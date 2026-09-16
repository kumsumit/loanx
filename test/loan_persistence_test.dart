import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:loanx/db/tostore_database.dart';
import 'package:loanx/db/app_settings.dart';
import 'package:loanx/model/loan.dart';
import 'package:loanx/model/loan_change.dart';
import 'package:loanx/provider/provider.dart';
import 'package:loanx/service/database_helper.dart';

class _TestDB extends DB {
  _TestDB(this.database);
  final Database database;
  @override
  Future<Database> build() async => database;
}

void main() {
  late Database database;
  late ProviderContainer container;
  late Directory directory;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('loan-test-');
    await AppSettings.initForTesting(directory);
    database = await DatabaseHelper.instance.openMemory(name: 'loan-test');
    container = ProviderContainer(
      overrides: [dBProvider.overrideWith(() => _TestDB(database))],
    );
    await container.read(dBProvider.future);
    await container.read(loanListProvider.future);
  });
  tearDown(() async {
    container.dispose();
    await database.close();
    await directory.delete(recursive: true);
  });

  Future<int> createLoan() => container
      .read(loanListProvider.notifier)
      .add(
        null,
        'Borrower',
        '1234567890',
        '',
        '',
        1000,
        10,
        'g',
        0,
        InterestType.simple.index,
        InterestFrequency.monthly.index,
        5,
        0,
        0,
        '',
        '',
        1,
        1,
      );

  test('loan writes and completion audit are persisted', () async {
    final id = await createLoan();
    final loan = container.read(loanListProvider).requireValue.single;
    loan.complete(receivedBy: 'Recipient', amountReceived: 1000);
    await container.read(loanListProvider.notifier).updateLoan(loan);
    final changes = await database.query(
      LoanChange.tableName,
      where: 'loanId = ?',
      whereArgs: [id],
      orderBy: 'id',
    );
    expect(changes, hasLength(2));
    expect(changes.last['description'], contains('Recipient'));
    expect(await database.query(Loan.tableName), hasLength(1));
    final stored = (await database.query(Loan.tableName)).single;
    expect(stored['uid'], isNotEmpty);
    expect(stored['ownerId'], isNotEmpty);
    expect(stored['lenderPartyId'], isNotEmpty);
    expect(stored['borrowerPartyId'], isNotEmpty);
    expect(stored['lenderPartyId'], isNot(stored['borrowerPartyId']));
    expect(await database.query('parties'), hasLength(2));
  });

  test('owner-scoped reads and writes reject unrelated loan IDs', () async {
    await createLoan();
    final local = (await database.query(Loan.tableName)).single;
    final foreign = Map<String, Object?>.from(local)
      ..remove('id')
      ..['uid'] = 'foreign-uid'
      ..['ownerId'] = 'another-local-owner'
      ..['lenderPartyId'] = 'another-self-party';
    final foreignId = await database.insert(Loan.tableName, foreign);
    final loans = await container
        .read(loanListProvider.notifier)
        .readAllLoans();
    expect(loans, hasLength(1));
    await expectLater(
      container.read(loanListProvider.notifier).delete(foreignId),
      throwsStateError,
    );
    await expectLater(
      container.read(loanListProvider.notifier).bulkDelete([
        loans.single.id!,
        foreignId,
      ]),
      throwsStateError,
    );
    expect(await database.query(Loan.tableName), hasLength(2));
  });

  test(
    'borrower preference cannot create or mutate financial records',
    () async {
      final id = await createLoan();
      final loan = container.read(loanListProvider).requireValue.single;
      AppSettings.putOnboardingInterest(1);
      await expectLater(createLoan(), throwsStateError);
      await expectLater(
        container.read(loanListProvider.notifier).updateLoan(loan),
        throwsStateError,
      );
      await expectLater(
        container.read(loanListProvider.notifier).delete(id),
        throwsStateError,
      );
      expect(await database.query(Loan.tableName), hasLength(1));
    },
  );
}
