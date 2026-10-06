import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/invoice.dart';
import 'company_stamp_helper.dart';

/// Professional A4 Invoice PDF Generator
/// Design: White background, Deep Blue, Green, Golden Yellow accents
class InvoicePdfService {
  // ── Brand Colors ──────────────────────────────────────────────────────────
  static const PdfColor deepBlue = PdfColor.fromInt(0xFF0D2B6F);
  static const PdfColor emerald = PdfColor.fromInt(0xFF047857);
  static const PdfColor goldenYellow = PdfColor.fromInt(0xFFF59E0B);
  static const PdfColor darkText = PdfColor.fromInt(0xFF0F172A);
  static const PdfColor slateBody = PdfColor.fromInt(0xFF1E293B);
  static const PdfColor slateMuted = PdfColor.fromInt(0xFF475569);
  static const PdfColor borderDark = PdfColor.fromInt(0xFF334155);
  static const PdfColor headerBg = PdfColor.fromInt(0xFFF1F5F9);
  static const PdfColor zebraBg = PdfColor.fromInt(0xFFF8FAFC);
  static const PdfColor white = PdfColor(1, 1, 1);

  static final _inr = NumberFormat('#,##,##0.00', 'en_IN');

  /// Generate professional A4 Invoice PDF bytes
  static Future<Uint8List> generateInvoicePdfBytes(
    Invoice invoice, {
    bool includeStampAndSignature = false,
    Uint8List? customStampBytes,
  }) async {
    final pdf = pw.Document();

    // Load logo
    pw.MemoryImage? logoImage;
    try {
      final ByteData logoData = await rootBundle.load('assets/images/logo.png');
      logoImage = pw.MemoryImage(logoData.buffer.asUint8List());
    } catch (_) {}

    // Load stamp
    pw.MemoryImage? stampImage;
    if (includeStampAndSignature) {
      final stampBytes = await AdminCompanyStampHelper.loadStampAndSignatureBytes(
        customBytes: customStampBytes,
      );
      if (stampBytes != null) {
        stampImage = pw.MemoryImage(stampBytes);
      }
    }

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(28, 20, 28, 20),
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              // ── Header ──────────────────────────────────────────────────
              _buildHeader(invoice, logoImage),
              pw.SizedBox(height: 10),

              // ── Invoice Info Row ────────────────────────────────────────
              _buildInvoiceInfoRow(invoice),
              pw.SizedBox(height: 10),

              // ── Customer Details ────────────────────────────────────────
              _buildSectionHeader('CUSTOMER DETAILS'),
              _buildCustomerDetails(invoice),
              pw.SizedBox(height: 8),

              // ── Item Table ──────────────────────────────────────────────
              _buildSectionHeader('INVOICE ITEMS'),
              _buildItemTable(invoice),
              pw.SizedBox(height: 8),

              // ── Financial Summary ───────────────────────────────────────
              _buildSectionHeader('FINANCIAL SUMMARY'),
              _buildFinancialSummary(invoice),
              pw.SizedBox(height: 6),

              // ── Amount in Words ─────────────────────────────────────────
              _buildAmountInWords(invoice),
              pw.SizedBox(height: 8),

              // ── Payment Summary ─────────────────────────────────────────
              _buildSectionHeader('PAYMENT DETAILS'),
              _buildPaymentSummary(invoice),

              pw.Spacer(),

              // ── Helpline & Stamp/Signature ──────────────────────────────
              _buildFooter(invoice, stampImage, includeStampAndSignature),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  // ── Header ──────────────────────────────────────────────────────────────────

  static pw.Widget _buildHeader(Invoice invoice, pw.MemoryImage? logo) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        gradient: pw.LinearGradient(
          colors: [deepBlue, const PdfColor.fromInt(0xFF1A3A8F)],
        ),
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Row(
        children: [
          if (logo != null) ...[
            pw.Container(
              width: 44,
              height: 44,
              decoration: pw.BoxDecoration(
                shape: pw.BoxShape.circle,
                color: white,
              ),
              padding: const pw.EdgeInsets.all(3),
              child: pw.ClipOval(child: pw.Image(logo, fit: pw.BoxFit.contain)),
            ),
            pw.SizedBox(width: 10),
          ],
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'SIYA INFOTECH & DIGITAL SOLUTIONS',
                  style: pw.TextStyle(
                    color: white,
                    fontSize: 11,
                    fontWeight: pw.FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
                pw.SizedBox(height: 2),
                pw.Text(
                  'Solar Solutions & Digital Services',
                  style: pw.TextStyle(
                    color: const PdfColor.fromInt(0xFFBFDBFE),
                    fontSize: 7.5,
                    fontStyle: pw.FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: pw.BoxDecoration(
              color: goldenYellow,
              borderRadius: pw.BorderRadius.circular(4),
            ),
            child: pw.Text(
              'INVOICE',
              style: pw.TextStyle(
                color: darkText,
                fontSize: 12,
                fontWeight: pw.FontWeight.bold,
                letterSpacing: 1,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Invoice Info Row ────────────────────────────────────────────────────────

  static pw.Widget _buildInvoiceInfoRow(Invoice invoice) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: borderDark, width: 0.8),
        borderRadius: pw.BorderRadius.circular(4),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.RichText(
                text: pw.TextSpan(
                  children: [
                    pw.TextSpan(
                      text: 'Invoice No.: ',
                      style: pw.TextStyle(color: slateMuted, fontSize: 7.5, fontWeight: pw.FontWeight.bold),
                    ),
                    pw.TextSpan(
                      text: invoice.invoiceNumber,
                      style: pw.TextStyle(color: deepBlue, fontSize: 8.5, fontWeight: pw.FontWeight.bold),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 2),
              pw.RichText(
                text: pw.TextSpan(
                  children: [
                    pw.TextSpan(
                      text: 'Ref. Invoice No.: ',
                      style: pw.TextStyle(color: slateMuted, fontSize: 7.5, fontWeight: pw.FontWeight.bold),
                    ),
                    pw.TextSpan(
                      text: invoice.refInvoiceNo,
                      style: pw.TextStyle(color: emerald, fontSize: 8, fontWeight: pw.FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ],
          ),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.RichText(
                text: pw.TextSpan(
                  children: [
                    pw.TextSpan(
                      text: 'Invoice Date: ',
                      style: pw.TextStyle(color: slateMuted, fontSize: 7.5, fontWeight: pw.FontWeight.bold),
                    ),
                    pw.TextSpan(
                      text: invoice.formattedDate,
                      style: pw.TextStyle(color: darkText, fontSize: 8, fontWeight: pw.FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Section Header ──────────────────────────────────────────────────────────

  static pw.Widget _buildSectionHeader(String title) {
    return pw.Container(
      decoration: pw.BoxDecoration(
        color: headerBg,
        border: pw.Border.all(color: borderDark, width: 0.8),
      ),
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 2.2),
      child: pw.Row(
        children: [
          pw.Container(
            width: 3.5,
            height: 10,
            color: deepBlue,
            margin: const pw.EdgeInsets.only(right: 6),
          ),
          pw.Text(
            title,
            style: pw.TextStyle(
              color: darkText,
              fontSize: 8.2,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  // ── Customer Details ────────────────────────────────────────────────────────

  static pw.Widget _buildCustomerDetails(Invoice invoice) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(6),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: borderDark, width: 0.5),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                _infoRow('Customer Name', invoice.customerName),
                _infoRow('Address', invoice.address),
                _infoRow('Village / City', invoice.villageCity),
              ],
            ),
          ),
          pw.SizedBox(width: 10),
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                _infoRow('District', invoice.district),
                _infoRow('Consumer No.', invoice.consumerNo),
                _infoRow('Mobile No.', invoice.mobileNo),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _infoRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 2),
      child: pw.RichText(
        text: pw.TextSpan(
          children: [
            pw.TextSpan(
              text: '$label: ',
              style: pw.TextStyle(color: slateMuted, fontSize: 7, fontWeight: pw.FontWeight.bold),
            ),
            pw.TextSpan(
              text: value.isNotEmpty ? value : '—',
              style: pw.TextStyle(color: darkText, fontSize: 7.5),
            ),
          ],
        ),
      ),
    );
  }

  // ── Item Table ──────────────────────────────────────────────────────────────

  static pw.Widget _buildItemTable(Invoice invoice) {
    final items = invoice.items;
    return pw.Table(
      border: pw.TableBorder.all(color: borderDark, width: 0.5),
      columnWidths: {
        0: const pw.FixedColumnWidth(28),
        1: const pw.FlexColumnWidth(3),
        2: const pw.FlexColumnWidth(3),
        3: const pw.FixedColumnWidth(45),
        4: const pw.FixedColumnWidth(55),
        5: const pw.FixedColumnWidth(60),
      },
      children: [
        // Header
        pw.TableRow(
          decoration: pw.BoxDecoration(color: deepBlue),
          children: ['Sr.', 'Description', 'Specification', 'Qty.', 'Rate', 'Amount']
              .map((h) => pw.Container(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3),
                    child: pw.Text(
                      h,
                      style: pw.TextStyle(
                        color: white,
                        fontSize: 7,
                        fontWeight: pw.FontWeight.bold,
                      ),
                      textAlign: h == 'Rate' || h == 'Amount' ? pw.TextAlign.right : pw.TextAlign.left,
                    ),
                  ))
              .toList(),
        ),
        // Data rows
        ...items.asMap().entries.map((entry) {
          final idx = entry.key;
          final item = entry.value;
          final isZebra = idx % 2 == 1;
          return pw.TableRow(
            decoration: isZebra ? pw.BoxDecoration(color: zebraBg) : null,
            children: [
              _tableCell(item['sr'] ?? '${idx + 1}'),
              _tableCell(item['item'] ?? item['description'] ?? ''),
              _tableCell(item['spec'] ?? item['specification'] ?? ''),
              _tableCell(item['qty'] ?? item['quantity'] ?? ''),
              _tableCell(item['rate'] ?? '', align: pw.TextAlign.right),
              _tableCell(item['amount'] ?? '', align: pw.TextAlign.right),
            ],
          );
        }),
      ],
    );
  }

  static pw.Widget _tableCell(String text, {pw.TextAlign align = pw.TextAlign.left}) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 2.5),
      child: pw.Text(
        text,
        style: pw.TextStyle(color: slateBody, fontSize: 7),
        textAlign: align,
      ),
    );
  }

  // ── Financial Summary ───────────────────────────────────────────────────────

  static pw.Widget _buildFinancialSummary(Invoice invoice) {
    final gst = invoice.gstBreakdown;
    return pw.Container(
      padding: const pw.EdgeInsets.all(6),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: borderDark, width: 0.5),
      ),
      child: pw.Column(
        children: [
          _summaryRow('Taxable Amount', '₹ ${_inr.format(gst.totalTaxableValue)}'),
          _summaryRow('GST Included @ 5% (70% Portion)', '₹ ${_inr.format(gst.gst5)}'),
          _summaryRow('GST Included @ 18% (30% Portion)', '₹ ${_inr.format(gst.gst18)}'),
          _summaryRow('Total GST Included', '₹ ${_inr.format(gst.totalGstIncluded)}', highlight: true),
          pw.Divider(color: borderDark, height: 6, thickness: 0.5),
          _summaryRow('GRAND TOTAL', '₹ ${_inr.format(invoice.grandTotal)}', isBold: true, isGrand: true),
        ],
      ),
    );
  }

  static pw.Widget _summaryRow(String label, String value, {bool isBold = false, bool isGrand = false, bool highlight = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 1.2),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(
              color: highlight ? emerald : (isGrand ? deepBlue : slateMuted),
              fontSize: isGrand ? 9 : 7.5,
              fontWeight: isBold || isGrand ? pw.FontWeight.bold : pw.FontWeight.normal,
            ),
          ),
          pw.Text(
            value,
            style: pw.TextStyle(
              color: isGrand ? deepBlue : darkText,
              fontSize: isGrand ? 10 : 7.5,
              fontWeight: isBold || isGrand ? pw.FontWeight.bold : pw.FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  // ── Amount in Words ─────────────────────────────────────────────────────────

  static pw.Widget _buildAmountInWords(Invoice invoice) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: pw.BoxDecoration(
        color: const PdfColor.fromInt(0xFFFEF3C7),
        border: pw.Border.all(color: goldenYellow, width: 0.8),
        borderRadius: pw.BorderRadius.circular(3),
      ),
      child: pw.RichText(
        text: pw.TextSpan(
          children: [
            pw.TextSpan(
              text: 'Amount in Words: ',
              style: pw.TextStyle(color: slateMuted, fontSize: 7, fontWeight: pw.FontWeight.bold),
            ),
            pw.TextSpan(
              text: invoice.amountInWords,
              style: pw.TextStyle(color: darkText, fontSize: 7.5, fontWeight: pw.FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  // ── Payment Summary ─────────────────────────────────────────────────────────

  static pw.Widget _buildPaymentSummary(Invoice invoice) {
    final statusColor = invoice.paymentStatus == 'Paid'
        ? emerald
        : (invoice.paymentStatus == 'Partially Paid'
            ? const PdfColor.fromInt(0xFF0284C7)
            : goldenYellow);

    return pw.Container(
      padding: const pw.EdgeInsets.all(6),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: borderDark, width: 0.5),
      ),
      child: pw.Row(
        children: [
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                _summaryRow('Total Invoice Amount', '₹ ${_inr.format(invoice.grandTotal)}'),
                _summaryRow('Total Paid', '₹ ${_inr.format(invoice.totalPaid)}'),
                _summaryRow('Total Pending', '₹ ${_inr.format(invoice.totalPending)}'),
              ],
            ),
          ),
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: pw.BoxDecoration(
              color: statusColor,
              borderRadius: pw.BorderRadius.circular(4),
            ),
            child: pw.Text(
              invoice.paymentStatus,
              style: pw.TextStyle(
                color: invoice.paymentStatus == 'Pending' ? darkText : white,
                fontSize: 8,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Footer ──────────────────────────────────────────────────────────────────

  static pw.Widget _buildFooter(Invoice invoice, pw.MemoryImage? stampImage, bool includeStamp) {
    return pw.Column(
      children: [
        // Helpline
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: pw.BoxDecoration(
            color: headerBg,
            border: pw.Border.all(color: borderDark, width: 0.5),
            borderRadius: pw.BorderRadius.circular(3),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.center,
            children: [
              pw.Text(
                'Helpline: 7972143798  |  Owner: Manoj Kshirsagar  |  SIYA INFOTECH & DIGITAL SOLUTIONS',
                style: pw.TextStyle(color: slateMuted, fontSize: 6.5, fontWeight: pw.FontWeight.bold),
              ),
            ],
          ),
        ),
        pw.SizedBox(height: 6),

        // Stamp & Signature
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.end,
          children: [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                AdminCompanyStampHelper.buildStampAndSignatureWidget(
                  image: stampImage,
                  include: includeStamp,
                  height: 64,
                  width: 150,
                ),
                pw.SizedBox(height: 2),
                pw.Text(
                  'For SIYA INFOTECH & DIGITAL SOLUTIONS',
                  style: pw.TextStyle(color: deepBlue, fontSize: 6.5, fontWeight: pw.FontWeight.bold),
                ),
                pw.Text(
                  'Authorized Signatory',
                  style: pw.TextStyle(color: slateMuted, fontSize: 6),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  // ── Print ───────────────────────────────────────────────────────────────────

  static Future<void> printInvoice(Invoice invoice) async {
    final bytes = await generateInvoicePdfBytes(invoice);
    await Printing.layoutPdf(onLayout: (_) => bytes);
  }

  // ── Download / Share ────────────────────────────────────────────────────────

  static Future<void> shareInvoice(Invoice invoice) async {
    final bytes = await generateInvoicePdfBytes(invoice);
    await Printing.sharePdf(
      bytes: bytes,
      filename: invoice.pdfFileName ?? 'Invoice.pdf',
    );
  }

  /// Share on WhatsApp
  static Future<void> shareOnWhatsApp(Invoice invoice) async {
    final phone = invoice.mobileNo.replaceAll(RegExp(r'[^0-9]'), '');
    final fullPhone = phone.startsWith('91') ? phone : '91$phone';
    final message = Uri.encodeComponent(
      'Dear ${invoice.customerName},\n\n'
      'Your Invoice ${invoice.invoiceNumber} '
      '(Ref: ${invoice.refInvoiceNo}) has been generated.\n\n'
      'Grand Total: ₹${_inr.format(invoice.grandTotal)}\n'
      'Status: ${invoice.paymentStatus}\n\n'
      'SIYA INFOTECH & DIGITAL SOLUTIONS\n'
      'Helpline: 7972143798',
    );
    final url = Uri.parse('https://wa.me/$fullPhone?text=$message');
    try {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }
}
