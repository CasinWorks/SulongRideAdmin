import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/driver_route_guard.dart';
import '../core/local_notifications_service.dart';
import '../providers/auth_provider.dart';
import '../providers/maintenance_provider.dart';
import '../views/screens/auth/login_screen.dart';
import '../views/screens/auth/register_screen.dart';
import '../views/screens/chat/chat_screen.dart';
import '../views/screens/history/trip_history_screen.dart';
import '../views/screens/home/driver_home_screen.dart';
import '../views/screens/hub/achievements_screen.dart';
import '../views/screens/hub/driver_hub_screen.dart';
import '../views/screens/hr/attendance_screen.dart';
import '../views/screens/hr/leave_request_screen.dart';
import '../views/screens/maintenance/maintenance_screen.dart';
import '../views/screens/onboarding/driver_onboarding_hub_screen.dart';
import '../views/screens/onboarding/driver_onboarding_wizard_screen.dart';
import '../views/screens/onboarding/driver_post_approval_welcome_screen.dart';
import '../views/screens/onboarding/driver_welcome_screen.dart';
import '../views/screens/profile/change_password_screen.dart';
import '../views/screens/profile/edit_profile_screen.dart';
import '../views/screens/settings/settings_screen.dart';
import '../views/screens/splash/splash_screen.dart';
import '../views/screens/training/driver_training_screen.dart';
import '../views/screens/trip/active_trip_screen.dart';
import '../views/screens/trip/trip_completed_screen.dart';

const _trainingBlockedPaths = {
  '/home',
  '/hub',
  '/attendance',
  '/leave',
  '/achievements',
  '/history',
};

final goRouterProvider = Provider<GoRouter>((ref) {
  final refresh = ref.watch(goRouterRefreshProvider);
  final guard = ref.watch(driverRouteGuardProvider);
  final maintenance = ref.watch(maintenanceControllerProvider);
  final router = GoRouter(
    initialLocation: '/splash',
    refreshListenable: Listenable.merge([refresh, guard, maintenance]),
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
        if (session == null) return '/login';
        return '/home';
      }

      if (session == null) {
        if (loc != '/login' && loc != '/register') return '/login';
        return null;
      }

      if (!guard.ready) return null;

      if (guard.needsOnboarding) {
        if (isDriverOnboardingRoute(loc)) return null;
        return '/onboarding';
      }

      if (loc == '/welcome-approved') return null;

      if (guard.needsTraining) {
        if (loc == '/training' || loc == '/settings') return null;
        if (_trainingBlockedPaths.contains(loc) ||
            loc.startsWith('/trip/') ||
            loc.startsWith('/chat/')) {
          return '/training';
        }
        if (loc == '/welcome-approved') return '/training';
        return loc == '/home' || loc == '/hub' ? '/training' : null;
      }

      if (loc == '/training') return '/home';

      if (loc == '/onboarding' || loc.startsWith('/onboarding/')) {
        return '/home';
      }
      if (loc == '/login' || loc == '/register') {
        return '/home';
      }
      return null;
    },
    routes: [
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: '/maintenance',
        builder: (context, state) => MaintenanceScreen(status: maintenance.status),
      ),
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/welcome',
        builder: (context, state) => const DriverWelcomeScreen(),
      ),
      GoRoute(
        path: '/welcome-approved',
        builder: (context, state) {
          final replay = state.uri.queryParameters['replay'] == '1';
          return DriverPostApprovalWelcomeScreen(replay: replay);
        },
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
        builder: (context, state) => const DriverOnboardingHubScreen(),
        routes: [
          GoRoute(
            path: 'apply',
            builder: (context, state) {
              final step = int.tryParse(state.uri.queryParameters['step'] ?? '') ?? 1;
              return DriverOnboardingWizardScreen(initialStep: step);
            },
          ),
        ],
      ),
      GoRoute(
        path: '/training',
        builder: (context, state) => const DriverTrainingScreen(),
      ),
      GoRoute(
        path: '/home',
        builder: (context, state) => const DriverHomeScreen(),
      ),
      GoRoute(
        path: '/hub',
        builder: (context, state) => const DriverHubScreen(),
      ),
      GoRoute(
        path: '/attendance',
        builder: (context, state) => const AttendanceScreen(),
      ),
      GoRoute(
        path: '/leave',
        builder: (context, state) => const LeaveRequestScreen(),
      ),
      GoRoute(
        path: '/achievements',
        builder: (context, state) => const AchievementsScreen(),
      ),
      GoRoute(
        path: '/profile/edit',
        builder: (context, state) => const EditProfileScreen(),
      ),
      GoRoute(
        path: '/profile/password',
        builder: (context, state) => const ChangePasswordScreen(),
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
          return ActiveTripScreen(tripId: id);
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
        builder: (context, state) => const TripHistoryScreen(),
      ),
      GoRoute(
        path: '/profile',
        redirect: (_, __) => '/hub',
      ),
    ],
  );
  LocalNotificationsService.onChatMessageTap = (tripId) {
    router.go('/trip/$tripId');
  };
  return router;
});
