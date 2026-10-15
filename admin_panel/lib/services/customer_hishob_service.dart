import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/customer_hishob.dart';
import '../models/customer_payment.dart';
import '../models/invoice.dart';
import 'invoice_storage_service.dart';
import 'record_service.dart';
import 'supabase_service.dart';

class CustomerHishobDataResult {
  final List<CustomerHishobEntry> entries;
  final CustomerHishobMetrics metrics;

  CustomerHishobDataResult({
    required this.entries,
    required this.metrics,
  });
}

class CustomerHishobService {
  static SupabaseClient get _client => SupabaseService.client;

  /// Fetch all customer hishob entries combining saved invoices & actual payments
  static Future<CustomerHishobDataResult> fetchHishobData({
    String? searchQuery,
    String? statusFilter,
    DateTimeRange? dateRange,
  }) async {
    // 1. Fetch saved Invoices (Saved quotations without invoices are strictly excluded)
    final List<Invoice> allInvoices = await InvoiceStorageService.getAllInvoices();

    // 2. Fetch actual recorded Payment Transactions (Margin receipts strictly excluded)
    final List<PaymentTransaction> allPayments = [];
    try {
      final res = await _client
          .from('customer_payment_transactions')
          .select()
          .eq('status', 'Valid')
          .order('payment_date', ascending: true);

      for (final row in res as List) {
        try {
          allPayments.add(PaymentTransaction.fromJson(row as Map<String, dynamic>));
        } catch (_) {}
      }
    } catch (e) {
      debugPrint('Error fetching payment transactions in Hishob: $e');
    }

    // 3. Fetch customer master records for rich details (Name, Village, Address, Mobile)
    final Map<String, Map<String, dynamic>> customerMasterMap = {};
    try {
      final recRes = await _client
          .from('consumer_records')
          .select('id, consumer_no, name, mobile, address, village, district')
          .eq('deleted', false)
          .eq('is_merged', false);

      for (final r in recRes as List) {
        final m = r as Map<String, dynamic>;
        final cNo = (m['consumer_no']?.toString() ?? '').trim().toUpperCase();
        if (cNo.isNotEmpty) {
          customerMasterMap[cNo] = m;
        }
      }
    } catch (e) {
      debugPrint('Error fetching consumer records in Hishob: $e');
    }

    // 4. Group invoices by Consumer Number (Normalized)
    final Map<String, List<Invoice>> invoicesByConsumer = {};
    for (final inv in allInvoices) {
      final cNo = inv.consumerNo.trim().toUpperCase();
      if (cNo.isNotEmpty) {
        invoicesByConsumer.putIfAbsent(cNo, () => []).add(inv);
      }
    }

    // 5. Group payments by Consumer Number (Normalized)
    final Map<String, List<PaymentTransaction>> paymentsByConsumer = {};
    for (final p in allPayments) {
      final cNo = p.consumerNo.trim().toUpperCase();
      if (cNo.isNotEmpty) {
        paymentsByConsumer.putIfAbsent(cNo, () => []).add(p);
      }
    }

    // 6. Aggregate customers who have invoices (receivables) or payments recorded
    final Set<String> targetConsumerNos = {
      ...invoicesByConsumer.keys,
      ...paymentsByConsumer.keys,
    };

    final List<CustomerHishobEntry> allEntries = [];

    for (final cNo in targetConsumerNos) {
      final custInvoices = invoicesByConsumer[cNo] ?? [];
      final custPayments = paymentsByConsumer[cNo] ?? [];
      final master = customerMasterMap[cNo];

      // Customer info resolution
      String customerId = '';
      String customerName = '';
      String? mobile;
      String? address;
      String? villageCity;
      String? district;

      if (master != null) {
        customerId = master['id']?.toString() ?? '';
        customerName = master['name']?.toString() ?? '';
        mobile = master['mobile']?.toString();
        address = master['address']?.toString();
        villageCity = master['village']?.toString();
        district = master['district']?.toString();
      }

      if (customerName.isEmpty && custInvoices.isNotEmpty) {
        final firstInv = custInvoices.first;
        customerName = firstInv.customerName;
        mobile ??= firstInv.mobileNo;
        address ??= firstInv.address;
        villageCity ??= firstInv.villageCity;
        district ??= firstInv.district;
        if (customerId.isEmpty) {
          customerId = firstInv.customerId ?? '';
        }
      }

      if (customerName.isEmpty && custPayments.isNotEmpty) {
        final firstPay = custPayments.first;
        customerName = firstPay.customerName ?? 'Customer $cNo';
        mobile ??= firstPay.mobileNumber;
        villageCity ??= firstPay.village;
        if (customerId.isEmpty) {
          customerId = firstPay.customerId;
        }
      }

      if (customerName.isEmpty) {
        customerName = 'Customer $cNo';
      }

      final entry = CustomerHishobEntry.build(
        customerId: customerId,
        consumerNo: cNo,
        customerName: customerName,
        mobile: mobile,
        address: address,
        villageCity: villageCity,
        district: district,
        invoices: custInvoices,
        payments: custPayments,
      );

      allEntries.add(entry);
    }

    // Sort by Total Pending desc, then Customer Name asc
    allEntries.sort((a, b) {
      final cmp = b.totalPending.compareTo(a.totalPending);
      if (cmp != 0) return cmp;
      return a.customerName.toLowerCase().compareTo(b.customerName.toLowerCase());
    });

    // 7. Calculate overall metrics before search filtering
    final metrics = CustomerHishobMetrics.fromEntries(allEntries);

    // 8. Apply Search Filtering (Customer Name, Consumer Number, Invoice Number)
    List<CustomerHishobEntry> filtered = allEntries;

    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      final q = searchQuery.trim().toLowerCase();
      filtered = filtered.where((e) {
        final nameMatch = e.customerName.toLowerCase().contains(q);
        final consumerMatch = e.consumerNo.toLowerCase().contains(q);
        final invoiceMatch = e.invoices.any((inv) =>
            inv.invoiceNumber.toLowerCase().contains(q) ||
            inv.refInvoiceNo.toLowerCase().contains(q));
        final mobileMatch = (e.mobile?.toLowerCase() ?? '').contains(q);

        return nameMatch || consumerMatch || invoiceMatch || mobileMatch;
      }).toList();
    }

