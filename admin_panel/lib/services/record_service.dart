import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/consumer_record.dart';
import '../models/record_diff.dart';
import '../models/import_log.dart';
import 'audit_service.dart';
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

class DashboardMetrics {
  final int totalRecords;
  final int activeUsers;
  final int recentlyUpdated;
  final int totalImportBatches;
  final Map<String, int> statusCounts;
  final List<ConsumerRecord> recentRecords;

  DashboardMetrics({
    required this.totalRecords,
    required this.activeUsers,
    required this.recentlyUpdated,
    this.totalImportBatches = 0,
    required this.statusCounts,
    required this.recentRecords,
  });
}

class RecordService {
  static SupabaseClient get _client => SupabaseService.client;

  /// Fetch paginated, filtered, searched and sorted records
  static Future<PaginatedResult<ConsumerRecord>> fetchRecords({
    int page = 1,
    int pageSize = 15,
    String? searchQuery,
    String? statusFilter,
    String sortBy = 'updated_at',
    bool ascending = false,
  }) async {
    try {
      final from = (page - 1) * pageSize;
      final to = from + pageSize - 1;

      var filterBuilder = _client.from('consumer_records').select('*');

      if (statusFilter != null && statusFilter.isNotEmpty && statusFilter != 'All') {
        filterBuilder = filterBuilder.eq('status', statusFilter);
      }

      if (searchQuery != null && searchQuery.trim().isNotEmpty) {
        final term = '%${searchQuery.trim()}%';
        filterBuilder = filterBuilder.or(
          'consumer_no.ilike.$term,name.ilike.$term,mobile.ilike.$term,application_id.ilike.$term',
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
    } catch (e) {
      return PaginatedResult<ConsumerRecord>(
        items: [],
        totalCount: 0,
        page: page,
        pageSize: pageSize,
      );
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

  /// Delete a record
  static Future<void> deleteRecord(String id) async {
    await _client.from('consumer_records').delete().eq('id', id);
  }

  /// Bulk import records in batches of 50 with real-time progress callbacks
  static Future<Map<String, int>> bulkImportRecords({
    required List<ConsumerRecord> records,
    Function(int current, int total)? onProgress,
  }) async {
    final user = SupabaseService.currentUser;
    int successCount = 0;
    int errorCount = 0;
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
        // Fallback: try individual inserts in this batch to maximize successful imports
        for (final payload in payloads) {
          try {
            await _client
                .from('consumer_records')
                .upsert(payload, onConflict: 'consumer_no');
            successCount++;
          } catch (_) {
            errorCount++;
          }
        }
      }

      if (onProgress != null) {
        onProgress(end, records.length);
      }
    }

    return {
      'total': records.length,
      'success': successCount,
      'errors': errorCount,
    };
  }

  /// Execute smart import with duplicate resolution strategy and audit trail logging
  static Future<Map<String, int>> executeSmartImport({
    required List<ConsumerRecord> newRecords,
    required List<RecordDiff> conflictRecords,
    required ConflictStrategy strategy,
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

    // 2. Process modified records
    final auditLogs = <Map<String, dynamic>>[];

    for (final diff in conflictRecords) {
      if (strategy == ConflictStrategy.skipExisting || !diff.shouldUpdate) {
        skippedCount++;
        processedItems++;
        if (onProgress != null) onProgress(processedItems, totalItems);
        continue;
      }

      final mergedRecord = diff.createMergedRecord(strategy);
      final payload = mergedRecord.toJson();
      if (user != null) {
        payload['updated_by'] = user.id;
      }

      try {
        await _client
            .from('consumer_records')
            .update(payload)
            .eq('consumer_no', mergedRecord.consumerNo);
        updatedCount++;

        // Prepare audit log entries for each changed field
        for (final field in diff.changedFields) {
          // If updateNonEmptyOnly and new field was empty, it wasn't overwritten
          if (strategy == ConflictStrategy.updateNonEmptyOnly && field.isNewEmpty) {
            continue;
          }

          auditLogs.add({
            'record_id': diff.existingRecord.id,
            'consumer_no': diff.existingRecord.consumerNo,
            'action': 'UPDATE',
            'field_name': field.fieldLabel,
            'old_value': field.oldValue,
            'new_value': field.newValue,
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
          .order('updated_at', ascending: false)
          .limit(5);

      final List<dynamic> recentData = recentResponse as List<dynamic>;
      final recentRecords = recentData
          .map((json) => ConsumerRecord.fromJson(json as Map<String, dynamic>))
          .toList();

      final statusCounts = <String, int>{
        'Pending': 0,
        'Approved': 0,
        'In Progress': 0,
        'Completed': 0,
        'Rejected': 0,
      };

      return DashboardMetrics(
        totalRecords: totalRecords,
        activeUsers: 1,
        recentlyUpdated: recentRecords.length,
        totalImportBatches: totalImportBatches,
        statusCounts: statusCounts,
        recentRecords: recentRecords,
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
}
