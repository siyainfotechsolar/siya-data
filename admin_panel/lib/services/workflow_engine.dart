import '../models/consumer_record.dart';

enum WorkflowStage {
  application,
  agreement,
  loan,
  installation,
  rts,
  subsidy,
  completed,
}

enum StageState {
  completed,
  active,
  locked,
  skipped,
}

class WorkflowStageInfo {
  final WorkflowStage stage;
  final String label;
  final StageState state;
  final String lockReason;
  final String currentStatus;
  final bool isUnlocked;

  const WorkflowStageInfo({
    required this.stage,
    required this.label,
    required this.state,
    required this.lockReason,
    required this.currentStatus,
    required this.isUnlocked,
  });
}

class WorkflowEngine {
  /// Check if Application stage is completed
  static bool isApplicationCompleted(ConsumerRecord record) {
    final st = record.applicationStatus.trim().toLowerCase();
    final recSt = record.status.trim().toLowerCase();
    return st == 'submitted' ||
        st == 'verified' ||
        st == 'completed' ||
        recSt == 'submitted' ||
        recSt == 'verified' ||
        recSt == 'completed' ||
        (record.applicationId != null && record.applicationId!.trim().isNotEmpty);
  }

  /// Check if Agreement stage is completed
  static bool isAgreementCompleted(ConsumerRecord record) {
    final st = record.agreementStatus.trim().toLowerCase();
    return st == 'verified' || st == 'completed';
  }

  /// Check if Loan is required
  static bool isLoanRequired(ConsumerRecord record) {
    return record.loanRequired.trim().toLowerCase() == 'yes';
  }

  /// Check if Loan stage is completed (or skipped)
  static bool isLoanCompleted(ConsumerRecord record) {
    if (!isLoanRequired(record)) return true; // Skipped = satisfied
    final st = record.loanStatus.trim().toLowerCase();
    return st == 'approved' || st == 'completed' || st == 'not required';
  }

  /// Check if Installation stage is completed
  static bool isInstallationCompleted(ConsumerRecord record) {
    final st = record.installationStatus.trim().toLowerCase();
    return st == 'installation completed' || st == 'completed';
  }

  /// Check if RTS stage is completed
  static bool isRtsCompleted(ConsumerRecord record) {
    final st = record.rtsStatus.trim().toLowerCase();
    return st == 'completed';
  }

  /// Check if Subsidy stage is completed
  static bool isSubsidyCompleted(ConsumerRecord record) {
    final st = record.subsidyStatus.trim().toLowerCase();
    return st == 'received' || st == 'completed' || st == 'approved';
  }

  /// Calculate exact current active stage for a record
  static String getCurrentWorkStage(ConsumerRecord record) {
    if (isSubsidyCompleted(record)) {
      return 'Completed';
    }
    if (isRtsCompleted(record)) {
      return 'Subsidy';
    }
    if (isInstallationCompleted(record)) {
      return 'RTS';
    }
    if (isLoanCompleted(record)) {
      // Loan is either approved or skipped (Loan Required = NO)
      if (isAgreementCompleted(record)) {
        return 'Installation';
      }
      return 'Agreement';
    }
    if (isAgreementCompleted(record)) {
      return 'Loan';
    }
    if (isApplicationCompleted(record)) {
      return 'Agreement';
    }
    return 'Application';
  }

