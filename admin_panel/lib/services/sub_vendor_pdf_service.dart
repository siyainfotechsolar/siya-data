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
  static const PdfColor amberColor = PdfColor.fromInt(0xFFD97706);

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

              // Section 2: Statutory 70:30 GST Accounting on Site Quotation
              _sectionHeader('2. STATUTORY GST ACCOUNTING (70:30 SOLAR SPLIT ON QUOTATION)'),
              pw.Container(
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: borderDarkColor, width: 0.8),
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                ),
                child: pw.Column(
                  children: [
                    _settlementRow(
                      'Approved Site Quotation (Statutory Output GST Basis):',
                      _currency.format(a.effectiveSiteAmount),
                      isBold: true,
                    ),
                    _settlementRow(
                      '  - 70% Goods Taxable (${_currency.format(a.gstBreakdown.taxable70)}) @ 5% GST:',
                      _currency.format(a.gstBreakdown.gst5),
                      isZebra: true,
                    ),
                    _settlementRow(
                      '  - 30% Services Taxable (${_currency.format(a.gstBreakdown.taxable30)}) @ 18% GST:',
                      _currency.format(a.gstBreakdown.gst18),
                    ),
                    _settlementRow(
                      'Total Statutory Output GST Liability (Quotation Basis):',
                      _currency.format(a.gstBreakdown.totalGstIncluded),
                      isZebra: true,
                      isBold: true,
                    ),
                    _settlementRow(
                      'Less: Eligible Dynamic Material Input GST Credit (ITC):',
                      '- ${_currency.format(detail.totalEligibleInputGst)}',
                      valueColor: emeraldColor,
                    ),
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      color: headerBgColor,
                      child: pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text(
                            'NET STATUTORY GST PAYABLE TO GOVT:',
                            style: pw.TextStyle(
                              fontSize: 8.2,
                              fontWeight: pw.FontWeight.bold,
                              color: amberColor,
                            ),
                          ),
                          pw.Text(
                            _currency.format(detail.netGstLiability),
                            style: pw.TextStyle(
                              fontSize: 9.0,
                              fontWeight: pw.FontWeight.bold,
                              color: amberColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              pw.SizedBox(height: 8),

              // Section 3: Final Contractual Settlement Breakdown (Option A - Net Balance)
              _sectionHeader('3. CONTRACTUAL FINAL SETTLEMENT BREAKDOWN (OPTION A - NET BALANCE)'),
              pw.Container(
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: borderDarkColor, width: 0.8),
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                ),
                child: pw.Column(
                  children: [
                    _settlementRow(
                      'Total Realized Collections Credited to SIYA (Bank Loan / Cash Received):',
                      _currency.format(detail.effectiveCollection),
                      isBold: true,
                      valueColor: emeraldColor,
                    ),
                    _settlementRow(
                      '  [Compliance Note: 10% Loan Margin Paper Receipt is exempt from cash calculation]',
                      'Rs. 0.00 (Exempt)',
                      isZebra: true,
                    ),
                    _settlementRow(
                      'Less: Total Dynamic Material Issued (Net of Returns):',
                      '- ${_currency.format(detail.totalMaterialCost)}',
                      valueColor: PdfColors.red800,
                    ),
                    _settlementRow(
                      'Less: SIYA Platform Charges (${a.siteCapacityKw} kW @ Rs. 1,000/kW):',
                      '- ${_currency.format(detail.vendorCharges)}',
                      isZebra: true,
                      valueColor: navyColor,
                    ),
                    _settlementRow(
                      'Less: Statutory Net GST Liability (Output GST - Eligible ITC):',
                      '- ${_currency.format(detail.netGstLiability)}',
                      valueColor: amberColor,
                    ),
                    if (detail.otherExpenses > 0)
                      _settlementRow(
                        'Less: Approved Other Expenses / Transportation:',
                        '- ${_currency.format(detail.otherExpenses)}',
                        isZebra: true,
                      ),
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      color: headerBgColor,
                      child: pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text(
                            'Sub-Vendor Gross Entitlement:',
                            style: pw.TextStyle(fontSize: 8.2, fontWeight: pw.FontWeight.bold, color: navyColor),
                          ),
                          pw.Text(
                            _currency.format(detail.effectiveCollection - detail.totalMaterialCost - detail.vendorCharges - detail.netGstLiability - detail.otherExpenses),
                            style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: navyColor),
                          ),
                        ],
                      ),
                    ),
                    _settlementRow(
                      'Less: Previous Advances & Disbursals Paid to Date:',
                      '- ${_currency.format(detail.totalPaidToVendor)}',
                      valueColor: PdfColors.red800,
                    ),
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      color: accentBannerBg,
                      child: pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text(
                            detail.netSubVendorBalance >= 0
                                ? 'FINAL NET SETTLEMENT PAYABLE TO SUB-VENDOR:'
                                : 'AMOUNT RECOVERABLE FROM SUB-VENDOR:',
                            style: pw.TextStyle(
                              fontSize: 8.8,
                              fontWeight: pw.FontWeight.bold,
                              color: detail.netSubVendorBalance >= 0 ? emeraldColor : PdfColors.red800,
                            ),
                          ),
                          pw.Text(
                            _currency.format(detail.netSubVendorBalance.abs()),
                            style: pw.TextStyle(
                              fontSize: 10.5,
                              fontWeight: pw.FontWeight.bold,
                              color: detail.netSubVendorBalance >= 0 ? emeraldColor : PdfColors.red800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              pw.SizedBox(height: 3),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'Option B Reference (Fixed Charges): ${_currency.format(detail.vendorCharges)} - Paid ${_currency.format(detail.totalPaidToVendor)} = ${_currency.format(detail.outstandingVendorPayable)}',
                    style: const pw.TextStyle(fontSize: 6.8, color: slateMutedColor),
                  ),
                  pw.Text(
                    'Statutory 70:30 Rule under Notification No. 24/2018 applied.',
                    style: const pw.TextStyle(fontSize: 6.8, color: slateMutedColor),
                  ),
                ],
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
                  _kpiBox('Total Collection', _currency.format(summary.effectiveTotalCollection), emeraldColor),
                  pw.SizedBox(width: 5),
                  _kpiBox('Less: Material Cost', '- ${_currency.format(summary.totalMaterialCost)}', PdfColors.red800),
                  pw.SizedBox(width: 5),
                  _kpiBox('Less: SIYA Charges', '- ${_currency.format(summary.totalVendorCharges)}', navyColor),
                  pw.SizedBox(width: 5),
                  _kpiBox('Less: Net GST', '- ${_currency.format(summary.totalNetGstLiability)}', amberColor),
                  pw.SizedBox(width: 5),
                  _kpiBox(
                    summary.netSettlementPayable >= 0 ? 'Net Sub-Vendor Due' : 'Amount Recoverable',
                    _currency.format(summary.netSettlementPayable.abs()),
                    summary.netSettlementPayable >= 0 ? emeraldColor : PdfColors.red800,
                    isHighlight: true,
                  ),
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
                      padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 3.5),
                      child: pw.Row(
                        children: [
                          pw.SizedBox(width: 14, child: pw.Text('#', style: _thStyle)),
                          pw.SizedBox(width: 55, child: pw.Text('CA / Site ID', style: _thStyle)),
                          pw.Expanded(child: pw.Text('Customer Name', style: _thStyle)),
                          pw.SizedBox(width: 30, child: pw.Text('kW', style: _thStyle)),
                          pw.SizedBox(width: 56, child: pw.Text('Collection', style: _thStyle)),
                          pw.SizedBox(width: 56, child: pw.Text('Material Cost', style: _thStyle)),
                          pw.SizedBox(width: 44, child: pw.Text('SIYA Fee', style: _thStyle)),
                          pw.SizedBox(width: 44, child: pw.Text('Net GST', style: _thStyle)),
                          pw.SizedBox(width: 40, child: pw.Text('Paid', style: _thStyle)),
                          pw.SizedBox(width: 58, child: pw.Text('Net Balance', style: _thStyle, textAlign: pw.TextAlign.right)),
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
                          padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 3),
                          child: pw.Row(
                            children: [
                              pw.SizedBox(width: 14, child: pw.Text('${i + 1}', style: _tdStyle)),
                              pw.SizedBox(width: 55, child: pw.Text(s.assignment.consumerNo ?? '-', style: _tdStyle)),
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
                              pw.SizedBox(width: 30, child: pw.Text('${s.assignment.siteCapacityKw} kW', style: _tdStyle)),
                              pw.SizedBox(
                                width: 56,
                                child: pw.Text(
                                  _currency.format(s.effectiveCollection),
                                  style: pw.TextStyle(fontSize: 6.8, color: emeraldColor, fontWeight: pw.FontWeight.bold),
                                ),
                              ),
                              pw.SizedBox(
                                width: 56,
                                child: pw.Text(
                                  '- ${_currency.format(s.totalMaterialCost)}',
                                  style: const pw.TextStyle(fontSize: 6.8, color: PdfColors.red800),
                                ),
                              ),
                              pw.SizedBox(width: 44, child: pw.Text('- ${_currency.format(s.vendorCharges)}', style: _tdStyle)),
                              pw.SizedBox(width: 44, child: pw.Text('- ${_currency.format(s.netGstLiability)}', style: _tdStyle)),
                              pw.SizedBox(width: 40, child: pw.Text(_currency.format(s.totalPaidToVendor), style: _tdStyle)),
                              pw.SizedBox(
                                width: 58,
                                child: pw.Text(
                                  _currency.format(s.netSubVendorBalance),
                                  style: pw.TextStyle(
                                    fontSize: 7.0,
                                    fontWeight: pw.FontWeight.bold,
                                    color: s.netSubVendorBalance >= 0 ? emeraldColor : PdfColors.red800,
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

              // Section 2: Consolidated Financial & GST Summary
              _sectionHeader('2. CONSOLIDATED FINANCIAL & STATUTORY GST SUMMARY'),
              pw.Container(
                padding: const pw.EdgeInsets.all(6),
                decoration: pw.BoxDecoration(
                  color: headerBgColor,
                  border: pw.Border.all(color: borderDarkColor, width: 0.8),
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                ),
                child: pw.Column(
                  children: [
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        _subSummary('Site Quotation Base:', _currency.format(summary.totalSiteAmount)),
                        _subSummary('Output GST (70:30):', _currency.format(summary.siteDetails.fold<double>(0.0, (acc, s) => acc + s.assignment.gstBreakdown.totalGstIncluded))),
                        _subSummary('Eligible Input ITC:', '- ${_currency.format(summary.totalEligibleInputGst)}'),
                        _subSummary('Statutory Net GST:', _currency.format(summary.totalNetGstLiability), isBold: true),
                      ],
                    ),
                    pw.Divider(color: borderDarkColor, thickness: 0.4, height: 6),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        _subSummary('Total Realized Collections:', _currency.format(summary.effectiveTotalCollection)),
                        _subSummary('Material Cost:', '- ${_currency.format(summary.totalMaterialCost)}'),
                        _subSummary('SIYA Platform Fee:', '- ${_currency.format(summary.totalVendorCharges)}'),
                        _subSummary('Statutory Net GST:', '- ${_currency.format(summary.totalNetGstLiability)}'),
                        _subSummary('Advances Paid:', '- ${_currency.format(summary.totalPaidAmount)}'),
                        _subSummary(
                          summary.netSettlementPayable >= 0 ? 'Net Sub-Vendor Due:' : 'Amount Recoverable:',
                          _currency.format(summary.netSettlementPayable.abs()),
                          isBold: true,
                        ),
                      ],
                    ),
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

  static pw.Widget _metaRow(String label, String value, {bool isBold = false, PdfColor? valueColor}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 1.5),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: const pw.TextStyle(fontSize: 7, color: slateMutedColor)),
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: 7.2,
              fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
              color: valueColor ?? (isBold ? navyColor : darkTextColor),
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _th(String text, {pw.TextAlign align = pw.TextAlign.left}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: pw.Text(
        text,
        textAlign: align,
        style: pw.TextStyle(
          fontSize: 7,
          fontWeight: pw.FontWeight.bold,
          color: navyColor,
        ),
      ),
    );
  }

  static pw.Widget _td(String text, {bool isBold = false, pw.TextAlign align = pw.TextAlign.left, PdfColor? color}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3.5),
      child: pw.Text(
        text,
        textAlign: align,
        style: pw.TextStyle(
          fontSize: 6.8,
          fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: color ?? (isBold ? navyColor : darkTextColor),
        ),
      ),
    );
  }

  // ============================================================================
  // 3. SITE CUSTOMER PAYMENT & BANK LOAN CREDIT LEDGER STATEMENT PDF
  // ============================================================================

  static Future<Uint8List> generateSitePaymentLedgerPdfBytes({
    required VendorSiteAssignment assignment,
    required List<VendorCustomerPayment> payments,
    SubVendor? vendor,
  }) async {
    final pdfTheme = await SolarQuotationFontHelper.loadPdfTheme();
    final pdf = pw.Document(theme: pdfTheme);

    final siteAmount = assignment.effectiveSiteAmount;
    final cashRecv = assignment.totalCashReceived;
    final loanSanc = assignment.loanSanctionedAmount;
    final loanCred = assignment.totalLoanCredited;
    final loanPend = assignment.loanPendingCredit;
    final totRecv = assignment.effectiveReceivedAmount;
    final outstanding = assignment.effectiveCustomerOutstanding;

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
                          'EPC Solar Installation & Consumer Payment Ledger',
                          style: const pw.TextStyle(fontSize: 7.8, color: slateMutedColor),
                        ),
                        pw.Text(
                          'Betawad, Tal. Shindkheda, Dist. Dhule | Contact: 9673220315',
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
                        'CUSTOMER PAYMENT & LOAN LEDGER',
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

              // Site & Customer Info
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Expanded(
                    child: pw.Container(
                      padding: const pw.EdgeInsets.all(8),
                      decoration: pw.BoxDecoration(
                        border: pw.Border.all(color: borderDarkColor, width: 0.6),
                        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                      ),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('CUSTOMER & SITE DETAILS',
                              style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: navyColor)),
                          pw.SizedBox(height: 3),
                          _metaRow('Customer Name:', assignment.customerName ?? 'N/A', isBold: true),
                          _metaRow('Consumer / CA No:', assignment.consumerNo ?? 'N/A'),
                          _metaRow('Contact / Mobile:', assignment.customerMobile ?? 'N/A'),
                          _metaRow('Site Capacity:', '${assignment.siteCapacityKw} kW'),
                          _metaRow('Site Address:', assignment.customerAddress ?? 'N/A'),
                        ],
                      ),
                    ),
                  ),
                  pw.SizedBox(width: 8),
                  pw.Expanded(
                    child: pw.Container(
                      padding: const pw.EdgeInsets.all(8),
                      decoration: pw.BoxDecoration(
                        border: pw.Border.all(color: borderDarkColor, width: 0.6),
                        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                      ),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('PAYMENT & LOAN SPECIFICATIONS',
                              style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: navyColor)),
                          pw.SizedBox(height: 3),
                          _metaRow('Payment Type:', assignment.paymentType, isBold: true),
                          _metaRow('Sub-Vendor:', '${assignment.vendorCode ?? "VND"} - ${assignment.vendorName ?? "Sub-Vendor"}'),
                          if (assignment.isBankLoan) ...[
                            _metaRow('Loan Bank Name:', assignment.loanBankName ?? 'Not Specified'),
                            _metaRow('Loan App ID / UTR:', assignment.loanApplicationId ?? 'N/A'),
                            _metaRow('Sanctioned Loan:', _currency.format(assignment.loanSanctionedAmount)),
                            _metaRow('Loan Status:', assignment.loanStatus, isBold: true, valueColor: emeraldColor),
                          ] else ...[
                            _metaRow('Payment Status:', assignment.customerPaymentStatus, isBold: true, valueColor: emeraldColor),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              pw.SizedBox(height: 8),

              // KPI Cards Row
              pw.Row(
                children: [
                  _kpiBox('Total Site Amount', _currency.format(siteAmount), navyColor),
                  pw.SizedBox(width: 6),
                  _kpiBox('Cash Received', _currency.format(cashRecv), darkTextColor),
                  pw.SizedBox(width: 6),
                  _kpiBox(
                    'Bank Loan Credited',
                    _currency.format(loanCred),
                    emeraldColor,
                    isHighlight: assignment.isBankLoan,
                  ),
                  pw.SizedBox(width: 6),
                  _kpiBox('Total Received', _currency.format(totRecv), emeraldColor),
                  pw.SizedBox(width: 6),
                  _kpiBox('Customer Balance Due', _currency.format(outstanding), const PdfColor.fromInt(0xFFDC2626)),
                ],
              ),

              if (assignment.isBankLoan && loanPend > 0) ...[
                pw.SizedBox(height: 6),
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: pw.BoxDecoration(
                    color: const PdfColor.fromInt(0xFFFEF3C7),
                    border: pw.Border.all(color: const PdfColor.fromInt(0xFFF59E0B), width: 0.6),
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(3)),
                  ),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(
                        'Bank Loan Sanctioned: ${_currency.format(loanSanc)} | Total Credited: ${_currency.format(loanCred)}',
                        style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: const PdfColor.fromInt(0xFF92400E)),
                      ),
                      pw.Text(
                        'Pending Bank Loan Credit: ${_currency.format(loanPend)}',
                        style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: const PdfColor.fromInt(0xFFB45309)),
                      ),
                    ],
                  ),
                ),
              ],

              pw.SizedBox(height: 10),

              // Section Title
              pw.Text(
                'ITEMIZED TRANSACTION & BANK DISBURSEMENT LEDGER',
                style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: navyColor),
              ),
              pw.SizedBox(height: 4),

              // Ledger Table
              pw.Table(
                border: pw.TableBorder.all(color: borderDarkColor, width: 0.6),
                columnWidths: {
                  0: const pw.FixedColumnWidth(24),
                  1: const pw.FixedColumnWidth(55),
                  2: const pw.FixedColumnWidth(55),
                  3: const pw.FixedColumnWidth(60),
                  4: const pw.FixedColumnWidth(65),
                  5: const pw.FixedColumnWidth(60),
                  6: const pw.FixedColumnWidth(90),
                  7: const pw.FlexColumnWidth(),
                },
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: headerBgColor),
                    children: [
                      _th('#'),
                      _th('Date'),
                      _th('Category'),
                      _th('Stage'),
                      _th('Amount'),
                      _th('Mode'),
                      _th('UTR / Ref No'),
                      _th('Bank / Remarks'),
                    ],
                  ),
                  ...payments.asMap().entries.map((entry) {
                    final idx = entry.key + 1;
                    final p = entry.value;
                    final isBgZebra = idx % 2 == 0;
                    final isLoan = p.isLoan;

                    return pw.TableRow(
                      decoration: pw.BoxDecoration(color: isBgZebra ? zebraBgColor : PdfColors.white),
                      children: [
                        _td('$idx', align: pw.TextAlign.center),
                        _td(_dateFormat.format(p.paymentDate)),
                        _td(isLoan ? 'BANK LOAN' : 'CASH', isBold: true),
                        _td(p.paymentStage),
                        _td(_currency.format(p.amount), isBold: true, align: pw.TextAlign.right),
                        _td(p.paymentMode),
                        _td(p.referenceNumber ?? '-'),
                        _td([
                          if (p.bankName != null && p.bankName!.isNotEmpty) p.bankName,
                          if (p.remarks != null && p.remarks!.isNotEmpty) p.remarks,
                        ].where((s) => s != null).join(' | ')),
                      ],
                    );
                  }).toList(),
                  if (payments.isEmpty)
                    pw.TableRow(
                      children: [
                        pw.Container(
                          padding: const pw.EdgeInsets.all(12),
                          child: pw.Center(
                            child: pw.Text('No payment or loan credit transactions recorded for this site.',
                                style: const pw.TextStyle(fontSize: 8, color: slateMutedColor)),
                          ),
                        ),
                        for (int i = 0; i < 7; i++) pw.Container(),
                      ],
                    ),
                  // Totals Table Footer Row
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: headerBgColor),
                    children: [
                      _td(''),
                      _td('TOTALS', isBold: true),
                      _td(''),
                      _td(''),
                      _td(_currency.format(totRecv), isBold: true, align: pw.TextAlign.right),
                      _td(''),
                      _td(''),
                      _td('Cash: ${_currency.format(cashRecv)} | Loan: ${_currency.format(loanCred)}', isBold: true),
                    ],
                  ),
                ],
              ),

              pw.Spacer(),

              // Certification & Signature Box
              pw.Container(
                padding: const pw.EdgeInsets.all(8),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: borderDarkColor, width: 0.6),
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(3)),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('Authorized Verifier: SIYA INFOTECH & SOLAR ENERGY',
                            style: pw.TextStyle(fontSize: 7.2, fontWeight: pw.FontWeight.bold, color: navyColor)),
                        pw.Text('Generated on ${_dateFormat.format(DateTime.now())} via Siya Data Management Software',
                            style: const pw.TextStyle(fontSize: 6.5, color: slateMutedColor)),
                        pw.Text('All Bank Loan credits are reconciled with official bank credit advice and UTR statements.',
                            style: const pw.TextStyle(fontSize: 6.2, color: slateMutedColor)),
                      ],
                    ),
                    pw.Column(
                      children: [
                        pw.Container(width: 90, height: 25),
                        pw.Container(width: 90, height: 0.6, color: borderDarkColor),
                        pw.SizedBox(height: 2),
                        pw.Text('Authorized Signatory', style: const pw.TextStyle(fontSize: 7, color: slateMutedColor)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  /// Print or share Site Payment Ledger PDF directly
  static Future<void> printOrShareSitePaymentLedger({
    required VendorSiteAssignment assignment,
    required List<VendorCustomerPayment> payments,
    SubVendor? vendor,
  }) async {
    final bytes = await generateSitePaymentLedgerPdfBytes(
      assignment: assignment,
      payments: payments,
      vendor: vendor,
    );
    final safeName = (assignment.customerName ?? 'Site').replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
    await Printing.layoutPdf(
      onLayout: (format) async => bytes,
      name: 'Customer_Payment_Ledger_${safeName}_${assignment.consumerNo ?? "CA"}.pdf',
    );
  }

  // ============================================================================
  // 4. SUB-VENDOR FINAL SETTLEMENT & PAYOUT STATEMENT PDF
  // ============================================================================

  static Future<Uint8List> generateFinalSettlementStatementPdfBytes(
    SubVendorSettlement settlement, {
    SubVendor? vendor,
  }) async {
    final pdfTheme = await SolarQuotationFontHelper.loadPdfTheme();
    final pdf = pw.Document(theme: pdfTheme);

    final s = settlement;
    final isPayable = !s.isRecoverable;
    final primaryBannerColor = isPayable ? emeraldColor : const PdfColor.fromInt(0xFFDC2626);

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
                          'EPC Sub-Vendor Final Settlement & Payout Statement',
                          style: const pw.TextStyle(fontSize: 7.8, color: slateMutedColor),
                        ),
                        pw.Text(
                          'Betawad, Tal. Shindkheda, Dist. Dhule | Contact: 9673220315',
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
                        'FINAL PAYOUT STATEMENT',
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

              // Sub-Vendor & Site Details
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Expanded(
                    child: pw.Container(
                      padding: const pw.EdgeInsets.all(8),
                      decoration: pw.BoxDecoration(
                        border: pw.Border.all(color: borderDarkColor, width: 0.6),
                        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                      ),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('SUB-VENDOR INFORMATION',
                              style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: navyColor)),
                          pw.SizedBox(height: 3),
                          _metaRow('Vendor Name:', s.vendorName ?? vendor?.name ?? 'Sub-Vendor', isBold: true),
                          _metaRow('Vendor Code:', s.vendorCode ?? vendor?.vendorCode ?? 'VND'),
                          _metaRow('Settlement Mode:', s.settlementMode.code, isBold: true),
                          _metaRow('Statement Date:', _dateFormat.format(s.calculationDate)),
                          _metaRow('Approval Status:', s.isApproved ? 'Approved by Admin' : 'Draft / Pending', isBold: true, valueColor: s.isApproved ? emeraldColor : const PdfColor.fromInt(0xFFD97706)),
                        ],
                      ),
                    ),
                  ),
                  pw.SizedBox(width: 8),
                  pw.Expanded(
                    child: pw.Container(
                      padding: const pw.EdgeInsets.all(8),
                      decoration: pw.BoxDecoration(
                        border: pw.Border.all(color: borderDarkColor, width: 0.6),
                        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                      ),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('CUSTOMER SITE SPECIFICATIONS',
                              style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: navyColor)),
                          pw.SizedBox(height: 3),
                          _metaRow('Customer Name:', s.customerName ?? 'Site Customer', isBold: true),
                          _metaRow('Consumer / CA No:', s.consumerNo ?? 'CA-N/A'),
                          _metaRow('Installed Capacity:', '${s.siteCapacityKw} kW'),
                          _metaRow('Total Site Quotation:', _currency.format(s.totalQuotation), isBold: true),
                          _metaRow('Actual Collections:', _currency.format(s.totalActualCollected), valueColor: emeraldColor),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              pw.SizedBox(height: 8),

              // Comprehensive Settlement Ledger Table
              pw.Table(
                border: pw.TableBorder.all(color: borderDarkColor, width: 0.6),
                columnWidths: {
                  0: const pw.FixedColumnWidth(28),
                  1: const pw.FlexColumnWidth(3),
                  2: const pw.FlexColumnWidth(1.2),
                  3: const pw.FlexColumnWidth(1.2),
                },
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: headerBgColor),
                    children: [
                      _th('#'),
                      _th('FINANCIAL COMPONENT & AUDIT BREAKDOWN'),
                      _th('CREDIT (INR)', align: pw.TextAlign.right),
                      _th('DEBIT (INR)', align: pw.TextAlign.right),
                    ],
                  ),

                  // Section 1: Collections
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: zebraBgColor),
                    children: [
                      _td('1', align: pw.TextAlign.center),
                      _td('Total Actual Customer & Bank Loan Collections Credited to SIYA', isBold: true),
                      _td(_currency.format(s.totalActualCollected), isBold: true, align: pw.TextAlign.right),
                      _td('-'),
                    ],
                  ),
                  pw.TableRow(
                    children: [
                      _td(''),
                      _td('  - Actual Bank Loan Credited to SIYA (Expected 90%: ${_currency.format(s.expectedLoanAmount)})'),
                      _td(_currency.format(s.actualLoanCredited), align: pw.TextAlign.right),
                      _td('-'),
                    ],
                  ),
                  pw.TableRow(
                    children: [
                      _td(''),
                      _td(s.isMarginReceiptOnly
                          ? '  - 10% Margin Money: Paper Receipt Only for Bank (No Customer Cash Collection) -> Rs. 0.00'
                          : '  - Actual Customer Contribution / Advance (Expected 10%: ${_currency.format(s.loanDifferenceAmount)})'),
                      _td(s.isMarginReceiptOnly ? 'Rs. 0.00' : _currency.format(s.actualCustomerContribution), align: pw.TextAlign.right),
                      _td('-'),
                    ],
                  ),

                  // Section 2: Statutory Net GST (No Double Deduction)
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: zebraBgColor),
                    children: [
                      _td('2', align: pw.TextAlign.center),
                      _td(
                        s.use7030GstRule
                            ? 'Net GST Payable to Govt (70:30 Output GST ${_currency.format(s.outputGstLiability)} on Quotation ${_currency.format(s.totalQuotation)} [Goods 5%: ${_currency.format(s.goodsGst5)} + Services 18%: ${_currency.format(s.servicesGst18)}] - Eligible Material Input Credit ${_currency.format(s.eligibleInputGstCredit)})'
                            : 'Net GST Payable to Govt (Output GST ${_currency.format(s.outputGstLiability)} on Quotation ${_currency.format(s.totalQuotation)} - Eligible Material Input Credit ${_currency.format(s.eligibleInputGstCredit)})',
                        isBold: true,
                      ),
                      _td('-'),
                      _td(_currency.format(s.netGstLiability), isBold: true, align: pw.TextAlign.right),
                    ],
                  ),

                  // Section 3: Dynamic Material Costs
                  pw.TableRow(
                    children: [
                      _td('3', align: pw.TextAlign.center),
                      _td('Actual Dynamic Material Costs (Panels, Inverters & BOS issued minus returns)', isBold: true),
                      _td('-'),
                      _td(_currency.format(s.materialCost), isBold: true, align: pw.TextAlign.right),
                    ],
                  ),

                  // Section 4: SIYA Vendor Charges
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: zebraBgColor),
                    children: [
                      _td('4', align: pw.TextAlign.center),
                      _td('SIYA Company Vendor Charges (${s.siteCapacityKw} kW × Rs. 1,000/kW)', isBold: true),
                      _td('-'),
                      _td(_currency.format(s.siyaVendorCharges), isBold: true, align: pw.TextAlign.right),
                    ],
                  ),

                  // Section 5: Other Approved Expenses
                  pw.TableRow(
                    children: [
                      _td('5', align: pw.TextAlign.center),
                      _td('Other Approved Company / Site Operational Expenses'),
                      _td('-'),
                      _td(_currency.format(s.otherApprovedExpenses), align: pw.TextAlign.right),
                    ],
                  ),

                  // Section 6: Gross Sub-Vendor Entitlement
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: headerBgColor),
                    children: [
                      _td('6', align: pw.TextAlign.center),
                      _td('SUB-VENDOR GROSS CONTRACTUAL ENTITLEMENT (${s.settlementMode.code})', isBold: true),
                      _td(_currency.format(s.subVendorGrossEntitlement), isBold: true, align: pw.TextAlign.right),
                      _td('-'),
                    ],
                  ),

                  // Section 7: Previous Advances & Disbursements
                  pw.TableRow(
                    children: [
                      _td('7', align: pw.TextAlign.center),
                      _td('Previous Advances / Partial Payouts Already Paid to Sub-Vendor'),
                      _td('-'),
                      _td(_currency.format(s.previousPayoutsPaid), align: pw.TextAlign.right),
                    ],
                  ),

                  // Section 8: Approved Adjustments
                  if (s.approvedAdjustments.abs() > 0.01)
                    pw.TableRow(
                      decoration: const pw.BoxDecoration(color: zebraBgColor),
                      children: [
                        _td('8', align: pw.TextAlign.center),
                        _td('Approved Adjustments: ${s.adjustmentRemarks ?? "Adjustments"}'),
                        _td(s.approvedAdjustments > 0 ? _currency.format(s.approvedAdjustments) : '-', align: pw.TextAlign.right),
                        _td(s.approvedAdjustments < 0 ? _currency.format(s.approvedAdjustments.abs()) : '-', align: pw.TextAlign.right),
                      ],
                    ),
                ],
              ),

              pw.SizedBox(height: 8),

              // PROMINENT FINAL AMOUNT BANNER
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: pw.BoxDecoration(
                  color: primaryBannerColor,
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          isPayable
                              ? 'FINAL AMOUNT PAYABLE TO SUB-VENDOR'
                              : 'AMOUNT RECOVERABLE FROM SUB-VENDOR',
                          style: pw.TextStyle(
                            color: PdfColors.white,
                            fontSize: 10,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        pw.SizedBox(height: 2),
                        pw.Text(
                          'Calculated strictly from actual realized collections | Admin authorization required',
                          style: const pw.TextStyle(color: PdfColors.white, fontSize: 6.8),
                        ),
                      ],
                    ),
                    pw.Text(
                      _currency.format(isPayable ? s.amountPayableToVendor : s.amountRecoverableFromVendor),
                      style: pw.TextStyle(
                        color: PdfColors.white,
                        fontSize: 16,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),

              // Pending Receivables Information Note or Full Settlement Banner
              if (s.pendingCustomerReceivable > 0) ...[
                pw.SizedBox(height: 6),
                pw.Container(
                  padding: const pw.EdgeInsets.all(6),
                  decoration: pw.BoxDecoration(
                    color: const PdfColor.fromInt(0xFFFEF3C7),
                    border: pw.Border.all(color: const PdfColor.fromInt(0xFFF59E0B), width: 0.6),
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(3)),
                  ),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(
                        'Pending Customer/Bank Balance: ${_currency.format(s.pendingCustomerReceivable)} (10% Difference: ${_currency.format(s.pendingCustomerContribution)} | Loan: ${_currency.format(s.pendingLoanDisbursement)})',
                        style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold, color: const PdfColor.fromInt(0xFF92400E)),
                      ),
                      pw.Text(
                        'Potential Full Payout: ${_currency.format(s.potentialFuturePayoutUponFullCollection)}',
                        style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: const PdfColor.fromInt(0xFFB45309)),
                      ),
                    ],
                  ),
                ),
              ] else if (s.isMarginReceiptOnly) ...[
                pw.SizedBox(height: 6),
                pw.Container(
                  padding: const pw.EdgeInsets.all(6),
                  decoration: pw.BoxDecoration(
                    color: const PdfColor.fromInt(0xFFECFDF5),
                    border: pw.Border.all(color: const PdfColor.fromInt(0xFFA7F3D0), width: 0.6),
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(3)),
                  ),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(
                        'Bank Loan Fully Realized | 10% Margin Money is Bank Paper Receipt Only (No pending customer debt | Fully Settled)',
                        style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold, color: const PdfColor.fromInt(0xFF065F46)),
                      ),
                      pw.Text(
                        'Final Realized Settlement: ${_currency.format(s.amountPayableToVendor)}',
                        style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: const PdfColor.fromInt(0xFF065F46)),
                      ),
                    ],
                  ),
                ),
              ],

              pw.Spacer(),

              // Signatures & Approval Block
              pw.Container(
                padding: const pw.EdgeInsets.all(8),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: borderDarkColor, width: 0.6),
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(3)),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('Sub-Vendor Acceptance & Acknowledgment',
                            style: const pw.TextStyle(fontSize: 7, color: slateMutedColor)),
                        pw.SizedBox(height: 20),
                        pw.Text(s.vendorName ?? vendor?.name ?? 'Sub-Vendor Partner',
                            style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold)),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.center,
                      children: [
                        pw.Text('Accounts Department Verification',
                            style: const pw.TextStyle(fontSize: 7, color: slateMutedColor)),
                        pw.SizedBox(height: 20),
                        pw.Text('SIYA Accounts & Tax Division',
                            style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold)),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text('SIYA Management Approval',
                            style: const pw.TextStyle(fontSize: 7, color: slateMutedColor)),
                        pw.SizedBox(height: 20),
                        pw.Text('Siya Infotech & Solar Energy',
                            style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: navyColor)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  /// Print or share Final Settlement Statement PDF directly
  static Future<void> printOrShareFinalSettlementStatement(
    SubVendorSettlement settlement, {
    SubVendor? vendor,
  }) async {
    final bytes = await generateFinalSettlementStatementPdfBytes(
      settlement,
      vendor: vendor,
    );
    final safeName = (settlement.customerName ?? 'Site').replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
    await Printing.layoutPdf(
      onLayout: (format) async => bytes,
      name: 'Sub_Vendor_Final_Settlement_${safeName}_${settlement.consumerNo ?? "CA"}.pdf',
    );
  }

  // ============================================================================
  // 5. SUB-VENDOR FULL CHRONOLOGICAL ACCOUNT LEDGER PDF (WITH DATES, DEBIT & CREDIT)
  // ============================================================================

  static Future<Uint8List> generateVendorFullChronologicalLedgerPdfBytes({
    required SubVendorLedgerSummary summary,
    SubVendor? vendor,
  }) async {
    final pdfTheme = await SolarQuotationFontHelper.loadPdfTheme();
    final pdf = pw.Document(theme: pdfTheme);

    final isPayable = summary.isPayable;
    final primaryBannerColor = isPayable ? emeraldColor : const PdfColor.fromInt(0xFFDC2626);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 22, vertical: 18),
        header: (context) {
          return pw.Container(
            margin: const pw.EdgeInsets.only(bottom: 6),
            padding: const pw.EdgeInsets.all(8),
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
                        fontSize: 13,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.Text(
                      'Sub-Vendor Partner Financial Account Statement & Chronological Ledger',
                      style: const pw.TextStyle(fontSize: 7.2, color: slateMutedColor),
                    ),
                    pw.Text(
                      'Betawad, Tal. Shindkheda, Dist. Dhule | Contact: 9673220315',
                      style: const pw.TextStyle(fontSize: 6.8, color: slateMutedColor),
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
                    'TRANSACTION LEDGER',
                    style: pw.TextStyle(
                      color: PdfColors.white,
                      fontSize: 8,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
        footer: (context) {
          return pw.Container(
            margin: const pw.EdgeInsets.only(top: 6),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'Siya Data Management System | Confidential Sub-Vendor Account Ledger',
                  style: const pw.TextStyle(fontSize: 6.5, color: slateMutedColor),
                ),
                pw.Text(
                  'Page ${context.pageNumber} of ${context.pagesCount}',
                  style: const pw.TextStyle(fontSize: 6.8, color: slateMutedColor),
                ),
              ],
            ),
          );
        },
        build: (context) {
          return [
            // Vendor KYC & Account Information
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(
                  flex: 3,
                  child: pw.Container(
                    padding: const pw.EdgeInsets.all(6),
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: borderDarkColor, width: 0.6),
                      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(3)),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('SUB-VENDOR DETAILS', style: pw.TextStyle(fontSize: 7.2, fontWeight: pw.FontWeight.bold, color: navyColor)),
                        pw.Divider(color: borderDarkColor, thickness: 0.4, height: 4),
                        _infoRow('Vendor Name:', summary.vendorName),
                        _infoRow('Vendor Code:', summary.vendorCode),
                        _infoRow('Mobile No.:', vendor?.mobile ?? '-'),
                        _infoRow('Bank & A/C:', '${vendor?.bankName ?? "-"} | ${vendor?.accountNumber ?? "-"}'),
                        _infoRow('IFSC Code:', vendor?.ifscCode ?? '-'),
                      ],
                    ),
                  ),
                ),
                pw.SizedBox(width: 6),
                pw.Expanded(
                  flex: 2,
                  child: pw.Container(
                    padding: const pw.EdgeInsets.all(6),
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: borderDarkColor, width: 0.6),
                      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(3)),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('STATEMENT PERIOD & SUMMARY', style: pw.TextStyle(fontSize: 7.2, fontWeight: pw.FontWeight.bold, color: navyColor)),
                        pw.Divider(color: borderDarkColor, thickness: 0.4, height: 4),
                        _infoRow('Generated On:', _dateFormat.format(DateTime.now())),
                        _infoRow('Total Entries:', '${summary.entries.length} Transactions'),
                        _infoRow('Total Credits (Deposit):', _currency.format(summary.totalCredit)),
                        _infoRow('Total Debits (Deductions):', '- ${_currency.format(summary.totalDebit)}'),
                        _infoRow(
                          isPayable ? 'Net Payable Balance:' : 'Net Recoverable:',
                          _currency.format(summary.closingBalance.abs()),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            pw.SizedBox(height: 6),

            // Prominent Closing Balance Banner
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: pw.BoxDecoration(
                color: primaryBannerColor,
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(3)),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    isPayable
                        ? 'FINAL OUTSTANDING NET BALANCE PAYABLE TO SUB-VENDOR:'
                        : 'NET AMOUNT RECOVERABLE FROM SUB-VENDOR:',
                    style: pw.TextStyle(
                      color: PdfColors.white,
                      fontSize: 8.5,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.Text(
                    _currency.format(summary.closingBalance.abs()),
                    style: pw.TextStyle(
                      color: PdfColors.white,
                      fontSize: 12,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),

            pw.SizedBox(height: 6),

            // Chronological Ledger Table
            pw.Table(
              border: pw.TableBorder.all(color: borderDarkColor, width: 0.5),
              columnWidths: {
                0: const pw.FixedColumnWidth(18), // #
                1: const pw.FixedColumnWidth(48), // Date
                2: const pw.FixedColumnWidth(68), // Voucher Type
                3: const pw.FlexColumnWidth(3.2), // Particulars
                4: const pw.FixedColumnWidth(48), // Ref / UTR
                5: const pw.FixedColumnWidth(54), // Debit
                6: const pw.FixedColumnWidth(54), // Credit
                7: const pw.FixedColumnWidth(58), // Balance
              },
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: headerBgColor),
                  children: [
                    _th('#'),
                    _th('DATE'),
                    _th('VOUCHER TYPE'),
                    _th('PARTICULARS & TRANSACTION DETAILS'),
                    _th('REF / UTR'),
                    _th('DEBIT (Rs.)', align: pw.TextAlign.right),
                    _th('CREDIT (Rs.)', align: pw.TextAlign.right),
                    _th('BALANCE (Rs.)', align: pw.TextAlign.right),
                  ],
                ),
                if (summary.entries.isEmpty)
                  pw.TableRow(
                    children: [
                      _td('-'),
                      _td('-'),
                      _td('-'),
                      _td('No financial ledger transactions recorded for this vendor.'),
                      _td('-'),
                      _td('-'),
                      _td('-'),
                      _td('-'),
                    ],
                  )
                else
                  ...summary.entries.asMap().entries.map((entry) {
                    final i = entry.key;
                    final tx = entry.value;
                    final isZebra = i % 2 == 1;
                    return pw.TableRow(
                      decoration: pw.BoxDecoration(color: isZebra ? zebraBgColor : PdfColors.white),
                      children: [
                        _td('${i + 1}', align: pw.TextAlign.center),
                        _td(_dateFormat.format(tx.date)),
                        _td(tx.voucherType),
                        _td(tx.particulars, isBold: tx.isCredit),
                        _td(tx.referenceNo ?? '-'),
                        _td(
                          tx.debit > 0 ? _currency.format(tx.debit) : '-',
                          align: pw.TextAlign.right,
                          color: tx.debit > 0 ? PdfColors.red800 : null,
                        ),
                        _td(
                          tx.credit > 0 ? _currency.format(tx.credit) : '-',
                          align: pw.TextAlign.right,
                          color: tx.credit > 0 ? emeraldColor : null,
                          isBold: tx.credit > 0,
                        ),
                        _td(
                          _currency.format(tx.runningBalance),
                          align: pw.TextAlign.right,
                          isBold: true,
                          color: tx.runningBalance >= 0 ? emeraldColor : PdfColors.red800,
                        ),
                      ],
                    );
                  }),
                // Total Summary Row
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: headerBgColor),
                  children: [
                    _td(''),
                    _td(''),
                    _td(''),
                    _td('TOTALS & CLOSING NET BALANCE', isBold: true),
                    _td(''),
                    _td(_currency.format(summary.totalDebit), isBold: true, align: pw.TextAlign.right, color: PdfColors.red800),
                    _td(_currency.format(summary.totalCredit), isBold: true, align: pw.TextAlign.right, color: emeraldColor),
                    _td(
                      _currency.format(summary.closingBalance),
                      isBold: true,
                      align: pw.TextAlign.right,
                      color: summary.closingBalance >= 0 ? emeraldColor : PdfColors.red800,
                    ),
                  ],
                ),
              ],
            ),

            pw.SizedBox(height: 8),

            // Compliance & Statutory Note
            pw.Container(
              padding: const pw.EdgeInsets.all(5),
              decoration: pw.BoxDecoration(
                color: const PdfColor.fromInt(0xFFF8FAFC),
                border: pw.Border.all(color: borderDarkColor, width: 0.5),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(3)),
              ),
              child: pw.Row(
                children: [
                  pw.Expanded(
                    child: pw.Text(
                      'Accounting Notes: 1. Customer Collections include Bank Loans and Cash credited to SIYA. 2. Dynamic Material issued is debited net of returns. 3. Statutory Net GST liability is computed under Notification No. 24/2018 (70:30 Split on site quotation minus eligible material ITC). 4. 10% Loan Margin Paper Receipt is bank-processing compliance only and is excluded from cash calculation.',
                      style: const pw.TextStyle(fontSize: 6.2, color: slateMutedColor),
                    ),
                  ),
                ],
              ),
            ),

            pw.SizedBox(height: 12),

            // Signatures Block
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Container(width: 130, height: 0.8, color: borderDarkColor),
                    pw.SizedBox(height: 2),
                    pw.Text('Sub-Vendor Acceptance & Sign', style: const pw.TextStyle(fontSize: 6.8, color: slateMutedColor)),
                    pw.Text(summary.vendorName, style: pw.TextStyle(fontSize: 7.2, fontWeight: pw.FontWeight.bold)),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    pw.Container(width: 130, height: 0.8, color: borderDarkColor),
                    pw.SizedBox(height: 2),
                    pw.Text('Accounts Verification', style: const pw.TextStyle(fontSize: 6.8, color: slateMutedColor)),
                    pw.Text('SIYA Accounts & Tax Division', style: pw.TextStyle(fontSize: 7.2, fontWeight: pw.FontWeight.bold)),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Container(width: 130, height: 0.8, color: borderDarkColor),
                    pw.SizedBox(height: 2),
                    pw.Text('Authorized Signatory & Stamp', style: const pw.TextStyle(fontSize: 6.8, color: slateMutedColor)),
                    pw.Text('Siya Infotech & Solar Energy', style: pw.TextStyle(fontSize: 7.2, fontWeight: pw.FontWeight.bold, color: navyColor)),
                  ],
                ),
              ],
            ),
          ];
        },
      ),
    );

    return pdf.save();
  }

  /// Print or share Sub-Vendor Full Chronological Ledger PDF directly
  static Future<void> printOrShareSubVendorFullLedger({
    required SubVendorLedgerSummary summary,
    SubVendor? vendor,
  }) async {
    final bytes = await generateVendorFullChronologicalLedgerPdfBytes(
      summary: summary,
      vendor: vendor,
    );
    final safeName = summary.vendorName.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
    await Printing.layoutPdf(
      onLayout: (format) async => bytes,
      name: 'Sub_Vendor_Full_Ledger_${safeName}_${summary.vendorCode}.pdf',
    );
  }
}
