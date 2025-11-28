import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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
  String? _selectedRecruiterId; // Selected recruiter (Level 1 -> Level 2)
  Application? _selectedApplication; // Selected application (Level 2 -> Level 3)
  Map<String, Post> _postCache = {}; // Cache for post data
  Map<String, String> _recruiterNameCache = {}; // Cache for recruiter names
  int _refreshKey = 0; // Key to force refresh of FutureBuilder

  void _onMonthChanged(DateTime newMonth) {
    setState(() {
      _currentMonth = newMonth;
    });
  }

  void _onDateSelected(DateTime date) {
    setState(() {
      _selectedDate = date;
    });
  }

  void _onDateTapped(DateTime date) => _onDateSelected(date);

  // Helper function to normalize dates for comparison (removes time component)
  static DateTime _normalizeDate(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  // Helper function to extract date from slot (normalized)
  static DateTime _slotDate(AvailabilitySlot slot) {
    return _normalizeDate(slot.date);
  }

  // Helper to get month date range
  ({DateTime start, DateTime end}) _getMonthRange(DateTime month) {
    return (
      start: DateTime(month.year, month.month, 1),
      end: DateTime(month.year, month.month + 1, 0),
    );
  }

  // Helper to process slots and prepare calendar data
  ({
    Set<DateTime> allDates,
    Set<DateTime> availableDates,
    Set<DateTime> bookedDates,
  })
  _processSlots(List<AvailabilitySlot> slots) {
    return (
      allDates: slots.map(_slotDate).toSet(),
      availableDates: slots.where((s) => s.isAvailable).map(_slotDate).toSet(),
      bookedDates: slots
          .where((s) => s.bookedBy != null)
          .map(_slotDate)
          .toSet(),
    );
  }

  // Helper to prepare pending dates and exclude from available
  ({Set<DateTime> pendingDates, Set<DateTime> availableDatesExcludingPending})
  _preparePendingDates(
    List<AvailabilitySlot> slots,
    Set<String> pendingSlotIds,
    Set<DateTime> availableDates,
  ) {
    final pendingDates = slots
        .where((slot) => pendingSlotIds.contains(slot.id))
        .map(_slotDate)
        .toSet();
    final normalizedPendingDates = pendingDates.map(_normalizeDate).toSet();
    final normalizedAvailableDates = availableDates.map(_normalizeDate).toSet();
    final availableDatesExcludingPending = normalizedAvailableDates
        .where((date) => !normalizedPendingDates.contains(date))
        .toSet();
    return (
      pendingDates: normalizedPendingDates,
      availableDatesExcludingPending: availableDatesExcludingPending,
    );
  }

  @override
  Widget build(BuildContext context) {
    // Level 1: If no recruiter selected, show recruiter list
    if (_selectedRecruiterId == null) {
      return _buildRecruiterList();
    }

    // Level 2: If recruiter selected but no application, show application list
    if (_selectedApplication == null) {
      return PopScope(
        canPop: false,
        onPopInvoked: (didPop) {
          if (!didPop) {
            // Handle back button - navigate back to recruiter list
            setState(() {
              _selectedRecruiterId = null;
            });
          }
        },
        child: _buildApplicationList(),
      );
    }

    // Level 3: If application selected, show calendar
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (!didPop) {
          // Handle back button - navigate back to application list
          setState(() {
            _selectedApplication = null;
          });
        }
      },
      child: Column(
        children: [
          // Header with back button
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
                    icon: const Icon(
                      Icons.arrow_back,
                      color: Color(0xFF00C8A0),
                    ),
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
                      // Icon
                      Padding(
                        padding: const EdgeInsets.only(
                          top: 2.0,
                        ), 
                        child: const Icon(
                          Icons.event_available,
                          color: Color(0xFF00C8A0),
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),

                      // Text (Company Name & Job Title)
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
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: Colors.grey[600],
                                      height: 2.0,
                                    ),
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

          // Scrollable Content
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  // Month Navigation
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    color: Colors.grey[50],
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.chevron_left),
                          onPressed: () {
                            _onMonthChanged(
                              DateTime(
                                _currentMonth.year,
                                _currentMonth.month - 1,
                              ),
                            );
                          },
                        ),
                        Text(
                          DateFormat('MMMM yyyy').format(_currentMonth),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.chevron_right),
                          onPressed: () {
                            _onMonthChanged(
                              DateTime(
                                _currentMonth.year,
                                _currentMonth.month + 1,
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),

                  // Calendar Legend
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    color: Colors.grey[50],
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        LegendItem(
                          color: Colors.green,
                          label: 'Available',
                        ),
                        const SizedBox(width: 24),
                        LegendItem(
                          color: const Color(0xFFFF0000),
                          label: 'Unavailable',
                        ),
                        const SizedBox(width: 24),
                        LegendItem(color: Colors.amber[700]!, label: 'Pending'),
                      ],
                    ),
                  ),

                  // Calendar with real-time updates
                  Container(
                    padding: const EdgeInsets.all(16),
                    color: Colors.white,
                    child: StreamBuilder<List<AvailabilitySlot>>(
                      stream: _availabilityService
                          .streamAvailableSlotsForRecruiters(
                            {_selectedRecruiterId!},
                            startDate: _getMonthRange(_currentMonth).start,
                            endDate: _getMonthRange(_currentMonth).end,
                          ),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }

                        final userId = _authService.currentUserId;
                        final slots = snapshot.data ?? [];
                        
                        // Filter slots to only show booked slots for this specific application
                        final applicationId = _selectedApplication?.id;
                        final filteredSlots = applicationId != null
                            ? slots.where((slot) {
                                // Show available slots (no matchId yet)
                                if (slot.isAvailable && slot.bookedBy == null) {
                                  return true;
                                }
                                // Show booked slots only if they match this application
                                if (slot.bookedBy != null && slot.matchId == applicationId) {
                                  return true;
                                }
                                // Hide other booked slots
                                return false;
                              }).toList()
                            : slots;
                        
                        // Filter slots by post event date range if application is selected
                        return FutureBuilder<Post?>(
                          future: _selectedApplication != null
                              ? _postService.getById(_selectedApplication!.postId)
                              : Future<Post?>.value(null),
                          builder: (context, postSnapshot) {
                            final post = postSnapshot.data;
                            
                            // Filter slots by post event end date (allow booking before event starts)
                            final dateFilteredSlots = filteredSlots.where((slot) {
                              // Check if slot date is before or on event end date
                              if (post != null && post.eventEndDate != null) {
                                final slotDateOnly = DateTime(slot.date.year, slot.date.month, slot.date.day);
                                final eventEndDateOnly = DateTime(
                                  post.eventEndDate!.year,
                                  post.eventEndDate!.month,
                                  post.eventEndDate!.day,
                                );
                                
                                // Only check if slot date is after event end date
                                if (slotDateOnly.isAfter(eventEndDateOnly)) {
                                  return false; // Slot is after event end date
                                }
                              }
                              return true; // If no event end date, show all slots
                            }).toList();
                            
                            final processed = _processSlots(dateFilteredSlots);

                            // Get booked dates for this jobseeker and specific application
                            return FutureBuilder<Set<DateTime>>(
                              key: ValueKey('booked_dates_jobseeker_${applicationId ?? 'all'}_$_refreshKey'),
                              future: _availabilityService
                                  .getBookedDatesForJobseeker(
                                    userId,
                                    startDate: _getMonthRange(_currentMonth).start,
                                    endDate: _getMonthRange(_currentMonth).end,
                                    matchId: applicationId, // Filter by selected application
                                  ),
                              builder: (context, bookedSnapshot) {
                                // Get pending dates for jobseeker for this specific application
                                return FutureBuilder<Set<String>>(
                                  future: _availabilityService
                                      .getRequestedSlotIdsForJobseeker(
                                        userId,
                                        matchId: applicationId, // Filter by selected application
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
                                      availableDates: pendingData
                                          .availableDatesExcludingPending,
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

                  // Available Time Slots for Selected Date
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          'Available Slots - ${DateFormat('MMMM d, yyyy').format(_selectedDate)}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      JobseekerSlotsList(
                        selectedDate: _selectedDate,
                        selectedRecruiterId: _selectedRecruiterId,
                        selectedApplication: _selectedApplication,
                        availabilityService: _availabilityService,
                        authService: _authService,
                        applicationService: _applicationService,
                        postService: _postService,
                        onBooked: () {
                          // Force refresh of booked dates and calendar
                          setState(() {
                            _refreshKey++;
                          });
                        },
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ],
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
        // Header
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
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Colors.black,
                  ),
                ),
              ),
            ],
          ),
        ),

        // Recruiter List
        Expanded(
          child: StreamBuilder<List<Application>>(
            stream: _applicationService.streamMyApplications(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: 64,
                        color: Colors.grey[300],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Unable to load recruiters',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
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
                      Icon(
                        Icons.info_outline,
                        size: 64,
                        color: Colors.grey[300],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No approved matches',
                        style: TextStyle(color: Colors.grey[600], fontSize: 16),
                      ),
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: Text(
                          'You need to be approved by a recruiter to book interview slots',
                          style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 12,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                );
              }

              // Group applications by recruiter
              final Map<String, List<Application>> recruiterApplications = {};
              for (final app in approvedApplications) {
                recruiterApplications.putIfAbsent(app.recruiterId, () => []).add(app);
              }

              return FutureBuilder<Map<String, dynamic>>(
                future: _loadPostsAndRecruitersForApplications(
                  approvedApplications,
                ),
                builder: (context, dataSnapshot) {
                  if (dataSnapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final data = dataSnapshot.data ?? {};
                  final recruitersMap =
                      data['recruiters'] as Map<String, Map<String, dynamic>>? ??
                      {};

                  final uniqueRecruiters = recruiterApplications.keys.toList();

                  return ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: uniqueRecruiters.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final recruiterId = uniqueRecruiters[index];
                      final recruiterApps = recruiterApplications[recruiterId]!;
                      final count = recruiterApps.length;
                      
                      final recruiterData = recruitersMap[recruiterId] ?? {};
                      final fullName =
                          recruiterData['fullName'] as String? ??
                          recruiterData['professionalProfile'] as String? ??
                          'Unknown';

                      return Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.grey[200]!,
                          ),
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
                                  // 1. BRANDED ICON BOX
                                  Container(
                                    width: 50,
                                    height: 50,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF00C8A0)
                                          .withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Icon(
                                      Icons.business_center,
                                      color: Color(0xFF00C8A0),
                                      size: 24,
                                    ),
                                  ),
                                  const SizedBox(width: 16),

                                  // 2. TEXT CONTENT
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
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

                                  // 4. ARROW
                                  Icon(
                                    Icons.chevron_right,
                                    color: Colors.grey[300],
                                    size: 24,
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
              );
            },
          ),
        ),
      ],
    );
  }

  //Build application list for selected recruiter
  Widget _buildApplicationList() {
    return Column(
      children: [
        // Header with back button
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
                  icon: const Icon(
                    Icons.arrow_back,
                    color: Color(0xFF00C8A0),
                  ),
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
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Colors.black,
                  ),
                ),
              ),
            ],
          ),
        ),

        // Application List
        Expanded(
          child: StreamBuilder<List<Application>>(
            stream: _applicationService.streamMyApplications(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: 64,
                        color: Colors.grey[300],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Unable to load applications',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                );
              }

              final applications = snapshot.data ?? [];
              final approvedApplicationsForRecruiter = applications
                  .where((app) =>
                      app.status == ApplicationStatus.approved &&
                      app.recruiterId == _selectedRecruiterId)
                  .toList();

              if (approvedApplicationsForRecruiter.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 64,
                        color: Colors.grey[300],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No approved applications',
                        style: TextStyle(color: Colors.grey[600], fontSize: 16),
                      ),
                    ],
                  ),
                );
              }

              return FutureBuilder<Map<String, dynamic>>(
                future: _loadPostsAndRecruitersForApplications(
                  approvedApplicationsForRecruiter,
                ),
                builder: (context, dataSnapshot) {
                  if (dataSnapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final data = dataSnapshot.data ?? {};
                  final postsMap = data['posts'] as Map<String, Post>? ?? {};
                  final recruitersMap =
                      data['recruiters'] as Map<String, Map<String, dynamic>>? ??
                      {};

                  return ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: approvedApplicationsForRecruiter.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final application =
                          approvedApplicationsForRecruiter[index];
                      final post = postsMap[application.postId];
                      final recruiterData =
                          recruitersMap[application.recruiterId] ?? {};
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
                          border: Border.all(
                            color: Colors.grey[200]!,
                          ),
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
                                // Cache recruiter name for quick access
                                _recruiterNameCache[application.recruiterId] = fullName;
                              });
                            },
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                children: [
                                  // 1. BRANDED ICON BOX
                                  Container(
                                    width: 50,
                                    height: 50,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF00C8A0)
                                          .withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Icon(
                                      Icons.work_outline,
                                      color: Color(0xFF00C8A0),
                                      size: 24,
                                    ),
                                  ),
                                  const SizedBox(width: 16),

                                  // 2. TEXT CONTENT
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
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

                                        // 3. STATUS BADGE
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFE8F5E9),
                                            borderRadius:
                                                BorderRadius.circular(6),
                                            border: Border.all(
                                              color: const Color(0xFFC8E6C9),
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Icon(
                                                Icons.check_circle,
                                                size: 12,
                                                color: Color(0xFF2E7D32),
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                'Approved',
                                                style: TextStyle(
                                                  color: Colors.green[800],
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                  // 4. ARROW
                                  Icon(
                                    Icons.chevron_right,
                                    color: Colors.grey[300],
                                    size: 24,
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
              );
            },
          ),
        ),
      ],
    );
  }

  // Load post data and recruiter data for approved applications
  Future<Map<String, dynamic>> _loadPostsAndRecruitersForApplications(
    List<Application> applications,
  ) async {
    final Map<String, Post> postsMap = {};
    final Map<String, Map<String, dynamic>> recruitersMap = {};
    final Set<String> recruiterIds = applications
        .map((app) => app.recruiterId)
        .toSet();

    // Load posts
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

    // Load recruiter user documents
    final firestore = FirebaseFirestore.instance;
    for (final recruiterId in recruiterIds) {
      try {
        final userDoc = await firestore
            .collection('users')
            .doc(recruiterId)
            .get();
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

  /// Load display data for selected application (recruiter name and job title)
  Future<Map<String, dynamic>> _loadApplicationDisplayData(Application application) async {
    // Get recruiter name from cache or load it
    String? fullName = _recruiterNameCache[application.recruiterId];
    if (fullName == null) {
      try {
        final recruiterData = await _loadPostsAndRecruitersForApplications([application]);
        final recruitersMap = recruiterData['recruiters'] as Map<String, Map<String, dynamic>>? ?? {};
        final recruiterDataMap = recruitersMap[application.recruiterId] ?? {};
        fullName = recruiterDataMap['fullName'] as String? ??
            recruiterDataMap['professionalProfile'] as String? ??
            'Unknown';
        _recruiterNameCache[application.recruiterId] = fullName;
      } catch (e) {
        fullName = 'Unknown';
      }
    }

    // Get job title from cache or load it
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

    return {
      'fullName': fullName,
      'jobTitle': jobTitle ?? 'Job Position',
    };
  }
}


