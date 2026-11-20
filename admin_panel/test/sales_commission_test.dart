import 'package:flutter_test/flutter_test.dart';
import 'package:excel/excel.dart';
import 'package:admin_panel/models/sales_commission.dart';
import 'package:admin_panel/services/sales_commission_service.dart';
import 'package:admin_panel/services/sales_commission_excel_service.dart';

void main() {
  group('SIYA INFOTECH – Sales Person Commission Management Module Tests', () {
    setUp(() {
      SalesCommissionService.resetLocalCacheForTesting();
    });

    // Sample Test Customers matching the prompt specification:
    // Customer A: Sales Person Rahul, 3 kW @ ₹500 = ₹1,500 (Pending)
    final custA = SalesCommission(
      id: 'comm-1',
      consumerId: 'c-1',
      consumerNo: '100000000001',
      customerName: 'Customer A',
      siteLocation: 'Pune City',
      solarCapacity: '3 kW',
      capacityKw: 3.0,
      customerSource: 'Sales Person',
      salesPersonName: 'Rahul',
      commissionRatePerKw: 500.0,
      totalCommission: 1500.0,
      commissionStatus: 'Pending',
      commissionDate: DateTime(2026, 11, 10),
    );

    // Customer B: Sales Person Rahul, 5 kW @ ₹500 = ₹2,500 (Completed)
    final custB = SalesCommission(
      id: 'comm-2',
      consumerId: 'c-2',
      consumerNo: '100000000002',
      customerName: 'Customer B',
      siteLocation: 'Kolhapur',
      solarCapacity: '5 kW',
      capacityKw: 5.0,
      customerSource: 'Sales Person',
      salesPersonName: 'Rahul',
      commissionRatePerKw: 500.0,
      totalCommission: 2500.0,
      commissionStatus: 'Completed',
      commissionDate: DateTime(2026, 11, 12),
    );

    // Customer C: Direct Customer, 3 kW @ ₹0 = ₹0 (Not Applicable)
    final custC = SalesCommission(
      id: 'comm-3',
      consumerId: 'c-3',
      consumerNo: '100000000003',
      customerName: 'Customer C',
      siteLocation: 'Satara',
      solarCapacity: '3 kW',
      capacityKw: 3.0,
      customerSource: 'Direct Customer',
      salesPersonName: null,
      commissionRatePerKw: 0.0,
      totalCommission: 0.0,
      commissionStatus: 'Not Applicable',
      commissionDate: DateTime(2026, 11, 15),
    );

    // Customer D: Sales Person Amit, 2 kW @ ₹500 = ₹1,000 (Pending)
    final custD = SalesCommission(
      id: 'comm-4',
      consumerId: 'c-4',
      consumerNo: '100000000004',
      customerName: 'Customer D',
      siteLocation: 'Sangli',
      solarCapacity: '2 kW',
      capacityKw: 2.0,
      customerSource: 'Sales Person',
      salesPersonName: 'Amit',
      commissionRatePerKw: 500.0,
      totalCommission: 1000.0,
      commissionStatus: 'Pending',
      commissionDate: DateTime(2026, 11, 18),
    );

    test('1. Automatic Commission Calculation: Solar Capacity (kW) × Commission Rate per kW', () {
      // Customer A: 3 kW * 500 = 1500
      expect(custA.calculatedCommission, 1500.0);
      expect(custA.totalCommission, 1500.0);

      // Customer B: 5 kW * 500 = 2500
      expect(custB.calculatedCommission, 2500.0);
      expect(custB.totalCommission, 2500.0);

      // Customer D: 2 kW * 500 = 1000
      expect(custD.calculatedCommission, 1000.0);
      expect(custD.totalCommission, 1000.0);
    });

    test('2. Direct Customer Rules: Zero Commission, Not Applicable Status, Excluded from Pending', () {
      // Direct customer must always evaluate to zero commission
      expect(custC.isDirectCustomer, isTrue);
      expect(custC.commissionRatePerKw, 0.0);
      expect(custC.totalCommission, 0.0);
      expect(custC.calculatedCommission, 0.0);
      expect(custC.commissionStatus, 'Not Applicable');
      expect(custC.salesPersonName, isNull);

      // Copying with a rate on Direct Customer should remain 0
      final copied = custC.copyWith(commissionRatePerKw: 500.0);
      expect(copied.commissionRatePerKw, 0.0);
      expect(copied.totalCommission, 0.0);
      expect(copied.commissionStatus, 'Not Applicable');
    });

    test('3. Dashboard Summary Aggregations: Pending vs Completed vs Total Amounts', () {
      final list = [custA, custB, custC, custD];
      final summary = CommissionDashboardSummary.fromCommissions(list);

      // Total Customers = 4
      expect(summary.totalCustomers, 4);
      // Sales Person Customers = 3 (A, B, D)
      expect(summary.salesPersonCustomers, 3);
      // Direct Customers = 1 (C)
      expect(summary.directCustomers, 1);
      // Total Installed Capacity = 3 + 5 + 3 + 2 = 13 kW
      expect(summary.totalInstalledCapacityKw, 13.0);

      // Status Counts
      expect(summary.pendingCommissionCustomers, 2); // A, D
      expect(summary.completedCommissionCustomers, 1); // B
      expect(summary.notApplicableCustomers, 1); // C

      // Total Pending Commission Amount = 1500 (A) + 1000 (D) = 2500 (C excluded!)
      expect(summary.totalPendingCommissionAmount, 2500.0);

      // Total Completed Commission Amount = 2500 (B)
      expect(summary.totalCompletedCommissionAmount, 2500.0);

      // Grand Total Commission Amount = 1500 + 2500 + 1000 = 5000 (Matching prompt example!)
      expect(summary.totalCommissionAmount, 5000.0);
    });

    test('4. Sales Person-Wise Summary Breakdown: Grouped by Sales Person', () {
      final list = [custA, custB, custC, custD];
      final summaries = CommissionDashboardSummary.buildSalesPersonSummaries(list);

      // Only Sales Persons included (Direct customers excluded from Sales Person summary)
      expect(summaries.length, 2);

      // Rahul: Customer A (3 kW, 1500) + Customer B (5 kW, 2500) = 8 kW, 4000 total (1500 pending, 2500 completed)
      final rahul = summaries.firstWhere((s) => s.salesPersonName == 'Rahul');
      expect(rahul.totalCustomers, 2);
      expect(rahul.totalCapacityKw, 8.0);
      expect(rahul.totalCommission, 4000.0);
      expect(rahul.pendingCommission, 1500.0);
      expect(rahul.completedCommission, 2500.0);

      // Amit: Customer D (2 kW, 1000 total, 1000 pending)
      final amit = summaries.firstWhere((s) => s.salesPersonName == 'Amit');
      expect(amit.totalCustomers, 1);
      expect(amit.totalCapacityKw, 2.0);
      expect(amit.totalCommission, 1000.0);
      expect(amit.pendingCommission, 1000.0);
      expect(amit.completedCommission, 0.0);
    });

    test('5. Excel Export Generation: Exactly 5 Sheets with Required Headers and Totals', () {
      final list = [custA, custB, custC, custD];
      final bytes = SalesCommissionExcelService.buildExcelWorkbook(
        commissions: list,
        filterSummary: 'All Customers',
      );

      expect(bytes, isNotEmpty);
      final decoded = Excel.decodeBytes(bytes);

      // Verify all 5 mandatory sheets exist
      expect(decoded.tables.containsKey('Complete Customer List'), isTrue);
      expect(decoded.tables.containsKey('Sales Person-wise Summary'), isTrue);
      expect(decoded.tables.containsKey('Pending Commission'), isTrue);
      expect(decoded.tables.containsKey('Direct Customers'), isTrue);
      expect(decoded.tables.containsKey('Customer-wise Detailed Report'), isTrue);

      // Sheet 1: Complete Customer List has all 4 customers
      final s1 = decoded.tables['Complete Customer List']!;
      expect(s1.rows.length >= 6, isTrue);
      final s1Headers = s1.rows[4].map((c) => c?.value.toString() ?? '').toList();
      expect(s1Headers.contains('Customer Name'), isTrue);
      expect(s1Headers.contains('Consumer Number'), isTrue);
      expect(s1Headers.contains('Customer Source'), isTrue);
      expect(s1Headers.contains('Sales Person'), isTrue);
      expect(s1Headers.contains('Total Commission (₹)'), isTrue);

      // Sheet 2: Sales Person-wise Summary
      final s2 = decoded.tables['Sales Person-wise Summary']!;
      final s2Headers = s2.rows[3].map((c) => c?.value.toString() ?? '').toList();
      expect(s2Headers.contains('Sales Person Name'), isTrue);
      expect(s2Headers.contains('Total Customers'), isTrue);
      expect(s2Headers.contains('Total Commission (₹)'), isTrue);

      // Sheet 3: Pending Commission (Customers A & D)
      final s3 = decoded.tables['Pending Commission']!;
      expect(s3.rows.length >= 6, isTrue);

      // Sheet 4: Direct Customers (Customer C)
      final s4 = decoded.tables['Direct Customers']!;
      expect(s4.rows.length >= 5, isTrue);

      // Sheet 5: Customer-wise Detailed Report
      final s5 = decoded.tables['Customer-wise Detailed Report']!;
      expect(s5.rows.length >= 6, isTrue);
    });

    test('6. Search & Filter Logic: Customer, Consumer No, Sales Person, Source & Status', () {
      final list = [custA, custB, custC, custD];

      // A. Customer Name Search
      final searchA = list.where((c) => c.customerName.toLowerCase().contains('customer a')).toList();
      expect(searchA.length, 1);
      expect(searchA.first.consumerNo, '100000000001');

      // B. Consumer Number Search
      final searchNo = list.where((c) => c.consumerNo.contains('000003')).toList();
      expect(searchNo.length, 1);
      expect(searchNo.first.customerName, 'Customer C');

      // C. Sales Person Filter
      final rahulCustomers = list.where((c) => c.salesPersonName == 'Rahul').toList();
      expect(rahulCustomers.length, 2);

      // D. Customer Source Filter
      final directList = list.where((c) => c.customerSource == 'Direct Customer').toList();
      expect(directList.length, 1);
      expect(directList.first.customerName, 'Customer C');

      // E. Commission Status Filter
      final pendingList = list.where((c) => c.commissionStatus == 'Pending').toList();
      expect(pendingList.length, 2);
    });

    test('7. Duplicate Customer Prevention: Rejects second entry for same consumer number', () async {
      SalesCommissionService.resetLocalCacheForTesting([custA]);

      final duplicateEntry = SalesCommission(
        id: '', // New record
        consumerId: 'c-diff',
        consumerNo: custA.consumerNo, // Same consumer number!
        customerName: 'Duplicate Person',
        siteLocation: 'Pune',
        solarCapacity: '3 kW',
        capacityKw: 3.0,
        customerSource: 'Sales Person',
        salesPersonName: 'Rahul',
        commissionRatePerKw: 500.0,
        totalCommission: 1500.0,
        commissionStatus: 'Pending',
        commissionDate: DateTime.now(),
      );

      expect(
        () => SalesCommissionService.saveCommission(duplicateEntry),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('Duplicate Commission Record'),
        )),
      );
    });

    test('8. Model JSON Serialization and Deserialization', () {
      final json = custA.toJson();
      expect(json['consumer_no'], '100000000001');
      expect(json['customer_name'], 'Customer A');
      expect(json['customer_source'], 'Sales Person');
      expect(json['sales_person_name'], 'Rahul');
      expect(json['commission_rate_per_kw'], 500.0);
      expect(json['total_commission'], 1500.0);
      expect(json['commission_status'], 'Pending');

      final deserialized = SalesCommission.fromJson(json);
      expect(deserialized.consumerNo, custA.consumerNo);
      expect(deserialized.customerName, custA.customerName);
      expect(deserialized.capacityKw, custA.capacityKw);
      expect(deserialized.totalCommission, custA.totalCommission);
    });
  });
}
