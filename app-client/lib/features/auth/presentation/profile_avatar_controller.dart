import 'dart:convert';

import 'package:anomeye/features/auth/storage/secure_token_store.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final _avatarStoreProvider = Provider<SecureTokenStore>(
  (_) => SecureTokenStore('profile_avatar_path'),
);

final profileAvatarProvider =
    StateNotifierProvider<ProfileAvatarController, String?>(
  (ref) => ProfileAvatarController(ref.watch(_avatarStoreProvider)),
);

class ProfileAvatarController extends StateNotifier<String?> {
  ProfileAvatarController(this._store) : super(null) {
    _restore();
  }

  final SecureTokenStore _store;

  Future<void> setAvatarPath(String? path) async {
    state = path;
    if (path == null || path.isEmpty) {
      await _store.clear();
    } else {
      await _store.save(path);
    }
  }

  Future<void> _restore() async {
    final saved = await _store.read();
    if (saved == null || saved.isEmpty) return;
    state = saved;
  }
}

class ProfileInfoState {
  const ProfileInfoState({this.displayName, this.accountEmail});

  final String? displayName;
  final String? accountEmail;

  ProfileInfoState copyWith({String? displayName, String? accountEmail}) {
    return ProfileInfoState(
      displayName: displayName ?? this.displayName,
      accountEmail: accountEmail ?? this.accountEmail,
    );
  }

  Map<String, dynamic> toMap() => {
        'displayName': displayName,
        'accountEmail': accountEmail,
      };

  static ProfileInfoState fromMap(Map<String, dynamic> map) {
    return ProfileInfoState(
      displayName: map['displayName'] as String?,
      accountEmail: map['accountEmail'] as String?,
    );
  }
}

final _infoStoreProvider = Provider<SecureTokenStore>(
  (_) => SecureTokenStore('profile_info_state'),
);

final profileInfoProvider =
    StateNotifierProvider<ProfileInfoController, ProfileInfoState>(
  (ref) => ProfileInfoController(ref.watch(_infoStoreProvider)),
);

class ProfileInfoController extends StateNotifier<ProfileInfoState> {
  ProfileInfoController(this._store) : super(const ProfileInfoState()) {
    _restore();
  }

  final SecureTokenStore _store;

  Future<void> setDisplayName(String name) async {
    state = state.copyWith(displayName: name);
    await _persist();
  }

  Future<void> setAccountEmail(String email) async {
    state = state.copyWith(accountEmail: email);
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
        state = ProfileInfoState.fromMap(decoded);
      }
    } catch (_) {
      // ignore invalid json
    }
  }
}
