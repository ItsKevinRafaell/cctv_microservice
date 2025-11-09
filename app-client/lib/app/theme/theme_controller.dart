import 'package:anomeye/features/auth/storage/secure_token_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final _themeStoreProvider = Provider<SecureTokenStore>(
  (_) => SecureTokenStore('app_theme_mode'),
);

final themeModeControllerProvider =
    StateNotifierProvider<ThemeModeController, ThemeMode>(
      (ref) => ThemeModeController(ref.watch(_themeStoreProvider)),
    );

class ThemeModeController extends StateNotifier<ThemeMode> {
  ThemeModeController(this._store) : super(ThemeMode.system) {
    _restore();
  }

  final SecureTokenStore _store;

  Future<void> setTheme(ThemeMode mode) async {
    state = mode;
    if (mode == ThemeMode.system) {
      await _store.clear();
    } else {
      await _store.save(mode.name);
    }
  }

  Future<void> toggle() async {
    switch (state) {
      case ThemeMode.light:
        await setTheme(ThemeMode.dark);
        break;
      case ThemeMode.dark:
        await setTheme(ThemeMode.system);
        break;
      case ThemeMode.system:
        await setTheme(ThemeMode.light);
        break;
    }
  }

  Future<void> _restore() async {
    final stored = await _store.read();
    if (stored == null) return;
    switch (stored) {
      case 'light':
        state = ThemeMode.light;
        break;
      case 'dark':
        state = ThemeMode.dark;
        break;
      case 'system':
        state = ThemeMode.system;
        break;
    }
  }
}
