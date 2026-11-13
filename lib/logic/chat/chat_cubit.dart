import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';
import '../../core/network/websocket_client.dart';
import '../../data/models/message_model.dart';
import '../../data/models/room_model.dart';
import '../../data/repositories/chat_repository.dart';
import 'chat_state.dart';

class ChatCubit extends Cubit<ChatState> {
  final ChatRepository _chatRepository;
  final WebSocketClient _wsClient = WebSocketClient();
  final String _roomId;
  final String _currentUserId;
  final String _currentUserName;

  StreamSubscription<Map<String, dynamic>>? _wsEventSub;
  StreamSubscription<WsConnectionStatus>? _wsStatusSub;
  Timer? _typingDebounce;

  ChatCubit({
    required ChatRepository chatRepository,
    required String roomId,
    required String currentUserId,
    required String currentUserName,
  })  : _chatRepository = chatRepository,
        _roomId = roomId,
        _currentUserId = currentUserId,
        _currentUserName = currentUserName,
        super(ChatInitial()) {
    _initListeners();
    loadChat();
  }

  void _initListeners() {
    _wsStatusSub = _wsClient.statusStream.listen((status) {
      final s = state;
      if (s is ChatLoaded) {
        emit(s.copyWith(connectionStatus: status));
      }
    });

    _wsEventSub = _wsClient.eventStream.listen((event) {
      final type = event['type'] as String?;

      if (type == 'xchat_message') {
        _handleIncomingMessage(event);
      } else if (type == 'xchat_message_ack') {
        _handleMessageAck(event);
      } else if (type == 'xchat_delivered_receipt') {
        _handleDeliveredReceipt(event);
      } else if (type == 'xchat_read_receipt') {
        _handleReadReceipt(event);
      } else if (type == 'xchat_typing') {
        _handleTypingEvent(event);
      } else if (type == 'xchat_group_updated') {
        _handleGroupUpdated(event);
      }
    });
  }

  Future<void> loadChat() async {
    emit(ChatLoading());
    try {
      final room = await _chatRepository.getRoomDetails(_roomId, _currentUserId);
      final messages = await _chatRepository.getRoomMessages(_roomId);

      emit(ChatLoaded(
        room: room,
        messages: messages,
        connectionStatus: _wsClient.currentStatus,
      ));

      // Mark as read
      _wsClient.send({
        'type': 'xchat_read',
        'roomId': _roomId,
        'userId': _currentUserId,
      });
      _chatRepository.markRoomAsRead(_roomId, _currentUserId);
    } catch (e) {
      emit(ChatError(e.toString().replaceAll('Exception: ', '')));
    }
  }

  void _handleIncomingMessage(Map<String, dynamic> event) {
    final s = state;
    if (s is! ChatLoaded) return;

    final rawMsg = event['message'] as Map<String, dynamic>?;
    if (rawMsg == null) return;

    final roomId = (rawMsg['roomId'] ?? rawMsg['room_id']) as String?;
    if (roomId != _roomId) return;

    final incomingMsg = MessageModel.fromJson(rawMsg);
    final clientTempId = event['clientTempId'] as String?;

    final currentMessages = List<MessageModel>.from(s.messages);

    // If this was our own optimistic message, replace it
    if (clientTempId != null) {
      final idx = currentMessages.indexWhere((m) => m.clientTempId == clientTempId);
      if (idx != -1) {
        currentMessages[idx] = incomingMsg;
        emit(s.copyWith(messages: currentMessages));
        return;
      }
    }

    // Check if message is already present
    if (currentMessages.any((m) => m.id == incomingMsg.id)) {
      return;
    }

    currentMessages.add(incomingMsg);
    emit(s.copyWith(messages: currentMessages));

    // Send delivered and read receipts back to sender
    if (incomingMsg.senderId != _currentUserId) {
      _wsClient.send({
        'type': 'xchat_delivered',
        'messageId': incomingMsg.id,
        'roomId': _roomId,
      });

      _wsClient.send({
        'type': 'xchat_read',
        'roomId': _roomId,
        'userId': _currentUserId,
      });
    }
  }

  void _handleMessageAck(Map<String, dynamic> event) {
    final s = state;
    if (s is! ChatLoaded) return;

    final clientTempId = event['clientTempId'] as String?;
    final rawMsg = event['message'] as Map<String, dynamic>?;
    if (clientTempId == null || rawMsg == null) return;

    final confirmedMsg = MessageModel.fromJson(rawMsg);
    final currentMessages = List<MessageModel>.from(s.messages);

    final idx = currentMessages.indexWhere((m) => m.clientTempId == clientTempId);
    if (idx != -1) {
      currentMessages[idx] = confirmedMsg;
      emit(s.copyWith(messages: currentMessages));
    }
  }

