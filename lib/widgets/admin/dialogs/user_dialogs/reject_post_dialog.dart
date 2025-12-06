import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fyp_project/services/admin/user_service.dart';
import 'package:fyp_project/services/admin/post_service.dart';
import 'package:fyp_project/services/admin/report_service.dart';
import 'package:fyp_project/models/admin/report_model.dart';
import 'package:fyp_project/models/admin/report_category_model.dart';
import 'package:fyp_project/utils/admin/app_colors.dart';

class RejectPostDialog {
  static Future<Map<String, dynamic>?> show({
    required BuildContext context,
    required String postId,
    required String employerId,
    required int currentStrikes,
    required String reportId,
    required ReportService reportService,
    required PostService postService,
    required UserService userService,
    String? notes,
    String? Function()? getCurrentUserId,
    double walletBalance = 0.0,
    double heldCredits = 0.0,
    double availableBalance = 0.0,
  }) async {
    final violationController = TextEditingController();
    
    bool isLoading = false;
    String? reasonError;
    String? postStatus;
    ReportCategoryModel? matchedCategory;
    double? deductAmount;
    
    try {
      final postDoc = await FirebaseFirestore.instance
          .collection('posts')
          .doc(postId)
          .get();
      postStatus = postDoc.data()?['status']?.toString() ?? 'unknown';
      
      final reportDoc = await FirebaseFirestore.instance
          .collection('reports')
          .doc(reportId)
          .get();
      final reportReason = reportDoc.data()?['reason']?.toString() ?? '';
      
      final categoriesSnapshot = await FirebaseFirestore.instance
          .collection('report_categories')
          .where('type', isEqualTo: 'recruiter')
          .where('isEnabled', isEqualTo: true)
          .get();
      
      final categories = categoriesSnapshot.docs.map((doc) {
        final data = doc.data();
        return ReportCategoryModel(
          id: doc.id,
          name: data['name'] ?? '',
          description: data['description'] ?? '',
          isEnabled: data['isEnabled'] ?? true,
          creditDeduction: (data['creditDeduction'] as num?)?.toInt() ?? 0,
          type: data['type'] ?? 'recruiter',
          updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
        );
      }).toList();
      
      try {
        matchedCategory = categories.firstWhere(
          (cat) => cat.name.toLowerCase() == reportReason.toLowerCase(),
        );
      } catch (e) {
        try {
          matchedCategory = categories.firstWhere(
            (cat) => cat.name.toLowerCase().contains(reportReason.toLowerCase()) ||
                     reportReason.toLowerCase().contains(cat.name.toLowerCase()),
          );
        } catch (e2) {
          matchedCategory = null;
        }
      }
      
      if (matchedCategory != null && matchedCategory.id.isNotEmpty) {
        deductAmount = matchedCategory.creditDeduction.toDouble();
      }
    } catch (e) {
      print('Error loading post status or category: $e');
    }

    return await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: !isLoading,
      enableDrag: !isLoading,
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
              
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.error,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: isLoading ? null : () => Navigator.pop(context),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        postStatus == 'completed'
                            ? 'Issue Warning to Post Owner'
                            : 'Reject Post & Issue Warning',
                        style: const TextStyle(
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
                        postStatus == 'completed'
                            ? 'You are about to issue a warning and deduct credits from the post owner for the violation. The post status will remain as completed.'
                            : 'You are about to reject the post and issue a warning with credit deduction to the post owner.',
                        style: TextStyle(
                          fontSize: 15,
                          color: Colors.grey[800],
                        ),
                      ),
                      
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.blue[50],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.blue[200]!),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.account_balance_wallet, size: 20, color: Colors.blue[700]),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Post Owner Wallet Information',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.blue[900],
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
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
                            if (deductAmount != null && deductAmount > 0) ...[
                              const SizedBox(height: 8),
                              const Divider(),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Icon(Icons.info_outline, size: 16, color: Colors.blue[700]),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Credit deduction: ${deductAmount.toInt()} credits will be deducted',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: Colors.blue[900],
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                availableBalance >= deductAmount
                                    ? '✓ Sufficient balance available'
                                    : '⚠ Insufficient balance - deduction will be skipped',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: availableBalance >= deductAmount ? Colors.green[700] : Colors.orange[700],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ],
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
                            Icon(Icons.info_outline, color: Colors.orange[700], size: 20),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Post owner strikes: $currentStrikes/3',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.orange[900],
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    (3 - currentStrikes) > 0 
                                        ? '${3 - currentStrikes} more strike${(3 - currentStrikes) == 1 ? '' : 's'} until automatic suspension'
                                        : 'Account will be suspended automatically',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.orange[800],
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        postStatus == 'completed'
                            ? 'Violation Reason *'
                            : 'Rejection & Violation Reason *',
                        style: const TextStyle(
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
                          hintText: postStatus == 'completed'
                              ? 'Explain the violation...'
                              : 'Explain why the post is being rejected and the violation...',
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
                        postStatus == 'completed'
                            ? 'The post owner will receive a warning notification and credits will be deducted. The post status will not change.'
                            : 'The post will be rejected and the owner will receive a warning notification with credit deduction.',
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
                      child: ElevatedButton(
                        onPressed: isLoading ? null : () async {
                          final violationReason = violationController.text.trim();

                          if (violationReason.isEmpty) {
                            setDialogState(() {
                              reasonError = 'Please provide a rejection and violation reason';
                            });
                            return;
                          }

                          isLoading = true;
                          setDialogState(() {});

                          try {
                            
                            final postDoc = await FirebaseFirestore.instance
                                .collection('posts')
                                .doc(postId)
                                .get();
                            final postData = postDoc.data();
                            final postStatus = postData?['status']?.toString() ?? 'unknown';
                            
                            bool postRejected = false;
                            if (postStatus == 'active' || postStatus == 'approved') {
                              
                              await postService.rejectPost(postId, violationReason);
                              postRejected = true;
                            }
                            
                            final result = await userService.issueWarning(
                              userId: employerId,
                              violationReason: postRejected 
                                  ? 'Post rejected: $violationReason'
                                  : 'Post violation: $violationReason',
                              deductMarksAmount: deductAmount,
                              reportId: reportId,
                            );

                            if (!context.mounted) return;

                            if (result['success'] == true) {
                              final strikeCount = result['strikeCount'];
                              final wasSuspended = result['wasSuspended'];
                              final userName = result['userName'];
                              final deductionResult = result['deductionResult'] as Map<String, dynamic>?;

                              String actionMessage;
                              if (postRejected) {
                                
                                String baseMessage = wasSuspended 
                                    ? 'Post rejected - Owner suspended (3 strikes)'
                                    : 'Post rejected - Warning issued to owner (Strike $strikeCount/3)';
                                
                                if (deductAmount != null && deductAmount > 0) {
                                  if (deductionResult != null && deductionResult['success'] == true) {
                                    actionMessage = '$baseMessage. Credits deducted: ${deductAmount.toInt()}.';
                                  } else {
                                    
                                    final errorMsg = deductionResult?['error']?.toString() ?? 'Insufficient balance';
                                    actionMessage = '$baseMessage. Credit deduction failed: $errorMsg.';
                                  }
                                } else {
                                  actionMessage = baseMessage;
                                }
                              } else {
                                
                                String baseMessage = wasSuspended 
                                    ? 'Post violation handled - Owner suspended (3 strikes)'
                                    : 'Post violation handled - Warning issued to owner (Strike $strikeCount/3)';
                                
                                if (deductAmount != null && deductAmount > 0) {
                                  if (deductionResult != null && deductionResult['success'] == true) {
                                    actionMessage = '$baseMessage. Credits deducted: ${deductAmount.toInt()}.';
                                  } else {
                                    
                                    final errorMsg = deductionResult?['error']?.toString() ?? 'Insufficient balance';
                                    actionMessage = '$baseMessage. Credit deduction failed: $errorMsg.';
                                  }
                                } else {
                                  actionMessage = baseMessage;
                                }
                              }
                              
                              await reportService.updateReportStatus(
                                reportId,
                                ReportStatus.resolved,
                                notes: notes,
                                reviewedBy: getCurrentUserId?.call(),
                                actionTaken: actionMessage,
                              );

                              Navigator.pop(context, {
                                'success': true,
                                'wasSuspended': wasSuspended,
                                'strikeCount': strikeCount,
                                'userName': userName,
                              });
                            } else {
                              
                              final actionMessage = postRejected
                                  ? 'Post rejected - Warning failed: ${result['error']}'
                                  : 'Post violation handled - Warning failed: ${result['error']}';
                              
                              await reportService.updateReportStatus(
                                reportId,
                                ReportStatus.resolved,
                                notes: notes,
                                reviewedBy: getCurrentUserId?.call(),
                                actionTaken: actionMessage,
                              );
                              Navigator.pop(context, {
                                'success': false,
                                'error': result['error'],
                                'postRejected': postRejected,
                              });
                            }
                          } catch (e) {
                            Navigator.pop(context, {
                              'success': false,
                              'error': e.toString(),
                            });
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.error,
                          foregroundColor: Colors.white,
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
                            : Text(
                                postStatus == 'completed'
                                    ? 'Issue Warning'
                                    : 'Reject & Warn',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
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
