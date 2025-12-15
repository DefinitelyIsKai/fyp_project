import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import '../../../services/user/availability_service.dart';
import '../../../services/user/auth_service.dart';
import '../../../services/user/application_service.dart';
import '../../../services/user/post_service.dart';
import '../../../models/user/availability_slot.dart';
import '../../../models/user/application.dart';
import '../../../models/user/post.dart';
import '../../../widgets/user/monthly_calendar.dart';
import '../../../widgets/user/legend_item.dart';
import '../../../widgets/user/jobseeker_slots_list.dart';
import '../../../widgets/user/loading_indicator.dart';

class JobseekerBookingPage extends StatefulWidget {
  const JobseekerBookingPage({super.key});

  @override
  State<JobseekerBookingPage> createState() => _JobseekerBookingPageState();
}

class _JobseekerBookingPageState extends State<JobseekerBookingPage> {
  final AvailabilityService _availabilityService = AvailabilityService();
  final AuthService _authService = AuthService();
  final ApplicationService _applicationService = ApplicationService();
  final PostService _postService = PostService();

  DateTime _selectedDate = DateTime.now();
  DateTime _currentMonth = DateTime.now();
  String? _selectedRecruiterId;
  Application? _selectedApplication;
  Map<String, Post> _postCache = {};
  Map<String, String> _recruiterNameCache = {};
  int _refreshKey = 0;
  bool _isLoadingSlots = false;


  void _onMonthChanged(DateTime newMonth) {
    setState(() {
      _currentMonth = newMonth;
    });
  }

  void _onDateSelected(DateTime date) {
    final dateOnly = DateTime(date.year, date.month, date.day);
    final selectedDateOnly = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
    
    setState(() {
      _selectedDate = date;
      if (dateOnly != selectedDateOnly) {
        _isLoadingSlots = true;
      }
    });
  }

  void _onDateTapped(DateTime date) => _onDateSelected(date);

  Future<void> _refreshData() async {
    setState(() {
      _refreshKey++;
    });
    await Future.delayed(const Duration(milliseconds: 100));
  }

  void _onSlotsLoaded() {
    if (mounted && _isLoadingSlots) {
      setState(() {
        _isLoadingSlots = false;
      });
    }
  }

  static DateTime _normalizeDate(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  bool _isEventEndDatePassed(Post? post) {
    if (post == null || post.eventEndDate == null) {
      return false; 
    }
    final today = DateTime.now();
    final todayOnly = DateTime(today.year, today.month, today.day);
    final eventEndDateOnly = DateTime(
      post.eventEndDate!.year,
      post.eventEndDate!.month,
      post.eventEndDate!.day,
    );
    return todayOnly.isAfter(eventEndDateOnly);
  }

  bool _isPostValidForBooking(Post? post) {
    if (post == null) {
      return false; 
    }
    if (post.status == PostStatus.completed) {
      return false;
    }
    if (_isEventEndDatePassed(post)) {
      return false;
    }
    return true;
  }

  static DateTime _slotDate(AvailabilitySlot slot) {
    return _normalizeDate(slot.date);
  }

  ({DateTime start, DateTime end}) _getMonthRange(DateTime month) {
    return (start: DateTime(month.year, month.month, 1), end: DateTime(month.year, month.month + 1, 0));
  }

  ({Set<DateTime> allDates, Set<DateTime> availableDates, Set<DateTime> bookedDates}) _processSlots(
    List<AvailabilitySlot> slots,
  ) {
    return (
      allDates: slots.map(_slotDate).toSet(),
      availableDates: slots.where((s) => s.isAvailable).map(_slotDate).toSet(),
      bookedDates: slots.where((s) => s.bookedBy != null).map(_slotDate).toSet(),
    );
  }

  ({Set<DateTime> pendingDates, Set<DateTime> availableDatesExcludingPending}) _preparePendingDates(
    List<AvailabilitySlot> slots,
    Set<String> pendingSlotIds,
    Set<DateTime> availableDates,
  ) {
    final pendingDates = slots.where((slot) => pendingSlotIds.contains(slot.id)).map(_slotDate).toSet();
    final normalizedPendingDates = pendingDates.map(_normalizeDate).toSet();
    final normalizedAvailableDates = availableDates.map(_normalizeDate).toSet();
    final availableDatesExcludingPending = normalizedAvailableDates
        .where((date) => !normalizedPendingDates.contains(date))
        .toSet();
    return (pendingDates: normalizedPendingDates, availableDatesExcludingPending: availableDatesExcludingPending);
  }

  @override
  Widget build(BuildContext context) {
    if (_selectedRecruiterId == null) {
      return _buildRecruiterList();
    }

    if (_selectedApplication == null) {
      return PopScope(
        canPop: false,
        onPopInvoked: (didPop) {
          if (!didPop) {
            setState(() {
              _selectedRecruiterId = null;
            });
          }
        },
        child: _buildApplicationList(),
      );
    }

    return PopScope(
      canPop: false,
        onPopInvoked: (didPop) {
          if (!didPop) {
            setState(() {
              _selectedApplication = null;
            });
          }
        },
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
            ),
            child: Row(
              children: [
                Container(
                  margin: const EdgeInsets.only(right: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00C8A0).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back, color: Color(0xFF00C8A0)),
                    tooltip: 'Back to application list',
                    onPressed: () {
                      setState(() {
                        _selectedApplication = null;
                      });
                    },
                  ),
                ),
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 2.0),
                        child: const Icon(Icons.event_available, color: Color(0xFF00C8A0), size: 24),
                      ),
                      const SizedBox(width: 12),

