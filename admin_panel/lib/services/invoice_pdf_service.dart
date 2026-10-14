import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/invoice.dart';
import 'company_stamp_helper.dart';

/// Professional A4 GST Tax Invoice PDF Generator matching the Quotation template design system
class InvoicePdfService {
  // Theme Colors aligned with BankLoanQuotationService
  static const PdfColor navyColor = PdfColor.fromInt(0xFF0D2B6F);
  static const PdfColor emeraldColor = PdfColor.fromInt(0xFF047857);
  static const PdfColor lightGreenColor = PdfColor.fromInt(0xFF10B981);
  static const PdfColor goldenYellowColor = PdfColor.fromInt(0xFFF59E0B);
  static const PdfColor darkTextColor = PdfColor.fromInt(0xFF0F172A);
  static const PdfColor slateBodyColor = PdfColor.fromInt(0xFF1E293B);
  static const PdfColor slateMutedColor = PdfColor.fromInt(0xFF475569);
  static const PdfColor borderDarkColor = PdfColor.fromInt(0xFF334155);
  static const PdfColor headerBgColor = PdfColor.fromInt(0xFFF1F5F9);
  static const PdfColor zebraBgColor = PdfColor.fromInt(0xFFF8FAFC);
  static const PdfColor creamHighlightBg = PdfColor.fromInt(0xFFFEFCE8);

  static final _currencyFormatter = NumberFormat.currency(locale: 'en_IN', symbol: 'Rs. ', decimalDigits: 2);
  static final _inr = NumberFormat('#,##,##0.00', 'en_IN');