  void _handleDeliveredReceipt(Map<String, dynamic> event) {
    final s = state;
    if (s is! ChatLoaded) return;

    final messageId = event['messageId'] as String?;
    final roomId = event['roomId'] as String?;
    if (roomId != _roomId || messageId == null) return;

    final currentMessages = s.messages.map((m) {
      if (m.id == messageId && m.status == MessageDeliveryStatus.sent) {
        return m.copyWith(status: MessageDeliveryStatus.delivered);
      }
      return m;
    }).toList();

    emit(s.copyWith(messages: currentMessages));
  }

  void _handleReadReceipt(Map<String, dynamic> event) {
    final s = state;
    if (s is! ChatLoaded) return;

    final roomId = event['roomId'] as String?;
    final userId = event['userId'] as String?;
    if (roomId != _roomId || userId == _currentUserId) return;

    // All outgoing messages from current user are now marked as read (double blue ticks!)
    final currentMessages = s.messages.map((m) {
      if (m.senderId == _currentUserId && m.status != MessageDeliveryStatus.read) {
        return m.copyWith(status: MessageDeliveryStatus.read);
      }
      return m;
    }).toList();

    emit(s.copyWith(messages: currentMessages));
  }

  void _handleTypingEvent(Map<String, dynamic> event) {
    final s = state;
    if (s is! ChatLoaded) return;

    final roomId = event['roomId'] as String?;
    final userName = event['userName'] as String?;
    final isTyping = event['isTyping'] == true;

    if (roomId != _roomId || userName == null) return;

    final currentTypers = List<String>.from(s.typingUserNames);
    if (isTyping) {
      if (!currentTypers.contains(userName)) currentTypers.add(userName);
    } else {
      currentTypers.remove(userName);
    }

    emit(s.copyWith(typingUserNames: currentTypers));
  }

  void _handleGroupUpdated(Map<String, dynamic> event) {
    final s = state;
    if (s is! ChatLoaded) return;

    final roomId = event['roomId'] as String?;
    if (roomId != _roomId) return;

    final rawRoom = event['room'] as Map<String, dynamic>?;
    if (rawRoom != null) {
      final updatedRoom = RoomModel.fromJson(rawRoom);
      emit(s.copyWith(room: updatedRoom));
    }
  }

  Future<void> sendMessage(String text) async {
    final content = text.trim();
    if (content.isEmpty) return;

    final s = state;
    if (s is! ChatLoaded) return;

    final clientTempId = 'temp_${const Uuid().v4()}';
    final now = DateTime.now();

    // 1. Optimistic UI update
    final optimisticMessage = MessageModel(
      id: clientTempId,
      roomId: _roomId,
      senderId: _currentUserId,
      senderName: _currentUserName,
      content: content,
      messageType: 'text',
      status: MessageDeliveryStatus.pending,
      createdAt: now,
      updatedAt: now,
      clientTempId: clientTempId,
    );

    final updatedMessages = List<MessageModel>.from(s.messages)..add(optimisticMessage);
    emit(s.copyWith(messages: updatedMessages));

    // 2. Dispatch via WebSocket if connected
    if (_wsClient.currentStatus == WsConnectionStatus.connected) {
      _wsClient.send({
        'type': 'xchat_send',
        'roomId': _roomId,
        'senderId': _currentUserId,
        'content': content,
        'messageType': 'text',
        'clientTempId': clientTempId,
      });
    } else {
      // 3. Fallback to HTTP REST endpoint if WebSocket is offline/reconnecting
      try {
        final serverMsg = await _chatRepository.sendMessage(
          roomId: _roomId,
          senderId: _currentUserId,
          content: content,
          clientTempId: clientTempId,
        );

        final msgs = List<MessageModel>.from(state is ChatLoaded ? (state as ChatLoaded).messages : updatedMessages);
        final idx = msgs.indexWhere((m) => m.clientTempId == clientTempId);
        if (idx != -1) {
          msgs[idx] = serverMsg;
          emit(s.copyWith(messages: msgs));
        }
      } catch (e) {
        // Keeps message as pending/offline
      }
    }
  }

  void sendTyping(bool isTyping) {
    _typingDebounce?.cancel();
    _typingDebounce = Timer(const Duration(milliseconds: 300), () {
      _wsClient.send({
        'type': 'xchat_typing',
        'roomId': _roomId,
        'userId': _currentUserId,
        'userName': _currentUserName,
        'isTyping': isTyping,
      });
    });
  }

  Future<void> addMember(String targetUserId) async {
    try {
      final updatedRoom = await _chatRepository.addGroupMember(_roomId, targetUserId);
      final s = state;
      if (s is ChatLoaded) {
        emit(s.copyWith(room: updatedRoom));
      }
    } catch (_) {}
  }

  Future<void> removeMember(String targetUserId) async {
    try {
      final updatedRoom = await _chatRepository.removeGroupMember(_roomId, targetUserId);
      final s = state;
      if (s is ChatLoaded) {
        emit(s.copyWith(room: updatedRoom));
      }
    } catch (_) {}
  }

  @override
  Future<void> close() {
    _typingDebounce?.cancel();
    _wsEventSub?.cancel();
    _wsStatusSub?.cancel();
    return super.close();
  }
}

