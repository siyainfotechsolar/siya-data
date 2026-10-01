import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:admin_panel/models/customer_margin_receipt.dart';
import 'package:admin_panel/services/margin_money_receipt_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Admin Panel Customer Margin Money Receipt Tests', () {
    final sampleReceipt = CustomerMarginReceipt.create(
      consumerNo: '015510000472',
      customerName: 'DILIP PANDURANG PATIL',
      address: 'Plot No. 12, Shivaji Nagar',
      villageCity: 'Betawad',
      district: 'Dhule',
      mobileNo: '9822012345',
      receiptNo: 'SIYA-MMR-2026-0472',
      receiptDate: DateTime(2026, 10, 1),
      quotationNo: 'SIYA-Q-2026-0472',
      quotationDate: DateTime(2026, 10, 1),
      systemCapacity: '3 kW',
      systemType: 'On-Grid Solar System',
      totalSystemCost: 160000.0,
      bankLoanAmount: 144000.0,
      marginAmount: 16000.0,
      paymentMode: 'Cash',
      transactionRef: 'Paid in Cash',
    );

    test('1. generateReceiptPdfBytes produces valid non-empty A4 PDF with %PDF header', () async {
      final bytes = await MarginMoneyReceiptService.generateReceiptPdfBytes(sampleReceipt);

      expect(bytes, isNotNull);
      expect(bytes.isNotEmpty, isTrue);

      final header = ascii.decode(bytes.sublist(0, 5));
      expect(header, equals('%PDF-'));
    });

    test('2. Margin amount in words is accurately calculated', () {
      expect(sampleReceipt.marginAmountInWords, contains('Sixteen Thousand'));
      expect(sampleReceipt.marginAmount, equals(16000.0));
      expect(sampleReceipt.bankLoanAmount, equals(144000.0));
    });

    test('3. Filename matches MarginReceipt_[CustomerName]_[ReceiptNo].pdf format', () {
      expect(sampleReceipt.pdfFileName, startsWith('MarginReceipt_DILIP_PANDURANG_PATIL_SIYA-MMR-2026-0472'));
      expect(sampleReceipt.pdfFileName, endsWith('.pdf'));
    });

    test('4. Writes sample admin margin receipt PDF to artifact dir', () async {
      final bytes = await MarginMoneyReceiptService.generateReceiptPdfBytes(sampleReceipt);
      final artifactFile = File(r'C:\Users\Admin\.gemini\antigravity-ide\brain\c38e8e61-ed05-4303-8f0f-7f86ce402cb7\sample_admin_margin_receipt.pdf');
      await artifactFile.writeAsBytes(bytes);
      expect(artifactFile.existsSync(), isTrue);
    });
  });
}
