import 'package:flutter/material.dart';

class OfficeTaskType {
  static const String customerCall = 'Customer Call';
  static const String followUp = 'Follow-up';
  static const String documentCollection = 'Document Collection';
  static const String agreement = 'Agreement';
  static const String paymentFollowUp = 'Payment Follow-up';
  static const String loanDocument = 'Loan Document';
  static const String pmSuryaGhar = 'PM Surya Ghar Document';
  static const String subsidyFollowUp = 'Subsidy Follow-up';
  static const String rtsFollowUp = 'RTS Follow-up';
  static const String customerInfoUpdate = 'Customer Information Update';
  static const String billingIssue = 'Billing Issue';
  static const String customerComplaint = 'Customer Complaint';
  static const String generalOfficeWork = 'General Office Work';
  static const String other = 'Other';

  static const List<String> all = [
    customerCall,
    followUp,
    documentCollection,
    agreement,
    paymentFollowUp,
    loanDocument,
    pmSuryaGhar,
    subsidyFollowUp,
    rtsFollowUp,
    customerInfoUpdate,
    billingIssue,
    customerComplaint,
    generalOfficeWork,
    other,
  ];

  static const List<String> allTypes = all;

  static IconData getIcon(String type) {
    switch (type) {
      case customerCall:
        return Icons.phone_in_talk_rounded;
      case followUp:
        return Icons.phone_callback_rounded;
      case documentCollection:
        return Icons.folder_shared_rounded;
      case agreement:
        return Icons.handshake_rounded;
      case paymentFollowUp:
        return Icons.payments_rounded;
      case loanDocument:
        return Icons.account_balance_rounded;
      case pmSuryaGhar:
        return Icons.wb_sunny_rounded;
      case subsidyFollowUp:
        return Icons.currency_rupee_rounded;
      case rtsFollowUp:
        return Icons.electric_bolt_rounded;
      case customerInfoUpdate:
        return Icons.manage_accounts_rounded;
      case billingIssue:
        return Icons.receipt_long_rounded;
      case customerComplaint:
        return Icons.report_problem_rounded;
      case generalOfficeWork:
        return Icons.business_center_rounded;
      default:
        return Icons.assignment_rounded;
    }
  }
}

class OfficeTaskPriority {
  static const String low = 'Low';
  static const String normal = 'Normal';
  static const String high = 'High';
  static const String urgent = 'Urgent';

  static const List<String> all = [low, normal, high, urgent];
  static const List<String> allPriorities = all;

  static Color getColor(String priority) {
    switch (priority) {
      case urgent:
        return const Color(0xFFDC2626); // Crimson Red
      case high:
        return const Color(0xFFEA580C); // Vibrant Orange
      case normal:
        return const Color(0xFF2563EB); // Royal Blue
      case low:
      default:
        return const Color(0xFF64748B); // Slate Grey
    }
  }
}

class OfficeTaskStatus {
  static const String pending = 'Pending';
  static const String inProgress = 'In Progress';
  static const String hold = 'Hold';
  static const String completed = 'Completed';

  static const List<String> all = [pending, inProgress, hold, completed];

  static Color getColor(String status) {
    switch (status) {
      case completed:
        return const Color(0xFF059669); // Emerald Green
      case inProgress:
        return const Color(0xFF2563EB); // Royal Blue
      case hold:
        return const Color(0xFFD97706); // Amber
      case pending:
      default:
        return const Color(0xFF475569); // Slate
    }
  }
}

class OfficeTask {
  final String id;
  final String? customerId;
  final String customerName;
  final String consumerNo;
  final String? village;
  final String title;
  final String taskType;
  final String? description;
  final String priority;
  final String status;
  final DateTime? dueDate;
  final String? assignedToId;
  final String assignedToName;
  final String? createdBy;
  final String? createdByName;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final String? completionNote;
  final String? holdReason;
  final String? attachmentUrl;
  final DateTime createdAt;
  final DateTime updatedAt;

