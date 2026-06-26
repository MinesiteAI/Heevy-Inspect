import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'notification_service.dart';

/// Registers a stable device id for push dispatch until APNs/FCM is wired in-app.
class PushRegistration {
  static const _deviceIdKey = 'heevy_inspect_push_device_id_v1';

  static Future<String> deviceId() async {
    final prefs = await SharedPreferences.getInstance();
    var id = prefs.getString(_deviceIdKey);
    if (id == null || id.isEmpty) {
      id = 'inspect_${DateTime.now().millisecondsSinceEpoch}';
      await prefs.setString(_deviceIdKey, id);
    }
    return id;
  }

  static Future<void> registerIfSignedIn(SupabaseClient client) async {
    if (client.auth.currentSession == null) return;
    try {
      final id = await deviceId();
      await NotificationService(client).registerPushToken(
        token: id,
        platform: 'ios',
        appBuild: 'heevy_inspect',
      );
    } catch (_) {
      // Non-fatal — in-app notifications still work.
    }
  }
}
