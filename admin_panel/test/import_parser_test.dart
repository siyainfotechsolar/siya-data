import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:admin_panel/services/import_parser_service.dart';
import 'package:admin_panel/services/duplicate_detection_service.dart';
import 'package:admin_panel/models/consumer_record.dart';

void main() {
  group('ImportParserService Tests', () {
    test('Correctly parses CSV and auto-detects standard columns', () async {
      const csvData = '''Consumer Number,Customer Name,Phone,Village Address,App ID,Current Status,Notes
CN-1001,Rajesh Patel,9876543210,Ahmedabad,APP-001,Approved,Ready for install
CN-1002,Pooja Sharma,9123456780,Surat,APP-002,Pending,Survey done
''';
      final bytes = Uint8List.fromList(utf8.encode(csvData));
      final parsed = await ImportParserService.parseFile('consumers.csv', bytes);

      expect(parsed.headers.length, 7);
      expect(parsed.rows.length, 2);

      final mapping = ImportParserService.autoDetectColumns(parsed.headers);
      expect(mapping.isValid, isTrue);
      expect(mapping.consumerNoIndex, 0);
      expect(mapping.nameIndex, 1);
      expect(mapping.mobileIndex, 2);
      expect(mapping.addressIndex, 3);
      expect(mapping.applicationIdIndex, 4);
      expect(mapping.statusIndex, 5);
      expect(mapping.remarksIndex, 6);

      final validation = ImportParserService.validateData(parsed, mapping);
      expect(validation.totalRows, 2);
      expect(validation.validRowsCount, 2);
      expect(validation.invalidRowsCount, 0);
      expect(validation.duplicateCount, 0);
    });

    test('Identifies missing required fields and in-file duplicate consumer numbers', () async {
      const csvData = '''Consumer No,Name,Mobile
CN-2001,Ramesh Gupta,9999999999
,Missing Consumer No,8888888888
CN-2003,,7777777777
CN-2001,Duplicate Person,6666666666
''';
      final bytes = Uint8List.fromList(utf8.encode(csvData));
      final parsed = await ImportParserService.parseFile('test.csv', bytes);

      final mapping = ImportParserService.autoDetectColumns(parsed.headers);
      final validation = ImportParserService.validateData(parsed, mapping);

      expect(validation.totalRows, 4);
      expect(validation.validRowsCount, 1); // Only first row is valid
      expect(validation.invalidRowsCount, 3);
      expect(validation.duplicateCount, 1); // Row 4 has duplicate consumer number
    });

    test('Auto-detects MahaDiscom truncated headers and parses DD-MM-YY dates', () async {
      const csvData = '''Application Number,Discom Name,Consumer Numbe,Consumer Name,Mobile No.,Proposed Capacity,Status,Submitted Or
NP-MHSED26-14436435,MSEDCL,097030013003,SHRI. DILIP MAHADU MALI,9325129919,4.000,Subsidy Request,19-08-26
''';
      final bytes = Uint8List.fromList(utf8.encode(csvData));
      final parsed = await ImportParserService.parseFile('msedcl.csv', bytes);

      final mapping = ImportParserService.autoDetectColumns(parsed.headers);
      expect(mapping.consumerNoIndex, equals(2)); // Consumer Numbe
      expect(mapping.nameIndex, equals(3));       // Consumer Name
      expect(mapping.applicationIdIndex, equals(0)); // Application Number
      expect(mapping.submitDateIndex, equals(7));   // Submitted Or

      final validation = ImportParserService.validateData(parsed, mapping);
      expect(validation.validRowsCount, equals(1));
      final row = validation.rows.first;
      expect(row.submitDate, equals(DateTime(2026, 8, 19)));
    });

    test('Parses DD/MM/YYYY date format correctly', () async {
      const csvData = '''Consumer No,Name,Submitted On
CN-3001,Test User,15/08/2026
''';
      final bytes = Uint8List.fromList(utf8.encode(csvData));
      final parsed = await ImportParserService.parseFile('test_dates.csv', bytes);
      final mapping = ImportParserService.autoDetectColumns(parsed.headers);
      final validation = ImportParserService.validateData(parsed, mapping);
      expect(validation.rows.first.submitDate, equals(DateTime(2026, 8, 15)));
    });

    test('Parses date with timestamp (DD/MM/YYYY HH:MM:SS) correctly', () async {
      const csvData = '''Consumer No,Name,Submitted On
CN-3002,Test User,27/08/2026 14:30:00
''';
      final bytes = Uint8List.fromList(utf8.encode(csvData));
      final parsed = await ImportParserService.parseFile('test_ts.csv', bytes);
      final mapping = ImportParserService.autoDetectColumns(parsed.headers);
      final validation = ImportParserService.validateData(parsed, mapping);
      expect(validation.rows.first.submitDate, equals(DateTime(2026, 8, 27)));
    });

    test('Parses DD-MM-YYYY date format correctly', () async {
      const csvData = '''Consumer No,Name,Submit Date
CN-3003,Test User,25-12-2025
''';
      final bytes = Uint8List.fromList(utf8.encode(csvData));
      final parsed = await ImportParserService.parseFile('test_dash.csv', bytes);
      final mapping = ImportParserService.autoDetectColumns(parsed.headers);
      final validation = ImportParserService.validateData(parsed, mapping);
      expect(validation.rows.first.submitDate, equals(DateTime(2025, 12, 25)));
    });

    test('Parses "15 Aug 2026" month name date format', () async {
      const csvData = '''Consumer No,Name,Submitted On
CN-3004,Test User,15 Aug 2026
''';
      final bytes = Uint8List.fromList(utf8.encode(csvData));
      final parsed = await ImportParserService.parseFile('test_month.csv', bytes);
      final mapping = ImportParserService.autoDetectColumns(parsed.headers);
      final validation = ImportParserService.validateData(parsed, mapping);
      expect(validation.rows.first.submitDate, equals(DateTime(2026, 8, 15)));
    });

    test('Parses ISO YYYY-MM-DD date format', () async {
      const csvData = '''Consumer No,Name,Submit Date
CN-3005,Test User,2026-09-01
''';
      final bytes = Uint8List.fromList(utf8.encode(csvData));
      final parsed = await ImportParserService.parseFile('test_iso.csv', bytes);
      final mapping = ImportParserService.autoDetectColumns(parsed.headers);
      final validation = ImportParserService.validateData(parsed, mapping);
      expect(validation.rows.first.submitDate, equals(DateTime(2026, 9, 1)));
    });

    test('Both Application Date and Submit Date are mapped and parsed from CSV', () async {
      const csvData = '''Consumer No,Name,Application Date,Submitted On
CN-3006,Test User,01/07/2026,15/08/2026
''';
      final bytes = Uint8List.fromList(utf8.encode(csvData));
      final parsed = await ImportParserService.parseFile('test_both.csv', bytes);
      final mapping = ImportParserService.autoDetectColumns(parsed.headers);
      expect(mapping.applicationDateIndex, equals(2));
      expect(mapping.submitDateIndex, equals(3));
      final validation = ImportParserService.validateData(parsed, mapping);
      expect(validation.rows.first.applicationDate, equals(DateTime(2026, 7, 1)));
      expect(validation.rows.first.submitDate, equals(DateTime(2026, 8, 15)));
    });
  });

  group('DuplicateDetectionService computeFieldDiffs Tests', () {
    test('Detects submit_date difference between existing and incoming records', () {
      final existing = ConsumerRecord(
        id: 'test-id-1',
        consumerNo: '097030013003',
        name: 'SHRI. DILIP MAHADU MALI',
        status: 'Pending',
        submitDate: null, // No date in database
      );

      final incoming = ConsumerRecord(
        consumerNo: '097030013003',
        name: 'SHRI. DILIP MAHADU MALI',
        status: 'Pending',
        submitDate: DateTime(2026, 8, 19), // Date from Excel
      );

      final diffs = DuplicateDetectionService.computeFieldDiffs(
        existing,
        incoming,
        allowedFieldKeys: {'name', 'mobile', 'address', 'application_id', 'status', 'remarks', 'submit_date', 'application_date'},
        ignoreBlankValues: true,
      );

      // Must detect 1 diff: submit_date changed from null to 2026-08-19
      expect(diffs.length, equals(1));
      expect(diffs.first.fieldKey, equals('submit_date'));
      expect(diffs.first.newValue, equals('2026-08-19'));
    });

    test('Does NOT detect date diff when both dates are identical', () {
      final existing = ConsumerRecord(
        id: 'test-id-2',
        consumerNo: '097030013003',
        name: 'SHRI. DILIP MAHADU MALI',
        status: 'Pending',
        submitDate: DateTime(2026, 8, 19),
      );

      final incoming = ConsumerRecord(
        consumerNo: '097030013003',
        name: 'SHRI. DILIP MAHADU MALI',
        status: 'Pending',
        submitDate: DateTime(2026, 8, 19),
      );

      final diffs = DuplicateDetectionService.computeFieldDiffs(
        existing,
        incoming,
        allowedFieldKeys: {'name', 'mobile', 'address', 'application_id', 'status', 'remarks', 'submit_date', 'application_date'},
        ignoreBlankValues: true,
      );

      expect(diffs.length, equals(0)); // No differences
    });

    test('Detects application_date change from one date to another', () {
      final existing = ConsumerRecord(
        id: 'test-id-3',
        consumerNo: '097030013003',
        name: 'Test User',
        status: 'Pending',
        applicationDate: DateTime(2026, 1, 15),
      );

      final incoming = ConsumerRecord(
        consumerNo: '097030013003',
        name: 'Test User',
        status: 'Pending',
        applicationDate: DateTime(2026, 7, 1),
      );

      final diffs = DuplicateDetectionService.computeFieldDiffs(
        existing,
        incoming,
        allowedFieldKeys: {'name', 'status', 'application_date', 'submit_date'},
        ignoreBlankValues: true,
      );

      expect(diffs.length, equals(1));
      expect(diffs.first.fieldKey, equals('application_date'));
      expect(diffs.first.oldValue, equals('2026-01-15'));
      expect(diffs.first.newValue, equals('2026-07-01'));
    });
  });
}
