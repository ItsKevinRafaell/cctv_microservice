import 'dart:async';
import 'package:anomeye/app/di.dart';
import 'package:anomeye/features/auth/domain/auth_repo.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:anomeye/features/auth/storage/secure_token_store.dart';
import 'package:anomeye/features/notifications/data/fcm_service.dart';

class FcmState {
  final String? token;
  final bool permissionGranted;

  const FcmState({this.token, this.permissionGranted = false});

  FcmState copyWith({String? token, bool? permissionGranted}) => FcmState(
        token: token ?? this.token,
        permissionGranted: permissionGranted ?? this.permissionGranted,
      );
}

final fcmServiceProvider = Provider<FcmService>((ref) {
  return FcmService(FirebaseMessaging.instance);
});

final fcmControllerProvider =
    StateNotifierProvider<FcmController, FcmState>((ref) {
  final service = ref.watch(fcmServiceProvider);
  final store = ref.watch(secureFcmStoreProvider);
  // Tambahkan AuthRepo untuk bisa memanggil API backend
  final authRepo = ref.watch(authRepoProvider);
  return FcmController(service, store, authRepo);
});

final secureFcmStoreProvider = Provider<SecureTokenStore>((_) {
  return SecureTokenStore('fcm_token');
});

class FcmController extends StateNotifier<FcmState> {
  final FcmService _service;
  final SecureTokenStore _store;
  final AuthRepo _authRepo; // Tambahkan AuthRepo
  StreamSubscription<String>? _sub;

  FcmController(this._service, this._store, this._authRepo) : super(const FcmState());

  Future<void> init() async {
    // Request notification permissions
    final settings = await _service.requestPermission();
    final permissionGranted =
        settings.authorizationStatus == AuthorizationStatus.authorized ||
            settings.authorizationStatus == AuthorizationStatus.provisional;

    // Get the FCM token
    String? token;
    if (permissionGranted) {
      token = await _service.getToken();
      // Store token securely
      if (token != null) {
        await _store.save(token);
      }

      // Listen for token refreshes
      _sub?.cancel();
      _sub = _service.onTokenRefresh().listen((newToken) async {
        await _store.save(newToken);
        state = state.copyWith(token: newToken);
        // Update token on backend if user is logged in
        await _authRepo.upsertFcmToken(newToken);
      });
    } else {
      // Clear token if permissions are revoked
      await _store.clear();
      token = null;
    }

    // Update state with permission status and token
    state = state.copyWith(
      permissionGranted: permissionGranted,
      token: token,
    );
  }

  Future<void> clear() async {
    _sub?.cancel();
    _sub = null;
    await _store.clear();
    state = const FcmState();
  }

  /// Dipanggil setelah user berhasil login
  Future<void> registerIfPossible() async {
    await init();
    print('[FCM] permission=${state.permissionGranted}, token=${state.token}');
    final currentToken = state.token;
    if (currentToken != null) {
      // Panggil API untuk mengirim token ke backend
      await _authRepo.upsertFcmToken(currentToken);
    }
  }

  /// Dipanggil sebelum user logout
  Future<void> unregisterFromBackend() async {
    await _authRepo.deleteFcmToken();
  }
}
