import 'package:flutter_test/flutter_test.dart';
import 'package:excel/excel.dart';
import 'package:admin_panel/models/site_team_expense.dart';
import 'package:admin_panel/models/consumer_record.dart';
import 'package:admin_panel/services/site_team_expense_service.dart';
import 'package:admin_panel/services/team_expense_excel_service.dart';

void main() {
  group('SIYA INFOTECH – Site-Wise Team Expense & Excel Report Module Tests', () {
    setUp(() {
      SiteTeamExpenseService.resetLocalCacheForTesting();
    });

    final sampleSite1 = SiteTeamExpense(
      id: 'exp-1',
      consumerId: 'c-101',
      consumerNo: '123456789012',
      customerName: 'Suresh Patil',
      siteLocation: 'Kolhapur, Shiroli',
      solarCapacity: '5 kW',
      expenseDate: DateTime(2026, 11, 15),
      wiringExpense: 12500.0,
      civilExpense: 8000.0,
      structureExpense: 16000.0,
      remarks: 'Elevated 10ft structure',
    );

    final sampleSite2 = SiteTeamExpense(
      id: 'exp-2',
      consumerId: 'c-102',
      consumerNo: '987654321098',
      customerName: 'Anil Deshmukh',
      siteLocation: 'Sangli, Kupwad',
      solarCapacity: '3 kW',
      expenseDate: DateTime(2026, 11, 18),
      wiringExpense: 9000.0,
      civilExpense: 5500.0,
      structureExpense: 11000.0,
      remarks: 'Standard tin shed site',
    );

    final sampleSite3 = SiteTeamExpense(
      id: 'exp-3',
      consumerId: 'c-103',
      consumerNo: '555666777888',
      customerName: 'Vijay Shinde',
      siteLocation: 'Satara, Karad',
      solarCapacity: '10 kW',
      expenseDate: DateTime(2026, 11, 20),
      wiringExpense: 24000.0,
      civilExpense: 15000.0,
      structureExpense: 32000.0,
      remarks: 'Ground mount industrial system',
    );

    test('1. Automatic Customer-wise Calculation: Total Site Expense = Wiring + Civil + Structure', () {
      expect(sampleSite1.totalSiteExpense, 12500.0 + 8000.0 + 16000.0);
      expect(sampleSite1.totalSiteExpense, 36500.0);

      expect(sampleSite2.totalSiteExpense, 9000.0 + 5500.0 + 11000.0);
      expect(sampleSite2.totalSiteExpense, 25500.0);

      expect(sampleSite3.totalSiteExpense, 24000.0 + 15000.0 + 32000.0);
      expect(sampleSite3.totalSiteExpense, 71000.0);
    });

    test('2. Automatic Team-wise Calculation: Wiring, Civil, Structure, and Grand Total', () {
      final list = [sampleSite1, sampleSite2, sampleSite3];
      final summary = TeamExpenseSummary.fromExpenses(list);

      expect(summary.totalSites, 3);
      // Wiring Total: 12500 + 9000 + 24000 = 45500
      expect(summary.totalWiringExpense, 45500.0);
      // Civil Total: 8000 + 5500 + 15000 = 28500
      expect(summary.totalCivilExpense, 28500.0);
      // Structure Total: 16000 + 11000 + 32000 = 59000
      expect(summary.totalStructureExpense, 59000.0);
      // Grand Total: 45500 + 28500 + 59000 = 133000
      expect(summary.grandTotalExpense, 133000.0);
      expect(summary.grandTotalExpense, summary.totalWiringExpense + summary.totalCivilExpense + summary.totalStructureExpense);

      expect(summary.wiringSitesCount, 3);
      expect(summary.civilSitesCount, 3);
      expect(summary.structureSitesCount, 3);
    });

    test('3. Model JSON Serialization and Deserialization integrity', () {
      final json = sampleSite1.toJson();
      expect(json['consumer_no'], '123456789012');
      expect(json['customer_name'], 'Suresh Patil');
      expect(json['wiring_expense'], 12500.0);
      expect(json['civil_expense'], 8000.0);
      expect(json['structure_expense'], 16000.0);
      expect(json['expense_date'], '2026-11-15');

      final deserialized = SiteTeamExpense.fromJson(json);
      expect(deserialized.consumerNo, sampleSite1.consumerNo);
      expect(deserialized.customerName, sampleSite1.customerName);
      expect(deserialized.wiringExpense, sampleSite1.wiringExpense);
      expect(deserialized.civilExpense, sampleSite1.civilExpense);
      expect(deserialized.structureExpense, sampleSite1.structureExpense);
      expect(deserialized.totalSiteExpense, 36500.0);
    });

    test('4. Excel Report Generation: Exactly 3 Sheets with Required Columns and Grand Totals', () {
      final list = [sampleSite1, sampleSite2, sampleSite3];
      final bytes = TeamExpenseExcelService.buildExcelWorkbook(
        expenses: list,
        filterSummary: 'Date: All | Team: All',
      );

      expect(bytes, isNotEmpty);

      // Decode the generated Excel file to verify sheets and rows
      final decoded = Excel.decodeBytes(bytes);

      // Verify all 3 mandatory sheets exist
      expect(decoded.tables.containsKey('Customer-wise Report'), isTrue);
      expect(decoded.tables.containsKey('Team-wise Summary'), isTrue);
      expect(decoded.tables.containsKey('Detailed Team Report'), isTrue);

      // --- SHEET 1: Customer-wise Report ---
      final s1 = decoded.tables['Customer-wise Report']!;
      // Row 4 has headers
      final s1HeaderValues = s1.rows[4].map((cell) => cell?.value.toString() ?? '').toList();
      expect(s1HeaderValues.contains('Sr. No.'), isTrue);
      expect(s1HeaderValues.contains('Customer Name'), isTrue);
      expect(s1HeaderValues.contains('Consumer Number'), isTrue);
      expect(s1HeaderValues.contains('Site Location'), isTrue);
      expect(s1HeaderValues.contains('Solar Capacity'), isTrue);
      expect(s1HeaderValues.contains('Wiring Expense (₹)'), isTrue);
      expect(s1HeaderValues.contains('Civil Expense (₹)'), isTrue);
      expect(s1HeaderValues.contains('Structure Expense (₹)'), isTrue);
      expect(s1HeaderValues.contains('Total Site Expense (₹)'), isTrue);
      expect(s1HeaderValues.contains('Expense Date'), isTrue);
      expect(s1HeaderValues.contains('Remarks'), isTrue);

      // Customer rows exist
      expect(s1.rows.length >= 8, isTrue); // banner + headers + 3 data rows + total row

      // --- SHEET 2: Team-wise Summary ---
      final s2 = decoded.tables['Team-wise Summary']!;
      final s2HeaderValues = s2.rows[3].map((cell) => cell?.value.toString() ?? '').toList();
      expect(s2HeaderValues.contains('Team Name'), isTrue);
      expect(s2HeaderValues.contains('Number of Sites'), isTrue);
      expect(s2HeaderValues.contains('Total Expense (₹)'), isTrue);

      // Rows for Wiring, Civil, Structure, and Grand Total
      final s2TeamNames = s2.rows.skip(4).map((r) => r[0]?.value.toString() ?? '').toList();
      expect(s2TeamNames.contains('Wiring Team'), isTrue);
      expect(s2TeamNames.contains('Civil Team'), isTrue);
      expect(s2TeamNames.contains('Structure Team'), isTrue);
      expect(s2TeamNames.contains('Grand Total'), isTrue);

      // --- SHEET 3: Detailed Team Report ---
      final s3 = decoded.tables['Detailed Team Report']!;
      final s3HeaderValues = s3.rows[3].map((cell) => cell?.value.toString() ?? '').toList();
      expect(s3HeaderValues.contains('Sr. No.'), isTrue);
      expect(s3HeaderValues.contains('Customer Name'), isTrue);
      expect(s3HeaderValues.contains('Consumer Number'), isTrue);
      expect(s3HeaderValues.contains('Team Name'), isTrue);
      expect(s3HeaderValues.contains('Team Expense (₹)'), isTrue);
      expect(s3HeaderValues.contains('Expense Date'), isTrue);
      expect(s3HeaderValues.contains('Remarks'), isTrue);

      // Each customer has 3 team entries (3 customers × 3 teams = 9 detail rows)
      final detailRows = s3.rows.skip(4).take(9).toList();
      expect(detailRows.length, 9);
    });

    test('5. Duplicate Prevention: Prevents adding another record for the same consumer/site', () async {
      await SiteTeamExpenseService.saveExpense(sampleSite1);

      // Attempt to save another entry with the SAME consumerNo
      final duplicateSite = SiteTeamExpense(
        id: '', // new id
        consumerId: 'c-diff',
        consumerNo: sampleSite1.consumerNo, // identical consumer number
        customerName: 'Duplicate Test',
        siteLocation: 'Kolhapur',
        solarCapacity: '4 kW',
        expenseDate: DateTime.now(),
        wiringExpense: 5000,
        civilExpense: 3000,
        structureExpense: 6000,
      );

      expect(
        () async => await SiteTeamExpenseService.saveExpense(duplicateSite),
        throwsA(isA<Exception>()),
      );
    });

    test('6. Filter Logic: Date-wise, Customer Name, Consumer No, and Team-wise filtering', () {
      final list = [sampleSite1, sampleSite2, sampleSite3];

      // A. Customer Name Search
      final nameFilter = list.where((e) => e.customerName.toLowerCase().contains('patil')).toList();
      expect(nameFilter.length, 1);
      expect(nameFilter.first.customerName, 'Suresh Patil');

      // B. Consumer Number Search
      final noFilter = list.where((e) => e.consumerNo.contains('987654')).toList();
      expect(noFilter.length, 1);
      expect(noFilter.first.customerName, 'Anil Deshmukh');

      // C. Date Filter (Between Nov 16 and Nov 21)
      final dateFilter = list.where((e) {
        return e.expenseDate.isAfter(DateTime(2026, 11, 16)) &&
            e.expenseDate.isBefore(DateTime(2026, 11, 21));
      }).toList();
      expect(dateFilter.length, 2); // Anil Deshmukh (Nov 18) and Vijay Shinde (Nov 20)

      // D. Team-wise filter (Wiring > 0)
      final zeroWiringSite = sampleSite1.copyWith(id: 'zero-w', consumerNo: '000000', wiringExpense: 0.0);
      final listWithZero = [...list, zeroWiringSite];
      final wiringOnly = listWithZero.where((e) => e.wiringExpense > 0).toList();
      expect(wiringOnly.length, 3);
      expect(wiringOnly.contains(zeroWiringSite), isFalse);
    });

    test('7. Pending Site Expense Tracking & 4-Sheet Excel Report with Pending Sites', () {
      final list = [sampleSite1, sampleSite2]; // 2 recorded

      // 4 master consumers, 2 are recorded and 2 are pending
      final masterConsumers = [
        ConsumerRecord(
          consumerNo: '123456789012',
          name: 'Suresh Patil',
          status: 'Active',
          deleted: false,
          isMerged: false,
          applicationStatus: 'Approved',
          agreementRequired: false,
          agreementStatus: 'Verified',
          loanRequired: 'No',
          loanStatus: 'Not Required',
          loanSubStage: '',
          loanAttempts: const [],
          loanReapplyCount: 0,
          installationStatus: 'Installation Completed',
          rtsStatus: 'Completed',
          subsidyStatus: 'Approved',
          customerWorkState: 'COMPLETED',
          hasActiveFollowup: false,
          totalAmount: 150000,
          paidAmount: 150000,
          pendingAmount: 0,
          additionalPaidAmount: 0,
          firstPaymentAmount: 0,
          secondPaymentAmount: 0,
        ),
        ConsumerRecord(
          consumerNo: '987654321098',
          name: 'Anil Deshmukh',
          status: 'Active',
          deleted: false,
          isMerged: false,
          applicationStatus: 'Approved',
          agreementRequired: false,
          agreementStatus: 'Verified',
          loanRequired: 'No',
          loanStatus: 'Not Required',
          loanSubStage: '',
          loanAttempts: const [],
          loanReapplyCount: 0,
          installationStatus: 'Installation Completed',
          rtsStatus: 'Completed',
          subsidyStatus: 'Approved',
          customerWorkState: 'COMPLETED',
          hasActiveFollowup: false,
          totalAmount: 200000,
          paidAmount: 200000,
          pendingAmount: 0,
          additionalPaidAmount: 0,
          firstPaymentAmount: 0,
          secondPaymentAmount: 0,
        ),
        ConsumerRecord(
          consumerNo: '555555555555',
          name: 'Ramesh Kadam (Pending)',
          status: 'Active',
          address: 'Karad, Satara',
          systemCapacity: '5 kW',
          deleted: false,
          isMerged: false,
          applicationStatus: 'Approved',
          agreementRequired: false,
          agreementStatus: 'Verified',
          loanRequired: 'No',
          loanStatus: 'Not Required',
          loanSubStage: '',
          loanAttempts: const [],
          loanReapplyCount: 0,
          installationStatus: 'Installation Completed',
          rtsStatus: 'Completed',
          subsidyStatus: 'Approved',
          customerWorkState: 'COMPLETED',
          hasActiveFollowup: false,
          totalAmount: 250000,
          paidAmount: 250000,
          pendingAmount: 0,
          additionalPaidAmount: 0,
          firstPaymentAmount: 0,
          secondPaymentAmount: 0,
        ),
        ConsumerRecord(
          consumerNo: '777777777777',
          name: 'Sunita More (Pending)',
          status: 'Active',
          address: 'Wai, Satara',
          systemCapacity: '3 kW',
          deleted: false,
          isMerged: false,
          applicationStatus: 'Approved',
          agreementRequired: false,
          agreementStatus: 'Verified',
          loanRequired: 'No',
          loanStatus: 'Not Required',
          loanSubStage: '',
          loanAttempts: const [],
          loanReapplyCount: 0,
          installationStatus: 'Installation Completed',
          rtsStatus: 'Completed',
          subsidyStatus: 'Approved',
          customerWorkState: 'COMPLETED',
          hasActiveFollowup: false,
          totalAmount: 180000,
          paidAmount: 180000,
          pendingAmount: 0,
          additionalPaidAmount: 0,
          firstPaymentAmount: 0,
          secondPaymentAmount: 0,
        ),
      ];

      // Verify pending identification logic
      final recordedNos = list.map((e) => e.consumerNo.trim().toLowerCase()).toSet();
      final pendingConsumers = masterConsumers
          .where((c) => !recordedNos.contains(c.consumerNo.trim().toLowerCase()))
          .toList();

      expect(pendingConsumers.length, 2);
      expect(pendingConsumers[0].name, 'Ramesh Kadam (Pending)');
      expect(pendingConsumers[1].name, 'Sunita More (Pending)');

      // Verify Summary with Master Count
      final summary = TeamExpenseSummary.fromExpenses(list, totalMasterCount: masterConsumers.length);
      expect(summary.totalSites, 2);
      expect(summary.totalMasterSites, 4);
      expect(summary.pendingSitesCount, 2);

      // Verify Excel generation with Sheet 4: Pending Expenses Sites
      final bytes = TeamExpenseExcelService.buildExcelWorkbook(
        expenses: list,
        pendingConsumers: pendingConsumers,
        filterSummary: 'All Sites',
      );

      final decoded = Excel.decodeBytes(bytes);
      expect(decoded.tables.containsKey('Customer-wise Report'), isTrue);
      expect(decoded.tables.containsKey('Team-wise Summary'), isTrue);
      expect(decoded.tables.containsKey('Detailed Team Report'), isTrue);
      expect(decoded.tables.containsKey('Pending Expenses Sites'), isTrue);

      final s4 = decoded.tables['Pending Expenses Sites']!;
      expect(s4.rows.length >= 6, isTrue);
      final s4Headers = s4.rows[3].map((cell) => cell?.value.toString() ?? '').toList();
      expect(s4Headers.contains('Customer Name'), isTrue);
      expect(s4Headers.contains('Consumer Number'), isTrue);
      expect(s4Headers.contains('Expense Status'), isTrue);
      expect(s4Headers.contains('Action Required'), isTrue);
    });
  });
}
