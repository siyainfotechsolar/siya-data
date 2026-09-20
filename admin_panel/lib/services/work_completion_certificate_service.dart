import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/consumer_record.dart';

class WorkCompletionCertificateService {
  static const PdfColor navyColor = PdfColor.fromInt(0xFF0F2D69);
  static const PdfColor emeraldColor = PdfColor.fromInt(0xFF059669);
  static const PdfColor lightGreenColor = PdfColor.fromInt(0xFF10B981);
  static const PdfColor darkTextColor = PdfColor.fromInt(0xFF0F172A);
  static const PdfColor slateBodyColor = PdfColor.fromInt(0xFF334155);
  static const PdfColor slateMutedColor = PdfColor.fromInt(0xFF64748B);
  static const PdfColor tableBorderColor = PdfColor.fromInt(0xFFCBD5E1);
  static const PdfColor zebraBgColor = PdfColor.fromInt(0xFFF8FAFC);

  /// Generate Single-Page A4 PDF bytes for the Customer Work Completion Certificate
  static Future<Uint8List> generateCertificatePdfBytes(
    ConsumerRecord customer, {
    String? customCustomerName,
    String? customConsumerNo,
    String? customAddress,
    String? customCapacity,
    DateTime? customCompletionDate,
  }) async {
    final pdf = pw.Document();

    // Load Company Logo from Assets
    pw.MemoryImage? logoImage;
    try {
      final ByteData logoData = await rootBundle.load('assets/images/logo.png');
      logoImage = pw.MemoryImage(logoData.buffer.asUint8List());
    } catch (e) {
      debugPrint('Logo load error in admin WCR service: $e');
    }

    final String customerName = (customCustomerName != null && customCustomerName.trim().isNotEmpty)
        ? customCustomerName.trim()
        : customer.name.trim();

    final String consumerNo = (customConsumerNo != null && customConsumerNo.trim().isNotEmpty)
        ? customConsumerNo.trim()
        : customer.consumerNo.trim();

    // Resolve customer installation/completion date
    final DateTime completionDate = customCompletionDate ??
        customer.installationDate ??
        customer.rtsCompletionDate ??
        customer.submitDate ??
        DateTime.now();
    final String formattedCompletionDate = DateFormat('dd MMMM yyyy').format(completionDate);
    final String issueDateStr = DateFormat('dd-MM-yyyy').format(DateTime.now());

    // Resolve capacity display string
    String capacityDisplay = (customCapacity != null && customCapacity.trim().isNotEmpty)
        ? customCapacity.trim()
        : '';
    if (capacityDisplay.isEmpty && customer.remarks != null && customer.remarks!.trim().isNotEmpty) {
      final match = RegExp(r'(\d+(?:\.\d+)?\s*(?:kw|kW|KW|Kw))').firstMatch(customer.remarks!);
      if (match != null) capacityDisplay = match.group(1)!;
    }
    if (capacityDisplay.isEmpty) {
      capacityDisplay = '3.0 kW Rooftop Solar PV';
    }

    // Resolve address display string
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

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: pw.EdgeInsets.zero,
        build: (pw.Context context) {
          return pw.Container(
            width: PdfPageFormat.a4.width,
            height: PdfPageFormat.a4.height,
            padding: const pw.EdgeInsets.all(18),
            child: pw.Container(
              decoration: pw.BoxDecoration(
                color: PdfColors.white,
                border: pw.Border.all(color: navyColor, width: 1.5),
              ),
              padding: const pw.EdgeInsets.all(3.5),
              child: pw.Container(
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: lightGreenColor, width: 0.6),
                ),
                padding: const pw.EdgeInsets.symmetric(horizontal: 26, vertical: 20),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    // ==================================================
                    // 1. HEADER: BRANDING & LOGO
                    // ==================================================
                    pw.Row(
                      crossAxisAlignment: pw.CrossAxisAlignment.center,
                      children: [
                        if (logoImage != null)
                          pw.Container(
                            width: 58,
                            height: 58,
                            margin: const pw.EdgeInsets.only(right: 14),
                            child: pw.Image(logoImage, fit: pw.BoxFit.contain),
                          )
                        else
                          pw.Container(
                            width: 54,
                            height: 54,
                            margin: const pw.EdgeInsets.only(right: 14),
                            decoration: pw.BoxDecoration(
                              color: navyColor,
                              borderRadius: pw.BorderRadius.circular(6),
                            ),
                            child: pw.Center(
                              child: pw.Text(
                                'SIYA',
                                style: pw.TextStyle(
                                  color: PdfColors.white,
                                  fontWeight: pw.FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ),
                        pw.Expanded(
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Text(
                                'SIYA INFOTECH & SOLAR ENERGY',
                                style: pw.TextStyle(
                                  color: navyColor,
                                  fontSize: 14.5,
                                  fontWeight: pw.FontWeight.bold,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              pw.SizedBox(height: 2),
                              pw.Text(
                                'Solar Solutions & Digital Services',
                                style: pw.TextStyle(
                                  color: emeraldColor,
                                  fontSize: 9.0,
                                  fontWeight: pw.FontWeight.bold,
                                ),
                              ),
                              pw.SizedBox(height: 1),
                              pw.Text(
                                'Govt. Approved MNRE Channel Partner | Rooftop Solar Systems',
                                style: const pw.TextStyle(
                                  color: slateMutedColor,
                                  fontSize: 7.2,
                                ),
                              ),
                            ],
                          ),
                        ),
                        pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.end,
                          children: [
                            pw.Text(
                              'Phone: 7588003220',
                              style: pw.TextStyle(
                                color: navyColor,
                                fontSize: 8.0,
                                fontWeight: pw.FontWeight.bold,
                              ),
                            ),
                            pw.SizedBox(height: 1),
                            pw.Text(
                              'Email: siyainfodigital@gmail.com',
                              style: const pw.TextStyle(
                                color: slateBodyColor,
                                fontSize: 7.2,
                              ),
                            ),
                            pw.SizedBox(height: 1),
                            pw.Text(
                              '21, Mudavad Road, Betawad,',
                              style: const pw.TextStyle(
                                color: slateMutedColor,
                                fontSize: 6.8,
                              ),
                            ),
                            pw.Text(
                              'Tal. Shindkheda, Dist. Dhule - 425403',
                              style: const pw.TextStyle(
                                color: slateMutedColor,
                                fontSize: 6.8,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),

                    pw.SizedBox(height: 10),

                    // Decorative Dual-Tone Separator
                    pw.Row(
                      children: [
                        pw.Expanded(
                          flex: 7,
                          child: pw.Container(height: 2, color: navyColor),
                        ),
                        pw.Expanded(
                          flex: 3,
                          child: pw.Container(height: 2, color: lightGreenColor),
                        ),
                      ],
                    ),

                    pw.SizedBox(height: 12),

                    // ==================================================
                    // 2. CERTIFICATE TITLE BOX
                    // ==================================================
                    pw.Container(
                      width: double.infinity,
                      padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 12),
                      decoration: pw.BoxDecoration(
                        color: navyColor,
                        borderRadius: pw.BorderRadius.circular(4),
                      ),
                      child: pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: pw.CrossAxisAlignment.center,
                        children: [
                          pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Text(
                                'WORK COMPLETION CERTIFICATE',
                                style: pw.TextStyle(
                                  color: PdfColors.white,
                                  fontSize: 12.5,
                                  fontWeight: pw.FontWeight.bold,
                                  letterSpacing: 1.0,
                                ),
                              ),
                              pw.SizedBox(height: 1),
                              pw.Text(
                                'For Bank / Financial Institution Submission',
                                style: pw.TextStyle(
                                  color: lightGreenColor,
                                  fontSize: 7.5,
                                  fontWeight: pw.FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.end,
                            children: [
                              pw.Text(
                                'Ref: SIYA-WCR-${consumerNo.isNotEmpty ? consumerNo : "GEN"}',
                                style: const pw.TextStyle(
                                  color: PdfColors.white,
                                  fontSize: 7.5,
                                ),
                              ),
                              pw.SizedBox(height: 1),
                              pw.Text(
                                'Date: $issueDateStr',
                                style: const pw.TextStyle(
                                  color: PdfColors.white,
                                  fontSize: 7.5,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    pw.SizedBox(height: 12),

                    // ==================================================
                    // 3. STRICT 5-FIELD CUSTOMER SPECIFICATIONS TABLE
                    // ==================================================
                    pw.Container(
                      decoration: pw.BoxDecoration(
                        border: pw.Border.all(color: tableBorderColor, width: 0.8),
                        borderRadius: pw.BorderRadius.circular(4),
                      ),
                      child: pw.Column(
                        children: [
                          // Table Header
                          pw.Container(
                            padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: const pw.BoxDecoration(
                              color: navyColor,
                              borderRadius: pw.BorderRadius.only(
                                topLeft: pw.Radius.circular(3),
                                topRight: pw.Radius.circular(3),
                              ),
                            ),
                            child: pw.Row(
                              children: [
                                pw.Text(
                                  'PROJECT & BENEFICIARY DETAILS',
                                  style: pw.TextStyle(
                                    color: PdfColors.white,
                                    fontSize: 8.5,
                                    fontWeight: pw.FontWeight.bold,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Row 1: Customer Name
                          _buildTableRow('1. Customer Name', customerName, isZebra: false, isBoldValue: true),

                          // Row 2: Consumer Number
                          _buildTableRow('2. Consumer Number', consumerNo, isZebra: true, isBoldValue: true),

                          // Row 3: Project Address
                          _buildTableRow('3. Project Address', addressDisplay, isZebra: false),

                          // Row 4: Solar System Capacity
                          _buildTableRow('4. Solar System Capacity', capacityDisplay, isZebra: true, isBoldValue: true),

                          // Row 5: Installation / Completion Date
                          _buildTableRow('5. Installation Date', formattedCompletionDate, isZebra: false, isBoldValue: true, isLast: true),
                        ],
                      ),
                    ),

                    pw.SizedBox(height: 12),

                    // ==================================================
                    // 4. OFFICIAL COMPLETION DECLARATION
                    // ==================================================
                    pw.Container(
                      padding: const pw.EdgeInsets.all(10),
                      decoration: pw.BoxDecoration(
                        color: zebraBgColor,
                        border: pw.Border.all(color: tableBorderColor, width: 0.8),
                        borderRadius: pw.BorderRadius.circular(4),
                      ),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Row(
                            children: [
                              pw.Container(
                                width: 5,
                                height: 5,
                                decoration: const pw.BoxDecoration(
                                  color: emeraldColor,
                                  shape: pw.BoxShape.circle,
                                ),
                              ),
                              pw.SizedBox(width: 5),
                              pw.Text(
                                'OFFICIAL WORK COMPLETION DECLARATION',
                                style: pw.TextStyle(
                                  color: navyColor,
                                  fontSize: 8.5,
                                  fontWeight: pw.FontWeight.bold,
                                  letterSpacing: 0.4,
                                ),
                              ),
                            ],
                          ),
                          pw.SizedBox(height: 5),
                          pw.Text(
                            'This is to certify that the Rooftop Solar Photovoltaic (PV) System for the aforementioned customer has been successfully installed, commissioned, and tested in full accordance with the approved scheme, technical specifications, and safety guidelines prescribed by the Ministry of New and Renewable Energy (MNRE) and the State Power Distribution Utility (DISCOM).',
                            style: const pw.TextStyle(
                              color: slateBodyColor,
                              fontSize: 7.8,
                              lineSpacing: 1.3,
                            ),
                          ),
                          pw.SizedBox(height: 4),
                          pw.Text(
                            'The solar PV modules, inverter, structure, earthing, AC/DC protection units, and interconnecting cables have been physically verified, tested, and found completely operational, energised, and ready for regular grid-tied electricity generation and net-metering synchronisation.',
                            style: const pw.TextStyle(
                              color: slateBodyColor,
                              fontSize: 7.8,
                              lineSpacing: 1.3,
                            ),
                          ),
                        ],
                      ),
                    ),

                    pw.SizedBox(height: 10),

                    // Key Technical Compliance Metrics (Compact Grid)
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: pw.BoxDecoration(
                        border: pw.Border.all(color: tableBorderColor, width: 0.8),
                        borderRadius: pw.BorderRadius.circular(4),
                      ),
                      child: pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                        children: [
                          _buildComplianceChip('Grid Compliance', 'Verified & Safe'),
                          pw.Container(width: 1, height: 22, color: tableBorderColor),
                          _buildComplianceChip('Inverter Testing', 'Passed 100%'),
                          pw.Container(width: 1, height: 22, color: tableBorderColor),
                          _buildComplianceChip('Earthing & Lightning', 'Properly Grounded'),
                          pw.Container(width: 1, height: 22, color: tableBorderColor),
                          _buildComplianceChip('Physical Installation', 'Fully Completed'),
                        ],
                      ),
                    ),

                    pw.Spacer(),

                    // ==================================================
                    // 5. SIGNATURE & STAMP BLOCK (RIGHT ALIGNED)
                    // ==================================================
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        // Left: Official Verification Note & Customer Acknowledgement
                        pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Container(
                              padding: const pw.EdgeInsets.all(6),
                              decoration: pw.BoxDecoration(
                                border: pw.Border.all(color: tableBorderColor, width: 0.8),
                                borderRadius: pw.BorderRadius.circular(4),
                              ),
                              child: pw.Column(
                                crossAxisAlignment: pw.CrossAxisAlignment.start,
                                children: [
                                  pw.Text(
                                    'BENEFICIARY ACKNOWLEDGEMENT',
                                    style: pw.TextStyle(
                                      color: navyColor,
                                      fontSize: 7.5,
                                      fontWeight: pw.FontWeight.bold,
                                    ),
                                  ),
                                  pw.SizedBox(height: 2),
                                  pw.Text(
                                    'I confirm that the solar plant has been installed at my premises\nto my complete satisfaction and is generating power.',
                                    style: const pw.TextStyle(color: slateMutedColor, fontSize: 6.5),
                                  ),
                                  pw.SizedBox(height: 18),
                                  pw.Text(
                                    'Customer Signature: _______________________',
                                    style: pw.TextStyle(color: darkTextColor, fontSize: 7, fontWeight: pw.FontWeight.bold),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),

                        // Right: Official Company Seal & Signatory
                        pw.Container(
                          width: 200,
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.center,
                            children: [
                              pw.Text(
                                'For SIYA INFOTECH & SOLAR ENERGY',
                                style: pw.TextStyle(
                                  color: navyColor,
                                  fontSize: 8.5,
                                  fontWeight: pw.FontWeight.bold,
                                ),
                              ),
                              pw.SizedBox(height: 4),

                              // Seal / Stamp designated box
                              pw.Container(
                                width: 140,
                                height: 50,
                                decoration: pw.BoxDecoration(
                                  color: zebraBgColor,
                                  border: pw.Border.all(color: tableBorderColor, width: 0.8, style: pw.BorderStyle.dashed),
                                  borderRadius: pw.BorderRadius.circular(4),
                                ),
                                child: pw.Center(
                                  child: pw.Text(
                                    '[ OFFICIAL STAMP / SEAL ]',
                                    style: pw.TextStyle(
                                      color: slateMutedColor,
                                      fontSize: 7,
                                      fontWeight: pw.FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),

                              pw.SizedBox(height: 4),
                              pw.Container(width: 140, height: 1, color: navyColor),
                              pw.SizedBox(height: 2),
                              pw.Text(
                                'Authorized Signatory',
                                style: pw.TextStyle(
                                  color: darkTextColor,
                                  fontSize: 8,
                                  fontWeight: pw.FontWeight.bold,
                                ),
                              ),
                              pw.Text(
                                'Project Manager / Managing Director',
                                style: const pw.TextStyle(
                                  color: slateMutedColor,
                                  fontSize: 6.8,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    pw.SizedBox(height: 10),

                    // ==================================================
                    // 6. FOOTER
                    // ==================================================
                    pw.Container(height: 1, color: tableBorderColor),
                    pw.SizedBox(height: 4),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text(
                          'Helpline: 7588003220 | Email: siyainfodigital@gmail.com | Betawad, Dist. Dhule - 425403',
                          style: const pw.TextStyle(color: slateMutedColor, fontSize: 6.8),
                        ),
                        pw.Text(
                          'System-generated document issued for Bank & Official Submission',
                          style: pw.TextStyle(color: navyColor, fontSize: 6.8, fontWeight: pw.FontWeight.bold),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );

    return pdf.save();
  }

  static pw.Widget _buildTableRow(
    String label,
    String value, {
    required bool isZebra,
    bool isBoldValue = false,
    bool isLast = false,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
      decoration: pw.BoxDecoration(
        color: isZebra ? zebraBgColor : PdfColors.white,
        border: isLast
            ? null
            : const pw.Border(
                bottom: pw.BorderSide(color: tableBorderColor, width: 0.6),
              ),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 140,
            child: pw.Text(
              label,
              style: pw.TextStyle(
                color: navyColor,
                fontSize: 8.2,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ),
          pw.Text(':  ', style: pw.TextStyle(color: slateMutedColor, fontSize: 8.2, fontWeight: pw.FontWeight.bold)),
          pw.Expanded(
            child: pw.Text(
              value.isNotEmpty ? value : '—',
              style: pw.TextStyle(
                color: isBoldValue ? darkTextColor : slateBodyColor,
                fontSize: 8.2,
                fontWeight: isBoldValue ? pw.FontWeight.bold : pw.FontWeight.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildComplianceChip(String label, String status) {
    return pw.Column(
      mainAxisSize: pw.MainAxisSize.min,
      children: [
        pw.Text(
          label,
          style: const pw.TextStyle(color: slateMutedColor, fontSize: 6.8),
        ),
        pw.SizedBox(height: 1),
        pw.Text(
          status,
          style: pw.TextStyle(
            color: emeraldColor,
            fontSize: 7.2,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
      ],
    );
  }

  /// Download the Certificate directly to device / browser storage
  static Future<void> downloadCertificatePdf(
    BuildContext context,
    ConsumerRecord customer, {
    String? customCustomerName,
    String? customConsumerNo,
    String? customAddress,
    String? customCapacity,
    DateTime? customCompletionDate,
  }) async {
    try {
      final bytes = await generateCertificatePdfBytes(
        customer,
        customCustomerName: customCustomerName,
        customConsumerNo: customConsumerNo,
        customAddress: customAddress,
        customCapacity: customCapacity,
        customCompletionDate: customCompletionDate,
      );
      final effectiveName = (customCustomerName != null && customCustomerName.trim().isNotEmpty)
          ? customCustomerName.trim()
          : customer.name.trim();
      final effectiveConsumerNo = (customConsumerNo != null && customConsumerNo.trim().isNotEmpty)
          ? customConsumerNo.trim()
          : customer.consumerNo.trim();
      final safeName = effectiveName.replaceAll(RegExp(r'[^\w\s-]'), '').replaceAll(RegExp(r'\s+'), '_');
      final fileName = 'Work_Completion_Certificate_${safeName}_$effectiveConsumerNo.pdf';

      final result = await FilePicker.platform.saveFile(
        dialogTitle: 'Download Work Completion Certificate',
        fileName: fileName,
        bytes: bytes,
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );

      if (result != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Certificate downloaded successfully ($fileName)!'),
            backgroundColor: const Color(0xFF059669),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to download certificate: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Trigger Direct Print / Browser Print Layout
  static Future<void> printCertificate(
    ConsumerRecord customer, {
    String? customCustomerName,
    String? customConsumerNo,
    String? customAddress,
    String? customCapacity,
    DateTime? customCompletionDate,
  }) async {
    final effectiveConsumerNo = (customConsumerNo != null && customConsumerNo.trim().isNotEmpty)
        ? customConsumerNo.trim()
        : customer.consumerNo.trim();
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async {
        return generateCertificatePdfBytes(
          customer,
          customCustomerName: customCustomerName,
          customConsumerNo: customConsumerNo,
          customAddress: customAddress,
          customCapacity: customCapacity,
          customCompletionDate: customCompletionDate,
        );
      },
      name: 'Work_Completion_Certificate_$effectiveConsumerNo',
    );
  }

  /// Send Work Completion Details & Notification via WhatsApp
  static Future<void> sendOnWhatsApp(BuildContext context, ConsumerRecord customer) async {
    final phone = (customer.mobile ?? '').replaceAll(RegExp(r'\D'), '');
    if (phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Customer phone number is not available for WhatsApp.')),
      );
      return;
    }

    String capacityDisplay = '';
    if (customer.remarks != null && customer.remarks!.trim().isNotEmpty) {
      final match = RegExp(r'(\d+(?:\.\d+)?\s*(?:kw|kW|KW|Kw))').firstMatch(customer.remarks!);
      if (match != null) capacityDisplay = match.group(1)!;
    }
    if (capacityDisplay.isEmpty) capacityDisplay = '3.0 kW Rooftop Solar PV';

    final message = '''
*SIYA INFOTECH & SOLAR ENERGY*
*Work Completion Certificate Update*

Dear *${customer.name}*,
Congratulations! Your Rooftop Solar PV System ($capacityDisplay) installation has been successfully completed and certified.

📋 *Certificate Summary*:
• Consumer No: ${customer.consumerNo}
• Capacity: $capacityDisplay
• Installation Status: Completed & Tested
• Compliance: MNRE & Grid Safety Standards Verified

Your official Work Completion Certificate has been generated for bank / financial institution submission.

For any questions, contact us:
📞 7588003220
✉ siyainfodigital@gmail.com
📍 21, Mudavad Road, Betawad, Tal. Shindkheda, Dist. Dhule - 425403
''';

    final uri = Uri.parse('https://wa.me/$phone?text=${Uri.encodeComponent(message)}');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not open WhatsApp.')),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error opening WhatsApp: $e')),
        );
      }
    }
  }
}
