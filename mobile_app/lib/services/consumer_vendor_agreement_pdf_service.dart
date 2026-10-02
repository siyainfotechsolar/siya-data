import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/consumer_vendor_agreement.dart';
import 'company_stamp_helper.dart';

/// Official Master Reference implementation of Annexure 2 Agreement
/// Strictly follows original PM Surya Ghar: Muft Bijli Yojana Model Draft Agreement.
/// NO company letterhead, NO WCR logo, NO promotional styling.
/// Exactly 3 Pages A4 with COMPLETE VERTICAL DISTRIBUTION:
/// - Eliminates dead white space on every page by balancing gaps, line heights, and table heights.
/// - Page 1: Balanced gaps filling the page down to Clause 6.
/// - Page 2: Uniform 10.5pt clause gaps filling the page down to Clause 18.
/// - Page 3: Expanded financial card, tall payment table, and a 270pt Table-Based Signature & Stamp block.
class ConsumerVendorAgreementPdfService {
  /// Generate official 3-page A4 Annexure 2 Agreement PDF with balanced full-page distribution
  static Future<File> generateAgreementPdf({
    required ConsumerVendorAgreement agreement,
    Directory? outputDirectory,
    bool includeStampAndSignature = true,
    Uint8List? customStampAndSignatureBytes,
  }) async {
    final PdfDocument document = PdfDocument();
    document.pageSettings.size = PdfPageSize.a4;
    document.pageSettings.orientation = PdfPageOrientation.portrait;
    document.pageSettings.margins.all = 0;

    const double pageWidth = 595.28;
    const double pageHeight = 841.89;

    // Standard Legal / Government Typography
    final PdfFont docMainTitleFont = PdfStandardFont(PdfFontFamily.helvetica, 14.5, style: PdfFontStyle.bold);
    final PdfFont docSubTitleFont = PdfStandardFont(PdfFontFamily.helvetica, 9.2, style: PdfFontStyle.bold);
    final PdfFont runningHeaderFont = PdfStandardFont(PdfFontFamily.helvetica, 8.0, style: PdfFontStyle.italic);
    final PdfFont runningHeaderBold = PdfStandardFont(PdfFontFamily.helvetica, 9.0, style: PdfFontStyle.bold);

    final PdfFont sectionHeaderFont = PdfStandardFont(PdfFontFamily.helvetica, 9.2, style: PdfFontStyle.bold);
    final PdfFont centeredHeaderFont = PdfStandardFont(PdfFontFamily.helvetica, 9.2, style: PdfFontStyle.bold);
    final PdfFont bodyFont = PdfStandardFont(PdfFontFamily.helvetica, 8.5);
    final PdfFont bodyBoldFont = PdfStandardFont(PdfFontFamily.helvetica, 8.6, style: PdfFontStyle.bold);

    final PdfFont p2ClauseFont = PdfStandardFont(PdfFontFamily.helvetica, 7.6);
    final PdfFont p2ClauseBoldFont = PdfStandardFont(PdfFontFamily.helvetica, 7.8, style: PdfFontStyle.bold);

    final PdfFont tableHeaderFont = PdfStandardFont(PdfFontFamily.helvetica, 8.0, style: PdfFontStyle.bold);
    final PdfFont tableCellFont = PdfStandardFont(PdfFontFamily.helvetica, 7.6);
    final PdfFont tableCellBold = PdfStandardFont(PdfFontFamily.helvetica, 7.6, style: PdfFontStyle.bold);

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
          debugPrint('Stamp bitmap decoding error in agreement service: $e');
        }
      }
    }

    final PdfFont footerFont = PdfStandardFont(PdfFontFamily.helvetica, 7.4);
    final PdfFont footerBoldFont = PdfStandardFont(PdfFontFamily.helvetica, 7.4, style: PdfFontStyle.bold);

    // High Contrast, Clean Black & White / Grayscale Palette
    final PdfColor darkTextColor = PdfColor(15, 23, 42);    // #0F172A
    final PdfColor slateBodyColor = PdfColor(30, 41, 59);   // #1E293B
    final PdfColor slateMutedColor = PdfColor(71, 85, 105); // #475569
    final PdfColor borderDarkColor = PdfColor(51, 65, 85);  // #334155
    final PdfColor headerBgColor = PdfColor(241, 245, 249); // #F1F5F9

    final PdfBrush darkTextBrush = PdfSolidBrush(darkTextColor);
    final PdfBrush slateBodyBrush = PdfSolidBrush(slateBodyColor);
    final PdfBrush slateMutedBrush = PdfSolidBrush(slateMutedColor);
    final PdfBrush headerBgBrush = PdfSolidBrush(headerBgColor);

    final PdfPen borderPen = PdfPen(borderDarkColor, width: 0.8);
    final PdfPen thinDividerPen = PdfPen(borderDarkColor, width: 0.6);
    final PdfPen dashedPen = PdfPen(borderDarkColor, width: 0.8)..dashStyle = PdfDashStyle.dash;

    const double contentLeft = 36;
    const double contentWidth = pageWidth - (contentLeft * 2); // 523.28
    const double contentRight = contentLeft + contentWidth;

    final currencyFormatter = NumberFormat.currency(locale: 'en_IN', symbol: 'Rs. ', decimalDigits: 2);

    // Helper: Draw running header on every page
    void drawRunningHeader(PdfGraphics graphics) {
      const double headerY = 22;
      graphics.drawString(
        'Guidelines for PM - Surya Ghar: Muft Bijli Yojana\nCentral Financial Assistance to Residential Consumers',
        runningHeaderFont,
        brush: slateMutedBrush,
        bounds: const Rect.fromLTWH(contentLeft, headerY, 360, 22),
      );

      graphics.drawString(
        'Annexure 2',
        runningHeaderBold,
        brush: darkTextBrush,
        format: PdfStringFormat(alignment: PdfTextAlignment.right),
        bounds: const Rect.fromLTWH(contentRight - 100, headerY + 6, 100, 14),
      );

      graphics.drawLine(thinDividerPen, const Offset(contentLeft, headerY + 26), const Offset(contentRight, headerY + 26));
    }

    // Helper: Draw running footer at the end of the page stream
    void drawRunningFooter(PdfGraphics graphics, int pageNumber, int totalPages) {
      const double footerY = pageHeight - 30;
      graphics.drawLine(thinDividerPen, const Offset(contentLeft, footerY - 4), const Offset(contentRight, footerY - 4));

      graphics.drawString(
        'PM Surya Ghar: Muft Bijli Yojana | Model Draft Agreement | Agr. No: ${agreement.agreementNo}',
        footerFont,
        brush: slateMutedBrush,
        bounds: const Rect.fromLTWH(contentLeft, footerY, contentWidth * 0.75, 12),
      );

      graphics.drawString(
        'Page $pageNumber of $totalPages',
        footerBoldFont,
        brush: darkTextBrush,
        format: PdfStringFormat(alignment: PdfTextAlignment.right),
        bounds: const Rect.fromLTWH(contentLeft + (contentWidth * 0.75), footerY, contentWidth * 0.25, 12),
      );
    }

    // Helper: Draw text with dynamic height measurement to guarantee NO clipping
    double drawDynamicText(PdfGraphics graphics, double curY, String text, PdfFont font, PdfBrush brush, {double gap = 12.0}) {
      final Size measured = font.measureString(text, layoutArea: Size(contentWidth, 0));
      final double h = math.max(measured.height + 3, 14.0);
      graphics.drawString(text, font, brush: brush, bounds: Rect.fromLTWH(contentLeft, curY, contentWidth, h));
      return curY + h + gap;
    }

    // Helper: Draw numbered clause item with dynamic measurement to guarantee NO clipping
    double drawClauseItem(
      PdfGraphics graphics,
      double curY,
      String number,
      String? prefixTitle,
      String text,
      PdfFont font,
      PdfFont boldFont, {
      double gap = 11.0,
    }) {
      graphics.drawString(number, boldFont, brush: darkTextBrush, bounds: Rect.fromLTWH(contentLeft, curY, 20, 14));

      final double textLeft = contentLeft + 20;
      final double textW = contentWidth - 20;
      final String fullStr = (prefixTitle != null && prefixTitle.isNotEmpty) ? '$prefixTitle: $text' : text;

      final Size measured = font.measureString(fullStr, layoutArea: Size(textW, 0));
      final double h = math.max(measured.height + 3, 13.0);

      graphics.drawString(fullStr, font, brush: slateBodyBrush, bounds: Rect.fromLTWH(textLeft, curY, textW, h));
      return curY + h + gap;
    }

    // =========================================================================
    // PAGE 1: Original Title, Preamble, Parties (Centered), Recitals (Centered), First Party (1 to 6)
    // Vertically distributed with comfortable gaps to cover the entire page
    // =========================================================================
    final PdfPage page1 = document.pages.add();
    final PdfGraphics g1 = page1.graphics;
    drawRunningHeader(g1);

    double y = 56;

    // Document Title
    g1.drawString(
      'Model Draft Agreement',
      docMainTitleFont,
      brush: darkTextBrush,
      format: PdfStringFormat(alignment: PdfTextAlignment.center),
      bounds: Rect.fromLTWH(contentLeft, y, contentWidth, 20),
    );
    y += 24;

    g1.drawString(
      'between Consumer & Vendor for installation of grid connected rooftop solar (RTS) project under PM - Surya Ghar: Muft Bijli Yojana',
      docSubTitleFont,
      brush: darkTextBrush,
      format: PdfStringFormat(alignment: PdfTextAlignment.center),
      bounds: Rect.fromLTWH(contentLeft, y, contentWidth, 26),
    );
    y += 34;

    // Preamble
    final String preambleText =
        'This agreement is executed on ${agreement.executionDay} day of ${agreement.executionMonth}, ${agreement.executionYear} '
        'for design, supply, installation, commissioning and 5-year comprehensive maintenance of RTS project/system along with warranty '
        'under PM Surya Ghar: Muft Bijli Yojana.';
    y = drawDynamicText(g1, y, preambleText, bodyFont, darkTextBrush, gap: 18);

    // Parties: Between (CENTERED) & And (CENTERED)
    g1.drawString('Between', centeredHeaderFont, brush: darkTextBrush, format: PdfStringFormat(alignment: PdfTextAlignment.center), bounds: Rect.fromLTWH(contentLeft, y, contentWidth, 14));
    y += 18;
    final String consumerText =
        '${agreement.customerName} (Consumer No: ${agreement.consumerNo}, Mobile: ${agreement.customerMobile.isNotEmpty ? agreement.customerMobile : "N/A"}) '
        'having address at ${agreement.customerAddress.isNotEmpty ? agreement.customerAddress : "Betawad, Tal. Shindkheda, Dist. Dhule"} '
        '(hereinafter referred to as first Party i.e. /consumer/purchaser /owner of system).';
    y = drawDynamicText(g1, y, consumerText, bodyFont, slateBodyBrush, gap: 18);

    g1.drawString('And', centeredHeaderFont, brush: darkTextBrush, format: PdfStringFormat(alignment: PdfTextAlignment.center), bounds: Rect.fromLTWH(contentLeft, y, contentWidth, 14));
    y += 18;
    const String vendorText =
        'SIYA INFOTECH & DIGITAL SOLUTIONS (GSTIN: 27CVTPK6358P1ZD, Mobile: 7588003220, Email: siyainfodigital@gmail.com) '
        'having registered office at 21, Mudavad Road, Betawad, Tal. Shindkheda, Dist. Dhule - 425403 '
        '(hereinafter referred to as second Party i.e. Vendor/ contractor/ System Integrator).';
    y = drawDynamicText(g1, y, vendorText, bodyFont, slateBodyBrush, gap: 18);

    // Recitals: Whereas (CENTERED) & And whereas (CENTERED)
    g1.drawString('Whereas', centeredHeaderFont, brush: darkTextBrush, format: PdfStringFormat(alignment: PdfTextAlignment.center), bounds: Rect.fromLTWH(contentLeft, y, contentWidth, 14));
    y += 18;
    final String whereas1 =
        'First Party wishes to install a Grid Connected Rooftop Solar Plant of ${agreement.systemCapacity} on the rooftop of the residential building '
        'of the Consumer under PM Surya Ghar: Muft Bijli Yojana.';
    y = drawDynamicText(g1, y, whereas1, bodyFont, slateBodyBrush, gap: 16);

    g1.drawString('And whereas', centeredHeaderFont, brush: darkTextBrush, format: PdfStringFormat(alignment: PdfTextAlignment.center), bounds: Rect.fromLTWH(contentLeft, y, contentWidth, 14));
    y += 18;
    const String whereas2 =
        'Second Party has verified availability of appropriate roof and found it feasible to install a Grid Connected Roof Top Solar plant and that '
        'the second party is willing to design, supply, install, test, commission and carry out Operation & Maintenance of the Rooftop Solar plant for 5 year period.';
    y = drawDynamicText(g1, y, whereas2, bodyFont, slateBodyBrush, gap: 18);

    g1.drawString(
      'On this day, the First Party and Second Party agree to the following:',
      bodyBoldFont,
      brush: darkTextBrush,
      bounds: Rect.fromLTWH(contentLeft, y, contentWidth, 14),
    );
    y += 18;

    // First Party Undertakings (1 to 6)
    g1.drawString(
      'The First Party hereby undertakes to perform the following activities:',
      sectionHeaderFont,
      brush: darkTextBrush,
      bounds: Rect.fromLTWH(contentLeft, y, contentWidth, 15),
    );
    y += 20;

    const double p1Gap = 21.0;
    y = drawClauseItem(g1, y, '1.', null, 'Submission of online application at National Portal for installation of RTS project/system, Submission of application for net-metering and system inspection and upload of the relevant documents on the National Portal of the scheme.', bodyFont, bodyBoldFont, gap: p1Gap);
    y = drawClauseItem(g1, y, '2.', null, 'Provide secure storage of the material of the RTS plant delivered at the premises till handover of the system.', bodyFont, bodyBoldFont, gap: p1Gap);
    y = drawClauseItem(g1, y, '3.', null, 'Provide access to the Roof Top during installation of the plant, operation & maintenance, testing of the plant and equipment and for meter reading from solar meter, inverter etc.', bodyFont, bodyBoldFont, gap: p1Gap);
    y = drawClauseItem(g1, y, '4.', null, 'Provide electricity during plant installation and water for cleaning of the panels.', bodyFont, bodyBoldFont, gap: p1Gap);
    y = drawClauseItem(g1, y, '5.', null, 'Report any malfunctioning of the plant to the Vendor during the warranty period.', bodyFont, bodyBoldFont, gap: p1Gap);
    y = drawClauseItem(g1, y, '6.', null, 'Pay the amount as per the payment schedule as mutually agreed with the vendor, including any additional amount to the second party for any additional work /customization required depending upon the building condition.', bodyFont, bodyBoldFont, gap: 8.0);

    // Draw footer at the end of page 1
    drawRunningFooter(g1, 1, 3);

    // =========================================================================
    // PAGE 2: Second Party Undertakings (ALL 18 Clauses, perfectly aligned with no cutoff)
    // Distributed with comfortable gaps to cover the page gracefully down to Clause 18
    // =========================================================================
    final PdfPage page2 = document.pages.add();
    final PdfGraphics g2 = page2.graphics;
    drawRunningHeader(g2);

    y = 56;
    g2.drawString(
      'The Second Party hereby undertakes to perform the following activities:',
      sectionHeaderFont,
      brush: darkTextBrush,
      bounds: Rect.fromLTWH(contentLeft, y, contentWidth, 15),
    );
    y += 20;

    const double p2Gap = 12.0;
    y = drawClauseItem(g2, y, '1.', 'Standards & Scheme Compliance', 'The Vendor must follow all the standards and safety guidelines prescribed under state regulations and technical standards prescribed by MNRE for RTS projects, failing which the vendor is liable for blacklisting from participation in the govt. project/ scheme and other penal actions in accordance with the law. The responsibility of supply, installation and commissioning of the rooftop solar project/system in complete compliance with MNRE scheme guidelines lies with the Vendor.', p2ClauseFont, p2ClauseBoldFont, gap: p2Gap);
    y = drawClauseItem(g2, y, '2.', 'Site Survey', 'Site visit, survey and development of detailed project report for installation of RTS system. This also includes feasibility study of roof, strength of roof and shadow free area. If any additional work or customization is involved for the plant installation as per site condition and requirement of the consumer building, the Vendor shall prepare an estimate and can raise separate invoice including GST in addition to the amount towards standard plant cost. The consumer shall pay the amount for such additional work directly to the Vendor.', p2ClauseFont, p2ClauseBoldFont, gap: p2Gap);
    y = drawClauseItem(g2, y, '3.', 'Design & Engineering', 'Design of plant along with drawings and selection of components as per standard provided by the DISCOM/SERC/MNRE for best performance and safety of the plant.', p2ClauseFont, p2ClauseBoldFont, gap: p2Gap);
    y = drawClauseItem(g2, y, '4.', 'Module and Inverter', 'The solar modules, including the solar cells, should be manufactured in India. Both the solar modules and inverters shall conform to the relevant standards and specifications prescribed by MNRE. Any other requirement, viz. star labelling (solar modules), quality control orders and standards & labelling (inverters) etc., shall also be complied.', p2ClauseFont, p2ClauseBoldFont, gap: p2Gap);
    y = drawClauseItem(g2, y, '5.', 'Procurement & Supply', 'Procurement of complete system as per BIS/IS/IEC standard (whatever applicable) & safety guidelines for installation of rooftop solar plants. The supplied materials should comply with all MNRE standards for release of subsidy.', p2ClauseFont, p2ClauseBoldFont, gap: p2Gap);
    y = drawClauseItem(g2, y, '6.', 'Installation & Civil work', 'Complete civil work, structure work and electrical work (including drawings) following all the safety and relevant BIS standards.', p2ClauseFont, p2ClauseBoldFont, gap: p2Gap);
    y = drawClauseItem(g2, y, '7.', 'Documentation', 'Technical Catalogues/Warranty Certificates/BIS certificates/other test reports etc.: All such documents shall be provided to the consumer for online uploading and submission of technical specifications, IEC/BIS report, Sr. Nos, Warranty card of Solar Panel & Inverter, Layout & Electrical SLD, Structure Design and Drawing, Cable and other detailed documents.', p2ClauseFont, p2ClauseBoldFont, gap: p2Gap);
    y = drawClauseItem(g2, y, '8.', 'Project completion report (PCR)', 'Assisting the consumer in filling and uploading of signed documents (Consumer & Vendor) on the national portal.', p2ClauseFont, p2ClauseBoldFont, gap: p2Gap);
    y = drawClauseItem(g2, y, '9.', 'Warranty', 'System warranty certificates should be provided to the consumer. The complete system should be warranted for 5 years from the date of commissioning by DISCOM. Individual component warranty documents provided by the manufacturer shall be provided to the consumer and all possible assistance should be extended to the consumer for claiming the warranty from the manufacturer.', p2ClauseFont, p2ClauseBoldFont, gap: p2Gap);
    y = drawClauseItem(g2, y, '10.', 'NET meter & Grid Connectivity', 'Net meter supply/procurement, testing and approvals shall be in the scope of vendor. Grid connection of the plant shall be in the scope of the vendor.', p2ClauseFont, p2ClauseBoldFont, gap: p2Gap);
    y = drawClauseItem(g2, y, '11.', 'Testing and Commissioning', 'The vendor shall be present at the time of testing and commissioning by the DISCOM.', p2ClauseFont, p2ClauseBoldFont, gap: p2Gap);
    y = drawClauseItem(g2, y, '12.', 'Operation & Maintenance', 'Five (5) years Comprehensive Operation and Maintenance including overhauling, wear and tear and regular checking of healthiness of system at proper interval shall be in the scope of vendor. The vendor shall also educate the consumer on best practices for cleaning of the modules and system maintenance.', p2ClauseFont, p2ClauseBoldFont, gap: p2Gap);
    y = drawClauseItem(g2, y, '13.', 'Insurance', 'Any insurance cost pertaining to material transfer/storage before commissioning of the system shall be in the scope of the vendor.', p2ClauseFont, p2ClauseBoldFont, gap: p2Gap);
    y = drawClauseItem(g2, y, '14.', 'Applicable Standard', 'The system must meet the technical standards and specifications notified by MNRE. The vendor is solely responsible to supply component and service which meets the technical standards and specification prescribed by MNRE and State DISCOMs.', p2ClauseFont, p2ClauseBoldFont, gap: p2Gap);
    y = drawClauseItem(g2, y, '15.', 'Project/system cost & payment terms', 'The cost of the plant and payment schedule should be mutually discussed and decided between the vendor and consumer. The consumer may opt for milestone-based payment to the vendor and the same shall be included in the agreement.', p2ClauseFont, p2ClauseBoldFont, gap: p2Gap);
    y = drawClauseItem(g2, y, '16.', 'Dispute', 'In case of any dispute between consumer and vendor (in supply/installation/maintenance of system or payment terms), both parties must settle the same mutually or as per law. MNRE/DISCOM shall not be liable for, and would not be a party to any dispute arising between vendor and consumer.', p2ClauseFont, p2ClauseBoldFont, gap: p2Gap);
    y = drawClauseItem(g2, y, '17.', 'Subsidy / Project Related Documents', 'Vendor must provide all the documents to consumer and help in uploading the same to National Portal for smooth release of subsidy.', p2ClauseFont, p2ClauseBoldFont, gap: p2Gap);
    y = drawClauseItem(g2, y, '18.', 'Performance of Plant', 'The Performance Ratio (PR) of Plant must be >= 75% at the time of commissioning of the project by DISCOM or its authorised agency. Vendor must provide (returnable basis) radiation sensor with valid calibration certificate of any NABL / International laboratory at the time of commissioning / testing of the plant. Vendor must maintain the PR of the plant till warranty of project i.e. 5 years from the date of commissioning.', p2ClauseFont, p2ClauseBoldFont, gap: 8.0);

    // Draw footer at the end of page 2
    drawRunningFooter(g2, 2, 3);

    // =========================================================================
    // PAGE 3: Clause 19, Financial Card, Milestone Table, Table-Based Signatures, Disclaimer
    // First Party & Second Party Table anchored directly to base, zero dead white space
    // =========================================================================
    final PdfPage page3 = document.pages.add();
    final PdfGraphics g3 = page3.graphics;
    drawRunningHeader(g3);

    y = 56;
    // Clause 19: Mutually Agreed Terms of Payment
    g3.drawString(
      '19. Mutually Agreed Terms of Payment',
      docSubTitleFont,
      brush: darkTextBrush,
      bounds: Rect.fromLTWH(contentLeft, y, contentWidth, 16),
    );
    y += 24;

    // Financial Overview Card (4 Columns with generous vertical padding)
    const double sumBoxH = 52;
    g3.drawRectangle(brush: headerBgBrush, pen: borderPen, bounds: Rect.fromLTWH(contentLeft, y, contentWidth, sumBoxH));

    final double colW = contentWidth / 4;
    void drawSummaryMetric(String title, String value, double xPos) {
      g3.drawString(title, footerFont, brush: slateMutedBrush, bounds: Rect.fromLTWH(xPos, y + 8, colW - 6, 12));
      g3.drawString(value, bodyBoldFont, brush: darkTextBrush, bounds: Rect.fromLTWH(xPos, y + 26, colW - 6, 16));
    }

    drawSummaryMetric('Solar Capacity', agreement.systemCapacity, contentLeft + 12);
    drawSummaryMetric('Total Project Cost', agreement.totalProjectCost > 0 ? currencyFormatter.format(agreement.totalProjectCost) : 'Rs. ____________', contentLeft + colW + 8);
    drawSummaryMetric('Govt. CFA Subsidy', currencyFormatter.format(agreement.cfaSubsidyAmount), contentLeft + (colW * 2) + 8);
    drawSummaryMetric('Net Payable', agreement.netCustomerPayable > 0 ? currencyFormatter.format(agreement.netCustomerPayable) : 'Rs. ____________', contentLeft + (colW * 3) + 8);
    y += sumBoxH + 18;

    // Milestone Table with Comfortable Cell Padding & Proper Column Widths
    final PdfGrid grid = PdfGrid();
    grid.columns.add(count: 5);
    grid.columns[0].width = 30;
    grid.columns[1].width = 125;
    grid.columns[2].width = 55;
    grid.columns[3].width = 95;
    grid.columns[4].width = contentWidth - (30 + 125 + 55 + 95);

    grid.headers.add(1);
    final PdfGridRow headerRow = grid.headers[0];
    headerRow.cells[0].value = 'Sr.';
    headerRow.cells[1].value = 'Milestone Stage';
    headerRow.cells[2].value = 'Share %';
    headerRow.cells[3].value = 'Amount (Rs.)';
    headerRow.cells[4].value = 'Payment Due Condition';

    headerRow.style.backgroundBrush = headerBgBrush;
    headerRow.style.textBrush = darkTextBrush;
    headerRow.style.font = tableHeaderFont;

    for (final m in agreement.paymentMilestones) {
      final row = grid.rows.add();
      row.cells[0].value = '${m.sr}.';
      row.cells[1].value = m.stage;
      row.cells[2].value = '${m.percentage.toStringAsFixed(0)}%';
      row.cells[3].value = m.amount > 0 ? currencyFormatter.format(m.amount) : 'Rs. ____________';
      row.cells[4].value = m.description;

      row.cells[0].style.font = tableCellFont;
      row.cells[1].style.font = tableCellBold;
      row.cells[2].style.font = tableCellFont;
      row.cells[3].style.font = tableCellBold;
      row.cells[4].style.font = tableCellFont;

      row.cells[0].stringFormat = PdfStringFormat(alignment: PdfTextAlignment.center);
      row.cells[2].stringFormat = PdfStringFormat(alignment: PdfTextAlignment.center);
      row.cells[3].stringFormat = PdfStringFormat(alignment: PdfTextAlignment.right);
    }

    // Add total row
    final totalRow = grid.rows.add();
    totalRow.cells[0].value = '';
    totalRow.cells[1].value = 'Total Agreed Cost';
    totalRow.cells[2].value = '100%';
    totalRow.cells[3].value = agreement.totalProjectCost > 0 ? currencyFormatter.format(agreement.totalProjectCost) : 'Rs. ____________';
    totalRow.cells[4].value = '100% of Total Agreed Project';
    totalRow.style.backgroundBrush = headerBgBrush;
    for (int i = 0; i < 5; i++) {
      totalRow.cells[i].style.font = tableHeaderFont;
    }
    totalRow.cells[2].stringFormat = PdfStringFormat(alignment: PdfTextAlignment.center);
    totalRow.cells[3].stringFormat = PdfStringFormat(alignment: PdfTextAlignment.right);

    // Generous cell padding to give rows executive height
    grid.style.cellPadding = PdfPaddings(left: 6, top: 8, right: 6, bottom: 8);
    final PdfLayoutResult gridResult = grid.draw(
      page: page3,
      bounds: Rect.fromLTWH(contentLeft, y, contentWidth, 0),
    )!;

    y = gridResult.bounds.bottom + 18;

    // Anchor Disclaimer right above the footer line (y = 758 to 786)
    const double disclaimerY = 758;
    const double discH = 28;

    // Anchor Signature Box to extend from current y all the way down to disclaimer!
    final double signBoxBottom = disclaimerY - 12; // y = 746
    final double signBoxH = signBoxBottom - y;

    // ===================================================================
    // FIRST PARTY & SECOND PARTY TABLE-BASED SIGNATURE & STAMP BLOCK
    // Anchored directly to base with full vertical coverage & noble signing space
    // ===================================================================
    g3.drawRectangle(pen: borderPen, bounds: Rect.fromLTWH(contentLeft, y, contentWidth, signBoxH));

    const double dividerXRatio = 0.48;
    final double colDividerX = contentLeft + (contentWidth * dividerXRatio);
    g3.drawLine(borderPen, Offset(colDividerX, y), Offset(colDividerX, y + signBoxH));

    final double p1Width = (contentWidth * dividerXRatio) - 20;
    final double p2Left = colDividerX + 12;
    final double p2Width = (contentWidth * (1 - dividerXRatio)) - 22;

    // Row 1: Header Bar with light gray background
    const double headerBarH = 26;
    g3.drawRectangle(brush: headerBgBrush, bounds: Rect.fromLTWH(contentLeft, y, contentWidth, headerBarH));
    g3.drawLine(thinDividerPen, Offset(contentLeft, y + headerBarH), Offset(contentRight, y + headerBarH));
    g3.drawLine(borderPen, Offset(colDividerX, y), Offset(colDividerX, y + headerBarH));

    g3.drawString('First Party (Consumer)', sectionHeaderFont, brush: darkTextBrush, bounds: Rect.fromLTWH(contentLeft + 12, y + 6, p1Width, 16));
    g3.drawString('Second Party (Vendor)', sectionHeaderFont, brush: darkTextBrush, bounds: Rect.fromLTWH(p2Left, y + 6, p2Width, 16));

    // Row 2: Details Section
    double p1Y = y + headerBarH + 10;
    g3.drawString('Name: ${agreement.customerName}', bodyBoldFont, brush: darkTextBrush, bounds: Rect.fromLTWH(contentLeft + 12, p1Y, p1Width, 14));
    p1Y += 18;
    g3.drawString('Address: ${agreement.customerAddress.isNotEmpty ? agreement.customerAddress : "As per record"}', bodyFont, brush: slateBodyBrush, bounds: Rect.fromLTWH(contentLeft + 12, p1Y, p1Width, 13));
    p1Y += 16;
    g3.drawString('Consumer No: ${agreement.consumerNo}', bodyFont, brush: slateBodyBrush, bounds: Rect.fromLTWH(contentLeft + 12, p1Y, p1Width, 13));
    p1Y += 16;
    g3.drawString('Mobile: ${agreement.customerMobile.isNotEmpty ? agreement.customerMobile : "N/A"}', bodyFont, brush: slateBodyBrush, bounds: Rect.fromLTWH(contentLeft + 12, p1Y, p1Width, 13));
    p1Y += 16;
    g3.drawString('System Capacity: ${agreement.systemCapacity} Grid Connected RTS', bodyFont, brush: slateBodyBrush, bounds: Rect.fromLTWH(contentLeft + 12, p1Y, p1Width, 13));

    double p2Y = y + headerBarH + 10;
    g3.drawString('Name: SIYA INFOTECH & DIGITAL SOLUTIONS', bodyBoldFont, brush: darkTextBrush, bounds: Rect.fromLTWH(p2Left, p2Y, p2Width, 14));
    p2Y += 18;
    g3.drawString('Address: 21, Mudavad Road, Betawad, Tal. Shindkheda, Dist. Dhule', bodyFont, brush: slateBodyBrush, bounds: Rect.fromLTWH(p2Left, p2Y, p2Width, 13));
    p2Y += 16;
    g3.drawString('GSTIN: 27CVTPK6358P1ZD | Mobile: 7588003220', bodyFont, brush: slateBodyBrush, bounds: Rect.fromLTWH(p2Left, p2Y, p2Width, 13));
    p2Y += 16;
    g3.drawString('Email: siyainfodigital@gmail.com', bodyFont, brush: slateBodyBrush, bounds: Rect.fromLTWH(p2Left, p2Y, p2Width, 13));
    p2Y += 16;
    g3.drawString('Role: Vendor / Contractor / System Integrator', bodyFont, brush: slateBodyBrush, bounds: Rect.fromLTWH(p2Left, p2Y, p2Width, 13));

    // Horizontal divider separating details row from base signature row
    const double detailsH = 100;
    final double baseRowY = y + headerBarH + detailsH;
    g3.drawLine(thinDividerPen, Offset(contentLeft, baseRowY), Offset(contentRight, baseRowY));

    // Row 3: Base Signature & Dedicated Stamp Row
    final double baseRowH = signBoxBottom - baseRowY;

    // First Party (Consumer) Signature Base
    g3.drawString('Signature / Thumb Impression of First Party:', footerFont, brush: slateMutedBrush, bounds: Rect.fromLTWH(contentLeft + 12, baseRowY + 10, p1Width, 12));

    final double cSignY = baseRowY + (baseRowH * 0.62);
    g3.drawLine(thinDividerPen, Offset(contentLeft + 12, cSignY), Offset(contentLeft + 12 + p1Width, cSignY));
    g3.drawString('Signature of First Party (Consumer)', bodyBoldFont, brush: darkTextBrush, bounds: Rect.fromLTWH(contentLeft + 12, cSignY + 5, p1Width, 14));
    g3.drawString('Name: ${agreement.customerName}', bodyFont, brush: slateBodyBrush, bounds: Rect.fromLTWH(contentLeft + 12, cSignY + 20, p1Width, 13));
    g3.drawString('Date: ${agreement.formattedExecutionDate}   |   Place: Shindkheda', footerFont, brush: slateMutedBrush, bounds: Rect.fromLTWH(contentLeft + 12, cSignY + 35, p1Width, 13));

    // Second Party (Vendor) Signature & Stamp Base
    final double vSignY = cSignY;

    // Vendor Signature with aligned baseline drawn FIRST
    g3.drawLine(thinDividerPen, Offset(p2Left, vSignY), Offset(p2Left + p2Width, vSignY));

    // Draw Company Stamp & Authorized Signature ON TOP OF the line ("reshcya var")
    // Stamp size: 38mm x 38mm (108pt x 108pt) round stamp
    // Composite artwork width: 146pt, height: 108pt
    if (includeStampAndSignature) {
      const double pairW = 146;
      const double pairH = 108;
      final double stampX = p2Left + (p2Width - pairW) / 2;
      final double stampY = vSignY - 84;
      CompanyStampHelper.drawStampAndSignature(
        graphics: g3,
        bounds: Rect.fromLTWH(stampX, stampY, pairW, pairH),
        bitmap: stampAndSigBitmap,
        include: includeStampAndSignature,
      );
    }
    g3.drawString('Authorized Signatory', bodyBoldFont, brush: darkTextBrush, bounds: Rect.fromLTWH(p2Left, vSignY + 5, p2Width, 14));
    g3.drawString('SIYA INFOTECH & DIGITAL SOLUTIONS', footerFont, brush: slateMutedBrush, bounds: Rect.fromLTWH(p2Left, vSignY + 20, p2Width, 13));
    g3.drawString('Date: ${agreement.formattedExecutionDate}   |   Place: Shindkheda', footerFont, brush: slateMutedBrush, bounds: Rect.fromLTWH(p2Left, vSignY + 35, p2Width, 13));

    // Official PM Surya Ghar Disclaimer
    g3.drawRectangle(brush: headerBgBrush, pen: thinDividerPen, bounds: Rect.fromLTWH(contentLeft, disclaimerY, contentWidth, discH));
    const String disclaimer =
        'Disclaimer: This agreement is between vendor and consumer and any dispute related to the same shall not involve any third party including MNRE and Distribution Utilities.';
    g3.drawString(
      disclaimer,
      runningHeaderFont,
      brush: slateMutedBrush,
      format: PdfStringFormat(alignment: PdfTextAlignment.center, lineAlignment: PdfVerticalAlignment.middle),
      bounds: Rect.fromLTWH(contentLeft + 8, disclaimerY, contentWidth - 16, discH),
    );

    // Draw footer at the end of page 3
    drawRunningFooter(g3, 3, 3);

    // Save and return
    final List<int> bytes = await document.save();
    document.dispose();

    Directory dir;
    try {
      dir = outputDirectory ?? await getApplicationDocumentsDirectory();
    } catch (_) {
      dir = outputDirectory ?? Directory.systemTemp;
    }

    final File file = File('${dir.path}/${agreement.pdfFileName}');
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  /// Preview agreement in PDF viewer
  static Future<void> previewAgreement(File file) async {
    await OpenFilex.open(file.path);
  }

  /// Share agreement PDF via system share sheet
  static Future<void> shareAgreement(File file, ConsumerVendorAgreement agreement) async {
    final xFile = XFile(file.path, mimeType: 'application/pdf', name: agreement.pdfFileName);
    await Share.shareXFiles(
      [xFile],
      text: 'Consumer-Vendor Agreement (Annexure 2) for ${agreement.customerName} (${agreement.systemCapacity} Solar RTS Project)',
      subject: 'Consumer-Vendor Agreement - ${agreement.agreementNo}',
    );
  }

  /// Open/View agreement PDF
  static Future<void> printAgreement(ConsumerVendorAgreement agreement) async {
    final file = await generateAgreementPdf(agreement: agreement);
    await OpenFilex.open(file.path);
  }

  /// Share via WhatsApp
  static Future<void> shareViaWhatsApp(ConsumerVendorAgreement agreement) async {
    final phone = agreement.customerMobile.replaceAll(RegExp(r'\D'), '');
    final cleanPhone = phone.length == 10 ? '91$phone' : phone;

    final msg = Uri.encodeComponent(
      'Hello ${agreement.customerName},\n\n'
      'Please find attached the official Consumer-Vendor Agreement (Annexure 2) under PM Surya Ghar: Muft Bijli Yojana for your ${agreement.systemCapacity} Solar RTS Project.\n\n'
      '• Agreement No: ${agreement.agreementNo}\n'
      '• Execution Date: ${agreement.formattedExecutionDate}\n'
      '• Total Project Cost: Rs. ${agreement.totalProjectCost.toStringAsFixed(0)}\n'
      '• Govt Subsidy: Rs. ${agreement.cfaSubsidyAmount.toStringAsFixed(0)}\n'
      '• Net Payable: Rs. ${agreement.netCustomerPayable.toStringAsFixed(0)}\n\n'
      'Best regards,\n'
      'SIYA INFOTECH & DIGITAL SOLUTIONS\n'
      'Betawad, Dist. Dhule | Helpline: 7588003220',
    );

    final url = Uri.parse('https://wa.me/$cleanPhone?text=$msg');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }
}
