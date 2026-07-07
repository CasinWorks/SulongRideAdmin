import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_decorations.dart';
import '../../../../core/constants/app_text_styles.dart';

enum TripVisualPhase { searching, assigned, arrived, enRoute }

TripVisualPhase tripVisualPhase(String status) {
  return switch (status) {
    'accepted' => TripVisualPhase.assigned,
    'ongoing' => TripVisualPhase.enRoute,
    _ => TripVisualPhase.searching,
  };
}

/// Centered floating status card with phase-specific motion.
class TripStatusBanner extends StatefulWidget {
  const TripStatusBanner({
    super.key,
    required this.title,
    required this.subtitle,
    required this.etaLabel,
    required this.phase,
    required this.titleColor,
  });

  final String title;
  final String subtitle;
  final String etaLabel;
  final TripVisualPhase phase;
  final Color titleColor;

  @override
  State<TripStatusBanner> createState() => _TripStatusBannerState();
}

class _TripStatusBannerState extends State<TripStatusBanner>
    with TickerProviderStateMixin {
  late final AnimationController _enter;
  late final AnimationController _pulse;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _enter = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 480),
    );
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat();
    _scale = CurvedAnimation(parent: _enter, curve: Curves.easeOutBack);
    _enter.forward();
  }

  @override
  void didUpdateWidget(covariant TripStatusBanner oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.phase != widget.phase) {
      _enter
        ..reset()
        ..forward();
    }
  }

  @override
  void dispose() {
    _enter.dispose();
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: Tween<double>(begin: 0.92, end: 1).animate(_scale),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: AppDecorations.ecoCard.copyWith(
          color: AppColors.forestMedium.withValues(alpha: 0.96),
          border: Border.all(
            color: widget.titleColor.withValues(alpha: 0.35),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: widget.titleColor.withValues(alpha: 0.18),
              blurRadius: 24,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _PhaseIcon(phase: widget.phase, pulse: _pulse),
            const SizedBox(height: 12),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 320),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              transitionBuilder: (child, anim) => FadeTransition(
                opacity: anim,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 0.15),
                    end: Offset.zero,
                  ).animate(anim),
                  child: child,
                ),
              ),
              child: Column(
                key: ValueKey(widget.phase),
                children: [
                  Text(
                    widget.title,
                    textAlign: TextAlign.center,
                    style: AppTextStyles.headingSm.copyWith(
                      color: widget.titleColor,
                      fontSize: 17,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.subtitle,
                    textAlign: TextAlign.center,
                    style: AppTextStyles.bodySecondary.copyWith(fontSize: 12),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.forestLight.withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'ETA',
                    style: AppTextStyles.label.copyWith(fontSize: 10),
                  ),
                  const SizedBox(width: 8),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 260),
                    child: Text(
                      widget.etaLabel,
                      key: ValueKey(widget.etaLabel),
                      style: AppTextStyles.headingSm.copyWith(
                        color: AppColors.ecoGreenLight,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PhaseIcon extends StatelessWidget {
  const _PhaseIcon({required this.phase, required this.pulse});

  final TripVisualPhase phase;
  final Animation<double> pulse;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 72,
      height: 72,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (phase == TripVisualPhase.searching) ...[
            _RadarRing(pulse: pulse, delay: 0),
            _RadarRing(pulse: pulse, delay: 0.33),
            _RadarRing(pulse: pulse, delay: 0.66),
          ] else ...[
            _GlowRing(pulse: pulse, color: _phaseColor(phase)),
          ],
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  _phaseColor(phase).withValues(alpha: 0.9),
                  AppColors.forestLight,
                ],
              ),
            ),
            child: Icon(_phaseIcon(phase), color: AppColors.ecoCream, size: 24),
          ),
        ],
      ),
    );
  }

  static Color _phaseColor(TripVisualPhase phase) => switch (phase) {
        TripVisualPhase.searching => AppColors.textSecondary,
        TripVisualPhase.assigned => AppColors.ecoGreen,
        TripVisualPhase.arrived => AppColors.ecoGreenLight,
        TripVisualPhase.enRoute => AppColors.ecoGreenLight,
      };

  static IconData _phaseIcon(TripVisualPhase phase) => switch (phase) {
        TripVisualPhase.searching => Icons.radar,
        TripVisualPhase.assigned => Icons.electric_rickshaw_outlined,
        TripVisualPhase.arrived => Icons.location_on_outlined,
        TripVisualPhase.enRoute => Icons.route_outlined,
      };
}

class _RadarRing extends StatelessWidget {
  const _RadarRing({required this.pulse, required this.delay});

