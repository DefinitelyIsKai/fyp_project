import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../../models/user/availability_slot.dart';
import '../../models/user/booking_request.dart';
import 'auth_service.dart';
import 'notification_service.dart';

class AvailabilityService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AuthService _authService = AuthService();
  final NotificationService _notificationService = NotificationService();

  // Get availability slots for recruiter
  Stream<List<AvailabilitySlot>> streamAvailabilitySlots({
    DateTime? startDate,
    DateTime? endDate,
  }) async* {
    final userId = _authService.currentUserId;

    // Query only by recruiterId to avoid composite index requirement
    // Filter by date in memory instead
    yield* _firestore
        .collection('availability_slots')
        .where('recruiterId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) {
          final slots = snapshot.docs
              .map((doc) => AvailabilitySlot.fromFirestore(doc))
              .toList();

          // Filter by date range in memory
          final filteredSlots = slots.where((slot) {
            if (startDate != null && slot.date.isBefore(startDate)) {
              return false;
            }
            if (endDate != null && slot.date.isAfter(endDate)) {
              return false;
            }
            return true;
          }).toList();

          // Sort by date first, then by time
          filteredSlots.sort((a, b) {
            final dateCompare = a.date.compareTo(b.date);
            if (dateCompare != 0) return dateCompare;
            return a.startTime.compareTo(b.startTime);
          });
          return filteredSlots;
        });
  }

  // Get availability slots for a specific date
  Future<List<AvailabilitySlot>> getAvailabilitySlotsForDate(
    DateTime date,
  ) async {
    final userId = _authService.currentUserId;
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59);

    // Query only by recruiterId to avoid composite index requirement
    // Filter by date in memory instead
    final snapshot = await _firestore
        .collection('availability_slots')
        .where('recruiterId', isEqualTo: userId)
        .get();

    final slots = snapshot.docs
        .map((doc) => AvailabilitySlot.fromFirestore(doc))
        .where((slot) {
          // Filter by date range in memory
          return slot.date.isAfter(
                startOfDay.subtract(const Duration(seconds: 1)),
              ) &&
              slot.date.isBefore(endOfDay.add(const Duration(seconds: 1)));
        })
        .toList();
    // Sort by startTime in memory
    slots.sort((a, b) => a.startTime.compareTo(b.startTime));
    return slots;
  }

  // Create availability slot
  Future<String> createAvailabilitySlot({
    required DateTime date,
    required String startTime,
    required String endTime,
    bool isRecurring = false,
    String? recurringPattern,
  }) async {
    final userId = _authService.currentUserId;

    final slot = AvailabilitySlot(
      id: '',
      recruiterId: userId,
      date: date,
      startTime: startTime,
      endTime: endTime,
      isAvailable: true,
      createdAt: DateTime.now(),
      isRecurring: isRecurring,
      recurringPattern: recurringPattern,
    );

    final docRef = await _firestore
        .collection('availability_slots')
        .add(slot.toFirestore());
    return docRef.id;
  }

  // Toggle availability slot
  Future<void> toggleAvailabilitySlot(String slotId, bool isAvailable) async {
    await _firestore.collection('availability_slots').doc(slotId).update({
      'isAvailable': isAvailable,
    });
  }

  // Book a slot (INTERNAL USE ONLY - called by approveBookingRequest)
  // Jobseekers should use createBookingRequest instead, which creates a pending request
  Future<void> bookSlot({
    required String slotId,
    required String matchId,
    required String jobseekerId,
  }) async {
    await _firestore.collection('availability_slots').doc(slotId).update({
      'isAvailable': false,
      'bookedBy': jobseekerId,
      'matchId': matchId,
    });
  }

  // Delete availability slot
  Future<void> deleteAvailabilitySlot(String slotId) async {
    // Get slot details before deletion for notifications
    final slotDoc = await _firestore.collection('availability_slots').doc(slotId).get();
    if (!slotDoc.exists) {
      throw Exception('Slot not found');
    }

    final slot = AvailabilitySlot.fromFirestore(slotDoc);
    final slotTimeDisplay = _formatSlotTimeDisplay(slot);
    final recruiterId = slot.recruiterId;
    final bookedBy = slot.bookedBy;

    // Get all pending booking requests for this slot
    final pendingRequests = await _firestore
        .collection('booking_requests')
        .where('slotId', isEqualTo: slotId)
        .where('status', isEqualTo: 'pending')
        .get();

    final requestingJobseekerIds = pendingRequests.docs
        .map((doc) => BookingRequest.fromFirestore(doc).jobseekerId)
        .toList();

    // Delete the slot
    await _firestore.collection('availability_slots').doc(slotId).delete();

    // Send notifications asynchronously (don't block on these)
    _sendSlotDeletionNotifications(
      recruiterId: recruiterId,
      bookedBy: bookedBy,
      requestingJobseekerIds: requestingJobseekerIds,
      slotTimeDisplay: slotTimeDisplay,
    ).catchError((e) {
      // Log error but don't fail the deletion
      debugPrint('Error sending slot deletion notifications: $e');
    });
  }

  // Helper method to send slot deletion notifications
  Future<void> _sendSlotDeletionNotifications({
    required String recruiterId,
    String? bookedBy,
    required List<String> requestingJobseekerIds,
    required String slotTimeDisplay,
  }) async {
    final recruiterName = await _getUserName(recruiterId);
    final hasBookedJobseeker = bookedBy != null && bookedBy.isNotEmpty;
    final pendingRequestsCount = requestingJobseekerIds.length;

    // Notify jobseekers who have pending requests
    if (requestingJobseekerIds.isNotEmpty) {
      await _notificationService.notifySlotDeletedToRequestingJobseekers(
        jobseekerIds: requestingJobseekerIds,
        recruiterName: recruiterName,
        slotTimeDisplay: slotTimeDisplay,
      );
    }

    // Notify jobseeker who has booked the slot
    if (bookedBy != null && bookedBy.isNotEmpty) {
      await _notificationService.notifySlotDeletedToBookedJobseeker(
        jobseekerId: bookedBy,
        recruiterName: recruiterName,
        slotTimeDisplay: slotTimeDisplay,
      );
    }

    // Notify recruiter about the deletion
    await _notificationService.notifySlotDeletedToRecruiter(
      recruiterId: recruiterId,
      slotTimeDisplay: slotTimeDisplay,
      pendingRequestsCount: pendingRequestsCount,
      hasBookedJobseeker: hasBookedJobseeker,
    );
  }

  // Get available slots for booking (for jobseekers)
  Stream<List<AvailabilitySlot>> streamAvailableSlotsForRecruiter(
    String recruiterId,
  ) async* {
    // Query only by recruiterId and isAvailable to avoid composite index requirement
    // Filter by date in memory instead
    final now = DateTime.now();
    yield* _firestore
        .collection('availability_slots')
        .where('recruiterId', isEqualTo: recruiterId)
        .where('isAvailable', isEqualTo: true)
        .snapshots()
        .map((snapshot) {
          final slots = snapshot.docs
              .map((doc) => AvailabilitySlot.fromFirestore(doc))
              .where((slot) => slot.date.isAfter(now.subtract(const Duration(seconds: 1))))
              .toList();
          // Sort by date first, then by time
          slots.sort((a, b) {
            final dateCompare = a.date.compareTo(b.date);
            if (dateCompare != 0) return dateCompare;
            return a.startTime.compareTo(b.startTime);
          });
          return slots;
        });
  }

  // Get available slots for multiple recruiters (for jobseekers with approved matches)
  Stream<List<AvailabilitySlot>> streamAvailableSlotsForRecruiters(
    Set<String> recruiterIds, {
    DateTime? startDate,
    DateTime? endDate,
  }) async* {
    if (recruiterIds.isEmpty) {
      yield* Stream.value([]);
      return;
    }

    // Fetch slots for all recruiters and combine
    final now = DateTime.now();
    final start = startDate ?? now;
    final end = endDate ?? DateTime(now.year, now.month + 1, 0);

    // Query only by isAvailable to avoid composite index requirement
    // Filter by date and recruiterId in memory instead
    yield* _firestore
        .collection('availability_slots')
        .where('isAvailable', isEqualTo: true)
        .snapshots()
        .map((snapshot) {
          final allSlots = snapshot.docs.map((doc) {
            try {
              return AvailabilitySlot.fromFirestore(doc);
            } catch (e) {
              debugPrint('AvailabilityService: Error parsing slot ${doc.id}: $e');
              return null;
            }
          }).whereType<AvailabilitySlot>().toList();
          
          final slots = allSlots.where((slot) {
            // Filter by recruiterId
            if (!recruiterIds.contains(slot.recruiterId)) {
              return false;
            }
            // Filter by date range
            final slotDateOnly = DateTime(slot.date.year, slot.date.month, slot.date.day);
            final startDateOnly = DateTime(start.year, start.month, start.day);
            final endDateOnly = DateTime(end.year, end.month, end.day);
            
            if (slotDateOnly.isBefore(startDateOnly)) {
              return false;
            }
            if (slotDateOnly.isAfter(endDateOnly)) {
              return false;
            }
            return true;
          }).toList();
          
          // Sort by date first, then by time
          slots.sort((a, b) {
            final dateCompare = a.date.compareTo(b.date);
            if (dateCompare != 0) return dateCompare;
            return a.startTime.compareTo(b.startTime);
          });
          return slots;
        });
  }

  // Get dates with available slots for calendar display
  Future<Set<DateTime>> getAvailableDatesForRecruiters(
    Set<String> recruiterIds, {
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    if (recruiterIds.isEmpty) return {};

    final now = DateTime.now();
    final start = startDate ?? now;
    final end = endDate ?? DateTime(now.year, now.month + 1, 0);

    // Query only by isAvailable to avoid composite index requirement
    // Filter by date and recruiterId in memory instead
    final snapshot = await _firestore
        .collection('availability_slots')
        .where('isAvailable', isEqualTo: true)
        .get();

    final dates = <DateTime>{};
    for (final doc in snapshot.docs) {
      final slot = AvailabilitySlot.fromFirestore(doc);
      // Filter by recruiterId
      if (!recruiterIds.contains(slot.recruiterId)) continue;
      // Filter by date range
      if (slot.date.isBefore(start) || slot.date.isAfter(end)) continue;
      dates.add(DateTime(slot.date.year, slot.date.month, slot.date.day));
    }
    return dates;
  }

  // Get booked dates for calendar display
  Future<Set<DateTime>> getBookedDatesForJobseeker(
    String jobseekerId, {
    DateTime? startDate,
    DateTime? endDate,
    String? matchId, // Filter by specific application/match ID
  }) async {
    final now = DateTime.now();
    final start = startDate ?? now;
    final end = endDate ?? DateTime(now.year, now.month + 1, 0);

    // Query only by bookedBy to avoid composite index requirement
    // Filter by date and matchId in memory instead
    final snapshot = await _firestore
        .collection('availability_slots')
        .where('bookedBy', isEqualTo: jobseekerId)
        .get();

    final dates = <DateTime>{};
    for (final doc in snapshot.docs) {
      final slot = AvailabilitySlot.fromFirestore(doc);
      // Filter by matchId if provided
      if (matchId != null && slot.matchId != matchId) continue;
      // Filter by date range in memory
      if (slot.date.isBefore(start) || slot.date.isAfter(end)) continue;
      dates.add(DateTime(slot.date.year, slot.date.month, slot.date.day));
    }
    return dates;
  }

  // ========== Booking Request Functions ==========

  // Helper method to get user name from Firestore
  Future<String> _getUserName(String userId) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (userDoc.exists) {
        final data = userDoc.data();
        return data?['professionalProfile'] as String? ??
               data?['fullName'] as String? ?? 
               'Unknown';
      }
    } catch (e) {
      // Ignore errors and return default
    }
    return 'Unknown';
  }

  // Helper method to format slot time display
  String _formatSlotTimeDisplay(AvailabilitySlot slot) {
    final dateStr = '${slot.date.year}-${slot.date.month.toString().padLeft(2, '0')}-${slot.date.day.toString().padLeft(2, '0')}';
    return '$dateStr ${slot.timeDisplay}';
  }

  // Create a booking request (jobseeker sends request to recruiter)
  Future<String> createBookingRequest({
    required String slotId,
    required String matchId,
    required String jobseekerId,
    required String recruiterId,
  }) async {
    // Check if slot already has a pending request from this jobseeker
    final existingRequest = await _firestore
        .collection('booking_requests')
        .where('slotId', isEqualTo: slotId)
        .where('jobseekerId', isEqualTo: jobseekerId)
        .where('status', isEqualTo: 'pending')
        .limit(1)
        .get();

    if (existingRequest.docs.isNotEmpty) {
      throw Exception('You already have a pending request for this slot');
    }

    // Check if slot is already booked
    final slotDoc = await _firestore.collection('availability_slots').doc(slotId).get();
    if (!slotDoc.exists) {
      throw Exception('Slot not found');
    }
    final slotData = slotDoc.data()!;
    if (slotData['bookedBy'] != null) {
      throw Exception('This slot is already booked');
    }

    // Check if the job post is completed
    String? postId;
    try {
      // Get as Application (matchId is application ID)
      final applicationDoc = await _firestore.collection('applications').doc(matchId).get();
      if (applicationDoc.exists) {
        final appData = applicationDoc.data();
        postId = appData?['postId'] as String?;
      }

      // Check post status if postId was found
      if (postId != null) {
        final postDoc = await _firestore.collection('posts').doc(postId).get();
        if (postDoc.exists) {
          final postData = postDoc.data();
          final status = postData?['status'] as String?;
          if (status == 'completed') {
            throw Exception('This job post has been completed. You cannot book slots for completed posts.');
          }
        }
      }
    } catch (e) {
      // Re-throw if it's our custom exception, otherwise log and continue
      if (e.toString().contains('completed')) {
        rethrow;
      }
      debugPrint('Error checking post status: $e');
    }

    // Get slot details for notification
    final slot = AvailabilitySlot.fromFirestore(slotDoc);
    final slotTimeDisplay = _formatSlotTimeDisplay(slot);

    // Note: Multiple jobseekers can request the same slot
    // When recruiter approves one, others will be automatically rejected

    final request = BookingRequest(
      id: '',
      slotId: slotId,
      recruiterId: recruiterId,
      jobseekerId: jobseekerId,
      matchId: matchId,
      status: BookingRequestStatus.pending,
      createdAt: DateTime.now(),
    );

    final docRef = await _firestore
        .collection('booking_requests')
        .add(request.toFirestore());

    // Send notifications asynchronously (don't block on these)
    _sendBookingRequestNotifications(
      jobseekerId: jobseekerId,
      recruiterId: recruiterId,
      slotTimeDisplay: slotTimeDisplay,
    ).catchError((e) {
      // Log error but don't fail the booking request
      debugPrint('Error sending booking request notifications: $e');
    });

    return docRef.id;
  }

  // Helper method to send booking request notifications
  Future<void> _sendBookingRequestNotifications({
    required String jobseekerId,
    required String recruiterId,
    required String slotTimeDisplay,
  }) async {
    // Get user names
    final jobseekerName = await _getUserName(jobseekerId);
    final recruiterName = await _getUserName(recruiterId);

    // Notify recruiter
    await _notificationService.notifyBookingRequestSentToRecruiter(
      recruiterId: recruiterId,
      jobseekerName: jobseekerName,
      slotTimeDisplay: slotTimeDisplay,
    );

    // Notify jobseeker
    await _notificationService.notifyBookingRequestSentToJobseeker(
      jobseekerId: jobseekerId,
      recruiterName: recruiterName,
      slotTimeDisplay: slotTimeDisplay,
    );
  }

  // Get booking requests for an recruiter (stream)
  Stream<List<BookingRequest>> streamBookingRequestsForRecruiter() async* {
    final userId = _authService.currentUserId;
    yield* _firestore
        .collection('booking_requests')
        .where('recruiterId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) {
      final requests = snapshot.docs
          .map((doc) => BookingRequest.fromFirestore(doc))
          .toList();
      // Sort by createdAt descending (client-side to avoid Firestore composite index requirement)
      requests.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return requests;
    });
  }

  // Get booking requests for an jobseeker (stream)
  Stream<List<BookingRequest>> streamBookingRequestsForJobseeker(String jobseekerId) async* {
    yield* _firestore
        .collection('booking_requests')
        .where('jobseekerId', isEqualTo: jobseekerId)
        .snapshots()
        .map((snapshot) {
      final requests = snapshot.docs
          .map((doc) => BookingRequest.fromFirestore(doc))
          .toList();
      // Sort by createdAt descending (client-side to avoid Firestore composite index requirement)
      requests.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return requests;
    });
  }

  // Get pending booking request slot IDs for an jobseeker
  Future<Set<String>> getRequestedSlotIdsForJobseeker(
    String jobseekerId, {
    String? matchId, // Filter by specific application/match ID
  }) async {
    final snapshot = await _firestore
        .collection('booking_requests')
        .where('jobseekerId', isEqualTo: jobseekerId)
        .where('status', isEqualTo: 'pending')
        .get();

    return snapshot.docs
        .map((doc) => BookingRequest.fromFirestore(doc))
        .where((request) => matchId == null || request.matchId == matchId)
        .map((request) => request.slotId)
        .toSet();
  }

  // Get pending booking request slot IDs for an recruiter
  Future<Set<String>> getRequestedSlotIdsForRecruiter(String recruiterId) async {
    final snapshot = await _firestore
        .collection('booking_requests')
        .where('recruiterId', isEqualTo: recruiterId)
        .where('status', isEqualTo: 'pending')
        .get();

    return snapshot.docs
        .map((doc) => BookingRequest.fromFirestore(doc).slotId)
        .toSet();
  }

  // Approve booking request (and actually book the slot)
  Future<void> approveBookingRequest(String requestId) async {
    final requestDoc = await _firestore
        .collection('booking_requests')
        .doc(requestId)
        .get();

    if (!requestDoc.exists) {
      throw Exception('Booking request not found');
    }

    final request = BookingRequest.fromFirestore(requestDoc);

    // Check if slot is still available
    final slotDoc = await _firestore
        .collection('availability_slots')
        .doc(request.slotId)
        .get();

    if (!slotDoc.exists) {
      throw Exception('Slot not found');
    }

    final slotData = slotDoc.data()!;
    if (slotData['bookedBy'] != null) {
      // Slot already booked, reject all other pending requests for this slot
      await _firestore.collection('booking_requests').doc(requestId).update({
        'status': 'rejected',
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });
      throw Exception('This slot is already booked');
    }

    // Get slot details for notification
    final slot = AvailabilitySlot.fromFirestore(slotDoc);
    final slotTimeDisplay = _formatSlotTimeDisplay(slot);

    // Update booking request status
    await _firestore.collection('booking_requests').doc(requestId).update({
      'status': 'approved',
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    });

    // Actually book the slot
    await _firestore.collection('availability_slots').doc(request.slotId).update({
      'isAvailable': false,
      'bookedBy': request.jobseekerId,
      'matchId': request.matchId,
    });

    // Reject all other pending requests for this slot
    final otherRequests = await _firestore
        .collection('booking_requests')
        .where('slotId', isEqualTo: request.slotId)
        .where('status', isEqualTo: 'pending')
        .where(FieldPath.documentId, isNotEqualTo: requestId)
        .get();

    final batch = _firestore.batch();
    for (final doc in otherRequests.docs) {
      batch.update(doc.reference, {
        'status': 'rejected',
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });
    }
    await batch.commit();

    // Send notification to jobseeker asynchronously (don't block on this)
    _sendBookingApprovalNotification(
      jobseekerId: request.jobseekerId,
      recruiterId: request.recruiterId,
      slotTimeDisplay: slotTimeDisplay,
    ).catchError((e) {
      // Log error but don't fail the approval
      debugPrint('Error sending booking approval notification: $e');
    });
  }

  // Helper method to send booking approval notification
  Future<void> _sendBookingApprovalNotification({
    required String jobseekerId,
    required String recruiterId,
    required String slotTimeDisplay,
  }) async {
    final recruiterName = await _getUserName(recruiterId);
    
    await _notificationService.notifyBookingRequestApproved(
      jobseekerId: jobseekerId,
      recruiterName: recruiterName,
      slotTimeDisplay: slotTimeDisplay,
    );
  }

  // Reject booking request
  Future<void> rejectBookingRequest(String requestId) async {
    await _firestore.collection('booking_requests').doc(requestId).update({
      'status': 'rejected',
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    });
  }
}
