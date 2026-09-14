import 'package:flutter_test/flutter_test.dart';
import 'package:loanx/db/tostore_database.dart';
import 'package:loanx/domain/local_search.dart';
import 'package:loanx/service/database_helper.dart';
import 'package:loanx/service/local_search_service.dart';

void main() {
  late Database db;
  late LocalSearchService search;
  setUp(() async {
    db = await DatabaseHelper.instance.openMemory(
      name: 'search-${DateTime.now().microsecondsSinceEpoch}',
    );
    final now = DateTime.now().toUtc().toIso8601String();
    await db.insert('localOwners', {
      'id': 'a',
      'selfPartyId': 'self',
      'createdAt': now,
    });
    await db.insert('localOwners', {
      'id': 'b',
      'selfPartyId': 'other-self',
      'createdAt': now,
    });
    for (final row in [
      {'id': 'self', 'ownerId': 'a', 'displayName': 'Me'},
      {'id': 'mohan', 'ownerId': 'a', 'displayName': 'Mohan Kumar'},
      {'id': 'private', 'ownerId': 'b', 'displayName': 'Private Borrower'},
    ]) {
      await db.insert('parties', {
        ...row,
        'status': 'ACTIVE',
        'createdAt': now,
        'updatedAt': now,
      });
    }
    await db.insert('loans', {
      'depositorName': 'Mohan Kumar',
      'phoneNumber': '',
      'relativeName': '',
      'address': '',
      'loanAmount': 150000.0,
      'interestRate': 10.0,
      'weight': 20.0,
      'weightUnit': 'g',
      'interestType': 0,
      'interestFrequency': 3,
      'mortgageTermYears': 1,
      'additionalDetails': 'Gold bangles for shop expansion',
      'dateCreated': '2020-01-01T00:00:00.000Z',
      'familyRelationId': '1',
      'mortgageMaterialId': '1',
      'uid': 'loan-a',
      'ownerId': 'a',
      'lenderPartyId': 'self',
      'borrowerPartyId': 'mohan',
      'currency': 'INR',
    });
    await db.insert('loans', {
      'depositorName': 'Secret',
      'loanAmount': 999999.0,
      'uid': 'loan-b',
      'ownerId': 'b',
      'lenderPartyId': 'other-self',
      'borrowerPartyId': 'private',
      'currency': 'INR',
    });
    search = LocalSearchService(db, ownerId: 'a', selfPartyId: 'self');
  });
  tearDown(() => db.close());
  test('combines deterministic overdue gold and amount filters', () async {
    final r = await search.search(
      'show overdue gold loans above ₹1 lakh',
      now: DateTime.utc(2026),
    );
    expect(r.mode, SearchMode.structured);
    expect(r.results.map((e) => e.entityId), ['loan-a']);
  });
  test('finds names fuzzily and never leaks another owner', () async {
    expect(
      (await search.search('Mohan Kumar')).results
          .where((result) => result.entityType == SearchEntityType.party)
          .single
          .entityId,
      'mohan',
    );
    expect((await search.search('Private Borrower')).results, isEmpty);
  });
  test('returns deterministic lender-side aggregate', () async {
    final r = await search.search('who owes me the most');
    expect(r.results.single.entityId, 'loan-a');
    expect(r.results.single.entityType, SearchEntityType.answer);
  });
  test('search is bounded and malformed input fails closed', () async {
    await expectLater(search.search('x', limit: 51), throwsArgumentError);
    expect((await search.search('x' * 301)).interpreted, isFalse);
  });
}
