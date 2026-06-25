import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _themePrefKey = 'heevy_inspect_theme_mode';

final ValueNotifier<ThemeMode> themeModeNotifier = ValueNotifier<ThemeMode>(
  ThemeMode.dark,
);

Future<void> loadThemeMode() async {
  final prefs = await SharedPreferences.getInstance();
  final stored = prefs.getString(_themePrefKey);
  if (stored == 'light') {
    themeModeNotifier.value = ThemeMode.light;
  } else if (stored == 'dark') {
    themeModeNotifier.value = ThemeMode.dark;
  }
}

Future<void> setThemeMode(ThemeMode mode) async {
  themeModeNotifier.value = mode;
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(
    _themePrefKey,
    mode == ThemeMode.dark ? 'dark' : 'light',
  );
}
