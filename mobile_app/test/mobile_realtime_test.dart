import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/models/consumer_record.dart';
import 'package:mobile_app/services/realtime_service.dart';

void main() {
  group('Mobile App Realtime Sync Tests', () {
    test('Correctly parses Realtime Change Event on Mobile', () {
      final payload = {
        'id': 'mob-rt-1',
        'consumer_no': 'MOB-RT-1',
        'name': 'Rahul Shinde',
        'mobile': '9988776655',
        'status': 'Approved',
        'deleted': false,
      };

      final record = ConsumerRecord.fromJson(payload);
      final event = MobileRecordChangeEvent(
        type: MobileRealtimeChangeType.update,
        record: record,
        recordId: record.id!,
        rawPayload: payload,
      );

      expect(event.type, MobileRealtimeChangeType.update);
      expect(event.record!.name, 'Rahul Shinde');
      expect(event.record!.status, 'Approved');
    });

    test('Mobile in-memory list updates dynamically when status changes remotely', () {
      final records = [
        ConsumerRecord(id: 'r1', consumerNo: 'C100', name: 'John Doe', status: 'Pending'),
        ConsumerRecord(id: 'r2', consumerNo: 'C200', name: 'Jane Doe', status: 'Pending'),
      ];

      final incomingUpdate = ConsumerRecord(
        id: 'r1',
        consumerNo: 'C100',
        name: 'John Doe',
        status: 'Completed',
        remarks: 'Panel connected',
      );

      final idx = records.indexWhere((r) => r.id == incomingUpdate.id);
      expect(idx, 0);

      records[idx] = incomingUpdate;

      expect(records[0].status, 'Completed');
      expect(records[0].remarks, 'Panel connected');
      expect(records[1].status, 'Pending');
    });
  });
}
