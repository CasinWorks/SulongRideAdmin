import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/driver_local_store.dart';
import '../../../providers/auth_provider.dart';
import '../../components/primary_button.dart';

class DriverPostApprovalWelcomeScreen extends ConsumerStatefulWidget {
  const DriverPostApprovalWelcomeScreen({super.key, this.replay = false});

  /// Opened from Settings — back returns without changing completion state.
  final bool replay;

  @override
  ConsumerState<DriverPostApprovalWelcomeScreen> createState() =>
      _DriverPostApprovalWelcomeScreenState();
}

class _DriverPostApprovalWelcomeScreenState
    extends ConsumerState<DriverPostApprovalWelcomeScreen> {
  final _page = PageController();
  var _index = 0;

  static const _pages = [
    _TutorialPage(
      icon: Icons.celebration_rounded,
      title: 'You\'re approved!',
      body:
          'Welcome to the ${AppStrings.brandName} fleet. Your onboarding documents were reviewed and you\'re cleared to drive.\n\n'
          'This quick tour shows how to use the app day to day.',
      accent: true,
    ),
    _TutorialPage(
      icon: Icons.map_outlined,
      title: 'Home map & going Online',
      body:
          'The Home screen is your command center. When you\'re ready to accept rides, toggle Online.',
      bullets: [
        'Allow location while using the app — required when Online',
        'Online = visible to riders and eligible for trip requests',
        'Go Offline when you\'re on break or ending your shift',
        'Open Driver Hub from the top bar for profile and tools',
      ],
    ),
    _TutorialPage(
      icon: Icons.notifications_active_outlined,
      title: 'Trip requests & active rides',
      body:
          'When a rider books nearby, you\'ll get an incoming request sheet with pickup and fare.',
      bullets: [
        'Accept to start navigation to the pickup point',
        'Use in-app chat to message the rider during the trip',
        'Mark arrived, start trip, then complete when you reach drop-off',
        'External maps (Google/Waze) open from the trip screen if needed',
      ],
    ),
    _TutorialPage(
      icon: Icons.schedule_rounded,
      title: 'Time in, time out & leave',
      body:
          'HR attendance is separate from going Online. Clock in at the start of your company shift.',
      bullets: [
        'Time In / Time Out under Driver Hub → Workday',
        'Request Vacation Leave (VL) or Sick Leave (SL) in advance',
        'Your operator sees attendance and leave on the admin dashboard',
      ],
    ),
    _TutorialPage(
      icon: Icons.insights_outlined,
      title: 'Stats, history & achievements',
      body:
          'Track your performance as you complete more trips.',
      bullets: [
        'Driver Hub shows trips, earnings, and rider rating',
        'Trip history lists completed rides and fares',
        'Achievements unlock milestones as you grow',
        'Edit profile, password, and notification settings anytime',
      ],
    ),
    _TutorialPage(
      icon: Icons.electric_moped_rounded,
      title: 'Ready to drive',
      body:
          'Time In for your shift, go Online on the map, and accept your first booking. Mabuhay and drive safe!',
      bullets: [
        'Home → toggle Online',
        'Hub → Time in when your shift starts',
        'Replay this tour anytime in Settings',
      ],
    ),
  ];

  Future<void> _finish({bool skipped = false}) async {
    if (!widget.replay) {
      final uid = ref.read(supabaseClientProvider).auth.currentUser?.id;
      if (uid != null) {
        await DriverLocalStore.setPostApprovalWelcomeComplete(uid, complete: true);
      }
    }
    if (!mounted) return;
    if (widget.replay) {
      context.pop();
      return;
    }
    context.go('/home');
  }

  @override
  void dispose() {
    _page.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => _finish(skipped: true),
                child: Text(widget.replay ? 'Close' : 'Skip tour'),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _page,
                itemCount: _pages.length,
                onPageChanged: (i) => setState(() => _index = i),
                itemBuilder: (_, i) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  child: _pages[i],
                ),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                _pages.length,
                (i) => AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: i == _index ? 20 : 8,
                  height: 8,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    color: i == _index
                        ? AppColors.accent
                        : AppColors.textSecondary.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: PrimaryButton(
                label: _index == _pages.length - 1
                    ? (widget.replay ? 'Done' : 'Start driving')
                    : 'Next',
                onPressed: () {
                  if (_index < _pages.length - 1) {
                    _page.nextPage(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOut,
                    );
                  } else {
                    _finish();
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TutorialPage extends StatelessWidget {
  const _TutorialPage({
    required this.icon,
    required this.title,
    required this.body,
    this.bullets,
    this.accent = false,
  });

  final IconData icon;
  final String title;
  final String body;
  final List<String>? bullets;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (accent)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              'Account activated',
              style: AppTextStyles.bodySecondary.copyWith(
                color: AppColors.accent,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: AppColors.accent.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Icon(icon, size: 36, color: AppColors.accent),
        ),
        const SizedBox(height: 28),
        Text(title, style: AppTextStyles.headingLg),
        const SizedBox(height: 16),
        Text(body, style: AppTextStyles.bodySecondary.copyWith(height: 1.5)),
        if (bullets != null) ...[
          const SizedBox(height: 20),
          ...bullets!.map(
            (b) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.check_circle_outline, size: 18, color: AppColors.accent),
                  const SizedBox(width: 10),
                  Expanded(child: Text(b, style: AppTextStyles.body)),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}
