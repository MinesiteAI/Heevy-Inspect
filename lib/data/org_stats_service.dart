import 'package:supabase_flutter/supabase_flutter.dart';

class OrgStats {
  const OrgStats({
    required this.fieldCaptureCount,
    required this.workRequestCount,
    required this.draftWorkRequestCount,
  });

  final int fieldCaptureCount;
  final int workRequestCount;
  final int draftWorkRequestCount;
}

class OrgStatsService {
  OrgStatsService(this._client);

  final SupabaseClient _client;

  Future<OrgStats> load() async {
    final res = await _client.functions.invoke('mobile-org-stats', body: {});
    if (res.status >= 400) {
      return const OrgStats(
        fieldCaptureCount: 0,
        workRequestCount: 0,
        draftWorkRequestCount: 0,
      );
    }
    final data = res.data;
    if (data is! Map) {
      return const OrgStats(
        fieldCaptureCount: 0,
        workRequestCount: 0,
        draftWorkRequestCount: 0,
      );
    }
    return OrgStats(
      fieldCaptureCount: (data['field_capture_count'] as num?)?.toInt() ?? 0,
      workRequestCount: (data['work_request_count'] as num?)?.toInt() ?? 0,
      draftWorkRequestCount: (data['draft_work_request_count'] as num?)?.toInt() ?? 0,
    );
  }
}
