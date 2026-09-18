import 'package:flutter/material.dart';

/// Payment Types supported
class PaymentType {
  static const String offline = 'Offline';
  static const String online = 'Online';

  static const List<String> allTypes = [offline, online];
}

/// Payment Modes supported
class PaymentMode {
  static const String cash = 'Cash';
  static const String upi = 'UPI';
  static const String bankTransfer = 'Bank Transfer';
  static const String cheque = 'Cheque';
  static const String neft = 'NEFT';
  static const String rtgs = 'RTGS';
  static const String other = 'Other';

  static const List<String> allModes = [
    upi,
    bankTransfer,
    neft,
    rtgs,
    cash,
    cheque,
    other,
  ];

  static IconData getModeIcon(String mode) {
    switch (mode) {
      case upi:
        return Icons.qr_code_2_rounded;
      case bankTransfer:
      case neft:
      case rtgs:
        return Icons.account_balance_rounded;
      case cash:
        return Icons.payments_outlined;
      case cheque:
        return Icons.edit_note_rounded;
      default:
        return Icons.receipt_long_rounded;
    }
  }
}

/// Payment Statuses (Calculated)
class PaymentStatus {
  static const String pending = 'Pending';
  static const String partiallyPaid = 'Partially Paid';
  static const String paid = 'Paid';
  static const String overdue = 'Overdue';
  static const String followup = 'Payment Follow-up';
  static const String pendingSync = 'Pending Sync';
  static const String refunded = 'Refunded';
  static const String cancelled = 'Cancelled';

  static const List<String> allStatuses = [
    pending,
    partiallyPaid,
    paid,
    overdue,
    followup,
    pendingSync,
    refunded,
    cancelled,
  ];

  static Color statusColor(String status) {
    switch (status) {
      case paid:
        return const Color(0xFF059669);
      case partiallyPaid:
        return const Color(0xFF0284C7);
      case overdue:
        return const Color(0xFFDC2626);
      case followup:
        return const Color(0xFFF59E0B);
      case pendingSync:
        return const Color(0xFFEA580C);
      case refunded:
        return const Color(0xFF9333EA);
      case cancelled:
        return const Color(0xFF64748B);
      case pending:
      default:
        return const Color(0xFFD97706);
    }
  }
}

/// Payment Verification Status
class PaymentVerificationStatus {
  static const String pending = 'Pending';
  static const String verified = 'Verified';
  static const String rejected = 'Rejected';

  static const List<String> allStatuses = [
    pending,
    verified,
    rejected,
  ];

  static Color color(String status) {
    switch (status) {
      case verified:
        return const Color(0xFF059669);
      case rejected:
        return const Color(0xFFDC2626);
      case pending:
      default:
        return const Color(0xFFD97706);
    }
  }
}

/// Transaction Status
class TransactionStatus {
  static const String valid = 'Valid';
  static const String reversed = 'Reversed';
  static const String refunded = 'Refunded';
}

/// Model for a Customer Payment Transaction
class PaymentTransaction {
  final String? id;
  final String? clientTxId;
  final String? idempotencyKey;
  final String customerId;
  final String consumerNo;
  final double amount;
  final DateTime paymentDate;
  final String paymentType; // 'Online', 'Offline'
  final String paymentMode;
  final String? referenceNumber;
  final String? receivedBy;
  final String? remarks;
  final String? attachmentUrl;
  final String? localAttachmentPath;
  final String status; // 'Valid', 'Reversed', 'Refunded'
  final String syncStatus; // 'Synced', 'Pending Sync'
  final String verificationStatus; // 'Pending', 'Verified', 'Rejected'
  final String? verifiedBy;
  final String? verifiedByName;
  final DateTime? verifiedAt;
  final String? verificationRemarks;
  final double? extractedAmount;
  final DateTime? extractedDate;
  final String? extractedRefNo;
  final bool proofMismatch;
  final String? reversalReason;
  final String? createdBy;
  final String? createdByName;
  final DateTime? createdAt;
  final String? updatedBy;
  final String? updatedByName;
  final DateTime? updatedAt;

