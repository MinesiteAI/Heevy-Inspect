import 'dart:convert';
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

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
  }) async {
    final photoPayloads = [
      for (final p in photos)
        {
          'mime': p.mime,
          'ext': p.ext,
          'data_base64': base64Encode(p.bytes),
        },
    ];

    final FunctionResponse res;
    try {
      res = await _client.functions.invoke(
        'mobile-submit-field-capture',
        body: {
          'plant_area': plantArea,
          if (assetId != null) 'asset_id': assetId,
          if (assetTag != null) 'asset_tag': assetTag,
          'severity': severity,
          'notes': notes,
          if (voiceTranscript != null) 'voice_transcript': voiceTranscript,
          if (photoPayloads.isNotEmpty) 'photo_payloads': photoPayloads,
          if (mineSiteId != null) 'mine_site_id': mineSiteId,
          if (createWorkOrder) 'create_work_order': true,
        },
      );
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

  Future<List<Map<String, dynamic>>> listMyCaptures() async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return [];
    final rows = await _client
        .from('field_captures')
        .select(
          'id, created_at, plant_area, severity, notes, photo_urls, status, work_request_id, voice_transcript',
        )
        .eq('created_by', uid)
        .order('created_at', ascending: false)
        .limit(100);
    return List<Map<String, dynamic>>.from(rows);
  }

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
}
