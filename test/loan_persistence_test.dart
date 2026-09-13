import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:loanx/db/fastdb.dart';
import 'package:loanx/model/loan.dart';
import 'package:loanx/model/loan_change.dart';
import 'package:loanx/provider/provider.dart';
import 'package:loanx/service/database_helper.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class _TestDB extends DB {
  _TestDB(this.database);
  final Database database;
  @override
  Future<Database> build() async => database;
}

void main() {
  sqfliteFfiInit();
  late Directory directory;
  late Database database;
  late ProviderContainer container;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('loanx-audit-');
    await FastDB.initForTesting(directory);
    database = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    await DatabaseHelper.instance.onCreate(database, 7);
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

  test(
    'completion audits committed before state despite mutated UI instance',
    () async {
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
      expect(changes.last['description'], contains('Active → Completed'));
      expect(changes.last['description'], contains('Recipient'));
      expect(changes.last['description'], contains('1000.00'));
    },
  );

  test('audit failure rolls back newly inserted loan', () async {
    await database.execute(
      '''CREATE TRIGGER reject_audit BEFORE INSERT ON loanChanges
      BEGIN SELECT RAISE(ABORT, 'test audit failure'); END''',
    );
    await expectLater(createLoan(), throwsA(isA<DatabaseException>()));
    expect(await database.query(Loan.tableName), isEmpty);
    expect(container.read(loanListProvider).requireValue, isEmpty);
  });

  test(
    'audit failure rolls back financial update and leaves prior audit intact',
    () async {
      await createLoan();
      final loan = container.read(loanListProvider).requireValue.single;
      await database.execute(
        '''CREATE TRIGGER reject_audit BEFORE INSERT ON loanChanges
      BEGIN SELECT RAISE(ABORT, 'test audit failure'); END''',
      );
      loan.loanAmount = 999;
      await expectLater(
        container.read(loanListProvider.notifier).updateLoan(loan),
        throwsA(isA<DatabaseException>()),
      );
      expect((await database.query(Loan.tableName)).single['loanAmount'], 1000);
      expect(
        container.read(loanListProvider).requireValue.single.loanAmount,
        1000,
      );
      expect(await database.query(LoanChange.tableName), hasLength(1));
    },
  );
}
