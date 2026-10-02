import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/customer_margin_receipt.dart';
import 'company_stamp_helper.dart';
import 'customer_signature_helper.dart';

class MarginMoneyReceiptService {
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
              fontSize: 8.2,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  /// Generate Single-Page A4 PDF bytes for Customer Margin Money Receipt
  static Future<Uint8List> generateReceiptPdfBytes(
    CustomerMarginReceipt receipt, {
    bool includeStampAndSignature = true,
    Uint8List? customStampAndSignatureBytes,
    bool includeCustomerSignature = true,
    Uint8List? customCustomerSignatureBytes,
  }) async {
    final pdf = pw.Document();

    pw.Font? customerSignatureFont;
    if (includeCustomerSignature) {
      try {
        customerSignatureFont = await CustomerSignatureHelper.loadSignatureFont();
      } catch (_) {}
    }

    pw.MemoryImage? logoImage;
    try {
      final ByteData logoData = await rootBundle.load('assets/images/logo.png');
      logoImage = pw.MemoryImage(logoData.buffer.asUint8List());
    } catch (e) {
      debugPrint('Logo load error in admin margin receipt service: $e');
    }

    // Load Company Stamp & Authorized Signature (DEFAULT: automatically included)
    pw.MemoryImage? stampAndSigImage;
    if (includeStampAndSignature) {
      final stampBytes = await AdminCompanyStampHelper.loadStampAndSignatureBytes(
        customBytes: customStampAndSignatureBytes,
      );
      if (stampBytes != null && stampBytes.isNotEmpty) {
        try {
          stampAndSigImage = pw.MemoryImage(stampBytes);
        } catch (e) {
          debugPrint('Stamp image decoding error in admin margin receipt service: $e');
        }
      }
    }

    final currencyFormatter = NumberFormat.currency(locale: 'en_IN', symbol: 'Rs. ', decimalDigits: 2);
    final dateFormatter = DateFormat('dd/MM/yyyy');

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
                padding: const pw.EdgeInsets.symmetric(horizontal: 9, vertical: 8),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    // ==================================================
                    // 1. MASTER LETTERHEAD (Identical to WCR & Quotation)
                    // ==================================================
                    pw.Row(
                      crossAxisAlignment: pw.CrossAxisAlignment.center,
                      children: [
                        if (logoImage != null)
                          pw.Container(
                            width: 48,
                            height: 48,
                            margin: const pw.EdgeInsets.only(right: 12),
                            child: pw.Image(logoImage, fit: pw.BoxFit.contain),
                          )
                        else
                          pw.Container(
                            width: 48,
                            height: 48,
                            margin: const pw.EdgeInsets.only(right: 12),
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
                                'SIYA INFOTECH AND DIGITAL SOLUTIONS',
                                style: pw.TextStyle(
                                  color: navyColor,
                                  fontSize: 13.5,
                                  fontWeight: pw.FontWeight.bold,
                                  letterSpacing: 0.3,
                                ),
                              ),
                              pw.SizedBox(height: 1.5),
                              pw.Text(
                                'Solar EPC, Rooftop Power Plant Installation & Digital Engineering Services',
                                style: const pw.TextStyle(
                                  color: emeraldColor,
                                  fontSize: 7.8,
                                ),
                              ),
                              pw.SizedBox(height: 1.5),
                              pw.Text(
                                'At Post Betawad, Tal. Sindkheda, Dist. Dhule - 425403 (Maharashtra)',
                                style: const pw.TextStyle(
                                  color: slateBodyColor,
                                  fontSize: 7.2,
                                ),
                              ),
                              pw.SizedBox(height: 1.5),
                              pw.Text(
                                'Helpline: +91 7972143798  |  Email: siyainfodigital@gmail.com',
                                style: const pw.TextStyle(
                                  color: slateMutedColor,
                                  fontSize: 6.8,
                                ),
                              ),
                            ],
                          ),
                        ),
                        pw.Container(
                          padding: const pw.EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                          decoration: pw.BoxDecoration(
                            color: headerBgColor,
                            borderRadius: pw.BorderRadius.circular(4),
                            border: pw.Border.all(color: borderDarkColor, width: 0.8),
                          ),
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.end,
                            children: [
                              pw.Text('OFFICIAL RECEIPT', style: pw.TextStyle(fontSize: 7.2, fontWeight: pw.FontWeight.bold, color: navyColor)),
                              pw.SizedBox(height: 1),
                              pw.Text('PM Surya Ghar Finance', style: const pw.TextStyle(fontSize: 6.5, color: emeraldColor)),
                              pw.SizedBox(height: 1),
                              pw.Text('10% Margin Money', style: pw.TextStyle(fontSize: 6.5, fontWeight: pw.FontWeight.bold, color: goldenYellowColor)),
                            ],
                          ),
                        ),
                      ],
                    ),

                    pw.SizedBox(height: 6),

                    // ==================================================
                    // 2. DOCUMENT TITLE BANNER
                    // ==================================================
                    pw.Container(
                      width: double.infinity,
                      decoration: pw.BoxDecoration(
                        color: navyColor,
                        borderRadius: pw.BorderRadius.all(pw.Radius.circular(3)),
                      ),
                      padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                      child: pw.Column(
                        children: [
                          pw.Text(
                            'CUSTOMER MARGIN MONEY / ADVANCE PAYMENT RECEIPT',
                            textAlign: pw.TextAlign.center,
                            style: pw.TextStyle(
                              color: PdfColors.white,
                              fontSize: 10.5,
                              fontWeight: pw.FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                          pw.SizedBox(height: 1),
                          pw.Text(
                            'For Bank Solar Loan / Finance Purpose - PM Surya Ghar Muft Bijli Yojana',
                            textAlign: pw.TextAlign.center,
                            style: pw.TextStyle(
                              color: lightGreenColor,
                              fontSize: 7.2,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),

                    pw.SizedBox(height: 6),

                    // ==================================================
                    // 3. REFERENCE DETAILS & CUSTOMER DETAILS
                    // ==================================================
                    pw.Container(
                      decoration: pw.BoxDecoration(
                        color: zebraBgColor,
                        border: pw.Border.all(color: borderDarkColor, width: 0.8),
                      ),
                      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4.5),
                      child: pw.Row(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          // Left col: Receipt Meta
                          pw.Expanded(
                            flex: 5,
                            child: pw.Column(
                              crossAxisAlignment: pw.CrossAxisAlignment.start,
                              children: [
                                _buildInlineField('Receipt No.', receipt.receiptNo, isBold: true),
                                pw.SizedBox(height: 2),
                                _buildInlineField('Receipt Date', dateFormatter.format(receipt.receiptDate)),
                                pw.SizedBox(height: 2),
                                _buildInlineField('Linked Quotation', receipt.quotationNo),
                                pw.SizedBox(height: 2),
                                _buildInlineField('Quotation Date', dateFormatter.format(receipt.quotationDate)),
                              ],
                            ),
                          ),
                          pw.Container(width: 0.8, height: 42, color: borderDarkColor, margin: const pw.EdgeInsets.symmetric(horizontal: 8)),
                          // Right col: Customer Info
                          pw.Expanded(
                            flex: 6,
                            child: pw.Column(
                              crossAxisAlignment: pw.CrossAxisAlignment.start,
                              children: [
                                _buildInlineField('Customer Name', receipt.customerName, isBold: true),
                                pw.SizedBox(height: 2),
                                _buildInlineField('Consumer No.', receipt.consumerNo, isBold: true),
                                pw.SizedBox(height: 2),
                                _buildInlineField('Site Address', '${receipt.address}, ${receipt.villageCity}, ${receipt.district}'),
                                pw.SizedBox(height: 2),
                                _buildInlineField('Contact Mobile', receipt.mobileNo.isNotEmpty ? receipt.mobileNo : 'N/A'),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    pw.SizedBox(height: 6),

                    // ==================================================
                    // 4. FINANCIAL BREAKDOWN & MARGIN MONEY RECEIVED TABLE
                    // ==================================================
                    _buildSectionHeader('FINANCIAL BREAKDOWN & CUSTOMER CONTRIBUTION'),
                    pw.Container(
                      decoration: pw.BoxDecoration(
                        border: pw.Border.all(color: borderDarkColor, width: 0.8),
                      ),
                      child: pw.Column(
                        children: [
                          // Table Header
                          pw.Container(
                            color: headerBgColor,
                            padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            child: pw.Row(
                              children: [
                                pw.SizedBox(width: 30, child: pw.Text('Sr.', style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: darkTextColor))),
                                pw.Expanded(flex: 6, child: pw.Text('Particulars / Financial Description', style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: darkTextColor))),
                                pw.Expanded(flex: 3, child: pw.Text('Percentage (%)', textAlign: pw.TextAlign.center, style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: darkTextColor))),
                                pw.SizedBox(width: 100, child: pw.Text('Amount (Rs.)', textAlign: pw.TextAlign.right, style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: darkTextColor))),
                              ],
                            ),
                          ),
                          // Row 1: System Capacity & Total Cost
                          _buildTableRow('1', 'Total Solar Project / System Cost (${receipt.systemCapacity} ${receipt.systemType})', '100 %', receipt.totalSystemCost > 0 ? currencyFormatter.format(receipt.totalSystemCost) : 'Rs. ____________'),
                          // Row 2: Bank Loan
                          _buildTableRow('2', 'Proposed / Sanctioned Bank Loan (To be disbursed by Bank)', '90 %', receipt.bankLoanAmount > 0 ? currencyFormatter.format(receipt.bankLoanAmount) : 'Rs. ____________', isZebra: true),
                          // Row 3: HIGHLIGHTED MARGIN MONEY RECEIVED (10%)
                          pw.Container(
                            decoration: pw.BoxDecoration(
                              color: PdfColor.fromInt(0xFFFEFCE8), // Cream yellow
                              border: pw.Border(
                                top: pw.BorderSide(color: darkTextColor, width: 1.2),
                                bottom: pw.BorderSide(color: darkTextColor, width: 1.2),
                              ),
                            ),
                            padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                            child: pw.Row(
                              children: [
                                pw.SizedBox(width: 30, child: pw.Text('3', style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: darkTextColor))),
                                pw.Expanded(
                                  flex: 6,
                                  child: pw.Text(
                                    'CUSTOMER MARGIN MONEY / ADVANCE DEPOSIT RECEIVED',
                                    style: pw.TextStyle(fontSize: 8.2, fontWeight: pw.FontWeight.bold, color: const PdfColor.fromInt(0xFF854D0E)),
                                  ),
                                ),
                                pw.Expanded(
                                  flex: 3,
                                  child: pw.Text('10 %', textAlign: pw.TextAlign.center, style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: const PdfColor.fromInt(0xFF854D0E))),
                                ),
                                pw.SizedBox(
                                  width: 100,
                                  child: pw.Text(
                                    receipt.marginAmount > 0 ? currencyFormatter.format(receipt.marginAmount) : 'Rs. ____________',
                                    textAlign: pw.TextAlign.right,
                                    style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold, color: const PdfColor.fromInt(0xFF854D0E)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Amount in Words Pill
                    pw.Container(
                      width: double.infinity,
                      decoration: pw.BoxDecoration(
                        color: zebraBgColor,
                        border: pw.Border(
                          left: pw.BorderSide(color: borderDarkColor, width: 0.8),
                          right: pw.BorderSide(color: borderDarkColor, width: 0.8),
                          bottom: pw.BorderSide(color: borderDarkColor, width: 0.8),
                        ),
                      ),
                      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      child: pw.Row(
                        children: [
                          pw.Text('Margin Amount in Words: ', style: pw.TextStyle(fontSize: 7.2, fontWeight: pw.FontWeight.bold, color: darkTextColor)),
                          pw.Expanded(
                            child: pw.Text(
                              receipt.marginAmount > 0 && receipt.marginAmountInWords.trim().isNotEmpty
                                  ? receipt.marginAmountInWords
                                  : '________________________________________________',
                              style: pw.TextStyle(fontSize: 7.2, fontWeight: pw.FontWeight.bold, color: emeraldColor),
                            ),
                          ),
                        ],
                      ),
                    ),

                    pw.SizedBox(height: 10),

                    // ==================================================
                    // 5. PAYMENT SETTLEMENT DETAILS & VENDOR BANK DETAILS
                    // ==================================================
                    pw.Row(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        // Left: Payment Settlement Details
                        pw.Expanded(
                          flex: 5,
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              _buildSectionHeader('PAYMENT SETTLEMENT DETAILS'),
                              pw.Container(
                                padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6.5),
                                decoration: pw.BoxDecoration(
                                  color: PdfColors.white,
                                  border: pw.Border.all(color: borderDarkColor, width: 0.8),
                                ),
                                child: pw.Column(
                                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                                  children: [
                                    _buildInlineField('Payment Mode', receipt.paymentMode, isBold: true),
                                    pw.SizedBox(height: 2),
                                    _buildInlineField('Transaction / Ref No.', receipt.transactionRef.isEmpty ? 'Paid in Cash' : receipt.transactionRef, isBold: true),
                                    pw.SizedBox(height: 2),
                                    _buildInlineField('Payment Date', dateFormatter.format(receipt.paymentDate)),
                                    pw.SizedBox(height: 2),
                                    _buildInlineField(
                                      'Deposit Status',
                                      receipt.paymentMode.toLowerCase().contains('cash') ? 'RECEIVED IN CASH' : 'RECEIVED & REALIZED',
                                      isBold: true,
                                      valueColor: emeraldColor,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        pw.SizedBox(width: 8),
                        // Right: Vendor Bank Account for 90% Loan Disbursement
                        pw.Expanded(
                          flex: 5,
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              _buildSectionHeader('VENDOR BANK (FOR 90% LOAN DISBURSEMENT)'),
                              pw.Container(
                                padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6.5),
                                decoration: pw.BoxDecoration(
                                  color: zebraBgColor,
                                  border: pw.Border.all(color: borderDarkColor, width: 0.8),
                                ),
                                child: pw.Column(
                                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                                  children: [
                                    _buildInlineField('Bank & Branch', '${receipt.bankName}, ${receipt.branch}'),
                                    pw.SizedBox(height: 2),
                                    _buildInlineField('Account Name', 'SIYA INFOTECH AND DIGITAL SOLUTIONS', isBold: true),
                                    pw.SizedBox(height: 2),
                                    _buildInlineField('Account No.', receipt.accountNo, isBold: true),
                                    pw.SizedBox(height: 2),
                                    _buildInlineField('IFSC Code', receipt.ifscCode, isBold: true),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    pw.SizedBox(height: 10),

                    // ==================================================
                    // 6. BANK UNDERTAKING & OFFICIAL DECLARATION
                    // ==================================================
                    _buildSectionHeader('DECLARATION & UNDERTAKING FOR FINANCING BANK'),
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                      decoration: pw.BoxDecoration(
                        color: PdfColors.white,
                        border: pw.Border.all(color: borderDarkColor, width: 0.8),
                      ),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            '1. We hereby acknowledge and confirm that the customer (borrower) has deposited the required 10% margin money of ${currencyFormatter.format(receipt.marginAmount)} with us towards the complete installation of ${receipt.systemCapacity} Grid-Tied Solar Rooftop Power Plant under PM Surya Ghar Muft Bijli Yojana.',
                            style: const pw.TextStyle(fontSize: 7.2, color: slateBodyColor, height: 1.25),
                          ),
                          pw.SizedBox(height: 3),
                          pw.Text(
                            '2. The financing bank is kindly requested to sanction and disburse the remaining 90% loan amount of ${currencyFormatter.format(receipt.bankLoanAmount)} directly into our vendor bank account upon commissioning & installation as per PM Surya Ghar bank finance guidelines.',
                            style: const pw.TextStyle(fontSize: 7.2, color: slateBodyColor, height: 1.25),
                          ),
                          pw.SizedBox(height: 3),
                          pw.Text(
                            '3. All equipment supplied complies with MNRE technical specifications, BIS standards and grid-connectivity norms. This receipt forms an integral part of the bank loan documentation set along with Solar System Quotation.',
                            style: const pw.TextStyle(fontSize: 7.2, color: slateBodyColor, height: 1.25),
                          ),
                          pw.SizedBox(height: 3),
                          pw.Text(
                            '4. We confirm that 5 years comprehensive system maintenance & warranty and 25 years solar module performance warranty shall be provided as per program guidelines.',
                            style: const pw.TextStyle(fontSize: 7.2, color: slateBodyColor, height: 1.25),
                          ),
                        ],
                      ),
                    ),

                    // Spacer pushes the entire signature and stamp block down into the open space at the bottom of the page
                    pw.Spacer(),

                    // ==================================================
                    // 7. DUAL SIGNATURE BLOCK (Borrower + Vendor Stamp)
                    // ==================================================
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        // Left: Customer / Borrower Signature
                        pw.Container(
                          width: 220,
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Text(
                                'Customer / Borrower Confirmation',
                                style: pw.TextStyle(
                                  color: darkTextColor,
                                  fontSize: 8.5,
                                  fontWeight: pw.FontWeight.bold,
                                ),
                              ),
                              pw.SizedBox(height: 3),
                              pw.Text(
                                'I hereby confirm deposit of margin money for solar installation.',
                                style: const pw.TextStyle(
                                  color: slateMutedColor,
                                  fontSize: 6.8,
                                ),
                              ),
                              CustomerSignatureHelper.buildSignatureWidget(
                                customerName: receipt.customerName,
                                consumerNo: receipt.consumerNo,
                                customSignatureBytes: customCustomerSignatureBytes,
                                font: customerSignatureFont,
                                includeSignature: includeCustomerSignature,
                                height: 73,
                                fontSize: 16.5,
                              ),
                              pw.Container(width: 160, height: 1.0, color: darkTextColor),
                              pw.SizedBox(height: 3),
                              pw.Text(
                                'Borrower Signature',
                                style: pw.TextStyle(
                                  color: darkTextColor,
                                  fontSize: 8.0,
                                  fontWeight: pw.FontWeight.bold,
                                ),
                              ),
                              pw.SizedBox(height: 2),
                              pw.Text(
                                receipt.customerName,
                                style: const pw.TextStyle(
                                  color: slateMutedColor,
                                  fontSize: 7.0,
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Right: Vendor Authorization & Official Stamp
                        pw.Container(
                          width: 210,
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.center,
                            children: [
                              pw.Text(
                                'For SIYA INFOTECH AND DIGITAL SOLUTIONS',
                                style: pw.TextStyle(
                                  color: darkTextColor,
                                  fontSize: 8.5,
                                  fontWeight: pw.FontWeight.bold,
                                ),
                              ),
                              // Company Stamp & Authorized Signature (DEFAULT: included, can be removed)
                              AdminCompanyStampHelper.buildStampAndSignatureWidget(
                                image: stampAndSigImage,
                                include: includeStampAndSignature,
                                height: 72,
                                width: 160,
                              ),
                              pw.Container(width: 160, height: 1.0, color: darkTextColor),
                              pw.SizedBox(height: 3),
                              pw.Text(
                                'Authorized Signatory',
                                style: pw.TextStyle(color: darkTextColor, fontSize: 8.0, fontWeight: pw.FontWeight.bold),
                              ),
                              pw.SizedBox(height: 2),
                              pw.Text(
                                '${receipt.signatoryName} | ${receipt.signatoryDesignation} | Betawad',
                                style: const pw.TextStyle(
                                  color: slateMutedColor,
                                  fontSize: 7.0,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    pw.SizedBox(height: 6),

                    // ==================================================
                    // 8. FOOTER NOTE
                    // ==================================================
                    pw.Container(
                      width: double.infinity,
                      padding: const pw.EdgeInsets.only(top: 2),
                      decoration: pw.BoxDecoration(
                        border: pw.Border(top: pw.BorderSide(color: borderDarkColor, width: 0.5)),
                      ),
                      child: pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text(
                            'Siya Infotech and Digital Solutions | Customer Margin Money Receipt | PM Surya Ghar',
                            style: const pw.TextStyle(color: slateMutedColor, fontSize: 6.2),
                          ),
                          pw.Text(
                            'Page 1 of 1 | Single-Page A4 Bank Document',
                            style: const pw.TextStyle(color: slateMutedColor, fontSize: 6.2),
                          ),
                        ],
                      ),
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

  static pw.Widget _buildInlineField(String label, String value, {bool isBold = false, PdfColor? valueColor}) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.SizedBox(
          width: 80,
          child: pw.Text(
            '$label:',
            style: const pw.TextStyle(fontSize: 7.2, color: slateMutedColor),
          ),
        ),
        pw.Expanded(
          child: pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: 7.2,
              fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
              color: valueColor ?? (isBold ? darkTextColor : slateBodyColor),
            ),
          ),
        ),
      ],
    );
  }

  static pw.Widget _buildTableRow(String sr, String desc, String pct, String amount, {bool isZebra = false}) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 2.8),
      decoration: pw.BoxDecoration(
        color: isZebra ? zebraBgColor : PdfColors.white,
        border: const pw.Border(top: pw.BorderSide(color: borderDarkColor, width: 0.6)),
      ),
      child: pw.Row(
        children: [
          pw.SizedBox(width: 30, child: pw.Text(sr, style: const pw.TextStyle(fontSize: 7.5, color: slateMutedColor))),
          pw.Expanded(flex: 6, child: pw.Text(desc, style: const pw.TextStyle(fontSize: 7.5, color: slateBodyColor))),
          pw.Expanded(flex: 3, child: pw.Text(pct, textAlign: pw.TextAlign.center, style: const pw.TextStyle(fontSize: 7.5, color: slateBodyColor))),
          pw.SizedBox(width: 100, child: pw.Text(amount, textAlign: pw.TextAlign.right, style: pw.TextStyle(fontSize: 8.0, fontWeight: pw.FontWeight.bold, color: darkTextColor))),
        ],
      ),
    );
  }

  /// Print or Save using printing package
  static Future<void> printReceipt(
    CustomerMarginReceipt receipt, {
    bool includeStampAndSignature = true,
    bool includeCustomerSignature = true,
    Uint8List? customCustomerSignatureBytes,
  }) async {
    final pdfBytes = await generateReceiptPdfBytes(
      receipt,
      includeStampAndSignature: includeStampAndSignature,
      includeCustomerSignature: includeCustomerSignature,
      customCustomerSignatureBytes: customCustomerSignatureBytes,
    );
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdfBytes,
      name: receipt.pdfFileName,
    );
  }

  /// Save PDF file to chosen location
  static Future<String?> downloadPdf(
    CustomerMarginReceipt receipt, {
    bool includeStampAndSignature = true,
    bool includeCustomerSignature = true,
    Uint8List? customCustomerSignatureBytes,
  }) async {
    final pdfBytes = await generateReceiptPdfBytes(
      receipt,
      includeStampAndSignature: includeStampAndSignature,
      includeCustomerSignature: includeCustomerSignature,
      customCustomerSignatureBytes: customCustomerSignatureBytes,
    );
    await Printing.sharePdf(
      bytes: pdfBytes,
      filename: receipt.pdfFileName,
    );
    return receipt.pdfFileName;
  }

  /// Share Margin Money Receipt via WhatsApp
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
_(For Bank Loan / Finance Purpose - PM Surya Ghar)_

Dear *${receipt.customerName}*,
We have received your 10% Customer Margin Contribution for the Bank Solar Loan installation.

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
Betawad, Dist. Dhule | Helpline: 7972143798
''';

    final uri = Uri.parse('https://wa.me/$targetPhone?text=${Uri.encodeComponent(message)}');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
