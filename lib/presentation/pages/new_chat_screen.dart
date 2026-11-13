import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/page_transitions.dart';
import '../../data/models/room_model.dart';
import '../../data/models/user_model.dart';
import '../../data/repositories/auth_repository.dart';
import '../../logic/rooms/rooms_cubit.dart';
import '../widgets/app_avatar.dart';
import 'create_group_screen.dart';

class NewChatScreen extends StatefulWidget {
  final String currentUserId;
  final RoomsCubit roomsCubit;
  final ValueChanged<RoomModel>? onRoomSelected;

  const NewChatScreen({
    super.key,
    required this.currentUserId,
    required this.roomsCubit,
    this.onRoomSelected,
  });

  @override
  State<NewChatScreen> createState() => _NewChatScreenState();
}

class _NewChatScreenState extends State<NewChatScreen> {
  final AuthRepository _authRepository = AuthRepository();
  final TextEditingController _searchController = TextEditingController();
  List<UserModel> _allUsers = [];
  List<UserModel> _filteredUsers = [];
  bool _isLoading = true;
  bool _isSearching = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadUsers();
    _searchController.addListener(_onSearchChanged);
  }

  void _onSearchChanged() {
    final query = _searchController.text.trim().toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredUsers = _allUsers;
      } else {
        _filteredUsers = _allUsers.where((u) {
          return u.displayName.toLowerCase().contains(query) || u.username.toLowerCase().contains(query);
        }).toList();
      }
    });
  }

  Future<void> _loadUsers() async {
    try {
      final users = await _authRepository.getUsers(excludeUserId: widget.currentUserId);
      if (mounted) {
        setState(() {
          _allUsers = users;
          _filteredUsers = users;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceAll('Exception: ', '');
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _openCreateGroupScreen() {
    Navigator.of(context).push(
      SlidePageRoute<void>(
        page: CreateGroupScreen(
          currentUserId: widget.currentUserId,
          roomsCubit: widget.roomsCubit,
          onGroupCreated: (room) {
            Navigator.of(context).pop(); // Close new chat screen
            if (widget.onRoomSelected != null) {
              widget.onRoomSelected!(room);
            }
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                style: const TextStyle(color: Colors.white, fontSize: 16),
                decoration: const InputDecoration(
                  hintText: 'Search contacts...',
                  hintStyle: TextStyle(color: Colors.white70, fontSize: 16),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  filled: false,
                ),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Select Contact', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                  Text(
                    _isLoading ? 'Loading...' : '${_allUsers.length} contacts',
                    style: const TextStyle(fontSize: 12, color: Colors.white70),
                  ),
                ],
              ),
        actions: [
          IconButton(
            icon: Icon(_isSearching ? Icons.close : Icons.search_rounded),
            onPressed: () {
              setState(() {
                if (_isSearching) {
                  _isSearching = false;
                  _searchController.clear();
                } else {
                  _isSearching = true;
                }
              });
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline_rounded, size: 40, color: AppColors.error),
                      const SizedBox(height: 8),
                      Text(_error!, style: const TextStyle(color: AppColors.error)),
                      const SizedBox(height: 12),
                      ElevatedButton(onPressed: _loadUsers, child: const Text('Retry')),
                    ],
                  ),
                )
              : ListView(
                  children: [
                    if (!_isSearching) ...[
                      // New Group Action Tile
                      ListTile(
                        leading: Container(
                          width: 44,
                          height: 44,
                          decoration: const BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.group_add_rounded, color: Colors.white, size: 22),
                        ),
                        title: const Text(
                          'New Group',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                        ),
                        subtitle: const Text(
                          'Create a group conversation',
                          style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                        ),
                        onTap: _openCreateGroupScreen,
                      ),
                      const Divider(height: 0.5, indent: 72),
                      const Padding(
                        padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                        child: Text(
                          'CONTACTS ON XCHAT',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textMuted,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],

                    if (_filteredUsers.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(32),
                        child: Center(
                          child: Text(
                            _isSearching ? 'No contacts found matching "${_searchController.text}"' : 'No registered contacts found',
                            style: const TextStyle(color: AppColors.textSecondary),
                          ),
                        ),
                      )
                    else
                      ..._filteredUsers.map((user) {
                        return ListTile(
                          leading: AppAvatar(
                            imageUrl: user.avatarUrl,
                            name: user.displayName,
                            radius: 22,
                            isOnline: user.isOnline,
                            showOnlineIndicator: true,
                          ),
                          title: Text(
                            user.displayName,
                            style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                          ),
                          subtitle: Text(
                            user.isOnline ? 'Online' : '@${user.username}',
                            style: TextStyle(
                              fontSize: 13,
                              color: user.isOnline ? AppColors.accentGreen : AppColors.textMuted,
                              fontWeight: user.isOnline ? FontWeight.w600 : FontWeight.normal,
                            ),
                          ),
                          onTap: () async {
                            final nav = Navigator.of(context);
                            final room = await widget.roomsCubit.createDirectRoom(user.id);
                            nav.pop();
                            if (widget.onRoomSelected != null) {
                              widget.onRoomSelected!(room);
                            }
                          },
                        );
                      }),
                  ],
                ),
    );
  }
}

