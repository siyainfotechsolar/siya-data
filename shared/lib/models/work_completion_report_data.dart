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

  WorkCompletionReportData({
    required this.customerName,
    required this.consumerNo,
    required this.customerAddress,
    this.customerMobile = '',
    this.customerEmail = '',
    this.category = 'Private Sector / Residential',
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
      category: 'Private Sector / Residential',
      sanctionNo: sanction,
      applicationNo: customer.applicationId?.trim().isNotEmpty == true ? customer.applicationId!.trim() : cNo,
      applicationDate: customer.applicationDate ?? customer.submitDate ?? compDate.subtract(const Duration(days: 30)),
      completionDate: compDate,
      sanctionedCapacityKw: capKw,
      installedCapacityKw: capKw,
      moduleMake: 'Waaree Energies Ltd',
      moduleAlmmModel: 'WST-540-ALMM',
      moduleWattage: 540,
      moduleCount: modCount,
      moduleTotalCapacityKwp: totalKwp,
      moduleWarranty: '12 Years Product + 25 Years Performance',
      moduleSerialNos: 'WST540-001 to WST540-${modCount.toString().padLeft(3, '0')}',
      cellManufacturer: 'Premier Energies Ltd',
      cellGstInvoiceNo: 'PE/GST/2024/6710',
      inverterMake: 'Growatt New Energy',
      inverterModel: capKw <= 3.3 ? 'MIC 3300TL-X' : 'MOD ${capKw.ceil()}KTL3-X',
      inverterRating: '${capKw.toStringAsFixed(1)} kW, 1-Phase 230V, 50Hz',
      inverterControllerType: 'Dual MPPT / String Inverter',
      inverterCapacityKw: capKw <= 3.0 ? 3.3 : capKw,
      inverterHpd: 'Yes',
      inverterMfgYear: compDate.year,
      earthResistanceDetails: '3 Earthings (AC, DC, LA) < 5 Ohms',
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
}
