import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/trip_model.dart';
import '../repositories/trip_repository.dart';
import 'auth_provider.dart';
import 'driver_eligibility_provider.dart';
import 'onboarding_provider.dart';
import 'training_provider.dart';

/// Set from driver home when the Online switch changes (drives poll fallback).
final driverOnlineProvider = StateProvider<bool>((ref) => false);

/// Last error from polling open trips while online (RLS / network).
final requestedTripsPollErrorProvider = StateProvider<String?>((ref) => null);

List<TripModel> _openRequestedTrips(List<Map<String, dynamic>> rows) {
  return rows
      .map(TripModel.fromJson)
      .where((t) => t.status == 'requested' && t.driverId == null)
      .toList();
}

final tripRepositoryProvider = Provider<TripRepository>(
  (ref) => TripRepository(ref.watch(supabaseClientProvider)),
);

final fareConfigProvider = FutureProvider<FareConfig>((ref) async {
  final repo = ref.watch(tripRepositoryProvider);
  return repo.fetchActiveFareConfig();
});

final tripRealtimeProvider =
    StreamProvider.family<TripModel?, String>((ref, tripId) {
  final repo = ref.watch(tripRepositoryProvider);
  return _watchTrip(repo, tripId);
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

/// Live open requests: Supabase Realtime on `trips` + poll every 4s while online.
final requestedTripsProvider = StreamProvider<List<TripModel>>((ref) async* {
  final repo = ref.watch(tripRepositoryProvider);

  Future<List<TripModel>> pollIfOnline() async {
    if (!ref.read(driverOnlineProvider)) return [];
    final uid = ref.read(supabaseClientProvider).auth.currentUser?.id;
    if (uid != null) {
      try {
        final eligibility = await fetchDriverTripEligibility(
          authRepo: ref.read(authRepositoryProvider),
          trainingRepo: ref.read(trainingRepositoryProvider),
          onboardingRepo: ref.read(onboardingRepositoryProvider),
          driverId: uid,
        );
        if (!eligibility.canReceiveTrips) return [];
      } catch (_) {
        return [];
      }
      try {
        final active = await repo.fetchActiveTripForDriver(uid);
        if (active != null) return [];
      } catch (_) {}
    }
    try {
      final trips = _openRequestedTrips(await repo.fetchOpenRequestedTrips());
      ref.read(requestedTripsPollErrorProvider.notifier).state = null;
      return trips;
    } catch (e) {
      final message = e.toString();
      ref.read(requestedTripsPollErrorProvider.notifier).state = message;
      if (kDebugMode) {
        // ignore: avoid_print
        print('requestedTrips poll failed: $message');
      }
      return [];
    }
  }

  if (ref.read(driverOnlineProvider)) {
    yield await pollIfOnline();
  }

  final out = StreamController<List<TripModel>>();
  StreamSubscription<List<TripModel>>? realtimeSub;
  Timer? pollTimer;

  void startPollTimer() {
    pollTimer?.cancel();
    if (!ref.read(driverOnlineProvider)) return;
    pollTimer = Timer.periodic(const Duration(seconds: 4), (_) async {
      out.add(await pollIfOnline());
    });
  }

  realtimeSub = repo.requestedTripsStream().map(_openRequestedTrips).listen(
        (trips) async {
          if (!ref.read(driverOnlineProvider)) return;
          final uid = ref.read(supabaseClientProvider).auth.currentUser?.id;
          if (uid != null) {
            try {
              final eligibility = await fetchDriverTripEligibility(
                authRepo: ref.read(authRepositoryProvider),
                trainingRepo: ref.read(trainingRepositoryProvider),
                onboardingRepo: ref.read(onboardingRepositoryProvider),
                driverId: uid,
              );
              if (!eligibility.canReceiveTrips) return;
            } catch (_) {
              return;
            }
            try {
              if (await repo.fetchActiveTripForDriver(uid) != null) return;
            } catch (_) {}
          }
          out.add(trips);
        },
        onError: (e) {
          if (!ref.read(driverOnlineProvider)) return;
          ref.read(requestedTripsPollErrorProvider.notifier).state = e.toString();
        },
      );
  startPollTimer();

  ref.listen(driverOnlineProvider, (previous, online) {
    if (online && previous != true) {
      pollIfOnline().then(out.add);
    }
    startPollTimer();
  });

  ref.onDispose(() {
    realtimeSub?.cancel();
    pollTimer?.cancel();
    out.close();
  });

  await for (final trips in out.stream) {
    yield trips;
  }
});

final driverTripHistoryProvider = FutureProvider<List<TripModel>>((ref) async {
  final uid = ref.watch(authUserIdProvider);
  if (uid == null) return [];
  return ref.watch(tripRepositoryProvider).completedTripsForDriver(uid);
});

String formatPeso(double value) {
  final fixed = value.toStringAsFixed(2);
  return '₱$fixed';
}

final lastIncomingTripPingProvider = StateProvider<String?>((ref) => null);

/// Trip IDs the driver declined this session — do not show again until app restart.
final declinedIncomingTripIdsProvider = StateProvider<Set<String>>((ref) => {});

/// Driver's current accepted or ongoing trip (null when available for new requests).
final driverActiveTripProvider = StreamProvider<TripModel?>((ref) async* {
  final uid = ref.watch(authUserIdProvider);
  if (uid == null) {
    yield null;
    return;
  }
  final repo = ref.watch(tripRepositoryProvider);

  Future<TripModel?> fetchActive() => repo.fetchActiveTripForDriver(uid);

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
