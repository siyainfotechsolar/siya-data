import '../models/company_master.dart';
import '../models/consumer_record.dart';

class WorkCompletionReportData {
  // Consumer Details
  final String customerName;
  final String consumerNo;
  final String customerAddress;
  final String customerMobile;
  final String customerEmail;
  final String category;
  final String siteType;
  final String electricalPhase;
  final String sanctionNo;
  final String applicationNo;
  final DateTime applicationDate;
  final DateTime completionDate;
  final double sanctionedCapacityKw;
  final double installedCapacityKw;

  // Module Specifications
  final String moduleMake;
  final String moduleAlmmModel;
  final int moduleWattage;
  final int moduleCount;
  final double moduleTotalCapacityKwp;
  final String moduleWarranty;
  final String moduleSerialNos;
  final String cellManufacturer;
  final String cellGstInvoiceNo;

  // Inverter (PCU) Specifications
  final String inverterMake;
  final String inverterModel;
  final String inverterRating;
  final String inverterControllerType;
  final double inverterCapacityKw;
  final String inverterHpd;
  final int inverterMfgYear;

  // Earthing & Safety
  final String earthResistanceDetails;
  final String earthResistanceCertified;
  final String lightningArrester;

  // Vendor Details
  final String vendorFirmName;
  final String vendorGstin;
  final String vendorAddress;
  final String vendorMobile;
  final String vendorEmail;
  final String authorizedPerson;
  final String discomName;

  // Consumer Identity
  final String consumerAadhar;

  bool get isNonSubsidy => siteType.trim().toLowerCase() == 'non-subsidy';
  bool get isSubsidy => !isNonSubsidy;
  bool get isDcrRequired => !isNonSubsidy;
  bool get isThreePhase => installedCapacityKw > 6.0 || electricalPhase.contains('3');

  WorkCompletionReportData({
    required this.customerName,
    required this.consumerNo,
    required this.customerAddress,
    this.customerMobile = '',
    this.customerEmail = '',
    this.category = 'Private Sector / Residential',
    this.siteType = 'Subsidy',
    this.electricalPhase = '1-Phase',
    required this.sanctionNo,
    required this.applicationNo,
    required this.applicationDate,
    required this.completionDate,
    required this.sanctionedCapacityKw,
    required this.installedCapacityKw,
    this.moduleMake = 'Waaree Energies Ltd',
    this.moduleAlmmModel = 'WST-540-ALMM',
    this.moduleWattage = 540,
    required this.moduleCount,
    required this.moduleTotalCapacityKwp,
    this.moduleWarranty = '12 Years Product + 25 Years Performance',
    this.moduleSerialNos = '',
    this.cellManufacturer = 'Premier Energies Ltd',
    this.cellGstInvoiceNo = 'PE/INV/2024/7821',
    this.inverterMake = 'Growatt New Energy',
    this.inverterModel = 'MIC 3300TL-X',
    this.inverterRating = '3.3 kW, 1-Phase 230V, 50Hz',
    this.inverterControllerType = 'Dual MPPT / Grid-Tie',
    this.inverterCapacityKw = 3.3,
    this.inverterHpd = 'Yes',
    this.inverterMfgYear = 2024,
    this.earthResistanceDetails = '3 Earthings (AC, DC, LA) < 5 Ohms',
    this.earthResistanceCertified = 'Found in order (< 5 Ohms) as per MNRE OM Dtd. 07.06.24',
    this.lightningArrester = 'Installed with dedicated copper earth',
    String? vendorFirmName,
    String? vendorGstin,
    String? vendorAddress,
    String? vendorMobile,
    String? vendorEmail,
    String? authorizedPerson,
    String? discomName,
    this.consumerAadhar = '',
  })  : vendorFirmName = vendorFirmName ?? CompanyMaster.current.companyName,
        vendorGstin = vendorGstin ?? CompanyMaster.current.gstin,
        vendorAddress = vendorAddress ?? CompanyMaster.current.address,
        vendorMobile = vendorMobile ?? CompanyMaster.current.mobile,
        vendorEmail = vendorEmail ?? CompanyMaster.current.email,
        authorizedPerson = authorizedPerson ?? CompanyMaster.current.signatoryName,
        discomName = discomName ?? CompanyMaster.current.discomName;

