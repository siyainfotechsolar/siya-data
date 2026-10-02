import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'package:share_plus/share_plus.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/customer_margin_receipt.dart';
import 'company_stamp_helper.dart';

class MarginMoneyReceiptService {
  /// Generate a professional single-page A4 Customer Margin Money Receipt
  /// formatted for Bank Finance (PM Surya Ghar Muft Bijli Yojana).
  static Future<File> generateReceiptPdf({
    required CustomerMarginReceipt receipt,
    Directory? outputDirectory,
    bool includeStampAndSignature = true,
    Uint8List? customStampAndSignatureBytes,
  }) async {
    final PdfDocument document = PdfDocument();
    document.pageSettings.size = PdfPageSize.a4; // 595.28 x 841.89 points
    document.pageSettings.orientation = PdfPageOrientation.portrait;
    document.pageSettings.margins.all = 0;

    final PdfPage page = document.pages.add();
    final PdfGraphics graphics = page.graphics;
    const double pageWidth = 595.28;
    const double pageHeight = 841.89;

    // Fonts
    final PdfFont companyTitleFont = PdfStandardFont(PdfFontFamily.helvetica, 14.0, style: PdfFontStyle.bold);
    final PdfFont companySubTitleFont = PdfStandardFont(PdfFontFamily.helvetica, 8.5, style: PdfFontStyle.bold);
    final PdfFont headerRightBoldFont = PdfStandardFont(PdfFontFamily.helvetica, 8.0, style: PdfFontStyle.bold);
    final PdfFont headerRightFont = PdfStandardFont(PdfFontFamily.helvetica, 7.6);

    final PdfFont bannerTitleFont = PdfStandardFont(PdfFontFamily.helvetica, 10.5, style: PdfFontStyle.bold);
    final PdfFont bannerSubTitleFont = PdfStandardFont(PdfFontFamily.helvetica, 7.5, style: PdfFontStyle.bold);
    final PdfFont sectionHeaderFont = PdfStandardFont(PdfFontFamily.helvetica, 8.2, style: PdfFontStyle.bold);

    final PdfFont cellLabelFont = PdfStandardFont(PdfFontFamily.helvetica, 7.5);
    final PdfFont cellValFont = PdfStandardFont(PdfFontFamily.helvetica, 7.5, style: PdfFontStyle.bold);
    final PdfFont tableHeaderFont = PdfStandardFont(PdfFontFamily.helvetica, 7.8, style: PdfFontStyle.bold);
    final PdfFont bodyFont = PdfStandardFont(PdfFontFamily.helvetica, 7.5);
    final PdfFont bodyBoldFont = PdfStandardFont(PdfFontFamily.helvetica, 7.8, style: PdfFontStyle.bold);
    final PdfFont highlightBigFont = PdfStandardFont(PdfFontFamily.helvetica, 9.5, style: PdfFontStyle.bold);

    final PdfFont noteFont = PdfStandardFont(PdfFontFamily.helvetica, 6.8);
    final PdfFont signHeaderFont = PdfStandardFont(PdfFontFamily.helvetica, 8.5, style: PdfFontStyle.bold);
    final PdfFont signTitleFont = PdfStandardFont(PdfFontFamily.helvetica, 8.0, style: PdfFontStyle.bold);
    final PdfFont signSubFont = PdfStandardFont(PdfFontFamily.helvetica, 7.0);

    final PdfFont footerFont = PdfStandardFont(PdfFontFamily.helvetica, 6.8);
    final PdfFont footerBoldFont = PdfStandardFont(PdfFontFamily.helvetica, 6.8, style: PdfFontStyle.bold);

    // Colors
    final PdfColor navyColor = PdfColor(13, 43, 111); // #0D2B6F
    final PdfColor emeraldColor = PdfColor(4, 120, 87); // #047857
    final PdfColor lightGreenColor = PdfColor(16, 185, 129); // #10B981
    final PdfColor blackColor = PdfColor(15, 23, 42); // #0F172A
    final PdfColor borderDarkColor = PdfColor(51, 65, 85); // #334155
    final PdfColor darkTextColor = PdfColor(15, 23, 42);
    final PdfColor slateBodyColor = PdfColor(30, 41, 59);
    final PdfColor slateMutedColor = PdfColor(71, 85, 105);
    final PdfColor zebraBgColor = PdfColor(248, 250, 252);
    final PdfColor headerBgColor = PdfColor(241, 245, 249);
    final PdfColor whiteColor = PdfColor(255, 255, 255);
    final PdfColor creamYellowColor = PdfColor(254, 252, 232); // #FEFCE8
    final PdfColor amberTextColor = PdfColor(133, 77, 14); // #854D0E

    final PdfBrush navyBrush = PdfSolidBrush(navyColor);
    final PdfBrush emeraldBrush = PdfSolidBrush(emeraldColor);
    final PdfBrush darkTextBrush = PdfSolidBrush(darkTextColor);
    final PdfBrush slateBodyBrush = PdfSolidBrush(slateBodyColor);
    final PdfBrush slateMutedBrush = PdfSolidBrush(slateMutedColor);
    final PdfBrush zebraBgBrush = PdfSolidBrush(zebraBgColor);
    final PdfBrush headerBgBrush = PdfSolidBrush(headerBgColor);
    final PdfBrush whiteBrush = PdfSolidBrush(whiteColor);
    final PdfBrush creamYellowBrush = PdfSolidBrush(creamYellowColor);
    final PdfBrush amberTextBrush = PdfSolidBrush(amberTextColor);

    final PdfPen navyOuterPen = PdfPen(navyColor, width: 1.5);
    final PdfPen greenInnerPen = PdfPen(borderDarkColor, width: 0.6);
    final PdfPen tableOuterPen = PdfPen(blackColor, width: 1.0);
    final PdfPen tableGridPen = PdfPen(borderDarkColor, width: 0.8);
    final PdfPen thickBlackPen = PdfPen(blackColor, width: 1.4);

    const double outerMargin = 18;
    const double innerMargin = 21.5;
    const double contentLeft = 28;
    const double contentWidth = pageWidth - (contentLeft * 2); // 539.28
    const double contentRight = contentLeft + contentWidth;

    // 1. Dual Border
    graphics.drawRectangle(
      pen: navyOuterPen,
      bounds: const Rect.fromLTWH(outerMargin, outerMargin, pageWidth - (outerMargin * 2), pageHeight - (outerMargin * 2)),
    );
    graphics.drawRectangle(
      pen: greenInnerPen,
      bounds: const Rect.fromLTWH(innerMargin, innerMargin, pageWidth - (innerMargin * 2), pageHeight - (innerMargin * 2)),
    );

    final currencyFormatter = NumberFormat.currency(locale: 'en_IN', symbol: 'Rs. ', decimalDigits: 2);
    final dateFormatter = DateFormat('dd/MM/yyyy');

    // 2. Header
    double y = 30;

    PdfBitmap? logoBitmap;
    try {
      final ByteData logoData = await rootBundle.load('assets/images/logo.png');
      final Uint8List logoBytes = logoData.buffer.asUint8List();
      logoBitmap = PdfBitmap(logoBytes);
    } catch (e) {
      debugPrint('Logo load error in mobile margin receipt service: $e');
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
          debugPrint('Stamp bitmap decoding error in margin receipt: $e');
        }
      }
    }

    if (logoBitmap != null) {
      graphics.drawImage(logoBitmap, Rect.fromLTWH(contentLeft, y, 50, 50));
    } else {
      graphics.drawRectangle(
        brush: navyBrush,
        bounds: Rect.fromLTWH(contentLeft, y, 48, 48),
      );
      graphics.drawString(
        'SIYA',
        PdfStandardFont(PdfFontFamily.helvetica, 12, style: PdfFontStyle.bold),
        brush: whiteBrush,
        format: PdfStringFormat(alignment: PdfTextAlignment.center, lineAlignment: PdfVerticalAlignment.middle),
        bounds: Rect.fromLTWH(contentLeft, y, 48, 48),
      );
    }

    final double headerTextLeft = contentLeft + 56;

    graphics.drawString(
      'SIYA INFOTECH AND DIGITAL SOLUTIONS',
      companyTitleFont,
      brush: navyBrush,
      bounds: Rect.fromLTWH(headerTextLeft, y, 290, 18),
    );

    graphics.drawString(
      'Solar Solutions & Digital Engineering Services',
      companySubTitleFont,
      brush: emeraldBrush,
      bounds: Rect.fromLTWH(headerTextLeft, y + 16, 290, 13),
    );

    graphics.drawString(
      'PM Surya Ghar Yojana - Authorized Vendor',
      headerRightBoldFont,
      brush: emeraldBrush,
      bounds: Rect.fromLTWH(headerTextLeft, y + 28, 290, 12),
    );

    graphics.drawString(
      'At Post Betawad, Tal. Sindkheda, Dist. Dhule - 425403 (MH)',
      headerRightFont,
      brush: darkTextBrush,
      bounds: Rect.fromLTWH(headerTextLeft, y + 40, 290, 11),
    );

    // Right Header Box: Official Receipt
    const double rightBoxW = 145;
    final double rightBoxL = contentRight - rightBoxW;

    graphics.drawRectangle(
      brush: headerBgBrush,
      pen: tableGridPen,
      bounds: Rect.fromLTWH(rightBoxL, y + 2, rightBoxW, 46),
    );

    graphics.drawString(
      'OFFICIAL RECEIPT',
      headerRightBoldFont,
      brush: navyBrush,
      format: PdfStringFormat(alignment: PdfTextAlignment.center),
      bounds: Rect.fromLTWH(rightBoxL, y + 6, rightBoxW, 12),
    );
    graphics.drawString(
      'Bank Solar Loan Finance',
      headerRightFont,
      brush: emeraldBrush,
      format: PdfStringFormat(alignment: PdfTextAlignment.center),
      bounds: Rect.fromLTWH(rightBoxL, y + 19, rightBoxW, 11),
    );
    graphics.drawString(
      '10% Customer Margin Money',
      headerRightBoldFont,
      brush: darkTextBrush,
      format: PdfStringFormat(alignment: PdfTextAlignment.center),
      bounds: Rect.fromLTWH(rightBoxL, y + 31, rightBoxW, 11),
    );

    y += 56;

    // 3. Document Title Banner
    const double bannerH = 28;
    graphics.drawRectangle(
      brush: navyBrush,
      bounds: Rect.fromLTWH(contentLeft, y, contentWidth, bannerH),
    );

    graphics.drawString(
      'CUSTOMER MARGIN MONEY / ADVANCE PAYMENT RECEIPT',
      bannerTitleFont,
      brush: whiteBrush,
      format: PdfStringFormat(alignment: PdfTextAlignment.center),
      bounds: Rect.fromLTWH(contentLeft, y + 3, contentWidth, 14),
    );

    graphics.drawString(
      'For Bank Solar Loan / Finance Purpose - PM Surya Ghar Muft Bijli Yojana',
      bannerSubTitleFont,
      brush: PdfSolidBrush(lightGreenColor),
      format: PdfStringFormat(alignment: PdfTextAlignment.center),
      bounds: Rect.fromLTWH(contentLeft, y + 16, contentWidth, 11),
    );

    y += bannerH + 6;

    // 4. Reference Info & Customer Profile (Box with 2 columns)
    const double custBoxH = 58;
    graphics.drawRectangle(
      brush: zebraBgBrush,
      pen: tableOuterPen,
      bounds: Rect.fromLTWH(contentLeft, y, contentWidth, custBoxH),
    );

    final double colHalfW = contentWidth / 2;

    // Vertical Divider
    graphics.drawLine(
      tableGridPen,
      Offset(contentLeft + colHalfW, y),
      Offset(contentLeft + colHalfW, y + custBoxH),
    );

    // Left Column: Receipt Metadata
    double leftColY = y + 4;
    _drawInlineMeta(graphics, 'Receipt No.', receipt.receiptNo, contentLeft + 8, leftColY, 80, cellLabelFont, cellValFont, darkTextBrush);
    leftColY += 13;
    _drawInlineMeta(graphics, 'Receipt Date', dateFormatter.format(receipt.receiptDate), contentLeft + 8, leftColY, 80, cellLabelFont, cellValFont, darkTextBrush);
    leftColY += 13;
    _drawInlineMeta(graphics, 'Linked Quotation', receipt.quotationNo, contentLeft + 8, leftColY, 80, cellLabelFont, cellValFont, darkTextBrush);
    leftColY += 13;
    _drawInlineMeta(graphics, 'Quotation Date', dateFormatter.format(receipt.quotationDate), contentLeft + 8, leftColY, 80, cellLabelFont, cellValFont, darkTextBrush);

    // Right Column: Customer Info
    double rightColY = y + 4;
    final double rightColX = contentLeft + colHalfW + 8;
    _drawInlineMeta(graphics, 'Customer Name', receipt.customerName, rightColX, rightColY, 80, cellLabelFont, cellValFont, darkTextBrush);
    rightColY += 13;
    _drawInlineMeta(graphics, 'Consumer No.', receipt.consumerNo, rightColX, rightColY, 80, cellLabelFont, cellValFont, darkTextBrush);
    rightColY += 13;
    _drawInlineMeta(graphics, 'Site Address', '${receipt.address}, ${receipt.villageCity}', rightColX, rightColY, 80, cellLabelFont, cellValFont, darkTextBrush);
    rightColY += 13;
    _drawInlineMeta(graphics, 'Contact Mobile', receipt.mobileNo.isNotEmpty ? receipt.mobileNo : 'N/A', rightColX, rightColY, 80, cellLabelFont, cellValFont, darkTextBrush);

    y += custBoxH + 8;

    // 5. Financial Breakdown & Margin Money Received Table
    _drawSectionHeader(graphics, 'FINANCIAL BREAKDOWN & CUSTOMER CONTRIBUTION', contentLeft, y, contentWidth, 16, navyColor, headerBgBrush, tableGridPen, sectionHeaderFont, darkTextBrush);
    y += 16;

    // Table Header
    const double tblHeaderH = 16;
    graphics.drawRectangle(brush: headerBgBrush, pen: tableGridPen, bounds: Rect.fromLTWH(contentLeft, y, contentWidth, tblHeaderH));
    graphics.drawString('Sr.', tableHeaderFont, brush: darkTextBrush, bounds: Rect.fromLTWH(contentLeft + 8, y + 3, 25, 12));
    graphics.drawString('Particulars / Financial Description', tableHeaderFont, brush: darkTextBrush, bounds: Rect.fromLTWH(contentLeft + 35, y + 3, 300, 12));
    graphics.drawString('Percentage', tableHeaderFont, brush: darkTextBrush, format: PdfStringFormat(alignment: PdfTextAlignment.center), bounds: Rect.fromLTWH(contentRight - 180, y + 3, 60, 12));
    graphics.drawString('Amount (Rs.)', tableHeaderFont, brush: darkTextBrush, format: PdfStringFormat(alignment: PdfTextAlignment.right), bounds: Rect.fromLTWH(contentRight - 110, y + 3, 100, 12));
    y += tblHeaderH;

    // Row 1: Total Cost
    const double rowH = 16;
    graphics.drawRectangle(brush: whiteBrush, pen: tableGridPen, bounds: Rect.fromLTWH(contentLeft, y, contentWidth, rowH));
    graphics.drawString('1', bodyFont, brush: slateMutedBrush, bounds: Rect.fromLTWH(contentLeft + 8, y + 3.5, 25, 12));
    graphics.drawString('Total Solar Project / System Cost (${receipt.systemCapacity} ${receipt.systemType})', bodyFont, brush: slateBodyBrush, bounds: Rect.fromLTWH(contentLeft + 35, y + 3.5, 300, 12));
    graphics.drawString('100 %', bodyFont, brush: slateBodyBrush, format: PdfStringFormat(alignment: PdfTextAlignment.center), bounds: Rect.fromLTWH(contentRight - 180, y + 3.5, 60, 12));
    graphics.drawString(receipt.totalSystemCost > 0 ? currencyFormatter.format(receipt.totalSystemCost) : 'Rs. ____________', bodyBoldFont, brush: darkTextBrush, format: PdfStringFormat(alignment: PdfTextAlignment.right), bounds: Rect.fromLTWH(contentRight - 110, y + 3.5, 100, 12));
    y += rowH;

    // Row 2: Bank Loan (90%)
    graphics.drawRectangle(brush: zebraBgBrush, pen: tableGridPen, bounds: Rect.fromLTWH(contentLeft, y, contentWidth, rowH));
    graphics.drawString('2', bodyFont, brush: slateMutedBrush, bounds: Rect.fromLTWH(contentLeft + 8, y + 3.5, 25, 12));
    graphics.drawString('Proposed Bank Loan Amount (To be financed & disbursed by Bank)', bodyFont, brush: slateBodyBrush, bounds: Rect.fromLTWH(contentLeft + 35, y + 3.5, 300, 12));
    graphics.drawString('90 %', bodyFont, brush: slateBodyBrush, format: PdfStringFormat(alignment: PdfTextAlignment.center), bounds: Rect.fromLTWH(contentRight - 180, y + 3.5, 60, 12));
    graphics.drawString(receipt.bankLoanAmount > 0 ? currencyFormatter.format(receipt.bankLoanAmount) : 'Rs. ____________', bodyBoldFont, brush: darkTextBrush, format: PdfStringFormat(alignment: PdfTextAlignment.right), bounds: Rect.fromLTWH(contentRight - 110, y + 3.5, 100, 12));
    y += rowH;

    // Row 3: Highlighted Margin Money Received (10%)
    const double marginRowH = 19;
    graphics.drawRectangle(brush: creamYellowBrush, pen: thickBlackPen, bounds: Rect.fromLTWH(contentLeft, y, contentWidth, marginRowH));
    graphics.drawString('3', bodyBoldFont, brush: darkTextBrush, bounds: Rect.fromLTWH(contentLeft + 8, y + 4.5, 25, 12));
    graphics.drawString('CUSTOMER MARGIN MONEY / CONTRIBUTION RECEIVED', bodyBoldFont, brush: amberTextBrush, bounds: Rect.fromLTWH(contentLeft + 35, y + 4.5, 300, 12));
    graphics.drawString('10 %', highlightBigFont, brush: amberTextBrush, format: PdfStringFormat(alignment: PdfTextAlignment.center), bounds: Rect.fromLTWH(contentRight - 180, y + 4, 60, 14));
    graphics.drawString(receipt.marginAmount > 0 ? currencyFormatter.format(receipt.marginAmount) : 'Rs. ____________', highlightBigFont, brush: amberTextBrush, format: PdfStringFormat(alignment: PdfTextAlignment.right), bounds: Rect.fromLTWH(contentRight - 110, y + 4, 100, 14));
    y += marginRowH;

    // Amount in Words
    const double wordsRowH = 15;
    graphics.drawRectangle(brush: zebraBgBrush, pen: tableGridPen, bounds: Rect.fromLTWH(contentLeft, y, contentWidth, wordsRowH));
    graphics.drawString('Margin Amount in Words: ', bodyBoldFont, brush: darkTextBrush, bounds: Rect.fromLTWH(contentLeft + 8, y + 2.5, 110, 11));
    final String marginWords = receipt.marginAmount > 0 && receipt.marginAmountInWords.trim().isNotEmpty
        ? receipt.marginAmountInWords
        : '________________________________________________';
    graphics.drawString(marginWords, bodyBoldFont, brush: emeraldBrush, bounds: Rect.fromLTWH(contentLeft + 120, y + 2.5, contentWidth - 130, 11));
    y += wordsRowH + 8;

            // 6. Payment Settlement & Vendor Bank Details (Side by side)
    const double splitBoxW = (contentWidth - 8) / 2;
    const double splitBoxH = 68;

    // Left: Payment Settlement Details
    _drawSectionHeader(graphics, 'PAYMENT SETTLEMENT DETAILS', contentLeft, y, splitBoxW, 16, navyColor, headerBgBrush, tableGridPen, sectionHeaderFont, darkTextBrush);
    graphics.drawRectangle(brush: whiteBrush, pen: tableGridPen, bounds: Rect.fromLTWH(contentLeft, y + 16, splitBoxW, splitBoxH));
    double payY = y + 20;
    _drawInlineMeta(graphics, 'Payment Mode', receipt.paymentMode, contentLeft + 6, payY, 80, cellLabelFont, cellValFont, darkTextBrush);
    payY += 13;
    _drawInlineMeta(graphics, 'Transaction Ref', receipt.transactionRef.isEmpty ? 'Paid in Cash' : receipt.transactionRef, contentLeft + 6, payY, 80, cellLabelFont, cellValFont, darkTextBrush);
    payY += 13;
    _drawInlineMeta(graphics, 'Payment Date', dateFormatter.format(receipt.paymentDate), contentLeft + 6, payY, 80, cellLabelFont, cellValFont, darkTextBrush);
    payY += 13;
    _drawInlineMeta(
      graphics,
      'Deposit Status',
      receipt.paymentMode.toLowerCase().contains('cash') ? 'RECEIVED IN CASH' : 'RECEIVED & REALIZED',
      contentLeft + 6,
      payY,
      80,
      cellLabelFont,
      cellValFont,
      emeraldBrush,
    );

    // Right: Vendor Bank (For 90% Loan Disbursement)
    final double bankX = contentLeft + splitBoxW + 8;
    _drawSectionHeader(graphics, 'VENDOR BANK (FOR 90% DISBURSEMENT)', bankX, y, splitBoxW, 16, navyColor, headerBgBrush, tableGridPen, sectionHeaderFont, darkTextBrush);
    graphics.drawRectangle(brush: zebraBgBrush, pen: tableGridPen, bounds: Rect.fromLTWH(bankX, y + 16, splitBoxW, splitBoxH));
    double bnkY = y + 20;
    _drawInlineMeta(graphics, 'Bank & Branch', '${receipt.bankName}, ${receipt.branch}', bankX + 6, bnkY, 78, cellLabelFont, cellValFont, darkTextBrush);
    bnkY += 13;
    _drawInlineMeta(graphics, 'Account Name', 'SIYA INFOTECH AND DIGITAL SOLUTIONS', bankX + 6, bnkY, 78, cellLabelFont, cellValFont, darkTextBrush);
    bnkY += 13;
    _drawInlineMeta(graphics, 'Account No.', receipt.accountNo, bankX + 6, bnkY, 78, cellLabelFont, cellValFont, darkTextBrush);
    bnkY += 13;
    _drawInlineMeta(graphics, 'IFSC & UPI', '${receipt.ifscCode}  |  ${receipt.upiId}', bankX + 6, bnkY, 78, cellLabelFont, cellValFont, darkTextBrush);

    y += 16 + splitBoxH + 12;

        // 7. Undertaking & Declaration for Financing Bank
    _drawSectionHeader(graphics, 'DECLARATION & UNDERTAKING FOR FINANCING BANK', contentLeft, y, contentWidth, 16, navyColor, headerBgBrush, tableGridPen, sectionHeaderFont, darkTextBrush);
    y += 16;

    const double decBoxH = 56;
    graphics.drawRectangle(brush: whiteBrush, pen: tableGridPen, bounds: Rect.fromLTWH(contentLeft, y, contentWidth, decBoxH));
    graphics.drawString(
      '1. We hereby confirm receipt of 10% customer margin money of ${currencyFormatter.format(receipt.marginAmount)} from borrower towards ${receipt.systemCapacity} Grid-Connected Solar Rooftop Power Plant.',
      noteFont,
      brush: slateBodyBrush,
      bounds: Rect.fromLTWH(contentLeft + 6, y + 3, contentWidth - 12, 10),
    );
    graphics.drawString(
      '2. Financing bank is kindly requested to sanction and disburse the remaining 90% loan amount of ${currencyFormatter.format(receipt.bankLoanAmount)} directly into our vendor bank account upon commissioning.',
      noteFont,
      brush: slateBodyBrush,
      bounds: Rect.fromLTWH(contentLeft + 6, y + 14.5, contentWidth - 12, 10),
    );
    graphics.drawString(
      '3. All equipment supplied meets MNRE / MSEDCL technical requirements and BIS standards.',
      noteFont,
      brush: slateBodyBrush,
      bounds: Rect.fromLTWH(contentLeft + 6, y + 26, contentWidth - 12, 10),
    );
    graphics.drawString(
      '4. 5 years comprehensive maintenance & 25 years solar module performance warranty is provided.',
      noteFont,
      brush: slateBodyBrush,
      bounds: Rect.fromLTWH(contentLeft + 6, y + 37.5, contentWidth - 12, 10),
    );
    y += decBoxH;

    // 8. Dual Signatures (Borrower & Vendor Stamp Box) - Standardized layout matching Quotation
    // Positioned in the lower open space above the footer
    const double signBlockTotalH = 132;
    const double footerLineY = pageHeight - 38;
    final double signYBottomTarget = footerLineY - signBlockTotalH;
    final double signYStart = signYBottomTarget > (y + 15) ? signYBottomTarget : (y + 15);

    const double signColW = 210;
    const double lineWidth = 160;

    // Left: Customer Confirmation
    graphics.drawString('Customer / Borrower Confirmation', signHeaderFont, brush: darkTextBrush, bounds: Rect.fromLTWH(contentLeft, signYStart, signColW, 12));
    graphics.drawString('I hereby confirm deposit of margin money for solar installation.', noteFont, brush: slateMutedBrush, bounds: Rect.fromLTWH(contentLeft, signYStart + 14, signColW, 10));

    // Right: Vendor Authorization & Stamp
    final double vendorSignL = contentRight - signColW;
    graphics.drawString('For SIYA INFOTECH AND DIGITAL SOLUTIONS', signHeaderFont, brush: darkTextBrush, format: PdfStringFormat(alignment: PdfTextAlignment.center), bounds: Rect.fromLTWH(vendorSignL, signYStart, signColW, 12));

    // Vendor Official Stamp space:
    const double stampDiam = 66;
    final double stampY = signYStart + 14;

    // Unified Baseline: Both Borrower & Vendor lines sit at the EXACT SAME horizontal Y!
    final double commonLineY = stampY + stampDiam + 22;

    // Left Signature Line (160pt width)
    graphics.drawLine(tableOuterPen, Offset(contentLeft, commonLineY), Offset(contentLeft + lineWidth, commonLineY));
    graphics.drawString('Borrower Signature', signTitleFont, brush: darkTextBrush, bounds: Rect.fromLTWH(contentLeft, commonLineY + 4, signColW, 11));
    graphics.drawString(receipt.customerName, signSubFont, brush: slateMutedBrush, bounds: Rect.fromLTWH(contentLeft, commonLineY + 16, signColW, 10));

    // Right Signature Line (Identical 160pt width, perfectly centered under vendor column)
    final double vendorLineL = vendorSignL + ((signColW - lineWidth) / 2);
    graphics.drawLine(tableOuterPen, Offset(vendorLineL, commonLineY), Offset(vendorLineL + lineWidth, commonLineY));

    // Draw Company Stamp & Authorized Signature ON TOP OF the line ("reshcya var")
    // Stamp size: 38mm x 38mm (108pt x 108pt) round stamp
    // Composite artwork width: 146pt, height: 108pt
    if (includeStampAndSignature) {
      const double pairW = 146;
      const double pairH = 108;
      final double pairX = vendorLineL + (lineWidth - pairW) / 2;
      final double pairY = commonLineY - 84;
      CompanyStampHelper.drawStampAndSignature(
        graphics: graphics,
        bounds: Rect.fromLTWH(pairX, pairY, pairW, pairH),
        bitmap: stampAndSigBitmap,
        include: includeStampAndSignature,
      );
    }
    graphics.drawString('Authorized Signatory', signTitleFont, brush: darkTextBrush, format: PdfStringFormat(alignment: PdfTextAlignment.center), bounds: Rect.fromLTWH(vendorSignL, commonLineY + 4, signColW, 11));
    graphics.drawString('${receipt.signatoryName} • ${receipt.signatoryDesignation} | Betawad', signSubFont, brush: slateMutedBrush, format: PdfStringFormat(alignment: PdfTextAlignment.center), bounds: Rect.fromLTWH(vendorSignL, commonLineY + 16, signColW, 10));

    // 9. Footer
    const double footerY = pageHeight - 34;
    graphics.drawLine(tableOuterPen, Offset(contentLeft, footerY - 4), Offset(contentRight, footerY - 4));
    graphics.drawString(
      'Siya Infotech and Digital Solutions | Customer Margin Money Receipt | PM Surya Ghar',
      footerFont,
      brush: darkTextBrush,
      bounds: Rect.fromLTWH(contentLeft, footerY, contentWidth * 0.65, 11),
    );
    graphics.drawString(
      'Page 1 of 1 | Single-Page A4 Bank Document',
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

    final file = File('${dir.path}/${receipt.pdfFileName}');
    await file.writeAsBytes(bytes, flush: true);

    return file;
  }

  static void _drawSectionHeader(
    PdfGraphics graphics,
    String title,
    double x,
    double y,
    double width,
    double height,
    PdfColor navyColor,
    PdfBrush bgBrush,
    PdfPen pen,
    PdfFont font,
    PdfBrush textBrush,
  ) {
    graphics.drawRectangle(brush: bgBrush, pen: pen, bounds: Rect.fromLTWH(x, y, width, height));
    graphics.drawRectangle(brush: PdfSolidBrush(navyColor), bounds: Rect.fromLTWH(x + 2, y + 3, 3, height - 6));
    graphics.drawString(title, font, brush: textBrush, bounds: Rect.fromLTWH(x + 9, y + 2.5, width - 12, height - 4));
  }

  static void _drawInlineMeta(
    PdfGraphics graphics,
    String label,
    String value,
    double x,
    double y,
    double labelW,
    PdfFont labelFont,
    PdfFont valFont,
    PdfBrush valBrush,
  ) {
    graphics.drawString('$label:', labelFont, brush: PdfSolidBrush(PdfColor(71, 85, 105)), bounds: Rect.fromLTWH(x, y, labelW, 11));
    graphics.drawString(value, valFont, brush: valBrush, bounds: Rect.fromLTWH(x + labelW + 4, y, 180, 11));
  }

  /// Open in system PDF viewer
  static Future<void> previewReceipt(File file) async {
    await OpenFilex.open(file.path);
  }

  /// Share PDF via Android Share Sheet
  static Future<void> shareReceipt(File file, CustomerMarginReceipt receipt) async {
    final fileName = file.uri.pathSegments.last;
    final xFile = XFile(
      file.path,
      mimeType: 'application/pdf',
      name: fileName,
    );

    // ignore: deprecated_member_use
    await Share.shareXFiles(
      [xFile],
      subject: 'Customer Margin Money Receipt - ${receipt.customerName}',
      text: 'Please find attached the Customer Margin Money Receipt for ${receipt.customerName} (${receipt.systemCapacity} Solar System, Receipt No: ${receipt.receiptNo}).',
    );
  }

  /// Download and copy receipt to device storage (Downloads / Documents)
  static Future<File> downloadReceipt(File sourceFile, CustomerMarginReceipt receipt) async {
    final fileName = sourceFile.uri.pathSegments.last;

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

  /// WhatsApp sharing
  static Future<void> shareViaWhatsApp({
    required CustomerMarginReceipt receipt,
    String? customPhone,
  }) async {
    final phone = customPhone ?? receipt.mobileNo;
    final cleanPhone = phone.replaceAll(RegExp(r'\D'), '');
    final targetPhone = cleanPhone.length == 10 ? '91$cleanPhone' : cleanPhone;

    final currency = NumberFormat.currency(locale: 'en_IN', symbol: 'Rs. ', decimalDigits: 0);

    final message = '''
⚡ *SIYA INFOTECH AND DIGITAL SOLUTIONS* ⚡
📄 *CUSTOMER MARGIN MONEY RECEIPT*
_(PM Surya Ghar: Muft Bijli Yojana / Bank Finance)_

Dear *${receipt.customerName}*,
We have received your 10% Customer Margin Money deposit towards the Bank Solar Loan installation.

📋 *Receipt Summary:*
• *Receipt No:* ${receipt.receiptNo}
• *Date:* ${DateFormat('dd-MM-yyyy').format(receipt.receiptDate)}
• *Consumer No:* ${receipt.consumerNo}
• *System Capacity:* ${receipt.systemCapacity}
• *Total Project Cost:* ${currency.format(receipt.totalSystemCost)}
• *Bank Loan Amount (90%):* ${currency.format(receipt.bankLoanAmount)}
• *Margin Money Received (10%):* ${currency.format(receipt.marginAmount)}
• *Payment Mode:* ${receipt.paymentMode}
• *Txn / Ref:* ${receipt.transactionRef}

🏦 *Disbursement Bank:* ${receipt.bankName}, ${receipt.branch}
A/c: ${receipt.accountNo} (IFSC: ${receipt.ifscCode})

Please find your official Customer Margin Money Receipt attached.

Thank you!
*Siya Infotech and Digital Solutions*
Betawad, Dist. Dhule | Mob: 9028888047
''';

    final uri = Uri.parse('https://wa.me/$targetPhone?text=${Uri.encodeComponent(message)}');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
