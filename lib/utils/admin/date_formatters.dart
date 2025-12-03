import 'package:intl/intl.dart';

class DateFormatters {
  
  static String formatDate(DateTime date) {
    return DateFormat('dd/MM/yyyy').format(date);
  }

  static String formatDateLong(DateTime date) {
    return DateFormat('MMM dd, yyyy').format(date);
  }

  static String formatDateTime(DateTime date) {
    return DateFormat('MMM dd, yyyy • hh:mm a').format(date);
  }

  static String formatDateTimeWithDash(DateTime date) {
    return DateFormat('MMM dd, yyyy - HH:mm').format(date);
  }

  static String formatDateTimeDetailed(DateTime date) {
    return DateFormat('dd MMM yyyy, hh:mm a').format(date);
  }

  static String formatDateTimeDetailed24(DateTime date) {
    return DateFormat('dd MMM yyyy, HH:mm').format(date);
  }

  static String formatDateShort(DateTime date) {
    return DateFormat('MMM dd').format(date);
  }

  static String formatDateMedium(DateTime date) {
    return DateFormat('dd MMM yyyy').format(date);
  }

  static String formatTimeAgo(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 365) {
      final years = (difference.inDays / 365).floor();
      return '$years ${years == 1 ? 'year' : 'years'} ago';
    } else if (difference.inDays > 30) {
      final months = (difference.inDays / 30).floor();
      return '$months ${months == 1 ? 'month' : 'months'} ago';
    } else if (difference.inDays > 0) {
      return '${difference.inDays} ${difference.inDays == 1 ? 'day' : 'days'} ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} ${difference.inHours == 1 ? 'hour' : 'hours'} ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} ${difference.inMinutes == 1 ? 'minute' : 'minutes'} ago';
    } else {
      return 'Just now';
    }
  }

  static String getDateRangeText(DateTime startDate, DateTime endDate) {
    final daysDiff = endDate.difference(startDate).inDays;
    if (daysDiff == 0) {
      return 'Today (${formatDate(startDate)})';
    }
    if (daysDiff == 29 && endDate.day == DateTime.now().day) {
      return 'Last 30 days';
    }
    return '${formatDate(startDate)} - ${formatDate(endDate)}';
  }
}
