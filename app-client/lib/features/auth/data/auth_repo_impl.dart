import 'package:anomeye/features/auth/data/auth_api.dart';
import 'package:anomeye/features/auth/domain/auth_repo.dart';
import 'package:anomeye/features/auth/domain/auth_state.dart';
import 'package:anomeye/features/auth/domain/auth_user.dart';
import 'package:anomeye/features/auth/storage/secure_token_store.dart';
import 'package:dio/dio.dart';

class AuthRepoImpl implements AuthRepo {
  final AuthApi api;
  final SecureTokenStore store;
  final String baseUrl; // for direct authed calls without provider cycles
  String? _fcm;
  AuthRepoImpl(this.api, this.store, this.baseUrl);

  @override
  Future<void> signOut() async {
    await store.clear();
  }

  @override
  Future<AuthState> readToken() async {
    final t = await store.read();
    if (t == null) return const AuthState.unauthenticated();
    // Guard: drop leftover fake tokens from previous dev mode
    if (t.startsWith('fake-')) {
      await store.clear();
      return const AuthState.unauthenticated();
    }
    // TODO: optionally call /me untuk dapat user
    return AuthState.authenticated(
      token: t,
      user: const AuthUser(
          id: 1, email: 'unknown@local', companyId: 1, role: 'user'),
    );
  }

  @override
  Future<AuthState> signIn(
      {required String email, required String password}) async {
    final (token, user) = await api.signIn(email, password);
    await store.save(token);
    return AuthState.authenticated(token: token, user: user);
  }

  @override
  Future<AuthState> signUp(
      {required String email,
      required String password,
      required String companyId}) async {
    // TODO: implement signUp
    final (token, user) = await api.signUp(
      email: email,
      password: password,
      companyId: companyId,
    );
    await store.save(token);
    return AuthState.authenticated(token: token, user: user);
  }

  @override
  Future<void> upsertFcmToken(String token) async {
    // Make a direct authed call using stored JWT to avoid provider dependency cycles
    try {
      final jwt = await store.read();
      if (jwt == null) {
        _fcm = token;
        return;
      }
      final dio = Dio(BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 20),
        headers: {'Authorization': 'Bearer $jwt'},
      ));
      await dio.post('/api/users/fcm-token', data: {'fcm_token': token});
      _fcm = token;
    } catch (_) {
      _fcm = token; // keep local copy; non-critical failure
    }
  }

  @override
  Future<void> deleteFcmToken() async {
    try {
      final jwt = await store.read();
      if (jwt != null) {
        final dio = Dio(BaseOptions(
          baseUrl: baseUrl,
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 20),
          headers: {'Authorization': 'Bearer $jwt'},
        ));
        await dio.delete('/api/users/fcm-token');
      }
    } catch (_) {}
    _fcm = null;
  }
}
