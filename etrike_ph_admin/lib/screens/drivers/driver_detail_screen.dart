import 'package:file_picker/file_picker.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/admin_tokens.dart';
import '../../models/admin_models.dart';
import '../../providers/admin_provider.dart';
import '../../widgets/admin_chart_tooltips.dart';
import '../../widgets/admin_ui.dart';
import '../../models/onboarding_models.dart';
import '../../widgets/document_status_badge.dart';
import '../../widgets/driver_schedule_panel.dart';
import '../../widgets/onboarding_progress.dart';
import '../../widgets/driver_shift_setup_card.dart';

class DriverDetailScreen extends ConsumerStatefulWidget {
  const DriverDetailScreen({
    super.key,
    required this.driverId,
    this.scrollToReviews = false,
    this.initialTab,
  });

  final String driverId;
  final bool scrollToReviews;
  final String? initialTab;

  @override
  ConsumerState<DriverDetailScreen> createState() => _DriverDetailScreenState();
}

class _DriverDetailScreenState extends ConsumerState<DriverDetailScreen> {
  final _acknowledged = <String>{};

  int get _initialTabIndex {
    if (widget.scrollToReviews) return 2;
    return switch (widget.initialTab) {
      'performance' => 1,
      'ratings' => 2,
      'documents' => 3,
      'hr' => 4,
      'disciplinary' => 5,
      'activity' => 6,
      _ => 0,
    };
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(driverAdminProfileProvider(widget.driverId));

    return DefaultTabController(
      length: 7,
      initialIndex: _initialTabIndex,
      child: Scaffold(
        backgroundColor: AdminTokens.background,
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.canPop() ? context.pop() : context.go('/'),
          ),
          title: const Text('Driver profile'),
          actions: [
            IconButton(
              tooltip: 'Refresh',
              onPressed: () {
                ref.invalidate(driverAdminProfileProvider(widget.driverId));
                ref.invalidate(driverDocumentsProvider(widget.driverId));
                ref.invalidate(driverPipelineProvider(widget.driverId));
              },
              icon: const Icon(Icons.refresh),
            ),
          ],
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: 'Overview'),
              Tab(text: 'Performance'),
              Tab(text: 'Ratings'),
              Tab(text: 'Documents'),
              Tab(text: 'HR & Payroll'),
              Tab(text: 'Disciplinary'),
              Tab(text: 'Activity'),
            ],
          ),
        ),
        body: profileAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Error: $e')),
          data: (profile) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (profile.expiredDocumentLabels.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                  child: _ReviewBanner(
                    color: AdminTokens.critical,
                    text:
                        'This driver has expired documents: ${profile.expiredDocumentLabels.join(', ')}. Operations may be affected.',
                  ),
                ),
              if (profile.expiringSoonDocumentLabels.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                  child: _ReviewBanner(
                    color: AdminTokens.watch,
                    text:
                        'Documents expiring soon: ${profile.expiringSoonDocumentLabels.join(', ')}.',
                  ),
                ),
              if (profile.reviewStatus == ReviewStatus.critical)
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                  child: _ReviewBanner(
                    color: AdminTokens.critical,
                    text:
                        'This driver has a critical rating. Review their recent trips and consider a coaching session or suspension.',
                  ),
                )
              else if (profile.reviewStatus == ReviewStatus.watch)
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                  child: _ReviewBanner(
                    color: AdminTokens.watch,
                    text:
                        "This driver's rating has declined recently. Monitor closely over the next 7 days.",
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                child: _HeaderSection(profile: profile),
              ),
              Expanded(
                child: TabBarView(
                  children: [
                    _OverviewTab(profile: profile, driverId: widget.driverId),
                    _PerformanceTab(profile: profile),
                    _RatingsTab(
                      profile: profile,
                      acknowledged: _acknowledged,
                      onMarkReviewed: _markReviewed,
                    ),
                    _DocumentsTab(driverId: widget.driverId),
                    _HrTab(profile: profile, driverId: widget.driverId),
                    const _PlaceholderTab(
                      title: 'Disciplinary',
                      message: 'Incident records will appear here after HR SQL is extended.',
                    ),
                    _ActivityTab(entries: profile.activityLog),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _markReviewed(String tripId) async {
    setState(() => _acknowledged.add(tripId));
    try {
      await ref.read(adminRepositoryProvider).acknowledgeTripReview(tripId);
      ref.invalidate(driverAdminProfileProvider(widget.driverId));
      ref.invalidate(auditLogsProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Review marked as acknowledged')),
      );
    }
  }
}

class _OverviewTab extends StatelessWidget {
  const _OverviewTab({required this.profile, required this.driverId});

  final DriverProfile profile;
  final String driverId;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        _PerformanceStats(profile: profile),
        const SizedBox(height: 20),
        DriverShiftSetupCard(driverId: driverId),
        const SizedBox(height: 20),
        _TripHistoryChart(data: profile.tripsLast30Days),
        const SizedBox(height: 20),
        DriverSchedulePanel(driverId: driverId),
        const SizedBox(height: 20),
        _RecentTripsTable(trips: profile.recentTrips),
      ],
    );
  }
}

