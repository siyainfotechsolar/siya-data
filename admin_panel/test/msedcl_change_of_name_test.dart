import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
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

    test('10. Full Application CRUD (Create, Read/View, Update, Status, Delete) Lifecycle', () async {
      // 1. CREATE
      final newApp = MsedclChangeOfNameApplication(
        id: '',
        applicationNo: '',
        applicationDate: DateTime.now(),
        subDivisionOffice: 'Nardana Sub-Division',
        circleOffice: 'Dhule Circle',
        village: 'Nardana',
        reasonForChange: MsedclReasonForChange.inheritance,
        assignedEmployee: 'Rahul',
        remarks: 'Legal heir transfer under will',
        oldFirstName: 'Ramesh',
        oldSurname: 'Patil',
        oldConsumerFullName: 'Ramesh Patil',
        consumerNo: '096570009999',
        newFirstName: 'Mahesh',
        newSurname: 'Patil',
        newConsumerFullName: 'Mahesh Ramesh Patil',
        newMobileNo: '9876543210',
        propertyAddress: 'Plot 12, Nardana, Dhule',
        stampPaperValue: 500.0,
        formXOption: 'transfer',
        documents: const [
          MsedclDocumentItem(docType: MsedclDocumentType.electricityBill, status: 'Received'),
          MsedclDocumentItem(docType: MsedclDocumentType.extract712, status: 'Received'),
          MsedclDocumentItem(docType: MsedclDocumentType.successionOrWill, status: 'Received'),
        ],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final created = await MsedclChangeOfNameService.saveApplication(newApp);
      expect(created.id, isNotEmpty);
      expect(created.applicationNo, startsWith('MSEDCL-CN-'));
      expect(created.computedNewFullName, 'Mahesh Ramesh Patil');
      expect(created.receivedDocCount, 3);

      // 2. READ / VIEW
      final allApps = await MsedclChangeOfNameService.fetchApplications();
      final fetched = allApps.firstWhere((a) => a.id == created.id);
      expect(fetched.applicationNo, created.applicationNo);
      expect(fetched.consumerNo, '096570009999');
      expect(fetched.stampPaperValue, 500.0);
      expect(fetched.reasonForChange, MsedclReasonForChange.inheritance);

      // 3. UPDATE (Edit fields)
      final modifiedApp = fetched.copyWith(
        remarks: 'Updated after verifying succession certificate',
        stampPaperValue: 200.0,
      );
      final updated = await MsedclChangeOfNameService.saveApplication(modifiedApp);
      expect(updated.remarks, 'Updated after verifying succession certificate');
      expect(updated.stampPaperValue, 200.0);

      // 4. ADVANCE STATUS
      final withNewStatus = await MsedclChangeOfNameService.updateStatus(
        id: updated.id,
        newStatus: MsedclApplicationStatus.submitted,
        updatedBy: 'Admin',
        remarks: 'Application submitted to Nardana Sub-Division office',
      );
      expect(withNewStatus?.status, MsedclApplicationStatus.submitted);
      expect(withNewStatus?.statusHistory.last.status, MsedclApplicationStatus.submitted);

      // 5. DELETE
      final deleteResult = await MsedclChangeOfNameService.deleteApplication(created.id);
      expect(deleteResult, isTrue);

      final postDeleteList = await MsedclChangeOfNameService.fetchApplications();
      expect(postDeleteList.any((a) => a.id == created.id), isFalse);
    });

    test('11. Signature Upload, Serialization & Embedding in Form U, Stamp Affidavit & Form X', () async {
      // 1. Create a dummy transparent 1x1 PNG signature in base64
      const dummySignatureBase64 =
          'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=';

      final appWithSignatures = MsedclChangeOfNameApplication(
        id: 'test-sig-001',
        applicationNo: 'MSEDCL-CN-202611-SIG',
        applicationDate: DateTime.now(),
        subDivisionOffice: 'Nardana Sub-Division',
        circleOffice: 'Dhule Circle',
        village: 'Nardana',
        reasonForChange: MsedclReasonForChange.purchaseOfProperty,
        assignedEmployee: 'Rahul',
        oldFirstName: 'RAMESH',
        oldSurname: 'PATIL',
        oldConsumerFullName: 'RAMESH PATIL',
        consumerNo: '096570003663',
        newFirstName: 'SURESH',
        newSurname: 'PATIL',
        newConsumerFullName: 'SURESH RAMESH PATIL',
        newMobileNo: '9822112233',
        propertyAddress: 'Plot 22, Nardana, Dhule',
        stampPaperValue: 100.0,
        stampPaperLanguage: 'Marathi',
        newConsumerSignatureBase64: dummySignatureBase64,
        oldConsumerSignatureBase64: dummySignatureBase64,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Verify getters
      expect(appWithSignatures.hasNewConsumerSignature, isTrue);
      expect(appWithSignatures.hasOldConsumerSignature, isTrue);
      expect(appWithSignatures.newConsumerSignatureBytes, isNotNull);
      expect(appWithSignatures.oldConsumerSignatureBytes, isNotNull);

      // Verify JSON serialization of signatures
      final json = appWithSignatures.toJson();
      expect(json['new_consumer_signature_base64'], dummySignatureBase64);
      expect(json['old_consumer_signature_base64'], dummySignatureBase64);

      final deserialized = MsedclChangeOfNameApplication.fromJson(json);
      expect(deserialized.hasNewConsumerSignature, isTrue);
      expect(deserialized.hasOldConsumerSignature, isTrue);

      // Generate 2-Page Official Form U PDF with embedded signature
      final uFormPdf = await MsedclPdfService.generateUFormPdf(appWithSignatures);
      expect(uFormPdf.length, greaterThan(1000));

      // Generate ₹100 Stamp Paper Affidavit PDF with embedded signature
      final affidavitPdf = await MsedclPdfService.generateAffidavitPdf(appWithSignatures);
      expect(affidavitPdf.length, greaterThan(1000));

      // Generate Form X PDF with embedded signature
      final formXPdf = await MsedclPdfService.generateFormXPdf(appWithSignatures);
      expect(formXPdf.length, greaterThan(1000));

      // Generate Complete Master Application PDF
      final masterPdf = await MsedclPdfService.generateCompleteApplicationPdf(appWithSignatures);
      expect(masterPdf.length, greaterThan(1500));
      expect(masterPdf.length, lessThanOrEqualTo(1024 * 1024), reason: 'Complete Master Application PDF must be strictly <= 1 MB for portal upload');
    });

    test('12. Strict MSEDCL Portal Document Size Limit (Upto 1 MB / 1024 KB) with Heavy Attachments', () async {
      // 1. Generate realistic image bytes for 5 document enclosures
      final dummyImg = img.Image(width: 800, height: 1100);
      img.fill(dummyImg, color: img.ColorRgba8(245, 245, 245, 255));
      for (int y = 50; y < 1050; y += 40) {
        img.drawLine(dummyImg, x1: 50, y1: y, x2: 750, y2: y, color: img.ColorRgba8(50, 50, 50, 255));
      }
      final rawDocBytes = Uint8List.fromList(img.encodePng(dummyImg));
      final rawDocBase64 = base64Encode(rawDocBytes);

      // Verify compressImageForA4 works and produces valid image bytes
      final compressedBytes = MsedclPdfService.compressImageForA4(rawDocBytes, maxDimension: 800, quality: 60);
      expect(compressedBytes.length, greaterThan(100));

      // 2. Build application with 5 attached received documents
      final heavyApp = MsedclChangeOfNameApplication(
        id: 'heavy-doc-app',
        applicationNo: 'MSEDCL-CN-202611-1MB',
        applicationDate: DateTime.now(),
        subDivisionOffice: 'Nardana Sub-Division',
        circleOffice: 'Dhule Circle',
        village: 'Nardana',
        reasonForChange: MsedclReasonForChange.purchaseOfProperty,
        assignedEmployee: 'Avinash',
        status: MsedclApplicationStatus.docsCompleted,
        oldFirstName: 'AALIEM',
        oldSurname: 'PATEL',
        oldConsumerFullName: 'AALIEM BABUMIYA PATEL',
        consumerNo: '096570003663',
        newFirstName: 'RAJU',
        newSurname: 'CHAUDHARI',
        newConsumerFullName: 'RAJU VASANT CHAUDHARI',
        newMobileNo: '9423187654',
        propertyAddress: 'Nardana, Tal. Shindkheda, Dist. Dhule',
        stampPaperValue: 100.0,
        stampPaperLanguage: 'English',
        documents: [
          MsedclDocumentItem(docType: MsedclDocumentType.electricityBill, status: 'Received', fileName: 'bill.png', fileBytesBase64: rawDocBase64),
          MsedclDocumentItem(docType: MsedclDocumentType.extract712, status: 'Received', fileName: '712.png', fileBytesBase64: rawDocBase64),
          MsedclDocumentItem(docType: MsedclDocumentType.ownershipProof, status: 'Received', fileName: 'sale_deed.png', fileBytesBase64: rawDocBase64),
          MsedclDocumentItem(docType: MsedclDocumentType.propertyTaxReceipt, status: 'Received', fileName: 'tax.png', fileBytesBase64: rawDocBase64),
          MsedclDocumentItem(docType: MsedclDocumentType.affidavitGazette, status: 'Received', fileName: 'affidavit.png', fileBytesBase64: rawDocBase64),
        ],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // 3. Generate all documents and verify size constraints
      final uForm = await MsedclPdfService.generateUFormPdf(heavyApp);
      expect(uForm.lengthInBytes, lessThanOrEqualTo(1024 * 1024), reason: 'Form U PDF must be <= 1 MB');

      final affidavit = await MsedclPdfService.generateAffidavitPdf(heavyApp);
      expect(affidavit.lengthInBytes, lessThanOrEqualTo(1024 * 1024), reason: 'Affidavit PDF must be <= 1 MB');

      final formX = await MsedclPdfService.generateFormXPdf(heavyApp);
      expect(formX.lengthInBytes, lessThanOrEqualTo(1024 * 1024), reason: 'Form X PDF must be <= 1 MB');

      final checklist = await MsedclPdfService.generateChecklistPdf(heavyApp);
      expect(checklist.lengthInBytes, lessThanOrEqualTo(1024 * 1024), reason: 'Checklist PDF must be <= 1 MB');

      final completeApp = await MsedclPdfService.generateCompleteApplicationPdf(heavyApp);
      expect(completeApp.lengthInBytes, greaterThan(10000));
      expect(completeApp.lengthInBytes, lessThanOrEqualTo(1024 * 1024),
          reason: 'Complete Application PDF with 5 heavy attachments MUST be <= 1 MB (1024 KB) for portal upload');

      // Verify portal size limit constant
      expect(MsedclPdfService.maxPortalPdfSizeBytes, 1024 * 1024);
    });
  });
}
