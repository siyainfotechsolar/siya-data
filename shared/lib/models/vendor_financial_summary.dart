import '../services/sub_vendor_financial_engine.dart';
import 'sub_vendor_account_ledger.dart';
import 'sub_vendor_material_outward.dart';
import 'vendor_customer_payment.dart';
import 'vendor_gst_recovery.dart';
import 'vendor_site_assignment.dart';
import 'vendor_material_transaction.dart';
import 'vendor_payout.dart';

/// Complete financial calculation breakdown for a single site assignment.
class SiteFinancialDetail {
  final VendorSiteAssignment assignment;
  final List<VendorMaterialTransaction> materials;
  final List<VendorPayout> payouts;

  // 5% Category (Solar PV Modules & Inverters)
  final double material5Taxable;
  final double material5Gst;
  final double material5Total;

  // 18% Category (Solar BOS & other balance of system)
  final double material18Taxable;
  final double material18Gst;
  final double material18Total;

  // 0% / Other GST Category
  final double materialOtherTotal;

  // Total Material Cost (Actual Issues minus Returns)
  final double totalMaterialTaxable;
  final double totalEligibleInputGst;
  final double totalMaterialCost;

  // Statutory Net GST Liability (70:30 Output GST on quotation - Eligible Input GST)
  final double netGstLiability;
  final double approvedGstRecovery;

  // Vendor Charges & Expenses
  final double vendorCharges; // Capacity × ₹1,000/kW
  final double otherExpenses;
  final double totalVendorPayable; // vendorCharges + otherExpenses

  // Customer Site Financials & Payment Tracking
  final double totalSiteAmount; // Total Contract Amount from Customer
  final double amountReceivedBySiya; // Paid by Customer to SIYA
  final String paymentType; // 'Cash Customer', 'Bank Loan Customer', 'Part Cash + Part Loan'
  final double cashReceived;
  final double loanSanctioned;
  final double loanCredited;
  final double loanPendingCredit;
  final double totalCustomerReceived; // cashReceived + loanCredited
  final double customerOutstanding;
  final String loanStatus;
  final String customerPaymentStatus;

  // Payouts & Settlement to Sub-Vendor
  final double totalPaidToVendor;
  final double outstandingVendorPayable; // legacy vendor charges minus paid

  /// Effective collection realized (Bank loan credited + customer cash)
  double get effectiveCollection => amountReceivedBySiya;

  /// Net balance payable to Sub-Vendor under Net Balance model:
  /// (Collection - Material Cost - SIYA Charges - Expenses - Net GST Liability - Contractual GST Recovery - Paid to Vendor)
  double get netSubVendorBalance {
    return SubVendorFinancialEngine.round2(
      effectiveCollection -
          totalMaterialCost -
          vendorCharges -
          otherExpenses -
          netGstLiability -
          approvedGstRecovery -
          totalPaidToVendor,
    );
  }

  const SiteFinancialDetail({
    required this.assignment,
    required this.materials,
    required this.payouts,
    required this.material5Taxable,
    required this.material5Gst,
    required this.material5Total,
    required this.material18Taxable,
    required this.material18Gst,
    required this.material18Total,
    this.materialOtherTotal = 0.0,
    required this.totalMaterialTaxable,
    required this.totalEligibleInputGst,
    required this.totalMaterialCost,
    this.netGstLiability = 0.0,
    this.approvedGstRecovery = 0.0,
    required this.vendorCharges,
    required this.otherExpenses,
    required this.totalVendorPayable,
    required this.totalSiteAmount,
    required this.amountReceivedBySiya,
    this.paymentType = 'Cash Customer',
    this.cashReceived = 0.0,
    this.loanSanctioned = 0.0,
    this.loanCredited = 0.0,
    this.loanPendingCredit = 0.0,
    this.totalCustomerReceived = 0.0,
    this.customerOutstanding = 0.0,
    this.loanStatus = 'Not Required',
    this.customerPaymentStatus = 'Pending',
    required this.totalPaidToVendor,
    required this.outstandingVendorPayable,
  });

