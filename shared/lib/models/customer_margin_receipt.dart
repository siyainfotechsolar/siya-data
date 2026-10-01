import 'package:intl/intl.dart';
import '../utils/number_to_words_utils.dart';
import 'solar_quotation.dart';

class CustomerMarginReceipt {
  final String id;
  final String? customerId;
  final String consumerNo;
  final String customerName;
  final String address;
  final String villageCity;
  final String district;
  final String mobileNo;
  final String receiptNo;
  final DateTime receiptDate;
  final String quotationNo;
  final DateTime quotationDate;
  final String systemCapacity;
  final String systemType;
  final double totalSystemCost;
  final double bankLoanAmount;
  final double marginAmount;
  final String marginAmountInWords;
  final String paymentMode;
  final String transactionRef;
  final DateTime paymentDate;
  final String bankName;
  final String branch;
  final String accountNo;
  final String ifscCode;
  final String upiId;
  final String signatoryName;
  final String signatoryDesignation;
  final String notes;
  final String pdfFileName;
  final String? pdfFilePath;
  final String? fileUrl;
  final DateTime createdAt;
  final String? createdBy;

  CustomerMarginReceipt({
    required this.id,
    this.customerId,
    required this.consumerNo,
    required this.customerName,
    required this.address,
    required this.villageCity,
    required this.district,
    required this.mobileNo,
    required this.receiptNo,
    required this.receiptDate,
    required this.quotationNo,
    required this.quotationDate,
    this.systemCapacity = '3 kW',
    this.systemType = 'On-Grid Solar System',
    required this.totalSystemCost,
    required this.bankLoanAmount,
    required    this.marginAmount,
    required this.marginAmountInWords,
    this.paymentMode = 'Cash',
    this.transactionRef = 'Paid in Cash',
    DateTime? paymentDate,
    this.bankName = 'STATE BANK OF INDIA',
    this.branch = 'Betawad',
    this.accountNo = '40662252403',
    this.ifscCode = 'SBIN0004798',
    this.upiId = 'siyainfodigital@sbi',
    this.signatoryName = 'Authorized Signatory',
    this.signatoryDesignation = 'Managing Director / Partner',
    this.notes = 'Received 10% Customer Margin Contribution in Cash towards PM Surya Ghar Bank Solar Loan installation.',
    required this.pdfFileName,
    this.pdfFilePath,
    this.fileUrl,
    DateTime? createdAt,
    this.createdBy,
  })  : paymentDate = paymentDate ?? receiptDate,
        createdAt = createdAt ?? DateTime.now();

