import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/consumer_record.dart';
import '../services/record_service.dart';
import '../services/realtime_service.dart';
import '../widgets/no_action_reason_dialog.dart';
import 'record_detail_screen.dart';

class ActionCenterScreen extends StatefulWidget {
  final String? initialStageFilter;

  const ActionCenterScreen({super.key, this.initialStageFilter});

  @override
  State<ActionCenterScreen> createState() => _ActionCenterScreenState();
}

class _ActionCenterScreenState extends State<ActionCenterScreen> {
  bool _isLoading = false;
  List<ConsumerRecord> _records = [];
  Map<String, int> _summary = {
    'agreementPending': 0,
    'loanPending': 0,
    'installationPending': 0,
    'rtsPending': 0,
    'subsidyProcessing': 0,
    'completed': 0,
    'totalActive': 0,
  };
  String _selectedStageFilter = 'ALL';
  String _selectedStaffFilter = 'All';

  StreamSubscription<MobileRecordChangeEvent>? _realtimeSub;

  @override
  void initState() {
    super.initState();
    if (widget.initialStageFilter != null && widget.initialStageFilter!.isNotEmpty) {
      _selectedStageFilter = widget.initialStageFilter!;
    }
    _loadActionCenterData();
    _initRealtime();
  }

  void _initRealtime() {
    MobileRealtimeService.initialize();
    _realtimeSub = MobileRealtimeService.recordEvents.listen((_) {
      if (mounted) {
        _loadActionCenterData();
      }
    });
  }

  @override
  void dispose() {
    _realtimeSub?.cancel();
    super.dispose();
  }

