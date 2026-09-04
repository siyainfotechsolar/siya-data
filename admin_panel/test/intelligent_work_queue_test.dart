import 'package:flutter_test/flutter_test.dart';
import 'package:admin_panel/models/consumer_record.dart';
import 'package:admin_panel/services/workflow_engine.dart';
import 'package:admin_panel/services/report_service.dart';
import 'package:admin_panel/models/report_filter_options.dart';

void main() {
  group('Intelligent Customer Work Queue Tests (No Customer Age)', () {
    test('1. Application Days calculation from Submit Date', () {
      final now = DateTime.now();
      final subDate = now.subtract(const Duration(days: 20));

      final record = ConsumerRecord(
        consumerNo: '123456789012',
        name: 'Amit Patel',
        submitDate: subDate,
      );

      expect(record.applicationDays, equals(20));
    });

    test('2. Intelligent Action Required & Next Action derivation', () {
      // Agreement Missing -> Action Required = Agreement, Next Action = Upload Agreement
      final r1 = ConsumerRecord(
        consumerNo: '1001',
        name: 'Test 1',
        agreementStatus: 'Pending',
      );
      expect(r1.actionRequired, equals('Agreement'));
      expect(r1.nextAction, equals('Upload Agreement'));

      // Agreement completed, Loan Required YES, Loan pending -> Action Required = Loan, Next Action = Follow Up Loan
      final r2 = ConsumerRecord(
        consumerNo: '1002',
        name: 'Test 2',
        agreementStatus: 'Verified',
        loanRequired: 'Yes',
        loanStatus: 'Pending',
      );
      expect(r2.actionRequired, equals('Loan'));
      expect(r2.nextAction, equals('Follow Up Loan'));

      // Loan approved, Installation pending -> Action Required = Installation, Next Action = Schedule Installation
      final r3 = ConsumerRecord(
        consumerNo: '1003',
        name: 'Test 3',
        agreementStatus: 'Verified',
        loanRequired: 'Yes',
        loanStatus: 'Approved',
        installationStatus: 'Not Started',
      );
      expect(r3.actionRequired, equals('Installation'));
      expect(r3.nextAction, equals('Schedule Installation'));

      // Installation completed, RTS pending -> Action Required = RTS, Next Action = Process RTS
      final r4 = ConsumerRecord(
        consumerNo: '1004',
        name: 'Test 4',
        agreementStatus: 'Verified',
        installationStatus: 'Installation Completed',
        rtsStatus: 'Not Started',
      );
      expect(r4.actionRequired, equals('RTS'));
      expect(r4.nextAction, equals('Process RTS'));

      // RTS completed, Subsidy Request -> Action Required = Subsidy, Next Action = Process Subsidy
      final r5 = ConsumerRecord(
        consumerNo: '1005',
        name: 'Test 5',
        agreementStatus: 'Verified',
        installationStatus: 'Installation Completed',
        rtsStatus: 'Completed',
        subsidyStatus: 'Applied',
      );
      expect(r5.actionRequired, equals('Subsidy'));
      expect(r5.nextAction, equals('Process Subsidy'));

      // Subsidy Received -> Action Required = None, Next Action = None
      final r6 = ConsumerRecord(
        consumerNo: '1006',
        name: 'Test 6',
        agreementStatus: 'Verified',
        installationStatus: 'Installation Completed',
        rtsStatus: 'Completed',
        subsidyStatus: 'Received',
      );
      expect(r6.actionRequired, equals('None'));
      expect(r6.nextAction, equals('None'));
    });

    test('3. Days in Current Stage calculation', () {
      final now = DateTime.now();
      final tenDaysAgo = now.subtract(const Duration(days: 10));

      final record = ConsumerRecord(
        consumerNo: '2001',
        name: 'Stage Duration Test',
        agreementStatus: 'Verified',
        installationStatus: 'Installation Completed',
        rtsStatus: 'Completed',
        subsidyStatus: 'Applied',
        subsidyAppliedDate: tenDaysAgo,
      );

      expect(record.daysInCurrentStage, equals(10));
    });

    test('4. Subsidy Received = COMPLETED & Queue Removal', () {
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

    test('5. Priority Categories considering Stage Duration and Application Days', () {
      final now = DateTime.now();
      final oldSubmitDate = now.subtract(const Duration(days: 80));

      // Customer A: 80 Application Days + Installation Pending -> Critical Active Work
      final customerA = ConsumerRecord(
        consumerNo: 'A100',
        name: 'Customer A',
        submitDate: oldSubmitDate,
        agreementStatus: 'Verified',
        installationStatus: 'Not Started',
      );
      expect(customerA.priorityCategory, equals('Critical Active Work'));

      // Customer B: 80 Application Days + Subsidy Under Process -> Processing (NOT Critical Active Work)
      final customerB = ConsumerRecord(
        consumerNo: 'B200',
        name: 'Customer B',
        submitDate: oldSubmitDate,
        agreementStatus: 'Verified',
        installationStatus: 'Installation Completed',
        rtsStatus: 'Completed',
        subsidyStatus: 'Under Process',
      );
      expect(customerB.priorityCategory, equals('Processing'));

      // Customer C: 80 Application Days + Subsidy Received -> Completed
      final customerC = ConsumerRecord(
        consumerNo: 'C300',
        name: 'Customer C',
        submitDate: oldSubmitDate,
        agreementStatus: 'Verified',
        installationStatus: 'Installation Completed',
        rtsStatus: 'Completed',
        subsidyStatus: 'Received',
      );
      expect(customerC.priorityCategory, equals('Completed'));
    });

    test('6. ReportService active vs completed filter scope', () {
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
