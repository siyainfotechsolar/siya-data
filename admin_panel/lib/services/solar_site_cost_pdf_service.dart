import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:siya_shared/siya_shared.dart';
import 'solar_quotation_font_helper.dart';

/// Professional PDF Generator for SIYA SOLAR SITE COST CALCULATOR statements.
class SolarSiteCostPdfService {
  static const PdfColor navyColor = PdfColor.fromInt(0xFF0D2B6F);
  static const PdfColor goldColor = PdfColor.fromInt(0xFFD97706);
  static const PdfColor emeraldColor = PdfColor.fromInt(0xFF047857);
  static const PdfColor darkTextColor = PdfColor.fromInt(0xFF0F172A);
  static const PdfColor slateBodyColor = PdfColor.fromInt(0xFF1E293B);
  static const PdfColor slateMutedColor = PdfColor.fromInt(0xFF64748B);
  static const PdfColor borderDarkColor = PdfColor.fromInt(0xFFCBD5E1);
  static const PdfColor headerBgColor = PdfColor.fromInt(0xFFF1F5F9);
  static const PdfColor zebraBgColor = PdfColor.fromInt(0xFFF8FAFC);
  static const PdfColor accentBannerBg = PdfColor.fromInt(0xFFEFF6FF);

  static final _currency = NumberFormat.currency(locale: 'en_IN', symbol: 'Rs. ', decimalDigits: 2);
  static final _dateFormat = DateFormat('dd-MM-yyyy');

