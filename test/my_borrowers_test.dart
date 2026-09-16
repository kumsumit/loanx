import 'package:flutter_test/flutter_test.dart';
import 'package:loanx/features/lender/my_borrowers.dart';
import 'package:loanx/service/database_helper.dart';

void main() {
  test('borrowers are grouped by owned Party IDs, not their names', () async {
    final db = await DatabaseHelper.instance.openMemory(
      name: 'my-borrowers-${DateTime.now().microsecondsSinceEpoch}',
    );
    try {
      final now = DateTime.utc(2026, 1, 1).toIso8601String();
      await db.insert('localOwners', {
        'id': 'owner',
        'selfPartyId': 'lender',
        'createdAt': now,
      });
      for (final (id, userId) in <(String, String?)>[
        ('external', null),
        ('connected', 'borrower-account'),
      ]) {
        await db.insert('parties', {
          'id': id,
          'ownerId': 'owner',
          'displayName': 'Same name',
          'userId': userId,
          'status': 'ACTIVE',
          'createdAt': now,
          'updatedAt': now,
        });
        await db.insert('loans', {
          'ownerId': 'owner',
          'uid': 'loan-$id',
          'lenderPartyId': 'lender',
          'borrowerPartyId': id,
          'depositorName': 'Same name',
          'phoneNumber': '',
          'relativeName': '',
          'address': '',
          'loanAmount': 1000.0,
          'currency': 'INR',
          'weight': 0.0,
          'interestRate': 0.0,
          'interestType': 0,
          'interestFrequency': 3,
          'additionalDetails': '',
          'dateCreated': now,
          'familyRelationId': 1,
          'mortgageMaterialId': 1,
        });
      }
      final borrowers = await loadMyBorrowers(db);
      expect(borrowers, hasLength(2));
      expect(borrowers.map((item) => item.loanCount), [1, 1]);
      expect(borrowers.map((item) => item.connected).toSet(), {true, false});
    } finally {
      await db.close();
    }
  });
}
