import 'dart:async';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import '../models/consumer_record.dart';
import '../services/record_service.dart';
import '../services/realtime_service.dart';
import '../widgets/record_details_dialog.dart';
import '../widgets/record_form_dialog.dart';

class ActionCenterScreen extends StatefulWidget {
  final String? initialStageFilter;

  const ActionCenterScreen({super.key, this.initialStageFilter});

  @override
  State<ActionCenterScreen> createState() => _ActionCenterScreenState();
}

class _ActionCenterScreenState extends State<ActionCenterScreen> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _verticalScrollController = ScrollController();
  final ScrollController _horizontalScrollController = ScrollController();
  Timer? _debounceTimer;

  bool _isLoading = false;
  List<ConsumerRecord> _records = [];
  int _totalCount = 0;
  int _currentPage = 1;
  final int _pageSize = 15;

  String _selectedStageFilter = 'ALL';
  String _selectedStaffFilter = 'All';

  StreamSubscription<ConsumerRecordChangeEvent>? _realtimeSub;

  @override
  void initState() {
    super.initState();
    if (widget.initialStageFilter != null && widget.initialStageFilter!.isNotEmpty) {
      _selectedStageFilter = widget.initialStageFilter!;
    }
    _loadActionCenterRecords();
    _initRealtimeSync();
  }

  void _initRealtimeSync() {
    RealtimeSyncService.initialize();
    _realtimeSub = RealtimeSyncService.recordEvents.listen((_) {
      if (mounted) {
        _loadActionCenterRecords();
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
        _loadActionCenterRecords();
      }
    });
  }

  Future<void> _loadActionCenterRecords() async {
    setState(() => _isLoading = true);

    try {
      final result = await RecordService.fetchActionCenterRecords(
        page: _currentPage,
        pageSize: _pageSize,
        stageFilter: _selectedStageFilter,
        assignedStaffFilter: _selectedStaffFilter,
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
            content: Text('Failed to load Action Center: $e'),
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
        onRecordUpdated: _loadActionCenterRecords,
      ),
    );
  }

  void _openEditDialog(ConsumerRecord record) {
    showDialog(
      context: context,
      builder: (_) => RecordFormDialog(
        initialRecord: record,
        onRecordSaved: (_) => _loadActionCenterRecords(),
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
        content: Text('Mark customer ${record.name} as complete? They will be moved immediately to Completed.'),
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
              content: Text('Customer ${record.name} marked as complete and moved to Completed.'),
              backgroundColor: Colors.green,
            ),
          );
          _loadActionCenterRecords();
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

  Future<void> _confirmReopen(ConsumerRecord record) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.replay_rounded, color: Colors.blue),
            SizedBox(width: 8),
            Text('Reopen Customer'),
          ],
        ),
        content: Text('Reopen customer ${record.name}? Workflow Engine will recalculate current stage and return customer to Action Center.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFF2563EB)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Reopen Customer'),
          ),
        ],
      ),
    );

    if (confirmed == true && record.id != null && mounted) {
      try {
        await RecordService.reopenCustomer(record.id!);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Customer ${record.name} reopened successfully.'),
              backgroundColor: Colors.blue,
            ),
          );
          _loadActionCenterRecords();
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
                      Icon(Icons.bolt_rounded, color: theme.colorScheme.primary, size: 30),
                      const SizedBox(width: 8),
                      Text(
                        'ACTION CENTER',
                        style: theme.textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Intelligent operational queue — WHO NEEDS ACTION NOW?',
                    style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 13),
                  ),
                ],
              ),
              IconButton.outlined(
                icon: const Icon(Icons.refresh),
                tooltip: 'Refresh Action Center',
                onPressed: _loadActionCenterRecords,
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Stage Summary Filter Cards
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _buildStageFilterCard(
                title: 'Agreement Pending',
                stageCode: 'Agreement Pending',
                color: const Color(0xFF2563EB),
                icon: Icons.history_edu_rounded,
              ),
              _buildStageFilterCard(
                title: 'Loan Pending',
                stageCode: 'Loan Pending',
                color: const Color(0xFFD97706),
                icon: Icons.account_balance_rounded,
              ),
              _buildStageFilterCard(
                title: 'Installation Pending',
                stageCode: 'Installation Pending',
                color: const Color(0xFF0F766E),
                icon: Icons.build_circle_outlined,
              ),
              _buildStageFilterCard(
                title: 'RTS Pending',
                stageCode: 'RTS Pending',
                color: const Color(0xFF7C3AED),
                icon: Icons.electric_meter_rounded,
              ),
              _buildStageFilterCard(
                title: 'Subsidy Processing',
                stageCode: 'Subsidy Processing',
                color: const Color(0xFF059669),
                icon: Icons.currency_rupee_rounded,
              ),
              _buildStageFilterCard(
                title: 'Completed',
                stageCode: 'Completed',
                color: Colors.grey.shade700,
                icon: Icons.check_circle_rounded,
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
                        hintText: 'Search Action Center by Customer Name, Consumer No, App ID, Mobile...',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () {
                                  _searchController.clear();
                                  _loadActionCenterRecords();
                                },
                              )
                            : null,
                        border: const OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Stage Dropdown Filter
                  DropdownButtonHideUnderline(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade400),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: DropdownButton<String>(
                        value: _selectedStageFilter,
                        items: const [
                          DropdownMenuItem(value: 'ALL', child: Text('Work Stage: All Stages')),
                          DropdownMenuItem(value: 'Agreement Pending', child: Text('Agreement Pending')),
                          DropdownMenuItem(value: 'Loan Pending', child: Text('Loan Pending')),
                          DropdownMenuItem(value: 'Installation Pending', child: Text('Installation Pending')),
                          DropdownMenuItem(value: 'RTS Pending', child: Text('RTS Pending')),
                          DropdownMenuItem(value: 'Subsidy Processing', child: Text('Subsidy Processing')),
                          DropdownMenuItem(value: 'Completed', child: Text('Completed')),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            setState(() {
                              _selectedStageFilter = val;
                              _currentPage = 1;
                            });
                            _loadActionCenterRecords();
                          }
                        },
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Assigned Staff Filter
                  DropdownButtonHideUnderline(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade400),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: DropdownButton<String>(
                        value: _selectedStaffFilter,
                        items: const [
                          DropdownMenuItem(value: 'All', child: Text('Staff: All Staff')),
                          DropdownMenuItem(value: 'Rushikesh', child: Text('Rushikesh')),
                          DropdownMenuItem(value: 'Rihan', child: Text('Rihan')),
                          DropdownMenuItem(value: 'Vishal', child: Text('Vishal')),
                          DropdownMenuItem(value: 'Samadhan', child: Text('Samadhan')),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            setState(() {
                              _selectedStaffFilter = val;
                              _currentPage = 1;
                            });
                            _loadActionCenterRecords();
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

          // Action Center Customer Table Card
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
                                'No customers requiring action for selected stage/filter.',
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
                                        DataColumn(label: Text('Customer Name', style: TextStyle(fontWeight: FontWeight.bold))),
                                        DataColumn(label: Text('Consumer No', style: TextStyle(fontWeight: FontWeight.bold))),
                                        DataColumn(label: Text('Application Date', style: TextStyle(fontWeight: FontWeight.bold))),
                                        DataColumn(label: Text('Application Days', style: TextStyle(fontWeight: FontWeight.bold))),
                                        DataColumn(label: Text('Current Work Stage', style: TextStyle(fontWeight: FontWeight.bold))),
                                        DataColumn(label: Text('Current Status', style: TextStyle(fontWeight: FontWeight.bold))),
                                        DataColumn(label: Text('Action Required', style: TextStyle(fontWeight: FontWeight.bold))),
                                        DataColumn(label: Text('Next Action', style: TextStyle(fontWeight: FontWeight.bold))),
                                        DataColumn(label: Text('Days in Stage', style: TextStyle(fontWeight: FontWeight.bold))),
                                        DataColumn(label: Text('Assigned Staff', style: TextStyle(fontWeight: FontWeight.bold))),
                                        DataColumn(label: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold))),
                                      ],
                                      rows: _records.map((r) {
                                        final isCompleted = r.customerWorkState.toUpperCase() == 'COMPLETED' || r.overallStage == 'Completed';

                                        return DataRow(
                                          cells: [
                                            // Customer Name
                                            DataCell(
                                              InkWell(
                                                onTap: () => _openDetailsDialog(r),
                                                child: Text(
                                                  r.name,
                                                  style: const TextStyle(fontWeight: FontWeight.w600),
                                                ),
                                              ),
                                            ),
                                            // Consumer No
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
                                            // Application Date
                                            DataCell(
                                              Text(
                                                r.applicationDate != null
                                                    ? r.applicationDate!.toLocal().toString().split(' ')[0]
                                                    : (r.submitDate != null
                                                        ? r.submitDate!.toLocal().toString().split(' ')[0]
                                                        : (r.createdAt != null
                                                            ? r.createdAt!.toLocal().toString().split(' ')[0]
                                                            : '—')),
                                              ),
                                            ),
                                            // Application Days (Informational)
                                            DataCell(
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: Colors.grey.shade100,
                                                  borderRadius: BorderRadius.circular(4),
                                                ),
                                                child: Text(
                                                  '${r.applicationDays} Days',
                                                  style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 12),
                                                ),
                                              ),
                                            ),
                                            // Current Work Stage
                                            DataCell(_buildStageBadge(r.overallStage)),
                                            // Current Status
                                            DataCell(Text(r.currentStatus, style: const TextStyle(fontSize: 13))),
                                            // Action Required
                                            DataCell(
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                                decoration: BoxDecoration(
                                                  color: isCompleted ? Colors.grey.shade200 : const Color(0xFFEFF6FF),
                                                  borderRadius: BorderRadius.circular(4),
                                                  border: Border.all(
                                                    color: isCompleted ? Colors.grey.shade400 : const Color(0xFF93C5FD),
                                                  ),
                                                ),
                                                child: Text(
                                                  r.actionRequired,
                                                  style: TextStyle(
                                                    color: isCompleted ? Colors.grey.shade700 : const Color(0xFF1E40AF),
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 12,
                                                  ),
                                                ),
                                              ),
                                            ),
                                            // Next Action
                                            DataCell(
                                              Text(
                                                r.nextAction,
                                                style: TextStyle(
                                                  fontWeight: isCompleted ? FontWeight.normal : FontWeight.w600,
                                                  color: isCompleted ? Colors.grey.shade600 : Colors.black87,
                                                ),
                                              ),
                                            ),
                                            // Days in Current Stage
                                            DataCell(
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: r.daysInCurrentStage >= 15
                                                      ? const Color(0xFFFEF2F2)
                                                      : (r.daysInCurrentStage >= 8 ? const Color(0xFFFFFBEB) : const Color(0xFFF0FDF4)),
                                                  borderRadius: BorderRadius.circular(4),
                                                ),
                                                child: Text(
                                                  '${r.daysInCurrentStage} Days',
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 12,
                                                    color: r.daysInCurrentStage >= 15
                                                        ? const Color(0xFFDC2626)
                                                        : (r.daysInCurrentStage >= 8 ? const Color(0xFFD97706) : const Color(0xFF16A34A)),
                                                  ),
                                                ),
                                              ),
                                            ),
                                            // Assigned Staff
                                            DataCell(Text(r.assignedStaff ?? r.installerTeam ?? 'Unassigned')),
                                            // Actions
                                            DataCell(
                                              Row(
                                                children: [
                                                  if (!isCompleted)
                                                    IconButton(
                                                      icon: const Icon(Icons.check_circle_outline, size: 20, color: Color(0xFF059669)),
                                                      tooltip: 'Mark as Complete',
                                                      onPressed: () => _confirmMarkAsComplete(r),
                                                    )
                                                  else
                                                    IconButton(
                                                      icon: const Icon(Icons.replay_rounded, size: 20, color: Color(0xFF2563EB)),
                                                      tooltip: 'Reopen Customer',
                                                      onPressed: () => _confirmReopen(r),
                                                    ),
                                                  IconButton(
                                                    icon: const Icon(Icons.visibility_outlined, size: 20),
                                                    tooltip: 'View Customer Details',
                                                    onPressed: () => _openDetailsDialog(r),
                                                  ),
                                                  IconButton(
                                                    icon: const Icon(Icons.edit_outlined, size: 20),
                                                    tooltip: 'Edit Customer',
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
                        'Showing ${(_currentPage - 1) * _pageSize + (_records.isEmpty ? 0 : 1)} - ${(_currentPage - 1) * _pageSize + _records.length} of $_totalCount customers',
                        style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                      ),
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.chevron_left),
                            onPressed: _currentPage > 1
                                ? () {
                                    setState(() => _currentPage--);
                                    _loadActionCenterRecords();
                                  }
                                : null,
                          ),
                          Text('Page $_currentPage of ${totalPages == 0 ? 1 : totalPages}'),
                          IconButton(
                            icon: const Icon(Icons.chevron_right),
                            onPressed: _currentPage < totalPages
                                ? () {
                                    setState(() => _currentPage++);
                                    _loadActionCenterRecords();
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

  Widget _buildStageFilterCard({
    required String title,
    required String stageCode,
    required Color color,
    required IconData icon,
  }) {
    final isSelected = _selectedStageFilter.toUpperCase() == stageCode.toUpperCase();

    return InkWell(
      onTap: () {
        setState(() {
          _selectedStageFilter = isSelected ? 'ALL' : stageCode;
          _currentPage = 1;
        });
        _loadActionCenterRecords();
      },
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 175,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.1) : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? color : Colors.grey.shade300,
            width: isSelected ? 2.5 : 1.0,
          ),
          boxShadow: isSelected
              ? [BoxShadow(color: color.withValues(alpha: 0.15), blurRadius: 6, offset: const Offset(0, 2))]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              isSelected ? 'Selected ✓' : 'Filter Section ➔',
              style: TextStyle(
                color: isSelected ? color : Colors.grey.shade600,
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStageBadge(String stage) {
    Color bg;
    Color fg;

    switch (stage) {
      case 'Agreement':
        bg = const Color(0xFFEFF6FF);
        fg = const Color(0xFF2563EB);
        break;
      case 'Loan':
        bg = const Color(0xFFFFFBEB);
        fg = const Color(0xFFD97706);
        break;
      case 'Installation':
        bg = const Color(0xFFCCFBF1);
        fg = const Color(0xFF0F766E);
        break;
      case 'RTS':
        bg = const Color(0xFFF3E8FF);
        fg = const Color(0xFF7C3AED);
        break;
      case 'Subsidy':
        bg = const Color(0xFFECFDF5);
        fg = const Color(0xFF059669);
        break;
      case 'Completed':
      default:
        bg = const Color(0xFFF3F4F6);
        fg = const Color(0xFF4B5563);
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: fg.withValues(alpha: 0.3)),
      ),
      child: Text(
        stage,
        style: TextStyle(color: fg, fontWeight: FontWeight.bold, fontSize: 12),
      ),
    );
  }
}

/// Backward compatibility alias for PriorityListScreen
typedef PriorityListScreen = ActionCenterScreen;
