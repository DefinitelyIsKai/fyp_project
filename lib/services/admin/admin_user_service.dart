import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fyp_project/services/admin/auth_service.dart';
import 'package:fyp_project/services/admin/role_service.dart';
import 'package:fyp_project/models/admin/add_admin_form_model.dart';

class AdminUserService {
  final RoleService _roleService = RoleService();

  /// Validate admin form data
  Map<String, String?> validateForm(AddAdminFormModel form) {
    final errors = <String, String?>{};

    if (form.name.trim().isEmpty) {
      errors['name'] = 'Please enter a name';
    }

    if (form.email.trim().isEmpty || !form.email.contains('@')) {
      errors['email'] = 'Please enter a valid email address';
    }

    if (form.password.isEmpty || form.password.length < 6) {
      errors['password'] = 'Password must be at least 6 characters';
    }

    if (form.password != form.confirmPassword) {
      errors['confirmPassword'] = 'Passwords do not match';
    }

    // Age validation (18-80)
    if (form.age != null) {
      if (form.age! < 18 || form.age! > 80) {
        errors['age'] = 'Age must be between 18 and 80';
      }
    }

    // Phone number validation (XXX-XXX XXXX format)
    if (form.phoneNumber != null && form.phoneNumber!.isNotEmpty) {
      final digitsOnly = form.phoneNumber!.replaceAll(RegExp(r'[^\d]'), '');
      if (digitsOnly.length != 10) {
        errors['phoneNumber'] = 'Phone number must be 10 digits (XXX-XXX XXXX)';
      }
    }

    return errors;
  }

  /// Validate role exists and has permissions
  Future<String?> validateRole(String role) async {
    try {
      final roleModel = await _roleService.getRoleByName(role.toLowerCase());
      if (roleModel == null) {
        return 'Role "$role" not found. Please select a valid role.';
      }
      
      if (roleModel.permissions.isEmpty) {
        return 'Role "$role" has no permissions assigned. Please assign permissions to this role first.';
      }
      
      return null; // No error
    } catch (e) {
      return 'Error validating role: $e';
    }
  }

  /// Create admin user
  Future<CreateAdminResult> createAdminUser(
    BuildContext context,
    AddAdminFormModel form,
  ) async {
    try {
      final authService = Provider.of<AuthService>(context, listen: false);

      // Show loading indicator using rootNavigator to ensure it's above all dialogs
      showDialog(
        context: context,
        barrierDismissible: false,
        useRootNavigator: true,
        builder: (dialogContext) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      try {
        final result = await authService.register(
          form.name,
          form.email,
          form.password,
          role: form.role,
          originalUserPassword: form.currentPassword?.isEmpty == true ? null : form.currentPassword,
          location: form.location?.isEmpty == true ? null : form.location,
          age: form.age,
          phoneNumber: form.phoneNumber?.isEmpty == true ? null : form.phoneNumber,
          gender: form.gender?.isEmpty == true ? null : form.gender,
          imageBase64: form.imageBase64,
          imageFileType: form.imageFileType,
        );

        // Always close loading dialog first - use rootNavigator to ensure we close the right dialog
        if (context.mounted) {
          Navigator.of(context, rootNavigator: true).pop();
        }

        if (result.success) {
          // Success - user is still logged in
          return CreateAdminResult(
            success: true,
            message: result.message ?? 'Admin user "${form.name}" created successfully',
          );
        } else {
          // Failed - check if it's a password error
          final errorMessage = result.error ?? 'Failed to create admin user.';
          final isPasswordError = errorMessage.toLowerCase().contains('password') || 
                                  errorMessage.toLowerCase().contains('incorrect');
          
          // If password is wrong and user provided a password, sign them out
          if (isPasswordError && form.currentPassword != null && form.currentPassword!.isNotEmpty) {
            try {
              await authService.logout();
              debugPrint('Signed out user due to incorrect password');
            } catch (e) {
              debugPrint('Error signing out after password failure: $e');
            }
          }
          
          return CreateAdminResult(
            success: false,
            error: errorMessage,
            requiresReauth: isPasswordError && form.currentPassword != null && form.currentPassword!.isNotEmpty,
          );
        }
      } catch (e) {
        // Close loading dialog on error
        if (context.mounted) {
          try {
            Navigator.of(context, rootNavigator: true).pop();
          } catch (_) {
            // Dialog might already be closed, ignore
          }
        }
        rethrow;
      }
    } catch (e) {
      // Ensure loading dialog is closed even if there's an exception
      if (context.mounted) {
        try {
          Navigator.of(context, rootNavigator: true).pop();
        } catch (_) {
          // Dialog might already be closed, ignore
        }
      }
      return CreateAdminResult(
        success: false,
        error: 'Error creating admin user: $e',
      );
    }
  }
}

class CreateAdminResult {
  final bool success;
  final String? message;
  final String? error;
  final bool requiresReauth;

  CreateAdminResult({
    required this.success,
    this.message,
    this.error,
    this.requiresReauth = false,
  });
}

