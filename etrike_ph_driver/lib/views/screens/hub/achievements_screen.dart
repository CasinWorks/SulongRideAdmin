import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_decorations.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../models/driver_stats.dart';
import '../../../providers/hr_provider.dart';

class AchievementsScreen extends ConsumerWidget {
  const AchievementsScreen({super.key});

  IconData _iconFor(String name) => switch (name) {
        'flag' => Icons.flag_outlined,
        'local_taxi' => Icons.electric_moped_outlined,
        'emoji_events' => Icons.emoji_events_outlined,
        'schedule' => Icons.schedule_outlined,
        'calendar_month' => Icons.calendar_month_outlined,
        'payments' => Icons.payments_outlined,
        _ => Icons.star_outline,
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(driverStatsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Achievements', style: AppTextStyles.headingSm),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
      ),
      body: statsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.accent)),
        error: (e, _) => Center(child: Text('$e')),
        data: (stats) {
          final achievements = DriverAchievement.fromStats(stats);
          final unlocked = achievements.where((a) => a.unlocked).length;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: AppDecorations.ecoCard,
                child: Column(
                  children: [
                    Text('$unlocked / ${achievements.length}', style: AppTextStyles.headingLg),
                    const SizedBox(height: 4),
                    Text('Achievements unlocked', style: AppTextStyles.bodySecondary),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              ...achievements.map((a) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(16),
                  decoration: AppDecorations.ecoCard.copyWith(
                    color: a.unlocked
                        ? AppColors.forestMedium
                        : AppColors.forestMedium.withValues(alpha: 0.5),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: a.unlocked
                              ? AppColors.accent.withValues(alpha: 0.2)
                              : AppColors.textSecondary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(
                          _iconFor(a.iconName),
                          color: a.unlocked ? AppColors.accent : AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              a.title,
                              style: AppTextStyles.body.copyWith(
                                fontWeight: FontWeight.w600,
                                color: a.unlocked ? AppColors.textPrimary : AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(a.subtitle, style: AppTextStyles.bodySecondary.copyWith(fontSize: 12)),
                          ],
                        ),
                      ),
                      if (a.unlocked)
                        const Icon(Icons.check_circle, color: AppColors.accent, size: 22),
                    ],
                  ),
                );
              }),
            ],
          );
        },
      ),
    );
  }
}
