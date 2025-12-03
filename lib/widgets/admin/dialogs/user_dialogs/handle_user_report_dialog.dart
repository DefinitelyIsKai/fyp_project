import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fyp_project/models/admin/report_category_model.dart';
import 'package:fyp_project/services/admin/user_service.dart';

class HandleUserReportDialog {
  static Future<Map<String, dynamic>?> show({
    required BuildContext context,
    required String userId,
    required String userName,
    required int currentStrikes,
    required double walletBalance,
    required double availableBalance,
    required double heldCredits,
    required double? deductAmount,
    required ReportCategoryModel? matchedCategory,
    required String reportId,
    required String reportReason,
  }) async {
    final violationController = TextEditingController();
    final durationController = TextEditingController(text: '30');
    final customDeductController = TextEditingController();
    
    bool isLoading = false;
    String? reasonError;
    String? durationError;
    String? customDeductError;
    String selectedAction = 'warning';
    
    final isCustomReason = matchedCategory == null;
    double? finalDeductAmount = deductAmount;
    double? confirmedCustomAmount; 
    bool isCustomAmountConfirmed = false;

    return await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: !isLoading,
      enableDrag: !isLoading,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.9,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.orange[700],
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
                        'Handle User Report',
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
              Flexible(
                child: SingleChildScrollView(
                  padding: EdgeInsets.only(
                    left: 24,
                    right: 24,
                    top: 24,
                    bottom: MediaQuery.of(context).viewInsets.bottom + 24,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'The following actions will be taken against the reported user.',
                        style: TextStyle(
                          fontSize: 15,
                          color: Colors.grey[800],
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.orange[50],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.orange[200]!),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.warning_amber_rounded, color: Colors.orange[700], size: 24),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Warning will be issued',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.black87,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Current strikes: $currentStrikes/3',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.orange[900],
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    (3 - currentStrikes) > 0 
                                        ? '${3 - currentStrikes} more strike${(3 - currentStrikes) == 1 ? '' : 's'} until automatic suspension'
                                        : 'Account will be suspended automatically',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.orange[800],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      Builder(
                        builder: (context) {
                          final currentCanDeduct = finalDeductAmount != null && finalDeductAmount! > 0 && availableBalance >= finalDeductAmount!;
                          final currentNeedsAlternative = (finalDeductAmount != null && finalDeductAmount! > 0 && !currentCanDeduct) ||
                              (isCustomReason && availableBalance == 0 && (finalDeductAmount == null || finalDeductAmount == 0));
                          
                          if (currentNeedsAlternative) {
                            return Column(
                              children: [
                                const SizedBox(height: 12),
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Colors.red[50],
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: Colors.red[200]!),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Icon(Icons.error_outline, color: Colors.red[700], size: 24),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  'Insufficient Balance',
                                                  style: TextStyle(
                                                    fontSize: 15,
                                                    fontWeight: FontWeight.w600,
                                                    color: Colors.black87,
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  isCustomReason && availableBalance == 0 && (finalDeductAmount == null || finalDeductAmount == 0)
                                                      ? 'Custom Reason: No credit deduction specified and balance is 0'
                                                      : 'Category: ${matchedCategory?.name ?? 'N/A'}',
                                                  style: TextStyle(
                                                    fontSize: 13,
                                                    color: Colors.red[900],
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                                if (!(isCustomReason && availableBalance == 0 && (finalDeductAmount == null || finalDeductAmount == 0))) ...[
                                                  const SizedBox(height: 2),
                                                  Text(
                                                    'Required: ${deductAmount?.toInt() ?? 0} credits',
                                                    style: TextStyle(
                                                      fontSize: 14,
                                                      color: Colors.red[900],
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                  ),
                                                ],
                                                const SizedBox(height: 2),
                                                Text(
                                                  'Available: ${availableBalance.toStringAsFixed(0)} credits (Total: ${walletBalance.toStringAsFixed(0)}, Held: ${heldCredits.toStringAsFixed(0)})',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: Colors.red[800],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      const Divider(),
                                      const SizedBox(height: 12),
                                      const Text(
                                        'Alternative Action:',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.black87,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      RadioListTile<String>(
                                        title: const Text('Warning Only'),
                                        subtitle: const Text('Issue a warning without suspension (credit deduction will be skipped)'),
                                        value: 'warning',
                                        groupValue: selectedAction,
                                        onChanged: isLoading ? null : (value) {
                                          if (value != null) {
                                            setDialogState(() {
                                              selectedAction = value;
                                            });
                                          }
                                        },
                                        contentPadding: EdgeInsets.zero,
                                      ),
                                      RadioListTile<String>(
                                        title: const Text('Suspend User'),
                                        subtitle: const Text('Suspend the user account for a specified duration'),
                                        value: 'suspend',
                                        groupValue: selectedAction,
                                        onChanged: isLoading ? null : (value) {
                                          if (value != null) {
                                            setDialogState(() {
                                              selectedAction = value;
                                            });
                                          }
                                        },
                                        contentPadding: EdgeInsets.zero,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            );
                          }
                          return const SizedBox.shrink();
                        },
                      ),
                      
                      Builder(
                        builder: (context) {
                          final currentCanDeduct = finalDeductAmount != null && finalDeductAmount! > 0 && availableBalance >= finalDeductAmount!;
                          final currentNeedsAlternative = (finalDeductAmount != null && finalDeductAmount! > 0 && !currentCanDeduct) ||
                              (isCustomReason && availableBalance == 0 && (finalDeductAmount == null || finalDeductAmount == 0));
                          
                          if (currentNeedsAlternative) {
                            return const SizedBox.shrink();
                          } else if (finalDeductAmount != null && finalDeductAmount! > 0 && currentCanDeduct && !isCustomReason) {
                            return Column(
                              children: [
                                const SizedBox(height: 12),
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Colors.red[50],
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: Colors.red[200]!),
                                  ),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Icon(Icons.account_balance_wallet, color: Colors.red[700], size: 24),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Credits will be deducted',
                                              style: TextStyle(
                                                fontSize: 15,
                                                fontWeight: FontWeight.w600,
                                                color: Colors.black87,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              'Category: ${matchedCategory.name}',
                                              style: TextStyle(
                                                fontSize: 13,
                                                color: Colors.red[900],
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              'Amount: ${finalDeductAmount!.toInt()} credits',
                                              style: TextStyle(
                                                fontSize: 14,
                                                color: Colors.red[900],
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              'Available balance: ${availableBalance.toStringAsFixed(0)} credits',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.red[800],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            );
                          } else {
                            return Column(
                              children: [
                                const SizedBox(height: 12),
                                Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.blue[50],
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.blue[200]!),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(Icons.info_outline, color: Colors.blue[700], size: 20),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Wallet Balance Information',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.blue[900],
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Total: ${walletBalance.toStringAsFixed(0)} credits',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: Colors.blue[800],
                                      ),
                                    ),
                                    Text(
                                      'Held: ${heldCredits.toStringAsFixed(0)} credits',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: Colors.blue[800],
                                      ),
                                    ),
                                    Text(
                                      'Available: ${availableBalance.toStringAsFixed(0)} credits',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: Colors.blue[900],
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                                ),
                                if (isCustomReason) ...[
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.amber[50],
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.amber[200]!),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.edit_note, color: Colors.amber[700], size: 20),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'Custom Reason: "$reportReason"',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.amber[900],
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'This is a custom reason. You can set a custom credit deduction amount.',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.amber[800],
                                  ),
                                ),
                                const SizedBox(height: 12),
                                const Text(
                                  'Custom Credit Deduction (Optional)',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                    color: Colors.black87,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                TextField(
                                  controller: customDeductController,
                                  keyboardType: const TextInputType.numberWithOptions(decimal: false),
                                  enabled: !isLoading,
                                  onChanged: (value) {
                                    setDialogState(() {
                                      if (customDeductError != null) {
                                        customDeductError = null;
                                      }
                                      
                                      if (isCustomAmountConfirmed) {
                                        isCustomAmountConfirmed = false;
                                        confirmedCustomAmount = null;
                                      }
                                    });
                                  },
                                  decoration: InputDecoration(
                                    hintText: 'Enter amount (0 = no deduction)',
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: BorderSide(
                                        color: customDeductError != null ? Colors.red : Colors.grey,
                                      ),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: BorderSide(
                                        color: customDeductError != null ? Colors.red : Colors.grey,
                                      ),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: BorderSide(
                                        color: customDeductError != null ? Colors.red : Colors.blue,
                                        width: 2,
                                      ),
                                    ),
                                    errorText: customDeductError,
                                    prefixIcon: Icon(
                                      Icons.account_balance_wallet,
                                      color: customDeductError != null ? Colors.red : Colors.grey,
                                    ),
                                    suffixText: 'credits',
                                    fillColor: customDeductError != null ? Colors.red[50] : Colors.white,
                                    filled: true,
                                    contentPadding: const EdgeInsets.all(16),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Expanded(
                                      child: OutlinedButton(
                                        onPressed: isLoading ? null : () {
                                          final customAmountText = customDeductController.text.trim();
                                          if (customAmountText.isEmpty) {
                                            setDialogState(() {
                                              customDeductError = 'Please enter an amount first';
                                            });
                                            return;
                                          }
                                          
                                          final customAmount = double.tryParse(customAmountText);
                                          if (customAmount == null || customAmount < 0) {
                                            setDialogState(() {
                                              customDeductError = 'Please enter a valid number (0 or greater)';
                                            });
                                            return;
                                          }
                                          
                                          setDialogState(() {
                                            customDeductError = null;
                                            confirmedCustomAmount = customAmount > 0 ? customAmount : null;
                                            finalDeductAmount = confirmedCustomAmount;
                                            isCustomAmountConfirmed = true;
                                          });
                                        },
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: Colors.blue[700],
                                          side: BorderSide(color: Colors.blue[300]!),
                                          padding: const EdgeInsets.symmetric(vertical: 12),
                                        ),
                                        child: const Text('Confirm Amount'),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                if (isCustomAmountConfirmed && confirmedCustomAmount != null) ...[
                                  Builder(
                                    builder: (context) {
                                      final deduct = confirmedCustomAmount!;
                                      final isSufficient = availableBalance >= deduct;
                                      return Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: isSufficient
                                              ? Colors.green[50]
                                              : Colors.red[50],
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(
                                            color: isSufficient
                                                ? Colors.green[200]!
                                                : Colors.red[200]!,
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            Icon(
                                              isSufficient
                                                  ? Icons.check_circle
                                                  : Icons.error_outline,
                                              size: 20,
                                              color: isSufficient
                                                  ? Colors.green[700]
                                                  : Colors.red[700],
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    isSufficient
                                                        ? 'Balance Check: Sufficient'
                                                        : 'Balance Check: Insufficient',
                                                    style: TextStyle(
                                                      fontSize: 14,
                                                      color: isSufficient
                                                          ? Colors.green[900]
                                                          : Colors.red[900],
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    'Available: ${availableBalance.toStringAsFixed(0)} credits | Required: ${deduct.toStringAsFixed(0)} credits',
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      color: isSufficient
                                                          ? Colors.green[800]
                                                          : Colors.red[800],
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              ],
                            ),
                                ),
                                ] else ...[
                                  const SizedBox(height: 12),
                                  Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.grey[100],
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.grey[300]!),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.info_outline, color: Colors.grey[600], size: 18),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'No matching report category found. Only warning will be issued.',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[700],
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                                ),
                                ],
                              ],
                            );
                          }
                        },
                      ),
                      
                      Builder(
                        builder: (context) {
                          final currentCanDeduct = finalDeductAmount != null && finalDeductAmount! > 0 && availableBalance >= finalDeductAmount!;
                          final currentNeedsAlternative = (finalDeductAmount != null && finalDeductAmount! > 0 && !currentCanDeduct) ||
                              (isCustomReason && availableBalance == 0 && (finalDeductAmount == null || finalDeductAmount == 0));
                          
                          if (currentNeedsAlternative && selectedAction == 'suspend') {
                            return Column(
                              children: [
                                const SizedBox(height: 20),
                                const Text(
                                  'Suspension Duration (Days) *',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 15,
                                    color: Colors.black87,
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
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: BorderSide(
                                        color: durationError != null ? Colors.red : Colors.grey,
                                      ),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: BorderSide(
                                        color: durationError != null ? Colors.red : Colors.grey,
                                      ),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: BorderSide(
                                        color: durationError != null ? Colors.red : Colors.blue,
                                        width: 2,
                                      ),
                                    ),
                                    errorBorder: const OutlineInputBorder(
                                      borderRadius: BorderRadius.all(Radius.circular(8)),
                                      borderSide: BorderSide(color: Colors.red, width: 2),
                                    ),
                                    focusedErrorBorder: const OutlineInputBorder(
                                      borderRadius: BorderRadius.all(Radius.circular(8)),
                                      borderSide: BorderSide(color: Colors.red, width: 2),
                                    ),
                                    errorText: durationError,
                                    contentPadding: const EdgeInsets.all(16),
                                    prefixIcon: Icon(
                                      Icons.calendar_today,
                                      color: durationError != null ? Colors.red : Colors.grey,
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
                              ],
                            );
                          }
                          return const SizedBox.shrink();
                        },
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'Violation Reason *',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: violationController,
                        maxLines: 4,
                        enabled: !isLoading,
                        onChanged: (value) {
                          if (reasonError != null) {
                            setDialogState(() => reasonError = null);
                          }
                        },
                        decoration: InputDecoration(
                          hintText: 'Explain the violation (this will be sent to the user)...',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(
                              color: reasonError != null ? Colors.red : Colors.grey,
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(
                              color: reasonError != null ? Colors.red : Colors.grey,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(
                              color: reasonError != null ? Colors.red : Colors.blue,
                              width: 2,
                            ),
                          ),
                          errorBorder: const OutlineInputBorder(
                            borderRadius: BorderRadius.all(Radius.circular(8)),
                            borderSide: BorderSide(color: Colors.red, width: 2),
                          ),
                          focusedErrorBorder: const OutlineInputBorder(
                            borderRadius: BorderRadius.all(Radius.circular(8)),
                            borderSide: BorderSide(color: Colors.red, width: 2),
                          ),
                          errorText: reasonError,
                          filled: true,
                          fillColor: reasonError != null ? Colors.red[50] : Colors.grey[50],
                          contentPadding: const EdgeInsets.all(16),
                        ),
                        textInputAction: TextInputAction.done,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'The user will receive a warning notification. After 3 strikes, their account will be automatically suspended.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                      if (isLoading) ...[
                        const SizedBox(height: 20),
                        const Center(
                          child: Column(
                            children: [
                              CircularProgressIndicator(),
                              SizedBox(height: 12),
                              Text(
                                'Processing...',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  border: Border(
                    top: BorderSide(color: Colors.grey[200]!),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: isLoading ? null : () => Navigator.pop(context),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: Text(
                          'Cancel',
                          style: TextStyle(
                            color: Colors.grey[700],
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: Builder(
                        builder: (context) {
                          
                          bool shouldDisableButton = false;
                          if (isCustomReason) {
                            
                            if (!isCustomAmountConfirmed) {
                              shouldDisableButton = true;
                            }
                          }
                          
                          return ElevatedButton(
                            onPressed: (isLoading || shouldDisableButton) ? null : () async {
                          final violationReason = violationController.text.trim();
                          
                          reasonError = null;
                          durationError = null;
                          
                          if (violationReason.isEmpty) {
                            setDialogState(() {
                              reasonError = 'Please provide a violation reason';
                            });
                            return;
                          }
                          
                          if (isCustomReason) {
                            if (!isCustomAmountConfirmed) {
                              final customAmountText = customDeductController.text.trim();
                              if (customAmountText.isEmpty) {
                                
                                finalDeductAmount = null;
                              } else {
                                
                                setDialogState(() {
                                  customDeductError = 'Please click "Confirm Amount" first';
                                });
                                return;
                              }
                            } else {
                              
                              finalDeductAmount = confirmedCustomAmount;
                            }
                          }
                          
                          final currentCanDeduct = finalDeductAmount != null && finalDeductAmount! > 0 && availableBalance >= finalDeductAmount!;
                          final currentNeedsAlternative = (finalDeductAmount != null && finalDeductAmount! > 0 && !currentCanDeduct) ||
                              (isCustomReason && availableBalance == 0 && (finalDeductAmount == null || finalDeductAmount == 0));
                          
                          if (currentNeedsAlternative && selectedAction == 'suspend') {
                            final durationText = durationController.text.trim();
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
                              final userService = UserService();
                              final currentAdminId = FirebaseAuth.instance.currentUser?.uid;
                              
                              final userDoc = await FirebaseFirestore.instance
                                  .collection('users')
                                  .doc(userId)
                                  .get();
                              final userData = userDoc.data();
                              final userEmail = userData?['email'] ?? '';
                              
                              await userService.suspendUser(
                                userId,
                                violationReason: violationReason,
                                durationDays: durationDays,
                              );
                              
                              try {
                                final walletRef = FirebaseFirestore.instance
                                    .collection('wallets')
                                    .doc(userId);
                                final transactionsRef = walletRef.collection('transactions');
                                
                                await transactionsRef.add({
                                  'id': '',
                                  'userId': userId,
                                  'type': 'debit',
                                  'amount': 0, 
                                  'description': 'Account suspended due to insufficient balance for report category deduction. Reason: $violationReason',
                                  'createdAt': FieldValue.serverTimestamp(),
                                  'referenceId': reportId,
                                });
                              } catch (e) {
                                
                              }
                              
                              try {
                                await FirebaseFirestore.instance
                                    .collection('notifications')
                                    .add({
                                  'body': 'Your account has been suspended for $durationDays days due to insufficient balance for report category deduction. Reason: $violationReason',
                                  'category': 'account_suspension',
                                  'createdAt': FieldValue.serverTimestamp(),
                                  'isRead': false,
                                  'metadata': {
                                    'violationReason': violationReason,
                                    'suspensionDuration': durationDays,
                                    'userName': userName,
                                    'userEmail': userEmail,
                                    'actionType': 'suspension',
                                    'reason': 'Insufficient balance for credit deduction',
                                  },
                                  'title': 'Account Suspended',
                                  'userId': userId,
                                });
                              } catch (e) {
                                
                              }
                              
                              try {
                                await FirebaseFirestore.instance.collection('logs').add({
                                  'actionType': 'report_handled_suspend',
                                  'userId': userId,
                                  'userName': userName,
                                  'reportId': reportId,
                                  'violationReason': violationReason,
                                  'durationDays': durationDays,
                                  'deductAmount': deductAmount,
                                  'availableBalance': availableBalance,
                                  'reason': 'Insufficient balance for credit deduction. User suspended instead.',
                                  'createdAt': FieldValue.serverTimestamp(),
                                  'createdBy': currentAdminId,
                                });
                              } catch (e) {
                                
                              }
                              
                              Navigator.pop(context, {
                                'success': true,
                                'action': 'suspend',
                                'durationDays': durationDays,
                                'userName': userName,
                              });
                            } catch (e) {
                              setDialogState(() {
                                isLoading = false;
                              });
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Error: $e'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            }
                          } else {
                            
                            final canDeductFinal = finalDeductAmount != null && finalDeductAmount! > 0 && availableBalance >= finalDeductAmount!;
                            
                            Navigator.pop(context, {
                              'success': true,
                              'action': 'warning',
                              'violationReason': violationReason,
                              'deductAmount': canDeductFinal ? finalDeductAmount : null,
                            });
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: shouldDisableButton ? Colors.grey[400] : Colors.orange,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: Colors.grey[400],
                          disabledForegroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                            child: isLoading
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                    ),
                                  )
                                : const Text(
                                    'Apply Actions',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
}
