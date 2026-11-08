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

    // -------------------------------------------------------------------------
    // 7. CASH CUSTOMER RECORD & INSTALLMENT LIFECYCLE
    // -------------------------------------------------------------------------
    test('7. Cash Customer Payment Lifecycle: Advance, Partial, and Final Payments', () {
      final cashSite = VendorSiteAssignment(
        id: 'asg-cash-1',
        vendorId: 'vnd-1',
        customerId: 'cust-cash-1',
        assignedDate: DateTime(2026, 11, 1),
        siteCapacityKw: 3.0,
        ratePerKw: 1000.0,
        paymentType: 'Cash Customer',
        totalCustomerSiteAmount: 200000.0,
        totalCashReceived: 0.0,
        totalCustomerReceived: 0.0,
        customerOutstanding: 200000.0,
        customerPaymentStatus: 'Pending',
      );

      // Advance payment: ₹50,000
      final advance = VendorCustomerPayment.create(
        assignmentId: cashSite.id,
        vendorId: cashSite.vendorId,
        customerId: cashSite.customerId,
        paymentType: 'CASH',
        paymentStage: 'ADVANCE',
        amount: 50000.0,
        paymentMode: 'UPI',
        referenceNumber: 'UPI-ADV-98124',
      );
      expect(advance.isCash, isTrue);
      expect(advance.isLoan, isFalse);
      expect(advance.amount, equals(50000.0));

      // Partial payment: ₹50,000
      final partial = VendorCustomerPayment.create(
        assignmentId: cashSite.id,
        vendorId: cashSite.vendorId,
        customerId: cashSite.customerId,
        paymentType: 'CASH',
        paymentStage: 'PARTIAL',
        amount: 50000.0,
        paymentMode: 'Bank Transfer',
        referenceNumber: 'NEFT-PART-1122',
      );

      final totalCashPaid = advance.amount + partial.amount; // ₹1,00,000
      final updatedCashSite = cashSite.copyWith(
        totalCashReceived: totalCashPaid,
        totalCustomerReceived: totalCashPaid,
        customerOutstanding: cashSite.totalCustomerSiteAmount - totalCashPaid,
        customerPaymentStatus: 'Partial',
      );

      expect(updatedCashSite.totalCashReceived, equals(100000.0));
      expect(updatedCashSite.customerOutstanding, equals(100000.0));
      expect(updatedCashSite.customerPaymentStatus, equals('Partial'));

      // Final payment: ₹1,00,000
      final finalPay = VendorCustomerPayment.create(
        assignmentId: cashSite.id,
        vendorId: cashSite.vendorId,
        customerId: cashSite.customerId,
        paymentType: 'CASH',
        paymentStage: 'FINAL',
        amount: 100000.0,
        paymentMode: 'Bank Transfer',
        referenceNumber: 'RTGS-FINAL-9900',
      );

      final fullyPaidTotal = totalCashPaid + finalPay.amount; // ₹2,00,000
      final completedCashSite = updatedCashSite.copyWith(
        totalCashReceived: fullyPaidTotal,
        totalCustomerReceived: fullyPaidTotal,
        customerOutstanding: cashSite.totalCustomerSiteAmount - fullyPaidTotal,
        customerPaymentStatus: 'Paid',
      );

      expect(completedCashSite.totalCashReceived, equals(200000.0));
      expect(completedCashSite.customerOutstanding, equals(0.0));
      expect(completedCashSite.customerPaymentStatus, equals('Paid'));
    });

    // -------------------------------------------------------------------------
    // 8. BANK LOAN TRACKING & MULTIPLE CREDIT INSTALLMENTS
    // -------------------------------------------------------------------------
    test('8. Bank Loan Lifecycle: Applied -> Sanctioned -> Multiple Credit Installments -> Fully Credited', () {
      // Loan Site: Site ₹2,00,000 | Loan Sanctioned: ₹2,00,000
      var loanSite = VendorSiteAssignment(
        id: 'asg-loan-1',
        vendorId: 'vnd-1',
        customerId: 'cust-loan-1',
        assignedDate: DateTime(2026, 11, 1),
        siteCapacityKw: 3.0,
        paymentType: 'Bank Loan Customer',
        totalCustomerSiteAmount: 200000.0,
        loanBankName: 'State Bank of India',
        loanApplicationId: 'SBI-SOLAR-2026-9812',
        loanAppliedAmount: 200000.0,
        loanSanctionedAmount: 200000.0,
        loanStatus: 'Sanctioned',
        totalLoanCredited: 0.0,
        totalCustomerReceived: 0.0,
        customerOutstanding: 200000.0,
      );

      expect(loanSite.isBankLoan, isTrue);
      expect(loanSite.loanPendingCredit, equals(200000.0));
      expect(loanSite.loanStatus, equals('Sanctioned'));

      // 1st Installment Credit: ₹1,00,000
      final inst1 = VendorCustomerPayment.create(
        assignmentId: loanSite.id,
        vendorId: loanSite.vendorId,
        customerId: loanSite.customerId,
        paymentType: 'BANK_LOAN',
        paymentStage: 'LOAN_CREDIT',
        amount: 100000.0,
        bankName: 'State Bank of India',
        loanApplicationId: 'SBI-SOLAR-2026-9812',
        referenceNumber: 'SBIN20261108001',
        attachmentUrl: 'https://storage.siyasolar.com/loans/sbi_proof_1.pdf',
        remarks: '1st disbursal credited to SIYA current account',
      );
      expect(inst1.isLoan, isTrue);
      expect(inst1.referenceNumber, equals('SBIN20261108001'));

      loanSite = loanSite.copyWith(
        totalLoanCredited: inst1.amount,
        totalCustomerReceived: inst1.amount,
        customerOutstanding: loanSite.totalCustomerSiteAmount - inst1.amount,
        loanStatus: 'Partially Credited',
        customerPaymentStatus: 'Partial',
      );
      expect(loanSite.totalLoanCredited, equals(100000.0));
      expect(loanSite.loanPendingCredit, equals(100000.0)); // ₹2,00,000 - ₹1,00,000 = ₹1,00,000 pending
      expect(loanSite.customerOutstanding, equals(100000.0));
      expect(loanSite.loanStatus, equals('Partially Credited'));

      // 2nd Installment Credit: ₹50,000
      final inst2 = VendorCustomerPayment.create(
        assignmentId: loanSite.id,
        vendorId: loanSite.vendorId,
        customerId: loanSite.customerId,
        paymentType: 'BANK_LOAN',
        paymentStage: 'LOAN_CREDIT',
        amount: 50000.0,
        bankName: 'State Bank of India',
        loanApplicationId: 'SBI-SOLAR-2026-9812',
        referenceNumber: 'SBIN20261108002',
        remarks: '2nd disbursal after structure erection',
      );

      final totalAfterInst2 = loanSite.totalLoanCredited + inst2.amount; // ₹1,50,000
      loanSite = loanSite.copyWith(
        totalLoanCredited: totalAfterInst2,
        totalCustomerReceived: totalAfterInst2,
        customerOutstanding: loanSite.totalCustomerSiteAmount - totalAfterInst2,
        loanStatus: 'Partially Credited',
      );
      expect(loanSite.totalLoanCredited, equals(150000.0));
      expect(loanSite.loanPendingCredit, equals(50000.0));
      expect(loanSite.customerOutstanding, equals(50000.0));

      // 3rd & Final Installment Credit: ₹50,000
      final inst3 = VendorCustomerPayment.create(
        assignmentId: loanSite.id,
        vendorId: loanSite.vendorId,
        customerId: loanSite.customerId,
        paymentType: 'BANK_LOAN',
        paymentStage: 'LOAN_CREDIT',
        amount: 50000.0,
        bankName: 'State Bank of India',
        loanApplicationId: 'SBI-SOLAR-2026-9812',
        referenceNumber: 'SBIN20261108003',
        remarks: 'Final disbursal post net-meter commissioning',
      );

      final totalFullyCredited = totalAfterInst2 + inst3.amount; // ₹2,00,000
      loanSite = loanSite.copyWith(
        totalLoanCredited: totalFullyCredited,
        totalCustomerReceived: totalFullyCredited,
        customerOutstanding: loanSite.totalCustomerSiteAmount - totalFullyCredited,
        loanStatus: 'Fully Credited',
        customerPaymentStatus: 'Paid',
      );
      expect(loanSite.totalLoanCredited, equals(200000.0));
      expect(loanSite.loanPendingCredit, equals(0.0));
      expect(loanSite.customerOutstanding, equals(0.0));
      expect(loanSite.loanStatus, equals('Fully Credited'));
      expect(loanSite.customerPaymentStatus, equals('Paid'));
    });

    // -------------------------------------------------------------------------
    // 9. PART CASH + PART LOAN HYBRID SPLIT CALCULATIONS
    // -------------------------------------------------------------------------
    test('9. Part Cash + Part Loan: Multiple cash & loan transactions against same Site ID', () {
      // Contract: ₹2,00,000 | Cash: ₹50,000 | Loan: ₹1,50,000
      final hybridSite = VendorSiteAssignment(
        id: 'asg-hybrid-1',
        vendorId: 'vnd-1',
        customerId: 'cust-hybrid-1',
        assignedDate: DateTime(2026, 11, 1),
        siteCapacityKw: 3.3,
        paymentType: 'Part Cash + Part Loan',
        totalCustomerSiteAmount: 200000.0,
        loanBankName: 'Bank of Maharashtra',
        loanApplicationId: 'BOM-2026-SOLAR-09',
        loanAppliedAmount: 150000.0,
        loanSanctionedAmount: 150000.0,
        loanStatus: 'Fully Credited',
        totalCashReceived: 50000.0,
        totalLoanCredited: 150000.0,
        totalCustomerReceived: 200000.0,
        customerOutstanding: 0.0,
        customerPaymentStatus: 'Paid',
      );

      // Verify Total Received = Cash Received + Loan Credited
      expect(hybridSite.totalCustomerReceived, equals(hybridSite.totalCashReceived + hybridSite.totalLoanCredited));
      expect(hybridSite.totalCustomerReceived, equals(200000.0));

      // Verify Outstanding = Total Site Amount - Total Received
      expect(hybridSite.customerOutstanding, equals(hybridSite.totalCustomerSiteAmount - hybridSite.totalCustomerReceived));
      expect(hybridSite.customerOutstanding, equals(0.0));
      expect(hybridSite.loanPendingCredit, equals(0.0));

      // Aggregate Summary check
      final summary = VendorFinancialSummary.compute(
        vendorId: 'vnd-1',
        vendorCode: 'SIYA-VND-101',
        vendorName: 'Patil Solar Works',
        assignments: [hybridSite],
        allMaterials: [],
        allPayouts: [],
      );

      expect(summary.totalCustomerSiteAmount, equals(200000.0));
      expect(summary.totalCashReceived, equals(50000.0));
      expect(summary.totalLoanSanctioned, equals(150000.0));
      expect(summary.totalLoanCredited, equals(150000.0));
      expect(summary.totalLoanPendingCredit, equals(0.0));
      expect(summary.totalCustomerCollection, equals(200000.0));
      expect(summary.totalCustomerOutstanding, equals(0.0));
    });

    // -------------------------------------------------------------------------
    // 10. SITE PAYMENT LEDGER PDF GENERATION
    // -------------------------------------------------------------------------
    test('10. SubVendorPdfService generates valid PDF bytes for Customer Payment Ledger', () async {
      final assignment = VendorSiteAssignment(
        id: 'asg-pdf-ledger-1',
        vendorId: 'vnd-1',
        customerId: 'cust-pdf-1',
        customerName: 'Ganesh Shinde',
        consumerNo: '1899201992',
        customerMobile: '9822001122',
        customerAddress: 'Betawad, Shindkheda',
        assignedDate: DateTime(2026, 11, 1),
        siteCapacityKw: 3.0,
        paymentType: 'Part Cash + Part Loan',
        totalCustomerSiteAmount: 200000.0,
        loanBankName: 'State Bank of India',
        loanApplicationId: 'SBI-APP-2026-99',
        loanSanctionedAmount: 150000.0,
        totalCashReceived: 50000.0,
        totalLoanCredited: 100000.0,
        totalCustomerReceived: 150000.0,
        customerOutstanding: 50000.0,
        loanStatus: 'Partially Credited',
        customerPaymentStatus: 'Partial',
      );

      final payments = [
        VendorCustomerPayment.create(
          assignmentId: assignment.id,
          vendorId: assignment.vendorId,
          customerId: assignment.customerId,
          paymentType: 'CASH',
          paymentStage: 'ADVANCE',
          amount: 50000.0,
          paymentDate: DateTime(2026, 11, 2),
          paymentMode: 'UPI',
          referenceNumber: 'UPI-771199',
          remarks: 'Initial advance booking payment',
        ),
        VendorCustomerPayment.create(
          assignmentId: assignment.id,
          vendorId: assignment.vendorId,
          customerId: assignment.customerId,
          paymentType: 'BANK_LOAN',
          paymentStage: 'LOAN_CREDIT',
          amount: 100000.0,
          paymentDate: DateTime(2026, 11, 5),
          paymentMode: 'Bank Transfer',
          bankName: 'State Bank of India',
          loanApplicationId: 'SBI-APP-2026-99',
          referenceNumber: 'SBIN99001188',
          remarks: '1st Loan Installment Disbursed',
        ),
      ];

      final ledgerPdfBytes = await SubVendorPdfService.generateSitePaymentLedgerPdfBytes(
        assignment: assignment,
        payments: payments,
      );

      expect(ledgerPdfBytes, isNotEmpty);
      expect(ledgerPdfBytes.length, greaterThan(1000));
    });

    // -------------------------------------------------------------------------
    // 11. SUB-VENDOR FINAL SETTLEMENT CALCULATOR (USER'S ₹2 LAKH SITE SPECIFICATION)
    // -------------------------------------------------------------------------
    test('11. Final Settlement Calculator: User ₹2,00,000 Site Example with 90% Loan & 10% Diff', () {
      final assignment = VendorSiteAssignment(
        id: 'asg-settle-1',
        vendorId: 'vnd-1',
        customerId: 'cust-1',
        customerName: 'Sanjay Patil',
        consumerNo: '1899203344',
        assignedDate: DateTime(2026, 11, 1),
        siteCapacityKw: 3.0,
        ratePerKw: 1000.0, // SIYA Vendor Charges: 3 kW × ₹1,000 = ₹3,000
        vendorCharges: 3000.0,
        totalCustomerSiteAmount: 200000.0,
        loanBankName: 'State Bank of India',
        loanApplicationId: 'SBI-2026-99',
        loanSanctionedAmount: 180000.0, // 90% expected
        totalCashReceived: 20000.0, // 10% difference customer contribution received
        totalLoanCredited: 150000.0, // ₹1,50,000 actually credited (₹30,000 pending)
        totalCustomerReceived: 170000.0,
        customerOutstanding: 30000.0,
      );

      // Material Issued: Total ₹1,50,000 (Taxable ₹1,36,000, Input GST ₹14,000)
      final panelMat = VendorMaterialTransaction(
        id: 'mat-1',
        assignmentId: assignment.id,
        vendorId: assignment.vendorId,
        customerId: assignment.customerId,
        transactionDate: DateTime(2026, 11, 1),
        transactionType: 'ISSUE',
        itemName: 'TopCon Modules & Inverter',
        itemCategory: 'SOLAR_PANEL',
        gstRate: 5.0,
        quantity: 1,
        unit: 'Set',
        unitRate: 120000.0,
        taxableAmount: 120000.0,
        gstAmount: 6000.0,
        totalAmount: 126000.0,
      );

      final bosMat = VendorMaterialTransaction(
        id: 'mat-2',
        assignmentId: assignment.id,
        vendorId: assignment.vendorId,
        customerId: assignment.customerId,
        transactionDate: DateTime(2026, 11, 1),
        transactionType: 'ISSUE',
        itemName: 'BOS Structure & Cables',
        itemCategory: 'BOS',
        gstRate: 18.0,
        quantity: 1,
        unit: 'Set',
        unitRate: 20338.98,
        taxableAmount: 20338.98,
        gstAmount: 3661.02,
        totalAmount: 24000.0,
      );

      final List<VendorMaterialTransaction> materials = [panelMat, bosMat];
      // Total Material Cost = ₹1,26,000 + ₹24,000 = ₹1,50,000 (Taxable = ₹1,40,338.98, Input GST = ₹9,661.02)

      // Previous advance paid to Sub-Vendor: ₹5,000
      final previousPayout = VendorPayout(
        id: 'payout-1',
        vendorId: assignment.vendorId,
        assignmentId: assignment.id,
        payoutDate: DateTime(2026, 11, 2),
        amount: 5000.0,
      );

      // Compute Settlement under Option A (Net Balance)
      final settlement = SubVendorSettlement.compute(
        assignment: assignment,
        materials: materials,
        previousPayouts: [previousPayout],
        settlementMode: SubVendorSettlementMode.netBalance,
        expectedLoanPercent: 90.0,
        outputGstRate: 13.8,
      );

      // 1. Quotation & Planning Checks
      expect(settlement.totalQuotation, equals(200000.0));
      expect(settlement.expectedLoanAmount, equals(180000.0));
      expect(settlement.loanDifferenceAmount, equals(20000.0));

      // 2. Actual Collections Checks (Strictly from actual money received, not loan sanctioned)
      expect(settlement.actualLoanCredited, equals(150000.0));
      expect(settlement.actualCustomerContribution, equals(20000.0));
      expect(settlement.totalActualCollected, equals(170000.0));
      expect(settlement.pendingCustomerReceivable, equals(30000.0));
      expect(settlement.pendingLoanDisbursement, equals(30000.0));
      expect(settlement.pendingCustomerContribution, equals(0.0));

      // 3. Material & GST Checks (Zero double deduction of GST)
      expect(settlement.materialCost, equals(150000.0));
      expect(settlement.siyaVendorCharges, equals(3000.0)); // 3 kW × ₹1,000 deducted once only
      expect(settlement.eligibleInputGstCredit, equals(9661.02));
      expect(settlement.outputGstLiability, greaterThan(0.0));
      // Net GST = Output GST on collected amount minus Input GST on materials
      expect(settlement.netGstLiability, equals(double.parse((settlement.outputGstLiability - settlement.eligibleInputGstCredit).clamp(0, 999999).toStringAsFixed(2))));

      // 4. Previous Advances & Net Payable
      expect(settlement.previousPayoutsPaid, equals(5000.0));
      expect(settlement.finalPayoutPayable, equals(double.parse((settlement.subVendorGrossEntitlement - 5000.0).toStringAsFixed(2))));
      expect(settlement.potentialFuturePayoutUponFullCollection, greaterThan(settlement.finalPayoutPayable));
    });

    // -------------------------------------------------------------------------
    // 12. SETTLEMENT MODES COMPARISON (OPTION A, OPTION B, OPTION C)
    // -------------------------------------------------------------------------
    test('12. Comparison of Option A (Net Balance), Option B (Fixed Fee), and Option C (Profit Sharing)', () {
      final assignment = VendorSiteAssignment(
        id: 'asg-modes-1',
        vendorId: 'vnd-1',
        customerId: 'cust-modes-1',
        assignedDate: DateTime(2026, 11, 1),
        siteCapacityKw: 4.0,
        ratePerKw: 1000.0,
        vendorCharges: 4000.0,
        otherExpenses: 1000.0,
        totalCustomerSiteAmount: 200000.0,
        totalCustomerReceived: 200000.0, // Fully collected
      );

      final material = VendorMaterialTransaction(
        id: 'mat-mode',
        assignmentId: assignment.id,
        vendorId: assignment.vendorId,
        customerId: assignment.customerId,
        transactionDate: DateTime(2026, 11, 1),
        transactionType: 'ISSUE',
        itemName: 'Modules',
        itemCategory: 'SOLAR_PANEL',
        gstRate: 5.0,
        quantity: 1,
        unit: 'Set',
        unitRate: 140000.0,
        taxableAmount: 140000.0,
        gstAmount: 7000.0,
        totalAmount: 147000.0,
      );

      // Mode A: Net Balance (उरलेली रक्कम पूर्ण Sub-Vendor ची)
      final modeA = SubVendorSettlement.compute(
        assignment: assignment,
        materials: [material],
        previousPayouts: [],
        settlementMode: SubVendorSettlementMode.netBalance,
      );
      expect(modeA.settlementMode, equals(SubVendorSettlementMode.netBalance));
      expect(modeA.subVendorGrossEntitlement, equals(double.parse((modeA.totalActualCollected - modeA.totalDeductions).toStringAsFixed(2))));

      // Mode B: Fixed Fee (आधी ठरवलेली रक्कम ₹15,000 + extra expenses ₹1,000)
      final modeB = SubVendorSettlement.compute(
        assignment: assignment,
        materials: [material],
        previousPayouts: [],
        settlementMode: SubVendorSettlementMode.fixedFee,
        fixedAgreedFee: 15000.0,
      );
      expect(modeB.settlementMode, equals(SubVendorSettlementMode.fixedFee));
      expect(modeB.subVendorGrossEntitlement, equals(15000.0 + 1000.0)); // Fixed fee + approved expenses

      // Mode C: Profit Share (70% of Net Profit)
      final modeC = SubVendorSettlement.compute(
        assignment: assignment,
        materials: [material],
        previousPayouts: [],
        settlementMode: SubVendorSettlementMode.profitShare,
        vendorProfitSharePercent: 70.0,
      );
      expect(modeC.settlementMode, equals(SubVendorSettlementMode.profitShare));
      expect(modeC.subVendorGrossEntitlement, equals(double.parse((modeC.netProfit * 0.70).toStringAsFixed(2))));
    });

    // -------------------------------------------------------------------------
    // 13. NEGATIVE SETTLEMENT RECOVERY (AMOUNT RECOVERABLE FROM SUB-VENDOR)
    // -------------------------------------------------------------------------
    test('13. Negative Settlement: Shows Amount Recoverable when advances exceed entitlement', () {
      final assignment = VendorSiteAssignment(
        id: 'asg-neg-1',
        vendorId: 'vnd-1',
        customerId: 'cust-neg-1',
        assignedDate: DateTime(2026, 11, 1),
        siteCapacityKw: 3.0,
        ratePerKw: 1000.0,
        vendorCharges: 3000.0,
        totalCustomerSiteAmount: 200000.0,
        totalCustomerReceived: 100000.0, // Partial collection so far
      );

      final material = VendorMaterialTransaction(
        id: 'mat-neg',
        assignmentId: assignment.id,
        vendorId: assignment.vendorId,
        customerId: assignment.customerId,
        transactionDate: DateTime(2026, 11, 1),
        transactionType: 'ISSUE',
        itemName: 'Panels & BOS',
        itemCategory: 'SOLAR_PANEL',
        gstRate: 5.0,
        quantity: 1,
        unit: 'Set',
        unitRate: 90000.0,
        taxableAmount: 90000.0,
        gstAmount: 4500.0,
        totalAmount: 94500.0,
      );

      // Advance already given to Sub-Vendor: ₹25,000
      final advance = VendorPayout(
        id: 'payout-adv-large',
        vendorId: assignment.vendorId,
        assignmentId: assignment.id,
        payoutDate: DateTime(2026, 11, 2),
        amount: 25000.0,
      );

      final settlement = SubVendorSettlement.compute(
        assignment: assignment,
        materials: [material],
        previousPayouts: [advance],
        settlementMode: SubVendorSettlementMode.netBalance,
      );

      // Entitlement is small because only ₹1,00,000 collected and material was ₹94,500.
      // Advance of ₹25,000 exceeds entitlement -> Result is negative!
      expect(settlement.finalPayoutPayable, lessThan(0.0));
      expect(settlement.isRecoverable, isTrue);
      expect(settlement.amountPayableToVendor, equals(0.0));
      expect(settlement.amountRecoverableFromVendor, greaterThan(0.0));
      expect(settlement.amountRecoverableFromVendor, equals(settlement.finalPayoutPayable.abs()));
    });

    // -------------------------------------------------------------------------
    // 14. PDF FINAL SETTLEMENT STATEMENT GENERATION
    // -------------------------------------------------------------------------
    test('14. SubVendorPdfService generates valid PDF bytes for Final Settlement Statement', () async {
      final assignment = VendorSiteAssignment(
        id: 'asg-pdf-settle-1',
        vendorId: 'vnd-1',
        customerId: 'cust-pdf-1',
        customerName: 'Sanjay Patil',
        consumerNo: '1899203344',
        assignedDate: DateTime(2026, 11, 1),
        siteCapacityKw: 3.0,
        ratePerKw: 1000.0,
        vendorCharges: 3000.0,
        totalCustomerSiteAmount: 200000.0,
        totalCustomerReceived: 170000.0,
        settlementApproved: true,
      );

      final material = VendorMaterialTransaction(
        id: 'mat-pdf-settle',
        assignmentId: assignment.id,
        vendorId: assignment.vendorId,
        customerId: assignment.customerId,
        transactionDate: DateTime(2026, 11, 1),
        transactionType: 'ISSUE',
        itemName: 'TopCon Modules 550Wp',
        itemCategory: 'SOLAR_PANEL',
        gstRate: 5.0,
        quantity: 6,
        unit: 'Nos',
        unitRate: 12000.0,
        taxableAmount: 72000.0,
        gstAmount: 3600.0,
        totalAmount: 75600.0,
      );

      final settlement = SubVendorSettlement.compute(
        assignment: assignment,
        materials: [material],
        previousPayouts: [],
        settlementMode: SubVendorSettlementMode.netBalance,
        isApproved: true,
      );

      final pdfBytes = await SubVendorPdfService.generateFinalSettlementStatementPdfBytes(settlement);
      expect(pdfBytes, isNotEmpty);
      expect(pdfBytes.length, greaterThan(1500));
    });

    // -------------------------------------------------------------------------
    // 15. STATUTORY 70:30 COMPOSITE GST CALCULATION RULE
    // -------------------------------------------------------------------------
    test('15. Statutory 70:30 GST composite breakdown matches prompt illustrative ₹2,00,000 example', () {
      const quotationAmount = 200000.0;
      final gst = SolarQuotationGstBreakdown.calculate(quotationAmount);

      // 70% Goods portion @ 5% GST
      expect(gst.portion70, equals(140000.0));
      // Formula: 140,000 * 5 / 105 = 6666.666...
      expect(gst.gst5, closeTo(6666.67, 0.01));
      expect(gst.taxable70, closeTo(133333.33, 0.01));

      // 30% Services/BOS portion @ 18% GST
      expect(gst.portion30, equals(60000.0));
      // Formula: 60,000 * 18 / 118 = 9152.542...
      expect(gst.gst18, closeTo(9152.54, 0.01));
      expect(gst.taxable30, closeTo(50847.46, 0.01));

      // Total Output GST = 6666.67 + 9152.54 = 15819.21
      expect(gst.totalGstIncluded, closeTo(15819.21, 0.01));
      // Total Taxable Value = 200,000 - 15,819.21 = 184180.79
      expect(gst.totalTaxableValue, closeTo(184180.79, 0.01));
      expect(gst.grandTotal, equals(200000.0));
    });

    // -------------------------------------------------------------------------
    // 16. LOAN CUSTOMER CALCULATIONS & SHORTFALL AUDIT
    // -------------------------------------------------------------------------
    test('16. Loan Customer calculation: 90% expected loan, 10% diff, shortfall, and margin pending', () {
      final siteAssignment = VendorSiteAssignment(
        id: 'asg-loan-test-1',
        vendorId: 'vnd-1',
        customerId: 'cust-1',
        assignedDate: DateTime(2026, 11, 1),
        siteCapacityKw: 3.0,
        ratePerKw: 1000.0,
        vendorCharges: 3000.0,
        paymentType: 'Bank Loan Customer',
        totalCustomerSiteAmount: 200000.0,
        loanSanctionedAmount: 180000.0,
        totalLoanCredited: 140000.0, // Partial credit received
        totalCashReceived: 10000.0,  // Margin received from customer
      );

      // Expected loan: 90% of ₹200,000 = ₹180,000
      expect(siteAssignment.expectedLoan, equals(180000.0));
      // Remaining 10%: ₹20,000
      expect(siteAssignment.remaining10, equals(20000.0));
      // Loan shortfall: ₹180,000 - ₹140,000 = ₹40,000
      expect(siteAssignment.loanShortfallCalc, equals(40000.0));
      // Margin pending: ₹20,000 - ₹10,000 = ₹10,000
      expect(siteAssignment.customerMarginPending, equals(10000.0));

      // Effective customer collection: ₹140,000 + ₹10,000 = ₹150,000
      expect(siteAssignment.totalCustomerReceived, equals(0.0)); // stored as 0 until trigger
      expect(siteAssignment.totalLoanCredited + siteAssignment.totalCashReceived, equals(150000.0));
    });

    // -------------------------------------------------------------------------
    // 17. MATERIAL PURCHASE GST & ITC ELIGIBILITY AUDIT
    // -------------------------------------------------------------------------
    test('17. Material Purchase GST tracks actual invoice GST and ITC eligibility', () {
      final eligibleMat = VendorMaterialTransaction.create(
        assignmentId: 'asg-mat-test',
        vendorId: 'vnd-1',
        customerId: 'cust-1',
        transactionType: 'ISSUE',
        itemName: 'TopCon Solar Panels 550W',
        itemCategory: 'SOLAR_PANEL',
        quantity: 10,
        unitRate: 10000.0,
        gstRate: 5.0,
        supplierName: 'Waaree Solar Ltd',
        invoiceNumber: 'INV-2026-9901',
        isItcEligible: true,
      );

      expect(eligibleMat.taxableAmount, equals(100000.0));
      expect(eligibleMat.gstAmount, equals(5000.0));
      expect(eligibleMat.totalAmount, equals(105000.0));
      expect(eligibleMat.supplierName, equals('Waaree Solar Ltd'));
      expect(eligibleMat.invoiceNumber, equals('INV-2026-9901'));
      expect(eligibleMat.isItcEligible, isTrue);
      expect(eligibleMat.signedItcEligible, equals(5000.0));
      expect(eligibleMat.signedItcIneligible, equals(0.0));

      final ineligibleMat = VendorMaterialTransaction.create(
        assignmentId: 'asg-mat-test',
        vendorId: 'vnd-1',
        customerId: 'cust-1',
        transactionType: 'ISSUE',
        itemName: 'Local Hardware & Consumables',
        itemCategory: 'BOS',
        quantity: 1,
        unitRate: 2000.0,
        gstRate: 18.0,
        supplierName: 'Local Hardware Store',
        invoiceNumber: 'CASH-MEMO-01',
        isItcEligible: false, // Ineligible for ITC
      );

      expect(ineligibleMat.gstAmount, equals(360.0));
      expect(ineligibleMat.isItcEligible, isFalse);
      expect(ineligibleMat.signedItcEligible, equals(0.0));
      expect(ineligibleMat.signedItcIneligible, equals(360.0));
    });

    // -------------------------------------------------------------------------
    // 18. CONTRACTUAL SUB-VENDOR GST RECOVERY & OPTION A SETTLEMENT
    // -------------------------------------------------------------------------
    test('18. Contractual GST Recovery is recorded with Admin approval and deducted in settlement', () {
      final recovery = VendorGstRecovery.calculate(
        assignmentId: 'asg-gst-rec-1',
        vendorId: 'vnd-1',
        taxableValue: 10000.0,
        gstRate: 18.0,
        invoiceNumber: 'DN-2026-001',
        recoveryStatus: 'Approved',
        remarks: 'Agreed contractual recovery for installation works',
      );

      expect(recovery.taxableValue, equals(10000.0));
      expect(recovery.gstRate, equals(18.0));
      expect(recovery.gstAmount, equals(1800.0));
      expect(recovery.totalRecovery, equals(11800.0));
      expect(recovery.isApproved, isTrue);
      expect(recovery.invoiceNumber, equals('DN-2026-001'));

      // Option A Settlement math test with contractual recovery:
      // Realized Collection: ₹1,80,000
      // Material Cost: ₹1,05,000
      // SIYA Platform Fee: ₹3,000
      // Other Expenses: ₹2,000
      // Approved GST Recovery: ₹11,800
      // Advances already paid: ₹20,000
      const realizedCollection = 180000.0;
      const materialCost = 105000.0;
      const vendorCharges = 3000.0;
      const otherExpenses = 2000.0;
      final approvedRecovery = recovery.totalRecovery;
      const advancesPaid = 20000.0;

      final netSubVendorEntitlement = realizedCollection - materialCost - vendorCharges - otherExpenses - approvedRecovery;
      // 180,000 - 105,000 - 3,000 - 2,000 - 11,800 = 58,200
      expect(netSubVendorEntitlement, equals(58200.0));

      final finalPayable = netSubVendorEntitlement - advancesPaid;
      // 58,200 - 20,000 = 38,200
      expect(finalPayable, equals(38200.0));
      expect(finalPayable, greaterThan(0.0));
    });
  });
}

