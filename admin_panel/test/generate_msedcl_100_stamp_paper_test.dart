import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
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

    print('All 5 MSEDCL ₹100 Stamp Paper and Application PDFs successfully generated in $artifactDir');
  });
}
