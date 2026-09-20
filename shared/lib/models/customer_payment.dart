import 'package:flutter/material.dart';

/// Payment Types (Simple & Clean: 1st Payment, 2nd Payment, Additional Payment)
class PaymentType {
  static const String firstPayment = '1st Payment';
  static const String secondPayment = '2nd Payment';
  static const String additional = 'Additional Payment';
  static const String general = 'Payment';

  // Backward compatibility aliases
  static const String contract = '1st Payment';
  static const String offline = '1st Payment';
  static const String online = '1st Payment';

  static const List<String> loanTypes = [firstPayment, secondPayment, additional];
  static const List<String> normalTypes = [general, additional];
  static const List<String> allTypes = [firstPayment, secondPayment, additional, general, 'CONTRACT', 'ADDITIONAL'];

  static String displayName(String type) {
    final t = type.trim();
    if (isAdditionalType(t)) {
      return 'Additional Payment';
    }
    if (isFirst(t)) {
      return '1st Payment';
    }
    if (isSecond(t)) {
      return '2nd Payment';
    }
    return t.isNotEmpty ? t : 'Payment';
  }

  static bool isFirst(String type) {
    final t = type.trim().toLowerCase();
    return t == '1st payment' || t == '1st_payment' || t == '1st installment' || t == 'contract';
  }

  static bool isSecond(String type) {
    final t = type.trim().toLowerCase();
    return t == '2nd payment' || t == '2nd_payment' || t == '2nd installment';
  }

  static bool isAdditionalType(String type) {
    final t = type.trim().toLowerCase();
    return t == 'additional' || t == 'additional payment' || t == 'additional_payment';
  }
}

/// Additional Payment Categories
class AdditionalPaymentCategory {
  // Mobile categories
  static const String extraMaterial = 'EXTRA_MATERIAL';
  static const String extraWork = 'EXTRA_WORK';
  static const String additionalInstallation = 'ADDITIONAL_INSTALLATION';
  static const String transport = 'TRANSPORT';
  static const String serviceCharge = 'SERVICE_CHARGE';
  static const String other = 'OTHER';

  // Admin categories
  static const String extraCivilWork = 'EXTRA_CIVIL_WORK';
  static const String meterShift = 'METER_SHIFT';
  static const String structureHeightIncrease = 'STRUCTURE_HEIGHT_INCREASE';
  static const String earthingLightningArrester = 'EARTHING_LIGHTNING_ARRESTER';
  static const String transportExtraDistance = 'TRANSPORT_EXTRA_DISTANCE';
  static const String extraCableWiring = 'EXTRA_CABLE_WIRING';
  static const String liaisoningDiscomCharges = 'LIAISONING_DISCOM_CHARGES';
  static const String otherMiscellaneous = 'OTHER_MISCELLANEOUS';

  static const List<String> allCategories = [
    extraMaterial,
    extraWork,
    additionalInstallation,
    transport,
    serviceCharge,
    other,
    extraCivilWork,
    meterShift,
    structureHeightIncrease,
    earthingLightningArrester,
    transportExtraDistance,
    extraCableWiring,
    liaisoningDiscomCharges,
    otherMiscellaneous,
  ];

  static String displayName(String cat) {
    switch (cat.toUpperCase()) {
      case 'EXTRA_MATERIAL':
        return 'Extra Material';
      case 'EXTRA_WORK':
        return 'Extra Work';
      case 'ADDITIONAL_INSTALLATION':
        return 'Additional Installation';
      case 'TRANSPORT':
        return 'Transport';
      case 'SERVICE_CHARGE':
        return 'Service Charge';
      case 'OTHER':
        return 'Other';
      case 'EXTRA_CIVIL_WORK':
        return 'Extra Civil Work';
      case 'METER_SHIFT':
        return 'Meter Shifting';
      case 'STRUCTURE_HEIGHT_INCREASE':
        return 'Structure Height Increase';
      case 'EARTHING_LIGHTNING_ARRESTER':
        return 'Earthing & Lightning Arrester';
      case 'TRANSPORT_EXTRA_DISTANCE':
        return 'Transport (Extra Distance)';
      case 'EXTRA_CABLE_WIRING':
        return 'Extra Cable / Wiring';
      case 'LIAISONING_DISCOM_CHARGES':
        return 'Liaisoning / DISCOM Charges';
      case 'OTHER_MISCELLANEOUS':
      default:
        return 'Other Miscellaneous';
    }
  }

