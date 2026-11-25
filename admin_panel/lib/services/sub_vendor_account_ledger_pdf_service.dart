import 'dart:convert';
import 'dart:typed_data';
import 'package:csv/csv.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:siya_shared/siya_shared.dart';
import '../utils/universal_file_saver.dart';
import 'solar_quotation_font_helper.dart';

/// PDF Statement Generation & Excel/CSV Export for Sub-Vendor Account Ledger.
class SubVendorAccountLedgerPdfService {
  static const PdfColor navyColor = PdfColor.fromInt(0xFF0D2B6F);
  static const PdfColor greenColor = PdfColor.fromInt(0xFF059669);
  static const PdfColor amberColor = PdfColor.fromInt(0xFFD97706);
  static const PdfColor redColor = PdfColor.fromInt(0xFFDC2626);
  static const PdfColor slateDark = PdfColor.fromInt(0xFF0F172A);
  static const PdfColor slateBody = PdfColor.fromInt(0xFF334155);
  static const PdfColor slateLight = PdfColor.fromInt(0xFFF8FAFC);
  static const PdfColor borderGray = PdfColor.fromInt(0xFFCBD5E1);

  static final _currency = NumberFormat.currency(locale: 'en_IN', symbol: 'Rs. ', decimalDigits: 2);
  static final _dateFormat = DateFormat('dd-MM-yyyy');