  /// Create helper with auto-calculated margin words & standard naming
  factory CustomerMarginReceipt.create({
    String? id,
    String? customerId,
    required String consumerNo,
    required String customerName,
    required String address,
    required String villageCity,
    required String district,
    required String mobileNo,
    String? receiptNo,
    DateTime? receiptDate,
    String? quotationNo,
    DateTime? quotationDate,
    String systemCapacity = '3 kW',
    String systemType = 'On-Grid Solar System',
    required double totalSystemCost,
    double? bankLoanAmount,
    double? marginAmount,
    String paymentMode = 'Cash',
    String transactionRef = 'Paid in Cash',
    DateTime? paymentDate,
    String bankName = 'STATE BANK OF INDIA',
    String branch = 'Betawad',
    String accountNo = '40662252403',
    String ifscCode = 'SBIN0004798',
    String upiId = 'siyainfodigital@sbi',
    String signatoryName = 'Authorized Signatory',
    String signatoryDesignation = 'Managing Director / Partner',
    String? notes,
    String? createdBy,
  }) {
    final now = DateTime.now();
    final rDate = receiptDate ?? now;
    final qDate = quotationDate ?? now;
    final pDate = paymentDate ?? rDate;

    final suffix = consumerNo.length > 4 ? consumerNo.substring(consumerNo.length - 4) : consumerNo;
    final generatedReceiptNo = receiptNo ?? 'SIYA-MMR-${rDate.year}-$suffix';
    final generatedQuotationNo = quotationNo ?? 'SIYA-Q-${qDate.year}-$suffix';

    final effectiveMargin = marginAmount ?? (totalSystemCost * 0.10).roundToDouble();
    final effectiveLoan = bankLoanAmount ?? (totalSystemCost - effectiveMargin).clamp(0.0, double.infinity);
    final words = NumberToWordsUtils.convertToIndianRupees(effectiveMargin);

    final safeCustName = customerName.replaceAll(RegExp(r'[^\w\s-]'), '').replaceAll(RegExp(r'\s+'), '_');
    final fileName = 'MarginReceipt_${safeCustName}_$generatedReceiptNo.pdf';

    return CustomerMarginReceipt(
      id: id ?? 'mmr_${DateTime.now().millisecondsSinceEpoch}_$suffix',
      customerId: customerId,
      consumerNo: consumerNo,
      customerName: customerName,
      address: address,
      villageCity: villageCity,
      district: district,
      mobileNo: mobileNo,
      receiptNo: generatedReceiptNo,
      receiptDate: rDate,
      quotationNo: generatedQuotationNo,
      quotationDate: qDate,
      systemCapacity: systemCapacity,
      systemType: systemType,
      totalSystemCost: totalSystemCost,
      bankLoanAmount: effectiveLoan,
      marginAmount: effectiveMargin,
      marginAmountInWords: words,
      paymentMode: paymentMode,
      transactionRef: transactionRef,
      paymentDate: pDate,
      bankName: bankName,
      branch: branch,
      accountNo: accountNo,
      ifscCode: ifscCode,
      upiId: upiId,
      signatoryName: signatoryName,
      signatoryDesignation: signatoryDesignation,
      notes: notes ?? 'Received 10% Customer Margin Contribution in Cash towards PM Surya Ghar Bank Solar Loan installation.',
      pdfFileName: fileName,
      createdBy: createdBy,
    );
  }

