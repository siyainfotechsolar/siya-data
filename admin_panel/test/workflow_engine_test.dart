import 'package:flutter_test/flutter_test.dart';
import 'package:admin_panel/models/consumer_record.dart';
import 'package:admin_panel/services/workflow_engine.dart';

void main() {
  group('Strict 1-by-1 WorkflowEngine Tests', () {
    test('1-by-1 Progression: Application -> Agreement -> Loan -> Installation -> RTS -> Subsidy -> Completed', () {
      // Step 1: New record (Application stage)
      var rec = ConsumerRecord(
        consumerNo: '1001',
        name: 'Test Customer',
        applicationStatus: 'Submitted',
        agreementStatus: 'Pending',
        loanRequired: 'Yes',
        loanStatus: 'Not Started',
      );
      expect(WorkflowEngine.getCurrentWorkStage(rec), equals('Agreement'));

      var states = WorkflowEngine.getStageStates(rec);
      expect(states[WorkflowStage.application]!.state, equals(StageState.completed));
      expect(states[WorkflowStage.agreement]!.state, equals(StageState.active));
      expect(states[WorkflowStage.loan]!.state, equals(StageState.locked));
      expect(states[WorkflowStage.installation]!.state, equals(StageState.locked));
      expect(states[WorkflowStage.loan]!.lockReason, contains('🔒 Complete Agreement first'));

      // Step 2: Agreement Verified -> Loan unlocked (Loan Required = YES)
      rec = rec.copyWith(
        agreementStatus: 'Verified',
        loanRequired: 'Yes',
        loanStatus: 'Under Process',
      );
      expect(WorkflowEngine.getCurrentWorkStage(rec), equals('Loan'));
      states = WorkflowEngine.getStageStates(rec);
      expect(states[WorkflowStage.agreement]!.state, equals(StageState.completed));
      expect(states[WorkflowStage.loan]!.state, equals(StageState.active));
      expect(states[WorkflowStage.installation]!.state, equals(StageState.locked));
      expect(states[WorkflowStage.installation]!.lockReason, contains('🔒 Get Loan Approved first'));

      // Step 3: Loan Completed -> Installation unlocked
      rec = rec.copyWith(
        loanStatus: 'Completed',
        loanSubStage: '2nd Installment Completed',
        installationStatus: 'Wiring Pending',
      );
      expect(WorkflowEngine.getCurrentWorkStage(rec), equals('Installation'));
      states = WorkflowEngine.getStageStates(rec);
      expect(states[WorkflowStage.loan]!.state, equals(StageState.completed));
      expect(states[WorkflowStage.installation]!.state, equals(StageState.active));
      expect(states[WorkflowStage.rts]!.state, equals(StageState.locked));
      expect(states[WorkflowStage.rts]!.lockReason, contains('🔒 Complete Installation first'));

      // Step 4: Installation Completed -> RTS unlocked
      rec = rec.copyWith(
        installationStatus: 'Installation Completed',
        rtsStatus: 'Inspection Pending',
      );
      expect(WorkflowEngine.getCurrentWorkStage(rec), equals('RTS'));
      states = WorkflowEngine.getStageStates(rec);
      expect(states[WorkflowStage.installation]!.state, equals(StageState.completed));
      expect(states[WorkflowStage.rts]!.state, equals(StageState.active));
      expect(states[WorkflowStage.subsidy]!.state, equals(StageState.locked));

      // Step 5: RTS Completed -> Subsidy unlocked
      rec = rec.copyWith(
        rtsStatus: 'Completed',
        subsidyStatus: 'Applied',
      );
      expect(WorkflowEngine.getCurrentWorkStage(rec), equals('Subsidy'));
      states = WorkflowEngine.getStageStates(rec);
      expect(states[WorkflowStage.rts]!.state, equals(StageState.completed));
      expect(states[WorkflowStage.subsidy]!.state, equals(StageState.active));

      // Step 6: Subsidy Received -> Completed
      rec = rec.copyWith(
        subsidyStatus: 'Received',
      );
      expect(WorkflowEngine.getCurrentWorkStage(rec), equals('Completed'));
      states = WorkflowEngine.getStageStates(rec);
      expect(states[WorkflowStage.subsidy]!.state, equals(StageState.completed));
      expect(states[WorkflowStage.completed]!.state, equals(StageState.completed));
    });

    test('Loan Required = NO Exception: Bypasses Loan and unlocks Installation after Agreement', () {
      var rec = ConsumerRecord(
        consumerNo: '1002',
        name: 'Cash Customer',
        agreementStatus: 'Verified',
        loanRequired: 'No',
        installationStatus: 'Not Started',
      );

      expect(WorkflowEngine.isLoanRequired(rec), isFalse);
      expect(WorkflowEngine.isLoanCompleted(rec), isTrue); // Skipped is satisfied
      expect(WorkflowEngine.getCurrentWorkStage(rec), equals('Installation'));

      final states = WorkflowEngine.getStageStates(rec);
      expect(states[WorkflowStage.loan]!.state, equals(StageState.skipped));
      expect(states[WorkflowStage.loan]!.currentStatus, equals('Not Required'));
      expect(states[WorkflowStage.installation]!.state, equals(StageState.active));
      expect(states[WorkflowStage.installation]!.isUnlocked, isTrue);
    });

    test('Single-stage update validation: Prevents stage jumping', () {
      final rec = ConsumerRecord(
        consumerNo: '1003',
        name: 'Pending Customer',
        agreementStatus: 'Pending',
        loanRequired: 'Yes',
        loanStatus: 'Not Started',
        installationStatus: 'Not Started',
      );

      // Attempting to jump directly to Installation Completed
      final errors = WorkflowEngine.validateStageProgression(
        rec,
        newInstallationStatus: 'Installation Completed',
      );

      expect(errors.isNotEmpty, isTrue);
      expect(errors.any((e) => e.contains('Cannot complete Installation')), isTrue);
    });

    test('Owner Override unlocks all future stages for editing', () {
      final rec = ConsumerRecord(
        consumerNo: '1004',
        name: 'Locked Customer',
        agreementStatus: 'Pending',
      );

      final normalStates = WorkflowEngine.getStageStates(rec, isOwnerOverride: false);
      expect(normalStates[WorkflowStage.installation]!.isUnlocked, isFalse);

      final ownerStates = WorkflowEngine.getStageStates(rec, isOwnerOverride: true);
      expect(ownerStates[WorkflowStage.installation]!.isUnlocked, isTrue);
    });

    test('Smart Loan Sub-Stages & Bank Rejection Loop', () {
      // 1. Agreement completed, Loan Applied
      var rec = ConsumerRecord(
        consumerNo: '1005',
        name: 'Bank Loan Customer',
        agreementStatus: 'Verified',
        loanRequired: 'Yes',
        loanSubStage: 'Loan Applied',
      );

      expect(WorkflowEngine.getCurrentWorkStage(rec), equals('Loan'));
      expect(WorkflowEngine.getActionRequired(rec), equals('Loan Action Required'));
      expect(WorkflowEngine.getNextAction(rec), equals('Prepare / Submit Loan File'));
      expect(WorkflowEngine.isLoanCompleted(rec), isFalse);

      // 2. File at Bank
      rec = rec.copyWith(loanSubStage: 'File at Bank');
      expect(WorkflowEngine.getActionRequired(rec), equals('Bank Follow-up'));
      expect(WorkflowEngine.getNextAction(rec), equals('Check Bank Status'));
      expect(WorkflowEngine.getStageStates(rec)[WorkflowStage.installation]!.isUnlocked, isFalse);

      // 3. Bank Rejects Loan -> Stage: Loan Rejected
      rec = rec.copyWith(
        loanSubStage: 'Loan Rejected',
        rejectionReason: 'Bank document issue',
        bankRemarks: 'Invalid income certificate',
        correctionRequired: 'Upload corrected document',
      );
      expect(WorkflowEngine.getCurrentWorkStage(rec), equals('Loan'));
      expect(WorkflowEngine.getActionRequired(rec), equals('Loan Correction'));
      expect(WorkflowEngine.getNextAction(rec), equals('Correct Issue'));
      // Installation, RTS, Subsidy MUST remain LOCKED!
      var states = WorkflowEngine.getStageStates(rec);
      expect(states[WorkflowStage.installation]!.isUnlocked, isFalse);
      expect(states[WorkflowStage.rts]!.isUnlocked, isFalse);
      expect(states[WorkflowStage.subsidy]!.isUnlocked, isFalse);

      // 4. Correction Required
      rec = rec.copyWith(loanSubStage: 'Correction Required');
      expect(WorkflowEngine.getActionRequired(rec), equals('Correct Loan File'));
      expect(WorkflowEngine.getNextAction(rec), equals('Prepare Corrected File'));

      // 5. Re-Apply Loan (Attempt #1)
      rec = rec.copyWith(
        loanSubStage: 'Loan Applied',
        loanReapplyCount: 1,
        loanAttempts: [
          {
            'attempt_number': 1,
            'reapply_date': '2026-08-15T10:00:00Z',
            'previous_rejection_reason': 'Bank document issue',
          }
        ],
      );
      expect(rec.loanReapplyCount, equals(1));
      expect(rec.loanAttempts.length, equals(1));
      expect(WorkflowEngine.getCurrentWorkStage(rec), equals('Loan'));

      // 6. File at Bank again -> Loan Approved
      rec = rec.copyWith(loanSubStage: 'Loan Approved');
      expect(WorkflowEngine.getCurrentWorkStage(rec), equals('Loan'));
      expect(WorkflowEngine.getActionRequired(rec), equals('1st Installment'));
      expect(WorkflowEngine.getNextAction(rec), equals('Process 1st Installment'));

      // 7. 1st Installment -> 2nd Installment
      rec = rec.copyWith(loanSubStage: '1st Installment');
      expect(WorkflowEngine.getActionRequired(rec), equals('1st Installment'));

      rec = rec.copyWith(loanSubStage: '2nd Installment');
      expect(WorkflowEngine.getActionRequired(rec), equals('2nd Installment'));

      // 8. 2nd Installment Completed -> Installation Unlocked!
      rec = rec.copyWith(loanSubStage: '2nd Installment Completed');
      expect(WorkflowEngine.isLoanCompleted(rec), isTrue);
      expect(WorkflowEngine.getCurrentWorkStage(rec), equals('Installation'));
      states = WorkflowEngine.getStageStates(rec);
      expect(states[WorkflowStage.installation]!.isUnlocked, isTrue);
    });
  });
}
