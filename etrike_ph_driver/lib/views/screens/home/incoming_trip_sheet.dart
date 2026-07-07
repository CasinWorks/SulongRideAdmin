import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../models/trip_model.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/driver_eligibility_provider.dart';
import '../../../providers/onboarding_provider.dart';
import '../../../providers/training_provider.dart';
import '../../../providers/trip_provider.dart';
import '../../components/primary_button.dart';

Future<bool?> showIncomingTripSheet({
  required BuildContext context,
  required TripModel trip,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (sheetContext) => _IncomingTripSheetBody(trip: trip),
  );
}

class _IncomingTripSheetBody extends ConsumerStatefulWidget {
  const _IncomingTripSheetBody({required this.trip});

  final TripModel trip;

  @override
  ConsumerState<_IncomingTripSheetBody> createState() => _IncomingTripSheetBodyState();
}

class _IncomingTripSheetBodyState extends ConsumerState<_IncomingTripSheetBody> {
  final ValueNotifier<bool> _busy = ValueNotifier<bool>(false);

  @override
  void dispose() {
    _busy.dispose();
    super.dispose();
  }

  Future<void> _accept() async {
    final uid = ref.read(supabaseClientProvider).auth.currentUser?.id;
    if (uid == null) return;
    _busy.value = true;
    try {
      final eligibility = await fetchDriverTripEligibility(
        authRepo: ref.read(authRepositoryProvider),
        trainingRepo: ref.read(trainingRepositoryProvider),
        onboardingRepo: ref.read(onboardingRepositoryProvider),
        driverId: uid,
      );
      if (!eligibility.canReceiveTrips) {
        _busy.value = false;
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                eligibility.primaryBlockReason ??
                    'Complete onboarding requirements before accepting trips.',
              ),
            ),
          );
          Navigator.of(context).pop(false);
        }
        return;
      }

      await ref.read(tripRepositoryProvider).acceptTrip(
            tripId: widget.trip.id,
            driverId: uid,
          );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      _busy.value = false;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: _busy,
      builder: (context, busy, _) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.divider,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text('New trip request', style: AppTextStyles.headingSm),
              const SizedBox(height: 12),
              Text('Pickup', style: AppTextStyles.label),
              Text(widget.trip.pickupAddress, style: AppTextStyles.body),
              const SizedBox(height: 8),
              Text('Drop-off', style: AppTextStyles.label),
              Text(widget.trip.dropoffAddress, style: AppTextStyles.body),
              const SizedBox(height: 8),
              Text('Fare', style: AppTextStyles.label),
              Text(
                formatPeso(widget.trip.fare),
                style: AppTextStyles.headingSm.copyWith(color: AppColors.accent),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: PrimaryButton(
                      label: 'Decline',
                      useAccent: false,
                      onPressed: busy ? null : () => Navigator.of(context).pop(false),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: PrimaryButton(
                      label: 'Accept',
                      isLoading: busy,
                      onPressed: busy ? null : () {
                        _accept();
                      },
                    ),
                  ),
                ],
              ),
              SizedBox(height: MediaQuery.paddingOf(context).bottom + 8),
            ],
          ),
        );
      },
    );
  }
}
