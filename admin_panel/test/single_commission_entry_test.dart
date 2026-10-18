import 'package:flutter_test/flutter_test.dart';
import 'package:admin_panel/models/commission_record.dart';
import 'package:admin_panel/services/commission_service.dart';

void main() {
  group('Commission Agent Module - One by One (Single) Entry Tests', () {
    test('1. Save single commission entry with valid data', () async {
      final record = await CommissionService.saveSingleCommissionEntry(
        agentName: 'Sunil Patil',
        agentId: 'agent-1',
        customerName: 'KISHOR CHAUDHARI',
        customerId: 'cust-101',
        consumerNo: '012345678910',
        solarCapacity: 4.0,
        commissionDate: DateTime(2026, 10, 18),
        commissionAmount: 6000.0,
        remarks: 'Direct survey referral',
      );

      expect(record.agentName, equals('Sunil Patil'));
      expect(record.customerName, equals('KISHOR CHAUDHARI'));
      expect(record.consumerNo, equals('012345678910'));
      expect(record.solarCapacity, equals(4.0));
      expect(record.commissionAmount, equals(6000.0));
      expect(record.status, equals(CommissionStatus.pendingApproval));
      expect(record.paidAmount, equals(0.0));
      expect(record.entryNumber, startsWith('SIYA-COM-'));
      expect(record.isPendingApproval, isTrue);
    });

    test('2. Direct pre-approval workflow on single entry creation', () async {
      final record = await CommissionService.saveSingleCommissionEntry(
        agentName: 'Ramesh Shinde',
        agentId: 'agent-2',
        customerName: 'ANIL MAHAJAN',
        consumerNo: '012345678911',
        solarCapacity: 3.0,
        commissionDate: DateTime(2026, 10, 18),
        commissionAmount: 4500.0,
        approvedAmount: 4500.0,
        status: CommissionStatus.approved,
        remarks: 'Admin pre-approved',
      );

      expect(record.status, equals(CommissionStatus.approved));
      expect(record.approvedAmount, equals(4500.0));
      expect(record.isApproved, isTrue);
      expect(record.pendingAmount, equals(4500.0));
    });

    test('3. Field validation: agentName, customerName, and commissionAmount', () async {
      // Missing Agent Name
      expect(
        () => CommissionService.saveSingleCommissionEntry(
          agentName: '',
          customerName: 'SURESH PATIL',
          commissionAmount: 5000.0,
        ),
        throwsA(isA<ArgumentError>()),
      );

      // Missing Customer Name
      expect(
        () => CommissionService.saveSingleCommissionEntry(
          agentName: 'Sunil Patil',
          customerName: '   ',
          commissionAmount: 5000.0,
        ),
        throwsA(isA<ArgumentError>()),
      );

      // Invalid Amount (zero or negative)
      expect(
        () => CommissionService.saveSingleCommissionEntry(
          agentName: 'Sunil Patil',
          customerName: 'SURESH PATIL',
          commissionAmount: 0.0,
        ),
        throwsA(isA<ArgumentError>()),
      );

      expect(
        () => CommissionService.saveSingleCommissionEntry(
          agentName: 'Sunil Patil',
          customerName: 'SURESH PATIL',
          commissionAmount: -100.0,
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('4. Rate per kW calculation assistant formula', () {
      const capacity = 3.5;
      const ratePerKw = 1500.0;
      final calculated = capacity * ratePerKw;
      expect(calculated, equals(5250.0));

      const negotiatedCapacity = 5.0;
      const negotiatedRate = 1200.0;
      final negotiatedTotal = negotiatedCapacity * negotiatedRate;
      expect(negotiatedTotal, equals(6000.0));
    });

    test('5. Duplicate detection for single entry', () async {
      // First save an entry
      final testDate = DateTime(2026, 10, 20);
      await CommissionService.saveSingleCommissionEntry(
        agentName: 'Vikas More',
        customerName: 'MUKESH SHARMA',
        consumerNo: '099988877766',
        commissionDate: testDate,
        commissionAmount: 7000.0,
      );

      // Check duplicate with same agent, customer, and month
      final warning = await CommissionService.checkSingleDuplicate(
        agentName: 'Vikas More',
        customerName: 'MUKESH SHARMA',
        consumerNo: '099988877766',
        commissionDate: testDate,
      );

      expect(warning, isNotNull);
      expect(warning!.existingEntryNumber, isNotNull);

      // Check with different customer should have no warning
      final noWarning = await CommissionService.checkSingleDuplicate(
        agentName: 'Vikas More',
        customerName: 'DIFFERENT CUSTOMER',
        commissionDate: testDate,
      );
      expect(noWarning, isNull);
    });

    test('6. Sequential "Save & Add Another" flow saves multiple distinct entries', () async {
      final entries = <CommissionRecord>[];

      // Entry 1
      final e1 = await CommissionService.saveSingleCommissionEntry(
        agentName: 'Ganesh Pawar',
        customerName: 'CUSTOMER ONE',
        consumerNo: '111111111111',
        solarCapacity: 3.0,
        commissionDate: DateTime(2026, 10, 18),
        commissionAmount: 4500.0,
      );
      entries.add(e1);

      // Entry 2 (Sequential next entry for same agent)
      final e2 = await CommissionService.saveSingleCommissionEntry(
        agentName: 'Ganesh Pawar',
        customerName: 'CUSTOMER TWO',
        consumerNo: '222222222222',
        solarCapacity: 4.0,
        commissionDate: DateTime(2026, 10, 18),
        commissionAmount: 6000.0,
      );
      entries.add(e2);

      // Entry 3
      final e3 = await CommissionService.saveSingleCommissionEntry(
        agentName: 'Ganesh Pawar',
        customerName: 'CUSTOMER THREE',
        consumerNo: '333333333333',
        solarCapacity: 5.0,
        commissionDate: DateTime(2026, 10, 18),
        commissionAmount: 7500.0,
      );
      entries.add(e3);

      expect(entries.length, equals(3));
      // All have distinct unique entry numbers
      final uniqueEntryNumbers = entries.map((e) => e.entryNumber).toSet();
      expect(uniqueEntryNumbers.length, equals(3));

      // Total commission recorded across the 3 sequential entries
      final totalRecorded = entries.fold<double>(0.0, (s, e) => s + e.commissionAmount);
      expect(totalRecorded, equals(18000.0));
    });
  });
}