  static IconData getIcon(String category) {
    switch (category.toUpperCase()) {
      case 'EXTRA_MATERIAL':
        return Icons.inventory_2_rounded;
      case 'EXTRA_WORK':
        return Icons.construction_rounded;
      case 'ADDITIONAL_INSTALLATION':
        return Icons.solar_power_rounded;
      case 'TRANSPORT':
        return Icons.local_shipping_rounded;
      case 'SERVICE_CHARGE':
        return Icons.room_service_rounded;
      case 'OTHER':
        return Icons.more_horiz_rounded;
      case 'EXTRA_CIVIL_WORK':
        return Icons.foundation;
      case 'METER_SHIFT':
        return Icons.electric_meter;
      case 'STRUCTURE_HEIGHT_INCREASE':
        return Icons.height;
      case 'EARTHING_LIGHTNING_ARRESTER':
        return Icons.bolt;
      case 'TRANSPORT_EXTRA_DISTANCE':
        return Icons.local_shipping;
      case 'EXTRA_CABLE_WIRING':
        return Icons.cable;
      case 'LIAISONING_DISCOM_CHARGES':
        return Icons.receipt_long;
      case 'OTHER_MISCELLANEOUS':
      default:
        return Icons.handyman;
    }
  }

  static IconData getCategoryIcon(String cat) => getIcon(cat);
}

/// Payment Modes (Unified across Mobile & Admin)
class PaymentMode {
  static const String cash = 'Cash';
  static const String upi = 'UPI';
  static const String bankTransfer = 'Bank Transfer';
  static const String cheque = 'Cheque';
  static const String neft = 'NEFT';
  static const String rtgs = 'RTGS';
  static const String other = 'Other';

  static const List<String> allModes = [
    cash,
    upi,
    bankTransfer,
    cheque,
    neft,
    rtgs,
    other,
  ];

  static bool isValid(String mode) => allModes.contains(mode);

  static IconData getIcon(String mode) {
    switch (mode) {
      case cash:
        return Icons.money;
      case upi:
        return Icons.qr_code_scanner;
      case bankTransfer:
      case neft:
      case rtgs:
        return Icons.account_balance;
      case cheque:
        return Icons.description;
      case other:
      default:
        return Icons.payment;
    }
  }

  static IconData getModeIcon(String mode) => getIcon(mode);
}

/// Payment Statuses
class PaymentStatus {
  static const String pending = 'Pending';
  static const String partiallyPaid = 'Partially Paid';
  static const String paid = 'Paid';
  static const String overdue = 'Overdue';
  static const String followup = 'Follow-up Due';
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
        return const Color(0xFF059669); // Emerald
      case partiallyPaid:
        return const Color(0xFF0284C7); // Sky
      case overdue:
        return const Color(0xFFDC2626); // Red
      case followup:
        return const Color(0xFFF59E0B); // Amber
      case pendingSync:
        return const Color(0xFFEA580C); // Orange
      case refunded:
        return const Color(0xFF9333EA); // Purple
      case cancelled:
        return const Color(0xFF64748B); // Slate
      case pending:
      default:
        return const Color(0xFFD97706); // Amber
    }
  }
}

/// Verification Statuses for Bank & Admin Reconciliation
class PaymentVerificationStatus {
  static const String pending = 'Pending';
  static const String verified = 'Verified';
  static const String rejected = 'Rejected';
  static const String voided = 'Void';

  static const List<String> allStatuses = [
    pending,
    verified,
    rejected,
    voided,
  ];

  static Color statusColor(String status) {
    switch (status) {
      case verified:
        return const Color(0xFF059669);
      case rejected:
        return const Color(0xFFDC2626);
      case voided:
        return const Color(0xFF475569);
      case pending:
      default:
        return const Color(0xFFD97706);
    }
  }

  static Color color(String status) => statusColor(status);
}