  /// Create directly from an existing SolarQuotation
  factory CustomerMarginReceipt.fromQuotation(
    SolarQuotation q, {
    String? receiptNo,
    DateTime? receiptDate,
    String paymentMode = 'Cash',
    String transactionRef = 'Paid in Cash',
    DateTime? paymentDate,
    double? marginAmount,
    String? notes,
  }) {
    final now = DateTime.now();
    final rDate = receiptDate ?? now;
    final suffix = q.consumerNo.length > 4 ? q.consumerNo.substring(q.consumerNo.length - 4) : q.consumerNo;
    final generatedReceiptNo = receiptNo ?? 'SIYA-MMR-${rDate.year}-$suffix';

    final effectiveMargin = marginAmount ?? (q.customerContribution > 0 ? q.customerContribution : (q.grandTotal * 0.10).roundToDouble());
    final effectiveLoan = (q.grandTotal - effectiveMargin).clamp(0.0, double.infinity);
    final words = NumberToWordsUtils.convertToIndianRupees(effectiveMargin);

    final safeCustName = q.customerName.replaceAll(RegExp(r'[^\w\s-]'), '').replaceAll(RegExp(r'\s+'), '_');
    final fileName = 'MarginReceipt_${safeCustName}_$generatedReceiptNo.pdf';

    return CustomerMarginReceipt(
      id: 'mmr_${DateTime.now().millisecondsSinceEpoch}_$suffix',
      customerId: q.customerId,
      consumerNo: q.consumerNo,
      customerName: q.customerName,
      address: q.address,
      villageCity: q.villageCity,
      district: q.district,
      mobileNo: q.mobileNo,
      receiptNo: generatedReceiptNo,
      receiptDate: rDate,
      quotationNo: q.quotationNo,
      quotationDate: q.quotationDate,
      systemCapacity: q.systemCapacity,
      systemType: q.systemType,
      totalSystemCost: q.grandTotal,
      bankLoanAmount: effectiveLoan,
      marginAmount: effectiveMargin,
      marginAmountInWords: words,
      paymentMode: paymentMode,
      transactionRef: transactionRef,
      paymentDate: paymentDate ?? rDate,
      bankName: q.bankName,
      branch: q.branch,
      accountNo: q.accountNo,
      ifscCode: q.ifscCode,
      upiId: q.upiId,
      signatoryName: q.signatoryName,
      signatoryDesignation: q.signatoryDesignation,
      notes: notes ?? 'Received 10% Customer Margin Contribution towards PM Surya Ghar Bank Solar Loan installation.',
      pdfFileName: fileName,
      createdBy: q.createdBy,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'customer_id': customerId,
      'consumer_no': consumerNo,
      'customer_name': customerName,
      'address': address,
      'village_city': villageCity,
      'district': district,
      'mobile_no': mobileNo,
      'receipt_no': receiptNo,
      'receipt_date': receiptDate.toIso8601String(),
      'quotation_no': quotationNo,
      'quotation_date': quotationDate.toIso8601String(),
      'system_capacity': systemCapacity,
      'system_type': systemType,
      'total_system_cost': totalSystemCost,
      'bank_loan_amount': bankLoanAmount,
      'margin_amount': marginAmount,
      'margin_amount_in_words': marginAmountInWords,
      'payment_mode': paymentMode,
      'transaction_ref': transactionRef,
      'payment_date': paymentDate.toIso8601String(),
      'bank_name': bankName,
      'branch': branch,
      'account_no': accountNo,
      'ifsc_code': ifscCode,
      'upi_id': upiId,
      'signatory_name': signatoryName,
      'signatory_designation': signatoryDesignation,
      'notes': notes,
      'file_name': pdfFileName,
      'file_path': pdfFilePath,
      'file_url': fileUrl,
      'created_at': createdAt.toIso8601String(),
      'created_by': createdBy,
    };
  }

  factory CustomerMarginReceipt.fromJson(Map<String, dynamic> map) {
    return CustomerMarginReceipt(
      id: map['id']?.toString() ?? '',
      customerId: map['customer_id']?.toString(),
      consumerNo: map['consumer_no']?.toString() ?? '',
      customerName: map['customer_name']?.toString() ?? '',
      address: map['address']?.toString() ?? '',
      villageCity: map['village_city']?.toString() ?? '',
      district: map['district']?.toString() ?? '',
      mobileNo: map['mobile_no']?.toString() ?? '',
      receiptNo: map['receipt_no']?.toString() ?? '',
      receiptDate: map['receipt_date'] != null
          ? DateTime.tryParse(map['receipt_date'].toString()) ?? DateTime.now()
          : DateTime.now(),
      quotationNo: map['quotation_no']?.toString() ?? '',
      quotationDate: map['quotation_date'] != null
          ? DateTime.tryParse(map['quotation_date'].toString()) ?? DateTime.now()
          : DateTime.now(),
      systemCapacity: map['system_capacity']?.toString() ?? '3 kW',
      systemType: map['system_type']?.toString() ?? 'On-Grid Solar System',
      totalSystemCost: (map['total_system_cost'] as num?)?.toDouble() ?? 160000.0,
      bankLoanAmount: (map['bank_loan_amount'] as num?)?.toDouble() ?? 144000.0,
      marginAmount: (map['margin_amount'] as num?)?.toDouble() ?? 16000.0,
      marginAmountInWords: map['margin_amount_in_words']?.toString() ?? '',
      paymentMode: map['payment_mode']?.toString() ?? 'Online / UPI',
      transactionRef: map['transaction_ref']?.toString() ?? 'Self / Bank Transfer',
      paymentDate: map['payment_date'] != null
          ? DateTime.tryParse(map['payment_date'].toString()) ?? DateTime.now()
          : DateTime.now(),
      bankName: map['bank_name']?.toString() ?? 'STATE BANK OF INDIA',
      branch: map['branch']?.toString() ?? 'Betawad',
      accountNo: map['account_no']?.toString() ?? '40662252403',
      ifscCode: map['ifsc_code']?.toString() ?? 'SBIN0004798',
      upiId: map['upi_id']?.toString() ?? 'siyainfodigital@sbi',
      signatoryName: map['signatory_name']?.toString() ?? 'Authorized Signatory',
      signatoryDesignation: map['signatory_designation']?.toString() ?? 'Managing Director / Partner',
      notes: map['notes']?.toString() ?? '',
      pdfFileName: map['file_name']?.toString() ?? 'margin_receipt.pdf',
      pdfFilePath: map['file_path']?.toString(),
      fileUrl: map['file_url']?.toString(),
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      createdBy: map['created_by']?.toString(),
    );
  }

