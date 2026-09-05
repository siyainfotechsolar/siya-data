import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/consumer_record.dart';
import 'supabase_service.dart';

class PaginatedResult<T> {
  final List<T> items;
  final int totalCount;
  final int page;
  final int pageSize;

  PaginatedResult({
    required this.items,
    required this.totalCount,
    required this.page,
    required this.pageSize,
  });

  int get totalPages => (totalCount / pageSize).ceil();
  bool get hasNextPage => page < totalPages;
  bool get hasPreviousPage => page > 1;
}

class MobileRecordService {
  static SupabaseClient get _client => SupabaseService.client;

  /// Fetch active consumer records with optional status filter and search query
  static Future<PaginatedResult<ConsumerRecord>> fetchRecords({
    int page = 1,
    int pageSize = 20,
    String? searchQuery,
    String? statusFilter,
  }) async {
    try {
      final from = (page - 1) * pageSize;
      final to = from + pageSize - 1;

      var queryBuilder = _client
          .from('consumer_records')
          .select('*')
          .eq('deleted', false)
          .eq('is_merged', false);

      if (statusFilter != null && statusFilter.isNotEmpty && statusFilter != 'All') {
        queryBuilder = queryBuilder.eq('status', statusFilter);
      }

      if (searchQuery != null && searchQuery.trim().isNotEmpty) {
        final term = '%${searchQuery.trim()}%';
        queryBuilder = queryBuilder.or(
          'consumer_no.ilike.$term,name.ilike.$term,mobile.ilike.$term,application_id.ilike.$term',
        );
      }

      final response = await queryBuilder
          .order('updated_at', ascending: false)
          .range(from, to)
          .count(CountOption.exact);

      final List<dynamic> data = response.data;
      final int totalCount = response.count;

      final records = data
          .map((json) => ConsumerRecord.fromJson(json as Map<String, dynamic>))
          .toList();

      return PaginatedResult<ConsumerRecord>(
        items: records,
        totalCount: totalCount,
        page: page,
        pageSize: pageSize,
      );
    } catch (e, stack) {
      // ignore: avoid_print
      print('MobileRecordService.fetchRecords error: $e\n$stack');
      rethrow;
    }
  }

  /// Get record by ID
  static Future<ConsumerRecord?> getRecordById(String id) async {
    try {
      final response = await _client
          .from('consumer_records')
          .select('*')
          .eq('id', id)
          .maybeSingle();

      if (response == null) return null;
      return ConsumerRecord.fromJson(response);
    } catch (e) {
      return null;
    }
  }

  /// Update status and optional remarks from mobile app with audit trail
  static Future<ConsumerRecord> updateRecordStatus({
    required String id,
    required String consumerNo,
    required String oldStatus,
    required String newStatus,
    String? remarks,
  }) async {
    final user = SupabaseService.currentUser;
    final nowIso = DateTime.now().toUtc().toIso8601String();

    final updatePayload = <String, dynamic>{
      'status': newStatus,
      'updated_at': nowIso,
    };
    if (user != null) {
      updatePayload['updated_by'] = user.id;
    }
    if (remarks != null && remarks.trim().isNotEmpty) {
      updatePayload['remarks'] = remarks.trim();
    }

    final response = await _client
        .from('consumer_records')
        .update(updatePayload)
        .eq('id', id)
        .select()
        .single();

    final updated = ConsumerRecord.fromJson(response);

    // Create field-level audit log entry
    try {
      await _client.from('audit_logs').insert({
        'record_id': id,
        'consumer_no': consumerNo,
        'action': 'UPDATE',
        'field_name': 'Status',
        'old_value': oldStatus,
        'new_value': newStatus,
        'changed_by': user?.id,
        'source': 'Mobile App',
        'created_at': nowIso,
      });

      if (remarks != null && remarks.trim().isNotEmpty) {
        await _client.from('audit_logs').insert({
          'record_id': id,
          'consumer_no': consumerNo,
          'action': 'UPDATE',
          'field_name': 'Remarks',
          'old_value': null,
          'new_value': remarks.trim(),
          'changed_by': user?.id,
          'source': 'Mobile App',
          'created_at': nowIso,
        });
      }
    } catch (_) {
      // Audit log failures should not block successful record update
    }

    return updated;
  }

