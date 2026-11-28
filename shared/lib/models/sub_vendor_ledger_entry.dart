import 'package:intl/intl.dart';
import '../services/sub_vendor_financial_engine.dart';
import 'vendor_site_assignment.dart';
import 'vendor_material_transaction.dart';
import 'vendor_payout.dart';
import 'vendor_customer_payment.dart';
import 'vendor_gst_recovery.dart';
import 'sub_vendor_material_outward.dart';
import 'sub_vendor_account_ledger.dart';

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

  /// Value date (standard banking passbook field, defaults to transaction date)
  DateTime get valueDate => date;

  /// Bank indicator for running balance: 'Cr' for positive/payable, 'Dr' for negative/recoverable
  String get balanceIndicator => runningBalance >= -0.001 ? 'Cr' : 'Dr';

  /// Bank passbook style transaction narration (e.g. 'BY LOAN...', 'TO MATERIAL...')
  String get bankNarration {
    final clean = particulars.trim();
    if (clean.toUpperCase().startsWith('BY ') || clean.toUpperCase().startsWith('TO ')) {
      return clean;
    }
    return isCredit ? 'BY $clean' : 'TO $clean';
  }

  /// Tally Prime standard voucher type: Receipt, Payment, Journal, Purchase, Debit Note
  String get tallyVoucherType {
    switch (voucherType) {
      case 'Bank Loan Credit':
      case 'Customer Cash Credit':
      case 'Customer Collection':
        return 'Receipt';
      case 'Vendor Payout / Advance':
        return 'Payment';
      case 'Material Return':
        return 'Debit Note';
      case 'Material Issue':
        return 'Purchase';
      case 'SIYA Platform Fee':
      case 'Statutory Net GST':
      case 'Contractual GST Recovery':
      case 'Approved Site Expense':
      default:
        return 'Journal';
    }
  }

  /// Tally Prime double-entry particulars format ('To ...' for Debit, 'By ...' for Credit)
  String get tallyParticulars {
    final clean = particulars.trim();
    if (clean.startsWith('To ') || clean.startsWith('By ')) {
      return clean;
    }
    return isCredit ? 'By $clean' : 'To $clean';
  }

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
  String get closingBalanceIndicator => closingBalance >= -0.001 ? 'Cr' : 'Dr';

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
    List<SubVendorMaterialOutward> materialOutwards = const [],
    List<SubVendorAccountLedgerEntry> accountLedgerEntries = const [],
    String? filterAssignmentId,
    DateTime? fromDate,
    DateTime? toDate,
  }) {
    final List<SubVendorLedgerEntry> rawEntries = [];

    // Filter assignments if specific site requested (exclude Cancelled)
    final targetAssignments = (filterAssignmentId != null
            ? assignments.where((a) => a.id == filterAssignmentId)
            : assignments)
        .where((a) => a.status.trim().toLowerCase() != 'cancelled')
        .toList();

    final targetAssignmentIds = targetAssignments.map((a) => a.id).toSet();

    // 1. Customer Payments (Bank Loan & Cash Realized Collections -> CREDITS)
    //    Emit itemized approved payments AND reconcile any residual un-itemized Cash/Loan on assignment.
    final filteredPayments = customerPayments.where((cp) {
      if (filterAssignmentId != null && cp.assignmentId != filterAssignmentId) return false;
      return targetAssignmentIds.contains(cp.assignmentId);
    }).toList();

    final Map<String, int> capturedSumPaiseByAssign = {};

    for (final cp in filteredPayments) {
      if (!cp.isApproved) continue;
      capturedSumPaiseByAssign[cp.assignmentId] =
          (capturedSumPaiseByAssign[cp.assignmentId] ?? 0) +
              SubVendorFinancialEngine.toPaise(cp.amount);

      rawEntries.add(
        SubVendorLedgerEntry(
          id: 'cp_${cp.id}',
          date: SubVendorFinancialEngine.normalizeDate(cp.paymentDate),
          voucherType: cp.isLoan ? 'Bank Loan Credit' : 'Customer Cash Credit',
          particulars: cp.isLoan
              ? 'Bank Loan Credited - ${cp.customerName ?? "Customer"} (CA: ${cp.consumerNo ?? "N/A"})'
              : 'Customer Advance/Cash - ${cp.customerName ?? "Customer"} (CA: ${cp.consumerNo ?? "N/A"})',
          siteName: cp.customerName,
          consumerNo: cp.consumerNo,
          assignmentId: cp.assignmentId,
          referenceNo: cp.referenceNumber ?? cp.loanApplicationId ?? '-',
          paymentMode: cp.paymentMode,
          credit: SubVendorFinancialEngine.round2(cp.amount),
          debit: 0.0,
          remarks: cp.remarks,
        ),
      );
    }

    for (final a in targetAssignments) {
      final totalRecvP = SubVendorFinancialEngine.toPaise(a.effectiveReceivedAmount);
      final alreadyP = capturedSumPaiseByAssign[a.id] ?? 0;
      final residualP = totalRecvP - alreadyP;
      if (residualP > 1) {
        final residual = SubVendorFinancialEngine.fromPaise(residualP);
        rawEntries.add(
          SubVendorLedgerEntry(
            id: 'a_coll_${a.id}',
            date: SubVendorFinancialEngine.normalizeDate(a.assignedDate),
            voucherType: alreadyP > 0
                ? 'Customer Cash Credit'
                : (a.isBankLoan ? 'Bank Loan Credit' : 'Customer Collection'),
            particulars: alreadyP > 0
                ? 'Additional Customer Collection Credited to SIYA - ${a.customerName ?? "Site"} (CA: ${a.consumerNo ?? "N/A"})'
                : 'Realized Collections Credited to SIYA - ${a.customerName ?? "Site"} (CA: ${a.consumerNo ?? "N/A"})',
            siteName: a.customerName,
            consumerNo: a.consumerNo,
            assignmentId: a.id,
            referenceNo: a.loanApplicationId ?? a.consumerNo ?? '-',
            paymentMode: alreadyP > 0 ? 'Cash / Other' : a.paymentType,
            credit: residual,
            debit: 0.0,
            remarks: 'Site Realized Collection',
          ),
        );
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

    // 6. Sub-Vendor Payouts / Advances Paid (DEBITS — Approved / Paid ONLY)
    final filteredPayouts = payouts.where((p) {
      if (!SubVendorFinancialEngine.isDisbursedPayout(p)) return false;
      if (filterAssignmentId != null) {
        return p.assignmentId == filterAssignmentId ||
            (p.assignmentId == null && targetAssignments.length == 1);
      }
      return true;
    }).toList();

    for (final p in filteredPayouts) {
      rawEntries.add(
        SubVendorLedgerEntry(
          id: 'payout_${p.id}',
          date: SubVendorFinancialEngine.normalizeDate(p.payoutDate),
          voucherType: 'Vendor Payout / Advance',
          particulars: 'Payout / Advance Disbursed to Vendor via ${p.paymentMode}${p.bankName != null ? " (${p.bankName})" : ""}${p.remarks != null ? " - " + p.remarks! : ""}',
          assignmentId: p.assignmentId,
          referenceNo: p.referenceNumber ?? '-',
          paymentMode: p.paymentMode,
          credit: 0.0,
          debit: SubVendorFinancialEngine.round2(p.amount),
          remarks: p.remarks,
        ),
      );
    }

    // 6B. Material Outward Entries (DEBITS - Maal Dila) & Manual Account Ledger Payments (CREDITS/DEBITS)
    if (filterAssignmentId == null) {
      final Set<String> rawOutwardKeys = {};
      for (final out in materialOutwards) {
        if (!out.isActive) continue;
        final outKey = '${out.vendorId}::${out.outwardNumber.trim().toUpperCase()}';
        if (out.outwardNumber.trim().isNotEmpty) rawOutwardKeys.add(outKey);
        rawEntries.add(
          SubVendorLedgerEntry(
            id: 'outward_${out.id}',
            date: SubVendorFinancialEngine.normalizeDate(out.outwardDate),
            voucherType: 'Material Outward',
            particulars: 'Material Outward (${out.totalItems} items, Qty: ${out.totalQuantity.toStringAsFixed(1)}) - ${out.outwardNumber}',
            referenceNo: out.outwardNumber,
            paymentMode: 'Outward',
            credit: 0.0,
            debit: SubVendorFinancialEngine.round2(out.totalValue),
            remarks: out.remarks,
          ),
        );
      }

      final Set<String> rawMaterialIds = materials.map((m) => m.id).toSet();
      final Set<String> rawOutwardIds = materialOutwards.map((o) => o.id).toSet();
      final Set<String> rawPaymentIds = customerPayments.map((p) => p.id).toSet();
      final Set<String> rawPayoutIds = payouts.map((p) => p.id).toSet();
      final Set<String> rawAssignmentIds = assignments.map((a) => a.id).toSet();

      for (final rawLe in accountLedgerEntries) {
        final le = SubVendorFinancialEngine.normalizeLedgerEntryPolarity(rawLe);
        if (!le.isActive) continue;
        final tType = le.transactionType.toUpperCase();
        // Skip synthesized rows already sourced directly from dedicated tables above
        if (le.id.startsWith('cp_') ||
            le.id.startsWith('a_coll_') ||
            le.id.startsWith('vp_') ||
            le.id.startsWith('vmt_') ||
            le.id.startsWith('mo_') ||
            le.id.startsWith('cpt_')) {
          continue;
        }
        final refId = le.referenceId;
        if (refId != null &&
            (rawMaterialIds.contains(refId) ||
                rawOutwardIds.contains(refId) ||
                rawPaymentIds.contains(refId) ||
                rawPayoutIds.contains(refId) ||
                rawAssignmentIds.contains(refId))) {
          continue;
        }
        final refKey = '${le.vendorId}::${le.referenceNumber.trim().toUpperCase()}';
        if (tType == 'MATERIAL_OUTWARD' &&
            le.referenceNumber.trim().isNotEmpty &&
            rawOutwardKeys.contains(refKey)) {
          continue;
        }

        if (tType == 'MATERIAL_PAYMENT' || tType == 'ADVANCE_REFUND') {
          rawEntries.add(
            SubVendorLedgerEntry(
              id: 'acct_pay_${le.id}',
              date: SubVendorFinancialEngine.normalizeDate(le.transactionDate),
              voucherType: tType == 'ADVANCE_REFUND'
                  ? 'Advance / Deposit Refund'
                  : 'Sub-Vendor Payment Credit',
              particulars: '${le.particulars}${le.remarks != null && le.remarks!.isNotEmpty ? " - ${le.remarks}" : ""}',
              referenceNo: le.referenceNumber,
              paymentMode: le.paymentMode,
              credit: SubVendorFinancialEngine.round2(le.creditAmount),
              debit: 0.0,
              remarks: le.remarks,
            ),
          );
        } else if (tType == 'ADVANCE_GIVEN' || tType == 'MATERIAL_OUTWARD') {
          rawEntries.add(
            SubVendorLedgerEntry(
              id: tType == 'MATERIAL_OUTWARD'
                  ? 'acct_out_${le.id}'
                  : 'acct_adv_${le.id}',
              date: SubVendorFinancialEngine.normalizeDate(le.transactionDate),
              voucherType: tType == 'MATERIAL_OUTWARD'
                  ? 'Material Outward'
                  : 'Vendor Payout / Advance',
              particulars: '${le.particulars}${le.remarks != null && le.remarks!.isNotEmpty ? " - ${le.remarks}" : ""}',
              referenceNo: le.referenceNumber,
              paymentMode: le.paymentMode,
              credit: 0.0,
              debit: SubVendorFinancialEngine.round2(le.debitAmount),
              remarks: le.remarks,
            ),
          );
        }
      }
    }

    // 7. Sort Chronologically (by normalized calendar Date ASC)
    rawEntries.sort((a, b) {
      final cmp = SubVendorFinancialEngine.normalizeDate(a.date)
          .compareTo(SubVendorFinancialEngine.normalizeDate(b.date));
      if (cmp != 0) return cmp;
      if (a.isCredit && !b.isCredit) return -1;
      if (!a.isCredit && b.isCredit) return 1;
      return a.id.compareTo(b.id);
    });

    // 8. Compute true Opening Balance (prior to fromDate), period totals, and Closing Balance
    final DateTime? normFrom =
        fromDate != null ? SubVendorFinancialEngine.normalizeDate(fromDate) : null;
    final DateTime? normTo =
        toDate != null ? SubVendorFinancialEngine.normalizeDate(toDate) : null;

    int currentBalancePaise = 0;
    int openingBalancePaise = 0;
    int periodCreditPaise = 0;
    int periodDebitPaise = 0;
    final List<SubVendorLedgerEntry> finalEntries = [];

    for (final entry in rawEntries) {
      final entryDate = SubVendorFinancialEngine.normalizeDate(entry.date);
      final crP = SubVendorFinancialEngine.toPaise(entry.credit);
      final drP = SubVendorFinancialEngine.toPaise(entry.debit);

      currentBalancePaise += (crP - drP);
      final withBal = entry.copyWithRunningBalance(
          SubVendorFinancialEngine.fromPaise(currentBalancePaise));

      if (normFrom != null && entryDate.isBefore(normFrom)) {
        openingBalancePaise += (crP - drP);
        continue;
      }
      if (normTo != null && entryDate.isAfter(normTo)) {
        continue;
      }

      periodCreditPaise += crP;
      periodDebitPaise += drP;
      finalEntries.add(withBal);
    }

    final closingPaise = openingBalancePaise + periodCreditPaise - periodDebitPaise;

    return SubVendorLedgerSummary(
      vendorId: vendorId,
      vendorName: vendorName,
      vendorCode: vendorCode,
      openingBalance: SubVendorFinancialEngine.fromPaise(openingBalancePaise),
      totalCredit: SubVendorFinancialEngine.fromPaise(periodCreditPaise),
      totalDebit: SubVendorFinancialEngine.fromPaise(periodDebitPaise),
      closingBalance: SubVendorFinancialEngine.fromPaise(closingPaise),
      entries: finalEntries,
      fromDate: normFrom,
      toDate: normTo,
    );
  }
}

