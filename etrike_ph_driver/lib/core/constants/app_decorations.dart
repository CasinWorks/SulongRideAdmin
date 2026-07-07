import 'package:flutter/material.dart';

import 'app_colors.dart';

abstract final class AppDecorations {
  static const BorderRadius drawerTop = BorderRadius.vertical(top: Radius.circular(32));

  static BoxDecoration ecoDrawer({double opacity = 0.95}) => BoxDecoration(
        color: AppColors.forestDark.withValues(alpha: opacity),
        borderRadius: drawerTop,
        boxShadow: const [
          BoxShadow(
            color: AppColors.drawerShadow,
            blurRadius: 30,
            offset: Offset(0, -15),
          ),
        ],
      );

  static BoxDecoration ecoCard = BoxDecoration(
    color: AppColors.forestMedium,
    borderRadius: BorderRadius.circular(16),
    border: Border.all(color: AppColors.forestLight.withValues(alpha: 0.6)),
  );

  static BoxDecoration ecoInput = BoxDecoration(
    color: AppColors.forestMedium,
    borderRadius: BorderRadius.circular(14),
    border: Border.all(color: AppColors.forestLight.withValues(alpha: 0.5)),
  );

  static BoxDecoration floatingControl = BoxDecoration(
    color: AppColors.forestMedium.withValues(alpha: 0.92),
    borderRadius: BorderRadius.circular(12),
    boxShadow: const [
      BoxShadow(color: Color(0x33000000), blurRadius: 12, offset: Offset(0, 4)),
    ],
  );
}
