import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:anomeye/features/auth/domain/auth_user.dart';
part 'auth_state.freezed.dart';

@freezed
class AuthState with _$AuthState {
  const factory AuthState.unauthenticated() = _Unauthenticated;
  const factory AuthState.authenticated({
    required String token,
    required AuthUser user,
  }) = _Authenticated;
}
