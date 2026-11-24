import 'package:flutter_test/flutter_test.dart';
import 'package:admin_panel/models/msedcl_change_of_name.dart';
import 'package:admin_panel/services/msedcl_change_of_name_service.dart';
import 'package:admin_panel/services/msedcl_pdf_service.dart';
import 'package:admin_panel/services/msedcl_excel_service.dart';

void main() {
  group('SIYA INFOTECH – MSEDCL Change of Name & Document Generator Tests', () {
    setUp(() {
      MsedclChangeOfNameService.resetCacheForTesting();
    });

    test('1. Model JSON Serialization & Deserialization Integrity', () {
      final now = DateTime.now();
      final app = MsedclChangeOfNameApplication(
        id: 'test-001',
        applicationNo: 'MSEDCL-CN-202611-999',
        applicationDate: now,
        subDivisionOffice: 'Nardana Sub-Division',
        circleOffice: 'Dhule Circle',
        village: 'Nardana',
        reasonForChange: MsedclReasonForChange.purchaseOfProperty,
        assignedEmployee: 'Rahul',
        remarks: 'Registered Sale deed attached',
        status: MsedclApplicationStatus.newEntry,
        oldFirstName: 'AALIEM',
        oldFatherOrHusbandName: 'BABUMIYA',
        oldSurname: 'PATEL',
        oldConsumerFullName: 'AALIEM BABUMIYA PATEL',
        consumerNo: '096570003663',
        oldMobileNo: '9822334455',
        oldMeterNo: 'MTR-12345',
        newFirstName: 'RAJU',
        newFatherOrHusbandName: 'VASANT',
        newSurname: 'CHAUDHARI',
        newConsumerFullName: 'RAJU VASANT CHAUDHARI',
        newAge: 42,
        newMobileNo: '9423187654',
        newPhoneNo: '02562-234567',
        newEmail: 'raju@gmail.com',
        newAadhaarNo: '4567 8901 2345',
        propertyAddress: 'Plot 14, Nardana, Dhule',
        stampPaperValue: 100.0,
        stampPaperState: 'Maharashtra',
        stampPaperLanguage: 'Marathi',
        stampTopMarginMm: 80.0,
        formXOption: 'transfer',
        oldConsumerConsent: true,
        createdAt: now,
        updatedAt: now,
      );

      final json = app.toJson();
      expect(json['application_no'], 'MSEDCL-CN-202611-999');
      expect(json['consumer_no'], '096570003663');
      expect(json['stamp_paper_value'], 100.0);
      expect(json['form_x_option'], 'transfer');

      final fromJson = MsedclChangeOfNameApplication.fromJson(json);
      expect(fromJson.applicationNo, app.applicationNo);
      expect(fromJson.computedNewFullName, 'RAJU VASANT CHAUDHARI');
      expect(fromJson.computedOldFullName, 'AALIEM BABUMIYA PATEL');
      expect(fromJson.isFormXTransfer, isTrue);
      expect(fromJson.isFormXRefund, isFalse);
    });

    test('2. Service CRUD Operations & Status Advancement History', () async {
      // 1. Initial fetch contains default seed apps
      final initial = await MsedclChangeOfNameService.fetchApplications();
      expect(initial.length, greaterThanOrEqualTo(3));

      // 2. Create a new application
      final newApp = MsedclChangeOfNameApplication(
        id: '',
        applicationNo: '',
        applicationDate: DateTime.now(),
        subDivisionOffice: 'Shindkheda Sub-Division',
        village: 'Ghotane',
        oldFirstName: 'Aanandrao',
        oldConsumerFullName: 'Aanandrao Patil',
        consumerNo: '094660000245',
        newFirstName: 'Sunil',
        newConsumerFullName: 'Sunil Patil',
        newMobileNo: '9823456789',
        propertyAddress: 'Ghotane, Shindkheda',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final saved = await MsedclChangeOfNameService.saveApplication(newApp);
      expect(saved.id.isNotEmpty, isTrue);
      expect(saved.applicationNo.startsWith('MSEDCL-CN-'), isTrue);
      expect(saved.statusHistory.isNotEmpty, isTrue);

      // 3. Update status to 'Documents Completed'
      final updated = await MsedclChangeOfNameService.updateStatus(
        id: saved.id,
        newStatus: MsedclApplicationStatus.docsCompleted,
        updatedBy: 'Admin',
        remarks: 'All documents verified',
      );
      expect(updated, isNotNull);
      expect(updated!.status, MsedclApplicationStatus.docsCompleted);
      expect(updated.statusHistory.length, 2);

      // 4. Delete application
      final deleted = await MsedclChangeOfNameService.deleteApplication(saved.id);
      expect(deleted, isTrue);
      final afterDelete = await MsedclChangeOfNameService.fetchApplications();
      expect(afterDelete.any((a) => a.id == saved.id), isFalse);
    });

    test('3. MSEDCL U Form PDF Generation', () async {
      final app = MsedclChangeOfNameService.defaultSeedApplications.first;
      final pdfBytes = await MsedclPdfService.generateUFormPdf(app);
      expect(pdfBytes, isNotNull);
      expect(pdfBytes.length, greaterThan(1000));
    });

    test('4. Stamp Paper Affidavit PDF Generation (Marathi & English)', () async {
      final appMarathi = MsedclChangeOfNameService.defaultSeedApplications.first;
      final pdfBytesMarathi = await MsedclPdfService.generateAffidavitPdf(appMarathi);
      expect(pdfBytesMarathi, isNotNull);
      expect(pdfBytesMarathi.length, greaterThan(1000));

      final appEnglish = appMarathi.copyWith(
        stampPaperLanguage: 'English',
        stampPaperValue: 500.0,
      );
      final pdfBytesEnglish = await MsedclPdfService.generateAffidavitPdf(appEnglish);
      expect(pdfBytesEnglish, isNotNull);
      expect(pdfBytesEnglish.length, greaterThan(1000));
    });

    test('5. Form X PDF Generation (Transfer & Refund)', () async {
      // Option A: Transfer
      final appTransfer = MsedclChangeOfNameService.defaultSeedApplications.first;
      final pdfTransfer = await MsedclPdfService.generateFormXPdf(appTransfer);
      expect(pdfTransfer, isNotNull);
      expect(pdfTransfer.length, greaterThan(1000));

      // Option B: Refund
      final appRefund = appTransfer.copyWith(
        formXOption: 'refund',
        refundAccountHolderName: 'AALIEM PATEL',
        refundBankName: 'State Bank of India',
        refundAccountNumber: '30456789012',
        refundIfscCode: 'SBIN0001234',
        refundBranch: 'Nardana',
        receiptStatus: 'Available',
      );
      final pdfRefund = await MsedclPdfService.generateFormXPdf(appRefund);
      expect(pdfRefund, isNotNull);
      expect(pdfRefund.length, greaterThan(1000));
    });

    test('6. Annexure A Document Checklist PDF Generation', () async {
      final app = MsedclChangeOfNameService.defaultSeedApplications.first;
      final pdfBytes = await MsedclPdfService.generateChecklistPdf(app);
      expect(pdfBytes, isNotNull);
      expect(pdfBytes.length, greaterThan(1000));
    });

    test('7. Complete Application Combined Master PDF Generation', () async {
      final app = MsedclChangeOfNameService.defaultSeedApplications.first;
      final combinedBytes = await MsedclPdfService.generateCompleteApplicationPdf(
        app,
        includeUForm: true,
        includeAffidavit: true,
        includeFormX: true,
        includeChecklist: true,
      );
      expect(combinedBytes, isNotNull);
      expect(combinedBytes.length, greaterThan(2000));
    });

    test('8. Excel Export Generation with Exactly 5 Sheets', () {
      final apps = MsedclChangeOfNameService.defaultSeedApplications;
      final workbook = MsedclExcelService.generateWorkbook(
        applications: apps,
        appliedFilterDescription: 'All Test Applications',
      );

      expect(workbook.tables.containsKey('All Applications'), isTrue);
      expect(workbook.tables.containsKey('Pending Applications'), isTrue);
      expect(workbook.tables.containsKey('Completed Applications'), isTrue);
      expect(workbook.tables.containsKey('Sub-Division Breakdown'), isTrue);
      expect(workbook.tables.containsKey('Employee Breakdown'), isTrue);
      expect(workbook.tables.length, 5);

      final bytes = workbook.save();
      expect(bytes, isNotNull);
      expect(bytes!.length, greaterThan(500));
    });

    test('9. Search and Filter Query Execution', () async {
      // 1. Filter by Status
      final pending = await MsedclChangeOfNameService.fetchApplications(status: MsedclApplicationStatus.docsPending);
      expect(pending.every((a) => a.status == MsedclApplicationStatus.docsPending), isTrue);

      // 2. Filter by Sub-Division
      final nardana = await MsedclChangeOfNameService.fetchApplications(subDivision: 'Nardana');
      expect(nardana.every((a) => a.subDivisionOffice.contains('Nardana')), isTrue);

      // 3. Search query matching Consumer No
      final byConsumer = await MsedclChangeOfNameService.fetchApplications(searchQuery: '096570003663');
      expect(byConsumer.length, 1);
      expect(byConsumer.first.consumerNo, '096570003663');

      // 4. Search query matching New Consumer Name
      final byName = await MsedclChangeOfNameService.fetchApplications(searchQuery: 'Raju');
      expect(byName.length, 1);
      expect(byName.first.computedNewFullName.toLowerCase(), contains('raju'));
    });
  });
}
