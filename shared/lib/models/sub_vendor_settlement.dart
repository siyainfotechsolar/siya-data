import 'package:flutter/foundation.dart';
import 'vendor_site_assignment.dart';
import 'vendor_material_transaction.dart';
import 'vendor_payout.dart';
import 'vendor_customer_payment.dart';
import 'solar_quotation.dart';

/// Settlement Calculation Modes supported by SIYA INFOTECH & SOLAR ENERGY
enum SubVendorSettlementMode {
  /// Option A (Default EPC Contractor model): Remaining Net Balance belongs to Sub-Vendor
  /// Sub-Vendor Entitlement = Actual Collection - Material Cost - Net GST - SIYA Vendor Charges - Expenses
  netBalance,

  /// Option B: Fixed Agreed Amount (निश्चित कंत्राट रक्कम / Installation charges per site or per kW)
  fixedFee,

  /// Option C: Profit Sharing (उरलेल्या Net Profit मधील ठरावीक टक्केवारी)
  profitShare,
}

extension SubVendorSettlementModeExt on SubVendorSettlementMode {
  String get code {
    switch (this) {
      case SubVendorSettlementMode.netBalance:
        return 'NET_BALANCE';
      case SubVendorSettlementMode.fixedFee:
        return 'FIXED_FEE';
      case SubVendorSettlementMode.profitShare:
        return 'PROFIT_SHARE';
    }
  }

  String get labelMarathi {
    switch (this) {
      case SubVendorSettlementMode.netBalance:
        return 'पर्याय A: उरलेली रक्कम पूर्ण Sub-Vendor ची (Net Balance Payout)';
      case SubVendorSettlementMode.fixedFee:
        return 'पर्याय B: Sub-Vendor सोबत आधी ठरवलेली रक्कम (Fixed Agreed Amount)';
      case SubVendorSettlementMode.profitShare:
        return 'पर्याय C: उरलेल्या नफ्यातील टक्केवारी (Profit Sharing)';
    }
  }

  static SubVendorSettlementMode fromCode(String? code) {
    switch (code?.toUpperCase()) {
      case 'FIXED_FEE':
        return SubVendorSettlementMode.fixedFee;
      case 'PROFIT_SHARE':
        return SubVendorSettlementMode.profitShare;
      case 'NET_BALANCE':
      default:
        return SubVendorSettlementMode.netBalance;
    }
  }
}

/// Complete Sub-Vendor Final Settlement and Payout Calculation Model
class SubVendorSettlement {
  final String id;
  final String assignmentId;
  final String vendorId;
  final String customerId;
  final DateTime calculationDate;

  // 1. Quotation & Loan Plan
  final double totalQuotation; // 100% Contract Amount with GST (e.g. ₹2,00,000)
  final double expectedLoanPercent; // Default 90%
  final double expectedLoanAmount; // e.g. ₹1,80,000
  final double loanDifferencePercent; // 10%
  final double loanDifferenceAmount; // e.g. ₹20,000

  // 2. Actual Collections
  final double actualLoanCredited; // Credited from Bank
  final double actualCustomerContribution; // Cash/Advance collected
  final double totalActualCollected; // actualLoanCredited + actualCustomerContribution
  final double pendingCustomerReceivable; // totalQuotation - totalActualCollected
  final double pendingLoanDisbursement; // expectedLoanAmount - actualLoanCredited
  final double pendingCustomerContribution; // loanDifferenceAmount - actualCustomerContribution

  // 3. GST Calculation & Prevention of Double Deduction
  final bool use7030GstRule; // True: Statutory 70:30 Rule (70% @ 5% + 30% @ 18%), False: Flat Rate
  final double goodsTaxable70; // 70% Goods portion taxable (for 70:30 rule)
  final double goodsGst5; // 5% GST included in Goods portion
  final double servicesTaxable30; // 30% Services/BOS portion taxable
  final double servicesGst18; // 18% GST included in Services portion
  final double outputGstRate; // Composite solar rate (e.g. 13.8% or 8.59%) or invoice GST
  final double taxableRevenue; // totalActualCollected / (1 + outputGstRate/100) or 70:30 taxable
  final double outputGstLiability; // totalActualCollected - taxableRevenue or 70:30 output GST
  final double materialTaxable;
  final double eligibleInputGstCredit; // 5% Panels/Inverters + 18% BOS
  final double netGstLiability; // max(0, outputGstLiability - eligibleInputGstCredit)