  Future<void> _loadActionCenterData() async {
    setState(() => _isLoading = true);

    try {
      final summary = await MobileRecordService.fetchActionCenterSummary(
        staffFilter: _selectedStaffFilter,
      );
      final records = await MobileRecordService.fetchActionCenterRecords(
        stageFilter: _selectedStageFilter,
        assignedStaffFilter: _selectedStaffFilter,
      );

      if (mounted) {
        setState(() {
          _summary = summary;
          _records = records;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load Action Center: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _confirmMarkAsComplete(ConsumerRecord record) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.check_circle_outline, color: Colors.green),
            SizedBox(width: 8),
            Text('Mark as Complete'),
          ],
        ),
        content: Text('Mark customer ${record.name} as complete? They will be removed from active work queues.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFF059669)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Mark as Complete'),
          ),
        ],
      ),
    );

    if (confirmed == true && record.id != null && mounted) {
      try {
        await MobileRecordService.markCustomerAsComplete(record.id!);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Customer ${record.name} marked as complete.'),
              backgroundColor: Colors.green,
            ),
          );
          _loadActionCenterData();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to mark complete: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  Future<void> _confirmMarkAsNoActionRequired(ConsumerRecord record) async {
    final result = await NoActionReasonDialog.show(
      context,
      customerName: record.name,
    );

    if (result != null && record.id != null && mounted) {
      try {
        await MobileRecordService.markCustomerAsNoActionRequired(
          recordId: record.id!,
          reason: result['reason'] ?? 'Hold',
          freeTextDetails: result['details'],
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Customer ${record.name} marked as Hold / No Action Required.'),
              backgroundColor: const Color(0xFFD97706),
            ),
          );
          _loadActionCenterData();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to mark as Hold: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  Future<void> _confirmReopen(ConsumerRecord record) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.refresh, color: Colors.blue),
            SizedBox(width: 8),
            Text('Reopen Customer'),
          ],
        ),
        content: Text('Reopen customer ${record.name} and return to active work queues?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Reopen'),
          ),
        ],
      ),
    );

    if (confirmed == true && record.id != null && mounted) {
      try {
        await MobileRecordService.reopenCustomer(record.id!);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Customer ${record.name} reopened and returned to active workflow.'),
              backgroundColor: Colors.blue,
            ),
          );
          _loadActionCenterData();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to reopen customer: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _loadActionCenterData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Card
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.bolt_rounded, color: theme.colorScheme.primary, size: 26),
                          const SizedBox(width: 8),
                          Text(
                            'ACTION CENTER',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Operational work queues — WHO NEEDS ACTION NOW?',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                      ),
                      const Divider(height: 20),

                      // Stage Grid Counters
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _buildSummaryBox(
                              title: 'Agreement',
                              count: _summary['agreementPending'] ?? 0,
                              color: const Color(0xFF2563EB),
                              filterKey: 'Agreement Pending',
                            ),
                            const SizedBox(width: 8),
                            _buildSummaryBox(
                              title: 'Loan',
                              count: _summary['loanPending'] ?? 0,
                              color: const Color(0xFFD97706),
                              filterKey: 'Loan Pending',
                            ),
                            const SizedBox(width: 8),
                            _buildSummaryBox(
                              title: 'Installation',
                              count: _summary['installationPending'] ?? 0,
                              color: const Color(0xFF0F766E),
                              filterKey: 'Installation Pending',
                            ),
                            const SizedBox(width: 8),
                            _buildSummaryBox(
                              title: 'RTS',
                              count: _summary['rtsPending'] ?? 0,
                              color: const Color(0xFF7C3AED),
                              filterKey: 'RTS Pending',
                            ),
                            const SizedBox(width: 8),
                            _buildSummaryBox(
                              title: 'Subsidy',
                              count: _summary['subsidyProcessing'] ?? 0,
                              color: const Color(0xFF059669),
                              filterKey: 'Subsidy Processing',
                            ),
                            const SizedBox(width: 8),
                            _buildSummaryBox(
                              title: 'Hold',
                              count: _summary['noAction'] ?? 0,
                              color: const Color(0xFFD97706),
                              filterKey: 'Hold',
                            ),
                            const SizedBox(width: 8),
                            _buildSummaryBox(
                              title: 'Completed',
                              count: _summary['completed'] ?? 0,
                              color: Colors.grey.shade700,
                              filterKey: 'Completed',
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Filter Bar
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _selectedStageFilter == 'ALL' ? 'All Active Customers' : _selectedStageFilter,
                    style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  if (_selectedStageFilter != 'ALL')
                    TextButton.icon(
                      onPressed: () {
                        setState(() => _selectedStageFilter = 'ALL');
                        _loadActionCenterData();
                      },
                      icon: const Icon(Icons.clear, size: 16),
                      label: const Text('Clear Filter'),
                    ),
                ],
              ),
              const SizedBox(height: 12),

              // Customer Cards List
              if (_isLoading)
                const Padding(
                  padding: EdgeInsets.all(40.0),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_records.isEmpty)
                Card(
                  elevation: 1,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: const Padding(
                    padding: EdgeInsets.all(32.0),
                    child: Center(
                      child: Text(
                        'No customers require action in this queue.',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                  ),
                )
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _records.length,
                  itemBuilder: (context, index) {
                    final record = _records[index];
                    return _buildMobileCustomerCard(record);
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryBox({
    required String title,
    required int count,
    required Color color,
    required String filterKey,
  }) {
    final isSelected = _selectedStageFilter.toUpperCase() == filterKey.toUpperCase();

    return InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() {
          _selectedStageFilter = isSelected ? 'ALL' : filterKey;
        });
        _loadActionCenterData();
      },
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 100,
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.15) : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? color : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Text(
              '$count',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color),
            ),
            const SizedBox(height: 2),
            Text(
              title,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? color : Colors.black87,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  /// Mobile Customer Card Layout (Section 21)
  Widget _buildMobileCustomerCard(ConsumerRecord record) {
    final theme = Theme.of(context);
    final isCompleted = record.customerWorkState.toUpperCase() == 'COMPLETED' || record.overallStage == 'Completed';
    final isHold = record.isNoActionRequired;

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // CUSTOMER NAME Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    record.name.toUpperCase(),
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
                if (isHold)
                  OutlinedButton.icon(
                    onPressed: () => _confirmReopen(record),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF2563EB),
                      side: const BorderSide(color: Color(0xFF2563EB)),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      visualDensity: VisualDensity.compact,
                    ),
                    icon: const Icon(Icons.refresh, size: 14),
                    label: const Text('Reopen', style: TextStyle(fontSize: 12)),
                  )
                else if (!isCompleted)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.pause_circle_outline, color: Color(0xFFD97706)),
                        tooltip: 'Mark as Hold',
                        onPressed: () => _confirmMarkAsNoActionRequired(record),
                      ),
                      IconButton(
                        icon: const Icon(Icons.check_circle_outline, color: Color(0xFF059669)),
                        tooltip: 'Mark as Complete',
                        onPressed: () => _confirmMarkAsComplete(record),
                      ),
                    ],
                  ),
              ],
            ),
            if (record.consumerNo.isNotEmpty)
              Text(
                'Consumer No: ${record.consumerNo}',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            if (isHold)
              Container(
                margin: const EdgeInsets.only(top: 8, bottom: 4),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFFF59E0B)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.pause_circle_filled, size: 16, color: Color(0xFFD97706)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        (record.noActionReason != null && record.noActionReason!.isNotEmpty)
                            ? 'HOLD: ${record.noActionReason}'
                            : 'WORK STATE: HOLD (NO ACTION REQUIRED)',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF92400E),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            const Divider(height: 16),

            // Current Stage
            _buildDetailRow('Current Stage:', record.overallStage, isBold: true),
            const SizedBox(height: 6),

            // Status (No unnecessary progress circles)
            _buildDetailRow('Status:', record.currentStatus),
            const SizedBox(height: 6),

            // Action Required
            _buildDetailRow('Action Required:', record.actionRequired, isHighlight: !isCompleted),
            const SizedBox(height: 6),

            // Next Action
            _buildDetailRow('Next Action:', record.nextAction, isBold: !isCompleted),
            const SizedBox(height: 6),

            // Days in Current Stage
            _buildDetailRow('Days in Current Stage:', '${record.daysInCurrentStage} Days'),
            const SizedBox(height: 6),

            // Application Days
            _buildDetailRow('Application Days:', '${record.applicationDays} Days'),

            const SizedBox(height: 14),

            // [Open Customer] Action Button
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => RecordDetailScreen(record: record),
                    ),
                  );
                  _loadActionCenterData();
                },
                icon: const Icon(Icons.open_in_new, size: 16),
                label: const Text('Open Customer'),
                style: OutlinedButton.styleFrom(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {bool isBold = false, bool isHighlight = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 13, color: Colors.black54),
        ),
        Flexible(
          child: Container(
            padding: isHighlight ? const EdgeInsets.symmetric(horizontal: 8, vertical: 2) : EdgeInsets.zero,
            decoration: isHighlight
                ? BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: const Color(0xFF93C5FD)),
                  )
                : null,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: (isBold || isHighlight) ? FontWeight.bold : FontWeight.w500,
                color: isHighlight ? const Color(0xFF1E40AF) : Colors.black87,
              ),
              textAlign: TextAlign.end,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ],
    );
  }
}

/// Backward compatibility alias for PriorityScreen
typedef PriorityScreen = ActionCenterScreen;
