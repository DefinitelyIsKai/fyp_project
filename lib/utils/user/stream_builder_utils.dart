import 'package:flutter/material.dart';

/// Utility functions for common StreamBuilder patterns
/// 
/// Provides helper functions to reduce boilerplate when using StreamBuilder
class StreamBuilderUtils {
  /// Builds a loading indicator for StreamBuilder waiting state
  static Widget buildLoading({
    Color? color,
    EdgeInsets? padding,
  }) {
    return Center(
      child: Padding(
        padding: padding ?? const EdgeInsets.all(32.0),
        child: CircularProgressIndicator(
          color: color ?? const Color(0xFF00C8A0),
        ),
      ),
    );
  }

  /// Builds an error widget for StreamBuilder error state
  static Widget buildError({
    required String title,
    String? message,
    IconData? icon,
    Color? iconColor,
    Widget? action,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon ?? Icons.error_outline,
              size: 64,
              color: iconColor ?? Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.black,
                fontSize: 18,
              ),
            ),
            if (message != null) ...[
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[600], fontSize: 14),
              ),
            ],
            if (action != null) ...[
              const SizedBox(height: 20),
              action,
            ],
          ],
        ),
      ),
    );
  }

  /// Builds an empty state widget for StreamBuilder empty data
  static Widget buildEmpty({
    required IconData icon,
    required String title,
    String? subtitle,
    Color? iconColor,
    double? iconSize,
    Widget? action,
  }) {
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
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 8),
              Text(
                subtitle,
                style: TextStyle(color: Colors.grey[500], fontSize: 14),
              ),
            ],
            if (action != null) ...[
              const SizedBox(height: 24),
              action,
            ],
          ],
        ),
      ),
    );
  }
}

