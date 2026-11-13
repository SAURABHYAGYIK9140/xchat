import 'package:equatable/equatable.dart';
import '../../core/network/websocket_client.dart';
import '../../data/models/message_model.dart';
import '../../data/models/room_model.dart';

abstract class ChatState extends Equatable {
  const ChatState();
  @override
  List<Object?> get props => [];
}

class ChatInitial extends ChatState {}

class ChatLoading extends ChatState {}

class ChatLoaded extends ChatState {
  final RoomModel room;
  final List<MessageModel> messages;
  final List<String> typingUserNames;
  final WsConnectionStatus connectionStatus;
  final MessageModel? replyToMessage;

  const ChatLoaded({
    required this.room,
    required this.messages,
    this.typingUserNames = const [],
    this.connectionStatus = WsConnectionStatus.connected,
    this.replyToMessage,
  });

  bool get isTypingActive => typingUserNames.isNotEmpty;

  ChatLoaded copyWith({
    RoomModel? room,
    List<MessageModel>? messages,
    List<String>? typingUserNames,
    WsConnectionStatus? connectionStatus,
    MessageModel? replyToMessage,
    bool clearReplyTo = false,
  }) {
    return ChatLoaded(
      room: room ?? this.room,
      messages: messages ?? this.messages,
      typingUserNames: typingUserNames ?? this.typingUserNames,
      connectionStatus: connectionStatus ?? this.connectionStatus,
      replyToMessage: clearReplyTo
          ? null
          : (replyToMessage ?? this.replyToMessage),
    );
  }

  @override
  List<Object?> get props => [
    room,
    messages,
    typingUserNames,
    connectionStatus,
    replyToMessage,
  ];
}

class ChatError extends ChatState {
  final String message;
  const ChatError(this.message);

  @override
  List<Object?> get props => [message];
}
