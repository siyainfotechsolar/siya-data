/// Represents a payment or payout disbursement made to a Sub-Vendor.
class VendorPayout {
  final String id;
  final String vendorId;
  final String? assignmentId;
  final DateTime payoutDate;
  final double amount;
  final String paymentMode; // 'Bank Transfer', 'NEFT/RTGS', 'UPI', 'Cheque', 'Cash'
  final String? referenceNumber;
  final String? bankName;
  final String? remarks;
  final String status; // 'Pending', 'Approved', 'Paid'
  final DateTime? createdAt;
  final String? createdBy;

  // Joined metadata for UI convenience
  final String? siteConsumerNo;
  final String? customerName;
  final String? vendorName;

  const VendorPayout({
    required this.id,
    required this.vendorId,
    this.assignmentId,
    required this.payoutDate,
    required this.amount,
    this.paymentMode = 'Bank Transfer',
    this.referenceNumber,
    this.bankName,
    this.remarks,
    this.status = 'Paid',
    this.createdAt,
    this.createdBy,
    this.siteConsumerNo,
    this.customerName,
    this.vendorName,
  });

  factory VendorPayout.fromJson(Map<String, dynamic> json) {
    return VendorPayout(
      id: json['id'] as String? ?? '',
      vendorId: json['vendor_id'] as String? ?? '',
      assignmentId: json['assignment_id'] as String?,
      payoutDate: json['payout_date'] != null
          ? DateTime.tryParse(json['payout_date'] as String) ?? DateTime.now()
          : DateTime.now(),
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      paymentMode: json['payment_mode'] as String? ?? 'Bank Transfer',
      referenceNumber: json['reference_number'] as String?,
      bankName: json['bank_name'] as String?,
      remarks: json['remarks'] as String?,
      status: json['status'] as String? ?? 'Paid',
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'] as String) : null,
      createdBy: json['created_by'] as String?,
      siteConsumerNo: json['consumer_no'] as String?,
      customerName: json['customer_name'] as String?,
      vendorName: json['vendor_name'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id.isNotEmpty) 'id': id,
      'vendor_id': vendorId,
      if (assignmentId != null) 'assignment_id': assignmentId,
      'payout_date': payoutDate.toIso8601String().split('T').first,
      'amount': amount,
      'payment_mode': paymentMode,
      if (referenceNumber != null) 'reference_number': referenceNumber,
      if (bankName != null) 'bank_name': bankName,
      if (remarks != null) 'remarks': remarks,
      'status': status,
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
      if (createdBy != null) 'created_by': createdBy,
    };
  }
}

