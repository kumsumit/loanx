import 'package:flutter_test/flutter_test.dart';
import 'package:loanx/db/tostore_database.dart';
import 'package:loanx/features/borrower/home.dart';
import 'package:loanx/service/database_helper.dart';

void main() {
  late Database db;

  setUp(() async {
    db = await DatabaseHelper.instance.openMemory(
      name: 'borrower-home-${DateTime.now().microsecondsSinceEpoch}',
    );
    final now = DateTime.utc(2026, 9, 16).toIso8601String();
    await db.insert('localOwners', {
      'id': 'owner',
      'selfPartyId': 'borrower',
      'createdAt': now,
    });
    for (final party in const [
      ('borrower', 'Borrower', 'borrower-user'),
      ('connected-lender', 'Connected Lender', 'lender-user'),
      ('external-lender', 'External Lender', null),
      ('other-borrower', 'Other Borrower', 'other-user'),
    ]) {
      await db.insert('parties', {
        'id': party.$1,
        'ownerId': 'owner',
        'displayName': party.$2,
        'userId': party.$3,
        'status': 'ACTIVE',
        'createdAt': now,
        'updatedAt': now,
      });
    }
    await _relationship(db, 'connected-relationship', 'connected-lender');
    await _relationship(db, 'external-relationship', 'external-lender');
  });

  tearDown(() => db.close());

  test('shows only connected loans received by this borrower', () async {
    await db.insert(
      'loans',
      _loan(
        uid: 'visible-loan',
        lenderId: 'connected-lender',
        borrowerId: 'borrower',
        relationshipId: 'connected-relationship',
      ),
    );
    await db.insert(
      'loans',
      _loan(
        uid: 'external-loan',
        lenderId: 'external-lender',
        borrowerId: 'borrower',
        relationshipId: 'external-relationship',
      ),
    );
    await db.insert(
      'loans',
      _loan(
        uid: 'lender-side-loan',
        lenderId: 'borrower',
        borrowerId: 'other-borrower',
        relationshipId: 'connected-relationship',
      ),
    );

    await _share(db, 'visible-loan', 'borrower');
    await _share(db, 'external-loan', 'borrower');

    await _notification(db, 'visible-notice', 'borrower', 'visible-loan');
    await _notification(db, 'unrelated-notice', 'borrower', 'external-loan');
    await _notification(
      db,
      'other-recipient',
      'other-borrower',
      'visible-loan',
    );

    final dashboard = await loadBorrowerDashboard(db);

    expect(dashboard.loans.map((item) => item.loanUid), ['visible-loan']);
    expect(dashboard.loans.single.lenderPartyId, 'connected-lender');
    expect(dashboard.loans.single.lenderName, 'Connected Lender');
    expect(dashboard.notifications.map((item) => item.id), ['visible-notice']);
  });

  test('an active relationship alone never reveals an unshared loan', () async {
    await db.insert(
      'loans',
      _loan(
        uid: 'unshared',
        lenderId: 'connected-lender',
        borrowerId: 'borrower',
        relationshipId: 'connected-relationship',
      ),
    );
    expect((await loadBorrowerDashboard(db)).loans, isEmpty);
    await _share(db, 'unshared', 'borrower');
    expect((await loadBorrowerDashboard(db)).loans, hasLength(1));
    await db.update(
      'sharedResources',
      {'revokedAt': DateTime.utc(2026, 9, 16).toIso8601String()},
      where: 'id = ?',
      whereArgs: ['share-unshared'],
    );
    expect((await loadBorrowerDashboard(db)).loans, isEmpty);
  });

  test('sharing cannot attach an unrelated relationship to a loan', () async {
    await db.insert(
      'loans',
      _loan(
        uid: 'wrong-relationship',
        lenderId: 'connected-lender',
        borrowerId: 'borrower',
        relationshipId: 'external-relationship',
      ),
    );
    await _share(db, 'wrong-relationship', 'borrower');
    expect((await loadBorrowerDashboard(db)).loans, isEmpty);
  });
}

Future<void> _share(Database db, String uid, String recipient) => db
    .insert('sharedResources', {
      'id': 'share-$uid',
      'ownerId': 'owner',
      'loanUid': uid,
      'recipientPartyId': recipient,
      'resourceType': 'LOAN',
      'resourceId': uid,
      'visibility': 'SHARED',
      'sharedAt': DateTime.utc(2026, 9, 16).toIso8601String(),
    })
    .then((_) {});

Future<void> _relationship(Database db, String id, String lenderId) async {
  final now = DateTime.utc(2026, 9, 16).toIso8601String();
  await db.insert('relationships', {
    'id': id,
    'ownerId': 'owner',
    'partyAId': lenderId,
    'partyBId': 'borrower',
    'status': 'ACTIVE',
    'createdAt': now,
    'updatedAt': now,
  });
}

Map<String, Object?> _loan({
  required String uid,
  required String lenderId,
  required String borrowerId,
  required String relationshipId,
}) => {
  'depositorName': 'Legacy name',
  'phoneNumber': '',
  'relativeName': '',
  'address': '',
  'loanAmount': 1000.0,
  'interestRate': 10.0,
  'weight': 0.0,
  'interestType': 0,
  'interestFrequency': 3,
  'additionalDetails': '',
  'dateCreated': DateTime.utc(2026, 1, 1).toIso8601String(),
  'familyRelationId': 1,
  'mortgageMaterialId': 1,
  'uid': uid,
  'ownerId': 'owner',
  'lenderPartyId': lenderId,
  'borrowerPartyId': borrowerId,
  'relationshipId': relationshipId,
  'currency': 'INR',
};

Future<void> _notification(
  Database db,
  String id,
  String recipient,
  String entityId,
) => db.insert('notifications', {
  'id': id,
  'ownerId': 'owner',
  'recipientPartyId': recipient,
  'type': 'LOAN_UPDATE',
  'entityType': 'LOAN',
  'entityId': entityId,
  'title': 'Loan updated',
  'body': 'The lender updated your loan.',
  'createdAt': DateTime.utc(2026, 9, 16).toIso8601String(),
});
