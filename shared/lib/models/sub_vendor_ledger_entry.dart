import 'package:intl/intl.dart';
import 'vendor_site_assignment.dart';
import 'vendor_material_transaction.dart';
import 'vendor_payout.dart';
import 'vendor_customer_payment.dart';
import 'vendor_gst_recovery.dart';

/// Single itemized chronological debit/credit entry in a Sub-Vendor's accounting ledger.
class SubVendorLedgerEntry {
  final String id;
  final DateTime date;
  final String voucherType; // 'Bank Loan Credit', 'Customer Cash', 'Material Issue', 'Material Return', 'SIYA Platform Fee', 'Statutory Net GST', 'GST Recovery', 'Vendor Payout / Advance', 'Approved Adjustment'
  final String particulars;
  final String? siteName;
  final String? consumerNo;
  final String? assignmentId;
  final String? referenceNo; // UTR, Challan, Invoice, Check No.
  final String? paymentMode;
  final double debit;
  final double credit;
  double runningBalance;
  final String? remarks;

  SubVendorLedgerEntry({
    required this.id,
    required this.date,
    required this.voucherType,
    required this.particulars,
    this.siteName,
    this.consumerNo,
    this.assignmentId,
    this.referenceNo,
    this.paymentMode,
    this.debit = 0.0,
    this.credit = 0.0,
    this.runningBalance = 0.0,
    this.remarks,
  });

  bool get isCredit => credit > 0.001;
  bool get isDebit => debit > 0.001;
  double get netEffect => credit - debit;

  SubVendorLedgerEntry copyWithRunningBalance(double balance) {
    return SubVendorLedgerEntry(
      id: id,
      date: date,
      voucherType: voucherType,
      particulars: particulars,
      siteName: siteName,
      consumerNo: consumerNo,
      assignmentId: assignmentId,
      referenceNo: referenceNo,
      paymentMode: paymentMode,
      debit: debit,
      credit: credit,
      runningBalance: balance,
      remarks: remarks,
    );
  }
}

/// Ledger Summary aggregation for a Sub-Vendor statement.
class SubVendorLedgerSummary {
  final String vendorId;
  final String vendorName;
  final String vendorCode;
  final double openingBalance;
  final double totalCredit;
  final double totalDebit;
  final double closingBalance;
  final List<SubVendorLedgerEntry> entries;
  final DateTime? fromDate;
  final DateTime? toDate;

  bool get isPayable => closingBalance >= 0.0;
  double get netPayableAmount => closingBalance >= 0.0 ? closingBalance : 0.0;
  double get netRecoverableAmount => closingBalance < 0.0 ? closingBalance.abs() : 0.0;

  const SubVendorLedgerSummary({
    required this.vendorId,
    required this.vendorName,
    required this.vendorCode,
    this.openingBalance = 0.0,
    required this.totalCredit,
    required this.totalDebit,
    required this.closingBalance,
    required this.entries,
    this.fromDate,
    this.toDate,
  });
}

/// Chronological Ledger Engine for Sub-Vendors
class SubVendorLedgerBuilder {
  static final _currency = NumberFormat.currency(locale: 'en_IN', symbol: 'Rs. ', decimalDigits: 2);

