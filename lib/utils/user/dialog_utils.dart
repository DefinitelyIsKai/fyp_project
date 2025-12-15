import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
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
      
      if (context.mounted) {
        Navigator.of(context).pushReplacementNamed(AppRoutes.userLogin);
      }

      Future.delayed(const Duration(milliseconds: 100), () async {
        try {
          await service.signOut();
        } catch (e) {
          debugPrint('Error during signOut (non-critical): $e');
        }
      });
    }
  }
}