class _RatingsTab extends StatelessWidget {
  const _RatingsTab({
    required this.profile,
    required this.acknowledged,
    required this.onMarkReviewed,
  });

  final DriverProfile profile;
  final Set<String> acknowledged;
  final void Function(String tripId) onMarkReviewed;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        _RatingsSection(
          profile: profile,
          acknowledged: acknowledged,
          onMarkReviewed: onMarkReviewed,
        ),
      ],
    );
  }
}

class _HrTab extends StatelessWidget {
  const _HrTab({required this.profile, required this.driverId});

  final DriverProfile profile;
  final String driverId;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        _HrSection(profile: profile),
      ],
    );
  }
}

class _ActivityTab extends StatelessWidget {
  const _ActivityTab({required this.entries});

  final List<ActivityLogEntry> entries;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return const Center(child: Text('No activity logged yet.'));
    }
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [_ActivityLog(entries: entries)],
    );
  }
}

class _PerformanceTab extends StatelessWidget {
  const _PerformanceTab({required this.profile});

  final DriverProfile profile;

  @override
  Widget build(BuildContext context) {
    final weekly = <int>[];
    for (var w = 0; w < 4; w++) {
      final start = 29 - (w + 1) * 7;
      final end = 29 - w * 7;
      var sum = 0;
      for (var i = start; i < end && i < profile.tripsLast30Days.length; i++) {
        if (i >= 0) sum += profile.tripsLast30Days[i].count;
      }
      weekly.insert(0, sum);
    }

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        AdminPanelCard(
          title: 'Trips per week (last 4 weeks)',
          child: SizedBox(
            height: 220,
            child: BarChart(
              BarChartData(
                barTouchData: AdminChartTooltips.barTouchData(),
                alignment: BarChartAlignment.spaceAround,
                maxY: ((weekly.isEmpty ? 0 : weekly.reduce((a, b) => a > b ? a : b)) + 4).toDouble(),
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
                      getTitlesWidget: (v, _) => Text(
                        'W${v.toInt() + 1}',
                        style: const TextStyle(fontSize: 11, color: AdminTokens.textSecondary),
                      ),
                    ),
                  ),
                ),
                barGroups: List.generate(weekly.length, (i) {
                  return BarChartGroupData(
                    x: i,
                    barRods: [
                      BarChartRodData(
                        toY: weekly[i].toDouble(),
                        color: AdminTokens.accent,
                        width: 28,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                      ),
                    ],
                  );
                }),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            AdminStatCard(
              label: 'Avg trips / day (month)',
              value: profile.avgTripsPerDayMonth.toStringAsFixed(1),
            ),
            AdminStatCard(
              label: 'Avg fare / trip',
              value: profile.totalTrips > 0
                  ? '₱${(profile.totalEarnings / profile.totalTrips).toStringAsFixed(0)}'
                  : '—',
            ),
            AdminStatCard(
              label: 'Overall rating',
              value: profile.totalReviews > 0 ? '${profile.overallRating.toStringAsFixed(1)}★' : '—',
            ),
          ],
        ),
      ],
    );
  }
}

