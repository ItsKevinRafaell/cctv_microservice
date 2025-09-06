import 'dart:async';
import 'package:anomeye/features/auth/domain/auth_repo.dart';
import 'package:anomeye/features/auth/domain/auth_state.dart';
import 'package:anomeye/features/auth/domain/auth_user.dart';
import 'package:anomeye/features/auth/storage/secure_token_store.dart';

class AuthRepoFake implements AuthRepo {
  final SecureTokenStore _store;
  String? _fcm; // simpan lokal (dummy)
  AuthRepoFake(this._store);

  @override
  Future<AuthState> readToken() async {
    final t = await _store.read();
    if (t == null) return const AuthState.unauthenticated();
    // user dummy
    final u = AuthUser(
        id: 1,
        email: 'admin@ujicoba.com',
        companyId: 1,
        role: 'company_admin',
        fcmToken: _fcm);
    return AuthState.authenticated(token: t, user: u);
  }

  @override
  Future<AuthState> signIn(
      {required String email, required String password}) async {
    await Future.delayed(const Duration(milliseconds: 400));
    if (email.isEmpty || password.length < 3) {
      throw Exception('Invalid credential');
    }
    final token = 'fake-${DateTime.now().millisecondsSinceEpoch}';
    await _store.save(token);
    final u = AuthUser(
        id: 1,
        email: email,
        companyId: 1,
        role: 'company_admin',
        fcmToken: _fcm);
    return AuthState.authenticated(token: token, user: u);
  }

  @override
  Future<AuthState> signUp({
    required String email,
    required String password,
    required String companyId,
  }) async {
    // Anggap sama seperti signIn untuk dummy
    return signIn(email: email, password: password);
  }

  @override
  Future<void> signOut() async {
    await _store.clear();
  }

  @override
  Future<void> upsertFcmToken(String token) async {
    await Future.delayed(const Duration(milliseconds: 100));
    _fcm = token;
  }

  @override
  Future<void> deleteFcmToken() async {
    await Future.delayed(const Duration(milliseconds: 100));
    _fcm = null;
  }
}
