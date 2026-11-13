import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../data/models/room_model.dart';
import '../../data/models/user_model.dart';
import '../../data/repositories/auth_repository.dart';
import '../../logic/rooms/rooms_cubit.dart';
import 'create_group_dialog.dart';

class NewChatDialog extends StatefulWidget {
  final String currentUserId;
  final RoomsCubit roomsCubit;
  final ValueChanged<RoomModel>? onRoomSelected;

  const NewChatDialog({
    super.key,
    required this.currentUserId,
    required this.roomsCubit,
    this.onRoomSelected,
  });

  @override
  State<NewChatDialog> createState() => _NewChatDialogState();
}

class _NewChatDialogState extends State<NewChatDialog> {
  final AuthRepository _authRepository = AuthRepository();
  List<UserModel> _users = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    try {
      final users = await _authRepository.getUsers(excludeUserId: widget.currentUserId);
      if (mounted) {
        setState(() {
          _users = users;
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
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 450, maxHeight: 550),
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'New Conversation',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            const Divider(),

            // New Group Action
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: AppColors.primary,
                child: Icon(Icons.group_add_rounded, color: Colors.white, size: 20),
              ),
              title: const Text('New Group', style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: const Text('Create a conversation with multiple participants', style: TextStyle(fontSize: 12)),
              onTap: () {
                Navigator.of(context).pop();
                showDialog<void>(
                  context: context,
                  builder: (_) => CreateGroupDialog(
                    currentUserId: widget.currentUserId,
                    roomsCubit: widget.roomsCubit,
                    onGroupCreated: widget.onRoomSelected,
                  ),
                );
              },
            ),
            const Divider(),

            // User List Section
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 12, 20, 6),
              child: Row(
                children: [
                  Text(
                    'CONTACTS ON XCHAT',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textMuted,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? Center(child: Text(_error!, style: const TextStyle(color: AppColors.error)))
                      : _users.isEmpty
                          ? const Center(child: Text('No other users found'))
                          : ListView.separated(
                              itemCount: _users.length,
                              separatorBuilder: (_, __) => const Divider(height: 0.5, indent: 70),
                              itemBuilder: (context, index) {
                                final user = _users[index];
                                return ListTile(
                                  leading: Stack(
                                    children: [
                                      CircleAvatar(
                                        radius: 20,
                                        backgroundImage: NetworkImage(user.avatarUrl),
                                      ),
                                      if (user.isOnline)
                                        Positioned(
                                          right: 0,
                                          bottom: 0,
                                          child: Container(
                                            width: 10,
                                            height: 10,
                                            decoration: BoxDecoration(
                                              color: AppColors.onlineIndicator,
                                              shape: BoxShape.circle,
                                              border: Border.all(color: Colors.white, width: 1.5),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  title: Text(
                                    user.displayName,
                                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                                  ),
                                  subtitle: Text(
                                    '@${user.username} • ${user.isOnline ? "Online" : "Offline"}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: user.isOnline ? AppColors.accentGreen : AppColors.textMuted,
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
                              },
                            ),
            ),
          ],
        ),
      ),
    );
  }
}
