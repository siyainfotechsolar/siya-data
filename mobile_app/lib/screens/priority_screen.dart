import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/consumer_record.dart';
import '../services/record_service.dart';
import '../services/realtime_service.dart';
import 'record_detail_screen.dart';

class PriorityScreen extends StatefulWidget {
  const PriorityScreen({super.key});

  @override
  State<PriorityScreen> createState() => _PriorityScreenState();
}

class _PriorityScreenState extends State<PriorityScreen> {
  bool _isLoading = false;
  List<ConsumerRecord> _records = [];
  Map<String, int> _summary = {'critical': 0, 'high': 0, 'medium': 0, 'normal': 0, 'total': 0};
  String _selectedPriorityFilter = 'ALL';

  StreamSubscription<MobileRecordChangeEvent>? _realtimeSub;

  @override
  void initState() {
    super.initState();
    _loadPriorityData();
    _initRealtime();
  }

  void _initRealtime() {
    MobileRealtimeService.initialize();
    _realtimeSub = MobileRealtimeService.recordEvents.listen((_) {
      if (mounted) {
        _loadPriorityData();
      }
    });
  }

  @override
  void dispose() {
    _realtimeSub?.cancel();
    super.dispose();
  }

  Future<void> _loadPriorityData() async {
    setState(() => _isLoading = true);

    try {
      final summary = await MobileRecordService.fetchPrioritySummary();
      final records = await MobileRecordService.fetchPriorityRecords(
        priorityFilter: _selectedPriorityFilter,
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
          SnackBar(content: Text('Failed to load Priority List: $e'), backgroundColor: Colors.red),
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
        content: const Text('Mark this customer as complete?'),
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
              content: Text('Customer ${record.name} marked as complete and removed from Priority List.'),
              backgroundColor: Colors.green,
            ),
          );
          _loadPriorityData();
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _loadPriorityData,
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
                          Icon(Icons.priority_high_rounded, color: Colors.red.shade700, size: 24),
                          const SizedBox(width: 8),
                          Text(
                            'Application Priority',
                            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Active customers requiring action, prioritized by workflow status and application age.',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                      ),
                      const Divider(height: 20),

                      // 4 Summary Grid Counters
                      Row(
                        children: [
                          Expanded(
                            child: _buildSummaryBox(
                              symbol: '🔴',
                              title: 'Critical',
                              count: _summary['critical'] ?? 0,
                              color: const Color(0xFFDC2626),
                              filterKey: 'CRITICAL',
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildSummaryBox(
                              symbol: '🟠',
                              title: 'High',
                              count: _summary['high'] ?? 0,
                              color: const Color(0xFFEA580C),
                              filterKey: 'HIGH',
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildSummaryBox(
                              symbol: '🟡',
                              title: 'Medium',
                              count: _summary['medium'] ?? 0,
                              color: const Color(0xFFD97706),
                              filterKey: 'MEDIUM',
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildSummaryBox(
                              symbol: '🟢',
                              title: 'Normal',
                              count: _summary['normal'] ?? 0,
                              color: const Color(0xFF16A34A),
                              filterKey: 'NORMAL',
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Filter Chips Row
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    FilterChip(
                      selected: _selectedPriorityFilter == 'ALL',
                      label: const Text('All Active'),
                      onSelected: (_) {
                        setState(() => _selectedPriorityFilter = 'ALL');
                        _loadPriorityData();
                      },
                    ),
                    const SizedBox(width: 8),
                    FilterChip(
                      selected: _selectedPriorityFilter == 'CRITICAL',
                      label: const Text('🔴 Critical (31+ Days)'),
                      selectedColor: const Color(0xFFFEF2F2),
                      onSelected: (_) {
                        setState(() => _selectedPriorityFilter = 'CRITICAL');
                        _loadPriorityData();
                      },
                    ),
                    const SizedBox(width: 8),
                    FilterChip(
                      selected: _selectedPriorityFilter == 'HIGH',
                      label: const Text('🟠 High (16–30 Days)'),
                      selectedColor: const Color(0xFFFFF7ED),
                      onSelected: (_) {
                        setState(() => _selectedPriorityFilter = 'HIGH');
                        _loadPriorityData();
                      },
                    ),
                    const SizedBox(width: 8),
                    FilterChip(
                      selected: _selectedPriorityFilter == 'MEDIUM',
                      label: const Text('🟡 Medium (8–15 Days)'),
                      selectedColor: const Color(0xFFFFFBEB),
                      onSelected: (_) {
                        setState(() => _selectedPriorityFilter = 'MEDIUM');
                        _loadPriorityData();
                      },
                    ),
                    const SizedBox(width: 8),
                    FilterChip(
                      selected: _selectedPriorityFilter == 'NORMAL',
                      label: const Text('🟢 Normal (0–7 Days)'),
                      selectedColor: const Color(0xFFF0FDF4),
                      onSelected: (_) {
                        setState(() => _selectedPriorityFilter = 'NORMAL');
                        _loadPriorityData();
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // Record Cards List
              _isLoading
                  ? const Padding(
                      padding: EdgeInsets.all(40.0),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  : _records.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.all(32.0),
                          child: Center(
                            child: Text(
                              'No active applications in this priority category.',
                              style: TextStyle(color: Colors.grey.shade600),
                            ),
                          ),
                        )
                      : ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _records.length,
                          itemBuilder: (ctx, i) {
                            final r = _records[i];
                            return _buildPriorityRecordCard(r);
                          },
                        ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryBox({
    required String symbol,
    required String title,
    required int count,
    required Color color,
    required String filterKey,
  }) {
    final isSelected = _selectedPriorityFilter == filterKey;

    return InkWell(
      onTap: () {
        setState(() {
          _selectedPriorityFilter = isSelected ? 'ALL' : filterKey;
        });
        _loadPriorityData();
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.15) : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? color : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Text(symbol, style: const TextStyle(fontSize: 14)),
            const SizedBox(height: 2),
            Text(
              '$count',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color),
            ),
            Text(
              title,
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.grey.shade800),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPriorityRecordCard(ConsumerRecord r) {
    final priority = r.priorityLevel;
    Color color;
    Color bgColor;
    String symbol;

    switch (priority) {
      case PriorityLevel.critical:
        color = const Color(0xFFDC2626);
        bgColor = const Color(0xFFFEF2F2);
        symbol = '🔴';
        break;
      case PriorityLevel.high:
        color = const Color(0xFFEA580C);
        bgColor = const Color(0xFFFFF7ED);
        symbol = '🟠';
        break;
      case PriorityLevel.medium:
        color = const Color(0xFFD97706);
        bgColor = const Color(0xFFFFFBEB);
        symbol = '🟡';
        break;
      case PriorityLevel.normal:
      default:
        color = const Color(0xFF16A34A);
        bgColor = const Color(0xFFF0FDF4);
        symbol = '🟢';
        break;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () async {
          final updated = await Navigator.of(context).push<bool>(
            MaterialPageRoute(
              builder: (_) => RecordDetailScreen(record: r),
            ),
          );
          if (updated == true) {
            _loadPriorityData();
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(14.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Priority Badge Symbol Box
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: color.withValues(alpha: 0.3)),
                ),
                child: Center(
                  child: Text(symbol, style: const TextStyle(fontSize: 20)),
                ),
              ),
              const SizedBox(width: 12),

              // Customer Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      r.name,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    const SizedBox(height: 2),
                    InkWell(
                      onTap: () {
                        Clipboard.setData(ClipboardData(text: r.consumerNo));
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Consumer No. ${r.consumerNo} copied to clipboard'),
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      },
                      borderRadius: BorderRadius.circular(4),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2.0),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Consumer No: ${r.consumerNo}',
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade700, fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              Icons.copy_rounded,
                              size: 13,
                              color: Colors.grey.shade700,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'Stage: ${r.overallStage}',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blue.shade800),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.amber.shade50,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'Action: ${r.actionRequired}',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.amber.shade900),
                          ),
                        ),
                        if (r.isSubmitDateFuture) ...[
                          const Tooltip(
                            message: 'Future Submit Date',
                            child: Icon(Icons.warning_amber_rounded, color: Colors.amber, size: 14),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),

              // Application Days Highlight Pill & Mark Complete Action
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${r.applicationDays} Days',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  ),
                  const SizedBox(height: 2),
                  IconButton(
                    icon: const Icon(Icons.check_circle_outline, size: 22, color: Color(0xFF059669)),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    tooltip: 'Mark as Complete',
                    onPressed: () => _confirmMarkAsComplete(r),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
