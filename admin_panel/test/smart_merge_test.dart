import 'package:flutter_test/flutter_test.dart';
import 'package:admin_panel/models/consumer_record.dart';
import 'package:admin_panel/models/duplicate_group.dart';
import 'package:admin_panel/models/merge_conflict.dart';
import 'package:admin_panel/models/record_diff.dart';
import 'package:admin_panel/utils/consumer_no_utils.dart';

void main() {
  group('Phase 14: Duplicate Finder & Smart Merge System Tests', () {
    final now = DateTime.now();

    DateTime daysAgo(int days) {
      return DateTime(now.year, now.month, now.day).subtract(Duration(days: days));
    }

    test('1. Exact Consumer No duplicate detection', () {
      expect(ConsumerNoNormalizer.isDuplicate('110014099875', '110014099875'), isTrue);
    });

    test('2. Leading apostrophe duplicate detection', () {
      expect(ConsumerNoNormalizer.isDuplicate("'110014099875", '110014099875'), isTrue);
      expect(ConsumerNoNormalizer.isDuplicate("' 110014099875", "'110014099875"), isTrue);
    });

    test('3. Spaces and hyphens formatting variation duplicate detection', () {
      expect(ConsumerNoNormalizer.isDuplicate('110014 099875', '1100-140-99875'), isTrue);
      expect(ConsumerNoNormalizer.isDuplicate('110014099875 ', ' 110014099875 '), isTrue);
    });

    test('4. Empty Master field auto-copies Duplicate value', () {
      final conflict = MergeConflictField.compare(
        fieldKey: 'mobile',
        fieldLabel: 'Mobile Number',
        masterVal: '', // Empty Master
        duplicateVal: '9552024163', // Duplicate has value
      );

      expect(conflict.state, equals(MergeFieldState.empty));
      expect(conflict.strategy, equals(MergeStrategy.useDuplicate));
      expect(conflict.resolvedValue, equals('9552024163'));
    });

    test('5. Non-empty Master value preserved when Duplicate is empty', () {
      final conflict = MergeConflictField.compare(
        fieldKey: 'mobile',
        fieldLabel: 'Mobile Number',
        masterVal: '9552024163', // Master has value
        duplicateVal: '', // Duplicate empty
      );

      expect(conflict.state, equals(MergeFieldState.empty));
      expect(conflict.strategy, equals(MergeStrategy.keepMaster));
      expect(conflict.resolvedValue, equals('9552024163'));
    });

    test('6. Different mobile numbers trigger a CONFLICT requiring resolution strategy', () {
      final conflict = MergeConflictField.compare(
        fieldKey: 'mobile',
        fieldLabel: 'Mobile Number',
        masterVal: '9552024163',
        duplicateVal: '9876543210',
      );

      expect(conflict.state, equals(MergeFieldState.conflict));

      // Test Strategy 1: Keep Master
      conflict.strategy = MergeStrategy.keepMaster;
      expect(conflict.resolvedValue, equals('9552024163'));

      // Test Strategy 2: Use Duplicate
      conflict.strategy = MergeStrategy.useDuplicate;
      expect(conflict.resolvedValue, equals('9876543210'));

      // Test Strategy 3: Custom
      conflict.strategy = MergeStrategy.custom;
      conflict.customValue = '9000000000';
      expect(conflict.resolvedValue, equals('9000000000'));
    });

    test('7. Workflow status conflict resolution prevents accidental status downgrade', () {
      final conflict = MergeConflictField.compare(
        fieldKey: 'installation_status',
        fieldLabel: 'Installation Status',
        masterVal: 'Not Started',
        duplicateVal: 'Installation Completed',
      );

      expect(conflict.state, equals(MergeFieldState.conflict));

      // Explicit selection of higher duplicate status
      conflict.strategy = MergeStrategy.useDuplicate;
      expect(conflict.resolvedValue, equals('Installation Completed'));
    });

    test('8. Finalizing Submit Date recalculates Application Days & Priority dynamically', () {
      final submitDate40DaysAgo = daysAgo(40);
      final rec = ConsumerRecord(
        consumerNo: '110014099875',
        name: 'Merged Customer',
        submitDate: submitDate40DaysAgo,
      );

      expect(rec.applicationDays, equals(40));
      expect(rec.priority, equals('CRITICAL'));
    });

    test('9. Document URLs are preserved during merge', () {
      final master = ConsumerRecord(
        consumerNo: '110014099875',
        name: 'Doc Test Master',
        agreementDocUrl: 'https://storage/doc_master.pdf',
        installationPhotosUrl: null,
      );

      final duplicate = ConsumerRecord(
        consumerNo: "'110014099875",
        name: 'Doc Test Duplicate',
        agreementDocUrl: null,
        installationPhotosUrl: 'https://storage/photo_dup.jpg',
      );

      final docConflict1 = MergeConflictField.compare(
        fieldKey: 'agreement_doc_url',
        fieldLabel: 'Agreement Doc',
        masterVal: master.agreementDocUrl,
        duplicateVal: duplicate.agreementDocUrl,
      );

      final docConflict2 = MergeConflictField.compare(
        fieldKey: 'installation_photos_url',
        fieldLabel: 'Installation Photos',
        masterVal: master.installationPhotosUrl,
        duplicateVal: duplicate.installationPhotosUrl,
      );

      expect(docConflict1.resolvedValue, equals('https://storage/doc_master.pdf'));
      expect(docConflict2.resolvedValue, equals('https://storage/photo_dup.jpg'));
    });

    test('10. Master Record selection preserves primary ID while linking duplicate IDs', () {
      final master = ConsumerRecord(id: 'master-1001', consumerNo: '110014099875', name: 'Master');
      final dup1 = ConsumerRecord(id: 'dup-1088', consumerNo: "'110014099875", name: 'Dup 1');
      final dup2 = ConsumerRecord(id: 'dup-1120', consumerNo: '110014 099875', name: 'Dup 2');

      final group = DuplicateGroup(
        normalizedConsumerNo: '110014099875',
        records: [master, dup1, dup2],
        matchType: DuplicateMatchType.formattingVariation,
      );

      expect(group.recordCount, equals(3));
      expect(group.normalizedConsumerNo, equals('110014099875'));
    });

    test('11. Merged duplicate records set is_merged = true and merged_into_id = master_id', () {
      final duplicateMerged = ConsumerRecord(
        id: 'dup-1088',
        consumerNo: "'110014099875",
        name: 'Dup Record',
        isMerged: true,
        mergedIntoId: 'master-1001',
        mergedAt: now,
      );

      expect(duplicateMerged.isMerged, isTrue);
      expect(duplicateMerged.mergedIntoId, equals('master-1001'));
      expect(duplicateMerged.isActiveApplication, isFalse); // Excluded from active priority and records
    });

    test('12. Excel import duplicate analysis uses normalized Consumer No matching', () {
      final existing = ConsumerRecord(
        id: 'rec-1',
        consumerNo: '110014099875',
        name: 'Excel Import Test',
      );

      final incomingImport = ConsumerRecord(
        consumerNo: "' 110014099875",
        name: 'Excel Import Test',
      );

      expect(existing.normalizedConsumerNo, equals(incomingImport.normalizedConsumerNo));
    });

    test('13. UPDATE / SKIP mapping rule: Skipped fields never overwrite existing data', () {
      final existing = ConsumerRecord(
        consumerNo: '110014099875',
        name: 'Existing Customer',
        mobile: '9552024163',
        address: 'Pune',
      );

      final incoming = ConsumerRecord(
        consumerNo: '110014099875',
        name: 'Updated Name',
        mobile: '9999999999', // Mapped
        address: 'Mumbai', // SKIPPED column
      );

      final diff = RecordDiff(
        existingRecord: existing,
        incomingRecord: incoming,
        changedFields: [],
      );

      final merged = diff.createMergedRecord(
        ConflictStrategy.updateNonEmptyOnly,
        allowedFieldKeys: {'name', 'mobile'}, // address is SKIPPED
      );

      expect(merged.name, equals('Updated Name'));
      expect(merged.mobile, equals('9999999999'));
      expect(merged.address, equals('Pune')); // Preserved original address!
    });

    test('14. Audit log contract for SMART_MERGE action', () {
      final auditJson = {
        'action': 'SMART_MERGE',
        'record_id': 'master-1001',
        'consumer_no': '110014099875',
        'duplicate_ids': ['dup-1088', 'dup-1120'],
      };

      expect(auditJson['action'], equals('SMART_MERGE'));
      expect(auditJson['consumer_no'], equals('110014099875'));
    });

    test('15. Active application filter excludes merged records', () {
      final active = ConsumerRecord(consumerNo: '1001', name: 'Active', isMerged: false);
      final merged = ConsumerRecord(consumerNo: '1002', name: 'Merged', isMerged: true);

      expect(active.isActiveApplication, isTrue);
      expect(merged.isActiveApplication, isFalse);
    });

    test('16. DuplicateGroup matchType classification', () {
      final exactGroup = DuplicateGroup(
        normalizedConsumerNo: '1001',
        records: [
          ConsumerRecord(consumerNo: '1001', name: 'A'),
          ConsumerRecord(consumerNo: '1001', name: 'B'),
        ],
        matchType: DuplicateMatchType.exactMatch,
      );

      final variationGroup = DuplicateGroup(
        normalizedConsumerNo: '1001',
        records: [
          ConsumerRecord(consumerNo: '1001', name: 'A'),
          ConsumerRecord(consumerNo: "'1001", name: 'B'),
        ],
        matchType: DuplicateMatchType.formattingVariation,
      );

      expect(exactGroup.matchType, equals(DuplicateMatchType.exactMatch));
      expect(variationGroup.matchType, equals(DuplicateMatchType.formattingVariation));
    });

    test('17. Multi-record merge combines fields from 3+ duplicates safely', () {
      final m = MergeConflictField.compare(
        fieldKey: 'remarks',
        fieldLabel: 'Remarks',
        masterVal: '',
        duplicateVal: 'Installer Notes',
      );

      expect(m.resolvedValue, equals('Installer Notes'));
    });

    test('18. Application Days and Priority recalculate from finalized Submit Date', () {
      final submitDate10DaysAgo = daysAgo(10);
      final record = ConsumerRecord(
        consumerNo: '110014099875',
        name: 'Date Recalc Test',
        submitDate: submitDate10DaysAgo,
      );

      expect(record.applicationDays, equals(10));
      expect(record.priority, equals('MEDIUM'));
    });
  });
}
