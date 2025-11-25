import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../services/user/availability_service.dart';
import '../../../../services/user/application_service.dart';
import '../../../../services/user/auth_service.dart';
import '../../../../services/user/post_service.dart';
import '../../../../models/user/availability_slot.dart';
import '../../../../models/user/booking_request.dart';
import '../../../../pages/user/profile/public_profile_page.dart';
import '../../../../utils/user/dialog_utils.dart';

class PendingRequestDialog extends StatelessWidget {
  final AvailabilitySlot slot;
  final List<BookingRequest> requests;
  final AvailabilityService availabilityService;
  final ApplicationService applicationService;
  final AuthService authService;
  final PostService postService;

  const PendingRequestDialog({
    super.key,
    required this.slot,
    required this.requests,
    required this.availabilityService,
    required this.applicationService,
    required this.authService,
    required this.postService,
  });

  Future<void> _approveBookingRequest(BuildContext context, BookingRequest request) async {
    final confirmed = await DialogUtils.showConfirmationDialog(
      context: context,
      title: 'Approve Booking Request',
      message: 'Are you sure you want to approve this booking request? This will confirm the interview slot and notify the jobseeker.',
      icon: Icons.check_circle,
      confirmText: 'Approve',
      cancelText: 'Cancel',
      isDestructive: false,
    );

    if (confirmed != true || !context.mounted) return;

    try {
      await availabilityService.approveBookingRequest(request.id);
      if (!context.mounted) return;
      Navigator.pop(context); // Close the pending request dialog
      DialogUtils.showSuccessMessage(
        context: context,
        message: 'Booking request approved successfully',
      );
    } catch (e) {
      if (!context.mounted) return;
      DialogUtils.showWarningMessage(
        context: context,
        message: 'Error approving request: $e',
      );
    }
  }

  Future<void> _rejectBookingRequest(BuildContext context, BookingRequest request) async {
    final confirmed = await DialogUtils.showConfirmationDialog(
      context: context,
      title: 'Reject Booking Request',
      message: 'Are you sure you want to reject this booking request? The jobseeker will be notified.',
      icon: Icons.cancel,
      confirmText: 'Reject',
      cancelText: 'Cancel',
      isDestructive: false,
    );

    if (confirmed != true || !context.mounted) return;

    try {
      await availabilityService.rejectBookingRequest(request.id);
      if (!context.mounted) return;
      Navigator.pop(context); // Close the pending request dialog
      DialogUtils.showWarningMessage(
        context: context,
        message: 'Booking request rejected',
      );
    } catch (e) {
      if (!context.mounted) return;
      DialogUtils.showWarningMessage(
        context: context,
        message: 'Error rejecting request: $e',
      );
    }
  }

