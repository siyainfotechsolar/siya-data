import 'package:flutter/foundation.dart' show debugPrint;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/consumer_record.dart';
import '../models/customer_misc_action.dart';
import '../models/customer_issue.dart';
import '../models/customer_payment.dart';
import 'supabase_service.dart';
import 'workflow_engine.dart';
import 'activity_log_service.dart';
import 'app_database.dart';
import 'connectivity_service.dart';
import 'sync_engine.dart';

/// Centralized logger for MobileRecordService — always use this instead of
/// bare catch (_) {} so errors are traceable in production logs.
void _log(String fn, Object error, {String? context}) {
  debugPrint('[RecordService][$fn] Error${context != null ? " ($context)" : ""}: $error');
}

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

  /// Fetch active consumer records with optional status filter and search query (Offline-First)
  static Future<PaginatedResult<ConsumerRecord>> fetchRecords({
    int page = 1,
    int pageSize = 20,
    String? searchQuery,
    String? statusFilter,
  }) async {
    // 1. If currently offline, query SQLite database directly for instant response
    if (ConnectivityService.isOffline) {
      final localItems = await AppDatabase.searchConsumerRecords(
        query: searchQuery,
        statusFilter: statusFilter,
        page: page,
        pageSize: pageSize,
      );
      final totalCount = await AppDatabase.countConsumerRecords(
        query: searchQuery,
        statusFilter: statusFilter,
      );
      return PaginatedResult<ConsumerRecord>(
        items: localItems,
        totalCount: totalCount,
        page: page,
        pageSize: pageSize,
      );
    }

    // 2. If online, fetch from Supabase and cache locally
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

      // Cache records into SQLite in background
      AppDatabase.batchUpsertConsumerRecords(records, syncStatus: 'SYNCED').catchError((_) {});

      return PaginatedResult<ConsumerRecord>(
        items: records,
        totalCount: totalCount,
        page: page,
        pageSize: pageSize,
      );
    } catch (e) {
      // On any connection error, fallback immediately to SQLite
      _log('fetchRecords', e, context: 'page=$page q=$searchQuery');
      final localItems = await AppDatabase.searchConsumerRecords(
        query: searchQuery,
        statusFilter: statusFilter,
        page: page,
        pageSize: pageSize,
      );
      final totalCount = await AppDatabase.countConsumerRecords(
        query: searchQuery,
        statusFilter: statusFilter,
      );
      return PaginatedResult<ConsumerRecord>(
        items: localItems,
        totalCount: totalCount,
        page: page,
        pageSize: pageSize,
      );
    }
  }

  /// Get record by ID (Offline-First)
  static Future<ConsumerRecord?> getRecordById(String id) async {
    // Check local database first
    final local = await AppDatabase.getConsumerRecordById(id);
    if (local != null) return local;

    if (ConnectivityService.isOffline) return null;

    try {
      final response = await _client
          .from('consumer_records')
          .select('*')
          .eq('id', id)
          .maybeSingle();

      if (response == null) return null;
      final record = ConsumerRecord.fromJson(response);
      await AppDatabase.upsertConsumerRecord(record, syncStatus: 'SYNCED');
      return record;
    } catch (e) {
      _log('getRecordById', e, context: 'id=$id');
      return null;
    }
  }

  /// Update status and optional remarks from mobile app with audit trail (Offline-First)
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

    // 1. Update local database immediately
    final existing = await AppDatabase.getConsumerRecordById(id);
    final localUpdated = existing != null
        ? existing.copyWith(
            status: newStatus,
            remarks: remarks != null && remarks.trim().isNotEmpty ? remarks.trim() : existing.remarks,
            updatedAt: DateTime.now(),
          )
        : ConsumerRecord(
            id: id,
            consumerNo: consumerNo,
            name: existing?.name ?? '',
            status: newStatus,
            remarks: remarks,
            updatedAt: DateTime.now(),
          );

    await AppDatabase.upsertConsumerRecord(localUpdated, syncStatus: 'Pending Sync');

    if (ConnectivityService.isOffline) {
      await AppDatabase.enqueueOperation(
        OfflineOperation(
          operationId: 'op_${DateTime.now().microsecondsSinceEpoch}',
          entityType: 'consumer_record',
          entityId: id,
          action: 'UPDATE_STATUS',
          payload: updatePayload,
          userId: user?.id,
          createdAt: DateTime.now(),
        ),
      );
      await AppDatabase.logOfflineActivity(
        recordId: id,
        consumerNo: consumerNo,
        customerName: localUpdated.name,
        staffName: user?.email?.split('@')[0] ?? 'Staff',
        action: 'STATUS_UPDATED',
        remarks: 'Status changed: $oldStatus -> $newStatus (Offline)',
      );
      return localUpdated;
    }

    try {
      final response = await _client
          .from('consumer_records')
          .update(updatePayload)
          .eq('id', id)
          .select()
          .single();

      final updated = ConsumerRecord.fromJson(response);
      await AppDatabase.upsertConsumerRecord(updated, syncStatus: 'SYNCED');

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
      } catch (_) {}

      return updated;
    } catch (e) {
      // On network failure, enqueue for later sync
      _log('updateRecordStatus', e, context: 'id=$id status=$newStatus');
      await AppDatabase.enqueueOperation(
        OfflineOperation(
          operationId: 'op_${DateTime.now().microsecondsSinceEpoch}',
          entityType: 'consumer_record',
          entityId: id,
          action: 'UPDATE_STATUS',
          payload: updatePayload,
          userId: user?.id,
          createdAt: DateTime.now(),
        ),
      );
      return localUpdated;
    }
  }

  /// Update individual workflow stages and values with audit logging (Offline-First)
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

    final localUpdated = record.copyWith(
      applicationStatus: applicationStatus,
      agreementStatus: agreementStatus,
      loanRequired: loanRequired,
      loanStatus: loanStatus,
      installationStatus: installationStatus,
      installerTeam: installerTeam,
      rtsStatus: rtsStatus,
      rtsApplicationId: rtsApplicationId,
      subsidyStatus: subsidyStatus,
      remarks: remarks != null && remarks.trim().isNotEmpty ? remarks.trim() : record.remarks,
      updatedAt: DateTime.now(),
    );

    // Save locally immediately
    await AppDatabase.upsertConsumerRecord(localUpdated, syncStatus: 'Pending Sync');

    if (ConnectivityService.isOffline) {
      await AppDatabase.enqueueOperation(
        OfflineOperation(
          operationId: 'op_${DateTime.now().microsecondsSinceEpoch}',
          entityType: 'consumer_record',
          entityId: record.id!,
          action: 'UPDATE_WORKFLOW_STAGE',
          payload: updatePayload,
          userId: user?.id,
          createdAt: DateTime.now(),
        ),
      );
      await AppDatabase.logOfflineActivity(
        recordId: record.id,
        consumerNo: record.consumerNo,
        customerName: localUpdated.name,
        staffName: user?.email?.split('@')[0] ?? 'Staff',
        action: 'STAGE_CHANGED',
        remarks: 'Workflow updated to ${localUpdated.overallStage} (Offline)',
      );
      return localUpdated;
    }

    try {
      final response = await _client
          .from('consumer_records')
          .update(updatePayload)
          .eq('id', record.id!)
          .select()
          .single();

      final updated = ConsumerRecord.fromJson(response);
      await AppDatabase.upsertConsumerRecord(updated, syncStatus: 'SYNCED');

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

        String module = 'Workflow';
        String action = 'Stage Changed';
        String? oldVal = record.overallStage;
        String? newVal = updated.overallStage;

        if (installationStatus != null && installationStatus != record.installationStatus) {
          module = 'Installation';
          action = 'Installation Updated';
          oldVal = record.installationStatus;
          newVal = installationStatus;
        } else if (loanStatus != null && loanStatus != record.loanStatus) {
          module = 'Loan';
          action = 'Loan Updated';
          oldVal = record.loanStatus;
          newVal = loanStatus;
        } else if (agreementStatus != null && agreementStatus != record.agreementStatus) {
          module = 'Customer';
          action = 'Agreement Updated';
          oldVal = record.agreementStatus;
          newVal = agreementStatus;
        } else if (rtsStatus != null && rtsStatus != record.rtsStatus) {
          module = 'RTS';
          action = 'RTS Updated';
          oldVal = record.rtsStatus;
          newVal = rtsStatus;
        } else if (subsidyStatus != null && subsidyStatus != record.subsidyStatus) {
          module = 'Subsidy';
          action = 'Subsidy Updated';
          oldVal = record.subsidyStatus;
          newVal = subsidyStatus;
        }

        await ActivityLogService.logActivity(
          recordId: record.id,
          consumerNo: record.consumerNo,
          customerName: record.name,
          village: record.address ?? '-',
          module: module,
          action: action,
          oldValue: oldVal,
          newValue: newVal,
          nextAction: updated.actionRequired,
          remarks: remarks,
          source: 'Mobile App',
        );
      } catch (_) {}

      return updated;
    } catch (_) {
      await AppDatabase.enqueueOperation(
        OfflineOperation(
          operationId: 'op_${DateTime.now().microsecondsSinceEpoch}',
          entityType: 'consumer_record',
          entityId: record.id!,
          action: 'UPDATE_WORKFLOW_STAGE',
          payload: updatePayload,
          userId: user?.id,
          createdAt: DateTime.now(),
        ),
      );
      return localUpdated;
    }
  }

  /// Consumer Name correction via Mobile App (Offline-First)
  static Future<ConsumerRecord> updateCustomerName({
    required String recordId,
    required String newName,
  }) async {
    final cleanNewName = newName.trim();
    if (cleanNewName.isEmpty) {
      throw Exception('Consumer Name cannot be empty.');
    }

    final user = SupabaseService.currentUser;
    final nowIso = DateTime.now().toUtc().toIso8601String();

    final existing = await AppDatabase.getConsumerRecordById(recordId);
    final oldName = existing?.name ?? '';
    final consumerNo = existing?.consumerNo ?? '';

    final updatePayload = <String, dynamic>{
      'name': cleanNewName,
      'updated_at': nowIso,
    };
    if (user != null) {
      updatePayload['updated_by'] = user.id;
    }

    final localUpdated = existing != null
        ? existing.copyWith(name: cleanNewName, updatedAt: DateTime.now())
        : ConsumerRecord(id: recordId, consumerNo: consumerNo, name: cleanNewName, updatedAt: DateTime.now());

    await AppDatabase.upsertConsumerRecord(localUpdated, syncStatus: 'Pending Sync');

    if (ConnectivityService.isOffline) {
      await AppDatabase.enqueueOperation(
        OfflineOperation(
          operationId: 'op_${DateTime.now().microsecondsSinceEpoch}',
          entityType: 'consumer_record',
          entityId: recordId,
          action: 'NAME_CORRECTION',
          payload: updatePayload,
          userId: user?.id,
          createdAt: DateTime.now(),
        ),
      );
      await AppDatabase.logOfflineActivity(
        recordId: recordId,
        consumerNo: consumerNo,
        customerName: cleanNewName,
        staffName: user?.email?.split('@')[0] ?? 'Staff',
        action: 'NAME_CORRECTION',
        remarks: 'Name updated to $cleanNewName (Offline)',
      );
      return localUpdated;
    }

    try {
      final response = await _client
          .from('consumer_records')
          .update(updatePayload)
          .eq('id', recordId)
          .select()
          .single();

      final updated = ConsumerRecord.fromJson(response);
      await AppDatabase.upsertConsumerRecord(updated, syncStatus: 'SYNCED');

      // Record in audit_logs
      try {
        await _client.from('audit_logs').insert({
          'record_id': recordId,
          'consumer_no': consumerNo,
          'action': 'NAME_CORRECTION',
          'field_name': 'Customer Name',
          'old_value': oldName,
          'new_value': cleanNewName,
          'changed_by': user?.id,
          'source': 'Mobile Name Correction',
          'created_at': nowIso,
        });

        await ActivityLogService.logActivity(
          recordId: recordId,
          consumerNo: consumerNo,
          customerName: cleanNewName,
          module: 'Customer',
          action: 'Customer Name Correction',
          oldValue: oldName,
          newValue: cleanNewName,
          remarks: 'Consumer name changed via Android mobile app',
        );
      } catch (_) {}

      return updated;
    } catch (_) {
      await AppDatabase.enqueueOperation(
        OfflineOperation(
          operationId: 'op_${DateTime.now().microsecondsSinceEpoch}',
          entityType: 'consumer_record',
          entityId: recordId,
          action: 'NAME_CORRECTION',
          payload: updatePayload,
          userId: user?.id,
          createdAt: DateTime.now(),
        ),
      );
      return localUpdated;
    }
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
    if (ConnectivityService.isOffline) {
      return await AppDatabase.getDashboardSummary();
    }

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
      return await AppDatabase.getDashboardSummary();
    }
  }

  /// Compute Action Center summary counts directly from persistent local SQLite
  static Future<Map<String, int>> _computeActionCenterSummaryFromLocal({String? staffFilter}) async {
    final records = await AppDatabase.getAllConsumerRecords();
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

    for (final rec in records) {
      if (staffFilter != null && staffFilter.trim().isNotEmpty && staffFilter.trim().toLowerCase() != 'all') {
        final st = staffFilter.trim().toLowerCase();
        final as = (rec.assignedStaff ?? '').toLowerCase();
        final it = (rec.installerTeam ?? '').toLowerCase();
        if (!as.contains(st) && !it.contains(st)) continue;
      }

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

    final miscActions = await AppDatabase.getMiscActions(statusFilter: 'Active');
    final issues = await AppDatabase.getCustomerIssues(statusFilter: 'Active');
    final paymentCount = await AppDatabase.getPendingPaymentsCount();

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
      'misc': miscActions.length,
      'issues': issues.length,
      'payments': paymentCount,
      'totalActive': agreementPending + loanPending + installationPending + rtsPending + subsidyProcessing,
    };
  }

  /// Fetch Action Center summary counts for Mobile App (Offline-First)
  static Future<Map<String, int>> fetchActionCenterSummary({String? staffFilter}) async {
    if (ConnectivityService.isOffline) {
      return await _computeActionCenterSummaryFromLocal(staffFilter: staffFilter);
    }

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
      return await _computeActionCenterSummaryFromLocal(staffFilter: staffFilter);
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

  /// Filter and sort records for Action Center display
  static List<ConsumerRecord> _filterActionCenterRecords(
    List<ConsumerRecord> records, {
    String? stageFilter,
    String? assignedStaffFilter,
  }) {
    var filtered = List<ConsumerRecord>.from(records);

    if (assignedStaffFilter != null && assignedStaffFilter.trim().isNotEmpty && assignedStaffFilter.trim().toLowerCase() != 'all') {
      final st = assignedStaffFilter.trim().toLowerCase();
      filtered = filtered.where((r) {
        final as = (r.assignedStaff ?? '').toLowerCase();
        final it = (r.installerTeam ?? '').toLowerCase();
        return as.contains(st) || it.contains(st);
      }).toList();
    }

    if (stageFilter != null && stageFilter.isNotEmpty && stageFilter.toUpperCase() != 'ALL') {
      final sf = stageFilter.trim().toLowerCase();
      if (sf == 'today_followup' || sf == "today's follow-up" || sf.contains('today')) {
        filtered = filtered.where((r) => r.isFollowupToday).toList();
      } else if (sf == 'overdue_followup' || sf == 'overdue follow-up' || sf.contains('overdue')) {
        filtered = filtered.where((r) => r.isFollowupOverdue).toList();
      } else if (sf == 'upcoming_followup' || sf == 'upcoming follow-up' || sf.contains('upcoming')) {
        filtered = filtered.where((r) => r.isFollowupUpcoming).toList();
      } else if (sf == 'follow-up' || sf == 'followup' || sf == 'follow up') {
        filtered = filtered.where((r) => r.hasActiveFollowup).toList();
      } else if (sf.contains('agreement')) {
        filtered = filtered.where((r) => !r.isCompletedState && !r.isNoActionRequired && r.overallStage == 'Agreement').toList();
      } else if (sf.contains('loan')) {
        filtered = filtered.where((r) => !r.isCompletedState && !r.isNoActionRequired && r.overallStage == 'Loan').toList();
      } else if (sf.contains('installation')) {
        filtered = filtered.where((r) => !r.isCompletedState && !r.isNoActionRequired && r.overallStage == 'Installation').toList();
      } else if (sf.contains('rts')) {
        filtered = filtered.where((r) => !r.isCompletedState && !r.isNoActionRequired && r.overallStage == 'RTS').toList();
      } else if (sf.contains('subsidy')) {
        filtered = filtered.where((r) => !r.isCompletedState && !r.isNoActionRequired && r.overallStage == 'Subsidy').toList();
      } else if (sf.contains('completed')) {
        filtered = filtered.where((r) => r.isCompletedState || r.overallStage == 'Completed').toList();
      } else if (sf.contains('hold') || sf.contains('no action') || sf.contains('no_action')) {
        filtered = filtered.where((r) => r.isNoActionRequired).toList();
      }
    } else {
      filtered = filtered.where((r) => !r.isCompletedState && !r.isNoActionRequired && r.overallStage != 'Completed').toList();
    }

    WorkflowEngine.sortRecordsForActionCenter(filtered);
    return filtered;
  }

  /// Fetch active applications for Mobile Action Center (Offline-First)
  static Future<List<ConsumerRecord>> fetchActionCenterRecords({
    String? stageFilter,
    String? assignedStaffFilter,
  }) async {
    if (ConnectivityService.isOffline) {
      final localRecords = await AppDatabase.getAllConsumerRecords();
      return _filterActionCenterRecords(
        localRecords,
        stageFilter: stageFilter,
        assignedStaffFilter: assignedStaffFilter,
      );
    }

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

      // Cache locally in SQLite for offline access
      AppDatabase.batchUpsertConsumerRecords(records, syncStatus: 'SYNCED').catchError((_) {});

      return _filterActionCenterRecords(
        records,
        stageFilter: stageFilter,
        assignedStaffFilter: assignedStaffFilter,
      );
    } catch (_) {
      final localRecords = await AppDatabase.getAllConsumerRecords();
      return _filterActionCenterRecords(
        localRecords,
        stageFilter: stageFilter,
        assignedStaffFilter: assignedStaffFilter,
      );
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

  /// 1. MARK COMPLETE (Offline-First)
  /// customer_work_state = COMPLETED
  /// Removes immediately from active Action Center. Kept available in Completed, History, Reports, Search.
  static Future<ConsumerRecord> markCustomerAsComplete(String recordId) async {
    final user = SupabaseService.currentUser;
    final nowIso = DateTime.now().toUtc().toIso8601String();

    final existing = await AppDatabase.getConsumerRecordById(recordId);
    final previousState = existing?.customerWorkState ?? 'ACTIVE';
    final consumerNo = existing?.consumerNo ?? '';

    final localUpdated = existing != null
        ? existing.copyWith(customerWorkState: 'COMPLETED', updatedAt: DateTime.now())
        : ConsumerRecord(
            id: recordId,
            consumerNo: consumerNo,
            name: existing?.name ?? '',
            customerWorkState: 'COMPLETED',
            updatedAt: DateTime.now(),
          );

    await AppDatabase.upsertConsumerRecord(localUpdated, syncStatus: 'Pending Sync');

    final updatePayload = <String, dynamic>{
      'customer_work_state': 'COMPLETED',
      'updated_at': nowIso,
      'updated_by': user?.id,
    };

    if (ConnectivityService.isOffline) {
      await AppDatabase.enqueueOperation(
        OfflineOperation(
          operationId: 'op_${DateTime.now().microsecondsSinceEpoch}',
          entityType: 'consumer_record',
          entityId: recordId,
          action: 'MARK_COMPLETE',
          payload: updatePayload,
          userId: user?.id,
          createdAt: DateTime.now(),
        ),
      );
      await AppDatabase.logOfflineActivity(
        recordId: recordId,
        consumerNo: consumerNo,
        customerName: localUpdated.name,
        staffName: user?.email?.split('@')[0] ?? 'Staff',
        action: 'MARK_COMPLETE',
        remarks: 'Marked customer as Complete (Offline)',
      );
      return localUpdated;
    }

    try {
      final response = await _client
          .from('consumer_records')
          .update(updatePayload)
          .eq('id', recordId)
          .select()
          .single();

      final updated = ConsumerRecord.fromJson(response);
      await AppDatabase.upsertConsumerRecord(updated, syncStatus: 'SYNCED');

      try {
        await _client.from('audit_logs').insert({
          'record_id': recordId,
          'consumer_no': consumerNo.isNotEmpty ? consumerNo : updated.consumerNo,
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
    } catch (_) {
      await AppDatabase.enqueueOperation(
        OfflineOperation(
          operationId: 'op_${DateTime.now().microsecondsSinceEpoch}',
          entityType: 'consumer_record',
          entityId: recordId,
          action: 'MARK_COMPLETE',
          payload: updatePayload,
          userId: user?.id,
          createdAt: DateTime.now(),
        ),
      );
      return localUpdated;
    }
  }

  /// 2. MARK HOLD (Offline-First)
  /// customer_work_state = ON_HOLD
  /// Requires Hold Reason. Optional: Hold Remarks, Expected Follow-up Date.
  static Future<ConsumerRecord> markCustomerAsHold({
    required String recordId,
    required String reason,
    String? remarks,
    DateTime? expectedFollowupDate,
  }) async {
    final user = SupabaseService.currentUser;
    final nowIso = DateTime.now().toUtc().toIso8601String();
    final expectedDateStr = expectedFollowupDate?.toIso8601String().split('T')[0];
    final userName = user?.userMetadata?['name'] as String? ?? user?.email ?? 'Mobile Staff';

    final existing = await AppDatabase.getConsumerRecordById(recordId);
    final previousState = existing?.customerWorkState ?? 'ACTIVE';
    final consumerNo = existing?.consumerNo ?? '';

    final localUpdated = existing != null
        ? existing.copyWith(
            customerWorkState: 'ON_HOLD',
            holdReason: reason.trim(),
            holdRemarks: remarks?.trim(),
            expectedFollowupDate: expectedFollowupDate,
            holdDate: DateTime.now(),
            noActionReason: reason.trim(),
            noActionDate: DateTime.now(),
            noActionBy: user?.id,
            noActionByName: userName,
            updatedAt: DateTime.now(),
          )
        : ConsumerRecord(
            id: recordId,
            consumerNo: consumerNo,
            name: existing?.name ?? '',
            customerWorkState: 'ON_HOLD',
            holdReason: reason.trim(),
            holdRemarks: remarks?.trim(),
            expectedFollowupDate: expectedFollowupDate,
            updatedAt: DateTime.now(),
          );

    await AppDatabase.upsertConsumerRecord(localUpdated, syncStatus: 'Pending Sync');

    final updatePayload = <String, dynamic>{
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
    };

    if (ConnectivityService.isOffline) {
      await AppDatabase.enqueueOperation(
        OfflineOperation(
          operationId: 'op_${DateTime.now().microsecondsSinceEpoch}',
          entityType: 'consumer_record',
          entityId: recordId,
          action: 'MARK_HOLD',
          payload: updatePayload,
          userId: user?.id,
          createdAt: DateTime.now(),
        ),
      );
      await AppDatabase.logOfflineActivity(
        recordId: recordId,
        consumerNo: consumerNo,
        customerName: localUpdated.name,
        staffName: userName,
        action: 'MARK_HOLD',
        remarks: 'Placed on Hold: $reason (Offline)',
      );
      return localUpdated;
    }

    try {
      final response = await _client
          .from('consumer_records')
          .update(updatePayload)
          .eq('id', recordId)
          .select()
          .single();

      final updated = ConsumerRecord.fromJson(response);
      await AppDatabase.upsertConsumerRecord(updated, syncStatus: 'SYNCED');

      try {
        await _client.from('audit_logs').insert({
          'record_id': recordId,
          'consumer_no': consumerNo.isNotEmpty ? consumerNo : updated.consumerNo,
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
    } catch (_) {
      await AppDatabase.enqueueOperation(
        OfflineOperation(
          operationId: 'op_${DateTime.now().microsecondsSinceEpoch}',
          entityType: 'consumer_record',
          entityId: recordId,
          action: 'MARK_HOLD',
          payload: updatePayload,
          userId: user?.id,
          createdAt: DateTime.now(),
        ),
      );
      return localUpdated;
    }
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

  /// REOPEN CUSTOMER (Offline-First)
  /// customer_work_state = ACTIVE
  /// Recalculates current stage and returns customer to correct Action Center queue.
  static Future<ConsumerRecord> reopenCustomer(String recordId) async {
    final user = SupabaseService.currentUser;
    final nowIso = DateTime.now().toUtc().toIso8601String();

    final existing = await AppDatabase.getConsumerRecordById(recordId);
    final previousState = existing?.customerWorkState ?? 'ON_HOLD';
    final consumerNo = existing?.consumerNo ?? '';

    final localUpdated = existing != null
        ? existing.copyWith(
            customerWorkState: 'ACTIVE',
            clearNoAction: true,
            updatedAt: DateTime.now(),
          )
        : ConsumerRecord(
            id: recordId,
            consumerNo: consumerNo,
            name: existing?.name ?? '',
            customerWorkState: 'ACTIVE',
            updatedAt: DateTime.now(),
          );

    await AppDatabase.upsertConsumerRecord(localUpdated, syncStatus: 'Pending Sync');

    final updatePayload = <String, dynamic>{
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
    };

    if (ConnectivityService.isOffline) {
      await AppDatabase.enqueueOperation(
        OfflineOperation(
          operationId: 'op_${DateTime.now().microsecondsSinceEpoch}',
          entityType: 'consumer_record',
          entityId: recordId,
          action: 'REOPEN_CUSTOMER',
          payload: updatePayload,
          userId: user?.id,
          createdAt: DateTime.now(),
        ),
      );
      await AppDatabase.logOfflineActivity(
        recordId: recordId,
        consumerNo: consumerNo,
        customerName: localUpdated.name,
        staffName: user?.email?.split('@')[0] ?? 'Staff',
        action: 'REOPEN_CUSTOMER',
        remarks: 'Reopened customer (Offline)',
      );
      return localUpdated;
    }

    try {
      final response = await _client
          .from('consumer_records')
          .update(updatePayload)
          .eq('id', recordId)
          .select()
          .single();

      final updated = ConsumerRecord.fromJson(response);
      await AppDatabase.upsertConsumerRecord(updated, syncStatus: 'SYNCED');

      try {
        await _client.from('audit_logs').insert({
          'record_id': recordId,
          'consumer_no': consumerNo.isNotEmpty ? consumerNo : updated.consumerNo,
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
    } catch (_) {
      await AppDatabase.enqueueOperation(
        OfflineOperation(
          operationId: 'op_${DateTime.now().microsecondsSinceEpoch}',
          entityType: 'consumer_record',
          entityId: recordId,
          action: 'REOPEN_CUSTOMER',
          payload: updatePayload,
          userId: user?.id,
          createdAt: DateTime.now(),
        ),
      );
      return localUpdated;
    }
  }

  /// 3. MARK FOLLOW-UP (Offline-First)
  /// Schedules follow-up: Follow-up Date, Follow-up Reason, Remarks.
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

    final existing = await AppDatabase.getConsumerRecordById(recordId);
    final consumerNo = existing?.consumerNo ?? '';

    final localUpdated = existing != null
        ? existing.copyWith(
            hasActiveFollowup: true,
            followupDate: followupDate,
            followupReason: followupReason.trim(),
            followupRemarks: remarks?.trim(),
            updatedAt: DateTime.now(),
          )
        : ConsumerRecord(
            id: recordId,
            consumerNo: consumerNo,
            name: existing?.name ?? '',
            hasActiveFollowup: true,
            followupDate: followupDate,
            followupReason: followupReason.trim(),
            followupRemarks: remarks?.trim(),
            updatedAt: DateTime.now(),
          );

    await AppDatabase.upsertConsumerRecord(localUpdated, syncStatus: 'Pending Sync');

    final updatePayload = <String, dynamic>{
      'has_active_followup': true,
      'followup_date': dateStr,
      'followup_reason': followupReason.trim(),
      'followup_remarks': remarks?.trim(),
      'updated_at': nowIso,
      'updated_by': user?.id,
    };

    final followupPayload = <String, dynamic>{
      'record_id': recordId,
      'consumer_no': consumerNo.isNotEmpty ? consumerNo : localUpdated.consumerNo,
      'followup_date': dateStr,
      'followup_reason': followupReason.trim(),
      'remarks': remarks?.trim(),
      'status': 'PENDING',
      'created_at': nowIso,
      'created_by': user?.id,
      'created_by_name': userName,
      if (relatedType != null) 'related_type': relatedType,
      if (relatedId != null) 'related_id': relatedId,
    };

    if (ConnectivityService.isOffline) {
      await AppDatabase.enqueueOperation(
        OfflineOperation(
          operationId: 'op_${DateTime.now().microsecondsSinceEpoch}',
          entityType: 'consumer_record',
          entityId: recordId,
          action: 'MARK_FOLLOWUP',
          payload: updatePayload,
          userId: user?.id,
          createdAt: DateTime.now(),
        ),
      );
      await AppDatabase.enqueueOperation(
        OfflineOperation(
          operationId: 'op_fu_${DateTime.now().microsecondsSinceEpoch}',
          entityType: 'customer_followup',
          entityId: recordId,
          action: 'MARK_FOLLOWUP',
          payload: followupPayload,
          userId: user?.id,
          createdAt: DateTime.now(),
        ),
      );
      await AppDatabase.logOfflineActivity(
        recordId: recordId,
        consumerNo: consumerNo,
        customerName: localUpdated.name,
        staffName: userName,
        action: 'MARK_FOLLOWUP',
        remarks: 'Follow-up scheduled on $dateStr: $followupReason (Offline)',
      );
      return localUpdated;
    }

    try {
      final response = await _client
          .from('consumer_records')
          .update(updatePayload)
          .eq('id', recordId)
          .select()
          .single();

      final updated = ConsumerRecord.fromJson(response);
      await AppDatabase.upsertConsumerRecord(updated, syncStatus: 'SYNCED');

      try {
        await _client.from('customer_followups').insert(followupPayload);
      } catch (_) {}

      try {
        await _client.from('audit_logs').insert({
          'record_id': recordId,
          'consumer_no': consumerNo.isNotEmpty ? consumerNo : updated.consumerNo,
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
    } catch (_) {
      await AppDatabase.enqueueOperation(
        OfflineOperation(
          operationId: 'op_${DateTime.now().microsecondsSinceEpoch}',
          entityType: 'consumer_record',
          entityId: recordId,
          action: 'MARK_FOLLOWUP',
          payload: updatePayload,
          userId: user?.id,
          createdAt: DateTime.now(),
        ),
      );
      await AppDatabase.enqueueOperation(
        OfflineOperation(
          operationId: 'op_fu_${DateTime.now().microsecondsSinceEpoch}',
          entityType: 'customer_followup',
          entityId: recordId,
          action: 'MARK_FOLLOWUP',
          payload: followupPayload,
          userId: user?.id,
          createdAt: DateTime.now(),
        ),
      );
      return localUpdated;
    }
  }

  /// FOLLOW-UP DONE (Offline-First)
  /// Records Follow-up Result, Remarks, and Optional Next Follow-up Date.
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

    final existing = await AppDatabase.getConsumerRecordById(recordId);
    final consumerNo = existing?.consumerNo ?? '';

    final localUpdated = existing != null
        ? existing.copyWith(
            lastFollowupResult: followupResult.trim(),
            hasActiveFollowup: nextFollowupDate != null,
            followupDate: nextFollowupDate,
            clearFollowup: nextFollowupDate == null,
            followupReason: nextFollowupDate != null ? 'Follow-up Call' : null,
            followupRemarks: nextFollowupDate != null ? remarks?.trim() : null,
            updatedAt: DateTime.now(),
          )
        : ConsumerRecord(
            id: recordId,
            consumerNo: consumerNo,
            name: existing?.name ?? '',
            lastFollowupResult: followupResult.trim(),
            hasActiveFollowup: nextFollowupDate != null,
            followupDate: nextFollowupDate,
            updatedAt: DateTime.now(),
          );

    await AppDatabase.upsertConsumerRecord(localUpdated, syncStatus: 'Pending Sync');

    final updatePayload = <String, dynamic>{
      'last_followup_result': followupResult.trim(),
      'updated_at': nowIso,
      'updated_by': user?.id,
      if (nextFollowupDate != null) ...{
        'has_active_followup': true,
        'followup_date': nextDateStr,
        'followup_reason': 'Follow-up Call',
        'followup_remarks': remarks?.trim(),
      } else ...{
        'has_active_followup': false,
      },
    };

    final completeFollowupPayload = <String, dynamic>{
      'status': 'COMPLETED',
      'followup_result': followupResult.trim(),
      'result_remarks': remarks?.trim(),
      'next_followup_date': nextDateStr,
      'completed_at': nowIso,
      'completed_by': user?.id,
      'completed_by_name': userName,
    };

    if (ConnectivityService.isOffline) {
      await AppDatabase.enqueueOperation(
        OfflineOperation(
          operationId: 'op_${DateTime.now().microsecondsSinceEpoch}',
          entityType: 'consumer_record',
          entityId: recordId,
          action: 'COMPLETE_FOLLOWUP',
          payload: updatePayload,
          userId: user?.id,
          createdAt: DateTime.now(),
        ),
      );
      await AppDatabase.enqueueOperation(
        OfflineOperation(
          operationId: 'op_cf_${DateTime.now().microsecondsSinceEpoch}',
          entityType: 'customer_followup',
          entityId: recordId,
          action: 'COMPLETE_FOLLOWUP',
          payload: completeFollowupPayload,
          userId: user?.id,
          createdAt: DateTime.now(),
        ),
      );
      await AppDatabase.logOfflineActivity(
        recordId: recordId,
        consumerNo: consumerNo,
        customerName: localUpdated.name,
        staffName: userName,
        action: 'FOLLOWUP_DONE',
        remarks: 'Follow-up completed: $followupResult (Offline)',
      );
      return localUpdated;
    }

    try {
      try {
        await _client
            .from('customer_followups')
            .update(completeFollowupPayload)
            .eq('record_id', recordId)
            .eq('status', 'PENDING');
      } catch (_) {}

      final response = await _client
          .from('consumer_records')
          .update(updatePayload)
          .eq('id', recordId)
          .select()
          .single();

      final updated = ConsumerRecord.fromJson(response);
      await AppDatabase.upsertConsumerRecord(updated, syncStatus: 'SYNCED');

      try {
        await _client.from('audit_logs').insert({
          'record_id': recordId,
          'consumer_no': consumerNo.isNotEmpty ? consumerNo : updated.consumerNo,
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
    } catch (_) {
      await AppDatabase.enqueueOperation(
        OfflineOperation(
          operationId: 'op_${DateTime.now().microsecondsSinceEpoch}',
          entityType: 'consumer_record',
          entityId: recordId,
          action: 'COMPLETE_FOLLOWUP',
          payload: updatePayload,
          userId: user?.id,
          createdAt: DateTime.now(),
        ),
      );
      await AppDatabase.enqueueOperation(
        OfflineOperation(
          operationId: 'op_cf_${DateTime.now().microsecondsSinceEpoch}',
          entityType: 'customer_followup',
          entityId: recordId,
          action: 'COMPLETE_FOLLOWUP',
          payload: completeFollowupPayload,
          userId: user?.id,
          createdAt: DateTime.now(),
        ),
      );
      return localUpdated;
    }
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

  /// Mark loan as Rejected with reason, bank remarks, correction required, and log audit entry (Offline-First)
  static Future<ConsumerRecord> markLoanRejected({
    required String recordId,
    required String rejectionReason,
    String? bankRemarks,
    required String correctionRequired,
  }) async {
    final user = SupabaseService.currentUser;
    final nowIso = DateTime.now().toUtc().toIso8601String();

    final existing = await AppDatabase.getConsumerRecordById(recordId);
    final consumerNo = existing?.consumerNo ?? '';

    final localUpdated = existing != null
        ? existing.copyWith(
            loanStatus: 'Rejected',
            customerWorkState: 'ACTIVE',
            updatedAt: DateTime.now(),
          )
        : ConsumerRecord(
            id: recordId,
            consumerNo: consumerNo,
            name: existing?.name ?? '',
            loanStatus: 'Rejected',
            customerWorkState: 'ACTIVE',
            updatedAt: DateTime.now(),
          );

    await AppDatabase.upsertConsumerRecord(localUpdated, syncStatus: 'Pending Sync');

    final updatePayload = <String, dynamic>{
      'loan_status': 'Rejected',
      'loan_sub_stage': 'Loan Rejected',
      'rejection_reason': rejectionReason,
      'bank_remarks': bankRemarks,
      'correction_required': correctionRequired,
      'rejection_date': nowIso,
      'customer_work_state': 'ACTIVE',
      'updated_at': nowIso,
      'updated_by': user?.id,
    };

    if (ConnectivityService.isOffline) {
      await AppDatabase.enqueueOperation(
        OfflineOperation(
          operationId: 'op_${DateTime.now().microsecondsSinceEpoch}',
          entityType: 'consumer_record',
          entityId: recordId,
          action: 'LOAN_REJECTED',
          payload: updatePayload,
          userId: user?.id,
          createdAt: DateTime.now(),
        ),
      );
      await AppDatabase.logOfflineActivity(
        recordId: recordId,
        consumerNo: consumerNo,
        customerName: localUpdated.name,
        staffName: user?.email?.split('@')[0] ?? 'Staff',
        action: 'LOAN_REJECTED',
        remarks: 'Loan rejected: $rejectionReason (Offline)',
      );
      return localUpdated;
    }

    try {
      final response = await _client
          .from('consumer_records')
          .update(updatePayload)
          .eq('id', recordId)
          .select()
          .single();

      final updated = ConsumerRecord.fromJson(response);
      await AppDatabase.upsertConsumerRecord(updated, syncStatus: 'SYNCED');

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
    } catch (_) {
      await AppDatabase.enqueueOperation(
        OfflineOperation(
          operationId: 'op_${DateTime.now().microsecondsSinceEpoch}',
          entityType: 'consumer_record',
          entityId: recordId,
          action: 'LOAN_REJECTED',
          payload: updatePayload,
          userId: user?.id,
          createdAt: DateTime.now(),
        ),
      );
      return localUpdated;
    }
  }

  /// Create new Loan Attempt, increment reapply count, set loan_sub_stage = 'Loan Applied', update history log (Offline-First)
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

    final localUpdated = currentRecord.copyWith(
      loanStatus: 'Applied',
      customerWorkState: 'ACTIVE',
      updatedAt: DateTime.now(),
    );

    await AppDatabase.upsertConsumerRecord(localUpdated, syncStatus: 'Pending Sync');

    final updatePayload = <String, dynamic>{
      'loan_status': 'Applied',
      'loan_sub_stage': 'Loan Applied',
      'loan_reapply_count': nextAttemptNo,
      'last_reapply_date': nowIso,
      'loan_applied_date': nowIso,
      'loan_attempts': updatedAttempts,
      'customer_work_state': 'ACTIVE',
      'updated_at': nowIso,
      'updated_by': user?.id,
    };

    if (ConnectivityService.isOffline) {
      await AppDatabase.enqueueOperation(
        OfflineOperation(
          operationId: 'op_${DateTime.now().microsecondsSinceEpoch}',
          entityType: 'consumer_record',
          entityId: currentRecord.id!,
          action: 'LOAN_REAPPLY',
          payload: updatePayload,
          userId: user?.id,
          createdAt: DateTime.now(),
        ),
      );
      await AppDatabase.logOfflineActivity(
        recordId: currentRecord.id,
        consumerNo: currentRecord.consumerNo,
        customerName: currentRecord.name,
        staffName: user?.email?.split('@')[0] ?? 'Staff',
        action: 'LOAN_REAPPLY',
        remarks: 'Loan re-applied attempt #$nextAttemptNo (Offline)',
      );
      return localUpdated;
    }

    try {
      final response = await _client
          .from('consumer_records')
          .update(updatePayload)
          .eq('id', currentRecord.id!)
          .select()
          .single();

      final updated = ConsumerRecord.fromJson(response);
      await AppDatabase.upsertConsumerRecord(updated, syncStatus: 'SYNCED');

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
    } catch (_) {
      await AppDatabase.enqueueOperation(
        OfflineOperation(
          operationId: 'op_${DateTime.now().microsecondsSinceEpoch}',
          entityType: 'consumer_record',
          entityId: currentRecord.id!,
          action: 'LOAN_REAPPLY',
          payload: updatePayload,
          userId: user?.id,
          createdAt: DateTime.now(),
        ),
      );
      return localUpdated;
    }
  }

  // ===========================================================================
  // MISC (MISCELLANEOUS CUSTOMER ACTIONS) SERVICES - MOBILE (Offline-First)
  // ===========================================================================

  /// Fetch MISC actions for mobile queue (Offline-First)
  static Future<List<CustomerMiscAction>> fetchMiscActions({
    String? statusFilter,
    String? staffFilter,
  }) async {
    if (ConnectivityService.isOffline) {
      return await AppDatabase.getMiscActions(statusFilter: statusFilter);
    }
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
      final list = data.map((j) => CustomerMiscAction.fromJson(j as Map<String, dynamic>)).toList();
      for (final a in list) {
        AppDatabase.upsertMiscAction(a, syncStatus: 'SYNCED').catchError((_) {});
      }
      return list;
    } catch (e) {
      return await AppDatabase.getMiscActions(statusFilter: statusFilter);
    }
  }

  /// Fetch MISC actions for a specific customer (Offline-First)
  static Future<List<CustomerMiscAction>> fetchMiscActionsForCustomer(String recordId) async {
    if (ConnectivityService.isOffline) {
      return await AppDatabase.getMiscActions(recordId: recordId);
    }
    try {
      final response = await _client
          .from('customer_misc_actions')
          .select('*')
          .eq('record_id', recordId)
          .order('created_at', ascending: false);

      final List<dynamic> data = response as List<dynamic>;
      final list = data.map((j) => CustomerMiscAction.fromJson(j as Map<String, dynamic>)).toList();
      for (final a in list) {
        AppDatabase.upsertMiscAction(a, syncStatus: 'SYNCED').catchError((_) {});
      }
      return list;
    } catch (e) {
      return await AppDatabase.getMiscActions(recordId: recordId);
    }
  }

  /// Check active duplicate
  static Future<CustomerMiscAction?> checkDuplicateMiscAction({
    required String recordId,
    required String reason,
  }) async {
    try {
      if (ConnectivityService.isOffline) {
        final all = await AppDatabase.getMiscActions(recordId: recordId);
        for (final m in all) {
          if (m.reason == reason.trim() && (m.status == 'Pending' || m.status == 'In Progress')) {
            return m;
          }
        }
        return null;
      }

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

  /// Create MISC action from Mobile (Offline-First)
  static Future<CustomerMiscAction> createMiscAction(CustomerMiscAction action) async {
    final user = SupabaseService.currentUser;
    final nowIso = DateTime.now().toUtc().toIso8601String();
    final actionId = action.id ?? 'misc_${DateTime.now().microsecondsSinceEpoch}';

    final jsonMap = action.toJson();
    jsonMap['id'] = actionId;
    if (user != null) {
      jsonMap['created_by'] = user.id;
      jsonMap['created_by_name'] = user.email?.split('@')[0] ?? 'Staff';
    }

    final localAction = CustomerMiscAction.fromJson(jsonMap);
    await AppDatabase.upsertMiscAction(localAction, syncStatus: 'Pending Sync');

    if (ConnectivityService.isOffline) {
      await AppDatabase.enqueueOperation(
        OfflineOperation(
          operationId: actionId,
          entityType: 'misc_action',
          entityId: actionId,
          action: 'CREATE_MISC',
          payload: jsonMap,
          userId: user?.id,
          createdAt: DateTime.now(),
        ),
      );
      await AppDatabase.logOfflineActivity(
        recordId: action.recordId,
        consumerNo: action.consumerNo,
        customerName: action.customerName,
        staffName: user?.email?.split('@')[0] ?? 'Staff',
        action: 'MISC_ACTION_CREATED',
        remarks: 'Misc Action: ${action.reason} (Offline)',
      );
      return localAction;
    }

    try {
      final response = await _client
          .from('customer_misc_actions')
          .insert(jsonMap)
          .select()
          .single();

      final created = CustomerMiscAction.fromJson(response);
      await AppDatabase.upsertMiscAction(created, syncStatus: 'SYNCED');

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
    } catch (_) {
      await AppDatabase.enqueueOperation(
        OfflineOperation(
          operationId: actionId,
          entityType: 'misc_action',
          entityId: actionId,
          action: 'CREATE_MISC',
          payload: jsonMap,
          userId: user?.id,
          createdAt: DateTime.now(),
        ),
      );
      return localAction;
    }
  }

  /// Complete MISC action (Offline-First)
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

    if (ConnectivityService.isOffline) {
      await AppDatabase.enqueueOperation(
        OfflineOperation(
          operationId: 'op_cm_${DateTime.now().microsecondsSinceEpoch}',
          entityType: 'misc_action',
          entityId: id,
          action: 'UPDATE_MISC',
          payload: updatePayload,
          userId: user?.id,
          createdAt: DateTime.now(),
        ),
      );
      return CustomerMiscAction(
        id: id,
        recordId: '',
        consumerNo: '',
        customerName: '',
        reason: 'Misc Action',
        status: 'Completed',
        remarks: remarks,
        createdAt: DateTime.now(),
      );
    }

    try {
      final response = await _client
          .from('customer_misc_actions')
          .update(updatePayload)
          .eq('id', id)
          .select()
          .single();

      final completed = CustomerMiscAction.fromJson(response);
      await AppDatabase.upsertMiscAction(completed, syncStatus: 'SYNCED');

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
    } catch (_) {
      await AppDatabase.enqueueOperation(
        OfflineOperation(
          operationId: 'op_cm_${DateTime.now().microsecondsSinceEpoch}',
          entityType: 'misc_action',
          entityId: id,
          action: 'UPDATE_MISC',
          payload: updatePayload,
          userId: user?.id,
          createdAt: DateTime.now(),
        ),
      );
      return CustomerMiscAction(
        id: id,
        recordId: '',
        consumerNo: '',
        customerName: '',
        reason: 'Misc Action',
        status: 'Completed',
        remarks: remarks,
        createdAt: DateTime.now(),
      );
    }
  }

  /// Hold MISC action (Offline-First)
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

    if (ConnectivityService.isOffline) {
      await AppDatabase.enqueueOperation(
        OfflineOperation(
          operationId: 'op_hm_${DateTime.now().microsecondsSinceEpoch}',
          entityType: 'misc_action',
          entityId: id,
          action: 'UPDATE_MISC',
          payload: updatePayload,
          userId: user?.id,
          createdAt: DateTime.now(),
        ),
      );
      return CustomerMiscAction(
        id: id,
        recordId: '',
        consumerNo: '',
        customerName: '',
        reason: 'Misc Action',
        status: 'Hold',
        holdReason: cleanReason,
        remarks: remarks,
        createdAt: DateTime.now(),
      );
    }

    try {
      final response = await _client
          .from('customer_misc_actions')
          .update(updatePayload)
          .eq('id', id)
          .select()
          .single();

      final onHold = CustomerMiscAction.fromJson(response);
      await AppDatabase.upsertMiscAction(onHold, syncStatus: 'SYNCED');

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
    } catch (_) {
      await AppDatabase.enqueueOperation(
        OfflineOperation(
          operationId: 'op_hm_${DateTime.now().microsecondsSinceEpoch}',
          entityType: 'misc_action',
          entityId: id,
          action: 'UPDATE_MISC',
          payload: updatePayload,
          userId: user?.id,
          createdAt: DateTime.now(),
        ),
      );
      return CustomerMiscAction(
        id: id,
        recordId: '',
        consumerNo: '',
        customerName: '',
        reason: 'Misc Action',
        status: 'Hold',
        holdReason: cleanReason,
        remarks: remarks,
        createdAt: DateTime.now(),
      );
    }
  }

  // ============================================================================
  // MOBILE GENERAL ISSUE METHODS (Offline-First)
  // ============================================================================

  /// Fetch active issues for mobile staff (Offline-First)
  static Future<List<CustomerIssue>> fetchIssues({
    String? statusFilter,
    String? assignedStaffFilter,
    String? searchQuery,
  }) async {
    if (ConnectivityService.isOffline) {
      return await AppDatabase.getCustomerIssues(statusFilter: statusFilter);
    }
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
      final list = data.map((j) => CustomerIssue.fromJson(j as Map<String, dynamic>)).toList();
      for (final issue in list) {
        AppDatabase.upsertCustomerIssue(issue, syncStatus: 'SYNCED').catchError((_) {});
      }
      return list;
    } catch (_) {
      return await AppDatabase.getCustomerIssues(statusFilter: statusFilter);
    }
  }

  /// Create issue from mobile (Offline-First)
  static Future<CustomerIssue> createIssue(CustomerIssue issue) async {
    final user = SupabaseService.currentUser;
    final userName = user?.userMetadata?['name'] as String? ?? user?.email ?? 'Mobile Staff';
    final nowIso = DateTime.now().toUtc().toIso8601String();
    final issueId = issue.id ?? 'iss_${DateTime.now().microsecondsSinceEpoch}';

    final payload = issue.toJson();
    payload['id'] = issueId;
    payload['created_by'] = user?.id;
    payload['created_by_name'] = userName;
    payload['created_at'] = nowIso;
    payload['updated_at'] = nowIso;

    final localIssue = CustomerIssue.fromJson(payload);
    await AppDatabase.upsertCustomerIssue(localIssue, syncStatus: 'Pending Sync');

    if (ConnectivityService.isOffline) {
      await AppDatabase.enqueueOperation(
        OfflineOperation(
          operationId: issueId,
          entityType: 'issue',
          entityId: issueId,
          action: 'CREATE_ISSUE',
          payload: payload,
          userId: user?.id,
          createdAt: DateTime.now(),
        ),
      );
      await AppDatabase.logOfflineActivity(
        recordId: issue.customerId,
        consumerNo: issue.consumerNo,
        customerName: issue.customerName,
        staffName: userName,
        action: 'ISSUE_REPORTED',
        remarks: 'Issue: ${issue.title} (Offline)',
      );
      return localIssue;
    }

    try {
      final response = await _client.from('customer_issues').insert(payload).select().single();
      final created = CustomerIssue.fromJson(response);
      await AppDatabase.upsertCustomerIssue(created, syncStatus: 'SYNCED');

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
    } catch (_) {
      await AppDatabase.enqueueOperation(
        OfflineOperation(
          operationId: issueId,
          entityType: 'issue',
          entityId: issueId,
          action: 'CREATE_ISSUE',
          payload: payload,
          userId: user?.id,
          createdAt: DateTime.now(),
        ),
      );
      return localIssue;
    }
  }

  /// Resolve issue from mobile (Offline-First)
  static Future<CustomerIssue> resolveIssue({
    required String issueId,
    String? remarks,
  }) async {
    final user = SupabaseService.currentUser;
    final userName = user?.userMetadata?['name'] as String? ?? user?.email ?? 'Mobile Staff';
    final nowIso = DateTime.now().toUtc().toIso8601String();

    final updatePayload = <String, dynamic>{
      'status': 'Resolved',
      'resolution_remarks': remarks?.trim(),
      'resolved_by': user?.id,
      'resolved_by_name': userName,
      'resolved_at': nowIso,
      'updated_at': nowIso,
    };

    if (ConnectivityService.isOffline) {
      await AppDatabase.enqueueOperation(
        OfflineOperation(
          operationId: 'op_ri_${DateTime.now().microsecondsSinceEpoch}',
          entityType: 'issue',
          entityId: issueId,
          action: 'UPDATE_ISSUE',
          payload: updatePayload,
          userId: user?.id,
          createdAt: DateTime.now(),
        ),
      );
      return CustomerIssue(
        id: issueId,
        customerId: '',
        consumerNo: '',
        customerName: '',
        title: 'Resolved Issue',
        issueType: 'Other',
        status: 'Resolved',
        createdAt: DateTime.now(),
      );
    }

    try {
      final response = await _client
          .from('customer_issues')
          .update(updatePayload)
          .eq('id', issueId)
          .select()
          .single();

      final resolved = CustomerIssue.fromJson(response);
      await AppDatabase.upsertCustomerIssue(resolved, syncStatus: 'SYNCED');

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
    } catch (_) {
      await AppDatabase.enqueueOperation(
        OfflineOperation(
          operationId: 'op_ri_${DateTime.now().microsecondsSinceEpoch}',
          entityType: 'issue',
          entityId: issueId,
          action: 'UPDATE_ISSUE',
          payload: updatePayload,
          userId: user?.id,
          createdAt: DateTime.now(),
        ),
      );
      return CustomerIssue(
        id: issueId,
        customerId: '',
        consumerNo: '',
        customerName: '',
        title: 'Resolved Issue',
        issueType: 'Other',
        status: 'Resolved',
        createdAt: DateTime.now(),
      );
    }
  }

  /// Hold issue from mobile (Offline-First)
  static Future<CustomerIssue> holdIssue({
    required String issueId,
    required String holdReason,
    String? remarks,
  }) async {
    final user = SupabaseService.currentUser;
    final userName = user?.userMetadata?['name'] as String? ?? user?.email ?? 'Mobile Staff';
    final nowIso = DateTime.now().toUtc().toIso8601String();

    final updatePayload = <String, dynamic>{
      'status': 'Hold',
      'hold_reason': holdReason.trim(),
      'remarks': remarks?.trim(),
      'updated_at': nowIso,
    };

    if (ConnectivityService.isOffline) {
      await AppDatabase.enqueueOperation(
        OfflineOperation(
          operationId: 'op_hi_${DateTime.now().microsecondsSinceEpoch}',
          entityType: 'issue',
          entityId: issueId,
          action: 'UPDATE_ISSUE',
          payload: updatePayload,
          userId: user?.id,
          createdAt: DateTime.now(),
        ),
      );
      return CustomerIssue(
        id: issueId,
        customerId: '',
        consumerNo: '',
        customerName: '',
        title: 'Held Issue',
        issueType: 'Other',
        status: 'Hold',
        createdAt: DateTime.now(),
      );
    }

    try {
      final response = await _client
          .from('customer_issues')
          .update(updatePayload)
          .eq('id', issueId)
          .select()
          .single();

      final held = CustomerIssue.fromJson(response);
      await AppDatabase.upsertCustomerIssue(held, syncStatus: 'SYNCED');

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
    } catch (_) {
      await AppDatabase.enqueueOperation(
        OfflineOperation(
          operationId: 'op_hi_${DateTime.now().microsecondsSinceEpoch}',
          entityType: 'issue',
          entityId: issueId,
          action: 'UPDATE_ISSUE',
          payload: updatePayload,
          userId: user?.id,
          createdAt: DateTime.now(),
        ),
      );
      return CustomerIssue(
        id: issueId,
        customerId: '',
        consumerNo: '',
        customerName: '',
        title: 'Held Issue',
        issueType: 'Other',
        status: 'Hold',
        createdAt: DateTime.now(),
      );
    }
  }

  /// Reopen issue from mobile (Offline-First)
  static Future<CustomerIssue> reopenIssue({
    required String issueId,
    String? remarks,
  }) async {
    final user = SupabaseService.currentUser;
    final userName = user?.userMetadata?['name'] as String? ?? user?.email ?? 'Mobile Staff';
    final nowIso = DateTime.now().toUtc().toIso8601String();

    final updatePayload = <String, dynamic>{
      'status': 'In Progress',
      'hold_reason': null,
      'resolution_remarks': null,
      'resolved_at': null,
      'resolved_by': null,
      'resolved_by_name': null,
      'updated_by': user?.id,
      'updated_at': nowIso,
    };

    if (ConnectivityService.isOffline) {
      await AppDatabase.enqueueOperation(
        OfflineOperation(
          operationId: 'op_rei_${DateTime.now().microsecondsSinceEpoch}',
          entityType: 'issue',
          entityId: issueId,
          action: 'UPDATE_ISSUE',
          payload: updatePayload,
          userId: user?.id,
          createdAt: DateTime.now(),
        ),
      );
      return CustomerIssue(
        id: issueId,
        customerId: '',
        consumerNo: '',
        customerName: '',
        title: 'Reopened Issue',
        issueType: 'Other',
        status: 'In Progress',
        createdAt: DateTime.now(),
      );
    }

    try {
      final response = await _client
          .from('customer_issues')
          .update(updatePayload)
          .eq('id', issueId)
          .select()
          .single();

      final reopened = CustomerIssue.fromJson(response);
      await AppDatabase.upsertCustomerIssue(reopened, syncStatus: 'SYNCED');

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
    } catch (_) {
      await AppDatabase.enqueueOperation(
        OfflineOperation(
          operationId: 'op_rei_${DateTime.now().microsecondsSinceEpoch}',
          entityType: 'issue',
          entityId: issueId,
          action: 'UPDATE_ISSUE',
          payload: updatePayload,
          userId: user?.id,
          createdAt: DateTime.now(),
        ),
      );
      return CustomerIssue(
        id: issueId,
        customerId: '',
        consumerNo: '',
        customerName: '',
        title: 'Reopened Issue',
        issueType: 'Other',
        status: 'In Progress',
        createdAt: DateTime.now(),
      );
    }
  }

  // ============================================================================
  // MOBILE PAYMENT METHODS (Offline-First)
  // ============================================================================

  /// Fetch customers with pending payment for mobile (Offline-First)
  static Future<List<ConsumerRecord>> fetchPaymentPendingRecords({
    String? searchQuery,
    String? staffFilter,
  }) async {
    if (ConnectivityService.isOffline) {
      final all = await AppDatabase.getAllConsumerRecords();
      return all.where((r) {
        if (r.deleted || r.isMerged) return false;
        if (r.customerWorkState == 'ON_HOLD') return false;
        if (r.pendingAmount <= 0) return false;
        if (staffFilter != null && staffFilter.isNotEmpty && staffFilter != 'All') {
          if (r.assignedStaff != staffFilter) return false;
        }
        if (searchQuery != null && searchQuery.trim().isNotEmpty) {
          final term = searchQuery.trim().toLowerCase();
          final name = r.name.toLowerCase();
          final cNo = r.consumerNo.toLowerCase();
          final mob = (r.mobile ?? '').toLowerCase();
          if (!name.contains(term) && !cNo.contains(term) && !mob.contains(term)) return false;
        }
        return true;
      }).toList();
    }

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
      final all = await AppDatabase.getAllConsumerRecords();
      return all.where((r) {
        if (r.deleted || r.isMerged) return false;
        if (r.customerWorkState == 'ON_HOLD') return false;
        if (r.pendingAmount <= 0) return false;
        if (staffFilter != null && staffFilter.isNotEmpty && staffFilter != 'All') {
          if (r.assignedStaff != staffFilter) return false;
        }
        if (searchQuery != null && searchQuery.trim().isNotEmpty) {
          final term = searchQuery.trim().toLowerCase();
          final name = r.name.toLowerCase();
          final cNo = r.consumerNo.toLowerCase();
          final mob = (r.mobile ?? '').toLowerCase();
          if (!name.contains(term) && !cNo.contains(term) && !mob.contains(term)) return false;
        }
        return true;
      }).toList();
    }
  }

  /// Add payment transaction from mobile (Offline-First)
  static Future<PaymentTransaction> addPaymentTransaction(PaymentTransaction transaction) async {
    final user = SupabaseService.currentUser;
    final userName = user?.userMetadata?['name'] as String? ?? user?.email ?? 'Mobile Staff';
    final clientTxId = transaction.clientTxId ?? 'tx_${DateTime.now().microsecondsSinceEpoch}';

    final offlineTx = PaymentTransaction(
      id: transaction.id ?? clientTxId,
      clientTxId: clientTxId,
      idempotencyKey: transaction.idempotencyKey ?? 'idem_$clientTxId',
      customerId: transaction.customerId,
      consumerNo: transaction.consumerNo,
      amount: transaction.amount,
      paymentDate: transaction.paymentDate,
      paymentMode: transaction.paymentMode,
      referenceNumber: transaction.referenceNumber,
      receivedBy: transaction.receivedBy,
      remarks: transaction.remarks,
      attachmentUrl: transaction.attachmentUrl,
      localAttachmentPath: transaction.localAttachmentPath,
      status: transaction.status,
      syncStatus: 'Pending Sync',
      createdBy: user?.id,
      createdByName: userName,
      createdAt: DateTime.now(),
    );

    // 1. Save to SQLite cached_payments immediately
    await AppDatabase.upsertPayment(offlineTx, syncStatus: 'Pending Sync');

    // 2. Enqueue offline operation
    await AppDatabase.enqueueOperation(
      OfflineOperation(
        operationId: clientTxId,
        entityType: 'payment',
        entityId: offlineTx.id ?? clientTxId,
        action: 'ADD_PAYMENT',
        payload: offlineTx.toJson(),
        userId: user?.id,
        createdAt: DateTime.now(),
      ),
    );

    // 3. Log activity locally
    await AppDatabase.logOfflineActivity(
      recordId: offlineTx.customerId,
      consumerNo: offlineTx.consumerNo,
      customerName: offlineTx.consumerNo,
      staffName: userName,
      action: 'PAYMENT_RECEIVED',
      remarks: '₹${offlineTx.amount} via ${offlineTx.paymentMode} (${offlineTx.syncStatus})',
    );

    // 4. If online, trigger background sync
    if (ConnectivityService.isOnline) {
      SyncEngine.syncNow().catchError((_) => const SyncResult(success: false));
    }

    return offlineTx;
  }

  /// Fetch customer payment transactions (Offline-First)
  static Future<List<PaymentTransaction>> fetchCustomerPayments(String customerId) async {
    if (ConnectivityService.isOffline) {
      return await AppDatabase.getCustomerPayments(customerId);
    }
    try {
      final res = await _client
          .from('customer_payment_transactions')
          .select()
          .eq('customer_id', customerId)
          .order('payment_date', ascending: false);

      final list = (res as List).map((m) => PaymentTransaction.fromJson(m)).toList();
      for (final tx in list) {
        AppDatabase.upsertPayment(tx, syncStatus: 'Synced').catchError((_) {});
      }
      return list;
    } catch (_) {
      return await AppDatabase.getCustomerPayments(customerId);
    }
  }
}

