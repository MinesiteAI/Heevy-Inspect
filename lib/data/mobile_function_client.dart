import 'package:supabase_flutter/supabase_flutter.dart';

/// Thrown when the Supabase session is missing or edge functions return 401.
class MobileAuthException implements Exception {
  const MobileAuthException(this.message);

  final String message;

  @override
  String toString() => message;
}

bool isMobileAuthError(Object error) {
  final msg = error.toString().toLowerCase();
  return error is MobileAuthException ||
      msg.contains('session expired') ||
      msg.contains('unauthorized') ||
      msg.contains('401');
}

/// Refreshes JWT and invokes Heevy Inspect edge functions with explicit auth.
class MobileFunctionClient {
  MobileFunctionClient(this._client);

  final SupabaseClient _client;

  Future<FunctionResponse> invoke(
    String name, {
    Map<String, dynamic>? body,
  }) async {
    try {
      await _client.auth.refreshSession();
    } catch (_) {
      // Use existing session if refresh fails transiently.
    }

    final token = _client.auth.currentSession?.accessToken;
    if (token == null || token.isEmpty) {
      throw const MobileAuthException('Session expired — sign in again.');
    }

    final res = await _client.functions.invoke(
      name,
      body: body ?? {},
      headers: {'Authorization': 'Bearer $token'},
    );

    if (res.status == 401) {
      throw const MobileAuthException('Session expired — sign in again.');
    }

    return res;
  }
}
