import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:admin_panel/models/msedcl_change_of_name.dart';
import 'package:admin_panel/services/msedcl_pdf_service.dart';

void main() {
  test('generate official sample PDFs for user artifact directory', () async {
    final sigImg = img.Image(width: 140, height: 40);
    img.fill(sigImg, color: img.ColorRgba8(0, 0, 0, 0));
    img.drawLine(sigImg, x1: 15, y1: 25, x2: 125, y2: 15, color: img.ColorRgba8(10, 45, 140, 255));
    img.drawLine(sigImg, x1: 25, y1: 30, x2: 80, y2: 10, color: img.ColorRgba8(10, 45, 140, 255));
    final dummySignature = base64Encode(Uint8List.fromList(img.encodePng(sigImg)));

    final app = MsedclChangeOfNameApplication(
      id: 'app-sample-001',
      applicationNo: 'MSEDCL-CN-202611-0042',
      applicationDate: DateTime.now(),
      subDivisionOffice: 'Nardana Sub-Division',
      circleOffice: 'Dhule Circle',
      village: 'Nardana',
      reasonForChange: MsedclReasonForChange.purchaseOfProperty,
      assignedEmployee: 'Rahul',
      remarks: 'Registered Sale Deed No. 1420/2026',
      status: MsedclApplicationStatus.docsCompleted,
      oldFirstName: 'AALIEM',
      oldFatherOrHusbandName: 'BABUMIYA',
      oldSurname: 'PATEL',
      oldConsumerFullName: 'AALIEM BABUMIYA PATEL',
      consumerNo: '096570003663',
      oldMobileNo: '9822334455',
      oldMeterNo: 'MTR-782190',
      newFirstName: 'RAJU',
      newFatherOrHusbandName: 'VASANT',
      newSurname: 'CHAUDHARI',
      newConsumerFullName: 'RAJU VASANT CHAUDHARI',
      newAge: 42,
      newMobileNo: '9423187654',
      newPhoneNo: '02562-234567',
      newEmail: 'raju.chaudhari@gmail.com',
      newAadhaarNo: '4567 8901 2345',
      propertyAddress: 'Plot No. 14, Gat No. 88, Near Water Tank, Nardana, Tal. Shindkheda, Dist. Dhule',
      stampPaperValue: 100.0,
      stampPaperState: 'Maharashtra',
      stampPaperLanguage: 'Marathi',
      stampTopMarginMm: 80.0,
      formXOption: 'transfer',
      oldConsumerConsent: true,
      documents: const [
        MsedclDocumentItem(docType: MsedclDocumentType.electricityBill, status: 'Received'),
        MsedclDocumentItem(docType: MsedclDocumentType.extract712, status: 'Received'),
        MsedclDocumentItem(docType: MsedclDocumentType.ownershipProof, status: 'Received'),
        MsedclDocumentItem(docType: MsedclDocumentType.propertyTaxReceipt, status: 'Received'),
        MsedclDocumentItem(docType: MsedclDocumentType.affidavitGazette, status: 'Received'),
      ],
      newConsumerSignatureBase64: dummySignature,
      oldConsumerSignatureBase64: dummySignature,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    final dir = Directory(r'C:\Users\Admin\.gemini\antigravity\brain\830e2504-7b0c-4ee4-8264-23b83985f796');
    if (!dir.existsSync()) dir.createSync(recursive: true);

    // 1. Official 2-Page MSEDCL U Form PDF (Page 1: Form U; Page 2: Annexure A & Form X)
    final uFormBytes = await MsedclPdfService.generateUFormPdf(app);
    File('${dir.path}\\msedcl_official_u_form_application.pdf').writeAsBytesSync(uFormBytes);

    // 2. Official Marathi ₹100 Stamp Paper Affidavit (Plain Preview)
    final plainAffidavitApp = app.copyWith(stampTopMarginMm: 0);
    final marathiAffidavitBytes = await MsedclPdfService.generateAffidavitPdf(plainAffidavitApp);
    File('${dir.path}\\msedcl_100_rupees_stamp_paper_affidavit_marathi_preview.pdf').writeAsBytesSync(marathiAffidavitBytes);

    // 3. Official Marathi Physical Stamp Paper (80mm Top Margin)
    final physicalAffidavitApp = app.copyWith(stampTopMarginMm: 80);
    final physicalAffidavitBytes = await MsedclPdfService.generateAffidavitPdf(physicalAffidavitApp);
    File('${dir.path}\\msedcl_100_rupees_physical_stamp_paper_affidavit_marathi.pdf').writeAsBytesSync(physicalAffidavitBytes);

    // 4. Official English ₹100 Stamp Paper Affidavit
    final engAffidavitApp = app.copyWith(stampPaperLanguage: 'English', stampTopMarginMm: 0);
    final engAffidavitBytes = await MsedclPdfService.generateAffidavitPdf(engAffidavitApp);
    File('${dir.path}\\msedcl_100_rupees_stamp_paper_affidavit_english.pdf').writeAsBytesSync(engAffidavitBytes);

    // 5. Official Form X Security Deposit PDF
    final formXBytes = await MsedclPdfService.generateFormXPdf(app);
    File('${dir.path}\\msedcl_form_x_security_deposit_transfer.pdf').writeAsBytesSync(formXBytes);

    // 6. Complete Master Application Combined PDF
    final masterBytes = await MsedclPdfService.generateCompleteApplicationPdf(app);
    File('${dir.path}\\msedcl_complete_master_application.pdf').writeAsBytesSync(masterBytes);

    print('Generated all 6 official signed PDF documents successfully!');
  });
}
