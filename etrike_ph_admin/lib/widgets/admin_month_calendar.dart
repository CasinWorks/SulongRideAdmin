import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';

import '../core/theme/admin_tokens.dart';

class AdminMonthCalendar extends StatelessWidget {
  const AdminMonthCalendar({
    super.key,
    required this.focusedDay,
    required this.selectedDay,
    required this.onDaySelected,
    required this.onPageChanged,
    this.shiftCounts = const {},
  });

  final DateTime focusedDay;
  final DateTime selectedDay;
  final ValueChanged<DateTime> onDaySelected;
  final ValueChanged<DateTime> onPageChanged;
  final Map<DateTime, int> shiftCounts;

  DateTime _dayOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: AdminTokens.cardDecoration,
      child: TableCalendar<void>(
        firstDay: DateTime.utc(2024, 1, 1),
        lastDay: DateTime.utc(2030, 12, 31),
        focusedDay: focusedDay,
        selectedDayPredicate: (day) => isSameDay(selectedDay, day),
        calendarFormat: CalendarFormat.month,
        startingDayOfWeek: StartingDayOfWeek.monday,
        headerStyle: const HeaderStyle(
          formatButtonVisible: false,
          titleCentered: true,
          titleTextStyle: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
        ),
        daysOfWeekStyle: const DaysOfWeekStyle(
          weekdayStyle: TextStyle(fontSize: 12, color: AdminTokens.textSecondary),
          weekendStyle: TextStyle(fontSize: 12, color: AdminTokens.textSecondary),
        ),
        calendarStyle: CalendarStyle(
          outsideDaysVisible: false,
          todayDecoration: BoxDecoration(
            color: AdminTokens.accent.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          todayTextStyle: const TextStyle(color: AdminTokens.accent, fontWeight: FontWeight.w600),
          selectedDecoration: const BoxDecoration(
            color: AdminTokens.accent,
            shape: BoxShape.circle,
          ),
          selectedTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
          markerDecoration: const BoxDecoration(
            color: AdminTokens.accent,
            shape: BoxShape.circle,
          ),
          markersMaxCount: 1,
        ),
        onDaySelected: (selected, focused) => onDaySelected(_dayOnly(selected)),
        onPageChanged: (focused) => onPageChanged(_dayOnly(focused)),
        calendarBuilders: CalendarBuilders(
          markerBuilder: (context, day, events) {
            final count = shiftCounts[_dayOnly(day)];
            if (count == null || count == 0) return null;
            return Positioned(
              bottom: 1,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: AdminTokens.accent.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$count',
                  style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: AdminTokens.accent),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
