import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:siya_shared/siya_shared.dart';
import 'sub_vendor_service.dart';
import 'supabase_service.dart';

/// Database & Real-time State Service for Sub-Vendor Account Dashboard & Credit / Debit Ledger.
class SubVendorAccountLedgerService {
  static const String _ledgerTable = 'sub_vendor_account_ledger';
  static const String _localLedgerKey = 'cached_sub_vendor_account_ledger';

  static List<SubVendorAccountLedgerEntry> _inMemoryLedger = [];
  static bool _hasInitializedLocal = false;

  // ---------------------------------------------------------------------------
  // 1. RECORD MANUAL TRANSACTION (PAYMENT, ADVANCE, REFUND)
  // ---------------------------------------------------------------------------
  static Future<SubVendorAccountLedgerEntry> recordTransaction({
    required String vendorId,
    required String vendorName,
    required DateTime transactionDate,
    required String transactionType, // 'MATERIAL_OUTWARD', 'MATERIAL_PAYMENT', 'ADVANCE_GIVEN', 'ADVANCE_REFUND'
    required double amount,
    required String referenceNumber,
    String? referenceId,
    String paymentMode = 'Bank Transfer',
    required String particulars,
    String? remarks,
  }) async {
    await _ensureLocalInitialized();

    if (amount <= 0) {
      throw ArgumentError('Transaction amount must be greater than zero.');
    }

    final String type = transactionType.toUpperCase();
    final String category = (type == 'MATERIAL_OUTWARD' || type == 'MATERIAL_PAYMENT') ? 'MATERIAL' : 'ADVANCE';
    final double credit = (type == 'MATERIAL_OUTWARD' || type == 'ADVANCE_REFUND') ? amount : 0.0;
    final double debit = (type == 'MATERIAL_PAYMENT' || type == 'ADVANCE_GIVEN') ? amount : 0.0;

    // Try Supabase RPC first
    try {
      final client = SupabaseService.client;
      final currentUser = SupabaseService.currentUser;

      final rpcRes = await client.rpc('record_sub_vendor_ledger_entry', params: {
        'p_vendor_id': vendorId,
        'p_transaction_date': transactionDate.toIso8601String().split('T').first,
        'p_transaction_type': type,
        'p_amount': amount,
        'p_reference_number': referenceNumber,
        'p_payment_mode': paymentMode,
        'p_particulars': particulars,
        'p_remarks': remarks,
        'p_reference_id': referenceId,
        'p_created_by': currentUser?.id,
      });

      if (rpcRes != null && rpcRes['success'] == true) {
        final entryId = rpcRes['id'].toString();
        final entry = SubVendorAccountLedgerEntry(
          id: entryId,
          vendorId: vendorId,
          vendorName: vendorName,
          transactionDate: transactionDate,
          transactionType: type,
          category: category,
          creditAmount: credit,
          debitAmount: debit,
          runningBalance: 0.0,
          referenceNumber: referenceNumber,
          referenceId: referenceId,
          paymentMode: paymentMode,
          particulars: particulars,
          remarks: remarks,
          status: 'Active',
          createdAt: DateTime.now(),
        );

        _inMemoryLedger.add(entry);
        _recalculateLocalRunningBalances(vendorId);
        await _saveLedgerToCache(_inMemoryLedger);
        return entry;
      }
    } catch (e) {
      debugPrint('Notice: Supabase ledger RPC failed ($e). Recording in atomic local ledger engine.');
    }

    // Local in-memory fallback
    final entryId = 'ledger-${DateTime.now().millisecondsSinceEpoch}-${_inMemoryLedger.length + 1}';
    final entry = SubVendorAccountLedgerEntry(
      id: entryId,
      vendorId: vendorId,
      vendorName: vendorName,
      transactionDate: transactionDate,
      transactionType: type,
      category: category,
      creditAmount: credit,
      debitAmount: debit,
      runningBalance: 0.0,
      referenceNumber: referenceNumber,
      referenceId: referenceId,
      paymentMode: paymentMode,
      particulars: particulars,
      remarks: remarks,
      status: 'Active',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    _inMemoryLedger.add(entry);
    _recalculateLocalRunningBalances(vendorId);
    await _saveLedgerToCache(_inMemoryLedger);
    return entry;
  }

  // ---------------------------------------------------------------------------
  // 2. AUTOMATIC SYNC FROM MATERIAL OUTWARD ENTRY
  // ---------------------------------------------------------------------------
  static Future<void> syncFromMaterialOutward({
    required String outwardId,
    required String outwardNumber,
    required String vendorId,
    required String vendorName,
    required DateTime outwardDate,
    required double totalOutwardValue,
    required int totalItems,
    required double totalQuantity,
    String? remarks,
    bool isUpdate = false,
  }) async {
    await _ensureLocalInitialized();

    if (totalOutwardValue <= 0) return;

    final particulars = 'Material Outward Dispatch ($totalItems items, Qty: ${totalQuantity.toStringAsFixed(1)})';

    // If update, check existing ledger entry for this outward
    final existingIdx = _inMemoryLedger.indexWhere((e) => e.referenceId == outwardId || e.referenceNumber == outwardNumber);
    if (existingIdx >= 0 && isUpdate) {
      final existing = _inMemoryLedger[existingIdx];
      _inMemoryLedger[existingIdx] = existing.copyWith(
        vendorId: vendorId,
        vendorName: vendorName,
        transactionDate: outwardDate,
        creditAmount: totalOutwardValue,
        debitAmount: 0.0,
        particulars: particulars,
        remarks: remarks,
        updatedAt: DateTime.now(),
      );
      _recalculateLocalRunningBalances(vendorId);
      await _saveLedgerToCache(_inMemoryLedger);
      return;
    }

    // Otherwise record new entry
    await recordTransaction(
      vendorId: vendorId,
      vendorName: vendorName,
      transactionDate: outwardDate,
      transactionType: 'MATERIAL_OUTWARD',
      amount: totalOutwardValue,
      referenceNumber: outwardNumber,
      referenceId: outwardId,
      paymentMode: 'Inventory',
      particulars: particulars,
      remarks: remarks,
    );
  }

  // ---------------------------------------------------------------------------
  // 3. CANCEL TRANSACTION OR CANCEL BY OUTWARD REFERENCE ID
  // ---------------------------------------------------------------------------
  static Future<void> cancelLedgerEntryByReferenceId(String referenceId, {String reason = 'Outward Cancelled'}) async {
    await _ensureLocalInitialized();

    final idx = _inMemoryLedger.indexWhere((e) => e.referenceId == referenceId);
    if (idx >= 0) {
      final existing = _inMemoryLedger[idx];
      _inMemoryLedger[idx] = existing.copyWith(
        status: 'Cancelled',
        cancelledAt: DateTime.now(),
        cancellationReason: reason,
        updatedAt: DateTime.now(),
      );
      _recalculateLocalRunningBalances(existing.vendorId);
      await _saveLedgerToCache(_inMemoryLedger);
    }
  }

  static Future<SubVendorAccountLedgerEntry> cancelTransaction(String entryId, {String reason = 'Cancelled by Admin'}) async {
    await _ensureLocalInitialized();

    final idx = _inMemoryLedger.indexWhere((e) => e.id == entryId);
    if (idx < 0) {
      throw StateError('Ledger entry "$entryId" not found.');
    }

    final existing = _inMemoryLedger[idx];
    if (existing.isCancelled) {
      throw StateError('Ledger entry is already cancelled.');
    }

    final cancelled = existing.copyWith(
      status: 'Cancelled',
      cancelledAt: DateTime.now(),
      cancellationReason: reason,
      updatedAt: DateTime.now(),
    );

    _inMemoryLedger[idx] = cancelled;
    _recalculateLocalRunningBalances(existing.vendorId);
    await _saveLedgerToCache(_inMemoryLedger);
    return cancelled;
  }

  // ---------------------------------------------------------------------------
  // 4. FETCH LEDGER ENTRIES & ALIASES
  // ---------------------------------------------------------------------------
  static Future<List<SubVendorAccountLedgerEntry>> fetchLedgerEntries({
    String? vendorId,
    DateTime? fromDate,
    DateTime? toDate,
    String? typeFilter,
    String? categoryFilter,
    String? statusFilter = 'Active',
    String? searchQuery,
  }) async {
    await _ensureLocalInitialized();

    try {
      final client = SupabaseService.client;
      var query = client.from(_ledgerTable).select();

      if (vendorId != null && vendorId.isNotEmpty && vendorId != 'All') {
        query = query.eq('vendor_id', vendorId);
      }
      if (statusFilter != null && statusFilter.isNotEmpty && statusFilter != 'All') {
        query = query.eq('status', statusFilter);
      }

      final res = await query.order('transaction_date', ascending: true).order('created_at', ascending: true);
      final List<dynamic> rows = res as List<dynamic>;
      final list = rows.map((e) => SubVendorAccountLedgerEntry.fromJson(e as Map<String, dynamic>)).toList();
      _inMemoryLedger = list;
      // Dynamically recalculate running balances chronologically by date
      final vIds = _inMemoryLedger.map((e) => e.vendorId).toSet();
      for (final vId in vIds) {
        _recalculateLocalRunningBalances(vId);
      }
      _saveLedgerToCache(_inMemoryLedger);
    } catch (e) {
      debugPrint('Notice: Fetching ledger from Supabase: $e');
    }

    return _filterLedgerList(
      _inMemoryLedger,
      vendorId: vendorId,
      fromDate: fromDate,
      toDate: toDate,
      typeFilter: typeFilter,
      categoryFilter: categoryFilter,
      statusFilter: statusFilter,
      searchQuery: searchQuery,
    );
  }

  /// Alias for fetchLedgerEntries
  static Future<List<SubVendorAccountLedgerEntry>> fetchLedger({
    String? vendorId,
    DateTime? fromDate,
    DateTime? toDate,
    String? typeFilter,
    String? categoryFilter,
    String? statusFilter = 'Active',
    String? searchQuery,
  }) => fetchLedgerEntries(
    vendorId: vendorId,
    fromDate: fromDate,
    toDate: toDate,
    typeFilter: typeFilter,
    categoryFilter: categoryFilter,
    statusFilter: statusFilter,
    searchQuery: searchQuery,
  );

  /// Helper to sync a SubVendorMaterialOutward domain object into ledger
  static Future<void> syncOutwardToLedger(SubVendorMaterialOutward outward) async {
    await syncFromMaterialOutward(
      outwardId: outward.id,
      outwardNumber: outward.outwardNumber,
      vendorId: outward.vendorId,
      vendorName: outward.vendorName,
      outwardDate: outward.outwardDate,
      totalOutwardValue: outward.totalValue,
      totalItems: outward.totalItems,
      totalQuantity: outward.totalQuantity,
      remarks: outward.remarks,
    );
  }

  // ---------------------------------------------------------------------------
  // 5. DASHBOARD METRICS CALCULATION
  // ---------------------------------------------------------------------------
  static Future<SubVendorDashboardMetrics> calculateDashboardMetrics({
    List<SubVendor>? preloadedVendors,
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    await _ensureLocalInitialized();

    final activeEntries = _filterLedgerList(
      _inMemoryLedger,
      fromDate: fromDate,
      toDate: toDate,
      statusFilter: 'Active',
    );

    List<SubVendor> vendors = preloadedVendors ?? [];
    if (vendors.isEmpty) {
      try {
        vendors = await SubVendorService.fetchAllVendors();
      } catch (e) {
        debugPrint('Notice: Fetch vendors in ledger calculation: $e');
        final Map<String, String> seen = {};
        for (final e in activeEntries) {
          seen[e.vendorId] = e.vendorName;
        }
        vendors = seen.entries
            .map((entry) => SubVendor(
                  id: entry.key,
                  vendorCode: 'VND-${entry.key}',
                  name: entry.value,
                  mobile: '',
                  email: '',
                  isActive: true,
                  status: 'Active',
                ))
            .toList();
      }
    }

    double totalCredit = 0.0;
    double totalDebit = 0.0;
    double totalMaterialOutwardValue = 0.0;
    double totalMaterialPaymentsReceived = 0.0;
    double totalAdvanceGiven = 0.0;
    double totalAdvanceRefundReceived = 0.0;

    for (final e in activeEntries) {
      totalCredit += e.creditAmount;
      totalDebit += e.debitAmount;

      switch (e.transactionType.toUpperCase()) {
        case 'MATERIAL_OUTWARD':
          totalMaterialOutwardValue += e.creditAmount;
          break;
        case 'MATERIAL_PAYMENT':
          totalMaterialPaymentsReceived += e.debitAmount;
          break;
        case 'ADVANCE_GIVEN':
          totalAdvanceGiven += e.debitAmount;
          break;
        case 'ADVANCE_REFUND':
          totalAdvanceRefundReceived += e.creditAmount;
          break;
      }
    }

    // Sub Vendor-wise Balances
    final List<SubVendorAccountBalanceSummary> vendorBalances = [];
    final Map<String, List<SubVendorAccountLedgerEntry>> vendorMap = {};

    for (final e in activeEntries) {
      vendorMap.putIfAbsent(e.vendorId, () => []).add(e);
    }

    for (final v in vendors) {
      final vEntries = vendorMap[v.id] ?? [];
      double vCredit = 0.0;
      double vDebit = 0.0;
      double vMatOutward = 0.0;
      double vMatPayment = 0.0;
      double vAdvGiven = 0.0;
      double vAdvRefund = 0.0;
      DateTime? lastDate;

      for (final e in vEntries) {
        vCredit += e.creditAmount;
        vDebit += e.debitAmount;
        if (lastDate == null || e.transactionDate.isAfter(lastDate)) {
          lastDate = e.transactionDate;
        }

        if (e.transactionType == 'MATERIAL_OUTWARD') vMatOutward += e.creditAmount;
        if (e.transactionType == 'MATERIAL_PAYMENT') vMatPayment += e.debitAmount;
        if (e.transactionType == 'ADVANCE_GIVEN') vAdvGiven += e.debitAmount;
        if (e.transactionType == 'ADVANCE_REFUND') vAdvRefund += e.creditAmount;
      }

      vendorBalances.add(SubVendorAccountBalanceSummary(
        vendorId: v.id,
        vendorName: v.name,
        vendorCode: v.vendorCode,
        totalCredit: vCredit,
        totalDebit: vDebit,
        netBalance: vCredit - vDebit,
        materialReceivable: vMatOutward - vMatPayment,
        advanceBalance: vAdvGiven - vAdvRefund,
        totalTransactions: vEntries.length,
        lastTransactionDate: lastDate,
      ));
    }

    // Sort by largest outstanding balance first
    vendorBalances.sort((a, b) => b.netBalance.compareTo(a.netBalance));

    return SubVendorDashboardMetrics(
      totalCredit: totalCredit,
      totalDebit: totalDebit,
      netBalance: totalCredit - totalDebit,
      totalMaterialOutwardValue: totalMaterialOutwardValue,
      totalMaterialPaymentsReceived: totalMaterialPaymentsReceived,
      netMaterialReceivable: totalMaterialOutwardValue - totalMaterialPaymentsReceived,
      totalAdvanceGiven: totalAdvanceGiven,
      totalAdvanceRefundReceived: totalAdvanceRefundReceived,
      netAdvanceBalance: totalAdvanceGiven - totalAdvanceRefundReceived,
      vendorBalances: vendorBalances,
    );
  }

  /// Alias for calculateDashboardMetrics
  static Future<SubVendorDashboardMetrics> fetchDashboardMetrics({
    List<SubVendor>? preloadedVendors,
    DateTime? fromDate,
    DateTime? toDate,
  }) => calculateDashboardMetrics(
    preloadedVendors: preloadedVendors,
    fromDate: fromDate,
    toDate: toDate,
  );

  /// Fetch balances per vendor
  static Future<List<SubVendorAccountBalanceSummary>> fetchSubVendorBalances({
    List<SubVendor>? preloadedVendors,
  }) async {
    final metrics = await calculateDashboardMetrics(preloadedVendors: preloadedVendors);
    return metrics.vendorBalances;
  }

  /// Public filter helper
  static List<SubVendorAccountLedgerEntry> filterLedgerEntries(
    List<SubVendorAccountLedgerEntry> list, {
    String? vendorId,
    DateTime? fromDate,
    DateTime? toDate,
    String? typeFilter,
    String? categoryFilter,
    String? statusFilter,
    String? searchQuery,
  }) => _filterLedgerList(
    list,
    vendorId: vendorId,
    fromDate: fromDate,
    toDate: toDate,
    typeFilter: typeFilter,
    categoryFilter: categoryFilter,
    statusFilter: statusFilter,
    searchQuery: searchQuery,
  );

  // ---------------------------------------------------------------------------
  // HELPER METHODS: RUNNING BALANCES & LOCAL STORAGE
  // ---------------------------------------------------------------------------
  static void _recalculateLocalRunningBalances(String vendorId) {
    final vEntries = _inMemoryLedger.where((e) => e.vendorId == vendorId).toList()
      ..sort((a, b) {
        final dComp = a.transactionDate.compareTo(b.transactionDate);
        if (dComp != 0) return dComp;
        return (a.createdAt ?? DateTime.now()).compareTo(b.createdAt ?? DateTime.now());
      });

    double balance = 0.0;
    for (final e in vEntries) {
      if (e.isActive) {
        balance += (e.creditAmount - e.debitAmount);
      }
      final globalIdx = _inMemoryLedger.indexWhere((item) => item.id == e.id);
      if (globalIdx >= 0) {
        _inMemoryLedger[globalIdx] = _inMemoryLedger[globalIdx].copyWith(runningBalance: balance);
      }
    }
  }

  static List<SubVendorAccountLedgerEntry> _filterLedgerList(
    List<SubVendorAccountLedgerEntry> list, {
    String? vendorId,
    DateTime? fromDate,
    DateTime? toDate,
    String? typeFilter,
    String? categoryFilter,
    String? statusFilter,
    String? searchQuery,
  }) {
    return list.where((e) {
      if (statusFilter != null && statusFilter != 'All' && e.status.toLowerCase() != statusFilter.toLowerCase()) {
        return false;
      }
      if (vendorId != null && vendorId != 'All' && e.vendorId != vendorId) {
        return false;
      }
      if (categoryFilter != null && categoryFilter != 'All' && e.category.toLowerCase() != categoryFilter.toLowerCase()) {
        return false;
      }
      if (typeFilter != null && typeFilter != 'All' && e.transactionType.toLowerCase() != typeFilter.toLowerCase()) {
        return false;
      }
      if (fromDate != null) {
        final d = DateTime(e.transactionDate.year, e.transactionDate.month, e.transactionDate.day);
        final f = DateTime(fromDate.year, fromDate.month, fromDate.day);
        if (d.isBefore(f)) return false;
      }
      if (toDate != null) {
        final d = DateTime(e.transactionDate.year, e.transactionDate.month, e.transactionDate.day);
        final t = DateTime(toDate.year, toDate.month, toDate.day);
        if (d.isAfter(t)) return false;
      }
      if (searchQuery != null && searchQuery.trim().isNotEmpty) {
        final q = searchQuery.trim().toLowerCase();
        final match = e.referenceNumber.toLowerCase().contains(q) ||
            e.particulars.toLowerCase().contains(q) ||
            (e.remarks != null && e.remarks!.toLowerCase().contains(q));
        if (!match) return false;
      }
      return true;
    }).toList()
      ..sort((a, b) {
        final dComp = b.transactionDate.compareTo(a.transactionDate);
        if (dComp != 0) return dComp;
        return (b.createdAt ?? DateTime.now()).compareTo(a.createdAt ?? DateTime.now());
      });
  }

  static Future<void> _ensureLocalInitialized() async {
    if (_hasInitializedLocal) return;
    _hasInitializedLocal = true;

    try {
      final prefs = await SharedPreferences.getInstance();
      final str = prefs.getString(_localLedgerKey);
      if (str != null && str.isNotEmpty) {
        final decoded = jsonDecode(str) as List<dynamic>;
        _inMemoryLedger = decoded
            .map((e) => SubVendorAccountLedgerEntry.fromJson(e as Map<String, dynamic>))
            .where((e) => !e.id.startsWith('ledg-sample-'))
            .toList();
      } else {
        _inMemoryLedger = [];
      }
    } catch (_) {
      _inMemoryLedger = [];
    }
  }

  static Future<void> _saveLedgerToCache(List<SubVendorAccountLedgerEntry> list) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_localLedgerKey, jsonEncode(list.map((e) => e.toJson()).toList()));
    } catch (_) {}
  }

  @visibleForTesting
  static void resetInMemoryDataForTesting() {
    _inMemoryLedger.clear();
    _hasInitializedLocal = true;
  }
}
