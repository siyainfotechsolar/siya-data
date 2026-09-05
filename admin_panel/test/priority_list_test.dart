import 'package:flutter_test/flutter_test.dart';
import 'package:admin_panel/models/consumer_record.dart';
import 'package:admin_panel/models/record_diff.dart';

void main() {
  group('Dynamic Application Days Based Priority List Tests', () {
    final now = DateTime.now();

    DateTime daysAgo(int days) {
      return DateTime(now.year, now.month, now.day).subtract(Duration(days: days));
    }

    DateTime daysInFuture(int days) {
      return DateTime(now.year, now.month, now.day).add(Duration(days: days));
    }

    test('Test Case 1: 0 days submit date resolves to NORMAL priority', () {
      final record = ConsumerRecord(
        consumerNo: 'P101',
        name: 'Normal Customer 0 Days',
        submitDate: daysAgo(0),
      );
      expect(record.applicationDays, equals(0));
      expect(record.priorityLevel, equals(PriorityLevel.normal));
      expect(record.priority, equals('NORMAL'));
    });

    test('Test Case 2: 7 days submit date resolves to NORMAL priority', () {
      final record = ConsumerRecord(
        consumerNo: 'P102',
        name: 'Normal Customer 7 Days',
        submitDate: daysAgo(7),
      );
      expect(record.applicationDays, equals(7));
      expect(record.priorityLevel, equals(PriorityLevel.normal));
      expect(record.priority, equals('NORMAL'));
    });

    test('Test Case 3: 8 days submit date resolves to MEDIUM priority', () {
      final record = ConsumerRecord(
        consumerNo: 'P103',
        name: 'Medium Customer 8 Days',
        submitDate: daysAgo(8),
      );
      expect(record.applicationDays, equals(8));
      expect(record.priorityLevel, equals(PriorityLevel.medium));
      expect(record.priority, equals('MEDIUM'));
    });

    test('Test Case 4: 15 days submit date resolves to MEDIUM priority', () {
      final record = ConsumerRecord(
        consumerNo: 'P104',
        name: 'Medium Customer 15 Days',
        submitDate: daysAgo(15),
      );
      expect(record.applicationDays, equals(15));
      expect(record.priorityLevel, equals(PriorityLevel.medium));
      expect(record.priority, equals('MEDIUM'));
    });

    test('Test Case 5: 16 days submit date resolves to HIGH priority', () {
      final record = ConsumerRecord(
        consumerNo: 'P105',
        name: 'High Customer 16 Days',
        submitDate: daysAgo(16),
      );
      expect(record.applicationDays, equals(16));
      expect(record.priorityLevel, equals(PriorityLevel.high));
      expect(record.priority, equals('HIGH'));
    });

    test('Test Case 6: 30 days submit date resolves to HIGH priority', () {
      final record = ConsumerRecord(
        consumerNo: 'P106',
        name: 'High Customer 30 Days',
        submitDate: daysAgo(30),
      );
      expect(record.applicationDays, equals(30));
      expect(record.priorityLevel, equals(PriorityLevel.high));
      expect(record.priority, equals('HIGH'));
    });

    test('Test Case 7: 31 days submit date resolves to CRITICAL priority', () {
      final record = ConsumerRecord(
        consumerNo: 'P107',
        name: 'Critical Customer 31 Days',
        submitDate: daysAgo(31),
      );
      expect(record.applicationDays, equals(31));
      expect(record.priorityLevel, equals(PriorityLevel.critical));
      expect(record.priority, equals('CRITICAL'));
    });

    test('Test Case 8: 60+ days submit date resolves to CRITICAL priority', () {
      final record = ConsumerRecord(
        consumerNo: 'P108',
        name: 'Critical Customer 65 Days',
        submitDate: daysAgo(65),
      );
      expect(record.applicationDays, equals(65));
      expect(record.priorityLevel, equals(PriorityLevel.critical));
      expect(record.priority, equals('CRITICAL'));
    });

    test('Test Case 9: Oldest records appear first (Priority Rank ASC, Application Days DESC)', () {
      final list = [
        ConsumerRecord(consumerNo: 'A', name: 'Cust A', submitDate: daysAgo(3)), // NORMAL (3)
        ConsumerRecord(consumerNo: 'B', name: 'Cust B', submitDate: daysAgo(65)), // CRITICAL (65)
        ConsumerRecord(consumerNo: 'C', name: 'Cust C', submitDate: daysAgo(42)), // CRITICAL (42)
        ConsumerRecord(consumerNo: 'D', name: 'Cust D', submitDate: daysAgo(25)), // HIGH (25)
        ConsumerRecord(consumerNo: 'E', name: 'Cust E', submitDate: daysAgo(10)), // MEDIUM (10)
      ];

      list.sort((a, b) {
        final rankCmp = a.priorityLevel.rank.compareTo(b.priorityLevel.rank);
        if (rankCmp != 0) return rankCmp;
        return b.applicationDays.compareTo(a.applicationDays);
      });

      expect(list.map((r) => r.consumerNo).toList(), equals(['B', 'C', 'D', 'E', 'A']));
      expect(list.first.applicationDays, equals(65));
      expect(list.first.priority, equals('CRITICAL'));
    });

    test('Test Case 10: Completed records are excluded from active priority list and get Priority None', () {
      final recordCompleted = ConsumerRecord(
        consumerNo: 'P110',
        name: 'Finished Consumer',
        status: 'Completed',
        submitDate: daysAgo(908),
      );

      expect(recordCompleted.isActiveApplication, isFalse);
      expect(recordCompleted.priorityLevel, equals(PriorityLevel.none));
      expect(recordCompleted.priority, equals('None'));
      expect(recordCompleted.actionRequired, equals('None'));
      expect(recordCompleted.nextAction, equals('None'));
    });

    test('Test Case 11: Subsidy Received records get Priority None', () {
      final recordSubsidyReceived = ConsumerRecord(
        consumerNo: 'P111',
        name: 'Subsidy Received Consumer',
        subsidyStatus: 'Received',
        submitDate: daysAgo(500),
      );

      expect(recordSubsidyReceived.isActiveApplication, isFalse);
      expect(recordSubsidyReceived.priorityLevel, equals(PriorityLevel.none));
      expect(recordSubsidyReceived.priority, equals('None'));
      expect(recordSubsidyReceived.actionRequired, equals('None'));
    });

    test('Test Case 12: Subsidy Processing cases resolve to Processing priority, NOT Critical', () {
      final recordProcessing = ConsumerRecord(
        consumerNo: 'P112',
        name: 'Subsidy Processing Customer',
        rtsStatus: 'Completed',
        subsidyStatus: 'Subsidy Request',
        submitDate: daysAgo(300),
      );

      expect(recordProcessing.priorityLevel, equals(PriorityLevel.processing));
      expect(recordProcessing.priority, equals('Processing'));
      expect(recordProcessing.actionRequired, equals('Subsidy'));
    });

    test('Test Case 13: Operational Pending stage Agreement resolves to Critical for 753 days', () {
      final recordAgreement = ConsumerRecord(
        consumerNo: 'P113',
        name: 'Agreement Pending Customer',
        agreementStatus: 'Pending',
        submitDate: daysAgo(753),
      );

      expect(recordAgreement.priorityLevel, equals(PriorityLevel.critical));
      expect(recordAgreement.priority, equals('CRITICAL'));
      expect(recordAgreement.actionRequired, equals('Agreement'));
    });

    test('Test Case 14: Submit Date UPDATE recalculates application days & priority', () {
      final existing = ConsumerRecord(
        consumerNo: 'P116',
        name: 'Submit Update Test',
        submitDate: daysAgo(5), // NORMAL (5)
      );

      final incoming = ConsumerRecord(
        consumerNo: 'P116',
        name: 'Submit Update Test',
        submitDate: daysAgo(40), // Updated to CRITICAL (40)
      );

      final diff = RecordDiff(
        existingRecord: existing,
        incomingRecord: incoming,
        changedFields: [],
      );

      final merged = diff.createMergedRecord(
        ConflictStrategy.updateNonEmptyOnly,
        allowedFieldKeys: {'submit_date'},
      );

      expect(merged.applicationDays, equals(40));
      expect(merged.priority, equals('CRITICAL'));
    });

    test('Test Case 15: Future submit date returns 0 days and isSubmitDateFuture warning flag', () {
      final recordFuture = ConsumerRecord(
        consumerNo: 'P118',
        name: 'Future Date Customer',
        submitDate: daysInFuture(5),
      );

      expect(recordFuture.applicationDays, equals(0));
      expect(recordFuture.priority, equals('NORMAL'));
      expect(recordFuture.isSubmitDateFuture, isTrue);
    });

    test('Test Case 16: Mark as Complete sets priority = None, action_required = None, next_action = None & removes from Active Priority List', () {
      final activeRecord = ConsumerRecord(
        consumerNo: 'P119',
        name: 'Active Customer to Complete',
        submitDate: daysAgo(45), // Originally CRITICAL
      );

      expect(activeRecord.priority, equals('CRITICAL'));
      expect(activeRecord.isActiveApplication, isTrue);

      final completedRecord = activeRecord.copyWith(customerWorkState: 'COMPLETED');

      expect(completedRecord.customerWorkState, equals('COMPLETED'));
      expect(completedRecord.priorityLevel, equals(PriorityLevel.none));
      expect(completedRecord.priority, equals('None'));
      expect(completedRecord.actionRequired, equals('None'));
      expect(completedRecord.nextAction, equals('None'));
      expect(completedRecord.isActiveApplication, isFalse);
      expect(completedRecord.overallStage, equals('Completed'));
    });

    test('Test Case 17: Reopened customer returns to active status and recalculates priority from Workflow Engine', () {
      final completedRecord = ConsumerRecord(
        consumerNo: 'P120',
        name: 'Completed Customer to Reopen',
        submitDate: daysAgo(20), // 20 days -> HIGH
        customerWorkState: 'COMPLETED',
      );

      expect(completedRecord.priority, equals('None'));
      expect(completedRecord.isActiveApplication, isFalse);

      final reopenedRecord = completedRecord.copyWith(customerWorkState: 'ACTIVE');

      expect(reopenedRecord.customerWorkState, equals('ACTIVE'));
      expect(reopenedRecord.isActiveApplication, isTrue);
      expect(reopenedRecord.priorityLevel, equals(PriorityLevel.high));
      expect(reopenedRecord.priority, equals('HIGH'));
      expect(reopenedRecord.actionRequired, equals('Agreement'));
    });
  });
}