  /// Builds a fully reconciled chronological debit/credit ledger for a sub-vendor
  static SubVendorLedgerSummary buildLedger({
    required String vendorId,
    required String vendorName,
    required String vendorCode,
    required List<VendorSiteAssignment> assignments,
    required List<VendorMaterialTransaction> materials,
    required List<VendorPayout> payouts,
    required List<VendorCustomerPayment> customerPayments,
    List<VendorGstRecovery> gstRecoveries = const [],
    String? filterAssignmentId,
    DateTime? fromDate,
    DateTime? toDate,
  }) {
    final List<SubVendorLedgerEntry> rawEntries = [];

    // Filter assignments if specific site requested
    final targetAssignments = filterAssignmentId != null
        ? assignments.where((a) => a.id == filterAssignmentId).toList()
        : assignments;

    final targetAssignmentIds = targetAssignments.map((a) => a.id).toSet();

    // 1. Customer Payments (Bank Loan & Cash Realized Collections -> CREDITS)
    final filteredPayments = customerPayments.where((cp) {
      if (filterAssignmentId != null && cp.assignmentId != filterAssignmentId) return false;
      return targetAssignmentIds.contains(cp.assignmentId);
    }).toList();

    if (filteredPayments.isNotEmpty) {
      for (final cp in filteredPayments) {
        if (!cp.isApproved) continue;
        rawEntries.add(
          SubVendorLedgerEntry(
            id: 'cp_${cp.id}',
            date: cp.paymentDate,
            voucherType: cp.isLoan ? 'Bank Loan Credit' : 'Customer Cash Credit',
            particulars: cp.isLoan
                ? 'Bank Loan Credited - ${cp.customerName ?? "Customer"} (CA: ${cp.consumerNo ?? "N/A"})'
                : 'Customer Advance/Cash - ${cp.customerName ?? "Customer"} (CA: ${cp.consumerNo ?? "N/A"})',
            siteName: cp.customerName,
            consumerNo: cp.consumerNo,
            assignmentId: cp.assignmentId,
            referenceNo: cp.referenceNumber ?? cp.loanApplicationId ?? '-',
            paymentMode: cp.paymentMode,
            credit: cp.amount,
            debit: 0.0,
            remarks: cp.remarks,
          ),
        );
      }
    } else {
      // Fallback: If individual customer payments haven't been recorded in table, use assignment credited totals
      for (final a in targetAssignments) {
        final collection = a.totalCustomerReceived > 0 ? a.totalCustomerReceived : a.customerPaidAmount;
        if (collection > 0) {
          rawEntries.add(
            SubVendorLedgerEntry(
              id: 'a_coll_${a.id}',
              date: a.assignedDate,
              voucherType: a.isBankLoan ? 'Bank Loan Credit' : 'Customer Collection',
              particulars: 'Realized Collections Credited to SIYA - ${a.customerName ?? "Site"} (CA: ${a.consumerNo ?? "N/A"})',
              siteName: a.customerName,
              consumerNo: a.consumerNo,
              assignmentId: a.id,
              referenceNo: a.loanApplicationId ?? '-',
              paymentMode: a.paymentType,
              credit: collection,
              debit: 0.0,
              remarks: 'Site Realized Collection',
            ),
          );
        }
      }
    }

    // 2. Material Transactions (Issues = DEBITS, Returns = CREDITS)
    final filteredMaterials = materials.where((m) {
      if (filterAssignmentId != null && m.assignmentId != filterAssignmentId) return false;
      return targetAssignmentIds.contains(m.assignmentId);
    }).toList();

    for (final m in filteredMaterials) {
      final signIsReturn = m.isReturn;
      rawEntries.add(
        SubVendorLedgerEntry(
          id: 'mat_${m.id}',
          date: m.transactionDate,
          voucherType: signIsReturn ? 'Material Return' : 'Material Issue',
          particulars: signIsReturn
              ? 'Material Return Credit: ${m.itemName} (${m.quantity} ${m.unit})'
              : 'Material Issued: ${m.itemName} (${m.quantity} ${m.unit} @ ${_currency.format(m.unitRate)} + ${m.gstRate.toStringAsFixed(0)}% GST)',
          assignmentId: m.assignmentId,
          referenceNo: m.challanNumber ?? m.invoiceNumber ?? '-',
          paymentMode: 'Inventory',
          credit: signIsReturn ? m.totalAmount : 0.0,
          debit: signIsReturn ? 0.0 : m.totalAmount,
          remarks: m.remarks,
        ),
      );
    }

    // 3. SIYA Platform Charges (DEBITS) & 4. Statutory Net GST Liability (DEBITS)
    for (final a in targetAssignments) {
      // SIYA Platform fee (Installed Capacity × Rate per kW)
      final charges = a.siteCapacityKw * a.ratePerKw;
      if (charges > 0) {
        rawEntries.add(
          SubVendorLedgerEntry(
            id: 'siya_fee_${a.id}',
            date: a.assignedDate,
            voucherType: 'SIYA Platform Fee',
            particulars: 'SIYA Platform Charges (${a.siteCapacityKw} kW @ ${_currency.format(a.ratePerKw)}/kW) - ${a.customerName ?? "Site"} (CA: ${a.consumerNo ?? "N/A"})',
            siteName: a.customerName,
            consumerNo: a.consumerNo,
            assignmentId: a.id,
            referenceNo: 'SIYA-FEE',
            paymentMode: 'System Allocation',
            credit: 0.0,
            debit: charges,
          ),
        );
      }

      // Other approved site expenses
      if (a.otherExpenses > 0) {
        rawEntries.add(
          SubVendorLedgerEntry(
            id: 'exp_${a.id}',
            date: a.assignedDate,
            voucherType: 'Approved Site Expense',
            particulars: 'Site Operational / Transportation Expense - ${a.customerName ?? "Site"} (CA: ${a.consumerNo ?? "N/A"})',
            siteName: a.customerName,
            consumerNo: a.consumerNo,
            assignmentId: a.id,
            credit: 0.0,
            debit: a.otherExpenses,
          ),
        );
      }

      // Statutory Net GST Liability (70:30 Rule Output GST on full quotation minus Eligible Input ITC)
      final siteMaterials = materials.where((m) => m.assignmentId == a.id).toList();
      double mEligibleItc = 0.0;
      for (final m in siteMaterials) {
        final sign = m.isReturn ? -1.0 : 1.0;
        mEligibleItc += sign * m.signedItcEligible;
      }
      final outputGst7030 = a.gstBreakdown.totalGstIncluded;
      final netGst = (outputGst7030 - mEligibleItc) > 0 ? (outputGst7030 - mEligibleItc) : 0.0;

      if (netGst > 0) {
        rawEntries.add(
          SubVendorLedgerEntry(
            id: 'net_gst_${a.id}',
            date: a.assignedDate,
            voucherType: 'Statutory Net GST',
            particulars: 'Statutory Net GST Liability (70:30 Output GST ${_currency.format(outputGst7030)} - Material ITC ${_currency.format(mEligibleItc)}) - ${a.customerName ?? "Site"} (CA: ${a.consumerNo ?? "N/A"})',
            siteName: a.customerName,
            consumerNo: a.consumerNo,
            assignmentId: a.id,
            referenceNo: 'GST-7030',
            paymentMode: 'Tax Liability',
            credit: 0.0,
            debit: double.parse(netGst.toStringAsFixed(2)),
          ),
        );
      }
    }

    // 5. Contractual Approved GST Recoveries (DEBITS)
    final filteredRecoveries = gstRecoveries.where((r) {
      if (!r.isApproved && !r.isCollected) return false;
      if (filterAssignmentId != null && r.assignmentId != filterAssignmentId) return false;
      return targetAssignmentIds.contains(r.assignmentId);
    }).toList();

    for (final r in filteredRecoveries) {
      rawEntries.add(
        SubVendorLedgerEntry(
          id: 'gst_rec_${r.id}',
          date: r.recoveryDate,
          voucherType: 'Contractual GST Recovery',
          particulars: 'Approved Contractual GST Recovery (${r.remarks ?? "Audit Adjustment"})',
          assignmentId: r.assignmentId,
          referenceNo: r.invoiceNumber ?? 'VGR-${r.id.substring(0, 6)}',
          paymentMode: 'GST Recovery',
          credit: 0.0,
          debit: r.totalRecovery,
          remarks: r.remarks,
        ),
      );
    }

    // 6. Sub-Vendor Payouts / Advances Paid (DEBITS)
    final filteredPayouts = payouts.where((p) {
      if (p.status.toLowerCase() == 'rejected') return false;
      if (filterAssignmentId != null) {
        return p.assignmentId == filterAssignmentId || p.assignmentId == null;
      }
      return true;
    }).toList();

    for (final p in filteredPayouts) {
      rawEntries.add(
        SubVendorLedgerEntry(
          id: 'payout_${p.id}',
          date: p.payoutDate,
          voucherType: 'Vendor Payout / Advance',
          particulars: 'Payout / Advance Disbursed to Vendor via ${p.paymentMode}${p.bankName != null ? " (${p.bankName})" : ""}${p.remarks != null ? " - " + p.remarks! : ""}',
          assignmentId: p.assignmentId,
          referenceNo: p.referenceNumber ?? '-',
          paymentMode: p.paymentMode,
          credit: 0.0,
          debit: p.amount,
          remarks: p.remarks,
        ),
      );
    }

    // 7. Sort Chronologically (by Date ASC)
    rawEntries.sort((a, b) {
      final cmp = a.date.compareTo(b.date);
      if (cmp != 0) return cmp;
      // In case of same date, credits come first, then debits
      if (a.isCredit && !b.isCredit) return -1;
      if (!a.isCredit && b.isCredit) return 1;
      return a.id.compareTo(b.id);
    });

    // 8. Filter by Date Range (if supplied) and calculate running balance
    double currentBalance = 0.0;
    double totalCredit = 0.0;
    double totalDebit = 0.0;
    final List<SubVendorLedgerEntry> finalEntries = [];

    for (final entry in rawEntries) {
      currentBalance += (entry.credit - entry.debit);
      final withBal = entry.copyWithRunningBalance(double.parse(currentBalance.toStringAsFixed(2)));

      final bool afterStart = fromDate == null || !entry.date.isBefore(fromDate);
      final bool beforeEnd = toDate == null || !entry.date.isAfter(toDate);

      if (afterStart && beforeEnd) {
        totalCredit += entry.credit;
        totalDebit += entry.debit;
        finalEntries.add(withBal);
      }
    }

    return SubVendorLedgerSummary(
      vendorId: vendorId,
      vendorName: vendorName,
      vendorCode: vendorCode,
      totalCredit: double.parse(totalCredit.toStringAsFixed(2)),
      totalDebit: double.parse(totalDebit.toStringAsFixed(2)),
      closingBalance: double.parse(currentBalance.toStringAsFixed(2)),
      entries: finalEntries,
      fromDate: fromDate,
      toDate: toDate,
    );
  }
}
