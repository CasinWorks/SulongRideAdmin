import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_decorations.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/hr_provider.dart';
import '../../../providers/onboarding_provider.dart';
import '../../components/driver_ui.dart';
import '../../components/primary_button.dart';

class DriverHubScreen extends ConsumerWidget {
  const DriverHubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(driverProfileProvider);
    final statsAsync = ref.watch(driverStatsProvider);
    final openAttAsync = ref.watch(openAttendanceProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.accent)),
        error: (e, _) => Center(child: Text('$e')),
        data: (driver) {
          if (driver == null) {
            return const Center(child: Text('No driver profile'));
          }
          return CustomScrollView(
            slivers: [
              SliverAppBar.large(
                backgroundColor: AppColors.background,
                foregroundColor: AppColors.textPrimary,
                title: Text('Driver Hub', style: AppTextStyles.headingSm),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.home_outlined),
                    onPressed: () => context.go('/home'),
                  ),
                ],
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: AppDecorations.ecoCard,
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 32,
                          backgroundColor: AppColors.accent.withValues(alpha: 0.2),
                          backgroundImage: driver.profilePhotoUrl != null
                              ? NetworkImage(driver.profilePhotoUrl!)
                              : null,
                          child: driver.profilePhotoUrl == null
                              ? Text(
                                  driver.fullName.isNotEmpty
                                      ? driver.fullName[0].toUpperCase()
                                      : '?',
                                  style: AppTextStyles.headingMd.copyWith(color: AppColors.accent),
                                )
                              : null,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(driver.fullName, style: AppTextStyles.headingSm),
                              const SizedBox(height: 4),
                              Text(driver.email, style: AppTextStyles.bodySecondary),
                              const SizedBox(height: 4),
                              Text(
                                '${driver.station} · ${driver.shiftSchedule}',
                                style: AppTextStyles.bodySecondary.copyWith(fontSize: 12),
                              ),
                              const SizedBox(height: 8),
                              ApprovalStatusChip(status: driver.approvalStatus),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (!driver.isApproved)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.amber.withValues(alpha: 0.6)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Onboarding in progress', style: AppTextStyles.headingSm.copyWith(fontSize: 16)),
                          const SizedBox(height: 8),
                          Text(
                            driver.approvalStatus == 'rejected'
                                ? 'Your application was not approved. Update documents in onboarding or contact your operator.'
                                : 'Complete your application and upload required documents. You cannot go Online until approved.',
                            style: AppTextStyles.bodySecondary.copyWith(height: 1.4),
                          ),
                          const SizedBox(height: 12),
                          PrimaryButton(
                            label: 'Open onboarding',
                            onPressed: () => context.go('/onboarding'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: statsAsync.when(
                    loading: () => const SizedBox(height: 80, child: Center(child: CircularProgressIndicator())),
                    error: (_, __) => const SizedBox.shrink(),
                    data: (stats) => Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            DriverStatCard(label: 'Trips', value: '${stats.completedTrips}', icon: Icons.route),
                            const SizedBox(width: 10),
                            DriverStatCard(label: 'Earnings', value: stats.earningsLabel, icon: Icons.payments_outlined),
                            const SizedBox(width: 10),
                            DriverStatCard(label: 'Rating', value: stats.ratingLabel, icon: Icons.star_outline),
                          ],
                        ),
                        if (stats.totalReviews > 0) ...[
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              DriverStatCard(
                                label: 'Reviews',
                                value: '${stats.totalReviews}',
                                icon: Icons.rate_review_outlined,
                              ),
                              const SizedBox(width: 10),
                              DriverStatCard(
                                label: 'Complaints (7d)',
                                value: '${stats.complaintsLast7d}',
                                icon: Icons.report_outlined,
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: openAttAsync.when(
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                  data: (open) {
                    if (open == null) return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.accent.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.timer_outlined, color: AppColors.accent),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Timed in since ${DateFormat.jm().format(open.clockIn.toLocal())}',
                                style: AppTextStyles.body,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 16)),
              SliverToBoxAdapter(
                child: DriverGroupedSection(
                  title: 'Workday',
                  children: [
                    DriverSettingsTile(
                      icon: Icons.login_rounded,
                      title: 'Time in / Time out',
                      subtitle: 'Clock your shift for HR records',
                      onTap: () => context.push('/attendance'),
                      showDivider: true,
                    ),
                    DriverSettingsTile(
                      icon: Icons.beach_access_outlined,
                      title: 'Leave requests',
                      subtitle: 'Vacation leave (VL) & sick leave (SL)',
                      onTap: () => context.push('/leave'),
                      showDivider: false,
                    ),
                  ],
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 20)),
              SliverToBoxAdapter(
                child: DriverGroupedSection(
                  title: 'Performance',
                  children: [
                    DriverSettingsTile(
                      icon: Icons.bar_chart_rounded,
                      title: 'Stats & history',
                      subtitle: 'Trips completed and earnings',
                      onTap: () => context.push('/history'),
                    ),
                    DriverSettingsTile(
                      icon: Icons.emoji_events_outlined,
                      title: 'Achievements',
                      subtitle: 'Milestones as you grow',
                      onTap: () => context.push('/achievements'),
                      showDivider: false,
                    ),
                  ],
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 20)),
              SliverToBoxAdapter(
                child: DriverGroupedSection(
                  title: 'Account',
                  children: [
                    DriverSettingsTile(
                      icon: Icons.person_outline,
                      title: 'Edit profile',
                      subtitle: 'Name, phone, trike details',
                      onTap: () => context.push('/profile/edit'),
                    ),
                    DriverSettingsTile(
                      icon: Icons.lock_outline,
                      title: 'Change password',
                      onTap: () => context.push('/profile/password'),
                    ),
                    DriverSettingsTile(
                      icon: Icons.settings_outlined,
                      title: 'Settings',
                      onTap: () => context.push('/settings'),
                      showDivider: false,
                    ),
                  ],
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 24)),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: PrimaryButton(
                    label: 'Log out',
                    useAccent: false,
                    onPressed: () async {
                      await ref.read(authRepositoryProvider).signOut();
                      ref.invalidate(driverProfileProvider);
                      ref.invalidate(driverStatsProvider);
                      ref.invalidate(openAttendanceProvider);
                      ref.invalidate(onboardingBundleProvider);
                      if (context.mounted) context.go('/login');
                    },
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 32)),
            ],
          );
        },
      ),
    );
  }
}