  factory WorkCompletionReportData.fromCustomer(
    ConsumerRecord customer, {
    String? customCustomerName,
    String? customConsumerNo,
    String? customAddress,
    String? customCapacity,
    DateTime? customCompletionDate,
    String? customAadhar,
    CompanyMaster? company,
  }) {
    final comp = company ?? CompanyMaster.current;
    final String name = (customCustomerName != null && customCustomerName.trim().isNotEmpty)
        ? customCustomerName.trim()
        : customer.name.trim();

    final String cNo = (customConsumerNo != null && customConsumerNo.trim().isNotEmpty)
        ? customConsumerNo.trim()
        : customer.consumerNo.trim();

    String addr = (customAddress != null && customAddress.trim().isNotEmpty)
        ? customAddress.trim()
        : '';
    if (addr.isEmpty) {
      if (customer.address != null && customer.address!.trim().isNotEmpty) {
        addr = customer.address!.trim();
      } else if (customer.village != null && customer.village!.trim().isNotEmpty) {
        addr = '${customer.village!.trim()}, Tal. Shindkheda, Dist. Dhule';
      } else {
        addr = 'Betawad, Tal. Shindkheda, Dist. Dhule - 425403';
      }
    }

    // Parse capacity
    double capKw = 3.0;
    String capStr = (customCapacity != null && customCapacity.trim().isNotEmpty)
        ? customCapacity.trim()
        : (customer.systemCapacity?.trim() ?? '');
    if (capStr.isEmpty && customer.remarks != null) {
      final m = RegExp(r'(\d+(?:\.\d+)?)\s*(?:kw|kW|KW|Kw)').firstMatch(customer.remarks!);
      if (m != null) capKw = double.tryParse(m.group(1)!) ?? 3.0;
    } else if (capStr.isNotEmpty) {
      final m = RegExp(r'(\d+(?:\.\d+)?)').firstMatch(capStr);
      if (m != null) capKw = double.tryParse(m.group(1)!) ?? 3.0;
    }

    // Above 6 kW is 3-Phase (415V, 50Hz); <= 6 kW is 1-Phase (230V, 50Hz)
    final bool isThreePhase = capKw > 6.0;
    final String phaseStr = isThreePhase ? '3-Phase 415V, 50Hz' : '1-Phase 230V, 50Hz';
    final String phaseShort = isThreePhase ? '3-Phase' : '1-Phase';

    // Non-subsidy sites do not require DCR
    final bool isNonSubsidy = customer.isNonSubsidy;

    final int modCount = (capKw * 1000 / 540).ceil();
    final double totalKwp = double.parse((modCount * 0.54).toStringAsFixed(2));

    final DateTime compDate = customCompletionDate ??
        customer.installationDate ??
        customer.rtsCompletionDate ??
        customer.submitDate ??
        DateTime.now();

    final String sanction = customer.applicationId?.trim().isNotEmpty == true
        ? customer.applicationId!.trim()
        : 'SIYA/SAN/${compDate.year}/${cNo.length > 5 ? cNo.substring(cNo.length - 5) : cNo}';

    return WorkCompletionReportData(
      customerName: name,
      consumerNo: cNo,
      customerAddress: addr,
      customerMobile: customer.mobile?.trim() ?? '',
      customerEmail: '',
      category: isNonSubsidy ? 'Commercial / Non-Subsidy' : 'Private Sector / Residential',
      siteType: customer.siteType,
      electricalPhase: phaseShort,
      sanctionNo: sanction,
      applicationNo: customer.applicationId?.trim().isNotEmpty == true ? customer.applicationId!.trim() : cNo,
      applicationDate: customer.applicationDate ?? customer.submitDate ?? compDate.subtract(const Duration(days: 30)),
      completionDate: compDate,
      sanctionedCapacityKw: capKw,
      installedCapacityKw: capKw,
      moduleMake: 'Waaree Energies Ltd',
      moduleAlmmModel: isNonSubsidy ? 'WST-540-Non-DCR' : 'WST-540-ALMM',
      moduleWattage: 540,
      moduleCount: modCount,
      moduleTotalCapacityKwp: totalKwp,
      moduleWarranty: '12 Years Product + 25 Years Performance',
      moduleSerialNos: 'WST540-001 to WST540-${modCount.toString().padLeft(3, '0')}',
      cellManufacturer: isNonSubsidy ? 'N/A (Non-DCR / Non-Subsidy)' : 'Premier Energies Ltd',
      cellGstInvoiceNo: isNonSubsidy ? 'N/A (Non-Subsidy)' : 'PE/GST/2024/6710',
      inverterMake: 'Growatt New Energy',
      inverterModel: capKw <= 3.3
          ? 'MIC 3300TL-X'
          : (capKw <= 6.0 ? 'MIN 6000TL-X' : 'MOD ${capKw.ceil()}KTL3-X'),
      inverterRating: '${capKw.toStringAsFixed(1)} kW, $phaseStr',
      inverterControllerType: isThreePhase ? 'Dual MPPT / 3-Phase Grid-Tied' : 'Dual MPPT / String Inverter',
      inverterCapacityKw: capKw <= 3.0 ? 3.3 : capKw,
      inverterHpd: 'Yes',
      inverterMfgYear: compDate.year,
      earthResistanceDetails: isThreePhase ? '4 Earthings (AC, DC, Body, LA) < 5 Ohms' : '3 Earthings (AC, DC, LA) < 5 Ohms',
      earthResistanceCertified: 'Certified & Found in order (< 5 Ohms) as per MNRE OM Dtd. 07.06.24',
      lightningArrester: 'Installed with dedicated copper earth',
      vendorFirmName: comp.companyName,
      vendorGstin: comp.gstin,
      vendorAddress: comp.address,
      vendorMobile: comp.mobile,
      vendorEmail: comp.email,
      authorizedPerson: comp.signatoryName,
      discomName: comp.discomName,
      consumerAadhar: customAadhar ?? '',
    );
  }

