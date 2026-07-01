import 'package:flutter/material.dart';

import '../core/theme/admin_tokens.dart';
import '../models/admin_models.dart';

class AdminStatCard extends StatelessWidget {
  const AdminStatCard({
    super.key,
    required this.label,
    required this.value,
    this.subLabel,
    this.delta,
    this.deltaPositive,
    this.minWidth = 160,
  });

  final String label;
  final String value;
  final String? subLabel;
  final String? delta;
  final bool? deltaPositive;
  final double minWidth;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(minWidth: minWidth),
      padding: const EdgeInsets.all(20),
      decoration: AdminTokens.cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w600),
          ),
          if (subLabel != null) ...[
            const SizedBox(height: 4),
            Text(subLabel!, style: const TextStyle(fontSize: 12, color: AdminTokens.textSecondary)),
          ],
          if (delta != null) ...[
            const SizedBox(height: 4),
            Text(
              delta!,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: deltaPositive == true
                    ? AdminTokens.accent
                    : deltaPositive == false
                        ? AdminTokens.critical
                        : AdminTokens.textSecondary,
              ),
            ),
          ],
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(color: AdminTokens.textSecondary, fontSize: 13)),
        ],
      ),
    );
  }
}

class AdminPanelCard extends StatelessWidget {
  const AdminPanelCard({
    super.key,
    required this.title,
    required this.child,
    this.trailing,
  });

  final String title;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: AdminTokens.cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class FlaggedAlertRow extends StatelessWidget {
  const FlaggedAlertRow({super.key, required this.item});

  final FlaggedItem item;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: item.onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border(left: BorderSide(color: item.borderColor, width: 4)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.title, style: const TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text(item.subtitle, style: const TextStyle(fontSize: 13, color: AdminTokens.textSecondary)),
                  ],
                ),
              ),
              if (item.onTap != null)
                const Icon(Icons.chevron_right, color: AdminTokens.textSecondary, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class StatusPill extends StatelessWidget {
  const StatusPill({super.key, required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color),
      ),
    );
  }
}

class StarRatingDisplay extends StatelessWidget {
  const StarRatingDisplay({
    super.key,
    required this.rating,
    this.size = 16,
    this.showValue = true,
  });

  final double rating;
  final double size;
  final bool showValue;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ...List.generate(5, (i) {
          final filled = rating >= i + 1;
          final half = !filled && rating > i && rating < i + 1;
          return Icon(
            filled
                ? Icons.star_rounded
                : half
                    ? Icons.star_half_rounded
                    : Icons.star_outline_rounded,
            size: size,
            color: const Color(0xFFF59E0B),
          );
        }),
        if (showValue) ...[
          const SizedBox(width: 6),
          Text(
            rating.toStringAsFixed(1),
            style: TextStyle(fontSize: size * 0.85, fontWeight: FontWeight.w600),
          ),
        ],
      ],
    );
  }
}

class DriverAvatar extends StatelessWidget {
  const DriverAvatar({super.key, required this.name, this.radius = 24});

  final String name;
  final double radius;

  String get _initials {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: AdminTokens.accent.withValues(alpha: 0.15),
      foregroundColor: AdminTokens.accent,
      child: Text(_initials, style: TextStyle(fontWeight: FontWeight.w600, fontSize: radius * 0.7)),
    );
  }
}

String reviewStatusLabel(ReviewStatus status) => switch (status) {
      ReviewStatus.critical => 'Critical',
      ReviewStatus.watch => 'Watch',
      ReviewStatus.good => 'Good',
    };

Color reviewStatusColor(ReviewStatus status) => switch (status) {
      ReviewStatus.critical => AdminTokens.critical,
      ReviewStatus.watch => AdminTokens.watch,
      ReviewStatus.good => AdminTokens.accent,
    };

String tripStatusLabel(TripStatus status) => switch (status) {
      TripStatus.completed => 'Completed',
      TripStatus.cancelled => 'Cancelled',
      TripStatus.ongoing => 'Ongoing',
    };

Color tripStatusColor(TripStatus status) => switch (status) {
      TripStatus.completed => AdminTokens.accent,
      TripStatus.cancelled => AdminTokens.critical,
      TripStatus.ongoing => AdminTokens.watch,
    };
