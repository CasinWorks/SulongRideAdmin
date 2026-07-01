import 'package:flutter/material.dart';

/// Shared visual tokens — keep in sync with [ThemeData] in main.dart.
abstract final class AdminTokens {
  static const background = Color(0xFFF5F7F5);
  static const accent = Color(0xFF2E7D32);
  static const card = Colors.white;
  static const textPrimary = Color(0xDE000000);
  static const textSecondary = Color(0x8A000000);
  static const critical = Color(0xFFEF4444);
  static const watch = Color(0xFFF59E0B);
  static const complaintBar = Color(0xFFE57E4A);
  static const pendingBorder = Color(0xFFF59E0B);
  static const attentionBorder = Color(0xFFEF4444);
  static const border = Color(0xFFE2E8E2);

  static const cardRadius = 16.0;

  static BoxDecoration cardDecoration = BoxDecoration(
    color: card,
    borderRadius: BorderRadius.circular(cardRadius),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.04),
        blurRadius: 12,
        offset: const Offset(0, 4),
      ),
    ],
  );
}
