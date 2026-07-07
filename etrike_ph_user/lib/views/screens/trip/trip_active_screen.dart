import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../core/eta_utils.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_map_styles.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/local_notifications_service.dart';
import '../../../core/map_camera_utils.dart';
import '../../../core/trip_live_activity_service.dart';
import '../../../models/driver_model.dart';
import '../../../models/trip_model.dart';
import '../../../providers/driver_provider.dart';
import '../../../providers/chat_provider.dart';
import '../../../providers/trip_provider.dart';
import '../../components/platform_map_view.dart';
import 'widgets/trip_tracking_overlay.dart';

class TripActiveScreen extends ConsumerStatefulWidget {
  const TripActiveScreen({super.key, required this.tripId});

  final String tripId;

  @override
  ConsumerState<TripActiveScreen> createState() => _TripActiveScreenState();
}

class _TripActiveScreenState extends ConsumerState<TripActiveScreen> {
  GoogleMapController? _mapController;
  String? _syncedLiveActivityKey;
  String? _routeTripId;
  Set<Polyline> _routePolylines = {};
  int? _routeDurationSeconds;
  int? _liveEtaSeconds;
  String? _liveEtaKey;
  DateTime? _lastEtaFetch;
  LatLng? _lastEtaOrigin;
  String? _lastCameraKey;
  String? _routeLoadingForTripId;

  @override
  void dispose() {
    TripLiveActivityService.end();
    _mapController?.dispose();
    super.dispose();
  }

  void _syncLiveActivity(TripModel trip, DriverModel? driver) {
    unawaited(
      TripLiveActivityService.syncFromTrip(
        trip,
        driver: driver,
        eta: _etaLabel(trip),
      ),
    );
  }

  String _etaLabel(TripModel trip) {
    return formatEtaMinutes(
      _liveEtaSeconds ?? _routeDurationSeconds,
      fallback: formatEtaMinutes(
        estimateDurationSecondsFromKm(trip.distanceKm),
        fallback: '—',
      ),
    );
  }

  Future<void> _refreshLiveEta(
    TripModel trip,
    LatLng? driverPos,
    DriverModel? driver,
  ) async {
    if (trip.status != 'accepted' && trip.status != 'ongoing') return;

    final LatLng? origin;
    final LatLng destination;
    if (trip.status == 'accepted') {
      if (driverPos == null) return;
      origin = driverPos;
      destination = LatLng(trip.pickupLat, trip.pickupLng);
    } else {
      origin = driverPos ?? LatLng(trip.pickupLat, trip.pickupLng);
      destination = LatLng(trip.dropoffLat, trip.dropoffLng);
    }

    final key = '${trip.id}:${trip.status}';
    final now = DateTime.now();
    if (_liveEtaKey == key &&
        _lastEtaFetch != null &&
        now.difference(_lastEtaFetch!) < const Duration(seconds: 45) &&
        _lastEtaOrigin != null &&
        _lastEtaOrigin!.latitude == origin.latitude &&
        _lastEtaOrigin!.longitude == origin.longitude) {
      return;
    }

    try {
      final directions = await ref.read(tripRepositoryProvider).fetchDirections(
            origin: origin,
            destination: destination,
          );
      if (!mounted) return;
      if (directions.durationSeconds <= 0) return;
      setState(() {
        _liveEtaSeconds = directions.durationSeconds;
        _liveEtaKey = key;
        _lastEtaFetch = now;
        _lastEtaOrigin = origin;
      });
      _syncLiveActivity(trip, driver);
    } catch (_) {}
  }

  Future<void> _ensureRoute(TripModel trip) async {
    if (_routeTripId == trip.id && _routePolylines.isNotEmpty) return;
    if (_routeLoadingForTripId == trip.id) return;
    _routeLoadingForTripId = trip.id;
    _routeTripId = trip.id;
    try {
      final directions = await ref.read(tripRepositoryProvider).fetchDirections(
            origin: LatLng(trip.pickupLat, trip.pickupLng),
            destination: LatLng(trip.dropoffLat, trip.dropoffLng),
          );
      if (!mounted || _routeTripId != trip.id) return;
      setState(() {
        _routePolylines = {
          Polyline(
            polylineId: const PolylineId('trip_route'),
            points: directions.points,
            color: AppColors.accent,
            width: 5,
          ),
        };
        _routeDurationSeconds = directions.durationSeconds;
      });
      _lastCameraKey = null;
    } catch (_) {}
    _routeLoadingForTripId = null;
  }

  void _fitCamera(TripModel trip, LatLng? driverPos, {bool force = false}) {
    final controller = _mapController;
    if (controller == null) return;

    final points = <LatLng>[
      LatLng(trip.pickupLat, trip.pickupLng),
      LatLng(trip.dropoffLat, trip.dropoffLng),
      ?driverPos,
      ..._routePolylines.expand((p) => p.points),
    ];
    if (points.isEmpty) return;

    final key = cameraKeyForPoints(points);
    if (!force && key == _lastCameraKey) return;
    _lastCameraKey = key;

    unawaited(
      controller.animateCamera(
        CameraUpdate.newLatLngBounds(boundsForPoints(points), 80),
      ),
    );
  }