  // 4. Dynamic Material & Operational Deductions
  final double materialCost; // Dynamic Actual Material Issued minus Returns
  final double siyaVendorCharges; // Capacity × ₹1,000/kW (deducted once only)
  final double otherApprovedExpenses; // Extra site expenses approved by Admin
  final double totalDeductions; // materialCost + netGstLiability + siyaVendorCharges + otherApprovedExpenses

  // 5. Margin & Profit
  final double grossMargin; // totalActualCollected - materialCost
  final double netProfit; // totalActualCollected - totalDeductions

  // 6. Sub-Vendor Entitlement based on Settlement Mode
  final SubVendorSettlementMode settlementMode;
  final double fixedAgreedFee; // For Mode B
  final double vendorProfitSharePercent; // For Mode C (e.g. 70%)
  final double subVendorGrossEntitlement;

  // 7. Previous Payouts & Adjustments
  final double previousPayoutsPaid; // Advances & partial payouts already disbursed
  final double approvedAdjustments; // Extra credit (+) or debit (-)
  final String? adjustmentRemarks;

  // 8. Final Amount Payable or Recoverable
  final double finalPayoutPayable; // subVendorGrossEntitlement - previousPayoutsPaid + approvedAdjustments
  final bool isRecoverable; // true if finalPayoutPayable < 0
  final double amountPayableToVendor; // max(0, finalPayoutPayable)
  final double amountRecoverableFromVendor; // if negative: finalPayoutPayable.abs()

  // 9. Potential Future Payout upon full collection of pending 10% or balance
  final double potentialFuturePayoutUponFullCollection;

  // 10. Audit & Admin Approval
  final String status; // 'Draft', 'Pending_Approval', 'Approved', 'Settled'
  final bool isApproved;
  final String? approvedBy;
  final DateTime? approvedAt;
  final String? notes;

  // Joined metadata for UI display
  final String? customerName;
  final String? consumerNo;
  final String? vendorName;
  final String? vendorCode;
  final double siteCapacityKw;

  const SubVendorSettlement({
    required this.id,
    required this.assignmentId,
    required this.vendorId,
    required this.customerId,
    required this.calculationDate,
    required this.totalQuotation,
    required this.expectedLoanPercent,
    required this.expectedLoanAmount,
    required this.loanDifferencePercent,
    required this.loanDifferenceAmount,
    required this.actualLoanCredited,
    required this.actualCustomerContribution,
    required this.totalActualCollected,
    required this.pendingCustomerReceivable,
    required this.pendingLoanDisbursement,
    required this.pendingCustomerContribution,
    this.use7030GstRule = true,
    this.goodsTaxable70 = 0.0,
    this.goodsGst5 = 0.0,
    this.servicesTaxable30 = 0.0,
    this.servicesGst18 = 0.0,
    required this.outputGstRate,
    required this.taxableRevenue,
    required this.outputGstLiability,
    required this.materialTaxable,
    required this.eligibleInputGstCredit,
    required this.netGstLiability,
    required this.materialCost,
    required this.siyaVendorCharges,
    required this.otherApprovedExpenses,
    required this.totalDeductions,
    required this.grossMargin,
    required this.netProfit,
    required this.settlementMode,
    required this.fixedAgreedFee,
    required this.vendorProfitSharePercent,
    required this.subVendorGrossEntitlement,
    required this.previousPayoutsPaid,
    required this.approvedAdjustments,
    this.adjustmentRemarks,
    required this.finalPayoutPayable,
    required this.isRecoverable,
    required this.amountPayableToVendor,
    required this.amountRecoverableFromVendor,
    required this.potentialFuturePayoutUponFullCollection,
    this.status = 'Draft',
    this.isApproved = false,
    this.approvedBy,
    this.approvedAt,
    this.notes,
    this.customerName,
    this.consumerNo,
    this.vendorName,
    this.vendorCode,
    this.siteCapacityKw = 3.0,
  });

