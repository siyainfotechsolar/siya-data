import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/models/consumer_record.dart';
import 'package:mobile_app/services/work_completion_certificate_service.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Work Completion Certificate Tests', () {
    final testCustomer = ConsumerRecord(
      id: 'cust_001',
      consumerNo: '096590001608',
      name: 'SHRI NAMDEO DAGA MALI',
      address: 'PIMPRAD, TAL. SHINDKHEDA',
      mobile: '9673220315',
      installationStatus: 'Installation Completed',
      installationDate: DateTime(2026, 8, 15),
      remarks: '3 kW Solar Rooftop System installed successfully',
    );

    test('1. Generates single-page A4 PDF with valid magic header', () async {
      final file = await WorkCompletionCertificateService.generateCertificatePdf(
        customer: testCustomer,
      );

      expect(file, isNotNull);
      expect(file.existsSync(), isTrue);

      final bytes = await file.readAsBytes();
      expect(bytes.length, greaterThan(1000));

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

    test('2. Output filename matches Work_Completion_Certificate_[CustomerName].pdf format', () async {
      final file = await WorkCompletionCertificateService.generateCertificatePdf(
        customer: testCustomer,
      );

      final filename = file.uri.pathSegments.last;
      expect(filename, startsWith('Work_Completion_Certificate_'));
      expect(filename, endsWith('.pdf'));
      expect(filename, contains('SHRI_NAMDEO_DAGA_MALI'));
    });

    test('3. Handles missing optional fields gracefully without failure', () async {
      final minimalCustomer = ConsumerRecord(
        consumerNo: '096570003931',
        name: 'MOHAMMAD SADIQUE PATEL',
        // No address, no installation date, no capacity
      );

      final file = await WorkCompletionCertificateService.generateCertificatePdf(
        customer: minimalCustomer,
      );

      expect(file.existsSync(), isTrue);
      final bytes = await file.readAsBytes();
      final loadedDoc = PdfDocument(inputBytes: bytes);
      expect(loadedDoc.pages.count, equals(1));
      loadedDoc.dispose();
    });
  });
}