  /// Update individual workflow stages and values with audit logging
  static Future<ConsumerRecord> updateWorkflowStage({
    required ConsumerRecord record,
    String? applicationStatus,
    String? agreementStatus,
    String? loanRequired,
    String? loanStatus,
    String? installationStatus,
    String? installerTeam,
    String? rtsStatus,
    String? rtsApplicationId,
    String? subsidyStatus,
    String? remarks,
  }) async {
    final user = SupabaseService.currentUser;
    final nowIso = DateTime.now().toUtc().toIso8601String();

    final updatePayload = <String, dynamic>{
      'updated_at': nowIso,
    };
    if (user != null) {
      updatePayload['updated_by'] = user.id;
    }

    if (applicationStatus != null) updatePayload['application_status'] = applicationStatus;
    if (agreementStatus != null) updatePayload['agreement_status'] = agreementStatus;
    if (loanRequired != null) updatePayload['loan_required'] = loanRequired;
    if (loanStatus != null) updatePayload['loan_status'] = loanStatus;
    if (installationStatus != null) updatePayload['installation_status'] = installationStatus;
    if (installerTeam != null) updatePayload['installer_team'] = installerTeam;
    if (rtsStatus != null) updatePayload['rts_status'] = rtsStatus;
    if (rtsApplicationId != null) updatePayload['rts_application_id'] = rtsApplicationId;
    if (subsidyStatus != null) updatePayload['subsidy_status'] = subsidyStatus;
    if (remarks != null && remarks.trim().isNotEmpty) updatePayload['remarks'] = remarks.trim();

    final response = await _client
        .from('consumer_records')
        .update(updatePayload)
        .eq('id', record.id!)
        .select()
        .single();

    final updated = ConsumerRecord.fromJson(response);

    // Audit log
    try {
      await _client.from('audit_logs').insert({
        'record_id': record.id,
        'consumer_no': record.consumerNo,
        'action': 'WORKFLOW_UPDATE',
        'field_name': 'Workflow Stage',
        'old_value': record.overallStage,
        'new_value': updated.overallStage,
        'changed_by': user?.id,
        'source': 'Mobile App',
        'created_at': nowIso,
      });
    } catch (_) {}

    return updated;
  }

  /// Fetch current staff profile details
  static Future<Map<String, dynamic>?> getCurrentStaffProfile() async {
    try {
      final user = SupabaseService.currentUser;
      if (user == null) return null;

      final res = await _client
          .from('profiles')
          .select('*')
          .eq('id', user.id)
          .maybeSingle();

      return res;
    } catch (_) {
      return null;
    }
  }

  /// Summary counts for Mobile Dashboard
  static Future<Map<String, int>> fetchDashboardSummary() async {
    try {
      final totalRes = await _client
          .from('consumer_records')
          .select('id')
          .eq('deleted', false)
          .eq('is_merged', false)
          .count(CountOption.exact);

      final inProgressRes = await _client
          .from('consumer_records')
          .select('id')
          .eq('deleted', false)
          .eq('is_merged', false)
          .eq('status', 'In Progress')
          .count(CountOption.exact);

      final completedRes = await _client
          .from('consumer_records')
          .select('id')
          .eq('deleted', false)
          .eq('is_merged', false)
          .eq('status', 'Completed')
          .count(CountOption.exact);

      return {
        'total': totalRes.count,
        'inProgress': inProgressRes.count,
        'completed': completedRes.count,
      };
    } catch (_) {
      return {
        'total': 0,
        'inProgress': 0,
        'completed': 0,
      };
    }
  }

  /// Fetch Priority List summary counts for Mobile App
  static Future<Map<String, int>> fetchPrioritySummary() async {
    try {
      final activeRes = await _client
          .from('consumer_records')
          .select('*')
          .eq('deleted', false)
          .eq('is_merged', false)
          .neq('customer_work_state', 'COMPLETED')
          .not('status', 'ilike', 'completed')
          .not('status', 'ilike', 'cancelled')
          .not('application_status', 'ilike', 'completed')
          .not('application_status', 'ilike', 'cancelled')
          .not('subsidy_status', 'ilike', 'received')
          .not('subsidy_status', 'ilike', 'completed');

      int critical = 0;
      int high = 0;
      int medium = 0;
      int normal = 0;

      final List<dynamic> activeData = activeRes as List<dynamic>;
      for (final row in activeData) {
        final rec = ConsumerRecord.fromJson(row as Map<String, dynamic>);
        switch (rec.priorityLevel) {
          case PriorityLevel.critical:
            critical++;
            break;
          case PriorityLevel.high:
            high++;
            break;
          case PriorityLevel.medium:
            medium++;
            break;
          case PriorityLevel.normal:
            normal++;
            break;
          default:
            break;
        }
      }

      final totalOperationalActive = critical + high + medium + normal;

      return {
        'critical': critical,
        'high': high,
        'medium': medium,
        'normal': normal,
        'total': totalOperationalActive,
      };
    } catch (_) {
      return {'critical': 0, 'high': 0, 'medium': 0, 'normal': 0, 'total': 0};
    }
  }

