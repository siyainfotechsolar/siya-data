import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/consumer_record.dart';
import 'supabase_service.dart';
import 'workflow_engine.dart';


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

  /// Fetch Action Center summary counts for Mobile App
  static Future<Map<String, int>> fetchActionCenterSummary({String? staffFilter}) async {
    try {
      var queryBuilder = _client
          .from('consumer_records')
          .select('*')
          .eq('deleted', false)
          .eq('is_merged', false);

      if (staffFilter != null && staffFilter.trim().isNotEmpty && staffFilter.trim().toLowerCase() != 'all') {
        final st = staffFilter.trim();
        queryBuilder = queryBuilder.or('assigned_staff.ilike.%$st%,installer_team.ilike.%$st%');
      }

      final response = await queryBuilder;
      final List<dynamic> data = response as List<dynamic>;

      int agreementPending = 0;
      int loanPending = 0;
      int installationPending = 0;
      int rtsPending = 0;
      int subsidyProcessing = 0;
      int completed = 0;
      int noAction = 0;

      for (final row in data) {
        final rec = ConsumerRecord.fromJson(row as Map<String, dynamic>);
        if (rec.isNoActionRequired) {
          noAction++;
        } else if (rec.isCompletedState || rec.overallStage == 'Completed') {
          completed++;
        } else {
          final stage = WorkflowEngine.getCurrentWorkStage(rec);
          switch (stage) {
            case 'Agreement':
              agreementPending++;
              break;
            case 'Loan':
              loanPending++;
              break;
            case 'Installation':
              installationPending++;
              break;
            case 'RTS':
              rtsPending++;
              break;
            case 'Subsidy':
              subsidyProcessing++;
              break;
          }
        }
      }

      return {
        'agreementPending': agreementPending,
        'loanPending': loanPending,
        'installationPending': installationPending,
        'rtsPending': rtsPending,
        'subsidyProcessing': subsidyProcessing,
        'completed': completed,
        'noAction': noAction,
        'totalActive': agreementPending + loanPending + installationPending + rtsPending + subsidyProcessing,
      };
    } catch (_) {
      return {
        'agreementPending': 0,
        'loanPending': 0,
        'installationPending': 0,
        'rtsPending': 0,
        'subsidyProcessing': 0,
        'completed': 0,
        'noAction': 0,
        'totalActive': 0,
      };
    }
  }

  /// Backward-compatible alias for fetchActionCenterSummary
  static Future<Map<String, int>> fetchPrioritySummary() async {
    final summary = await fetchActionCenterSummary();
    return {
      'critical': summary['agreementPending'] ?? 0,
      'high': summary['loanPending'] ?? 0,
      'medium': summary['installationPending'] ?? 0,
      'normal': summary['rtsPending'] ?? 0,
      'total': summary['totalActive'] ?? 0,
    };
  }

  /// Fetch active applications for Mobile Action Center sorted by Days in Stage DESC & Application Days DESC
  static Future<List<ConsumerRecord>> fetchActionCenterRecords({
    String? stageFilter,
    String? assignedStaffFilter,
  }) async {
    try {
      var queryBuilder = _client
          .from('consumer_records')
          .select('*')
          .eq('deleted', false)
          .eq('is_merged', false);

      if (assignedStaffFilter != null && assignedStaffFilter.trim().isNotEmpty && assignedStaffFilter.trim().toLowerCase() != 'all') {
        final st = assignedStaffFilter.trim();
        queryBuilder = queryBuilder.or('assigned_staff.ilike.%$st%,installer_team.ilike.%$st%');
      }

      final response = await queryBuilder;
      final List<dynamic> data = response as List<dynamic>;
      List<ConsumerRecord> records = data.map((j) => ConsumerRecord.fromJson(j as Map<String, dynamic>)).toList();

      if (stageFilter != null && stageFilter.isNotEmpty && stageFilter.toUpperCase() != 'ALL') {
        final sf = stageFilter.trim().toLowerCase();
        if (sf.contains('agreement')) {
          records = records.where((r) => !r.isCompletedState && !r.isNoActionRequired && r.overallStage == 'Agreement').toList();
        } else if (sf.contains('loan')) {
          records = records.where((r) => !r.isCompletedState && !r.isNoActionRequired && r.overallStage == 'Loan').toList();
        } else if (sf.contains('installation')) {
          records = records.where((r) => !r.isCompletedState && !r.isNoActionRequired && r.overallStage == 'Installation').toList();
        } else if (sf.contains('rts')) {
          records = records.where((r) => !r.isCompletedState && !r.isNoActionRequired && r.overallStage == 'RTS').toList();
        } else if (sf.contains('subsidy')) {
          records = records.where((r) => !r.isCompletedState && !r.isNoActionRequired && r.overallStage == 'Subsidy').toList();
        } else if (sf.contains('completed')) {
          records = records.where((r) => r.isCompletedState || r.overallStage == 'Completed').toList();
        } else if (sf.contains('hold') || sf.contains('no action') || sf.contains('no_action')) {
          records = records.where((r) => r.isNoActionRequired).toList();
        }
      } else {
        // By default, Action Center shows only active actionable records (excludes Completed & No Action Required)
        records = records.where((r) => !r.isCompletedState && !r.isNoActionRequired && r.overallStage != 'Completed').toList();
      }

      WorkflowEngine.sortRecordsForActionCenter(records);
      return records;
    } catch (e) {
      // ignore: avoid_print
      print('Error in MobileRecordService.fetchActionCenterRecords: $e');
      return [];
    }
  }

  /// Backward-compatible alias for fetchActionCenterRecords
  static Future<List<ConsumerRecord>> fetchPriorityRecords({
    String? priorityFilter,
  }) async {
    return fetchActionCenterRecords(stageFilter: priorityFilter);
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

  /// Mark customer work state as NO_ACTION_REQUIRED (Hold / Paused) with mandatory reason
  static Future<ConsumerRecord> markCustomerAsNoActionRequired({
    required String recordId,
    required String reason,
    String? freeTextDetails,
  }) async {
    final user = SupabaseService.currentUser;
    final nowIso = DateTime.now().toUtc().toIso8601String();

    String previousState = 'ACTIVE';
    String? consumerNo;
    try {
      final prev = await _client.from('consumer_records').select('customer_work_state, consumer_no').eq('id', recordId).maybeSingle();
      if (prev != null) {
        previousState = prev['customer_work_state'] as String? ?? 'ACTIVE';
        consumerNo = prev['consumer_no'] as String?;
      }
    } catch (_) {}

    final effectiveReason = (freeTextDetails != null && freeTextDetails.trim().isNotEmpty)
        ? (reason.toLowerCase() == 'other' ? freeTextDetails.trim() : '$reason: ${freeTextDetails.trim()}')
        : reason.trim();

    final userName = user?.userMetadata?['name'] as String? ?? user?.email ?? 'Mobile User';

    final response = await _client
        .from('consumer_records')
        .update({
          'customer_work_state': 'NO_ACTION_REQUIRED',
          'no_action_reason': effectiveReason,
          'no_action_date': nowIso,
          'no_action_by': user?.id,
          'no_action_by_name': userName,
          'hold_reason': effectiveReason,
          'hold_date': nowIso,
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
        'consumer_no': consumerNo ?? updated.consumerNo,
        'action': 'MARK_AS_NO_ACTION_REQUIRED',
        'field_name': 'customer_work_state',
        'old_value': previousState,
        'new_value': 'NO_ACTION_REQUIRED',
        'reason': effectiveReason,
        'changed_by': user?.id,
        'source': 'Mobile App',
        'created_at': nowIso,
      });
    } catch (_) {}

    return updated;
  }

  /// Reopen customer work state back to ACTIVE (returns to action center & priority list)
  static Future<ConsumerRecord> reopenCustomer(String recordId) async {
    final user = SupabaseService.currentUser;
    final nowIso = DateTime.now().toUtc().toIso8601String();

    String previousState = 'NO_ACTION_REQUIRED';
    String? consumerNo;
    try {
      final prev = await _client.from('consumer_records').select('customer_work_state, consumer_no').eq('id', recordId).maybeSingle();
      if (prev != null) {
        previousState = prev['customer_work_state'] as String? ?? 'NO_ACTION_REQUIRED';
        consumerNo = prev['consumer_no'] as String?;
      }
    } catch (_) {}

    final response = await _client
        .from('consumer_records')
        .update({
          'customer_work_state': 'ACTIVE',
          'no_action_reason': null,
          'no_action_date': null,
          'no_action_by': null,
          'no_action_by_name': null,
          'hold_reason': null,
          'hold_date': null,
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
        'consumer_no': consumerNo ?? updated.consumerNo,
        'action': 'REOPEN_CUSTOMER',
        'field_name': 'customer_work_state',
        'old_value': previousState,
        'new_value': 'ACTIVE',
        'changed_by': user?.id,
        'source': 'Mobile App',
        'created_at': nowIso,
      });
    } catch (_) {}

    return updated;
  }

  /// Mark loan as Rejected with reason, bank remarks, correction required, and log audit entry
  static Future<ConsumerRecord> markLoanRejected({
    required String recordId,
    required String rejectionReason,
    String? bankRemarks,
    required String correctionRequired,
  }) async {
    final user = SupabaseService.currentUser;
    final nowIso = DateTime.now().toUtc().toIso8601String();

    final response = await _client
        .from('consumer_records')
        .update({
          'loan_status': 'Rejected',
          'loan_sub_stage': 'Loan Rejected',
          'rejection_reason': rejectionReason,
          'bank_remarks': bankRemarks,
          'correction_required': correctionRequired,
          'rejection_date': nowIso,
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
        'action': 'LOAN_REJECTED',
        'field_name': 'loan_sub_stage',
        'old_value': 'File at Bank',
        'new_value': 'Loan Rejected',
        'changed_by': user?.id,
        'source': 'Mobile App',
        'created_at': nowIso,
      });
    } catch (_) {}

    return updated;
  }

  /// Create new Loan Attempt, increment reapply count, set loan_sub_stage = 'Loan Applied', update history log
  static Future<ConsumerRecord> reapplyLoan({
    required ConsumerRecord currentRecord,
    String? remarks,
  }) async {
    final user = SupabaseService.currentUser;
    final nowIso = DateTime.now().toUtc().toIso8601String();

    final nextAttemptNo = currentRecord.loanReapplyCount + 1;
    final newAttempt = {
      'attempt_number': nextAttemptNo,
      'reapply_date': nowIso,
      'previous_rejection_reason': currentRecord.rejectionReason,
      'previous_bank_remarks': currentRecord.bankRemarks,
      'previous_rejection_date': currentRecord.rejectionDate?.toUtc().toIso8601String(),
      'remarks': remarks ?? 'Re-applied by staff',
    };

    final updatedAttempts = List<Map<String, dynamic>>.from(currentRecord.loanAttempts)..add(newAttempt);

    final response = await _client
        .from('consumer_records')
        .update({
          'loan_status': 'Applied',
          'loan_sub_stage': 'Loan Applied',
          'loan_reapply_count': nextAttemptNo,
          'last_reapply_date': nowIso,
          'loan_applied_date': nowIso,
          'loan_attempts': updatedAttempts,
          'customer_work_state': 'ACTIVE',
          'updated_at': nowIso,
          'updated_by': user?.id,
        })
        .eq('id', currentRecord.id!)
        .select()
        .single();

    final updated = ConsumerRecord.fromJson(response);

    try {
      await _client.from('audit_logs').insert({
        'record_id': currentRecord.id!,
        'consumer_no': updated.consumerNo,
        'action': 'LOAN_REAPPLY',
        'field_name': 'loan_sub_stage',
        'old_value': currentRecord.loanSubStage,
        'new_value': 'Loan Applied (Attempt #$nextAttemptNo)',
        'changed_by': user?.id,
        'source': 'Mobile App',
        'created_at': nowIso,
      });
    } catch (_) {}

    return updated;
  }
}
