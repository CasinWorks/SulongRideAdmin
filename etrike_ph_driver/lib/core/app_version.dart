import 'package:package_info_plus/package_info_plus.dart';

abstract final class AppVersion {
  static Future<String> label() async {
    final info = await PackageInfo.fromPlatform();
    return '${info.version} (${info.buildNumber})';
  }
}
