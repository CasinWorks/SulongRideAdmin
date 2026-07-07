import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/trip_live_activity_service.dart';
import '../../../providers/trip_provider.dart';

class TripCompletedScreen extends ConsumerStatefulWidget {
  const TripCompletedScreen({super.key, required this.tripId});

  final String tripId;

  @override
  ConsumerState<TripCompletedScreen> createState() => _TripCompletedScreenState();
}

class _TripCompletedScreenState extends ConsumerState<TripCompletedScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(DriverTripLiveActivityService.end());
    });
  }

  @override
  Widget build(BuildContext context) {
    final tripAsync = ref.watch(tripRealtimeProvider(widget.tripId));

    return tripAsync.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(
        appBar: AppBar(),
        body: Center(child: Text('Error: $e')),
      ),
      data: (trip) {
        if (trip == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const Center(child: Text('Trip not found')),
          );
        }
        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            title: Text('Trip completed', style: AppTextStyles.headingSm),
            backgroundColor: Colors.transparent,
            elevation: 0,
            foregroundColor: AppColors.textPrimary,
          ),
          body: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Great job!', style: AppTextStyles.headingMd),
                const SizedBox(height: 12),
                Text('Pickup', style: AppTextStyles.label),
                Text(trip.pickupAddress, style: AppTextStyles.body),
                const SizedBox(height: 12),
                Text('Drop-off', style: AppTextStyles.label),
                Text(trip.dropoffAddress, style: AppTextStyles.body),
                const SizedBox(height: 12),
                Text('Fare', style: AppTextStyles.label),
                Text(formatPeso(trip.fare), style: AppTextStyles.headingSm),
                const Spacer(),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => context.go('/home'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text('Back to map'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
