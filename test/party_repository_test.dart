import 'package:flutter_test/flutter_test.dart';
import 'package:loanx/domain/party.dart';
import 'package:loanx/service/party_repository.dart';
import 'package:loanx/db/tostore_database.dart';
import 'package:loanx/service/database_helper.dart';

void main() {
  late Database db;
  late PartyRepository a;
  late PartyRepository b;
  setUp(() async {
    db = await DatabaseHelper.instance.openMemory(
      name: 'party-test-${DateTime.now().microsecondsSinceEpoch}',
    );
    await db.insert('localOwners', {
      'id': 'a',
      'selfPartyId': 'self-a',
      'createdAt': DateTime.now().toIso8601String(),
    });
    await db.insert('localOwners', {
      'id': 'b',
      'selfPartyId': 'self-b',
      'createdAt': DateTime.now().toIso8601String(),
    });
    a = PartyRepository(db, ownerId: 'a');
    b = PartyRepository(db, ownerId: 'b');
  });
  tearDown(() => db.close());

  test('external contacts remain private even when phone matches', () async {
    final first = await a.createExternalParty(
      displayName: 'First',
      phone: '123',
    );
    final second = await b.createExternalParty(
      displayName: 'Second',
      phone: '123',
    );
    expect(first.id, isNot(second.id));
    expect(first.isExternal, isTrue);
    expect((await a.list()).map((p) => p.id), [first.id]);
    await expectLater(a.get(second.id), throwsStateError);
    await expectLater(
      a.updateContact(second.id, displayName: 'Changed'),
      throwsStateError,
    );
    expect((await b.get(second.id)).displayName, 'Second');
  });

  test(
    'contact edits retain IDs and account links without inventing identity',
    () async {
      final party = await a.createExternalParty(
        displayName: ' Name ',
        countryCode: 'in',
      );
      expect(party.displayName, 'Name');
      expect(party.countryCode, 'IN');
      final updated = await a.updateContact(party.id, displayName: 'New name');
      expect(updated.id, party.id);
      expect(updated.createdAt, party.createdAt);
      expect(updated.userId, isNull);
      expect(updated.updatedAt.isUtc, isTrue);
    },
  );

  test(
    'relationship retries are idempotent and roles are not assigned',
    () async {
      final first = await a.createExternalParty(displayName: 'First');
      final second = await a.createExternalParty(displayName: 'Second');
      final third = await a.createExternalParty(displayName: 'Third');
      final relationship = await a.createRelationship(
        partyAId: first.id,
        partyBId: second.id,
        id: 'request-1',
      );
      final retry = await a.createRelationship(
        partyAId: second.id,
        partyBId: first.id,
        id: 'request-1',
      );
      expect(retry.id, relationship.id);
      expect(retry.status, RelationshipStatus.pending);
      await expectLater(
        a.createRelationship(
          partyAId: first.id,
          partyBId: third.id,
          id: 'request-1',
        ),
        throwsStateError,
      );
      expect(await db.query('relationships'), hasLength(1));
    },
  );

  test('relationship cannot connect another workspace or self', () async {
    final first = await a.createExternalParty(displayName: 'First');
    final second = await b.createExternalParty(displayName: 'Second');
    await expectLater(
      a.createRelationship(partyAId: first.id, partyBId: second.id),
      throwsStateError,
    );
    await expectLater(
      a.createRelationship(partyAId: first.id, partyBId: first.id),
      throwsArgumentError,
    );
    expect(await db.query('relationships'), isEmpty);
  });

  test('validates input and bounded pagination', () async {
    await expectLater(
      a.createExternalParty(displayName: '  '),
      throwsArgumentError,
    );
    await expectLater(
      a.createExternalParty(displayName: 'Name', countryCode: '123'),
      throwsArgumentError,
    );
    await expectLater(a.list(limit: 201), throwsArgumentError);
    await expectLater(
      PartyRepository(
        db,
        ownerId: 'missing',
      ).createExternalParty(displayName: 'Name'),
      throwsStateError,
    );
    await a.createExternalParty(displayName: 'C');
    await a.createExternalParty(displayName: 'A');
    await a.createExternalParty(displayName: 'B');
    expect((await a.list(limit: 1, offset: 1)).single.displayName, 'B');
  });
}
