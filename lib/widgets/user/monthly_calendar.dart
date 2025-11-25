import 'package:flutter/material.dart';

class MonthlyCalendar extends StatelessWidget {
  final DateTime currentMonth;
  final DateTime? selectedDate;
  final Set<DateTime> availableDates;
  final Set<DateTime> bookedDates;
  final Set<DateTime> addedSlotDates; // For recruiters - dates with added slots
  final Set<DateTime> pendingDates; // Dates with pending booking requests
  final Function(DateTime) onDateSelected;
  final Function(DateTime) onDateTapped;

  const MonthlyCalendar({
    super.key,
    required this.currentMonth,
    this.selectedDate,
    this.availableDates = const {},
    this.bookedDates = const {},
    this.addedSlotDates = const {},
    this.pendingDates = const {},
    required this.onDateSelected,
    required this.onDateTapped,
  });

  @override
  Widget build(BuildContext context) {
    final firstDayOfMonth = DateTime(currentMonth.year, currentMonth.month, 1);
    final lastDayOfMonth = DateTime(
      currentMonth.year,
      currentMonth.month + 1,
      0,
    );
    final firstDayWeekday = firstDayOfMonth.weekday;
    final daysInMonth = lastDayOfMonth.day;

    final weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    return Column(
      children: [
        // Weekday headers
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          child: Row(
            children: weekdays.map((day) {
              return Expanded(
                child: Center(
                  child: Text(
                    day,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[700],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 8),
        // Calendar grid
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          child: Column(
            children: [
              for (var week = 0; week < 6; week++)
                Row(
                  children: [
                    for (var day = 0; day < 7; day++)
                      Expanded(
                        child: _buildDayCell(
                          week: week,
                          day: day,
                          firstDayWeekday: firstDayWeekday,
                          daysInMonth: daysInMonth,
                          firstDayOfMonth: firstDayOfMonth,
                        ),
                      ),
                  ],
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDayCell({
    required int week,
    required int day,
    required int firstDayWeekday,
    required int daysInMonth,
    required DateTime firstDayOfMonth,
  }) {
    // firstDayWeekday is 1-7 (Mon=1, Sun=7), but we need 0-6 (Mon=0, Sun=6)
    // Convert: Mon=1 -> 0, Tue=2 -> 1, ..., Sun=7 -> 6
    final adjustedFirstDay = (firstDayWeekday - 1) % 7;
    final dayNumber = week * 7 + day - adjustedFirstDay + 1;

    if (dayNumber < 1 || dayNumber > daysInMonth) {
      return const SizedBox(height: 48);
    }

    // Normalize date to remove time component for accurate comparison
    final date = DateTime(
      firstDayOfMonth.year,
      firstDayOfMonth.month,
      dayNumber,
    );

    final isSelected =
        selectedDate != null &&
        selectedDate!.year == date.year &&
        selectedDate!.month == date.month &&
        selectedDate!.day == date.day;

    final isAvailable = availableDates.any(
      (d) => d.year == date.year && d.month == date.month && d.day == date.day,
    );

    final isBooked = bookedDates.any(
      (d) => d.year == date.year && d.month == date.month && d.day == date.day,
    );

    final hasAddedSlot = addedSlotDates.any(
      (d) => d.year == date.year && d.month == date.month && d.day == date.day,
    );

    final hasPending = pendingDates.any(
      (d) => d.year == date.year && d.month == date.month && d.day == date.day,
    );

    final isToday =
        date.year == DateTime.now().year &&
        date.month == DateTime.now().month &&
        date.day == DateTime.now().day;

    final isPast = date.isBefore(
      DateTime.now().subtract(const Duration(days: 1)),
    );

    Color? backgroundColor;
    Color? textColor;
    Color? borderColor;
    double? borderWidth;
    List<Widget> cornerIndicators = [];

    // Determine background and text colors first
    // Priority: booked > pending > available > selected > addedSlot > past
    // When selected, show full color for booked/pending/available dates
    if (isBooked) {
      backgroundColor = isSelected ? Colors.red[600] : Colors.red[50];
      textColor = isSelected ? Colors.white : Colors.red[800];
      borderColor = Colors.red[700];
      borderWidth = isSelected ? 2.5 : 2;
    } else if (hasPending) {
      backgroundColor = isSelected ? Colors.amber[600] : Colors.amber[50];
      textColor = isSelected ? Colors.white : Colors.amber[800];
      borderColor = Colors.amber[700];
      borderWidth = isSelected ? 2.5 : 2;
    } else if (isAvailable) {
      backgroundColor = isSelected ? Colors.green[600] : Colors.green[50];
      textColor = isSelected ? Colors.white : Colors.green[800];
      borderColor = Colors.green[700];
      borderWidth = isSelected ? 2.5 : 2;
    } else if (isSelected) {
      backgroundColor = const Color(0xFF00C8A0);
      textColor = Colors.white;
      borderColor = const Color(0xFF00C8A0);
      borderWidth = 2.5;
    } else if (hasAddedSlot) {
      backgroundColor = Colors.blue[50];
      textColor = Colors.blue[800];
      borderColor = Colors.blue;
      borderWidth = 2;
    } else if (isPast) {
      backgroundColor = Colors.grey[100];
      textColor = Colors.grey[400];
    } else {
      textColor = Colors.black87;
    }

    // Add corner indicators based on status (show multiple if date has multiple statuses)
    // Show all applicable indicators
    final List<Color> indicatorColors = [];

    if (isBooked) {
      indicatorColors.add(Colors.red);
    }
    if (hasPending) {
      indicatorColors.add(Colors.amber[700]!);
    }
    if (isAvailable) {
      indicatorColors.add(Colors.green);
    }
    if (hasAddedSlot) {
      indicatorColors.add(Colors.blue);
    }

    // If multiple indicators, arrange them horizontally
    if (indicatorColors.length == 1) {
      // Single indicator
      cornerIndicators.add(
        Positioned(
          top: 1,
          right: 1,
          child: Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(
              color: indicatorColors[0],
              shape: BoxShape.circle,
              border: Border.all(
                color: isSelected ? Colors.white : Colors.white,
                width: isSelected ? 2 : 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 2,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
          ),
        ),
      );
    } else if (indicatorColors.length > 1) {
      // Multiple indicators - arrange horizontally
      double startRight = 1;
      for (int i = 0; i < indicatorColors.length; i++) {
        cornerIndicators.add(
          Positioned(
            top: 1,
            right: startRight,
            child: Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: indicatorColors[i],
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? Colors.white : Colors.white,
                  width: isSelected ? 2 : 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 2,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
            ),
          ),
        );
        startRight += 10; // Space between indicators
      }
    }

    return GestureDetector(
      onTap: isPast ? null : () => onDateTapped(date),
      child: Container(
        height: 48,
        margin: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(8),
          border: isToday && !isSelected
              ? Border.all(color: const Color(0xFF00C8A0), width: 2)
              : (borderColor != null && !isSelected)
              ? Border.all(color: borderColor, width: borderWidth ?? 2)
              : (isSelected
                    ? Border.all(
                        color: borderColor ?? const Color(0xFF00C8A0),
                        width: borderWidth ?? 2.5,
                      )
                    : null),
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Center(
              child: Text(
                '$dayNumber',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: isSelected || isToday
                      ? FontWeight.bold
                      : FontWeight.normal,
                  color: textColor,
                ),
              ),
            ),
            ...cornerIndicators,
          ],
        ),
      ),
    );
  }
}
