import 'package:freezed_annotation/freezed_annotation.dart';
part 'anomaly.freezed.dart';
part 'anomaly.g.dart';

@freezed
class Anomaly with _$Anomaly {
  const factory Anomaly({
    required String id, // pakai String agar fleksibel (int/uuid)
    required String cameraId, // "cam1"
    required String anomalyType, // "intrusion", dst
    required double confidence, // 0.0 - 1.0
    String? videoClipUrl, // optional bukti
    required DateTime reportedAt, // ISO8601
  }) = _Anomaly;

  factory Anomaly.fromJson(Map<String, dynamic> json) =>
      _$AnomalyFromJson(json);
}
