import 'package:dio/dio.dart';
import 'package:anomeye/features/auth/domain/auth_user.dart';

class AuthApi {
  final Dio _dio;
  AuthApi(this._dio);

  Future<(String, AuthUser)> signIn(String email, String password) async {
    final r = await _dio.post('/api/login', data: {'email': email, 'password': password});
    final token = (r.data['token'] ?? '') as String;
    AuthUser user;
    if (r.data['user'] is Map<String, dynamic>) {
      user = AuthUser.fromJson(r.data['user'] as Map<String, dynamic>);
    } else {
      user = AuthUser(id: 0, email: email, companyId: 0, role: 'company_admin');
    }
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

  Future<AuthUser> fetchProfile() async {
    final r = await _dio.get('/api/users/me');
    if (r.data is Map<String, dynamic>) {
      return AuthUser.fromJson(r.data as Map<String, dynamic>);
    }
    throw DioException.badResponse(
      requestOptions: r.requestOptions,
      response: r,
      statusCode: r.statusCode ?? 500,
    );
  }

  Future<AuthUser> updateProfile({
    String? name,
    String? jobTitle,
    String? phone,
    String? avatarUrl,
  }) async {
    final payload = <String, dynamic>{};
    if (name != null) payload['name'] = name;
    if (jobTitle != null) payload['job_title'] = jobTitle;
    if (phone != null) payload['phone'] = phone;
    if (avatarUrl != null) payload['avatar_url'] = avatarUrl;

    final r = await _dio.patch('/api/users/me', data: payload);
    if (r.data is Map<String, dynamic>) {
      return AuthUser.fromJson(r.data as Map<String, dynamic>);
    }
    throw DioException.badResponse(
      requestOptions: r.requestOptions,
      response: r,
      statusCode: r.statusCode ?? 500,
    );
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    await _dio.post('/api/users/change-password', data: {
      'current_password': currentPassword,
      'new_password': newPassword,
    });
  }
}