  // ============================================================================
  // 1. SUB-VENDOR ACCOUNT STATEMENT PDF (PASSBOOK / LEDGER FORMAT)
  // ============================================================================
  static Future<Uint8List> generateAccountStatementPdfBytes({
    required SubVendor vendor,
    required List<SubVendorAccountLedgerEntry> entries,
    double openingBalance = 0.0,
    required double totalCredit,
    required double totalDebit,
    required double closingBalance,
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    final pdfTheme = await SolarQuotationFontHelper.loadPdfTheme();
    final pdf = pw.Document(theme: pdfTheme);

    final activeEntries = entries.where((e) => e.isActive).toList()
      ..sort((a, b) => a.transactionDate.compareTo(b.transactionDate));

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        header: (context) => _buildStatementHeader(vendor, fromDate, toDate),
        footer: (context) => _buildStatementFooter(context),
        build: (context) {
          return [
            pw.SizedBox(height: 10),
            // Financial KPI Cards
            pw.Row(
              children: [
                _buildKpiCard('Total Credit (येणे)', _currency.format(totalCredit), greenColor),
                pw.SizedBox(width: 8),
                _buildKpiCard('Total Debit (देणे)', _currency.format(totalDebit), amberColor),
                pw.SizedBox(width: 8),
                _buildKpiCard(
                  'Closing Balance',
                  '${_currency.format(closingBalance.abs())} ${closingBalance >= 0 ? "Cr (येणे)" : "Dr (देणे)"}',
                  closingBalance >= 0 ? greenColor : redColor,
                ),
              ],
            ),
            pw.SizedBox(height: 14),

            // Ledger Table
            pw.Table(
              border: pw.TableBorder.all(color: borderGray, width: 0.5),
              columnWidths: {
                0: const pw.FlexColumnWidth(1.2), // Date
                1: const pw.FlexColumnWidth(1.4), // Ref No
                2: const pw.FlexColumnWidth(3.0), // Particulars
                3: const pw.FlexColumnWidth(1.1), // Mode
                4: const pw.FlexColumnWidth(1.5), // Credit
                5: const pw.FlexColumnWidth(1.5), // Debit
                6: const pw.FlexColumnWidth(1.6), // Running Balance
              },
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: navyColor),
                  children: [
                    _buildCell('Date', isHeader: true, color: PdfColors.white, align: pw.TextAlign.center),
                    _buildCell('Ref / Entry No', isHeader: true, color: PdfColors.white),
                    _buildCell('Transaction Particulars', isHeader: true, color: PdfColors.white),
                    _buildCell('Mode', isHeader: true, color: PdfColors.white, align: pw.TextAlign.center),
                    _buildCell('Credit (Rs.)', isHeader: true, color: PdfColors.white, align: pw.TextAlign.right),
                    _buildCell('Debit (Rs.)', isHeader: true, color: PdfColors.white, align: pw.TextAlign.right),
                    _buildCell('Balance (Rs.)', isHeader: true, color: PdfColors.white, align: pw.TextAlign.right),
                  ],
                ),
                // Opening Balance Row
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey100),
                  children: [
                    _buildCell('-', align: pw.TextAlign.center),
                    _buildCell('OP-BAL'),
                    _buildCell('Opening Balance Brought Forward', isHeader: true),
                    _buildCell('-', align: pw.TextAlign.center),
                    _buildCell('-', align: pw.TextAlign.right),
                    _buildCell('-', align: pw.TextAlign.right),
                    _buildCell(_currency.format(openingBalance), isHeader: true, align: pw.TextAlign.right),
                  ],
                ),
                // Transaction Rows
                ...activeEntries.map((e) {
                  return pw.TableRow(
                    children: [
                      _buildCell(_dateFormat.format(e.transactionDate), align: pw.TextAlign.center),
                      _buildCell(e.referenceNumber),
                      _buildCell(e.particulars),
                      _buildCell(e.paymentMode, align: pw.TextAlign.center),
                      _buildCell(e.creditAmount > 0 ? _currency.format(e.creditAmount) : '-', align: pw.TextAlign.right, color: greenColor),
                      _buildCell(e.debitAmount > 0 ? _currency.format(e.debitAmount) : '-', align: pw.TextAlign.right, color: amberColor),
                      _buildCell('${_currency.format(e.runningBalance.abs())} ${e.runningBalance >= 0 ? "Cr" : "Dr"}', isHeader: true, align: pw.TextAlign.right),
                    ],
                  );
                }),
                // Total Summary Row
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                  children: [
                    _buildCell(''),
                    _buildCell(''),
                    _buildCell('TOTAL TRANSACTIONS: ${activeEntries.length}', isHeader: true),
                    _buildCell(''),
                    _buildCell(_currency.format(totalCredit), isHeader: true, align: pw.TextAlign.right, color: greenColor),
                    _buildCell(_currency.format(totalDebit), isHeader: true, align: pw.TextAlign.right, color: amberColor),
                    _buildCell(_currency.format(closingBalance), isHeader: true, align: pw.TextAlign.right, color: navyColor),
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

  // ============================================================================
  // 2. EXCEL / CSV EXPORT
  // ============================================================================
  static Future<void> exportVendorLedgerCsv({
    required SubVendor vendor,
    required List<SubVendorAccountLedgerEntry> entries,
    required double totalCredit,
    required double totalDebit,
    required double closingBalance,
  }) async {
    final rows = <List<dynamic>>[
      ['SUB VENDOR ACCOUNT LEDGER STATEMENT'],
      ['Sub Vendor Name', vendor.name],
      ['Vendor Code', vendor.vendorCode],
      ['Mobile', vendor.mobile],
      ['Date', 'Reference / Entry No', 'Particulars', 'Category', 'Payment Mode', 'Credit (Receivable)', 'Debit (Payable)', 'Running Balance', 'Status', 'Remarks'],
    ];

    for (final e in entries) {
      rows.add([
        _dateFormat.format(e.transactionDate),
        e.referenceNumber,
        e.particulars,
        e.category,
        e.paymentMode,
        e.creditAmount > 0 ? e.creditAmount : 0.0,
        e.debitAmount > 0 ? e.debitAmount : 0.0,
        e.runningBalance,
        e.status,
        e.remarks ?? '',
      ]);
    }

    rows.add([]);
    rows.add(['TOTAL CREDIT', totalCredit]);
    rows.add(['TOTAL DEBIT', totalDebit]);
    rows.add(['NET OUTSTANDING BALANCE', closingBalance]);

    final csvString = const ListToCsvConverter().convert(rows);
    final fileName = 'Ledger_${vendor.vendorCode}_${DateFormat('yyyyMMdd').format(DateTime.now())}.csv';
    await saveFileUniversal(bytes: Uint8List.fromList(utf8.encode(csvString)), fileName: fileName);
  }

  static Future<void> exportDashboardSummaryCsv(SubVendorDashboardMetrics metrics) async {
    final rows = <List<dynamic>>[
      ['SIYA INFOTECH - SUB VENDOR ACCOUNT DASHBOARD SUMMARY'],
      ['Total Credit (Receivable)', metrics.totalCredit],
      ['Total Debit (Payable)', metrics.totalDebit],
      ['Net Outstanding Balance', metrics.netBalance],
      ['Total Material Outward Value', metrics.totalMaterialOutwardValue],
      ['Total Material Payments Received', metrics.totalMaterialPaymentsReceived],
      ['Net Material Receivable', metrics.netMaterialReceivable],
      ['Total Advance Given', metrics.totalAdvanceGiven],
      ['Total Advance Refund Received', metrics.totalAdvanceRefundReceived],
      ['Net Advance Balance', metrics.netAdvanceBalance],
      [],
      ['Vendor Code', 'Sub Vendor Name', 'Total Credit', 'Total Debit', 'Net Balance', 'Material Receivable', 'Advance Balance', 'Transactions Count', 'Last Activity Date'],
    ];

    for (final v in metrics.vendorBalances) {
      rows.add([
        v.vendorCode,
        v.vendorName,
        v.totalCredit,
        v.totalDebit,
        v.netBalance,
        v.materialReceivable,
        v.advanceBalance,
        v.totalTransactions,
        v.lastTransactionDate != null ? _dateFormat.format(v.lastTransactionDate!) : '-',
      ]);
    }

    final csvString = const ListToCsvConverter().convert(rows);
    final fileName = 'Sub_Vendor_Dashboard_Summary_${DateFormat('yyyyMMdd').format(DateTime.now())}.csv';
    await saveFileUniversal(bytes: Uint8List.fromList(utf8.encode(csvString)), fileName: fileName);
  }

  // ============================================================================
  // HELPER WIDGETS
  // ============================================================================
  static pw.Widget _buildStatementHeader(SubVendor vendor, DateTime? fromDate, DateTime? toDate) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(bottom: 8),
      decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: borderGray, width: 1.2))),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('SIYA INFOTECH & SOLAR ENERGY', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 13, color: navyColor)),
              pw.Text('Sub Vendor Account Ledger Statement', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11, color: greenColor)),
              pw.SizedBox(height: 2),
              pw.Text('Vendor: ${vendor.name} (${vendor.vendorCode}) | Mob: ${vendor.mobile}', style: const pw.TextStyle(fontSize: 9, color: slateDark)),
            ],
          ),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text('Statement Period:', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
              pw.Text(
                '${fromDate != null ? _dateFormat.format(fromDate) : "Opening"} to ${toDate != null ? _dateFormat.format(toDate) : "Present"}',
                style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: navyColor),
              ),
              pw.Text('Generated: ${_dateFormat.format(DateTime.now())}', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey500)),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildStatementFooter(pw.Context context) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(top: 8),
      padding: const pw.EdgeInsets.only(top: 4),
      decoration: const pw.BoxDecoration(border: pw.Border(top: pw.BorderSide(color: borderGray, width: 0.5))),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text('Siya Solar ERP • Certified Double-Entry Account Statement', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey500)),
          pw.Text('Page ${context.pageNumber} of ${context.pagesCount}', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey500)),
        ],
      ),
    );
  }

  static pw.Widget _buildKpiCard(String label, String value, PdfColor color) {
    return pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.all(8),
        decoration: pw.BoxDecoration(
          color: slateLight,
          border: pw.Border.all(color: borderGray, width: 0.6),
          borderRadius: pw.BorderRadius.circular(4),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(label, style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
            pw.SizedBox(height: 2),
            pw.Text(value, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11, color: color)),
          ],
        ),
      ),
    );
  }

  static pw.Widget _buildCell(
    String text, {
    bool isHeader = false,
    pw.TextAlign align = pw.TextAlign.left,
    PdfColor? color,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 4),
      child: pw.Text(
        text,
        textAlign: align,
        style: pw.TextStyle(
          fontSize: isHeader ? 8.5 : 8,
          fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: color ?? (isHeader ? slateDark : slateBody),
        ),
      ),
    );
  }
}
