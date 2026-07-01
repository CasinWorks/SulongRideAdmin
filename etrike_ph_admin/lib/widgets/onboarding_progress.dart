import 'package:flutter/material.dart';

import '../core/theme/admin_tokens.dart';
import '../models/onboarding_models.dart';

/// Circular completion ring with percentage label.
class CompletionRing extends StatelessWidget {
  const CompletionRing({
    super.key,
    required this.percent,
    this.size = 72,
    this.strokeWidth = 6,
    this.label,
    this.subLabel,
  });

  final int percent;
  final double size;
  final double strokeWidth;
  final String? label;
  final String? subLabel;

  @override
  Widget build(BuildContext context) {
    final p = percent.clamp(0, 100) / 100.0;
    final color = percent >= 80
        ? AdminTokens.accent
        : percent >= 50
            ? AdminTokens.watch
            : AdminTokens.textSecondary;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: size,
          height: size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CircularProgressIndicator(
                value: 1,
                strokeWidth: strokeWidth,
                color: AdminTokens.border,
                backgroundColor: Colors.transparent,
              ),
              CircularProgressIndicator(
                value: p,
                strokeWidth: strokeWidth,
                color: color,
                backgroundColor: Colors.transparent,
              ),
              Text(
                '$percent%',
                style: TextStyle(
                  fontSize: size * 0.22,
                  fontWeight: FontWeight.w700,
                  color: AdminTokens.textPrimary,
                ),
              ),
            ],
          ),
        ),
        if (label != null) ...[
          const SizedBox(height: 6),
          Text(label!, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        ],
        if (subLabel != null)
          Text(subLabel!, style: const TextStyle(fontSize: 11, color: AdminTokens.textSecondary)),
      ],
    );
  }
}

/// Horizontal segmented progress bar with optional labels.
class SegmentedProgressBar extends StatelessWidget {
  const SegmentedProgressBar({
    super.key,
    required this.percent,
    this.height = 8,
    this.showLabel = true,
  });

  final int percent;
  final double height;
  final bool showLabel;

  @override
  Widget build(BuildContext context) {
    final p = percent.clamp(0, 100) / 100.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showLabel)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(
              'Registration $percent% complete',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
        ClipRRect(
          borderRadius: BorderRadius.circular(height),
          child: LinearProgressIndicator(
            value: p,
            minHeight: height,
            backgroundColor: AdminTokens.border,
            color: AdminTokens.accent,
          ),
        ),
      ],
    );
  }
}

/// Hiring pipeline: Application → Interview → Hiring → Onboarding → Contract → Active
class HiringPipelineBar extends StatelessWidget {
  const HiringPipelineBar({
    super.key,
    required this.currentStage,
    this.onStageTap,
    this.compact = false,
  });

  final HiringStage currentStage;
  final void Function(HiringStage stage)? onStageTap;
  final bool compact;

  static const _stages = [
    HiringStage.application,
    HiringStage.interviewScheduled,
    HiringStage.offerHiring,
    HiringStage.onboarding,
    HiringStage.contractSigning,
    HiringStage.approvedActive,
  ];

  @override
  Widget build(BuildContext context) {
    final currentIdx = _stages.indexWhere((s) => s == currentStage || s.orderIndex >= currentStage.orderIndex);
    final activeIdx = currentIdx < 0 ? 0 : currentIdx;

    return LayoutBuilder(
      builder: (context, constraints) {
        final useIconsOnly = compact || constraints.maxWidth < 520;
        return Row(
          children: [
            for (var i = 0; i < _stages.length; i++) ...[
              Expanded(
                child: _StageNode(
                  stage: _stages[i],
                  state: i < activeIdx
                      ? _NodeState.done
                      : i == activeIdx
                          ? _NodeState.current
                          : _NodeState.upcoming,
                  iconsOnly: useIconsOnly,
                  onTap: onStageTap == null ? null : () => onStageTap!(_stages[i]),
                ),
              ),
              if (i < _stages.length - 1)
                Container(
                  width: 12,
                  height: 2,
                  color: i < activeIdx ? AdminTokens.accent : AdminTokens.border,
                ),
            ],
          ],
        );
      },
    );
  }
}

enum _NodeState { done, current, upcoming }

class _StageNode extends StatelessWidget {
  const _StageNode({
    required this.stage,
    required this.state,
    required this.iconsOnly,
    this.onTap,
  });

  final HiringStage stage;
  final _NodeState state;
  final bool iconsOnly;
  final VoidCallback? onTap;

  IconData get _icon => switch (stage) {
        HiringStage.application => Icons.description_outlined,
        HiringStage.interviewScheduled => Icons.record_voice_over_outlined,
        HiringStage.offerHiring => Icons.handshake_outlined,
        HiringStage.onboarding => Icons.checklist_rtl_outlined,
        HiringStage.contractSigning => Icons.draw_outlined,
        HiringStage.approvedActive => Icons.electric_moped_outlined,
        _ => Icons.circle_outlined,
      };

