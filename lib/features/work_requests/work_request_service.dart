import 'package:supabase_flutter/supabase_flutter.dart';

class WorkRequestService {
  WorkRequestService(this._client);

  final SupabaseClient _client;

  Future<List<Map<String, dynamic>>> listWorkRequests() async {
    final res = await _client.functions.invoke('mobile-list-work-requests', body: {});
    if (res.status >= 400) throw Exception(_error(res));
    final data = res.data;
    if (data is Map && data['items'] is List) {
      return List<Map<String, dynamic>>.from(data['items'] as List);
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

  String _error(FunctionResponse res) {
    final data = res.data;
    if (data is Map && data['error'] != null) return data['error'].toString();
    return 'Request failed (${res.status})';
  }
}
