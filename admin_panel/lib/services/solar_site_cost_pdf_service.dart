import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:siya_shared/siya_shared.dart';
import 'solar_quotation_font_helper.dart';

/// Professional PDF Generator for SIYA SOLAR SITE COST CALCULATOR statements.
/// Supports both Taxable Base Cost, Item-wise GST (5%, 12%, 18%), and Grand Total.
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

            // 3. Solar Panels Section (with 5% GST)
            if (calc.panels.isNotEmpty) ...[
              _buildSectionTitle('1. SOLAR PANELS (WATTAGE × RATE/WATT + 5% GST)'),
              _buildPanelsTable(calc),
              pw.SizedBox(height: 10),
            ],

            // 4. Inverters Section (Fixed Cost + 5%/12% GST)
            if (calc.inverters.isNotEmpty) ...[
              _buildSectionTitle('2. INVERTER COST (FIXED RATE + 5%/12% GST)'),
              _buildInvertersTable(calc),
              pw.SizedBox(height: 10),
            ],

            // 5. GI Pipe Section (Size-wise, KG Rate + 18% GST)
            if (calc.giPipes.isNotEmpty) ...[
              _buildSectionTitle('3. GI PIPE STRUCTURE (SIZE-WISE & RATE PER KG + 18% GST)'),
              _buildGiPipesTable(calc),
              pw.SizedBox(height: 10),
            ],

            // 6. Other Structure Section (+ 18% GST)
            if (calc.structureItems.isNotEmpty) ...[
              _buildSectionTitle('4. OTHER STRUCTURE MATERIAL (+ 18% GST)'),
              _buildStructureTable(calc),
              pw.SizedBox(height: 10),
            ],

            // 7. Electrical BOS Section (+ 18% GST)
            if (calc.bosItems.isNotEmpty) ...[
              _buildSectionTitle('5. ELECTRICAL BOS MATERIAL (+ 18% GST)'),
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

            // 11. Final Category Summary with GST & Prominent Site Cost Card
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
                'SOLAR SITE MATERIAL-WISE TOTAL COST & GST CALCULATOR',
                style: pw.TextStyle(
                  fontSize: 9.5,
                  fontWeight: pw.FontWeight.bold,
                  color: goldColor,
                ),
              ),
              pw.Text(
                'Confidential Site Material, BOS, Labour & GST Estimation Sheet',
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
                _infoRow('Pricing Mode:', calc.isGstApplicable ? 'GST Inclusive (With Tax)' : 'Net Base Cost (Without GST)'),
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
        0: pw.FlexColumnWidth(2.3), // Brand & Model
        1: pw.FlexColumnWidth(1.0), // Wattage
        2: pw.FlexColumnWidth(0.9), // Qty
        3: pw.FlexColumnWidth(1.2), // Rate/W
        4: pw.FlexColumnWidth(1.4), // Taxable
        5: pw.FlexColumnWidth(0.9), // GST %
        6: pw.FlexColumnWidth(1.2), // GST (Rs)
        7: pw.FlexColumnWidth(1.5), // Total Amount
      },
      children: [
        _tableHeader(['Panel Brand / Model', 'Watts', 'Qty', 'Rate/W', 'Taxable (Rs.)', 'GST %', 'GST (Rs.)', 'Total (Rs.)']),
        ...calc.panels.map((p) => _tableRow([
              '${p.brand} ${p.model}'.trim(),
              '${p.wattage.toStringAsFixed(0)} W',
              '${p.quantity} Nos',
              'Rs. ${p.ratePerWatt.toStringAsFixed(2)}',
              _currency.format(p.taxableAmount),
              '${p.gstRate.toStringAsFixed(0)}%',
              _currency.format(p.gstAmount),
              _currency.format(p.totalAmount),
            ])),
        _tableTotalRow('Total Solar Panel Cost (Taxable / GST / Total)', [
          _currency.format(calc.totalPanelTaxable),
          _currency.format(calc.totalPanelGst),
          _currency.format(calc.totalPanelCost),
        ], 8),
      ],
    );
  }

  static pw.Widget _buildInvertersTable(SolarSiteCostCalculation calc) {
    return pw.Table(
      border: pw.TableBorder.all(color: borderDarkColor, width: 0.5),
      columnWidths: const {
        0: pw.FlexColumnWidth(2.5),
        1: pw.FlexColumnWidth(1.2),
        2: pw.FlexColumnWidth(0.9),
        3: pw.FlexColumnWidth(1.4),
        4: pw.FlexColumnWidth(1.4),
        5: pw.FlexColumnWidth(0.9),
        6: pw.FlexColumnWidth(1.2),
        7: pw.FlexColumnWidth(1.5),
      },
      children: [
        _tableHeader(['Inverter Brand / Model', 'Capacity', 'Qty', 'Fixed Rate', 'Taxable (Rs.)', 'GST %', 'GST (Rs.)', 'Total (Rs.)']),
        ...calc.inverters.map((inv) => _tableRow([
              '${inv.brand} ${inv.model}'.trim(),
              inv.capacity,
              '${inv.quantity} Nos',
              _currency.format(inv.fixedRate),
              _currency.format(inv.taxableAmount),
              '${inv.gstRate.toStringAsFixed(0)}%',
              _currency.format(inv.gstAmount),
              _currency.format(inv.totalAmount),
            ])),
        _tableTotalRow('Total Inverter Cost (Taxable / GST / Total)', [
          _currency.format(calc.totalInverterTaxable),
          _currency.format(calc.totalInverterGst),
          _currency.format(calc.totalInverterCost),
        ], 8),
      ],
    );
  }

  static pw.Widget _buildGiPipesTable(SolarSiteCostCalculation calc) {
    return pw.Table(
      border: pw.TableBorder.all(color: borderDarkColor, width: 0.5),
      columnWidths: const {
        0: pw.FlexColumnWidth(2.0),
        1: pw.FlexColumnWidth(0.8),
        2: pw.FlexColumnWidth(0.8),
        3: pw.FlexColumnWidth(1.1),
        4: pw.FlexColumnWidth(1.0),
        5: pw.FlexColumnWidth(1.3),
        6: pw.FlexColumnWidth(0.8),
        7: pw.FlexColumnWidth(1.1),
        8: pw.FlexColumnWidth(1.4),
      },
      children: [
        _tableHeader(['GI Pipe Size', 'Thk', 'Pipes', 'Total Wt', 'Rate/KG', 'Taxable (Rs.)', 'GST %', 'GST (Rs.)', 'Total (Rs.)']),
        ...calc.giPipes.map((pipe) => _tableRow([
              pipe.pipeSize,
              '${pipe.thicknessMm.toStringAsFixed(1)}mm',
              '${pipe.numberOfPipes}',
              '${pipe.totalWeightKg.toStringAsFixed(1)}KG',
              'Rs.${pipe.ratePerKg.toStringAsFixed(0)}',
              _currency.format(pipe.taxableAmount),
              '${pipe.gstRate.toStringAsFixed(0)}%',
              _currency.format(pipe.gstAmount),
              _currency.format(pipe.totalAmount),
            ])),
        _tableTotalRow('Total GI Pipe Cost (Taxable / GST / Total)', [
          _currency.format(calc.totalGiPipeTaxable),
          _currency.format(calc.totalGiPipeGst),
          _currency.format(calc.totalGiPipeCost),
        ], 9),
      ],
    );
  }

  static pw.Widget _buildStructureTable(SolarSiteCostCalculation calc) {
    return pw.Table(
      border: pw.TableBorder.all(color: borderDarkColor, width: 0.5),
      columnWidths: const {
        0: pw.FlexColumnWidth(2.5),
        1: pw.FlexColumnWidth(1.4),
        2: pw.FlexColumnWidth(1.1),
        3: pw.FlexColumnWidth(1.2),
        4: pw.FlexColumnWidth(1.4),
        5: pw.FlexColumnWidth(0.8),
        6: pw.FlexColumnWidth(1.1),
        7: pw.FlexColumnWidth(1.4),
      },
      children: [
        _tableHeader(['Structure Item', 'Specification', 'Unit/Qty', 'Rate', 'Taxable (Rs.)', 'GST %', 'GST (Rs.)', 'Total (Rs.)']),
        ...calc.structureItems.map((item) => _tableRow([
              item.itemName,
              item.specification,
              '${item.quantity.toStringAsFixed(0)} ${item.unit}',
              'Rs.${item.rate.toStringAsFixed(2)}',
              _currency.format(item.taxableAmount),
              '${item.gstRate.toStringAsFixed(0)}%',
              _currency.format(item.gstAmount),
              _currency.format(item.totalAmount),
            ])),
        _tableTotalRow('Total Other Structure Cost', [
          _currency.format(calc.totalStructureTaxable),
          _currency.format(calc.totalStructureGst),
          _currency.format(calc.totalStructureCost),
        ], 8),
      ],
    );
  }

  static pw.Widget _buildBosTable(SolarSiteCostCalculation calc) {
    return pw.Table(
      border: pw.TableBorder.all(color: borderDarkColor, width: 0.5),
      columnWidths: const {
        0: pw.FlexColumnWidth(2.3),
        1: pw.FlexColumnWidth(1.5),
        2: pw.FlexColumnWidth(1.0),
        3: pw.FlexColumnWidth(1.2),
        4: pw.FlexColumnWidth(1.4),
        5: pw.FlexColumnWidth(0.8),
        6: pw.FlexColumnWidth(1.1),
        7: pw.FlexColumnWidth(1.4),
      },
      children: [
        _tableHeader(['BOS Item', 'Specification', 'Unit/Qty', 'Rate', 'Taxable (Rs.)', 'GST %', 'GST (Rs.)', 'Total (Rs.)']),
        ...calc.bosItems.map((item) => _tableRow([
              item.itemName,
              item.specification,
              item.unit == 'FIXED' ? '1 Fixed' : '${item.quantity.toStringAsFixed(0)} ${item.unit}',
              _currency.format(item.rate),
              _currency.format(item.taxableAmount),
              '${item.gstRate.toStringAsFixed(0)}%',
              _currency.format(item.gstAmount),
              _currency.format(item.totalAmount),
            ])),
        _tableTotalRow('Total Electrical BOS Cost', [
          _currency.format(calc.totalBosTaxable),
          _currency.format(calc.totalBosGst),
          _currency.format(calc.totalBosCost),
        ], 8),
      ],
    );
  }

  static pw.Widget _buildOtherMaterialsTable(SolarSiteCostCalculation calc) {
    return pw.Table(
      border: pw.TableBorder.all(color: borderDarkColor, width: 0.5),
      columnWidths: const {
        0: pw.FlexColumnWidth(2.5),
        1: pw.FlexColumnWidth(1.5),
        2: pw.FlexColumnWidth(1.0),
        3: pw.FlexColumnWidth(1.2),
        4: pw.FlexColumnWidth(1.4),
        5: pw.FlexColumnWidth(0.8),
        6: pw.FlexColumnWidth(1.1),
        7: pw.FlexColumnWidth(1.4),
      },
      children: [
        _tableHeader(['Material Name', 'Specification', 'Unit/Qty', 'Rate', 'Taxable (Rs.)', 'GST %', 'GST (Rs.)', 'Total (Rs.)']),
        ...calc.otherMaterials.map((item) => _tableRow([
              item.materialName,
              item.specification,
              '${item.quantity.toStringAsFixed(0)} ${item.unit}',
              'Rs.${item.rate.toStringAsFixed(2)}',
              _currency.format(item.taxableAmount),
              '${item.gstRate.toStringAsFixed(0)}%',
              _currency.format(item.gstAmount),
              _currency.format(item.totalAmount),
            ])),
        _tableTotalRow('Total Other Materials Cost', [
          _currency.format(calc.totalOtherMaterialTaxable),
          _currency.format(calc.totalOtherMaterialGst),
          _currency.format(calc.totalOtherMaterialCost),
        ], 8),
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
        _tableSimpleTotalRow('Total Labour Cost (Wiring + Structure + Civil)', _currency.format(calc.totalLabourCost), 3),
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
        _tableSimpleTotalRow('Total Other Expenses', _currency.format(calc.totalOtherExpensesCost), 3),
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
              pw.Text('CATEGORY-WISE COST & GST SUMMARY', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: navyColor)),
              pw.Text(calc.isGstApplicable ? 'Mode: GST Inclusive' : 'Mode: Net Base Cost', style: const pw.TextStyle(fontSize: 7.5, color: slateMutedColor)),
            ],
          ),
          pw.Divider(color: borderDarkColor, thickness: 0.8),
          pw.SizedBox(height: 4),

          _summaryRow('1. Total Solar Panel Taxable:', _currency.format(calc.totalPanelTaxable)),
          if (calc.totalPanelGst > 0)
            _summaryRow('   + Solar Panels 5% GST:', _currency.format(calc.totalPanelGst)),
          _summaryRow('2. Total Inverter Taxable (Fixed):', _currency.format(calc.totalInverterTaxable)),
          if (calc.totalInverterGst > 0)
            _summaryRow('   + Inverter GST:', _currency.format(calc.totalInverterGst)),
          _summaryRow('3. Total GI Pipe Structure Taxable:', _currency.format(calc.totalGiPipeTaxable)),
          if (calc.totalGiPipeGst > 0)
            _summaryRow('   + GI Pipe 18% GST:', _currency.format(calc.totalGiPipeGst)),
          if (calc.totalStructureTaxable > 0)
            _summaryRow('4. Total Other Structure Material Taxable:', _currency.format(calc.totalStructureTaxable)),
          _summaryRow('5. Total Electrical BOS Taxable:', _currency.format(calc.totalBosTaxable)),
          if (calc.totalBosGst > 0)
            _summaryRow('   + Electrical BOS 18% GST:', _currency.format(calc.totalBosGst)),
          if (calc.totalOtherMaterialTaxable > 0)
            _summaryRow('6. Total Other Materials Taxable:', _currency.format(calc.totalOtherMaterialTaxable)),
          
          pw.Divider(color: borderDarkColor, thickness: 0.5),
          _summaryRow('Subtotal Taxable Material Cost:', _currency.format(calc.totalTaxableCost)),
          _summaryRow('Total Material GST Amount (5% & 18%):', _currency.format(calc.totalGstAmount)),
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
                  calc.isGstApplicable ? 'FINAL TOTAL SITE COST (GST INCLUSIVE):' : 'FINAL TOTAL SITE COST (NET BASE):',
                  style: pw.TextStyle(fontSize: 10.5, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
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
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'Base Net Cost (w/o GST): ${_currency.format(calc.finalSiteCostWithoutGst)}',
                  style: const pw.TextStyle(fontSize: 8, color: slateMutedColor),
                ),
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

  static pw.TableRow _tableTotalRow(String label, List<String> totals, int totalCols) {
    return pw.TableRow(
      decoration: const pw.BoxDecoration(color: zebraBgColor),
      children: [
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: pw.Text(
            label,
            style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: navyColor),
          ),
        ),
        ...List.generate(
          totalCols - totals.length - 1,
          (_) => pw.Padding(padding: const pw.EdgeInsets.all(2), child: pw.Text('')),
        ),
        ...totals.map((t) => pw.Padding(
              padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              child: pw.Text(
                t,
                style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: darkTextColor),
              ),
            )),
      ],
    );
  }

  static pw.TableRow _tableSimpleTotalRow(String label, String total, int colSpan) {
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
          (_) => pw.Padding(padding: const pw.EdgeInsets.all(2), child: pw.Text('')),
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
