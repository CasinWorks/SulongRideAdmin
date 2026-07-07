import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/local_notifications_service.dart';
import '../providers/auth_provider.dart';
import '../providers/maintenance_provider.dart';
import '../views/screens/auth/login_screen.dart';
import '../views/screens/auth/register_screen.dart';
import '../views/screens/chat/chat_screen.dart';
import '../views/screens/history/ride_history_screen.dart';
import '../views/screens/home/home_screen.dart';
import '../views/screens/profile/profile_screen.dart';
import '../views/screens/maintenance/maintenance_screen.dart';
import '../views/screens/onboarding/onboarding_screen.dart';
import '../views/screens/settings/settings_screen.dart';
import '../views/screens/splash/splash_screen.dart';
import '../views/screens/trip/trip_active_screen.dart';
import '../views/screens/trip/trip_completed_screen.dart';

final goRouterProvider = Provider<GoRouter>((ref) {
  final refresh = ref.watch(goRouterRefreshProvider);
  final maintenance = ref.watch(maintenanceControllerProvider);
  final router = GoRouter(
    initialLocation: '/splash',
    refreshListenable: Listenable.merge([refresh, maintenance]),
    redirect: (context, state) {
      final session = Supabase.instance.client.auth.currentSession;
      final loc = state.matchedLocation;
      if (loc == '/splash') return null;

      if (!maintenance.ready) return null;

      if (maintenance.blocksApp) {
        if (loc != '/maintenance') return '/maintenance';
        return null;
      }

      if (loc == '/maintenance') {
        if (session == null) {
          return '/login';
        }
        return '/home';
      }

      if (session == null && loc != '/login' && loc != '/register' && loc != '/onboarding') {
        return '/login';
      }
      if (session != null && (loc == '/login' || loc == '/register')) {
        return '/home';
      }
      return null;
    },
    routes: [
      GoRoute(
        path: '/maintenance',
        builder: (context, state) => MaintenanceScreen(status: maintenance.status),
      ),
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/onboarding',
        builder: (context, state) {
          final replay = state.uri.queryParameters['replay'] == '1';
          return OnboardingScreen(replay: replay);
        },
      ),
      GoRoute(
        path: '/home',
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: '/trip/:id/completed',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return TripCompletedScreen(tripId: id);
        },
      ),
      GoRoute(
        path: '/trip/:id',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return TripActiveScreen(tripId: id);
        },
      ),
      GoRoute(
        path: '/chat/:tripId',
        builder: (context, state) {
          final id = state.pathParameters['tripId']!;
          return ChatScreen(tripId: id);
        },
      ),
      GoRoute(
        path: '/history',
        builder: (context, state) => const RideHistoryScreen(),
      ),
      GoRoute(
        path: '/profile',
        builder: (context, state) => const ProfileScreen(),
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsScreen(),
      ),
    ],
  );
  LocalNotificationsService.onChatMessageTap = (tripId) {
    router.go('/trip/$tripId');
  };
  return router;
});
