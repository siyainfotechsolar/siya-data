import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/customer_payment.dart';
import '../models/consumer_record.dart';
import 'supabase_service.dart';
import 'activity_log_service.dart';
import 'excel_export_service.dart';

class AdminPaymentService {
  static SupabaseClient get _client => SupabaseService.client;

  /// Fetch executive dashboard KPI metrics for the Admin Payment Module
  static Future<AdminPaymentMetrics> fetchDashboardMetrics() async {
    try {
      // 1. Fetch transactions for calculation
      final txRes = await _client
          .from('customer_payment_transactions')
          .select('amount, payment_date, status, verification_status, sync_status, payment_type, additional_category');

      final txList = txRes as List;
      final now = DateTime.now();
      final todayStr = now.toIso8601String().split('T')[0];
      final currentMonth = now.month;
      final currentYear = now.year;

      double contractCollection = 0;
      double additionalCollection = 0;
      double totalCollection = 0;
      double todayCollection = 0;
      double monthCollection = 0;
      int pendingVerification = 0;
      int pendingSync = 0;
      int todayCount = 0;

      for (final row in txList) {
        final map = row as Map<String, dynamic>;
        final status = map['status']?.toString() ?? 'Valid';
        final vStatus = map['verification_status']?.toString() ?? 'Pending';
        final syncStatus = map['sync_status']?.toString() ?? 'Synced';
        final dateStr = map['payment_date']?.toString() ?? '';
        final pType = map['payment_type']?.toString() ?? PaymentType.contract;
        final amount = (map['amount'] is num)
            ? (map['amount'] as num).toDouble()
            : double.tryParse(map['amount']?.toString() ?? '0') ?? 0.0;

        if (status == 'Valid' && vStatus != 'Rejected' && vStatus != 'Void') {
          totalCollection += amount;
          if (pType.toUpperCase() == 'ADDITIONAL') {
            additionalCollection += amount;
          } else {
            contractCollection += amount;
          }

          if (dateStr == todayStr) {
            todayCollection += amount;
            todayCount++;
          }

          if (dateStr.isNotEmpty) {
            final dt = DateTime.tryParse(dateStr);
            if (dt != null && dt.month == currentMonth && dt.year == currentYear) {
              monthCollection += amount;
            }
          }
        }

        if (vStatus == 'Pending') {
          pendingVerification++;
        }

        if (syncStatus != 'Synced') {
          pendingSync++;
        }
      }

      // 2. Fetch total outstanding from active consumer records
      double totalOutstanding = 0;
      int followupCount = 0;
      try {
        final recRes = await _client
            .from('consumer_records')
            .select('pending_amount, has_active_followup, is_hold, customer_work_state')
            .eq('deleted', false)
            .eq('is_merged', false);

        for (final r in recRes as List) {
          final m = r as Map<String, dynamic>;
          final state = m['customer_work_state']?.toString();
          if (state != 'COMPLETED') {
            final pend = (m['pending_amount'] is num)
                ? (m['pending_amount'] as num).toDouble()
                : double.tryParse(m['pending_amount']?.toString() ?? '0') ?? 0.0;
            totalOutstanding += pend;
          }

          if (m['has_active_followup'] == true) {
            followupCount++;
          }
        }
      } catch (e) {
        debugPrint('Error fetching outstanding: $e');
      }

      return AdminPaymentMetrics(
        contractCollection: contractCollection,
        additionalCollection: additionalCollection,
        totalCollection: totalCollection,
        todayCollection: todayCollection,
        monthCollection: monthCollection,
        totalOutstanding: totalOutstanding,
        pendingVerificationCount: pendingVerification,
        pendingSyncCount: pendingSync,
        followUpCount: followupCount,
        todayPaymentsCount: todayCount,
        totalTransactionsCount: txList.length,
      );
    } catch (e) {
      debugPrint('AdminPaymentService.fetchDashboardMetrics error: $e');
      return AdminPaymentMetrics.empty();
    }
  }

