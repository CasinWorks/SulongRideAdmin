import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../models/app_maintenance.dart';

class MaintenanceScreen extends StatelessWidget {
  const MaintenanceScreen({super.key, required this.status});

  final AppMaintenanceStatus status;

  String _windowLabel() {
    final fmt = DateFormat('MMM d, h:mm a');
    final start = status.startsAt;
    final end = status.endsAt;
    if (start == null || end == null) return '';
    return '${fmt.format(start)} – ${fmt.format(end)}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              Icon(Icons.engineering_outlined, size: 56, color: AppColors.accent),
              const SizedBox(height: 20),
              Text(
                status.title ?? 'Maintenance in progress',
                style: AppTextStyles.headingMd,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                status.message ??
                    'Sulong Ride is temporarily unavailable. Please try again later.',
                style: AppTextStyles.bodySecondary,
                textAlign: TextAlign.center,
              ),
              if (_windowLabel().isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  _windowLabel(),
                  style: AppTextStyles.label.copyWith(color: AppColors.accent),
                  textAlign: TextAlign.center,
                ),
              ],
              const Spacer(),
              Text(
                'This screen will disappear automatically when maintenance ends.',
                style: AppTextStyles.bodySecondary.copyWith(fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class MaintenanceBanner extends StatelessWidget {
  const MaintenanceBanner({super.key, required this.status});

  final AppMaintenanceStatus status;

  @override
  Widget build(BuildContext context) {
    if (!status.shouldNotify || status.phase != AppMaintenancePhase.scheduled) {
      return const SizedBox.shrink();
    }
    final start = status.startsAt;
    final label = start != null
        ? DateFormat('MMM d, h:mm a').format(start)
        : 'soon';
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.45)),
      ),
      child: Text(
        '${status.title ?? 'Scheduled maintenance'} starts $label.',
        style: AppTextStyles.bodySecondary,
      ),
    );
  }
}
