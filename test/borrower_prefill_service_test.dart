import 'package:flutter_test/flutter_test.dart';
import 'package:intl_phone_number_input/intl_phone_number_input.dart';
import 'package:loanx/db/tostore_database.dart';
import 'package:loanx/model/loan.dart';
import 'package:loanx/service/borrower_prefill_service.dart';
import 'package:loanx/service/database_helper.dart';

void main() {
  late Database database;

  setUp(() async {
    database = await DatabaseHelper.instance.openMemory(name: 'prefill-test');
    final now = DateTime.now().toUtc().toIso8601String();
    await database.insert('localOwners', {
      'id': 'owner',
      'selfPartyId': 'self',
      'createdAt': now,
    });
    await database.insert('parties', {
      'id': 'self',
      'ownerId': 'owner',
      'displayName': 'Lender',
      'status': 'ACTIVE',
      'createdAt': now,
      'updatedAt': now,
    });
  });

  tearDown(() => database.close());

  test('prefills the lender-owned borrower record for a valid E.164 match',
      () async {
    final now = DateTime.now().toUtc().toIso8601String();
    await database.insert('parties', {
      'id': 'borrower',
      'ownerId': 'owner',
      'displayName': 'Asha Patel',
      'phone': '98765 43210',
      'countryCode': 'IN',
      'status': 'ACTIVE',
      'createdAt': now,
      'updatedAt': now,
    });
    await database.insert(Loan.tableName, {
      'ownerId': 'owner',
      'borrowerPartyId': 'borrower',
      'depositorName': 'Asha Patel',
      'phoneNumber': '9876543210',
      'relativeName': 'Ravi Patel',
      'address': '12 Market Road',
      'loanAmount': 1000.0,
      'currency': 'INR',
      'weight': 0.0,
      'interestRate': 0.0,
      'interestType': 0,
      'interestFrequency': 0,
      'mortgageTermYears': 5,
      'lockInDays': 0,
      'earlyRedemptionCharge': 0.0,
      'weightUnit': 'g',
      'termsAndConditions': '',
      'completedBy': '',
      'completionReference': '',
      'completionNotes': '',
      'dateCreated': now,
      'calculationVersion': 'exact-v1',
      'syncState': 'LOCAL_ONLY',
    });

    final prefill = await BorrowerPrefillService.findForPhone(
      database,
      ownerId: 'owner',
      phone: PhoneNumber(isoCode: 'IN', nsn: '9876543210'),
    );

    expect(prefill, isNotNull);
    expect(prefill!.displayName, 'Asha Patel');
    expect(prefill.address, '12 Market Road');
    expect(prefill.relativeName, 'Ravi Patel');
  });

  test('does not use a matching contact from another local owner', () async {
    final now = DateTime.now().toUtc().toIso8601String();
    await database.insert('localOwners', {
      'id': 'other-owner',
      'selfPartyId': 'other-self',
      'createdAt': now,
    });
    await database.insert('parties', {
      'id': 'private-borrower',
      'ownerId': 'other-owner',
      'displayName': 'Private person',
      'phone': '9876543210',
      'countryCode': 'IN',
      'status': 'ACTIVE',
      'createdAt': now,
      'updatedAt': now,
    });

    final prefill = await BorrowerPrefillService.findForPhone(
      database,
      ownerId: 'owner',
      phone: PhoneNumber(isoCode: 'IN', nsn: '9876543210'),
    );

    expect(prefill, isNull);
  });
}
