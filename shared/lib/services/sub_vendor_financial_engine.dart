import 'dart:math' as math;
import 'package:intl/intl.dart';
import '../models/sub_vendor_account_ledger.dart';
import '../models/sub_vendor_material_outward.dart';
import '../models/vendor_customer_payment.dart';
import '../models/vendor_material_transaction.dart';
import '../models/vendor_payout.dart';
import '../models/vendor_site_assignment.dart';

/// Decimal-safe financial calculation result for a single Material Outward row.
class MaterialOutwardRowCalculation {
  final double quantity;
  final double ratePerUnit;
  final double gstPercentage;
  final double baseAmount;
  final double gstAmount;
  final double finalAmount;

  const MaterialOutwardRowCalculation({
    required this.quantity,
    required this.ratePerUnit,
    required this.gstPercentage,
    required this.baseAmount,
    required this.gstAmount,
    required this.finalAmount,
  });
}

/// Decimal-safe multi-row financial rollup for a Material Outward voucher.
class MaterialOutwardTotalsCalculation {
  final int totalItems;
  final double totalQuantity;
  final double subtotal;
  final double totalGst;
  final double grandTotal;
  final Map<double, double> gstByRate;

  const MaterialOutwardTotalsCalculation({
    required this.totalItems,
    required this.totalQuantity,
    required this.subtotal,
    required this.totalGst,
    required this.grandTotal,
    this.gstByRate = const {},
  });
}

/// GST and ITC classification breakdown for materials.
class MaterialGstBreakdownResult {
  final double material5Taxable;
  final double material5Gst;
  final double material5Total;

  final double material18Taxable;
  final double material18Gst;
  final double material18Total;

  final double otherAndZeroTaxable;
  final double otherAndZeroGst;
  final double otherAndZeroTotal;

  final double totalTaxable;
  final double totalInvoiceGst;
  final double totalEligibleInputGst;
  final double totalIneligibleInputGst;
  final double totalMaterialCost;

  const MaterialGstBreakdownResult({
    required this.material5Taxable,
    required this.material5Gst,
    required this.material5Total,
    required this.material18Taxable,
    required this.material18Gst,
    required this.material18Total,
    this.otherAndZeroTaxable = 0.0,
    this.otherAndZeroGst = 0.0,
    this.otherAndZeroTotal = 0.0,
    required this.totalTaxable,
    required this.totalInvoiceGst,
    required this.totalEligibleInputGst,
    this.totalIneligibleInputGst = 0.0,
    required this.totalMaterialCost,
  });
}

/// Normalized ledger extraction result used consistently by Dashboards,
/// Summaries, PDFs, CSVs, and Settlement calculators without double counting.
class SubVendorCentralLedgerExtras {
  final double activeOutwardCost;
  final double activeOutwardSubtotal;
  final double activeOutwardGst;
  final double manualLedgerOutwardCost;
  final double directVendorPayments;
  final double directAdvancesGiven;
  final double directAdvanceRefunds;

  const SubVendorCentralLedgerExtras({
    this.activeOutwardCost = 0.0,
    this.activeOutwardSubtotal = 0.0,
    this.activeOutwardGst = 0.0,
    this.manualLedgerOutwardCost = 0.0,
    this.directVendorPayments = 0.0,
    this.directAdvancesGiven = 0.0,
    this.directAdvanceRefunds = 0.0,
  });

  double get totalOutwardCost =>
      SubVendorFinancialEngine.round2(activeOutwardCost + manualLedgerOutwardCost);
}

/// Period-grouped financial summary (Daily, Monthly, Financial Year).
class PeriodReconciliationSummary {
  final String periodKey;
  final String periodLabel;
  final int entryCount;
  final double totalQuantity;
  final double subtotal;
  final double totalGst;
  final double grandTotal;
  final double totalCredit;
  final double totalDebit;
  final double netEffect;