  /// Factory calculator that computes dynamic financials from actual material entries
  factory SiteFinancialDetail.compute({
    required VendorSiteAssignment assignment,
    required List<VendorMaterialTransaction> materials,
    required List<VendorPayout> payouts,
    List<VendorGstRecovery> gstRecoveries = const [],
    List<VendorCustomerPayment> customerPayments = const [],
    bool includeUnlinkedPayouts = true,
  }) {
    final matBreakdown = SubVendorFinancialEngine.classifySiteMaterialsGst(materials);

    // Statutory Net GST Liability = Output GST on quotation (70:30 rule) - Eligible Material Input GST Credit
    final outputGstOnQuotation = assignment.gstBreakdown.totalGstIncluded;
    final rawNetGst = outputGstOnQuotation - matBreakdown.totalEligibleInputGst;
    final netGst = rawNetGst > 0 ? SubVendorFinancialEngine.round2(rawNetGst) : 0.0;

    final double siteGstRecovery = gstRecoveries.isNotEmpty
        ? SubVendorFinancialEngine.sumPaise(
            gstRecoveries.where(
                (r) => r.assignmentId == assignment.id && (r.isApproved || r.isCollected)),
            (r) => r.totalRecovery,
          )
        : SubVendorFinancialEngine.round2(assignment.approvedGstRecoveryAmount);

    // Vendor charges: Installed Capacity × ₹1,000/kW (or assigned rate)
    final charges = SubVendorFinancialEngine.round2(
        assignment.siteCapacityKw * assignment.ratePerKw);
    final expenses = SubVendorFinancialEngine.round2(assignment.otherExpenses);
    final totVendorPayable = SubVendorFinancialEngine.round2(charges + expenses);

    // Site Amount & Received from Customer
    final siteAmt = SubVendorFinancialEngine.round2(assignment.effectiveSiteAmount);
    final cashRecv = SubVendorFinancialEngine.round2(assignment.totalCashReceived);
    final loanSanc = SubVendorFinancialEngine.round2(assignment.loanSanctionedAmount);
    final loanCred = SubVendorFinancialEngine.round2(assignment.totalLoanCredited);
    final loanPend = SubVendorFinancialEngine.round2(assignment.loanPendingCredit);
    final custRecv = customerPayments.isNotEmpty
        ? SubVendorFinancialEngine.reconcileSiteReceivedAmount(
            assignment,
            siteCustomerPayments: customerPayments,
          )
        : SubVendorFinancialEngine.round2(assignment.effectiveReceivedAmount);
    final custOut = siteAmt > 0
        ? (siteAmt - custRecv > 0 ? SubVendorFinancialEngine.round2(siteAmt - custRecv) : 0.0)
        : SubVendorFinancialEngine.round2(assignment.effectiveCustomerOutstanding);

    // Disbursed payouts made to sub-vendor for this site (excludes Rejected/Cancelled/Pending)
    int paidPaise = 0;
    for (final p in payouts) {
      if (!SubVendorFinancialEngine.isDisbursedPayout(p)) continue;
      if (p.assignmentId == assignment.id ||
          (includeUnlinkedPayouts && p.assignmentId == null)) {
        paidPaise += SubVendorFinancialEngine.toPaise(p.amount);
      }
    }
    final paidToVendor = SubVendorFinancialEngine.fromPaise(paidPaise);
    final outstanding = SubVendorFinancialEngine.round2(totVendorPayable - paidToVendor);

    return SiteFinancialDetail(
      assignment: assignment,
      materials: materials,
      payouts: payouts,
      material5Taxable: matBreakdown.material5Taxable,
      material5Gst: matBreakdown.material5Gst,
      material5Total: matBreakdown.material5Total,
      material18Taxable: matBreakdown.material18Taxable,
      material18Gst: matBreakdown.material18Gst,
      material18Total: matBreakdown.material18Total,
      materialOtherTotal: matBreakdown.otherAndZeroTotal,
      totalMaterialTaxable: matBreakdown.totalTaxable,
      totalEligibleInputGst: matBreakdown.totalEligibleInputGst,
      totalMaterialCost: matBreakdown.totalMaterialCost,
      netGstLiability: netGst,
      approvedGstRecovery: siteGstRecovery,
      vendorCharges: charges,
      otherExpenses: expenses,
      totalVendorPayable: totVendorPayable,
      totalSiteAmount: siteAmt,
      amountReceivedBySiya: custRecv,
      paymentType: assignment.paymentType,
      cashReceived: cashRecv,
      loanSanctioned: loanSanc,
      loanCredited: loanCred,
      loanPendingCredit: loanPend,
      totalCustomerReceived: custRecv,
      customerOutstanding: custOut,
      loanStatus: assignment.loanStatus,
      customerPaymentStatus: assignment.customerPaymentStatus,
      totalPaidToVendor: paidToVendor,
      outstandingVendorPayable: outstanding,
    );
  }
}

