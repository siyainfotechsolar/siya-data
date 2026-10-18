import 'package:flutter_test/flutter_test.dart';
import 'package:admin_panel/models/agent_master.dart';
import 'package:admin_panel/models/commission_record.dart';
import 'package:admin_panel/services/commission_service.dart';

void main() {
  group('Commission Agent Module & Bulk Manual Entry Tests', () {
    test('1. Multi-row entry & manual commission amount calculation', () {
      final drafts = [
        CommissionDraftItem(
          localId: '1',
          agentName: 'Sunil Patil',
          customerName: 'DILIP PATIL',
          consumerNo: '012345678901',
          solarCapacity: 3.0,
          commissionDate: DateTime(2026, 10, 15),
          commissionAmount: 5000.0, // Manually entered
        ),
        CommissionDraftItem(
          localId: '2',
          agentName: 'Sunil Patil', // Same agent for multiple customers
          customerName: 'NAMDEO MALI',
          consumerNo: '012345678902',
          solarCapacity: 5.0, // Different kW
          commissionDate: DateTime(2026, 10, 15),
          commissionAmount: 7500.0, // Different manual amount, NOT formula
        ),
        CommissionDraftItem(
          localId: '3',
          agentName: 'Ramesh Shinde',
          customerName: 'RAMESH JADHAV',
          consumerNo: '012345678903',
          solarCapacity: 3.0, // Same 3kW as row 1, but different manual amount
          commissionDate: DateTime(2026, 10, 15),
          commissionAmount: 6200.0, // Distinct manual rate negotiated
        ),
      ];

      // Verify each row is valid
      for (final draft in drafts) {
        expect(draft.isValid, isTrue);
      }

      // Summary total is strict sum of manual amounts, never auto-calculated
      final totalSum = drafts.fold<double>(0.0, (sum, d) => sum + (d.commissionAmount ?? 0.0));
      expect(totalSum, equals(18700.0));

      final uniqueAgents = drafts.map((d) => d.agentName).toSet().length;
      expect(uniqueAgents, equals(2));

      final uniqueCustomers = drafts.map((d) => d.customerName).toSet().length;
      expect(uniqueCustomers, equals(3));
    });

    test('2. Row validation: required fields and invalid row highlighting', () {
      final invalidRow1 = CommissionDraftItem(
        localId: 'inv-1',
        agentName: '', // Missing agent
        customerName: 'Valid Customer',
        commissionAmount: 5000.0,
      );
      expect(invalidRow1.isValid, isFalse);
      expect(invalidRow1.validate(), contains('Select an agent'));

      final invalidRow2 = CommissionDraftItem(
        localId: 'inv-2',
        agentName: 'Sunil Patil',
        customerName: '', // Missing customer
        commissionAmount: 5000.0,
      );
      expect(invalidRow2.isValid, isFalse);
      expect(invalidRow2.validate(), contains('Customer name is required'));

      final invalidRow3 = CommissionDraftItem(
        localId: 'inv-3',
        agentName: 'Sunil Patil',
        customerName: 'Valid Customer',
        commissionAmount: null, // Missing amount
      );
      expect(invalidRow3.isValid, isFalse);
      expect(invalidRow3.validate(), contains('Commission amount is required'));

      final invalidRow4 = CommissionDraftItem(
        localId: 'inv-4',
        agentName: 'Sunil Patil',
        customerName: 'Valid Customer',
        commissionAmount: -100.0, // Invalid monetary amount
      );
      expect(invalidRow4.isValid, isFalse);
      expect(invalidRow4.validate(), contains('Amount must be greater than ₹0'));

      // A valid row alongside invalid rows is NOT discarded
      final validRow = CommissionDraftItem(
        localId: 'val-1',
        agentName: 'Sunil Patil',
        customerName: 'Valid Customer',
        commissionAmount: 4000.0,
      );
      expect(validRow.isValid, isTrue);
    });

    test('3. Duplicate prevention: detects repeated agent, customer & period', () async {
      final batch = [
        CommissionDraftItem(
          localId: 'row-a',
          agentName: 'Ganesh Pawar',
          customerName: 'Suresh Patil',
          commissionDate: DateTime(2026, 10, 10),
          commissionAmount: 5000.0,
        ),
        CommissionDraftItem(
          localId: 'row-b',
          agentName: 'Ganesh Pawar',
          customerName: 'Suresh Patil', // Same agent and customer in same month
          commissionDate: DateTime(2026, 10, 20),
          commissionAmount: 5000.0,
        ),
      ];

      final warnings = await CommissionService.checkBatchDuplicates(batch);
      expect(warnings.isNotEmpty, isTrue);
      expect(warnings.first.reason, contains('Repeated entry in this batch'));
    });

    test('4. Bulk Save: unique entry numbers, pending approval status & partial failures', () async {
      final drafts = [
        CommissionDraftItem(
          localId: 'save-1',
          agentName: 'Sunil Patil',
          customerName: 'Test Customer A',
          consumerNo: '111111111111',
          commissionDate: DateTime.now(),
          commissionAmount: 3000.0,
        ),
        CommissionDraftItem(
          localId: 'save-2',
          agentName: 'Sunil Patil',
          customerName: 'Test Customer B',
          consumerNo: '222222222222',
          commissionDate: DateTime.now(),
          commissionAmount: 4500.0,
        ),
        CommissionDraftItem(
          localId: 'save-3-invalid',
          agentName: '', // Invalid row
          customerName: 'Incomplete Row',
          commissionAmount: null,
        ),
      ];

      final result = await CommissionService.saveBulkCommissionEntries(drafts: drafts);

      // Verify partial failure handling: 2 saved, 1 failed
      expect(result.totalSaved, equals(2));
      expect(result.totalFailed, equals(1));
      expect(result.failedItems.first.localId, equals('save-3-invalid'));

      // Saved rows get marked with isSaved and unique entry numbers
      for (final item in result.savedItems) {
        expect(item.isSaved, isTrue);
        expect(item.savedEntryNumber, isNotNull);
        expect(item.savedEntryNumber, startsWith('SIYA-COM-'));
      }

      // Initial status is Pending Approval, never marked paid automatically
      for (final record in result.createdRecords) {
        expect(record.status, equals(CommissionStatus.pendingApproval));
        expect(record.paidAmount, equals(0.0));
        expect(record.isPendingApproval, isTrue);
        expect(record.isFullyPaid, isFalse);
      }
    });

    test('5. Approval Workflow: individual and bulk approval', () async {
      final record = CommissionRecord(
        id: 'comm-approve-test',
        entryNumber: 'SIYA-COM-2026-9001',
        agentName: 'Vikas More',
        customerName: 'Anil Sonawane',
        commissionDate: DateTime.now(),
        commissionAmount: 8000.0,
        status: CommissionStatus.pendingApproval,
      );

      expect(record.isPendingApproval, isTrue);
      expect(record.isApproved, isFalse);

      final approvedRecord = record.copyWith(
        status: CommissionStatus.approved,
        approvedAmount: 8000.0,
        approvedAt: DateTime.now(),
      );

      expect(approvedRecord.isApproved, isTrue);
      expect(approvedRecord.isPendingApproval, isFalse);
      expect(approvedRecord.effectiveApprovedAmount, equals(8000.0));
      expect(approvedRecord.pendingAmount, equals(8000.0)); // No payments yet
    });

    test('6. Payment Tracking: pending balance, partial payments, and full settlement', () {
      final comm = CommissionRecord(
        id: 'comm-pay-test',
        entryNumber: 'SIYA-COM-2026-9002',
        agentName: 'Sunil Patil',
        customerName: 'Nitin Chaudhari',
        commissionDate: DateTime.now(),
        commissionAmount: 10000.0,
        approvedAmount: 10000.0,
        paidAmount: 0.0,
        status: CommissionStatus.approved,
      );

      // Initial state: Pending Amount = 10,000 - 0 = 10,000
      expect(comm.pendingAmount, equals(10000.0));
      expect(comm.isFullyPaid, isFalse);
      expect(comm.isPartiallyPaid, isFalse);

      // 1st Installment payment: 4,000
      final afterFirstPayment = comm.copyWith(
        paidAmount: 4000.0,
        status: CommissionStatus.partiallyPaid,
      );
      // Pending Amount = Approved (10,000) - Paid (4,000) = 6,000
      expect(afterFirstPayment.pendingAmount, equals(6000.0));
      expect(afterFirstPayment.isPartiallyPaid, isTrue);
      expect(afterFirstPayment.isFullyPaid, isFalse);

      // 2nd Installment payment: 6,000 (Remaining balance)
      final afterSecondPayment = afterFirstPayment.copyWith(
        paidAmount: 10000.0,
        status: CommissionStatus.paid,
      );
      // Pending Amount = Approved (10,000) - Paid (10,000) = 0
      expect(afterSecondPayment.pendingAmount, equals(0.0));
      expect(afterSecondPayment.isFullyPaid, isTrue);
      expect(afterSecondPayment.isPartiallyPaid, isFalse);
    });

    test('7. Optional Bulk Import: template generation and parsing', () {
      final templateCsv = CommissionService.generateImportTemplateCsv();
      expect(templateCsv, contains('Agent Name,Customer Name,Consumer Number,Solar Capacity,Commission Date,Commission Amount,Remarks'));
      expect(templateCsv, contains('Sunil Patil'));

      final rawData = [
        ['Agent Name', 'Customer Name', 'Consumer Number', 'Solar Capacity', 'Commission Date', 'Commission Amount', 'Remarks'],
        ['Sunil Patil', 'Rahul Shinde', '098765432101', '4.0', '2026-10-18', '6000', 'Rooftop unit'],
        ['Ramesh Shinde', 'Kailas Patil', '098765432102', '5.0', '2026-10-18', '7500', 'Agri pump solar'],
      ];

      final agents = [
        const AgentMaster(id: 'ag-1', name: 'Sunil Patil'),
        const AgentMaster(id: 'ag-2', name: 'Ramesh Shinde'),
      ];

      final parsed = CommissionService.parseImportRows(rawData, agents);
      expect(parsed.length, equals(2));
      expect(parsed[0].agentName, equals('Sunil Patil'));
      expect(parsed[0].agentId, equals('ag-1'));
      expect(parsed[0].customerName, equals('Rahul Shinde'));
      expect(parsed[0].commissionAmount, equals(6000.0));
      expect(parsed[0].solarCapacity, equals(4.0));

      expect(parsed[1].agentName, equals('Ramesh Shinde'));
      expect(parsed[1].agentId, equals('ag-2'));
      expect(parsed[1].commissionAmount, equals(7500.0));
    });
  });
}
