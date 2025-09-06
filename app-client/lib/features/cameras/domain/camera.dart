import 'package:freezed_annotation/freezed_annotation.dart';
part 'camera.freezed.dart';
part 'camera.g.dart';

@freezed
class Camera with _$Camera {
  const factory Camera({
    required String id, // contoh: "cam1"
    required String name, // "Lobby - Cam 1"
    String? location, // nullable -> sesuai backend
    @Default(false) bool online,
    @Default(0) int activeAlerts,
    String? streamUrl, // HLS/RTC nanti
  }) = _Camera;

  factory Camera.fromJson(Map<String, dynamic> json) => _$CameraFromJson(json);
}
