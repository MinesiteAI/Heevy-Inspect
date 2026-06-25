import 'package:supabase_flutter/supabase_flutter.dart';

class StorageUrlService {
  StorageUrlService(this._client);

  final SupabaseClient _client;

  Future<Map<String, String>> signUrls(List<String> paths) async {
    if (paths.isEmpty) return {};
    final res = await _client.functions.invoke(
      'mobile-sign-storage-urls',
      body: {'paths': paths},
    );
    if (res.status >= 400) return {};
    final data = res.data;
    if (data is! Map) return {};
    final signed = data['signed_urls'];
    if (signed is! Map) return {};
    return signed.map((k, v) => MapEntry(k.toString(), v.toString()));
  }

  /// Resolve photo_urls from captures (paths or stale URLs) to signed URLs.
  Future<List<String>> resolvePhotoUrls(List<dynamic> raw) async {
    final paths = <String>[];
    for (final item in raw) {
      final s = item?.toString() ?? '';
      if (s.isEmpty) continue;
      if (s.startsWith('http')) {
        paths.add(s);
      } else if (s.startsWith('inspection-uploads/')) {
        paths.add(s);
      } else {
        paths.add('inspection-uploads/$s');
      }
    }
    final needSign = paths.where((p) => !p.startsWith('http')).toList();
    final signed = await signUrls(needSign);
    return [
      for (final p in paths)
        p.startsWith('http') ? p : (signed[p] ?? signed['inspection-uploads/$p'] ?? p),
    ];
  }
}
