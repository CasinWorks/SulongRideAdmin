import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../providers/maintenance_provider.dart';
import '../../../core/driver_route_guard.dart';
import '../../../providers/onboarding_provider.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  final ValueNotifier<String?> _error = ValueNotifier<String?>(null);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  Future<void> _bootstrap() async {
    try {
      await ref.read(maintenanceControllerProvider).refresh();
      if (!mounted) return;
      if (ref.read(maintenanceControllerProvider).blocksApp) {
        context.go('/maintenance');
        return;
      }

      final session = Supabase.instance.client.auth.currentSession;
      if (!mounted) return;
      if (session == null) {
        context.go('/login');
        return;
      }

      await ref.read(onboardingRepositoryProvider).fetchBundle();
      if (!mounted) return;

      final route = await resolvePostAuthRoute(ref);
      if (!mounted) return;
      context.go(route);
    } catch (e) {
      _error.value = e.toString();
    }
  }

  @override
  void dispose() {
    _error.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String?>(
      valueListenable: _error,
      builder: (context, error, _) {
        if (error != null) {
          return Scaffold(
            backgroundColor: AppColors.background,
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Something went wrong', style: AppTextStyles.headingSm),
                    const SizedBox(height: 8),
                    Text(error, style: AppTextStyles.bodySecondary),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {
                        _error.value = null;
                        _bootstrap();
                      },
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            ),
          );
        }
        return Scaffold(
          backgroundColor: AppColors.primary,
          body: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  AppStrings.brandName,
                  style: AppTextStyles.headingLg.copyWith(color: AppColors.ecoCream),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  AppStrings.brandTagline,
                  style: AppTextStyles.bodySecondary,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  AppStrings.driverRoleLabel,
                  style: AppTextStyles.body.copyWith(color: AppColors.ecoCreamDark),
                ),
                const SizedBox(height: 28),
                const CircularProgressIndicator(color: AppColors.accent),
              ],
            ),
          ),
        );
      },
    );
  }
}
