import 'package:anomeye/features/anomalies/domain/anomaly.dart';

abstract class AnomaliesRepo {
  /// Daftar alert terbaru (opsional filter kamera)
  Future<List<Anomaly>> listRecent({String? cameraId, int limit = 50});

  /// Ambil 1 alert by id
  Future<Anomaly> getById(String id);
}
