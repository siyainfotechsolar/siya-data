import 'package:flutter/foundation.dart';

/// Represents a customer payment transaction (Cash or Bank Loan Credit installment)
/// linked to a specific Sub-Vendor Site Assignment.
class VendorCustomerPayment {
  final String id;
  final String assignmentId;
  final String vendorId;
  final String customerId;
  final String paymentType; // 'CASH' or 'BANK_LOAN'
  final String paymentStage; // 'ADVANCE', 'PARTIAL', 'FINAL', 'LOAN_CREDIT'
  final double amount;
  final DateTime paymentDate;
  final String paymentMode; // 'Cash', 'UPI', 'NEFT/RTGS', 'Bank Transfer', 'Cheque'
  final String? referenceNumber; // UTR / Cheque / Txn ID
  final String? bankName; // State Bank of India, Bank of Maharashtra, etc.
  final String? loanApplicationId;
  final String? attachmentUrl;
  final String? remarks;
  final String status; // 'Approved', 'Pending', 'Rejected'
  final String? approvedBy;
  final DateTime? approvedAt;
  final DateTime? createdAt;
  final String? createdBy;

  // Joined display metadata
  final String? customerName;
  final String? consumerNo;
  final String? vendorName;
  final String? vendorCode;

  const VendorCustomerPayment({
    required this.id,
    required this.assignmentId,
    required this.vendorId,
    required this.customerId,
    required this.paymentType,
    required this.paymentStage,
    required this.amount,
    required this.paymentDate,
    this.paymentMode = 'Bank Transfer',
    this.referenceNumber,
    this.bankName,
    this.loanApplicationId,
    this.attachmentUrl,
    this.remarks,
    this.status = 'Approved',
    this.approvedBy,
    this.approvedAt,
    this.createdAt,
    this.createdBy,
    this.customerName,
    this.consumerNo,
    this.vendorName,
    this.vendorCode,
  });

  bool get isLoan => paymentType.toUpperCase() == 'BANK_LOAN';
  bool get isCash => paymentType.toUpperCase() == 'CASH';
  bool get isApproved => status.toUpperCase() == 'APPROVED';

  factory VendorCustomerPayment.create({
    required String assignmentId,
    required String vendorId,
    required String customerId,
    required String paymentType,
    required String paymentStage,
    required double amount,
    DateTime? paymentDate,
    String paymentMode = 'Bank Transfer',
    String? referenceNumber,
    String? bankName,
    String? loanApplicationId,
    String? attachmentUrl,
    String? remarks,
    String status = 'Approved',
    String? createdBy,
  }) {
    return VendorCustomerPayment(
      id: '',
      assignmentId: assignmentId,
      vendorId: vendorId,
      customerId: customerId,
      paymentType: paymentType.toUpperCase(),
      paymentStage: paymentStage.toUpperCase(),
      amount: double.parse(amount.toStringAsFixed(2)),
      paymentDate: paymentDate ?? DateTime.now(),
      paymentMode: paymentMode,
      referenceNumber: referenceNumber?.trim(),
      bankName: bankName?.trim(),
      loanApplicationId: loanApplicationId?.trim(),
      attachmentUrl: attachmentUrl?.trim(),
      remarks: remarks?.trim(),
      status: status,
      createdBy: createdBy,
      createdAt: DateTime.now(),
    );
  }

  factory VendorCustomerPayment.fromJson(Map<String, dynamic> json) {
    Map<String, dynamic>? customer;
    if (json['customer'] != null && json['customer'] is Map) {
      customer = json['customer'] as Map<String, dynamic>;
    } else if (json['consumer_records'] != null && json['consumer_records'] is Map) {
      customer = json['consumer_records'] as Map<String, dynamic>;
    }

    Map<String, dynamic>? vendor;
    if (json['sub_vendors'] != null && json['sub_vendors'] is Map) {
      vendor = json['sub_vendors'] as Map<String, dynamic>;
    }

    return VendorCustomerPayment(
      id: json['id'] as String? ?? '',
      assignmentId: json['assignment_id'] as String? ?? '',
      vendorId: json['vendor_id'] as String? ?? '',
      customerId: json['customer_id'] as String? ?? '',
      paymentType: (json['payment_type'] as String? ?? 'CASH').toUpperCase(),
      paymentStage: (json['payment_stage'] as String? ?? 'PARTIAL').toUpperCase(),
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      paymentDate: json['payment_date'] != null
          ? DateTime.tryParse(json['payment_date'] as String) ?? DateTime.now()
          : DateTime.now(),
      paymentMode: json['payment_mode'] as String? ?? 'Bank Transfer',
      referenceNumber: json['reference_number'] as String?,
      bankName: json['bank_name'] as String?,
      loanApplicationId: json['loan_application_id'] as String?,
      attachmentUrl: json['attachment_url'] as String?,
      remarks: json['remarks'] as String?,
      status: json['status'] as String? ?? 'Approved',
      approvedBy: json['approved_by'] as String?,
      approvedAt: json['approved_at'] != null ? DateTime.tryParse(json['approved_at'] as String) : null,
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'] as String) : null,
      createdBy: json['created_by'] as String?,
      customerName: json['customer_name'] as String? ?? customer?['name'] as String?,
      consumerNo: json['consumer_no'] as String? ?? customer?['consumer_no'] as String?,
      vendorName: json['vendor_name'] as String? ?? vendor?['name'] as String?,
      vendorCode: json['vendor_code'] as String? ?? vendor?['vendor_code'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id.isNotEmpty) 'id': id,
      'assignment_id': assignmentId,
      'vendor_id': vendorId,
      'customer_id': customerId,
      'payment_type': paymentType,
      'payment_stage': paymentStage,
      'amount': amount,
      'payment_date': paymentDate.toIso8601String().split('T').first,
      'payment_mode': paymentMode,
      if (referenceNumber != null && referenceNumber!.isNotEmpty) 'reference_number': referenceNumber,
      if (bankName != null && bankName!.isNotEmpty) 'bank_name': bankName,
      if (loanApplicationId != null && loanApplicationId!.isNotEmpty) 'loan_application_id': loanApplicationId,
      if (attachmentUrl != null && attachmentUrl!.isNotEmpty) 'attachment_url': attachmentUrl,
      if (remarks != null && remarks!.isNotEmpty) 'remarks': remarks,
      'status': status,
      if (approvedBy != null) 'approved_by': approvedBy,
      if (approvedAt != null) 'approved_at': approvedAt!.toIso8601String(),
      if (createdBy != null) 'created_by': createdBy,
    };
  }
}
