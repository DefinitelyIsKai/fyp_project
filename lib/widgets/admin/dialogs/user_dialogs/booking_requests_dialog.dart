import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../services/user/availability_service.dart';
import '../../../../services/user/application_service.dart';
import '../../../../services/user/auth_service.dart';
import '../../../../services/user/post_service.dart';
import '../../../../services/user/matching_service.dart';
import '../../../../models/user/booking_request.dart';
import '../../../../pages/user/profile/public_profile_page.dart';
import '../../../../utils/user/dialog_utils.dart';

class BookingRequestsDialog extends StatelessWidget {
  final AvailabilityService availabilityService;
  final ApplicationService applicationService;
  final AuthService authService;
  final PostService postService;
  final MatchingService matchingService;

  const BookingRequestsDialog({
    super.key,
    required this.availabilityService,
    required this.applicationService,
    required this.authService,
    required this.postService,
    required this.matchingService,
  });

  Future<void> _approveBookingRequest(BuildContext context, String requestId, String slotId, String matchId) async {
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
      await availabilityService.approveBookingRequest(requestId);

      // Note: scheduleInterview removed - job_matches collection no longer used
      // Booking system now uses Application directly

      if (!context.mounted) return;
      DialogUtils.showSuccessMessage(
        context: context,
        message: 'Booking request approved successfully',
      );
    } catch (e) {
      if (!context.mounted) return;
      DialogUtils.showWarningMessage(
        context: context,
        message: 'Error approving booking request: $e',
      );
    }
  }

  Future<void> _rejectBookingRequest(BuildContext context, String requestId) async {
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
      await availabilityService.rejectBookingRequest(requestId);
      if (!context.mounted) return;
      DialogUtils.showWarningMessage(
        context: context,
        message: 'Booking request rejected',
      );
    } catch (e) {
      if (!context.mounted) return;
      DialogUtils.showWarningMessage(
        context: context,
        message: 'Error rejecting booking request: $e',
      );
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
          maxHeight: MediaQuery.of(context).size.height * 0.8,
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
                      color: const Color(0xFF00C8A0).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.event_available,
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
                          'Booking Requests',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Review and manage booking requests',
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
            ),
            Divider(height: 1, thickness: 1, color: Colors.grey[200]),
            Flexible(
              child: StreamBuilder<List<BookingRequest>>(
                stream: availabilityService.streamBookingRequestsForRecruiter(),
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
                      child: Padding(
                        padding: const EdgeInsets.all(40),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: Colors.red[50],
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.error_outline,
                                size: 48,
                                color: Colors.red[400],
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Error loading requests',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey[700],
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '${snapshot.error}',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  final allRequests = snapshot.data ?? [];
                  final pendingRequests = allRequests
                      .where((req) => req.status == BookingRequestStatus.pending)
                      .toList();

                  if (pendingRequests.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(40),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                color: Colors.grey[50],
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.event_available_outlined,
                                size: 64,
                                color: Colors.grey[400],
                              ),
                            ),
                            const SizedBox(height: 24),
                            Text(
                              'No Pending Requests',
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
                                'All booking requests have been reviewed',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 14,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: pendingRequests.length,
                    itemBuilder: (context, index) {
                      final request = pendingRequests[index];
                      return FutureBuilder<Map<String, dynamic>>(
                        future: _loadBookingRequestData(request),
                        builder: (context, dataSnapshot) {
                          if (!dataSnapshot.hasData) {
                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: Colors.grey[50],
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: Colors.grey[200]!),
                              ),
                              child: const Center(
                                child: CircularProgressIndicator(
                                  color: Color(0xFF00C8A0),
                                ),
                              ),
                            );
                          }

                          final data = dataSnapshot.data ?? {};
                          final jobseekerName = data['jobseekerName'] as String? ?? 'Unknown';
                          final slotDate = data['slotDate'] as DateTime?;
                          final slotTime = data['slotTime'] as String? ?? '';
                          final postTitle = data['postTitle'] as String?;

                          // Get initials for avatar
                          final initials = jobseekerName
                              .split(' ')
                              .where((word) => word.isNotEmpty)
                              .take(2)
                              .map((word) => word[0].toUpperCase())
                              .join();

                          return Container(
                            margin: const EdgeInsets.only(bottom: 16),
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
                              child: Padding(
                                padding: const EdgeInsets.all(20),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Jobseeker Info Row
                                    Row(
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
                                        // Name and Details
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              InkWell(
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
                                                child: Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    Text(
                                                      jobseekerName,
                                                      style: const TextStyle(
                                                        fontSize: 18,
                                                        fontWeight: FontWeight.w700,
                                                        color: Colors.black87,
                                                      ),
                                                    ),
                                                    const SizedBox(width: 6),
                                                    const Icon(
                                                      Icons.open_in_new,
                                                      size: 16,
                                                      color: Color(0xFF00C8A0),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              const SizedBox(height: 8),
                                              // Job Post Title - More Prominent
                                              Container(
                                                padding: const EdgeInsets.symmetric(
                                                  horizontal: 12,
                                                  vertical: 10,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFF00C8A0).withOpacity(0.15),
                                                  borderRadius: BorderRadius.circular(10),
                                                  border: Border.all(
                                                    color: const Color(0xFF00C8A0).withOpacity(0.3),
                                                    width: 1,
                                                  ),
                                                ),
                                                child: Row(
                                                  children: [
                                                    Icon(
                                                      Icons.work_outline,
                                                      size: 18,
                                                      color: const Color(0xFF00C8A0),
                                                    ),
                                                    const SizedBox(width: 10),
                                                    Expanded(
                                                      child: Text(
                                                        postTitle ?? 'Job Post',
                                                        style: TextStyle(
                                                          fontSize: 15,
                                                          fontWeight: FontWeight.w700,
                                                          color: const Color(0xFF00C8A0),
                                                        ),
                                                        maxLines: 2,
                                                        overflow: TextOverflow.ellipsis,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              const SizedBox(height: 12),
                                              // Date and Time Info
                                              if (slotDate != null) ...[
                                                Container(
                                                  padding: const EdgeInsets.symmetric(
                                                    horizontal: 12,
                                                    vertical: 8,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: Colors.grey[50],
                                                    borderRadius: BorderRadius.circular(8),
                                                  ),
                                                  child: Row(
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      Icon(
                                                        Icons.calendar_today,
                                                        size: 16,
                                                        color: Colors.grey[600],
                                                      ),
                                                      const SizedBox(width: 8),
                                                      Text(
                                                        DateFormat('MMM d, yyyy').format(slotDate),
                                                        style: TextStyle(
                                                          fontSize: 14,
                                                          fontWeight: FontWeight.w500,
                                                          color: Colors.grey[700],
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                const SizedBox(height: 8),
                                              ],
                                              Container(
                                                padding: const EdgeInsets.symmetric(
                                                  horizontal: 12,
                                                  vertical: 8,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: Colors.grey[50],
                                                  borderRadius: BorderRadius.circular(8),
                                                ),
                                                child: Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    Icon(
                                                      Icons.access_time,
                                                      size: 16,
                                                      color: Colors.grey[600],
                                                    ),
                                                    const SizedBox(width: 8),
                                                    Text(
                                                      slotTime,
                                                      style: TextStyle(
                                                        fontSize: 14,
                                                        fontWeight: FontWeight.w500,
                                                        color: Colors.grey[700],
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
                                    const SizedBox(height: 20),
                                    // Action Buttons
                                    Row(
                                      children: [
                                        Expanded(
                                          child: OutlinedButton.icon(
                                            onPressed: () {
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
                                            icon: const Icon(Icons.person_outline, size: 18),
                                            label: const Text(
                                              'View Profile',
                                              style: TextStyle(
                                                fontWeight: FontWeight.w600,
                                                fontSize: 14,
                                              ),
                                            ),
                                            style: OutlinedButton.styleFrom(
                                              foregroundColor: const Color(0xFF00C8A0),
                                              side: const BorderSide(
                                                color: Color(0xFF00C8A0),
                                                width: 1.5,
                                              ),
                                              padding: const EdgeInsets.symmetric(
                                                horizontal: 16,
                                                vertical: 12,
                                              ),
                                              shape: RoundedRectangleBorder(
                                                borderRadius: BorderRadius.circular(12),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: OutlinedButton(
                                            onPressed: () {
                                              _rejectBookingRequest(context, request.id);
                                            },
                                            style: OutlinedButton.styleFrom(
                                              foregroundColor: Colors.red[700],
                                              side: BorderSide(
                                                color: Colors.red[300]!,
                                                width: 1.5,
                                              ),
                                              padding: const EdgeInsets.symmetric(
                                                horizontal: 16,
                                                vertical: 12,
                                              ),
                                              shape: RoundedRectangleBorder(
                                                borderRadius: BorderRadius.circular(12),
                                              ),
                                            ),
                                            child: const Text(
                                              'Reject',
                                              style: TextStyle(
                                                fontWeight: FontWeight.w600,
                                                fontSize: 14,
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: ElevatedButton(
                                            onPressed: () {
                                              _approveBookingRequest(
                                                context,
                                                request.id,
                                                request.slotId,
                                                request.matchId,
                                              );
                                            },
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: const Color(0xFF00C8A0),
                                              foregroundColor: Colors.white,
                                              padding: const EdgeInsets.symmetric(
                                                horizontal: 16,
                                                vertical: 12,
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
                                                fontSize: 14,
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

  Future<Map<String, dynamic>> _loadBookingRequestData(BookingRequest request) async {
    try {
      // Load jobseeker data
      final firestore = FirebaseFirestore.instance;
      final userDoc = await firestore.collection('users').doc(request.jobseekerId).get();
      final jobseekerName = userDoc.exists
          ? (userDoc.data()?['fullName'] as String? ?? 'Unknown')
          : 'Unknown';

      // Load slot data
      final slotDoc = await firestore.collection('availability_slots').doc(request.slotId).get();
      DateTime? slotDate;
      String slotTime = '';

      if (slotDoc.exists) {
        final slotData = slotDoc.data()!;
        slotDate = (slotData['date'] as Timestamp?)?.toDate();
        final startTime = slotData['startTime'] as String? ?? '';
        final endTime = slotData['endTime'] as String? ?? '';
        slotTime = '$startTime - $endTime';
      }

      // Load post title from matchId (could be Application ID or JobMatch ID)
      String? postTitle;
      try {
        // Try to get as Application first
        final applicationDoc = await firestore.collection('applications').doc(request.matchId).get();
        if (applicationDoc.exists) {
          final appData = applicationDoc.data();
          final postId = appData?['postId'] as String?;
          if (postId != null) {
            final post = await postService.getById(postId);
            postTitle = post?.title;
          }
        } else {
          // Try to get as JobMatch
          final jobMatchDoc = await firestore.collection('job_matches').doc(request.matchId).get();
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
        debugPrint('Error loading post title for matchId ${request.matchId}: $e');
      }

      return {
        'jobseekerName': jobseekerName,
        'slotDate': slotDate,
        'slotTime': slotTime,
        'postTitle': postTitle,
      };
    } catch (e) {
      debugPrint('Error loading booking request data: $e');
      return {
        'jobseekerName': 'Unknown',
        'slotDate': null,
        'slotTime': '',
        'postTitle': null,
      };
    }
  }
}

