import 'dart:async';
import 'package:anomeye/features/auth/domain/auth_repo.dart';
import 'package:anomeye/features/auth/domain/auth_state.dart';
import 'package:anomeye/features/auth/domain/auth_user.dart';
import 'package:anomeye/features/auth/storage/secure_token_store.dart';

class AuthRepoFake implements AuthRepo {
  final SecureTokenStore _store;
  AuthUser? _user;
  AuthRepoFake(this._store);

  @override
  Future<AuthState> readToken() async {
    final t = await _store.read();
    if (t == null) return const AuthState.unauthenticated();
    _user ??= AuthUser(
      id: 1,
      email: 'admin@ujicoba.com',
      companyId: 1,
      role: 'company_admin',
      name: 'Admin Demo',
      jobTitle: 'Security Lead',
      phone: '+62-812-0000-1111',
    );
    return AuthState.authenticated(token: t, user: _user!);
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
    _user = AuthUser(
      id: 1,
      email: email,
      companyId: 1,
      role: 'company_admin',
      name: 'Demo Admin',
      jobTitle: 'Security Lead',
      phone: '+62-812-0000-1111',
    );
    return AuthState.authenticated(token: token, user: _user!);
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
    _user = null;
  }

  @override
  Future<void> upsertFcmToken(String token) async {
    await Future.delayed(const Duration(milliseconds: 50));
  }

  @override
  Future<void> deleteFcmToken() async {
    await Future.delayed(const Duration(milliseconds: 50));
  }

  @override
  Future<AuthUser> fetchProfile() async {
    final state = await readToken();
    return state.when(
      unauthenticated: () => throw Exception('Not authenticated'),
      authenticated: (_, user) => user,
    );
  }

  @override
  Future<AuthUser> updateProfile({
    String? name,
    String? jobTitle,
    String? phone,
    String? avatarUrl,
  }) async {
    _user = (_user ??
            AuthUser(
              id: 1,
              email: 'admin@ujicoba.com',
              companyId: 1,
              role: 'company_admin',
            ))
        .copyWith(
      name: name ?? _user?.name,
      jobTitle: jobTitle ?? _user?.jobTitle,
      phone: phone ?? _user?.phone,
      avatarUrl: avatarUrl ?? _user?.avatarUrl,
    );
    return _user!;
  }

  @override
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    await Future.delayed(const Duration(milliseconds: 150));
  }
}