  Future<Map<String, dynamic>> _loadJobseekerData(String jobseekerId, String matchId) async {
    try {
      final firestore = FirebaseFirestore.instance;
      final userDoc = await firestore.collection('users').doc(jobseekerId).get();
      String? fullName;
      String? email;
      
      if (userDoc.exists) {
        final data = userDoc.data() ?? {};
        fullName = data['fullName'] as String? ?? 'Unknown';
        email = data['email'] as String? ?? 'No email';
      } else {
        fullName = 'Unknown';
        email = 'No email';
      }

      // Load post title from matchId (could be Application ID or JobMatch ID)
      String? postTitle;
      try {
        // Try to get as Application first
        final applicationDoc = await firestore.collection('applications').doc(matchId).get();
        if (applicationDoc.exists) {
          final appData = applicationDoc.data();
          final postId = appData?['postId'] as String?;
          if (postId != null) {
            final post = await postService.getById(postId);
            postTitle = post?.title;
          }
        } else {
          // Try to get as JobMatch
          final jobMatchDoc = await firestore.collection('job_matches').doc(matchId).get();
          if (jobMatchDoc.exists) {
            final matchData = jobMatchDoc.data();
            // JobMatch has jobTitle directly, but we can also get from post
            final jobTitle = matchData?['jobTitle'] as String?;
            if (jobTitle != null && jobTitle.isNotEmpty) {
              postTitle = jobTitle;
            } else {
              // Fallback: get from post
              final jobId = matchData?['jobId'] as String?;
              if (jobId != null) {
                final post = await postService.getById(jobId);
                postTitle = post?.title;
              }
            }
          }
        }
      } catch (e) {
        debugPrint('Error loading post title for matchId $matchId: $e');
      }

      return {
        'fullName': fullName,
        'email': email,
        'postTitle': postTitle,
      };
    } catch (e) {
      debugPrint('Error loading jobseeker data: $e');
      return {
        'fullName': 'Unknown',
        'email': 'No email',
        'postTitle': null,
      };
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.75,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.amber.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.pending_actions,
                      color: Colors.amber[700],
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Pending Booking Requests',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          slot.timeDisplay,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[600],
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
            ),
            Divider(height: 1, thickness: 1, color: Colors.grey[200]),
            // Content
            Flexible(
              child: requests.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(40),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: Colors.grey[50],
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.inbox_outlined,
                                size: 48,
                                color: Colors.grey[400],
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No Pending Requests',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey[700],
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'There are no pending booking requests for this time slot.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      shrinkWrap: true,
                      itemCount: requests.length,
                      itemBuilder: (context, index) {
                        final request = requests[index];
                        return FutureBuilder<Map<String, dynamic>>(
                          future: _loadJobseekerData(request.jobseekerId, request.matchId),
                          builder: (context, snapshot) {
                            final jobseekerData = snapshot.data ?? {};
                            final fullName = jobseekerData['fullName'] as String? ?? 'Unknown';
                            final email = jobseekerData['email'] as String? ?? 'No email';
                            final postTitle = jobseekerData['postTitle'] as String?;

                            // Get initials for avatar
                            final initials = fullName
                                .split(' ')
                                .where((word) => word.isNotEmpty)
                                .take(2)
                                .map((word) => word[0].toUpperCase())
                                .join();

                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: Colors.grey[200]!),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.03),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(16),
                                  onTap: () {
                                    Navigator.pop(context);
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => PublicProfilePage(
                                          userId: request.jobseekerId,
                                        ),
                                      ),
                                    );
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Row(
                                      children: [
                                        // Avatar
                                        Container(
                                          width: 56,
                                          height: 56,
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              begin: Alignment.topLeft,
                                              end: Alignment.bottomRight,
                                              colors: [
                                                const Color(0xFF00C8A0).withOpacity(0.8),
                                                const Color(0xFF00C8A0),
                                              ],
                                            ),
                                            shape: BoxShape.circle,
                                            boxShadow: [
                                              BoxShadow(
                                                color: const Color(0xFF00C8A0).withOpacity(0.3),
                                                blurRadius: 8,
                                                offset: const Offset(0, 2),
                                              ),
                                            ],
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
                                        // Name, Post Title, and Email
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
                                              const SizedBox(height: 8),
                                              // Job Post Title
                                              Container(
                                                padding: const EdgeInsets.symmetric(
                                                  horizontal: 10,
                                                  vertical: 6,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFF00C8A0).withOpacity(0.15),
                                                  borderRadius: BorderRadius.circular(8),
                                                  border: Border.all(
                                                    color: const Color(0xFF00C8A0).withOpacity(0.3),
                                                    width: 1,
                                                  ),
                                                ),
                                                child: Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    Icon(
                                                      Icons.work_outline,
                                                      size: 14,
                                                      color: const Color(0xFF00C8A0),
                                                    ),
                                                    const SizedBox(width: 6),
                                                    Flexible(
                                                      child: Text(
                                                        postTitle ?? 'Job Post',
                                                        style: TextStyle(
                                                          fontSize: 13,
                                                          fontWeight: FontWeight.w700,
                                                          color: const Color(0xFF00C8A0),
                                                        ),
                                                        maxLines: 1,
                                                        overflow: TextOverflow.ellipsis,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              const SizedBox(height: 6),
                                              Row(
                                                children: [
                                                  Icon(
                                                    Icons.email_outlined,
                                                    size: 14,
                                                    color: Colors.grey[600],
                                                  ),
                                                  const SizedBox(width: 6),
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
                                            ],
                                          ),
                                        ),
                                        // Action Menu
                                        PopupMenuButton<String>(
                                          color: Colors.white,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          icon: Container(
                                            padding: const EdgeInsets.all(8),
                                            decoration: BoxDecoration(
                                              color: Colors.grey[50],
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Icon(
                                              Icons.more_vert,
                                              color: Colors.grey[700],
                                              size: 20,
                                            ),
                                          ),
                                          onSelected: (value) {
                                            if (value == 'view') {
                                              Navigator.pop(context);
                                              Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (context) => PublicProfilePage(
                                                    userId: request.jobseekerId,
                                                  ),
                                                ),
                                              );
                                            } else if (value == 'approve') {
                                              _approveBookingRequest(context, request);
                                            } else if (value == 'reject') {
                                              _rejectBookingRequest(context, request);
                                            }
                                          },
                                          itemBuilder: (context) => [
                                            PopupMenuItem(
                                              value: 'view',
                                              child: Row(
                                                children: [
                                                  Container(
                                                    padding: const EdgeInsets.all(6),
                                                    decoration: BoxDecoration(
                                                      color: const Color(0xFF00C8A0).withOpacity(0.1),
                                                      borderRadius: BorderRadius.circular(6),
                                                    ),
                                                    child: const Icon(
                                                      Icons.person_outline,
                                                      size: 18,
                                                      color: Color(0xFF00C8A0),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 12),
                                                  const Text(
                                                    'View Profile',
                                                    style: TextStyle(
                                                      fontSize: 14,
                                                      fontWeight: FontWeight.w500,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            PopupMenuItem(
                                              value: 'approve',
                                              child: Row(
                                                children: [
                                                  Container(
                                                    padding: const EdgeInsets.all(6),
                                                    decoration: BoxDecoration(
                                                      color: Colors.green.withOpacity(0.1),
                                                      borderRadius: BorderRadius.circular(6),
                                                    ),
                                                    child: const Icon(
                                                      Icons.check_circle,
                                                      size: 18,
                                                      color: Colors.green,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 12),
                                                  const Text(
                                                    'Approve',
                                                    style: TextStyle(
                                                      fontSize: 14,
                                                      fontWeight: FontWeight.w500,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            PopupMenuItem(
                                              value: 'reject',
                                              child: Row(
                                                children: [
                                                  Container(
                                                    padding: const EdgeInsets.all(6),
                                                    decoration: BoxDecoration(
                                                      color: Colors.red.withOpacity(0.1),
                                                      borderRadius: BorderRadius.circular(6),
                                                    ),
                                                    child: const Icon(
                                                      Icons.cancel,
                                                      size: 18,
                                                      color: Colors.red,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 12),
                                                  const Text(
                                                    'Reject',
                                                    style: TextStyle(
                                                      fontSize: 14,
                                                      fontWeight: FontWeight.w500,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
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

