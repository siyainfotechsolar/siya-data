import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:admin_panel/models/consumer_vendor_agreement.dart';
import 'package:admin_panel/models/work_completion_report_data.dart';
import 'package:admin_panel/services/agreement_storage_service.dart';
import 'package:admin_panel/services/customer_signature_helper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Universal Customer Data Sync & Cross-Module Synchronization Tests', () {
    test('1. WorkCompletionReportData full serialization round-trip', () {
      final original = WorkCompletionReportData(
        customerName: 'Sanjay Patil',
        consumerNo: '012345678901',
        customerAddress: 'Betawad, Dhule',
        customerMobile: '9876543210',
        sanctionNo: 'SAN-012345678901',
        applicationNo: 'APP-9988',
        applicationDate: DateTime(2026, 3, 15),
        completionDate: DateTime(2026, 4, 10),
        sanctionedCapacityKw: 4.5,
        installedCapacityKw: 4.5,
        moduleMake: 'Waaree Energies Ltd',
        moduleAlmmModel: 'WST-540-ALMM',
        moduleWattage: 540,
        moduleCount: 8,
        moduleTotalCapacityKwp: 4.32,
        moduleWarranty: '12 Years Product + 25 Years Performance',
        moduleSerialNos: 'WST-001, WST-002, WST-003, WST-004',
        cellManufacturer: 'Premier Energies Ltd',
        cellGstInvoiceNo: 'PE/INV/2026/1029',
        inverterMake: 'Growatt New Energy',
        inverterModel: 'MIN 6000TL-X',
        inverterRating: '4.5 kW, 1-Phase 230V, 50Hz',
        inverterControllerType: 'Dual MPPT / String Inverter',
        inverterCapacityKw: 4.5,
        inverterHpd: 'Yes',
        inverterMfgYear: 2026,
        earthResistanceDetails: '3 Earthings (AC, DC, LA) < 5 Ohms',
        earthResistanceCertified: 'Certified & Found in order',
        lightningArrester: 'Installed with copper rod',
        vendorFirmName: 'SIYA INFOTECH & DIGITAL SOLUTIONS',
        vendorGstin: '27CVTPK6358P1ZD',
        vendorAddress: '21, Mudavad Road, Betawad',
        vendorMobile: '7972143798',
        vendorEmail: 'siyainfodigital@gmail.com',
        authorizedPerson: 'Authorized Signatory',
        discomName: 'MSEDCL',
        consumerAadhar: '1234-5678-9012',
      );

      final json = original.toJson();
      expect(json, isA<Map<String, dynamic>>());
      expect(json['consumer_no'], equals('012345678901'));
      expect(json['module_serial_nos'], equals('WST-001, WST-002, WST-003, WST-004'));
      expect(json['installed_capacity_kw'], equals(4.5));

      final restored = WorkCompletionReportData.fromJson(json);
      expect(restored.customerName, equals(original.customerName));
      expect(restored.consumerNo, equals(original.consumerNo));
      expect(restored.installedCapacityKw, equals(original.installedCapacityKw));
      expect(restored.moduleSerialNos, equals(original.moduleSerialNos));
      expect(restored.inverterModel, equals(original.inverterModel));
      expect(restored.sanctionNo, equals(original.sanctionNo));
      expect(restored.consumerAadhar, equals(original.consumerAadhar));
    });

    test('2. AgreementStorageService saves and retrieves agreements with deduplication', () async {
      const consumerNo = '012345678901';
      final agreement1 = ConsumerVendorAgreement.create(
        consumerNo: consumerNo,
        customerName: 'Kailas Mali',
        address: 'Betawad',
        mobileNo: '9822000000',
        systemCapacity: '3 kW',
        totalProjectCost: 200000,
        cfaSubsidyAmount: 78000,
        netCustomerPayable: 122000,
      );

      await AgreementStorageService.saveAgreement(agreement1);

      final list1 = await AgreementStorageService.getAgreementsForCustomer(consumerNo);
      expect(list1.length, equals(1));
      expect(list1.first.agreementNo, equals(agreement1.agreementNo));
      expect(list1.first.customerName, equals('Kailas Mali'));

      // Save updated version of same agreement
      final updatedAgreement = agreement1.copyWith(
        customerName: 'Kailas Vitthal Mali',
        totalProjectCost: 210000,
      );
      await AgreementStorageService.saveAgreement(updatedAgreement);

      final list2 = await AgreementStorageService.getAgreementsForCustomer(consumerNo);
      // Must not create duplicate entry
      expect(list2.length, equals(1));
      expect(list2.first.customerName, equals('Kailas Vitthal Mali'));
      expect(list2.first.totalProjectCost, equals(210000));
    });

    test('3. AgreementStorageService deletes agreements correctly', () async {
      const consumerNo = '012345678902';
      final agreement = ConsumerVendorAgreement.create(
        consumerNo: consumerNo,
        customerName: 'Ramesh Patil',
      );

      await AgreementStorageService.saveAgreement(agreement);
      final beforeDelete = await AgreementStorageService.getAgreementsForCustomer(consumerNo);
      expect(beforeDelete.length, equals(1));

      await AgreementStorageService.deleteAgreement(consumerNo, agreement.id);
      final afterDelete = await AgreementStorageService.getAgreementsForCustomer(consumerNo);
      expect(afterDelete.isEmpty, isTrue);
    });

    test('4. CustomerSignatureHelper loads signature from local storage into memory cache', () async {
      const consumerNo = '012345678999';
      final dummyBytes = Uint8List.fromList([137, 80, 78, 71, 13, 10, 26, 10, 0, 0, 0, 13]);

      CustomerSignatureHelper.clearCustomerSignature(consumerNo);
      expect(CustomerSignatureHelper.hasCustomerSignature(consumerNo), isFalse);

      // Save signature
      CustomerSignatureHelper.setCustomerSignature(consumerNo, dummyBytes);
      expect(CustomerSignatureHelper.hasCustomerSignature(consumerNo), isTrue);

      // Verify ensureCustomerSignatureLoaded succeeds
      final loaded = await CustomerSignatureHelper.ensureCustomerSignatureLoaded(consumerNo);
      expect(loaded, isTrue);
      expect(CustomerSignatureHelper.getCustomerSignature(consumerNo), isNotNull);

      CustomerSignatureHelper.clearCustomerSignature(consumerNo);
      expect(CustomerSignatureHelper.hasCustomerSignature(consumerNo), isFalse);
    });
  });
}
