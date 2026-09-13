import 'dart:convert';
import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';
import 'package:tostore/tostore.dart';

import '../db/tostore_database.dart';
import '../db/settings_store.dart';
import '../model/family_relation.dart';
import '../model/mortgage_material.dart';
import '../model/weight_unit.dart';
import 'canonical_migration.dart';

final class DatabaseHelper {
  DatabaseHelper._();
  static final instance = DatabaseHelper._();
  static const schemaVersion = 9;
  static const _encodingKeyName = 'loanx.tostore.encoding_key';
  static const _masterKeyName = 'loanx.tostore.master_key';
  LoanxDatabasePort? _database;

  Future<LoanxDatabasePort> get database async => _database ??= await _open();

  Future<SettingsStore> get settingsStore async {
    final db = await database;
    return ToStoreSettingsStore((db as LoanxDatabase).store);
  }

  /// Creates an isolated in-memory adapter for tests and previews.  Callers
  /// still receive the storage port, so test code does not couple to ToStore.
  Future<LoanxDatabasePort> openMemory({String name = 'loanx-test'}) async {
    final store = await ToStore.memory(dbName: name, schemas: schemas);
    return LoanxDatabase(store);
  }

  Future<LoanxDatabasePort> _open() async {
    const secure = FlutterSecureStorage();
    final directory = await getApplicationSupportDirectory();
    final store = await ToStore.open(
      dbPath: directory.path,
      dbName: 'loanx',
      schemas: schemas,
      applyActiveSpaceOnDefault: false,
      config: DataStoreConfig(
        ignoreUnknownFields: false,
        enableJournal: true,
        persistRecoveryOnCommit: true,
        defaultTransactionIsolationLevel: TransactionIsolationLevel.serializable,
        defaultQueryLimit: 0,
        encryptionConfig: EncryptionConfig(
          encryptionType: EncryptionType.aes256Gcm,
          encodingKey: await _key(secure, _encodingKeyName),
          encryptionKey: await _key(secure, _masterKeyName),
          encryptionScope: EncryptionScope.full,
        ),
      ),
    );
    final db = LoanxDatabase(store);
    await db.setVersion(schemaVersion);
    await _seed(db);
    return db;
  }

  static Future<String> _key(FlutterSecureStorage storage, String name) async {
    final existing = await storage.read(key: name);
    if (existing != null && existing.isNotEmpty) return existing;
    final random = Random.secure();
    final value = base64UrlEncode(List<int>.generate(32, (_) => random.nextInt(256)));
    await storage.write(key: name, value: value);
    return value;
  }

  static Future<void> _seed(LoanxDatabasePort db) async {
    if ((await db.query('localOwners')).isEmpty) {
      final owner = CanonicalMigration.newId();
      final self = CanonicalMigration.newId();
      final now = DateTime.now().toUtc().toIso8601String();
      await db.transaction((tx) async {
        await tx.insert('localOwners', {'id': owner, 'selfPartyId': self, 'createdAt': now});
        await tx.insert('parties', {'id': self, 'ownerId': owner, 'displayName': 'Local owner', 'status': 'ACTIVE', 'createdAt': now, 'updatedAt': now});
      });
    }
    for (final name in const ['Husband', 'Father', 'Wife']) {
      await db.insert(FamilyRelation.tableName, {'name': name, 'isAddedByUser': 0}, conflictAlgorithm: ConflictAlgorithm.ignore);
    }
    for (final name in const ['Ring','Anklet','Bracelet','Armlet','Chain','Ear-Ring','Head-Locket','Medal','Necklace','Locket','Neck band']) {
      await db.insert(MortgageMaterial.tableName, {'name': name, 'isAddedByUser': 0}, conflictAlgorithm: ConflictAlgorithm.ignore);
    }
    for (final unit in const [WeightUnit(name: 'Gram', symbol: 'g'), WeightUnit(name: 'Kilogram', symbol: 'kg'), WeightUnit(name: 'Milligram', symbol: 'mg'), WeightUnit(name: 'Tola', symbol: 'tola')]) {
      await db.insert(WeightUnit.tableName, unit.toJson(), conflictAlgorithm: ConflictAlgorithm.ignore);
    }
    await db.flush();
  }