/// Overall financial summary aggregated across all sites for a sub-vendor.
class VendorFinancialSummary {
  final String vendorId;
  final String vendorCode;
  final String vendorName;

  // Site Counts & Capacity
  final int totalAssignedSites;
  final int completedSites;
  final int pendingSites;
  final double totalCapacityKw;

  // Contract Amounts & Customer Collections
  final double totalSiteAmount;
  final double totalReceivedBySiya;
  final double totalCashReceived;
  final double totalLoanSanctioned;
  final double totalLoanCredited;
  final double totalLoanPendingCredit;
  final double totalCustomerCollection;
  final double totalCustomerOutstanding;

  double get totalCustomerSiteAmount => totalSiteAmount;

  // Dynamic Material Costs Breakdown
  final double material5Taxable;
  final double material5Gst;
  final double material5Total;

  final double material18Taxable;
  final double material18Gst;
  final double material18Total;

  final double materialOtherTotal;

  final double totalMaterialTaxable;
  final double totalEligibleInputGst;
  final double totalMaterialCost;

  // Statutory Net GST Liability (70:30 Output GST on quotation - Eligible Input GST)
  final double totalNetGstLiability;
  final double totalApprovedGstRecovery;

  // SIYA Vendor Charges (Installed Capacity × ₹1,000/kW)
  final double totalVendorCharges;
  final double totalOtherExpenses;
  final double totalSettlementAmount; // totalVendorCharges + totalOtherExpenses

  // Payments & Balance to Vendor
  final double totalPaidAmount;
  final double totalUnlinkedPayouts;
  final double outstandingSettlement; // totalSettlementAmount - totalPaidAmount

  /// Total customer collection realized (never inflated with unpaid quotations)
  double get effectiveTotalCollection => totalCustomerCollection;

  // Centralized Ledger / Unallocated Outward Additions
  final double totalMaterialOutwardCost;
  final double totalDirectVendorPayments;
  final double totalDirectAdvancesGiven;
  final double totalDirectAdvanceRefunds;

  double get combinedMaterialCost =>
      SubVendorFinancialEngine.round2(totalMaterialCost + totalMaterialOutwardCost);

  double get combinedPaidAndAdvances =>
      SubVendorFinancialEngine.round2(totalPaidAmount + totalDirectAdvancesGiven);

  /// Separate Material Account Balance: Material Outward minus Direct Material Payments
  double get materialReceivableBalance =>
      SubVendorFinancialEngine.round2(totalMaterialOutwardCost - totalDirectVendorPayments);

  /// Separate Advance Account Balance: Advances/Payouts Given minus Advance Refunds
  double get advanceBalance =>
      SubVendorFinancialEngine.round2(combinedPaidAndAdvances - totalDirectAdvanceRefunds);

  double get netSettlementPayable {
    return SubVendorFinancialEngine.round2(
      effectiveTotalCollection +
          totalDirectVendorPayments +
          totalDirectAdvanceRefunds -
          totalMaterialCost -
          totalMaterialOutwardCost -
          totalVendorCharges -
          totalOtherExpenses -
          totalNetGstLiability -
          totalApprovedGstRecovery -
          totalPaidAmount -
          totalDirectAdvancesGiven,
    );
  }

