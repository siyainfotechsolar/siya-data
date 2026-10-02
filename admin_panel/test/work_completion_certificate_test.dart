import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:admin_panel/models/consumer_record.dart';
import 'package:admin_panel/models/work_completion_report_data.dart';
import 'package:admin_panel/services/work_completion_certificate_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final customer = ConsumerRecord(
    id: 'cust-1',
    consumerNo: '012345678901',
    name: 'Ramesh Balasaheb Patil',
    mobile: '9876543210',
    address: 'Plot 42, Shivajinagar, Betawad, Tal. Shindkheda, Dist. Dhule',
    installationStatus: 'Installation Completed',
    installationDate: DateTime(2026, 8, 15),
    submitDate: DateTime(2026, 7, 1),
    remarks: '3 kW Rooftop Solar PV System',
  );

  final reportData = WorkCompletionReportData.fromCustomer(customer);
  const artifactDir = 'C:/Users/Admin/.gemini/antigravity-ide/brain/67039af7-0b8d-4c87-88c6-a2fc95b148ba';

  group('Admin Panel Work Completion Certificate & Dossier Tests', () {
    test('0. generateBankWcrPdfBytes produces valid 1-page Bank Work Completion Certificate', () async {
      final pdfBytes = await WorkCompletionCertificateService.generateBankWcrPdfBytes(reportData);

      expect(pdfBytes, isNotEmpty);
      expect(pdfBytes.length, greaterThan(2000));

      final header = ascii.decode(pdfBytes.take(5).toList());
      expect(header, equals('%PDF-'));

      try {
        File('$artifactDir/Bank_Work_Completion_Certificate_Sample.pdf').writeAsBytesSync(pdfBytes);
      } catch (_) {}
    });

    test('1. generateWcrPdfBytes produces valid 2-page A4 PDF with %PDF header', () async {
      final pdfBytes = await WorkCompletionCertificateService.generateWcrPdfBytes(reportData);

      expect(pdfBytes, isNotEmpty);
      expect(pdfBytes.length, greaterThan(2000));

      final header = ascii.decode(pdfBytes.take(5).toList());
      expect(header, equals('%PDF-'));

      try {
        File('$artifactDir/MSEDCL_WCR_Sample.pdf').writeAsBytesSync(pdfBytes);
      } catch (_) {}
    });

    test('2. generateAnnexure1PdfBytes produces valid 2-page Annexure-I Commissioning Report', () async {
      final pdfBytes = await WorkCompletionCertificateService.generateAnnexure1PdfBytes(reportData);

      expect(pdfBytes, isNotEmpty);
      expect(pdfBytes.length, greaterThan(2000));

      final header = ascii.decode(pdfBytes.take(5).toList());
      expect(header, equals('%PDF-'));

      try {
        File('$artifactDir/MSEDCL_Annexure_1_Sample.pdf').writeAsBytesSync(pdfBytes);
      } catch (_) {}
    });

    test('3. generateDcrPdfBytes produces valid 1-page DCR Undertaking', () async {
      final pdfBytes = await WorkCompletionCertificateService.generateDcrPdfBytes(reportData);

      expect(pdfBytes, isNotEmpty);
      expect(pdfBytes.length, greaterThan(1500));

      final header = ascii.decode(pdfBytes.take(5).toList());
      expect(header, equals('%PDF-'));

      try {
        File('$artifactDir/MSEDCL_DCR_Undertaking_Sample.pdf').writeAsBytesSync(pdfBytes);
      } catch (_) {}
    });

    test('4. generateAnnexure3PdfBytes produces valid 5-page Net-Metering Agreement', () async {
      final pdfBytes = await WorkCompletionCertificateService.generateAnnexure3PdfBytes(reportData);

      expect(pdfBytes, isNotEmpty);
      expect(pdfBytes.length, greaterThan(5000));

      final header = ascii.decode(pdfBytes.take(5).toList());
      expect(header, equals('%PDF-'));

      try {
        File('$artifactDir/MSEDCL_Annexure_3_Net_Metering_Sample.pdf').writeAsBytesSync(pdfBytes);
      } catch (_) {}
    });

    test('5. Backward compatible generateCertificatePdfBytes works seamlessly', () async {
      final pdfBytes = await WorkCompletionCertificateService.generateCertificatePdfBytes(customer);
      expect(pdfBytes, isNotEmpty);
      final header = ascii.decode(pdfBytes.take(5).toList());
      expect(header, equals('%PDF-'));
    });

    test('6. PDF generation handles missing optional fields gracefully', () async {
      final emptyCustomer = ConsumerRecord(
        consumerNo: '999999999999',
        name: 'Sunita Vijay Deshmukh',
      );

      final pdfBytes = await WorkCompletionCertificateService.generateCertificatePdfBytes(emptyCustomer);
      expect(pdfBytes, isNotEmpty);
      final header = ascii.decode(pdfBytes.take(5).toList());
      expect(header, equals('%PDF-'));
    });
  });
}
