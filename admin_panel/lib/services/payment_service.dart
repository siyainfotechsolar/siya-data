import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/customer_payment.dart';
import '../models/consumer_record.dart';
import 'supabase_service.dart';
import 'activity_log_service.dart';

class AdminPaymentService {
  static SupabaseClient get _client => SupabaseService.client;

  /// Fetch executive dashboard KPI metrics for the Admin Payment Module
  static Future<AdminPaymentMetrics> fetchDashboardMetrics() async {
    try {
      // 1. Fetch transactions for calculation
      final txRes = await _client
          .from('customer_payment_transactions')
          .select('amount, payment_date, status, verification_status, sync_status, payment_type');

      final txList = txRes as List;
      final now = DateTime.now();
      final todayStr = now.toIso8601String().split('T')[0];
      final currentMonth = now.month;
      final currentYear = now.year;

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
        final amount = (map['amount'] is num)
            ? (map['amount'] as num).toDouble()
            : double.tryParse(map['amount']?.toString() ?? '0') ?? 0.0;

        if (status == 'Valid' && vStatus != 'Rejected' && vStatus != 'Void') {
          totalCollection += amount;

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
    String paymentType = 'All', // 'All', 'Online', 'Offline'
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
}