  const PeriodReconciliationSummary({
    required this.periodKey,
    required this.periodLabel,
    this.entryCount = 0,
    this.totalQuantity = 0.0,
    this.subtotal = 0.0,
    this.totalGst = 0.0,
    this.grandTotal = 0.0,
    this.totalCredit = 0.0,
    this.totalDebit = 0.0,
    this.netEffect = 0.0,
  });
}

/// Reconciled Passbook balances split explicitly per Accounting Section rules.
class SubVendorSeparatedBalances {
  final double openingBalance;
  final double totalCredit;
  final double totalDebit;
  final double netBalance; // Opening + Credit - Debit (+ Cr = Payable, - Dr = Receivable)

  final double totalMaterialOutward;
  final double totalMaterialPaymentsReceived;
  final double materialReceivableBalance; // Outward - Payments Received (+ = Receivable from Vendor)

  final double totalAdvanceGiven;
  final double totalAdvanceRefundReceived;
  final double advanceBalance; // Advance Given - Advance Refund (+ = Advance lying with Vendor)

  const SubVendorSeparatedBalances({
    this.openingBalance = 0.0,
    required this.totalCredit,
    required this.totalDebit,
    required this.netBalance,
    required this.totalMaterialOutward,
    required this.totalMaterialPaymentsReceived,
    required this.materialReceivableBalance,
    required this.totalAdvanceGiven,
    required this.totalAdvanceRefundReceived,
    required this.advanceBalance,
  });

  bool get isPayable => netBalance > 0.001;
  bool get isReceivable => netBalance < -0.001;
}

