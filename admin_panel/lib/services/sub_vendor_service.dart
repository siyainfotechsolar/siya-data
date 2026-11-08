import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:siya_shared/siya_shared.dart';
import 'supabase_service.dart';

/// Database Service handling all Sub-Vendor operations, site assignments,
/// dynamic material tracking, GST calculations, and financial settlements.
class SubVendorService {
  static SupabaseClient get _client => SupabaseService.client;

  // ============================================================================
  // 1. VENDOR ACCOUNT MANAGEMENT (ADMIN)
  // ============================================================================

  /// Fetch all registered sub-vendors
  static Future<List<SubVendor>> fetchAllVendors() async {
    try {
      final response = await _client
          .from('sub_vendors')
          .select('*')
          .order('name', ascending: true);

      final List<dynamic> data = response as List<dynamic>;
      return data.map((json) => SubVendor.fromJson(json as Map<String, dynamic>)).toList();
    } catch (e, stack) {
      debugPrint('Error in SubVendorService.fetchAllVendors: $e\n$stack');
      rethrow;
    }
  }

  /// Fetch single sub-vendor by ID
  static Future<SubVendor?> fetchVendorById(String id) async {
    try {
      final response = await _client
          .from('sub_vendors')
          .select('*')
          .eq('id', id)
          .maybeSingle();

      if (response == null) return null;
      return SubVendor.fromJson(response as Map<String, dynamic>);
    } catch (e) {
      debugPrint('Error in SubVendorService.fetchVendorById: $e');
      return null;
    }
  }

  /// Fetch sub-vendor profile associated with the currently signed-in user
  static Future<SubVendor?> fetchCurrentVendorProfile() async {
    final user = SupabaseService.currentUser;
    if (user == null) return null;

    try {
      // 1. Try match by auth_user_id
      final response = await _client
          .from('sub_vendors')
          .select('*')
          .eq('auth_user_id', user.id)
          .maybeSingle();

      if (response != null) {
        return SubVendor.fromJson(response as Map<String, dynamic>);
      }

      // 2. Fallback: match by email or mobile
      final profile = await SupabaseService.fetchProfile(user.id);
      final mobile = profile?['mobile'] as String?;
      final email = user.email;

      if (mobile != null && mobile.trim().isNotEmpty) {
        final byMobile = await _client
            .from('sub_vendors')
            .select('*')
            .eq('mobile', mobile.trim())
            .maybeSingle();
        if (byMobile != null) {
          return SubVendor.fromJson(byMobile as Map<String, dynamic>);
        }
      }

      if (email != null && email.trim().isNotEmpty) {
        final byEmail = await _client
            .from('sub_vendors')
            .select('*')
            .eq('email', email.trim().toLowerCase())
            .maybeSingle();
        if (byEmail != null) {
          return SubVendor.fromJson(byEmail as Map<String, dynamic>);
        }
      }

      return null;
    } catch (e) {
      debugPrint('Error in SubVendorService.fetchCurrentVendorProfile: $e');
      return null;
    }
  }

