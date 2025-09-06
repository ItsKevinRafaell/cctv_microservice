import 'package:freezed_annotation/freezed_annotation.dart';
part 'recording.freezed.dart';
part 'recording.g.dart';

@freezed
class Recording with _$Recording {
  const factory Recording({
    required String cameraId,
    required DateTime startedAt,
    required DateTime endedAt,
    required String key, // s3_key
    required int sizeBytes,
    String? url, // presigned (opsional)
  }) = _Recording;

  factory Recording.fromJson(Map<String, dynamic> json) =>
      _$RecordingFromJson(json);
}
