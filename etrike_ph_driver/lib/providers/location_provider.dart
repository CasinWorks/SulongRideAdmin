import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../repositories/location_repository.dart';
import 'auth_provider.dart';

final locationRepositoryProvider = Provider<LocationRepository>(
  (ref) => LocationRepository(ref.watch(supabaseClientProvider)),
);

class LocationTicker {
  LocationTicker(this.ref);

  final Ref ref;
  Timer? _timer;
  Duration _interval = const Duration(seconds: 5);

  void setFastMode(bool enabled) {
    _interval = enabled ? const Duration(seconds: 2) : const Duration(seconds: 5);
    if (_timer != null) start();
  }

  void start() {
    _timer?.cancel();
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
    } catch (_) {
      // Intentionally swallow periodic errors (permissions, GPS gaps).
    }
  }

  void dispose() => stop();
}

final locationTickerProvider = Provider<LocationTicker>((ref) {
  final ticker = LocationTicker(ref);
  ref.onDispose(ticker.dispose);
  return ticker;
});
