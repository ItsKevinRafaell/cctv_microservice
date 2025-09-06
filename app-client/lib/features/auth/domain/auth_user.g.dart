// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'auth_user.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$AuthUserImpl _$$AuthUserImplFromJson(Map<String, dynamic> json) =>
    _$AuthUserImpl(
      id: (json['id'] as num).toInt(),
      email: json['email'] as String,
      companyId: (json['companyId'] as num).toInt(),
      role: json['role'] as String,
      fcmToken: json['fcmToken'] as String?,
    );

Map<String, dynamic> _$$AuthUserImplToJson(_$AuthUserImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'email': instance.email,
      'companyId': instance.companyId,
      'role': instance.role,
      'fcmToken': instance.fcmToken,
    };
