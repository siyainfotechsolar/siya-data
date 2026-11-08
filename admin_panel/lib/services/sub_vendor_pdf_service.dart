import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:siya_shared/siya_shared.dart';
import 'solar_quotation_font_helper.dart';

/// Professional PDF Generator for Sub-Vendor Site Settlement Sheets and Account Statements.
class SubVendorPdfService {
  static const PdfColor navyColor = PdfColor.fromInt(0xFF0D2B6F);
  static const PdfColor emeraldColor = PdfColor.fromInt(0xFF047857);
  static const PdfColor darkTextColor = PdfColor.fromInt(0xFF0F172A);
  static const PdfColor slateBodyColor = PdfColor.fromInt(0xFF1E293B);
  static const PdfColor slateMutedColor = PdfColor.fromInt(0xFF475569);
  static const PdfColor borderDarkColor = PdfColor.fromInt(0xFF94A3B8);
  static const PdfColor headerBgColor = PdfColor.fromInt(0xFFF1F5F9);
  static const PdfColor zebraBgColor = PdfColor.fromInt(0xFFF8FAFC);
  static const PdfColor accentBannerBg = PdfColor.fromInt(0xFFE0F2FE);

  static final _currency = NumberFormat.currency(locale: 'en_IN', symbol: 'Rs. ', decimalDigits: 2);
  static final _dateFormat = DateFormat('dd-MM-yyyy');

  // ============================================================================
  // 1. SITE-WISE FINANCIAL & MATERIAL SETTLEMENT STATEMENT PDF
  // ============================================================================