/// Transaction Lifecycle Statuses
class TransactionStatus {
  static const String valid = 'Valid';
  static const String reversed = 'Reversed';
  static const String refunded = 'Refunded';
  static const String voided = 'Void';
}

/// Model for a Customer Payment Transaction (Central Database Schema Parity)
class PaymentTransaction {
  static const List<String> standardModes = PaymentMode.allModes;

  final String? id;
  final String? clientTxId;
  final String? idempotencyKey;
  final String customerId;
  final String consumerNo;
  final String? customerName;
  final String? village;
  final String? mobileNumber;
  final double amount;
  final DateTime paymentDate;
  final String paymentType;
  final String? additionalCategory;
  final String paymentMode;
  final String? referenceNumber;
  final String? receivedBy;
  final String? remarks;
  final String? attachmentUrl;
  final String? localAttachmentPath;
  final String status;
  final String? reversalReason;
  final String? voidReason;
  final String verificationStatus;
  final String? verifiedBy;
  final String? verifiedByName;
  final DateTime? verifiedAt;
  final String? verificationRemarks;
  final double? extractedAmount;
  final DateTime? extractedDate;
  final String? extractedRefNo;
  final bool proofMismatch;
  final String syncStatus;
  final String? createdBy;
  final String? createdByName;
  final DateTime? createdAt;
  final String? updatedBy;
  final String? updatedByName;
  final DateTime? updatedAt;

  PaymentTransaction({
    this.id,
    this.clientTxId,
    this.idempotencyKey,
    required this.customerId,
    required this.consumerNo,
    this.customerName,
    this.village,
    this.mobileNumber,
    required this.amount,
    required this.paymentDate,
    this.paymentType = PaymentType.contract,
    this.additionalCategory,
    required this.paymentMode,
    this.referenceNumber,
    this.receivedBy,
    this.remarks,
    this.attachmentUrl,
    this.localAttachmentPath,
    this.status = TransactionStatus.valid,
    this.reversalReason,
    this.voidReason,
    this.verificationStatus = PaymentVerificationStatus.pending,
    this.verifiedBy,
    this.verifiedByName,
    this.verifiedAt,
    this.verificationRemarks,
    this.extractedAmount,
    this.extractedDate,
    this.extractedRefNo,
    this.proofMismatch = false,
    this.syncStatus = 'Synced',
    this.createdBy,
    this.createdByName,
    this.createdAt,
    this.updatedBy,
    this.updatedByName,
    this.updatedAt,
  });

  bool get isValid => status == TransactionStatus.valid;
  bool get isReversed => status == TransactionStatus.reversed;
  bool get isVoid => status == TransactionStatus.voided || verificationStatus == PaymentVerificationStatus.voided;
  bool get isVerified => verificationStatus == PaymentVerificationStatus.verified;
  bool get isPendingVerification => verificationStatus == PaymentVerificationStatus.pending;
  bool get isRejected => verificationStatus == PaymentVerificationStatus.rejected;
  bool get isSynced => syncStatus == 'Synced';
  bool get isPendingSync => syncStatus == 'Pending Sync';

  bool get isAdditional => PaymentType.isAdditionalType(paymentType);
  bool get isFirstPayment => PaymentType.isFirst(paymentType);
  bool get isSecondPayment => PaymentType.isSecond(paymentType);
  bool get isContract => !isAdditional;

  String get typeDisplayName => PaymentType.displayName(paymentType);
  String get categoryDisplayName =>
      additionalCategory != null ? AdditionalPaymentCategory.displayName(additionalCategory!) : '—';

