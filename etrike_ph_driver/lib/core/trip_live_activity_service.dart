import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:live_activities/live_activities.dart';

import '../models/trip_model.dart';

/// iOS Live Activity + Dynamic Island for the driver's active trip.
///
/// Failures never block in-app trip UI.
abstract final class DriverTripLiveActivityService {
  static const _appGroupId = 'group.com.etrikeph.etrikePhDriver';
  static const _activityKey = 'sulong_driver_trip';

  static final LiveActivities _plugin = LiveActivities();
  static String? _activityId;
  static bool _initialized = false;
  static Future<void>? _initFuture;

  static bool _isLiveTripStatus(String status) =>
      status == 'accepted' || status == 'ongoing';

  static Future<void> init() {
    if (!Platform.isIOS) return Future.value();
    _initFuture ??= _doInit();
    return _initFuture!;
  }

  static Future<void> _ensureReady() async {
    if (!Platform.isIOS) return;
    if (!_initialized) await init();
  }

  static Future<void> _doInit() async {
    if (_initialized) return;
    try {
      await _plugin.init(
        appGroupId: _appGroupId,
        urlScheme: 'sulongdriver',
        requireNotificationPermission: false,
      );
      _initialized = true;
    } catch (e) {
      debugPrint('DriverTripLiveActivityService init: $e');
    }
  }

  /// Keep the Live Activity in sync with server state, or dismiss it when idle.
  static Future<void> reconcileWithTrip(TripModel? trip) async {
    if (!Platform.isIOS) return;
    await _ensureReady();
    if (!_initialized) return;
    if (trip == null || !_isLiveTripStatus(trip.status)) {
      await end();
      return;
    }
    await syncFromTrip(trip);
  }

  static Future<void> syncFromTrip(TripModel trip) async {
    if (!Platform.isIOS) return;
    await _ensureReady();
    if (!_initialized) return;
    try {
      if (!await _plugin.areActivitiesEnabled()) return;
      if (!_isLiveTripStatus(trip.status)) {
        await end();
        return;
      }

      final payload = _payloadFor(trip);
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
    } catch (e) {
      debugPrint('DriverTripLiveActivityService: $e');
    }
  }

  /// Briefly surfaces a new chat message on the lock screen / Dynamic Island.
  static Future<void> showChatPreview({
    required TripModel trip,
    required String preview,
  }) async {
    if (!Platform.isIOS) return;
    if (!_isLiveTripStatus(trip.status)) return;
    await _ensureReady();
    if (!_initialized) return;
    try {
      if (!await _plugin.areActivitiesEnabled()) return;
      final base = _payloadFor(trip);
      final trimmed = preview.length > 72 ? '${preview.substring(0, 72)}…' : preview;
      final payload = {
        ...base,
        'subtitle': '💬 $trimmed',
      };
      final id = await _plugin.createOrUpdateActivity(
        _activityKey,
        payload,
        removeWhenAppIsKilled: false,
      );
      _activityId = id ?? _activityId;
    } catch (e) {
      debugPrint('DriverTripLiveActivityService chat preview: $e');
    }
  }

  static Map<String, dynamic> _payloadFor(TripModel trip) {
    final (title, subtitle, phase, progress, eta) = switch (trip.status) {
      'accepted' => (
          'Head to pickup',
          trip.pickupAddress,
          'assigned',
          0,
          '3 min',
        ),
      'ongoing' => (
          'En route',
          trip.dropoffAddress,
          'enroute',
          2,
          '~${(trip.distanceKm ?? 2).ceil()} min',
        ),
      _ => (
          'Trip update',
          trip.pickupAddress,
          'searching',
          0,
          '—',
        ),
    };
    return {
      'title': title,
      'subtitle': subtitle,
      'eta': eta,
      'phase': phase,
      'progress': progress,
    };
  }

  /// Dismiss any driver Live Activity — including orphans after app restart.
  static Future<void> end() async {
    if (!Platform.isIOS) return;
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
        debugPrint('DriverTripLiveActivityService: ended Live Activity');
      }
    } catch (e) {
      debugPrint('DriverTripLiveActivityService end: $e');
    } finally {
      _activityId = null;
    }
  }
}
