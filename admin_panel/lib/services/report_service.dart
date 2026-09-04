import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/consumer_record.dart';
import '../models/report_filter_options.dart';

class StageStatusMetric {
  final String stage;
  final String status;
  final int count;

  const StageStatusMetric({
    required this.stage,
    required this.status,
    required this.count,
  });
}

class ReportSummaryMetrics {
  final int totalApplications;
  final int activeApplications;
  final int pending;
  final int critical;
  final int high;
  final int medium;
  final int normal;
  final int completed;

  const ReportSummaryMetrics({
    this.totalApplications = 0,
    this.activeApplications = 0,
    this.pending = 0,
    this.critical = 0,
    this.high = 0,
    this.medium = 0,
    this.normal = 0,
    this.completed = 0,
  });
}

class WorkflowSummaryMetrics {
  final int application;
  final int agreement;
  final int loan;
  final int installation;
  final int rts;
  final int subsidy;
  final int completed;

  const WorkflowSummaryMetrics({
    this.application = 0,
    this.agreement = 0,
    this.loan = 0,
    this.installation = 0,
    this.rts = 0,
    this.subsidy = 0,
    this.completed = 0,
  });
}

class ReportService {
  static SupabaseClient get _client => Supabase.instance.client;

  /// Fetches raw active consumer records from Supabase (excluding deleted and merged records)
  static Future<List<ConsumerRecord>> fetchAllActiveRecords() async {
    final response = await _client
        .from('consumer_records')
        .select('*')
        .eq('deleted', false)
        .eq('is_merged', false)
        .order('submit_date', ascending: false);

    final list = (response as List<dynamic>)
        .map((json) => ConsumerRecord.fromJson(json as Map<String, dynamic>))
        .toList();

    return list;
  }

  /// Filters a list of consumer records using the given ReportFilterOptions
  static List<ConsumerRecord> applyFilters(
    List<ConsumerRecord> records,
    ReportFilterOptions options,
  ) {
    var result = records.where((r) {
      if (r.deleted || r.isMerged) return false;

      // 0. Customer Scope Filter (Active, Completed, All)
      if (options.customerScope == 'Active') {
        if (r.isFullyCompleted || r.subsidyStatus.toLowerCase() == 'received') {
          return false;
        }
      } else if (options.customerScope == 'Completed') {
        if (!r.isFullyCompleted && r.subsidyStatus.toLowerCase() != 'received') {
          return false;
        }
      }

      // 1. Application Date Range
      if (options.applicationDateFrom != null) {
        if (r.applicationDate == null || r.applicationDate!.isBefore(options.applicationDateFrom!)) {
          return false;
        }
      }
      if (options.applicationDateTo != null) {
        final endOfTo = options.applicationDateTo!.add(const Duration(days: 1));
        if (r.applicationDate == null || !r.applicationDate!.isBefore(endOfTo)) {
          return false;
        }
      }

      // 2. Submit Date Range
      if (options.submitDateFrom != null) {
        if (r.submitDate == null || r.submitDate!.isBefore(options.submitDateFrom!)) {
          return false;
        }
      }
      if (options.submitDateTo != null) {
        final endOfTo = options.submitDateTo!.add(const Duration(days: 1));
        if (r.submitDate == null || !r.submitDate!.isBefore(endOfTo)) {
          return false;
        }
      }

      // 3. Work Stage Filter
      if (options.workStage != null && options.workStage!.isNotEmpty) {
        if (r.overallStage.toLowerCase() != options.workStage!.toLowerCase()) {
          return false;
        }
      }

      // 4. Status Filter
      if (options.status != null && options.status!.isNotEmpty) {
        if (r.status.toLowerCase() != options.status!.toLowerCase()) {
          return false;
        }
      }

      // 5. Priority Filter
      if (options.priority != null && options.priority!.isNotEmpty) {
        if (r.priority.toLowerCase() != options.priority!.toLowerCase()) {
          return false;
        }
      }

      // 6. Loan Status Filter
      if (options.loanStatus != null && options.loanStatus!.isNotEmpty) {
        if (r.loanStatus.toLowerCase() != options.loanStatus!.toLowerCase()) {
          return false;
        }
      }

      // 7. Installation Status Filter
      if (options.installationStatus != null && options.installationStatus!.isNotEmpty) {
        if (r.installationStatus.toLowerCase() != options.installationStatus!.toLowerCase()) {
          return false;
        }
      }

      // 8. RTS Status Filter
      if (options.rtsStatus != null && options.rtsStatus!.isNotEmpty) {
        if (r.rtsStatus.toLowerCase() != options.rtsStatus!.toLowerCase()) {
          return false;
        }
      }

      // 9. Subsidy Status Filter
      if (options.subsidyStatus != null && options.subsidyStatus!.isNotEmpty) {
        if (r.subsidyStatus.toLowerCase() != options.subsidyStatus!.toLowerCase()) {
          return false;
        }
      }

      // 10. Staff Filter
      if (options.assignedStaff != null && options.assignedStaff!.isNotEmpty) {
        final staffQuery = options.assignedStaff!.toLowerCase();
        final createdBy = (r.createdBy ?? '').toLowerCase();
        final updatedBy = (r.updatedBy ?? '').toLowerCase();
        if (!createdBy.contains(staffQuery) && !updatedBy.contains(staffQuery)) {
          return false;
        }
      }

      // 11. Search Query
      if (options.searchQuery.trim().isNotEmpty) {
        final q = options.searchQuery.trim().toLowerCase();
        final matchName = r.name.toLowerCase().contains(q);
        final matchConsumerNo = r.consumerNo.toLowerCase().contains(q);
        final matchAppId = (r.applicationId ?? '').toLowerCase().contains(q);
        final matchMobile = (r.mobile ?? '').toLowerCase().contains(q);
        if (!matchName && !matchConsumerNo && !matchAppId && !matchMobile) {
          return false;
        }
      }

      return true;
    }).toList();

    // Sorting
    result.sort((a, b) {
      int comparison = 0;
      switch (options.sortBy) {
        case 'days':
          comparison = a.applicationDays.compareTo(b.applicationDays);
          break;
        case 'app_date':
          final dA = a.applicationDate ?? DateTime(1970);
          final dB = b.applicationDate ?? DateTime(1970);
          comparison = dA.compareTo(dB);
          break;
        case 'submit_date':
          final dA = a.submitDate ?? DateTime(1970);
          final dB = b.submitDate ?? DateTime(1970);
          comparison = dA.compareTo(dB);
          break;
        case 'priority':
          comparison = a.priorityLevel.rank.compareTo(b.priorityLevel.rank); // lower rank = higher priority
          break;
        case 'stage':
          comparison = a.overallStage.compareTo(b.overallStage);
          break;
        case 'status':
          comparison = a.status.compareTo(b.status);
          break;
        case 'name':
          comparison = a.name.compareTo(b.name);
          break;
        default:
          comparison = a.applicationDays.compareTo(b.applicationDays);
      }
      return options.sortAscending ? comparison : -comparison;
    });

    return result;
  }

