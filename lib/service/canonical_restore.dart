import 'package:sqflite_sqlcipher/sqflite.dart';

/// Restores a local-only canonical backup without identifying people by contact
/// details. A different local workspace is explicitly mapped onto this device.
class CanonicalRestore {
  static Future<void> merge(Database source, Database target) async {
    if (await source.getVersion() != 8) {
      throw const FormatException('Unsupported canonical backup version.');
    }
    final integrity = await source.rawQuery('PRAGMA integrity_check');
    if (integrity.length != 1 ||
        integrity.single.values.single != 'ok' ||
        (await source.rawQuery('PRAGMA foreign_key_check')).isNotEmpty) {
      throw const FormatException('Invalid backup database integrity.');
    }
    const tables = [
      'localOwners',
      'users',
      'parties',
      'relationships',
      'familyRelations',
      'mortgageMaterials',
      'weightUnits',
      'loans',
      'loanChanges',
      'migrationSnapshots',
      'migrationReports',
    ];
    final rows = <String, List<Map<String, Object?>>>{};
    for (final table in tables) {
      rows[table] = await source.query(table);
    }
    if (rows['localOwners']!.length != 1 ||
        rows['users']!.isNotEmpty ||
        rows['parties']!.any((p) => p['userId'] != null)) {
      throw const FormatException(
        'Only a single local workspace can be restored.',
      );
    }
    final sourceOwner = rows['localOwners']!.single;
    final sourceOwnerId = sourceOwner['id'];
    final sourceSelfId = sourceOwner['selfPartyId'];
    final sourceParties = {for (final p in rows['parties']!) p['id']: p};
    if (!sourceParties.containsKey(sourceSelfId)) {
      throw const FormatException('Missing workspace participant.');
    }
    for (final table in ['parties', 'relationships', 'loans']) {
      if (rows[table]!.any((row) => row['ownerId'] != sourceOwnerId)) {
        throw const FormatException('Backup contains another workspace.');
      }
    }
    for (final loan in rows['loans']!) {
      if (!sourceParties.containsKey(loan['lenderPartyId']) ||
          !sourceParties.containsKey(loan['borrowerPartyId']) ||
          loan['lenderPartyId'] == loan['borrowerPartyId'] ||
          loan['uid'] is! String ||
          (loan['uid'] as String).isEmpty) {
        throw const FormatException('Invalid loan participant or identity.');
      }
      for (final field in [
        'loanAmount',
        'interestRate',
        'weight',
        'earlyRedemptionCharge',
        'settlementAmount',
      ]) {
        final value = loan[field];
        if (value != null && (value is! num || !value.isFinite || value < 0)) {
          throw FormatException('Invalid financial field: $field.');
        }
      }
      if (loan['loanAmount'] == null ||
          DateTime.tryParse('${loan['dateCreated']}') == null ||
          (loan['dateFinished'] != null &&
              DateTime.tryParse('${loan['dateFinished']}') == null)) {
        throw const FormatException('Invalid loan amount or date.');
      }
    }
    final relationshipIds = {for (final r in rows['relationships']!) r['id']};
    for (final r in rows['relationships']!) {
      if (!sourceParties.containsKey(r['partyAId']) ||
          !sourceParties.containsKey(r['partyBId']) ||
          r['partyAId'] == r['partyBId']) {
        throw const FormatException('Invalid relationship participants.');
      }
    }
    for (final loan in rows['loans']!) {
      if (loan['relationshipId'] != null &&
          !relationshipIds.contains(loan['relationshipId'])) {
        throw const FormatException('Missing loan relationship.');
      }
    }
    await target.transaction((tx) async {
      final owners = await tx.query('localOwners');
      if (owners.length != 1) {
        throw const FormatException('Invalid target workspace.');
      }
      final owner = owners.single;
      Object? partyId(Object? id) =>
          id == sourceSelfId ? owner['selfPartyId'] : id;
      for (final p in rows['parties']!) {
        if (p['id'] == sourceSelfId) continue;
        if (p['id'] == owner['selfPartyId']) {
          throw const FormatException(
            'Participant identity conflicts with workspace.',
          );
        }
        await _insertExact(tx, 'parties', {...p, 'ownerId': owner['id']});
      }
      for (final r in rows['relationships']!) {
        await _insertExact(tx, 'relationships', {
          ...r,
          'ownerId': owner['id'],
          'partyAId': partyId(r['partyAId']),
          'partyBId': partyId(r['partyBId']),
        });
      }
      final lookupIds = <String, Map<Object?, int>>{};
      for (final table in [
        'familyRelations',
        'mortgageMaterials',
        'weightUnits',
      ]) {
        final ids = <Object?, int>{};
        final key = table == 'weightUnits' ? 'symbol' : 'name';
        for (final row in rows[table]!) {
          final existing = await tx.query(
            table,
            where: '$key = ?',
            whereArgs: [row[key]],
          );
          ids[row['id']] = existing.isEmpty
              ? await tx.insert(
                  table,
                  Map<String, Object?>.from(row)..remove('id'),
                )
              : existing.single['id'] as int;
        }
        lookupIds[table] = ids;
      }
      final loanIds = <Object?, int>{};
      for (final row in rows['loans']!) {
        final values = Map<String, Object?>.from(row)..remove('id');
        values['ownerId'] = owner['id'];
        values['lenderPartyId'] = partyId(row['lenderPartyId']);
        values['borrowerPartyId'] = partyId(row['borrowerPartyId']);
        for (final entry in {
          'familyRelationId': 'familyRelations',
          'mortgageMaterialId': 'mortgageMaterials',
        }.entries) {
          final original = row[entry.key];
          if (original != null &&
              !lookupIds[entry.value]!.containsKey(original)) {
            throw const FormatException('Missing loan lookup reference.');
          }
          values[entry.key] = lookupIds[entry.value]![original];
        }
        final existing = await tx.query(
          'loans',
          where: 'uid = ?',
          whereArgs: [row['uid']],
        );
        if (existing.isNotEmpty) {
          _compare(values, existing.single, 'loan');
          loanIds[row['id']] = existing.single['id'] as int;
        } else {
          loanIds[row['id']] = await tx.insert('loans', values);
        }
      }
      for (final change in rows['loanChanges']!) {
        final loanId = loanIds[change['loanId']];
        if (loanId == null) throw const FormatException('Missing audit loan.');
        final values = {...change, 'loanId': loanId}..remove('id');
        final existing = await tx.query(
          'loanChanges',
          where: 'loanId = ? AND description = ? AND createdAt = ?',
          whereArgs: [loanId, change['description'], change['createdAt']],
        );
        if (existing.isEmpty) await tx.insert('loanChanges', values);
      }
      for (final table in ['migrationSnapshots', 'migrationReports']) {
        for (final row in rows[table]!) {
          await _insertExact(tx, table, row);
        }
      }
      if ((await tx.rawQuery('PRAGMA foreign_key_check')).isNotEmpty) {
        throw const FormatException('Restored references failed validation.');
      }
    });
  }

  static Future<void> _insertExact(
    DatabaseExecutor tx,
    String table,
    Map<String, Object?> values,
  ) async {
    final existing = await tx.query(
      table,
      where: 'id = ?',
      whereArgs: [values['id']],
    );
    if (existing.isEmpty) {
      await tx.insert(table, values);
    } else {
      _compare(values, existing.single, table);
    }
  }

  static void _compare(
    Map<String, Object?> expected,
    Map<String, Object?> actual,
    String entity,
  ) {
    if (expected.entries.any((entry) => actual[entry.key] != entry.value)) {
      throw FormatException(
        'Conflicting $entity in backup; no data was imported.',
      );
    }
  }
}
