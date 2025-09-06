import 'dart:convert';
import 'package:anomeye/features/auth/data/auth_api.dart';
import 'package:anomeye/features/auth/domain/auth_repo.dart';
import 'package:anomeye/features/auth/domain/auth_state.dart';
import 'package:anomeye/features/auth/domain/auth_user.dart';
import 'package:anomeye/features/auth/storage/secure_token_store.dart';

class AuthRepoImpl implements AuthRepo {
  final AuthApi api;
  final SecureTokenStore store;
  String? _fcm;
  AuthRepoImpl(this.api, this.store);

  Map<String, dynamic>? _decodeClaims(String token) {
    try {
      final parts = token.split('.');
      if (parts.length < 2) return null;
      String normalized = parts[1].replaceAll('-', '+').replaceAll('_', '/');
      while (normalized.length % 4 != 0) {
        normalized += '=';
      }
      final payload = utf8.decode(base64.decode(normalized));
      return json.decode(payload) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> signOut() async {
    await store.clear();
  }

  @override
  Future<AuthState> readToken() async {
    final t = await store.read();
    if (t == null) return const AuthState.unauthenticated();
    final claims = _decodeClaims(t);
    if (claims != null) {
      final exp = claims['exp'];
      if (exp is num) {
        final expiresAt = DateTime.fromMillisecondsSinceEpoch(exp.toInt() * 1000);
        if (DateTime.now().isAfter(expiresAt)) {
          await store.clear();
          return const AuthState.unauthenticated();
        }
      }
      final email = (claims['email'] ?? claims['sub'] ?? '') as String;
      final role = (claims['role'] ?? 'user') as String;
      final cid = (claims['company_id'] is num) ? (claims['company_id'] as num).toInt() : 0;
      return AuthState.authenticated(
        token: t,
        user: AuthUser(
          id: (claims['user_id'] is num) ? (claims['user_id'] as num).toInt() : 0,
          email: email,
          companyId: cid,
          role: role,
        ),
      );
    }
    return const AuthState.unauthenticated();
  }

  @override
  Future<AuthState> signIn({required String email, required String password}) async {
    final (token, user) = await api.signIn(email, password);
    await store.save(token);
    return AuthState.authenticated(token: token, user: user);
  }

  @override
  Future<AuthState> signUp({required String email, required String password, required String companyId}) async {
    final (token, user) = await api.signUp(email: email, password: password, companyId: companyId);
    await store.save(token);
    return AuthState.authenticated(token: token, user: user);
  }

  @override
  Future<void> upsertFcmToken(String token) async {
    _fcm = token;
    await api.upsertFcmToken(token);
  }

  @override
  Future<void> deleteFcmToken() async {
    _fcm = null;
    await api.deleteFcmToken();
  }
}

