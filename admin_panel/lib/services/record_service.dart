import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/consumer_record.dart';
import '../models/record_diff.dart';
import '../models/import_log.dart';
import 'audit_service.dart';
import 'supabase_service.dart';
import 'workflow_engine.dart';
import '../utils/consumer_no_utils.dart';

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

class DashboardMetrics {
  final int totalRecords;
  final int activeUsers;
  final int recentlyUpdated;
  final int totalImportBatches;
  final Map<String, int> statusCounts;
  final List<ConsumerRecord> recentRecords;

  // Action Center Counts
  final int agreementPendingCount;
  final int loanPendingCount;
  final int installationPendingCount;
  final int rtsPendingCount;
  final int subsidyPendingCount;
  final int completedCount;

  // Today's Work Counts
  int get loanFollowupsCount => loanPendingCount;
  int get installationsCount => installationPendingCount;
  int get rtsWorkCount => rtsPendingCount;
  int get agreementsCount => agreementPendingCount;
  int get subsidyProcessingCount => subsidyPendingCount;

  DashboardMetrics({
    required this.totalRecords,
    required this.activeUsers,
    required this.recentlyUpdated,
    this.totalImportBatches = 0,
    required this.statusCounts,
    required this.recentRecords,
    this.agreementPendingCount = 0,
    this.loanPendingCount = 0,
    this.installationPendingCount = 0,
    this.rtsPendingCount = 0,
    this.subsidyPendingCount = 0,
    this.completedCount = 0,
  });
}

class RecordService {
  static SupabaseClient get _client => SupabaseService.client;

  /// Check if the currently authenticated user is an Admin
  static Future<bool> isCurrentUserAdmin() async {
    try {
      final user = SupabaseService.currentUser;
      if (user == null) return false;
      final res = await _client
          .from('profiles')
          .select('role')
          .eq('id', user.id)
          .maybeSingle();
      if (res == null) return false;
      return res['role'] == 'admin';
    } catch (_) {
      return false;
    }
  }

  /// Check if current user has delete permission (either admin or staff with can_delete)
  static Future<bool> canCurrentUserDelete() async {
    try {
      final user = SupabaseService.currentUser;
      if (user == null) return false;
      final res = await _client
          .from('profiles')
          .select('role, can_delete')
          .eq('id', user.id)
          .maybeSingle();
      if (res == null) return false;
      return res['role'] == 'admin' || res['can_delete'] == true;
    } catch (_) {
      return false;
    }
  }

  /// Fetch paginated, filtered, searched and sorted records (excluding soft-deleted)
  static Future<PaginatedResult<ConsumerRecord>> fetchRecords({
    int page = 1,
    int pageSize = 15,
    String? searchQuery,
    String? statusFilter,
    String? workflowQueueFilter, // 'Agreement Pending', 'Loan Pending', 'Installation Pending', 'RTS Pending', 'Subsidy Pending', 'Subsidy Processing', 'Completed'
    String workQueueScope = 'Active', // 'Active', 'Completed', 'Old Applications', 'All'
    String sortBy = 'updated_at',
    bool ascending = false,
  }) async {
    try {
      final from = (page - 1) * pageSize;
      final to = from + pageSize - 1;

      var filterBuilder = _client
          .from('consumer_records')
          .select('*')
          .eq('deleted', false)
          .eq('is_merged', false);

      if (workQueueScope == 'Active') {
        filterBuilder = filterBuilder
            .neq('customer_work_state', 'COMPLETED')
            .neq('subsidy_status', 'Received')
            .neq('status', 'Completed');
      } else if (workQueueScope == 'Completed') {
        filterBuilder = filterBuilder.or('customer_work_state.eq.COMPLETED,subsidy_status.ilike.Received,status.ilike.Completed');
      } else if (workQueueScope == 'Old Applications') {
        final sixtyDaysAgo = DateTime.now().subtract(const Duration(days: 60)).toIso8601String();
        filterBuilder = filterBuilder.lte('submit_date', sixtyDaysAgo);
      }

      if (statusFilter != null && statusFilter.isNotEmpty && statusFilter != 'All') {
        filterBuilder = filterBuilder.eq('status', statusFilter);
      }

      // Workflow Queue filter
      if (workflowQueueFilter != null && workflowQueueFilter.isNotEmpty && workflowQueueFilter != 'All') {
        switch (workflowQueueFilter) {
          case 'Agreement Pending':
            filterBuilder = filterBuilder.eq('agreement_status', 'Pending');
            break;
          case 'Loan Pending':
            filterBuilder = filterBuilder.eq('loan_required', 'Yes').neq('loan_status', 'Approved');
            break;
          case 'Installation Pending':
            filterBuilder = filterBuilder.neq('installation_status', 'Installation Completed');
            break;
          case 'RTS Pending':
            filterBuilder = filterBuilder.eq('installation_status', 'Installation Completed').neq('rts_status', 'Completed');
            break;
          case 'Subsidy Pending':
          case 'Subsidy Processing':
            filterBuilder = filterBuilder.eq('rts_status', 'Completed').neq('subsidy_status', 'Received');
            break;
          case 'Completed':
            filterBuilder = filterBuilder.or('subsidy_status.ilike.Received,status.ilike.Completed');
            break;
        }
      }

      if (searchQuery != null && searchQuery.trim().isNotEmpty) {
        final rawTerm = '%${searchQuery.trim()}%';
        final normTerm = '%${ConsumerNoNormalizer.normalize(searchQuery)}%';
        filterBuilder = filterBuilder.or(
          'consumer_no.ilike.$rawTerm,consumer_no.ilike.$normTerm,name.ilike.$rawTerm,mobile.ilike.$rawTerm,application_id.ilike.$rawTerm',
        );
      }

      final response = await filterBuilder
          .order(sortBy, ascending: ascending)
          .range(from, to)
          .count(CountOption.exact);

      final List<dynamic> data = response.data;
      final int totalCount = response.count;

      final records = data.map((json) => ConsumerRecord.fromJson(json as Map<String, dynamic>)).toList();

      return PaginatedResult<ConsumerRecord>(
        items: records,
        totalCount: totalCount,
        page: page,
        pageSize: pageSize,
      );
    } catch (e, stack) {
      // ignore: avoid_print
      print('Error in RecordService.fetchRecords: $e\n$stack');
      rethrow;
    }
  }

