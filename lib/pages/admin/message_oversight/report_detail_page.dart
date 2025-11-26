import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fyp_project/models/admin/report_model.dart';
import 'package:fyp_project/models/admin/job_post_model.dart';
import 'package:fyp_project/services/admin/report_service.dart';
import 'package:fyp_project/services/admin/user_service.dart';
import 'package:fyp_project/services/admin/post_service.dart';
import 'package:fyp_project/pages/admin/post_moderation/post_detail_page.dart';
import 'package:fyp_project/utils/admin/app_colors.dart';

class ReportDetailPage extends StatefulWidget {
  final ReportModel report;

  const ReportDetailPage({super.key, required this.report});

  @override
  State<ReportDetailPage> createState() => _ReportDetailPageState();
}

class _ReportDetailPageState extends State<ReportDetailPage> {
  final ReportService _reportService = ReportService();
  final UserService _userService = UserService();
  final PostService _postService = PostService();
  bool _isProcessing = false;
  final TextEditingController _notesController = TextEditingController();
  final TextEditingController _violationController = TextEditingController();
  final TextEditingController _deductAmountController = TextEditingController();
  
  // Cached user and post information
  Map<String, String> _userInfo = {}; // userId -> "Name (email)"
  Map<String, String> _postInfo = {}; // postId -> "Post Title"
  Map<String, JobPostModel> _postModels = {}; // postId -> JobPostModel
  Map<String, bool> _postExists = {}; // postId -> exists/deleted status
  Map<String, String> _postStatus = {}; // postId -> post status
  bool _isLoadingInfo = true;

  String? _getCurrentUserId() {
    return FirebaseAuth.instance.currentUser?.uid;
  }

