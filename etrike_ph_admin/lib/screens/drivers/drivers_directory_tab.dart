import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/theme/admin_tokens.dart';
import '../../models/roster_models.dart';
import '../../providers/admin_provider.dart';
import '../../widgets/admin_ui.dart';
import '../../widgets/roster_status_chip.dart';

class DriversDirectoryTab extends ConsumerStatefulWidget {
  const DriversDirectoryTab({
    super.key,
    this.onboardingOnly = false,
    this.onFilterApplied,
  });

  final bool onboardingOnly;
  final VoidCallback? onFilterApplied;

  @override
  ConsumerState<DriversDirectoryTab> createState() => _DriversDirectoryTabState();
}

class _DriversDirectoryTabState extends ConsumerState<DriversDirectoryTab> {
  var _filter = _DriverFilter.all;
  var _query = '';

  @override
  void initState() {
    super.initState();
    if (widget.onboardingOnly) {
      _filter = _DriverFilter.onboarding;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        widget.onFilterApplied?.call();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(driversDirectoryProvider);

    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (entries) {
        var list = entries;
        if (_filter != _DriverFilter.all) {
          list = list.where((e) => _matchesFilter(e, _filter)).toList();
        }
        if (_query.trim().isNotEmpty) {
          final q = _query.toLowerCase();
          list = list
              .where(
                (e) =>
                    e.driver.fullName.toLowerCase().contains(q) ||
                    e.driver.email.toLowerCase().contains(q) ||
                    e.driver.station.toLowerCase().contains(q) ||
                    (e.driver.trikePlateNumber ?? '').toLowerCase().contains(q),
              )
              .toList();
        }

        return ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text('Drivers', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 4),
            Text(
              '${entries.length} total · ${entries.where((e) => e.todayStatus == DriverDayStatus.onShift).length} on shift today',
              style: const TextStyle(color: AdminTokens.textSecondary),
            ),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: () => context.push('/drivers/register'),
                icon: const Icon(Icons.person_add_outlined, size: 18),
                label: const Text('Register driver'),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              decoration: InputDecoration(
                hintText: 'Search name, email, station, plate…',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: _DriverFilter.values.map((f) {
                final selected = _filter == f;
                return FilterChip(
                  label: Text(f.label),
                  selected: selected,
                  onSelected: (_) => setState(() => _filter = f),
                  selectedColor: AdminTokens.accent.withValues(alpha: 0.15),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
            if (list.isEmpty)
              const Text('No drivers match your filters.')
            else
              ...list.map((e) => _DriverCard(
                    entry: e,
                    onTap: () => context.push('/drivers/${e.driver.id}'),
                  )),
          ],
        );
      },
    );
  }

  bool _matchesFilter(DriverDirectoryEntry e, _DriverFilter f) => switch (f) {
        _DriverFilter.all => true,
        _DriverFilter.onShift => e.todayStatus == DriverDayStatus.onShift,
        _DriverFilter.online => e.isOnline,
        _DriverFilter.onLeave =>
          e.todayStatus == DriverDayStatus.onLeaveVl ||
          e.todayStatus == DriverDayStatus.onLeaveSl,
        _DriverFilter.offDuty => e.todayStatus == DriverDayStatus.offDuty,
        _DriverFilter.approved => e.driver.approvalStatus == 'approved',
        _DriverFilter.pending => e.driver.approvalStatus == 'pending',
        _DriverFilter.onboarding => e.driver.approvalStatus == 'pending',
      };
}

enum _DriverFilter {
  all('All'),
  onShift('On shift'),
  online('Online'),
  onLeave('On leave'),
  offDuty('Off duty'),
  approved('Approved'),
  pending('Pending'),
  onboarding('Onboarding');

  const _DriverFilter(this.label);
  final String label;
}

class _DriverCard extends StatelessWidget {
  const _DriverCard({required this.entry, required this.onTap});

  final DriverDirectoryEntry entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final d = entry.driver;
    final fmt = DateFormat.yMMMd();
    final start = d.startDate ?? d.createdAt;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Ink(
            decoration: AdminTokens.cardDecoration,
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DriverAvatar(name: d.fullName.isNotEmpty ? d.fullName : d.email, radius: 26),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              d.fullName.isNotEmpty ? d.fullName : d.email,
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                            ),
                          ),
                          RosterStatusChip(status: entry.todayStatus, compact: true),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(d.email, style: const TextStyle(fontSize: 12, color: AdminTokens.textSecondary)),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          _InfoChip(icon: Icons.location_on_outlined, label: d.station),
                          _InfoChip(icon: Icons.badge_outlined, label: d.employmentLabel),
                          _InfoChip(icon: Icons.schedule, label: d.shiftSchedule),
                          if (d.trikePlateNumber != null)
                            _InfoChip(icon: Icons.electric_moped, label: d.trikePlateNumber!),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          OnlineDot(online: entry.isOnline),
                          const SizedBox(width: 16),
                          if (entry.overallRating != null)
                            StarRatingDisplay(rating: entry.overallRating!, size: 14),
                          if (entry.totalReviews > 0) ...[
                            const SizedBox(width: 6),
                            Text(
                              '(${entry.totalReviews})',
                              style: const TextStyle(fontSize: 11, color: AdminTokens.textSecondary),
                            ),
                          ],
                        ],
                      ),
                      if (entry.leaveTypeToday != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          'On approved ${entry.leaveTypeToday} today',
                          style: const TextStyle(fontSize: 12, color: AdminTokens.watch),
                        ),
                      ],
                      const SizedBox(height: 8),
                      Text(
                        'Start ${start != null ? fmt.format(start) : '—'} · ${d.phone ?? 'No phone'}',
                        style: const TextStyle(fontSize: 11, color: AdminTokens.textSecondary),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: AdminTokens.textSecondary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AdminTokens.background,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AdminTokens.textSecondary),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(fontSize: 11)),
        ],
      ),
    );
  }
}
