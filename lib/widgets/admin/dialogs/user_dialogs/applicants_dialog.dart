import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../models/user/post.dart';
import '../../../../models/user/application.dart';
import '../../../../models/user/message.dart';
import '../../../../services/user/application_service.dart';
import '../../../../services/user/post_service.dart';
import '../../../../services/user/report_service.dart';
import '../../../../services/user/messaging_service.dart';
import '../../../../utils/user/dialog_utils.dart';
import '../../../../utils/user/date_utils.dart' as DateUtilsHelper;
import '../../../../widgets/user/loading_indicator.dart';
import '../../../../widgets/user/empty_state.dart';
import '../../../../pages/user/profile/public_profile_page.dart';
import '../../../../pages/user/message/messaging_page.dart';
import '../../../../widgets/admin/dialogs/user_dialogs/report_jobseeker_dialog.dart';

class ApplicantsDialog extends StatefulWidget {
  final Post post;
  final ApplicationService applicationService;

  const ApplicantsDialog({
    super.key,
    required this.post,
    required this.applicationService,
  });

  @override
  State<ApplicantsDialog> createState() => _ApplicantsDialogState();
}

class _ApplicantsDialogState extends State<ApplicantsDialog> {
  final Map<String, String> _jobseekerNames = {};
  late final Stream<List<Application>> _appsStream;
  final PostService _postService = PostService();
  final ReportService _reportService = ReportService();

  @override
  void initState() {
    super.initState();
    _appsStream = widget.applicationService.streamPostApplications(
      widget.post.id,
    );
  }

  Future<void> _ensureName(String userId) async {
    if (_jobseekerNames.containsKey(userId)) return;
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();
      _jobseekerNames[userId] =
          userDoc.data()?['fullName'] as String? ?? 'Unknown';
    } catch (_) {
      _jobseekerNames[userId] = 'Unknown';
    }
    
