import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class AcquisitionStorage {
  AcquisitionStorage._();

  static const _key = 'heevy_inspect_acquisition_v1';

  static Future<Map<String, dynamic>> payloadForRegister() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_key);
    if (raw == null || raw.isEmpty) {
      return {
        'acquisition_source': 'heevy_inspect_ios',
        'product': 'heevy_inspect',
      };
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        return {
          'acquisition_source': 'heevy_inspect_ios',
          'product': 'heevy_inspect',
          'acquisition': decoded,
        };
      }
    } catch (_) {}
    return {
      'acquisition_source': 'heevy_inspect_ios',
      'product': 'heevy_inspect',
    };
  }
}
