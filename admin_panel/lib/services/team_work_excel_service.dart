import 'dart:io';
import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import '../models/team_work_expense.dart';
import '../utils/universal_file_saver.dart';
import 'team_work_service.dart';
import 'audit_service.dart';

class TeamWorkExcelService {
  static final NumberFormat _currencyFormatter =
      NumberFormat.currency(locale: 'en_IN', symbol: '₹ ', decimalDigits: 2);
  static final DateFormat _dateFormatter = DateFormat('dd-MM-yyyy');

  /// Builds a complete multi-sheet Excel workbook containing:
  /// - Sheet 1: Detailed Work Entries
  /// - Sheet 2: Person-wise Expense Summary
  /// - Sheet 3: Customer-wise Expense Summary
  /// - Sheet 4: Category-wise Summary
  static Excel generateWorkbook({
    required List<TeamWorkExpense> expenses,
    String? appliedFilterDescription,
    int? customMemberCount,
  }) {
    final excel = Excel.createExcel();
    excel.delete('Sheet1'); // Remove default sheet

    final now = DateTime.now();
    final generatedDateStr = DateFormat('dd-MM-yyyy HH:mm').format(now);
    final effectiveFilters = appliedFilterDescription ?? 'All Records (Unfiltered)';

    final personSummaries = TeamWorkService.buildPersonSummaries(expenses);
    final customerSummaries = TeamWorkService.buildCustomerSummaries(expenses);
    final categorySummaries = TeamWorkService.buildCategorySummaries(expenses);
    final dashboardSummary = TeamWorkDashboardSummary.calculate(expenses, customTeamMemberCount: customMemberCount);

    // -------------------------------------------------------------------------
    // STYLES
    // -------------------------------------------------------------------------
    final titleStyle = CellStyle(
      bold: true,
      fontSize: 14,
      fontColorHex: ExcelColor.fromHexString('#1E3A8A'),
    );

    final metaStyle = CellStyle(
      fontSize: 10,
      italic: true,
      fontColorHex: ExcelColor.fromHexString('#4B5563'),
    );

    final headerStyle = CellStyle(
      bold: true,
      fontSize: 11,
      fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
      backgroundColorHex: ExcelColor.fromHexString('#1E3A8A'),
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
    );

    final totalRowStyle = CellStyle(
      bold: true,
      fontSize: 11,
      fontColorHex: ExcelColor.fromHexString('#064E3B'),
      backgroundColorHex: ExcelColor.fromHexString('#D1FAE5'),
    );

    final currencyStyle = CellStyle(
      horizontalAlign: HorizontalAlign.Right,
    );

    // =========================================================================
    // SHEET 1: DETAILED WORK ENTRIES
    // =========================================================================
    const sheet1Name = 'Detailed Work Entries';
    final sheet1 = excel[sheet1Name];
    excel.setDefaultSheet(sheet1Name);

    sheet1.appendRow([TextCellValue('SIYA INFOTECH & SOLAR ENERGY — DETAILED TEAM WORK ENTRIES')]);
    sheet1.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0)).cellStyle = titleStyle;

    sheet1.appendRow([TextCellValue('Generated: $generatedDateStr | Filters: $effectiveFilters')]);
    sheet1.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 1)).cellStyle = metaStyle;

    sheet1.appendRow([TextCellValue('Total Entries: ${expenses.length} | Grand Total: ${_currencyFormatter.format(dashboardSummary.grandTotalExpense)}')]);
    sheet1.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 2)).cellStyle = metaStyle;
    sheet1.appendRow([TextCellValue('')]);

    final s1Headers = [
      'Sr. No.',
      'Work Date',
      'Customer Name',
      'Consumer Number',
      'Site Location',
      'Team Member Name',
      'Work Category',
      'Individual Expense (₹)',
      'Remarks',
    ];

    sheet1.appendRow(s1Headers.map((h) => TextCellValue(h)).toList());
    final headerRowIdx1 = 4;
    for (int c = 0; c < s1Headers.length; c++) {
      sheet1.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: headerRowIdx1)).cellStyle = headerStyle;
    }

    double s1TotalExp = 0.0;
    int rowCounter1 = headerRowIdx1 + 1;

    for (int i = 0; i < expenses.length; i++) {
      final e = expenses[i];
      s1TotalExp += e.individualExpense;

      sheet1.appendRow([
        IntCellValue(i + 1),
        TextCellValue(_dateFormatter.format(e.workDate)),
        TextCellValue(e.customerName),
        TextCellValue(e.consumerNo),
        TextCellValue(e.siteLocation.isNotEmpty ? e.siteLocation : '-'),
        TextCellValue(e.teamMemberName),
        TextCellValue(e.workCategory),
        DoubleCellValue(e.individualExpense),
        TextCellValue(e.remarks.isNotEmpty ? e.remarks : '-'),
      ]);

      sheet1.cell(CellIndex.indexByColumnRow(columnIndex: 7, rowIndex: rowCounter1)).cellStyle = currencyStyle;
      rowCounter1++;
    }

    // Grand Total Row in Sheet 1
    sheet1.appendRow([
      TextCellValue('GRAND TOTAL'),
      TextCellValue(''),
      TextCellValue(''),
      TextCellValue(''),
      TextCellValue(''),
      TextCellValue(''),
      TextCellValue(''),
      DoubleCellValue(s1TotalExp),
      TextCellValue(''),
    ]);
    final totalRowIdx1 = rowCounter1;
    for (int c = 0; c < s1Headers.length; c++) {
      sheet1.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: totalRowIdx1)).cellStyle = totalRowStyle;
    }

    // Auto widths for Sheet 1
    final s1Widths = [8.0, 13.0, 28.0, 18.0, 24.0, 18.0, 14.0, 18.0, 25.0];
    for (int c = 0; c < s1Widths.length; c++) {
      sheet1.setColumnWidth(c, s1Widths[c]);
    }

    // =========================================================================
    // SHEET 2: PERSON-WISE EXPENSE SUMMARY
    // =========================================================================
    const sheet2Name = 'Person-wise Summary';
    final sheet2 = excel[sheet2Name];

    sheet2.appendRow([TextCellValue('SIYA INFOTECH & SOLAR ENERGY — PERSON-WISE WORK EXPENSE SUMMARY')]);
    sheet2.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0)).cellStyle = titleStyle;

    sheet2.appendRow([TextCellValue('Generated: $generatedDateStr | Filters: $effectiveFilters')]);
    sheet2.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 1)).cellStyle = metaStyle;
    sheet2.appendRow([TextCellValue('')]);

    final s2Headers = [
      'Team Member Name',
      'Structure Expense (₹)',
      'Wiring Expense (₹)',
      'Civil Expense (₹)',
      'Total Expense (₹)',
      'Total Sites',
    ];

    sheet2.appendRow(s2Headers.map((h) => TextCellValue(h)).toList());
    final headerRowIdx2 = 3;
    for (int c = 0; c < s2Headers.length; c++) {
      sheet2.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: headerRowIdx2)).cellStyle = headerStyle;
    }

    int rowCounter2 = headerRowIdx2 + 1;
    double s2TotStruct = 0.0;
    double s2TotWire = 0.0;
    double s2TotCiv = 0.0;
    double s2GrandTot = 0.0;

    for (final p in personSummaries) {
      s2TotStruct += p.structureExpense;
      s2TotWire += p.wiringExpense;
      s2TotCiv += p.civilExpense;
      s2GrandTot += p.totalExpense;

      sheet2.appendRow([
        TextCellValue(p.teamMemberName),
        DoubleCellValue(p.structureExpense),
        DoubleCellValue(p.wiringExpense),
        DoubleCellValue(p.civilExpense),
        DoubleCellValue(p.totalExpense),
        IntCellValue(p.totalSites),
      ]);

      sheet2.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: rowCounter2)).cellStyle = currencyStyle;
      sheet2.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: rowCounter2)).cellStyle = currencyStyle;
      sheet2.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: rowCounter2)).cellStyle = currencyStyle;
      sheet2.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: rowCounter2)).cellStyle = currencyStyle;
      rowCounter2++;
    }

    // Grand Total Row in Sheet 2
    sheet2.appendRow([
      TextCellValue('GRAND TOTAL'),
      DoubleCellValue(s2TotStruct),
      DoubleCellValue(s2TotWire),
      DoubleCellValue(s2TotCiv),
      DoubleCellValue(s2GrandTot),
      IntCellValue(dashboardSummary.totalSites),
    ]);
    final totalRowIdx2 = rowCounter2;
    for (int c = 0; c < s2Headers.length; c++) {
      sheet2.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: totalRowIdx2)).cellStyle = totalRowStyle;
    }

    final s2Widths = [22.0, 20.0, 20.0, 18.0, 20.0, 14.0];
    for (int c = 0; c < s2Widths.length; c++) {
      sheet2.setColumnWidth(c, s2Widths[c]);
    }

    // =========================================================================
    // SHEET 3: CUSTOMER-WISE EXPENSE SUMMARY
    // =========================================================================
    const sheet3Name = 'Customer-wise Summary';
    final sheet3 = excel[sheet3Name];

    sheet3.appendRow([TextCellValue('SIYA INFOTECH & SOLAR ENERGY — CUSTOMER-WISE EXPENSE SUMMARY')]);
    sheet3.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0)).cellStyle = titleStyle;

    sheet3.appendRow([TextCellValue('Generated: $generatedDateStr | Filters: $effectiveFilters')]);
    sheet3.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 1)).cellStyle = metaStyle;
    sheet3.appendRow([TextCellValue('')]);

    final s3Headers = [
      'Customer Name',
      'Consumer Number',
      'Structure Expense (₹)',
      'Wiring Expense (₹)',
      'Civil Expense (₹)',
      'Total Site Expense (₹)',
    ];

    sheet3.appendRow(s3Headers.map((h) => TextCellValue(h)).toList());
    final headerRowIdx3 = 3;
    for (int c = 0; c < s3Headers.length; c++) {
      sheet3.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: headerRowIdx3)).cellStyle = headerStyle;
    }

    int rowCounter3 = headerRowIdx3 + 1;
    double s3TotStruct = 0.0;
    double s3TotWire = 0.0;
    double s3TotCiv = 0.0;
    double s3GrandTot = 0.0;

    for (final c in customerSummaries) {
      s3TotStruct += c.structureExpense;
      s3TotWire += c.wiringExpense;
      s3TotCiv += c.civilExpense;
      s3GrandTot += c.totalSiteExpense;

      sheet3.appendRow([
        TextCellValue(c.customerName),
        TextCellValue(c.consumerNo),
        DoubleCellValue(c.structureExpense),
        DoubleCellValue(c.wiringExpense),
        DoubleCellValue(c.civilExpense),
        DoubleCellValue(c.totalSiteExpense),
      ]);

      sheet3.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: rowCounter3)).cellStyle = currencyStyle;
      sheet3.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: rowCounter3)).cellStyle = currencyStyle;
      sheet3.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: rowCounter3)).cellStyle = currencyStyle;
      sheet3.cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: rowCounter3)).cellStyle = currencyStyle;
      rowCounter3++;
    }

    // Grand Total Row in Sheet 3
    sheet3.appendRow([
      TextCellValue('GRAND TOTAL'),
      TextCellValue('${customerSummaries.length} Sites'),
      DoubleCellValue(s3TotStruct),
      DoubleCellValue(s3TotWire),
      DoubleCellValue(s3TotCiv),
      DoubleCellValue(s3GrandTot),
    ]);
    final totalRowIdx3 = rowCounter3;
    for (int c = 0; c < s3Headers.length; c++) {
      sheet3.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: totalRowIdx3)).cellStyle = totalRowStyle;
    }

    final s3Widths = [28.0, 18.0, 20.0, 20.0, 18.0, 22.0];
    for (int c = 0; c < s3Widths.length; c++) {
      sheet3.setColumnWidth(c, s3Widths[c]);
    }

    // =========================================================================
    // SHEET 4: CATEGORY-WISE SUMMARY
    // =========================================================================
    const sheet4Name = 'Category-wise Summary';
    final sheet4 = excel[sheet4Name];

    sheet4.appendRow([TextCellValue('SIYA INFOTECH & SOLAR ENERGY — WORK CATEGORY EXPENSE SUMMARY')]);
    sheet4.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0)).cellStyle = titleStyle;

    sheet4.appendRow([TextCellValue('Generated: $generatedDateStr | Filters: $effectiveFilters')]);
    sheet4.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 1)).cellStyle = metaStyle;
    sheet4.appendRow([TextCellValue('')]);

    final s4Headers = [
      'Work Category',
      'Total Workers',
      'Total Sites',
      'Total Expense (₹)',
    ];

    sheet4.appendRow(s4Headers.map((h) => TextCellValue(h)).toList());
    final headerRowIdx4 = 3;
    for (int c = 0; c < s4Headers.length; c++) {
      sheet4.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: headerRowIdx4)).cellStyle = headerStyle;
    }

    int rowCounter4 = headerRowIdx4 + 1;
    double s4GrandTot = 0.0;

    for (final cat in categorySummaries) {
      s4GrandTot += cat.totalExpense;

      sheet4.appendRow([
        TextCellValue(cat.workCategory),
        IntCellValue(cat.totalWorkers),
        IntCellValue(cat.totalSites),
        DoubleCellValue(cat.totalExpense),
      ]);

      sheet4.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: rowCounter4)).cellStyle = currencyStyle;
      rowCounter4++;
    }

    // Grand Total Row in Sheet 4
    sheet4.appendRow([
      TextCellValue('GRAND TOTAL'),
      IntCellValue(dashboardSummary.totalTeamMembers),
      IntCellValue(dashboardSummary.totalSites),
      DoubleCellValue(s4GrandTot),
    ]);
    final totalRowIdx4 = rowCounter4;
    for (int c = 0; c < s4Headers.length; c++) {
      sheet4.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: totalRowIdx4)).cellStyle = totalRowStyle;
    }

    final s4Widths = [20.0, 16.0, 16.0, 22.0];
    for (int c = 0; c < s4Widths.length; c++) {
      sheet4.setColumnWidth(c, s4Widths[c]);
    }

    return excel;
  }

  /// Exports and prompts user to save the Excel file
  static Future<String?> exportAndSave({
    required List<TeamWorkExpense> expenses,
    String? appliedFilterDescription,
    int? customMemberCount,
  }) async {
    final excel = generateWorkbook(
      expenses: expenses,
      appliedFilterDescription: appliedFilterDescription,
      customMemberCount: customMemberCount,
    );

    final bytes = excel.encode();
    if (bytes == null) {
      throw Exception('Failed to encode Excel file.');
    }

    final dateStr = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
    final defaultFileName = 'SiyaSolar_TeamWork_Expenses_$dateStr.xlsx';

    final savedPath = await saveFileUniversal(
      bytes: Uint8List.fromList(bytes),
      fileName: defaultFileName,
      dialogTitle: 'Save Team Work & Expense Excel Report',
    );

    if (savedPath != null) {
      await AuditService.logExportRun(
        module: 'Team Work & Individual Expense Management',
        recordCount: expenses.length,
        filterSummary: 'Exported $defaultFileName (${expenses.length} records, 4 sheets)',
      );
    }
    return savedPath;
  }
}
