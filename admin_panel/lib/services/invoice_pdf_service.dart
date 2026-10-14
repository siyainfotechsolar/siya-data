import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/invoice.dart';
import 'company_stamp_helper.dart';

/// Professional A4 GST Invoice PDF Generator matching Siya live invoices
class InvoicePdfService {
  static const PdfColor darkText = PdfColor.fromInt(0xFF0F172A);
  static const PdfColor slateBody = PdfColor.fromInt(0xFF1E293B);
  static const PdfColor slateMuted = PdfColor.fromInt(0xFF475569);
  static const PdfColor borderLight = PdfColor.fromInt(0xFF94A3B8);
  static const PdfColor borderDark = PdfColor.fromInt(0xFF475569);
  static const PdfColor tableHeaderBg = PdfColor.fromInt(0xFFF8FAFC);
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

    // Load stamp (if selected)
    pw.MemoryImage? stampImage;
    if (includeStampAndSignature) {
      final stampBytes = await AdminCompanyStampHelper.loadStampAndSignatureBytes(
        customBytes: customStampBytes,
      );
      if (stampBytes != null) {
        stampImage = pw.MemoryImage(stampBytes);
      }
    }

    final gst = invoice.gstBreakdown;

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(26, 22, 26, 18),
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              // ── Header (Company info on left, GST INVOICE on right) ────────
              _buildHeader(logoImage),
              pw.SizedBox(height: 10),

              // ── Metadata Box (Invoice#, Date, Place of Supply, Price) ───────
              _buildMetadataBox(invoice),
              pw.SizedBox(height: 8),

              // ── Customer & Subject ──────────────────────────────────────────
              _buildCustomerSubject(invoice),
              pw.SizedBox(height: 8),

              // ── The 2 Statutory Line Items Table ───────────────────────────
              _buildItemTable(invoice, gst),
              pw.SizedBox(height: 10),

              // ── Lower Section: Bank/Terms/QR on left & Totals on right ──────
              _buildLowerSection(invoice, gst, stampImage, includeStampAndSignature),

              pw.Spacer(),

              // ── Footer ──────────────────────────────────────────────────────
              _buildFooter(),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  // ── 1. Header ──────────────────────────────────────────────────────────────

