import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/date_formatter.dart';
import '../../core/utils/page_transitions.dart';
import '../../data/repositories/chat_repository.dart';
import '../../logic/chat/chat_cubit.dart';
import '../../logic/chat/chat_state.dart';
import '../widgets/app_avatar.dart';
import '../widgets/chat_input_bar.dart';
import '../widgets/connection_banner.dart';
import '../widgets/message_bubble.dart';
import 'group_info_screen.dart';

class ChatView extends StatelessWidget {
  final String roomId;
  final String currentUserId;
  final String currentUserName;
  final VoidCallback? onBack;

  const ChatView({
    super.key,
    required this.roomId,
    required this.currentUserId,
    required this.currentUserName,
    this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      key: ValueKey(roomId),
      create: (ctx) => ChatCubit(
        chatRepository: ChatRepository(),
        roomId: roomId,
        currentUserId: currentUserId,
        currentUserName: currentUserName,
      ),
      child: _ChatViewScaffold(
        currentUserId: currentUserId,
        onBack: onBack,
      ),
    );
  }
}

class _ChatViewScaffold extends StatefulWidget {
  final String currentUserId;
  final VoidCallback? onBack;

  const _ChatViewScaffold({
    required this.currentUserId,
    this.onBack,
  });

  @override
  State<_ChatViewScaffold> createState() => _ChatViewScaffoldState();
}

class _ChatViewScaffoldState extends State<_ChatViewScaffold> {
  final ScrollController _scrollController = ScrollController();

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<ChatCubit, ChatState>(
      listener: (context, state) {
        if (state is ChatLoaded) {
          _scrollToBottom();
        }
      },
      builder: (context, state) {
        if (state is ChatLoading) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (state is ChatError) {
          return Scaffold(
            appBar: AppBar(leading: widget.onBack != null ? IconButton(icon: const Icon(Icons.arrow_back), onPressed: widget.onBack) : null),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline_rounded, size: 48, color: AppColors.error),
                  const SizedBox(height: 12),
                  Text(state.message, style: const TextStyle(color: AppColors.error)),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => context.read<ChatCubit>().loadChat(),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          );
        }

        if (state is! ChatLoaded) {
          return const Scaffold(body: SizedBox.shrink());
        }

        final room = state.room;
        final cubit = context.read<ChatCubit>();

        String statusSubtitle;
        if (state.isTypingActive) {
          statusSubtitle = '${state.typingUserNames.join(', ')} is typing...';
        } else if (room.isGroup) {
          statusSubtitle = '${room.members.length} participants';
        } else {
          statusSubtitle = 'Online';
        }

        return Scaffold(
          backgroundColor: AppColors.chatWallpaper,
          appBar: AppBar(
            leadingWidth: widget.onBack != null ? 92 : 56,
            titleSpacing: 0,
            leading: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.onBack != null) ...[
                  const SizedBox(width: 4),
                  IconButton(
                    icon: const Icon(Icons.arrow_back, size: 23),
                    onPressed: widget.onBack,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                    style: IconButton.styleFrom(
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      minimumSize: const Size(36, 36),
                    ),
                    tooltip: 'Back',
                  ),
                  const SizedBox(width: 2),
                ] else
                  const SizedBox(width: 12),
                GestureDetector(
                  onTap: room.isGroup
                      ? () => Navigator.of(context).push(
                            SlidePageRoute<void>(
                              page: GroupInfoScreen(
                                room: room,
                                currentUserId: widget.currentUserId,
                                chatCubit: cubit,
                              ),
                            ),
                          )
                      : null,
                  child: AppAvatar(
                    imageUrl: room.avatarUrl,
                    name: room.name,
                    isGroup: room.isGroup,
                    radius: 19,
                  ),
                ),
              ],
            ),
            title: InkWell(
              onTap: room.isGroup
                  ? () => Navigator.of(context).push(
                        SlidePageRoute<void>(
                          page: GroupInfoScreen(
                            room: room,
                            currentUserId: widget.currentUserId,
                            chatCubit: cubit,
                          ),
                        ),
                      )
                  : null,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    room.name,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    statusSubtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: state.isTypingActive ? const Color(0xFFD9FDD3) : Colors.white70,
                      fontWeight: state.isTypingActive ? FontWeight.w600 : FontWeight.normal,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            actions: [
              if (room.isGroup)
                IconButton(
                  icon: const Icon(Icons.info_outline_rounded),
                  tooltip: 'Group Info',
                  onPressed: () => Navigator.of(context).push(
                    SlidePageRoute<void>(
                      page: GroupInfoScreen(
                        room: room,
                        currentUserId: widget.currentUserId,
                        chatCubit: cubit,
                      ),
                    ),
                  ),
                ),
              IconButton(
                icon: const Icon(Icons.more_vert_rounded),
                onPressed: () {},
              ),
            ],
          ),
          body: Column(
            children: [
              // Connection Banner (Handles offline / reconnection state)
              ConnectionBanner(status: state.connectionStatus),

              // Messages list with sticky dates
              Expanded(
                child: state.messages.isEmpty
                    ? Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white.withAlpha(230),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'No messages here yet. Say hello!',
                            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                          ),
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: state.messages.length,
                        itemBuilder: (context, index) {
                          final msg = state.messages[index];
                          final isMe = msg.senderId == widget.currentUserId;

                          // Show date divider if first message or day changed
                          bool showDateDivider = false;
                          if (index == 0) {
                            showDateDivider = true;
                          } else {
                            final prev = state.messages[index - 1];
                            final prevDt = prev.createdAt.toLocal();
                            final currDt = msg.createdAt.toLocal();
                            if (prevDt.year != currDt.year || prevDt.month != currDt.month || prevDt.day != currDt.day) {
                              showDateDivider = true;
                            }
                          }

                          return Column(
                            children: [
                              if (showDateDivider)
                                Center(
                                  child: Container(
                                    margin: const EdgeInsets.symmetric(vertical: 8),
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withAlpha(230),
                                      borderRadius: BorderRadius.circular(6),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withAlpha(10),
                                          blurRadius: 1,
                                          offset: const Offset(0, 1),
                                        ),
                                      ],
                                    ),
                                    child: Text(
                                      DateFormatter.formatDateDivider(msg.createdAt),
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ),
                                ),
                              MessageBubble(
                                message: msg,
                                isMe: isMe,
                                showSenderName: room.isGroup,
                              ),
                            ],
                          );
                        },
                      ),
              ),

              // Bottom Input Bar
              ChatInputBar(
                onSendMessage: (text) => cubit.sendMessage(text),
                onTypingChanged: (isTyping) => cubit.sendTyping(isTyping),
              ),
            ],
          ),
        );
      },
    );
  }
}
