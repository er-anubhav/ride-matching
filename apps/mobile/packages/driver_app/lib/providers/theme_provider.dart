import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared/shared.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeNotifier extends StateNotifier<ThemeMode> {
  static const String _prefKey = 'theme_mode';
  final SharedPreferences _prefs;

  ThemeNotifier(this._prefs) : super(ThemeMode.dark) {
    _loadTheme();
  }

  void _loadTheme() {
    final savedMode = _prefs.getString(_prefKey);
    if (savedMode == 'light') {
      state = ThemeMode.light;
    } else if (savedMode == 'dark') {
      state = ThemeMode.dark;
    } else if (savedMode == 'system') {
      state = ThemeMode.system;
    } else {
      state = ThemeMode.dark;
    }
    _updateAppColors();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _updateAppColorsForMode(mode);
    state = mode;
    String modeString = 'system';
    if (mode == ThemeMode.light) {
      modeString = 'light';
    } else if (mode == ThemeMode.dark) {
      modeString = 'dark';
    }
    await _prefs.setString(_prefKey, modeString);
  }

  void toggleTheme() {
    if (state == ThemeMode.dark) {
      setThemeMode(ThemeMode.light);
    } else {
      setThemeMode(ThemeMode.dark);
    }
  }

  void _updateAppColors() => _updateAppColorsForMode(state);

  void _updateAppColorsForMode(ThemeMode mode) {
    Brightness brightness;
    if (mode == ThemeMode.light) {
      brightness = Brightness.light;
    } else if (mode == ThemeMode.dark) {
      brightness = Brightness.dark;
    } else {
      brightness = PlatformDispatcher.instance.platformBrightness;
    }
    AppColors.brightness = brightness;
  }
}

final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('Initialize SharedPreferences in main() first');
});

final themeProvider = StateNotifierProvider<ThemeNotifier, ThemeMode>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return ThemeNotifier(prefs);
});