  /// Fetch active applications for Mobile Priority List sorted by Priority Rank & Application Days DESC
  static Future<List<ConsumerRecord>> fetchPriorityRecords({
    String? priorityFilter,
  }) async {
    try {
      var queryBuilder = _client
          .from('consumer_records')
          .select('*')
          .eq('deleted', false)
          .eq('is_merged', false)
          .neq('customer_work_state', 'COMPLETED')
          .not('status', 'ilike', 'completed')
          .not('status', 'ilike', 'cancelled')
          .not('application_status', 'ilike', 'completed')
          .not('application_status', 'ilike', 'cancelled')
          .not('subsidy_status', 'ilike', 'received')
          .not('subsidy_status', 'ilike', 'completed');

      final response = await queryBuilder
          .order('submit_date', ascending: true, nullsFirst: false)
          .order('created_at', ascending: true);

      final List<dynamic> data = response as List<dynamic>;
      List<ConsumerRecord> records = data.map((j) => ConsumerRecord.fromJson(j as Map<String, dynamic>)).toList();

      // Exclude Completed & Subsidy Received
      records = records.where((r) => r.priorityLevel != PriorityLevel.none).toList();

      if (priorityFilter != null && priorityFilter.isNotEmpty && priorityFilter.toUpperCase() != 'ALL') {
        records = records.where((r) => r.priority.toUpperCase() == priorityFilter.toUpperCase()).toList();
      } else {
        // Exclude Subsidy Processing from Operational Active queue
        records = records.where((r) => r.priorityLevel != PriorityLevel.processing).toList();
      }

      records.sort((a, b) {
        final rankCmp = a.priorityLevel.rank.compareTo(b.priorityLevel.rank);
        if (rankCmp != 0) return rankCmp;
        return b.applicationDays.compareTo(a.applicationDays);
      });

      return records;
    } catch (e) {
      // ignore: avoid_print
      print('Error in MobileRecordService.fetchPriorityRecords: $e');
      return [];
    }
  }

  /// Mark customer work state as COMPLETED (removes from Priority List)
  static Future<ConsumerRecord> markCustomerAsComplete(String recordId) async {
    final user = SupabaseService.currentUser;
    final nowIso = DateTime.now().toUtc().toIso8601String();

    final response = await _client
        .from('consumer_records')
        .update({
          'customer_work_state': 'COMPLETED',
          'updated_at': nowIso,
          'updated_by': user?.id,
        })
        .eq('id', recordId)
        .select()
        .single();

    final updated = ConsumerRecord.fromJson(response);

    try {
      await _client.from('audit_logs').insert({
        'record_id': recordId,
        'consumer_no': updated.consumerNo,
        'action': 'MARK_AS_COMPLETE',
        'field_name': 'customer_work_state',
        'old_value': 'ACTIVE',
        'new_value': 'COMPLETED',
        'changed_by': user?.id,
        'source': 'Mobile App',
        'created_at': nowIso,
      });
    } catch (_) {}

    return updated;
  }

  /// Reopen customer work state back to ACTIVE (returns to priority list)
  static Future<ConsumerRecord> reopenCustomer(String recordId) async {
    final user = SupabaseService.currentUser;
    final nowIso = DateTime.now().toUtc().toIso8601String();

    final response = await _client
        .from('consumer_records')
        .update({
          'customer_work_state': 'ACTIVE',
          'updated_at': nowIso,
          'updated_by': user?.id,
        })
        .eq('id', recordId)
        .select()
        .single();

    final updated = ConsumerRecord.fromJson(response);

    try {
      await _client.from('audit_logs').insert({
        'record_id': recordId,
        'consumer_no': updated.consumerNo,
        'action': 'REOPEN_CUSTOMER',
        'field_name': 'customer_work_state',
        'old_value': 'COMPLETED',
        'new_value': 'ACTIVE',
        'changed_by': user?.id,
        'source': 'Mobile App',
        'created_at': nowIso,
      });
    } catch (_) {}

    return updated;
  }
}
