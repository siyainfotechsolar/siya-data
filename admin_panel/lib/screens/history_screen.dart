import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/import_log.dart';
import '../models/activity_log.dart';
import '../services/audit_service.dart';
import '../services/activity_log_service.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Tab 0: Who Worked Log State
  bool _isLoadingActivities = false;
  List<ActivityLog> _activityLogs = [];
  int _activityTotalCount = 0;
  int _activityPage = 1;
  final int _activityPageSize = 15;
  String _selectedDateRange = 'Today'; // 'Today', 'This Week', 'This Month', 'All Time'
  String _selectedStaff = 'All';
  String _selectedModule = 'All';
  String _selectedAction = 'All';
  final TextEditingController _activitySearchController = TextEditingController();
  List<StaffWorkMetric> _todayMetrics = [];
  bool _isLoadingMetrics = false;
  final Set<String> _knownStaffNames = {'All'};
  Timer? _activityDebounce;

  // Tab 1: Import Logs State
  bool _isLoadingImports = false;
  List<ImportLog> _importLogs = [];
  int _importTotalCount = 0;
  int _importPage = 1;
  final int _importPageSize = 12;

  // Tab 2: Audit Logs State
  bool _isLoadingAudits = false;
  List<AuditLogEntry> _auditLogs = [];
  int _auditTotalCount = 0;
  int _auditPage = 1;
  final int _auditPageSize = 15;
  final TextEditingController _auditSearchController = TextEditingController();
  String _selectedAuditAction = 'All';
  Timer? _auditDebounce;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        if (_tabController.index == 0) {
          _loadActivityLogs();
          _loadWhoWorkedTodayMetrics();
        } else if (_tabController.index == 1) {
          _loadImportLogs();
        } else {
          _loadAuditLogs();
        }
      }
    });

    _loadActivityLogs();
    _loadWhoWorkedTodayMetrics();
    _loadImportLogs();
    _loadAuditLogs();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _activitySearchController.dispose();
    _auditSearchController.dispose();
    _activityDebounce?.cancel();
    _auditDebounce?.cancel();
    super.dispose();
  }

  // --- Who Worked Log Methods ---
  Future<void> _loadWhoWorkedTodayMetrics() async {
    setState(() => _isLoadingMetrics = true);
    final metrics = await ActivityLogService.fetchWhoWorkedTodaySummary();
    if (mounted) {
      setState(() {
        _todayMetrics = metrics;
        for (final m in metrics) {
          _knownStaffNames.add(m.staffName);
        }
        _isLoadingMetrics = false;
      });
    }
  }

  Future<void> _loadActivityLogs() async {
    setState(() => _isLoadingActivities = true);

    DateTime? startDate;
    DateTime? endDate;
    final now = DateTime.now();

    if (_selectedDateRange == 'Today') {
      startDate = DateTime(now.year, now.month, now.day);
      endDate = DateTime(now.year, now.month, now.day, 23, 59, 59);
    } else if (_selectedDateRange == 'This Week') {
      startDate = DateTime(now.year, now.month, now.day).subtract(Duration(days: now.weekday - 1));
      endDate = DateTime(now.year, now.month, now.day, 23, 59, 59);
    } else if (_selectedDateRange == 'This Month') {
      startDate = DateTime(now.year, now.month, 1);
      endDate = DateTime(now.year, now.month, now.day, 23, 59, 59);
    }

    final result = await ActivityLogService.fetchActivityLogs(
      page: _activityPage,
      pageSize: _activityPageSize,
      startDate: startDate,
      endDate: endDate,
      staffFilter: _selectedStaff == 'All' ? null : _selectedStaff,
      moduleFilter: _selectedModule == 'All' ? null : _selectedModule,
      actionFilter: _selectedAction == 'All' ? null : _selectedAction,
      customerQuery: _activitySearchController.text,
    );

    if (mounted) {
      setState(() {
        _activityLogs = result.items;
        _activityTotalCount = result.totalCount;
        for (final log in result.items) {
          _knownStaffNames.add(log.staffName);
        }
        _isLoadingActivities = false;
      });
    }
  }

  void _onActivitySearchChanged(String query) {
    _activityDebounce?.cancel();
    _activityDebounce = Timer(const Duration(milliseconds: 350), () {
      setState(() => _activityPage = 1);
      _loadActivityLogs();
    });
  }

  Future<void> _handleExportActivityExcel() async {
    DateTime? startDate;
    DateTime? endDate;
    final now = DateTime.now();

    if (_selectedDateRange == 'Today') {
      startDate = DateTime(now.year, now.month, now.day);
      endDate = DateTime(now.year, now.month, now.day, 23, 59, 59);
    } else if (_selectedDateRange == 'This Week') {
      startDate = DateTime(now.year, now.month, now.day).subtract(Duration(days: now.weekday - 1));
      endDate = DateTime(now.year, now.month, now.day, 23, 59, 59);
    } else if (_selectedDateRange == 'This Month') {
      startDate = DateTime(now.year, now.month, 1);
      endDate = DateTime(now.year, now.month, now.day, 23, 59, 59);
    }

    final exportData = await ActivityLogService.fetchActivityLogs(
      page: 1,
      pageSize: 500,
      startDate: startDate,
      endDate: endDate,
      staffFilter: _selectedStaff == 'All' ? null : _selectedStaff,
      moduleFilter: _selectedModule == 'All' ? null : _selectedModule,
      actionFilter: _selectedAction == 'All' ? null : _selectedAction,
      customerQuery: _activitySearchController.text,
    );

    if (exportData.items.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No activity logs found for current filter')),
        );
      }
      return;
    }

    final csvString = ActivityLogService.exportActivityToCsv(exportData.items);
    final uri = Uri.parse('data:text/csv;charset=utf-8,${Uri.encodeComponent(csvString)}');

    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Exported ${exportData.items.length} activity log records successfully!'),
            backgroundColor: const Color(0xFF059669),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export triggered: ${exportData.items.length} records ready')),
        );
      }
    }
  }

  // --- Import Logs Methods ---
  Future<void> _loadImportLogs() async {
    setState(() => _isLoadingImports = true);
    final result = await AuditService.fetchImportLogs(
      page: _importPage,
      pageSize: _importPageSize,
    );
    if (mounted) {
      setState(() {
        _importLogs = result.items;
        _importTotalCount = result.totalCount;
        _isLoadingImports = false;
      });
    }
  }

  // --- Audit Logs Methods ---
  Future<void> _loadAuditLogs() async {
    setState(() => _isLoadingAudits = true);
    final result = await AuditService.fetchAuditLogs(
      page: _auditPage,
      pageSize: _auditPageSize,
      searchQuery: _auditSearchController.text,
      actionFilter: _selectedAuditAction,
    );
    if (mounted) {
      setState(() {
        _auditLogs = result.items;
        _auditTotalCount = result.totalCount;
        _isLoadingAudits = false;
      });
    }
  }

  void _onAuditSearchChanged(String query) {
    _auditDebounce?.cancel();
    _auditDebounce = Timer(const Duration(milliseconds: 350), () {
      setState(() => _auditPage = 1);
      _loadAuditLogs();
    });
  }

  void _showBatchDetails(ImportLog log) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFD97706).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.description_outlined, color: Color(0xFFD97706)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(log.fileName, style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold)),
                  Text('Imported on ${log.createdAt.toLocal().toString().split('.')[0]}', style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B))),
                ],
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 480,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Divider(),
              const SizedBox(height: 12),
              _buildDetailRow('Total Records Processed', log.totalRows.toString()),
              _buildDetailRow('New Records Inserted', log.insertedCount.toString(), color: const Color(0xFF059669)),
              _buildDetailRow('Existing Records Updated', log.updatedCount.toString(), color: const Color(0xFFD97706)),
              _buildDetailRow('Records Skipped', log.skippedCount.toString(), color: const Color(0xFF64748B)),
              if (log.failedCount > 0)
                _buildDetailRow('Failed Records', log.failedCount.toString(), color: Colors.red),
              const SizedBox(height: 16),
              if (log.errors.isNotEmpty) ...[
                Text('Error Breakdown', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Container(
                  constraints: const BoxConstraints(maxHeight: 140),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.withValues(alpha: 0.2)),
                  ),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: log.errors.length,
                    itemBuilder: (context, i) => Text(
                      '• ${log.errors[i]}',
                      style: GoogleFonts.inter(fontSize: 12, color: Colors.red.shade900),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF475569))),
          Text(
            value,
            style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: color ?? const Color(0xFF0F172A)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Activity & History Center',
                    style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Centralized Who Worked Log, customer journey history, and immutable operational audits',
                    style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
              IconButton.outlined(
                icon: const Icon(Icons.refresh),
                tooltip: 'Refresh',
                onPressed: () {
                  if (_tabController.index == 0) {
                    _loadActivityLogs();
                    _loadWhoWorkedTodayMetrics();
                  } else if (_tabController.index == 1) {
                    _loadImportLogs();
                  } else {
                    _loadAuditLogs();
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Tabs
          TabBar(
            controller: _tabController,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            labelColor: theme.colorScheme.primary,
            unselectedLabelColor: const Color(0xFF64748B),
            indicatorColor: theme.colorScheme.primary,
            tabs: const [
              Tab(
                icon: Icon(Icons.badge_rounded, size: 18),
                child: Text('Who Worked Log (Activity)'),
              ),
              Tab(
                icon: Icon(Icons.history_rounded, size: 18),
                child: Text('Import Batches'),
              ),
              Tab(
                icon: Icon(Icons.shield_outlined, size: 18),
                child: Text('Security Audit Trail'),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Tab Views
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildWhoWorkedTab(),
                _buildImportLogsTab(),
                _buildAuditLogsTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- Tab 0: Who Worked Log ---
  Widget _buildWhoWorkedTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. "WHO WORKED TODAY" KPI Summary Section
        _buildWhoWorkedTodayKpis(),
        const SizedBox(height: 16),

        // 2. Filters & Excel Export Toolbar
        _buildActivityFiltersToolbar(),
        const SizedBox(height: 12),

        // 3. Activity Log Table
        Expanded(
          child: _isLoadingActivities
              ? const Center(child: CircularProgressIndicator())
              : _activityLogs.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.assignment_turned_in_outlined, size: 54, color: Colors.grey.shade400),
                          const SizedBox(height: 12),
                          Text(
                            'No Activity Recorded for Selected Filter',
                            style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Staff actions, customer updates, and follow-ups will appear here.',
                            style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                          ),
                        ],
                      ),
                    )
                  : Card(
                      elevation: 1,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      child: ListView.separated(
                        itemCount: _activityLogs.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final log = _activityLogs[index];
                          return _buildActivityListTile(log);
                        },
                      ),
                    ),
        ),

        // 4. Pagination
        if (_activityTotalCount > _activityPageSize) ...[
          const SizedBox(height: 10),
          _buildActivityPagination(),
        ],
      ],
    );
  }

  Widget _buildWhoWorkedTodayKpis() {
    final theme = Theme.of(context);

    return Card(
      elevation: 1,
      color: const Color(0xFFF8FAFC),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.workspace_premium_rounded, color: theme.colorScheme.primary, size: 20),
                const SizedBox(width: 8),
                Text(
                  'WHO WORKED TODAY',
                  style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '${_todayMetrics.length} Staff Active',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: theme.colorScheme.primary),
                  ),
                ),
                const Spacer(),
                Text(
                  'Auto-aggregates all completed actions, follow-ups & stage moves',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (_isLoadingMetrics)
              const LinearProgressIndicator()
            else if (_todayMetrics.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Text('No operational actions logged today yet.', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
              )
            else
              SizedBox(
                height: 86,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _todayMetrics.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 12),
                  itemBuilder: (context, index) {
                    final m = _todayMetrics[index];
                    return Container(
                      width: 220,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFCBD5E1)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                m.staffName,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                              const Spacer(),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                decoration: BoxDecoration(
                                  color: Colors.blue.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  m.staffRole,
                                  style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.blue),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '${m.totalActions} Actions • ${m.customersWorked} Customers',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: theme.colorScheme.primary),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${m.completed} Done • ${m.pending} Pend • ${m.followups} F/ups',
                            style: TextStyle(fontSize: 10, color: Colors.grey.shade700),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildActivityFiltersToolbar() {
    return Row(
      children: [
        // Date Presets
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(8),
          ),
          child: DropdownButton<String>(
            value: _selectedDateRange,
            underline: const SizedBox(),
            isDense: true,
            items: const ['Today', 'This Week', 'This Month', 'All Time'].map((r) {
              return DropdownMenuItem(value: r, child: Text(r, style: const TextStyle(fontSize: 12)));
            }).toList(),
            onChanged: (val) {
              if (val != null) {
                setState(() {
                  _selectedDateRange = val;
                  _activityPage = 1;
                });
                _loadActivityLogs();
              }
            },
          ),
        ),
        const SizedBox(width: 8),

        // Staff Filter
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(8),
          ),
          child: DropdownButton<String>(
            value: _knownStaffNames.contains(_selectedStaff) ? _selectedStaff : 'All',
            underline: const SizedBox(),
            isDense: true,
            items: _knownStaffNames.map((s) {
              return DropdownMenuItem(value: s, child: Text('Staff: $s', style: const TextStyle(fontSize: 12)));
            }).toList(),
            onChanged: (val) {
              if (val != null) {
                setState(() {
                  _selectedStaff = val;
                  _activityPage = 1;
                });
                _loadActivityLogs();
              }
            },
          ),
        ),
        const SizedBox(width: 8),

        // Module Filter
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(8),
          ),
          child: DropdownButton<String>(
            value: _selectedModule,
            underline: const SizedBox(),
            isDense: true,
            items: const [
              'All',
              'Customer',
              'Loan',
              'Installation',
              'RTS',
              'Subsidy',
              'Payment',
              'Follow-up',
              'Workflow'
            ].map((m) {
              return DropdownMenuItem(value: m, child: Text('Module: $m', style: const TextStyle(fontSize: 12)));
            }).toList(),
            onChanged: (val) {
              if (val != null) {
                setState(() {
                  _selectedModule = val;
                  _activityPage = 1;
                });
                _loadActivityLogs();
              }
            },
          ),
        ),
        const SizedBox(width: 12),

        // Search Field
        Expanded(
          child: SizedBox(
            height: 38,
            child: TextField(
              controller: _activitySearchController,
              onChanged: _onActivitySearchChanged,
              decoration: InputDecoration(
                hintText: 'Search customer, consumer no, village...',
                hintStyle: const TextStyle(fontSize: 12),
                prefixIcon: const Icon(Icons.search, size: 18),
                contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 8),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),

        // Export Button
        FilledButton.icon(
          onPressed: _handleExportActivityExcel,
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF059669),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          icon: const Icon(Icons.file_download_outlined, size: 16),
          label: const Text('Export Activity Excel', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
        ),
      ],
    );
  }

  Widget _buildActivityListTile(ActivityLog log) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 10.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Time badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Column(
              children: [
                Text(log.formattedTime, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                Text(log.formattedDate, style: TextStyle(fontSize: 9, color: Colors.grey.shade600)),
              ],
            ),
          ),
          const SizedBox(width: 12),

          // Staff Info
          SizedBox(
            width: 140,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(log.staffName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                Text(log.staffRole.toUpperCase(), style: TextStyle(fontSize: 10, color: Colors.grey.shade600, fontWeight: FontWeight.w600)),
              ],
            ),
          ),

          // Customer Info
          SizedBox(
            width: 180,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(log.customerName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
                Text('No: ${log.consumerNo} • ${log.village}', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
              ],
            ),
          ),
          const SizedBox(width: 12),

          // Module & Action
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.blue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(log.module, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blue)),
          ),
          const SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(log.action, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                if (log.oldValue != null || log.newValue != null) ...[
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Text('Old: ${log.oldValue ?? '-'}', style: const TextStyle(fontSize: 11, color: Colors.red)),
                      const SizedBox(width: 6),
                      const Icon(Icons.arrow_forward_rounded, size: 10, color: Colors.grey),
                      const SizedBox(width: 6),
                      Text('New: ${log.newValue ?? '-'}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.green)),
                    ],
                  ),
                ],
                if (log.remarks != null && log.remarks!.isNotEmpty)
                  Text('Remarks: ${log.remarks}', style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Colors.grey.shade700)),
              ],
            ),
          ),

          // Next Action Pill
          if (log.nextAction != null && log.nextAction!.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                'Next: ${log.nextAction}',
                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.orange),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildActivityPagination() {
    final totalPages = (_activityTotalCount / _activityPageSize).ceil();

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'Showing ${(_activityPage - 1) * _activityPageSize + 1} to ${_activityPage * _activityPageSize > _activityTotalCount ? _activityTotalCount : _activityPage * _activityPageSize} of $_activityTotalCount activity records',
          style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
        ),
        Row(
          children: [
            OutlinedButton(
              onPressed: _activityPage > 1
                  ? () {
                      setState(() => _activityPage--);
                      _loadActivityLogs();
                    }
                  : null,
              child: const Text('Previous'),
            ),
            const SizedBox(width: 8),
            Text('Page $_activityPage of $totalPages', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold)),
            const SizedBox(width: 8),
            OutlinedButton(
              onPressed: _activityPage < totalPages
                  ? () {
                      setState(() => _activityPage++);
                      _loadActivityLogs();
                    }
                  : null,
              child: const Text('Next'),
            ),
          ],
        ),
      ],
    );
  }

  // --- Tab 1: Import Logs ---
  Widget _buildImportLogsTab() {
    if (_isLoadingImports) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_importLogs.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history_toggle_off_rounded, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              'No Import Runs Recorded Yet',
              style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              'Upload CSV or Excel files from the Records tab to start tracking batches.',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        Expanded(
          child: Card(
            elevation: 1,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: ListView.separated(
              itemCount: _importLogs.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final log = _importLogs[index];
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: const Color(0xFF059669).withValues(alpha: 0.1),
                    child: const Icon(Icons.table_chart_outlined, color: Color(0xFF059669), size: 20),
                  ),
                  title: Text(log.fileName, style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14)),
                  subtitle: Text(
                    '${log.insertedCount} added • ${log.updatedCount} updated • ${log.totalRows} total records\nBy ${log.userEmail ?? 'Admin'} on ${log.createdAt.toLocal().toString().split('.')[0]}',
                    style: const TextStyle(fontSize: 12),
                  ),
                  trailing: OutlinedButton(
                    onPressed: () => _showBatchDetails(log),
                    child: const Text('View Summary'),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  // --- Tab 2: Audit Logs ---
  Widget _buildAuditLogsTab() {
    return Column(
      children: [
        // Filter bar
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _auditSearchController,
                onChanged: _onAuditSearchChanged,
                decoration: InputDecoration(
                  hintText: 'Search audit records by Consumer No or changed value...',
                  prefixIcon: const Icon(Icons.search),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  isDense: true,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: DropdownButton<String>(
                value: _selectedAuditAction,
                underline: const SizedBox(),
                isDense: true,
                items: const ['All', 'INSERT', 'UPDATE', 'DELETE', 'IMPORT', 'RESTORE'].map((a) {
                  return DropdownMenuItem(value: a, child: Text('Action: $a', style: const TextStyle(fontSize: 13)));
                }).toList(),
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      _selectedAuditAction = val;
                      _auditPage = 1;
                    });
                    _loadAuditLogs();
                  }
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // List
        Expanded(
          child: _isLoadingAudits
              ? const Center(child: CircularProgressIndicator())
              : _auditLogs.isEmpty
                  ? Center(
                      child: Text('No audit logs found.', style: TextStyle(color: Colors.grey.shade600)),
                    )
                  : Card(
                      elevation: 1,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: ListView.separated(
                        itemCount: _auditLogs.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final log = _auditLogs[index];
                          return ListTile(
                            title: Row(
                              children: [
                                Text('Consumer No: ${log.consumerNo ?? '-'}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade200,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(log.action, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                                ),
                              ],
                            ),
                            subtitle: Text(
                              '${log.fieldName ?? 'Field'}: ${log.oldValue ?? 'None'} → ${log.newValue ?? 'None'}\nBy ${log.userEmail ?? 'Staff'} on ${log.createdAt.toLocal().toString().split('.')[0]}',
                              style: const TextStyle(fontSize: 11),
                            ),
                          );
                        },
                      ),
                    ),
        ),
      ],
    );
  }
}
