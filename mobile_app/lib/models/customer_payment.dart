import 'package:flutter/material.dart';

/// Payment Modes supported
class PaymentMode {
  static const String cash = 'Cash';
  static const String upi = 'UPI';
  static const String bankTransfer = 'Bank Transfer';
  static const String cheque = 'Cheque';
  static const String other = 'Other';

  static const List<String> allModes = [
    cash,
    upi,
    bankTransfer,
    cheque,
    other,
  ];
}

/// Payment Statuses
class PaymentStatus {
  static const String pending = 'Pending';
  static const String partiallyPaid = 'Partially Paid';
  static const String paid = 'Paid';
  static const String overdue = 'Overdue';
  static const String refunded = 'Refunded';
  static const String cancelled = 'Cancelled';

  static const List<String> allStatuses = [
    pending,
    partiallyPaid,
    paid,
    overdue,
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

/// Transaction Status
class TransactionStatus {
  static const String valid = 'Valid';
  static const String reversed = 'Reversed';
  static const String refunded = 'Refunded';
}

/// Model for a Customer Payment Transaction
class PaymentTransaction {
  final String? id;
  final String customerId;
  final String consumerNo;
  final double amount;
  final DateTime paymentDate;
  final String paymentMode;
  final String? referenceNumber;
  final String? receivedBy;
  final String? remarks;
  final String? attachmentUrl;
  final String status;
  final String? reversalReason;
  final String? createdBy;
  final String? createdByName;
  final DateTime? createdAt;
  final String? updatedBy;
  final String? updatedByName;
  final DateTime? updatedAt;

  const PaymentTransaction({
    this.id,
    required this.customerId,
    required this.consumerNo,
    required this.amount,
    required this.paymentDate,
    required this.paymentMode,
    this.referenceNumber,
    this.receivedBy,
    this.remarks,
    this.attachmentUrl,
    this.status = TransactionStatus.valid,
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

  factory PaymentTransaction.fromJson(Map<String, dynamic> json) {
    return PaymentTransaction(
      id: json['id']?.toString(),
      customerId: json['customer_id']?.toString() ?? '',
      consumerNo: json['consumer_no']?.toString() ?? '',
      amount: (json['amount'] is num)
          ? (json['amount'] as num).toDouble()
          : double.tryParse(json['amount']?.toString() ?? '0') ?? 0.0,
      paymentDate: json['payment_date'] != null
          ? DateTime.tryParse(json['payment_date'].toString()) ?? DateTime.now()
          : DateTime.now(),
      paymentMode: json['payment_mode']?.toString() ?? PaymentMode.other,
      referenceNumber: json['reference_number']?.toString(),
      receivedBy: json['received_by']?.toString(),
      remarks: json['remarks']?.toString(),
      attachmentUrl: json['attachment_url']?.toString(),
      status: json['status']?.toString() ?? TransactionStatus.valid,
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
      'customer_id': customerId,
      'consumer_no': consumerNo,
      'amount': amount,
      'payment_date': paymentDate.toIso8601String().split('T')[0],
      'payment_mode': paymentMode,
      if (referenceNumber != null) 'reference_number': referenceNumber,
      if (receivedBy != null) 'received_by': receivedBy,
      if (remarks != null) 'remarks': remarks,
      if (attachmentUrl != null) 'attachment_url': attachmentUrl,
      'status': status,
      if (reversalReason != null) 'reversal_reason': reversalReason,
      if (createdBy != null) 'created_by': createdBy,
      if (createdByName != null) 'created_by_name': createdByName,
      'created_at': (createdAt ?? DateTime.now()).toIso8601String(),
      if (updatedBy != null) 'updated_by': updatedBy,
      if (updatedByName != null) 'updated_by_name': updatedByName,
      'updated_at': (updatedAt ?? DateTime.now()).toIso8601String(),
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

  const CustomerPaymentSummary({
    required this.totalAmount,
    required this.paidAmount,
    required this.pendingAmount,
    required this.paymentStatus,
    this.paymentDueDate,
  });

  bool get isPaid => paymentStatus == PaymentStatus.paid;
  bool get isOverdue => paymentStatus == PaymentStatus.overdue;
  bool get isPartiallyPaid => paymentStatus == PaymentStatus.partiallyPaid;
  bool get isPending => paymentStatus == PaymentStatus.pending;
  String get status => paymentStatus;
}

/// Backward compatibility and naming aliases
typedef CustomerPaymentTransaction = PaymentTransaction;
typedef CustomerPaymentCalculation = CustomerPaymentSummary;

