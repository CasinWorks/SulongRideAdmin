import 'package:flutter/material.dart';

import '../core/theme/admin_tokens.dart';
import '../models/onboarding_models.dart';

class DocumentStatusBadge extends StatelessWidget {
  const DocumentStatusBadge({super.key, required this.status});

  final DocumentStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, color, outlined) = switch (status) {
      DocumentStatus.verified => ('Verified', AdminTokens.accent, false),
      DocumentStatus.pending => ('Pending review', AdminTokens.pendingBorder, false),
      DocumentStatus.expiringSoon => ('Expiring soon', AdminTokens.watch, false),
      DocumentStatus.expired => ('Expired', AdminTokens.critical, false),
      DocumentStatus.rejected => ('Rejected', AdminTokens.critical, true),
      DocumentStatus.notRequired => ('Not required', AdminTokens.textSecondary, false),
      DocumentStatus.doesNotExpire => ('Does not expire', AdminTokens.textSecondary, false),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: outlined ? Colors.transparent : color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: outlined ? 0.8 : 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (status == DocumentStatus.doesNotExpire) ...[
            Icon(Icons.lock_outline, size: 12, color: color),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color),
          ),
        ],
      ),
    );
  }
}