class _DocumentsTab extends ConsumerWidget {
  const _DocumentsTab({required this.driverId});

  final String driverId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final docsAsync = ref.watch(driverDocumentsProvider(driverId));
    final pipelineAsync = ref.watch(driverPipelineProvider(driverId));

    return docsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (docs) {
        final checklist = computeChecklistPercent(docs);
        final pipeline = pipelineAsync.valueOrNull ??
            const HiringPipelineState(stage: HiringStage.application);

        return ListView(
          padding: const EdgeInsets.all(24),
          children: [
            OnboardingProgressHeader(
              pipeline: pipeline.copyWith(checklistPercent: checklist),
              checklistPercent: checklist,
              onSendReminder: () async {
                await ref.read(onboardingRepositoryProvider).sendReminder(
                      driverId: driverId,
                      summary: 'Reminder sent from driver profile',
                    );
                ref.invalidate(driverPipelineProvider(driverId));
              },
              onSetDeadline: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: DateTime.now().add(const Duration(days: 14)),
                  firstDate: DateTime.now(),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                );
                if (picked == null) return;
                await ref.read(onboardingRepositoryProvider).setDeadline(
                      driverId: driverId,
                      date: picked,
                      kind: 'onboarding',
                    );
                ref.invalidate(driverPipelineProvider(driverId));
              },
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: kRequiredDriverDocuments.map((type) {
                final row = docs.cast<DriverDocumentRow?>().firstWhere(
                      (d) => d?.docType == type,
                      orElse: () => null,
                    );
                final status = row?.status ??
                    (type.doesNotExpire ? DocumentStatus.doesNotExpire : DocumentStatus.pending);
                final days = row?.daysUntilExpiry;

                return SizedBox(
                  width: 300,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: AdminTokens.cardDecoration,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(type.label, style: const TextStyle(fontWeight: FontWeight.w600)),
                        const SizedBox(height: 8),
                        DocumentStatusBadge(status: status),
                        if (row?.documentNumber != null) ...[
                          const SizedBox(height: 8),
                          Text('No. ${row!.documentNumber}', style: const TextStyle(fontSize: 12)),
                        ],
                        if (row?.expiryDate != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            'Expires ${DateFormat.yMMMd().format(row!.expiryDate!)}'
                            '${days != null ? ' ($days days)' : ''}',
                            style: TextStyle(
                              fontSize: 12,
                              color: days != null && days < 30
                                  ? AdminTokens.critical
                                  : days != null && days < 60
                                      ? AdminTokens.watch
                                      : AdminTokens.textSecondary,
                            ),
                          ),
                        ],
                        if (row?.adminNotes != null && row!.adminNotes!.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(row.adminNotes!, style: const TextStyle(fontSize: 12, color: AdminTokens.textSecondary)),
                        ],
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          children: [
                            if (row?.fileUrl != null)
                              OutlinedButton(
                                onPressed: () => launchUrl(Uri.parse(row!.fileUrl!)),
                                child: const Text('View file'),
                              ),
                            OutlinedButton(
                              onPressed: () => _uploadRenewal(context, ref, type),
                              child: const Text('Upload renewal'),
                            ),
                            if (row != null && row.status == DocumentStatus.pending)
                              FilledButton.tonal(
                                onPressed: () async {
                                  await ref.read(onboardingRepositoryProvider).verifyDocument(
                                        documentId: row.id,
                                        driverId: driverId,
                                        status: DocumentStatus.verified,
                                      );
                                  ref.invalidate(driverDocumentsProvider(driverId));
                                },
                                child: const Text('Verify'),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        );
      },
    );
  }

  Future<void> _uploadRenewal(BuildContext context, WidgetRef ref, DocumentType type) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    if (file.bytes == null) return;
    await ref.read(onboardingRepositoryProvider).upsertDocument(
          driverId: driverId,
          docType: type,
          fileBytes: file.bytes!,
          fileName: file.name,
        );
    ref.invalidate(driverDocumentsProvider(driverId));
    ref.invalidate(driverAdminProfileProvider(driverId));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${type.label} uploaded')),
      );
    }
  }
}

