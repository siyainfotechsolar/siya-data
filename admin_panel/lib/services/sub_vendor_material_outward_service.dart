import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:siya_shared/siya_shared.dart';
import 'sub_vendor_service.dart';
import 'sub_vendor_account_ledger_service.dart';
import 'supabase_service.dart';

/// Database & State Service for Sub-Vendor Material Outward Tracking & Inventory Stock Management.
class SubVendorMaterialOutwardService {
  static const String _outwardsTable = 'sub_vendor_material_outwards';
  static const String _itemsTable = 'sub_vendor_material_outward_items';
  static const String _auditTable = 'sub_vendor_material_outward_audit';
  static const String _materialMasterTable = 'solar_cost_material_master';

  static const String _localOutwardsKey = 'cached_sub_vendor_material_outwards';
  static const String _localMaterialsKey = 'cached_material_master_inventory';
  static const String _localAuditKey = 'cached_sub_vendor_outward_audits';

  // In-memory fallback caches for seamless responsiveness and tests
  static List<SubVendorMaterialOutward> _inMemoryOutwards = [];
  static List<MaterialMasterItem> _inMemoryMaterials = [];
  static List<SubVendorMaterialOutwardAudit> _inMemoryAudits = [];
  static bool _hasInitializedLocal = false;

  // ---------------------------------------------------------------------------
  // 1. FETCH ACTIVE SUB-VENDORS
  // ---------------------------------------------------------------------------
  static Future<List<SubVendor>> fetchActiveSubVendors() async {
    try {
      final vendors = await SubVendorService.fetchAllVendors();
      return vendors.where((v) => v.isActive && v.status.toLowerCase() != 'blocked').toList();
    } catch (e) {
      debugPrint('Warning: Could not fetch sub-vendors from Supabase: $e');
      if (e.toString().contains('initialize')) {
        return [
          const SubVendor(
            id: 'vnd-test-001',
            vendorCode: 'VND-TEST',
            name: 'Test Sub-Vendor',
            mobile: '9999999999',
            email: 'test@siyasolar.com',
            isActive: true,
            status: 'Active',
          ),
        ];
      }
      return [];
    }
  }

  // ---------------------------------------------------------------------------
  // 2. FETCH MATERIAL MASTER WITH INVENTORY STOCK
  // ---------------------------------------------------------------------------
  static Future<List<MaterialMasterItem>> fetchMaterialMaster() async {
    await _ensureLocalInitialized();
    try {
      final client = SupabaseService.client;
      final res = await client
          .from(_materialMasterTable)
          .select()
          .eq('is_active', true)
          .order('display_order', ascending: true);

      final List<dynamic> rows = res as List<dynamic>;
      if (rows.isNotEmpty) {
        final list = rows.map((e) => MaterialMasterItem.fromJson(e as Map<String, dynamic>)).toList();
        _inMemoryMaterials = list;
        _saveMaterialsToCache(list);
        return list;
      }
    } catch (e) {
      debugPrint('Warning: Could not fetch material master from Supabase: $e. Using local stock.');
    }

    if (_inMemoryMaterials.isNotEmpty) return _inMemoryMaterials;
    return _defaultInitialMaterials;
  }

  /// Adds a custom new material to the existing Material Master (or local fallback).
  static Future<MaterialMasterItem> addMaterialToMaster({
    required String itemName,
    String unit = 'NOS',
    double defaultRate = 0.0,
    String category = 'OTHER',
  }) async {
    await _ensureLocalInitialized();
    final trimmed = itemName.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('Material name cannot be empty.');
    }

    // Check if already exists case-insensitively
    final existingIdx = _inMemoryMaterials.indexWhere(
      (m) => m.itemName.toLowerCase() == trimmed.toLowerCase(),
    );
    if (existingIdx >= 0) {
      return _inMemoryMaterials[existingIdx];
    }

    try {
      final client = SupabaseService.client;
      final res = await client.from(_materialMasterTable).insert({
        'item_name': trimmed,
        'unit': unit.toUpperCase(),
        'category': category,
        'default_rate': defaultRate,
        'is_active': true,
        'display_order': _inMemoryMaterials.length + 1,
      }).select().single();

      final created = MaterialMasterItem.fromJson(res);
      _inMemoryMaterials.add(created);
      await _saveMaterialsToCache(_inMemoryMaterials);
      return created;
    } catch (e) {
      debugPrint('Notice: Could not insert new material to Supabase ($e). Adding locally.');
    }

