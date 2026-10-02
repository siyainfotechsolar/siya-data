import 'package:intl/intl.dart';

class PaymentMilestone {
  final int sr;
  final String stage;
  final String description;
  final double percentage;
  final double amount;
  final String notes;

  PaymentMilestone({
    required this.sr,
    required this.stage,
    required this.description,
    required this.percentage,
    required this.amount,
    this.notes = '',
  });

  factory PaymentMilestone.fromJson(Map<String, dynamic> json) {
    return PaymentMilestone(
      sr: json['sr'] is int ? json['sr'] : int.tryParse(json['sr']?.toString() ?? '1') ?? 1,
      stage: json['stage']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      percentage: (json['percentage'] as num?)?.toDouble() ?? 0.0,
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      notes: json['notes']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'sr': sr,
    'stage': stage,
    'description': description,
    'percentage': percentage,
    'amount': amount,
    'notes': notes,
  };

  PaymentMilestone copyWith({
    int? sr,
    String? stage,
    String? description,
    double? percentage,
    double? amount,
    String? notes,
  }) {
    return PaymentMilestone(
      sr: sr ?? this.sr,
      stage: stage ?? this.stage,
      description: description ?? this.description,
      percentage: percentage ?? this.percentage,
      amount: amount ?? this.amount,
      notes: notes ?? this.notes,
    );
  }
}

class ConsumerVendorAgreement {
  final String id;
  final String? customerId;
  final String consumerNo;
  final String customerName;
  final String customerAddress;
  final String villageCity;
  final String district;
  final String customerMobile;
  final String agreementNo;
  final DateTime executionDate;
  final String systemCapacity;
  final String systemType;
  final String schemeName;
  final double totalProjectCost;
  final double cfaSubsidyAmount;
  final double netCustomerPayable;
  final String vendorName;
  final String vendorAddress;
  final String vendorPhone;
  final String vendorEmail;
  final String vendorGstin;
  final String discomName;
  final List<PaymentMilestone> paymentMilestones;
  final String pdfFileName;
  final String? pdfFilePath;
  final String? fileUrl;
  final DateTime createdAt;
  final DateTime? updatedAt;

  String get vendorFirmName => vendorName;
  String get vendorMobile => vendorPhone;

  ConsumerVendorAgreement({
    required this.id,
    this.customerId,
    required this.consumerNo,
    required this.customerName,
    required this.customerAddress,
    this.villageCity = '',
    this.district = '',
    this.customerMobile = '',
    required this.agreementNo,
    required this.executionDate,
    this.systemCapacity = '3 kW',
    this.systemType = 'Grid Connected Rooftop Solar (RTS) Project',
    this.schemeName = 'PM - Surya Ghar: Muft Bijli Yojana',
    required this.totalProjectCost,
    this.cfaSubsidyAmount = 78000.0,
    required this.netCustomerPayable,
    String? vendorName,
    String? vendorFirmName,
    this.vendorAddress = '21, Mudavad Road, Betawad, Tal. Shindkheda, Dist. Dhule - 425403',
    String? vendorPhone,
    String? vendorMobile,
    this.vendorEmail = 'siyainfodigital@gmail.com',
    this.vendorGstin = '27CVTPK6358P1ZD',
    this.discomName = 'MSEDCL',
    List<PaymentMilestone>? paymentMilestones,
    String? pdfFileName,
    this.pdfFilePath,
    this.fileUrl,
    DateTime? createdAt,
    this.updatedAt,
  })  : vendorName = vendorFirmName ?? vendorName ?? 'SIYA INFOTECH & DIGITAL SOLUTIONS',
        vendorPhone = vendorMobile ?? vendorPhone ?? '7972143798',
        pdfFileName = pdfFileName ?? 'Annex_2_Agreement_${agreementNo}.pdf',
        createdAt = createdAt ?? DateTime.now(),
        paymentMilestones = paymentMilestones ?? defaultMilestones(totalProjectCost);

  /// Default 3 editable milestone terms based on industry standard PM Surya Ghar guidelines
  static List<PaymentMilestone> defaultMilestones(double totalCost) {
    final m1Amount = (totalCost * 0.20).roundToDouble();
    final m2Amount = (totalCost * 0.60).roundToDouble();
    final m3Amount = (totalCost - m1Amount - m2Amount).roundToDouble();

    return [
      PaymentMilestone(
        sr: 1,
        stage: 'Advance with Work Order / Agreement',
        description: 'Advance payment upon signing agreement & site survey verification',
        percentage: 20.0,
        amount: m1Amount,
        notes: 'Payable at contract signing',
      ),
      PaymentMilestone(
        sr: 2,
        stage: 'Material Delivery at Site',
        description: 'Delivery of Solar Modules, Inverter, GI Mounting Structure & BOS',
        percentage: 60.0,
        amount: m2Amount,
        notes: 'Payable upon physical material delivery',
      ),
      PaymentMilestone(
        sr: 3,
        stage: 'Installation, Testing & Handover',
        description: 'Complete installation, joint inspection & Net-Meter documentation',
        percentage: 20.0,
        amount: m3Amount,
        notes: 'Payable before net-meter commissioning',
      ),
    ];
  }

