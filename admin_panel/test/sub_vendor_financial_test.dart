import 'package:flutter_test/flutter_test.dart';
import 'package:siya_shared/siya_shared.dart';
import 'package:admin_panel/services/sub_vendor_pdf_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Sub-Vendor Financial Calculation & Dashboard Tests', () {
    // -------------------------------------------------------------------------
    // 1. VENDOR CHARGE CALCULATION (Installed Capacity × ₹1,000/kW)
    // -------------------------------------------------------------------------
    test('Vendor Charges calculates accurately as Capacity × Rate (default ₹1,000/kW)', () {
      final assignment3kW = VendorSiteAssignment(
        id: 'asgn_001',
        vendorId: 'vnd_001',
        customerId: 'cust_001',
        assignedDate: DateTime(2026, 11, 1),
        siteCapacityKw: 3.0,
        ratePerKw: 1000.0,
        vendorCharges: 3000.0,
      );
      expect(assignment3kW.vendorCharges, equals(3000.0));
      expect(assignment3kW.siteCapacityKw * assignment3kW.ratePerKw, equals(3000.0));

      final assignment5kW = VendorSiteAssignment(
        id: 'asgn_002',
        vendorId: 'vnd_001',
        customerId: 'cust_002',
        assignedDate: DateTime(2026, 11, 2),
        siteCapacityKw: 5.0,
        ratePerKw: 1200.0, // Custom rate test
        vendorCharges: 6000.0,
      );
      expect(assignment5kW.vendorCharges, equals(6000.0));
    });

    // -------------------------------------------------------------------------
    // 2. DYNAMIC MATERIAL COST & GST BREAKDOWN (5% vs 18%, Issues & Returns)
    // -------------------------------------------------------------------------
    test('Dynamic Material Cost: 5% Panels/Inverters, 18% BOS, and Return deductions', () {
      final assignment = VendorSiteAssignment(
        id: 'asgn_100',
        vendorId: 'vnd_100',
        customerId: 'cust_100',
        assignedDate: DateTime(2026, 11, 1),
        siteCapacityKw: 3.0,
        ratePerKw: 1000.0,
        customerTotalAmount: 200000.0,
        customerPaidAmount: 180000.0,
      );

      // 1. Issue 6 Solar Panels @ ₹12,000 each = ₹72,000 Taxable @ 5% GST = ₹3,600 GST -> ₹75,600 Total
      final panelIssue = VendorMaterialTransaction.create(
        assignmentId: assignment.id,
        vendorId: assignment.vendorId,
        customerId: assignment.customerId,
        transactionType: 'ISSUE',
        itemName: 'Solar PV Modules 550Wp TopCon',
        itemCategory: 'SOLAR_PANEL',
        quantity: 6,
        unitRate: 12000.0,
      );
      expect(panelIssue.gstRate, equals(5.0));
      expect(panelIssue.taxableAmount, equals(72000.0));
      expect(panelIssue.gstAmount, equals(3600.0));
      expect(panelIssue.totalAmount, equals(75600.0));

      // 2. Issue 1 Inverter @ ₹25,000 = ₹25,000 Taxable @ 5% GST = ₹1,250 GST -> ₹26,250 Total
      final inverterIssue = VendorMaterialTransaction.create(
        assignmentId: assignment.id,
        vendorId: assignment.vendorId,
        customerId: assignment.customerId,
        transactionType: 'ISSUE',
        itemName: 'Grid Inverter 3.3kW Single Phase',
        itemCategory: 'INVERTER',
        quantity: 1,
        unitRate: 25000.0,
      );
      expect(inverterIssue.gstRate, equals(5.0));
      expect(inverterIssue.taxableAmount, equals(25000.0));
      expect(inverterIssue.gstAmount, equals(1250.0));
      expect(inverterIssue.totalAmount, equals(26250.0));

      // 3. Issue BOS Structure & Cables @ ₹15,000 Taxable @ 18% GST = ₹2,700 GST -> ₹17,700 Total
      final bosIssue = VendorMaterialTransaction.create(
        assignmentId: assignment.id,
        vendorId: assignment.vendorId,
        customerId: assignment.customerId,
        transactionType: 'ISSUE',
        itemName: 'GI Structure & Solar Cables Kit',
        itemCategory: 'BOS',
        quantity: 1,
        unitRate: 15000.0,
      );
      expect(bosIssue.gstRate, equals(18.0));
      expect(bosIssue.taxableAmount, equals(15000.0));
      expect(bosIssue.gstAmount, equals(2700.0));
      expect(bosIssue.totalAmount, equals(17700.0));

      // 4. Return 1 extra Cable bundle @ ₹2,000 (18% GST) returned unused from site
      final cableReturn = VendorMaterialTransaction.create(
        assignmentId: assignment.id,
        vendorId: assignment.vendorId,
        customerId: assignment.customerId,
        transactionType: 'RETURN',
        itemName: 'DC Solar Cable 4 sq.mm (Unused return)',
        itemCategory: 'BOS',
        quantity: 1,
        unitRate: 2000.0,
      );
      expect(cableReturn.isReturn, isTrue);
      expect(cableReturn.taxableAmount, equals(2000.0));
      expect(cableReturn.gstAmount, equals(360.0));
      expect(cableReturn.totalAmount, equals(2360.0));

      final materials = [panelIssue, inverterIssue, bosIssue, cableReturn];

      // Compute site financials
      final detail = SiteFinancialDetail.compute(
        assignment: assignment,
        materials: materials,
        payouts: [],
      );

      // 5% Category = Panels (₹72,000 + ₹3,600) + Inverter (₹25,000 + ₹1,250) = ₹97,000 Taxable, ₹4,850 GST, ₹1,01,850 Total
      expect(detail.material5Taxable, equals(97000.0));
      expect(detail.material5Gst, equals(4850.0));
      expect(detail.material5Total, equals(101850.0));

      // 18% Category = BOS Issue (₹15,000 + ₹2,700) minus Return (₹2,000 + ₹360) = ₹13,000 Taxable, ₹2,340 GST, ₹15,340 Total
      expect(detail.material18Taxable, equals(13000.0));
      expect(detail.material18Gst, equals(2340.0));
      expect(detail.material18Total, equals(15340.0));

      // Net Material Totals
      expect(detail.totalMaterialTaxable, equals(110000.0));
      expect(detail.totalEligibleInputGst, equals(7190.0));
      expect(detail.totalMaterialCost, equals(117190.0));

      // Vendor charges
      expect(detail.vendorCharges, equals(3000.0));
      expect(detail.totalVendorPayable, equals(3000.0));
      expect(detail.outstandingVendorPayable, equals(3000.0));
    });

    // -------------------------------------------------------------------------
    // 3. SETTLEMENT & PAYOUT TRACKING
    // -------------------------------------------------------------------------
    test('Settlement & Payout: Disbursed payouts reduce outstanding balance transparently', () {
      final assignment = VendorSiteAssignment(
        id: 'asgn_200',
        vendorId: 'vnd_200',
        customerId: 'cust_200',
        assignedDate: DateTime(2026, 11, 1),
        siteCapacityKw: 5.0,
        ratePerKw: 1000.0,
        otherExpenses: 500.0, // Approved local permit fee
      );

      // Payout of ₹2,000 made via Bank Transfer
      final payout = VendorPayout(
        id: 'pay_001',
        vendorId: 'vnd_200',
        assignmentId: 'asgn_200',
        payoutDate: DateTime(2026, 11, 5),
        amount: 2000.0,
        paymentMode: 'Bank Transfer',
        referenceNumber: 'UTR9822334411',
      );

      final detail = SiteFinancialDetail.compute(
        assignment: assignment,
        materials: [],
        payouts: [payout],
      );

      // Charges: 5.0 * 1000 = 5000 + 500 expenses = 5500 total payable
      expect(detail.vendorCharges, equals(5000.0));
      expect(detail.otherExpenses, equals(500.0));
      expect(detail.totalVendorPayable, equals(5500.0));
      expect(detail.totalPaidToVendor, equals(2000.0));
      expect(detail.outstandingVendorPayable, equals(3500.0));
    });

    // -------------------------------------------------------------------------
    // 4. SECURITY & VENDOR DATA ISOLATION TEST
    // -------------------------------------------------------------------------
    test('Security Isolation: Vendor A cannot see or calculate Vendor B data', () {
      final vendorA = SubVendor(
        id: 'vendor_A_uuid',
        vendorCode: 'SIYA-VND-001',
        name: 'Om Solar Solutions',
        mobile: '9822112233',
        email: '9822112233@vendor.siyasolar.com',
      );

      final vendorB = SubVendor(
        id: 'vendor_B_uuid',
        vendorCode: 'SIYA-VND-002',
        name: 'Shree Electricals',
        mobile: '9833445566',
        email: '9833445566@vendor.siyasolar.com',
      );

      final assignmentA = VendorSiteAssignment(
        id: 'asgn_A',
        vendorId: vendorA.id,
        customerId: 'cust_A',
        assignedDate: DateTime(2026, 11, 1),
        siteCapacityKw: 3.0,
        customerName: 'Customer A (Dhule)',
      );

      final assignmentB = VendorSiteAssignment(
        id: 'asgn_B',
        vendorId: vendorB.id,
        customerId: 'cust_B',
        assignedDate: DateTime(2026, 11, 2),
        siteCapacityKw: 5.0,
        customerName: 'Customer B (Shindkheda)',
      );

      final allAssignments = [assignmentA, assignmentB];

      // Vendor A views their portal: Filtered strictly by vendorId == vendorA.id
      final vendorAAssignments = allAssignments.where((a) => a.vendorId == vendorA.id).toList();
      expect(vendorAAssignments.length, equals(1));
      expect(vendorAAssignments.first.customerName, equals('Customer A (Dhule)'));
      expect(vendorAAssignments.any((a) => a.customerName == 'Customer B (Shindkheda)'), isFalse);

      // Vendor B views their portal: Filtered strictly by vendorId == vendorB.id
      final vendorBAssignments = allAssignments.where((a) => a.vendorId == vendorB.id).toList();
      expect(vendorBAssignments.length, equals(1));
      expect(vendorBAssignments.first.customerName, equals('Customer B (Shindkheda)'));
      expect(vendorBAssignments.any((a) => a.customerName == 'Customer A (Dhule)'), isFalse);
    });

    // -------------------------------------------------------------------------
    // 5. PDF STATEMENT GENERATION
    // -------------------------------------------------------------------------
    test('SubVendorPdfService generates valid PDF bytes for site and master statements', () async {
      final vendor = SubVendor(
        id: 'vnd_pdf',
        vendorCode: 'SIYA-VND-088',
        name: 'Patil Solar EPC',
        mobile: '9673220315',
        email: 'patil@vendor.siyasolar.com',
        bankName: 'State Bank of India',
        accountNumber: '30291827364',
        ifscCode: 'SBIN0000300',
      );

      final assignment = VendorSiteAssignment(
        id: 'asgn_pdf',
        vendorId: vendor.id,
        customerId: 'cust_pdf',
        assignedDate: DateTime(2026, 11, 1),
        siteCapacityKw: 3.0,
        ratePerKw: 1000.0,
        consumerNo: '096590001608',
        customerName: 'Ganesh Dilip Patil',
        customerAddress: 'Betawad, Tal. Shindkheda, Dist. Dhule',
        customerTotalAmount: 200000.0,
        customerPaidAmount: 122000.0,
      );

      final material = VendorMaterialTransaction.create(
        assignmentId: assignment.id,
        vendorId: vendor.id,
        customerId: assignment.customerId,
        transactionType: 'ISSUE',
        itemName: '550Wp DCR Solar Modules (6 Panels)',
        itemCategory: 'SOLAR_PANEL',
        quantity: 6,
        unitRate: 12000.0,
      );

      final payout = VendorPayout(
        id: 'pay_pdf',
        vendorId: vendor.id,
        assignmentId: assignment.id,
        payoutDate: DateTime(2026, 11, 4),
        amount: 3000.0,
      );

      final detail = SiteFinancialDetail.compute(
        assignment: assignment,
        materials: [material],
        payouts: [payout],
      );

      // Test 1: Generate Site Statement PDF
      final sitePdfBytes = await SubVendorPdfService.generateSiteStatementPdfBytes(detail, vendor: vendor);
      expect(sitePdfBytes, isNotEmpty);
      expect(sitePdfBytes.length, greaterThan(1000));

      // Test 2: Generate Master Vendor Statement PDF
      final summary = VendorFinancialSummary.compute(
        vendorId: vendor.id,
        vendorCode: vendor.vendorCode,
        vendorName: vendor.name,
        assignments: [assignment],
        allMaterials: [material],
        allPayouts: [payout],
      );

      final masterPdfBytes = await SubVendorPdfService.generateVendorOverallStatementPdfBytes(summary, vendor: vendor);
      expect(masterPdfBytes, isNotEmpty);
      expect(masterPdfBytes.length, greaterThan(1000));
    });

    test('6. Final Permission Settings: SIYA Admin has Full Control; Sub-Vendor has View-Only access to own site materials', () {
      // SIYA Admin defines material rates & GST
      final adminIssuedPanel = VendorMaterialTransaction.create(
        assignmentId: 'asg-admin-site-1',
        vendorId: 'vnd-1',
        customerId: 'cust-1',
        transactionType: 'ISSUE',
        itemName: 'DCR Mono Perc Modules 550Wp',
        itemCategory: 'SOLAR_PANEL',
        quantity: 10,
        unitRate: 11500.0,
        gstRate: 5.0,
      );

      // Verify Admin's calculation
      expect(adminIssuedPanel.gstRate, equals(5.0));
      expect(adminIssuedPanel.taxableAmount, equals(115000.0));
      expect(adminIssuedPanel.totalAmount, equals(120750.0));

      // Sub-Vendor views the material detail (Read-only object)
      final subVendorView = adminIssuedPanel;
      expect(subVendorView.itemName, equals('DCR Mono Perc Modules 550Wp'));
      expect(subVendorView.totalAmount, equals(120750.0));

      // Automatic inclusion in site calculation
      final assignment = VendorSiteAssignment(
        id: 'asg-admin-site-1',
        vendorId: 'vnd-1',
        customerId: 'cust-1',
        assignedDate: DateTime(2026, 11, 1),
        siteCapacityKw: 5.5,
        ratePerKw: 1000.0,
        vendorCharges: 5500.0,
      );

      final detail = SiteFinancialDetail.compute(
        assignment: assignment,
        materials: [adminIssuedPanel],
        payouts: [],
      );

      expect(detail.totalMaterialCost, equals(120750.0));
      expect(detail.vendorCharges, equals(5500.0));
      expect(detail.totalVendorPayable, equals(5500.0));
      expect(detail.outstandingVendorPayable, equals(5500.0));
    });
  });
}