  static pw.Widget _buildHeader(pw.MemoryImage? logo) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        // Company info & Logo
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            if (logo != null) ...[
              pw.Container(
                width: 48,
                height: 48,
                margin: const pw.EdgeInsets.only(right: 10),
                child: pw.Image(logo, fit: pw.BoxFit.contain),
              ),
            ],
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'Siya Infotech & Digital Solution',
                  style: pw.TextStyle(
                    color: darkText,
                    fontSize: 13,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 2),
                pw.Text('MUDAVAD ROAD ,AT POST BETAWAD,', style: pw.TextStyle(color: slateBody, fontSize: 8)),
                pw.Text('TALUKA SHINDKHEDA', style: pw.TextStyle(color: slateBody, fontSize: 8)),
                pw.Text('DHULE Maharashtra 425403', style: pw.TextStyle(color: slateBody, fontSize: 8)),
                pw.Text('India', style: pw.TextStyle(color: slateBody, fontSize: 8)),
                pw.SizedBox(height: 1),
                pw.Text('GSTIN 27CVTPK6358P1ZD', style: pw.TextStyle(color: darkText, fontSize: 8, fontWeight: pw.FontWeight.bold)),
                pw.Text('7588003220', style: pw.TextStyle(color: slateBody, fontSize: 8)),
              ],
            ),
          ],
        ),

        // Big "GST INVOICE" title on right
        pw.Padding(
          padding: const pw.EdgeInsets.only(top: 8),
          child: pw.Text(
            'GST INVOICE',
            style: pw.TextStyle(
              color: darkText,
              fontSize: 20,
              fontWeight: pw.FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
        ),
      ],
    );
  }

  // ── 2. Metadata Box ────────────────────────────────────────────────────────

  static pw.Widget _buildMetadataBox(Invoice invoice) {
    final dateStr = DateFormat('dd/MM/yyyy').format(invoice.invoiceDate);

    return pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: borderLight, width: 0.7),
      ),
      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: pw.Row(
        children: [
          // Left side
          pw.Expanded(
            flex: 5,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                _metaLine('Invoice#', invoice.invoiceNumber.isNotEmpty ? invoice.invoiceNumber : 'SID000321', isBoldValue: true),
                _metaLine('Invoice Date', dateStr),
                _metaLine('Terms', 'Due on Receipt'),
                _metaLine('Due Date', dateStr),
              ],
            ),
          ),
          // Vertical divider line
          pw.Container(width: 0.7, height: 48, color: borderLight),
          pw.SizedBox(width: 12),
          // Right side
          pw.Expanded(
            flex: 5,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                _metaLine('Place Of Supply', 'Maharashtra (27)'),
                _metaLine('PRICE', _inr.format(invoice.grandTotal), isBoldValue: true),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _metaLine(String label, String value, {bool isBoldValue = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 1.5),
      child: pw.Row(
        children: [
          pw.SizedBox(
            width: 82,
            child: pw.Text(
              '$label :',
              style: pw.TextStyle(color: slateMuted, fontSize: 7.8, fontWeight: pw.FontWeight.bold),
            ),
          ),
          pw.Text(
            value,
            style: pw.TextStyle(
              color: darkText,
              fontSize: 8,
              fontWeight: isBoldValue ? pw.FontWeight.bold : pw.FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  // ── 3. Customer Name & Subject ─────────────────────────────────────────────

  static pw.Widget _buildCustomerSubject(Invoice invoice) {
    final capStr = invoice.systemCapacity.isNotEmpty ? invoice.systemCapacity : '3kw';
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          invoice.customerName.toLowerCase(),
          style: pw.TextStyle(
            color: darkText,
            fontSize: 10.5,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.SizedBox(height: 6),
        pw.Text('Subject :', style: pw.TextStyle(color: slateMuted, fontSize: 8, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 1),
        pw.Text(
          'solar power gen system $capStr under pm suryghar yojan',
          style: pw.TextStyle(color: slateBody, fontSize: 8),
        ),
      ],
    );
  }

  // ── 4. The 2-Line Items Table ──────────────────────────────────────────────

  static pw.Widget _buildItemTable(Invoice invoice, dynamic gst) {
    final capStr = invoice.systemCapacity.isNotEmpty ? invoice.systemCapacity : '3Kwp';

    // Item 1 (70% Goods portion @ 5% GST = 2.5% CGST + 2.5% SGST)
    final taxable1 = gst.taxable70;
    final cgst1 = gst.gst5 / 2.0;
    final sgst1 = gst.gst5 / 2.0;
    final total1 = gst.portion70;

    // Item 2 (30% Services/BoS portion @ 18% GST = 9% CGST + 9% SGST)
    final taxable2 = gst.taxable30;
    final cgst2 = gst.gst18 / 2.0;
    final sgst2 = gst.gst18 / 2.0;
    final total2 = gst.portion30;

    // Sub Totals
    final totalTaxable = gst.totalTaxableValue;
    final totalCgst = (gst.gst5 + gst.gst18) / 2.0;
    final totalSgst = (gst.gst5 + gst.gst18) / 2.0;
    final grandTotal = gst.grandTotal;

    const tableBorder = pw.TableBorder(
      left: pw.BorderSide(color: borderLight, width: 0.6),
      right: pw.BorderSide(color: borderLight, width: 0.6),
      top: pw.BorderSide(color: borderLight, width: 0.6),
      bottom: pw.BorderSide(color: borderLight, width: 0.6),
      horizontalInside: pw.BorderSide(color: borderLight, width: 0.5),
      verticalInside: pw.BorderSide(color: borderLight, width: 0.5),
    );

    return pw.Table(
      border: tableBorder,
      columnWidths: const {
        0: pw.FixedColumnWidth(18), // #
        1: pw.FlexColumnWidth(3.0), // Description
        2: pw.FixedColumnWidth(28), // Qty
        3: pw.FixedColumnWidth(48), // Rate
        4: pw.FixedColumnWidth(48), // Amount
        5: pw.FixedColumnWidth(52), // Taxable Amount
        6: pw.FixedColumnWidth(24), // CGST %
        7: pw.FixedColumnWidth(40), // CGST Amt
        8: pw.FixedColumnWidth(24), // SGST %
        9: pw.FixedColumnWidth(40), // SGST Amt
        10: pw.FixedColumnWidth(54), // Total
      },
      children: [
        // ── Header Row 1 ──
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: tableHeaderBg),
          children: [
            _th('#', align: pw.TextAlign.center),
            _th('Description'),
            _th('Qty', align: pw.TextAlign.right),
            _th('Rate', align: pw.TextAlign.right),
            _th('Amount', align: pw.TextAlign.right),
            _th('Taxable\nAmount', align: pw.TextAlign.right),
            _th('CGST\n%', align: pw.TextAlign.center),
            _th('CGST\nAmt', align: pw.TextAlign.right),
            _th('SGST\n%', align: pw.TextAlign.center),
            _th('SGST\nAmt', align: pw.TextAlign.right),
            _th('Total', align: pw.TextAlign.right),
          ],
        ),

        // ── Item 1 Row: Solar Power Generation System (5% GST) ──
        pw.TableRow(
          children: [
            _td('1', align: pw.TextAlign.center),
            _td('solar power\ngeneration system\n$capStr rooftop Grid tie'),
            _td('1.00', align: pw.TextAlign.right),
            _td(_inr.format(taxable1), align: pw.TextAlign.right),
            _td(_inr.format(taxable1), align: pw.TextAlign.right),
            _td(_inr.format(taxable1), align: pw.TextAlign.right),
            _td('2.5%', align: pw.TextAlign.center),
            _td(_inr.format(cgst1), align: pw.TextAlign.right),
            _td('2.5%', align: pw.TextAlign.center),
            _td(_inr.format(sgst1), align: pw.TextAlign.right),
            _td(_inr.format(total1), align: pw.TextAlign.right),
          ],
        ),

        // ── Item 2 Row: Solar Bos INC (18% GST) ──
        pw.TableRow(
          children: [
            _td('2', align: pw.TextAlign.center),
            _td('Solar Bos INC'),
            _td('1.00', align: pw.TextAlign.right),
            _td(_inr.format(taxable2), align: pw.TextAlign.right),
            _td(_inr.format(taxable2), align: pw.TextAlign.right),
            _td(_inr.format(taxable2), align: pw.TextAlign.right),
            _td('9%', align: pw.TextAlign.center),
            _td(_inr.format(cgst2), align: pw.TextAlign.right),
            _td('9%', align: pw.TextAlign.center),
            _td(_inr.format(sgst2), align: pw.TextAlign.right),
            _td(_inr.format(total2), align: pw.TextAlign.right),
          ],
        ),

        // ── Sub Total Row ──
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: tableHeaderBg),
          children: [
            _td(''),
            _td('Sub Total', isBold: true, align: pw.TextAlign.right),
            _td(''),
            _td(''),
            _td(_inr.format(totalTaxable), isBold: true, align: pw.TextAlign.right),
            _td(_inr.format(totalTaxable), isBold: true, align: pw.TextAlign.right),
            _td(''),
            _td(_inr.format(totalCgst), isBold: true, align: pw.TextAlign.right),
            _td(''),
            _td(_inr.format(totalSgst), isBold: true, align: pw.TextAlign.right),
            _td(_inr.format(grandTotal), isBold: true, align: pw.TextAlign.right),
          ],
        ),
      ],
    );
  }

  static pw.Widget _th(String title, {pw.TextAlign align = pw.TextAlign.left}) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 3.5),
      child: pw.Text(
        title,
        style: pw.TextStyle(
          color: darkText,
          fontSize: 7,
          fontWeight: pw.FontWeight.bold,
        ),
        textAlign: align,
      ),
    );
  }

  static pw.Widget _td(String text, {pw.TextAlign align = pw.TextAlign.left, bool isBold = false}) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 3.5),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          color: darkText,
          fontSize: 7,
          fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
        textAlign: align,
      ),
    );
  }

  // ── 5. Lower Section ───────────────────────────────────────────────────────

  static pw.Widget _buildLowerSection(
    Invoice invoice,
    dynamic gst,
    pw.MemoryImage? stampImage,
    bool includeStamp,
  ) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // Left Column: Words, Bank Details, Terms, UPI QR
        pw.Expanded(
          flex: 6,
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Total in words
              pw.Text('Total In Words', style: pw.TextStyle(color: slateMuted, fontSize: 7, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 1),
              pw.Text(
                'Indian Rupee ${invoice.amountInWords} Only',
                style: pw.TextStyle(color: darkText, fontSize: 7.5, fontWeight: pw.FontWeight.bold, fontStyle: pw.FontStyle.italic),
              ),
              pw.SizedBox(height: 8),

              pw.Text('Thanks for your business.', style: pw.TextStyle(color: darkText, fontSize: 7.5)),
              pw.SizedBox(height: 6),

              // Bank Info
              pw.Text('BANK A/C NAME - SIYA INFOTECH ADN DIGITAL SOLUTIONS', style: pw.TextStyle(color: darkText, fontSize: 7, fontWeight: pw.FontWeight.bold)),
              pw.Text('BANK A/C NO - 45489966347', style: pw.TextStyle(color: darkText, fontSize: 7, fontWeight: pw.FontWeight.bold)),
              pw.Text('IFSC CODE - SBIN0004798', style: pw.TextStyle(color: darkText, fontSize: 7, fontWeight: pw.FontWeight.bold)),
              pw.Text('BRANCH - STATE BANK OF INDIA BETAWAD', style: pw.TextStyle(color: darkText, fontSize: 7, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 8),

              // Terms & Conditions
              pw.Text('1. WARRANTY VOID IF GOODS PHYSICALLY DAMAGED/BURN', style: pw.TextStyle(color: slateBody, fontSize: 6)),
              pw.Text('1. GOODS ONCE SOLD WILL NOT BE TAKEN BACK For Siya Infotech And Digital solutions', style: pw.TextStyle(color: slateBody, fontSize: 6)),
              pw.Text('2. OUR RESPOSIBILITY CEASES THE MOMENT GOODS HANDOVER TO TRANSTPORTER', style: pw.TextStyle(color: slateBody, fontSize: 6)),
              pw.Text('3. INTEREST AT 24% P.A. WILL BE CHARGED AFTER DUE DATE', style: pw.TextStyle(color: slateBody, fontSize: 6)),
              pw.Text('4. CHEQUE BOUNCING WILL BE CHARGED 500 RS.', style: pw.TextStyle(color: slateBody, fontSize: 6)),
              pw.Text('5. WARRANTY VOID IF GOODS PHYSICALLY DAMAGED/BURN', style: pw.TextStyle(color: slateBody, fontSize: 6)),
              pw.Text('6. All disputes subject to DHULE Jurisdication only.', style: pw.TextStyle(color: slateBody, fontSize: 6)),
              pw.SizedBox(height: 8),

              // UPI QR Code
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  pw.Container(
                    width: 58,
                    height: 58,
                    padding: const pw.EdgeInsets.all(2),
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: borderLight, width: 0.6),
                    ),
                    child: pw.BarcodeWidget(
                      barcode: pw.Barcode.qrCode(),
                      data: 'upi://pay?pa=45489966347@sbi&pn=SIYA%20INFOTECH%20ADN%20DIGITAL%20SOLUTIONS&am=${invoice.grandTotal.toStringAsFixed(2)}&cu=INR',
                    ),
                  ),
                  pw.SizedBox(width: 8),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('Scan to Pay to siya', style: pw.TextStyle(color: darkText, fontSize: 7.5, fontWeight: pw.FontWeight.bold)),
                      pw.Text('infotech', style: pw.TextStyle(color: darkText, fontSize: 7.5, fontWeight: pw.FontWeight.bold)),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),

        pw.SizedBox(width: 14),

        // Right Column: Summary Box (Adjustment, Total, Balance Due)
        pw.Expanded(
          flex: 4,
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              pw.Container(
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: borderLight, width: 0.7),
                ),
                child: pw.Column(
                  children: [
                    _summaryLine('Adjustment', '(-) 0.00'),
                    pw.Divider(height: 1, thickness: 0.5, color: borderLight),
                    _summaryLine('Total', _inr.format(invoice.grandTotal), isBold: true, isLarge: true),
                    pw.Divider(height: 1, thickness: 0.5, color: borderLight),
                    _summaryLine('Balance Due', _inr.format(invoice.totalPending), isBold: true, isLarge: true),
                  ],
                ),
              ),

              if (includeStamp && stampImage != null) ...[
                pw.SizedBox(height: 12),
                pw.Align(
                  alignment: pw.Alignment.centerRight,
                  child: pw.Container(
                    width: 110,
                    height: 55,
                    child: pw.Image(stampImage),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  static pw.Widget _summaryLine(String label, String value, {bool isBold = false, bool isLarge = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4.5),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(
              color: darkText,
              fontSize: isLarge ? 8.5 : 7.5,
              fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
            ),
          ),
          pw.Text(
            value,
            style: pw.TextStyle(
              color: darkText,
              fontSize: isLarge ? 9.5 : 7.5,
              fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  // ── 6. Footer ──────────────────────────────────────────────────────────────

  static pw.Widget _buildFooter() {
    return pw.Column(
      children: [
        pw.Divider(color: borderLight, thickness: 0.5, height: 4),
        pw.SizedBox(height: 3),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'This is a computer-generated Invoice and no signature is required',
              style: pw.TextStyle(color: slateMuted, fontSize: 6.5),
            ),
            pw.Text(
              '1',
              style: pw.TextStyle(color: slateMuted, fontSize: 6.5),
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
      'Your GST Invoice ${invoice.invoiceNumber} '
      '(Ref: ${invoice.refInvoiceNo}) has been generated.\n\n'
      'Total Amount: ₹${_inr.format(invoice.grandTotal)}\n'
      'Balance Due: ₹${_inr.format(invoice.totalPending)}\n\n'
      'SIYA INFOTECH & DIGITAL SOLUTIONS\n'
      'Contact: 7588003220',
    );
    final url = Uri.parse('https://wa.me/$fullPhone?text=$message');
    try {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }
}
