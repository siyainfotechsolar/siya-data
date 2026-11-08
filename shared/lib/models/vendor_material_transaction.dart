/// Represents an actual material issue or return for a sub-vendor site.
class VendorMaterialTransaction {
  final String id;
  final String assignmentId;
  final String vendorId;
  final String customerId;
  final String transactionType; // 'ISSUE', 'RETURN'
  final DateTime transactionDate;
  final String itemName;
  final String itemCategory; // 'SOLAR_PANEL', 'INVERTER', 'BOS', 'OTHER'
  final double gstRate; // 5.0% for Panels & Inverters, 18.0% for BOS
  final double quantity;
  final String unit; // 'Nos', 'Sets', 'Mtrs', 'Kg'
  final double unitRate; // Actual purchase rate per unit (excl. GST)
  final double taxableAmount; // quantity * unitRate
  final double gstAmount; // taxableAmount * (gstRate / 100)
  final double totalAmount; // taxableAmount + gstAmount
  final String? challanNumber;
  final String? serialNumbers;
  final String? remarks;
  final DateTime? createdAt;
  final String? createdBy;

  const VendorMaterialTransaction({
    required this.id,
    required this.assignmentId,
    required this.vendorId,
    required this.customerId,
    required this.transactionType,
    required this.transactionDate,
    required this.itemName,
    required this.itemCategory,
    this.gstRate = 5.0,
    required this.quantity,
    this.unit = 'Nos',
    required this.unitRate,
    required this.taxableAmount,
    required this.gstAmount,
    required this.totalAmount,
    this.challanNumber,
    this.serialNumbers,
    this.remarks,
    this.createdAt,
    this.createdBy,
  });

  bool get isIssue => transactionType.toUpperCase() == 'ISSUE';
  bool get isReturn => transactionType.toUpperCase() == 'RETURN';

  double get signedTaxable => isReturn ? -taxableAmount : taxableAmount;
  double get signedGst => isReturn ? -gstAmount : gstAmount;
  double get signedTotal => isReturn ? -totalAmount : totalAmount;

  factory VendorMaterialTransaction.create({
    required String assignmentId,
    required String vendorId,
    required String customerId,
    required String transactionType,
    DateTime? transactionDate,
    required String itemName,
    required String itemCategory,
    double? gstRate,
    required double quantity,
    String unit = 'Nos',
    required double unitRate,
    String? challanNumber,
    String? serialNumbers,
    String? remarks,
    String? createdBy,
  }) {
    final effectiveGst = gstRate ??
        ((itemCategory == 'SOLAR_PANEL' || itemCategory == 'INVERTER') ? 5.0 : 18.0);
    final taxable = double.parse((quantity * unitRate).toStringAsFixed(2));
    final gst = double.parse((taxable * (effectiveGst / 100.0)).toStringAsFixed(2));
    final total = double.parse((taxable + gst).toStringAsFixed(2));

    return VendorMaterialTransaction(
      id: '',
      assignmentId: assignmentId,
      vendorId: vendorId,
      customerId: customerId,
      transactionType: transactionType.toUpperCase(),
      transactionDate: transactionDate ?? DateTime.now(),
      itemName: itemName,
      itemCategory: itemCategory,
      gstRate: effectiveGst,
      quantity: quantity,
      unit: unit,
      unitRate: unitRate,
      taxableAmount: taxable,
      gstAmount: gst,
      totalAmount: total,
      challanNumber: challanNumber,
      serialNumbers: serialNumbers,
      remarks: remarks,
      createdBy: createdBy,
    );
  }

  factory VendorMaterialTransaction.fromJson(Map<String, dynamic> json) {
    return VendorMaterialTransaction(
      id: json['id'] as String? ?? '',
      assignmentId: json['assignment_id'] as String? ?? '',
      vendorId: json['vendor_id'] as String? ?? '',
      customerId: json['customer_id'] as String? ?? '',
      transactionType: json['transaction_type'] as String? ?? 'ISSUE',
      transactionDate: json['transaction_date'] != null
          ? DateTime.tryParse(json['transaction_date'] as String) ?? DateTime.now()
          : DateTime.now(),
      itemName: json['item_name'] as String? ?? '',
      itemCategory: json['item_category'] as String? ?? 'BOS',
      gstRate: (json['gst_rate'] as num?)?.toDouble() ?? 5.0,
      quantity: (json['quantity'] as num?)?.toDouble() ?? 0.0,
      unit: json['unit'] as String? ?? 'Nos',
      unitRate: (json['unit_rate'] as num?)?.toDouble() ?? 0.0,
      taxableAmount: (json['taxable_amount'] as num?)?.toDouble() ?? 0.0,
      gstAmount: (json['gst_amount'] as num?)?.toDouble() ?? 0.0,
      totalAmount: (json['total_amount'] as num?)?.toDouble() ?? 0.0,
      challanNumber: json['challan_number'] as String?,
      serialNumbers: json['serial_numbers'] as String?,
      remarks: json['remarks'] as String?,
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'] as String) : null,
      createdBy: json['created_by'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id.isNotEmpty) 'id': id,
      'assignment_id': assignmentId,
      'vendor_id': vendorId,
      'customer_id': customerId,
      'transaction_type': transactionType,
      'transaction_date': transactionDate.toIso8601String().split('T').first,
      'item_name': itemName,
      'item_category': itemCategory,
      'gst_rate': gstRate,
      'quantity': quantity,
      'unit': unit,
      'unit_rate': unitRate,
      'taxable_amount': taxableAmount,
      'gst_amount': gstAmount,
      'total_amount': totalAmount,
      if (challanNumber != null) 'challan_number': challanNumber,
      if (serialNumbers != null) 'serial_numbers': serialNumbers,
      if (remarks != null) 'remarks': remarks,
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
      if (createdBy != null) 'created_by': createdBy,
    };
  }
}

