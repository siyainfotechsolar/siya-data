import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/models/consumer_record.dart';

void main() {
  group('Mobile App ConsumerRecord Model Tests', () {
    test('Mobile ConsumerRecord deserializes from JSON with soft delete fields', () {
      final json = {
        'id': 'mob-rec-1',
        'consumer_no': 'MOB-1001',
        'name': 'Sanjay Sharma',
        'mobile': '9876500000',
        'address': 'Pune, Maharashtra',
        'application_id': 'APP-MOB-1',
        'status': 'In Progress',
        'remarks': 'Site survey done',
        'deleted': false,
        'created_at': '2026-09-03T10:00:00.000Z',
        'updated_at': '2026-09-03T12:00:00.000Z',
      };

      final record = ConsumerRecord.fromJson(json);

      expect(record.id, 'mob-rec-1');
      expect(record.consumerNo, 'MOB-1001');
      expect(record.name, 'Sanjay Sharma');
      expect(record.mobile, '9876500000');
      expect(record.address, 'Pune, Maharashtra');
      expect(record.status, 'In Progress');
      expect(record.remarks, 'Site survey done');
      expect(record.deleted, isFalse);
    });

    test('Mobile ConsumerRecord serializes to JSON with correct keys', () {
      final record = ConsumerRecord(
        id: 'mob-rec-2',
        consumerNo: 'MOB-1002',
        name: 'Vikas Jadhav',
        mobile: '9123400000',
        status: 'Completed',
        remarks: 'Panel mounting finished',
      );

      final json = record.toJson(includeId: true);

      expect(json['id'], 'mob-rec-2');
      expect(json['consumer_no'], 'MOB-1002');
      expect(json['name'], 'Vikas Jadhav');
      expect(json['status'], 'Completed');
      expect(json['remarks'], 'Panel mounting finished');
      expect(json['deleted'], isFalse);
    });

    test('Mobile ConsumerRecord status update via copyWith', () {
      final record = ConsumerRecord(
        consumerNo: 'MOB-1003',
        name: 'Ganesh Shinde',
        status: 'Pending',
      );

      final updated = record.copyWith(
        status: 'Installed',
        remarks: 'Meter connected and verified',
      );

      expect(updated.status, 'Installed');
      expect(updated.remarks, 'Meter connected and verified');
      expect(updated.consumerNo, 'MOB-1003');
    });
  });
}
