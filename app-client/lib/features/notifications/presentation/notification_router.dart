import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:go_router/go_router.dart';

/// Baca payload dan arahkan route.
/// Contoh payload: { "type": "anomaly", "anomaly_id": "123" }
void handleNotificationNavigation(GoRouter router, RemoteMessage msg) {
  final data = msg.data;
  final type = data['type'];

  if (type == 'anomaly' && data['anomaly_id'] != null) {
    router.go('/anomalies/${data['anomaly_id']}');
    return;
  }

  if (type == 'camera' && data['camera_id'] != null) {
    router.go('/camera/${data['camera_id']}');
    return;
  }

  // fallback
  router.go('/');
}

/// Pasang listener untuk onMessageOpenedApp & initialMessage
Future<void> wireNotificationNavigation(WidgetRef ref, GoRouter router) async {
  // jika app dibuka dari terminated via notif
  final initial = await FirebaseMessaging.instance.getInitialMessage();
  if (initial != null) {
    handleNotificationNavigation(router, initial);
  }

  // jika app dibuka dari background via notif
  FirebaseMessaging.onMessageOpenedApp.listen((msg) {
    handleNotificationNavigation(router, msg);
  });
}
