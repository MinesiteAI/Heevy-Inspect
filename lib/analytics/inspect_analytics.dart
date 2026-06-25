import 'package:shared_preferences/shared_preferences.dart';

/// Lightweight funnel events for v2 (local until analytics SDK wired).
class InspectAnalytics {
  static const _prefix = 'inspect_event_';

  static Future<void> track(String event) async {
    final prefs = await SharedPreferences.getInstance();
    final count = prefs.getInt('$_prefix$event') ?? 0;
    await prefs.setInt('$_prefix$event', count + 1);
    await prefs.setString('${_prefix}last_$event', DateTime.now().toIso8601String());
  }

  static Future<int> count(String event) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('$_prefix$event') ?? 0;
  }
}
