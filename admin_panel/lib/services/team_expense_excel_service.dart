import 'dart:typed_data';
import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import '../models/site_team_expense.dart';
import '../models/consumer_record.dart';
import '../utils/universal_file_saver.dart';
import 'audit_service.dart';

class TeamExpenseExcelService {
  static final NumberFormat _currencyFormatter = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹ ',
    decimalDigits: 2,
  );

  /// Builds a complete multi-sheet Excel workbook containing:
  /// - Sheet 1: Customer-wise Report
  /// - Sheet 2: Team-wise Summary
  /// - Sheet 3: Detailed Team Report
  /// - Sheet 4: Pending Expenses Sites (when pending customers provided)
  static List<int> buildExcelWorkbook({
    required List<SiteTeamExpense> expenses,
    List<ConsumerRecord>? pendingConsumers,
    String? filterSummary,
  }) {
    final excel = Excel.createExcel();

    // Remove default Sheet1
    excel.delete('Sheet1');

    final summary = TeamExpenseSummary.fromExpenses(expenses);
    final now = DateTime.now();
    final generatedDateStr = DateFormat('dd/MM/yyyy hh:mm a').format(now);
    final effectiveFilters = (filterSummary != null && filterSummary.isNotEmpty)
        ? filterSummary
        : 'All Sites (No Filters)';

    // Styling constants
    final headerStyle = CellStyle(
      bold: true,
      fontSize: 11,
      fontColorHex: ExcelColor.white,
      backgroundColorHex: ExcelColor.fromHexString('#1E3A8A'), // Navy Blue
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
    );

    final titleStyle = CellStyle(
      bold: true,
      fontSize: 13,
      fontColorHex: ExcelColor.fromHexString('#0F172A'),
    );

    final metaStyle = CellStyle(
      fontSize: 10,
      fontColorHex: ExcelColor.fromHexString('#475569'),
    );

    final totalRowStyle = CellStyle(
      bold: true,
      fontSize: 11,
      fontColorHex: ExcelColor.fromHexString('#064E3B'),
      backgroundColorHex: ExcelColor.fromHexString('#D1FAE5'), // Light Emerald
      horizontalAlign: HorizontalAlign.Right,
      verticalAlign: VerticalAlign.Center,
    );

    final totalLabelStyle = CellStyle(
      bold: true,
      fontSize: 11,
      fontColorHex: ExcelColor.fromHexString('#064E3B'),
      backgroundColorHex: ExcelColor.fromHexString('#D1FAE5'),
      horizontalAlign: HorizontalAlign.Left,
      verticalAlign: VerticalAlign.Center,
    );

    final currencyStyle = CellStyle(
      fontSize: 10,
      horizontalAlign: HorizontalAlign.Right,
    );

    // =========================================================================
    // SHEET 1: CUSTOMER-WISE REPORT
    // =========================================================================
    const sheet1Name = 'Customer-wise Report';
    final sheet1 = excel[sheet1Name];
    excel.setDefaultSheet(sheet1Name);

    // Banner
    sheet1.appendRow([TextCellValue('SIYA INFOTECH & SOLAR ENERGY — SITE-WISE TEAM EXPENSE REPORT')]);
    sheet1.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0)).cellStyle = titleStyle;

    sheet1.appendRow([TextCellValue('Generated: $generatedDateStr | Applied Filters: $effectiveFilters')]);
    sheet1.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 1)).cellStyle = metaStyle;

    sheet1.appendRow([TextCellValue('Total Sites: ${summary.totalSites} | Grand Total Expense: ${_currencyFormatter.format(summary.grandTotalExpense)}')]);
    sheet1.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 2)).cellStyle = metaStyle;

    sheet1.appendRow([TextCellValue('')]); // empty spacer

    // Header Row (Row 4)
    final sheet1Headers = [
      'Sr. No.',
      'Customer Name',
      'Consumer Number',
      'Site Location',
      'Solar Capacity',
      'Wiring Expense (₹)',
      'Civil Expense (₹)',
      'Structure Expense (₹)',
      'Total Site Expense (₹)',
      'Expense Date',
      'Remarks',
    ];
    sheet1.appendRow(sheet1Headers.map((h) => TextCellValue(h)).toList());
    final headerRowIdx1 = 4;
    for (int c = 0; c < sheet1Headers.length; c++) {
      sheet1.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: headerRowIdx1)).cellStyle = headerStyle;
    }

    // Data Rows
    int rowCounter1 = headerRowIdx1 + 1;
    for (int i = 0; i < expenses.length; i++) {
      final e = expenses[i];
      sheet1.appendRow([
        IntCellValue(i + 1),
        TextCellValue(e.customerName),
        TextCellValue(e.consumerNo),
        TextCellValue(e.siteLocation.isNotEmpty ? e.siteLocation : '—'),
        TextCellValue(e.solarCapacity.isNotEmpty ? e.solarCapacity : '—'),
        TextCellValue(_currencyFormatter.format(e.wiringExpense)),
        TextCellValue(_currencyFormatter.format(e.civilExpense)),
        TextCellValue(_currencyFormatter.format(e.structureExpense)),
        TextCellValue(_currencyFormatter.format(e.totalSiteExpense)),
        TextCellValue(e.formattedDate),
        TextCellValue(e.remarks ?? '—'),
      ]);

      // Align currency cells
      for (int c = 5; c <= 8; c++) {
        sheet1.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: rowCounter1)).cellStyle = currencyStyle;
      }
      rowCounter1++;
    }

    // Grand Total Row
    sheet1.appendRow([
      TextCellValue(''),
      TextCellValue('GRAND TOTAL'),
      TextCellValue('${summary.totalSites} Sites'),
      TextCellValue(''),
      TextCellValue(''),
      TextCellValue(_currencyFormatter.format(summary.totalWiringExpense)),
      TextCellValue(_currencyFormatter.format(summary.totalCivilExpense)),
      TextCellValue(_currencyFormatter.format(summary.totalStructureExpense)),
      TextCellValue(_currencyFormatter.format(summary.grandTotalExpense)),
      TextCellValue(''),
      TextCellValue(''),
    ]);
    final totalRowIdx1 = rowCounter1;
    for (int c = 0; c < sheet1Headers.length; c++) {
      final cell = sheet1.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: totalRowIdx1));
      cell.cellStyle = (c <= 4) ? totalLabelStyle : totalRowStyle;
    }

    // Auto Column Widths for Sheet 1
    final s1Widths = [10.0, 26.0, 18.0, 20.0, 16.0, 20.0, 20.0, 22.0, 22.0, 15.0, 25.0];
    for (int c = 0; c < s1Widths.length; c++) {
      sheet1.setColumnWidth(c, s1Widths[c]);
    }

    // =========================================================================
    // SHEET 2: TEAM-WISE SUMMARY
    // =========================================================================
    const sheet2Name = 'Team-wise Summary';
    final sheet2 = excel[sheet2Name];

    // Banner
    sheet2.appendRow([TextCellValue('SIYA INFOTECH & SOLAR ENERGY — TEAM-WISE EXPENSE SUMMARY')]);
    sheet2.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0)).cellStyle = titleStyle;

    sheet2.appendRow([TextCellValue('Generated: $generatedDateStr | Applied Filters: $effectiveFilters')]);
    sheet2.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 1)).cellStyle = metaStyle;

    sheet2.appendRow([TextCellValue('')]); // empty spacer

    // Headers
    final sheet2Headers = ['Team Name', 'Number of Sites', 'Total Expense (₹)'];
    sheet2.appendRow(sheet2Headers.map((h) => TextCellValue(h)).toList());
    final headerRowIdx2 = 3;
    for (int c = 0; c < sheet2Headers.length; c++) {
      sheet2.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: headerRowIdx2)).cellStyle = headerStyle;
    }

    // Team Rows
    final teamRows = [
      ['Wiring Team', summary.wiringSitesCount, summary.totalWiringExpense],
      ['Civil Team', summary.civilSitesCount, summary.totalCivilExpense],
      ['Structure Team', summary.structureSitesCount, summary.totalStructureExpense],
    ];

    int rowCounter2 = headerRowIdx2 + 1;
    for (final tr in teamRows) {
      sheet2.appendRow([
        TextCellValue(tr[0] as String),
        IntCellValue(tr[1] as int),
        TextCellValue(_currencyFormatter.format(tr[2] as double)),
      ]);
      sheet2.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: rowCounter2)).cellStyle = currencyStyle;
      rowCounter2++;
    }

    // Grand Total Row
    sheet2.appendRow([
      TextCellValue('Grand Total'),
      IntCellValue(summary.totalSites),
      TextCellValue(_currencyFormatter.format(summary.grandTotalExpense)),
    ]);
    final totalRowIdx2 = rowCounter2;
    for (int c = 0; c < sheet2Headers.length; c++) {
      sheet2.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: totalRowIdx2)).cellStyle = totalRowStyle;
    }

    // Column widths for Sheet 2
    sheet2.setColumnWidth(0, 24.0);
    sheet2.setColumnWidth(1, 18.0);
    sheet2.setColumnWidth(2, 24.0);

    // =========================================================================
    // SHEET 3: DETAILED TEAM REPORT
    // =========================================================================
    const sheet3Name = 'Detailed Team Report';
    final sheet3 = excel[sheet3Name];

    // Banner
    sheet3.appendRow([TextCellValue('SIYA INFOTECH & SOLAR ENERGY — DETAILED TEAM-WISE EXPENSE AUDIT')]);
    sheet3.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0)).cellStyle = titleStyle;

    sheet3.appendRow([TextCellValue('Generated: $generatedDateStr | Applied Filters: $effectiveFilters')]);
    sheet3.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 1)).cellStyle = metaStyle;

    sheet3.appendRow([TextCellValue('')]); // empty spacer

    // Headers
    final sheet3Headers = [
      'Sr. No.',
      'Customer Name',
      'Consumer Number',
      'Team Name',
      'Team Expense (₹)',
      'Expense Date',
      'Remarks',
    ];
    sheet3.appendRow(sheet3Headers.map((h) => TextCellValue(h)).toList());
    final headerRowIdx3 = 3;
    for (int c = 0; c < sheet3Headers.length; c++) {
      sheet3.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: headerRowIdx3)).cellStyle = headerStyle;
    }

    // Detailed Team Rows: each customer's team expense listed separately
    int detailSrNo = 1;
    int rowCounter3 = headerRowIdx3 + 1;
    for (final e in expenses) {
      // 1. Wiring Team
      sheet3.appendRow([
        IntCellValue(detailSrNo++),
        TextCellValue(e.customerName),
        TextCellValue(e.consumerNo),
        TextCellValue('Wiring Team'),
        TextCellValue(_currencyFormatter.format(e.wiringExpense)),
        TextCellValue(e.formattedDate),
        TextCellValue(e.remarks ?? '—'),
      ]);
      sheet3.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: rowCounter3++)).cellStyle = currencyStyle;

      // 2. Civil Team
      sheet3.appendRow([
        IntCellValue(detailSrNo++),
        TextCellValue(e.customerName),
        TextCellValue(e.consumerNo),
        TextCellValue('Civil Team'),
        TextCellValue(_currencyFormatter.format(e.civilExpense)),
        TextCellValue(e.formattedDate),
        TextCellValue(e.remarks ?? '—'),
      ]);
      sheet3.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: rowCounter3++)).cellStyle = currencyStyle;

      // 3. Structure Team
      sheet3.appendRow([
        IntCellValue(detailSrNo++),
        TextCellValue(e.customerName),
        TextCellValue(e.consumerNo),
        TextCellValue('Structure Team'),
        TextCellValue(_currencyFormatter.format(e.structureExpense)),
        TextCellValue(e.formattedDate),
        TextCellValue(e.remarks ?? '—'),
      ]);
      sheet3.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: rowCounter3++)).cellStyle = currencyStyle;
    }

    // Grand Total Row in Sheet 3
    sheet3.appendRow([
      TextCellValue(''),
      TextCellValue('GRAND TOTAL'),
      TextCellValue('${expenses.length} Sites (${(expenses.length * 3)} Team Rows)'),
      TextCellValue('All Teams'),
      TextCellValue(_currencyFormatter.format(summary.grandTotalExpense)),
      TextCellValue(''),
      TextCellValue(''),
    ]);
    final totalRowIdx3 = rowCounter3;
    for (int c = 0; c < sheet3Headers.length; c++) {
      sheet3.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: totalRowIdx3)).cellStyle = totalRowStyle;
    }

    // Column widths for Sheet 3
    final s3Widths = [10.0, 26.0, 18.0, 20.0, 22.0, 15.0, 25.0];
    for (int c = 0; c < s3Widths.length; c++) {
      sheet3.setColumnWidth(c, s3Widths[c]);
    }

    // =========================================================================
    // SHEET 4: Pending Expenses Sites (Customers awaiting team expense entry)
    // =========================================================================
    if (pendingConsumers != null && pendingConsumers.isNotEmpty) {
      const sheet4Name = 'Pending Expenses Sites';
      final sheet4 = excel[sheet4Name];

      // Title & Metadata
      sheet4.appendRow([TextCellValue('SIYA INFOTECH & SOLAR ENERGY - SITES PENDING TEAM EXPENSE ENTRY')]);
      sheet4.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0)).cellStyle = titleStyle;

      sheet4.appendRow([TextCellValue('Report Generated: $generatedDateStr | Total Pending Sites: ${pendingConsumers.length}')]);
      sheet4.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 1)).cellStyle = metaStyle;
      sheet4.appendRow([TextCellValue('')]);

      final sheet4Headers = [
        'Sr. No.',
        'Customer Name',
        'Consumer Number',
        'Site Location / Village',
        'Solar Capacity',
        'Mobile Number',
        'Expense Status',
        'Action Required',
      ];
      sheet4.appendRow(sheet4Headers.map((h) => TextCellValue(h)).toList());
      for (int c = 0; c < sheet4Headers.length; c++) {
        sheet4.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: 3)).cellStyle = headerStyle;
      }

      int s4Idx = 1;
      int rIdx4 = 4;
      for (final p in pendingConsumers) {
        final loc = p.address ?? p.village ?? '-';
        final cap = p.systemCapacity?.isNotEmpty == true
            ? p.systemCapacity!
            : (p.capacityKw > 0 ? '${p.capacityKw} kW' : '-');
        sheet4.appendRow([
          IntCellValue(s4Idx++),
          TextCellValue(p.name),
          TextCellValue(p.consumerNo),
          TextCellValue(loc),
          TextCellValue(cap),
          TextCellValue(p.mobile ?? '-'),
          TextCellValue('Expense Entry Pending'),
          TextCellValue('Record Wiring, Civil & Structure Expenses'),
        ]);

        final isEven = (rIdx4 % 2 == 0);
        final bg = isEven ? ExcelColor.fromHexString('#FFFBEB') : ExcelColor.white;
        final cellSt = CellStyle(
          fontSize: 10,
          backgroundColorHex: bg,
          verticalAlign: VerticalAlign.Center,
        );
        for (int c = 0; c < sheet4Headers.length; c++) {
          sheet4.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: rIdx4)).cellStyle = cellSt;
        }
        rIdx4++;
      }

      // Sheet 4 column widths
      final s4Widths = [10.0, 26.0, 18.0, 26.0, 16.0, 16.0, 24.0, 36.0];
      for (int c = 0; c < s4Widths.length; c++) {
        sheet4.setColumnWidth(c, s4Widths[c]);
      }
    }

    return excel.save() ?? [];
  }

  /// Prompts user to save the Excel file via FilePicker and records an audit log
  static Future<bool> exportAndSave({
    required List<SiteTeamExpense> expenses,
    List<ConsumerRecord>? pendingConsumers,
    String? filterSummary,
  }) async {
    if (expenses.isEmpty && (pendingConsumers == null || pendingConsumers.isEmpty)) {
      throw Exception('No team expenses or customer records found to export.');
    }

    final bytes = buildExcelWorkbook(
      expenses: expenses,
      pendingConsumers: pendingConsumers,
      filterSummary: filterSummary,
    );

    final dateStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final fileName = 'Siya_Site_Team_Expenses_$dateStr.xlsx';

    final savedPath = await saveFileUniversal(
      bytes: Uint8List.fromList(bytes),
      fileName: fileName,
      dialogTitle: 'Save Team Expense Excel Report',
    );

    if (savedPath != null) {
      await AuditService.logExportRun(
        module: 'Team Expense Calculator',
        recordCount: expenses.length + (pendingConsumers?.length ?? 0),
        filterSummary: filterSummary,
      );
    }

    return savedPath != null;
  }
}
