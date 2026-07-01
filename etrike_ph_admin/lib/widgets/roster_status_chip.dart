import 'package:flutter/material.dart';

import '../core/theme/admin_tokens.dart';
import '../models/roster_models.dart';

Color rosterStatusColor(DriverDayStatus status) => switch (status) {
      DriverDayStatus.onShift => AdminTokens.accent,
      DriverDayStatus.online => const Color(0xFF2563EB),
      DriverDayStatus.offDuty => const Color(0xFF9CA3AF),
      DriverDayStatus.onLeaveVl => AdminTokens.watch,
      DriverDayStatus.onLeaveSl => const Color(0xFFEA580C),
      DriverDayStatus.pending => AdminTokens.watch,
      DriverDayStatus.revoked => AdminTokens.critical,
    };

class RosterStatusChip extends StatelessWidget {
  const RosterStatusChip({super.key, required this.status, this.compact = false});

  final DriverDayStatus status;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final color = rosterStatusColor(status);
    final label = switch (status) {
      DriverDayStatus.onLeaveVl => 'VL',
      DriverDayStatus.onLeaveSl => 'SL',
      DriverDayStatus.onShift => 'On shift',
      DriverDayStatus.online => 'Online',
      DriverDayStatus.offDuty => 'Off duty',
      DriverDayStatus.pending => 'Pending',
      DriverDayStatus.revoked => 'Revoked',
    };
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
        vertical: compact ? 3 : 4,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: compact ? 11 : 12,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

class OnlineDot extends StatelessWidget {
  const OnlineDot({super.key, required this.online});

  final bool online;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: online ? AdminTokens.accent : const Color(0xFFD1D5DB),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          online ? 'Online' : 'Offline',
          style: TextStyle(
            fontSize: 12,
            color: online ? AdminTokens.accent : AdminTokens.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
