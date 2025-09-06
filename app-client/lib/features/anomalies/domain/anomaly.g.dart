// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'anomaly.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$AnomalyImpl _$$AnomalyImplFromJson(Map<String, dynamic> json) =>
    _$AnomalyImpl(
      id: json['id'] as String,
      cameraId: json['cameraId'] as String,
      anomalyType: json['anomalyType'] as String,
      confidence: (json['confidence'] as num).toDouble(),
      videoClipUrl: json['videoClipUrl'] as String?,
      reportedAt: DateTime.parse(json['reportedAt'] as String),
    );

Map<String, dynamic> _$$AnomalyImplToJson(_$AnomalyImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'cameraId': instance.cameraId,
      'anomalyType': instance.anomalyType,
      'confidence': instance.confidence,
      'videoClipUrl': instance.videoClipUrl,
      'reportedAt': instance.reportedAt.toIso8601String(),
    };
