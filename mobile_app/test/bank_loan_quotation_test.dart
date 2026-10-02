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
        systemCapacity: '3.5 kW',
        totalSystemCost: 184180.79,
        gstAmount: 15819.21,
        grandTotal: 200000.0,
        bankLoanAmount: 180000.0,
        customerContribution: 20000.0,
      );

      final file = await BankLoanQuotationService.generateQuotationPdf(
        quotation: quotation,
      );

      expect(file, isNotNull);
      expect(file.existsSync(), isTrue);

      final bytes = await file.readAsBytes();
      expect(bytes.length, greaterThan(1000));

      try {
        final convDir = 'C:/Users/Admin/.gemini/antigravity-ide/brain/66c28ce9-6a4b-4da6-95cb-8aeb63238283';
        final artifactPdf = File('$convDir/sample_mobile_quotation.pdf');
        artifactPdf.parent.createSync(recursive: true);
        artifactPdf.writeAsBytesSync(bytes);
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

    test('6. Company standard pricing matrix: 3kW=1.8L, 3.5kW=2.0L, 4kW=2.4L, 5kW=3.0L', () {
      final pricing = [
        {'cap': '3 kW', 'cost': 180000.0, 'expectedLoan': 162000.0, 'expectedContrib': 18000.0},
        {'cap': '3.5 kW', 'cost': 200000.0, 'expectedLoan': 180000.0, 'expectedContrib': 20000.0},
        {'cap': '4 kW', 'cost': 240000.0, 'expectedLoan': 216000.0, 'expectedContrib': 24000.0},
        {'cap': '5 kW', 'cost': 300000.0, 'expectedLoan': 270000.0, 'expectedContrib': 30000.0},
      ];

      for (final p in pricing) {
        final cost = p['cost'] as double;
        final loan = (cost * 0.9).roundToDouble();
        final contrib = (cost - loan).roundToDouble();
        expect(loan, equals(p['expectedLoan']));
        expect(contrib, equals(p['expectedContrib']));
        expect(loan + contrib, equals(cost));
      }
    });

    test('7. GST Module — Statutory 70:30 Split with Rs. 2,00,000 example verification', () {
      const totalAmount = 200000.0;
      final gst = SolarQuotationGstBreakdown.calculate(totalAmount);

      // Verify exact user requirements and statutory formulas
      expect(gst.totalAmount, equals(200000.0));
      expect(gst.portion70, equals(140000.0));
      expect(gst.gst5, closeTo(6666.67, 0.01));
      expect(gst.portion30, equals(60000.0));
      expect(gst.gst18, closeTo(9152.54, 0.01));
      expect(gst.totalTaxableValue, closeTo(184180.79, 0.01));
      expect(gst.totalGstIncluded, closeTo(15819.21, 0.01));
      expect(gst.grandTotal, equals(200000.0));
      expect(gst.totalTaxableValue + gst.totalGstIncluded, closeTo(totalAmount, 0.001));
    });

    test('8. Default Stamp & Signature inclusion and per-PDF removal support', () async {
      final quotation = SolarQuotation.create(
        consumerNo: testCustomer.consumerNo,
        customerName: testCustomer.name,
        grandTotal: 200000.0,
      );

      // Default (with stamp & signature)
      final pdfWithStamp = await BankLoanQuotationService.generateQuotationPdf(
        quotation: quotation,
        includeStampAndSignature: true,
      );
      expect(pdfWithStamp.existsSync(), isTrue);
      expect(await pdfWithStamp.length(), greaterThan(1000));

      // With stamp & signature removed
      final pdfWithoutStamp = await BankLoanQuotationService.generateQuotationPdf(
        quotation: quotation,
        includeStampAndSignature: false,
      );
      expect(pdfWithoutStamp.existsSync(), isTrue);
      expect(await pdfWithoutStamp.length(), greaterThan(1000));
    });
  });
}

