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

/// PDF Generation and Excel/CSV Export Service for Sub-Vendor Material Outward Tracking.
class SubVendorMaterialOutwardPdfService {
  static const PdfColor navyColor = PdfColor.fromInt(0xFF0D2B6F);
  static const PdfColor greenColor = PdfColor.fromInt(0xFF059669);
  static const PdfColor amberColor = PdfColor.fromInt(0xFFD97706);
  static const PdfColor slateDark = PdfColor.fromInt(0xFF0F172A);
  static const PdfColor slateBody = PdfColor.fromInt(0xFF334155);
  static const PdfColor slateLight = PdfColor.fromInt(0xFFF8FAFC);
  static const PdfColor borderGray = PdfColor.fromInt(0xFFCBD5E1);

  static final _dateFormat = DateFormat('dd-MM-yyyy');

  // ============================================================================
  // 1. MATERIAL OUTWARD DELIVERY CHALLAN / DISPATCH SLIP (SINGLE ENTRY)
  // ============================================================================
  static Future<Uint8List> generateOutwardSlipPdfBytes(SubVendorMaterialOutward outward) async {
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
              // Header
              pw.Container(
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  color: navyColor,
                  borderRadius: pw.BorderRadius.circular(6),
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
                            color: PdfColors.white,
                            fontSize: 16,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        pw.SizedBox(height: 3),
                        pw.Text(
                          'Solar EPC & Government Rooftop Installation Projects',
                          style: const pw.TextStyle(color: PdfColors.grey200, fontSize: 10),
                        ),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text(
                          'MATERIAL OUTWARD SLIP',
                          style: pw.TextStyle(
                            color: PdfColors.amber,
                            fontSize: 13,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        pw.SizedBox(height: 3),
                        pw.Text(
                          'Challan No: ${outward.outwardNumber}',
                          style: pw.TextStyle(color: PdfColors.white, fontSize: 10, fontWeight: pw.FontWeight.bold),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              pw.SizedBox(height: 14),

              // Transaction Info Grid
              pw.Container(
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  color: slateLight,
                  border: pw.Border.all(color: borderGray, width: 0.8),
                  borderRadius: pw.BorderRadius.circular(4),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        _buildInfoLabel('ISSUED TO SUB-VENDOR:', outward.vendorName, isBold: true),
                        _buildInfoLabel('OUTWARD ENTRY NO:', outward.outwardNumber),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        _buildInfoLabel('DISPATCH DATE:', _dateFormat.format(outward.outwardDate)),
                        _buildInfoLabel('STATUS:', outward.status.toUpperCase(), color: outward.isActive ? greenColor : PdfColors.red),
                      ],
                    ),
                  ],
                ),
              ),

              if (outward.remarks != null && outward.remarks!.isNotEmpty) ...[
                pw.SizedBox(height: 8),
                pw.Container(
                  padding: const pw.EdgeInsets.all(8),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.grey100,
                    border: pw.Border.all(color: borderGray, width: 0.5),
                    borderRadius: pw.BorderRadius.circular(4),
                  ),
                  child: pw.Text('Remarks: ${outward.remarks}', style: const pw.TextStyle(fontSize: 10, color: slateBody)),
                ),
              ],

              pw.SizedBox(height: 14),

