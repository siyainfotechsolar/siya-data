import 'package:intl/intl.dart';

class ActivityLog {
  final String id;
  final String? recordId;
  final String consumerNo;
  final String customerName;
  final String village;
  final String module;
  final String action;
  final String? oldValue;
  final String? newValue;
  final String? nextAction;
  final String? remarks;
  final String? staffId;
  final String staffName;
  final String staffRole;
  final String source;
  final Map<String, dynamic>? metadata;
  final DateTime createdAt;

  ActivityLog({
    required this.id,
    this.recordId,
    required this.consumerNo,
    required this.customerName,
    required this.village,
    required this.module,
    required this.action,
    this.oldValue,
    this.newValue,
    this.nextAction,
    this.remarks,
    this.staffId,
    required this.staffName,
    required this.staffRole,
    required this.source,
    this.metadata,
    required this.createdAt,
  });

  factory ActivityLog.fromJson(Map<String, dynamic> json) {
    DateTime parsedDate;
    try {
      parsedDate = json['created_at'] != null
          ? DateTime.parse(json['created_at'].toString()).toLocal()
          : DateTime.now();
    } catch (_) {
      parsedDate = DateTime.now();
    }

    return ActivityLog(
      id: json['id']?.toString() ?? '',
      recordId: json['record_id']?.toString(),
      consumerNo: json['consumer_no']?.toString() ?? '',
      customerName: json['customer_name']?.toString() ?? 'Unknown Customer',
      village: json['village']?.toString() ?? '-',
      module: json['module']?.toString() ?? 'General',
      action: json['action']?.toString() ?? 'Updated',
      oldValue: json['old_value']?.toString(),
      newValue: json['new_value']?.toString(),
      nextAction: json['next_action']?.toString(),
      remarks: json['remarks']?.toString(),
      staffId: json['staff_id']?.toString(),
      staffName: json['staff_name']?.toString() ?? 'Staff Member',
      staffRole: json['staff_role']?.toString() ?? 'staff',
      source: json['source']?.toString() ?? 'Admin Web',
      metadata: json['metadata'] is Map<String, dynamic> ? json['metadata'] : null,
      createdAt: parsedDate,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id.isNotEmpty) 'id': id,
      if (recordId != null) 'record_id': recordId,
      'consumer_no': consumerNo,
      'customer_name': customerName,
      'village': village,
      'module': module,
      'action': action,
      'old_value': oldValue,
      'new_value': newValue,
      'next_action': nextAction,
      'remarks': remarks,
      'staff_id': staffId,
      'staff_name': staffName,
      'staff_role': staffRole,
      'source': source,
      if (metadata != null) 'metadata': metadata,
      'created_at': createdAt.toUtc().toIso8601String(),
    };
  }

  String get formattedDate => DateFormat('dd/MM/yyyy').format(createdAt);
  String get formattedTime => DateFormat('hh:mm a').format(createdAt);
  String get formattedDateTime => DateFormat('dd/MM/yyyy hh:mm a').format(createdAt);

  bool get isToday {
    final now = DateTime.now();
    return createdAt.year == now.year &&
        createdAt.month == now.month &&
        createdAt.day == now.day;
  }
}

class StaffWorkMetric {
  final String staffName;
  final String staffRole;
  final int totalActions;
  final int customersWorked;
  final int completed;
  final int pending;
  final int followups;
  final int issues;
  final int installations;
  final int payments;

  const StaffWorkMetric({
    required this.staffName,
    required this.staffRole,
    required this.totalActions,
    required this.customersWorked,
    required this.completed,
    required this.pending,
    required this.followups,
    required this.issues,
    required this.installations,
    required this.payments,
  });
}
