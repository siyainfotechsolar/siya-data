import 'package:flutter/material.dart';

/// Standard 14 Issue Types supported in Solar CRM
class IssueType {
  static const String customerComplaint = 'Customer Complaint';
  static const String documentProblem = 'Document Problem';
  static const String materialProblem = 'Material Problem';
  static const String installationProblem = 'Installation Problem';
  static const String inverterProblem = 'Inverter Problem';
  static const String panelProblem = 'Panel Problem';
  static const String wiringProblem = 'Wiring Problem';
  static const String bankProblem = 'Bank Problem';
  static const String msedclProblem = 'MSEDCL Problem';
  static const String rtsProblem = 'RTS Problem';
  static const String subsidyProblem = 'Subsidy Problem';
  static const String paymentProblem = 'Payment Problem';
  static const String staffTeamProblem = 'Staff/Team Problem';
  static const String other = 'Other';

  static const List<String> allTypes = [
    customerComplaint,
    documentProblem,
    materialProblem,
    installationProblem,
    inverterProblem,
    panelProblem,
    wiringProblem,
    bankProblem,
    msedclProblem,
    rtsProblem,
    subsidyProblem,
    paymentProblem,
    staffTeamProblem,
    other,
  ];
}

/// Standard Issue Statuses
class IssueStatus {
  static const String newIssue = 'New';
  static const String assigned = 'Assigned';
  static const String inProgress = 'In Progress';
  static const String hold = 'Hold';
  static const String resolved = 'Resolved';
  static const String closed = 'Closed';
  static const String cancelled = 'Cancelled';

  static const List<String> allStatuses = [
    newIssue,
    assigned,
    inProgress,
    hold,
    resolved,
    closed,
    cancelled,
  ];
}

/// Standard Issue Priorities
class IssuePriority {
  static const String normal = 'Normal';
  static const String high = 'High';
  static const String urgent = 'Urgent';

  static const List<String> allPriorities = [
    normal,
    high,
    urgent,
  ];
}

/// Model representing a Customer General Issue
class CustomerIssue {
  final String? id;
  final String customerId;
  final String customerName;
  final String consumerNo;
  final String? mobileNumber;
  final String issueType;
  final String title;
  final String? description;
  final String priority;
  final String status;
  final String? assignedStaff;
  final DateTime? assignedDate;
  final DateTime? dueDate;
  final String? holdReason;
  final String? resolutionRemarks;
  final String? remarks;
  final String? createdBy;
  final String? createdByName;
  final DateTime createdAt;
  final String? updatedBy;
  final String? updatedByName;
  final DateTime updatedAt;
  final String? resolvedBy;
  final String? resolvedByName;
  final DateTime? resolvedAt;
  final String? closedBy;
  final String? closedByName;
  final DateTime? closedAt;

  static const List<String> standardTypes = IssueType.allTypes;
  static const List<String> standardStatuses = IssueStatus.allStatuses;
  static const List<String> standardPriorities = IssuePriority.allPriorities;

  const CustomerIssue({
    this.id,
    required this.customerId,
    required this.customerName,
    required this.consumerNo,
    String? mobileNumber,
    String? mobile,
    required this.issueType,
    required this.title,
    this.description,
    this.priority = IssuePriority.normal,
    this.status = IssueStatus.newIssue,
    this.assignedStaff,
    this.assignedDate,
    this.dueDate,
    this.holdReason,
    this.resolutionRemarks,
    this.remarks,
    this.createdBy,
    this.createdByName,
    required this.createdAt,
    this.updatedBy,
    this.updatedByName,
    DateTime? updatedAt,
    this.resolvedBy,
    this.resolvedByName,
    this.resolvedAt,
    this.closedBy,
    this.closedByName,
    this.closedAt,
  })  : mobileNumber = mobileNumber ?? mobile,
        updatedAt = updatedAt ?? createdAt;

  bool get isActive =>
      status == IssueStatus.newIssue ||
      status == IssueStatus.assigned ||
      status == IssueStatus.inProgress ||
      status == IssueStatus.hold;

  bool get isHold => status == IssueStatus.hold;
  bool get isResolved => status == IssueStatus.resolved;
  bool get isClosed => status == IssueStatus.closed;
  bool get isCancelled => status == IssueStatus.cancelled;

  bool get isDueToday {
    if (dueDate == null) return false;
    final now = DateTime.now();
    return dueDate!.year == now.year &&
        dueDate!.month == now.month &&
        dueDate!.day == now.day;
  }

  bool get isOverdue {
    if (dueDate == null || !isActive) return false;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final due = DateTime(dueDate!.year, dueDate!.month, dueDate!.day);
    return due.isBefore(today);
  }

