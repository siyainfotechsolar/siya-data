import '../models/company_master.dart';
import '../models/consumer_record.dart';
import '../models/consumer_vendor_agreement.dart';
import '../models/customer_margin_receipt.dart';
import '../models/invoice.dart';
import '../models/lead_record.dart';
import '../models/office_task.dart';
import '../models/solar_quotation.dart';
import '../models/work_completion_report_data.dart';

/// Central Master Data Hub — Single Source of Truth Coordinator.
/// 
/// Enforces ONE DETAIL -> ONE MASTER RECORD -> USED EVERYWHERE architecture.
/// Whenever customer, company, or staff master records change, this hub
/// ensures every downstream module, report, or document seamlessly resolves
/// the latest information.
class MasterDataHub {
  static CompanyMaster _company = CompanyMaster.defaultMaster();

  /// Get active Company Master
  static CompanyMaster get company => _company;

  /// Update active Company Master across the entire application runtime
  static void setCompanyMaster(CompanyMaster master) {
    _company = master;
    CompanyMaster.setGlobal(master);
  }

  /// Hydrate Solar Quotation with current Customer and Company Master data
  static SolarQuotation hydrateQuotation({
    required SolarQuotation quotation,
    required ConsumerRecord customer,
    CompanyMaster? customCompany,
  }) {
    final comp = customCompany ?? _company;
    return SolarQuotation.create(
      id: quotation.id,
      customerId: customer.id ?? quotation.customerId,
      consumerNo: customer.consumerNo.isNotEmpty ? customer.consumerNo : quotation.consumerNo,
      customerName: customer.name.isNotEmpty ? customer.name : quotation.customerName,
      address: (customer.address != null && customer.address!.isNotEmpty)
          ? customer.address!
          : quotation.address,
      villageCity: (customer.address != null && customer.address!.isNotEmpty)
          ? customer.address!
          : quotation.villageCity,
      district: quotation.district,
      mobileNo: (customer.mobile != null && customer.mobile!.isNotEmpty)
          ? customer.mobile!
          : quotation.mobileNo,
      quotationNo: quotation.quotationNo,
      quotationDate: quotation.quotationDate,
      systemCapacity: (customer.systemCapacity != null && customer.systemCapacity!.isNotEmpty)
          ? customer.systemCapacity!
          : quotation.systemCapacity,
      systemType: (customer.systemType != null && customer.systemType!.isNotEmpty)
          ? customer.systemType!
          : quotation.systemType,
      totalSystemCost: quotation.totalSystemCost,
      gstAmount: quotation.gstAmount,
      grandTotal: quotation.grandTotal,
      bankLoanAmount: quotation.bankLoanAmount,
      customerContribution: quotation.customerContribution,
      bankName: comp.bankName,
      branch: comp.branch,
      accountNo: comp.accountNo,
      ifscCode: comp.ifscCode,
      accountType: comp.accountType,
      signatoryName: comp.signatoryName,
      signatoryDesignation: comp.signatoryDesignation,
      pdfFilePath: quotation.pdfFilePath,
      fileUrl: quotation.fileUrl,
      createdBy: quotation.createdBy,
      items: quotation.items,
    );
  }

