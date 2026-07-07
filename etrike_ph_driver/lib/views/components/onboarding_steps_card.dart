import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_decorations.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/onboarding_step_utils.dart';
import '../../models/onboarding_models.dart';

/// Tappable onboarding steps — jump to any wizard step to edit or re-upload.
class OnboardingStepsCard extends StatelessWidget {
  const OnboardingStepsCard({
    super.key,
    required this.bundle,
    required this.onStepTap,
    this.trainingComplete = false,
  });

  final OnboardingBundle bundle;
  final void Function(int step) onStepTap;
  final bool trainingComplete;

  @override
  Widget build(BuildContext context) {
    final steps = buildOnboardingStepSummaries(
      bundle: bundle,
      trainingComplete: trainingComplete,
    );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppDecorations.ecoCard,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Application steps', style: AppTextStyles.headingSm.copyWith(fontSize: 16)),
          const SizedBox(height: 4),
          Text(
            'Tap a step to review, edit details, replace uploads, or remove files.',
            style: AppTextStyles.bodySecondary.copyWith(height: 1.35),
          ),
          const SizedBox(height: 12),
          ...steps.map((step) => _StepTile(summary: step, onTap: () => onStepTap(step.step))),
        ],
      ),
    );
  }
}

class _StepTile extends StatelessWidget {
  const _StepTile({required this.summary, required this.onTap});

  final OnboardingStepSummary summary;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final (icon, color) = switch (summary.status) {
      OnboardingStepStatus.complete => (Icons.check_circle_outline, AppColors.accent),
      OnboardingStepStatus.inProgress => (Icons.pending_outlined, AppColors.amber),
      OnboardingStepStatus.needsAttention => (Icons.error_outline, AppColors.error),
      OnboardingStepStatus.notStarted => (Icons.radio_button_unchecked, AppColors.textSecondary),
    };

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: AppColors.forestMedium.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Row(
              children: [
                Icon(icon, color: color, size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${summary.step}. ${summary.label}',
                        style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600),
                      ),
                      if (summary.subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(summary.subtitle!, style: AppTextStyles.bodySecondary.copyWith(fontSize: 12)),
                      ],
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: AppColors.textSecondary.withValues(alpha: 0.8)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
