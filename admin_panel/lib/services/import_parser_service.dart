import 'dart:convert';
import 'dart:typed_data';
import 'package:csv/csv.dart';
import 'package:excel/excel.dart';
import '../models/consumer_record.dart';

/// Holds the raw tabular data parsed from an uploaded file
class RawImportData {
  final String fileName;
  final int fileSizeBytes;
  final List<String> headers;
  final List<List<String>> rows;

  RawImportData({
    required this.fileName,
    required this.fileSizeBytes,
    required this.headers,
    required this.rows,
  });

  int get totalRows => rows.length;
}

/// Stores field to column-index mappings and update behavior
class ImportColumnMapping {
  int? consumerNoIndex;
  int? nameIndex;
  int? mobileIndex;
  int? addressIndex;
  int? applicationIdIndex;
  int? statusIndex;
  int? remarksIndex;

  /// If true, blank values in imported columns will not overwrite existing database values
  bool ignoreBlankValues;

  ImportColumnMapping({
    this.consumerNoIndex,
    this.nameIndex,
    this.mobileIndex,
    this.addressIndex,
    this.applicationIdIndex,
    this.statusIndex,
    this.remarksIndex,
    this.ignoreBlankValues = true,
  });

  bool get isValid => consumerNoIndex != null && nameIndex != null;

  /// Returns the set of database field keys that are explicitly mapped (not skipped)
  Set<String> get mappedFieldKeys {
    final keys = <String>{};
    if (consumerNoIndex != null) keys.add('consumer_no');
    if (nameIndex != null) keys.add('name');
    if (mobileIndex != null) keys.add('mobile');
    if (addressIndex != null) keys.add('address');
    if (applicationIdIndex != null) keys.add('application_id');
    if (statusIndex != null) keys.add('status');
    if (remarksIndex != null) keys.add('remarks');
    return keys;
  }

  /// Check if a specific database field key is mapped for import/update
  bool isFieldMapped(String fieldKey) => mappedFieldKeys.contains(fieldKey);
}

/// Represents a validated row ready for preview or import
class ValidatedImportRow {
  final int rowNumber;
  final String consumerNo;
  final String name;
  final String? mobile;
  final String? address;
  final String? applicationId;
  final String status;
  final String? remarks;
  final List<String> errors;
  final bool isDuplicateInFile;

  ValidatedImportRow({
    required this.rowNumber,
    required this.consumerNo,
    required this.name,
    this.mobile,
    this.address,
    this.applicationId,
    required this.status,
    this.remarks,
    this.errors = const [],
    this.isDuplicateInFile = false,
  });

  bool get isValid => errors.isEmpty && !isDuplicateInFile;

  ConsumerRecord toConsumerRecord() {
    return ConsumerRecord(
      consumerNo: consumerNo,
      name: name,
      mobile: mobile,
      address: address,
      applicationId: applicationId,
      status: status.isEmpty ? 'Pending' : status,
      remarks: remarks,
    );
  }
}

/// Validation report summarizing the file readiness
class ImportValidationReport {
  final List<ValidatedImportRow> rows;
  final int totalRows;
  final int validRowsCount;
  final int invalidRowsCount;
  final int duplicateCount;

  ImportValidationReport({
    required this.rows,
    required this.totalRows,
    required this.validRowsCount,
    required this.invalidRowsCount,
    required this.duplicateCount,
  });
}

class ImportParserService {
  /// Parse file bytes into headers and rows matrix based on file extension
  static Future<RawImportData> parseFile(String fileName, Uint8List bytes) async {
    final lowerName = fileName.toLowerCase();

    if (lowerName.endsWith('.csv')) {
      return _parseCsv(fileName, bytes);
    } else if (lowerName.endsWith('.xlsx') || lowerName.endsWith('.xls')) {
      return _parseExcel(fileName, bytes);
    } else {
      throw Exception('Unsupported file format. Please upload a .xlsx, .xls, or .csv file.');
    }
  }

