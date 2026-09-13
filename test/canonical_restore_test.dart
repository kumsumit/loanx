import 'package:flutter_test/flutter_test.dart';
import 'package:loanx/service/canonical_restore.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();
  late Database source;
  late Database target;
  setUp(() async {
    source = await fixture('source');
    target = await fixture('target');
    await source.insert('parties', party('external', 'source'));
    await source.insert('loans', loan('loan-1'));
    await source.insert('loanChanges', {
      'loanId': 1,
      'description': 'Created',
      'createdAt': '2026-01-01T00:00:00Z',
    });
  });
  tearDown(() async {
    await source.close();
    await target.close();
  });
  test(
    'restore transfers ownership, preserves roles and replays once',
    () async {
      await CanonicalRestore.merge(source, target);
      await CanonicalRestore.merge(source, target);
      final row = (await target.query('loans')).single;
      expect(row['uid'], 'loan-1');
      expect(row['ownerId'], 'target');
      expect(row['lenderPartyId'], 'target-self');
      expect(row['borrowerPartyId'], 'external');
      expect(row['loanAmount'], 1234.56);
      expect(row['settlementAmount'], 900.25);
      expect(await target.query('loanChanges'), hasLength(1));
      expect(await target.query('parties'), hasLength(2));
    },
  );
  test(
    'identical financial details with distinct loan IDs stay distinct',
    () async {
      await source.insert('loans', loan('loan-2'));
      await CanonicalRestore.merge(source, target);
      expect(await target.query('loans'), hasLength(2));
    },
  );
  test(
    'conflicting stable loan identity rolls back the entire restore',
    () async {
      await CanonicalRestore.merge(source, target);
      await source.insert('parties', party('new-person', 'source'));
      await source.update('loans', {'loanAmount': 50});
      await expectLater(
        CanonicalRestore.merge(source, target),
        throwsFormatException,
      );
      expect((await target.query('loans')).single['loanAmount'], 1234.56);
      expect(await target.query('parties'), hasLength(2));
    },
  );
  test(
    'other workspace data and linked identities fail before writing',
    () async {
      await source.update(
        'parties',
        {'ownerId': 'intruder'},
        where: 'id = ?',
        whereArgs: ['external'],
      );
      await expectLater(
        CanonicalRestore.merge(source, target),
        throwsFormatException,
      );
      await source.update(
        'parties',
        {'ownerId': 'source', 'userId': 'account'},
        where: 'id = ?',
        whereArgs: ['external'],
      );
      await expectLater(
        CanonicalRestore.merge(source, target),
        throwsFormatException,
      );
      expect(await target.query('loans'), isEmpty);
    },
  );
  test('orphan audit event rolls back inserts', () async {
    await source.insert('loanChanges', {
      'loanId': 999,
      'description': 'bad',
      'createdAt': '2026-01-01',
    });
    await expectLater(
      CanonicalRestore.merge(source, target),
      throwsFormatException,
    );
    expect(await target.query('loans'), isEmpty);
    expect(await target.query('parties'), hasLength(1));
  });
  test(
    'snapshot provenance preserved and conflicting provenance rejected',
    () async {
      await source.insert('migrationSnapshots', {
        'id': 'source:v8',
        'entityType': 'loan',
        'sourceId': '1',
        'payload': '{}',
      });
      await CanonicalRestore.merge(source, target);
      expect(await target.query('migrationSnapshots'), hasLength(1));
      await source.update('migrationSnapshots', {
        'payload': '{"changed":true}',
      });
      await expectLater(
        CanonicalRestore.merge(source, target),
        throwsFormatException,
      );
      expect(
        (await target.query('migrationSnapshots')).single['payload'],
        '{}',
      );
    },
  );
}

Map<String, Object?> party(String id, String owner) => {
  'id': id,
  'ownerId': owner,
  'displayName': id,
  'phone': '',
  'email': '',
  'countryCode': 'IN',
  'userId': null,
  'status': 'ACTIVE',
  'createdAt': '2026-01-01',
  'updatedAt': '2026-01-01',
};
Map<String, Object?> loan(String uid) => {
  'uid': uid,
  'ownerId': 'source',
  'lenderPartyId': 'source-self',
  'borrowerPartyId': 'external',
  'currency': 'INR',
  'calculationVersion': 'legacy-v1',
  'loanAmount': 1234.56,
  'settlementAmount': 900.25,
  'dateCreated': '2026-01-01',
  'familyRelationId': 1,
  'mortgageMaterialId': 1,
};
Future<Database> fixture(String owner) async {
  final db = await databaseFactoryFfi.openDatabase(
    inMemoryDatabasePath,
    options: OpenDatabaseOptions(singleInstance: false),
  );
  await db.setVersion(8);
  for (final sql in [
    'CREATE TABLE localOwners(id TEXT PRIMARY KEY,selfPartyId TEXT,createdAt TEXT)',
    'CREATE TABLE users(id TEXT PRIMARY KEY,phone TEXT,email TEXT,status TEXT,createdAt TEXT,updatedAt TEXT)',
    'CREATE TABLE parties(id TEXT PRIMARY KEY,ownerId TEXT,displayName TEXT,phone TEXT,email TEXT,countryCode TEXT,userId TEXT,status TEXT,createdAt TEXT,updatedAt TEXT)',
    'CREATE TABLE relationships(id TEXT PRIMARY KEY,ownerId TEXT,partyAId TEXT,partyBId TEXT,status TEXT,createdAt TEXT,updatedAt TEXT)',
    'CREATE TABLE familyRelations(id INTEGER PRIMARY KEY,name TEXT UNIQUE)',
    'CREATE TABLE mortgageMaterials(id INTEGER PRIMARY KEY,name TEXT UNIQUE)',
    'CREATE TABLE weightUnits(id INTEGER PRIMARY KEY,name TEXT,symbol TEXT UNIQUE)',
    'CREATE TABLE loans(id INTEGER PRIMARY KEY,uid TEXT UNIQUE,ownerId TEXT,lenderPartyId TEXT,borrowerPartyId TEXT,relationshipId TEXT,currency TEXT,calculationVersion TEXT,loanAmount REAL,settlementAmount REAL,dateCreated TEXT,familyRelationId INTEGER,mortgageMaterialId INTEGER)',
    'CREATE TABLE loanChanges(id INTEGER PRIMARY KEY,loanId INTEGER,description TEXT,createdAt TEXT)',
    'CREATE TABLE migrationSnapshots(id TEXT PRIMARY KEY,entityType TEXT,sourceId TEXT,payload TEXT)',
    'CREATE TABLE migrationReports(id TEXT PRIMARY KEY,createdAt TEXT,payload TEXT)',
  ]) {
    await db.execute(sql);
  }
  await db.insert('localOwners', {
    'id': owner,
    'selfPartyId': '$owner-self',
    'createdAt': '2026-01-01',
  });
  await db.insert('parties', party('$owner-self', owner));
  await db.insert('familyRelations', {'id': 1, 'name': 'Father'});
  await db.insert('mortgageMaterials', {'id': 1, 'name': 'Ring'});
  return db;
}