  /// Calculate state of each stage for timeline and lockers
  static Map<WorkflowStage, WorkflowStageInfo> getStageStates(
    ConsumerRecord record, {
    bool isOwnerOverride = false,
  }) {
    final appDone = isApplicationCompleted(record);
    final agreeDone = isAgreementCompleted(record);
    final loanReq = isLoanRequired(record);
    final loanDone = isLoanCompleted(record);
    final installDone = isInstallationCompleted(record);
    final rtsDone = isRtsCompleted(record);
    final subsidyDone = isSubsidyCompleted(record);

    final currentStageLabel = getCurrentWorkStage(record);

    // Application
    final appState = appDone ? StageState.completed : StageState.active;

    // Agreement: Unlocked if Application done
    final agreeUnlocked = appDone || isOwnerOverride;
    final agreeState = agreeDone
        ? StageState.completed
        : (agreeUnlocked ? StageState.active : StageState.locked);
    final agreeLockReason = agreeUnlocked ? '' : '🔒 Complete Application first.';

    // Loan: Skipped if loan_required != YES. Else unlocked if Agreement done
    final loanState = !loanReq
        ? StageState.skipped
        : (loanDone
            ? StageState.completed
            : (agreeDone || isOwnerOverride ? StageState.active : StageState.locked));
    final loanLockReason = !loanReq
        ? 'Skipped (Loan Required = NO)'
        : (agreeDone || isOwnerOverride ? '' : '🔒 Complete Agreement first.');

    // Installation: Unlocked if Agreement done AND Loan done (or Loan skipped)
    final installUnlocked = (agreeDone && loanDone) || isOwnerOverride;
    final installState = installDone
        ? StageState.completed
        : (installUnlocked ? StageState.active : StageState.locked);
    final installLockReason = installUnlocked
        ? ''
        : (!agreeDone
            ? '🔒 Complete Agreement first.'
            : (loanReq && !loanDone ? '🔒 Get Loan Approved first.' : '🔒 Complete preceding stages first.'));

    // RTS: Unlocked if Installation done
    final rtsUnlocked = installDone || isOwnerOverride;
    final rtsState = rtsDone
        ? StageState.completed
        : (rtsUnlocked ? StageState.active : StageState.locked);
    final rtsLockReason = rtsUnlocked ? '' : '🔒 Complete Installation first.';

    // Subsidy: Unlocked if RTS done
    final subsidyUnlocked = rtsDone || isOwnerOverride;
    final subsidyState = subsidyDone
        ? StageState.completed
        : (subsidyUnlocked ? StageState.active : StageState.locked);
    final subsidyLockReason = subsidyUnlocked ? '' : '🔒 Complete RTS first.';

    // Completed
    final completedState = subsidyDone ? StageState.completed : StageState.locked;
    final completedLockReason = subsidyDone ? '' : '🔒 Complete Subsidy first.';

    return {
      WorkflowStage.application: WorkflowStageInfo(
        stage: WorkflowStage.application,
        label: 'Application',
        state: appState,
        lockReason: '',
        currentStatus: record.applicationStatus.isNotEmpty ? record.applicationStatus : record.status,
        isUnlocked: true,
      ),
      WorkflowStage.agreement: WorkflowStageInfo(
        stage: WorkflowStage.agreement,
        label: 'Agreement',
        state: agreeState,
        lockReason: agreeLockReason,
        currentStatus: record.agreementStatus,
        isUnlocked: agreeUnlocked,
      ),
      WorkflowStage.loan: WorkflowStageInfo(
        stage: WorkflowStage.loan,
        label: 'Loan',
        state: loanState,
        lockReason: loanLockReason,
        currentStatus: !loanReq ? 'Not Required' : record.loanStatus,
        isUnlocked: (agreeDone && loanReq) || isOwnerOverride,
      ),
      WorkflowStage.installation: WorkflowStageInfo(
        stage: WorkflowStage.installation,
        label: 'Installation',
        state: installState,
        lockReason: installLockReason,
        currentStatus: record.installationStatus,
        isUnlocked: installUnlocked,
      ),
      WorkflowStage.rts: WorkflowStageInfo(
        stage: WorkflowStage.rts,
        label: 'RTS',
        state: rtsState,
        lockReason: rtsLockReason,
        currentStatus: record.rtsStatus,
        isUnlocked: rtsUnlocked,
      ),
      WorkflowStage.subsidy: WorkflowStageInfo(
        stage: WorkflowStage.subsidy,
        label: 'Subsidy',
        state: subsidyState,
        lockReason: subsidyLockReason,
        currentStatus: record.subsidyStatus,
        isUnlocked: subsidyUnlocked,
      ),
      WorkflowStage.completed: WorkflowStageInfo(
        stage: WorkflowStage.completed,
        label: 'Completed',
        state: completedState,
        lockReason: completedLockReason,
        currentStatus: subsidyDone ? 'Completed' : 'Pending',
        isUnlocked: subsidyDone || isOwnerOverride,
      ),
    };
  }

  /// Validate single-stage update attempt or imported payload progression
  static List<String> validateStageProgression(
    ConsumerRecord existing, {
    String? newAgreementStatus,
    String? newLoanStatus,
    String? newInstallationStatus,
    String? newRtsStatus,
    String? newSubsidyStatus,
    String? newLoanRequired,
  }) {
    final errors = <String>[];

    final effectiveLoanReq = (newLoanRequired ?? existing.loanRequired).trim().toLowerCase() == 'yes';

    // If attempting to mark Agreement as Verified/Completed when Application is not submitted
    if (newAgreementStatus != null &&
        (newAgreementStatus.toLowerCase() == 'verified' || newAgreementStatus.toLowerCase() == 'completed')) {
      if (!isApplicationCompleted(existing)) {
        errors.add('Cannot complete Agreement before Application is submitted/verified.');
      }
    }

    // If attempting to mark Loan Approved when Agreement is not completed
    if (newLoanStatus != null &&
        (newLoanStatus.toLowerCase() == 'approved' || newLoanStatus.toLowerCase() == 'completed')) {
      final agreeDone = newAgreementStatus != null
          ? (newAgreementStatus.toLowerCase() == 'verified' || newAgreementStatus.toLowerCase() == 'completed')
          : isAgreementCompleted(existing);
      if (!agreeDone) {
        errors.add('Cannot complete/approve Loan before Agreement is verified.');
      }
    }

    // If attempting to mark Installation as Completed
    if (newInstallationStatus != null &&
        (newInstallationStatus.toLowerCase() == 'installation completed' || newInstallationStatus.toLowerCase() == 'completed')) {
      final agreeDone = newAgreementStatus != null
          ? (newAgreementStatus.toLowerCase() == 'verified' || newAgreementStatus.toLowerCase() == 'completed')
          : isAgreementCompleted(existing);
      if (!agreeDone) {
        errors.add('Cannot complete Installation before Agreement is verified.');
      }
      if (effectiveLoanReq) {
        final loanDone = newLoanStatus != null
            ? (newLoanStatus.toLowerCase() == 'approved' || newLoanStatus.toLowerCase() == 'completed')
            : isLoanCompleted(existing);
        if (!loanDone) {
          errors.add('Cannot complete Installation before Loan is approved.');
        }
      }
    }

    // If attempting to set RTS status beyond Not Started
    if (newRtsStatus != null && newRtsStatus.toLowerCase() != 'not started') {
      final installDone = newInstallationStatus != null
          ? (newInstallationStatus.toLowerCase() == 'installation completed' || newInstallationStatus.toLowerCase() == 'completed')
          : isInstallationCompleted(existing);
      if (!installDone) {
        errors.add('Cannot proceed with RTS before Installation is completed.');
      }
    }

    // If attempting to set Subsidy status beyond Not Applied
    if (newSubsidyStatus != null && newSubsidyStatus.toLowerCase() != 'not applied') {
      final rtsDone = newRtsStatus != null
          ? (newRtsStatus.toLowerCase() == 'completed')
          : isRtsCompleted(existing);
      if (!rtsDone) {
        errors.add('Cannot proceed with Subsidy before RTS is completed.');
      }
    }

    return errors;
  }
}
