import 'package:shared_preferences/shared_preferences.dart';

class OnboardingUserPrefs {
  static const _seenLoginKey = 'heevy_inspect_seen_login';

  static Future<bool> hasSeenLoginScreenBefore() async {
    final p = await SharedPreferences.getInstance();
    return p.getBool(_seenLoginKey) ?? false;
  }

  static Future<void> markLoginScreenSeen() async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(_seenLoginKey, true);
  }
}
