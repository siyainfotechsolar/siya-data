import 'package:flutter_test/flutter_test.dart';
import 'package:admin_panel/models/consumer_record.dart';
import 'package:admin_panel/services/record_service.dart';

void main() {
  group('Non-Subsidy Only Dashboard Logic Tests', () {
    test('DashboardMetrics holds pure Non-Subsidy data with zero Subsidy metrics', () {
      final metrics = DashboardMetrics(
        totalRecords: 42,
        activeUsers: 5,
        recentlyUpdated: 10,
        statusCounts: {'Pending': 12, 'Completed': 30},
        recentRecords: [
          ConsumerRecord(
            consumerNo: 'NS-101',
            name: 'Kisan Agro Cold Storage',
            siteType: 'Non-Subsidy',
            status: 'Completed',
          ),
        ],
        agreementPendingCount: 4,
        loanPendingCount: 2,
        installationPendingCount: 5,
        rtsPendingCount: 1,
        subsidyPendingCount: 0, // Must be 0 for Non-Subsidy
        completedCount: 30,
        noActionCount: 3,
        subsidySitesCount: 0, // Must be 0
        nonSubsidySitesCount: 42,
        totalPaymentAmount: 1500000.0,
        paidPaymentAmount: 1100000.0,
        pendingPaymentAmount: 400000.0,
        pendingPaymentsCount: 8,
        pendingTasksCount: 12,
        completedTasksCount: 34,
      );

      // Verify Non-Subsidy customer count
      expect(metrics.totalRecords, equals(42));
      expect(metrics.nonSubsidySitesCount, equals(42));
      expect(metrics.subsidySitesCount, equals(0));

      // Verify Completed Sites count
      expect(metrics.completedCount, equals(30));

      // Verify Tasks linked to Non-Subsidy
      expect(metrics.pendingTasksCount, equals(12));
      expect(metrics.completedTasksCount, equals(34));

      // Verify Payments
      expect(metrics.totalPaymentAmount, equals(1500000.0));
      expect(metrics.paidPaymentAmount, equals(1100000.0));
      expect(metrics.pendingPaymentAmount, equals(400000.0));
      expect(metrics.pendingPaymentsCount, equals(8));

      // Verify Subsidy queue is zero
      expect(metrics.subsidyPendingCount, equals(0));
    });

    test('Filter logic strictly separates Non-Subsidy from Subsidy records', () {
      final allRecords = [
        ConsumerRecord(consumerNo: 'SUB-1', name: 'User 1', siteType: 'Subsidy', status: 'Completed', totalAmount: 150000, paidAmount: 150000),
        ConsumerRecord(consumerNo: 'NS-1', name: 'User 2', siteType: 'Non-Subsidy', status: 'Completed', totalAmount: 300000, paidAmount: 300000),
        ConsumerRecord(consumerNo: 'NS-2', name: 'User 3', siteType: 'Non-Subsidy', status: 'Pending', totalAmount: 500000, paidAmount: 200000),
        ConsumerRecord(consumerNo: 'SUB-2', name: 'User 4', siteType: 'Subsidy', status: 'Pending', totalAmount: 200000, paidAmount: 50000),
      ];

      // Non-Subsidy filtering
      final nonSubsidyList = allRecords.where((r) => (r.siteType ?? '').toLowerCase() == 'non-subsidy').toList();

      expect(nonSubsidyList.length, equals(2));
      expect(nonSubsidyList.every((r) => r.siteType == 'Non-Subsidy'), isTrue);

      // Non-Subsidy completed count
      final completedNonSubsidy = nonSubsidyList.where((r) => r.status.toLowerCase() == 'completed').length;
      expect(completedNonSubsidy, equals(1));

      // Non-Subsidy payment totals
      final totalContract = nonSubsidyList.fold<double>(0.0, (sum, r) => sum + (r.totalAmount ?? 0.0));
      final paidTotal = nonSubsidyList.fold<double>(0.0, (sum, r) => sum + (r.paidAmount ?? 0.0));
      final pendingTotal = totalContract - paidTotal;

      expect(totalContract, equals(800000.0));
      expect(paidTotal, equals(500000.0));
      expect(pendingTotal, equals(300000.0));
    });
  });
}
