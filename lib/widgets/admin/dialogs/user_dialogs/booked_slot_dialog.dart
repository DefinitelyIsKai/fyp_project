import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../../../services/user/availability_service.dart';
import '../../../../services/user/application_service.dart';
import '../../../../services/user/auth_service.dart';
import '../../../../services/user/post_service.dart';
import '../../../../models/user/availability_slot.dart';
import '../../../../pages/user/profile/public_profile_page.dart';

class BookedSlotDialog extends StatelessWidget {
  final AvailabilitySlot slot;
  final AvailabilityService availabilityService;
  final ApplicationService applicationService;
  final AuthService authService;
  final PostService postService;

  const BookedSlotDialog({
    super.key,
    required this.slot,
    required this.availabilityService,
    required this.applicationService,
    required this.authService,
    required this.postService,
  });

  Future<Map<String, dynamic>> _loadBookedSlotData() async {
    try {
      final firestore = FirebaseFirestore.instance;
      final jobseekerId = slot.bookedBy;
      final matchId = slot.matchId;

      if (jobseekerId == null) {
        return {
          'jobseekerName': 'Unknown',
          'email': 'No email',
          'postTitle': null,
        };
      }

      // Load jobseeker data
      final userDoc = await firestore.collection('users').doc(jobseekerId).get();
      final jobseekerName = userDoc.exists
          ? (userDoc.data()?['fullName'] as String? ?? 'Unknown')
          : 'Unknown';
      final email = userDoc.data()?['email'] as String? ?? 'No email';

      // Load post title from matchId (could be Application ID or JobMatch ID)
      String? postTitle;
      if (matchId != null) {
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
      }

      return {
        'jobseekerName': jobseekerName,
        'email': email,
        'postTitle': postTitle,
      };
    } catch (e) {
      debugPrint('Error loading booked slot data: $e');
      return {
        'jobseekerName': 'Unknown',
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
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Booked Slot Details',
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
              child: FutureBuilder<Map<String, dynamic>>(
                future: _loadBookedSlotData(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Padding(
                      padding: EdgeInsets.all(40),
                      child: Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFF00C8A0),
                        ),
                      ),
                    );
                  }

                  final data = snapshot.data ?? {};
                  final jobseekerName = data['jobseekerName'] as String? ?? 'Unknown';
                  final email = data['email'] as String? ?? 'No email';
                  final postTitle = data['postTitle'] as String?;

                  // Get initials for avatar
                  final initials = jobseekerName
                      .split(' ')
                      .where((word) => word.isNotEmpty)
                      .take(2)
                      .map((word) => word[0].toUpperCase())
                      .join();

                  return SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Jobseeker Info Card
                        Container(
                          padding: const EdgeInsets.all(20),
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
                          child: Column(
                            children: [
                              // Avatar and Name
                              Row(
                                children: [
                                  Container(
                                    width: 64,
                                    height: 64,
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
                                          fontSize: 24,
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
                                        InkWell(
                                          onTap: () {
                                            Navigator.pop(context);
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (context) => PublicProfilePage(
                                                  userId: slot.bookedBy!,
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
                                                  fontSize: 20,
                                                  fontWeight: FontWeight.w700,
                                                  color: Colors.black87,
                                                ),
                                              ),
                                              const SizedBox(width: 6),
                                              const Icon(
                                                Icons.open_in_new,
                                                size: 18,
                                                color: Color(0xFF00C8A0),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Row(
                                          children: [
                                            Icon(
                                              Icons.email_outlined,
                                              size: 16,
                                              color: Colors.grey[600],
                                            ),
                                            const SizedBox(width: 6),
                                            Expanded(
                                              child: Text(
                                                email,
                                                style: TextStyle(
                                                  fontSize: 14,
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
                                ],
                              ),
                              const SizedBox(height: 20),
                              // Job Post Title
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
                                    const Icon(
                                      Icons.work_outline,
                                      size: 18,
                                      color: Color(0xFF00C8A0),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        postTitle ?? 'Job Post',
                                        style: const TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF00C8A0),
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        // Booking Information
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.grey[50],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Booking Information',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Icon(
                                    Icons.calendar_today,
                                    size: 18,
                                    color: Colors.grey[600],
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    DateFormat('MMMM d, yyyy').format(slot.date),
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.grey[700],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Icon(
                                    Icons.access_time,
                                    size: 18,
                                    color: Colors.grey[600],
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    slot.timeDisplay,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.grey[700],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Icon(
                                    Icons.check_circle,
                                    size: 18,
                                    color: Colors.green[600],
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    'Confirmed',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.green[700],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        // Action Button
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: () {
                              Navigator.pop(context);
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => PublicProfilePage(
                                    userId: slot.bookedBy!,
                                  ),
                                ),
                              );
                            },
                            icon: const Icon(Icons.person_outline, size: 18),
                            label: const Text(
                              'View Jobseeker Profile',
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

