import 'package:intl/intl.dart';
import '../utils/number_to_words_utils.dart';
import 'company_master.dart';

class SolarQuotation {
  final String id;
  final String? customerId;
  final String consumerNo;
  final String customerName;
  final String address;
  final String villageCity;
  final String district;
  final String mobileNo;
  final String quotationNo;
  final DateTime quotationDate;
  final String systemCapacity;
  final String systemType;
  final double totalSystemCost;
  final double gstAmount;
  final double grandTotal;
  final String amountInWords;
  final double bankLoanAmount;
  final double customerContribution;
  final String bankName;
  final String branch;
  final String accountNo;
  final String ifscCode;
  final String accountType;
  final String upiId;
  final String signatoryName;
  final String signatoryDesignation;
  final String pdfFileName;
  final String? pdfFilePath;
  final String? fileUrl;
  final DateTime createdAt;
  final String? createdBy;
  final List<Map<String, String>> items;

  SolarQuotation({
    required this.id,
    this.customerId,
    required this.consumerNo,
    required this.customerName,
    required this.address,
    required this.villageCity,
    required this.district,
    required this.mobileNo,
    required this.quotationNo,
    required this.quotationDate,
    this.systemCapacity = '3 kW',
    this.systemType = 'On-Grid Solar System',
    required this.totalSystemCost,
    this.gstAmount = 0.0,
    required this.grandTotal,
    required this.amountInWords,
    required this.bankLoanAmount,
    required this.customerContribution,
    String? bankName,
    String? branch,
    String? accountNo,
    String? ifscCode,
    String? accountType,
    String? upiId,
    String? signatoryName,
    String? signatoryDesignation,
    required this.pdfFileName,
    this.pdfFilePath,
    this.fileUrl,
    DateTime? createdAt,
    this.createdBy,
    List<Map<String, String>>? items,
  })  : bankName = bankName ?? CompanyMaster.current.bankName,
        branch = branch ?? CompanyMaster.current.branch,
        accountNo = accountNo ?? CompanyMaster.current.accountNo,
        ifscCode = ifscCode ?? CompanyMaster.current.ifscCode,
        accountType = accountType ?? CompanyMaster.current.accountType,
        upiId = upiId ?? '',
        signatoryName = signatoryName ?? CompanyMaster.current.signatoryName,
        signatoryDesignation = signatoryDesignation ?? CompanyMaster.current.signatoryDesignation,
        createdAt = createdAt ?? DateTime.now(),
        items = items ?? defaultItems(systemCapacity);

  /// Default 9 standard components as specified in solar quotation requirements
  static List<Map<String, String>> defaultItems([String? capacity]) {
    final capStr = (capacity != null && capacity.trim().isNotEmpty) ? capacity.trim() : '3 kW';
    return [
      {
        'sr': '1',
        'item': 'Solar PV Modules',
        'spec': 'Mono / TOPCon - $capStr',
        'qty': capStr,
      },
      {
        'sr': '2',
        'item': 'Grid-Tied Inverter',
        'spec': '$capStr Grid-Tied Inverter',
        'qty': '1 No.',
      },
      {
        'sr': '3',
        'item': 'Mounting Structure',
        'spec': 'Hot Dip GI',
        'qty': '1 Set',
      },
      {
        'sr': '4',
        'item': 'DC Cable',
        'spec': 'Solar UV Protected Cable',
        'qty': 'As Required',
      },
      {
        'sr': '5',
        'item': 'AC Cable',
        'spec': 'Armoured AC Cable',
        'qty': 'As Required',
      },
      {
        'sr': '6',
        'item': 'ACDB & DCDB',
        'spec': 'Protection Distribution Box',
        'qty': '1 Set',
      },
      {
        'sr': '7',
        'item': 'Earthing',
        'spec': 'Chemical GI Earthing Electrodes',
        'qty': 'As Required',
      },
      {
        'sr': '8',
        'item': 'Installation & Commissioning',
        'spec': 'Civil, Mechanical & Electrical Work',
        'qty': '1 Job',
      },
      {
        'sr': '9',
        'item': 'Net Metering Assistance',
        'spec': 'MSEDCL Portal & Documentation',
        'qty': '1 Job',
      },
    ];
  }

  /// Default 8 Scope of Work items
  static const List<String> defaultScopeOfWork = [
    'Supply of solar panels and inverter',
    'GI mounting structure',
    'DC/AC cabling',
    'ACDB/DCDB',
    'Earthing',
    'Installation & commissioning',
    'Net-metering assistance',
    'Testing and handover',
  ];

