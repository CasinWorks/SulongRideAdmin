import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';

class EcoDrawerHandle extends StatelessWidget {
  const EcoDrawerHandle({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 48,
        height: 4,
        margin: const EdgeInsets.only(top: 10, bottom: 12),
        decoration: BoxDecoration(
          color: AppColors.forestLight,
          borderRadius: BorderRadius.circular(99),
        ),
      ),
    );
  }
}