class _PlaceholderTab extends StatelessWidget {
  const _PlaceholderTab({required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: AdminPanelCard(title: title, child: Text(message, style: const TextStyle(color: AdminTokens.textSecondary))),
      ),
    );
  }
}

class _ReviewBanner extends StatelessWidget {
  const _ReviewBanner({required this.color, required this.text});

  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.warning_amber_rounded, color: color),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: TextStyle(color: color.withValues(alpha: 0.9), height: 1.4))),
        ],
      ),
    );
  }
}

class _HeaderSection extends StatelessWidget {
  const _HeaderSection({required this.profile});

  final DriverProfile profile;

  @override
  Widget build(BuildContext context) {
    final joined = DateFormat.yMMMd().format(profile.joinedAt);
    final statusColor = switch (profile.statusLabel) {
      'Active' => AdminTokens.accent,
      'On Leave' => AdminTokens.watch,
      'Revoked' => AdminTokens.critical,
      _ => AdminTokens.textSecondary,
    };

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: AdminTokens.cardDecoration,
      child: LayoutBuilder(
        builder: (context, c) {
          final stacked = c.maxWidth < 500;
          final avatarRow = Row(
            children: [
              DriverAvatar(name: profile.fullName, radius: 32),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(profile.fullName, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Text(
                      '${profile.badgeNumber}${profile.plate != null ? ' · ${profile.plate}' : ''}',
                      style: const TextStyle(color: AdminTokens.textSecondary),
                    ),
                    if (profile.email != null)
                      Text(profile.email!, style: const TextStyle(fontSize: 13, color: AdminTokens.textSecondary)),
                  ],
                ),
              ),
              if (!stacked) StatusPill(label: profile.statusLabel, color: statusColor),
            ],
          );

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (stacked) ...[avatarRow, const SizedBox(height: 12), StatusPill(label: profile.statusLabel, color: statusColor)]
              else avatarRow,
              const SizedBox(height: 12),
              Text('Joined $joined', style: const TextStyle(fontSize: 13, color: AdminTokens.textSecondary)),
              if (profile.unitNumber != null)
                Text(
                  'Company e-trike unit ${profile.unitNumber}',
                  style: const TextStyle(fontSize: 13, color: AdminTokens.textSecondary),
                ),
              Text(
                '${profile.employmentType} · ${profile.shiftSchedule}',
                style: const TextStyle(fontSize: 13, color: AdminTokens.textSecondary),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _PerformanceStats extends StatelessWidget {
  const _PerformanceStats({required this.profile});

  final DriverProfile profile;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        AdminStatCard(label: 'Total trips (all time)', value: '${profile.totalTrips}'),
        AdminStatCard(label: 'Trips this month', value: '${profile.tripsThisMonth}'),
        AdminStatCard(
          label: 'Total earnings (all time)',
          value: '₱${profile.totalEarnings.toStringAsFixed(0)}',
        ),
        AdminStatCard(
          label: 'Avg trips / day (this month)',
          value: profile.avgTripsPerDayMonth.toStringAsFixed(1),
        ),
      ],
    );
  }
}

class _TripHistoryChart extends StatelessWidget {
  const _TripHistoryChart({required this.data});

  final List<DailyTripCount> data;