  /// Default 6 Important Notes
  static const List<String> defaultImportantNotes = [
    '1. Quotation prepared for bank loan / finance processing.',
    '2. Equipment make/model may vary based on availability.',
    '3. Government subsidy, if applicable, is subject to prevailing government rules and eligibility.',
    '4. Electricity-board charges, statutory fees and additional civil work, if applicable, may be charged separately.',
    '5. Installation will follow applicable MSEDCL/MNRE requirements.',
    '6. Quotation validity: 30 days.',
  ];

  /// Factory helper to build a quotation with auto-calculated values
  factory SolarQuotation.create({
    String? id,
    String? customerId,
    required String consumerNo,
    required String customerName,
    String? address,
    String? villageCity,
    String? district,
    String? mobileNo,
    String? quotationNo,
    DateTime? quotationDate,
    String systemCapacity = '3 kW',
    String systemType = 'On-Grid Solar System',
    double totalSystemCost = 160000.0,
    double gstAmount = 0.0,
    double? grandTotal,
    double? bankLoanAmount,
    double? customerContribution,
    String? bankName,
    String? branch,
    String? accountNo,
    String? ifscCode,
    String? accountType,
    String? upiId,
    String? signatoryName,
    String? signatoryDesignation,
    String? pdfFilePath,
    String? fileUrl,
    String? createdBy,
    List<Map<String, String>>? items,
  }) {
    final effectiveQuotationDate = quotationDate ?? DateTime.now();
    final effectiveGrandTotal = grandTotal ?? (totalSystemCost + gstAmount);
    // Standard bank financing is typically 90% loan, 10% customer contribution
    final effectiveContribution = customerContribution ?? (effectiveGrandTotal * 0.10).roundToDouble();
    final effectiveLoan = bankLoanAmount ?? (effectiveGrandTotal - effectiveContribution).roundToDouble();
    final words = NumberToWordsUtils.convertToIndianRupees(effectiveGrandTotal);

    final generatedId = id ?? 'quot_${DateTime.now().millisecondsSinceEpoch}';
    final effectiveQuotationNo = quotationNo ??
        'SIYA-Q-${effectiveQuotationDate.year}-${(consumerNo.length > 4 ? consumerNo.substring(consumerNo.length - 4) : consumerNo)}';

    final safeCustomerName = customerName
        .trim()
        .replaceAll(RegExp(r'[^\w\s-]'), '')
        .replaceAll(RegExp(r'\s+'), '_');
    final safeQuotationNo = effectiveQuotationNo
        .trim()
        .replaceAll(RegExp(r'[^\w\s-]'), '_');
    final fileName = 'Quotation_${safeCustomerName}_$safeQuotationNo.pdf';

    return SolarQuotation(
      id: generatedId,
      customerId: customerId,
      consumerNo: consumerNo.trim(),
      customerName: customerName.trim(),
      address: address?.trim() ?? '',
      villageCity: villageCity?.trim() ?? '',
      district: district?.trim() ?? '',
      mobileNo: mobileNo?.trim() ?? '',
      quotationNo: effectiveQuotationNo,
      quotationDate: effectiveQuotationDate,
      systemCapacity: systemCapacity.trim().isNotEmpty ? systemCapacity.trim() : '3 kW',
      systemType: systemType,
      totalSystemCost: totalSystemCost,
      gstAmount: gstAmount,
      grandTotal: effectiveGrandTotal,
      amountInWords: words,
      bankLoanAmount: effectiveLoan,
      customerContribution: effectiveContribution,
      bankName: bankName,
      branch: branch,
      accountNo: accountNo,
      ifscCode: ifscCode,
      accountType: accountType,
      upiId: upiId,
      signatoryName: signatoryName,
      signatoryDesignation: signatoryDesignation,
      pdfFileName: fileName,
      pdfFilePath: pdfFilePath,
      fileUrl: fileUrl,
      createdAt: DateTime.now(),
      createdBy: createdBy,
      items: items ?? defaultItems(systemCapacity),
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
      'quotation_no': quotationNo,
      'quotation_date': quotationDate.toIso8601String(),
      'system_capacity': systemCapacity,
      'system_type': systemType,
      'total_system_cost': totalSystemCost,
      'gst_amount': gstAmount,
      'grand_total': grandTotal,
      'amount_in_words': amountInWords,
      'bank_loan_amount': bankLoanAmount,
      'customer_contribution': customerContribution,
      'bank_name': bankName,
      'branch': branch,
      'account_no': accountNo,
      'ifsc_code': ifscCode,
      'account_type': accountType,
      'upi_id': upiId,
      'signatory_name': signatoryName,
      'signatory_designation': signatoryDesignation,
      'file_name': pdfFileName,
      'file_path': pdfFilePath,
      'file_url': fileUrl,
      'created_at': createdAt.toIso8601String(),
      'created_by': createdBy,
      'items': items,
    };
  }

