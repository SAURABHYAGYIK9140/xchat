import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../data/models/room_model.dart';
import '../../data/models/user_model.dart';
import '../../data/repositories/auth_repository.dart';
import '../../logic/rooms/rooms_cubit.dart';
import '../widgets/app_avatar.dart';

class CreateGroupScreen extends StatefulWidget {
  final String currentUserId;
  final RoomsCubit roomsCubit;
  final ValueChanged<RoomModel>? onGroupCreated;

  const CreateGroupScreen({
    super.key,
    required this.currentUserId,
    required this.roomsCubit,
    this.onGroupCreated,
  });

  @override
  State<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends State<CreateGroupScreen> {
  final _nameController = TextEditingController();
  final _descController = TextEditingController();
  final AuthRepository _authRepository = AuthRepository();

  List<UserModel> _availableUsers = [];
  final Set<String> _selectedUserIds = {};
  bool _isLoading = true;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    try {
      final users = await _authRepository.getUsers(
        excludeUserId: widget.currentUserId,
      );
      if (mounted) {
        setState(() {
          _availableUsers = users;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _handleCreate() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a group subject')),
      );
      return;
    }

    if (_selectedUserIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one participant')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final nav = Navigator.of(context);
      final room = await widget.roomsCubit.createGroup(
        name: name,
        description: _descController.text.trim().isNotEmpty
            ? _descController.text.trim()
            : null,
        memberUserIds: _selectedUserIds.toList(),
      );
      nav.pop();
      if (widget.onGroupCreated != null) {
        widget.onGroupCreated!(room);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to create group: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selectedUsers = _availableUsers
        .where((u) => _selectedUserIds.contains(u.id))
        .toList();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'New Group',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            Text(
              '${_selectedUserIds.length} of ${_availableUsers.length} selected',
              style: const TextStyle(fontSize: 12, color: Colors.white70),
            ),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Group Info Card
                Container(
                  padding: const EdgeInsets.all(16),
                  color: AppColors.secondarySurface,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Group Default Avatar
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withAlpha(40),
                          shape: BoxShape.circle,
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.groups_rounded,
                            size: 32,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),

                      // Input Fields
                      Expanded(
                        child: Column(
                          children: [
                            TextField(
                              controller: _nameController,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                              decoration: const InputDecoration(
                                hintText: 'Type group subject here...',
                                filled: false,
                                contentPadding: EdgeInsets.symmetric(
                                  vertical: 4,
                                ),
                                border: UnderlineInputBorder(
                                  borderSide: BorderSide(
                                    color: AppColors.primary,
                                    width: 1.5,
                                  ),
                                ),
                                enabledBorder: UnderlineInputBorder(
                                  borderSide: BorderSide(
                                    color: AppColors.divider,
                                    width: 1,
                                  ),
                                ),
                                focusedBorder: UnderlineInputBorder(
                                  borderSide: BorderSide(
                                    color: AppColors.primary,
                                    width: 2,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            TextField(
                              controller: _descController,
                              style: const TextStyle(fontSize: 13),
                              decoration: const InputDecoration(
                                hintText: 'Group description (optional)',
                                filled: false,
                                contentPadding: EdgeInsets.symmetric(
                                  vertical: 4,
                                ),
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Selected Participants Horizontal Tray (Animated)
                if (selectedUsers.isNotEmpty)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    height: 85,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      border: Border(
                        bottom: BorderSide(
                          color: AppColors.divider,
                          width: 0.5,
                        ),
                      ),
                    ),
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      scrollDirection: Axis.horizontal,
                      itemCount: selectedUsers.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 12),
                      itemBuilder: (context, idx) {
                        final user = selectedUsers[idx];
                        return Stack(
                          children: [
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                AppAvatar(
                                  imageUrl: user.avatarUrl,
                                  name: user.displayName,
                                  radius: 22,
                                ),
                                const SizedBox(height: 4),
                                SizedBox(
                                  width: 54,
                                  child: Text(
                                    user.displayName.split(' ').first,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: AppColors.textSecondary,
                                    ),
                                    textAlign: TextAlign.center,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            Positioned(
                              top: -2,
                              right: 2,
                              child: InkWell(
                                onTap: () {
                                  setState(() {
                                    _selectedUserIds.remove(user.id);
                                  });
                                },
                                child: Container(
                                  padding: const EdgeInsets.all(2),
                                  decoration: const BoxDecoration(
                                    color: Color(0xFF64748B),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.close,
                                    size: 12,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),

                // Participants Section Header
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 14, 16, 6),
                  child: Row(
                    children: [
                      Text(
                        'CONTACTS',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textMuted,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),

                // Contact Selection List
                Expanded(
                  child: ListView.separated(
                    itemCount: _availableUsers.length,
                    separatorBuilder: (_, __) =>
                        const Divider(height: 0.5, indent: 72),
                    itemBuilder: (context, index) {
                      final user = _availableUsers[index];
                      final isSelected = _selectedUserIds.contains(user.id);

                      return CheckboxListTile(
                        value: isSelected,
                        activeColor: AppColors.primary,
                        checkboxShape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                        onChanged: (checked) {
                          setState(() {
                            if (checked == true) {
                              _selectedUserIds.add(user.id);
                            } else {
                              _selectedUserIds.remove(user.id);
                            }
                          });
                        },
                        secondary: AppAvatar(
                          imageUrl: user.avatarUrl,
                          name: user.displayName,
                          radius: 20,
                          isOnline: user.isOnline,
                          showOnlineIndicator: true,
                        ),
                        title: Text(
                          user.displayName,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        subtitle: Text(
                          '@${user.username}',
                          style: const TextStyle(
                            fontSize: 12.5,
                            color: AppColors.textMuted,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _isSubmitting ? null : _handleCreate,
        backgroundColor: AppColors.primary,
        tooltip: 'Create Group',
        child: _isSubmitting
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : const Icon(Icons.check_rounded, color: Colors.white, size: 26),
      ),
    );
  }
}
