import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/activity_log.dart';
import 'supabase_service.dart';

class PaginatedActivityResult {
  final List<ActivityLog> items;
  final int totalCount;
  final int page;
  final int pageSize;

  const PaginatedActivityResult({
    required this.items,
    required this.totalCount,
    required this.page,
    required this.pageSize,
  });
}

class ActivityLogService {
  static SupabaseClient get _client => SupabaseService.client;
  static Map<String, dynamic>? _cachedProfile;

  /// Centralized logging method for all operational actions in Siya Solar Connect
  static Future<void> logActivity({
    String? recordId,
    required String consumerNo,
    required String customerName,
    String village = '-',
    required String module,
    required String action,
    String? oldValue,
    String? newValue,
    String? nextAction,
    String? remarks,
    String source = 'Admin Web',
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final user = SupabaseService.currentUser;
      String staffName = 'Admin';
      String staffRole = 'admin';

      if (user != null) {
        if (_cachedProfile == null) {
          try {
            final profile = await _client
                .from('profiles')
                .select('full_name, role, email')
                .eq('id', user.id)
                .maybeSingle();
            _cachedProfile = profile;
          } catch (_) {}
        }

        if (_cachedProfile != null) {
          staffName = _cachedProfile?['full_name'] ??
              user.email?.split('@').first ??
              'Admin';
          staffRole = _cachedProfile?['role'] ?? 'admin';
        } else {
          staffName = user.email?.split('@').first ?? 'Admin';
        }
      }

      await _client.from('activity_logs').insert({
        'record_id': recordId,
        'consumer_no': consumerNo.trim(),
        'customer_name': customerName.trim(),
        'village': village.trim().isNotEmpty ? village.trim() : '-',
        'module': module.trim(),
        'action': action.trim(),
        'old_value': oldValue,
        'new_value': newValue,
        'next_action': nextAction,
        'remarks': remarks,
        'staff_id': user?.id,
        'staff_name': staffName,
        'staff_role': staffRole,
        'source': source,
        'metadata': metadata,
        'created_at': DateTime.now().toUtc().toIso8601String(),
      });
    } catch (e) {
      // ignore: avoid_print
      print('ActivityLogService write error: $e');
    }
  }

  /// Fetch complete chronological timeline for a specific customer
  static Future<List<ActivityLog>> fetchCustomerTimeline({
    String? recordId,
    required String consumerNo,
  }) async {
    try {
      var query = _client.from('activity_logs').select();

      if (recordId != null && recordId.isNotEmpty) {
        query = query.or('record_id.eq.$recordId,consumer_no.eq.$consumerNo');
      } else {
        query = query.eq('consumer_no', consumerNo);
      }

      final response = await query.order('created_at', ascending: false).limit(100);
      final List<dynamic> data = response as List<dynamic>;
      return data.map((json) => ActivityLog.fromJson(json as Map<String, dynamic>)).toList();
    } catch (e) {
      return [];
    }
  }

  /// Fetch paginated activity logs with full filter capabilities
  static Future<PaginatedActivityResult> fetchActivityLogs({
    int page = 1,
    int pageSize = 20,
    DateTime? startDate,
    DateTime? endDate,
    String? staffFilter,
    String? customerQuery,
    String? villageFilter,
    String? moduleFilter,
    String? actionFilter,
  }) async {
    try {
      final from = (page - 1) * pageSize;
      final to = from + pageSize - 1;

      var query = _client.from('activity_logs').select('*');

      if (startDate != null) {
        final startIso = DateTime(startDate.year, startDate.month, startDate.day, 0, 0, 0).toUtc().toIso8601String();
        query = query.gte('created_at', startIso);
      }
      if (endDate != null) {
        final endIso = DateTime(endDate.year, endDate.month, endDate.day, 23, 59, 59).toUtc().toIso8601String();
        query = query.lte('created_at', endIso);
      }

      if (staffFilter != null && staffFilter.isNotEmpty && staffFilter != 'All') {
        query = query.eq('staff_name', staffFilter);
      }
      if (villageFilter != null && villageFilter.isNotEmpty && villageFilter != 'All') {
        query = query.ilike('village', '%$villageFilter%');
      }
      if (moduleFilter != null && moduleFilter.isNotEmpty && moduleFilter != 'All') {
        query = query.eq('module', moduleFilter);
      }
      if (actionFilter != null && actionFilter.isNotEmpty && actionFilter != 'All') {
        query = query.eq('action', actionFilter);
      }
      if (customerQuery != null && customerQuery.trim().isNotEmpty) {
        final term = customerQuery.trim();
        query = query.or('consumer_no.ilike.%$term%,customer_name.ilike.%$term%');
      }

      final response = await query
          .order('created_at', ascending: false)
          .range(from, to)
          .count(CountOption.exact);
      final List<dynamic> data = response.data as List<dynamic>;
      final int total = response.count;

      final items = data.map((json) => ActivityLog.fromJson(json as Map<String, dynamic>)).toList();

      return PaginatedActivityResult(
        items: items,
        totalCount: total,
        page: page,
        pageSize: pageSize,
      );
    } catch (e) {
      return PaginatedActivityResult(items: [], totalCount: 0, page: page, pageSize: pageSize);
    }
  }