  /// Parse CSV bytes
  static RawImportData _parseCsv(String fileName, Uint8List bytes) {
    // Try utf8 decode, fallback to latin1 if corrupted
    String csvString;
    try {
      csvString = utf8.decode(bytes);
    } catch (_) {
      csvString = latin1.decode(bytes);
    }

    // Normalize all line endings to \n
    csvString = csvString.replaceAll('\r\n', '\n').replaceAll('\r', '\n');

    const converter = CsvToListConverter(eol: '\n', shouldParseNumbers: false);
    final rawList = converter.convert(csvString);

    if (rawList.isEmpty) {
      throw Exception('The selected CSV file is empty.');
    }

    final headers = rawList.first
        .map((e) => e?.toString().trim() ?? '')
        .where((h) => h.isNotEmpty)
        .toList();
    final headerCount = headers.length;

    final rows = <List<String>>[];
    for (int i = 1; i < rawList.length; i++) {
      final row = rawList[i];
      // Take only up to headerCount cells and stringify
      final rowCells = <String>[];
      for (int c = 0; c < headerCount; c++) {
        if (c < row.length) {
          rowCells.add(row[c]?.toString().trim() ?? '');
        } else {
          rowCells.add('');
        }
      }

      // Skip completely empty rows
      if (rowCells.any((c) => c.isNotEmpty)) {
        rows.add(rowCells);
      }
    }

    return RawImportData(
      fileName: fileName,
      fileSizeBytes: bytes.length,
      headers: headers,
      rows: rows,
    );
  }

  /// Parse Excel (.xlsx / .xls) bytes
  static RawImportData _parseExcel(String fileName, Uint8List bytes) {
    final excel = Excel.decodeBytes(bytes);
    if (excel.tables.isEmpty) {
      throw Exception('No sheets found in Excel file.');
    }

    // Use the first active/available sheet with data
    Sheet? activeSheet;
    for (final table in excel.tables.keys) {
      final sheet = excel.tables[table];
      if (sheet != null && sheet.rows.isNotEmpty) {
        activeSheet = sheet;
        break;
      }
    }

    if (activeSheet == null || activeSheet.rows.isEmpty) {
      throw Exception('Excel sheet is empty.');
    }

    // Extract headers from the first row
    final headerRow = activeSheet.rows.first;
    final headers = <String>[];
    for (final cell in headerRow) {
      final val = _extractCellValue(cell);
      if (val.isNotEmpty) {
        headers.add(val);
      }
    }

    if (headers.isEmpty) {
      throw Exception('Could not find valid column headers in the first row of the Excel sheet.');
    }

    final headerCount = headers.length;
    final rows = <List<String>>[];

    for (int i = 1; i < activeSheet.rows.length; i++) {
      final row = activeSheet.rows[i];
      final rowCells = <String>[];

      for (int c = 0; c < headerCount; c++) {
        if (c < row.length) {
          rowCells.add(_extractCellValue(row[c]));
        } else {
          rowCells.add('');
        }
      }

      // Check if row has any content
      if (rowCells.any((cell) => cell.isNotEmpty)) {
        rows.add(rowCells);
      }
    }

    return RawImportData(
      fileName: fileName,
      fileSizeBytes: bytes.length,
      headers: headers,
      rows: rows,
    );
  }

  /// Helper to extract string representation from various Excel cell types
  static String _extractCellValue(Data? cell) {
    if (cell == null || cell.value == null) return '';
    final val = cell.value;
    if (val is TextCellValue) {
      return val.value.text?.trim() ?? '';
    } else if (val is IntCellValue) {
      return val.value.toString();
    } else if (val is DoubleCellValue) {
      // Remove trailing zero for clean numbers (e.g., 12345.0 -> 12345)
      final d = val.value;
      if (d == d.toInt()) {
        return d.toInt().toString();
      }
      return d.toString();
    } else if (val is DateCellValue) {
      return '${val.year}-${val.month.toString().padLeft(2, '0')}-${val.day.toString().padLeft(2, '0')}';
    } else if (val is BoolCellValue) {
      return val.value.toString();
    }
    return val.toString().trim();
  }

  /// Automatically detect standard fields by matching header names
  static ImportColumnMapping autoDetectColumns(List<String> headers) {
    final mapping = ImportColumnMapping();

    for (int i = 0; i < headers.length; i++) {
      final h = _normalizeHeader(headers[i]);

      // Consumer No
      if (mapping.consumerNoIndex == null && _matches(h, _consumerNoAliases)) {
        mapping.consumerNoIndex = i;
      }
      // Name
      else if (mapping.nameIndex == null && _matches(h, _nameAliases)) {
        mapping.nameIndex = i;
      }
      // Mobile
      else if (mapping.mobileIndex == null && _matches(h, _mobileAliases)) {
        mapping.mobileIndex = i;
      }
      // Address
      else if (mapping.addressIndex == null && _matches(h, _addressAliases)) {
        mapping.addressIndex = i;
      }
      // Application ID
      else if (mapping.applicationIdIndex == null && _matches(h, _applicationIdAliases)) {
        mapping.applicationIdIndex = i;
      }
      // Status
      else if (mapping.statusIndex == null && _matches(h, _statusAliases)) {
        mapping.statusIndex = i;
      }
      // Remarks
      else if (mapping.remarksIndex == null && _matches(h, _remarksAliases)) {
        mapping.remarksIndex = i;
      }
    }

    return mapping;
  }

