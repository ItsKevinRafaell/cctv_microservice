import 'package:dio/dio.dart';
import 'package:anomeye/features/auth/domain/auth_user.dart';

class AuthApi {
  final Dio _dio;
  AuthApi(this._dio);

  Future<(String, AuthUser)> signIn(String email, String password) async {
    final r = await _dio.post('/api/login', data: {'email': email, 'password': password});
    final token = (r.data['token'] ?? '') as String;
    final user = AuthUser(id: 0, email: email, companyId: 0, role: 'company_admin');
    return (token, user);
  }

  Future<(String, AuthUser)> signUp({
    required String email,
    required String password,
    required String companyId,
  }) async {
    // Backend register endpoint returns 201 without token; follow-up with login
    await _dio.post('/api/register', data: {
      'email': email,
      'password': password,
      'company_id': int.tryParse(companyId) ?? 1,
      'role': 'company_admin',
    });
    return signIn(email, password);
  }

  Future<void> upsertFcmToken(String token) async {
    await _dio.post('/api/users/fcm-token', data: {
      'fcm_token': token,
    });
  }

  Future<void> deleteFcmToken() async {
    // Send empty string to clear token on backend
    await _dio.post('/api/users/fcm-token', data: {
      'fcm_token': ''
    });
  }
}