  static final List<TableSchema> schemas = [
    _table('familyRelations', [_text('name', nullable: false, unique: true), _int('isAddedByUser', defaultValue: 0)]),
    _table('mortgageMaterials', [_text('name', nullable: false, unique: true), _int('isAddedByUser', defaultValue: 0)]),
    _table('weightUnits', [_text('name', nullable: false), _text('symbol', nullable: false, unique: true), _int('isAddedByUser', nullable: false, defaultValue: 0)]),
    _table('loans', [
      _text('depositorName'), _text('phoneNumber'), _text('email'), _text('relativeName'), _text('address'),
      _double('loanAmount'), _double('interestRate'), _double('weight'), _text('weightUnit', nullable: false, defaultValue: 'g'),
      _int('interestType'), _int('interestFrequency'), _int('mortgageTermYears', nullable: false, defaultValue: 5),
      _int('lockInDays', nullable: false, defaultValue: 0), _double('earlyRedemptionCharge', nullable: false, defaultValue: 0),
      _text('additionalDetails'), _text('termsAndConditions', nullable: false, defaultValue: ''), _text('dateCreated'), _text('dateFinished'),
      _text('completedBy', nullable: false, defaultValue: ''), _double('settlementAmount'), _text('completionReference', nullable: false, defaultValue: ''),
      _text('completionNotes', nullable: false, defaultValue: ''), _text('familyRelationId'), _text('mortgageMaterialId'),
      _text('uid', unique: true), _text('ownerId', indexed: true), _text('lenderPartyId', indexed: true),
      _text('borrowerPartyId', indexed: true), _text('relationshipId', indexed: true), _text('currency', nullable: false, defaultValue: 'INR'),
      _text('calculationVersion', nullable: false, defaultValue: 'legacy-v1'),
    ]),
    _table('loanChanges', [_text('loanId', nullable: false, indexed: true), _text('description', nullable: false), _text('createdAt', nullable: false)]),
    _stringTable('localOwners', [_text('selfPartyId', nullable: false, unique: true), _text('createdAt', nullable: false)]),
    _stringTable('users', [_text('phone'), _text('email'), _text('status', nullable: false), _text('createdAt', nullable: false), _text('updatedAt', nullable: false)]),
    _stringTable('parties', [_text('ownerId', nullable: false, indexed: true), _text('displayName', nullable: false, indexed: true), _text('phone'), _text('email'), _text('countryCode'), _text('userId'), _text('status', nullable: false, defaultValue: 'ACTIVE'), _text('createdAt', nullable: false), _text('updatedAt', nullable: false)]),
    _stringTable('relationships', [_text('ownerId', nullable: false, indexed: true), _text('partyAId', nullable: false), _text('partyBId', nullable: false), _text('status', nullable: false), _text('createdAt', nullable: false), _text('updatedAt', nullable: false)]),
    _stringTable('migrationSnapshots', [_text('entityType', nullable: false), _text('sourceId', nullable: false), _text('payload', nullable: false)]),
    _stringTable('migrationReports', [_text('createdAt', nullable: false), _text('payload', nullable: false)]),
  ];

  static TableSchema _table(String name, List<FieldSchema> fields) => TableSchema(name: name, tableId: 'loanx.$name', primaryKeyConfig: const PrimaryKeyConfig(type: PrimaryKeyType.sequential), fields: fields);
  static TableSchema _stringTable(String name, List<FieldSchema> fields) => TableSchema(name: name, tableId: 'loanx.$name', primaryKeyConfig: const PrimaryKeyConfig(type: PrimaryKeyType.none), fields: fields);
  static FieldSchema _text(String name, {bool nullable = true, bool unique = false, bool indexed = false, String? defaultValue}) => FieldSchema(name: name, type: DataType.text, nullable: nullable, unique: unique, createIndex: indexed, defaultValue: defaultValue);
  static FieldSchema _int(String name, {bool nullable = true, int? defaultValue}) => FieldSchema(name: name, type: DataType.integer, nullable: nullable, defaultValue: defaultValue);
  static FieldSchema _double(String name, {bool nullable = true, num? defaultValue}) => FieldSchema(name: name, type: DataType.double, nullable: nullable, defaultValue: defaultValue);

  Future<void> close() async { final db = _database; _database = null; await db?.close(); }
}
