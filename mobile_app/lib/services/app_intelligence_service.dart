import 'package:flutter/material.dart';
import '../models/consumer_record.dart';
import 'app_database.dart';
import 'workflow_engine.dart';

/// Operational Intelligence Model
class OperationalInsights {
  final int stalledCount;
  final int paymentActionCount;
  final int loanAttentionCount;
  final int followupDueCount;
  final double totalPendingCollection;
  final List<ConsumerRecord> criticalRecords;
  final List<ConsumerRecord> stalledRecords;
  final List<ConsumerRecord> paymentOpportunityRecords;
  final List<ConsumerRecord> loanAttentionRecords;
  final List<ConsumerRecord> followupDueRecords;

  const OperationalInsights({
    required this.stalledCount,
    required this.paymentActionCount,
    required this.loanAttentionCount,
    required this.followupDueCount,
    required this.totalPendingCollection,
    required this.criticalRecords,
    this.stalledRecords = const [],
    this.paymentOpportunityRecords = const [],
    this.loanAttentionRecords = const [],
    this.followupDueRecords = const [],
  });

  static OperationalInsights empty() => const OperationalInsights(
        stalledCount: 0,
        paymentActionCount: 0,
        loanAttentionCount: 0,
        followupDueCount: 0,
        totalPendingCollection: 0.0,
        criticalRecords: [],
        stalledRecords: [],
        paymentOpportunityRecords: [],
        loanAttentionRecords: [],
        followupDueRecords: [],
      );
}

/// Customer-level Intelligence
class CustomerIntelligence {
  final String nextBestAction;
  final String actionContext;
  final double? suggestedPaymentAmount;
  final String riskLevel; // 'LOW', 'MEDIUM', 'HIGH'
  final Color riskColor;
  final int daysInStage;

  String get context => actionContext;
  int get daysInCurrentStage => daysInStage;

  const CustomerIntelligence({
    required this.nextBestAction,
    required this.actionContext,
    this.suggestedPaymentAmount,
    required this.riskLevel,
    required this.riskColor,
    required this.daysInStage,
  });
}

class AppIntelligenceService {
  /// Generate comprehensive operational insights from cached local records
  static Future<OperationalInsights> computeInsights() async {
    try {
      final records = await AppDatabase.getAllConsumerRecords();
      int stalled = 0;
      int paymentAction = 0;
      int loanAttention = 0;
      int followupDue = 0;
      double pendingCollection = 0.0;
      final List<ConsumerRecord> criticalList = [];
      final List<ConsumerRecord> stalledList = [];
      final List<ConsumerRecord> paymentList = [];
      final List<ConsumerRecord> loanList = [];
      final List<ConsumerRecord> followupList = [];

      final now = DateTime.now();
      final todayStr = now.toIso8601String().split('T')[0];

      for (final r in records) {
        if (r.isDeleted || WorkflowEngine.isWorkCompleted(r)) continue;

        final stage = WorkflowEngine.getCurrentWorkStage(r);
        final daysInStage = WorkflowEngine.getDaysInCurrentStage(r);
        final subStage = r.loanSubStage.trim().toLowerCase();

        // 1. Stalled detection (> 10 days in any active stage or on hold)
        if (daysInStage >= 10 || r.isHold) {
          stalled++;
          stalledList.add(r);
          if (criticalList.length < 10) criticalList.add(r);
        }

        // 2. Payment Action Opportunity
        // If installation started/completed and pending amount > 0
        if ((stage == 'Installation' || stage == 'RTS' || stage == 'Subsidy') && r.pendingAmount > 0) {
          paymentAction++;
          pendingCollection += r.pendingAmount;
          paymentList.add(r);
        }

        // 3. Loan Attention
        if (stage == 'Loan' &&
            (subStage.contains('rejected') ||
                subStage.contains('correction') ||
                subStage.contains('bank') ||
                daysInStage >= 7)) {
          loanAttention++;
          loanList.add(r);
        }

        // 4. Follow-up due today
        if (r.hasActiveFollowup) {
          if (r.followupDate != null) {
            final fStr = r.followupDate!.toIso8601String().split('T')[0];
            if (fStr.compareTo(todayStr) <= 0) {
              followupDue++;
              followupList.add(r);
            }
          } else {
            followupDue++;
            followupList.add(r);
          }
        }
      }

      return OperationalInsights(
        stalledCount: stalled,
        paymentActionCount: paymentAction,
        loanAttentionCount: loanAttention,
        followupDueCount: followupDue,
        totalPendingCollection: pendingCollection,
        criticalRecords: criticalList,
        stalledRecords: stalledList,
        paymentOpportunityRecords: paymentList,
        loanAttentionRecords: loanList,
        followupDueRecords: followupList,
      );
    } catch (_) {
      return OperationalInsights.empty();
    }
  }

  /// Evaluate individual customer intelligence
  static CustomerIntelligence evaluateCustomer(ConsumerRecord record) {
    final stage = WorkflowEngine.getCurrentWorkStage(record);
    final daysInStage = WorkflowEngine.getDaysInCurrentStage(record);
    final nextAction = WorkflowEngine.getNextAction(record);
    final loanSub = record.loanSubStage.trim().toLowerCase();

    // Risk level
    String risk = 'LOW';
    Color riskColor = const Color(0xFF059669); // Green

    if (record.isHold || loanSub.contains('rejected') || daysInStage >= 14) {
      risk = 'HIGH';
      riskColor = const Color(0xFFDC2626); // Red
    } else if (daysInStage >= 7 || record.pendingAmount > 0 && record.installationStatus == 'Installation Completed') {
      risk = 'MEDIUM';
      riskColor = const Color(0xFFD97706); // Amber
    }

    // Suggested payment amount
    double? suggestedAmount;
    if (record.pendingAmount > 0) {
      if (record.paidAmount == 0 && record.totalAmount > 0) {
        // Suggested first installment (approx 40-50%)
        suggestedAmount = (record.totalAmount * 0.5).roundToDouble();
      } else {
        // Remaining pending
        suggestedAmount = record.pendingAmount;
      }
    }

    // Context explanation
    String contextText;
    if (WorkflowEngine.isWorkCompleted(record)) {
      contextText = 'Customer installation & subsidy completed.';
    } else if (record.isHold) {
      contextText = 'Customer is on Hold: ${record.holdReason ?? "Requires attention"}';
    } else if (stage == 'Loan') {
      if (loanSub.contains('rejected')) {
        contextText = 'Loan was rejected. Rectify documents and re-apply.';
      } else if (loanSub.contains('bank')) {
        contextText = 'File is currently at the bank. Follow up on sanction status.';
      } else {
        contextText = '$daysInStage days in Loan processing.';
      }
    } else if (stage == 'Installation') {
      contextText = 'Installation stage active ($daysInStage days). Coordinate materials & field team.';
    } else if (stage == 'Agreement') {
      contextText = 'Agreement pending ($daysInStage days). Obtain customer signature.';
    } else {
      contextText = 'Active stage: $stage ($daysInStage days).';
    }

    return CustomerIntelligence(
      nextBestAction: nextAction,
      actionContext: contextText,
      suggestedPaymentAmount: suggestedAmount,
      riskLevel: risk,
      riskColor: riskColor,
      daysInStage: daysInStage,
    );
  }
}
