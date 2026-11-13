import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/constants/app_colors.dart';
import '../../data/models/user_model.dart';
import '../../data/repositories/auth_repository.dart';
import '../../logic/rooms/rooms_cubit.dart';

class CreateGroupDialog extends StatefulWidget {
  final String currentUserId;

  const CreateGroupDialog({super.key, required this.currentUserId});

  @override
  State<CreateGroupDialog> createState() => _CreateGroupDialogState();
}

class _CreateGroupDialogState extends State<CreateGroupDialog> {
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
      final users = await _authRepository.getUsers(excludeUserId: widget.currentUserId);
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
        const SnackBar(content: Text('Please enter a group name')),
      );
      return;
    }

    if (_selectedUserIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one member')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final nav = Navigator.of(context);
      await context.read<RoomsCubit>().createGroup(
            name: name,
            description: _descController.text.trim().isNotEmpty ? _descController.text.trim() : null,
            memberUserIds: _selectedUserIds.toList(),
          );
      nav.pop();
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to create group: $e')),
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
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480, maxHeight: 620),
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Create New Group',
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

            // Form inputs
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Group Subject', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      hintText: 'e.g. Mobile Engineering Team',
                      prefixIcon: Icon(Icons.group_outlined, size: 18, color: AppColors.textSecondary),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text('Description (Optional)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _descController,
                    decoration: const InputDecoration(
                      hintText: 'e.g. Cross-platform chat discussion',
                      prefixIcon: Icon(Icons.info_outline_rounded, size: 18, color: AppColors.textSecondary),
                    ),
                  ),
                ],
              ),
            ),

            // Members selection section
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'SELECT MEMBERS',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textMuted,
                      letterSpacing: 0.5,
                    ),
                  ),
                  Text(
                    '${_selectedUserIds.length} selected',
                    style: const TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),

            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _availableUsers.isEmpty
                      ? const Center(child: Text('No users available to add'))
                      : ListView.separated(
                          itemCount: _availableUsers.length,
                          separatorBuilder: (_, __) => const Divider(height: 0.5, indent: 70),
                          itemBuilder: (context, index) {
                            final user = _availableUsers[index];
                            final isSelected = _selectedUserIds.contains(user.id);

                            return CheckboxListTile(
                              value: isSelected,
                              activeColor: AppColors.primary,
                              onChanged: (checked) {
                                setState(() {
                                  if (checked == true) {
                                    _selectedUserIds.add(user.id);
                                  } else {
                                    _selectedUserIds.remove(user.id);
                                  }
                                });
                              },
                              secondary: CircleAvatar(
                                radius: 18,
                                backgroundImage: NetworkImage(user.avatarUrl),
                              ),
                              title: Text(user.displayName, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600)),
                              subtitle: Text('@${user.username}', style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
                            );
                          },
                        ),
            ),

            // Footer Submit Action
            const Divider(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _isSubmitting ? null : _handleCreate,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: _isSubmitting
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Create Group', style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