  WorkCompletionReportData copyWith({
    String? customerName,
    String? consumerNo,
    String? customerAddress,
    String? customerMobile,
    String? customerEmail,
    String? category,
    String? siteType,
    String? electricalPhase,
    String? sanctionNo,
    String? applicationNo,
    DateTime? applicationDate,
    DateTime? completionDate,
    double? sanctionedCapacityKw,
    double? installedCapacityKw,
    String? moduleMake,
    String? moduleAlmmModel,
    int? moduleWattage,
    int? moduleCount,
    double? moduleTotalCapacityKwp,
    String? moduleWarranty,
    String? moduleSerialNos,
    String? cellManufacturer,
    String? cellGstInvoiceNo,
    String? inverterMake,
    String? inverterModel,
    String? inverterRating,
    String? inverterControllerType,
    double? inverterCapacityKw,
    String? inverterHpd,
    int? inverterMfgYear,
    String? earthResistanceDetails,
    String? earthResistanceCertified,
    String? lightningArrester,
    String? vendorFirmName,
    String? vendorGstin,
    String? vendorAddress,
    String? vendorMobile,
    String? vendorEmail,
    String? authorizedPerson,
    String? discomName,
    String? consumerAadhar,
  }) {
    return WorkCompletionReportData(
      customerName: customerName ?? this.customerName,
      consumerNo: consumerNo ?? this.consumerNo,
      customerAddress: customerAddress ?? this.customerAddress,
      customerMobile: customerMobile ?? this.customerMobile,
      customerEmail: customerEmail ?? this.customerEmail,
      category: category ?? this.category,
      siteType: siteType ?? this.siteType,
      electricalPhase: electricalPhase ?? this.electricalPhase,
      sanctionNo: sanctionNo ?? this.sanctionNo,
      applicationNo: applicationNo ?? this.applicationNo,
      applicationDate: applicationDate ?? this.applicationDate,
      completionDate: completionDate ?? this.completionDate,
      sanctionedCapacityKw: sanctionedCapacityKw ?? this.sanctionedCapacityKw,
      installedCapacityKw: installedCapacityKw ?? this.installedCapacityKw,
      moduleMake: moduleMake ?? this.moduleMake,
      moduleAlmmModel: moduleAlmmModel ?? this.moduleAlmmModel,
      moduleWattage: moduleWattage ?? this.moduleWattage,
      moduleCount: moduleCount ?? this.moduleCount,
      moduleTotalCapacityKwp: moduleTotalCapacityKwp ?? this.moduleTotalCapacityKwp,
      moduleWarranty: moduleWarranty ?? this.moduleWarranty,
      moduleSerialNos: moduleSerialNos ?? this.moduleSerialNos,
      cellManufacturer: cellManufacturer ?? this.cellManufacturer,
      cellGstInvoiceNo: cellGstInvoiceNo ?? this.cellGstInvoiceNo,
      inverterMake: inverterMake ?? this.inverterMake,
      inverterModel: inverterModel ?? this.inverterModel,
      inverterRating: inverterRating ?? this.inverterRating,
      inverterControllerType: inverterControllerType ?? this.inverterControllerType,
      inverterCapacityKw: inverterCapacityKw ?? this.inverterCapacityKw,
      inverterHpd: inverterHpd ?? this.inverterHpd,
      inverterMfgYear: inverterMfgYear ?? this.inverterMfgYear,
      earthResistanceDetails: earthResistanceDetails ?? this.earthResistanceDetails,
      earthResistanceCertified: earthResistanceCertified ?? this.earthResistanceCertified,
      lightningArrester: lightningArrester ?? this.lightningArrester,
      vendorFirmName: vendorFirmName ?? this.vendorFirmName,
      vendorGstin: vendorGstin ?? this.vendorGstin,
      vendorAddress: vendorAddress ?? this.vendorAddress,
      vendorMobile: vendorMobile ?? this.vendorMobile,
      vendorEmail: vendorEmail ?? this.vendorEmail,
      authorizedPerson: authorizedPerson ?? this.authorizedPerson,
      discomName: discomName ?? this.discomName,
      consumerAadhar: consumerAadhar ?? this.consumerAadhar,
    );
  }