  /// Create a fresh Agreement populated with customer profile data
  factory ConsumerVendorAgreement.create({
    String? customerId,
    required String consumerNo,
    required String customerName,
    String? address,
    String? villageCity,
    String? district,
    String? mobileNo,
    String? agreementNo,
    DateTime? executionDate,
    String? systemCapacity,
    double? totalProjectCost,
    double? cfaSubsidyAmount,
    double? netCustomerPayable,
    List<PaymentMilestone>? paymentMilestones,
  }) {
    final now = DateTime.now();
    final date = executionDate ?? now;
    final capacity = (systemCapacity != null && systemCapacity.trim().isNotEmpty) ? systemCapacity.trim() : '3 kW';
    final cost = totalProjectCost ?? 160000.0;
    final subsidy = cfaSubsidyAmount ?? 78000.0;
    final netPayable = netCustomerPayable ?? (cost - subsidy > 0 ? cost - subsidy : cost);

    final cleanName = customerName.trim().replaceAll(RegExp(r'\s+'), '_').replaceAll(RegExp(r'[^\w\-]'), '');
    final cleanConsumer = consumerNo.trim().replaceAll(RegExp(r'\s+'), '');
    final agrNumber = agreementNo ?? 'SIYA-AGR-${date.year}-${cleanConsumer.length >= 4 ? cleanConsumer.substring(cleanConsumer.length - 4) : cleanConsumer}';

    final fileName = 'Agreement_${cleanName.isNotEmpty ? cleanName : "Customer"}_$agrNumber.pdf';

    return ConsumerVendorAgreement(
      id: 'agr_${now.millisecondsSinceEpoch}_${cleanConsumer.hashCode.abs()}',
      customerId: customerId,
      consumerNo: consumerNo.trim(),
      customerName: customerName.trim(),
      customerAddress: address?.trim() ?? '',
      villageCity: villageCity?.trim() ?? '',
      district: district?.trim() ?? '',
      customerMobile: mobileNo?.trim() ?? '',
      agreementNo: agrNumber,
      executionDate: date,
      systemCapacity: capacity,
      totalProjectCost: cost,
      cfaSubsidyAmount: subsidy,
      netCustomerPayable: netPayable,
      paymentMilestones: paymentMilestones ?? defaultMilestones(cost),
      pdfFileName: fileName,
    );
  }

