import 'package:supabase_flutter/supabase_flutter.dart';

class AppNotification {
  AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.time,
    required this.readAt,
    required this.dismissedAt,
    required this.workOrderId,
    required this.workOrderNumber,
    required this.payload,
  });

  final String id;
  final String type;
  final String title;
  final String body;
  final DateTime time;
  final DateTime? readAt;
  final DateTime? dismissedAt;
  final String? workOrderId;
  final String? workOrderNumber;
  final Map<String, dynamic> payload;

  bool get read => readAt != null;

  AppNotification.fromJson(Map<String, dynamic> json)
      : id = (json['id'] ?? '').toString(),
        type = (json['type'] ?? 'generic').toString(),
        title = (json['title'] ?? '').toString(),
        body = (json['body'] ?? '').toString(),
        time = DateTime.tryParse((json['created_at'] ?? '').toString()) ??
            DateTime.now(),
        readAt = DateTime.tryParse((json['read_at'] ?? '').toString()),
        dismissedAt =
            DateTime.tryParse((json['dismissed_at'] ?? '').toString()),
        workOrderId = (json['work_order_id'] ?? '').toString().trim().isEmpty
            ? null
            : (json['work_order_id']).toString(),
        workOrderNumber =
            (json['work_order_number'] ?? '').toString().trim().isEmpty
                ? null
                : (json['work_order_number']).toString(),
        payload = (json['payload_json'] is Map)
            ? Map<String, dynamic>.from(json['payload_json'] as Map)
            : const {};
}

class NotificationPage {
  NotificationPage({
    required this.items,
    required this.unreadCount,
    required this.totalCount,
    required this.hasMore,
    required this.nextOffset,
  });

  final List<AppNotification> items;
  final int unreadCount;
  final int totalCount;
  final bool hasMore;
  final int nextOffset;
}

class NotificationService {
  NotificationService(this._client);

  final SupabaseClient _client;

  Future<NotificationPage> list({
    int limit = 50,
    int offset = 0,
    bool includeDismissed = false,
  }) async {
    final res = await _client.functions.invoke(
      'mobile-list-notifications',
      body: {
        'limit': limit,
        'offset': offset,
        'include_dismissed': includeDismissed,
      },
    );
    if (res.status >= 400) {
      throw Exception('Could not load notifications (${res.status})');
    }
    final data = (res.data is Map) ? res.data as Map : const {};
    final list = (data['notifications'] as List?) ?? const [];
    return NotificationPage(
      items: list
          .cast<Map<String, dynamic>>()
          .map(AppNotification.fromJson)
          .toList(),
      unreadCount: (data['unread_count'] as num?)?.toInt() ?? 0,
      totalCount: (data['total_count'] as num?)?.toInt() ?? 0,
      hasMore: data['has_more'] == true,
      nextOffset: (data['next_offset'] as num?)?.toInt() ?? 0,
    );
  }

  Future<void> update(String notificationId, String action) async {
    final res = await _client.functions.invoke(
      'mobile-update-notification',
      body: {
        'notification_id': notificationId,
        'action': action,
      },
    );
    if (res.status >= 400) {
      throw Exception('Could not update notification');
    }
  }

  Future<void> registerPushToken({
    required String token,
    String platform = 'ios',
    String? appBuild,
  }) async {
    final t = token.trim();
    if (t.isEmpty) return;
    final res = await _client.functions.invoke(
      'mobile-register-push-token',
      body: {
        'device_token': t,
        'platform': platform,
        if (appBuild != null) 'app_build': appBuild,
        'environment': 'heevy_inspect',
      },
    );
    if (res.status >= 400) {
      throw Exception('Push token registration failed');
    }
  }
}
