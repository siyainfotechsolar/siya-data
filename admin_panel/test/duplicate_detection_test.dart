import 'package:flutter_test/flutter_test.dart';
import 'package:admin_panel/models/consumer_record.dart';
import 'package:admin_panel/models/record_diff.dart';
import 'package:admin_panel/services/duplicate_detection_service.dart';

void main() {
  group('Duplicate Detection & Diff Engine Tests', () {
    test('Correctly computes field diffs between existing and incoming records', () {
      final existing = ConsumerRecord(
        id: 'rec-1',
        consumerNo: 'CN-100',
        name: 'Rajesh Patel',
        mobile: '9876543210',
        address: 'Ahmedabad Old Address',
        applicationId: 'APP-100',
        status: 'Pending',
        remarks: 'Original remark',
      );

      final incoming = ConsumerRecord(
        consumerNo: 'CN-100',
        name: 'Rajesh Patel', // Same
        mobile: '9876543210', // Same
        address: 'Ahmedabad New Address', // Changed
        applicationId: 'APP-100', // Same
        status: 'Approved', // Changed
        remarks: null, // Empty
      );

      final diffs = DuplicateDetectionService.computeFieldDiffs(existing, incoming);

      expect(diffs.length, 3);

      final addressDiff = diffs.firstWhere((d) => d.fieldKey == 'address');
      expect(addressDiff.oldValue, 'Ahmedabad Old Address');
      expect(addressDiff.newValue, 'Ahmedabad New Address');

      final statusDiff = diffs.firstWhere((d) => d.fieldKey == 'status');
      expect(statusDiff.oldValue, 'Pending');
      expect(statusDiff.newValue, 'Approved');

      final remarksDiff = diffs.firstWhere((d) => d.fieldKey == 'remarks');
      expect(remarksDiff.oldValue, 'Original remark');
      expect(remarksDiff.newValue, null);
    });

    test('ConflictStrategy.updateNonEmptyOnly preserves existing data when new value is empty', () {
      final existing = ConsumerRecord(
        id: 'rec-2',
        consumerNo: 'CN-200',
        name: 'Pooja Sharma',
        mobile: '9123456780',
        address: 'Surat',
        status: 'Approved',
      );

      final incoming = ConsumerRecord(
        consumerNo: 'CN-200',
        name: 'Pooja Sharma Updated',
        mobile: '', // Blank in Excel
        address: null, // Blank in Excel
        status: 'Installed',
      );

      final diffs = DuplicateDetectionService.computeFieldDiffs(existing, incoming);
      final recordDiff = RecordDiff(
        existingRecord: existing,
        incomingRecord: incoming,
        changedFields: diffs,
      );

      final merged = recordDiff.createMergedRecord(ConflictStrategy.updateNonEmptyOnly);

      expect(merged.name, 'Pooja Sharma Updated'); // Updated
      expect(merged.mobile, '9123456780'); // Preserved existing mobile
      expect(merged.address, 'Surat'); // Preserved existing address
      expect(merged.status, 'Installed'); // Updated
    });

    test('ConflictStrategy.overwriteAll replaces fields with new incoming values', () {
      final existing = ConsumerRecord(
        id: 'rec-3',
        consumerNo: 'CN-300',
        name: 'Sunil Kumar',
        mobile: '9998887776',
        address: 'Vadodara',
        status: 'Pending',
      );

      final incoming = ConsumerRecord(
        consumerNo: 'CN-300',
        name: 'Sunil Kumar',
        mobile: null, // User wants to clear mobile
        address: 'Vadodara New',
        status: 'Rejected',
      );

      final diffs = DuplicateDetectionService.computeFieldDiffs(existing, incoming);
      final recordDiff = RecordDiff(
        existingRecord: existing,
        incomingRecord: incoming,
        changedFields: diffs,
      );

      final merged = recordDiff.createMergedRecord(ConflictStrategy.overwriteAll);

      expect(merged.mobile, isNull); // Overwritten to null
      expect(merged.address, 'Vadodara New');
      expect(merged.status, 'Rejected');
    });

    test('ConflictStrategy.skipExisting preserves all existing record fields intact', () {
      final existing = ConsumerRecord(
        id: 'rec-4',
        consumerNo: 'CN-400',
        name: 'Original Name',
        mobile: '1111111111',
        status: 'Pending',
      );

      final incoming = ConsumerRecord(
        consumerNo: 'CN-400',
        name: 'Modified Name',
        mobile: '2222222222',
        status: 'Completed',
      );

      final diffs = DuplicateDetectionService.computeFieldDiffs(existing, incoming);
      final recordDiff = RecordDiff(
        existingRecord: existing,
        incomingRecord: incoming,
        changedFields: diffs,
      );

      final merged = recordDiff.createMergedRecord(ConflictStrategy.skipExisting);

      expect(merged.name, 'Original Name');
      expect(merged.mobile, '1111111111');
      expect(merged.status, 'Pending');
    });
  });
}
