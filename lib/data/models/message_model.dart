import 'package:equatable/equatable.dart';

enum MessageDeliveryStatus { pending, sent, delivered, read }

class MessageModel extends Equatable {
  final String id;
  final String roomId;
  final String senderId;
  final String senderName;
  final String content;
  final String messageType; // 'text' | 'image' | 'system'
  final MessageDeliveryStatus status;
  final String? replyToId;
  final bool isDeleted;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? clientTempId;

  const MessageModel({
    required this.id,
    required this.roomId,
    required this.senderId,
    required this.senderName,
    required this.content,
    this.messageType = 'text',
    this.status = MessageDeliveryStatus.sent,
    this.replyToId,
    this.isDeleted = false,
    required this.createdAt,
    required this.updatedAt,
    this.clientTempId,
  });

  factory MessageModel.fromJson(Map<String, dynamic> json) {
    MessageDeliveryStatus parseStatus(String? s) {
      switch (s) {
        case 'pending':
          return MessageDeliveryStatus.pending;
        case 'delivered':
          return MessageDeliveryStatus.delivered;
        case 'read':
          return MessageDeliveryStatus.read;
        case 'sent':
        default:
          return MessageDeliveryStatus.sent;
      }
    }

    return MessageModel(
      id: json['id'] as String,
      roomId: (json['roomId'] ?? json['room_id']) as String,
      senderId: (json['senderId'] ?? json['sender_id']) as String,
      senderName:
          (json['senderName'] ?? json['sender_name']) as String? ?? 'User',
      content: (json['content'] as String?) ?? '',
      messageType:
          (json['messageType'] ?? json['message_type']) as String? ?? 'text',
      status: parseStatus(json['status'] as String?),
      replyToId: (json['replyToId'] ?? json['reply_to_id']) as String?,
      isDeleted: json['isDeleted'] == true || json['is_deleted'] == 1,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String) ?? DateTime.now()
          : (json['created_at'] != null
                ? DateTime.tryParse(json['created_at'] as String) ??
                      DateTime.now()
                : DateTime.now()),
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'] as String) ?? DateTime.now()
          : (json['updated_at'] != null
                ? DateTime.tryParse(json['updated_at'] as String) ??
                      DateTime.now()
                : DateTime.now()),
      clientTempId: json['clientTempId'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    String statusToString(MessageDeliveryStatus s) {
      switch (s) {
        case MessageDeliveryStatus.pending:
          return 'pending';
        case MessageDeliveryStatus.delivered:
          return 'delivered';
        case MessageDeliveryStatus.read:
          return 'read';
        case MessageDeliveryStatus.sent:
          return 'sent';
      }
    }

    return {
      'id': id,
      'roomId': roomId,
      'senderId': senderId,
      'senderName': senderName,
      'content': content,
      'messageType': messageType,
      'status': statusToString(status),
      'replyToId': replyToId,
      'isDeleted': isDeleted,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'clientTempId': clientTempId,
    };
  }

  MessageModel copyWith({
    String? id,
    String? roomId,
    String? senderId,
    String? senderName,
    String? content,
    String? messageType,
    MessageDeliveryStatus? status,
    String? replyToId,
    bool? isDeleted,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? clientTempId,
  }) {
    return MessageModel(
      id: id ?? this.id,
      roomId: roomId ?? this.roomId,
      senderId: senderId ?? this.senderId,
      senderName: senderName ?? this.senderName,
      content: content ?? this.content,
      messageType: messageType ?? this.messageType,
      status: status ?? this.status,
      replyToId: replyToId ?? this.replyToId,
      isDeleted: isDeleted ?? this.isDeleted,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      clientTempId: clientTempId ?? this.clientTempId,
    );
  }

  @override
  List<Object?> get props => [
    id,
    roomId,
    senderId,
    content,
    status,
    isDeleted,
    createdAt,
    clientTempId,
  ];
}
