import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/theme/admin_tokens.dart';
import '../../models/roster_models.dart';
import '../../providers/admin_provider.dart';
import '../../widgets/admin_month_calendar.dart';
import '../../widgets/admin_ui.dart';
import '../../widgets/roster_status_chip.dart';

class AttendanceRosterTab extends ConsumerStatefulWidget {
  const AttendanceRosterTab({super.key});

  @override
  ConsumerState<AttendanceRosterTab> createState() => _AttendanceRosterTabState();
}

class _AttendanceRosterTabState extends ConsumerState<AttendanceRosterTab> {
  var _selectedDay = DateTime.now();
  var _focusedMonth = DateTime.now();

  DateTime get _dayOnly => DateTime(_selectedDay.year, _selectedDay.month, _selectedDay.day);

  @override
  Widget build(BuildContext context) {
    final rosterAsync = ref.watch(rosterForDateProvider(_dayOnly));
    final countsAsync = ref.watch(monthShiftCountsProvider(
      DateTime(_focusedMonth.year, _focusedMonth.month, 1),
    ));

    return rosterAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Text('Error: $e\n\nRun fix_driver_hr.sql and fix_driver_profile_hr.sql in Supabase.'),
      ),
      data: (roster) {
        final counts = countsAsync.maybeWhen(data: (m) => m, orElse: () => <DateTime, int>{});
        final fmt = DateFormat.yMMMEd();
        final timeFmt = DateFormat.jm();

        return LayoutBuilder(
          builder: (context, c) {
            final wide = c.maxWidth >= 960;
            final calendar = AdminMonthCalendar(
              focusedDay: _focusedMonth,
              selectedDay: _dayOnly,
              shiftCounts: counts,
              onDaySelected: (d) => setState(() => _selectedDay = d),
              onPageChanged: (m) => setState(() => _focusedMonth = m),
            );

            final summary = _RosterSummaryBar(summary: roster);
            final rosterList = _RosterList(
              entries: roster.entries,
              timeFmt: timeFmt,
              onDriverTap: (id) => context.push('/drivers/$id'),
            );

            return ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Text('Attendance & roster', style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 4),
                Text(
                  fmt.format(_dayOnly),
                  style: const TextStyle(color: AdminTokens.textSecondary),
                ),
                const SizedBox(height: 16),
                if (wide)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(width: 360, child: calendar),
                      const SizedBox(width: 20),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [summary, const SizedBox(height: 16), rosterList],
                        ),
                      ),
                    ],
                  )
                else ...[
                  calendar,
                  const SizedBox(height: 16),
                  summary,
                  const SizedBox(height: 16),
                  rosterList,
                ],
                const SizedBox(height: 12),
                const _LegendRow(),
              ],
            );
          },
        );
      },
    );
  }
}

class _RosterSummaryBar extends StatelessWidget {
  const _RosterSummaryBar({required this.summary});

  final DayRosterSummary summary;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        _SummaryPill(
          label: 'On shift',
          value: '${summary.onShiftCount}',
          color: AdminTokens.accent,
        ),
        _SummaryPill(
          label: 'Online',
          value: '${summary.onlineCount}',
          color: const Color(0xFF2563EB),
        ),
        _SummaryPill(
          label: 'On leave',
          value: '${summary.onLeaveCount}',
          color: AdminTokens.watch,
        ),
        _SummaryPill(
          label: 'Off duty',
          value: '${summary.offDutyCount}',
          color: const Color(0xFF9CA3AF),
        ),
      ],
    );
  }
}

class _SummaryPill extends StatelessWidget {
  const _SummaryPill({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: color)),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(fontSize: 12, color: AdminTokens.textSecondary)),
        ],
      ),
    );
  }
}

class _RosterList extends StatelessWidget {
  const _RosterList({
    required this.entries,
    required this.timeFmt,
    required this.onDriverTap,
  });

  final List<DriverRosterEntry> entries;
  final DateFormat timeFmt;
  final void Function(String id) onDriverTap;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return const AdminPanelCard(
        title: 'Roster',
        child: Text('No drivers in the system yet.'),
      );
    }

    return AdminPanelCard(
      title: 'Roster (${entries.length} drivers)',
      child: Column(
        children: entries.map((e) => _RosterRow(entry: e, timeFmt: timeFmt, onTap: () => onDriverTap(e.driverId))).toList(),
      ),
    );
  }
}

class _RosterRow extends StatelessWidget {
  const _RosterRow({
    required this.entry,
    required this.timeFmt,
    required this.onTap,
  });

  final DriverRosterEntry entry;
  final DateFormat timeFmt;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final borderColor = rosterStatusColor(entry.status);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AdminTokens.background,
            borderRadius: BorderRadius.circular(12),
            border: Border(left: BorderSide(color: borderColor, width: 4)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DriverAvatar(name: entry.fullName, radius: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            entry.fullName,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                        RosterStatusChip(status: entry.status, compact: true),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${entry.station} · ${entry.shiftSchedule}',
                      style: const TextStyle(fontSize: 12, color: AdminTokens.textSecondary),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${entry.employmentType}'
                      '${entry.plate != null ? ' · ${entry.plate}' : ''}'
                      '${entry.overallRating != null ? ' · ${entry.overallRating!.toStringAsFixed(1)}★' : ''}',
                      style: const TextStyle(fontSize: 12, color: AdminTokens.textSecondary),
                    ),
                    if (entry.clockIn != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Clock: ${timeFmt.format(entry.clockIn!.toLocal())}'
                        '${entry.clockOut != null ? ' – ${timeFmt.format(entry.clockOut!.toLocal())}' : ' – active'}',
                        style: const TextStyle(fontSize: 11, color: AdminTokens.textSecondary),
                      ),
                    ],
                    if (entry.leaveType != null)
                      Text(
                        'Approved leave: ${entry.leaveType}',
                        style: TextStyle(fontSize: 11, color: borderColor),
                      ),
                    const SizedBox(height: 6),
                    OnlineDot(online: entry.isOnline),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AdminTokens.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}

class _LegendRow extends StatelessWidget {
  const _LegendRow();

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 16,
      runSpacing: 8,
      children: [
        for (final s in [
          DriverDayStatus.onShift,
          DriverDayStatus.online,
          DriverDayStatus.onLeaveVl,
          DriverDayStatus.onLeaveSl,
          DriverDayStatus.offDuty,
        ])
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              RosterStatusChip(status: s, compact: true),
            ],
          ),
      ],
    );
  }
}
