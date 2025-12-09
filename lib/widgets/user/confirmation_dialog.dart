import 'package:flutter/material.dart';

class ConfirmationDialog extends StatelessWidget {
  final String title;
  final String message;
  final IconData? icon;
  final Color? iconColor;
  final Color? iconBackgroundColor;
  final String confirmText;
  final String cancelText;
  final Color confirmButtonColor;
  final Color? cancelButtonColor;
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
    final effectiveIconColor = iconColor ?? (isDestructive ? Colors.red : const Color(0xFF00C8A0));
    final effectiveIconBackgroundColor = iconBackgroundColor ?? 
        (isDestructive ? Colors.red.withOpacity(0.1) : const Color(0xFF00C8A0).withOpacity(0.1));
    
 
    final effectiveConfirmColor = isDestructive ? Colors.red : confirmButtonColor;
    

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

