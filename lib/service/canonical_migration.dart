import 'dart:math';

import '../db/tostore_database.dart';
import '../domain/calculation_contract.dart';

/// Canonical identity helpers retained by repositories after the clean ToStore
/// cutover. There is intentionally no SQLite schema migration path.
abstract final class CanonicalMigration {
  static const version = 10;

  static String newId() {
    final random = Random.secure();
    final bytes = List.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 15) | 64;
    bytes[8] = (bytes[8] & 63) | 128;
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }

  static Future<Map<String, Object?>> identityForNewLoan(
    DatabaseExecutor db,
    Map<String, Object?> row, {
    String? ownerId,
    String? counterpartyId,
    bool borrowing = false,
    String currency = 'INR',
    String? uid,
  }) async {
    final owners = await db.query(
      'localOwners',
      where: ownerId == null ? null : 'id = ?',
      whereArgs: ownerId == null ? null : [ownerId],
    );
    if (owners.length != 1) {
      throw StateError('A single local owner is required.');
    }
    final owner = owners.single;
    final id = owner['id'] as String;
    final now = DateTime.now().toUtc().toIso8601String();
    var other = counterpartyId;
    if (other == null) {
      other = newId();
      await db.insert('parties', {
        'id': other,
        'ownerId': id,
        'displayName': row['depositorName'] ?? '',
        'phone': row['phoneNumber'],
        'email': row['email'],
        'status': 'ACTIVE',
        'createdAt': now,
        'updatedAt': now,
      });
    } else {
      final party = await db.query(
        'parties',
        where: 'id = ? AND ownerId = ? AND status = ?',
        whereArgs: [other, id, 'ACTIVE'],
      );
      if (party.length != 1) {
        throw StateError(
          'The selected party is unavailable in this workspace.',
        );
      }
    }
    if (other == owner['selfPartyId']) {
      throw ArgumentError('Lender and borrower must differ.');
    }
    if (!RegExp(r'^[A-Z]{3}$').hasMatch(currency)) {
      throw ArgumentError('Invalid currency code.');
    }
    return {
      'uid': uid ?? newId(),
      'ownerId': id,
      'lenderPartyId': borrowing ? other : owner['selfPartyId'],
      'borrowerPartyId': borrowing ? owner['selfPartyId'] : other,
      'relationshipId': null,
      'currency': currency,
      'calculationVersion': CalculationContract.current,
    };
  }

  static String exactTotal(Iterable<num> values) {
    var total = BigInt.zero;
    var scale = 0;
    for (final value in values) {
      if (!value.isFinite) {
        throw const FormatException('Nonfinite financial value.');
      }
      final pieces = value.toString().toLowerCase().split('e');
      final decimal = pieces[0].split('.');
      var digits = BigInt.parse(decimal.join());
      var places =
          (decimal.length == 2 ? decimal[1].length : 0) -
          (pieces.length == 2 ? int.parse(pieces[1]) : 0);
      if (places < 0) {
        digits *= BigInt.from(10).pow(-places);
        places = 0;
      }
      if (places > scale) {
        total *= BigInt.from(10).pow(places - scale);
        scale = places;
      }
      total += digits * BigInt.from(10).pow(scale - places);
    }
    final sign = total.isNegative ? '-' : '';
    final digits = total.abs().toString().padLeft(scale + 1, '0');
    return scale == 0
        ? '$sign$digits'
        : '$sign${digits.substring(0, digits.length - scale)}.${digits.substring(digits.length - scale)}';
  }
}
