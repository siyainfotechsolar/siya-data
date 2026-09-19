import 'package:flutter_test/flutter_test.dart';
import 'package:admin_panel/models/office_task.dart';

void main() {
  group('Office Staff Task Assignment Model Tests', () {
    test('OfficeTask serialization and deserialization works accurately', () {
      final now = DateTime.now();
      final task = OfficeTask(
        id: 'task-101',
        customerId: 'cust-202',
        customerName: 'ABC Patil',
        consumerNo: '123456789012',
        village: 'Kopargaon',
        title: 'Customer Call - ABC Patil',
        taskType: OfficeTaskType.customerCall,
        description: 'Call customer to request copy of electricity bill',
        priority: OfficeTaskPriority.high,
        status: OfficeTaskStatus.pending,
        dueDate: now.add(const Duration(days: 1)),
        assignedToId: 'staff-01',
        assignedToName: 'Pooja',
        createdBy: 'admin-01',
        createdByName: 'Admin',
        createdAt: now,
        updatedAt: now,
      );

      final map = task.toMap();
      expect(map['title'], 'Customer Call - ABC Patil');
      expect(map['task_type'], OfficeTaskType.customerCall);
      expect(map['assigned_to_name'], 'Pooja');
      expect(map['priority'], OfficeTaskPriority.high);
      expect(map['status'], OfficeTaskStatus.pending);

      final fromMap = OfficeTask.fromMap(map);
      expect(fromMap.id, 'task-101');
      expect(fromMap.customerName, 'ABC Patil');
      expect(fromMap.assignedToName, 'Pooja');
      expect(fromMap.village, 'Kopargaon');
    });

    test('All 14 Office Staff Task Types are registered', () {
      expect(OfficeTaskType.allTypes.length, 14);
      expect(OfficeTaskType.allTypes.contains('Customer Call'), isTrue);
      expect(OfficeTaskType.allTypes.contains('Follow-up'), isTrue);
      expect(OfficeTaskType.allTypes.contains('Document Collection'), isTrue);
      expect(OfficeTaskType.allTypes.contains('Agreement'), isTrue);
      expect(OfficeTaskType.allTypes.contains('Payment Follow-up'), isTrue);
      expect(OfficeTaskType.allTypes.contains('Loan Document'), isTrue);
      expect(OfficeTaskType.allTypes.contains('PM Surya Ghar Document'), isTrue);
      expect(OfficeTaskType.allTypes.contains('Subsidy Follow-up'), isTrue);
      expect(OfficeTaskType.allTypes.contains('RTS Follow-up'), isTrue);
      expect(OfficeTaskType.allTypes.contains('Customer Information Update'), isTrue);
      expect(OfficeTaskType.allTypes.contains('Billing Issue'), isTrue);
      expect(OfficeTaskType.allTypes.contains('Customer Complaint'), isTrue);
      expect(OfficeTaskType.allTypes.contains('General Office Work'), isTrue);
      expect(OfficeTaskType.allTypes.contains('Other'), isTrue);
    });

    test('Reassignment and Work Log assignment model validation', () {
      final assignment = TaskAssignment(
        id: 'assign-55',
        taskId: 'task-101',
        staffId: 'staff-02',
        staffName: 'Rahul',
        assignedBy: 'admin-01',
        assignedByName: 'Admin',
        status: 'Reassigned',
        remarks: 'Reassigned from Pooja to Rahul for urgent followup',
        assignedAt: DateTime.now(),
      );

      final map = assignment.toMap();
      expect(map['staff_name'], 'Rahul');
      expect(map['status'], 'Reassigned');
      expect(map['remarks'], contains('Reassigned from Pooja to Rahul'));

      final reconstructed = TaskAssignment.fromMap(map);
      expect(reconstructed.staffName, 'Rahul');
      expect(reconstructed.status, 'Reassigned');
    });

    test('Task isOverdue computation behaves correctly', () {
      final pastDue = OfficeTask(
        id: '1',
        customerName: 'Test',
        consumerNo: '111',
        title: 'Overdue Task',
        taskType: OfficeTaskType.followUp,
        assignedToName: 'Amit',
        dueDate: DateTime.now().subtract(const Duration(days: 2)),
        status: OfficeTaskStatus.pending,
      );
      expect(pastDue.isOverdue, isTrue);

      final completedPastDue = pastDue.copyWith(status: OfficeTaskStatus.completed);
      expect(completedPastDue.isOverdue, isFalse);

      final futureTask = pastDue.copyWith(dueDate: DateTime.now().add(const Duration(days: 3)));
      expect(futureTask.isOverdue, isFalse);
    });
  });
}
