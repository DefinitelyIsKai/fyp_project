import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../models/user/app_notification.dart';

class NotificationDetailDialog extends StatelessWidget {
  final AppNotification notification;

  const NotificationDetailDialog({
    super.key,
    required this.notification,
  });

  IconData _iconFor(NotificationCategory category) {
    switch (category) {
      case NotificationCategory.message:
        return Icons.chat_bubble_outline_rounded;
      case NotificationCategory.wallet:
        return Icons.account_balance_wallet_outlined;
      case NotificationCategory.post:
        return Icons.campaign_outlined;
      case NotificationCategory.application:
        return Icons.work_outline_rounded;
      case NotificationCategory.booking:
        return Icons.calendar_today_outlined;
      case NotificationCategory.system:
        return Icons.info_outline_rounded;
      case NotificationCategory.account_warning:
        return Icons.warning_amber_rounded;
      case NotificationCategory.account_suspension:
        return Icons.block_rounded;
      case NotificationCategory.account_unsuspension:
        return Icons.check_circle_outline_rounded;
      case NotificationCategory.post_rejection:
        return Icons.warning_amber_rounded;
      case NotificationCategory.post_approval:
        return Icons.check_circle_outline_rounded;
      case NotificationCategory.report_resolved:
        return Icons.warning_amber_rounded;
    }
  }

  Color _getIconBackgroundColor(NotificationCategory category) {
    switch (category) {
      case NotificationCategory.message:
        return const Color(0xFF00C8A0).withOpacity(0.1);
      case NotificationCategory.wallet:
        return Colors.orange.withOpacity(0.1);
      case NotificationCategory.post:
        return Colors.green.withOpacity(0.1);
      case NotificationCategory.application:
        return Colors.purple.withOpacity(0.1);
      case NotificationCategory.booking:
        return Colors.blue.withOpacity(0.1);
      case NotificationCategory.system:
        return Colors.grey.withOpacity(0.1);
      case NotificationCategory.account_warning:
        return Colors.red.withOpacity(0.1);
      case NotificationCategory.account_suspension:
        return Colors.red.withOpacity(0.15);
      case NotificationCategory.post_rejection:
        return Colors.red.withOpacity(0.15);
      case NotificationCategory.post_approval:
        return Colors.green.withOpacity(0.1);
      case NotificationCategory.account_unsuspension:
        return Colors.green.withOpacity(0.1);
      case NotificationCategory.report_resolved:
        return Colors.red.withOpacity(0.1);
    }
  }

  Color _getIconColor(NotificationCategory category) {
    switch (category) {
      case NotificationCategory.message:
        return const Color(0xFF00C8A0);
      case NotificationCategory.wallet:
        return Colors.orange;
      case NotificationCategory.post:
        return Colors.green;
      case NotificationCategory.application:
        return Colors.purple;
      case NotificationCategory.booking:
        return Colors.blue;
      case NotificationCategory.system:
        return Colors.grey;
      case NotificationCategory.account_warning:
        return Colors.red;
      case NotificationCategory.account_suspension:
        return Colors.red[800]!;
      case NotificationCategory.post_rejection:
        return Colors.red[800]!;
      case NotificationCategory.post_approval:
        return Colors.green;
      case NotificationCategory.account_unsuspension:
        return Colors.green;
      case NotificationCategory.report_resolved:
        return Colors.red[800]!;
    }
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final diff = now.difference(timestamp);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return DateFormat('MMM d, yyyy h:mm a').format(timestamp);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with icon and close button
            Row(
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: _getIconBackgroundColor(notification.category),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: _getIconColor(notification.category).withOpacity(0.2),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Icon(
                    _iconFor(notification.category),
                    color: _getIconColor(notification.category),
                    size: 32,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        notification.title,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.access_time,
                              size: 14,
                              color: Colors.grey[600],
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _formatTimestamp(notification.createdAt),
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[700],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.close,
                      size: 20,
                      color: Colors.black54,
                    ),
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Divider(height: 1, thickness: 1, color: Colors.grey[200]),
            const SizedBox(height: 20),
            // Full notification body
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: Text(
                notification.body,
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.grey[800],
                  height: 1.6,
                  letterSpacing: 0.2,
                ),
              ),
            ),
            // Metadata section (if available)
            if (notification.metadata.isNotEmpty) ...[
              const SizedBox(height: 20),
              Text(
                'Additional Details',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[200]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: notification.metadata.entries.map((entry) {
                    final isLast = notification.metadata.entries.last == entry;
                    return Container(
                      padding: EdgeInsets.only(bottom: isLast ? 0 : 12),
                      margin: EdgeInsets.only(bottom: isLast ? 0 : 12),
                      decoration: BoxDecoration(
                        border: isLast
                            ? null
                            : Border(
                                bottom: BorderSide(
                                  color: Colors.grey[200]!,
                                  width: 1,
                                ),
                              ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF00C8A0).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              entry.key,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF00C8A0),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              entry.value.toString(),
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[800],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
            const SizedBox(height: 24),
            // Close button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00C8A0),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  'Close',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

