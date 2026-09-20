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
    final PdfFont titleFont = PdfStandardFont(PdfFontFamily.helvetica, 18, style: PdfFontStyle.bold);
    final PdfFont certificateTitleFont = PdfStandardFont(PdfFontFamily.helvetica, 15, style: PdfFontStyle.bold);
    final PdfFont sectionHeaderFont = PdfStandardFont(PdfFontFamily.helvetica, 11, style: PdfFontStyle.bold);
    final PdfFont bodyFont = PdfStandardFont(PdfFontFamily.helvetica, 9.5);
    final PdfFont bodyBoldFont = PdfStandardFont(PdfFontFamily.helvetica, 9.5, style: PdfFontStyle.bold);
    final PdfFont smallFont = PdfStandardFont(PdfFontFamily.helvetica, 8.5);
    final PdfFont smallBoldFont = PdfStandardFont(PdfFontFamily.helvetica, 8.5, style: PdfFontStyle.bold);
    final PdfFont footerBrandFont = PdfStandardFont(PdfFontFamily.helvetica, 10, style: PdfFontStyle.bold);

    // Color Palette (Deep Navy Blue + Vibrant Green)
    final PdfColor deepNavy = PdfColor(15, 45, 105); // #0F2D69
    final PdfColor emeraldGreen = PdfColor(5, 150, 105); // #059669
    final PdfColor lightGreenAccent = PdfColor(16, 185, 129); // #10B981
    final PdfColor slateDark = PdfColor(15, 23, 42); // #0F172A
    final PdfColor slateBody = PdfColor(51, 65, 85); // #334155
    final PdfColor slateMuted = PdfColor(100, 116, 139); // #64748B
    final PdfColor slateLight = PdfColor(241, 245, 249); // #F1F5F9
    final PdfColor cardBg = PdfColor(248, 250, 252); // #F8FAFC
    final PdfColor borderLight = PdfColor(203, 213, 225); // #CBD5E1

    final PdfBrush deepNavyBrush = PdfSolidBrush(deepNavy);
    final PdfBrush emeraldBrush = PdfSolidBrush(emeraldGreen);
    final PdfBrush slateDarkBrush = PdfSolidBrush(slateDark);
    final PdfBrush slateBodyBrush = PdfSolidBrush(slateBody);
    final PdfBrush slateMutedBrush = PdfSolidBrush(slateMuted);
    final PdfBrush whiteBrush = PdfSolidBrush(PdfColor(255, 255, 255));

    final PdfPen outerNavyPen = PdfPen(deepNavy, width: 1.5);
    final PdfPen innerGreenPen = PdfPen(lightGreenAccent, width: 0.5);
    final PdfPen separatorPen = PdfPen(deepNavy, width: 1.2);
    final PdfPen tableBorderPen = PdfPen(borderLight, width: 0.8);

    // ==========================================
    // 1. THIN DECORATIVE OUTER BORDER
    // ==========================================
    const double outerMargin = 22;
    graphics.drawRectangle(
      pen: outerNavyPen,
      bounds: const Rect.fromLTWH(outerMargin, outerMargin, pageWidth - (outerMargin * 2), pageHeight - (outerMargin * 2)),
    );

    const double innerMargin = 25.5;
    graphics.drawRectangle(
      pen: innerGreenPen,
      bounds: const Rect.fromLTWH(innerMargin, innerMargin, pageWidth - (innerMargin * 2), pageHeight - (innerMargin * 2)),
    );

    const double contentLeft = 40;
    const double contentWidth = pageWidth - (contentLeft * 2); // 515.28

    // ==========================================
    // 2. HEADER: LOGO & COMPANY BRANDING
    // ==========================================
    double y = 40;

    // Load and render company logo
    PdfBitmap? logoBitmap;
    try {
      final ByteData logoData = await rootBundle.load('assets/images/logo.png');
      final Uint8List logoBytes = logoData.buffer.asUint8List();
      logoBitmap = PdfBitmap(logoBytes);
    } catch (e) {
      debugPrint('Logo load error in certificate service: $e');
    }

    if (logoBitmap != null) {
      graphics.drawImage(
        logoBitmap,
        Rect.fromLTWH(contentLeft, y, 62, 62),
      );
    } else {
      // Elegant fallback icon block
      graphics.drawRectangle(
        brush: PdfSolidBrush(deepNavy),
        bounds: Rect.fromLTWH(contentLeft, y, 62, 62),
      );
      graphics.drawString(
        'SIYA\nSOLAR',
        smallBoldFont,
        brush: whiteBrush,
        format: PdfStringFormat(alignment: PdfTextAlignment.center, lineAlignment: PdfVerticalAlignment.middle),
        bounds: Rect.fromLTWH(contentLeft, y, 62, 62),
      );
    }

    // Company Header Text
    final double headerTextLeft = contentLeft + 72;
    final double headerTextWidth = contentWidth - 72;

    graphics.drawString(
      'SIYA INFOTECH & SOLAR ENERGY',
      titleFont,
      brush: deepNavyBrush,
      bounds: Rect.fromLTWH(headerTextLeft, y + 4, headerTextWidth, 22),
    );

    graphics.drawString(
      'Solar Solutions & Digital Services',
      sectionHeaderFont,
      brush: emeraldBrush,
      bounds: Rect.fromLTWH(headerTextLeft, y + 27, headerTextWidth, 16),
    );

    graphics.drawString(
      'Govt. Empaneled Solar Rooftop Channel Partner & EPC Contractor',
      smallFont,
      brush: slateMutedBrush,
      bounds: Rect.fromLTWH(headerTextLeft, y + 45, headerTextWidth, 14),
    );

    y += 74;

    // Thin Blue + Green Separator Line
    graphics.drawLine(
      separatorPen,
      Offset(contentLeft, y),
      Offset(contentLeft + contentWidth, y),
    );
    graphics.drawLine(
      PdfPen(lightGreenAccent, width: 2.0),
      Offset(contentLeft, y + 2.5),
      Offset(contentLeft + (contentWidth * 0.35), y + 2.5),
    );

    y += 18;

    // ==========================================
    // 3. TITLE: LARGE DARK-BLUE BOX
    // ==========================================
    const double titleBoxHeight = 36;
    graphics.drawRectangle(
      brush: deepNavyBrush,
      bounds: Rect.fromLTWH(contentLeft, y, contentWidth, titleBoxHeight),
    );

    graphics.drawString(
      'WORK COMPLETION CERTIFICATE',
      certificateTitleFont,
      brush: whiteBrush,
      format: PdfStringFormat(alignment: PdfTextAlignment.center, lineAlignment: PdfVerticalAlignment.middle),
      bounds: Rect.fromLTWH(contentLeft, y, contentWidth, titleBoxHeight),
    );

    y += titleBoxHeight + 8;

    // Below Title: Submission note & Completion Date
    final DateTime? actualCompletionDate = customer.installationDate ?? customer.rtsCompletionDate ?? customer.rtsDate;
    final String dateFormatted = actualCompletionDate != null
        ? DateFormat('dd / MM / yyyy').format(actualCompletionDate)
        : '____ / ____ / ______';

    graphics.drawString(
      'For Bank / Financial Institution Submission',
      smallBoldFont,
      brush: slateBodyBrush,
      bounds: Rect.fromLTWH(contentLeft, y, contentWidth * 0.6, 16),
    );

    graphics.drawString(
      'Date: $dateFormatted',
      smallBoldFont,
      brush: slateDarkBrush,
      format: PdfStringFormat(alignment: PdfTextAlignment.right),
      bounds: Rect.fromLTWH(contentLeft + (contentWidth * 0.4), y, contentWidth * 0.6, 16),
    );

    y += 24;

    // ==========================================
    // 4. CUSTOMER & PROJECT DETAILS SECTION
    // ==========================================
    // Section Header Banner
    const double sectionBannerHeight = 22;
    graphics.drawRectangle(
      brush: PdfSolidBrush(slateLight),
      bounds: Rect.fromLTWH(contentLeft, y, contentWidth, sectionBannerHeight),
    );
    graphics.drawRectangle(
      brush: deepNavyBrush,
      bounds: Rect.fromLTWH(contentLeft, y, 4, sectionBannerHeight),
    );
    graphics.drawString(
      'CUSTOMER & PROJECT DETAILS',
      sectionHeaderFont,
      brush: deepNavyBrush,
      bounds: Rect.fromLTWH(contentLeft + 12, y + 4, contentWidth - 20, 16),
    );

    y += sectionBannerHeight + 4;

    // Clean Two-Column Table with ONLY required 5 fields
    const double col1Width = 195;
    final double col2Width = contentWidth - col1Width; // 320.28

    // Derive fields cleanly
    final String customerName = customer.name.trim();
    final String consumerNo = customer.consumerNo.trim();
    final String projectAddress = (customer.address != null && customer.address!.trim().isNotEmpty)
        ? customer.address!.trim()
        : ((customer.village != null && customer.village!.trim().isNotEmpty) ? customer.village!.trim() : '');

    // Capacity detection
    String capacity = '';
    if (customer.remarks != null && customer.remarks!.trim().isNotEmpty) {
      final match = RegExp(r'(\d+(?:\.\d+)?\s*(?:kw|kW|KW|Kw))').firstMatch(customer.remarks!);
      if (match != null) capacity = match.group(1)!;
    }

    final String completionDateText = actualCompletionDate != null
        ? DateFormat('dd-MM-yyyy').format(actualCompletionDate)
        : '';

    final List<MapEntry<String, String>> tableRows = [
      MapEntry('Customer Name:', customerName),
      MapEntry('Consumer No.:', consumerNo),
      MapEntry('Project Address:', projectAddress),
      MapEntry('Solar System Capacity:', capacity),
      MapEntry('Installation / Completion Date:', completionDateText),
    ];

    for (int i = 0; i < tableRows.length; i++) {
      final entry = tableRows[i];
      final bool isAddress = i == 2;
      final double rowHeight = isAddress && entry.value.length > 45 ? 32 : 24;

      // Alternating row background
      if (i % 2 == 0) {
        graphics.drawRectangle(
          brush: PdfSolidBrush(cardBg),
          bounds: Rect.fromLTWH(contentLeft, y, contentWidth, rowHeight),
        );
      }

      // Cell Border
      graphics.drawRectangle(
        pen: tableBorderPen,
        bounds: Rect.fromLTWH(contentLeft, y, contentWidth, rowHeight),
      );
      graphics.drawLine(
        tableBorderPen,
        Offset(contentLeft + col1Width, y),
        Offset(contentLeft + col1Width, y + rowHeight),
      );

      // Col 1: Label
      graphics.drawString(
        entry.key,
        bodyBoldFont,
        brush: slateDarkBrush,
        bounds: Rect.fromLTWH(contentLeft + 10, y + (isAddress ? 6 : 5), col1Width - 15, rowHeight - 6),
      );

      // Col 2: Value
      graphics.drawString(
        entry.value,
        bodyFont,
        brush: slateDarkBrush,
        bounds: Rect.fromLTWH(contentLeft + col1Width + 10, y + (isAddress ? 6 : 5), col2Width - 15, rowHeight - 6),
      );

      y += rowHeight;
    }

    y += 20;

    // ==========================================
    // 5. PROJECT COMPLETION STATUS SECTION
    // ==========================================
    graphics.drawRectangle(
      brush: PdfSolidBrush(slateLight),
      bounds: Rect.fromLTWH(contentLeft, y, contentWidth, sectionBannerHeight),
    );
    graphics.drawRectangle(
      brush: PdfSolidBrush(lightGreenAccent),
      bounds: Rect.fromLTWH(contentLeft, y, 4, sectionBannerHeight),
    );
    graphics.drawString(
      'PROJECT COMPLETION STATUS',
      sectionHeaderFont,
      brush: deepNavyBrush,
      bounds: Rect.fromLTWH(contentLeft + 12, y + 4, contentWidth - 20, 16),
    );

    y += sectionBannerHeight + 6;

    // Certificate Declaration Text Card
    const double certBoxHeight = 145;
    graphics.drawRectangle(
      brush: PdfSolidBrush(cardBg),
      pen: PdfPen(borderLight, width: 0.8),
      bounds: Rect.fromLTWH(contentLeft, y, contentWidth, certBoxHeight),
    );
    // Left decorative emerald bar
    graphics.drawRectangle(
      brush: PdfSolidBrush(lightGreenAccent),
      bounds: Rect.fromLTWH(contentLeft, y, 3.5, certBoxHeight),
    );

    const String certificateParagraph1 =
        'This is to certify that the Solar Rooftop Project of the above-mentioned customer has been successfully completed and the solar PV system has been installed, tested and commissioned at the customer\'s premises.';

    const String certificateParagraph2 =
        'The project work has been completed as per the agreed scope of work and the system has been handed over to the customer.';

    const String certificateParagraph3 =
        'This certificate is issued for submission to the concerned Bank / Financial Institution towards confirmation of completion of the solar project.';

    final PdfStringFormat certFormat = PdfStringFormat(lineSpacing: 3);
    const double textPadding = 14;
    final double textWidth = contentWidth - (textPadding * 2);

    double textY = y + 12;
    graphics.drawString(
      certificateParagraph1,
      bodyFont,
      brush: slateBodyBrush,
      format: certFormat,
      bounds: Rect.fromLTWH(contentLeft + textPadding, textY, textWidth, 42),
    );

    textY += 46;
    graphics.drawString(
      certificateParagraph2,
      bodyFont,
      brush: slateBodyBrush,
      format: certFormat,
      bounds: Rect.fromLTWH(contentLeft + textPadding, textY, textWidth, 32),
    );

    textY += 36;
    graphics.drawString(
      certificateParagraph3,
      bodyFont,
      brush: slateBodyBrush,
      format: certFormat,
      bounds: Rect.fromLTWH(contentLeft + textPadding, textY, textWidth, 36),
    );

    y += certBoxHeight + 24;

    // ==========================================
    // 6. SIGNATURE & COMPANY SEAL
    // ==========================================
    final double signBlockWidth = 230;
    final double signBlockLeft = contentLeft + contentWidth - signBlockWidth;

    graphics.drawString(
      'For SIYA INFOTECH & SOLAR ENERGY',
      sectionHeaderFont,
      brush: deepNavyBrush,
      format: PdfStringFormat(alignment: PdfTextAlignment.center),
      bounds: Rect.fromLTWH(signBlockLeft, y, signBlockWidth, 16),
    );

    y += 24;

    // Company Seal / Stamp Frame with ample physical stamp/signature space
    final double sealBoxWidth = 110;
    final double sealBoxHeight = 58;
    final double sealLeft = signBlockLeft + ((signBlockWidth - sealBoxWidth) / 2);

    graphics.drawRectangle(
      pen: PdfPen(PdfColor(148, 163, 184), width: 1.0, dashStyle: PdfDashStyle.dash),
      bounds: Rect.fromLTWH(sealLeft, y, sealBoxWidth, sealBoxHeight),
    );

    graphics.drawString(
      'OFFICIAL\nCOMPANY SEAL',
      smallFont,
      brush: slateMutedBrush,
      format: PdfStringFormat(alignment: PdfTextAlignment.center, lineAlignment: PdfVerticalAlignment.middle),
      bounds: Rect.fromLTWH(sealLeft, y, sealBoxWidth, sealBoxHeight),
    );

    y += sealBoxHeight + 24;

    // Signature Line
    graphics.drawLine(
      PdfPen(deepNavy, width: 1.0),
      Offset(signBlockLeft + 20, y),
      Offset(signBlockLeft + signBlockWidth - 20, y),
    );

    y += 5;

    graphics.drawString(
      'Authorized Signatory',
      bodyBoldFont,
      brush: slateDarkBrush,
      format: PdfStringFormat(alignment: PdfTextAlignment.center),
      bounds: Rect.fromLTWH(signBlockLeft, y, signBlockWidth, 14),
    );

    graphics.drawString(
      'Company Seal',
      smallFont,
      brush: slateMutedBrush,
      format: PdfStringFormat(alignment: PdfTextAlignment.center),
      bounds: Rect.fromLTWH(signBlockLeft, y + 14, signBlockWidth, 14),
    );

    // ==========================================
    // 7. FOOTER SECTION
    // ==========================================
    const double footerY = pageHeight - 48;

    // Thin separator above footer
    graphics.drawLine(
      PdfPen(borderLight, width: 0.8),
      Offset(contentLeft, footerY - 8),
      Offset(contentLeft + contentWidth, footerY - 8),
    );

    // Bottom-left: CLEAN ENERGY • SMART FUTURE
    graphics.drawString(
      'CLEAN ENERGY • SMART FUTURE',
      footerBrandFont,
      brush: emeraldBrush,
      bounds: Rect.fromLTWH(contentLeft, footerY, contentWidth * 0.5, 18),
    );

    // Bottom-right: System note
    graphics.drawString(
      'Official Work Completion Certificate  |  Siya Data Management',
      smallFont,
      brush: slateMutedBrush,
      format: PdfStringFormat(alignment: PdfTextAlignment.right),
      bounds: Rect.fromLTWH(contentLeft + (contentWidth * 0.4), footerY + 2, contentWidth * 0.6, 16),
    );

    // ==========================================
    // SAVE TO FILE
    // ==========================================
    final List<int> bytes = await document.save();
    document.dispose();

    // Sanitize customer name for filename
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
