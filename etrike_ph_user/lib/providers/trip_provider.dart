import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/trip_model.dart';
import '../core/eco/eco_models.dart';
import '../repositories/trip_repository.dart';
import '../repositories/vehicle_types_repository.dart';
import 'auth_provider.dart';

final dioProvider = Provider<Dio>((ref) => Dio());

final tripRepositoryProvider = Provider<TripRepository>(
  (ref) => TripRepository(
    ref.watch(supabaseClientProvider),
    ref.watch(dioProvider),
    ref.watch(authRepositoryProvider),
  ),
);

final fareConfigProvider = FutureProvider<FareConfig>((ref) async {
  final repo = ref.watch(tripRepositoryProvider);
  return repo.fetchActiveFareConfig();
});

final vehicleTypesRepositoryProvider = Provider<VehicleTypesRepository>(
  (ref) => VehicleTypesRepository(ref.watch(supabaseClientProvider)),
);

final vehicleTypesProvider = FutureProvider<List<EcoVehicleOption>>((ref) async {
  return ref.watch(vehicleTypesRepositoryProvider).listActiveVehicleTypes();
});

Stream<TripModel?> _watchTrip(TripRepository repo, String tripId) async* {
  try {
    yield await repo.fetchTrip(tripId);
  } catch (_) {
    yield null;
    return;
  }

  try {
    await for (final rows in repo.tripStream(tripId).timeout(const Duration(seconds: 12))) {
      if (rows.isEmpty) {
        yield null;
      } else {
        yield TripModel.fromJson(rows.first);
      }
    }
  } on TimeoutException {
    // Realtime unavailable — poll instead of showing an error screen.
  } catch (_) {}

  while (true) {
    await Future<void>.delayed(const Duration(seconds: 5));
    try {
      yield await repo.fetchTrip(tripId);
    } catch (_) {}
  }
}

final tripRealtimeProvider =
    StreamProvider.family<TripModel?, String>((ref, tripId) {
  final repo = ref.watch(tripRepositoryProvider);
  return _watchTrip(repo, tripId);
});

final rideHistoryProvider = FutureProvider<List<TripModel>>((ref) async {
  final user = ref.watch(supabaseClientProvider).auth.currentUser;
  if (user == null) return [];
  try {
    return ref.watch(tripRepositoryProvider).completedTripsForRider(user.id);
  } catch (_) {
    rethrow;
  }
});

/// Rider's current requested, accepted, or ongoing trip.
final riderActiveTripProvider = StreamProvider<TripModel?>((ref) async* {
  final uid = ref.watch(supabaseClientProvider).auth.currentUser?.id;
  if (uid == null) {
    yield null;
    return;
  }
  final repo = ref.watch(tripRepositoryProvider);

  Future<TripModel?> fetchActive() => repo.fetchActiveTripForRider(uid);

  yield await fetchActive();

  final out = StreamController<TripModel?>();
  Timer? timer;

  timer = Timer.periodic(const Duration(seconds: 4), (_) async {
    out.add(await fetchActive());
  });

  ref.onDispose(() {
    timer?.cancel();
    out.close();
  });

  await for (final trip in out.stream) {
    yield trip;
  }
});

String formatPeso(double value) {
  final fixed = value.toStringAsFixed(2);
  return '₱$fixed';
}
