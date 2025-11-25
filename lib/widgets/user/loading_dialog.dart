import 'package:flutter/material.dart';

/// Reusable loading dialog widget
/// 
/// Provides consistent loading dialog UI
class LoadingDialog extends StatelessWidget {
  final String? message;
  final Color? color;

  const LoadingDialog({
    super.key,
    this.message,
    this.color,
  });

  /// Shows a loading dialog
  static void show({
    required BuildContext context,
    String? message,
    bool barrierDismissible = false,
  }) {
    showDialog(
      context: context,
      barrierDismissible: barrierDismissible,
      builder: (context) => LoadingDialog(message: message),
    );
  }

  /// Closes the loading dialog if it's open
  static void hide(BuildContext context) {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(
              color: color ?? const Color(0xFF00C8A0),
            ),
            if (message != null) ...[
              const SizedBox(height: 16),
              Text(
                message!,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Colors.black87,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

