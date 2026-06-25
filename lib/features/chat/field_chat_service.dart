import 'package:supabase_flutter/supabase_flutter.dart';

class FieldChatService {
  FieldChatService(this._client);

  final SupabaseClient _client;

  Future<({String? conversationId, String reply})> sendMessage({
    required String message,
    String? conversationId,
    String? sourceType,
    String? sourceId,
  }) async {
    final res = await _client.functions.invoke(
      'mobile-field-chat',
      body: {
        'message': message,
        if (conversationId != null) 'conversation_id': conversationId,
        if (sourceType != null) 'source_type': sourceType,
        if (sourceId != null) 'source_id': sourceId,
      },
    );
    if (res.status >= 400) {
      final err = res.data is Map ? res.data['error'] : res.data;
      throw Exception(err?.toString() ?? 'Chat failed');
    }
    final data = res.data as Map;
    return (
      conversationId: data['conversation_id']?.toString(),
      reply: data['reply']?.toString() ?? '',
    );
  }
}
