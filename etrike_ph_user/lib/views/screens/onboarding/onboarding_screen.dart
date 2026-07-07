import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/eco/eco_local_store.dart';
import '../../components/primary_button.dart';
import 'onboarding_illustrations.dart';

class OnboardingPage {
  const OnboardingPage({
    required this.kind,
    required this.title,
    required this.body,
    this.badge,
  });

  final OnboardingIllustrationKind kind;
  final String title;
  final String body;
  final String? badge;
}

const _pages = [
  OnboardingPage(
    kind: OnboardingIllustrationKind.welcome,
    badge: 'Welcome',
    title: 'Ride clean.\nRide smart.',
    body:
        '${AppStrings.brandName} connects you to electric trikes — fast, affordable, and zero emissions.',
  ),
  OnboardingPage(
    kind: OnboardingIllustrationKind.search,
    badge: 'Step 1',
    title: 'Search your route',
    body:
        'Set your pickup and drop-off on the map, or type an address. We\'ll find the best path for you.',
  ),
  OnboardingPage(
    kind: OnboardingIllustrationKind.book,
    badge: 'Step 2',
    title: 'Book in seconds',
    body:
        'Pick your eco-trike type, see the fare upfront, and tap Book ride. A nearby driver gets notified.',
  ),
  OnboardingPage(
    kind: OnboardingIllustrationKind.pay,
    badge: 'Step 3',
    title: 'Pay your way',
    body:
        'Use cash, your in-app wallet, or a saved card. Transparent pricing — no surprises at the end.',
  ),
  OnboardingPage(
    kind: OnboardingIllustrationKind.features,
    badge: 'Explore',
    title: 'More than a ride',
    body:
        'Track live, chat with your driver, share your trip, and view your ride history.',
  ),
  OnboardingPage(
    kind: OnboardingIllustrationKind.ready,
    badge: 'You\'re set',
    title: 'Ready when you are',
    body: 'Create an account or sign in to book your first eco-ride. Malapit na — let\'s go!',
  ),
];

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, this.replay = false});

  /// When true, opened from Settings — back returns instead of login.
  final bool replay;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pageController = PageController();
  int _index = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _finish({bool toRegister = false}) async {
    if (!widget.replay) {
      await EcoLocalStore.setOnboardingCompleted(true);
    }
    if (!mounted) return;
    if (widget.replay) {
      context.pop();
      return;
    }
    context.go(toRegister ? '/register' : '/login');
  }

  void _next() {
    if (_index < _pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeOutCubic,
      );
    } else {
      _finish();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLast = _index == _pages.length - 1;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
              child: Row(
                children: [
                  if (widget.replay)
                    IconButton(
                      onPressed: () => context.pop(),
                      icon: const Icon(Icons.arrow_back, color: AppColors.ecoCream),
                    )
                  else
                    const SizedBox(width: 8),
                  const Spacer(),
                  if (!isLast)
                    TextButton(
                      onPressed: () => _finish(),
                      child: Text(
                        'Skip',
                        style: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _pages.length,
                onPageChanged: (i) => setState(() => _index = i),
                itemBuilder: (context, i) {
                  final p = _pages[i];
                  return _OnboardingPageView(
                    page: p,
                    active: _index == i,
                  );
                },
              ),
            ),
            _PageDots(count: _pages.length, index: _index),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 12),
              child: Column(
                children: [
                  PrimaryButton(
                    label: isLast ? 'Get started' : 'Next',
                    onPressed: _next,
                  ),
                  if (isLast && !widget.replay) ...[
                    const SizedBox(height: 10),
                    TextButton(
                      onPressed: () => _finish(toRegister: true),
                      child: Text(
                        'Create an account',
                        style: AppTextStyles.body.copyWith(color: AppColors.ecoGreenLight),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OnboardingPageView extends StatelessWidget {
  const _OnboardingPageView({required this.page, required this.active});

  final OnboardingPage page;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          OnboardingIllustration(kind: page.kind, active: active),
          const SizedBox(height: 20),
          if (page.badge != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: AppColors.ecoGreen.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.ecoGreen.withValues(alpha: 0.4)),
              ),
              child: Text(
                page.badge!,
                style: AppTextStyles.label.copyWith(
                  color: AppColors.ecoGreenLight,
                  fontSize: 11,
                ),
              ),
            ),
          const SizedBox(height: 14),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 320),
            child: Text(
              page.title,
              key: ValueKey(page.title),
              textAlign: TextAlign.center,
              style: AppTextStyles.headingLg.copyWith(height: 1.15),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            page.body,
            textAlign: TextAlign.center,
            style: AppTextStyles.bodySecondary.copyWith(height: 1.45, fontSize: 14),
          ),
        ],
      ),
    );
  }
}

class _PageDots extends StatelessWidget {
  const _PageDots({required this.count, required this.index});

  final int count;
  final int index;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (i) {
        final active = i == index;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 280),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: active ? 22 : 7,
          height: 7,
          decoration: BoxDecoration(
            color: active ? AppColors.ecoGreen : AppColors.forestLight,
            borderRadius: BorderRadius.circular(4),
          ),
        );
      }),
    );
  }
}
