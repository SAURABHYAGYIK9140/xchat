import 'package:intl/intl.dart';

class DateFormatter {
  static String formatMessageTime(DateTime dateTime) {
    return DateFormat('h:mm a').format(dateTime.toLocal());
  }

  static String formatConversationTime(DateTime dateTime) {
    final now = DateTime.now();
    final local = dateTime.toLocal();
    final difference = now.difference(local);

    final sameDay = now.year == local.year && now.month == local.month && now.day == local.day;
    if (sameDay) {
      return DateFormat('h:mm a').format(local);
    }

    final yesterday = now.subtract(const Duration(days: 1));
    final wasYesterday = yesterday.year == local.year && yesterday.month == local.month && yesterday.day == local.day;
    if (wasYesterday) {
      return 'Yesterday';
    }

    if (difference.inDays < 7) {
      return DateFormat('EEEE').format(local);
    }

    return DateFormat('d/M/yyyy').format(local);
  }

  static String formatDateDivider(DateTime dateTime) {
    final now = DateTime.now();
    final local = dateTime.toLocal();

    final sameDay = now.year == local.year && now.month == local.month && now.day == local.day;
    if (sameDay) {
      return 'Today';
    }

    final yesterday = now.subtract(const Duration(days: 1));
    final wasYesterday = yesterday.year == local.year && yesterday.month == local.month && yesterday.day == local.day;
    if (wasYesterday) {
      return 'Yesterday';
    }

    return DateFormat('MMMM d, yyyy').format(local);
  }

  static String formatLastSeen(DateTime? dateTime) {
    if (dateTime == null) return 'Offline';
    final now = DateTime.now();
    final local = dateTime.toLocal();
    final difference = now.difference(local);

    if (difference.inMinutes < 1) {
      return 'Last seen just now';
    } else if (difference.inMinutes < 60) {
      return 'Last seen ${difference.inMinutes}m ago';
    } else if (difference.inHours < 24 && now.day == local.day) {
      return 'Last seen today at ${DateFormat('h:mm a').format(local)}';
    } else if (difference.inDays < 2) {
      return 'Last seen yesterday at ${DateFormat('h:mm a').format(local)}';
    } else {
      return 'Last seen ${DateFormat('d/M/yy').format(local)}';
    }
  }
}

