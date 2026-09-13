import 'dart:convert';
import 'package:crypto/crypto.dart';
import '../db/tostore_database.dart';
import '../domain/connected.dart';
import '../domain/party.dart';

/// Offline store for the connected experience. All reads are owner scoped;
/// the server remains authoritative for remote membership and entitlements.
final class ConnectedRepository {
  ConnectedRepository(
    this.database, {
    required this.ownerId,
    required this.selfPartyId,
  });
  final Database database;
  final String ownerId, selfPartyId;

  Future<Conversation> createConversation({
    required ConversationType type,
    required String title,
    required List<String> participantPartyIds,
    String? relationshipId,
    String? loanUid,
    String? operationId,
  }) async {
    final id = operationId ?? domainId();
    _id(id);
    final cleanTitle = _text(title, 200, true)!;
    if (!participantPartyIds.contains(selfPartyId) ||
        participantPartyIds.toSet().length < 2) {
      throw ArgumentError(
        'A conversation requires self and another participant',
      );
    }
    return database.transaction((tx) async {
      await _owner(tx);
      for (final partyId in participantPartyIds.toSet()) {
        await _party(tx, partyId);
      }
      if (relationshipId != null) {
        final rows = await tx.query(
          'relationships',
          where: 'id = ? AND ownerId = ?',
          whereArgs: [relationshipId, ownerId],
        );
        if (rows.isEmpty || rows.single['status'] == 'BLOCKED') {
          throw StateError('Relationship is unavailable');
        }
      }
      final previous = await tx.query(
        'conversations',
        where: 'id = ?',
        whereArgs: [id],
      );
      if (previous.isNotEmpty) {
        final row = previous.single;
        if (row['ownerId'] != ownerId ||
            row['type'] != type.name.toUpperCase() ||
            row['title'] != cleanTitle) {
          throw StateError('Operation ID was already used with different data');
        }
        return _conversation(row);
      }
      final now = DateTime.now().toUtc().toIso8601String();
      final row = <String, Object?>{
        'id': id,
        'ownerId': ownerId,
        'type': type.name.toUpperCase(),
        'relationshipId': relationshipId,
        'loanUid': loanUid,
        'title': cleanTitle,
        'status': 'ACTIVE',
        'createdAt': now,
        'updatedAt': now,
      };
      await tx.insert('conversations', row);
      for (final partyId in participantPartyIds.toSet()) {
        await tx.insert('conversationParticipants', {
          'id': '$id:$partyId',
          'ownerId': ownerId,
          'conversationId': id,
          'partyId': partyId,
          'status': 'ACTIVE',
          'joinedAt': now,
        });
      }
      return _conversation(row);
    });
  }

  Future<ChatMessage> sendMessage({
    required String conversationId,
    required MessageKind kind,
    required String body,
    required String operationId,
  }) async {
    _id(operationId);
    final clean = _text(body, 4000, true)!;
    if (kind != MessageKind.text && kind != MessageKind.system) {
      throw ArgumentError(
        'Attachments and financial references require typed metadata',
      );
    }
    final payloadHash = sha256
        .convert(utf8.encode('$conversationId|${kind.name}|$clean'))
        .toString();
    return database.transaction((tx) async {
      await _membership(tx, conversationId);
      final previous = await tx.query(
        'messages',
        where: 'id = ?',
        whereArgs: [operationId],
      );
      if (previous.isNotEmpty) {
        if (previous.single['ownerId'] != ownerId ||
            previous.single['payloadHash'] != payloadHash) {
          throw StateError('Operation ID was already used with different data');
        }
        return _message(previous.single);
      }
      final now = DateTime.now().toUtc().toIso8601String();
      final row = <String, Object?>{
        'id': operationId,
        'ownerId': ownerId,
        'conversationId': conversationId,
        'senderPartyId': selfPartyId,
        'kind': kind.name.toUpperCase(),
        'body': clean,
        'clientOperationId': operationId,
        'payloadHash': payloadHash,
        'createdAt': now,
        'persistedAt': now,
      };
      await tx.insert('messages', row);
      await tx.update(
        'conversations',
        {'updatedAt': now},
        where: 'id = ? AND ownerId = ?',
        whereArgs: [conversationId, ownerId],
      );
      return _message(row);
    });
  }

