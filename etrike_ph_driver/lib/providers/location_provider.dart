import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../repositories/location_repository.dart';
import 'auth_provider.dart';
import 'hr_provider.dart';
import 'trip_provider.dart';

final locationRepositoryProvider = Provider<LocationRepository>(
  (ref) => LocationRepository(ref.watch(supabaseClientProvider)),
);

class LocationTicker {
  LocationTicker(this.ref);

  final Ref ref;
  Timer? _timer;
  Duration _interval = const Duration(seconds: 5);
  DateTime? _lastAttendanceCheck;

  void setFastMode(bool enabled) {
    _interval = enabled ? const Duration(seconds: 2) : const Duration(seconds: 5);
    if (_timer != null) start();
  }

  void start() {
    _timer?.cancel();
    _lastAttendanceCheck = null;
    unawaited(_tick());
    _timer = Timer.periodic(_interval, (_) => _tick());
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> _tick() async {
    try {
      final uid = ref.read(supabaseClientProvider).auth.currentUser?.id;
      if (uid == null) return;
      final pos = await Geolocator.getCurrentPosition();
      await ref.read(locationRepositoryProvider).updateDriverLocation(
            driverId: uid,
            lat: pos.latitude,
            lng: pos.longitude,
          );
      await _enforceShiftTimeout();
    } catch (_) {
      // Intentionally swallow periodic errors (permissions, GPS gaps).
    }
  }

  Future<void> _enforceShiftTimeout() async {
    final now = DateTime.now();
    if (_lastAttendanceCheck != null &&
        now.difference(_lastAttendanceCheck!) < const Duration(minutes: 2)) {
      return;
    }
    _lastAttendanceCheck = now;
    final closed =
        await ref.read(hrRepositoryProvider).autoCloseStaleAttendance();
    if (!closed) return;
    stop();
    ref.read(driverOnlineProvider.notifier).state = false;
    ref.read(driverForcedOfflineReasonProvider.notifier).state =
        'Your shift timed out after 24 hours. Time in again on your next shift to go Online.';
    ref.invalidate(openAttendanceProvider);
    ref.invalidate(attendanceHistoryProvider);
    ref.invalidate(driverStatsProvider);
  }

  void dispose() => stop();
}

final locationTickerProvider = Provider<LocationTicker>((ref) {
  final ticker = LocationTicker(ref);
  ref.onDispose(ticker.dispose);
  return ticker;
});
