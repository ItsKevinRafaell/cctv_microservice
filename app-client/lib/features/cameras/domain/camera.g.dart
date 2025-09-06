// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'camera.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$CameraImpl _$$CameraImplFromJson(Map<String, dynamic> json) => _$CameraImpl(
      id: json['id'] as String,
      name: json['name'] as String,
      location: json['location'] as String?,
      online: json['online'] as bool? ?? false,
      activeAlerts: (json['activeAlerts'] as num?)?.toInt() ?? 0,
      streamUrl: json['streamUrl'] as String?,
    );

Map<String, dynamic> _$$CameraImplToJson(_$CameraImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'location': instance.location,
      'online': instance.online,
      'activeAlerts': instance.activeAlerts,
      'streamUrl': instance.streamUrl,
    };
