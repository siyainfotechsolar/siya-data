import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/office_task.dart';
import 'supabase_service.dart';

class OfficeTaskService {
  static SupabaseClient get _client => SupabaseService.client;

  /// Fetch active office staff members specifically eligible for task assignment
  static Future<List<Map<String, String>>> fetchActiveOfficeStaff() async {
    try {
      final res = await _client
          .from('profiles')
          .select('id, full_name, email, role, status, is_active')
          .eq('status', 'Active')
          .order('role', ascending: false)
          .order('full_name', ascending: true);

      final List<Map<String, String>> staffList = [];
      for (final row in res) {
        final isActive = row['is_active'] as bool? ?? true;
        if (!isActive) continue;

        final role = (row['role'] as String? ?? 'staff').toLowerCase();
        // Allow office_staff, staff, and admin
        if (role != 'office_staff' && role != 'staff' && role != 'admin') continue;

        final fullName = (row['full_name'] as String?)?.trim();
        final email = (row['email'] as String?)?.trim() ?? '';
        final displayName = (fullName != null && fullName.isNotEmpty)
            ? fullName
            : (email.isNotEmpty ? email.split('@').first : 'Staff');

        staffList.add({
          'id': row['id']?.toString() ?? '',
          'name': displayName,
          'email': email,
          'role': role,
        });
      }
      return staffList;
    } catch (e, stack) {
      debugPrint('Error fetching active office staff: $e\n$stack');
      return [];
    }
  }

  /// Upload a file attachment for an office task to Supabase storage
  static Future<String> uploadTaskAttachment({
    required Uint8List bytes,
    required String fileName,
  }) async {
    final cleanName = fileName.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
    final storagePath = 'office_tasks/${DateTime.now().millisecondsSinceEpoch}_$cleanName';
    await _client.storage.from('customer-documents').uploadBinary(
      storagePath,
      bytes,
    );
    return _client.storage.from('customer-documents').getPublicUrl(storagePath);
  }

  /// Create a new Office Task and assign to an Office Staff member
  static Future<OfficeTask> createTask({
    String? customerId,
    required String customerName,
    required String consumerNo,
    String? village,
    required String title,
    required String taskType,
    String? description,
    String priority = OfficeTaskPriority.normal,
    DateTime? dueDate,
    String? assignedToId,
    required String assignedToName,
    String? attachmentUrl,
  }) async {
    try {
      final currentUser = SupabaseService.currentUser;
      final createdByName = currentUser?.email?.split('@').first ?? 'Admin';

      final taskData = {
        'customer_id': customerId,
        'customer_name': customerName.trim(),
        'consumer_no': consumerNo.trim(),
        'village': village?.trim(),
        'title': title.trim(),
        'task_type': taskType,
        'description': description?.trim(),
        'priority': priority,
        'status': OfficeTaskStatus.pending,
        'due_date': dueDate?.toIso8601String().split('T').first,
        'assigned_to_id': assignedToId,
        'assigned_to_name': assignedToName.trim(),
        'created_by': currentUser?.id,
        'created_by_name': createdByName,
        if (attachmentUrl != null && attachmentUrl.isNotEmpty)
          'attachment_url': attachmentUrl,
      };

      final response = await _client
          .from('tasks')
          .insert(taskData)
          .select()
          .single();

      final createdTask = OfficeTask.fromMap(response);

      // Create initial assignment record for audit history
      await _client.from('task_assignments').insert({
        'task_id': createdTask.id,
        'staff_id': assignedToId,
        'staff_name': assignedToName.trim(),
        'assigned_by': currentUser?.id,
        'assigned_by_name': createdByName,
        'status': 'Assigned',
        'remarks': 'Initial task assignment by $createdByName',
      });

      return createdTask;
    } catch (e, stack) {
      debugPrint('Error creating office task: $e\n$stack');
      rethrow;
    }
  }

