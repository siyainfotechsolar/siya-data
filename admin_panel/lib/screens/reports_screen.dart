import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';

import '../models/consumer_record.dart';
import '../models/report_filter_options.dart';
import '../services/report_service.dart';
import '../services/export_service.dart';
import '../services/realtime_service.dart';
import '../widgets/record_details_dialog.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  List<ConsumerRecord> _allActiveRecords = [];
  List<ConsumerRecord> _filteredRecords = [];

  ReportFilterOptions _filters = const ReportFilterOptions();
  ReportSummaryMetrics _summary = const ReportSummaryMetrics();
  WorkflowSummaryMetrics _workflow = const WorkflowSummaryMetrics();
  List<StageStatusMetric> _stageWisePending = [];

  StreamSubscription<ConsumerRecordChangeEvent>? _realtimeSub;

  // Available Table Columns
  final List<String> _allColumns = [
    'Customer Name',
    'Consumer No',
    'Application ID',
    'Application Date',
    'Submit Date',
    'Application Days',
    'Priority',
    'Current Work Stage',
    'Current Status',
    'Application Status',
    'Agreement Status',
    'Loan Required',
    'Loan Status',
    'Installation Status',
    'RTS Status',
    'Subsidy Status',
    'Assigned Staff',
  ];

  late Set<String> _visibleColumns;

  // Filter controllers & local state
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _staffController = TextEditingController();

  DateTime? _tempAppFrom;
  DateTime? _tempAppTo;
  DateTime? _tempSubFrom;
  DateTime? _tempSubTo;
  String? _tempStage;
  String? _tempStatus;
  String? _tempPriority;
  String? _tempLoanStatus;
  String? _tempInstallationStatus;
  String? _tempRtsStatus;
  String? _tempSubsidyStatus;

  // Scroll controllers for dual-axis scrolling
  final ScrollController _verticalScrollController = ScrollController();
  final ScrollController _horizontalScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _visibleColumns = Set.from(_allColumns);
    _loadData();
    _initRealtime();
  }

  void _initRealtime() {
    RealtimeSyncService.initialize();
    _realtimeSub = RealtimeSyncService.recordEvents.listen((_) {
      if (mounted) {
        _loadData(showLoading: false);
      }
    });
  }

  @override
  void dispose() {
    _realtimeSub?.cancel();
    _searchController.dispose();
    _staffController.dispose();
    _verticalScrollController.dispose();
    _horizontalScrollController.dispose();
    super.dispose();
  }

  Future<void> _loadData({bool showLoading = true}) async {
    if (showLoading) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final records = await ReportService.fetchAllActiveRecords();
      if (mounted) {
        setState(() {
          _allActiveRecords = records;
          _reapplyFiltersAndMetrics();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load report data: $e';
          _isLoading = false;
        });
      }
    }
  }

  void _reapplyFiltersAndMetrics() {
    _filteredRecords = ReportService.applyFilters(_allActiveRecords, _filters);
    _summary = ReportService.computeSummaryMetrics(_filteredRecords);
    _workflow = ReportService.computeWorkflowMetrics(_filteredRecords);
    _stageWisePending = ReportService.computeStageWisePending(_filteredRecords);
  }

  void _applyTempFilters() {
    setState(() {
      _filters = _filters.copyWith(
        applicationDateFrom: _tempAppFrom,
        applicationDateTo: _tempAppTo,
        submitDateFrom: _tempSubFrom,
        submitDateTo: _tempSubTo,
        workStage: _tempStage,
        status: _tempStatus,
        priority: _tempPriority,
        loanStatus: _tempLoanStatus,
        installationStatus: _tempInstallationStatus,
        rtsStatus: _tempRtsStatus,
        subsidyStatus: _tempSubsidyStatus,
        assignedStaff: _staffController.text.trim(),
        searchQuery: _searchController.text.trim(),
        clearAppDate: _tempAppFrom == null && _tempAppTo == null,
        clearSubmitDate: _tempSubFrom == null && _tempSubTo == null,
        clearStage: _tempStage == null || _tempStage!.isEmpty,
        clearStatus: _tempStatus == null || _tempStatus!.isEmpty,
        clearPriority: _tempPriority == null || _tempPriority!.isEmpty,
        clearLoan: _tempLoanStatus == null || _tempLoanStatus!.isEmpty,
        clearInstallation: _tempInstallationStatus == null || _tempInstallationStatus!.isEmpty,
        clearRts: _tempRtsStatus == null || _tempRtsStatus!.isEmpty,
        clearSubsidy: _tempSubsidyStatus == null || _tempSubsidyStatus!.isEmpty,
        clearStaff: _staffController.text.trim().isEmpty,
      );
      _reapplyFiltersAndMetrics();
    });
  }

  void _clearAllFilters() {
    setState(() {
      _searchController.clear();
      _staffController.clear();
      _tempAppFrom = null;
      _tempAppTo = null;
      _tempSubFrom = null;
      _tempSubTo = null;
      _tempStage = null;
      _tempStatus = null;
      _tempPriority = null;
      _tempLoanStatus = null;
      _tempInstallationStatus = null;
      _tempRtsStatus = null;
      _tempSubsidyStatus = null;
      _filters = const ReportFilterOptions();
      _reapplyFiltersAndMetrics();
    });
  }

  // --- Export Actions ---

  Future<void> _exportExcel() async {
    try {
      final bytes = ExportService.generateExcel(
        records: _filteredRecords,
        visibleColumns: _visibleColumns.toList(),
      );
      final fileName = 'siya_solar_report_${DateTime.now().millisecondsSinceEpoch}.xlsx';
      
      final result = await FilePicker.platform.saveFile(
        dialogTitle: 'Export Report as Excel',
        fileName: fileName,
        bytes: Uint8List.fromList(bytes),
        type: FileType.custom,
        allowedExtensions: ['xlsx'],
      );

      if (result != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Report exported to Excel successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to export Excel: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _exportCsv() async {
    try {
      final csvString = ExportService.generateCsv(
        records: _filteredRecords,
        visibleColumns: _visibleColumns.toList(),
      );
      final bytes = utf8.encode(csvString);
      final fileName = 'siya_solar_report_${DateTime.now().millisecondsSinceEpoch}.csv';

      final result = await FilePicker.platform.saveFile(
        dialogTitle: 'Export Report as CSV',
        fileName: fileName,
        bytes: Uint8List.fromList(bytes),
        type: FileType.custom,
        allowedExtensions: ['csv'],
      );

      if (result != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Report exported to CSV successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to export CSV: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _exportPdf() async {
    try {
      final pdfBytes = await ExportService.generatePdf(
        records: _filteredRecords,
        summary: _summary,
        workflow: _workflow,
        filters: _filters,
        visibleColumns: _visibleColumns.toList(),
      );
      final fileName = 'siya_solar_report_${DateTime.now().millisecondsSinceEpoch}.pdf';

      final result = await FilePicker.platform.saveFile(
        dialogTitle: 'Export Report as PDF',
        fileName: fileName,
        bytes: pdfBytes,
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );

      if (result != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Report exported to PDF successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to export PDF: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showColumnVisibilityDialog() {
    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Row(
                children: [
                  Icon(Icons.view_column_rounded, color: Colors.blue),
                  SizedBox(width: 8),
                  Text('Customize Visible Columns'),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: _allColumns.map((col) {
                    final isChecked = _visibleColumns.contains(col);
                    return CheckboxListTile(
                      title: Text(col, style: const TextStyle(fontSize: 14)),
                      value: isChecked,
                      onChanged: (val) {
                        setDialogState(() {
                          if (val == true) {
                            _visibleColumns.add(col);
                          } else {
                            if (_visibleColumns.length > 1) {
                              _visibleColumns.remove(col);
                            }
                          }
                        });
                        setState(() {});
                      },
                    );
                  }).toList(),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    setState(() => _visibleColumns = Set.from(_allColumns));
                    setDialogState(() {});
                  },
                  child: const Text('Select All'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Done'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline_rounded, size: 48, color: theme.colorScheme.error),
                      const SizedBox(height: 16),
                      Text(_errorMessage!, style: TextStyle(color: theme.colorScheme.error)),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: _loadData,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 1. Header Section
                      _buildHeaderSection(theme),
                      const SizedBox(height: 20),

                      // 2. Global Filter Bar
                      _buildFilterBar(theme),
                      const SizedBox(height: 20),

                      // Active Filter Chips
                      if (_filters.hasActiveFilters) ...[
                        _buildFilterChips(theme),
                        const SizedBox(height: 20),
                      ],

                      // 3. Summary Cards Grid
                      _buildSummaryCards(theme),
                      const SizedBox(height: 24),

                      // 4. Workflow Summary
                      _buildWorkflowSummary(theme),
                      const SizedBox(height: 24),

                      // 5. Priority & Stage-wise Pending Split Section
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(flex: 2, child: _buildPrioritySummaryCard(theme)),
                          const SizedBox(width: 20),
                          Expanded(flex: 3, child: _buildStageWisePendingCard(theme)),
                        ],
                      ),
                      const SizedBox(height: 28),

                      // 6. Main Data Table Section
                      _buildMainTableSection(theme),
                    ],
                  ),
                ),
    );
  }

  // --- HEADER SECTION ---

  Widget _buildHeaderSection(ThemeData theme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.bar_chart_rounded, size: 28, color: theme.colorScheme.primary),
                const SizedBox(width: 10),
                const Text(
                  'Reports & Executive Dashboard',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Live database analytics, 6-stage workflow breakdown, and priority metrics',
              style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 13),
            ),
          ],
        ),
        Row(
          children: [
            OutlinedButton.icon(
              onPressed: _exportExcel,
              icon: const Icon(Icons.table_view_outlined, color: Colors.green),
              label: const Text('Export Excel', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
              style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.green)),
            ),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              onPressed: _exportCsv,
              icon: const Icon(Icons.description_outlined, color: Colors.blue),
              label: const Text('Export CSV', style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
              style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.blue)),
            ),
            const SizedBox(width: 8),
            FilledButton.icon(
              onPressed: _exportPdf,
              icon: const Icon(Icons.picture_as_pdf_outlined),
              label: const Text('Export PDF', style: TextStyle(fontWeight: FontWeight.bold)),
              style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              tooltip: 'Refresh Data',
              onPressed: () => _loadData(),
            ),
          ],
        ),
      ],
    );
  }

  // --- GLOBAL FILTER BAR ---

  Widget _buildFilterBar(ThemeData theme) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.filter_alt_outlined, size: 20, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text('Global Filter Bar', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                // Application Date From & To
                _buildDatePickerButton('App Date From', _tempAppFrom, (d) => setState(() => _tempAppFrom = d)),
                _buildDatePickerButton('App Date To', _tempAppTo, (d) => setState(() => _tempAppTo = d)),

                // Submit Date From & To
                _buildDatePickerButton('Submit Date From', _tempSubFrom, (d) => setState(() => _tempSubFrom = d)),
                _buildDatePickerButton('Submit Date To', _tempSubTo, (d) => setState(() => _tempSubTo = d)),

                // Stage Dropdown
                _buildDropdown(
                  label: 'Current Work Stage',
                  value: _tempStage,
                  items: const ['Application', 'Agreement', 'Loan', 'Installation', 'RTS', 'Subsidy', 'Completed'],
                  onChanged: (val) => setState(() => _tempStage = val),
                ),

                // Status Dropdown
                _buildDropdown(
                  label: 'Status',
                  value: _tempStatus,
                  items: const ['Pending', 'Submitted', 'Uploaded', 'Verified', 'Approved', 'Completed', 'Rejected'],
                  onChanged: (val) => setState(() => _tempStatus = val),
                ),

                // Priority Dropdown
                _buildDropdown(
                  label: 'Priority',
                  value: _tempPriority,
                  items: const ['CRITICAL', 'HIGH', 'MEDIUM', 'NORMAL'],
                  onChanged: (val) => setState(() => _tempPriority = val),
                ),

                // Loan Status Dropdown
                _buildDropdown(
                  label: 'Loan Status',
                  value: _tempLoanStatus,
                  items: const ['Not Required', 'Pending', 'Applied', 'Under Process', 'Approved', 'Rejected'],
                  onChanged: (val) => setState(() => _tempLoanStatus = val),
                ),

                // Installation Status Dropdown
                _buildDropdown(
                  label: 'Installation Status',
                  value: _tempInstallationStatus,
                  items: const ['Not Started', 'Scheduled', 'Installation Pending', 'Structure Pending', 'Panel Pending', 'Wiring Pending', 'Installation Completed'],
                  onChanged: (val) => setState(() => _tempInstallationStatus = val),
                ),

                // RTS Status Dropdown
                _buildDropdown(
                  label: 'RTS Status',
                  value: _tempRtsStatus,
                  items: const ['Not Started', 'Application Pending', 'Applied', 'Meter Pending', 'Inspection Pending', 'Completed', 'Rejected'],
                  onChanged: (val) => setState(() => _tempRtsStatus = val),
                ),

                // Subsidy Status Dropdown
                _buildDropdown(
                  label: 'Subsidy Status',
                  value: _tempSubsidyStatus,
                  items: const ['Not Applied', 'Applied', 'Under Process', 'Pending', 'Approved', 'Received', 'Rejected'],
                  onChanged: (val) => setState(() => _tempSubsidyStatus = val),
                ),

                // Search field
                SizedBox(
                  width: 200,
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      labelText: 'Search Customer / No',
                      isDense: true,
                      prefixIcon: const Icon(Icons.search, size: 18),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),

                // Action Buttons
                FilledButton.icon(
                  onPressed: _applyTempFilters,
                  icon: const Icon(Icons.check_rounded, size: 18),
                  label: const Text('APPLY'),
                ),
                OutlinedButton.icon(
                  onPressed: _clearAllFilters,
                  icon: const Icon(Icons.clear_all_rounded, size: 18),
                  label: const Text('CLEAR ALL'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDatePickerButton(String label, DateTime? selected, ValueChanged<DateTime?> onSelected) {
    final str = selected != null ? selected.toIso8601String().split('T')[0] : label;
    return OutlinedButton.icon(
      onPressed: () async {
        final d = await showDatePicker(
          context: context,
          initialDate: selected ?? DateTime.now(),
          firstDate: DateTime(2020),
          lastDate: DateTime(2030),
        );
        onSelected(d);
      },
      icon: const Icon(Icons.calendar_today_outlined, size: 16),
      label: Text(str, style: TextStyle(fontSize: 13, color: selected != null ? Colors.blue : null)),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  Widget _buildDropdown({
    required String label,
    required String? value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return SizedBox(
      width: 170,
      child: DropdownButtonFormField<String>(
        value: value != null && items.contains(value) ? value : null,
        isDense: true,
        decoration: InputDecoration(
          labelText: label,
          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        ),
        items: [
          DropdownMenuItem<String>(value: null, child: Text('All $label', style: const TextStyle(fontSize: 12, color: Colors.grey))),
          ...items.map((i) => DropdownMenuItem(value: i, child: Text(i, style: const TextStyle(fontSize: 13)))),
        ],
        onChanged: onChanged,
      ),
    );
  }

  // --- FILTER CHIPS ---

  Widget _buildFilterChips(ThemeData theme) {
    final chips = <Widget>[];

    if (_filters.workStage != null) {
      chips.add(_chip('Stage: ${_filters.workStage}', () => setState(() {
        _tempStage = null;
        _applyTempFilters();
      })));
    }
    if (_filters.status != null) {
      chips.add(_chip('Status: ${_filters.status}', () => setState(() {
        _tempStatus = null;
        _applyTempFilters();
      })));
    }
    if (_filters.priority != null) {
      chips.add(_chip('Priority: ${_filters.priority}', () => setState(() {
        _tempPriority = null;
        _applyTempFilters();
      })));
    }
    if (_filters.loanStatus != null) {
      chips.add(_chip('Loan: ${_filters.loanStatus}', () => setState(() {
        _tempLoanStatus = null;
        _applyTempFilters();
      })));
    }
    if (_filters.installationStatus != null) {
      chips.add(_chip('Install: ${_filters.installationStatus}', () => setState(() {
        _tempInstallationStatus = null;
        _applyTempFilters();
      })));
    }
    if (_filters.rtsStatus != null) {
      chips.add(_chip('RTS: ${_filters.rtsStatus}', () => setState(() {
        _tempRtsStatus = null;
        _applyTempFilters();
      })));
    }
    if (_filters.subsidyStatus != null) {
      chips.add(_chip('Subsidy: ${_filters.subsidyStatus}', () => setState(() {
        _tempSubsidyStatus = null;
        _applyTempFilters();
      })));
    }
    if (_filters.searchQuery.isNotEmpty) {
      chips.add(_chip('Search: "${_filters.searchQuery}"', () => setState(() {
        _searchController.clear();
        _applyTempFilters();
      })));
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: chips,
    );
  }

  Widget _chip(String label, VoidCallback onDeleted) {
    return Chip(
      label: Text(label, style: const TextStyle(fontSize: 12)),
      deleteIcon: const Icon(Icons.close, size: 14),
      onDeleted: onDeleted,
      backgroundColor: Colors.blue.withValues(alpha: 0.1),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    );
  }

  // --- SUMMARY CARDS ---

  Widget _buildSummaryCards(ThemeData theme) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth > 1200 ? 8 : (constraints.maxWidth > 800 ? 4 : 2);
        return GridView.count(
          crossAxisCount: crossAxisCount,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.6,
          children: [
            _metricCard('Total Applications', '${_summary.totalApplications}', Icons.article_outlined, Colors.blue),
            _metricCard('Active Applications', '${_summary.activeApplications}', Icons.pending_actions_outlined, Colors.indigo),
            _metricCard('Pending', '${_summary.pending}', Icons.hourglass_top_rounded, Colors.amber.shade800),
            _metricCard('Critical (31+ Days)', '${_summary.critical}', Icons.error_rounded, Colors.red),
            _metricCard('High (16–30 Days)', '${_summary.high}', Icons.warning_rounded, Colors.orange.shade800),
            _metricCard('Medium (8–15 Days)', '${_summary.medium}', Icons.info_rounded, Colors.amber.shade700),
            _metricCard('Normal (0–7 Days)', '${_summary.normal}', Icons.check_circle_rounded, Colors.green),
            _metricCard('Completed', '${_summary.completed}', Icons.verified_rounded, Colors.teal),
          ],
        );
      },
    );
  }

  Widget _metricCard(String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: color.withValues(alpha: 0.3)),
      ),
      color: color.withValues(alpha: 0.05),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
                Icon(icon, size: 20, color: color),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color.withValues(alpha: 0.9)),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  // --- WORKFLOW SUMMARY ---

  Widget _buildWorkflowSummary(ThemeData theme) {
    final stages = [
      {'name': 'APPLICATION', 'count': _workflow.application, 'icon': Icons.description_outlined, 'color': Colors.blue},
      {'name': 'AGREEMENT', 'count': _workflow.agreement, 'icon': Icons.assignment_outlined, 'color': Colors.indigo},
      {'name': 'LOAN', 'count': _workflow.loan, 'icon': Icons.account_balance_outlined, 'color': Colors.purple},
      {'name': 'INSTALLATION', 'count': _workflow.installation, 'icon': Icons.build_outlined, 'color': Colors.amber.shade800},
      {'name': 'RTS', 'count': _workflow.rts, 'icon': Icons.electric_meter_outlined, 'color': Colors.deepOrange},
      {'name': 'SUBSIDY', 'count': _workflow.subsidy, 'icon': Icons.payments_outlined, 'color': Colors.cyan.shade800},
      {'name': 'COMPLETED', 'count': _workflow.completed, 'icon': Icons.verified_rounded, 'color': Colors.green},
    ];

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.alt_route_rounded, size: 20, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text('6-Stage Workflow Summary Breakdown', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: stages.map((s) {
                final color = s['color'] as Color;
                final isLast = s['name'] == 'COMPLETED';
                return Expanded(
                  child: InkWell(
                    onTap: () {
                      setState(() {
                        _tempStage = s['name'] as String;
                        _applyTempFilters();
                      });
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                      margin: EdgeInsets.only(right: isLast ? 0 : 8),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.08),
                        border: Border.all(color: color.withValues(alpha: 0.3)),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        children: [
                          Icon(s['icon'] as IconData, size: 22, color: color),
                          const SizedBox(height: 6),
                          Text(
                            '${s['count']}',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            s['name'] as String,
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  // --- PRIORITY SUMMARY CARD ---

  Widget _buildPrioritySummaryCard(ThemeData theme) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.priority_high_rounded, size: 20, color: Colors.red),
                const SizedBox(width: 8),
                Text('Priority Report', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Calculated strictly from Submit Date to Current Date',
              style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            _priorityRow('🔴 Critical (31+ Days)', _summary.critical, const Color(0xFFDC2626), 'CRITICAL'),
            const Divider(height: 12),
            _priorityRow('🟠 High (16–30 Days)', _summary.high, const Color(0xFFEA580C), 'HIGH'),
            const Divider(height: 12),
            _priorityRow('🟡 Medium (8–15 Days)', _summary.medium, const Color(0xFFD97706), 'MEDIUM'),
            const Divider(height: 12),
            _priorityRow('🟢 Normal (0–7 Days)', _summary.normal, const Color(0xFF16A34A), 'NORMAL'),
          ],
        ),
      ),
    );
  }

  Widget _priorityRow(String label, int count, Color color, String priorityKey) {
    return InkWell(
      onTap: () {
        setState(() {
          _tempPriority = priorityKey;
          _applyTempFilters();
        });
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: color)),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '$count',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- STAGE-WISE PENDING CARD ---

  Widget _buildStageWisePendingCard(ThemeData theme) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.table_view_rounded, size: 20, color: theme.colorScheme.primary),
                    const SizedBox(width: 8),
                    Text('Stage-wise Pending Breakdown', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                  ],
                ),
                Text('${_stageWisePending.length} Categories', style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant)),
              ],
            ),
            const SizedBox(height: 12),
            if (_stageWisePending.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text('No pending records found.', style: TextStyle(fontSize: 13, color: Colors.grey)),
              )
            else
              Table(
                columnWidths: const {
                  0: FlexColumnWidth(2),
                  1: FlexColumnWidth(3),
                  2: FlexColumnWidth(1),
                },
                children: [
                  TableRow(
                    decoration: BoxDecoration(color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3)),
                    children: const [
                      Padding(padding: EdgeInsets.all(8), child: Text('Stage', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                      Padding(padding: EdgeInsets.all(8), child: Text('Current Status', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                      Padding(padding: EdgeInsets.all(8), child: Text('Count', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12), textAlign: TextAlign.right)),
                    ],
                  ),
                  ..._stageWisePending.take(8).map((m) {
                    return TableRow(
                      children: [
                        TableCell(
                          child: InkWell(
                            onTap: () {
                              setState(() {
                                _tempStage = m.stage;
                                _tempStatus = m.status;
                                _applyTempFilters();
                              });
                            },
                            child: Padding(
                              padding: const EdgeInsets.all(8),
                              child: Text(m.stage, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blue)),
                            ),
                          ),
                        ),
                        TableCell(
                          child: Padding(
                            padding: const EdgeInsets.all(8),
                            child: Text(m.status, style: const TextStyle(fontSize: 12)),
                          ),
                        ),
                        TableCell(
                          child: Padding(
                            padding: const EdgeInsets.all(8),
                            child: Text('${m.count}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold), textAlign: TextAlign.right),
                          ),
                        ),
                      ],
                    );
                  }),
                ],
              ),
          ],
        ),
      ),
    );
  }

  // --- MAIN REPORT TABLE ---

  Widget _buildMainTableSection(ThemeData theme) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Table Header Bar
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.list_alt_rounded, size: 22, color: theme.colorScheme.primary),
                    const SizedBox(width: 8),
                    Text(
                      'Detailed Report Table (${_filteredRecords.length} Records)',
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                Row(
                  children: [
                    // Sort Selector
                    DropdownButton<String>(
                      value: _filters.sortBy,
                      isDense: true,
                      underline: const SizedBox(),
                      items: const [
                        DropdownMenuItem(value: 'days', child: Text('Sort: Application Days', style: TextStyle(fontSize: 13))),
                        DropdownMenuItem(value: 'submit_date', child: Text('Sort: Submit Date', style: TextStyle(fontSize: 13))),
                        DropdownMenuItem(value: 'app_date', child: Text('Sort: Application Date', style: TextStyle(fontSize: 13))),
                        DropdownMenuItem(value: 'priority', child: Text('Sort: Priority Level', style: TextStyle(fontSize: 13))),
                        DropdownMenuItem(value: 'stage', child: Text('Sort: Workflow Stage', style: TextStyle(fontSize: 13))),
                        DropdownMenuItem(value: 'name', child: Text('Sort: Customer Name', style: TextStyle(fontSize: 13))),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setState(() {
                            _filters = _filters.copyWith(sortBy: val);
                            _reapplyFiltersAndMetrics();
                          });
                        }
                      },
                    ),
                    IconButton(
                      icon: Icon(_filters.sortAscending ? Icons.arrow_upward : Icons.arrow_downward, size: 18),
                      tooltip: _filters.sortAscending ? 'Sort Ascending' : 'Sort Descending',
                      onPressed: () {
                        setState(() {
                          _filters = _filters.copyWith(sortAscending: !_filters.sortAscending);
                          _reapplyFiltersAndMetrics();
                        });
                      },
                    ),
                    const SizedBox(width: 12),
                    OutlinedButton.icon(
                      onPressed: _showColumnVisibilityDialog,
                      icon: const Icon(Icons.view_column_rounded, size: 18),
                      label: Text('Columns (${_visibleColumns.length}/${_allColumns.length})'),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Scrollable Table Grid
            if (_filteredRecords.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32.0),
                  child: Text('No customer records match the selected filters.', style: TextStyle(color: Colors.grey)),
                ),
              )
            else
              Scrollbar(
                controller: _verticalScrollController,
                thumbVisibility: true,
                child: SingleChildScrollView(
                  controller: _verticalScrollController,
                  scrollDirection: Axis.vertical,
                  child: Scrollbar(
                    controller: _horizontalScrollController,
                    thumbVisibility: true,
                    child: SingleChildScrollView(
                      controller: _horizontalScrollController,
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        headingRowColor: WidgetStateProperty.all(theme.colorScheme.primaryContainer.withValues(alpha: 0.3)),
                        columns: _visibleColumns.map((col) {
                          return DataColumn(
                            label: Text(
                              col,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                          );
                        }).toList(),
                        rows: _filteredRecords.map((r) {
                          return DataRow(
                            cells: _visibleColumns.map((col) {
                              return DataCell(_buildCellWidget(r, col));
                            }).toList(),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCellWidget(ConsumerRecord r, String col) {
    switch (col) {
      case 'Customer Name':
        return InkWell(
          onTap: () => _openRecordDetails(r),
          child: Text(
            r.name,
            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue, decoration: TextDecoration.underline),
          ),
        );
      case 'Consumer No':
        return InkWell(
          onTap: () => _openRecordDetails(r),
          child: Text(
            r.consumerNo,
            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue, decoration: TextDecoration.underline),
          ),
        );
      case 'Priority':
        final color = r.priorityLevel.color;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            r.priority,
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: color),
          ),
        );
      case 'Current Work Stage':
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: Colors.blue.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            r.overallStage,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.blue),
          ),
        );
      default:
        return Text(ExportService.getColumnValue(r, col), style: const TextStyle(fontSize: 12));
    }
  }

  void _openRecordDetails(ConsumerRecord record) {
    showDialog(
      context: context,
      builder: (_) => RecordDetailsDialog(
        record: record,
        onRecordUpdated: () => _loadData(showLoading: false),
      ),
    );
  }
}