  Future<void> _dismissReport() async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text(
          'Dismiss Report',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: const Text(
          'Dismissing a report means closing it without taking any action. This is typically used when the report is invalid or no action is needed.\n\nAre you sure you want to dismiss this report?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: TextStyle(
                color: Colors.grey[700],
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.grey[700],
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text(
              'Dismiss',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isProcessing = true);
    try {
      await _reportService.updateReportStatus(
        widget.report.id,
        ReportStatus.dismissed,
        notes: _notesController.text.isEmpty 
            ? 'Report dismissed without action' 
            : _notesController.text,
        reviewedBy: _getCurrentUserId(),
        actionTaken: 'Dismissed - No action taken',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Report dismissed'),
            backgroundColor: Colors.grey,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  Future<void> _showWarningDialog() async {
    if (widget.report.reportType != ReportType.user) return;

    final userId = widget.report.reportedEmployeeId ?? widget.report.reportedItemId;
    if (userId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to identify user to warn'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Get current strike count and wallet balance
    final currentStrikes = await _userService.getStrikeCount(userId);
    final strikesRemaining = 3 - currentStrikes;
    final walletBalance = await _userService.getWalletBalance(userId);
    
    bool giveWarning = true;
    bool deductMarks = false;
    double? deductAmount;

    _violationController.clear();
    _deductAmountController.clear();
    
    await showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            'Handle User Report',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Choose actions to take against the reported user.',
                  style: TextStyle(
                    fontSize: 15,
                    color: Colors.grey[800],
                  ),
                ),
                const SizedBox(height: 16),
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
                      Icon(Icons.account_balance_wallet, color: Colors.blue[700], size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Current wallet balance: ${walletBalance.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.blue[900],
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
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
                              'Current strikes: $currentStrikes/3',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.orange[900],
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              strikesRemaining > 0 
                                  ? '$strikesRemaining more strike${strikesRemaining == 1 ? '' : 's'} until automatic suspension'
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
                // Action checkboxes
                CheckboxListTile(
                  value: giveWarning,
                  onChanged: (value) {
                    setDialogState(() => giveWarning = value ?? true);
                  },
                  title: const Text(
                    'Give Warning',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: const Text('Add a strike to the user\'s account'),
                  controlAffinity: ListTileControlAffinity.leading,
                ),
                CheckboxListTile(
                  value: deductMarks,
                  onChanged: (value) {
                    setDialogState(() {
                      deductMarks = value ?? false;
                      if (!deductMarks) {
                        _deductAmountController.clear();
                      }
                    });
                  },
                  title: const Text(
                    'Deduct Marks',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: const Text('Deduct marks from user\'s wallet'),
                  controlAffinity: ListTileControlAffinity.leading,
                ),
                if (deductMarks) ...[
                  const SizedBox(height: 8),
                  TextField(
                    controller: _deductAmountController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: 'Amount to Deduct *',
                      hintText: 'Enter amount (can go negative)',
                      prefixIcon: const Icon(Icons.attach_money),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      filled: true,
                      fillColor: Colors.grey[50],
                    ),
                  ),
                ],
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
                  controller: _violationController,
                  maxLines: 4,
                  decoration: InputDecoration(
                    hintText: 'Explain the violation (this will be sent to the user)...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    filled: true,
                    fillColor: Colors.grey[50],
                    contentPadding: const EdgeInsets.all(16),
                  ),
                  textInputAction: TextInputAction.done,
                ),
                const SizedBox(height: 12),
                Text(
                  giveWarning
                      ? 'The user will receive a warning notification. After 3 strikes, their account will be automatically suspended.'
                      : 'No warning will be issued.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
              child: Text(
                'Cancel',
                style: TextStyle(
                  color: Colors.grey[700],
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                final violationReason = _violationController.text.trim();

                if (violationReason.isEmpty) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please provide a violation reason'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }

                if (deductMarks) {
                  final amountText = _deductAmountController.text.trim();
                  if (amountText.isEmpty) {
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Please enter the amount to deduct'),
                        backgroundColor: Colors.red,
                      ),
                    );
                    return;
                  }
                  deductAmount = double.tryParse(amountText);
                  if (deductAmount == null || deductAmount! <= 0) {
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Please enter a valid amount'),
                        backgroundColor: Colors.red,
                      ),
                    );
                    return;
                  }
                  // Allow negative balances - no need to check if amount exceeds balance
                }

                if (!giveWarning && !deductMarks) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please select at least one action'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }

                Navigator.pop(context);
                await _issueWarningToUser(userId, violationReason, giveWarning, deductAmount);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'Apply Actions',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _issueWarningToUser(String userId, String violationReason, bool giveWarning, double? deductAmount) async {
    setState(() => _isProcessing = true);
    try {
      String actionTaken = '';
      
      if (giveWarning && deductAmount != null && deductAmount > 0) {
        // Both warning and deduction
        final result = await _userService.issueWarning(
          userId: userId,
          violationReason: violationReason,
          deductMarksAmount: deductAmount,
        );
        
        if (!mounted) return;
        
        if (result['success'] == true) {
          final strikeCount = result['strikeCount'];
          final wasSuspended = result['wasSuspended'];
          final userName = result['userName'];
          final deductionResult = result['deductionResult'] as Map<String, dynamic>?;
          
          String actionMsg = '';
          if (wasSuspended) {
            actionMsg = 'Warning issued - User suspended (3 strikes). ';
          } else {
            actionMsg = 'Warning issued (Strike $strikeCount/3). ';
          }
          
          if (deductionResult != null && deductionResult['success'] == true) {
            actionMsg += 'Marks deducted: ${deductAmount.toStringAsFixed(2)}. New balance: ${deductionResult['newBalance']?.toStringAsFixed(2) ?? '0.00'}.';
          } else if (deductionResult != null) {
            actionMsg += 'Warning issued but mark deduction failed: ${deductionResult['error']}.';
          }
          
          actionTaken = actionMsg;
          
          // Update report status
          await _reportService.updateReportStatus(
            widget.report.id,
            ReportStatus.resolved,
            notes: _notesController.text.isEmpty ? null : _notesController.text,
            reviewedBy: _getCurrentUserId(),
            actionTaken: actionTaken,
          );
          
          if (wasSuspended) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('$userName has reached 3 strikes and has been automatically suspended. Marks deducted: ${deductAmount.toStringAsFixed(2)}'),
                backgroundColor: Colors.orange,
              ),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Warning issued to $userName (Strike $strikeCount/3). Marks deducted: ${deductAmount.toStringAsFixed(2)}'),
                backgroundColor: Colors.green,
              ),
            );
          }
          Navigator.pop(context, true);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to issue warning: ${result['error']}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } else if (giveWarning) {
        // Only warning
        final result = await _userService.issueWarning(
          userId: userId,
          violationReason: violationReason,
        );
        
        if (!mounted) return;
        
        if (result['success'] == true) {
          final strikeCount = result['strikeCount'];
          final wasSuspended = result['wasSuspended'];
          final userName = result['userName'];
          
          actionTaken = wasSuspended 
              ? 'Warning issued - User suspended (3 strikes)' 
              : 'Warning issued (Strike $strikeCount/3)';
          
          // Update report status
          await _reportService.updateReportStatus(
            widget.report.id,
            ReportStatus.resolved,
            notes: _notesController.text.isEmpty ? null : _notesController.text,
            reviewedBy: _getCurrentUserId(),
            actionTaken: actionTaken,
          );
          
          if (wasSuspended) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('$userName has reached 3 strikes and has been automatically suspended'),
                backgroundColor: Colors.orange,
              ),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Warning issued to $userName (Strike $strikeCount/3)'),
                backgroundColor: Colors.green,
              ),
            );
          }
          Navigator.pop(context, true);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to issue warning: ${result['error']}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } else if (deductAmount != null && deductAmount > 0) {
        // Only deduction
        final deductionResult = await _userService.deductMarks(
          userId: userId,
          amount: deductAmount,
          reason: 'Report action: $violationReason',
        );
        
        if (!mounted) return;
        
        if (deductionResult['success'] == true) {
          actionTaken = 'Marks deducted: ${deductAmount.toStringAsFixed(2)}. New balance: ${deductionResult['newBalance']?.toStringAsFixed(2) ?? '0.00'}.';
          
          // Update report status
          await _reportService.updateReportStatus(
            widget.report.id,
            ReportStatus.resolved,
            notes: _notesController.text.isEmpty ? null : _notesController.text,
            reviewedBy: _getCurrentUserId(),
            actionTaken: actionTaken,
          );
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Marks deducted: ${deductAmount.toStringAsFixed(2)}. New balance: ${deductionResult['newBalance']?.toStringAsFixed(2) ?? '0.00'}'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context, true);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to deduct marks: ${deductionResult['error']}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to issue warning: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  Future<void> _showRejectPostDialog() async {
    if (widget.report.reportType != ReportType.jobPost) return;

    final postId = widget.report.reportedPostId ?? widget.report.reportedItemId;
    if (postId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to identify post to reject'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Check if post is deleted
    if (_isPostDeleted()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot reject: Post has already been deleted'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Check if post is already rejected
    if (_isPostRejected()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Post has already been rejected'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Get post owner ID
    String? employerId = widget.report.reportedEmployerId;
    if (employerId == null || employerId.isEmpty) {
      try {
        final postDoc = await FirebaseFirestore.instance
            .collection('posts')
            .doc(postId)
            .get();
        if (postDoc.exists) {
          employerId = postDoc.data()?['ownerId']?.toString();
        }
      } catch (e) {
        print('Error fetching post: $e');
      }
    }

    if (employerId == null || employerId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to identify post owner'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Get current strike count for the employer
    final currentStrikes = await _userService.getStrikeCount(employerId);
    final strikesRemaining = 3 - currentStrikes;

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text(
          'Reject Post & Issue Warning',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'You are about to reject the post and issue a warning to the post owner.',
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
                            strikesRemaining > 0 
                                ? '$strikesRemaining more strike${strikesRemaining == 1 ? '' : 's'} until automatic suspension'
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
              const Text(
                'Rejection & Violation Reason *',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _violationController,
                maxLines: 4,
                decoration: InputDecoration(
                  hintText: 'Explain why the post is being rejected and the violation...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  filled: true,
                  fillColor: Colors.grey[50],
                  contentPadding: const EdgeInsets.all(16),
                ),
                textInputAction: TextInputAction.done,
              ),
              const SizedBox(height: 12),
              Text(
                'The post will be rejected and the owner will receive a warning notification.',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            child: Text(
              'Cancel',
              style: TextStyle(
                color: Colors.grey[700],
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              final violationReason = _violationController.text.trim();

              if (violationReason.isEmpty) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please provide a rejection and violation reason'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }

              Navigator.pop(context);
              await _rejectPostAndWarn(postId, employerId!, violationReason);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text(
              'Reject & Warn',
              style: TextStyle(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _rejectPostAndWarn(String postId, String employerId, String reason) async {
    setState(() => _isProcessing = true);
    try {
      // Reject the post
      await _postService.rejectPost(postId, reason);

      // Issue warning to the post owner
      final result = await _userService.issueWarning(
        userId: employerId,
        violationReason: 'Post rejected: $reason',
      );

      if (!mounted) return;

      if (result['success'] == true) {
        final strikeCount = result['strikeCount'];
        final wasSuspended = result['wasSuspended'];
        final userName = result['userName'];

        // Update report status
        await _reportService.updateReportStatus(
          widget.report.id,
          ReportStatus.resolved,
          notes: _notesController.text.isEmpty ? null : _notesController.text,
          reviewedBy: _getCurrentUserId(),
          actionTaken: wasSuspended 
              ? 'Post rejected - Owner suspended (3 strikes)' 
              : 'Post rejected - Warning issued to owner (Strike $strikeCount/3)',
        );

        if (wasSuspended) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Post rejected. $userName has reached 3 strikes and has been automatically suspended'),
              backgroundColor: Colors.orange,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Post rejected. Warning issued to $userName (Strike $strikeCount/3)'),
              backgroundColor: Colors.green,
            ),
          );
        }
        Navigator.pop(context, true);
      } else {
        // Post was rejected but warning failed
        await _reportService.updateReportStatus(
          widget.report.id,
          ReportStatus.resolved,
          notes: _notesController.text.isEmpty ? null : _notesController.text,
          reviewedBy: _getCurrentUserId(),
          actionTaken: 'Post rejected - Warning failed: ${result['error']}',
        );
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Post rejected but failed to issue warning: ${result['error']}'),
            backgroundColor: Colors.orange,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  @override
  void initState() {
    super.initState();
    _loadAdditionalInfo();
  }

  Future<void> _loadAdditionalInfo() async {
    setState(() => _isLoadingInfo = true);
    
    try {
      // Load reporter info
      if (widget.report.reporterId.isNotEmpty) {
        await _loadUserInfo(widget.report.reporterId);
      }
      
      // Load reviewed by info
      if (widget.report.reviewedBy != null && widget.report.reviewedBy!.isNotEmpty) {
        await _loadUserInfo(widget.report.reviewedBy!);
      }
      
      // Load reported user info (for employee reports)
      if (widget.report.reportType == ReportType.user) {
        final userId = widget.report.reportedEmployeeId ?? widget.report.reportedItemId;
        if (userId.isNotEmpty) {
          await _loadUserInfo(userId);
        }
      }
      
      // Load post info (for post reports)
      if (widget.report.reportType == ReportType.jobPost) {
        final postId = widget.report.reportedPostId ?? widget.report.reportedItemId;
        if (postId.isNotEmpty) {
          await _loadPostInfo(postId);
        }
        
        // Load post owner info
        if (widget.report.reportedEmployerId != null && widget.report.reportedEmployerId!.isNotEmpty) {
          await _loadUserInfo(widget.report.reportedEmployerId!);
        }
      }
    } catch (e) {
      print('Error loading additional info: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoadingInfo = false);
      }
    }
  }

  Future<void> _loadUserInfo(String userId) async {
    if (_userInfo.containsKey(userId)) return;
    
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();
      
      if (userDoc.exists) {
        final data = userDoc.data();
        final name = data?['fullName'] ?? 'Unknown User';
        final email = data?['email'] ?? '';
        _userInfo[userId] = email.isNotEmpty ? '$name ($email)' : name;
      } else {
        _userInfo[userId] = 'User not found';
      }
    } catch (e) {
      _userInfo[userId] = 'Error loading user';
    }
    
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _loadPostInfo(String postId) async {
    if (_postInfo.containsKey(postId)) return;
    
    try {
      final postDoc = await FirebaseFirestore.instance
          .collection('posts')
          .doc(postId)
          .get();
      
      if (postDoc.exists) {
        final data = postDoc.data();
        final title = data?['title'] ?? 'Unknown Post';
        final status = data?['status']?.toString() ?? 'unknown';
        
        _postInfo[postId] = title;
        _postExists[postId] = true;
        _postStatus[postId] = status;
        
        // Store the full post model for viewing details
        try {
          _postModels[postId] = JobPostModel.fromFirestore(postDoc);
        } catch (e) {
          print('Error parsing post model: $e');
        }
        
        // Also load post owner if not already loaded
        final ownerId = data?['ownerId']?.toString();
        if (ownerId != null && ownerId.isNotEmpty && !_userInfo.containsKey(ownerId)) {
          await _loadUserInfo(ownerId);
        }
      } else {
        _postInfo[postId] = 'Post Deleted';
        _postExists[postId] = false;
        _postStatus[postId] = 'deleted';
        
        // Auto-resolve report if post is deleted and report is still pending
        if (widget.report.status == ReportStatus.pending && mounted) {
          _autoResolveDeletedPost();
        }
      }
    } catch (e) {
      _postInfo[postId] = 'Error loading post';
      _postExists[postId] = false;
    }
    
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _autoResolveDeletedPost() async {
    // Only auto-resolve if report is still pending
    if (widget.report.status != ReportStatus.pending) return;
    
    try {
      await _reportService.updateReportStatus(
        widget.report.id,
        ReportStatus.resolved,
        notes: 'Report automatically resolved: The reported post has been deleted.',
        reviewedBy: _getCurrentUserId(),
        actionTaken: 'Auto-resolved: Post deleted',
      );
      
      // Show a snackbar to inform the user
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Report automatically resolved: The reported post has been deleted.'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 4),
          ),
        );
        // Refresh the page after a short delay
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            Navigator.pop(context, true);
          }
        });
      }
    } catch (e) {
      print('Error auto-resolving report: $e');
      // Don't show error to user, just log it
    }
  }

  bool _isPostDeleted() {
    if (widget.report.reportType != ReportType.jobPost) return false;
    final postId = widget.report.reportedPostId ?? widget.report.reportedItemId;
    if (postId.isEmpty) return false;
    return _postExists[postId] == false || _postStatus[postId] == 'deleted';
  }

  bool _isPostRejected() {
    if (widget.report.reportType != ReportType.jobPost) return false;
    final postId = widget.report.reportedPostId ?? widget.report.reportedItemId;
    if (postId.isEmpty) return false;
    return _postStatus[postId] == 'rejected';
  }

  Future<void> _viewPostDetails() async {
    final postId = widget.report.reportedPostId ?? widget.report.reportedItemId;
    if (postId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Post ID not available'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Check if post is deleted
    if (_isPostDeleted()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot view: Post has been deleted'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Check if we already have the post model
    if (_postModels.containsKey(postId)) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PostDetailPage(post: _postModels[postId]!),
        ),
      );
      return;
    }

    // Load the post if we don't have it
    try {
      final postDoc = await FirebaseFirestore.instance
          .collection('posts')
          .doc(postId)
          .get();
      
      if (postDoc.exists) {
        final post = JobPostModel.fromFirestore(postDoc);
        _postModels[postId] = post;
        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => PostDetailPage(post: post),
            ),
          );
        }
      } else {
        // Update state to reflect deleted post
        _postExists[postId] = false;
        _postStatus[postId] = 'deleted';
        if (mounted) {
          setState(() {});
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Post has been deleted and is no longer available'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading post: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _getUserDisplay(String userId) {
    return _userInfo[userId] ?? (userId.isEmpty ? 'N/A' : 'Loading...');
  }

  String _getPostDisplay(String postId) {
    return _postInfo[postId] ?? (postId.isEmpty ? 'N/A' : 'Loading...');
  }

  @override
  void dispose() {
    _notesController.dispose();
    _violationController.dispose();
    _deductAmountController.dispose();
    super.dispose();
  }

  Color _getStatusColor() {
    switch (widget.report.status) {
      case ReportStatus.pending:
        return Colors.red;
      case ReportStatus.underReview:
        return Colors.orange;
      case ReportStatus.resolved:
        return Colors.green;
      case ReportStatus.dismissed:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _getStatusColor();
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Report Details'),
        backgroundColor: AppColors.cardRed,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status Banner
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.1),
                border: Border(
                  bottom: BorderSide(color: statusColor.withOpacity(0.3), width: 2),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: statusColor,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      widget.report.status.toString().split('.').last.toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      widget.report.reportType == ReportType.jobPost 
                          ? 'Post Report' 
                          : widget.report.reportType == ReportType.user 
                              ? 'Employee Report' 
                              : 'Report',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[800],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Report Information Card
            Padding(
              padding: const EdgeInsets.all(16),
              child: Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: _isLoadingInfo
                      ? const Center(
                          child: Padding(
                            padding: EdgeInsets.all(20),
                            child: CircularProgressIndicator(),
                          ),
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Report Information',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 20),
                            _DetailRow(
                              label: 'Reason', 
                              value: widget.report.reason,
                              isHighlighted: true,
                            ),
                            if (widget.report.description != null && widget.report.description!.isNotEmpty) ...[
                              const SizedBox(height: 16),
                              _DetailRow(
                                label: 'Description', 
                                value: widget.report.description!,
                              ),
                            ],
                            const SizedBox(height: 16),
            _DetailRow(
              label: 'Reported At',
                              value: _formatDateTime(widget.report.reportedAt),
                            ),
                            const SizedBox(height: 16),
                            // Show reporter information
                            _DetailRow(
                              label: 'Reporter', 
                              value: _getUserDisplay(widget.report.reporterId),
                            ),
                            const SizedBox(height: 16),
                            // Show reported item information based on type
                            if (widget.report.reportType == ReportType.user) ...[
                              _DetailRow(
                                label: 'Reported User', 
                                value: _getUserDisplay(
                                  widget.report.reportedEmployeeId ?? widget.report.reportedItemId
                                ),
                              ),
                            ] else if (widget.report.reportType == ReportType.jobPost) ...[
                              // Reported Post with View Details button
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 4),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    SizedBox(
                                      width: 130,
                                      child: Text(
                                        'Reported Post',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 14,
                                          color: Colors.grey[700],
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  _getPostDisplay(
                                                    widget.report.reportedPostId ?? widget.report.reportedItemId
                                                  ),
                                                  style: const TextStyle(
                                                    fontSize: 14,
                                                    color: Colors.black87,
                                                  ),
                                                ),
                                              ),
                                              if (_isPostDeleted()) ...[
                                                const SizedBox(width: 8),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(
                                                    horizontal: 8,
                                                    vertical: 4,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: Colors.red[50],
                                                    borderRadius: BorderRadius.circular(4),
                                                    border: Border.all(color: Colors.red[300]!),
                                                  ),
                                                  child: Row(
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      Icon(Icons.delete_outline, 
                                                        size: 14, 
                                                        color: Colors.red[700],
                                                      ),
                                                      const SizedBox(width: 4),
                                                      Text(
                                                        'Deleted',
                                                        style: TextStyle(
                                                          fontSize: 11,
                                                          color: Colors.red[700],
                                                          fontWeight: FontWeight.w600,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ] else if (_isPostRejected()) ...[
                                                const SizedBox(width: 8),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(
                                                    horizontal: 8,
                                                    vertical: 4,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: Colors.orange[50],
                                                    borderRadius: BorderRadius.circular(4),
                                                    border: Border.all(color: Colors.orange[300]!),
                                                  ),
                                                  child: Row(
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      Icon(Icons.block, 
                                                        size: 14, 
                                                        color: Colors.orange[700],
                                                      ),
                                                      const SizedBox(width: 4),
                                                      Text(
                                                        'Rejected',
                                                        style: TextStyle(
                                                          fontSize: 11,
                                                          color: Colors.orange[700],
                                                          fontWeight: FontWeight.w600,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                          const SizedBox(height: 8),
                                          if (!_isPostDeleted())
                                            OutlinedButton.icon(
                                              onPressed: _viewPostDetails,
                                              icon: const Icon(Icons.visibility, size: 16),
                                              label: const Text('View Post Details'),
                                              style: OutlinedButton.styleFrom(
                                                foregroundColor: Colors.blue[700],
                                                side: BorderSide(color: Colors.blue[300]!),
                                                padding: const EdgeInsets.symmetric(
                                                  horizontal: 12,
                                                  vertical: 8,
                                                ),
                                              ),
                                            )
                                          else
                                            Container(
                                              padding: const EdgeInsets.symmetric(
                                                horizontal: 12,
                                                vertical: 8,
                                              ),
                                              decoration: BoxDecoration(
                                                color: Colors.grey[100],
                                                borderRadius: BorderRadius.circular(8),
                                                border: Border.all(color: Colors.grey[300]!),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(Icons.info_outline, 
                                                    size: 16, 
                                                    color: Colors.grey[600],
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Text(
                                                    'Post has been deleted',
                                                    style: TextStyle(
                                                      fontSize: 14,
                                                      color: Colors.grey[600],
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (widget.report.reportedEmployerId != null && 
                                  widget.report.reportedEmployerId!.isNotEmpty) ...[
                                const SizedBox(height: 16),
                                _DetailRow(
                                  label: 'Post Owner', 
                                  value: _getUserDisplay(widget.report.reportedEmployerId!),
                                ),
                              ],
                            ],
                            if (widget.report.reviewedBy != null && widget.report.reviewedBy!.isNotEmpty) ...[
                              const SizedBox(height: 16),
                              _DetailRow(
                                label: 'Reviewed By', 
                                value: _getUserDisplay(widget.report.reviewedBy!),
                              ),
                            ],
                            if (widget.report.reviewedAt != null) ...[
                              const SizedBox(height: 16),
                              _DetailRow(
                                label: 'Reviewed At', 
                                value: _formatDateTime(widget.report.reviewedAt!),
                              ),
                            ],
                            if (widget.report.reviewNotes != null && widget.report.reviewNotes!.isNotEmpty) ...[
                              const SizedBox(height: 16),
                              _DetailRow(
                                label: 'Review Notes', 
                                value: widget.report.reviewNotes!,
                              ),
                            ],
                            if (widget.report.actionTaken != null && widget.report.actionTaken!.isNotEmpty) ...[
                              const SizedBox(height: 16),
            _DetailRow(
                                label: 'Action Taken', 
                                value: widget.report.actionTaken!,
                              ),
                            ],
                          ],
                        ),
                ),
              ),
            ),

            // Review Notes Section (only show if report is not resolved)
            if (widget.report.status != ReportStatus.resolved) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Card(
                  elevation: 1,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Internal Notes',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 12),
            TextField(
              controller: _notesController,
                          decoration: InputDecoration(
                            hintText: 'Add internal notes about this report...',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            filled: true,
                            fillColor: Colors.grey[50],
                            contentPadding: const EdgeInsets.all(16),
              ),
              maxLines: 3,
            ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],

            // Action Buttons (only show if report is not resolved)
            if (widget.report.status != ReportStatus.resolved) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: [
                    if (widget.report.reportType == ReportType.user) ...[
                      // Employee Report Actions
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: (_isProcessing || _isLoadingInfo) ? null : _showWarningDialog,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 2,
                          ),
                          child: const Text(
                            'Handle User Report',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: (_isProcessing || _isLoadingInfo) ? null : _dismissReport,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.grey[700],
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            side: BorderSide(color: Colors.grey[400]!, width: 1.5),
                          ),
                          child: const Text(
                            'Dismiss Report',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                  ] else if (widget.report.reportType == ReportType.jobPost) ...[
                    // Post Report Actions
                    if (_isPostDeleted()) ...[
                      // Post is deleted - show info message
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.green[50],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.green[200]!),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.check_circle_outline, color: Colors.green[700], size: 20),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Post Deleted - Report Resolved',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.green[900],
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'The reported post has been deleted. The report has been automatically resolved.',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.green[800],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                    ] else if (_isPostRejected()) ...[
                      // Post is already rejected - show info message
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.blue[50],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.blue[200]!),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.info_outline, color: Colors.blue[700], size: 20),
                            const SizedBox(width: 12),
                Expanded(
                              child: Text(
                                'The reported post has already been rejected.',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.blue[900],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                    ] else ...[
                      // Post exists and can be rejected (only show if we've loaded the post info)
                      if (!_isLoadingInfo && _postExists.containsKey(
                        widget.report.reportedPostId ?? widget.report.reportedItemId
                      )) ...[
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: (_isProcessing || _isLoadingInfo) ? null : _showRejectPostDialog,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.error,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 2,
                            ),
                            child: const Text(
                              'Reject Post & Give Warning',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                      ] else if (_isLoadingInfo) ...[
                        // Show loading state while checking post status
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.grey[400],
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 0,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                const Text(
                                  'Checking post status...',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                    ],
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: (_isProcessing || _isLoadingInfo) ? null : _dismissReport,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.grey[700],
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          side: BorderSide(color: Colors.grey[400]!, width: 1.5),
                        ),
                        child: const Text(
                          'Dismiss Report',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ] else ...[
                    // Other report types - just dismiss
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: (_isProcessing || _isLoadingInfo) ? null : _dismissReport,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.grey[700],
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          side: BorderSide(color: Colors.grey[400]!, width: 1.5),
                        ),
                        child: const Text(
                          'Dismiss Report',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                    if (_isProcessing) ...[
                      const SizedBox(height: 20),
                      const Center(
                        child: CircularProgressIndicator(),
                      ),
                    ],
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ] else ...[
              // Report is resolved - show message
              Padding(
                padding: const EdgeInsets.all(16),
                child: Card(
                  elevation: 1,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: Colors.green[200]!, width: 1),
                  ),
                  color: Colors.green[50],
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      children: [
                        Icon(Icons.check_circle, color: Colors.green[700], size: 28),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Report Resolved',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green[900],
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'This report has been resolved. No further actions can be taken.',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.green[800],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ],
        ),
      ),
    );
  }

  String _formatDateTime(DateTime date) {
    // The date should already be in local time from report_service
    // Just format it directly without any conversion
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final day = date.day;
    final month = months[date.month - 1];
    final year = date.year;
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '$day $month $year, $hour:$minute';
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isHighlighted;

  const _DetailRow({
    required this.label,
    required this.value,
    this.isHighlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: Colors.grey[700],
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isHighlighted ? FontWeight.w600 : FontWeight.normal,
                color: isHighlighted ? Colors.black87 : Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

