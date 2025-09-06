import 'package:anomeye/app/di.dart';
import 'package:anomeye/features/anomalies/presentation/anomaly_controllers.dart';
import 'package:anomeye/features/auth/domain/auth_state.dart';
import 'package:anomeye/features/cameras/presentation/cameras_controller.dart';
import 'package:anomeye/features/notifications/data/fcm_service.dart';
import 'package:anomeye/features/notifications/presentation/fcm_controller.dart';
import 'package:anomeye/features/notifications/presentation/notification_router.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:anomeye/app/router.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:anomeye/firebase_options.dart';
import 'package:media_kit/media_kit.dart';

// GlobalKey tetap di sini
final scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

void main() async {
  // Hanya inisialisasi fundamental yang diletakkan di sini
  WidgetsFlutterBinding.ensureInitialized();
  // Init media_kit before any Player is created (synchronous on Flutter)
  MediaKit.ensureInitialized();
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
      FirebaseMessaging.onMessage.listen((msg) {
        final title = msg.notification?.title ?? '(no title)';
        final body = msg.notification?.body ?? '(no body)';
        scaffoldMessengerKey.currentState?.showSnackBar(
          SnackBar(content: Text('Push FG: $title — $body')),
        );
      });

      // 2. Wire navigation untuk notifikasi
      final router = ref.read(appRouterProvider);
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
    );
  }
}
