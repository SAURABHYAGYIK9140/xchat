import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/constants/app_colors.dart';
import '../../core/network/websocket_client.dart';
import '../../core/services/notification_service.dart';
import '../../core/utils/page_transitions.dart';
import '../../core/utils/responsive_helper.dart';
import '../../data/models/user_model.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/chat_repository.dart';
import '../../logic/auth/auth_cubit.dart';
import '../../logic/rooms/rooms_cubit.dart';
import '../../logic/rooms/rooms_state.dart';
import '../widgets/app_avatar.dart';
import '../widgets/connection_banner.dart';
import '../widgets/conversation_tile.dart';
import '../widgets/empty_chat_placeholder.dart';
import 'chat_detail_page.dart';
import 'chat_view.dart';
import 'create_group_screen.dart';
import 'new_chat_screen.dart';

class HomePage extends StatelessWidget {
  final UserModel currentUser;

  const HomePage({super.key, required this.currentUser});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (ctx) => RoomsCubit(
        chatRepository: ChatRepository(),
        currentUserId: currentUser.id,
      )..loadRooms(),
      child: _HomePageScaffold(currentUser: currentUser),
    );
  }
}

class _HomePageScaffold extends StatefulWidget {
  final UserModel currentUser;

  const _HomePageScaffold({required this.currentUser});

  @override
  State<_HomePageScaffold> createState() => _HomePageScaffoldState();
}

class _HomePageScaffoldState extends State<_HomePageScaffold> {
  final TextEditingController _searchController = TextEditingController();
  final WebSocketClient _wsClient = WebSocketClient();

