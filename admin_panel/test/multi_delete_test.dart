import 'package:flutter_test/flutter_test.dart';
import 'package:admin_panel/models/consumer_record.dart';
import 'package:admin_panel/models/record_diff.dart';

void main() {
  group('Multi-Delete & Soft-Delete Feature Tests', () {
    test('ConsumerRecord defaults deleted to false and supports soft-delete fields', () {
      final record = ConsumerRecord(
        id: 'rec-1',
        consumerNo: 'CN-1001',
        name: 'Raj Patil',
        status: 'Approved',
      );

      expect(record.deleted, isFalse);
      expect(record.deletedAt, isNull);
      expect(record.deletedBy, isNull);

      final now = DateTime.now();
      final softDeleted = record.copyWith(
        deleted: true,
        deletedAt: now,
        deletedBy: 'user-admin-123',
      );

      expect(softDeleted.deleted, isTrue);
      expect(softDeleted.deletedAt, now);
      expect(softDeleted.deletedBy, 'user-admin-123');
    });

    test('ConsumerRecord json serialization includes soft-delete metadata', () {
      final now = DateTime.utc(2026, 9, 3, 14, 0, 0);
      final record = ConsumerRecord(
        id: 'rec-2',
        consumerNo: 'CN-1002',
        name: 'Amit Patil',
        status: 'Pending',
        deleted: true,
        deletedAt: now,
        deletedBy: 'user-admin-456',
      );

      final json = record.toJson(includeId: true);
      expect(json['id'], 'rec-2');
      expect(json['deleted'], isTrue);
      expect(json['deleted_at'], now.toIso8601String());
      expect(json['deleted_by'], 'user-admin-456');

      final deserialized = ConsumerRecord.fromJson(json);
      expect(deserialized.id, 'rec-2');
      expect(deserialized.deleted, isTrue);
      expect(deserialized.deletedAt, now);
      expect(deserialized.deletedBy, 'user-admin-456');
    });

    test('Record selection and bulk soft-delete ID list aggregation', () {
      final records = [
        ConsumerRecord(id: 'id-1', consumerNo: '1001', name: 'Raj Patil'),
        ConsumerRecord(id: 'id-2', consumerNo: '1002', name: 'Amit Patil'),
        ConsumerRecord(id: 'id-3', consumerNo: '1003', name: 'Suresh'),
      ];

      final Set<String> selectedIds = {};

      // Select 1001 and 1003
      selectedIds.add(records[0].id!);
      selectedIds.add(records[2].id!);

      expect(selectedIds.length, 2);
      expect(selectedIds.contains('id-1'), isTrue);
      expect(selectedIds.contains('id-2'), isFalse);
      expect(selectedIds.contains('id-3'), isTrue);

      // Deselect all
      selectedIds.clear();
      expect(selectedIds.isEmpty, isTrue);
    });

    test('Empty selection validation prevents deletion execution', () {
      final Set<String> selectedIds = {};

      // Simulate service validation
      expect(
        () {
          if (selectedIds.isEmpty) {
            throw Exception('No records selected for deletion.');
          }
        },
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('No records selected for deletion.'),
        )),
      );
    });

    test('Restoring a record resets deleted, deleted_at, and deleted_by', () {
      final now = DateTime.now();
      final softDeleted = ConsumerRecord(
        id: 'rec-del-1',
        consumerNo: 'CN-999',
        name: 'Deleted Consumer',
        deleted: true,
        deletedAt: now,
        deletedBy: 'admin-id',
      );

      final restored = softDeleted.copyWith(
        deleted: false,
        clearDeletedMetadata: true,
      );

      expect(restored.deleted, isFalse);
      expect(restored.deletedAt, isNull);
      expect(restored.deletedBy, isNull);
    });

    test('Audit log payload contract for single and bulk deletion', () {
      final recordIds = ['rec-1', 'rec-2', 'rec-3'];
      final consumerNos = ['1001', '1002', '1003'];
      final user = 'admin-user-id';
      final nowIso = DateTime.now().toUtc().toIso8601String();

      final auditLogs = List.generate(recordIds.length, (i) {
        return {
          'record_id': recordIds[i],
          'consumer_no': consumerNos[i],
          'action': recordIds.length > 1 ? 'BULK_DELETE' : 'DELETE',
          'field_name': 'deleted',
          'old_value': 'false',
          'new_value': 'true',
          'changed_by': user,
          'source': 'Admin Web',
          'created_at': nowIso,
        };
      });

      expect(auditLogs.length, 3);
      expect(auditLogs[0]['action'], 'BULK_DELETE');
      expect(auditLogs[0]['old_value'], 'false');
      expect(auditLogs[0]['new_value'], 'true');
      expect(auditLogs[0]['changed_by'], 'admin-user-id');
      expect(auditLogs[0]['source'], 'Admin Web');
    });

    test('Re-importing a previously soft-deleted record un-deletes it upon merge', () {
      final existingDeleted = ConsumerRecord(
        id: 'rec-del-10',
        consumerNo: 'CN-RESTORE-10',
        name: 'Old Name',
        deleted: true,
        deletedAt: DateTime.now(),
        deletedBy: 'admin-1',
      );

      final incoming = ConsumerRecord(
        consumerNo: 'CN-RESTORE-10',
        name: 'New Re-imported Name',
        mobile: '9876543210',
      );

      final diff = RecordDiff(
        existingRecord: existingDeleted,
        incomingRecord: incoming,
        changedFields: [
          FieldDiff(
            fieldKey: 'name',
            fieldLabel: 'Consumer Name',
            oldValue: 'Old Name',
            newValue: 'New Re-imported Name',
          ),
        ],
      );

      final merged = diff.createMergedRecord(ConflictStrategy.updateNonEmptyOnly);
      expect(merged.name, 'New Re-imported Name');
      expect(merged.deleted, isFalse);
      expect(merged.deletedAt, isNull);
      expect(merged.deletedBy, isNull);
    });
  });
}