/// Centralized, decimal-safe Calculation & Reconciliation Engine for the entire
/// Sub-Vendor Module across Web Admin, Sub-Vendor Portal, Mobile App, PDFs, and CSVs.
///
/// Standardized Sign Convention (Party Passbook / Option A):
/// - Credit (+ Cr): Increases balance payable to Sub-Vendor / reduces vendor debit
///   (Customer Collections, Bank Loan Credits, Material Returns, Material Payments
///    received from Sub-Vendor, Advance Refunds received from Sub-Vendor).
/// - Debit (- Dr): Increases deduction or receivable from Sub-Vendor
///   (Material Outward, Site Material Issues, SIYA Charges, Approved Expenses,
///    Statutory Net GST, Approved Contractual GST Recoveries, Payouts & Advances Given).
class SubVendorFinancialEngine {
  static final NumberFormat currencyFormatter = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 2,
  );

  static final NumberFormat pdfCurrencyFormatter = NumberFormat.currency(
    locale: 'en_IN',
    symbol: 'Rs. ',
    decimalDigits: 2,
  );

  /// Format an amount cleanly in Indian Rupees (e.g., ₹1,34,440.26).
  static String formatCurrency(double amount, {bool asciiPrefix = false}) {
    final val = round2(amount);
    return asciiPrefix ? pdfCurrencyFormatter.format(val) : currencyFormatter.format(val);
  }

  /// Convert rupee amount to integer paise to prevent IEEE-754 drift.
  static int toPaise(double amount) {
    if (amount.isNaN || amount.isInfinite) return 0;
    return (amount * 100.0).round();
  }

  /// Convert integer paise back to rounded rupees.
  static double fromPaise(int paise) => paise / 100.0;

  /// Round strictly to 2 decimal places using paise arithmetic.
  static double round2(double value) => fromPaise(toPaise(value));

  /// Sum an iterable of doubles in exact integer paise.
  static double sumPaise<T>(Iterable<T> items, double Function(T item) selector) {
    int total = 0;
    for (final item in items) {
      total += toPaise(selector(item));
    }
    return fromPaise(total);
  }

  /// Normalize any DateTime (including UTC timestamps) to local calendar midnight
  /// so date filters never drop boundary-day transactions due to timezone offsets.
  static DateTime normalizeDate(DateTime dt) {
    final local = dt.isUtc ? dt.toLocal() : dt;
    return DateTime(local.year, local.month, local.day);
  }

  /// Parse dynamic date inputs safely into local calendar date.
  static DateTime parseCalendarDate(dynamic value, {DateTime? fallback}) {
    if (value is DateTime) return normalizeDate(value);
    if (value != null) {
      final raw = value.toString().trim();
      if (raw.isNotEmpty) {
        final dateOnlyMatch = RegExp(r'^(\d{4})-(\d{2})-(\d{2})').firstMatch(raw);
        if (dateOnlyMatch != null && !raw.contains('T')) {
          final y = int.parse(dateOnlyMatch.group(1)!);
          final m = int.parse(dateOnlyMatch.group(2)!);
          final d = int.parse(dateOnlyMatch.group(3)!);
          return DateTime(y, m, d);
        }
        final parsed = DateTime.tryParse(raw);
        if (parsed != null) return normalizeDate(parsed);
      }
    }
    return normalizeDate(fallback ?? DateTime.now());
  }

  /// Inclusive calendar-date range check.
  static bool isWithinDateRange(
    DateTime date, {
    DateTime? fromDate,
    DateTime? toDate,
  }) {
    final target = normalizeDate(date);
    if (fromDate != null && target.isBefore(normalizeDate(fromDate))) {
      return false;
    }
    if (toDate != null && target.isAfter(normalizeDate(toDate))) {
      return false;
    }
    return true;
  }

  static String dayKey(DateTime date) {
    final d = normalizeDate(date);
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  static String monthKey(DateTime date) {
    final d = normalizeDate(date);
    return '${d.year}-${d.month.toString().padLeft(2, '0')}';
  }

  static String monthLabel(DateTime date) => DateFormat('MMM yyyy').format(normalizeDate(date));

  /// Indian Financial Year (April 1 to March 31).
  static String financialYearKey(DateTime date) {
    final d = normalizeDate(date);
    final startYear = d.month >= 4 ? d.year : d.year - 1;
    final endSuffix = (startYear + 1).toString().substring(2);
    return 'FY $startYear-$endSuffix';
  }

  // ---------------------------------------------------------------------------
  // 1. MATERIAL OUTWARD ROW & TOTAL CALCULATIONS
  // ---------------------------------------------------------------------------

  /// Calculates a single Material Outward row with exact 2-decimal rounding:
  /// Base = round2(Qty * Rate)
  /// GST = round2(Base * GST% / 100)
  /// Final = round2(Base + GST)
  static MaterialOutwardRowCalculation calculateOutwardRow({
    required double quantity,
    required double ratePerUnit,
    double gstPercentage = 0.0,
  }) {
    final safeQty = quantity < 0 ? 0.0 : quantity;
    final safeRate = ratePerUnit < 0 ? 0.0 : ratePerUnit;
    final safeGstPct = gstPercentage < 0 ? 0.0 : gstPercentage;

    final base = round2(safeQty * safeRate);
    final gstAmt = safeGstPct == 0.0 ? 0.0 : round2(base * (safeGstPct / 100.0));
    final finalAmt = round2(base + gstAmt);

    return MaterialOutwardRowCalculation(
      quantity: round2(safeQty),
      ratePerUnit: round2(safeRate),
      gstPercentage: round2(safeGstPct),
      baseAmount: base,
      gstAmount: gstAmt,
      finalAmount: finalAmt,
    );
  }

  /// Normalizes every outward line item so stored base/gst/total match exact formula.
  static List<SubVendorMaterialOutwardItem> normalizeOutwardItems(
    List<SubVendorMaterialOutwardItem> items, {
    String? outwardId,
  }) {
    return items.map((item) {
      final calc = calculateOutwardRow(
        quantity: item.quantity,
        ratePerUnit: item.unitRate,
        gstPercentage: item.gstPercentage,
      );
      return item.copyWith(
        outwardId: outwardId ?? item.outwardId,
        quantity: item.quantity,
        unitRate: calc.ratePerUnit,
        baseAmount: calc.baseAmount,
        gstPercentage: calc.gstPercentage,
        gstAmount: calc.gstAmount,
        totalPrice: calc.finalAmount,
      );
    }).toList();
  }

  /// Aggregates multi-row Material Outward totals in exact paise so that:
  /// Subtotal = sum(row.baseAmount), Total GST = sum(row.gstAmount),
  /// Grand Total = Subtotal + Total GST.
  static MaterialOutwardTotalsCalculation calculateOutwardTotals(
    List<SubVendorMaterialOutwardItem> items,
  ) {
    int qtyPaise = 0;
    int subPaise = 0;
    int gstPaise = 0;
    final Map<double, int> gstBucketsPaise = {};

    for (final item in items) {
      final row = calculateOutwardRow(
        quantity: item.quantity,
        ratePerUnit: item.unitRate,
        gstPercentage: item.gstPercentage,
      );
      qtyPaise += toPaise(item.quantity);
      subPaise += toPaise(row.baseAmount);
      final rowGstP = toPaise(row.gstAmount);
      gstPaise += rowGstP;
      gstBucketsPaise[row.gstPercentage] =
          (gstBucketsPaise[row.gstPercentage] ?? 0) + rowGstP;
    }

    return MaterialOutwardTotalsCalculation(
      totalItems: items.length,
      totalQuantity: fromPaise(qtyPaise),
      subtotal: fromPaise(subPaise),
      totalGst: fromPaise(gstPaise),
      grandTotal: fromPaise(subPaise + gstPaise),
      gstByRate: {
        for (final e in gstBucketsPaise.entries) e.key: fromPaise(e.value),
      },
    );
  }

  // ---------------------------------------------------------------------------
  // 2. STATUS, COLLECTION & DYNAMIC SITE MATERIAL GST HELPERS
  // ---------------------------------------------------------------------------

  /// Only 'Approved' and 'Paid' payouts (or legacy blank) reduce payable balance.
  /// Excludes 'Pending', 'Rejected', and 'Cancelled'.
  static bool isDisbursedPayout(VendorPayout payout) {
    final st = payout.status.trim().toLowerCase();
    return st.isEmpty || st == 'paid' || st == 'approved';
  }

  /// Reconciles site realized collections consistently with SQL GREATEST rule.
  static double reconcileSiteReceivedAmount(
    VendorSiteAssignment assignment, {
    List<VendorCustomerPayment> siteCustomerPayments = const [],
  }) {
    final storedMax = math.max(
      assignment.totalCustomerReceived,
      assignment.customerPaidAmount,
    );
    int approvedCpPaise = 0;
    for (final cp in siteCustomerPayments) {
      if (cp.assignmentId == assignment.id && cp.isApproved) {
        approvedCpPaise += toPaise(cp.amount);
      }
    }
    return round2(math.max(storedMax, fromPaise(approvedCpPaise)));
  }

  /// Classifies Site Materials (`VendorMaterialTransaction`) by actual GST rate
  /// and `isItcEligible` flag without misrouting 0% GST items into 18%.
  static MaterialGstBreakdownResult classifySiteMaterialsGst(
    List<VendorMaterialTransaction> materials,
  ) {
    int m5Tax = 0, m5Gst = 0;
    int m18Tax = 0, m18Gst = 0;
    int mOtherTax = 0, mOtherGst = 0;
    int eligibleItc = 0, ineligibleItc = 0;

    for (final item in materials) {
      final sign = item.isReturn ? -1 : 1;
      final rate = item.gstRate;
      final taxP = sign * toPaise(item.taxableAmount);
      final gstP = sign * toPaise(item.gstAmount);

      if ((rate - 5.0).abs() < 0.01) {
        m5Tax += taxP;
        m5Gst += gstP;
      } else if ((rate - 18.0).abs() < 0.01) {
        m18Tax += taxP;
        m18Gst += gstP;
      } else {
        mOtherTax += taxP;
        mOtherGst += gstP;
      }

      if (item.isItcEligible) {
        eligibleItc += gstP;
      } else {
        ineligibleItc += gstP;
      }
    }

    final m5Tot = m5Tax + m5Gst;
    final m18Tot = m18Tax + m18Gst;
    final mOtherTot = mOtherTax + mOtherGst;
    final totTax = m5Tax + m18Tax + mOtherTax;
    final totGst = m5Gst + m18Gst + mOtherGst;

    return MaterialGstBreakdownResult(
      material5Taxable: fromPaise(m5Tax),
      material5Gst: fromPaise(m5Gst),
      material5Total: fromPaise(m5Tot),
      material18Taxable: fromPaise(m18Tax),
      material18Gst: fromPaise(m18Gst),
      material18Total: fromPaise(m18Tot),
      otherAndZeroTaxable: fromPaise(mOtherTax),
      otherAndZeroGst: fromPaise(mOtherGst),
      otherAndZeroTotal: fromPaise(mOtherTot),
      totalTaxable: fromPaise(totTax),
      totalInvoiceGst: fromPaise(totGst),
      totalEligibleInputGst: fromPaise(eligibleItc),
      totalIneligibleInputGst: fromPaise(ineligibleItc),
      totalMaterialCost: fromPaise(totTax + totGst),
    );
  }

  // ---------------------------------------------------------------------------
  // 3. PASSBOOK POLARITY & CENTRAL DEDUPLICATION
  // ---------------------------------------------------------------------------

  /// Ensures any ledger entry (including legacy pre-000051 inverted rows)
  /// resolves cleanly under Standard Party Passbook Credit/Debit rules.
  static SubVendorAccountLedgerEntry normalizeLedgerEntryPolarity(
    SubVendorAccountLedgerEntry entry,
  ) {
    if (entry.id.startsWith('cp_') ||
        entry.id.startsWith('cpt_') ||
        entry.id.startsWith('a_coll_') ||
        entry.id.startsWith('vmt_') ||
        entry.id.startsWith('mo_') ||
        entry.id.startsWith('vp_')) {
      return entry;
    }

    final tType = entry.transactionType.toUpperCase();
    final absAmount = entry.creditAmount > 0.001
        ? entry.creditAmount
        : entry.debitAmount;

    if (tType == 'MATERIAL_PAYMENT' || tType == 'ADVANCE_REFUND') {
      if (entry.creditAmount > 0.001 && entry.debitAmount <= 0.001) return entry;
      return entry.copyWith(creditAmount: absAmount, debitAmount: 0.0);
    }

    if (tType == 'MATERIAL_OUTWARD' || tType == 'ADVANCE_GIVEN') {
      if (entry.debitAmount > 0.001 && entry.creditAmount <= 0.001) return entry;
      return entry.copyWith(creditAmount: 0.0, debitAmount: absAmount);
    }

    return entry;
  }

  /// Extracts non-duplicated Outwards & Direct Ledger figures for a vendor
  /// (consistent across Dashboard, Summaries, Settlement, and Mobile).
  static SubVendorCentralLedgerExtras extractCentralExtras({
    String? vendorIdFilter,
    List<SubVendorMaterialOutward> materialOutwards = const [],
    List<SubVendorAccountLedgerEntry> accountLedgerEntries = const [],
    Set<String> knownRawIds = const {},
  }) {
    int outwardCostP = 0;
    int outwardSubP = 0;
    int outwardGstP = 0;
    int manualOutwardP = 0;
    int directPaymentsP = 0;
    int directAdvancesP = 0;
    int directRefundsP = 0;

    final Set<String> outwardIds = {};
    final Set<String> outwardVendorKeys = {};

    for (final o in materialOutwards) {
      if (vendorIdFilter != null && o.vendorId != vendorIdFilter) continue;
      if (!o.isActive) continue;
      if (o.id.isNotEmpty) outwardIds.add(o.id);
      final outNo = o.outwardNumber.trim().toUpperCase();
      if (outNo.isNotEmpty) outwardVendorKeys.add('${o.vendorId}::$outNo');

      if (o.items.isNotEmpty) {
        final calc = calculateOutwardTotals(o.items);
        outwardSubP += toPaise(calc.subtotal);
        outwardGstP += toPaise(calc.totalGst);
        outwardCostP += toPaise(calc.grandTotal);
      } else {
        outwardSubP += toPaise(o.subtotal > 0 ? o.subtotal : o.totalValue);
        outwardGstP += toPaise(o.totalGst);
        outwardCostP += toPaise(o.totalValue);
      }
    }

    final Set<String> allKnownRefs = {...knownRawIds, ...outwardIds};
    final Set<String> seenDirectIds = {};

    for (final raw in accountLedgerEntries) {
      final le = normalizeLedgerEntryPolarity(raw);
      if (!le.isActive) continue;
      if (vendorIdFilter != null && le.vendorId != vendorIdFilter) continue;
      if (le.id.isNotEmpty && !seenDirectIds.add(le.id)) continue;

      if (le.id.startsWith('mo_') ||
          le.id.startsWith('vmt_') ||
          le.id.startsWith('cp_') ||
          le.id.startsWith('cpt_') ||
          le.id.startsWith('a_coll_') ||
          le.id.startsWith('vp_')) {
        continue;
      }

      if (le.referenceId != null && allKnownRefs.contains(le.referenceId)) {
        continue;
      }

      final tType = le.transactionType.toUpperCase();
      final outKey = '${le.vendorId}::${le.referenceNumber.trim().toUpperCase()}';
      if (tType == 'MATERIAL_OUTWARD' &&
          le.referenceNumber.trim().isNotEmpty &&
          outwardVendorKeys.contains(outKey)) {
        continue;
      }

      if (tType == 'MATERIAL_PAYMENT') {
        directPaymentsP += toPaise(le.creditAmount);
      } else if (tType == 'ADVANCE_GIVEN') {
        directAdvancesP += toPaise(le.debitAmount);
      } else if (tType == 'ADVANCE_REFUND') {
        directRefundsP += toPaise(le.creditAmount);
      } else if (tType == 'MATERIAL_OUTWARD') {
        manualOutwardP += toPaise(le.debitAmount);
      }
    }

    return SubVendorCentralLedgerExtras(
      activeOutwardCost: fromPaise(outwardCostP),
      activeOutwardSubtotal: fromPaise(outwardSubP),
      activeOutwardGst: fromPaise(outwardGstP),
      manualLedgerOutwardCost: fromPaise(manualOutwardP),
      directVendorPayments: fromPaise(directPaymentsP),
      directAdvancesGiven: fromPaise(directAdvancesP),
      directAdvanceRefunds: fromPaise(directRefundsP),
    );
  }

  /// Compute Passbook opening/period/closing & separated Material vs Advance
  /// balances for any ledger entry list (supports arbitrary date boundaries).
  static SubVendorSeparatedBalances calculatePassbookBalances(
    List<SubVendorAccountLedgerEntry> allEntries, {
    String? vendorId,
    DateTime? fromDate,
    DateTime? toDate,
  }) {
    final active = allEntries
        .map(normalizeLedgerEntryPolarity)
        .where((e) => e.isActive && (vendorId == null || vendorId == 'All' || e.vendorId == vendorId))
        .toList()
      ..sort((a, b) {
        final dCmp = normalizeDate(a.transactionDate).compareTo(normalizeDate(b.transactionDate));
        if (dCmp != 0) return dCmp;
        final cA = a.createdAt;
        final cB = b.createdAt;
        if (cA != null && cB != null) {
          final cCmp = cA.compareTo(cB);
          if (cCmp != 0) return cCmp;
        }
        return a.id.compareTo(b.id);
      });

    int openP = 0;
    int periodCrP = 0;
    int periodDrP = 0;
    int matOutP = 0;
    int matPayP = 0;
    int advGivenP = 0;
    int advRefundP = 0;

    final DateTime? normFrom = fromDate != null ? normalizeDate(fromDate) : null;
    final DateTime? normTo = toDate != null ? normalizeDate(toDate) : null;

    for (final e in active) {
      final d = normalizeDate(e.transactionDate);
      final crP = toPaise(e.creditAmount);
      final drP = toPaise(e.debitAmount);

      if (normFrom != null && d.isBefore(normFrom)) {
        openP += (crP - drP);
        continue;
      }
      if (normTo != null && d.isAfter(normTo)) {
        continue;
      }

      periodCrP += crP;
      periodDrP += drP;

      switch (e.transactionType.toUpperCase()) {
        case 'MATERIAL_OUTWARD':
          matOutP += drP;
          break;
        case 'MATERIAL_PAYMENT':
          matPayP += crP;
          break;
        case 'ADVANCE_GIVEN':
          advGivenP += drP;
          break;
        case 'ADVANCE_REFUND':
          advRefundP += crP;
          break;
      }
    }

    return SubVendorSeparatedBalances(
      openingBalance: fromPaise(openP),
      totalCredit: fromPaise(periodCrP),
      totalDebit: fromPaise(periodDrP),
      netBalance: fromPaise(openP + periodCrP - periodDrP),
      totalMaterialOutward: fromPaise(matOutP),
      totalMaterialPaymentsReceived: fromPaise(matPayP),
      materialReceivableBalance: fromPaise(matOutP - matPayP),
      totalAdvanceGiven: fromPaise(advGivenP),
      totalAdvanceRefundReceived: fromPaise(advRefundP),
      advanceBalance: fromPaise(advGivenP - advRefundP),
    );
  }

  /// Groups active Material Outwards by Day, Month, or Indian Financial Year
  /// with exact ₹ Subtotal, GST, and Grand Total reconciliation.
  static List<PeriodReconciliationSummary> buildOutwardPeriodSummary(
    List<SubVendorMaterialOutward> outwards, {
    required String grouping, // 'DAILY', 'MONTHLY', 'FINANCIAL_YEAR'
  }) {
    final Map<String, _PeriodAcc> buckets = {};

    for (final o in outwards) {
      if (!o.isActive) continue;
      final d = normalizeDate(o.outwardDate);
      String key;
      String label;
      switch (grouping.toUpperCase()) {
        case 'DAILY':
          key = dayKey(d);
          label = DateFormat('dd-MM-yyyy').format(d);
          break;
        case 'FINANCIAL_YEAR':
          key = financialYearKey(d);
          label = key;
          break;
        case 'MONTHLY':
        default:
          key = monthKey(d);
          label = monthLabel(d);
          break;
      }

      final acc = buckets.putIfAbsent(key, () => _PeriodAcc(key, label));
      acc.count++;
      if (o.items.isNotEmpty) {
        final calc = calculateOutwardTotals(o.items);
        acc.qtyP += toPaise(calc.totalQuantity);
        acc.subP += toPaise(calc.subtotal);
        acc.gstP += toPaise(calc.totalGst);
        acc.totP += toPaise(calc.grandTotal);
      } else {
        acc.qtyP += toPaise(o.totalQuantity);
        acc.subP += toPaise(o.subtotal > 0 ? o.subtotal : o.totalValue);
        acc.gstP += toPaise(o.totalGst);
        acc.totP += toPaise(o.totalValue);
      }
    }

    final list = buckets.values
        .map((a) => PeriodReconciliationSummary(
              periodKey: a.key,
              periodLabel: a.label,
              entryCount: a.count,
              totalQuantity: fromPaise(a.qtyP),
              subtotal: fromPaise(a.subP),
              totalGst: fromPaise(a.gstP),
              grandTotal: fromPaise(a.totP),
            ))
        .toList()
      ..sort((a, b) => b.periodKey.compareTo(a.periodKey));

    return list;
  }
}

class _PeriodAcc {
  final String key;
  final String label;
  int count = 0;
  int qtyP = 0;
  int subP = 0;
  int gstP = 0;
  int totP = 0;

  _PeriodAcc(this.key, this.label);
}
