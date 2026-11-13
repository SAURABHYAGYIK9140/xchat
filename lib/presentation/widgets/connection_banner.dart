import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/network/websocket_client.dart';

class ConnectionBanner extends StatelessWidget {
  final WsConnectionStatus status;

  const ConnectionBanner({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    if (status == WsConnectionStatus.connected) {
      return const SizedBox.shrink();
    }

    final isConnecting = status == WsConnectionStatus.connecting || status == WsConnectionStatus.reconnecting;
    final message = isConnecting ? 'Connecting to XChat...' : 'Waiting for network connection...';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
      color: isConnecting ? AppColors.warningSurface : const Color(0xFFFEE2E2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 12,
            height: 12,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(
                isConnecting ? AppColors.warning : AppColors.error,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            message,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: isConnecting ? const Color(0xFF92400E) : const Color(0xFF991B1B),
            ),
          ),
        ],
      ),
    );
  }
}

