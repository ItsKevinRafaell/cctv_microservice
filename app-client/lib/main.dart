import 'package:anomeye/app/theme/app_theme.dart';
import 'package:anomeye/features/anomalies/presentation/anomaly_controllers.dart';
import 'package:anomeye/features/notifications/presentation/notification_router.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:anomeye/app/router.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:anomeye/firebase_options.dart';
import 'package:anomeye/features/notifications/data/fcm_service.dart';

// GlobalKey tetap di sini
final scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

void main() async {
  // Hanya inisialisasi fundamental yang diletakkan di sini
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Background handler harus tetap di top-level
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  // Gunakan default provider (API) untuk Cameras & Anomalies.
  runApp(const ProviderScope(child: AnomEyeApp()));
}

class AnomEyeApp extends ConsumerStatefulWidget {
  const AnomEyeApp({super.key});
  @override
  ConsumerState<AnomEyeApp> createState() => _AnomEyeAppState();
}

class _AnomEyeAppState extends ConsumerState<AnomEyeApp> {
  @override
  void initState() {
    super.initState();
    // Pindahkan semua setup yang berhubungan dengan state aplikasi ke sini
    _initializeAppLogic();
  }

  void _initializeAppLogic() {
    // Jalankan setelah frame pertama selesai di-build
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // 1. Dengarkan notifikasi foreground
      final router = ref.read(appRouterProvider);
      FirebaseMessaging.onMessage.listen((msg) {
        final title = msg.notification?.title ?? 'AnomEye Alert';
        final body = msg.notification?.body ?? '';
        final messenger = scaffoldMessengerKey.currentState;
        final messageText = body.isNotEmpty ? '$title\n$body' : title;
        final level = (msg.data['level'] ?? msg.data['severity'] ?? 'info').toString();
        messenger
          ?..clearSnackBars()
          ..showSnackBar(
            SnackBar(
              margin: const EdgeInsets.only(left: 16, right: 16, top: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              content: Text(messageText),
              duration: const Duration(seconds: 4),
              behavior: SnackBarBehavior.floating,
              backgroundColor: _toastColor(level),
            ),
          );

        // Refresh anomaly feeds so UI reflects latest detection.
        try {
          ref.invalidate(anomaliesListProvider(null));
          final cameraId = msg.data['camera_id'];
          if (cameraId is String && cameraId.isNotEmpty) {
            ref.invalidate(anomaliesListProvider(cameraId));
          }
        } catch (_) {
          // ignore if corresponding provider not listened yet
        }

        // Offer navigation to detail via toast tap is not possible,
        // so keep existing deep link via notification tap only.
      });

      // 2. Wire navigation untuk notifikasi
      await wireNotificationNavigation(ref, router);
    });
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(appRouterProvider);
    return MaterialApp.router(
      scaffoldMessengerKey: scaffoldMessengerKey,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
      title: 'Anomeye',
      theme: AppTheme.light,
    );
  }
}

Color _toastColor(String level) {
  switch (level.toLowerCase()) {
    case 'warning':
    case 'warn':
      return const Color(0xFFF79009);
    case 'error':
    case 'critical':
      return const Color(0xFFD92D20);
    case 'success':
      return const Color(0xFF039855);
    default:
      return const Color(0xFF0C4EA3);
  }
}

