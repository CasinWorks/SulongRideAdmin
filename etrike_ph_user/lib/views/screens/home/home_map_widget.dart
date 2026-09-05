import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../core/constants/app_map_styles.dart';
import '../../components/platform_map_view.dart';

class HomeMapWidget extends StatelessWidget {
  const HomeMapWidget({
    super.key,
    required this.initialTarget,
    required this.markers,
    required this.polylines,
    required this.onMapCreated,
    this.onMapTap,
    this.myLocationEnabled = true,
    this.circles = const {},
    this.cameraTargetBounds,
    this.minZoom,
    this.initialZoom = 15,
  });

  final LatLng initialTarget;
  final Set<Marker> markers;
  final Set<Polyline> polylines;
  final Set<Circle> circles;
  final void Function(GoogleMapController controller) onMapCreated;
  final void Function(LatLng position)? onMapTap;
  final bool myLocationEnabled;
  final LatLngBounds? cameraTargetBounds;
  final double? minZoom;
  final double initialZoom;

  @override
  Widget build(BuildContext context) {
    return PlatformMapView(
      initialTarget: initialTarget,
      markers: markers,
      polylines: polylines,
      circles: circles,
      cameraTargetBounds: cameraTargetBounds,
      minZoom: minZoom,
      initialZoom: initialZoom,
      onMapCreated: onMapCreated,
      onMapTap: onMapTap,
      myLocationEnabled: myLocationEnabled,
      mapStyle: AppMapStyles.ecoDark,
    );
  }
}
