import 'package:anomeye/features/cameras/domain/camera.dart';
import 'package:anomeye/features/cameras/domain/cameras_repo.dart';
import 'package:dio/dio.dart';

class CamerasRepoApi implements CamerasRepo {
  final Dio _dio;
  CamerasRepoApi(this._dio);

  @override
  Future<List<Camera>> listCameras() async {
    final res = await _dio.get('/api/cameras');
    final data = res.data;
    if (data is! List) {
      throw Exception('Unexpected response for /api/cameras');
    }
    return data.map<Camera>((e) => _map((e as Map).cast<String, dynamic>())).toList();
  }

  @override
  Future<Camera> getCamera(String id) async {
    // Backend belum menyediakan GET /api/cameras/{id}.
    // Ambil semua lalu cari yang cocok (id di app = stream_key).
    final list = await listCameras();
    try {
      return list.firstWhere((c) => c.id == id);
    } catch (_) {
      // Fallback: coba cocokkan jika id berupa angka (numeric camera id)
      // terhadap stream_key default cam<ID>.
      if (int.tryParse(id) != null) {
        final key = 'cam$id';
        return list.firstWhere((c) => c.id == key);
      }
      rethrow;
    }
  }

  Camera _map(Map<String, dynamic> m) {
    // API fields:
    // id(int), name, location?, stream_key?, hls_url?, rtsp_url?, webrtc_url?
    final rawId = m['stream_key']?.toString();
    final numericId = m['id']?.toString();
    final id = (rawId != null && rawId.isNotEmpty)
        ? rawId
        : (numericId != null ? 'cam$numericId' : '');
    final name = (m['name'] ?? 'Camera $id').toString();
    final location = (m['location'] as String?)?.trim();
    final hls = (m['hls_url'] as String?)?.trim();

    return Camera(
      id: id, // gunakan stream_key sebagai ID di app
      name: name,
      location: (location != null && location.isNotEmpty) ? location : null,
      online: true, // jika belum ada status online dari backend
      activeAlerts: 0,
      streamUrl: hls,
    );
  }
}

