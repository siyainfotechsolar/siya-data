import 'dart:convert';

/// Represents a double-entry accounting ledger entry for a Sub-Vendor.
/// Credit / Debit Rules:
/// - MATERIAL_OUTWARD: Credit (Receivable increases - आपल्याला पैसे येणे)
/// - MATERIAL_PAYMENT: Debit (Receivable decreases - येणे कमी)
/// - ADVANCE_GIVEN: Debit (Advance payable increases - आपले पैसे बाहेर)
/// - ADVANCE_REFUND: Credit (Advance balance decreases - आपले पैसे परत)
class SubVendorAccountLedgerEntry {
  final String id;
  final String vendorId;
  final String vendorName;
  final DateTime transactionDate;
  final String transactionType; // 'MATERIAL_OUTWARD', 'MATERIAL_PAYMENT', 'ADVANCE_GIVEN', 'ADVANCE_REFUND'
  final String category; // 'MATERIAL', 'ADVANCE'
  final double creditAmount;
  final double debitAmount;
  final double runningBalance;
  final String referenceNumber;
  final String? referenceId; // links to sub_vendor_material_outwards.id if applicable
  final String paymentMode; // 'Bank Transfer', 'NEFT/RTGS', 'UPI', 'Cheque', 'Cash', 'Inventory'
  final String particulars;
  final String? remarks;
  final String status; // 'Active', 'Cancelled'
  final DateTime? cancelledAt;
  final String? cancellationReason;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? createdBy;

  const SubVendorAccountLedgerEntry({
    required this.id,
    required this.vendorId,
    required this.vendorName,
    required this.transactionDate,
    required this.transactionType,
    required this.category,
    this.creditAmount = 0.0,
    this.debitAmount = 0.0,
    this.runningBalance = 0.0,
    required this.referenceNumber,
    this.referenceId,
    this.paymentMode = 'Bank Transfer',
    required this.particulars,
    this.remarks,
    this.status = 'Active',
    this.cancelledAt,
    this.cancellationReason,
    this.createdAt,
    this.updatedAt,
    this.createdBy,
  });

  bool get isCredit => creditAmount > 0.001;
  bool get isDebit => debitAmount > 0.001;
  bool get isActive => status.toUpperCase() == 'ACTIVE';
  bool get isCancelled => status.toUpperCase() == 'CANCELLED';

  String get typeLabel {
    switch (transactionType.toUpperCase()) {
      case 'MATERIAL_OUTWARD':
        return 'Material Outward';
      case 'MATERIAL_PAYMENT':
        return 'Material Payment Received';
      case 'ADVANCE_GIVEN':
        return 'Advance / Deposit Given';
      case 'ADVANCE_REFUND':
        return 'Advance / Deposit Refund';
      default:
        return transactionType;
    }
  }

