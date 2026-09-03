import 'package:flutter_test/flutter_test.dart';
import 'package:admin_panel/models/consumer_record.dart';
import 'package:admin_panel/models/record_diff.dart';
import 'package:admin_panel/services/duplicate_detection_service.dart';
import 'package:admin_panel/services/import_parser_service.dart';

void main() {
  group('Import Column Update & Skip Policy Tests', () {
    late ConsumerRecord existing;
    late ConsumerRecord incoming;

    setUp(() {
      existing = ConsumerRecord(
        id: 'rec-1001',
        consumerNo: '1001',
        name: 'Raj Patil',
        mobile: '9876543210',
        address: 'Pune, Maharashtra',
        applicationId: 'APP-99',
        status: 'Pending',
        remarks: 'Old Customer',
      );

      incoming = ConsumerRecord(
        consumerNo: '1001',
        name: 'Raj P.',
        mobile: '9999999999',
        address: 'Mumbai, Maharashtra',
        applicationId: 'APP-100',
        status: 'Approved',
        remarks: 'New Remark',
      );
    });

    test('1. One selected column updates correctly: only status changes in sparse payload', () {
      final diff = RecordDiff(
        existingRecord: existing,
        incomingRecord: incoming,
        changedFields: DuplicateDetectionService.computeFieldDiffs(
          existing,
          incoming,
          allowedFieldKeys: {'status'},
        ),
      );

      final payload = diff.buildUpdatePayload(
        allowedFieldKeys: {'status'},
        ignoreBlankValues: true,
      );

      // Must strictly contain ONLY status
      expect(payload.length, equals(1));
      expect(payload['status'], equals('Approved'));
      expect(payload.containsKey('name'), isFalse);
      expect(payload.containsKey('mobile'), isFalse);
      expect(payload.containsKey('remarks'), isFalse);
    });

    test('2. Skipped fields remain unchanged and are completely omitted from update payload', () {
      final diff = RecordDiff(
        existingRecord: existing,
        incomingRecord: incoming,
        changedFields: DuplicateDetectionService.computeFieldDiffs(
          existing,
          incoming,
          allowedFieldKeys: {'status'},
        ),
      );

      final merged = diff.createMergedRecord(
        ConflictStrategy.overwriteAll,
        allowedFieldKeys: {'status'},
        ignoreBlankValues: true,
      );

      // Status updated
      expect(merged.status, equals('Approved'));
      // All other fields remain identical to existing record
      expect(merged.name, equals('Raj Patil'));
      expect(merged.mobile, equals('9876543210'));
      expect(merged.address, equals('Pune, Maharashtra'));
      expect(merged.applicationId, equals('APP-99'));
      expect(merged.remarks, equals('Old Customer'));
    });

    test('3. Blank selected value does not overwrite existing value by default', () {
      final incomingWithBlankStatus = ConsumerRecord(
        consumerNo: '1001',
        name: 'Raj Patil',
        status: '', // Blank
      );

      final diff = RecordDiff(
        existingRecord: existing,
        incomingRecord: incomingWithBlankStatus,
        changedFields: DuplicateDetectionService.computeFieldDiffs(
          existing,
          incomingWithBlankStatus,
          allowedFieldKeys: {'status'},
          ignoreBlankValues: true,
        ),
      );

      final payload = diff.buildUpdatePayload(
        allowedFieldKeys: {'status'},
        ignoreBlankValues: true,
      );

      // Blank value ignored -> payload empty, existing data preserved
      expect(payload.isEmpty, isTrue);
    });

    test('4. Differences in skipped fields do not trigger an update or conflict', () {
      // Excel has completely different name and mobile, but user mapped ONLY status
      // In this case, existing status is 'Pending' and incoming status is also 'Pending'
      final incomingSameStatus = ConsumerRecord(
        consumerNo: '1001',
        name: 'Completely Different Name',
        mobile: '1111111111',
        status: 'Pending', // identical
      );

      final diffs = DuplicateDetectionService.computeFieldDiffs(
        existing,
        incomingSameStatus,
        allowedFieldKeys: {'status'},
        ignoreBlankValues: true,
      );

      // Since only 'status' is mapped and status did not change, diffs must be empty
      expect(diffs.isEmpty, isTrue);
    });

    test('5. Multiple selected columns update correctly while unselected stay skipped', () {
      final diff = RecordDiff(
        existingRecord: existing,
        incomingRecord: incoming,
        changedFields: DuplicateDetectionService.computeFieldDiffs(
          existing,
          incoming,
          allowedFieldKeys: {'status', 'remarks'},
        ),
      );

      final payload = diff.buildUpdatePayload(
        allowedFieldKeys: {'status', 'remarks'},
        ignoreBlankValues: true,
      );

      expect(payload.length, equals(2));
      expect(payload['status'], equals('Approved'));
      expect(payload['remarks'], equals('New Remark'));
      expect(payload.containsKey('name'), isFalse);
      expect(payload.containsKey('mobile'), isFalse);
      expect(payload.containsKey('address'), isFalse);
    });

    test('6. Re-importing the same selected values results in SKIP / UNCHANGED', () {
      final incomingSame = ConsumerRecord(
        consumerNo: '1001',
        name: 'Raj Patil',
        status: 'Pending',
      );

      final diffs = DuplicateDetectionService.computeFieldDiffs(
        existing,
        incomingSame,
        allowedFieldKeys: {'status'},
        ignoreBlankValues: true,
      );

      expect(diffs.isEmpty, isTrue);

      final diff = RecordDiff(
        existingRecord: existing,
        incomingRecord: incomingSame,
        changedFields: diffs,
      );

      final payload = diff.buildUpdatePayload(
        allowedFieldKeys: {'status'},
        ignoreBlankValues: true,
      );

      expect(payload.isEmpty, isTrue);
    });

    test('7. New record imports only mapped fields and keeps skipped fields as null', () {
      final mapping = ImportColumnMapping(
        consumerNoIndex: 0,
        nameIndex: 1,
        statusIndex: 2,
        // mobile, address, remarks are SKIPPED (null)
      );

      expect(mapping.mappedFieldKeys, containsAll(['consumer_no', 'name', 'status']));
      expect(mapping.mappedFieldKeys.contains('mobile'), isFalse);
      expect(mapping.mappedFieldKeys.contains('remarks'), isFalse);

      final rawData = RawImportData(
        fileName: 'test.csv',
        fileSizeBytes: 100,
        headers: ['Consumer No', 'Name', 'Status', 'Mobile', 'Remarks'],
        rows: [
          ['1002', 'Amit Shah', 'Approved', '9898989898', 'Vendor Note'],
        ],
      );

      final report = ImportParserService.validateData(rawData, mapping);
      expect(report.validRowsCount, equals(1));

      final record = report.rows.first.toConsumerRecord();
      expect(record.consumerNo, equals('1002'));
      expect(record.name, equals('Amit Shah'));
      expect(record.status, equals('Approved'));
      // Skipped columns were not mapped into record
      expect(record.mobile, isNull);
      expect(record.remarks, isNull);
    });

    test('8. Audit log entries are generated ONLY for permitted and actually changed fields', () {
      final diff = RecordDiff(
        existingRecord: existing,
        incomingRecord: incoming,
        changedFields: DuplicateDetectionService.computeFieldDiffs(
          existing,
          incoming,
          allowedFieldKeys: {'status'},
        ),
      );

      final sparsePayload = diff.buildUpdatePayload(
        allowedFieldKeys: {'status'},
        ignoreBlankValues: true,
      );

      final auditEntries = <String>[];
      for (final key in sparsePayload.keys) {
        auditEntries.add(key);
      }

      expect(auditEntries, equals(['status']));
      expect(auditEntries.contains('name'), isFalse);
      expect(auditEntries.contains('mobile'), isFalse);
    });
  });
}
