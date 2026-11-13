import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../data/models/room_model.dart';
import '../../data/repositories/auth_repository.dart';
import '../../logic/chat/chat_cubit.dart';

class GroupInfoDialog extends StatefulWidget {
  final RoomModel room;
  final String currentUserId;
  final ChatCubit chatCubit;

  const GroupInfoDialog({
    super.key,
    required this.room,
    required this.currentUserId,
    required this.chatCubit,
  });

  @override
  State<GroupInfoDialog> createState() => _GroupInfoDialogState();
}

class _GroupInfoDialogState extends State<GroupInfoDialog> {
  final AuthRepository _authRepository = AuthRepository();
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    _checkAdminStatus();
  }

  void _checkAdminStatus() {
    final myMember = widget.room.members.where((m) => m.userId == widget.currentUserId);
    if (myMember.isNotEmpty) {
      _isAdmin = myMember.first.role == 'admin';
    }
  }

  void _showAddMemberModal() async {
    final existingUserIds = widget.room.members.map((m) => m.userId).toSet();
    final allUsers = await _authRepository.getUsers();
    final candidateUsers = allUsers.where((u) => !existingUserIds.contains(u.id)).toList();

    if (!mounted) return;
    final parentNav = Navigator.of(context);

    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text('Add Member to Group', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
              const Divider(height: 1),
              if (candidateUsers.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('All registered contacts are already in this group.'),
                )
              else
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: candidateUsers.length,
                    separatorBuilder: (_, __) => const Divider(height: 0.5, indent: 70),
                    itemBuilder: (context, idx) {
                      final user = candidateUsers[idx];
                      return ListTile(
                        leading: CircleAvatar(backgroundImage: NetworkImage(user.avatarUrl)),
                        title: Text(user.displayName, style: const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text('@${user.username}'),
                        trailing: ElevatedButton(
                          onPressed: () async {
                            Navigator.of(ctx).pop();
                            await widget.chatCubit.addMember(user.id);
                            parentNav.pop();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          ),
                          child: const Text('Add'),
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  void _handleRemoveMember(RoomMemberModel member) async {
    final parentNav = Navigator.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(member.userId == widget.currentUserId ? 'Leave Group?' : 'Remove Member?'),
        content: Text(
          member.userId == widget.currentUserId
              ? 'Are you sure you want to leave "${widget.room.name}"?'
              : 'Remove ${member.user?.displayName ?? "this member"} from the group?',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: Text(member.userId == widget.currentUserId ? 'Leave' : 'Remove'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await widget.chatCubit.removeMember(member.userId);
      parentNav.pop();
    }
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
                  const Text('Group Information', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            const Divider(),

            // Group Banner
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 32,
                    backgroundColor: AppColors.primary.withAlpha(38),
                    backgroundImage: widget.room.avatarUrl != null ? NetworkImage(widget.room.avatarUrl!) : null,
                    child: widget.room.avatarUrl == null
                        ? const Icon(Icons.groups_rounded, size: 36, color: AppColors.primary)
                        : null,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.room.name,
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                        ),
                        if (widget.room.description != null && widget.room.description!.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              widget.room.description!,
                              style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                            ),
                          ),
                        const SizedBox(height: 4),
                        Text(
                          '${widget.room.members.length} participants',
                          style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(),

            // Members Header & Add Action
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${widget.room.members.length} PARTICIPANTS',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textMuted, letterSpacing: 0.5),
                  ),
                  if (_isAdmin)
                    TextButton.icon(
                      onPressed: _showAddMemberModal,
                      icon: const Icon(Icons.person_add_rounded, size: 16, color: AppColors.primary),
                      label: const Text('Add Member', style: TextStyle(fontSize: 13, color: AppColors.primary, fontWeight: FontWeight.w600)),
                    ),
                ],
              ),
            ),

            // Members List
            Expanded(
              child: ListView.separated(
                itemCount: widget.room.members.length,
                separatorBuilder: (_, __) => const Divider(height: 0.5, indent: 70),
                itemBuilder: (context, index) {
                  final member = widget.room.members[index];
                  final isCurrent = member.userId == widget.currentUserId;
                  final isMemberAdmin = member.role == 'admin';
                  final displayName = member.user?.displayName ?? (isCurrent ? 'You' : 'Member');
                  final avatar = member.user?.avatarUrl ?? 'https://api.dicebear.com/7.x/avataaars/svg?seed=${member.userId}';

                  return ListTile(
                    leading: CircleAvatar(
                      radius: 20,
                      backgroundImage: NetworkImage(avatar),
                    ),
                    title: Row(
                      children: [
                        Text(displayName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14.5)),
                        if (isCurrent)
                          const Padding(
                            padding: EdgeInsets.only(left: 6),
                            child: Text('(You)', style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
                          ),
                      ],
                    ),
                    subtitle: Text(
                      isMemberAdmin ? 'Group Admin' : 'Member',
                      style: TextStyle(
                        fontSize: 12,
                        color: isMemberAdmin ? AppColors.primary : AppColors.textMuted,
                        fontWeight: isMemberAdmin ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                    trailing: (_isAdmin && !isMemberAdmin) || isCurrent
                        ? IconButton(
                            icon: Icon(
                              isCurrent ? Icons.exit_to_app_rounded : Icons.person_remove_rounded,
                              size: 20,
                              color: AppColors.error,
                            ),
                            tooltip: isCurrent ? 'Leave Group' : 'Remove Member',
                            onPressed: () => _handleRemoveMember(member),
                          )
                        : null,
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
