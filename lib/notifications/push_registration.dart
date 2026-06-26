import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'apns_token_channel.dart';
import 'notification_service.dart';

/// Registers APNs / injected push tokens with the backend.
class PushRegistration {
  static const _legacyDeviceIdKey = 'heevy_inspect_push_device_id_v1';

  /// Optional bootstrap: `--dart-define=IOS_PUSH_DEVICE_TOKEN=...`
  static String? tokenFromEnvironment() {
    const token = String.fromEnvironment(
      'IOS_PUSH_DEVICE_TOKEN',
      defaultValue: '',
    );
    final t = token.trim();
    return t.isNotEmpty ? t : null;
  }

  static Future<String?> resolveDeviceToken() async {
    final fromEnv = tokenFromEnvironment();
    if (fromEnv != null) return fromEnv;

    await ApnsTokenChannel.requestPermissionAndRegister();
    final apns = await ApnsTokenChannel.getDeviceToken();
    if (apns != null) return apns;

    // Legacy placeholder — only used when APNs unavailable (e.g. simulator).
    final prefs = await SharedPreferences.getInstance();
    var id = prefs.getString(_legacyDeviceIdKey);
    if (id == null || id.isEmpty) {
      id = 'inspect_sim_${DateTime.now().millisecondsSinceEpoch}';
      await prefs.setString(_legacyDeviceIdKey, id);
    }
    return id;
  }

  static Future<void> registerIfSignedIn(SupabaseClient client) async {
    if (client.auth.currentSession == null) return;
    try {
      final token = await resolveDeviceToken();
      if (token == null || token.isEmpty) return;

      String appBuild = 'heevy_inspect';
      try {
        final info = await PackageInfo.fromPlatform();
        appBuild = '${info.version}+${info.buildNumber}';
      } catch (_) {}

      await NotificationService(client).registerPushToken(
        token: token,
        platform: 'ios',
        appBuild: appBuild,
      );
    } catch (_) {
      // Non-fatal — in-app notifications still work.
    }
  }
}
