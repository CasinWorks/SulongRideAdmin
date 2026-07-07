import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_decorations.dart';
import '../../../core/constants/app_text_styles.dart';

enum OnboardingIllustrationKind {
  welcome,
  search,
  book,
  pay,
  features,
  ready,
}

class OnboardingIllustration extends StatefulWidget {
  const OnboardingIllustration({
    super.key,
    required this.kind,
    required this.active,
  });

  final OnboardingIllustrationKind kind;
  final bool active;

  @override
  State<OnboardingIllustration> createState() => _OnboardingIllustrationState();
}

class _OnboardingIllustrationState extends State<OnboardingIllustration>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(seconds: 4))
      ..repeat();
    if (widget.active) _c.forward(from: 0);
  }

  @override
  void didUpdateWidget(covariant OnboardingIllustration oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !oldWidget.active) {
      _c.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 280,
      width: double.infinity,
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) => switch (widget.kind) {
          OnboardingIllustrationKind.welcome => _WelcomeScene(t: _c.value),
          OnboardingIllustrationKind.search => _SearchScene(t: _c.value),
          OnboardingIllustrationKind.book => _BookScene(t: _c.value),
          OnboardingIllustrationKind.pay => _PayScene(t: _c.value),
          OnboardingIllustrationKind.features => _FeaturesScene(t: _c.value),
          OnboardingIllustrationKind.ready => _ReadyScene(t: _c.value),
        },
      ),
    );
  }
}

class _WelcomeScene extends StatelessWidget {
  const _WelcomeScene({required this.t});

  final double t;

  @override
  Widget build(BuildContext context) {
    final slide = Curves.easeOutCubic.transform((t * 2).clamp(0.0, 1.0));
    return Stack(
      alignment: Alignment.center,
      children: [
        ...List.generate(6, (i) {
          final angle = (i / 6) * math.pi * 2 + t * math.pi * 2;
          return Transform.translate(
            offset: Offset(math.cos(angle) * 100, math.sin(angle) * 60 - 20),
            child: Icon(
              Icons.eco_outlined,
              size: 16,
              color: AppColors.ecoGreen.withValues(alpha: 0.25 + (i % 3) * 0.1),
            ),
          );
        }),
        Transform.translate(
          offset: Offset(120 * (1 - slide), 0),
          child: Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  AppColors.ecoGreen.withValues(alpha: 0.35),
                  Colors.transparent,
                ],
              ),
            ),
            child: Icon(
              Icons.electric_rickshaw_outlined,
              size: 88,
              color: AppColors.ecoGreenLight.withValues(alpha: 0.9 + math.sin(t * math.pi * 2) * 0.1),
            ),
          ),
        ),
      ],
    );
  }
}

class _SearchScene extends StatelessWidget {
  const _SearchScene({required this.t});

  final double t;

  @override
  Widget build(BuildContext context) {
    final drop = Curves.elasticOut.transform((t * 1.4).clamp(0.0, 1.0));
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Stack(
        children: [
          Container(
            height: 200,
            decoration: BoxDecoration(
              color: AppColors.mapBg,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.forestLight),
            ),
            child: CustomPaint(
              painter: _GridPainter(opacity: 0.08),
              size: Size.infinite,
            ),
          ),
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: AppDecorations.ecoInput,
              child: Row(
                children: [
                  const Icon(Icons.search, color: AppColors.ecoGreenLight, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _typewriter('SM Megamall, Ortigas…', t),
                      style: AppTextStyles.body.copyWith(fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            left: 48,
            top: 90 + (1 - drop) * -40,
            child: _MapPin(color: AppColors.pickupPin, label: 'Pickup', visible: drop),
          ),
          Positioned(
            right: 52,
            top: 130 + (1 - drop) * -50,
            child: _MapPin(color: AppColors.dropoffPin, label: 'Dropoff', visible: drop),
          ),
        ],
      ),
    );
  }

  String _typewriter(String text, double t) {
    final count = (text.length * (t * 1.8).clamp(0.0, 1.0)).floor();
    return text.substring(0, count);
  }
}

class _BookScene extends StatelessWidget {
  const _BookScene({required this.t});

  final double t;