  /// Create a new Sub-Vendor account via Admin RPC
  static Future<String> createVendor({
    required String vendorCode,
    required String name,
    required String mobile,
    required String password,
    String? contactPerson,
    String? email,
    String? address,
    String? panNumber,
    String? gstNumber,
    String? bankName,
    String? accountNumber,
    String? ifscCode,
    String? upiId,
    double defaultRatePerKw = 1000.0,
    String? notes,
  }) async {
    try {
      final effectiveEmail = (email != null && email.trim().isNotEmpty)
          ? email.trim()
          : '${mobile.trim()}@vendor.siyasolar.com';

      // 1. Call admin_create_sub_vendor RPC
      try {
        final rpcResult = await _client.rpc('admin_create_sub_vendor', params: {
          'p_vendor_code': vendorCode.trim().toUpperCase(),
          'p_name': name.trim(),
          'p_mobile': mobile.trim(),
          'p_password': password.trim(),
          'p_contact_person': contactPerson?.trim().isEmpty == true ? null : contactPerson?.trim(),
          'p_email': effectiveEmail,
          'p_address': address?.trim().isEmpty == true ? null : address?.trim(),
          'p_pan_number': panNumber?.trim().isEmpty == true ? null : panNumber?.trim(),
          'p_gst_number': gstNumber?.trim().isEmpty == true ? null : gstNumber?.trim(),
          'p_bank_name': bankName?.trim().isEmpty == true ? null : bankName?.trim(),
          'p_account_number': accountNumber?.trim().isEmpty == true ? null : accountNumber?.trim(),
          'p_ifsc_code': ifscCode?.trim().isEmpty == true ? null : ifscCode?.trim(),
          'p_upi_id': upiId?.trim().isEmpty == true ? null : upiId?.trim(),
          'p_default_rate_per_kw': defaultRatePerKw,
          'p_notes': notes?.trim().isEmpty == true ? null : notes?.trim(),
        });

        return rpcResult.toString();
      } catch (rpcError) {
        final errStr = rpcError.toString();
        if (errStr.contains('already in use') ||
            errStr.contains('already exists') ||
            errStr.contains('Unauthorized') ||
            errStr.contains('Password must be')) {
          rethrow;
        }
        debugPrint('admin_create_sub_vendor RPC unavailable or failed, falling back to direct table insert: $rpcError');
      }

      // 2. Fallback: Direct table insert into sub_vendors
      final newVendor = SubVendor(
        id: '',
        vendorCode: vendorCode.trim().toUpperCase(),
        name: name.trim(),
        contactPerson: contactPerson?.trim(),
        mobile: mobile.trim(),
        email: effectiveEmail,
        address: address?.trim(),
        panNumber: panNumber?.trim(),
        gstNumber: gstNumber?.trim(),
        bankName: bankName?.trim(),
        accountNumber: accountNumber?.trim(),
        ifscCode: ifscCode?.trim(),
        upiId: upiId?.trim(),
        defaultRatePerKw: defaultRatePerKw,
        notes: notes?.trim(),
        createdBy: SupabaseService.currentUser?.id,
      );

      final insertData = newVendor.toJson()..remove('id');
      final res = await _client.from('sub_vendors').insert(insertData).select('id').single();
      return res['id'] as String;
    } catch (e, stack) {
      debugPrint('Error in SubVendorService.createVendor: $e\n$stack');
      rethrow;
    }
  }

  /// Update Sub-Vendor profile
  static Future<void> updateVendor(SubVendor vendor) async {
    try {
      final updateData = vendor.toJson();
      updateData['updated_at'] = DateTime.now().toIso8601String();
      updateData['updated_by'] = SupabaseService.currentUser?.id;

      await _client
          .from('sub_vendors')
          .update(updateData)
          .eq('id', vendor.id);
    } catch (e, stack) {
      debugPrint('Error in SubVendorService.updateVendor: $e\n$stack');
      rethrow;
    }
  }

  /// Toggle vendor account active / inactive / blocked
  static Future<void> toggleVendorStatus(String vendorId, String status) async {
    try {
      // 1. Try RPC
      try {
        await _client.rpc('admin_set_vendor_status', params: {
          'p_vendor_id': vendorId,
          'p_status': status,
        });
        return;
      } catch (rpcError) {
        debugPrint('admin_set_vendor_status RPC failed, using fallback: $rpcError');
      }

      // 2. Fallback direct update
      final isActive = status.toLowerCase() == 'active';
      await _client.from('sub_vendors').update({
        'status': status,
        'is_active': isActive,
        'updated_at': DateTime.now().toIso8601String(),
        'updated_by': SupabaseService.currentUser?.id,
      }).eq('id', vendorId);
    } catch (e, stack) {
      debugPrint('Error in SubVendorService.toggleVendorStatus: $e\n$stack');
      rethrow;
    }
  }

  /// Reset vendor password via Admin RPC
  static Future<void> resetVendorPassword({
    required String authUserId,
    required String newPassword,
  }) async {
    try {
      await _client.rpc('admin_set_user_password', params: {
        'p_target_user_id': authUserId,
        'p_new_password': newPassword.trim(),
      });
    } catch (e, stack) {
      debugPrint('Error in SubVendorService.resetVendorPassword: $e\n$stack');
      rethrow;
    }
  }

