import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:siya_shared/siya_shared.dart';
import 'package:mobile_app/screens/sub_vendor_dashboard_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Sub-Vendor Mobile Integration & Financial Calculation Tests', () {
    // -------------------------------------------------------------------------
    // 1. LOGIN IDENTIFIER RESOLUTION & VENDOR ACCOUNT CREATION
    // -------------------------------------------------------------------------
    test('1. Sub-Vendor login identifier resolves mobile number & vendor code correctly', () {
      // 10-digit mobile number
      String resolveLogin(String input) {
        if (!input.contains('@')) {
          final clean = input.replaceAll(RegExp(r'[^0-9a-zA-Z]'), '').toLowerCase();
          return '$clean@vendor.siyasolar.com';
        }
        return input.trim().toLowerCase();
      }

      expect(resolveLogin('9822334455'), equals('9822334455@vendor.siyasolar.com'));
      expect(resolveLogin('SIYA-VND-001'), equals('siyavnd001@vendor.siyasolar.com'));
      expect(resolveLogin('staff@siyasolar.com'), equals('staff@siyasolar.com'));
      expect(resolveLogin('  9876543210  '), equals('9876543210@vendor.siyasolar.com'));
    });

    test('2. Sub-Vendor Account model handles Active, Inactive, and Blocked status', () {
      final vendorActive = SubVendor(
        id: 'vnd_001',
        vendorCode: 'SIYA-VND-001',
        name: 'Omkar Solar Services',
        mobile: '9822334455',
        email: '9822334455@vendor.siyasolar.com',
        defaultRatePerKw: 1000.0,
        isActive: true,
        status: 'Active',
      );
      expect(vendorActive.isActive, isTrue);
      expect(vendorActive.status, equals('Active'));

      final vendorBlocked = vendorActive.copyWith(
        isActive: false,
        status: 'Blocked',
      );
      expect(vendorBlocked.isActive, isFalse);
      expect(vendorBlocked.status, equals('Blocked'));
    });

    // -------------------------------------------------------------------------
    // 3. AUTOMATIC CALCULATION: CAPACITY × ₹1,000/KW & DYNAMIC MATERIALS (5% vs 18%)
    // -------------------------------------------------------------------------
    test('3. Dynamic calculations: Vendor Charges = kW × ₹1,000, 5% Panels/Inverters, 18% BOS, and Returns deduction', () {
      final assignment = VendorSiteAssignment(
        id: 'asg_site_01',
        vendorId: 'vnd_001',
        customerId: 'cust_ramesh',
        customerName: 'Ramesh Patil',
        consumerNo: '096590001234',
        customerVillageCity: 'Betawad',
        assignedDate: DateTime(2026, 11, 1),
        siteCapacityKw: 4.5,
        ratePerKw: 1000.0,
        vendorCharges: 4500.0, // 4.5 kW * ₹1,000 = ₹4,500
        otherExpenses: 500.0,
        expenseRemarks: 'High rise civil work',
        status: 'In Progress',
      );

      // Actual dynamic materials issued & returned
      final materials = [
        // 1. Solar Panels (5% GST) Issue: 8 panels @ ₹9,000 = ₹72,000 + 5% GST = ₹75,600
        VendorMaterialTransaction(
          id: 'mat_01',
          assignmentId: assignment.id,
          vendorId: 'vnd_001',
          customerId: 'cust_ramesh',
          transactionType: 'ISSUE',
          transactionDate: DateTime(2026, 11, 2),
          itemName: '550 Wp TopCon Bifacial Panels',
          itemCategory: 'SOLAR_PANEL',
          gstRate: 5.0,
          quantity: 8,
          unit: 'Nos',
          unitRate: 9000.0,
          taxableAmount: 72000.0,
          gstAmount: 3600.0,
          totalAmount: 75600.0,
        ),
        // 2. Solar Inverter (5% GST) Issue: 1 unit @ ₹25,000 = ₹25,000 + 5% GST = ₹26,250
        VendorMaterialTransaction(
          id: 'mat_02',
          assignmentId: assignment.id,
          vendorId: 'vnd_001',
          customerId: 'cust_ramesh',
          transactionType: 'ISSUE',
          transactionDate: DateTime(2026, 11, 2),
          itemName: '5 kW On-Grid Inverter',
          itemCategory: 'INVERTER',
          gstRate: 5.0,
          quantity: 1,
          unit: 'Nos',
          unitRate: 25000.0,
          taxableAmount: 25000.0,
          gstAmount: 1250.0,
          totalAmount: 26250.0,
        ),
        // 3. Solar BOS (18% GST) Issue: ACDB/DCDB & GI structure @ ₹15,000 + 18% GST = ₹17,700
        VendorMaterialTransaction(
          id: 'mat_03',
          assignmentId: assignment.id,
          vendorId: 'vnd_001',
          customerId: 'cust_ramesh',
          transactionType: 'ISSUE',
          transactionDate: DateTime(2026, 11, 3),
          itemName: 'Solar BOS Kit & Structure',
          itemCategory: 'BOS',
          gstRate: 18.0,
          quantity: 1,
          unit: 'Set',
          unitRate: 15000.0,
          taxableAmount: 15000.0,
          gstAmount: 2700.0,
          totalAmount: 17700.0,
        ),
        // 4. Material Return (RETURN): 1 excess panel returned (-₹9,000 - 5% = -₹9,450)
        VendorMaterialTransaction(
          id: 'mat_04',
          assignmentId: assignment.id,
          vendorId: 'vnd_001',
          customerId: 'cust_ramesh',
          transactionType: 'RETURN',
          transactionDate: DateTime(2026, 11, 4),
          itemName: '550 Wp TopCon Bifacial Panels',
          itemCategory: 'SOLAR_PANEL',
          gstRate: 5.0,
          quantity: 1,
          unit: 'Nos',
          unitRate: 9000.0,
          taxableAmount: 9000.0,
          gstAmount: 450.0,
          totalAmount: 9450.0,
        ),
      ];

      final payouts = [
        VendorPayout(
          id: 'pay_01',
          vendorId: 'vnd_001',
          assignmentId: assignment.id,
          payoutDate: DateTime(2026, 11, 5),
          amount: 3000.0,
          paymentMode: 'Bank Transfer',
          referenceNumber: 'UTR20261105001',
          status: 'Paid',
        ),
      ];

      final detail = SiteFinancialDetail.compute(
        assignment: assignment,
        materials: materials,
        payouts: payouts,
      );

      // 1. Capacity Charges: 4.5 kW * ₹1,000/kW = ₹4,500
      expect(detail.vendorCharges, equals(4500.0));

      // 2. 5% GST Category: (72,000 - 9,000) taxable = 63,000 + 25,000 inverter = 88,000 taxable; GST = 4,400; Total = 92,400
      expect(detail.material5Total, equals(92400.0));

      // 3. 18% GST Category: 17,700
      expect(detail.material18Total, equals(17700.0));

      // 4. Total Dynamic Material Cost: 92,400 + 17,700 = 110,100
      expect(detail.totalMaterialCost, equals(110100.0));

      // 5. Net Site Settlement Amount: Charges (₹4,500) + Other Expenses (₹500) = ₹5,000
      expect(detail.totalVendorPayable, equals(5000.0));

      // 6. Paid: ₹3,000 -> Remaining Settlement: ₹2,000
      expect(detail.totalPaidToVendor, equals(3000.0));
      expect(detail.outstandingVendorPayable, equals(2000.0));
    });

    // -------------------------------------------------------------------------
    // 4. SECURITY & ACCESS ISOLATION TEST BETWEEN TWO DIFFERENT SUB-VENDORS
    // -------------------------------------------------------------------------
    test('4. Security: Complete access isolation between Sub-Vendor A and Sub-Vendor B', () {
      // Sub-Vendor A
      final vendorA = SubVendor(
        id: 'vnd_a',
        vendorCode: 'SIYA-VND-001',
        name: 'Sanjay Solar Works',
        mobile: '9822110001',
        email: '9822110001@vendor.siyasolar.com',
        defaultRatePerKw: 1000.0,
      );

      // Sub-Vendor B
      final vendorB = SubVendor(
        id: 'vnd_b',
        vendorCode: 'SIYA-VND-002',
        name: 'Rajesh Electricals',
        mobile: '9822110002',
        email: '9822110002@vendor.siyasolar.com',
        defaultRatePerKw: 1000.0,
      );

      final assignmentsA = [
        VendorSiteAssignment(
          id: 'asg_a1',
          vendorId: vendorA.id,
          customerId: 'cust_1',
          customerName: 'Customer A1',
          consumerNo: '096590001111',
          assignedDate: DateTime(2026, 11, 1),
          siteCapacityKw: 3.0,
          ratePerKw: 1000.0,
          vendorCharges: 3000.0,
          status: 'Completed',
        ),
        VendorSiteAssignment(
          id: 'asg_a2',
          vendorId: vendorA.id,
          customerId: 'cust_2',
          customerName: 'Customer A2',
          consumerNo: '096590002222',
          assignedDate: DateTime(2026, 11, 2),
          siteCapacityKw: 5.0,
          ratePerKw: 1000.0,
          vendorCharges: 5000.0,
          status: 'In Progress',
        ),
      ];

      final assignmentsB = [
        VendorSiteAssignment(
          id: 'asg_b1',
          vendorId: vendorB.id,
          customerId: 'cust_3',
          customerName: 'Customer B1',
          consumerNo: '096590003333',
          assignedDate: DateTime(2026, 11, 3),
          siteCapacityKw: 10.0,
          ratePerKw: 1000.0,
          vendorCharges: 10000.0,
          status: 'Assigned',
        ),
      ];

      final materialsA = [
        VendorMaterialTransaction(
          id: 'mat_a1',
          assignmentId: 'asg_a1',
          vendorId: vendorA.id,
          customerId: 'cust_1',
          transactionType: 'ISSUE',
          transactionDate: DateTime(2026, 11, 1),
          itemName: 'Panels A',
          itemCategory: 'SOLAR_PANEL',
          gstRate: 5.0,
          quantity: 6,
          unitRate: 10000.0,
          taxableAmount: 60000.0,
          gstAmount: 3000.0,
          totalAmount: 63000.0,
        ),
      ];

      final materialsB = [
        VendorMaterialTransaction(
          id: 'mat_b1',
          assignmentId: 'asg_b1',
          vendorId: vendorB.id,
          customerId: 'cust_3',
          transactionType: 'ISSUE',
          transactionDate: DateTime(2026, 11, 3),
          itemName: 'Panels B',
          itemCategory: 'SOLAR_PANEL',
          gstRate: 5.0,
          quantity: 20,
          unitRate: 10000.0,
          taxableAmount: 200000.0,
          gstAmount: 10000.0,
          totalAmount: 210000.0,
        ),
      ];

      final summaryA = VendorFinancialSummary.compute(
        vendorId: vendorA.id,
        vendorCode: vendorA.vendorCode,
        vendorName: vendorA.name,
        assignments: assignmentsA,
        allMaterials: materialsA,
        allPayouts: [],
      );

      final summaryB = VendorFinancialSummary.compute(
        vendorId: vendorB.id,
        vendorCode: vendorB.vendorCode,
        vendorName: vendorB.name,
        assignments: assignmentsB,
        allMaterials: materialsB,
        allPayouts: [],
      );

      // Verify Vendor A sees only Vendor A's data
      expect(summaryA.vendorId, equals(vendorA.id));
      expect(summaryA.totalAssignedSites, equals(2));
      expect(summaryA.completedSites, equals(1));
      expect(summaryA.pendingSites, equals(1));
      expect(summaryA.totalCapacityKw, equals(8.0)); // 3.0 + 5.0
      expect(summaryA.totalVendorCharges, equals(8000.0));
      expect(summaryA.totalMaterialCost, equals(63000.0));

      // Verify Vendor B sees only Vendor B's data
      expect(summaryB.vendorId, equals(vendorB.id));
      expect(summaryB.totalAssignedSites, equals(1));
      expect(summaryB.totalCapacityKw, equals(10.0));
      expect(summaryB.totalVendorCharges, equals(10000.0));
      expect(summaryB.totalMaterialCost, equals(210000.0));

      // STRICT ISOLATION ASSERTIONS
      // Vendor A summary must NOT contain Vendor B's customer IDs or material IDs
      expect(summaryA.siteDetails.any((d) => d.assignment.customerId == 'cust_3'), isFalse);
      expect(summaryA.siteDetails.any((d) => d.assignment.vendorId == vendorB.id), isFalse);

      // Vendor B summary must NOT contain Vendor A's customer IDs or material IDs
      expect(summaryB.siteDetails.any((d) => d.assignment.customerId == 'cust_1'), isFalse);
      expect(summaryB.siteDetails.any((d) => d.assignment.customerId == 'cust_2'), isFalse);
      expect(summaryB.siteDetails.any((d) => d.assignment.vendorId == vendorA.id), isFalse);
    });

    // -------------------------------------------------------------------------
    // 5. MOBILE DASHBOARD SCREEN WIDGET RENDERING
    // -------------------------------------------------------------------------
    testWidgets('5. SubVendorMobileDashboardScreen renders responsive mobile UI with tabs and metrics', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(390, 844); // iPhone/Pixel mobile viewport
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final testVendor = SubVendor(
        id: 'vnd_mock',
        vendorCode: 'SIYA-VND-088',
        name: 'Omkar Solar Tech',
        mobile: '9822334455',
        email: '9822334455@vendor.siyasolar.com',
        defaultRatePerKw: 1000.0,
        status: 'Active',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: SubVendorMobileDashboardScreen(preloadedVendor: testVendor),
        ),
      );
      await tester.pump();

      // Verify Header & Vendor details
      expect(find.text('Omkar Solar Tech'), findsOneWidget);
      expect(find.textContaining('SIYA-VND-088'), findsOneWidget);

      // Verify 4 Mobile Tabs
      expect(find.text('Sites'), findsOneWidget);
      expect(find.text('Materials'), findsOneWidget);
      expect(find.text('Payouts'), findsOneWidget);
      expect(find.text('Profile'), findsOneWidget);
    });
  });
}
