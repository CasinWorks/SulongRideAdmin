import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';

class EcoTabSwitcher extends StatelessWidget {
  const EcoTabSwitcher({
    super.key,
    required this.leftLabel,
    required this.rightLabel,
    required this.activeLeft,
    required this.onChanged,
  });

  final String leftLabel;
  final String rightLabel;
  final bool activeLeft;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.forestMedium.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.forestLight.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _Tab(
              label: leftLabel,
              selected: activeLeft,
              onTap: () => onChanged(true),
            ),
          ),
          Expanded(
            child: _Tab(
              label: rightLabel,
              selected: !activeLeft,
              onTap: () => onChanged(false),
            ),
          ),
        ],
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  const _Tab({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppColors.ecoGreen.withValues(alpha: 0.25) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: AppTextStyles.label.copyWith(
            color: selected ? AppColors.ecoGreenLight : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}
