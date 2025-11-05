import 'package:anomeye/features/recordings/storage/recording_seen_store.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final recordingSeenStoreProvider = Provider<RecordingSeenStore>((_) {
  return RecordingSeenStore();
});

final recordingSeenProvider =
    StateNotifierProvider<RecordingSeenController, Set<String>>((ref) {
  final store = ref.watch(recordingSeenStoreProvider);
  return RecordingSeenController(store);
});

class RecordingSeenController extends StateNotifier<Set<String>> {
  RecordingSeenController(this._store) : super(const <String>{}) {
    _load();
  }

  final RecordingSeenStore _store;
  bool _hydrated = false;

  Future<void> _load() async {
    final entries = await _store.readAll();
    _hydrated = true;
    if (mounted) {
      state = entries;
    }
  }

  bool get isReady => _hydrated;

  Future<void> markSeen(String key) async {
    final next = {...state, key};
    state = next;
    await _store.saveAll(next);
  }

  Future<void> reset() async {
    state = const <String>{};
    await _store.clear();
  }
}
