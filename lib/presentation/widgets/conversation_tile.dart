import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/date_formatter.dart';
import '../../data/models/room_model.dart';
import 'status_tick.dart';
import '../../data/models/message_model.dart';

class ConversationTile extends StatelessWidget {
  final RoomModel room;
  final String currentUserId;
  final bool isSelected;
  final VoidCallback onTap;

  const ConversationTile({
    super.key,
    required this.room,
    required this.currentUserId,
    this.isSelected = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final hasUnread = room.unreadCount > 0;
    final isLastMessageMine = room.lastMessageSenderId == currentUserId;

    return Material(
      color: isSelected ? AppColors.secondarySurface : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              // Avatar
              Stack(
                children: [
                  CircleAvatar(
                    radius: 25,
                    backgroundColor: room.isGroup ? const Color(0xFF00A884).withAlpha(38) : AppColors.secondarySurface,
                    backgroundImage: room.avatarUrl != null ? NetworkImage(room.avatarUrl!) : null,
                    child: room.avatarUrl == null
                        ? Icon(
                            room.isGroup ? Icons.groups_rounded : Icons.person_rounded,
                            color: room.isGroup ? AppColors.primary : AppColors.textSecondary,
                            size: 26,
                          )
                        : null,
                  ),
                  if (room.isGroup)
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: const BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.group, size: 10, color: Colors.white),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 14),

              // Conversation details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top row: Room Name & Timestamp
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            room.name,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: hasUnread ? FontWeight.w700 : FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (room.lastMessageTime != null)
                          Text(
                            DateFormatter.formatConversationTime(room.lastMessageTime!),
                            style: TextStyle(
                              fontSize: 12,
                              color: hasUnread ? AppColors.accentGreen : AppColors.textMuted,
                              fontWeight: hasUnread ? FontWeight.w600 : FontWeight.normal,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),

                    // Bottom row: Last message preview & Unread badge
                    Row(
                      children: [
                        if (isLastMessageMine) ...[
                          const StatusTick(status: MessageDeliveryStatus.read),
                          const SizedBox(width: 4),
                        ],
                        Expanded(
                          child: Text(
                            room.lastMessage ?? (room.isGroup ? 'Group created' : 'Tap to start chat'),
                            style: TextStyle(
                              fontSize: 13.5,
                              color: hasUnread ? AppColors.textPrimary : AppColors.textSecondary,
                              fontWeight: hasUnread ? FontWeight.w600 : FontWeight.normal,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (hasUnread)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: const BoxDecoration(
                              color: AppColors.unreadBadge,
                              shape: BoxShape.circle,
                            ),
                            constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
                            child: Center(
                              child: Text(
                                room.unreadCount.toString(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
