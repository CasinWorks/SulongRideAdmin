import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/app_router.dart';
import 'core/constants/app_colors.dart';
import 'core/constants/app_strings.dart';
import 'core/constants/app_text_styles.dart';
import 'core/constants/keys.dart';
import 'core/local_notifications_service.dart';
import 'core/message_notifications.dart';
import 'core/trip_live_activity_service.dart';
import 'core/platform/platform_flags.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark,
      systemNavigationBarColor: AppColors.forestDark,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );
  if (kIsWeb) {
    runApp(const _WebNotSupportedApp(role: AppStrings.riderRoleLabel));
    return;
  }
  if (!googleMapsKeysConfigured) {
    runApp(const _MapsKeyConfigErrorApp());
    return;
  }
  runApp(const _AppBootstrap());
}

/// Runs async SDK init after the first Flutter frame so iOS never sits on a
/// white launch screen while PlatformFlags / Supabase / notifications start.
class _AppBootstrap extends StatefulWidget {
  const _AppBootstrap();

  @override
  State<_AppBootstrap> createState() => _AppBootstrapState();
}

class _AppBootstrapState extends State<_AppBootstrap> {
  Object? _error;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _runInit();
  }

  Future<void> _runInit() async {
    setState(() {
      _error = null;
      _ready = false;
    });
    try {
      await PlatformFlags.initialize().timeout(const Duration(seconds: 10));
      await Supabase.initialize(
        url: supabaseUrl,
        anonKey: supabaseAnonKey,
      ).timeout(const Duration(seconds: 20));
      // Non-blocking: notification setup can be slow on first iOS launch.
      unawaited(
        LocalNotificationsService.initialize().timeout(
          const Duration(seconds: 15),
          onTimeout: () => debugPrint('Local notifications init timed out'),
        ),
      );
      await TripLiveActivityService.init();
      // Clear orphaned Dynamic Island / lock-screen activities from prior sessions.
      await TripLiveActivityService.end();
      if (mounted) setState(() => _ready = true);
    } catch (e, st) {
      debugPrint('Bootstrap init failed: $e\n$st');
      if (mounted) setState(() => _error = e);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_ready) {
      return const ProviderScope(child: SulongRideUserApp());
    }
    if (_error != null) {
      return _BootstrapErrorApp(
        error: _error.toString(),
        onRetry: _runInit,
      );
    }
    return const _BootstrapSplash();
  }
}

/// Branded splash shown immediately on first frame (matches in-app splash).
class _WebNotSupportedApp extends StatelessWidget {
  const _WebNotSupportedApp({required this.role});

  final String role;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '${AppStrings.brandName} — $role',
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.phone_iphone, size: 48, color: AppColors.accent),
                const SizedBox(height: 16),
                Text('Mobile app only', style: AppTextStyles.headingSm),
                const SizedBox(height: 12),
                Text(
                  'The $role app runs on iPhone and Android only.\n\n'
                  'For the operator dashboard, run:\n'
                  'cd etrike_ph_admin\n'
                  'flutter run -d chrome',
                  style: AppTextStyles.bodySecondary,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BootstrapSplash extends StatelessWidget {
  const _BootstrapSplash();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppStrings.brandName,
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: AppColors.primary,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                AppStrings.brandName,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                AppStrings.brandTagline,
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.white70,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                AppStrings.riderRoleLabel,
                style: const TextStyle(
                  fontSize: 15,
                  color: Colors.white70,
                ),
              ),
              const SizedBox(height: 28),
              const CircularProgressIndicator(color: AppColors.accent),
            ],
          ),
        ),
      ),
    );
  }
}

class _BootstrapErrorApp extends StatelessWidget {
  const _BootstrapErrorApp({
    required this.error,
    required this.onRetry,
  });

  final String error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppStrings.brandName,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: AppColors.background,
        colorScheme: ColorScheme.fromSeed(seedColor: AppColors.accent),
      ),
      home: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 48, color: AppColors.error),
                const SizedBox(height: 16),
                Text('Could not start the app', style: AppTextStyles.headingSm),
                const SizedBox(height: 12),
                Text(
                  error,
                  style: AppTextStyles.bodySecondary,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: onRetry,
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Shown when Maps SDK / REST keys are missing or identical — avoids a blank screen.
class _MapsKeyConfigErrorApp extends StatelessWidget {
  const _MapsKeyConfigErrorApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppStrings.brandName,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: AppColors.background,
        colorScheme: ColorScheme.fromSeed(seedColor: AppColors.accent),
      ),
      home: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.map_outlined, size: 48, color: AppColors.error),
                const SizedBox(height: 16),
                Text('Google Maps not configured', style: AppTextStyles.headingSm),
                const SizedBox(height: 12),
                Text(
                  'Set googleMapsNativeApiKey in lib/core/constants/keys.dart, '
                  'copy it to ios/Runner/Info.plist (GMSApiKey) and '
                  'android/app/src/main/AndroidManifest.xml. '
                  'Use a different key for googleMapsWebServicesApiKey.',
                  style: AppTextStyles.bodySecondary,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class SulongRideUserApp extends ConsumerWidget {
  const SulongRideUserApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(messageNotificationsProvider);
    final router = ref.watch(goRouterProvider);
    return MaterialApp.router(
      title: AppStrings.brandName,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: AppColors.background,
        colorScheme: const ColorScheme.dark(
          primary: AppColors.ecoGreen,
          secondary: AppColors.ecoGreenLight,
          surface: AppColors.surface,
          onPrimary: AppColors.ecoCream,
          onSurface: AppColors.ecoCream,
        ),
        appBarTheme: AppBarTheme(
          centerTitle: false,
          backgroundColor: AppColors.surface,
          foregroundColor: AppColors.textPrimary,
          titleTextStyle: AppTextStyles.headingSm,
        ),
        snackBarTheme: const SnackBarThemeData(
          backgroundColor: AppColors.forestMedium,
          contentTextStyle: TextStyle(color: AppColors.ecoCream),
        ),
      ),
      routerConfig: router,
    );
  }
}
