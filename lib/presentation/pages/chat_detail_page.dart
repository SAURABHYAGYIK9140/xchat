import 'package:flutter/material.dart';
import 'chat_view.dart';

class ChatDetailPage extends StatelessWidget {
  final String roomId;
  final String currentUserId;
  final String currentUserName;

  const ChatDetailPage({
    super.key,
    required this.roomId,
    required this.currentUserId,
    required this.currentUserName,
  });

  @override
  Widget build(BuildContext context) {
    return ChatView(
      roomId: roomId,
      currentUserId: currentUserId,
      currentUserName: currentUserName,
      onBack: () => Navigator.of(context).pop(),
    );
  }
}