              // Table Title
              pw.Text('ISSUED MATERIAL DETAILS', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11, color: navyColor)),
              pw.SizedBox(height: 6),

              // Items Table
              pw.Table(
                border: pw.TableBorder.all(color: borderGray, width: 0.6),
                columnWidths: {
                  0: const pw.FixedColumnWidth(22),
                  1: const pw.FlexColumnWidth(2.8),
                  2: const pw.FlexColumnWidth(0.8),
                  3: const pw.FlexColumnWidth(0.7),
                  4: const pw.FlexColumnWidth(1.0),
                  5: const pw.FlexColumnWidth(1.1),
                  6: const pw.FlexColumnWidth(0.7),
                  7: const pw.FlexColumnWidth(1.0),
                  8: const pw.FlexColumnWidth(1.2),
                },
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                    children: [
                      _buildTableCell('#', isHeader: true, align: pw.TextAlign.center),
                      _buildTableCell('Material Description', isHeader: true),
                      _buildTableCell('Qty', isHeader: true, align: pw.TextAlign.right),
                      _buildTableCell('Unit', isHeader: true, align: pw.TextAlign.center),
                      _buildTableCell('Rate', isHeader: true, align: pw.TextAlign.right),
                      _buildTableCell('Base Amt', isHeader: true, align: pw.TextAlign.right),
                      _buildTableCell('GST %', isHeader: true, align: pw.TextAlign.center),
                      _buildTableCell('GST Amt', isHeader: true, align: pw.TextAlign.right),
                      _buildTableCell('Final Price', isHeader: true, align: pw.TextAlign.right),
                    ],
                  ),
                  ...outward.items.asMap().entries.map((entry) {
                    final idx = entry.key + 1;
                    final item = entry.value;
                    final rowCalc = SubVendorFinancialEngine.calculateOutwardRow(
                      quantity: item.quantity,
                      ratePerUnit: item.unitRate,
                      gstPercentage: item.gstPercentage,
                    );
                    return pw.TableRow(
                      decoration: pw.BoxDecoration(color: idx.isEven ? slateLight : PdfColors.white),
                      children: [
                        _buildTableCell(idx.toString(), align: pw.TextAlign.center),
                        _buildTableCell(item.materialName),
                        _buildTableCell(item.quantity.toStringAsFixed(2), align: pw.TextAlign.right),
                        _buildTableCell(item.unit, align: pw.TextAlign.center),
                        _buildTableCell(rowCalc.ratePerUnit.toStringAsFixed(2), align: pw.TextAlign.right),
                        _buildTableCell(rowCalc.baseAmount.toStringAsFixed(2), align: pw.TextAlign.right),
                        _buildTableCell('${rowCalc.gstPercentage.toStringAsFixed(0)}%', align: pw.TextAlign.center),
                        _buildTableCell(rowCalc.gstAmount.toStringAsFixed(2), align: pw.TextAlign.right),
                        _buildTableCell(rowCalc.finalAmount.toStringAsFixed(2), align: pw.TextAlign.right),
                      ],
                    );
                  }),
                  // Total Row (aligned directly under Base Amt, GST Amt & Final Price columns)
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.grey100),
                    children: [
                      _buildTableCell(''),
                      _buildTableCell('TOTAL (${outward.totalItems} Items)', isHeader: true),
                      _buildTableCell(outward.totalQuantity.toStringAsFixed(2), isHeader: true, align: pw.TextAlign.right),
                      _buildTableCell(''),
                      _buildTableCell('Totals:', isHeader: true, align: pw.TextAlign.right),
                      _buildTableCell(outward.subtotal.toStringAsFixed(2), isHeader: true, align: pw.TextAlign.right),
                      _buildTableCell(''),
                      _buildTableCell(outward.totalGst.toStringAsFixed(2), isHeader: true, align: pw.TextAlign.right),
                      _buildTableCell(outward.totalValue.toStringAsFixed(2), isHeader: true, align: pw.TextAlign.right),
                    ],
                  ),
                ],
              ),

              pw.SizedBox(height: 10),
              pw.Align(
                alignment: pw.Alignment.centerRight,
                child: pw.Container(
                  width: 220,
                  padding: const pw.EdgeInsets.all(8),
                  decoration: pw.BoxDecoration(
                    color: slateLight,
                    border: pw.Border.all(color: borderGray, width: 0.6),
                    borderRadius: pw.BorderRadius.circular(4),
                  ),
                  child: pw.Column(
                    children: [
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text('Subtotal:', style: const pw.TextStyle(fontSize: 9, color: slateBody)),
                          pw.Text('Rs. ${outward.subtotal.toStringAsFixed(2)}', style: const pw.TextStyle(fontSize: 9, color: slateBody)),
                        ],
                      ),
                      pw.SizedBox(height: 2),
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text('Total GST:', style: const pw.TextStyle(fontSize: 9, color: slateBody)),
                          pw.Text('Rs. ${outward.totalGst.toStringAsFixed(2)}', style: const pw.TextStyle(fontSize: 9, color: slateBody)),
                        ],
                      ),
                      pw.Divider(height: 6, color: borderGray),
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text('Grand Total:', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: navyColor)),
                          pw.Text('Rs. ${outward.totalValue.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: greenColor)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              pw.Spacer(),

              // Signatures Section
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      pw.Container(width: 140, height: 1, color: borderGray),
                      pw.SizedBox(height: 4),
                      pw.Text('Receiver Sub-Vendor Signature', style: const pw.TextStyle(fontSize: 9, color: slateBody)),
                      pw.Text('(${outward.vendorName})', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      pw.Container(width: 140, height: 1, color: borderGray),
                      pw.SizedBox(height: 4),
                      pw.Text('Authorized Dispatcher Signature', style: const pw.TextStyle(fontSize: 9, color: slateBody)),
                      pw.Text('For SIYA INFOTECH & SOLAR ENERGY', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 10),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  // ============================================================================
  // 2. REPORT A: DATE-WISE MATERIAL OUTWARD REPORT PDF (WITH FULL MONETARY AMOUNTS)
  // ============================================================================
  static Future<Uint8List> generateDateWiseReportPdfBytes(List<SubVendorMaterialOutward> entries) async {
    final pdfTheme = await SolarQuotationFontHelper.loadPdfTheme();
    final pdf = pw.Document(theme: pdfTheme);
    final activeEntries = entries.where((e) => e.isActive).toList();
    final totalQty = SubVendorFinancialEngine.sumPaise(activeEntries, (e) => e.totalQuantity);
    final totalSub = SubVendorFinancialEngine.sumPaise(activeEntries, (e) => e.subtotal);
    final totalGst = SubVendorFinancialEngine.sumPaise(activeEntries, (e) => e.totalGst);
    final totalVal = SubVendorFinancialEngine.sumPaise(activeEntries, (e) => e.totalValue);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        header: (context) => _buildReportHeader('DATE-WISE MATERIAL OUTWARD REPORT', 'Chronological dispatch log with Base Amount, GST, and Final Value'),
        footer: (context) => _buildReportFooter(context),
        build: (context) {
          return [
            pw.SizedBox(height: 10),
            _buildReportKpis([
              {'label': 'Total Entries', 'value': activeEntries.length.toString()},
              {'label': 'Total Qty', 'value': totalQty.toStringAsFixed(2)},
              {'label': 'Subtotal (Base)', 'value': 'Rs. ${totalSub.toStringAsFixed(2)}'},
              {'label': 'Total GST', 'value': 'Rs. ${totalGst.toStringAsFixed(2)}'},
              {'label': 'Grand Total', 'value': 'Rs. ${totalVal.toStringAsFixed(2)}'},
            ]),
            pw.SizedBox(height: 12),
            pw.Table(
              border: pw.TableBorder.all(color: borderGray, width: 0.5),
              columnWidths: {
                0: const pw.FixedColumnWidth(20),
                1: const pw.FlexColumnWidth(1.3),
                2: const pw.FlexColumnWidth(1.0),
                3: const pw.FlexColumnWidth(1.7),
                4: const pw.FlexColumnWidth(2.0),
                5: const pw.FlexColumnWidth(0.8),
                6: const pw.FlexColumnWidth(0.9),
                7: const pw.FlexColumnWidth(1.0),
                8: const pw.FlexColumnWidth(0.9),
                9: const pw.FlexColumnWidth(1.1),
              },
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: navyColor),
                  children: [
                    _buildTableCell('#', isHeader: true, color: PdfColors.white, align: pw.TextAlign.center),
                    _buildTableCell('Outward No', isHeader: true, color: PdfColors.white),
                    _buildTableCell('Date', isHeader: true, color: PdfColors.white, align: pw.TextAlign.center),
                    _buildTableCell('Sub Vendor', isHeader: true, color: PdfColors.white),
                    _buildTableCell('Material Name', isHeader: true, color: PdfColors.white),
                    _buildTableCell('Qty', isHeader: true, color: PdfColors.white, align: pw.TextAlign.right),
                    _buildTableCell('Base (Rs.)', isHeader: true, color: PdfColors.white, align: pw.TextAlign.right),
                    _buildTableCell('GST %', isHeader: true, color: PdfColors.white, align: pw.TextAlign.center),
                    _buildTableCell('GST (Rs.)', isHeader: true, color: PdfColors.white, align: pw.TextAlign.right),
                    _buildTableCell('Total (Rs.)', isHeader: true, color: PdfColors.white, align: pw.TextAlign.right),
                  ],
                ),
                ...activeEntries.expand((e) {
                  return e.items.map((item) {
                    final calc = SubVendorFinancialEngine.calculateOutwardRow(
                      quantity: item.quantity,
                      ratePerUnit: item.unitRate,
                      gstPercentage: item.gstPercentage,
                    );
                    return {
                      'outward_number': e.outwardNumber,
                      'date': _dateFormat.format(e.outwardDate),
                      'vendor': e.vendorName,
                      'material': '${item.materialName} (${item.unit})',
                      'qty': item.quantity.toStringAsFixed(2),
                      'base': calc.baseAmount.toStringAsFixed(2),
                      'gst_pct': '${calc.gstPercentage.toStringAsFixed(0)}%',
                      'gst_amt': calc.gstAmount.toStringAsFixed(2),
                      'total': calc.finalAmount.toStringAsFixed(2),
                    };
                  });
                }).toList().asMap().entries.map((entry) {
                  final idx = entry.key + 1;
                  final r = entry.value;
                  return pw.TableRow(
                    decoration: pw.BoxDecoration(color: idx.isEven ? slateLight : PdfColors.white),
                    children: [
                      _buildTableCell(idx.toString(), align: pw.TextAlign.center),
                      _buildTableCell(r['outward_number']!),
                      _buildTableCell(r['date']!, align: pw.TextAlign.center),
                      _buildTableCell(r['vendor']!),
                      _buildTableCell(r['material']!),
                      _buildTableCell(r['qty']!, align: pw.TextAlign.right),
                      _buildTableCell(r['base']!, align: pw.TextAlign.right),
                      _buildTableCell(r['gst_pct']!, align: pw.TextAlign.center),
                      _buildTableCell(r['gst_amt']!, align: pw.TextAlign.right),
                      _buildTableCell(r['total']!, align: pw.TextAlign.right),
                    ],
                  );
                }),
              ],
            ),
          ];
        },
      ),
    );

    return pdf.save();
  }

  // ============================================================================
  // 3. REPORT B: SUB VENDOR-WISE REPORT PDF
  // ============================================================================
  static Future<Uint8List> generateSubVendorWiseReportPdfBytes(List<Map<String, dynamic>> vendorSummaries) async {
    final pdfTheme = await SolarQuotationFontHelper.loadPdfTheme();
    final pdf = pw.Document(theme: pdfTheme);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        header: (context) => _buildReportHeader('SUB VENDOR-WISE MATERIAL ISSUE REPORT', 'Summary & financial breakdown of materials dispatched per Sub-Vendor'),
        footer: (context) => _buildReportFooter(context),
        build: (context) {
          return [
            pw.SizedBox(height: 10),
            ...vendorSummaries.map((v) {
              final vendorName = v['vendor_name'] as String;
              final totalOutwards = v['total_outwards'] as int;
              final totalQty = (v['total_quantity'] as num).toDouble();
              final totalSub = (v['total_subtotal'] as num?)?.toDouble() ?? 0.0;
              final totalGst = (v['total_gst'] as num?)?.toDouble() ?? 0.0;
              final totalVal = (v['total_value'] as num?)?.toDouble() ?? 0.0;
              final matSummary = v['materials_summary'] as Map<String, double>;
              final matValSummary = (v['materials_value_summary'] as Map<String, double>?) ?? const {};

              return pw.Container(
                margin: const pw.EdgeInsets.only(bottom: 14),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: borderGray, width: 0.8),
                  borderRadius: pw.BorderRadius.circular(6),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: const pw.BoxDecoration(
                        color: slateLight,
                        borderRadius: pw.BorderRadius.only(topLeft: pw.Radius.circular(5), topRight: pw.Radius.circular(5)),
                      ),
                      child: pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text(vendorName, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11, color: navyColor)),
                          pw.Text(
                            'Outwards: $totalOutwards | Qty: ${totalQty.toStringAsFixed(2)} | Sub: Rs. ${totalSub.toStringAsFixed(2)} | GST: Rs. ${totalGst.toStringAsFixed(2)} | Total: Rs. ${totalVal.toStringAsFixed(2)}',
                            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9, color: greenColor),
                          ),
                        ],
                      ),
                    ),
                    pw.Table(
                      border: pw.TableBorder.all(color: borderGray, width: 0.4),
                      columnWidths: {
                        0: const pw.FlexColumnWidth(3.5),
                        1: const pw.FlexColumnWidth(1.5),
                        2: const pw.FlexColumnWidth(2.0),
                      },
                      children: [
                        pw.TableRow(
                          decoration: const pw.BoxDecoration(color: PdfColors.grey100),
                          children: [
                            _buildTableCell('Material Issued', isHeader: true),
                            _buildTableCell('Total Quantity', isHeader: true, align: pw.TextAlign.right),
                            _buildTableCell('Total Value (Rs.)', isHeader: true, align: pw.TextAlign.right),
                          ],
                        ),
                        ...matSummary.entries.map((m) {
                          final val = matValSummary[m.key] ?? 0.0;
                          return pw.TableRow(
                            children: [
                              _buildTableCell(m.key),
                              _buildTableCell(m.value.toStringAsFixed(2), align: pw.TextAlign.right),
                              _buildTableCell(val.toStringAsFixed(2), align: pw.TextAlign.right),
                            ],
                          );
                        }),
                      ],
                    ),
                  ],
                ),
              );
            }),
          ];
        },
      ),
    );

    return pdf.save();
  }

  // ============================================================================
  // 4. REPORT C: MATERIAL-WISE REPORT PDF
  // ============================================================================
  static Future<Uint8List> generateMaterialWiseReportPdfBytes(List<Map<String, dynamic>> materialSummaries) async {
    final pdfTheme = await SolarQuotationFontHelper.loadPdfTheme();
    final pdf = pw.Document(theme: pdfTheme);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        header: (context) => _buildReportHeader('MATERIAL-WISE OUTWARD DISTRIBUTION REPORT', 'Total quantity and rupee value issued per material'),
        footer: (context) => _buildReportFooter(context),
        build: (context) {
          return [
            pw.SizedBox(height: 10),
            ...materialSummaries.map((m) {
              final matName = m['material_name'] as String;
              final unit = m['unit'] as String;
              final totalQty = (m['total_quantity'] as num).toDouble();
              final totalVal = (m['total_value'] as num?)?.toDouble() ?? 0.0;
              final vBreakdown = m['vendor_breakdown'] as Map<String, double>;
              final vValBreakdown = (m['vendor_value_breakdown'] as Map<String, double>?) ?? const {};

              return pw.Container(
                margin: const pw.EdgeInsets.only(bottom: 12),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: borderGray, width: 0.8),
                  borderRadius: pw.BorderRadius.circular(6),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: const pw.BoxDecoration(
                        color: slateLight,
                        borderRadius: pw.BorderRadius.only(topLeft: pw.Radius.circular(5), topRight: pw.Radius.circular(5)),
                      ),
                      child: pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text(matName, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11, color: navyColor)),
                          pw.Text('Issued: ${totalQty.toStringAsFixed(2)} $unit | Value: Rs. ${totalVal.toStringAsFixed(2)}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9.5, color: amberColor)),
                        ],
                      ),
                    ),
                    pw.Table(
                      border: pw.TableBorder.all(color: borderGray, width: 0.4),
                      columnWidths: {
                        0: const pw.FlexColumnWidth(3.5),
                        1: const pw.FlexColumnWidth(1.5),
                        2: const pw.FlexColumnWidth(2.0),
                      },
                      children: [
                        pw.TableRow(
                          decoration: const pw.BoxDecoration(color: PdfColors.grey100),
                          children: [
                            _buildTableCell('Sub Vendor Receiver', isHeader: true),
                            _buildTableCell('Quantity ($unit)', isHeader: true, align: pw.TextAlign.right),
                            _buildTableCell('Value (Rs.)', isHeader: true, align: pw.TextAlign.right),
                          ],
                        ),
                        ...vBreakdown.entries.map((v) {
                          final val = vValBreakdown[v.key] ?? 0.0;
                          return pw.TableRow(
                            children: [
                              _buildTableCell(v.key),
                              _buildTableCell(v.value.toStringAsFixed(2), align: pw.TextAlign.right),
                              _buildTableCell(val.toStringAsFixed(2), align: pw.TextAlign.right),
                            ],
                          );
                        }),
                      ],
                    ),
                  ],
                ),
              );
            }),
          ];
        },
      ),
    );

    return pdf.save();
  }

  /// REPORT D: DAILY / MONTHLY / FINANCIAL YEAR RECONCILIATION PDF
  static Future<Uint8List> generatePeriodReportPdfBytes(
    List<PeriodReconciliationSummary> periods, {
    required String grouping,
  }) async {
    final pdfTheme = await SolarQuotationFontHelper.loadPdfTheme();
    final pdf = pw.Document(theme: pdfTheme);
    final totalSub = SubVendorFinancialEngine.sumPaise(periods, (p) => p.subtotal);
    final totalGst = SubVendorFinancialEngine.sumPaise(periods, (p) => p.totalGst);
    final totalGrand = SubVendorFinancialEngine.sumPaise(periods, (p) => p.grandTotal);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        header: (context) => _buildReportHeader('PERIOD MATERIAL OUTWARD SUMMARY ($grouping)', 'Reconciled Subtotal, GST & Grand Total breakdown'),
        footer: (context) => _buildReportFooter(context),
        build: (context) => [
          pw.SizedBox(height: 10),
          _buildReportKpis([
            {'label': 'Periods', 'value': periods.length.toString()},
            {'label': 'Subtotal', 'value': 'Rs. ${totalSub.toStringAsFixed(2)}'},
            {'label': 'Total GST', 'value': 'Rs. ${totalGst.toStringAsFixed(2)}'},
            {'label': 'Grand Total', 'value': 'Rs. ${totalGrand.toStringAsFixed(2)}'},
          ]),
          pw.SizedBox(height: 12),
          pw.Table(
            border: pw.TableBorder.all(color: borderGray, width: 0.5),
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: navyColor),
                children: [
                  _buildTableCell('Period', isHeader: true, color: PdfColors.white),
                  _buildTableCell('Entries', isHeader: true, color: PdfColors.white, align: pw.TextAlign.right),
                  _buildTableCell('Qty', isHeader: true, color: PdfColors.white, align: pw.TextAlign.right),
                  _buildTableCell('Subtotal (Rs.)', isHeader: true, color: PdfColors.white, align: pw.TextAlign.right),
                  _buildTableCell('GST (Rs.)', isHeader: true, color: PdfColors.white, align: pw.TextAlign.right),
                  _buildTableCell('Grand Total (Rs.)', isHeader: true, color: PdfColors.white, align: pw.TextAlign.right),
                ],
              ),
              ...periods.map((p) => pw.TableRow(children: [
                    _buildTableCell(p.periodLabel),
                    _buildTableCell('${p.entryCount}', align: pw.TextAlign.right),
                    _buildTableCell(p.totalQuantity.toStringAsFixed(2), align: pw.TextAlign.right),
                    _buildTableCell(p.subtotal.toStringAsFixed(2), align: pw.TextAlign.right),
                    _buildTableCell(p.totalGst.toStringAsFixed(2), align: pw.TextAlign.right),
                    _buildTableCell(p.grandTotal.toStringAsFixed(2), align: pw.TextAlign.right, isHeader: true),
                  ])),
            ],
          ),
        ],
      ),
    );
    return pdf.save();
  }

  // ============================================================================
  // 5. EXCEL / CSV EXPORT UTILITIES (WITH MONETARY FIELDS)
  // ============================================================================

  /// Exports Date-wise Report to CSV with complete monetary columns.
  static Future<void> exportDateWiseReportCsv(List<SubVendorMaterialOutward> entries) async {
    final rows = <List<dynamic>>[
      ['Outward Number', 'Date', 'Sub Vendor Name', 'Material Name', 'Unit', 'Quantity', 'Rate (INR)', 'Base Amount (INR)', 'GST %', 'GST Amount (INR)', 'Final Amount (INR)', 'Remarks'],
    ];

    for (final e in entries.where((e) => e.isActive)) {
      for (final item in e.items) {
        final calc = SubVendorFinancialEngine.calculateOutwardRow(
          quantity: item.quantity,
          ratePerUnit: item.unitRate,
          gstPercentage: item.gstPercentage,
        );
        rows.add([
          e.outwardNumber,
          _dateFormat.format(e.outwardDate),
          e.vendorName,
          item.materialName,
          item.unit,
          item.quantity,
          calc.ratePerUnit,
          calc.baseAmount,
          calc.gstPercentage,
          calc.gstAmount,
          calc.finalAmount,
          e.remarks ?? '',
        ]);
      }
    }

    final csvString = const ListToCsvConverter().convert(rows);
    final fileName = 'Date_Wise_Material_Outward_Report_${DateFormat('yyyyMMdd').format(DateTime.now())}.csv';
    await saveFileUniversal(bytes: Uint8List.fromList(utf8.encode(csvString)), fileName: fileName);
  }

  /// Exports Sub Vendor-wise Summary to CSV with Subtotal, GST, Grand Total.
  static Future<void> exportSubVendorWiseReportCsv(List<Map<String, dynamic>> summaries) async {
    final rows = <List<dynamic>>[
      ['Sub Vendor Name', 'Total Outward Entries', 'Total Quantity Issued', 'Subtotal (INR)', 'Total GST (INR)', 'Grand Total (INR)', 'Material Details Summary'],
    ];

    for (final v in summaries) {
      final matSummary = (v['materials_summary'] as Map<String, double>)
          .entries
          .map((e) => '${e.key}: ${e.value}')
          .join('; ');

      rows.add([
        v['vendor_name'],
        v['total_outwards'],
        v['total_quantity'],
        (v['total_subtotal'] as num?)?.toDouble() ?? 0.0,
        (v['total_gst'] as num?)?.toDouble() ?? 0.0,
        (v['total_value'] as num?)?.toDouble() ?? 0.0,
        matSummary,
      ]);
    }

    final csvString = const ListToCsvConverter().convert(rows);
    final fileName = 'Sub_Vendor_Wise_Material_Report_${DateFormat('yyyyMMdd').format(DateTime.now())}.csv';
    await saveFileUniversal(bytes: Uint8List.fromList(utf8.encode(csvString)), fileName: fileName);
  }

  /// Exports Material-wise Summary to CSV with Taxable, GST & Grand Total.
  static Future<void> exportMaterialWiseReportCsv(List<Map<String, dynamic>> summaries) async {
    final rows = <List<dynamic>>[
      ['Material Name', 'Unit', 'Total Quantity Issued', 'Taxable Value (INR)', 'Total GST (INR)', 'Grand Total (INR)', 'Sub Vendor Breakdown'],
    ];

    for (final m in summaries) {
      final vBreakdown = (m['vendor_breakdown'] as Map<String, double>)
          .entries
          .map((e) => '${e.key}: ${e.value}')
          .join('; ');

      rows.add([
        m['material_name'],
        m['unit'],
        m['total_quantity'],
        (m['total_taxable'] as num?)?.toDouble() ?? 0.0,
        (m['total_gst'] as num?)?.toDouble() ?? 0.0,
        (m['total_value'] as num?)?.toDouble() ?? 0.0,
        vBreakdown,
      ]);
    }

    final csvString = const ListToCsvConverter().convert(rows);
    final fileName = 'Material_Wise_Outward_Report_${DateFormat('yyyyMMdd').format(DateTime.now())}.csv';
    await saveFileUniversal(bytes: Uint8List.fromList(utf8.encode(csvString)), fileName: fileName);
  }

  static Future<void> exportPeriodReportCsv(
    List<PeriodReconciliationSummary> periods, {
    required String grouping,
  }) async {
    final rows = <List<dynamic>>[
      ['Period ($grouping)', 'Outward Entries', 'Total Quantity', 'Subtotal (INR)', 'Total GST (INR)', 'Grand Total (INR)'],
      ...periods.map((p) => [p.periodLabel, p.entryCount, p.totalQuantity, p.subtotal, p.totalGst, p.grandTotal]),
    ];
    final csvString = const ListToCsvConverter().convert(rows);
    final fileName = 'Period_Material_Outward_${grouping}_${DateFormat('yyyyMMdd').format(DateTime.now())}.csv';
    await saveFileUniversal(bytes: Uint8List.fromList(utf8.encode(csvString)), fileName: fileName);
  }

  // ============================================================================
  // HELPER WIDGETS
  // ============================================================================
  static pw.Widget _buildInfoLabel(String label, String value, {bool isBold = false, PdfColor? color}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.RichText(
        text: pw.TextSpan(
          children: [
            pw.TextSpan(text: '$label ', style: const pw.TextStyle(color: PdfColors.grey700, fontSize: 9)),
            pw.TextSpan(
              text: value,
              style: pw.TextStyle(
                fontSize: 10,
                fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
                color: color ?? slateDark,
              ),
            ),
          ],
        ),
      ),
    );
  }

  static pw.Widget _buildTableCell(
    String text, {
    bool isHeader = false,
    pw.TextAlign align = pw.TextAlign.left,
    PdfColor? color,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
      child: pw.Text(
        text,
        textAlign: align,
        style: pw.TextStyle(
          fontSize: isHeader ? 9 : 8.5,
          fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: color ?? (isHeader ? slateDark : slateBody),
        ),
      ),
    );
  }

  static pw.Widget _buildReportHeader(String title, String subtitle) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(bottom: 8),
      decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: borderGray, width: 1))),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('SIYA INFOTECH & SOLAR ENERGY', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 13, color: navyColor)),
              pw.Text(title, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10, color: greenColor)),
            ],
          ),
          pw.Text(subtitle, style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
        ],
      ),
    );
  }

  static pw.Widget _buildReportFooter(pw.Context context) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(top: 8),
      padding: const pw.EdgeInsets.only(top: 4),
      decoration: const pw.BoxDecoration(border: pw.Border(top: pw.BorderSide(color: borderGray, width: 0.5))),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text('Siya Solar ERP • Confidential Internal Material Outward Record', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey500)),
          pw.Text('Page ${context.pageNumber} of ${context.pagesCount}', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey500)),
        ],
      ),
    );
  }

  static pw.Widget _buildReportKpis(List<Map<String, String>> kpis) {
    return pw.Row(
      children: kpis.map((k) {
        return pw.Expanded(
          child: pw.Container(
            margin: const pw.EdgeInsets.symmetric(horizontal: 4),
            padding: const pw.EdgeInsets.all(6),
            decoration: pw.BoxDecoration(
              color: slateLight,
              border: pw.Border.all(color: borderGray, width: 0.6),
              borderRadius: pw.BorderRadius.circular(4),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(k['label']!, style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
                pw.SizedBox(height: 2),
                pw.Text(k['value']!, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11, color: navyColor)),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}
