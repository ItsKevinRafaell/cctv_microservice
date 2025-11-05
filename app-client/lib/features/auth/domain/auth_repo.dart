import 'package:anomeye/features/auth/domain/auth_state.dart';
import 'package:anomeye/features/auth/domain/auth_user.dart';

abstract class AuthRepo {
  Future<AuthState> readToken();
  Future<AuthState> signIn({required String email, required String password});
  Future<AuthState> signUp({
    required String email,
    required String password,
    required String companyId,
  });
  Future<void> signOut();

  Future<void> upsertFcmToken(String token);
  Future<void> deleteFcmToken();

  Future<AuthUser> fetchProfile();
  Future<AuthUser> updateProfile({
    String? name,
    String? jobTitle,
    String? phone,
    String? avatarUrl,
  });
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  });
}
