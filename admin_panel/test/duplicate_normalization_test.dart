import 'package:flutter_test/flutter_test.dart';
import 'package:admin_panel/models/consumer_record.dart';
import 'package:admin_panel/models/record_diff.dart';
import 'package:admin_panel/utils/consumer_no_utils.dart';
import 'package:admin_panel/services/import_parser_service.dart';
import 'package:admin_panel/services/duplicate_detection_service.dart';

void main() {
  group('Consumer Number Normalization & Duplicate Matching Tests', () {
    test('1. Normalizes leading apostrophes, spaces, hyphens, and float .0 correctly', () {
      expect(ConsumerNoNormalizer.normalize('110014099875'), equals('110014099875'));
      expect(ConsumerNoNormalizer.normalize("'110014099875"), equals('110014099875'));
      expect(ConsumerNoNormalizer.normalize("' 110014099875"), equals('110014099875'));
      expect(ConsumerNoNormalizer.normalize(' 110014099875 '), equals('110014099875'));
      expect(ConsumerNoNormalizer.normalize('110014 099875'), equals('110014099875'));
      expect(ConsumerNoNormalizer.normalize('110014099875.0'), equals('110014099875'));
      expect(ConsumerNoNormalizer.normalize('1100-140-99875'), equals('110014099875'));
      expect(ConsumerNoNormalizer.normalize('`110014099875'), equals('110014099875'));
      expect(ConsumerNoNormalizer.normalize('"110014099875"'), equals('110014099875'));
    });

    test('2. ConsumerNoNormalizer.isDuplicate matches formatted variations', () {
      expect(ConsumerNoNormalizer.isDuplicate('110014099875', "'110014099875"), isTrue);
      expect(ConsumerNoNormalizer.isDuplicate("' 110014099875", '110014 099875'), isTrue);
      expect(ConsumerNoNormalizer.isDuplicate('110014099875 ', '110014099875.0'), isTrue);
      expect(ConsumerNoNormalizer.isDuplicate('110014099875', '990014099875'), isFalse);
    });

    test('3. ConsumerRecord.normalizedConsumerNo returns normalized key', () {
      final record = ConsumerRecord(
        consumerNo: "' 110014099875",
        name: 'Apostrophe Customer',
      );
      expect(record.normalizedConsumerNo, equals('110014099875'));
    });

    test('4. In-file duplicate detection flags apostrophe and space variations as duplicates', () {
      final rawData = RawImportData(
        fileName: 'test.csv',
        fileSizeBytes: 100,
        headers: ['Consumer No', 'Name'],
        rows: [
          ['110014099875', 'Customer 1'],
          ["'110014099875", 'Customer 1 Dup'],
          ['110014 099875', 'Customer 1 Space Dup'],
          ['990014099875', 'Customer 2 Unique'],
        ],
      );

      final mapping = ImportColumnMapping(
        consumerNoIndex: 0,
        nameIndex: 1,
      );

      final report = ImportParserService.validateData(rawData, mapping);

      expect(report.totalRows, equals(4));
      expect(report.rows[0].isDuplicateInFile, isFalse);
      expect(report.rows[1].isDuplicateInFile, isTrue); // Row 2 flagged duplicate of Row 1
      expect(report.rows[2].isDuplicateInFile, isTrue); // Row 3 flagged duplicate of Row 1
      expect(report.rows[3].isDuplicateInFile, isFalse);
      expect(report.duplicateCount, equals(2));
    });

    test('5. DuplicateDetectionService matches existing record with leading apostrophe in import as EXACT DUPLICATE', () async {
      final existing = ConsumerRecord(
        id: 'rec-1',
        consumerNo: '110014099875',
        name: 'Rahul Sharma',
        mobile: '9876543210',
        status: 'Pending',
      );

      final incoming = ConsumerRecord(
        consumerNo: "'110014099875", // Leading apostrophe in import
        name: 'Rahul Sharma',
        mobile: '9876543210',
        status: 'Pending',
      );

      final diffs = DuplicateDetectionService.computeFieldDiffs(
        existing,
        incoming,
        allowedFieldKeys: {'name', 'mobile', 'status'},
      );

      expect(diffs, isEmpty); // Classified as EXACT DUPLICATE
    });

    test('6. Normalized matching correctly detects field conflicts when mapped fields differ', () {
      final existing = ConsumerRecord(
        id: 'rec-1',
        consumerNo: '110014099875',
        name: 'Rahul Sharma',
        mobile: '9876543210',
        address: 'Pune',
      );

      final incoming = ConsumerRecord(
        consumerNo: "' 110014099875", // Apostrophe and space
        name: 'Rahul Sharma',
        mobile: '9999999999', // Updated mobile number
        address: 'Mumbai',
      );

      final diffs = DuplicateDetectionService.computeFieldDiffs(
        existing,
        incoming,
        allowedFieldKeys: {'mobile', 'address'},
      );

      expect(diffs.length, equals(2));
      expect(diffs.any((d) => d.fieldKey == 'mobile' && d.newValue == '9999999999'), isTrue);
      expect(diffs.any((d) => d.fieldKey == 'address' && d.newValue == 'Mumbai'), isTrue);
    });

    test('7. Original display value of stored record is preserved during merge', () {
      final existing = ConsumerRecord(
        id: 'rec-1',
        consumerNo: '110014099875', // Original display value
        name: 'Original Customer Name',
      );

      final incoming = ConsumerRecord(
        consumerNo: "'110014099875", // Incoming formatted string
        name: 'Updated Customer Name',
      );

      final diff = RecordDiff(
        existingRecord: existing,
        incomingRecord: incoming,
        changedFields: [
          FieldDiff(fieldKey: 'name', fieldLabel: 'Name', oldValue: 'Original Customer Name', newValue: 'Updated Customer Name'),
        ],
      );

      final merged = diff.createMergedRecord(
        ConflictStrategy.updateNonEmptyOnly,
        allowedFieldKeys: {'name'}, // consumer_no is SKIPPED / unmapped
      );

      expect(merged.consumerNo, equals('110014099875')); // Kept original display value
      expect(merged.name, equals('Updated Customer Name'));
    });
  });
}
