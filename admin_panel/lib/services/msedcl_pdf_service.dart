import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:syncfusion_flutter_pdf/pdf.dart' as sf;
import '../models/msedcl_change_of_name.dart';
import 'solar_quotation_font_helper.dart';

class MsedclPdfService {
  static final DateFormat _dateFormat = DateFormat('dd/MM/yyyy');

  // MSEDCL Official Branding Colors
  static const PdfColor primaryBlue = PdfColor.fromInt(0xFF0F3B7A);
  static const PdfColor mahavitaranRed = PdfColor.fromInt(0xFFDC2626);
  static const PdfColor darkText = PdfColor.fromInt(0xFF1E293B);
  static const PdfColor mutedText = PdfColor.fromInt(0xFF64748B);
  static const PdfColor lightBg = PdfColor.fromInt(0xFFF8FAFC);
  static const PdfColor borderColor = PdfColor.fromInt(0xFF94A3B8);

  static Uint8List? _cachedTemplateBytes;

  /// Loads the original official MSEDCL U Form template PDF
  static Future<Uint8List?> _loadTemplateBytes() async {
    if (_cachedTemplateBytes != null) return _cachedTemplateBytes;
    try {
      final byteData = await rootBundle.load('assets/templates/msedcl_u_form_template.pdf');
      _cachedTemplateBytes = byteData.buffer.asUint8List();
      return _cachedTemplateBytes;
    } catch (_) {}

    try {
      final f = File('assets/templates/msedcl_u_form_template.pdf');
      if (f.existsSync()) {
        _cachedTemplateBytes = f.readAsBytesSync();
        return _cachedTemplateBytes;
      }
    } catch (_) {}

    try {
      final f = File('admin_panel/assets/templates/msedcl_u_form_template.pdf');
      if (f.existsSync()) {
        _cachedTemplateBytes = f.readAsBytesSync();
        return _cachedTemplateBytes;
      }
    } catch (_) {}

    try {
      final f = File(r'C:\Users\Admin\.gemini\antigravity\brain\830e2504-7b0c-4ee4-8264-23b83985f796\.user_uploaded\media_1795543505437_d96150c5.pdf');
      if (f.existsSync()) {
        _cachedTemplateBytes = f.readAsBytesSync();
        return _cachedTemplateBytes;
      }
    } catch (_) {}

    return null;
  }

  // ==========================================
  // 1. MSEDCL U FORM PDF (2-PAGE OFFICIAL FORM)
  // ==========================================

  /// Generate official MSEDCL Form U (Application Form for Change of Name & Annexure A / Form X)
  /// Keeps the original official MSEDCL PDF as the base, and overlays all customer details,
  /// checkboxes and uploaded signatures directly in new high-precision layers.
  static Future<Uint8List> generateUFormPdf(MsedclChangeOfNameApplication app) async {
    final templateBytes = await _loadTemplateBytes();
    if (templateBytes != null && templateBytes.isNotEmpty) {
      try {
        return _generateUFormOverlayPdf(app, templateBytes);
      } catch (e) {
        // ignore: avoid_print
        print('MsedclPdfService: Failed to overlay onto original PDF template: $e. Falling back to generated replica.');
      }
    }
    return _generateUFormFallbackPdf(app);
  }

  /// Overlay customer details, signatures and checkboxes onto the original official MSEDCL template
  static Uint8List _generateUFormOverlayPdf(MsedclChangeOfNameApplication app, Uint8List templateBytes) {
    final document = sf.PdfDocument(inputBytes: templateBytes);

    // Dark Navy Blue ink brush for authentic official form appearance
    final textBrush = sf.PdfSolidBrush(sf.PdfColor(12, 38, 100));
    final fontBold = sf.PdfStandardFont(sf.PdfFontFamily.helvetica, 8.5, style: sf.PdfFontStyle.bold);
    final fontNormal = sf.PdfStandardFont(sf.PdfFontFamily.helvetica, 8);
    final fontSmall = sf.PdfStandardFont(sf.PdfFontFamily.helvetica, 7.5);
    final fontCheck = sf.PdfStandardFont(sf.PdfFontFamily.helvetica, 10, style: sf.PdfFontStyle.bold);

    // Alignment formats for perfect centering within form boxes and lines
    final centerFormat = sf.PdfStringFormat(
      alignment: sf.PdfTextAlignment.center,
      lineAlignment: sf.PdfVerticalAlignment.middle,
    );

    // =========================================================================
    // PAGE 0: OFFICIAL "U" FORM - DEDICATED NEW LAYER FOR CUSTOMER DETAILS
    // =========================================================================
    final page0 = document.pages[0];
    final layer0 = page0.layers.add(name: 'NewCustomerDetails');
    final g0 = layer0.graphics;

    // 1. Date of Application
    g0.drawString(_dateFormat.format(app.applicationDate), fontBold, brush: textBrush, bounds: ui.Rect.fromLTWH(485, 134, 85, 14));

    // 2. Sub-Division / Circle Office
    final officeStr = '${app.subDivisionOffice.isNotEmpty ? app.subDivisionOffice : "Sub-Division"}, ${app.circleOffice.isNotEmpty ? app.circleOffice : "Circle Office"}';
    g0.drawString(officeStr, fontBold, brush: textBrush, bounds: ui.Rect.fromLTWH(85, 184, 250, 14));

    // 3. Old Consumer Details (First, Father, Surname)
    // Centered vertically and horizontally inside the designated table cells
    final oldFirst = app.oldFirstName.isNotEmpty ? app.oldFirstName : (app.oldConsumerFullName.split(' ').isNotEmpty ? app.oldConsumerFullName.split(' ').first : '');
    final oldFather = app.oldFatherOrHusbandName.isNotEmpty ? app.oldFatherOrHusbandName : (app.oldConsumerFullName.split(' ').length > 1 ? app.oldConsumerFullName.split(' ')[1] : '');
    final oldLast = app.oldSurname.isNotEmpty ? app.oldSurname : (app.oldConsumerFullName.split(' ').length > 2 ? app.oldConsumerFullName.split(' ').last : '');

    g0.drawString(oldFirst.toUpperCase(), fontBold, brush: textBrush, bounds: ui.Rect.fromLTWH(176, 280, 118, 30), format: centerFormat);
    g0.drawString(oldFather.toUpperCase(), fontBold, brush: textBrush, bounds: ui.Rect.fromLTWH(296, 280, 123, 30), format: centerFormat);
    g0.drawString(oldLast.toUpperCase(), fontBold, brush: textBrush, bounds: ui.Rect.fromLTWH(421, 280, 116, 30), format: centerFormat);

    // Old Consumer No & Mobile
    g0.drawString(app.consumerNo, fontBold, brush: textBrush, bounds: ui.Rect.fromLTWH(180, 311, 115, 23), format: centerFormat);
    if (app.oldMobileNo.isNotEmpty) {
      g0.drawString(app.oldMobileNo, fontBold, brush: textBrush, bounds: ui.Rect.fromLTWH(345, 311, 190, 23), format: centerFormat);
    }

    // 4. New Consumer Details (First, Father, Surname)
    // Centered vertically and horizontally inside the designated table cells
    final newFirst = app.newFirstName.isNotEmpty ? app.newFirstName : (app.computedNewFullName.split(' ').isNotEmpty ? app.computedNewFullName.split(' ').first : '');
    final newFather = app.newFatherOrHusbandName.isNotEmpty ? app.newFatherOrHusbandName : (app.computedNewFullName.split(' ').length > 1 ? app.computedNewFullName.split(' ')[1] : '');
    final newLast = app.newSurname.isNotEmpty ? app.newSurname : (app.computedNewFullName.split(' ').length > 2 ? app.computedNewFullName.split(' ').last : '');

    g0.drawString(newFirst.toUpperCase(), fontBold, brush: textBrush, bounds: ui.Rect.fromLTWH(176, 390, 118, 30), format: centerFormat);
    g0.drawString(newFather.toUpperCase(), fontBold, brush: textBrush, bounds: ui.Rect.fromLTWH(296, 390, 123, 30), format: centerFormat);
    g0.drawString(newLast.toUpperCase(), fontBold, brush: textBrush, bounds: ui.Rect.fromLTWH(421, 390, 116, 30), format: centerFormat);

    // New Consumer Contact: Email, Phone, Mobile
    // Carefully sized to fit into official template boxes without colliding
    if (app.newEmail.isNotEmpty) {
      g0.drawString(app.newEmail, fontSmall, brush: textBrush, bounds: ui.Rect.fromLTWH(132, 420, 88, 17), format: centerFormat);
    }
    g0.drawString(app.newPhoneNo.isNotEmpty ? app.newPhoneNo : '-', fontSmall, brush: textBrush, bounds: ui.Rect.fromLTWH(277, 420, 73, 17), format: centerFormat);
    g0.drawString(app.newMobileNo, fontBold, brush: textBrush, bounds: ui.Rect.fromLTWH(407, 420, 128, 17), format: centerFormat);

    // Aadhaar Card No (Optional)
    if (app.newAadhaarNo.isNotEmpty) {
      g0.drawString(app.newAadhaarNo, fontBold, brush: textBrush, bounds: ui.Rect.fromLTWH(200, 437, 160, 16), format: sf.PdfStringFormat(lineAlignment: sf.PdfVerticalAlignment.middle));
    }

    // 5. Reason for Change of Name
    final reasonText = '${app.reasonForChange}${app.remarks.isNotEmpty ? " (${app.remarks})" : ""}';
    g0.drawString(reasonText, fontNormal, brush: textBrush, bounds: ui.Rect.fromLTWH(225, 459, 295, 14));

    // 6. Documents Enclosed (fits neatly before "(Please see Annexure A)")
    final docList = app.documents.where((d) => d.isReceived).map((d) => d.docType).toList();
    final enclosedText = docList.isNotEmpty ? docList.take(2).join(', ') : 'Registered Sale Deed, 7/12 Extract';
    g0.drawString(enclosedText, fontSmall, brush: textBrush, bounds: ui.Rect.fromLTWH(242, 482, 180, 14));

    // 7. Signature of Applicant (placed directly above "Signature of Applicant" label)
    if (app.hasNewConsumerSignature && app.newConsumerSignatureBytes != null) {
      try {
        final pdfBitmap = sf.PdfBitmap(app.newConsumerSignatureBytes!);
        g0.drawImage(pdfBitmap, ui.Rect.fromLTWH(390, 642, 120, 38));
      } catch (_) {}
    }

    // 8. Bottom Acknowledgement Receipt Slip Details:
    // Left completely BLANK for MSEDCL counter office use per user instruction ("he fill chi garaj nahi")

    // =========================================================================
    // PAGE 1: ANNEXURE A & FORM X - DEDICATED NEW LAYER
    // =========================================================================
    final page1 = document.pages[1];
    final layer1 = page1.layers.add(name: 'AnnexureAndFormXDetails');
    final g1 = layer1.graphics;

    // Checkmarks for Annexure A Checklist (placed neatly inside the box margin at x = 73)
    bool hasOcc = app.documents.any((d) => d.isReceived && d.docType == MsedclDocumentType.occupancyCertificate);
    bool hasOwn = app.documents.any((d) => d.isReceived && (d.docType == MsedclDocumentType.ownershipProof || d.docType == MsedclDocumentType.extract712 || d.docType == MsedclDocumentType.form8 || d.docType == MsedclDocumentType.propertyTaxReceipt));
    bool hasLegal = app.documents.any((d) => d.isReceived && d.docType == MsedclDocumentType.successionOrWill);
    bool hasAffidavit = app.documents.any((d) => d.isReceived && (d.docType == MsedclDocumentType.affidavitGazette || d.docType.contains('Affidavit') || d.docType.contains('प्रतिज्ञापत्र')));
    bool hasNoc = app.documents.any((d) => d.isReceived && d.docType == MsedclDocumentType.ownerNoc);

    if (!hasOcc && !hasOwn && !hasLegal && !hasAffidavit) {
      hasOwn = true;
      hasAffidavit = true;
    }

    if (hasOcc) g1.drawString('[X]', fontCheck, brush: textBrush, bounds: ui.Rect.fromLTWH(73, 151, 14, 14));
    if (hasOwn) g1.drawString('[X]', fontCheck, brush: textBrush, bounds: ui.Rect.fromLTWH(73, 167, 14, 14));
    if (hasLegal) g1.drawString('[X]', fontCheck, brush: textBrush, bounds: ui.Rect.fromLTWH(73, 188, 14, 14));
    if (hasAffidavit) g1.drawString('[X]', fontCheck, brush: textBrush, bounds: ui.Rect.fromLTWH(73, 226, 14, 14));
    if (hasNoc) g1.drawString('[X]', fontCheck, brush: textBrush, bounds: ui.Rect.fromLTWH(73, 240, 14, 14));

    // FORM X
    if (app.isFormXTransfer) {
      // Option a) Transfer of Security Deposit
      g1.drawString(app.oldConsumerFullName.toUpperCase(), fontBold, brush: textBrush, bounds: ui.Rect.fromLTWH(170, 412, 270, 14), format: centerFormat);
      g1.drawString(app.consumerNo, fontBold, brush: textBrush, bounds: ui.Rect.fromLTWH(355, 424, 120, 14), format: centerFormat);
      g1.drawString(app.computedNewFullName.toUpperCase(), fontBold, brush: textBrush, bounds: ui.Rect.fromLTWH(205, 436, 280, 14), format: centerFormat);

      // Old Consumer Consent Signature
      if (app.hasOldConsumerSignature && app.oldConsumerSignatureBytes != null) {
        try {
          final pdfBitmap = sf.PdfBitmap(app.oldConsumerSignatureBytes!);
          g1.drawImage(pdfBitmap, ui.Rect.fromLTWH(380, 462, 120, 36));
        } catch (_) {}
      }
    } else {
      // Option b) Refund of Security Deposit
      g1.drawString(app.oldConsumerFullName.toUpperCase(), fontBold, brush: textBrush, bounds: ui.Rect.fromLTWH(170, 585, 270, 14), format: centerFormat);
      g1.drawString(app.computedNewFullName.toUpperCase(), fontBold, brush: textBrush, bounds: ui.Rect.fromLTWH(365, 599, 140, 14), format: centerFormat);
      g1.drawString(app.consumerNo, fontBold, brush: textBrush, bounds: ui.Rect.fromLTWH(345, 612, 125, 14), format: centerFormat);

      final holder = app.refundAccountHolderName.isNotEmpty ? app.refundAccountHolderName : app.oldConsumerFullName;
      g1.drawString(holder, fontBold, brush: textBrush, bounds: ui.Rect.fromLTWH(195, 672, 250, 14));
      g1.drawString('${app.refundBankName} ${app.refundBranch}'.trim(), fontBold, brush: textBrush, bounds: ui.Rect.fromLTWH(195, 685, 250, 14));
      g1.drawString(app.refundAccountNumber, fontBold, brush: textBrush, bounds: ui.Rect.fromLTWH(145, 697, 200, 14));
      g1.drawString(app.refundIfscCode, fontBold, brush: textBrush, bounds: ui.Rect.fromLTWH(125, 710, 150, 14));
      g1.drawString(app.originalReceiptNo.isNotEmpty ? app.originalReceiptNo : (app.receiptStatus == 'Available' ? 'Available' : 'Lost (Indemnity Enclosed)'), fontNormal, brush: textBrush, bounds: ui.Rect.fromLTWH(175, 722, 150, 14));

      // Old Consumer Refund Signature
      if (app.hasOldConsumerSignature && app.oldConsumerSignatureBytes != null) {
        try {
          final pdfBitmap = sf.PdfBitmap(app.oldConsumerSignatureBytes!);
          g1.drawImage(pdfBitmap, ui.Rect.fromLTWH(380, 722, 120, 36));
        } catch (_) {}
      }
    }

    final outBytes = Uint8List.fromList(document.saveSync());
    document.dispose();
    return outBytes;
  }

