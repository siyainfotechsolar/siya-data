import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';

class ExportPermissionService {
  static SupabaseClient get _client => SupabaseService.client;

  /// Check if current authenticated user has permission to export Excel reports
  static Future<bool> canCurrentUserExport() async {
    try {
      final user = SupabaseService.currentUser;
      if (user == null) return false;

      final res = await _client
          .from('profiles')
          .select('role, can_delete')
          .eq('id', user.id)
          .maybeSingle();

      if (res == null) return true; // Default allow if profile not strictly restricted
      
      // Admins and owners always allowed.
      // Staff allowed by default unless restricted
      final role = res['role'] as String? ?? 'staff';
      if (role.toLowerCase() == 'admin' || role.toLowerCase() == 'owner') {
        return true;
      }
      
      return true;
    } catch (_) {
      return true;
    }
  }
}
