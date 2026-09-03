import 'package:flutter_test/flutter_test.dart';
import 'package:admin_panel/models/consumer_record.dart';
import 'package:admin_panel/models/record_diff.dart';

void main() {
  group('Customer Solar Workflow & Dependency Guard Tests', () {
    test('Rule 1: Loan Required = YES requires Loan Approved before Installation Completed', () {
      final recordPendingLoan = ConsumerRecord(
        consumerNo: '1001',
        name: 'Ramesh Patil',
        loanRequired: 'Yes',
        loanStatus: 'Pending',
        installationStatus: 'Not Started',
      );

      // Loan is not approved yet -> should NOT be allowed to complete installation
      expect(recordPendingLoan.isLoanSatisfied, isFalse);
      expect(recordPendingLoan.canCompleteInstallation, isFalse);

      final recordApprovedLoan = recordPendingLoan.copyWith(loanStatus: 'Approved');
      expect(recordApprovedLoan.isLoanSatisfied, isTrue);
      expect(recordApprovedLoan.canCompleteInstallation, isTrue);
    });

    test('Rule 2: Loan Required = NO bypasses loan and immediately allows installation', () {
      final recordCashCustomer = ConsumerRecord(
        consumerNo: '1002',
        name: 'Suresh Shinde',
        loanRequired: 'No',
        loanStatus: 'Not Required',
        installationStatus: 'Scheduled',
      );

      expect(recordCashCustomer.isLoanSatisfied, isTrue);
      expect(recordCashCustomer.canCompleteInstallation, isTrue);
    });

    test('Rule 3: RTS Net Meter cannot proceed until installation is completed', () {
      final recordInstalling = ConsumerRecord(
        consumerNo: '1003',
        name: 'Anil Jadhav',
        installationStatus: 'Panel Pending',
      );

      expect(recordInstalling.canStartRts, isFalse);

      final recordInstalled = recordInstalling.copyWith(
        installationStatus: 'Installation Completed',
      );
      expect(recordInstalled.canStartRts, isTrue);
    });

    test('Rule 4: Subsidy cannot proceed until RTS is completed', () {
      final recordRtsPending = ConsumerRecord(
        consumerNo: '1004',
        name: 'Sunita Deshmukh',
        installationStatus: 'Installation Completed',
        rtsStatus: 'Meter Pending',
      );

      expect(recordRtsPending.canStartSubsidy, isFalse);

      final recordRtsDone = recordRtsPending.copyWith(
        rtsStatus: 'Completed',
      );
      expect(recordRtsDone.canStartSubsidy, isTrue);
    });

    test('Rule 5: Overall stage progression resolves correctly through lifecycle', () {
      // Step 1: Application
      var record = ConsumerRecord(
        consumerNo: '1005',
        name: 'Vikas Kadam',
        agreementStatus: 'Pending',
      );
      expect(record.overallStage, equals('Agreement'));

      // Step 2: Agreement Verified, Loan Pending
      record = record.copyWith(
        agreementStatus: 'Verified',
        loanRequired: 'Yes',
        loanStatus: 'Under Process',
      );
      expect(record.overallStage, equals('Loan'));

      // Step 3: Loan Approved, Installation in progress
      record = record.copyWith(
        loanStatus: 'Approved',
        installationStatus: 'Wiring Pending',
      );
      expect(record.overallStage, equals('Installation'));

      // Step 4: Installation Completed, RTS in progress
      record = record.copyWith(
        installationStatus: 'Installation Completed',
        rtsStatus: 'Inspection Pending',
      );
      expect(record.overallStage, equals('RTS'));

      // Step 5: RTS Completed, Subsidy in progress
      record = record.copyWith(
        rtsStatus: 'Completed',
        subsidyStatus: 'Under Process',
      );
      expect(record.overallStage, equals('Subsidy'));

      // Step 6: Subsidy Received -> 100% Completed
      record = record.copyWith(
        subsidyStatus: 'Received',
      );
      expect(record.overallStage, equals('Completed'));
      expect(record.isFullyCompleted, isTrue);
    });

    test('Rule 6: Excel Import Sparse Payload updates only mapped workflow columns', () {
      final existing = ConsumerRecord(
        id: 'rec-1',
        consumerNo: '1006',
        name: 'Existing Customer',
        loanRequired: 'Yes',
        loanStatus: 'Pending',
        installationStatus: 'Not Started',
        rtsStatus: 'Not Started',
      );

      final incoming = ConsumerRecord(
        consumerNo: '1006',
        name: 'Existing Customer',
        loanRequired: 'Yes',
        loanStatus: 'Approved', // Mapped & changed
        installationStatus: 'Installation Completed', // Skipped in mapping
        rtsStatus: 'Completed', // Skipped in mapping
      );

      final diff = RecordDiff(
        existingRecord: existing,
        incomingRecord: incoming,
        changedFields: [],
      );

      // Only 'loan_status' is mapped/allowed
      final payload = diff.buildUpdatePayload(
        allowedFieldKeys: {'loan_status'},
      );

      expect(payload.containsKey('loan_status'), isTrue);
      expect(payload['loan_status'], equals('Approved'));
      expect(payload.containsKey('installation_status'), isFalse);
      expect(payload.containsKey('rts_status'), isFalse);
    });
  });
}
