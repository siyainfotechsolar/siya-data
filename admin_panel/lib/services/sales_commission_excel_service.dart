import 'dart:typed_data';
import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import '../models/sales_commission.dart';
import 'audit_service.dart';

class SalesCommissionExcelService {
  static final NumberFormat _currencyFormatter = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹ ',
    decimalDigits: 2,
  );

  /// Builds a complete multi-sheet Excel workbook containing:
  /// - Sheet 1: Complete Customer Commission List (All customers together)
  /// - Sheet 2: Sales Person-wise Summary
  /// - Sheet 3: Pending Commission
  /// - Sheet 4: Direct Customers
  /// - Sheet 5: Customer-wise Detailed Report
  static List<int> buildExcelWorkbook({
    required List<SalesCommission> commissions,
    String? filterSummary,
  }) {
    final excel = Excel.createExcel();

    // Remove default Sheet1
    excel.delete('Sheet1');

    final summary = CommissionDashboardSummary.fromCommissions(commissions);
    final salesPersonSummaries = CommissionDashboardSummary.buildSalesPersonSummaries(commissions);
    final now = DateTime.now();
    final generatedDateStr = DateFormat('dd/MM/yyyy hh:mm a').format(now);
    final effectiveFilters = (filterSummary != null && filterSummary.isNotEmpty)
        ? filterSummary
        : 'All Records (No Filters)';

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

    // =========================================================================
    // SHEET 1: Complete Customer Commission List
    // =========================================================================
    const sheet1Name = 'Complete Customer List';
    final sheet1 = excel[sheet1Name];

    sheet1.appendRow([TextCellValue('SIYA INFOTECH & SOLAR ENERGY - SALES PERSON COMMISSION MANAGEMENT')]);
    sheet1.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0)).cellStyle = titleStyle;

    sheet1.appendRow([TextCellValue('Report: Complete Customer Commission List | Date: $generatedDateStr | Filters: $effectiveFilters')]);
    sheet1.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 1)).cellStyle = metaStyle;

    sheet1.appendRow([TextCellValue('Total Customers: ${commissions.length} | Sales Person: ${summary.salesPersonCustomers} | Direct: ${summary.directCustomers} | Pending: ${summary.pendingCommissionCustomers}')]);
    sheet1.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 2)).cellStyle = metaStyle;
    sheet1.appendRow([TextCellValue('')]);

    final sheet1Headers = [
      'Sr. No.',
      'Customer Name',
      'Consumer Number',
      'Customer Source',
      'Sales Person',
      'Capacity (kW)',
      'Rate per kW (₹)',
      'Total Commission (₹)',
      'Commission Status',
      'Date',
      'Remarks',
    ];
    sheet1.appendRow(sheet1Headers.map((h) => TextCellValue(h)).toList());
    for (int c = 0; c < sheet1Headers.length; c++) {
      sheet1.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: 4)).cellStyle = headerStyle;
    }

    int s1Idx = 1;
    int rowCounter1 = 5;
    for (final c in commissions) {
      sheet1.appendRow([
        IntCellValue(s1Idx++),
        TextCellValue(c.customerName),
        TextCellValue(c.consumerNo),
        TextCellValue(c.customerSource),
        TextCellValue(c.isDirectCustomer ? '—' : (c.salesPersonName ?? '—')),
        DoubleCellValue(c.capacityKw),
        TextCellValue(c.isDirectCustomer ? '₹ 0.00' : _currencyFormatter.format(c.commissionRatePerKw)),
        TextCellValue(c.isDirectCustomer ? '₹ 0.00' : _currencyFormatter.format(c.totalCommission)),
        TextCellValue(c.commissionStatus),
        TextCellValue(c.formattedDate),
        TextCellValue(c.remarks ?? ''),
      ]);

      final isEven = (rowCounter1 % 2 == 0);
      final bg = isEven ? ExcelColor.fromHexString('#F8FAFC') : ExcelColor.white;
      final cellSt = CellStyle(
        fontSize: 10,
        backgroundColorHex: bg,
        verticalAlign: VerticalAlign.Center,
      );
      for (int col = 0; col < sheet1Headers.length; col++) {
        sheet1.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: rowCounter1)).cellStyle = cellSt;
      }
      rowCounter1++;
    }

    // Grand Total Row Sheet 1
    sheet1.appendRow([
      TextCellValue(''),
      TextCellValue('GRAND TOTAL'),
      TextCellValue('${commissions.length} Customers'),
      TextCellValue(''),
      TextCellValue(''),
      DoubleCellValue(summary.totalInstalledCapacityKw),
      TextCellValue(''),
      TextCellValue(_currencyFormatter.format(summary.totalCommissionAmount)),
      TextCellValue('Pending: ${_currencyFormatter.format(summary.totalPendingCommissionAmount)}'),
      TextCellValue(''),
      TextCellValue(''),
    ]);
    final totalRowIdx1 = rowCounter1;
    for (int c = 0; c < sheet1Headers.length; c++) {
      sheet1.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: totalRowIdx1)).cellStyle = totalRowStyle;
    }

    // Column widths for Sheet 1
    final s1Widths = [10.0, 26.0, 18.0, 18.0, 22.0, 15.0, 18.0, 22.0, 18.0, 14.0, 24.0];
    for (int c = 0; c < s1Widths.length; c++) {
      sheet1.setColumnWidth(c, s1Widths[c]);
    }

    // =========================================================================
    // SHEET 2: Sales Person-wise Summary
    // =========================================================================
    const sheet2Name = 'Sales Person-wise Summary';
    final sheet2 = excel[sheet2Name];

    sheet2.appendRow([TextCellValue('SIYA INFOTECH & SOLAR ENERGY - SALES PERSON COMMISSION SUMMARY')]);
    sheet2.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0)).cellStyle = titleStyle;

    sheet2.appendRow([TextCellValue('Report Generated: $generatedDateStr | Total Sales Persons: ${salesPersonSummaries.length}')]);
    sheet2.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 1)).cellStyle = metaStyle;
    sheet2.appendRow([TextCellValue('')]);

    final sheet2Headers = [
      'Sr. No.',
      'Sales Person Name',
      'Total Customers',
      'Total Capacity (kW)',
      'Total Commission (₹)',
      'Pending Commission (₹)',
      'Completed Commission (₹)',
    ];
    sheet2.appendRow(sheet2Headers.map((h) => TextCellValue(h)).toList());
    for (int c = 0; c < sheet2Headers.length; c++) {
      sheet2.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: 3)).cellStyle = headerStyle;
    }

    int s2Idx = 1;
    int rowCounter2 = 4;
    double spTotalKw = 0.0;
    double spTotalComm = 0.0;
    double spTotalPending = 0.0;
    double spTotalCompleted = 0.0;
    int spTotalCust = 0;

    for (final sp in salesPersonSummaries) {
      spTotalCust += sp.totalCustomers;
      spTotalKw += sp.totalCapacityKw;
      spTotalComm += sp.totalCommission;
      spTotalPending += sp.pendingCommission;
      spTotalCompleted += sp.completedCommission;

      sheet2.appendRow([
        IntCellValue(s2Idx++),
        TextCellValue(sp.salesPersonName),
        IntCellValue(sp.totalCustomers),
        DoubleCellValue(sp.totalCapacityKw),
        TextCellValue(_currencyFormatter.format(sp.totalCommission)),
        TextCellValue(_currencyFormatter.format(sp.pendingCommission)),
        TextCellValue(_currencyFormatter.format(sp.completedCommission)),
      ]);

      final isEven = (rowCounter2 % 2 == 0);
      final bg = isEven ? ExcelColor.fromHexString('#F8FAFC') : ExcelColor.white;
      final cellSt = CellStyle(
        fontSize: 10,
        backgroundColorHex: bg,
        verticalAlign: VerticalAlign.Center,
      );
      for (int col = 0; col < sheet2Headers.length; col++) {
        sheet2.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: rowCounter2)).cellStyle = cellSt;
      }
      rowCounter2++;
    }

    // Grand Total Row Sheet 2
    sheet2.appendRow([
      TextCellValue(''),
      TextCellValue('GRAND TOTAL'),
      IntCellValue(spTotalCust),
      DoubleCellValue(spTotalKw),
      TextCellValue(_currencyFormatter.format(spTotalComm)),
      TextCellValue(_currencyFormatter.format(spTotalPending)),
      TextCellValue(_currencyFormatter.format(spTotalCompleted)),
    ]);
    final totalRowIdx2 = rowCounter2;
    for (int c = 0; c < sheet2Headers.length; c++) {
      sheet2.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: totalRowIdx2)).cellStyle = totalRowStyle;
    }

    // Column widths for Sheet 2
    final s2Widths = [10.0, 28.0, 18.0, 20.0, 24.0, 24.0, 24.0];
    for (int c = 0; c < s2Widths.length; c++) {
      sheet2.setColumnWidth(c, s2Widths[c]);
    }

    // =========================================================================
    // SHEET 3: Pending Commission (Customers with Pending Status)
    // =========================================================================
    const sheet3Name = 'Pending Commission';
    final sheet3 = excel[sheet3Name];

    final pendingList = commissions.where((c) => c.isPending && !c.isDirectCustomer).toList();

    sheet3.appendRow([TextCellValue('SIYA INFOTECH & SOLAR ENERGY - PENDING SALES COMMISSIONS')]);
    sheet3.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0)).cellStyle = titleStyle;

    sheet3.appendRow([TextCellValue('Report Generated: $generatedDateStr | Pending Customers: ${pendingList.length} | Pending Amount: ${_currencyFormatter.format(summary.totalPendingCommissionAmount)}')]);
    sheet3.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 1)).cellStyle = metaStyle;
    sheet3.appendRow([TextCellValue('')]);

    final sheet3Headers = [
      'Sr. No.',
      'Customer Name',
      'Consumer Number',
      'Sales Person',
      'Capacity (kW)',
      'Rate per kW (₹)',
      'Pending Commission (₹)',
      'Date',
      'Remarks',
    ];
    sheet3.appendRow(sheet3Headers.map((h) => TextCellValue(h)).toList());
    for (int c = 0; c < sheet3Headers.length; c++) {
      sheet3.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: 3)).cellStyle = headerStyle;
    }

    int s3Idx = 1;
    int rowCounter3 = 4;
    double pendingKwSum = 0.0;
    double pendingAmountSum = 0.0;

    for (final p in pendingList) {
      pendingKwSum += p.capacityKw;
      pendingAmountSum += p.totalCommission;

      sheet3.appendRow([
        IntCellValue(s3Idx++),
        TextCellValue(p.customerName),
        TextCellValue(p.consumerNo),
        TextCellValue(p.salesPersonName ?? '—'),
        DoubleCellValue(p.capacityKw),
        TextCellValue(_currencyFormatter.format(p.commissionRatePerKw)),
        TextCellValue(_currencyFormatter.format(p.totalCommission)),
        TextCellValue(p.formattedDate),
        TextCellValue(p.remarks ?? ''),
      ]);

      final isEven = (rowCounter3 % 2 == 0);
      final bg = isEven ? ExcelColor.fromHexString('#FFFBEB') : ExcelColor.white;
      final cellSt = CellStyle(
        fontSize: 10,
        backgroundColorHex: bg,
        verticalAlign: VerticalAlign.Center,
      );
      for (int col = 0; col < sheet3Headers.length; col++) {
        sheet3.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: rowCounter3)).cellStyle = cellSt;
      }
      rowCounter3++;
    }

    // Grand Total Row Sheet 3
    sheet3.appendRow([
      TextCellValue(''),
      TextCellValue('TOTAL PENDING'),
      TextCellValue('${pendingList.length} Customers'),
      TextCellValue(''),
      DoubleCellValue(pendingKwSum),
      TextCellValue(''),
      TextCellValue(_currencyFormatter.format(pendingAmountSum)),
      TextCellValue(''),
      TextCellValue(''),
    ]);
    final totalRowIdx3 = rowCounter3;
    for (int c = 0; c < sheet3Headers.length; c++) {
      sheet3.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: totalRowIdx3)).cellStyle = totalRowStyle;
    }

    // Column widths for Sheet 3
    final s3Widths = [10.0, 26.0, 18.0, 22.0, 16.0, 18.0, 24.0, 14.0, 24.0];
    for (int c = 0; c < s3Widths.length; c++) {
      sheet3.setColumnWidth(c, s3Widths[c]);
    }

    // =========================================================================
    // SHEET 4: Direct Customers (Zero Commission, Not Applicable)
    // =========================================================================
    const sheet4Name = 'Direct Customers';
    final sheet4 = excel[sheet4Name];

    final directList = commissions.where((c) => c.isDirectCustomer).toList();

    sheet4.appendRow([TextCellValue('SIYA INFOTECH & SOLAR ENERGY - DIRECT CUSTOMERS (NO COMMISSION)')]);
    sheet4.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0)).cellStyle = titleStyle;

    sheet4.appendRow([TextCellValue('Report Generated: $generatedDateStr | Total Direct Customers: ${directList.length} | Commission: ₹0.00 (Not Applicable)')]);
    sheet4.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 1)).cellStyle = metaStyle;
    sheet4.appendRow([TextCellValue('')]);

    final sheet4Headers = [
      'Sr. No.',
      'Customer Name',
      'Consumer Number',
      'Site Location',
      'Capacity (kW)',
      'Customer Source',
      'Commission Amount (₹)',
      'Commission Status',
      'Remarks',
    ];
    sheet4.appendRow(sheet4Headers.map((h) => TextCellValue(h)).toList());
    for (int c = 0; c < sheet4Headers.length; c++) {
      sheet4.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: 3)).cellStyle = headerStyle;
    }

    int s4Idx = 1;
    int rowCounter4 = 4;
    double directKwSum = 0.0;

    for (final d in directList) {
      directKwSum += d.capacityKw;

      sheet4.appendRow([
        IntCellValue(s4Idx++),
        TextCellValue(d.customerName),
        TextCellValue(d.consumerNo),
        TextCellValue(d.siteLocation),
        DoubleCellValue(d.capacityKw),
        TextCellValue('Direct Customer'),
        TextCellValue('₹ 0.00'),
        TextCellValue('Not Applicable'),
        TextCellValue(d.remarks ?? ''),
      ]);

      final isEven = (rowCounter4 % 2 == 0);
      final bg = isEven ? ExcelColor.fromHexString('#F0FDF4') : ExcelColor.white;
      final cellSt = CellStyle(
        fontSize: 10,
        backgroundColorHex: bg,
        verticalAlign: VerticalAlign.Center,
      );
      for (int col = 0; col < sheet4Headers.length; col++) {
        sheet4.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: rowCounter4)).cellStyle = cellSt;
      }
      rowCounter4++;
    }

    // Summary Row Sheet 4
    sheet4.appendRow([
      TextCellValue(''),
      TextCellValue('TOTAL DIRECT CUSTOMERS'),
      TextCellValue('${directList.length} Customers'),
      TextCellValue(''),
      DoubleCellValue(directKwSum),
      TextCellValue('Direct'),
      TextCellValue('₹ 0.00'),
      TextCellValue('Not Applicable'),
      TextCellValue(''),
    ]);
    final totalRowIdx4 = rowCounter4;
    for (int c = 0; c < sheet4Headers.length; c++) {
      sheet4.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: totalRowIdx4)).cellStyle = totalRowStyle;
    }

    // Column widths for Sheet 4
    final s4Widths = [10.0, 26.0, 18.0, 24.0, 16.0, 18.0, 22.0, 18.0, 24.0];
    for (int c = 0; c < s4Widths.length; c++) {
      sheet4.setColumnWidth(c, s4Widths[c]);
    }

    // =========================================================================
    // SHEET 5: Customer-wise Detailed Report
    // =========================================================================
    const sheet5Name = 'Customer-wise Detailed Report';
    final sheet5 = excel[sheet5Name];

    sheet5.appendRow([TextCellValue('SIYA INFOTECH & SOLAR ENERGY - CUSTOMER-WISE DETAILED COMMISSION REPORT')]);
    sheet5.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0)).cellStyle = titleStyle;

    sheet5.appendRow([TextCellValue('Report Generated: $generatedDateStr | Total Records: ${commissions.length} | Grand Total Commission: ${_currencyFormatter.format(summary.totalCommissionAmount)}')]);
    sheet5.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 1)).cellStyle = metaStyle;
    sheet5.appendRow([TextCellValue('')]);

    final sheet5Headers = [
      'Sr. No.',
      'Customer Name',
      'Consumer Number',
      'Site Location',
      'Solar Capacity',
      'Capacity (kW)',
      'Customer Source',
      'Sales Person',
      'Commission Rate / kW (₹)',
      'Total Commission (₹)',
      'Commission Status',
      'Commission Date',
      'Remarks',
    ];
    sheet5.appendRow(sheet5Headers.map((h) => TextCellValue(h)).toList());
    for (int c = 0; c < sheet5Headers.length; c++) {
      sheet5.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: 3)).cellStyle = headerStyle;
    }

    int s5Idx = 1;
    int rowCounter5 = 4;

    for (final c in commissions) {
      sheet5.appendRow([
        IntCellValue(s5Idx++),
        TextCellValue(c.customerName),
        TextCellValue(c.consumerNo),
        TextCellValue(c.siteLocation),
        TextCellValue(c.solarCapacity),
        DoubleCellValue(c.capacityKw),
        TextCellValue(c.customerSource),
        TextCellValue(c.isDirectCustomer ? '—' : (c.salesPersonName ?? '—')),
        TextCellValue(c.isDirectCustomer ? '₹ 0.00' : _currencyFormatter.format(c.commissionRatePerKw)),
        TextCellValue(c.isDirectCustomer ? '₹ 0.00' : _currencyFormatter.format(c.totalCommission)),
        TextCellValue(c.commissionStatus),
        TextCellValue(c.formattedDate),
        TextCellValue(c.remarks ?? ''),
      ]);

      final isEven = (rowCounter5 % 2 == 0);
      final bg = isEven ? ExcelColor.fromHexString('#F8FAFC') : ExcelColor.white;
      final cellSt = CellStyle(
        fontSize: 10,
        backgroundColorHex: bg,
        verticalAlign: VerticalAlign.Center,
      );
      for (int col = 0; col < sheet5Headers.length; col++) {
        sheet5.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: rowCounter5)).cellStyle = cellSt;
      }
      rowCounter5++;
    }

    // Grand Total Row Sheet 5
    sheet5.appendRow([
      TextCellValue(''),
      TextCellValue('GRAND TOTAL'),
      TextCellValue('${commissions.length} Sites'),
      TextCellValue(''),
      TextCellValue(''),
      DoubleCellValue(summary.totalInstalledCapacityKw),
      TextCellValue(''),
      TextCellValue(''),
      TextCellValue(''),
      TextCellValue(_currencyFormatter.format(summary.totalCommissionAmount)),
      TextCellValue('Pending: ${_currencyFormatter.format(summary.totalPendingCommissionAmount)}'),
      TextCellValue(''),
      TextCellValue(''),
    ]);
    final totalRowIdx5 = rowCounter5;
    for (int c = 0; c < sheet5Headers.length; c++) {
      sheet5.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: totalRowIdx5)).cellStyle = totalRowStyle;
    }

    // Column widths for Sheet 5
    final s5Widths = [10.0, 26.0, 18.0, 24.0, 16.0, 15.0, 18.0, 22.0, 22.0, 22.0, 18.0, 16.0, 24.0];
    for (int c = 0; c < s5Widths.length; c++) {
      sheet5.setColumnWidth(c, s5Widths[c]);
    }

    return excel.save() ?? [];
  }

  /// Prompts user to save the Excel file via FilePicker and records an audit log
  static Future<bool> exportAndSave({
    required List<SalesCommission> commissions,
    String? filterSummary,
  }) async {
    if (commissions.isEmpty) {
      throw Exception('No commission records found to export.');
    }

    final bytes = buildExcelWorkbook(
      commissions: commissions,
      filterSummary: filterSummary,
    );

    final dateStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final fileName = 'Siya_Sales_Commissions_$dateStr.xlsx';

    final result = await FilePicker.platform.saveFile(
      dialogTitle: 'Save Sales Person Commission Excel Report',
      fileName: fileName,
      bytes: Uint8List.fromList(bytes),
      type: FileType.custom,
      allowedExtensions: ['xlsx'],
    );

    if (result != null) {
      await AuditService.logExportRun(
        module: 'Sales Person Commission Management',
        recordCount: commissions.length,
        filterSummary: filterSummary,
      );
    }

    return result != null;
  }
}