  factory PaymentTransaction.fromJson(Map<String, dynamic> json) {
    return PaymentTransaction(
      id: json['id']?.toString(),
      clientTxId: json['client_tx_id']?.toString(),
      idempotencyKey: json['idempotency_key']?.toString(),
      customerId: json['customer_id']?.toString() ?? '',
      consumerNo: json['consumer_no']?.toString() ?? '',
      customerName: json['customer_name']?.toString() ?? json['customer']?['customer_name']?.toString(),
      village: json['village']?.toString() ?? json['customer']?['village']?.toString(),
      mobileNumber: json['mobile_number']?.toString() ?? json['customer']?['mobile_number']?.toString(),
      amount: (json['amount'] is num)
          ? (json['amount'] as num).toDouble()
          : double.tryParse(json['amount']?.toString() ?? '0') ?? 0.0,
      paymentDate: json['payment_date'] != null
          ? DateTime.tryParse(json['payment_date'].toString()) ?? DateTime.now()
          : DateTime.now(),
      paymentType: json['payment_type']?.toString() ?? PaymentType.contract,
      additionalCategory: json['additional_category']?.toString(),
      paymentMode: json['payment_mode']?.toString() ?? PaymentMode.cash,
      referenceNumber: json['reference_number']?.toString(),
      receivedBy: json['received_by']?.toString(),
      remarks: json['remarks']?.toString(),
      attachmentUrl: json['attachment_url']?.toString(),
      localAttachmentPath: json['local_attachment_path']?.toString(),
      status: json['status']?.toString() ?? TransactionStatus.valid,
      reversalReason: json['reversal_reason']?.toString(),
      voidReason: json['void_reason']?.toString(),
      verificationStatus: json['verification_status']?.toString() ?? PaymentVerificationStatus.pending,
      verifiedBy: json['verified_by']?.toString(),
      verifiedByName: json['verified_by_name']?.toString(),
      verifiedAt: json['verified_at'] != null ? DateTime.tryParse(json['verified_at'].toString()) : null,
      verificationRemarks: json['verification_remarks']?.toString(),
      extractedAmount: json['extracted_amount'] != null ? double.tryParse(json['extracted_amount'].toString()) : null,
      extractedDate: json['extracted_date'] != null ? DateTime.tryParse(json['extracted_date'].toString()) : null,
      extractedRefNo: json['extracted_ref_no']?.toString(),
      proofMismatch: json['proof_mismatch'] == true || json['proof_mismatch'] == 1,
      syncStatus: json['sync_status']?.toString() ?? 'Synced',
      createdBy: json['created_by']?.toString(),
      createdByName: json['created_by_name']?.toString(),
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
      updatedBy: json['updated_by']?.toString(),
      updatedByName: json['updated_by_name']?.toString(),
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      if (clientTxId != null) 'client_tx_id': clientTxId,
      if (idempotencyKey != null) 'idempotency_key': idempotencyKey,
      'customer_id': customerId,
      'consumer_no': consumerNo,
      if (customerName != null) 'customer_name': customerName,
      if (village != null) 'village': village,
      if (mobileNumber != null) 'mobile_number': mobileNumber,
      'amount': amount,
      'payment_date': paymentDate.toIso8601String().split('T')[0],
      'payment_type': paymentType,
      if (additionalCategory != null) 'additional_category': additionalCategory,
      'payment_mode': paymentMode,
      if (referenceNumber != null) 'reference_number': referenceNumber,
      if (receivedBy != null) 'received_by': receivedBy,
      if (remarks != null) 'remarks': remarks,
      if (attachmentUrl != null) 'attachment_url': attachmentUrl,
      if (localAttachmentPath != null) 'local_attachment_path': localAttachmentPath,
      'status': status,
      if (reversalReason != null) 'reversal_reason': reversalReason,
      if (voidReason != null) 'void_reason': voidReason,
      'verification_status': verificationStatus,
      if (verifiedBy != null) 'verified_by': verifiedBy,
      if (verifiedByName != null) 'verified_by_name': verifiedByName,
      if (verifiedAt != null) 'verified_at': verifiedAt!.toIso8601String(),
      if (verificationRemarks != null) 'verification_remarks': verificationRemarks,
      if (extractedAmount != null) 'extracted_amount': extractedAmount,
      if (extractedDate != null) 'extracted_date': extractedDate!.toIso8601String().split('T')[0],
      if (extractedRefNo != null) 'extracted_ref_no': extractedRefNo,
      'proof_mismatch': proofMismatch,
      'sync_status': syncStatus,
      if (createdBy != null) 'created_by': createdBy,
      if (createdByName != null) 'created_by_name': createdByName,
      'created_at': (createdAt ?? DateTime.now()).toIso8601String(),
      if (updatedBy != null) 'updated_by': updatedBy,
      if (updatedByName != null) 'updated_by_name': updatedByName,
      'updated_at': (updatedAt ?? DateTime.now()).toIso8601String(),
    };
  }