  /// Factory calculator that computes dynamic financials from actual site records
  factory SubVendorSettlement.compute({
    required VendorSiteAssignment assignment,
    required List<VendorMaterialTransaction> materials,
    required List<VendorPayout> previousPayouts,
    List<VendorCustomerPayment> customerPayments = const [],
    SubVendorSettlementMode settlementMode = SubVendorSettlementMode.netBalance,
    double expectedLoanPercent = 90.0,
    bool use7030GstRule = true, // Default to true: Statutory 70:30 Split (70% @ 5% Goods + 30% @ 18% Services)
    double outputGstRate = 13.8, // Flat fallback if use7030GstRule is false
    double fixedAgreedFee = 0.0,
    double vendorProfitSharePercent = 70.0,
    double approvedAdjustments = 0.0,
    String? adjustmentRemarks,
    String status = 'Draft',
    bool isApproved = false,
    String? approvedBy,
    DateTime? approvedAt,
    String? notes,
  }) {
    final double totalQuotation = assignment.effectiveSiteAmount > 0
        ? assignment.effectiveSiteAmount
        : (assignment.customerTotalAmount > 0 ? assignment.customerTotalAmount : 200000.0);

    final double loanDiffPercent = (100.0 - expectedLoanPercent).clamp(0.0, 100.0);
    final double expectedLoanAmt = (totalQuotation * expectedLoanPercent) / 100.0;
    final double loanDiffAmt = (totalQuotation * loanDiffPercent) / 100.0;

    // Actual Collections from approved customer payments or assignment totals
    double actualLoan = assignment.totalLoanCredited;
    double actualCash = assignment.totalCashReceived;

    if (customerPayments.isNotEmpty) {
      double pLoan = 0.0;
      double pCash = 0.0;
      for (final p in customerPayments) {
        if (p.isApproved) {
          if (p.isLoan) {
            pLoan += p.amount;
          } else {
            pCash += p.amount;
          }
        }
      }
      if (pLoan > 0 || pCash > 0) {
        actualLoan = pLoan;
        actualCash = pCash;
      }
    }

    final double totalCollected = actualLoan + actualCash > 0
        ? (actualLoan + actualCash)
        : assignment.effectiveReceivedAmount;

    final double pendingReceivable = (totalQuotation - totalCollected) > 0
        ? (totalQuotation - totalCollected)
        : 0.0;

    final double pendingLoan = (expectedLoanAmt - actualLoan) > 0
        ? (expectedLoanAmt - actualLoan)
        : 0.0;

    final double pendingCash = (loanDiffAmt - actualCash) > 0
        ? (loanDiffAmt - actualCash)
        : 0.0;

    // Dynamic Material Costs & GST Breakdown
    double m5Taxable = 0.0;
    double m5Gst = 0.0;
    double m18Taxable = 0.0;
    double m18Gst = 0.0;

    for (final item in materials) {
      final sign = item.isReturn ? -1.0 : 1.0;
      final is5Pct = (item.gstRate - 5.0).abs() < 0.5 ||
          item.itemCategory == 'SOLAR_PANEL' ||
          item.itemCategory == 'INVERTER';

      if (is5Pct) {
        m5Taxable += sign * item.taxableAmount;
        m5Gst += sign * item.gstAmount;
      } else {
        m18Taxable += sign * item.taxableAmount;
        m18Gst += sign * item.gstAmount;
      }
    }

    final double matTaxable = m5Taxable + m18Taxable;
    final double eligibleInputGst = m5Gst + m18Gst;
    final double totalMaterialCost = matTaxable + eligibleInputGst;

    // Output GST Liability calculated on Total Quotation Amount (even if collection is partial e.g. ₹2,00,000 on ₹2,22,222 quotation)
    // As per user specification: Quotation amount is the statutory invoice basis for Output GST.
    final double gstBasisAmount = totalQuotation > 0 ? totalQuotation : totalCollected;

    double taxableRev;
    double outputGst;
    double gTaxable70 = 0.0;
    double gGst5 = 0.0;
    double sTaxable30 = 0.0;
    double sGst18 = 0.0;
    double effectiveGstRate = outputGstRate;

    if (use7030GstRule) {
      final gst7030 = SolarQuotationGstBreakdown.calculate(gstBasisAmount);
      outputGst = gst7030.totalGstIncluded;
      taxableRev = gst7030.totalTaxableValue;
      gTaxable70 = gst7030.taxable70;
      gGst5 = gst7030.gst5;
      sTaxable30 = gst7030.taxable30;
      sGst18 = gst7030.gst18;
      effectiveGstRate = gstBasisAmount > 0 && taxableRev > 0
          ? double.parse(((outputGst / taxableRev) * 100.0).toStringAsFixed(2))
          : 8.59;
    } else {
      taxableRev = gstBasisAmount / (1.0 + (outputGstRate / 100.0));
      outputGst = gstBasisAmount - taxableRev;
      gTaxable70 = gstBasisAmount * 0.70;
      sTaxable30 = gstBasisAmount * 0.30;
    }

    // Net GST Liability = Output GST minus Input GST Credit (No Double Deduction!)
    final double netGst = (outputGst - eligibleInputGst) > 0
        ? (outputGst - eligibleInputGst)
        : 0.0;

    // SIYA Vendor Charges (Installed Capacity × Rate per kW, default ₹1,000/kW)
    final double charges = assignment.siteCapacityKw * assignment.ratePerKw;
    final double otherExpenses = assignment.otherExpenses;

    final double totalDeductions = totalMaterialCost + netGst + charges + otherExpenses;
    final double grossMargin = totalCollected - totalMaterialCost;
    final double netProfit = totalCollected - totalDeductions;

    // Sub-Vendor Entitlement Calculation based on chosen mode
    double entitlement = 0.0;
    switch (settlementMode) {
      case SubVendorSettlementMode.netBalance:
        // Option A: Net Balance = Total Collected minus (Material Cost + Net GST + SIYA Charges + Expenses)
        entitlement = totalCollected - totalDeductions;
        break;

      case SubVendorSettlementMode.fixedFee:
        // Option B: Fixed Agreed Fee + approved expenses
        entitlement = (fixedAgreedFee > 0 ? fixedAgreedFee : charges) + otherExpenses;
        break;

      case SubVendorSettlementMode.profitShare:
        // Option C: Profit Share %
        final share = (vendorProfitSharePercent / 100.0).clamp(0.0, 1.0);
        entitlement = _round(netProfit) * share;
        break;
    }

    // Previous payouts disbursed to Sub-Vendor for this site
    double paidToVendor = 0.0;
    for (final p in previousPayouts) {
      if (p.assignmentId == assignment.id || p.assignmentId == null) {
        paidToVendor += p.amount;
      }
    }

    final double finalPayable = entitlement - paidToVendor + approvedAdjustments;
    final bool isRecov = finalPayable < -0.01;
    final double amtPayable = isRecov ? 0.0 : finalPayable;
    final double amtRecoverable = isRecov ? finalPayable.abs() : 0.0;

    // Calculate potential full entitlement upon 100% quotation collection
    double fullTaxableRev;
    double fullOutputGst;
    if (use7030GstRule) {
      final fullGst7030 = SolarQuotationGstBreakdown.calculate(totalQuotation);
      fullOutputGst = fullGst7030.totalGstIncluded;
      fullTaxableRev = fullGst7030.totalTaxableValue;
    } else {
      fullTaxableRev = totalQuotation / (1.0 + (outputGstRate / 100.0));
      fullOutputGst = totalQuotation - fullTaxableRev;
    }
    final double fullNetGst = (fullOutputGst - eligibleInputGst) > 0 ? (fullOutputGst - eligibleInputGst) : 0.0;
    final double fullDeductions = totalMaterialCost + fullNetGst + charges + otherExpenses;
    double fullEntitlement = 0.0;
    if (settlementMode == SubVendorSettlementMode.netBalance) {
      fullEntitlement = totalQuotation - fullDeductions;
    } else if (settlementMode == SubVendorSettlementMode.fixedFee) {
      fullEntitlement = (fixedAgreedFee > 0 ? fixedAgreedFee : charges) + otherExpenses;
    } else {
      fullEntitlement = (totalQuotation - fullDeductions) * (vendorProfitSharePercent / 100.0);
    }
    final double potentialFuturePayout = (fullEntitlement - paidToVendor + approvedAdjustments);

    return SubVendorSettlement(
      id: '',
      assignmentId: assignment.id,
      vendorId: assignment.vendorId,
      customerId: assignment.customerId,
      calculationDate: DateTime.now(),
      totalQuotation: _round(totalQuotation),
      expectedLoanPercent: _round(expectedLoanPercent),
      expectedLoanAmount: _round(expectedLoanAmt),
      loanDifferencePercent: _round(loanDiffPercent),
      loanDifferenceAmount: _round(loanDiffAmt),
      actualLoanCredited: _round(actualLoan),
      actualCustomerContribution: _round(actualCash),
      totalActualCollected: _round(totalCollected),
      pendingCustomerReceivable: _round(pendingReceivable),
      pendingLoanDisbursement: _round(pendingLoan),
      pendingCustomerContribution: _round(pendingCash),
      use7030GstRule: use7030GstRule,
      goodsTaxable70: _round(gTaxable70),
      goodsGst5: _round(gGst5),
      servicesTaxable30: _round(sTaxable30),
      servicesGst18: _round(sGst18),
      outputGstRate: _round(effectiveGstRate),
      taxableRevenue: _round(taxableRev),
      outputGstLiability: _round(outputGst),
      materialTaxable: _round(matTaxable),
      eligibleInputGstCredit: _round(eligibleInputGst),
      netGstLiability: _round(netGst),
      materialCost: _round(totalMaterialCost),
      siyaVendorCharges: _round(charges),
      otherApprovedExpenses: _round(otherExpenses),
      totalDeductions: _round(totalDeductions),
      grossMargin: _round(grossMargin),
      netProfit: _round(netProfit),
      settlementMode: settlementMode,
      fixedAgreedFee: _round(fixedAgreedFee),
      vendorProfitSharePercent: _round(vendorProfitSharePercent),
      subVendorGrossEntitlement: _round(entitlement),
      previousPayoutsPaid: _round(paidToVendor),
      approvedAdjustments: _round(approvedAdjustments),
      adjustmentRemarks: adjustmentRemarks,
      finalPayoutPayable: _round(finalPayable),
      isRecoverable: isRecov,
      amountPayableToVendor: _round(amtPayable),
      amountRecoverableFromVendor: _round(amtRecoverable),
      potentialFuturePayoutUponFullCollection: _round(potentialFuturePayout),
      status: isApproved ? 'Approved' : status,
      isApproved: isApproved || assignment.settlementApproved,
      approvedBy: approvedBy ?? assignment.settlementApprovedBy,
      approvedAt: approvedAt ?? assignment.settlementApprovedAt,
      notes: notes,
      customerName: assignment.customerName,
      consumerNo: assignment.consumerNo,
      vendorName: assignment.vendorName,
      vendorCode: assignment.vendorCode,
      siteCapacityKw: assignment.siteCapacityKw,
    );
  }

