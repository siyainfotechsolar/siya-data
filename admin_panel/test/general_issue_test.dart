import 'package:flutter_test/flutter_test.dart';
import 'package:admin_panel/models/customer_issue.dart';

void main() {
  group('General Issue Module Tests', () {
    test('1. CustomerIssue JSON serialization & deserialization contract', () {
      final now = DateTime.now();
      final issue = CustomerIssue(
        id: 'issue-101',
        customerId: 'cust-uuid-1',
        consumerNo: '123456789012',
        customerName: 'Raj Patil',
        mobile: '9876543210',
        issueType: 'Document Problem',
        title: 'Electricity bill name mismatch',
        description: 'Need corrected Aadhaar card and affidavit',
        priority: 'High',
        status: 'In Progress',
        assignedStaff: 'Rihan',
        dueDate: DateTime(2026, 9, 12),
        remarks: 'Staff contacted customer',
        createdBy: 'admin-user',
        createdAt: now,
      );

      final json = issue.toJson();
      expect(json['customer_id'], 'cust-uuid-1');
      expect(json['consumer_no'], '123456789012');
      expect(json['customer_name'], 'Raj Patil');
      expect(json['issue_type'], 'Document Problem');
      expect(json['title'], 'Electricity bill name mismatch');
      expect(json['priority'], 'High');
      expect(json['status'], 'In Progress');
      expect(json['assigned_staff'], 'Rihan');
      expect(json['due_date'], '2026-09-12');

      final deserialized = CustomerIssue.fromJson(json);
      expect(deserialized.id, 'issue-101');
      expect(deserialized.customerId, 'cust-uuid-1');
      expect(deserialized.customerName, 'Raj Patil');
      expect(deserialized.issueType, 'Document Problem');
      expect(deserialized.priority, 'High');
      expect(deserialized.status, 'In Progress');
      expect(deserialized.assignedStaff, 'Rihan');
      expect(deserialized.dueDate, DateTime(2026, 9, 12));
    });

    test('2. Standard 14 Issue Types verification', () {
      expect(CustomerIssue.standardTypes, contains('Customer Complaint'));
      expect(CustomerIssue.standardTypes, contains('Document Problem'));
      expect(CustomerIssue.standardTypes, contains('Material Problem'));
      expect(CustomerIssue.standardTypes, contains('Installation Problem'));
      expect(CustomerIssue.standardTypes, contains('Inverter Problem'));
      expect(CustomerIssue.standardTypes, contains('Panel Problem'));
      expect(CustomerIssue.standardTypes, contains('Wiring Problem'));
      expect(CustomerIssue.standardTypes, contains('Bank Problem'));
      expect(CustomerIssue.standardTypes, contains('MSEDCL Problem'));
      expect(CustomerIssue.standardTypes, contains('RTS Problem'));
      expect(CustomerIssue.standardTypes, contains('Subsidy Problem'));
      expect(CustomerIssue.standardTypes, contains('Payment Problem'));
      expect(CustomerIssue.standardTypes, contains('Staff/Team Problem'));
      expect(CustomerIssue.standardTypes, contains('Other'));
      expect(CustomerIssue.standardTypes.length, 14);
    });

    test('3. Standard Statuses verification', () {
      expect(CustomerIssue.standardStatuses, contains('New'));
      expect(CustomerIssue.standardStatuses, contains('Assigned'));
      expect(CustomerIssue.standardStatuses, contains('In Progress'));
      expect(CustomerIssue.standardStatuses, contains('Hold'));
      expect(CustomerIssue.standardStatuses, contains('Resolved'));
      expect(CustomerIssue.standardStatuses, contains('Closed'));
      expect(CustomerIssue.standardStatuses, contains('Cancelled'));
      expect(CustomerIssue.standardStatuses.length, 7);
    });

    test('4. Standard Priorities verification', () {
      expect(CustomerIssue.standardPriorities, contains('Normal'));
      expect(CustomerIssue.standardPriorities, contains('High'));
      expect(CustomerIssue.standardPriorities, contains('Urgent'));
      expect(CustomerIssue.standardPriorities.length, 3);
    });

    test('5. Active status evaluation', () {
      final activeIssue = CustomerIssue(
        id: '1', customerId: 'c1', consumerNo: '123', customerName: 'A',
        issueType: 'Other', title: 'T', priority: 'Normal', status: 'In Progress',
        createdAt: DateTime.now(),
      );
      expect(activeIssue.isActive, isTrue);

      final holdIssue = CustomerIssue(
        id: '2', customerId: 'c1', consumerNo: '123', customerName: 'A',
        issueType: 'Other', title: 'T', priority: 'Normal', status: 'Hold',
        createdAt: DateTime.now(),
      );
      expect(holdIssue.isActive, isTrue);

      final resolvedIssue = CustomerIssue(
        id: '3', customerId: 'c1', consumerNo: '123', customerName: 'A',
        issueType: 'Other', title: 'T', priority: 'Normal', status: 'Resolved',
        createdAt: DateTime.now(),
      );
      expect(resolvedIssue.isActive, isFalse);

      final closedIssue = CustomerIssue(
        id: '4', customerId: 'c1', consumerNo: '123', customerName: 'A',
        issueType: 'Other', title: 'T', priority: 'Normal', status: 'Closed',
        createdAt: DateTime.now(),
      );
      expect(closedIssue.isActive, isFalse);
    });

    test('6. Stuck Issue Detection', () {
      // 10 days old in In Progress -> stuck
      final stuckIssue = CustomerIssue(
        id: 'stuck-1',
        customerId: 'c1',
        consumerNo: '123',
        customerName: 'Stuck Customer',
        issueType: 'Inverter Problem',
        title: 'Inverter error code 09',
        priority: 'High',
        status: 'In Progress',
        createdAt: DateTime.now().subtract(const Duration(days: 10)),
      );
      expect(stuckIssue.isStuck, isTrue);

      // 2 days old in In Progress -> not stuck
      final freshIssue = CustomerIssue(
        id: 'fresh-1',
        customerId: 'c1',
        consumerNo: '123',
        customerName: 'Fresh Customer',
        issueType: 'Inverter Problem',
        title: 'Inverter error code 09',
        priority: 'High',
        status: 'In Progress',
        createdAt: DateTime.now().subtract(const Duration(days: 2)),
      );
      expect(freshIssue.isStuck, isFalse);

      // 10 days old but Resolved -> not stuck
      final resolvedIssue = CustomerIssue(
        id: 'res-1',
        customerId: 'c1',
        consumerNo: '123',
        customerName: 'Resolved Customer',
        issueType: 'Inverter Problem',
        title: 'Inverter error code 09',
        priority: 'High',
        status: 'Resolved',
        createdAt: DateTime.now().subtract(const Duration(days: 10)),
      );
      expect(resolvedIssue.isStuck, isFalse);
    });

    test('7. Due Date Overdue and Due Today evaluation', () {
      final today = DateTime.now();
      final overdueIssue = CustomerIssue(
        id: 'od-1', customerId: 'c1', consumerNo: '123', customerName: 'A',
        issueType: 'Other', title: 'T', priority: 'Normal', status: 'In Progress',
        dueDate: today.subtract(const Duration(days: 2)),
        createdAt: today.subtract(const Duration(days: 3)),
      );
      expect(overdueIssue.isOverdue, isTrue);
      expect(overdueIssue.isDueToday, isFalse);

      final dueTodayIssue = CustomerIssue(
        id: 'dt-1', customerId: 'c1', consumerNo: '123', customerName: 'A',
        issueType: 'Other', title: 'T', priority: 'Normal', status: 'In Progress',
        dueDate: today,
        createdAt: today,
      );
      expect(dueTodayIssue.isDueToday, isTrue);
    });

    test('8. Duplicate Issue check contract', () {
      final activeIssue = CustomerIssue(
        id: 'existing-1',
        customerId: 'customer-123',
        consumerNo: '112233445566',
        customerName: 'Raj Patil',
        issueType: 'Document Problem',
        title: 'Existing active document issue',
        priority: 'Normal',
        status: 'In Progress',
        createdAt: DateTime.now(),
      );

      // Simulation of duplicate rule: Same Customer + Same Issue Type + Active Issue
      bool isDuplicate(String customerId, String issueType, List<CustomerIssue> existingIssues) {
        return existingIssues.any((i) =>
          i.customerId == customerId &&
          i.issueType.toLowerCase() == issueType.toLowerCase() &&
          i.isActive,
        );
      }

      expect(isDuplicate('customer-123', 'Document Problem', [activeIssue]), isTrue);
      expect(isDuplicate('customer-123', 'Inverter Problem', [activeIssue]), isFalse);
      expect(isDuplicate('customer-999', 'Document Problem', [activeIssue]), isFalse);
    });

    test('9. CustomerIssueHistory model serialization', () {
      final now = DateTime.now();
      final history = CustomerIssueHistory(
        id: 'hist-1',
        issueId: 'issue-101',
        action: 'STATUS_CHANGED',
        oldValue: 'New',
        newValue: 'Assigned',
        performedByName: 'Admin',
        remarks: 'Assigned to technical lead',
        createdAt: now,
      );

      final json = history.toJson();
      expect(json['issue_id'], 'issue-101');
      expect(json['action'], 'STATUS_CHANGED');
      expect(json['old_value'], 'New');
      expect(json['new_value'], 'Assigned');

      final deserialized = CustomerIssueHistory.fromJson(json);
      expect(deserialized.id, 'hist-1');
      expect(deserialized.action, 'STATUS_CHANGED');
      expect(deserialized.newValue, 'Assigned');
    });
  });
}