  @override
  void initState() {
    super.initState();
    // Pre-cache contacts so "New Chat" opens instantly without waiting
    AuthRepository().getUsers(excludeUserId: widget.currentUser.id).ignore();

    // Register notification tap redirection handler
    NotificationService.onChatOpenedFromNotification = _openChatRoom;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      NotificationService.processPendingNavigation();
    });
  }

  void _openChatRoom(String roomId) {
    if (NotificationService.activeRoomId == roomId) return;

    final nav =
        NotificationService.navigatorKey.currentState ?? Navigator.of(context);
    final currentCtx =
        NotificationService.navigatorKey.currentContext ?? context;
    final isWide = ResponsiveHelper.isWideScreen(currentCtx);

    if (isWide) {
      currentCtx.read<RoomsCubit>().selectRoom(roomId);
    } else {
      // If currently viewing another ChatDetailPage, pop it to prevent stacked pages
      if (NotificationService.activeRoomId != null && nav.canPop()) {
        nav.pop();
      }
      context.read<RoomsCubit>().selectRoom(roomId);
      nav
          .push(
            MaterialPageRoute<void>(
              builder: (_) => ChatDetailPage(
                roomId: roomId,
                currentUserId: widget.currentUser.id,
                currentUserName: widget.currentUser.displayName,
              ),
            ),
          )
          .then((_) {
            if (mounted) {
              context.read<RoomsCubit>().selectRoom(null);
            }
          });
    }
  }

  @override
  void dispose() {
    if (NotificationService.onChatOpenedFromNotification == _openChatRoom) {
      NotificationService.onChatOpenedFromNotification = null;
    }
    _searchController.dispose();
    super.dispose();
  }

  void _showNewChatDialog() {
    final roomsCubit = context.read<RoomsCubit>();
    final isWide = ResponsiveHelper.isWideScreen(context);

    Navigator.of(context).push(
      SlidePageRoute<void>(
        page: NewChatScreen(
          currentUserId: widget.currentUser.id,
          roomsCubit: roomsCubit,
          onRoomSelected: (room) {
            if (!isWide) {
              Navigator.of(context)
                  .push(
                    SlidePageRoute<void>(
                      page: ChatDetailPage(
                        roomId: room.id,
                        currentUserId: widget.currentUser.id,
                        currentUserName: widget.currentUser.displayName,
                      ),
                    ),
                  )
                  .then((_) {
                    if (mounted) {
                      context.read<RoomsCubit>().selectRoom(null);
                    }
                  });
            }
          },
        ),
      ),
    );
  }

  void _showCreateGroupDialog() {
    final roomsCubit = context.read<RoomsCubit>();
    final isWide = ResponsiveHelper.isWideScreen(context);

    Navigator.of(context).push(
      SlidePageRoute<void>(
        page: CreateGroupScreen(
          currentUserId: widget.currentUser.id,
          roomsCubit: roomsCubit,
          onGroupCreated: (room) {
            if (!isWide) {
              Navigator.of(context)
                  .push(
                    SlidePageRoute<void>(
                      page: ChatDetailPage(
                        roomId: room.id,
                        currentUserId: widget.currentUser.id,
                        currentUserName: widget.currentUser.displayName,
                      ),
                    ),
                  )
                  .then((_) {
                    if (mounted) {
                      context.read<RoomsCubit>().selectRoom(null);
                    }
                  });
            }
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isWide = ResponsiveHelper.isWideScreen(context);

    if (isWide) {
      return _buildWideScreenLayout(context);
    } else {
      return _buildMobileLayout(context);
    }
  }

  // ==================== WIDE SCREEN / DESKTOP / WEB (DUAL-PANE) ====================
  Widget _buildWideScreenLayout(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Row(
        children: [
          // Left Sidebar (Conversation List & Actions)
          SizedBox(
            width: 380,
            child: Container(
              decoration: const BoxDecoration(
                border: Border(
                  right: BorderSide(color: AppColors.divider, width: 0.5),
                ),
                color: Colors.white,
              ),
              child: Column(
                children: [
                  // Sidebar Profile Header
                  Container(
                    height: 60,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    color: AppColors.secondarySurface,
                    child: Row(
                      children: [
                        AppAvatar(
                          imageUrl: widget.currentUser.avatarUrl,
                          name: widget.currentUser.displayName,
                          radius: 19,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.currentUser.displayName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14.5,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                '@${widget.currentUser.username}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.group_add_outlined,
                            size: 20,
                            color: AppColors.textSecondary,
                          ),
                          tooltip: 'New Group',
                          onPressed: _showCreateGroupDialog,
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.chat_outlined,
                            size: 20,
                            color: AppColors.textSecondary,
                          ),
                          tooltip: 'New Chat',
                          onPressed: _showNewChatDialog,
                        ),
                        PopupMenuButton<String>(
                          icon: const Icon(
                            Icons.more_vert,
                            size: 20,
                            color: AppColors.textSecondary,
                          ),
                          onSelected: (val) {
                            if (val == 'logout') {
                              context.read<AuthCubit>().logout();
                            }
                          },
                          itemBuilder: (_) => [
                            const PopupMenuItem(
                              value: 'logout',
                              child: Text('Logout'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Connection Banner (Auto-Reconnection State)
                  StreamBuilder<WsConnectionStatus>(
                    stream: _wsClient.statusStream,
                    initialData: _wsClient.currentStatus,
                    builder: (context, snapshot) {
                      return ConnectionBanner(
                        status: snapshot.data ?? WsConnectionStatus.connected,
                      );
                    },
                  ),

                  // Search Bar
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    color: Colors.white,
                    child: TextField(
                      controller: _searchController,
                      onChanged: (q) =>
                          context.read<RoomsCubit>().setSearchQuery(q),
                      decoration: InputDecoration(
                        hintText: 'Search or start new chat',
                        prefixIcon: const Icon(
                          Icons.search,
                          size: 18,
                          color: AppColors.textMuted,
                        ),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 16),
                                onPressed: () {
                                  _searchController.clear();
                                  context.read<RoomsCubit>().setSearchQuery('');
                                },
                              )
                            : null,
                      ),
                    ),
                  ),
                  const Divider(height: 1),

                  // Conversation List
                  Expanded(child: _buildConversationList(isWide: true)),
                ],
              ),
            ),
          ),

          // Right Chat Area (Active Chat or Empty Placeholder)
          Expanded(
            child: BlocBuilder<RoomsCubit, RoomsState>(
              builder: (context, state) {
                final activeRoomId = state is RoomsLoaded
                    ? state.activeRoomId
                    : null;

                if (activeRoomId == null) {
                  return const EmptyChatPlaceholder();
                }

                return ChatView(
                  key: ValueKey(activeRoomId),
                  roomId: activeRoomId,
                  currentUserId: widget.currentUser.id,
                  currentUserName: widget.currentUser.displayName,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ==================== MOBILE LAYOUT (SINGLE-PANE) ====================
  Widget _buildMobileLayout(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('XChat'),
        actions: [
          IconButton(
            icon: const Icon(Icons.group_add_rounded),
            tooltip: 'New Group',
            onPressed: _showCreateGroupDialog,
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (val) {
              if (val == 'logout') context.read<AuthCubit>().logout();
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                enabled: false,
                child: Text(
                  'Logged in as @${widget.currentUser.username}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textMuted,
                  ),
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(value: 'logout', child: Text('Logout')),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Connection Banner
          StreamBuilder<WsConnectionStatus>(
            stream: _wsClient.statusStream,
            initialData: _wsClient.currentStatus,
            builder: (context, snapshot) {
              return ConnectionBanner(
                status: snapshot.data ?? WsConnectionStatus.connected,
              );
            },
          ),

          // Search bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: TextField(
              controller: _searchController,
              onChanged: (q) => context.read<RoomsCubit>().setSearchQuery(q),
              decoration: const InputDecoration(
                hintText: 'Search conversations...',
                prefixIcon: Icon(
                  Icons.search,
                  size: 18,
                  color: AppColors.textMuted,
                ),
              ),
            ),
          ),
          const Divider(height: 1),

          // Conversation List
          Expanded(child: _buildConversationList(isWide: false)),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showNewChatDialog,
        tooltip: 'New Chat',
        child: const Icon(Icons.chat_rounded),
      ),
    );
  }

  Widget _buildConversationList({required bool isWide}) {
    return BlocBuilder<RoomsCubit, RoomsState>(
      builder: (context, state) {
        if (state is RoomsLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        if (state is RoomsError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.error_outline_rounded,
                  size: 40,
                  color: AppColors.error,
                ),
                const SizedBox(height: 8),
                Text(
                  state.message,
                  style: const TextStyle(color: AppColors.error),
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: () => context.read<RoomsCubit>().loadRooms(),
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        }

        if (state is RoomsLoaded) {
          final rooms = state.filteredRooms;

          if (rooms.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      _searchController.text.isNotEmpty
                          ? Icons.search_off_rounded
                          : Icons.chat_bubble_outline_rounded,
                      size: 48,
                      color: AppColors.textMuted,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _searchController.text.isNotEmpty
                          ? 'No conversations matching "${_searchController.text}"'
                          : 'No conversations yet.\nStart a chat with a contact or create a group!',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                        height: 1.4,
                      ),
                    ),
                    if (_searchController.text.isEmpty) ...[
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: _showNewChatDialog,
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('Start New Chat'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          }

          return ListView.separated(
            itemCount: rooms.length,
            separatorBuilder: (_, __) => const Divider(height: 0.5, indent: 70),
            itemBuilder: (context, index) {
              final room = rooms[index];
              final isSelected = isWide && state.activeRoomId == room.id;

              return ConversationTile(
                room: room,
                currentUserId: widget.currentUser.id,
                isSelected: isSelected,
                onTap: () {
                  final roomsCubit = context.read<RoomsCubit>();
                  if (isWide) {
                    roomsCubit.selectRoom(room.id);
                  } else {
                    roomsCubit.selectRoom(room.id);
                    Navigator.of(context)
                        .push(
                          MaterialPageRoute<void>(
                            builder: (_) => ChatDetailPage(
                              roomId: room.id,
                              currentUserId: widget.currentUser.id,
                              currentUserName: widget.currentUser.displayName,
                            ),
                          ),
                        )
                        .then((_) {
                          if (mounted) {
                            roomsCubit.selectRoom(null);
                          }
                        });
                  }
                },
              );
            },
          );
        }

        return const SizedBox.shrink();
      },
    );
  }
}
