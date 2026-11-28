import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/app_config.dart';

class SupabaseService {
  static SupabaseClient get client => Supabase.instance.client;

  static Object? initError;

  static Future<void> initialize() async {
    // Only initialize if not already initialized
    try {
      await Supabase.initialize(
        url: AppConfig.supabaseUrl,
        anonKey: AppConfig.supabaseAnonKey,
      );
      initError = null;
    } catch (e) {
      initError = e;
      // Allow app to run in offline/placeholder mode during dev
    }
  }

  static User? get currentUser {
    try {
      return client.auth.currentUser;
    } catch (_) {
      return null;
    }
  }

  static Session? get currentSession {
    try {
      return client.auth.currentSession;
    } catch (_) {
      return null;
    }
  }

  static bool get isAuthenticated => currentUser != null;

  static bool get hasValidSession {
    final session = currentSession;
    if (session == null) return false;
    return !session.isExpired;
  }

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
      // Fallback safely when RPC is not yet deployed or offline
    }

    final digitsOnly = trimmed.replaceAll(RegExp(r'[^0-9]'), '');
    if (digitsOnly.length >= 10) {
      return '${digitsOnly.substring(digitsOnly.length - 10)}@vendor.siyasolar.com';
    }
    return '${trimmed.replaceAll(RegExp(r'\s+'), '').toLowerCase()}@vendor.siyasolar.com';
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

  /// Fetches profile for a specific user ID or the current user
  static Future<Map<String, dynamic>?> fetchProfile([String? userId]) async {
    final uid = userId ?? currentUser?.id;
    if (uid == null) return null;
    try {
      final res = await client
          .from('profiles')
          .select('*')
          .eq('id', uid)
          .maybeSingle();
      return res;
    } catch (e) {
      return null;
    }
  }

  static Future<void> resetPassword(String email) async {
    await client.auth.resetPasswordForEmail(email.trim());
  }

  static Future<void> signOut() async {
    try {
      await client.auth.signOut();
    } catch (_) {}
  }

  /// Records an authentication audit log event
  static Future<void> logAuthAudit({
    required String action,
    required String email,
    String? userId,
    String? details,
  }) async {
    try {
      await client.from('audit_logs').insert({
        'action': action,
        'consumer_no': email,
        'field_name': 'auth',
        'old_value': null,
        'new_value': details ?? action,
        'changed_by': userId ?? currentUser?.id,
        'source': 'Admin Web Login',
        'created_at': DateTime.now().toIso8601String(),
      });
    } catch (_) {
      // Fail-soft for audit logging
    }
  }
}