  /// Programmatic 2-Page MSEDCL U Form fallback if template PDF file is not present
  static Future<Uint8List> _generateUFormFallbackPdf(MsedclChangeOfNameApplication app) async {
    final pdf = pw.Document(
      title: 'MSEDCL Form U - ${app.consumerNo}',
      author: 'Siya Infotech & Solar Energy',
    );

    final pdfTheme = await SolarQuotationFontHelper.loadPdfTheme();

    // -------------------------------------------------------------
    // PAGE 1: OFFICIAL "U" FORM FOR CHANGE OF NAME
    // -------------------------------------------------------------
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        theme: pdfTheme,
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              // Top Header with CIN & Mahavitaran
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'Maharashtra State Electricity Distribution Co. Ltd.',
                        style: pw.TextStyle(fontSize: 10.5, fontWeight: pw.FontWeight.bold, color: primaryBlue),
                      ),
                      pw.Text(
                        '(A Govt. of Maharashtra undertaking)',
                        style: const pw.TextStyle(fontSize: 8, color: darkText),
                      ),
                      pw.Text(
                        'CIN: U40109MH20055GC153645',
                        style: const pw.TextStyle(fontSize: 7.5, color: darkText),
                      ),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        'MAHAVITARAN',
                        style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: mahavitaranRed),
                      ),
                      pw.Text(
                        'Maharashtra State Electricity Distribution Co. Ltd.',
                        style: const pw.TextStyle(fontSize: 6.5, color: mutedText),
                      ),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 6),

              // Title Section
              pw.Center(
                child: pw.Column(
                  children: [
                    pw.Text(
                      '"U" FORM FOR CHANGE OF NAME',
                      style: pw.TextStyle(fontSize: 11.5, fontWeight: pw.FontWeight.bold, color: darkText),
                    ),
                    pw.Text(
                      '(Address of the premises shall remain same)',
                      style: const pw.TextStyle(fontSize: 7.5, color: darkText),
                    ),
                    pw.Text(
                      'You can fill this form online also. Please visit www.mahadiscom.in',
                      style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold, color: darkText),
                    ),
                    pw.Text(
                      '(Processing fee will be waived if application and payment is made online)',
                      style: const pw.TextStyle(fontSize: 6.5, color: darkText),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 4),

              // Date of Application
              pw.Align(
                alignment: pw.Alignment.centerRight,
                child: pw.Text(
                  'Date of Application: ${_dateFormat.format(app.applicationDate)}',
                  style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: darkText),
                ),
              ),
              pw.SizedBox(height: 2),

              // To Officer
              pw.Text('To,', style: const pw.TextStyle(fontSize: 8)),
              pw.Text('The Office In Charge,', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: mahavitaranRed)),
              pw.Text(
                'Sub-Division/ Circle Office: ${app.subDivisionOffice}, ${app.circleOffice}',
                style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: mahavitaranRed),
              ),
              pw.Text('-------------------------------------------', style: const pw.TextStyle(fontSize: 7, color: borderColor)),
              pw.SizedBox(height: 2),

              pw.Text('Dear Sir / Madam,', style: const pw.TextStyle(fontSize: 7.5)),
              pw.Text(
                'I hereby submit this application for Change of Name of connection as mentioned below.',
                style: const pw.TextStyle(fontSize: 7.5),
              ),
              pw.SizedBox(height: 4),

              // 1) Details of Old Consumer
              pw.Text(
                '1) Details of Old Consumer',
                style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: mahavitaranRed),
              ),
              pw.SizedBox(height: 2),
              pw.Table(
                border: pw.TableBorder.all(color: darkText, width: 0.6),
                columnWidths: {
                  0: const pw.FlexColumnWidth(2.6),
                  1: const pw.FlexColumnWidth(2.8),
                  2: const pw.FlexColumnWidth(3.2),
                  3: const pw.FlexColumnWidth(2.8),
                },
                children: [
                  pw.TableRow(
                    children: [
                      pw.Container(
                        padding: const pw.EdgeInsets.all(3),
                        child: pw.Text('1) Applicants Name\n(IN BLOCK LETTERS)', style: pw.TextStyle(fontSize: 6.8, fontWeight: pw.FontWeight.bold)),
                      ),
                      pw.Container(
                        padding: const pw.EdgeInsets.all(3),
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text('First name', style: const pw.TextStyle(fontSize: 6.5, color: mutedText)),
                            pw.Text(app.oldFirstName.toUpperCase(), style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold)),
                          ],
                        ),
                      ),
                      pw.Container(
                        padding: const pw.EdgeInsets.all(3),
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text('Name of Father/Husband', style: const pw.TextStyle(fontSize: 6.5, color: mutedText)),
                            pw.Text(app.oldFatherOrHusbandName.toUpperCase(), style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold)),
                          ],
                        ),
                      ),
                      pw.Container(
                        padding: const pw.EdgeInsets.all(3),
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text('Surname', style: const pw.TextStyle(fontSize: 6.5, color: mutedText)),
                            pw.Text(app.oldSurname.toUpperCase(), style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  pw.TableRow(
                    children: [
                      pw.Container(
                        padding: const pw.EdgeInsets.all(3),
                        child: pw.Text('2) Consumer No.:', style: pw.TextStyle(fontSize: 7.2, fontWeight: pw.FontWeight.bold)),
                      ),
                      pw.Container(
                        padding: const pw.EdgeInsets.all(3),
                        child: pw.Text(app.consumerNo, style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: primaryBlue)),
                      ),
                      pw.Container(
                        padding: const pw.EdgeInsets.all(3),
                        child: pw.Text('(Mobile No):', style: const pw.TextStyle(fontSize: 7)),
                      ),
                      pw.Container(
                        padding: const pw.EdgeInsets.all(3),
                        child: pw.Text(app.oldMobileNo.isNotEmpty ? app.oldMobileNo : '—', style: const pw.TextStyle(fontSize: 7.5)),
                      ),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 5),

              // 2) Details of New Consumer
              pw.Text(
                '2) Details of New Consumer',
                style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: mahavitaranRed),
              ),
              pw.SizedBox(height: 2),
              pw.Table(
                border: pw.TableBorder.all(color: darkText, width: 0.6),
                columnWidths: {
                  0: const pw.FlexColumnWidth(2.6),
                  1: const pw.FlexColumnWidth(2.8),
                  2: const pw.FlexColumnWidth(3.2),
                  3: const pw.FlexColumnWidth(2.8),
                },
                children: [
                  pw.TableRow(
                    children: [
                      pw.Container(
                        padding: const pw.EdgeInsets.all(3),
                        child: pw.Text('1) Applicants Name\n(IN BLOCK LETTERS)', style: pw.TextStyle(fontSize: 6.8, fontWeight: pw.FontWeight.bold)),
                      ),
                      pw.Container(
                        padding: const pw.EdgeInsets.all(3),
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text('First name', style: const pw.TextStyle(fontSize: 6.5, color: mutedText)),
                            pw.Text(app.newFirstName.toUpperCase(), style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold)),
                          ],
                        ),
                      ),
                      pw.Container(
                        padding: const pw.EdgeInsets.all(3),
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text('Name of Father/Husband', style: const pw.TextStyle(fontSize: 6.5, color: mutedText)),
                            pw.Text(app.newFatherOrHusbandName.toUpperCase(), style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold)),
                          ],
                        ),
                      ),
                      pw.Container(
                        padding: const pw.EdgeInsets.all(3),
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text('Surname', style: const pw.TextStyle(fontSize: 6.5, color: mutedText)),
                            pw.Text(app.newSurname.toUpperCase(), style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  pw.TableRow(
                    children: [
                      pw.Container(
                        padding: const pw.EdgeInsets.all(3),
                        child: pw.Text('2) Email Id:', style: const pw.TextStyle(fontSize: 7)),
                      ),
                      pw.Container(
                        padding: const pw.EdgeInsets.all(3),
                        child: pw.Text(app.newEmail.isNotEmpty ? app.newEmail : '—', style: const pw.TextStyle(fontSize: 7)),
                      ),
                      pw.Container(
                        padding: const pw.EdgeInsets.all(3),
                        child: pw.Text('(Phone No): ${app.newPhoneNo.isNotEmpty ? app.newPhoneNo : "—"}', style: const pw.TextStyle(fontSize: 7)),
                      ),
                      pw.Container(
                        padding: const pw.EdgeInsets.all(3),
                        child: pw.Text('(Mobile No): ${app.newMobileNo}', style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold)),
                      ),
                    ],
                  ),
                  pw.TableRow(
                    children: [
                      pw.Container(
                        padding: const pw.EdgeInsets.all(3),
                        child: pw.Text('3) Aadhar Card No.(Optional):', style: const pw.TextStyle(fontSize: 6.8)),
                      ),
                      pw.Container(
                        padding: const pw.EdgeInsets.all(3),
                        child: pw.Text(app.newAadhaarNo.isNotEmpty ? app.newAadhaarNo : '—', style: const pw.TextStyle(fontSize: 7.5)),
                      ),
                      pw.Container(padding: const pw.EdgeInsets.all(3), child: pw.Text('Property Address:', style: const pw.TextStyle(fontSize: 6.5, color: mutedText))),
                      pw.Container(padding: const pw.EdgeInsets.all(3), child: pw.Text(app.propertyAddress, style: const pw.TextStyle(fontSize: 7))),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 5),

              // 3) Reason for Change of Name
              pw.RichText(
                text: pw.TextSpan(
                  children: [
                    pw.TextSpan(
                      text: '3) Reason for Change of Name : ',
                      style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: mahavitaranRed),
                    ),
                    pw.TextSpan(
                      text: '${app.reasonForChange} ${app.remarks.isNotEmpty ? "(${app.remarks})" : ""}',
                      style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: darkText),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 3),

              // 4) Document enclosed
              pw.RichText(
                text: pw.TextSpan(
                  children: [
                    pw.TextSpan(
                      text: '4) Document enclosed (Please specify ) ',
                      style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: mahavitaranRed),
                    ),
                    pw.TextSpan(
                      text: app.documents.where((d) => d.isReceived).isNotEmpty
                          ? app.documents.where((d) => d.isReceived).map((d) => d.docType).join(', ')
                          : 'Ownership Document, 7/12 Extract, ₹100 Stamp Paper Affidavit',
                      style: const pw.TextStyle(fontSize: 7.5, color: darkText),
                    ),
                    pw.TextSpan(
                      text: '  (Please see Annexure "A")',
                      style: const pw.TextStyle(fontSize: 7.5, color: darkText),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 4),

              // Notes
              pw.Container(
                padding: const pw.EdgeInsets.all(4),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'Note: 1. For transfer of Security Deposit, old consumer should give consent, in absence of such consent incoming consumer will pay security deposit.',
                      style: const pw.TextStyle(fontSize: 6.6),
                    ),
                    pw.Text(
                      '         2. If old consumer wants refund of Security Deposit then fill up form "X".',
                      style: const pw.TextStyle(fontSize: 6.6),
                    ),
                    pw.Text(
                      '         3. In case of arrears, this application will not be processed and intimation will be sent to new consumer.',
                      style: const pw.TextStyle(fontSize: 6.6),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 2),

              // Declaration
              pw.Text(
                'Declaration:',
                style: pw.TextStyle(fontSize: 7.8, fontWeight: pw.FontWeight.bold, color: mahavitaranRed),
              ),
              pw.Container(
                padding: const pw.EdgeInsets.all(4),
                decoration: pw.BoxDecoration(border: pw.Border.all(color: borderColor, width: 0.5), color: lightBg),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('I hereby declare that', style: const pw.TextStyle(fontSize: 6.6)),
                    pw.Text(
                      'I will abide by the provisions of Electricity Act 2003 and Maharashtra Electricity Regulatory Commission (Electricity Supply Code and other conditions of Supply) Regulation 2005. I will further abide by rules & regulations issued by regulatory bodies & MSEDCL from time to time. I will pay the electricity bill as per prevailing MSEDCL Tariff. If the premises is declared unauthorized then at the time of vacation by competent authority, MSEDCL will have liberty to remove the electric connection immediately.',
                      style: const pw.TextStyle(fontSize: 6.3, height: 1.2),
                    ),
                    pw.SizedBox(height: 1),
                    pw.Text(
                      'The above information is true and if any false information is observed, I / we will be responsible for the consequence thereof.',
                      style: const pw.TextStyle(fontSize: 6.3, height: 1.2),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 3),

              pw.Text(
                'Note: You can upload signed copy of this form & relevant document for change of name, on MSEDCL website OR by using Mobile App.',
                style: pw.TextStyle(fontSize: 6.5, fontWeight: pw.FontWeight.bold, color: mahavitaranRed),
              ),
              pw.SizedBox(height: 4),

              // Signature of Applicant Section
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.end,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      if (app.hasNewConsumerSignature)
                        pw.Container(
                          height: 32,
                          child: pw.Image(pw.MemoryImage(app.newConsumerSignatureBytes!), height: 30, fit: pw.BoxFit.contain),
                        )
                      else
                        pw.SizedBox(height: 32),
                      pw.Container(width: 140, height: 0.8, color: darkText),
                      pw.SizedBox(height: 2),
                      pw.Text(
                        'Signature of Applicant',
                        style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: primaryBlue),
                      ),
                      pw.Text(
                        '(${app.computedNewFullName})',
                        style: const pw.TextStyle(fontSize: 6.8, color: mutedText),
                      ),
                    ],
                  ),
                ],
              ),
              pw.Spacer(),

              // Scissor cut line
              pw.Row(
                children: [
                  pw.Expanded(
                    child: pw.Text(
                      '- - - - - - - - - - - - - - - - - - - - - - - - - [ Cut Here ] - - - - - - - - - - - - - - - - - - - - - - - - -',
                      style: pw.TextStyle(fontSize: 7, color: mahavitaranRed, fontWeight: pw.FontWeight.bold),
                      textAlign: pw.TextAlign.center,
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 2),

              // Acknowledgement Receipt (Office Use Box)
              pw.Container(
                height: 52,
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: darkText, width: 0.7),
                ),
                child: pw.Row(
                  children: [
                    // Red Vertical Banner
                    pw.Container(
                      width: 18,
                      color: mahavitaranRed,
                      alignment: pw.Alignment.center,
                      child: pw.Text(
                        'For Office Use',
                        style: pw.TextStyle(fontSize: 6.5, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
                        textAlign: pw.TextAlign.center,
                      ),
                    ),
                    // Details
                    pw.Expanded(
                      flex: 4,
                      child: pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          mainAxisAlignment: pw.MainAxisAlignment.center,
                          children: [
                            pw.Text('Application No.: ________________________', style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold)),
                            pw.Text('Applicant Name: ________________________', style: const pw.TextStyle(fontSize: 6.8)),
                            pw.Text('Application Received Date: ____________', style: const pw.TextStyle(fontSize: 6.8)),
                          ],
                        ),
                      ),
                    ),
                    // Middle
                    pw.Expanded(
                      flex: 3,
                      child: pw.Column(
                        mainAxisAlignment: pw.MainAxisAlignment.center,
                        children: [
                          pw.Text('Acknowledgement Receipt', style: pw.TextStyle(fontSize: 7.2, fontWeight: pw.FontWeight.bold, color: primaryBlue)),
                          pw.Text('MAHAVITARAN', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: mahavitaranRed)),
                        ],
                      ),
                    ),
                    // Right Stamp
                    pw.Expanded(
                      flex: 4,
                      child: pw.Column(
                        mainAxisAlignment: pw.MainAxisAlignment.center,
                        children: [
                          pw.Text('Signature & Office Stamp', style: pw.TextStyle(fontSize: 6.8, fontWeight: pw.FontWeight.bold, color: mahavitaranRed)),
                          pw.Text('(Representative MSEDCL)', style: const pw.TextStyle(fontSize: 6.2, color: mutedText)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );

    // -------------------------------------------------------------
    // PAGE 2: OFFICIAL ANNEXURE "A" & FORM "X"
    // -------------------------------------------------------------
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 28, vertical: 24),
        theme: pdfTheme,
        build: (context) {
          final isOccupancyTicked = app.documents.any((d) => d.isReceived && d.docType.toLowerCase().contains('occupancy'));
          final isOwnershipTicked = app.documents.any((d) => d.isReceived && (d.docType.contains('7/12') || d.docType.contains('Form 8') || d.docType.toLowerCase().contains('ownership') || d.docType.toLowerCase().contains('tax')));
          final isLegalDocTicked = app.documents.any((d) => d.isReceived && (d.docType.toLowerCase().contains('inheritance') || d.docType.toLowerCase().contains('succession') || d.docType.toLowerCase().contains('will') || d.docType.toLowerCase().contains('gift')));
          final isIncorporationTicked = app.documents.any((d) => d.isReceived && d.docType.toLowerCase().contains('incorporation'));
          final isAffidavitTicked = app.documents.any((d) => d.isReceived && (d.docType.toLowerCase().contains('affidavit') || d.docType.toLowerCase().contains('gazette')));
          final isNocTicked = app.documents.any((d) => d.isReceived && (d.docType.toLowerCase().contains('noc') || d.docType.toLowerCase().contains('lease')));

          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              // Annexure "A" Title
              pw.Center(
                child: pw.Text(
                  'Annexure "A"',
                  style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: darkText),
                ),
              ),
              pw.SizedBox(height: 6),

              pw.Text(
                'Document required (please tick):',
                style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: mahavitaranRed),
              ),
              pw.SizedBox(height: 3),

              // Checklist Box
              pw.Container(
                padding: const pw.EdgeInsets.all(8),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: darkText, width: 0.8),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'Any one of the relevant document:-',
                      style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: mahavitaranRed),
                    ),
                    pw.SizedBox(height: 6),
                    _buildChecklistRow(isOccupancyTicked, 'a. Occupancy Certificate issued by statutory body / Competent Authority.'),
                    _buildChecklistRow(isOwnershipTicked || (!isOccupancyTicked && !isLegalDocTicked), 'b. Ownership Document/form 8 / Form 7-12 / tax / lease issued by Local Authority'),
                    _buildChecklistRow(isLegalDocTicked, 'c. Certified copy of Corresponding Legal Document (In case of inheritance / succession / will/ Gift Deed)'),
                    _buildChecklistRow(isIncorporationTicked, 'd. Certificate of Incorporation issued as per provision of companies Act 1956.'),
                    _buildChecklistRow(isAffidavitTicked || true, 'e. Affidavit / Gazette Notification for himself (In case applicant himself has changed his name)'),
                    _buildChecklistRow(isNocTicked, 'f. Legal document supporting letting and NOC of the owner. (In case of premises is let out to the applicant)'),
                  ],
                ),
              ),
              pw.SizedBox(height: 16),

              // Divider
              pw.Text(
                '-------------------------------------------------------------------------------------------------------------------------',
                style: const pw.TextStyle(fontSize: 8, color: borderColor),
                textAlign: pw.TextAlign.center,
              ),
              pw.SizedBox(height: 14),

              // FORM "X" Title
              pw.Center(
                child: pw.Text(
                  'FORM "X"',
                  style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: darkText),
                ),
              ),
              pw.SizedBox(height: 10),

              // a) Transfer of Security Deposit
              pw.Text(
                'a) Transfer of Security Deposit',
                style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: mahavitaranRed),
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                'I, Shri / Smt. / M/s. ${app.computedOldFullName}, hereby give consent for transfer of Security Deposit held against my consumer no. ${app.consumerNo} in the name of transferee Shri / Smt./ /M/s. ${app.computedNewFullName}.',
                style: const pw.TextStyle(fontSize: 8.5, height: 1.35),
              ),
              pw.SizedBox(height: 4),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.end,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      if (app.isFormXTransfer && app.hasOldConsumerSignature)
                        pw.Container(
                          height: 30,
                          child: pw.Image(pw.MemoryImage(app.oldConsumerSignatureBytes!), height: 28, fit: pw.BoxFit.contain),
                        )
                      else
                        pw.SizedBox(height: 30),
                      pw.Container(width: 150, height: 0.8, color: mahavitaranRed),
                      pw.SizedBox(height: 2),
                      pw.Text(
                        'Signature of Old Consumer',
                        style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: mahavitaranRed),
                      ),
                      pw.Text('(${app.computedOldFullName})', style: const pw.TextStyle(fontSize: 6.8, color: mutedText)),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 14),

              // OR
              pw.Center(
                child: pw.Text(
                  'OR',
                  style: pw.TextStyle(fontSize: 10.5, fontWeight: pw.FontWeight.bold, color: darkText),
                ),
              ),
              pw.SizedBox(height: 10),

              // b) Refund of Security Deposit
              pw.Text(
                'b) Refund of Security Deposit',
                style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: mahavitaranRed),
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                'I, Shri / Smt. / M/s. ${app.refundAccountHolderName.isNotEmpty ? app.refundAccountHolderName : app.computedOldFullName}, hereby give consent to transfer the connection in the name of transferee Shri / Smt. /M/s. ${app.computedNewFullName}. I request to refund the security deposit held against my consumer no. ${app.consumerNo} to me. For refund of security deposit Original Receipt is enclosed. OR my Original Receipt of S.D. is lost, I am enclosing indemnity bond. The Account details for ECS are as below.',
                style: const pw.TextStyle(fontSize: 8.5, height: 1.35),
              ),
              pw.SizedBox(height: 4),
              pw.Padding(
                padding: const pw.EdgeInsets.only(left: 14),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('- Name of Account Holder: ${app.refundAccountHolderName.isNotEmpty ? app.refundAccountHolderName : app.computedOldFullName}', style: const pw.TextStyle(fontSize: 8)),
                    pw.Text('- Name of Bank & Branch: ${app.refundBankName.isNotEmpty ? app.refundBankName : "________________"} ${app.refundBranch.isNotEmpty ? "(${app.refundBranch})" : ""}', style: const pw.TextStyle(fontSize: 8)),
                    pw.Text('- Bank A/c no.: ${app.refundAccountNumber.isNotEmpty ? app.refundAccountNumber : "________________________"}', style: const pw.TextStyle(fontSize: 8)),
                    pw.Text('- IFSC no.: ${app.refundIfscCode.isNotEmpty ? app.refundIfscCode : "________________________"}', style: const pw.TextStyle(fontSize: 8)),
                    pw.Text('- Original Receipt no..: ${app.originalReceiptNo.isNotEmpty ? app.originalReceiptNo : "________________________"}', style: const pw.TextStyle(fontSize: 8)),
                  ],
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.end,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      if (!app.isFormXTransfer && app.hasOldConsumerSignature)
                        pw.Container(
                          height: 30,
                          child: pw.Image(pw.MemoryImage(app.oldConsumerSignatureBytes!), height: 28, fit: pw.BoxFit.contain),
                        )
                      else
                        pw.SizedBox(height: 30),
                      pw.Container(width: 150, height: 0.8, color: mahavitaranRed),
                      pw.SizedBox(height: 2),
                      pw.Text(
                        'Signature of Old Consumer',
                        style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: mahavitaranRed),
                      ),
                      pw.Text('(${app.computedOldFullName})', style: const pw.TextStyle(fontSize: 6.8, color: mutedText)),
                    ],
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  static pw.Widget _buildChecklistRow(bool isChecked, String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Container(
            width: 10,
            height: 10,
            decoration: pw.BoxDecoration(border: pw.Border.all(color: darkText, width: 0.8)),
            alignment: pw.Alignment.center,
            child: isChecked ? pw.Text('X', style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: primaryBlue)) : null,
          ),
          pw.SizedBox(width: 6),
          pw.Expanded(
            child: pw.Text(
              text,
              style: pw.TextStyle(
                fontSize: 7.8,
                fontWeight: isChecked ? pw.FontWeight.bold : pw.FontWeight.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // 2. STAMP PAPER AFFIDAVIT / UNDERTAKING PDF
  // ==========================================

  /// Generate Editable Stamp Paper Affidavit / Undertaking for the NEW CUSTOMER
  static Future<Uint8List> generateAffidavitPdf(MsedclChangeOfNameApplication app) async {
    final pdf = pw.Document(
      title: 'MSEDCL Affidavit - ${app.computedNewFullName}',
      author: 'Siya Infotech & Solar Energy',
    );

    final pdfTheme = await SolarQuotationFontHelper.loadPdfTheme();

    final isMarathi = app.stampPaperLanguage.toLowerCase() == 'marathi';

    pdf.addPage(
      pw.Page(
        pageFormat: const PdfPageFormat(612.0, 792.0), // Match exact US Letter dimensions of official MSEDCL form
        margin: const pw.EdgeInsets.symmetric(horizontal: 26, vertical: 18),
        theme: pdfTheme,
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              // Top Margin gap for physical non-judicial stamp paper if configured
              if (app.stampTopMarginMm > 0)
                pw.SizedBox(height: app.stampTopMarginMm * 2.83465) // 1mm = 2.83465 pt
              else ...[
                // Simulated Stamp Paper Header when printed on plain paper
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 10),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: const PdfColor.fromInt(0xFF854D0E), width: 1.2),
                    color: const PdfColor.fromInt(0xFFFEFCE8),
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(5)),
                  ),
                  child: pw.Column(
                    children: [
                      pw.Text(
                        'GOVERNMENT OF MAHARASHTRA | NON-JUDICIAL STAMP PAPER',
                        style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: const PdfColor.fromInt(0xFF854D0E)),
                        textAlign: pw.TextAlign.center,
                      ),
                      pw.SizedBox(height: 1),
                      pw.Text(
                        'महाराष्ट्र शासन | मुद्रांक शुल्क मूल्य: रु. ${app.stampPaperValue.toInt()}/- (रुपये ${app.stampPaperValue.toInt()} फक्त)',
                        style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: const PdfColor.fromInt(0xFF854D0E)),
                        textAlign: pw.TextAlign.center,
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(height: 8),
              ],

              // Affidavit Title
              pw.Text(
                isMarathi ? '।। प्रतिज्ञापत्र / हमीपत्र ।।' : 'AFFIDAVIT / UNDERTAKING',
                style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: primaryBlue),
                textAlign: pw.TextAlign.center,
              ),
              pw.Text(
                isMarathi
                    ? '(महाराष्ट्र राज्य विद्युत वितरण कंपनी मर्यादित - वीज ग्राहक नाव बदल कामी)'
                    : '(For Change of Name in MSEDCL Electricity Connection)',
                style: const pw.TextStyle(fontSize: 8.5, color: mutedText),
                textAlign: pw.TextAlign.center,
              ),
              pw.SizedBox(height: 8),

              // Deponent / Applicant Details
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: pw.BoxDecoration(border: pw.Border.all(color: borderColor, width: 0.8), color: lightBg),
                child: isMarathi
                    ? pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            'मी खालीलप्रमाणे सत्य प्रतिज्ञेवर लिहून देतो / देते की —',
                            style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
                          ),
                          pw.SizedBox(height: 3),
                          pw.Text(
                            'अर्जदार / नवीन ग्राहक: ${app.computedNewFullName}, वय: ${app.newAge} वर्षे, व्यवसाय: शेती/व्यवसाय/नोकरी, '
                            'रा. ${app.propertyAddress}. '
                            'आधार क्र.: ${app.newAadhaarNo.isNotEmpty ? app.newAadhaarNo : "लागू नाही"}.',
                            style: const pw.TextStyle(fontSize: 8, height: 1.3),
                          ),
                        ],
                      )
                    : pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            'I, the undersigned deponent, do hereby solemnly affirm and state on oath as under:',
                            style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
                          ),
                          pw.SizedBox(height: 3),
                          pw.Text(
                            'Applicant / Transferee: ${app.computedNewFullName}, Age: ${app.newAge} Years, '
                            'Residing at: ${app.propertyAddress}. '
                            'Aadhaar No: ${app.newAadhaarNo.isNotEmpty ? app.newAadhaarNo : "N/A"}.',
                            style: const pw.TextStyle(fontSize: 8, height: 1.3),
                          ),
                        ],
                      ),
              ),
              pw.SizedBox(height: 8),

              // Custom or Standard Affidavit Body
              if (app.affidavitCustomText != null && app.affidavitCustomText!.trim().isNotEmpty)
                pw.Container(
                  padding: const pw.EdgeInsets.all(6),
                  child: pw.Text(
                    app.affidavitCustomText!,
                    style: const pw.TextStyle(fontSize: 8, height: 1.3),
                  ),
                )
              else if (isMarathi) ...[
                _buildClauseText('१.', 'सदर मिळकतीवर महावितरणचा वीज ग्राहक क्रमांक ${app.consumerNo} हा असून तो सध्या जुने ग्राहक ${app.computedOldFullName} यांच्या नावावर नोंदणीकृत आहे.'),
                _buildClauseText('२.', 'मी सदर मिळकत / जागा (${app.propertyAddress}) ही कायदेशीररित्या (${app.reasonForChange}) अन्वये प्राप्त केली असून सध्या सदर जागेचा संपूर्ण कायदेशीर ताबा व मालकी हक्क माझ्याकडे आहे.'),
                _buildClauseText('३.', 'सदर जागेवरील वीज मीटर ग्राहक क्र. ${app.consumerNo} हे माझ्या नावाने (${app.computedNewFullName}) हस्तांतरित / नाव बदल करून मिळण्यासाठी मी हा अर्ज सादर करत आहे.'),
                _buildClauseText('४.', 'सदर वीज जोडणी माझ्या नावावर झाल्यानंतर भविष्यात येणारे सर्व वीज देयक (Bills) नियमाप्रमाणे विहित मुदतीत भरण्याची संपूर्ण जबाबदारी माझी राहील.'),
                _buildClauseText('५.', 'सदर वीज जोडणीवर जुनी थकबाकी किंवा कायदेशीर देणी असल्यास, ती महावितरणच्या नियमानुसार भरण्यास मी वैयक्तिकरीत्या बांधील व सहमत आहे.'),
                _buildClauseText('६.', 'सदर नाव बदलाबाबत भविष्यात कोणताही वाद किंवा आक्षेप उद्भवल्यास त्याची संपूर्ण जबाबदारी माझी राहील. मी सादर केलेली सर्व कागदपत्रे व माहिती खरी व कायदेशीर आहे.'),
              ] else ...[
                _buildClauseText('1.', 'That the existing electricity connection bearing Consumer No. ${app.consumerNo} currently stands registered in the name of the previous consumer, ${app.computedOldFullName}.'),
                _buildClauseText('2.', 'That I am the rightful owner / legal occupier in lawful possession of the premises situated at ${app.propertyAddress} by virtue of ${app.reasonForChange}.'),
                _buildClauseText('3.', 'That I have applied to MSEDCL (${app.subDivisionOffice}) for transferring the said electricity connection to my name (${app.computedNewFullName}).'),
                _buildClauseText('4.', 'That I undertake to pay all future electricity consumption bills promptly without default as and when billed by MSEDCL.'),
                _buildClauseText('5.', 'That if any legitimate past arrears or dues are found pending against Consumer No. ${app.consumerNo}, I undertake to clear the same in accordance with MSEDCL rules.'),
                _buildClauseText('6.', 'That all statements made herein and documents submitted are true, correct, and legally valid. I hereby indemnify MSEDCL against any third-party claims or disputes.'),
              ],

              pw.SizedBox(height: 8),
              pw.Text(
                isMarathi
                    ? 'करिता हे प्रतिज्ञापत्र / हमीपत्र मी स्वतःच्या राजीखुशीने, कोणत्याही दबावाशिवाय लिहून सही केली आहे. जेणेकरून महावितरण कार्यालयात पुरावा म्हणून सादर करता येईल.'
                    : 'Solemnly affirmed and signed on this day with sound mind and free will, without any coercion or undue influence.',
                style: pw.TextStyle(fontSize: 7.5, fontStyle: isMarathi ? pw.FontStyle.normal : pw.FontStyle.italic),
              ),
              pw.SizedBox(height: 12),

              // Date, Place & Applicant Signature
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(isMarathi ? 'दिनांक: ${_dateFormat.format(app.applicationDate)}' : 'Date: ${_dateFormat.format(app.applicationDate)}', style: const pw.TextStyle(fontSize: 8)),
                      pw.Text(isMarathi ? 'ठिकाण: ${app.affidavitPlace}' : 'Place: ${app.affidavitPlace}', style: const pw.TextStyle(fontSize: 8)),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      if (app.hasNewConsumerSignature)
                        pw.Container(
                          height: 32,
                          child: pw.Image(pw.MemoryImage(app.newConsumerSignatureBytes!), height: 30, fit: pw.BoxFit.contain),
                        )
                      else
                        pw.SizedBox(height: 32),
                      pw.Container(width: 140, height: 0.8, color: darkText),
                      pw.SizedBox(height: 3),
                      pw.Text(
                        isMarathi ? 'प्रतिज्ञापत्र देणारा / अर्जदार (सही)' : 'Signature of Deponent / Applicant',
                        style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
                      ),
                      pw.Text('(${app.computedNewFullName})', style: const pw.TextStyle(fontSize: 7.5, color: mutedText)),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 10),

              // Blank Notary / Attestation Block (Left strictly blank for physical attestation)
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: pw.BoxDecoration(border: pw.Border.all(color: borderColor, width: 0.8)),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('BEFORE ME', style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold)),
                        pw.SizedBox(height: 12),
                        pw.Text('Notary Public / Executive Magistrate', style: const pw.TextStyle(fontSize: 7)),
                        pw.Text('(Affix Notary Stamp & Seal here)', style: const pw.TextStyle(fontSize: 6.5, color: mutedText)),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text('IDENTIFIED BY', style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold)),
                        pw.SizedBox(height: 12),
                        pw.Text('Advocate / Witness Signature', style: const pw.TextStyle(fontSize: 7)),
                        pw.Text('Name: ______________________', style: const pw.TextStyle(fontSize: 6.5, color: mutedText)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  // ==========================================
  // 3. FORM X (SECURITY DEPOSIT) PDF
  // ==========================================

  /// Generate MSEDCL Form X PDF (Transfer or Refund of Security Deposit)
  static Future<Uint8List> generateFormXPdf(MsedclChangeOfNameApplication app) async {
    final pdf = pw.Document(
      title: 'MSEDCL Form X - ${app.consumerNo}',
      author: 'Siya Infotech & Solar Energy',
    );

    final pdfTheme = await SolarQuotationFontHelper.loadPdfTheme();

    final isTransfer = app.isFormXTransfer;

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        theme: pdfTheme,
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              // Header
              pw.Container(
                padding: const pw.EdgeInsets.all(8),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: primaryBlue, width: 1.5),
                  color: lightBg,
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                ),
                child: pw.Column(
                  children: [
                    pw.Text(
                      'MAHARASHTRA STATE ELECTRICITY DISTRIBUTION CO. LTD.',
                      style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: primaryBlue),
                      textAlign: pw.TextAlign.center,
                    ),
                    pw.SizedBox(height: 2),
                    pw.Text(
                      'FORM "X" — SECURITY DEPOSIT CONSENT / APPLICATION',
                      style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: darkText),
                      textAlign: pw.TextAlign.center,
                    ),
                    pw.Text(
                      isTransfer
                          ? '(Consent for Transfer of Security Deposit to New Consumer)'
                          : '(Application for Refund of Security Deposit via ECS/NEFT)',
                      style: const pw.TextStyle(fontSize: 8, color: mutedText),
                      textAlign: pw.TextAlign.center,
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 12),

              // To Officer
              pw.Text('To,', style: const pw.TextStyle(fontSize: 9)),
              pw.Text('The Assistant Engineer / Junior Engineer,', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
              pw.Text('MSEDCL, ${app.subDivisionOffice}.', style: const pw.TextStyle(fontSize: 9)),
              pw.SizedBox(height: 10),

              // Consumer Details
              pw.Table(
                border: pw.TableBorder.all(color: borderColor, width: 0.5),
                children: [
                  _tableRow(['Consumer Number', app.consumerNo, 'Sub-Division', app.subDivisionOffice]),
                  _tableRow(['Old Consumer (Transferor)', app.computedOldFullName, 'New Consumer (Transferee)', app.computedNewFullName]),
                  _tableRow(['Premises Address', app.propertyAddress, 'Date', _dateFormat.format(app.applicationDate)]),
                ],
              ),
              pw.SizedBox(height: 12),

              if (isTransfer) ...[
                // OPTION A: TRANSFER OF SECURITY DEPOSIT
                _buildSectionHeader('OPTION A: CONSENT TO TRANSFER SECURITY DEPOSIT'),
                pw.Container(
                  padding: const pw.EdgeInsets.all(10),
                  decoration: pw.BoxDecoration(border: pw.Border.all(color: borderColor, width: 0.8), color: lightBg),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'I, ${app.computedOldFullName}, the existing registered consumer for electricity connection No. ${app.consumerNo}, '
                        'hereby state that I have transferred / handed over the possession of the premises to ${app.computedNewFullName}.',
                        style: const pw.TextStyle(fontSize: 8.5, height: 1.4),
                      ),
                      pw.SizedBox(height: 6),
                      pw.Text(
                        'I hereby give my free consent and authorize MSEDCL to transfer the entire Security Deposit amount '
                        'currently standing to the credit of my Consumer No. ${app.consumerNo} to the new consumer, ${app.computedNewFullName}. '
                        'I confirm that I shall have no claim whatsoever on the said security deposit in future.',
                        style: pw.TextStyle(fontSize: 8.5, height: 1.4, fontWeight: pw.FontWeight.bold),
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(height: 30),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        if (app.hasOldConsumerSignature)
                          pw.Container(
                            height: 34,
                            child: pw.Image(pw.MemoryImage(app.oldConsumerSignatureBytes!), height: 32, fit: pw.BoxFit.contain),
                          )
                        else
                          pw.SizedBox(height: 34),
                        pw.Container(width: 150, height: 1, color: darkText),
                        pw.SizedBox(height: 4),
                        pw.Text('Signature of Old Consumer (Transferor)', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                        pw.Text('Name: ${app.computedOldFullName}', style: const pw.TextStyle(fontSize: 7.5, color: mutedText)),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        if (app.hasNewConsumerSignature)
                          pw.Container(
                            height: 34,
                            child: pw.Image(pw.MemoryImage(app.newConsumerSignatureBytes!), height: 32, fit: pw.BoxFit.contain),
                          )
                        else
                          pw.SizedBox(height: 34),
                        pw.Container(width: 150, height: 1, color: darkText),
                        pw.SizedBox(height: 4),
                        pw.Text('Signature of New Consumer (Acceptor)', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                        pw.Text('Name: ${app.computedNewFullName}', style: const pw.TextStyle(fontSize: 7.5, color: mutedText)),
                      ],
                    ),
                  ],
                ),
              ] else ...[
                // OPTION B: REFUND OF SECURITY DEPOSIT
                _buildSectionHeader('OPTION B: APPLICATION FOR REFUND OF SECURITY DEPOSIT'),
                pw.Container(
                  padding: const pw.EdgeInsets.all(10),
                  decoration: pw.BoxDecoration(border: pw.Border.all(color: borderColor, width: 0.8), color: lightBg),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'I, ${app.refundAccountHolderName.isNotEmpty ? app.refundAccountHolderName : app.computedOldFullName}, '
                        'hereby request MSEDCL to refund the Security Deposit standing against Consumer No. ${app.consumerNo} '
                        'via direct bank transfer (ECS / NEFT) to my bank account specified below:',
                        style: const pw.TextStyle(fontSize: 8.5, height: 1.4),
                      ),
                      pw.SizedBox(height: 8),
                      pw.Table(
                        border: pw.TableBorder.all(color: borderColor, width: 0.5),
                        children: [
                          _tableRow(['Bank Account Holder', app.refundAccountHolderName.isNotEmpty ? app.refundAccountHolderName : app.computedOldFullName, 'Bank Name', app.refundBankName]),
                          _tableRow(['Bank Account Number', app.refundAccountNumber, 'IFSC Code', app.refundIfscCode]),
                          _tableRow(['Branch', app.refundBranch, 'SD Receipt No.', app.originalReceiptNo.isNotEmpty ? app.originalReceiptNo : 'As per MSEDCL Ledger']),
                          _tableRow(['Original Receipt Status', app.receiptStatus, 'Indemnity Bond Attached', app.receiptStatus == 'Lost' ? 'Yes (Enclosed)' : 'Not Required']),
                        ],
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(height: 30),
                pw.Align(
                  alignment: pw.Alignment.centerRight,
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      if (app.hasOldConsumerSignature)
                        pw.Container(
                          height: 34,
                          child: pw.Image(pw.MemoryImage(app.oldConsumerSignatureBytes!), height: 32, fit: pw.BoxFit.contain),
                        )
                      else
                        pw.SizedBox(height: 34),
                      pw.Container(width: 160, height: 1, color: darkText),
                      pw.SizedBox(height: 4),
                      pw.Text('Signature of Previous Consumer (Claimant)', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                      pw.Text('Name: ${app.refundAccountHolderName.isNotEmpty ? app.refundAccountHolderName : app.computedOldFullName}', style: const pw.TextStyle(fontSize: 7.5, color: mutedText)),
                    ],
                  ),
                ),
              ],

              pw.Spacer(),
              // Office verification
              _buildSectionHeader('FOR MSEDCL ACCOUNTS & CASH OFFICE USE'),
              pw.Table(
                border: pw.TableBorder.all(color: borderColor, width: 0.5),
                children: [
                  _tableRow(['Deposit Amount Verified (₹)', '', 'Receipt Book/Page No.', '']),
                  _tableRow(['Audited by Accountant', '', 'Approved by Executive Engineer', '']),
                ],
              ),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  // ==========================================
  // 4. DOCUMENT CHECKLIST (ANNEXURE A) PDF
  // ==========================================

  /// Generate Annexure A Document Checklist and Verification Summary PDF
  static Future<Uint8List> generateChecklistPdf(MsedclChangeOfNameApplication app) async {
    final pdf = pw.Document(
      title: 'Annexure A Checklist - ${app.consumerNo}',
      author: 'Siya Infotech & Solar Energy',
    );

    final pdfTheme = await SolarQuotationFontHelper.loadPdfTheme();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        theme: pdfTheme,
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              // Header
              pw.Container(
                padding: const pw.EdgeInsets.all(8),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: primaryBlue, width: 1.5),
                  color: lightBg,
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                ),
                child: pw.Column(
                  children: [
                    pw.Text(
                      'MAHARASHTRA STATE ELECTRICITY DISTRIBUTION CO. LTD.',
                      style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: primaryBlue),
                      textAlign: pw.TextAlign.center,
                    ),
                    pw.SizedBox(height: 2),
                    pw.Text(
                      'ANNEXURE "A" — DOCUMENT CHECKLIST & SCRUTINY SHEET',
                      style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: darkText),
                      textAlign: pw.TextAlign.center,
                    ),
                    pw.Text(
                      'Change of Name Verification & Document Compliance',
                      style: const pw.TextStyle(fontSize: 8, color: mutedText),
                      textAlign: pw.TextAlign.center,
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 10),

              // Application Info
              pw.Table(
                border: pw.TableBorder.all(color: borderColor, width: 0.5),
                children: [
                  _tableRow(['Application No.', app.applicationNo, 'Date', _dateFormat.format(app.applicationDate)]),
                  _tableRow(['Consumer Number', app.consumerNo, 'Sub-Division', app.subDivisionOffice]),
                  _tableRow(['Old Consumer Name', app.computedOldFullName, 'New Consumer Name', app.computedNewFullName]),
                  _tableRow(['Reason for Name Change', app.reasonForChange, 'Status', app.status]),
                ],
              ),
              pw.SizedBox(height: 10),

              _buildSectionHeader('ENCLOSED DOCUMENTS STATUS & COMPLIANCE SUMMARY'),
              pw.Table(
                border: pw.TableBorder.all(color: borderColor, width: 0.5),
                columnWidths: {
                  0: const pw.FlexColumnWidth(0.8),
                  1: const pw.FlexColumnWidth(3.8),
                  2: const pw.FlexColumnWidth(1.6),
                  3: const pw.FlexColumnWidth(3.0),
                },
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: lightBg),
                    children: [
                      _headerCell('Sr.'),
                      _headerCell('Document Description'),
                      _headerCell('Status'),
                      _headerCell('Notes / File Reference'),
                    ],
                  ),
                  ...List.generate(app.documents.length, (idx) {
                    final d = app.documents[idx];
                    final statusColor = d.isReceived
                        ? const PdfColor.fromInt(0xFF047857) // Green
                        : (d.isPending ? const PdfColor.fromInt(0xFFB45309) : mutedText);
                    return pw.TableRow(
                      children: [
                        pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('${idx + 1}', textAlign: pw.TextAlign.center, style: const pw.TextStyle(fontSize: 8))),
                        pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text(d.docType, style: pw.TextStyle(fontSize: 8, fontWeight: d.isReceived ? pw.FontWeight.bold : pw.FontWeight.normal))),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(5),
                          child: pw.Text(
                            d.status,
                            style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: statusColor),
                            textAlign: pw.TextAlign.center,
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(5),
                          child: pw.Text(
                            d.fileName != null ? '${d.fileName} (${d.notes ?? ""})' : (d.notes ?? '—'),
                            style: const pw.TextStyle(fontSize: 7.5),
                          ),
                        ),
                      ],
                    );
                  }),
                ],
              ),
              pw.SizedBox(height: 20),

              // Summary Counts
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                children: [
                  _statBadge('Received Documents', '${app.receivedDocCount} / ${app.applicableDocCount}', const PdfColor.fromInt(0xFFECFDF5), const PdfColor.fromInt(0xFF047857)),
                  _statBadge('Pending Documents', '${app.documents.where((d) => d.isPending).length}', const PdfColor.fromInt(0xFFFFFBEB), const PdfColor.fromInt(0xFFB45309)),
                  _statBadge('Not Applicable', '${app.documents.where((d) => d.isNotApplicable).length}', lightBg, mutedText),
                ],
              ),
              pw.Spacer(),

              // Verification signatures
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Container(width: 140, height: 1, color: darkText),
                      pw.SizedBox(height: 3),
                      pw.Text('Prepared / Verified by Staff', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                      pw.Text('Name: ${app.assignedEmployee}', style: const pw.TextStyle(fontSize: 7.5, color: mutedText)),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Container(width: 140, height: 1, color: darkText),
                      pw.SizedBox(height: 3),
                      pw.Text('Applicant Acknowledgment (Signature)', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                      pw.Text('Name: ${app.computedNewFullName}', style: const pw.TextStyle(fontSize: 7.5, color: mutedText)),
                    ],
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  // ==========================================
  // 5. COMPLETE APPLICATION COMBINED PDF
  // ==========================================

  /// Combines all filled documents into one single upload-ready Master PDF
  static Future<Uint8List> generateCompleteApplicationPdf(
    MsedclChangeOfNameApplication app, {
    bool includeUForm = true,
    bool includeAffidavit = true,
    bool includeFormX = true,
    bool includeChecklist = true,
    bool includeAttachments = true,
  }) async {
    final templateBytes = await _loadTemplateBytes();
    if (templateBytes != null && templateBytes.isNotEmpty && includeUForm) {
      try {
        final uFormOverlayBytes = _generateUFormOverlayPdf(app, templateBytes);
        final masterDoc = sf.PdfDocument(inputBytes: uFormOverlayBytes);

        if (includeAffidavit) {
          final affidavitBytes = await generateAffidavitPdf(app);
          final affidavitDoc = sf.PdfDocument(inputBytes: affidavitBytes);
          for (int i = 0; i < affidavitDoc.pages.count; i++) {
            final template = affidavitDoc.pages[i].createTemplate();
            final newPage = masterDoc.pages.add();
            newPage.graphics.drawPdfTemplate(template, ui.Offset.zero);
          }
          affidavitDoc.dispose();
        }

        if (includeAttachments) {
          for (final doc in app.documents) {
            if (doc.isReceived && doc.fileBytes != null) {
              try {
                final attachBitmap = sf.PdfBitmap(doc.fileBytes!);
                final attachPage = masterDoc.pages.add();
                final pageSize = attachPage.getClientSize();
                attachPage.graphics.drawString(
                  'Enclosure: ${doc.docType}',
                  sf.PdfStandardFont(sf.PdfFontFamily.helvetica, 10, style: sf.PdfFontStyle.bold),
                  brush: sf.PdfSolidBrush(sf.PdfColor(15, 35, 90)),
                  bounds: ui.Rect.fromLTWH(20, 15, pageSize.width - 40, 20),
                );
                attachPage.graphics.drawImage(
                  attachBitmap,
                  ui.Rect.fromLTWH(20, 40, pageSize.width - 40, pageSize.height - 60),
                );
              } catch (_) {}
            }
          }
        }

        final outBytes = Uint8List.fromList(masterDoc.saveSync());
        masterDoc.dispose();
        return outBytes;
      } catch (e) {
        // ignore: avoid_print
        print('MsedclPdfService.generateCompleteApplicationPdf overlay fallback: $e');
      }
    }

    return _generateCompleteApplicationFallbackPdf(
      app,
      includeUForm: includeUForm,
      includeAffidavit: includeAffidavit,
      includeFormX: includeFormX,
      includeChecklist: includeChecklist,
      includeAttachments: includeAttachments,
    );
  }

  static Future<Uint8List> _generateCompleteApplicationFallbackPdf(
    MsedclChangeOfNameApplication app, {
    bool includeUForm = true,
    bool includeAffidavit = true,
    bool includeFormX = true,
    bool includeChecklist = true,
    bool includeAttachments = true,
  }) async {
    final pdf = pw.Document(
      title: 'MSEDCL Complete Application - ${app.consumerNo}',
      author: 'Siya Infotech & Solar Energy',
    );

    final pdfTheme = await SolarQuotationFontHelper.loadPdfTheme();

    // 1. U-Form Page
    if (includeUForm) {
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(28),
          theme: pdfTheme,
          build: (context) => _buildUFormContent(app),
        ),
      );
    }

    // 2. Affidavit Page
    if (includeAffidavit) {
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(28),
          theme: pdfTheme,
          build: (context) => _buildAffidavitContent(app),
        ),
      );
    }

    // 3. Form X Page
    if (includeFormX) {
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(28),
          theme: pdfTheme,
          build: (context) => _buildFormXContent(app),
        ),
      );
    }

    // 4. Checklist Page
    if (includeChecklist) {
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(28),
          theme: pdfTheme,
          build: (context) => _buildChecklistContent(app),
        ),
      );
    }

    // 5. Attached Document Pages (if image bytes are present)
    if (includeAttachments) {
      for (final doc in app.documents) {
        if (doc.isReceived && doc.fileBytes != null) {
          try {
            final image = pw.MemoryImage(doc.fileBytes!);
            pdf.addPage(
              pw.Page(
                pageFormat: PdfPageFormat.a4,
                margin: const pw.EdgeInsets.all(28),
                theme: pdfTheme,
                build: (context) {
                  return pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                    children: [
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                        color: lightBg,
                        child: pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Text('Enclosure: ${doc.docType}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
                            pw.Text('App No: ${app.applicationNo}', style: const pw.TextStyle(fontSize: 8, color: mutedText)),
                          ],
                        ),
                      ),
                      pw.SizedBox(height: 8),
                      pw.Expanded(
                        child: pw.Center(
                          child: pw.Image(image, fit: pw.BoxFit.contain),
                        ),
                      ),
                    ],
                  );
                },
              ),
            );
          } catch (_) {
            // If image fails to decode (e.g. unsupported format), skip gracefully
          }
        }
      }
    }

    return pdf.save();
  }

  // ==========================================
  // HELPER WIDGETS
  // ==========================================

  static pw.Widget _buildSectionHeader(String title) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 2),
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: const pw.BoxDecoration(color: primaryBlue),
      child: pw.Text(
        title,
        style: pw.TextStyle(color: PdfColors.white, fontSize: 8, fontWeight: pw.FontWeight.bold),
      ),
    );
  }

  static pw.TableRow _tableRow(List<String> cells) {
    return pw.TableRow(
      children: cells.asMap().entries.map((entry) {
        final isLabel = entry.key % 2 == 0;
        return pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 3),
          child: pw.Text(
            entry.value,
            style: pw.TextStyle(
              fontSize: 7.5,
              fontWeight: isLabel ? pw.FontWeight.bold : pw.FontWeight.normal,
              color: isLabel ? darkText : const PdfColor.fromInt(0xFF0F172A),
            ),
          ),
        );
      }).toList(),
    );
  }

  static pw.Widget _headerCell(String title) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(5),
      child: pw.Text(
        title,
        style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: primaryBlue),
        textAlign: pw.TextAlign.center,
      ),
    );
  }

  static pw.Widget _buildClauseText(String num, String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 5),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('$num ', style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold)),
          pw.Expanded(
            child: pw.Text(text, style: const pw.TextStyle(fontSize: 8.5, height: 1.35)),
          ),
        ],
      ),
    );
  }

  static pw.Widget _statBadge(String label, String value, PdfColor bg, PdfColor text) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: pw.BoxDecoration(
        color: bg,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
        border: pw.Border.all(color: text.flatten()),
      ),
      child: pw.Column(
        children: [
          pw.Text(value, style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: text)),
          pw.SizedBox(height: 2),
          pw.Text(label, style: pw.TextStyle(fontSize: 7.5, color: text)),
        ],
      ),
    );
  }

  // Content builders for combined document
  static pw.Widget _buildUFormContent(MsedclChangeOfNameApplication app) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        pw.Container(
          padding: const pw.EdgeInsets.all(6),
          color: lightBg,
          child: pw.Column(
            children: [
              pw.Text('MAHARASHTRA STATE ELECTRICITY DISTRIBUTION CO. LTD. — FORM "U"', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: primaryBlue), textAlign: pw.TextAlign.center),
              pw.Text('Application for Change of Name | Consumer No: ${app.consumerNo}', style: const pw.TextStyle(fontSize: 8, color: mutedText), textAlign: pw.TextAlign.center),
            ],
          ),
        ),
        pw.SizedBox(height: 6),
        _buildSectionHeader('1. OLD CONSUMER (TRANSFEROR)'),
        pw.Table(
          border: pw.TableBorder.all(color: borderColor, width: 0.5),
          children: [
            _tableRow(['Consumer No.', app.consumerNo, 'Meter No.', app.oldMeterNo.isNotEmpty ? app.oldMeterNo : 'As per bill']),
            _tableRow(['Transferor Name', app.computedOldFullName, 'Mobile', app.oldMobileNo.isNotEmpty ? app.oldMobileNo : '—']),
          ],
        ),
        pw.SizedBox(height: 6),
        _buildSectionHeader('2. NEW CONSUMER (APPLICANT)'),
        pw.Table(
          border: pw.TableBorder.all(color: borderColor, width: 0.5),
          children: [
            _tableRow(['Applicant Name', app.computedNewFullName, 'Age', '${app.newAge} Yrs']),
            _tableRow(['Mobile Number', app.newMobileNo, 'Aadhaar', app.newAadhaarNo.isNotEmpty ? app.newAadhaarNo : '—']),
            _tableRow(['Premises Address', app.propertyAddress, 'Sub-Division', app.subDivisionOffice]),
          ],
        ),
        pw.SizedBox(height: 6),
        _buildSectionHeader('3. REASON & UNDERTAKING'),
        pw.Text('Reason: ${app.reasonForChange}', style: const pw.TextStyle(fontSize: 8)),
        pw.SizedBox(height: 4),
        pw.Text('Declaration: I undertake to abide by MERC Regulations and pay all electricity bills promptly.', style: const pw.TextStyle(fontSize: 7.5, color: mutedText)),
        pw.Spacer(),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                if (app.hasOldConsumerSignature)
                  pw.Container(
                    height: 26,
                    child: pw.Image(pw.MemoryImage(app.oldConsumerSignatureBytes!), height: 24, fit: pw.BoxFit.contain),
                  )
                else
                  pw.SizedBox(height: 26),
                pw.Container(width: 140, height: 0.8, color: darkText),
                pw.SizedBox(height: 2),
                pw.Text('Transferor Signature', style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold)),
                pw.Text('(${app.computedOldFullName})', style: const pw.TextStyle(fontSize: 6.8, color: mutedText)),
              ],
            ),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                if (app.hasNewConsumerSignature)
                  pw.Container(
                    height: 26,
                    child: pw.Image(pw.MemoryImage(app.newConsumerSignatureBytes!), height: 24, fit: pw.BoxFit.contain),
                  )
                else
                  pw.SizedBox(height: 26),
                pw.Container(width: 140, height: 0.8, color: darkText),
                pw.SizedBox(height: 2),
                pw.Text('Applicant Signature', style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold)),
                pw.Text('(${app.computedNewFullName})', style: const pw.TextStyle(fontSize: 6.8, color: mutedText)),
              ],
            ),
          ],
        ),
      ],
    );
  }

  static pw.Widget _buildAffidavitContent(MsedclChangeOfNameApplication app) {
    final isMarathi = app.stampPaperLanguage.toLowerCase() == 'marathi';
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        pw.Text(
          isMarathi ? '।। प्रतिज्ञापत्र / हमीपत्र (AFFIDAVIT) ।।' : 'AFFIDAVIT / UNDERTAKING',
          style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: primaryBlue),
          textAlign: pw.TextAlign.center,
        ),
        pw.Text(
          'Value: Rs. ${app.stampPaperValue.toInt()} Stamp Paper | State: Maharashtra',
          style: const pw.TextStyle(fontSize: 8, color: mutedText),
          textAlign: pw.TextAlign.center,
        ),
        pw.SizedBox(height: 8),
        pw.Text(
          isMarathi
              ? 'मी, ${app.computedNewFullName}, वय: ${app.newAge} वर्षे, रा. ${app.propertyAddress}, सत्य प्रतिज्ञेवर लिहून देतो की वीज ग्राहक क्र. ${app.consumerNo} '
                '(जुने नाव: ${app.computedOldFullName}) ही वीज जोडणी कायदेशीररित्या माझ्या नावे हस्तांतरित होण्यास मी विनंती करत आहे. '
                'सदर वीज जोडणीची देयके वेळेवर भरण्यास मी पूर्णपणे बांधील आहे.'
              : 'I, ${app.computedNewFullName}, age: ${app.newAge} years, residing at ${app.propertyAddress}, solemnly affirm that Consumer No. ${app.consumerNo} '
                '(previously in the name of ${app.computedOldFullName}) be transferred to my name. I undertake to pay all future and legitimate pending bills.',
          style: const pw.TextStyle(fontSize: 8.5, height: 1.4),
        ),
        pw.Spacer(),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.Text('Place: ${app.affidavitPlace} | Date: ${_dateFormat.format(app.applicationDate)}', style: const pw.TextStyle(fontSize: 8)),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                if (app.hasNewConsumerSignature)
                  pw.Container(
                    height: 28,
                    child: pw.Image(pw.MemoryImage(app.newConsumerSignatureBytes!), height: 26, fit: pw.BoxFit.contain),
                  )
                else
                  pw.SizedBox(height: 28),
                pw.Container(width: 140, height: 0.8, color: darkText),
                pw.SizedBox(height: 2),
                pw.Text('Deponent Signature', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                pw.Text('(${app.computedNewFullName})', style: const pw.TextStyle(fontSize: 6.8, color: mutedText)),
              ],
            ),
          ],
        ),
      ],
    );
  }

  static pw.Widget _buildFormXContent(MsedclChangeOfNameApplication app) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        pw.Text(
          'MSEDCL FORM "X" — SECURITY DEPOSIT CONSENT / REFUND',
          style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: primaryBlue),
          textAlign: pw.TextAlign.center,
        ),
        pw.SizedBox(height: 8),
        pw.Text('Consumer No: ${app.consumerNo} | Old Consumer: ${app.computedOldFullName}', style: const pw.TextStyle(fontSize: 8.5)),
        pw.SizedBox(height: 8),
        if (app.isFormXTransfer) ...[
          pw.Text(
            'CONSENT: I, ${app.computedOldFullName}, hereby consent to transfer my security deposit on Consumer No. ${app.consumerNo} '
            'to the incoming consumer ${app.computedNewFullName} without any reservation.',
            style: const pw.TextStyle(fontSize: 8.5, height: 1.4),
          ),
        ] else ...[
          pw.Text(
            'REFUND: Please refund security deposit for Consumer No. ${app.consumerNo} to Bank Account: '
            '${app.refundAccountNumber} (${app.refundBankName}, IFSC: ${app.refundIfscCode}).',
            style: const pw.TextStyle(fontSize: 8.5, height: 1.4),
          ),
        ],
        pw.Spacer(),
        pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              if (app.hasOldConsumerSignature)
                pw.Container(
                  height: 28,
                  child: pw.Image(pw.MemoryImage(app.oldConsumerSignatureBytes!), height: 26, fit: pw.BoxFit.contain),
                )
              else
                pw.SizedBox(height: 28),
              pw.Container(width: 140, height: 0.8, color: darkText),
              pw.SizedBox(height: 2),
              pw.Text('Old Consumer Signature', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
              pw.Text('(${app.computedOldFullName})', style: const pw.TextStyle(fontSize: 6.8, color: mutedText)),
            ],
          ),
        ),
      ],
    );
  }

  static pw.Widget _buildChecklistContent(MsedclChangeOfNameApplication app) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        pw.Text(
          'ANNEXURE "A" — DOCUMENT CHECKLIST SUMMARY',
          style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: primaryBlue),
          textAlign: pw.TextAlign.center,
        ),
        pw.SizedBox(height: 8),
        pw.Table(
          border: pw.TableBorder.all(color: borderColor, width: 0.5),
          children: [
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: lightBg),
              children: [
                _headerCell('Document Type'),
                _headerCell('Status'),
                _headerCell('File Notes'),
              ],
            ),
            ...app.documents.map((d) {
              return pw.TableRow(
                children: [
                  pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(d.docType, style: const pw.TextStyle(fontSize: 7.5))),
                  pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(d.status, style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold))),
                  pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(d.fileName ?? d.notes ?? '—', style: const pw.TextStyle(fontSize: 7))),
                ],
              );
            }),
          ],
        ),
      ],
    );
  }
}
