import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:siya_shared/siya_shared.dart';
import 'supabase_service.dart';

/// Mobile Database Service handling Sub-Vendor data fetching, site assignments,
/// dynamic material transactions, GST calculations, and financial settlements.
class SubVendorService {
  static SupabaseClient? get _client {
    try {
      return SupabaseService.client;
    } catch (_) {
      return null;
    }
  }

  // ============================================================================
  // 1. SUB-VENDOR PROFILE RESOLUTION
  // ============================================================================

  /// Fetch sub-vendor profile associated with the currently signed-in user
  static Future<SubVendor?> fetchCurrentVendorProfile() async {
    final client = _client;
    if (client == null) return null;
    final user = SupabaseService.currentUser;
    if (user == null) return null;

    try {
      // 1. Try match by auth_user_id
      final response = await client
          .from('sub_vendors')
          .select('*')
          .eq('auth_user_id', user.id)
          .maybeSingle();

      if (response != null) {
        return SubVendor.fromJson(response as Map<String, dynamic>);
      }

      // 2. Fallback: match by email or mobile
      final userEmail = user.email;
      if (userEmail != null && userEmail.trim().isNotEmpty) {
        final byEmail = await client
            .from('sub_vendors')
            .select('*')
            .eq('email', userEmail.trim().toLowerCase())
            .maybeSingle();
        if (byEmail != null) {
          return SubVendor.fromJson(byEmail as Map<String, dynamic>);
        }
      }

      // 3. Fallback: match by profiles.mobile
      final profileRes = await client
          .from('profiles')
          .select('mobile')
          .eq('id', user.id)
          .maybeSingle();
      final mobile = profileRes?['mobile'] as String?;
      if (mobile != null && mobile.trim().isNotEmpty) {
        final byMobile = await client
            .from('sub_vendors')
            .select('*')
            .eq('mobile', mobile.trim())
            .maybeSingle();
        if (byMobile != null) {
          return SubVendor.fromJson(byMobile as Map<String, dynamic>);
        }
      }

      return null;
    } catch (e) {
      debugPrint('Error in SubVendorService.fetchCurrentVendorProfile: $e');
      return null;
    }
  }

  // ============================================================================
  // 2. SITE ASSIGNMENTS
  // ============================================================================

  /// Fetch site assignments for a specific sub-vendor (enforced by RLS)
  static Future<List<VendorSiteAssignment>> fetchAssignments({
    required String vendorId,
    String? status,
  }) async {
    final client = _client;
    if (client == null) return [];
    try {
      var query = client
          .from('vendor_site_assignments')
          .select('*, customer:consumer_records(*)')
          .eq('vendor_id', vendorId);

      if (status != null && status != 'All') {
        query = query.eq('status', status);
      }

      final response = await query.order('assigned_date', ascending: false);
      final List<dynamic> data = response as List<dynamic>;

      return data.map((json) {
        final map = Map<String, dynamic>.from(json as Map);
        if (map['customer'] != null && map['customer'] is Map) {
          final cust = map['customer'] as Map;
          map['customer_name'] = cust['customer_name'];
          map['consumer_number'] = cust['consumer_number'];
          map['village_city'] = cust['village_city'];
          map['district'] = cust['district'];
          map['mobile_number'] = cust['mobile_number'];
        }
        return VendorSiteAssignment.fromJson(map);
      }).toList();
    } catch (e, stack) {
      debugPrint('Error in SubVendorService.fetchAssignments: $e\n$stack');
      return [];
    }
  }

  // ============================================================================
  // 3. DYNAMIC MATERIAL TRANSACTIONS (ISSUES & RETURNS)
  // ============================================================================

  /// Fetch dynamic material transactions for a vendor or specific site
  static Future<List<VendorMaterialTransaction>> fetchVendorMaterials(
    String vendorId, {
    String? assignmentId,
  }) async {
    final client = _client;
    if (client == null) return [];
    try {
      var query = client
          .from('vendor_material_transactions')
          .select('*, customer:consumer_records(customer_name, consumer_number)')
          .eq('vendor_id', vendorId);

      if (assignmentId != null && assignmentId.isNotEmpty) {
        query = query.eq('assignment_id', assignmentId);
      }

      final response = await query.order('transaction_date', ascending: false);
      final List<dynamic> data = response as List<dynamic>;

      return data.map((json) {
        final map = Map<String, dynamic>.from(json as Map);
        if (map['customer'] != null && map['customer'] is Map) {
          final cust = map['customer'] as Map;
          map['customer_name'] = cust['customer_name'];
          map['consumer_number'] = cust['consumer_number'];
        }
        return VendorMaterialTransaction.fromJson(map);
      }).toList();
    } catch (e, stack) {
      debugPrint('Error in SubVendorService.fetchVendorMaterials: $e\n$stack');
      return [];
    }
  }

  // ============================================================================
  // 4. VENDOR PAYOUTS
  // ============================================================================

  /// Fetch vendor payouts/disbursements
  static Future<List<VendorPayout>> fetchVendorPayouts(
    String vendorId, {
    String? assignmentId,
  }) async {
    final client = _client;
    if (client == null) return [];
    try {
      var query = client
          .from('vendor_payouts')
          .select('*')
          .eq('vendor_id', vendorId);

      if (assignmentId != null && assignmentId.isNotEmpty) {
        query = query.eq('assignment_id', assignmentId);
      }

      final response = await query.order('payout_date', ascending: false);
      final List<dynamic> data = response as List<dynamic>;

      return data.map((json) => VendorPayout.fromJson(json as Map<String, dynamic>)).toList();
    } catch (e, stack) {
      debugPrint('Error in SubVendorService.fetchVendorPayouts: $e\n$stack');
      return [];
    }
  }

  // ============================================================================
  // 5. FINANCIAL CALCULATIONS & SUMMARIES
  // ============================================================================

  /// Fetch comprehensive financial summary for a Sub-Vendor
  static Future<VendorFinancialSummary> fetchVendorSummary(String vendorId) async {
    final client = _client;
    SubVendor? vendorObj;
    if (client != null) {
      try {
        final vendor = await client
            .from('sub_vendors')
            .select('*')
            .eq('id', vendorId)
            .maybeSingle();

        vendorObj = vendor != null ? SubVendor.fromJson(vendor as Map<String, dynamic>) : null;
      } catch (e) {
        debugPrint('Error fetching vendor: $e');
      }
    }
    final assignments = await fetchAssignments(vendorId: vendorId);
    final materials = await fetchVendorMaterials(vendorId);
    final payouts = await fetchVendorPayouts(vendorId);

    return VendorFinancialSummary.compute(
      vendorId: vendorId,
      vendorCode: vendorObj?.vendorCode ?? 'VND',
      vendorName: vendorObj?.name ?? 'Vendor',
      assignments: assignments,
      allMaterials: materials,
      allPayouts: payouts,
    );
  }

  /// Update assignment status by Sub-Vendor (e.g. 'In Progress', 'Completed')
  /// Backend RLS ensures sub-vendor can only update if not financial_approved
  static Future<void> updateAssignmentStatus({
    required String assignmentId,
    required String status,
  }) async {
    final client = _client;
    if (client == null) return;
    try {
      final updateData = <String, dynamic>{
        'status': status,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      };
      if (status == 'Completed') {
        updateData['completion_date'] = DateTime.now().toIso8601String().substring(0, 10);
      }

      await client
          .from('vendor_site_assignments')
          .update(updateData)
          .eq('id', assignmentId);
    } catch (e) {
      debugPrint('Error updating assignment status: $e');
      rethrow;
    }
  }
}
