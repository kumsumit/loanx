import 'dart:convert';
import 'dart:math';

import 'package:sqflite_sqlcipher/sqflite.dart';

/// Schema v8 introduces identity without reinterpreting legacy financial data.
/// Call within the openDatabase upgrade transaction, with foreign keys disabled
/// before the transaction. All original columns and integer references survive.
class CanonicalMigration {
  static const version = 8;
  static const identityColumns = [
    'uid', 'ownerId', 'lenderPartyId', 'borrowerPartyId', 'relationshipId',
    'currency', 'calculationVersion',
  ];

  static String newId() {
    final random = Random.secure();
    final bytes = List.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 15) | 64;
    bytes[8] = (bytes[8] & 63) | 128;
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }

  static Future<void> upgrade(DatabaseExecutor db) async {
    if ((await db.rawQuery('PRAGMA table_info(loans)')).any((c) => c['name'] == 'uid')) {
      return;
    }
    if ((await db.rawQuery('PRAGMA foreign_key_check')).isNotEmpty) {
      throw const FormatException('Existing database contains orphan references; migration aborted.');
    }
    final originals = <String, List<Map<String, Object?>>>{};
    for (final table in ['loans', 'loanChanges', 'familyRelations', 'mortgageMaterials', 'weightUnits']) {
      originals[table] = await db.query(table, orderBy: 'id');
    }
    for (final loan in originals['loans']!) {
      if (loan['loanAmount'] is! num || !(loan['loanAmount'] as num).isFinite) {
        throw const FormatException('Legacy principal is invalid; migration aborted.');
      }
    }
    await createIdentityTables(db);
    final now = DateTime.now().toUtc().toIso8601String();
    final owner = newId();
    final self = newId();
    await db.insert('localOwners', {'id': owner, 'selfPartyId': self, 'createdAt': now});
    await db.insert('parties', {
      'id': self, 'ownerId': owner, 'displayName': 'Local owner',
      'status': 'ACTIVE', 'createdAt': now, 'updatedAt': now,
    });
    for (final table in originals.entries) {
      for (final row in table.value) {
        await db.insert('migrationSnapshots', {
          'id': '$owner:v7:${table.key}:${row['id']}',
          'entityType': table.key, 'sourceId': '${row['id']}', 'payload': jsonEncode(row),
        });
      }
    }

    final oldSql = (await db.rawQuery("SELECT sql FROM sqlite_master WHERE type='table' AND name='loans'")).single['sql'] as String;
    var sql = oldSql.replaceFirst(RegExp(r'CREATE TABLE(?: IF NOT EXISTS)?\s+["`\[]?loans["`\]]?', caseSensitive: false), 'CREATE TABLE loans_v8');
    sql = sql.replaceFirst(RegExp(r',\s*UNIQUE\s*\(depositorName\s*,\s*relativeName\s*,\s*address\s*,\s*loanAmount\s*,\s*familyRelationId\s*\)', caseSensitive: false), '');
    // Append before table constraints: SQLite requires columns first.
    final insertion = sql.toUpperCase().indexOf('FOREIGN KEY');
    final position = insertion < 0 ? sql.lastIndexOf(')') : insertion;
    final prefix = sql.substring(0, position).trimRight();
    sql = '${prefix.endsWith(',') ? prefix : '$prefix,'}\n'
        'uid TEXT NOT NULL UNIQUE, ownerId TEXT NOT NULL, '
        'lenderPartyId TEXT NOT NULL, borrowerPartyId TEXT NOT NULL, '
        'relationshipId TEXT, currency TEXT NOT NULL DEFAULT \'INR\', '
        'calculationVersion TEXT NOT NULL DEFAULT \'legacy-v1\', '
        'CHECK(lenderPartyId <> borrowerPartyId), '
        'CHECK(length(currency)=3 AND currency=upper(currency)), '
        'FOREIGN KEY(ownerId) REFERENCES localOwners(id), '
        'FOREIGN KEY(lenderPartyId) REFERENCES parties(id), '
        'FOREIGN KEY(borrowerPartyId) REFERENCES parties(id), '
        'FOREIGN KEY(relationshipId) REFERENCES relationships(id)'
        '${insertion < 0 ? '' : ','}${sql.substring(position)}';
    await db.execute(sql);
    for (final row in originals['loans']!) {
      final identity = await identityForNewLoan(db, row, ownerId: owner);
      await db.insert('loans_v8', {...row, ...identity});
    }
    // Do not rename the old table: SQLite could retarget child foreign keys.
    await db.execute('DROP TABLE loans');
    await db.execute('ALTER TABLE loans_v8 RENAME TO loans');
    await db.execute('CREATE INDEX loans_owner_lender ON loans(ownerId,lenderPartyId,dateCreated)');
    await db.execute('CREATE INDEX loans_owner_borrower ON loans(ownerId,borrowerPartyId,dateCreated)');
    await db.execute('CREATE INDEX loans_relationship ON loans(relationshipId)');
    await db.execute('CREATE INDEX loanChanges_loan ON loanChanges(loanId,createdAt)');
    await installLoanGuards(db);

    for (final table in originals.entries) {
      final actual = await db.query(table.key, orderBy: 'id');
      if (actual.length != table.value.length) throw StateError('Migration count mismatch: ${table.key}');
      for (var i = 0; i < actual.length; i++) {
        for (final entry in table.value[i].entries) {
          if (actual[i][entry.key] != entry.value) {
            throw StateError('Migration changed ${table.key}.${entry.key}');
          }
        }
      }
    }
    if ((await db.rawQuery('PRAGMA foreign_key_check')).isNotEmpty) {
      throw StateError('Migration reference reconciliation failed.');
    }
    await db.insert('migrationReports', {
      'id': '$owner:v7-v8', 'createdAt': now,
      'payload': jsonEncode({
        'from': 7, 'to': 8, 'counts': {for (final e in originals.entries) e.key: e.value.length},
        'principalTotal': exactTotal(originals['loans']!.map((r) => r['loanAmount'] as num)),
        'settlementTotal': exactTotal(originals['loans']!.map((r) => r['settlementAmount']).whereType<num>()),
        'reconciliation': 'Every original field compared exactly; no financial conversion',
        'currency': 'INR', 'currencyBasis': 'Legacy application rupee convention',
        'settlementsAreRepayments': false,
      }),
    });
  }

  static Future<void> createIdentityTables(DatabaseExecutor db) async {
    for (final sql in [
      '''CREATE TABLE localOwners(id TEXT PRIMARY KEY NOT NULL,selfPartyId TEXT NOT NULL UNIQUE,createdAt TEXT NOT NULL)''',
      '''CREATE TABLE users(id TEXT PRIMARY KEY NOT NULL,phone TEXT,email TEXT,status TEXT NOT NULL,createdAt TEXT NOT NULL,updatedAt TEXT NOT NULL)''',
      '''CREATE TABLE parties(id TEXT PRIMARY KEY NOT NULL,ownerId TEXT NOT NULL,displayName TEXT NOT NULL,phone TEXT,email TEXT,countryCode TEXT,userId TEXT,status TEXT NOT NULL DEFAULT 'ACTIVE' CHECK(status IN ('ACTIVE','ARCHIVED')),createdAt TEXT NOT NULL,updatedAt TEXT NOT NULL,FOREIGN KEY(ownerId) REFERENCES localOwners(id),FOREIGN KEY(userId) REFERENCES users(id))''',
      '''CREATE INDEX parties_owner_name ON parties(ownerId,displayName,id)''',
      '''CREATE TABLE relationships(id TEXT PRIMARY KEY NOT NULL,ownerId TEXT NOT NULL,partyAId TEXT NOT NULL,partyBId TEXT NOT NULL,status TEXT NOT NULL CHECK(status IN ('PENDING','ACTIVE','BLOCKED','ENDED')),createdAt TEXT NOT NULL,updatedAt TEXT NOT NULL,CHECK(partyAId<>partyBId),UNIQUE(ownerId,partyAId,partyBId),FOREIGN KEY(ownerId) REFERENCES localOwners(id),FOREIGN KEY(partyAId) REFERENCES parties(id),FOREIGN KEY(partyBId) REFERENCES parties(id))''',
      '''CREATE TABLE migrationSnapshots(id TEXT PRIMARY KEY NOT NULL,entityType TEXT NOT NULL,sourceId TEXT NOT NULL,payload TEXT NOT NULL)''',
      '''CREATE TABLE migrationReports(id TEXT PRIMARY KEY NOT NULL,createdAt TEXT NOT NULL,payload TEXT NOT NULL)''',
    ]) { await db.execute(sql); }
    for (final table in ['migrationSnapshots', 'migrationReports']) {
      for (final action in ['UPDATE','DELETE']) {
        await db.execute('CREATE TRIGGER ${table}_no_$action BEFORE $action ON $table BEGIN SELECT RAISE(ABORT, \'Migration evidence is immutable\'); END');
      }
    }
    for (final action in ['INSERT', 'UPDATE']) {
      await db.execute('''CREATE TRIGGER relationships_scope_$action BEFORE $action ON relationships
        WHEN NOT EXISTS(SELECT 1 FROM parties WHERE id=NEW.partyAId AND ownerId=NEW.ownerId)
          OR NOT EXISTS(SELECT 1 FROM parties WHERE id=NEW.partyBId AND ownerId=NEW.ownerId)
        BEGIN SELECT RAISE(ABORT,'Relationship ownership mismatch'); END''');
    }
    await db.execute('''CREATE TRIGGER parties_identity_immutable BEFORE UPDATE OF id,ownerId,userId ON parties
      WHEN NEW.id IS NOT OLD.id OR NEW.ownerId IS NOT OLD.ownerId OR NEW.userId IS NOT OLD.userId
      BEGIN SELECT RAISE(ABORT,'Identity linking requires an authenticated migration'); END''');
  }

  static Future<void> installLoanGuards(DatabaseExecutor db) async {
    for (final action in ['INSERT', 'UPDATE']) {
      await db.execute('''CREATE TRIGGER loans_scope_$action BEFORE $action ON loans
        WHEN NOT EXISTS(SELECT 1 FROM parties WHERE id=NEW.lenderPartyId AND ownerId=NEW.ownerId)
          OR NOT EXISTS(SELECT 1 FROM parties WHERE id=NEW.borrowerPartyId AND ownerId=NEW.ownerId)
          OR NOT EXISTS(SELECT 1 FROM localOwners WHERE id=NEW.ownerId AND selfPartyId IN (NEW.lenderPartyId,NEW.borrowerPartyId))
          OR (NEW.relationshipId IS NOT NULL AND NOT EXISTS(
            SELECT 1 FROM relationships WHERE id=NEW.relationshipId AND ownerId=NEW.ownerId
              AND partyAId IN (NEW.lenderPartyId,NEW.borrowerPartyId) AND partyBId IN (NEW.lenderPartyId,NEW.borrowerPartyId)))
        BEGIN SELECT RAISE(ABORT,'Loan participant ownership mismatch'); END''');
    }
    await db.execute('''CREATE TRIGGER loans_identity_immutable BEFORE UPDATE OF uid,ownerId,lenderPartyId,borrowerPartyId ON loans
      WHEN NEW.uid IS NOT OLD.uid OR NEW.ownerId IS NOT OLD.ownerId OR NEW.lenderPartyId IS NOT OLD.lenderPartyId OR NEW.borrowerPartyId IS NOT OLD.borrowerPartyId
      BEGIN SELECT RAISE(ABORT,'Loan participants cannot be silently reassigned'); END''');
  }

  /// Existing UI creates a private external participant; explicit selection can
  /// reuse a Party in either direction. A contact match never links an account.
  static Future<Map<String,Object?>> identityForNewLoan(DatabaseExecutor db, Map<String,Object?> row, {
    String? ownerId, String? counterpartyId, bool borrowing = false, String currency = 'INR', String? uid,
  }) async {
    final owner = (await db.query('localOwners', where: ownerId == null ? null : 'id=?', whereArgs: ownerId == null ? null : [ownerId])).single;
    final id = owner['id'] as String;
    final now = DateTime.now().toUtc().toIso8601String();
    var other = counterpartyId;
    if (other == null) {
      other = newId();
      await db.insert('parties', {
        'id': other, 'ownerId': id, 'displayName': row['depositorName'] ?? '',
        'phone': row['phoneNumber'], 'email': row['email'],
        'status': 'ACTIVE', 'createdAt': now, 'updatedAt': now,
      });
    } else if ((await db.query('parties',where:'id=? AND ownerId=? AND status=?',whereArgs:[other,id,'ACTIVE'])).length != 1) {
      throw StateError('The selected party is unavailable in this workspace.');
    }
    if (other == owner['selfPartyId']) throw ArgumentError('Lender and borrower must differ.');
    if (!RegExp(r'^[A-Z]{3}$').hasMatch(currency)) throw ArgumentError('Invalid currency code.');
    return {
      'uid': uid ?? newId(), 'ownerId': id,
      'lenderPartyId': borrowing ? other : owner['selfPartyId'],
      'borrowerPartyId': borrowing ? owner['selfPartyId'] : other,
      'relationshipId': null, 'currency': currency, 'calculationVersion': 'legacy-v1',
    };
  }

  /// Sum decimal representations exactly for reconciliation, not balance accrual.
  static String exactTotal(Iterable<num> values) {
    var total = BigInt.zero;
    var scale = 0;
    for (final value in values) {
      if (!value.isFinite) throw const FormatException('Nonfinite financial value.');
      final pieces = value.toString().toLowerCase().split('e');
      final decimal = pieces[0].split('.');
      var digits = BigInt.parse(decimal.join());
      var places = (decimal.length == 2 ? decimal[1].length : 0) - (pieces.length == 2 ? int.parse(pieces[1]) : 0);
      if (places < 0) { digits *= BigInt.from(10).pow(-places); places = 0; }
      if (places > scale) { total *= BigInt.from(10).pow(places-scale); scale=places; }
      total += digits * BigInt.from(10).pow(scale-places);
    }
    final sign = total.isNegative ? '-' : '';
    final digits = total.abs().toString().padLeft(scale+1,'0');
    return scale == 0 ? '$sign$digits' : '$sign${digits.substring(0,digits.length-scale)}.${digits.substring(digits.length-scale)}';
  }
}
