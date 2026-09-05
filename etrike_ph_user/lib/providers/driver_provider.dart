import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/geo.dart';
import '../models/driver_model.dart';
import '../models/place_model.dart';
import '../repositories/driver_repository.dart';
import 'auth_provider.dart';
import 'place_provider.dart';

final driverRepositoryProvider = Provider<DriverRepository>(
  (ref) => DriverRepository(ref.watch(supabaseClientProvider)),
);

final nearbyDriversProvider = StreamProvider<List<DriverModel>>((ref) async* {
  final repo = ref.watch(driverRepositoryProvider);
  final selected = ref.watch(selectedPlaceProvider);
  await for (final rows in repo.driversStream()) {
    List<PlaceModel> places = const [];
    try {
      places = await ref.read(activePlacesProvider.future);
    } catch (_) {}
    final models = rows.map(DriverModel.fromJson).where((d) {
      if (!d.isOnline || !d.isAvailable || d.latLng == null) return false;
      if (d.placeId != null &&
          selected.isPersisted &&
          d.placeId != selected.id) {
        return false;
      }
      PlaceModel area = selected;
      if (d.placeId != null) {
        for (final p in places) {
          if (p.id == d.placeId) {
            area = p;
            break;
          }
        }
      }
      final km = haversineKm(
        area.centerLat,
        area.centerLng,
        d.currentLat!,
        d.currentLng!,
      );
      return km <= area.radiusKm;
    }).toList();
    yield models;
  }
});

final driverLiveProvider =
    StreamProvider.family<DriverModel?, String>((ref, driverId) async* {
  final repo = ref.watch(driverRepositoryProvider);
  await for (final rows in repo.driverStream(driverId)) {
    if (rows.isEmpty) {
      yield null;
    } else {
      yield DriverModel.fromJson(rows.first);
    }
  }
});
