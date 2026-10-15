import 'package:flutter/foundation.dart';
import 'invoice.dart';
import 'customer_payment.dart';

/// Calculation breakdown for an individual invoice in the customer ledger
class InvoiceBalance {
  final Invoice invoice;
  final double totalPaid;
  final double pendingAmount;
  final String paymentStatus; // 'Paid', 'Partially Paid', 'Unpaid'
  final bool isOverpaid;
  final double overpaidAmount;
  final List<PaymentTransaction> allocatedPayments;

  InvoiceBalance({
    required this.invoice,
    required this.totalPaid,
    required this.pendingAmount,
    required this.paymentStatus,
    this.isOverpaid = false,
    this.overpaidAmount = 0.0,
    required this.allocatedPayments,
  });

  /// Invoice Grand Total
  double get grandTotal => invoice.grandTotal;

  /// Invoice Number
  String get invoiceNumber => invoice.invoiceNumber;

  /// Invoice Date
  DateTime get invoiceDate => invoice.invoiceDate;
}

/// Customer-level Hishob Record aggregating all saved invoices & actual recorded payments
class CustomerHishobEntry {
  final String customerId;
  final String consumerNo;
  final String customerName;
  final String? mobile;
  final String? address;
  final String? villageCity;
  final String? district;
  final List<Invoice> invoices;
  final List<PaymentTransaction> payments;
  final List<InvoiceBalance> invoiceBalances;

  CustomerHishobEntry({
    required this.customerId,
    required this.consumerNo,
    required this.customerName,
    this.mobile,
    this.address,
    this.villageCity,
    this.district,
    required this.invoices,
    required this.payments,
    required this.invoiceBalances,
  });

  /// 1. Total Customer Amount: Amount due strictly against saved invoices
  double get totalAmount => invoices.fold(0.0, (sum, inv) => sum + inv.grandTotal);

  /// 2. Total Paid: Sum of actual recorded payments only (Margin Receipts strictly excluded!)
  double get totalPaid => payments
      .where((p) => p.isValid)
      .fold(0.0, (sum, p) => sum + p.amount);

  /// 3. Total Pending: Total Amount - Total Paid (clamped to 0 to prevent accidental negative pending balance)
  double get totalPending => (totalAmount - totalPaid).clamp(0.0, double.infinity);

  /// 4. Overpayment check (Flags for review instead of silently changing records)
  bool get isOverpaid => totalAmount > 0 && totalPaid > totalAmount;
  double get overpaidAmount => isOverpaid ? (totalPaid - totalAmount) : 0.0;

  /// 5. Overall Payment Status: Paid, Partially Paid, Unpaid
  String get paymentStatus {
    if (totalAmount <= 0) {
      return totalPaid > 0 ? 'Advance Received' : 'No Invoices';
    }
    if (totalPaid >= totalAmount) {
      return 'Paid';
    }
    if (totalPaid > 0) {
      return 'Partially Paid';
    }
    return 'Unpaid';
  }

