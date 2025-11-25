import 'package:flutter/material.dart';

/// Reusable error state widget
/// 
/// Provides consistent error handling UI across the application
class ErrorState extends StatelessWidget {
  final String title;
  final String? message;
  final IconData? icon;
  final Color? iconColor;
  final Widget? action;
  final EdgeInsets? padding;

  const ErrorState({
    super.key,
    required this.title,
    this.message,
    this.icon,
    this.iconColor,
    this.action,
    this.padding,
  });

  /// Standard error state for loading failures
  const ErrorState.standard({
    super.key,
    required String title,
    String? message,
    this.action,
    this.padding,
  }) : title = title,
       icon = Icons.error_outline,
       iconColor = const Color(0xFF00C8A0),
       message = message;

  /// Error state for profile loading
  const ErrorState.profile({
    super.key,
    required String error,
    this.action,
  }) : title = 'Unable to Load Profile',
       message = error,
       icon = Icons.error_outline,
       iconColor = Colors.grey,
       padding = const EdgeInsets.all(24.0);

  /// Error state for posts loading
  const ErrorState.posts({
    super.key,
    required String error,
    this.action,
  }) : title = 'Could not load your posts',
       message = error,
       icon = Icons.error_outline,
       iconColor = const Color(0xFF00C8A0),
       padding = const EdgeInsets.all(24.0);

  /// Error state for search/discovery
  const ErrorState.search({
    super.key,
    this.action,
  }) : title = 'Unable to load posts',
       message = 'Please try again later',
       icon = Icons.error_outline,
       iconColor = Colors.grey,
       padding = const EdgeInsets.all(24.0);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: padding ?? const EdgeInsets.all(24.0),
        padding: const EdgeInsets.all(32.0),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.grey[100],
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon ?? Icons.error_outline,
                size: 40,
                color: iconColor ?? Colors.grey[400],
              ),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Colors.black,
              ),
              textAlign: TextAlign.center,
            ),
            if (message != null) ...[
              const SizedBox(height: 8),
              Text(
                message!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 14,
                ),
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

