import 'package:flutter/material.dart';

/// A reusable confirmation dialog widget that can be customized
/// for various confirmation scenarios throughout the app.
class ConfirmationDialog extends StatelessWidget {
  /// The title of the dialog
  final String title;

  /// The message/description shown in the dialog
  final String message;

  /// The icon to display (optional)
  final IconData? icon;

  /// The color for the icon background (optional, defaults to red with opacity)
  final Color? iconColor;

  /// The background color for the icon container (optional)
  final Color? iconBackgroundColor;

  /// The text for the confirm button
  final String confirmText;

  /// The text for the cancel button
  final String cancelText;

  /// The color for the confirm button
  final Color confirmButtonColor;

  /// The color for the cancel button text/border
  final Color? cancelButtonColor;

  /// Whether the confirm button should be destructive (red) or normal
  final bool isDestructive;

  const ConfirmationDialog({
    super.key,
    required this.title,
    required this.message,
    this.icon,
    this.iconColor,
    this.iconBackgroundColor,
    this.confirmText = 'Confirm',
    this.cancelText = 'Cancel',
    this.confirmButtonColor = const Color(0xFF00C8A0),
    this.cancelButtonColor,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    // Determine icon color based on isDestructive or provided color
    final effectiveIconColor = iconColor ?? (isDestructive ? Colors.red : const Color(0xFF00C8A0));
    final effectiveIconBackgroundColor = iconBackgroundColor ?? 
        (isDestructive ? Colors.red.withOpacity(0.1) : const Color(0xFF00C8A0).withOpacity(0.1));
    
    // Determine confirm button color
    final effectiveConfirmColor = isDestructive ? Colors.red : confirmButtonColor;
    
    // Determine cancel button color
    final effectiveCancelColor = cancelButtonColor ?? Colors.grey;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: effectiveIconBackgroundColor,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  size: 30,
                  color: effectiveIconColor,
                ),
              ),
              const SizedBox(height: 16),
            ],
            Text(
              title,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.grey,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: effectiveCancelColor,
                      side: BorderSide(color: effectiveCancelColor),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(cancelText),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: effectiveConfirmColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(confirmText),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

