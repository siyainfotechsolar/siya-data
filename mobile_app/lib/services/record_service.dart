import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/consumer_record.dart';
import '../models/customer_misc_action.dart';
import '../models/customer_issue.dart';
import '../models/customer_payment.dart';
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
      int todaysFollowup = 0;
      int overdueFollowup = 0;
      int upcomingFollowup = 0;

      for (final row in data) {
        final rec = ConsumerRecord.fromJson(row as Map<String, dynamic>);
        if (rec.hasActiveFollowup) {
          if (rec.isFollowupToday) {
            todaysFollowup++;
          } else if (rec.isFollowupOverdue) {
            overdueFollowup++;
          } else if (rec.isFollowupUpcoming) {
            upcomingFollowup++;
          }
        }

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

      int miscCount = 0;
      try {
        final miscRes = await _client
            .from('customer_misc_actions')
            .select('id')
            .inFilter('status', ['Pending', 'In Progress'])
            .count(CountOption.exact);
        miscCount = miscRes.count;
      } catch (_) {}

      int issueCount = 0;
      try {
        final issueRes = await _client
            .from('customer_issues')
            .select('id')
            .inFilter('status', ['New', 'Assigned', 'In Progress', 'Hold'])
            .count(CountOption.exact);
        issueCount = issueRes.count;
      } catch (_) {}

      int paymentCount = 0;
      try {
        final payRes = await _client
            .from('consumer_records')
            .select('id')
            .eq('deleted', false)
            .eq('is_merged', false)
            .not('customer_work_state', 'eq', 'ON_HOLD')
            .gt('pending_amount', 0)
            .count(CountOption.exact);
        paymentCount = payRes.count;
      } catch (_) {}

      return {
        'agreementPending': agreementPending,
        'loanPending': loanPending,
        'installationPending': installationPending,
        'rtsPending': rtsPending,
        'subsidyProcessing': subsidyProcessing,
        'completed': completed,
        'noAction': noAction,
        'todaysFollowup': todaysFollowup,
        'overdueFollowup': overdueFollowup,
        'upcomingFollowup': upcomingFollowup,
        'misc': miscCount,
        'issues': issueCount,
        'payments': paymentCount,
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
        'todaysFollowup': 0,
        'overdueFollowup': 0,
        'upcomingFollowup': 0,
        'misc': 0,
        'issues': 0,
        'payments': 0,
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
        if (sf == 'today_followup' || sf == "today's follow-up" || sf.contains('today')) {
          records = records.where((r) => r.isFollowupToday).toList();
        } else if (sf == 'overdue_followup' || sf == 'overdue follow-up' || sf.contains('overdue')) {
          records = records.where((r) => r.isFollowupOverdue).toList();
        } else if (sf == 'upcoming_followup' || sf == 'upcoming follow-up' || sf.contains('upcoming')) {
          records = records.where((r) => r.isFollowupUpcoming).toList();
        } else if (sf == 'follow-up' || sf == 'followup' || sf == 'follow up') {
          records = records.where((r) => r.hasActiveFollowup).toList();
        } else if (sf.contains('agreement')) {
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
        // By default, Action Center shows only active actionable records (excludes Completed & Hold)
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

  // ==========================================================================
  // ACTION CENTER: 3 QUICK ACTIONS (MARK COMPLETE, MARK HOLD, MARK FOLLOW-UP)
  // ==========================================================================

  /// 1. MARK COMPLETE
  /// customer_work_state = COMPLETED
  /// Removes immediately from active Action Center. Kept available in Completed, History, Reports, Search.
  static Future<ConsumerRecord> markCustomerAsComplete(String recordId) async {
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
        'consumer_no': consumerNo ?? updated.consumerNo,
        'action': 'MARK_COMPLETE',
        'field_name': 'customer_work_state',
        'old_value': previousState,
        'new_value': 'COMPLETED',
        'remarks': 'Marked Complete',
        'changed_by': user?.id,
        'source': 'Mobile App',
        'created_at': nowIso,
      });
    } catch (_) {}

    return updated;
  }

  /// 2. MARK HOLD
  /// customer_work_state = ON_HOLD
  /// Requires Hold Reason. Optional: Hold Remarks, Expected Follow-up Date.
  /// Removes immediately from active Action Center. Kept available in On Hold, History, Reports, Search.
  static Future<ConsumerRecord> markCustomerAsHold({
    required String recordId,
    required String reason,
    String? remarks,
    DateTime? expectedFollowupDate,
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

    final userName = user?.userMetadata?['name'] as String? ?? user?.email ?? 'Mobile Staff';
    final expectedDateStr = expectedFollowupDate?.toIso8601String().split('T')[0];

    final response = await _client
        .from('consumer_records')
        .update({
          'customer_work_state': 'ON_HOLD',
          'hold_reason': reason.trim(),
          'hold_remarks': remarks?.trim(),
          'expected_followup_date': expectedDateStr,
          'hold_date': nowIso,
          'no_action_reason': reason.trim(),
          'no_action_date': nowIso,
          'no_action_by': user?.id,
          'no_action_by_name': userName,
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
        'action': 'MARK_HOLD',
        'field_name': 'customer_work_state',
        'old_value': previousState,
        'new_value': 'ON_HOLD',
        'reason': reason.trim(),
        'remarks': remarks?.trim(),
        'metadata': {
          if (expectedDateStr != null) 'expected_followup_date': expectedDateStr,
        },
        'changed_by': user?.id,
        'source': 'Mobile App',
        'created_at': nowIso,
      });
    } catch (_) {}

    return updated;
  }

  /// Backward-compatible alias for markCustomerAsHold
  static Future<ConsumerRecord> markCustomerAsNoActionRequired({
    required String recordId,
    required String reason,
    String? freeTextDetails,
  }) async {
    return markCustomerAsHold(
      recordId: recordId,
      reason: reason,
      remarks: freeTextDetails,
    );
  }

  /// REOPEN CUSTOMER
  /// customer_work_state = ACTIVE
  /// Recalculates current stage and returns customer to correct Action Center queue.
  static Future<ConsumerRecord> reopenCustomer(String recordId) async {
    final user = SupabaseService.currentUser;
    final nowIso = DateTime.now().toUtc().toIso8601String();

    String previousState = 'ON_HOLD';
    String? consumerNo;
    try {
      final prev = await _client.from('consumer_records').select('customer_work_state, consumer_no').eq('id', recordId).maybeSingle();
      if (prev != null) {
        previousState = prev['customer_work_state'] as String? ?? 'ON_HOLD';
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
          'hold_remarks': null,
          'expected_followup_date': null,
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
        'remarks': 'Reopened and returned to active Action Center',
        'changed_by': user?.id,
        'source': 'Mobile App',
        'created_at': nowIso,
      });
    } catch (_) {}

    return updated;
  }

  /// 3. MARK FOLLOW-UP
  /// Schedules follow-up: Follow-up Date, Follow-up Reason, Remarks.
  /// Categorized as: Today's Follow-up, Overdue Follow-up, Upcoming Follow-up.
  static Future<ConsumerRecord> markCustomerFollowup({
    required String recordId,
    required DateTime followupDate,
    required String followupReason,
    String? remarks,
    String? relatedType,
    String? relatedId,
  }) async {
    final user = SupabaseService.currentUser;
    final nowIso = DateTime.now().toUtc().toIso8601String();
    final dateStr = followupDate.toIso8601String().split('T')[0];
    final userName = user?.userMetadata?['name'] as String? ?? user?.email ?? 'Mobile Staff';

    String? consumerNo;
    try {
      final prev = await _client.from('consumer_records').select('consumer_no').eq('id', recordId).maybeSingle();
      if (prev != null) {
        consumerNo = prev['consumer_no'] as String?;
      }
    } catch (_) {}

    // 1. Update consumer_records with current active follow-up
    final response = await _client
        .from('consumer_records')
        .update({
          'has_active_followup': true,
          'followup_date': dateStr,
          'followup_reason': followupReason.trim(),
          'followup_remarks': remarks?.trim(),
          'updated_at': nowIso,
          'updated_by': user?.id,
        })
        .eq('id', recordId)
        .select()
        .single();

    final updated = ConsumerRecord.fromJson(response);

    // 2. Insert into customer_followups history table
    try {
      final payload = <String, dynamic>{
        'record_id': recordId,
        'consumer_no': consumerNo ?? updated.consumerNo,
        'followup_date': dateStr,
        'followup_reason': followupReason.trim(),
        'remarks': remarks?.trim(),
        'status': 'PENDING',
        'created_at': nowIso,
        'created_by': user?.id,
        'created_by_name': userName,
      };
      if (relatedType != null) payload['related_type'] = relatedType;
      if (relatedId != null) payload['related_id'] = relatedId;

      await _client.from('customer_followups').insert(payload);
    } catch (e) {
      // ignore: avoid_print
      print('Failed to insert customer_followups in mobile: $e');
    }

    // 3. Write to audit_logs
    try {
      await _client.from('audit_logs').insert({
        'record_id': recordId,
        'consumer_no': consumerNo ?? updated.consumerNo,
        'action': 'MARK_FOLLOWUP',
        'field_name': 'has_active_followup',
        'old_value': 'false',
        'new_value': 'true',
        'reason': followupReason.trim(),
        'remarks': remarks?.trim(),
        'metadata': {
          'followup_date': dateStr,
          'followup_reason': followupReason.trim(),
        },
        'changed_by': user?.id,
        'source': 'Mobile App',
        'created_at': nowIso,
      });
    } catch (_) {}

    return updated;
  }

  /// FOLLOW-UP DONE
  /// Records Follow-up Result, Remarks, and Optional Next Follow-up Date.
  /// Saves every follow-up in history. Does NOT automatically change Work Stage or Sub-Stage.
  static Future<ConsumerRecord> completeCustomerFollowup({
    required String recordId,
    required String followupResult,
    String? remarks,
    DateTime? nextFollowupDate,
  }) async {
    final user = SupabaseService.currentUser;
    final nowIso = DateTime.now().toUtc().toIso8601String();
    final nextDateStr = nextFollowupDate?.toIso8601String().split('T')[0];
    final userName = user?.userMetadata?['name'] as String? ?? user?.email ?? 'Mobile Staff';

    String? consumerNo;
    try {
      final prev = await _client.from('consumer_records').select('consumer_no').eq('id', recordId).maybeSingle();
      if (prev != null) {
        consumerNo = prev['consumer_no'] as String?;
      }
    } catch (_) {}

    // 1. Mark pending followup in customer_followups as COMPLETED
    try {
      await _client
          .from('customer_followups')
          .update({
            'status': 'COMPLETED',
            'followup_result': followupResult.trim(),
            'result_remarks': remarks?.trim(),
            'next_followup_date': nextDateStr,
            'completed_at': nowIso,
            'completed_by': user?.id,
            'completed_by_name': userName,
          })
          .eq('record_id', recordId)
          .eq('status', 'PENDING');
    } catch (e) {
      // ignore: avoid_print
      print('Failed to complete pending customer_followup in mobile: $e');
    }

    // 2. If nextFollowupDate is given, create new pending follow-up and keep active
    final updatePayload = <String, dynamic>{
      'last_followup_result': followupResult.trim(),
      'updated_at': nowIso,
      'updated_by': user?.id,
    };

    if (nextFollowupDate != null) {
      updatePayload['has_active_followup'] = true;
      updatePayload['followup_date'] = nextDateStr;
      updatePayload['followup_reason'] = 'Follow-up Call';
      updatePayload['followup_remarks'] = remarks?.trim();

      try {
        await _client.from('customer_followups').insert({
          'record_id': recordId,
          'consumer_no': consumerNo ?? '',
          'followup_date': nextDateStr,
          'followup_reason': 'Follow-up Call',
          'remarks': remarks?.trim(),
          'status': 'PENDING',
          'created_at': nowIso,
          'created_by': user?.id,
          'created_by_name': userName,
        });
      } catch (_) {}
    } else {
      updatePayload['has_active_followup'] = false;
    }

    final response = await _client
        .from('consumer_records')
        .update(updatePayload)
        .eq('id', recordId)
        .select()
        .single();

    final updated = ConsumerRecord.fromJson(response);

    // 3. Write to audit_logs
    try {
      await _client.from('audit_logs').insert({
        'record_id': recordId,
        'consumer_no': consumerNo ?? updated.consumerNo,
        'action': 'FOLLOWUP_DONE',
        'field_name': 'followup_result',
        'old_value': 'PENDING',
        'new_value': followupResult.trim(),
        'reason': followupResult.trim(),
        'remarks': remarks?.trim(),
        'metadata': {
          'followup_result': followupResult.trim(),
          if (nextDateStr != null) 'next_followup_date': nextDateStr,
        },
        'changed_by': user?.id,
        'source': 'Mobile App',
        'created_at': nowIso,
      });
    } catch (_) {}

    return updated;
  }

  /// Fetch follow-up history for a customer
  static Future<List<Map<String, dynamic>>> fetchCustomerFollowupHistory(String recordId) async {
    try {
      final res = await _client
          .from('customer_followups')
          .select('*')
          .eq('record_id', recordId)
          .order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(res as List);
    } catch (_) {
      return [];
    }
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

  // ===========================================================================
  // MISC (MISCELLANEOUS CUSTOMER ACTIONS) SERVICES - MOBILE
  // ===========================================================================

  /// Fetch MISC actions for mobile queue
  static Future<List<CustomerMiscAction>> fetchMiscActions({
    String? statusFilter,
    String? staffFilter,
  }) async {
    try {
      var query = _client.from('customer_misc_actions').select('*');

      final s = statusFilter ?? 'Active';
      if (s == 'Active') {
        query = query.inFilter('status', ['Pending', 'In Progress']);
      } else if (s != 'All' && s.isNotEmpty) {
        query = query.eq('status', s);
      }

      if (staffFilter != null && staffFilter.trim().isNotEmpty && staffFilter.trim().toLowerCase() != 'all') {
        query = query.ilike('assigned_staff_name', '%${staffFilter.trim()}%');
      }

      final response = await query.order('created_at', ascending: false);
      final List<dynamic> data = response as List<dynamic>;
      return data.map((j) => CustomerMiscAction.fromJson(j as Map<String, dynamic>)).toList();
    } catch (e) {
      // ignore: avoid_print
      print('MobileRecordService.fetchMiscActions error: $e');
      return [];
    }
  }

  /// Fetch MISC actions for a specific customer
  static Future<List<CustomerMiscAction>> fetchMiscActionsForCustomer(String recordId) async {
    try {
      final response = await _client
          .from('customer_misc_actions')
          .select('*')
          .eq('record_id', recordId)
          .order('created_at', ascending: false);

      final List<dynamic> data = response as List<dynamic>;
      return data.map((j) => CustomerMiscAction.fromJson(j as Map<String, dynamic>)).toList();
    } catch (e) {
      return [];
    }
  }

  /// Check active duplicate
  static Future<CustomerMiscAction?> checkDuplicateMiscAction({
    required String recordId,
    required String reason,
  }) async {
    try {
      final response = await _client
          .from('customer_misc_actions')
          .select('*')
          .eq('record_id', recordId)
          .eq('reason', reason.trim())
          .inFilter('status', ['Pending', 'In Progress'])
          .maybeSingle();

      if (response == null) return null;
      return CustomerMiscAction.fromJson(response);
    } catch (e) {
      return null;
    }
  }

  /// Create MISC action from Mobile
  static Future<CustomerMiscAction> createMiscAction(CustomerMiscAction action) async {
    final user = SupabaseService.currentUser;
    final nowIso = DateTime.now().toUtc().toIso8601String();

    final payload = action.toJson();
    if (user != null) {
      payload['created_by'] = user.id;
      payload['created_by_name'] = user.email?.split('@')[0] ?? 'Staff';
    }

    final response = await _client
        .from('customer_misc_actions')
        .insert(payload)
        .select()
        .single();

    final created = CustomerMiscAction.fromJson(response);

    try {
      await _client.from('audit_logs').insert({
        'record_id': created.recordId,
        'consumer_no': created.consumerNo,
        'action': 'MISC_ACTION_CREATED',
        'field_name': 'misc_reason',
        'old_value': null,
        'new_value': '${created.reason} (${created.priority})',
        'changed_by': user?.id,
        'source': 'Mobile App',
        'remarks': created.description ?? created.remarks,
        'created_at': nowIso,
      });
    } catch (_) {}

    return created;
  }

  /// Complete MISC action
  static Future<CustomerMiscAction> completeMiscAction({
    required String id,
    String? remarks,
  }) async {
    final user = SupabaseService.currentUser;
    final nowIso = DateTime.now().toUtc().toIso8601String();

    final updatePayload = <String, dynamic>{
      'status': 'Completed',
      'completed_at': nowIso,
      'completed_by': user?.id,
      'completed_by_name': user?.email?.split('@')[0] ?? 'Staff',
    };
    if (remarks != null && remarks.trim().isNotEmpty) {
      updatePayload['remarks'] = remarks.trim();
    }

    final response = await _client
        .from('customer_misc_actions')
        .update(updatePayload)
        .eq('id', id)
        .select()
        .single();

    final completed = CustomerMiscAction.fromJson(response);

    try {
      await _client.from('audit_logs').insert({
        'record_id': completed.recordId,
        'consumer_no': completed.consumerNo,
        'action': 'MISC_ACTION_COMPLETED',
        'field_name': 'misc_status',
        'old_value': 'Pending',
        'new_value': 'Completed',
        'changed_by': user?.id,
        'source': 'Mobile App',
        'remarks': remarks,
        'created_at': nowIso,
      });
    } catch (_) {}

    return completed;
  }

  /// Hold MISC action
  static Future<CustomerMiscAction> holdMiscAction({
    required String id,
    required String holdReason,
    String? remarks,
  }) async {
    final cleanReason = holdReason.trim();
    if (cleanReason.isEmpty) {
      throw Exception('Hold Reason is required');
    }

    final user = SupabaseService.currentUser;
    final nowIso = DateTime.now().toUtc().toIso8601String();

    final updatePayload = <String, dynamic>{
      'status': 'Hold',
      'hold_reason': cleanReason,
    };
    if (remarks != null && remarks.trim().isNotEmpty) {
      updatePayload['remarks'] = remarks.trim();
    }

    final response = await _client
        .from('customer_misc_actions')
        .update(updatePayload)
        .eq('id', id)
        .select()
        .single();

    final onHold = CustomerMiscAction.fromJson(response);

    try {
      await _client.from('audit_logs').insert({
        'record_id': onHold.recordId,
        'consumer_no': onHold.consumerNo,
        'action': 'MISC_ACTION_HOLD',
        'field_name': 'misc_status',
        'old_value': 'Pending',
        'new_value': 'Hold ($cleanReason)',
        'changed_by': user?.id,
        'source': 'Mobile App',
        'remarks': remarks,
        'created_at': nowIso,
      });
    } catch (_) {}

    return onHold;
  }

  // ============================================================================
  // MOBILE GENERAL ISSUE METHODS
  // ============================================================================

  /// Fetch active issues for mobile staff
  static Future<List<CustomerIssue>> fetchIssues({
    String? statusFilter,
    String? assignedStaffFilter,
    String? searchQuery,
  }) async {
    try {
      var query = _client.from('customer_issues').select();

      if (statusFilter != null && statusFilter.isNotEmpty && statusFilter != 'All') {
        if (statusFilter == 'Active') {
          query = query.inFilter('status', ['New', 'Assigned', 'In Progress', 'Hold']);
        } else {
          query = query.eq('status', statusFilter);
        }
      } else {
        query = query.inFilter('status', ['New', 'Assigned', 'In Progress', 'Hold']);
      }

      if (assignedStaffFilter != null && assignedStaffFilter.isNotEmpty && assignedStaffFilter != 'All') {
        query = query.eq('assigned_staff', assignedStaffFilter);
      }

      if (searchQuery != null && searchQuery.trim().isNotEmpty) {
        final term = '%${searchQuery.trim()}%';
        query = query.or('customer_name.ilike.$term,consumer_no.ilike.$term,title.ilike.$term');
      }

      final response = await query.order('created_at', ascending: false).limit(50);
      final List<dynamic> data = response as List<dynamic>;
      return data.map((j) => CustomerIssue.fromJson(j as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  /// Create issue from mobile
  static Future<CustomerIssue> createIssue(CustomerIssue issue) async {
    final user = SupabaseService.currentUser;
    final userName = user?.userMetadata?['name'] as String? ?? user?.email ?? 'Mobile Staff';
    final nowIso = DateTime.now().toUtc().toIso8601String();

    final payload = issue.toJson();
    payload['created_by'] = user?.id;
    payload['created_by_name'] = userName;
    payload['created_at'] = nowIso;
    payload['updated_at'] = nowIso;

    final response = await _client.from('customer_issues').insert(payload).select().single();
    final created = CustomerIssue.fromJson(response);

    try {
      await _client.from('customer_issue_history').insert({
        'issue_id': created.id,
        'action_type': 'CREATED',
        'new_value': created.status,
        'remarks': 'Reported via Mobile: ${created.title}',
        'changed_by': user?.id,
        'changed_by_name': userName,
        'created_at': nowIso,
      });
    } catch (_) {}

    return created;
  }

  /// Resolve issue from mobile
  static Future<CustomerIssue> resolveIssue({
    required String issueId,
    String? remarks,
  }) async {
    final user = SupabaseService.currentUser;
    final userName = user?.userMetadata?['name'] as String? ?? user?.email ?? 'Mobile Staff';
    final nowIso = DateTime.now().toUtc().toIso8601String();

    final response = await _client
        .from('customer_issues')
        .update({
          'status': 'Resolved',
          'resolution_remarks': remarks?.trim(),
          'resolved_by': user?.id,
          'resolved_by_name': userName,
          'resolved_at': nowIso,
          'updated_at': nowIso,
        })
        .eq('id', issueId)
        .select()
        .single();

    final resolved = CustomerIssue.fromJson(response);

    try {
      await _client.from('customer_issue_history').insert({
        'issue_id': issueId,
        'action_type': 'RESOLVED',
        'new_value': 'Resolved',
        'remarks': remarks?.trim() ?? 'Resolved via Mobile',
        'changed_by': user?.id,
        'changed_by_name': userName,
        'created_at': nowIso,
      });
    } catch (_) {}

    return resolved;
  }

  /// Hold issue from mobile
  static Future<CustomerIssue> holdIssue({
    required String issueId,
    required String holdReason,
    String? remarks,
  }) async {
    final user = SupabaseService.currentUser;
    final userName = user?.userMetadata?['name'] as String? ?? user?.email ?? 'Mobile Staff';
    final nowIso = DateTime.now().toUtc().toIso8601String();

    final response = await _client
        .from('customer_issues')
        .update({
          'status': 'Hold',
          'hold_reason': holdReason.trim(),
          'remarks': remarks?.trim(),
          'updated_at': nowIso,
        })
        .eq('id', issueId)
        .select()
        .single();

    final held = CustomerIssue.fromJson(response);

    try {
      await _client.from('customer_issue_history').insert({
        'issue_id': issueId,
        'action_type': 'HOLD',
        'new_value': 'Hold: $holdReason',
        'remarks': remarks?.trim() ?? holdReason.trim(),
        'changed_by': user?.id,
        'changed_by_name': userName,
        'created_at': nowIso,
      });
    } catch (_) {}

    return held;
  }

  /// Reopen issue from mobile
  static Future<CustomerIssue> reopenIssue({
    required String issueId,
    String? remarks,
  }) async {
    final user = SupabaseService.currentUser;
    final userName = user?.userMetadata?['name'] as String? ?? user?.email ?? 'Mobile Staff';
    final nowIso = DateTime.now().toUtc().toIso8601String();

    final response = await _client
        .from('customer_issues')
        .update({
          'status': 'In Progress',
          'hold_reason': null,
          'resolution_remarks': null,
          'resolved_at': null,
          'resolved_by': null,
          'resolved_by_name': null,
          'updated_by': user?.id,
          'updated_at': nowIso,
        })
        .eq('id', issueId)
        .select()
        .single();

    final reopened = CustomerIssue.fromJson(response);

    try {
      await _client.from('customer_issue_history').insert({
        'issue_id': issueId,
        'action_type': 'REOPENED',
        'new_value': 'In Progress',
        'remarks': remarks?.trim() ?? 'Reopened via Mobile',
        'changed_by': user?.id,
        'changed_by_name': userName,
        'created_at': nowIso,
      });
    } catch (_) {}

    return reopened;
  }

  // ============================================================================
  // MOBILE PAYMENT METHODS
  // ============================================================================

  /// Fetch customers with pending payment for mobile
  static Future<List<ConsumerRecord>> fetchPaymentPendingRecords({
    String? searchQuery,
    String? staffFilter,
  }) async {
    try {
      var query = _client
          .from('consumer_records')
          .select()
          .eq('deleted', false)
          .eq('is_merged', false)
          .not('customer_work_state', 'eq', 'ON_HOLD')
          .gt('pending_amount', 0);

      if (staffFilter != null && staffFilter.isNotEmpty && staffFilter != 'All') {
        query = query.eq('assigned_staff', staffFilter);
      }

      if (searchQuery != null && searchQuery.trim().isNotEmpty) {
        final term = '%${searchQuery.trim()}%';
        query = query.or('name.ilike.$term,consumer_no.ilike.$term,mobile.ilike.$term');
      }

      final response = await query.order('pending_amount', ascending: false).limit(50);
      final List<dynamic> data = response as List<dynamic>;
      return data.map((j) => ConsumerRecord.fromJson(j as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  /// Add payment transaction from mobile
  static Future<PaymentTransaction> addPaymentTransaction(PaymentTransaction transaction) async {
    final user = SupabaseService.currentUser;
    final userName = user?.userMetadata?['name'] as String? ?? user?.email ?? 'Mobile Staff';
    final nowIso = DateTime.now().toUtc().toIso8601String();

    final payload = transaction.toJson();
    payload['created_by'] = user?.id;
    payload['created_by_name'] = userName;
    payload['created_at'] = nowIso;
    payload['updated_at'] = nowIso;

    final response = await _client
        .from('customer_payment_transactions')
        .insert(payload)
        .select()
        .single();

    final created = PaymentTransaction.fromJson(response);

    try {
      await _client.from('audit_logs').insert({
        'record_id': created.customerId,
        'consumer_no': created.consumerNo,
        'action': 'PAYMENT_RECEIVED',
        'field_name': 'paid_amount',
        'old_value': null,
        'new_value': '₹${created.amount} via ${created.paymentMode} (Mobile)',
        'changed_by': user?.id,
        'source': 'Mobile App',
        'created_at': nowIso,
      });
    } catch (_) {}

    return created;
  }
}