  factory SolarQuotation.fromJson(Map<String, dynamic> json) {
    return SolarQuotation(
      id: json['id']?.toString() ?? '',
      customerId: json['customer_id']?.toString(),
      consumerNo: json['consumer_no']?.toString() ?? '',
      customerName: json['customer_name']?.toString() ?? '',
      address: json['address']?.toString() ?? '',
      villageCity: json['village_city']?.toString() ?? '',
      district: json['district']?.toString() ?? '',
      mobileNo: json['mobile_no']?.toString() ?? '',
      quotationNo: json['quotation_no']?.toString() ?? '',
      quotationDate: json['quotation_date'] != null
          ? DateTime.tryParse(json['quotation_date'].toString()) ?? DateTime.now()
          : DateTime.now(),
      systemCapacity: json['system_capacity']?.toString() ?? '3 kW',
      systemType: json['system_type']?.toString() ?? 'On-Grid Solar System',
      totalSystemCost: (json['total_system_cost'] is num)
          ? (json['total_system_cost'] as num).toDouble()
          : double.tryParse(json['total_system_cost']?.toString() ?? '0') ?? 0.0,
      gstAmount: (json['gst_amount'] is num)
          ? (json['gst_amount'] as num).toDouble()
          : double.tryParse(json['gst_amount']?.toString() ?? '0') ?? 0.0,
      grandTotal: (json['grand_total'] is num)
          ? (json['grand_total'] as num).toDouble()
          : double.tryParse(json['grand_total']?.toString() ?? '0') ?? 0.0,
      amountInWords: json['amount_in_words']?.toString() ?? '',
      bankLoanAmount: (json['bank_loan_amount'] is num)
          ? (json['bank_loan_amount'] as num).toDouble()
          : double.tryParse(json['bank_loan_amount']?.toString() ?? '0') ?? 0.0,
      customerContribution: (json['customer_contribution'] is num)
          ? (json['customer_contribution'] as num).toDouble()
          : double.tryParse(json['customer_contribution']?.toString() ?? '0') ?? 0.0,
      bankName: json['bank_name']?.toString() ?? 'STATE BANK OF INDIA',
      branch: json['branch']?.toString() ?? 'Betawad',
      accountNo: json['account_no']?.toString() ?? '40662252403',
      ifscCode: json['ifsc_code']?.toString() ?? 'SBIN0004798',
      accountType: json['account_type']?.toString() ?? 'Current Account',
      upiId: json['upi_id']?.toString() ?? 'siyainfodigital@sbi',
      signatoryName: json['signatory_name']?.toString() ?? 'Manoj Kshirsagar',
      signatoryDesignation: json['signatory_designation']?.toString() ?? 'Managing Director / Partner',
      pdfFileName: json['file_name']?.toString() ?? json['pdf_file_name']?.toString() ?? 'Quotation.pdf',
      pdfFilePath: json['file_path']?.toString() ?? json['pdf_file_path']?.toString(),
      fileUrl: json['file_url']?.toString(),
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      createdBy: json['created_by']?.toString(),
      items: json['items'] != null
          ? (json['items'] as List)
              .map((item) => Map<String, String>.from(item as Map))
              .toList()
          : defaultItems(json['system_capacity']?.toString() ?? '3 kW'),
    );
  }

