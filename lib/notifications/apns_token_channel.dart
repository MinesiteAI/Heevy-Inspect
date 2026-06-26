import 'package:flutter/services.dart';

/// Reads the iOS APNs device token from native code when available.
class ApnsTokenChannel {
  static const _channel = MethodChannel('heevy_inspect/push');

  static Future<String?> getDeviceToken() async {
    try {
      final token = await _channel.invokeMethod<String>('getDeviceToken');
      final t = token?.trim() ?? '';
      return t.isNotEmpty ? t : null;
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }

  static Future<void> requestPermissionAndRegister() async {
    try {
      await _channel.invokeMethod<void>('requestPermissionAndRegister');
    } on MissingPluginException {
      // Android / unsupported platform.
    } on PlatformException {
      // Permission denied or simulator without push.
    }
  }
}