  PaymentTransaction copyWith({
    String? id,
    String? clientTxId,
    String? idempotencyKey,
    String? customerId,
    String? consumerNo,
    String? customerName,
    String? village,
    String? mobileNumber,
    double? amount,
    DateTime? paymentDate,
    String? paymentType,
    String? additionalCategory,
    String? paymentMode,
    String? referenceNumber,
    String? receivedBy,
    String? remarks,
    String? attachmentUrl,
    String? localAttachmentPath,
    String? status,
    String? reversalReason,
    String? voidReason,
    String? verificationStatus,
    String? verifiedBy,
    String? verifiedByName,
    DateTime? verifiedAt,
    String? verificationRemarks,
    double? extractedAmount,
    DateTime? extractedDate,
    String? extractedRefNo,
    bool? proofMismatch,
    String? syncStatus,
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
      customerName: customerName ?? this.customerName,
      village: village ?? this.village,
      mobileNumber: mobileNumber ?? this.mobileNumber,
      amount: amount ?? this.amount,
      paymentDate: paymentDate ?? this.paymentDate,
      paymentType: paymentType ?? this.paymentType,
      additionalCategory: additionalCategory ?? this.additionalCategory,
      paymentMode: paymentMode ?? this.paymentMode,
      referenceNumber: referenceNumber ?? this.referenceNumber,
      receivedBy: receivedBy ?? this.receivedBy,
      remarks: remarks ?? this.remarks,
      attachmentUrl: attachmentUrl ?? this.attachmentUrl,
      localAttachmentPath: localAttachmentPath ?? this.localAttachmentPath,
      status: status ?? this.status,
      reversalReason: reversalReason ?? this.reversalReason,
      voidReason: voidReason ?? this.voidReason,
      verificationStatus: verificationStatus ?? this.verificationStatus,
      verifiedBy: verifiedBy ?? this.verifiedBy,
      verifiedByName: verifiedByName ?? this.verifiedByName,
      verifiedAt: verifiedAt ?? this.verifiedAt,
      verificationRemarks: verificationRemarks ?? this.verificationRemarks,
      extractedAmount: extractedAmount ?? this.extractedAmount,
      extractedDate: extractedDate ?? this.extractedDate,
      extractedRefNo: extractedRefNo ?? this.extractedRefNo,
      proofMismatch: proofMismatch ?? this.proofMismatch,
      syncStatus: syncStatus ?? this.syncStatus,
      createdBy: createdBy ?? this.createdBy,
      createdByName: createdByName ?? this.createdByName,
      createdAt: createdAt ?? this.createdAt,
      updatedBy: updatedBy ?? this.updatedBy,
      updatedByName: updatedByName ?? this.updatedByName,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

/// Summary helper for customer balance calculations with strict Contract vs Additional separation
class CustomerPaymentSummary {
  final double contractAmount;
  final double contractPaid;
  final double contractPending;
  final double additionalPaid;
  final double totalReceived;
  final String paymentStatus;
  final DateTime? paymentDueDate;
  final DateTime? lastPaymentDate;
  final double? lastPaymentAmount;
  final int totalTransactionsCount;
  final int pendingSyncCount;

  const CustomerPaymentSummary({
    double? contractAmount,
    double? contractPaid,
    double? contractPending,
    this.additionalPaid = 0.0,
    double? totalReceived,
    required this.paymentStatus,
    this.paymentDueDate,
    this.lastPaymentDate,
    this.lastPaymentAmount,
    this.totalTransactionsCount = 0,
    this.pendingSyncCount = 0,
    // Backward compatibility parameter aliases
    double? totalAmount,
    double? paidAmount,
    double? pendingAmount,
  })  : contractAmount = contractAmount ?? totalAmount ?? 0.0,
        contractPaid = contractPaid ?? paidAmount ?? 0.0,
        contractPending = contractPending ?? pendingAmount ?? 0.0,
        totalReceived = totalReceived ?? ((contractPaid ?? paidAmount ?? 0.0) + (additionalPaid));

  // Forwarding getters for backward compatibility
  double get totalAmount => contractAmount;
  double get paidAmount => contractPaid;
  double get pendingAmount => contractPending;

  bool get isPaid => paymentStatus == PaymentStatus.paid;
  bool get isOverdue => paymentStatus == PaymentStatus.overdue;
  bool get isPartiallyPaid => paymentStatus == PaymentStatus.partiallyPaid;
  bool get isPending => paymentStatus == PaymentStatus.pending;
  bool get hasPendingSync => pendingSyncCount > 0;
  String get status => paymentStatus;
  double get paidPercentage =>
      contractAmount > 0 ? ((contractPaid / contractAmount) * 100).clamp(0.0, 100.0) : 0.0;

  /// Pure deterministic balance computation formula with Contract vs Additional separation
  static CustomerPaymentSummary calculate({
    required double totalAmount, // Contract total
    required List<PaymentTransaction> transactions,
    DateTime? dueDate,
  }) {
    double contractPaid = 0;
    double additionalPaid = 0;
    DateTime? lastPayment;
    double? lastAmt;
    int pendingSync = 0;

    for (final tx in transactions) {
      if (tx.isValid &&
          tx.verificationStatus != PaymentVerificationStatus.rejected &&
          tx.verificationStatus != PaymentVerificationStatus.voided) {
        if (tx.isAdditional) {
          additionalPaid += tx.amount;
        } else {
          contractPaid += tx.amount;
        }

        if (lastPayment == null || tx.paymentDate.isAfter(lastPayment)) {
          lastPayment = tx.paymentDate;
          lastAmt = tx.amount;
        }
      }
      if (tx.isPendingSync) {
        pendingSync++;
      }
    }

    // CRITICAL ACCOUNTING RULE:
    // contractPending = totalAmount - contractPaid.
    // additionalPaid is completely separate and never decreases contractPending.
    final contractPending = (totalAmount - contractPaid).clamp(0.0, double.infinity);
    final totalReceived = contractPaid + additionalPaid;

    String status = PaymentStatus.pending;
    if (contractPaid >= totalAmount && totalAmount > 0) {
      status = PaymentStatus.paid;
    } else if (contractPaid > 0) {
      status = PaymentStatus.partiallyPaid;
    }

    if (status != PaymentStatus.paid && dueDate != null) {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final due = DateTime(dueDate.year, dueDate.month, dueDate.day);
      if (due.isBefore(today)) {
        status = PaymentStatus.overdue;
      }
    }

    return CustomerPaymentSummary(
      contractAmount: totalAmount,
      contractPaid: contractPaid,
      contractPending: contractPending,
      additionalPaid: additionalPaid,
      totalReceived: totalReceived,
      paymentStatus: status,
      paymentDueDate: dueDate,
      lastPaymentDate: lastPayment,
      lastPaymentAmount: lastAmt,
      totalTransactionsCount: transactions.length,
      pendingSyncCount: pendingSync,
    );
  }
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
  final double contractCollection;
  final double additionalCollection;
  final double totalReceivedAmount;
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
    this.contractCollection = 0.0,
    this.additionalCollection = 0.0,
    double? totalReceivedAmount,
    required this.todayPaymentsCount,
    required this.pendingPaymentsCount,
    required this.pendingSyncCount,
    required this.activeFollowupsCount,
    this.unverifiedPaymentsCount = 0,
  }) : totalReceivedAmount = totalReceivedAmount ?? (contractCollection > 0 || additionalCollection > 0 ? (contractCollection + additionalCollection) : totalPaidAmount);

  factory PaymentDashboardSummary.empty() {
    return const PaymentDashboardSummary(
      todayCollection: 0.0,
      monthCollection: 0.0,
      totalContractAmount: 0.0,
      totalPaidAmount: 0.0,
      totalPendingAmount: 0.0,
      contractCollection: 0.0,
      additionalCollection: 0.0,
      totalReceivedAmount: 0.0,
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

  factory PaymentFollowupRecord.fromJson(Map<String, dynamic> json) {
    return PaymentFollowupRecord(
      id: json['id'] as String? ?? '',
      customerId: json['customer_id'] as String? ?? '',
      consumerNo: json['consumer_no'] as String? ?? '',
      customerName: json['customer_name'] as String? ?? '',
      followupDate: DateTime.tryParse(json['followup_date']?.toString() ?? '') ?? DateTime.now(),
      assignedStaff: json['assigned_staff'] as String?,
      remarks: json['remarks'] as String? ?? '',
      pendingAmount: (json['pending_amount'] as num?)?.toDouble() ?? 0.0,
      status: json['status'] as String? ?? 'PENDING',
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'customer_id': customerId,
      'consumer_no': consumerNo,
      'customer_name': customerName,
      'followup_date': followupDate.toIso8601String().split('T')[0],
      if (assignedStaff != null) 'assigned_staff': assignedStaff,
      'remarks': remarks,
      'pending_amount': pendingAmount,
      'status': status,
      'created_at': createdAt.toIso8601String(),
    };
  }
}

/// Admin Payment Dashboard Summary Metrics
class AdminPaymentMetrics {
  final double contractCollection;
  final double additionalCollection;
  final double totalCollection;
  final double todayCollection;
  final double monthCollection;
  final double totalOutstanding;
  final int pendingVerificationCount;
  final int pendingSyncCount;
  final int followUpCount;
  final int todayPaymentsCount;
  final int totalTransactionsCount;

  const AdminPaymentMetrics({
    this.contractCollection = 0.0,
    this.additionalCollection = 0.0,
    this.totalCollection = 0.0,
    this.todayCollection = 0.0,
    this.monthCollection = 0.0,
    this.totalOutstanding = 0.0,
    this.pendingVerificationCount = 0,
    this.pendingSyncCount = 0,
    this.followUpCount = 0,
    this.todayPaymentsCount = 0,
    this.totalTransactionsCount = 0,
  });

  static AdminPaymentMetrics empty() => const AdminPaymentMetrics();
}

/// Customer Payment Summary Row for Customer-level Ledger Table
class CustomerPaymentRow {
  final String customerId;
  final String customerName;
  final String consumerNo;
  final String village;
  final String mobileNumber;
  final double totalAmount; // Contract Amount
  final double paidAmount; // Contract Paid
  final double pendingAmount; // Contract Pending
  final double firstPaymentAmount;
  final double secondPaymentAmount;
  final double firstPaymentReceived;
  final double secondPaymentReceived;
  final bool isLoanCustomer;
  final double additionalPaid; // Additional Paid
  final double totalReceived; // Total Received = Contract Paid + Additional Paid
  final String paymentStatus;
  final DateTime? lastPaymentDate;
  final double? lastPaymentAmount;
  final String? lastPaymentMode;
  final String? lastPaymentType;
  final String? lastAdditionalCategory;

  double get firstPaymentPending => (firstPaymentAmount - firstPaymentReceived).clamp(0.0, double.infinity);
  double get secondPaymentPending => (secondPaymentAmount - secondPaymentReceived).clamp(0.0, double.infinity);

  const CustomerPaymentRow({
    required this.customerId,
    required this.customerName,
    required this.consumerNo,
    this.village = '',
    this.mobileNumber = '',
    required this.totalAmount,
    required this.paidAmount,
    required this.pendingAmount,
    this.firstPaymentAmount = 0.0,
    this.secondPaymentAmount = 0.0,
    this.firstPaymentReceived = 0.0,
    this.secondPaymentReceived = 0.0,
    this.isLoanCustomer = false,
    this.additionalPaid = 0.0,
    double? totalReceived,
    required this.paymentStatus,
    this.lastPaymentDate,
    this.lastPaymentAmount,
    this.lastPaymentMode,
    this.lastPaymentType,
    this.lastAdditionalCategory,
  }) : totalReceived = totalReceived ?? (paidAmount + additionalPaid);
}

// Global Aliases for schema backwards compatibility
typedef CustomerPaymentTransaction = PaymentTransaction;
typedef CustomerPaymentCalculation = CustomerPaymentSummary;