  Future<List<ChatMessage>> messages(
    String conversationId, {
    int limit = 50,
    int offset = 0,
  }) async {
    if (limit < 1 || limit > 100 || offset < 0) {
      throw ArgumentError('Invalid pagination');
    }
    await _membership(database, conversationId);
    return (await database.query(
      'messages',
      where: 'ownerId = ? AND conversationId = ?',
      whereArgs: [ownerId, conversationId],
      orderBy: 'createdAt DESC, id DESC',
      limit: limit,
      offset: offset,
    )).map(_message).toList();
  }

  Future<void> markDelivered(String messageId) =>
      _mark(messageId, 'deliveredAt');
  Future<void> markRead(String messageId) => _mark(messageId, 'readAt');
  Future<void> _mark(String id, String field) async {
    final rows = await database.query(
      'messages',
      where: 'id = ? AND ownerId = ?',
      whereArgs: [id, ownerId],
    );
    if (rows.isEmpty) throw StateError('Message is unavailable');
    await _membership(database, rows.single['conversationId'] as String);
    await database.update(
      'messages',
      {field: DateTime.now().toUtc().toIso8601String()},
      where: 'id = ? AND ownerId = ?',
      whereArgs: [id, ownerId],
    );
  }

  Future<void> _owner(DatabaseExecutor tx) async {
    if ((await tx.query(
      'localOwners',
      where: 'id = ?',
      whereArgs: [ownerId],
    )).isEmpty) {
      throw StateError('Local workspace does not exist');
    }
  }

  Future<void> _party(DatabaseExecutor tx, String id) async {
    if ((await tx.query(
      'parties',
      where: 'id = ? AND ownerId = ?',
      whereArgs: [id, ownerId],
    )).isEmpty) {
      throw StateError('Party is unavailable');
    }
  }

  Future<void> _membership(DatabaseExecutor tx, String conversationId) async {
    final rows = await tx.query(
      'conversationParticipants',
      where: 'ownerId = ? AND conversationId = ? AND partyId = ?',
      whereArgs: [ownerId, conversationId, selfPartyId],
    );
    if (rows.isEmpty || rows.single['status'] != 'ACTIVE') {
      throw StateError('Conversation is unavailable');
    }
  }

  static void _id(String value) {
    if (!RegExp(r'^[a-zA-Z0-9:_-]{1,160}$').hasMatch(value)) {
      throw ArgumentError('Invalid operation ID');
    }
  }

  static String? _text(String? value, int max, bool required) {
    final v = value?.trim();
    if (v == null || v.isEmpty) {
      if (required) throw ArgumentError('Value is required');
      return null;
    }
    if (v.length > max ||
        RegExp(r'[\x00-\x08\x0b\x0c\x0e-\x1f\x7f]').hasMatch(v)) {
      throw ArgumentError('Value is invalid');
    }
    return v;
  }

  static Conversation _conversation(Map<String, Object?> r) => Conversation(
    id: r['id'] as String,
    ownerId: r['ownerId'] as String,
    type: ConversationType.values.byName((r['type'] as String).toLowerCase()),
    title: r['title'] as String,
    status: r['status'] as String,
    relationshipId: r['relationshipId'] as String?,
    loanUid: r['loanUid'] as String?,
    createdAt: DateTime.parse(r['createdAt'] as String),
    updatedAt: DateTime.parse(r['updatedAt'] as String),
  );
  static ChatMessage _message(Map<String, Object?> r) => ChatMessage(
    id: r['id'] as String,
    conversationId: r['conversationId'] as String,
    senderPartyId: r['senderPartyId'] as String,
    kind: MessageKind.values.byName((r['kind'] as String).toLowerCase()),
    body: r['body'] as String,
    createdAt: DateTime.parse(r['createdAt'] as String),
    persistedAt: DateTime.parse(r['persistedAt'] as String),
    deliveredAt: r['deliveredAt'] == null
        ? null
        : DateTime.parse(r['deliveredAt'] as String),
    readAt: r['readAt'] == null ? null : DateTime.parse(r['readAt'] as String),
  );
}
