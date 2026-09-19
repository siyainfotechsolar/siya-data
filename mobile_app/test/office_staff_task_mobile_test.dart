import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/models/office_task.dart';

void main() {
  group('Mobile Office Staff Tasks Test Suite', () {
    test('Task status transitions: Start, Hold, Complete', () {
      final initial = OfficeTask(
        id: 'task-mob-1',
        customerId: 'cust-1',
        customerName: 'Suresh Patil',
        consumerNo: '998877665544',
        village: 'Rahata',
        title: 'Document Collection - Suresh Patil',
        taskType: OfficeTaskType.documentCollection,
        priority: OfficeTaskPriority.high,
        status: OfficeTaskStatus.pending,
        assignedToName: 'Pooja',
      );

      expect(initial.status, OfficeTaskStatus.pending);
      expect(initial.isCompleted, isFalse);

      // 1. Staff starts task -> In Progress
      final startedTime = DateTime.now();
      final inProgress = initial.copyWith(
        status: OfficeTaskStatus.inProgress,
        startedAt: startedTime,
      );
      expect(inProgress.status, OfficeTaskStatus.inProgress);
      expect(inProgress.startedAt, startedTime);

      // 2. Staff puts on Hold
      final onHold = inProgress.copyWith(
        status: OfficeTaskStatus.hold,
        holdReason: 'Customer requested callback after 5 PM',
      );
      expect(onHold.status, OfficeTaskStatus.hold);
      expect(onHold.holdReason, contains('callback after 5 PM'));

      // 3. Staff Completes task
      final completedTime = DateTime.now();
      final completed = onHold.copyWith(
        status: OfficeTaskStatus.completed,
        completedAt: completedTime,
        completionNote: 'Received Aadhar & Electricity bill photos via WhatsApp',
      );
      expect(completed.status, OfficeTaskStatus.completed);
      expect(completed.isCompleted, isTrue);
      expect(completed.completionNote, isNotNull);
    });

    test('All 14 Task Types are defined and selectable', () {
      expect(OfficeTaskType.allTypes.length, 14);
      expect(OfficeTaskType.allTypes, contains('PM Surya Ghar Document'));
      expect(OfficeTaskType.allTypes, contains('Payment Follow-up'));
      expect(OfficeTaskType.allTypes, contains('Billing Issue'));
    });

    test('Local SQLite schema columns match OfficeTask map keys', () {
      final task = OfficeTask(
        id: 't-1',
        customerName: 'Anil Kumar',
        consumerNo: '112233445566',
        title: 'Agreement Follow-up',
        taskType: OfficeTaskType.agreement,
        assignedToName: 'Rahul',
      );

      final map = task.toMap();
      expect(map.containsKey('id'), isTrue);
      expect(map.containsKey('customer_id'), isTrue);
      expect(map.containsKey('customer_name'), isTrue);
      expect(map.containsKey('consumer_no'), isTrue);
      expect(map.containsKey('village'), isTrue);
      expect(map.containsKey('title'), isTrue);
      expect(map.containsKey('task_type'), isTrue);
      expect(map.containsKey('priority'), isTrue);
      expect(map.containsKey('status'), isTrue);
      expect(map.containsKey('assigned_to_name'), isTrue);
    });
  });
}
