import 'dart:async';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import '../models/consumer_record.dart';
import '../services/record_service.dart';
import '../services/realtime_service.dart';
import '../widgets/record_details_dialog.dart';
import '../widgets/record_form_dialog.dart';

class PriorityListScreen extends StatefulWidget {
  final String? initialPriorityFilter;

  const PriorityListScreen({super.key, this.initialPriorityFilter});

  @override
  State<PriorityListScreen> createState() => _PriorityListScreenState();
}

class _PriorityListScreenState extends State<PriorityListScreen> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _verticalScrollController = ScrollController();
  final ScrollController _horizontalScrollController = ScrollController();
  Timer? _debounceTimer;

  bool _isLoading = false;
  List<ConsumerRecord> _records = [];
  int _totalCount = 0;
  int _currentPage = 1;
  final int _pageSize = 15;

  String _selectedPriorityFilter = 'ALL';
  String _selectedAppStatus = 'All';

  StreamSubscription<ConsumerRecordChangeEvent>? _realtimeSub;

  @override
  void initState() {
    super.initState();
    if (widget.initialPriorityFilter != null) {
      _selectedPriorityFilter = widget.initialPriorityFilter!.toUpperCase();
    }
    _loadPriorityRecords();
    _initRealtimeSync();
  }

  void _initRealtimeSync() {
    RealtimeSyncService.initialize();
    _realtimeSub = RealtimeSyncService.recordEvents.listen((_) {
      if (mounted) {
        _loadPriorityRecords();
      }
    });
  }

  @override
  void dispose() {
    _realtimeSub?.cancel();
    _searchController.dispose();
    _verticalScrollController.dispose();
    _horizontalScrollController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 350), () {
      if (mounted) {
        setState(() => _currentPage = 1);
        _loadPriorityRecords();
      }
    });
  }

  Future<void> _loadPriorityRecords() async {
    setState(() => _isLoading = true);

    try {
      final result = await RecordService.fetchPriorityRecords(
        page: _currentPage,
        pageSize: _pageSize,
        priorityFilter: _selectedPriorityFilter,
        applicationStatusFilter: _selectedAppStatus,
        searchQuery: _searchController.text,
      );

      if (mounted) {
        setState(() {
          _records = result.items;
          _totalCount = result.totalCount;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load Priority List: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _openDetailsDialog(ConsumerRecord record) {
    showDialog(
      context: context,
      builder: (_) => RecordDetailsDialog(
        record: record,
        onRecordUpdated: _loadPriorityRecords,
      ),
    );
  }

  void _openEditDialog(ConsumerRecord record) {
    showDialog(
      context: context,
      builder: (_) => RecordFormDialog(
        initialRecord: record,
        onRecordSaved: (_) => _loadPriorityRecords(),
      ),
    );
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
        await RecordService.markCustomerAsComplete(record.id!);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Customer ${record.name} marked as complete and removed from Priority List.'),
              backgroundColor: Colors.green,
            ),
          );
          _loadPriorityRecords();
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
    final totalPages = (_totalCount / _pageSize).ceil();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Title
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.priority_high_rounded, color: Colors.red.shade700, size: 28),
                      const SizedBox(width: 8),
                      Text(
                        'Priority List (Application Days)',
                        style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Active customers requiring action, prioritized by workflow status and application age.',
                    style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
              IconButton.outlined(
                icon: const Icon(Icons.refresh),
                tooltip: 'Refresh Priority List',
                onPressed: _loadPriorityRecords,
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Priority Summary Cards
          Wrap(
            spacing: 14,
            runSpacing: 14,
            children: [
              _buildPrioritySummaryCard(
                title: 'CRITICAL',
                range: '31+ Days',
                color: const Color(0xFFDC2626),
                bgColor: const Color(0xFFFEF2F2),
                borderColor: const Color(0xFFFCA5A5),
                priorityCode: 'CRITICAL',
              ),
              _buildPrioritySummaryCard(
                title: 'HIGH',
                range: '16–30 Days',
                color: const Color(0xFFEA580C),
                bgColor: const Color(0xFFFFF7ED),
                borderColor: const Color(0xFFFDBA74),
                priorityCode: 'HIGH',
              ),
              _buildPrioritySummaryCard(
                title: 'MEDIUM',
                range: '8–15 Days',
                color: const Color(0xFFD97706),
                bgColor: const Color(0xFFFFFBEB),
                borderColor: const Color(0xFFFDE68A),
                priorityCode: 'MEDIUM',
              ),
              _buildPrioritySummaryCard(
                title: 'NORMAL',
                range: '0–7 Days',
                color: const Color(0xFF16A34A),
                bgColor: const Color(0xFFF0FDF4),
                borderColor: const Color(0xFF86EFAC),
                priorityCode: 'NORMAL',
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Search & Filter Bar
          Card(
            elevation: 1,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: TextField(
                      controller: _searchController,
                      onChanged: _onSearchChanged,
                      decoration: InputDecoration(
                        hintText: 'Search Priority List by Name, Consumer No, App ID...',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () {
                                  _searchController.clear();
                                  _loadPriorityRecords();
                                },
                              )
                            : null,
                        border: const OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Priority Level Dropdown Filter
                  DropdownButtonHideUnderline(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade400),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: DropdownButton<String>(
                        value: _selectedPriorityFilter,
                        items: const [
                          DropdownMenuItem(value: 'ALL', child: Text('Priority: All Active')),
                          DropdownMenuItem(value: 'CRITICAL', child: Text('🔴 Critical (31+ Days)')),
                          DropdownMenuItem(value: 'HIGH', child: Text('🟠 High (16-30 Days)')),
                          DropdownMenuItem(value: 'MEDIUM', child: Text('🟡 Medium (8-15 Days)')),
                          DropdownMenuItem(value: 'NORMAL', child: Text('🟢 Normal (0-7 Days)')),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            setState(() {
                              _selectedPriorityFilter = val;
                              _currentPage = 1;
                            });
                            _loadPriorityRecords();
                          }
                        },
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Application Status Dropdown
                  DropdownButtonHideUnderline(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade400),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: DropdownButton<String>(
                        value: _selectedAppStatus,
                        items: const [
                          DropdownMenuItem(value: 'All', child: Text('App Status: All')),
                          DropdownMenuItem(value: 'Submitted', child: Text('Submitted')),
                          DropdownMenuItem(value: 'Under Verification', child: Text('Under Verification')),
                          DropdownMenuItem(value: 'Approved', child: Text('Approved')),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            setState(() {
                              _selectedAppStatus = val;
                              _currentPage = 1;
                            });
                            _loadPriorityRecords();
                          }
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Priority List Table Card
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Column(
              children: [
                _isLoading
                    ? const Padding(
                        padding: EdgeInsets.all(40.0),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    : _records.isEmpty
                        ? Padding(
                            padding: const EdgeInsets.all(40.0),
                            child: Center(
                              child: Text(
                                'No active applications found for selected priority filter.',
                                style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                              ),
                            ),
                          )
                        : ScrollConfiguration(
                            behavior: ScrollConfiguration.of(context).copyWith(
                              dragDevices: {
                                PointerDeviceKind.touch,
                                PointerDeviceKind.mouse,
                                PointerDeviceKind.trackpad,
                                PointerDeviceKind.stylus,
                              },
                            ),
                            child: Scrollbar(
                              controller: _verticalScrollController,
                              thumbVisibility: true,
                              trackVisibility: true,
                              child: SingleChildScrollView(
                                controller: _verticalScrollController,
                                scrollDirection: Axis.vertical,
                                child: Scrollbar(
                                  controller: _horizontalScrollController,
                                  thumbVisibility: true,
                                  trackVisibility: true,
                                  child: SingleChildScrollView(
                                    controller: _horizontalScrollController,
                                    scrollDirection: Axis.horizontal,
                                    child: DataTable(
                                      headingRowColor: WidgetStateProperty.all(
                                        theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                                      ),
                                      columns: const [
                                        DataColumn(label: Text('Priority Level', style: TextStyle(fontWeight: FontWeight.bold))),
                                        DataColumn(label: Text('Customer Name', style: TextStyle(fontWeight: FontWeight.bold))),
                                        DataColumn(label: Text('Consumer No', style: TextStyle(fontWeight: FontWeight.bold))),
                                        DataColumn(label: Text('App ID', style: TextStyle(fontWeight: FontWeight.bold))),
                                        DataColumn(label: Text('App Status', style: TextStyle(fontWeight: FontWeight.bold))),
                                        DataColumn(label: Text('Submit Date', style: TextStyle(fontWeight: FontWeight.bold))),
                                        DataColumn(label: Text('Application Days', style: TextStyle(fontWeight: FontWeight.bold))),
                                        DataColumn(label: Text('Assigned Staff', style: TextStyle(fontWeight: FontWeight.bold))),
                                        DataColumn(label: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold))),
                                      ],
                                      rows: _records.map((r) {
                                        return DataRow(
                                          cells: [
                                            DataCell(_buildPriorityBadge(r)),
                                            DataCell(
                                              InkWell(
                                                onTap: () => _openDetailsDialog(r),
                                                child: Text(r.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                                              ),
                                            ),
                                            DataCell(
                                              InkWell(
                                                onTap: () => _openDetailsDialog(r),
                                                child: Text(
                                                  r.consumerNo,
                                                  style: const TextStyle(
                                                    color: Color(0xFF2563EB),
                                                    decoration: TextDecoration.underline,
                                                  ),
                                                ),
                                              ),
                                            ),
                                            DataCell(Text(r.applicationId ?? '—')),
                                            DataCell(Text(r.applicationStatus)),
                                            DataCell(
                                              Row(
                                                children: [
                                                  Text(
                                                    r.submitDate != null
                                                        ? r.submitDate!.toLocal().toString().split(' ')[0]
                                                        : (r.createdAt != null
                                                            ? r.createdAt!.toLocal().toString().split(' ')[0]
                                                            : '—'),
                                                  ),
                                                  if (r.isSubmitDateFuture) ...[
                                                    const SizedBox(width: 6),
                                                    const Tooltip(
                                                      message: 'Warning: Submit date is in the future!',
                                                      child: Icon(Icons.warning_amber_rounded, color: Colors.amber, size: 16),
                                                    ),
                                                  ],
                                                ],
                                              ),
                                            ),
                                            DataCell(
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: Colors.grey.shade100,
                                                  borderRadius: BorderRadius.circular(4),
                                                ),
                                                child: Text(
                                                  '${r.applicationDays} Days',
                                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                                ),
                                              ),
                                            ),
                                            DataCell(Text(r.installerTeam ?? 'Unassigned')),
                                            DataCell(
                                              Row(
                                                children: [
                                                  IconButton(
                                                    icon: const Icon(Icons.check_circle_outline, size: 20, color: Color(0xFF059669)),
                                                    tooltip: 'Mark as Complete',
                                                    onPressed: () => _confirmMarkAsComplete(r),
                                                  ),
                                                  IconButton(
                                                    icon: const Icon(Icons.timeline_rounded, size: 20, color: Color(0xFFD97706)),
                                                    tooltip: 'Workflow Lifecycle',
                                                    onPressed: () => _openDetailsDialog(r),
                                                  ),
                                                  IconButton(
                                                    icon: const Icon(Icons.visibility_outlined, size: 20),
                                                    tooltip: 'View Record',
                                                    onPressed: () => _openDetailsDialog(r),
                                                  ),
                                                  IconButton(
                                                    icon: const Icon(Icons.edit_outlined, size: 20),
                                                    tooltip: 'Edit Record',
                                                    onPressed: () => _openEditDialog(r),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        );
                                      }).toList(),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),

                // Pagination Footer
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Showing ${(_currentPage - 1) * _pageSize + (_records.isEmpty ? 0 : 1)} - ${(_currentPage - 1) * _pageSize + _records.length} of $_totalCount active applications',
                        style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                      ),
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.chevron_left),
                            onPressed: _currentPage > 1
                                ? () {
                                    setState(() => _currentPage--);
                                    _loadPriorityRecords();
                                  }
                                : null,
                          ),
                          Text('Page $_currentPage of ${totalPages == 0 ? 1 : totalPages}'),
                          IconButton(
                            icon: const Icon(Icons.chevron_right),
                            onPressed: _currentPage < totalPages
                                ? () {
                                    setState(() => _currentPage++);
                                    _loadPriorityRecords();
                                  }
                                : null,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrioritySummaryCard({
    required String title,
    required String range,
    required Color color,
    required Color bgColor,
    required Color borderColor,
    required String priorityCode,
  }) {
    final isSelected = _selectedPriorityFilter == priorityCode;

    return InkWell(
      onTap: () {
        setState(() {
          _selectedPriorityFilter = isSelected ? 'ALL' : priorityCode;
          _currentPage = 1;
        });
        _loadPriorityRecords();
      },
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 210,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? color : borderColor,
            width: isSelected ? 2.5 : 1.0,
          ),
          boxShadow: isSelected
              ? [BoxShadow(color: color.withValues(alpha: 0.2), blurRadius: 8, offset: const Offset(0, 3))]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    title,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                  ),
                ),
                Text(
                  range,
                  style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Filter Queue ➔',
              style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPriorityBadge(ConsumerRecord record) {
    final priority = record.priorityLevel;
    Color bg;
    Color fg;
    String symbol;

    switch (priority) {
      case PriorityLevel.critical:
        bg = const Color(0xFFFEF2F2);
        fg = const Color(0xFFDC2626);
        symbol = '🔴';
        break;
      case PriorityLevel.high:
        bg = const Color(0xFFFFF7ED);
        fg = const Color(0xFFEA580C);
        symbol = '🟠';
        break;
      case PriorityLevel.medium:
        bg = const Color(0xFFFFFBEB);
        fg = const Color(0xFFD97706);
        symbol = '🟡';
        break;
      case PriorityLevel.normal:
      default:
        bg = const Color(0xFFF0FDF4);
        fg = const Color(0xFF16A34A);
        symbol = '🟢';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: fg.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(symbol, style: const TextStyle(fontSize: 10)),
          const SizedBox(width: 6),
          Text(
            priority.label,
            style: TextStyle(color: fg, fontWeight: FontWeight.bold, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
