import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../data/models/message_model.dart';

class StatusTick extends StatelessWidget {
  final MessageDeliveryStatus status;

  const StatusTick({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    switch (status) {
      case MessageDeliveryStatus.pending:
        return const Icon(
          Icons.access_time_rounded,
          size: 12,
          color: AppColors.textMuted,
        );
      case MessageDeliveryStatus.sent:
        return const Icon(
          Icons.check_rounded,
          size: 14,
          color: AppColors.deliveredTick,
        );
      case MessageDeliveryStatus.delivered:
        return const Icon(
          Icons.done_all_rounded,
          size: 14,
          color: AppColors.deliveredTick,
        );
      case MessageDeliveryStatus.read:
        return const Icon(
          Icons.done_all_rounded,
          size: 14,
          color: AppColors.readTick,
        );
    }
  }
}