  @override
  Widget build(BuildContext context) {
    return AdminPanelCard(
      title: 'Trip history — last 30 days',
      child: SizedBox(
        height: 220,
        child: LineChart(
          LineChartData(
            lineTouchData: AdminChartTooltips.lineTouchData(),
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              getDrawingHorizontalLine: (_) => FlLine(
                color: Colors.black.withValues(alpha: 0.06),
                strokeWidth: 1,
              ),
            ),
            titlesData: FlTitlesData(
              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 24,
                  getTitlesWidget: (v, _) => Text(
                    v.toInt().toString(),
                    style: const TextStyle(fontSize: 10, color: AdminTokens.textSecondary),
                  ),
                ),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  interval: 7,
                  getTitlesWidget: (v, _) {
                    final i = v.toInt();
                    if (i < 0 || i >= data.length) return const SizedBox.shrink();
                    return Text(
                      '${data[i].date.month}/${data[i].date.day}',
                      style: const TextStyle(fontSize: 10, color: AdminTokens.textSecondary),
                    );
                  },
                ),
              ),
            ),
            borderData: FlBorderData(show: false),
            lineBarsData: [
              LineChartBarData(
                spots: List.generate(
                  data.length,
                  (i) => FlSpot(i.toDouble(), data[i].count.toDouble()),
                ),
                isCurved: true,
                color: AdminTokens.accent,
                barWidth: 3,
                dotData: const FlDotData(show: false),
                belowBarData: BarAreaData(
                  show: true,
                  color: AdminTokens.accent.withValues(alpha: 0.08),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RatingsSection extends StatelessWidget {
  const _RatingsSection({
    required this.profile,
    required this.acknowledged,
    required this.onMarkReviewed,
  });

  final DriverProfile profile;
  final Set<String> acknowledged;
  final void Function(String tripId) onMarkReviewed;

  @override
  Widget build(BuildContext context) {
    final complaintDelta = profile.complaintsLast7d - profile.complaintsPrev7d;
    final deltaLabel = complaintDelta > 0
        ? '↑ from ${profile.complaintsPrev7d}'
        : complaintDelta < 0
            ? '↓ from ${profile.complaintsPrev7d}'
            : 'same as prev week';
    final hasReviews = profile.totalReviews > 0;
    final unratedTrips = profile.totalTrips - profile.totalReviews;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Ratings & feedback', style: Theme.of(context).textTheme.titleMedium),
        if (!hasReviews && profile.totalTrips > 0)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              '$unratedTrips completed trip${unratedTrips == 1 ? '' : 's'} — no passenger ratings yet.',
              style: const TextStyle(fontSize: 12, color: AdminTokens.textSecondary),
            ),
          ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            AdminStatCard(
              label: 'Overall rating',
              value: hasReviews ? profile.overallRating.toStringAsFixed(1) : '—',
              subLabel: hasReviews ? '★ average' : 'No ratings yet',
            ),
            AdminStatCard(
              label: 'Complaints (last 7 days)',
              value: '${profile.complaintsLast7d}',
              delta: deltaLabel,
              deltaPositive: complaintDelta <= 0,
            ),
            AdminStatCard(label: 'Total reviews', value: '${profile.totalReviews}'),
            AdminStatCard(
              label: '1–2★ trips (last 30 days)',
              value: '${profile.lowRatingCount30d}',
              subLabel: '${profile.lowRatingPercent30d.toStringAsFixed(0)}% of month trips',
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (hasReviews)
          Align(
            alignment: Alignment.centerLeft,
            child: StarRatingDisplay(rating: profile.overallRating, size: 20),
          ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, c) {
            final wide = c.maxWidth >= 800;
            final complaints = _ComplaintBars(summary: profile.complaintSummary);
            final reviews = _LowRatingList(
              reviews: profile.lowRatingReviews,
              recentTrips: profile.recentTrips,
              acknowledged: acknowledged,
              onMarkReviewed: onMarkReviewed,
            );
            if (wide) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: complaints),
                  const SizedBox(width: 16),
                  Expanded(child: reviews),
                ],
              );
            }
            return Column(
              children: [complaints, const SizedBox(height: 16), reviews],
            );
          },
        ),
      ],
    );
  }
}

