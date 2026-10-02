import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/consumer_vendor_agreement.dart';

/// Official Master Reference implementation of Annexure 2 Agreement
/// Strictly follows original PM Surya Ghar: Muft Bijli Yojana Model Draft Agreement.
/// NO company letterhead, NO WCR logo, NO promotional styling.
/// Exactly 3 Pages A4:
/// - Page 1: Title, Preamble, Parties (Centered), Recitals (Centered), First Party (1-6)
/// - Page 2: Second Party Undertakings (All 18 Clauses, perfectly aligned with no cutoff)
/// - Page 3: Clause 19, Financial Overview, Milestone Table, Table-Based First & Second Party Signatures, Disclaimer
class ConsumerVendorAgreementService {
  static const PdfColor darkTextColor = PdfColor.fromInt(0xFF0F172A);
  static const PdfColor slateBodyColor = PdfColor.fromInt(0xFF1E293B);
  static const PdfColor slateMutedColor = PdfColor.fromInt(0xFF475569);
  static const PdfColor borderDarkColor = PdfColor.fromInt(0xFF334155);
  static const PdfColor borderLightColor = PdfColor.fromInt(0xFFCBD5E1);
  static const PdfColor headerBgColor = PdfColor.fromInt(0xFFF1F5F9);

  /// Running header matching the master reference guidelines
  static pw.Widget _buildRunningHeader() {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'Guidelines for PM - Surya Ghar: Muft Bijli Yojana',
                  style: pw.TextStyle(color: slateMutedColor, fontSize: 8.0, fontStyle: pw.FontStyle.italic),
                ),
                pw.SizedBox(height: 1),
                pw.Text(
                  'Central Financial Assistance to Residential Consumers',
                  style: pw.TextStyle(color: slateMutedColor, fontSize: 7.5, fontStyle: pw.FontStyle.italic),
                ),
              ],
            ),
            pw.Text(
              'Annexure 2',
              style: pw.TextStyle(color: darkTextColor, fontSize: 9.0, fontWeight: pw.FontWeight.bold),
            ),
          ],
        ),
        pw.SizedBox(height: 4),
        pw.Container(height: 0.8, color: borderDarkColor),
        pw.SizedBox(height: 8),
      ],
    );
  }

  /// Running footer matching the master reference (Page X of 3)
  static pw.Widget _buildRunningFooter(ConsumerVendorAgreement agreement, int pageNum, int totalPages) {
    return pw.Column(
      mainAxisSize: pw.MainAxisSize.min,
      children: [
        pw.Container(height: 0.8, color: borderDarkColor, margin: const pw.EdgeInsets.only(bottom: 4)),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'PM Surya Ghar: Muft Bijli Yojana | Model Draft Agreement | Agr. No: ${agreement.agreementNo}',
              style: const pw.TextStyle(color: slateMutedColor, fontSize: 7.2),
            ),
            pw.Text(
              'Page $pageNum of $totalPages',
              style: pw.TextStyle(color: darkTextColor, fontSize: 7.2, fontWeight: pw.FontWeight.bold),
            ),
          ],
        ),
      ],
    );
  }

  /// Helper: Clause item with clear number indentation and readable line height
  static pw.Widget _buildClauseItem(
    String number,
    String? prefixTitle,
    String description, {
    double bottomGap = 6.5,
    double fontSize = 7.5,
  }) {
    return pw.Padding(
      padding: pw.EdgeInsets.only(bottom: bottomGap),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 18,
            child: pw.Text(
              number,
              style: pw.TextStyle(color: darkTextColor, fontSize: fontSize, fontWeight: pw.FontWeight.bold),
            ),
          ),
          pw.Expanded(
            child: pw.RichText(
              text: pw.TextSpan(
                children: [
                  if (prefixTitle != null && prefixTitle.isNotEmpty)
                    pw.TextSpan(
                      text: '$prefixTitle: ',
                      style: pw.TextStyle(color: darkTextColor, fontSize: fontSize, fontWeight: pw.FontWeight.bold),
                    ),
                  pw.TextSpan(
                    text: description,
                    style: pw.TextStyle(color: slateBodyColor, fontSize: fontSize, lineSpacing: 1.25),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Generate exact 3-Page A4 PDF bytes with Table-Based First & Second Party Signatures
  static Future<Uint8List> generateAgreementPdfBytes(
    ConsumerVendorAgreement agreement, {
    bool includeStampAndSignature = true,
    Uint8List? customStampAndSignatureBytes,
  }) async {
    final pdf = pw.Document();
    final currencyFmt = NumberFormat.currency(locale: 'en_IN', symbol: 'Rs. ', decimalDigits: 2);

    // Load Company Stamp & Authorized Signature (DEFAULT: automatically included)
    pw.MemoryImage? stampAndSigImage;
    if (includeStampAndSignature) {
      if (customStampAndSignatureBytes != null) {
        stampAndSigImage = pw.MemoryImage(customStampAndSignatureBytes);
      } else {
        try {
          final ByteData pairData = await rootBundle.load('assets/images/company_stamp_signature_pair.png');
          stampAndSigImage = pw.MemoryImage(pairData.buffer.asUint8List());
        } catch (e) {
          debugPrint('Stamp & signature pair load error in admin agreement service: $e');
        }
      }
    }

    // =========================================================================
    // PAGE 1: Original Title, Preamble, Parties (Centered), Recitals (Centered), First Party (1 to 6)
    // =========================================================================
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 36, vertical: 24),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              _buildRunningHeader(),

              // Title Section (Original Master Format)
              pw.Center(
                child: pw.Column(
                  children: [
                    pw.Text(
                      'Model Draft Agreement',
                      style: pw.TextStyle(color: darkTextColor, fontSize: 13.5, fontWeight: pw.FontWeight.bold),
                    ),
                    pw.SizedBox(height: 3),
                    pw.Text(
                      'between Consumer & Vendor for installation of grid connected rooftop solar (RTS) project under PM - Surya Ghar: Muft Bijli Yojana',
                      textAlign: pw.TextAlign.center,
                      style: pw.TextStyle(color: darkTextColor, fontSize: 8.8, fontWeight: pw.FontWeight.bold),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 12),

              // Preamble
              pw.Text(
                'This agreement is executed on ${agreement.executionDay} day of ${agreement.executionMonth}, ${agreement.executionYear} '
                'for design, supply, installation, commissioning and 5-year comprehensive maintenance of RTS project/system along with warranty '
                'under PM Surya Ghar: Muft Bijli Yojana.',
                style: const pw.TextStyle(color: darkTextColor, fontSize: 8.6, lineSpacing: 1.4),
              ),
              pw.SizedBox(height: 14),

              // Parties (Between & And) - CENTERED HEADINGS as in user screenshot
              pw.Center(
                child: pw.Text('Between', style: pw.TextStyle(color: darkTextColor, fontSize: 9.5, fontWeight: pw.FontWeight.bold)),
              ),
              pw.SizedBox(height: 4),
              pw.RichText(
                text: pw.TextSpan(
                  children: [
                    pw.TextSpan(
                      text: '${agreement.customerName} ',
                      style: pw.TextStyle(color: darkTextColor, fontSize: 8.5, fontWeight: pw.FontWeight.bold),
                    ),
                    pw.TextSpan(
                      text: '(Consumer No: ${agreement.consumerNo}, Mobile: ${agreement.customerMobile.isNotEmpty ? agreement.customerMobile : "N/A"}) ',
                      style: pw.TextStyle(color: darkTextColor, fontSize: 8.3, fontWeight: pw.FontWeight.bold),
                    ),
                    pw.TextSpan(
                      text: 'having address at ${agreement.customerAddress.isNotEmpty ? agreement.customerAddress : "Betawad, Tal. Shindkheda, Dist. Dhule"} '
                          '(hereinafter referred to as first Party i.e. /consumer/purchaser /owner of system).',
                      style: const pw.TextStyle(color: slateBodyColor, fontSize: 8.3, lineSpacing: 1.4),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 14),

              pw.Center(
                child: pw.Text('And', style: pw.TextStyle(color: darkTextColor, fontSize: 9.5, fontWeight: pw.FontWeight.bold)),
              ),
              pw.SizedBox(height: 4),
              pw.RichText(
                text: pw.TextSpan(
                  children: [
                    pw.TextSpan(
                      text: 'SIYA INFOTECH & DIGITAL SOLUTIONS ',
                      style: pw.TextStyle(color: darkTextColor, fontSize: 8.5, fontWeight: pw.FontWeight.bold),
                    ),
                    pw.TextSpan(
                      text: '(GSTIN: 27CVTPK6358P1ZD, Mobile: 7588003220, Email: siyainfodigital@gmail.com) ',
                      style: pw.TextStyle(color: darkTextColor, fontSize: 8.3, fontWeight: pw.FontWeight.bold),
                    ),
                    const pw.TextSpan(
                      text: 'having registered office at 21, Mudavad Road, Betawad, Tal. Shindkheda, Dist. Dhule - 425403 '
                          '(hereinafter referred to as second Party i.e. Vendor/ contractor/ System Integrator).',
                      style: pw.TextStyle(color: slateBodyColor, fontSize: 8.3, lineSpacing: 1.4),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 14),

              // Recitals (Whereas) - CENTERED HEADINGS as in user screenshot
              pw.Center(
                child: pw.Text('Whereas', style: pw.TextStyle(color: darkTextColor, fontSize: 9.5, fontWeight: pw.FontWeight.bold)),
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                'First Party wishes to install a Grid Connected Rooftop Solar Plant of ${agreement.systemCapacity} on the rooftop of the residential building of the Consumer under PM Surya Ghar: Muft Bijli Yojana.',
                style: const pw.TextStyle(color: slateBodyColor, fontSize: 8.3, lineSpacing: 1.4),
              ),
              pw.SizedBox(height: 12),

              pw.Center(
                child: pw.Text('And whereas', style: pw.TextStyle(color: darkTextColor, fontSize: 9.5, fontWeight: pw.FontWeight.bold)),
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                'Second Party has verified availability of appropriate roof and found it feasible to install a Grid Connected Roof Top Solar plant and that the second party is willing to design, supply, install, test, commission and carry out Operation & Maintenance of the Rooftop Solar plant for 5 year period.',
                style: const pw.TextStyle(color: slateBodyColor, fontSize: 8.3, lineSpacing: 1.4),
              ),
              pw.SizedBox(height: 14),

              pw.Text(
                'On this day, the First Party and Second Party agree to the following:',
                style: pw.TextStyle(color: darkTextColor, fontSize: 8.8, fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 12),

              // First Party Undertakings (All 6 Clauses)
              pw.Text(
                'The First Party hereby undertakes to perform the following activities:',
                style: pw.TextStyle(color: darkTextColor, fontSize: 9.2, fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 8),
              _buildClauseItem('1.', null, 'Submission of online application at National Portal for installation of RTS project/system, Submission of application for net-metering and system inspection and upload of the relevant documents on the National Portal of the scheme.', bottomGap: 16.0, fontSize: 8.4),
              _buildClauseItem('2.', null, 'Provide secure storage of the material of the RTS plant delivered at the premises till handover of the system.', bottomGap: 16.0, fontSize: 8.4),
              _buildClauseItem('3.', null, 'Provide access to the Roof Top during installation of the plant, operation & maintenance, testing of the plant and equipment and for meter reading from solar meter, inverter etc.', bottomGap: 16.0, fontSize: 8.4),
              _buildClauseItem('4.', null, 'Provide electricity during plant installation and water for cleaning of the panels.', bottomGap: 16.0, fontSize: 8.4),
              _buildClauseItem('5.', null, 'Report any malfunctioning of the plant to the Vendor during the warranty period.', bottomGap: 16.0, fontSize: 8.4),
              _buildClauseItem('6.', null, 'Pay the amount as per the payment schedule as mutually agreed with the vendor, including any additional amount to the second party for any additional work /customization required depending upon the building condition.', bottomGap: 6.0, fontSize: 8.4),

              pw.Spacer(),
              _buildRunningFooter(agreement, 1, 3),
            ],
          );
        },
      ),
    );

    // =========================================================================
    // PAGE 2: Second Party Undertakings (ALL 18 Clauses) - Complete, Crisp & Exact
    // =========================================================================
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 36, vertical: 24),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              _buildRunningHeader(),

              pw.Text(
                'The Second Party hereby undertakes to perform the following activities:',
                style: pw.TextStyle(color: darkTextColor, fontSize: 9.2, fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 10),

              _buildClauseItem('1.', 'Standards & Scheme Compliance', 'The Vendor must follow all the standards and safety guidelines prescribed under state regulations and technical standards prescribed by MNRE for RTS projects, failing which the vendor is liable for blacklisting from participation in the govt. project/ scheme and other penal actions in accordance with the law. The responsibility of supply, installation and commissioning of the rooftop solar project/system in complete compliance with MNRE scheme guidelines lies with the Vendor.', bottomGap: 8.0, fontSize: 7.7),
              _buildClauseItem('2.', 'Site Survey', 'Site visit, survey and development of detailed project report for installation of RTS system. This also includes feasibility study of roof, strength of roof and shadow free area. If any additional work or customization is involved for the plant installation as per site condition and requirement of the consumer building, the Vendor shall prepare an estimate and can raise separate invoice including GST in addition to the amount towards standard plant cost. The consumer shall pay the amount for such additional work directly to the Vendor.', bottomGap: 8.0, fontSize: 7.7),
              _buildClauseItem('3.', 'Design & Engineering', 'Design of plant along with drawings and selection of components as per standard provided by the DISCOM/SERC/MNRE for best performance and safety of the plant.', bottomGap: 8.0, fontSize: 7.7),
              _buildClauseItem('4.', 'Module and Inverter', 'The solar modules, including the solar cells, should be manufactured in India. Both the solar modules and inverters shall conform to the relevant standards and specifications prescribed by MNRE. Any other requirement, viz. star labelling (solar modules), quality control orders and standards & labelling (inverters) etc., shall also be complied.', bottomGap: 8.0, fontSize: 7.7),
              _buildClauseItem('5.', 'Procurement & Supply', 'Procurement of complete system as per BIS/IS/IEC standard (whatever applicable) & safety guidelines for installation of rooftop solar plants. The supplied materials should comply with all MNRE standards for release of subsidy.', bottomGap: 8.0, fontSize: 7.7),
              _buildClauseItem('6.', 'Installation & Civil work', 'Complete civil work, structure work and electrical work (including drawings) following all the safety and relevant BIS standards.', bottomGap: 8.0, fontSize: 7.7),
              _buildClauseItem('7.', 'Documentation', 'Technical Catalogues/Warranty Certificates/BIS certificates/other test reports etc.: All such documents shall be provided to the consumer for online uploading and submission of technical specifications, IEC/BIS report, Sr. Nos, Warranty card of Solar Panel & Inverter, Layout & Electrical SLD, Structure Design and Drawing, Cable and other detailed documents.', bottomGap: 8.0, fontSize: 7.7),
              _buildClauseItem('8.', 'Project completion report (PCR)', 'Assisting the consumer in filling and uploading of signed documents (Consumer & Vendor) on the national portal.', bottomGap: 8.0, fontSize: 7.7),
              _buildClauseItem('9.', 'Warranty', 'System warranty certificates should be provided to the consumer. The complete system should be warranted for 5 years from the date of commissioning by DISCOM. Individual component warranty documents provided by the manufacturer shall be provided to the consumer and all possible assistance should be extended to the consumer for claiming the warranty from the manufacturer.', bottomGap: 8.0, fontSize: 7.7),
              _buildClauseItem('10.', 'NET meter & Grid Connectivity', 'Net meter supply/procurement, testing and approvals shall be in the scope of vendor. Grid connection of the plant shall be in the scope of the vendor.', bottomGap: 8.0, fontSize: 7.7),
              _buildClauseItem('11.', 'Testing and Commissioning', 'The vendor shall be present at the time of testing and commissioning by the DISCOM.', bottomGap: 8.0, fontSize: 7.7),
              _buildClauseItem('12.', 'Operation & Maintenance', 'Five (5) years Comprehensive Operation and Maintenance including overhauling, wear and tear and regular checking of healthiness of system at proper interval shall be in the scope of vendor. The vendor shall also educate the consumer on best practices for cleaning of the modules and system maintenance.', bottomGap: 8.0, fontSize: 7.7),
              _buildClauseItem('13.', 'Insurance', 'Any insurance cost pertaining to material transfer/storage before commissioning of the system shall be in the scope of the vendor.', bottomGap: 8.0, fontSize: 7.7),
              _buildClauseItem('14.', 'Applicable Standard', 'The system must meet the technical standards and specifications notified by MNRE. The vendor is solely responsible to supply component and service which meets the technical standards and specification prescribed by MNRE and State DISCOMs.', bottomGap: 8.0, fontSize: 7.7),
              _buildClauseItem('15.', 'Project/system cost & payment terms', 'The cost of the plant and payment schedule should be mutually discussed and decided between the vendor and consumer. The consumer may opt for milestone-based payment to the vendor and the same shall be included in the agreement.', bottomGap: 8.0, fontSize: 7.7),
              _buildClauseItem('16.', 'Dispute', 'In case of any dispute between consumer and vendor (in supply/installation/maintenance of system or payment terms), both parties must settle the same mutually or as per law. MNRE/DISCOM shall not be liable for, and would not be a party to any dispute arising between vendor and consumer.', bottomGap: 8.0, fontSize: 7.7),
              _buildClauseItem('17.', 'Subsidy / Project Related Documents', 'Vendor must provide all the documents to consumer and help in uploading the same to National Portal for smooth release of subsidy.', bottomGap: 8.0, fontSize: 7.7),
              _buildClauseItem('18.', 'Performance of Plant', 'The Performance Ratio (PR) of Plant must be >= 75% at the time of commissioning of the project by DISCOM or its authorised agency. Vendor must provide (returnable basis) radiation sensor with valid calibration certificate of any NABL / International laboratory at the time of commissioning / testing of the plant. Vendor must maintain the PR of the plant till warranty of project i.e. 5 years from the date of commissioning.', bottomGap: 6.0, fontSize: 7.7),

              pw.Spacer(),
              _buildRunningFooter(agreement, 2, 3),
            ],
          );
        },
      ),
    );

    // =========================================================================
    // PAGE 3: Clause 19, Payment Table, Table-Based First & Second Party Signatures, Disclaimer
    // =========================================================================
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 36, vertical: 24),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              _buildRunningHeader(),

              // Clause 19: Mutually Agreed Terms of Payment
              pw.Text(
                '19. Mutually Agreed Terms of Payment',
                style: pw.TextStyle(color: darkTextColor, fontSize: 10.5, fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 10),

              // Financial Overview Card (4 Columns)
              pw.Container(
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: borderDarkColor, width: 0.8),
                  color: headerBgColor,
                ),
                padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('Solar Capacity', style: const pw.TextStyle(color: slateMutedColor, fontSize: 6.8)),
                        pw.SizedBox(height: 2),
                        pw.Text(agreement.systemCapacity, style: pw.TextStyle(color: darkTextColor, fontSize: 8.8, fontWeight: pw.FontWeight.bold)),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('Total Project Cost', style: const pw.TextStyle(color: slateMutedColor, fontSize: 6.8)),
                        pw.SizedBox(height: 2),
                        pw.Text(agreement.totalProjectCost > 0 ? currencyFmt.format(agreement.totalProjectCost) : 'Rs. ____________', style: pw.TextStyle(color: darkTextColor, fontSize: 8.8, fontWeight: pw.FontWeight.bold)),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('Govt. CFA Subsidy', style: const pw.TextStyle(color: slateMutedColor, fontSize: 6.8)),
                        pw.SizedBox(height: 2),
                        pw.Text(currencyFmt.format(agreement.cfaSubsidyAmount), style: pw.TextStyle(color: darkTextColor, fontSize: 8.8, fontWeight: pw.FontWeight.bold)),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('Net Payable', style: const pw.TextStyle(color: slateMutedColor, fontSize: 6.8)),
                        pw.SizedBox(height: 2),
                        pw.Text(agreement.netCustomerPayable > 0 ? currencyFmt.format(agreement.netCustomerPayable) : 'Rs. ____________', style: pw.TextStyle(color: darkTextColor, fontSize: 8.8, fontWeight: pw.FontWeight.bold)),
                      ],
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 12),

              // Payment Milestone Table with Comfortable Cell Padding & Proper Column Widths
              pw.Table(
                border: pw.TableBorder.all(color: borderDarkColor, width: 0.8),
                columnWidths: {
                  0: const pw.FixedColumnWidth(28),
                  1: const pw.FlexColumnWidth(2.6),
                  2: const pw.FlexColumnWidth(1.1),
                  3: const pw.FlexColumnWidth(1.7),
                  4: const pw.FlexColumnWidth(3.4),
                },
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: headerBgColor),
                    children: [
                      pw.Padding(padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 6.0), child: pw.Text('Sr.', style: pw.TextStyle(color: darkTextColor, fontSize: 7.8, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.center)),
                      pw.Padding(padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 6.0), child: pw.Text('Milestone Stage', style: pw.TextStyle(color: darkTextColor, fontSize: 7.8, fontWeight: pw.FontWeight.bold))),
                      pw.Padding(padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 6.0), child: pw.Text('Share %', style: pw.TextStyle(color: darkTextColor, fontSize: 7.8, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.center)),
                      pw.Padding(padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 6.0), child: pw.Text('Amount (Rs.)', style: pw.TextStyle(color: darkTextColor, fontSize: 7.8, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.right)),
                      pw.Padding(padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 6.0), child: pw.Text('Payment Due Condition', style: pw.TextStyle(color: darkTextColor, fontSize: 7.8, fontWeight: pw.FontWeight.bold))),
                    ],
                  ),
                  ...agreement.paymentMilestones.map((m) {
                    return pw.TableRow(
                      children: [
                        pw.Padding(padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5.5), child: pw.Text('${m.sr}.', style: const pw.TextStyle(color: slateBodyColor, fontSize: 7.5), textAlign: pw.TextAlign.center)),
                        pw.Padding(padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5.5), child: pw.Text(m.stage, style: pw.TextStyle(color: darkTextColor, fontSize: 7.5, fontWeight: pw.FontWeight.bold))),
                        pw.Padding(padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5.5), child: pw.Text('${m.percentage.toStringAsFixed(0)}%', style: const pw.TextStyle(color: slateBodyColor, fontSize: 7.5), textAlign: pw.TextAlign.center)),
                        pw.Padding(padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5.5), child: pw.Text(m.amount > 0 ? currencyFmt.format(m.amount) : 'Rs. ____________', style: pw.TextStyle(color: darkTextColor, fontSize: 7.5, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.right)),
                        pw.Padding(padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5.5), child: pw.Text(m.description, style: const pw.TextStyle(color: slateBodyColor, fontSize: 7.3, lineSpacing: 1.25))),
                      ],
                    );
                  }),
                  // Table Total Summary Row
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: headerBgColor),
                    children: [
                      pw.Padding(padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5.5), child: pw.Text('', textAlign: pw.TextAlign.center)),
                      pw.Padding(padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5.5), child: pw.Text('Total Agreed Cost', style: pw.TextStyle(color: darkTextColor, fontSize: 7.8, fontWeight: pw.FontWeight.bold))),
                      pw.Padding(padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5.5), child: pw.Text('100%', style: pw.TextStyle(color: darkTextColor, fontSize: 7.8, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.center)),
                      pw.Padding(padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5.5), child: pw.Text(agreement.totalProjectCost > 0 ? currencyFmt.format(agreement.totalProjectCost) : 'Rs. ____________', style: pw.TextStyle(color: darkTextColor, fontSize: 7.8, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.right)),
                      pw.Padding(padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5.5), child: pw.Text('100% of Total Agreed Project', style: pw.TextStyle(color: slateMutedColor, fontSize: 7.3, fontStyle: pw.FontStyle.italic))),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 12),

              // ===================================================================
              // FIRST PARTY & SECOND PARTY TABLE-BASED SIGNATURE & STAMP BLOCK
              // Anchored directly to base with full vertical coverage & noble signing space
              // ===================================================================
              pw.Expanded(
                child: pw.Table(
                  border: pw.TableBorder.all(color: borderDarkColor, width: 0.8),
                  columnWidths: {
                    0: const pw.FlexColumnWidth(1),
                    1: const pw.FlexColumnWidth(1),
                  },
                  children: [
                    // Row 1: Header Row
                    pw.TableRow(
                      decoration: const pw.BoxDecoration(color: headerBgColor),
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          child: pw.Text('First Party (Consumer)', style: pw.TextStyle(color: darkTextColor, fontSize: 8.8, fontWeight: pw.FontWeight.bold)),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          child: pw.Text('Second Party (Vendor)', style: pw.TextStyle(color: darkTextColor, fontSize: 8.8, fontWeight: pw.FontWeight.bold)),
                        ),
                      ],
                    ),
                    // Row 2: Details Row
                    pw.TableRow(
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(10),
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Text('Name: ${agreement.customerName}', style: pw.TextStyle(color: darkTextColor, fontSize: 8.4, fontWeight: pw.FontWeight.bold)),
                              pw.SizedBox(height: 5),
                              pw.Text('Address: ${agreement.customerAddress.isNotEmpty ? agreement.customerAddress : "As per record"}', style: const pw.TextStyle(color: slateBodyColor, fontSize: 7.8)),
                              pw.SizedBox(height: 5),
                              pw.Text('Consumer No: ${agreement.consumerNo}', style: const pw.TextStyle(color: slateBodyColor, fontSize: 7.8)),
                              pw.SizedBox(height: 5),
                              pw.Text('Mobile: ${agreement.customerMobile.isNotEmpty ? agreement.customerMobile : "N/A"}', style: const pw.TextStyle(color: slateBodyColor, fontSize: 7.8)),
                              pw.SizedBox(height: 5),
                              pw.Text('System Capacity: ${agreement.systemCapacity} Grid Connected RTS', style: const pw.TextStyle(color: slateBodyColor, fontSize: 7.8)),
                            ],
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(10),
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Text('Name: SIYA INFOTECH & DIGITAL SOLUTIONS', style: pw.TextStyle(color: darkTextColor, fontSize: 8.4, fontWeight: pw.FontWeight.bold)),
                              pw.SizedBox(height: 5),
                              pw.Text('Address: 21, Mudavad Road, Betawad, Tal. Shindkheda, Dist. Dhule', style: const pw.TextStyle(color: slateBodyColor, fontSize: 7.8)),
                              pw.SizedBox(height: 5),
                              pw.Text('GSTIN: 27CVTPK6358P1ZD | Mobile: 7588003220', style: const pw.TextStyle(color: slateBodyColor, fontSize: 7.8)),
                              pw.SizedBox(height: 5),
                              pw.Text('Email: siyainfodigital@gmail.com', style: const pw.TextStyle(color: slateBodyColor, fontSize: 7.8)),
                              pw.SizedBox(height: 5),
                              pw.Text('Role: Vendor / Contractor / System Integrator', style: const pw.TextStyle(color: slateBodyColor, fontSize: 7.8)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    // Row 3: Base Signature & Dedicated Stamp Row
                    pw.TableRow(
                      children: [
                        // Consumer Signature Base
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(10),
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Text('Signature / Thumb Impression of First Party:', style: const pw.TextStyle(color: slateMutedColor, fontSize: 6.8)),
                              pw.SizedBox(height: 100),
                              pw.Container(height: 0.8, color: borderDarkColor),
                              pw.SizedBox(height: 4),
                              pw.Text('Signature of First Party (Consumer)', style: pw.TextStyle(color: darkTextColor, fontSize: 8.2, fontWeight: pw.FontWeight.bold)),
                              pw.SizedBox(height: 3),
                              pw.Text('Name: ${agreement.customerName}', style: const pw.TextStyle(color: slateBodyColor, fontSize: 7.4)),
                              pw.SizedBox(height: 2),
                              pw.Text('Date: ${agreement.formattedExecutionDate}   |   Place: Shindkheda', style: const pw.TextStyle(color: slateMutedColor, fontSize: 7.2)),
                            ],
                          ),
                        ),
                        // Vendor Signature & Dedicated Stamp Base
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(10),
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.center,
                            children: [
                              // Company Stamp & Authorized Signature (DEFAULT: included, can be removed)
                              if (includeStampAndSignature && stampAndSigImage != null) ...[
                                pw.Container(
                                  height: 70,
                                  alignment: pw.Alignment.center,
                                  child: pw.Image(stampAndSigImage, fit: pw.BoxFit.contain),
                                ),
                                pw.SizedBox(height: 36),
                              ] else ...[
                                // Completely blank space for manual company stamp
                                pw.SizedBox(height: 70),
                                pw.SizedBox(height: 36),
                              ],
                              pw.Container(height: 0.8, color: borderDarkColor),
                              pw.SizedBox(height: 4),
                              pw.Align(
                                alignment: pw.Alignment.centerLeft,
                                child: pw.Column(
                                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                                  children: [
                                    pw.Text('Authorized Signatory', style: pw.TextStyle(color: darkTextColor, fontSize: 8.2, fontWeight: pw.FontWeight.bold)),
                                    pw.Text('SIYA INFOTECH & DIGITAL SOLUTIONS', style: const pw.TextStyle(color: slateMutedColor, fontSize: 7.0)),
                                    pw.SizedBox(height: 2),
                                    pw.Text('Date: ${agreement.formattedExecutionDate}   |   Place: Shindkheda', style: const pw.TextStyle(color: slateMutedColor, fontSize: 7.2)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 10),

              // Official PM Surya Ghar Disclaimer
              pw.Container(
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: borderLightColor, width: 0.6),
                  color: headerBgColor,
                ),
                padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                child: pw.Text(
                  'Disclaimer: This agreement is between vendor and consumer and any dispute related to the same shall not involve any third party including MNRE and Distribution Utilities.',
                  style: pw.TextStyle(color: slateMutedColor, fontSize: 7.2, fontStyle: pw.FontStyle.italic),
                  textAlign: pw.TextAlign.center,
                ),
              ),
              pw.SizedBox(height: 6),
              _buildRunningFooter(agreement, 3, 3),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  /// Preview agreement in PDF preview dialog
  static Future<void> previewAgreement(
    BuildContext context,
    ConsumerVendorAgreement agreement, {
    bool includeStampAndSignature = true,
  }) async {
    final pdfBytes = await generateAgreementPdfBytes(
      agreement,
      includeStampAndSignature: includeStampAndSignature,
    );
    if (!context.mounted) return;
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdfBytes,
      name: agreement.pdfFileName,
    );
  }

  /// Download agreement PDF to local disk
  static Future<String?> downloadAgreementPdf(
    BuildContext context,
    ConsumerVendorAgreement agreement, {
    bool includeStampAndSignature = true,
  }) async {
    try {
      final pdfBytes = await generateAgreementPdfBytes(
        agreement,
        includeStampAndSignature: includeStampAndSignature,
      );
      final outputFile = await FilePicker.platform.saveFile(
        dialogTitle: 'Save Consumer-Vendor Agreement PDF',
        fileName: agreement.pdfFileName,
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );

      if (outputFile != null) {
        await Printing.sharePdf(
          bytes: pdfBytes,
          filename: agreement.pdfFileName,
        );
        return outputFile;
      }
      return null;
    } catch (e) {
      debugPrint('Error saving agreement PDF: $e');
      return null;
    }
  }

  /// Share agreement via WhatsApp Web
  static Future<void> shareViaWhatsApp(ConsumerVendorAgreement agreement) async {
    final phone = agreement.customerMobile.replaceAll(RegExp(r'\D'), '');
    final cleanPhone = phone.length == 10 ? '91$phone' : phone;

    final msg = Uri.encodeComponent(
      'Hello ${agreement.customerName},\n\n'
      'Please find the official Consumer-Vendor Agreement (Annexure 2) under PM Surya Ghar: Muft Bijli Yojana for your ${agreement.systemCapacity} Solar RTS Project.\n\n'
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
