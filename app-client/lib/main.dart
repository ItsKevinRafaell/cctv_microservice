import 'package:anomeye/app/theme/app_theme.dart';
import 'package:anomeye/app/theme/theme_controller.dart';
import 'package:anomeye/features/notifications/data/fcm_service.dart';
import 'package:anomeye/features/notifications/presentation/notification_router.dart';
import 'package:anomeye/features/notifications/presentation/notification_preferences_controller.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:anomeye/app/router.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:anomeye/firebase_options.dart';

// GlobalKey tetap di sini
final scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

void main() async {
  // Hanya inisialisasi fundamental yang diletakkan di sini
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

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
        final title = msg.notification?.title ?? 'New alert';
        final body = msg.notification?.body ?? '';
        ref.read(notificationSoundPlayerProvider).playAlert();
        scaffoldMessengerKey.currentState?.showSnackBar(
          SnackBar(
            content: Text('$title - $body'),
            action: SnackBarAction(
              label: 'VIEW',
              onPressed: () => handleNotificationNavigation(ref, router, msg),
            ),
          ),
        );
      });

      // 2. Wire navigation untuk notifikasi
      await wireNotificationNavigation(ref, router);
    });
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(appRouterProvider);
    final themeMode = ref.watch(themeModeControllerProvider);
    return MaterialApp.router(
      scaffoldMessengerKey: scaffoldMessengerKey,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
      title: 'Anomeye',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      builder: (context, child) {
        final theme = Theme.of(context);
        final gradient = theme.brightness == Brightness.dark
            ? const LinearGradient(
                colors: [Color(0xFF1D1450), Color(0xFF101226)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : const LinearGradient(
                colors: [Color(0xFFE9F2FF), Color(0xFFD4E4FF)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              );
        return DecoratedBox(
          decoration: BoxDecoration(gradient: gradient),
          child: child,
        );
      },
    );
  }
}
