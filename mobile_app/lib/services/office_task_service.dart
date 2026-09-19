import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/office_task.dart';
import 'supabase_service.dart';
import 'app_database.dart';
import 'connectivity_service.dart';

class MobileOfficeTaskService {
  static SupabaseClient get _client => SupabaseService.client;

  /// Upload an attachment for an office task
  static Future<String?> uploadTaskFile(File file) async {
    try {
      final fileName = 'office_task_${DateTime.now().millisecondsSinceEpoch}_${file.uri.pathSegments.last}';
      final path = 'office_tasks/$fileName';
      await _client.storage.from('customer-documents').upload(path, file);
      return _client.storage.from('customer-documents').getPublicUrl(path);
    } catch (e) {
      debugPrint('Error uploading task file: $e');
      return null;
    }
  }

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

  /// Create a new Office Task (online with offline cache)
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
    final currentUser = SupabaseService.currentUser;
    final createdByName = currentUser?.email?.split('@').first ?? 'Staff';
    final now = DateTime.now();

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
      'created_at': now.toIso8601String(),
      'updated_at': now.toIso8601String(),
    };

    if (ConnectivityService.isOnline) {
      try {
        final response = await _client
            .from('tasks')
            .insert(taskData)
            .select()
            .single();

        final createdTask = OfficeTask.fromMap(response);

        // Cache locally for offline availability
        await AppDatabase.upsertOfficeTask(createdTask);

        // Initial assignment record
        await _client.from('task_assignments').insert({
          'task_id': createdTask.id,
          'staff_id': assignedToId,
          'staff_name': assignedToName.trim(),
          'assigned_by': currentUser?.id,
          'assigned_by_name': createdByName,
          'status': 'Assigned',
          'remarks': 'Task created and assigned to ${assignedToName.trim()}',
        });

        return createdTask;
      } catch (e) {
        debugPrint('Failed to create task online, saving locally: $e');
      }
    }

    // Offline creation fallback
    final localId = 'task_local_${now.millisecondsSinceEpoch}';
    final offlineTask = OfficeTask.fromMap({
      ...taskData,
      'id': localId,
    });
    await AppDatabase.upsertOfficeTask(offlineTask);
    return offlineTask;
  }

  /// Fetch tasks assigned to the current logged-in office staff member
  static Future<List<OfficeTask>> fetchMyTasks() async {
    final user = SupabaseService.currentUser;
    final email = user?.email?.toLowerCase();
    String? staffName;

    // Try finding user's profile display name
    try {
      if (user != null) {
        final profile = await _client
            .from('profiles')
            .select('full_name')
            .eq('id', user.id)
            .maybeSingle();
        staffName = profile?['full_name'] as String?;
      }
    } catch (_) {}

    final effectiveName = (staffName != null && staffName.trim().isNotEmpty)
        ? staffName.trim()
        : (email?.split('@').first ?? 'Staff');

    return await fetchTasks(staffName: effectiveName);
  }

  /// Fetch all tasks with optional filters (Supabase with SQLite caching)
  static Future<List<OfficeTask>> fetchTasks({
    String? staffName,
    String? status,
    String? taskType,
    String? searchQuery,
    int limit = 150,
  }) async {
    if (ConnectivityService.isOnline) {
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

        final res = await query.order('created_at', ascending: false).limit(limit);
        final list = (res as List).map((m) => OfficeTask.fromMap(m)).toList();

        // Update local SQLite cache
        await AppDatabase.upsertOfficeTasks(list);

        return _filterTasksLocally(list, searchQuery);
      } catch (e) {
        debugPrint('Failed to fetch tasks online, using SQLite cache: $e');
      }
    }

    // Offline: load from SQLite cache
    final cached = await AppDatabase.getCachedOfficeTasks(
      staffName: staffName,
      status: status,
    );
    return _filterTasksLocally(cached, searchQuery);
  }

  static List<OfficeTask> _filterTasksLocally(List<OfficeTask> list, String? query) {
    if (query == null || query.trim().isEmpty) return list;
    final q = query.toLowerCase().trim();
    return list.where((t) {
      return t.title.toLowerCase().contains(q) ||
          t.customerName.toLowerCase().contains(q) ||
          t.consumerNo.toLowerCase().contains(q) ||
          (t.village?.toLowerCase().contains(q) ?? false) ||
          t.assignedToName.toLowerCase().contains(q);
    }).toList();
  }

  /// Update task status (Start, Hold, Complete, Add Note)
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
    final now = DateTime.now();
    final updatedTask = task.copyWith(
      status: newStatus,
      startedAt: (newStatus == OfficeTaskStatus.inProgress && task.startedAt == null)
          ? now
          : task.startedAt,
      completedAt: newStatus == OfficeTaskStatus.completed ? now : task.completedAt,
      completionNote: completionNote ?? task.completionNote,
      holdReason: holdReason ?? task.holdReason,
      attachmentUrl: attachmentUrl ?? task.attachmentUrl,
    );

    // Save locally immediately
    await AppDatabase.upsertOfficeTask(updatedTask);

    // Update server if online
    if (ConnectivityService.isOnline) {
      try {
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

        await _client.from('tasks').update(updates).eq('id', task.id);

        // Record assignment/work log entry
        await _client.from('task_assignments').insert({
          'task_id': task.id,
          'staff_id': staffId ?? task.assignedToId,
          'staff_name': staffName,
          'status': newStatus,
          'started_at': newStatus == OfficeTaskStatus.inProgress ? now.toIso8601String() : null,
          'completed_at': newStatus == OfficeTaskStatus.completed ? now.toIso8601String() : null,
          'remarks': remarks ?? completionNote ?? holdReason ?? 'Status changed to $newStatus',
        });
      } catch (e) {
        debugPrint('Failed to update task on server: $e');
      }
    }

    return updatedTask;
  }
}
