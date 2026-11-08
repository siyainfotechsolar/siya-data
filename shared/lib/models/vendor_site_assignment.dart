/// Represents a Site Assignment linking a Customer Site to a Sub-Vendor.
class VendorSiteAssignment {
  final String id;
  final String vendorId;
  final String customerId;
  final DateTime assignedDate;
  final double siteCapacityKw;
  final double ratePerKw;
  final double vendorCharges; // siteCapacityKw * ratePerKw
  final double otherExpenses;
  final String? expenseRemarks;
  final String status; // 'Assigned', 'In Progress', 'Completed', 'Settled', 'Cancelled'
  final DateTime? completionDate;
  final String? notes;
  final bool financialApproved;
  final String? financialApprovedBy;
  final DateTime? financialApprovedAt;
  final bool settlementApproved;
  final String? settlementApprovedBy;
  final DateTime? settlementApprovedAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? createdBy;
  final String? updatedBy;

  // Joined metadata for UI convenience
  final String? consumerNo;
  final String? customerName;
  final String? customerMobile;
  final String? customerAddress;
  final String? customerVillageCity;
  final double customerTotalAmount;
  final double customerPaidAmount;
  final String? vendorCode;
  final String? vendorName;

  // Customer Payment & Bank Loan Tracking Fields
  final String paymentType; // 'Cash Customer', 'Bank Loan Customer', 'Part Cash + Part Loan'
  final double totalCustomerSiteAmount; // Overrides or mirrors consumer_records.total_amount
  final String? loanBankName;
  final String? loanApplicationId;
  final double loanAppliedAmount;
  final double loanSanctionedAmount;
  final String loanStatus; // 'Not Required', 'Applied', 'Sanctioned', 'Partially Credited', 'Fully Credited'
  final double totalCashReceived;
  final double totalLoanCredited;
  final double totalCustomerReceived; // totalCashReceived + totalLoanCredited
  final double customerOutstanding;
  final String customerPaymentStatus; // 'Pending', 'Partial', 'Paid'

  const VendorSiteAssignment({
    required this.id,
    required this.vendorId,
    required this.customerId,
    required this.assignedDate,
    this.siteCapacityKw = 3.0,
    this.ratePerKw = 1000.0,
    this.vendorCharges = 3000.0,
    this.otherExpenses = 0.0,
    this.expenseRemarks,
    this.status = 'Assigned',
    this.completionDate,
    this.notes,
    this.financialApproved = false,
    this.financialApprovedBy,
    this.financialApprovedAt,
    this.settlementApproved = false,
    this.settlementApprovedBy,
    this.settlementApprovedAt,
    this.createdAt,
    this.updatedAt,
    this.createdBy,
    this.updatedBy,
    this.consumerNo,
    this.customerName,
    this.customerMobile,
    this.customerAddress,
    this.customerVillageCity,
    this.customerTotalAmount = 0.0,
    this.customerPaidAmount = 0.0,
    this.vendorCode,
    this.vendorName,
    this.paymentType = 'Cash Customer',
    this.totalCustomerSiteAmount = 0.0,
    this.loanBankName,
    this.loanApplicationId,
    this.loanAppliedAmount = 0.0,
    this.loanSanctionedAmount = 0.0,
    this.loanStatus = 'Not Required',
    this.totalCashReceived = 0.0,
    this.totalLoanCredited = 0.0,
    this.totalCustomerReceived = 0.0,
    this.customerOutstanding = 0.0,
    this.customerPaymentStatus = 'Pending',
  });

  bool get isCompleted => status.toLowerCase() == 'completed' || status.toLowerCase() == 'settled';
  bool get isSettled => status.toLowerCase() == 'settled' || settlementApproved;

  /// Total payment due to the sub-vendor for installation and approved expenses
  double get totalVendorDue => vendorCharges + otherExpenses;

  /// Effective Site Amount
  double get effectiveSiteAmount =>
      totalCustomerSiteAmount > 0 ? totalCustomerSiteAmount : customerTotalAmount;

