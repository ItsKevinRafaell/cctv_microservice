// lib/app/di.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';

import 'package:anomeye/app/env.dart';
import 'package:anomeye/core/network/auth_interceptor.dart';

// Auth
import 'package:anomeye/features/auth/domain/auth_repo.dart';
import 'package:anomeye/features/auth/domain/auth_state.dart';
import 'package:anomeye/features/auth/presentation/auth_controller.dart';
import 'package:anomeye/features/auth/storage/secure_token_store.dart';

import 'package:anomeye/features/auth/data/auth_repo_impl.dart';
import 'package:anomeye/features/auth/data/auth_api.dart';

// Cameras & Anomalies (provider override point)
import 'package:anomeye/features/cameras/domain/cameras_repo.dart';
import 'package:anomeye/features/anomalies/domain/anomalies_repo.dart';

final envProvider = Provider<AppEnv>((_) => defaultEnv);

final tokenStoreProvider = Provider<SecureTokenStore>(
  // FIX: Berikan 'key' yang dibutuhkan oleh constructor
  (_) => SecureTokenStore('auth_token'),
);

// Holds the current auth bearer token to be read by interceptors without
// creating provider cycles with AuthState.
final authTokenProvider = StateProvider<String?>((_) => null);

// ===== Auth =====
final authRepoProvider = Provider<AuthRepo>((ref) {
  final store = ref.watch(tokenStoreProvider);
  final dio = ref.watch(dioProvider);
  return AuthRepoImpl(AuthApi(dio), store);
});

final authStateProvider =
    StateNotifierProvider<AuthController, AuthState>((ref) {
  final repo = ref.watch(authRepoProvider);
  final c = AuthController(repo, ref);
  c.bootstrap(); // load token awal
  return c;

});

// ===== Dio + Interceptor =====
final dioProvider = Provider<Dio>((ref) {
  final env = ref.watch(envProvider);
  final dio = Dio(BaseOptions(
    baseUrl: env.baseUrl,
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 20),
  ));
  dio.interceptors.add(AuthInterceptor(ref)); // saat ini no-op / bearer
  return dio;
});

// ===== Override points untuk Repos (Fake/API) =====
// NOTE: Repo ini HARUS dioverride di main.dart (ProviderScope.overrides)
final camerasRepoProviderOverride = Provider<CamerasRepo>((ref) {
  throw UnimplementedError(
      'Sambungkan CamerasRepo ke Fake/API sebelum dipakai');
});

final anomaliesRepoProviderOverride = Provider<AnomaliesRepo>((ref) {
  throw UnimplementedError(
      'Sambungkan AnomaliesRepo ke Fake/API sebelum dipakai');
});


