import 'dart:convert';
import 'dart:io';

import 'package:anomeye/features/auth/storage/secure_token_store.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class NotificationSoundPrefs {
  const NotificationSoundPrefs({this.enabled = true, this.customPath});

  final bool enabled;
  final String? customPath;

  NotificationSoundPrefs copyWith({bool? enabled, String? customPath}) {
    return NotificationSoundPrefs(
      enabled: enabled ?? this.enabled,
      customPath: customPath ?? this.customPath,
    );
  }

  Map<String, dynamic> toMap() => {
        'enabled': enabled,
        'customPath': customPath,
      };

  static NotificationSoundPrefs fromMap(Map<String, dynamic> map) {
    return NotificationSoundPrefs(
      enabled: map['enabled'] is bool ? map['enabled'] as bool : true,
      customPath: map['customPath'] as String?,
    );
  }
}

final _notificationPrefsStoreProvider = Provider<SecureTokenStore>(
  (_) => SecureTokenStore('notification_sound'),
);

final notificationSoundProvider =
    StateNotifierProvider<NotificationSoundController, NotificationSoundPrefs>(
  (ref) => NotificationSoundController(ref.watch(_notificationPrefsStoreProvider)),
);

final notificationSoundPlayerProvider = Provider<NotificationSoundPlayer>((ref) {
  final player = AudioPlayer();
  ref.onDispose(player.dispose);
  return NotificationSoundPlayer(ref, player);
});

class NotificationSoundController
    extends StateNotifier<NotificationSoundPrefs> {
  NotificationSoundController(this._store)
      : super(const NotificationSoundPrefs()) {
    _restore();
  }

  final SecureTokenStore _store;

  Future<void> setEnabled(bool enabled) async {
    state = state.copyWith(enabled: enabled);
    await _persist();
  }

  Future<void> setCustomPath(String? path) async {
    state = state.copyWith(customPath: path);
    await _persist();
  }

  Future<void> _persist() async {
    await _store.save(jsonEncode(state.toMap()));
  }

  Future<void> _restore() async {
    final raw = await _store.read();
    if (raw == null || raw.isEmpty) return;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        state = NotificationSoundPrefs.fromMap(decoded);
      }
    } catch (_) {
      // ignore corrupted payloads
    }
  }
}

class NotificationSoundPlayer {
  NotificationSoundPlayer(this._ref, this._player);

  final Ref _ref;
  final AudioPlayer _player;

  Future<void> playAlert() async {
    final prefs = _ref.read(notificationSoundProvider);
    await _play(prefs);
  }

  Future<void> playPreview(NotificationSoundPrefs prefs) async {
    await _play(prefs, ignoreMute: true);
  }

  Future<void> _play(
    NotificationSoundPrefs prefs, {
    bool ignoreMute = false,
  }) async {
    if (!prefs.enabled && !ignoreMute) return;
    try {
      await _player.stop();
      final customPath = prefs.customPath;
      if (customPath != null && customPath.isNotEmpty) {
        final file = File(customPath);
        if (await file.exists()) {
          await _player.play(DeviceFileSource(file.path));
          return;
        }
      }
    } catch (_) {
      // fall back to system tone below
    }
    await SystemSound.play(SystemSoundType.alert);
  }
}