  /// Stuck Issue: Remains 'In Progress' or 'Assigned' > 7 days or past due date
  bool get isStuck {
    if (!isActive) return false;
    if (status != IssueStatus.assigned && status != IssueStatus.inProgress) return false;
    if (isOverdue) return true;
    final sevenDaysAgo = DateTime.now().subtract(const Duration(days: 7));
    return createdAt.isBefore(sevenDaysAgo);
  }

  /// Mobile getter alias
  String? get mobile => mobileNumber;

  Color get typeColor {
    switch (issueType) {
      case IssueType.customerComplaint:
        return const Color(0xFFDC2626); // Red
      case IssueType.documentProblem:
        return const Color(0xFF2563EB); // Blue
      case IssueType.materialProblem:
        return const Color(0xFF0F766E); // Teal
      case IssueType.installationProblem:
      case IssueType.inverterProblem:
      case IssueType.panelProblem:
      case IssueType.wiringProblem:
        return const Color(0xFFD97706); // Amber
      case IssueType.bankProblem:
        return const Color(0xFF7C3AED); // Purple
      case IssueType.msedclProblem:
      case IssueType.rtsProblem:
        return const Color(0xFF0284C7); // Sky
      case IssueType.subsidyProblem:
      case IssueType.paymentProblem:
        return const Color(0xFF059669); // Emerald
      case IssueType.staffTeamProblem:
        return const Color(0xFFE11D48); // Rose
      case IssueType.other:
      default:
        return const Color(0xFF64748B); // Slate
    }
  }

  Color get priorityColor {
    switch (priority) {
      case IssuePriority.urgent:
        return const Color(0xFFDC2626); // Red
      case IssuePriority.high:
        return const Color(0xFFEA580C); // Orange
      case IssuePriority.normal:
      default:
        return const Color(0xFF2563EB); // Blue
    }
  }

  Color get statusColor {
    switch (status) {
      case IssueStatus.newIssue:
        return const Color(0xFF6366F1); // Indigo
      case IssueStatus.assigned:
        return const Color(0xFF0284C7); // Sky
      case IssueStatus.inProgress:
        return const Color(0xFFD97706); // Amber
      case IssueStatus.hold:
        return const Color(0xFF9333EA); // Purple
      case IssueStatus.resolved:
        return const Color(0xFF059669); // Emerald
      case IssueStatus.closed:
        return const Color(0xFF475569); // Slate
      case IssueStatus.cancelled:
        return const Color(0xFFDC2626); // Red
      default:
        return const Color(0xFF64748B);
    }
  }

