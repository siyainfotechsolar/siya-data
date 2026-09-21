import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/models/consumer_record.dart';
import 'package:mobile_app/models/lead_record.dart';

void main() {
  group('Mobile App Non-Subsidy Dashboard Aggregates & Task Linkage Tests', () {
    test('Calculates pure Non-Subsidy customer and payment aggregates', () {
      final records = [
        ConsumerRecord(
          id: 'sub_1',
          consumerNo: 'SUB-101',
          name: 'Subsidy Farmer',
          siteType: 'Subsidy',
          status: 'Completed',
          totalAmount: 200000.0,
          paidAmount: 200000.0,
          pendingAmount: 0.0,
        ),
        ConsumerRecord(
          id: 'ns_1',
          consumerNo: 'NS-201',
          name: 'Factory Site Alpha',
          siteType: 'Non-Subsidy',
          status: 'Completed',
          totalAmount: 1200000.0,
          paidAmount: 1000000.0,
          pendingAmount: 200000.0,
        ),
        ConsumerRecord(
          id: 'ns_2',
          consumerNo: 'NS-202',
          name: 'Commercial Shop Beta',
          siteType: 'Non-Subsidy',
          status: 'In Progress',
          totalAmount: 500000.0,
          paidAmount: 100000.0,
          pendingAmount: 400000.0,
        ),
      ];

      // Pure Non-Subsidy filter
      final nonSubsidyRecords = records.where((r) => r.isNonSubsidy).toList();

      expect(nonSubsidyRecords.length, equals(2));
      expect(nonSubsidyRecords.every((r) => r.siteType == 'Non-Subsidy'), isTrue);

      // Total Non-Subsidy customers
      final totalNonSubsidy = nonSubsidyRecords.length;
      expect(totalNonSubsidy, equals(2));

      // Completed Sites count
      final completedSites = nonSubsidyRecords.where((r) => r.status.toLowerCase() == 'completed').length;
      expect(completedSites, equals(1));

      // Payment aggregates for Non-Subsidy
      double totalPay = 0.0;
      double paidPay = 0.0;
      int pendingCount = 0;

      for (final r in nonSubsidyRecords) {
        final total = r.totalAmount ?? 0.0;
        final paid = r.paidAmount ?? 0.0;
        totalPay += total;
        paidPay += paid;
        if ((total - paid) > 0 || (r.pendingAmount != null && r.pendingAmount! > 0)) {
          pendingCount++;
        }
      }
      final pendingPay = (totalPay - paidPay) > 0 ? (totalPay - paidPay) : 0.0;

      expect(totalPay, equals(1700000.0));
      expect(paidPay, equals(1100000.0));
      expect(pendingPay, equals(600000.0));
      expect(pendingCount, equals(2));
    });

    test('Filters tasks to only those linked to Non-Subsidy customers', () {
      final nonSubsidyConsumerNos = {'NS-201', 'NS-202', 'cust_ns_1'};

      final tasks = [
        {'id': 't1', 'consumer_no': 'NS-201', 'status': 'Pending', 'task_type': 'Meter Test'},
        {'id': 't2', 'consumer_no': 'SUB-101', 'status': 'Pending', 'task_type': 'Subsidy Document'},
        {'id': 't3', 'consumer_no': 'NS-202', 'status': 'Completed', 'task_type': 'Wiring Inspection'},
        {'id': 't4', 'customer_id': 'cust_ns_1', 'status': 'Pending', 'task_type': 'Inverter Commissioning'},
        {'id': 't5', 'consumer_no': 'SUB-102', 'status': 'Completed', 'task_type': 'Net Metering'},
      ];

      // Non-subsidy task filter
      final linkedTasks = tasks.where((t) {
        final cNo = (t['consumer_no'] ?? '').toString();
        final cId = (t['customer_id'] ?? '').toString();
        return (cNo.isNotEmpty && nonSubsidyConsumerNos.contains(cNo)) ||
               (cId.isNotEmpty && nonSubsidyConsumerNos.contains(cId));
      }).toList();

      expect(linkedTasks.length, equals(3));
      expect(linkedTasks.map((t) => t['id']), containsAll(['t1', 't3', 't4']));
      expect(linkedTasks.any((t) => t['id'] == 't2' || t['id'] == 't5'), isFalse);

      final pendingTasks = linkedTasks.where((t) => t['status'] == 'Pending').length;
      final completedTasks = linkedTasks.where((t) => t['status'] == 'Completed').length;

      expect(pendingTasks, equals(2));
      expect(completedTasks, equals(1));
    });
  });
}
