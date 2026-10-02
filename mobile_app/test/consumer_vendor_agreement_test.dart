import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/models/consumer_record.dart';
import 'package:mobile_app/models/consumer_vendor_agreement.dart';
import 'package:mobile_app/services/consumer_vendor_agreement_pdf_service.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Consumer-Vendor Agreement (Annexure 2) PDF Tests', () {
    final testCustomer = ConsumerRecord(
      id: 'cust_001',
      consumerNo: '096590001608',
      name: 'SHRI NAMDEO DAGA MALI',
      address: 'PIMPRAD, TAL. SHINDKHEDA, DIST. DHULE',
      mobile: '9673220315',
      installationStatus: 'Installation Completed',
      remarks: '3 kW Solar Rooftop System installed successfully',
      totalAmount: 160000.0,
      loanSanctionedAmount: 128000.0,
    );

    test('1. Generates 3-page A4 Annexure 2 Agreement PDF with valid magic header', () async {
      final agreement = ConsumerVendorAgreement.create(
        customerId: testCustomer.id,
        consumerNo: testCustomer.consumerNo,
        customerName: testCustomer.name,
        address: testCustomer.address,
        villageCity: 'Pimprad',
        district: 'Dhule',
        mobileNo: testCustomer.mobile ?? '',
        agreementNo: 'SIYA-AGR-2026-1608',
        systemCapacity: '3 kW',
        totalProjectCost: 160000.0,
        cfaSubsidyAmount: 78000.0,
        netCustomerPayable: 82000.0,
      );

      final file = await ConsumerVendorAgreementPdfService.generateAgreementPdf(
        agreement: agreement,
      );

      expect(file, isNotNull);
      expect(file.existsSync(), isTrue);

      final bytes = await file.readAsBytes();
      expect(bytes.length, greaterThan(2000));

      try {
        final artifactPdf = File('C:/Users/Admin/.gemini/antigravity-ide/brain/2bed3ad8-3c6f-46aa-8dfe-7955750ffd6d/sample_consumer_vendor_agreement.pdf');
        if (artifactPdf.parent.existsSync()) {
          artifactPdf.writeAsBytesSync(bytes);
        }
      } catch (_) {}

      // PDF Magic Header: %PDF
      final magicHeader = String.fromCharCodes(bytes.take(4));
      expect(magicHeader, equals('%PDF'));

      // Verify exact 3 pages A4
      final loadedDoc = PdfDocument(inputBytes: bytes);
      expect(loadedDoc.pages.count, equals(3));
      final size = loadedDoc.pages[0].size;
      expect(size.width, closeTo(595.28, 1.0));
      expect(size.height, closeTo(841.89, 1.0));
      loadedDoc.dispose();
    });

    test('2. Output filename matches Agreement_[CustomerName]_[AgreementNo].pdf format', () {
      final agreement = ConsumerVendorAgreement.create(
        consumerNo: testCustomer.consumerNo,
        customerName: testCustomer.name,
        agreementNo: 'SIYA-AGR-2026-1608',
      );

      expect(agreement.pdfFileName, startsWith('Agreement_'));
      expect(agreement.pdfFileName, endsWith('.pdf'));
      expect(agreement.pdfFileName, contains('SHRI_NAMDEO_DAGA_MALI'));
      expect(agreement.pdfFileName, contains('SIYA-AGR-2026-1608'));
    });

    test('3. Milestone payment schedule sums to total cost and default milestones are valid', () {
      final agreement = ConsumerVendorAgreement.create(
        consumerNo: testCustomer.consumerNo,
        customerName: testCustomer.name,
        totalProjectCost: 160000.0,
      );

      expect(agreement.paymentMilestones.length, equals(3));
      final totalMilestoneAmount = agreement.paymentMilestones.fold<double>(0.0, (sum, m) => sum + m.amount);
      expect(totalMilestoneAmount, equals(160000.0));
      final totalPercent = agreement.paymentMilestones.fold<double>(0.0, (sum, m) => sum + m.percentage);
      expect(totalPercent, equals(100.0));
    });

    test('4. Verifies complete content and no truncation on all 3 pages', () async {
      final agreement = ConsumerVendorAgreement.create(
        customerId: testCustomer.id,
        consumerNo: testCustomer.consumerNo,
        customerName: testCustomer.name,
        address: testCustomer.address,
        villageCity: 'Pimprad',
        district: 'Dhule',
        mobileNo: testCustomer.mobile ?? '',
        agreementNo: 'SIYA-AGR-2026-1608',
        systemCapacity: '3 kW',
        totalProjectCost: 160000.0,
        cfaSubsidyAmount: 78000.0,
        netCustomerPayable: 82000.0,
      );

      final file = await ConsumerVendorAgreementPdfService.generateAgreementPdf(
        agreement: agreement,
      );
      final bytes = await file.readAsBytes();
      final loadedDoc = PdfDocument(inputBytes: bytes);
      expect(loadedDoc.pages.count, equals(3));

      final extractor = PdfTextExtractor(loadedDoc);

      // Page 1 assertions
      final p1Text = extractor.extractText(startPageIndex: 0, endPageIndex: 0);
      expect(p1Text, contains('Model Draft Agreement'));
      expect(p1Text, contains('Between'));
      expect(p1Text, contains('SHRI NAMDEO DAGA MALI'));
      expect(p1Text, contains('SIYA INFOTECH & DIGITAL SOLUTIONS'));
      expect(p1Text, contains('Integrator)'));
      expect(p1Text, contains('year period'));
      expect(p1Text, contains('Pay the amount as per the payment schedule'));
      expect(p1Text, contains('Page 1 of 3'));

      // Page 2 assertions (All 18 clauses)
      final p2Text = extractor.extractText(startPageIndex: 1, endPageIndex: 1);
      expect(p2Text, contains('The Second Party hereby undertakes to perform the following activities:'));
      expect(p2Text, contains('Standards & Scheme Compliance'));
      expect(p2Text, contains('Project completion report (PCR)'));
      expect(p2Text, contains('national portal'));
      expect(p2Text, contains('Insurance'));
      expect(p2Text, contains('scope of the vendor'));
      expect(p2Text, contains('Performance of Plant'));
      expect(p2Text, contains('5 years from the date of commissioning'));
      expect(p2Text, contains('Page 2 of 3'));

      // Page 3 assertions (Payment Table, Signatures, Stamp, Disclaimer)
      final p3Text = extractor.extractText(startPageIndex: 2, endPageIndex: 2);
      expect(p3Text, contains('19. Mutually Agreed Terms of Payment'));
      expect(p3Text, contains('Solar Capacity'));
      expect(p3Text, contains('Rs. 1,60,000.00'));
      expect(p3Text, contains('Rs. 78,000.00'));
      expect(p3Text, contains('Rs. 82,000.00'));
      expect(p3Text, contains('Advance with Work Order'));
      expect(p3Text, contains('First Party (Consumer)'));
      expect(p3Text, contains('Signature of First Party (Consumer)'));
      expect(p3Text, contains('Second Party (Vendor)'));
      expect(p3Text, contains('Authorized Signatory'));
      expect(p3Text, contains('Disclaimer'));
      expect(p3Text, contains('Page 3 of 3'));

      loadedDoc.dispose();
    });
  });
}
