import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:intl/intl.dart';

import '../models/admin_models.dart';
import '../models/driver_row.dart';
import '../models/fare_config.dart';
import '../providers/admin_provider.dart';
import '../repositories/audit_repository.dart';
import '../widgets/admin_ui.dart';
import 'attendance/attendance_roster_tab.dart';
import 'audit/audit_logs_tab.dart';
import 'drivers/drivers_directory_tab.dart';
import 'overview/fleet_overview_tab.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  int _tab = 0;
  var _sortDriversByTrips = false;
  var _directoryOnboardingFilter = false;
  final _baseFare = TextEditingController();
  final _perKm = TextEditingController();
  final _minimum = TextEditingController();
  var _savingFare = false;
  String? _loadedFareId;

  @override
  void initState() {
    super.initState();
    ref.listenManual(activeFareProvider, (previous, next) {
      next.whenData(_hydrateFareFields);
    });
  }

  void _hydrateFareFields(FareConfig? fare) {
    if (fare == null || _loadedFareId == fare.id) return;
    _loadedFareId = fare.id;
    _baseFare.text = fare.baseFare.toStringAsFixed(0);
    _perKm.text = fare.perKmRate.toStringAsFixed(0);
    _minimum.text = fare.minimumFare.toStringAsFixed(0);
  }

  @override
  void dispose() {
    _baseFare.dispose();
    _perKm.dispose();
    _minimum.dispose();
    super.dispose();
  }

  Future<void> _signOut() async {
    final client = Supabase.instance.client;
    await AuditRepository(client).log(
      action: 'auth.sign_out',
      summary: 'Operator signed out',
    );
    await client.auth.signOut();
    if (mounted) context.go('/login');
  }

  Future<void> _setApproval(String driverId, String status) async {
    await ref.read(adminRepositoryProvider).setDriverApproval(
          driverId: driverId,
          status: status,
        );
    ref.invalidate(pendingDriversProvider);
    ref.invalidate(approvedDriversProvider);
    ref.invalidate(rejectedDriversProvider);
    ref.invalidate(auditLogsProvider);
    if (mounted) {
      final message = switch (status) {
        'approved' => 'Driver approved',
        'rejected' => 'Driver revoked',
        _ => 'Driver status updated',
      };
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }

  Future<void> _saveFare(String fareId) async {
    setState(() => _savingFare = true);
    try {
      await ref.read(adminRepositoryProvider).updateActiveFare(
            id: fareId,
            baseFare: double.parse(_baseFare.text),
            perKmRate: double.parse(_perKm.text),
            minimumFare: double.parse(_minimum.text),
          );
      ref.invalidate(activeFareProvider);
      ref.invalidate(auditLogsProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Fare updated')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e')),
        );
      }
    } finally {
      if (mounted) setState(() => _savingFare = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final operatorAsync = ref.watch(isOperatorProvider);

    return operatorAsync.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        body: Center(child: Text('Error: $e')),
      ),
      data: (isOperator) {
        if (!isOperator) {
          final user = Supabase.instance.client.auth.currentUser;
          final email = user?.email ?? 'unknown';
          final uid = user?.id ?? '—';
          return Scaffold(
            appBar: AppBar(title: const Text('Sulong Ride Admin')),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.admin_panel_settings_outlined, size: 48),
                      const SizedBox(height: 16),
                      const Text(
                        'This account is not an operator.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Signed in as:\n$email\n\nUser ID:\n$uid',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 13, color: Colors.black54),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'In Supabase → SQL Editor, run the insert using your email or UUID, then tap Retry.',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      SelectableText(
                        "insert into public.operators (id, email, full_name)\n"
                        "select id, email, 'Operator'\n"
                        "from auth.users\n"
                        "where email = '$email'\n"
                        "on conflict (id) do update\n"
                        "  set email = excluded.email;",
                        style: TextStyle(
                          fontSize: 12,
                          fontFamily: 'monospace',
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),
                      FilledButton(
                        onPressed: () => ref.invalidate(isOperatorProvider),
                        child: const Text('Retry'),
                      ),
                      const SizedBox(height: 8),
                      TextButton(onPressed: _signOut, child: const Text('Sign out')),
                    ],
                  ),
                ),
              ),
            ),
          );
        }

        return Scaffold(
          backgroundColor: const Color(0xFFF5F7F5),
          appBar: AppBar(
            elevation: 0,
            scrolledUnderElevation: 0,
            backgroundColor: const Color(0xFFF5F7F5),
            title: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Sulong Ride Admin', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
                Text('Operations & HR', style: TextStyle(fontSize: 12, fontWeight: FontWeight.normal, color: Colors.black54)),
              ],
            ),
            actions: [
              TextButton(onPressed: _signOut, child: const Text('Sign out')),
            ],
          ),
          body: Row(
            children: [
              NavigationRail(
                selectedIndex: _tab,
                onDestinationSelected: (i) => setState(() {
                  _tab = i;
                  if (i != 3) _sortDriversByTrips = false;
                }),
                labelType: NavigationRailLabelType.all,
                backgroundColor: const Color(0xFFF5F7F5),
                destinations: const [
                  NavigationRailDestination(
                    icon: Icon(Icons.dashboard_outlined),
                    selectedIcon: Icon(Icons.dashboard),
                    label: Text('Overview'),
                  ),
                  NavigationRailDestination(
                    icon: Icon(Icons.people_outline),
                    selectedIcon: Icon(Icons.people),
                    label: Text('Drivers'),
                  ),
                  NavigationRailDestination(
                    icon: Icon(Icons.pending_actions_outlined),
                    selectedIcon: Icon(Icons.pending_actions),
                    label: Text('Pending'),
                  ),
                  NavigationRailDestination(
                    icon: Icon(Icons.verified_user_outlined),
                    selectedIcon: Icon(Icons.verified_user),
                    label: Text('Approved'),
                  ),
                  NavigationRailDestination(
                    icon: Icon(Icons.block_outlined),
                    selectedIcon: Icon(Icons.block),
                    label: Text('Revoked'),
                  ),
                  NavigationRailDestination(
                    icon: Icon(Icons.schedule_outlined),
                    selectedIcon: Icon(Icons.schedule),
                    label: Text('Attendance'),
                  ),
                  NavigationRailDestination(
                    icon: Icon(Icons.beach_access_outlined),
                    selectedIcon: Icon(Icons.beach_access),
                    label: Text('Leave'),
                  ),
                  NavigationRailDestination(
                    icon: Icon(Icons.payments_outlined),
                    selectedIcon: Icon(Icons.payments),
                    label: Text('Fare'),
                  ),
                  NavigationRailDestination(
                    icon: Icon(Icons.history_outlined),
                    selectedIcon: Icon(Icons.history),
                    label: Text('Audit logs'),
                  ),
                ],
              ),
              const VerticalDivider(width: 1),
              Expanded(child: _buildTab()),
            ],
          ),
        );
      },
    );
  }

  Future<void> _reviewLeave(String id, String status) async {
    await ref.read(adminRepositoryProvider).reviewLeaveRequest(id: id, status: status);
    ref.invalidate(pendingLeaveProvider);
    ref.invalidate(rosterForDateProvider);
    ref.invalidate(driversDirectoryProvider);
    ref.invalidate(auditLogsProvider);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Leave ${status == 'approved' ? 'approved' : 'rejected'}')),
      );
    }
  }

  Widget _buildTab() {
    return switch (_tab) {
      0 => _buildOverviewTab(),
      1 => DriversDirectoryTab(
          onboardingOnly: _directoryOnboardingFilter,
          onFilterApplied: () => setState(() => _directoryOnboardingFilter = false),
        ),
      2 => _DriversList(
          provider: pendingDriversProvider,
          emptyLabel: 'No pending driver applications.',
          onDriverTap: (id) => context.push('/drivers/$id'),
          actions: (id) => [
            FilledButton(
              onPressed: () => _setApproval(id, 'approved'),
              child: const Text('Approve'),
            ),
            const SizedBox(width: 8),
            OutlinedButton(
              onPressed: () => _setApproval(id, 'rejected'),
              child: const Text('Reject'),
            ),
          ],
        ),
      3 => _DriversList(
          provider: approvedDriversProvider,
          emptyLabel: 'No approved drivers yet.',
          sortByTrips: _sortDriversByTrips,
          header: _sortDriversByTrips ? 'Top drivers this week' : null,
          onDriverTap: (id) => context.push('/drivers/$id'),
          actions: (id) => [
            OutlinedButton(
              onPressed: () => _setApproval(id, 'rejected'),
              child: const Text('Revoke'),
            ),
          ],
        ),
      4 => _DriversList(
          provider: rejectedDriversProvider,
          emptyLabel: 'No revoked drivers.',
          actions: (id) => [
            FilledButton(
              onPressed: () => _setApproval(id, 'approved'),
              child: const Text('Approve again'),
            ),
          ],
        ),
      5 => const AttendanceRosterTab(),
      6 => _buildLeaveTab(),
      7 => _buildFareTab(),
      8 => const AuditLogsTab(),
      _ => _buildOverviewTab(),
    };
  }

  Widget _buildOverviewTab() {
    final overviewAsync = ref.watch(fleetOverviewProvider);
    return overviewAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e\n\nRun fix_trip_ratings.sql in Supabase.')),
      data: (raw) {
        final data = FleetOverviewData(
          activeDrivers: raw.activeDrivers,
          pendingApproval: raw.pendingApproval,
          tripsToday: raw.tripsToday,
          tripsYesterday: raw.tripsYesterday,
          faresToday: raw.faresToday,
          avgFareToday: raw.avgFareToday,
          driversOnDuty: raw.driversOnDuty,
          payrollThisPeriod: raw.payrollThisPeriod,
          payrollDriverCount: raw.payrollDriverCount,
          tripsLast7Days: raw.tripsLast7Days,
          driverStatus: raw.driverStatus,
          flaggedItems: raw.flaggedItems.map((item) {
            return FlaggedItem(
              title: item.title,
              subtitle: item.subtitle,
              borderColor: item.borderColor,
              driverId: item.driverId,
              link: item.link,
              onTap: () => _handleFlaggedTap(item),
            );
          }).toList(),
          driversNeedingReview: raw.driversNeedingReview,
          topDriversThisWeek: raw.topDriversThisWeek,
          pendingBonusesCount: raw.pendingBonusesCount,
        );
        return FleetOverviewTab(
          data: data,
          onReviewPending: () => setState(() => _tab = 2),
          onReviewLeave: () => setState(() => _tab = 6),
          onTopDrivers: () => setState(() {
            _tab = 3;
            _sortDriversByTrips = true;
          }),
          onViewDriver: (id) => context.push('/drivers/$id'),
          onSeeAllReviews: (id) => context.push('/drivers/$id?reviews=1'),
          onApproveBonuses: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Payroll module coming soon — run fix_driver_onboarding.sql')),
            );
          },
          onRegisterDriver: () => context.push('/drivers/register'),
          onOnboardingPipeline: () => setState(() {
            _tab = 1;
            _directoryOnboardingFilter = true;
          }),
        );
      },
    );
  }

  void _handleFlaggedTap(FlaggedItem item) {
    switch (item.link) {
      case FlaggedLink.pending:
        setState(() => _tab = 2);
      case FlaggedLink.leave:
        setState(() => _tab = 6);
      case FlaggedLink.driverProfile:
        if (item.driverId != null) context.push('/drivers/${item.driverId}');
      case FlaggedLink.driverDocuments:
        if (item.driverId != null) context.push('/drivers/${item.driverId}?tab=documents');
      case FlaggedLink.driverHr:
        if (item.driverId != null) context.push('/drivers/${item.driverId}?tab=hr');
      case FlaggedLink.register:
        if (item.driverId != null) {
          context.push('/drivers/register?id=${item.driverId}');
        } else {
          context.push('/drivers/register');
        }
      case FlaggedLink.payroll:
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Payroll module coming in Phase 4')),
        );
      case FlaggedLink.disciplinary:
        if (item.driverId != null) {
          context.push('/drivers/${item.driverId}?tab=disciplinary');
        }
      case FlaggedLink.none:
        break;
    }
  }

  Widget _buildLeaveTab() {
    final async = ref.watch(pendingLeaveProvider);
    final fmt = DateFormat.yMMMd();
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e\n\nRun fix_driver_hr.sql in Supabase.')),
      data: (rows) {
        if (rows.isEmpty) {
          return const Center(child: Text('No pending leave requests.'));
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: rows.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, i) {
            final r = rows[i];
            return ListTile(
              title: Text('${r.driverName} · ${r.leaveType}'),
              subtitle: Text(
                '${fmt.format(r.startDate)} – ${fmt.format(r.endDate)}\n${r.reason}',
              ),
              isThreeLine: true,
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FilledButton(
                    onPressed: () => _reviewLeave(r.id, 'approved'),
                    child: const Text('Approve'),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton(
                    onPressed: () => _reviewLeave(r.id, 'rejected'),
                    child: const Text('Reject'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildFareTab() {
    final fareAsync = ref.watch(activeFareProvider);
    return fareAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (fare) {
        _hydrateFareFields(fare);
        return Padding(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Active fare (Carmona pilot)', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 16),
                TextField(
                  controller: _baseFare,
                  decoration: const InputDecoration(
                    labelText: 'Base fare (₱)',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _perKm,
                  decoration: const InputDecoration(
                    labelText: 'Per km rate (₱)',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _minimum,
                  decoration: const InputDecoration(
                    labelText: 'Minimum fare (₱)',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: fare == null || _savingFare
                      ? null
                      : () => _saveFare(fare.id),
                  child: _savingFare
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Save fare'),
                ),
                if (fare == null)
                  const Padding(
                    padding: EdgeInsets.only(top: 12),
                    child: Text(
                      'No active fare_config row. Run supabase/fix_carmona_pilot.sql first.',
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _DriversList extends ConsumerWidget {
  const _DriversList({
    required this.provider,
    required this.emptyLabel,
    required this.actions,
    this.onDriverTap,
    this.sortByTrips = false,
    this.header,
  });

  final FutureProvider<List<DriverRow>> provider;
  final String emptyLabel;
  final List<Widget> Function(String id) actions;
  final void Function(String id)? onDriverTap;
  final bool sortByTrips;
  final String? header;

  int _mockTripsFor(DriverRow d, Map<String, int> weekly) => weekly[d.id] ?? 0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(provider);
    final weeklyAsync = sortByTrips ? ref.watch(weeklyTripsByDriverProvider) : null;
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (drivers) {
        final weekly = weeklyAsync?.maybeWhen(data: (m) => m, orElse: () => <String, int>{}) ?? {};
        final list = [...drivers];
        if (sortByTrips) {
          list.sort((a, b) => _mockTripsFor(b, weekly).compareTo(_mockTripsFor(a, weekly)));
        }
        if (list.isEmpty) {
          return Center(child: Text(emptyLabel));
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: list.length + (header != null ? 1 : 0),
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (context, index) {
            if (header != null && index == 0) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(header!, style: Theme.of(context).textTheme.titleMedium),
              );
            }
            final i = header != null ? index - 1 : index;
            final d = list[i];
            return ListTile(
              leading: DriverAvatar(name: d.fullName.isEmpty ? d.email : d.fullName, radius: 20),
              title: Text(d.fullName.isEmpty ? d.email : d.fullName),
              subtitle: Text(
                '${d.email}\n'
                'Plate: ${d.trikePlateNumber ?? '—'} · ${d.trikeModel ?? '—'}\n'
                'Status: ${d.approvalStatus}'
                '${sortByTrips ? ' · ${_mockTripsFor(d, weekly)} trips this week' : ''}',
              ),
              isThreeLine: true,
              onTap: onDriverTap != null ? () => onDriverTap!(d.id) : null,
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (onDriverTap != null)
                    TextButton(
                      onPressed: () => onDriverTap!(d.id),
                      child: const Text('Profile'),
                    ),
                  ...actions(d.id),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
