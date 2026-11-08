/// Represents a Contractual Sub-Vendor GST Recovery entry approved by Admin.
class VendorGstRecovery {
  final String id;
  final String assignmentId;
  final String vendorId;
  final double taxableValue;
  final double gstRate;
  final double gstAmount;
  final double totalRecovery;
  final String? invoiceNumber;
  final String recoveryStatus; // 'Pending', 'Approved', 'Collected'
  final DateTime recoveryDate;
  final DateTime? paymentDate;
  final String? remarks;
  final String? createdBy;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  // Joined metadata for UI convenience
  final String? customerName;
  final String? consumerNo;
  final String? vendorName;
  final String? vendorCode;

  const VendorGstRecovery({
    required this.id,
    required this.assignmentId,
    required this.vendorId,
    required this.taxableValue,
    this.gstRate = 18.0,
    required this.gstAmount,
    required this.totalRecovery,
    this.invoiceNumber,
    this.recoveryStatus = 'Approved',
    required this.recoveryDate,
    this.paymentDate,
    this.remarks,
    this.createdBy,
    this.createdAt,
    this.updatedAt,
    this.customerName,
    this.consumerNo,
    this.vendorName,
    this.vendorCode,
  });

  bool get isApproved => recoveryStatus.toUpperCase() == 'APPROVED';
  bool get isCollected => recoveryStatus.toUpperCase() == 'COLLECTED';

  factory VendorGstRecovery.calculate({
    required String assignmentId,
    required String vendorId,
    required double taxableValue,
    double gstRate = 18.0,
    String? invoiceNumber,
    String recoveryStatus = 'Approved',
    DateTime? recoveryDate,
    DateTime? paymentDate,
    String? remarks,
    String? createdBy,
    String? customerName,
    String? consumerNo,
    String? vendorName,
    String? vendorCode,
  }) {
    final validTaxable = double.parse(taxableValue.toStringAsFixed(2));
    final validGstRate = double.parse(gstRate.toStringAsFixed(2));
    final calcGst = double.parse((validTaxable * (validGstRate / 100.0)).toStringAsFixed(2));
    final calcTotal = double.parse((validTaxable + calcGst).toStringAsFixed(2));

    return VendorGstRecovery(
      id: '',
      assignmentId: assignmentId,
      vendorId: vendorId,
      taxableValue: validTaxable,
      gstRate: validGstRate,
      gstAmount: calcGst,
      totalRecovery: calcTotal,
      invoiceNumber: invoiceNumber?.trim(),
      recoveryStatus: recoveryStatus,
      recoveryDate: recoveryDate ?? DateTime.now(),
      paymentDate: paymentDate,
      remarks: remarks?.trim(),
      createdBy: createdBy,
      createdAt: DateTime.now(),
      customerName: customerName,
      consumerNo: consumerNo,
      vendorName: vendorName,
      vendorCode: vendorCode,
    );
  }

  factory VendorGstRecovery.fromJson(Map<String, dynamic> json) {
    Map<String, dynamic>? customer;
    if (json['consumer_records'] != null && json['consumer_records'] is Map) {
      customer = json['consumer_records'] as Map<String, dynamic>;
    }

    Map<String, dynamic>? vendor;
    if (json['sub_vendors'] != null && json['sub_vendors'] is Map) {
      vendor = json['sub_vendors'] as Map<String, dynamic>;
    }

    final taxable = (json['taxable_value'] as num?)?.toDouble() ?? 0.0;
    final rate = (json['gst_rate'] as num?)?.toDouble() ?? 18.0;
    final gst = (json['gst_amount'] as num?)?.toDouble() ?? (taxable * rate / 100.0);
    final total = (json['total_recovery'] as num?)?.toDouble() ?? (taxable + gst);

    return VendorGstRecovery(
      id: json['id'] as String? ?? '',
      assignmentId: json['assignment_id'] as String? ?? '',
      vendorId: json['vendor_id'] as String? ?? '',
      taxableValue: taxable,
      gstRate: rate,
      gstAmount: gst,
      totalRecovery: total,
      invoiceNumber: json['invoice_number'] as String?,
      recoveryStatus: json['recovery_status'] as String? ?? 'Approved',
      recoveryDate: json['recovery_date'] != null
          ? DateTime.tryParse(json['recovery_date'] as String) ?? DateTime.now()
          : DateTime.now(),
      paymentDate: json['payment_date'] != null
          ? DateTime.tryParse(json['payment_date'] as String)
          : null,
      remarks: json['remarks'] as String?,
      createdBy: json['created_by'] as String?,
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'] as String) : null,
      updatedAt: json['updated_at'] != null ? DateTime.tryParse(json['updated_at'] as String) : null,
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
      'taxable_value': taxableValue,
      'gst_rate': gstRate,
      'gst_amount': gstAmount,
      'total_recovery': totalRecovery,
      if (invoiceNumber != null && invoiceNumber!.isNotEmpty) 'invoice_number': invoiceNumber,
      'recovery_status': recoveryStatus,
      'recovery_date': recoveryDate.toIso8601String().split('T').first,
      if (paymentDate != null) 'payment_date': paymentDate!.toIso8601String().split('T').first,
      if (remarks != null && remarks!.isNotEmpty) 'remarks': remarks,
      if (createdBy != null) 'created_by': createdBy,
    };
  }
}

