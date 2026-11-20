import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/team_member.dart';
import '../models/team_work_expense.dart';
import '../models/consumer_record.dart';
import '../utils/consumer_no_utils.dart';
import 'supabase_service.dart';

class TeamWorkService {
  static SupabaseClient get _client => SupabaseService.client;

  // In-memory caches for fast local access, offline fallback, and unit test execution
  static final List<TeamMember> _memberCache = [];
  static final List<TeamWorkExpense> _expenseCache = [];

  // Default seed members
  static final List<TeamMember> defaultSeedMembers = [
    const TeamMember(id: 'seed-vishal', name: 'Vishal', notes: 'Initial team member'),
    const TeamMember(id: 'seed-yendeshwar', name: 'Yendeshwar', notes: 'Initial team member'),
    const TeamMember(id: 'seed-samadhan', name: 'Samadhan', notes: 'Initial team member'),
    const TeamMember(id: 'seed-eknath', name: 'Eknath', notes: 'Initial team member'),
  ];

  // ==========================================
  // 1. TEAM MEMBER MASTER
  // ==========================================

  /// Fetch all Team Members from Team Member Master
  static Future<List<TeamMember>> fetchTeamMembers({bool activeOnly = false}) async {
    try {
      final query = _client.from('team_members').select('*');
      final response = activeOnly
          ? await query.eq('is_active', true).order('name', ascending: true)
          : await query.order('name', ascending: true);

      final List<dynamic> data = response as List<dynamic>;
      final list = data.map((json) => TeamMember.fromJson(json as Map<String, dynamic>)).toList();

      if (list.isNotEmpty) {
        _memberCache.clear();
        _memberCache.addAll(list);
        return list;
      }

      // If database returned empty, seed default members
      if (_memberCache.isEmpty) {
        _memberCache.addAll(defaultSeedMembers);
      }
      return activeOnly ? _memberCache.where((m) => m.isActive).toList() : List.from(_memberCache);
    } catch (e) {
      // ignore: avoid_print
      print('TeamWorkService.fetchTeamMembers fallback: $e');
      if (_memberCache.isEmpty) {
        _memberCache.addAll(defaultSeedMembers);
      }
      return activeOnly ? _memberCache.where((m) => m.isActive).toList() : List.from(_memberCache);
    }
  }

  /// Add or update a Team Member
  static Future<TeamMember> saveTeamMember(TeamMember member) async {
    final isNew = member.id.isEmpty || member.id.startsWith('seed-');
    final String targetId = isNew ? DateTime.now().millisecondsSinceEpoch.toString() : member.id;
    final toSave = member.copyWith(id: targetId, updatedAt: DateTime.now());

    try {
      if (isNew) {
        final payload = toSave.toJson();
        payload.remove('id'); // let Supabase gen_random_uuid
        final res = await _client.from('team_members').insert(payload).select().single();
        final saved = TeamMember.fromJson(res);
        _memberCache.removeWhere((m) => m.name.toLowerCase() == saved.name.toLowerCase() || m.id == targetId);
        _memberCache.add(saved);
        return saved;
      } else {
        final res = await _client.from('team_members').update(toSave.toJson()).eq('id', toSave.id).select().single();
        final saved = TeamMember.fromJson(res);
        final idx = _memberCache.indexWhere((m) => m.id == saved.id);
        if (idx >= 0) {
          _memberCache[idx] = saved;
        } else {
          _memberCache.add(saved);
        }
        return saved;
      }
    } catch (e) {
      // ignore: avoid_print
      print('TeamWorkService.saveTeamMember fallback: $e');
      final idx = _memberCache.indexWhere((m) => m.id == toSave.id || m.name.toLowerCase() == toSave.name.toLowerCase());
      if (idx >= 0) {
        _memberCache[idx] = toSave;
      } else {
        _memberCache.add(toSave);
      }
      return toSave;
    }
  }

  /// Toggle Team Member Active Status
  static Future<void> toggleTeamMemberActive(String memberId, bool isActive) async {
    try {
      await _client.from('team_members').update({'is_active': isActive, 'updated_at': DateTime.now().toIso8601String()}).eq('id', memberId);
    } catch (e) {
      // ignore: avoid_print
      print('TeamWorkService.toggleTeamMemberActive fallback: $e');
    } finally {
      final idx = _memberCache.indexWhere((m) => m.id == memberId);
      if (idx >= 0) {
        _memberCache[idx] = _memberCache[idx].copyWith(isActive: isActive);
      }
    }
  }

  // ==========================================
  // 2. TEAM WORK EXPENSES (SITE-WISE & PERSON-WISE)
  // ==========================================

  /// Fetch all individual work expense entries
  static Future<List<TeamWorkExpense>> fetchWorkExpenses() async {
    try {
      final response = await _client
          .from('team_work_expenses')
          .select('*')
          .order('work_date', ascending: false)
          .order('created_at', ascending: false);

      final List<dynamic> data = response as List<dynamic>;
      final list = data.map((json) => TeamWorkExpense.fromJson(json as Map<String, dynamic>)).toList();
      _expenseCache.clear();
      _expenseCache.addAll(list);
      return list;
    } catch (e) {
      // ignore: avoid_print
      print('TeamWorkService.fetchWorkExpenses fallback: $e');
      return List.from(_expenseCache);
    }
  }

