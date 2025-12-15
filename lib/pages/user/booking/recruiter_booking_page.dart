import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../services/user/availability_service.dart';
import '../../../services/user/auth_service.dart';
import '../../../services/user/application_service.dart';
import '../../../services/user/post_service.dart';
import '../../../services/user/matching_service.dart';
import '../../../models/user/availability_slot.dart';
import '../../../models/user/booking_request.dart';
import '../../../widgets/user/monthly_calendar.dart';
import '../../../widgets/user/legend_item.dart';
import '../../../widgets/user/time_slot_card.dart';
import '../../../widgets/admin/dialogs/user_dialogs/add_slot_dialog.dart';
import '../../../widgets/admin/dialogs/user_dialogs/booking_requests_dialog.dart';

class RecruiterBookingPage extends StatefulWidget {
  const RecruiterBookingPage({super.key});

  @override
  State<RecruiterBookingPage> createState() => _RecruiterBookingPageState();
}

class _RecruiterBookingPageState extends State<RecruiterBookingPage> {
  final AvailabilityService _availabilityService = AvailabilityService();
  final AuthService _authService = AuthService();
  final ApplicationService _applicationService = ApplicationService();
  final PostService _postService = PostService();
  final MatchingService _matchingService = MatchingService();

  DateTime _selectedDate = DateTime.now();
  DateTime _currentMonth = DateTime.now();

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

  Future<void> _refreshData() async {
    setState(() {
    });
    await Future.delayed(const Duration(milliseconds: 100));
  }

