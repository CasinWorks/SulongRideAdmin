import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_decorations.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/constants/trip_rating.dart';
import '../../../core/eco/eco_local_store.dart';
import '../../../models/trip_model.dart';
import '../../../providers/trip_provider.dart';
import '../../components/eco/eco_animations.dart';
import '../../components/primary_button.dart';
import '../../components/trip_rating_panel.dart';

class TripCompletedScreen extends ConsumerWidget {
  const TripCompletedScreen({super.key, required this.tripId});

  final String tripId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tripAsync = ref.watch(tripRealtimeProvider(tripId));

    return tripAsync.when(
      loading: () => Scaffold(
        backgroundColor: AppColors.background,
        body: const Center(child: CircularProgressIndicator(color: AppColors.ecoGreen)),
      ),
      error: (e, _) => Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: Text('Error: $e')),
      ),
      data: (trip) {
        if (trip == null) {
          return Scaffold(
            backgroundColor: AppColors.background,
            body: const Center(child: Text('Trip not found')),
          );
        }
        return _TripCompletedBody(trip: trip);
      },
    );
  }
}

class _TripCompletedBody extends ConsumerStatefulWidget {
  const _TripCompletedBody({required this.trip});

  final TripModel trip;

  @override
  ConsumerState<_TripCompletedBody> createState() => _TripCompletedBodyState();
}

class _TripCompletedBodyState extends ConsumerState<_TripCompletedBody> {
  var _stars = 5;
  final _tags = <String>{};
  final _reviewCtrl = TextEditingController();
  var _submitting = false;
  var _submitted = false;

  List<String> get _activeTags =>
      _stars <= 3 ? tripComplaintTags : tripPositiveTags;

  int get _maxTags => _stars <= 3 ? maxComplaintTagsPerTrip : 5;

  @override
  void dispose() {
    _reviewCtrl.dispose();
    super.dispose();
  }

  Future<void> _submitRating() async {
    if (_submitting || widget.trip.hasRating || _submitted) return;
    setState(() => _submitting = true);
    final complaintTags = _stars <= 3
        ? _tags.where((t) => tripComplaintTags.contains(t)).take(maxComplaintTagsPerTrip).toList()
        : <String>[];
    final positiveNote = _stars >= 4
        ? _tags.where((t) => tripPositiveTags.contains(t)).join(', ')
        : '';
    final reviewText = [
      if (positiveNote.isNotEmpty) positiveNote,
      if (_reviewCtrl.text.trim().isNotEmpty) _reviewCtrl.text.trim(),
    ].join('. ').trim();

    try {
      await ref.read(tripRepositoryProvider).submitTripRating(
            tripId: widget.trip.id,
            rating: _stars,
            reviewText: reviewText.isEmpty ? null : reviewText,
            complaintTags: complaintTags,
          );
      await EcoLocalStore.clearPendingRatingTrip();
      ref.invalidate(rideHistoryProvider);
      ref.invalidate(tripRealtimeProvider(widget.trip.id));
      if (mounted) {
        setState(() => _submitted = true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Salamat! Your feedback was saved.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not save rating: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final trip = widget.trip;
    final alreadyRated = trip.hasRating || _submitted;

    return Scaffold(
      backgroundColor: AppColors.background,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: EcoFadeIn(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.eco_outlined, color: AppColors.ecoGreenLight, size: 48),
                const SizedBox(height: 16),
                Text('Ride complete!', style: AppTextStyles.headingLg),
                const SizedBox(height: 8),
                Text(
                  'Thanks for riding with ${AppStrings.brandName}',
                  style: AppTextStyles.bodySecondary,
                ),
                const SizedBox(height: 24),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: AppDecorations.ecoCard,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Pickup', style: AppTextStyles.label),
                      Text(trip.pickupAddress, style: AppTextStyles.body),
                      const SizedBox(height: 12),
                      Text('Drop-off', style: AppTextStyles.label),
                      Text(trip.dropoffAddress, style: AppTextStyles.body),
                      const SizedBox(height: 12),
                      Text('Fare', style: AppTextStyles.label),
                      Text(
                        formatPeso(trip.fare),
                        style: AppTextStyles.displayMetric.copyWith(fontSize: 24),
                      ),
                    ],
                  ),
                ),
                if (!alreadyRated) ...[
                  const SizedBox(height: 24),
                  TripRatingPanel(
                    title: 'Rate your trip',
                    stars: _stars,
                    tags: _tags,
                    maxTags: _maxTags,
                    reviewCtrl: _reviewCtrl,
                    submitting: _submitting,
                    onStar: (n) => setState(() {
                      _stars = n;
                      _tags.removeWhere((t) => !_activeTags.contains(t));
                    }),
                    onTag: (tag) {
                      setState(() {
                        if (_tags.contains(tag)) {
                          _tags.remove(tag);
                        } else if (_tags.length < _maxTags) {
                          _tags.add(tag);
                        }
                      });
                    },
                    onSubmit: _submitRating,
                    submitLabel: 'Submit rating',
                  ),
                ] else ...[
                  const SizedBox(height: 24),
                  Text(
                    'Thanks for your feedback!',
                    style: AppTextStyles.body.copyWith(color: AppColors.ecoGreenLight),
                  ),
                ],
                const SizedBox(height: 24),
                PrimaryButton(
                  label: alreadyRated ? 'Back to home' : 'Skip for now',
                  useAccent: alreadyRated,
                  onPressed: () => context.go('/home'),
                ),
                if (!alreadyRated) ...[
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () => context.push('/history'),
                    child: const Text('Rate later in trip history'),
                  ),
                ],
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
