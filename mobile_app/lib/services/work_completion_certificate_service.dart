import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'package:share_plus/share_plus.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import '../models/consumer_record.dart';

class WorkCompletionCertificateService {
  /// Generate a professional single-page A4 Work Completion Certificate
  static Future<File> generateCertificatePdf({
    required ConsumerRecord customer,
    String? customCustomerName,
    String? customConsumerNo,
    String? customAddress,
    String? customCapacity,
    DateTime? customCompletionDate,
    Directory? outputDirectory,
  }) async {
    // 1. Initialize A4 Document (Single Page, Portrait)
    final PdfDocument document = PdfDocument();
    document.pageSettings.size = PdfPageSize.a4; // 595.28 x 841.89 points
    document.pageSettings.orientation = PdfPageOrientation.portrait;
    document.pageSettings.margins.all = 0; // Custom exact margins

    final PdfPage page = document.pages.add();
    final PdfGraphics graphics = page.graphics;
    const double pageWidth = 595.28;
    const double pageHeight = 841.89;

    // Fonts
    final PdfFont companyTitleFont = PdfStandardFont(PdfFontFamily.helvetica, 14.5, style: PdfFontStyle.bold);
    final PdfFont certTitleFont = PdfStandardFont(PdfFontFamily.helvetica, 12.5, style: PdfFontStyle.bold);
    final PdfFont certSubTitleFont = PdfStandardFont(PdfFontFamily.helvetica, 7.5, style: PdfFontStyle.bold);
    final PdfFont tableHeaderFont = PdfStandardFont(PdfFontFamily.helvetica, 8.5, style: PdfFontStyle.bold);
    final PdfFont labelFont = PdfStandardFont(PdfFontFamily.helvetica, 8.2, style: PdfFontStyle.bold);
    final PdfFont valueBoldFont = PdfStandardFont(PdfFontFamily.helvetica, 8.2, style: PdfFontStyle.bold);
    final PdfFont valueFont = PdfStandardFont(PdfFontFamily.helvetica, 8.2);
    final PdfFont declHeaderFont = PdfStandardFont(PdfFontFamily.helvetica, 8.5, style: PdfFontStyle.bold);
    final PdfFont bodyFont = PdfStandardFont(PdfFontFamily.helvetica, 7.8);
    final PdfFont chipLabelFont = PdfStandardFont(PdfFontFamily.helvetica, 6.8);
    final PdfFont chipStatusFont = PdfStandardFont(PdfFontFamily.helvetica, 7.2, style: PdfFontStyle.bold);
    final PdfFont signHeaderFont = PdfStandardFont(PdfFontFamily.helvetica, 9.0, style: PdfFontStyle.bold);
    final PdfFont signTitleFont = PdfStandardFont(PdfFontFamily.helvetica, 8.5, style: PdfFontStyle.bold);
    final PdfFont signSubFont = PdfStandardFont(PdfFontFamily.helvetica, 7.0);
    final PdfFont stampFont = PdfStandardFont(PdfFontFamily.helvetica, 7.5, style: PdfFontStyle.bold);
    final PdfFont footerFont = PdfStandardFont(PdfFontFamily.helvetica, 6.6);
    final PdfFont footerBoldFont = PdfStandardFont(PdfFontFamily.helvetica, 6.6, style: PdfFontStyle.bold);
    final PdfFont headerRightBoldFont = PdfStandardFont(PdfFontFamily.helvetica, 7.8, style: PdfFontStyle.bold);
    final PdfFont headerRightFont = PdfStandardFont(PdfFontFamily.helvetica, 7.2);
    final PdfFont headerRightMutedFont = PdfStandardFont(PdfFontFamily.helvetica, 6.8);

    // Color Palette matching design
    final PdfColor navyColor = PdfColor(13, 43, 111); // #0D2B6F
    final PdfColor emeraldColor = PdfColor(43, 182, 115); // #2BB673
    final PdfColor lightGreenColor = PdfColor(16, 185, 129); // #10B981
    final PdfColor darkTextColor = PdfColor(15, 23, 42); // #0F172A
    final PdfColor slateBodyColor = PdfColor(51, 65, 85); // #334155
    final PdfColor slateMutedColor = PdfColor(100, 116, 139); // #64748B
    final PdfColor tableBorderColor = PdfColor(203, 213, 225); // #CBD5E1
    final PdfColor zebraBgColor = PdfColor(248, 250, 252); // #F8FAFC
    final PdfColor whiteColor = PdfColor(255, 255, 255);

    final PdfBrush navyBrush = PdfSolidBrush(navyColor);
    final PdfBrush emeraldBrush = PdfSolidBrush(emeraldColor);
    final PdfBrush lightGreenBrush = PdfSolidBrush(lightGreenColor);
    final PdfBrush darkTextBrush = PdfSolidBrush(darkTextColor);
    final PdfBrush slateBodyBrush = PdfSolidBrush(slateBodyColor);
    final PdfBrush slateMutedBrush = PdfSolidBrush(slateMutedColor);
    final PdfBrush zebraBgBrush = PdfSolidBrush(zebraBgColor);
    final PdfBrush whiteBrush = PdfSolidBrush(whiteColor);

    final PdfPen navyOuterPen = PdfPen(navyColor, width: 1.5);
    final PdfPen greenInnerPen = PdfPen(lightGreenColor, width: 0.6);
    final PdfPen borderPen = PdfPen(tableBorderColor, width: 0.8);
    final PdfPen thinBorderPen = PdfPen(tableBorderColor, width: 0.6);

    // ==========================================
    // 1. DUAL BORDER (Outer Navy 1.5 + Inner Green 0.6)
    // ==========================================
    const double outerMargin = 18;
    graphics.drawRectangle(
      pen: navyOuterPen,
      bounds: const Rect.fromLTWH(outerMargin, outerMargin, pageWidth - (outerMargin * 2), pageHeight - (outerMargin * 2)),
    );

    const double innerMargin = 21.5;
    graphics.drawRectangle(
      pen: greenInnerPen,
      bounds: const Rect.fromLTWH(innerMargin, innerMargin, pageWidth - (innerMargin * 2), pageHeight - (innerMargin * 2)),
    );

    const double contentLeft = 44;
    const double contentWidth = pageWidth - (contentLeft * 2); // 507.28
    const double contentRight = contentLeft + contentWidth;

    // Resolve Customer Data
    final String customerName = (customCustomerName != null && customCustomerName.trim().isNotEmpty)
        ? customCustomerName.trim()
        : customer.name.trim();

    final String consumerNo = (customConsumerNo != null && customConsumerNo.trim().isNotEmpty)
        ? customConsumerNo.trim()
        : customer.consumerNo.trim();

    final DateTime completionDate = customCompletionDate ??
        customer.installationDate ??
        customer.rtsCompletionDate ??
        customer.submitDate ??
        DateTime.now();
    final String formattedCompletionDate = DateFormat('dd MMMM yyyy').format(completionDate);
    final String issueDateStr = DateFormat('dd-MM-yyyy').format(DateTime.now());

    String capacityDisplay = (customCapacity != null && customCapacity.trim().isNotEmpty)
        ? customCapacity.trim()
        : '';
    if (capacityDisplay.isEmpty && customer.remarks != null && customer.remarks!.trim().isNotEmpty) {
      final match = RegExp(r'(\d+(?:\.\d+)?\s*(?:kw|kW|KW|Kw))').firstMatch(customer.remarks!);
      if (match != null) capacityDisplay = match.group(1)!;
    }
    if (capacityDisplay.isEmpty) {
      capacityDisplay = '3 kW';
    }

    String addressDisplay = (customAddress != null && customAddress.trim().isNotEmpty)
        ? customAddress.trim()
        : '';
    if (addressDisplay.isEmpty) {
      if (customer.address != null && customer.address!.trim().isNotEmpty) {
        addressDisplay = customer.address!.trim();
      } else if (customer.village != null && customer.village!.trim().isNotEmpty) {
        addressDisplay = customer.village!.trim();
      }
    }
    if (addressDisplay.isEmpty) addressDisplay = 'Project site as per consumer record';

    // ==========================================
    // 2. HEADER: BRANDING & CONTACT INFO
    // ==========================================
    double y = 38;

    PdfBitmap? logoBitmap;
    try {
      final ByteData logoData = await rootBundle.load('assets/images/logo.png');
      final Uint8List logoBytes = logoData.buffer.asUint8List();
      logoBitmap = PdfBitmap(logoBytes);
    } catch (e) {
      debugPrint('Logo load error in mobile WCR service: $e');
    }

    if (logoBitmap != null) {
      graphics.drawImage(logoBitmap, Rect.fromLTWH(contentLeft, y, 56, 56));
    } else {
      graphics.drawRectangle(
        brush: navyBrush,
        bounds: Rect.fromLTWH(contentLeft, y, 54, 54),
      );
      graphics.drawString(
        'SIYA',
        PdfStandardFont(PdfFontFamily.helvetica, 14, style: PdfFontStyle.bold),
        brush: whiteBrush,
        format: PdfStringFormat(alignment: PdfTextAlignment.center, lineAlignment: PdfVerticalAlignment.middle),
        bounds: Rect.fromLTWH(contentLeft, y, 54, 54),
      );
    }

    final double headerTextLeft = contentLeft + 68;

    graphics.drawString(
      'SIYA INFOTECH & SOLAR ENERGY',
      companyTitleFont,
      brush: navyBrush,
      bounds: Rect.fromLTWH(headerTextLeft, y + 2, 260, 18),
    );

    graphics.drawString(
      'Solar Solutions & Digital Services',
      tableHeaderFont,
      brush: emeraldBrush,
      bounds: Rect.fromLTWH(headerTextLeft, y + 22, 260, 14),
    );

    graphics.drawString(
      'Govt. Approved MNRE Channel Partner | Rooftop Solar Systems',
      headerRightMutedFont,
      brush: slateMutedBrush,
      bounds: Rect.fromLTWH(headerTextLeft, y + 38, 260, 12),
    );

    // Header Right Contacts
    graphics.drawString(
      'GSTIN: 27CVTPK6358P1ZD',
      headerRightBoldFont,
      brush: navyBrush,
      format: PdfStringFormat(alignment: PdfTextAlignment.right),
      bounds: Rect.fromLTWH(contentRight - 200, y, 200, 12),
    );

    graphics.drawString(
      'Phone: 7588003220',
      headerRightBoldFont,
      brush: navyBrush,
      format: PdfStringFormat(alignment: PdfTextAlignment.right),
      bounds: Rect.fromLTWH(contentRight - 200, y + 12, 200, 12),
    );

    graphics.drawString(
      'Email: siyainfodigital@gmail.com',
      headerRightFont,
      brush: slateBodyBrush,
      format: PdfStringFormat(alignment: PdfTextAlignment.right),
      bounds: Rect.fromLTWH(contentRight - 200, y + 24, 200, 12),
    );

    graphics.drawString(
      '21, Mudavad Road, Betawad,',
      headerRightMutedFont,
      brush: slateMutedBrush,
      format: PdfStringFormat(alignment: PdfTextAlignment.right),
      bounds: Rect.fromLTWH(contentRight - 200, y + 35, 200, 11),
    );

    graphics.drawString(
      'Tal. Shindkheda, Dist. Dhule - 425403',
      headerRightMutedFont,
      brush: slateMutedBrush,
      format: PdfStringFormat(alignment: PdfTextAlignment.right),
      bounds: Rect.fromLTWH(contentRight - 200, y + 45, 200, 11),
    );

    y += 62;

    // Dual-Tone Separator
    graphics.drawLine(
      PdfPen(navyColor, width: 2.0),
      Offset(contentLeft, y),
      Offset(contentLeft + (contentWidth * 0.7), y),
    );
    graphics.drawLine(
      PdfPen(lightGreenColor, width: 2.0),
      Offset(contentLeft + (contentWidth * 0.7), y),
      Offset(contentRight, y),
    );

    y += 12;

    // ==========================================
    // 3. TITLE: DARK NAVY BANNER
    // ==========================================
    const double titleBoxHeight = 36;
    graphics.drawRectangle(
      brush: navyBrush,
      bounds: Rect.fromLTWH(contentLeft, y, contentWidth, titleBoxHeight),
    );

    graphics.drawString(
      'WORK COMPLETION CERTIFICATE',
      certTitleFont,
      brush: whiteBrush,
      bounds: Rect.fromLTWH(contentLeft + 12, y + 5, 300, 16),
    );

    graphics.drawString(
      'For Bank / Financial Institution Submission',
      certSubTitleFont,
      brush: lightGreenBrush,
      bounds: Rect.fromLTWH(contentLeft + 12, y + 21, 300, 12),
    );

    graphics.drawString(
      'Ref: SIYA-WCR-${consumerNo.isNotEmpty ? consumerNo : "GEN"}',
      certSubTitleFont,
      brush: whiteBrush,
      format: PdfStringFormat(alignment: PdfTextAlignment.right),
      bounds: Rect.fromLTWH(contentRight - 200, y + 6, 188, 12),
    );

    graphics.drawString(
      'Date: $issueDateStr',
      certSubTitleFont,
      brush: whiteBrush,
      format: PdfStringFormat(alignment: PdfTextAlignment.right),
      bounds: Rect.fromLTWH(contentRight - 200, y + 20, 188, 12),
    );

    y += titleBoxHeight + 12;

    // ==========================================
    // 4. PROJECT & BENEFICIARY DETAILS TABLE
    // ==========================================
    const double tableHeaderHeight = 20;
    graphics.drawRectangle(
      brush: navyBrush,
      bounds: Rect.fromLTWH(contentLeft, y, contentWidth, tableHeaderHeight),
    );
    graphics.drawString(
      'PROJECT & BENEFICIARY DETAILS',
      tableHeaderFont,
      brush: whiteBrush,
      bounds: Rect.fromLTWH(contentLeft + 10, y + 4, contentWidth - 20, 14),
    );

    y += tableHeaderHeight;

    final List<Map<String, String>> rows = [
      {'label': '1. Customer Name', 'val': customerName, 'isBold': 'true', 'zebra': 'false'},
      {'label': '2. Consumer Number', 'val': consumerNo, 'isBold': 'true', 'zebra': 'true'},
      {'label': '3. Project Address', 'val': addressDisplay, 'isBold': 'false', 'zebra': 'false'},
      {'label': '4. Solar System Capacity', 'val': capacityDisplay, 'isBold': 'true', 'zebra': 'true'},
      {'label': '5. Installation Date', 'val': formattedCompletionDate, 'isBold': 'true', 'zebra': 'false'},
    ];

    const double col1Width = 140;

    for (int i = 0; i < rows.length; i++) {
      final r = rows[i];
      final bool isZebra = r['zebra'] == 'true';
      final bool isBold = r['isBold'] == 'true';
      final double rHeight = (i == 2 && addressDisplay.length > 50) ? 30.0 : 22.0;

      if (isZebra) {
        graphics.drawRectangle(
          brush: zebraBgBrush,
          bounds: Rect.fromLTWH(contentLeft, y, contentWidth, rHeight),
        );
      }

      graphics.drawRectangle(
        pen: thinBorderPen,
        bounds: Rect.fromLTWH(contentLeft, y, contentWidth, rHeight),
      );

      // Label
      graphics.drawString(
        r['label']!,
        labelFont,
        brush: navyBrush,
        bounds: Rect.fromLTWH(contentLeft + 10, y + (rHeight > 22 ? 6 : 4.5), col1Width, rHeight),
      );

      // Colon
      graphics.drawString(
        ':',
        labelFont,
        brush: slateMutedBrush,
        bounds: Rect.fromLTWH(contentLeft + col1Width + 2, y + (rHeight > 22 ? 6 : 4.5), 10, rHeight),
      );

      // Value
      graphics.drawString(
        r['val']!,
        isBold ? valueBoldFont : valueFont,
        brush: isBold ? darkTextBrush : slateBodyBrush,
        bounds: Rect.fromLTWH(contentLeft + col1Width + 14, y + (rHeight > 22 ? 6 : 4.5), contentWidth - col1Width - 20, rHeight - 6),
      );

      y += rHeight;
    }

    y += 12;

    // ==========================================
    // 5. OFFICIAL WORK COMPLETION DECLARATION
    // ==========================================
    const double declBoxHeight = 112;
    graphics.drawRectangle(
      brush: zebraBgBrush,
      pen: borderPen,
      bounds: Rect.fromLTWH(contentLeft, y, contentWidth, declBoxHeight),
    );

    // Green bullet dot
    graphics.drawEllipse(
      Rect.fromLTWH(contentLeft + 10, y + 10, 5, 5),
      brush: emeraldBrush,
    );

    graphics.drawString(
      'OFFICIAL WORK COMPLETION DECLARATION',
      declHeaderFont,
      brush: navyBrush,
      bounds: Rect.fromLTWH(contentLeft + 20, y + 7, contentWidth - 30, 14),
    );

    const String declP1 =
        'This is to certify that the Rooftop Solar Photovoltaic (PV) System for the aforementioned customer has been successfully installed, commissioned, and tested in full accordance with the approved scheme, technical specifications, and safety guidelines prescribed by the Ministry of New and Renewable Energy (MNRE) and the State Power Distribution Utility (DISCOM).';

    const String declP2 =
        'The solar PV modules, inverter, structure, earthing, AC/DC protection units, and interconnecting cables have been physically verified, tested, and found completely operational, energised, and ready for regular grid-tied electricity generation and net-metering synchronisation.';

    final PdfStringFormat declFormat = PdfStringFormat(lineSpacing: 2);

    graphics.drawString(
      declP1,
      bodyFont,
      brush: slateBodyBrush,
      format: declFormat,
      bounds: Rect.fromLTWH(contentLeft + 10, y + 24, contentWidth - 20, 42),
    );

    graphics.drawString(
      declP2,
      bodyFont,
      brush: slateBodyBrush,
      format: declFormat,
      bounds: Rect.fromLTWH(contentLeft + 10, y + 68, contentWidth - 20, 40),
    );

    y += declBoxHeight + 10;

    // ==========================================
    // 6. TECHNICAL COMPLIANCE METRICS (4 CHIPS)
    // ==========================================
    const double chipBoxHeight = 34;
    graphics.drawRectangle(
      pen: borderPen,
      bounds: Rect.fromLTWH(contentLeft, y, contentWidth, chipBoxHeight),
    );

    final double cWidth = contentWidth / 4;
    final List<MapEntry<String, String>> chips = [
      const MapEntry('Grid Compliance', 'Verified & Safe'),
      const MapEntry('Inverter Testing', 'Passed 100%'),
      const MapEntry('Earthing & Lightning', 'Properly Grounded'),
      const MapEntry('Physical Installation', 'Fully Completed'),
    ];

    for (int i = 0; i < chips.length; i++) {
      final double cLeft = contentLeft + (i * cWidth);
      if (i > 0) {
        graphics.drawLine(
          borderPen,
          Offset(cLeft, y + 5),
          Offset(cLeft, y + chipBoxHeight - 5),
        );
      }
      graphics.drawString(
        chips[i].key,
        chipLabelFont,
        brush: slateMutedBrush,
        format: PdfStringFormat(alignment: PdfTextAlignment.center),
        bounds: Rect.fromLTWH(cLeft, y + 5, cWidth, 11),
      );
      graphics.drawString(
        chips[i].value,
        chipStatusFont,
        brush: emeraldBrush,
        format: PdfStringFormat(alignment: PdfTextAlignment.center),
        bounds: Rect.fromLTWH(cLeft, y + 17, cWidth, 12),
      );
    }

    y += chipBoxHeight + 16;

    // ==========================================
    // 7. SIGNATURE BLOCK (RIGHT ALIGNED AT BOTTOM AREA)
    // ==========================================
    const double signWidth = 230;
    final double signLeft = contentRight - signWidth;
    double signY = pageHeight - 200;

    graphics.drawString(
      'For SIYA INFOTECH & SOLAR ENERGY',
      signHeaderFont,
      brush: navyBrush,
      format: PdfStringFormat(alignment: PdfTextAlignment.center),
      bounds: Rect.fromLTWH(signLeft, signY, signWidth, 14),
    );

    signY += 18;

    // Dashed Stamp Box
    const double stampW = 150;
    const double stampH = 62;
    final double stampL = signLeft + ((signWidth - stampW) / 2);

    final PdfPen dashPen = PdfPen(tableBorderColor, width: 0.8);
    dashPen.dashStyle = PdfDashStyle.dash;

    graphics.drawRectangle(
      brush: zebraBgBrush,
      pen: dashPen,
      bounds: Rect.fromLTWH(stampL, signY, stampW, stampH),
    );

    graphics.drawString(
      '[ OFFICIAL STAMP / SEAL ]',
      stampFont,
      brush: slateMutedBrush,
      format: PdfStringFormat(alignment: PdfTextAlignment.center, lineAlignment: PdfVerticalAlignment.middle),
      bounds: Rect.fromLTWH(stampL, signY, stampW, stampH),
    );

    signY += stampH + 10;

    // Solid Line
    graphics.drawLine(
      PdfPen(navyColor, width: 1.0),
      Offset(stampL, signY),
      Offset(stampL + stampW, signY),
    );

    signY += 5;

    graphics.drawString(
      'Authorized Signatory',
      signTitleFont,
      brush: darkTextBrush,
      format: PdfStringFormat(alignment: PdfTextAlignment.center),
      bounds: Rect.fromLTWH(signLeft, signY, signWidth, 14),
    );

    graphics.drawString(
      'Project Manager / Managing Director',
      signSubFont,
      brush: slateMutedBrush,
      format: PdfStringFormat(alignment: PdfTextAlignment.center),
      bounds: Rect.fromLTWH(signLeft, signY + 14, signWidth, 12),
    );

    // ==========================================
    // 8. FOOTER
    // ==========================================
    const double footerY = pageHeight - 40;

    graphics.drawLine(
      borderPen,
      Offset(contentLeft, footerY - 6),
      Offset(contentRight, footerY - 6),
    );

    graphics.drawString(
      'GSTIN: 27CVTPK6358P1ZD | Helpline: 7588003220 | Email: siyainfodigital@gmail.com',
      footerFont,
      brush: slateMutedBrush,
      bounds: Rect.fromLTWH(contentLeft, footerY, contentWidth * 0.65, 12),
    );

    graphics.drawString(
      'Official Bank & DISCOM Submission Document',
      footerBoldFont,
      brush: navyBrush,
      format: PdfStringFormat(alignment: PdfTextAlignment.right),
      bounds: Rect.fromLTWH(contentLeft + (contentWidth * 0.4), footerY, contentWidth * 0.6, 12),
    );

    // Save File
    final List<int> bytes = await document.save();
    document.dispose();

    final safeCustomerName = customer.name
        .trim()
        .replaceAll(RegExp(r'[^\w\s-]'), '')
        .replaceAll(RegExp(r'\s+'), '_');

    Directory dir;
    try {
      dir = outputDirectory ?? await getApplicationDocumentsDirectory();
    } catch (_) {
      dir = outputDirectory ?? Directory.systemTemp;
    }

    final fileName = 'Work_Completion_Certificate_$safeCustomerName.pdf';
    final file = File('${dir.path}/$fileName');
    await file.writeAsBytes(bytes, flush: true);

    return file;
  }