class _ComplaintBars extends StatelessWidget {
  const _ComplaintBars({required this.summary});

  final List<ComplaintCount> summary;

  @override
  Widget build(BuildContext context) {
    final sorted = [...summary]..sort((a, b) => b.count.compareTo(a.count));
    final top = sorted.take(5).toList();
    final max = top.isEmpty ? 1 : top.first.count;

    return AdminPanelCard(
      title: 'Top complaint reasons',
      child: top.isEmpty
          ? const Text(
              'No complaint tags recorded yet.',
              style: TextStyle(color: AdminTokens.textSecondary, fontSize: 13),
            )
          : Column(
        children: top.map((c) {
          final widthFactor = c.count / max;
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Text(c.tag, style: const TextStyle(fontSize: 13))),
                    Text('${c.count}', style: const TextStyle(fontWeight: FontWeight.w600)),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: widthFactor,
                    minHeight: 8,
                    backgroundColor: AdminTokens.complaintBar.withValues(alpha: 0.15),
                    color: AdminTokens.complaintBar,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _LowRatingList extends StatelessWidget {
  const _LowRatingList({
    required this.reviews,
    required this.recentTrips,
    required this.acknowledged,
    required this.onMarkReviewed,
  });

  final List<TripRecord> reviews;
  final List<TripRecord> recentTrips;
  final Set<String> acknowledged;
  final void Function(String tripId) onMarkReviewed;

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat.yMMMd();
    if (reviews.isEmpty) {
      final unrated = recentTrips.where((t) => t.rating == null).toList();
      final rated = recentTrips.where((t) => t.rating != null).toList();
      return AdminPanelCard(
        title: 'Recent trip feedback',
        child: recentTrips.isEmpty
            ? const Text(
                'No completed trips yet.',
                style: TextStyle(color: AdminTokens.textSecondary),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (unrated.isNotEmpty) ...[
                    Text(
                      '${unrated.length} trip${unrated.length == 1 ? '' : 's'} awaiting passenger rating',
                      style: const TextStyle(fontSize: 12, color: AdminTokens.textSecondary),
                    ),
                    const SizedBox(height: 10),
                    ...unrated.take(5).map((t) => _TripFeedbackTile(trip: t, fmt: fmt)),
                  ],
                  if (rated.isNotEmpty && unrated.isNotEmpty) const SizedBox(height: 12),
                  if (rated.isNotEmpty) ...[
                    if (rated.every((t) => (t.rating ?? 5) > 3))
                      const Text(
                        'No low ratings (1–3★) on recent trips.',
                        style: TextStyle(fontSize: 12, color: AdminTokens.textSecondary),
                      ),
                    ...rated
                        .where((t) => (t.rating ?? 5) <= 3)
                        .take(5)
                        .map((t) => _TripFeedbackTile(trip: t, fmt: fmt, showReview: true)),
                  ],
                ],
              ),
      );
    }

    return AdminPanelCard(
      title: 'Recent low ratings',
      child: Column(
              children: reviews.take(5).map((r) {
                final done = acknowledged.contains(r.id) || r.reviewAcknowledged;
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AdminTokens.background,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          StarRatingDisplay(rating: r.rating ?? 0, size: 14),
                          const Spacer(),
                          Text(fmt.format(r.date), style: const TextStyle(fontSize: 12, color: AdminTokens.textSecondary)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        r.reviewText?.isNotEmpty == true ? r.reviewText! : 'No comment left',
                        style: const TextStyle(fontSize: 13, height: 1.4),
                      ),
                      if (r.complaintTags.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: r.complaintTags
                              .map(
                                (t) => Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: AdminTokens.critical.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(t, style: const TextStyle(fontSize: 11, color: AdminTokens.critical)),
                                ),
                              )
                              .toList(),
                        ),
                      ],
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: done ? null : () => onMarkReviewed(r.id),
                        child: Text(done ? 'Reviewed' : 'Mark as reviewed'),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
    );
  }
}

class _TripFeedbackTile extends StatelessWidget {
  const _TripFeedbackTile({
    required this.trip,
    required this.fmt,
    this.showReview = false,
  });

  final TripRecord trip;
  final DateFormat fmt;
  final bool showReview;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AdminTokens.background,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${trip.pickup} → ${trip.dropoff}',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '₱${trip.fare.toStringAsFixed(0)}',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Text(fmt.format(trip.date), style: const TextStyle(fontSize: 12, color: AdminTokens.textSecondary)),
              const Spacer(),
              if (trip.rating != null)
                StarRatingDisplay(rating: trip.rating!, size: 14)
              else
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AdminTokens.watch.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'Unrated',
                    style: TextStyle(fontSize: 11, color: AdminTokens.watch),
                  ),
                ),
            ],
          ),
          if (showReview && trip.reviewText?.isNotEmpty == true) ...[
            const SizedBox(height: 6),
            Text(trip.reviewText!, style: const TextStyle(fontSize: 12, height: 1.35)),
          ],
        ],
      ),
    );
  }
}