  static Future<Uint8List> generateSiteCostPdfBytes(SolarSiteCostCalculation calc) async {
    final pdfTheme = await SolarQuotationFontHelper.loadPdfTheme();
    final pdf = pw.Document(theme: pdfTheme);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        build: (context) {
          return [
            // 1. Header Banner
            _buildHeader(calc),
            pw.SizedBox(height: 12),

            // 2. Site & Customer Summary Info Box
            _buildInfoCard(calc),
            pw.SizedBox(height: 12),

            // 3. Solar Panels Section
            if (calc.panels.isNotEmpty) ...[
              _buildSectionTitle('1. SOLAR PANELS (WATTAGE × RATE/WATT)'),
              _buildPanelsTable(calc),
              pw.SizedBox(height: 10),
            ],

            // 4. Inverters Section (Fixed Cost)
            if (calc.inverters.isNotEmpty) ...[
              _buildSectionTitle('2. INVERTER COST (FIXED RATE ONLY)'),
              _buildInvertersTable(calc),
              pw.SizedBox(height: 10),
            ],

            // 5. GI Pipe Section (Size-wise & KG Rate)
            if (calc.giPipes.isNotEmpty) ...[
              _buildSectionTitle('3. GI PIPE STRUCTURE (SIZE-WISE & RATE PER KG)'),
              _buildGiPipesTable(calc),
              pw.SizedBox(height: 10),
            ],

            // 6. Other Structure Section
            if (calc.structureItems.isNotEmpty) ...[
              _buildSectionTitle('4. OTHER STRUCTURE MATERIAL'),
              _buildStructureTable(calc),
              pw.SizedBox(height: 10),
            ],

            // 7. Electrical BOS Section
            if (calc.bosItems.isNotEmpty) ...[
              _buildSectionTitle('5. ELECTRICAL BOS MATERIAL'),
              _buildBosTable(calc),
              pw.SizedBox(height: 10),
            ],

            // 8. Other Materials (if any)
            if (calc.otherMaterials.isNotEmpty) ...[
              _buildSectionTitle('6. OTHER CUSTOM MATERIALS'),
              _buildOtherMaterialsTable(calc),
              pw.SizedBox(height: 10),
            ],

            // 9. Labour Cost (Exactly 3 categories)
            _buildSectionTitle('7. LABOUR CHARGES (THREE CATEGORIES)'),
            _buildLabourTable(calc),
            pw.SizedBox(height: 10),

            // 10. Other Expenses
            _buildSectionTitle('8. OTHER EXPENSES (TRANSPORT & ON-SITE)'),
            _buildExpensesTable(calc),
            pw.SizedBox(height: 14),

            // 11. Final Category Summary & Prominent Site Cost Card
            _buildFinalSummaryBox(calc),
            pw.SizedBox(height: 16),

            // 12. Signatures / Audit footer
            _buildFooterSignatures(calc),
          ];
        },
      ),
    );

    return pdf.save();
  }

  // ---------------------------------------------------------------------------
  // Widgets / Helpers
  // ---------------------------------------------------------------------------

  static pw.Widget _buildHeader(SolarSiteCostCalculation calc) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: headerBgColor,
        border: pw.Border.all(color: borderDarkColor, width: 0.8),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
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
                  fontSize: 15,
                  fontWeight: pw.FontWeight.bold,
                  color: navyColor,
                ),
              ),
              pw.SizedBox(height: 2),
              pw.Text(
                'SOLAR SITE MATERIAL-WISE TOTAL COST CALCULATOR',
                style: pw.TextStyle(
                  fontSize: 9.5,
                  fontWeight: pw.FontWeight.bold,
                  color: goldColor,
                ),
              ),
              pw.Text(
                'Confidential Site Material & Cost Estimation Sheet',
                style: const pw.TextStyle(fontSize: 8, color: slateMutedColor),
              ),
            ],
          ),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: const pw.BoxDecoration(
                  color: navyColor,
                  borderRadius: pw.BorderRadius.all(pw.Radius.circular(4)),
                ),
                child: pw.Text(
                  calc.calculationNumber.isNotEmpty ? calc.calculationNumber : 'SCC-ESTIMATE',
                  style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
                ),
              ),
              pw.SizedBox(height: 3),
              pw.Text(
                'Date: ${_dateFormat.format(calc.calculationDate)}',
                style: const pw.TextStyle(fontSize: 8.5, color: slateBodyColor),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildInfoCard(SolarSiteCostCalculation calc) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        color: accentBannerBg,
        border: pw.Border.all(color: borderDarkColor, width: 0.8),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                _infoRow('Site Name:', calc.siteName),
                pw.SizedBox(height: 3),
                _infoRow('Customer:', calc.customerName.isNotEmpty ? calc.customerName : 'N/A'),
              ],
            ),
          ),
          pw.SizedBox(width: 16),
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                _infoRow('System Capacity:', '${calc.systemCapacityKw.toStringAsFixed(2)} kW (${calc.totalSystemWattage.toStringAsFixed(0)} W)'),
                pw.SizedBox(height: 3),
                _infoRow('Cost Per kW:', _currency.format(calc.costPerKw)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _infoRow(String label, String value) {
    return pw.RichText(
      text: pw.TextSpan(
        text: '$label ',
        style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: slateBodyColor),
        children: [
          pw.TextSpan(
            text: value,
            style: pw.TextStyle(fontWeight: pw.FontWeight.normal, color: darkTextColor),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildSectionTitle(String title) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 4),
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: const pw.BoxDecoration(
        color: headerBgColor,
        borderRadius: pw.BorderRadius.all(pw.Radius.circular(3)),
      ),
      child: pw.Text(
        title,
        style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: navyColor),
      ),
    );
  }

  static pw.Widget _buildPanelsTable(SolarSiteCostCalculation calc) {
    return pw.Table(
      border: pw.TableBorder.all(color: borderDarkColor, width: 0.5),
      columnWidths: const {
        0: pw.FlexColumnWidth(2.5), // Brand & Model
        1: pw.FlexColumnWidth(1.2), // Wattage
        2: pw.FlexColumnWidth(1.0), // Qty
        3: pw.FlexColumnWidth(1.4), // Total Wattage
        4: pw.FlexColumnWidth(1.3), // Rate/W
        5: pw.FlexColumnWidth(1.6), // Total Amount
      },
      children: [
        _tableHeader(['Panel Brand / Model', 'Wattage (W)', 'Quantity', 'Total Watts', 'Rate (Rs/W)', 'Total (Rs.)']),
        ...calc.panels.map((p) => _tableRow([
              '${p.brand} ${p.model}'.trim(),
              '${p.wattage.toStringAsFixed(0)} W',
              '${p.quantity} Nos',
              '${p.totalWattage.toStringAsFixed(0)} W',
              'Rs. ${p.ratePerWatt.toStringAsFixed(2)}',
              _currency.format(p.totalAmount),
            ])),
        _tableTotalRow('Total Solar Panel Cost', _currency.format(calc.totalPanelCost), 6),
      ],
    );
  }

  static pw.Widget _buildInvertersTable(SolarSiteCostCalculation calc) {
    return pw.Table(
      border: pw.TableBorder.all(color: borderDarkColor, width: 0.5),
      columnWidths: const {
        0: pw.FlexColumnWidth(3.0), // Brand & Model
        1: pw.FlexColumnWidth(1.5), // Capacity
        2: pw.FlexColumnWidth(1.0), // Qty
        3: pw.FlexColumnWidth(1.8), // Fixed Rate
        4: pw.FlexColumnWidth(1.8), // Total
      },
      children: [
        _tableHeader(['Inverter Brand / Model', 'Capacity', 'Quantity', 'Fixed Rate (Rs.)', 'Total (Rs.)']),
        ...calc.inverters.map((inv) => _tableRow([
              '${inv.brand} ${inv.model}'.trim(),
              inv.capacity,
              '${inv.quantity} Nos',
              _currency.format(inv.fixedRate),
              _currency.format(inv.totalAmount),
            ])),
        _tableTotalRow('Total Inverter Cost (Fixed Rate)', _currency.format(calc.totalInverterCost), 5),
      ],
    );
  }

  static pw.Widget _buildGiPipesTable(SolarSiteCostCalculation calc) {
    return pw.Table(
      border: pw.TableBorder.all(color: borderDarkColor, width: 0.5),
      columnWidths: const {
        0: pw.FlexColumnWidth(2.2), // Size
        1: pw.FlexColumnWidth(1.0), // Thk
        2: pw.FlexColumnWidth(1.0), // Pipes
        3: pw.FlexColumnWidth(1.3), // Wt/Pipe
        4: pw.FlexColumnWidth(1.4), // Total Wt
        5: pw.FlexColumnWidth(1.2), // Rate/KG
        6: pw.FlexColumnWidth(1.7), // Total
      },
      children: [
        _tableHeader(['GI Pipe Size', 'Thk (mm)', 'Pipes', 'Wt/Pipe', 'Total Wt (KG)', 'Rate/KG', 'Total (Rs.)']),
        ...calc.giPipes.map((pipe) => _tableRow([
              pipe.pipeSize,
              '${pipe.thicknessMm.toStringAsFixed(1)} mm',
              '${pipe.numberOfPipes} Nos',
              '${pipe.weightPerPipeKg.toStringAsFixed(1)} KG',
              '${pipe.totalWeightKg.toStringAsFixed(1)} KG',
              'Rs. ${pipe.ratePerKg.toStringAsFixed(2)}',
              _currency.format(pipe.totalAmount),
            ])),
        _tableTotalRow('Total GI Pipe Cost', _currency.format(calc.totalGiPipeCost), 7),
      ],
    );
  }

  static pw.Widget _buildStructureTable(SolarSiteCostCalculation calc) {
    return pw.Table(
      border: pw.TableBorder.all(color: borderDarkColor, width: 0.5),
      columnWidths: const {
        0: pw.FlexColumnWidth(3.0),
        1: pw.FlexColumnWidth(1.5),
        2: pw.FlexColumnWidth(1.2),
        3: pw.FlexColumnWidth(1.5),
        4: pw.FlexColumnWidth(1.8),
      },
      children: [
        _tableHeader(['Structure Item', 'Specification', 'Unit / Qty', 'Rate (Rs.)', 'Total (Rs.)']),
        ...calc.structureItems.map((item) => _tableRow([
              item.itemName,
              item.specification,
              '${item.quantity.toStringAsFixed(0)} ${item.unit}',
              'Rs. ${item.rate.toStringAsFixed(2)}',
              _currency.format(item.totalAmount),
            ])),
        _tableTotalRow('Total Other Structure Cost', _currency.format(calc.totalStructureCost), 5),
      ],
    );
  }

  static pw.Widget _buildBosTable(SolarSiteCostCalculation calc) {
    return pw.Table(
      border: pw.TableBorder.all(color: borderDarkColor, width: 0.5),
      columnWidths: const {
        0: pw.FlexColumnWidth(2.6),
        1: pw.FlexColumnWidth(2.0),
        2: pw.FlexColumnWidth(1.2),
        3: pw.FlexColumnWidth(1.4),
        4: pw.FlexColumnWidth(1.8),
      },
      children: [
        _tableHeader(['BOS Item', 'Specification', 'Unit / Qty', 'Rate (Rs.)', 'Total (Rs.)']),
        ...calc.bosItems.map((item) => _tableRow([
              item.itemName,
              item.specification,
              item.unit == 'FIXED' ? '1 Fixed' : '${item.quantity.toStringAsFixed(0)} ${item.unit}',
              _currency.format(item.rate),
              _currency.format(item.totalAmount),
            ])),
        _tableTotalRow('Total Electrical BOS Cost', _currency.format(calc.totalBosCost), 5),
      ],
    );
  }

  static pw.Widget _buildOtherMaterialsTable(SolarSiteCostCalculation calc) {
    return pw.Table(
      border: pw.TableBorder.all(color: borderDarkColor, width: 0.5),
      columnWidths: const {
        0: pw.FlexColumnWidth(3.0),
        1: pw.FlexColumnWidth(2.0),
        2: pw.FlexColumnWidth(1.2),
        3: pw.FlexColumnWidth(1.4),
        4: pw.FlexColumnWidth(1.8),
      },
      children: [
        _tableHeader(['Material Name', 'Specification', 'Unit / Qty', 'Rate (Rs.)', 'Total (Rs.)']),
        ...calc.otherMaterials.map((item) => _tableRow([
              item.materialName,
              item.specification,
              '${item.quantity.toStringAsFixed(0)} ${item.unit}',
              'Rs. ${item.rate.toStringAsFixed(2)}',
              _currency.format(item.totalAmount),
            ])),
        _tableTotalRow('Total Other Materials Cost', _currency.format(calc.totalOtherMaterialCost), 5),
      ],
    );
  }

  static pw.Widget _buildLabourTable(SolarSiteCostCalculation calc) {
    return pw.Table(
      border: pw.TableBorder.all(color: borderDarkColor, width: 0.5),
      columnWidths: const {
        0: pw.FlexColumnWidth(3.0),
        1: pw.FlexColumnWidth(3.5),
        2: pw.FlexColumnWidth(2.0),
      },
      children: [
        _tableHeader(['Labour Category', 'Description', 'Amount (Rs.)']),
        _tableRow(['A. Wiring Labour', calc.labour.wiringLabour.description, _currency.format(calc.totalWiringLabour)]),
        _tableRow(['B. Structure Labour', calc.labour.structureLabour.description, _currency.format(calc.totalStructureLabour)]),
        _tableRow(['C. Civil Labour', calc.labour.civilLabour.description, _currency.format(calc.totalCivilLabour)]),
        _tableTotalRow('Total Labour Cost (Wiring + Structure + Civil)', _currency.format(calc.totalLabourCost), 3),
      ],
    );
  }

  static pw.Widget _buildExpensesTable(SolarSiteCostCalculation calc) {
    return pw.Table(
      border: pw.TableBorder.all(color: borderDarkColor, width: 0.5),
      columnWidths: const {
        0: pw.FlexColumnWidth(3.5),
        1: pw.FlexColumnWidth(3.0),
        2: pw.FlexColumnWidth(2.0),
      },
      children: [
        _tableHeader(['Expense Particulars', 'Type / Details', 'Amount (Rs.)']),
        _tableRow(['Transportation Charges', 'Freight to site', _currency.format(calc.otherExpenses.transportation)]),
        _tableRow(['Loading / Unloading', 'Site material handling', _currency.format(calc.otherExpenses.loadingUnloading)]),
        _tableRow(['Other Site Expenses', 'Miscellaneous site contingency', _currency.format(calc.otherExpenses.otherExpenses)]),
        ...calc.otherExpenses.customExpenses.map((exp) => _tableRow([
              exp.description,
              'Additional expense',
              _currency.format(exp.amount),
            ])),
        _tableTotalRow('Total Other Expenses', _currency.format(calc.totalOtherExpensesCost), 3),
      ],
    );
  }

  static pw.Widget _buildFinalSummaryBox(SolarSiteCostCalculation calc) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: zebraBgColor,
        border: pw.Border.all(color: navyColor, width: 1.2),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
      ),
      child: pw.Column(
        children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('CATEGORY-WISE COST SUMMARY', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: navyColor)),
              pw.Text('All amounts in INR (Exclusive of GST/Loans)', style: const pw.TextStyle(fontSize: 7.5, color: slateMutedColor)),
            ],
          ),
          pw.Divider(color: borderDarkColor, thickness: 0.8),
          pw.SizedBox(height: 4),

          _summaryRow('1. Total Solar Panel Cost:', _currency.format(calc.totalPanelCost)),
          _summaryRow('2. Total Inverter Cost (Fixed):', _currency.format(calc.totalInverterCost)),
          _summaryRow('3. Total GI Pipe Structure Cost:', _currency.format(calc.totalGiPipeCost)),
          if (calc.totalStructureCost > 0)
            _summaryRow('4. Total Other Structure Material Cost:', _currency.format(calc.totalStructureCost)),
          _summaryRow('5. Total Electrical BOS Cost:', _currency.format(calc.totalBosCost)),
          if (calc.totalOtherMaterialCost > 0)
            _summaryRow('6. Total Other Materials Cost:', _currency.format(calc.totalOtherMaterialCost)),
          _summaryRow('7. Total Labour Cost (Wiring + Structure + Civil):', _currency.format(calc.totalLabourCost)),
          _summaryRow('8. Total Other Expenses (Transport & Unloading):', _currency.format(calc.totalOtherExpensesCost)),

          pw.SizedBox(height: 6),
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: const pw.BoxDecoration(
              color: navyColor,
              borderRadius: pw.BorderRadius.all(pw.Radius.circular(4)),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'FINAL TOTAL SITE COST:',
                  style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
                ),
                pw.Text(
                  _currency.format(calc.finalSiteCost),
                  style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: PdfColors.amber),
                ),
              ],
            ),
          ),
          if (calc.systemCapacityKw > 0) ...[
            pw.SizedBox(height: 4),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.end,
              children: [
                pw.Text(
                  'Cost Per Installed kW: ${_currency.format(calc.costPerKw)} / kW',
                  style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: emeraldColor),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  static pw.Widget _summaryRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 1.5),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: const pw.TextStyle(fontSize: 8, color: slateBodyColor)),
          pw.Text(value, style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: darkTextColor)),
        ],
      ),
    );
  }

  static pw.TableRow _tableHeader(List<String> titles) {
    return pw.TableRow(
      decoration: const pw.BoxDecoration(color: headerBgColor),
      children: titles
          .map((t) => pw.Padding(
                padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                child: pw.Text(
                  t,
                  style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: navyColor),
                ),
              ))
          .toList(),
    );
  }

  static pw.TableRow _tableRow(List<String> values) {
    return pw.TableRow(
      children: values
          .map((v) => pw.Padding(
                padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3.5),
                child: pw.Text(
                  v,
                  style: const pw.TextStyle(fontSize: 7.5, color: darkTextColor),
                ),
              ))
          .toList(),
    );
  }

  static pw.TableRow _tableTotalRow(String label, String total, int colSpan) {
    return pw.TableRow(
      decoration: const pw.BoxDecoration(color: zebraBgColor),
      children: [
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: pw.Text(
            label,
            style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: navyColor),
          ),
        ),
        ...List.generate(
          colSpan - 2,
          (index) => pw.Padding(padding: const pw.EdgeInsets.all(2), child: pw.Text('')),
        ),
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: pw.Text(
            total,
            style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: darkTextColor),
          ),
        ),
      ],
    );
  }

  static pw.Widget _buildFooterSignatures(SolarSiteCostCalculation calc) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text('Prepared By:', style: const pw.TextStyle(fontSize: 8, color: slateMutedColor)),
            pw.SizedBox(height: 18),
            pw.Container(width: 120, height: 0.8, color: borderDarkColor),
            pw.SizedBox(height: 2),
            pw.Text('Technical Estimation Team', style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold)),
          ],
        ),
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.Text('Approved By:', style: const pw.TextStyle(fontSize: 8, color: slateMutedColor)),
            pw.SizedBox(height: 18),
            pw.Container(width: 120, height: 0.8, color: borderDarkColor),
            pw.SizedBox(height: 2),
            pw.Text('SIYA INFOTECH & SOLAR ENERGY', style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: navyColor)),
          ],
        ),
      ],
    );
  }
}
