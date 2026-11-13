import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/network/websocket_client.dart';
import '../../core/services/notification_service.dart';
import '../../data/models/room_model.dart';
import '../../data/repositories/chat_repository.dart';
import 'rooms_state.dart';

class RoomsCubit extends Cubit<RoomsState> {
  final ChatRepository _chatRepository;
  final WebSocketClient _wsClient = WebSocketClient();
  final String _currentUserId;

  StreamSubscription<Map<String, dynamic>>? _wsSub;

  RoomsCubit({
    required ChatRepository chatRepository,
    required String currentUserId,
  }) : _chatRepository = chatRepository,
       _currentUserId = currentUserId,
       super(RoomsInitial()) {
    _listenToWebSocket();
  }

  void _listenToWebSocket() {
    _wsSub = _wsClient.eventStream.listen((event) {
      final type = event['type'] as String?;

      if (type == 'xchat_message') {
        _handleNewMessage(event);
      } else if (type == 'xchat_read_receipt') {
        _handleReadReceipt(event);
      } else if (type == 'xchat_presence') {
        _handlePresenceUpdate(event);
      } else if (type == 'xchat_auth_success') {
        _handleAuthSuccess(event);
      } else if (type == 'xchat_room_created' ||
          type == 'xchat_group_updated') {
        loadRooms();
      }
    });
  }

  void _handleNewMessage(Map<String, dynamic> event) {
    final s = state;
    if (s is! RoomsLoaded) return;

    final rawMsg = event['message'] as Map<String, dynamic>?;
    if (rawMsg == null) return;

    final roomId = (rawMsg['roomId'] ?? rawMsg['room_id']) as String?;
    if (roomId == null) return;

    final content = rawMsg['content'] as String? ?? '';
    final createdAt = rawMsg['createdAt'] != null
        ? DateTime.tryParse(rawMsg['createdAt'] as String) ?? DateTime.now()
        : DateTime.now();
    final senderId = (rawMsg['senderId'] ?? rawMsg['sender_id']) as String?;

    final currentRooms = List<RoomModel>.from(s.rooms);
    final roomIndex = currentRooms.indexWhere((r) => r.id == roomId);

    if (roomIndex != -1) {
      final old = currentRooms.removeAt(roomIndex);
      final isCurrentActive = s.activeRoomId == roomId;
      final newUnread = (senderId != _currentUserId && !isCurrentActive)
          ? old.unreadCount + 1
          : old.unreadCount;

      final updated = old.copyWith(
        lastMessage: content,
        lastMessageTime: createdAt,
        lastMessageSenderId: senderId,
        unreadCount: newUnread,
        updatedAt: createdAt,
      );

      // Move updated room to top of list (WhatsApp standard behavior)
      currentRooms.insert(0, updated);
      emit(s.copyWith(rooms: currentRooms));

      // Show instant notification if message is from another user and not currently active room
      if (senderId != null && senderId != _currentUserId && !isCurrentActive) {
        final senderName =
            (rawMsg['senderName'] ?? rawMsg['sender_name']) as String? ??
            old.name;
        NotificationService().showInstantMessageNotification(
          id: roomId.hashCode,
          title: old.isGroup ? '${old.name} ($senderName)' : senderName,
          body: content,
          roomId: roomId,
        );
      }
    } else {
      // Room was newly created or first message
      loadRooms();
    }
  }

  void _handleReadReceipt(Map<String, dynamic> event) {
    final s = state;
    if (s is! RoomsLoaded) return;

    final roomId = event['roomId'] as String?;
    final userId = event['userId'] as String?;

    if (roomId != null && userId == _currentUserId) {
      final updatedRooms = s.rooms.map((r) {
        if (r.id == roomId) {
          return r.copyWith(unreadCount: 0);
        }
        return r;
      }).toList();

      emit(s.copyWith(rooms: updatedRooms));
    }
  }

  void _handlePresenceUpdate(Map<String, dynamic> event) {
    final s = state;
    if (s is! RoomsLoaded) return;

    final userId = event['userId'] as String?;
    final isOnline = event['isOnline'] == true;
    final lastSeenStr = event['lastSeen'] as String?;
    final lastSeen = lastSeenStr != null
        ? DateTime.tryParse(lastSeenStr)
        : null;

    if (userId == null) return;

    final updatedRooms = s.rooms.map((room) {
      if (room.isGroup) return room;

      final updatedMembers = room.members.map((member) {
        if (member.userId == userId) {
          final updatedUser = member.user?.copyWith(
            isOnline: isOnline,
            lastSeen: lastSeen ?? member.user?.lastSeen,
          );
          return RoomMemberModel(
            id: member.id,
            roomId: member.roomId,
            userId: member.userId,
            role: member.role,
            lastReadAt: member.lastReadAt,
            joinedAt: member.joinedAt,
            user: updatedUser,
          );
        }
        return member;
      }).toList();

      return room.copyWith(members: updatedMembers);
    }).toList();

    emit(s.copyWith(rooms: updatedRooms));
  }

