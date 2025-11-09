import 'dart:convert';

import 'package:anomeye/features/auth/storage/secure_token_store.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final _readStoreProvider = Provider<SecureTokenStore>(
  (_) => SecureTokenStore('anomaly_read_ids'),
);

final anomalyReadControllerProvider =
    StateNotifierProvider<AnomalyReadController, Set<String>>(
      (ref) => AnomalyReadController(ref.watch(_readStoreProvider)),
    );

class AnomalyReadController extends StateNotifier<Set<String>> {
  AnomalyReadController(this._store) : super(<String>{}) {
    _restore();
  }

  final SecureTokenStore _store;

  Future<void> markRead(String id) async {
    if (state.contains(id)) return;
    final updated = {...state, id};
    state = updated;
    await _store.save(jsonEncode(updated.toList()));
  }

  Future<void> markMany(Iterable<String> ids) async {
    final updated = {...state, ...ids};
    state = updated;
    await _store.save(jsonEncode(updated.toList()));
  }

  Future<void> clear() async {
    state = <String>{};
    await _store.clear();
  }

  Future<void> _restore() async {
    final raw = await _store.read();
    if (raw == null || raw.isEmpty) return;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        state = decoded.map((e) => e.toString()).toSet();
      }
    } catch (_) {
      // ignore decode errors
    }
  }
}