  static double _round(double val) => double.parse(val.toStringAsFixed(2));

  factory SubVendorSettlement.fromJson(Map<String, dynamic> json) {
    return SubVendorSettlement(
      id: json['id'] as String? ?? '',
      assignmentId: json['assignment_id'] as String? ?? '',
      vendorId: json['vendor_id'] as String? ?? '',
      customerId: json['customer_id'] as String? ?? '',
      calculationDate: json['calculation_date'] != null
          ? DateTime.tryParse(json['calculation_date'] as String) ?? DateTime.now()
          : DateTime.now(),
      totalQuotation: (json['total_quotation'] as num?)?.toDouble() ?? 0.0,
      expectedLoanPercent: (json['expected_loan_percent'] as num?)?.toDouble() ?? 90.0,
      expectedLoanAmount: (json['expected_loan_amount'] as num?)?.toDouble() ?? 0.0,
      loanDifferencePercent: (json['loan_difference_percent'] as num?)?.toDouble() ?? 10.0,
      loanDifferenceAmount: (json['loan_difference_amount'] as num?)?.toDouble() ?? 0.0,
      actualLoanCredited: (json['actual_loan_credited'] as num?)?.toDouble() ?? 0.0,
      actualCustomerContribution: (json['actual_customer_contribution'] as num?)?.toDouble() ?? 0.0,
      totalActualCollected: (json['total_actual_collected'] as num?)?.toDouble() ?? 0.0,
      pendingCustomerReceivable: (json['pending_customer_receivable'] as num?)?.toDouble() ?? 0.0,
      pendingLoanDisbursement: (json['pending_loan_disbursement'] as num?)?.toDouble() ?? 0.0,
      pendingCustomerContribution: (json['pending_customer_contribution'] as num?)?.toDouble() ?? 0.0,
      use7030GstRule: json['use_70_30_gst_rule'] as bool? ?? true,
      goodsTaxable70: (json['goods_taxable_70'] as num?)?.toDouble() ?? 0.0,
      goodsGst5: (json['goods_gst_5'] as num?)?.toDouble() ?? 0.0,
      servicesTaxable30: (json['services_taxable_30'] as num?)?.toDouble() ?? 0.0,
      servicesGst18: (json['services_gst_18'] as num?)?.toDouble() ?? 0.0,
      outputGstRate: (json['output_gst_rate'] as num?)?.toDouble() ?? 8.59,
      taxableRevenue: (json['taxable_revenue'] as num?)?.toDouble() ?? 0.0,
      outputGstLiability: (json['output_gst_liability'] as num?)?.toDouble() ?? 0.0,
      materialTaxable: (json['material_taxable'] as num?)?.toDouble() ?? 0.0,
      eligibleInputGstCredit: (json['eligible_input_gst_credit'] as num?)?.toDouble() ?? 0.0,
      netGstLiability: (json['net_gst_liability'] as num?)?.toDouble() ?? 0.0,
      materialCost: (json['material_cost'] as num?)?.toDouble() ?? 0.0,
      siyaVendorCharges: (json['siya_vendor_charges'] as num?)?.toDouble() ?? 0.0,
      otherApprovedExpenses: (json['other_approved_expenses'] as num?)?.toDouble() ?? 0.0,
      totalDeductions: (json['total_deductions'] as num?)?.toDouble() ?? 0.0,
      grossMargin: (json['gross_margin'] as num?)?.toDouble() ?? 0.0,
      netProfit: (json['net_profit'] as num?)?.toDouble() ?? 0.0,
      settlementMode: SubVendorSettlementModeExt.fromCode(json['settlement_mode'] as String?),
      fixedAgreedFee: (json['fixed_agreed_fee'] as num?)?.toDouble() ?? 0.0,
      vendorProfitSharePercent: (json['vendor_profit_share_percent'] as num?)?.toDouble() ?? 70.0,
      subVendorGrossEntitlement: (json['sub_vendor_gross_entitlement'] as num?)?.toDouble() ?? 0.0,
      previousPayoutsPaid: (json['previous_payouts_paid'] as num?)?.toDouble() ?? 0.0,
      approvedAdjustments: (json['approved_adjustments'] as num?)?.toDouble() ?? 0.0,
      adjustmentRemarks: json['adjustment_remarks'] as String?,
      finalPayoutPayable: (json['final_payout_payable'] as num?)?.toDouble() ?? 0.0,
      isRecoverable: json['is_recoverable'] as bool? ?? false,
      amountPayableToVendor: (json['amount_payable_to_vendor'] as num?)?.toDouble() ?? 0.0,
      amountRecoverableFromVendor: (json['amount_recoverable_from_vendor'] as num?)?.toDouble() ?? 0.0,
      potentialFuturePayoutUponFullCollection:
          (json['potential_future_payout'] as num?)?.toDouble() ?? 0.0,
      status: json['status'] as String? ?? 'Draft',
      isApproved: json['is_approved'] as bool? ?? false,
      approvedBy: json['approved_by'] as String?,
      approvedAt: json['approved_at'] != null ? DateTime.tryParse(json['approved_at'] as String) : null,
      notes: json['notes'] as String?,
      customerName: json['customer_name'] as String?,
      consumerNo: json['consumer_no'] as String?,
      vendorName: json['vendor_name'] as String?,
      vendorCode: json['vendor_code'] as String?,
      siteCapacityKw: (json['site_capacity_kw'] as num?)?.toDouble() ?? 3.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id.isNotEmpty) 'id': id,
      'assignment_id': assignmentId,
      'vendor_id': vendorId,
      'customer_id': customerId,
      'calculation_date': calculationDate.toIso8601String().split('T').first,
      'total_quotation': totalQuotation,
      'expected_loan_percent': expectedLoanPercent,
      'expected_loan_amount': expectedLoanAmount,
      'loan_difference_percent': loanDifferencePercent,
      'loan_difference_amount': loanDifferenceAmount,
      'actual_loan_credited': actualLoanCredited,
      'actual_customer_contribution': actualCustomerContribution,
      'total_actual_collected': totalActualCollected,
      'pending_customer_receivable': pendingCustomerReceivable,
      'pending_loan_disbursement': pendingLoanDisbursement,
      'pending_customer_contribution': pendingCustomerContribution,
      'use_70_30_gst_rule': use7030GstRule,
      'goods_taxable_70': goodsTaxable70,
      'goods_gst_5': goodsGst5,
      'services_taxable_30': servicesTaxable30,
      'services_gst_18': servicesGst18,
      'output_gst_rate': outputGstRate,
      'taxable_revenue': taxableRevenue,
      'output_gst_liability': outputGstLiability,
      'material_taxable': materialTaxable,
      'eligible_input_gst_credit': eligibleInputGstCredit,
      'net_gst_liability': netGstLiability,
      'material_cost': materialCost,
      'siya_vendor_charges': siyaVendorCharges,
      'other_approved_expenses': otherApprovedExpenses,
      'total_deductions': totalDeductions,
      'gross_margin': grossMargin,
      'net_profit': netProfit,
      'settlement_mode': settlementMode.code,
      'fixed_agreed_fee': fixedAgreedFee,
      'vendor_profit_share_percent': vendorProfitSharePercent,
      'sub_vendor_gross_entitlement': subVendorGrossEntitlement,
      'previous_payouts_paid': previousPayoutsPaid,
      'approved_adjustments': approvedAdjustments,
      if (adjustmentRemarks != null) 'adjustment_remarks': adjustmentRemarks,
      'final_payout_payable': finalPayoutPayable,
      'is_recoverable': isRecoverable,
      'amount_payable_to_vendor': amountPayableToVendor,
      'amount_recoverable_from_vendor': amountRecoverableFromVendor,
      'potential_future_payout': potentialFuturePayoutUponFullCollection,
      'status': status,
      'is_approved': isApproved,
      if (approvedBy != null) 'approved_by': approvedBy,
      if (approvedAt != null) 'approved_at': approvedAt!.toIso8601String(),
      if (notes != null) 'notes': notes,
    };
  }
}