  static Future<Uint8List> generateSiteStatementPdfBytes(
    SiteFinancialDetail detail, {
    SubVendor? vendor,
  }) async {
    final pdfTheme = await SolarQuotationFontHelper.loadPdfTheme();
    final pdf = pw.Document(theme: pdfTheme);
    final a = detail.assignment;

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 28, vertical: 24),
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Corporate Header
              pw.Container(
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  color: headerBgColor,
                  border: pw.Border.all(color: borderDarkColor, width: 0.8),
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'SIYA INFOTECH & SOLAR ENERGY',
                          style: pw.TextStyle(
                            color: navyColor,
                            fontSize: 14,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        pw.SizedBox(height: 2),
                        pw.Text(
                          'Engineering, Procurement & Construction (EPC) Partner Network',
                          style: const pw.TextStyle(fontSize: 7.8, color: slateMutedColor),
                        ),
                        pw.Text(
                          'Betawad, Tal. Shindkheda, Dist. Dhule, Maharashtra | Contact: 9673220315',
                          style: const pw.TextStyle(fontSize: 7.2, color: slateMutedColor),
                        ),
                      ],
                    ),
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: const pw.BoxDecoration(
                        color: navyColor,
                        borderRadius: pw.BorderRadius.all(pw.Radius.circular(3)),
                      ),
                      child: pw.Text(
                        'SUB-VENDOR SITE SETTLEMENT',
                        style: pw.TextStyle(
                          color: PdfColors.white,
                          fontSize: 8.5,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              pw.SizedBox(height: 8),

              // Sub-Vendor & Customer Details Grid
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // Sub-Vendor Box
                  pw.Expanded(
                    child: pw.Container(
                      padding: const pw.EdgeInsets.all(8),
                      decoration: pw.BoxDecoration(
                        border: pw.Border.all(color: borderDarkColor, width: 0.8),
                        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                      ),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            'SUB-VENDOR INFORMATION',
                            style: pw.TextStyle(
                              fontSize: 8.2,
                              fontWeight: pw.FontWeight.bold,
                              color: navyColor,
                            ),
                          ),
                          pw.Divider(color: borderDarkColor, thickness: 0.5, height: 6),
                          _infoRow('Vendor Name:', a.vendorName ?? vendor?.name ?? 'Sub-Vendor'),
                          _infoRow('Vendor Code:', a.vendorCode ?? vendor?.vendorCode ?? 'VND'),
                          _infoRow('Mobile No.:', a.customerMobile ?? vendor?.mobile ?? '-'),
                          _infoRow('Bank & A/C:', '${vendor?.bankName ?? "-"} | ${vendor?.accountNumber ?? "-"}'),
                          _infoRow('IFSC Code:', vendor?.ifscCode ?? '-'),
                        ],
                      ),
                    ),
                  ),
                  pw.SizedBox(width: 8),
                  // Site & Customer Box
                  pw.Expanded(
                    child: pw.Container(
                      padding: const pw.EdgeInsets.all(8),
                      decoration: pw.BoxDecoration(
                        border: pw.Border.all(color: borderDarkColor, width: 0.8),
                        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                      ),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            'ASSIGNED SITE & CUSTOMER',
                            style: pw.TextStyle(
                              fontSize: 8.2,
                              fontWeight: pw.FontWeight.bold,
                              color: navyColor,
                            ),
                          ),
                          pw.Divider(color: borderDarkColor, thickness: 0.5, height: 6),
                          _infoRow('Customer Name:', a.customerName ?? 'Customer'),
                          _infoRow('Consumer / CA No.:', a.consumerNo ?? '-'),
                          _infoRow('Site Capacity:', '${a.siteCapacityKw} kW'),
                          _infoRow('Assigned Date:', _dateFormat.format(a.assignedDate)),
                          _infoRow('Site Status:', a.status),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              pw.SizedBox(height: 8),

              // Section 1: Materials Issued & Returned
              _sectionHeader('1. ACTUAL MATERIAL ISSUED & RETURNED (DYNAMIC SITE COST)'),
              pw.Container(
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: borderDarkColor, width: 0.8),
                ),
                child: pw.Column(
                  children: [
                    // Header Row
                    pw.Container(
                      color: headerBgColor,
                      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 3.5),
                      child: pw.Row(
                        children: [
                          pw.SizedBox(width: 20, child: pw.Text('#', style: _thStyle)),
                          pw.Expanded(flex: 3, child: pw.Text('Item Description', style: _thStyle)),
                          pw.SizedBox(width: 45, child: pw.Text('Type', style: _thStyle)),
                          pw.SizedBox(width: 35, child: pw.Text('GST %', style: _thStyle)),
                          pw.SizedBox(width: 45, child: pw.Text('Qty', style: _thStyle)),
                          pw.SizedBox(width: 55, child: pw.Text('Unit Rate', style: _thStyle)),
                          pw.SizedBox(width: 60, child: pw.Text('Taxable', style: _thStyle)),
                          pw.SizedBox(width: 50, child: pw.Text('GST Amt', style: _thStyle)),
                          pw.SizedBox(width: 65, child: pw.Text('Total', style: _thStyle, textAlign: pw.TextAlign.right)),
                        ],
                      ),
                    ),
                    if (detail.materials.isEmpty)
                      pw.Container(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Center(
                          child: pw.Text(
                            'No material transactions recorded for this site yet.',
                            style: const pw.TextStyle(fontSize: 7.5, color: slateMutedColor),
                          ),
                        ),
                      )
                    else
                      ...detail.materials.asMap().entries.map((entry) {
                        final i = entry.key;
                        final m = entry.value;
                        final isRet = m.isReturn;
                        return pw.Container(
                          color: i % 2 == 1 ? zebraBgColor : PdfColors.white,
                          padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                          child: pw.Row(
                            children: [
                              pw.SizedBox(width: 20, child: pw.Text('${i + 1}', style: _tdStyle)),
                              pw.Expanded(
                                flex: 3,
                                child: pw.Text(
                                  m.itemName,
                                  style: pw.TextStyle(
                                    fontSize: 7.2,
                                    fontWeight: pw.FontWeight.bold,
                                    color: darkTextColor,
                                  ),
                                ),
                              ),
                              pw.SizedBox(
                                width: 45,
                                child: pw.Text(
                                  isRet ? 'RETURN' : 'ISSUE',
                                  style: pw.TextStyle(
                                    fontSize: 6.8,
                                    fontWeight: pw.FontWeight.bold,
                                    color: isRet ? PdfColors.red700 : emeraldColor,
                                  ),
                                ),
                              ),
                              pw.SizedBox(width: 35, child: pw.Text('${m.gstRate.toStringAsFixed(0)}%', style: _tdStyle)),
                              pw.SizedBox(width: 45, child: pw.Text('${m.quantity} ${m.unit}', style: _tdStyle)),
                              pw.SizedBox(width: 55, child: pw.Text(_currency.format(m.unitRate), style: _tdStyle)),
                              pw.SizedBox(
                                width: 60,
                                child: pw.Text(
                                  '${isRet ? "-" : ""}${_currency.format(m.taxableAmount)}',
                                  style: _tdStyle,
                                ),
                              ),
                              pw.SizedBox(
                                width: 50,
                                child: pw.Text(
                                  '${isRet ? "-" : ""}${_currency.format(m.gstAmount)}',
                                  style: _tdStyle,
                                ),
                              ),
                              pw.SizedBox(
                                width: 65,
                                child: pw.Text(
                                  '${isRet ? "-" : ""}${_currency.format(m.totalAmount)}',
                                  style: pw.TextStyle(
                                    fontSize: 7.2,
                                    fontWeight: pw.FontWeight.bold,
                                    color: isRet ? PdfColors.red700 : darkTextColor,
                                  ),
                                  textAlign: pw.TextAlign.right,
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                  ],
                ),
              ),

              pw.SizedBox(height: 6),

              // Material Summary Subtotal Box (5% vs 18% GST Breakdown)
              pw.Container(
                padding: const pw.EdgeInsets.all(6),
                decoration: pw.BoxDecoration(
                  color: headerBgColor,
                  border: pw.Border.all(color: borderDarkColor, width: 0.8),
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(3)),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    _subSummary('5% GST Category (Panels & Inverter):', _currency.format(detail.material5Total)),
                    _subSummary('18% GST Category (Solar BOS):', _currency.format(detail.material18Total)),
                    _subSummary('Total Eligible Input GST:', _currency.format(detail.totalEligibleInputGst)),
                    _subSummary('Net Material Cost:', _currency.format(detail.totalMaterialCost), isBold: true),
                  ],
                ),
              ),

              pw.SizedBox(height: 8),

              // Section 2: Financial Calculation & Settlement
              _sectionHeader('2. VENDOR CHARGES & FINAL SETTLEMENT BREAKDOWN'),
              pw.Container(
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: borderDarkColor, width: 0.8),
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                ),
                child: pw.Column(
                  children: [
                    _settlementRow(
                      'Vendor Installation Charges (${a.siteCapacityKw} kW @ ${_currency.format(a.ratePerKw)}/kW):',
                      _currency.format(detail.vendorCharges),
                    ),
                    _settlementRow(
                      'Approved Other Expenses / Transportation:',
                      _currency.format(detail.otherExpenses),
                      isZebra: true,
                    ),
                    _settlementRow(
                      'Total Vendor Settlement Amount Payable:',
                      _currency.format(detail.totalVendorPayable),
                      isBold: true,
                    ),
                    _settlementRow(
                      'Disbursed Payouts Received to Date:',
                      '- ${_currency.format(detail.totalPaidToVendor)}',
                      isZebra: true,
                      valueColor: emeraldColor,
                    ),
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      color: accentBannerBg,
                      child: pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text(
                            'NET OUTSTANDING SETTLEMENT BALANCE:',
                            style: pw.TextStyle(
                              fontSize: 8.5,
                              fontWeight: pw.FontWeight.bold,
                              color: navyColor,
                            ),
                          ),
                          pw.Text(
                            _currency.format(detail.outstandingVendorPayable),
                            style: pw.TextStyle(
                              fontSize: 10,
                              fontWeight: pw.FontWeight.bold,
                              color: detail.outstandingVendorPayable > 0 ? navyColor : emeraldColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              pw.Spacer(),

              // Authorization & Signatures
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Container(width: 140, height: 0.8, color: borderDarkColor),
                      pw.SizedBox(height: 3),
                      pw.Text(
                        'Sub-Vendor Acceptance & Sign',
                        style: const pw.TextStyle(fontSize: 7.2, color: slateMutedColor),
                      ),
                      pw.Text(
                        a.vendorName ?? vendor?.name ?? 'Partner',
                        style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold),
                      ),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      pw.Container(width: 140, height: 0.8, color: borderDarkColor),
                      pw.SizedBox(height: 3),
                      pw.Text(
                        'Accounts Verification',
                        style: const pw.TextStyle(fontSize: 7.2, color: slateMutedColor),
                      ),
                      pw.Text(
                        'SIYA Infotech Accounts',
                        style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold),
                      ),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Container(width: 140, height: 0.8, color: borderDarkColor),
                      pw.SizedBox(height: 3),
                      pw.Text(
                        'Authorized Signatory & Stamp',
                        style: const pw.TextStyle(fontSize: 7.2, color: slateMutedColor),
                      ),
                      pw.Text(
                        'Siya Infotech & Solar Energy',
                        style: pw.TextStyle(
                          fontSize: 7.5,
                          fontWeight: pw.FontWeight.bold,
                          color: navyColor,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 4),
              pw.Center(
                child: pw.Text(
                  'Statement generated by Siya Data Management Software on ${_dateFormat.format(DateTime.now())}',
                  style: const pw.TextStyle(fontSize: 6.5, color: slateMutedColor),
                ),
              ),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  // ============================================================================
  // 2. OVERALL SUB-VENDOR ACCOUNT STATEMENT PDF
  // ============================================================================

  static Future<Uint8List> generateVendorOverallStatementPdfBytes(
    VendorFinancialSummary summary, {
    SubVendor? vendor,
  }) async {
    final pdfTheme = await SolarQuotationFontHelper.loadPdfTheme();
    final pdf = pw.Document(theme: pdfTheme);

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 28, vertical: 24),
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Corporate Header
              pw.Container(
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  color: headerBgColor,
                  border: pw.Border.all(color: borderDarkColor, width: 0.8),
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'SIYA INFOTECH & SOLAR ENERGY',
                          style: pw.TextStyle(
                            color: navyColor,
                            fontSize: 14,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        pw.SizedBox(height: 2),
                        pw.Text(
                          'Sub-Vendor Master Financial & Performance Statement',
                          style: const pw.TextStyle(fontSize: 7.8, color: slateMutedColor),
                        ),
                      ],
                    ),
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: const pw.BoxDecoration(
                        color: navyColor,
                        borderRadius: pw.BorderRadius.all(pw.Radius.circular(3)),
                      ),
                      child: pw.Text(
                        'MASTER STATEMENT',
                        style: pw.TextStyle(
                          color: PdfColors.white,
                          fontSize: 8.5,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              pw.SizedBox(height: 8),

              // Vendor Profile Bar
              pw.Container(
                padding: const pw.EdgeInsets.all(8),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: borderDarkColor, width: 0.8),
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    _subSummary('Vendor Name:', summary.vendorName, isBold: true),
                    _subSummary('Vendor Code:', summary.vendorCode, isBold: true),
                    _subSummary('Assigned Sites:', '${summary.totalAssignedSites} (${summary.completedSites} Completed)'),
                    _subSummary('Total Capacity:', '${summary.totalCapacityKw} kW', isBold: true),
                  ],
                ),
              ),

              pw.SizedBox(height: 8),

              // KPI Financial Tiles
              pw.Row(
                children: [
                  _kpiBox('Total Material Cost', _currency.format(summary.totalMaterialCost), slateBodyColor),
                  pw.SizedBox(width: 6),
                  _kpiBox('Vendor Charges', _currency.format(summary.totalVendorCharges), navyColor),
                  pw.SizedBox(width: 6),
                  _kpiBox('Total Paid', _currency.format(summary.totalPaidAmount), emeraldColor),
                  pw.SizedBox(width: 6),
                  _kpiBox('Outstanding Due', _currency.format(summary.outstandingSettlement), navyColor, isHighlight: true),
                ],
              ),

              pw.SizedBox(height: 8),

              // Section 1: Site-wise Summary Table
              _sectionHeader('1. SITE-BY-SITE PERFORMANCE & FINANCIAL BREAKDOWN'),
              pw.Container(
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: borderDarkColor, width: 0.8),
                ),
                child: pw.Column(
                  children: [
                    pw.Container(
                      color: headerBgColor,
                      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 3.5),
                      child: pw.Row(
                        children: [
                          pw.SizedBox(width: 20, child: pw.Text('#', style: _thStyle)),
                          pw.SizedBox(width: 65, child: pw.Text('CA / Site ID', style: _thStyle)),
                          pw.Expanded(child: pw.Text('Customer Name', style: _thStyle)),
                          pw.SizedBox(width: 45, child: pw.Text('kW', style: _thStyle)),
                          pw.SizedBox(width: 65, child: pw.Text('Status', style: _thStyle)),
                          pw.SizedBox(width: 70, child: pw.Text('Material Cost', style: _thStyle)),
                          pw.SizedBox(width: 65, child: pw.Text('Charges', style: _thStyle)),
                          pw.SizedBox(width: 65, child: pw.Text('Paid', style: _thStyle)),
                          pw.SizedBox(width: 70, child: pw.Text('Balance', style: _thStyle, textAlign: pw.TextAlign.right)),
                        ],
                      ),
                    ),
                    if (summary.siteDetails.isEmpty)
                      pw.Container(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Center(
                          child: pw.Text('No sites assigned yet.', style: const pw.TextStyle(fontSize: 7.5)),
                        ),
                      )
                    else
                      ...summary.siteDetails.asMap().entries.map((entry) {
                        final i = entry.key;
                        final s = entry.value;
                        return pw.Container(
                          color: i % 2 == 1 ? zebraBgColor : PdfColors.white,
                          padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                          child: pw.Row(
                            children: [
                              pw.SizedBox(width: 20, child: pw.Text('${i + 1}', style: _tdStyle)),
                              pw.SizedBox(width: 65, child: pw.Text(s.assignment.consumerNo ?? '-', style: _tdStyle)),
                              pw.Expanded(
                                child: pw.Text(
                                  s.assignment.customerName ?? '-',
                                  style: pw.TextStyle(
                                    fontSize: 7.2,
                                    fontWeight: pw.FontWeight.bold,
                                    color: darkTextColor,
                                  ),
                                ),
                              ),
                              pw.SizedBox(width: 45, child: pw.Text('${s.assignment.siteCapacityKw} kW', style: _tdStyle)),
                              pw.SizedBox(width: 65, child: pw.Text(s.assignment.status, style: _tdStyle)),
                              pw.SizedBox(width: 70, child: pw.Text(_currency.format(s.totalMaterialCost), style: _tdStyle)),
                              pw.SizedBox(width: 65, child: pw.Text(_currency.format(s.vendorCharges), style: _tdStyle)),
                              pw.SizedBox(width: 65, child: pw.Text(_currency.format(s.totalPaidToVendor), style: _tdStyle)),
                              pw.SizedBox(
                                width: 70,
                                child: pw.Text(
                                  _currency.format(s.outstandingVendorPayable),
                                  style: pw.TextStyle(
                                    fontSize: 7.2,
                                    fontWeight: pw.FontWeight.bold,
                                    color: s.outstandingVendorPayable > 0 ? navyColor : emeraldColor,
                                  ),
                                  textAlign: pw.TextAlign.right,
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                  ],
                ),
              ),

              pw.SizedBox(height: 8),

              // Section 2: Consolidated Summary
              _sectionHeader('2. CONSOLIDATED FINANCIAL SUMMARY'),
              pw.Container(
                padding: const pw.EdgeInsets.all(8),
                decoration: pw.BoxDecoration(
                  color: headerBgColor,
                  border: pw.Border.all(color: borderDarkColor, width: 0.8),
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    _subSummary('5% GST Material Total:', _currency.format(summary.material5Total)),
                    _subSummary('18% GST BOS Total:', _currency.format(summary.material18Total)),
                    _subSummary('Total Input GST:', _currency.format(summary.totalEligibleInputGst)),
                    _subSummary('Total Payouts Made:', _currency.format(summary.totalPaidAmount)),
                    _subSummary('Net Outstanding Due:', _currency.format(summary.outstandingSettlement), isBold: true),
                  ],
                ),
              ),

              pw.Spacer(),

              // Signatures
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Container(width: 140, height: 0.8, color: borderDarkColor),
                      pw.SizedBox(height: 3),
                      pw.Text('Sub-Vendor Signature', style: const pw.TextStyle(fontSize: 7.2, color: slateMutedColor)),
                      pw.Text(summary.vendorName, style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold)),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Container(width: 140, height: 0.8, color: borderDarkColor),
                      pw.SizedBox(height: 3),
                      pw.Text('Authorized Signatory & Stamp', style: const pw.TextStyle(fontSize: 7.2, color: slateMutedColor)),
                      pw.Text('Siya Infotech & Solar Energy', style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: navyColor)),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 4),
              pw.Center(
                child: pw.Text(
                  'Siya Data Management Software — Confidential Partner Document',
                  style: const pw.TextStyle(fontSize: 6.5, color: slateMutedColor),
                ),
              ),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  // ============================================================================
  // PRINT / PREVIEW ACTIONS
  // ============================================================================

  static Future<void> printOrShareSiteStatement(
    SiteFinancialDetail detail, {
    SubVendor? vendor,
  }) async {
    final bytes = await generateSiteStatementPdfBytes(detail, vendor: vendor);
    await Printing.layoutPdf(
      onLayout: (format) async => bytes,
      name: 'Site_Settlement_${detail.assignment.consumerNo ?? "VND"}.pdf',
    );
  }

  static Future<void> printOrShareVendorOverallStatement(
    VendorFinancialSummary summary, {
    SubVendor? vendor,
  }) async {
    final bytes = await generateVendorOverallStatementPdfBytes(summary, vendor: vendor);
    await Printing.layoutPdf(
      onLayout: (format) async => bytes,
      name: 'Vendor_Statement_${summary.vendorCode}.pdf',
    );
  }

  // ============================================================================
  // PRIVATE HELPER WIDGETS
  // ============================================================================

  static pw.TextStyle get _thStyle => pw.TextStyle(
        fontSize: 7.2,
        fontWeight: pw.FontWeight.bold,
        color: darkTextColor,
      );

  static pw.TextStyle get _tdStyle => const pw.TextStyle(
        fontSize: 7.0,
        color: slateBodyColor,
      );

  static pw.Widget _infoRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 1.5),
      child: pw.Row(
        children: [
          pw.SizedBox(
            width: 80,
            child: pw.Text(
              label,
              style: const pw.TextStyle(fontSize: 7.2, color: slateMutedColor),
            ),
          ),
          pw.Expanded(
            child: pw.Text(
              value,
              style: pw.TextStyle(fontSize: 7.2, fontWeight: pw.FontWeight.bold, color: darkTextColor),
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _sectionHeader(String title) {
    return pw.Container(
      color: headerBgColor,
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      margin: const pw.EdgeInsets.only(bottom: 3),
      child: pw.Row(
        children: [
          pw.Container(width: 3, height: 10, color: navyColor, margin: const pw.EdgeInsets.only(right: 5)),
          pw.Text(
            title,
            style: pw.TextStyle(fontSize: 7.8, fontWeight: pw.FontWeight.bold, color: navyColor),
          ),
        ],
      ),
    );
  }

  static pw.Widget _settlementRow(String label, String value, {bool isZebra = false, bool isBold = false, PdfColor? valueColor}) {
    return pw.Container(
      color: isZebra ? zebraBgColor : PdfColors.white,
      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(
              fontSize: 7.5,
              fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
              color: isBold ? navyColor : darkTextColor,
            ),
          ),
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: 7.8,
              fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
              color: valueColor ?? (isBold ? navyColor : darkTextColor),
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _subSummary(String label, String value, {bool isBold = false}) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(label, style: const pw.TextStyle(fontSize: 6.5, color: slateMutedColor)),
        pw.Text(
          value,
          style: pw.TextStyle(
            fontSize: 7.5,
            fontWeight: pw.FontWeight.bold,
            color: isBold ? navyColor : darkTextColor,
          ),
        ),
      ],
    );
  }

  static pw.Widget _kpiBox(String title, String value, PdfColor color, {bool isHighlight = false}) {
    return pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.all(6),
        decoration: pw.BoxDecoration(
          color: isHighlight ? accentBannerBg : headerBgColor,
          border: pw.Border.all(color: isHighlight ? navyColor : borderDarkColor, width: 0.8),
          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(3)),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(title, style: const pw.TextStyle(fontSize: 6.8, color: slateMutedColor)),
            pw.SizedBox(height: 2),
            pw.Text(
              value,
              style: pw.TextStyle(fontSize: 8.8, fontWeight: pw.FontWeight.bold, color: color),
            ),
          ],
        ),
      ),
    );
  }
}
