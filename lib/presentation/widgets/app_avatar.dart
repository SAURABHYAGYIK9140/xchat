import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

class AppAvatar extends StatelessWidget {
  final String? imageUrl;
  final String name;
  final bool isGroup;
  final double radius;
  final bool isOnline;
  final bool showOnlineIndicator;

  const AppAvatar({
    super.key,
    this.imageUrl,
    required this.name,
    this.isGroup = false,
    this.radius = 24,
    this.isOnline = false,
    this.showOnlineIndicator = false,
  });

  String _getInitials(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return isGroup ? 'G' : 'U';
    final parts = trimmed.split(' ').where((p) => p.isNotEmpty).toList();
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return trimmed.substring(0, trimmed.length >= 2 ? 2 : 1).toUpperCase();
  }

  Color _getBackgroundColor() {
    if (isGroup) {
      return const Color(0xFF00A884).withAlpha(40);
    }
    // Deterministic pleasant palette based on name hash
    final hash = name.hashCode.abs();
    final colors = [
      const Color(0xFF008069),
      const Color(0xFF00A884),
      const Color(0xFF0284C7),
      const Color(0xFF6366F1),
      const Color(0xFF8B5CF6),
      const Color(0xFFEC4899),
      const Color(0xFF14B8A6),
    ];
    return colors[hash % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    final bool hasImage = imageUrl != null &&
        imageUrl!.trim().isNotEmpty &&
        !imageUrl!.contains('example.com') &&
        (imageUrl!.startsWith('http://') || imageUrl!.startsWith('https://'));

    Widget avatarContent;

    if (hasImage) {
      avatarContent = ClipOval(
        child: Image.network(
          imageUrl!,
          width: radius * 2,
          height: radius * 2,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _buildFallback(),
        ),
      );
    } else {
      avatarContent = _buildFallback();
    }

    if (!showOnlineIndicator && !isGroup) {
      return avatarContent;
    }

    return Stack(
      clipBehavior: Clip.none,
      children: [
        avatarContent,
        if (showOnlineIndicator && isOnline)
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: (radius * 0.45).clamp(8.0, 14.0),
              height: (radius * 0.45).clamp(8.0, 14.0),
              decoration: BoxDecoration(
                color: AppColors.onlineIndicator,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
            ),
          ),
        if (isGroup && showOnlineIndicator)
          Positioned(
            right: -2,
            bottom: -2,
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: const BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.group, size: 10, color: Colors.white),
            ),
          ),
      ],
    );
  }

  Widget _buildFallback() {
    if (isGroup) {
      return Container(
        width: radius * 2,
        height: radius * 2,
        decoration: BoxDecoration(
          color: _getBackgroundColor(),
          shape: BoxShape.circle,
        ),
        child: Center(
          child: Icon(
            Icons.groups_rounded,
            size: radius * 1.1,
            color: AppColors.primary,
          ),
        ),
      );
    }

    return Container(
      width: radius * 2,
      height: radius * 2,
      decoration: BoxDecoration(
        color: _getBackgroundColor(),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          _getInitials(name),
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: radius * 0.75,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }
}
