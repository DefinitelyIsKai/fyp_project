import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

/// Utility class for date and time formatting
/// 
/// Provides consistent date formatting across the application
class DateUtils {
  /// Formats a date as a relative time string (e.g., "2h ago", "Yesterday", "3d ago")
  /// 
  /// Examples:
  /// - "Just now" for < 1 minute
  /// - "5m ago" for minutes
  /// - "2h ago" for hours
  /// - "Yesterday" for 1 day ago
  /// - "3d ago" for 2-6 days ago
  /// - "25/12/2024" for older dates
  static String formatRelativeDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      if (difference.inHours == 0) {
        if (difference.inMinutes == 0) {
          return 'Just now';
        }
        return '${difference.inMinutes}m ago';
      }
      return '${difference.inHours}h ago';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  /// Formats a date as "YYYY-MM-DD" string
  static String formatDateString(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  /// Formats a date as "MMM d, yyyy" (e.g., "Dec 25, 2024")
  static String formatDate(DateTime date) {
    final month = _getMonthAbbreviation(date.month);
    return '${month} ${date.day.toString().padLeft(2, '0')}, ${date.year}';
  }

  /// Formats a time as "h:mm AM/PM" (e.g., "9:00 AM", "2:30 PM")
  static String formatTime(DateTime date) {
    final hour = date.hour == 0 ? 12 : (date.hour > 12 ? date.hour - 12 : date.hour);
    final minute = date.minute.toString().padLeft(2, '0');
    final period = date.hour < 12 ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }

  /// Formats a date and time together (e.g., "Dec 25, 2024, 9:00 AM")
  static String formatDateTime(DateTime date) {
    return '${formatDate(date)}, ${formatTime(date)}';
  }

  /// Formats an event date range
  /// 
  /// Handles same-day events, multi-day events, and single dates
  /// Examples:
  /// - Same day: "Dec 25, 2024, 9:00 AM - 5:00 PM"
  /// - Different days: "Dec 25, 2024 - Dec 27, 2024"
  /// - Single start: "Dec 25, 2024, 9:00 AM"
  /// - Single end: "Until Dec 27, 2024, 5:00 PM"
  static String formatEventDateRange({
    DateTime? startDate,
    DateTime? endDate,
  }) {
    if (startDate == null && endDate == null) {
      return 'Not specified';
    }
    
    if (startDate != null && endDate != null) {
      // Check if same day
      if (startDate.year == endDate.year &&
          startDate.month == endDate.month &&
          startDate.day == endDate.day) {
        // Same day: "Dec 25, 2024, 9:00 AM - 5:00 PM"
        return '${formatDate(startDate)}, ${formatTime(startDate)} - ${formatTime(endDate)}';
      } else {
        // Different days: "Dec 25, 2024 - Dec 27, 2024"
        return '${formatDate(startDate)} - ${formatDate(endDate)}';
      }
    } else if (startDate != null) {
      // Only start date: "Dec 25, 2024, 9:00 AM"
      return '${formatDate(startDate)}, ${formatTime(startDate)}';
    } else {
      // Only end date: "Until Dec 27, 2024, 5:00 PM"
      return 'Until ${formatDate(endDate!)}, ${formatTime(endDate)}';
    }
  }

  /// Formats a date using DateFormat (for more complex formatting)
  /// 
  /// Uses intl package's DateFormat for locale-aware formatting
  static String formatWithPattern(DateTime date, String pattern) {
    return DateFormat(pattern).format(date);
  }

  /// Gets month abbreviation (Jan, Feb, Mar, etc.)
  static String _getMonthAbbreviation(int month) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return months[month - 1];
  }

  /// Parses a Firestore timestamp to DateTime
  /// 
  /// Handles Timestamp, DateTime, and null values safely
  static DateTime parseTimestamp(dynamic value) {
    if (value == null) return DateTime.now();
    if (value is DateTime) return value;
    if (value is Timestamp) return value.toDate();
    if (value is Map) return DateTime.now();
    return DateTime.now();
  }

  /// Normalizes a date by removing time component (sets to midnight)
  static DateTime normalizeDate(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  /// Gets the start and end of a month
  static ({DateTime start, DateTime end}) getMonthRange(DateTime month) {
    return (
      start: DateTime(month.year, month.month, 1),
      end: DateTime(month.year, month.month + 1, 0),
    );
  }

  /// Formats a date as "time ago" string (e.g., "2 days ago", "3 hours ago")
  /// 
  /// More detailed version with pluralization
  /// Examples:
  /// - "Just now" for < 1 minute
  /// - "5 minutes ago" for minutes
  /// - "2 hours ago" for hours
  /// - "3 days ago" for days
  static String formatTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 0) {
      return '${difference.inDays} ${difference.inDays == 1 ? 'day' : 'days'} ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} ${difference.inHours == 1 ? 'hour' : 'hours'} ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} ${difference.inMinutes == 1 ? 'minute' : 'minutes'} ago';
    } else {
      return 'Just now';
    }
  }

  /// Formats a date as "time ago" string (short version, e.g., "2d ago", "3h ago")
  /// 
  /// Compact version without pluralization
  /// Examples:
  /// - "Just now" for < 1 minute
  /// - "5m ago" for minutes
  /// - "2h ago" for hours
  /// - "3d ago" for days
  static String formatTimeAgoShort(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }
}

