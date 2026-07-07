import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/driver_local_store.dart';
import '../models/driver_model.dart';
import '../models/training_models.dart';
import '../providers/auth_provider.dart';
import '../providers/onboarding_provider.dart';
import '../providers/training_provider.dart';

/// Tracks driver approval status for route guards (pending → onboarding).
class DriverRouteGuard extends ChangeNotifier {
  DriverRouteGuard(this._ref) {
    _sub = _ref.listen<AsyncValue<dynamic>>(
      authSessionProvider,
      (_, __) => unawaited(refresh()),
      fireImmediately: true,
    );
    _pollTimer = Timer.periodic(const Duration(seconds: 25), (_) {
      if (_ref.read(supabaseClientProvider).auth.currentSession != null) {
        unawaited(refresh(silent: true));
      }
    });
  }

  final Ref _ref;
  ProviderSubscription<AsyncValue<dynamic>>? _sub;
  Timer? _pollTimer;

  DriverModel? profile;
  DriverTrainingRecord? training;
  int checklistPercent = 0;
  bool ready = false;

  /// True while driver must stay on onboarding (pending/rejected or docs incomplete).
  bool get needsOnboarding {
    if (profile == null) return false;
    if (profile!.approvalStatus != 'approved') return true;
    return checklistPercent < 100;
  }

  bool get onboardingDocumentsComplete => checklistPercent >= 100;

  bool get isRejected => profile?.approvalStatus == 'rejected';

  bool get needsTraining =>
      profile != null &&
      profile!.isApproved &&
      !(training?.isComplete ?? false);

  Future<void> refresh({bool silent = false}) async {
    final session = _ref.read(supabaseClientProvider).auth.currentSession;
    if (session == null) {
      profile = null;
      ready = true;
      notifyListeners();
      return;
    }
    if (!silent) {
      ready = false;
      notifyListeners();
    }
    try {
      profile = await _ref.read(authRepositoryProvider).fetchDriverProfile();
      if (profile != null) {
        training = await _ref.read(trainingRepositoryProvider).fetchTraining(profile!.id);
        try {
          final bundle =
              await _ref.read(onboardingRepositoryProvider).fetchBundle();
          checklistPercent = bundle.checklistPercent;
        } catch (_) {
          checklistPercent = profile!.isApproved ? 100 : 0;
        }
      } else {
        training = null;
        checklistPercent = 0;
      }
    } catch (_) {
      profile = null;
      training = null;
      checklistPercent = 0;
    }
    ready = true;
    _ref.invalidate(driverProfileProvider);
    _ref.invalidate(onboardingBundleProvider);
    notifyListeners();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _sub?.close();
    super.dispose();
  }
}

final driverRouteGuardProvider = Provider<DriverRouteGuard>((ref) {
  final guard = DriverRouteGuard(ref);
  ref.onDispose(guard.dispose);
  return guard;
});

bool isDriverOnboardingRoute(String location) =>
    location == '/onboarding' || location.startsWith('/onboarding/');

/// Where to send the user right after sign-in / splash.
Future<String> resolvePostAuthRoute(WidgetRef ref) async {
  await ref.read(driverRouteGuardProvider).refresh();
  final guard = ref.read(driverRouteGuardProvider);
  final profile = guard.profile;

  if (guard.needsOnboarding) return '/onboarding';

  final welcomeDone = await DriverLocalStore.onboardingComplete();
  if (!welcomeDone) return '/welcome';

  if (profile != null && profile.isApproved) {
    final postApprovalDone =
        await DriverLocalStore.postApprovalWelcomeComplete(profile.id);
    if (!postApprovalDone) return '/welcome-approved';

    final trainingRecord =
        await ref.read(trainingRepositoryProvider).fetchTraining(profile.id);
    if (!(trainingRecord?.isComplete ?? false)) return '/training';
  }

  return '/home';
}
