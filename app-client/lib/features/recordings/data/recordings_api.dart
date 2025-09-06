import 'package:dio/dio.dart';
import 'package:anomeye/features/recordings/domain/recording.dart';

class RecordingsApi {
  final Dio _dio;
  RecordingsApi(this._dio);

  Future<List<Recording>> list(
    String cameraId, {
    DateTime? from,
    DateTime? to,
    bool presign = true,
  }) async {
    final resp = await _dio.get(
      '/api/cameras/$cameraId/recordings',
      queryParameters: {
        if (from != null) 'from': from.toUtc().toIso8601String(),
        if (to != null) 'to': to.toUtc().toIso8601String(),
        'presign': presign ? '1' : '0',
      },
    );

    // backend shape:
    // { camera_id, from, to, count, items: [ {key,size,url?}, ... ] }
    final cameraIdResp = (resp.data['camera_id'] as String?) ?? cameraId;
    final items =
        (resp.data['items'] as List<dynamic>).cast<Map<String, dynamic>>();

    // API tidak mengirim started_at/ended_at; derive dari key:
    final List<Recording> result = [];
    for (final m in items) {
      final key = m['key'] as String;
      final size = (m['size'] as num?)?.toInt() ?? 0;
      final url = m['url'] as String?;

      // key pola: cam1_YYYYMMDD_HHMMSS.mp4 (segment 60s default)
      final ts = key.split('_').last.replaceAll('.mp4', ''); // YYYYMMDD_HHMMSS
      DateTime? start;
      try {
        start = DateTime.parse(
          ts.replaceFirst('_', 'T'), // YYYYMMDDTHHMMSS
        );
      } catch (_) {}
      start ??= DateTime.now().toUtc();
      final end = start.add(const Duration(seconds: 60));

      result.add(Recording(
        cameraId: cameraIdResp,
        startedAt: start.toUtc(),
        endedAt: end.toUtc(),
        key: key,
        sizeBytes: size,
        url: url,
      ));
    }
    // urut terbaru di atas
    result.sort((a, b) => b.startedAt.compareTo(a.startedAt));
    return result;
  }
}
