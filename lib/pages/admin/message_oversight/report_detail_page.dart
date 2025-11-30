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
          actionMsg += 'Credits deducted: ${deductAmount?.toStringAsFixed(0) ?? '0'}. New balance: ${deductionResult['newBalance']?.toStringAsFixed(0) ?? '0'}.';
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
                              // Show post owner details (always show if available)
                              if (_getPostOwnerId() != null && _getPostOwnerId()!.isNotEmpty) ...[
                                const SizedBox(height: 16),
                                _DetailRow(
                                  label: 'Post Owner', 
                                  value: _getUserDisplay(_getPostOwnerId()!),
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
                            // Show credit deduction if report is resolved and deduction was made
                            if (widget.report.status == ReportStatus.resolved) ...[
                              Builder(
                                builder: (context) {
                                  final deductedCredits = _getDeductedCreditsFromActionTaken();
                                  if (deductedCredits != null) {
                                    return Column(
                                      children: [
                                        const SizedBox(height: 16),
                                        _DetailRow(
                                          label: 'Credit Deducted', 
                                          value: '$deductedCredits credits',
                                          isHighlighted: false,
                                        ),
                                      ],
                                    );
                                  }
                                  return const SizedBox.shrink();
                                },
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

            // Review Notes Section 
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

            // Action Buttons 
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
                      // Post exists and can be handled
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
                            child: Text(
                              _getPostActionButtonText(),
                              style: const TextStyle(
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

