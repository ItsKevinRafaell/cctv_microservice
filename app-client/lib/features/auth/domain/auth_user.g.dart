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
      name: json['name'] as String?,
      jobTitle: json['jobTitle'] as String?,
      phone: json['phone'] as String?,
      avatarUrl: json['avatarUrl'] as String?,
    );

Map<String, dynamic> _$$AuthUserImplToJson(_$AuthUserImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'email': instance.email,
      'companyId': instance.companyId,
      'role': instance.role,
      'fcmToken': instance.fcmToken,
      'name': instance.name,
      'jobTitle': instance.jobTitle,
      'phone': instance.phone,
      'avatarUrl': instance.avatarUrl,
    };
