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
  static const schemaVersion = 11;
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
        defaultTransactionIsolationLevel:
            TransactionIsolationLevel.serializable,
        // ToStore rejects queries when this is zero. The compatibility adapter
        // explicitly paginates SQL-style unbounded reads, while this default
        // also protects the few native ToStore calls from accidental scans.
        defaultQueryLimit: 1000,
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
    final value = base64UrlEncode(
      List<int>.generate(32, (_) => random.nextInt(256)),
    );
    await storage.write(key: name, value: value);
    return value;
  }

  static Future<void> _seed(LoanxDatabasePort db) async {
    if ((await db.query('localOwners')).isEmpty) {
      final owner = CanonicalMigration.newId();
      final self = CanonicalMigration.newId();
      final now = DateTime.now().toUtc().toIso8601String();
      await db.transaction((tx) async {
        await tx.insert('localOwners', {
          'id': owner,
          'selfPartyId': self,
          'createdAt': now,
        });
        await tx.insert('parties', {
          'id': self,
          'ownerId': owner,
          'displayName': 'Local owner',
          'status': 'ACTIVE',
          'createdAt': now,
          'updatedAt': now,
        });
      });
    }
    for (final name in const ['Husband', 'Father', 'Wife']) {
      await db.insert(FamilyRelation.tableName, {
        'name': name,
        'isAddedByUser': 0,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    }
    for (final name in const [
      'Ring',
      'Anklet',
      'Bracelet',
      'Armlet',
      'Chain',
      'Ear-Ring',
      'Head-Locket',
      'Medal',
      'Necklace',
      'Locket',
      'Neck band',
    ]) {
      await db.insert(MortgageMaterial.tableName, {
        'name': name,
        'isAddedByUser': 0,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    }
    for (final unit in const [
      WeightUnit(name: 'Gram', symbol: 'g'),
      WeightUnit(name: 'Kilogram', symbol: 'kg'),
      WeightUnit(name: 'Milligram', symbol: 'mg'),
      WeightUnit(name: 'Tola', symbol: 'tola'),
    ]) {
      await db.insert(
        WeightUnit.tableName,
        unit.toJson(),
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }
    await db.flush();
  }

  static final List<TableSchema> schemas = [
    _table('familyRelations', [
      _text('name', nullable: false, unique: true),
      _int('isAddedByUser', defaultValue: 0),
    ]),
    _table('mortgageMaterials', [
      _text('name', nullable: false, unique: true),
      _int('isAddedByUser', defaultValue: 0),
    ]),
    _table('weightUnits', [
      _text('name', nullable: false),
      _text('symbol', nullable: false, unique: true),
      _int('isAddedByUser', nullable: false, defaultValue: 0),
    ]),
    _table('loans', [
      _text('depositorName'),
      _text('phoneNumber'),
      _text('email'),
      _text('relativeName'),
      _text('address'),
      _double('loanAmount'),
      _double('interestRate'),
      _double('weight'),
      _text('weightUnit', nullable: false, defaultValue: 'g'),
      _int('interestType'),
      _int('interestFrequency'),
      _int('mortgageTermYears', nullable: false, defaultValue: 5),
      _int('lockInDays', nullable: false, defaultValue: 0),
      _double('earlyRedemptionCharge', nullable: false, defaultValue: 0),
      _text('additionalDetails'),
      _text('termsAndConditions', nullable: false, defaultValue: ''),
      _text('dateCreated'),
      _text('dateFinished'),
      _text('completedBy', nullable: false, defaultValue: ''),
      _double('settlementAmount'),
      _text('completionReference', nullable: false, defaultValue: ''),
      _text('completionNotes', nullable: false, defaultValue: ''),
      _text('familyRelationId'),
      _text('mortgageMaterialId'),
      _text('uid', unique: true),
      _text('ownerId', indexed: true),
      _text('lenderPartyId', indexed: true),
      _text('borrowerPartyId', indexed: true),
      _text('relationshipId', indexed: true),
      _text('currency', nullable: false, defaultValue: 'INR'),
      _text('calculationVersion', nullable: false, defaultValue: 'legacy-v1'),
    ]),
    _table('loanChanges', [
      _text('loanId', nullable: false, indexed: true),
      _text('description', nullable: false),
      _text('createdAt', nullable: false),
    ]),
    _stringTable('localOwners', [
      _text('selfPartyId', nullable: false, unique: true),
      _text('createdAt', nullable: false),
    ]),
    _stringTable('users', [
      _text('phone'),
      _text('email'),
      _text('status', nullable: false),
      _text('createdAt', nullable: false),
      _text('updatedAt', nullable: false),
    ]),
    _stringTable('parties', [
      _text('ownerId', nullable: false, indexed: true),
      _text('displayName', nullable: false, indexed: true),
      _text('phone'),
      _text('email'),
      _text('countryCode'),
      _text('userId'),
      _text('status', nullable: false, defaultValue: 'ACTIVE'),
      _text('createdAt', nullable: false),
      _text('updatedAt', nullable: false),
    ]),
    _stringTable('relationships', [
      _text('ownerId', nullable: false, indexed: true),
      _text('partyAId', nullable: false),
      _text('partyBId', nullable: false),
      _text('status', nullable: false),
      _text('createdAt', nullable: false),
      _text('updatedAt', nullable: false),
    ]),
    _stringTable('financialEvents', [
      _text('ownerId', nullable: false, indexed: true),
      _text('loanUid', nullable: false, indexed: true),
      _text('type', nullable: false),
      _text('amountMinor', nullable: false),
      _text('currency', nullable: false),
      _int('currencyScale', nullable: false),
      _text('effectiveDate', nullable: false),
      _text('recordedAt', nullable: false),
      _text('paymentMethod'),
      _text('referenceNumber'),
      _text('notes'),
      _text('createdBy', nullable: false),
      _text('reversesEventId'),
      _text('payloadHash', nullable: false),
    ]),
    _stringTable('auditEvents', [
      _text('ownerId', nullable: false, indexed: true),
      _text('actorId', nullable: false),
      _text('entityType', nullable: false),
      _text('entityId', nullable: false, indexed: true),
      _text('action', nullable: false),
      _text('occurredAt', nullable: false),
      _text('correlationId', nullable: false),
    ]),
    _stringTable('migrationSnapshots', [
      _text('entityType', nullable: false),
      _text('sourceId', nullable: false),
      _text('payload', nullable: false),
    ]),
    _stringTable('migrationReports', [
      _text('createdAt', nullable: false),
      _text('payload', nullable: false),
    ]),
    _stringTable('conversations', [
      _text('ownerId', nullable: false, indexed: true),
      _text('type', nullable: false),
      _text('relationshipId'),
      _text('loanUid'),
      _text('title', nullable: false),
      _text('status', nullable: false, defaultValue: 'ACTIVE'),
      _text('createdAt', nullable: false),
      _text('updatedAt', nullable: false),
    ]),
    _stringTable('conversationParticipants', [
      _text('ownerId', nullable: false, indexed: true),
      _text('conversationId', nullable: false, indexed: true),
      _text('partyId', nullable: false, indexed: true),
      _text('status', nullable: false),
      _text('joinedAt', nullable: false),
    ]),
    _stringTable('messages', [
      _text('ownerId', nullable: false, indexed: true),
      _text('conversationId', nullable: false, indexed: true),
      _text('senderPartyId', nullable: false),
      _text('kind', nullable: false),
      _text('body', nullable: false),
      _text('clientOperationId', nullable: false, indexed: true),
      _text('payloadHash', nullable: false),
      _text('createdAt', nullable: false),
      _text('persistedAt', nullable: false),
      _text('deliveredAt'),
      _text('readAt'),
    ]),
    _stringTable('notifications', [
      _text('ownerId', nullable: false, indexed: true),
      _text('recipientPartyId', nullable: false, indexed: true),
      _text('type', nullable: false),
      _text('entityType'),
      _text('entityId'),
      _text('title', nullable: false),
      _text('body', nullable: false),
      _text('createdAt', nullable: false),
      _text('readAt'),
    ]),
    _stringTable('sharedResources', [
      _text('ownerId', nullable: false, indexed: true),
      _text('loanUid', nullable: false, indexed: true),
      _text('recipientPartyId', nullable: false, indexed: true),
      _text('resourceType', nullable: false),
      _text('resourceId', nullable: false),
      _text('visibility', nullable: false),
      _text('sharedAt', nullable: false),
      _text('revokedAt'),
    ]),
    _stringTable('reminders', [
      _text('ownerId', nullable: false, indexed: true),
      _text('loanUid', nullable: false, indexed: true),
      _text('recipientPartyId', nullable: false),
      _text('dueDate', nullable: false),
      _text('channel', nullable: false),
      _text('idempotencyKey', nullable: false, indexed: true),
      _text('status', nullable: false),
      _text('createdAt', nullable: false),
      _text('sentAt'),
    ]),
    _stringTable('reports', [
      _text('ownerId', nullable: false, indexed: true),
      _text('reporterPartyId', nullable: false),
      _text('reportedPartyId', nullable: false),
      _text('conversationId'),
      _text('reason', nullable: false),
      _text('createdAt', nullable: false),
    ]),
  ];

  static TableSchema _table(String name, List<FieldSchema> fields) =>
      TableSchema(
        name: name,
        tableId: 'loanx.$name',
        primaryKeyConfig: const PrimaryKeyConfig(
          type: PrimaryKeyType.sequential,
        ),
        fields: fields,
      );
  static TableSchema _stringTable(String name, List<FieldSchema> fields) =>
      TableSchema(
        name: name,
        tableId: 'loanx.$name',
        primaryKeyConfig: const PrimaryKeyConfig(type: PrimaryKeyType.none),
        fields: fields,
      );
  static FieldSchema _text(
    String name, {
    bool nullable = true,
    bool unique = false,
    bool indexed = false,
    String? defaultValue,
  }) => FieldSchema(
    name: name,
    type: DataType.text,
    nullable: nullable,
    unique: unique,
    createIndex: indexed,
    defaultValue: defaultValue,
  );
  static FieldSchema _int(
    String name, {
    bool nullable = true,
    int? defaultValue,
  }) => FieldSchema(
    name: name,
    type: DataType.integer,
    nullable: nullable,
    defaultValue: defaultValue,
  );
  static FieldSchema _double(
    String name, {
    bool nullable = true,
    num? defaultValue,
  }) => FieldSchema(
    name: name,
    type: DataType.double,
    nullable: nullable,
    defaultValue: defaultValue,
  );

  Future<void> close() async {
    final db = _database;
    _database = null;
    await db?.close();
  }
}
