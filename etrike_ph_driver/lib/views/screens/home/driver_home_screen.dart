import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../../core/constants/map_regions.dart';
import '../../../core/trip_live_activity_service.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_map_styles.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/location_permission.dart';
import '../../../core/local_notifications_service.dart';
import '../../../models/driver_model.dart';
import '../../../models/trip_model.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/driver_eligibility_provider.dart';
import '../../../providers/hr_provider.dart';
import '../../../providers/location_provider.dart';
import '../../../providers/onboarding_provider.dart';
import '../../../providers/training_provider.dart';
import '../../../providers/trip_provider.dart';
import '../../../providers/maintenance_provider.dart';
import '../maintenance/maintenance_screen.dart';
import '../../components/platform_map_view.dart';

class DriverHomeScreen extends ConsumerStatefulWidget {
  const DriverHomeScreen({super.key});

  @override
  ConsumerState<DriverHomeScreen> createState() => _DriverHomeScreenState();
}

class _DriverHomeScreenState extends ConsumerState<DriverHomeScreen> {
  GoogleMapController? _mapController;
  final ValueNotifier<bool> _online = ValueNotifier<bool>(false);
  final ValueNotifier<LatLng> _cameraTarget =
      ValueNotifier<LatLng>(MapRegions.carmonaCenter);
  final ValueNotifier<String?> _locationError = ValueNotifier<String?>(null);
  bool _incomingSheetShowing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initLocation();
      _restoreSession();
    });
  }

  Future<void> _restoreSession() async {
    final uid = ref.read(supabaseClientProvider).auth.currentUser?.id;
    if (uid == null) return;
    try {
      final online =
          await ref.read(locationRepositoryProvider).fetchDriverOnline(uid);
      if (online) {
        final eligibility = await fetchDriverTripEligibility(
          authRepo: ref.read(authRepositoryProvider),
          trainingRepo: ref.read(trainingRepositoryProvider),
          onboardingRepo: ref.read(onboardingRepositoryProvider),
          hrRepo: ref.read(hrRepositoryProvider),
          driverId: uid,
        );
        if (!eligibility.canReceiveTrips) {
          await ref.read(locationRepositoryProvider).setDriverOnline(
                driverId: uid,
                isOnline: false,
              );
          _online.value = false;
          ref.read(driverOnlineProvider.notifier).state = false;
          ref.read(locationTickerProvider).stop();
        } else {
          _online.value = true;
          ref.read(driverOnlineProvider.notifier).state = true;
          ref.read(locationTickerProvider).start();
        }
      }
    } catch (_) {}

    try {
      final active =
          await ref.read(tripRepositoryProvider).fetchActiveTripForDriver(uid);
      await DriverTripLiveActivityService.reconcileWithTrip(active);
      if (active != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Active trip (${active.status}) — finish it to receive new bookings.',
            ),
            action: SnackBarAction(
              label: 'Open',
              onPressed: () => context.go('/trip/${active.id}'),
            ),
            duration: const Duration(seconds: 6),
          ),
        );
      }
    } catch (_) {
      await DriverTripLiveActivityService.end();
    }
  }

  @override
  void dispose() {
    _online.dispose();
    _cameraTarget.dispose();
    _locationError.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _initLocation() async {
    try {
      if (!await hasUsableLocationPermission()) {
        _locationError.value = 'Location permission is required while online.';
        return;
      }
      final pos = await Geolocator.getCurrentPosition();
      final latLng = LatLng(pos.latitude, pos.longitude);
      _cameraTarget.value = latLng;
      await _mapController?.animateCamera(CameraUpdate.newLatLngZoom(latLng, 14));
    } catch (e) {
      _locationError.value = e.toString();
    }
  }

  Future<void> _setOnline(bool value) async {
    final uid = ref.read(supabaseClientProvider).auth.currentUser?.id;
    if (uid == null) return;

    if (value) {
      try {
        final profile =
            await ref.read(authRepositoryProvider).fetchDriverProfile();
        if (profile != null && !profile.canStartShift()) {
          if (mounted) {
            await _showNotOnShiftDialog(profile.shiftWindowLabel);
          }
          return;
        }

        final eligibility = await fetchDriverTripEligibility(
          authRepo: ref.read(authRepositoryProvider),
          trainingRepo: ref.read(trainingRepositoryProvider),
          onboardingRepo: ref.read(onboardingRepositoryProvider),
          hrRepo: ref.read(hrRepositoryProvider),
          driverId: uid,
        );
        if (!eligibility.canReceiveTrips) {
          if (!mounted) return;
          final onboardingBlocked = !eligibility.isApproved ||
              !eligibility.documentsComplete ||
              !eligibility.trainingComplete ||
              !eligibility.hasAssignedVehicle;
          if (onboardingBlocked) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  eligibility.primaryBlockReason ??
                      'Complete onboarding requirements before going Online.',
                ),
                duration: const Duration(seconds: 5),
              ),
            );
            if (!eligibility.documentsComplete) {
              context.push('/onboarding');
            } else if (!eligibility.trainingComplete) {
              context.push('/training');
            }
            return;
          }
          if (!eligibility.timedIn) {
            final timedIn = await _promptTimeInFirst(profile);
            if (!timedIn) return;
          } else {
            return;
          }
        }
      } catch (_) {
        return;
      }
    }

    try {
      await ref.read(locationRepositoryProvider).setDriverOnline(
            driverId: uid,
            isOnline: value,
          );
      _online.value = value;
      ref.read(driverOnlineProvider.notifier).state = value;
      if (value) {
        ref.read(lastIncomingTripPingProvider.notifier).state = null;
      }
      final ticker = ref.read(locationTickerProvider);
      if (value) {
        ticker.start();
      } else {
        ticker.stop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_formatOnlineError(e))),
        );
      }
    }
  }

  String _formatTripPollError(String message) {
    if (message.contains('42501') || message.contains('row-level security')) {
      return 'Cannot load trip requests (RLS). Run supabase/apply_mvp_fixes.sql '
          'in Supabase SQL Editor, wait ~30s, toggle Online off/on.';
    }
    return 'Trip requests: $message';
  }

  String _formatOnlineError(Object error) {
    final message = error.toString();
    if (message.contains('PGRST204') &&
        (message.contains('is_online') || message.contains('is_available'))) {
      return 'Driver database is missing online columns (is_online). '
          'In Supabase SQL Editor, run supabase/fix_drivers_schema.sql '
          '(includes notify pgrst reload), wait ~30s, then toggle Online again.';
    }
    if (message.contains('row-level security') || message.contains('42501')) {
      return 'Supabase blocked updating your driver profile (RLS). '
          'Run supabase/setup_test_driver.sql in the SQL Editor, then try again.';
    }
    return message;
  }

  Future<void> _showNotOnShiftDialog(String shiftLabel) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Not your shift'),
        content: Text(
          'You can only go Online during your scheduled hours.\n\n$shiftLabel',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<bool> _promptTimeInFirst(DriverModel? profile) async {
    final action = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Time in first'),
        content: const Text(
          'Clock in for your shift before going Online. Time-in is required to receive trip requests.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop('cancel'),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop('attendance'),
            child: const Text('Open Time in'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop('timeIn'),
            child: const Text('Time in now'),
          ),
        ],
      ),
    );

    if (action == 'attendance') {
      if (mounted) context.push('/attendance');
      return false;
    }
    if (action != 'timeIn') return false;

    try {
      await ref.read(hrRepositoryProvider).clockIn(profile: profile);
      ref.invalidate(openAttendanceProvider);
      ref.invalidate(attendanceHistoryProvider);
      ref.invalidate(driverStatsProvider);
      return true;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final pollError = ref.watch(requestedTripsPollErrorProvider);
    final isOnline = ref.watch(driverOnlineProvider);
    final maintenanceStatus = ref.watch(appMaintenanceStatusProvider);
    final activeTrip = ref.watch(driverActiveTripProvider).asData?.value;
    final profile = ref.watch(driverProfileProvider).asData?.value;
    final approvalPending = profile != null && !profile.isApproved;

    ref.listen<bool>(driverOnlineProvider, (previous, next) {
      _online.value = next;
    });
    ref.listen<String?>(driverForcedOfflineReasonProvider, (previous, next) {
      if (next == null || !context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(next), duration: const Duration(seconds: 6)),
      );
      ref.read(driverForcedOfflineReasonProvider.notifier).state = null;
    });

    ref.listen<AsyncValue<TripModel?>>(driverActiveTripProvider, (previous, next) {
      unawaited(
        DriverTripLiveActivityService.reconcileWithTrip(next.asData?.value),
      );
      final trip = next.asData?.value;
      final prevId = previous?.asData?.value?.id;
      if (trip == null || trip.id == prevId) return;
      if (trip.status != 'accepted' && trip.status != 'ongoing') return;
      if (!context.mounted) return;
      final loc = GoRouterState.of(context).uri.path;
      if (loc.startsWith('/trip/')) return;
      unawaited(LocalNotificationsService.showIncomingTrip());
      context.go('/trip/${trip.id}');
    });

    ref.listen<AsyncValue<List<TripModel>>>(requestedTripsProvider, (previous, next) {
      next.whenData((trips) async {
        if (!ref.read(driverOnlineProvider)) return;
        if (_incomingSheetShowing) return;
        if (ref.read(driverActiveTripProvider).asData?.value != null) return;
        final uid = ref.read(supabaseClientProvider).auth.currentUser?.id;
        if (uid == null) return;

        try {
          final eligibility = await fetchDriverTripEligibility(
            authRepo: ref.read(authRepositoryProvider),
            trainingRepo: ref.read(trainingRepositoryProvider),
            onboardingRepo: ref.read(onboardingRepositoryProvider),
            hrRepo: ref.read(hrRepositoryProvider),
            driverId: uid,
          );
          if (!eligibility.canReceiveTrips) return;
        } catch (_) {
          return;
        }

        try {
          final busy = await ref.read(tripRepositoryProvider).fetchActiveTripForDriver(uid);
          if (busy != null) return;
        } catch (_) {}
        if (trips.isEmpty) return;

        final newest = trips.reduce(
          (a, b) => a.createdAt.isAfter(b.createdAt) ? a : b,
        );
        final last = ref.read(lastIncomingTripPingProvider);
        if (last == newest.id) return;
        ref.read(lastIncomingTripPingProvider.notifier).state = newest.id;

        if (kDebugMode && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Trip assigned (${newest.pickupAddress})'),
              duration: const Duration(seconds: 2),
            ),
          );
        }
        await LocalNotificationsService.showIncomingTrip();
        if (!context.mounted) return;

        _incomingSheetShowing = true;
        try {
          if (newest.driverId == null) {
            await ref.read(tripRepositoryProvider).acceptTrip(
                  tripId: newest.id,
                  driverId: uid,
                );
          }
        } catch (_) {
          _incomingSheetShowing = false;
          return;
        }
        _incomingSheetShowing = false;
        if (!context.mounted) return;
        context.go('/trip/${newest.id}');
      });
    });

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: ValueListenableBuilder<LatLng>(
              valueListenable: _cameraTarget,
              builder: (context, target, _) {
                return PlatformMapView(
                  initialTarget: target,
                  markers: const {},
                  mapStyle: AppMapStyles.ecoDark,
                  myLocationEnabled: true,
                  onMapCreated: (c) {
                    _mapController = c;
                  },
                );
              },
            ),
          ),
          Positioned(
            top: MediaQuery.paddingOf(context).top + 12,
            left: 16,
            right: 16,
            child: Column(
              children: [
                MaintenanceBanner(status: maintenanceStatus),
                if (approvalPending)
                  Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.accent),
                    ),
                    child: Text(
                      profile.approvalStatus == 'rejected'
                          ? 'Your driver account was not approved. Contact the operator.'
                          : 'Account pending approval — you cannot go online until an operator approves you.',
                      style: AppTextStyles.bodySecondary,
                    ),
                  ),
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: const [
                            BoxShadow(color: Color(0x33000000), blurRadius: 12, offset: Offset(0, 4)),
                          ],
                        ),
                        child: Row(
                          children: [
                            Text('Online', style: AppTextStyles.body),
                            const Spacer(),
                            ValueListenableBuilder<bool>(
                              valueListenable: _online,
                              builder: (context, online, _) {
                                return Switch(
                                  value: online,
                                  activeTrackColor: AppColors.accent.withValues(alpha: 0.35),
                                  activeThumbColor: AppColors.accent,
                                  onChanged: (v) => _setOnline(v),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    _IconCircle(
                      icon: Icons.settings_outlined,
                      onTap: () => context.push('/settings'),
                    ),
                    const SizedBox(width: 10),
                    _IconCircle(
                      icon: Icons.history,
                      onTap: () => context.push('/history'),
                    ),
                    const SizedBox(width: 10),
                    _IconCircle(
                      icon: Icons.person_outline,
                      onTap: () => context.push('/hub'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: MediaQuery.paddingOf(context).bottom + 16,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (activeTrip != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.accent),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Active trip (${activeTrip.status}) — new bookings are paused.',
                          style: AppTextStyles.bodySecondary,
                        ),
                        const SizedBox(height: 8),
                        FilledButton(
                          onPressed: () => context.go('/trip/${activeTrip.id}'),
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.accent,
                            foregroundColor: AppColors.primary,
                          ),
                          child: const Text('Continue trip'),
                        ),
                      ],
                    ),
                  ),
                if (isOnline && pollError != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.accent.withValues(alpha: 0.5)),
                    ),
                    child: Text(
                      _formatTripPollError(pollError),
                      style: AppTextStyles.bodySecondary,
                    ),
                  ),
                ValueListenableBuilder<String?>(
                  valueListenable: _locationError,
                  builder: (context, err, _) {
                    if (err == null) return const SizedBox.shrink();
                    return Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(err, style: AppTextStyles.bodySecondary),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _IconCircle extends StatelessWidget {
  const _IconCircle({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      shape: const CircleBorder(),
      elevation: 3,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Icon(icon, color: AppColors.textPrimary),
        ),
      ),
    );
  }
}
