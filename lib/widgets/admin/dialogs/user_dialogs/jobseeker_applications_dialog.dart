import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../services/user/application_service.dart';
import '../../../../services/user/auth_service.dart';
import '../../../../services/user/post_service.dart';
import '../../../../models/user/application.dart';
import '../../../../pages/user/profile/public_profile_page.dart';
import '../../../../utils/user/dialog_utils.dart';

class JobseekerApplicationsDialog extends StatelessWidget {
  final ApplicationService applicationService;
  final AuthService authService;
  final PostService postService;

  const JobseekerApplicationsDialog({
    super.key,
    required this.applicationService,
    required this.authService,
    required this.postService,
  });

  Future<void> _approveApplication(BuildContext context, String applicationId) async {
    final confirmed = await DialogUtils.showConfirmationDialog(
      context: context,
      title: 'Approve Application',
      message: 'Are you sure you want to approve this application? The jobseeker will be notified and can proceed with booking interview slots.',
      icon: Icons.check_circle,
      confirmText: 'Approve',
      cancelText: 'Cancel',
      isDestructive: false,
    );

    if (confirmed != true || !context.mounted) return;

    try {
      await applicationService.approveApplication(applicationId);
      if (!context.mounted) return;
      DialogUtils.showSuccessMessage(
        context: context,
        message: 'Application approved successfully',
      );
    } catch (e) {
      if (!context.mounted) return;
      final bool quotaExceeded = e.toString().contains('QUOTA_EXCEEDED');
      DialogUtils.showWarningMessage(
        context: context,
        message: quotaExceeded
            ? 'This post has reached its applicant quota. You cannot approve more applicants than the quota limit.'
            : 'Error approving application: $e',
      );
    }
  }