  @override
  Widget build(BuildContext context) {
    final sheetUp = Curves.easeOutCubic.transform((t * 1.2).clamp(0.0, 1.0));
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.bottomCenter,
        children: [
          Container(
            height: 160,
            decoration: BoxDecoration(
              color: AppColors.mapBg,
              borderRadius: BorderRadius.circular(20),
            ),
          ),
          Transform.translate(
            offset: Offset(0, 80 * (1 - sheetUp)),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: AppDecorations.ecoDrawer(opacity: 0.98),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.forestLight,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _VehicleChip(
                        icon: Icons.electric_rickshaw_outlined,
                        label: 'Commuter',
                        selected: t % 1 > 0.15 && t % 1 < 0.55,
                      ),
                      _VehicleChip(
                        icon: Icons.airline_seat_recline_normal,
                        label: 'Premium',
                        selected: t % 1 >= 0.55 && t % 1 < 0.85,
                      ),
                      _VehicleChip(
                        icon: Icons.groups_2_outlined,
                        label: 'Sidecar',
                        selected: t % 1 >= 0.85,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.ecoGreen,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Book eco-ride',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.button.copyWith(fontSize: 14),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PayScene extends StatelessWidget {
  const _PayScene({required this.t});

  final double t;

  @override
  Widget build(BuildContext context) {
    final balance = (87 * Curves.easeOut.transform((t * 1.5).clamp(0.0, 1.0))).round();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _PayCard(
                icon: Icons.account_balance_wallet_outlined,
                label: 'Wallet',
                highlight: t % 1 < 0.33,
                offset: math.sin(t * math.pi * 2) * 4,
              ),
              const SizedBox(width: 12),
              _PayCard(
                icon: Icons.payments_outlined,
                label: 'Cash',
                highlight: t % 1 >= 0.33 && t % 1 < 0.66,
                offset: math.sin(t * math.pi * 2 + 1) * 4,
              ),
              const SizedBox(width: 12),
              _PayCard(
                icon: Icons.credit_card,
                label: 'Card',
                highlight: t % 1 >= 0.66,
                offset: math.sin(t * math.pi * 2 + 2) * 4,
              ),
            ],
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            decoration: AppDecorations.ecoCard,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.receipt_long_outlined, color: AppColors.ecoGreenLight, size: 20),
                const SizedBox(width: 12),
                Text('₱$balance', style: AppTextStyles.displayMetric.copyWith(fontSize: 32)),
                const SizedBox(width: 8),
                Text('estimated', style: AppTextStyles.label.copyWith(fontSize: 10)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FeaturesScene extends StatelessWidget {
  const _FeaturesScene({required this.t});

  final double t;

  static const _items = [
    (Icons.history, 'Ride history'),
    (Icons.shield_outlined, 'Safety toolkit'),
    (Icons.chat_bubble_outline, 'Driver chat'),
    (Icons.eco_outlined, 'CO₂ saved'),
    (Icons.share_outlined, 'Share trip'),
    (Icons.settings_outlined, 'Settings'),
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        alignment: WrapAlignment.center,
        children: List.generate(_items.length, (i) {
          final delay = i * 0.08;
          final progress = ((t - delay) * 2).clamp(0.0, 1.0);
          final scale = Curves.easeOutBack.transform(progress);
          return Transform.scale(
            scale: scale,
            child: Opacity(
              opacity: progress,
              child: Container(
                width: 96,
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
                decoration: AppDecorations.ecoCard,
                child: Column(
                  children: [
                    Icon(_items[i].$1, color: AppColors.ecoGreenLight, size: 22),
                    const SizedBox(height: 6),
                    Text(
                      _items[i].$2,
                      textAlign: TextAlign.center,
                      style: AppTextStyles.label.copyWith(fontSize: 9),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _ReadyScene extends StatelessWidget {
  const _ReadyScene({required this.t});

  final double t;

  @override
  Widget build(BuildContext context) {
  return Stack(
      alignment: Alignment.center,
      children: [
        ...List.generate(12, (i) {
          final angle = (i / 12) * math.pi * 2;
          final radius = 70 + math.sin(t * math.pi * 2 + i) * 12;
          return Transform.translate(
            offset: Offset(math.cos(angle + t) * radius, math.sin(angle + t) * radius * 0.6),
            child: Icon(
              Icons.star_rounded,
              size: 10 + (i % 3) * 4,
              color: AppColors.ecoGreenLight.withValues(alpha: 0.35 + (i % 4) * 0.12),
            ),
          );
        }),
        Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.ecoGreen.withValues(alpha: 0.2),
            border: Border.all(color: AppColors.ecoGreenLight, width: 2),
          ),
          child: Icon(
            Icons.check_rounded,
            size: 56,
            color: AppColors.ecoGreenLight.withValues(
              alpha: 0.7 + math.sin(t * math.pi * 2) * 0.3,
            ),
          ),
        ),
      ],
    );
  }
}

class _MapPin extends StatelessWidget {
  const _MapPin({required this.color, required this.label, required this.visible});

  final Color color;
  final String label;
  final double visible;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: visible.clamp(0.0, 1.0),
      child: Column(
        children: [
          Icon(Icons.location_on, color: color, size: 32),
          Text(label, style: AppTextStyles.label.copyWith(fontSize: 9, color: color)),
        ],
      ),
    );
  }
}

class _VehicleChip extends StatelessWidget {
  const _VehicleChip({
    required this.icon,
    required this.label,
    required this.selected,
  });

  final IconData icon;
  final String label;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 280),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: selected ? AppColors.ecoGreen.withValues(alpha: 0.25) : AppColors.forestMedium,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: selected ? AppColors.ecoGreen : AppColors.forestLight,
        ),
      ),
      child: Column(
        children: [
          Icon(icon, size: 18, color: selected ? AppColors.ecoGreenLight : AppColors.textSecondary),
          const SizedBox(height: 4),
          Text(
            label,
            style: AppTextStyles.label.copyWith(
              fontSize: 8,
              color: selected ? AppColors.ecoCream : AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _PayCard extends StatelessWidget {
  const _PayCard({
    required this.icon,
    required this.label,
    required this.highlight,
    required this.offset,
  });

  final IconData icon;
  final String label;
  final bool highlight;
  final double offset;

  @override
  Widget build(BuildContext context) {
    return Transform.translate(
      offset: Offset(0, highlight ? -8 + offset : 0),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: 88,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: highlight ? AppColors.ecoGreen.withValues(alpha: 0.2) : AppColors.forestMedium,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: highlight ? AppColors.ecoGreenLight : AppColors.forestLight,
            width: highlight ? 2 : 1,
          ),
          boxShadow: highlight
              ? [BoxShadow(color: AppColors.ecoGreen.withValues(alpha: 0.3), blurRadius: 12)]
              : null,
        ),
        child: Column(
          children: [
            Icon(icon, color: AppColors.ecoGreenLight, size: 24),
            const SizedBox(height: 6),
            Text(label, style: AppTextStyles.label.copyWith(fontSize: 10)),
          ],
        ),
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  _GridPainter({required this.opacity});

  final double opacity;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.ecoGreen.withValues(alpha: opacity)
      ..strokeWidth = 1;
    const step = 28.0;
    for (var x = 0.0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (var y = 0.0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _GridPainter oldDelegate) => false;
}
