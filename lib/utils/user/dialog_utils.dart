import 'package:flutter/material.dart';
import '../../widgets/user/confirmation_dialog.dart';
import '../../widgets/user/message_box.dart';
import '../../services/user/auth_service.dart';
import '../../routes/app_routes.dart';


class DialogUtils {
 
  static Future<bool?> showConfirmationDialog({
    required BuildContext context,
    required String title,
    required String message,
    IconData? icon,
    Color? iconColor,
    Color? iconBackgroundColor,
    String confirmText = 'Confirm',
    String cancelText = 'Cancel',
    Color confirmButtonColor = const Color(0xFF00C8A0),
    Color? cancelButtonColor,
    bool isDestructive = false,
  }) async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => ConfirmationDialog(
        title: title,
        message: message,
        icon: icon,
        iconColor: iconColor,
        iconBackgroundColor: iconBackgroundColor,
        confirmText: confirmText,
        cancelText: cancelText,
        confirmButtonColor: confirmButtonColor,
        cancelButtonColor: cancelButtonColor,
        isDestructive: isDestructive,
      ),
    );
  }

  /// Shows a simple confirmation dialog with default styling
  /// Useful for quick confirmations without custom icons
  static Future<bool?> showSimpleConfirmation({
    required BuildContext context,
    required String title,
    required String message,
    String confirmText = 'Confirm',
    String cancelText = 'Cancel',
  }) async {
    return await showConfirmationDialog(
      context: context,
      title: title,
      message: message,
      confirmText: confirmText,
      cancelText: cancelText,
    );
  }

  /// Shows a destructive confirmation dialog (e.g., delete, logout)
  /// Automatically uses red styling
  static Future<bool?> showDestructiveConfirmation({
    required BuildContext context,
    required String title,
    required String message,
    IconData? icon,
    String confirmText = 'Delete',
    String cancelText = 'Cancel',
  }) async {
    return await showConfirmationDialog(
      context: context,
      title: title,
      message: message,
      icon: icon ?? Icons.warning,
      confirmText: confirmText,
      cancelText: cancelText,
      isDestructive: true,
    );
  }

  /// Shows a success message box (green/teal color)
  /// Displays at the top of the screen and auto-dismisses after 3 seconds
  static void showSuccessMessage({
    required BuildContext context,
    required String message,
    Duration duration = const Duration(seconds: 3),
  }) {
    MessageBox.show(
      context: context,
      message: message,
      type: MessageBoxType.success,
      duration: duration,
    );
  }

  /// Shows a warning message box (red color)
  /// Displays at the top of the screen and auto-dismisses after 3 seconds
  static void showWarningMessage({
    required BuildContext context,
    required String message,
    Duration duration = const Duration(seconds: 3),
  }) {
    MessageBox.show(
      context: context,
      message: message,
      type: MessageBoxType.warning,
      duration: duration,
    );
  }

  /// Shows an info message box (blue color)
  /// Displays at the top of the screen and auto-dismisses after 3 seconds
  static void showInfoMessage({
    required BuildContext context,
    required String message,
    Duration duration = const Duration(seconds: 3),
  }) {
    MessageBox.show(
      context: context,
      message: message,
      type: MessageBoxType.info,
      duration: duration,
    );
  }

  /// Shows logout confirmation dialog and handles the logout flow
  /// This is a unified method that can be used across all user pages
  static Future<void> showLogoutConfirmation({
    required BuildContext context,
    AuthService? authService,
  }) async {
    final confirmed = await showDestructiveConfirmation(
      context: context,
      title: 'Logout?',
      message: 'Are you sure you want to logout?',
      icon: Icons.logout,
      confirmText: 'Logout',
      cancelText: 'Cancel',
    );

    if (confirmed == true && context.mounted) {
      final service = authService ?? AuthService();
      
      // Navigate away first to stop all streams and listeners
      // This prevents Firestore permission errors during logout
      if (context.mounted) {
        Navigator.of(context).pushReplacementNamed(AppRoutes.userLogin);
      }
      
      // Then sign out after navigation (in background)
      // This prevents any active streams from trying to access Firestore after logout
      Future.microtask(() async {
        try {
          await service.signOut();
        } catch (e) {
          // Ignore errors during logout - user is already navigated away
          debugPrint('Error during signOut (non-critical): $e');
        }
      });
    }
  }
}