    // 9. Apply Payment Status Filtering
    if (statusFilter != null && statusFilter != 'All' && statusFilter.isNotEmpty) {
      if (statusFilter == 'Paid') {
        filtered = filtered.where((e) => e.paymentStatus == 'Paid').toList();
      } else if (statusFilter == 'Partially Paid') {
        filtered = filtered.where((e) => e.paymentStatus == 'Partially Paid').toList();
      } else if (statusFilter == 'Unpaid') {
        filtered = filtered.where((e) => e.paymentStatus == 'Unpaid').toList();
      } else if (statusFilter == 'Pending') {
        // Pending covers Unpaid and Partially Paid
        filtered = filtered.where((e) => e.totalPending > 0).toList();
      }
    }

    // 10. Apply Date Range Filtering (if specified)
    if (dateRange != null) {
      final start = DateTime(dateRange.start.year, dateRange.start.month, dateRange.start.day);
      final end = DateTime(dateRange.end.year, dateRange.end.month, dateRange.end.day, 23, 59, 59);

      filtered = filtered.where((e) {
        final hasInvoiceInDate = e.invoices.any((inv) =>
            inv.invoiceDate.isAfter(start.subtract(const Duration(seconds: 1))) &&
            inv.invoiceDate.isBefore(end.add(const Duration(seconds: 1))));
        final hasPaymentInDate = e.payments.any((p) =>
            p.paymentDate.isAfter(start.subtract(const Duration(seconds: 1))) &&
            p.paymentDate.isBefore(end.add(const Duration(seconds: 1))));

        return hasInvoiceInDate || hasPaymentInDate;
      }).toList();
    }

    return CustomerHishobDataResult(
      entries: filtered,
      metrics: metrics,
    );
  }

  /// Add an actual payment with duplicate prevention and live balance update
  static Future<PaymentTransaction> recordPayment({
    required String customerId,
    required String consumerNo,
    String? customerName,
    required double amount,
    required DateTime paymentDate,
    required String paymentMode,
    String? invoiceNumber,
    String? referenceNumber,
    String? remarks,
  }) async {
    // 1. Prevent duplicate payment submission
    final existing = await RecordService.checkDuplicatePayment(
      customerId: customerId,
      amount: amount,
      paymentDate: paymentDate,
      referenceNumber: referenceNumber,
    );

    if (existing != null) {
      throw Exception(
        'A payment of ₹${amount.toStringAsFixed(0)} on ${paymentDate.day}/${paymentDate.month}/${paymentDate.year} '
        'already exists for this customer (Transaction Ref: ${existing.referenceNumber ?? "N/A"}).',
      );
    }

    // 2. Build payment transaction
    final tx = PaymentTransaction(
      customerId: customerId,
      consumerNo: consumerNo.trim(),
      customerName: customerName,
      amount: amount,
      paymentDate: paymentDate,
      paymentMode: paymentMode,
      paymentType: PaymentType.general,
      invoiceNumber: invoiceNumber?.trim().isNotEmpty == true ? invoiceNumber!.trim() : null,
      referenceNumber: referenceNumber?.trim().isNotEmpty == true ? referenceNumber!.trim() : null,
      remarks: remarks?.trim().isNotEmpty == true ? remarks!.trim() : null,
      status: TransactionStatus.valid,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    // 3. Save to database permanently
    final created = await RecordService.addPaymentTransaction(tx);
    return created;
  }

  /// Update an existing payment transaction with confirmation
  static Future<void> updatePayment({
    required PaymentTransaction payment,
    required double newAmount,
    required DateTime newDate,
    required String newMode,
    String? newInvoiceNumber,
    String? newRef,
    String? newRemarks,
  }) async {
    final updated = payment.copyWith(
      amount: newAmount,
      paymentDate: newDate,
      paymentMode: newMode,
      invoiceNumber: newInvoiceNumber?.trim().isNotEmpty == true ? newInvoiceNumber!.trim() : null,
      referenceNumber: newRef?.trim().isNotEmpty == true ? newRef!.trim() : null,
      remarks: newRemarks?.trim().isNotEmpty == true ? newRemarks!.trim() : null,
      updatedAt: DateTime.now(),
    );

    await RecordService.updatePaymentTransaction(updated);
  }

  /// Delete (or cancel) a payment transaction with balance recalculation
  static Future<void> deletePayment(String paymentId) async {
    await RecordService.deletePaymentTransaction(paymentId);
  }
}