    if (mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {});
        }
      });
    }
  }

  Future<void> _handleApprove(String applicationId) async {
    try {
      await widget.applicationService.approveApplication(applicationId);
      if (mounted) {
        DialogUtils.showSuccessMessage(
          context: context,
          message: 'Application approved. Jobseeker can now message you.',
        );
      }
    } catch (e) {
      if (mounted) {
        final bool quotaExceeded = e.toString().contains('QUOTA_EXCEEDED');
        DialogUtils.showWarningMessage(
          context: context,
          message: quotaExceeded
              ? 'This post has reached its applicant quota. You cannot approve more applicants than the quota limit.'
              : 'Error approving application: $e',
        );
      }
    }
  }

  Future<void> _handleReject(String applicationId) async {
    try {
      await widget.applicationService.rejectApplication(applicationId);
      if (mounted) {
        DialogUtils.showInfoMessage(
          context: context,
          message: 'Application rejected.',
        );
      }
    } catch (e) {
      if (mounted) {
        DialogUtils.showInfoMessage(
          context: context,
          message: 'Error rejecting application: $e',
        );
      }
    }
  }

  Color _getStatusColor(ApplicationStatus status) {
    switch (status) {
      case ApplicationStatus.approved:
        return const Color(0xFF00C8A0);
      case ApplicationStatus.rejected:
        return Colors.red;
      case ApplicationStatus.deleted:
        return Colors.red;
      default:
        return Colors.orange;
    }
  }

  String _getStatusText(ApplicationStatus status) {
    switch (status) {
      case ApplicationStatus.approved:
        return 'Approved';
      case ApplicationStatus.rejected:
        return 'Rejected';
      case ApplicationStatus.deleted:
        return 'Deleted';
      default:
        return 'Pending';
    }
  }

  Future<void> _openJobseekerProfile(String userId) async {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => PublicProfilePage(userId: userId)),
    );
  }

  Future<void> _messageJobseeker(String userId) async {
    try {
      final svc = MessagingService();
      final conversationId = await svc.getOrCreateConversation(
        otherUserId: userId,
      );

      await Future.delayed(const Duration(milliseconds: 200));

      final convoSnap = await FirebaseFirestore.instance
          .collection('conversations')
          .doc(conversationId)
          .get();

      if (!convoSnap.exists) {
        throw Exception('Conversation not found');
      }

      final conversation = Conversation.fromFirestore(convoSnap);
      final otherDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();
      final otherName = otherDoc.data()?['fullName'] as String? ?? 'Unknown';
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              ChatDetailPage(conversation: conversation, otherName: otherName),
        ),
      );
    } catch (e) {
      if (mounted) {
        DialogUtils.showWarningMessage(
          context: context,
          message: 'Could not open chat: ${e.toString()}',
        );
      }
    }
  }

  Future<void> _showReportJobseekerDialog(
    String jobseekerId,
    String jobseekerName,
  ) async {
    
    final hasReported = await _reportService.hasReportedJobseeker(
      jobseekerId,
      widget.post.id,
    );

    if (hasReported) {
      final confirmed = await DialogUtils.showConfirmationDialog(
        context: context,
        title: 'Report Again',
        message: 'You have previously reported $jobseekerName. You can submit another report if there are new incidents or concerns.',
        icon: Icons.flag_outlined,
        confirmText: 'Continue',
        cancelText: 'Cancel',
        isDestructive: false,
      );
      if (confirmed != true || !mounted) return;
    }

    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => ReportJobseekerDialog(jobseekerName: jobseekerName),
    );

    if (result != null && result['reason'] != null) {
      try {
        await _reportService.reportJobseeker(
          jobseekerId: jobseekerId,
          postId: widget.post.id,
          reason: result['reason']!,
          description: result['description'] ?? '',
        );
        if (mounted) {
          DialogUtils.showSuccessMessage(
            context: context,
            message: hasReported
                ? 'Additional report submitted successfully. Thank you for your feedback.'
                : 'Report submitted successfully. Thank you for your feedback.',
          );
        }
      } catch (e) {
        if (mounted) {
          DialogUtils.showWarningMessage(
            context: context,
            message: e.toString().replaceAll('Exception: ', ''),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: double.maxFinite,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.8,
          maxWidth: 500,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Applicants',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: Colors.black,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.post.title,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w400,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  if (widget.post.status != PostStatus.completed)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: TextButton.icon(
                        onPressed: () async {
                          
                          final confirmed = await DialogUtils.showConfirmationDialog(
                            context: context,
                            title: 'Mark as Completed',
                            message: 'Are you sure you want to mark "${widget.post.title}" as completed? This will close the post to new applications.',
                            icon: Icons.flag,
                            confirmText: 'Mark Complete',
                            cancelText: 'Cancel',
                            isDestructive: false,
                          );
                          
                          if (confirmed != true || !mounted) return;
                          
                          try {
                            await _postService.markCompleted(
                              postId: widget.post.id,
                            );
                            if (mounted) {
                              DialogUtils.showSuccessMessage(
                                context: context,
                                message: 'Post marked as completed.',
                              );
                            }
                            Navigator.pop(context);
                          } catch (e) {
                            if (mounted) {
                              DialogUtils.showWarningMessage(
                                context: context,
                                message: 'Failed to mark completed: $e',
                              );
                            }
                          }
                        },
                        icon: const Icon(
                          Icons.flag,
                          size: 18,
                          color: Color(0xFF00C8A0),
                        ),
                        label: const Text(
                          'Completed',
                          style: TextStyle(
                            fontSize: 13,
                            color: Color(0xFF00C8A0),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                    ),
                  IconButton(
                    icon: const Icon(
                      Icons.close,
                      color: Colors.black,
                      size: 22,
                    ),
                    onPressed: () => Navigator.pop(context),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
            Flexible(
              child: StreamBuilder<List<Application>>(
                stream: _appsStream,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const LoadingIndicator.standard(
                      padding: EdgeInsets.all(32.0),
                    );
                  }
                  final apps = snapshot.data ?? const <Application>[];
                  if (apps.isEmpty) {
                    return const EmptyState.noApplicants();
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.all(12),
                    shrinkWrap: true,
                    itemCount: apps.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final app = apps[index];
                      _ensureName(app.jobseekerId);
                      final jobseekerName =
                          _jobseekerNames[app.jobseekerId] ?? '—';
                      return Container(
                        decoration: BoxDecoration(
                          color: Colors.grey[50],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey[200]!),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          onTap: () => _openJobseekerProfile(app.jobseekerId),
                          title: Text(
                            jobseekerName,
                            style: const TextStyle(
                              color: Colors.black,
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    'Applied ${DateUtilsHelper.DateUtils.formatTimeAgo(app.createdAt)}',
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 13,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _getStatusColor(
                                      app.status,
                                    ).withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    _getStatusText(app.status),
                                    style: TextStyle(
                                      color: _getStatusColor(app.status),
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                tooltip: 'Message',
                                icon: const Icon(
                                  Icons.chat_bubble_outline,
                                  size: 18,
                                  color: Color(0xFF00C8A0),
                                ),
                                onPressed: () =>
                                    _messageJobseeker(app.jobseekerId),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                visualDensity: VisualDensity.compact,
                                style: IconButton.styleFrom(
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                              ),
                              const SizedBox(width: 8),
                              FutureBuilder<bool>(
                                future: _reportService.hasReportedJobseeker(
                                  app.jobseekerId,
                                  widget.post.id,
                                ),
                                builder: (context, reportSnapshot) {
                                  return PopupMenuButton<String>(
                                    key: ValueKey(
                                        'popup_${app.jobseekerId}_${app.id}'),
                                    color: Colors.white,
                                    icon: const Icon(
                                      Icons.more_vert,
                                      size: 18,
                                      color: Colors.grey,
                                    ),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                    style: IconButton.styleFrom(
                                      tapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                    ),
                                    onSelected: (value) {
                                      switch (value) {
                                        case 'approve':
                                          _handleApprove(app.id);
                                          break;
                                        case 'reject':
                                          _handleReject(app.id);
                                          break;
                                        
                                        case 'report':
                                          _showReportJobseekerDialog(
                                            app.jobseekerId,
                                            jobseekerName,
                                          );
                                          break;
                                      }
                                    },
                                    itemBuilder: (context) {
                                      final items = <PopupMenuEntry<String>>[];

                                      if (app.status ==
                                          ApplicationStatus.pending) {
                                        items.add(
                                          const PopupMenuItem<String>(
                                            value: 'approve',
                                            child: Row(
                                              children: [
                                                Icon(
                                                  Icons.check_circle,
                                                  size: 20,
                                                  color: Color(0xFF00C8A0),
                                                ),
                                                SizedBox(width: 12),
                                                Text('Approve'),
                                              ],
                                            ),
                                          ),
                                        );
                                        items.add(
                                          const PopupMenuItem<String>(
                                            value: 'reject',
                                            child: Row(
                                              children: [
                                                Icon(
                                                  Icons.cancel,
                                                  size: 20,
                                                  color: Colors.red,
                                                ),
                                                SizedBox(width: 12),
                                                Text('Reject'),
                                              ],
                                            ),
                                          ),
                                        );
                                      }

                                      if (items.isNotEmpty) {
                                        items.add(const PopupMenuDivider());
                                      }

                                      final hasReported = reportSnapshot.data ?? false;
                                      items.add(
                                        PopupMenuItem<String>(
                                          value: 'report',
                                          child: Row(
                                            children: [
                                              Icon(
                                                hasReported 
                                                    ? Icons.flag 
                                                    : Icons.flag_outlined,
                                                size: 20,
                                                color: Colors.red,
                                              ),
                                              const SizedBox(width: 12),
                                              Text(
                                                hasReported 
                                                    ? 'Report Again' 
                                                    : 'Report',
                                                style: TextStyle(
                                                  color: Colors.red,
                                                  fontWeight: hasReported 
                                                      ? FontWeight.w600 
                                                      : FontWeight.normal,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      );

                                      return items;
                                    },
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