  CustomerMarginReceipt copyWith({
    String? id,
    String? customerId,
    String? consumerNo,
    String? customerName,
    String? address,
    String? villageCity,
    String? district,
    String? mobileNo,
    String? receiptNo,
    DateTime? receiptDate,
    String? quotationNo,
    DateTime? quotationDate,
    String? systemCapacity,
    String? systemType,
    double? totalSystemCost,
    double? bankLoanAmount,
    double? marginAmount,
    String? marginAmountInWords,
    String? paymentMode,
    String? transactionRef,
    DateTime? paymentDate,
    String? bankName,
    String? branch,
    String? accountNo,
    String? ifscCode,
    String? upiId,
    String? signatoryName,
    String? signatoryDesignation,
    String? notes,
    String? pdfFileName,
    String? pdfFilePath,
    String? fileUrl,
    DateTime? createdAt,
    String? createdBy,
  }) {
    return CustomerMarginReceipt(
      id: id ?? this.id,
      customerId: customerId ?? this.customerId,
      consumerNo: consumerNo ?? this.consumerNo,
      customerName: customerName ?? this.customerName,
      address: address ?? this.address,
      villageCity: villageCity ?? this.villageCity,
      district: district ?? this.district,
      mobileNo: mobileNo ?? this.mobileNo,
      receiptNo: receiptNo ?? this.receiptNo,
      receiptDate: receiptDate ?? this.receiptDate,
      quotationNo: quotationNo ?? this.quotationNo,
      quotationDate: quotationDate ?? this.quotationDate,
      systemCapacity: systemCapacity ?? this.systemCapacity,
      systemType: systemType ?? this.systemType,
      totalSystemCost: totalSystemCost ?? this.totalSystemCost,
      bankLoanAmount: bankLoanAmount ?? this.bankLoanAmount,
      marginAmount: marginAmount ?? this.marginAmount,
      marginAmountInWords: marginAmountInWords ?? this.marginAmountInWords,
      paymentMode: paymentMode ?? this.paymentMode,
      transactionRef: transactionRef ?? this.transactionRef,
      paymentDate: paymentDate ?? this.paymentDate,
      bankName: bankName ?? this.bankName,
      branch: branch ?? this.branch,
      accountNo: accountNo ?? this.accountNo,
      ifscCode: ifscCode ?? this.ifscCode,
      upiId: upiId ?? this.upiId,
      signatoryName: signatoryName ?? this.signatoryName,
      signatoryDesignation: signatoryDesignation ?? this.signatoryDesignation,
      notes: notes ?? this.notes,
      pdfFileName: pdfFileName ?? this.pdfFileName,
      pdfFilePath: pdfFilePath ?? this.pdfFilePath,
      fileUrl: fileUrl ?? this.fileUrl,
      createdAt: createdAt ?? this.createdAt,
      createdBy: createdBy ?? this.createdBy,
    );
  }
}
