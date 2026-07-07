import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_decorations.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/constants/trip_rating.dart';
import '../../../core/eco/eco_local_store.dart';
import '../../../models/trip_model.dart';
import '../../../providers/trip_provider.dart';
import '../../components/eco/eco_animations.dart';
import '../../components/trip_rating_panel.dart';

class RideHistoryScreen extends ConsumerStatefulWidget {
  const RideHistoryScreen({super.key});

  @override
  ConsumerState<RideHistoryScreen> createState() => _RideHistoryScreenState();
}

class _RideHistoryScreenState extends ConsumerState<RideHistoryScreen> {
  String? _expandedId;
  String? _ratingTripId;
  var _submitting = false;
  int _stars = 5;
  final _reviewCtrl = TextEditingController();
  final Set<String> _tags = {};
  Map<String, EcoTripRating> _legacyRatings = {};

  List<String> get _activeTags =>
      _stars <= 3 ? tripComplaintTags : tripPositiveTags;

  int get _maxTags => _stars <= 3 ? maxComplaintTagsPerTrip : 5;

  @override
  void initState() {
    super.initState();
    _loadRatings();
  }

  Future<void> _loadRatings() async {
    final pending = await EcoLocalStore.pendingRatingTripId();
    final legacy = await EcoLocalStore.tripRatings();
    if (!mounted) return;
    setState(() {
      _legacyRatings = legacy;
      if (pending != null) {
        _ratingTripId = pending;
        _expandedId = pending;
      }
    });
  }

  @override
  void dispose() {
    _reviewCtrl.dispose();
    super.dispose();
  }

  void _resetRatingForm() {
    _stars = 5;
    _tags.clear();
    _reviewCtrl.clear();
  }

  void _openRatingFor(TripModel trip) {
    setState(() {
      _ratingTripId = trip.id;
      _expandedId = trip.id;
      _resetRatingForm();
    });
  }

  void _cancelRating() {
    setState(() {
      _ratingTripId = null;
      _resetRatingForm();
    });
  }

  Future<void> _submitRating(String tripId) async {
    if (_submitting) return;
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

    final wasPending = (await EcoLocalStore.pendingRatingTripId()) == tripId;

    try {
      await ref.read(tripRepositoryProvider).submitTripRating(
            tripId: tripId,
            rating: _stars,
            reviewText: reviewText.isEmpty ? null : reviewText,
            complaintTags: complaintTags,
          );
      await EcoLocalStore.clearPendingRatingTrip();
      ref.invalidate(rideHistoryProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not save rating: $e')),
        );
      }
      return;
    } finally {
      if (mounted) setState(() => _submitting = false);
    }

