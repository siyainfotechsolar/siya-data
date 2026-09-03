import 'package:flutter_test/flutter_test.dart';
import 'package:admin_panel/models/consumer_record.dart';
import 'package:admin_panel/services/realtime_service.dart';

void main() {
  group('Admin Panel Realtime Sync Tests', () {
    test('Correctly parses Realtime Change Payload for UPDATE', () {
      final updatePayload = {
        'id': 'realtime-rec-1',
        'consumer_no': 'RT-1001',
        'name': 'Mahesh Joshi',
        'mobile': '9876543210',
        'address': 'Nashik, Maharashtra',
        'status': 'Completed',
        'remarks': 'Installation verified on site',
        'deleted': false,
        'updated_at': '2026-09-03T15:00:00.000Z',
      };

      final record = ConsumerRecord.fromJson(updatePayload);
      final event = ConsumerRecordChangeEvent(
        type: RealtimeChangeType.update,
        record: record,
        recordId: record.id!,
        rawPayload: updatePayload,
      );

      expect(event.type, RealtimeChangeType.update);
      expect(event.recordId, 'realtime-rec-1');
      expect(event.record!.status, 'Completed');
      expect(event.record!.remarks, 'Installation verified on site');
      expect(event.record!.deleted, isFalse);
    });

    test('In-memory list update replacement logic', () {
      final records = [
        ConsumerRecord(id: '1', consumerNo: 'C1', name: 'User 1', status: 'Pending'),
        ConsumerRecord(id: '2', consumerNo: 'C2', name: 'User 2', status: 'Pending'),
      ];

      final updatedRecord = ConsumerRecord(
        id: '2',
        consumerNo: 'C2',
        name: 'User 2',
        status: 'In Progress',
        remarks: 'Survey in progress',
      );

      final index = records.indexWhere((r) => r.id == updatedRecord.id);
      expect(index, 1);

      records[index] = updatedRecord;

      expect(records[1].status, 'In Progress');
      expect(records[1].remarks, 'Survey in progress');
    });

    test('Realtime soft-delete evicts record from active list', () {
      final records = [
        ConsumerRecord(id: '1', consumerNo: 'C1', name: 'User 1', status: 'Pending'),
        ConsumerRecord(id: '2', consumerNo: 'C2', name: 'User 2', status: 'Pending'),
      ];

      final deletedRecord = ConsumerRecord(
        id: '1',
        consumerNo: 'C1',
        name: 'User 1',
        deleted: true,
      );

      final index = records.indexWhere((r) => r.id == deletedRecord.id);
      if (index != -1 && deletedRecord.deleted) {
        records.removeAt(index);
      }

      expect(records.length, 1);
      expect(records.first.id, '2');
    });
  });
}
