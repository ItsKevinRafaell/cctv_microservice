import 'package:anomeye/features/anomalies/domain/anomaly.dart';
import 'package:anomeye/features/anomalies/domain/anomalies_repo.dart';
import 'package:collection/collection.dart';

/// Implementasi fake dari AnomaliesRepo untuk development dan testing.
class AnomaliesRepoFake implements AnomaliesRepo {
  final Duration delay;
  AnomaliesRepoFake({this.delay = const Duration(milliseconds: 400)});

  // Data anomali palsu yang sudah disiapkan
  final _anomalies = <Anomaly>[
    Anomaly(
      id: 'anomaly1',
      cameraId: 'cam1',
      anomalyType: 'Intrusion Detected',
      confidence: 0.95,
      reportedAt: DateTime.now().subtract(const Duration(minutes: 5)),
    ),
    Anomaly(
      id: 'anomaly2',
      cameraId: 'cam2',
      anomalyType: 'Suspicious Loitering',
      confidence: 0.82,
      reportedAt: DateTime.now().subtract(const Duration(minutes: 30)),
    ),
    Anomaly(
      id: 'anomaly3',
      cameraId: 'cam1',
      anomalyType: 'Unattended Object',
      confidence: 0.88,
      reportedAt: DateTime.now().subtract(const Duration(hours: 1)),
    ),
    Anomaly(
      id: 'anomaly4',
      cameraId: 'cam4',
      anomalyType: 'Perimeter Breach',
      confidence: 0.99,
      reportedAt: DateTime.now().subtract(const Duration(hours: 2)),
    ),
  ];

  @override
  Future<List<Anomaly>> listRecent({String? cameraId, int limit = 50}) async {
    await Future.delayed(delay); // Simulasi jeda jaringan

    // Terapkan filter jika cameraId diberikan
    var results = _anomalies;
    if (cameraId != null) {
      results = _anomalies.where((a) => a.cameraId == cameraId).toList();
    }

    // Urutkan dari yang terbaru dan batasi jumlahnya
    results.sort((a, b) => b.reportedAt.compareTo(a.reportedAt));
    return results.take(limit).toList();
  }

  @override
  Future<Anomaly> getById(String id) async {
    await Future.delayed(delay);

    final anomaly = _anomalies.firstWhereOrNull((a) => a.id == id);

    if (anomaly != null) {
      return anomaly;
    } else {
      // Simulasi error "404 Not Found"
      throw Exception('Anomaly with ID $id not found.');
    }
  }
}
