abstract final class SupabaseConfig {
  static const String url = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://ribjmoizwcvowrbhbfri.supabase.co',
  );

  static const String anonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue:
        'sb_publishable_dJ_MAJyROywjh8bM_Es1Kw_cJXYasO7',
  );
}
