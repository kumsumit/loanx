import 'package:flutter_test/flutter_test.dart';
import 'package:loanx/service/database_helper.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();
  late Database source;
  late Database target;

  setUp(() async {
    source = await _fixture();
    target = await _fixture();
  });
  tearDown(() async {
    await source.close();
    await target.close();
  });

  test(
    'legacy restore preserves terms, settlement, collateral and history',
    () async {
      await _seed(source);
      await DatabaseHelper.restoreTables(source, targetDatabase: target);
      final loan = (await target.query('loans')).single;
      expect(loan['loanAmount'], 1234.56);
      expect(loan['interestRate'], 3.5);
      expect(loan['settlementAmount'], 900.25);
      expect(loan['dateFinished'], '2026-02-01 12:00:00');
      expect(loan['completionReference'], 'receipt-1');
      expect(loan['weight'], 12.75);
      expect(loan['weightUnit'], 'tola');
      expect(loan['termsAndConditions'], 'Original terms');
      expect(
        (await target.query('loanChanges')).single['description'],
        'Recorded',
      );
      expect((await target.query('weightUnits')).single['symbol'], 'tola');
      final material = (await target.query('mortgageMaterials')).single;
      expect(loan['mortgageMaterialId'], material['id']);
      expect(material['name'], 'Gold necklace');

      // Replaying the same legacy backup must not double records or totals.
      await DatabaseHelper.restoreTables(source, targetDatabase: target);
      expect((await target.query('loans')).length, 1);
      expect((await target.query('loanChanges')).length, 1);
    },
  );

  test(
    'conflicting terms abort the entire merge, including lookup writes',
    () async {
      await _seed(source);
      await _seed(target);
      await source.update('loans', {'interestRate': 99.0});
      await source.insert('mortgageMaterials', {
        'id': 88,
        'name': 'New material',
      });
      await expectLater(
        DatabaseHelper.restoreTables(source, targetDatabase: target),
        throwsFormatException,
      );
      expect((await target.query('loans')).single['interestRate'], 3.5);
      expect((await target.query('mortgageMaterials')).length, 1);
      expect((await target.query('loanChanges')).length, 1);
    },
  );

  test(
    'orphan audit history fails without dropping the event or changing data',
    () async {
      await _seed(source);
      await source.insert('loanChanges', {
        'loanId': 999,
        'description': 'Orphan',
        'createdAt': '2026-01-02T00:00:00Z',
      });
      await expectLater(
        DatabaseHelper.restoreTables(source, targetDatabase: target),
        throwsFormatException,
      );
      expect(await target.query('loans'), isEmpty);
      expect(await target.query('familyRelations'), isEmpty);
    },
  );

  test('missing collateral references roll back earlier inserts', () async {
    await _seed(source);
    await source.update('loans', {'mortgageMaterialId': 404});
    await expectLater(
      DatabaseHelper.restoreTables(source, targetDatabase: target),
      throwsFormatException,
    );
    expect(await target.query('loans'), isEmpty);
    expect(await target.query('familyRelations'), isEmpty);
  });

  test('target write failure rolls back imported loan and lookups', () async {
    await _seed(source);
    await target.execute(
      '''CREATE TRIGGER reject_audit BEFORE INSERT ON loanChanges
      BEGIN SELECT RAISE(ABORT, 'test storage failure'); END''',
    );
    await expectLater(
      DatabaseHelper.restoreTables(source, targetDatabase: target),
      throwsA(isA<DatabaseException>()),
    );
    expect(await target.query('loans'), isEmpty);
    expect(await target.query('familyRelations'), isEmpty);
  });

  test(
    'future schema and invalid financial values are rejected before writes',
    () async {
      await _seed(source);
      await source.setVersion(8);
      await expectLater(
        DatabaseHelper.restoreTables(source, targetDatabase: target),
        throwsFormatException,
      );
      await source.setVersion(7);
      await source.update('loans', {'loanAmount': -1});
      await expectLater(
        DatabaseHelper.restoreTables(source, targetDatabase: target),
        throwsFormatException,
      );
      expect(await target.query('loans'), isEmpty);
    },
  );

  test('version 1 backup without newer tables remains readable', () async {
    await _seed(source);
    await source.execute('DROP TABLE loanChanges');
    await source.execute('DROP TABLE weightUnits');
    await source.setVersion(1);
    await DatabaseHelper.restoreTables(source, targetDatabase: target);
    expect((await target.query('loans')).single['loanAmount'], 1234.56);
    expect(await target.query('loanChanges'), isEmpty);
  });
}

Future<Database> _fixture() => databaseFactoryFfi.openDatabase(
  inMemoryDatabasePath,
  options: OpenDatabaseOptions(
    version: 7,
    singleInstance: false,
    onCreate: (db, _) async {
      await db.execute(
        'CREATE TABLE familyRelations(id INTEGER PRIMARY KEY, name TEXT UNIQUE, isAddedByUser INTEGER)',
      );
      await db.execute(
        'CREATE TABLE mortgageMaterials(id INTEGER PRIMARY KEY, name TEXT UNIQUE, isAddedByUser INTEGER)',
      );
      await db.execute(
        'CREATE TABLE weightUnits(id INTEGER PRIMARY KEY, name TEXT, symbol TEXT UNIQUE, isAddedByUser INTEGER)',
      );
      await db.execute(
        '''CREATE TABLE loans(
        id INTEGER PRIMARY KEY, depositorName TEXT, phoneNumber TEXT,
        relativeName TEXT, address TEXT, loanAmount REAL, interestRate REAL,
        weight REAL, weightUnit TEXT, interestType INTEGER, interestFrequency INTEGER,
        dateCreated TEXT, dateFinished TEXT, completedBy TEXT, settlementAmount REAL,
        completionReference TEXT, completionNotes TEXT, termsAndConditions TEXT,
        familyRelationId INTEGER, mortgageMaterialId INTEGER,
        UNIQUE(depositorName, relativeName, address, loanAmount, familyRelationId))''',
      );
      await db.execute(
        'CREATE TABLE loanChanges(id INTEGER PRIMARY KEY, loanId INTEGER, description TEXT, createdAt TEXT)',
      );
    },
  ),
);

Future<void> _seed(Database db) async {
  await db.insert('familyRelations', {'id': 20, 'name': 'Father'});
  await db.insert('mortgageMaterials', {'id': 30, 'name': 'Gold necklace'});
  await db.insert('weightUnits', {'id': 40, 'name': 'Tola', 'symbol': 'tola'});
  await db.insert('loans', {
    'id': 50,
    'depositorName': 'External participant',
    'phoneNumber': '+910000000000',
    'relativeName': 'Relative',
    'address': 'Private address',
    'loanAmount': 1234.56,
    'interestRate': 3.5,
    'weight': 12.75,
    'weightUnit': 'tola',
    'interestType': 0,
    'interestFrequency': 0,
    'dateCreated': '2026-01-01 12:00:00',
    'dateFinished': '2026-02-01 12:00:00',
    'completedBy': 'Recorder',
    'settlementAmount': 900.25,
    'completionReference': 'receipt-1',
    'completionNotes': 'Legacy settlement, not inferred repayment',
    'termsAndConditions': 'Original terms',
    'familyRelationId': 20,
    'mortgageMaterialId': 30,
  });
  await db.insert('loanChanges', {
    'id': 60,
    'loanId': 50,
    'description': 'Recorded',
    'createdAt': '2026-01-01T12:00:00Z',
  });
}
