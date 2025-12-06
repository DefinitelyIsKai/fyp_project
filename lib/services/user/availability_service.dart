import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import '../../models/user/availability_slot.dart';
import '../../models/user/booking_request.dart';
import 'auth_service.dart';
import 'notification_service.dart';
import 'email_service.dart';
import 'post_service.dart';

class AvailabilityService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AuthService _authService = AuthService();
  final NotificationService _notificationService = NotificationService();
  final EmailService _emailService = EmailService();
  final PostService _postService = PostService();

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
    );

    final docRef = await _firestore
        .collection('availability_slots')
        .add(slot.toFirestore());
    return docRef.id;
  }

  // Toggle availability slot
  Future<void> toggleAvailabilitySlot(String slotId, bool isAvailable) async {
    // Check if slot is booked - cannot toggle if booked
    final slotDoc = await _firestore.collection('availability_slots').doc(slotId).get();
    if (!slotDoc.exists) {
      throw Exception('Slot not found');
    }
    
    final slotData = slotDoc.data()!;
    final bookedBy = slotData['bookedBy'] as String?;
    
    if (bookedBy != null && bookedBy.isNotEmpty) {
      throw Exception('Cannot toggle availability for a booked slot. The slot is currently booked by a jobseeker.');
    }
    
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

    // notified asynchronously
    _sendSlotDeletionNotifications(
      recruiterId: recruiterId,
      bookedBy: bookedBy,
      requestingJobseekerIds: requestingJobseekerIds,
      slotTimeDisplay: slotTimeDisplay,
      slot: slot, 
    ).catchError((e) {
    
      debugPrint('Error sending slot deletion notifications: $e');
    });
  }

  Future<void> _sendSlotDeletionNotifications({
    required String recruiterId,
    String? bookedBy,
    required List<String> requestingJobseekerIds,
    required String slotTimeDisplay,
    AvailabilitySlot? slot, 
  }) async {
    final recruiterName = await _getUserName(recruiterId);
    final hasBookedJobseeker = bookedBy != null && bookedBy.isNotEmpty;
    final pendingRequestsCount = requestingJobseekerIds.length;

    //noticejobseekers  pending 
    if (requestingJobseekerIds.isNotEmpty) {
      await _notificationService.notifySlotDeletedToRequestingJobseekers(
        jobseekerIds: requestingJobseekerIds,
        recruiterName: recruiterName,
        slotTimeDisplay: slotTimeDisplay,
      );
    }

    //email and app
    if (bookedBy != null && bookedBy.isNotEmpty) {
      await _notificationService.notifySlotDeletedToBookedJobseeker(
        jobseekerId: bookedBy,
        recruiterName: recruiterName,
        slotTimeDisplay: slotTimeDisplay,
      );

      // Send email notification to booked jobseeker
      if (slot != null) {
        _sendBookingCancellationEmail(
          jobseekerId: bookedBy,
          recruiterId: recruiterId,
          recruiterName: recruiterName,
          slot: slot,
        ).catchError((e) {
          debugPrint('Error sending booking cancellation email: $e');
        });
      }
    }

    await _notificationService.notifySlotDeletedToRecruiter(
      recruiterId: recruiterId,
      slotTimeDisplay: slotTimeDisplay,
      pendingRequestsCount: pendingRequestsCount,
      hasBookedJobseeker: hasBookedJobseeker,
    );
  }

  //available slot jobseeker
  Stream<List<AvailabilitySlot>> streamAvailableSlotsForRecruiter(
    String recruiterId,
  ) async* {

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
          slots.sort((a, b) {
            final dateCompare = a.date.compareTo(b.date);
            if (dateCompare != 0) return dateCompare;
            return a.startTime.compareTo(b.startTime);
          });
          return slots;
        });
  }

  //available slots recruiters 
  Stream<List<AvailabilitySlot>> streamAvailableSlotsForRecruiters(
    Set<String> recruiterIds, {
    DateTime? startDate,
    DateTime? endDate,
    String? jobseekerId,
  }) async* {
    if (recruiterIds.isEmpty) {
      yield* Stream.value([]);
      return;
    }

    
    final now = DateTime.now();
    final start = startDate ?? now;
    final end = endDate ?? DateTime(now.year, now.month + 1, 0);

  
    if (jobseekerId != null && jobseekerId.isNotEmpty) {
      
      final availableSlotsStream = _firestore
          .collection('availability_slots')
          .where('isAvailable', isEqualTo: true)
          .snapshots();
      
      final bookedSlotsStream = _firestore
          .collection('availability_slots')
          .where('bookedBy', isEqualTo: jobseekerId)
          .snapshots();
      
     
      StreamController<List<AvailabilitySlot>>? controller;
      StreamSubscription? availableSub;
      StreamSubscription? bookedSub;
      
      List<AvailabilitySlot>? latestAvailableSlots;
      List<AvailabilitySlot>? latestBookedSlots;
      
      controller = StreamController<List<AvailabilitySlot>>(
        onListen: () {
          availableSub = availableSlotsStream.listen((availableSnapshot) {
            latestAvailableSlots = availableSnapshot.docs.map((doc) {
              try {
                return AvailabilitySlot.fromFirestore(doc);
              } catch (e) {
                debugPrint('AvailabilityService: Error parsing slot ${doc.id}: $e');
                return null;
              }
            }).whereType<AvailabilitySlot>().toList();
            _emitCombinedSlots(controller, latestAvailableSlots, latestBookedSlots, recruiterIds, start, end);
          });
          
          bookedSub = bookedSlotsStream.listen((bookedSnapshot) {
            latestBookedSlots = bookedSnapshot.docs.map((doc) {
              try {
                return AvailabilitySlot.fromFirestore(doc);
              } catch (e) {
                debugPrint('AvailabilityService: Error parsing booked slot ${doc.id}: $e');
                return null;
              }
            }).whereType<AvailabilitySlot>().toList();
            _emitCombinedSlots(controller, latestAvailableSlots, latestBookedSlots, recruiterIds, start, end);
          });
        },
        onCancel: () {
          availableSub?.cancel();
          bookedSub?.cancel();
        },
      );
      
      yield* controller.stream;
    } else {
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
              //filter recruiterId
              if (!recruiterIds.contains(slot.recruiterId)) {
                return false;
              }
              //filter by date range
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
            
            slots.sort((a, b) {
              final dateCompare = a.date.compareTo(b.date);
              if (dateCompare != 0) return dateCompare;
              return a.startTime.compareTo(b.startTime);
            });
            return slots;
          });
    }
  }

 
  Future<Set<DateTime>> getAvailableDatesForRecruiters(
    Set<String> recruiterIds, {
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    if (recruiterIds.isEmpty) return {};

    final now = DateTime.now();
    final start = startDate ?? now;
    final end = endDate ?? DateTime(now.year, now.month + 1, 0);

  
    final snapshot = await _firestore
        .collection('availability_slots')
        .where('isAvailable', isEqualTo: true)
        .get();

    final dates = <DateTime>{};
    for (final doc in snapshot.docs) {
      final slot = AvailabilitySlot.fromFirestore(doc);
    
      if (!recruiterIds.contains(slot.recruiterId)) continue;
      
      if (slot.date.isBefore(start) || slot.date.isAfter(end)) continue;
      dates.add(DateTime(slot.date.year, slot.date.month, slot.date.day));
    }
    return dates;
  }

  //booked dates 
  Future<Set<DateTime>> getBookedDatesForJobseeker(
    String jobseekerId, {
    DateTime? startDate,
    DateTime? endDate,
    String? matchId, 
  }) async {
    final now = DateTime.now();
    final start = startDate ?? now;
    final end = endDate ?? DateTime(now.year, now.month + 1, 0);

    //query only by bookedBy 
    final snapshot = await _firestore
        .collection('availability_slots')
        .where('bookedBy', isEqualTo: jobseekerId)
        .get();

    final dates = <DateTime>{};
    for (final doc in snapshot.docs) {
      final slot = AvailabilitySlot.fromFirestore(doc);
      //filter  matchId
      if (matchId != null && slot.matchId != matchId) continue;
      //date range in memory
      if (slot.date.isBefore(start) || slot.date.isAfter(end)) continue;
      dates.add(DateTime(slot.date.year, slot.date.month, slot.date.day));
    }
    return dates;
  }

  

  
  Future<String> _getUserName(String userId) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (userDoc.exists) {
        final data = userDoc.data();
        return 
               data?['fullName'] as String? ?? 
               'Unknown';
      }
    } catch (e) {

    }
    return 'Unknown';
  }

  //format slot time display
  String _formatSlotTimeDisplay(AvailabilitySlot slot) {
    final dateStr = '${slot.date.year}-${slot.date.month.toString().padLeft(2, '0')}-${slot.date.day.toString().padLeft(2, '0')}';
    return '$dateStr ${slot.timeDisplay}';
  }

  //create booking request 
  Future<String> createBookingRequest({
    required String slotId,
    required String matchId,
    required String jobseekerId,
    required String recruiterId,
  }) async {
    //check pending reques slot
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

    //check  slot  booked
    final slotDoc = await _firestore.collection('availability_slots').doc(slotId).get();
    if (!slotDoc.exists) {
      throw Exception('Slot not found');
    }
    final slotData = slotDoc.data()!;
    if (slotData['bookedBy'] != null) {
      throw Exception('This slot is already booked');
    }

    //check post completed
    String? postId;
    try {
      //matchid is application id
      final applicationDoc = await _firestore.collection('applications').doc(matchId).get();
      if (applicationDoc.exists) {
        final appData = applicationDoc.data();
        postId = appData?['postId'] as String?;
      }

      //check post status 
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
      if (e.toString().contains('completed')) {
        rethrow;
      }
      debugPrint('Error checking post status: $e');
    }

    final slot = AvailabilitySlot.fromFirestore(slotDoc);
    final slotTimeDisplay = _formatSlotTimeDisplay(slot);

    //one approves others rejected

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

    //notifications 
    _sendBookingRequestNotifications(
      jobseekerId: jobseekerId,
      recruiterId: recruiterId,
      slotTimeDisplay: slotTimeDisplay,
    ).catchError((e) {
      debugPrint('Error sending booking request notifications: $e');
    });

    return docRef.id;
  }


  Future<void> _sendBookingRequestNotifications({
    required String jobseekerId,
    required String recruiterId,
    required String slotTimeDisplay,
  }) async {

    final jobseekerName = await _getUserName(jobseekerId);
    final recruiterName = await _getUserName(recruiterId);

    await _notificationService.notifyBookingRequestSentToRecruiter(
      recruiterId: recruiterId,
      jobseekerName: jobseekerName,
      slotTimeDisplay: slotTimeDisplay,
    );

 
    await _notificationService.notifyBookingRequestSentToJobseeker(
      jobseekerId: jobseekerId,
      recruiterName: recruiterName,
      slotTimeDisplay: slotTimeDisplay,
    );
  }

 
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
      requests.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return requests;
    });
  }

  Stream<List<BookingRequest>> streamBookingRequestsForJobseeker(String jobseekerId) async* {
    yield* _firestore
        .collection('booking_requests')
        .where('jobseekerId', isEqualTo: jobseekerId)
        .snapshots()
        .map((snapshot) {
      final requests = snapshot.docs
          .map((doc) => BookingRequest.fromFirestore(doc))
          .toList();
      requests.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return requests;
    });
  }


  Future<Set<String>> getRequestedSlotIdsForJobseeker(
    String jobseekerId, {
    String? matchId,
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

  
  Future<void> approveBookingRequest(String requestId) async {
    final requestDoc = await _firestore
        .collection('booking_requests')
        .doc(requestId)
        .get();

    if (!requestDoc.exists) {
      throw Exception('Booking request not found');
    }

    final request = BookingRequest.fromFirestore(requestDoc);

   
    final slotDoc = await _firestore
        .collection('availability_slots')
        .doc(request.slotId)
        .get();

    if (!slotDoc.exists) {
      throw Exception('Slot not found');
    }

    final slotData = slotDoc.data()!;
    if (slotData['bookedBy'] != null) {
      await _firestore.collection('booking_requests').doc(requestId).update({
        'status': 'rejected',
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });
      throw Exception('This slot is already booked');
    }

  
    final slot = AvailabilitySlot.fromFirestore(slotDoc);

 
    await _firestore.collection('booking_requests').doc(requestId).update({
      'status': 'approved',
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    });

  
    await _firestore.collection('availability_slots').doc(request.slotId).update({
      'isAvailable': false,
      'bookedBy': request.jobseekerId,
      'matchId': request.matchId,
    });

 
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

   
    _sendBookingApprovalNotification(
      jobseekerId: request.jobseekerId,
      recruiterId: request.recruiterId,
      slot: slot,
      matchId: request.matchId,
    ).catchError((e) {
      
      debugPrint('Error sending booking approval notification/email: $e');
    });
  }

  
  Future<void> _sendBookingCancellationEmail({
    required String jobseekerId,
    required String recruiterId,
    required String recruiterName,
    required AvailabilitySlot slot,
  }) async {
    try {
      final jobseekerEmail = await _getUserEmail(jobseekerId);
      final jobseekerName = await _getUserName(jobseekerId);
    
      String jobTitle = 'the job position';
      if (slot.matchId != null && slot.matchId!.isNotEmpty) {
        try {
          //find postid in applicat
          final applicationDoc = await _firestore.collection('applications').doc(slot.matchId).get();
          if (applicationDoc.exists) {
            final appData = applicationDoc.data();
            final postId = appData?['postId'] as String?;
            if (postId != null) {
              final post = await _postService.getById(postId);
              if (post != null) {
                jobTitle = post.title;
              }
            }
          }
        } catch (e) {
          debugPrint('Error getting job title for cancellation email: $e');
        }
      }

      if (jobseekerEmail != null && jobseekerEmail.isNotEmpty) {
        final slotDate = DateFormat('MMMM d, yyyy').format(slot.date);
        final slotTime = slot.timeDisplay;

        await _emailService.sendBookingCancellationEmail(
          recipientEmail: jobseekerEmail,
          recipientName: jobseekerName,
          recruiterName: recruiterName,
          slotDate: slotDate,
          slotTime: slotTime,
          jobTitle: jobTitle,
        );
      } else {
        debugPrint('Jobseeker email not found, skipping cancellation email notification');
      }
    } catch (e) {
      debugPrint('Error sending booking cancellation email: $e');
    }
  }

  Future<void> _sendBookingApprovalNotification({
    required String jobseekerId,
    required String recruiterId,
    required AvailabilitySlot slot,
    required String matchId,
  }) async {
    final recruiterName = await _getUserName(recruiterId);
    final slotTimeDisplay = _formatSlotTimeDisplay(slot);
    
    await _notificationService.notifyBookingRequestApproved(
      jobseekerId: jobseekerId,
      recruiterName: recruiterName,
      slotTimeDisplay: slotTimeDisplay,
    );

    //SMTP
    try {
      
      final jobseekerEmail = await _getUserEmail(jobseekerId);
      final jobseekerName = await _getUserName(jobseekerId);
  
      String jobTitle = 'the job position';
      try {
        
        final applicationDoc = await _firestore.collection('applications').doc(matchId).get();
        if (applicationDoc.exists) {
          final appData = applicationDoc.data();
          final postId = appData?['postId'] as String?;
          if (postId != null) {
            final post = await _postService.getById(postId);
            if (post != null) {
              jobTitle = post.title;
            }
          }
        }
      } catch (e) {
        debugPrint('Error getting job title for email: $e');
      }

      if (jobseekerEmail != null && jobseekerEmail.isNotEmpty) {
        final slotDate = DateFormat('MMMM d, yyyy').format(slot.date);
        final slotTime = slotTimeDisplay;

        await _emailService.sendBookingApprovalEmail(
          recipientEmail: jobseekerEmail,
          recipientName: jobseekerName,
          recruiterName: recruiterName,
          slotDate: slotDate,
          slotTime: slotTime,
          jobTitle: jobTitle,
        );
      } else {
        debugPrint('Jobseeker email not found, skipping email notification');
      }
    } catch (e) {
      debugPrint('Error sending booking approval email: $e');
    }
  }

  void _emitCombinedSlots(
    StreamController<List<AvailabilitySlot>>? controller,
    List<AvailabilitySlot>? availableSlots,
    List<AvailabilitySlot>? bookedSlots,
    Set<String> recruiterIds,
    DateTime start,
    DateTime end,
  ) {
    if (controller == null || (!controller.isClosed && controller.hasListener)) {
      final allSlots = <AvailabilitySlot>[];
      
     
      if (availableSlots != null) {
        allSlots.addAll(availableSlots);
      }
      
     
      if (bookedSlots != null) {
        final availableSlotIds = allSlots.map((s) => s.id).toSet();
        for (final bookedSlot in bookedSlots) {
          if (!availableSlotIds.contains(bookedSlot.id)) {
            allSlots.add(bookedSlot);
          }
        }
      }
      
     
      final slots = allSlots.where((slot) {
      
        if (!recruiterIds.contains(slot.recruiterId)) {
          return false;
        }
      
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
      
      slots.sort((a, b) {
        final dateCompare = a.date.compareTo(b.date);
        if (dateCompare != 0) return dateCompare;
        return a.startTime.compareTo(b.startTime);
      });
      
      if (controller != null && !controller.isClosed) {
        controller.add(slots);
      }
    }
  }

 
  Future<String?> _getUserEmail(String userId) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (userDoc.exists) {
        final data = userDoc.data();
        return data?['email'] as String?;
      }
    } catch (e) {
      debugPrint('Error getting user email: $e');
    }
    return null;
  }

  //reject booking request
  Future<void> rejectBookingRequest(String requestId) async {
    await _firestore.collection('booking_requests').doc(requestId).update({
      'status': 'rejected',
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    });
  }
}
