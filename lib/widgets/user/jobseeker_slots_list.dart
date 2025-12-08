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

class JobseekerSlotsList extends StatefulWidget {
  final DateTime selectedDate;
  final String? selectedRecruiterId;
  final Application? selectedApplication;
  final AvailabilityService availabilityService;
  final AuthService authService;
  final ApplicationService applicationService;
  final PostService postService;
  final VoidCallback onBooked;
  final VoidCallback? onSlotsLoaded; 

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
    this.onSlotsLoaded,
  });

  @override
  State<JobseekerSlotsList> createState() => _JobseekerSlotsListState();
}

class _JobseekerSlotsListState extends State<JobseekerSlotsList> {
  bool _hasNotifiedLoaded = false; //track if already notified head
  DateTime? _lastNotifiedDate; //track last notified 

  @override
  void didUpdateWidget(JobseekerSlotsList oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Reset notification state if date changed
    final oldDate = DateTime(oldWidget.selectedDate.year, oldWidget.selectedDate.month, oldWidget.selectedDate.day);
    final newDate = DateTime(widget.selectedDate.year, widget.selectedDate.month, widget.selectedDate.day);
    if (oldDate != newDate) {
      _hasNotifiedLoaded = false;
      _lastNotifiedDate = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    //approved applications
    return FutureBuilder<List<Application>>(
      future: widget.applicationService.streamMyApplications().first,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(
              color: Color(0xFF00C8A0),
            ),
          );
        }

        final applications = snapshot.data ?? [];
        
        //approved recruiterid applications
        final approvedApplications = applications.where((app) => app.status == ApplicationStatus.approved).toList();
        
        final approvedRecruiterIdsSet = approvedApplications
            .map((app) => app.recruiterId)
            .toSet();

        Set<String> approvedRecruiterIds;
        Application? applicationToUse = widget.selectedApplication;
        if (widget.selectedRecruiterId != null) {
          if (approvedRecruiterIdsSet.contains(widget.selectedRecruiterId!)) {
            approvedRecruiterIds = {widget.selectedRecruiterId!};
          } else {
            // Selected recruiter doesn't have an approved application
            approvedRecruiterIds = {};
          }
        } else {
          //all 
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
          widget.selectedDate.year,
          widget.selectedDate.month,
          widget.selectedDate.day,
        );
        final endOfDay = DateTime(
          widget.selectedDate.year,
          widget.selectedDate.month,
          widget.selectedDate.day,
          23,
          59,
          59,
        );

        final jobseekerId = widget.authService.currentUserId;
        
        return StreamBuilder<List<AvailabilitySlot>>(
          stream: widget.availabilityService.streamAvailableSlotsForRecruiters(
            approvedRecruiterIds,
            startDate: startOfDay,
            endDate: endOfDay,
            jobseekerId: jobseekerId, 
          ),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.active) {
              if (snapshot.hasData || snapshot.hasError) {
                final currentDate = DateTime(
                  widget.selectedDate.year,
                  widget.selectedDate.month,
                  widget.selectedDate.day,
                );
                
                // Always notify if date changed, or if we haven't notified yet
                if (_lastNotifiedDate == null || 
                    _lastNotifiedDate!.year != currentDate.year ||
                    _lastNotifiedDate!.month != currentDate.month ||
                    _lastNotifiedDate!.day != currentDate.day) {
                  _hasNotifiedLoaded = true;
                  _lastNotifiedDate = currentDate;
                  
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    widget.onSlotsLoaded?.call();
                  });
                } else if (!_hasNotifiedLoaded) {
                  // If same date but haven't notified yet, notify now
                  _hasNotifiedLoaded = true;
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    widget.onSlotsLoaded?.call();
                  });
                }
              }
            }
            
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(
                  color: Color(0xFF00C8A0),
                ),
              );
            }

            final slots = snapshot.data ?? [];

            //show owneed slots
            if (widget.selectedRecruiterId != null) {
              var recruiterSlots = slots
                  .where((slot) => slot.recruiterId == widget.selectedRecruiterId!)
                  .toList();
              
              recruiterSlots.sort((a, b) => a.startTime.compareTo(b.startTime));
              
              if (applicationToUse == null && recruiterSlots.isNotEmpty && approvedApplications.isNotEmpty) {
                try {
                  final approvedApp = approvedApplications.firstWhere(
                    (app) => app.recruiterId == widget.selectedRecruiterId!,
                  );
                  applicationToUse = approvedApp;
                } catch (e) {
                }
              }
              
              if (applicationToUse != null) {
                //check  requested slots and post status
                final jobseekerId = widget.authService.currentUserId;
                final application = applicationToUse!;
                final applicationId = application.id;
                
                // First, check post data to filter by eventEndDate BEFORE displaying slots
                return FutureBuilder<Post?>(
                  future: widget.postService.getById(application.postId),
                  builder: (context, postSnapshot) {
                    // Show loading while post data is being fetched
                    if (postSnapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFF00C8A0),
                        ),
                      );
                    }
                    
                    final post = postSnapshot.data;
                    
                    // Filter slots by eventEndDate BEFORE any other processing
                    final dateFilteredSlots = recruiterSlots.where((slot) {
                      if (post != null && post.eventEndDate != null) {
                        final slotDateOnly = DateTime(slot.date.year, slot.date.month, slot.date.day);
                        final eventEndDateOnly = DateTime(
                          post.eventEndDate!.year,
                          post.eventEndDate!.month,
                          post.eventEndDate!.day,
                        );
                        
                        if (slotDateOnly.isAfter(eventEndDateOnly)) {
                          return false; // Don't show slots after event end date
                        }
                      }
                      return true;
                    }).toList();

                    if (dateFilteredSlots.isEmpty) {
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

                    //check slot  unavailable 
                    final unavailableSlots = <String>{};
                    for (int i = 0; i < dateFilteredSlots.length; i++) {
                      final slot = dateFilteredSlots[i];
                      //mark subsequent slots as unavailable when slot is booked oter
                      if (slot.bookedBy != null && 
                          !(slot.bookedBy == jobseekerId && slot.matchId == applicationId)) {
                        for (int j = i + 1; j < dateFilteredSlots.length; j++) {
                          unavailableSlots.add(dateFilteredSlots[j].id);
                        }
                        break; 
                      }
                    }
                    return FutureBuilder<Map<String, dynamic>>(
                      future: Future.wait([
                        widget.availabilityService.getRequestedSlotIdsForJobseeker(
                          jobseekerId,
                          matchId: applicationId, 
                        ),
                        _checkPostStatus(applicationId, widget.postService), 
                      ]).then((results) => {
                        'requestedSlotIds': results[0] as Set<String>,
                        'isPostCompleted': results[1] as bool,
                      }),
                      builder: (context, dataSnapshot) {
                        final requestedSlotIds = (dataSnapshot.data?['requestedSlotIds'] as Set<String>?) ?? {};
                        final isPostCompleted = (dataSnapshot.data?['isPostCompleted'] as bool?) ?? false;

                        final filteredSlots = dateFilteredSlots.where((slot) {
                          // Post eventEndDate filtering already done above
                          // Now filter by booking status
                          if (slot.bookedBy != null && slot.matchId == applicationId) {
                            return true; 
                          }
                          if (slot.isAvailable && slot.bookedBy == null) {
                            return true; 
                          }
                          return true;
                        }).toList();

                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      children: filteredSlots
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
                                FutureBuilder<String>(
                                  future: _loadRecruiterName(application.recruiterId),
                                  builder: (context, snapshot) {
                                    return Text(
                                      snapshot.data ?? 'Recruiter',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                        color: Colors.grey[600],
                                      ),
                                    );
                                  },
                                ),
                                const SizedBox(height: 12),
                                Divider(
                                  height: 1,
                                  thickness: 1,
                                  color: Colors.grey[200],
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
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
                                    // Request button or status
                                    if (isBooked)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 16,
                                          vertical: 8,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.green[50],
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(
                                            color: Colors.green[300]!,
                                            width: 1.5,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Icons.check_circle,
                                              size: 16,
                                              color: Colors.green[700],
                                            ),
                                            const SizedBox(width: 6),
                                            Text(
                                              'Booked',
                                              style: TextStyle(
                                                color: Colors.green[800],
                                                fontSize: 14,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                        ),
                                      )
                                    else if (isRequested)
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
                  },
                );
              } else {
                // No application selected
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

            //group slots by recruiter (when no specific recruiter selected)
            final jobseekerId = widget.authService.currentUserId;
            final applicationId = widget.selectedApplication?.id;
            
            // First check if we have a selected application and get post data
            if (widget.selectedApplication == null) {
              return const SizedBox.shrink();
            }
            
            return FutureBuilder<Post?>(
              future: widget.postService.getById(widget.selectedApplication!.postId),
              builder: (context, postSnapshot) {
                // Show loading while post data is being fetched
                if (postSnapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(
                      color: Color(0xFF00C8A0),
                    ),
                  );
                }
                
                final post = postSnapshot.data;
                
                // Filter slots by eventEndDate BEFORE grouping by recruiter
                final allDateFilteredSlots = slots.where((slot) {
                  if (post != null && post.eventEndDate != null) {
                    final slotDateOnly = DateTime(slot.date.year, slot.date.month, slot.date.day);
                    final eventEndDateOnly = DateTime(
                      post.eventEndDate!.year,
                      post.eventEndDate!.month,
                      post.eventEndDate!.day,
                    );
                    
                    if (slotDateOnly.isAfter(eventEndDateOnly)) {
                      return false; // Don't show slots after event end date
                    }
                  }
                  return true;
                }).toList();
                
                // Now group filtered slots by recruiter
                final slotsByRecruiter = <String, List<AvailabilitySlot>>{};
                for (final slot in allDateFilteredSlots) {
                  slotsByRecruiter.putIfAbsent(slot.recruiterId, () => []).add(slot);
                }
                 
                 return FutureBuilder<Map<String, dynamic>>(
                   future: Future.wait([
                     widget.availabilityService.getRequestedSlotIdsForJobseeker(
                       jobseekerId,
                       matchId: applicationId, 
                     ),
                     applicationId != null ? _checkPostStatus(applicationId, widget.postService) : Future.value(false),
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

                         recruiterSlots.sort((a, b) => a.startTime.compareTo(b.startTime));
                         Application? application;
                         if (widget.selectedApplication != null && widget.selectedApplication!.recruiterId == recruiterId) {
                           application = widget.selectedApplication;
                         } else {
                           return const SizedBox.shrink();
                         }

                         final currentApplication = application!;
                         final matchApplicationId = currentApplication.id;

                         // Slots are already filtered by eventEndDate above
                         final dateFilteredSlots = recruiterSlots;

                         final unavailableSlots = <String>{};
                         for (int i = 0; i < dateFilteredSlots.length; i++) {
                           if (dateFilteredSlots[i].bookedBy != null) {
                             // Mark all subsequent slots as unavailable
                             for (int j = i + 1; j < dateFilteredSlots.length; j++) {
                               unavailableSlots.add(dateFilteredSlots[j].id);
                             }
                             break;
                           }
                         }

                         return Padding(
                           padding: const EdgeInsets.symmetric(horizontal: 16),
                           child: Column(
                             children: dateFilteredSlots
                                 .where((slot) {
                                   if (slot.bookedBy != null && slot.matchId == matchApplicationId) {
                                     return true; 
                                   }
                                   if (slot.isAvailable && slot.bookedBy == null) {
                                     return true; 
                                   }
                                   //requested slot
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
                                           FutureBuilder<String>(
                                             future: _loadRecruiterName(currentApplication.recruiterId),
                                             builder: (context, snapshot) {
                                               return Text(
                                                 snapshot.data ?? 'Recruiter',
                                                 style: TextStyle(
                                                   fontSize: 14,
                                                   fontWeight: FontWeight.w500,
                                                   color: Colors.grey[600],
                                                 ),
                                               );
                                             },
                                           ),
                                           const SizedBox(height: 12),
                                           Divider(
                                             height: 1,
                                             thickness: 1,
                                             color: Colors.grey[200],
                                           ),
                                           const SizedBox(height: 12),
                                           Row(
                                             children: [
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
                                               // Request button or status
                                               if (isBooked)
                                                 Container(
                                                   padding: const EdgeInsets.symmetric(
                                                     horizontal: 16,
                                                     vertical: 8,
                                                   ),
                                                   decoration: BoxDecoration(
                                                     color: Colors.green[50],
                                                     borderRadius: BorderRadius.circular(8),
                                                     border: Border.all(
                                                       color: Colors.green[300]!,
                                                       width: 1.5,
                                                     ),
                                                   ),
                                                   child: Row(
                                                     mainAxisSize: MainAxisSize.min,
                                                     children: [
                                                       Icon(
                                                         Icons.check_circle,
                                                         size: 16,
                                                         color: Colors.green[700],
                                                       ),
                                                       const SizedBox(width: 6),
                                                       Text(
                                                         'Booked',
                                                         style: TextStyle(
                                                           color: Colors.green[800],
                                                           fontSize: 14,
                                                           fontWeight: FontWeight.w600,
                                                         ),
                                                       ),
                                                     ],
                                                   ),
                                                 )
                                               else if (isRequested)
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
       },
     );
   }

  //check post completed
  Future<bool> _checkPostStatus(String matchId, PostService postService) async {
    try {
      final firestore = FirebaseFirestore.instance;
      String? postId;
      
      //applicationmatchid
      final applicationDoc = await firestore.collection('applications').doc(matchId).get();
      if (applicationDoc.exists) {
        final appData = applicationDoc.data();
        postId = appData?['postId'] as String?;
      }

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
    final jobTitle = await _loadJobTitle(application.postId, widget.postService);
    
    final confirmed = await DialogUtils.showConfirmationDialog(
      context: context,
      title: 'Request Booking',
      message: 'Send booking request for interview slot on ${DateFormat('MMMM d, yyyy').format(slot.date)} '
          'at ${slot.timeDisplay} for $jobTitle?\n\n'
          'The recruiter will review and approve your request.',
      icon: Icons.event_available,
      confirmText: 'Send Request',
      cancelText: 'Cancel',
      isDestructive: false,
    );

    if (confirmed == true) {
      try {
        final jobseekerId = widget.authService.currentUserId;
        await widget.availabilityService.createBookingRequest(
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
                widget.onBooked();
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

  Future<String> _loadRecruiterName(String recruiterId) async {
    try {
      final firestore = FirebaseFirestore.instance;
      final userDoc = await firestore.collection('users').doc(recruiterId).get();
      if (userDoc.exists) {
        final data = userDoc.data() ?? {};
        return (data['fullName'] as String?) ??
            (data['professionalProfile'] as String?) ??
            'Recruiter';
      }
    } catch (e) {
      debugPrint('Error loading recruiter name: $e');
    }
    return 'Recruiter';
  }

  Future<String> _loadJobTitle(String postId, PostService postService) async {
    try {
      final post = await postService.getById(postId);
      return post?.title ?? 'this job';
    } catch (e) {
      debugPrint('Error loading job title: $e');
    }
    return 'this job';
  }
}



