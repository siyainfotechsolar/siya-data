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

  // Total Material Cost (Actual Issues minus Returns)
  final double totalMaterialTaxable;
  final double totalEligibleInputGst;
  final double totalMaterialCost;

  // Vendor Charges & Expenses
  final double vendorCharges; // Capacity × ₹1,000/kW
  final double otherExpenses;
  final double totalVendorPayable; // vendorCharges + otherExpenses

  // Customer Site Financials
  final double totalSiteAmount; // Total Contract Amount from Customer
  final double amountReceivedBySiya; // Paid by Customer to SIYA

  // Payouts & Settlement
  final double totalPaidToVendor;
  final double outstandingVendorPayable; // totalVendorPayable - totalPaidToVendor

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
    required this.totalMaterialTaxable,
    required this.totalEligibleInputGst,
    required this.totalMaterialCost,
    required this.vendorCharges,
    required this.otherExpenses,
    required this.totalVendorPayable,
    required this.totalSiteAmount,
    required this.amountReceivedBySiya,
    required this.totalPaidToVendor,
    required this.outstandingVendorPayable,
  });

  /// Factory calculator that computes dynamic financials from actual material entries
  factory SiteFinancialDetail.compute({
    required VendorSiteAssignment assignment,
    required List<VendorMaterialTransaction> materials,
    required List<VendorPayout> payouts,
  }) {
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

    final m5Total = m5Taxable + m5Gst;
    final m18Total = m18Taxable + m18Gst;
    final totMaterialTaxable = m5Taxable + m18Taxable;
    final totEligibleInputGst = m5Gst + m18Gst;
    final totMaterialCost = m5Total + m18Total;

    // Vendor charges: Installed Capacity × ₹1,000/kW (or assigned rate)
    final charges = assignment.siteCapacityKw * assignment.ratePerKw;
    final expenses = assignment.otherExpenses;
    final totVendorPayable = charges + expenses;

    // Site Amount & Received from Customer
    final siteAmt = assignment.customerTotalAmount;
    final siyaRecv = assignment.customerPaidAmount;

    // Payouts made to sub-vendor for this site
    double paidToVendor = 0.0;
    for (final p in payouts) {
      if (p.assignmentId == assignment.id || p.assignmentId == null) {
        paidToVendor += p.amount;
      }
    }

    final outstanding = totVendorPayable - paidToVendor;

    return SiteFinancialDetail(
      assignment: assignment,
      materials: materials,
      payouts: payouts,
      material5Taxable: double.parse(m5Taxable.toStringAsFixed(2)),
      material5Gst: double.parse(m5Gst.toStringAsFixed(2)),
      material5Total: double.parse(m5Total.toStringAsFixed(2)),
      material18Taxable: double.parse(m18Taxable.toStringAsFixed(2)),
      material18Gst: double.parse(m18Gst.toStringAsFixed(2)),
      material18Total: double.parse(m18Total.toStringAsFixed(2)),
      totalMaterialTaxable: double.parse(totMaterialTaxable.toStringAsFixed(2)),
      totalEligibleInputGst: double.parse(totEligibleInputGst.toStringAsFixed(2)),
      totalMaterialCost: double.parse(totMaterialCost.toStringAsFixed(2)),
      vendorCharges: double.parse(charges.toStringAsFixed(2)),
      otherExpenses: double.parse(expenses.toStringAsFixed(2)),
      totalVendorPayable: double.parse(totVendorPayable.toStringAsFixed(2)),
      totalSiteAmount: double.parse(siteAmt.toStringAsFixed(2)),
      amountReceivedBySiya: double.parse(siyaRecv.toStringAsFixed(2)),
      totalPaidToVendor: double.parse(paidToVendor.toStringAsFixed(2)),
      outstandingVendorPayable: double.parse(outstanding.toStringAsFixed(2)),
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

  // Dynamic Material Costs Breakdown
  final double material5Taxable;
  final double material5Gst;
  final double material5Total;

  final double material18Taxable;
  final double material18Gst;
  final double material18Total;

  final double totalMaterialTaxable;
  final double totalEligibleInputGst;
  final double totalMaterialCost;

  // SIYA Vendor Charges (Installed Capacity × ₹1,000/kW)
  final double totalVendorCharges;
  final double totalOtherExpenses;
  final double totalSettlementAmount; // totalVendorCharges + totalOtherExpenses

  // Payments & Balance
  final double totalPaidAmount;
  final double outstandingSettlement; // totalSettlementAmount - totalPaidAmount

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
    required this.material5Taxable,
    required this.material5Gst,
    required this.material5Total,
    required this.material18Taxable,
    required this.material18Gst,
    required this.material18Total,
    required this.totalMaterialTaxable,
    required this.totalEligibleInputGst,
    required this.totalMaterialCost,
    required this.totalVendorCharges,
    required this.totalOtherExpenses,
    required this.totalSettlementAmount,
    required this.totalPaidAmount,
    required this.outstandingSettlement,
    required this.siteDetails,
  });

  /// Factory calculator that computes dynamic summary from site assignments, materials, and payouts
  factory VendorFinancialSummary.compute({
    required String vendorId,
    required String vendorCode,
    required String vendorName,
    required List<VendorSiteAssignment> assignments,
    required List<VendorMaterialTransaction> allMaterials,
    required List<VendorPayout> allPayouts,
  }) {
    int completed = 0;
    int pending = 0;
    double totKw = 0.0;
    double totSiteAmt = 0.0;
    double totRecvSiya = 0.0;
    double m5Tax = 0.0;
    double m5Gst = 0.0;
    double m18Tax = 0.0;
    double m18Gst = 0.0;
    double charges = 0.0;
    double expenses = 0.0;

    final siteDetails = <SiteFinancialDetail>[];

    for (final assignment in assignments) {
      if (assignment.isCompleted) {
        completed++;
      } else {
        pending++;
      }

      totKw += assignment.siteCapacityKw;
      totSiteAmt += assignment.customerTotalAmount;
      totRecvSiya += assignment.customerPaidAmount;

      final siteMaterials = allMaterials.where((m) => m.assignmentId == assignment.id).toList();
      final sitePayouts = allPayouts.where((p) => p.assignmentId == assignment.id).toList();

      final detail = SiteFinancialDetail.compute(
        assignment: assignment,
        materials: siteMaterials,
        payouts: sitePayouts,
      );

      m5Tax += detail.material5Taxable;
      m5Gst += detail.material5Gst;
      m18Tax += detail.material18Taxable;
      m18Gst += detail.material18Gst;
      charges += detail.vendorCharges;
      expenses += detail.otherExpenses;

      siteDetails.add(detail);
    }

    final m5Tot = m5Tax + m5Gst;
    final m18Tot = m18Tax + m18Gst;
    final totMatTaxable = m5Tax + m18Tax;
    final totInputGst = m5Gst + m18Gst;
    final totMatCost = m5Tot + m18Tot;

    final settlement = charges + expenses;

    // Total payouts across all sites for this vendor
    double totalPaid = 0.0;
    for (final p in allPayouts) {
      totalPaid += p.amount;
    }

    final outstanding = settlement - totalPaid;

    return VendorFinancialSummary(
      vendorId: vendorId,
      vendorCode: vendorCode,
      vendorName: vendorName,
      totalAssignedSites: assignments.length,
      completedSites: completed,
      pendingSites: pending,
      totalCapacityKw: double.parse(totKw.toStringAsFixed(2)),
      totalSiteAmount: double.parse(totSiteAmt.toStringAsFixed(2)),
      totalReceivedBySiya: double.parse(totRecvSiya.toStringAsFixed(2)),
      material5Taxable: double.parse(m5Tax.toStringAsFixed(2)),
      material5Gst: double.parse(m5Gst.toStringAsFixed(2)),
      material5Total: double.parse(m5Tot.toStringAsFixed(2)),
      material18Taxable: double.parse(m18Tax.toStringAsFixed(2)),
      material18Gst: double.parse(m18Gst.toStringAsFixed(2)),
      material18Total: double.parse(m18Tot.toStringAsFixed(2)),
      totalMaterialTaxable: double.parse(totMatTaxable.toStringAsFixed(2)),
      totalEligibleInputGst: double.parse(totInputGst.toStringAsFixed(2)),
      totalMaterialCost: double.parse(totMatCost.toStringAsFixed(2)),
      totalVendorCharges: double.parse(charges.toStringAsFixed(2)),
      totalOtherExpenses: double.parse(expenses.toStringAsFixed(2)),
      totalSettlementAmount: double.parse(settlement.toStringAsFixed(2)),
      totalPaidAmount: double.parse(totalPaid.toStringAsFixed(2)),
      outstandingSettlement: double.parse(outstanding.toStringAsFixed(2)),
      siteDetails: siteDetails,
    );
  }
}

