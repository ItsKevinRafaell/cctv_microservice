import 'package:anomeye/app/di.dart';
import 'package:anomeye/core/config/app_config.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final appConfigProvider = Provider<AppConfig>(
    (_) => const AppConfig(baseUrl: 'http://10.0.2.2:8080', useFake: true));

final dioProvider = Provider<Dio>((ref) {
  final cfg = ref.watch(appConfigProvider);
  final dio = Dio(BaseOptions(
    baseUrl: cfg.baseUrl,
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 20),
  ));

  dio.interceptors.add(
    InterceptorsWrapper(onRequest: (o, h) {
      final s = ref.read(authStateProvider);
      final token = s.maybeWhen(authenticated: (t, u) => t, orElse: () => null);
      if (token != null) o.headers['Authorization'] = 'Bearer $token';
      return h.next(o);
    }),
  );
  return dio;
});
