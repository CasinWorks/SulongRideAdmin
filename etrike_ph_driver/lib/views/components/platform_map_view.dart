import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/platform/platform_flags.dart';

bool get supportsNativeGoogleMap =>
    defaultTargetPlatform == TargetPlatform.iOS ||
    defaultTargetPlatform == TargetPlatform.android;

class PlatformMapView extends StatelessWidget {
  const PlatformMapView({
    super.key,
    required this.initialTarget,
    required this.markers,
    this.polylines = const {},
    this.onMapCreated,
    this.myLocationEnabled = true,
    this.mapStyle,
  });

  final LatLng initialTarget;
  final Set<Marker> markers;
  final Set<Polyline> polylines;
  final void Function(GoogleMapController controller)? onMapCreated;
  final bool myLocationEnabled;
  final String? mapStyle;

  @override
  Widget build(BuildContext context) {
    if (!supportsNativeGoogleMap || PlatformFlags.isIOSSimulator) {
      return _MapPlaceholder(
        center: initialTarget,
        markers: markers,
        hasRoute: polylines.isNotEmpty,
        isSimulator: PlatformFlags.isIOSSimulator,
      );
    }

    return GoogleMap(
      style: mapStyle,
      initialCameraPosition: CameraPosition(target: initialTarget, zoom: 15),
      markers: markers,
      polylines: polylines,
      myLocationEnabled:
          myLocationEnabled && !PlatformFlags.disableGoogleMapsMyLocationLayer,
      myLocationButtonEnabled: false,
      compassEnabled: false,
      mapToolbarEnabled: false,
      zoomControlsEnabled: false,
      onMapCreated: onMapCreated ?? (_) {},
    );
  }
}

class _MapPlaceholder extends StatelessWidget {
  const _MapPlaceholder({
    required this.center,
    required this.markers,
    required this.hasRoute,
    required this.isSimulator,
  });

  final LatLng center;
  final Set<Marker> markers;
  final bool hasRoute;
  final bool isSimulator;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.primary,
      child: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: _GridPainter(),
            ),
          ),
          Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 360),
                child: Material(
                  color: AppColors.surface,
                  elevation: 4,
                  borderRadius: BorderRadius.circular(16),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.map_outlined, color: AppColors.accent, size: 28),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                isSimulator
                                    ? 'Map preview (simulator)'
                                    : 'Map preview (desktop)',
                                style: AppTextStyles.headingSm,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          isSimulator
                              ? 'Google Maps can crash on the iOS simulator. Use a physical iPhone for live maps — you can still go online and accept trips here.'
                              : 'Live Google Maps runs on iOS and Android. On macOS you can still go online and handle trips.',
                          style: AppTextStyles.bodySecondary,
                        ),
                        const SizedBox(height: 16),
                        Text('Center', style: AppTextStyles.label),
                        Text(
                          '${center.latitude.toStringAsFixed(5)}, ${center.longitude.toStringAsFixed(5)}',
                          style: AppTextStyles.body,
                        ),
                        if (hasRoute) ...[
                          const SizedBox(height: 8),
                          Text(
                            'Route polyline ready',
                            style: AppTextStyles.body.copyWith(color: AppColors.accent),
                          ),
                        ],
                        if (markers.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Text('Pins', style: AppTextStyles.label),
                          const SizedBox(height: 4),
                          ...markers.map(
                            (m) => Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Text(
                                '• ${m.infoWindow.title ?? m.markerId.value}',
                                style: AppTextStyles.bodySecondary,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.divider
      ..strokeWidth = 1;
    const step = 48.0;
    for (var x = 0.0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (var y = 0.0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
