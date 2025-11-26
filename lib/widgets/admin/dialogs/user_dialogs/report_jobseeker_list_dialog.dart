import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../models/user/application.dart';
import '../../../../services/user/application_service.dart';
import '../../../../services/user/report_service.dart';
import '../../../../utils/user/dialog_utils.dart';
import '../../../../utils/user/date_utils.dart' as DateUtilsHelper;
import '../../../../widgets/user/loading_indicator.dart';
import '../../../../widgets/user/empty_state.dart';
import 'report_jobseeker_dialog.dart';

/// Dialog for selecting a jobseeker to report from a list
class ReportJobseekerListDialog extends StatefulWidget {
  final String postId;
  final ReportService reportService;

  const ReportJobseekerListDialog({
    super.key,
    required this.postId,
    required this.reportService,
  });

  @override
  State<ReportJobseekerListDialog> createState() => _ReportJobseekerListDialogState();
}

class _ReportJobseekerListDialogState extends State<ReportJobseekerListDialog> {
  final ApplicationService _applicationService = ApplicationService();
  final Map<String, String> _jobseekerNames = {};
  final Map<String, bool> _hasReportedMap = {};

  Future<void> _ensureName(String userId) async {
    if (_jobseekerNames.containsKey(userId)) return;
    try {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(userId).get();
      _jobseekerNames[userId] = userDoc.data()?['fullName'] as String? ?? 'Unknown';
      if (mounted) setState(() {});
    } catch (_) {
      _jobseekerNames[userId] = 'Unknown';
      if (mounted) setState(() {});
    }
  }

  Future<void> _checkReportedStatus(String jobseekerId) async {
    if (_hasReportedMap.containsKey(jobseekerId)) return;
    try {
      final hasReported = await widget.reportService.hasReportedJobseeker(
        jobseekerId,
        widget.postId,
      );
      _hasReportedMap[jobseekerId] = hasReported;
      if (mounted) setState(() {});
    } catch (_) {
      _hasReportedMap[jobseekerId] = false;
      if (mounted) setState(() {});
    }
  }

  Future<void> _showReportDialog(String jobseekerId, String jobseekerName) async {
    final hasReported = _hasReportedMap[jobseekerId] ?? false;
    
    // Show confirmation dialog first
    final confirmed = await DialogUtils.showConfirmationDialog(
      context: context,
      title: hasReported ? 'Report Again' : 'Report Jobseeker',
      message: hasReported 
        ? 'You have previously reported $jobseekerName. You can submit another report if there are new incidents or concerns. This will create a new report for our moderation team.'
        : 'Are you sure you want to report $jobseekerName? This action will submit a report to our moderation team.',
      icon: Icons.flag_outlined,
      confirmText: 'Continue',
      cancelText: 'Cancel',
      isDestructive: false,
    );

    if (confirmed != true || !mounted) return;

    // Show the report form dialog
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => ReportJobseekerDialog(jobseekerName: jobseekerName),
    );

    if (result != null && result['reason'] != null) {
      try {
        await widget.reportService.reportJobseeker(
          jobseekerId: jobseekerId,
          postId: widget.postId,
          reason: result['reason']!,
          description: result['description'] ?? '',
        );
        if (mounted) {
          setState(() {
            _hasReportedMap[jobseekerId] = true;
          });
          DialogUtils.showSuccessMessage(
            context: context,
            message: 'Report submitted successfully. Thank you for your feedback.',
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

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Container(
        width: double.maxFinite,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header with icon and title
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
                border: Border(
                  bottom: BorderSide(color: Colors.grey[200]!),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.flag_outlined,
                      color: Colors.red,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Select Jobseeker to Report',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: Colors.black,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Choose a jobseeker to submit a report',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.close,
                        color: Colors.black87,
                        size: 20,
                      ),
                    ),
                    onPressed: () => Navigator.pop(context),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
            Expanded(
              child: StreamBuilder<List<Application>>(
                stream: _applicationService.streamPostApplications(widget.postId),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const LoadingIndicator.standard();
                  }
                  final applications = snapshot.data ?? [];
                  if (applications.isEmpty) {
                    return const EmptyState.noApplicants();
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.all(8),
                    itemCount: applications.length,
                    itemBuilder: (context, index) {
                      final app = applications[index];
                      _ensureName(app.jobseekerId);
                      _checkReportedStatus(app.jobseekerId);
                      final jobseekerName = _jobseekerNames[app.jobseekerId] ?? '—';
                      final hasReported = _hasReportedMap[app.jobseekerId] ?? false;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: hasReported 
                                ? Colors.grey[300]! 
                                : Colors.grey[200]!,
                            width: hasReported ? 1.5 : 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.04),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              // Avatar
                              CircleAvatar(
                                radius: 28,
                                backgroundColor: const Color(0xFF00C8A0).withOpacity(0.1),
                                child: Text(
                                  jobseekerName.isNotEmpty 
                                      ? jobseekerName[0].toUpperCase() 
                                      : '?',
                                  style: const TextStyle(
                                    color: Color(0xFF00C8A0),
                                    fontSize: 20,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              // Name and details
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      jobseekerName,
                                      style: const TextStyle(
                                        color: Colors.black,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 16,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 6),
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.access_time,
                                          size: 12,
                                          color: Colors.grey[600],
                                        ),
                                        const SizedBox(width: 4),
                                        Flexible(
                                          child: Text(
                                            'Applied ${DateUtilsHelper.DateUtils.formatTimeAgo(app.createdAt)}',
                                            style: TextStyle(
                                              color: Colors.grey[600],
                                              fontSize: 12,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: _getStatusColor(app.status).withOpacity(0.15),
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
                              const SizedBox(width: 12),
                              // Action buttons
                              Flexible(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    // Reported badge
                                    if (hasReported)
                                      Container(
                                        margin: const EdgeInsets.only(bottom: 8),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF00C8A0).withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(
                                            color: const Color(0xFF00C8A0).withOpacity(0.3),
                                          ),
                                        ),
                                        child: const Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Icons.check_circle,
                                              size: 14,
                                              color: Color(0xFF00C8A0),
                                            ),
                                            SizedBox(width: 4),
                                            Text(
                                              'Reported',
                                              style: TextStyle(
                                                color: Color(0xFF00C8A0),
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    // Report button
                                    ElevatedButton.icon(
                                      onPressed: () => _showReportDialog(
                                        app.jobseekerId,
                                        jobseekerName,
                                      ),
                                      icon: const Icon(
                                        Icons.flag,
                                        size: 16,
                                      ),
                                      label: const Text(
                                        'Report',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.red,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 16,
                                          vertical: 10,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        elevation: 0,
                                        minimumSize: const Size(0, 40),
                                      ),
                                    ),
                                  ],
                                ),
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

