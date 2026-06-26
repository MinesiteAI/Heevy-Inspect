import 'package:supabase_flutter/supabase_flutter.dart';

class PmScheduleService {
  PmScheduleService(this._client);

  final SupabaseClient _client;

  Future<Map<String, dynamic>> loadInbox({int daysAhead = 7}) async {
    final res = await _client.functions.invoke(
      'mobile-list-pm-schedule',
      body: {'days_ahead': daysAhead},
    );
    if (res.status >= 400) throw Exception(_error(res));
    final data = res.data;
    if (data is Map) return Map<String, dynamic>.from(data);
    throw Exception('Unexpected response');
  }

  String _error(FunctionResponse res) {
    final data = res.data;
    if (data is Map && data['error'] != null) return data['error'].toString();
    return 'Request failed (${res.status})';
  }
}
