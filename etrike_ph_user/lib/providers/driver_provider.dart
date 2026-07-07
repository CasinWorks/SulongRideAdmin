import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/driver_model.dart';
import '../repositories/driver_repository.dart';
import 'auth_provider.dart';

final driverRepositoryProvider = Provider<DriverRepository>(
  (ref) => DriverRepository(ref.watch(supabaseClientProvider)),
);

final nearbyDriversProvider = StreamProvider<List<DriverModel>>((ref) async* {
  final repo = ref.watch(driverRepositoryProvider);
  await for (final rows in repo.driversStream()) {
    final models = rows.map(DriverModel.fromJson).where((d) {
      return d.isOnline && d.isAvailable && d.latLng != null;
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
