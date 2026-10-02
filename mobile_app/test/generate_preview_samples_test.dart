import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/models/consumer_record.dart';
import 'package:mobile_app/models/solar_quotation.dart';
import 'package:mobile_app/models/customer_margin_receipt.dart';
import 'package:mobile_app/models/consumer_vendor_agreement.dart';
import 'package:mobile_app/services/bank_loan_quotation_service.dart';
import 'package:mobile_app/services/margin_money_receipt_service.dart';
import 'package:mobile_app/services/work_completion_certificate_service.dart';
import 'package:mobile_app/services/consumer_vendor_agreement_pdf_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final sampleCustomer = ConsumerRecord(
    id: 'cust_sample_01',
    consumerNo: '081234567890',
    name: 'RAMESHWAR KISANRAO PATIL',
    mobile: '9876543210',
    address: 'Plot No 14, Betawad, Tal. Shindkheda, Dist. Dhule',
    systemCapacity: '3.5 kW',
    totalAmount: 200000.0,
    paidAmount: 20000.0,
    pendingAmount: 180000.0,
    installationStatus: 'Installation Completed',
    installationDate: DateTime(2026, 10, 1),
    remarks: '3.5 kW Solar Rooftop System installed successfully',
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );

  final artifactDir = Directory(r'C:\Users\Admin\.gemini\antigravity-ide\brain\67039af7-0b8d-4c87-88c6-a2fc95b148ba');

  test('Generate all preview sample PDFs to artifact directory', () async {
    if (!artifactDir.existsSync()) {
      artifactDir.createSync(recursive: true);
    }

    // 1. Bank Loan Solar Quotation (WITH STAMP) — unique pdfFileName so BLANK version never overwrites it
    final quotation = SolarQuotation.create(
      consumerNo: sampleCustomer.consumerNo,
      customerName: sampleCustomer.name,
      mobileNo: sampleCustomer.mobile,
      villageCity: 'Betawad',
      district: 'Dhule',
      systemCapacity: '3.5 kW',
      grandTotal: 200000.0,
      bankLoanAmount: 180000.0,
      customerContribution: 20000.0,
    );

    // Give the WITH-STAMP quotation an explicit unique filename
    final quotationWithStamp = quotation.copyWith(
      pdfFileName: 'Quotation_RAMESHWAR_KISANRAO_PATIL_SIYA-Q-2026-7890.pdf',
    );

    final qFileWithStamp = await BankLoanQuotationService.generateQuotationPdf(
      quotation: quotationWithStamp,
      outputDirectory: artifactDir,
      includeStampAndSignature: true,
    );

    // 2. Bank Loan Solar Quotation (BLANK / WITHOUT STAMP) — different filename
    final qFileBlank = await BankLoanQuotationService.generateQuotationPdf(
      quotation: quotation.copyWith(pdfFileName: 'Quotation_RAMESHWAR_KISANRAO_PATIL_SIYA-Q-2026-7890_BLANK.pdf'),
      outputDirectory: artifactDir,
      includeStampAndSignature: false,
    );

    // 3. Customer Margin Money Receipt (WITH STAMP)
    final receipt = CustomerMarginReceipt.create(
      consumerNo: sampleCustomer.consumerNo,
      customerName: sampleCustomer.name,
      address: sampleCustomer.address ?? 'Betawad',
      villageCity: 'Betawad',
      district: 'Dhule',
      mobileNo: sampleCustomer.mobile ?? '9876543210',
      receiptNo: 'SIYA-MMR-2026-7890',
      receiptDate: DateTime.now(),
      quotationNo: quotation.quotationNo,
      quotationDate: quotation.quotationDate,
      systemCapacity: '3.5 kW',
      systemType: 'On-Grid Rooftop Solar PV',
      totalSystemCost: 200000.0,
      bankLoanAmount: 180000.0,
      marginAmount: 20000.0,
      paymentMode: 'Online Transfer (NEFT/IMPS)',
      transactionRef: 'NEFT-MAHB-987654321',
    );

    final rFile = await MarginMoneyReceiptService.generateReceiptPdf(
      receipt: receipt,
      outputDirectory: artifactDir,
      includeStampAndSignature: true,
    );

    // 4. Model Draft Vendor Agreement (WITH STAMP)
    final agreement = ConsumerVendorAgreement(
      id: 'agr_sample_01',
      customerId: sampleCustomer.id,
      consumerNo: sampleCustomer.consumerNo,
      customerName: sampleCustomer.name,
      customerAddress: sampleCustomer.address ?? 'Betawad',
      villageCity: 'Betawad',
      district: 'Dhule',
      customerMobile: sampleCustomer.mobile ?? '9876543210',
      vendorFirmName: 'SIYA INFOTECH & DIGITAL SOLUTIONS',
      vendorGstin: '27CVTPK6358P1ZD',
      vendorAddress: '21, Mudavad Road, Betawad, Tal. Shindkheda, Dist. Dhule - 425403',
      vendorMobile: '7588003220',
      vendorEmail: 'siyainfodigital@gmail.com',
      systemCapacity: '3.5 kW',
      systemType: 'Grid-Connected Rooftop Solar PV',
      totalProjectCost: 200000.0,
      cfaSubsidyAmount: 78000.0,
      netCustomerPayable: 122000.0,
      executionDate: DateTime.now(),
      agreementNo: 'SIYA-AGR-2026-7890',
      discomName: 'MSEDCL',
      paymentMilestones: ConsumerVendorAgreement.defaultMilestones(200000.0),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    final agrFile = await ConsumerVendorAgreementPdfService.generateAgreementPdf(
      agreement: agreement,
      outputDirectory: artifactDir,
      includeStampAndSignature: true,
    );

    // 5. Work Completion Report (WCR) (WITH STAMP)
    final wcrFile = await WorkCompletionCertificateService.generateCertificatePdf(
      customer: sampleCustomer,
      outputDirectory: artifactDir,
      includeStampAndSignature: true,
    );

    expect(qFileWithStamp.existsSync(), isTrue);
    expect(qFileBlank.existsSync(), isTrue);
    expect(rFile.existsSync(), isTrue);
    expect(agrFile.existsSync(), isTrue);
    expect(wcrFile.existsSync(), isTrue);

    print('PDF_GENERATION_SUCCESS: All 5 PDF previews generated successfully in artifact directory.');
  });
}
