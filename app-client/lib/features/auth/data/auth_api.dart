import 'package:dio/dio.dart';
import 'package:anomeye/features/auth/domain/auth_user.dart';

class AuthApi {
  final Dio _dio;
  AuthApi(this._dio);

  Future<(String, AuthUser)> signIn(String email, String password) async {
    // Backend: POST /api/login -> { token }
    final r = await _dio.post(
      '/api/login',
      data: {'email': email, 'password': password},
    );
    final token = (r.data is Map) ? (r.data['token'] as String) : '';
    // If backend doesn't return user, construct minimal user from email
    final user = AuthUser(
      id: 0,
      email: email,
      companyId: 0,
      role: 'user',
    );
    return (token, user);
  }

  Future<(String, AuthUser)> signUp({
    required String email,
    required String password,
    required String companyId,
  }) async {
    // Backend: POST /api/register { email, password, company_id }
    final r = await _dio.post(
      '/api/register',
      data: {
        'email': email,
        'password': password,
        'company_id': companyId,
      },
    );
    // Some backends return token on register, otherwise fallback to login
    String? token;
    AuthUser user = AuthUser(id: 0, email: email, companyId: int.tryParse(companyId) ?? 0, role: 'user');
    if (r.data is Map && r.data['token'] is String) {
      token = r.data['token'] as String;
      // If user object exists, parse; otherwise keep minimal
      final u = (r.data['user']);
      if (u is Map) {
        final m = u.cast<String, dynamic>();
        user = AuthUser(
          id: (m['id'] as num?)?.toInt() ?? 0,
          email: (m['email'] as String?) ?? email,
          companyId: (m['company_id'] as num?)?.toInt() ?? user.companyId,
          role: (m['role'] as String?) ?? 'user',
        );
      }
      return (token, user);
    }
    // Fallback: login after register
    final (tkn, usr) = await signIn(email, password);
    return (tkn, usr);
  }

  Future<void> upsertFcmToken(String token) async {
    // Backend: POST /api/users/fcm-token { fcm_token }
    await _dio.post(
      '/api/users/fcm-token',
      data: {'fcm_token': token},
    );
  }

  Future<void> deleteFcmToken() async {
    // Optional backend support; if unavailable, no-op
    try {
      await _dio.delete('/api/users/fcm-token');
    } on DioException {
      // ignore
    }
  }
}
