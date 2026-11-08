import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:siya_shared/siya_shared.dart';
import 'supabase_service.dart';

/// Service managing SIYA SOLAR SITE COST CALCULATOR records, material master, and persistence.
class SolarSiteCostService {
  static const String _tableName = 'solar_site_cost_calculations';
  static const String _masterTableName = 'solar_cost_material_master';
  static const String _localCacheKey = 'cached_solar_site_cost_calculations';

  // ---------------------------------------------------------------------------
  // 1. Fetch Calculations
  // ---------------------------------------------------------------------------
  static Future<List<SolarSiteCostCalculation>> fetchCalculations() async {
    try {
      final client = SupabaseService.client;
      final res = await client
          .from(_tableName)
          .select()
          .order('calculation_date', ascending: false)
          .order('created_at', ascending: false);

      final list = (res as List<dynamic>)
          .map((row) => SolarSiteCostCalculation.fromJson(row as Map<String, dynamic>))
          .toList();

      // Update local cache
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_localCacheKey, jsonEncode(list.map((e) => e.toJson()).toList()));
      } catch (_) {}

      return list;
    } catch (e) {
      debugPrint('Warning: Could not fetch calculations from Supabase: $e. Using local cache.');
      return _loadFromLocalCache();
    }
  }

  static Future<List<SolarSiteCostCalculation>> _loadFromLocalCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final str = prefs.getString(_localCacheKey);
      if (str != null && str.isNotEmpty) {
        final decoded = jsonDecode(str) as List<dynamic>;
        return decoded
            .map((e) => SolarSiteCostCalculation.fromJson(e as Map<String, dynamic>))
            .toList();
      }
    } catch (_) {}
    return [SolarSiteCostCalculation.createSampleTestCalculation()];
  }

  // ---------------------------------------------------------------------------
  // 2. Save Calculation (Create or Update)
  // ---------------------------------------------------------------------------
  static Future<SolarSiteCostCalculation> saveCalculation(SolarSiteCostCalculation calc) async {
    final client = SupabaseService.client;
    final currentUser = SupabaseService.currentUser;

    // Generate calculation number if not present
    var calcNumber = calc.calculationNumber;
    if (calcNumber.isEmpty || calcNumber == 'SCC-TEST-SAMPLE') {
      final now = DateTime.now();
      final timestamp = now.millisecondsSinceEpoch.toString().substring(7);
      calcNumber = 'SCC-${now.year}-$timestamp';
    }

    final data = calc.copyWith(
      calculationNumber: calcNumber,
      createdBy: currentUser?.id ?? calc.createdBy,
      updatedAt: DateTime.now(),
    );

    try {
      if (data.id != null && data.id!.isNotEmpty && data.id != 'sample-id') {
        // Update existing
        final res = await client
            .from(_tableName)
            .update(data.toJson())
            .eq('id', data.id!)
            .select()
            .single();
        return SolarSiteCostCalculation.fromJson(res);
      } else {
        // Insert new
        final payload = data.toJson();
        payload.remove('id'); // let Postgres generate uuid
        final res = await client
            .from(_tableName)
            .insert(payload)
            .select()
            .single();
        return SolarSiteCostCalculation.fromJson(res);
      }
    } catch (e) {
      debugPrint('Failed to save calculation to Supabase: $e');
      // Update local cache fallback
      final existing = await _loadFromLocalCache();
      final updatedList = <SolarSiteCostCalculation>[];
      bool found = false;
      for (final item in existing) {
        if (item.id != null && item.id == data.id) {
          updatedList.add(data);
          found = true;
        } else {
          updatedList.add(item);
        }
      }
      if (!found) {
        updatedList.insert(0, data);
      }
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_localCacheKey, jsonEncode(updatedList.map((e) => e.toJson()).toList()));
      } catch (_) {}
      return data;
    }
  }

  // ---------------------------------------------------------------------------
  // 3. Delete Calculation
  // ---------------------------------------------------------------------------
  static Future<void> deleteCalculation(String id) async {
    try {
      final client = SupabaseService.client;
      await client.from(_tableName).delete().eq('id', id);
    } catch (e) {
      debugPrint('Warning: Could not delete calculation from Supabase: $e');
    }
    // Delete from local cache
    try {
      final existing = await _loadFromLocalCache();
      existing.removeWhere((item) => item.id == id);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_localCacheKey, jsonEncode(existing.map((e) => e.toJson()).toList()));
    } catch (_) {}
  }

  // ---------------------------------------------------------------------------
  // 4. Duplicate Calculation
  // ---------------------------------------------------------------------------
  static Future<SolarSiteCostCalculation> duplicateCalculation(SolarSiteCostCalculation original) async {
    final now = DateTime.now();
    final timestamp = now.millisecondsSinceEpoch.toString().substring(7);
    final newNumber = 'SCC-${now.year}-$timestamp';

    final duplicated = original.copyWith(
      id: null,
      calculationNumber: newNumber,
      siteName: '${original.siteName} (Copy)',
      customerName: original.customerName,
      calculationDate: now,
      createdAt: now,
      updatedAt: now,
    );

    return saveCalculation(duplicated);
  }

  // ---------------------------------------------------------------------------
  // 5. Material Master Management
  // ---------------------------------------------------------------------------
  static Future<List<Map<String, dynamic>>> fetchMaterialMaster() async {
    try {
      final client = SupabaseService.client;
      final res = await client
          .from(_masterTableName)
          .select()
          .eq('is_active', true)
          .order('display_order', ascending: true);
      return (res as List<dynamic>).map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (e) {
      debugPrint('Warning: Could not fetch material master from Supabase: $e');
      return _defaultMaterialMasterFallback;
    }
  }

  static Future<void> saveMaterialMasterItem(Map<String, dynamic> item) async {
    final client = SupabaseService.client;
    final id = item['id'];
    if (id != null && id.toString().isNotEmpty) {
      await client.from(_masterTableName).update(item).eq('id', id);
    } else {
      item.remove('id');
      await client.from(_masterTableName).insert(item);
    }
  }

  // Fallback default master
  static const List<Map<String, dynamic>> _defaultMaterialMasterFallback = [
    {
      'category': 'GI_PIPE',
      'item_name': 'GI Pipe 40x40 mm',
      'specification': '40x40 mm Sq. Pipe (1.6mm Thk, 20 Ft)',
      'unit': 'KG',
      'default_rate': 85.0,
      'default_weight_per_unit': 8.0,
      'default_length_feet': 20.0,
    },
    {
      'category': 'GI_PIPE',
      'item_name': 'GI Pipe 80x40 mm',
      'specification': '80x40 mm Rect. Pipe (2.0mm Thk, 20 Ft)',
      'unit': 'KG',
      'default_rate': 90.0,
      'default_weight_per_unit': 12.0,
      'default_length_feet': 20.0,
    },
    {
      'category': 'GI_PIPE',
      'item_name': 'GI Pipe 40x20 mm',
      'specification': '40x20 mm Rect. Pipe (1.6mm Thk, 20 Ft)',
      'unit': 'KG',
      'default_rate': 80.0,
      'default_weight_per_unit': 6.0,
      'default_length_feet': 20.0,
    },
    {
      'category': 'GI_PIPE',
      'item_name': 'GI Pipe 50x50 mm',
      'specification': '50x50 mm Sq. Pipe (2.0mm Thk, 20 Ft)',
      'unit': 'KG',
      'default_rate': 88.0,
      'default_weight_per_unit': 10.0,
      'default_length_feet': 20.0,
    },
    {
      'category': 'PANEL',
      'item_name': 'Mono PERC 550W',
      'specification': '550W Mono PERC Panel',
      'unit': 'WATT',
      'default_rate': 18.0,
    },
    {
      'category': 'INVERTER',
      'item_name': '3.3 kW On-Grid Inverter',
      'specification': 'Single Phase Dual MPPT',
      'unit': 'FIXED',
      'default_rate': 25000.0,
    },
    {
      'category': 'BOS',
      'item_name': 'ACDB',
      'specification': 'AC Distribution Box',
      'unit': 'FIXED',
      'default_rate': 2500.0,
    },
    {
      'category': 'BOS',
      'item_name': 'DCDB',
      'specification': 'DC Distribution Box',
      'unit': 'FIXED',
      'default_rate': 2200.0,
    },
    {
      'category': 'BOS',
      'item_name': 'DC Cable',
      'specification': '4 sq mm DC Solar Cable',
      'unit': 'FIXED',
      'default_rate': 1750.0,
    },
    {
      'category': 'BOS',
      'item_name': 'AC Cable',
      'specification': '3-Core AC Cable',
      'unit': 'FIXED',
      'default_rate': 1950.0,
    },
    {
      'category': 'BOS',
      'item_name': 'Earthing Kit',
      'specification': 'Earthing Electrode + Chemical Set',
      'unit': 'FIXED',
      'default_rate': 3500.0,
    },
    {
      'category': 'BOS',
      'item_name': 'MC4 Connector',
      'specification': 'MC4 Connector Pair',
      'unit': 'FIXED',
      'default_rate': 500.0,
    },
    {
      'category': 'LABOUR',
      'item_name': 'Wiring Labour',
      'specification': 'Cable Wiring & Termination',
      'unit': 'FIXED',
      'default_rate': 6000.0,
    },
    {
      'category': 'LABOUR',
      'item_name': 'Structure Labour',
      'specification': 'Structure Installation',
      'unit': 'FIXED',
      'default_rate': 7000.0,
    },
    {
      'category': 'LABOUR',
      'item_name': 'Civil Labour',
      'specification': 'Civil Concrete Foundation Work',
      'unit': 'FIXED',
      'default_rate': 5500.0,
    },
    {
      'category': 'EXPENSE',
      'item_name': 'Transportation',
      'specification': 'Freight & Transport',
      'unit': 'FIXED',
      'default_rate': 3000.0,
    },
    {
      'category': 'EXPENSE',
      'item_name': 'Loading / Unloading',
      'specification': 'Material Loading / Unloading',
      'unit': 'FIXED',
      'default_rate': 500.0,
    },
    {
      'category': 'EXPENSE',
      'item_name': 'Other Expenses',
      'specification': 'Site Contingency',
      'unit': 'FIXED',
      'default_rate': 1000.0,
    },
  ];
}