  final Animation<double> pulse;
  final double delay;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: pulse,
      builder: (context, _) {
        final t = (pulse.value + delay) % 1.0;
        final scale = 0.5 + t * 0.9;
        final opacity = (1 - t).clamp(0.0, 1.0);
        return Transform.scale(
          scale: scale,
          child: Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: AppColors.ecoGreen.withValues(alpha: opacity * 0.55),
                width: 2,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _GlowRing extends StatelessWidget {
  const _GlowRing({required this.pulse, required this.color});

  final Animation<double> pulse;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: pulse,
      builder: (context, _) {
        final breathe = 0.85 + math.sin(pulse.value * math.pi * 2) * 0.08;
        return Transform.scale(
          scale: breathe,
          child: Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.45),
                  blurRadius: 18,
                  spreadRadius: 4,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Animated progress rail: Assigned → Arrived → En route.
class TripProgressRail extends StatefulWidget {
  const TripProgressRail({super.key, required this.status});

  final String status;

  @override
  State<TripProgressRail> createState() => _TripProgressRailState();
}

class _TripProgressRailState extends State<TripProgressRail>
    with SingleTickerProviderStateMixin {
  late final AnimationController _shimmer;

  @override
  void initState() {
    super.initState();
    _shimmer = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
  }

  @override
  void dispose() {
    _shimmer.dispose();
    super.dispose();
  }

  int get _activeIndex => switch (widget.status) {
        'accepted' => 1,
        'ongoing' => 2,
        _ => 0,
      };

  bool _isDone(int index) {
    if (widget.status == 'ongoing') return index < 2;
    if (widget.status == 'accepted') return index == 0;
    return false;
  }

  @override
  Widget build(BuildContext context) {
    const labels = ['Assigned', 'Arrived', 'En route'];
    return Row(
      children: [
        for (var i = 0; i < 3; i++) ...[
          if (i > 0)
            Expanded(
              child: _AnimatedConnector(
                filled: _activeIndex > i,
                shimmer: _shimmer,
                active: _activeIndex == i,
              ),
            ),
          _ProgressStep(
            label: labels[i],
            done: _isDone(i),
            current: _activeIndex == i && widget.status != 'requested',
            waiting: widget.status == 'requested' && i == 0,
          ),
        ],
      ],
    );
  }
}

class _ProgressStep extends StatefulWidget {
  const _ProgressStep({
    required this.label,
    required this.done,
    required this.current,
    required this.waiting,
  });

  final String label;
  final bool done;
  final bool current;
  final bool waiting;

  @override
  State<_ProgressStep> createState() => _ProgressStepState();
}

class _ProgressStepState extends State<_ProgressStep>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;
  late final Animation<double> _ring;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _scale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.22), weight: 40),
      TweenSequenceItem(tween: Tween(begin: 1.22, end: 1.0), weight: 60),
    ]).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    _ring = Tween<double>(begin: 0.6, end: 1.35).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
    _syncAnimation();
  }

  @override
  void didUpdateWidget(covariant _ProgressStep oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.done != widget.done && widget.done) {
      _controller.forward(from: 0);
    }
    _syncAnimation();
  }

  void _syncAnimation() {
    if (widget.current || widget.waiting) {
      if (!_controller.isAnimating) _controller.repeat();
    } else {
      _controller.stop();
      _controller.value = 0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final active = widget.done || widget.current || widget.waiting;
    return Column(
      children: [
        SizedBox(
          width: 28,
          height: 28,
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (widget.current || widget.waiting)
                AnimatedBuilder(
                  animation: _controller,
                  builder: (context, _) => Transform.scale(
                    scale: _ring.value,
                    child: Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppColors.ecoGreen.withValues(
                            alpha: (1.4 - _ring.value).clamp(0.0, 1.0),
                          ),
                          width: 2,
                        ),
                      ),
                    ),
                  ),
                ),
              AnimatedBuilder(
                animation: _controller,
                builder: (context, child) => Transform.scale(
                  scale: widget.done ? _scale.value.clamp(1.0, 1.22) : 1.0,
                  child: child,
                ),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 350),
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    color: widget.done
                        ? AppColors.ecoGreen
                        : active
                            ? AppColors.forestLight
                            : AppColors.forestMedium,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: active ? AppColors.ecoGreenLight : AppColors.forestLight,
                      width: widget.current ? 2 : 1,
                    ),
                    boxShadow: widget.current
                        ? [
                            BoxShadow(
                              color: AppColors.ecoGreen.withValues(alpha: 0.5),
                              blurRadius: 10,
                            ),
                          ]
                        : null,
                  ),
                  child: widget.done
                      ? const Icon(Icons.check, size: 10, color: Colors.white)
                      : widget.waiting
                          ? _SearchingDots()
                          : null,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 280),
          style: AppTextStyles.label.copyWith(
            fontSize: 9,
            color: active ? AppColors.ecoGreenLight : AppColors.textSecondary,
            fontWeight: widget.current ? FontWeight.w800 : FontWeight.w600,
          ),
          child: Text(widget.label),
        ),
      ],
    );
  }
}

