import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../screens/dashboard_screen.dart';
import '../screens/drivers/driver_detail_screen.dart';
import '../screens/drivers/driver_register_screen.dart';
import '../screens/login_screen.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/login',
    refreshListenable: _AuthRefreshListenable(),
    redirect: (context, state) {
      final session = Supabase.instance.client.auth.currentSession;
      final loggingIn = state.matchedLocation == '/login';
      if (session == null) return loggingIn ? null : '/login';
      if (loggingIn) return '/';
      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/',
        builder: (context, state) => const DashboardScreen(),
      ),
      GoRoute(
        path: '/drivers/register',
        builder: (context, state) {
          final driverId = state.uri.queryParameters['id'];
          return DriverRegisterScreen(driverId: driverId);
        },
      ),
      GoRoute(
        path: '/drivers/:id',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          final scrollToReviews = state.uri.queryParameters['reviews'] == '1';
          final initialTab = state.uri.queryParameters['tab'];
          return DriverDetailScreen(
            driverId: id,
            scrollToReviews: scrollToReviews,
            initialTab: initialTab,
          );
        },
      ),
    ],
  );
});

class _AuthRefreshListenable extends ChangeNotifier {
  _AuthRefreshListenable() {
    Supabase.instance.client.auth.onAuthStateChange.listen((_) {
      notifyListeners();
    });
  }
}