  Set<Marker> _buildMarkers(TripModel trip, LatLng? driverPos, DriverModel? driver) {
    final markers = <Marker>{
      Marker(
        markerId: const MarkerId('pickup'),
        position: LatLng(trip.pickupLat, trip.pickupLng),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
        infoWindow: InfoWindow(title: 'Pickup', snippet: trip.pickupAddress),
      ),
      Marker(
        markerId: const MarkerId('dropoff'),
        position: LatLng(trip.dropoffLat, trip.dropoffLng),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRose),
        infoWindow: InfoWindow(title: 'Drop-off', snippet: trip.dropoffAddress),
      ),
    };

    if (driverPos != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('driver'),
          position: driverPos,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
          infoWindow: InfoWindow(
            title: 'Your driver',
            snippet: driver?.fullName ?? 'En route',
          ),
        ),
      );
    }

    return markers;
  }

  @override
  Widget build(BuildContext context) {
    final tripAsync = ref.watch(tripRealtimeProvider(widget.tripId));
    ref.watch(tripChatProvider(widget.tripId));

    ref.listen(tripRealtimeProvider(widget.tripId), (previous, next) {
      final prevTrip = previous?.asData?.value;
      final newTrip = next.asData?.value;
      if (newTrip != null) {
        final driverId = newTrip.driverId;
        final driver = driverId == null
            ? null
            : ref.read(driverLiveProvider(driverId)).asData?.value;
        _syncLiveActivity(newTrip, driver);
      }
      if (newTrip?.status == 'accepted' && prevTrip?.status != 'accepted') {
        LocalNotificationsService.showTripAccepted();
      }
      if (newTrip?.status == 'completed' && prevTrip?.status != 'completed') {
        TripLiveActivityService.end();
        if (context.mounted) {
          context.go('/trip/${widget.tripId}/completed');
        }
      }
      if (newTrip?.status == 'cancelled' && prevTrip?.status != 'cancelled') {
        TripLiveActivityService.end();
        if (context.mounted) {
          context.go('/home');
        }
      }
    });

    return tripAsync.when(
      loading: () => Scaffold(
        backgroundColor: AppColors.background,
        body: const Center(child: CircularProgressIndicator(color: AppColors.ecoGreen)),
      ),
      error: (e, _) => Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.go('/home'),
          ),
        ),
        body: Center(child: Text('Error: $e', style: AppTextStyles.body)),
      ),
      data: (trip) {
        if (trip == null) {
          return Scaffold(
            backgroundColor: AppColors.background,
            body: Center(child: Text('Trip not found', style: AppTextStyles.body)),
          );
        }

        final driverId = trip.driverId;
        final driverState = driverId == null
            ? const AsyncValue<DriverModel?>.data(null)
            : ref.watch(driverLiveProvider(driverId));

        final driver = driverState.asData?.value;
        final driverPos = driver?.latLng;
        final liveKey = '${trip.id}:${trip.status}';
        if (_syncedLiveActivityKey != liveKey) {
          _syncedLiveActivityKey = liveKey;
          _liveEtaKey = null;
          _syncLiveActivity(trip, driver);
        }

        if (_routeTripId != trip.id || _routePolylines.isEmpty) {
          unawaited(_ensureRoute(trip));
        }

        unawaited(_refreshLiveEta(trip, driverPos, driver));

        if (driverId != null) {
          ref.listen<AsyncValue<DriverModel?>>(
            driverLiveProvider(driverId),
            (previous, next) {
              final pos = next.asData?.value?.latLng;
              final d = next.asData?.value;
              _fitCamera(trip, pos);
              unawaited(_refreshLiveEta(trip, pos, d));
            },
          );
        }

        final markers = _buildMarkers(trip, driverPos, driver);

        return Scaffold(
          backgroundColor: AppColors.background,
          body: Stack(
            children: [
              Positioned.fill(
                child: PlatformMapView(
                  initialTarget: LatLng(trip.pickupLat, trip.pickupLng),
                  markers: markers,
                  polylines: _routePolylines,
                  mapStyle: AppMapStyles.ecoTrip,
                  onMapCreated: (c) {
                    _mapController = c;
                    _lastCameraKey = null;
                    _fitCamera(trip, driverPos, force: true);
                  },
                  myLocationEnabled: false,
                ),
              ),
              Positioned(
                top: MediaQuery.paddingOf(context).top + 4,
                left: 8,
                child: Material(
                  color: AppColors.forestMedium.withValues(alpha: 0.9),
                  shape: const CircleBorder(),
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back, color: AppColors.ecoCream),
                    onPressed: () => context.go('/home'),
                  ),
                ),
              ),
              Positioned(
                right: 12,
                bottom: MediaQuery.paddingOf(context).bottom + 280,
                child: Material(
                  color: AppColors.forestMedium.withValues(alpha: 0.92),
                  shape: const CircleBorder(),
                  elevation: 4,
                  child: IconButton(
                    tooltip: 'Recenter map',
                    icon: const Icon(Icons.my_location, color: AppColors.ecoCream),
                    onPressed: () => _fitCamera(trip, driverPos, force: true),
                  ),
                ),
              ),
              TripTrackingOverlay(
                trip: trip,
                driver: driver,
                etaLabel: _etaLabel(trip),
              ),
            ],
          ),
        );
      },
    );
  }
}
