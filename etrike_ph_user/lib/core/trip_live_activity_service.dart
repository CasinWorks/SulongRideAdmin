import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:live_activities/live_activities.dart';

import '../models/driver_model.dart';
import '../models/trip_model.dart';
import 'eta_utils.dart';

/// How trip status can appear outside the app on Apple devices.
enum TripLivePresentation {
  none,
  lockScreen,
  dynamicIsland,
  appleWatch,
}

/// iOS Live Activity + Dynamic Island updates during an active booking.
///
/// Optional layer — failures never block booking or in-app trip UI.
abstract final class TripLiveActivityService {
  static const _appGroupId = 'group.com.etrikeph.etrikePhUser';
  static const _activityKey = 'sulong_active_trip';

  static final LiveActivities _plugin = LiveActivities();
  static String? _activityId;
  static bool _initialized = false;
  static Future<void>? _initFuture;

  static bool _isLiveTripStatus(String status) =>
      status == 'requested' || status == 'accepted' || status == 'ongoing';

  static TripLivePresentation get presentationHint {
    if (!Platform.isIOS) return TripLivePresentation.none;
    return TripLivePresentation.lockScreen;
  }

  static Future<void> init() {
    if (!Platform.isIOS) return Future.value();
    _initFuture ??= _doInit();
    return _initFuture!;
  }

  static Future<void> _doInit() async {
    await _runOptional(() async {
      if (_initialized) return;
      await _plugin.init(
        appGroupId: _appGroupId,
        urlScheme: 'sulongride',
        requireNotificationPermission: false,
      );
      _initialized = true;
      if (kDebugMode) {
        final enabled = await _plugin.areActivitiesEnabled();
        debugPrint('TripLiveActivityService ready (enabled=$enabled)');
      }
    });
  }

  static Future<void> _ensureReady() async {
    if (!Platform.isIOS) return;
    if (!_initialized) await init();
  }

  static Future<bool> get isSupported async {
    if (!Platform.isIOS) return false;
    await _ensureReady();
    if (!_initialized) return false;
    try {
      return await _plugin.areActivitiesEnabled();
    } catch (_) {
      return false;
    }
  }

  static int _progressForStatus(String status) {
    return switch (status) {
      'accepted' => 1,
      'ongoing' => 2,
      _ => 0,
    };
  }

  static String _phaseForStatus(String status) {
    return switch (status) {
      'accepted' => 'assigned',
      'ongoing' => 'enroute',
      _ => 'searching',
    };
  }

  static Map<String, dynamic> _payload({
    required String title,
    required String subtitle,
    required String eta,
    required String status,
  }) {
    return {
      'title': title,
      'subtitle': subtitle,
      'eta': eta,
      'phase': _phaseForStatus(status),
      'progress': _progressForStatus(status),
    };
  }

  /// Keep the Live Activity in sync with server state, or dismiss when idle.
  static Future<void> reconcileWithTrip(
    TripModel? trip, {
    DriverModel? driver,
    String? eta,
  }) async {
    if (!Platform.isIOS) return;
    await _ensureReady();
    if (!_initialized) return;
    if (trip == null || !_isLiveTripStatus(trip.status)) {
      await end();
      return;
    }
    await syncFromTrip(trip, driver: driver, eta: eta);
  }

  static Future<void> syncTrip({
    required String status,
    required String title,
    required String subtitle,
    required String eta,
    String? driverName,
  }) async {
    await _runOptional(() async {
      await _ensureReady();
      if (!_initialized) {
        debugPrint('TripLiveActivityService: init incomplete, skipping');
        return;
      }
      if (!await isSupported) {
        debugPrint('TripLiveActivityService: Live Activities disabled in Settings');
        return;
      }
      if (!_isLiveTripStatus(status)) {
        await end();
        return;
      }

      final payload = _payload(
        title: title,
        subtitle: subtitle,
        eta: eta,
        status: status,
      );

      final id = await _plugin.createOrUpdateActivity(
        _activityKey,
        payload,
        removeWhenAppIsKilled: false,
      );
      _activityId = id ?? _activityId;
      if (_activityId == null) {
        final ids = await _plugin.getAllActivitiesIds();
        if (ids.isNotEmpty) _activityId = ids.last;
      }
      if (kDebugMode) {
        debugPrint(
          'TripLiveActivityService: ${_activityId ?? "no-id"} '
          'phase=${_phaseForStatus(status)}',
        );
      }
    });
  }