  /// Fetch paginated deleted records (Recycle Bin, admin only)
  static Future<PaginatedResult<ConsumerRecord>> fetchDeletedRecords({
    int page = 1,
    int pageSize = 15,
    String? searchQuery,
  }) async {
    try {
      final from = (page - 1) * pageSize;
      final to = from + pageSize - 1;

      var filterBuilder = _client
          .from('consumer_records')
          .select('*')
          .eq('deleted', true);

      if (searchQuery != null && searchQuery.trim().isNotEmpty) {
        final term = '%${searchQuery.trim()}%';
        filterBuilder = filterBuilder.or(
          'consumer_no.ilike.$term,name.ilike.$term,mobile.ilike.$term,application_id.ilike.$term',
        );
      }

      final response = await filterBuilder
          .order('deleted_at', ascending: false)
          .range(from, to)
          .count(CountOption.exact);

      final List<dynamic> data = response.data;
      final int totalCount = response.count;

      final records = data.map((json) => ConsumerRecord.fromJson(json as Map<String, dynamic>)).toList();

      return PaginatedResult<ConsumerRecord>(
        items: records,
        totalCount: totalCount,
        page: page,
        pageSize: pageSize,
      );
    } catch (e, stack) {
      // ignore: avoid_print
      print('Error in RecordService.fetchDeletedRecords: $e\n$stack');
      rethrow;
    }
  }

  /// Create a new consumer record
  static Future<ConsumerRecord> createRecord(ConsumerRecord record) async {
    final user = SupabaseService.currentUser;
    final payload = record.toJson();
    if (user != null) {
      payload['created_by'] = user.id;
      payload['updated_by'] = user.id;
    }

    final response = await _client
        .from('consumer_records')
        .insert(payload)
        .select()
        .single();

    return ConsumerRecord.fromJson(response);
  }

  /// Update an existing record
  static Future<ConsumerRecord> updateRecord(ConsumerRecord record) async {
    if (record.id == null) {
      throw Exception('Cannot update record without an ID');
    }

    final user = SupabaseService.currentUser;
    final payload = record.toJson();
    if (user != null) {
      payload['updated_by'] = user.id;
    }

    final response = await _client
        .from('consumer_records')
        .update(payload)
        .eq('id', record.id!)
        .select()
        .single();

    return ConsumerRecord.fromJson(response);
  }

  /// Soft delete a single record
  static Future<void> deleteRecord(String id, {String? consumerNo}) async {
    await softDeleteMultipleRecords([id]);
  }

