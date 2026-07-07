import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';

class PlatformFlags {
  PlatformFlags._();

  static const MethodChannel _channel = MethodChannel('etrike/platform');

  static bool _initialized = false;
  static bool _isIOSSimulator = false;

  static bool get isIOSSimulator => _isIOSSimulator;

  static bool get disableGoogleMapsMyLocationLayer {
    if (kIsWeb) return false;
    return Platform.isIOS && _isIOSSimulator;
  }

  static Future<void> initialize() async {
    if (_initialized || kIsWeb) return;
    _initialized = true;

    if (!Platform.isIOS) return;

    try {
      final result = await _channel.invokeMethod<bool>('isSimulator');
      _isIOSSimulator = result ?? false;
    } catch (_) {
      _isIOSSimulator = false;
    }
  }
}

