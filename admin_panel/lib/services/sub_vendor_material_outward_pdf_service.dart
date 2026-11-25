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
                  0: const pw.FixedColumnWidth(24),
                  1: const pw.FlexColumnWidth(3.2),
                  2: const pw.FlexColumnWidth(0.9),
                  3: const pw.FlexColumnWidth(0.8),
                  4: const pw.FlexColumnWidth(1.2),
                  5: const pw.FlexColumnWidth(0.8),
                  6: const pw.FlexColumnWidth(1.1),
                  7: const pw.FlexColumnWidth(1.3),
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
                      _buildTableCell('GST %', isHeader: true, align: pw.TextAlign.center),
                      _buildTableCell('GST Amt', isHeader: true, align: pw.TextAlign.right),
                      _buildTableCell('Final Price', isHeader: true, align: pw.TextAlign.right),
                    ],
                  ),
                  ...outward.items.asMap().entries.map((entry) {
                    final idx = entry.key + 1;
                    final item = entry.value;
                    return pw.TableRow(
                      decoration: pw.BoxDecoration(color: idx.isEven ? slateLight : PdfColors.white),
                      children: [
                        _buildTableCell(idx.toString(), align: pw.TextAlign.center),
                        _buildTableCell(item.materialName),
                        _buildTableCell(item.quantity.toStringAsFixed(2), align: pw.TextAlign.right),
                        _buildTableCell(item.unit, align: pw.TextAlign.center),
                        _buildTableCell(item.unitRate.toStringAsFixed(2), align: pw.TextAlign.right),
                        _buildTableCell('${item.gstPercentage.toStringAsFixed(0)}%', align: pw.TextAlign.center),
                        _buildTableCell(item.gstAmount.toStringAsFixed(2), align: pw.TextAlign.right),
                        _buildTableCell(item.totalPrice.toStringAsFixed(2), align: pw.TextAlign.right),
                      ],
                    );
                  }),
                  // Total Row
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.grey100),
                    children: [
                      _buildTableCell(''),
                      _buildTableCell('TOTAL (${outward.totalItems} Items)', isHeader: true),
                      _buildTableCell(outward.totalQuantity.toStringAsFixed(2), isHeader: true, align: pw.TextAlign.right),
                      _buildTableCell(''),
                      _buildTableCell('Subtotal:', isHeader: true, align: pw.TextAlign.right),
                      _buildTableCell(outward.subtotal.toStringAsFixed(2), isHeader: true, align: pw.TextAlign.right),
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
  // 2. REPORT A: DATE-WISE MATERIAL OUTWARD REPORT PDF
  // ============================================================================
  static Future<Uint8List> generateDateWiseReportPdfBytes(List<SubVendorMaterialOutward> entries) async {
    final pdfTheme = await SolarQuotationFontHelper.loadPdfTheme();
    final pdf = pw.Document(theme: pdfTheme);
    final activeEntries = entries.where((e) => e.isActive).toList();
    final totalQty = activeEntries.fold(0.0, (sum, e) => sum + e.totalQuantity);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        header: (context) => _buildReportHeader('DATE-WISE MATERIAL OUTWARD REPORT', 'Chronological log of materials issued to Sub-Vendors'),
        footer: (context) => _buildReportFooter(context),
        build: (context) {
          return [
            pw.SizedBox(height: 10),
            _buildReportKpis([
              {'label': 'Total Entries', 'value': activeEntries.length.toString()},
              {'label': 'Total Qty Issued', 'value': totalQty.toStringAsFixed(1)},
              {'label': 'Report Generated', 'value': _dateFormat.format(DateTime.now())},
            ]),
            pw.SizedBox(height: 14),
            pw.Table(
              border: pw.TableBorder.all(color: borderGray, width: 0.5),
              columnWidths: {
                0: const pw.FixedColumnWidth(24),
                1: const pw.FlexColumnWidth(1.4),
                2: const pw.FlexColumnWidth(1.2),
                3: const pw.FlexColumnWidth(2.2),
                4: const pw.FlexColumnWidth(2.6),
                5: const pw.FlexColumnWidth(1.0),
                6: const pw.FlexColumnWidth(1.0),
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
                    _buildTableCell('Unit', isHeader: true, color: PdfColors.white, align: pw.TextAlign.center),
                    _buildTableCell('Qty', isHeader: true, color: PdfColors.white, align: pw.TextAlign.right),
                  ],
                ),
                ...activeEntries.expand((e) {
                  return e.items.map((item) => {
                    'outward_number': e.outwardNumber,
                    'date': _dateFormat.format(e.outwardDate),
                    'vendor': e.vendorName,
                    'material': item.materialName,
                    'unit': item.unit,
                    'qty': item.quantity.toStringAsFixed(1),
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
                      _buildTableCell(r['unit']!, align: pw.TextAlign.center),
                      _buildTableCell(r['qty']!, align: pw.TextAlign.right),
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
        header: (context) => _buildReportHeader('SUB VENDOR-WISE MATERIAL ISSUE REPORT', 'Summary & material breakdown of all materials dispatched per Sub-Vendor'),
        footer: (context) => _buildReportFooter(context),
        build: (context) {
          return [
            pw.SizedBox(height: 10),
            ...vendorSummaries.map((v) {
              final vendorName = v['vendor_name'] as String;
              final totalOutwards = v['total_outwards'] as int;
              final totalQty = (v['total_quantity'] as num).toDouble();
              final matSummary = v['materials_summary'] as Map<String, double>;

              return pw.Container(
                margin: const pw.EdgeInsets.only(bottom: 14),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: borderGray, width: 0.8),
                  borderRadius: pw.BorderRadius.circular(6),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    // Vendor Banner
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
                          pw.Text('Outwards: $totalOutwards | Total Qty: ${totalQty.toStringAsFixed(1)}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10, color: greenColor)),
                        ],
                      ),
                    ),
                    // Material Breakdown Table
                    pw.Table(
                      border: pw.TableBorder.all(color: borderGray, width: 0.4),
                      columnWidths: {
                        0: const pw.FlexColumnWidth(4),
                        1: const pw.FlexColumnWidth(2),
                      },
                      children: [
                        pw.TableRow(
                          decoration: const pw.BoxDecoration(color: PdfColors.grey100),
                          children: [
                            _buildTableCell('Material Issued', isHeader: true),
                            _buildTableCell('Total Quantity', isHeader: true, align: pw.TextAlign.right),
                          ],
                        ),
                        ...matSummary.entries.map((m) {
                          return pw.TableRow(
                            children: [
                              _buildTableCell(m.key),
                              _buildTableCell(m.value.toStringAsFixed(1), align: pw.TextAlign.right),
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
        header: (context) => _buildReportHeader('MATERIAL-WISE OUTWARD DISTRIBUTION REPORT', 'Total quantity issued per material with Sub-Vendor breakdown'),
        footer: (context) => _buildReportFooter(context),
        build: (context) {
          return [
            pw.SizedBox(height: 10),
            ...materialSummaries.map((m) {
              final matName = m['material_name'] as String;
              final unit = m['unit'] as String;
              final totalQty = (m['total_quantity'] as num).toDouble();
              final vBreakdown = m['vendor_breakdown'] as Map<String, double>;

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
                          pw.Text('Total Issued: ${totalQty.toStringAsFixed(1)} $unit', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10, color: amberColor)),
                        ],
                      ),
                    ),
                    pw.Table(
                      border: pw.TableBorder.all(color: borderGray, width: 0.4),
                      columnWidths: {
                        0: const pw.FlexColumnWidth(4),
                        1: const pw.FlexColumnWidth(2),
                      },
                      children: [
                        pw.TableRow(
                          decoration: const pw.BoxDecoration(color: PdfColors.grey100),
                          children: [
                            _buildTableCell('Sub Vendor Receiver', isHeader: true),
                            _buildTableCell('Quantity ($unit)', isHeader: true, align: pw.TextAlign.right),
                          ],
                        ),
                        ...vBreakdown.entries.map((v) {
                          return pw.TableRow(
                            children: [
                              _buildTableCell(v.key),
                              _buildTableCell(v.value.toStringAsFixed(1), align: pw.TextAlign.right),
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
  // 5. EXCEL / CSV EXPORT UTILITIES
  // ============================================================================

  /// Exports Date-wise Report to CSV and downloads file.
  static Future<void> exportDateWiseReportCsv(List<SubVendorMaterialOutward> entries) async {
    final rows = <List<dynamic>>[
      ['Outward Number', 'Date', 'Sub Vendor Name', 'Material Name', 'Unit', 'Quantity', 'Remarks'],
    ];

    for (final e in entries.where((e) => e.isActive)) {
      for (final item in e.items) {
        rows.add([
          e.outwardNumber,
          _dateFormat.format(e.outwardDate),
          e.vendorName,
          item.materialName,
          item.unit,
          item.quantity,
          e.remarks ?? '',
        ]);
      }
    }

    final csvString = const ListToCsvConverter().convert(rows);
    final fileName = 'Date_Wise_Material_Outward_Report_${DateFormat('yyyyMMdd').format(DateTime.now())}.csv';
    await saveFileUniversal(bytes: Uint8List.fromList(utf8.encode(csvString)), fileName: fileName);
  }

  /// Exports Sub Vendor-wise Summary to CSV.
  static Future<void> exportSubVendorWiseReportCsv(List<Map<String, dynamic>> summaries) async {
    final rows = <List<dynamic>>[
      ['Sub Vendor Name', 'Total Outward Entries', 'Total Quantity Issued', 'Material Details Summary'],
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
        matSummary,
      ]);
    }

    final csvString = const ListToCsvConverter().convert(rows);
    final fileName = 'Sub_Vendor_Wise_Material_Report_${DateFormat('yyyyMMdd').format(DateTime.now())}.csv';
    await saveFileUniversal(bytes: Uint8List.fromList(utf8.encode(csvString)), fileName: fileName);
  }

  /// Exports Material-wise Summary to CSV.
  static Future<void> exportMaterialWiseReportCsv(List<Map<String, dynamic>> summaries) async {
    final rows = <List<dynamic>>[
      ['Material Name', 'Unit', 'Total Quantity Issued', 'Sub Vendor Breakdown'],
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
        vBreakdown,
      ]);
    }

    final csvString = const ListToCsvConverter().convert(rows);
    final fileName = 'Material_Wise_Outward_Report_${DateFormat('yyyyMMdd').format(DateTime.now())}.csv';
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
