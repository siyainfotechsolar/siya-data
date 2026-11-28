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

    final normalizedAmt = SubVendorFinancialEngine.round2(amount);
    if (normalizedAmt <= 0) {
      throw ArgumentError('Transaction amount must be greater than zero.');
    }

    final String type = transactionType.toUpperCase();
    final String category = (type == 'MATERIAL_OUTWARD' || type == 'MATERIAL_PAYMENT') ? 'MATERIAL' : 'ADVANCE';
    final double credit = (type == 'MATERIAL_PAYMENT' || type == 'ADVANCE_REFUND') ? normalizedAmt : 0.0;
    final double debit = (type == 'MATERIAL_OUTWARD' || type == 'ADVANCE_GIVEN') ? normalizedAmt : 0.0;
    final String cleanRef = referenceNumber.trim().isEmpty ? '-' : referenceNumber.trim();
    final DateTime normDate = SubVendorFinancialEngine.normalizeDate(transactionDate);

    // Duplicate payment / reference prevention on active non-placeholder references
    if (cleanRef != '-' && cleanRef.toUpperCase() != 'N/A') {
      final localDup = _inMemoryLedger.any((e) =>
          e.isActive &&
          e.vendorId == vendorId &&
          e.transactionType.toUpperCase() == type &&
          e.referenceNumber.trim().toUpperCase() == cleanRef.toUpperCase() &&
          (referenceId == null || e.referenceId != referenceId));
      if (localDup) {
        throw Exception('Duplicate reference / UTR "$cleanRef" already exists in active ledger for this Sub-Vendor.');
      }

      try {
        final client = SupabaseService.client;
        final existingRemote = await client
            .from(_ledgerTable)
            .select('id, reference_id')
            .eq('vendor_id', vendorId)
            .eq('transaction_type', type)
            .eq('status', 'Active')
            .ilike('reference_number', cleanRef);
        final list = existingRemote as List<dynamic>;
        if (list.isNotEmpty) {
          throw Exception('Duplicate reference / UTR "$cleanRef" already exists in active ledger for this Sub-Vendor.');
        }
      } catch (dupCheckErr) {
        if (dupCheckErr.toString().contains('Duplicate reference')) {
          rethrow;
        }
      }
    }

    // Try Supabase RPC first
    try {
      final client = SupabaseService.client;
      final currentUser = SupabaseService.currentUser;

      final rpcRes = await client.rpc('record_sub_vendor_ledger_entry', params: {
        'p_vendor_id': vendorId,
        'p_transaction_date': normDate.toIso8601String().split('T').first,
        'p_transaction_type': type,
        'p_amount': normalizedAmt,
        'p_reference_number': cleanRef,
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
          transactionDate: normDate,
          transactionType: type,
          category: category,
          creditAmount: credit,
          debitAmount: debit,
          runningBalance: 0.0,
          referenceNumber: cleanRef,
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
      transactionDate: normDate,
      transactionType: type,
      category: category,
      creditAmount: credit,
      debitAmount: debit,
      runningBalance: 0.0,
      referenceNumber: cleanRef,
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

    final normalizedAmt = SubVendorFinancialEngine.round2(totalOutwardValue);
    final normDate = SubVendorFinancialEngine.normalizeDate(outwardDate);
    final particulars = 'Material Outward Dispatch ($totalItems items, Qty: ${totalQuantity.toStringAsFixed(1)})';

    if (isUpdate) {
      // Update any existing mirrored rows in Supabase sub_vendor_account_ledger
      try {
        final client = SupabaseService.client;
        final uuidRegex = RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$');
        final updatePayload = {
          'vendor_id': vendorId,
          'vendor_name': vendorName,
          'transaction_date': normDate.toIso8601String().split('T').first,
          'category': 'MATERIAL',
          'credit_amount': 0.0,
          'debit_amount': normalizedAmt,
          'particulars': particulars,
          if (remarks != null) 'remarks': remarks,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        };
        if (uuidRegex.hasMatch(outwardId)) {
          await client
              .from(_ledgerTable)
              .update(updatePayload)
              .eq('reference_id', outwardId);
        } else {
          await client
              .from(_ledgerTable)
              .update(updatePayload)
              .eq('transaction_type', 'MATERIAL_OUTWARD')
              .eq('reference_number', outwardNumber);
        }
        await client.rpc('recalculate_sub_vendor_ledger_balances', params: {'p_vendor_id': vendorId});
      } catch (e) {
        debugPrint('Notice: Supabase mirrored outward update skipped/unavailable ($e).');
      }
    }

    // Update existing local ledger cache entry if present
    final existingIdx = _inMemoryLedger.indexWhere((e) =>
        e.id == 'mo_$outwardId' ||
        e.referenceId == outwardId ||
        (e.transactionType.toUpperCase() == 'MATERIAL_OUTWARD' &&
            e.referenceNumber.trim().toUpperCase() == outwardNumber.trim().toUpperCase()));
    if (existingIdx >= 0 && isUpdate) {
      final existing = _inMemoryLedger[existingIdx];
      _inMemoryLedger[existingIdx] = existing.copyWith(
        vendorId: vendorId,
        vendorName: vendorName,
        transactionDate: normDate,
        creditAmount: 0.0,
        debitAmount: normalizedAmt,
        particulars: particulars,
        remarks: remarks,
        updatedAt: DateTime.now(),
      );
      _recalculateLocalRunningBalances(vendorId);
      if (existing.vendorId != vendorId) {
        _recalculateLocalRunningBalances(existing.vendorId);
      }
      await _saveLedgerToCache(_inMemoryLedger);
      return;
    }

    // In offline/test mode (or when no mirrored row existed on update without remote outward)
    if (!isUpdate) {
      await recordTransaction(
        vendorId: vendorId,
        vendorName: vendorName,
        transactionDate: normDate,
        transactionType: 'MATERIAL_OUTWARD',
        amount: normalizedAmt,
        referenceNumber: outwardNumber,
        referenceId: outwardId,
        paymentMode: 'Inventory',
        particulars: particulars,
        remarks: remarks,
      );
    }
  }

  // ---------------------------------------------------------------------------
  // 3. CANCEL TRANSACTION OR CANCEL BY OUTWARD REFERENCE ID
  // ---------------------------------------------------------------------------
  static Future<void> cancelLedgerEntryByReferenceId(
    String referenceId, {
    String? outwardNumber,
    String reason = 'Outward Cancelled',
  }) async {
    await _ensureLocalInitialized();

    final nowIso = DateTime.now().toUtc().toIso8601String();
    final affectedVendors = <String>{};

    // Update any mirrored Supabase ledger entries so cancelled outwards never remain Active
    try {
      final client = SupabaseService.client;
      final uuidRegex = RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$');
      final cancelPayload = {
        'status': 'Cancelled',
        'cancelled_at': nowIso,
        'cancellation_reason': reason,
        'updated_at': nowIso,
      };
      if (uuidRegex.hasMatch(referenceId)) {
        final updatedRows = await client
            .from(_ledgerTable)
            .update(cancelPayload)
            .eq('reference_id', referenceId)
            .select('vendor_id');
        for (final r in (updatedRows as List<dynamic>)) {
          final vid = r['vendor_id'] as String?;
          if (vid != null) affectedVendors.add(vid);
        }
      }
      if (outwardNumber != null && outwardNumber.trim().isNotEmpty) {
        final byRefNo = await client
            .from(_ledgerTable)
            .update(cancelPayload)
            .eq('transaction_type', 'MATERIAL_OUTWARD')
            .eq('reference_number', outwardNumber.trim())
            .select('vendor_id');
        for (final r in (byRefNo as List<dynamic>)) {
          final vid = r['vendor_id'] as String?;
          if (vid != null) affectedVendors.add(vid);
        }
      }
      for (final vid in affectedVendors) {
        await client.rpc('recalculate_sub_vendor_ledger_balances', params: {'p_vendor_id': vid});
      }
    } catch (e) {
      debugPrint('Notice: Supabase mirrored outward cancellation ($e).');
    }

    for (var idx = 0; idx < _inMemoryLedger.length; idx++) {
      final existing = _inMemoryLedger[idx];
      final matchesRefId = existing.referenceId == referenceId || existing.id == 'mo_$referenceId';
      final matchesOutwardNo = outwardNumber != null &&
          outwardNumber.trim().isNotEmpty &&
          existing.transactionType.toUpperCase() == 'MATERIAL_OUTWARD' &&
          existing.referenceNumber.trim().toUpperCase() == outwardNumber.trim().toUpperCase();
      if (matchesRefId || matchesOutwardNo) {
        _inMemoryLedger[idx] = existing.copyWith(
          status: 'Cancelled',
          cancelledAt: DateTime.now(),
          cancellationReason: reason,
          updatedAt: DateTime.now(),
        );
        affectedVendors.add(existing.vendorId);
      }
    }
    for (final vid in affectedVendors) {
      _recalculateLocalRunningBalances(vid);
    }
    await _saveLedgerToCache(_inMemoryLedger);
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

    if (entryId.startsWith('mo_')) {
      throw Exception('Material Outward entries (OUT-...) must be cancelled from the "Material Outward" tab so outward audit logs remain intact.');
    } else if (entryId.startsWith('cpt_') || entryId.startsWith('a_coll_')) {
      throw Exception('Auto-synced Customer / Loan entries cannot be cancelled directly from this manual ledger.');
    }

    final nowIso = DateTime.now().toUtc().toIso8601String();
    try {
      final client = SupabaseService.client;
      if (entryId.startsWith('cp_')) {
        await client.from('vendor_customer_payments').update({
          'status': 'Rejected',
          'remarks': '${existing.remarks ?? ""} [Cancelled: $reason]'.trim(),
          'updated_at': nowIso,
        }).eq('id', entryId.substring(3));
      } else if (entryId.startsWith('vp_')) {
        await client.from('vendor_payouts').update({
          'status': 'Rejected',
          'remarks': '${existing.remarks ?? ""} [Cancelled: $reason]'.trim(),
        }).eq('id', entryId.substring(3));
      } else if (!entryId.startsWith('vmt_')) {
        await client.from(_ledgerTable).update({
          'status': 'Cancelled',
          'cancelled_at': nowIso,
          'cancellation_reason': reason,
          'updated_at': nowIso,
        }).eq('id', entryId);
        await client.rpc('recalculate_sub_vendor_ledger_balances', params: {'p_vendor_id': existing.vendorId});
      }
    } catch (e) {
      debugPrint('Notice: Supabase cancel ledger entry ($e). Applying local soft cancellation.');
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

  /// Permanently removes a manual ledger entry from Supabase & local cache and recalculates running balances.
  static Future<void> deleteTransaction(String entryId) async {
    await _ensureLocalInitialized();

    final idx = _inMemoryLedger.indexWhere((e) => e.id == entryId);
    final vendorId = idx >= 0 ? _inMemoryLedger[idx].vendorId : null;

    if (entryId.startsWith('mo_')) {
      throw Exception(
        'Material Outward entries (OUT-...) must be cancelled from the "Material Outward" tab so outward audit logs remain intact.',
      );
    } else if (entryId.startsWith('cpt_')) {
      throw Exception(
        'CRM Customer Payments cannot be deleted from here. Manage them inside the Customer Payment Module.',
      );
    } else if (entryId.startsWith('a_coll_')) {
      throw Exception(
        'Auto-synced Site Collection entries reflect Customer Paid / Bank Loan amounts and cannot be manually deleted here.',
      );
    }

    try {
      final client = SupabaseService.client;
      if (entryId.startsWith('cp_')) {
        await client.from('vendor_customer_payments').delete().eq('id', entryId.substring(3));
      } else if (entryId.startsWith('vp_')) {
        await client.from('vendor_payouts').delete().eq('id', entryId.substring(3));
      } else if (entryId.startsWith('vmt_')) {
        await client.from('vendor_material_transactions').delete().eq('id', entryId.substring(4));
      } else {
        await client.from(_ledgerTable).delete().eq('id', entryId);
      }
    } catch (e) {
      debugPrint('Notice: Supabase delete ledger entry ($e). Removing locally.');
    }

    if (idx >= 0) {
      _inMemoryLedger.removeAt(idx);
      if (vendorId != null) {
        _recalculateLocalRunningBalances(vendorId);
      }
      await _saveLedgerToCache(_inMemoryLedger);
    }
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
      final String? vFilter =
          (vendorId != null && vendorId.isNotEmpty && vendorId != 'All') ? vendorId : null;

      List<SubVendorAccountLedgerEntry> list = [];

      // -----------------------------------------------------------------------
      // PRIMARY PATH: Query the centralised v_sub_vendor_unified_ledger VIEW
      // (Created in migration 20261126000049_sub_vendor_central_database_audit_fix.sql)
      // This single view UNIONs all 4 sources — no double-counting.
      // -----------------------------------------------------------------------
      final localCachedEntries = List<SubVendorAccountLedgerEntry>.from(_inMemoryLedger);
      bool unifiedViewLoaded = false;
      bool ledgerTableLoaded = false;

      try {
        var viewQuery = client.from('v_sub_vendor_unified_ledger').select();
        if (vFilter != null) {
          viewQuery = viewQuery.eq('vendor_id', vFilter);
        }
        final viewRes = await viewQuery
            .order('transaction_date', ascending: true)
            .order('created_at', ascending: true);

        final List<dynamic> viewRows = viewRes as List<dynamic>;
        list = viewRows.map((e) => _entryFromUnifiedRow(e as Map<String, dynamic>)).toList();
        unifiedViewLoaded = true;
        ledgerTableLoaded = true;
      } catch (viewErr) {
        debugPrint('Notice: v_sub_vendor_unified_ledger view not available ($viewErr). Using multi-table fallback.');
      }

      if (!unifiedViewLoaded) {
        try {
          var query = client.from(_ledgerTable).select();
          if (vFilter != null) {
            query = query.eq('vendor_id', vFilter);
          }
          final res = await query
              .order('transaction_date', ascending: true)
              .order('created_at', ascending: true);
          final List<dynamic> rows = res as List<dynamic>;
          list = rows.map((e) => SubVendorAccountLedgerEntry.fromJson(e as Map<String, dynamic>)).toList();
          ledgerTableLoaded = true;
        } catch (ledgerErr) {
          debugPrint('Notice: $_ledgerTable table query unavailable ($ledgerErr). Preserving local manual entries.');
        }
      }

      // Preserve or auto-sync any browser-cached local entries (recorded while SQL tables were missing)
      final uuidRegex = RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$');
      final localManual = localCachedEntries.where((loc) {
        if (vFilter != null && loc.vendorId != vFilter) return false;
        return loc.id.startsWith('ledger-') && loc.isActive;
      }).toList();

      if (ledgerTableLoaded && localManual.isNotEmpty) {
        final currentUserId = SupabaseService.currentUser?.id;
        for (final loc in localManual) {
          final alreadySynced = list.any((s) =>
              s.isActive &&
              s.vendorId == loc.vendorId &&
              s.transactionType == loc.transactionType &&
              s.referenceNumber.trim().toUpperCase() == loc.referenceNumber.trim().toUpperCase() &&
              ((s.creditAmount + s.debitAmount) - (loc.creditAmount + loc.debitAmount)).abs() < 0.01);
          if (alreadySynced) continue;

          // If this was a mirrored outward and outward_number already exists in list/mo, skip auto-inserting duplicate
          if (loc.transactionType == 'MATERIAL_OUTWARD' &&
              list.any((s) =>
                  s.transactionType == 'MATERIAL_OUTWARD' &&
                  s.referenceNumber.trim().toUpperCase() == loc.referenceNumber.trim().toUpperCase())) {
            continue;
          }

          try {
            final amt = loc.creditAmount > 0 ? loc.creditAmount : loc.debitAmount;
            final refUuid = (loc.referenceId != null && uuidRegex.hasMatch(loc.referenceId!))
                ? loc.referenceId
                : null;
            final rpcRes = await client.rpc('record_sub_vendor_ledger_entry', params: {
              'p_vendor_id': loc.vendorId,
              'p_transaction_date': loc.transactionDate.toIso8601String().split('T').first,
              'p_transaction_type': loc.transactionType,
              'p_amount': amt,
              'p_reference_number': loc.referenceNumber,
              'p_payment_mode': loc.paymentMode,
              'p_particulars': loc.particulars,
              'p_remarks': loc.remarks,
              'p_reference_id': refUuid,
              'p_created_by': currentUserId,
            });
            if (rpcRes != null && rpcRes['id'] != null) {
              list.add(loc.copyWith(id: rpcRes['id'].toString()));
            } else {
              list.add(loc);
            }
          } catch (syncErr) {
            debugPrint('Notice: Could not auto-sync local entry ${loc.referenceNumber} ($syncErr)');
            list.add(loc);
          }
        }
      } else if (!ledgerTableLoaded && localManual.isNotEmpty) {
        for (final loc in localManual) {
          if (!list.any((e) => e.id == loc.id)) {
            list.add(loc);
          }
        }
      }

      // Defensive supplemental merge across ALL central sub-vendor & CRM tables
      // so missing SQL migration branches (or pre-0050 view) never drop
      // Site Materials (vendor_material_transactions), Outwards, Loans, CRM Payments, or Payouts.
      List<SubVendor> vendorsList = [];
      List<Map<String, dynamic>> rawOutwards = [];
      List<VendorCustomerPayment> cpList = [];
      List<VendorSiteAssignment> assignList = [];
      List<Map<String, dynamic>> crmPaymentsRaw = [];
      List<VendorPayout> vpList = [];
      List<VendorMaterialTransaction> vmtList = [];

      try {
        vendorsList = await SubVendorService.fetchAllVendors();
      } catch (e) {
        debugPrint('Notice: Ledger merge fetchAllVendors ($e)');
      }

      try {
        var moQuery = client.from('sub_vendor_material_outwards').select();
        if (vFilter != null) moQuery = moQuery.eq('vendor_id', vFilter);
        final moRes = await moQuery;
        rawOutwards = (moRes as List<dynamic>).map((r) => Map<String, dynamic>.from(r as Map)).toList();
      } catch (e) {
        debugPrint('Notice: Ledger merge outwards ($e)');
      }

      try {
        cpList = await SubVendorService.fetchCustomerPayments(vendorId: vFilter);
      } catch (e) {
        debugPrint('Notice: Ledger merge vendor_customer_payments ($e)');
      }

      try {
        assignList = await SubVendorService.fetchAssignments(vendorId: vFilter);
      } catch (e) {
        debugPrint('Notice: Ledger merge vendor_site_assignments ($e)');
      }

      try {
        final custIds = assignList
            .where((a) => a.status != 'Cancelled' && a.customerId.isNotEmpty)
            .map((a) => a.customerId)
            .toSet()
            .toList();
        if (custIds.isNotEmpty) {
          final cptRes = await client
              .from('customer_payment_transactions')
              .select()
              .inFilter('customer_id', custIds);
          crmPaymentsRaw = (cptRes as List<dynamic>).map((r) => Map<String, dynamic>.from(r as Map)).toList();
        }
      } catch (e) {
        debugPrint('Notice: Ledger merge customer_payment_transactions ($e)');
      }

      try {
        vpList = vFilter != null
            ? await SubVendorService.fetchVendorPayouts(vFilter)
            : await SubVendorService.fetchAllVendorPayouts();
      } catch (e) {
        debugPrint('Notice: Ledger merge vendor_payouts ($e)');
      }

      try {
        vmtList = vFilter != null
            ? await SubVendorService.fetchVendorMaterials(vFilter)
            : await SubVendorService.fetchAllVendorMaterials();
      } catch (e) {
        debugPrint('Notice: Ledger merge vendor_material_transactions ($e)');
      }

      list = mergeSupplementalLedgerEntries(
        baseEntries: list,
        vendorNameMap: {for (final v in vendorsList) v.id: v.name},
        rawOutwards: rawOutwards,
        siteMaterials: vmtList,
        customerPayments: cpList,
        assignments: assignList,
        crmPaymentsRaw: crmPaymentsRaw,
        payouts: vpList,
        vendorFilter: vFilter,
      );

      if (vFilter != null) {
        _inMemoryLedger = [
          ..._inMemoryLedger.where((e) => e.vendorId != vFilter),
          ...list,
        ];
      } else {
        _inMemoryLedger = list;
      }

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

  static SubVendorAccountLedgerEntry _entryFromUnifiedRow(Map<String, dynamic> row) {
    final credit = (row['credit_amount'] as num?)?.toDouble() ?? 0.0;
    final debit = (row['debit_amount'] as num?)?.toDouble() ?? 0.0;
    final type = (row['transaction_type'] as String? ?? 'MATERIAL_PAYMENT').toUpperCase();
    final cat = (row['category'] as String? ?? 'MATERIAL').toUpperCase();
    return SubVendorAccountLedgerEntry(
      id: row['id'] as String? ?? '',
      vendorId: row['vendor_id'] as String? ?? '',
      vendorName: row['vendor_name'] as String? ?? 'Sub-Vendor',
      transactionDate: row['transaction_date'] != null
          ? DateTime.tryParse(row['transaction_date'] as String) ?? DateTime.now()
          : DateTime.now(),
      transactionType: type,
      category: cat,
      creditAmount: credit,
      debitAmount: debit,
      runningBalance: (row['running_balance'] as num?)?.toDouble() ?? 0.0,
      referenceNumber: row['reference_number'] as String? ?? '-',
      referenceId: row['reference_id'] as String?,
      paymentMode: row['payment_mode'] as String? ?? 'Bank Transfer',
      particulars: row['particulars'] as String? ?? '',
      remarks: row['remarks'] as String?,
      status: row['status'] as String? ?? 'Active',
      createdAt: row['created_at'] != null
          ? DateTime.tryParse(row['created_at'] as String)
          : null,
    );
  }

  /// Pure deduplicating merger across all central sources (Ledger, Material Outwards,
  /// Site Materials, Vendor Customer Payments, CRM Customer Payments, Site Collections,
  /// and Vendor Payouts) so every screen sees complete data whether SQL view 0050 is
  /// deployed or running via fallback queries.
  static List<SubVendorAccountLedgerEntry> mergeSupplementalLedgerEntries({
    required List<SubVendorAccountLedgerEntry> baseEntries,
    Map<String, String> vendorNameMap = const {},
    List<Map<String, dynamic>> rawOutwards = const [],
    List<VendorMaterialTransaction> siteMaterials = const [],
    List<VendorCustomerPayment> customerPayments = const [],
    List<VendorSiteAssignment> assignments = const [],
    List<Map<String, dynamic>> crmPaymentsRaw = const [],
    List<VendorPayout> payouts = const [],
    String? vendorFilter,
  }) {
    final merged = List<SubVendorAccountLedgerEntry>.from(baseEntries);
    final existingIds = merged.map((e) => e.id).toSet();
    final existingActiveRefIds = merged
        .where((e) => e.isActive && e.referenceId != null && e.referenceId!.isNotEmpty)
        .map((e) => e.referenceId!)
        .toSet();
    final existingActiveOutwardKeys = merged
        .where((e) => e.isActive && e.transactionType.toUpperCase() == 'MATERIAL_OUTWARD')
        .map((e) => '${e.vendorId}::${e.referenceNumber.trim().toUpperCase()}')
        .toSet();

    // 1. Active Material Outwards (sub_vendor_material_outwards)
    for (final row in rawOutwards) {
      final status = (row['status'] as String? ?? 'Active');
      if (status != 'Active') continue;
      final vid = row['vendor_id'] as String? ?? '';
      if (vendorFilter != null && vid != vendorFilter) continue;
      final moId = row['id'] as String? ?? '';
      if (moId.isEmpty) continue;
      final synthId = 'mo_$moId';
      final outwardNo = (row['outward_number'] as String? ?? '-').trim();
      final outKey = '$vid::${outwardNo.toUpperCase()}';
      if (existingIds.contains(synthId) ||
          existingActiveRefIds.contains(moId) ||
          existingActiveOutwardKeys.contains(outKey)) {
        continue;
      }

      final outwardDate = row['outward_date'] != null
          ? DateTime.tryParse(row['outward_date'] as String) ?? DateTime.now()
          : DateTime.now();
      final totalVal = (row['total_value'] as num?)?.toDouble() ?? 0.0;
      final totalItems = (row['total_items'] as num?)?.toInt() ?? 0;
      final totalQty = (row['total_quantity'] as num?)?.toDouble() ?? 0.0;

      merged.add(SubVendorAccountLedgerEntry(
        id: synthId,
        vendorId: vid,
        vendorName: vendorNameMap[vid] ?? (row['vendor_name'] as String?) ?? 'Sub-Vendor',
        transactionDate: outwardDate,
        transactionType: 'MATERIAL_OUTWARD',
        category: 'MATERIAL',
        creditAmount: 0.0,
        debitAmount: totalVal,
        runningBalance: 0.0,
        referenceNumber: (row['outward_number'] as String?) ?? '-',
        referenceId: moId,
        paymentMode: 'Inventory',
        particulars: 'Material Outward Dispatch ($totalItems items, Qty: $totalQty)',
        remarks: row['remarks'] as String?,
        status: 'Active',
        createdAt: row['created_at'] != null
            ? DateTime.tryParse(row['created_at'] as String) ?? outwardDate
            : outwardDate,
      ));
      existingIds.add(synthId);
      existingActiveRefIds.add(moId);
    }

    // 2. Site Material Issues & Returns (vendor_material_transactions)
    for (final vmt in siteMaterials) {
      if (vendorFilter != null && vmt.vendorId != vendorFilter) continue;
      if (vmt.totalAmount <= 0) continue;
      final synthId = 'vmt_${vmt.id}';
      if (existingIds.contains(synthId) || existingActiveRefIds.contains(vmt.id)) continue;

      merged.add(SubVendorAccountLedgerEntry(
        id: synthId,
        vendorId: vmt.vendorId,
        vendorName: vendorNameMap[vmt.vendorId] ?? 'Sub-Vendor',
        transactionDate: vmt.transactionDate,
        transactionType: vmt.isReturn ? 'MATERIAL_PAYMENT' : 'MATERIAL_OUTWARD',
        category: 'MATERIAL',
        creditAmount: vmt.isReturn ? vmt.totalAmount : 0.0,
        debitAmount: vmt.isReturn ? 0.0 : vmt.totalAmount,
        runningBalance: 0.0,
        referenceNumber: vmt.challanNumber ?? vmt.invoiceNumber ?? 'SITE-${vmt.assignmentId.length >= 8 ? vmt.assignmentId.substring(0, 8) : vmt.assignmentId}',
        referenceId: vmt.id,
        paymentMode: 'Inventory',
        particulars: vmt.isReturn
            ? 'Site Material Return: ${vmt.itemName} (${vmt.quantity} ${vmt.unit})'
            : 'Site Material Given: ${vmt.itemName} (${vmt.quantity} ${vmt.unit})',
        remarks: vmt.remarks,
        status: 'Active',
        createdAt: vmt.createdAt ?? vmt.transactionDate,
      ));
      existingIds.add(synthId);
      existingActiveRefIds.add(vmt.id);
    }

    // 3. Vendor Customer Payments (Cash & Bank Loan Credits in vendor_customer_payments)
    final Map<String, double> capturedSumByAssign = {};
    final Map<String, List<VendorCustomerPayment>> approvedCpByAssign = {};

    for (final cp in customerPayments) {
      if (!cp.isApproved) continue;
      if (vendorFilter != null && cp.vendorId != vendorFilter) continue;
      approvedCpByAssign.putIfAbsent(cp.assignmentId, () => []).add(cp);
      capturedSumByAssign[cp.assignmentId] =
          (capturedSumByAssign[cp.assignmentId] ?? 0.0) + cp.amount;

      final synthId = 'cp_${cp.id}';
      if (existingIds.contains(synthId) || existingActiveRefIds.contains(cp.id)) continue;

      final custName = cp.customerName ?? 'Customer';
      merged.add(SubVendorAccountLedgerEntry(
        id: synthId,
        vendorId: cp.vendorId,
        vendorName: vendorNameMap[cp.vendorId] ?? cp.vendorName ?? 'Sub-Vendor',
        transactionDate: cp.paymentDate,
        transactionType: 'MATERIAL_PAYMENT',
        category: 'MATERIAL',
        creditAmount: cp.amount,
        debitAmount: 0.0,
        runningBalance: 0.0,
        referenceNumber: cp.referenceNumber ?? cp.loanApplicationId ?? '-',
        referenceId: cp.id,
        paymentMode: cp.paymentMode,
        particulars: cp.isLoan
            ? 'Bank Loan Credited (${cp.bankName ?? "Bank"} - $custName)'
            : 'Customer Cash / Payment Received ($custName)',
        remarks: cp.remarks,
        status: 'Active',
        createdAt: cp.createdAt ?? cp.paymentDate,
      ));
      existingIds.add(synthId);
      existingActiveRefIds.add(cp.id);
    }

    // 4. Main CRM Customer / Loan Payments (customer_payment_transactions) for assigned sites
    final Map<String, List<VendorSiteAssignment>> assignsByCustomer = {};
    for (final a in assignments) {
      if (a.status == 'Cancelled') continue;
      if (vendorFilter != null && a.vendorId != vendorFilter) continue;
      assignsByCustomer.putIfAbsent(a.customerId, () => []).add(a);
    }

    for (final row in crmPaymentsRaw) {
      final status = (row['status'] as String? ?? 'Valid');
      final deleted = row['deleted'] == true;
      final verStatus = (row['verification_status'] as String? ?? 'Pending');
      if (status != 'Valid' || deleted || verStatus == 'Rejected' || verStatus == 'Void') {
        continue;
      }
      final cptId = row['id'] as String? ?? '';
      final custId = row['customer_id'] as String? ?? '';
      final amt = (row['amount'] as num?)?.toDouble() ?? 0.0;
      if (cptId.isEmpty || custId.isEmpty || amt <= 0) continue;

      final custAssigns = assignsByCustomer[custId];
      if (custAssigns == null || custAssigns.isEmpty) continue;

      final pDate = row['payment_date'] != null
          ? DateTime.tryParse(row['payment_date'] as String) ?? DateTime.now()
          : DateTime.now();
      final cptRef = (row['reference_number'] as String? ?? '').trim();
      final pMode = row['payment_mode'] as String? ?? 'Bank Transfer';
      final pType = row['payment_type'] as String? ?? 'Payment';
      final remarks = row['remarks'] as String?;

      for (final a in custAssigns) {
        final existingCps = approvedCpByAssign[a.id] ?? const [];
        final isDuplicateOfCp = existingCps.any((cp) {
          final cpRef = (cp.referenceNumber ?? '').trim();
          if (cpRef.isNotEmpty && cptRef.isNotEmpty && cpRef.toUpperCase() == cptRef.toUpperCase()) {
            return true;
          }
          return (cp.amount - amt).abs() < 0.01 &&
              cp.paymentDate.difference(pDate).inDays.abs() <= 1;
        });
        if (isDuplicateOfCp) continue;

        capturedSumByAssign[a.id] = (capturedSumByAssign[a.id] ?? 0.0) + amt;

        final aPrefix = a.id.length >= 8 ? a.id.substring(0, 8) : a.id;
        final synthId = 'cpt_${cptId}_$aPrefix';
        if (existingIds.contains(synthId) || existingActiveRefIds.contains(cptId)) continue;

        final custName = a.customerName ?? 'Customer';
        final lowerInfo = '${remarks ?? ''} $pType $pMode'.toLowerCase();
        final isLoanHint = lowerInfo.contains('loan');

        merged.add(SubVendorAccountLedgerEntry(
          id: synthId,
          vendorId: a.vendorId,
          vendorName: vendorNameMap[a.vendorId] ?? a.vendorName ?? 'Sub-Vendor',
          transactionDate: pDate,
          transactionType: 'MATERIAL_PAYMENT',
          category: 'MATERIAL',
          creditAmount: amt,
          debitAmount: 0.0,
          runningBalance: 0.0,
          referenceNumber: cptRef.isNotEmpty ? cptRef : (a.consumerNo ?? row['consumer_no'] as String? ?? '-'),
          referenceId: cptId,
          paymentMode: pMode,
          particulars: isLoanHint
              ? 'Bank Loan / Finance Credited ($pType - $custName)'
              : 'Customer Payment Received ($pType - $custName)',
          remarks: remarks,
          status: 'Active',
          createdAt: row['created_at'] != null
              ? DateTime.tryParse(row['created_at'] as String) ?? pDate
              : pDate,
        ));
        existingIds.add(synthId);
        existingActiveRefIds.add(cptId);
      }
    }

    // 5. Assignment / Consumer Paid Residual Fallback (captures Bank Loan / Paid Amount not itemized above)
    for (final a in assignments) {
      if (a.status == 'Cancelled') continue;
      if (vendorFilter != null && a.vendorId != vendorFilter) continue;
      final synthId = 'a_coll_${a.id}';
      if (existingIds.contains(synthId) || existingActiveRefIds.contains(a.id)) continue;

      final targetCollected = a.effectiveReceivedAmount;
      final alreadyCaptured = capturedSumByAssign[a.id] ?? 0.0;
      final residual = double.parse((targetCollected - alreadyCaptured).toStringAsFixed(2));
      if (residual <= 0.01) continue;

      merged.add(SubVendorAccountLedgerEntry(
        id: synthId,
        vendorId: a.vendorId,
        vendorName: vendorNameMap[a.vendorId] ?? a.vendorName ?? 'Sub-Vendor',
        transactionDate: a.assignedDate,
        transactionType: 'MATERIAL_PAYMENT',
        category: 'MATERIAL',
        creditAmount: residual,
        debitAmount: 0.0,
        runningBalance: 0.0,
        referenceNumber: a.loanApplicationId ?? a.consumerNo ?? 'COLL-${a.id.length >= 8 ? a.id.substring(0, 8) : a.id}',
        referenceId: a.id,
        paymentMode: a.totalLoanCredited > 0 ? 'Bank Transfer' : a.paymentType,
        particulars: a.totalLoanCredited > 0
            ? 'Site Loan & Customer Collection (${a.customerName ?? "Site"} | Loan: Rs. ${a.totalLoanCredited.toStringAsFixed(2)})'
            : 'Site Customer Collection (${a.customerName ?? "Site"})',
        remarks: 'Auto-synced residual from Site Assignment / Consumer Paid Amount',
        status: 'Active',
        createdAt: a.createdAt ?? a.assignedDate,
      ));
      existingIds.add(synthId);
      existingActiveRefIds.add(a.id);
    }

    // 6. Approved / Paid Vendor Payouts (vendor_payouts)
    for (final vp in payouts) {
      if (vendorFilter != null && vp.vendorId != vendorFilter) continue;
      final st = vp.status.toLowerCase();
      if (st == 'rejected' || st == 'cancelled' || st == 'pending') continue;
      final synthId = 'vp_${vp.id}';
      if (existingIds.contains(synthId) || existingActiveRefIds.contains(vp.id)) continue;

      merged.add(SubVendorAccountLedgerEntry(
        id: synthId,
        vendorId: vp.vendorId,
        vendorName: vendorNameMap[vp.vendorId] ?? 'Sub-Vendor',
        transactionDate: vp.payoutDate,
        transactionType: 'ADVANCE_GIVEN',
        category: 'ADVANCE',
        creditAmount: 0.0,
        debitAmount: vp.amount,
        runningBalance: 0.0,
        referenceNumber: vp.referenceNumber ?? '-',
        referenceId: vp.id,
        paymentMode: vp.paymentMode,
        particulars: 'Payout / Advance to Sub-Vendor',
        remarks: vp.remarks,
        status: 'Active',
        createdAt: vp.createdAt ?? vp.payoutDate,
      ));
      existingIds.add(synthId);
      existingActiveRefIds.add(vp.id);
    }

    return merged;
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
    try {
      await fetchLedgerEntries(statusFilter: 'All');
    } catch (_) {}

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

    final balances = SubVendorFinancialEngine.calculatePassbookBalances(
      _inMemoryLedger,
      fromDate: fromDate,
      toDate: toDate,
    );

    // Sub Vendor-wise Balances (using same normalized central Passbook engine)
    final List<SubVendorAccountBalanceSummary> vendorBalances = [];

    for (final v in vendors) {
      final vActive = activeEntries.where((e) => e.vendorId == v.id).toList();
      final vBal = SubVendorFinancialEngine.calculatePassbookBalances(
        _inMemoryLedger,
        vendorId: v.id,
        fromDate: fromDate,
        toDate: toDate,
      );
      DateTime? lastDate;
      for (final e in vActive) {
        final d = SubVendorFinancialEngine.normalizeDate(e.transactionDate);
        if (lastDate == null || d.isAfter(lastDate)) {
          lastDate = d;
        }
      }

      vendorBalances.add(SubVendorAccountBalanceSummary(
        vendorId: v.id,
        vendorName: v.name,
        vendorCode: v.vendorCode,
        totalCredit: vBal.totalCredit,
        totalDebit: vBal.totalDebit,
        netBalance: vBal.netBalance,
        materialReceivable: vBal.materialReceivableBalance,
        advanceBalance: vBal.advanceBalance,
        totalTransactions: vActive.length,
        lastTransactionDate: lastDate,
      ));
    }

    // Sort by largest outstanding balance first
    vendorBalances.sort((a, b) => b.netBalance.compareTo(a.netBalance));

    return SubVendorDashboardMetrics(
      totalCredit: balances.totalCredit,
      totalDebit: balances.totalDebit,
      netBalance: balances.netBalance,
      totalMaterialOutwardValue: balances.totalMaterialOutward,
      totalMaterialPaymentsReceived: balances.totalMaterialPaymentsReceived,
      netMaterialReceivable: balances.materialReceivableBalance,
      totalAdvanceGiven: balances.totalAdvanceGiven,
      totalAdvanceRefundReceived: balances.totalAdvanceRefundReceived,
      netAdvanceBalance: balances.advanceBalance,
      vendorBalances: vendorBalances,
    );
  }

  /// Calculates accurate Opening Balance strictly before `fromDate` for filtered statements.
  static double calculateOpeningBalance({
    String? vendorId,
    DateTime? fromDate,
  }) {
    if (fromDate == null) return 0.0;
    return SubVendorFinancialEngine.calculatePassbookBalances(
      _inMemoryLedger,
      vendorId: vendorId,
      fromDate: fromDate,
    ).openingBalance;
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
    final vEntries = _inMemoryLedger
        .where((e) => e.vendorId == vendorId)
        .map(SubVendorFinancialEngine.normalizeLedgerEntryPolarity)
        .toList()
      ..sort((a, b) {
        final dComp = SubVendorFinancialEngine.normalizeDate(a.transactionDate)
            .compareTo(SubVendorFinancialEngine.normalizeDate(b.transactionDate));
        if (dComp != 0) return dComp;
        final cA = a.createdAt ?? a.transactionDate;
        final cB = b.createdAt ?? b.transactionDate;
        final cComp = cA.compareTo(cB);
        if (cComp != 0) return cComp;
        return a.id.compareTo(b.id);
      });

    int balancePaise = 0;
    for (final e in vEntries) {
      if (e.isActive) {
        balancePaise += SubVendorFinancialEngine.toPaise(e.creditAmount) -
            SubVendorFinancialEngine.toPaise(e.debitAmount);
      }
      final globalIdx = _inMemoryLedger.indexWhere((item) => item.id == e.id);
      if (globalIdx >= 0) {
        _inMemoryLedger[globalIdx] = e.copyWith(
          runningBalance: SubVendorFinancialEngine.fromPaise(balancePaise),
        );
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
      if (!SubVendorFinancialEngine.isWithinDateRange(
        e.transactionDate,
        fromDate: fromDate,
        toDate: toDate,
      )) {
        return false;
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
        final dComp = SubVendorFinancialEngine.normalizeDate(b.transactionDate)
            .compareTo(SubVendorFinancialEngine.normalizeDate(a.transactionDate));
        if (dComp != 0) return dComp;
        final cA = a.createdAt ?? a.transactionDate;
        final cB = b.createdAt ?? b.transactionDate;
        final cComp = cB.compareTo(cA);
        if (cComp != 0) return cComp;
        return b.id.compareTo(a.id);
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