    final localNew = MaterialMasterItem(
      id: 'mat-custom-${DateTime.now().millisecondsSinceEpoch}',
      itemName: trimmed,
      unit: unit.toUpperCase(),
      category: category,
      defaultRate: defaultRate,
      displayOrder: _inMemoryMaterials.length + 1,
    );
    _inMemoryMaterials.add(localNew);
    await _saveMaterialsToCache(_inMemoryMaterials);
    return localNew;
  }

  /// Helper to compute normalized pricing fields for outward items.
  static List<SubVendorMaterialOutwardItem> _normalizeItemsPricing(
    List<SubVendorMaterialOutwardItem> items,
    String outwardId,
    Map<String, MaterialMasterItem> masterMap,
  ) {
    return items.map((i) {
      final rate = i.unitRate >= 0 ? i.unitRate : (masterMap[i.materialId]?.defaultRate ?? 0.0);
      final base = double.parse((i.quantity * rate).toStringAsFixed(2));
      final gstPct = i.gstPercentage;
      final gstAmt = double.parse((base * gstPct / 100.0).toStringAsFixed(2));
      final finalPrice = double.parse((base + gstAmt).toStringAsFixed(2));
      return i.copyWith(
        outwardId: outwardId,
        id: i.id.isNotEmpty ? i.id : 'item-${DateTime.now().microsecondsSinceEpoch}',
        unitRate: rate,
        baseAmount: base,
        gstPercentage: gstPct,
        gstAmount: gstAmt,
        totalPrice: finalPrice,
      );
    }).toList();
  }

  // ---------------------------------------------------------------------------
  // 3. RECORD OUTWARD ENTRY (BULK SAVE WITH RATE & GST, NO STOCK DEDUCTION)
  // ---------------------------------------------------------------------------
  static Future<SubVendorMaterialOutward> recordOutward({
    required String vendorId,
    required String vendorName,
    required DateTime outwardDate,
    String? remarks,
    required List<SubVendorMaterialOutwardItem> items,
  }) async {
    await _ensureLocalInitialized();

    // 1. Validations
    if (items.isEmpty) {
      throw ArgumentError('Material Outward entry must contain at least one material row.');
    }

    for (final item in items) {
      if (item.quantity <= 0) {
        throw ArgumentError('Quantity for "${item.materialName}" must be greater than zero.');
      }
      if (item.unitRate < 0) {
        throw ArgumentError('Rate for "${item.materialName}" cannot be negative.');
      }
    }

    final masterList = await fetchMaterialMaster();
    final masterMap = {for (var m in masterList) m.id: m};
    final normalizedItems = _normalizeItemsPricing(items, '', masterMap);

    final double totalQty = normalizedItems.fold<double>(0.0, (sum, i) => sum + i.quantity);
    final double subtotal = normalizedItems.fold<double>(0.0, (sum, i) => sum + i.baseAmount);
    final double totalGst = normalizedItems.fold<double>(0.0, (sum, i) => sum + i.gstAmount);
    final double grandTotal = normalizedItems.fold<double>(0.0, (sum, i) => sum + i.totalPrice);

    // 2. Try Supabase Atomic RPC (NO inventory stock deduction)
    try {
      final client = SupabaseService.client;
      final currentUser = SupabaseService.currentUser;

      final itemsPayload = normalizedItems.map((i) => {
        'material_id': i.materialId,
        'material_name': i.materialName,
        'unit': i.unit,
        'quantity': i.quantity,
        'unit_rate': i.unitRate,
        'base_amount': i.baseAmount,
        'gst_percentage': i.gstPercentage,
        'gst_amount': i.gstAmount,
        'total_price': i.totalPrice,
      }).toList();

      final rpcRes = await client.rpc('record_sub_vendor_material_outward', params: {
        'p_vendor_id': vendorId,
        'p_outward_date': outwardDate.toIso8601String().split('T').first,
        'p_remarks': remarks,
        'p_items': itemsPayload,
        'p_created_by': currentUser?.id,
      });

      if (rpcRes != null && rpcRes['success'] == true) {
        final outwardId = rpcRes['id'].toString();
        final outwardNumber = rpcRes['outward_number'].toString();

        final createdOutward = SubVendorMaterialOutward(
          id: outwardId,
          outwardNumber: outwardNumber,
          vendorId: vendorId,
          vendorName: vendorName,
          outwardDate: outwardDate,
          totalItems: normalizedItems.length,
          totalQuantity: totalQty,
          subtotal: subtotal,
          totalGst: totalGst,
          totalValue: grandTotal,
          remarks: remarks,
          status: 'Active',
          items: normalizedItems.map((i) => i.copyWith(outwardId: outwardId)).toList(),
          createdAt: DateTime.now(),
        );

        _inMemoryOutwards.insert(0, createdOutward);
        await _saveOutwardsToCache(_inMemoryOutwards);

        // Auto-sync with Credit/Debit Ledger
        if (grandTotal > 0) {
          await SubVendorAccountLedgerService.syncFromMaterialOutward(
            outwardId: outwardId,
            outwardNumber: outwardNumber,
            vendorId: vendorId,
            vendorName: vendorName,
            outwardDate: outwardDate,
            totalOutwardValue: grandTotal,
            totalItems: normalizedItems.length,
            totalQuantity: totalQty,
            remarks: remarks,
          );
        }

        return createdOutward;
      }
    } catch (e) {
      debugPrint('Notice: RPC call failed ($e). Processing with local outward engine.');
    }

    // 3. Local Fallback Execution (NO inventory stock deduction)
    final seq = _inMemoryOutwards.length + 1;
    final dateStr = '${outwardDate.year}${outwardDate.month.toString().padLeft(2, '0')}${outwardDate.day.toString().padLeft(2, '0')}';
    final outwardNumber = 'OUT-$dateStr-${seq.toString().padLeft(4, '0')}';
    final outwardId = 'outward-${DateTime.now().millisecondsSinceEpoch}-$seq';

    final processedItems = normalizedItems.map((i) => i.copyWith(outwardId: outwardId)).toList();

    final createdOutward = SubVendorMaterialOutward(
      id: outwardId,
      outwardNumber: outwardNumber,
      vendorId: vendorId,
      vendorName: vendorName,
      outwardDate: outwardDate,
      totalItems: processedItems.length,
      totalQuantity: totalQty,
      subtotal: subtotal,
      totalGst: totalGst,
      totalValue: grandTotal,
      remarks: remarks,
      status: 'Active',
      items: processedItems,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    _inMemoryOutwards.insert(0, createdOutward);
    _logAudit(
      outwardId: outwardId,
      outwardNumber: outwardNumber,
      action: 'CREATE',
      description: 'Created outward entry with ${processedItems.length} materials, total qty: $totalQty, grand total: $grandTotal',
      details: createdOutward.toJson(),
    );

    await _saveOutwardsToCache(_inMemoryOutwards);

    // Auto-sync with Credit/Debit Ledger
    if (grandTotal > 0) {
      await SubVendorAccountLedgerService.syncFromMaterialOutward(
        outwardId: outwardId,
        outwardNumber: outwardNumber,
        vendorId: vendorId,
        vendorName: vendorName,
        outwardDate: outwardDate,
        totalOutwardValue: grandTotal,
        totalItems: processedItems.length,
        totalQuantity: totalQty,
        remarks: remarks,
      );
    }

    return createdOutward;
  }

  // ---------------------------------------------------------------------------
  // 4. UPDATE OUTWARD ENTRY (WITH RATE & GST, NO STOCK MODIFICATION)
  // ---------------------------------------------------------------------------
  static Future<SubVendorMaterialOutward> updateOutward({
    required String outwardId,
    required String vendorId,
    required String vendorName,
    required DateTime outwardDate,
    String? remarks,
    required List<SubVendorMaterialOutwardItem> items,
  }) async {
    await _ensureLocalInitialized();

    if (items.isEmpty) {
      throw ArgumentError('Material Outward entry must contain at least one material row.');
    }

    for (final item in items) {
      if (item.quantity <= 0) {
        throw ArgumentError('Quantity for "${item.materialName}" must be greater than zero.');
      }
      if (item.unitRate < 0) {
        throw ArgumentError('Rate for "${item.materialName}" cannot be negative.');
      }
    }

    final existingIndex = _inMemoryOutwards.indexWhere((o) => o.id == outwardId);
    if (existingIndex < 0) {
      throw StateError('Material Outward entry "$outwardId" not found.');
    }

    final existing = _inMemoryOutwards[existingIndex];
    if (existing.isCancelled) {
      throw StateError('Cannot edit a Cancelled Material Outward record.');
    }

    final masterList = await fetchMaterialMaster();
    final masterMap = {for (var m in masterList) m.id: m};
    final processedItems = _normalizeItemsPricing(items, outwardId, masterMap);

    final double totalQty = processedItems.fold<double>(0.0, (sum, i) => sum + i.quantity);
    final double subtotal = processedItems.fold<double>(0.0, (sum, i) => sum + i.baseAmount);
    final double totalGst = processedItems.fold<double>(0.0, (sum, i) => sum + i.gstAmount);
    final double grandTotal = processedItems.fold<double>(0.0, (sum, i) => sum + i.totalPrice);

    // Try Supabase RPC first
    try {
      final client = SupabaseService.client;
      final currentUser = SupabaseService.currentUser;

      final itemsPayload = processedItems.map((i) => {
        'material_id': i.materialId,
        'material_name': i.materialName,
        'unit': i.unit,
        'quantity': i.quantity,
        'unit_rate': i.unitRate,
        'base_amount': i.baseAmount,
        'gst_percentage': i.gstPercentage,
        'gst_amount': i.gstAmount,
        'total_price': i.totalPrice,
      }).toList();

      final rpcRes = await client.rpc('update_sub_vendor_material_outward', params: {
        'p_outward_id': outwardId,
        'p_vendor_id': vendorId,
        'p_outward_date': outwardDate.toIso8601String().split('T').first,
        'p_remarks': remarks,
        'p_items': itemsPayload,
        'p_updated_by': currentUser?.id,
      });

      if (rpcRes != null && rpcRes['success'] == true) {
        final updated = existing.copyWith(
          vendorId: vendorId,
          vendorName: vendorName,
          outwardDate: outwardDate,
          remarks: remarks,
          items: processedItems,
          totalItems: processedItems.length,
          totalQuantity: totalQty,
          subtotal: subtotal,
          totalGst: totalGst,
          totalValue: grandTotal,
          updatedAt: DateTime.now(),
        );

        _inMemoryOutwards[existingIndex] = updated;
        await _saveOutwardsToCache(_inMemoryOutwards);
        await SubVendorAccountLedgerService.syncFromMaterialOutward(
          outwardId: outwardId,
          outwardNumber: updated.outwardNumber,
          vendorId: vendorId,
          vendorName: vendorName,
          outwardDate: outwardDate,
          totalOutwardValue: grandTotal,
          totalItems: processedItems.length,
          totalQuantity: totalQty,
          remarks: remarks,
          isUpdate: true,
        );
        return updated;
      }
    } catch (e) {
      debugPrint('Notice: RPC update failed ($e). Processing local update.');
    }

    final updated = existing.copyWith(
      vendorId: vendorId,
      vendorName: vendorName,
      outwardDate: outwardDate,
      remarks: remarks,
      items: processedItems,
      totalItems: processedItems.length,
      totalQuantity: totalQty,
      subtotal: subtotal,
      totalGst: totalGst,
      totalValue: grandTotal,
      updatedAt: DateTime.now(),
    );

    _inMemoryOutwards[existingIndex] = updated;
    _logAudit(
      outwardId: outwardId,
      outwardNumber: existing.outwardNumber,
      action: 'UPDATE',
      description: 'Updated outward entry. New Total Qty: $totalQty, Grand Total: $grandTotal',
      details: updated.toJson(),
    );

    await _saveOutwardsToCache(_inMemoryOutwards);

    // Auto-sync ledger update
    await SubVendorAccountLedgerService.syncFromMaterialOutward(
      outwardId: outwardId,
      outwardNumber: updated.outwardNumber,
      vendorId: vendorId,
      vendorName: vendorName,
      outwardDate: outwardDate,
      totalOutwardValue: grandTotal,
      totalItems: processedItems.length,
      totalQuantity: totalQty,
      remarks: remarks,
      isUpdate: true,
    );

    return updated;
  }

  // ---------------------------------------------------------------------------
  // 5. CANCEL OUTWARD ENTRY (NO STOCK MODIFICATION)
  // ---------------------------------------------------------------------------
  static Future<SubVendorMaterialOutward> cancelOutward(
    String outwardId, {
    String reason = 'Cancelled by Admin',
  }) async {
    await _ensureLocalInitialized();

    final existingIndex = _inMemoryOutwards.indexWhere((o) => o.id == outwardId);
    if (existingIndex < 0) {
      throw StateError('Material Outward entry "$outwardId" not found.');
    }

    final existing = _inMemoryOutwards[existingIndex];
    if (existing.isCancelled) {
      throw StateError('Record is already cancelled.');
    }

    // Try Supabase RPC first
    try {
      final client = SupabaseService.client;
      final currentUser = SupabaseService.currentUser;

      final rpcRes = await client.rpc('cancel_sub_vendor_material_outward', params: {
        'p_outward_id': outwardId,
        'p_cancellation_reason': reason,
        'p_cancelled_by': currentUser?.id,
      });

      if (rpcRes != null && rpcRes['success'] == true) {
        final cancelled = existing.copyWith(
          status: 'Cancelled',
          cancelledAt: DateTime.now(),
          cancellationReason: reason,
          updatedAt: DateTime.now(),
        );
        _inMemoryOutwards[existingIndex] = cancelled;
        await _saveOutwardsToCache(_inMemoryOutwards);
        await SubVendorAccountLedgerService.cancelLedgerEntryByReferenceId(outwardId, reason: reason);
        return cancelled;
      }
    } catch (e) {
      debugPrint('Notice: RPC cancellation failed ($e). Processing local cancellation.');
    }

    final cancelled = existing.copyWith(
      status: 'Cancelled',
      cancelledAt: DateTime.now(),
      cancellationReason: reason,
      updatedAt: DateTime.now(),
    );

    _inMemoryOutwards[existingIndex] = cancelled;
    _logAudit(
      outwardId: outwardId,
      outwardNumber: existing.outwardNumber,
      action: 'CANCEL',
      description: 'Cancelled outward entry: $reason',
      details: {'reason': reason},
    );

    await _saveOutwardsToCache(_inMemoryOutwards);

    // Auto-sync ledger cancellation
    await SubVendorAccountLedgerService.cancelLedgerEntryByReferenceId(outwardId, reason: reason);

    return cancelled;
  }

  // ---------------------------------------------------------------------------
  // 6. FETCH OUTWARDS (WITH REMOTE & LOCAL SYNC)
  // ---------------------------------------------------------------------------
  static final RegExp _uuidPattern = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  );

  static Future<List<SubVendorMaterialOutward>> fetchOutwards() async {
    await _ensureLocalInitialized();
    final localCached = List<SubVendorMaterialOutward>.from(_inMemoryOutwards);
    try {
      final client = SupabaseService.client;
      final res = await client
          .from(_outwardsTable)
          .select('*, sub_vendor_material_outward_items(*)')
          .order('outward_date', ascending: false)
          .order('created_at', ascending: false);

      final List<dynamic> rows = res as List<dynamic>;
      final list = rows.map((e) => SubVendorMaterialOutward.fromJson(e as Map<String, dynamic>)).toList();

      // Auto-sync any unsynced browser-cached local outward entries (e.g. recorded before SQL migration)
      final unsyncedLocal = localCached
          .where((o) => o.id.startsWith('outward-') && !list.any((r) => r.outwardNumber == o.outwardNumber))
          .toList();

      if (unsyncedLocal.isNotEmpty) {
        final currentUserId = SupabaseService.currentUser?.id;
        for (final localOut in unsyncedLocal) {
          try {
            final insertedHeader = await client
                .from(_outwardsTable)
                .insert({
                  'outward_number': localOut.outwardNumber,
                  'vendor_id': localOut.vendorId,
                  'vendor_name': localOut.vendorName,
                  'outward_date': localOut.outwardDate.toIso8601String().split('T').first,
                  'total_items': localOut.totalItems,
                  'total_quantity': localOut.totalQuantity,
                  'subtotal': localOut.subtotal,
                  'total_gst': localOut.totalGst,
                  'total_value': localOut.totalValue,
                  'remarks': localOut.remarks,
                  'status': localOut.status,
                  'created_by': currentUserId,
                })
                .select()
                .single();

            final newServerId = insertedHeader['id'].toString();
            if (localOut.items.isNotEmpty) {
              final itemsPayload = localOut.items
                  .map((i) => {
                        'outward_id': newServerId,
                        'material_id': (i.materialId != null && _uuidPattern.hasMatch(i.materialId!))
                            ? i.materialId
                            : null,
                        'material_name': i.materialName,
                        'unit': i.unit,
                        'quantity': i.quantity,
                        'unit_rate': i.unitRate,
                        'base_amount': i.baseAmount,
                        'gst_percentage': i.gstPercentage,
                        'gst_amount': i.gstAmount,
                        'total_price': i.totalPrice,
                      })
                  .toList();
              await client.from(_itemsTable).insert(itemsPayload);
            }
            list.insert(
              0,
              localOut.copyWith(
                id: newServerId,
                items: localOut.items.map((i) => i.copyWith(outwardId: newServerId)).toList(),
              ),
            );
          } catch (syncErr) {
            debugPrint('Notice: Preserving unsynced local outward ${localOut.outwardNumber} ($syncErr)');
            list.insert(0, localOut);
          }
        }
      }

      _inMemoryOutwards = list;
      await _saveOutwardsToCache(list);
      return list;
    } catch (e) {
      debugPrint('Warning: Could not fetch outwards from Supabase: $e');
    }

    return List.from(_inMemoryOutwards);
  }

  // ---------------------------------------------------------------------------
  // 7. AUDIT TRAIL LOGGING & FETCHING
  // ---------------------------------------------------------------------------
  static Future<List<SubVendorMaterialOutwardAudit>> fetchAudits(String outwardId) async {
    await _ensureLocalInitialized();
    return _inMemoryAudits.where((a) => a.outwardId == outwardId).toList();
  }

  static void _logAudit({
    required String outwardId,
    required String outwardNumber,
    required String action,
    required String description,
    required Map<String, dynamic> details,
  }) {
    final audit = SubVendorMaterialOutwardAudit(
      id: 'audit-${DateTime.now().millisecondsSinceEpoch}',
      outwardId: outwardId,
      outwardNumber: outwardNumber,
      action: action,
      description: description,
      details: details,
      createdAt: DateTime.now(),
    );
    _inMemoryAudits.insert(0, audit);
    _saveAuditsToCache(_inMemoryAudits);
  }

  // ---------------------------------------------------------------------------
  // 8. REPORT GENERATION ENGINE (DATE-WISE, SUB-VENDOR-WISE, MATERIAL-WISE)
  // ---------------------------------------------------------------------------

  /// Filter outward entries based on date range, vendor, material, and outward number.
  /// Important Rule: Cancelled entries are excluded from active report totals.
  static List<SubVendorMaterialOutward> filterOutwards(
    List<SubVendorMaterialOutward> entries, {
    DateTime? fromDate,
    DateTime? toDate,
    String? vendorId,
    String? materialName,
    String? outwardNumber,
    bool includeCancelled = false,
  }) {
    return entries.where((entry) {
      if (!includeCancelled && entry.isCancelled) return false;

      if (fromDate != null) {
        final d = DateTime(entry.outwardDate.year, entry.outwardDate.month, entry.outwardDate.day);
        final f = DateTime(fromDate.year, fromDate.month, fromDate.day);
        if (d.isBefore(f)) return false;
      }

      if (toDate != null) {
        final d = DateTime(entry.outwardDate.year, entry.outwardDate.month, entry.outwardDate.day);
        final t = DateTime(toDate.year, toDate.month, toDate.day);
        if (d.isAfter(t)) return false;
      }

      if (vendorId != null && vendorId.isNotEmpty && vendorId != 'All') {
        if (entry.vendorId != vendorId) return false;
      }

      if (outwardNumber != null && outwardNumber.trim().isNotEmpty) {
        if (!entry.outwardNumber.toLowerCase().contains(outwardNumber.trim().toLowerCase())) {
          return false;
        }
      }

      if (materialName != null && materialName.trim().isNotEmpty && materialName != 'All') {
        final hasMat = entry.items.any((i) => i.materialName.toLowerCase().contains(materialName.trim().toLowerCase()));
        if (!hasMat) return false;
      }

      return true;
    }).toList();
  }

  /// A. Date-wise Material Outward Report Rows
  static List<Map<String, dynamic>> generateDateWiseReportRows(List<SubVendorMaterialOutward> entries) {
    final List<Map<String, dynamic>> rows = [];
    final activeEntries = entries.where((e) => e.isActive).toList()
      ..sort((a, b) => b.outwardDate.compareTo(a.outwardDate));

    for (final entry in activeEntries) {
      for (final item in entry.items) {
        rows.add({
          'outward_number': entry.outwardNumber,
          'outward_date': entry.outwardDate,
          'vendor_name': entry.vendorName,
          'material_name': item.materialName,
          'unit': item.unit,
          'quantity': item.quantity,
          'remarks': entry.remarks ?? '',
        });
      }
    }
    return rows;
  }

  /// B. Sub Vendor-wise Report Summary & Breakdown
  static List<Map<String, dynamic>> generateSubVendorWiseSummary(List<SubVendorMaterialOutward> entries) {
    final activeEntries = entries.where((e) => e.isActive).toList();
    final Map<String, Map<String, dynamic>> vendorMap = {};

    for (final entry in activeEntries) {
      if (!vendorMap.containsKey(entry.vendorId)) {
        vendorMap[entry.vendorId] = {
          'vendor_id': entry.vendorId,
          'vendor_name': entry.vendorName,
          'total_outwards': 0,
          'total_quantity': 0.0,
          'materials_summary': <String, double>{},
          'transactions': <Map<String, dynamic>>[],
        };
      }

      final v = vendorMap[entry.vendorId]!;
      v['total_outwards'] = (v['total_outwards'] as int) + 1;
      v['total_quantity'] = (v['total_quantity'] as double) + entry.totalQuantity;

      final matSummary = v['materials_summary'] as Map<String, double>;
      for (final item in entry.items) {
        matSummary[item.materialName] = (matSummary[item.materialName] ?? 0.0) + item.quantity;
      }

      (v['transactions'] as List<Map<String, dynamic>>).add({
        'outward_number': entry.outwardNumber,
        'outward_date': entry.outwardDate,
        'total_items': entry.totalItems,
        'total_quantity': entry.totalQuantity,
        'items': entry.items.map((i) => i.toJson()).toList(),
      });
    }

    return vendorMap.values.toList()
      ..sort((a, b) => (b['total_quantity'] as double).compareTo(a['total_quantity'] as double));
  }

  /// C. Material-wise Report Summary & Breakdown
  static List<Map<String, dynamic>> generateMaterialWiseSummary(List<SubVendorMaterialOutward> entries) {
    final activeEntries = entries.where((e) => e.isActive).toList();
    final Map<String, Map<String, dynamic>> matMap = {};

    for (final entry in activeEntries) {
      for (final item in entry.items) {
        final key = item.materialName.trim();
        if (!matMap.containsKey(key)) {
          matMap[key] = {
            'material_name': item.materialName,
            'unit': item.unit,
            'total_quantity': 0.0,
            'total_outwards': 0,
            'vendor_breakdown': <String, double>{},
            'date_details': <Map<String, dynamic>>[],
          };
        }

        final m = matMap[key]!;
        m['total_quantity'] = (m['total_quantity'] as double) + item.quantity;
        m['total_outwards'] = (m['total_outwards'] as int) + 1;

        final vBreakdown = m['vendor_breakdown'] as Map<String, double>;
        vBreakdown[entry.vendorName] = (vBreakdown[entry.vendorName] ?? 0.0) + item.quantity;

        (m['date_details'] as List<Map<String, dynamic>>).add({
          'outward_number': entry.outwardNumber,
          'outward_date': entry.outwardDate,
          'vendor_name': entry.vendorName,
          'quantity': item.quantity,
          'unit': item.unit,
        });
      }
    }

    return matMap.values.toList()
      ..sort((a, b) => (b['total_quantity'] as double).compareTo(a['total_quantity'] as double));
  }

  // ---------------------------------------------------------------------------
  // HELPER METHODS: LOCAL STOCK EFFECTS & CACHING
  // ---------------------------------------------------------------------------
  static void _applyLocalStockDeduction(List<SubVendorMaterialOutwardItem> items) {
    for (final item in items) {
      final idx = _inMemoryMaterials.indexWhere((m) => m.id == item.materialId || m.itemName.toLowerCase() == item.materialName.toLowerCase());
      if (idx >= 0) {
        final current = _inMemoryMaterials[idx];
        final newStock = (current.availableStock - item.quantity).clamp(0.0, 999999.0);
        _inMemoryMaterials[idx] = current.copyWith(availableStock: double.parse(newStock.toStringAsFixed(2)));
      }
    }
  }

  static void _applyLocalStockRestoration(List<SubVendorMaterialOutwardItem> items) {
    for (final item in items) {
      final idx = _inMemoryMaterials.indexWhere((m) => m.id == item.materialId || m.itemName.toLowerCase() == item.materialName.toLowerCase());
      if (idx >= 0) {
        final current = _inMemoryMaterials[idx];
        final newStock = current.availableStock + item.quantity;
        _inMemoryMaterials[idx] = current.copyWith(availableStock: double.parse(newStock.toStringAsFixed(2)));
      }
    }
  }

  static Future<void> _ensureLocalInitialized() async {
    if (_hasInitializedLocal) return;
    _hasInitializedLocal = true;

    try {
      final prefs = await SharedPreferences.getInstance();

      // Materials
      final matStr = prefs.getString(_localMaterialsKey);
      if (matStr != null && matStr.isNotEmpty) {
        final decoded = jsonDecode(matStr) as List<dynamic>;
        _inMemoryMaterials = decoded.map((e) => MaterialMasterItem.fromJson(e as Map<String, dynamic>)).toList();
      } else {
        _inMemoryMaterials = List.from(_defaultInitialMaterials);
      }

      // Outwards
      final outStr = prefs.getString(_localOutwardsKey);
      if (outStr != null && outStr.isNotEmpty) {
        final decoded = jsonDecode(outStr) as List<dynamic>;
        _inMemoryOutwards = decoded.map((e) => SubVendorMaterialOutward.fromJson(e as Map<String, dynamic>)).toList();
      }

      // Audits
      final auditStr = prefs.getString(_localAuditKey);
      if (auditStr != null && auditStr.isNotEmpty) {
        final decoded = jsonDecode(auditStr) as List<dynamic>;
        _inMemoryAudits = decoded.map((e) => SubVendorMaterialOutwardAudit.fromJson(e as Map<String, dynamic>)).toList();
      }
    } catch (_) {
      _inMemoryMaterials = List.from(_defaultInitialMaterials);
    }
  }

  static Future<void> _saveOutwardsToCache(List<SubVendorMaterialOutward> list) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_localOutwardsKey, jsonEncode(list.map((e) => e.toJson()).toList()));
    } catch (_) {}
  }

  static Future<void> _saveMaterialsToCache(List<MaterialMasterItem> list) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_localMaterialsKey, jsonEncode(list.map((e) => e.toJson()).toList()));
    } catch (_) {}
  }

  static Future<void> _saveAuditsToCache(List<SubVendorMaterialOutwardAudit> list) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_localAuditKey, jsonEncode(list.map((e) => e.toJson()).toList()));
    } catch (_) {}
  }

  /// Default baseline materials if database empty or offline
  static final List<MaterialMasterItem> _defaultInitialMaterials = [
    const MaterialMasterItem(
      id: 'mat-001',
      itemName: 'Solar PV Modules (550Wp TopCon Bifacial)',
      unit: 'NOS',
      category: 'PANEL',
      specification: '550 Watt Mono PERC / TopCon Panel',
      availableStock: 500.0,
      defaultRate: 11500.0,
      displayOrder: 1,
    ),
    const MaterialMasterItem(
      id: 'mat-002',
      itemName: 'Solar Inverter 3.3 kW Dual MPPT',
      unit: 'NOS',
      category: 'INVERTER',
      specification: 'Single Phase On-Grid Inverter',
      availableStock: 25.0,
      defaultRate: 25000.0,
      displayOrder: 2,
    ),
    const MaterialMasterItem(
      id: 'mat-003',
      itemName: 'Solar Inverter 5 kW 3-Phase',
      unit: 'NOS',
      category: 'INVERTER',
      specification: 'Three Phase On-Grid Inverter',
      availableStock: 20.0,
      defaultRate: 38000.0,
      displayOrder: 3,
    ),
    const MaterialMasterItem(
      id: 'mat-004',
      itemName: 'GI Mounting Structure (Tin Shed / RCC Elevated)',
      unit: 'SETS',
      category: 'STRUCTURE',
      specification: 'Standard 3kW Hot Dip Galvanized Structure',
      availableStock: 40.0,
      defaultRate: 14000.0,
      displayOrder: 4,
    ),
    const MaterialMasterItem(
      id: 'mat-005',
      itemName: 'Solar DC Cable 4 sq.mm (Polycab)',
      unit: 'METER',
      category: 'BOS',
      specification: 'UV Resistant Dual Insulated Copper Cable',
      availableStock: 1500.0,
      defaultRate: 42.0,
      displayOrder: 5,
    ),
    const MaterialMasterItem(
      id: 'mat-006',
      itemName: 'Solar AC Cable 4 sq.mm 3-Core Cu',
      unit: 'METER',
      category: 'BOS',
      specification: 'Armoured Copper AC Cable',
      availableStock: 800.0,
      defaultRate: 75.0,
      displayOrder: 6,
    ),
    const MaterialMasterItem(
      id: 'mat-007',
      itemName: 'ACDB & DCDB Distribution Box Set',
      unit: 'SETS',
      category: 'BOS',
      specification: 'IP65 Enclosure with SPD & MCB Protection',
      availableStock: 35.0,
      defaultRate: 3200.0,
      displayOrder: 7,
    ),
    const MaterialMasterItem(
      id: 'mat-008',
      itemName: 'Chemical Earthing Kit (3 Electrodes + Compound)',
      unit: 'SETS',
      category: 'BOS',
      specification: 'Maintenance-free Chemical Gel Earthing System',
      availableStock: 50.0,
      defaultRate: 2800.0,
      displayOrder: 8,
    ),
    const MaterialMasterItem(
      id: 'mat-009',
      itemName: 'Lightning Arrester with Support Mast',
      unit: 'SETS',
      category: 'BOS',
      specification: 'Pure Copper Multi-Point LA Mast with Insulator',
      availableStock: 30.0,
      defaultRate: 2500.0,
      displayOrder: 9,
    ),
    const MaterialMasterItem(
      id: 'mat-010',
      itemName: 'MC4 Connectors (Pair)',
      unit: 'PAIRS',
      category: 'BOS',
      specification: 'IP68 1000V Male/Female Pair',
      availableStock: 300.0,
      defaultRate: 45.0,
      displayOrder: 10,
    ),
  ];

  /// Testing helper: resets in-memory data for deterministic unit test execution
  @visibleForTesting
  static void resetInMemoryDataForTesting() {
    _inMemoryOutwards.clear();
    _inMemoryAudits.clear();
    _inMemoryMaterials = List.from(_defaultInitialMaterials);
    _hasInitializedLocal = true;
  }
}
