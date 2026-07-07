import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_decorations.dart';
import '../../core/constants/app_text_styles.dart';
import '../../utils/driver_performance_analytics.dart';
import 'driver_ui.dart';

class DriverPerformanceCharts extends StatelessWidget {
  const DriverPerformanceCharts({super.key, required this.snapshot});

  final DriverPerformanceSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final s = snapshot.stats;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Your performance', style: AppTextStyles.headingSm),
          const SizedBox(height: 12),
          Row(
            children: [
              DriverStatCard(
                label: 'Total trips',
                value: '${s.completedTrips}',
                icon: Icons.route_rounded,
              ),
              const SizedBox(width: 10),
              DriverStatCard(
                label: 'Earnings',
                value: s.earningsLabel,
                icon: Icons.payments_outlined,
              ),
              const SizedBox(width: 10),
              DriverStatCard(
                label: 'Rating',
                value: s.ratingLabel,
                icon: Icons.star_rounded,
              ),
            ],
          ),
          const SizedBox(height: 16),
          _ChartCard(
            title: 'Trips — last 7 days',
            child: _BarChart(
              values: snapshot.last7Days.map((d) => d.tripCount.toDouble()).toList(),
              labels: snapshot.last7Days.map((d) => DateFormat.E().format(d.date)).toList(),
              maxY: snapshot.maxTripsPerDay.toDouble(),
              barColor: AppColors.accent,
            ),
          ),
          const SizedBox(height: 12),
          _ChartCard(
            title: 'Earnings — last 7 days',
            child: _BarChart(
              values: snapshot.last7Days.map((d) => d.earnings).toList(),
              labels: snapshot.last7Days.map((d) => DateFormat.E().format(d.date)).toList(),
              maxY: snapshot.maxEarningsPerDay,
              barColor: AppColors.ecoGreenLight,
              formatValue: (v) => '₱${v.toStringAsFixed(0)}',
            ),
          ),
          const SizedBox(height: 12),
          _RatingCard(snapshot: snapshot),
          const SizedBox(height: 8),
          Text(
            'Trip history',
            style: AppTextStyles.label.copyWith(
              color: AppColors.textSecondary,
              letterSpacing: 0.6,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _ChartCard extends StatelessWidget {
  const _ChartCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: AppDecorations.ecoCard,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppTextStyles.label),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _BarChart extends StatelessWidget {
  const _BarChart({
    required this.values,
    required this.labels,
    required this.maxY,
    required this.barColor,
    this.formatValue,
  });

  final List<double> values;
  final List<String> labels;
  final double maxY;
  final Color barColor;
  final String Function(double)? formatValue;

  @override
  Widget build(BuildContext context) {
    const height = 120.0;
    return SizedBox(
      height: height + 28,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(values.length, (i) {
          final v = values[i];
          final fraction = maxY > 0 ? (v / maxY).clamp(0.0, 1.0) : 0.0;
          final barH = (height * fraction).clamp(v > 0 ? 6.0 : 0.0, height);
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (v > 0)
                    Text(
                      formatValue != null ? formatValue!(v) : v.toInt().toString(),
                      style: AppTextStyles.bodySecondary.copyWith(fontSize: 9),
                      textAlign: TextAlign.center,
                    ),
                  const SizedBox(height: 4),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 400),
                    height: barH,
                    decoration: BoxDecoration(
                      color: barColor.withValues(alpha: v > 0 ? 0.9 : 0.2),
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    labels[i],
                    style: AppTextStyles.bodySecondary.copyWith(fontSize: 10),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _RatingCard extends StatelessWidget {
  const _RatingCard({required this.snapshot});

  final DriverPerformanceSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final rating = snapshot.stats.overallRating;
    final monthRating = snapshot.stats.ratingThisMonth;
    final reviews = snapshot.stats.totalReviews;
    final complaints = snapshot.stats.complaintsLast7d;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: AppDecorations.ecoCard.copyWith(
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Passenger ratings', style: AppTextStyles.label),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _RatingRing(rating: rating),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (rating != null) ...[
                      Row(
                        children: List.generate(5, (i) {
                          final starIndex = i + 1;
                          final filled = rating >= starIndex;
                          final half = !filled && rating > i;
                          return Icon(
                            filled
                                ? Icons.star_rounded
                                : half
                                    ? Icons.star_half_rounded
                                    : Icons.star_outline_rounded,
                            color: AppColors.amber,
                            size: 22,
                          );
                        }),
                      ),
                      const SizedBox(height: 6),
                    ],
                    Text(
                      reviews > 0 ? '$reviews rated trips' : 'No ratings yet',
                      style: AppTextStyles.bodySecondary.copyWith(fontSize: 12),
                    ),
                    if (monthRating != null && reviews > 0)
                      Text(
                        'This month: ${monthRating.toStringAsFixed(1)}★',
                        style: AppTextStyles.bodySecondary.copyWith(fontSize: 12),
                      ),
                    if (complaints > 0)
                      Text(
                        '$complaints complaint tags (7 days)',
                        style: AppTextStyles.bodySecondary.copyWith(
                          fontSize: 12,
                          color: AppColors.error,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          if (snapshot.ratedTrips > 0) ...[
            const SizedBox(height: 20),
            ...List.generate(5, (i) {
              final star = 5 - i;
              final count = snapshot.starCounts[star] ?? 0;
              return _StarBar(
                star: star,
                count: count,
                max: snapshot.maxStarCount,
              );
            }),
          ],
          if (snapshot.unratedTrips > 0) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  flex: snapshot.ratedTrips,
                  child: Container(
                    height: 6,
                    decoration: BoxDecoration(
                      color: AppColors.accent,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  flex: snapshot.unratedTrips,
                  child: Container(
                    height: 6,
                    decoration: BoxDecoration(
                      color: AppColors.divider,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '${snapshot.ratedTrips} rated · ${snapshot.unratedTrips} awaiting rating',
              style: AppTextStyles.bodySecondary.copyWith(fontSize: 11),
            ),
          ],
        ],
      ),
    );
  }
}

class _RatingRing extends StatelessWidget {
  const _RatingRing({required this.rating});

  final double? rating;

  @override
  Widget build(BuildContext context) {
    final pct = rating != null ? (rating! / 5).clamp(0.0, 1.0) : 0.0;
    return SizedBox(
      width: 88,
      height: 88,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 88,
            height: 88,
            child: CircularProgressIndicator(
              value: 1,
              strokeWidth: 8,
              color: AppColors.divider,
              backgroundColor: Colors.transparent,
            ),
          ),
          SizedBox(
            width: 88,
            height: 88,
            child: CircularProgressIndicator(
              value: pct,
              strokeWidth: 8,
              color: AppColors.amber,
              backgroundColor: Colors.transparent,
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                rating != null ? rating!.toStringAsFixed(1) : '—',
                style: AppTextStyles.headingSm.copyWith(fontSize: 22),
              ),
              Text(
                'of 5',
                style: AppTextStyles.bodySecondary.copyWith(fontSize: 10),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StarBar extends StatelessWidget {
  const _StarBar({required this.star, required this.count, required this.max});

  final int star;
  final int count;
  final int max;

  @override
  Widget build(BuildContext context) {
    final fraction = max > 0 ? count / max : 0.0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          SizedBox(
            width: 28,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('$star', style: AppTextStyles.bodySecondary.copyWith(fontSize: 11)),
                const Icon(Icons.star_rounded, size: 12, color: AppColors.amber),
              ],
            ),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: fraction,
                minHeight: 8,
                backgroundColor: AppColors.divider,
                color: star <= 2
                    ? AppColors.error
                    : star == 3
                        ? AppColors.amber
                        : AppColors.accent,
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 20,
            child: Text(
              '$count',
              style: AppTextStyles.bodySecondary.copyWith(fontSize: 11),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }
}