  static DateTime _normalizeDate(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  static DateTime _slotDate(AvailabilitySlot slot) {
    return _normalizeDate(slot.date);
  }

  ({DateTime start, DateTime end}) _getMonthRange(DateTime month) {
    return (
      start: DateTime(month.year, month.month, 1),
      end: DateTime(month.year, month.month + 1, 0),
    );
  }

  ({DateTime start, DateTime end}) _getDayRange(DateTime date) {
    return (
      start: DateTime(date.year, date.month, date.day),
      end: DateTime(date.year, date.month, date.day, 23, 59, 59),
    );
  }

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
              const Icon(Icons.calendar_today, color: Color(0xFF00C8A0)),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Set Interview Availability',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Colors.black,
                  ),
                ),
              ),
              IconButton(
                icon: StreamBuilder<int>(
                  stream: _availabilityService
                      .streamBookingRequestsForRecruiter()
                      .map(
                        (requests) => requests
                            .where(
                              (r) => r.status == BookingRequestStatus.pending,
                            )
                            .length,
                      ),
                  builder: (context, snapshot) {
                    final count = snapshot.data ?? 0;
                    return Stack(
                      children: [
                        Icon(
                          Icons.notifications_outlined,
                          color: const Color(0xFF00C8A0),
                        ),
                        if (count > 0)
                          Positioned(
                            right: 0,
                            top: 0,
                            child: Container(
                              padding: const EdgeInsets.all(2),
                              decoration: const BoxDecoration(
                                color: Colors.red,
                                shape: BoxShape.circle,
                              ),
                              constraints: const BoxConstraints(
                                minWidth: 16,
                                minHeight: 16,
                              ),
                              child: Text(
                                count > 9 ? '9+' : count.toString(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                ),
                tooltip: 'View Booking Requests',
                onPressed: () => _showBookingRequestsDialog(),
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
                      const SizedBox(width: 16),
                      LegendItem(
                        color: const Color(0xFFFF0000),
                        label: 'Unavailable',
                      ),
                      const SizedBox(width: 16),
                      LegendItem(color: Colors.amber[700]!, label: 'Pending'),
                      const SizedBox(width: 16),
                      LegendItem(color: Colors.blue, label: 'Added Slot'),
                    ],
                  ),
                ),

                Container(
                  padding: const EdgeInsets.all(16),
                  color: Colors.white,
                  child: StreamBuilder<List<AvailabilitySlot>>(
                    stream: _availabilityService.streamAvailabilitySlots(
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

                      final slots = snapshot.data ?? [];
                      final processed = _processSlots(slots);
                      return StreamBuilder<Set<String>>(
                        stream: _availabilityService
                            .streamRequestedSlotIdsForRecruiter(
                              _authService.currentUserId,
                            ),
                        builder: (context, pendingSnapshot) {
                          final pendingData = _preparePendingDates(
                            slots,
                            pendingSnapshot.data ?? {},
                            processed.availableDates,
                          );

                          return MonthlyCalendar(
                            currentMonth: _currentMonth,
                            selectedDate: _selectedDate,
                            availableDates: pendingData
                                .availableDatesExcludingPending,
                            bookedDates: processed.bookedDates,
                            addedSlotDates: processed.allDates,
                            pendingDates: pendingData.pendingDates,
                            onDateSelected: _onDateSelected,
                            onDateTapped: _onDateTapped,
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
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Time Slots - ${DateFormat('MMMM d, yyyy').format(_selectedDate)}',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          ElevatedButton.icon(
                            onPressed: _showAddSlotDialog,
                            icon: const Icon(Icons.add, size: 18),
                            label: const Text('Add Slot'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF00C8A0),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 10,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    StreamBuilder<List<AvailabilitySlot>>(
                      stream: _availabilityService.streamAvailabilitySlots(
                        startDate: _getDayRange(_selectedDate).start,
                        endDate: _getDayRange(_selectedDate).end,
                      ),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Padding(
                            padding: EdgeInsets.all(32.0),
                            child: Center(child: CircularProgressIndicator()),
                          );
                        }

                        final slots = snapshot.data ?? [];

                        if (slots.isEmpty) {
                          return Center(
                            child: Padding(
                              padding: const EdgeInsets.all(32.0),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.schedule,
                                    size: 64,
                                    color: Colors.grey[300],
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'No time slots for this date',
                                    style: TextStyle(color: Colors.grey[600]),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Tap "Add Slot" to create availability',
                                    style: TextStyle(
                                      color: Colors.grey[500],
                                      fontSize: 12,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),
                          );
                        }


                        return StreamBuilder<Set<String>>(
                          stream: _availabilityService
                              .streamRequestedSlotIdsForRecruiter(
                                _authService.currentUserId,
                              ),
                          builder: (context, requestedSnapshot) {
                            if (requestedSnapshot.connectionState == ConnectionState.waiting) {
                              return const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(32.0),
                                  child: CircularProgressIndicator(
                                    color: Color(0xFF00C8A0),
                                  ),
                                ),
                              );
                            }
                            
                            final requestedSlotIds =
                                requestedSnapshot.data ?? {};

                            return Column(
                              children: slots.map((slot) {
                                final hasPendingRequest = requestedSlotIds
                                    .contains(slot.id);
                                return Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                  ),
                                  child: TimeSlotCard(
                                    slot: slot,
                                    isRecruiter: true,
                                    hasPendingRequest: hasPendingRequest,
                                    onToggle: (isAvailable) async {
                                      try {
                                        await _availabilityService
                                            .toggleAvailabilitySlot(
                                              slot.id,
                                              isAvailable,
                                            );
                                      } catch (e) {
                                        if (mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              content: Text(e.toString().replaceFirst('Exception: ', '')),
                                              backgroundColor: Colors.red,
                                              duration: const Duration(seconds: 3),
                                            ),
                                          );
                                        }
                                      }
                                    },
                                    onDelete: () async {
                                      await _availabilityService
                                          .deleteAvailabilitySlot(slot.id);
                                    },
                                    applicationService: _applicationService,
                                    authService: _authService,
                                    postService: _postService,
                                    availabilityService: _availabilityService,
                                  ),
                                );
                              }).toList(),
                            );
                          },
                        );
                      },
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
    );
  }

  void _showAddSlotDialog() {
    showDialog(
      context: context,
      builder: (context) => AddSlotDialog(
        selectedDate: _selectedDate,
        onSave: (date, startTime, endTime) async {
          await _availabilityService.createAvailabilitySlot(
            date: date,
            startTime: startTime,
            endTime: endTime,
          );
        },
      ),
    );
  }

  void _showBookingRequestsDialog() {
    showDialog(
      context: context,
      builder: (context) => BookingRequestsDialog(
        availabilityService: _availabilityService,
        applicationService: _applicationService,
        authService: _authService,
        postService: _postService,
        matchingService: _matchingService,
      ),
    );
  }
}

