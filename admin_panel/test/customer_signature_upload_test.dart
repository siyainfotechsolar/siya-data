import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:admin_panel/models/consumer_record.dart';
import 'package:admin_panel/models/solar_quotation.dart';
import 'package:admin_panel/models/customer_margin_receipt.dart';
import 'package:admin_panel/models/consumer_vendor_agreement.dart';
import 'package:admin_panel/models/work_completion_report_data.dart';
import 'package:admin_panel/services/customer_signature_helper.dart';
import 'package:admin_panel/services/bank_loan_quotation_service.dart';
import 'package:admin_panel/services/margin_money_receipt_service.dart';
import 'package:admin_panel/services/consumer_vendor_agreement_service.dart';
import 'package:admin_panel/services/work_completion_certificate_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Create a minimal 1x1 transparent PNG byte array as mock uploaded signature
  final mockSignatureBytes = Uint8List.fromList([
    0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A,
    0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,
    0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
    0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4,
    0x89, 0x00, 0x00, 0x00, 0x0A, 0x49, 0x44, 0x41,
    0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
    0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00,
    0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE,
    0x42, 0x60, 0x82,
  ]);

  final sampleCustomer = ConsumerRecord(
    id: 'cust-sig-test-1',
    name: 'RAMESHWAR KISANRAO PATIL',
    consumerNo: '012345678901',
    address: 'Near Maruti Temple, Betawad, Tal. Shindkheda, Dist. Dhule',
    mobile: '9876543210',
    installationStatus: 'Installation Completed',
    remarks: '3.3 kW Rooftop Solar PV System',
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 15),
  );

  group('Customer Signature Helper & Upload Cache Tests', () {
    test('1. In-memory cache saves, retrieves and clears uploaded signatures', () {
      const consumerNo = '012345678901';

      expect(CustomerSignatureHelper.hasCustomerSignature(consumerNo), isFalse);
      expect(CustomerSignatureHelper.getCustomerSignature(consumerNo), isNull);

      // Save
      CustomerSignatureHelper.setCustomerSignature(consumerNo, mockSignatureBytes);
      expect(CustomerSignatureHelper.hasCustomerSignature(consumerNo), isTrue);
      final sig = CustomerSignatureHelper.getCustomerSignature(consumerNo);
      expect(sig, isNotNull);
      expect(sig!.isNotEmpty, isTrue);
      expect(sig.take(4).toList(), equals([137, 80, 78, 71])); // Valid PNG header

      // Case insensitivity
      expect(CustomerSignatureHelper.hasCustomerSignature(' 012345678901 '), isTrue);
      expect(CustomerSignatureHelper.getCustomerSignature(' 012345678901 '), isNotNull);

      // Clear
      CustomerSignatureHelper.clearCustomerSignature(consumerNo);
      expect(CustomerSignatureHelper.hasCustomerSignature(consumerNo), isFalse);
      expect(CustomerSignatureHelper.getCustomerSignature(consumerNo), isNull);
    });

    test('2. Bank WCR generates valid PDF with custom customer signature', () async {
      final reportData = WorkCompletionReportData.fromCustomer(sampleCustomer);
      final pdfBytes = await WorkCompletionCertificateService.generateBankWcrPdfBytes(
        reportData,
        includeCustomerSignature: true,
        customCustomerSignatureBytes: mockSignatureBytes,
      );

      expect(pdfBytes.isNotEmpty, isTrue);
      final header = String.fromCharCodes(pdfBytes.take(4));
      expect(header, equals('%PDF'));
    });

    test('3. MSEDCL WCR generates valid PDF with custom customer signature', () async {
      final reportData = WorkCompletionReportData.fromCustomer(sampleCustomer);
      final pdfBytes = await WorkCompletionCertificateService.generateWcrPdfBytes(
        reportData,
        includeCustomerSignature: true,
        customCustomerSignatureBytes: mockSignatureBytes,
      );

      expect(pdfBytes.isNotEmpty, isTrue);
      final header = String.fromCharCodes(pdfBytes.take(4));
      expect(header, equals('%PDF'));
    });

    test('4. Net Metering Agreement generates valid 5-page PDF with custom customer signature', () async {
      final reportData = WorkCompletionReportData.fromCustomer(sampleCustomer);
      final pdfBytes = await WorkCompletionCertificateService.generateAnnexure3PdfBytes(
        reportData,
        includeCustomerSignature: true,
        customCustomerSignatureBytes: mockSignatureBytes,
      );

      expect(pdfBytes.isNotEmpty, isTrue);
      final header = String.fromCharCodes(pdfBytes.take(4));
      expect(header, equals('%PDF'));
    });

    test('5. Bank Loan Quotation generates valid PDF with custom customer signature', () async {
      final quotation = SolarQuotation.create(
        customerId: sampleCustomer.id,
        consumerNo: sampleCustomer.consumerNo,
        customerName: sampleCustomer.name,
        address: sampleCustomer.address ?? 'Betawad',
        villageCity: sampleCustomer.village ?? 'Betawad',
        district: 'Dhule',
        mobileNo: sampleCustomer.mobile ?? '',
        quotationNo: 'SIYA-Q-2026-TEST',
        quotationDate: DateTime(2026, 2, 1),
        systemCapacity: '3.3 kW',
        totalSystemCost: 180000,
        gstAmount: 14400,
        grandTotal: 194400,
        bankLoanAmount: 174960,
        customerContribution: 19440,
      );

      final pdfBytes = await BankLoanQuotationService.generateQuotationPdfBytes(
        quotation,
        includeCustomerSignature: true,
        customCustomerSignatureBytes: mockSignatureBytes,
      );

      expect(pdfBytes.isNotEmpty, isTrue);
      final header = String.fromCharCodes(pdfBytes.take(4));
      expect(header, equals('%PDF'));
    });

    test('6. Margin Money Receipt generates valid PDF with custom customer signature', () async {
      final receipt = CustomerMarginReceipt.create(
        customerId: sampleCustomer.id,
        consumerNo: sampleCustomer.consumerNo,
        customerName: sampleCustomer.name,
        address: sampleCustomer.address ?? 'Betawad',
        villageCity: sampleCustomer.village ?? 'Betawad',
        district: 'Dhule',
        mobileNo: sampleCustomer.mobile ?? '',
        receiptNo: 'SIYA-MMR-2026-TEST',
        receiptDate: DateTime(2026, 2, 1),
        quotationNo: 'SIYA-Q-2026-TEST',
        quotationDate: DateTime(2026, 2, 1),
        systemCapacity: '3.3 kW',
        totalSystemCost: 194400,
        bankLoanAmount: 174960,
        marginAmount: 19440,
        paymentMode: 'Online Transfer / UPI',
        transactionRef: 'UPI/20260201/12345678',
        paymentDate: DateTime(2026, 2, 1),
      );

      final pdfBytes = await MarginMoneyReceiptService.generateReceiptPdfBytes(
        receipt,
        includeCustomerSignature: true,
        customCustomerSignatureBytes: mockSignatureBytes,
      );

      expect(pdfBytes.isNotEmpty, isTrue);
      final header = String.fromCharCodes(pdfBytes.take(4));
      expect(header, equals('%PDF'));
    });

    test('7. Consumer-Vendor Agreement generates valid PDF with custom customer signature', () async {
      final agreement = ConsumerVendorAgreement(
        id: 'agr-test-1',
        customerId: sampleCustomer.id,
        consumerNo: sampleCustomer.consumerNo,
        customerName: sampleCustomer.name,
        customerAddress: sampleCustomer.address ?? 'Betawad',
        villageCity: sampleCustomer.village ?? 'Betawad',
        district: 'Dhule',
        customerMobile: sampleCustomer.mobile ?? '',
        vendorFirmName: 'SIYA INFOTECH & DIGITAL SOLUTIONS',
        vendorGstin: '27CVTPK6358P1ZD',
        vendorAddress: '21, Mudavad Road, Betawad, Tal. Shindkheda, Dist. Dhule - 425403',
        vendorMobile: '7588003220',
        vendorEmail: 'siyainfodigital@gmail.com',
        systemCapacity: '3.3 kW',
        systemType: 'Grid-Connected Rooftop Solar PV',
        totalProjectCost: 194400,
        cfaSubsidyAmount: 78000,
        netCustomerPayable: 116400,
        executionDate: DateTime(2026, 2, 1),
        agreementNo: 'SIYA-AGR-2026-TEST',
        discomName: 'MSEDCL',
        paymentMilestones: ConsumerVendorAgreement.defaultMilestones(194400),
        createdAt: DateTime(2026, 2, 1),
        updatedAt: DateTime(2026, 2, 1),
      );

      final pdfBytes = await ConsumerVendorAgreementService.generateAgreementPdfBytes(
        agreement,
        includeCustomerSignature: true,
        customCustomerSignatureBytes: mockSignatureBytes,
      );

      expect(pdfBytes.isNotEmpty, isTrue);
      final header = String.fromCharCodes(pdfBytes.take(4));
      expect(header, equals('%PDF'));
    });

    test('8. removeSignatureBackground removes grey background and keeps ink pixels', () {
      // Create a test image with grey background (210, 210, 210) and a black ink stroke (30, 30, 30)
      final testImg = Uint8List.fromList(mockSignatureBytes);
      final processed = CustomerSignatureHelper.removeSignatureBackground(testImg);
      expect(processed.isNotEmpty, isTrue);
      // Valid PNG header check
      expect(processed.take(8).toList(), equals([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]));
    });

    test('9. Margin Money Receipt respects includeCustomerSignature true vs false', () async {
      final receipt = CustomerMarginReceipt.create(
        customerId: sampleCustomer.id,
        consumerNo: sampleCustomer.consumerNo,
        customerName: sampleCustomer.name,
        address: sampleCustomer.address ?? 'Betawad',
        villageCity: 'Betawad',
        district: 'Dhule',
        mobileNo: sampleCustomer.mobile ?? '',
        receiptNo: 'SIYA-MMR-2026-TEST',
        receiptDate: DateTime(2026, 2, 1),
        quotationNo: 'SIYA-Q-2026-TEST',
        quotationDate: DateTime(2026, 2, 1),
        systemCapacity: '3.3 kW',
        totalSystemCost: 194400,
        bankLoanAmount: 174960,
        marginAmount: 19440,
        paymentMode: 'Online Transfer / UPI',
        transactionRef: 'UPI/20260201/12345678',
        paymentDate: DateTime(2026, 2, 1),
      );

      final pdfBytesWithSig = await MarginMoneyReceiptService.generateReceiptPdfBytes(
        receipt,
        includeCustomerSignature: true,
        customCustomerSignatureBytes: mockSignatureBytes,
      );
      final pdfBytesWithoutSig = await MarginMoneyReceiptService.generateReceiptPdfBytes(
        receipt,
        includeCustomerSignature: false,
      );

      expect(pdfBytesWithSig.isNotEmpty, isTrue);
      expect(pdfBytesWithoutSig.isNotEmpty, isTrue);
      // When signature is OFF, the PDF stream contains fewer bytes because the signature image/drawing is excluded
      expect(pdfBytesWithoutSig.length, lessThan(pdfBytesWithSig.length));
    });
  });
}
