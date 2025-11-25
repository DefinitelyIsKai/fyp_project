import 'package:flutter/material.dart';

/// Utility class for showing loading dialogs
/// 
/// Provides consistent loading dialog UI across the application
class LoadingDialogUtils {
  /// Shows a loading dialog with optional message
  /// 
  /// Returns the dialog context so it can be closed with Navigator.pop(context)
  static BuildContext showLoadingDialog({
    required BuildContext context,
    String? message,
    bool barrierDismissible = false,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: barrierDismissible,
      builder: (context) => _LoadingDialog(message: message),
    ) as BuildContext;
  }

  /// Shows a loading dialog and returns a function to close it
  static void Function() showLoadingDialogWithCloser({
    required BuildContext context,
    String? message,
    bool barrierDismissible = false,
  }) {
    showDialog(
      context: context,
      barrierDismissible: barrierDismissible,
      builder: (context) => _LoadingDialog(message: message),
    );
    
    return () {
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
    };
  }
}

/// Internal loading dialog widget
class _LoadingDialog extends StatelessWidget {
  final String? message;

  const _LoadingDialog({this.message});

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
            const CircularProgressIndicator(
              color: Color(0xFF00C8A0),
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

