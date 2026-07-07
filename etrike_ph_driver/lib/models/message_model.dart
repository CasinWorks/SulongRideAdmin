/// Chat message from `messages`.
enum MessageDeliveryStatus { sending, sent, delivered, read, failed }

class MessageModel {
  const MessageModel({
    required this.id,
    required this.tripId,
    required this.senderId,
    required this.senderRole,
    required this.message,
    required this.createdAt,
    this.deliveredAt,
    this.readAt,
    this.localStatus,
  });

  final String id;
  final String tripId;
  final String senderId;
  final String senderRole;
  final String message;
  final DateTime createdAt;
  final DateTime? deliveredAt;
  final DateTime? readAt;
  final MessageDeliveryStatus? localStatus;

  bool get isOptimistic => id.startsWith('pending-');

  MessageDeliveryStatus deliveryStatusFor(String currentUserId) {
    if (localStatus == MessageDeliveryStatus.sending ||
        localStatus == MessageDeliveryStatus.failed) {
      return localStatus!;
    }
    if (senderId != currentUserId) return MessageDeliveryStatus.sent;
    if (readAt != null) return MessageDeliveryStatus.read;
    if (deliveredAt != null) return MessageDeliveryStatus.delivered;
    return MessageDeliveryStatus.sent;
  }

  factory MessageModel.fromJson(Map<String, dynamic> json) {
    return MessageModel(
      id: json['id'] as String,
      tripId: json['trip_id'] as String,
      senderId: json['sender_id'] as String,
      senderRole: json['sender_role'] as String? ?? 'rider',
      message: json['message'] as String? ?? '',
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ??
          DateTime.now().toUtc(),
      deliveredAt: json['delivered_at'] != null
          ? DateTime.tryParse(json['delivered_at'] as String)
          : null,
      readAt: json['read_at'] != null
          ? DateTime.tryParse(json['read_at'] as String)
          : null,
    );
  }

  factory MessageModel.optimistic({
    required String clientId,
    required String tripId,
    required String senderId,
    required String senderRole,
    required String message,
    MessageDeliveryStatus status = MessageDeliveryStatus.sending,
  }) {
    return MessageModel(
      id: clientId,
      tripId: tripId,
      senderId: senderId,
      senderRole: senderRole,
      message: message,
      createdAt: DateTime.now().toUtc(),
      localStatus: status,
    );
  }

  MessageModel copyWith({
    String? id,
    MessageDeliveryStatus? localStatus,
    DateTime? deliveredAt,
    DateTime? readAt,
  }) {
    return MessageModel(
      id: id ?? this.id,
      tripId: tripId,
      senderId: senderId,
      senderRole: senderRole,
      message: message,
      createdAt: createdAt,
      deliveredAt: deliveredAt ?? this.deliveredAt,
      readAt: readAt ?? this.readAt,
      localStatus: localStatus ?? this.localStatus,
    );
  }
}

bool tripChatIsOpen(String status) =>
    status == 'accepted' || status == 'ongoing';