  // ============================================================================
  // 2. SITE ASSIGNMENT MANAGEMENT
  // ============================================================================

  /// Fetch site assignments (Optionally filtered by vendorId)
  static Future<List<VendorSiteAssignment>> fetchAssignments({
    String? vendorId,
    String? status,
  }) async {
    try {
      var query = _client.from('vendor_site_assignments').select('''
        *,
        consumer_records!customer_id (
          id,
          consumer_no,
          name,
          mobile,
          address,
          status,
          system_capacity,
          total_amount,
          paid_amount,
          installation_status
        ),
        sub_vendors!vendor_id (
          id,
          vendor_code,
          name,
          mobile
        )
      ''');

      if (vendorId != null && vendorId.isNotEmpty) {
        query = query.eq('vendor_id', vendorId);
      }

      if (status != null && status.isNotEmpty && status != 'All') {
        query = query.eq('status', status);
      }

      final response = await query.order('assigned_date', ascending: false);
      final List<dynamic> data = response as List<dynamic>;

      return data.map((json) {
        return VendorSiteAssignment.fromJson(json as Map<String, dynamic>);
      }).toList();
    } catch (e, stack) {
      debugPrint('Error in SubVendorService.fetchAssignments: $e\n$stack');
      rethrow;
    }
  }

  /// Assign a customer site to a sub-vendor
  static Future<VendorSiteAssignment> assignSiteToVendor({
    required String vendorId,
    required String customerId,
    required double siteCapacityKw,
    double ratePerKw = 1000.0,
    double otherExpenses = 0.0,
    String? expenseRemarks,
    String? notes,
    DateTime? assignedDate,
  }) async {
    try {
      final vendorCharges = double.parse((siteCapacityKw * ratePerKw).toStringAsFixed(2));
      final date = assignedDate ?? DateTime.now();

      final insertData = {
        'vendor_id': vendorId,
        'customer_id': customerId,
        'assigned_date': date.toIso8601String().split('T').first,
        'site_capacity_kw': siteCapacityKw,
        'rate_per_kw': ratePerKw,
        'vendor_charges': vendorCharges,
        'other_expenses': otherExpenses,
        if (expenseRemarks != null) 'expense_remarks': expenseRemarks.trim(),
        'status': 'Assigned',
        if (notes != null) 'notes': notes.trim(),
        'created_by': SupabaseService.currentUser?.id,
      };

      final response = await _client
          .from('vendor_site_assignments')
          .insert(insertData)
          .select('''
            *,
            consumer_records!customer_id (
              id, consumer_no, name, mobile, address, status, system_capacity, total_amount, paid_amount
            ),
            sub_vendors!vendor_id (
              id, vendor_code, name, mobile
            )
          ''')
          .single();

      return VendorSiteAssignment.fromJson(response as Map<String, dynamic>);
    } catch (e, stack) {
      debugPrint('Error in SubVendorService.assignSiteToVendor: $e\n$stack');
      rethrow;
    }
  }

  /// Update assignment status (e.g. 'In Progress', 'Completed', 'Settled')
  static Future<void> updateAssignmentStatus(
    String assignmentId,
    String status, {
    DateTime? completionDate,
    String? notes,
  }) async {
    try {
      final updateData = <String, dynamic>{
        'status': status,
        'updated_at': DateTime.now().toIso8601String(),
        'updated_by': SupabaseService.currentUser?.id,
      };

      if (status.toLowerCase() == 'completed' || completionDate != null) {
        updateData['completion_date'] =
            (completionDate ?? DateTime.now()).toIso8601String().split('T').first;
      }

      if (notes != null) {
        updateData['notes'] = notes.trim();
      }

      await _client
          .from('vendor_site_assignments')
          .update(updateData)
          .eq('id', assignmentId);
    } catch (e, stack) {
      debugPrint('Error in SubVendorService.updateAssignmentStatus: $e\n$stack');
      rethrow;
    }
  }