  /// Soft delete multiple records (moves to Recycle Bin)
  static Future<int> softDeleteMultipleRecords(List<String> recordIds) async {
    if (recordIds.isEmpty) {
      throw Exception('No records selected for deletion.');
    }

    final user = SupabaseService.currentUser;
    final nowIso = DateTime.now().toUtc().toIso8601String();

    // 1. Fetch consumer_nos for audit logs
    final fetched = await _client
        .from('consumer_records')
        .select('id, consumer_no')
        .inFilter('id', recordIds);

    // 2. Perform soft delete update
    await _client.from('consumer_records').update({
      'deleted': true,
      'deleted_at': nowIso,
      'deleted_by': user?.id,
    }).inFilter('id', recordIds);

    // 3. Insert audit log entries
    final auditLogs = (fetched as List<dynamic>).map((row) {
      return {
        'record_id': row['id'],
        'consumer_no': row['consumer_no'],
        'action': recordIds.length > 1 ? 'BULK_DELETE' : 'DELETE',
        'field_name': 'deleted',
        'old_value': 'false',
        'new_value': 'true',
        'changed_by': user?.id,
        'source': 'Admin Web',
        'created_at': nowIso,
      };
    }).toList();

    if (auditLogs.isNotEmpty) {
      try {
        await _client.from('audit_logs').insert(auditLogs);
      } catch (_) {
        // Non-blocking audit log insert
      }
    }

    return recordIds.length;
  }

  /// Restore soft-deleted records from Recycle Bin (Admin only)
  static Future<int> restoreRecords(List<String> recordIds) async {
    if (recordIds.isEmpty) {
      throw Exception('No records selected to restore.');
    }

    final user = SupabaseService.currentUser;
    final nowIso = DateTime.now().toUtc().toIso8601String();

    // 1. Fetch consumer_nos for audit logs
    final fetched = await _client
        .from('consumer_records')
        .select('id, consumer_no')
        .inFilter('id', recordIds);

    // 2. Clear soft delete flags
    await _client.from('consumer_records').update({
      'deleted': false,
      'deleted_at': null,
      'deleted_by': null,
      'updated_at': nowIso,
      'updated_by': user?.id,
    }).inFilter('id', recordIds);

    // 3. Insert audit logs
    final auditLogs = (fetched as List<dynamic>).map((row) {
      return {
        'record_id': row['id'],
        'consumer_no': row['consumer_no'],
        'action': 'RESTORE',
        'field_name': 'deleted',
        'old_value': 'true',
        'new_value': 'false',
        'changed_by': user?.id,
        'source': 'Admin Web',
        'created_at': nowIso,
      };
    }).toList();

    if (auditLogs.isNotEmpty) {
      try {
        await _client.from('audit_logs').insert(auditLogs);
      } catch (_) {}
    }

    return recordIds.length;
  }

  /// Permanently delete records from database (Admin only)
  static Future<int> permanentDeleteRecords(List<String> recordIds) async {
    if (recordIds.isEmpty) {
      throw Exception('No records selected for permanent deletion.');
    }

    final user = SupabaseService.currentUser;
    final nowIso = DateTime.now().toUtc().toIso8601String();

    // 1. Fetch consumer_nos for audit logs before hard delete
    final fetched = await _client
        .from('consumer_records')
        .select('id, consumer_no')
        .inFilter('id', recordIds);

    // 2. Hard delete records
    await _client.from('consumer_records').delete().inFilter('id', recordIds);

    // 3. Insert audit logs
    final auditLogs = (fetched as List<dynamic>).map((row) {
      return {
        'record_id': row['id'],
        'consumer_no': row['consumer_no'],
        'action': 'PERMANENT_DELETE',
        'field_name': 'all_fields',
        'old_value': 'Record Existed',
        'new_value': 'Permanently Removed',
        'changed_by': user?.id,
        'source': 'Admin Web',
        'created_at': nowIso,
      };
    }).toList();

    if (auditLogs.isNotEmpty) {
      try {
        await _client.from('audit_logs').insert(auditLogs);
      } catch (_) {}
    }

    return recordIds.length;
  }

