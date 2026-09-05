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
    final subStage = record.loanSubStage.trim().toLowerCase();
    final st = record.loanStatus.trim().toLowerCase();
    return subStage == 'loan completed' ||
        subStage == 'completed' ||
        st == 'loan completed' ||
        st == 'completed';
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

  /// Check if Subsidy stage is completed (Subsidy Received = COMPLETED)
  static bool isSubsidyCompleted(ConsumerRecord record) {
    final st = record.subsidyStatus.trim().toLowerCase();
    final recSt = record.status.trim().toLowerCase();
    return st == 'received' || st == 'completed' || recSt == 'completed';
  }

  /// Returns true if customer work is 100% completed (Subsidy Received or Mark as Complete)
  static bool isWorkCompleted(ConsumerRecord record) {
    if (record.customerWorkState.toUpperCase() == 'COMPLETED') return true;
    return isSubsidyCompleted(record);
  }

  /// Calculate exact current active work stage for a record (Only ONE stage actionable at a time)
  static String getCurrentWorkStage(ConsumerRecord record) {
    if (isWorkCompleted(record)) {
      return 'Completed';
    }
    if (isRtsCompleted(record)) {
      return 'Subsidy';
    }
    if (isInstallationCompleted(record)) {
      return 'RTS';
    }
    final agreeDone = isAgreementCompleted(record);
    final loanReq = isLoanRequired(record);
    final loanDone = isLoanCompleted(record);

    if (agreeDone) {
      if (loanReq && !loanDone) {
        return 'Loan';
      }
      return 'Installation';
    }
    return 'Agreement';
  }

  /// Calculate current work status derived from current work stage
  static String getCurrentWorkStatus(ConsumerRecord record) {
    if (isWorkCompleted(record)) {
      return 'Completed';
    }
    final stage = getCurrentWorkStage(record);
    switch (stage) {
      case 'Subsidy':
        return record.subsidyStatus;
      case 'RTS':
        return record.rtsStatus;
      case 'Installation':
        return record.installationStatus;
      case 'Loan':
        return record.loanSubStage.isNotEmpty ? record.loanSubStage : record.loanStatus;
      case 'Agreement':
      default:
        return record.agreementStatus;
    }
  }

  /// Calculate intelligent Action Required step
  static String getActionRequired(ConsumerRecord record) {
    if (record.customerWorkState.toUpperCase() == 'NO_ACTION_REQUIRED' || isWorkCompleted(record)) {
      return 'None';
    }
    final stage = getCurrentWorkStage(record);
    switch (stage) {
      case 'Agreement':
        return 'Agreement';
      case 'Loan':
        final subStage = record.loanSubStage.trim().toLowerCase();
        if (subStage.contains('rejected')) {
          return 'Loan Correction';
        } else if (subStage.contains('correction')) {
          return 'Correct Loan File';
        } else if (subStage.contains('re-apply') || subStage.contains('reapply')) {
          return 'Re-Apply Loan';
        } else if (subStage.contains('file at bank') || subStage.contains('bank')) {
          return 'Bank Follow-up';
        } else if (subStage.contains('ready')) {
          return 'Loan File Action Required';
        } else if (subStage == 'loan approved') {
          return '1st Installment';
        } else if (subStage == '1st installment') {
          return '2nd Installment';
        } else if (subStage == '2nd installment') {
          return 'Mark Loan Completed';
        } else if (subStage == 'loan completed') {
          return 'Installation Ready';
        }
        return 'Loan Action Required';
      case 'Installation':
        return 'Installation';
      case 'RTS':
        return 'RTS';
      case 'Subsidy':
        return 'Subsidy';
      case 'Completed':
      default:
        return 'None';
    }
  }

  /// Calculate useful Next Action instruction for staff
  static String getNextAction(ConsumerRecord record) {
    if (record.customerWorkState.toUpperCase() == 'NO_ACTION_REQUIRED' || isWorkCompleted(record)) {
      return 'None';
    }
    final stage = getCurrentWorkStage(record);
    if (stage == 'Loan') {
      final subStage = record.loanSubStage.trim().toLowerCase();
      if (subStage.contains('rejected')) {
        return 'Correct Issue';
      } else if (subStage.contains('correction')) {
        return 'Prepare Corrected File';
      } else if (subStage.contains('re-apply') || subStage.contains('reapply')) {
        return 'Re-Apply Loan File';
      } else if (subStage.contains('file at bank') || subStage.contains('bank')) {
        return 'Check Bank Status';
      } else if (subStage.contains('ready')) {
        return 'Submit to Bank';
      } else if (subStage == 'loan approved') {
        return 'Process 1st Installment';
      } else if (subStage == '1st installment') {
        return 'Process 2nd Installment';
      } else if (subStage == '2nd installment') {
        return 'Mark Loan Completed';
      } else if (subStage == 'loan completed') {
        return 'Schedule Installation';
      }
      return 'Prepare / Submit Loan File';
    }
    final action = getActionRequired(record);
    switch (action) {
      case 'Agreement':
        return 'Upload Agreement';
      case 'Installation':
        return 'Schedule Installation';
      case 'RTS':
        return 'Process RTS';
      case 'Subsidy':
        return 'Process Subsidy';
      case 'None':
      default:
        return 'None';
    }
  }

  /// Sort records for Action Center: 1) Days in Current Stage DESC, 2) Application Days DESC, 3) Application Date ASC
  static void sortRecordsForActionCenter(List<ConsumerRecord> list) {
    list.sort((a, b) {
      final stageDaysCmp = b.daysInCurrentStage.compareTo(a.daysInCurrentStage);
      if (stageDaysCmp != 0) return stageDaysCmp;

      final appDaysCmp = b.applicationDays.compareTo(a.applicationDays);
      if (appDaysCmp != 0) return appDaysCmp;

      final aDate = a.applicationDate ?? a.submitDate ?? a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bDate = b.applicationDate ?? b.submitDate ?? b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return aDate.compareTo(bDate);
    });
  }

  /// Calculate Days in Current Stage (Current Date - Current Stage Start Date)
  static int getDaysInCurrentStage(ConsumerRecord record) {
    if (isWorkCompleted(record)) return 0;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final stage = getCurrentWorkStage(record);

    DateTime? startDate;
    switch (stage) {
      case 'Subsidy':
        startDate = record.subsidyAppliedDate ?? record.rtsCompletionDate ?? record.rtsDate ?? record.submitDate;
        break;
      case 'RTS':
        startDate = record.rtsDate ?? record.installationDate ?? record.submitDate;
        break;
      case 'Installation':
        startDate = record.installationDate ?? record.loanApprovedDate ?? record.agreementDate ?? record.submitDate;
        break;
      case 'Loan':
        startDate = record.loanAppliedDate ?? record.agreementDate ?? record.submitDate;
        break;
      case 'Agreement':
        startDate = record.agreementDate ?? record.submitDate;
        break;
      case 'Application':
      default:
        startDate = record.submitDate ?? record.applicationDate ?? record.createdAt;
        break;
    }

    if (startDate == null) return 0;
    final sDate = DateTime(startDate.year, startDate.month, startDate.day);
    if (sDate.isAfter(today)) return 0;
    return today.difference(sDate).inDays;
  }

  /// Calculate intelligent Priority Category
  static String getPriorityCategory(ConsumerRecord record) {
    if (isWorkCompleted(record) || getCurrentWorkStage(record) == 'Completed') {
      return 'None';
    }

    final subSt = record.subsidyStatus.trim().toLowerCase();
    // If RTS is done and subsidy is submitted/under process/approved -> Processing (not critical active work)
    if (isRtsCompleted(record) && (subSt == 'applied' || subSt == 'under process' || subSt == 'approved' || subSt == 'subsidy request' || subSt == 'pending')) {
      return 'Processing';
    }

    // Active actionable work pending -> categorize based on applicationDays and stage duration
    final days = record.applicationDays;
    final stageDays = getDaysInCurrentStage(record);

    if (days >= 31 || stageDays >= 15) {
      return 'Critical Active Work';
    }
    if (days >= 16 || stageDays >= 8) {
      return 'High Active Work';
    }
    if (days >= 8) {
      return 'Medium Active Work';
    }
    return 'Normal Active Work';
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
    final loanLockReason = (agreeDone || isOwnerOverride)
        ? ''
        : '🔒 Complete Agreement first.';

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
        isUnlocked: agreeDone || isOwnerOverride,
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
