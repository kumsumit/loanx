import 'package:sqflite_sqlcipher/sqflite.dart';

import '../domain/party.dart';

/// A private local workspace, never a substitute for server authorization.
class PartyRepository {
  PartyRepository(this.database, {required this.ownerId});
  final Database database;
  final String ownerId;

  Future<Party> get(String id) async {
    final rows = await database.query(
      'parties',
      where: 'id = ? AND ownerId = ?',
      whereArgs: [id, ownerId],
      limit: 1,
    );
    if (rows.isEmpty) {
      throw StateError('Party is unavailable in this workspace');
    }
    return Party.fromMap(rows.single);
  }

  Future<List<Party>> list({int limit = 50, int offset = 0}) async {
    if (limit < 1 || limit > 200 || offset < 0) {
      throw ArgumentError('Invalid pagination');
    }
    final rows = await database.query(
      'parties',
      where: 'ownerId = ?',
      whereArgs: [ownerId],
      orderBy: 'displayName COLLATE NOCASE, id',
      limit: limit,
      offset: offset,
    );
    return rows.map(Party.fromMap).toList(growable: false);
  }

  Future<Party> createExternalParty({
    required String displayName,
    String? phone,
    String? email,
    String? countryCode,
  }) async {
    final values = _contact(displayName, phone, email, countryCode);
    final id = domainId();
    final now = DateTime.now().toUtc().toIso8601String();
    await database.transaction((txn) async {
      await _owner(txn);
      await txn.insert('parties', {
        ...values,
        'id': id,
        'ownerId': ownerId,
        'userId': null,
        'status': 'ACTIVE',
        'createdAt': now,
        'updatedAt': now,
      });
    });
    return get(id);
  }

  /// Editing contacts cannot link an account or change verification state.
  Future<Party> updateContact(
    String id, {
    required String displayName,
    String? phone,
    String? email,
    String? countryCode,
  }) async {
    final values = _contact(displayName, phone, email, countryCode);
    final changed = await database.update(
      'parties',
      {...values, 'updatedAt': DateTime.now().toUtc().toIso8601String()},
      where: 'id = ? AND ownerId = ?',
      whereArgs: [id, ownerId],
    );
    if (changed != 1) {
      throw StateError('Party is unavailable in this workspace');
    }
    return get(id);
  }

  /// Records pending local intent only. Activation requires verified consent
  /// through the future authenticated connection service.
  Future<Relationship> createRelationship({
    required String partyAId,
    required String partyBId,
    String? id,
  }) async {
    if (partyAId == partyBId) throw ArgumentError('Distinct parties required');
    final key = id ?? domainId();
    if (!RegExp(r'^[a-zA-Z0-9_-]{1,128}$').hasMatch(key)) {
      throw ArgumentError('Invalid operation ID');
    }
    final pair = [partyAId, partyBId]..sort();
    return database.transaction((txn) async {
      await _owner(txn);
      for (final party in pair) {
        final rows = await txn.query(
          'parties',
          columns: ['id'],
          where: 'id = ? AND ownerId = ?',
          whereArgs: [party, ownerId],
        );
        if (rows.isEmpty) {
          throw StateError('Party is unavailable in this workspace');
        }
      }
      final previous = await txn.query(
        'relationships',
        where: 'id = ?',
        whereArgs: [key],
      );
      if (previous.isNotEmpty) {
        final row = previous.single;
        if (row['ownerId'] != ownerId ||
            row['partyAId'] != pair[0] ||
            row['partyBId'] != pair[1]) {
          throw StateError('Operation ID was already used');
        }
        return Relationship.fromMap(row);
      }
      final existing = await txn.query(
        'relationships',
        where: 'ownerId = ? AND partyAId = ? AND partyBId = ?',
        whereArgs: [ownerId, ...pair],
      );
      if (existing.isNotEmpty) {
        throw StateError('Relationship already exists for these parties');
      }
      final now = DateTime.now().toUtc().toIso8601String();
      final values = <String, Object?>{
        'id': key,
        'ownerId': ownerId,
        'partyAId': pair[0],
        'partyBId': pair[1],
        'status': 'PENDING',
        'createdAt': now,
        'updatedAt': now,
      };
      await txn.insert('relationships', values);
      return Relationship.fromMap(values);
    });
  }

  Future<void> _owner(DatabaseExecutor txn) async {
    if ((await txn.query(
      'localOwners',
      columns: ['id'],
      where: 'id = ?',
      whereArgs: [ownerId],
    )).isEmpty) {
      throw StateError('Local workspace does not exist');
    }
  }

  Map<String, Object?> _contact(
    String name,
    String? phone,
    String? email,
    String? countryCode,
  ) {
    String? bounded(String? value, int max) {
      final result = value?.trim();
      if (result == null || result.isEmpty) return null;
      if (result.length > max || RegExp(r'[\x00-\x1f\x7f]').hasMatch(result)) {
        throw ArgumentError('Contact field is invalid');
      }
      return result;
    }

    final displayName = bounded(name, 200);
    if (displayName == null) throw ArgumentError('Display name is required');
    final country = bounded(countryCode, 2)?.toUpperCase();
    if (country != null && !RegExp(r'^[A-Z]{2}$').hasMatch(country)) {
      throw ArgumentError('Country must be an ISO two-letter code');
    }
    return {
      'displayName': displayName,
      'phone': bounded(phone, 64),
      'email': bounded(email, 254),
      'countryCode': country,
    };
  }
}
