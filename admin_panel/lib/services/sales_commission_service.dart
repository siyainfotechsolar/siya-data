import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/sales_commission.dart';
import '../models/consumer_record.dart';
import '../models/user_profile.dart';
import '../utils/consumer_no_utils.dart';
import 'supabase_service.dart';

class SalesCommissionService {
  static SupabaseClient get _client => SupabaseService.client;

  // In-memory cache for fast local access and offline fallback
  static final List<SalesCommission> _inMemoryCache = [];

  /// Fetch all customer commission records, automatically synced with Customer Master
  /// so that ALL customers (Sales Person + Direct) appear together by default.
  static Future<List<SalesCommission>> fetchCommissions() async {
    try {
      List<SalesCommission> existingList = [];
      try {
        final List<dynamic> dbRecords = await _client
            .from('sales_commissions')
            .select('*')
            .order('commission_date', ascending: false)
            .order('created_at', ascending: false);

        existingList = dbRecords
            .map((json) => SalesCommission.fromJson(json as Map<String, dynamic>))
            .toList();
      } catch (dbErr) {
        // ignore: avoid_print
        print('SalesCommissionService: DB sales_commissions table query fallback: $dbErr');
        // Preserve any previously saved in-memory commission records
        existingList = _inMemoryCache.where((c) => !c.id.startsWith('init-')).toList();
      }

      // Fetch active, non-merged customers to guarantee ALL real customers are represented
      final customers = await fetchAvailableCustomers();
      final existingConsumerNos = existingList
          .map((c) => ConsumerNoNormalizer.normalize(c.consumerNo))
          .where((s) => s.isNotEmpty)
          .toSet();

      final merged = <SalesCommission>[...existingList];

      for (final cust in customers) {
        final custNorm = ConsumerNoNormalizer.normalize(cust.consumerNo);
        if (custNorm.isNotEmpty && !existingConsumerNos.contains(custNorm)) {
          existingConsumerNos.add(custNorm);
          // Initialize customer in module
          final hasStaff = cust.assignedStaff != null && cust.assignedStaff!.trim().isNotEmpty;
          final capKw = cust.capacityKw > 0 ? cust.capacityKw : 3.0;
          final defaultRate = hasStaff ? 500.0 : 0.0;
          final source = hasStaff ? 'Sales Person' : 'Sales Person';
          final status = 'Pending';

          final newCommission = SalesCommission(
            id: 'init-${cust.id ?? cust.consumerNo}',
            consumerId: cust.id ?? '',
            consumerNo: cust.consumerNo,
            customerName: cust.name,
            siteLocation: cust.address ?? cust.village ?? '',
            solarCapacity: cust.systemCapacity?.isNotEmpty == true
                ? cust.systemCapacity!
                : '${capKw.toStringAsFixed(1)} kW',
            capacityKw: capKw,
            customerSource: source,
            salesPersonId: null,
            salesPersonName: hasStaff ? cust.assignedStaff : null,
            commissionRatePerKw: defaultRate,
            totalCommission: hasStaff ? (capKw * defaultRate) : 0.0,
            commissionStatus: status,
            commissionDate: cust.createdAt ?? DateTime.now(),
            remarks: 'Imported from Customer Master',
          );
          merged.add(newCommission);
        }
      }

      _inMemoryCache.clear();
      _inMemoryCache.addAll(merged);
      return merged;
    } catch (e) {
      // ignore: avoid_print
      print('SalesCommissionService.fetchCommissions error: $e. Falling back to in-memory cache.');
      return List.unmodifiable(_inMemoryCache);
    }
  }

