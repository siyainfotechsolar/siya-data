import 'package:flutter/material.dart';

class CustomerMiscAction {
  final String? id;
  final String recordId;
  final String consumerNo;
  final String customerName;
  final String? mobile;
  final String reason;
  final String? description;
  final String? assignedStaffId;
  final String? assignedStaffName;
  final DateTime? dueDate;
  final String priority;
  final String status;
  final String? remarks;
  final String? holdReason;
  final String? createdBy;
  final String? createdByName;
  final DateTime createdAt;
  final String? completedBy;
  final String? completedByName;
  final DateTime? completedAt;

  static const List<String> standardReasons = [
    'Customer Details Correction',
    'Document Request',
    'Site Visit Required',
    'Customer Callback',
    'Mobile Number Update',
    'Address Correction',
    'Bank Related Other Request',
    'MSEDCL Related Other Request',
    'Material Related Request',
    'Other Customer Request',
    'Manual Staff Action',
  ];

  static const List<String> standardPriorities = [
    'Low',
    'Medium',
    'High',
    'Urgent',
  ];

  static const List<String> standardStatuses = [
    'Pending',
    'In Progress',
    'Hold',
    'Completed',
    'Cancelled',
  ];

  const CustomerMiscAction({
    this.id,
    required this.recordId,
    required this.consumerNo,
    required this.customerName,
    this.mobile,
    required this.reason,
    this.description,
    this.assignedStaffId,
    this.assignedStaffName,
    this.dueDate,
    this.priority = 'Medium',
    this.status = 'Pending',
    this.remarks,
    this.holdReason,
    this.createdBy,
    this.createdByName,
    required this.createdAt,
    this.completedBy,
    this.completedByName,
    this.completedAt,
  });

  bool get isActive => status == 'Pending' || status == 'In Progress';
  bool get isHold => status == 'Hold';
  bool get isCompleted => status == 'Completed';

  bool get isOverdue {
    if (dueDate == null || !isActive) return false;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final due = DateTime(dueDate!.year, dueDate!.month, dueDate!.day);
    return due.isBefore(today);
  }

  bool get isDueToday {
    if (dueDate == null || !isActive) return false;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final due = DateTime(dueDate!.year, dueDate!.month, dueDate!.day);
    return due.isAtSameMomentAs(today);
  }

  Color get priorityColor {
    switch (priority.toLowerCase()) {
      case 'urgent':
        return const Color(0xFFDC2626);
      case 'high':
        return const Color(0xFFEA580C);
      case 'low':
        return const Color(0xFF16A34A);
      case 'medium':
      default:
        return const Color(0xFF2563EB);
    }
  }

  Color get statusColor {
    switch (status.toLowerCase()) {
      case 'completed':
        return const Color(0xFF059669);
      case 'hold':
        return const Color(0xFFD97706);
      case 'in progress':
        return const Color(0xFF2563EB);
      case 'cancelled':
        return Colors.grey.shade600;
      case 'pending':
      default:
        return const Color(0xFF4F46E5);
    }
  }

  factory CustomerMiscAction.fromJson(Map<String, dynamic> json) {
    return CustomerMiscAction(
      id: json['id'] as String?,
      recordId: json['record_id'] as String? ?? '',
      consumerNo: json['consumer_no'] as String? ?? '',
      customerName: json['customer_name'] as String? ?? '',
      mobile: json['mobile'] as String?,
      reason: json['reason'] as String? ?? 'Manual Staff Action',
      description: json['description'] as String?,
      assignedStaffId: json['assigned_staff_id'] as String?,
      assignedStaffName: json['assigned_staff_name'] as String?,
      dueDate: json['due_date'] != null
          ? DateTime.tryParse(json['due_date'].toString())
          : null,
      priority: json['priority'] as String? ?? 'Medium',
      status: json['status'] as String? ?? 'Pending',
      remarks: json['remarks'] as String?,
      holdReason: json['hold_reason'] as String?,
      createdBy: json['created_by'] as String?,
      createdByName: json['created_by_name'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      completedBy: json['completed_by'] as String?,
      completedByName: json['completed_by_name'] as String?,
      completedAt: json['completed_at'] != null
          ? DateTime.tryParse(json['completed_at'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'record_id': recordId,
      'consumer_no': consumerNo,
      'customer_name': customerName,
      'mobile': mobile,
      'reason': reason,
      'description': description,
      'assigned_staff_id': assignedStaffId,
      'assigned_staff_name': assignedStaffName,
      'due_date': dueDate?.toIso8601String().split('T')[0],
      'priority': priority,
      'status': status,
      'remarks': remarks,
      'hold_reason': holdReason,
      'created_by': createdBy,
      'created_by_name': createdByName,
      'created_at': createdAt.toIso8601String(),
      'completed_by': completedBy,
      'completed_by_name': completedByName,
      'completed_at': completedAt?.toIso8601String(),
    };
    if (id != null) {
      map['id'] = id;
    }
    return map;
  }

  CustomerMiscAction copyWith({
    String? id,
    String? recordId,
    String? consumerNo,
    String? customerName,
    String? mobile,
    String? reason,
    String? description,
    String? assignedStaffId,
    String? assignedStaffName,
    DateTime? dueDate,
    String? priority,
    String? status,
    String? remarks,
    String? holdReason,
    String? createdBy,
    String? createdByName,
    DateTime? createdAt,
    String? completedBy,
    String? completedByName,
    DateTime? completedAt,
  }) {
    return CustomerMiscAction(
      id: id ?? this.id,
      recordId: recordId ?? this.recordId,
      consumerNo: consumerNo ?? this.consumerNo,
      customerName: customerName ?? this.customerName,
      mobile: mobile ?? this.mobile,
      reason: reason ?? this.reason,
      description: description ?? this.description,
      assignedStaffId: assignedStaffId ?? this.assignedStaffId,
      assignedStaffName: assignedStaffName ?? this.assignedStaffName,
      dueDate: dueDate ?? this.dueDate,
      priority: priority ?? this.priority,
      status: status ?? this.status,
      remarks: remarks ?? this.remarks,
      holdReason: holdReason ?? this.holdReason,
      createdBy: createdBy ?? this.createdBy,
      createdByName: createdByName ?? this.createdByName,
      createdAt: createdAt ?? this.createdAt,
      completedBy: completedBy ?? this.completedBy,
      completedByName: completedByName ?? this.completedByName,
      completedAt: completedAt ?? this.completedAt,
    );
  }
}
