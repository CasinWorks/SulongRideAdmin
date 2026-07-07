import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../../core/constants/map_regions.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/location_permission.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/eco/eco_local_store.dart';
import '../../../core/trip_live_activity_service.dart';
import '../../../core/eco/eco_models.dart';
import '../../../models/driver_model.dart';
import '../../../models/trip_model.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/driver_provider.dart';
import '../../../providers/maintenance_provider.dart';
import '../../../providers/trip_provider.dart';
import '../maintenance/maintenance_screen.dart';
import 'booking_bottom_sheet.dart';
import 'home_map_widget.dart';

class HomeUi {
  const HomeUi({
    this.pickup,
    this.pickupAddress = '',
    this.dropoff,
    this.dropoffAddress = '',
    this.routePoints = const [],
    this.distanceKm = 0,
    this.routeDurationSeconds = 0,
    this.predictions = const [],
    this.searchBusy = false,
    this.routeBusy = false,
    this.bookingBusy = false,
    this.locatingPickup = false,
    this.pickupFromDeviceGps = false,
    this.error,
    this.sheetNotice,
  });

  final LatLng? pickup;
  final String pickupAddress;
  final LatLng? dropoff;
  final String dropoffAddress;
  final List<LatLng> routePoints;
  final double distanceKm;
  final int routeDurationSeconds;
  final List<Map<String, dynamic>> predictions;
  final bool searchBusy;
  final bool routeBusy;
  final bool bookingBusy;
  final bool locatingPickup;
  final bool pickupFromDeviceGps;
  final String? error;
  final String? sheetNotice;

  bool get routeReady =>
      pickup != null &&
      dropoff != null &&
      routePoints.isNotEmpty &&
      !routeBusy &&
      !locatingPickup;

