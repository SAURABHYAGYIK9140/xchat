import 'package:equatable/equatable.dart';
import 'user_model.dart';

class RoomMemberModel extends Equatable {
  final String id;
  final String roomId;
  final String userId;
  final String role; // 'admin' | 'member'
  final DateTime? lastReadAt;
  final DateTime joinedAt;
  final UserModel? user;

  const RoomMemberModel({
    required this.id,
    required this.roomId,
    required this.userId,
    required this.role,
    this.lastReadAt,
    required this.joinedAt,
    this.user,
  });

  factory RoomMemberModel.fromJson(Map<String, dynamic> json) {
    return RoomMemberModel(
      id: json['id'] as String,
      roomId: (json['roomId'] ?? json['room_id']) as String,
      userId: (json['userId'] ?? json['user_id']) as String,
      role: (json['role'] as String?) ?? 'member',
      lastReadAt: json['lastReadAt'] != null
          ? DateTime.tryParse(json['lastReadAt'] as String)
          : (json['last_read_at'] != null ? DateTime.tryParse(json['last_read_at'] as String) : null),
      joinedAt: json['joinedAt'] != null
          ? DateTime.tryParse(json['joinedAt'] as String) ?? DateTime.now()
          : (json['joined_at'] != null
              ? DateTime.tryParse(json['joined_at'] as String) ?? DateTime.now()
              : DateTime.now()),
      user: json['user'] != null ? UserModel.fromJson(json['user'] as Map<String, dynamic>) : null,
    );
  }

  @override
  List<Object?> get props => [id, roomId, userId, role, lastReadAt, joinedAt, user];
}

class RoomModel extends Equatable {
  final String id;
  final String name;
  final bool isGroup;
  final String? description;
  final String? avatarUrl;
  final String createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? lastMessage;
  final DateTime? lastMessageTime;
  final String? lastMessageSenderId;
  final int unreadCount;
  final List<RoomMemberModel> members;

  const RoomModel({
    required this.id,
    required this.name,
    required this.isGroup,
    this.description,
    this.avatarUrl,
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
    this.lastMessage,
    this.lastMessageTime,
    this.lastMessageSenderId,
    this.unreadCount = 0,
    this.members = const [],
  });

  factory RoomModel.fromJson(Map<String, dynamic> json) {
    final rawMembers = json['members'] as List<dynamic>?;
    final members = rawMembers != null
        ? rawMembers.map((m) => RoomMemberModel.fromJson(m as Map<String, dynamic>)).toList()
        : <RoomMemberModel>[];

    return RoomModel(
      id: json['id'] as String,
      name: (json['name'] as String?) ?? 'Conversation',
      isGroup: json['isGroup'] == true || json['is_group'] == 1,
      description: (json['description'] as String?),
      avatarUrl: (json['avatarUrl'] ?? json['avatar_url']) as String?,
      createdBy: (json['createdBy'] ?? json['created_by']) as String? ?? '',
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String) ?? DateTime.now()
          : (json['created_at'] != null
              ? DateTime.tryParse(json['created_at'] as String) ?? DateTime.now()
              : DateTime.now()),
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'] as String) ?? DateTime.now()
          : (json['updated_at'] != null
              ? DateTime.tryParse(json['updated_at'] as String) ?? DateTime.now()
              : DateTime.now()),
      lastMessage: json['lastMessage'] as String?,
      lastMessageTime: json['lastMessageTime'] != null
          ? DateTime.tryParse(json['lastMessageTime'] as String)
          : null,
      lastMessageSenderId: json['lastMessageSenderId'] as String?,
      unreadCount: (json['unreadCount'] as num?)?.toInt() ?? 0,
      members: members,
    );
  }

  RoomModel copyWith({
    String? id,
    String? name,
    bool? isGroup,
    String? description,
    String? avatarUrl,
    String? createdBy,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? lastMessage,
    DateTime? lastMessageTime,
    String? lastMessageSenderId,
    int? unreadCount,
    List<RoomMemberModel>? members,
  }) {
    return RoomModel(
      id: id ?? this.id,
      name: name ?? this.name,
      isGroup: isGroup ?? this.isGroup,
      description: description ?? this.description,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lastMessage: lastMessage ?? this.lastMessage,
      lastMessageTime: lastMessageTime ?? this.lastMessageTime,
      lastMessageSenderId: lastMessageSenderId ?? this.lastMessageSenderId,
      unreadCount: unreadCount ?? this.unreadCount,
      members: members ?? this.members,
    );
  }

  RoomMemberModel? otherMember(String currentUserId) {
    if (isGroup) return null;
    final others = members.where((m) => m.userId != currentUserId);
    return others.isNotEmpty ? others.first : null;
  }

  bool isOtherUserOnline(String currentUserId) {
    final other = otherMember(currentUserId);
    return other?.user?.isOnline ?? false;
  }

  DateTime? otherUserLastSeen(String currentUserId) {
    final other = otherMember(currentUserId);
    return other?.user?.lastSeen;
  }

  @override
  List<Object?> get props => [
        id,
        name,
        isGroup,
        avatarUrl,
        updatedAt,
        lastMessage,
        lastMessageTime,
        unreadCount,
        members,
      ];
}