  /// Save (Add or Edit) an individual work expense entry
  static Future<TeamWorkExpense> saveWorkExpense(TeamWorkExpense expense) async {
    final isNew = expense.id.isEmpty || expense.id.startsWith('temp-');
    final String targetId = isNew ? 'exp-${DateTime.now().millisecondsSinceEpoch}' : expense.id;
    final toSave = expense.copyWith(id: targetId, updatedAt: DateTime.now());

    try {
      if (isNew) {
        final payload = toSave.toJson();
        payload.remove('id'); // let Supabase gen_random_uuid
        final res = await _client.from('team_work_expenses').insert(payload).select().single();
        final saved = TeamWorkExpense.fromJson(res);
        _expenseCache.removeWhere((e) => e.id == targetId);
        _expenseCache.insert(0, saved);
        return saved;
      } else {
        final res = await _client.from('team_work_expenses').update(toSave.toJson()).eq('id', toSave.id).select().single();
        final saved = TeamWorkExpense.fromJson(res);
        final idx = _expenseCache.indexWhere((e) => e.id == saved.id);
        if (idx >= 0) {
          _expenseCache[idx] = saved;
        } else {
          _expenseCache.insert(0, saved);
        }
        return saved;
      }
    } catch (e) {
      // ignore: avoid_print
      print('TeamWorkService.saveWorkExpense fallback: $e');
      final idx = _expenseCache.indexWhere((e) => e.id == toSave.id);
      if (idx >= 0) {
        _expenseCache[idx] = toSave;
      } else {
        _expenseCache.insert(0, toSave);
      }
      return toSave;
    }
  }

  /// Delete an individual work expense entry by ID
  static Future<void> deleteWorkExpense(String id) async {
    try {
      await _client.from('team_work_expenses').delete().eq('id', id);
    } catch (e) {
      // ignore: avoid_print
      print('TeamWorkService.deleteWorkExpense fallback: $e');
    } finally {
      _expenseCache.removeWhere((e) => e.id == id);
    }
  }

  /// Batch Save multiple work expenses for a site (add/edit) and optionally delete removed entries
  static Future<List<TeamWorkExpense>> saveMultipleWorkExpenses({
    required List<TeamWorkExpense> toSave,
    List<String> toDelete = const [],
  }) async {
    for (final id in toDelete) {
      if (id.isNotEmpty && !id.startsWith('temp-')) {
        await deleteWorkExpense(id);
      }
    }
    final results = <TeamWorkExpense>[];
    for (final exp in toSave) {
      final saved = await saveWorkExpense(exp);
      results.add(saved);
    }
    return results;
  }

  // ==========================================
  // 3. CUSTOMER MASTER (REAL UNIQUE CUSTOMERS ONLY)
  // ==========================================

  /// Fetch active, non-merged, unique customers from Customer Master
  /// (Deduplicated with ConsumerNoNormalizer to show exactly the real customers)
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
      print('TeamWorkService.fetchAvailableCustomers fallback: $e');
      return [];
    }
  }

  // ==========================================
  // 4. AGGREGATIONS & SUMMARIES
  // ==========================================

  /// Build Person-wise Expense Summaries
  static List<PersonExpenseSummary> buildPersonSummaries(List<TeamWorkExpense> expenses) {
    final map = <String, List<TeamWorkExpense>>{};

    for (final e in expenses) {
      final name = e.teamMemberName.trim();
      if (name.isEmpty) continue;
      map.putIfAbsent(name, () => []).add(e);
    }

    final summaries = map.entries.map((entry) {
      return PersonExpenseSummary.fromExpenses(entry.key, entry.value);
    }).toList();

    // Sort descending by total expense
    summaries.sort((a, b) => b.totalExpense.compareTo(a.totalExpense));
    return summaries;
  }

  /// Build Customer-wise Expense Summaries
  static List<CustomerExpenseSummary> buildCustomerSummaries(List<TeamWorkExpense> expenses) {
    final map = <String, List<TeamWorkExpense>>{};

    for (final e in expenses) {
      final key = ConsumerNoNormalizer.normalize(e.consumerNo);
      if (key.isEmpty) continue;
      map.putIfAbsent(key, () => []).add(e);
    }

    final summaries = map.entries.map((entry) {
      final first = entry.value.first;
      return CustomerExpenseSummary.fromEntries(
        first.consumerNo,
        first.customerName,
        first.siteLocation,
        first.solarCapacity,
        entry.value,
      );
    }).toList();

    // Sort descending by total site expense
    summaries.sort((a, b) => b.totalSiteExpense.compareTo(a.totalSiteExpense));
    return summaries;
  }

  /// Build Category-wise Expense Summaries (Structure, Wiring, Civil)
  static List<CategoryExpenseSummary> buildCategorySummaries(List<TeamWorkExpense> expenses) {
    final categories = ['Structure', 'Wiring', 'Civil'];
    final list = <CategoryExpenseSummary>[];

    for (final cat in categories) {
      final matching = expenses.where((e) => e.workCategory.trim().toLowerCase() == cat.toLowerCase());
      final workers = matching.map((e) => e.teamMemberName.trim().toLowerCase()).where((w) => w.isNotEmpty).toSet();
      final sites = matching.map((e) => ConsumerNoNormalizer.normalize(e.consumerNo)).where((s) => s.isNotEmpty).toSet();
      final total = matching.fold<double>(0.0, (sum, e) => sum + e.individualExpense);

      list.add(CategoryExpenseSummary(
        workCategory: cat,
        totalWorkers: workers.length,
        totalSites: sites.length,
        totalExpense: total,
      ));
    }

    return list;
  }

  /// Clear caches for unit testing
  static void resetCacheForTesting() {
    _memberCache.clear();
    _expenseCache.clear();
  }
}