  /// Gross Entitlement before deducting Paid Advances/Payouts
  double get netVendorEntitlement {
    return SubVendorFinancialEngine.round2(
      effectiveTotalCollection +
          totalDirectVendorPayments +
          totalDirectAdvanceRefunds -
          totalMaterialCost -
          totalMaterialOutwardCost -
          totalVendorCharges -
          totalOtherExpenses -
          totalNetGstLiability -
          totalApprovedGstRecovery,
    );
  }

  // Site-by-site breakdown
  final List<SiteFinancialDetail> siteDetails;

  const VendorFinancialSummary({
    required this.vendorId,
    required this.vendorCode,
    required this.vendorName,
    required this.totalAssignedSites,
    required this.completedSites,
    required this.pendingSites,
    required this.totalCapacityKw,
    required this.totalSiteAmount,
    required this.totalReceivedBySiya,
    this.totalCashReceived = 0.0,
    this.totalLoanSanctioned = 0.0,
    this.totalLoanCredited = 0.0,
    this.totalLoanPendingCredit = 0.0,
    this.totalCustomerCollection = 0.0,
    this.totalCustomerOutstanding = 0.0,
    required this.material5Taxable,
    required this.material5Gst,
    required this.material5Total,
    required this.material18Taxable,
    required this.material18Gst,
    required this.material18Total,
    this.materialOtherTotal = 0.0,
    required this.totalMaterialTaxable,
    required this.totalEligibleInputGst,
    required this.totalMaterialCost,
    this.totalNetGstLiability = 0.0,
    this.totalApprovedGstRecovery = 0.0,
    required this.totalVendorCharges,
    required this.totalOtherExpenses,
    required this.totalSettlementAmount,
    required this.totalPaidAmount,
    this.totalUnlinkedPayouts = 0.0,
    required this.outstandingSettlement,
    this.totalMaterialOutwardCost = 0.0,
    this.totalDirectVendorPayments = 0.0,
    this.totalDirectAdvancesGiven = 0.0,
    this.totalDirectAdvanceRefunds = 0.0,
    required this.siteDetails,
  });

