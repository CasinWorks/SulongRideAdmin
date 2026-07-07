import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/onboarding_models.dart';
import '../repositories/onboarding_repository.dart';
import 'auth_provider.dart';

final onboardingRepositoryProvider = Provider<OnboardingRepository>(
  (ref) => OnboardingRepository(ref.watch(supabaseClientProvider)),
);

final onboardingBundleProvider = FutureProvider<OnboardingBundle>((ref) async {
  final uid = ref.watch(authUserIdProvider);
  if (uid == null) return const OnboardingBundle();
  return ref.watch(onboardingRepositoryProvider).fetchBundle();
});
