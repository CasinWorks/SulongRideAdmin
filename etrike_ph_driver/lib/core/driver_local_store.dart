import 'package:shared_preferences/shared_preferences.dart';

abstract final class DriverLocalStore {
  static const _onboardingCompleteKey = 'driver_onboarding_complete';
  static const _postApprovalWelcomePrefix = 'driver_post_approval_welcome_';
  static const _pushKey = 'driver_push_notifications';

  static Future<bool> onboardingComplete() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_onboardingCompleteKey) ?? false;
  }

  static Future<void> setOnboardingComplete(bool complete) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_onboardingCompleteKey, complete);
  }

  static Future<bool> postApprovalWelcomeComplete(String driverId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('$_postApprovalWelcomePrefix$driverId') ?? false;
  }

  static Future<void> setPostApprovalWelcomeComplete(
    String driverId, {
    required bool complete,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('$_postApprovalWelcomePrefix$driverId', complete);
  }

  static Future<bool> pushNotifications() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_pushKey) ?? true;
  }

  static Future<void> setPushNotifications(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_pushKey, value);
  }
}
