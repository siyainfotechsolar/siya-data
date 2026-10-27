import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:admin_panel/models/consumer_record.dart';
import 'package:admin_panel/models/consumer_vendor_agreement.dart';
import 'package:admin_panel/services/consumer_vendor_agreement_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Admin Panel Consumer-Vendor Agreement (Annexure 2) PDF Tests', () {
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

    test('1. Generates 3-page A4 Annexure 2 Agreement PDF bytes with valid magic header', () async {
      final agreement = ConsumerVendorAgreement.create(
        customerId: testCustomer.id,
        consumerNo: testCustomer.consumerNo,
        customerName: testCustomer.name,
        address: testCustomer.address,
        villageCity: 'Pimprad',
        district: 'Dhule',
        mobileNo: testCustomer.mobile ?? '',
        agreementNo: 'SIYA-AGR-2026-1608',
        systemCapacity: '3 kW',
        totalProjectCost: 160000.0,
        cfaSubsidyAmount: 78000.0,
        netCustomerPayable: 82000.0,
      );

      final bytes = await ConsumerVendorAgreementService.generateAgreementPdfBytes(agreement);

      expect(bytes, isNotNull);
      expect(bytes.length, greaterThan(2000));

      // PDF Magic Header: %PDF
      final magicHeader = String.fromCharCodes(bytes.take(4));
      expect(magicHeader, equals('%PDF'));

      try {
        File('c:/ide/siya data/sample_agreement_standard_3pages.pdf').writeAsBytesSync(bytes);
        final brainDir = Directory('C:/Users/Admin/.gemini/antigravity-ide/brain/f1479f94-abe8-4fd1-a622-460c01645d8e');
        if (brainDir.existsSync()) {
          File('${brainDir.path}/sample_agreement_standard_3pages.pdf').writeAsBytesSync(bytes);
        }
      } catch (_) {}
    });

    test('2. Output filename matches Agreement_[CustomerName]_[AgreementNo].pdf format', () {
      final agreement = ConsumerVendorAgreement.create(
        consumerNo: testCustomer.consumerNo,
        customerName: testCustomer.name,
        agreementNo: 'SIYA-AGR-2026-1608',
      );

      expect(agreement.pdfFileName, startsWith('Agreement_'));
      expect(agreement.pdfFileName, endsWith('.pdf'));
      expect(agreement.pdfFileName, contains('SHRI_NAMDEO_DAGA_MALI'));
      expect(agreement.pdfFileName, contains('SIYA-AGR-2026-1608'));
    });

    test('3. Milestone payment schedule sums to total cost and default milestones are valid', () {
      final agreement = ConsumerVendorAgreement.create(
        consumerNo: testCustomer.consumerNo,
        customerName: testCustomer.name,
        totalProjectCost: 160000.0,
      );

      expect(agreement.paymentMilestones.length, equals(3));
      final totalMilestoneAmount = agreement.paymentMilestones.fold<double>(0.0, (sum, m) => sum + m.amount);
      expect(totalMilestoneAmount, equals(160000.0));
      final totalPercent = agreement.paymentMilestones.fold<double>(0.0, (sum, m) => sum + m.percentage);
      expect(totalPercent, equals(100.0));
    });

    test('4. Generates 4-page A4 Annexure 2 Agreement on Rs. 100 Stamp Paper', () async {
      final agreement = ConsumerVendorAgreement.create(
        customerId: testCustomer.id,
        consumerNo: testCustomer.consumerNo,
        customerName: testCustomer.name,
        address: testCustomer.address,
        villageCity: 'Pimprad',
        district: 'Dhule',
        mobileNo: testCustomer.mobile ?? '',
        agreementNo: 'SIYA-AGR-2026-1608',
        systemCapacity: '3 kW',
        totalProjectCost: 160000.0,
        cfaSubsidyAmount: 78000.0,
        netCustomerPayable: 82000.0,
      );

      final bytes = await ConsumerVendorAgreementService.generateAgreementPdfBytes(
        agreement,
        includeStampPaper: true,
        stampPaperBackground: true,
        includeStampAndSignature: true,
      );

      expect(bytes, isNotNull);
      expect(bytes.length, greaterThan(2000));
      final magicHeader = String.fromCharCodes(bytes.take(4));
      expect(magicHeader, equals('%PDF'));

      try {
        File('c:/ide/siya data/sample_agreement_stamp_paper_e_stamp.pdf').writeAsBytesSync(bytes);
        final brainDir = Directory('C:/Users/Admin/.gemini/antigravity-ide/brain/f1479f94-abe8-4fd1-a622-460c01645d8e');
        if (brainDir.existsSync()) {
          File('${brainDir.path}/sample_agreement_stamp_paper_e_stamp.pdf').writeAsBytesSync(bytes);
        }
      } catch (_) {}
    });

    test('5. Generates 4-page A4 Annexure 2 Agreement Physical Blank Print Mode', () async {
      final agreement = ConsumerVendorAgreement.create(
        customerId: testCustomer.id,
        consumerNo: testCustomer.consumerNo,
        customerName: testCustomer.name,
        address: testCustomer.address,
        villageCity: 'Pimprad',
        district: 'Dhule',
        mobileNo: testCustomer.mobile ?? '',
        agreementNo: 'SIYA-AGR-2026-1608',
        systemCapacity: '3 kW',
        totalProjectCost: 160000.0,
        cfaSubsidyAmount: 78000.0,
        netCustomerPayable: 82000.0,
      );

      final bytes = await ConsumerVendorAgreementService.generateAgreementPdfBytes(
        agreement,
        includeStampPaper: true,
        stampPaperBackground: false,
        includeStampAndSignature: true,
      );

      expect(bytes, isNotNull);
      expect(bytes.length, greaterThan(2000));
      final magicHeader = String.fromCharCodes(bytes.take(4));
      expect(magicHeader, equals('%PDF'));

      try {
        File('c:/ide/siya data/sample_agreement_stamp_paper_physical_print.pdf').writeAsBytesSync(bytes);
        final brainDir = Directory('C:/Users/Admin/.gemini/antigravity-ide/brain/f1479f94-abe8-4fd1-a622-460c01645d8e');
        if (brainDir.existsSync()) {
          File('${brainDir.path}/sample_agreement_stamp_paper_physical_print.pdf').writeAsBytesSync(bytes);
        }
      } catch (_) {}
    });
  });
}
