import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_profile.dart';
import 'supabase_service.dart';

class UserManagementService {
  static SupabaseClient get _client => SupabaseService.client;

  /// Fetch all registered user profiles
  static Future<List<UserProfile>> fetchAllUsers() async {
    try {
      final response = await _client
          .from('profiles')
          .select('*')
          .order('role', ascending: true)
          .order('created_at', ascending: false);

      final List<dynamic> data = response as List<dynamic>;
      return data.map((json) => UserProfile.fromJson(json as Map<String, dynamic>)).toList();
    } catch (e, stack) {
      // ignore: avoid_print
      print('Error in UserManagementService.fetchAllUsers: $e\n$stack');
      rethrow;
    }
  }

  /// Update user role ('admin' or 'staff')
  static Future<void> updateUserRole(String userId, String newRole) async {
    final currentUser = SupabaseService.currentUser;
    if (currentUser != null && currentUser.id == userId && newRole != 'admin') {
      throw Exception('Self-demotion protection: You cannot remove your own admin status.');
    }

    await _client.from('profiles').update({
      'role': newRole,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', userId);
  }

  /// Toggle user active state
  static Future<void> toggleUserActive(String userId, bool isActive) async {
    final currentUser = SupabaseService.currentUser;
    if (currentUser != null && currentUser.id == userId && !isActive) {
      throw Exception('Self-lockout protection: You cannot deactivate your own account.');
    }

    await _client.from('profiles').update({
      'is_active': isActive,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', userId);
  }

  /// Toggle can_delete permission
  static Future<void> toggleDeletePermission(String userId, bool canDelete) async {
    await _client.from('profiles').update({
      'can_delete': canDelete,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', userId);
  }
}