  static Future<void> showSearching({
    String subtitle = 'Finding the nearest electric trike…',
  }) =>
      syncTrip(
        status: 'requested',
        title: 'Finding your trike',
        subtitle: subtitle,
        eta: '—',
      );

  static Future<void> showAssigned({
    required String driverName,
    String eta = '3 min',
  }) =>
      syncTrip(
        status: 'accepted',
        title: 'Driver assigned',
        subtitle: '$driverName is heading to your pickup',
        eta: eta,
        driverName: driverName,
      );

  static Future<void> showEnRoute({
    required String destination,
    required String eta,
  }) =>
      syncTrip(
        status: 'ongoing',
        title: 'En route',
        subtitle: 'Heading to $destination',
        eta: eta,
      );

  /// Briefly surfaces a new chat message on the lock screen / Dynamic Island.
  static Future<void> showChatPreview({
    required TripModel trip,
    required String preview,
  }) async {
    if (!_isLiveTripStatus(trip.status)) {
      await end();
      return;
    }
    final trimmed =
        preview.length > 72 ? '${preview.substring(0, 72)}…' : preview;
    final resolvedEta = formatEtaMinutes(
      estimateDurationSecondsFromKm(trip.distanceKm),
      fallback: '—',
    );
    await syncTrip(
      status: trip.status,
      title: 'New message',
      subtitle: '💬 $trimmed',
      eta: resolvedEta,
    );
  }

  static Future<void> syncFromTrip(
    TripModel trip, {
    DriverModel? driver,
    String? eta,
  }) async {
    if (!_isLiveTripStatus(trip.status)) {
      await end();
      return;
    }

    final resolvedEta = eta ??
        formatEtaMinutes(
          estimateDurationSecondsFromKm(trip.distanceKm),
          fallback: '—',
        );

    switch (trip.status) {
      case 'accepted':
        await showAssigned(
          driverName: driver?.fullName ?? 'Your driver',
          eta: resolvedEta,
        );
      case 'ongoing':
        await showEnRoute(
          destination: trip.dropoffAddress,
          eta: resolvedEta,
        );
      case 'requested':
        await showSearching();
      default:
        await end();
    }
  }

  /// Dismiss any rider Live Activity — including orphans after app restart.
  static Future<void> end() async {
    await _runOptional(() async {
      await _ensureReady();
      if (!_initialized) return;
      try {
        final ids = <String>{};
        if (_activityId != null) ids.add(_activityId!);
        ids.addAll(await _plugin.getAllActivitiesIds());
        for (final id in ids) {
          try {
            await _plugin.endActivity(id);
          } catch (_) {}
        }
        await _plugin.endAllActivities();
        if (kDebugMode) {
          debugPrint('TripLiveActivityService: ended Live Activity');
        }
      } finally {
        _activityId = null;
      }
    });
  }

  static Future<void> dispose() async {
    await end();
    await _runOptional(() async {
      if (Platform.isIOS && _initialized) {
        await _plugin.dispose();
        _initialized = false;
        _initFuture = null;
      }
    });
  }

  static Future<void> _runOptional(Future<void> Function() action) async {
    try {
      await action();
    } catch (e, stack) {
      final message = e.toString();
      if (message.contains('LIVE_ACTIVITY_ERROR') ||
          message.contains('ActivityInput')) {
        debugPrint(
          'TripLiveActivityService: Live Activity failed. '
          'Run: cd ios && ruby check_live_activity_setup.rb — '
          'App Group must exist in Apple Developer portal. Error: $e',
        );
      } else {
        debugPrint('TripLiveActivityService error: $e');
      }
      if (kDebugMode) debugPrint('$stack');
    }
  }
}