  /// Hydrate Invoice with current Customer and Company Master data
  static Invoice hydrateInvoice({
    required Invoice invoice,
    required ConsumerRecord customer,
    CompanyMaster? customCompany,
  }) {
    return Invoice(
      id: invoice.id,
      invoiceNumber: invoice.invoiceNumber,
      refInvoiceNo: invoice.refInvoiceNo,
      refQuotationId: invoice.refQuotationId,
      customerId: customer.id ?? invoice.customerId,
      consumerNo: customer.consumerNo.isNotEmpty ? customer.consumerNo : invoice.consumerNo,
      customerName: customer.name.isNotEmpty ? customer.name : invoice.customerName,
      address: (customer.address != null && customer.address!.isNotEmpty)
          ? customer.address!
          : invoice.address,
      villageCity: (customer.address != null && customer.address!.isNotEmpty)
          ? customer.address!
          : invoice.villageCity,
      district: invoice.district,
      mobileNo: (customer.mobile != null && customer.mobile!.isNotEmpty)
          ? customer.mobile!
          : invoice.mobileNo,
      invoiceDate: invoice.invoiceDate,
      systemCapacity: (customer.systemCapacity != null && customer.systemCapacity!.isNotEmpty)
          ? customer.systemCapacity!
          : invoice.systemCapacity,
      systemType: (customer.systemType != null && customer.systemType!.isNotEmpty)
          ? customer.systemType!
          : invoice.systemType,
      items: invoice.items,
      taxableAmount: invoice.taxableAmount,
      gst5: invoice.gst5,
      gst18: invoice.gst18,
      totalGst: invoice.totalGst,
      grandTotal: invoice.grandTotal,
      amountInWords: invoice.amountInWords,
      totalPaid: invoice.totalPaid,
      totalPending: invoice.totalPending,
      paymentStatus: invoice.paymentStatus,
      pdfFileName: invoice.pdfFileName,
      pdfFilePath: invoice.pdfFilePath,
      fileUrl: invoice.fileUrl,
      includeStampAndSignature: invoice.includeStampAndSignature,
      createdBy: invoice.createdBy,
      createdAt: invoice.createdAt,
      updatedAt: invoice.updatedAt,
    );
  }

  /// Create Work Completion Report Data directly from Central Customer & Company Master
  static WorkCompletionReportData createWorkCompletionReport({
    required ConsumerRecord customer,
    CompanyMaster? customCompany,
    String? customSanctionNo,
    String? customApplicationNo,
    DateTime? applicationDate,
    DateTime? completionDate,
  }) {
    final comp = customCompany ?? _company;
    final capNum = _parseCapacityNumber(customer.systemCapacity);

    return WorkCompletionReportData(
      customerName: customer.name,
      consumerNo: customer.consumerNo,
      customerAddress: customer.address ?? '',
      customerMobile: customer.mobile ?? '',
      category: 'Private Sector / Residential',
      sanctionNo: customSanctionNo ?? customer.applicationId ?? 'SAN-${customer.consumerNo}',
      applicationNo: customApplicationNo ?? customer.applicationId ?? customer.consumerNo,
      applicationDate: applicationDate ?? customer.submitDate ?? customer.createdAt ?? DateTime.now(),
      completionDate: completionDate ?? customer.installationDate ?? DateTime.now(),
      sanctionedCapacityKw: capNum,
      installedCapacityKw: capNum,
      moduleCount: (capNum * 2).round().clamp(1, 100),
      moduleTotalCapacityKwp: capNum,
      vendorFirmName: comp.companyName,
      vendorGstin: comp.gstin,
      vendorAddress: comp.address,
      vendorMobile: comp.mobile,
      vendorEmail: comp.email,
      authorizedPerson: comp.signatoryName,
      discomName: comp.discomName,
    );
  }

  /// Create Consumer Vendor Agreement directly from Central Customer & Company Master
  static ConsumerVendorAgreement createAgreement({
    required ConsumerRecord customer,
    CompanyMaster? customCompany,
    DateTime? executionDate,
    double? totalProjectCost,
    double? cfaSubsidyAmount,
    double? netCustomerPayable,
  }) {
    final comp = customCompany ?? _company;
    return ConsumerVendorAgreement.create(
      customerId: customer.id,
      consumerNo: customer.consumerNo,
      customerName: customer.name,
      address: customer.address,
      villageCity: customer.address,
      mobileNo: customer.mobile,
      executionDate: executionDate ?? customer.agreementDate ?? DateTime.now(),
      systemCapacity: customer.systemCapacity ?? '3 kW',
      totalProjectCost: totalProjectCost ?? customer.totalAmount,
      cfaSubsidyAmount: cfaSubsidyAmount,
      netCustomerPayable: netCustomerPayable,
    ).copyWith(
      vendorName: comp.companyName,
      vendorGstin: comp.gstin,
      vendorAddress: comp.address,
      vendorPhone: comp.mobile,
      vendorEmail: comp.email,
    );
  }

