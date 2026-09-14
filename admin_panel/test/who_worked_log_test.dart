import 'package:flutter_test/flutter_test.dart';
import 'package:admin_panel/models/activity_log.dart';
import 'package:admin_panel/services/activity_log_service.dart';

void main() {
  group('Who Worked Log & Activity History Tests (Admin Panel)', () {
    test('ActivityLog correctly models operational activity with exact fields', () {
      final log = ActivityLog(
        id: 'act-001',
        recordId: 'rec-123',
        consumerNo: '2013847291',
        customerName: 'RAJENDRA KOTHAWADE',
        village: 'Nashik',
        module: 'Loan',
        action: 'Loan Status Updated',
        oldValue: 'File at Bank',
        newValue: 'Approved',
        nextAction: 'Installation Scheduled',
        remarks: 'Branch manager sanctioned loan',
        staffId: 'usr-1',
        staffName: 'Rushikesh',
        staffRole: 'Loan',
        source: 'Admin Web',
        createdAt: DateTime(2026, 9, 14, 10, 32),
      );

      expect(log.consumerNo, equals('2013847291'));
      expect(log.customerName, equals('RAJENDRA KOTHAWADE'));
      expect(log.staffName, equals('Rushikesh'));
      expect(log.module, equals('Loan'));
      expect(log.action, equals('Loan Status Updated'));
      expect(log.oldValue, equals('File at Bank'));
      expect(log.newValue, equals('Approved'));
      expect(log.formattedDate, equals('14/09/2026'));
      expect(log.formattedTime, equals('10:32 AM'));
      expect(log.formattedDateTime, equals('14/09/2026 10:32 AM'));
    });

    test('StaffWorkMetric correctly represents WHO WORKED TODAY metrics', () {
      const metric = StaffWorkMetric(
        staffName: 'Rushikesh',
        staffRole: 'Loan Staff',
        totalActions: 18,
        customersWorked: 12,
        completed: 8,
        pending: 4,
        followups: 3,
        issues: 0,
        installations: 0,
        payments: 2,
      );

      expect(metric.staffName, equals('Rushikesh'));
      expect(metric.totalActions, equals(18));
      expect(metric.customersWorked, equals(12));
      expect(metric.completed, equals(8));
      expect(metric.pending, equals(4));
    });

    test('exportActivityToCsv generates proper Excel-compatible CSV headers', () {
      final logs = [
        ActivityLog(
          id: 'act-1',
          consumerNo: '112233',
          customerName: 'Rajendra Kothawade',
          village: 'Nashik',
          module: 'Loan',
          action: 'Loan Status Updated',
          oldValue: 'File at Bank',
          newValue: 'Approved',
          remarks: 'Done',
          staffName: 'Rushikesh',
          staffRole: 'Loan',
          source: 'Admin Web',
          createdAt: DateTime(2026, 9, 14, 10, 32),
        ),
      ];

      final csv = ActivityLogService.exportActivityToCsv(logs);
      expect(
        csv,
        contains('Date,Time,Staff,Role,Customer,Consumer No,Village,Module,Action,Old Value,New Value,Remarks'),
      );
      expect(csv, contains('Rushikesh,Loan,Rajendra Kothawade,112233,Nashik,Loan,Loan Status Updated'));
    });
  });
}
