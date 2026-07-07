import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/driver_local_store.dart';
import '../../../core/driver_route_guard.dart';
import '../../components/primary_button.dart';

class DriverWelcomeScreen extends ConsumerStatefulWidget {
  const DriverWelcomeScreen({super.key});

  @override
  ConsumerState<DriverWelcomeScreen> createState() => _DriverWelcomeScreenState();
}

class _DriverWelcomeScreenState extends ConsumerState<DriverWelcomeScreen> {
  final _page = PageController();
  var _index = 0;

  static const _pages = [
    _WelcomePage(
      icon: Icons.electric_moped_rounded,
      title: 'Welcome to ${AppStrings.brandName}',
      body:
          'You\'re joining the Carmona e-trike fleet. This app is your work companion — trips, attendance, and performance all in one place.',
    ),
    _WelcomePage(
      icon: Icons.verified_user_outlined,
      title: 'Complete onboarding',
      body:
          'After registration, complete your driver onboarding — personal info and required documents — right in this app.\n\n'
          'Our operator reviews your application in the admin portal. Once approved, you can go Online and accept bookings.',
      bullets: [
        'Fill in personal details accurately',
        'Upload your PDL, clearances, and health docs',
        'Submit for review (usually 1 business day)',
        'Approved → toggle Online on the map screen',
      ],
    ),
    _WelcomePage(
      icon: Icons.schedule_rounded,
      title: 'Time in & time out',
      body:
          'Company drivers must clock in at the start of shift and clock out when done. This is separate from going Online for trips — both matter for HR records.',
      bullets: [
        'Time In when you start your shift',
        'Go Online to receive ride requests',
        'Time Out when your shift ends',
        'Request VL / SL for planned or sick leave',
      ],
    ),
    _WelcomePage(
      icon: Icons.emoji_events_outlined,
      title: 'Track your progress',
      body:
          'View trip history, earnings stats, and achievements as you complete more rides. Your operator can see attendance and leave requests on the admin dashboard.',
    ),
  ];

  Future<void> _finish() async {
    await DriverLocalStore.setOnboardingComplete(true);
    if (!mounted) return;
    await ref.read(driverRouteGuardProvider).refresh();
    final needsOnboarding = ref.read(driverRouteGuardProvider).needsOnboarding;
    if (!mounted) return;
    context.go(needsOnboarding ? '/onboarding' : '/home');
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
                onPressed: _finish,
                child: const Text('Skip'),
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
                (i) => Container(
                  width: i == _index ? 20 : 8,
                  height: 8,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    color: i == _index ? AppColors.accent : AppColors.textSecondary.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: PrimaryButton(
                label: _index == _pages.length - 1 ? 'Get started' : 'Continue',
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

class _WelcomePage extends StatelessWidget {
  const _WelcomePage({
    required this.icon,
    required this.title,
    required this.body,
    this.bullets,
  });

  final IconData icon;
  final String title;
  final String body;
  final List<String>? bullets;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