  /// Fetch payments with comprehensive Admin filters and Customer metadata
  static Future<List<PaymentTransaction>> fetchPayments({
    String? searchQuery,
    String dateFilter = 'All', // 'All', 'Today', 'This Week', 'This Month'
    DateTime? startDate,
    DateTime? endDate,
    String paymentType = 'All', // 'All', 'CONTRACT', 'ADDITIONAL'
    String additionalCategory = 'All', // 'All', 'EXTRA_MATERIAL', etc.
    String paymentMode = 'All', // 'All', 'UPI', 'Cash', 'Bank Transfer', etc.
    String verificationStatus = 'All', // 'All', 'Pending', 'Verified', 'Rejected', 'Void'
    String syncStatus = 'All', // 'All', 'Synced', 'Pending', 'Local', 'Failed'
    String? villageFilter,
    String? staffFilter,
    int limit = 200,
  }) async {
    try {
      // Query payment transactions with joined consumer_records
      var query = _client.from('customer_payment_transactions').select('''
        *,
        customer:consumer_records!customer_payment_transactions_customer_id_fkey(
          customer_name,
          village,
          mobile_number,
          current_stage,
          total_amount,
          paid_amount,
          pending_amount
        )
      ''');

      // Date filtering
      final now = DateTime.now();
      if (dateFilter == 'Today') {
        final today = now.toIso8601String().split('T')[0];
        query = query.eq('payment_date', today);
      } else if (dateFilter == 'This Week') {
        final weekAgo = now.subtract(const Duration(days: 7)).toIso8601String().split('T')[0];
        query = query.gte('payment_date', weekAgo);
      } else if (dateFilter == 'This Month') {
        final monthStart = DateTime(now.year, now.month, 1).toIso8601String().split('T')[0];
        query = query.gte('payment_date', monthStart);
      } else if (startDate != null && endDate != null) {
        query = query
            .gte('payment_date', startDate.toIso8601String().split('T')[0])
            .lte('payment_date', endDate.toIso8601String().split('T')[0]);
      }

      // Payment Type filter
      if (paymentType != 'All') {
        query = query.eq('payment_type', paymentType);
      }

      // Additional Category filter
      if (additionalCategory != 'All') {
        query = query.eq('additional_category', additionalCategory);
      }

      // Payment Mode filter
      if (paymentMode != 'All') {
        query = query.eq('payment_mode', paymentMode);
      }

      // Verification Status filter
      if (verificationStatus != 'All') {
        query = query.eq('verification_status', verificationStatus);
      }

      // Sync Status filter
      if (syncStatus != 'All') {
        query = query.eq('sync_status', syncStatus);
      }

      // Staff filter
      if (staffFilter != null && staffFilter.isNotEmpty && staffFilter != 'All') {
        query = query.or('created_by_name.ilike.%$staffFilter%,received_by.ilike.%$staffFilter%');
      }

      final res = await query.order('payment_date', ascending: false).limit(limit);

      final List<PaymentTransaction> results = [];
      for (final item in (res as List)) {
        final map = Map<String, dynamic>.from(item as Map);
        // Extract customer metadata
        if (map['customer'] is Map) {
          final cust = map['customer'] as Map;
          map['customer_name'] = cust['customer_name'];
          map['village'] = cust['village'];
          map['mobile_number'] = cust['mobile_number'];
        }
        results.add(PaymentTransaction.fromJson(map));
      }

      // Client-side search filtering if provided (matches customer, consumer no, mobile, payment ID, reference)
      if (searchQuery != null && searchQuery.trim().isNotEmpty) {
        final q = searchQuery.toLowerCase().trim();
        return results.where((tx) {
          final nameMatch = (tx.customerName ?? '').toLowerCase().contains(q);
          final cNoMatch = tx.consumerNo.toLowerCase().contains(q);
          final mobileMatch = (tx.mobileNumber ?? '').toLowerCase().contains(q);
          final idMatch = (tx.id ?? '').toLowerCase().contains(q);
          final refMatch = (tx.referenceNumber ?? '').toLowerCase().contains(q);
          final villageMatch = (tx.village ?? '').toLowerCase().contains(q);
          return nameMatch || cNoMatch || mobileMatch || idMatch || refMatch || villageMatch;
        }).toList();
      }

      // Village filtering
      if (villageFilter != null && villageFilter.isNotEmpty && villageFilter != 'All') {
        return results.where((tx) => (tx.village ?? '').toLowerCase() == villageFilter.toLowerCase()).toList();
      }

      return results;
    } catch (e) {
      debugPrint('AdminPaymentService.fetchPayments error: $e');
      return [];
    }
  }