  /// Aggregates "WHO WORKED TODAY" staff breakdown
  static Future<List<StaffWorkMetric>> fetchWhoWorkedTodaySummary({DateTime? date}) async {
    final targetDate = date ?? DateTime.now();
    final startIso = DateTime(targetDate.year, targetDate.month, targetDate.day, 0, 0, 0).toUtc().toIso8601String();
    final endIso = DateTime(targetDate.year, targetDate.month, targetDate.day, 23, 59, 59).toUtc().toIso8601String();

    try {
      final response = await _client
          .from('activity_logs')
          .select('staff_name, staff_role, consumer_no, module, action, new_value')
          .gte('created_at', startIso)
          .lte('created_at', endIso)
          .limit(1000);

      final List<dynamic> logs = response as List<dynamic>;

      // Group by staff_name
      final Map<String, List<Map<String, dynamic>>> grouped = {};
      final Map<String, String> roles = {};

      for (final log in logs) {
        final name = log['staff_name']?.toString() ?? 'Unknown Staff';
        final role = log['staff_role']?.toString() ?? 'staff';
        grouped.putIfAbsent(name, () => []).add(log as Map<String, dynamic>);
        roles[name] = role;
      }

      final List<StaffWorkMetric> metrics = [];

      grouped.forEach((staffName, staffLogs) {
        final distinctCustomers = staffLogs.map((l) => l['consumer_no']?.toString() ?? '').toSet();
        distinctCustomers.remove('');

        int completed = 0;
        int pending = 0;
        int followups = 0;
        int issues = 0;
        int installations = 0;
        int payments = 0;

        for (final l in staffLogs) {
          final action = (l['action']?.toString() ?? '').toLowerCase();
          final module = (l['module']?.toString() ?? '').toLowerCase();
          final newVal = (l['new_value']?.toString() ?? '').toLowerCase();

          if (action.contains('complete') || newVal.contains('complete') || newVal.contains('done') || newVal.contains('approved')) {
            completed++;
          } else if (action.contains('pending') || newVal.contains('pending') || newVal.contains('hold')) {
            pending++;
          }

          if (module.contains('follow') || action.contains('follow')) {
            followups++;
          }
          if (module.contains('issue') || action.contains('issue')) {
            issues++;
          }
          if (module.contains('install') || action.contains('install')) {
            installations++;
          }
          if (module.contains('payment') || action.contains('payment')) {
            payments++;
          }
        }

        metrics.add(StaffWorkMetric(
          staffName: staffName,
          staffRole: roles[staffName] ?? 'staff',
          totalActions: staffLogs.length,
          customersWorked: distinctCustomers.length,
          completed: completed,
          pending: pending,
          followups: followups,
          issues: issues,
          installations: installations,
          payments: payments,
        ));
      });

      // Sort by total actions descending
      metrics.sort((a, b) => b.totalActions.compareTo(a.totalActions));
      return metrics;
    } catch (e) {
      return [];
    }
  }

  /// Generates CSV export for Who Worked Log
  static String exportActivityToCsv(List<ActivityLog> logs) {
    final buffer = StringBuffer();
    // Header
    buffer.writeln('Date,Time,Staff,Role,Customer,Consumer No,Village,Module,Action,Old Value,New Value,Remarks');

    for (final log in logs) {
      buffer.writeln([
        _escapeCsv(log.formattedDate),
        _escapeCsv(log.formattedTime),
        _escapeCsv(log.staffName),
        _escapeCsv(log.staffRole),
        _escapeCsv(log.customerName),
        _escapeCsv(log.consumerNo),
        _escapeCsv(log.village),
        _escapeCsv(log.module),
        _escapeCsv(log.action),
        _escapeCsv(log.oldValue ?? '-'),
        _escapeCsv(log.newValue ?? '-'),
        _escapeCsv(log.remarks ?? '-'),
      ].join(','));
    }

    return buffer.toString();
  }

  static String _escapeCsv(String field) {
    if (field.contains(',') || field.contains('"') || field.contains('\n')) {
      return '"${field.replaceAll('"', '""')}"';
    }
    return field;
  }
}