  /// Create Margin Money Receipt directly from Central Customer & Company Master
  static CustomerMarginReceipt createMarginReceipt({
    required ConsumerRecord customer,
    CompanyMaster? customCompany,
    String? quotationNo,
    DateTime? quotationDate,
    double? totalSystemCost,
    double? bankLoanAmount,
    double? marginAmount,
    String paymentMode = 'Cash',
    String transactionRef = 'Paid in Cash',
  }) {
    final comp = customCompany ?? _company;
    final cost = totalSystemCost ?? (customer.totalAmount > 0 ? customer.totalAmount : 160000.0);
    final loan = bankLoanAmount ?? (customer.loanSanctionedAmount > 0 ? customer.loanSanctionedAmount : (cost * 0.9).roundToDouble());
    final margin = marginAmount ?? (cost - loan > 0 ? cost - loan : (cost * 0.1).roundToDouble());

    return CustomerMarginReceipt.create(
      customerId: customer.id,
      consumerNo: customer.consumerNo,
      customerName: customer.name,
      address: customer.address ?? '',
      villageCity: customer.address ?? '',
      district: '',
      mobileNo: customer.mobile ?? '',
      quotationNo: quotationNo ?? 'SIYA-Q-${DateTime.now().year}-${customer.consumerNo}',
      quotationDate: quotationDate ?? DateTime.now(),
      systemCapacity: customer.systemCapacity ?? '3 kW',
      systemType: customer.systemType ?? 'On-Grid Solar System',
      totalSystemCost: cost,
      bankLoanAmount: loan,
      marginAmount: margin,
      paymentMode: paymentMode,
      transactionRef: transactionRef,
      bankName: comp.bankName,
      branch: comp.branch,
      accountNo: comp.accountNo,
      ifscCode: comp.ifscCode,
      signatoryName: comp.signatoryName,
      signatoryDesignation: comp.signatoryDesignation,
    );
  }

  /// Hydrate Lead with Customer Master data if linked
  static LeadRecord hydrateLead({
    required LeadRecord lead,
    required ConsumerRecord customer,
  }) {
    return lead.copyWith(
      customerId: customer.id ?? lead.customerId,
      customerName: customer.name.isNotEmpty ? customer.name : lead.customerName,
      mobileNo: (customer.mobile != null && customer.mobile!.isNotEmpty) ? customer.mobile! : lead.mobileNo,
      village: (customer.address != null && customer.address!.isNotEmpty) ? customer.address : lead.village,
      consumerNo: customer.consumerNo.isNotEmpty ? customer.consumerNo : lead.consumerNo,
      approxSystemSize: customer.systemCapacity ?? lead.approxSystemSize,
    );
  }

  /// Hydrate Office Task with Customer Master data
  static OfficeTask hydrateTask({
    required OfficeTask task,
    required ConsumerRecord customer,
  }) {
    return task.copyWith(
      customerId: customer.id ?? task.customerId,
      consumerNo: customer.consumerNo.isNotEmpty ? customer.consumerNo : task.consumerNo,
      customerName: customer.name.isNotEmpty ? customer.name : task.customerName,
    );
  }

  static double _parseCapacityNumber(String? capacityStr) {
    if (capacityStr == null || capacityStr.trim().isEmpty) return 3.0;
    final match = RegExp(r'([\d.]+)').firstMatch(capacityStr);
    if (match != null) {
      final parsed = double.tryParse(match.group(1)!);
      if (parsed != null && parsed > 0) return parsed;
    }
    return 3.0;
  }
}