  /// Approve or unlock financial entries for a site assignment
  static Future<void> approveSiteFinancials(String assignmentId, bool approved) async {
    try {
      final updateData = <String, dynamic>{
        'financial_approved': approved,
        'financial_approved_by': approved ? SupabaseService.currentUser?.id : null,
        'financial_approved_at': approved ? DateTime.now().toIso8601String() : null,
        'updated_at': DateTime.now().toIso8601String(),
        'updated_by': SupabaseService.currentUser?.id,
      };

      await _client
          .from('vendor_site_assignments')
          .update(updateData)
          .eq('id', assignmentId);
    } catch (e, stack) {
      debugPrint('Error in SubVendorService.approveSiteFinancials: $e\n$stack');
      rethrow;
    }
  }

  /// Approve final settlement for a site assignment
  static Future<void> approveSiteSettlement(String assignmentId, bool approved) async {
    try {
      final updateData = <String, dynamic>{
        'settlement_approved': approved,
        'settlement_approved_by': approved ? SupabaseService.currentUser?.id : null,
        'settlement_approved_at': approved ? DateTime.now().toIso8601String() : null,
        if (approved) 'status': 'Settled',
        'updated_at': DateTime.now().toIso8601String(),
        'updated_by': SupabaseService.currentUser?.id,
      };

      await _client
          .from('vendor_site_assignments')
          .update(updateData)
          .eq('id', assignmentId);
    } catch (e, stack) {
      debugPrint('Error in SubVendorService.approveSiteSettlement: $e\n$stack');
      rethrow;
    }
  }

  // ============================================================================
  // 3. DYNAMIC MATERIAL ISSUES & RETURNS (WITH 5% & 18% GST)
  // ============================================================================

