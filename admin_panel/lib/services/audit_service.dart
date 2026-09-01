import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/import_log.dart';
import 'record_service.dart';
import 'supabase_service.dart';

class AuditService {
  static SupabaseClient get _client => SupabaseService.client;

  /// Fetch paginated import batch logs
  static Future<PaginatedResult<ImportLog>> fetchImportLogs({
    int page = 1,
    int pageSize = 15,
  }) async {
    try {
      final from = (page - 1) * pageSize;
      final to = from + pageSize - 1;

      final response = await _client
          .from('import_logs')
          .select('*, profiles(email)')
          .order('created_at', ascending: false)
          .range(from, to)
          .count(CountOption.exact);

      final List<dynamic> data = response.data;
      final int totalCount = response.count;

      final logs = data.map((json) => ImportLog.fromJson(json as Map<String, dynamic>)).toList();

      return PaginatedResult<ImportLog>(
        items: logs,
        totalCount: totalCount,
        page: page,
        pageSize: pageSize,
      );
    } catch (e) {
      return PaginatedResult<ImportLog>(
        items: [],
        totalCount: 0,
        page: page,
        pageSize: pageSize,
      );
    }
  }

  /// Fetch paginated field-level audit logs
  static Future<PaginatedResult<AuditLogEntry>> fetchAuditLogs({
    int page = 1,
    int pageSize = 20,
    String? searchQuery,
    String? actionFilter,
  }) async {
    try {
      final from = (page - 1) * pageSize;
      final to = from + pageSize - 1;

      var queryBuilder = _client.from('audit_logs').select('*, profiles(email)');

      if (actionFilter != null && actionFilter.isNotEmpty && actionFilter != 'All') {
        queryBuilder = queryBuilder.eq('action', actionFilter);
      }

      if (searchQuery != null && searchQuery.trim().isNotEmpty) {
        final term = '%${searchQuery.trim()}%';
        queryBuilder = queryBuilder.or('consumer_no.ilike.$term,field_name.ilike.$term,new_value.ilike.$term');
      }

      final response = await queryBuilder
          .order('created_at', ascending: false)
          .range(from, to)
          .count(CountOption.exact);

      final List<dynamic> data = response.data;
      final int totalCount = response.count;

      final entries = data.map((json) => AuditLogEntry.fromJson(json as Map<String, dynamic>)).toList();

      return PaginatedResult<AuditLogEntry>(
        items: entries,
        totalCount: totalCount,
        page: page,
        pageSize: pageSize,
      );
    } catch (e) {
      return PaginatedResult<AuditLogEntry>(
        items: [],
        totalCount: 0,
        page: page,
        pageSize: pageSize,
      );
    }
  }

  /// Record a new import batch run
  static Future<void> logImportRun(ImportLog log) async {
    try {
      final payload = log.toJson();
      final user = SupabaseService.currentUser;
      if (user != null) {
        payload['created_by'] = user.id;
      }
      await _client.from('import_logs').insert(payload);
    } catch (_) {
      // Non-blocking log insert
    }
  }
}
