import 'package:intl/intl.dart';
import '../utils/number_to_words_utils.dart';
import 'solar_quotation.dart';

/// Invoice model — created ONLY when user explicitly clicks [Generate Invoice].
/// Never auto-created from quotation save/edit/PDF generation.
class Invoice {
  final String id;
  final String invoiceNumber;
  final String refInvoiceNo; // Quotation No. reference
  final String? refQuotationId; // Quotation ID reference
  final String? customerId;
  final String consumerNo;
  final String customerName;
  final String address;
  final String villageCity;
  final String district;
  final String mobileNo;
  final DateTime invoiceDate;
  final String systemCapacity;
  final String systemType;
  final List<Map<String, String>> items;
  final double taxableAmount;
  final double gst5;
  final double gst18;
  final double totalGst;
  final double grandTotal;
  final String amountInWords;
  final double totalPaid;
  final double totalPending;
  final String paymentStatus; // Paid, Partially Paid, Pending
  final String? pdfFileName;
  final String? pdfFilePath;
  final String? fileUrl;
  final bool includeStampAndSignature;
  final String? createdBy;
  final DateTime createdAt;
  final DateTime? updatedAt;

  Invoice({
    required this.id,
    required this.invoiceNumber,
    required this.refInvoiceNo,
    this.refQuotationId,
    this.customerId,
    required this.consumerNo,
    required this.customerName,
    required this.address,
    required this.villageCity,
    required this.district,
    required this.mobileNo,
    required this.invoiceDate,
    this.systemCapacity = '3 kW',
    this.systemType = 'On-Grid Solar System',
    required this.items,
    required this.taxableAmount,
    required this.gst5,
    required this.gst18,
    required this.totalGst,
    required this.grandTotal,
    required this.amountInWords,
    this.totalPaid = 0.0,
    double? totalPending,
    this.paymentStatus = 'Pending',
    this.pdfFileName,
    this.pdfFilePath,
    this.fileUrl,
    this.includeStampAndSignature = false,
    this.createdBy,
    DateTime? createdAt,
    this.updatedAt,
  })  : totalPending = totalPending ?? grandTotal,
        createdAt = createdAt ?? DateTime.now();

  /// Generate Invoice from a saved Quotation (manual creation only)
  factory Invoice.fromQuotation({
    required SolarQuotation quotation,
    required String invoiceNumber,
    String? createdBy,
  }) {
    final gst = SolarQuotationGstBreakdown.calculate(quotation.grandTotal);
    final words = NumberToWordsUtils.convertToIndianRupees(quotation.grandTotal);

    final safeCustomerName = quotation.customerName
        .trim()
        .replaceAll(RegExp(r'[^\w\s-]'), '')
        .replaceAll(RegExp(r'\s+'), '_');
    final safeInvoiceNo = invoiceNumber
        .trim()
        .replaceAll(RegExp(r'[^\w\s-]'), '_');
    final fileName = 'Invoice_${safeCustomerName}_$safeInvoiceNo.pdf';

    return Invoice(
      id: 'inv_${DateTime.now().millisecondsSinceEpoch}',
      invoiceNumber: invoiceNumber,
      refInvoiceNo: quotation.quotationNo,
      refQuotationId: quotation.id,
      customerId: quotation.customerId,
      consumerNo: quotation.consumerNo,
      customerName: quotation.customerName,
      address: quotation.address,
      villageCity: quotation.villageCity,
      district: quotation.district,
      mobileNo: quotation.mobileNo,
      invoiceDate: DateTime.now(),
      systemCapacity: quotation.systemCapacity,
      systemType: quotation.systemType,
      items: quotation.items.map((item) => Map<String, String>.from(item)).toList(),
      taxableAmount: gst.totalTaxableValue,
      gst5: gst.gst5,
      gst18: gst.gst18,
      totalGst: gst.totalGstIncluded,
      grandTotal: quotation.grandTotal,
      amountInWords: words,
      totalPaid: 0.0,
      totalPending: quotation.grandTotal,
      paymentStatus: 'Pending',
      pdfFileName: fileName,
      includeStampAndSignature: false,
      createdBy: createdBy,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'invoice_number': invoiceNumber,
      'ref_invoice_no': refInvoiceNo,
      'ref_quotation_id': refQuotationId,
      'customer_id': customerId,
      'consumer_no': consumerNo,
      'customer_name': customerName,
      'address': address,
      'village_city': villageCity,
      'district': district,
      'mobile_no': mobileNo,
      'invoice_date': invoiceDate.toIso8601String(),
      'system_capacity': systemCapacity,
      'system_type': systemType,
      'items': items,
      'taxable_amount': taxableAmount,
      'gst_5': gst5,
      'gst_18': gst18,
      'total_gst': totalGst,
      'grand_total': grandTotal,
      'amount_in_words': amountInWords,
      'total_paid': totalPaid,
      'total_pending': totalPending,
      'payment_status': paymentStatus,
      'pdf_file_name': pdfFileName,
      'pdf_file_path': pdfFilePath,
      'file_url': fileUrl,
      'include_stamp_and_signature': includeStampAndSignature,
      'created_by': createdBy,
      'created_at': createdAt.toIso8601String(),
      'updated_at': (updatedAt ?? DateTime.now()).toIso8601String(),
    };
  }

