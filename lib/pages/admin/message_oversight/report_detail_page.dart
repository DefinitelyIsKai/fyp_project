import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fyp_project/models/admin/report_model.dart';
import 'package:fyp_project/models/admin/job_post_model.dart';
import 'package:fyp_project/models/admin/report_category_model.dart';
import 'package:fyp_project/services/admin/report_service.dart';
import 'package:fyp_project/services/admin/user_service.dart';
import 'package:fyp_project/services/admin/post_service.dart';
import 'package:fyp_project/services/admin/system_config_service.dart';
import 'package:fyp_project/pages/admin/post_moderation/post_detail_page.dart';
import 'package:fyp_project/utils/admin/app_colors.dart';
import 'package:fyp_project/widgets/admin/dialogs/user_dialogs/handle_user_report_dialog.dart';
import 'package:fyp_project/widgets/admin/cards/report_status_banner.dart';
import 'package:fyp_project/widgets/admin/cards/report_information_card.dart';
import 'package:fyp_project/widgets/admin/common/report_internal_notes_section.dart';
import 'package:fyp_project/widgets/admin/common/report_resolved_message.dart';
import 'package:fyp_project/widgets/admin/common/report_action_buttons.dart';

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
  final SystemConfigService _configService = SystemConfigService();
  bool _isProcessing = false;
  final TextEditingController _notesController = TextEditingController();
  final TextEditingController _violationController = TextEditingController();
  final TextEditingController _deductAmountController = TextEditingController();
  
  Map<String, String> _userInfo = {};
  Map<String, String> _postInfo = {};
  Map<String, JobPostModel> _postModels = {}; 
  Map<String, bool> _postExists = {};
  Map<String, String> _postStatus = {};
  bool _isLoadingInfo = true;

  String? _getCurrentUserId() {
    return FirebaseAuth.instance.currentUser?.uid;
  }

  Future<void> _dismissReport() async {
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
    
    // Get wallet balance and held credits to calculate available balance
    double walletBalance = 0.0;
    double heldCredits = 0.0;
    try {
      final walletDoc = await FirebaseFirestore.instance
          .collection('wallets')
          .doc(userId)
          .get();
      if (walletDoc.exists) {
        final data = walletDoc.data();
        final balanceValue = data?['balance'];
        final heldCreditsValue = data?['heldCredits'];
        
        if (balanceValue != null) {
          walletBalance = (balanceValue is num) ? balanceValue.toDouble() : 0.0;
        }
        if (heldCreditsValue != null) {
          heldCredits = (heldCreditsValue is num) ? heldCreditsValue.toDouble() : 0.0;
        }
      } else {
        // If wallet doesn't exist, create it
        walletBalance = await _userService.getWalletBalance(userId);
      }
    } catch (e) {
      walletBalance = await _userService.getWalletBalance(userId);
    }
    
    // Available balance = balance - heldCredits (real balance)
    final availableBalance = walletBalance - heldCredits;
    
    // Fetch report categories and match with report reason (for user/jobseeker reports)
    // User reports: recruiter reporting jobseeker, so we should check both 'jobseeker' and 'recruiter' types
    // to handle cases where categories might be incorrectly typed
    List<ReportCategoryModel> reportCategories = [];
    ReportCategoryModel? matchedCategory;
    try {
      final allCategories = await _configService.getReportCategories();
      // For user reports, check both 'jobseeker' and 'recruiter' type categories
      // (in case categories are incorrectly typed - should be 'jobseeker' for user reports)
      reportCategories = allCategories.where((cat) => 
        cat.type == 'jobseeker' || cat.type == 'recruiter'
      ).toList();
      try {
        matchedCategory = reportCategories.firstWhere(
          (cat) => cat.name.toLowerCase() == widget.report.reason.toLowerCase(),
        );
      } catch (e) {
        try {
          matchedCategory = reportCategories.firstWhere(
            (cat) => cat.name.toLowerCase().contains(widget.report.reason.toLowerCase()) ||
                     widget.report.reason.toLowerCase().contains(cat.name.toLowerCase()),
          );
        } catch (e2) {
          // No match found - this is a custom reason (other)
          matchedCategory = null;
        }
      }
      // Only use if category is enabled and has valid ID
      if (matchedCategory != null && (matchedCategory.id.isEmpty || !matchedCategory.isEnabled)) {
        matchedCategory = null;
      }
    } catch (e) {
      matchedCategory = null;
    }
    
    // If no matched category, this is a custom reason - allow admin to set custom deduction
    final deductAmount = matchedCategory?.creditDeduction.toDouble();

    // Get user name for dialog
    String userName = 'User';
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();
      if (userDoc.exists) {
        userName = userDoc.data()?['fullName'] ?? 'User';
      }
    } catch (e) {
      // Use default
    }

    final result = await HandleUserReportDialog.show(
      context: context,
      userId: userId,
      userName: userName,
      currentStrikes: currentStrikes,
      walletBalance: walletBalance,
      availableBalance: availableBalance,
      heldCredits: heldCredits,
      deductAmount: deductAmount,
      matchedCategory: matchedCategory,
      reportId: widget.report.id,
      reportReason: widget.report.reason,
    );

    if (result != null && result['success'] == true) {
      if (result['action'] == 'suspend') {
        // User was suspended
        final durationDays = result['durationDays'] as int;
        final suspendedUserName = result['userName'] as String;
        
        // Update report status
        await _reportService.updateReportStatus(
          widget.report.id,
          ReportStatus.resolved,
          notes: _notesController.text.isEmpty ? null : _notesController.text,
          reviewedBy: _getCurrentUserId(),
          actionTaken: 'User suspended for $durationDays days due to insufficient balance for credit deduction (${deductAmount?.toInt() ?? 0} credits required).',
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('$suspendedUserName has been suspended for $durationDays days due to insufficient balance.'),
              backgroundColor: Colors.orange,
            ),
          );
          Navigator.pop(context, true);
        }
      } else {
        // Normal warning flow
        final violationReason = result['violationReason'] as String;
        final deductAmountFromResult = result['deductAmount'] as double?;
        await _issueWarningToUser(userId, violationReason, deductAmountFromResult);
      }
    }
  }

  Future<void> _issueWarningToUser(String userId, String violationReason, double? deductAmount) async {
    setState(() => _isProcessing = true);
    try {
      String actionTaken = '';
      
      // Always issue warning, and deduct credits if amount is provided
      final result = await _userService.issueWarning(
        userId: userId,
        violationReason: violationReason,
        deductMarksAmount: deductAmount,
        reportId: widget.report.id,
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
          actionMsg += 'Credits deducted: ${deductAmount?.toStringAsFixed(0) ?? '0'}.';
        } else if (deductAmount != null && deductAmount > 0) {
          actionMsg += 'Warning issued but credit deduction failed: ${deductionResult?['error'] ?? 'Unknown error'}.';
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
              content: Text(
                deductAmount != null && deductAmount > 0
                    ? '$userName has reached 3 strikes and has been automatically suspended. Credits deducted: ${deductAmount.toInt()}.'
                    : '$userName has reached 3 strikes and has been automatically suspended.',
              ),
              backgroundColor: Colors.orange,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                deductAmount != null && deductAmount > 0
                    ? 'Warning issued to $userName (Strike $strikeCount/3). Credits deducted: ${deductAmount.toInt()}.'
                    : 'Warning issued to $userName (Strike $strikeCount/3).',
              ),
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

    // Get post status
    String postStatus = 'unknown';
    try {
      final postDoc = await FirebaseFirestore.instance
          .collection('posts')
          .doc(postId)
          .get();
      if (postDoc.exists) {
        postStatus = postDoc.data()?['status']?.toString() ?? 'unknown';
      }
    } catch (e) {
      print('Error fetching post status: $e');
    }

    // Get current strike count for the employer
    final currentStrikes = await _userService.getStrikeCount(employerId);

    // Get wallet balance and held credits to calculate available balance
    double walletBalance = 0.0;
    double heldCredits = 0.0;
    try {
      final walletDoc = await FirebaseFirestore.instance
          .collection('wallets')
          .doc(employerId)
          .get();
      if (walletDoc.exists) {
        final data = walletDoc.data();
        final balanceValue = data?['balance'];
        final heldCreditsValue = data?['heldCredits'];
        
        if (balanceValue != null) {
          walletBalance = (balanceValue is num) ? balanceValue.toDouble() : 0.0;
        }
        if (heldCreditsValue != null) {
          heldCredits = (heldCreditsValue is num) ? heldCreditsValue.toDouble() : 0.0;
        }
      } else {
        walletBalance = await _userService.getWalletBalance(employerId);
      }
    } catch (e) {
      walletBalance = await _userService.getWalletBalance(employerId);
    }
    
    // Available balance = balance - heldCredits (real balance)
    final availableBalance = walletBalance - heldCredits;
    
    // Fetch report categories and match with report reason (for post reports)
    // Post reports: jobseeker reporting recruiter's post, so we should check both 'recruiter' and 'jobseeker' types
    // to handle cases where categories might be incorrectly typed
    List<ReportCategoryModel> reportCategories = [];
    ReportCategoryModel? matchedCategory;
    try {
      final allCategories = await _configService.getReportCategories();
      // For post reports, check both 'recruiter' and 'jobseeker' type categories
      // (in case categories are incorrectly typed - should be 'recruiter' for post reports)
      reportCategories = allCategories.where((cat) => 
        cat.type == 'recruiter' || cat.type == 'jobseeker'
      ).toList();
      try {
        matchedCategory = reportCategories.firstWhere(
          (cat) => cat.name.toLowerCase() == widget.report.reason.toLowerCase(),
        );
      } catch (e) {
        try {
          matchedCategory = reportCategories.firstWhere(
            (cat) => cat.name.toLowerCase().contains(widget.report.reason.toLowerCase()) ||
                     widget.report.reason.toLowerCase().contains(cat.name.toLowerCase()),
          );
        } catch (e2) {
          // No match found - this is a custom reason (other)
          matchedCategory = null;
        }
      }
      // Only use if category is enabled and has valid ID
      if (matchedCategory != null && (matchedCategory.id.isEmpty || !matchedCategory.isEnabled)) {
        matchedCategory = null;
      }
    } catch (e) {
      matchedCategory = null;
    }
    
    // If no matched category, this is a custom reason - allow admin to set custom deduction
    final deductAmount = matchedCategory?.creditDeduction.toDouble();

    // Get user name for dialog
    String userName = 'User';
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(employerId)
          .get();
      if (userDoc.exists) {
        userName = userDoc.data()?['fullName'] ?? 'User';
      }
    } catch (e) {
      // Use default
    }

    final result = await HandleUserReportDialog.show(
      context: context,
      userId: employerId,
      userName: userName,
      currentStrikes: currentStrikes,
      walletBalance: walletBalance,
      availableBalance: availableBalance,
      heldCredits: heldCredits,
      deductAmount: deductAmount,
      matchedCategory: matchedCategory,
      reportId: widget.report.id,
      reportReason: widget.report.reason,
    );

    if (result != null && result['success'] == true && mounted) {
      if (result['action'] == 'suspend') {
        // User was suspended
        final durationDays = result['durationDays'] as int;
        final suspendedUserName = result['userName'] as String;
        
        // Handle post based on status
        bool postRejected = false;
        if (postStatus == 'active' || postStatus == 'approved') {
          // Reject the post
          await _postService.rejectPost(postId, 'Post owner suspended due to insufficient balance for credit deduction.');
          postRejected = true;
        }
        // If post is completed, don't change status
        
        // Update report status
        await _reportService.updateReportStatus(
          widget.report.id,
          ReportStatus.resolved,
          notes: _notesController.text.isEmpty ? null : _notesController.text,
          reviewedBy: _getCurrentUserId(),
          actionTaken: 'Post owner suspended for $durationDays days due to insufficient balance for credit deduction (${deductAmount?.toInt() ?? 0} credits required).${postRejected ? ' Post rejected.' : ''}',
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('$suspendedUserName has been suspended for $durationDays days.${postRejected ? ' Post rejected.' : ''}'),
              backgroundColor: Colors.orange,
            ),
          );
          Navigator.pop(context, true);
        }
      } else {
        // Normal warning flow
        final violationReason = result['violationReason'] as String;
        final deductAmountFromResult = result['deductAmount'] as double?;
        
        // Handle post based on status
        bool postRejected = false;
        if (postStatus == 'active' || postStatus == 'approved') {
          // Reject the post
          await _postService.rejectPost(postId, violationReason);
          postRejected = true;
        }
        // If post is completed, don't change status, just issue warning
        
        await _issueWarningToPostOwner(employerId, violationReason, deductAmountFromResult, postRejected, postStatus);
      }
    }
  }

  Future<void> _issueWarningToPostOwner(String userId, String violationReason, double? deductAmount, bool postRejected, String postStatus) async {
    setState(() => _isProcessing = true);
    try {
      String actionTaken = '';
      
      // Always issue warning, and deduct credits if amount is provided
      final result = await _userService.issueWarning(
        userId: userId,
        violationReason: postRejected 
            ? 'Post rejected: $violationReason'
            : 'Post violation: $violationReason',
        deductMarksAmount: deductAmount,
        reportId: widget.report.id,
      );
      
      if (!mounted) return;
      
      if (result['success'] == true) {
        final strikeCount = result['strikeCount'];
        final wasSuspended = result['wasSuspended'];
        final userName = result['userName'];
        final deductionResult = result['deductionResult'] as Map<String, dynamic>?;
        
        String actionMsg = '';
        if (postRejected) {
          actionMsg = wasSuspended 
              ? 'Post rejected - Owner suspended (3 strikes). '
              : 'Post rejected - Warning issued to owner (Strike $strikeCount/3). ';
        } else {
          actionMsg = wasSuspended 
              ? 'Post violation handled - Owner suspended (3 strikes). '
              : 'Post violation handled - Warning issued to owner (Strike $strikeCount/3). ';
        }
        
        if (deductAmount != null && deductAmount > 0) {
          if (deductionResult != null && deductionResult['success'] == true) {
            actionMsg += 'Credits deducted: ${deductAmount.toInt()}.';
          } else {
            actionMsg += 'Credit deduction failed: ${deductionResult?['error'] ?? 'Unknown error'}.';
          }
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
              content: Text(
                postRejected
                    ? 'Post rejected. $userName has reached 3 strikes and has been automatically suspended.'
                    : 'Post violation handled. $userName has reached 3 strikes and has been automatically suspended.',
              ),
              backgroundColor: Colors.orange,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                postRejected
                    ? 'Post rejected. Warning issued to $userName (Strike $strikeCount/3).'
                    : 'Post violation handled. Warning issued to $userName (Strike $strikeCount/3).',
              ),
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
          
        if (widget.report.reportedEmployerId != null && widget.report.reportedEmployerId!.isNotEmpty) {
          await _loadUserInfo(widget.report.reportedEmployerId!);
        } else if (_postModels.containsKey(postId)) {
          final ownerId = _postModels[postId]?.ownerId;
          if (ownerId != null && ownerId.isNotEmpty) {
            await _loadUserInfo(ownerId);
          }
        }
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
        
        try {
          _postModels[postId] = JobPostModel.fromFirestore(postDoc);
        } catch (e) {
          print('Error parsing post model: $e');
        }
        
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
        // Refresh the page
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            Navigator.pop(context, true);
          }
        });
      }
    } catch (e) {
      print('Error auto-resolving report: $e');
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

  String _getPostActionButtonText() {
    if (widget.report.reportType != ReportType.jobPost) return 'Handle Report';
    final postId = widget.report.reportedPostId ?? widget.report.reportedItemId;
    if (postId.isEmpty) return 'Handle Report';
    final status = _postStatus[postId] ?? 'unknown';
    
    if (status == 'completed') {
      return 'Issue Warning to Post Owner';
    } else if (status == 'active' || status == 'approved') {
      return 'Reject Post & Issue Warning';
    } else {
      return 'Handle Post Report';
    }
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

    if (_postModels.containsKey(postId)) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PostDetailPage(post: _postModels[postId]!),
        ),
      );
      return;
    }

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

  String? _getPostOwnerId() {
    if (widget.report.reportType != ReportType.jobPost) return null;
    
    final postId = widget.report.reportedPostId ?? widget.report.reportedItemId;
    if (postId.isEmpty) return null;
    
    if (widget.report.reportedEmployerId != null && 
        widget.report.reportedEmployerId!.isNotEmpty) {
      return widget.report.reportedEmployerId;
    } 
    
    if (_postModels.containsKey(postId)) {
      final ownerId = _postModels[postId]?.ownerId;
      if (ownerId != null && ownerId.isNotEmpty) {
        return ownerId;
      }
    }
    
    return null;
  }

  /// Extract credit deduction amount from actionTaken text
  /// Returns null if no deduction found, or the amount as a string
  String? _getDeductedCreditsFromActionTaken() {
    if (widget.report.actionTaken == null || widget.report.actionTaken!.isEmpty) {
      return null;
    }
    
    final actionTaken = widget.report.actionTaken!;
    
    // Try to find pattern like "Credits deducted: 100" or "Credits deducted: 100."
    final regex = RegExp(r'Credits deducted:\s*(\d+(?:\.\d+)?)');
    final match = regex.firstMatch(actionTaken);
    
    if (match != null && match.groupCount >= 1) {
      final amountStr = match.group(1);
      if (amountStr != null) {
        final amount = double.tryParse(amountStr);
        if (amount != null && amount > 0) {
          return amount.toStringAsFixed(0);
        }
      }
    }
    
    return null;
  }



  @override
  void dispose() {
    _notesController.dispose();
    _violationController.dispose();
    _deductAmountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
            ReportStatusBanner(report: widget.report),
            ReportInformationCard(
              report: widget.report,
              isLoading: _isLoadingInfo,
              getUserDisplay: _getUserDisplay,
              getPostDisplay: _getPostDisplay,
              getPostOwnerId: _getPostOwnerId,
              isPostDeleted: _isPostDeleted,
              isPostRejected: _isPostRejected,
              onViewPostDetails: _viewPostDetails,
              formatDateTime: _formatDateTime,
              getDeductedCreditsFromActionTaken: _getDeductedCreditsFromActionTaken,
            ),
            ReportInternalNotesSection(
              notesController: _notesController,
              isResolved: widget.report.status == ReportStatus.resolved,
            ),
            if (widget.report.status != ReportStatus.resolved) ...[
              const SizedBox(height: 24),
            ],
            ReportActionButtons(
              report: widget.report,
              isProcessing: _isProcessing,
              isLoadingInfo: _isLoadingInfo,
              isPostDeleted: _isPostDeleted,
              isPostRejected: _isPostRejected,
              getPostActionButtonText: _getPostActionButtonText,
              postExists: (postId) => _postExists.containsKey(postId),
              onDismissReport: _dismissReport,
              onHandleUserReport: _showWarningDialog,
              onRejectPost: _showRejectPostDialog,
            ),
            if (widget.report.status == ReportStatus.resolved) ...[
              const ReportResolvedMessage(),
              const SizedBox(height: 24),
            ],
          ],
        ),
      ),
    );
  }

  String _formatDateTime(DateTime date) {
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final day = date.day;
    final month = months[date.month - 1];
    final year = date.year;
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '$day $month $year, $hour:$minute';
  }
}

