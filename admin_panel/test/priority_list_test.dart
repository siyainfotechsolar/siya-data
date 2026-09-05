import 'package:flutter_test/flutter_test.dart';
import 'package:admin_panel/models/consumer_record.dart';
import 'package:admin_panel/models/record_diff.dart';
import 'package:admin_panel/services/workflow_engine.dart';

void main() {
  group('Smart Action Center & Workflow Engine Tests', () {
    final now = DateTime.now();

    DateTime daysAgo(int days) {
      return DateTime(now.year, now.month, now.day).subtract(Duration(days: days));
    }

    DateTime daysInFuture(int days) {
      return DateTime(now.year, now.month, now.day).add(Duration(days: days));
    }

    test('Test Case 1: Application Days calculation from submitDate', () {
      final record = ConsumerRecord(
        consumerNo: 'AC101',
        name: 'Customer 0 Days',
        submitDate: daysAgo(0),
      );
      expect(record.applicationDays, equals(0));
      expect(record.overallStage, equals('Agreement'));
      expect(record.actionRequired, equals('Agreement'));
      expect(record.nextAction, equals('Upload Agreement'));
    });

    test('Test Case 2: Agreement Pending customer properties', () {
      final record = ConsumerRecord(
        consumerNo: 'AC102',
        name: 'Agreement Pending Customer',
        submitDate: daysAgo(7),
        agreementStatus: 'Pending',
      );
      expect(record.applicationDays, equals(7));
      expect(record.overallStage, equals('Agreement'));
      expect(record.actionRequired, equals('Agreement'));
      expect(record.nextAction, equals('Upload Agreement'));
    });

    test('Test Case 3: Loan Required = YES -> Agreement completed moves to Loan Pending', () {
      final record = ConsumerRecord(
        consumerNo: 'AC103',
        name: 'Loan Required Customer',
        agreementStatus: 'Verified',
        loanRequired: 'Yes',
        loanStatus: 'Pending',
        submitDate: daysAgo(10),
      );
      expect(record.overallStage, equals('Loan'));
      expect(record.actionRequired, equals('Loan Action Required'));
      expect(record.nextAction, equals('Prepare / Submit Loan File'));
    });

    test('Test Case 4: Loan Required = NO -> Agreement completed skips Loan to Installation', () {
      final record = ConsumerRecord(
        consumerNo: 'AC104',
        name: 'Loan Not Required Customer',
        agreementStatus: 'Verified',
        loanRequired: 'No',
        installationStatus: 'Not Started',
        submitDate: daysAgo(15),
      );
      expect(record.overallStage, equals('Installation'));
      expect(record.actionRequired, equals('Installation'));
      expect(record.nextAction, equals('Schedule Installation'));
    });

    test('Test Case 5: Installation Completed moves to RTS Pending', () {
      final record = ConsumerRecord(
        consumerNo: 'AC105',
        name: 'Installation Done Customer',
        agreementStatus: 'Verified',
        loanRequired: 'No',
        installationStatus: 'Installation Completed',
        rtsStatus: 'Not Started',
        submitDate: daysAgo(20),
      );
      expect(record.overallStage, equals('RTS'));
      expect(record.actionRequired, equals('RTS'));
      expect(record.nextAction, equals('Process RTS'));
    });

    test('Test Case 6: RTS Completed moves to Subsidy Processing', () {
      final record = ConsumerRecord(
        consumerNo: 'AC106',
        name: 'RTS Completed Customer',
        agreementStatus: 'Verified',
        installationStatus: 'Installation Completed',
        rtsStatus: 'Completed',
        subsidyStatus: 'Subsidy Request',
        submitDate: daysAgo(30),
      );
      expect(record.overallStage, equals('Subsidy'));
      expect(record.actionRequired, equals('Subsidy'));
      expect(record.nextAction, equals('Process Subsidy'));
    });

    test('Test Case 7: Action Center sorting: 1) Days in Stage DESC, 2) App Days DESC, 3) App Date ASC', () {
      final list = [
        ConsumerRecord(consumerNo: 'A', name: 'Cust A', submitDate: daysAgo(10), agreementDate: daysAgo(2)), // Days in Stage: 2
        ConsumerRecord(consumerNo: 'B', name: 'Cust B', submitDate: daysAgo(65), agreementDate: daysAgo(20)), // Days in Stage: 20
        ConsumerRecord(consumerNo: 'C', name: 'Cust C', submitDate: daysAgo(42), agreementDate: daysAgo(15)), // Days in Stage: 15
      ];

      WorkflowEngine.sortRecordsForActionCenter(list);

      expect(list.map((r) => r.consumerNo).toList(), equals(['B', 'C', 'A']));
    });

    test('Test Case 8: Subsidy Received sets customer_work_state = COMPLETED and clears actions', () {
      final recordCompleted = ConsumerRecord(
        consumerNo: 'AC108',
        name: 'Subsidy Received Consumer',
        subsidyStatus: 'Received',
        submitDate: daysAgo(90),
      );

      expect(recordCompleted.isFullyCompleted, isTrue);
      expect(recordCompleted.overallStage, equals('Completed'));
      expect(recordCompleted.actionRequired, equals('None'));
      expect(recordCompleted.nextAction, equals('None'));
      expect(recordCompleted.isActiveApplication, isFalse);
    });

    test('Test Case 9: Mark as Complete sets customerWorkState = COMPLETED, actionRequired = None, nextAction = None', () {
      final activeRecord = ConsumerRecord(
        consumerNo: 'AC109',
        name: 'Active Customer to Complete',
        submitDate: daysAgo(45),
      );

      expect(activeRecord.isActiveApplication, isTrue);

      final completedRecord = activeRecord.copyWith(customerWorkState: 'COMPLETED');

      expect(completedRecord.customerWorkState, equals('COMPLETED'));
      expect(completedRecord.actionRequired, equals('None'));
      expect(completedRecord.nextAction, equals('None'));
      expect(completedRecord.isActiveApplication, isFalse);
      expect(completedRecord.overallStage, equals('Completed'));
    });

    test('Test Case 10: Reopened customer returns to active status and recalculates stage via Workflow Engine', () {
      final completedRecord = ConsumerRecord(
        consumerNo: 'AC110',
        name: 'Completed Customer to Reopen',
        submitDate: daysAgo(20),
        customerWorkState: 'COMPLETED',
      );

      expect(completedRecord.isActiveApplication, isFalse);
      expect(completedRecord.overallStage, equals('Completed'));

      final reopenedRecord = completedRecord.copyWith(customerWorkState: 'ACTIVE');

      expect(reopenedRecord.customerWorkState, equals('ACTIVE'));
      expect(reopenedRecord.isActiveApplication, isTrue);
      expect(reopenedRecord.overallStage, equals('Agreement'));
      expect(reopenedRecord.actionRequired, equals('Agreement'));
      expect(reopenedRecord.nextAction, equals('Upload Agreement'));
    });
  });
}
