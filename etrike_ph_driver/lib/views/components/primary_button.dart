import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';

class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.useAccent = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final bool useAccent;

  @override
  Widget build(BuildContext context) {
    final bg = useAccent ? AppColors.ecoGreen : AppColors.forestLight;
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: bg,
          foregroundColor: AppColors.ecoCream,
          disabledBackgroundColor: AppColors.forestLight.withValues(alpha: 0.5),
          elevation: useAccent ? 4 : 0,
          shadowColor: AppColors.ecoGreen.withValues(alpha: 0.2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        onPressed: isLoading ? null : onPressed,
        child: isLoading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.ecoCream,
                ),
              )
            : Text(label, style: AppTextStyles.button),
      ),
    );
  }
}
