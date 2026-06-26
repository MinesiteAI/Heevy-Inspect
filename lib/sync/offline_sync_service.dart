import 'package:supabase_flutter/supabase_flutter.dart';

import '../features/capture/capture_service.dart';
import 'offline_queue.dart';

class OfflineSyncResult {
  const OfflineSyncResult({
    required this.synced,
    required this.failed,
    required this.remaining,
  });

  final int synced;
  final int failed;
  final int remaining;
}

class OfflineSyncService {
  OfflineSyncService(this._client);

  final SupabaseClient _client;
  final OfflineQueue _queue = OfflineQueue();

  Future<int> pendingCount() => _queue.pendingCount();

  Future<OfflineSyncResult> syncAll() async {
    final items = await _queue.list();
    if (items.isEmpty) {
      return const OfflineSyncResult(synced: 0, failed: 0, remaining: 0);
    }

    var synced = 0;
    var failed = 0;
    final captureSvc = CaptureService(_client);

    for (final item in items) {
      try {
        if (item.type == OfflineQueueItemType.fieldCapture) {
          await captureSvc.submitFieldCapture(
            plantArea: '',
            severity: 'Medium',
            notes: '',
            offlinePayload: item.payload,
          );
        } else if (item.type == OfflineQueueItemType.pmInspection) {
          await _syncPmInspection(item);
        }
        await _queue.remove(item.id);
        synced++;
      } catch (_) {
        failed++;
      }
    }

    final remaining = await _queue.pendingCount();
    return OfflineSyncResult(
      synced: synced,
      failed: failed,
      remaining: remaining,
    );
  }

  Future<void> _syncPmInspection(OfflineQueueItem item) async {
    final res = await _client.functions.invoke(
      'mobile-submit-pm-inspection',
      body: item.payload,
    );
    if (res.status >= 400) {
      final data = res.data;
      final msg = data is Map
          ? (data['error']?.toString() ?? 'PM sync failed')
          : 'PM sync failed';
      throw Exception(msg);
    }
  }
}