  /// Factory calculator that computes dynamic summary from site assignments,
  /// materials, payouts, customer payments, material outwards, GST recoveries,
  /// and direct account ledger entries through one central standard engine.
  factory VendorFinancialSummary.compute({
    required String vendorId,
    required String vendorCode,
    required String vendorName,
    required List<VendorSiteAssignment> assignments,
    required List<VendorMaterialTransaction> allMaterials,
    required List<VendorPayout> allPayouts,
    List<VendorCustomerPayment> customerPayments = const [],
    List<VendorGstRecovery> gstRecoveries = const [],
    List<SubVendorMaterialOutward> materialOutwards = const [],
    List<SubVendorAccountLedgerEntry> accountLedgerEntries = const [],
    double extraMaterialOutwardCost = 0.0,
    double extraDirectVendorPayments = 0.0,
    double extraDirectAdvancesGiven = 0.0,
    double extraDirectAdvanceRefunds = 0.0,
  }) {
    final activeAssignments = assignments
        .where((a) => a.status.trim().toLowerCase() != 'cancelled')
        .toList();
    final activeAssignmentIds = activeAssignments.map((a) => a.id).toSet();

    // Derive central extras via unified engine if raw lists were passed directly
    final bool hasPrecomputedExtras = extraMaterialOutwardCost > 0 ||
        extraDirectVendorPayments > 0 ||
        extraDirectAdvancesGiven > 0 ||
        extraDirectAdvanceRefunds > 0;
    double resolvedOutwardCost = extraMaterialOutwardCost;
    double resolvedDirectPay = extraDirectVendorPayments;
    double resolvedDirectAdv = extraDirectAdvancesGiven;
    double resolvedDirectRef = extraDirectAdvanceRefunds;

    if (!hasPrecomputedExtras &&
        (materialOutwards.isNotEmpty || accountLedgerEntries.isNotEmpty)) {
      final central = SubVendorFinancialEngine.extractCentralExtras(
        vendorIdFilter: vendorId,
        materialOutwards: materialOutwards,
        accountLedgerEntries: accountLedgerEntries,
        knownRawIds: {
          ...assignments.map((a) => a.id),
          ...allMaterials.map((m) => m.id),
          ...allPayouts.map((p) => p.id),
          ...customerPayments.map((c) => c.id),
        },
      );
      resolvedOutwardCost = central.totalOutwardCost;
      resolvedDirectPay = central.directVendorPayments;
      resolvedDirectAdv = central.directAdvancesGiven;
      resolvedDirectRef = central.directAdvanceRefunds;
    }

    final validPayouts = allPayouts
        .where((p) =>
            p.vendorId == vendorId && SubVendorFinancialEngine.isDisbursedPayout(p))
        .toList();

    int completed = 0;
    int pending = 0;
    int kwP = 0, siteAmtP = 0, recvSiyaP = 0, cashP = 0, loanSancP = 0;
    int loanCredP = 0, loanPendP = 0, custOutP = 0;
    int m5TaxP = 0, m5GstP = 0, m18TaxP = 0, m18GstP = 0, mOtherTotP = 0;
    int mEligibleItcP = 0, mTotalMatP = 0, mTaxableTotP = 0;
    int chargesP = 0, expensesP = 0, netGstP = 0, gstRecovP = 0;

    final siteDetails = <SiteFinancialDetail>[];

    for (final assignment in activeAssignments) {
      if (assignment.isCompleted) {
        completed++;
      } else {
        pending++;
      }

      final siteMaterials =
          allMaterials.where((m) => m.assignmentId == assignment.id).toList();
      final sitePayouts = validPayouts.where((p) {
        if (p.assignmentId == assignment.id) return true;
        if (p.assignmentId == null && activeAssignments.length == 1) return true;
        return false;
      }).toList();
      final siteCp =
          customerPayments.where((c) => c.assignmentId == assignment.id).toList();
      final siteRecoveries =
          gstRecoveries.where((r) => r.assignmentId == assignment.id).toList();

      final detail = SiteFinancialDetail.compute(
        assignment: assignment,
        materials: siteMaterials,
        payouts: sitePayouts,
        gstRecoveries: siteRecoveries,
        customerPayments: siteCp,
        includeUnlinkedPayouts: activeAssignments.length == 1,
      );

      kwP += SubVendorFinancialEngine.toPaise(assignment.siteCapacityKw);
      siteAmtP += SubVendorFinancialEngine.toPaise(detail.totalSiteAmount);
      recvSiyaP += SubVendorFinancialEngine.toPaise(detail.effectiveCollection);
      cashP += SubVendorFinancialEngine.toPaise(detail.cashReceived);
      loanSancP += SubVendorFinancialEngine.toPaise(detail.loanSanctioned);
      loanCredP += SubVendorFinancialEngine.toPaise(detail.loanCredited);
      loanPendP += SubVendorFinancialEngine.toPaise(detail.loanPendingCredit);
      custOutP += SubVendorFinancialEngine.toPaise(detail.customerOutstanding);

      m5TaxP += SubVendorFinancialEngine.toPaise(detail.material5Taxable);
      m5GstP += SubVendorFinancialEngine.toPaise(detail.material5Gst);
      m18TaxP += SubVendorFinancialEngine.toPaise(detail.material18Taxable);
      m18GstP += SubVendorFinancialEngine.toPaise(detail.material18Gst);
      mOtherTotP += SubVendorFinancialEngine.toPaise(detail.materialOtherTotal);
      mTaxableTotP += SubVendorFinancialEngine.toPaise(detail.totalMaterialTaxable);
      mEligibleItcP += SubVendorFinancialEngine.toPaise(detail.totalEligibleInputGst);
      mTotalMatP += SubVendorFinancialEngine.toPaise(detail.totalMaterialCost);

      chargesP += SubVendorFinancialEngine.toPaise(detail.vendorCharges);
      expensesP += SubVendorFinancialEngine.toPaise(detail.otherExpenses);
      netGstP += SubVendorFinancialEngine.toPaise(detail.netGstLiability);
      gstRecovP += SubVendorFinancialEngine.toPaise(detail.approvedGstRecovery);

      siteDetails.add(detail);
    }

    // Include any vendor-level GST recoveries referencing cancelled/other sites if approved
    for (final r in gstRecoveries) {
      if (r.vendorId == vendorId &&
          (r.isApproved || r.isCollected) &&
          !activeAssignmentIds.contains(r.assignmentId)) {
        gstRecovP += SubVendorFinancialEngine.toPaise(r.totalRecovery);
      }
    }

    int totalPaidP = 0;
    int unlinkedPaidP = 0;
    for (final p in validPayouts) {
      final pPaise = SubVendorFinancialEngine.toPaise(p.amount);
      totalPaidP += pPaise;
      if (p.assignmentId == null ||
          (activeAssignments.length > 1 && !activeAssignmentIds.contains(p.assignmentId))) {
        unlinkedPaidP += pPaise;
      } else if (activeAssignments.isEmpty) {
        unlinkedPaidP += pPaise;
      }
    }

    final settlementP = chargesP + expensesP;
    final outstandingP = settlementP - totalPaidP;

    return VendorFinancialSummary(
      vendorId: vendorId,
      vendorCode: vendorCode,
      vendorName: vendorName,
      totalAssignedSites: activeAssignments.length,
      completedSites: completed,
      pendingSites: pending,
      totalCapacityKw: SubVendorFinancialEngine.fromPaise(kwP),
      totalSiteAmount: SubVendorFinancialEngine.fromPaise(siteAmtP),
      totalReceivedBySiya: SubVendorFinancialEngine.fromPaise(recvSiyaP),
      totalCashReceived: SubVendorFinancialEngine.fromPaise(cashP),
      totalLoanSanctioned: SubVendorFinancialEngine.fromPaise(loanSancP),
      totalLoanCredited: SubVendorFinancialEngine.fromPaise(loanCredP),
      totalLoanPendingCredit: SubVendorFinancialEngine.fromPaise(loanPendP),
      totalCustomerCollection: SubVendorFinancialEngine.fromPaise(recvSiyaP),
      totalCustomerOutstanding: SubVendorFinancialEngine.fromPaise(custOutP),
      material5Taxable: SubVendorFinancialEngine.fromPaise(m5TaxP),
      material5Gst: SubVendorFinancialEngine.fromPaise(m5GstP),
      material5Total: SubVendorFinancialEngine.fromPaise(m5TaxP + m5GstP),
      material18Taxable: SubVendorFinancialEngine.fromPaise(m18TaxP),
      material18Gst: SubVendorFinancialEngine.fromPaise(m18GstP),
      material18Total: SubVendorFinancialEngine.fromPaise(m18TaxP + m18GstP),
      materialOtherTotal: SubVendorFinancialEngine.fromPaise(mOtherTotP),
      totalMaterialTaxable: SubVendorFinancialEngine.fromPaise(mTaxableTotP),
      totalEligibleInputGst: SubVendorFinancialEngine.fromPaise(mEligibleItcP),
      totalMaterialCost: SubVendorFinancialEngine.fromPaise(mTotalMatP),
      totalNetGstLiability: SubVendorFinancialEngine.fromPaise(netGstP),
      totalApprovedGstRecovery: SubVendorFinancialEngine.fromPaise(gstRecovP),
      totalVendorCharges: SubVendorFinancialEngine.fromPaise(chargesP),
      totalOtherExpenses: SubVendorFinancialEngine.fromPaise(expensesP),
      totalSettlementAmount: SubVendorFinancialEngine.fromPaise(settlementP),
      totalPaidAmount: SubVendorFinancialEngine.fromPaise(totalPaidP),
      totalUnlinkedPayouts: SubVendorFinancialEngine.fromPaise(unlinkedPaidP),
      outstandingSettlement: SubVendorFinancialEngine.fromPaise(outstandingP),
      totalMaterialOutwardCost: SubVendorFinancialEngine.round2(resolvedOutwardCost),
      totalDirectVendorPayments: SubVendorFinancialEngine.round2(resolvedDirectPay),
      totalDirectAdvancesGiven: SubVendorFinancialEngine.round2(resolvedDirectAdv),
      totalDirectAdvanceRefunds: SubVendorFinancialEngine.round2(resolvedDirectRef),
      siteDetails: siteDetails,
    );
  }
}
