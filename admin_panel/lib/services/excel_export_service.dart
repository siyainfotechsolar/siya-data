import 'package:flutter/foundation.dart';
import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';

class ExcelColumnDef<T> {
  final String header;
  final dynamic Function(T item) valueExtractor;

  const ExcelColumnDef({
    required this.header,
    required this.valueExtractor,
  });
}

class ExcelExportService {
  /// Generate a standard, formatted .xlsx file from any list of items
  static List<int> buildExcelDocument<T>({
    required String sheetName,
    required List<ExcelColumnDef<T>> columns,
    required List<T> items,
  }) {
    final excel = Excel.createExcel();
    final sanitizedSheetName = sheetName.replaceAll(RegExp(r'[\\/?*\[\]:]'), ' ').trim();
    final sheet = excel[sanitizedSheetName.isEmpty ? 'Data' : sanitizedSheetName];
    excel.setDefaultSheet(sanitizedSheetName.isEmpty ? 'Data' : sanitizedSheetName);

    // 1. Header Row
    final headerRow = columns.map((col) => TextCellValue(col.header)).toList();
    sheet.appendRow(headerRow);

    // 2. Data Rows
    for (final item in items) {
      final row = <CellValue>[];
      for (final col in columns) {
        final val = col.valueExtractor(item);
        if (val == null) {
          row.add(TextCellValue('—'));
        } else if (val is num) {
          row.add(DoubleCellValue(val.toDouble()));
        } else if (val is bool) {
          row.add(TextCellValue(val ? 'Yes' : 'No'));
        } else if (val is DateTime) {
          row.add(TextCellValue(DateFormat('dd/MM/yyyy').format(val.toLocal())));
        } else {
          row.add(TextCellValue(val.toString()));
        }
      }
      sheet.appendRow(row);
    }

    return excel.save() ?? [];
  }

  /// Automatically prompt user to save the Excel file
  static Future<bool> exportAndSave<T>({
    required String filePrefix,
    required String sheetName,
    required List<ExcelColumnDef<T>> columns,
    required List<T> items,
  }) async {
    if (items.isEmpty) {
      throw Exception('No data to export.');
    }

    final bytes = buildExcelDocument<T>(
      sheetName: sheetName,
      columns: columns,
      items: items,
    );

    final dateStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final fileName = '${filePrefix}_$dateStr.xlsx';

    final result = await FilePicker.platform.saveFile(
      dialogTitle: 'Save $sheetName Export',
      fileName: fileName,
      bytes: Uint8List.fromList(bytes),
      type: FileType.custom,
      allowedExtensions: ['xlsx'],
    );

    return result != null;
  }
}