  /// Calculates executive summary metrics
  static ReportSummaryMetrics computeSummaryMetrics(List<ConsumerRecord> records) {
    int total = records.length;
    int active = 0;
    int pending = 0;
    int critical = 0;
    int high = 0;
    int medium = 0;
    int normal = 0;
    int completed = 0;

    for (final r in records) {
      if (r.isFullyCompleted) {
        completed++;
      } else {
        active++;
      }

      if (r.status.toLowerCase() == 'pending' || r.status.toLowerCase() == 'submitted') {
        pending++;
      }

      switch (r.priorityLevel) {
        case PriorityLevel.critical:
          critical++;
          break;
        case PriorityLevel.high:
          high++;
          break;
        case PriorityLevel.medium:
          medium++;
          break;
        case PriorityLevel.normal:
          normal++;
          break;
      }
    }

    return ReportSummaryMetrics(
      totalApplications: total,
      activeApplications: active,
      pending: pending,
      critical: critical,
      high: high,
      medium: medium,
      normal: normal,
      completed: completed,
    );
  }

  /// Calculates 6-stage workflow breakdown counts
  static WorkflowSummaryMetrics computeWorkflowMetrics(List<ConsumerRecord> records) {
    int appCount = 0;
    int agreeCount = 0;
    int loanCount = 0;
    int installCount = 0;
    int rtsCount = 0;
    int subCount = 0;
    int compCount = 0;

    for (final r in records) {
      switch (r.overallStage) {
        case 'Application':
          appCount++;
          break;
        case 'Agreement':
          agreeCount++;
          break;
        case 'Loan':
          loanCount++;
          break;
        case 'Installation':
          installCount++;
          break;
        case 'RTS':
          rtsCount++;
          break;
        case 'Subsidy':
          subCount++;
          break;
        case 'Completed':
          compCount++;
          break;
      }
    }

    return WorkflowSummaryMetrics(
      application: appCount,
      agreement: agreeCount,
      loan: loanCount,
      installation: installCount,
      rts: rtsCount,
      subsidy: subCount,
      completed: compCount,
    );
  }

  /// Calculates stage-wise status breakdown table
  static List<StageStatusMetric> computeStageWisePending(List<ConsumerRecord> records) {
    final Map<String, int> countsMap = {};

    for (final r in records) {
      final stage = r.overallStage;
      String currentStatus = r.status;

      // Extract specific stage status for detail
      switch (stage) {
        case 'Application':
          currentStatus = r.applicationStatus;
          break;
        case 'Agreement':
          currentStatus = r.agreementStatus;
          break;
        case 'Loan':
          currentStatus = r.loanStatus;
          break;
        case 'Installation':
          currentStatus = r.installationStatus;
          break;
        case 'RTS':
          currentStatus = r.rtsStatus;
          break;
        case 'Subsidy':
          currentStatus = r.subsidyStatus;
          break;
        case 'Completed':
          currentStatus = 'Completed';
          break;
      }

      final key = '$stage|$currentStatus';
      countsMap[key] = (countsMap[key] ?? 0) + 1;
    }

    final List<StageStatusMetric> metrics = [];
    countsMap.forEach((key, count) {
      final parts = key.split('|');
      metrics.add(StageStatusMetric(
        stage: parts[0],
        status: parts[1],
        count: count,
      ));
    });

    // Sort by count descending
    metrics.sort((a, b) => b.count.compareTo(a.count));
    return metrics;
  }
}