  @override
  Widget build(BuildContext context) {
    final color = switch (state) {
      _NodeState.done => AdminTokens.accent,
      _NodeState.current => AdminTokens.accent,
      _NodeState.upcoming => AdminTokens.textSecondary,
    };

    final child = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: state == _NodeState.current
                ? AdminTokens.accent.withValues(alpha: 0.15)
                : state == _NodeState.done
                    ? AdminTokens.accent.withValues(alpha: 0.2)
                    : AdminTokens.border.withValues(alpha: 0.5),
            border: Border.all(
              color: color,
              width: state == _NodeState.current ? 2 : 1,
            ),
          ),
          child: Icon(
            state == _NodeState.done ? Icons.check : _icon,
            size: 16,
            color: color,
          ),
        ),
        if (!iconsOnly) ...[
          const SizedBox(height: 4),
          Text(
            stage.label,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 10,
              fontWeight: state == _NodeState.current ? FontWeight.w600 : FontWeight.w400,
              color: color,
            ),
          ),
        ],
      ],
    );

    if (onTap == null) return child;
    return InkWell(onTap: onTap, borderRadius: BorderRadius.circular(8), child: child);
  }
}

/// 7-step wizard step indicator.
class RegistrationStepIndicator extends StatelessWidget {
  const RegistrationStepIndicator({
    super.key,
    required this.currentStep,
    required this.completedSteps,
  });

  final int currentStep;
  final Set<int> completedSteps;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (var i = 1; i <= 7; i++) ...[
            _WizardStepChip(
              step: i,
              label: kRegistrationStepLabels[i - 1],
              isCurrent: i == currentStep,
              isComplete: completedSteps.contains(i),
            ),
            if (i < 7)
              Container(
                width: 24,
                height: 2,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                color: completedSteps.contains(i) ? AdminTokens.accent : AdminTokens.border,
              ),
          ],
        ],
      ),
    );
  }
}

class _WizardStepChip extends StatelessWidget {
  const _WizardStepChip({
    required this.step,
    required this.label,
    required this.isCurrent,
    required this.isComplete,
  });

  final int step;
  final String label;
  final bool isCurrent;
  final bool isComplete;

  @override
  Widget build(BuildContext context) {
    final bg = isCurrent
        ? AdminTokens.accent.withValues(alpha: 0.12)
        : isComplete
            ? AdminTokens.accent.withValues(alpha: 0.08)
            : AdminTokens.border.withValues(alpha: 0.3);
    final fg = isCurrent || isComplete ? AdminTokens.accent : AdminTokens.textSecondary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isCurrent ? AdminTokens.accent : Colors.transparent,
          width: 1.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 10,
            backgroundColor: isComplete ? AdminTokens.accent : Colors.transparent,
            child: isComplete
                ? const Icon(Icons.check, size: 12, color: Colors.white)
                : Text('$step', style: TextStyle(fontSize: 10, color: fg, fontWeight: FontWeight.w600)),
          ),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(fontSize: 12, fontWeight: isCurrent ? FontWeight.w600 : FontWeight.w400, color: fg)),
        ],
      ),
    );
  }
}

/// Dual progress header for registration screen.
class OnboardingProgressHeader extends StatelessWidget {
  const OnboardingProgressHeader({
    super.key,
    required this.pipeline,
    required this.checklistPercent,
    this.onSendReminder,
    this.onSetDeadline,
  });

  final HiringPipelineState pipeline;
  final int checklistPercent;
  final VoidCallback? onSendReminder;
  final VoidCallback? onSetDeadline;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: AdminTokens.cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CompletionRing(
                percent: pipeline.effectivePipelinePercent,
                label: 'Hiring pipeline',
                subLabel: pipeline.stage.label,
              ),
              const SizedBox(width: 24),
              CompletionRing(
                percent: checklistPercent,
                label: 'Document checklist',
                subLabel: 'Company e-trike driver',
              ),
              const Spacer(),
              if (onSetDeadline != null || onSendReminder != null)
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (onSetDeadline != null)
                      OutlinedButton.icon(
                        onPressed: onSetDeadline,
                        icon: const Icon(Icons.event_outlined, size: 18),
                        label: const Text('Set deadline'),
                      ),
                    if (onSendReminder != null)
                      FilledButton.tonal(
                        onPressed: onSendReminder,
                        child: const Text('Send reminder'),
                      ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 20),
          HiringPipelineBar(currentStage: pipeline.stage),
          const SizedBox(height: 16),
          SegmentedProgressBar(percent: checklistPercent),
        ],
      ),
    );
  }
}