  /// Fetch all material transactions for a specific site assignment
  static Future<List<VendorMaterialTransaction>> fetchSiteMaterials(String assignmentId) async {
    try {
      final response = await _client
          .from('vendor_material_transactions')
          .select('*')
          .eq('assignment_id', assignmentId)
          .order('transaction_date', ascending: true);

      final List<dynamic> data = response as List<dynamic>;
      return data
          .map((json) => VendorMaterialTransaction.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e, stack) {
      debugPrint('Error in SubVendorService.fetchSiteMaterials: $e\n$stack');
      rethrow;
    }
  }

  /// Fetch all material transactions for a vendor across all their sites
  static Future<List<VendorMaterialTransaction>> fetchVendorMaterials(String vendorId) async {
    try {
      final response = await _client
          .from('vendor_material_transactions')
          .select('*')
          .eq('vendor_id', vendorId)
          .order('transaction_date', ascending: false);

      final List<dynamic> data = response as List<dynamic>;
      return data
          .map((json) => VendorMaterialTransaction.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e, stack) {
      debugPrint('Error in SubVendorService.fetchVendorMaterials: $e\n$stack');
      rethrow;
    }
  }

  /// Record a material issue or return
  static Future<VendorMaterialTransaction> recordMaterialTransaction(
    VendorMaterialTransaction tx,
  ) async {
    try {
      final insertData = tx.toJson()..remove('id');
      insertData['created_by'] = SupabaseService.currentUser?.id;

      final response = await _client
          .from('vendor_material_transactions')
          .insert(insertData)
          .select()
          .single();

      return VendorMaterialTransaction.fromJson(response as Map<String, dynamic>);
    } catch (e, stack) {
      debugPrint('Error in SubVendorService.recordMaterialTransaction: $e\n$stack');
      rethrow;
    }
  }

  /// Delete a material transaction (if not locked by approval)
  static Future<void> deleteMaterialTransaction(String txId) async {
    try {
      await _client
          .from('vendor_material_transactions')
          .delete()
          .eq('id', txId);
    } catch (e, stack) {
      debugPrint('Error in SubVendorService.deleteMaterialTransaction: $e\n$stack');
      rethrow;
    }
  }

  // ============================================================================
  // 4. VENDOR PAYOUTS & DISBURSEMENTS
  // ============================================================================

  /// Fetch payouts for a vendor
  static Future<List<VendorPayout>> fetchVendorPayouts(String vendorId) async {
    try {
      final response = await _client
          .from('vendor_payouts')
          .select('''
            *,
            vendor_site_assignments!assignment_id (
              consumer_records!customer_id (
                consumer_no,
                name
              )
            )
          ''')
          .eq('vendor_id', vendorId)
          .order('payout_date', ascending: false);

      final List<dynamic> data = response as List<dynamic>;
      return data.map((json) {
        final map = Map<String, dynamic>.from(json as Map);
        final assignment = map['vendor_site_assignments'] as Map<String, dynamic>?;
        final customer = assignment?['consumer_records'] as Map<String, dynamic>?;
        if (customer != null) {
          map['consumer_no'] = customer['consumer_no'];
          map['customer_name'] = customer['name'];
        }
        return VendorPayout.fromJson(map);
      }).toList();
    } catch (e, stack) {
      debugPrint('Error in SubVendorService.fetchVendorPayouts: $e\n$stack');
      rethrow;
    }
  }

  /// Record a payout disbursement to a sub-vendor
  static Future<VendorPayout> recordVendorPayout(VendorPayout payout) async {
    try {
      final insertData = payout.toJson()..remove('id');
      insertData['created_by'] = SupabaseService.currentUser?.id;

      final response = await _client
          .from('vendor_payouts')
          .insert(insertData)
          .select()
          .single();

      return VendorPayout.fromJson(response as Map<String, dynamic>);
    } catch (e, stack) {
      debugPrint('Error in SubVendorService.recordVendorPayout: $e\n$stack');
      rethrow;
    }
  }

  // ============================================================================
  // 5. FINANCIAL CALCULATIONS & SUMMARY ENGINE
  // ============================================================================

  /// Calculates dynamic financial details for a single site assignment
  static Future<SiteFinancialDetail> getSiteFinancialDetail(
    VendorSiteAssignment assignment,
  ) async {
    try {
      final materials = await fetchSiteMaterials(assignment.id);
      final payouts = await fetchVendorPayouts(assignment.vendorId);
      return SiteFinancialDetail.compute(
        assignment: assignment,
        materials: materials,
        payouts: payouts.where((p) => p.assignmentId == assignment.id).toList(),
      );
    } catch (e, stack) {
      debugPrint('Error in SubVendorService.getSiteFinancialDetail: $e\n$stack');
      rethrow;
    }
  }

  /// Calculates full financial summary for a sub-vendor
  static Future<VendorFinancialSummary> getVendorFinancialSummary(String vendorId) async {
    try {
      final vendor = await fetchVendorById(vendorId);
      final assignments = await fetchAssignments(vendorId: vendorId);
      final materials = await fetchVendorMaterials(vendorId);
      final payouts = await fetchVendorPayouts(vendorId);

      return VendorFinancialSummary.compute(
        vendorId: vendorId,
        vendorCode: vendor?.vendorCode ?? 'VND',
        vendorName: vendor?.name ?? 'Sub-Vendor',
        assignments: assignments,
        allMaterials: materials,
        allPayouts: payouts,
      );
    } catch (e, stack) {
      debugPrint('Error in SubVendorService.getVendorFinancialSummary: $e\n$stack');
      rethrow;
    }
  }

  // ============================================================================
  // 6. CUSTOMER PAYMENT & BANK LOAN DISBURSEMENT TRACKING
  // ============================================================================

  /// Fetch customer payment transactions (Cash / Bank Loan credits)
  static Future<List<VendorCustomerPayment>> fetchCustomerPayments({
    String? assignmentId,
    String? vendorId,
    String? customerId,
    String? paymentType,
  }) async {
    try {
      var query = _client.from('vendor_customer_payments').select('''
        *,
        consumer_records!customer_id (
          id,
          consumer_no,
          name,
          mobile,
          address
        ),
        sub_vendors!vendor_id (
          id,
          vendor_code,
          name,
          mobile
        )
      ''');

      if (assignmentId != null && assignmentId.isNotEmpty) {
        query = query.eq('assignment_id', assignmentId);
      }
      if (vendorId != null && vendorId.isNotEmpty) {
        query = query.eq('vendor_id', vendorId);
      }
      if (customerId != null && customerId.isNotEmpty) {
        query = query.eq('customer_id', customerId);
      }
      if (paymentType != null && paymentType.isNotEmpty && paymentType != 'All') {
        query = query.eq('payment_type', paymentType.toUpperCase());
      }

      final response = await query.order('payment_date', ascending: false);
      final List<dynamic> data = response as List<dynamic>;

      return data.map((json) {
        return VendorCustomerPayment.fromJson(json as Map<String, dynamic>);
      }).toList();
    } catch (e, stack) {
      debugPrint('Error in SubVendorService.fetchCustomerPayments: $e\n$stack');
      return [];
    }
  }

  /// Check if reference number (UTR/Txn ID) already exists for this site assignment
  static Future<bool> checkDuplicateUtr({
    required String assignmentId,
    required String referenceNumber,
    String? excludePaymentId,
  }) async {
    final cleanRef = referenceNumber.trim();
    if (cleanRef.isEmpty) return false;

    try {
      var query = _client
          .from('vendor_customer_payments')
          .select('id')
          .eq('assignment_id', assignmentId)
          .eq('reference_number', cleanRef);

      if (excludePaymentId != null && excludePaymentId.isNotEmpty) {
        query = query.neq('id', excludePaymentId);
      }

      final response = await query;
      final List<dynamic> list = response as List<dynamic>;
      return list.isNotEmpty;
    } catch (e) {
      debugPrint('Error in SubVendorService.checkDuplicateUtr: $e');
      return false;
    }
  }

  /// Record a customer payment (Cash installment or Bank Loan credit)
  static Future<VendorCustomerPayment> recordCustomerPayment(
    VendorCustomerPayment payment,
  ) async {
    try {
      // Check duplicate UTR if present
      if (payment.referenceNumber != null && payment.referenceNumber!.trim().isNotEmpty) {
        final isDup = await checkDuplicateUtr(
          assignmentId: payment.assignmentId,
          referenceNumber: payment.referenceNumber!,
        );
        if (isDup) {
          throw Exception('Duplicate Transaction/UTR number "${payment.referenceNumber}" already exists for this site!');
        }
      }

      final insertData = payment.toJson()..remove('id');
      insertData['created_by'] = SupabaseService.currentUser?.id;
      insertData['created_at'] = DateTime.now().toUtc().toIso8601String();
      if (payment.status == 'Approved') {
        insertData['approved_by'] = SupabaseService.currentUser?.id;
        insertData['approved_at'] = DateTime.now().toUtc().toIso8601String();
      }

      final response = await _client
          .from('vendor_customer_payments')
          .insert(insertData)
          .select()
          .single();

      return VendorCustomerPayment.fromJson(response as Map<String, dynamic>);
    } catch (e, stack) {
      debugPrint('Error in SubVendorService.recordCustomerPayment: $e\n$stack');
      rethrow;
    }
  }

  /// Delete customer payment record (Admin only)
  static Future<void> deleteCustomerPayment(String paymentId) async {
    try {
      await _client
          .from('vendor_customer_payments')
          .delete()
          .eq('id', paymentId);
    } catch (e, stack) {
      debugPrint('Error in SubVendorService.deleteCustomerPayment: $e\n$stack');
      rethrow;
    }
  }

  /// Update Site Payment & Loan Configuration (Payment Type, Sanction Amount, Bank, etc.)
  static Future<void> updateSitePaymentConfig({
    required String assignmentId,
    required String paymentType,
    required double totalCustomerSiteAmount,
    String? loanBankName,
    String? loanApplicationId,
    double? loanAppliedAmount,
    double? loanSanctionedAmount,
  }) async {
    try {
      final updateData = <String, dynamic>{
        'payment_type': paymentType,
        'total_customer_site_amount': totalCustomerSiteAmount,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
        'updated_by': SupabaseService.currentUser?.id,
      };

      if (loanBankName != null) updateData['loan_bank_name'] = loanBankName.trim();
      if (loanApplicationId != null) updateData['loan_application_id'] = loanApplicationId.trim();
      if (loanAppliedAmount != null) updateData['loan_applied_amount'] = loanAppliedAmount;
      if (loanSanctionedAmount != null) updateData['loan_sanctioned_amount'] = loanSanctionedAmount;

      await _client
          .from('vendor_site_assignments')
          .update(updateData)
          .eq('id', assignmentId);
    } catch (e, stack) {
      debugPrint('Error in SubVendorService.updateSitePaymentConfig: $e\n$stack');
      rethrow;
    }
  }

  // ============================================================================
  // 7. SUB-VENDOR FINAL SETTLEMENT & PAYOUT CALCULATOR
  // ============================================================================

  /// Calculates dynamic final settlement for a site assignment
  static Future<SubVendorSettlement> calculateSiteSettlement({
    required VendorSiteAssignment assignment,
    SubVendorSettlementMode settlementMode = SubVendorSettlementMode.netBalance,
    double expectedLoanPercent = 90.0,
    double outputGstRate = 13.8,
    double fixedAgreedFee = 0.0,
    double vendorProfitSharePercent = 70.0,
    double approvedAdjustments = 0.0,
    String? adjustmentRemarks,
  }) async {
    try {
      final materials = await fetchSiteMaterials(assignment.id);
      final payouts = await fetchVendorPayouts(assignment.vendorId);
      final payments = await fetchCustomerPayments(assignmentId: assignment.id);

      return SubVendorSettlement.compute(
        assignment: assignment,
        materials: materials,
        previousPayouts: payouts.where((p) => p.assignmentId == assignment.id).toList(),
        customerPayments: payments,
        settlementMode: settlementMode,
        expectedLoanPercent: expectedLoanPercent,
        outputGstRate: outputGstRate,
        fixedAgreedFee: fixedAgreedFee,
        vendorProfitSharePercent: vendorProfitSharePercent,
        approvedAdjustments: approvedAdjustments,
        adjustmentRemarks: adjustmentRemarks,
      );
    } catch (e, stack) {
      debugPrint('Error in SubVendorService.calculateSiteSettlement: $e\n$stack');
      rethrow;
    }
  }

  /// Fetch saved settlement from database if exists
  static Future<SubVendorSettlement?> fetchSavedSettlement(String assignmentId) async {
    try {
      final res = await _client
          .from('vendor_settlements')
          .select('*')
          .eq('assignment_id', assignmentId)
          .maybeSingle();

      if (res == null) return null;
      return SubVendorSettlement.fromJson(res as Map<String, dynamic>);
    } catch (e) {
      debugPrint('SubVendorService.fetchSavedSettlement: $e');
      return null;
    }
  }

  /// Save or Approve a final settlement record
  static Future<SubVendorSettlement> saveOrApproveSettlement(
    SubVendorSettlement settlement, {
    bool approve = false,
  }) async {
    try {
      final data = settlement.toJson();
      data.remove('id');
      data['updated_at'] = DateTime.now().toUtc().toIso8601String();
      data['created_by'] = SupabaseService.currentUser?.id;

      if (approve) {
        data['status'] = 'Approved';
        data['is_approved'] = true;
        data['approved_by'] = SupabaseService.currentUser?.id;
        data['approved_at'] = DateTime.now().toUtc().toIso8601String();
      }

      // Upsert using unique constraint on assignment_id
      final res = await _client
          .from('vendor_settlements')
          .upsert(data, onConflict: 'assignment_id')
          .select()
          .single();

      // If approved, update assignment settlement flag
      if (approve) {
        await approveSiteSettlement(settlement.assignmentId, true);
      }

      return SubVendorSettlement.fromJson(res as Map<String, dynamic>);
    } catch (e, stack) {
      debugPrint('Error in SubVendorService.saveOrApproveSettlement: $e\n$stack');
      rethrow;
    }
  }
}