  /// Preview the generated certificate in system PDF viewer
  static Future<void> previewCertificate(File file) async {
    await OpenFilex.open(file.path);
  }

  /// Share the certificate PDF via Android native Share Sheet (WhatsApp, Email, etc.)
  static Future<void> shareCertificate(File file, ConsumerRecord customer) async {
    final fileName = file.uri.pathSegments.last;
    final xFile = XFile(
      file.path,
      mimeType: 'application/pdf',
      name: fileName,
    );

    // ignore: deprecated_member_use
    await Share.shareXFiles(
      [xFile],
      subject: 'Work Completion Certificate - ${customer.name}',
      text: 'Please find attached the Work Completion Certificate for Solar Rooftop Project of ${customer.name} (Consumer No: ${customer.consumerNo}).',
    );
  }

  /// Download and copy certificate to device storage (Downloads / Documents)
  static Future<File> downloadCertificate(File sourceFile, ConsumerRecord customer) async {
    final fileName = sourceFile.uri.pathSegments.last;

    // Check standard Android public Download folder
    final publicDownloadDir = Directory('/storage/emulated/0/Download');
    if (await publicDownloadDir.exists()) {
      try {
        final targetPath = '${publicDownloadDir.path}/$fileName';
        final downloadedFile = await sourceFile.copy(targetPath);
        return downloadedFile;
      } catch (e) {
        debugPrint('Download to /storage/emulated/0/Download failed, falling back: $e');
      }
    }

    // Fallback to getDownloadsDirectory or getExternalStorageDirectory
    try {
      final extDir = await getDownloadsDirectory() ?? await getExternalStorageDirectory();
      if (extDir != null) {
        final targetPath = '${extDir.path}/$fileName';
        final downloadedFile = await sourceFile.copy(targetPath);
        return downloadedFile;
      }
    } catch (e) {
      debugPrint('Fallback download dir failed: $e');
    }

    return sourceFile;
  }
}

