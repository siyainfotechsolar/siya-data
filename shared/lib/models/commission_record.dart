import 'package:flutter/material.dart';

/// Status constants for Commission workflow
class CommissionStatus {
  static const String pendingApproval = 'Pending Approval';
  static const String approved = 'Approved';
  static const String partiallyPaid = 'Partially Paid';
  static const String paid = 'Paid';
  static const String rejected = 'Rejected';

  static const List<String> allStatuses = [
    'All',
    pendingApproval,
    approved,
    partiallyPaid,
    paid,
    rejected,
  ];

  static Color getStatusColor(String status) {
    switch (status) {
      case approved:
        return const Color(0xFF0284C7); // Sky Blue
      case partiallyPaid:
        return const Color(0xFFD97706); // Amber
      case paid:
        return const Color(0xFF16A34A); // Green
      case rejected:
        return const Color(0xFFDC2626); // Red
      case pendingApproval:
      default:
        return const Color(0xFFF57C00); // Solar Orange
    }
  }

  static IconData getStatusIcon(String status) {
    switch (status) {
      case approved:
        return Icons.verified_outlined;
      case partiallyPaid:
        return Icons.pie_chart_outline_rounded;
      case paid:
        return Icons.check_circle_outline_rounded;
      case rejected:
        return Icons.cancel_outlined;
      case pendingApproval:
      default:
        return Icons.hourglass_top_rounded;
    }
  }
}

/// Commission Record Model
///
/// Represents an individual manual commission entry for an agent.
/// Commission amount is entered manually by the user, never calculated automatically.
class CommissionRecord {
  final String id;
  final String entryNumber;
  final String? agentId;
  final String agentName;
  final String? customerId;
  final String customerName;
  final String? consumerNo;
  final double? solarCapacity; // Optional kW, purely reference
  final DateTime commissionDate;
  final double commissionAmount; // Manual entry
  final double? approvedAmount;
  final double paidAmount; // Actual payments received
  final String status;
  final String? approvedBy;
  final DateTime? approvedAt;
  final String? remarks;
  final bool deleted;
  final String? createdBy;
  final String? updatedBy;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const CommissionRecord({
    required this.id,
    required this.entryNumber,
    this.agentId,
    required this.agentName,
    this.customerId,
    required this.customerName,
    this.consumerNo,
    this.solarCapacity,
    required this.commissionDate,
    required this.commissionAmount,
    this.approvedAmount,
    this.paidAmount = 0.0,
    this.status = CommissionStatus.pendingApproval,
    this.approvedBy,
    this.approvedAt,
    this.remarks,
    this.deleted = false,
    this.createdBy,
    this.updatedBy,
    this.createdAt,
    this.updatedAt,
  });

  /// The amount recognized for payout calculation
  double get effectiveApprovedAmount => approvedAmount ?? commissionAmount;

  /// Pending payout amount = Approved Amount − Total Actual Commission Payments
  double get pendingAmount {
    final diff = effectiveApprovedAmount - paidAmount;
    return diff > 0 ? diff : 0.0;
  }

  bool get isApproved =>
      status == CommissionStatus.approved ||
      status == CommissionStatus.partiallyPaid ||
      status == CommissionStatus.paid;

  bool get isPendingApproval => status == CommissionStatus.pendingApproval;

  bool get isFullyPaid =>
      status == CommissionStatus.paid ||
      (isApproved && effectiveApprovedAmount > 0 && pendingAmount <= 0.01);

  bool get isPartiallyPaid =>
      status == CommissionStatus.partiallyPaid ||
      (paidAmount > 0 && pendingAmount > 0.01);

