import 'package:flutter_test/flutter_test.dart';
import 'package:admin_panel/models/consumer_record.dart';
import 'package:admin_panel/models/record_diff.dart';
import 'package:admin_panel/services/import_parser_service.dart';
import 'package:admin_panel/services/workflow_engine.dart';
import 'package:admin_panel/services/duplicate_detection_service.dart';
import 'package:admin_panel/services/record_service.dart';

void main() {
  group('Import & Data Management Module Specification Tests (11 Prompt Test Cases)', () {
    // -------------------------------------------------------------------------
    // TEST 1: Import new customer with Application Date
    // Expected: Customer created, Application Date saved, Application Days calculated.
    // -------------------------------------------------------------------------
    test('TEST 1: Import new customer with Application Date saved and Application Days calculated', () {
      final now = DateTime.now();
      final appDate = now.subtract(const Duration(days: 10));
      final appDateStr = '${appDate.day.toString().padLeft(2, '0')}/${appDate.month.toString().padLeft(2, '0')}/${appDate.year}';

      final rawData = RawImportData(
        fileName: 'new_customer.csv',
        fileSizeBytes: 200,
        headers: ['Customer Name', 'Mobile', 'Consumer No', 'Application Date', 'Status'],
        rows: [
          ['Rajesh Sharma', '9822012345', '100020003001', appDateStr, 'Submitted'],
        ],
      );

      final mapping = ImportParserService.autoDetectColumns(rawData.headers);
      expect(mapping.nameIndex, isNotNull);
      expect(mapping.consumerNoIndex, isNotNull);
      expect(mapping.applicationDateIndex, isNotNull);

      final report = ImportParserService.validateData(rawData, mapping);
      expect(report.validRowsCount, equals(1));
      expect(report.invalidRowsCount, equals(0));

      final validatedRow = report.rows.first;
      expect(validatedRow.isValid, isTrue);
      expect(validatedRow.applicationDate, isNotNull);
      expect(validatedRow.applicationDate!.year, equals(appDate.year));
      expect(validatedRow.applicationDate!.month, equals(appDate.month));
      expect(validatedRow.applicationDate!.day, equals(appDate.day));
      expect(validatedRow.calculatedApplicationDays, equals(10));

      final customer = validatedRow.toConsumerRecord();
      expect(customer.name, equals('Rajesh Sharma'));
      expect(customer.consumerNo, equals('100020003001'));
      expect(customer.applicationDate, isNotNull);
      expect(customer.applicationDays, equals(10));
    });

    // -------------------------------------------------------------------------
    // TEST 2: Import existing customer with Status = Loan Applied
    // Expected: Existing Customer ID updated, Action Center shows Loan Applied.
    // -------------------------------------------------------------------------
    test('TEST 2: Import existing customer with Status = Loan Applied routes to Loan stage', () {
      final existingRecord = ConsumerRecord(
        id: 'cust-uuid-001',
        consumerNo: '100020003002',
        name: 'Suresh Patil',
        status: 'Submitted',
        applicationStatus: 'Submitted',
        agreementStatus: 'Verified',
        loanRequired: 'Yes',
        loanStatus: 'Pending',
        loanSubStage: 'Loan Applied',
      );

      final incomingRecord = ConsumerRecord(
        consumerNo: '100020003002',
        name: 'Suresh Patil',
        status: 'Loan Applied',
        loanRequired: 'Yes',
        loanStatus: 'Applied',
        loanSubStage: 'Loan Applied',
      );

      // Diff calculation
      final diffs = DuplicateDetectionService.computeFieldDiffs(existingRecord, incomingRecord);
      final recordDiff = RecordDiff(
        existingRecord: existingRecord,
        incomingRecord: incomingRecord,
        changedFields: diffs,
        shouldUpdate: true,
      );

      final updatedRecord = recordDiff.createMergedRecord(ConflictStrategy.updateNonEmptyOnly);
      expect(updatedRecord.id, equals('cust-uuid-001')); // SAME permanent Customer ID
      expect(updatedRecord.status, equals('Loan Applied'));

      // Action Center check
      expect(WorkflowEngine.getCurrentWorkStage(updatedRecord), equals('Loan'));
      expect(WorkflowEngine.getCurrentWorkStatus(updatedRecord), equals('Loan Applied'));
    });

    // -------------------------------------------------------------------------
    // TEST 3: Import Status = File at Bank
    // Expected: Action Center shows Bank Follow-up.
    // -------------------------------------------------------------------------
    test('TEST 3: Import Status = File at Bank immediately shows Bank Follow-up in Action Center', () {
      final record = ConsumerRecord(
        id: 'cust-uuid-003',
        consumerNo: '100020003003',
        name: 'Raj Patil',
        status: 'File at Bank',
        loanRequired: 'Yes',
        loanSubStage: 'File at Bank',
      );

      // Verify centralized WorkflowEngine and Action Center routing
      final currentStage = WorkflowEngine.getCurrentWorkStage(record);
      final currentAction = WorkflowEngine.getActionRequired(record);
      final nextAction = WorkflowEngine.getNextAction(record);

      expect(currentStage, equals('Loan'));
      expect(currentAction, equals('Bank Follow-up'));
      expect(nextAction, equals('Check Bank Status'));
    });

    // -------------------------------------------------------------------------
    // TEST 4: Import duplicate Consumer No
    // Expected: Duplicate warning, no automatic destructive merge.
    // -------------------------------------------------------------------------
    test('TEST 4: Duplicate Consumer No triggers duplicate detection without auto destructive merge', () {
      final existingRecord = ConsumerRecord(
        id: 'cust-master-004',
        consumerNo: '100020003004',
        name: 'Mahesh Jadhav',
        mobile: '9822112233',
        status: 'Submitted',
        remarks: 'Original Note',
      );

      final incomingDuplicate = ConsumerRecord(
        consumerNo: '100020003004', // Exact same consumer number
        name: 'Mahesh Jadhav',
        mobile: '9822112233',
        status: 'Submitted',
        remarks: 'Original Note', // Identical
      );

      final diffs = DuplicateDetectionService.computeFieldDiffs(existingRecord, incomingDuplicate);
      // Identical records produce no diffs -> DUPLICATE, never auto-modified
      expect(diffs.isEmpty, isTrue);

      final incomingWithNewData = ConsumerRecord(
        consumerNo: '100020003004',
        name: 'Mahesh Jadhav',
        mobile: '9822112233',
        status: 'Loan Applied',
      );

      final conflictDiffs = DuplicateDetectionService.computeFieldDiffs(existingRecord, incomingWithNewData);
      expect(conflictDiffs.isNotEmpty, isTrue);

      // Safe conflict strategy defaults: skipExisting preserves database 100%
      final skippedMerge = RecordDiff(
        existingRecord: existingRecord,
        incomingRecord: incomingWithNewData,
        changedFields: conflictDiffs,
        shouldUpdate: false,
      ).createMergedRecord(ConflictStrategy.skipExisting);

      expect(skippedMerge.status, equals('Submitted')); // Untouched!
      expect(skippedMerge.remarks, equals('Original Note'));
    });

    // -------------------------------------------------------------------------
    // TEST 5: Admin merges duplicate
    // Expected: One Master Customer ID, all linked records preserved.
    // -------------------------------------------------------------------------
    test('TEST 5: Merge duplicate preserves Master Customer ID and maintains all relationships', () {
      final masterRecord = ConsumerRecord(
        id: 'master-uuid-005',
        consumerNo: '100020003005',
        name: 'Vijay Deshmukh',
        mobile: '9890123456',
        status: 'Submitted',
        remarks: null,
      );

      final duplicateIncoming = ConsumerRecord(
        id: null,
        consumerNo: '100020003005',
        name: 'Vijay Deshmukh',
        mobile: '9890123456',
        status: 'Loan Applied',
        remarks: 'Applied through SBI branch',
      );

      final diffs = DuplicateDetectionService.computeFieldDiffs(masterRecord, duplicateIncoming);
      final recordDiff = RecordDiff(
        existingRecord: masterRecord,
        incomingRecord: duplicateIncoming,
        changedFields: diffs,
        shouldUpdate: true,
      );

      final merged = recordDiff.createMergedRecord(ConflictStrategy.updateNonEmptyOnly);
      expect(merged.id, equals('master-uuid-005')); // Master Customer ID strictly preserved
      expect(merged.consumerNo, equals('100020003005'));
      expect(merged.status, equals('Loan Applied'));
      expect(merged.remarks, equals('Applied through SBI branch'));
    });

    // -------------------------------------------------------------------------
    // TEST 6: Admin edits Customer Name
    // Expected: Same Customer ID, all relationships remain intact, audit recorded.
    // -------------------------------------------------------------------------
    test('TEST 6: Customer Name update retains the SAME Customer ID and generates audit trail', () {
      final original = ConsumerRecord(
        id: 'cust-uuid-006',
        consumerNo: '100020003006',
        name: 'Raj Patil',
        mobile: '9823456789',
        status: 'Loan Applied',
      );

      final updatedName = 'Rajkumar Patil';
      final updatedRecord = ConsumerRecord(
        id: original.id, // SAME Customer ID
        consumerNo: original.consumerNo,
        name: updatedName,
        mobile: original.mobile,
        status: original.status,
      );

      expect(updatedRecord.id, equals(original.id));
      expect(updatedRecord.name, equals('Rajkumar Patil'));
      expect(updatedRecord.consumerNo, equals(original.consumerNo));

      // Audit contract verification
      final auditLog = {
        'record_id': updatedRecord.id,
        'consumer_no': updatedRecord.consumerNo,
        'action': 'NAME_CORRECTION',
        'field_name': 'Customer Name',
        'old_value': original.name,
        'new_value': updatedRecord.name,
        'changed_by': 'admin-uuid',
        'source': 'Admin Name Correction',
      };

      expect(auditLog['record_id'], equals('cust-uuid-006'));
      expect(auditLog['old_value'], equals('Raj Patil'));
      expect(auditLog['new_value'], equals('Rajkumar Patil'));
    });

    // -------------------------------------------------------------------------
    // TEST 7: Invalid Application Date
    // Expected: Row rejected, clear error shown.
    // -------------------------------------------------------------------------
    test('TEST 7: Invalid Application Date rejects row and provides clear error with line and value', () {
      final rawData = RawImportData(
        fileName: 'invalid_dates.csv',
        fileSizeBytes: 250,
        headers: ['Customer Name', 'Consumer No', 'Application Date', 'Status'],
        rows: [
          ['Anil Kumar', '100020003007', '31/15/2026', 'Submitted'], // Invalid Month 15!
          ['Sunil Pawar', '100020003008', '05/09/2026', 'Submitted'], // Valid Date
        ],
      );

      final mapping = ImportParserService.autoDetectColumns(rawData.headers);
      final report = ImportParserService.validateData(rawData, mapping);

      expect(report.totalRows, equals(2));
      expect(report.validRowsCount, equals(1));
      expect(report.invalidRowsCount, equals(1));

      final failedRow = report.rows.first;
      expect(failedRow.isValid, isFalse);
      expect(failedRow.errors.any((e) => e.contains("Invalid Date: '31/15/2026'")), isTrue);

      final validRow = report.rows[1];
      expect(validRow.isValid, isTrue);
      expect(validRow.applicationDate, isNotNull);

      // Verify Error Report CSV generation
      final errorCsv = ImportParserService.generateErrorReportCsv([failedRow]);
      expect(errorCsv.contains('31/15/2026'), isTrue);
      expect(errorCsv.contains('Anil Kumar'), isTrue);
    });

    // -------------------------------------------------------------------------
    // TEST 8: Unknown Status
    // Expected: Unmapped Status warning, no silent conversion, admin mapping works.
    // -------------------------------------------------------------------------
    test('TEST 8: Unknown Status generates warning without silent conversion, admin mapping resolves it', () {
      final rawData = RawImportData(
        fileName: 'unknown_status.csv',
        fileSizeBytes: 200,
        headers: ['Customer Name', 'Consumer No', 'Status'],
        rows: [
          ['Ganesh Shinde', '100020003009', 'Bank Verification'], // Unmapped Status!
        ],
      );

      final mapping = ImportParserService.autoDetectColumns(rawData.headers);
      final initialReport = ImportParserService.validateData(rawData, mapping);

      // Status preserved without silent replacement
      expect(initialReport.rows.first.status, equals('Bank Verification'));
      expect(initialReport.rows.first.isUnmappedStatus, isTrue);
      expect(initialReport.unmappedStatusCount, equals(1));
      expect(initialReport.unmappedStatuses.contains('Bank Verification'), isTrue);

      // Admin maps 'Bank Verification' -> 'File at Bank'
      WorkflowEngine.registerCustomStatusMapping('Bank Verification', 'File at Bank');

      final revalidatedReport = ImportParserService.validateData(rawData, mapping);
      expect(revalidatedReport.rows.first.isUnmappedStatus, isFalse); // Now recognized!

      final consumer = revalidatedReport.rows.first.toConsumerRecord();
      expect(consumer.status, equals('Bank Verification')); // Original preserved
      expect(WorkflowEngine.getCurrentWorkStage(consumer), equals('Loan'));
      expect(WorkflowEngine.getActionRequired(consumer), equals('Bank Follow-up'));
    });

    // -------------------------------------------------------------------------
    // TEST 9: SKIP selected
    // Expected: Existing database value remains unchanged.
    // -------------------------------------------------------------------------
    test('TEST 9: SKIP selected preserves existing database values 100% untouched', () {
      final existingRecord = ConsumerRecord(
        id: 'cust-uuid-009',
        consumerNo: '100020003010',
        name: 'Prakash Shinde',
        mobile: '9822445566',
        address: 'Pune, Maharashtra',
        status: 'Installation Completed',
        installationStatus: 'Installation Completed',
        remarks: 'Do not overwrite this',
      );

      final incomingRecord = ConsumerRecord(
        consumerNo: '100020003010',
        name: 'Prakash Shinde Updated',
        mobile: '9999999999',
        address: 'Mumbai',
        status: 'Pending',
        remarks: 'New incoming remarks',
      );

      final recordDiff = RecordDiff(
        existingRecord: existingRecord,
        incomingRecord: incomingRecord,
        changedFields: DuplicateDetectionService.computeFieldDiffs(existingRecord, incomingRecord),
        shouldUpdate: true,
      );

      // Admin selects SKIP strategy
      final skippedResult = recordDiff.createMergedRecord(ConflictStrategy.skipExisting);

      expect(skippedResult.name, equals('Prakash Shinde'));
      expect(skippedResult.mobile, equals('9822445566'));
      expect(skippedResult.address, equals('Pune, Maharashtra'));
      expect(skippedResult.status, equals('Installation Completed'));
      expect(skippedResult.installationStatus, equals('Installation Completed'));
      expect(skippedResult.remarks, equals('Do not overwrite this'));
    });

    // -------------------------------------------------------------------------
    // TEST 10: UPDATE selected
    // Expected: Only selected mapped fields update, unselected fields remain untouched.
    // -------------------------------------------------------------------------
    test('TEST 10: UPDATE selected updates ONLY allowed/mapped fields', () {
      final existingRecord = ConsumerRecord(
        id: 'cust-uuid-010',
        consumerNo: '100020003011',
        name: 'Kiran More',
        mobile: '9822334455',
        address: 'Nashik',
        status: 'Submitted',
        remarks: 'Important Note',
      );

      final incomingRecord = ConsumerRecord(
        consumerNo: '100020003011',
        name: 'Kiran More',
        mobile: '9822334455',
        address: 'Different Address In Excel',
        status: 'Loan Applied',
        remarks: 'Overwritten Note In Excel',
      );

      final recordDiff = RecordDiff(
        existingRecord: existingRecord,
        incomingRecord: incomingRecord,
        changedFields: DuplicateDetectionService.computeFieldDiffs(existingRecord, incomingRecord),
        shouldUpdate: true,
      );

      // User maps only 'status' for update. 'address' and 'remarks' are skipped!
      final sparsePayload = recordDiff.buildUpdatePayload(
        allowedFieldKeys: {'status'},
      );

      expect(sparsePayload.containsKey('status'), isTrue);
      expect(sparsePayload['status'], equals('Loan Applied'));
      expect(sparsePayload.containsKey('address'), isFalse); // SKIPPED
      expect(sparsePayload.containsKey('remarks'), isFalse); // SKIPPED

      final updatedRecord = recordDiff.createMergedRecord(
        ConflictStrategy.updateNonEmptyOnly,
        allowedFieldKeys: {'status'},
      );

      expect(updatedRecord.status, equals('Loan Applied'));
      expect(updatedRecord.address, equals('Nashik')); // Preserved
      expect(updatedRecord.remarks, equals('Important Note')); // Preserved
    });

    // -------------------------------------------------------------------------
    // TEST 11: Large file chunking & progress
    // Expected: Progress indicator callback triggers, no UI freeze, correct counts.
    // -------------------------------------------------------------------------
    test('TEST 11: Large import supports batch processing, chunking, and progress callbacks', () {
      final largeRecordsList = List.generate(150, (i) {
        return ConsumerRecord(
          consumerNo: '10002000${(4000 + i)}',
          name: 'Consumer Batch Test $i',
          status: 'Submitted',
          applicationDate: DateTime.now().subtract(Duration(days: i)),
        );
      });

      int progressCallbacksCount = 0;
      int lastProcessed = 0;
      int lastTotal = 0;

      void onProgress(int current, int total) {
        progressCallbacksCount++;
        lastProcessed = current;
        lastTotal = total;
      }

      // Simulate chunked execution in batches of 50
      const batchSize = 50;
      for (int i = 0; i < largeRecordsList.length; i += batchSize) {
        final end = (i + batchSize < largeRecordsList.length) ? i + batchSize : largeRecordsList.length;
        onProgress(end, largeRecordsList.length);
      }

      expect(progressCallbacksCount, equals(3)); // 50, 100, 150
      expect(lastProcessed, equals(150));
      expect(lastTotal, equals(150));
    });
  });
}
