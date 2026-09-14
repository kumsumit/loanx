import 'package:flutter_test/flutter_test.dart';
import 'package:loanx/db/tostore_database.dart';
import 'package:loanx/domain/connected.dart';
import 'package:loanx/service/connected_repository.dart';
import 'package:loanx/service/database_helper.dart';

void main() {
  late Database db;
  late ConnectedRepository repo;
  setUp(() async {
    db = await DatabaseHelper.instance.openMemory(
      name: 'connected-${DateTime.now().microsecondsSinceEpoch}',
    );
    final now = DateTime.now().toUtc().toIso8601String();
    await db.insert('localOwners', {
      'id': 'owner',
      'selfPartyId': 'self',
      'createdAt': now,
    });
    for (final p in const [('self', 'Me'), ('other', 'Mohan')]) {
      await db.insert('parties', {
        'id': p.$1,
        'ownerId': 'owner',
        'displayName': p.$2,
        'status': 'ACTIVE',
        'createdAt': now,
        'updatedAt': now,
      });
    }
    repo = ConnectedRepository(db, ownerId: 'owner', selfPartyId: 'self');
  });
  tearDown(() => db.close());
  test('persists idempotent messages and delivery/read state', () async {
    final c = await repo.createConversation(
      type: ConversationType.loan,
      title: 'Loan chat',
      participantPartyIds: ['self', 'other'],
      operationId: 'conversation-1',
    );
    final first = await repo.sendMessage(
      conversationId: c.id,
      kind: MessageKind.text,
      body: 'I will pay Friday',
      operationId: 'message-1',
    );
    final retry = await repo.sendMessage(
      conversationId: c.id,
      kind: MessageKind.text,
      body: 'I will pay Friday',
      operationId: 'message-1',
    );
    expect(retry.id, first.id);
    expect(await db.query('messages'), hasLength(1));
    await repo.markDelivered(first.id);
    await repo.markRead(first.id);
    final saved = (await repo.messages(c.id)).single;
    expect(saved.deliveredAt, isNotNull);
    expect(saved.readAt, isNotNull);
    await expectLater(
      repo.sendMessage(
        conversationId: c.id,
        kind: MessageKind.text,
        body: 'Changed',
        operationId: 'message-1',
      ),
      throwsStateError,
    );
  });
  test('owner and membership scopes cannot be bypassed', () async {
    await expectLater(
      repo.createConversation(
        type: ConversationType.loan,
        title: 'bad',
        participantPartyIds: ['other'],
      ),
      throwsArgumentError,
    );
    await expectLater(repo.messages('missing'), throwsStateError);
  });
  test('notifications and shares remain recipient scoped', () async {
    await repo.createNotification(
      recipientPartyId: 'self',
      type: 'REPAYMENT',
      title: 'Payment received',
      body: 'A repayment was recorded',
      operationId: 'notice-1',
    );
    await repo.createNotification(
      recipientPartyId: 'other',
      type: 'PRIVATE',
      title: 'Other',
      body: 'Not for self',
      operationId: 'notice-2',
    );
    expect((await repo.notifications()).map((e) => e.id), ['notice-1']);
    await repo.markNotificationRead('notice-1');
    expect((await repo.notifications(unreadOnly: true)), isEmpty);
    await db.insert('loans', {
      'depositorName': 'Mohan',
      'loanAmount': 100.0,
      'uid': 'loan-1',
      'ownerId': 'owner',
      'lenderPartyId': 'self',
      'borrowerPartyId': 'other',
      'currency': 'INR',
    });
    final share = await repo.shareResource(
      loanUid: 'loan-1',
      recipientPartyId: 'self',
      resourceType: 'statement',
      resourceId: 'statement-1',
      operationId: 'share-1',
    );
    expect((await repo.sharedWithMe()).single.resourceType, 'STATEMENT');
    await repo.revokeShare(share.id);
    expect(await repo.sharedWithMe(), isEmpty);
  });
}
