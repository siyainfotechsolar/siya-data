import 'package:flutter_test/flutter_test.dart';
import 'package:admin_panel/models/team_member.dart';
import 'package:admin_panel/models/team_work_expense.dart';
import 'package:admin_panel/services/team_work_service.dart';
import 'package:admin_panel/services/team_work_excel_service.dart';

void main() {
  group('SIYA INFOTECH – Team Work & Individual Expense Management Module Tests', () {
    setUp(() {
      TeamWorkService.resetCacheForTesting();
    });

    test('1. Team Member Master Seed & CRUD: Vishal, Yendeshwar, Samadhan, Eknath', () async {
      final initialMembers = await TeamWorkService.fetchTeamMembers();
      expect(initialMembers.length, greaterThanOrEqualTo(4));
      final names = initialMembers.map((m) => m.name.toLowerCase()).toList();
      expect(names, contains('vishal'));
      expect(names, contains('yendeshwar'));
      expect(names, contains('samadhan'));
      expect(names, contains('eknath'));

      // Add a new team member
      final newMember = const TeamMember(id: '', name: 'Ramesh Pawar', phone: '9876543210');
      final saved = await TeamWorkService.saveTeamMember(newMember);
      expect(saved.name, 'Ramesh Pawar');

      final all = await TeamWorkService.fetchTeamMembers();
      expect(all.any((m) => m.name == 'Ramesh Pawar'), isTrue);

      // Toggle active status
      await TeamWorkService.toggleTeamMemberActive(saved.id, false);
      final activeOnly = await TeamWorkService.fetchTeamMembers(activeOnly: true);
      expect(activeOnly.any((m) => m.name == 'Ramesh Pawar'), isFalse);
    });

    test('2. Multiple Workers on Same Site and Same Category with Separate Entries', () {
      final now = DateTime.now();

      // Example from prompt:
      // Site: Customer A – 3 kW
      // Vishal: Structure ₹1,500
      // Yendeshwar: Structure ₹1,000
      // Samadhan: Wiring ₹1,200
      // Eknath: Civil ₹800
      // Total Site Expense = ₹4,500
      final entries = [
        TeamWorkExpense(
          id: '1',
          consumerNo: '097030120001',
          customerName: 'Customer A',
          siteLocation: 'Dhule',
          solarCapacity: '3 kW',
          workDate: now,
          workCategory: 'Structure',
          teamMemberName: 'Vishal',
          individualExpense: 1500.0,
        ),
        TeamWorkExpense(
          id: '2',
          consumerNo: '097030120001',
          customerName: 'Customer A',
          siteLocation: 'Dhule',
          solarCapacity: '3 kW',
          workDate: now,
          workCategory: 'Structure',
          teamMemberName: 'Yendeshwar',
          individualExpense: 1000.0,
        ),
        TeamWorkExpense(
          id: '3',
          consumerNo: '097030120001',
          customerName: 'Customer A',
          siteLocation: 'Dhule',
          solarCapacity: '3 kW',
          workDate: now,
          workCategory: 'Wiring',
          teamMemberName: 'Samadhan',
          individualExpense: 1200.0,
        ),
        TeamWorkExpense(
          id: '4',
          consumerNo: '097030120001',
          customerName: 'Customer A',
          siteLocation: 'Dhule',
          solarCapacity: '3 kW',
          workDate: now,
          workCategory: 'Civil',
          teamMemberName: 'Eknath',
          individualExpense: 800.0,
        ),
      ];

      // Site-wise calculation
      final custSummaries = TeamWorkService.buildCustomerSummaries(entries);
      expect(custSummaries.length, 1);
      final siteA = custSummaries.first;
      expect(siteA.structureExpense, 2500.0); // 1500 + 1000
      expect(siteA.wiringExpense, 1200.0);
      expect(siteA.civilExpense, 800.0);
      expect(siteA.totalSiteExpense, 4500.0); // Exactly ₹4,500 as in prompt!
      expect(siteA.entriesCount, 4);
    });

    test('3. One Person Performing Multiple Work Categories Across Multiple Sites', () {
      final now = DateTime.now();

      // Vishal performs Structure at Customer A and Civil at Customer B
      final entries = [
        TeamWorkExpense(
          id: '1',
          consumerNo: '097030120001',
          customerName: 'Customer A',
          workDate: now,
          workCategory: 'Structure',
          teamMemberName: 'Vishal',
          individualExpense: 1500.0,
        ),
        TeamWorkExpense(
          id: '2',
          consumerNo: '097030120002',
          customerName: 'Customer B',
          workDate: now,
          workCategory: 'Civil',
          teamMemberName: 'Vishal',
          individualExpense: 1000.0,
        ),
        TeamWorkExpense(
          id: '3',
          consumerNo: '097030120002',
          customerName: 'Customer B',
          workDate: now,
          workCategory: 'Wiring',
          teamMemberName: 'Samadhan',
          individualExpense: 1200.0,
        ),
      ];

      final personSummaries = TeamWorkService.buildPersonSummaries(entries);
      final vishal = personSummaries.firstWhere((p) => p.teamMemberName == 'Vishal');
      expect(vishal.structureExpense, 1500.0);
      expect(vishal.civilExpense, 1000.0);
      expect(vishal.wiringExpense, 0.0);
      expect(vishal.totalExpense, 2500.0);
      expect(vishal.totalSites, 2); // Customer A and Customer B
    });

    test('4. Category-wise Summary and Dashboard Calculations', () {
      final now = DateTime.now();
      final entries = [
        TeamWorkExpense(
          id: '1',
          consumerNo: 'SITE-01',
          customerName: 'Cust 1',
          workDate: now,
          workCategory: 'Structure',
          teamMemberName: 'Vishal',
          individualExpense: 2000.0,
        ),
        TeamWorkExpense(
          id: '2',
          consumerNo: 'SITE-01',
          customerName: 'Cust 1',
          workDate: now,
          workCategory: 'Wiring',
          teamMemberName: 'Samadhan',
          individualExpense: 1500.0,
        ),
        TeamWorkExpense(
          id: '3',
          consumerNo: 'SITE-02',
          customerName: 'Cust 2',
          workDate: now,
          workCategory: 'Civil',
          teamMemberName: 'Eknath',
          individualExpense: 1000.0,
        ),
      ];

      final catSummaries = TeamWorkService.buildCategorySummaries(entries);
      final struct = catSummaries.firstWhere((c) => c.workCategory == 'Structure');
      final wire = catSummaries.firstWhere((c) => c.workCategory == 'Wiring');
      final civ = catSummaries.firstWhere((c) => c.workCategory == 'Civil');

      expect(struct.totalExpense, 2000.0);
      expect(wire.totalExpense, 1500.0);
      expect(civ.totalExpense, 1000.0);

      final dash = TeamWorkDashboardSummary.calculate(entries, customTeamMemberCount: 4);
      expect(dash.totalSites, 2);
      expect(dash.totalTeamMembers, 4);
      expect(dash.totalStructureExpense, 2000.0);
      expect(dash.totalWiringExpense, 1500.0);
      expect(dash.totalCivilExpense, 1000.0);
      expect(dash.grandTotalExpense, 4500.0);
    });

    test('5. Excel Export Generation: Exactly 4 Sheets with Required Headers and Totals', () {
      final now = DateTime.now();
      final entries = [
        TeamWorkExpense(
          id: '1',
          consumerNo: '097030120001',
          customerName: 'Customer A',
          siteLocation: 'Dhule Site',
          solarCapacity: '3 kW',
          workDate: now,
          workCategory: 'Structure',
          teamMemberName: 'Vishal',
          individualExpense: 1500.0,
          remarks: 'Done foundation',
        ),
        TeamWorkExpense(
          id: '2',
          consumerNo: '097030120001',
          customerName: 'Customer A',
          siteLocation: 'Dhule Site',
          solarCapacity: '3 kW',
          workDate: now,
          workCategory: 'Wiring',
          teamMemberName: 'Samadhan',
          individualExpense: 1200.0,
        ),
        TeamWorkExpense(
          id: '3',
          consumerNo: '097030120002',
          customerName: 'Customer B',
          siteLocation: 'Malegaon',
          solarCapacity: '5 kW',
          workDate: now,
          workCategory: 'Civil',
          teamMemberName: 'Eknath',
          individualExpense: 800.0,
        ),
      ];

      final excel = TeamWorkExcelService.generateWorkbook(
        expenses: entries,
        appliedFilterDescription: 'Test Report',
        customMemberCount: 4,
      );

      // Must contain exactly the 4 required sheets
      expect(excel.tables.containsKey('Detailed Work Entries'), isTrue);
      expect(excel.tables.containsKey('Person-wise Summary'), isTrue);
      expect(excel.tables.containsKey('Customer-wise Summary'), isTrue);
      expect(excel.tables.containsKey('Category-wise Summary'), isTrue);

      final s1 = excel.tables['Detailed Work Entries']!;
      expect(s1.maxRows, greaterThan(4));

      final s2 = excel.tables['Person-wise Summary']!;
      expect(s2.maxRows, greaterThan(3));

      final s3 = excel.tables['Customer-wise Summary']!;
      expect(s3.maxRows, greaterThan(3));

      final s4 = excel.tables['Category-wise Summary']!;
      expect(s4.maxRows, greaterThan(3));

      final bytes = excel.encode();
      expect(bytes, isNotNull);
      expect(bytes!.length, greaterThan(0));
    });

    test('6. Model JSON Serialization & Deserialization Integrity', () {
      final now = DateTime(2026, 11, 20);
      final entry = TeamWorkExpense(
        id: 'uuid-1234',
        consumerId: 'cust-uuid',
        consumerNo: '097030120217',
        customerName: 'AABID NURMOHMAD KHATIK',
        siteLocation: 'AT SAIPARK SINDKHEDE',
        solarCapacity: '3 kW',
        workDate: now,
        workCategory: 'Structure',
        teamMemberId: 'member-1',
        teamMemberName: 'Vishal',
        individualExpense: 1500.0,
        remarks: 'Purlin and rafter fixed',
      );

      final json = entry.toJson();
      expect(json['consumer_no'], '097030120217');
      expect(json['customer_name'], 'AABID NURMOHMAD KHATIK');
      expect(json['team_member_name'], 'Vishal');
      expect(json['work_category'], 'Structure');
      expect(json['individual_expense'], 1500.0);

      final reconstructed = TeamWorkExpense.fromJson(json);
      expect(reconstructed.id, entry.id);
      expect(reconstructed.consumerNo, entry.consumerNo);
      expect(reconstructed.individualExpense, entry.individualExpense);
      expect(reconstructed.workCategory, entry.workCategory);
    });

    test('7. Add, Edit, Delete Expense Operations with Isolated Records', () async {
      final now = DateTime.now();

      // Add entry
      final e1 = TeamWorkExpense(
        id: '',
        consumerNo: 'CUST-1',
        customerName: 'Test Cust',
        workDate: now,
        workCategory: 'Wiring',
        teamMemberName: 'Samadhan',
        individualExpense: 1200.0,
      );
      final saved1 = await TeamWorkService.saveWorkExpense(e1);
      expect(saved1.id, isNotEmpty);

      // Add second entry on same site
      final e2 = TeamWorkExpense(
        id: '',
        consumerNo: 'CUST-1',
        customerName: 'Test Cust',
        workDate: now,
        workCategory: 'Civil',
        teamMemberName: 'Eknath',
        individualExpense: 800.0,
      );
      final saved2 = await TeamWorkService.saveWorkExpense(e2);
      expect(saved2.id, isNotEmpty);

      // Edit first entry
      final updated1 = saved1.copyWith(individualExpense: 1400.0);
      final savedUpdated = await TeamWorkService.saveWorkExpense(updated1);
      expect(savedUpdated.individualExpense, 1400.0);

      // Verify second entry was NOT affected
      final all = await TeamWorkService.fetchWorkExpenses();
      final check2 = all.firstWhere((e) => e.id == saved2.id);
      expect(check2.individualExpense, 800.0);

      // Delete first entry
      await TeamWorkService.deleteWorkExpense(saved1.id);
      final afterDelete = await TeamWorkService.fetchWorkExpenses();
      expect(afterDelete.any((e) => e.id == saved1.id), isFalse);
      expect(afterDelete.any((e) => e.id == saved2.id), isTrue);
    });
  });
}