  Map<String, dynamic> toJson() => {
    'customer_name': customerName,
    'consumer_no': consumerNo,
    'customer_address': customerAddress,
    'customer_mobile': customerMobile,
    'customer_email': customerEmail,
    'category': category,
    'site_type': siteType,
    'electrical_phase': electricalPhase,
    'sanction_no': sanctionNo,
    'application_no': applicationNo,
    'application_date': applicationDate.toIso8601String(),
    'completion_date': completionDate.toIso8601String(),
    'sanctioned_capacity_kw': sanctionedCapacityKw,
    'installed_capacity_kw': installedCapacityKw,
    'module_make': moduleMake,
    'module_almm_model': moduleAlmmModel,
    'module_wattage': moduleWattage,
    'module_count': moduleCount,
    'module_total_capacity_kwp': moduleTotalCapacityKwp,
    'module_warranty': moduleWarranty,
    'module_serial_nos': moduleSerialNos,
    'cell_manufacturer': cellManufacturer,
    'cell_gst_invoice_no': cellGstInvoiceNo,
    'inverter_make': inverterMake,
    'inverter_model': inverterModel,
    'inverter_rating': inverterRating,
    'inverter_controller_type': inverterControllerType,
    'inverter_capacity_kw': inverterCapacityKw,
    'inverter_hpd': inverterHpd,
    'inverter_mfg_year': inverterMfgYear,
    'earth_resistance_details': earthResistanceDetails,
    'earth_resistance_certified': earthResistanceCertified,
    'lightning_arrester': lightningArrester,
    'vendor_firm_name': vendorFirmName,
    'vendor_gstin': vendorGstin,
    'vendor_address': vendorAddress,
    'vendor_mobile': vendorMobile,
    'vendor_email': vendorEmail,
    'authorized_person': authorizedPerson,
    'discom_name': discomName,
    'consumer_aadhar': consumerAadhar,
  };

