import 'package:anomeye/app/di.dart';
import 'package:anomeye/app/env.dart';
import 'package:anomeye/features/anomalies/data/anomalies_repo_api.dart';
import 'package:anomeye/features/anomalies/data/anomalies_repo_fake.dart';
import 'package:anomeye/features/anomalies/presentation/anomaly_controllers.dart';
import 'package:anomeye/features/auth/domain/auth_state.dart';
import 'package:anomeye/features/cameras/data/cameras_repo_api.dart';
import 'package:anomeye/features/cameras/data/cameras_repo_fake.dart';
import 'package:anomeye/features/cameras/presentation/cameras_controller.dart';
import 'package:anomeye/features/notifications/data/fcm_service.dart';
import 'package:anomeye/features/notifications/presentation/fcm_controller.dart';
import 'package:anomeye/features/notifications/presentation/notification_router.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:anomeye/core/notifications/local_notifications.dart';
import 'package:flutter/foundation.dart';
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
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Background handler harus tetap di top-level
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  // Read dart-defines if provided
  const kApiBase = String.fromEnvironment('API_BASE_URL');
  const kHlsBase = String.fromEnvironment('HLS_BASE_URL');
  const kUseFake = bool.fromEnvironment('USE_FAKE', defaultValue: false);

  // Platform-aware defaults
  final isAndroid = !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
  final defaultApi = isAndroid ? 'http://10.0.2.2:8080' : 'http://localhost:8080';
  final defaultHls = isAndroid ? 'http://10.0.2.2:8888' : 'http://localhost:8888';
  final apiBase = (kApiBase.isNotEmpty) ? kApiBase : defaultApi;
  final hlsBase = (kHlsBase.isNotEmpty) ? kHlsBase : defaultHls;

  runApp(ProviderScope(
    overrides: [
      // Environment override
      envProvider.overrideWithValue(AppEnv(baseUrl: apiBase, mtxHlsBase: hlsBase)),

      // Repo wiring: use API by default, allow fakes via USE_FAKE=true
      if (kUseFake)
        camerasRepoProvider.overrideWithValue(CamerasRepoFake())
      else
        camerasRepoProvider.overrideWith((ref) =>
            CamerasRepoApi(ref.read(dioProvider), ref.read(envProvider).mtxHlsBase)),

      if (kUseFake)
        anomaliesRepoProvider.overrideWithValue(AnomaliesRepoFake())
      else
        anomaliesRepoProvider.overrideWith(
            (ref) => AnomaliesRepoApi(ref.read(dioProvider))),
    ],
    child: const AnomEyeApp(),
  ));
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
      // Bootstrap auth state (load token from secure storage)
      await ref.read(authStateProvider.notifier).bootstrap();
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

      // 2b. Inisialisasi local notifications & tampilkan notifikasi saat app foreground
      await LocalNotifications.init();
      FirebaseMessaging.onMessage.listen((msg) {
        final title = msg.notification?.title ?? '(no title)';
        final body = msg.notification?.body ?? '(no body)';
        LocalNotifications.show(title: title, body: body);
      });

      // 3. Listener auth dipasang di build() (lihat bawah) untuk menghindari CircularDependencyError
    });
  }

  @override
  Widget build(BuildContext context) {
    // Pasang listener perubahan auth di dalam build lifecycle (aman untuk Riverpod)
    ref.listen<AuthState>(authStateProvider, (prev, next) {
      next.maybeWhen(
        authenticated: (_, __) {
          ref.read(fcmControllerProvider.notifier).registerIfPossible();
        },
        orElse: () {},
      );
    });

    final router = ref.watch(appRouterProvider);
    return MaterialApp.router(
      scaffoldMessengerKey: scaffoldMessengerKey,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
      title: 'Anomeye',
    );
  }
}
