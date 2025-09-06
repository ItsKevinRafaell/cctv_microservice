import 'package:anomeye/features/anomalies/domain/anomaly.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:anomeye/features/anomalies/domain/anomalies_repo.dart';

final anomaliesRepoProvider = Provider<AnomaliesRepo>((ref) {
  throw UnimplementedError('Bind AnomaliesRepo (Fake/API) pada DI');
});

/// State list anomalies, selalu fetch data baru saat halaman dibuka.
final anomaliesListProvider = StateNotifierProvider.autoDispose
    .family<AnomaliesListController, AsyncValue<List<Anomaly>>, String?>(
  (ref, cameraId) => AnomaliesListController(ref, cameraId),
);

/// State detail anomaly, selalu fetch data baru saat halaman dibuka.
final anomalyDetailProvider = StateNotifierProvider.autoDispose
    .family<AnomalyDetailController, AsyncValue<Anomaly>, String>(
  (ref, id) => AnomalyDetailController(ref, id),
);

class AnomaliesListController extends StateNotifier<AsyncValue<List<Anomaly>>> {
  AnomaliesListController(this._ref, this.cameraId)
      : super(const AsyncValue.loading()) {
    // Memuat data secara otomatis saat controller dibuat
    load();
  }
  final Ref _ref;
  final String? cameraId;

  Future<void> load() async {
    /* ... implementasi tidak berubah ... */
    state = const AsyncValue.loading();
    try {
      final repo = _ref.read(anomaliesRepoProvider);
      final list = await repo.listRecent(cameraId: cameraId, limit: 50);
      if (mounted) state = AsyncValue.data(list);
    } catch (e, st) {
      if (mounted) state = AsyncValue.error(e, st);
    }
  }
}

class AnomalyDetailController extends StateNotifier<AsyncValue<Anomaly>> {
  // FIX: Tambahkan pemanggilan load() di constructor, sama seperti ListController
  AnomalyDetailController(this._ref, this.id)
      : super(const AsyncValue.loading()) {
    load();
  }
  final Ref _ref;
  final String id;

  Future<void> load() async {
    /* ... implementasi tidak berubah ... */
    state = const AsyncValue.loading();
    try {
      final repo = _ref.read(anomaliesRepoProvider);
      final a = await repo.getById(id);
      if (mounted) state = AsyncValue.data(a);
    } catch (e, st) {
      if (mounted) state = AsyncValue.error(e, st);
    }
  }
}
