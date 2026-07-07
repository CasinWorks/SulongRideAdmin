import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/driver_trip_eligibility.dart';
import '../repositories/auth_repository.dart';
import '../repositories/onboarding_repository.dart';
import '../repositories/training_repository.dart';
import 'auth_provider.dart';
import 'onboarding_provider.dart';
import 'training_provider.dart';

final driverTripEligibilityProvider = FutureProvider<DriverTripEligibility>((ref) async {
  final uid = ref.watch(authUserIdProvider);
  if (uid == null) {
    return const DriverTripEligibility(
      canReceiveTrips: false,
      primaryBlockReason: 'Not signed in.',
    );
  }

  final profile = await ref.read(authRepositoryProvider).fetchDriverProfile();
  final training = await ref.read(trainingRepositoryProvider).fetchTraining(uid);
  final onboarding = await ref.read(onboardingRepositoryProvider).fetchBundle();

  return evaluateDriverTripEligibility(
    profile: profile,
    training: training,
    onboarding: onboarding,
  );
});

/// Refreshes eligibility after onboarding/training changes.
Future<DriverTripEligibility> refreshDriverTripEligibility(WidgetRef ref) async {
  ref.invalidate(driverTripEligibilityProvider);
  return ref.read(driverTripEligibilityProvider.future);
}

Future<DriverTripEligibility> fetchDriverTripEligibility({
  required AuthRepository authRepo,
  required TrainingRepository trainingRepo,
  required OnboardingRepository onboardingRepo,
  required String driverId,
}) async {
  final profile = await authRepo.fetchDriverProfile();
  final training = await trainingRepo.fetchTraining(driverId);
  final onboarding = await onboardingRepo.fetchBundle();
  return evaluateDriverTripEligibility(
    profile: profile,
    training: training,
    onboarding: onboarding,
  );
}
