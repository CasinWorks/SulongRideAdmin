import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_decorations.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../providers/hr_provider.dart';
import '../../components/primary_button.dart';

class AttendanceScreen extends ConsumerWidget {
  const AttendanceScreen({super.key});

  String _formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    if (h > 0) return '${h}h ${m}m';
    return '${m}m';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final openAsync = ref.watch(openAttendanceProvider);
    final historyAsync = ref.watch(attendanceHistoryProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Time in / out', style: AppTextStyles.headingSm),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
      ),
      body: RefreshIndicator(
        color: AppColors.accent,
        onRefresh: () async {
          ref.invalidate(openAttendanceProvider);
          ref.invalidate(attendanceHistoryProvider);
          ref.invalidate(driverStatsProvider);
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'Clock in at the start of your shift and clock out when you finish. This is recorded for HR and payroll.',
              style: AppTextStyles.bodySecondary.copyWith(height: 1.4),
            ),
            const SizedBox(height: 20),
            openAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Text('$e'),
              data: (open) {
                final timedIn = open != null;
                return Container(
                  padding: const EdgeInsets.all(20),
                  decoration: AppDecorations.ecoCard,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Icon(
                            timedIn ? Icons.play_circle_filled : Icons.pause_circle_outline,
                            color: timedIn ? AppColors.accent : AppColors.textSecondary,
                            size: 28,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              timedIn ? 'You are timed in' : 'You are timed out',
                              style: AppTextStyles.headingSm.copyWith(fontSize: 18),
                            ),
                          ),
                        ],
                      ),
                      if (open case final record?) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Since ${DateFormat.yMMMd().add_jm().format(record.clockIn.toLocal())}',
                          style: AppTextStyles.bodySecondary,
                        ),
                      ],
                      const SizedBox(height: 20),
                      PrimaryButton(
                        label: timedIn ? 'Time out' : 'Time in',
                        useAccent: !timedIn,
                        onPressed: () async {
                          try {
                            final repo = ref.read(hrRepositoryProvider);
                            if (timedIn) {
                              await repo.clockOut();
                            } else {
                              await repo.clockIn();
                            }
                            ref.invalidate(openAttendanceProvider);
                            ref.invalidate(attendanceHistoryProvider);
                            ref.invalidate(driverStatsProvider);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(timedIn ? 'Timed out' : 'Timed in — have a safe shift!'),
                                ),
                              );
                            }
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('$e')),
                              );
                            }
                          }
                        },
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 28),
            Text('Recent shifts', style: AppTextStyles.headingSm.copyWith(fontSize: 16)),
            const SizedBox(height: 12),
            historyAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Text('$e'),
              data: (rows) {
                if (rows.isEmpty) {
                  return Text('No attendance records yet.', style: AppTextStyles.bodySecondary);
                }
                return Column(
                  children: rows.map((r) {
                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(14),
                      decoration: AppDecorations.ecoCard,
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  DateFormat.yMMMd().format(r.clockIn.toLocal()),
                                  style: AppTextStyles.body,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${DateFormat.jm().format(r.clockIn.toLocal())}'
                                  '${r.clockOut != null ? ' – ${DateFormat.jm().format(r.clockOut!.toLocal())}' : ' – active'}',
                                  style: AppTextStyles.bodySecondary.copyWith(fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            _formatDuration(r.duration),
                            style: AppTextStyles.label.copyWith(color: AppColors.accent),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
