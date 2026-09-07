import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';

class ExportPermissionService {
  static SupabaseClient get _client => SupabaseService.client;

  /// Check if current authenticated user has permission to export Excel reports.
  /// Admins/owners: always allowed.
  /// Staff: allowed by default, but can be restricted via 'can_export' profile flag.
  /// Fails closed (returns false) on errors or missing profile.
  static Future<bool> canCurrentUserExport() async {
    try {
      final user = SupabaseService.currentUser;
      if (user == null) return false;

      final res = await _client
          .from('profiles')
          .select('role, can_export')
          .eq('id', user.id)
          .maybeSingle();

      if (res == null) return false; // No profile found → deny access

      final role = (res['role'] as String? ?? 'staff').toLowerCase();

      // Admins and owners always allowed
      if (role == 'admin' || role == 'owner') {
        return true;
      }

      // Staff: check can_export flag (default true if column doesn't exist yet)
      final canExport = res['can_export'] as bool? ?? true;
      return canExport;
    } catch (_) {
      // Fail closed: deny on error
      return false;
    }
  }
}
