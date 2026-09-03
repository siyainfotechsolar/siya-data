import 'consumer_record.dart';

enum ConflictStrategy {
  overwriteAll,
  updateNonEmptyOnly,
  skipExisting,
}

class FieldDiff {
  final String fieldKey;
  final String fieldLabel;
  final String? oldValue;
  final String? newValue;

  FieldDiff({
    required this.fieldKey,
    required this.fieldLabel,
    this.oldValue,
    this.newValue,
  });

  bool get isChanged {
    final cleanOld = oldValue?.trim() ?? '';
    final cleanNew = newValue?.trim() ?? '';
    return cleanOld != cleanNew;
  }

  bool get isNewEmpty => (newValue?.trim() ?? '').isEmpty;
}

class RecordDiff {
  final ConsumerRecord existingRecord;
  final ConsumerRecord incomingRecord;
  final List<FieldDiff> changedFields;
  bool shouldUpdate;

  RecordDiff({
    required this.existingRecord,
    required this.incomingRecord,
    required this.changedFields,
    this.shouldUpdate = true,
  });

  bool get hasChanges => changedFields.isNotEmpty;

  /// Constructs a strictly sparse update payload containing ONLY fields that are:
  /// 1. Included in [allowedFieldKeys] (not skipped).
  /// 2. Different from the existing database value.
  /// 3. If [ignoreBlankValues] is true, new empty values are rejected and preserved.
  Map<String, dynamic> buildUpdatePayload({
    Set<String>? allowedFieldKeys,
    bool ignoreBlankValues = true,
  }) {
    final payload = <String, dynamic>{};
    if (!shouldUpdate) return payload;

    final allowed = allowedFieldKeys ?? {
      'name',
      'mobile',
      'address',
      'application_id',
      'status',
      'remarks',
      // Workflow & Date fields
      'application_date',
      'submit_date',
      'application_status',
      'agreement_status',
      'loan_required',
      'loan_status',
      'installation_status',
      'installer_team',
      'rts_status',
      'rts_application_id',
      'subsidy_status',
    };

    void checkAndAdd(String key, String? oldVal, String? newVal) {
      if (!allowed.contains(key)) return; // SKIPPED: never touch database

      final cleanOld = oldVal?.trim() ?? '';
      final cleanNew = newVal?.trim() ?? '';

      // Ignore blank values if setting is enabled
      if (ignoreBlankValues && cleanNew.isEmpty) {
        return;
      }

      if (cleanOld != cleanNew) {
        payload[key] = (newVal == null || cleanNew.isEmpty) ? null : cleanNew;
      }
    }

    checkAndAdd('name', existingRecord.name, incomingRecord.name);
    checkAndAdd('mobile', existingRecord.mobile, incomingRecord.mobile);
    checkAndAdd('address', existingRecord.address, incomingRecord.address);
    checkAndAdd('application_id', existingRecord.applicationId, incomingRecord.applicationId);
    checkAndAdd('status', existingRecord.status, incomingRecord.status);
    checkAndAdd('remarks', existingRecord.remarks, incomingRecord.remarks);
    // Workflow & Date checks
    if (allowed.contains('application_date')) {
      final oldIso = existingRecord.applicationDate?.toIso8601String() ?? '';
      final newIso = incomingRecord.applicationDate?.toIso8601String() ?? '';
      if (newIso.isNotEmpty && oldIso != newIso) {
        payload['application_date'] = incomingRecord.applicationDate!.toIso8601String();
      }
    }
    if (allowed.contains('submit_date')) {
      final oldIso = existingRecord.submitDate?.toIso8601String() ?? '';
      final newIso = incomingRecord.submitDate?.toIso8601String() ?? '';
      if (newIso.isNotEmpty && oldIso != newIso) {
        payload['submit_date'] = incomingRecord.submitDate!.toIso8601String();
      }
    }
    checkAndAdd('application_status', existingRecord.applicationStatus, incomingRecord.applicationStatus);
    checkAndAdd('agreement_status', existingRecord.agreementStatus, incomingRecord.agreementStatus);
    checkAndAdd('loan_required', existingRecord.loanRequired, incomingRecord.loanRequired);
    checkAndAdd('loan_status', existingRecord.loanStatus, incomingRecord.loanStatus);
    checkAndAdd('installation_status', existingRecord.installationStatus, incomingRecord.installationStatus);
    checkAndAdd('installer_team', existingRecord.installerTeam, incomingRecord.installerTeam);
    checkAndAdd('rts_status', existingRecord.rtsStatus, incomingRecord.rtsStatus);
    checkAndAdd('rts_application_id', existingRecord.rtsApplicationId, incomingRecord.rtsApplicationId);
    checkAndAdd('subsidy_status', existingRecord.subsidyStatus, incomingRecord.subsidyStatus);

    return payload;
  }