  void _handleAuthSuccess(Map<String, dynamic> event) {
    final s = state;
    if (s is! RoomsLoaded) return;

    final onlineUsersRaw = event['onlineUsers'] as List<dynamic>?;
    if (onlineUsersRaw == null) return;

    final onlineUserIds = <String>{};
    final lastSeenMap = <String, DateTime>{};

    for (final u in onlineUsersRaw) {
      if (u is Map<String, dynamic>) {
        final id = u['userId'] as String?;
        if (id != null) {
          onlineUserIds.add(id);
          final ls = u['lastSeen'] as String?;
          if (ls != null) {
            final dt = DateTime.tryParse(ls);
            if (dt != null) lastSeenMap[id] = dt;
          }
        }
      }
    }

    final updatedRooms = s.rooms.map((room) {
      if (room.isGroup) return room;

      final updatedMembers = room.members.map((member) {
        if (onlineUserIds.contains(member.userId)) {
          final updatedUser = member.user?.copyWith(
            isOnline: true,
            lastSeen: lastSeenMap[member.userId] ?? member.user?.lastSeen,
          );
          return RoomMemberModel(
            id: member.id,
            roomId: member.roomId,
            userId: member.userId,
            role: member.role,
            lastReadAt: member.lastReadAt,
            joinedAt: member.joinedAt,
            user: updatedUser,
          );
        }
        return member;
      }).toList();

      return room.copyWith(members: updatedMembers);
    }).toList();

    emit(s.copyWith(rooms: updatedRooms));
  }

  Future<void> loadRooms() async {
    final currentActiveId = (state is RoomsLoaded)
        ? (state as RoomsLoaded).activeRoomId
        : null;
    emit(RoomsLoading());
    try {
      final rooms = await _chatRepository.getUserRooms(_currentUserId);
      emit(RoomsLoaded(rooms: rooms, activeRoomId: currentActiveId));
    } catch (e) {
      emit(RoomsError(e.toString().replaceAll('Exception: ', '')));
    }
  }

  void selectRoom(String? roomId) {
    final s = state;
    if (s is RoomsLoaded) {
      if (roomId == null) {
        emit(s.copyWith(clearActiveRoom: true));
        return;
      }

      // Mark unread as 0 locally
      final updatedRooms = s.rooms.map((r) {
        if (r.id == roomId) return r.copyWith(unreadCount: 0);
        return r;
      }).toList();

      emit(s.copyWith(rooms: updatedRooms, activeRoomId: roomId));

      // Notify server room is read
      _chatRepository.markRoomAsRead(roomId, _currentUserId);
      _wsClient.send({
        'type': 'xchat_read',
        'roomId': roomId,
        'userId': _currentUserId,
      });
    }
  }

  void setSearchQuery(String query) {
    final s = state;
    if (s is RoomsLoaded) {
      emit(s.copyWith(searchQuery: query));
    }
  }

  Future<RoomModel> createDirectRoom(String targetUserId) async {
    final s = state;
    if (s is RoomsLoaded) {
      final existing = s.rooms.where(
        (r) => !r.isGroup && r.members.any((m) => m.userId == targetUserId),
      );
      if (existing.isNotEmpty) {
        final room = existing.first;
        selectRoom(room.id);
        return room;
      }
    }

    final room = await _chatRepository.getOrCreateDirectRoom(
      _currentUserId,
      targetUserId,
    );
    loadRooms().ignore();
    selectRoom(room.id);
    return room;
  }

  Future<RoomModel> createGroup({
    required String name,
    String? description,
    String? avatarUrl,
    required List<String> memberUserIds,
  }) async {
    final room = await _chatRepository.createGroupRoom(
      creatorId: _currentUserId,
      name: name,
      description: description,
      avatarUrl: avatarUrl,
      memberUserIds: memberUserIds,
    );
    await loadRooms();
    selectRoom(room.id);
    return room;
  }

  @override
  Future<void> close() {
    _wsSub?.cancel();
    return super.close();
  }
}
