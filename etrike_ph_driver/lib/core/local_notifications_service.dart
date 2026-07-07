import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'constants/app_strings.dart';

typedef ChatNotificationTapHandler = void Function(String tripId);

/// Local notifications for trips and chat (FCM can extend this later).
abstract final class LocalNotificationsService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static ChatNotificationTapHandler? onChatMessageTap;

  static const AndroidNotificationChannel _tripChannel = AndroidNotificationChannel(
    'sulong_ride_driver_trips',
    'Sulong Ride — Trips',
    description: 'Trip request alerts',
    importance: Importance.max,
  );

  static const AndroidNotificationChannel _chatChannel = AndroidNotificationChannel(
    'sulong_ride_driver_chat',
    'Sulong Ride — Messages',
    description: 'Chat messages during active trips',
    importance: Importance.max,
  );

  static Future<void> initialize() async {
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
      defaultPresentAlert: true,
      defaultPresentBadge: true,
      defaultPresentSound: true,
      defaultPresentBanner: true,
      defaultPresentList: true,
    );
    const macOS = DarwinInitializationSettings();
    await _plugin.initialize(
      const InitializationSettings(
        android: android,
        iOS: ios,
        macOS: macOS,
      ),
      onDidReceiveNotificationResponse: _onTap,
    );
    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.createNotificationChannel(_tripChannel);
    await androidPlugin?.createNotificationChannel(_chatChannel);
    await androidPlugin?.requestNotificationsPermission();

    final iosPlugin = _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    await iosPlugin?.requestPermissions(alert: true, badge: true, sound: true);
  }

  static void _onTap(NotificationResponse response) {
    final tripId = response.payload;
    if (tripId != null && tripId.isNotEmpty) {
      onChatMessageTap?.call(tripId);
    }
  }

  static Future<void> showIncomingTrip() async {
    await _plugin.show(
      2001,
      'New trip request',
      'Open ${AppStrings.brandName} to accept or decline.',
      NotificationDetails(
        android: AndroidNotificationDetails(
          _tripChannel.id,
          _tripChannel.name,
          channelDescription: _tripChannel.description,
          importance: Importance.max,
          priority: Priority.high,
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
          presentBanner: true,
          presentList: true,
          interruptionLevel: InterruptionLevel.active,
        ),
        macOS: const DarwinNotificationDetails(),
      ),
    );
  }

  static Future<void> showChatMessage({
    required int notificationId,
    required String title,
    required String body,
    required String tripId,
  }) async {
    await _plugin.show(
      notificationId,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _chatChannel.id,
          _chatChannel.name,
          channelDescription: _chatChannel.description,
          importance: Importance.max,
          priority: Priority.high,
          category: AndroidNotificationCategory.message,
          visibility: NotificationVisibility.public,
          styleInformation: BigTextStyleInformation(
            body,
            contentTitle: title,
          ),
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
          presentBanner: true,
          presentList: true,
          interruptionLevel: InterruptionLevel.active,
        ),
        macOS: const DarwinNotificationDetails(),
      ),
      payload: tripId,
    );
  }
}
