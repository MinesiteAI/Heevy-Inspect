import 'package:supabase_flutter/supabase_flutter.dart';

class PmSubmissionService {
  PmSubmissionService(this._client);

  final SupabaseClient _client;

  Future<List<Map<String, dynamic>>> listMySubmissions() async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return [];
    final rows = await _client
        .from('pm_form_submissions')
        .select(
          'id, template_id, status, notes, submitted_at, created_at, form_values',
        )
        .eq('created_by', uid)
        .order('submitted_at', ascending: false)
        .limit(100);
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<Map<String, dynamic>?> getSubmission(String id) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return null;
    final row = await _client
        .from('pm_form_submissions')
        .select('*')
        .eq('id', id)
        .eq('created_by', uid)
        .maybeSingle();
    if (row == null) return null;
    return Map<String, dynamic>.from(row);
  }
}
