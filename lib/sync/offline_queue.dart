import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

enum OfflineQueueItemType { fieldCapture, pmInspection }

class OfflineQueueItem {
  OfflineQueueItem({
    required this.id,
    required this.type,
    required this.createdAt,
    required this.payload,
    this.label,
  });

  final String id;
  final OfflineQueueItemType type;
  final DateTime createdAt;
  final Map<String, dynamic> payload;
  final String? label;

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.name,
        'created_at': createdAt.toIso8601String(),
        'payload': payload,
        if (label != null) 'label': label,
      };

  factory OfflineQueueItem.fromJson(Map<String, dynamic> json) {
    final typeName = json['type']?.toString() ?? OfflineQueueItemType.fieldCapture.name;
    final type = OfflineQueueItemType.values.firstWhere(
      (t) => t.name == typeName,
      orElse: () => OfflineQueueItemType.fieldCapture,
    );
    return OfflineQueueItem(
      id: json['id']?.toString() ?? '',
      type: type,
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ??
          DateTime.now(),
      payload: json['payload'] is Map
          ? Map<String, dynamic>.from(json['payload'] as Map)
          : {},
      label: json['label']?.toString(),
    );
  }
}

class OfflineQueue {
  static const _storageKey = 'heevy_inspect_offline_queue_v1';

  Future<List<OfflineQueueItem>> list() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      return decoded
          .whereType<Map>()
          .map((e) => OfflineQueueItem.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> enqueue(OfflineQueueItem item) async {
    final items = await list();
    items.insert(0, item);
    await _save(items);
  }

  Future<void> remove(String id) async {
    final items = await list();
    items.removeWhere((i) => i.id == id);
    await _save(items);
  }

  Future<int> pendingCount() async => (await list()).length;

  Future<void> _save(List<OfflineQueueItem> items) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(items.map((i) => i.toJson()).toList());
    await prefs.setString(_storageKey, encoded);
  }
}

bool isLikelyOfflineError(Object error) {
  final msg = error.toString().toLowerCase();
  return msg.contains('network error') ||
      msg.contains('failed to fetch') ||
      msg.contains('socketexception') ||
      msg.contains('connection') ||
      msg.contains('offline') ||
      msg.contains('timed out');
}
