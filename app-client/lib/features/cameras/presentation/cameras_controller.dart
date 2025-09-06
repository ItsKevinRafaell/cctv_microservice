import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:anomeye/features/cameras/domain/cameras_repo.dart';
import 'package:anomeye/features/cameras/domain/camera.dart';

// FILE INI SUDAH BENAR, JANGAN DIUBAH
final camerasListProvider =
    StateNotifierProvider<CamerasListController, AsyncValue<List<Camera>>>(
  (ref) => CamerasListController(ref),
);

class CamerasListController extends StateNotifier<AsyncValue<List<Camera>>> {
  // Constructor ini sengaja kosong agar bisa di-load manual dari UI
  CamerasListController(this._ref) : super(const AsyncValue.loading());

  final Ref _ref;

  Future<void> load() async {
    state = const AsyncValue.loading();
    try {
      final repo = _ref.read(camerasRepoProvider);
      final cameras = await repo.listCameras();
      if (mounted) state = AsyncValue.data(cameras);
    } catch (e, st) {
      if (mounted) state = AsyncValue.error(e, st);
    }
  }
}

// ... sisa file

/// State detail kamera
final cameraDetailProvider = StateNotifierProvider.family<
    CameraDetailController, AsyncValue<Camera>, String>(
  // CHANGE 2: Pass the whole `ref` object here too
  (ref, id) => CameraDetailController(ref, id),
);

class CameraDetailController extends StateNotifier<AsyncValue<Camera>> {
  // CHANGE 6: The constructor now accepts `Ref`
  CameraDetailController(this._ref, this.id)
      : super(const AsyncValue.loading());
  // CHANGE 7: The type is now `Ref`
  final Ref _ref;
  final String id;

  Future<void> load() async {
    state = const AsyncValue.loading();
    try {
      // CHANGE 8: Call the `.read()` method on the `_ref` object
      final repo = _ref.read(camerasRepoProvider);
      final cam = await repo.getCamera(id);
      state = AsyncValue.data(cam);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

/// Provider repo untuk di-inject dari DI (lihat bagian DI)
final camerasRepoProvider = Provider<CamerasRepo>((ref) {
  throw UnimplementedError('camerasRepoProvider belum di-bind di DI');
});
