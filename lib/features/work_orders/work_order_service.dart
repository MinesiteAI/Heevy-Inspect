import 'dart:convert';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/mobile_function_client.dart';
import '../capture/capture_service.dart';

class WorkOrderService {
  WorkOrderService(this._client);

  final SupabaseClient _client;

  MobileFunctionClient get _fn => MobileFunctionClient(_client);

  Future<List<Map<String, dynamic>>> listWorkOrders() async {
    final res = await _fn.invoke('mobile-list-work-orders', body: {});
    if (res.status >= 400) {
      throw Exception(_error(res));
    }
    final data = res.data;
    if (data is Map && data['items'] is List) {
      return List<Map<String, dynamic>>.from(data['items'] as List);
    }
    return [];
  }

  Future<Map<String, dynamic>> getWorkOrder(String id) async {
    final res = await _fn.invoke(
      'mobile-get-work-order',
      body: {'id': id},
    );
    if (res.status >= 400) throw Exception(_error(res));
    final data = res.data;
    if (data is Map && data['work_order'] is Map) {
      return Map<String, dynamic>.from(data['work_order'] as Map);
    }
    throw Exception('Work order not found');
  }

  Future<Map<String, dynamic>> createWorkOrder({
    required String title,
    String? description,
    String? location,
    String? assetId,
    String? assetTag,
    String? priority,
    String? sourceType,
    String? sourceId,
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
    final res = await _fn.invoke(
      'mobile-create-work-order',
      body: {
        'work_order': {
          'title': title,
          if (description != null) 'description': description,
          if (location != null) 'location': location,
          if (assetId != null) 'asset_id': assetId,
          if (assetTag != null) 'asset_name': assetTag,
          if (priority != null) 'priority': priority,
          if (sourceType != null) 'source_type': sourceType,
          if (sourceId != null) 'source_id': sourceId,
        },
        if (photoPayloads.isNotEmpty) 'photo_payloads': photoPayloads,
      },
    );
    if (res.status >= 400) throw Exception(_error(res));
    final data = res.data;
    if (data is Map && data['work_order'] is Map) {
      return Map<String, dynamic>.from(data['work_order'] as Map);
    }
    return Map<String, dynamic>.from(data as Map);
  }

  String _error(FunctionResponse res) {
    final data = res.data;
    if (data is Map && data['error'] != null) return data['error'].toString();
    return 'Request failed (${res.status})';
  }
}
