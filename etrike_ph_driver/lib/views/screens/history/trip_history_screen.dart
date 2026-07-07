import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../models/driver_stats.dart';
import '../../../models/trip_model.dart';
import '../../../providers/hr_provider.dart';
import '../../../providers/trip_provider.dart';
import '../../../utils/driver_performance_analytics.dart';
import '../../components/driver_performance_charts.dart';

class TripHistoryScreen extends ConsumerWidget {
  const TripHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(driverTripHistoryProvider);
    final statsAsync = ref.watch(driverStatsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Stats & history', style: AppTextStyles.headingSm),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () {
              ref.invalidate(driverTripHistoryProvider);
              ref.invalidate(driverStatsProvider);
            },
          ),
        ],
      ),
      body: historyAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Could not load history', style: AppTextStyles.headingSm),
                const SizedBox(height: 8),
                Text('$e', textAlign: TextAlign.center),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: () {
                    ref.invalidate(driverTripHistoryProvider);
                    ref.invalidate(driverStatsProvider);
                  },
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
        data: (trips) {
          final stats = statsAsync.maybeWhen(
            data: (s) => s,
            orElse: () => DriverStats(
              completedTrips: trips.length,
              totalEarnings: trips.fold<double>(0, (sum, t) => sum + t.fare),
              attendanceDays: 0,
              openShift: false,
            ),
          );
          final snapshot = buildPerformanceSnapshot(stats: stats, trips: trips);

          if (trips.isEmpty) {
            return ListView(
              children: [
                DriverPerformanceCharts(snapshot: snapshot),
                Padding(
                  padding: const EdgeInsets.all(32),
                  child: Center(
                    child: Text(
                      'No completed trips yet.\nYour charts will fill in after your first ride.',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.bodySecondary,
                    ),
                  ),
                ),
              ],
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.only(bottom: 24),
            itemCount: trips.length + 1,
            separatorBuilder: (context, index) {
              if (index == 0) return const SizedBox.shrink();
              return const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: SizedBox(height: 12),
              );
            },
            itemBuilder: (context, index) {
              if (index == 0) {
                return DriverPerformanceCharts(snapshot: snapshot);
              }
              final trip = trips[index - 1];
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _HistoryCard(trip: trip),
              );
            },
          );
        },
      ),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  const _HistoryCard({required this.trip});

  final TripModel trip;

  @override
  Widget build(BuildContext context) {
    final date = DateFormat.yMMMd().add_jm().format(trip.createdAt.toLocal());
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(color: Color(0x33000000), blurRadius: 10, offset: Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(date, style: AppTextStyles.label),
          const SizedBox(height: 8),
          Text('Pickup', style: AppTextStyles.label),
          Text(trip.pickupAddress, style: AppTextStyles.body),
          const SizedBox(height: 8),
          Text('Drop-off', style: AppTextStyles.label),
          Text(trip.dropoffAddress, style: AppTextStyles.body),
          const SizedBox(height: 8),
          Text(formatPeso(trip.fare), style: AppTextStyles.headingSm.copyWith(color: AppColors.accent)),
          if (trip.hasRating) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.star, color: AppColors.ecoGreenLight, size: 16),
                const SizedBox(width: 4),
                Text(
                  '${trip.rating}★ passenger rating',
                  style: AppTextStyles.bodySecondary,
                ),
              ],
            ),
            if (trip.reviewText != null && trip.reviewText!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '"${trip.reviewText}"',
                  style: AppTextStyles.bodySecondary.copyWith(fontSize: 12),
                ),
              ),
            if (trip.complaintTags.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Wrap(
                  spacing: 4,
                  children: trip.complaintTags
                      .map((t) => Chip(
                            label: Text(t, style: const TextStyle(fontSize: 10)),
                            visualDensity: VisualDensity.compact,
                          ))
                      .toList(),
                ),
              ),
          ],
        ],
      ),
    );
  }
}