                      Expanded(
                        child: FutureBuilder<Map<String, dynamic>>(
                          future: _selectedApplication != null
                              ? _loadApplicationDisplayData(_selectedApplication!)
                              : Future.value({'fullName': null, 'jobTitle': null}),
                          builder: (context, snapshot) {
                            final fullName = snapshot.data?['fullName'] as String?;
                            final jobTitle = snapshot.data?['jobTitle'] as String?;

                            return Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  fullName ?? 'Book Interview Slot',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.black,
                                    height: 1.1,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (jobTitle != null && jobTitle.isNotEmpty) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    jobTitle,
                                    style: TextStyle(fontSize: 16, color: Colors.grey[600], height: 2.0),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ],
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: RefreshIndicator(
              onRefresh: _refreshData,
              color: const Color(0xFF00C8A0),
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      color: Colors.grey[50],
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.chevron_left),
                            onPressed: () {
                              _onMonthChanged(DateTime(_currentMonth.year, _currentMonth.month - 1));
                            },
                          ),
                          Text(
                            DateFormat('MMMM yyyy').format(_currentMonth),
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          IconButton(
                            icon: const Icon(Icons.chevron_right),
                            onPressed: () {
                              _onMonthChanged(DateTime(_currentMonth.year, _currentMonth.month + 1));
                            },
                          ),
                        ],
                      ),
                    ),

                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      color: Colors.grey[50],
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          LegendItem(color: Colors.green, label: 'Available'),
                          const SizedBox(width: 24),
                          LegendItem(color: const Color(0xFFFF0000), label: 'Booked'),
                          const SizedBox(width: 24),
                          LegendItem(color: Colors.amber[700]!, label: 'Pending'),
                        ],
                      ),
                    ),

                    Container(
                      padding: const EdgeInsets.all(16),
                      color: Colors.white,
                      child: StreamBuilder<List<AvailabilitySlot>>(
                        key: ValueKey(
                          'calendar_stream_${_selectedRecruiterId}_${_currentMonth.year}_${_currentMonth.month}',
                        ),
                        stream: _availabilityService.streamAvailableSlotsForRecruiters(
                          {_selectedRecruiterId!},
                          startDate: _getMonthRange(_currentMonth).start,
                          endDate: _getMonthRange(_currentMonth).end,
                          jobseekerId: _authService.currentUserId,
                        ),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return const Center(
                              child: CircularProgressIndicator(
                                color: Color(0xFF00C8A0),
                              ),
                            );
                          }

                          final userId = _authService.currentUserId;
                          final slots = snapshot.data ?? [];

                          final applicationId = _selectedApplication?.id;
                          final filteredSlots = applicationId != null
                              ? slots.where((slot) {
                                  if (slot.isAvailable && slot.bookedBy == null) {
                                    return true;
                                  }
                                  if (slot.bookedBy != null && slot.matchId == applicationId) {
                                    return true;
                                  }
                                  return false;
                                }).toList()
                              : slots;

                          final postId = _selectedApplication?.postId;
                          if (postId == null) {
                            final processed = _processSlots(filteredSlots);
                            final monthRange = _getMonthRange(_currentMonth);
                            return StreamBuilder<Set<DateTime>>(
                              stream: _availabilityService.streamBookedDatesForJobseeker(
                                userId,
                                startDate: monthRange.start,
                                endDate: monthRange.end,
                                matchId: applicationId,
                              ),
                              builder: (context, bookedSnapshot) {
                                return StreamBuilder<Set<String>>(
                                  stream: _availabilityService.streamRequestedSlotIdsForJobseeker(
                                    userId,
                                    matchId: applicationId,
                                  ),
                                  builder: (context, pendingSnapshot) {
                                    final pendingData = _preparePendingDates(
                                      filteredSlots,
                                      pendingSnapshot.data ?? {},
                                      processed.availableDates,
                                    );
                                    return MonthlyCalendar(
                                      currentMonth: _currentMonth,
                                      selectedDate: _selectedDate,
                                      availableDates: pendingData.availableDatesExcludingPending,
                                      bookedDates: bookedSnapshot.data ?? {},
                                      addedSlotDates: const {},
                                      pendingDates: pendingData.pendingDates,
                                      onDateSelected: _onDateSelected,
                                      onDateTapped: _onDateTapped,
                                    );
                                  },
                                );
                              },
                            );
                          }

                          return StreamBuilder<Post?>(
                            stream: _postService.streamPostById(postId),
                            builder: (context, postSnapshot) {
                              if (postSnapshot.connectionState == ConnectionState.waiting) {
                                return const Center(
                                  child: CircularProgressIndicator(
                                    color: Color(0xFF00C8A0),
                                  ),
                                );
                              }
                              
                              final post = postSnapshot.data;
                              
                              if (post != null) {
                                _postCache[postId] = post;
                              }

                         
                              final dateFilteredSlots = filteredSlots.where((slot) {
                                if (post != null && post.eventEndDate != null) {
                                  final slotDateOnly = DateTime(slot.date.year, slot.date.month, slot.date.day);
                                  final eventEndDateOnly = DateTime(
                                    post.eventEndDate!.year,
                                    post.eventEndDate!.month,
                                    post.eventEndDate!.day,
                                  );

                                  if (slotDateOnly.isAfter(eventEndDateOnly)) {
                                    return false;
                                  }
                                }
                                return true;
                              }).toList();

                              final processed = _processSlots(dateFilteredSlots);

                              final monthRange = _getMonthRange(_currentMonth);

                              return StreamBuilder<Set<DateTime>>(
                                stream: _availabilityService.streamBookedDatesForJobseeker(
                                  userId,
                                  startDate: monthRange.start,
                                  endDate: monthRange.end,
                                  matchId: applicationId,
                                ),
                                builder: (context, bookedSnapshot) {
                                  return StreamBuilder<Set<String>>(
                                    stream: _availabilityService.streamRequestedSlotIdsForJobseeker(
                                      userId,
                                      matchId: applicationId,
                                    ),
                                    builder: (context, pendingSnapshot) {
                                      final pendingData = _preparePendingDates(
                                        dateFilteredSlots,
                                        pendingSnapshot.data ?? {},
                                        processed.availableDates,
                                      );

                                      return MonthlyCalendar(
                                        currentMonth: _currentMonth,
                                        selectedDate: _selectedDate,
                                        availableDates: pendingData.availableDatesExcludingPending,
                                        bookedDates: bookedSnapshot.data ?? {},
                                        addedSlotDates: const {},
                                        pendingDates: pendingData.pendingDates,
                                        onDateSelected: _onDateSelected,
                                        onDateTapped: _onDateTapped,
                                      );
                                    },
                                  );
                                },
                              );
                            },
                          );
                        },
                      ),
                    ),

                    const Divider(height: 1),

                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(
                            'Time Slots - ${DateFormat('MMMM d, yyyy').format(_selectedDate)}',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                        ),
                        Stack(
                          children: [
                            JobseekerSlotsList(
                              key: ValueKey('slots_${_selectedDate.toIso8601String()}'),
                              selectedDate: _selectedDate,
                              selectedRecruiterId: _selectedRecruiterId,
                              selectedApplication: _selectedApplication,
                              availabilityService: _availabilityService,
                              authService: _authService,
                              applicationService: _applicationService,
                              postService: _postService,
                              onBooked: () {
                                setState(() {
                                  _refreshKey++;
                                });
                              },
                              onSlotsLoaded: _onSlotsLoaded,
                            ),
                            if (_isLoadingSlots)
                              Container(
                                color: Colors.white.withOpacity(0.8),
                                child: const Center(child: LoadingIndicator.standard()),
                              ),
                          ],
                        ),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecruiterList() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
          ),
          child: Row(
            children: [
              const Icon(Icons.business, color: Color(0xFF00C8A0)),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Select Recruiter to Book Interview',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.black),
                ),
              ),
            ],
          ),
        ),

        Expanded(
          child: StreamBuilder<List<Application>>(
            stream: _applicationService.streamMyApplications(),
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
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline, size: 64, color: Colors.grey[300]),
                      const SizedBox(height: 16),
                      Text('Unable to load recruiters', style: TextStyle(color: Colors.grey[600])),
                    ],
                  ),
                );
              }

              final applications = snapshot.data ?? [];
              final approvedApplications = applications
                  .where((app) => app.status == ApplicationStatus.approved)
                  .toList();

              if (approvedApplications.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.info_outline, size: 64, color: Colors.grey[300]),
                      const SizedBox(height: 16),
                      Text('No approved matches', style: TextStyle(color: Colors.grey[600], fontSize: 16)),
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: Text(
                          'You need to be approved by a recruiter to book interview slots',
                          style: TextStyle(color: Colors.grey[500], fontSize: 12),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                );
              }

              final Map<String, List<Application>> recruiterApplications = {};
              for (final app in approvedApplications) {
                recruiterApplications.putIfAbsent(app.recruiterId, () => []).add(app);
              }

              return StreamBuilder<Map<String, dynamic>>(
                stream: _streamPostsAndRecruitersForApplications(approvedApplications),
                builder: (context, dataSnapshot) {
                  if (dataSnapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFF00C8A0),
                      ),
                    );
                  }

                  final data = dataSnapshot.data ?? {};
                  final postsMap = data['posts'] as Map<String, Post>? ?? {};
                  final recruitersMap = data['recruiters'] as Map<String, Map<String, dynamic>>? ?? {};

                  
                  final validRecruiters = <String>[];
                  final validApplicationCounts = <String, int>{};
                  for (final recruiterId in recruiterApplications.keys) {
                    final recruiterApps = recruiterApplications[recruiterId]!;
                    int validCount = 0;
                    for (final app in recruiterApps) {
                      final post = postsMap[app.postId];
                      if (_isPostValidForBooking(post)) {
                        validCount++;
                      }
                    }

                    if (validCount > 0) {
                      validRecruiters.add(recruiterId);
                      validApplicationCounts[recruiterId] = validCount;
                    }
                  }

                  if (validRecruiters.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.info_outline, size: 64, color: Colors.grey[300]),
                          const SizedBox(height: 16),
                          Text('No available recruiters', style: TextStyle(color: Colors.grey[600], fontSize: 16)),
                          const SizedBox(height: 8),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 32),
                            child: Text(
                              'All job posts have expired event dates or are completed',
                              style: TextStyle(color: Colors.grey[500], fontSize: 12),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  final uniqueRecruiters = validRecruiters;

                  return ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: uniqueRecruiters.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final recruiterId = uniqueRecruiters[index];
                      final count = validApplicationCounts[recruiterId] ?? 0;

                      final recruiterData = recruitersMap[recruiterId] ?? {};
                      final fullName =
                          recruiterData['fullName'] as String? ??
                          recruiterData['professionalProfile'] as String? ??
                          'Unknown';

                      return Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey[200]!),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.03),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () {
                              setState(() {
                                _selectedRecruiterId = recruiterId;
                              });
                            },
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                children: [
                                  Container(
                                    width: 50,
                                    height: 50,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF00C8A0).withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Icon(Icons.business_center, color: Color(0xFF00C8A0), size: 24),
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
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '$count approved application${count > 1 ? 's' : ''}',
                                          style: TextStyle(
                                            color: Colors.grey[600],
                                            fontSize: 13,
                                            fontWeight: FontWeight.w500,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                  Icon(Icons.chevron_right, color: Colors.grey[300], size: 24),
                                ],
                              ),
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
    );
  }

  Widget _buildApplicationList() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
          ),
          child: Row(
            children: [
              Container(
                margin: const EdgeInsets.only(right: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF00C8A0).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Color(0xFF00C8A0)),
                  tooltip: 'Back to recruiter list',
                  onPressed: () {
                    setState(() {
                      _selectedRecruiterId = null;
                    });
                  },
                ),
              ),
              const Icon(Icons.work_outline, color: Color(0xFF00C8A0)),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Select Job Application',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.black),
                ),
              ),
            ],
          ),
        ),

        Expanded(
          child: StreamBuilder<List<Application>>(
            stream: _applicationService.streamMyApplications(),
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
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline, size: 64, color: Colors.grey[300]),
                      const SizedBox(height: 16),
                      Text('Unable to load applications', style: TextStyle(color: Colors.grey[600])),
                    ],
                  ),
                );
              }

              final applications = snapshot.data ?? [];
              final approvedApplicationsForRecruiter = applications
                  .where((app) => app.status == ApplicationStatus.approved && app.recruiterId == _selectedRecruiterId)
                  .toList();

              if (approvedApplicationsForRecruiter.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.info_outline, size: 64, color: Colors.grey[300]),
                      const SizedBox(height: 16),
                      Text('No approved applications', style: TextStyle(color: Colors.grey[600], fontSize: 16)),
                    ],
                  ),
                );
              }

              return StreamBuilder<Map<String, dynamic>>(
                stream: _streamPostsAndRecruitersForApplications(approvedApplicationsForRecruiter),
                builder: (context, dataSnapshot) {
                  if (dataSnapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFF00C8A0),
                      ),
                    );
                  }

                  final data = dataSnapshot.data ?? {};
                  final postsMap = data['posts'] as Map<String, Post>? ?? {};
                  final recruitersMap = data['recruiters'] as Map<String, Map<String, dynamic>>? ?? {};

                  
                  final validApplications = approvedApplicationsForRecruiter.where((application) {
                    final post = postsMap[application.postId];
                    return _isPostValidForBooking(post);
                  }).toList();

                  if (validApplications.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.info_outline, size: 64, color: Colors.grey[300]),
                          const SizedBox(height: 16),
                          Text('No available applications', style: TextStyle(color: Colors.grey[600], fontSize: 16)),
                          const SizedBox(height: 8),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 32),
                            child: Text(
                              'All job posts have expired event dates or are completed',
                              style: TextStyle(color: Colors.grey[500], fontSize: 12),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: validApplications.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final application = validApplications[index];
                      final post = postsMap[application.postId];
                      final recruiterData = recruitersMap[application.recruiterId] ?? {};
                      final fullName =
                          recruiterData['fullName'] as String? ??
                          recruiterData['professionalProfile'] as String? ??
                          post?.event ??
                          'Unknown';
                      final jobTitle = post?.title ?? 'Job Position';

                      return Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey[200]!),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.03),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () async {
                              setState(() {
                                _selectedApplication = application;
                                _recruiterNameCache[application.recruiterId] = fullName;
                              });
                            },
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                children: [
                                  Container(
                                    width: 50,
                                    height: 50,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF00C8A0).withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Icon(Icons.work_outline, color: Color(0xFF00C8A0), size: 24),
                                  ),
                                  const SizedBox(width: 16),

                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          jobTitle,
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w700,
                                            color: Colors.black87,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          fullName,
                                          style: TextStyle(
                                            color: Colors.grey[600],
                                            fontSize: 13,
                                            fontWeight: FontWeight.w500,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 8),

                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF00C8A0).withOpacity(0.15),
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Text(
                                            'Approved',
                                            style: TextStyle(
                                              color: const Color(0xFF00C8A0),
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Icon(Icons.chevron_right, color: Colors.grey[300], size: 24),
                                ],
                              ),
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
    );
  }

  
  Future<Map<String, dynamic>> _loadPostsAndRecruitersForApplications(List<Application> applications) async {
    final Map<String, Post> postsMap = {};
    final Map<String, Map<String, dynamic>> recruitersMap = {};
    final Set<String> recruiterIds = applications.map((app) => app.recruiterId).toSet();

    for (final app in applications) {
      if (_postCache.containsKey(app.postId)) {
        postsMap[app.postId] = _postCache[app.postId]!;
      } else {
        final post = await _postService.getById(app.postId);
        if (post != null) {
          _postCache[app.postId] = post;
          postsMap[app.postId] = post;
        }
      }
    }

    final firestore = FirebaseFirestore.instance;
    for (final recruiterId in recruiterIds) {
      try {
        final userDoc = await firestore.collection('users').doc(recruiterId).get();
        if (userDoc.exists) {
          final data = userDoc.data() ?? {};
          recruitersMap[recruiterId] = {
            'fullName': data['fullName'] as String?,
            'professionalProfile': data['professionalProfile'] as String?,
          };
        }
      } catch (e) {
        debugPrint('Error loading recruiter $recruiterId: $e');
      }
    }

    return {'posts': postsMap, 'recruiters': recruitersMap};
  }

  Stream<Map<String, dynamic>> _streamPostsAndRecruitersForApplications(List<Application> applications) {
    if (applications.isEmpty) {
      return Stream.value({'posts': <String, Post>{}, 'recruiters': <String, Map<String, dynamic>>{}});
    }

    final Set<String> postIds = applications.map((app) => app.postId).toSet();
    final Set<String> recruiterIds = applications.map((app) => app.recruiterId).toSet();


    final Map<String, Post> postsMap = {};
    final Map<String, Map<String, dynamic>> recruitersMap = {};

    final Set<String> postsReceived = {};
    final Set<String> recruitersReceived = {};


    final controller = StreamController<Map<String, dynamic>>();
    final List<StreamSubscription> subscriptions = [];

    void emitIfReady() {
      if ((postIds.isEmpty || postsReceived.length == postIds.length) &&
          (recruiterIds.isEmpty || recruitersReceived.length == recruiterIds.length)) {
        if (!controller.isClosed) {
          controller.add({
            'posts': Map<String, Post>.from(postsMap),
            'recruiters': Map<String, Map<String, dynamic>>.from(recruitersMap),
          });
        }
      }
    }

    for (final postId in postIds) {
      final subscription = _postService.streamPostById(postId).listen((post) {
        if (post != null) {
          postsMap[postId] = post;
          _postCache[postId] = post; 
        }
        postsReceived.add(postId);
        emitIfReady();
      }, onError: (error) {
        debugPrint('Error streaming post $postId: $error');
        postsReceived.add(postId);
        emitIfReady();
      });
      subscriptions.add(subscription);
    }

   
    final firestore = FirebaseFirestore.instance;
    for (final recruiterId in recruiterIds) {
      final subscription = firestore.collection('users').doc(recruiterId).snapshots().listen((doc) {
        if (doc.exists) {
          final data = doc.data() ?? {};
          recruitersMap[recruiterId] = {
            'fullName': data['fullName'] as String?,
            'professionalProfile': data['professionalProfile'] as String?,
          };
        } else {
          recruitersMap[recruiterId] = {};
        }
        recruitersReceived.add(recruiterId);
        emitIfReady();
      }, onError: (error) {
        debugPrint('Error streaming recruiter $recruiterId: $error');
        recruitersReceived.add(recruiterId);
        emitIfReady();
      });
      subscriptions.add(subscription);
    }


    if (postIds.isEmpty && recruiterIds.isEmpty) {
      emitIfReady();
    }

   
    controller.onCancel = () {
      for (final subscription in subscriptions) {
        subscription.cancel();
      }
    };

    return controller.stream;
  }

  Future<Map<String, dynamic>> _loadApplicationDisplayData(Application application) async {
    String? fullName = _recruiterNameCache[application.recruiterId];
    if (fullName == null) {
      try {
        final recruiterData = await _loadPostsAndRecruitersForApplications([application]);
        final recruitersMap = recruiterData['recruiters'] as Map<String, Map<String, dynamic>>? ?? {};
        final recruiterDataMap = recruitersMap[application.recruiterId] ?? {};
        fullName =
            recruiterDataMap['fullName'] as String? ?? recruiterDataMap['professionalProfile'] as String? ?? 'Unknown';
        _recruiterNameCache[application.recruiterId] = fullName;
      } catch (e) {
        fullName = 'Unknown';
      }
    }

    String? jobTitle;
    if (_postCache.containsKey(application.postId)) {
      jobTitle = _postCache[application.postId]?.title;
    } else {
      final post = await _postService.getById(application.postId);
      if (post != null) {
        _postCache[application.postId] = post;
        jobTitle = post.title;
      }
    }

    return {'fullName': fullName, 'jobTitle': jobTitle ?? 'Job Position'};
  }
}
