import 'package:flutter/material.dart';

/// Reusable empty state widget
/// 
/// Provides consistent empty state UI across the application
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Color? iconColor;
  final double? iconSize;
  final Widget? action;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.iconColor,
    this.iconSize,
    this.action,
  });

  /// Empty state for no items in a list
  const EmptyState.noItems({
    super.key,
    String? title,
    String? subtitle,
    this.action,
  }) : icon = Icons.inbox_outlined,
       title = title ?? 'No items yet',
       subtitle = subtitle ?? 'Your items will appear here',
       iconColor = Colors.grey,
       iconSize = 64.0;

  /// Empty state for no posts
  const EmptyState.noPosts({
    super.key,
    String? subtitle,
    this.action,
  }) : icon = Icons.post_add,
       title = 'No posts yet',
       subtitle = subtitle ?? 'Tap the + button to create a new post',
       iconColor = Colors.grey,
       iconSize = 80.0;

  /// Empty state for no conversations
  const EmptyState.noConversations({
    super.key,
    this.action,
  }) : icon = Icons.chat_bubble_outline_rounded,
       title = 'No Conversations',
       subtitle = 'Your conversations will appear here',
       iconColor = Colors.grey,
       iconSize = 80.0;

  /// Empty state for no matches/applications
  const EmptyState.noMatches({
    super.key,
    required bool isRecruiter,
    this.action,
  }) : icon = Icons.work_outline,
       title = isRecruiter ? 'No applications yet' : 'No matches found',
       subtitle = isRecruiter 
           ? 'Applications will appear here'
           : 'New job matches will appear here',
       iconColor = Colors.grey,
       iconSize = 80.0;

  /// Empty state for no transactions
  const EmptyState.noTransactions({
    super.key,
    this.action,
  }) : icon = Icons.receipt_long,
       title = 'No transactions yet',
       subtitle = 'Your transaction history will appear here',
       iconColor = Colors.grey,
       iconSize = 64.0;

  /// Empty state for no locations
  const EmptyState.noLocations({
    super.key,
    this.action,
  }) : icon = Icons.map_outlined,
       title = 'No locations found',
       subtitle = 'Try adjusting your search filters',
       iconColor = Colors.grey,
       iconSize = 64.0;

  /// Empty state for no applicants
  const EmptyState.noApplicants({
    super.key,
    this.action,
  }) : icon = Icons.people_outline,
       title = 'No applicants yet',
       subtitle = null,
       iconColor = Colors.grey,
       iconSize = 64.0;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: iconSize ?? 64.0,
              color: iconColor ?? Colors.grey[300],
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 8),
              Text(
                subtitle!,
                style: TextStyle(
                  color: Colors.grey[500],
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
            ],
            if (action != null) ...[
              const SizedBox(height: 24),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

