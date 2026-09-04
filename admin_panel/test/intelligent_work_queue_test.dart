import 'package:flutter_test/flutter_test.dart';
import 'package:admin_panel/models/consumer_record.dart';
import 'package:admin_panel/services/workflow_engine.dart';
import 'package:admin_panel/services/report_service.dart';
import 'package:admin_panel/models/report_filter_options.dart';

void main() {
  group('Intelligent Customer Work Queue Tests', () {
    test('1. Application Age vs Application Days separation', () {
      final now = DateTime.now();
      final appDate = now.subtract(const Duration(days: 66));
      final subDate = now.subtract(const Duration(days: 20));

      final record = ConsumerRecord(
        consumerNo: '123456789012',
        name: 'Amit Patel',
        applicationDate: appDate,
        submitDate: subDate,
      );

      expect(record.applicationAgeDays, equals(66));
      expect(record.applicationDays, equals(20));
    });

    test('2. Intelligent Action Required derivation', () {
      // Agreement Missing -> Action Required = Agreement
      final r1 = ConsumerRecord(
        consumerNo: '1001',
        name: 'Test 1',
        agreementStatus: 'Pending',
      );
      expect(r1.actionRequired, equals('Agreement'));

      // Agreement completed, Loan Required YES, Loan pending -> Action Required = Loan
      final r2 = ConsumerRecord(
        consumerNo: '1002',
        name: 'Test 2',
        agreementStatus: 'Verified',
        loanRequired: 'Yes',
        loanStatus: 'Pending',
      );
      expect(r2.actionRequired, equals('Loan'));

      // Loan approved, Installation pending -> Action Required = Installation
      final r3 = ConsumerRecord(
        consumerNo: '1003',
        name: 'Test 3',
        agreementStatus: 'Verified',
        loanRequired: 'Yes',
        loanStatus: 'Approved',
        installationStatus: 'Not Started',
      );
      expect(r3.actionRequired, equals('Installation'));

      // Installation completed, RTS pending -> Action Required = RTS
      final r4 = ConsumerRecord(
        consumerNo: '1004',
        name: 'Test 4',
        agreementStatus: 'Verified',
        installationStatus: 'Installation Completed',
        rtsStatus: 'Not Started',
      );
      expect(r4.actionRequired, equals('RTS'));

      // RTS completed, Subsidy Request -> Action Required = Subsidy
      final r5 = ConsumerRecord(
        consumerNo: '1005',
        name: 'Test 5',
        agreementStatus: 'Verified',
        installationStatus: 'Installation Completed',
        rtsStatus: 'Completed',
        subsidyStatus: 'Applied',
      );
      expect(r5.actionRequired, equals('Subsidy'));

      // Subsidy Received -> Action Required = None
      final r6 = ConsumerRecord(
        consumerNo: '1006',
        name: 'Test 6',
        agreementStatus: 'Verified',
        installationStatus: 'Installation Completed',
        rtsStatus: 'Completed',
        subsidyStatus: 'Received',
      );
      expect(r6.actionRequired, equals('None'));
    });

    test('3. Subsidy Received = COMPLETED & Queue Removal', () {
      final record = ConsumerRecord(
        consumerNo: '9999',
        name: 'Completed Customer',
        subsidyStatus: 'Received',
      );

      expect(WorkflowEngine.isWorkCompleted(record), isTrue);
      expect(WorkflowEngine.getCurrentWorkStage(record), equals('Completed'));
      expect(WorkflowEngine.getCurrentWorkStatus(record), equals('Completed'));
      expect(record.isActiveWork, isFalse);
    });

    test('4. Priority Categories do not rely on Application Age alone', () {
      final now = DateTime.now();
      final oldAppDate = now.subtract(const Duration(days: 90));

      // Customer A: 90 Days Old + Installation Pending -> High/Critical Active Work
      final customerA = ConsumerRecord(
        consumerNo: 'A100',
        name: 'Customer A',
        applicationDate: oldAppDate,
        submitDate: oldAppDate,
        agreementStatus: 'Verified',
        installationStatus: 'Not Started',
      );
      expect(customerA.priorityCategory, equals('Critical Active Work'));

      // Customer B: 90 Days Old + Subsidy Under Process -> Processing (NOT Critical)
      final customerB = ConsumerRecord(
        consumerNo: 'B200',
        name: 'Customer B',
        applicationDate: oldAppDate,
        submitDate: oldAppDate,
        agreementStatus: 'Verified',
        installationStatus: 'Installation Completed',
        rtsStatus: 'Completed',
        subsidyStatus: 'Under Process',
      );
      expect(customerB.priorityCategory, equals('Processing'));

      // Customer C: 90 Days Old + Subsidy Received -> Completed
      final customerC = ConsumerRecord(
        consumerNo: 'C300',
        name: 'Customer C',
        applicationDate: oldAppDate,
        submitDate: oldAppDate,
        agreementStatus: 'Verified',
        installationStatus: 'Installation Completed',
        rtsStatus: 'Completed',
        subsidyStatus: 'Received',
      );
      expect(customerC.priorityCategory, equals('Completed'));
    });

    test('5. ReportService active vs completed filter scope', () {
      final now = DateTime.now();
      final records = [
        ConsumerRecord(
          consumerNo: '1',
          name: 'Active Customer',
          agreementStatus: 'Pending',
        ),
        ConsumerRecord(
          consumerNo: '2',
          name: 'Completed Customer',
          subsidyStatus: 'Received',
        ),
      ];

      final activeOnly = ReportService.applyFilters(
        records,
        const ReportFilterOptions(customerScope: 'Active'),
      );
      expect(activeOnly.length, equals(1));
      expect(activeOnly.first.consumerNo, equals('1'));

      final completedOnly = ReportService.applyFilters(
        records,
        const ReportFilterOptions(customerScope: 'Completed'),
      );
      expect(completedOnly.length, equals(1));
      expect(completedOnly.first.consumerNo, equals('2'));

      final allRecords = ReportService.applyFilters(
        records,
        const ReportFilterOptions(customerScope: 'All'),
      );
      expect(allRecords.length, equals(2));
    });
  });
}
