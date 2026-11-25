import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart' as sf;
import 'package:admin_panel/models/msedcl_change_of_name.dart';
import 'package:admin_panel/services/msedcl_pdf_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Generate official ₹100 Stamp Paper Affidavit & MSEDCL Change of Name PDFs', () async {
    const artifactDir = 'C:/Users/Admin/.gemini/antigravity/brain/830e2504-7b0c-4ee4-8264-23b83985f796';
    Directory(artifactDir).createSync(recursive: true);

    // -------------------------------------------------------------------------
    // 1. ₹100 Stamp Paper Application - Marathi (Preview on Plain A4)
    // -------------------------------------------------------------------------
    final app100MarathiPlain = MsedclChangeOfNameApplication(
      id: 'app-sample-100-marathi',
      applicationNo: 'MSEDCL-CN-202611-001',
      applicationDate: DateTime.now(),
      subDivisionOffice: 'Nardana Sub-Division',
      circleOffice: 'Dhule Circle',
      village: 'Jatoda',
      reasonForChange: MsedclReasonForChange.purchaseOfProperty,
      assignedEmployee: 'Rahul Patil',
      remarks: 'Property purchased via registered Sale Deed. Official ₹100 Non-Judicial Stamp Paper Affidavit generated for MSEDCL Name Transfer.',
      status: MsedclApplicationStatus.docsCompleted,
      // Old Consumer
      oldFirstName: 'AALIEM',
      oldFatherOrHusbandName: 'BABUMIYA',
      oldSurname: 'PATEL',
      oldConsumerFullName: 'AALIEM BABUMIYA PATEL',
      consumerNo: '096570003663',
      oldMobileNo: '9822001122',
      oldMeterNo: 'MTR-982145',
      // New Consumer
      newFirstName: 'RAJU',
      newFatherOrHusbandName: 'VASANT',
      newSurname: 'CHAUDHARI',
      newConsumerFullName: 'RAJU VASANT CHAUDHARI',
      newAge: 38,
      newMobileNo: '9822114455',
      newPhoneNo: '02562-245100',
      newEmail: 'raju.chaudhari@gmail.com',
      newAadhaarNo: '7845 1209 3456',
      propertyAddress: 'H. N. 25, At Post Jatoda, Tal. Shindkheda, Dist. Dhule - 425406',
      // Stamp Paper Configuration: ₹100, Plain paper simulated header (top margin = 0)
      stampPaperValue: 100.0,
      stampPaperState: 'Maharashtra',
      stampPaperLanguage: 'Marathi',
      stampTopMarginMm: 0.0, // Shows Government of Maharashtra ₹100 header
      affidavitPlace: 'Dhule',
      // Form X
      formXOption: 'transfer',
      oldConsumerConsent: true,
      documents: const [
        MsedclDocumentItem(docType: MsedclDocumentType.electricityBill, status: 'Received', fileName: 'electricity_bill_oct2026.pdf'),
        MsedclDocumentItem(docType: MsedclDocumentType.ownershipProof, status: 'Received', fileName: 'sale_deed_registered.pdf'),
        MsedclDocumentItem(docType: MsedclDocumentType.extract712, status: 'Received', fileName: '7_12_extract_jatoda.pdf'),
        MsedclDocumentItem(docType: MsedclDocumentType.form8, status: 'Received', fileName: 'form_8a_grampanchayat.pdf'),
        MsedclDocumentItem(docType: MsedclDocumentType.propertyTaxReceipt, status: 'Received', fileName: 'tax_receipt_2026.pdf'),
        MsedclDocumentItem(docType: MsedclDocumentType.ownerNoc, status: 'Received', fileName: 'seller_noc_consent.pdf'),
      ],
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    final bytes1 = await MsedclPdfService.generateAffidavitPdf(app100MarathiPlain);
    final file1 = File('$artifactDir/msedcl_100_rupees_stamp_paper_affidavit_marathi_preview.pdf');
    await file1.writeAsBytes(bytes1);
    expect(file1.existsSync(), isTrue);

    // -------------------------------------------------------------------------
    // 2. ₹100 Physical Stamp Paper Application - Marathi (80mm Top Margin)
    // -------------------------------------------------------------------------
    final app100PhysicalStamp = app100MarathiPlain.copyWith(
      isPhysicalStampPaper: true,
      stampTopMarginMm: 80.0, // 80mm top margin for physical government stamp paper
    );
    final bytes2 = await MsedclPdfService.generateAffidavitPdf(app100PhysicalStamp);
    final file2 = File('$artifactDir/msedcl_100_rupees_physical_stamp_paper_affidavit_marathi.pdf');
    await file2.writeAsBytes(bytes2);
    expect(file2.existsSync(), isTrue);

    // -------------------------------------------------------------------------
    // 3. ₹100 Stamp Paper Application - English Version
    // -------------------------------------------------------------------------
    final app100English = app100MarathiPlain.copyWith(
      stampPaperLanguage: 'English',
      isPhysicalStampPaper: false,
      stampTopMarginMm: 0.0,
    );
    final bytes3 = await MsedclPdfService.generateAffidavitPdf(app100English);
    final file3 = File('$artifactDir/msedcl_100_rupees_stamp_paper_affidavit_english.pdf');
    await file3.writeAsBytes(bytes3);
    expect(file3.existsSync(), isTrue);

    // -------------------------------------------------------------------------
    // 4. MSEDCL Official Form U PDF
    // -------------------------------------------------------------------------
    final bytes4 = await MsedclPdfService.generateUFormPdf(app100MarathiPlain);
    final file4 = File('$artifactDir/msedcl_official_u_form_application.pdf');
    await file4.writeAsBytes(bytes4);
    expect(file4.existsSync(), isTrue);

    // -------------------------------------------------------------------------
    // 5. Form X Security Deposit Transfer PDF
    // -------------------------------------------------------------------------
    final bytes5 = await MsedclPdfService.generateFormXPdf(app100MarathiPlain);
    final file5 = File('$artifactDir/msedcl_form_x_security_deposit_transfer.pdf');
    await file5.writeAsBytes(bytes5);
    expect(file5.existsSync(), isTrue);

    // -------------------------------------------------------------------------
    // 6. Complete Master Application PDF (Form U + Checklist/Form X + ₹100 Stamp Affidavit)
    // Uses app100English so the official English Self Undertaking is embedded in the master PDF
    // -------------------------------------------------------------------------
    final bytes6 = await MsedclPdfService.generateCompleteApplicationPdf(app100English);
    final file6 = File('$artifactDir/msedcl_complete_master_application.pdf');
    await file6.writeAsBytes(bytes6);
    expect(file6.existsSync(), isTrue);

    final bytes6Marathi = await MsedclPdfService.generateCompleteApplicationPdf(app100MarathiPlain);
    final file6Marathi = File('$artifactDir/msedcl_complete_master_application_marathi.pdf');
    await file6Marathi.writeAsBytes(bytes6Marathi);
    expect(file6Marathi.existsSync(), isTrue);

    print('All MSEDCL ₹100 Stamp Paper and Application PDFs successfully generated in $artifactDir');

    for (final entry in [
      MapEntry('Marathi Preview', file1),
      MapEntry('Physical Marathi', file2),
      MapEntry('English Affidavit', file3),
      MapEntry('Form U', file4),
      MapEntry('Form X', file5),
      MapEntry('Master Application', file6),
      MapEntry('Master Application (Marathi)', file6Marathi),
    ]) {
      final doc = sf.PdfDocument(inputBytes: entry.value.readAsBytesSync());
      print('--> [${entry.key}] Pages: ${doc.pages.count}, Size: ${entry.value.lengthSync()} bytes');
      if (entry.key == 'English Affidavit' || entry.key == 'Master Application') {
        final extractor = sf.PdfTextExtractor(doc);
        for (int i = 0; i < doc.pages.count; i++) {
          print('--- ${entry.key} PAGE ${i + 1} ---');
          print(extractor.extractText(startPageIndex: i, endPageIndex: i).trim());
        }
      }
      doc.dispose();
    }
  });
}
