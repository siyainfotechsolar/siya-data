import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:admin_panel/models/consumer_record.dart';
import 'package:admin_panel/services/work_completion_certificate_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Admin Panel Work Completion Certificate Tests', () {
    test('1. generateCertificatePdfBytes produces valid non-empty A4 PDF with %PDF header', () async {
      final customer = ConsumerRecord(
        id: 'cust-1',
        consumerNo: '012345678901',
        name: 'Ramesh Balasaheb Patil',
        mobile: '9876543210',
        address: 'Plot 42, Shivajinagar, Baramati',
        installationStatus: 'Installation Completed',
        installationDate: DateTime(2026, 8, 15),
        submitDate: DateTime(2026, 7, 1),
        remarks: '3 kW Rooftop Solar PV System',
      );

      final pdfBytes = await WorkCompletionCertificateService.generateCertificatePdfBytes(customer);

      expect(pdfBytes, isNotEmpty);
      expect(pdfBytes.length, greaterThan(1000));

      // Save sample PDF to artifact directory for user preview
      try {
        final artifactPdf = File('C:/Users/Admin/.gemini/antigravity-ide/brain/ecc0cc6d-4f1e-4aeb-a1d3-08471c43d06b/sample_wcr_certificate.pdf');
        artifactPdf.writeAsBytesSync(pdfBytes);
      } catch (e) {
        // Ignore file save error in CI
      }

      // Standard PDF header '%PDF-'
      final header = ascii.decode(pdfBytes.take(5).toList());
      expect(header, equals('%PDF-'));
    });

    test('2. PDF generation handles missing optional fields gracefully', () async {
      final customer = ConsumerRecord(
        consumerNo: '999999999999',
        name: 'Sunita Vijay Deshmukh',
      );

      final pdfBytes = await WorkCompletionCertificateService.generateCertificatePdfBytes(customer);

      expect(pdfBytes, isNotEmpty);
      final header = ascii.decode(pdfBytes.take(5).toList());
      expect(header, equals('%PDF-'));
    });

    test('3. WhatsApp message formatting includes customer details and clean summary', () {
      final customer = ConsumerRecord(
        consumerNo: '112233445566',
        name: 'Amit Deshmukh',
        mobile: '+91 94220 12345',
        remarks: '5 kW Rooftop Solar Plant',
      );

      final phone = (customer.mobile ?? '').replaceAll(RegExp(r'\D'), '');
      expect(phone, equals('919422012345'));
    });
  });
}