class _SearchingDots extends StatefulWidget {
  @override
  State<_SearchingDots> createState() => _SearchingDotsState();
}

class _SearchingDotsState extends State<_SearchingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) => Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(3, (i) {
          final phase = ((_c.value * 3) + i) % 3;
          final on = phase < 1.2;
          return Container(
            width: 3,
            height: 3,
            margin: const EdgeInsets.symmetric(horizontal: 1),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: on
                  ? AppColors.ecoGreenLight
                  : AppColors.ecoGreenLight.withValues(alpha: 0.25),
            ),
          );
        }),
      ),
    );
  }
}

class _AnimatedConnector extends StatelessWidget {
  const _AnimatedConnector({
    required this.filled,
    required this.shimmer,
    required this.active,
  });

  final bool filled;
  final Animation<double> shimmer;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 3,
      margin: const EdgeInsets.only(bottom: 22, left: 2, right: 2),
      decoration: BoxDecoration(
        color: AppColors.forestMedium,
        borderRadius: BorderRadius.circular(2),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(2),
        child: Stack(
          children: [
            TweenAnimationBuilder<double>(
              tween: Tween(end: filled ? 1.0 : active ? 0.35 : 0.0),
              duration: const Duration(milliseconds: 600),
              curve: Curves.easeOutCubic,
              builder: (context, value, _) => FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: value,
                child: Container(color: AppColors.ecoGreen),
              ),
            ),
            if (active && !filled)
              AnimatedBuilder(
                animation: shimmer,
                builder: (context, _) {
                  return FractionallySizedBox(
                    alignment: Alignment(shimmer.value * 2 - 1, 0),
                    widthFactor: 0.35,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.transparent,
                            AppColors.ecoGreenLight.withValues(alpha: 0.7),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}

/// Hero panel shown while waiting for a driver in the bottom sheet.
class WaitingForDriverPanel extends StatefulWidget {
  const WaitingForDriverPanel({super.key});

  @override
  State<WaitingForDriverPanel> createState() => _WaitingForDriverPanelState();
}

class _WaitingForDriverPanelState extends State<WaitingForDriverPanel>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        children: [
          SizedBox(
            height: 56,
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) => CustomPaint(
                painter: _TrikeSweepPainter(progress: _controller.value),
                child: const Center(
                  child: Icon(
                    Icons.electric_rickshaw_outlined,
                    color: AppColors.ecoGreenLight,
                    size: 28,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          _AnimatedWaitingText(),
        ],
      ),
    );
  }
}

class _AnimatedWaitingText extends StatefulWidget {
  @override
  State<_AnimatedWaitingText> createState() => _AnimatedWaitingTextState();
}

class _AnimatedWaitingTextState extends State<_AnimatedWaitingText> {
  static const _phrases = [
    'Scanning for nearby trikes',
    'Matching you with a driver',
    'Almost there',
  ];
  int _index = 0;

  @override
  void initState() {
    super.initState();
    Future<void>.delayed(const Duration(seconds: 3), _cycle);
  }

  void _cycle() {
    if (!mounted) return;
    setState(() => _index = (_index + 1) % _phrases.length);
    Future<void>.delayed(const Duration(seconds: 3), _cycle);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 400),
      child: Text(
        '${_phrases[_index]}…',
        key: ValueKey(_index),
        style: AppTextStyles.body.copyWith(color: AppColors.ecoGreenLight),
        textAlign: TextAlign.center,
      ),
    );
  }
}

class _TrikeSweepPainter extends CustomPainter {
  _TrikeSweepPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width * 0.38;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..shader = SweepGradient(
        startAngle: progress * math.pi * 2,
        colors: [
          AppColors.ecoGreen.withValues(alpha: 0.05),
          AppColors.ecoGreenLight.withValues(alpha: 0.85),
          AppColors.ecoGreen.withValues(alpha: 0.05),
        ],
        stops: const [0.0, 0.12, 0.24],
      ).createShader(Rect.fromCircle(center: center, radius: radius));

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      progress * math.pi * 2,
      math.pi * 1.2,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _TrikeSweepPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
