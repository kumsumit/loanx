import 'dart:math';

/// Offline-safe UUID v4. IDs convey no identity verification or authorization.
String domainId() {
  final random = Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  final hex = bytes.map((v) => v.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
      '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
}

/// An authenticated account; financial roles are deliberately absent.
class User {
  const User({
    required this.id,
    this.phone,
    this.email,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  factory User.fromMap(Map<String, Object?> row) => User(
    id: row['id'] as String,
    phone: row['phone'] as String?,
    email: row['email'] as String?,
    status: row['status'] as String,
    createdAt: DateTime.parse(row['createdAt'] as String),
    updatedAt: DateTime.parse(row['updatedAt'] as String),
  );
  final String id;
  final String? phone;
  final String? email;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;
}

class Party {
  const Party({
    required this.id,
    required this.ownerId,
    required this.displayName,
    this.phone,
    this.email,
    this.countryCode,
    this.userId,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Party.fromMap(Map<String, Object?> row) => Party(
    id: row['id'] as String,
    ownerId: row['ownerId'] as String,
    displayName: row['displayName'] as String,
    phone: row['phone'] as String?,
    email: row['email'] as String?,
    countryCode: row['countryCode'] as String?,
    userId: row['userId'] as String?,
    status: row['status'] as String,
    createdAt: DateTime.parse(row['createdAt'] as String),
    updatedAt: DateTime.parse(row['updatedAt'] as String),
  );

  final String id;
  final String ownerId;
  final String displayName;
  final String? phone;
  final String? email;
  final String? countryCode;
  final String? userId;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;
  bool get isExternal => userId == null;
}

enum RelationshipStatus { pending, active, blocked, ended }

class Relationship {
  const Relationship({
    required this.id,
    required this.ownerId,
    required this.partyAId,
    required this.partyBId,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Relationship.fromMap(Map<String, Object?> row) => Relationship(
    id: row['id'] as String,
    ownerId: row['ownerId'] as String,
    partyAId: row['partyAId'] as String,
    partyBId: row['partyBId'] as String,
    status: RelationshipStatus.values.byName(
      (row['status'] as String).toLowerCase(),
    ),
    createdAt: DateTime.parse(row['createdAt'] as String),
    updatedAt: DateTime.parse(row['updatedAt'] as String),
  );

  final String id;
  final String ownerId;
  final String partyAId;
  final String partyBId;
  final RelationshipStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;
}
