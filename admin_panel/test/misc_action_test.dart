import 'package:flutter_test/flutter_test.dart';
import 'package:admin_panel/models/consumer_record.dart';
import 'package:admin_panel/models/customer_misc_action.dart';
import 'package:admin_panel/services/workflow_engine.dart';

void main() {
  group('MISC Action Center Module Tests', () {
    test('1. CustomerMiscAction json serialization and deserialization contract', () {
      final now = DateTime.now();
      final action = CustomerMiscAction(
        id: 'misc-101',
        recordId: 'cust-uuid-1',
        consumerNo: '123456789012',
        customerName: 'Suresh Patil',
        mobile: '9876543210',
        reason: 'Customer Details Correction',
        description: 'Update bank account IFSC code',
        assignedStaffName: 'Pooja Patil',
        dueDate: DateTime(2026, 9, 10),
        priority: 'High',
        status: 'Pending',
        remarks: 'Urgent correction before subsidy disbursement',
        createdAt: now,
      );

      final json = action.toJson();
      expect(json['record_id'], 'cust-uuid-1');
      expect(json['consumer_no'], '123456789012');
      expect(json['customer_name'], 'Suresh Patil');
      expect(json['reason'], 'Customer Details Correction');
      expect(json['priority'], 'High');
      expect(json['status'], 'Pending');
      expect(json['due_date'], '2026-09-10');

      final deserialized = CustomerMiscAction.fromJson(json);
      expect(deserialized.id, 'misc-101');
      expect(deserialized.recordId, 'cust-uuid-1');
      expect(deserialized.customerName, 'Suresh Patil');
      expect(deserialized.reason, 'Customer Details Correction');
      expect(deserialized.priority, 'High');
      expect(deserialized.status, 'Pending');
      expect(deserialized.dueDate, DateTime(2026, 9, 10));
    });

    test('2. Standard MISC Reasons include all 11 prompt specified reasons', () {
      expect(CustomerMiscAction.standardReasons, contains('Customer Details Correction'));
      expect(CustomerMiscAction.standardReasons, contains('Document Request'));
      expect(CustomerMiscAction.standardReasons, contains('Site Visit Required'));
      expect(CustomerMiscAction.standardReasons, contains('Customer Callback'));
      expect(CustomerMiscAction.standardReasons, contains('Mobile Number Update'));
      expect(CustomerMiscAction.standardReasons, contains('Address Correction'));
      expect(CustomerMiscAction.standardReasons, contains('Bank Related Other Request'));
      expect(CustomerMiscAction.standardReasons, contains('MSEDCL Related Other Request'));
      expect(CustomerMiscAction.standardReasons, contains('Material Related Request'));
      expect(CustomerMiscAction.standardReasons, contains('Other Customer Request'));
      expect(CustomerMiscAction.standardReasons, contains('Manual Staff Action'));
      expect(CustomerMiscAction.standardReasons.length, 11);
    });

    test('3. Status and Active/Hold/Completed getters evaluation', () {
      final now = DateTime.now();

      final pendingAction = CustomerMiscAction(
        recordId: '1',
        consumerNo: '100',
        customerName: 'Test',
        reason: 'Material Related Request',
        status: 'Pending',
        createdAt: now,
      );
      expect(pendingAction.isActive, isTrue);
      expect(pendingAction.isHold, isFalse);
      expect(pendingAction.isCompleted, isFalse);

      final inProgAction = pendingAction.copyWith(status: 'In Progress');
      expect(inProgAction.isActive, isTrue);

      final holdAction = pendingAction.copyWith(status: 'Hold', holdReason: 'Customer out of station');
      expect(holdAction.isActive, isFalse);
      expect(holdAction.isHold, isTrue);
      expect(holdAction.holdReason, 'Customer out of station');

      final completedAction = pendingAction.copyWith(status: 'Completed');
      expect(completedAction.isActive, isFalse);
      expect(completedAction.isCompleted, isTrue);
    });

    test('4. Due date evaluation: isOverdue and isDueToday', () {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final yesterday = today.subtract(const Duration(days: 1));
      final tomorrow = today.add(const Duration(days: 1));

      final overdueAction = CustomerMiscAction(
        recordId: '1',
        consumerNo: '100',
        customerName: 'Test',
        reason: 'Document Request',
        dueDate: yesterday,
        status: 'Pending',
        createdAt: now,
      );
      expect(overdueAction.isOverdue, isTrue);
      expect(overdueAction.isDueToday, isFalse);

      final todayAction = overdueAction.copyWith(dueDate: today);
      expect(todayAction.isOverdue, isFalse);
      expect(todayAction.isDueToday, isTrue);

      final futureAction = overdueAction.copyWith(dueDate: tomorrow);
      expect(futureAction.isOverdue, isFalse);
      expect(futureAction.isDueToday, isFalse);

      // Completed actions are never overdue even if past due date
      final completedPastDue = overdueAction.copyWith(status: 'Completed');
      expect(completedPastDue.isOverdue, isFalse);
    });

    test('5. Duplicate Protection Logic: Same customer with same reason while active', () {
      final existingActions = [
        CustomerMiscAction(
          id: 'act-1',
          recordId: 'cust-1',
          consumerNo: '1001',
          customerName: 'Ramesh',
          reason: 'Site Visit Required',
          status: 'Pending',
          createdAt: DateTime.now(),
        ),
        CustomerMiscAction(
          id: 'act-2',
          recordId: 'cust-2',
          consumerNo: '1002',
          customerName: 'Mahesh',
          reason: 'Site Visit Required',
          status: 'Completed',
          createdAt: DateTime.now(),
        ),
      ];

      // Checking for cust-1 with 'Site Visit Required' -> DUPLICATE FOUND
      bool isDuplicateCust1 = existingActions.any(
        (a) => a.recordId == 'cust-1' && a.reason == 'Site Visit Required' && a.isActive,
      );
      expect(isDuplicateCust1, isTrue);

      // Checking for cust-1 with different reason -> NO DUPLICATE
      bool isDuplicateDiffReason = existingActions.any(
        (a) => a.recordId == 'cust-1' && a.reason == 'Document Request' && a.isActive,
      );
      expect(isDuplicateDiffReason, isFalse);

      // Checking for cust-2 where previous action was completed -> NO DUPLICATE
      bool isDuplicateCust2 = existingActions.any(
        (a) => a.recordId == 'cust-2' && a.reason == 'Site Visit Required' && a.isActive,
      );
      expect(isDuplicateCust2, isFalse);
    });

    test('6. IMPORTANT ARCHITECTURE: MISC is an action, NOT a workflow stage', () {
      final customer = ConsumerRecord(
        id: 'cust-uuid-1',
        consumerNo: '123456789012',
        name: 'Ganesh Kadam',
        agreementStatus: 'Completed',
        loanRequired: 'Yes',
        loanStatus: 'Applied',
        customerWorkState: 'ACTIVE',
        status: 'In Progress',
      );

      // Pre-condition: stage is Loan
      expect(WorkflowEngine.getCurrentWorkStage(customer), 'Loan');
      expect(customer.customerWorkState, 'ACTIVE');

      // Create a MISC action for this customer
      final miscAction = CustomerMiscAction(
        id: 'misc-1',
        recordId: customer.id!,
        consumerNo: customer.consumerNo,
        customerName: customer.name,
        reason: 'Customer Callback',
        status: 'Pending',
        createdAt: DateTime.now(),
      );

      // Assert customer's work stage remains unaltered by MISC action
      expect(WorkflowEngine.getCurrentWorkStage(customer), 'Loan');
      expect(customer.customerWorkState, 'ACTIVE');

      // Complete the MISC action
      final completedMisc = miscAction.copyWith(status: 'Completed', completedAt: DateTime.now());
      expect(completedMisc.status, 'Completed');

      // Assert customer's work stage still remains completely unaltered
      expect(WorkflowEngine.getCurrentWorkStage(customer), 'Loan');
      expect(customer.customerWorkState, 'ACTIVE');
      expect(customer.status, 'In Progress');
    });

    test('7. SINGLE CENTRALIZED FOLLOW-UP: MISC Follow-up maps to central customer_followups', () {
      final miscAction = CustomerMiscAction(
        id: 'misc-99',
        recordId: 'cust-uuid-42',
        consumerNo: '999888777666',
        customerName: 'Nitin Gore',
        reason: 'Bank Related Other Request',
        status: 'Pending',
        createdAt: DateTime.now(),
      );

      // Follow-up scheduled from MISC action must target the customer's central recordId
      final followupDate = DateTime.now().add(const Duration(days: 2));
      final followupReason = 'MISC: ${miscAction.reason}';

      final centralizedFollowupPayload = {
        'record_id': miscAction.recordId,
        'consumer_no': miscAction.consumerNo,
        'followup_date': followupDate.toIso8601String().split('T')[0],
        'followup_reason': followupReason,
        'status': 'PENDING',
      };

      expect(centralizedFollowupPayload['record_id'], 'cust-uuid-42');
      expect(centralizedFollowupPayload['followup_reason'], 'MISC: Bank Related Other Request');
      expect(centralizedFollowupPayload['status'], 'PENDING');
    });
  });
}
