import 'package:flutter/material.dart';

class TaskStatus {
  static const String newTask = 'New';
  static const String documentReview = 'Document Review';
  static const String customerDataUpdate = 'Customer Data Update';
  static const String verification = 'Verification';
  static const String complete = 'Complete';
  static const String hold = 'Hold';
  static const String followup = 'Follow-up';
  static const String reopen = 'Reopen';

  static const List<String> all = [
    newTask,
    documentReview,
    customerDataUpdate,
    verification,
    complete,
    hold,
    followup,
    reopen,
  ];

  static const List<String> standardWorkflow = [
    newTask,
    documentReview,
    customerDataUpdate,
    verification,
    complete,
  ];
}

class TaskDocumentType {
  static const String electricityBill = 'Electricity Bill';
  static const String loanDocument = 'Loan Document';
  static const String paymentProof = 'Payment Proof';
  static const String agreement = 'Agreement';
  static const String rts = 'RTS';
  static const String subsidy = 'Subsidy';
  static const String installation = 'Installation';
  static const String other = 'Other';

  static const List<String> all = [
    electricityBill,
    loanDocument,
    paymentProof,
    agreement,
    rts,
    subsidy,
    installation,
    other,
  ];
}

class TaskPriority {
  static const String normal = 'Normal';
  static const String high = 'High';
  static const String urgent = 'Urgent';

  static const List<String> all = [normal, high, urgent];
}

class CustomerTask {
  final String id;
  final String customerId;
  final String customerName;
  final String consumerNo;
  final String? mobileNumber;
  final String taskType; // 'Customer Document Update'
  final String title;
  final String documentType;
  final String documentName;
  final String? documentUrl; // Supabase storage remote URL
  final String? localFilePath; // Local file path for offline access
  final String? fileHash;
  final int fileSize;
  final String source; // 'WhatsApp Share', 'Manual Upload', etc.
  final String status;
  final String priority;
  final String? assignedStaff;
  final DateTime? dueDate;
  final String? holdReason;
  final String? resolutionRemarks;
  final String? remarks;
  final Map<String, dynamic>? extractedData;
  final String syncStatus; // 'Synced', 'Pending Sync'
  final String? createdBy;
  final String? createdByName;
  final DateTime createdAt;
  final String? updatedBy;
  final String? updatedByName;
  final DateTime updatedAt;
  final String? completedBy;
  final String? completedByName;
  final DateTime? completedAt;

  const CustomerTask({
    required this.id,
    required this.customerId,
    required this.customerName,
    required this.consumerNo,
    this.mobileNumber,
    this.taskType = 'Customer Document Update',
    required this.title,
    this.documentType = TaskDocumentType.other,
    required this.documentName,
    this.documentUrl,
    this.localFilePath,
    this.fileHash,
    this.fileSize = 0,
    this.source = 'WhatsApp Share',
    this.status = TaskStatus.newTask,
    this.priority = TaskPriority.normal,
    this.assignedStaff,
    this.dueDate,
    this.holdReason,
    this.resolutionRemarks,
    this.remarks,
    this.extractedData,
    this.syncStatus = 'Synced',
    this.createdBy,
    this.createdByName,
    required this.createdAt,
    this.updatedBy,
    this.updatedByName,
    required this.updatedAt,
    this.completedBy,
    this.completedByName,
    this.completedAt,
  });

  bool get isComplete => status == TaskStatus.complete;
  bool get isHold => status == TaskStatus.hold;
  bool get isPendingSync => syncStatus == 'Pending Sync';
  bool get isWhatsAppShare => source == 'WhatsApp Share';

  Color get statusColor {
    switch (status) {
      case TaskStatus.newTask:
        return const Color(0xFF2563EB); // Blue
      case TaskStatus.documentReview:
        return const Color(0xFFD97706); // Amber
      case TaskStatus.customerDataUpdate:
        return const Color(0xFF7C3AED); // Purple
      case TaskStatus.verification:
        return const Color(0xFF0284C7); // Sky
      case TaskStatus.complete:
        return const Color(0xFF059669); // Emerald
      case TaskStatus.hold:
        return const Color(0xFFDC2626); // Red
      case TaskStatus.followup:
        return const Color(0xFFEA580C); // Orange
      case TaskStatus.reopen:
        return const Color(0xFF4F46E5); // Indigo
      default:
        return Colors.grey;
    }
  }

  Color get priorityColor {
    switch (priority) {
      case TaskPriority.urgent:
        return const Color(0xFFDC2626);
      case TaskPriority.high:
        return const Color(0xFFEA580C);
      case TaskPriority.normal:
      default:
        return const Color(0xFF059669);
    }
  }

