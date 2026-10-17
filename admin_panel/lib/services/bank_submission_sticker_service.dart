import 'dart:io' show File;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show ByteData, rootBundle;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/consumer_record.dart';

class BankSubmissionStickerService {
  static const PdfColor darkPrimary = PdfColor.fromInt(0xFF0F172A);
  static const PdfColor slateSubtext = PdfColor.fromInt(0xFF334155);
  static const PdfColor lightBg = PdfColor.fromInt(0xFFF8FAFC);
  static const PdfColor lightBannerBg = PdfColor.fromInt(0xFFF1F5F9);
  static const PdfColor blackColor = PdfColor.fromInt(0xFF000000);
  static const PdfColor whiteColor = PdfColor.fromInt(0xFFFFFFFF);
  static const PdfColor lightBorderColor = PdfColor.fromInt(0xFFCBD5E1);

  /// Generates an A4 portrait PDF where each page contains exactly 2 stickers (top and bottom).
  /// Safe page margins and safe cutting margins ensure zero border clipping on any office printer.
  /// If an odd number of customers is selected, the bottom sticker of the last page remains blank.
  static Future<Uint8List> generateStickersPdfBytes(
    List<ConsumerRecord> customers, {
    Uint8List? customLogoBytes,
  }) async {
    final pdf = pw.Document();

    if (customers.isEmpty) {
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(24),
          build: (ctx) => pw.Center(
            child: pw.Text(
              'No customers selected for sticker printing.',
              style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
            ),
          ),
        ),
      );
      return pdf.save();
    }

    // Load Company Logo
    pw.MemoryImage? logoImage;
    if (customLogoBytes != null && customLogoBytes.isNotEmpty) {
      try {
        logoImage = pw.MemoryImage(customLogoBytes);
      } catch (_) {}
    }
    if (logoImage == null) {
      try {
        final ByteData logoData = await rootBundle.load('assets/images/logo.png');
        logoImage = pw.MemoryImage(logoData.buffer.asUint8List());
      } catch (_) {
        try {
          if (!kIsWeb) {
            final f = File('assets/images/logo.png');
            if (f.existsSync()) {
              logoImage = pw.MemoryImage(f.readAsBytesSync());
            }
          }
        } catch (_) {}
      }
    }

    // Process customers in pairs of 2 per A4 sheet (Horizontal / आडवे stickers with generous safe margins)
    for (int i = 0; i < customers.length; i += 2) {
      final topCustomer = customers[i];
      final bottomCustomer = (i + 1 < customers.length) ? customers[i + 1] : null;

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          // Page Margins: 24pt (~8.5mm) horizontal and 20pt (~7mm) vertical
          margin: const pw.EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                // Top Sticker: Centered with Generous Safe Margins
                pw.Expanded(
                  child: pw.Center(
                    child: pw.SizedBox(
                      width: 480,
                      height: 310,
                      child: _buildStickerBox(topCustomer, logoImage),
                    ),
                  ),
                ),

                // Center Cutting Guide with Wide Safe Buffer (Height: 28pt)
                pw.SizedBox(
                  height: 28,
                  child: _buildCuttingGuide(),
                ),

                // Bottom Sticker: Centered with Generous Safe Margins
                pw.Expanded(
                  child: bottomCustomer != null
                      ? pw.Center(
                          child: pw.SizedBox(
                            width: 480,
                            height: 310,
                            child: _buildStickerBox(bottomCustomer, logoImage),
                          ),
                        )
                      : pw.Container(),
                ),
              ],
            );
          },
        ),
      );
    }

    return pdf.save();
  }

  /// Builds a clean horizontal cutting guide between top and bottom stickers
  static pw.Widget _buildCuttingGuide() {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.Text(
            '> - - -',
            style: pw.TextStyle(
              fontSize: 8.5,
              fontWeight: pw.FontWeight.bold,
              color: darkPrimary,
            ),
          ),
          pw.Expanded(
            child: pw.Container(
              margin: const pw.EdgeInsets.symmetric(horizontal: 8),
              child: pw.LayoutBuilder(
                builder: (context, constraints) {
                  const dashWidth = 5.0;
                  const dashSpace = 4.0;
                  final dashCount = (constraints!.maxWidth / (dashWidth + dashSpace)).floor();
                  return pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: List.generate(
                      dashCount,
                      (_) => pw.SizedBox(
                        width: dashWidth,
                        height: 0.9,
                        child: pw.DecoratedBox(
                          decoration: const pw.BoxDecoration(color: darkPrimary),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          pw.Text(
            'CUT HERE / SAFE STICKER SEPARATION LINE',
            style: pw.TextStyle(
              fontSize: 7.2,
              fontWeight: pw.FontWeight.bold,
              color: darkPrimary,
              letterSpacing: 0.6,
            ),
          ),
          pw.Expanded(
            child: pw.Container(
              margin: const pw.EdgeInsets.symmetric(horizontal: 8),
              child: pw.LayoutBuilder(
                builder: (context, constraints) {
                  const dashWidth = 5.0;
                  const dashSpace = 4.0;
                  final dashCount = (constraints!.maxWidth / (dashWidth + dashSpace)).floor();
                  return pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: List.generate(
                      dashCount,
                      (_) => pw.SizedBox(
                        width: dashWidth,
                        height: 0.9,
                        child: pw.DecoratedBox(
                          decoration: const pw.BoxDecoration(color: darkPrimary),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          pw.Text(
            '- - - <',
            style: pw.TextStyle(
              fontSize: 8.5,
              fontWeight: pw.FontWeight.bold,
              color: darkPrimary,
            ),
          ),
        ],
      ),
    );
  }

  /// Formats capacity or returns blank string
  static String _formatCapacity(ConsumerRecord r) {
    if (r.systemCapacity != null && r.systemCapacity!.trim().isNotEmpty) {
      final s = r.systemCapacity!.trim();
      if (s.toLowerCase().contains('kw')) {
        return s;
      }
      return '$s kW';
    }
    if (r.capacityKw > 0) {
      final isInt = r.capacityKw.truncateToDouble() == r.capacityKw;
      return '${isInt ? r.capacityKw.toInt() : r.capacityKw.toStringAsFixed(1)} kW';
    }
    return '';
  }

  /// Builds a single professional Horizontal / आडवे sticker box sized compactly at 480x310pt.
  /// Features company logo, wide safe margins, high-contrast badges, and sharp document hierarchy.
  static pw.Widget _buildStickerBox(ConsumerRecord customer, pw.MemoryImage? logoImage) {
    final custName = customer.name.trim().toUpperCase();
    final custAddress = (customer.address ?? '').trim().toUpperCase();
    final mobileNo = (customer.mobile ?? '').trim();
    final consumerNo = customer.consumerNo.trim();
    final capacity = _formatCapacity(customer);

    return pw.Container(
      decoration: pw.BoxDecoration(
        color: whiteColor,
        border: pw.Border.all(color: darkPrimary, width: 2.0),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(5)),
      ),
      padding: const pw.EdgeInsets.all(2.5),
      child: pw.Container(
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: darkPrimary, width: 0.9),
          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(3)),
        ),
        padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            // ── 1. Company Branding Header with Official Logo ──
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: pw.BoxDecoration(
                color: lightBg,
                border: pw.Border.all(color: darkPrimary, width: 0.9),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(3)),
              ),
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  if (logoImage != null) ...[
                    pw.Container(
                      width: 32,
                      height: 32,
                      margin: const pw.EdgeInsets.only(right: 10),
                      decoration: pw.BoxDecoration(
                        color: whiteColor,
                        shape: pw.BoxShape.circle,
                        border: pw.Border.all(color: darkPrimary, width: 1.0),
                      ),
                      child: pw.ClipOval(
                        child: pw.Image(logoImage, fit: pw.BoxFit.cover),
                      ),
                    ),
                  ],
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      mainAxisAlignment: pw.MainAxisAlignment.center,
                      children: [
                        pw.Text(
                          'SIYA INFOTECH & SOLAR ENERGY',
                          style: pw.TextStyle(
                            color: darkPrimary,
                            fontSize: 13.5,
                            fontWeight: pw.FontWeight.bold,
                            letterSpacing: 0.4,
                          ),
                        ),
                        pw.SizedBox(height: 1),
                        pw.Text(
                          'Authorised Solar EPC & Digital Solutions | Betawad, Tal. Sindkheda, Dist. Dhule',
                          style: pw.TextStyle(
                            color: slateSubtext,
                            fontSize: 7.2,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        pw.Text(
                          'Helpline / Contact: 7588003220 / 7972143798',
                          style: pw.TextStyle(
                            color: darkPrimary,
                            fontSize: 7.6,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: const pw.BoxDecoration(
                      color: darkPrimary,
                      borderRadius: pw.BorderRadius.all(pw.Radius.circular(3)),
                    ),
                    child: pw.Column(
                      mainAxisSize: pw.MainAxisSize.min,
                      children: [
                        pw.Text(
                          'PM SURYA GHAR',
                          style: pw.TextStyle(
                            color: whiteColor,
                            fontSize: 8.0,
                            fontWeight: pw.FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                        pw.Text(
                          'GOVT. SUBSIDY SCHEME',
                          style: pw.TextStyle(
                            color: const PdfColor.fromInt(0xFFE2E8F0),
                            fontSize: 5.8,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ── 2. Official Document Category Ribbon ──
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: const pw.BoxDecoration(
                color: darkPrimary,
                borderRadius: pw.BorderRadius.all(pw.Radius.circular(2)),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'SOLAR ROOFTOP LOAN DOCUMENT DOSSIER',
                    style: pw.TextStyle(
                      color: whiteColor,
                      fontSize: 8.8,
                      fontWeight: pw.FontWeight.bold,
                      letterSpacing: 0.8,
                    ),
                  ),
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 7, vertical: 1.5),
                    decoration: const pw.BoxDecoration(
                      color: whiteColor,
                      borderRadius: pw.BorderRadius.all(pw.Radius.circular(2)),
                    ),
                    child: pw.Text(
                      'BANK SUBMISSION FILE',
                      style: pw.TextStyle(
                        color: darkPrimary,
                        fontSize: 7.5,
                        fontWeight: pw.FontWeight.bold,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── 3. Field 1: Customer Name (Horizontal Wide Box) ──
            pw.Container(
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: darkPrimary, width: 1.1),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(3)),
              ),
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  pw.Container(
                    width: 120,
                    padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 5.5),
                    color: lightBannerBg,
                    child: pw.Text(
                      'CUSTOMER NAME',
                      style: pw.TextStyle(
                        color: darkPrimary,
                        fontSize: 8.5,
                        fontWeight: pw.FontWeight.bold,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ),
                  pw.Container(width: 1.0, color: darkPrimary),
                  pw.Expanded(
                    child: pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
                      child: pw.Text(
                        custName,
                        style: pw.TextStyle(
                          color: darkPrimary,
                          fontSize: 13.5,
                          fontWeight: pw.FontWeight.bold,
                          letterSpacing: 0.3,
                        ),
                        maxLines: 1,
                        overflow: pw.TextOverflow.clip,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── 4. Field 2: Installation Address ──
            pw.Container(
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: darkPrimary, width: 1.1),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(3)),
              ),
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  pw.Container(
                    width: 120,
                    padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                    color: lightBannerBg,
                    child: pw.Text(
                      'INSTALLATION SITE',
                      style: pw.TextStyle(
                        color: darkPrimary,
                        fontSize: 8.0,
                        fontWeight: pw.FontWeight.bold,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ),
                  pw.Container(width: 1.0, color: darkPrimary),
                  pw.Expanded(
                    child: pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      child: pw.Text(
                        custAddress.isNotEmpty ? custAddress : ' ',
                        style: pw.TextStyle(
                          color: darkPrimary,
                          fontSize: 10.0,
                          fontWeight: pw.FontWeight.bold,
                        ),
                        maxLines: 2,
                        overflow: pw.TextOverflow.clip,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── 5. Fields: Key Details Grid (2 Rows x 2 Columns) ──
            pw.Table(
              border: pw.TableBorder.all(color: darkPrimary, width: 1.0),
              columnWidths: const {
                0: pw.FlexColumnWidth(1),
                1: pw.FlexColumnWidth(1),
              },
              children: [
                pw.TableRow(
                  children: [
                    _buildCell('CONSUMER NO.', consumerNo, valueFontSize: 13.5, isMonospace: true),
                    _buildCell('MOBILE NO.', mobileNo, valueFontSize: 13.0),
                  ],
                ),
                pw.TableRow(
                  children: [
                    _buildCell('SOLAR CAPACITY', capacity, valueFontSize: 13.0),
                    _buildCell('LOAN SCHEME', 'PM SURYA GHAR YOJANA LOAN', valueFontSize: 10.0),
                  ],
                ),
              ],
            ),

            // ── 6. Official Footer Docket Strip ──
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: pw.BoxDecoration(
                color: lightBannerBg,
                border: pw.Border.all(color: lightBorderColor, width: 0.8),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(2)),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'AUTHORISED EPC: SIYA INFOTECH & SOLAR ENERGY  |  OFFICIAL BANK DOCKET',
                    style: pw.TextStyle(
                      color: slateSubtext,
                      fontSize: 6.8,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.Text(
                    'VERIFIED & CERTIFIED FOR SUBMISSION',
                    style: pw.TextStyle(
                      color: darkPrimary,
                      fontSize: 6.8,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Builds a structured high-contrast cell for the sticker details table
  static pw.Widget _buildCell(
    String label,
    String value, {
    double valueFontSize = 13.0,
    bool isMonospace = false,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        mainAxisAlignment: pw.MainAxisAlignment.center,
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(
              color: slateSubtext,
              fontSize: 7.5,
              fontWeight: pw.FontWeight.bold,
              letterSpacing: 0.4,
            ),
          ),
          pw.SizedBox(height: 2.0),
          pw.Text(
            value.isNotEmpty ? value : '—',
            style: pw.TextStyle(
              color: darkPrimary,
              fontSize: valueFontSize,
              fontWeight: pw.FontWeight.bold,
              letterSpacing: isMonospace ? 0.7 : 0.3,
            ),
            maxLines: 1,
            overflow: pw.TextOverflow.clip,
          ),
        ],
      ),
    );
  }

  /// Triggers direct printing of selected stickers
  static Future<void> printStickers(List<ConsumerRecord> customers) async {
    final pdfBytes = await generateStickersPdfBytes(customers);
    final count = customers.length;
    final fileName = 'Bank_Submission_Stickers_${count}Cust_${DateFormat('yyyyMMdd').format(DateTime.now())}.pdf';
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdfBytes,
      name: fileName,
    );
  }

  /// Downloads / shares the PDF file of stickers
  static Future<void> downloadPdf(List<ConsumerRecord> customers) async {
    final pdfBytes = await generateStickersPdfBytes(customers);
    final count = customers.length;
    final fileName = 'Bank_Submission_Stickers_${count}Cust_${DateFormat('yyyyMMdd').format(DateTime.now())}.pdf';
    await Printing.sharePdf(
      bytes: pdfBytes,
      filename: fileName,
    );
  }
}
