import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/site_team_expense.dart';
import '../models/consumer_record.dart';
import 'supabase_service.dart';

class SiteTeamExpenseService {
  static SupabaseClient get _client => SupabaseService.client;

  // In-memory cache for fast local access and offline fallback
  static final List<SiteTeamExpense> _inMemoryCache = [];

  /// Fetch all site-wise team expenses
  static Future<List<SiteTeamExpense>> fetchExpenses() async {
    try {
      final response = await _client
          .from('site_team_expenses')
          .select('*')
          .order('expense_date', ascending: false)
          .order('created_at', ascending: false);

      final List<dynamic> data = response as List<dynamic>;
      final list = data.map((json) => SiteTeamExpense.fromJson(json as Map<String, dynamic>)).toList();

      _inMemoryCache.clear();
      _inMemoryCache.addAll(list);
      return list;
    } catch (e) {
      // ignore: avoid_print
      print('SiteTeamExpenseService.fetchExpenses error: $e. Falling back to local cache.');
      return List.unmodifiable(_inMemoryCache);
    }
  }

  /// Save (create or update) a site-wise team expense entry
  static Future<SiteTeamExpense> saveExpense(SiteTeamExpense expense) async {
    // 1. Prevent duplicate records for the same site / consumer number
    final existingWithSameConsumer = _inMemoryCache.where(
      (e) => e.consumerNo.trim() == expense.consumerNo.trim() && e.id != expense.id,
    );

    if (existingWithSameConsumer.isNotEmpty) {
      throw Exception(
        'Duplicate Site Record: An expense entry already exists for ${expense.customerName} '
        '(Consumer No: ${expense.consumerNo}). Please edit the existing entry.',
      );
    }

    final payload = expense.toJson();
    final currentUserId = SupabaseService.currentUser?.id;
    if (currentUserId != null) {
      payload['created_by'] = currentUserId;
    }

    try {
      if (expense.id.isEmpty) {
        // Create new
        final res = await _client
            .from('site_team_expenses')
            .insert(payload)
            .select()
            .single();

        final created = SiteTeamExpense.fromJson(res);
        _inMemoryCache.removeWhere((e) => e.id == created.id);
        _inMemoryCache.insert(0, created);
        return created;
      } else {
        // Update existing
        final res = await _client
            .from('site_team_expenses')
            .update(payload)
            .eq('id', expense.id)
            .select()
            .single();

        final updated = SiteTeamExpense.fromJson(res);
        final index = _inMemoryCache.indexWhere((e) => e.id == updated.id);
        if (index >= 0) {
          _inMemoryCache[index] = updated;
        } else {
          _inMemoryCache.insert(0, updated);
        }
        return updated;
      }
    } catch (e) {
      // In-memory fallback if table or network unavailable
      // ignore: avoid_print
      print('SiteTeamExpenseService.saveExpense fallback due to error: $e');

      final effectiveId = expense.id.isEmpty ? 'local-${DateTime.now().millisecondsSinceEpoch}' : expense.id;
      final localExpense = expense.copyWith(id: effectiveId);

      final index = _inMemoryCache.indexWhere((e) => e.id == effectiveId);
      if (index >= 0) {
        _inMemoryCache[index] = localExpense;
      } else {
        _inMemoryCache.insert(0, localExpense);
      }
      return localExpense;
    }
  }

  /// Delete a site-wise team expense entry
  static Future<void> deleteExpense(String id) async {
    try {
      await _client.from('site_team_expenses').delete().eq('id', id);
    } catch (e) {
      // ignore: avoid_print
      print('SiteTeamExpenseService.deleteExpense network error: $e');
    } finally {
      _inMemoryCache.removeWhere((e) => e.id == id);
    }
  }

  /// Fetch active customers from Customer Master for the selection dropdown
  static Future<List<ConsumerRecord>> fetchAvailableCustomers() async {
    try {
      final response = await _client
          .from('consumer_records')
          .select('*')
          .eq('deleted', false)
          .order('name', ascending: true);

      final List<dynamic> data = response as List<dynamic>;
      return data.map((json) => ConsumerRecord.fromJson(json as Map<String, dynamic>)).toList();
    } catch (e) {
      // ignore: avoid_print
      print('SiteTeamExpenseService.fetchAvailableCustomers error: $e');
      return [];
    }
  }

  /// For unit testing: clear in-memory cache
  static void resetLocalCacheForTesting() {
    _inMemoryCache.clear();
  }
}