  factory CustomerTask.fromMap(Map<String, dynamic> map) {
    DateTime parseDate(dynamic val, [DateTime? fallback]) {
      if (val == null) return fallback ?? DateTime.now();
      try {
        return DateTime.parse(val.toString());
      } catch (_) {
        return fallback ?? DateTime.now();
      }
    }

    DateTime? parseNullableDate(dynamic val) {
      if (val == null) return null;
      try {
        return DateTime.parse(val.toString());
      } catch (_) {
        return null;
      }
    }

    return CustomerTask(
      id: map['id']?.toString() ?? '',
      customerId: map['customer_id']?.toString() ?? '',
      customerName: map['customer_name']?.toString() ?? 'Customer',
      consumerNo: map['consumer_no']?.toString() ?? '-',
      mobileNumber: map['mobile_number']?.toString(),
      taskType: map['task_type']?.toString() ?? 'Customer Document Update',
      title: map['title']?.toString() ?? 'Document Task',
      documentType: map['document_type']?.toString() ?? TaskDocumentType.other,
      documentName: map['document_name']?.toString() ?? 'document.pdf',
      documentUrl: map['document_url']?.toString(),
      localFilePath: map['local_file_path']?.toString(),
      fileHash: map['file_hash']?.toString(),
      fileSize: (map['file_size'] as num?)?.toInt() ?? 0,
      source: map['source']?.toString() ?? 'WhatsApp Share',
      status: map['status']?.toString() ?? TaskStatus.newTask,
      priority: map['priority']?.toString() ?? TaskPriority.normal,
      assignedStaff: map['assigned_staff']?.toString(),
      dueDate: parseNullableDate(map['due_date']),
      holdReason: map['hold_reason']?.toString(),
      resolutionRemarks: map['resolution_remarks']?.toString(),
      remarks: map['remarks']?.toString(),
      extractedData: map['extracted_data'] != null && map['extracted_data'] is Map
          ? Map<String, dynamic>.from(map['extracted_data'] as Map)
          : null,
      syncStatus: map['sync_status']?.toString() ?? 'Synced',
      createdBy: map['created_by']?.toString(),
      createdByName: map['created_by_name']?.toString(),
      createdAt: parseDate(map['created_at']),
      updatedBy: map['updated_by']?.toString(),
      updatedByName: map['updated_by_name']?.toString(),
      updatedAt: parseDate(map['updated_at']),
      completedBy: map['completed_by']?.toString(),
      completedByName: map['completed_by_name']?.toString(),
      completedAt: parseNullableDate(map['completed_at']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'customer_id': customerId,
      'customer_name': customerName,
      'consumer_no': consumerNo,
      'mobile_number': mobileNumber,
      'task_type': taskType,
      'title': title,
      'document_type': documentType,
      'document_name': documentName,
      'document_url': documentUrl,
      'local_file_path': localFilePath,
      'file_hash': fileHash,
      'file_size': fileSize,
      'source': source,
      'status': status,
      'priority': priority,
      'assigned_staff': assignedStaff,
      'due_date': dueDate?.toIso8601String().split('T').first,
      'hold_reason': holdReason,
      'resolution_remarks': resolutionRemarks,
      'remarks': remarks,
      'extracted_data': extractedData,
      'sync_status': syncStatus,
      'created_by': createdBy,
      'created_by_name': createdByName,
      'created_at': createdAt.toIso8601String(),
      'updated_by': updatedBy,
      'updated_by_name': updatedByName,
      'updated_at': updatedAt.toIso8601String(),
      'completed_by': completedBy,
      'completed_by_name': completedByName,
      'completed_at': completedAt?.toIso8601String(),
    };
  }

  CustomerTask copyWith({
    String? id,
    String? customerId,
    String? customerName,
    String? consumerNo,
    String? mobileNumber,
    String? taskType,
    String? title,
    String? documentType,
    String? documentName,
    String? documentUrl,
    String? localFilePath,
    String? fileHash,
    int? fileSize,
    String? source,
    String? status,
    String? priority,
    String? assignedStaff,
    DateTime? dueDate,
    String? holdReason,
    String? resolutionRemarks,
    String? remarks,
    Map<String, dynamic>? extractedData,
    String? syncStatus,
    String? createdBy,
    String? createdByName,
    DateTime? createdAt,
    String? updatedBy,
    String? updatedByName,
    DateTime? updatedAt,
    String? completedBy,
    String? completedByName,
    DateTime? completedAt,
  }) {
    return CustomerTask(
      id: id ?? this.id,
      customerId: customerId ?? this.customerId,
      customerName: customerName ?? this.customerName,
      consumerNo: consumerNo ?? this.consumerNo,
      mobileNumber: mobileNumber ?? this.mobileNumber,
      taskType: taskType ?? this.taskType,
      title: title ?? this.title,
      documentType: documentType ?? this.documentType,
      documentName: documentName ?? this.documentName,
      documentUrl: documentUrl ?? this.documentUrl,
      localFilePath: localFilePath ?? this.localFilePath,
      fileHash: fileHash ?? this.fileHash,
      fileSize: fileSize ?? this.fileSize,
      source: source ?? this.source,
      status: status ?? this.status,
      priority: priority ?? this.priority,
      assignedStaff: assignedStaff ?? this.assignedStaff,
      dueDate: dueDate ?? this.dueDate,
      holdReason: holdReason ?? this.holdReason,
      resolutionRemarks: resolutionRemarks ?? this.resolutionRemarks,
      remarks: remarks ?? this.remarks,
      extractedData: extractedData ?? this.extractedData,
      syncStatus: syncStatus ?? this.syncStatus,
      createdBy: createdBy ?? this.createdBy,
      createdByName: createdByName ?? this.createdByName,
      createdAt: createdAt ?? this.createdAt,
      updatedBy: updatedBy ?? this.updatedBy,
      updatedByName: updatedByName ?? this.updatedByName,
      updatedAt: updatedAt ?? this.updatedAt,
      completedBy: completedBy ?? this.completedBy,
      completedByName: completedByName ?? this.completedByName,
      completedAt: completedAt ?? this.completedAt,
    );
  }
}
