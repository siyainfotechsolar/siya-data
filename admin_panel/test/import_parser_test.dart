import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:admin_panel/services/import_parser_service.dart';

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
  });
}
