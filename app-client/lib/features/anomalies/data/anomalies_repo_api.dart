import 'package:anomeye/features/anomalies/domain/anomalies_repo.dart';
import 'package:anomeye/features/anomalies/domain/anomaly.dart';
import 'package:dio/dio.dart';

class AnomaliesRepoApi implements AnomaliesRepo {
  final Dio _dio;
  AnomaliesRepoApi(this._dio);

  @override
  Future<List<Anomaly>> listRecent({String? cameraId, int limit = 50}) async {
    Response res;
    try {
      res = await _dio.get(
        '/api/anomalies/recent',
        queryParameters: {
          if (cameraId != null) 'camera_id': cameraId,
          'limit': limit,
        },
      );
    } on DioException catch (_) {
      // Fallback to /api/anomalies if /recent is unavailable
      res = await _dio.get(
        '/api/anomalies',
        queryParameters: {
          if (cameraId != null) 'camera_id': cameraId,
          'limit': limit,
        },
      );
    }

    final body = res.data;
    final List<dynamic> list;
    if (body is List) {
      list = body;
    } else if (body is Map && body['items'] is List) {
      list = body['items'] as List;
    } else {
      throw Exception('Unexpected response for anomalies');
    }
    final items = list.map((e) => _mapAnomaly((e as Map).cast<String, dynamic>())).toList();
    // Sort newest first if not already
    items.sort((a, b) => b.reportedAt.compareTo(a.reportedAt));
    return items;
  }

  @override
  Future<Anomaly> getById(String id) async {
    try {
      final res = await _dio.get('/api/anomalies/$id');
      return _mapAnomaly((res.data as Map).cast<String, dynamic>());
    } on DioException catch (_) {
      // Fallback: list recent and find
      final list = await listRecent(limit: 100);
      return list.firstWhere((a) => a.id == id);
    }
  }

  Anomaly _mapAnomaly(Map<String, dynamic> m) {
    final rawId = m['id'] ?? m['anomaly_id'] ?? m['uuid'] ?? '';
    final id = rawId.toString();
    final cameraId = (m['camera_id'] ?? m['cameraId'] ?? (m['camera'] is Map ? m['camera']['id'] : null) ?? '').toString();
    final anomalyType = (m['anomaly_type'] ?? m['type'] ?? 'anomaly').toString();
    final confidenceVal = m['confidence'] ?? m['score'] ?? m['prob'] ?? 0.0;
    final confidence = (confidenceVal is num) ? confidenceVal.toDouble() : double.tryParse(confidenceVal.toString()) ?? 0.0;
    final videoClipUrl = (m['video_clip_url'] ?? m['video_url'] ?? m['clip_url'] ?? m['url'])?.toString();
    final ts = (m['reported_at'] ?? m['created_at'] ?? m['timestamp'])?.toString();
    DateTime reportedAt;
    try {
      reportedAt = DateTime.parse(ts ?? DateTime.now().toUtc().toIso8601String());
    } catch (_) {
      reportedAt = DateTime.now().toUtc();
    }
    return Anomaly(
      id: id,
      cameraId: cameraId,
      anomalyType: anomalyType,
      confidence: confidence,
      videoClipUrl: videoClipUrl,
      reportedAt: reportedAt.toUtc(),
    );
  }
}

