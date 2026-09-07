import 'package:flutter/foundation.dart';
import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'audit_service.dart';

class ExcelColumnDef<T> {
  final String header;
  final dynamic Function(T item) valueExtractor;
  final bool isCurrency;

  const ExcelColumnDef({
    required this.header,
    required this.valueExtractor,
    this.isCurrency = false,
  });
}

class ExcelSheetData<T> {
  final String sheetName;
  final List<ExcelColumnDef<T>> columns;
  final List<T> items;
  final String? reportTitle;
  final String? filterSummary;

  const ExcelSheetData({
    required this.sheetName,
    required this.columns,
    required this.items,
    this.reportTitle,
    this.filterSummary,
  });
}

class ExcelExportService {
  static final NumberFormat _currencyFormatter = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 0,
  );

  /// Format cell values with strict formatting (Currency, Dates, Booleans)
  static CellValue formatCellValue(dynamic val, {bool isCurrency = false}) {
    if (val == null) {
      return TextCellValue('—');
    }
    if (isCurrency && val is num) {
      return TextCellValue(_currencyFormatter.format(val));
    }
    if (val is int) {
      return IntCellValue(val);
    }
    if (val is double) {
      return DoubleCellValue(val);
    }
    if (val is bool) {
      return TextCellValue(val ? 'Yes' : 'No');
    }
    if (val is DateTime) {
      return TextCellValue(DateFormat('dd/MM/yyyy').format(val.toLocal()));
    }
    final s = val.toString();
    return TextCellValue(s.isEmpty ? '—' : s);
  }

  /// Append standard metadata header banner to an Excel sheet
  static void _appendMetadataBanner(
    Sheet sheet, {
    required String title,
    required int totalRecords,
    String? filterSummary,
  }) {
    final now = DateTime.now();
    final formattedDateTime = DateFormat('dd/MM/yyyy hh:mm a').format(now);

    // Row 1: Report Title
    sheet.appendRow([TextCellValue('REPORT: $title')]);
    // Row 2: Generated Date & Time
    sheet.appendRow([TextCellValue('Generated: $formattedDateTime')]);
    // Row 3: Applied Filters
    sheet.appendRow([TextCellValue('Applied Filters: ${filterSummary != null && filterSummary.isNotEmpty ? filterSummary : 'All Records (No Filters)'}')]);
    // Row 4: Total Records
    sheet.appendRow([TextCellValue('Total Records: $totalRecords')]);
    // Row 5: Empty separator row
    sheet.appendRow([TextCellValue('')]);
  }

  /// Generate a standard, formatted .xlsx file from a single list of items
  static List<int> buildExcelDocument<T>({
    required String sheetName,
    required List<ExcelColumnDef<T>> columns,
    required List<T> items,
    String? reportTitle,
    String? filterSummary,
  }) {
    final excel = Excel.createExcel();
    final sanitizedSheetName = sheetName.replaceAll(RegExp(r'[\\/?*\[\]:]'), ' ').trim();
    final finalSheetName = sanitizedSheetName.isEmpty ? 'Data' : sanitizedSheetName;
    final sheet = excel[finalSheetName];
    excel.setDefaultSheet(finalSheetName);

    // 1. Metadata Header Banner
    _appendMetadataBanner(
      sheet,
      title: reportTitle ?? sheetName,
      totalRecords: items.length,
      filterSummary: filterSummary,
    );

    // 2. Table Column Headers
    final headerRow = columns.map((col) => TextCellValue(col.header)).toList();
    sheet.appendRow(headerRow);

    // 3. Data Rows
    for (final item in items) {
      final row = <CellValue>[];
      for (final col in columns) {
        final val = col.valueExtractor(item);
        row.add(formatCellValue(val, isCurrency: col.isCurrency));
      }
      sheet.appendRow(row);
    }

    return excel.save() ?? [];
  }

  /// Generate a multi-sheet .xlsx file (e.g. Complete Customer Report with Loan, Installation, Payment, etc.)
  static List<int> buildMultiSheetExcelDocument(List<ExcelSheetData> sheets) {
    final excel = Excel.createExcel();

    for (int i = 0; i < sheets.length; i++) {
      final s = sheets[i];
      final sanitized = s.sheetName.replaceAll(RegExp(r'[\\/?*\[\]:]'), ' ').trim();
      final finalName = sanitized.isEmpty ? 'Sheet${i + 1}' : sanitized;
      final sheet = excel[finalName];
      if (i == 0) excel.setDefaultSheet(finalName);

      // Metadata Banner
      _appendMetadataBanner(
        sheet,
        title: s.reportTitle ?? s.sheetName,
        totalRecords: s.items.length,
        filterSummary: s.filterSummary,
      );

      // Table Headers
      final headerRow = s.columns.map((col) => TextCellValue(col.header)).toList();
      sheet.appendRow(headerRow);

      // Data Rows
      for (final item in s.items) {
        final row = <CellValue>[];
        for (final col in s.columns) {
          final val = col.valueExtractor(item);
          row.add(formatCellValue(val, isCurrency: col.isCurrency));
        }
        sheet.appendRow(row);
      }
    }

    return excel.save() ?? [];
  }

  /// Automatically prompt user to save the Excel file and record an audit log entry
  static Future<bool> exportAndSave<T>({
    required String filePrefix,
    required String sheetName,
    required List<ExcelColumnDef<T>> columns,
    required List<T> items,
    String? reportTitle,
    String? filterSummary,
  }) async {
    if (items.isEmpty) {
      throw Exception('No data to export.');
    }

    final bytes = buildExcelDocument<T>(
      sheetName: sheetName,
      columns: columns,
      items: items,
      reportTitle: reportTitle,
      filterSummary: filterSummary,
    );

    final dateStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final cleanPrefix = filePrefix.replaceAll(' ', '_');
    final fileName = '${cleanPrefix}_$dateStr.xlsx';

    final result = await FilePicker.platform.saveFile(
      dialogTitle: 'Save $sheetName Export',
      fileName: fileName,
      bytes: Uint8List.fromList(bytes),
      type: FileType.custom,
      allowedExtensions: ['xlsx'],
    );

    if (result != null) {
      // Audit log the export
      await AuditService.logExportRun(
        module: reportTitle ?? sheetName,
        recordCount: items.length,
        filterSummary: filterSummary,
      );
    }

    return result != null;
  }

  /// Export a multi-sheet document and trigger save file dialog
  static Future<bool> exportMultiSheetAndSave({
    required String filePrefix,
    required List<ExcelSheetData> sheets,
    String? reportTitle,
    String? filterSummary,
  }) async {
    if (sheets.isEmpty || sheets.every((s) => s.items.isEmpty)) {
      throw Exception('No data to export across sheets.');
    }

    final bytes = buildMultiSheetExcelDocument(sheets);
    final dateStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final cleanPrefix = filePrefix.replaceAll(' ', '_');
    final fileName = '${cleanPrefix}_$dateStr.xlsx';

    final totalRows = sheets.fold<int>(0, (sum, s) => sum + s.items.length);

    final result = await FilePicker.platform.saveFile(
      dialogTitle: 'Save ${reportTitle ?? 'Report'} Export',
      fileName: fileName,
      bytes: Uint8List.fromList(bytes),
      type: FileType.custom,
      allowedExtensions: ['xlsx'],
    );

    if (result != null) {
      await AuditService.logExportRun(
        module: reportTitle ?? 'Multi-Sheet Report',
        recordCount: totalRows,
        filterSummary: filterSummary,
      );
    }

    return result != null;
  }
}