  Future<void> _rejectApplication(BuildContext context, String applicationId) async {
    final confirmed = await DialogUtils.showConfirmationDialog(
      context: context,
      title: 'Reject Application',
      message: 'Are you sure you want to reject this application? The jobseeker will be notified.',
      icon: Icons.cancel,
      confirmText: 'Reject',
      cancelText: 'Cancel',
      isDestructive: false,
    );

    if (confirmed != true || !context.mounted) return;

    try {
      await applicationService.rejectApplication(applicationId);
      if (!context.mounted) return;
      DialogUtils.showWarningMessage(
        context: context,
        message: 'Application rejected',
      );
    } catch (e) {
      if (!context.mounted) return;
      DialogUtils.showWarningMessage(
        context: context,
        message: 'Error rejecting application: $e',
      );
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
        return Colors.amber[700]!;
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
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.8,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00C8A0).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.people,
                    color: Color(0xFF00C8A0),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Jobseeker Applications',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Review and manage applications',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.close,
                      size: 20,
                      color: Colors.black54,
                    ),
                  ),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Divider(
              height: 1,
              thickness: 1,
              color: Colors.grey[200],
            ),
            const SizedBox(height: 8),
            Expanded(
              child: StreamBuilder<List<Application>>(
                stream: applicationService.streamRecruiterApplications(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFF00C8A0),
                      ),
                    );
                  }

                  if (snapshot.hasError) {
                    return Center(
                      child: Text('Error: ${snapshot.error}'),
                    );
                  }

                  final allApplications = snapshot.data ?? [];
                  final applications = allApplications
                      .where((app) => app.status == ApplicationStatus.pending)
                      .toList();

                  if (applications.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: const Color(0xFF00C8A0).withOpacity(0.05),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.people_outline,
                              size: 64,
                              color: Colors.grey[400],
                            ),
                          ),
                          const SizedBox(height: 24),
                          Text(
                            'No Pending Applications',
                            style: TextStyle(
                              color: Colors.grey[800],
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 32),
                            child: Text(
                              'All applications have been reviewed',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 14,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: applications.length,
                    itemBuilder: (context, index) {
                      final application = applications[index];
                      return FutureBuilder<Map<String, dynamic>>(
                        future: _loadJobseekerData(application.jobseekerId),
                        builder: (context, jobseekerSnapshot) {
                          final jobseekerData = jobseekerSnapshot.data ?? {};
                          final fullName = jobseekerData['fullName'] as String? ?? 'Unknown';
                          final email = jobseekerData['email'] as String? ?? 'No email';

                          final initials = fullName
                              .split(' ')
                              .where((word) => word.isNotEmpty)
                              .take(2)
                              .map((word) => word[0].toUpperCase())
                              .join();

                          return Container(
                            margin: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.05),
                                  blurRadius: 10,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                children: [
                                  
                                  Container(
                                    width: 56,
                                    height: 56,
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                        colors: [
                                          const Color(0xFF00C8A0),
                                          const Color(0xFF00C8A0).withOpacity(0.8),
                                        ],
                                      ),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Center(
                                      child: Text(
                                        initials.isNotEmpty ? initials : '?',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          fullName,
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w700,
                                            color: Colors.black87,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            Icon(
                                              Icons.email_outlined,
                                              size: 14,
                                              color: Colors.grey[600],
                                            ),
                                            const SizedBox(width: 4),
                                            Expanded(
                                              child: Text(
                                                email,
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  color: Colors.grey[700],
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 5,
                                          ),
                                          decoration: BoxDecoration(
                                            color: _getStatusColor(application.status)
                                                .withOpacity(0.15),
                                            borderRadius: BorderRadius.circular(20),
                                            border: Border.all(
                                              color: _getStatusColor(application.status)
                                                  .withOpacity(0.3),
                                              width: 1,
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Container(
                                                width: 6,
                                                height: 6,
                                                decoration: BoxDecoration(
                                                  color: _getStatusColor(application.status),
                                                  shape: BoxShape.circle,
                                                ),
                                              ),
                                              const SizedBox(width: 6),
                                              Text(
                                                _getStatusText(application.status),
                                                style: TextStyle(
                                                  color: _getStatusColor(application.status),
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w600,
                                                  letterSpacing: 0.5,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  
                                  if (application.status == ApplicationStatus.pending)
                                    Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        SizedBox(
                                          width: 100,
                                          child: ElevatedButton(
                                            onPressed: () {
                                              _approveApplication(context, application.id);
                                            },
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: const Color(0xFF00C8A0),
                                              foregroundColor: Colors.white,
                                              padding: const EdgeInsets.symmetric(
                                                horizontal: 16,
                                                vertical: 10,
                                              ),
                                              shape: RoundedRectangleBorder(
                                                borderRadius: BorderRadius.circular(12),
                                              ),
                                              elevation: 0,
                                            ),
                                            child: const Text(
                                              'Approve',
                                              style: TextStyle(
                                                fontWeight: FontWeight.w600,
                                                fontSize: 13,
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        SizedBox(
                                          width: 100,
                                          child: OutlinedButton(
                                            onPressed: () {
                                              _rejectApplication(context, application.id);
                                            },
                                            style: OutlinedButton.styleFrom(
                                              foregroundColor: Colors.red[700],
                                              side: BorderSide(
                                                color: Colors.red[300]!,
                                                width: 1.5,
                                              ),
                                              padding: const EdgeInsets.symmetric(
                                                horizontal: 16,
                                                vertical: 10,
                                              ),
                                              shape: RoundedRectangleBorder(
                                                borderRadius: BorderRadius.circular(12),
                                              ),
                                            ),
                                            child: const Text(
                                              'Reject',
                                              style: TextStyle(
                                                fontWeight: FontWeight.w600,
                                                fontSize: 13,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    )
                                  else
                                    IconButton(
                                      icon: Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF00C8A0).withOpacity(0.1),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          Icons.visibility_outlined,
                                          color: Color(0xFF00C8A0),
                                          size: 20,
                                        ),
                                      ),
                                      onPressed: () {
                                        Navigator.pop(context);
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) => PublicProfilePage(
                                              userId: application.jobseekerId,
                                            ),
                                          ),
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
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<Map<String, dynamic>> _loadJobseekerData(String jobseekerId) async {
    try {
      final firestore = FirebaseFirestore.instance;
      final userDoc = await firestore.collection('users').doc(jobseekerId).get();

      if (userDoc.exists) {
        final data = userDoc.data() ?? {};
        return {
          'fullName': data['fullName'] as String? ?? 'Unknown',
          'email': data['email'] as String? ?? 'No email',
        };
      }
    } catch (e) {
      debugPrint('Error loading jobseeker data: $e');
    }

    return {
      'fullName': 'Unknown',
      'email': 'No email',
    };
  }
}