  /// Helper to build toner-friendly section headers with crisp border and navy accent tag
  static pw.Widget _buildSectionHeader(String title) {
    return pw.Container(
      decoration: pw.BoxDecoration(
        color: headerBgColor,
        border: pw.Border.all(color: borderDarkColor, width: 0.8),
      ),
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 2.2),
      child: pw.Row(
        children: [
          pw.Container(
            width: 3.5,
            height: 10,
            color: navyColor,
            margin: const pw.EdgeInsets.only(right: 6),
          ),
          pw.Text(
            title,
            style: pw.TextStyle(
              color: darkTextColor,
              fontSize: 7.8,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  /// Generate Single-Page A4 GST Tax Invoice PDF bytes
  static Future<Uint8List> generateInvoicePdfBytes(
    Invoice invoice, {
    bool includeStampAndSignature = false,
    Uint8List? customStampBytes,
  }) async {
    final pdf = pw.Document();

    // 1. Load Company Logo from Assets
    pw.MemoryImage? logoImage;
    try {
      final ByteData logoData = await rootBundle.load('assets/images/logo.png');
      logoImage = pw.MemoryImage(logoData.buffer.asUint8List());
    } catch (e) {
      debugPrint('Logo load error in admin invoice service: $e');
    }

    // 2. Load Company Stamp & Authorized Signature
    pw.MemoryImage? stampImage;
    if (includeStampAndSignature) {
      final stampBytes = await AdminCompanyStampHelper.loadStampAndSignatureBytes(
        customBytes: customStampBytes,
      );
      if (stampBytes != null && stampBytes.isNotEmpty) {
        try {
          stampImage = pw.MemoryImage(stampBytes);
        } catch (e) {
          debugPrint('Stamp image decoding error in admin invoice service: $e');
        }
      }
    }

    final gst = invoice.gstBreakdown;
    final dateStr = DateFormat('dd/MM/yyyy').format(invoice.invoiceDate);

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
                  border: pw.Border.all(color: emeraldColor, width: 0.6),
                ),
                padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 7),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    // ==================================================
                    // 1. HEADER: MASTER LETTERHEAD
                    // ==================================================
                    pw.Row(
                      crossAxisAlignment: pw.CrossAxisAlignment.center,
                      children: [
                        if (logoImage != null)
                          pw.Container(
                            width: 46,
                            height: 46,
                            margin: const pw.EdgeInsets.only(right: 10),
                            child: pw.Image(logoImage, fit: pw.BoxFit.contain),
                          )
                        else
                          pw.Container(
                            width: 46,
                            height: 46,
                            margin: const pw.EdgeInsets.only(right: 10),
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
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ),
                        pw.Expanded(
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Text(
                                'SIYA INFOTECH & DIGITAL SOLUTIONS',
                                style: pw.TextStyle(
                                  color: navyColor,
                                  fontSize: 14.0,
                                  fontWeight: pw.FontWeight.bold,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              pw.SizedBox(height: 1.5),
                              pw.Text(
                                'Solar Solutions & Digital Services',
                                style: pw.TextStyle(
                                  color: emeraldColor,
                                  fontSize: 8.8,
                                  fontWeight: pw.FontWeight.bold,
                                ),
                              ),
                              pw.SizedBox(height: 1.0),
                              pw.Text(
                                'PM Surya Ghar Yojana - Authorized Vendor',
                                style: pw.TextStyle(
                                  color: emeraldColor,
                                  fontSize: 7.5,
                                  fontWeight: pw.FontWeight.bold,
                                ),
                              ),
                              pw.SizedBox(height: 1.0),
                              pw.Text(
                                'Betawad, Taluka Shindkheda, District Dhule, Maharashtra',
                                style: const pw.TextStyle(
                                  color: slateMutedColor,
                                  fontSize: 6.8,
                                ),
                              ),
                            ],
                          ),
                        ),
                        pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.end,
                          children: [
                            pw.Text(
                              'GSTIN: 27CVTPK6358P1ZD',
                              style: pw.TextStyle(
                                color: navyColor,
                                fontSize: 8.0,
                                fontWeight: pw.FontWeight.bold,
                              ),
                            ),
                            pw.SizedBox(height: 1.5),
                            pw.Text(
                              'Phone: 7588003220 / 7972143798',
                              style: pw.TextStyle(
                                color: navyColor,
                                fontSize: 7.8,
                                fontWeight: pw.FontWeight.bold,
                              ),
                            ),
                            pw.SizedBox(height: 1.5),
                            pw.Text(
                              'Email: siyainfodigital@gmail.com',
                              style: const pw.TextStyle(
                                color: slateBodyColor,
                                fontSize: 7.0,
                              ),
                            ),
                            pw.SizedBox(height: 1.5),
                            pw.Text(
                              'Mudavad Road, At Post Betawad,',
                              style: const pw.TextStyle(
                                color: slateMutedColor,
                                fontSize: 6.8,
                              ),
                            ),
                            pw.Text(
                              'Dist. Dhule, Maharashtra - 425403',
                              style: const pw.TextStyle(
                                color: slateMutedColor,
                                fontSize: 6.8,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),

                    pw.SizedBox(height: 4),

                    // Triple-Tone Separator (Navy + Emerald + Golden Yellow)
                    pw.Row(
                      children: [
                        pw.Expanded(
                          flex: 6,
                          child: pw.Container(height: 2.0, color: navyColor),
                        ),
                        pw.Expanded(
                          flex: 3,
                          child: pw.Container(height: 2.0, color: emeraldColor),
                        ),
                        pw.Expanded(
                          flex: 1,
                          child: pw.Container(height: 2.0, color: goldenYellowColor),
                        ),
                      ],
                    ),

                    pw.SizedBox(height: 4),

                    // ==================================================
                    // 2. INVOICE TITLE BANNER
                    // ==================================================
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: pw.BoxDecoration(
                        color: PdfColors.white,
                        border: pw.Border.all(color: borderDarkColor, width: 1.0),
                      ),
                      child: pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Text(
                                'TAX INVOICE (GST) / BILL OF SUPPLY',
                                style: pw.TextStyle(
                                  color: darkTextColor,
                                  fontSize: 11.5,
                                  fontWeight: pw.FontWeight.bold,
                                  letterSpacing: 0.3,
                                ),
                              ),
                              pw.SizedBox(height: 1.5),
                              pw.Text(
                                'Subject: solar power gen system ${invoice.systemCapacity} under pm suryghar yojan',
                                style: pw.TextStyle(
                                  color: slateBodyColor,
                                  fontSize: 7.5,
                                  fontWeight: pw.FontWeight.bold,
                                ),
                              ),
                              pw.Text(
                                'Place of Supply: Maharashtra (State Code: 27)',
                                style: pw.TextStyle(
                                  color: emeraldColor,
                                  fontSize: 7.2,
                                  fontWeight: pw.FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.end,
                            children: [
                              pw.Row(
                                children: [
                                  pw.Text('Invoice No.: ', style: pw.TextStyle(fontSize: 7.8, fontWeight: pw.FontWeight.bold, color: slateMutedColor)),
                                  pw.Text(
                                    invoice.invoiceNumber.isNotEmpty ? invoice.invoiceNumber : 'SID000321',
                                    style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: navyColor),
                                  ),
                                ],
                              ),
                              pw.SizedBox(height: 1.5),
                              pw.Text(
                                'Invoice Date: $dateStr',
                                style: pw.TextStyle(color: darkTextColor, fontSize: 7.5, fontWeight: pw.FontWeight.bold),
                              ),
                              pw.Text(
                                'Due Date: $dateStr (Due on Receipt)',
                                style: const pw.TextStyle(color: slateMutedColor, fontSize: 7.2),
                              ),
                              if (invoice.refInvoiceNo.isNotEmpty) ...[
                                pw.SizedBox(height: 1.0),
                                pw.Text(
                                  'Ref Quotation: ${invoice.refInvoiceNo}',
                                  style: pw.TextStyle(color: emeraldColor, fontSize: 7.2, fontWeight: pw.FontWeight.bold),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),

                    pw.SizedBox(height: 4),

                    // ==================================================
                    // 3. CUSTOMER DETAILS (Strictly as per Customer Profile)
                    // ==================================================
                    _buildSectionHeader('CUSTOMER DETAILS & PLACE OF SUPPLY'),
                    pw.Container(
                      decoration: pw.BoxDecoration(
                        border: pw.Border.all(color: borderDarkColor, width: 0.8),
                      ),
                      child: pw.Column(
                        children: [
                          _buildTableRow('Customer Name', invoice.customerName, 'Consumer No.', invoice.consumerNo.isNotEmpty ? invoice.consumerNo : 'N/A', isZebra: false, isLeftBold: true),
                          _buildTableRow('Address', invoice.address.isNotEmpty ? invoice.address : 'Betawad', 'Village / City', invoice.villageCity.isNotEmpty ? invoice.villageCity : 'Betawad', isZebra: true),
                          _buildTableRow('District', invoice.district.isNotEmpty ? invoice.district : 'Dhule', 'Mobile No.', invoice.mobileNo.isNotEmpty ? invoice.mobileNo : 'N/A', isZebra: false),
                        ],
                      ),
                    ),

                    pw.SizedBox(height: 4),

                    // ==================================================
                    // 4. STATUTORY 2-LINE ITEMS TABLE
                    // ==================================================
                    _buildSectionHeader('STATUTORY GST PARTICULARS (70% GOODS @ 5% GST + 30% SERVICES @ 18% GST)'),
                    _buildItemTable(invoice, gst),

                    pw.SizedBox(height: 4),

                    // ==================================================
                    // 5. AMOUNT IN WORDS
                    // ==================================================
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 3.0),
                      decoration: pw.BoxDecoration(
                        color: PdfColors.white,
                        border: pw.Border.all(color: borderDarkColor, width: 0.8),
                      ),
                      child: pw.Row(
                        children: [
                          pw.Text(
                            'Amount in Words: ',
                            style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: darkTextColor),
                          ),
                          pw.Expanded(
                            child: pw.Text(
                              invoice.amountInWords.isNotEmpty
                                  ? 'Indian Rupee ${invoice.amountInWords} Only'
                                  : 'Indian Rupee ________________________________________ Only',
                              style: pw.TextStyle(
                                fontSize: 7.5,
                                fontWeight: pw.FontWeight.bold,
                                color: darkTextColor,
                                fontStyle: pw.FontStyle.italic,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    pw.SizedBox(height: 4),

                    // ==================================================
                    // 6. LOWER SECTION: BANK/QR/TERMS + SUMMARY/STAMP
                    // ==================================================
                    pw.Row(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        // Left: Bank details, QR & Terms
                        pw.Expanded(
                          flex: 11,
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              _buildSectionHeader('BANK ACCOUNT DETAILS & SCAN TO PAY'),
                              pw.Container(
                                decoration: pw.BoxDecoration(
                                  border: pw.Border.all(color: borderDarkColor, width: 0.8),
                                ),
                                child: pw.Column(
                                  children: [
                                    _buildBankRow('Account Name', 'SIYA INFOTECH ADN DIGITAL SOLUTIONS', isBold: true),
                                    _buildBankRow('Bank Name', 'State Bank of India', isZebra: true),
                                    _buildBankRow('Branch', 'STATE BANK OF INDIA BETAWAD'),
                                    _buildBankRow('Account No.', '45489966347', isZebra: true, isBold: true),
                                    _buildBankRow('IFSC Code', 'SBIN0004798', isBold: true),
                                  ],
                                ),
                              ),
                              pw.SizedBox(height: 3),
                              // QR Code + UPI Bar
                              pw.Container(
                                padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                decoration: pw.BoxDecoration(
                                  color: zebraBgColor,
                                  border: pw.Border.all(color: borderDarkColor, width: 0.8),
                                ),
                                child: pw.Row(
                                  children: [
                                    pw.Container(
                                      width: 44,
                                      height: 44,
                                      padding: const pw.EdgeInsets.all(1.5),
                                      decoration: pw.BoxDecoration(
                                        color: PdfColors.white,
                                        border: pw.Border.all(color: borderDarkColor, width: 0.6),
                                      ),
                                      child: pw.BarcodeWidget(
                                        barcode: pw.Barcode.qrCode(),
                                        data: 'upi://pay?pa=45489966347@sbi&pn=SIYA%20INFOTECH%20ADN%20DIGITAL%20SOLUTIONS&am=${invoice.grandTotal.toStringAsFixed(2)}&cu=INR',
                                      ),
                                    ),
                                    pw.SizedBox(width: 8),
                                    pw.Expanded(
                                      child: pw.Column(
                                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                                        children: [
                                          pw.Text(
                                            'Scan to Pay via UPI / Any Bank App',
                                            style: pw.TextStyle(color: navyColor, fontSize: 7.2, fontWeight: pw.FontWeight.bold),
                                          ),
                                          pw.Text(
                                            'Beneficiary: SIYA INFOTECH ADN DIGITAL SOLUTIONS',
                                            style: const pw.TextStyle(color: slateBodyColor, fontSize: 6.5),
                                          ),
                                          pw.Text(
                                            'UPI ID: 45489966347@sbi',
                                            style: pw.TextStyle(color: darkTextColor, fontSize: 6.8, fontWeight: pw.FontWeight.bold),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              pw.SizedBox(height: 3),
                              _buildSectionHeader('TERMS & CONDITIONS'),
                              pw.Container(
                                padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                decoration: pw.BoxDecoration(
                                  color: PdfColors.white,
                                  border: pw.Border.all(color: borderDarkColor, width: 0.8),
                                ),
                                child: pw.Column(
                                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                                  children: [
                                    _buildTermItem('1. Goods once sold will not be taken back.'),
                                    _buildTermItem('2. Warranty void if goods physically damaged or burnt.'),
                                    _buildTermItem('3. Our responsibility ceases once goods are handed over to the transporter.'),
                                    _buildTermItem('4. Interest at 24% P.A. will be charged after due date.'),
                                    _buildTermItem('5. Cheque bouncing will incur charges of Rs. 500/-.'),
                                    _buildTermItem('6. All disputes are subject to Dhule Jurisdiction only.'),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),

                        pw.SizedBox(width: 8),

                        // Right: Payment & Balance Summary + Vendor Stamp & Sign
                        pw.Expanded(
                          flex: 9,
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              _buildSectionHeader('PAYMENT & BALANCE SUMMARY'),
                              pw.Container(
                                decoration: pw.BoxDecoration(
                                  border: pw.Border.all(color: borderDarkColor, width: 0.8),
                                ),
                                child: pw.Column(
                                  children: [
                                    _buildSummaryRow('Total Taxable Value', _currencyFormatter.format(gst.totalTaxableValue), isBold: true),
                                    _buildSummaryRow('CGST Amount', _currencyFormatter.format((gst.gst5 + gst.gst18) / 2.0), isZebra: true),
                                    _buildSummaryRow('SGST Amount', _currencyFormatter.format((gst.gst5 + gst.gst18) / 2.0)),
                                    _buildSummaryRow('Total GST Included', _currencyFormatter.format(gst.totalGstIncluded), isZebra: true, isBold: true),
                                    // Highlighted Grand Total Box
                                    pw.Container(
                                      decoration: pw.BoxDecoration(
                                        color: creamHighlightBg,
                                        border: pw.Border.all(color: darkTextColor, width: 1.0),
                                      ),
                                      child: pw.Row(
                                        children: [
                                          pw.Container(width: 3.5, height: 16, color: goldenYellowColor),
                                          pw.Expanded(
                                            child: pw.Padding(
                                              padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                                              child: pw.Row(
                                                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                                                children: [
                                                  pw.Text('Total Amount (Incl. GST)', style: pw.TextStyle(fontSize: 7.8, fontWeight: pw.FontWeight.bold, color: darkTextColor)),
                                                  pw.Text(_currencyFormatter.format(invoice.grandTotal), style: pw.TextStyle(fontSize: 8.8, fontWeight: pw.FontWeight.bold, color: darkTextColor)),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    _buildSummaryRow('Amount Received / Paid', _currencyFormatter.format(invoice.totalPaid)),
                                    _buildSummaryRow('Balance Due', _currencyFormatter.format(invoice.totalPending), isZebra: true, isBold: true, isRed: invoice.totalPending > 0),
                                  ],
                                ),
                              ),

                              pw.SizedBox(height: 6),

                              // Vendor Stamp & Signature Box
                              pw.Container(
                                width: double.infinity,
                                padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                decoration: pw.BoxDecoration(
                                  color: PdfColors.white,
                                  border: pw.Border.all(color: borderDarkColor, width: 0.8),
                                ),
                                child: pw.Column(
                                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                                  children: [
                                    pw.Text(
                                      'For SIYA INFOTECH & DIGITAL SOLUTIONS',
                                      style: pw.TextStyle(
                                        color: darkTextColor,
                                        fontSize: 7.8,
                                        fontWeight: pw.FontWeight.bold,
                                      ),
                                    ),
                                    pw.SizedBox(height: 2),
                                    AdminCompanyStampHelper.buildStampAndSignatureWidget(
                                      image: stampImage,
                                      include: includeStampAndSignature,
                                      height: 60,
                                      width: 140,
                                    ),
                                    pw.Container(width: 130, height: 0.8, color: darkTextColor),
                                    pw.SizedBox(height: 2),
                                    pw.Text(
                                      'Authorized Signatory',
                                      style: pw.TextStyle(color: darkTextColor, fontSize: 7.5, fontWeight: pw.FontWeight.bold),
                                    ),
                                    pw.Text(
                                      '(Vendor Stamp & Signature)',
                                      style: const pw.TextStyle(
                                        color: slateMutedColor,
                                        fontSize: 6.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    pw.Spacer(),

                    // ==================================================
                    // 7. FOOTER
                    // ==================================================
                    pw.Column(
                      children: [
                        pw.Container(height: 0.8, color: borderDarkColor),
                        pw.SizedBox(height: 2.5),
                        pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Text(
                              'This is a computer-generated Tax Invoice / Bill of Supply and is valid under GST Act.',
                              style: const pw.TextStyle(color: slateMutedColor, fontSize: 6.5),
                            ),
                            pw.Text(
                              'Page 1 of 1',
                              style: const pw.TextStyle(color: slateMutedColor, fontSize: 6.5),
                            ),
                          ],
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

  // ── 2-Line Items Table ──────────────────────────────────────────────────────
  static pw.Widget _buildItemTable(Invoice invoice, dynamic gst) {
    final capStr = invoice.systemCapacity.isNotEmpty ? invoice.systemCapacity : '3 kW';

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
      left: pw.BorderSide(color: borderDarkColor, width: 0.8),
      right: pw.BorderSide(color: borderDarkColor, width: 0.8),
      top: pw.BorderSide(color: borderDarkColor, width: 0.8),
      bottom: pw.BorderSide(color: borderDarkColor, width: 0.8),
      horizontalInside: pw.BorderSide(color: borderDarkColor, width: 0.6),
      verticalInside: pw.BorderSide(color: borderDarkColor, width: 0.6),
    );

    return pw.Table(
      border: tableBorder,
      columnWidths: const {
        0: pw.FixedColumnWidth(16), // #
        1: pw.FlexColumnWidth(3.2), // Description
        2: pw.FixedColumnWidth(24), // Qty
        3: pw.FixedColumnWidth(44), // Rate
        4: pw.FixedColumnWidth(46), // Amount
        5: pw.FixedColumnWidth(48), // Taxable Amount
        6: pw.FixedColumnWidth(22), // CGST %
        7: pw.FixedColumnWidth(38), // CGST Amt
        8: pw.FixedColumnWidth(22), // SGST %
        9: pw.FixedColumnWidth(38), // SGST Amt
        10: pw.FixedColumnWidth(50), // Total
      },
      children: [
        // Header Row
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: headerBgColor),
          children: [
            _th('#', align: pw.TextAlign.center),
            _th('Description of Goods / Services'),
            _th('Qty', align: pw.TextAlign.center),
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

        // Line Item 1: 70% Goods portion @ 5% GST
        pw.TableRow(
          children: [
            _td('1', align: pw.TextAlign.center),
            _td('solar power generation system\n$capStr rooftop Grid tie\n(70% Goods Portion @ 5% GST)', isBoldTitle: true),
            _td('1.00', align: pw.TextAlign.center),
            _td(_inr.format(taxable1), align: pw.TextAlign.right),
            _td(_inr.format(taxable1), align: pw.TextAlign.right),
            _td(_inr.format(taxable1), align: pw.TextAlign.right),
            _td('2.5%', align: pw.TextAlign.center),
            _td(_inr.format(cgst1), align: pw.TextAlign.right),
            _td('2.5%', align: pw.TextAlign.center),
            _td(_inr.format(sgst1), align: pw.TextAlign.right),
            _td(_inr.format(total1), align: pw.TextAlign.right, isBold: true),
          ],
        ),

        // Line Item 2: 30% Services/BoS portion @ 18% GST
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: zebraBgColor),
          children: [
            _td('2', align: pw.TextAlign.center),
            _td('Solar Bos INC\n(30% Services / BoS Portion @ 18% GST)', isBoldTitle: true),
            _td('1.00', align: pw.TextAlign.center),
            _td(_inr.format(taxable2), align: pw.TextAlign.right),
            _td(_inr.format(taxable2), align: pw.TextAlign.right),
            _td(_inr.format(taxable2), align: pw.TextAlign.right),
            _td('9%', align: pw.TextAlign.center),
            _td(_inr.format(cgst2), align: pw.TextAlign.right),
            _td('9%', align: pw.TextAlign.center),
            _td(_inr.format(sgst2), align: pw.TextAlign.right),
            _td(_inr.format(total2), align: pw.TextAlign.right, isBold: true),
          ],
        ),

        // Sub Total / Summary Row
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: headerBgColor),
          children: [
            _td(''),
            _td('Sub Total (GST Included)', isBold: true, align: pw.TextAlign.right),
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
      padding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 3.0),
      child: pw.Text(
        title,
        style: pw.TextStyle(
          color: darkTextColor,
          fontSize: 6.8,
          fontWeight: pw.FontWeight.bold,
        ),
        textAlign: align,
      ),
    );
  }

  static pw.Widget _td(
    String text, {
    pw.TextAlign align = pw.TextAlign.left,
    bool isBold = false,
    bool isBoldTitle = false,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 2.5),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          color: isBoldTitle ? darkTextColor : slateBodyColor,
          fontSize: 6.8,
          fontWeight: (isBold || isBoldTitle) ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
        textAlign: align,
      ),
    );
  }

  // ── Helper Table Rows ───────────────────────────────────────────────────────
  static pw.Widget _buildTableRow(
    String leftLabel,
    String leftVal,
    String rightLabel,
    String rightVal, {
    bool isZebra = false,
    bool isLeftBold = false,
  }) {
    return pw.Container(
      color: isZebra ? zebraBgColor : PdfColors.white,
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 2.0),
      child: pw.Row(
        children: [
          pw.SizedBox(
            width: 78,
            child: pw.Text(
              leftLabel,
              style: const pw.TextStyle(fontSize: 7.2, color: slateMutedColor),
            ),
          ),
          pw.Text(': ', style: const pw.TextStyle(fontSize: 7.2, color: slateMutedColor)),
          pw.Expanded(
            flex: 4,
            child: pw.Text(
              leftVal.isNotEmpty ? leftVal : '-',
              style: pw.TextStyle(
                fontSize: 7.5,
                fontWeight: isLeftBold ? pw.FontWeight.bold : pw.FontWeight.normal,
                color: darkTextColor,
              ),
            ),
          ),
          pw.SizedBox(
            width: 75,
            child: pw.Text(
              rightLabel,
              style: const pw.TextStyle(fontSize: 7.2, color: slateMutedColor),
            ),
          ),
          pw.Text(': ', style: const pw.TextStyle(fontSize: 7.2, color: slateMutedColor)),
          pw.Expanded(
            flex: 3,
            child: pw.Text(
              rightVal.isNotEmpty ? rightVal : '-',
              style: pw.TextStyle(
                fontSize: 7.5,
                fontWeight: pw.FontWeight.bold,
                color: darkTextColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildBankRow(String label, String value, {bool isZebra = false, bool isBold = false}) {
    return pw.Container(
      color: isZebra ? zebraBgColor : PdfColors.white,
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 1.8),
      child: pw.Row(
        children: [
          pw.SizedBox(
            width: 78,
            child: pw.Text(label, style: const pw.TextStyle(fontSize: 6.8, color: slateMutedColor)),
          ),
          pw.Text(': ', style: const pw.TextStyle(fontSize: 6.8, color: slateMutedColor)),
          pw.Expanded(
            child: pw.Text(
              value,
              style: pw.TextStyle(
                fontSize: 7.0,
                fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
                color: darkTextColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildSummaryRow(String label, String value, {bool isZebra = false, bool isBold = false, bool isRed = false}) {
    return pw.Container(
      color: isZebra ? zebraBgColor : PdfColors.white,
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 2.0),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(
              fontSize: 7.2,
              fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
              color: isBold ? darkTextColor : slateBodyColor,
            ),
          ),
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: 7.5,
              fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
              color: isRed ? const PdfColor.fromInt(0xFFDC2626) : (isBold ? darkTextColor : slateBodyColor),
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildTermItem(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 0.6),
      child: pw.Text(
        text,
        style: const pw.TextStyle(fontSize: 6.0, color: slateBodyColor),
      ),
    );
  }

  // ── Print ───────────────────────────────────────────────────────────────────
  static Future<void> printInvoice(Invoice invoice) async {
    final bytes = await generateInvoicePdfBytes(
      invoice,
      includeStampAndSignature: invoice.includeStampAndSignature,
    );
    await Printing.layoutPdf(onLayout: (_) => bytes);
  }

  // ── Download / Share ────────────────────────────────────────────────────────
  static Future<void> shareInvoice(Invoice invoice) async {
    final bytes = await generateInvoicePdfBytes(
      invoice,
      includeStampAndSignature: invoice.includeStampAndSignature,
    );
    await Printing.sharePdf(
      bytes: bytes,
      filename: invoice.pdfFileName ?? 'Invoice_${invoice.invoiceNumber}.pdf',
    );
  }

  /// Share on WhatsApp
  static Future<void> shareOnWhatsApp(Invoice invoice) async {
    final phone = invoice.mobileNo.replaceAll(RegExp(r'[^0-9]'), '');
    final fullPhone = phone.startsWith('91') ? phone : '91$phone';
    final message = Uri.encodeComponent(
      'Dear ${invoice.customerName},\n\n'
      'Your GST Tax Invoice ${invoice.invoiceNumber} '
      '(Ref: ${invoice.refInvoiceNo}) has been generated.\n\n'
      'Total Amount: ${_currencyFormatter.format(invoice.grandTotal)}\n'
      'Balance Due: ${_currencyFormatter.format(invoice.totalPending)}\n\n'
      'SIYA INFOTECH & DIGITAL SOLUTIONS\n'
      'Contact: 7588003220',
    );
    final url = Uri.parse('https://wa.me/$fullPhone?text=$message');
    try {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }
}

