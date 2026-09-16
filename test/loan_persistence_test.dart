import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:loanx/db/tostore_database.dart';
import 'package:loanx/db/app_settings.dart';
import 'package:loanx/model/loan.dart';
import 'package:loanx/model/loan_change.dart';
import 'package:loanx/provider/provider.dart';
import 'package:loanx/service/database_helper.dart';
import 'package:tostore/tostore.dart';

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
        '',
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
    expect(stored['loanAmountExact'], '1000.0');
    expect(stored['uid'], isNotEmpty);
    expect(stored['ownerId'], isNotEmpty);
    expect(stored['lenderPartyId'], isNotEmpty);
    expect(stored['borrowerPartyId'], isNotEmpty);
    expect(stored['lenderPartyId'], isNot(stored['borrowerPartyId']));
    expect(await database.query('parties'), hasLength(2));
  });

  test(
    'server-linked lender loans queue party before loan mutations',
    () async {
      final ownerId = 'owner-server';
      await database.insert('localOwners', {
        'id': ownerId,
        'selfPartyId': 'self-server',
        'remoteWorkspaceId': 'workspace-1',
        'remotePartyId': 'remote-self',
        'createdAt': DateTime.now().toUtc().toIso8601String(),
      });
      await database.insert('parties', {
        'id': 'self-server',
        'ownerId': ownerId,
        'displayName': 'Owner',
        'status': 'ACTIVE',
        'createdAt': DateTime.now().toUtc().toIso8601String(),
        'updatedAt': DateTime.now().toUtc().toIso8601String(),
      });
      await createLoan();
      final queued = await database.query(
        'pendingSyncMutations',
        orderBy: 'createdAt ASC',
      );
      expect(queued, hasLength(2));
      expect(queued[0]['entityType'], 'party');
      expect(queued[0]['operation'], 'create');
      expect(queued[1]['entityType'], 'loan');
      expect(queued[1]['operation'], 'create');
    },
  );

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

  test('principal survives a file-backed database reopen', () async {
    final directory = await Directory.systemTemp.createTemp('loan-durable-');
    final dbName = 'loan-durable-${DateTime.now().microsecondsSinceEpoch}';
    final config = DataStoreConfig(
      dbName: dbName,
      defaultQueryLimit: 1000,
      persistRecoveryOnCommit: true,
    );
    final firstStore = await ToStore.open(
      dbPath: directory.path,
      dbName: dbName,
      schemas: DatabaseHelper.schemas,
      config: config,
    );
    final first = LoanxDatabase(firstStore);
    await first.transaction((tx) async {
      await tx.insert('localOwners', {
        'id': 'owner',
        'selfPartyId': 'self',
        'createdAt': DateTime.now().toUtc().toIso8601String(),
      });
      await tx.insert('loans', {
        'loanAmount': 12500.75,
        'loanAmountExact': '12500.75',
        'currency': 'INR',
      });
    });
    expect((await first.query('loans')).single['loanAmountExact'], '12500.75');
    await first.close();

    final reopenedStore = await ToStore.open(
      dbPath: directory.path,
      dbName: dbName,
      schemas: DatabaseHelper.schemas,
      config: config,
      reinitialize: true,
      noPersistOnClose: false,
    );
    final reopened = LoanxDatabase(reopenedStore);
    addTearDown(() async {
      await reopened.close();
      await directory.delete(recursive: true);
    });

    final rows = await reopened.query('loans');
    expect(rows, hasLength(1));
    expect(rows.single['loanAmountExact'], '12500.75');
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