  /// Save (create or update) a sales commission record
  static Future<SalesCommission> saveCommission(SalesCommission commission) async {
    // 1. Duplicate check: prevent duplicate records for the same consumer/site
    final existingWithSameConsumer = _inMemoryCache.where(
      (c) => (ConsumerNoNormalizer.isDuplicate(c.consumerNo, commission.consumerNo) || c.consumerNo.trim() == commission.consumerNo.trim()) &&
          c.id != commission.id &&
          !c.id.startsWith('init-'),
    );

    if (existingWithSameConsumer.isNotEmpty) {
      throw Exception(
        'Duplicate Commission Record: A commission entry already exists for ${commission.customerName} '
        '(Consumer No: ${commission.consumerNo}). Please edit the existing entry.',
      );
    }

    // Apply strict rules
    SalesCommission toSave = commission;
    if (commission.isDirectCustomer) {
      toSave = commission.copyWith(
        commissionRatePerKw: 0.0,
        totalCommission: 0.0,
        commissionStatus: 'Not Applicable',
        salesPersonName: null,
        salesPersonId: null,
      );
    } else {
      toSave = commission.copyWith(
        totalCommission: commission.capacityKw * commission.commissionRatePerKw,
      );
    }

    final payload = toSave.toJson();
    final currentUserId = SupabaseService.currentUser?.id;
    if (currentUserId != null) {
      payload['created_by'] = currentUserId;
    }

    // If ID is pseudo-init, remove it so PostgreSQL generates UUID
    if (payload['id'] != null && payload['id'].toString().startsWith('init-')) {
      payload.remove('id');
    }

    try {
      final isNew = toSave.id.isEmpty || toSave.id.startsWith('init-');
      if (isNew) {
        final res = await _client
            .from('sales_commissions')
            .insert(payload)
            .select()
            .single();

        final created = SalesCommission.fromJson(res);
        _inMemoryCache.removeWhere((c) => c.consumerNo.trim() == created.consumerNo.trim());
        _inMemoryCache.insert(0, created);
        return created;
      } else {
        final res = await _client
            .from('sales_commissions')
            .update(payload)
            .eq('id', toSave.id)
            .select()
            .single();

        final updated = SalesCommission.fromJson(res);
        final index = _inMemoryCache.indexWhere((c) => c.id == updated.id);
        if (index >= 0) {
          _inMemoryCache[index] = updated;
        } else {
          _inMemoryCache.insert(0, updated);
        }
        return updated;
      }
    } catch (e) {
      // ignore: avoid_print
      print('SalesCommissionService.saveCommission DB fallback: $e');

      final effectiveId = (toSave.id.isEmpty || toSave.id.startsWith('init-'))
          ? 'local-${DateTime.now().millisecondsSinceEpoch}'
          : toSave.id;
      final local = toSave.copyWith(id: effectiveId);

      final index = _inMemoryCache.indexWhere((c) => c.consumerNo.trim() == local.consumerNo.trim());
      if (index >= 0) {
        _inMemoryCache[index] = local;
      } else {
        _inMemoryCache.insert(0, local);
      }
      return local;
    }
  }

  /// Delete a commission record
  static Future<void> deleteCommission(String id) async {
    try {
      if (!id.startsWith('init-') && !id.startsWith('local-')) {
        await _client.from('sales_commissions').delete().eq('id', id);
      }
    } catch (e) {
      // ignore: avoid_print
      print('SalesCommissionService.deleteCommission DB error: $e');
    } finally {
      _inMemoryCache.removeWhere((c) => c.id == id);
    }
  }

  /// Batch save multiple commission records
  static Future<List<SalesCommission>> saveMultipleCommissions(List<SalesCommission> list) async {
    final results = <SalesCommission>[];
    for (final c in list) {
      final saved = await saveCommission(c);
      results.add(saved);
    }
    return results;
  }

  /// Fetch active, non-merged, unique customers from Customer Master
  static Future<List<ConsumerRecord>> fetchAvailableCustomers() async {
    try {
      final response = await _client
          .from('consumer_records')
          .select('*')
          .eq('deleted', false)
          .eq('is_merged', false)
          .order('name', ascending: true);

      final List<dynamic> data = response as List<dynamic>;
      final all = data.map((json) => ConsumerRecord.fromJson(json as Map<String, dynamic>)).toList();

      // Deduplicate by normalized consumer number to ensure only real unique customers are shown
      final seen = <String>{};
      final uniqueList = <ConsumerRecord>[];
      for (final c in all) {
        if (c.isMerged || c.deleted) continue;
        final norm = ConsumerNoNormalizer.normalize(c.consumerNo);
        if (norm.isNotEmpty && seen.add(norm)) {
          uniqueList.add(c);
        }
      }
      return uniqueList;
    } catch (e) {
      // ignore: avoid_print
      print('SalesCommissionService.fetchAvailableCustomers error: $e');
      return [];
    }
  }

  /// Fetch Staff/Employees for Sales Person selection
  static Future<List<UserProfile>> fetchAvailableStaff() async {
    try {
      final response = await _client
          .from('profiles')
          .select('*')
          .order('name', ascending: true);

      final List<dynamic> data = response as List<dynamic>;
      return data.map((json) => UserProfile.fromJson(json as Map<String, dynamic>)).toList();
    } catch (e) {
      // ignore: avoid_print
      print('SalesCommissionService.fetchAvailableStaff error: $e');
      return [];
    }
  }

  /// For unit testing: clear in-memory cache and seed test data
  static void resetLocalCacheForTesting([List<SalesCommission>? initial]) {
    _inMemoryCache.clear();
    if (initial != null) {
      _inMemoryCache.addAll(initial);
    }
  }
}