  factory WorkCompletionReportData.fromJson(Map<String, dynamic> json) {
    return WorkCompletionReportData(
      customerName: json['customer_name']?.toString() ?? '',
      consumerNo: json['consumer_no']?.toString() ?? '',
      customerAddress: json['customer_address']?.toString() ?? '',
      customerMobile: json['customer_mobile']?.toString() ?? '',
      customerEmail: json['customer_email']?.toString() ?? '',
      category: json['category']?.toString() ?? 'Private Sector / Residential',
      siteType: json['site_type']?.toString() ?? 'Subsidy',
      electricalPhase: json['electrical_phase']?.toString() ?? '1-Phase',
      sanctionNo: json['sanction_no']?.toString() ?? '',
      applicationNo: json['application_no']?.toString() ?? '',
      applicationDate: json['application_date'] != null
          ? DateTime.tryParse(json['application_date'].toString()) ?? DateTime.now()
          : DateTime.now(),
      completionDate: json['completion_date'] != null
          ? DateTime.tryParse(json['completion_date'].toString()) ?? DateTime.now()
          : DateTime.now(),
      sanctionedCapacityKw: (json['sanctioned_capacity_kw'] as num?)?.toDouble() ?? 3.0,
      installedCapacityKw: (json['installed_capacity_kw'] as num?)?.toDouble() ?? 3.0,
      moduleMake: json['module_make']?.toString() ?? 'Waaree Energies Ltd',
      moduleAlmmModel: json['module_almm_model']?.toString() ?? 'WST-540-ALMM',
      moduleWattage: (json['module_wattage'] as num?)?.toInt() ?? 540,
      moduleCount: (json['module_count'] as num?)?.toInt() ?? 6,
      moduleTotalCapacityKwp: (json['module_total_capacity_kwp'] as num?)?.toDouble() ?? 3.24,
      moduleWarranty: json['module_warranty']?.toString() ?? '12 Years Product + 25 Years Performance',
      moduleSerialNos: json['module_serial_nos']?.toString() ?? '',
      cellManufacturer: json['cell_manufacturer']?.toString() ?? 'Premier Energies Ltd',
      cellGstInvoiceNo: json['cell_gst_invoice_no']?.toString() ?? 'PE/GST/2024/6710',
      inverterMake: json['inverter_make']?.toString() ?? 'Growatt New Energy',
      inverterModel: json['inverter_model']?.toString() ?? 'MIC 3300TL-X',
      inverterRating: json['inverter_rating']?.toString() ?? '3.3 kW, 1-Phase 230V, 50Hz',
      inverterControllerType: json['inverter_controller_type']?.toString() ?? 'Dual MPPT / String Inverter',
      inverterCapacityKw: (json['inverter_capacity_kw'] as num?)?.toDouble() ?? 3.3,
      inverterHpd: json['inverter_hpd']?.toString() ?? 'Yes',
      inverterMfgYear: (json['inverter_mfg_year'] as num?)?.toInt() ?? DateTime.now().year,
      earthResistanceDetails: json['earth_resistance_details']?.toString() ?? '3 Earthings (AC, DC, LA) < 5 Ohms',
      earthResistanceCertified: json['earth_resistance_certified']?.toString() ?? 'Certified & Found in order (< 5 Ohms) as per MNRE OM Dtd. 07.06.24',
      lightningArrester: json['lightning_arrester']?.toString() ?? 'Installed with dedicated copper earth',
      vendorFirmName: json['vendor_firm_name']?.toString() ?? 'SIYA INFOTECH & DIGITAL SOLUTIONS',
      vendorGstin: json['vendor_gstin']?.toString() ?? '27CVTPK6358P1ZD',
      vendorAddress: json['vendor_address']?.toString() ?? '21, Mudavad Road, Betawad, Tal. Shindkheda, Dist. Dhule - 425403',
      vendorMobile: json['vendor_mobile']?.toString() ?? '7972143798',
      vendorEmail: json['vendor_email']?.toString() ?? 'siyainfodigital@gmail.com',
      authorizedPerson: json['authorized_person']?.toString() ?? 'Authorized Signatory',
      discomName: json['discom_name']?.toString() ?? 'MSEDCL',
      consumerAadhar: json['consumer_aadhar']?.toString() ?? '',
    );
  }
}

