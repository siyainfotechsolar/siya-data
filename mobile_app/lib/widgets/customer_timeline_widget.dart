import 'package:flutter/material.dart';
import '../models/activity_log.dart';
import '../services/activity_log_service.dart';

class CustomerTimelineWidget extends StatefulWidget {
  final String? recordId;
  final String consumerNo;
  final String customerName;

  const CustomerTimelineWidget({
    super.key,
    this.recordId,
    required this.consumerNo,
    required this.customerName,
  });

  @override
  State<CustomerTimelineWidget> createState() => _CustomerTimelineWidgetState();
}

class _CustomerTimelineWidgetState extends State<CustomerTimelineWidget> {
  bool _isLoading = true;
  List<ActivityLog> _logs = [];

  @override
  void initState() {
    super.initState();
    _loadTimeline();
  }

  Future<void> _loadTimeline() async {
    setState(() => _isLoading = true);
    final logs = await ActivityLogService.fetchCustomerTimeline(
      recordId: widget.recordId,
      consumerNo: widget.consumerNo,
    );
    if (mounted) {
      setState(() {
        _logs = logs;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (_isLoading) {
      return const Padding(
        padding: EdgeInsets.all(24.0),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_logs.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20.0),
        decoration: BoxDecoration(
          color: isDark ? Colors.grey.shade900 : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            Icon(Icons.history_toggle_off_rounded, size: 36, color: Colors.grey.shade400),
            const SizedBox(height: 8),
            const Text(
              'No Activity History Recorded Yet',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            const SizedBox(height: 4),
            Text(
              'Activities by staff on this customer will appear here chronologically.',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.timeline_rounded, color: theme.colorScheme.primary, size: 20),
            const SizedBox(width: 8),
            Text(
              'Activity History (${_logs.length})',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.refresh, size: 18),
              onPressed: _loadTimeline,
              tooltip: 'Refresh Timeline',
            ),
          ],
        ),
        const SizedBox(height: 8),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _logs.length,
          itemBuilder: (context, index) {
            final log = _logs[index];
            final isFirst = index == 0;
            final isLast = index == _logs.length - 1;

            return _buildTimelineItem(log, isFirst, isLast, theme, isDark);
          },
        ),
      ],
    );
  }

  Widget _buildTimelineItem(
    ActivityLog log,
    bool isFirst,
    bool isLast,
    ThemeData theme,
    bool isDark,
  ) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Timeline indicator line & icon
          SizedBox(
            width: 32,
            child: Column(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: isFirst ? theme.colorScheme.primary : Colors.grey.shade400,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      color: Colors.grey.withValues(alpha: 0.3),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),

          // Content Card
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 14.0),
              child: Card(
                elevation: 0,
                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: BorderSide(
                    color: isFirst
                        ? theme.colorScheme.primary.withValues(alpha: 0.3)
                        : Colors.grey.withValues(alpha: 0.2),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header: Date/Time + Staff Info
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              log.formattedTime,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            log.formattedDate,
                            style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                          ),
                          const Spacer(),
                          // Module Badge
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.blue.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              log.module.toUpperCase(),
                              style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.blue),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),

                      // Staff Name and Action
                      Row(
                        children: [
                          Icon(Icons.person, size: 14, color: Colors.grey.shade600),
                          const SizedBox(width: 4),
                          Text(
                            log.staffName,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '(${log.staffRole})',
                            style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        log.action,
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                      ),

                      // Old Value -> New Value Diff
                      if (log.oldValue != null || log.newValue != null) ...[
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.04),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'Old: ${log.oldValue ?? '-'}',
                                  style: const TextStyle(fontSize: 11, color: Colors.red),
                                ),
                              ),
                              const Icon(Icons.arrow_forward_rounded, size: 12, color: Colors.grey),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  'New: ${log.newValue ?? '-'}',
                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.green),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      // Remarks
                      if (log.remarks != null && log.remarks!.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.notes_rounded, size: 12, color: Colors.grey),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                log.remarks!,
                                style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Colors.grey.shade700),
                              ),
                            ),
                          ],
                        ),
                      ],

                      // Next Action
                      if (log.nextAction != null && log.nextAction!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.next_plan_outlined, size: 12, color: Colors.blue),
                            const SizedBox(width: 4),
                            Text(
                              'Next: ${log.nextAction}',
                              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.blue),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
