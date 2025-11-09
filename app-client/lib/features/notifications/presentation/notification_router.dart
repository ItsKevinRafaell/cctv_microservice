import 'package:anomeye/features/anomalies/presentation/anomaly_read_controller.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Baca payload dan arahkan route.
/// Contoh payload: { "type": "anomaly", "anomaly_id": "123" }
void handleNotificationNavigation(
  WidgetRef ref,
  GoRouter router,
  RemoteMessage msg,
) {
  final data = msg.data;
  final type = data['type'];
  final anomalyId = data['anomaly_id']?.toString();
  final cameraId = data['camera_id']?.toString();

  if (anomalyId != null && anomalyId.isNotEmpty) {
    ref.read(anomalyReadControllerProvider.notifier).markRead(anomalyId);
  }

  if (type == 'anomaly' || anomalyId != null) {
    if (cameraId != null && cameraId.isNotEmpty) {
      router.go('/live/$cameraId');
    } else if (anomalyId != null && anomalyId.isNotEmpty) {
      router.go('/anomalies/$anomalyId');
    } else {
      router.go('/');
    }
    return;
  }

  if (type == 'camera' && cameraId != null && cameraId.isNotEmpty) {
    router.go('/live/$cameraId');
    return;
  }

  router.go('/');
}

/// Pasang listener untuk onMessageOpenedApp & initialMessage
Future<void> wireNotificationNavigation(WidgetRef ref, GoRouter router) async {
  // jika app dibuka dari terminated via notif
  final initial = await FirebaseMessaging.instance.getInitialMessage();
  if (initial != null) {
    handleNotificationNavigation(ref, router, initial);
  }

  // jika app dibuka dari background via notif
  FirebaseMessaging.onMessageOpenedApp.listen((msg) {
    handleNotificationNavigation(ref, router, msg);
  });
}
