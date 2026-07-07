import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_decorations.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/external_navigation.dart';
import '../../../../core/trip_live_activity_service.dart';
import '../../../../models/message_model.dart';
import '../../../../models/trip_model.dart';
import '../../../../providers/trip_provider.dart';
import '../../../components/primary_button.dart';
import '../../../components/slide_to_confirm.dart';
import 'trip_dynamic_island_bar.dart';
import 'trip_status_animations.dart';

class DriverTripOverlay extends ConsumerStatefulWidget {
  const DriverTripOverlay({
    super.key,
    required this.trip,
  });

  final TripModel trip;

  @override
  ConsumerState<DriverTripOverlay> createState() => _DriverTripOverlayState();
}

class _DriverTripOverlayState extends ConsumerState<DriverTripOverlay> {
  bool _actionBusy = false;
  String? _pendingTargetStatus;
  Completer<void>? _statusWaitCompleter;
  _CashPaymentPhase _cashPhase = _CashPaymentPhase.idle;

  @override
  void didUpdateWidget(covariant DriverTripOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.trip.id != widget.trip.id) {
      _cashPhase = _CashPaymentPhase.idle;
    }
    if (oldWidget.trip.status != widget.trip.status) {
      if (widget.trip.status != 'ongoing') {
        _cashPhase = _CashPaymentPhase.idle;
      }
      _resolvePendingStatusWait();
      _syncLive();
    }
  }

  void _resolvePendingStatusWait() {
    final target = _pendingTargetStatus;
    if (target == null || widget.trip.status != target) return;
    final completer = _statusWaitCompleter;
    if (completer != null && !completer.isCompleted) {
      completer.complete();
    }
  }

  void _syncLive() {
    unawaited(DriverTripLiveActivityService.syncFromTrip(widget.trip));
  }

  Future<void> _waitForTripStatus(String expected) async {
    if (widget.trip.status == expected) return;

    final completer = Completer<void>();
    _statusWaitCompleter = completer;
    _pendingTargetStatus = expected;

    try {
      await completer.future.timeout(const Duration(seconds: 15));
      return;
    } on TimeoutException {
      // Fall through to poll Supabase once more.
    } finally {
      if (_statusWaitCompleter == completer) {
        _statusWaitCompleter = null;
        _pendingTargetStatus = null;
      }
    }

    final fetched =
        await ref.read(tripRepositoryProvider).fetchTrip(widget.trip.id);
    if (fetched?.status != expected) {
      throw StateError('Trip update not confirmed yet. Please wait and try again.');
    }
  }

  Future<void> _markArrivedAtPickup() async {
    if (_actionBusy) return;
    HapticFeedback.lightImpact();
    setState(() => _actionBusy = true);
    try {
      await ref.read(tripRepositoryProvider).updateTripStatus(
            tripId: widget.trip.id,
            status: 'ongoing',
          );
      await _waitForTripStatus('ongoing');
      if (mounted) _syncLive();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e')),
      );
    } finally {
      if (mounted) setState(() => _actionBusy = false);
    }
  }

  Future<void> _confirmPaymentAndComplete() async {
    if (_actionBusy) return;
    HapticFeedback.lightImpact();
    setState(() => _actionBusy = true);
    try {
      await ref.read(tripRepositoryProvider).confirmCashPayment(widget.trip.id);
      await ref.read(tripRepositoryProvider).completeTrip(widget.trip.id);
      await _waitForTripStatus('completed');
      unawaited(DriverTripLiveActivityService.end());
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e')),
      );
      setState(() => _cashPhase = _CashPaymentPhase.slideConfirm);
    } finally {
      if (mounted) setState(() => _actionBusy = false);
    }
  }

  _StatusCopy _statusCopy() {
    switch (widget.trip.status) {
      case 'accepted':
        return _StatusCopy(
          title: 'Head to pickup',
          subtitle: widget.trip.pickupAddress,
          phase: TripVisualPhase.assigned,
        );
      case 'ongoing':
        if (_cashPhase != _CashPaymentPhase.idle) {
          return _StatusCopy(
            title: 'Collect cash payment',
            subtitle: 'Confirm fare before completing trip',
            phase: TripVisualPhase.enRoute,
          );
        }
        return _StatusCopy(
          title: 'Passenger on board',
          subtitle: 'Drop-off: ${widget.trip.dropoffAddress}',
          phase: TripVisualPhase.enRoute,
        );
      default:
        return _StatusCopy(
          title: 'Trip active',
          subtitle: widget.trip.pickupAddress,
          phase: TripVisualPhase.searching,
        );
    }
  }

  String _etaLabel() {
    if (widget.trip.status == 'ongoing') {
      return '~${(widget.trip.distanceKm ?? 2).ceil()} min';
    }
    if (widget.trip.status == 'accepted') return '3 min';
    return '—';
  }

  int _progressIndex() => switch (widget.trip.status) {
        'accepted' => 0,
        'ongoing' => 2,
        _ => 0,
      };

  @override
  Widget build(BuildContext context) {
    final status = _statusCopy();
    final topPad = MediaQuery.paddingOf(context).top;
    final displayTrip = widget.trip;

    return Stack(
      children: [
        Positioned(
          top: topPad + 2,
          left: 0,
          right: 0,
          child: Center(
            child: TripDynamicIslandBar(
              title: status.title,
              etaLabel: _etaLabel(),
              phase: status.phase,
              progress: _progressIndex(),
            ),
          ),
        ),
        Positioned(
          top: topPad + 52,
          left: 28,
          right: 28,
          child: Center(
            child: TripStatusBanner(
              title: status.title,
              subtitle: status.subtitle,
              etaLabel: _etaLabel(),
              phase: status.phase,
              titleColor: AppColors.ecoGreenLight,
            ),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: Container(
            decoration: AppDecorations.ecoDrawer(),
            padding: EdgeInsets.fromLTRB(20, 12, 20, MediaQuery.paddingOf(context).bottom + 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TripProgressRail(status: displayTrip.status),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Fare', style: AppTextStyles.label),
                          Text(
                            formatPeso(displayTrip.fare),
                            style: AppTextStyles.headingSm.copyWith(color: AppColors.accent),
                          ),
                        ],
                      ),
                    ),
                    if (tripChatIsOpen(displayTrip.status))
                      IconButton(
                        onPressed: _actionBusy ? null : () => context.push('/chat/${displayTrip.id}'),
                        icon: Icon(Icons.chat_bubble_outline, color: AppColors.accent),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                if (displayTrip.status == 'accepted' || displayTrip.status == 'ongoing')
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.accent,
                          side: BorderSide(color: AppColors.accent.withValues(alpha: 0.6)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        icon: const Icon(Icons.navigation_outlined, size: 20),
                        label: Text(
                          displayTrip.status == 'accepted'
                              ? 'Navigate to pickup'
                              : 'Navigate to drop-off',
                          style: AppTextStyles.label.copyWith(color: AppColors.accent),
                        ),
                        onPressed: _actionBusy
                            ? null
                            : () {
                                final toPickup = displayTrip.status == 'accepted';
                                final lat = toPickup ? displayTrip.pickupLat : displayTrip.dropoffLat;
                                final lng = toPickup ? displayTrip.pickupLng : displayTrip.dropoffLng;
                                final label = toPickup
                                    ? displayTrip.pickupAddress
                                    : displayTrip.dropoffAddress;
                                unawaited(
                                  ExternalNavigation.openNavigation(
                                    context: context,
                                    lat: lat,
                                    lng: lng,
                                    destinationLabel: label,
                                  ),
                                );
                              },
                      ),
                    ),
                  ),
                if (displayTrip.status == 'accepted')
                  PrimaryButton(
                    label: 'Arrived at pickup',
                    isLoading: _actionBusy,
                    onPressed: _actionBusy ? null : _markArrivedAtPickup,
                  ),
                if (displayTrip.status == 'ongoing') ...[
                  if (_cashPhase == _CashPaymentPhase.idle)
                    PrimaryButton(
                      label: 'End trip — collect payment',
                      useAccent: false,
                      isLoading: _actionBusy,
                      onPressed: _actionBusy
                          ? null
                          : () => setState(() => _cashPhase = _CashPaymentPhase.awaitingCash),
                    )
                  else if (_cashPhase == _CashPaymentPhase.awaitingCash) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.accent.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.accent.withValues(alpha: 0.25)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Cash payment due',
                            style: AppTextStyles.label.copyWith(color: AppColors.accent),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            formatPeso(displayTrip.fare),
                            style: AppTextStyles.headingSm.copyWith(color: AppColors.accent),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Collect the full fare from the rider before completing this trip.',
                            style: AppTextStyles.bodySecondary.copyWith(fontSize: 12, height: 1.35),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    PrimaryButton(
                      label: 'Payment received',
                      isLoading: _actionBusy,
                      onPressed: _actionBusy
                          ? null
                          : () => setState(() => _cashPhase = _CashPaymentPhase.slideConfirm),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: _actionBusy
                          ? null
                          : () => setState(() => _cashPhase = _CashPaymentPhase.idle),
                      child: const Text('Back'),
                    ),
                  ] else if (_cashPhase == _CashPaymentPhase.slideConfirm) ...[
                    Text(
                      'Slide to confirm you received ${formatPeso(displayTrip.fare)} in cash.',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.bodySecondary.copyWith(fontSize: 12, height: 1.35),
                    ),
                    const SizedBox(height: 12),
                    SlideToConfirm(
                      label: 'Slide to confirm payment',
                      confirmedLabel: 'Payment confirmed',
                      enabled: !_actionBusy,
                      onConfirmed: _confirmPaymentAndComplete,
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: _actionBusy
                          ? null
                          : () => setState(() => _cashPhase = _CashPaymentPhase.awaitingCash),
                      child: const Text('Back'),
                    ),
                  ],
                ],
              ],
            ),
          ),
        ),
        if (_actionBusy)
          Positioned.fill(
            child: IgnorePointer(
              child: ColoredBox(
                color: AppColors.background.withValues(alpha: 0.35),
                child: const Center(
                  child: Card(
                    color: AppColors.surface,
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(color: AppColors.accent),
                          SizedBox(height: 12),
                          Text(
                            'Updating trip…',
                            style: TextStyle(color: AppColors.textPrimary),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _StatusCopy {
  const _StatusCopy({
    required this.title,
    required this.subtitle,
    required this.phase,
  });

  final String title;
  final String subtitle;
  final TripVisualPhase phase;
}

enum _CashPaymentPhase {
  idle,
  awaitingCash,
  slideConfirm,
}
