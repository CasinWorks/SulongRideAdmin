import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../providers/auth_provider.dart';
import '../../components/primary_button.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(driverProfileProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Profile', style: AppTextStyles.headingSm),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Could not load profile', style: AppTextStyles.headingSm),
                const SizedBox(height: 8),
                Text('$e', textAlign: TextAlign.center),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: () => ref.invalidate(driverProfileProvider),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
        data: (driver) {
          if (driver == null) {
            return Center(child: Text('No driver profile found.', style: AppTextStyles.body));
          }
          return Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(driver.fullName, style: AppTextStyles.headingMd),
                const SizedBox(height: 8),
                Text(driver.email, style: AppTextStyles.bodySecondary),
                const SizedBox(height: 16),
                Text('Plate', style: AppTextStyles.label),
                Text(driver.trikePlateNumber ?? '—', style: AppTextStyles.body),
                const SizedBox(height: 12),
                Text('Model', style: AppTextStyles.label),
                Text(driver.trikeModel ?? '—', style: AppTextStyles.body),
                const Spacer(),
                PrimaryButton(
                  label: 'Log out',
                  useAccent: false,
                  onPressed: () async {
                    try {
                      await ref.read(authRepositoryProvider).signOut();
                      if (context.mounted) context.go('/login');
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
                      }
                    }
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
