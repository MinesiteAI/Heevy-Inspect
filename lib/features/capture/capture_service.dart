import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

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
    required List<String> photoUrls,
    String? mineSiteId,
  }) async {
    final res = await _client.functions.invoke(
      'mobile-submit-field-capture',
      body: {
        'plant_area': plantArea,
        if (assetId != null) 'asset_id': assetId,
        if (assetTag != null) 'asset_tag': assetTag,
        'severity': severity,
        'notes': notes,
        if (voiceTranscript != null) 'voice_transcript': voiceTranscript,
        'photo_urls': photoUrls,
        if (mineSiteId != null) 'mine_site_id': mineSiteId,
      },
    );
    if (res.status >= 400) {
      final err = res.data;
      throw Exception(
        err is Map ? (err['error'] ?? err).toString() : 'Submit failed',
      );
    }
    return Map<String, dynamic>.from(res.data as Map);
  }

  Future<List<Map<String, dynamic>>> listMyCaptures() async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return [];
    final rows = await _client
        .from('field_captures')
        .select(
          'id, created_at, plant_area, severity, notes, photo_urls, status, work_request_id',
        )
        .eq('created_by', uid)
        .order('created_at', ascending: false)
        .limit(100);
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<String> uploadPhoto(List<int> bytes, String mime, String ext) async {
    final uid = _client.auth.currentUser?.id ?? 'anon';
    final path =
        '$uid/${DateTime.now().millisecondsSinceEpoch}.${ext.replaceAll('.', '')}';
    await _client.storage.from('inspection-uploads').uploadBinary(
          path,
          Uint8List.fromList(bytes),
          fileOptions: FileOptions(contentType: mime, upsert: false),
        );
    return _client.storage.from('inspection-uploads').getPublicUrl(path);
  }
}
