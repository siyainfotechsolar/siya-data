import 'package:flutter_test/flutter_test.dart';
import 'package:admin_panel/models/consumer_record.dart';
import 'package:admin_panel/models/record_diff.dart';
import 'package:admin_panel/services/import_parser_service.dart';

void main() {
  group('Import Date + Auto Priority Calculation Tests', () {
    DateTime daysAgo(int days) {
      final now = DateTime.now();
      return DateTime(now.year, now.month, now.day - days);
    }

    test('1. Application Date and Submit Date parse cleanly from Excel/CSV formats', () {
      final headers = ['Consumer No', 'Name', 'Application Date', 'Submit Date'];
      final mapping = ImportParserService.autoDetectColumns(headers);

      expect(mapping.applicationDateIndex, equals(2));
      expect(mapping.submitDateIndex, equals(3));

      final rawData = RawImportData(
        fileName: 'test.xlsx',
        fileSizeBytes: 100,
        headers: headers,
        rows: [
          ['1001', 'Rahul Sharma', '01/08/2026', '05/08/2026'],
        ],
      );

      final report = ImportParserService.validateData(rawData, mapping);
      expect(report.validRowsCount, equals(1));

      final row = report.rows.first;
      expect(row.applicationDate, equals(DateTime(2026, 8, 1)));
      expect(row.submitDate, equals(DateTime(2026, 8, 5)));
    });

    test('2. Application Days and Priority calculate automatically from Submit Date', () {
      final submitDate20DaysAgo = daysAgo(20);
      final row = ValidatedImportRow(
        rowNumber: 2,
        consumerNo: '1001',
        name: 'Test Consumer',
        status: 'Submitted',
        submitDate: submitDate20DaysAgo,
      );

      expect(row.calculatedApplicationDays, equals(20));
      expect(row.calculatedPriority, equals('HIGH'));
    });

    test('3. User-entered Priority in Excel is ignored; system calculates dynamically', () {
      final submitDate35DaysAgo = daysAgo(35);
      final rec = ConsumerRecord(
        consumerNo: '1001',
        name: 'Test Consumer',
        submitDate: submitDate35DaysAgo,
      );

      // System priority calculated dynamically from 35 days -> CRITICAL
      expect(rec.applicationDays, equals(35));
      expect(rec.priority, equals('CRITICAL'));
    });

    test('4. Submit Date UPDATE recalculates Application Days & Priority dynamically', () {
      final oldSubmitDate = daysAgo(5); // NORMAL priority (5 days)
      final existingRecord = ConsumerRecord(
        consumerNo: '1001',
        name: 'Test Consumer',
        submitDate: oldSubmitDate,
      );

      expect(existingRecord.priority, equals('NORMAL'));

      final newSubmitDate = daysAgo(40); // CRITICAL priority (40 days)
      final incomingRecord = ConsumerRecord(
        consumerNo: '1001',
        name: 'Test Consumer',
        submitDate: newSubmitDate,
      );

      final diff = RecordDiff(
        existingRecord: existingRecord,
        incomingRecord: incomingRecord,
        changedFields: [
          FieldDiff(
            fieldKey: 'submit_date',
            fieldLabel: 'Submit Date',
            oldValue: oldSubmitDate.toIso8601String(),
            newValue: newSubmitDate.toIso8601String(),
          ),
        ],
      );

      final merged = diff.createMergedRecord(
        ConflictStrategy.overwriteAll,
        allowedFieldKeys: {'submit_date'},
      );

      expect(merged.submitDate, equals(newSubmitDate));
      expect(merged.applicationDays, equals(40));
      expect(merged.priority, equals('CRITICAL'));
    });

    test('5. Submit Date SKIP keeps existing Submit Date and recalculates Priority from existing date', () {
      final existingSubmitDate = daysAgo(18); // HIGH priority (18 days)
      final existingRecord = ConsumerRecord(
        consumerNo: '1001',
        name: 'Test Consumer',
        submitDate: existingSubmitDate,
      );

      final incomingRecord = ConsumerRecord(
        consumerNo: '1001',
        name: 'Test Consumer',
        submitDate: daysAgo(2), // Incoming submit date (should be ignored because submit_date is SKIPPED)
      );

      final diff = RecordDiff(
        existingRecord: existingRecord,
        incomingRecord: incomingRecord,
        changedFields: [],
      );

      final merged = diff.createMergedRecord(
        ConflictStrategy.updateNonEmptyOnly,
        allowedFieldKeys: {'name', 'mobile'}, // submit_date is NOT in allowedFieldKeys -> SKIPPED
      );

      expect(merged.submitDate, equals(existingSubmitDate));
      expect(merged.applicationDays, equals(18));
      expect(merged.priority, equals('HIGH'));
    });

    test('6. Application Date UPDATE changes Application Date only, leaving Priority unaffected', () {
      final existingSubmitDate = daysAgo(10); // MEDIUM priority (10 days)
      final existingRecord = ConsumerRecord(
        consumerNo: '1001',
        name: 'Test Consumer',
        applicationDate: DateTime(2026, 1, 1),
        submitDate: existingSubmitDate,
      );

      expect(existingRecord.priority, equals('MEDIUM'));

      final newApplicationDate = DateTime(2026, 6, 1);
      final incomingRecord = ConsumerRecord(
        consumerNo: '1001',
        name: 'Test Consumer',
        applicationDate: newApplicationDate,
        submitDate: existingSubmitDate,
      );

      final diff = RecordDiff(
        existingRecord: existingRecord,
        incomingRecord: incomingRecord,
        changedFields: [
          FieldDiff(
            fieldKey: 'application_date',
            fieldLabel: 'Application Date',
            oldValue: '2026-01-01',
            newValue: '2026-06-01',
          ),
        ],
      );

      final merged = diff.createMergedRecord(
        ConflictStrategy.overwriteAll,
        allowedFieldKeys: {'application_date'},
      );

      expect(merged.applicationDate, equals(newApplicationDate));
      expect(merged.submitDate, equals(existingSubmitDate));
      expect(merged.applicationDays, equals(10));
      expect(merged.priority, equals('MEDIUM'));
    });
  });
}
