import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/driver_model.dart';
import '../repositories/auth_repository.dart';

final supabaseClientProvider = Provider<SupabaseClient>(
  (ref) => Supabase.instance.client,
);

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(ref.watch(supabaseClientProvider)),
);

final authSessionProvider = StreamProvider<Session?>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return client.auth.onAuthStateChange.map((event) => event.session);
});

/// Rebuild user-scoped providers whenever the signed-in account changes.
final authUserIdProvider = Provider<String?>((ref) {
  return ref.watch(authSessionProvider).valueOrNull?.user.id;
});

final driverProfileProvider = FutureProvider<DriverModel?>((ref) async {
  final uid = ref.watch(authUserIdProvider);
  if (uid == null) return null;
  final repo = ref.watch(authRepositoryProvider);
  return repo.fetchDriverProfile();
});

class GoRouterRefreshNotifier extends ChangeNotifier {
  GoRouterRefreshNotifier(this._client) {
    _subscription = _client.auth.onAuthStateChange.listen((_) {
      notifyListeners();
    });
  }

  final SupabaseClient _client;
  late final StreamSubscription<AuthState> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}

final goRouterRefreshProvider = Provider<GoRouterRefreshNotifier>((ref) {
  final notifier = GoRouterRefreshNotifier(ref.watch(supabaseClientProvider));
  ref.onDispose(notifier.dispose);
  return notifier;
});