  /// Effective Received from Customer
  double get effectiveReceivedAmount =>
      totalCustomerReceived > 0 ? totalCustomerReceived : customerPaidAmount;

  /// Effective Outstanding Due from Customer
  double get effectiveCustomerOutstanding {
    if (customerOutstanding > 0) return customerOutstanding;
    final diff = effectiveSiteAmount - effectiveReceivedAmount;
    return diff > 0 ? diff : 0.0;
  }

  /// Whether site involves bank loan
  bool get isBankLoan =>
      paymentType == 'Bank Loan Customer' ||
      paymentType == 'Part Cash + Part Loan' ||
      loanSanctionedAmount > 0;

  /// Pending Bank Loan credit amount
  double get loanPendingCredit {
    if (loanSanctionedAmount <= 0) return 0.0;
    final pending = loanSanctionedAmount - totalLoanCredited;
    return pending > 0 ? double.parse(pending.toStringAsFixed(2)) : 0.0;
  }

  factory VendorSiteAssignment.fromJson(Map<String, dynamic> json) {
    // If joined customer record exists
    final customer = json['consumer_records'] as Map<String, dynamic>?;
    final vendor = json['sub_vendors'] as Map<String, dynamic>?;

    final capKw = (json['site_capacity_kw'] as num?)?.toDouble() ?? 3.0;
    final rate = (json['rate_per_kw'] as num?)?.toDouble() ?? 1000.0;
    final charges = (json['vendor_charges'] as num?)?.toDouble() ?? (capKw * rate);

    final custTot = (customer?['total_amount'] as num?)?.toDouble() ??
        (json['customer_total_amount'] as num?)?.toDouble() ??
        0.0;
    final custPaid = (customer?['paid_amount'] as num?)?.toDouble() ??
        (json['customer_paid_amount'] as num?)?.toDouble() ??
        0.0;

    final totCustSiteAmt = (json['total_customer_site_amount'] as num?)?.toDouble() ??
        (custTot > 0 ? custTot : 0.0);
    final totCashRecv = (json['total_cash_received'] as num?)?.toDouble() ?? 0.0;
    final totLoanCredit = (json['total_loan_credited'] as num?)?.toDouble() ?? 0.0;
    final totCustRecv = (json['total_customer_received'] as num?)?.toDouble() ??
        (totCashRecv + totLoanCredit > 0 ? (totCashRecv + totLoanCredit) : custPaid);
    final custOut = (json['customer_outstanding'] as num?)?.toDouble() ??
        ((totCustSiteAmt - totCustRecv) > 0 ? (totCustSiteAmt - totCustRecv) : 0.0);

    return VendorSiteAssignment(
      id: json['id'] as String? ?? '',
      vendorId: json['vendor_id'] as String? ?? '',
      customerId: json['customer_id'] as String? ?? '',
      assignedDate: json['assigned_date'] != null
          ? DateTime.tryParse(json['assigned_date'] as String) ?? DateTime.now()
          : DateTime.now(),
      siteCapacityKw: capKw,
      ratePerKw: rate,
      vendorCharges: charges,
      otherExpenses: (json['other_expenses'] as num?)?.toDouble() ?? 0.0,
      expenseRemarks: json['expense_remarks'] as String?,
      status: json['status'] as String? ?? 'Assigned',
      completionDate: json['completion_date'] != null ? DateTime.tryParse(json['completion_date'] as String) : null,
      notes: json['notes'] as String?,
      financialApproved: json['financial_approved'] as bool? ?? false,
      financialApprovedBy: json['financial_approved_by'] as String?,
      financialApprovedAt: json['financial_approved_at'] != null
          ? DateTime.tryParse(json['financial_approved_at'] as String)
          : null,
      settlementApproved: json['settlement_approved'] as bool? ?? false,
      settlementApprovedBy: json['settlement_approved_by'] as String?,
      settlementApprovedAt: json['settlement_approved_at'] != null
          ? DateTime.tryParse(json['settlement_approved_at'] as String)
          : null,
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'] as String) : null,
      updatedAt: json['updated_at'] != null ? DateTime.tryParse(json['updated_at'] as String) : null,
      createdBy: json['created_by'] as String?,
      updatedBy: json['updated_by'] as String?,
      consumerNo: json['consumer_no'] as String? ?? customer?['consumer_no'] as String?,
      customerName: json['customer_name'] as String? ?? customer?['name'] as String?,
      customerMobile: json['customer_mobile'] as String? ?? customer?['mobile'] as String?,
      customerAddress: json['customer_address'] as String? ?? customer?['address'] as String?,
      customerVillageCity: (customer?['village_city'] ?? customer?['address']) as String?,
      customerTotalAmount: custTot,
      customerPaidAmount: custPaid,
      vendorCode: vendor?['vendor_code'] as String?,
      vendorName: vendor?['name'] as String?,
      // Payment & Bank Loan Fields
      paymentType: json['payment_type'] as String? ?? 'Cash Customer',
      totalCustomerSiteAmount: totCustSiteAmt,
      loanBankName: json['loan_bank_name'] as String?,
      loanApplicationId: json['loan_application_id'] as String?,
      loanAppliedAmount: (json['loan_applied_amount'] as num?)?.toDouble() ?? 0.0,
      loanSanctionedAmount: (json['loan_sanctioned_amount'] as num?)?.toDouble() ?? 0.0,
      loanStatus: json['loan_status'] as String? ?? 'Not Required',
      totalCashReceived: totCashRecv,
      totalLoanCredited: totLoanCredit,
      totalCustomerReceived: totCustRecv,
      customerOutstanding: custOut,
      customerPaymentStatus: json['customer_payment_status'] as String? ?? 'Pending',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id.isNotEmpty) 'id': id,
      'vendor_id': vendorId,
      'customer_id': customerId,
      'assigned_date': assignedDate.toIso8601String().split('T').first,
      'site_capacity_kw': siteCapacityKw,
      'rate_per_kw': ratePerKw,
      'vendor_charges': vendorCharges,
      'other_expenses': otherExpenses,
      if (expenseRemarks != null) 'expense_remarks': expenseRemarks,
      'status': status,
      if (completionDate != null) 'completion_date': completionDate!.toIso8601String().split('T').first,
      if (notes != null) 'notes': notes,
      'financial_approved': financialApproved,
      if (financialApprovedBy != null) 'financial_approved_by': financialApprovedBy,
      if (financialApprovedAt != null) 'financial_approved_at': financialApprovedAt!.toIso8601String(),
      'settlement_approved': settlementApproved,
      if (settlementApprovedBy != null) 'settlement_approved_by': settlementApprovedBy,
      if (settlementApprovedAt != null) 'settlement_approved_at': settlementApprovedAt!.toIso8601String(),
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
      if (updatedAt != null) 'updated_at': updatedAt!.toIso8601String(),
      if (createdBy != null) 'created_by': createdBy,
      if (updatedBy != null) 'updated_by': updatedBy,
      // Payment & Bank Loan Fields
      'payment_type': paymentType,
      'total_customer_site_amount': totalCustomerSiteAmount,
      if (loanBankName != null) 'loan_bank_name': loanBankName,
      if (loanApplicationId != null) 'loan_application_id': loanApplicationId,
      'loan_applied_amount': loanAppliedAmount,
      'loan_sanctioned_amount': loanSanctionedAmount,
      'loan_status': loanStatus,
      'total_cash_received': totalCashReceived,
      'total_loan_credited': totalLoanCredited,
      'total_customer_received': totalCustomerReceived,
      'customer_outstanding': customerOutstanding,
      'customer_payment_status': customerPaymentStatus,
    };
  }

  VendorSiteAssignment copyWith({
    String? id,
    String? vendorId,
    String? customerId,
    DateTime? assignedDate,
    double? siteCapacityKw,
    double? ratePerKw,
    double? vendorCharges,
    double? otherExpenses,
    String? expenseRemarks,
    String? status,
    DateTime? completionDate,
    String? notes,
    bool? financialApproved,
    String? financialApprovedBy,
    DateTime? financialApprovedAt,
    bool? settlementApproved,
    String? settlementApprovedBy,
    DateTime? settlementApprovedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? createdBy,
    String? updatedBy,
    String? consumerNo,
    String? customerName,
    String? customerMobile,
    String? customerAddress,
    String? customerVillageCity,
    double? customerTotalAmount,
    double? customerPaidAmount,
    String? vendorCode,
    String? vendorName,
    String? paymentType,
    double? totalCustomerSiteAmount,
    String? loanBankName,
    String? loanApplicationId,
    double? loanAppliedAmount,
    double? loanSanctionedAmount,
    String? loanStatus,
    double? totalCashReceived,
    double? totalLoanCredited,
    double? totalCustomerReceived,
    double? customerOutstanding,
    String? customerPaymentStatus,
  }) {
    return VendorSiteAssignment(
      id: id ?? this.id,
      vendorId: vendorId ?? this.vendorId,
      customerId: customerId ?? this.customerId,
      assignedDate: assignedDate ?? this.assignedDate,
      siteCapacityKw: siteCapacityKw ?? this.siteCapacityKw,
      ratePerKw: ratePerKw ?? this.ratePerKw,
      vendorCharges: vendorCharges ?? this.vendorCharges,
      otherExpenses: otherExpenses ?? this.otherExpenses,
      expenseRemarks: expenseRemarks ?? this.expenseRemarks,
      status: status ?? this.status,
      completionDate: completionDate ?? this.completionDate,
      notes: notes ?? this.notes,
      financialApproved: financialApproved ?? this.financialApproved,
      financialApprovedBy: financialApprovedBy ?? this.financialApprovedBy,
      financialApprovedAt: financialApprovedAt ?? this.financialApprovedAt,
      settlementApproved: settlementApproved ?? this.settlementApproved,
      settlementApprovedBy: settlementApprovedBy ?? this.settlementApprovedBy,
      settlementApprovedAt: settlementApprovedAt ?? this.settlementApprovedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      createdBy: createdBy ?? this.createdBy,
      updatedBy: updatedBy ?? this.updatedBy,
      consumerNo: consumerNo ?? this.consumerNo,
      customerName: customerName ?? this.customerName,
      customerMobile: customerMobile ?? this.customerMobile,
      customerAddress: customerAddress ?? this.customerAddress,
      customerVillageCity: customerVillageCity ?? this.customerVillageCity,
      customerTotalAmount: customerTotalAmount ?? this.customerTotalAmount,
      customerPaidAmount: customerPaidAmount ?? this.customerPaidAmount,
      vendorCode: vendorCode ?? this.vendorCode,
      vendorName: vendorName ?? this.vendorName,
      paymentType: paymentType ?? this.paymentType,
      totalCustomerSiteAmount: totalCustomerSiteAmount ?? this.totalCustomerSiteAmount,
      loanBankName: loanBankName ?? this.loanBankName,
      loanApplicationId: loanApplicationId ?? this.loanApplicationId,
      loanAppliedAmount: loanAppliedAmount ?? this.loanAppliedAmount,
      loanSanctionedAmount: loanSanctionedAmount ?? this.loanSanctionedAmount,
      loanStatus: loanStatus ?? this.loanStatus,
      totalCashReceived: totalCashReceived ?? this.totalCashReceived,
      totalLoanCredited: totalLoanCredited ?? this.totalLoanCredited,
      totalCustomerReceived: totalCustomerReceived ?? this.totalCustomerReceived,
      customerOutstanding: customerOutstanding ?? this.customerOutstanding,
      customerPaymentStatus: customerPaymentStatus ?? this.customerPaymentStatus,
    );
  }
}