  /// Bulk import records in batches of 50 with real-time progress callbacks
  static Future<Map<String, int>> bulkImportRecords({
    required List<ConsumerRecord> records,
    Function(int current, int total)? onProgress,
  }) async {
    final user = SupabaseService.currentUser;
    int successCount = 0;
    int errorCount = 0;
    Object? firstError;
    const batchSize = 50;

    for (int i = 0; i < records.length; i += batchSize) {
      final end = (i + batchSize < records.length) ? i + batchSize : records.length;
      final batch = records.sublist(i, end);

      final payloads = batch.map((r) {
        final map = r.toJson();
        if (user != null) {
          map['created_by'] = user.id;
          map['updated_by'] = user.id;
        }
        return map;
      }).toList();

      try {
        await _client
            .from('consumer_records')
            .upsert(payloads, onConflict: 'consumer_no');
        successCount += batch.length;
      } catch (e) {
        firstError ??= e;
        // Fallback: try individual inserts in this batch to maximize successful imports
        for (final payload in payloads) {
          try {
            await _client
                .from('consumer_records')
                .upsert(payload, onConflict: 'consumer_no');
            successCount++;
          } catch (individualError) {
            firstError ??= individualError;
            errorCount++;
          }
        }
      }

      if (onProgress != null) {
        onProgress(end, records.length);
      }
    }

    // If every single record failed, surface the error instead of silently succeeding
    if (successCount == 0 && errorCount > 0 && firstError != null) {
      throw Exception(
        'All $errorCount records failed to import. Check your permissions or database connection. Error: $firstError',
      );
    }

    return {
      'total': records.length,
      'success': successCount,
      'errors': errorCount,
    };
  }

  /// Execute smart import with duplicate resolution strategy, sparse field updates, and audit trail logging
  static Future<Map<String, int>> executeSmartImport({
    required List<ConsumerRecord> newRecords,
    required List<RecordDiff> conflictRecords,
    required ConflictStrategy strategy,
    Set<String>? allowedFieldKeys,
    bool ignoreBlankValues = true,
    String? fileName,
    int? fileSizeBytes,
    Function(int current, int total)? onProgress,
  }) async {
    final user = SupabaseService.currentUser;
    int insertedCount = 0;
    int updatedCount = 0;
    int skippedCount = 0;
    int errorCount = 0;

    final totalItems = newRecords.length + conflictRecords.length;
    int processedItems = 0;

    // 1. Insert brand new records
    if (newRecords.isNotEmpty) {
      final insertResult = await bulkImportRecords(
        records: newRecords,
        onProgress: (current, total) {
          processedItems = current;
          if (onProgress != null) {
            onProgress(processedItems, totalItems);
          }
        },
      );
      insertedCount = insertResult['success'] ?? 0;
      errorCount += insertResult['errors'] ?? 0;
    }

    // 2. Process modified records strictly with sparse payloads
    final auditLogs = <Map<String, dynamic>>[];

    for (final diff in conflictRecords) {
      if (strategy == ConflictStrategy.skipExisting || !diff.shouldUpdate) {
        skippedCount++;
        processedItems++;
        if (onProgress != null) onProgress(processedItems, totalItems);
        continue;
      }

      // Build strictly sparse payload containing ONLY allowed, changed fields
      final sparsePayload = diff.buildUpdatePayload(
        allowedFieldKeys: allowedFieldKeys,
        ignoreBlankValues: ignoreBlankValues,
      );

      // If no allowed fields changed (e.g. blank ignored or skipped), skip DB update
      if (sparsePayload.isEmpty) {
        skippedCount++;
        processedItems++;
        if (onProgress != null) onProgress(processedItems, totalItems);
        continue;
      }

      if (user != null) {
        sparsePayload['updated_by'] = user.id;
      }
      sparsePayload['updated_at'] = DateTime.now().toUtc().toIso8601String();

      try {
        await _client
            .from('consumer_records')
            .update(sparsePayload)
            .eq('consumer_no', diff.existingRecord.consumerNo);
        updatedCount++;

        // Prepare audit log entries ONLY for fields that were actually updated in DB
        for (final entry in sparsePayload.entries) {
          if (entry.key == 'updated_by' || entry.key == 'updated_at') continue;

          // Find human-readable label
          final matchingDiff = diff.changedFields.firstWhere(
            (f) => f.fieldKey == entry.key,
            orElse: () => FieldDiff(fieldKey: entry.key, fieldLabel: entry.key),
          );

          auditLogs.add({
            'record_id': diff.existingRecord.id,
            'consumer_no': diff.existingRecord.consumerNo,
            'action': 'UPDATE',
            'field_name': matchingDiff.fieldLabel,
            'old_value': matchingDiff.oldValue,
            'new_value': entry.value?.toString(),
            'changed_by': user?.id,
            'source': 'Excel / CSV Import',
            'created_at': DateTime.now().toUtc().toIso8601String(),
          });
        }
      } catch (e) {
        errorCount++;
      }

      processedItems++;
      if (onProgress != null) onProgress(processedItems, totalItems);
    }

    // 3. Batch insert audit logs
    if (auditLogs.isNotEmpty) {
      try {
        const auditBatchSize = 100;
        for (int i = 0; i < auditLogs.length; i += auditBatchSize) {
          final end = (i + auditBatchSize < auditLogs.length) ? i + auditBatchSize : auditLogs.length;
          final batch = auditLogs.sublist(i, end);
          await _client.from('audit_logs').insert(batch);
        }
      } catch (_) {
        // Audit log insert failure doesn't block the main flow
      }
    }

    // 4. Log overall import batch run in import_logs
    if (fileName != null) {
      await AuditService.logImportRun(
        ImportLog(
          fileName: fileName,
          fileSizeBytes: fileSizeBytes ?? 0,
          totalRows: totalItems,
          insertedCount: insertedCount,
          updatedCount: updatedCount,
          skippedCount: skippedCount,
          failedCount: errorCount,
          strategy: strategy.name,
          createdAt: DateTime.now(),
        ),
      );
    }

    return {
      'total': totalItems,
      'inserted': insertedCount,
      'updated': updatedCount,
      'skipped': skippedCount,
      'errors': errorCount,
    };
  }

