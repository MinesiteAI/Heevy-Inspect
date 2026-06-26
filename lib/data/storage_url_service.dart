import 'package:supabase_flutter/supabase_flutter.dart';

class StorageUrlService {
  StorageUrlService(this._client);

  final SupabaseClient _client;

  /// Extract bucket-relative path from Supabase storage URL or path string.
  static String? extractStoragePath(String urlOrPath) {
    final s = urlOrPath.trim();
    if (s.isEmpty) return null;

    // Already a relative path (with or without bucket prefix).
    if (!s.startsWith('http')) {
      if (s.startsWith('inspection-uploads/')) {
        return s.substring('inspection-uploads/'.length);
      }
      return s;
    }

    final uri = Uri.tryParse(s);
    if (uri == null) return null;

    // .../storage/v1/object/sign/inspection-uploads/<path>
    // .../storage/v1/object/public/inspection-uploads/<path>
    final segments = uri.pathSegments;
    for (var i = 0; i < segments.length; i++) {
      if (segments[i] == 'inspection-uploads' && i + 1 < segments.length) {
        return segments.sublist(i + 1).join('/');
      }
    }

    // Legacy: path after bucket name in URL path.
    final path = uri.path;
    const marker = '/inspection-uploads/';
    final idx = path.indexOf(marker);
    if (idx >= 0) {
      return path.substring(idx + marker.length);
    }

    return null;
  }

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

  /// Resolve photo_urls (paths, legacy URLs, expired signed URLs) to fresh signed URLs.
  Future<List<String>> resolvePhotoUrls(List<dynamic> raw) async {
    final pathKeys = <String>[];
    for (final item in raw) {
      final extracted = extractStoragePath(item?.toString() ?? '');
      if (extracted != null && extracted.isNotEmpty) {
        pathKeys.add(extracted);
      }
    }
    if (pathKeys.isEmpty) return [];

    final signed = await signUrls(pathKeys);
    final urls = <String>[];
    for (final key in pathKeys) {
      final url = signed[key] ??
          signed['inspection-uploads/$key'] ??
          signed[key.replaceFirst('inspection-uploads/', '')];
      if (url != null && url.startsWith('http')) {
        urls.add(url);
      }
    }
    return urls;
  }
}
