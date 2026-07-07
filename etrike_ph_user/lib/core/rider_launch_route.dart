import 'package:dio/dio.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../repositories/auth_repository.dart';
import '../repositories/maintenance_repository.dart';
import '../repositories/trip_repository.dart';
import 'trip_live_activity_service.dart';
import 'eco/eco_local_store.dart';

/// Where to send the rider after splash, login, or register.
Future<String> resolveRiderLaunchRoute() async {
  final client = Supabase.instance.client;
  final maintenance = await MaintenanceRepository(client).fetchStatus();
  if (maintenance.isBlocking) return '/maintenance';

  final session = client.auth.currentSession;
  if (session == null) {
    final seenOnboarding = await EcoLocalStore.onboardingCompleted();
    return seenOnboarding ? '/login' : '/onboarding';
  }

  final repo = TripRepository(
    Supabase.instance.client,
    Dio(),
    AuthRepository(Supabase.instance.client),
  );

  try {
    final active = await repo.fetchActiveTripForRider(session.user.id);
    await TripLiveActivityService.reconcileWithTrip(active);
    if (active != null) return '/trip/${active.id}';
  } catch (_) {
    await TripLiveActivityService.end();
  }

  return '/home';
}