  /// Fetch dashboard metrics
  static Future<DashboardMetrics> fetchDashboardMetrics() async {
    try {
      final recordsCountResponse = await _client
          .from('consumer_records')
          .select('id')
          .eq('deleted', false)
          .eq('is_merged', false)
          .count(CountOption.exact);
      final totalRecords = recordsCountResponse.count;

      int totalImportBatches = 0;
      try {
        final importLogsCountResponse = await _client
            .from('import_logs')
            .select('id')
            .count(CountOption.exact);
        totalImportBatches = importLogsCountResponse.count;
      } catch (_) {}

      final recentResponse = await _client
          .from('consumer_records')
          .select('*')
          .eq('deleted', false)
          .eq('is_merged', false)
          .order('updated_at', ascending: false)
          .limit(5);

      final List<dynamic> recentData = recentResponse as List<dynamic>;
      final recentRecords = recentData
          .map((json) => ConsumerRecord.fromJson(json as Map<String, dynamic>))
          .toList();

      // Action Center Counts (evaluated via WorkflowEngine)
      int agreementPending = 0;
      int loanPending = 0;
      int installationPending = 0;
      int rtsPending = 0;
      int subsidyPending = 0;
      int completedCount = 0;

      try {
        final allRes = await _client
            .from('consumer_records')
            .select('*')
            .eq('deleted', false)
            .eq('is_merged', false);
        final List<dynamic> allData = allRes as List<dynamic>;
        for (final row in allData) {
          final rec = ConsumerRecord.fromJson(row as Map<String, dynamic>);
          final stage = WorkflowEngine.getCurrentWorkStage(rec);
          if (rec.customerWorkState.toUpperCase() == 'COMPLETED' || stage == 'Completed') {
            completedCount++;
          } else {
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
                subsidyPending++;
                break;
            }
          }
        }
      } catch (_) {}

      final statusCounts = <String, int>{
        'Pending': 0,
        'Approved': 0,
        'In Progress': 0,
        'Completed': 0,
        'Rejected': 0,
      };

      try {
        final statusRes = await _client
            .from('consumer_records')
            .select('status')
            .eq('deleted', false)
            .eq('is_merged', false);
        for (final row in (statusRes as List<dynamic>)) {
          final s = row['status'] as String? ?? 'Pending';
          statusCounts[s] = (statusCounts[s] ?? 0) + 1;
        }
      } catch (_) {}

      return DashboardMetrics(
        totalRecords: totalRecords,
        activeUsers: 1,
        recentlyUpdated: recentRecords.length,
        totalImportBatches: totalImportBatches,
        statusCounts: statusCounts,
        recentRecords: recentRecords,
        agreementPendingCount: agreementPending,
        loanPendingCount: loanPending,
        installationPendingCount: installationPending,
        rtsPendingCount: rtsPending,
        subsidyPendingCount: subsidyPending,
        completedCount: completedCount,
      );
    } catch (_) {
      return DashboardMetrics(
        totalRecords: 0,
        activeUsers: 1,
        recentlyUpdated: 0,
        totalImportBatches: 0,
        statusCounts: {},
        recentRecords: [],
      );
    }
  }

  /// Fetch records for Smart Action Center module
  static Future<PaginatedResult<ConsumerRecord>> fetchActionCenterRecords({
    int page = 1,
    int pageSize = 15,
    String? stageFilter, // 'ALL', 'Agreement Pending', 'Loan Pending', 'Installation Pending', 'RTS Pending', 'Subsidy Processing', 'Completed'
    String? assignedStaffFilter,
    String? searchQuery,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final from = (page - 1) * pageSize;

      var filterBuilder = _client
          .from('consumer_records')
          .select('*')
          .eq('deleted', false)
          .eq('is_merged', false);

      if (assignedStaffFilter != null && assignedStaffFilter.isNotEmpty && assignedStaffFilter != 'All') {
        final st = assignedStaffFilter.trim();
        filterBuilder = filterBuilder.or('assigned_staff.ilike.%$st%,installer_team.ilike.%$st%');
      }

      if (startDate != null) {
        filterBuilder = filterBuilder.gte('submit_date', startDate.toIso8601String());
      }
      if (endDate != null) {
        filterBuilder = filterBuilder.lte('submit_date', endDate.toIso8601String());
      }

      if (searchQuery != null && searchQuery.trim().isNotEmpty) {
        final rawTerm = '%${searchQuery.trim()}%';
        final normTerm = '%${ConsumerNoNormalizer.normalize(searchQuery)}%';
        filterBuilder = filterBuilder.or(
          'consumer_no.ilike.$rawTerm,consumer_no.ilike.$normTerm,name.ilike.$rawTerm,mobile.ilike.$rawTerm,application_id.ilike.$rawTerm',
        );
      }

      final response = await filterBuilder;
      final List<dynamic> data = response as List<dynamic>;
      List<ConsumerRecord> records = data.map((j) => ConsumerRecord.fromJson(j as Map<String, dynamic>)).toList();

      // Stage Filtering
      if (stageFilter != null && stageFilter.isNotEmpty && stageFilter.toUpperCase() != 'ALL') {
        final sf = stageFilter.trim().toLowerCase();
        if (sf.contains('agreement')) {
          records = records.where((r) => r.customerWorkState.toUpperCase() != 'COMPLETED' && r.overallStage == 'Agreement').toList();
        } else if (sf.contains('loan')) {
          records = records.where((r) => r.customerWorkState.toUpperCase() != 'COMPLETED' && r.overallStage == 'Loan').toList();
        } else if (sf.contains('installation')) {
          records = records.where((r) => r.customerWorkState.toUpperCase() != 'COMPLETED' && r.overallStage == 'Installation').toList();
        } else if (sf.contains('rts')) {
          records = records.where((r) => r.customerWorkState.toUpperCase() != 'COMPLETED' && r.overallStage == 'RTS').toList();
        } else if (sf.contains('subsidy')) {
          records = records.where((r) => r.customerWorkState.toUpperCase() != 'COMPLETED' && r.overallStage == 'Subsidy').toList();
        } else if (sf.contains('completed')) {
          records = records.where((r) => r.customerWorkState.toUpperCase() == 'COMPLETED' || r.overallStage == 'Completed').toList();
        }
      }

      // Sort Action Center: 1) Days in Stage DESC, 2) Application Days DESC, 3) Application Date ASC
      WorkflowEngine.sortRecordsForActionCenter(records);

      final totalCount = records.length;
      final pagedItems = records.skip(from).take(pageSize).toList();

      return PaginatedResult<ConsumerRecord>(
        items: pagedItems,
        totalCount: totalCount,
        page: page,
        pageSize: pageSize,
      );
    } catch (e, stack) {
      // ignore: avoid_print
      print('Error in RecordService.fetchActionCenterRecords: $e\n$stack');
      rethrow;
    }
  }

  /// Backward-compatible alias for fetchActionCenterRecords
  static Future<PaginatedResult<ConsumerRecord>> fetchPriorityRecords({
    int page = 1,
    int pageSize = 15,
    String? priorityFilter,
    String? applicationStatusFilter,
    String? assignedStaffFilter,
    String? searchQuery,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    return fetchActionCenterRecords(
      page: page,
      pageSize: pageSize,
      stageFilter: priorityFilter,
      assignedStaffFilter: assignedStaffFilter,
      searchQuery: searchQuery,
      startDate: startDate,
      endDate: endDate,
    );
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
        'source': 'Admin Web',
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
        'source': 'Admin Web',
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
        'source': 'Admin Web',
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
        'source': 'Admin Web',
        'created_at': nowIso,
      });
    } catch (_) {}

    return updated;
  }
}