  /// Verify Payment Transaction
  static Future<bool> verifyPayment({
    required String paymentId,
    required String adminId,
    required String adminName,
    String? remarks,
  }) async {
    try {
      final now = DateTime.now().toIso8601String();
      await _client.from('customer_payment_transactions').update({
        'verification_status': PaymentVerificationStatus.verified,
        'verified_by': adminId,
        'verified_by_name': adminName,
        'verified_at': now,
        'verification_remarks': remarks ?? 'Verified by Admin',
        'updated_at': now,
      }).eq('id', paymentId);

      // Log Audit Trail
      await ActivityLogService.logActivity(
        consumerNo: paymentId,
        customerName: 'Payment Verification',
        module: 'Payment Module',
        action: 'VERIFIED',
        oldValue: 'Pending',
        newValue: 'Verified',
        remarks: remarks ?? 'Payment verified by $adminName',
      );

      return true;
    } catch (e) {
      debugPrint('AdminPaymentService.verifyPayment error: $e');
      return false;
    }
  }

  /// Reject Payment Transaction (requires mandatory reason)
  static Future<bool> rejectPayment({
    required String paymentId,
    required String adminId,
    required String adminName,
    required String reason,
  }) async {
    if (reason.trim().isEmpty) {
      throw ArgumentError('Mandatory reason is required to reject a payment transaction.');
    }

    try {
      final now = DateTime.now().toIso8601String();
      await _client.from('customer_payment_transactions').update({
        'verification_status': PaymentVerificationStatus.rejected,
        'verified_by': adminId,
        'verified_by_name': adminName,
        'verified_at': now,
        'verification_remarks': reason,
        'reversal_reason': reason,
        'updated_at': now,
      }).eq('id', paymentId);

      // Log Audit Trail
      await ActivityLogService.logActivity(
        consumerNo: paymentId,
        customerName: 'Payment Rejection',
        module: 'Payment Module',
        action: 'REJECTED',
        oldValue: 'Pending',
        newValue: 'Rejected',
        remarks: 'Reason: $reason (by $adminName)',
      );

      return true;
    } catch (e) {
      debugPrint('AdminPaymentService.rejectPayment error: $e');
      return false;
    }
  }

  /// Void Payment Transaction (Non-destructive: financial record is preserved in ledger)
  static Future<bool> voidPayment({
    required String paymentId,
    required String adminId,
    required String adminName,
    required String reason,
  }) async {
    if (reason.trim().isEmpty) {
      throw ArgumentError('Mandatory reason is required to void a payment transaction.');
    }

    try {
      final now = DateTime.now().toIso8601String();
      await _client.from('customer_payment_transactions').update({
        'status': TransactionStatus.voided,
        'verification_status': PaymentVerificationStatus.voided,
        'void_reason': reason,
        'reversal_reason': reason,
        'updated_by': adminId,
        'updated_by_name': adminName,
        'updated_at': now,
      }).eq('id', paymentId);

      // Log Audit Trail
      await ActivityLogService.logActivity(
        consumerNo: paymentId,
        customerName: 'Payment Voided',
        module: 'Payment Module',
        action: 'VOIDED',
        oldValue: 'Valid',
        newValue: 'Void',
        remarks: 'Reason: $reason (Preserved in ledger by $adminName)',
      );

      return true;
    } catch (e) {
      debugPrint('AdminPaymentService.voidPayment error: $e');
      return false;
    }
  }

