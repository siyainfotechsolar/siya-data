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

      // Step 3: Loan Approved -> Installation unlocked
      rec = rec.copyWith(
        loanStatus: 'Approved',
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
  });
}