  SolarQuotation copyWith({
    String? id,
    String? customerId,
    String? consumerNo,
    String? customerName,
    String? address,
    String? villageCity,
    String? district,
    String? mobileNo,
    String? quotationNo,
    DateTime? quotationDate,
    String? systemCapacity,
    String? systemType,
    double? totalSystemCost,
    double? gstAmount,
    double? grandTotal,
    String? amountInWords,
    double? bankLoanAmount,
    double? customerContribution,
    String? bankName,
    String? branch,
    String? accountNo,
    String? ifscCode,
    String? accountType,
    String? upiId,
    String? signatoryName,
    String? signatoryDesignation,
    String? pdfFileName,
    String? pdfFilePath,
    String? fileUrl,
    DateTime? createdAt,
    String? createdBy,
    List<Map<String, String>>? items,
  }) {
    return SolarQuotation(
      id: id ?? this.id,
      customerId: customerId ?? this.customerId,
      consumerNo: consumerNo ?? this.consumerNo,
      customerName: customerName ?? this.customerName,
      address: address ?? this.address,
      villageCity: villageCity ?? this.villageCity,
      district: district ?? this.district,
      mobileNo: mobileNo ?? this.mobileNo,
      quotationNo: quotationNo ?? this.quotationNo,
      quotationDate: quotationDate ?? this.quotationDate,
      systemCapacity: systemCapacity ?? this.systemCapacity,
      systemType: systemType ?? this.systemType,
      totalSystemCost: totalSystemCost ?? this.totalSystemCost,
      gstAmount: gstAmount ?? this.gstAmount,
      grandTotal: grandTotal ?? this.grandTotal,
      amountInWords: amountInWords ?? this.amountInWords,
      bankLoanAmount: bankLoanAmount ?? this.bankLoanAmount,
      customerContribution: customerContribution ?? this.customerContribution,
      bankName: bankName ?? this.bankName,
      branch: branch ?? this.branch,
      accountNo: accountNo ?? this.accountNo,
      ifscCode: ifscCode ?? this.ifscCode,
      accountType: accountType ?? this.accountType,
      upiId: upiId ?? this.upiId,
      signatoryName: signatoryName ?? this.signatoryName,
      signatoryDesignation: signatoryDesignation ?? this.signatoryDesignation,
      pdfFileName: pdfFileName ?? this.pdfFileName,
      pdfFilePath: pdfFilePath ?? this.pdfFilePath,
      fileUrl: fileUrl ?? this.fileUrl,
      createdAt: createdAt ?? this.createdAt,
      createdBy: createdBy ?? this.createdBy,
      items: items ?? this.items,
    );
  }

  String get formattedDate => DateFormat('dd / MM / yyyy').format(quotationDate);

  /// Statutory 70:30 GST calculation module (GST inclusive).
  SolarQuotationGstBreakdown get gstBreakdown => SolarQuotationGstBreakdown.calculate(grandTotal);
}

/// GST Module for Solar Quotation (Statutory 70:30 Rule).
///
/// Statutory structure:
/// - 70% of total amount → GST @ 5% (Goods: PV modules, inverters, structures)
/// - 30% of total amount → GST @ 18% (Services: Installation, commissioning, civil/electrical)
/// - Entered quotation amount is GST INCLUSIVE (do not add GST again).
class SolarQuotationGstBreakdown {
  final double totalAmount; // Total Amount (Including GST)
  final double portion70; // 70% Portion @ 5%
  final double gst5; // GST Included @ 5%
  final double taxable70; // 70% Taxable Value
  final double portion30; // 30% Portion @ 18%
  final double gst18; // GST Included @ 18%
  final double taxable30; // 30% Taxable Value
  final double totalTaxableValue; // Total Taxable Value
  final double totalGstIncluded; // Total GST Included
  final double grandTotal; // Grand Total (Including GST)

  const SolarQuotationGstBreakdown({
    required this.totalAmount,
    required this.portion70,
    required this.gst5,
    required this.taxable70,
    required this.portion30,
    required this.gst18,
    required this.taxable30,
    required this.totalTaxableValue,
    required this.totalGstIncluded,
    required this.grandTotal,
  });

  factory SolarQuotationGstBreakdown.calculate(double amount) {
    final validAmount = amount > 0 ? amount : 0.0;

    // 70% Portion @ 5% GST
    final p70 = validAmount * 0.70;
    final g5 = p70 * 5.0 / 105.0;
    final t70 = p70 - g5;

    // 30% Portion @ 18% GST
    final p30 = validAmount * 0.30;
    final g18 = p30 * 18.0 / 118.0;
    final t30 = p30 - g18;

    // Total GST Included & Taxable Value
    final totalGst = g5 + g18;
    final totalTaxable = validAmount - totalGst;

    return SolarQuotationGstBreakdown(
      totalAmount: validAmount,
      portion70: p70,
      gst5: g5,
      taxable70: t70,
      portion30: p30,
      gst18: g18,
      taxable30: t30,
      totalTaxableValue: totalTaxable,
      totalGstIncluded: totalGst,
      grandTotal: validAmount,
    );
  }
}