  HomeUi copyWith({
    LatLng? pickup,
    String? pickupAddress,
    LatLng? dropoff,
    String? dropoffAddress,
    List<LatLng>? routePoints,
    double? distanceKm,
    int? routeDurationSeconds,
    List<Map<String, dynamic>>? predictions,
    bool? searchBusy,
    bool? routeBusy,
    bool? bookingBusy,
    bool? locatingPickup,
    bool? pickupFromDeviceGps,
    String? error,
    String? sheetNotice,
    bool clearSheetNotice = false,
  }) {
    return HomeUi(
      pickup: pickup ?? this.pickup,
      pickupAddress: pickupAddress ?? this.pickupAddress,
      dropoff: dropoff ?? this.dropoff,
      dropoffAddress: dropoffAddress ?? this.dropoffAddress,
      routePoints: routePoints ?? this.routePoints,
      distanceKm: distanceKm ?? this.distanceKm,
      routeDurationSeconds: routeDurationSeconds ?? this.routeDurationSeconds,
      predictions: predictions ?? this.predictions,
      searchBusy: searchBusy ?? this.searchBusy,
      routeBusy: routeBusy ?? this.routeBusy,
      bookingBusy: bookingBusy ?? this.bookingBusy,
      locatingPickup: locatingPickup ?? this.locatingPickup,
      pickupFromDeviceGps: pickupFromDeviceGps ?? this.pickupFromDeviceGps,
      error: error,
      sheetNotice: clearSheetNotice ? null : (sheetNotice ?? this.sheetNotice),
    );
  }
}

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  static const LatLng _defaultPickup = MapRegions.carmonaCenter;

  late final ValueNotifier<HomeUi> _ui;
  GoogleMapController? _mapController;
  Timer? _debounce;
  LocationSearchTarget _searchTarget = LocationSearchTarget.dropoff;
  bool _pinModeActive = false;
  String _lastSearchQuery = '';

  @override
  void initState() {
    super.initState();
    _ui = ValueNotifier(
      const HomeUi(
        pickup: _defaultPickup,
        pickupAddress: 'Locating…',
        locatingPickup: true,
      ),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initLocation();
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _ui.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _applyDefaultPickup({String? notice}) async {
    var address = 'Carmona, Cavite, Philippines';
    try {
      final geocoded = await ref
          .read(tripRepositoryProvider)
          .reverseGeocode(_defaultPickup)
          .timeout(const Duration(seconds: 8));
      if (geocoded.isNotEmpty) address = geocoded;
    } catch (_) {}
    _ui.value = _ui.value.copyWith(
      pickup: _defaultPickup,
      pickupAddress: address,
      locatingPickup: false,
      pickupFromDeviceGps: false,
      error: null,
      sheetNotice: notice,
    );
    await _mapController?.animateCamera(
      CameraUpdate.newLatLngZoom(_defaultPickup, 14),
    );
    if (_ui.value.dropoff != null) {
      await _refreshRoute();
    }
  }

  Future<void> _initLocation() async {
    _ui.value = _ui.value.copyWith(
      pickup: _ui.value.pickup ?? _defaultPickup,
      locatingPickup: true,
      clearSheetNotice: true,
    );
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        await _applyDefaultPickup(
          notice:
              'Location is off. Using Carmona as pickup — turn on Location in Settings.',
        );
        return;
      }

      final permission = await ensureLocationPermission();
      final granted = permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always;

      if (!granted) {
        await _applyDefaultPickup(
          notice: locationPermissionHint(permission),
        );
        return;
      }

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 12),
        ),
      ).timeout(const Duration(seconds: 14));
      final pickup = LatLng(pos.latitude, pos.longitude);
      var address = '${pickup.latitude.toStringAsFixed(5)}, ${pickup.longitude.toStringAsFixed(5)}';
      try {
        final geocoded = await ref
            .read(tripRepositoryProvider)
            .reverseGeocode(pickup)
            .timeout(const Duration(seconds: 10));
        if (geocoded.isNotEmpty) address = geocoded;
      } catch (_) {}
      _ui.value = _ui.value.copyWith(
        pickup: pickup,
        pickupAddress: address,
        locatingPickup: false,
        pickupFromDeviceGps: true,
        error: null,
        clearSheetNotice: true,
      );
      await _mapController?.animateCamera(CameraUpdate.newLatLngZoom(pickup, 15));
      if (_ui.value.dropoff != null) {
        await _refreshRoute();
      }
    } catch (e) {
      await _applyDefaultPickup(
        notice: 'Could not get GPS ($e). Using Carmona as pickup.',
      );
    }
  }

  Future<void> _onSearchChanged(String text) async {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () async {
      if (text.trim().length < 3) {
        _lastSearchQuery = '';
        _ui.value = _ui.value.copyWith(
          predictions: const [],
          searchBusy: false,
          clearSheetNotice: true,
        );
        return;
      }
      _lastSearchQuery = text.trim();
      _ui.value = _ui.value.copyWith(searchBusy: true, clearSheetNotice: true);
      try {
        final pickup = _ui.value.pickup ?? _defaultPickup;
        final result = await ref
            .read(tripRepositoryProvider)
            .searchPlaces(text, near: pickup)
            .timeout(const Duration(seconds: 15));
        String? notice;
        if (result.predictions.isEmpty) {
          notice =
              'No matches nearby or nationwide. Pin the spot on the map, or try a street or landmark name.';
        }
        _ui.value = _ui.value.copyWith(
          predictions: result.predictions,
          searchBusy: false,
          sheetNotice: notice,
        );
      } catch (e) {
        _ui.value = _ui.value.copyWith(
          searchBusy: false,
          predictions: const [],
          sheetNotice:
              'Search unavailable ($e). You can still pin the location on the map.',
        );
      }
    });
  }

  Future<void> _onPickPrediction(Map<String, dynamic> prediction) async {
    if (_searchTarget == LocationSearchTarget.pickup) {
      await _onPickPickup(prediction);
    } else {
      await _onPickDropoff(prediction);
    }
  }

  Future<void> _onPickPickup(Map<String, dynamic> prediction) async {
    final placeId = prediction['place_id'] as String?;
    if (placeId == null) return;
    _ui.value = _ui.value.copyWith(routeBusy: true, predictions: const []);
    try {
      final details = await ref.read(tripRepositoryProvider).placeDetails(placeId);
      await _applyPickup(details.location, details.address);
    } catch (e) {
      _ui.value = _ui.value.copyWith(routeBusy: false, sheetNotice: e.toString());
    }
  }

  Future<void> _applyPickup(LatLng location, String address) async {
    _ui.value = _ui.value.copyWith(
      pickup: location,
      pickupAddress: address,
      pickupFromDeviceGps: false,
      predictions: const [],
      clearSheetNotice: true,
    );
    await _mapController?.animateCamera(
      CameraUpdate.newLatLngZoom(location, 15),
    );
    if (_ui.value.dropoff != null) {
      await _refreshRoute();
    } else {
      _ui.value = _ui.value.copyWith(routeBusy: false);
    }
  }

  Future<void> _onPickDropoff(Map<String, dynamic> prediction) async {
    final placeId = prediction['place_id'] as String?;
    if (placeId == null) return;
    _ui.value = _ui.value.copyWith(routeBusy: true, predictions: const []);
    try {
      final details = await ref.read(tripRepositoryProvider).placeDetails(placeId);
      await _applyDropoff(details.location, details.address);
    } catch (e) {
      _ui.value = _ui.value.copyWith(routeBusy: false, error: e.toString());
    }
  }

  Future<void> _applyDropoff(LatLng location, String address) async {
    final pickup = _ui.value.pickup ?? _defaultPickup;
    final directions = await ref.read(tripRepositoryProvider).fetchDirections(
          origin: pickup,
          destination: location,
        );
    final km = directions.distanceMeters / 1000;
    _ui.value = _ui.value.copyWith(
      dropoff: location,
      dropoffAddress: address,
      routePoints: directions.points,
      distanceKm: km,
      routeDurationSeconds: directions.durationSeconds,
      routeBusy: false,
      error: null,
      clearSheetNotice: true,
    );
    if (directions.points.isNotEmpty) {
      await _mapController?.animateCamera(
        CameraUpdate.newLatLngBounds(
          _boundsForPoints([pickup, location, ...directions.points]),
          64,
        ),
      );
    }
  }

  Future<void> _refreshRoute() async {
    final pickup = _ui.value.pickup;
    final dropoff = _ui.value.dropoff;
    if (pickup == null || dropoff == null) {
      _ui.value = _ui.value.copyWith(routeBusy: false);
      return;
    }
    _ui.value = _ui.value.copyWith(routeBusy: true);
    try {
      final directions = await ref.read(tripRepositoryProvider).fetchDirections(
            origin: pickup,
            destination: dropoff,
          );
      final km = directions.distanceMeters / 1000;
      _ui.value = _ui.value.copyWith(
        routePoints: directions.points,
        distanceKm: km,
        routeDurationSeconds: directions.durationSeconds,
        routeBusy: false,
        clearSheetNotice: true,
      );
      if (directions.points.isNotEmpty) {
        await _mapController?.animateCamera(
          CameraUpdate.newLatLngBounds(
            _boundsForPoints([pickup, dropoff, ...directions.points]),
            64,
          ),
        );
      }
    } catch (e) {
      _ui.value = _ui.value.copyWith(routeBusy: false, sheetNotice: e.toString());
    }
  }

  void _onSearchTargetChanged(LocationSearchTarget target) {
    setState(() {
      _searchTarget = target;
      _pinModeActive = false;
    });
    _ui.value = _ui.value.copyWith(
      predictions: const [],
      searchBusy: false,
      clearSheetNotice: true,
    );
  }

  void _enterPinMode() {
    setState(() => _pinModeActive = true);
    _ui.value = _ui.value.copyWith(
      predictions: const [],
      clearSheetNotice: true,
    );
  }

  void _exitPinMode() {
    setState(() => _pinModeActive = false);
  }

  Future<void> _onMapTap(LatLng position) async {
    if (!_pinModeActive) return;
    setState(() => _pinModeActive = false);
    _ui.value = _ui.value.copyWith(routeBusy: true, clearSheetNotice: true);
    var address =
        '${position.latitude.toStringAsFixed(5)}, ${position.longitude.toStringAsFixed(5)}';
    try {
      final geocoded = await ref
          .read(tripRepositoryProvider)
          .reverseGeocode(position)
          .timeout(const Duration(seconds: 10));
      if (geocoded.isNotEmpty) address = geocoded;
    } catch (_) {}
    try {
      if (_searchTarget == LocationSearchTarget.pickup) {
        await _applyPickup(position, address);
      } else {
        await _applyDropoff(position, address);
      }
    } catch (e) {
      _ui.value = _ui.value.copyWith(
        routeBusy: false,
        sheetNotice: 'Could not set pinned location: $e',
      );
    }
  }

  Future<void> _useMyLocationForPickup() async {
    setState(() => _searchTarget = LocationSearchTarget.pickup);
    await _initLocation();
  }

  LatLngBounds _boundsForPoints(List<LatLng> points) {
    double minLat = points.first.latitude;
    double maxLat = points.first.latitude;
    double minLng = points.first.longitude;
    double maxLng = points.first.longitude;
    for (final p in points) {
      minLat = minLat < p.latitude ? minLat : p.latitude;
      maxLat = maxLat > p.latitude ? maxLat : p.latitude;
      minLng = minLng < p.longitude ? minLng : p.longitude;
      maxLng = maxLng > p.longitude ? maxLng : p.longitude;
    }
    if ((maxLat - minLat).abs() < 0.002) {
      minLat -= 0.002;
      maxLat += 0.002;
    }
    if ((maxLng - minLng).abs() < 0.002) {
      minLng -= 0.002;
      maxLng += 0.002;
    }
    return LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );
  }

  Future<void> _bookTrip({
    required double fare,
    required String vehicleTypeId,
    String? promoCode,
  }) async {
    final user = ref.read(supabaseClientProvider).auth.currentUser;
    final pickup = _ui.value.pickup;
    final dropoff = _ui.value.dropoff;
    if (user == null || pickup == null || dropoff == null) return;
    _ui.value = _ui.value.copyWith(bookingBusy: true);
    try {
      final fareConfig = await ref.read(tripRepositoryProvider).fetchActiveFareConfig();
      final promo = promoCode != null ? EcoCatalog.findPromo(promoCode) : null;
      final confirmedFare = applyEcoPromo(
        fareConfig.computeFare(_ui.value.distanceKm),
        promo,
      );
      final trip = await ref.read(tripRepositoryProvider).createTrip(
            riderId: user.id,
            pickupAddress: _ui.value.pickupAddress,
            dropoffAddress: _ui.value.dropoffAddress,
            pickup: pickup,
            dropoff: dropoff,
            fare: confirmedFare,
            distanceKm: _ui.value.distanceKm,
          );
      await EcoLocalStore.incrementGreenRides();
      if (!mounted) return;
      _ui.value = _ui.value.copyWith(bookingBusy: false);
      await TripLiveActivityService.showSearching();
      if (!mounted) return;
      context.push('/trip/${trip.id}');
    } catch (e) {
      final message = e.toString();
      final String sheetNotice;
      if (message.contains('row-level security') || message.contains('42501')) {
        sheetNotice =
            'Supabase RLS: run supabase/fix_trips_rls.sql in the SQL Editor '
            '(allows riders to insert trips), then try Book ride again.';
      } else if (message.contains('distance_km') || message.contains('PGRST204')) {
        sheetNotice =
            'Trips table: run supabase/fix_trips_distance_km.sql in Supabase SQL Editor, '
            'then wait ~30s or restart the app.';
      } else if (message.contains('23503') ||
          message.contains('trips_rider_id_fkey') ||
          (message.contains('foreign key') && message.contains('users'))) {
        sheetNotice =
            'Your rider profile is missing in Supabase (logged in but no public.users row). '
            'Run supabase/fix_users_rls.sql, then supabase/backfill_users_from_auth.sql '
            'in the SQL Editor (or sign out and register again). '
            'If it persists, sign out and sign in again.';
      } else {
        sheetNotice = message;
      }
      _ui.value = _ui.value.copyWith(
        bookingBusy: false,
        sheetNotice: sheetNotice,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<TripModel?>>(riderActiveTripProvider, (_, next) {
      unawaited(TripLiveActivityService.reconcileWithTrip(next.asData?.value));
    });

    final driversAsync = ref.watch(nearbyDriversProvider);
    final activeTrip = ref.watch(riderActiveTripProvider).asData?.value;
    final maintenanceStatus = ref.watch(appMaintenanceStatusProvider);

    return ValueListenableBuilder<HomeUi>(
      valueListenable: _ui,
      builder: (context, ui, _) {
        final pickup = ui.pickup ?? _defaultPickup;
        final markers = <Marker>{};
        if (ui.pickup != null) {
          markers.add(
            Marker(
              markerId: const MarkerId('pickup'),
              position: ui.pickup!,
              icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
              infoWindow: InfoWindow(
                title: 'Pickup',
                snippet: ui.pickupFromDeviceGps
                    ? ui.pickupAddress
                    : '${ui.pickupAddress} (custom)',
              ),
            ),
          );
        }
        if (ui.dropoff != null) {
          markers.add(
            Marker(
              markerId: const MarkerId('dropoff'),
              position: ui.dropoff!,
              icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRose),
            ),
          );
        }
        final drivers = driversAsync.maybeWhen(
          data: (d) => d,
          orElse: () => <DriverModel>[],
        );
        for (final d in drivers) {
          final pos = d.latLng;
          if (pos == null) continue;
          markers.add(
            Marker(
              markerId: MarkerId('driver-${d.id}'),
              position: pos,
              icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
              infoWindow: InfoWindow(title: d.fullName, snippet: d.trikePlateNumber),
            ),
          );
        }

        final polylines = <Polyline>{};
        if (ui.routePoints.isNotEmpty) {
          polylines.add(
            Polyline(
              polylineId: const PolylineId('route'),
              color: AppColors.accent,
              width: 5,
              points: ui.routePoints,
            ),
          );
        }

        return Scaffold(
          backgroundColor: AppColors.background,
          body: Stack(
            children: [
              Positioned.fill(
                child: HomeMapWidget(
                  initialTarget: pickup,
                  markers: markers,
                  polylines: polylines,
                  onMapCreated: (c) => _mapController = c,
                  onMapTap: _pinModeActive ? _onMapTap : null,
                ),
              ),
              if (activeTrip != null)
                Positioned(
                  top: MediaQuery.paddingOf(context).top + 56,
                  left: 12,
                  right: 12,
                  child: Material(
                    color: AppColors.surface,
                    elevation: 4,
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Active trip (${activeTrip.status}) — tap to return to your ride.',
                            style: AppTextStyles.bodySecondary,
                          ),
                          const SizedBox(height: 8),
                          FilledButton(
                            onPressed: () => context.go('/trip/${activeTrip.id}'),
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.accent,
                              foregroundColor: AppColors.primary,
                            ),
                            child: const Text('Continue trip'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              if (ui.error != null ||
                  (ui.sheetNotice != null && ui.predictions.isEmpty))
                Positioned(
                  top: MediaQuery.paddingOf(context).top +
                      (activeTrip != null ? 108 : 56),
                  left: 12,
                  right: 12,
                  child: Material(
                    color: AppColors.surface,
                    elevation: 4,
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(
                        ui.sheetNotice ?? ui.error!,
                        style: AppTextStyles.bodySecondary.copyWith(
                          color: AppColors.error,
                        ),
                      ),
                    ),
                  ),
                ),
              Positioned(
                top: MediaQuery.paddingOf(context).top + 8,
                left: 12,
                right: 12,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    MaintenanceBanner(status: maintenanceStatus),
                    Row(
                      children: [
                        _CircleIconButton(
                          icon: Icons.history,
                          onTap: () => context.push('/history'),
                        ),
                        const SizedBox(width: 8),
                        _CircleIconButton(
                          icon: Icons.settings_outlined,
                          onTap: () => context.push('/settings'),
                        ),
                        const Spacer(),
                        _CircleIconButton(
                          icon: Icons.person_outline,
                          onTap: () => context.push('/profile'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (_pinModeActive)
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: MediaQuery.paddingOf(context).bottom + 24,
                  child: Material(
                    color: AppColors.forestMedium,
                    elevation: 6,
                    borderRadius: BorderRadius.circular(16),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 8, 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.add_location_alt, color: AppColors.ecoGreenLight),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  _searchTarget == LocationSearchTarget.pickup
                                      ? 'Tap the map to set pickup'
                                      : 'Tap the map to set destination',
                                  style: AppTextStyles.body,
                                ),
                              ),
                            ],
                          ),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: _exitPinMode,
                              child: Text(
                                'Cancel',
                                style: AppTextStyles.body.copyWith(color: AppColors.ecoGreenLight),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              if (!_pinModeActive)
                Positioned.fill(
                  child: BookingBottomSheet(
                    predictions: ui.predictions,
                    searchBusy: ui.searchBusy,
                    routeBusy: ui.routeBusy,
                    routeReady: ui.routeReady,
                    searchTarget: _searchTarget,
                    onSearchTargetChanged: _onSearchTargetChanged,
                    onUseMyLocationForPickup: _useMyLocationForPickup,
                    pickupLabel: ui.locatingPickup
                        ? 'Locating…'
                        : (ui.pickupAddress.isEmpty ? 'Current location' : ui.pickupAddress),
                    sheetNotice: ui.sheetNotice,
                    onOpenLocationSettings: openLocationSettings,
                    onRetryLocation: _initLocation,
                    showPinOnMapOption:
                        _lastSearchQuery.length >= 3 &&
                        !ui.searchBusy &&
                        ui.predictions.isEmpty,
                    onPinOnMap: _enterPinMode,
                    dropoffLabel:
                        ui.dropoffAddress.isEmpty ? 'Choose a destination' : ui.dropoffAddress,
                    distanceKm: ui.distanceKm,
                    routeDurationSeconds: ui.routeDurationSeconds,
                    bookingBusy: ui.bookingBusy,
                    onSearchChanged: _onSearchChanged,
                    onPickPrediction: _onPickPrediction,
                    onBook: ({required fare, required vehicleTypeId, promoCode}) => _bookTrip(
                      fare: fare,
                      vehicleTypeId: vehicleTypeId,
                      promoCode: promoCode,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _CircleIconButton extends StatelessWidget {
  const _CircleIconButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.forestMedium.withValues(alpha: 0.92),
      shape: const CircleBorder(),
      elevation: 3,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Icon(icon, color: AppColors.ecoCream),
        ),
      ),
    );
  }
}
