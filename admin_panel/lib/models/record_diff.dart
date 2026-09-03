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

  /// Merge incoming record into existing record according to chosen strategy
  ConsumerRecord createMergedRecord(ConflictStrategy strategy) {
    if (strategy == ConflictStrategy.skipExisting || !shouldUpdate) {
      return existingRecord;
    }

    if (strategy == ConflictStrategy.overwriteAll) {
      return ConsumerRecord(
        id: existingRecord.id,
        consumerNo: existingRecord.consumerNo,
        name: incomingRecord.name.isNotEmpty ? incomingRecord.name : existingRecord.name,
        mobile: incomingRecord.mobile,
        address: incomingRecord.address,
        applicationId: incomingRecord.applicationId,
        status: incomingRecord.status.isNotEmpty ? incomingRecord.status : existingRecord.status,
        remarks: incomingRecord.remarks,
        createdAt: existingRecord.createdAt,
        updatedAt: DateTime.now(),
        createdBy: existingRecord.createdBy,
        updatedBy: existingRecord.updatedBy,
        deleted: false,
        deletedAt: null,
        deletedBy: null,
      );
    }

    // updateNonEmptyOnly: only replace if new field is not null and not empty
    return ConsumerRecord(
      id: existingRecord.id,
      consumerNo: existingRecord.consumerNo,
      name: (incomingRecord.name.isNotEmpty) ? incomingRecord.name : existingRecord.name,
      mobile: (incomingRecord.mobile != null && incomingRecord.mobile!.trim().isNotEmpty)
          ? incomingRecord.mobile
          : existingRecord.mobile,
      address: (incomingRecord.address != null && incomingRecord.address!.trim().isNotEmpty)
          ? incomingRecord.address
          : existingRecord.address,
      applicationId: (incomingRecord.applicationId != null && incomingRecord.applicationId!.trim().isNotEmpty)
          ? incomingRecord.applicationId
          : existingRecord.applicationId,
      status: (incomingRecord.status.isNotEmpty && incomingRecord.status != 'Pending')
          ? incomingRecord.status
          : existingRecord.status,
      remarks: (incomingRecord.remarks != null && incomingRecord.remarks!.trim().isNotEmpty)
          ? incomingRecord.remarks
          : existingRecord.remarks,
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
