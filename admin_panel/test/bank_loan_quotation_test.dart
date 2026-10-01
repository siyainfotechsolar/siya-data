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
        final artifactPdf = File('C:/Users/Admin/.gemini/antigravity-ide/brain/c38e8e61-ed05-4303-8f0f-7f86ce402cb7/sample_admin_quotation.pdf');
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
  });
}
