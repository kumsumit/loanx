enum ConversationType { marketplace, relationship, loan, support }

enum MessageKind {
  text,
  image,
  document,
  system,
  loanProposal,
  paymentReference,
}

class Conversation {
  const Conversation({
    required this.id,
    required this.ownerId,
    required this.type,
    required this.title,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.relationshipId,
    this.loanUid,
  });
  final String id, ownerId, title, status;
  final ConversationType type;
  final String? relationshipId, loanUid;
  final DateTime createdAt, updatedAt;
}

class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.conversationId,
    required this.senderPartyId,
    required this.kind,
    required this.body,
    required this.createdAt,
    required this.persistedAt,
    this.deliveredAt,
    this.readAt,
  });
  final String id, conversationId, senderPartyId, body;
  final MessageKind kind;
  final DateTime createdAt, persistedAt;
  final DateTime? deliveredAt, readAt;
}

class LoanNotification {
  const LoanNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.createdAt,
    this.entityType,
    this.entityId,
    this.readAt,
  });
  final String id, type, title, body;
  final String? entityType, entityId;
  final DateTime createdAt;
  final DateTime? readAt;
}
