import 'package:flutter_test/flutter_test.dart';
import 'package:admin_panel/models/consumer_record.dart';
import 'package:admin_panel/models/report_filter_options.dart';
import 'package:admin_panel/services/report_service.dart';

void main() {
  group('ReportService Tests', () {
    final now = DateTime.now();

    // Stage: Application (agreementNotRequired/Pending app)
    final rec1 = ConsumerRecord(
      id: '1',
      consumerNo: 'SI001',
      name: 'Ramesh Sharma',
      status: 'Pending',
      submitDate: now.subtract(const Duration(days: 35)), // Critical priority (35 days)
      applicationStatus: 'Submitted',
      agreementStatus: 'Verified',
      loanRequired: 'No',
    );

    // Stage: Loan
    final rec2 = ConsumerRecord(
      id: '2',
      consumerNo: 'SI002',
      name: 'Suresh Patil',
      status: 'Approved',
      submitDate: now.subtract(const Duration(days: 20)), // High priority (20 days)
      applicationStatus: 'Verified',
      agreementStatus: 'Verified',
      loanRequired: 'Yes',
      loanStatus: 'Applied',
    );

    // Stage: Completed
    final rec3 = ConsumerRecord(
      id: '3',
      consumerNo: 'SI003',
      name: 'Priya Verma',
      status: 'Completed',
      submitDate: now.subtract(const Duration(days: 5)), // Normal priority (5 days)
      applicationStatus: 'Completed',
      agreementStatus: 'Verified',
      loanStatus: 'Not Required',
      installationStatus: 'Installation Completed',
      rtsStatus: 'Completed',
      subsidyStatus: 'Received',
    );

    final mergedRec = ConsumerRecord(
      id: '4',
      consumerNo: 'SI001-DUP',
      name: 'Ramesh Sharma (Duplicate)',
      isMerged: true,
      mergedIntoId: '1',
    );

    final deletedRec = ConsumerRecord(
      id: '5',
      consumerNo: 'SI005',
      name: 'Deleted Customer',
      deleted: true,
    );

    final testRecords = [rec1, rec2, rec3, mergedRec, deletedRec];

    test('Filter logic strictly excludes soft-deleted and merged records', () {
      final filtered = ReportService.applyFilters(testRecords, const ReportFilterOptions());
      expect(filtered.length, equals(3));
      expect(filtered.any((r) => r.isMerged), isFalse);
      expect(filtered.any((r) => r.deleted), isFalse);
    });

    test('Priority calculation derives strictly from submitDate Application Days', () {
      final summary = ReportService.computeSummaryMetrics([rec1, rec2, rec3]);
      expect(summary.totalApplications, equals(3));
      expect(summary.critical, equals(1)); // rec1 (35 days)
      expect(summary.high, equals(1));     // rec2 (20 days)
      expect(summary.normal, equals(1));   // rec3 (5 days)
      expect(summary.completed, equals(1));
    });

    test('Workflow Summary calculates correct 6-stage record counts', () {
      final wf = ReportService.computeWorkflowMetrics([rec1, rec2, rec3]);
      expect(wf.application, equals(1)); // rec1
      expect(wf.loan, equals(1));        // rec2
      expect(wf.completed, equals(1));   // rec3
    });

    test('Stage-wise pending breakdown aggregates counts accurately', () {
      final stageWise = ReportService.computeStageWisePending([rec1, rec2, rec3]);
      expect(stageWise.isNotEmpty, isTrue);

      final appPending = stageWise.firstWhere((s) => s.stage == 'Application');
      expect(appPending.count, equals(1));

      final loanPending = stageWise.firstWhere((s) => s.stage == 'Loan');
      expect(loanPending.status, equals('Applied'));
      expect(loanPending.count, equals(1));
    });

    test('Filter by Priority correctly returns matching records', () {
      final filtered = ReportService.applyFilters(
        testRecords,
        const ReportFilterOptions(priority: 'CRITICAL'),
      );
      expect(filtered.length, equals(1));
      expect(filtered.first.consumerNo, equals('SI001'));
    });

    test('Filter by Current Work Stage returns matching records', () {
      final filtered = ReportService.applyFilters(
        testRecords,
        const ReportFilterOptions(workStage: 'Loan'),
      );
      expect(filtered.length, equals(1));
      expect(filtered.first.consumerNo, equals('SI002'));
    });
  });
}