  /// Fetch tasks with filters
  static Future<List<OfficeTask>> fetchTasks({
    String? staffName,
    String? status,
    String? taskType,
    String? searchQuery,
    String? village,
    DateTime? date,
    int limit = 150,
  }) async {
    try {
      var query = _client.from('tasks').select();

      if (status != null && status != 'ALL' && status.isNotEmpty) {
        query = query.eq('status', status);
      }
      if (taskType != null && taskType != 'ALL' && taskType.isNotEmpty) {
        query = query.eq('task_type', taskType);
      }
      if (staffName != null && staffName != 'ALL' && staffName.isNotEmpty) {
        query = query.eq('assigned_to_name', staffName);
      }
      if (village != null && village != 'ALL' && village.isNotEmpty) {
        query = query.eq('village', village);
      }
      if (date != null) {
        final dateStr = date.toIso8601String().split('T').first;
        query = query.eq('due_date', dateStr);
      }

      final res = await query.order('created_at', ascending: false).limit(limit);
      var list = (res as List).map((m) => OfficeTask.fromMap(m)).toList();

      if (searchQuery != null && searchQuery.trim().isNotEmpty) {
        final q = searchQuery.toLowerCase().trim();
        list = list.where((t) {
          return t.title.toLowerCase().contains(q) ||
              t.customerName.toLowerCase().contains(q) ||
              t.consumerNo.toLowerCase().contains(q) ||
              (t.village?.toLowerCase().contains(q) ?? false) ||
              t.assignedToName.toLowerCase().contains(q);
        }).toList();
      }

      return list;
    } catch (e, stack) {
      debugPrint('Error fetching office tasks: $e\n$stack');
      return [];
    }
  }

  /// Update task status (Start, Hold, Complete, Add Note) and log work entry
  static Future<OfficeTask> updateTaskStatus({
    required OfficeTask task,
    required String newStatus,
    String? remarks,
    String? completionNote,
    String? holdReason,
    String? attachmentUrl,
    required String staffName,
    String? staffId,
  }) async {
    try {
      final now = DateTime.now();
      final updates = <String, dynamic>{
        'status': newStatus,
        'updated_at': now.toIso8601String(),
      };

      if (newStatus == OfficeTaskStatus.inProgress && task.startedAt == null) {
        updates['started_at'] = now.toIso8601String();
      } else if (newStatus == OfficeTaskStatus.completed) {
        updates['completed_at'] = now.toIso8601String();
        if (completionNote != null) updates['completion_note'] = completionNote;
        if (attachmentUrl != null) updates['attachment_url'] = attachmentUrl;
      } else if (newStatus == OfficeTaskStatus.hold) {
        if (holdReason != null) updates['hold_reason'] = holdReason;
      }

      final res = await _client
          .from('tasks')
          .update(updates)
          .eq('id', task.id)
          .select()
          .single();

      final updatedTask = OfficeTask.fromMap(res);

      // Record work log entry
      await _client.from('task_assignments').insert({
        'task_id': task.id,
        'staff_id': staffId ?? task.assignedToId,
        'staff_name': staffName,
        'status': newStatus,
        'started_at': newStatus == OfficeTaskStatus.inProgress ? now.toIso8601String() : null,
        'completed_at': newStatus == OfficeTaskStatus.completed ? now.toIso8601String() : null,
        'remarks': remarks ?? completionNote ?? holdReason ?? 'Status changed to $newStatus',
      });

      return updatedTask;
    } catch (e, stack) {
      debugPrint('Error updating task status: $e\n$stack');
      rethrow;
    }
  }

  /// Reassign task from one office staff member to another with complete audit logging
  static Future<OfficeTask> reassignTask({
    required OfficeTask task,
    required String newStaffId,
    required String newStaffName,
    String? reason,
  }) async {
    try {
      final currentUser = SupabaseService.currentUser;
      final assignedByName = currentUser?.email?.split('@').first ?? 'Admin';
      final now = DateTime.now();

      final res = await _client
          .from('tasks')
          .update({
            'assigned_to_id': newStaffId,
            'assigned_to_name': newStaffName.trim(),
            'updated_at': now.toIso8601String(),
          })
          .eq('id', task.id)
          .select()
          .single();

      final reassignedTask = OfficeTask.fromMap(res);

      // Insert reassignment log in task_assignments
      await _client.from('task_assignments').insert({
        'task_id': task.id,
        'staff_id': newStaffId,
        'staff_name': newStaffName.trim(),
        'assigned_by': currentUser?.id,
        'assigned_by_name': assignedByName,
        'status': 'Reassigned',
        'remarks': 'Reassigned from ${task.assignedToName} to $newStaffName. Reason: ${reason ?? "Staff reassignment"}',
      });

      return reassignedTask;
    } catch (e, stack) {
      debugPrint('Error reassigning task: $e\n$stack');
      rethrow;
    }
  }

  /// Fetch work log history for audit ("Who worked on which customer/task?")
  static Future<List<TaskAssignment>> fetchWorkLog({String? taskId}) async {
    try {
      var query = _client.from('task_assignments').select();
      if (taskId != null && taskId.isNotEmpty) {
        query = query.eq('task_id', taskId);
      }
      final res = await query.order('created_at', ascending: false).limit(100);
      return (res as List).map((m) => TaskAssignment.fromMap(m)).toList();
    } catch (e, stack) {
      debugPrint('Error fetching work log: $e\n$stack');
      return [];
    }
  }
}