  factory ConsumerVendorAgreement.fromJson(Map<String, dynamic> json) {
    final milestonesJson = json['payment_milestones'];
    List<PaymentMilestone>? milestones;
    if (milestonesJson is List) {
      milestones = milestonesJson
          .map((m) => PaymentMilestone.fromJson(Map<String, dynamic>.from(m as Map)))
          .toList();
    }

    final double totalCost = (json['total_project_cost'] as num?)?.toDouble() ?? 160000.0;

    return ConsumerVendorAgreement(
      id: json['id']?.toString() ?? '',
      customerId: json['customer_id']?.toString(),
      consumerNo: json['consumer_no']?.toString() ?? '',
      customerName: json['customer_name']?.toString() ?? '',
      customerAddress: json['customer_address']?.toString() ?? '',
      villageCity: json['village_city']?.toString() ?? '',
      district: json['district']?.toString() ?? '',
      customerMobile: json['customer_mobile']?.toString() ?? '',
      agreementNo: json['agreement_no']?.toString() ?? '',
      executionDate: json['execution_date'] != null
          ? DateTime.tryParse(json['execution_date'].toString()) ?? DateTime.now()
          : DateTime.now(),
      systemCapacity: json['system_capacity']?.toString() ?? '3 kW',
      systemType: json['system_type']?.toString() ?? 'Grid Connected Rooftop Solar (RTS) Project',
      schemeName: json['scheme_name']?.toString() ?? 'PM - Surya Ghar: Muft Bijli Yojana',
      totalProjectCost: totalCost,
      cfaSubsidyAmount: (json['cfa_subsidy_amount'] as num?)?.toDouble() ?? 78000.0,
      netCustomerPayable: (json['net_customer_payable'] as num?)?.toDouble() ?? (totalCost - 78000.0),
      vendorName: json['vendor_name']?.toString() ?? 'SIYA INFOTECH & DIGITAL SOLUTIONS',
      vendorAddress: json['vendor_address']?.toString() ?? '21, Mudavad Road, Betawad, Tal. Shindkheda, Dist. Dhule - 425403',
      vendorPhone: json['vendor_phone']?.toString() ?? '7972143798',
      vendorEmail: json['vendor_email']?.toString() ?? 'siyainfodigital@gmail.com',
      vendorGstin: json['vendor_gstin']?.toString() ?? '27CVTPK6358P1ZD',
      paymentMilestones: milestones ?? defaultMilestones(totalCost),
      pdfFileName: json['pdf_file_name']?.toString() ?? 'Agreement.pdf',
      pdfFilePath: json['pdf_file_path']?.toString(),
      fileUrl: json['file_url']?.toString(),
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'customer_id': customerId,
    'consumer_no': consumerNo,
    'customer_name': customerName,
    'customer_address': customerAddress,
    'village_city': villageCity,
    'district': district,
    'customer_mobile': customerMobile,
    'agreement_no': agreementNo,
    'execution_date': executionDate.toIso8601String(),
    'system_capacity': systemCapacity,
    'system_type': systemType,
    'scheme_name': schemeName,
    'total_project_cost': totalProjectCost,
    'cfa_subsidy_amount': cfaSubsidyAmount,
    'net_customer_payable': netCustomerPayable,
    'vendor_name': vendorName,
    'vendor_address': vendorAddress,
    'vendor_phone': vendorPhone,
    'vendor_email': vendorEmail,
    'vendor_gstin': vendorGstin,
    'payment_milestones': paymentMilestones.map((m) => m.toJson()).toList(),
    'pdf_file_name': pdfFileName,
    'pdf_file_path': pdfFilePath,
    'file_url': fileUrl,
    'created_at': createdAt.toIso8601String(),
  };

  ConsumerVendorAgreement copyWith({
    String? id,
    String? customerId,
    String? consumerNo,
    String? customerName,
    String? customerAddress,
    String? villageCity,
    String? district,
    String? customerMobile,
    String? agreementNo,
    DateTime? executionDate,
    String? systemCapacity,
    String? systemType,
    String? schemeName,
    double? totalProjectCost,
    double? cfaSubsidyAmount,
    double? netCustomerPayable,
    String? vendorName,
    String? vendorAddress,
    String? vendorPhone,
    String? vendorEmail,
    String? vendorGstin,
    List<PaymentMilestone>? paymentMilestones,
    String? pdfFileName,
    String? pdfFilePath,
    String? fileUrl,
    DateTime? createdAt,
  }) {
    return ConsumerVendorAgreement(
      id: id ?? this.id,
      customerId: customerId ?? this.customerId,
      consumerNo: consumerNo ?? this.consumerNo,
      customerName: customerName ?? this.customerName,
      customerAddress: customerAddress ?? this.customerAddress,
      villageCity: villageCity ?? this.villageCity,
      district: district ?? this.district,
      customerMobile: customerMobile ?? this.customerMobile,
      agreementNo: agreementNo ?? this.agreementNo,
      executionDate: executionDate ?? this.executionDate,
      systemCapacity: systemCapacity ?? this.systemCapacity,
      systemType: systemType ?? this.systemType,
      schemeName: schemeName ?? this.schemeName,
      totalProjectCost: totalProjectCost ?? this.totalProjectCost,
      cfaSubsidyAmount: cfaSubsidyAmount ?? this.cfaSubsidyAmount,
      netCustomerPayable: netCustomerPayable ?? this.netCustomerPayable,
      vendorName: vendorName ?? this.vendorName,
      vendorAddress: vendorAddress ?? this.vendorAddress,
      vendorPhone: vendorPhone ?? this.vendorPhone,
      vendorEmail: vendorEmail ?? this.vendorEmail,
      vendorGstin: vendorGstin ?? this.vendorGstin,
      paymentMilestones: paymentMilestones ?? this.paymentMilestones,
      pdfFileName: pdfFileName ?? this.pdfFileName,
      pdfFilePath: pdfFilePath ?? this.pdfFilePath,
      fileUrl: fileUrl ?? this.fileUrl,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  String get formattedExecutionDate => DateFormat('dd MMMM yyyy').format(executionDate);
  String get executionDay => DateFormat('dd').format(executionDate);
  String get executionMonth => DateFormat('MMMM').format(executionDate);
  String get executionYear => DateFormat('yyyy').format(executionDate);
}
