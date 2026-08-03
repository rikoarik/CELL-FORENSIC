import 'package:supabase_flutter/supabase_flutter.dart';

/// Supabase bootstrap for the student/teacher apps.
///
/// Offline-first: when URL/key are empty, [isConfigured] is false and the app
/// continues with the local [ContentPack] only (E1-04 / FR offline path).
class SupabaseConfig {
  const SupabaseConfig._();

  /// Override at build time:
  /// `flutter run --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...`
  static const url = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://ycxcpjjnwycteakxfppy.supabase.co',
  );

  /// Publishable key only — never service_role.
  static const publishableKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'sb_publishable_zVjn_CxpzwUCEuhbkkan5g_jnLH_V45',
  );

  static bool get isConfigured => url.isNotEmpty && publishableKey.isNotEmpty;

  static bool _initialized = false;

  static Future<void> ensureInitialized() async {
    if (!isConfigured || _initialized) return;
    await Supabase.initialize(url: url, publishableKey: publishableKey);
    _initialized = true;
  }

  static SupabaseClient? get clientOrNull {
    if (!isConfigured || !_initialized) return null;
    return Supabase.instance.client;
  }
}