  OfficeTask({
    required this.id,
    this.customerId,
    required this.customerName,
    required this.consumerNo,
    this.village,
    required this.title,
    required this.taskType,
    this.description,
    this.priority = OfficeTaskPriority.normal,
    this.status = OfficeTaskStatus.pending,
    this.dueDate,
    this.assignedToId,
    required this.assignedToName,
    this.createdBy,
    this.createdByName,
    this.startedAt,
    this.completedAt,
    this.completionNote,
    this.holdReason,
    this.attachmentUrl,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  bool get isCompleted => status == OfficeTaskStatus.completed;
  bool get isInProgress => status == OfficeTaskStatus.inProgress;
  bool get isHold => status == OfficeTaskStatus.hold;
  bool get isPending => status == OfficeTaskStatus.pending;

  bool get isOverdue {
    if (isCompleted || dueDate == null) return false;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final due = DateTime(dueDate!.year, dueDate!.month, dueDate!.day);
    return due.isBefore(today);
  }

  bool get isDueToday {
    if (isCompleted || dueDate == null) return false;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final due = DateTime(dueDate!.year, dueDate!.month, dueDate!.day);
    return due.isAtSameMomentAs(today);
  }

  Color get statusColor => OfficeTaskStatus.getColor(status);
  Color get priorityColor => OfficeTaskPriority.getColor(priority);

  factory OfficeTask.fromMap(Map<String, dynamic> map) {
    return OfficeTask(
      id: map['id']?.toString() ?? '',
      customerId: map['customer_id']?.toString(),
      customerName: map['customer_name']?.toString() ?? '',
      consumerNo: map['consumer_no']?.toString() ?? '',
      village: map['village']?.toString(),
      title: map['title']?.toString() ?? '',
      taskType: map['task_type']?.toString() ?? OfficeTaskType.other,
      description: map['description']?.toString(),
      priority: map['priority']?.toString() ?? OfficeTaskPriority.normal,
      status: map['status']?.toString() ?? OfficeTaskStatus.pending,
      dueDate: map['due_date'] != null
          ? DateTime.tryParse(map['due_date'].toString())
          : null,
      assignedToId: map['assigned_to_id']?.toString(),
      assignedToName: map['assigned_to_name']?.toString() ?? 'Unassigned',
      createdBy: map['created_by']?.toString(),
      createdByName: map['created_by_name']?.toString(),
      startedAt: map['started_at'] != null
          ? DateTime.tryParse(map['started_at'].toString())
          : null,
      completedAt: map['completed_at'] != null
          ? DateTime.tryParse(map['completed_at'].toString())
          : null,
      completionNote: map['completion_note']?.toString(),
      holdReason: map['hold_reason']?.toString(),
      attachmentUrl: map['attachment_url']?.toString(),
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'].toString())
          : DateTime.now(),
      updatedAt: map['updated_at'] != null
          ? DateTime.parse(map['updated_at'].toString())
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'customer_id': customerId,
      'customer_name': customerName,
      'consumer_no': consumerNo,
      'village': village,
      'title': title,
      'task_type': taskType,
      'description': description,
      'priority': priority,
      'status': status,
      'due_date': dueDate?.toIso8601String().split('T').first,
      'assigned_to_id': assignedToId,
      'assigned_to_name': assignedToName,
      'created_by': createdBy,
      'created_by_name': createdByName,
      'started_at': startedAt?.toIso8601String(),
      'completed_at': completedAt?.toIso8601String(),
      'completion_note': completionNote,
      'hold_reason': holdReason,
      'attachment_url': attachmentUrl,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  OfficeTask copyWith({
    String? title,
    String? taskType,
    String? description,
    String? priority,
    String? status,
    DateTime? dueDate,
    String? assignedToId,
    String? assignedToName,
    DateTime? startedAt,
    DateTime? completedAt,
    String? completionNote,
    String? holdReason,
    String? attachmentUrl,
  }) {
    return OfficeTask(
      id: id,
      customerId: customerId,
      customerName: customerName,
      consumerNo: consumerNo,
      village: village,
      title: title ?? this.title,
      taskType: taskType ?? this.taskType,
      description: description ?? this.description,
      priority: priority ?? this.priority,
      status: status ?? this.status,
      dueDate: dueDate ?? this.dueDate,
      assignedToId: assignedToId ?? this.assignedToId,
      assignedToName: assignedToName ?? this.assignedToName,
      createdBy: createdBy,
      createdByName: createdByName,
      startedAt: startedAt ?? this.startedAt,
      completedAt: completedAt ?? this.completedAt,
      completionNote: completionNote ?? this.completionNote,
      holdReason: holdReason ?? this.holdReason,
      attachmentUrl: attachmentUrl ?? this.attachmentUrl,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }
}

class TaskAssignment {
  final String id;
  final String taskId;
  final String? staffId;
  final String staffName;
  final String? assignedBy;
  final String? assignedByName;
  final DateTime assignedAt;
  final String status;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final String? remarks;
  final DateTime createdAt;

  TaskAssignment({
    required this.id,
    required this.taskId,
    this.staffId,
    required this.staffName,
    this.assignedBy,
    this.assignedByName,
    DateTime? assignedAt,
    this.status = 'Assigned',
    this.startedAt,
    this.completedAt,
    this.remarks,
    DateTime? createdAt,
  })  : assignedAt = assignedAt ?? DateTime.now(),
        createdAt = createdAt ?? DateTime.now();

  factory TaskAssignment.fromMap(Map<String, dynamic> map) {
    return TaskAssignment(
      id: map['id']?.toString() ?? '',
      taskId: map['task_id']?.toString() ?? '',
      staffId: map['staff_id']?.toString(),
      staffName: map['staff_name']?.toString() ?? '',
      assignedBy: map['assigned_by']?.toString(),
      assignedByName: map['assigned_by_name']?.toString(),
      assignedAt: map['assigned_at'] != null
          ? DateTime.parse(map['assigned_at'].toString())
          : DateTime.now(),
      status: map['status']?.toString() ?? 'Assigned',
      startedAt: map['started_at'] != null
          ? DateTime.tryParse(map['started_at'].toString())
          : null,
      completedAt: map['completed_at'] != null
          ? DateTime.tryParse(map['completed_at'].toString())
          : null,
      remarks: map['remarks']?.toString(),
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'].toString())
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'task_id': taskId,
      'staff_id': staffId,
      'staff_name': staffName,
      'assigned_by': assignedBy,
      'assigned_by_name': assignedByName,
      'assigned_at': assignedAt.toIso8601String(),
      'status': status,
      'started_at': startedAt?.toIso8601String(),
      'completed_at': completedAt?.toIso8601String(),
      'remarks': remarks,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
