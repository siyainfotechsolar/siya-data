import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_profile.dart';
import '../models/staff_workload_model.dart';
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

  /// Create a new User via Supabase Auth & Profile record
  static Future<void> createUser({
    required String fullName,
    required String mobile,
    required String email,
    required String role,
    String? employeeId,
    String? department,
    String status = 'Active',
    Map<String, List<String>>? permissions,
    String? remarks,
    String? temporaryPassword,
  }) async {
    try {
      final currentAdmin = SupabaseService.currentUser;
      final effectivePassword = (temporaryPassword != null && temporaryPassword.trim().length >= 6)
          ? temporaryPassword.trim()
          : 'Siya@${mobile.length >= 4 ? mobile.substring(mobile.length - 4) : "2026"}';

      // 1. Sign up user using Supabase Auth
      final authResponse = await _client.auth.signUp(
        email: email.trim(),
        password: effectivePassword,
        data: {
          'full_name': fullName.trim(),
          'role': role,
          'mobile': mobile.trim(),
        },
      );

      final newUserId = authResponse.user?.id;
      if (newUserId != null) {
        // 2. Upsert profile with full metadata
        final perms = permissions ?? UserRole.defaultPermissions(role);
        await _client.from('profiles').upsert({
          'id': newUserId,
          'email': email.trim(),
          'full_name': fullName.trim(),
          'role': role,
          'mobile': mobile.trim(),
          'employee_id': employeeId?.trim().isEmpty == true ? null : employeeId?.trim(),
          'department': department?.trim().isEmpty == true ? null : department?.trim(),
          'status': status,
          'is_active': status == 'Active',
          'can_delete': role == 'admin' || role == 'super_admin' || role == 'owner',
          'permissions': perms,
          'remarks': remarks?.trim().isEmpty == true ? null : remarks?.trim(),
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        });

        // 3. Log to audit_logs
        await _logAudit(
          action: 'USER_CREATED',
          targetUser: fullName.trim(),
          fieldName: 'account',
          oldVal: null,
          newVal: 'Role: $role, Mobile: $mobile, Status: $status',
          changedBy: currentAdmin?.id,
        );
      }
    } catch (e, stack) {
      // ignore: avoid_print
      print('Error in UserManagementService.createUser: $e\n$stack');
      rethrow;
    }
  }

  /// Update existing user profile, permissions, status, etc.
  static Future<void> updateUser({
    required String userId,
    required String fullName,
    required String mobile,
    required String email,
    required String role,
    String? employeeId,
    String? department,
    required String status,
    required Map<String, List<String>> permissions,
    String? remarks,
  }) async {
    try {
      final currentAdmin = SupabaseService.currentUser;
      if (currentAdmin != null && currentAdmin.id == userId) {
        if (role != 'admin' && role != 'super_admin') {
          throw Exception('Self-demotion protection: You cannot remove your own admin status.');
        }
        if (status != 'Active') {
          throw Exception('Self-lockout protection: You cannot deactivate or suspend your own account.');
        }
      }

      // Fetch previous profile for audit diff
      final prevList = await _client.from('profiles').select().eq('id', userId).limit(1);
      final prev = prevList.isNotEmpty ? prevList.first as Map<String, dynamic> : null;

      final updatePayload = {
        'full_name': fullName.trim(),
        'mobile': mobile.trim(),
        'role': role,
        'employee_id': employeeId?.trim().isEmpty == true ? null : employeeId?.trim(),
        'department': department?.trim().isEmpty == true ? null : department?.trim(),
        'status': status,
        'is_active': status == 'Active',
        'permissions': permissions,
        'remarks': remarks?.trim().isEmpty == true ? null : remarks?.trim(),
        'updated_at': DateTime.now().toIso8601String(),
      };

      await _client.from('profiles').update(updatePayload).eq('id', userId);

      // Audit tracking
      if (prev != null) {
        if (prev['role'] != role) {
          await _logAudit(
            action: 'ROLE_CHANGED',
            targetUser: fullName,
            fieldName: 'role',
            oldVal: prev['role']?.toString(),
            newVal: role,
            changedBy: currentAdmin?.id,
          );
        }
        if (prev['status'] != status) {
          await _logAudit(
            action: status == 'Active' ? 'USER_ACTIVATED' : 'USER_DEACTIVATED',
            targetUser: fullName,
            fieldName: 'status',
            oldVal: prev['status']?.toString(),
            newVal: status,
            changedBy: currentAdmin?.id,
          );
        }
      }

      await _logAudit(
        action: 'USER_UPDATED',
        targetUser: fullName,
        fieldName: 'profile',
        oldVal: null,
        newVal: 'Updated profile attributes & permissions for $email',
        changedBy: currentAdmin?.id,
      );
    } catch (e, stack) {
      // ignore: avoid_print
      print('Error in UserManagementService.updateUser: $e\n$stack');
      rethrow;
    }
  }

  /// Update user role
  static Future<void> updateUserRole(String userId, String newRole) async {
    final currentUser = SupabaseService.currentUser;
    if (currentUser != null && currentUser.id == userId && newRole != 'admin' && newRole != 'super_admin') {
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

    final newStatus = isActive ? 'Active' : 'Inactive';

    await _client.from('profiles').update({
      'is_active': isActive,
      'status': newStatus,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', userId);

    await _logAudit(
      action: isActive ? 'USER_ACTIVATED' : 'USER_DEACTIVATED',
      targetUser: userId,
      fieldName: 'status',
      oldVal: null,
      newVal: newStatus,
      changedBy: currentUser?.id,
    );
  }

  /// Toggle can_delete permission
  static Future<void> toggleDeletePermission(String userId, bool canDelete) async {
    await _client.from('profiles').update({
      'can_delete': canDelete,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', userId);
  }

  /// Trigger secure password reset link via Supabase Auth
  static Future<void> sendPasswordResetEmail(String email) async {
    if (email.trim().isEmpty) {
      throw Exception('Email address is required to send password reset link.');
    }
    await _client.auth.resetPasswordForEmail(email.trim());
  }

  /// Intelligent Workload Engine: Aggregates workload across tasks, issues, and customers
  static Future<List<StaffWorkload>> fetchWorkloadMetrics(List<UserProfile> users) async {
    try {
      // 1. Fetch active consumer records to aggregate assigned counts
      final consumerRows = await _client
          .from('consumer_records')
          .select('id, assigned_staff, installer_team, status, customer_work_state, has_active_followup, expected_followup_date')
          .eq('deleted', false);

      // 2. Fetch open customer issues
      final issuesRows = await _client
          .from('customer_issues')
          .select('id, assigned_staff, status')
          .inFilter('status', ['New', 'Assigned', 'In Progress', 'Hold']);

      final List<dynamic> consumers = consumerRows as List<dynamic>;
      final List<dynamic> issues = issuesRows as List<dynamic>;

      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day);
      final todayEnd = todayStart.add(const Duration(days: 1));

      return users.map((user) {
        final staffName = user.fullName?.trim() ?? user.email.split('@').first;
        final staffLower = staffName.toLowerCase();

        int assignedCustomers = 0;
        int pendingActions = 0;
        int todayFollowups = 0;
        int overdueFollowups = 0;
        int installationTasks = 0;
        int completedTasks = 0;

        for (final row in consumers) {
          final m = row as Map<String, dynamic>;
          final assigned = (m['assigned_staff'] as String? ?? '').toLowerCase();
          final installer = (m['installer_team'] as String? ?? '').toLowerCase();
          final workState = (m['customer_work_state'] as String? ?? 'ACTIVE').toUpperCase();
          final status = (m['status'] as String? ?? '').toLowerCase();

          final isAssigned = assigned.contains(staffLower) || installer.contains(staffLower);

          if (isAssigned) {
            if (workState == 'COMPLETED') {
              completedTasks++;
            } else {
              assignedCustomers++;

              if (workState == 'ACTIVE') {
                pendingActions++;
              }

              if (installer.contains(staffLower) || status.contains('install')) {
                installationTasks++;
              }

              if (m['has_active_followup'] == true && m['expected_followup_date'] != null) {
                final fDate = DateTime.tryParse(m['expected_followup_date'].toString());
                if (fDate != null) {
                  if (fDate.isBefore(todayStart)) {
                    overdueFollowups++;
                  } else if (fDate.isAfter(todayStart.subtract(const Duration(seconds: 1))) &&
                      fDate.isBefore(todayEnd)) {
                    todayFollowups++;
                  }
                }
              }
            }
          }
        }

        // Aggregate open issues assigned to this staff member
        int openIssues = 0;
        for (final row in issues) {
          final m = row as Map<String, dynamic>;
          final issueStaff = (m['assigned_staff'] as String? ?? '').toLowerCase();
          if (issueStaff.contains(staffLower)) {
            openIssues++;
          }
        }

        return StaffWorkload(
          staffId: user.id,
          staffName: staffName,
          email: user.email,
          role: UserRole.displayName(user.role),
          department: user.department,
          status: user.status,
          assignedCustomersCount: assignedCustomers,
          pendingActionsCount: pendingActions,
          overdueFollowupsCount: overdueFollowups,
          todayFollowupsCount: todayFollowups,
          openIssuesCount: openIssues,
          installationTasksCount: installationTasks,
          completedTasksCount: completedTasks,
        );
      }).toList();
    } catch (e, stack) {
      // ignore: avoid_print
      print('Error in UserManagementService.fetchWorkloadMetrics: $e\n$stack');
      return [];
    }
  }

  static Future<void> _logAudit({
    required String action,
    required String targetUser,
    String? fieldName,
    String? oldVal,
    String? newVal,
    String? changedBy,
  }) async {
    try {
      await _client.from('audit_logs').insert({
        'action': action,
        'consumer_no': targetUser,
        'field_name': fieldName,
        'old_value': oldVal,
        'new_value': newVal,
        'changed_by': changedBy,
        'source': 'Admin User Management',
        'created_at': DateTime.now().toIso8601String(),
      });
    } catch (_) {
      // Fail-soft for audit write
    }
  }
}

