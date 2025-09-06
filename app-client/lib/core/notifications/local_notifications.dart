import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/foundation.dart';

class LocalNotifications {
  static final _fln = FlutterLocalNotificationsPlugin();
  static const _channelId = 'anomeye_alerts';
  static const _channelName = 'AnomEye Alerts';
  static const _channelDesc = 'Alerts & anomaly notifications';

  static bool _inited = false;

  static Future<void> init() async {
    if (_inited) return;

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidInit);
    await _fln.initialize(initSettings);

    // Create channel on Android (idempotent)
    const androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDesc,
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
      ticker: 'AnomEye',
    );
    // Warm up by showing a silent test (not displayed if not used)
    if (kDebugMode) {
      // no-op: channel will be created on first show
    }
    _inited = true;
  }

  static Future<void> show({required String title, required String body}) async {
    const androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDesc,
      importance: Importance.high,
      priority: Priority.high,
    );
    const notifDetails = NotificationDetails(android: androidDetails);
    await _fln.show(DateTime.now().millisecondsSinceEpoch ~/ 1000, title, body, notifDetails);
  }
}

