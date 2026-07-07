import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_map_styles.dart';
import '../../../core/trip_live_activity_service.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/chat_provider.dart';
import '../../../providers/location_provider.dart';
import '../../../providers/trip_provider.dart';
import '../../components/platform_map_view.dart';
import 'widgets/driver_trip_overlay.dart';

class ActiveTripScreen extends ConsumerStatefulWidget {
  const ActiveTripScreen({super.key, required this.tripId});

  final String tripId;

  @override
  ConsumerState<ActiveTripScreen> createState() => _ActiveTripScreenState();
}

class _ActiveTripScreenState extends ConsumerState<ActiveTripScreen> {
  GoogleMapController? _mapController;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final ticker = ref.read(locationTickerProvider);
      ticker.setFastMode(true);
      ticker.start();
    });
  }

  @override
  void dispose() {
    ref.read(locationTickerProvider).setFastMode(false);
    _mapController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tripAsync = ref.watch(tripRealtimeProvider(widget.tripId));
    ref.watch(tripChatProvider(widget.tripId));
    final uid = ref.watch(supabaseClientProvider).auth.currentUser?.id;

    ref.listen(tripRealtimeProvider(widget.tripId), (previous, next) {
      final prevTrip = previous?.asData?.value;
      final newTrip = next.asData?.value;
      if (newTrip != null) {
        unawaited(DriverTripLiveActivityService.syncFromTrip(newTrip));
      }
      final terminal = newTrip?.status == 'completed' || newTrip?.status == 'cancelled';
      final wasActive = prevTrip != null &&
          prevTrip.status != 'completed' &&
          prevTrip.status != 'cancelled';
      if (terminal && wasActive) {
        unawaited(DriverTripLiveActivityService.end());
        if (context.mounted) {
          if (newTrip?.status == 'completed') {
            context.go('/trip/${widget.tripId}/completed');
          } else {
            context.go('/home');
          }
        }
      }
    });

    return tripAsync.when(
      loading: () => Scaffold(
        backgroundColor: AppColors.background,
        body: const Center(child: CircularProgressIndicator(color: AppColors.accent)),
      ),
      error: (e, _) => Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.go('/home'),
          ),
        ),
        body: Center(child: Text('Error: $e')),
      ),
      data: (trip) {
        if (trip == null) {
          return Scaffold(
            backgroundColor: AppColors.background,
            appBar: AppBar(),
            body: const Center(child: Text('Trip not found')),
          );
        }
        if (uid != null && trip.driverId != null && trip.driverId != uid) {
          return Scaffold(
            backgroundColor: AppColors.background,
            appBar: AppBar(),
            body: const Center(child: Text('This trip is assigned to another driver.')),
          );
        }

        const defaultCenter = LatLng(14.5995, 120.9842);
        final pickup = LatLng(trip.pickupLat, trip.pickupLng);
        final dropoff = LatLng(trip.dropoffLat, trip.dropoffLng);
        final mapCenter = pickup.latitude != 0 || pickup.longitude != 0
            ? pickup
            : defaultCenter;

        final markers = <Marker>{
          if (pickup.latitude != 0 || pickup.longitude != 0)
            Marker(
              markerId: const MarkerId('pickup'),
              position: pickup,
              icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
              infoWindow: InfoWindow(
                title: 'Pickup',
                snippet: trip.pickupAddress,
              ),
            ),
          if (dropoff.latitude != 0 || dropoff.longitude != 0)
            Marker(
              markerId: const MarkerId('dropoff'),
              position: dropoff,
              icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRose),
              infoWindow: InfoWindow(
                title: 'Drop-off',
                snippet: trip.dropoffAddress,
              ),
            ),
        };

        return Scaffold(
          backgroundColor: AppColors.background,
          body: Stack(
            children: [
              Positioned.fill(
                child: PlatformMapView(
                  initialTarget: mapCenter,
                  markers: markers,
                  mapStyle: AppMapStyles.ecoTrip,
                  onMapCreated: (c) => _mapController = c,
                  myLocationEnabled: true,
                ),
              ),
              Positioned(
                top: MediaQuery.paddingOf(context).top + 4,
                left: 8,
                child: Material(
                  color: AppColors.surface.withValues(alpha: 0.92),
                  shape: const CircleBorder(),
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
                    onPressed: () => context.go('/home'),
                  ),
                ),
              ),
              DriverTripOverlay(trip: trip),
            ],
          ),
        );
      },
    );
  }
}
