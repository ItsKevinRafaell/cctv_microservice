import 'package:dio/dio.dart';
import 'package:anomeye/features/cameras/domain/cameras_repo.dart';
import 'package:anomeye/features/cameras/domain/camera.dart';

/// Implementasi API nyata dengan pemetaan fleksibel terhadap bentuk respons backend.
class CamerasRepoApi implements CamerasRepo {
  final Dio _dio;
  final String _hlsBase;
  CamerasRepoApi(this._dio, this._hlsBase);

  @override
  Future<List<Camera>> listCameras() async {
    final res = await _dio.get('/api/cameras');
    final body = res.data;
    final List<dynamic> list;
    if (body is List) {
      list = body;
    } else if (body is Map && body['items'] is List) {
      list = body['items'] as List;
    } else {
      throw Exception('Unexpected /api/cameras response');
    }
    return list
        .map((e) => _mapCamera((e as Map).cast<String, dynamic>()))
        .toList();
  }

  @override
  Future<Camera> getCamera(String id) async {
    try {
      final res = await _dio.get('/api/cameras/$id');
      return _mapCamera((res.data as Map).cast<String, dynamic>());
    } on DioException catch (_) {
      // Fallback: jika id bukan numeric (kemungkinan stream_key), cari dari list
      final list = await listCameras();
      final cam = list.firstWhere(
        (c) => c.id == id,
        orElse: () => throw Exception('Camera not found: $id'),
      );
      return cam;
    }
  }

  Camera _mapCamera(Map<String, dynamic> m) {
    // id numerik (DB)
    final numId = (m['id'] ?? m['camera_id']);
    final dbId = (numId is num) ? numId.toInt().toString() : (numId?.toString() ?? '');
    // stream key -> dipakai untuk HLS path
    final streamKey = (m['stream_key'] ?? m['key'] ?? m['streamKey'] ?? dbId).toString();
    final name = (m['name'] ?? 'Camera $dbId').toString();
    final location = (m['location'] as String?) ?? (m['site'] as String?);
    final online = (m['online'] is bool)
        ? (m['online'] as bool)
        : ((m['status']?.toString().toLowerCase()) == 'online');
    final activeAlerts = (m['active_alerts'] is num)
        ? (m['active_alerts'] as num).toInt()
        : 0;
    final streamUrl = '$_hlsBase/$streamKey/index.m3u8';

    // Domain Camera.id akan memakai streamKey agar konsisten dg HLS route.
    return Camera(
      id: streamKey,
      name: name,
      location: location,
      online: online,
      activeAlerts: activeAlerts,
      streamUrl: streamUrl,
    );
  }
}

