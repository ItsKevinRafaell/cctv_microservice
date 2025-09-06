import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureTokenStore {
  // FIX 1: Hapus keyword `static` agar setiap instance punya state sendiri.
  final _storage = const FlutterSecureStorage();
  final String _key;

  // FIX 2: Buat constructor yang menerima 'key' sebagai parameter.
  // Ini memungkinkan kita membuat store untuk 'auth_token', 'fcm_token', dll.
  SecureTokenStore(this._key);

  Future<void> save(String token) => _storage.write(key: _key, value: token);
  Future<String?> read() => _storage.read(key: _key);
  Future<void> clear() => _storage.delete(key: _key);
}