  /// Edit authorized payment fields with mandatory reason and complete audit logging
  static Future<bool> updatePayment({
    required PaymentTransaction oldPayment,
    required Map<String, dynamic> updates,
    required String reason,
    required String adminId,
    required String adminName,
  }) async {
    if (reason.trim().isEmpty) {
      throw ArgumentError('Mandatory reason is required to edit payment records.');
    }

    try {
      final now = DateTime.now().toIso8601String();
      final patch = Map<String, dynamic>.from(updates);
      patch['updated_by'] = adminId;
      patch['updated_by_name'] = adminName;
      patch['updated_at'] = now;

      await _client
          .from('customer_payment_transactions')
          .update(patch)
          .eq('id', oldPayment.id!);

      // Log complete old vs new in audit trail
      await ActivityLogService.logActivity(
        recordId: oldPayment.customerId,
        consumerNo: oldPayment.consumerNo,
        customerName: oldPayment.customerName ?? 'Customer',
        village: oldPayment.village ?? '-',
        module: 'Payment Module',
        action: 'PAYMENT_EDITED',
        oldValue: jsonEncode({
          'amount': oldPayment.amount,
          'date': oldPayment.paymentDate.toIso8601String().split('T')[0],
          'mode': oldPayment.paymentMode,
          'reference': oldPayment.referenceNumber,
        }),
        newValue: jsonEncode(updates),
        remarks: 'Reason: $reason (Edited by $adminName)',
      );

      return true;
    } catch (e) {
      debugPrint('AdminPaymentService.updatePayment error: $e');
      return false;
    }
  }

  /// Fetch Customer Payment Profile for Admin view
  static Future<Map<String, dynamic>?> fetchCustomerPaymentProfile(String customerId) async {
    try {
      // 1. Fetch customer details
      final custRes = await _client
          .from('consumer_records')
          .select('id, customer_name, consumer_no, mobile_number, village, current_stage, total_amount, paid_amount, pending_amount, payment_status, payment_due_date')
          .eq('id', customerId)
          .maybeSingle();

      if (custRes == null) return null;

      // 2. Fetch payment transactions for this customer
      final txRes = await _client
          .from('customer_payment_transactions')
          .select()
          .eq('customer_id', customerId)
          .order('payment_date', ascending: false);

      final List<PaymentTransaction> transactions = (txRes as List)
          .map((m) => PaymentTransaction.fromJson(m as Map<String, dynamic>))
          .toList();

      final totalAmt = (custRes['total_amount'] is num)
          ? (custRes['total_amount'] as num).toDouble()
          : double.tryParse(custRes['total_amount']?.toString() ?? '0') ?? 0.0;

      final summary = CustomerPaymentSummary.calculate(
        totalAmount: totalAmt,
        transactions: transactions,
      );

      return {
        'customer': custRes,
        'transactions': transactions,
        'summary': summary,
      };
    } catch (e) {
      debugPrint('AdminPaymentService.fetchCustomerPaymentProfile error: $e');
      return null;
    }
  }

  /// Generate CSV string for payments export
  static String generatePaymentsCsv(List<PaymentTransaction> payments) {
    final buffer = StringBuffer();
    // Headers
    buffer.writeln('Payment ID,Customer Name,Consumer No,Village,Amount (INR),Payment Type,Payment Mode,Date,Reference No,Verification Status,Sync Status,Created By,Remarks');

    for (final p in payments) {
      final line = [
        p.id ?? '',
        '"${(p.customerName ?? '').replaceAll('"', '""')}"',
        '"${p.consumerNo.replaceAll('"', '""')}"',
        '"${(p.village ?? '').replaceAll('"', '""')}"',
        p.amount.toStringAsFixed(2),
        p.paymentType,
        p.paymentMode,
        p.paymentDate.toIso8601String().split('T')[0],
        '"${(p.referenceNumber ?? '').replaceAll('"', '""')}"',
        p.verificationStatus,
        p.syncStatus,
        '"${(p.createdByName ?? p.createdBy ?? '').replaceAll('"', '""')}"',
        '"${(p.remarks ?? '').replaceAll('"', '""')}"',
      ].join(',');
      buffer.writeln(line);
    }

    return buffer.toString();
  }

