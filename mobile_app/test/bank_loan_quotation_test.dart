import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/models/consumer_record.dart';
import 'package:mobile_app/models/solar_quotation.dart';
import 'package:mobile_app/services/bank_loan_quotation_service.dart';
import 'package:mobile_app/utils/number_to_words_utils.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Number To Words Utility Tests', () {
    test('Converts standard amounts to Indian currency words', () {
      expect(
        NumberToWordsUtils.convertToIndianRupees(160000),
        equals('Rupees One Lakh Sixty Thousand Only'),
      );
      expect(
        NumberToWordsUtils.convertToIndianRupees(185000),
        equals('Rupees One Lakh Eighty Five Thousand Only'),
      );
      expect(
        NumberToWordsUtils.convertToIndianRupees(225500),
        equals('Rupees Two Lakh Twenty Five Thousand Five Hundred Only'),
      );
      expect(
        NumberToWordsUtils.convertToIndianRupees(0),
        equals('Rupees Zero Only'),
      );
    });
  });

  group('Bank Loan Solar Quotation PDF Tests', () {
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

    test('1. Generates single-page A4 PDF with valid magic header', () async {
      final quotation = SolarQuotation.create(
        customerId: testCustomer.id,
        consumerNo: testCustomer.consumerNo,
        customerName: testCustomer.name,
        address: testCustomer.address,
        villageCity: 'Pimprad',
        district: 'Dhule',
        mobileNo: testCustomer.mobile ?? '',
        quotationNo: 'SIYA-Q-2026-1608',
        systemCapacity: '3 kW',
        totalSystemCost: 160000.0,
        gstAmount: 0.0,
        grandTotal: 160000.0,
        bankLoanAmount: 144000.0,
        customerContribution: 16000.0,
      );

      final file = await BankLoanQuotationService.generateQuotationPdf(
        quotation: quotation,
      );

      expect(file, isNotNull);
      expect(file.existsSync(), isTrue);

      final bytes = await file.readAsBytes();
      expect(bytes.length, greaterThan(1000));

      try {
        final artifactPdf = File('C:/Users/Admin/.gemini/antigravity-ide/brain/c38e8e61-ed05-4303-8f0f-7f86ce402cb7/sample_quotation.pdf');
        artifactPdf.parent.createSync(recursive: true);
        artifactPdf.writeAsBytesSync(bytes);
        File('c:/ide/siya data/Quotation_NAMDEO_MALI_SIYA-Q-2026-1608.pdf').writeAsBytesSync(bytes);
      } catch (_) {}

      // PDF Magic Header: %PDF
      final magicHeader = String.fromCharCodes(bytes.take(4));
      expect(magicHeader, equals('%PDF'));

      // Verify single page A4
      final loadedDoc = PdfDocument(inputBytes: bytes);
      expect(loadedDoc.pages.count, equals(1));
      final size = loadedDoc.pages[0].size;
      // A4 portrait dimensions: ~595 x 842 points
      expect(size.width, closeTo(595.28, 1.0));
      expect(size.height, closeTo(841.89, 1.0));
      loadedDoc.dispose();
    });

    test('2. Output filename matches Quotation_[CustomerName]_[QuotationNo].pdf format', () async {
      final quotation = SolarQuotation.create(
        customerId: testCustomer.id,
        consumerNo: testCustomer.consumerNo,
        customerName: testCustomer.name,
        address: testCustomer.address,
        quotationNo: 'SIYA-Q-2026-1608',
      );

      final file = await BankLoanQuotationService.generateQuotationPdf(
        quotation: quotation,
      );

      final filename = file.uri.pathSegments.last;
      expect(filename, startsWith('Quotation_'));
      expect(filename, endsWith('.pdf'));
      expect(filename, contains('SHRI_NAMDEO_DAGA_MALI'));
      expect(filename, contains('SIYA-Q-2026-1608'));
    });

    test('3. Handles missing optional fields gracefully without failure', () async {
      final quotation = SolarQuotation.create(
        consumerNo: '096570003931',
        customerName: 'MOHAMMAD SADIQUE PATEL',
        // Minimal fields
      );

      final file = await BankLoanQuotationService.generateQuotationPdf(
        quotation: quotation,
      );

      expect(file.existsSync(), isTrue);
      final bytes = await file.readAsBytes();
      final loadedDoc = PdfDocument(inputBytes: bytes);
      expect(loadedDoc.pages.count, equals(1));
      loadedDoc.dispose();
    });
  });
}
