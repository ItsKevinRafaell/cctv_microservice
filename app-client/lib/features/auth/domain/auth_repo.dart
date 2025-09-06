import 'package:anomeye/features/auth/domain/auth_state.dart';

abstract class AuthRepo {
  Future<AuthState> readToken();
  Future<AuthState> signIn({required String email, required String password});
  Future<AuthState> signUp({
    required String email,
    required String password,
    required String companyId,
  });
  Future<void> signOut();

  // NEW
  Future<void> upsertFcmToken(String token); // simpan/update token ke backend
  Future<void> deleteFcmToken(); // opsional: hapus saat logout
}
