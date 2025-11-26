import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/user/availability_service.dart';
import '../../services/user/auth_service.dart';
import '../../services/user/application_service.dart';
import '../../services/user/post_service.dart';
import '../../models/user/availability_slot.dart';
import '../../models/user/application.dart';
import '../../models/user/post.dart';
import '../../utils/user/dialog_utils.dart';

class JobseekerSlotsList extends StatelessWidget {
  final DateTime selectedDate;
  final String? selectedRecruiterId;
  final Application? selectedApplication;
  final AvailabilityService availabilityService;
  final AuthService authService;
  final ApplicationService applicationService;
  final PostService postService;
  final VoidCallback onBooked;

  const JobseekerSlotsList({
    super.key,
    required this.selectedDate,
    this.selectedRecruiterId,
    this.selectedApplication,
    required this.availabilityService,
    required this.authService,
    required this.applicationService,
    required this.postService,
    required this.onBooked,
  });

  @override
  Widget build(BuildContext context) {
    // Get approved applications
    return FutureBuilder<List<Application>>(
      future: applicationService.streamMyApplications().first,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final applications = snapshot.data ?? [];
        
        // Get approved recruiter IDs from applications
        final approvedApplications = applications.where((app) => app.status == ApplicationStatus.approved).toList();
        
        final approvedRecruiterIdsSet = approvedApplications
            .map((app) => app.recruiterId)
            .toSet();

        // If a specific recruiter is selected, verify they have an approved application
        Set<String> approvedRecruiterIds;
        Application? applicationToUse = selectedApplication;
        if (selectedRecruiterId != null) {
          // Verify the selected recruiter has an approved application
          if (approvedRecruiterIdsSet.contains(selectedRecruiterId!)) {
            approvedRecruiterIds = {selectedRecruiterId!};
          } else {
            // Selected recruiter doesn't have an approved application
            approvedRecruiterIds = {};
          }
        } else {
          // Use all approved recruiters
          approvedRecruiterIds = approvedRecruiterIdsSet;
        }

        if (approvedRecruiterIds.isEmpty) {
          return SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.info_outline, size: 64, color: Colors.grey[300]),
                  const SizedBox(height: 16),
                  Text(
                    'No approved matches',
                    style: TextStyle(color: Colors.grey[600], fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'You need to be approved by a recruiter to book slots',
                    style: TextStyle(color: Colors.grey[500], fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }

        final startOfDay = DateTime(
          selectedDate.year,
          selectedDate.month,
          selectedDate.day,
        );
        final endOfDay = DateTime(
          selectedDate.year,
          selectedDate.month,
          selectedDate.day,
          23,
          59,
          59,
        );

        return StreamBuilder<List<AvailabilitySlot>>(
          stream: availabilityService.streamAvailableSlotsForRecruiters(
            approvedRecruiterIds,
            startDate: startOfDay,
            endDate: endOfDay,
          ),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final slots = snapshot.data ?? [];

            if (slots.isEmpty) {
              return Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.event_busy, size: 64, color: Colors.grey[300]),
                    const SizedBox(height: 16),
                    Text(
                      'No available slots for this date',
                      style: TextStyle(color: Colors.grey[600]),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              );
            }

            // If a specific recruiter is selected, show only their slots
            if (selectedRecruiterId != null) {
              var recruiterSlots = slots
                  .where((slot) => slot.recruiterId == selectedRecruiterId!)
                  .toList();
              
              // Sort slots by start time
              recruiterSlots.sort((a, b) => a.startTime.compareTo(b.startTime));
              
              // If applicationToUse is null but we have an approved application, use it
              if (applicationToUse == null && recruiterSlots.isNotEmpty && approvedApplications.isNotEmpty) {
                try {
                  final approvedApp = approvedApplications.firstWhere(
                    (app) => app.recruiterId == selectedRecruiterId!,
                  );
                  applicationToUse = approvedApp;
                } catch (e) {
                  // Could not find application, will handle gracefully
                }
              }
              
              if (applicationToUse != null) {

              if (recruiterSlots.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.event_busy, size: 64, color: Colors.grey[300]),
                      const SizedBox(height: 16),
                      Text(
                        'No available slots for this date',
                        style: TextStyle(color: Colors.grey[600]),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                );
              }

              // Check which slots should be unavailable (after a booked slot)
              final unavailableSlots = <String>{};
              for (int i = 0; i < recruiterSlots.length; i++) {
                if (recruiterSlots[i].bookedBy != null) {
                  // Mark all subsequent slots as unavailable
                  for (int j = i + 1; j < recruiterSlots.length; j++) {
                    unavailableSlots.add(recruiterSlots[j].id);
                  }
                  break; // Only the first booked slot matters
                }
              }

              // Check for requested slots and post status
              final jobseekerId = authService.currentUserId;
              final application = applicationToUse!; // We know it's not null because of the if check
              final applicationId = application.id; // Get application ID for filtering
              return FutureBuilder<Map<String, dynamic>>(
                future: Future.wait([
                  availabilityService.getRequestedSlotIdsForJobseeker(
                    jobseekerId,
                    matchId: applicationId, // Filter by selected application
                  ),
                  _checkPostStatus(applicationId), // Check if post is completed
                ]).then((results) => {
                  'requestedSlotIds': results[0] as Set<String>,
                  'isPostCompleted': results[1] as bool,
                }),
                builder: (context, dataSnapshot) {
                  final requestedSlotIds = (dataSnapshot.data?['requestedSlotIds'] as Set<String>?) ?? {};
                  final isPostCompleted = (dataSnapshot.data?['isPostCompleted'] as bool?) ?? false;

                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      children: recruiterSlots
                          .where((slot) {
                            // Filter slots: show available slots or booked/requested slots for this application
                            if (slot.isAvailable && slot.bookedBy == null) {
                              return true; // Show all available slots
                            }
                            // Show booked slots only if they match this application
                            if (slot.bookedBy != null) {
                              return slot.matchId == applicationId;
                            }
                            // Show requested slots (they're already filtered by matchId in the service)
                            return true;
                          })
                          .map((slot) {
                        final isUnavailable = unavailableSlots.contains(slot.id);
                        final isBooked = slot.bookedBy != null && slot.matchId == applicationId;
                        final isRequested = requestedSlotIds.contains(slot.id);

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: Colors.grey[300]!,
                              width: 1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Company name at top in lighter grey
                                FutureBuilder<String>(
                                  future: _loadRecruiterName(application.recruiterId),
                                  builder: (context, snapshot) {
                                    return Text(
                                      snapshot.data ?? 'Company',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                        color: Colors.grey[600],
                                      ),
                                    );
                                  },
                                ),
                                const SizedBox(height: 12),
                                // Thin light grey separator
                                Divider(
                                  height: 1,
                                  thickness: 1,
                                  color: Colors.grey[200],
                                ),
                                const SizedBox(height: 12),
                                // Slot content: icon, time, and button
                                Row(
                                  children: [
                                    // Circular clock icon filled with teal
                                    Container(
                                      width: 40,
                                      height: 40,
                                      decoration: BoxDecoration(
                                        color: isBooked
                                            ? Colors.green
                                            : isRequested
                                            ? Colors.amber[700]
                                            : isUnavailable
                                            ? Colors.grey
                                            : const Color(0xFF00C8A0),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        isBooked
                                            ? Icons.check_circle
                                            : isRequested
                                            ? Icons.pending
                                            : isUnavailable
                                            ? Icons.block
                                            : Icons.access_time,
                                        color: Colors.white,
                                        size: 20,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    // Time range text
                                    Expanded(
                                      child: Text(
                                        slot.timeDisplay,
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.black87,
                                        ),
                                      ),
                                    ),
                                    // Request button
                                    if (isRequested)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 16,
                                          vertical: 8,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.grey[300],
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          'Requested',
                                          style: TextStyle(
                                            color: Colors.grey[700],
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      )
                                    else
                                      ElevatedButton(
                                        onPressed: (!isBooked &&
                                            !isUnavailable &&
                                            !isRequested &&
                                            !isPostCompleted)
                                            ? () => _bookSlot(context, slot, application)
                                            : null,
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(0xFF00C8A0),
                                          foregroundColor: Colors.white,
                                          disabledBackgroundColor: Colors.grey[300],
                                          disabledForegroundColor: Colors.grey[600],
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 20,
                                            vertical: 10,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          elevation: 0,
                                        ),
                                        child: const Text(
                                          'Request',
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  );
                },
              );
              } else {
                // No match found but we have slots - show them anyway
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    children: recruiterSlots.map((slot) {
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.grey[300]!,
                            width: 1,
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF00C8A0),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.access_time,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  slot.timeDisplay,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.black87,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                );
              }
            }

            // Group slots by recruiter (for multiple recruiters view)
            final slotsByRecruiter = <String, List<AvailabilitySlot>>{};
            for (final slot in slots) {
              slotsByRecruiter.putIfAbsent(slot.recruiterId, () => []).add(slot);
            }

            // Check for requested slots and post status
            final jobseekerId = authService.currentUserId;
            // Get application ID from selectedApplication if available
            final applicationId = selectedApplication?.id;
            return FutureBuilder<Map<String, dynamic>>(
              future: Future.wait([
                availabilityService.getRequestedSlotIdsForJobseeker(
                  jobseekerId,
                  matchId: applicationId, // Filter by selected application
                ),
                applicationId != null ? _checkPostStatus(applicationId) : Future.value(false),
              ]).then((results) => {
                'requestedSlotIds': results[0] as Set<String>,
                'isPostCompleted': results[1] as bool,
              }),
              builder: (context, dataSnapshot) {
                final requestedSlotIds = (dataSnapshot.data?['requestedSlotIds'] as Set<String>?) ?? {};
                final isPostCompleted = (dataSnapshot.data?['isPostCompleted'] as bool?) ?? false;

                return Column(
                  children: List.generate(slotsByRecruiter.length, (index) {
                    final recruiterId = slotsByRecruiter.keys.elementAt(index);
                    var recruiterSlots = slotsByRecruiter[recruiterId]!;

                    // Sort slots by start time
                    recruiterSlots.sort((a, b) => a.startTime.compareTo(b.startTime));

                    // Use selectedApplication if it matches this recruiter, otherwise skip
                    Application? application;
                    if (selectedApplication != null && selectedApplication!.recruiterId == recruiterId) {
                      application = selectedApplication;
                    } else {
                      // No application available for this recruiter, skip
                      return const SizedBox.shrink();
                    }

                    // Store application in a final variable for null safety (we know it's not null here)
                    final currentApplication = application!;
                    // Get application ID for this specific application
                    final matchApplicationId = currentApplication.id;

                    // Check which slots should be unavailable (after a booked slot)
                    final unavailableSlots = <String>{};
                    for (int i = 0; i < recruiterSlots.length; i++) {
                      if (recruiterSlots[i].bookedBy != null) {
                        // Mark all subsequent slots as unavailable
                        for (int j = i + 1; j < recruiterSlots.length; j++) {
                          unavailableSlots.add(recruiterSlots[j].id);
                        }
                        break; // Only the first booked slot matters
                      }
                    }

                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        children: recruiterSlots
                            .where((slot) {
                              // Filter slots: show available slots or booked/requested slots for this application
                              if (slot.isAvailable && slot.bookedBy == null) {
                                return true; // Show all available slots
                              }
                              // Show booked slots only if they match this application
                              if (slot.bookedBy != null) {
                                return slot.matchId == matchApplicationId;
                              }
                              // Show requested slots (they're already filtered by matchId in the service)
                              return true;
                            })
                            .map((slot) {
                          final isUnavailable = unavailableSlots.contains(slot.id);
                          final isBooked = slot.bookedBy != null && slot.matchId == matchApplicationId;
                          final isRequested = requestedSlotIds.contains(slot.id);

                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: Colors.grey[300]!,
                                width: 1,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.05),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Company name at top in lighter grey
                                  FutureBuilder<String>(
                                    future: _loadRecruiterName(currentApplication.recruiterId),
                                    builder: (context, snapshot) {
                                      return Text(
                                        snapshot.data ?? 'Company',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                          color: Colors.grey[600],
                                        ),
                                      );
                                    },
                                  ),
                                  const SizedBox(height: 12),
                                  // Thin light grey separator
                                  Divider(
                                    height: 1,
                                    thickness: 1,
                                    color: Colors.grey[200],
                                  ),
                                  const SizedBox(height: 12),
                                  // Slot content: icon, time, and button
                                  Row(
                                    children: [
                                      // Circular clock icon filled with teal
                                      Container(
                                        width: 40,
                                        height: 40,
                                        decoration: BoxDecoration(
                                          color: isBooked
                                              ? Colors.green
                                              : isRequested
                                              ? Colors.amber[700]
                                              : isUnavailable
                                              ? Colors.grey
                                              : const Color(0xFF00C8A0),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(
                                          isBooked
                                              ? Icons.check_circle
                                              : isRequested
                                              ? Icons.pending
                                              : isUnavailable
                                              ? Icons.block
                                              : Icons.access_time,
                                          color: Colors.white,
                                          size: 20,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      // Time range text
                                      Expanded(
                                        child: Text(
                                          slot.timeDisplay,
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.black87,
                                          ),
                                        ),
                                      ),
                                      // Request button
                                      if (isRequested)
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 16,
                                            vertical: 8,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.grey[300],
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            'Requested',
                                            style: TextStyle(
                                              color: Colors.grey[700],
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        )
                                      else
                                        ElevatedButton(
                                          onPressed: (!isBooked &&
                                              !isUnavailable &&
                                              !isRequested &&
                                              !isPostCompleted)
                                              ? () => _bookSlot(context, slot, currentApplication)
                                              : null,
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: const Color(0xFF00C8A0),
                                            foregroundColor: Colors.white,
                                            disabledBackgroundColor: Colors.grey[300],
                                            disabledForegroundColor: Colors.grey[600],
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 20,
                                              vertical: 10,
                                            ),
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            elevation: 0,
                                          ),
                                          child: const Text(
                                            'Request',
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    );
                  }),
                );
              },
            );
          },
        );
      },
    );
  }

  // Check if the post associated with matchId is completed
  Future<bool> _checkPostStatus(String matchId) async {
    try {
      final firestore = FirebaseFirestore.instance;
      String? postId;
      
      // Get as Application (matchId is application ID)
      final applicationDoc = await firestore.collection('applications').doc(matchId).get();
      if (applicationDoc.exists) {
        final appData = applicationDoc.data();
        postId = appData?['postId'] as String?;
      }

      // Check post status if postId was found
      if (postId != null) {
        final post = await postService.getById(postId);
        return post?.status == PostStatus.completed;
      }
    } catch (e) {
      debugPrint('Error checking post status: $e');
    }
    return false;
  }

  Future<void> _bookSlot(
      BuildContext context,
      AvailabilitySlot slot,
      Application application,
      ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text('Request Booking'),
        content: FutureBuilder<String>(
          future: _loadJobTitle(application.postId),
          builder: (context, snapshot) {
            final jobTitle = snapshot.data ?? 'this job';
            return Text(
              'Send booking request for interview slot on ${DateFormat('MMMM d, yyyy').format(slot.date)} '
                  'at ${slot.timeDisplay} for $jobTitle?\n\n'
                  'The recruiter will review and approve your request.',
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.black),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00C8A0),
              foregroundColor: Colors.white,
            ),
            child: const Text('Send Request'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final jobseekerId = authService.currentUserId;
        await availabilityService.createBookingRequest(
          slotId: slot.id,
          matchId: application.id,
          jobseekerId: jobseekerId,
          recruiterId: slot.recruiterId,
        );

        if (context.mounted) {
          DialogUtils.showSuccessMessage(
            context: context,
            message: 'Booking request sent successfully! Waiting for recruiter approval.',
          );
          onBooked();
        }
      } catch (e) {
        if (context.mounted) {
          DialogUtils.showWarningMessage(
            context: context,
            message: 'Failed to send booking request: $e',
          );
        }
      }
    }
  }

  /// Load recruiter name from Firestore
  Future<String> _loadRecruiterName(String recruiterId) async {
    try {
      final firestore = FirebaseFirestore.instance;
      final userDoc = await firestore.collection('users').doc(recruiterId).get();
      if (userDoc.exists) {
        final data = userDoc.data() ?? {};
        return (data['fullName'] as String?) ??
            (data['professionalProfile'] as String?) ??
            'Company';
      }
    } catch (e) {
      debugPrint('Error loading recruiter name: $e');
    }
    return 'Company';
  }

  /// Load job title from post
  Future<String> _loadJobTitle(String postId) async {
    try {
      final post = await postService.getById(postId);
      return post?.title ?? 'this job';
    } catch (e) {
      debugPrint('Error loading job title: $e');
    }
    return 'this job';
  }
}



