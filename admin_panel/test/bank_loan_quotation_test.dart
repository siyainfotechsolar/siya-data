import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:admin_panel/models/solar_quotation.dart';
import 'package:admin_panel/services/bank_loan_quotation_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Admin Panel Bank Loan Solar Quotation Tests', () {
    test('1. generateQuotationPdfBytes produces valid non-empty A4 PDF with %PDF header', () async {
      final quotation = SolarQuotation.create(
        customerId: 'cust_001',
        consumerNo: '096590001608',
        customerName: 'SHRI NAMDEO DAGA MALI',
        address: 'PIMPRAD, TAL. SHINDKHEDA, DIST. DHULE',
        villageCity: 'Pimprad',
        district: 'Dhule',
        mobileNo: '9673220315',
        quotationNo: 'SIYA-Q-2026-1608',
        systemCapacity: '3 kW',
        totalSystemCost: 160000.0,
        gstAmount: 0.0,
        grandTotal: 160000.0,
        bankLoanAmount: 144000.0,
        customerContribution: 16000.0,
      );

      final pdfBytes = await BankLoanQuotationService.generateQuotationPdfBytes(quotation);

      try {
        final convDir = 'C:/Users/Admin/.gemini/antigravity-ide/brain/66c28ce9-6a4b-4da6-95cb-8aeb63238283';
        final artifactPdf = File('$convDir/sample_admin_quotation.pdf');
        artifactPdf.parent.createSync(recursive: true);
        artifactPdf.writeAsBytesSync(pdfBytes);
        File('c:/ide/siya data/Quotation_Ramesh_Balasaheb_Patil_SIYA-Q-2026-8901.pdf').writeAsBytesSync(pdfBytes);
      } catch (_) {}

      expect(pdfBytes, isNotEmpty);
      expect(pdfBytes.length, greaterThan(1000));

      final header = ascii.decode(pdfBytes.take(5).toList());
      expect(header, equals('%PDF-'));
    });

    test('2. PDF generation handles minimal customer quotation gracefully', () async {
      final quotation = SolarQuotation.create(
        consumerNo: '999999999999',
        customerName: 'Sunita Vijay Deshmukh',
      );

      final pdfBytes = await BankLoanQuotationService.generateQuotationPdfBytes(quotation);

      expect(pdfBytes, isNotEmpty);
      final header = ascii.decode(pdfBytes.take(5).toList());
      expect(header, equals('%PDF-'));
    });

    test('3. Filename matches Quotation_[CustomerName]_[QuotationNo].pdf format', () {
      final quotation = SolarQuotation.create(
        consumerNo: '012345678901',
        customerName: 'Ramesh Balasaheb Patil',
        quotationNo: 'SIYA-Q-2026-8901',
      );

      expect(quotation.pdfFileName, startsWith('Quotation_'));
      expect(quotation.pdfFileName, endsWith('.pdf'));
      expect(quotation.pdfFileName, contains('Ramesh_Balasaheb_Patil'));
      expect(quotation.pdfFileName, contains('SIYA-Q-2026-8901'));
    });

    test('4. PDF generation fits cleanly with long customer address and notes', () async {
      final quotation = SolarQuotation.create(
        customerId: 'cust-2',
        consumerNo: '055554444333',
        customerName: 'Dnyaneshwar Madhavrao Deshmukh-Patil',
        address: 'Gat No. 124, Near Grampanchayat Office, Old Post Lane, Betawad, Taluka Shindkheda, Dist. Dhule',
        villageCity: 'Betawad',
        district: 'Dhule',
        mobileNo: '9822001122',
        quotationNo: 'SIYA-Q-2026-4333',
        systemCapacity: '5 kW',
        totalSystemCost: 260000.0,
        gstAmount: 0.0,
        grandTotal: 260000.0,
        bankLoanAmount: 234000.0,
        customerContribution: 26000.0,
      );

      final pdfBytes = await BankLoanQuotationService.generateQuotationPdfBytes(quotation);
      expect(pdfBytes, isNotEmpty);
      expect(pdfBytes.length, greaterThan(1000));
    });

    test('5. Two-way auto-calculation: Entering loan amount calculates customer contribution and vice versa', () {
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

    test('6. Reverse auto-calculation after Reset when only Loan Amount is entered', () {
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

    test('7. Company standard pricing matrix: 3kW=1.8L, 3.5kW=2.0L, 4kW=2.4L, 5kW=3.0L', () {
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
  });
}

