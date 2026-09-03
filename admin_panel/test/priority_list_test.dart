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

    test('Test Case 10: Completed records are excluded from active priority list', () {
      final recordCompleted = ConsumerRecord(
        consumerNo: 'P110',
        name: 'Finished Consumer',
        status: 'Completed',
        submitDate: daysAgo(45),
      );

      expect(recordCompleted.isActiveApplication, isFalse);
    });

    test('Test Case 11: Cancelled records are excluded from active priority list', () {
      final recordCancelled = ConsumerRecord(
        consumerNo: 'P111',
        name: 'Cancelled Consumer',
        status: 'Cancelled',
        submitDate: daysAgo(50),
      );

      expect(recordCancelled.isActiveApplication, isFalse);
    });

    test('Test Case 12: Status changes DO NOT change calculated priority', () {
      final initial = ConsumerRecord(
        consumerNo: 'P112',
        name: 'Status Test',
        status: 'Pending',
        submitDate: daysAgo(20), // HIGH (20)
      );

      final updatedStatus = initial.copyWith(status: 'Approved');
      expect(updatedStatus.applicationDays, equals(20));
      expect(updatedStatus.priority, equals('HIGH'));
    });

    test('Test Case 13: Subsidy status changes DO NOT change calculated priority', () {
      final initial = ConsumerRecord(
        consumerNo: 'P113',
        name: 'Subsidy Test',
        subsidyStatus: 'Not Applied',
        submitDate: daysAgo(25), // HIGH (25)
      );

      final updatedSubsidy = initial.copyWith(subsidyStatus: 'Approved');
      expect(updatedSubsidy.applicationDays, equals(25));
      expect(updatedSubsidy.priority, equals('HIGH'));
    });

    test('Test Case 14: Installation status changes DO NOT change calculated priority', () {
      final initial = ConsumerRecord(
        consumerNo: 'P114',
        name: 'Installation Test',
        installationStatus: 'Not Started',
        submitDate: daysAgo(12), // MEDIUM (12)
      );

      final updatedInstall = initial.copyWith(installationStatus: 'Panel Pending');
      expect(updatedInstall.applicationDays, equals(12));
      expect(updatedInstall.priority, equals('MEDIUM'));
    });

    test('Test Case 15: Loan status changes DO NOT change calculated priority', () {
      final initial = ConsumerRecord(
        consumerNo: 'P115',
        name: 'Loan Test',
        loanRequired: 'Yes',
        loanStatus: 'Pending',
        submitDate: daysAgo(35), // CRITICAL (35)
      );

      final updatedLoan = initial.copyWith(loanStatus: 'Approved');
      expect(updatedLoan.applicationDays, equals(35));
      expect(updatedLoan.priority, equals('CRITICAL'));
    });

    test('Test Case 16: Submit Date UPDATE recalculates application days & priority', () {
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

    test('Test Case 17: Submit Date SKIP preserves existing submit date', () {
      final existing = ConsumerRecord(
        consumerNo: 'P117',
        name: 'Submit Skip Test',
        submitDate: daysAgo(22), // HIGH (22)
      );

      final incoming = ConsumerRecord(
        consumerNo: 'P117',
        name: 'Submit Skip Test',
        submitDate: daysAgo(2), // Mapped as SKIP in import
      );

      final diff = RecordDiff(
        existingRecord: existing,
        incomingRecord: incoming,
        changedFields: [],
      );

      // 'submit_date' is omitted from allowedFieldKeys (SKIP)
      final merged = diff.createMergedRecord(
        ConflictStrategy.updateNonEmptyOnly,
        allowedFieldKeys: {'name'},
      );

      expect(merged.submitDate, equals(existing.submitDate));
      expect(merged.applicationDays, equals(22));
      expect(merged.priority, equals('HIGH'));
    });

    test('Test Case 18: Future submit date returns 0 days and isSubmitDateFuture warning flag', () {
      final recordFuture = ConsumerRecord(
        consumerNo: 'P118',
        name: 'Future Date Customer',
        submitDate: daysInFuture(5),
      );

      expect(recordFuture.applicationDays, equals(0));
      expect(recordFuture.priority, equals('NORMAL'));
      expect(recordFuture.isSubmitDateFuture, isTrue);
    });
  });
}
