import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

enum ExternalNavApp { waze, googleMaps }

class ExternalNavigation {
  ExternalNavigation._();

  static Future<bool> _canLaunch(Uri uri) async {
    try {
      return await canLaunchUrl(uri);
    } catch (_) {
      return false;
    }
  }

  static Future<bool> isWazeInstalled() {
    return _canLaunch(Uri.parse('waze://'));
  }

  static Future<bool> isGoogleMapsInstalled() {
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return _canLaunch(Uri.parse('comgooglemaps://'));
    }
    if (defaultTargetPlatform == TargetPlatform.android) {
      return _canLaunch(Uri.parse('google.navigation:q=0,0'));
    }
    return Future.value(false);
  }

  static Uri wazeUri(double lat, double lng) {
    return Uri.parse('https://waze.com/ul?ll=$lat,$lng&navigate=yes');
  }

  static Uri googleMapsUri(double lat, double lng) {
    return Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng&travelmode=driving',
    );
  }

  static Future<bool> openWaze(double lat, double lng) {
    return launchUrl(wazeUri(lat, lng), mode: LaunchMode.externalApplication);
  }

  static Future<bool> openGoogleMaps(double lat, double lng) {
    return launchUrl(googleMapsUri(lat, lng), mode: LaunchMode.externalApplication);
  }

  static Future<void> openNavigation({
    required BuildContext context,
    required double lat,
    required double lng,
    String? destinationLabel,
  }) async {
    final wazeOk = await isWazeInstalled();
    final googleOk = await isGoogleMapsInstalled();

    if (!context.mounted) return;

    if (wazeOk && googleOk) {
      await showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        builder: (ctx) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Open navigation',
                  style: Theme.of(ctx).textTheme.titleMedium,
                  textAlign: TextAlign.center,
                ),
                if (destinationLabel != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    destinationLabel,
                    style: Theme.of(ctx).textTheme.bodySmall,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: 12),
                ListTile(
                  leading: const Icon(Icons.navigation_outlined),
                  title: const Text('Waze'),
                  onTap: () async {
                    Navigator.pop(ctx);
                    await openWaze(lat, lng);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.map_outlined),
                  title: const Text('Google Maps'),
                  onTap: () async {
                    Navigator.pop(ctx);
                    await openGoogleMaps(lat, lng);
                  },
                ),
              ],
            ),
          ),
        ),
      );
      return;
    }

    if (wazeOk) {
      await openWaze(lat, lng);
      return;
    }

    await openGoogleMaps(lat, lng);
  }
}
