import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class RecordingSeenStore {
  static const _storageKey = 'recordings_seen_keys';
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  Future<Set<String>> readAll() async {
    final raw = await _storage.read(key: _storageKey);
    if (raw == null || raw.isEmpty) {
      return <String>{};
    }
    try {
      final decoded = json.decode(raw);
      if (decoded is List) {
        return decoded.whereType<String>().toSet();
      }
    } catch (_) {
      // fallthrough to reset storage
    }
    return <String>{};
  }

  Future<void> saveAll(Set<String> keys) {
    final payload = json.encode(keys.toList());
    return _storage.write(key: _storageKey, value: payload);
  }

  Future<void> clear() => _storage.delete(key: _storageKey);
}