  const PaymentTransaction({
    this.id,
    this.clientTxId,
    this.idempotencyKey,
    required this.customerId,
    required this.consumerNo,
    required this.amount,
    required this.paymentDate,
    this.paymentType = PaymentType.offline,
    required this.paymentMode,
    this.referenceNumber,
    this.receivedBy,
    this.remarks,
    this.attachmentUrl,
    this.localAttachmentPath,
    this.status = TransactionStatus.valid,
    this.syncStatus = 'Synced',
    this.verificationStatus = PaymentVerificationStatus.pending,
    this.verifiedBy,
    this.verifiedByName,
    this.verifiedAt,
    this.verificationRemarks,
    this.extractedAmount,
    this.extractedDate,
    this.extractedRefNo,
    this.proofMismatch = false,
    this.reversalReason,
    this.createdBy,
    this.createdByName,
    this.createdAt,
    this.updatedBy,
    this.updatedByName,
    this.updatedAt,
  });

  bool get isValid => status == TransactionStatus.valid;
  bool get isReversed => status == TransactionStatus.reversed;
  bool get isPendingSync => syncStatus == 'Pending Sync';
  bool get isVerified => verificationStatus == PaymentVerificationStatus.verified;

  PaymentTransaction copyWith({
    String? id,
    String? clientTxId,
    String? idempotencyKey,
    String? customerId,
    String? consumerNo,
    double? amount,
    DateTime? paymentDate,
    String? paymentType,
    String? paymentMode,
    String? referenceNumber,
    String? receivedBy,
    String? remarks,
    String? attachmentUrl,
    String? localAttachmentPath,
    String? status,
    String? syncStatus,
    String? verificationStatus,
    String? verifiedBy,
    String? verifiedByName,
    DateTime? verifiedAt,
    String? verificationRemarks,
    double? extractedAmount,
    DateTime? extractedDate,
    String? extractedRefNo,
    bool? proofMismatch,
    String? reversalReason,
    String? createdBy,
    String? createdByName,
    DateTime? createdAt,
    String? updatedBy,
    String? updatedByName,
    DateTime? updatedAt,
  }) {
    return PaymentTransaction(
      id: id ?? this.id,
      clientTxId: clientTxId ?? this.clientTxId,
      idempotencyKey: idempotencyKey ?? this.idempotencyKey,
      customerId: customerId ?? this.customerId,
      consumerNo: consumerNo ?? this.consumerNo,
      amount: amount ?? this.amount,
      paymentDate: paymentDate ?? this.paymentDate,
      paymentType: paymentType ?? this.paymentType,
      paymentMode: paymentMode ?? this.paymentMode,
      referenceNumber: referenceNumber ?? this.referenceNumber,
      receivedBy: receivedBy ?? this.receivedBy,
      remarks: remarks ?? this.remarks,
      attachmentUrl: attachmentUrl ?? this.attachmentUrl,
      localAttachmentPath: localAttachmentPath ?? this.localAttachmentPath,
      status: status ?? this.status,
      syncStatus: syncStatus ?? this.syncStatus,
      verificationStatus: verificationStatus ?? this.verificationStatus,
      verifiedBy: verifiedBy ?? this.verifiedBy,
      verifiedByName: verifiedByName ?? this.verifiedByName,
      verifiedAt: verifiedAt ?? this.verifiedAt,
      verificationRemarks: verificationRemarks ?? this.verificationRemarks,
      extractedAmount: extractedAmount ?? this.extractedAmount,
      extractedDate: extractedDate ?? this.extractedDate,
      extractedRefNo: extractedRefNo ?? this.extractedRefNo,
      proofMismatch: proofMismatch ?? this.proofMismatch,
      reversalReason: reversalReason ?? this.reversalReason,
      createdBy: createdBy ?? this.createdBy,
      createdByName: createdByName ?? this.createdByName,
      createdAt: createdAt ?? this.createdAt,
      updatedBy: updatedBy ?? this.updatedBy,
      updatedByName: updatedByName ?? this.updatedByName,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory PaymentTransaction.fromJson(Map<String, dynamic> json) {
    return PaymentTransaction(
      id: json['id']?.toString(),
      clientTxId: json['client_tx_id']?.toString(),
      idempotencyKey: json['idempotency_key']?.toString(),
      customerId: json['customer_id']?.toString() ?? '',
      consumerNo: json['consumer_no']?.toString() ?? '',
      amount: (json['amount'] is num)
          ? (json['amount'] as num).toDouble()
          : double.tryParse(json['amount']?.toString() ?? '0') ?? 0.0,
      paymentDate: json['payment_date'] != null
          ? DateTime.tryParse(json['payment_date'].toString()) ?? DateTime.now()
          : DateTime.now(),
      paymentType: json['payment_type']?.toString() ?? PaymentType.offline,
      paymentMode: json['payment_mode']?.toString() ?? PaymentMode.other,
      referenceNumber: json['reference_number']?.toString(),
      receivedBy: json['received_by']?.toString(),
      remarks: json['remarks']?.toString(),
      attachmentUrl: json['attachment_url']?.toString(),
      localAttachmentPath: json['local_attachment_path']?.toString(),
      status: json['status']?.toString() ?? TransactionStatus.valid,
      syncStatus: json['sync_status']?.toString() ?? 'Synced',
      verificationStatus: json['verification_status']?.toString() ?? PaymentVerificationStatus.pending,
      verifiedBy: json['verified_by']?.toString(),
      verifiedByName: json['verified_by_name']?.toString(),
      verifiedAt: json['verified_at'] != null ? DateTime.tryParse(json['verified_at'].toString()) : null,
      verificationRemarks: json['verification_remarks']?.toString(),
      extractedAmount: json['extracted_amount'] != null
          ? double.tryParse(json['extracted_amount'].toString())
          : null,
      extractedDate: json['extracted_date'] != null
          ? DateTime.tryParse(json['extracted_date'].toString())
          : null,
      extractedRefNo: json['extracted_ref_no']?.toString(),
      proofMismatch: json['proof_mismatch'] == true || json['proof_mismatch'] == 1,
      reversalReason: json['reversal_reason']?.toString(),
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
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      if (clientTxId != null) 'client_tx_id': clientTxId,
      if (idempotencyKey != null) 'idempotency_key': idempotencyKey,
      'customer_id': customerId,
      'consumer_no': consumerNo,
      'amount': amount,
      'payment_date': paymentDate.toIso8601String().split('T')[0],
      'payment_type': paymentType,
      'payment_mode': paymentMode,
      if (referenceNumber != null) 'reference_number': referenceNumber,
      if (receivedBy != null) 'received_by': receivedBy,
      if (remarks != null) 'remarks': remarks,
      if (attachmentUrl != null) 'attachment_url': attachmentUrl,
      if (localAttachmentPath != null) 'local_attachment_path': localAttachmentPath,
      'status': status,
      'sync_status': syncStatus,
      'verification_status': verificationStatus,
      if (verifiedBy != null) 'verified_by': verifiedBy,
      if (verifiedByName != null) 'verified_by_name': verifiedByName,
      if (verifiedAt != null) 'verified_at': verifiedAt!.toIso8601String(),
      if (verificationRemarks != null) 'verification_remarks': verificationRemarks,
      if (extractedAmount != null) 'extracted_amount': extractedAmount,
      if (extractedDate != null) 'extracted_date': extractedDate!.toIso8601String().split('T')[0],
      if (extractedRefNo != null) 'extracted_ref_no': extractedRefNo,
      'proof_mismatch': proofMismatch,
      if (reversalReason != null) 'reversal_reason': reversalReason,
      if (createdBy != null) 'created_by': createdBy,
      if (createdByName != null) 'created_by_name': createdByName,
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
      if (updatedBy != null) 'updated_by': updatedBy,
      if (updatedByName != null) 'updated_by_name': updatedByName,
      if (updatedAt != null) 'updated_at': updatedAt!.toIso8601String(),
    };
  }
}

/// Summary helper for customer balance calculations
class CustomerPaymentSummary {
  final double totalAmount;
  final double paidAmount;
  final double pendingAmount;
  final String paymentStatus;
  final DateTime? paymentDueDate;
  final DateTime? lastPaymentDate;
  final double? lastPaymentAmount;
  final int totalTransactionsCount;
  final int pendingSyncCount;

  const CustomerPaymentSummary({
    required this.totalAmount,
    required this.paidAmount,
    required this.pendingAmount,
    required this.paymentStatus,
    this.paymentDueDate,
    this.lastPaymentDate,
    this.lastPaymentAmount,
    this.totalTransactionsCount = 0,
    this.pendingSyncCount = 0,
  });

  bool get isPaid => paymentStatus == PaymentStatus.paid;
  bool get isOverdue => paymentStatus == PaymentStatus.overdue;
  bool get isPartiallyPaid => paymentStatus == PaymentStatus.partiallyPaid;
  bool get isPending => paymentStatus == PaymentStatus.pending;
  bool get hasPendingSync => pendingSyncCount > 0;
  String get status => paymentStatus;
  double get paidPercentage => totalAmount > 0 ? ((paidAmount / totalAmount) * 100).clamp(0.0, 100.0) : 0.0;
}

/// Installation Milestone Rule linking Installation stage to financial requirements
class InstallationPaymentStageRule {
  final String stageName;
  final double requiredPercentage; // e.g., 0.20 for 20%
  final String nextStageName;
  final String description;

  const InstallationPaymentStageRule({
    required this.stageName,
    required this.requiredPercentage,
    required this.nextStageName,
    required this.description,
  });

  static const List<InstallationPaymentStageRule> standardRules = [
    InstallationPaymentStageRule(
      stageName: 'Survey',
      requiredPercentage: 0.20,
      nextStageName: 'Structure',
      description: '20% Advance required before structure work begins',
    ),
    InstallationPaymentStageRule(
      stageName: 'Structure',
      requiredPercentage: 0.35,
      nextStageName: 'Panel Installation',
      description: '35% Milestone required before solar panels dispatch',
    ),
    InstallationPaymentStageRule(
      stageName: 'Panel',
      requiredPercentage: 0.60,
      nextStageName: 'Inverter & Wiring',
      description: '60% Milestone required before wiring and inverter installation',
    ),
    InstallationPaymentStageRule(
      stageName: 'Inverter',
      requiredPercentage: 0.80,
      nextStageName: 'Testing & Net Metering',
      description: '80% Milestone required before net meter application',
    ),
    InstallationPaymentStageRule(
      stageName: 'Wiring',
      requiredPercentage: 0.90,
      nextStageName: 'RTS Inspection',
      description: '90% Milestone required before DISCOM inspection',
    ),
    InstallationPaymentStageRule(
      stageName: 'RTS',
      requiredPercentage: 1.00,
      nextStageName: 'Commissioning',
      description: '100% Full balance required before system commissioning',
    ),
  ];

  static InstallationPaymentStageRule? getRuleForStage(String currentStage) {
    final lower = currentStage.toLowerCase();
    for (final rule in standardRules) {
      if (lower.contains(rule.stageName.toLowerCase())) {
        return rule;
      }
    }
    return null;
  }
}

/// Operational Dashboard Aggregate Summary
class PaymentDashboardSummary {
  final double todayCollection;
  final double monthCollection;
  final double totalContractAmount;
  final double totalPaidAmount;
  final double totalPendingAmount;
  final int todayPaymentsCount;
  final int pendingPaymentsCount;
  final int pendingSyncCount;
  final int activeFollowupsCount;
  final int unverifiedPaymentsCount;

  const PaymentDashboardSummary({
    required this.todayCollection,
    required this.monthCollection,
    required this.totalContractAmount,
    required this.totalPaidAmount,
    required this.totalPendingAmount,
    required this.todayPaymentsCount,
    required this.pendingPaymentsCount,
    required this.pendingSyncCount,
    required this.activeFollowupsCount,
    this.unverifiedPaymentsCount = 0,
  });

  factory PaymentDashboardSummary.empty() {
    return const PaymentDashboardSummary(
      todayCollection: 0.0,
      monthCollection: 0.0,
      totalContractAmount: 0.0,
      totalPaidAmount: 0.0,
      totalPendingAmount: 0.0,
      todayPaymentsCount: 0,
      pendingPaymentsCount: 0,
      pendingSyncCount: 0,
      activeFollowupsCount: 0,
      unverifiedPaymentsCount: 0,
    );
  }
}

/// Payment Followup Record Model
class PaymentFollowupRecord {
  final String id;
  final String customerId;
  final String consumerNo;
  final String customerName;
  final DateTime followupDate;
  final String? assignedStaff;
  final String remarks;
  final double pendingAmount;
  final String status; // 'PENDING', 'COMPLETED'
  final DateTime createdAt;

  const PaymentFollowupRecord({
    required this.id,
    required this.customerId,
    required this.consumerNo,
    required this.customerName,
    required this.followupDate,
    this.assignedStaff,
    required this.remarks,
    required this.pendingAmount,
    this.status = 'PENDING',
    required this.createdAt,
  });

  bool get isPending => status == 'PENDING';
  bool get isOverdue => isPending && followupDate.isBefore(DateTime.now());
  bool get isToday {
    final now = DateTime.now();
    return followupDate.year == now.year &&
        followupDate.month == now.month &&
        followupDate.day == now.day;
  }
}

/// Backward compatibility and naming aliases
typedef CustomerPaymentTransaction = PaymentTransaction;
typedef CustomerPaymentCalculation = CustomerPaymentSummary;
