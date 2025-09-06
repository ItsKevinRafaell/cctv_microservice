import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:anomeye/app/di.dart';
import 'package:anomeye/features/recordings/data/recordings_api.dart';
import 'package:anomeye/features/recordings/data/recordings_repo_impl.dart';
import 'package:anomeye/features/recordings/domain/recording.dart';
import 'package:anomeye/features/recordings/domain/recordings_repo.dart';

final recordingsRepoProvider = Provider<RecordingsRepo>((ref) {
  final dio = ref.watch(dioProvider);
  return RecordingsRepoImpl(RecordingsApi(dio));
});

class RecordingsController extends StateNotifier<AsyncValue<List<Recording>>> {
  final RecordingsRepo repo;
  RecordingsController(this.repo) : super(const AsyncLoading());

  Future<void> fetch(String cameraId,
      {DateTime? from, DateTime? to, bool presign = true}) async {
    state = const AsyncLoading();
    try {
      final items = await repo.list(
        cameraId: cameraId,
        from: from,
        to: to,
        presign: presign,
      );
      state = AsyncData(items);
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }
}

final recordingsControllerProvider = StateNotifierProvider.autoDispose<
    RecordingsController, AsyncValue<List<Recording>>>((ref) {
  return RecordingsController(ref.watch(recordingsRepoProvider));
});
