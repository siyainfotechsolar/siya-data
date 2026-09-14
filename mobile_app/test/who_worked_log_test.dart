import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/models/activity_log.dart';
import 'package:mobile_app/services/activity_log_service.dart';

void main() {
  group('Who Worked Log & Activity History Tests (Mobile)', () {
    test('ActivityLog correctly models operational action and formats date/time', () {
      final log = ActivityLog(
        id: 'act-001',
        recordId: 'rec-123',
        consumerNo: '2013847291',
        customerName: 'Rajendra Kothawade',
        village: 'Nashik',
        module: 'Loan',
        action: 'Loan Status Updated',
        oldValue: 'File at Bank',
        newValue: 'Approved',
        nextAction: 'Installation Scheduled',
        remarks: 'Branch manager sanctioned loan',
        staffId: 'usr-1',
        staffName: 'Rushikesh',
        staffRole: 'loan_staff',
        source: 'Mobile App',
        createdAt: DateTime(2026, 9, 14, 10, 32),
      );

      expect(log.consumerNo, equals('2013847291'));
      expect(log.customerName, equals('Rajendra Kothawade'));
      expect(log.staffName, equals('Rushikesh'));
      expect(log.staffRole, equals('loan_staff'));
      expect(log.module, equals('Loan'));
      expect(log.action, equals('Loan Status Updated'));
      expect(log.oldValue, equals('File at Bank'));
      expect(log.newValue, equals('Approved'));
      expect(log.formattedDate, equals('14/09/2026'));
      expect(log.formattedTime, equals('10:32 AM'));
      expect(log.formattedDateTime, equals('14/09/2026 10:32 AM'));
    });

    test('ActivityLog JSON serialization and deserialization roundtrip', () {
      final json = {
        'id': 'log-999',
        'record_id': 'rec-555',
        'consumer_no': '9988776655',
        'customer_name': 'Amit Patil',
        'village': 'Deola',
        'module': 'Installation',
        'action': 'Installation Completed',
        'old_value': 'Wiring Pending',
        'new_value': 'Installation Completed',
        'next_action': 'RTS Application',
        'remarks': '5kW system mounted and tested',
        'staff_id': 'usr-9',
        'staff_name': 'Vaibhav',
        'staff_role': 'installation_staff',
        'source': 'Mobile App',
        'created_at': '2026-09-14T11:45:00.000Z',
      };

      final log = ActivityLog.fromJson(json);
      expect(log.id, equals('log-999'));
      expect(log.customerName, equals('Amit Patil'));
      expect(log.staffName, equals('Vaibhav'));
      expect(log.action, equals('Installation Completed'));

      final outJson = log.toJson();
      expect(outJson['consumer_no'], equals('9988776655'));
      expect(outJson['staff_name'], equals('Vaibhav'));
      expect(outJson['action'], equals('Installation Completed'));
    });

    test('exportActivityToCsv generates RFC 4180 CSV with exact requested columns', () {
      final logs = [
        ActivityLog(
          id: 'act-1',
          consumerNo: '112233',
          customerName: 'Rushikesh Patil',
          village: 'Satana',
          module: 'Loan',
          action: 'Loan Approved',
          oldValue: 'Under Process',
          newValue: 'Approved',
          remarks: 'All documents clear',
          staffName: 'Rihan',
          staffRole: 'loan_staff',
          source: 'Mobile App',
          createdAt: DateTime(2026, 9, 14, 9, 30),
        ),
      ];

      final csv = ActivityLogService.exportActivityToCsv(logs);
      expect(
        csv,
        contains('Date,Time,Staff,Role,Customer,Consumer No,Village,Module,Action,Old Value,New Value,Remarks'),
      );
      expect(csv, contains('Rihan,loan_staff,Rushikesh Patil,112233,Satana,Loan,Loan Approved'));
      expect(csv, contains('Under Process,Approved,All documents clear'));
    });

    test('Activity Log enforces privacy: zero passwords or auth tokens recorded', () {
      final log = ActivityLog(
        id: 'act-safe',
        consumerNo: '445566',
        customerName: 'Safe Customer',
        village: 'Kalwan',
        module: 'Customer',
        action: 'Customer Created',
        staffName: 'Admin',
        staffRole: 'admin',
        source: 'Mobile App',
        createdAt: DateTime.now(),
      );

      final json = log.toJson();
      expect(json.containsKey('password'), isFalse);
      expect(json.containsKey('token'), isFalse);
      expect(json.containsKey('bearer'), isFalse);
      expect(json.containsKey('auth_token'), isFalse);
    });
  });
}
