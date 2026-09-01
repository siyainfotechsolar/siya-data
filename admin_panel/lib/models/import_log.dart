class ImportLog {
  final String? id;
  final String fileName;
  final int fileSizeBytes;
  final int totalRows;
  final int insertedCount;
  final int updatedCount;
  final int skippedCount;
  final int failedCount;
  final String strategy;
  final DateTime createdAt;
  final String? createdBy;
  final String? creatorEmail;

  ImportLog({
    this.id,
    required this.fileName,
    required this.fileSizeBytes,
    required this.totalRows,
    required this.insertedCount,
    required this.updatedCount,
    required this.skippedCount,
    this.failedCount = 0,
    required this.strategy,
    required this.createdAt,
    this.createdBy,
    this.creatorEmail,
  });

  factory ImportLog.fromJson(Map<String, dynamic> json) {
    return ImportLog(
      id: json['id'] as String?,
      fileName: json['file_name'] as String? ?? 'Unnamed File',
      fileSizeBytes: (json['file_size_bytes'] as num?)?.toInt() ?? 0,
      totalRows: (json['total_rows'] as num?)?.toInt() ?? 0,
      insertedCount: (json['inserted_count'] as num?)?.toInt() ?? 0,
      updatedCount: (json['updated_count'] as num?)?.toInt() ?? 0,
      skippedCount: (json['skipped_count'] as num?)?.toInt() ?? 0,
      failedCount: (json['failed_count'] as num?)?.toInt() ?? 0,
      strategy: json['strategy'] as String? ?? 'updateNonEmptyOnly',
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
      createdBy: json['created_by'] as String?,
      creatorEmail: json['profiles'] != null ? (json['profiles'] as Map<String, dynamic>)['email'] as String? : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'file_name': fileName,
      'file_size_bytes': fileSizeBytes,
      'total_rows': totalRows,
      'inserted_count': insertedCount,
      'updated_count': updatedCount,
      'skipped_count': skippedCount,
      'failed_count': failedCount,
      'strategy': strategy,
      'created_at': createdAt.toUtc().toIso8601String(),
      if (createdBy != null) 'created_by': createdBy,
    };
  }

  String get formattedFileSize {
    if (fileSizeBytes < 1024) return '$fileSizeBytes B';
    if (fileSizeBytes < 1024 * 1024) return '${(fileSizeBytes / 1024).toStringAsFixed(1)} KB';
    return '${(fileSizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  String get strategyLabel {
    switch (strategy) {
      case 'updateNonEmptyOnly':
        return 'Smart Update (Non-Empty)';
      case 'overwriteAll':
        return 'Overwrite All';
      case 'skipExisting':
        return 'Skip Existing';
      default:
        return strategy;
    }
  }
}

class AuditLogEntry {
  final String? id;
  final String? recordId;
  final String consumerNo;
  final String action;
  final String? fieldName;
  final String? oldValue;
  final String? newValue;
  final String? changedBy;
  final String? changerEmail;
  final String source;
  final DateTime createdAt;

  AuditLogEntry({
    this.id,
    this.recordId,
    required this.consumerNo,
    required this.action,
    this.fieldName,
    this.oldValue,
    this.newValue,
    this.changedBy,
    this.changerEmail,
    this.source = 'Admin Web',
    required this.createdAt,
  });

  factory AuditLogEntry.fromJson(Map<String, dynamic> json) {
    return AuditLogEntry(
      id: json['id'] as String?,
      recordId: json['record_id'] as String?,
      consumerNo: json['consumer_no'] as String? ?? '—',
      action: json['action'] as String? ?? 'UPDATE',
      fieldName: json['field_name'] as String?,
      oldValue: json['old_value'] as String?,
      newValue: json['new_value'] as String?,
      changedBy: json['changed_by'] as String?,
      changerEmail: json['profiles'] != null ? (json['profiles'] as Map<String, dynamic>)['email'] as String? : null,
      source: json['source'] as String? ?? 'Admin Web',
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }
}
