import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'package:share_plus/share_plus.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import '../models/solar_quotation.dart';
import 'company_stamp_helper.dart';

class BankLoanQuotationService {
  /// Generate a professional single-page A4 Bank Loan Solar Quotation
  /// using the EXACT letterhead style from the Work Completion Report (WCR).
  static Future<File> generateQuotationPdf({
    required SolarQuotation quotation,
    Directory? outputDirectory,
    bool includeStampAndSignature = true,
    Uint8List? customStampAndSignatureBytes,
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

    // Fonts - matching WCR Letterhead & Professional Layout
    final PdfFont companyTitleFont = PdfStandardFont(PdfFontFamily.helvetica, 14.5, style: PdfFontStyle.bold);
    final PdfFont companySubTitleFont = PdfStandardFont(PdfFontFamily.helvetica, 9.0, style: PdfFontStyle.bold);
    final PdfFont headerRightBoldFont = PdfStandardFont(PdfFontFamily.helvetica, 8.2, style: PdfFontStyle.bold);
    final PdfFont headerRightFont = PdfStandardFont(PdfFontFamily.helvetica, 7.8);
    final PdfFont headerRightMutedFont = PdfStandardFont(PdfFontFamily.helvetica, 7.2);

    final PdfFont bannerTitleFont = PdfStandardFont(PdfFontFamily.helvetica, 12.0, style: PdfFontStyle.bold);
    final PdfFont bannerSubTitleFont = PdfStandardFont(PdfFontFamily.helvetica, 7.8, style: PdfFontStyle.bold);
    final PdfFont sectionHeaderFont = PdfStandardFont(PdfFontFamily.helvetica, 8.2, style: PdfFontStyle.bold);

    final PdfFont tableHeaderFont = PdfStandardFont(PdfFontFamily.helvetica, 8.0, style: PdfFontStyle.bold);
    final PdfFont labelFont = PdfStandardFont(PdfFontFamily.helvetica, 8.0, style: PdfFontStyle.bold);
    final PdfFont valueBoldFont = PdfStandardFont(PdfFontFamily.helvetica, 8.0, style: PdfFontStyle.bold);
    final PdfFont valueFont = PdfStandardFont(PdfFontFamily.helvetica, 8.0);

    final PdfFont grandTotalLabelFont = PdfStandardFont(PdfFontFamily.helvetica, 9.0, style: PdfFontStyle.bold);
    final PdfFont grandTotalValFont = PdfStandardFont(PdfFontFamily.helvetica, 10.5, style: PdfFontStyle.bold);
    final PdfFont wordsFont = PdfStandardFont(PdfFontFamily.helvetica, 7.8, style: PdfFontStyle.bold);

    final PdfFont bulletFont = PdfStandardFont(PdfFontFamily.helvetica, 7.5);
    final PdfFont signHeaderFont = PdfStandardFont(PdfFontFamily.helvetica, 8.5, style: PdfFontStyle.bold);
    final PdfFont signTitleFont = PdfStandardFont(PdfFontFamily.helvetica, 8.0, style: PdfFontStyle.bold);
    final PdfFont signSubFont = PdfStandardFont(PdfFontFamily.helvetica, 7.0);

    final PdfFont footerFont = PdfStandardFont(PdfFontFamily.helvetica, 7.0);
    final PdfFont footerBoldFont = PdfStandardFont(PdfFontFamily.helvetica, 7.0, style: PdfFontStyle.bold);

    // Color Palette optimized for normal Black & White office printers AND Color prints
    final PdfColor navyColor = PdfColor(13, 43, 111); // #0D2B6F (Deep Navy)
    final PdfColor emeraldColor = PdfColor(4, 120, 87); // #047857 (Deep Emerald)
    final PdfColor goldenYellowColor = PdfColor(245, 158, 11); // #F59E0B (Golden Yellow Accent)
    final PdfColor blackColor = PdfColor(15, 23, 42); // #0F172A (Pure Dark Black/Charcoal)
    final PdfColor borderDarkColor = PdfColor(51, 65, 85); // #334155 (Clear Black/Charcoal Border for B&W)
    final PdfColor darkTextColor = PdfColor(15, 23, 42); // #0F172A (Pure Black Text)
    final PdfColor slateBodyColor = PdfColor(30, 41, 59); // #1E293B (Dark body text)
    final PdfColor slateMutedColor = PdfColor(71, 85, 105); // #475569 (Crisp charcoal)
    final PdfColor zebraBgColor = PdfColor(248, 250, 252); // #F8FAFC (Subtle 2% tint)
    final PdfColor headerBgColor = PdfColor(241, 245, 249); // #F1F5F9 (Light neutral heading box)
    final PdfColor whiteColor = PdfColor(255, 255, 255);

    final PdfBrush navyBrush = PdfSolidBrush(navyColor);
    final PdfBrush emeraldBrush = PdfSolidBrush(emeraldColor);
    final PdfBrush goldenYellowBrush = PdfSolidBrush(goldenYellowColor);
    final PdfBrush darkTextBrush = PdfSolidBrush(darkTextColor);
    final PdfBrush slateBodyBrush = PdfSolidBrush(slateBodyColor);
    final PdfBrush slateMutedBrush = PdfSolidBrush(slateMutedColor);
    final PdfBrush zebraBgBrush = PdfSolidBrush(zebraBgColor);
    final PdfBrush headerBgBrush = PdfSolidBrush(headerBgColor);
    final PdfBrush whiteBrush = PdfSolidBrush(whiteColor);

    final PdfPen navyOuterPen = PdfPen(navyColor, width: 1.5);
    final PdfPen greenInnerPen = PdfPen(borderDarkColor, width: 0.6);
    final PdfPen tableOuterPen = PdfPen(blackColor, width: 1.0);
    final PdfPen tableGridPen = PdfPen(borderDarkColor, width: 0.8);
    final PdfPen thickBlackPen = PdfPen(blackColor, width: 1.5);

    // ====================================================================
    // LAYOUT CONSTANTS — Proper A4 alignment with generous spacing
    // ====================================================================
    const double outerMargin = 18;
    const double innerMargin = 21.5;
    const double contentLeft = 28;                          // Left content edge inside inner border
    const double contentWidth = pageWidth - (contentLeft * 2); // 539.28
    const double contentRight = contentLeft + contentWidth;

    const double sectionGap = 6;            // Crisp gap between major sections
    const double sectionHeaderH = 18;       // All section headers uniform height
    const double custRowH = 17.5;           // Customer detail row height
    const double sysRowH = 16.5;            // System table row height
    const double finRowH = 17;              // Financial row height
    const double bankRowH = 15.5;           // Bank detail row height
    const double cellPadY = 3.6;            // Vertical text padding inside cells
    const double cellPadX = 8;              // Horizontal text padding inside cells

    // Customer table: label width, colon position, value start
    const double custLabelW = 72;
    const double custColonX = 76;  // relative to cell left
    const double custValX = 82;   // relative to cell left

    // ==========================================
    // 1. DUAL BORDER (Outer Navy 1.5 + Inner Green 0.6)
    // ==========================================
    graphics.drawRectangle(
      pen: navyOuterPen,
      bounds: const Rect.fromLTWH(outerMargin, outerMargin, pageWidth - (outerMargin * 2), pageHeight - (outerMargin * 2)),
    );
    graphics.drawRectangle(
      pen: greenInnerPen,
      bounds: const Rect.fromLTWH(innerMargin, innerMargin, pageWidth - (innerMargin * 2), pageHeight - (innerMargin * 2)),
    );

    // Currency Formatter
    final currencyFormatter = NumberFormat.currency(locale: 'en_IN', symbol: 'Rs. ', decimalDigits: 2);

    // ==========================================
    // 2. HEADER: BRANDING & CONTACT INFO
    // ==========================================
    double y = 32;

    PdfBitmap? logoBitmap;
    try {
      final ByteData logoData = await rootBundle.load('assets/images/logo.png');
      final Uint8List logoBytes = logoData.buffer.asUint8List();
      logoBitmap = PdfBitmap(logoBytes);
    } catch (e) {
      debugPrint('Logo load error in mobile Quotation service: $e');
    }

    // Load Company Stamp & Authorized Signature (DEFAULT: automatically included)
    PdfBitmap? stampAndSigBitmap;
    if (includeStampAndSignature) {
      final stampBytes = await CompanyStampHelper.loadStampAndSignatureBytes(
        customBytes: customStampAndSignatureBytes,
      );
      if (stampBytes != null && stampBytes.isNotEmpty) {
        try {
          stampAndSigBitmap = PdfBitmap(stampBytes);
        } catch (e) {
          debugPrint('Stamp bitmap decoding error in quotation: $e');
        }
      }
    }

    if (logoBitmap != null) {
      graphics.drawImage(logoBitmap, Rect.fromLTWH(contentLeft, y, 52, 52));
    } else {
      graphics.drawRectangle(
        brush: navyBrush,
        bounds: Rect.fromLTWH(contentLeft, y, 50, 50),
      );
      graphics.drawString(
        'SIYA',
        PdfStandardFont(PdfFontFamily.helvetica, 13, style: PdfFontStyle.bold),
        brush: whiteBrush,
        format: PdfStringFormat(alignment: PdfTextAlignment.center, lineAlignment: PdfVerticalAlignment.middle),
        bounds: Rect.fromLTWH(contentLeft, y, 50, 50),
      );
    }

    final double headerTextLeft = contentLeft + 58;

    graphics.drawString(
      'SIYA INFOTECH & DIGITAL SOLUTIONS',
      companyTitleFont,
      brush: navyBrush,
      bounds: Rect.fromLTWH(headerTextLeft, y, 290, 20),
    );

    graphics.drawString(
      'Solar Solutions & Digital Services',
      companySubTitleFont,
      brush: emeraldBrush,
      bounds: Rect.fromLTWH(headerTextLeft, y + 17, 290, 14),
    );

    graphics.drawString(
      'PM Surya Ghar Yojana - Authorized Vendor',
      headerRightBoldFont,
      brush: emeraldBrush,
      bounds: Rect.fromLTWH(headerTextLeft, y + 30, 290, 13),
    );

    graphics.drawString(
      'Betawad, Taluka Shindkheda, District Dhule, Maharashtra',
      headerRightMutedFont,
      brush: slateMutedBrush,
      bounds: Rect.fromLTWH(headerTextLeft, y + 42, 290, 12),
    );

    // Header Right Contacts
    graphics.drawString(
      'GSTIN: 27CVTPK6358P1ZD',
      headerRightBoldFont,
      brush: navyBrush,
      format: PdfStringFormat(alignment: PdfTextAlignment.right),
      bounds: Rect.fromLTWH(contentRight - 180, y, 180, 11),
    );

    graphics.drawString(
      'Phone: 7972143798',
      headerRightBoldFont,
      brush: navyBrush,
      format: PdfStringFormat(alignment: PdfTextAlignment.right),
      bounds: Rect.fromLTWH(contentRight - 180, y + 11, 180, 11),
    );

    graphics.drawString(
      'Email: siyainfodigital@gmail.com',
      headerRightFont,
      brush: slateBodyBrush,
      format: PdfStringFormat(alignment: PdfTextAlignment.right),
      bounds: Rect.fromLTWH(contentRight - 180, y + 22, 180, 11),
    );

    graphics.drawString(
      'Betawad, Tal. Shindkheda,',
      headerRightMutedFont,
      brush: slateMutedBrush,
      format: PdfStringFormat(alignment: PdfTextAlignment.right),
      bounds: Rect.fromLTWH(contentRight - 180, y + 33, 180, 10),
    );

    graphics.drawString(
      'Dist. Dhule, Maharashtra - 425403',
      headerRightMutedFont,
      brush: slateMutedBrush,
      format: PdfStringFormat(alignment: PdfTextAlignment.right),
      bounds: Rect.fromLTWH(contentRight - 180, y + 43, 180, 10),
    );

    y += 56;

    // Triple-Tone Separator Line (Deep Blue + Green + Golden Yellow)
    graphics.drawLine(
      PdfPen(navyColor, width: 2.0),
      Offset(contentLeft, y),
      Offset(contentLeft + (contentWidth * 0.55), y),
    );
    graphics.drawLine(
      PdfPen(emeraldColor, width: 2.0),
      Offset(contentLeft + (contentWidth * 0.55), y),
      Offset(contentLeft + (contentWidth * 0.85), y),
    );
    graphics.drawLine(
      PdfPen(goldenYellowColor, width: 2.0),
      Offset(contentLeft + (contentWidth * 0.85), y),
      Offset(contentRight, y),
    );

    y += 8;

    // ==========================================
    // 3. QUOTATION TITLE BANNER
    // ==========================================
    const double titleBoxH = 34;
    graphics.drawRectangle(
      brush: whiteBrush,
      pen: tableOuterPen,
      bounds: Rect.fromLTWH(contentLeft, y, contentWidth, titleBoxH),
    );

    graphics.drawString(
      'SOLAR SYSTEM QUOTATION',
      bannerTitleFont,
      brush: darkTextBrush,
      bounds: Rect.fromLTWH(contentLeft + 12, y + 4.5, 280, 15),
    );

    graphics.drawString(
      'For Bank Loan / Finance Purpose',
      bannerSubTitleFont,
      brush: slateBodyBrush,
      bounds: Rect.fromLTWH(contentLeft + 12, y + 20, 280, 11),
    );

    graphics.drawString(
      'Quotation No.: ${quotation.quotationNo}',
      bannerSubTitleFont,
      brush: darkTextBrush,
      format: PdfStringFormat(alignment: PdfTextAlignment.right),
      bounds: Rect.fromLTWH(contentRight - 220, y + 4.5, 208, 15),
    );

    graphics.drawString(
      'Date: ${quotation.formattedDate}',
      bannerSubTitleFont,
      brush: darkTextBrush,
      format: PdfStringFormat(alignment: PdfTextAlignment.right),
      bounds: Rect.fromLTWH(contentRight - 220, y + 20, 208, 11),
    );

    y += titleBoxH + sectionGap;

    // ==========================================
    // HELPER: Draw a section header with navy accent notch
    // ==========================================
    void drawSectionHeader(double atY, double width, String title, {double left = contentLeft}) {
      graphics.drawRectangle(
        brush: headerBgBrush,
        pen: tableOuterPen,
        bounds: Rect.fromLTWH(left, atY, width, sectionHeaderH),
      );
      // Navy accent bar (4pt wide)
      graphics.drawRectangle(
        brush: navyBrush,
        bounds: Rect.fromLTWH(left, atY, 4, sectionHeaderH),
      );
      graphics.drawString(
        title,
        sectionHeaderFont,
        brush: darkTextBrush,
        bounds: Rect.fromLTWH(left + 10, atY + 4.2, width - 16, sectionHeaderH - 4),
      );
    }

    // ==========================================
    // 4. CUSTOMER DETAILS
    // ==========================================
    drawSectionHeader(y, contentWidth, 'CUSTOMER DETAILS (As per Customer Profile)');
    y += sectionHeaderH;

    const double halfW = contentWidth / 2;

    final customerRows = [
      [
        {'label': 'Customer Name', 'val': quotation.customerName, 'bold': 'true'},
        {'label': 'Consumer No.', 'val': quotation.consumerNo, 'bold': 'true'},
      ],
      [
        {'label': 'Address', 'val': quotation.address.isNotEmpty ? quotation.address : 'Betawad', 'bold': 'false'},
        {'label': 'Village / City', 'val': quotation.villageCity.isNotEmpty ? quotation.villageCity : 'Betawad', 'bold': 'false'},
      ],
      [
        {'label': 'District', 'val': quotation.district.isNotEmpty ? quotation.district : 'Dhule', 'bold': 'false'},
        {'label': 'Mobile No.', 'val': quotation.mobileNo.isNotEmpty ? quotation.mobileNo : 'N/A', 'bold': 'false'},
      ],
    ];

    for (int r = 0; r < customerRows.length; r++) {
      final isZebra = r % 2 == 1;
      if (isZebra) {
        graphics.drawRectangle(
          brush: zebraBgBrush,
          bounds: Rect.fromLTWH(contentLeft, y, contentWidth, custRowH),
        );
      }
      // Outer border
      graphics.drawRectangle(
        pen: tableGridPen,
        bounds: Rect.fromLTWH(contentLeft, y, contentWidth, custRowH),
      );
      // Vertical divider between left and right columns
      graphics.drawLine(
        tableGridPen,
        Offset(contentLeft + halfW, y),
        Offset(contentLeft + halfW, y + custRowH),
      );

      // Left Column
      final leftData = customerRows[r][0];
      graphics.drawString(
        leftData['label']!,
        labelFont,
        brush: darkTextBrush,
        bounds: Rect.fromLTWH(contentLeft + cellPadX, y + cellPadY, custLabelW, custRowH),
      );
      graphics.drawString(
        ':',
        labelFont,
        brush: darkTextBrush,
        bounds: Rect.fromLTWH(contentLeft + custColonX, y + cellPadY, 6, custRowH),
      );
      final leftFont = leftData['bold'] == 'true'
          ? valueBoldFont
          : (leftData['val']!.length > 30
              ? PdfStandardFont(PdfFontFamily.helvetica, 7.0)
              : valueFont);
      graphics.drawString(
        leftData['val']!,
        leftFont,
        brush: darkTextBrush,
        format: PdfStringFormat(wordWrap: PdfWordWrapType.none),
        bounds: Rect.fromLTWH(contentLeft + custValX, y + cellPadY, halfW - custValX - 4, custRowH - cellPadY),
      );

      // Right Column (if present)
      final rightData = customerRows[r][1];
      if (rightData['label']!.isNotEmpty) {
        graphics.drawString(
          rightData['label']!,
          labelFont,
          brush: darkTextBrush,
          bounds: Rect.fromLTWH(contentLeft + halfW + cellPadX, y + cellPadY, custLabelW, custRowH),
        );
        graphics.drawString(
          ':',
          labelFont,
          brush: darkTextBrush,
          bounds: Rect.fromLTWH(contentLeft + halfW + custColonX, y + cellPadY, 6, custRowH),
        );
        graphics.drawString(
          rightData['val']!,
          rightData['bold'] == 'true' ? valueBoldFont : valueFont,
          brush: darkTextBrush,
          bounds: Rect.fromLTWH(contentLeft + halfW + custValX, y + cellPadY, halfW - custValX - 6, custRowH),
        );
      }

      y += custRowH;
    }

    y += sectionGap;

    // ==========================================
    // 5. SYSTEM DETAILS TABLE
    // ==========================================
    drawSectionHeader(y, contentWidth, 'SYSTEM DETAILS & TECHNICAL SPECIFICATIONS (${quotation.systemCapacity} ${quotation.systemType})');
    y += sectionHeaderH;

    // Column widths for system table (sum = contentWidth = 539.28)
    const double colSrW = 32;
    const double colItemW = 145;
    const double colQtyW = 75;
    final double colSpecW = contentWidth - colSrW - colItemW - colQtyW; // ~287.28

    // Table sub-header row
    const double tblHeaderH = 18;
    graphics.drawRectangle(
      brush: headerBgBrush,
      pen: tableGridPen,
      bounds: Rect.fromLTWH(contentLeft, y, contentWidth, tblHeaderH),
    );
    // Vertical grid lines in header
    graphics.drawLine(tableGridPen, Offset(contentLeft + colSrW, y), Offset(contentLeft + colSrW, y + tblHeaderH));
    graphics.drawLine(tableGridPen, Offset(contentLeft + colSrW + colItemW, y), Offset(contentLeft + colSrW + colItemW, y + tblHeaderH));
    graphics.drawLine(tableGridPen, Offset(contentLeft + colSrW + colItemW + colSpecW, y), Offset(contentLeft + colSrW + colItemW + colSpecW, y + tblHeaderH));

    graphics.drawString('Sr.', tableHeaderFont, brush: darkTextBrush,
      format: PdfStringFormat(alignment: PdfTextAlignment.center),
      bounds: Rect.fromLTWH(contentLeft, y + cellPadY, colSrW, tblHeaderH));
    graphics.drawString('Component / Description', tableHeaderFont, brush: darkTextBrush,
      bounds: Rect.fromLTWH(contentLeft + colSrW + 8, y + cellPadY, colItemW - 14, tblHeaderH));
    graphics.drawString('Technical Specification / Standard', tableHeaderFont, brush: darkTextBrush,
      bounds: Rect.fromLTWH(contentLeft + colSrW + colItemW + 8, y + cellPadY, colSpecW - 14, tblHeaderH));
    graphics.drawString('Quantity', tableHeaderFont, brush: darkTextBrush,
      format: PdfStringFormat(alignment: PdfTextAlignment.center),
      bounds: Rect.fromLTWH(contentLeft + colSrW + colItemW + colSpecW, y + cellPadY, colQtyW, tblHeaderH));

    y += tblHeaderH;

    // System data rows
    for (int i = 0; i < quotation.items.length; i++) {
      final item = quotation.items[i];
      final isZebra = i % 2 == 1;

      if (isZebra) {
        graphics.drawRectangle(
          brush: zebraBgBrush,
          bounds: Rect.fromLTWH(contentLeft, y, contentWidth, sysRowH),
        );
      }
      // Row border
      graphics.drawRectangle(
        pen: tableGridPen,
        bounds: Rect.fromLTWH(contentLeft, y, contentWidth, sysRowH),
      );
      // Vertical grid lines
      graphics.drawLine(tableGridPen, Offset(contentLeft + colSrW, y), Offset(contentLeft + colSrW, y + sysRowH));
      graphics.drawLine(tableGridPen, Offset(contentLeft + colSrW + colItemW, y), Offset(contentLeft + colSrW + colItemW, y + sysRowH));
      graphics.drawLine(tableGridPen, Offset(contentLeft + colSrW + colItemW + colSpecW, y), Offset(contentLeft + colSrW + colItemW + colSpecW, y + sysRowH));

      graphics.drawString(item['sr'] ?? '${i + 1}', valueFont, brush: darkTextBrush,
        format: PdfStringFormat(alignment: PdfTextAlignment.center),
        bounds: Rect.fromLTWH(contentLeft, y + cellPadY, colSrW, sysRowH));

      graphics.drawString(item['item'] ?? '', valueBoldFont, brush: darkTextBrush,
        bounds: Rect.fromLTWH(contentLeft + colSrW + 8, y + cellPadY, colItemW - 14, sysRowH));

      graphics.drawString(item['spec'] ?? '', valueFont, brush: slateBodyBrush,
        bounds: Rect.fromLTWH(contentLeft + colSrW + colItemW + 8, y + cellPadY, colSpecW - 14, sysRowH));

      graphics.drawString(item['qty'] ?? '', valueBoldFont, brush: darkTextBrush,
        format: PdfStringFormat(alignment: PdfTextAlignment.center),
        bounds: Rect.fromLTWH(contentLeft + colSrW + colItemW + colSpecW, y + cellPadY, colQtyW, sysRowH));

      y += sysRowH;
    }

    y += sectionGap;

    // ==========================================
    // 6. FINANCIAL DETAILS & BANK ACCOUNT (Side-by-Side)
    // ==========================================
    final gst = quotation.gstBreakdown;

    const double gstRowH = 14.0;
    const double grandTotalRowH = 18.0;
    const double rightFinRowH = 14.0;
    const double rightBankRowH = 11.0;
    const double rightSubGap = 4.0;

    // Both left and right boxes are exactly 134 pt tall:
    // Left:  18 (header) + (7 * 14.0) + 18.0 = 134.0
    // Right: 18 (header1) + (2 * 14.0) + 4.0 (gap) + 18 (header2) + (6 * 11.0) = 134.0
    const double sideBySideTotalH = 134.0;

    const double gap = 10; // gap between left and right boxes
    final double leftBoxW = (contentWidth - gap) / 2; // ~264.64
    final double rightBoxW = contentWidth - leftBoxW - gap; // ~264.64
    final double rightBoxLeft = contentLeft + leftBoxW + gap;

    final PdfFont gstLabelFont = PdfStandardFont(PdfFontFamily.helvetica, 7.5, style: PdfFontStyle.bold);
    final PdfFont gstValueFont = PdfStandardFont(PdfFontFamily.helvetica, 7.5);
    final PdfFont gstValueBoldFont = PdfStandardFont(PdfFontFamily.helvetica, 7.5, style: PdfFontStyle.bold);
    final PdfFont bankSmallLabelFont = PdfStandardFont(PdfFontFamily.helvetica, 7.0, style: PdfFontStyle.bold);
    final PdfFont bankSmallValueFont = PdfStandardFont(PdfFontFamily.helvetica, 7.0);
    final PdfFont bankSmallValueBold = PdfStandardFont(PdfFontFamily.helvetica, 7.0, style: PdfFontStyle.bold);

    // --- Left: GST Module & Financial Details ---
    drawSectionHeader(y, leftBoxW, 'GST MODULE & FINANCIAL DETAILS');

    final gstRows = [
      {'label': 'Total Amount (Including GST)', 'val': quotation.grandTotal > 0 ? currencyFormatter.format(gst.totalAmount) : 'Rs. ____________', 'bold': 'true', 'zebra': 'false'},
      {'label': '70% Portion @ 5%', 'val': quotation.grandTotal > 0 ? currencyFormatter.format(gst.portion70) : 'Rs. ____________', 'bold': 'false', 'zebra': 'true'},
      {'label': 'GST Included @ 5%', 'val': quotation.grandTotal > 0 ? currencyFormatter.format(gst.gst5) : 'Rs. ____________', 'bold': 'false', 'zebra': 'false'},
      {'label': '30% Portion @ 18%', 'val': quotation.grandTotal > 0 ? currencyFormatter.format(gst.portion30) : 'Rs. ____________', 'bold': 'false', 'zebra': 'true'},
      {'label': 'GST Included @ 18%', 'val': quotation.grandTotal > 0 ? currencyFormatter.format(gst.gst18) : 'Rs. ____________', 'bold': 'false', 'zebra': 'false'},
      {'label': 'Total Taxable Value', 'val': quotation.grandTotal > 0 ? currencyFormatter.format(gst.totalTaxableValue) : 'Rs. ____________', 'bold': 'true', 'zebra': 'true'},
      {'label': 'Total GST Included', 'val': quotation.grandTotal > 0 ? currencyFormatter.format(gst.totalGstIncluded) : 'Rs. ____________', 'bold': 'true', 'zebra': 'false'},
    ];

    double finY = y + sectionHeaderH;
    for (int i = 0; i < gstRows.length; i++) {
      final f = gstRows[i];
      final isZebra = f['zebra'] == 'true';

      if (isZebra) {
        graphics.drawRectangle(
          brush: zebraBgBrush,
          bounds: Rect.fromLTWH(contentLeft, finY, leftBoxW, gstRowH),
        );
      }
      graphics.drawRectangle(
        pen: tableGridPen,
        bounds: Rect.fromLTWH(contentLeft, finY, leftBoxW, gstRowH),
      );

      graphics.drawString(
        f['label']!,
        gstLabelFont,
        brush: darkTextBrush,
        bounds: Rect.fromLTWH(contentLeft + cellPadX, finY + 2.6, 142, gstRowH),
      );
      graphics.drawString(
        ':',
        gstLabelFont,
        brush: darkTextBrush,
        bounds: Rect.fromLTWH(contentLeft + 144, finY + 2.6, 6, gstRowH),
      );
      graphics.drawString(
        f['val']!,
        f['bold'] == 'true' ? gstValueBoldFont : gstValueFont,
        brush: darkTextBrush,
        format: PdfStringFormat(alignment: PdfTextAlignment.right),
        bounds: Rect.fromLTWH(contentLeft + 152, finY + 2.6, leftBoxW - 158, gstRowH),
      );

      finY += gstRowH;
    }

    // Grand Total (Including GST) Row with soft gold background
    graphics.drawRectangle(
      brush: PdfSolidBrush(PdfColor(254, 252, 232)),
      pen: thickBlackPen,
      bounds: Rect.fromLTWH(contentLeft, finY, leftBoxW, grandTotalRowH),
    );
    // Golden Yellow accent indicator on left edge
    graphics.drawRectangle(
      brush: goldenYellowBrush,
      bounds: Rect.fromLTWH(contentLeft, finY, 3.5, grandTotalRowH),
    );
    graphics.drawString(
      'Grand Total (Including GST)',
      grandTotalLabelFont,
      brush: darkTextBrush,
      bounds: Rect.fromLTWH(contentLeft + cellPadX, finY + 3.8, 142, grandTotalRowH),
    );
    graphics.drawString(
      ':',
      grandTotalLabelFont,
      brush: darkTextBrush,
      bounds: Rect.fromLTWH(contentLeft + 144, finY + 3.8, 6, grandTotalRowH),
    );
    graphics.drawString(
      quotation.grandTotal > 0 ? currencyFormatter.format(quotation.grandTotal) : 'Rs. ____________',
      grandTotalValFont,
      brush: darkTextBrush,
      format: PdfStringFormat(alignment: PdfTextAlignment.right),
      bounds: Rect.fromLTWH(contentLeft + 152, finY + 3.2, leftBoxW - 158, grandTotalRowH),
    );

    // --- Right: Bank Financing & Bank Account Details ---
    double rightY = y;

    // 1. Bank Financing (90:10 Ratio)
    drawSectionHeader(rightY, rightBoxW, 'BANK FINANCING (90:10 Ratio)', left: rightBoxLeft);
    rightY += sectionHeaderH;

    final financeRows = [
      {'label': 'Bank Loan Amount (90%)', 'val': quotation.bankLoanAmount > 0 ? currencyFormatter.format(quotation.bankLoanAmount) : 'Rs. ____________', 'bold': 'true', 'zebra': 'false'},
      {'label': 'Customer Contribution (10%)', 'val': quotation.customerContribution > 0 ? currencyFormatter.format(quotation.customerContribution) : 'Rs. ____________', 'bold': 'false', 'zebra': 'true'},
    ];

    for (int i = 0; i < financeRows.length; i++) {
      final f = financeRows[i];
      final isZebra = f['zebra'] == 'true';

      if (isZebra) {
        graphics.drawRectangle(
          brush: zebraBgBrush,
          bounds: Rect.fromLTWH(rightBoxLeft, rightY, rightBoxW, rightFinRowH),
        );
      }
      graphics.drawRectangle(
        pen: tableGridPen,
        bounds: Rect.fromLTWH(rightBoxLeft, rightY, rightBoxW, rightFinRowH),
      );

      graphics.drawString(
        f['label']!,
        gstLabelFont,
        brush: darkTextBrush,
        bounds: Rect.fromLTWH(rightBoxLeft + cellPadX, rightY + 2.6, 142, rightFinRowH),
      );
      graphics.drawString(
        ':',
        gstLabelFont,
        brush: darkTextBrush,
        bounds: Rect.fromLTWH(rightBoxLeft + 144, rightY + 2.6, 6, rightFinRowH),
      );
      graphics.drawString(
        f['val']!,
        f['bold'] == 'true' ? gstValueBoldFont : gstValueFont,
        brush: darkTextBrush,
        format: PdfStringFormat(alignment: PdfTextAlignment.right),
        bounds: Rect.fromLTWH(rightBoxLeft + 152, rightY + 2.6, rightBoxW - 158, rightFinRowH),
      );

      rightY += rightFinRowH;
    }

    rightY += rightSubGap;

    // 2. Bank Account (For Loan Disbursement)
    drawSectionHeader(rightY, rightBoxW, 'BANK ACCOUNT (For Loan Disbursement)', left: rightBoxLeft);
    rightY += sectionHeaderH;

    final bankRows = [
      {'label': 'Account Name', 'val': 'SIYA INFOTECH & DIGITAL SOLUTIONS', 'bold': 'true'},
      {'label': 'Bank Name', 'val': quotation.bankName, 'bold': 'false'},
      {'label': 'Branch', 'val': quotation.branch, 'bold': 'false'},
      {'label': 'Account No.', 'val': quotation.accountNo, 'bold': 'true'},
      {'label': 'IFSC Code', 'val': quotation.ifscCode, 'bold': 'true'},
      {'label': 'UPI ID', 'val': quotation.upiId, 'bold': 'false'},
    ];

    for (int i = 0; i < bankRows.length; i++) {
      final b = bankRows[i];
      if (i % 2 == 1) {
        graphics.drawRectangle(
          brush: zebraBgBrush,
          bounds: Rect.fromLTWH(rightBoxLeft, rightY, rightBoxW, rightBankRowH),
        );
      }
      graphics.drawRectangle(
        pen: tableGridPen,
        bounds: Rect.fromLTWH(rightBoxLeft, rightY, rightBoxW, rightBankRowH),
      );

      graphics.drawString(
        b['label']!,
        bankSmallLabelFont,
        brush: darkTextBrush,
        bounds: Rect.fromLTWH(rightBoxLeft + cellPadX, rightY + 1.8, 76, rightBankRowH),
      );
      graphics.drawString(
        ':',
        bankSmallLabelFont,
        brush: darkTextBrush,
        bounds: Rect.fromLTWH(rightBoxLeft + 78, rightY + 1.8, 6, rightBankRowH),
      );
      graphics.drawString(
        b['val']!,
        b['bold'] == 'true' ? bankSmallValueBold : bankSmallValueFont,
        brush: darkTextBrush,
        bounds: Rect.fromLTWH(rightBoxLeft + 86, rightY + 1.8, rightBoxW - 92, rightBankRowH),
      );

      rightY += rightBankRowH;
    }

    y += sideBySideTotalH + sectionGap;

    // Amount in Words (Full Width)
    const double wordsBoxH = 20;
    graphics.drawRectangle(
      brush: whiteBrush,
      pen: tableOuterPen,
      bounds: Rect.fromLTWH(contentLeft, y, contentWidth, wordsBoxH),
    );
    graphics.drawString('Amount in Words: ', wordsFont, brush: darkTextBrush,
      bounds: Rect.fromLTWH(contentLeft + cellPadX, y + cellPadY, 100, wordsBoxH));
    final String qWords = quotation.grandTotal > 0 && quotation.amountInWords.trim().isNotEmpty
        ? quotation.amountInWords
        : '________________________________________________';
    graphics.drawString(qWords, wordsFont, brush: darkTextBrush,
      bounds: Rect.fromLTWH(contentLeft + 108, y + cellPadY, contentWidth - 116, wordsBoxH));

    y += wordsBoxH + sectionGap;

    // ==========================================
    // 7. SCOPE OF WORK & IMPORTANT NOTES (Side-by-Side, equal height)
    // ==========================================
    final scopeItems = [
      'Supply of solar panels and inverter',
      'GI mounting structure',
      'DC/AC cabling',
      'ACDB/DCDB',
      'Earthing',
      'Installation & commissioning',
      'Net-metering assistance',
      'Testing and handover',
    ];

    final notes = [
      '1. Quotation prepared for bank loan / finance processing.',
      '2. Equipment make/model may vary based on availability.',
      '3. Government subsidy, if applicable, is subject to prevailing government rules and eligibility.',
      '4. Electricity-board charges, statutory fees and additional civil work, if applicable, may be charged separately.',
      '5. Installation will follow applicable MSEDCL/MNRE requirements.',
      '6. Quotation validity: 30 days.',
    ];

    const double bulletLineH = 11.0;
    const double noteLineH = 13.5;
    final double scopeContentH = scopeItems.length * bulletLineH + 6; // ~94
    final double notesContentH = notes.length * noteLineH + 6;       // ~87
    final double notesBoxContentH = scopeContentH > notesContentH ? scopeContentH : notesContentH;
    final double notesTotalH = sectionHeaderH + notesBoxContentH;

    final double scopeW = leftBoxW;
    final double notesW = rightBoxW;
    final double notesLeft = rightBoxLeft;

    // Left: Scope of Work
    drawSectionHeader(y, scopeW, 'SCOPE OF WORK');
    graphics.drawRectangle(
      brush: whiteBrush,
      pen: tableGridPen,
      bounds: Rect.fromLTWH(contentLeft, y + sectionHeaderH, scopeW, notesBoxContentH),
    );

    double scopeItemY = y + sectionHeaderH + 6;
    for (final item in scopeItems) {
      graphics.drawString('•', PdfStandardFont(PdfFontFamily.helvetica, 8, style: PdfFontStyle.bold),
        brush: darkTextBrush,
        bounds: Rect.fromLTWH(contentLeft + cellPadX, scopeItemY, 8, bulletLineH));
      graphics.drawString(item, bulletFont, brush: darkTextBrush,
        bounds: Rect.fromLTWH(contentLeft + cellPadX + 10, scopeItemY, scopeW - 24, bulletLineH));
      scopeItemY += bulletLineH;
    }

    // Right: Important Notes
    drawSectionHeader(y, notesW, 'IMPORTANT NOTES & CONDITIONS', left: notesLeft);
    graphics.drawRectangle(
      brush: whiteBrush,
      pen: tableGridPen,
      bounds: Rect.fromLTWH(notesLeft, y + sectionHeaderH, notesW, notesBoxContentH),
    );

    double noteItemY = y + sectionHeaderH + 5;
    for (final note in notes) {
      graphics.drawString(note, bulletFont, brush: darkTextBrush,
        bounds: Rect.fromLTWH(notesLeft + cellPadX, noteItemY, notesW - 16, noteLineH));
      noteItemY += noteLineH;
    }

    y += notesTotalH + 10; // Balanced space before signatures

    // ==========================================
    // 8. SIGNATURES & STAMPS (Customer & Vendor Dual Layout)
    // Positioned in the lower open space above the footer
    // ==========================================
    const double signBlockTotalH = 132;
    const double footerLineY = pageHeight - 38;
    final double signYBottomTarget = footerLineY - signBlockTotalH;
    final double signYStart = signYBottomTarget > (y + 10) ? signYBottomTarget : (y + 10);
    const double lineWidth = 160;

    // --- LEFT COLUMN: Customer Acceptance & Signature ---
    final double custSignLeft = contentLeft;
    const double custSignWidth = 220;
    double custY = signYStart;

    graphics.drawString(
      'Customer Acceptance',
      signHeaderFont,
      brush: darkTextBrush,
      bounds: Rect.fromLTWH(custSignLeft, custY, custSignWidth, 12),
    );
    custY += 14;

    graphics.drawString(
      'I/We accept the quotation, technical specifications & payment terms.',
      signSubFont,
      brush: slateMutedBrush,
      bounds: Rect.fromLTWH(custSignLeft, custY, custSignWidth, 10),
    );

    // --- RIGHT COLUMN: Vendor Authorization & Official Stamp ---
    const double vendorSignWidth = 210;
    final double vendorSignLeft = contentRight - vendorSignWidth;
    double vendorY = signYStart;

    graphics.drawString(
      'For SIYA INFOTECH & DIGITAL SOLUTIONS',
      signHeaderFont,
      brush: darkTextBrush,
      format: PdfStringFormat(alignment: PdfTextAlignment.center),
      bounds: Rect.fromLTWH(vendorSignLeft, vendorY, vendorSignWidth, 12),
    );
    vendorY += 14;

    // Vendor Official Stamp space:
    const double stampDiam = 66;

    // Unified Baseline: Both Customer & Vendor lines sit at the EXACT SAME horizontal Y!
    final double commonLineY = vendorY + stampDiam + 22;

    // Left Signature Line
    graphics.drawLine(
      tableOuterPen,
      Offset(custSignLeft, commonLineY),
      Offset(custSignLeft + lineWidth, commonLineY),
    );

    graphics.drawString(
      'Customer Signature',
      signTitleFont,
      brush: darkTextBrush,
      bounds: Rect.fromLTWH(custSignLeft, commonLineY + 4, custSignWidth, 11),
    );

    graphics.drawString(
      quotation.customerName,
      signSubFont,
      brush: slateMutedBrush,
      bounds: Rect.fromLTWH(custSignLeft, commonLineY + 16, custSignWidth, 10),
    );

    // Right Signature Line (Identical 160pt width, perfectly centered under vendor column)
    final double vendorLineL = vendorSignLeft + ((vendorSignWidth - lineWidth) / 2);
    graphics.drawLine(
      tableOuterPen,
      Offset(vendorLineL, commonLineY),
      Offset(vendorLineL + lineWidth, commonLineY),
    );

    // Draw Company Stamp & Authorized Signature ON TOP OF the line ("reshcya var")
    // Stamp size: 38mm x 38mm (108pt x 108pt) round stamp
    // Composite artwork is 540x400 (aspect ratio 1.35)
    // At height 108pt, width is 146pt, centered over the 160pt line
    if (includeStampAndSignature) {
      const double pairW = 146;
      const double pairH = 108;
      final double pairX = vendorLineL + (lineWidth - pairW) / 2;
      // Signature baseline rests directly on commonLineY
      final double pairY = commonLineY - 84;
      CompanyStampHelper.drawStampAndSignature(
        graphics: graphics,
        bounds: Rect.fromLTWH(pairX, pairY, pairW, pairH),
        bitmap: stampAndSigBitmap,
        include: includeStampAndSignature,
      );
    }

    graphics.drawString(
      'Authorized Signatory',
      signTitleFont,
      brush: darkTextBrush,
      format: PdfStringFormat(alignment: PdfTextAlignment.center),
      bounds: Rect.fromLTWH(vendorSignLeft, commonLineY + 4, vendorSignWidth, 11),
    );

    graphics.drawString(
      '(Vendor Stamp & Signature)',
      signSubFont,
      brush: slateMutedBrush,
      format: PdfStringFormat(alignment: PdfTextAlignment.center),
      bounds: Rect.fromLTWH(vendorSignLeft, commonLineY + 16, vendorSignWidth, 10),
    );

    // ==========================================
    // 9. FOOTER — Pinned at bottom inside inner border
    // ==========================================
    const double footerY = pageHeight - 34;

    graphics.drawLine(
      tableOuterPen,
      Offset(contentLeft, footerY - 4),
      Offset(contentRight, footerY - 4),
    );

    graphics.drawString(
      'GSTIN: 27CVTPK6358P1ZD | Helpline: 7972143798 | Email: siyainfodigital@gmail.com',
      footerFont,
      brush: darkTextBrush,
      bounds: Rect.fromLTWH(contentLeft, footerY, contentWidth * 0.65, 11),
    );

    graphics.drawString(
      'Official Bank Loan & Finance Quotation Document',
      footerBoldFont,
      brush: darkTextBrush,
      format: PdfStringFormat(alignment: PdfTextAlignment.right),
      bounds: Rect.fromLTWH(contentLeft + (contentWidth * 0.4), footerY, contentWidth * 0.6, 11),
    );

    // Save File
    final List<int> bytes = await document.save();
    document.dispose();

    Directory dir;
    try {
      dir = outputDirectory ?? await getApplicationDocumentsDirectory();
    } catch (_) {
      dir = outputDirectory ?? Directory.systemTemp;
    }

    final file = File('${dir.path}/${quotation.pdfFileName}');
    await file.writeAsBytes(bytes, flush: true);

    return file;
  }

  /// Preview the generated quotation in system PDF viewer
  static Future<void> previewQuotation(File file) async {
    await OpenFilex.open(file.path);
  }

  /// Share the quotation PDF via Android native Share Sheet (WhatsApp, Email, etc.)
  static Future<void> shareQuotation(File file, SolarQuotation quotation) async {
    final fileName = file.uri.pathSegments.last;
    final xFile = XFile(
      file.path,
      mimeType: 'application/pdf',
      name: fileName,
    );

    // ignore: deprecated_member_use
    await Share.shareXFiles(
      [xFile],
      subject: 'Bank Loan Solar Quotation - ${quotation.customerName}',
      text: 'Please find attached the Bank Loan Solar Quotation for ${quotation.customerName} (${quotation.systemCapacity} Solar System, Quotation No: ${quotation.quotationNo}).',
    );
  }

  /// Download and copy quotation to device storage (Downloads / Documents)
  static Future<File> downloadQuotation(File sourceFile, SolarQuotation quotation) async {
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
