import 'package:flutter/material.dart';
import 'package:fyp_project/models/admin/user_model.dart';
import 'package:fyp_project/services/admin/user_service.dart';

/// Dialog for suspending user accounts
class SuspendDialog {
  /// Shows the suspend dialog as a bottom sheet
  static Future<void> show({
    required BuildContext context,
    required UserModel user,
    required UserService userService,
    required Function(String, {bool isError}) onShowSnackBar,
    required VoidCallback onLoadData,
  }) async {
    final reasonController = TextEditingController();
    final durationController = TextEditingController(text: '30'); // Default 30 days

    bool isLoading = false;
    String? reasonError;
    String? durationError;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: true,
      enableDrag: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.85,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red[700],
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: isLoading ? null : () => Navigator.pop(context),
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Suspend User Account',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Content
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'You are about to suspend ${user.fullName}\'s account immediately.',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red[50],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.red[200]!),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.warning_amber, color: Colors.red[700], size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'This will suspend the user immediately without waiting for 3 warnings.',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.red[700],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'Suspension Reason *',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: reasonController,
                        maxLines: 3,
                        enabled: !isLoading,
                        onChanged: (value) {
                          if (reasonError != null) {
                            setDialogState(() => reasonError = null);
                          }
                        },
                        decoration: InputDecoration(
                          hintText: 'Explain why this account is being suspended...',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: reasonError != null ? Colors.red : Colors.grey[300]!,
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: reasonError != null ? Colors.red : Colors.grey[300]!,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: reasonError != null ? Colors.red : Colors.red[700]!,
                              width: 2,
                            ),
                          ),
                          errorBorder: const OutlineInputBorder(
                            borderSide: BorderSide(color: Colors.red, width: 2),
                          ),
                          focusedErrorBorder: const OutlineInputBorder(
                            borderSide: BorderSide(color: Colors.red, width: 2),
                          ),
                          errorText: reasonError,
                          contentPadding: const EdgeInsets.all(16),
                          prefixIcon: Icon(
                            Icons.description_outlined,
                            color: reasonError != null ? Colors.red : Colors.grey[600],
                          ),
                          fillColor: reasonError != null ? Colors.red[50] : Colors.grey[50],
                          filled: true,
                        ),
                        textInputAction: TextInputAction.done,
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'Suspension Duration (Days) *',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: durationController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: false),
                        enabled: !isLoading,
                        onChanged: (value) {
                          if (durationError != null) {
                            setDialogState(() => durationError = null);
                          }
                        },
                        decoration: InputDecoration(
                          hintText: 'Enter number of days (e.g., 30)',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: durationError != null ? Colors.red : Colors.grey[300]!,
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: durationError != null ? Colors.red : Colors.grey[300]!,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: durationError != null ? Colors.red : Colors.red[700]!,
                              width: 2,
                            ),
                          ),
                          errorBorder: const OutlineInputBorder(
                            borderSide: BorderSide(color: Colors.red, width: 2),
                          ),
                          focusedErrorBorder: const OutlineInputBorder(
                            borderSide: BorderSide(color: Colors.red, width: 2),
                          ),
                          errorText: durationError,
                          contentPadding: const EdgeInsets.all(16),
                          prefixIcon: Icon(
                            Icons.calendar_today,
                            size: 20,
                            color: durationError != null ? Colors.red : Colors.grey[600],
                          ),
                          fillColor: durationError != null ? Colors.red[50] : Colors.grey[50],
                          filled: true,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Enter a number greater than 0',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                      if (isLoading) ...[
                        const SizedBox(height: 24),
                        const Center(
                          child: Column(
                            children: [
                              CircularProgressIndicator(),
                              SizedBox(height: 12),
                              Text(
                                'Suspending user...',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 24),
                      // Action Buttons
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: isLoading ? null : () => Navigator.pop(context),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                side: BorderSide(color: Colors.grey[300]!),
                              ),
                              child: const Text(
                                'Cancel',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 2,
                            child: ElevatedButton(
                              onPressed: isLoading
                                  ? null
                                  : () async {
                                      final suspensionReason = reasonController.text.trim();
                                      final durationText = durationController.text.trim();

                                      // Reset errors
                                      reasonError = null;
                                      durationError = null;

                                      // Validate reason
                                      if (suspensionReason.isEmpty) {
                                        setDialogState(() {
                                          reasonError = 'Please provide a suspension reason';
                                        });
                                        return;
                                      }

                                      // Validate duration - cannot be empty
                                      if (durationText.isEmpty) {
                                        setDialogState(() {
                                          durationError = 'Please enter suspension duration';
                                        });
                                        return;
                                      }

                                      int? durationDays = int.tryParse(durationText);
                                      if (durationDays == null || durationDays <= 0) {
                                        setDialogState(() {
                                          durationError = 'Must be greater than 0';
                                        });
                                        return;
                                      }

                                      isLoading = true;
                                      setDialogState(() {});

                                      try {
                                        await userService.suspendUser(
                                          user.id,
                                          violationReason: suspensionReason,
                                          durationDays: durationDays,
                                        );

                                        if (context.mounted) {
                                          Navigator.pop(context);

                                          onShowSnackBar(
                                            '${user.fullName}\'s account has been suspended for $durationDays day${durationDays == 1 ? '' : 's'}',
                                          );

                                          onLoadData();
                                        }
                                      } catch (e) {
                                        if (context.mounted) {
                                          Navigator.pop(context);
                                          onShowSnackBar('Failed to suspend user: $e', isError: true);
                                        }
                                      }
                                    },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red[700],
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 0,
                              ),
                              child: isLoading
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                      ),
                                    )
                                  : const Text(
                                      'Suspend Account',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
