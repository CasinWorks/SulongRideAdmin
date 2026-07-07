import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import 'trip_status_animations.dart';

/// In-app Dynamic Island pill — mirrors Live Activity compact UI while the trip
/// screen is open (iOS hides the system island when the owning app is foreground).
class TripDynamicIslandBar extends StatefulWidget {
  const TripDynamicIslandBar({
    super.key,
    required this.title,
    required this.etaLabel,
    required this.phase,
    required this.progress,
    this.onTap,
  });

  final String title;
  final String etaLabel;
  final TripVisualPhase phase;
  final int progress;
  final VoidCallback? onTap;

  @override
  State<TripDynamicIslandBar> createState() => _TripDynamicIslandBarState();
}

class _TripDynamicIslandBarState extends State<TripDynamicIslandBar>
    with TickerProviderStateMixin {
  bool _expanded = false;
  late final AnimationController _morph;
  late final AnimationController _pulse;
  late final AnimationController _phasePop;
  late final Animation<double> _widthT;

  @override
  void initState() {
    super.initState();
    _morph = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
      value: _expanded ? 1 : 0,
    );
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
    _phasePop = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    )..forward();
    _widthT = CurvedAnimation(parent: _morph, curve: Curves.easeOutCubic);
  }

  @override
  void didUpdateWidget(covariant TripDynamicIslandBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.phase != widget.phase) {
      _phasePop
        ..reset()
        ..forward();
    }
    if (oldWidget.progress != widget.progress) {
      HapticFeedback.lightImpact();
    }
  }

  @override
  void dispose() {
    _morph.dispose();
    _pulse.dispose();
    _phasePop.dispose();
    super.dispose();
  }

  void _toggleExpanded() {
    setState(() => _expanded = !_expanded);
    if (_expanded) {
      _morph.forward();
    } else {
      _morph.reverse();
    }
    HapticFeedback.selectionClick();
    widget.onTap?.call();
  }

  int get _progress => widget.progress.clamp(0, 2);

  @override
  Widget build(BuildContext context) {
    final compactWidth = 128.0;
    final expandedWidth = math.min(MediaQuery.sizeOf(context).width - 48, 320.0);

    return AnimatedBuilder(
      animation: Listenable.merge([_widthT, _pulse, _phasePop]),
      builder: (context, _) {
        final width = compactWidth + (expandedWidth - compactWidth) * _widthT.value;
        final pop = 0.92 + 0.08 * Curves.easeOutBack.transform(_phasePop.value);

        return Transform.scale(
          scale: pop,
          child: GestureDetector(
            onTap: _toggleExpanded,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 320),
              curve: Curves.easeOutCubic,
              width: width,
              constraints: BoxConstraints(minHeight: _expanded ? 72 : 37),
              padding: EdgeInsets.symmetric(
                horizontal: _expanded ? 14 : 10,
                vertical: _expanded ? 12 : 8,
              ),
              decoration: BoxDecoration(
                color: const Color(0xFF0A0A0A),
                borderRadius: BorderRadius.circular(_expanded ? 22 : 20),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.ecoGreen.withValues(alpha: 0.22),
                    blurRadius: _expanded ? 18 : 10,
                    spreadRadius: _expanded ? 1 : 0,
                  ),
                ],
              ),
              child: _expanded ? _expandedBody() : _compactBody(),
            ),
          ),
        );
      },
    );
  }

  Widget _compactBody() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _PhaseGlyph(phase: widget.phase, pulse: _pulse, size: 18),
        if (widget.etaLabel != '—')
          Text(
            widget.etaLabel,
            style: AppTextStyles.label.copyWith(
              color: AppColors.ecoGreenLight,
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
      ],
    );
  }

  Widget _expandedBody() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            _PhaseGlyph(phase: widget.phase, pulse: _pulse, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                widget.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.label.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ),
            Text(
              widget.etaLabel,
              style: AppTextStyles.label.copyWith(
                color: AppColors.ecoGreenLight,
                fontWeight: FontWeight.w800,
                fontSize: 13,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _ProgressDots(progress: _progress),
      ],
    );
  }
}

class _PhaseGlyph extends StatelessWidget {
  const _PhaseGlyph({
    required this.phase,
    required this.pulse,
    required this.size,
  });

  final TripVisualPhase phase;
  final Animation<double> pulse;
  final double size;

  @override
  Widget build(BuildContext context) {
    final icon = switch (phase) {
      TripVisualPhase.assigned => Icons.check_circle_rounded,
      TripVisualPhase.arrived => Icons.location_on_rounded,
      TripVisualPhase.enRoute => Icons.turn_right_rounded,
      TripVisualPhase.searching => Icons.sensors_rounded,
    };

    final scale = phase == TripVisualPhase.searching
        ? 1.0 + 0.08 * math.sin(pulse.value * math.pi * 2)
        : 1.0;

    return Transform.scale(
      scale: scale,
      child: Container(
        width: size + 8,
        height: size + 8,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.ecoGreen.withValues(alpha: 0.2),
        ),
        child: Icon(icon, size: size, color: AppColors.ecoGreenLight),
      ),
    );
  }
}

class _ProgressDots extends StatelessWidget {
  const _ProgressDots({required this.progress});

  final int progress;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(3, (index) {
        final active = index <= progress;
        final current = index == progress;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 280),
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: current ? 18 : 8,
          height: 4,
          decoration: BoxDecoration(
            color: active
                ? AppColors.ecoGreenLight
                : Colors.white.withValues(alpha: 0.22),
            borderRadius: BorderRadius.circular(4),
          ),
        );
      }),
    );
  }
}
