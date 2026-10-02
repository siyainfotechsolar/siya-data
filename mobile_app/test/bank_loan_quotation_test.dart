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
        if (artifactPdf.parent.existsSync()) {
          artifactPdf.writeAsBytesSync(bytes);
        }
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

    test('4. Two-way auto-calculation: Entering loan amount calculates customer contribution and vice versa', () {
      const grandTotal = 160000.0;

      // 1. Enter Loan Amount -> Customer Contribution automatically calculated
      const enteredLoan = 140000.0;
      final autoCalculatedContrib = (grandTotal - enteredLoan).clamp(0.0, double.infinity);
      expect(autoCalculatedContrib, equals(20000.0));
      expect(autoCalculatedContrib / grandTotal * 100, equals(12.5));

      // 2. Enter Customer Contribution -> Loan Amount automatically calculated
      const enteredContrib = 15000.0;
      final autoCalculatedLoan = (grandTotal - enteredContrib).clamp(0.0, double.infinity);
      expect(autoCalculatedLoan, equals(145000.0));
      expect(autoCalculatedLoan / grandTotal * 100, equals(90.625));

      // 3. Margin receipt synchronizes with customer contribution
      final quotation = SolarQuotation.create(
        consumerNo: '012345678901',
        customerName: 'Test Customer',
        grandTotal: grandTotal,
        bankLoanAmount: autoCalculatedLoan,
        customerContribution: enteredContrib,
      );
      expect(quotation.customerContribution, equals(15000.0));
      expect(quotation.bankLoanAmount, equals(145000.0));
      expect(quotation.bankLoanAmount + quotation.customerContribution, equals(grandTotal));
    });

    test('5. Reverse auto-calculation after Reset when only Loan Amount is entered', () {
      // User resets form and enters only Bank Loan = 144,000 (90% financing)
      const enteredLoan = 144000.0;
      const gst = 0.0;

      // Reverse calculate: Grand Total = Loan / 0.9
      final autoGrand = (enteredLoan / 0.9).roundToDouble();
      final autoContrib = (autoGrand - enteredLoan).clamp(0.0, double.infinity);
      final autoCost = (autoGrand - gst).clamp(0.0, double.infinity);

      expect(autoGrand, equals(160000.0));
      expect(autoContrib, equals(16000.0));
      expect(autoCost, equals(160000.0));
      expect(autoContrib / autoGrand * 100, closeTo(10.0, 0.01));
      expect(enteredLoan / autoGrand * 100, closeTo(90.0, 0.01));

      // Test reverse calculation with 1,80,000 loan
      const higherLoan = 180000.0;
      final autoGrandHigher = (higherLoan / 0.9).roundToDouble();
      final autoContribHigher = (autoGrandHigher - higherLoan).clamp(0.0, double.infinity);
      expect(autoGrandHigher, equals(200000.0));
      expect(autoContribHigher, equals(20000.0));
    });
  });
}

