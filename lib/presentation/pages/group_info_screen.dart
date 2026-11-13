import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/date_formatter.dart';
import '../../data/models/room_model.dart';
import '../../data/repositories/auth_repository.dart';
import '../../logic/chat/chat_cubit.dart';
import '../widgets/app_avatar.dart';

class GroupInfoScreen extends StatefulWidget {
  final RoomModel room;
  final String currentUserId;
  final ChatCubit chatCubit;

  const GroupInfoScreen({
    super.key,
    required this.room,
    required this.currentUserId,
    required this.chatCubit,
  });

  @override
  State<GroupInfoScreen> createState() => _GroupInfoScreenState();
}

class _GroupInfoScreenState extends State<GroupInfoScreen> {
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
                        leading: AppAvatar(
                          imageUrl: user.avatarUrl,
                          name: user.displayName,
                          radius: 20,
                          isOnline: user.isOnline,
                          showOnlineIndicator: true,
                        ),
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
    final isMe = member.userId == widget.currentUserId;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isMe ? 'Leave Group?' : 'Remove Member?'),
        content: Text(
          isMe
              ? 'Are you sure you want to leave "${widget.room.name}"?'
              : 'Remove ${member.user?.displayName ?? "this member"} from the group?',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: Text(isMe ? 'Leave' : 'Remove'),
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
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      appBar: AppBar(
        title: const Text('Group Info', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
      ),
      body: ListView(
        children: [
          // Group Hero Profile Container
          Container(
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
            color: Colors.white,
            child: Column(
              children: [
                Hero(
                  tag: 'group_avatar_${widget.room.id}',
                  child: AppAvatar(
                    imageUrl: widget.room.avatarUrl,
                    name: widget.room.name,
                    isGroup: true,
                    radius: 46,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  widget.room.name,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                ),
                const SizedBox(height: 4),
                Text(
                  'Group • ${widget.room.members.length} participants',
                  style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 4),
                Text(
                  'Created ${DateFormatter.formatDateDivider(widget.room.createdAt)}',
                  style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Group Description
          if (widget.room.description != null && widget.room.description!.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(16),
              color: Colors.white,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Description', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.primary)),
                  const SizedBox(height: 6),
                  Text(
                    widget.room.description!,
                    style: const TextStyle(fontSize: 14, color: AppColors.textPrimary, height: 1.4),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
          ],

          // Participants Section
          Container(
            color: Colors.white,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                  child: Text(
                    '${widget.room.members.length} PARTICIPANTS',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textMuted, letterSpacing: 0.5),
                  ),
                ),

                // Add Member Tile (if admin)
                if (_isAdmin) ...[
                  ListTile(
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: const BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.person_add_rounded, color: Colors.white, size: 20),
                    ),
                    title: const Text('Add Participant', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                    onTap: _showAddMemberModal,
                  ),
                  const Divider(height: 0.5, indent: 70),
                ],

                // Members List
                ...widget.room.members.map((member) {
                  final isCurrent = member.userId == widget.currentUserId;
                  final isMemberAdmin = member.role == 'admin';
                  final displayName = member.user?.displayName ?? (isCurrent ? 'You' : 'Member');
                  final username = member.user?.username ?? '';

                  return ListTile(
                    leading: AppAvatar(
                      imageUrl: member.user?.avatarUrl,
                      name: displayName,
                      radius: 20,
                      isOnline: member.user?.isOnline ?? false,
                      showOnlineIndicator: true,
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
                      isMemberAdmin ? 'Group Admin' : (username.isNotEmpty ? '@$username' : 'Participant'),
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
                }),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Leave Group Footer Tile
          Container(
            color: Colors.white,
            child: ListTile(
              leading: const Icon(Icons.logout_rounded, color: AppColors.error),
              title: const Text('Exit Group', style: TextStyle(color: AppColors.error, fontWeight: FontWeight.w600)),
              onTap: () {
                final myMember = widget.room.members.where((m) => m.userId == widget.currentUserId).firstOrNull;
                if (myMember != null) {
                  _handleRemoveMember(myMember);
                }
              },
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

