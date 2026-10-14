import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:admin_panel/models/invoice.dart';
import 'package:admin_panel/models/solar_quotation.dart';
import 'package:admin_panel/services/invoice_pdf_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Generate Sample Invoice PDF matching Quotation styling', () async {
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
      totalSystemCost: 184180.79,
      gstAmount: 15819.21,
      grandTotal: 218000.0,
      bankLoanAmount: 196200.0,
      customerContribution: 21800.0,
    );

    final invoice = Invoice.fromQuotation(
      quotation: quotation,
      invoiceNumber: 'SID000321',
    );

    final pdfBytes = await InvoicePdfService.generateInvoicePdfBytes(
      invoice,
      includeStampAndSignature: true,
    );

    expect(pdfBytes, isNotEmpty);
    expect(pdfBytes.length, greaterThan(1000));

    // Save to conversation artifact directory and root directory
    final convDir = 'C:/Users/Admin/.gemini/antigravity-ide/brain/7d22e6db-58aa-4db1-b36d-ab40dab7e67a';
    final artifactFile = File('$convDir/sample_invoice.pdf');
    artifactFile.parent.createSync(recursive: true);
    artifactFile.writeAsBytesSync(pdfBytes);

    final rootFile = File('c:/ide/siya data/sample_invoice.pdf');
    rootFile.writeAsBytesSync(pdfBytes);

    print('Successfully generated sample invoice PDF: ${artifactFile.path} (${pdfBytes.length} bytes)');
  });
}
