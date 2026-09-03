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