  /// Merge incoming record into existing record strictly respecting allowedFieldKeys
  ConsumerRecord createMergedRecord(
    ConflictStrategy strategy, {
    Set<String>? allowedFieldKeys,
    bool? ignoreBlankValues,
  }) {
    if (strategy == ConflictStrategy.skipExisting || !shouldUpdate) {
      return existingRecord;
    }

    final effectiveIgnoreBlank = ignoreBlankValues ?? (strategy != ConflictStrategy.overwriteAll);

    final payload = buildUpdatePayload(
      allowedFieldKeys: allowedFieldKeys,
      ignoreBlankValues: effectiveIgnoreBlank,
    );

    return ConsumerRecord(
      id: existingRecord.id,
      consumerNo: existingRecord.consumerNo,
      name: payload.containsKey('name') ? (payload['name'] as String? ?? existingRecord.name) : existingRecord.name,
      mobile: payload.containsKey('mobile') ? payload['mobile'] as String? : existingRecord.mobile,
      address: payload.containsKey('address') ? payload['address'] as String? : existingRecord.address,
      applicationId: payload.containsKey('application_id') ? payload['application_id'] as String? : existingRecord.applicationId,
      status: payload.containsKey('status') ? (payload['status'] as String? ?? existingRecord.status) : existingRecord.status,
      remarks: payload.containsKey('remarks') ? payload['remarks'] as String? : existingRecord.remarks,
      createdAt: existingRecord.createdAt,
      updatedAt: DateTime.now(),
      createdBy: existingRecord.createdBy,
      updatedBy: existingRecord.updatedBy,
      deleted: false,
      deletedAt: null,
      deletedBy: null,
      // Workflow fields merged
      applicationStatus: payload.containsKey('application_status') ? (payload['application_status'] as String? ?? existingRecord.applicationStatus) : existingRecord.applicationStatus,
      applicationDate: payload.containsKey('application_date')
          ? (payload['application_date'] != null ? DateTime.tryParse(payload['application_date'] as String) : existingRecord.applicationDate)
          : existingRecord.applicationDate,
      submitDate: payload.containsKey('submit_date')
          ? (payload['submit_date'] != null ? DateTime.tryParse(payload['submit_date'] as String) : existingRecord.submitDate)
          : existingRecord.submitDate,
      agreementRequired: existingRecord.agreementRequired,
      agreementStatus: payload.containsKey('agreement_status') ? (payload['agreement_status'] as String? ?? existingRecord.agreementStatus) : existingRecord.agreementStatus,
      agreementDocUrl: existingRecord.agreementDocUrl,
      agreementDate: existingRecord.agreementDate,
      loanRequired: payload.containsKey('loan_required') ? (payload['loan_required'] as String? ?? existingRecord.loanRequired) : existingRecord.loanRequired,
      loanStatus: payload.containsKey('loan_status') ? (payload['loan_status'] as String? ?? existingRecord.loanStatus) : existingRecord.loanStatus,
      loanAppliedDate: existingRecord.loanAppliedDate,
      loanApprovedDate: existingRecord.loanApprovedDate,
      installationStatus: payload.containsKey('installation_status') ? (payload['installation_status'] as String? ?? existingRecord.installationStatus) : existingRecord.installationStatus,
      installationDate: existingRecord.installationDate,
      installerTeam: payload.containsKey('installer_team') ? payload['installer_team'] as String? : existingRecord.installerTeam,
      installationPhotosUrl: existingRecord.installationPhotosUrl,
      rtsStatus: payload.containsKey('rts_status') ? (payload['rts_status'] as String? ?? existingRecord.rtsStatus) : existingRecord.rtsStatus,
      rtsApplicationId: payload.containsKey('rts_application_id') ? payload['rts_application_id'] as String? : existingRecord.rtsApplicationId,
      rtsDate: existingRecord.rtsDate,
      rtsCompletionDate: existingRecord.rtsCompletionDate,
      subsidyStatus: payload.containsKey('subsidy_status') ? (payload['subsidy_status'] as String? ?? existingRecord.subsidyStatus) : existingRecord.subsidyStatus,
      subsidyAppliedDate: existingRecord.subsidyAppliedDate,
      subsidyApprovedDate: existingRecord.subsidyApprovedDate,
      subsidyReceivedDate: existingRecord.subsidyReceivedDate,
    );
  }
}

class DuplicateAnalysisResult {
  final List<ConsumerRecord> newRecords;
  final List<ConsumerRecord> identicalRecords;
  final List<RecordDiff> conflictRecords;

  DuplicateAnalysisResult({
    required this.newRecords,
    required this.identicalRecords,
    required this.conflictRecords,
  });

  int get totalIncoming => newRecords.length + identicalRecords.length + conflictRecords.length;
}