  factory SubVendorAccountLedgerEntry.fromJson(Map<String, dynamic> json) {
    return SubVendorAccountLedgerEntry(
      id: json['id']?.toString() ?? '',
      vendorId: json['vendor_id']?.toString() ?? '',
      vendorName: json['vendor_name']?.toString() ?? '',
      transactionDate: json['transaction_date'] != null
          ? DateTime.tryParse(json['transaction_date'].toString()) ?? DateTime.now()
          : DateTime.now(),
      transactionType: json['transaction_type']?.toString() ?? 'MATERIAL_OUTWARD',
      category: json['category']?.toString() ?? 'MATERIAL',
      creditAmount: (json['credit_amount'] as num?)?.toDouble() ?? 0.0,
      debitAmount: (json['debit_amount'] as num?)?.toDouble() ?? 0.0,
      runningBalance: (json['running_balance'] as num?)?.toDouble() ?? 0.0,
      referenceNumber: json['reference_number']?.toString() ?? '',
      referenceId: json['reference_id']?.toString(),
      paymentMode: json['payment_mode']?.toString() ?? 'Bank Transfer',
      particulars: json['particulars']?.toString() ?? '',
      remarks: json['remarks']?.toString(),
      status: json['status']?.toString() ?? 'Active',
      cancelledAt: json['cancelled_at'] != null ? DateTime.tryParse(json['cancelled_at'].toString()) : null,
      cancellationReason: json['cancellation_reason']?.toString(),
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'].toString()) : null,
      updatedAt: json['updated_at'] != null ? DateTime.tryParse(json['updated_at'].toString()) : null,
      createdBy: json['created_by']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'vendor_id': vendorId,
        'vendor_name': vendorName,
        'transaction_date': transactionDate.toIso8601String().split('T').first,
        'transaction_type': transactionType,
        'category': category,
        'credit_amount': creditAmount,
        'debit_amount': debitAmount,
        'running_balance': runningBalance,
        'reference_number': referenceNumber,
        if (referenceId != null) 'reference_id': referenceId,
        'payment_mode': paymentMode,
        'particulars': particulars,
        if (remarks != null) 'remarks': remarks,
        'status': status,
        if (cancelledAt != null) 'cancelled_at': cancelledAt!.toIso8601String(),
        if (cancellationReason != null) 'cancellation_reason': cancellationReason,
        if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
        if (updatedAt != null) 'updated_at': updatedAt!.toIso8601String(),
        if (createdBy != null) 'created_by': createdBy,
      };

  SubVendorAccountLedgerEntry copyWith({
    String? id,
    String? vendorId,
    String? vendorName,
    DateTime? transactionDate,
    String? transactionType,
    String? category,
    double? creditAmount,
    double? debitAmount,
    double? runningBalance,
    String? referenceNumber,
    String? referenceId,
    String? paymentMode,
    String? particulars,
    String? remarks,
    String? status,
    DateTime? cancelledAt,
    String? cancellationReason,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? createdBy,
  }) {
    return SubVendorAccountLedgerEntry(
      id: id ?? this.id,
      vendorId: vendorId ?? this.vendorId,
      vendorName: vendorName ?? this.vendorName,
      transactionDate: transactionDate ?? this.transactionDate,
      transactionType: transactionType ?? this.transactionType,
      category: category ?? this.category,
      creditAmount: creditAmount ?? this.creditAmount,
      debitAmount: debitAmount ?? this.debitAmount,
      runningBalance: runningBalance ?? this.runningBalance,
      referenceNumber: referenceNumber ?? this.referenceNumber,
      referenceId: referenceId ?? this.referenceId,
      paymentMode: paymentMode ?? this.paymentMode,
      particulars: particulars ?? this.particulars,
      remarks: remarks ?? this.remarks,
      status: status ?? this.status,
      cancelledAt: cancelledAt ?? this.cancelledAt,
      cancellationReason: cancellationReason ?? this.cancellationReason,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      createdBy: createdBy ?? this.createdBy,
    );
  }
}

/// Aggregated financial metrics for the high-level Sub Vendor Account Dashboard.
class SubVendorDashboardMetrics {
  final double totalCredit; // Sub Vendor कडून येणे (Material Outward Value + Advance Refund)
  final double totalDebit; // Sub Vendor ला देणे / जमा झालेले (Material Payment Received + Advance Given)
  final double netBalance; // Total Credit - Total Debit (आपल्याला Sub Vendor कडून येणे)
  final double totalMaterialOutwardValue;
  final double totalMaterialPaymentsReceived;
  final double netMaterialReceivable;
  final double totalAdvanceGiven;
  final double totalAdvanceRefundReceived;
  final double netAdvanceBalance;
  final List<SubVendorAccountBalanceSummary> vendorBalances;

  const SubVendorDashboardMetrics({
    required this.totalCredit,
    required this.totalDebit,
    required this.netBalance,
    required this.totalMaterialOutwardValue,
    required this.totalMaterialPaymentsReceived,
    required this.netMaterialReceivable,
    required this.totalAdvanceGiven,
    required this.totalAdvanceRefundReceived,
    required this.netAdvanceBalance,
    required this.vendorBalances,
  });

  bool get isReceivable => netBalance > 0.001;
  bool get isPayable => netBalance < -0.001;
  double get totalMaterialOutward => totalMaterialOutwardValue;
  double get totalMaterialPayment => totalMaterialPaymentsReceived;
  double get totalAdvanceRefund => totalAdvanceRefundReceived;

  factory SubVendorDashboardMetrics.empty() {
    return const SubVendorDashboardMetrics(
      totalCredit: 0.0,
      totalDebit: 0.0,
      netBalance: 0.0,
      totalMaterialOutwardValue: 0.0,
      totalMaterialPaymentsReceived: 0.0,
      netMaterialReceivable: 0.0,
      totalAdvanceGiven: 0.0,
      totalAdvanceRefundReceived: 0.0,
      netAdvanceBalance: 0.0,
      vendorBalances: [],
    );
  }
}

/// Balance summary per individual Sub-Vendor.
class SubVendorAccountBalanceSummary {
  final String vendorId;
  final String vendorName;
  final String vendorCode;
  final double totalCredit;
  final double totalDebit;
  final double netBalance;
  final double materialReceivable;
  final double advanceBalance;
  final int totalTransactions;
  final DateTime? lastTransactionDate;

  bool get isReceivable => netBalance > 0.001;
  bool get isPayable => netBalance < -0.001;

  const SubVendorAccountBalanceSummary({
    required this.vendorId,
    required this.vendorName,
    required this.vendorCode,
    required this.totalCredit,
    required this.totalDebit,
    required this.netBalance,
    required this.materialReceivable,
    required this.advanceBalance,
    this.totalTransactions = 0,
    this.lastTransactionDate,
  });
}