  /// Validate rows against mapping and detect errors or duplicates
  static ImportValidationReport validateData(RawImportData data, ImportColumnMapping mapping) {
    final validatedRows = <ValidatedImportRow>[];
    final seenConsumerNos = <String, int>{};

    for (int i = 0; i < data.rows.length; i++) {
      final row = data.rows[i];
      final rowNumber = i + 2; // +2 considering 1-based index and header row

      final consumerNo = _getCellValue(row, mapping.consumerNoIndex);
      final name = _getCellValue(row, mapping.nameIndex);
      final mobile = _getCellValue(row, mapping.mobileIndex);
      final address = _getCellValue(row, mapping.addressIndex);
      final applicationId = _getCellValue(row, mapping.applicationIdIndex);
      final status = _getCellValue(row, mapping.statusIndex);
      final remarks = _getCellValue(row, mapping.remarksIndex);

      final errors = <String>[];

      if (consumerNo.isEmpty) {
        errors.add('Missing Consumer No');
      }

      if (name.isEmpty) {
        errors.add('Missing Consumer Name');
      }

      bool isDuplicateInFile = false;
      if (consumerNo.isNotEmpty) {
        final normalizedNo = consumerNo.toUpperCase();
        if (seenConsumerNos.containsKey(normalizedNo)) {
          isDuplicateInFile = true;
          errors.add('Duplicate Consumer No in file (also in Row ${seenConsumerNos[normalizedNo]})');
        } else {
          seenConsumerNos[normalizedNo] = rowNumber;
        }
      }

      validatedRows.add(ValidatedImportRow(
        rowNumber: rowNumber,
        consumerNo: consumerNo,
        name: name,
        mobile: mobile.isEmpty ? null : mobile,
        address: address.isEmpty ? null : address,
        applicationId: applicationId.isEmpty ? null : applicationId,
        status: status.isEmpty ? 'Pending' : status,
        remarks: remarks.isEmpty ? null : remarks,
        errors: errors,
        isDuplicateInFile: isDuplicateInFile,
      ));
    }

    final validCount = validatedRows.where((r) => r.isValid).length;
    final duplicateCount = validatedRows.where((r) => r.isDuplicateInFile).length;
    final invalidCount = validatedRows.length - validCount;

    return ImportValidationReport(
      rows: validatedRows,
      totalRows: validatedRows.length,
      validRowsCount: validCount,
      invalidRowsCount: invalidCount,
      duplicateCount: duplicateCount,
    );
  }

  static String _getCellValue(List<String> row, int? index) {
    if (index == null || index < 0 || index >= row.length) return '';
    return row[index].trim();
  }

  static String _normalizeHeader(String header) {
    return header.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
  }

  static bool _matches(String normalizedHeader, List<String> aliases) {
    return aliases.any((alias) => normalizedHeader == alias || normalizedHeader.contains(alias));
  }

  static const _consumerNoAliases = [
    'consumerno',
    'consumernumber',
    'cano',
    'canumber',
    'kno',
    'knumber',
    'accountno',
    'accountnumber',
    'consumerid',
    'connectionno',
    'serviceno',
    'meterno',
    'consumer',
  ];

  static const _nameAliases = [
    'consumername',
    'customername',
    'applicantname',
    'beneficiaryname',
    'beneficiary',
    'clientname',
    'name',
  ];

  static const _mobileAliases = [
    'mobileno',
    'mobilenumber',
    'phoneno',
    'phonenumber',
    'contactno',
    'contactnumber',
    'mobile',
    'phone',
    'contact',
    'cellno',
    'cell',
  ];

  static const _addressAliases = [
    'address',
    'fulladdress',
    'premiseaddress',
    'location',
    'village',
    'city',
    'taluka',
    'district',
    'premise',
  ];

  static const _applicationIdAliases = [
    'applicationid',
    'applicationno',
    'appid',
    'registrationno',
    'regno',
    'ackno',
    'acknowledgementno',
    'formno',
  ];

  static const _statusAliases = [
    'installationstatus',
    'currentstatus',
    'stage',
    'status',
  ];

  static const _remarksAliases = [
    'remarks',
    'remark',
    'comments',
    'comment',
    'notes',
    'note',
    'description',
  ];
}
