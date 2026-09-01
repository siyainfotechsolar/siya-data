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

class DashboardMetrics {
  final int totalRecords;
  final int activeUsers;
  final int recentlyUpdated;
  final Map<String, int> statusCounts;
  final List<ConsumerRecord> recentRecords;

  DashboardMetrics({
    required this.totalRecords,
    required this.activeUsers,
    required this.recentlyUpdated,
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

  /// Fetch dashboard metrics
  static Future<DashboardMetrics> fetchDashboardMetrics() async {
    try {
      final recordsCountResponse = await _client
          .from('consumer_records')
          .select('id')
          .count(CountOption.exact);
      final totalRecords = recordsCountResponse.count;

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
        statusCounts: statusCounts,
        recentRecords: recentRecords,
      );
    } catch (_) {
      return DashboardMetrics(
        totalRecords: 0,
        activeUsers: 1,
        recentlyUpdated: 0,
        statusCounts: {},
        recentRecords: [],
      );
    }
  }
}
