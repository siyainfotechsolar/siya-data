import 'package:flutter/material.dart';

/// Payment Types supported
class PaymentType {
  static const String contract = 'CONTRACT';
  static const String additional = 'ADDITIONAL';

  // Backward compatibility aliases
  static const String offline = 'CONTRACT';
  static const String online = 'CONTRACT';

  static const List<String> allTypes = [contract, additional];

  static String displayName(String type) {
    if (type.toUpperCase() == 'ADDITIONAL') {
      return 'Additional Payment';
    }
    return 'Contract Payment';
  }
}

/// Additional Payment Categories
class AdditionalPaymentCategory {
  static const String extraMaterial = 'EXTRA_MATERIAL';
  static const String extraWork = 'EXTRA_WORK';
  static const String additionalInstallation = 'ADDITIONAL_INSTALLATION';
  static const String transport = 'TRANSPORT';
  static const String serviceCharge = 'SERVICE_CHARGE';
  static const String other = 'OTHER';

  static const List<String> allCategories = [
    extraMaterial,
    extraWork,
    additionalInstallation,
    transport,
    serviceCharge,
    other,
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
      default:
        return 'Other';
    }
  }

  static IconData getCategoryIcon(String cat) {
    switch (cat.toUpperCase()) {
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
      default:
        return Icons.more_horiz_rounded;
    }
  }
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

/// Payment Statuses
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

/// Payment Verification Status
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
}

/// Transaction Status
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

  const PaymentTransaction({
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

  bool get isAdditional => paymentType.toUpperCase() == 'ADDITIONAL';
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
      paymentMode: json['payment_mode']?.toString() ?? PaymentMode.other,
      referenceNumber: json['reference_number']?.toString(),
      receivedBy: json['received_by']?.toString(),
      remarks: json['remarks']?.toString(),
      attachmentUrl: json['attachment_url']?.toString(),
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
      proofMismatch: json['proof_mismatch'] == true,
      syncStatus: json['sync_status']?.toString() ?? 'Synced',
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
      if (additionalCategory != null) 'additional_category': additionalCategory,
      'payment_mode': paymentMode,
      if (referenceNumber != null) 'reference_number': referenceNumber,
      if (receivedBy != null) 'received_by': receivedBy,
      if (remarks != null) 'remarks': remarks,
      if (attachmentUrl != null) 'attachment_url': attachmentUrl,
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

  const CustomerPaymentSummary({
    double? contractAmount,
    double? contractPaid,
    double? contractPending,
    this.additionalPaid = 0.0,
    double? totalReceived,
    required this.paymentStatus,
    this.paymentDueDate,
    this.lastPaymentDate,
    // Backward compatibility parameter aliases
    double? totalAmount,
    double? paidAmount,
    double? pendingAmount,
  })  : contractAmount = contractAmount ?? totalAmount ?? 0.0,
        contractPaid = contractPaid ?? paidAmount ?? 0.0,
        contractPending = contractPending ?? pendingAmount ?? 0.0,
        totalReceived = totalReceived ?? ((contractPaid ?? paidAmount ?? 0.0) + additionalPaid);

  // Backward compatibility getters
  double get totalAmount => contractAmount;
  double get paidAmount => contractPaid;
  double get pendingAmount => contractPending;

  bool get isPaid => paymentStatus == PaymentStatus.paid;
  bool get isOverdue => paymentStatus == PaymentStatus.overdue;
  bool get isPartiallyPaid => paymentStatus == PaymentStatus.partiallyPaid;
  bool get isPending => paymentStatus == PaymentStatus.pending;
  String get status => paymentStatus;

  /// Pure deterministic balance computation formula with Contract vs Additional separation
  static CustomerPaymentSummary calculate({
    required double totalAmount, // Contract total
    required List<PaymentTransaction> transactions,
    DateTime? dueDate,
  }) {
    double contractPaid = 0;
    double additionalPaid = 0;
    DateTime? lastPayment;

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
        }
      }
    }

    // CRITICAL ACCOUNTING RULE:
    // Contract Pending = max(0, Contract Amount - Contract Payments)
    // Additional payments do NOT reduce Contract Pending!
    final contractPending = (totalAmount - contractPaid).clamp(0.0, double.infinity);
    final totalReceived = contractPaid + additionalPaid;

    String status;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    if (totalAmount > 0 && contractPaid >= totalAmount) {
      status = PaymentStatus.paid;
    } else if (dueDate != null &&
        DateTime(dueDate.year, dueDate.month, dueDate.day).isBefore(today) &&
        contractPending > 0) {
      status = PaymentStatus.overdue;
    } else if (contractPaid > 0 && contractPending > 0) {
      status = PaymentStatus.partiallyPaid;
    } else {
      status = PaymentStatus.pending;
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
    );
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
  final double additionalPaid; // Additional Paid
  final double totalReceived; // Total Received = Contract Paid + Additional Paid
  final String paymentStatus;
  final DateTime? lastPaymentDate;
  final double? lastPaymentAmount;
  final String? lastPaymentMode;
  final String? lastPaymentType;
  final String? lastAdditionalCategory;

  const CustomerPaymentRow({
    required this.customerId,
    required this.customerName,
    required this.consumerNo,
    this.village = '',
    this.mobileNumber = '',
    required this.totalAmount,
    required this.paidAmount,
    required this.pendingAmount,
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

/// Backward compatibility and naming aliases
typedef CustomerPaymentTransaction = PaymentTransaction;
typedef CustomerPaymentCalculation = CustomerPaymentSummary;
