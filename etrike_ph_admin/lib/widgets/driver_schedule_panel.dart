import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/admin_tokens.dart';
import '../../models/roster_models.dart';
import '../../providers/admin_provider.dart';
import '../../widgets/admin_month_calendar.dart';
import '../../widgets/admin_ui.dart';
import '../../widgets/roster_status_chip.dart';

class DriverSchedulePanel extends ConsumerStatefulWidget {
  const DriverSchedulePanel({super.key, required this.driverId});

  final String driverId;

  @override
  ConsumerState<DriverSchedulePanel> createState() => _DriverSchedulePanelState();
}

class _DriverSchedulePanelState extends ConsumerState<DriverSchedulePanel> {
  var _focusedMonth = DateTime.now();
  var _selectedDay = DateTime.now();

  DateTime get _month => DateTime(_focusedMonth.year, _focusedMonth.month, 1);
  DateTime get _dayOnly =>
      DateTime(_selectedDay.year, _selectedDay.month, _selectedDay.day);

  @override
  Widget build(BuildContext context) {
    final scheduleAsync = ref.watch(driverScheduleProvider((widget.driverId, _month)));
    final countsAsync = ref.watch(monthShiftCountsProvider(_month));

    return scheduleAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Padding(
        padding: const EdgeInsets.all(24),
        child: Text('Schedule unavailable: $e'),
      ),
      data: (days) {
        final counts = countsAsync.maybeWhen(data: (m) => m, orElse: () => <DateTime, int>{});
        final selected = days.cast<DriverScheduleDay?>().firstWhere(
              (d) =>
                  d!.date.year == _dayOnly.year &&
                  d.date.month == _dayOnly.month &&
                  d.date.day == _dayOnly.day,
              orElse: () => null,
            );

        return AdminPanelCard(
          title: 'Schedule & attendance',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AdminMonthCalendar(
                focusedDay: _focusedMonth,
                selectedDay: _dayOnly,
                shiftCounts: counts,
                onDaySelected: (d) => setState(() => _selectedDay = d),
                onPageChanged: (m) => setState(() => _focusedMonth = m),
              ),
              const SizedBox(height: 16),
              if (selected != null) _DayDetail(day: selected) else const Text('No data for this day.'),
            ],
          ),
        );
      },
    );
  }
}

class _DayDetail extends StatelessWidget {
  const _DayDetail({required this.day});

  final DriverScheduleDay day;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AdminTokens.background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '${day.date.month}/${day.date.day}/${day.date.year}',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              RosterStatusChip(status: day.status, compact: true),
            ],
          ),
          if (day.leaveType != null) ...[
            const SizedBox(height: 8),
            Text('Approved leave: ${day.leaveType}', style: const TextStyle(fontSize: 13)),
          ] else if (day.status == DriverDayStatus.offDuty &&
              day.attendanceBlocks.isEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Not a scheduled work day',
              style: TextStyle(fontSize: 12, color: AdminTokens.textSecondary),
            ),
          ],
          if (day.attendanceBlocks.isNotEmpty) ...[
            const SizedBox(height: 8),
            const Text('Time in / out', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            ...day.attendanceBlocks.map((b) {
              final inT = TimeOfDay.fromDateTime(b.clockIn.toLocal());
              final outT =
                  b.clockOut != null ? TimeOfDay.fromDateTime(b.clockOut!.toLocal()) : null;
              return Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '${inT.format(context)} → ${outT?.format(context) ?? 'active'}',
                  style: const TextStyle(fontSize: 12, color: AdminTokens.textSecondary),
                ),
              );
            }),
          ],
          if (day.attendanceBlocks.isEmpty && day.leaveType == null)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text('No attendance recorded.', style: TextStyle(fontSize: 12)),
            ),
        ],
      ),
    );
  }
}