class _RecentTripsTable extends StatelessWidget {
  const _RecentTripsTable({required this.trips});

  final List<TripRecord> trips;

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat.MMMd().add_jm();
    return AdminPanelCard(
      title: 'Recent trips (${trips.length})',
      child: trips.isEmpty
          ? const Text(
              'No completed trips to show.',
              style: TextStyle(color: AdminTokens.textSecondary),
            )
          : Column(
              children: trips.take(10).map((t) {
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    '${t.pickup} → ${t.dropoff}',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                  ),
                  subtitle: Text(
                    '${fmt.format(t.date)} · ${t.durationMinutes} min · ₱${t.fare.toStringAsFixed(0)}',
                    style: const TextStyle(fontSize: 12),
                  ),
                  trailing: t.rating != null
                      ? StarRatingDisplay(rating: t.rating!, size: 14)
                      : const Text('Unrated', style: TextStyle(fontSize: 11, color: AdminTokens.textSecondary)),
                );
              }).toList(),
            ),
    );
  }
}

class _HrSection extends StatelessWidget {
  const _HrSection({required this.profile});

  final DriverProfile profile;

  @override
  Widget build(BuildContext context) {
    return AdminPanelCard(
      title: 'HR & leave',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _HrRow('Station / depot', profile.station),
          _HrRow('Employment type', profile.employmentType),
          _HrRow('Assigned shift', profile.shiftSchedule),
          _HrRow('Contact number', profile.contactNumber),
          _HrRow('Emergency contact', profile.emergencyContact),
          const SizedBox(height: 16),
          Text('Leave balance', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 10),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              AdminStatCard(
                label: 'Sick leave remaining',
                value: '${profile.sickLeaveRemaining} days',
                minWidth: 140,
              ),
              AdminStatCard(
                label: 'Vacation leave remaining',
                value: '${profile.vacationLeaveRemaining} days',
                minWidth: 140,
              ),
              AdminStatCard(
                label: 'Taken this year',
                value: '${profile.leaveTakenThisYear} days',
                minWidth: 140,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HrRow extends StatelessWidget {
  const _HrRow(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(label, style: const TextStyle(color: AdminTokens.textSecondary, fontSize: 13)),
          ),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }
}

class _ActivityLog extends StatelessWidget {
  const _ActivityLog({required this.entries});

  final List<ActivityLogEntry> entries;

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat.yMMMd().add_jm();
    return AdminPanelCard(
      title: 'Activity log',
      child: Column(
        children: entries.map((e) {
          return ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.history, size: 20, color: AdminTokens.textSecondary),
            title: Text(e.action, style: const TextStyle(fontSize: 13)),
            subtitle: Text(fmt.format(e.date), style: const TextStyle(fontSize: 12)),
          );
        }).toList(),
      ),
    );
  }
}
