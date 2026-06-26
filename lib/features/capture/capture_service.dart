import 'dart:convert';
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/mobile_function_client.dart';

class CapturePhoto {
  const CapturePhoto({
    required this.bytes,
    required this.mime,
    required this.ext,
  });

  final Uint8List bytes;
  final String mime;
  final String ext;
}

class CaptureService {
  CaptureService(this._client);

  final SupabaseClient _client;

  MobileFunctionClient get _fn => MobileFunctionClient(_client);

  Future<Map<String, dynamic>> submitFieldCapture({
    required String plantArea,
    String? assetId,
    String? assetTag,
    required String severity,
    required String notes,
    String? voiceTranscript,
    List<CapturePhoto> photos = const [],
    String? mineSiteId,
    bool createWorkOrder = false,
    Map<String, dynamic>? offlinePayload,
  }) async {
    final Map<String, dynamic> body;
    if (offlinePayload != null) {
      body = Map<String, dynamic>.from(offlinePayload);
    } else {
      final photoPayloads = [
        for (final p in photos)
          {
            'mime': p.mime,
            'ext': p.ext,
            'data_base64': base64Encode(p.bytes),
          },
      ];
      body = {
        'plant_area': plantArea,
        if (assetId != null) 'asset_id': assetId,
        if (assetTag != null) 'asset_tag': assetTag,
        'severity': severity,
        'notes': notes,
        if (voiceTranscript != null) 'voice_transcript': voiceTranscript,
        if (photoPayloads.isNotEmpty) 'photo_payloads': photoPayloads,
        if (mineSiteId != null) 'mine_site_id': mineSiteId,
        if (createWorkOrder) 'create_work_order': true,
      };
    }

    final FunctionResponse res;
    try {
      res = await _fn.invoke('mobile-submit-field-capture', body: body);
    } catch (e) {
      throw Exception(_formatInvokeError(e));
    }

    if (res.status >= 400) {
      throw Exception(_formatResponseError(res));
    }

    final data = res.data;
    if (data is! Map) {
      throw Exception('Unexpected response from server');
    }
    return Map<String, dynamic>.from(data);
  }

  Future<List<Map<String, dynamic>>> listCaptures({
    String scope = 'mine',
  }) async {
    final res = await _fn.invoke(
      'mobile-list-field-captures',
      body: {'scope': scope},
    );
    if (res.status >= 400) throw Exception(_error(res));
    final data = res.data;
    if (data is Map && data['items'] is List) {
      return List<Map<String, dynamic>>.from(data['items'] as List);
    }
    return [];
  }

  Future<Map<String, dynamic>> listCapturesMeta({String scope = 'mine'}) async {
    final res = await _fn.invoke(
      'mobile-list-field-captures',
      body: {'scope': scope},
    );
    if (res.status >= 400) throw Exception(_error(res));
    final data = res.data;
    if (data is Map) return Map<String, dynamic>.from(data);
    return {'items': <Map<String, dynamic>>[]};
  }

  /// Legacy alias — personal captures only.
  Future<List<Map<String, dynamic>>> listMyCaptures() =>
      listCaptures(scope: 'mine');

  String _formatInvokeError(Object e) {
    final raw = e.toString().replaceFirst('Exception: ', '');
    if (raw.contains('Failed to fetch') || raw.contains('SocketException')) {
      return 'Network error — check your connection and try again.';
    }
    return raw;
  }

  String _formatResponseError(FunctionResponse res) {
    final data = res.data;
    if (data is Map) {
      final err = data['error'];
      if (err != null && err.toString().trim().isNotEmpty) {
        return err.toString();
      }
    }
    return 'Submit failed (${res.status})';
  }

  String _error(FunctionResponse res) {
    final data = res.data;
    if (data is Map && data['error'] != null) return data['error'].toString();
    return 'Request failed (${res.status})';
  }
}