  /// Recalculate customer paid_amount and pending_amount deterministically
  /// STRICT RULE: Additional payments do NOT reduce Contract Pending.
  static Future<void> recalculateAndUpdateCustomerBalance(String customerId) async {
    try {
      final cust = await _client
          .from('consumer_records')
          .select('total_amount, payment_due_date')
          .eq('id', customerId)
          .maybeSingle();

      if (cust == null) return;

      final totalAmount = (cust['total_amount'] is num)
          ? (cust['total_amount'] as num).toDouble()
          : double.tryParse(cust['total_amount']?.toString() ?? '0') ?? 0.0;

      final txRes = await _client
          .from('customer_payment_transactions')
          .select('amount, status, verification_status, deleted, payment_type')
          .eq('customer_id', customerId);

      double contractPaid = 0.0;
      double additionalPaid = 0.0;

      for (final row in (txRes as List)) {
        final m = row as Map<String, dynamic>;
        final status = m['status']?.toString() ?? 'Valid';
        final vStatus = m['verification_status']?.toString() ?? 'Pending';
        final deleted = m['deleted'] == true;
        if (status == 'Valid' && !deleted && vStatus != 'Rejected' && vStatus != 'Void') {
          final amt = (m['amount'] is num)
              ? (m['amount'] as num).toDouble()
              : double.tryParse(m['amount']?.toString() ?? '0') ?? 0.0;
          final pType = m['payment_type']?.toString() ?? PaymentType.contract;
          if (pType.toUpperCase() == 'ADDITIONAL') {
            additionalPaid += amt;
          } else {
            contractPaid += amt;
          }
        }
      }

      // CRITICAL ACCOUNTING RULE:
      // Contract Pending = max(0, Contract Amount - Contract Payments)
      // Additional payments do NOT reduce Contract Pending!
      final contractPending = (totalAmount > 0) ? (totalAmount - contractPaid).clamp(0.0, double.infinity) : 0.0;
      final totalReceived = contractPaid + additionalPaid;

      String newStatus = PaymentStatus.pending;
      if (totalAmount > 0 && contractPaid >= totalAmount) {
        newStatus = PaymentStatus.paid;
      } else if (contractPaid > 0) {
        newStatus = PaymentStatus.partiallyPaid;
      }

      await _client.from('consumer_records').update({
        'paid_amount': contractPaid,
        'pending_amount': contractPending,
        'additional_paid_amount': additionalPaid,
        'total_received_amount': totalReceived,
        'payment_status': newStatus,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', customerId);
    } catch (e) {
      debugPrint('Error recalculating customer balance: $e');
    }
  }

  /// Record a payment transaction from Admin Panel
  static Future<PaymentTransaction> recordPayment({
    required String customerId,
    required String consumerNo,
    required double amount,
    required DateTime paymentDate,
    required String paymentMode,
    String paymentType = PaymentType.contract,
    String? additionalCategory,
    String? referenceNumber,
    String? remarks,
  }) async {
    try {
      final user = SupabaseService.currentUser;
      final userName = user?.userMetadata?['name'] as String? ?? user?.email?.split('@')[0] ?? 'Admin';
      final dateStr = paymentDate.toIso8601String().split('T')[0];

      final res = await _client.from('customer_payment_transactions').insert({
        'customer_id': customerId,
        'consumer_no': consumerNo,
        'amount': amount,
        'payment_date': dateStr,
        'payment_type': paymentType,
        if (additionalCategory != null) 'additional_category': additionalCategory,
        'payment_mode': paymentMode,
        'reference_number': referenceNumber?.trim(),
        'remarks': remarks?.trim(),
        'received_by': userName,
        'status': 'Valid',
        'sync_status': 'Synced',
        'verification_status': 'Verified',
        'verified_by': user?.id,
        'verified_by_name': userName,
        'verified_at': DateTime.now().toUtc().toIso8601String(),
        'created_by': user?.id,
        'created_by_name': userName,
      }).select().single();

      final tx = PaymentTransaction.fromJson(res);

      // Auto-recalculate customer's Contract Paid, Contract Pending, and Additional Paid
      await recalculateAndUpdateCustomerBalance(customerId);

      // Audit Log
      await ActivityLogService.logActivity(
        recordId: customerId,
        consumerNo: consumerNo,
        customerName: 'Customer',
        module: 'Payment Module',
        action: 'PAYMENT_RECORDED',
        newValue: '₹${amount.toStringAsFixed(0)} ($paymentType) via $paymentMode',
        remarks: remarks ?? 'Payment recorded via Admin Panel',
      );

      return tx;
    } catch (e) {
      debugPrint('AdminPaymentService.recordPayment error: $e');
      rethrow;
    }
  }

  /// Simple update of payment transaction from Admin Panel
  static Future<bool> updatePaymentSimple({
    required String paymentId,
    required String customerId,
    required double amount,
    required DateTime paymentDate,
    required String paymentMode,
    String paymentType = PaymentType.contract,
    String? additionalCategory,
    String? referenceNumber,
    String? remarks,
  }) async {
    try {
      final user = SupabaseService.currentUser;
      final userName = user?.userMetadata?['name'] as String? ?? user?.email?.split('@')[0] ?? 'Admin';
      final dateStr = paymentDate.toIso8601String().split('T')[0];

      await _client.from('customer_payment_transactions').update({
        'amount': amount,
        'payment_date': dateStr,
        'payment_type': paymentType,
        'additional_category': additionalCategory,
        'payment_mode': paymentMode,
        'reference_number': referenceNumber?.trim(),
        'remarks': remarks?.trim(),
        'updated_by': user?.id,
        'updated_by_name': userName,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', paymentId);

      // Recalculate customer's balance
      await recalculateAndUpdateCustomerBalance(customerId);

      // Audit Log
      await ActivityLogService.logActivity(
        recordId: customerId,
        consumerNo: paymentId,
        customerName: 'Customer',
        module: 'Payment Module',
        action: 'PAYMENT_UPDATED',
        newValue: '₹${amount.toStringAsFixed(0)} ($paymentType) via $paymentMode',
        remarks: remarks ?? 'Payment updated by $userName',
      );

      return true;
    } catch (e) {
      debugPrint('AdminPaymentService.updatePaymentSimple error: $e');
      return false;
    }
  }

  /// Fetch Customer-wise Payment Summaries for the primary table
  static Future<List<CustomerPaymentRow>> fetchCustomerPaymentSummaries({
    String? searchQuery,
    String statusFilter = 'All',
  }) async {
    try {
      var query = _client.from('consumer_records').select('''
        id,
        customer_name,
        consumer_no,
        village,
        mobile_number,
        total_amount,
        paid_amount,
        pending_amount,
        additional_paid_amount,
        total_received_amount,
        payment_status,
        payments:customer_payment_transactions(
          amount,
          payment_date,
          payment_type,
          additional_category,
          payment_mode,
          status,
          verification_status,
          deleted
        )
      ''').eq('deleted', false).eq('is_merged', false);

      if (statusFilter != 'All') {
        query = query.eq('payment_status', statusFilter);
      }

      final res = await query.order('customer_name', ascending: true).limit(500);

      final List<CustomerPaymentRow> rows = [];
      for (final r in (res as List)) {
        final m = r as Map<String, dynamic>;
        final id = m['id']?.toString() ?? '';
        final name = m['customer_name']?.toString() ?? 'Unnamed';
        final cNo = m['consumer_no']?.toString() ?? '';
        final village = m['village']?.toString() ?? '';
        final mobile = m['mobile_number']?.toString() ?? '';

        final contractTotal = (m['total_amount'] is num)
            ? (m['total_amount'] as num).toDouble()
            : double.tryParse(m['total_amount']?.toString() ?? '0') ?? 0.0;
        double contractPaid = (m['paid_amount'] is num)
            ? (m['paid_amount'] as num).toDouble()
            : double.tryParse(m['paid_amount']?.toString() ?? '0') ?? 0.0;
        double contractPending = (m['pending_amount'] is num)
            ? (m['pending_amount'] as num).toDouble()
            : double.tryParse(m['pending_amount']?.toString() ?? '0') ?? 0.0;
        double additionalPaid = (m['additional_paid_amount'] is num)
            ? (m['additional_paid_amount'] as num).toDouble()
            : double.tryParse(m['additional_paid_amount']?.toString() ?? '0') ?? 0.0;
        double totalReceived = (m['total_received_amount'] is num)
            ? (m['total_received_amount'] as num).toDouble()
            : double.tryParse(m['total_received_amount']?.toString() ?? '0') ?? (contractPaid + additionalPaid);
        final status = m['payment_status']?.toString() ?? 'Pending';

        DateTime? lastDate;
        double? lastAmt;
        String? lastMode;
        String? lastType;
        String? lastCat;

        final txList = m['payments'] as List?;
        if (txList != null && txList.isNotEmpty) {
          double computedContractPaid = 0.0;
          double computedAdditionalPaid = 0.0;
          for (final tx in txList) {
            final txMap = tx as Map<String, dynamic>;
            if (txMap['status'] == 'Valid' &&
                txMap['deleted'] != true &&
                txMap['verification_status'] != 'Rejected' &&
                txMap['verification_status'] != 'Void') {
              final amt = (txMap['amount'] is num)
                  ? (txMap['amount'] as num).toDouble()
                  : double.tryParse(txMap['amount']?.toString() ?? '0') ?? 0.0;
              final pType = txMap['payment_type']?.toString() ?? PaymentType.contract;
              if (pType.toUpperCase() == 'ADDITIONAL') {
                computedAdditionalPaid += amt;
              } else {
                computedContractPaid += amt;
              }

              final dateStr = txMap['payment_date']?.toString();
              final dt = dateStr != null ? DateTime.tryParse(dateStr) : null;
              if (dt != null && (lastDate == null || dt.isAfter(lastDate))) {
                lastDate = dt;
                lastAmt = amt;
                lastMode = txMap['payment_mode']?.toString();
                lastType = pType;
                lastCat = txMap['additional_category']?.toString();
              }
            }
          }
          contractPaid = computedContractPaid;
          additionalPaid = computedAdditionalPaid;
          contractPending = (contractTotal - contractPaid).clamp(0.0, double.infinity);
          totalReceived = contractPaid + additionalPaid;
        }

        rows.add(CustomerPaymentRow(
          customerId: id,
          customerName: name,
          consumerNo: cNo,
          village: village,
          mobileNumber: mobile,
          totalAmount: contractTotal,
          paidAmount: contractPaid,
          pendingAmount: contractPending,
          additionalPaid: additionalPaid,
          totalReceived: totalReceived,
          paymentStatus: status,
          lastPaymentDate: lastDate,
          lastPaymentAmount: lastAmt,
          lastPaymentMode: lastMode,
          lastPaymentType: lastType,
          lastAdditionalCategory: lastCat,
        ));
      }

      if (searchQuery != null && searchQuery.trim().isNotEmpty) {
        final q = searchQuery.toLowerCase().trim();
        return rows.where((row) {
          return row.customerName.toLowerCase().contains(q) ||
              row.consumerNo.toLowerCase().contains(q) ||
              row.mobileNumber.toLowerCase().contains(q) ||
              row.village.toLowerCase().contains(q);
        }).toList();
      }

      return rows;
    } catch (e) {
      debugPrint('AdminPaymentService.fetchCustomerPaymentSummaries error: $e');
      return [];
    }
  }

  /// Fetch category-wise breakdown for additional payments
  static Future<Map<String, double>> fetchCategoryPaymentBreakdown() async {
    try {
      final res = await _client
          .from('customer_payment_transactions')
          .select('amount, additional_category, status, verification_status')
          .eq('payment_type', PaymentType.additional);

      final Map<String, double> breakdown = {
        AdditionalPaymentCategory.extraMaterial: 0.0,
        AdditionalPaymentCategory.extraWork: 0.0,
        AdditionalPaymentCategory.additionalInstallation: 0.0,
        AdditionalPaymentCategory.transport: 0.0,
        AdditionalPaymentCategory.serviceCharge: 0.0,
        AdditionalPaymentCategory.other: 0.0,
      };

      for (final row in (res as List)) {
        final m = row as Map<String, dynamic>;
        final status = m['status']?.toString() ?? 'Valid';
        final vStatus = m['verification_status']?.toString() ?? 'Pending';
        if (status == 'Valid' && vStatus != 'Rejected' && vStatus != 'Void') {
          final cat = m['additional_category']?.toString() ?? AdditionalPaymentCategory.other;
          final amt = (m['amount'] is num)
              ? (m['amount'] as num).toDouble()
              : double.tryParse(m['amount']?.toString() ?? '0') ?? 0.0;
          breakdown[cat] = (breakdown[cat] ?? 0.0) + amt;
        }
      }
      return breakdown;
    } catch (e) {
      debugPrint('Error fetching category breakdown: $e');
      return {};
    }
  }

  /// Export Customer Payment summary list to Excel (.xlsx) with separated Contract and Additional sums
  static Future<bool> exportCustomerPaymentsToExcel(List<CustomerPaymentRow> rows) async {
    final columns = [
      ExcelColumnDef<CustomerPaymentRow>(
        header: 'Customer',
        valueExtractor: (r) => r.customerName,
      ),
      ExcelColumnDef<CustomerPaymentRow>(
        header: 'Consumer No',
        valueExtractor: (r) => r.consumerNo,
      ),
      ExcelColumnDef<CustomerPaymentRow>(
        header: 'Contract Amount',
        valueExtractor: (r) => r.totalAmount,
        isCurrency: true,
      ),
      ExcelColumnDef<CustomerPaymentRow>(
        header: 'Contract Paid',
        valueExtractor: (r) => r.paidAmount,
        isCurrency: true,
      ),
      ExcelColumnDef<CustomerPaymentRow>(
        header: 'Contract Pending',
        valueExtractor: (r) => r.pendingAmount,
        isCurrency: true,
      ),
      ExcelColumnDef<CustomerPaymentRow>(
        header: 'Additional Paid',
        valueExtractor: (r) => r.additionalPaid,
        isCurrency: true,
      ),
      ExcelColumnDef<CustomerPaymentRow>(
        header: 'Total Received',
        valueExtractor: (r) => r.totalReceived,
        isCurrency: true,
      ),
      ExcelColumnDef<CustomerPaymentRow>(
        header: 'Payment Date',
        valueExtractor: (r) => r.lastPaymentDate != null ? DateFormat('dd/MM/yyyy').format(r.lastPaymentDate!) : '—',
      ),
      ExcelColumnDef<CustomerPaymentRow>(
        header: 'Payment Mode',
        valueExtractor: (r) => r.lastPaymentMode ?? '—',
      ),
    ];

    return await ExcelExportService.exportAndSave<CustomerPaymentRow>(
      filePrefix: 'Siya_Payments_Ledger',
      sheetName: 'Payments Ledger',
      columns: columns,
      items: rows,
      reportTitle: 'Siya Solar Connect — Customer Payment Ledger',
    );
  }
}