  /// Factory constructor that allocates actual payments to invoices accurately
  factory CustomerHishobEntry.build({
    required String customerId,
    required String consumerNo,
    required String customerName,
    String? mobile,
    String? address,
    String? villageCity,
    String? district,
    required List<Invoice> invoices,
    required List<PaymentTransaction> payments,
  }) {
    // Filter only valid payments (reversals/voids/cancelled excluded)
    final validPayments = payments.where((p) => p.isValid).toList();

    // Sort invoices chronologically (earliest first for consistent FIFO allocation of untagged payments)
    final sortedInvoices = List<Invoice>.from(invoices)
      ..sort((a, b) => a.invoiceDate.compareTo(b.invoiceDate));

    // Separate tagged vs untagged payments
    final Map<String, List<PaymentTransaction>> taggedByInvoice = {};
    final List<PaymentTransaction> untaggedPayments = [];

    for (final p in validPayments) {
      final invNo = p.invoiceNumber?.trim();
      if (invNo != null && invNo.isNotEmpty) {
        taggedByInvoice.putIfAbsent(invNo, () => []).add(p);
      } else {
        untaggedPayments.add(p);
      }
    }

    // Allocate payments to each invoice
    final List<InvoiceBalance> balances = [];
    double remainingUntagged = untaggedPayments.fold(0.0, (sum, p) => sum + p.amount);

    for (final inv in sortedInvoices) {
      final directlyTagged = taggedByInvoice[inv.invoiceNumber] ?? [];
      final directPaid = directlyTagged.fold(0.0, (sum, p) => sum + p.amount);

      double allocatedUntagged = 0.0;
      final allocatedPaymentList = List<PaymentTransaction>.from(directlyTagged);

      final needed = (inv.grandTotal - directPaid).clamp(0.0, double.infinity);
      if (needed > 0 && remainingUntagged > 0) {
        allocatedUntagged = remainingUntagged >= needed ? needed : remainingUntagged;
        remainingUntagged -= allocatedUntagged;
      }

      final invoicePaid = directPaid + allocatedUntagged;
      final invoicePending = (inv.grandTotal - invoicePaid).clamp(0.0, double.infinity);
      final isOver = directPaid > inv.grandTotal;
      final overAmount = isOver ? directPaid - inv.grandTotal : 0.0;

      String status;
      if (invoicePaid >= inv.grandTotal) {
        status = 'Paid';
      } else if (invoicePaid > 0) {
        status = 'Partially Paid';
      } else {
        status = 'Unpaid';
      }

      balances.add(InvoiceBalance(
        invoice: inv,
        totalPaid: invoicePaid,
        pendingAmount: invoicePending,
        paymentStatus: status,
        isOverpaid: isOver,
        overpaidAmount: overAmount,
        allocatedPayments: allocatedPaymentList,
      ));
    }

    return CustomerHishobEntry(
      customerId: customerId,
      consumerNo: consumerNo,
      customerName: customerName,
      mobile: mobile,
      address: address,
      villageCity: villageCity,
      district: district,
      invoices: sortedInvoices,
      payments: validPayments,
      invoiceBalances: balances,
    );
  }
}

/// Metrics for the Hishob Dashboard
class CustomerHishobMetrics {
  final double totalCustomerAmount;
  final double totalPaidAmount;
  final double totalPendingAmount;
  final int totalCustomers;
  final int pendingCustomersCount;
  final int fullyPaidCustomersCount;
  final int unpaidCustomersCount;
  final int overpaidCustomersCount;

  CustomerHishobMetrics({
    required this.totalCustomerAmount,
    required this.totalPaidAmount,
    required this.totalPendingAmount,
    required this.totalCustomers,
    required this.pendingCustomersCount,
    required this.fullyPaidCustomersCount,
    required this.unpaidCustomersCount,
    required this.overpaidCustomersCount,
  });

  factory CustomerHishobMetrics.fromEntries(List<CustomerHishobEntry> entries) {
    double totalCustomerAmount = 0.0;
    double totalPaidAmount = 0.0;
    int pendingCount = 0;
    int fullyPaidCount = 0;
    int unpaidCount = 0;
    int overpaidCount = 0;

    for (final e in entries) {
      totalCustomerAmount += e.totalAmount;
      totalPaidAmount += e.totalPaid;

      if (e.isOverpaid) {
        overpaidCount++;
      }

      if (e.totalAmount > 0) {
        if (e.totalPending > 0) {
          pendingCount++;
        }
        if (e.totalPaid >= e.totalAmount) {
          fullyPaidCount++;
        } else if (e.totalPaid == 0) {
          unpaidCount++;
        }
      }
    }

    final totalPendingAmount = (totalCustomerAmount - totalPaidAmount).clamp(0.0, double.infinity);

    return CustomerHishobMetrics(
      totalCustomerAmount: totalCustomerAmount,
      totalPaidAmount: totalPaidAmount,
      totalPendingAmount: totalPendingAmount,
      totalCustomers: entries.length,
      pendingCustomersCount: pendingCount,
      fullyPaidCustomersCount: fullyPaidCount,
      unpaidCustomersCount: unpaidCount,
      overpaidCustomersCount: overpaidCount,
    );
  }

  factory CustomerHishobMetrics.empty() {
    return CustomerHishobMetrics(
      totalCustomerAmount: 0.0,
      totalPaidAmount: 0.0,
      totalPendingAmount: 0.0,
      totalCustomers: 0,
      pendingCustomersCount: 0,
      fullyPaidCustomersCount: 0,
      unpaidCustomersCount: 0,
      overpaidCustomersCount: 0,
    );
  }
}