  factory Invoice.fromJson(Map<String, dynamic> json) {
    return Invoice(
      id: json['id']?.toString() ?? '',
      invoiceNumber: json['invoice_number']?.toString() ?? '',
      refInvoiceNo: json['ref_invoice_no']?.toString() ?? '',
      refQuotationId: json['ref_quotation_id']?.toString(),
      customerId: json['customer_id']?.toString(),
      consumerNo: json['consumer_no']?.toString() ?? '',
      customerName: json['customer_name']?.toString() ?? '',
      address: json['address']?.toString() ?? '',
      villageCity: json['village_city']?.toString() ?? '',
      district: json['district']?.toString() ?? '',
      mobileNo: json['mobile_no']?.toString() ?? '',
      invoiceDate: json['invoice_date'] != null
          ? DateTime.tryParse(json['invoice_date'].toString()) ?? DateTime.now()
          : DateTime.now(),
      systemCapacity: json['system_capacity']?.toString() ?? '3 kW',
      systemType: json['system_type']?.toString() ?? 'On-Grid Solar System',
      items: json['items'] != null
          ? (json['items'] as List)
              .map((item) => Map<String, String>.from(item as Map))
              .toList()
          : [],
      taxableAmount: _parseDouble(json['taxable_amount']),
      gst5: _parseDouble(json['gst_5']),
      gst18: _parseDouble(json['gst_18']),
      totalGst: _parseDouble(json['total_gst']),
      grandTotal: _parseDouble(json['grand_total']),
      amountInWords: json['amount_in_words']?.toString() ?? '',
      totalPaid: _parseDouble(json['total_paid']),
      totalPending: _parseDouble(json['total_pending']),
      paymentStatus: json['payment_status']?.toString() ?? 'Pending',
      pdfFileName: json['pdf_file_name']?.toString(),
      pdfFilePath: json['pdf_file_path']?.toString(),
      fileUrl: json['file_url']?.toString(),
      includeStampAndSignature: json['include_stamp_and_signature'] != false,
      createdBy: json['created_by']?.toString(),
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'].toString())
          : null,
    );
  }

  static double _parseDouble(dynamic v) {
    if (v is num) return v.toDouble();
    return double.tryParse(v?.toString() ?? '0') ?? 0.0;
  }

  Invoice copyWith({
    String? id,
    String? invoiceNumber,
    String? refInvoiceNo,
    String? refQuotationId,
    String? customerId,
    String? consumerNo,
    String? customerName,
    String? address,
    String? villageCity,
    String? district,
    String? mobileNo,
    DateTime? invoiceDate,
    String? systemCapacity,
    String? systemType,
    List<Map<String, String>>? items,
    double? taxableAmount,
    double? gst5,
    double? gst18,
    double? totalGst,
    double? grandTotal,
    String? amountInWords,
    double? totalPaid,
    double? totalPending,
    String? paymentStatus,
    String? pdfFileName,
    String? pdfFilePath,
    String? fileUrl,
    bool? includeStampAndSignature,
    String? createdBy,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Invoice(
      id: id ?? this.id,
      invoiceNumber: invoiceNumber ?? this.invoiceNumber,
      refInvoiceNo: refInvoiceNo ?? this.refInvoiceNo,
      refQuotationId: refQuotationId ?? this.refQuotationId,
      customerId: customerId ?? this.customerId,
      consumerNo: consumerNo ?? this.consumerNo,
      customerName: customerName ?? this.customerName,
      address: address ?? this.address,
      villageCity: villageCity ?? this.villageCity,
      district: district ?? this.district,
      mobileNo: mobileNo ?? this.mobileNo,
      invoiceDate: invoiceDate ?? this.invoiceDate,
      systemCapacity: systemCapacity ?? this.systemCapacity,
      systemType: systemType ?? this.systemType,
      items: items ?? this.items,
      taxableAmount: taxableAmount ?? this.taxableAmount,
      gst5: gst5 ?? this.gst5,
      gst18: gst18 ?? this.gst18,
      totalGst: totalGst ?? this.totalGst,
      grandTotal: grandTotal ?? this.grandTotal,
      amountInWords: amountInWords ?? this.amountInWords,
      totalPaid: totalPaid ?? this.totalPaid,
      totalPending: totalPending ?? this.totalPending,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      pdfFileName: pdfFileName ?? this.pdfFileName,
      pdfFilePath: pdfFilePath ?? this.pdfFilePath,
      fileUrl: fileUrl ?? this.fileUrl,
      includeStampAndSignature: includeStampAndSignature ?? this.includeStampAndSignature,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  String get formattedDate => DateFormat('dd / MM / yyyy').format(invoiceDate);

  /// GST breakdown (reusable from SolarQuotation module)
  SolarQuotationGstBreakdown get gstBreakdown =>
      SolarQuotationGstBreakdown.calculate(grandTotal);
}
