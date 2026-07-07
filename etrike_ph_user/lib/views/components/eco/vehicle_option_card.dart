import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_decorations.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/eco/eco_models.dart';

class VehicleOptionCard extends StatelessWidget {
  const VehicleOptionCard({
    super.key,
    required this.option,
    required this.priceLabel,
    required this.selected,
    required this.onTap,
  });

  final EcoVehicleOption option;
  final String priceLabel;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: AppDecorations.ecoCard.copyWith(
          border: Border.all(
            color: selected ? AppColors.ecoGreen : AppColors.forestLight.withValues(alpha: 0.5),
            width: selected ? 1.5 : 1,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: AppColors.ecoGreen.withValues(alpha: 0.15),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            Text(option.icon, style: const TextStyle(fontSize: 28)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(option.name, style: AppTextStyles.headingSm),
                  const SizedBox(height: 2),
                  Text(
                    option.description,
                    style: AppTextStyles.bodySecondary.copyWith(fontSize: 12),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.forestLight.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${option.etaMinutes}m',
                    style: AppTextStyles.mono.copyWith(color: AppColors.ecoGreenLight),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  priceLabel,
                  style: AppTextStyles.headingSm.copyWith(color: AppColors.ecoGreenLight),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
