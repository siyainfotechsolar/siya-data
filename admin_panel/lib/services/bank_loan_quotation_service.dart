import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/solar_quotation.dart';

class BankLoanQuotationService {
  static const PdfColor navyColor = PdfColor.fromInt(0xFF0D2B6F);
  static const PdfColor emeraldColor = PdfColor.fromInt(0xFF047857);
  static const PdfColor lightGreenColor = PdfColor.fromInt(0xFF10B981);
  static const PdfColor goldenYellowColor = PdfColor.fromInt(0xFFF59E0B);
  static const PdfColor darkTextColor = PdfColor.fromInt(0xFF0F172A);
  static const PdfColor slateBodyColor = PdfColor.fromInt(0xFF1E293B);
  static const PdfColor slateMutedColor = PdfColor.fromInt(0xFF475569);
  static const PdfColor borderDarkColor = PdfColor.fromInt(0xFF334155);
  static const PdfColor tableBorderColor = PdfColor.fromInt(0xFF334155);
  static const PdfColor headerBgColor = PdfColor.fromInt(0xFFF1F5F9);
  static const PdfColor zebraBgColor = PdfColor.fromInt(0xFFF8FAFC);

  /// Helper to build toner-friendly section headers with crisp border and bold black text
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

  /// Generate Single-Page A4 PDF bytes for Bank Loan Solar Quotation
  static Future<Uint8List> generateQuotationPdfBytes(SolarQuotation quotation) async {
    final pdf = pw.Document();

    // Load Company Logo from Assets
    pw.MemoryImage? logoImage;
    try {
      final ByteData logoData = await rootBundle.load('assets/images/logo.png');
      logoImage = pw.MemoryImage(logoData.buffer.asUint8List());
    } catch (e) {
      debugPrint('Logo load error in admin quotation service: $e');
    }

    final currencyFormatter = NumberFormat.currency(locale: 'en_IN', symbol: 'Rs. ', decimalDigits: 2);

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
                    // 1. HEADER: MASTER WCR LETTERHEAD
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
                                'SIYA INFOTECH & DIGITAL SOLUTIONS',
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
                              pw.SizedBox(height: 1.5),
                              pw.Text(
                                'PM Surya Ghar Yojana - Authorized Vendor',
                                style: pw.TextStyle(
                                  color: emeraldColor,
                                  fontSize: 7.8,
                                  fontWeight: pw.FontWeight.bold,
                                ),
                              ),
                              pw.SizedBox(height: 1.0),
                              pw.Text(
                                'Betawad, Taluka Shindkheda, District Dhule, Maharashtra',
                                style: const pw.TextStyle(
                                  color: slateMutedColor,
                                  fontSize: 7.0,
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
                              'Phone: 7588003220',
                              style: pw.TextStyle(
                                color: navyColor,
                                fontSize: 8.0,
                                fontWeight: pw.FontWeight.bold,
                              ),
                            ),
                            pw.SizedBox(height: 1.5),
                            pw.Text(
                              'Email: siyainfodigital@gmail.com',
                              style: const pw.TextStyle(
                                color: slateBodyColor,
                                fontSize: 7.2,
                              ),
                            ),
                            pw.SizedBox(height: 1.5),
                            pw.Text(
                              'Betawad, Tal. Shindkheda,',
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

                    // Triple-Tone Separator (Deep Blue + Green + Golden Yellow)
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
                    // 2. QUOTATION TITLE BANNER (B&W and Color Optimized)
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
                                'SOLAR SYSTEM QUOTATION',
                                style: pw.TextStyle(
                                  color: darkTextColor,
                                  fontSize: 12.0,
                                  fontWeight: pw.FontWeight.bold,
                                ),
                              ),
                              pw.Text(
                                'For Bank Loan / Finance Purpose',
                                style: pw.TextStyle(
                                  color: slateBodyColor,
                                  fontSize: 7.8,
                                  fontWeight: pw.FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.end,
                            children: [
                              pw.Text(
                                'Quotation No.: ${quotation.quotationNo}',
                                style: pw.TextStyle(
                                  color: darkTextColor,
                                  fontSize: 7.8,
                                  fontWeight: pw.FontWeight.bold,
                                ),
                              ),
                              pw.Text(
                                'Date: ${quotation.formattedDate}',
                                style: pw.TextStyle(
                                  color: darkTextColor,
                                  fontSize: 7.8,
                                  fontWeight: pw.FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    pw.SizedBox(height: 5),

                    // ==================================================
                    // 3. CUSTOMER DETAILS (5 Fields strictly as per profile)
                    // ==================================================
                    _buildSectionHeader('CUSTOMER DETAILS (As per Customer Profile)'),

                    pw.Container(
                      decoration: pw.BoxDecoration(
                        border: pw.Border.all(color: borderDarkColor, width: 0.8),
                      ),
                      child: pw.Column(
                        children: [
                          _buildTableRow('Customer Name', quotation.customerName, 'Consumer No.', quotation.consumerNo, isZebra: false, isLeftBold: true),
                          _buildTableRow('Address', quotation.address.isNotEmpty ? quotation.address : 'Betawad', 'Village / City', quotation.villageCity.isNotEmpty ? quotation.villageCity : 'Betawad', isZebra: true),
                          _buildTableRow('District', quotation.district.isNotEmpty ? quotation.district : 'Dhule', 'Mobile No.', quotation.mobileNo.isNotEmpty ? quotation.mobileNo : 'N/A', isZebra: false),
                        ],
                      ),
                    ),

                    pw.SizedBox(height: 5),

                    // ==================================================
                    // 4. SYSTEM DETAILS
                    // ==================================================
                    _buildSectionHeader('SYSTEM DETAILS & TECHNICAL SPECIFICATIONS (${quotation.systemCapacity} ${quotation.systemType})'),

                    pw.Container(
                      decoration: pw.BoxDecoration(
                        border: pw.Border.all(color: borderDarkColor, width: 0.8),
                      ),
                      child: pw.Column(
                        children: [
                          // Header
                          pw.Container(
                            color: headerBgColor,
                            padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 2.2),
                            child: pw.Row(
                              children: [
                                pw.SizedBox(width: 28, child: pw.Text('Sr.', style: pw.TextStyle(fontSize: 7.8, fontWeight: pw.FontWeight.bold, color: darkTextColor))),
                                pw.Container(width: 0.8, height: 11, color: borderDarkColor, margin: const pw.EdgeInsets.symmetric(horizontal: 4)),
                                pw.Expanded(flex: 3, child: pw.Text('Component / Description', style: pw.TextStyle(fontSize: 7.8, fontWeight: pw.FontWeight.bold, color: darkTextColor))),
                                pw.Container(width: 0.8, height: 11, color: borderDarkColor, margin: const pw.EdgeInsets.symmetric(horizontal: 4)),
                                pw.Expanded(flex: 5, child: pw.Text('Technical Specification / Standard', style: pw.TextStyle(fontSize: 7.8, fontWeight: pw.FontWeight.bold, color: darkTextColor))),
                                pw.Container(width: 0.8, height: 11, color: borderDarkColor, margin: const pw.EdgeInsets.symmetric(horizontal: 4)),
                                pw.SizedBox(width: 70, child: pw.Text('Quantity', textAlign: pw.TextAlign.center, style: pw.TextStyle(fontSize: 7.8, fontWeight: pw.FontWeight.bold, color: darkTextColor))),
                              ],
                            ),
                          ),
                          ...quotation.items.asMap().entries.map((entry) {
                            final i = entry.key;
                            final item = entry.value;
                            return pw.Container(
                              padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 1.8),
                              decoration: pw.BoxDecoration(
                                color: i % 2 == 1 ? zebraBgColor : PdfColors.white,
                                border: const pw.Border(top: pw.BorderSide(color: borderDarkColor, width: 0.8)),
                              ),
                              child: pw.Row(
                                children: [
                                  pw.SizedBox(width: 28, child: pw.Text(item['sr'] ?? '${i + 1}', style: const pw.TextStyle(fontSize: 7.5, color: slateMutedColor))),
                                  pw.Container(width: 0.8, height: 10, color: borderDarkColor, margin: const pw.EdgeInsets.symmetric(horizontal: 4)),
                                  pw.Expanded(flex: 3, child: pw.Text(item['item'] ?? '', style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: darkTextColor))),
                                  pw.Container(width: 0.8, height: 10, color: borderDarkColor, margin: const pw.EdgeInsets.symmetric(horizontal: 4)),
                                  pw.Expanded(flex: 5, child: pw.Text(item['spec'] ?? '', style: const pw.TextStyle(fontSize: 7.5, color: slateBodyColor))),
                                  pw.Container(width: 0.8, height: 10, color: borderDarkColor, margin: const pw.EdgeInsets.symmetric(horizontal: 4)),
                                  pw.SizedBox(width: 70, child: pw.Text(item['qty'] ?? '', textAlign: pw.TextAlign.center, style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: darkTextColor))),
                                ],
                              ),
                            );
                          }),
                        ],
                      ),
                    ),

                    pw.SizedBox(height: 5),

                    // ==================================================
                    // 5. FINANCIAL DETAILS & BANK DETAILS (Side-by-Side)
                    // ==================================================
                    pw.Row(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        // Left: Financial Details
                        pw.Expanded(
                          flex: 1,
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              _buildSectionHeader('FINANCIAL DETAILS'),
                              pw.Container(
                                decoration: pw.BoxDecoration(
                                  border: pw.Border.all(color: borderDarkColor, width: 0.8),
                                ),
                                child: pw.Column(
                                  children: [
                                    _buildFinRow('Total System Cost', currencyFormatter.format(quotation.totalSystemCost)),
                                    _buildFinRow('GST (Tax)', quotation.gstAmount > 0 ? currencyFormatter.format(quotation.gstAmount) : 'Exempt / Inclusive', isZebra: true),
                                    // Grand Total: Highlighted with soft cream/gold background, golden yellow indicator bar, and crisp bold text
                                    pw.Container(
                                      decoration: pw.BoxDecoration(
                                        color: const PdfColor.fromInt(0xFFFEFCE8),
                                        border: pw.Border.all(color: darkTextColor, width: 1.4),
                                      ),
                                      child: pw.Row(
                                        children: [
                                          pw.Container(width: 3.5, height: 16, color: goldenYellowColor),
                                          pw.Expanded(
                                            child: pw.Padding(
                                              padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 3.0),
                                              child: pw.Row(
                                                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                                                children: [
                                                  pw.Text('GRAND TOTAL', style: pw.TextStyle(fontSize: 8.8, fontWeight: pw.FontWeight.bold, color: darkTextColor)),
                                                  pw.Text(currencyFormatter.format(quotation.grandTotal), style: pw.TextStyle(fontSize: 10.0, fontWeight: pw.FontWeight.bold, color: darkTextColor)),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    _buildFinRow('Bank Loan Amount', currencyFormatter.format(quotation.bankLoanAmount), isBold: true),
                                    _buildFinRow('Customer Contribution', currencyFormatter.format(quotation.customerContribution), isZebra: true),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        pw.SizedBox(width: 9),
                        // Right: Bank Account Details
                        pw.Expanded(
                          flex: 1,
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              _buildSectionHeader('BANK ACCOUNT (For Loan Disbursement)'),
                              pw.Container(
                                decoration: pw.BoxDecoration(
                                  border: pw.Border.all(color: borderDarkColor, width: 0.8),
                                ),
                                child: pw.Column(
                                  children: [
                                    _buildBankRow('Account Name', 'SIYA INFOTECH & DIGITAL SOLUTIONS', isBold: true),
                                    _buildBankRow('Bank Name', quotation.bankName, isZebra: true),
                                    _buildBankRow('Branch', quotation.branch),
                                    _buildBankRow('Account No.', quotation.accountNo, isZebra: true, isBold: true),
                                    _buildBankRow('IFSC Code', quotation.ifscCode, isBold: true),
                                    _buildBankRow('UPI ID', quotation.upiId, isZebra: true),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    pw.SizedBox(height: 4),

                    // Amount in Words
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 3.0),
                      decoration: pw.BoxDecoration(
                        color: PdfColors.white,
                        border: pw.Border.all(color: borderDarkColor, width: 0.8),
                      ),
                      child: pw.Row(
                        children: [
                          pw.Text('Amount in Words: ', style: pw.TextStyle(fontSize: 7.8, fontWeight: pw.FontWeight.bold, color: darkTextColor)),
                          pw.Expanded(
                            child: pw.Text(
                              quotation.amountInWords,
                              style: pw.TextStyle(fontSize: 7.8, fontWeight: pw.FontWeight.bold, color: darkTextColor),
                            ),
                          ),
                        ],
                      ),
                    ),

                    pw.SizedBox(height: 5),

                    // ==================================================
                    // 6. SCOPE OF WORK & IMPORTANT NOTES (Side-by-Side)
                    // ==================================================
                    pw.Row(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        // Left: Scope of Work
                        pw.Expanded(
                          flex: 1,
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              _buildSectionHeader('SCOPE OF WORK'),
                              pw.Container(
                                padding: const pw.EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                                decoration: pw.BoxDecoration(
                                  color: PdfColors.white,
                                  border: pw.Border.all(color: borderDarkColor, width: 0.8),
                                ),
                                child: pw.Column(
                                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                                  children: [
                                    _buildBulletItem('Supply of solar panels and inverter'),
                                    _buildBulletItem('GI mounting structure'),
                                    _buildBulletItem('DC/AC cabling'),
                                    _buildBulletItem('ACDB/DCDB'),
                                    _buildBulletItem('Earthing'),
                                    _buildBulletItem('Installation & commissioning'),
                                    _buildBulletItem('Net-metering assistance'),
                                    _buildBulletItem('Testing and handover'),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        pw.SizedBox(width: 9),
                        // Right: Important Notes
                        pw.Expanded(
                          flex: 1,
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              _buildSectionHeader('IMPORTANT NOTES & CONDITIONS'),
                              pw.Container(
                                padding: const pw.EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                                decoration: pw.BoxDecoration(
                                  color: PdfColors.white,
                                  border: pw.Border.all(color: borderDarkColor, width: 0.8),
                                ),
                                child: pw.Column(
                                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                                  children: [
                                    _buildNumberedItem('1. Quotation prepared for bank loan / finance processing.'),
                                    _buildNumberedItem('2. Equipment make/model may vary based on availability.'),
                                    _buildNumberedItem('3. Government subsidy, if applicable, is subject to prevailing government rules and eligibility.'),
                                    _buildNumberedItem('4. Electricity-board charges, statutory fees and additional civil work, if applicable, may be charged separately.'),
                                    _buildNumberedItem('5. Installation will follow applicable MSEDCL/MNRE requirements.'),
                                    _buildNumberedItem('6. Quotation validity: 30 days.'),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    pw.SizedBox(height: 6),

                    // ==================================================
                    // 7. SIGNATURES & STAMPS (Customer & Vendor Dual Layout)
                    // ==================================================
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        // Left: Customer Acceptance & Signature
                        pw.Container(
                          width: 220,
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Text(
                                'Customer Acceptance',
                                style: pw.TextStyle(
                                  color: darkTextColor,
                                  fontSize: 8.5,
                                  fontWeight: pw.FontWeight.bold,
                                ),
                              ),
                              pw.SizedBox(height: 3),
                              pw.Text(
                                'I/We accept the quotation, technical specifications & payment terms.',
                                style: const pw.TextStyle(
                                  color: slateMutedColor,
                                  fontSize: 6.8,
                                ),
                              ),
                              pw.SizedBox(height: 44), // Generous space for customer's physical pen signature!
                              pw.Container(width: 160, height: 1.0, color: darkTextColor),
                              pw.SizedBox(height: 3),
                              pw.Text(
                                'Customer Signature',
                                style: pw.TextStyle(
                                  color: darkTextColor,
                                  fontSize: 8.0,
                                  fontWeight: pw.FontWeight.bold,
                                ),
                              ),
                              pw.SizedBox(height: 2),
                              pw.Text(
                                quotation.customerName,
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
                                'For SIYA INFOTECH & DIGITAL SOLUTIONS',
                                style: pw.TextStyle(
                                  color: darkTextColor,
                                  fontSize: 8.5,
                                  fontWeight: pw.FontWeight.bold,
                                ),
                              ),
                              pw.SizedBox(height: 4),
                              // Vendor Official Round Stamp (Completely blank inside, pure white background for manual ink stamp)
                              pw.Container(
                                width: 66,
                                height: 66,
                                decoration: pw.BoxDecoration(
                                  shape: pw.BoxShape.circle,
                                  color: PdfColors.white,
                                  border: pw.Border.all(color: borderDarkColor, style: pw.BorderStyle.dashed, width: 0.8),
                                ),
                                child: pw.Center(
                                  child: pw.Container(
                                    width: 56,
                                    height: 56,
                                    decoration: pw.BoxDecoration(
                                      shape: pw.BoxShape.circle,
                                      border: pw.Border.all(color: borderDarkColor, width: 0.5),
                                    ),
                                  ),
                                ),
                              ),
                              pw.SizedBox(height: 22), // Generous space for physical pen signature above the line!
                              pw.Container(width: 140, height: 1.0, color: darkTextColor),
                              pw.SizedBox(height: 3),
                              pw.Text(
                                'Authorized Signatory',
                                style: pw.TextStyle(color: darkTextColor, fontSize: 8.0, fontWeight: pw.FontWeight.bold),
                              ),
                              pw.SizedBox(height: 2),
                              pw.Text(
                                '(Vendor Stamp & Signature)',
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

                    pw.Spacer(),
                    pw.SizedBox(height: 4),

                    // ==================================================
                    // 8. FOOTER - EXACT SAME AS WCR
                    // ==================================================
                    pw.Container(
                      decoration: const pw.BoxDecoration(
                        border: pw.Border(top: pw.BorderSide(color: borderDarkColor, width: 0.8)),
                      ),
                      padding: const pw.EdgeInsets.only(top: 4),
                      child: pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text(
                            'GSTIN: 27CVTPK6358P1ZD | Helpline: 7588003220 | Email: siyainfodigital@gmail.com',
                            style: const pw.TextStyle(color: slateMutedColor, fontSize: 7.0),
                          ),
                          pw.Text(
                            'Official Bank Loan & Finance Quotation Document',
                            style: pw.TextStyle(color: darkTextColor, fontSize: 7.0, fontWeight: pw.FontWeight.bold),
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

  static pw.Widget _buildTableRow(String l1, String v1, String l2, String v2, {bool isZebra = false, bool isLeftBold = false}) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 2.2),
      decoration: pw.BoxDecoration(
        color: isZebra ? zebraBgColor : PdfColors.white,
        border: const pw.Border(top: pw.BorderSide(color: borderDarkColor, width: 0.8)),
      ),
      child: pw.Row(
        children: [
          pw.Expanded(
            child: pw.Row(
              children: [
                pw.SizedBox(width: 72, child: pw.Text(l1, style: pw.TextStyle(fontSize: 7.8, fontWeight: pw.FontWeight.bold, color: darkTextColor))),
                pw.Text(': ', style: const pw.TextStyle(fontSize: 7.8, color: slateMutedColor)),
                pw.Expanded(child: pw.Text(v1, style: pw.TextStyle(fontSize: 7.8, fontWeight: isLeftBold ? pw.FontWeight.bold : pw.FontWeight.normal, color: darkTextColor))),
              ],
            ),
          ),
          if (l2.isNotEmpty) ...[
            pw.Container(width: 0.8, height: 11, color: borderDarkColor, margin: const pw.EdgeInsets.symmetric(horizontal: 6)),
            pw.Expanded(
              child: pw.Row(
                children: [
                  pw.SizedBox(width: 72, child: pw.Text(l2, style: pw.TextStyle(fontSize: 7.8, fontWeight: pw.FontWeight.bold, color: darkTextColor))),
                  pw.Text(': ', style: const pw.TextStyle(fontSize: 7.8, color: slateMutedColor)),
                  pw.Expanded(child: pw.Text(v2, style: pw.TextStyle(fontSize: 7.8, fontWeight: isLeftBold ? pw.FontWeight.bold : pw.FontWeight.normal, color: darkTextColor))),
                ],
              ),
            ),
          ] else ...[
            pw.Spacer(),
          ],
        ],
      ),
    );
  }

  static pw.Widget _buildFinRow(String label, String value, {bool isZebra = false, bool isBold = false}) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 2.0),
      decoration: pw.BoxDecoration(
        color: isZebra ? zebraBgColor : PdfColors.white,
        border: const pw.Border(top: pw.BorderSide(color: borderDarkColor, width: 0.8)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: const pw.TextStyle(fontSize: 7.6, color: slateBodyColor)),
          pw.Text(value, style: pw.TextStyle(fontSize: 7.6, fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal, color: darkTextColor)),
        ],
      ),
    );
  }

  static pw.Widget _buildBankRow(String label, String value, {bool isZebra = false, bool isBold = false}) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 1.8),
      decoration: pw.BoxDecoration(
        color: isZebra ? zebraBgColor : PdfColors.white,
        border: const pw.Border(top: pw.BorderSide(color: borderDarkColor, width: 0.8)),
      ),
      child: pw.Row(
        children: [
          pw.SizedBox(width: 70, child: pw.Text(label, style: pw.TextStyle(fontSize: 7.4, fontWeight: pw.FontWeight.bold, color: darkTextColor))),
          pw.Text(': ', style: const pw.TextStyle(fontSize: 7.4, color: slateMutedColor)),
          pw.Expanded(child: pw.Text(value, style: pw.TextStyle(fontSize: 7.4, fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal, color: darkTextColor))),
        ],
      ),
    );
  }

  static pw.Widget _buildBulletItem(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 0.9),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.Container(
            width: 3.2,
            height: 3.2,
            margin: const pw.EdgeInsets.only(right: 5),
            decoration: const pw.BoxDecoration(
              color: darkTextColor,
              shape: pw.BoxShape.circle,
            ),
          ),
          pw.Expanded(child: pw.Text(text, style: const pw.TextStyle(fontSize: 7.2, color: darkTextColor))),
        ],
      ),
    );
  }

  static pw.Widget _buildNumberedItem(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 1.0),
      child: pw.Text(text, style: const pw.TextStyle(fontSize: 7.2, color: darkTextColor)),
    );
  }

  /// Download quotation PDF to user selected path
  static Future<void> downloadQuotationPdf(BuildContext context, SolarQuotation quotation) async {
    final pdfBytes = await generateQuotationPdfBytes(quotation);
    final String defaultFileName = quotation.pdfFileName;

    try {
      final String? selectedPath = await FilePicker.platform.saveFile(
        dialogTitle: 'Save Bank Loan Solar Quotation PDF',
        fileName: defaultFileName,
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );

      if (selectedPath != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Quotation saved to: $selectedPath'),
            backgroundColor: const Color(0xFF0D2B6F),
          ),
        );
      }
    } catch (_) {
      await Printing.sharePdf(bytes: pdfBytes, filename: defaultFileName);
    }
  }

  /// Direct Print Quotation
  static Future<void> printQuotationPdf(SolarQuotation quotation) async {
    final pdfBytes = await generateQuotationPdfBytes(quotation);
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdfBytes,
      name: quotation.pdfFileName,
    );
  }

  /// Share quotation via WhatsApp Web
  static Future<void> shareViaWhatsApp(SolarQuotation quotation) async {
    final phone = quotation.mobileNo.replaceAll(RegExp(r'\D'), '');
    final cleanPhone = phone.length == 10 ? '91$phone' : phone;

    final msg = Uri.encodeComponent(
      'Hello ${quotation.customerName},\n\n'
      'Please find attached the Bank Loan Solar Quotation for your ${quotation.systemCapacity} Solar System.\n\n'
      '• Quotation No: ${quotation.quotationNo}\n'
      '• Grand Total: Rs. ${quotation.grandTotal.toStringAsFixed(0)}\n'
      '• Bank Loan: Rs. ${quotation.bankLoanAmount.toStringAsFixed(0)}\n'
      '• Customer Contribution: Rs. ${quotation.customerContribution.toStringAsFixed(0)}\n\n'
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