    if (!mounted) return;
    setState(() {
      _ratingTripId = null;
      _resetRatingForm();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Salamat! Your feedback was saved.')),
    );
    if (wasPending) {
      context.go('/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    final historyAsync = ref.watch(rideHistoryProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('TRIP LOGS & RECEIPTS', style: AppTextStyles.label),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
      ),
      body: historyAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.ecoGreen)),
        error: (e, _) => Center(child: Text('$e', style: AppTextStyles.body)),
        data: (trips) {
          if (_ratingTripId != null) {
            final rated = trips.cast<TripModel?>().firstWhere(
                  (t) => t?.id == _ratingTripId,
                  orElse: () => null,
                );
            if (rated?.hasRating == true) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                EcoLocalStore.clearPendingRatingTrip();
                if (mounted) setState(() => _ratingTripId = null);
              });
            }
          }

          if (trips.isEmpty) {
            return Center(
              child: Text('No completed rides yet.', style: AppTextStyles.bodySecondary),
            );
          }

          final ratingTrip = _ratingTripId == null
              ? null
              : trips.cast<TripModel?>().firstWhere(
                    (t) => t?.id == _ratingTripId,
                    orElse: () => null,
                  );

          return EcoFadeIn(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                if (ratingTrip != null && !ratingTrip.hasRating) ...[
                  TripRatingPanel(
                    title: 'Rate your driver',
                    stars: _stars,
                    tags: _tags,
                    maxTags: _maxTags,
                    reviewCtrl: _reviewCtrl,
                    submitting: _submitting,
                    onStar: (s) => setState(() {
                      _stars = s;
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
                    onSubmit: () => _submitRating(ratingTrip.id),
                    secondaryLabel: 'Cancel',
                    secondaryAction: _cancelRating,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Trip to ${ratingTrip.dropoffAddress.split(',').first}',
                    style: AppTextStyles.bodySecondary.copyWith(fontSize: 11),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                ],
                Text('COMPLETED TRIPS', style: AppTextStyles.label.copyWith(fontSize: 10)),
                const SizedBox(height: 10),
                ...trips.map(
                  (trip) => _TripReceiptCard(
                    trip: trip,
                    expanded: _expandedId == trip.id,
                    legacyRating: _legacyRatings[trip.id],
                    isRating: _ratingTripId == trip.id,
                    onToggle: () => setState(() {
                      _expandedId = _expandedId == trip.id ? null : trip.id;
                    }),
                    onRateDriver: trip.hasRating || _legacyRatings.containsKey(trip.id)
                        ? null
                        : () => _openRatingFor(trip),
                    onBookAgain: () {
                      context.go('/home');
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Search for: ${trip.dropoffAddress}')),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _TripReceiptCard extends StatelessWidget {
  const _TripReceiptCard({
    required this.trip,
    required this.expanded,
    required this.onToggle,
    required this.onBookAgain,
    this.legacyRating,
    this.isRating = false,
    this.onRateDriver,
  });

  final TripModel trip;
  final bool expanded;
  final bool isRating;
  final VoidCallback onToggle;
  final VoidCallback onBookAgain;
  final VoidCallback? onRateDriver;
  final EcoTripRating? legacyRating;

  int? get _displayRating => trip.rating ?? legacyRating?.rating;
  String? get _displayReview => trip.reviewText ?? legacyRating?.review;
  List<String> get _displayTags => trip.complaintTags;
  bool get _hasRating => _displayRating != null;

  @override
  Widget build(BuildContext context) {
    final date = DateFormat.yMMMd().add_jm().format(trip.createdAt.toLocal());
    final mileage = (trip.fare - 15).clamp(0, double.infinity);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: AppDecorations.ecoCard.copyWith(
        border: isRating
            ? Border.all(color: AppColors.ecoGreen.withValues(alpha: 0.5))
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('🛺', style: TextStyle(fontSize: 24)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Trip to ${trip.dropoffAddress.split(',').first}',
                      style: AppTextStyles.headingSm,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(date, style: AppTextStyles.bodySecondary.copyWith(fontSize: 10)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(formatPeso(trip.fare), style: AppTextStyles.headingSm),
                  if (_hasRating)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: List.generate(
                          5,
                          (i) => Icon(
                            Icons.star,
                            size: 12,
                            color: i < _displayRating!
                                ? AppColors.amber
                                : AppColors.forestLight,
                          ),
                        ),
                      ),
                    )
                  else
                    Container(
                      margin: const EdgeInsets.only(top: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.amber.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Text(
                        'NOT RATED',
                        style: AppTextStyles.mono.copyWith(
                          color: AppColors.amber,
                          fontSize: 8,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              if (onRateDriver != null)
                TextButton.icon(
                  onPressed: onRateDriver,
                  icon: const Icon(Icons.star_outline, size: 16),
                  label: const Text('Rate driver'),
                ),
              const Spacer(),
              TextButton(
                onPressed: onBookAgain,
                child: Text(
                  'Book again',
                  style: AppTextStyles.label.copyWith(color: AppColors.ecoGreenLight),
                ),
              ),
              TextButton(
                onPressed: onToggle,
                child: Text(
                  expanded ? 'Hide' : 'Receipt',
                  style: AppTextStyles.label,
                ),
              ),
            ],
          ),
          if (expanded) ...[
            const SizedBox(height: 8),
            EcoSlideUp(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.forestDark.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _addrRow('Pickup', trip.pickupAddress, AppColors.pickupPin),
                    const SizedBox(height: 6),
                    _addrRow('Drop-off', trip.dropoffAddress, AppColors.amber),
                    const Divider(color: AppColors.forestLight, height: 20),
                    _receiptLine('EcoRide base booking fee', '₱15.00'),
                    _receiptLine('Electric mileage', '₱${mileage.toStringAsFixed(2)}'),
                    _receiptLine('Total charged', formatPeso(trip.fare), bold: true),
                    if (_hasRating) ...[
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          const Icon(Icons.star, color: AppColors.amber, size: 16),
                          const SizedBox(width: 6),
                          Text(
                            '$_displayRating★',
                            style: AppTextStyles.mono.copyWith(color: AppColors.amber),
                          ),
                        ],
                      ),
                      if (_displayReview != null && _displayReview!.isNotEmpty)
                        Text(
                          '"$_displayReview"',
                          style: AppTextStyles.bodySecondary.copyWith(fontSize: 10),
                        ),
                      if (_displayTags.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Wrap(
                            spacing: 4,
                            children: _displayTags
                                .map(
                                  (t) => Chip(
                                    label: Text(t, style: const TextStyle(fontSize: 9)),
                                    visualDensity: VisualDensity.compact,
                                  ),
                                )
                                .toList(),
                          ),
                        ),
                    ] else if (onRateDriver != null) ...[
                      const SizedBox(height: 10),
                      Text(
                        'You have not rated this driver yet.',
                        style: AppTextStyles.bodySecondary.copyWith(fontSize: 11),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _addrRow(String label, String value, Color dot) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 8,
          height: 8,
          margin: const EdgeInsets.only(top: 4, right: 8),
          decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
        ),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: AppTextStyles.bodySecondary.copyWith(fontSize: 11),
              children: [
                TextSpan(
                  text: '$label: ',
                  style: const TextStyle(
                    color: AppColors.ecoCream,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                TextSpan(text: value),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _receiptLine(String label, String value, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: AppTextStyles.bodySecondary.copyWith(
                fontSize: 11,
                fontWeight: bold ? FontWeight.w800 : FontWeight.w400,
                color: bold ? AppColors.ecoCream : AppColors.textSecondary,
              ),
            ),
          ),
          Text(
            value,
            style: AppTextStyles.body.copyWith(
              fontSize: 11,
              fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