  factory CustomerIssue.fromJson(Map<String, dynamic> json) {
    return CustomerIssue(
      id: json['id']?.toString(),
      customerId: json['customer_id']?.toString() ?? '',
      customerName: json['customer_name']?.toString() ?? '',
      consumerNo: json['consumer_no']?.toString() ?? '',
      mobileNumber: json['mobile_number']?.toString(),
      issueType: json['issue_type']?.toString() ?? IssueType.other,
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString(),
      priority: json['priority']?.toString() ?? IssuePriority.normal,
      status: json['status']?.toString() ?? IssueStatus.newIssue,
      assignedStaff: json['assigned_staff']?.toString(),
      assignedDate: json['assigned_date'] != null
          ? DateTime.tryParse(json['assigned_date'].toString())
          : null,
      dueDate: json['due_date'] != null
          ? DateTime.tryParse(json['due_date'].toString())
          : null,
      holdReason: json['hold_reason']?.toString(),
      resolutionRemarks: json['resolution_remarks']?.toString(),
      remarks: json['remarks']?.toString(),
      createdBy: json['created_by']?.toString(),
      createdByName: json['created_by_name']?.toString(),
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      updatedBy: json['updated_by']?.toString(),
      updatedByName: json['updated_by_name']?.toString(),
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      resolvedBy: json['resolved_by']?.toString(),
      resolvedByName: json['resolved_by_name']?.toString(),
      resolvedAt: json['resolved_at'] != null
          ? DateTime.tryParse(json['resolved_at'].toString())
          : null,
      closedBy: json['closed_by']?.toString(),
      closedByName: json['closed_by_name']?.toString(),
      closedAt: json['closed_at'] != null
          ? DateTime.tryParse(json['closed_at'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'customer_id': customerId,
      'customer_name': customerName,
      'consumer_no': consumerNo,
      if (mobileNumber != null) 'mobile_number': mobileNumber,
      'issue_type': issueType,
      'title': title,
      if (description != null) 'description': description,
      'priority': priority,
      'status': status,
      if (assignedStaff != null) 'assigned_staff': assignedStaff,
      if (assignedDate != null) 'assigned_date': assignedDate!.toIso8601String(),
      if (dueDate != null) 'due_date': dueDate!.toIso8601String().split('T')[0],
      if (holdReason != null) 'hold_reason': holdReason,
      if (resolutionRemarks != null) 'resolution_remarks': resolutionRemarks,
      if (remarks != null) 'remarks': remarks,
      if (createdBy != null) 'created_by': createdBy,
      if (createdByName != null) 'created_by_name': createdByName,
      'created_at': createdAt.toIso8601String(),
      if (updatedBy != null) 'updated_by': updatedBy,
      if (updatedByName != null) 'updated_by_name': updatedByName,
      'updated_at': updatedAt.toIso8601String(),
      if (resolvedBy != null) 'resolved_by': resolvedBy,
      if (resolvedByName != null) 'resolved_by_name': resolvedByName,
      if (resolvedAt != null) 'resolved_at': resolvedAt!.toIso8601String(),
      if (closedBy != null) 'closed_by': closedBy,
      if (closedByName != null) 'closed_by_name': closedByName,
      if (closedAt != null) 'closed_at': closedAt!.toIso8601String(),
    };
  }

  CustomerIssue copyWith({
    String? id,
    String? customerId,
    String? customerName,
    String? consumerNo,
    String? mobileNumber,
    String? issueType,
    String? title,
    String? description,
    String? priority,
    String? status,
    String? assignedStaff,
    DateTime? assignedDate,
    DateTime? dueDate,
    String? holdReason,
    String? resolutionRemarks,
    String? remarks,
    String? createdBy,
    String? createdByName,
    DateTime? createdAt,
    String? updatedBy,
    String? updatedByName,
    DateTime? updatedAt,
    String? resolvedBy,
    String? resolvedByName,
    DateTime? resolvedAt,
    String? closedBy,
    String? closedByName,
    DateTime? closedAt,
  }) {
    return CustomerIssue(
      id: id ?? this.id,
      customerId: customerId ?? this.customerId,
      customerName: customerName ?? this.customerName,
      consumerNo: consumerNo ?? this.consumerNo,
      mobileNumber: mobileNumber ?? this.mobileNumber,
      issueType: issueType ?? this.issueType,
      title: title ?? this.title,
      description: description ?? this.description,
      priority: priority ?? this.priority,
      status: status ?? this.status,
      assignedStaff: assignedStaff ?? this.assignedStaff,
      assignedDate: assignedDate ?? this.assignedDate,
      dueDate: dueDate ?? this.dueDate,
      holdReason: holdReason ?? this.holdReason,
      resolutionRemarks: resolutionRemarks ?? this.resolutionRemarks,
      remarks: remarks ?? this.remarks,
      createdBy: createdBy ?? this.createdBy,
      createdByName: createdByName ?? this.createdByName,
      createdAt: createdAt ?? this.createdAt,
      updatedBy: updatedBy ?? this.updatedBy,
      updatedByName: updatedByName ?? this.updatedByName,
      updatedAt: updatedAt ?? this.updatedAt,
      resolvedBy: resolvedBy ?? this.resolvedBy,
      resolvedByName: resolvedByName ?? this.resolvedByName,
      resolvedAt: resolvedAt ?? this.resolvedAt,
      closedBy: closedBy ?? this.closedBy,
      closedByName: closedByName ?? this.closedByName,
      closedAt: closedAt ?? this.closedAt,
    );
  }
}

/// Model for Issue History audit record
class CustomerIssueHistory {
  final String? id;
  final String issueId;
  final String actionType;
  String get action => actionType;
  final String? oldValue;
  final String? newValue;
  final String? remarks;
  final String? changedBy;
  final String? changedByName;
  String? get performedByName => changedByName;
  final DateTime createdAt;

  const CustomerIssueHistory({
    this.id,
    required this.issueId,
    String? actionType,
    String? action,
    this.oldValue,
    this.newValue,
    this.remarks,
    this.changedBy,
    String? changedByName,
    String? performedByName,
    required this.createdAt,
  })  : actionType = actionType ?? action ?? 'UPDATE',
        changedByName = changedByName ?? performedByName;

  factory CustomerIssueHistory.fromJson(Map<String, dynamic> json) {
    return CustomerIssueHistory(
      id: json['id']?.toString(),
      issueId: json['issue_id']?.toString() ?? '',
      actionType: json['action_type']?.toString() ?? json['action']?.toString() ?? 'UPDATE',
      oldValue: json['old_value']?.toString(),
      newValue: json['new_value']?.toString(),
      remarks: json['remarks']?.toString(),
      changedBy: json['changed_by']?.toString(),
      changedByName: json['changed_by_name']?.toString() ?? json['performed_by_name']?.toString(),
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'issue_id': issueId,
      'action_type': actionType,
      'action': actionType,
      if (oldValue != null) 'old_value': oldValue,
      if (newValue != null) 'new_value': newValue,
      if (remarks != null) 'remarks': remarks,
      if (changedBy != null) 'changed_by': changedBy,
      if (changedByName != null) 'changed_by_name': changedByName,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
