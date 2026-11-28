import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/app_config.dart';

class SupabaseService {
  static SupabaseClient get client => Supabase.instance.client;

  static Future<void> initialize() async {
    try {
      await Supabase.initialize(
        url: AppConfig.supabaseUrl,
        anonKey: AppConfig.supabaseAnonKey,
      );
    } catch (e) {
      // Allow app to run in placeholder mode during development
    }
  }

  static User? get currentUser {
    try {
      return client.auth.currentUser;
    } catch (_) {
      return null;
    }
  }

  static bool get isAuthenticated => currentUser != null;

  /// Resolves an Email Address, 10-digit Mobile Number, or Sub-Vendor Code
  /// into the user's Supabase Auth login email.
  static Future<String> resolveLoginEmail(String rawIdentifier) async {
    final trimmed = rawIdentifier.trim();
    if (trimmed.contains('@')) {
      return trimmed.toLowerCase();
    }

    try {
      final res = await client.rpc(
        'resolve_login_email',
        params: {'p_identifier': trimmed},
      );
      final resolved = res?.toString().trim() ?? '';
      if (resolved.isNotEmpty && resolved.contains('@')) {
        return resolved.toLowerCase();
      }
    } catch (_) {
      // Fallback cleanly when RPC is not yet applied or offline
    }

    final digitsOnly = trimmed.replaceAll(RegExp(r'[^0-9]'), '');
    if (digitsOnly.length >= 10) {
      return '${digitsOnly.substring(digitsOnly.length - 10)}@vendor.siyasolar.com';
    }
    final clean = trimmed.replaceAll(RegExp(r'[^0-9a-zA-Z]'), '').toLowerCase();
    return '$clean@vendor.siyasolar.com';
  }

  static Future<AuthResponse> signInWithEmailPassword({
    required String email,
    required String password,
  }) async {
    return await client.auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );
  }

  static Future<void> resetPassword(String email) async {
    await client.auth.resetPasswordForEmail(email.trim());
  }

  static Future<void> signOut() async {
    await client.auth.signOut();
  }
}