  CommissionRecord copyWith({
    String? id,
    String? entryNumber,
    String? agentId,
    String? agentName,
    String? customerId,
    String? customerName,
    String? consumerNo,
    double? solarCapacity,
    DateTime? commissionDate,
    double? commissionAmount,
    double? approvedAmount,
    double? paidAmount,
    String? status,
    String? approvedBy,
    DateTime? approvedAt,
    String? remarks,
    bool? deleted,
    String? createdBy,
    String? updatedBy,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return CommissionRecord(
      id: id ?? this.id,
      entryNumber: entryNumber ?? this.entryNumber,
      agentId: agentId ?? this.agentId,
      agentName: agentName ?? this.agentName,
      customerId: customerId ?? this.customerId,
      customerName: customerName ?? this.customerName,
      consumerNo: consumerNo ?? this.consumerNo,
      solarCapacity: solarCapacity ?? this.solarCapacity,
      commissionDate: commissionDate ?? this.commissionDate,
      commissionAmount: commissionAmount ?? this.commissionAmount,
      approvedAmount: approvedAmount ?? this.approvedAmount,
      paidAmount: paidAmount ?? this.paidAmount,
      status: status ?? this.status,
      approvedBy: approvedBy ?? this.approvedBy,
      approvedAt: approvedAt ?? this.approvedAt,
      remarks: remarks ?? this.remarks,
      deleted: deleted ?? this.deleted,
      createdBy: createdBy ?? this.createdBy,
      updatedBy: updatedBy ?? this.updatedBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'entry_number': entryNumber,
      'agent_id': agentId,
      'agent_name': agentName,
      'customer_id': customerId,
      'customer_name': customerName,
      'consumer_no': consumerNo,
      'solar_capacity': solarCapacity,
      'commission_date': commissionDate.toIso8601String().split('T').first,
      'commission_amount': commissionAmount,
      'approved_amount': approvedAmount,
      'paid_amount': paidAmount,
      'status': status,
      'approved_by': approvedBy,
      'approved_at': approvedAt?.toIso8601String(),
      'remarks': remarks,
      'deleted': deleted,
      'created_by': createdBy,
      'updated_by': updatedBy,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  factory CommissionRecord.fromJson(Map<String, dynamic> json) {
    return CommissionRecord(
      id: json['id']?.toString() ?? '',
      entryNumber: json['entry_number']?.toString() ?? '',
      agentId: json['agent_id']?.toString(),
      agentName: json['agent_name']?.toString() ?? 'Unknown Agent',
      customerId: json['customer_id']?.toString(),
      customerName: json['customer_name']?.toString() ?? 'Unknown Customer',
      consumerNo: json['consumer_no']?.toString(),
      solarCapacity: (json['solar_capacity'] is num)
          ? (json['solar_capacity'] as num).toDouble()
          : double.tryParse(json['solar_capacity']?.toString() ?? ''),
      commissionDate: json['commission_date'] != null
          ? DateTime.tryParse(json['commission_date'].toString()) ?? DateTime.now()
          : DateTime.now(),
      commissionAmount: (json['commission_amount'] is num)
          ? (json['commission_amount'] as num).toDouble()
          : (double.tryParse(json['commission_amount']?.toString() ?? '0') ?? 0.0),
      approvedAmount: (json['approved_amount'] is num)
          ? (json['approved_amount'] as num).toDouble()
          : double.tryParse(json['approved_amount']?.toString() ?? ''),
      paidAmount: (json['paid_amount'] is num)
          ? (json['paid_amount'] as num).toDouble()
          : (double.tryParse(json['paid_amount']?.toString() ?? '0') ?? 0.0),
      status: json['status']?.toString() ?? CommissionStatus.pendingApproval,
      approvedBy: json['approved_by']?.toString(),
      approvedAt: json['approved_at'] != null ? DateTime.tryParse(json['approved_at'].toString()) : null,
      remarks: json['remarks']?.toString(),
      deleted: json['deleted'] as bool? ?? false,
      createdBy: json['created_by']?.toString(),
      updatedBy: json['updated_by']?.toString(),
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'].toString()) : null,
      updatedAt: json['updated_at'] != null ? DateTime.tryParse(json['updated_at'].toString()) : null,
    );
  }
}
