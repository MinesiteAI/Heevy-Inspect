import 'dart:convert';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../capture/capture_service.dart';

class WorkRequestService {
  WorkRequestService(this._client);

  final SupabaseClient _client;

  Future<Map<String, dynamic>> listWorkRequestsMeta({
    String scope = 'mine',
  }) async {
    final res = await _client.functions.invoke(
      'mobile-list-work-requests',
      body: {'scope': scope},
    );
    if (res.status >= 400) throw Exception(_error(res));
    final data = res.data;
    if (data is Map) return Map<String, dynamic>.from(data);
    return {'items': <Map<String, dynamic>>[]};
  }

  Future<List<Map<String, dynamic>>> listWorkRequests({
    String scope = 'mine',
  }) async {
    final meta = await listWorkRequestsMeta(scope: scope);
    final items = meta['items'];
    if (items is List) {
      return List<Map<String, dynamic>>.from(items);
    }
    return [];
  }

  Future<Map<String, dynamic>> getWorkRequest(String id) async {
    final res = await _client.functions.invoke(
      'mobile-get-work-request',
      body: {'id': id},
    );
    if (res.status >= 400) throw Exception(_error(res));
    final data = res.data;
    if (data is Map) {
      return Map<String, dynamic>.from(data);
    }
    throw Exception('Work request not found');
  }

  Future<Map<String, dynamic>> submitWorkRequest(String id) async {
    final res = await _client.functions.invoke(
      'mobile-submit-work-request',
      body: {'id': id},
    );
    if (res.status >= 400) throw Exception(_error(res));
    final data = res.data;
    if (data is Map && data['work_request'] is Map) {
      return Map<String, dynamic>.from(data);
    }
    if (data is Map) return Map<String, dynamic>.from(data);
    throw Exception('Unexpected response');
  }

  Future<Map<String, dynamic>> createWorkRequest({
    required String workTitle,
    String? problemDescription,
    String? functionalLocation,
    String? assetId,
    String? assetTag,
    String? priority,
    List<CapturePhoto> photos = const [],
  }) async {
    final photoPayloads = [
      for (final p in photos)
        {
          'mime': p.mime,
          'ext': p.ext,
          'data_base64': base64Encode(p.bytes),
        },
    ];
    final res = await _client.functions.invoke(
      'mobile-create-work-request',
      body: {
        'work_request': {
          'work_title': workTitle,
          if (problemDescription != null && problemDescription.isNotEmpty)
            'problem_description': problemDescription,
          if (functionalLocation != null && functionalLocation.isNotEmpty)
            'functional_location': functionalLocation,
          if (assetId != null) 'asset_id': assetId,
          if (assetTag != null) 'asset_tag': assetTag,
          if (priority != null) 'priority': priority,
        },
        if (photoPayloads.isNotEmpty) 'photo_payloads': photoPayloads,
      },
    );
    if (res.status >= 400) throw Exception(_error(res));
    final data = res.data;
    if (data is Map && data['work_request'] is Map) {
      return Map<String, dynamic>.from(data['work_request'] as Map);
    }
    if (data is Map) return Map<String, dynamic>.from(data);
    throw Exception('Unexpected response');
  }

  String _error(FunctionResponse res) {
    final data = res.data;
    if (data is Map && data['error'] != null) return data['error'].toString();
    return 'Request failed (${res.status})';
  }
}
