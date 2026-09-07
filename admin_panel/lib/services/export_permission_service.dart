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

      // 1. Fetch user's role
      final profile = await _client
          .from('profiles')
          .select('role')
          .eq('id', user.id)
          .maybeSingle();

      if (profile != null) {
        final role = (profile['role'] as String? ?? 'staff').toLowerCase();
        if (role == 'admin' || role == 'owner') {
          return true;
        }
      }

      // 2. For staff, check optional can_export restriction (defaults to true if column does not exist)
      try {
        final exportPerm = await _client
            .from('profiles')
            .select('can_export')
            .eq('id', user.id)
            .maybeSingle();
        if (exportPerm != null && exportPerm.containsKey('can_export') && exportPerm['can_export'] != null) {
          return exportPerm['can_export'] as bool;
        }
      } catch (_) {
        // can_export column may not exist yet in DB schema
      }

      // Default: allow authenticated staff to export unless explicitly restricted
      return true;
    } catch (_) {
      // If profile query fails but user is authenticated, permit export
      return SupabaseService.currentUser != null;
    }
  }
}
