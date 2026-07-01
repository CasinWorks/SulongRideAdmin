import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/theme/admin_tokens.dart';
import '../../models/admin_models.dart';
import '../../widgets/admin_chart_tooltips.dart';
import '../../widgets/admin_ui.dart';

class FleetOverviewTab extends StatelessWidget {
  const FleetOverviewTab({
    super.key,
    required this.data,
    required this.onReviewPending,
    required this.onReviewLeave,
    required this.onTopDrivers,
    required this.onViewDriver,
    required this.onSeeAllReviews,
    this.onApproveBonuses,
    this.onRegisterDriver,
    this.onOnboardingPipeline,
  });

  final FleetOverviewData data;
  final VoidCallback onReviewPending;
  final VoidCallback onReviewLeave;
  final VoidCallback onTopDrivers;
  final void Function(String driverId) onViewDriver;
  final void Function(String driverId) onSeeAllReviews;
  final VoidCallback? onApproveBonuses;
  final VoidCallback? onRegisterDriver;
  final VoidCallback? onOnboardingPipeline;

  @override
  Widget build(BuildContext context) {
    final tripDelta = data.tripsToday - data.tripsYesterday;
    final tripDeltaLabel =
        '${tripDelta >= 0 ? '+' : ''}$tripDelta vs yesterday';

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 900;
        return ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text('Fleet overview', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                AdminStatCard(
                  label: 'Active drivers',
                  value: '${data.activeDrivers}',
                  subLabel: '${data.pendingApproval} pending approval',
                  minWidth: wide ? 170 : 150,
                ),
                AdminStatCard(
                  label: 'Trips today',
                  value: '${data.tripsToday}',
                  delta: tripDeltaLabel,
                  deltaPositive: tripDelta >= 0,
                  minWidth: wide ? 170 : 150,
                ),
                AdminStatCard(
                  label: 'Total fares today',
                  value: '₱${data.faresToday.toStringAsFixed(0)}',
                  minWidth: wide ? 170 : 150,
                ),
                AdminStatCard(
                  label: 'Avg fare per trip today',
                  value: '₱${data.avgFareToday.toStringAsFixed(0)}',
                  minWidth: wide ? 170 : 150,
                ),
                AdminStatCard(
                  label: 'Drivers on duty now',
                  value: '${data.driversOnDuty}',
                  subLabel: 'Live count',
                  minWidth: wide ? 170 : 150,
                ),
                AdminStatCard(
                  label: 'Total payroll this period',
                  value: data.payrollThisPeriod != null
                      ? '₱${data.payrollThisPeriod!.toStringAsFixed(0)}'
                      : '—',
                  subLabel: '${data.payrollDriverCount} drivers included',
                  minWidth: wide ? 170 : 150,
                ),
              ],
            ),
            const SizedBox(height: 24),
            if (wide)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _TripActivityChart(data: data.tripsLast7Days)),
                  const SizedBox(width: 16),
                  Expanded(child: _DriverStatusChart(breakdown: data.driverStatus)),
                ],
              )
            else ...[
              _TripActivityChart(data: data.tripsLast7Days),
              const SizedBox(height: 16),
              _DriverStatusChart(breakdown: data.driverStatus),
            ],
            const SizedBox(height: 24),
            Text('Flagged items', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            ...data.flaggedItems.map((item) => FlaggedAlertRow(item: item)),
            const SizedBox(height: 24),
            Text('Drivers needing review', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            if (data.driversNeedingReview.isEmpty)
              const Text('No drivers flagged for rating review.', style: TextStyle(color: AdminTokens.textSecondary))
            else
              ...data.driversNeedingReview.map(
                (d) => _DriverReviewRow(
                  flag: d,
                  onViewProfile: () => onViewDriver(d.driverId),
                  onSeeReviews: () => onSeeAllReviews(d.driverId),
                ),
              ),
            const SizedBox(height: 24),
            Text('Quick actions', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                FilledButton.tonal(onPressed: onReviewPending, child: const Text('Review pending drivers')),
                FilledButton.tonal(onPressed: onReviewLeave, child: const Text('Review leave requests')),
                FilledButton.tonal(onPressed: onTopDrivers, child: const Text('View top drivers this week')),
                if (onApproveBonuses != null)
                  FilledButton.tonal(
                    onPressed: onApproveBonuses,
                    child: Text(
                      data.pendingBonusesCount > 0
                          ? 'Approve pending bonuses (${data.pendingBonusesCount})'
                          : 'Approve pending bonuses',
                    ),
                  ),
                if (onRegisterDriver != null)
                  FilledButton(
                    onPressed: onRegisterDriver,
                    child: const Text('Register new driver'),
                  ),
                if (onOnboardingPipeline != null)
                  FilledButton.tonal(
                    onPressed: onOnboardingPipeline,
                    child: const Text('Onboarding pipeline'),
                  ),
              ],
            ),
            if (data.topDriversThisWeek.isNotEmpty) ...[
              const SizedBox(height: 28),
              Text('Top drivers this week', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              AdminPanelCard(
                title: 'By completed trips',
                child: Column(
                  children: [
                    for (var i = 0; i < data.topDriversThisWeek.length; i++) ...[
                      if (i > 0) const Divider(height: 1),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(
                          backgroundColor: AdminTokens.accent.withValues(alpha: 0.15),
                          child: Text(
                            '${i + 1}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              color: AdminTokens.accent,
                            ),
                          ),
                        ),
                        title: Text(data.topDriversThisWeek[i].name),
                        trailing: Text(
                          '${data.topDriversThisWeek[i].trips} trips',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        onTap: () => onViewDriver(data.topDriversThisWeek[i].id),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

class _TripActivityChart extends StatelessWidget {
  const _TripActivityChart({required this.data});

  final List<DailyTripCount> data;

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat.E();
    return AdminPanelCard(
      title: 'Trip activity (last 7 days)',
      child: SizedBox(
        height: 220,
        child: BarChart(
          BarChartData(
            barTouchData: AdminChartTooltips.barTouchData(),
            alignment: BarChartAlignment.spaceAround,
            maxY: (data.map((e) => e.count).reduce((a, b) => a > b ? a : b) + 6).toDouble(),
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              getDrawingHorizontalLine: (_) => FlLine(
                color: Colors.black.withValues(alpha: 0.06),
                strokeWidth: 1,
              ),
            ),
            borderData: FlBorderData(show: false),
            titlesData: FlTitlesData(
              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 28,
                  getTitlesWidget: (v, _) => Text(
                    v.toInt().toString(),
                    style: const TextStyle(fontSize: 11, color: AdminTokens.textSecondary),
                  ),
                ),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  getTitlesWidget: (v, _) {
                    final i = v.toInt();
                    if (i < 0 || i >= data.length) return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        fmt.format(data[i].date),
                        style: const TextStyle(fontSize: 11, color: AdminTokens.textSecondary),
                      ),
                    );
                  },
                ),
              ),
            ),
            barGroups: List.generate(data.length, (i) {
              return BarChartGroupData(
                x: i,
                barRods: [
                  BarChartRodData(
                    toY: data[i].count.toDouble(),
                    color: AdminTokens.accent,
                    width: 20,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                  ),
                ],
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _DriverStatusChart extends StatelessWidget {
  const _DriverStatusChart({required this.breakdown});

  final DriverStatusBreakdown breakdown;

  @override
  Widget build(BuildContext context) {
    final segments = [
      (label: 'On duty', count: breakdown.onDuty, color: AdminTokens.accent),
      (label: 'Off duty', count: breakdown.offDuty, color: const Color(0xFF9CA3AF)),
      (label: 'On leave', count: breakdown.onLeave, color: AdminTokens.watch),
      (label: 'Pending', count: breakdown.pending, color: AdminTokens.critical),
    ];

    return AdminPanelCard(
      title: 'Driver status breakdown',
      child: SizedBox(
        height: 220,
        child: Row(
          children: [
            Expanded(
              flex: 2,
              child: PieChart(
                PieChartData(
                  sectionsSpace: 2,
                  centerSpaceRadius: 36,
                  sections: segments
                      .where((s) => s.count > 0)
                      .map(
                        (s) => PieChartSectionData(
                          value: s.count.toDouble(),
                          color: s.color,
                          radius: 52,
                          title: '${((s.count / breakdown.total) * 100).round()}%',
                          titleStyle: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
            ),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: segments
                    .map(
                      (s) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(color: s.color, shape: BoxShape.circle),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '${s.label} (${s.count})',
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DriverReviewRow extends StatelessWidget {
  const _DriverReviewRow({
    required this.flag,
    required this.onViewProfile,
    required this.onSeeReviews,
  });

  final DriverReviewFlag flag;
  final VoidCallback onViewProfile;
  final VoidCallback onSeeReviews;

  @override
  Widget build(BuildContext context) {
    final borderColor = reviewStatusColor(flag.reviewStatus);
    final statusLabel = reviewStatusLabel(flag.reviewStatus);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border(left: BorderSide(color: borderColor, width: 4)),
      ),
      child: LayoutBuilder(
        builder: (context, c) {
          final stacked = c.maxWidth < 640;
          final left = Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DriverAvatar(name: flag.fullName, radius: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${flag.fullName} · ${flag.badgeNumber}',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                        StatusPill(
                          label: '$statusLabel — ${flag.overallRating.toStringAsFixed(1)}★',
                          color: borderColor,
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      flag.reasonLine,
                      style: const TextStyle(fontSize: 13, color: AdminTokens.textSecondary),
                    ),
                    if (!stacked) ...[
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        children: [
                          OutlinedButton(onPressed: onViewProfile, child: const Text('View profile')),
                          TextButton(onPressed: onSeeReviews, child: const Text('See all reviews')),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              if (!stacked) ...[
                const SizedBox(width: 12),
                Text(
                  flag.overallRating.toStringAsFixed(1),
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: borderColor,
                  ),
                ),
              ],
            ],
          );

          if (!stacked) return left;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              left,
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                children: [
                  OutlinedButton(onPressed: onViewProfile, child: const Text('View profile')),
                  TextButton(onPressed: onSeeReviews, child: const Text('See all reviews')),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}