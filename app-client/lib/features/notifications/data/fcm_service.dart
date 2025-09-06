// lib/features/notifications/data/fcm_service.dart
import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

/// Background handler WAJIB top-level (registrasi di main.dart)
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Inisialisasi ringan jika diperlukan
  await Firebase.initializeApp();
  // Bisa log / analytics di sini, navigasi jangan di sini
}

class FcmService {
  final FirebaseMessaging _fm;

  FcmService(this._fm);

  static Future<void> ensureInitialized() async {
    await Firebase.initializeApp();
  }

  Future<NotificationSettings> requestPermission() {
    return _fm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );
  }

  Future<String?> getToken() => _fm.getToken();

  Stream<String> onTokenRefresh() => _fm.onTokenRefresh;

  /// Listener pesan foreground
  Stream<RemoteMessage> onMessage() => FirebaseMessaging.onMessage;

  /// Listener ketika klik notifikasi (app dibuka dari background/terminated)
  Stream<RemoteMessage> onMessageOpenedApp() =>
      // FIX: Hapus tanda kurung () karena ini adalah getter, bukan method.
      FirebaseMessaging.onMessageOpenedApp;
}
