import 'package:flutter_test/flutter_test.dart';
import 'package:admin_panel/models/consumer_record.dart';
import 'package:admin_panel/services/workflow_engine.dart';

void main() {
  group('Action Center 3 Quick Actions & Follow-up Tests', () {
    test('1. Mark Complete sets customer_work_state = COMPLETED and preserves work stage', () {
      final original = ConsumerRecord(
        id: 'rec-1',
        consumerNo: '123456789012',
        name: 'Ganesh Shinde',
        status: 'In Progress',
        customerWorkState: 'ACTIVE',
        loanRequired: 'YES',
        loanStatus: 'Applied',
        agreementStatus: 'Verified',
      );

      expect(original.isActiveWorkState, isTrue);
      expect(original.isCompletedState, isFalse);
      expect(original.overallStage, equals('Loan'));

      final completed = original.copyWith(
        customerWorkState: 'COMPLETED',
      );

      expect(completed.customerWorkState, equals('COMPLETED'));
      expect(completed.isCompletedState, isTrue);
      expect(completed.isActiveWorkState, isFalse);
      // ActionRequired / NextAction reflect completed state
      expect(completed.actionRequired, equals('None'));
      expect(completed.nextAction, equals('None'));
      // Once completed, overallStage resolves to Completed
      expect(completed.overallStage, equals('Completed'));
      // Underlying workflow fields are NOT deleted or cleared
      expect(completed.consumerNo, equals('123456789012'));
      expect(completed.loanStatus, equals('Applied'));
      expect(completed.loanRequired, equals('YES'));
    });

    test('2. Mark Hold sets customer_work_state = ON_HOLD and retains stage & details', () {
      final original = ConsumerRecord(
        id: 'rec-2',
        consumerNo: '987654321098',
        name: 'Pooja Patil',
        status: 'In Progress',
        customerWorkState: 'ACTIVE',
        loanRequired: 'NO',
        agreementStatus: 'Verified',
        installationStatus: 'Site Survey Done',
      );

      expect(original.overallStage, equals('Installation'));

      final onHold = original.copyWith(
        customerWorkState: 'ON_HOLD',
        holdReason: 'Waiting for Bank',
        holdRemarks: 'Sanction letter pending from SBI',
        expectedFollowupDate: DateTime(2026, 9, 15),
      );

      expect(onHold.customerWorkState, equals('ON_HOLD'));
      expect(onHold.isHold, isTrue);
      expect(onHold.isActiveWorkState, isFalse);
      expect(onHold.holdReason, equals('Waiting for Bank'));
      expect(onHold.holdRemarks, equals('Sanction letter pending from SBI'));
      // Work Stage must NOT change
      expect(onHold.overallStage, equals('Installation'));
    });

    test('3. Reopening an On Hold customer sets customer_work_state = ACTIVE and reruns workflow', () {
      final onHold = ConsumerRecord(
        id: 'rec-2',
        consumerNo: '987654321098',
        name: 'Pooja Patil',
        status: 'In Progress',
        customerWorkState: 'ON_HOLD',
        holdReason: 'Waiting for Customer',
        agreementStatus: 'Pending',
      );

      expect(onHold.isHold, isTrue);
      expect(onHold.overallStage, equals('Agreement'));

      // Reopen
      final reopenedStage = WorkflowEngine.getCurrentWorkStage(onHold);
      final reopenedAction = WorkflowEngine.getActionRequired(onHold);
      final reopenedNextAction = WorkflowEngine.getNextAction(onHold);

      final reopened = onHold.copyWith(
        customerWorkState: 'ACTIVE',
        holdReason: null,
        holdRemarks: null,
      );

      expect(reopened.customerWorkState, equals('ACTIVE'));
      expect(reopened.isActiveWorkState, isTrue);
      expect(reopened.isHold, isFalse);
      expect(reopenedStage, equals('Agreement'));
      expect(reopenedAction, contains('Agreement'));
      expect(reopenedNextAction, isNotEmpty);
      expect(reopened.overallStage, equals('Agreement'));
      expect(reopened.actionRequired, contains('Agreement'));
    });

    test('4. Mark Follow-up schedules follow-up without mutating Work Stage', () {
      final today = DateTime.now();
      final original = ConsumerRecord(
        id: 'rec-3',
        consumerNo: '112233445566',
        name: 'Rahul Deshmukh',
        status: 'In Progress',
        customerWorkState: 'ACTIVE',
        loanRequired: 'NO',
        agreementStatus: 'Verified',
        installationStatus: 'Completed',
        rtsStatus: 'Documents Submitted',
      );

      expect(original.overallStage, equals('RTS'));

      final withFollowup = original.copyWith(
        hasActiveFollowup: true,
        followupDate: today,
        followupReason: 'Bank Follow-up',
        followupRemarks: 'Call manager about subsidy loan',
      );

      expect(withFollowup.hasActiveFollowup, isTrue);
      expect(withFollowup.followupReason, equals('Bank Follow-up'));
      expect(withFollowup.isFollowupToday, isTrue);
      expect(withFollowup.isFollowupOverdue, isFalse);
      expect(withFollowup.isFollowupUpcoming, isFalse);
      // Stage must remain RTS
      expect(withFollowup.overallStage, equals('RTS'));
    });

    test('5. Follow-up date classification: Today, Overdue, and Upcoming', () {
      final now = DateTime.now();
      final todayDate = DateTime(now.year, now.month, now.day, 12, 0);
      final yesterday = todayDate.subtract(const Duration(days: 2));
      final nextWeek = todayDate.add(const Duration(days: 4));

      final recOverdue = ConsumerRecord(
        consumerNo: '1',
        name: 'Overdue User',
        hasActiveFollowup: true,
        followupDate: yesterday,
      );
      expect(recOverdue.isFollowupOverdue, isTrue);
      expect(recOverdue.isFollowupToday, isFalse);
      expect(recOverdue.isFollowupUpcoming, isFalse);

      final recToday = ConsumerRecord(
        consumerNo: '2',
        name: 'Today User',
        hasActiveFollowup: true,
        followupDate: todayDate,
      );
      expect(recToday.isFollowupToday, isTrue);
      expect(recToday.isFollowupOverdue, isFalse);
      expect(recToday.isFollowupUpcoming, isFalse);

      final recUpcoming = ConsumerRecord(
        consumerNo: '3',
        name: 'Upcoming User',
        hasActiveFollowup: true,
        followupDate: nextWeek,
      );
      expect(recUpcoming.isFollowupUpcoming, isTrue);
      expect(recUpcoming.isFollowupToday, isFalse);
      expect(recUpcoming.isFollowupOverdue, isFalse);
    });

    test('6. Follow-up Done records result and next follow-up without modifying stage', () {
      final now = DateTime.now();
      final activeFollowup = ConsumerRecord(
        id: 'rec-4',
        consumerNo: '554433221100',
        name: 'Sunil Pawar',
        customerWorkState: 'ACTIVE',
        loanRequired: 'NO',
        agreementStatus: 'Verified',
        installationStatus: 'Installation in Progress',
        hasActiveFollowup: true,
        followupDate: now,
        followupReason: 'Customer Call',
      );

      expect(activeFollowup.overallStage, equals('Installation'));

      final nextDate = now.add(const Duration(days: 3));
      final followupCompleted = activeFollowup.copyWith(
        hasActiveFollowup: true, // has next follow-up
        followupDate: nextDate,
        followupReason: 'Customer Call',
        lastFollowupResult: 'Customer requested callback on Friday afternoon',
        followupRemarks: 'Talked to customer; agreed on installation inspection Friday',
      );

      expect(followupCompleted.lastFollowupResult, contains('callback on Friday'));
      expect(followupCompleted.isFollowupUpcoming, isTrue);
      expect(followupCompleted.overallStage, equals('Installation'));
    });

    test('7. Current Sub-Stage mapping reflects actual work stage sub-status', () {
      final agreementRec = ConsumerRecord(
        consumerNo: 'A1',
        name: 'Customer A',
        agreementStatus: 'Document Verification',
      );
      expect(agreementRec.currentSubStage, equals('Document Verification'));

      final loanRec = ConsumerRecord(
        consumerNo: 'L1',
        name: 'Customer L',
        loanRequired: 'YES',
        agreementStatus: 'Verified',
        loanStatus: 'Applied',
        loanSubStage: 'Sanctioned',
      );
      expect(loanRec.currentSubStage, equals('Sanctioned'));

      final installRec = ConsumerRecord(
        consumerNo: 'I1',
        name: 'Customer I',
        loanRequired: 'NO',
        agreementStatus: 'Verified',
        installationStatus: 'Structure Completed',
      );
      expect(installRec.currentSubStage, equals('Structure Completed'));

      final rtsRec = ConsumerRecord(
        consumerNo: 'R1',
        name: 'Customer R',
        loanRequired: 'NO',
        agreementStatus: 'Verified',
        installationStatus: 'Completed',
        rtsStatus: 'Meter Installed',
      );
      expect(rtsRec.currentSubStage, equals('Meter Installed'));

      final subsidyRec = ConsumerRecord(
        consumerNo: 'S1',
        name: 'Customer S',
        loanRequired: 'NO',
        agreementStatus: 'Verified',
        installationStatus: 'Completed',
        rtsStatus: 'Completed',
        subsidyStatus: 'Pending with Discom',
      );
      expect(subsidyRec.currentSubStage, equals('Pending with Discom'));
    });
  });
}
