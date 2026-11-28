import 'package:admin_panel/screens/sub_vendor_management_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:siya_shared/siya_shared.dart';

void main() {
  testWidgets('Financial Summaries tab renders without ParentDataWidget grey screen error across desktop & narrow viewports', (tester) async {
    final vendor = SubVendor(
      id: 'vnd-dhanshree',
      vendorCode: 'SIYA-VND',
      name: 'Dhanshree solar',
      mobile: '8600952048',
      email: 'dhanshree@vendor.siyasolar.com',
      defaultRatePerKw: 1000.0,
    );

    final assignments = [
      VendorSiteAssignment(
        id: 'asg-1',
        vendorId: vendor.id,
        customerId: 'cust-1',
        customerName: 'PANDURANG SHIRSAGAR',
        consumerNo: '097030010608',
        assignedDate: DateTime(2026, 11, 1),
        siteCapacityKw: 3.5,
        ratePerKw: 1000.0,
        vendorCharges: 3500.0,
        otherExpenses: 500.0,
        totalCustomerSiteAmount: 222222.0,
        loanSanctionedAmount: 200000.0,
        totalLoanCredited: 200000.0,
        totalCashReceived: 0.0,
        totalCustomerReceived: 200000.0,
        customerOutstanding: 0.0,
        paymentType: 'Bank Loan Customer',
      ),
    ];

    final extras = <String, Map<String, double>>{
      vendor.id: {
        'materialOutwardCost': 50000.0,
        'directVendorPayments': 10000.0,
        'directAdvancesGiven': 5000.0,
        'directAdvanceRefunds': 2000.0,
      },
    };

    for (final size in const [Size(1280, 900), Size(720, 800)]) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;

      await tester.pumpWidget(
        MaterialApp(
          home: SubVendorManagementScreen(
            initialTabIndex: 6,
            debugVendors: [vendor],
            debugAssignments: assignments,
            debugMaterials: const [],
            debugPayouts: const [],
            debugCustomerPayments: const [],
            debugGstRecoveries: const [],
            debugCentralExtras: extras,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Dhanshree solar'), findsOneWidget);
      expect(find.text('(SIYA-VND)'), findsOneWidget);
      expect(find.text('Settlement Calculator'), findsWidgets);
      expect(find.text('Export Statement'), findsOneWidget);
      expect(find.text('Bank Master Ledger'), findsOneWidget);
      expect(find.text('Sites'), findsOneWidget);
      expect(find.text('Capacity'), findsOneWidget);
      expect(find.text('Collection'), findsOneWidget);
      expect(find.text('Material Cost'), findsOneWidget);
      expect(find.text('Direct Paid'), findsOneWidget);
      expect(find.text('Adv. Refund'), findsOneWidget);
      expect(find.text('SIYA Fee'), findsOneWidget);
      expect(find.text('Expenses'), findsOneWidget);
      expect(find.text('Net GST'), findsOneWidget);
      expect(find.text('Paid / Adv'), findsOneWidget);
    }

    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}
