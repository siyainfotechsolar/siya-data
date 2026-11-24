import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'package:file_picker/file_picker.dart';

import '../models/consumer_record.dart';
import '../models/msedcl_change_of_name.dart';
import '../services/msedcl_change_of_name_service.dart';
import '../services/msedcl_pdf_service.dart';
import '../services/msedcl_excel_service.dart';
import '../utils/universal_file_saver.dart';
import '../utils/responsive.dart';

enum MsedclViewTab { all, pendingDocs, processing, completed }

class MsedclChangeOfNameScreen extends StatefulWidget {
  const MsedclChangeOfNameScreen({super.key});

  @override
  State<MsedclChangeOfNameScreen> createState() => _MsedclChangeOfNameScreenState();
}

class _MsedclChangeOfNameScreenState extends State<MsedclChangeOfNameScreen> {
  final DateFormat _dateFormat = DateFormat('dd/MM/yyyy');

  List<MsedclChangeOfNameApplication> _allApplications = [];
  List<ConsumerRecord> _availableConsumers = [];

  bool _isLoading = true;
  bool _isExporting = false;
  String? _errorMessage;

  MsedclViewTab _currentTab = MsedclViewTab.all;

  // Filter controllers & states
  final TextEditingController _searchCtrl = TextEditingController();
  String _selectedStatusFilter = 'All';
  String _selectedSubDivisionFilter = 'All';
  String _selectedEmployeeFilter = 'All';
  DateTime? _filterStartDate;
  DateTime? _filterEndDate;

  // Sub-division options
  static const List<String> subDivisions = [
    'All',
    'Nardana Sub-Division',
    'Shindkheda Sub-Division',
    'Dhule Rural Sub-Division',
    'Dhule Urban Sub-Division',
    'Shirpur Sub-Division',
    'Sakri Sub-Division',
    'Dondaicha Sub-Division',
  ];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final results = await Future.wait([
        MsedclChangeOfNameService.fetchApplications(),
        MsedclChangeOfNameService.fetchAvailableCustomers(),
      ]);

      if (mounted) {
        setState(() {
          _allApplications = results[0] as List<MsedclChangeOfNameApplication>;
          _availableConsumers = results[1] as List<ConsumerRecord>;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.toString().replaceAll('Exception: ', '');
        });
      }
    }
  }

  /// Filtered applications
  List<MsedclChangeOfNameApplication> get _filteredApplications {
    final q = _searchCtrl.text.trim().toLowerCase();

    return _allApplications.where((a) {
      // 1. Tab filter
      if (_currentTab == MsedclViewTab.pendingDocs &&
          (a.status == MsedclApplicationStatus.approved || a.status == MsedclApplicationStatus.nameChanged)) {
        return false;
      }
      if (_currentTab == MsedclViewTab.pendingDocs && a.status != MsedclApplicationStatus.docsPending && a.status != MsedclApplicationStatus.newEntry) {
        return false;
      }
      if (_currentTab == MsedclViewTab.processing &&
          (a.status != MsedclApplicationStatus.submitted && a.status != MsedclApplicationStatus.msedclProcessing && a.status != MsedclApplicationStatus.objectionRaised)) {
        return false;
      }
      if (_currentTab == MsedclViewTab.completed &&
          (a.status != MsedclApplicationStatus.approved && a.status != MsedclApplicationStatus.nameChanged)) {
        return false;
      }

      // 2. Status dropdown
      if (_selectedStatusFilter != 'All' && a.status.toLowerCase() != _selectedStatusFilter.toLowerCase()) {
        return false;
      }

      // 3. Sub-Division dropdown
      if (_selectedSubDivisionFilter != 'All' && !a.subDivisionOffice.toLowerCase().contains(_selectedSubDivisionFilter.toLowerCase())) {
        return false;
      }

      // 4. Employee dropdown
      if (_selectedEmployeeFilter != 'All' && a.assignedEmployee.toLowerCase() != _selectedEmployeeFilter.toLowerCase()) {
        return false;
      }

      // 5. Date filter
      if (_filterStartDate != null) {
        final start = DateTime(_filterStartDate!.year, _filterStartDate!.month, _filterStartDate!.day);
        if (a.applicationDate.isBefore(start)) return false;
      }
      if (_filterEndDate != null) {
        final end = DateTime(_filterEndDate!.year, _filterEndDate!.month, _filterEndDate!.day, 23, 59, 59);
        if (a.applicationDate.isAfter(end)) return false;
      }

      // 6. Search text
      if (q.isNotEmpty) {
        final match = a.applicationNo.toLowerCase().contains(q) ||
            a.consumerNo.toLowerCase().contains(q) ||
            a.oldConsumerFullName.toLowerCase().contains(q) ||
            a.newConsumerFullName.toLowerCase().contains(q) ||
            a.village.toLowerCase().contains(q) ||
            a.newMobileNo.contains(q) ||
            a.propertyAddress.toLowerCase().contains(q);
        if (!match) return false;
      }

      return true;
    }).toList();
  }

  void _resetFilters() {
    setState(() {
      _searchCtrl.clear();
      _selectedStatusFilter = 'All';
      _selectedSubDivisionFilter = 'All';
      _selectedEmployeeFilter = 'All';
      _filterStartDate = null;
      _filterEndDate = null;
    });
  }

  String get _appliedFiltersText {
    final parts = <String>[];
    if (_searchCtrl.text.trim().isNotEmpty) parts.add('Search: "${_searchCtrl.text.trim()}"');
    if (_selectedStatusFilter != 'All') parts.add('Status: $_selectedStatusFilter');
    if (_selectedSubDivisionFilter != 'All') parts.add('Sub-Division: $_selectedSubDivisionFilter');
    if (_selectedEmployeeFilter != 'All') parts.add('Staff: $_selectedEmployeeFilter');
    if (_filterStartDate != null && _filterEndDate != null) {
      parts.add('Date: ${_dateFormat.format(_filterStartDate!)} to ${_dateFormat.format(_filterEndDate!)}');
    }
    return parts.isEmpty ? 'All Records (Unfiltered)' : parts.join(', ');
  }

  // ==========================================
  // ACTIONS
  // ==========================================

  Future<void> _exportToExcel() async {
    final toExport = _filteredApplications;
    if (toExport.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No applications found to export.'), backgroundColor: Colors.orange),
      );
      return;
    }

    setState(() => _isExporting = true);
    try {
      final savedPath = await MsedclExcelService.exportAndSave(
        applications: toExport,
        appliedFilterDescription: _appliedFiltersText,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              savedPath != null
                  ? 'Excel Report exported successfully! (${toExport.length} applications, 5 sheets)'
                  : 'Excel Export cancelled.',
            ),
            backgroundColor: savedPath != null ? const Color(0xFF047857) : Colors.grey,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to export Excel report: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  Future<void> _openAddEditApplicationDialog({MsedclChangeOfNameApplication? existing, ConsumerRecord? preselectedCustomer}) async {
    final result = await showDialog<MsedclChangeOfNameApplication>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _MsedclApplicationFormDialog(
        existing: existing,
        preselectedCustomer: preselectedCustomer,
        availableCustomers: _availableConsumers,
        onSave: (app) async {
          return await MsedclChangeOfNameService.saveApplication(app);
        },
      ),
    );

    if (result != null && mounted) {
      await _loadData();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Application "${result.applicationNo}" for ${result.computedNewFullName} saved successfully.'),
          backgroundColor: const Color(0xFF047857),
        ),
      );
    }
  }

  void _openDocumentGeneratorDialog(MsedclChangeOfNameApplication application) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _MsedclDocumentGeneratorDialog(application: application),
    );
  }

  void _openViewApplicationDialog(MsedclChangeOfNameApplication application) {
    showDialog(
      context: context,
      builder: (ctx) => _ViewMsedclApplicationDialog(
        application: application,
        onEdit: () {
          Navigator.pop(ctx);
          _openAddEditApplicationDialog(existing: application);
        },
        onStatus: () {
          Navigator.pop(ctx);
          _openStatusHistoryDialog(application);
        },
        onPdf: () {
          Navigator.pop(ctx);
          _openDocumentGeneratorDialog(application);
        },
        onDelete: () {
          Navigator.pop(ctx);
          _deleteApplication(application);
        },
      ),
    );
  }

  void _openStatusHistoryDialog(MsedclChangeOfNameApplication application) {
    showDialog(
      context: context,
      builder: (ctx) => _MsedclStatusHistoryDialog(
        application: application,
        onStatusUpdated: (newStatus, remarks) async {
          await MsedclChangeOfNameService.updateStatus(
            id: application.id,
            newStatus: newStatus,
            updatedBy: 'Admin',
            remarks: remarks,
          );
          _loadData();
        },
      ),
    );
  }

  Future<void> _deleteApplication(MsedclChangeOfNameApplication application) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.delete_outline, color: Colors.red),
            SizedBox(width: 8),
            Text('Delete Application'),
          ],
        ),
        content: Text(
          'Are you sure you want to delete application "${application.applicationNo}" for '
          '${application.computedNewFullName} (Consumer No: ${application.consumerNo})?\n\n'
          'All associated document records and status history will be removed.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await MsedclChangeOfNameService.deleteApplication(application.id);
      _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Application deleted successfully.'), backgroundColor: Colors.green),
        );
      }
    }
  }

  // ==========================================
  // BUILD SCREEN
  // ==========================================

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isMobile = Responsive.isMobile(context);
    final displayed = _filteredApplications;

    // Counts
    final pendingCount = _allApplications.where((a) => a.status == MsedclApplicationStatus.docsPending || a.status == MsedclApplicationStatus.newEntry).length;
    final processingCount = _allApplications.where((a) => a.status == MsedclApplicationStatus.submitted || a.status == MsedclApplicationStatus.msedclProcessing || a.status == MsedclApplicationStatus.objectionRaised).length;
    final approvedCount = _allApplications.where((a) => a.status == MsedclApplicationStatus.approved || a.status == MsedclApplicationStatus.nameChanged).length;

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // HEADER BAR
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 8,
                        children: [
                          const Icon(Icons.assignment_turned_in_rounded, size: 28, color: Color(0xFF0F3B7A)),
                          Text(
                            isMobile ? 'MSEDCL Name Change' : 'MSEDCL Change of Name & Stamp Paper Generator',
                            style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          Chip(
                            backgroundColor: Colors.blue.shade50,
                            side: BorderSide(color: Colors.blue.shade200),
                            label: Text(
                              '${_allApplications.length} Applications',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blue.shade900),
                            ),
                          ),
                        ],
                      ),
                      if (!isMobile) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Generate official MSEDCL U Form, New Customer Stamp Paper Affidavit (₹100/₹500), Form X Security Deposit, and combined upload-ready PDFs.',
                          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                        ),
                      ],
                    ],
                  ),
                ),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  alignment: WrapAlignment.end,
                  children: [
                    // Excel Export (5 Sheets)
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF047857), // Emerald
                        foregroundColor: Colors.white,
                      ),
                      onPressed: _isExporting ? null : _exportToExcel,
                      icon: _isExporting
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Icon(Icons.table_view_rounded, size: 18),
                      label: Text(isMobile ? 'Excel' : 'Export to Excel (5 Sheets)'),
                    ),
                    // Add Application
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF0F3B7A), // MSEDCL Blue
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () => _openAddEditApplicationDialog(),
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: Text(isMobile ? 'New App' : '+ New Name Change App'),
                    ),
                    IconButton(
                      onPressed: _loadData,
                      icon: const Icon(Icons.refresh),
                      tooltip: 'Refresh',
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 14),

            // DASHBOARD SUMMARY METRICS (5 Cards)
            _buildDashboardMetricsBar(theme, isMobile),
            const SizedBox(height: 12),

            // FILTERS TOOLBAR
            _buildFiltersToolbar(theme, isMobile),
            const SizedBox(height: 10),

            // VIEW TAB SELECTOR
            _buildTabSelector(theme, pendingCount, processingCount, approvedCount),
            const SizedBox(height: 10),

            // MAIN CONTENT TABLE
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _errorMessage != null
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.error_outline, size: 48, color: Colors.red),
                              const SizedBox(height: 12),
                              Text(_errorMessage!),
                              const SizedBox(height: 12),
                              FilledButton(onPressed: _loadData, child: const Text('Retry')),
                            ],
                          ),
                        )
                      : _buildApplicationsTable(theme, displayed, isMobile),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // DASHBOARD METRIC CARDS
  // ==========================================

  Widget _buildDashboardMetricsBar(ThemeData theme, bool isMobile) {
    final total = _allApplications.length;
    final pendingDocs = _allApplications.where((a) => a.status == MsedclApplicationStatus.docsPending || a.status == MsedclApplicationStatus.newEntry).length;
    final submitted = _allApplications.where((a) => a.status == MsedclApplicationStatus.submitted || a.status == MsedclApplicationStatus.msedclProcessing).length;
    final approved = _allApplications.where((a) => a.status == MsedclApplicationStatus.approved || a.status == MsedclApplicationStatus.nameChanged).length;
    final subDivCount = _allApplications.map((a) => a.subDivisionOffice).toSet().length;

    final cards = [
      _MetricCard(
        title: 'Total Applications',
        value: '$total Apps',
        subtitle: 'All Consumer Records',
        icon: Icons.folder_shared_outlined,
        color: const Color(0xFF0F3B7A),
        bgColor: const Color(0xFFEFF6FF),
        isSelected: _currentTab == MsedclViewTab.all,
        onTap: () => setState(() => _currentTab = MsedclViewTab.all),
      ),
      _MetricCard(
        title: 'Documents Pending',
        value: '$pendingDocs Apps',
        subtitle: '7/12, Tax, Sale Deed',
        icon: Icons.pending_actions_rounded,
        color: const Color(0xFFD97706),
        bgColor: const Color(0xFFFFFBEB),
        isSelected: _currentTab == MsedclViewTab.pendingDocs,
        onTap: () => setState(() => _currentTab = MsedclViewTab.pendingDocs),
      ),
      _MetricCard(
        title: 'MSEDCL Processing',
        value: '$submitted Apps',
        subtitle: 'Submitted at Circle Office',
        icon: Icons.sync_problem_rounded,
        color: const Color(0xFF4F46E5),
        bgColor: const Color(0xFFEEF2FF),
        isSelected: _currentTab == MsedclViewTab.processing,
        onTap: () => setState(() => _currentTab = MsedclViewTab.processing),
      ),
      _MetricCard(
        title: 'Name Changed / Approved',
        value: '$approved Apps',
        subtitle: 'Order Issued by MSEDCL',
        icon: Icons.verified_user_rounded,
        color: const Color(0xFF047857),
        bgColor: const Color(0xFFECFDF5),
        isSelected: _currentTab == MsedclViewTab.completed,
        onTap: () => setState(() => _currentTab = MsedclViewTab.completed),
      ),
      _MetricCard(
        title: 'Active Sub-Divisions',
        value: '$subDivCount Offices',
        subtitle: 'Nardana, Shindkheda, Dhule',
        icon: Icons.location_city_outlined,
        color: const Color(0xFF0D9488),
        bgColor: const Color(0xFFF0FDFA),
      ),
    ];

    if (isMobile) {
      return SizedBox(
        height: 102,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: cards.length,
          separatorBuilder: (_, index) => const SizedBox(width: 8),
          itemBuilder: (_, i) => SizedBox(width: 175, child: cards[i]),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final crossCount = constraints.maxWidth > 1200 ? 5 : (constraints.maxWidth > 700 ? 3 : 2);
        final rows = <Widget>[];
        for (int i = 0; i < cards.length; i += crossCount) {
          final chunk = cards.sublist(i, (i + crossCount < cards.length) ? i + crossCount : cards.length);
          rows.add(
            Row(
              children: chunk
                  .map((c) => Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 4.0), child: c)))
                  .toList(),
            ),
          );
          if (i + crossCount < cards.length) rows.add(const SizedBox(height: 8));
        }
        return Column(children: rows);
      },
    );
  }

  // ==========================================
  // FILTERS TOOLBAR
  // ==========================================

  Widget _buildFiltersToolbar(ThemeData theme, bool isMobile) {
    final staffList = _allApplications.map((a) => a.assignedEmployee).where((e) => e.isNotEmpty).toSet().toList();

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
        child: Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 12,
          runSpacing: 8,
          children: [
            // Search Input
            SizedBox(
              width: isMobile ? double.infinity : 220,
              height: 38,
              child: TextField(
                controller: _searchCtrl,
                decoration: InputDecoration(
                  hintText: 'Search Name / Consumer No...',
                  prefixIcon: const Icon(Icons.search, size: 18),
                  suffixIcon: _searchCtrl.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 16),
                          onPressed: () {
                            _searchCtrl.clear();
                            setState(() {});
                          },
                        )
                      : null,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),

            // Status Filter Dropdown
            SizedBox(
              width: isMobile ? double.infinity : 175,
              height: 38,
              child: DropdownButtonFormField<String>(
                value: _selectedStatusFilter,
                decoration: InputDecoration(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  prefixIcon: const Icon(Icons.flag_outlined, size: 18),
                ),
                items: [
                  const DropdownMenuItem(value: 'All', child: Text('All Statuses')),
                  ...MsedclApplicationStatus.all.map((s) => DropdownMenuItem(value: s, child: Text(s))),
                ],
                onChanged: (val) {
                  if (val != null) setState(() => _selectedStatusFilter = val);
                },
              ),
            ),

            // Sub-Division Filter
            SizedBox(
              width: isMobile ? double.infinity : 180,
              height: 38,
              child: DropdownButtonFormField<String>(
                value: _selectedSubDivisionFilter,
                decoration: InputDecoration(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  prefixIcon: const Icon(Icons.domain_outlined, size: 18),
                ),
                items: subDivisions.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _selectedSubDivisionFilter = val);
                },
              ),
            ),

            // Assigned Staff Filter
            SizedBox(
              width: isMobile ? double.infinity : 150,
              height: 38,
              child: DropdownButtonFormField<String>(
                value: _selectedEmployeeFilter,
                decoration: InputDecoration(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  prefixIcon: const Icon(Icons.person_outline, size: 18),
                ),
                items: [
                  const DropdownMenuItem(value: 'All', child: Text('All Staff')),
                  ...staffList.map((e) => DropdownMenuItem(value: e, child: Text(e))),
                ],
                onChanged: (val) {
                  if (val != null) setState(() => _selectedEmployeeFilter = val);
                },
              ),
            ),

            // Date Range Picker
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              icon: const Icon(Icons.date_range_outlined, size: 16),
              label: Text(
                _filterStartDate == null
                    ? 'Date Filter'
                    : '${_dateFormat.format(_filterStartDate!)} - ${_filterEndDate != null ? _dateFormat.format(_filterEndDate!) : ""}',
                style: const TextStyle(fontSize: 12),
              ),
              onPressed: () async {
                final picked = await showDateRangePicker(
                  context: context,
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2035),
                  initialDateRange: _filterStartDate != null && _filterEndDate != null
                      ? DateTimeRange(start: _filterStartDate!, end: _filterEndDate!)
                      : null,
                );
                if (picked != null) {
                  setState(() {
                    _filterStartDate = picked.start;
                    _filterEndDate = picked.end;
                  });
                }
              },
            ),

            if (_searchCtrl.text.isNotEmpty ||
                _selectedStatusFilter != 'All' ||
                _selectedSubDivisionFilter != 'All' ||
                _selectedEmployeeFilter != 'All' ||
                _filterStartDate != null)
              TextButton.icon(
                icon: const Icon(Icons.clear_all, size: 16),
                label: const Text('Reset'),
                onPressed: _resetFilters,
              ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // TAB SELECTOR
  // ==========================================

  Widget _buildTabSelector(ThemeData theme, int pendingCount, int processingCount, int approvedCount) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SegmentedButton<MsedclViewTab>(
        segments: [
          ButtonSegment(
            value: MsedclViewTab.all,
            icon: const Icon(Icons.list_alt_rounded, size: 16),
            label: Text('All Applications (${_allApplications.length})'),
          ),
          ButtonSegment(
            value: MsedclViewTab.pendingDocs,
            icon: const Icon(Icons.pending_actions_rounded, size: 16),
            label: Text('Documents Pending ($pendingCount)'),
          ),
          ButtonSegment(
            value: MsedclViewTab.processing,
            icon: const Icon(Icons.sync_rounded, size: 16),
            label: Text('MSEDCL Processing ($processingCount)'),
          ),
          ButtonSegment(
            value: MsedclViewTab.completed,
            icon: const Icon(Icons.check_circle_outline_rounded, size: 16),
            label: Text('Completed & Approved ($approvedCount)'),
          ),
        ],
        selected: {_currentTab},
        onSelectionChanged: (set) {
          setState(() => _currentTab = set.first);
        },
      ),
    );
  }

  // ==========================================
  // APPLICATIONS TABLE
  // ==========================================

  Widget _buildApplicationsTable(ThemeData theme, List<MsedclChangeOfNameApplication> applications, bool isMobile) {
    if (applications.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.assignment_late_outlined, size: 56, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            const Text('No Name Change Applications Found', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text(
              _allApplications.isEmpty
                  ? 'Click "+ New Name Change App" to create your first application.'
                  : 'No applications match your search or filter criteria.',
              style: TextStyle(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 12),
            if (_allApplications.isNotEmpty)
              OutlinedButton(onPressed: _resetFilters, child: const Text('Reset All Filters'))
            else
              FilledButton.icon(
                icon: const Icon(Icons.add),
                label: const Text('+ Create First Application'),
                onPressed: () => _openAddEditApplicationDialog(),
              ),
          ],
        ),
      );
    }

    if (isMobile) {
      return ListView.separated(
        itemCount: applications.length,
        separatorBuilder: (_, index) => const SizedBox(height: 8),
        itemBuilder: (_, i) => _buildMobileApplicationCard(theme, applications[i]),
      );
    }

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SingleChildScrollView(
          child: DataTable(
            showCheckboxColumn: false,
            headingRowColor: WidgetStateProperty.all(const Color(0xFF0F3B7A).withOpacity(0.08)),
            columns: const [
              DataColumn(label: Text('Sr.', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('App No. & Date', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Consumer No.', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Old Consumer (Transferor)', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('New Consumer (Transferee)', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Sub-Division / Village', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Reason for Transfer', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Docs Received', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('PDF Documents', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F3B7A)))),
              DataColumn(label: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold))),
            ],
            rows: List.generate(applications.length, (idx) {
              final a = applications[idx];
              final statusColor = _getStatusColor(a.status);
              final statusBg = statusColor.withOpacity(0.12);

              return DataRow(
                onSelectChanged: (_) => _openViewApplicationDialog(a),
                cells: [
                  DataCell(Text('${idx + 1}')),
                  DataCell(Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(a.applicationNo, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                      Text(_dateFormat.format(a.applicationDate), style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                    ],
                  )),
                  DataCell(Text(a.consumerNo, style: const TextStyle(fontWeight: FontWeight.w600))),
                  DataCell(Text(a.computedOldFullName, style: const TextStyle(fontWeight: FontWeight.w500))),
                  DataCell(Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircleAvatar(
                        radius: 11,
                        backgroundColor: Colors.blue.shade100,
                        child: Text(
                          a.newFirstName.isNotEmpty ? a.newFirstName[0].toUpperCase() : 'N',
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.blue.shade900),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(a.computedNewFullName, style: const TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  )),
                  DataCell(Text('${a.subDivisionOffice} ${a.village.isNotEmpty ? "(${a.village})" : ""}')),
                  DataCell(SizedBox(
                    width: 140,
                    child: Text(a.reasonForChange, overflow: TextOverflow.ellipsis, maxLines: 1),
                  )),
                  DataCell(Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: a.receivedDocCount == a.applicableDocCount ? Colors.green.shade50 : Colors.amber.shade50,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: a.receivedDocCount == a.applicableDocCount ? Colors.green.shade400 : Colors.amber.shade400,
                      ),
                    ),
                    child: Text(
                      '${a.receivedDocCount} / ${a.applicableDocCount} Docs',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: a.receivedDocCount == a.applicableDocCount ? Colors.green.shade900 : Colors.amber.shade900,
                      ),
                    ),
                  )),
                  DataCell(Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: statusBg,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: statusColor),
                    ),
                    child: Text(
                      a.status,
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: statusColor),
                    ),
                  )),
                  DataCell(
                    ElevatedButton.icon(
                      icon: const Icon(Icons.picture_as_pdf_rounded, size: 14, color: Colors.white),
                      label: const Text('Generate PDFs', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0F3B7A),
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      ),
                      onPressed: () => _openDocumentGeneratorDialog(a),
                    ),
                  ),
                  DataCell(Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.visibility_outlined, size: 18, color: Color(0xFF0F3B7A)),
                        tooltip: 'View Application Details',
                        onPressed: () => _openViewApplicationDialog(a),
                      ),
                      IconButton(
                        icon: const Icon(Icons.timeline_rounded, size: 18, color: Color(0xFF4F46E5)),
                        tooltip: 'Status History',
                        onPressed: () => _openStatusHistoryDialog(a),
                      ),
                      IconButton(
                        icon: const Icon(Icons.edit_outlined, size: 18, color: Colors.blueGrey),
                        tooltip: 'Edit Application',
                        onPressed: () => _openAddEditApplicationDialog(existing: a),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                        tooltip: 'Delete',
                        onPressed: () => _deleteApplication(a),
                      ),
                    ],
                  )),
                ],
              );
            }),
          ),
        ),
      ),
    );
  }

  Widget _buildMobileApplicationCard(ThemeData theme, MsedclChangeOfNameApplication a) {
    final statusColor = _getStatusColor(a.status);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => _openViewApplicationDialog(a),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      '${a.applicationNo} • Consumer: ${a.consumerNo}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: statusColor),
                    ),
                    child: Text(
                      a.status,
                      style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text('Old Consumer: ${a.computedOldFullName}', style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
              Text('New Consumer: ${a.computedNewFullName} (${a.newMobileNo})', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              Text('Sub-Division: ${a.subDivisionOffice} • Date: ${_dateFormat.format(a.applicationDate)}', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
              const SizedBox(height: 10),
              Row(
                children: [
                  OutlinedButton.icon(
                    icon: const Icon(Icons.visibility_outlined, size: 14),
                    label: const Text('View', style: TextStyle(fontSize: 11)),
                    style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact),
                    onPressed: () => _openViewApplicationDialog(a),
                  ),
                  const SizedBox(width: 6),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.picture_as_pdf_rounded, size: 14, color: Colors.white),
                    label: const Text('PDFs', style: TextStyle(fontSize: 11, color: Colors.white)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0F3B7A),
                      visualDensity: VisualDensity.compact,
                    ),
                    onPressed: () => _openDocumentGeneratorDialog(a),
                  ),
                  const SizedBox(width: 6),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.edit_outlined, size: 14),
                    label: const Text('Edit', style: TextStyle(fontSize: 11)),
                    style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact),
                    onPressed: () => _openAddEditApplicationDialog(existing: a),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.timeline_rounded, size: 18, color: Color(0xFF4F46E5)),
                    onPressed: () => _openStatusHistoryDialog(a),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                    onPressed: () => _deleteApplication(a),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case MsedclApplicationStatus.newEntry:
        return Colors.blue;
      case MsedclApplicationStatus.docsPending:
        return Colors.amber.shade800;
      case MsedclApplicationStatus.docsCompleted:
        return Colors.teal;
      case MsedclApplicationStatus.submitted:
        return Colors.indigo;
      case MsedclApplicationStatus.msedclProcessing:
        return Colors.purple;
      case MsedclApplicationStatus.objectionRaised:
        return Colors.deepOrange;
      case MsedclApplicationStatus.approved:
      case MsedclApplicationStatus.nameChanged:
        return const Color(0xFF047857); // Green
      case MsedclApplicationStatus.rejected:
        return Colors.red;
      default:
        return Colors.blueGrey;
    }
  }
}

// ==========================================
// METRIC CARD WIDGET
// ==========================================

class _MetricCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color color;
  final Color bgColor;
  final bool isSelected;
  final VoidCallback? onTap;

  const _MetricCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.bgColor,
    this.isSelected = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? color : color.withOpacity(0.3),
            width: isSelected ? 2.0 : 1.0,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: color),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color),
            ),
            Text(
              subtitle,
              style: TextStyle(fontSize: 10, color: Colors.grey.shade700),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// APPLICATION FORM DIALOG (5 Structured Tabs)
// =============================================================================

class _MsedclApplicationFormDialog extends StatefulWidget {
  final MsedclChangeOfNameApplication? existing;
  final ConsumerRecord? preselectedCustomer;
  final List<ConsumerRecord> availableCustomers;
  final Future<MsedclChangeOfNameApplication> Function(MsedclChangeOfNameApplication) onSave;

  const _MsedclApplicationFormDialog({
    this.existing,
    this.preselectedCustomer,
    required this.availableCustomers,
    required this.onSave,
  });

  @override
  State<_MsedclApplicationFormDialog> createState() => _MsedclApplicationFormDialogState();
}

class _MsedclApplicationFormDialogState extends State<_MsedclApplicationFormDialog> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _formKey = GlobalKey<FormState>();

  // 1. Parties Controllers
  final _consumerNoCtrl = TextEditingController();
  final _oldFirstNameCtrl = TextEditingController();
  final _oldFatherHusbandCtrl = TextEditingController();
  final _oldSurnameCtrl = TextEditingController();
  final _oldFullNameCtrl = TextEditingController();
  final _oldMobileCtrl = TextEditingController();
  final _oldMeterNoCtrl = TextEditingController();

  final _newFirstNameCtrl = TextEditingController();
  final _newFatherHusbandCtrl = TextEditingController();
  final _newSurnameCtrl = TextEditingController();
  final _newFullNameCtrl = TextEditingController();
  final _newAgeCtrl = TextEditingController(text: '35');
  final _newMobileCtrl = TextEditingController();
  final _newPhoneCtrl = TextEditingController();
  final _newEmailCtrl = TextEditingController();
  final _newAadhaarCtrl = TextEditingController();
  final _propertyAddressCtrl = TextEditingController();

  final DateFormat _dateFormat = DateFormat('dd/MM/yyyy');

  // 2. Application Meta Controllers
  final _applicationNoCtrl = TextEditingController();
  DateTime _applicationDate = DateTime.now();
  String _subDivisionOffice = 'Nardana Sub-Division';
  String _circleOffice = 'Dhule Circle';
  final _villageCtrl = TextEditingController();
  String _reasonForChange = MsedclReasonForChange.purchaseOfProperty;
  final _assignedEmployeeCtrl = TextEditingController(text: 'Rahul');
  final _remarksCtrl = TextEditingController();
  String _status = MsedclApplicationStatus.newEntry;

  // 3. Stamp Paper Controllers
  double _stampValue = 100.0;
  String _stampLanguage = 'Marathi';
  double _stampTopMarginMm = 80.0;
  final _affidavitPlaceCtrl = TextEditingController(text: 'Dhule');
  final _affidavitCustomTextCtrl = TextEditingController();

  // 4. Form X Controllers
  String _formXOption = 'transfer';
  bool _oldConsumerConsent = true;
  final _refundAccountHolderCtrl = TextEditingController();
  final _refundBankNameCtrl = TextEditingController();
  final _refundBranchCtrl = TextEditingController();
  final _refundAccountNoCtrl = TextEditingController();
  final _refundIfscCtrl = TextEditingController();
  final _originalReceiptNoCtrl = TextEditingController();
  String _receiptStatus = 'Available';
  final _indemnityBondDetailsCtrl = TextEditingController();

  // 5. Annexure A Documents
  List<MsedclDocumentItem> _documents = [];

  int _currentStep = 0;
  bool _isSaving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging && _currentStep != _tabController.index) {
        setState(() {
          _currentStep = _tabController.index;
        });
      }
    });
    _initData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _consumerNoCtrl.dispose();
    _oldFirstNameCtrl.dispose();
    _oldFatherHusbandCtrl.dispose();
    _oldSurnameCtrl.dispose();
    _oldFullNameCtrl.dispose();
    _oldMobileCtrl.dispose();
    _oldMeterNoCtrl.dispose();
    _newFirstNameCtrl.dispose();
    _newFatherHusbandCtrl.dispose();
    _newSurnameCtrl.dispose();
    _newFullNameCtrl.dispose();
    _newAgeCtrl.dispose();
    _newMobileCtrl.dispose();
    _newPhoneCtrl.dispose();
    _newEmailCtrl.dispose();
    _newAadhaarCtrl.dispose();
    _propertyAddressCtrl.dispose();
    _applicationNoCtrl.dispose();
    _villageCtrl.dispose();
    _assignedEmployeeCtrl.dispose();
    _remarksCtrl.dispose();
    _affidavitPlaceCtrl.dispose();
    _affidavitCustomTextCtrl.dispose();
    _refundAccountHolderCtrl.dispose();
    _refundBankNameCtrl.dispose();
    _refundBranchCtrl.dispose();
    _refundAccountNoCtrl.dispose();
    _refundIfscCtrl.dispose();
    _originalReceiptNoCtrl.dispose();
    _indemnityBondDetailsCtrl.dispose();
    super.dispose();
  }

  void _goToPreviousStep() {
    if (_currentStep > 0) {
      setState(() {
        _errorMessage = null;
        _currentStep = _currentStep - 1;
      });
      _tabController.animateTo(_currentStep);
    }
  }

  void _goToNextStep() {
    setState(() => _errorMessage = null);

    // Validation when advancing from Step 1 (Customer Details)
    if (_currentStep == 0) {
      if (!_formKey.currentState!.validate()) {
        return;
      }
      if (_consumerNoCtrl.text.trim().isEmpty) {
        setState(() => _errorMessage = 'Consumer Number is required (ग्राहक क्रमांक आवश्यक आहे).');
        return;
      }
      if (_oldFullNameCtrl.text.trim().isEmpty) {
        setState(() => _errorMessage = 'Old Consumer Full Name is required (माजी ग्राहकाचे नाव आवश्यक आहे).');
        return;
      }
      if (_newFullNameCtrl.text.trim().isEmpty) {
        setState(() => _errorMessage = 'New Consumer Full Name is required (नवीन ग्राहकाचे नाव आवश्यक आहे).');
        return;
      }
      if (_newMobileCtrl.text.trim().isEmpty) {
        setState(() => _errorMessage = 'New Consumer Mobile Number is required (नवीन ग्राहकाचा मोबाईल क्र. आवश्यक आहे).');
        return;
      }
      if (_propertyAddressCtrl.text.trim().isEmpty) {
        setState(() => _errorMessage = 'Property Address is required (पत्ता आवश्यक आहे).');
        return;
      }
    } else if (_currentStep == 1) {
      // Step 2 validation
      if (_applicationNoCtrl.text.trim().isEmpty) {
        setState(() => _errorMessage = 'Application Number is required (अर्ज क्रमांक आवश्यक आहे).');
        return;
      }
    }

    if (_currentStep < 4) {
      setState(() {
        _currentStep = _currentStep + 1;
      });
      _tabController.animateTo(_currentStep);
    }
  }

  String _getStepTitle(int step) {
    switch (step) {
      case 0:
        return 'Customer Details';
      case 1:
        return 'Application Meta';
      case 2:
        return 'Stamp Paper';
      case 3:
        return 'Form X (Deposit)';
      case 4:
        return 'Annexure A (Submit)';
      default:
        return '';
    }
  }

  void _initData() {
    if (widget.existing != null) {
      final e = widget.existing!;
      _applicationNoCtrl.text = e.applicationNo;
      _applicationDate = e.applicationDate;
      _subDivisionOffice = e.subDivisionOffice;
      _circleOffice = e.circleOffice;
      _villageCtrl.text = e.village;
      _reasonForChange = e.reasonForChange;
      _assignedEmployeeCtrl.text = e.assignedEmployee;
      _remarksCtrl.text = e.remarks;
      _status = e.status;

      _consumerNoCtrl.text = e.consumerNo;
      _oldFirstNameCtrl.text = e.oldFirstName;
      _oldFatherHusbandCtrl.text = e.oldFatherOrHusbandName;
      _oldSurnameCtrl.text = e.oldSurname;
      _oldFullNameCtrl.text = e.oldConsumerFullName;
      _oldMobileCtrl.text = e.oldMobileNo;
      _oldMeterNoCtrl.text = e.oldMeterNo;

      _newFirstNameCtrl.text = e.newFirstName;
      _newFatherHusbandCtrl.text = e.newFatherOrHusbandName;
      _newSurnameCtrl.text = e.newSurname;
      _newFullNameCtrl.text = e.newConsumerFullName;
      _newAgeCtrl.text = e.newAge.toString();
      _newMobileCtrl.text = e.newMobileNo;
      _newPhoneCtrl.text = e.newPhoneNo;
      _newEmailCtrl.text = e.newEmail;
      _newAadhaarCtrl.text = e.newAadhaarNo;
      _propertyAddressCtrl.text = e.propertyAddress;

      _stampValue = e.stampPaperValue;
      _stampLanguage = e.stampPaperLanguage;
      _stampTopMarginMm = e.stampTopMarginMm;
      _affidavitPlaceCtrl.text = e.affidavitPlace;
      _affidavitCustomTextCtrl.text = e.affidavitCustomText ?? '';

      _formXOption = e.formXOption;
      _oldConsumerConsent = e.oldConsumerConsent;
      _refundAccountHolderCtrl.text = e.refundAccountHolderName;
      _refundBankNameCtrl.text = e.refundBankName;
      _refundBranchCtrl.text = e.refundBranch;
      _refundAccountNoCtrl.text = e.refundAccountNumber;
      _refundIfscCtrl.text = e.refundIfscCode;
      _originalReceiptNoCtrl.text = e.originalReceiptNo;
      _receiptStatus = e.receiptStatus;
      _indemnityBondDetailsCtrl.text = e.indemnityBondDetails;

      _documents = List.from(e.documents);
    } else {
      _applicationNoCtrl.text = MsedclChangeOfNameService.generateNextApplicationNo();
      _documents = MsedclDocumentType.all.map((t) => MsedclDocumentItem(docType: t)).toList();

      if (widget.preselectedCustomer != null) {
        _applyCustomer(widget.preselectedCustomer!);
      }
    }
  }

  void _applyCustomer(ConsumerRecord c) {
    _consumerNoCtrl.text = c.consumerNo;
    _oldFullNameCtrl.text = c.name;
    final parts = c.name.trim().split(' ');
    if (parts.isNotEmpty) _oldFirstNameCtrl.text = parts.first;
    if (parts.length > 2) {
      _oldFatherHusbandCtrl.text = parts.sublist(1, parts.length - 1).join(' ');
      _oldSurnameCtrl.text = parts.last;
    } else if (parts.length == 2) {
      _oldSurnameCtrl.text = parts.last;
    }
    _oldMobileCtrl.text = c.mobile ?? '';
    _villageCtrl.text = c.village ?? '';
    _propertyAddressCtrl.text = c.address ?? c.village ?? '';
    if (c.village != null && c.village!.isNotEmpty) {
      final v = c.village!.toLowerCase();
      if (v.contains('nardana')) {
        _subDivisionOffice = 'Nardana Sub-Division';
      } else if (v.contains('shindkheda')) {
        _subDivisionOffice = 'Shindkheda Sub-Division';
      } else if (v.contains('shirpur')) {
        _subDivisionOffice = 'Shirpur Sub-Division';
      }
    }
    setState(() {});
  }

  void _computeNewFullName() {
    final parts = [_newFirstNameCtrl.text.trim(), _newFatherHusbandCtrl.text.trim(), _newSurnameCtrl.text.trim()]
        .where((p) => p.isNotEmpty)
        .toList();
    _newFullNameCtrl.text = parts.join(' ');
  }

  void _computeOldFullName() {
    final parts = [_oldFirstNameCtrl.text.trim(), _oldFatherHusbandCtrl.text.trim(), _oldSurnameCtrl.text.trim()]
        .where((p) => p.isNotEmpty)
        .toList();
    _oldFullNameCtrl.text = parts.join(' ');
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      _tabController.animateTo(0);
      return;
    }

    if (_consumerNoCtrl.text.trim().isEmpty) {
      setState(() => _errorMessage = 'Consumer Number is required.');
      _tabController.animateTo(0);
      return;
    }

    if (_newFullNameCtrl.text.trim().isEmpty) {
      setState(() => _errorMessage = 'New Consumer Name is required.');
      _tabController.animateTo(0);
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      final app = MsedclChangeOfNameApplication(
        id: widget.existing?.id ?? '',
        applicationNo: _applicationNoCtrl.text.trim(),
        applicationDate: _applicationDate,
        subDivisionOffice: _subDivisionOffice,
        circleOffice: _circleOffice,
        village: _villageCtrl.text.trim(),
        reasonForChange: _reasonForChange,
        assignedEmployee: _assignedEmployeeCtrl.text.trim(),
        remarks: _remarksCtrl.text.trim(),
        status: _status,
        statusHistory: widget.existing?.statusHistory ?? [],
        oldFirstName: _oldFirstNameCtrl.text.trim(),
        oldFatherOrHusbandName: _oldFatherHusbandCtrl.text.trim(),
        oldSurname: _oldSurnameCtrl.text.trim(),
        oldConsumerFullName: _oldFullNameCtrl.text.trim(),
        consumerNo: _consumerNoCtrl.text.trim(),
        oldMobileNo: _oldMobileCtrl.text.trim(),
        oldMeterNo: _oldMeterNoCtrl.text.trim(),
        newFirstName: _newFirstNameCtrl.text.trim(),
        newFatherOrHusbandName: _newFatherHusbandCtrl.text.trim(),
        newSurname: _newSurnameCtrl.text.trim(),
        newConsumerFullName: _newFullNameCtrl.text.trim(),
        newAge: int.tryParse(_newAgeCtrl.text.trim()) ?? 35,
        newMobileNo: _newMobileCtrl.text.trim(),
        newPhoneNo: _newPhoneCtrl.text.trim(),
        newEmail: _newEmailCtrl.text.trim(),
        newAadhaarNo: _newAadhaarCtrl.text.trim(),
        propertyAddress: _propertyAddressCtrl.text.trim(),
        stampPaperValue: _stampValue,
        stampPaperState: 'Maharashtra',
        stampPaperLanguage: _stampLanguage,
        stampTopMarginMm: _stampTopMarginMm,
        affidavitCustomText: _affidavitCustomTextCtrl.text.trim().isNotEmpty ? _affidavitCustomTextCtrl.text.trim() : null,
        affidavitPlace: _affidavitPlaceCtrl.text.trim(),
        formXOption: _formXOption,
        oldConsumerConsent: _oldConsumerConsent,
        refundAccountHolderName: _refundAccountHolderCtrl.text.trim(),
        refundBankName: _refundBankNameCtrl.text.trim(),
        refundBranch: _refundBranchCtrl.text.trim(),
        refundAccountNumber: _refundAccountNoCtrl.text.trim(),
        refundIfscCode: _refundIfscCtrl.text.trim(),
        originalReceiptNo: _originalReceiptNoCtrl.text.trim(),
        receiptStatus: _receiptStatus,
        indemnityBondDetails: _indemnityBondDetailsCtrl.text.trim(),
        documents: _documents,
        createdAt: widget.existing?.createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final saved = await widget.onSave(app);
      if (mounted) Navigator.pop(context, saved);
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSaving = false;
          _errorMessage = e.toString().replaceAll('Exception: ', '');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = Responsive.isMobile(context);
    final isEdit = widget.existing != null;

    return AlertDialog(
      titlePadding: const EdgeInsets.fromLTRB(20, 18, 16, 8),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      actionsPadding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF0F3B7A).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.assignment_turned_in_rounded, color: Color(0xFF0F3B7A), size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isEdit ? 'Edit Name Change Application' : 'New MSEDCL Change of Name Application',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Text(
                  'Step ${_currentStep + 1} of 5: ${_getStepTitle(_currentStep)} • Complete all 5 steps to submit',
                  style: TextStyle(fontSize: 12, color: Colors.blue.shade900, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.pop(context),
            tooltip: 'Close',
          ),
        ],
      ),
      content: SizedBox(
        width: isMobile ? double.maxFinite : 900,
        height: 550,
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              if (_errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(10),
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.shade300),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: Colors.red, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(_errorMessage!, style: const TextStyle(color: Colors.red, fontSize: 13, fontWeight: FontWeight.w500)),
                      ),
                    ],
                  ),
                ),
              ],
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: (_currentStep + 1) / 5.0,
                  backgroundColor: Colors.grey.shade200,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    _currentStep == 4 ? const Color(0xFF047857) : const Color(0xFF0F3B7A),
                  ),
                  minHeight: 4,
                ),
              ),
              const SizedBox(height: 6),
              TabBar(
                controller: _tabController,
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                labelColor: const Color(0xFF0F3B7A),
                unselectedLabelColor: Colors.grey.shade600,
                indicatorColor: const Color(0xFF0F3B7A),
                tabs: const [
                  Tab(icon: Icon(Icons.people_outline, size: 18), text: 'Step 1: Customer Details'),
                  Tab(icon: Icon(Icons.business_outlined, size: 18), text: 'Step 2: Application Meta'),
                  Tab(icon: Icon(Icons.gavel_rounded, size: 18), text: 'Step 3: Stamp Paper'),
                  Tab(icon: Icon(Icons.security_outlined, size: 18), text: 'Step 4: Form X (Deposit)'),
                  Tab(icon: Icon(Icons.attach_file_rounded, size: 18), text: 'Step 5: Annexure A (Submit)'),
                ],
              ),
              const SizedBox(height: 10),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildCustomerDetailsTab(isMobile),
                    _buildApplicationMetaTab(isMobile),
                    _buildStampPaperTab(isMobile),
                    _buildFormXTab(isMobile),
                    _buildDocumentsChecklistTab(isMobile),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        Wrap(
          spacing: 12,
          runSpacing: 8,
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _currentStep == 4 ? Colors.green.shade50 : const Color(0xFF0F3B7A).withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _currentStep == 4 ? Colors.green.shade300 : const Color(0xFF0F3B7A).withOpacity(0.2),
                    ),
                  ),
                  child: Text(
                    'Step ${_currentStep + 1} of 5: ${_getStepTitle(_currentStep)}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: _currentStep == 4 ? const Color(0xFF047857) : const Color(0xFF0F3B7A),
                    ),
                  ),
                ),
              ],
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_currentStep > 0) ...[
                  OutlinedButton.icon(
                    onPressed: _goToPreviousStep,
                    icon: const Icon(Icons.arrow_back, size: 16),
                    label: const Text('Previous (मागे)'),
                  ),
                  const SizedBox(width: 8),
                ],
                if (_currentStep < 4)
                  FilledButton.icon(
                    style: FilledButton.styleFrom(backgroundColor: const Color(0xFF0F3B7A)),
                    onPressed: _goToNextStep,
                    icon: const Icon(Icons.arrow_forward, size: 16),
                    label: Text(
                      _currentStep == 0
                          ? 'Next: Step 2 ➔'
                          : (_currentStep == 1
                              ? 'Next: Step 3 ➔'
                              : (_currentStep == 2 ? 'Next: Step 4 ➔' : 'Next: Step 5 ➔')),
                    ),
                  )
                else
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF047857),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    ),
                    onPressed: _isSaving ? null : _submit,
                    icon: _isSaving
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Icon(Icons.check_circle_outline, size: 18),
                    label: Text(isEdit ? 'Submit Changes' : 'Submit Application (अर्ज सबमिट करा)'),
                  ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  // TAB 1: CUSTOMER DETAILS
  Widget _buildCustomerDetailsTab(bool isMobile) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Autocomplete selector from Customer Master
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.blue.shade50.withOpacity(0.5),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Quick Select from Existing Customer Master:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF0F3B7A))),
                const SizedBox(height: 6),
                Autocomplete<ConsumerRecord>(
                  displayStringForOption: (c) => '${c.name} (${c.consumerNo})',
                  optionsBuilder: (textEditingValue) {
                    final q = textEditingValue.text.trim().toLowerCase();
                    if (q.isEmpty) return const Iterable<ConsumerRecord>.empty();
                    return widget.availableCustomers.where(
                      (c) => c.name.toLowerCase().contains(q) || c.consumerNo.toLowerCase().contains(q),
                    );
                  },
                  onSelected: _applyCustomer,
                  fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                    return TextFormField(
                      controller: controller,
                      focusNode: focusNode,
                      decoration: const InputDecoration(
                        hintText: 'Search by Customer Name or Consumer No...',
                        prefixIcon: Icon(Icons.person_search_outlined),
                        isDense: true,
                        fillColor: Colors.white,
                        filled: true,
                        border: OutlineInputBorder(),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Section A: Old Consumer Details
          const Text('A. OLD CONSUMER DETAILS (हस्तांतरक / जुने वीज ग्राहक)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F3B7A))),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: TextFormField(
                  controller: _consumerNoCtrl,
                  decoration: const InputDecoration(labelText: 'Consumer No. *', border: OutlineInputBorder(), isDense: true),
                  validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: TextFormField(
                  controller: _oldMobileCtrl,
                  decoration: const InputDecoration(labelText: 'Old Consumer Mobile', border: OutlineInputBorder(), isDense: true),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: TextFormField(
                  controller: _oldMeterNoCtrl,
                  decoration: const InputDecoration(labelText: 'Old Meter No.', border: OutlineInputBorder(), isDense: true),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _oldFirstNameCtrl,
                  decoration: const InputDecoration(labelText: 'Old First Name', border: OutlineInputBorder(), isDense: true),
                  onChanged: (_) => _computeOldFullName(),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextFormField(
                  controller: _oldFatherHusbandCtrl,
                  decoration: const InputDecoration(labelText: 'Father / Husband Name', border: OutlineInputBorder(), isDense: true),
                  onChanged: (_) => _computeOldFullName(),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextFormField(
                  controller: _oldSurnameCtrl,
                  decoration: const InputDecoration(labelText: 'Old Surname', border: OutlineInputBorder(), isDense: true),
                  onChanged: (_) => _computeOldFullName(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _oldFullNameCtrl,
            decoration: const InputDecoration(labelText: 'Old Consumer Full Name (Transferor) *', border: OutlineInputBorder(), isDense: true),
            validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
          ),
          const SizedBox(height: 16),

          // Section B: New Consumer Details
          const Text('B. NEW CONSUMER DETAILS (हस्तांतरिती / नवीन ग्राहक)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F3B7A))),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _newFirstNameCtrl,
                  decoration: const InputDecoration(labelText: 'New First Name *', border: OutlineInputBorder(), isDense: true),
                  onChanged: (_) => _computeNewFullName(),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextFormField(
                  controller: _newFatherHusbandCtrl,
                  decoration: const InputDecoration(labelText: 'Father / Husband Name', border: OutlineInputBorder(), isDense: true),
                  onChanged: (_) => _computeNewFullName(),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextFormField(
                  controller: _newSurnameCtrl,
                  decoration: const InputDecoration(labelText: 'New Surname', border: OutlineInputBorder(), isDense: true),
                  onChanged: (_) => _computeNewFullName(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                flex: 3,
                child: TextFormField(
                  controller: _newFullNameCtrl,
                  decoration: const InputDecoration(labelText: 'New Consumer Full Name (Automatic) *', border: OutlineInputBorder(), isDense: true),
                  validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 1,
                child: TextFormField(
                  controller: _newAgeCtrl,
                  decoration: const InputDecoration(labelText: 'Age (Yrs)', border: OutlineInputBorder(), isDense: true),
                  keyboardType: TextInputType.number,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _newMobileCtrl,
                  decoration: const InputDecoration(labelText: 'New Consumer Mobile *', border: OutlineInputBorder(), isDense: true),
                  validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextFormField(
                  controller: _newEmailCtrl,
                  decoration: const InputDecoration(labelText: 'Email Address', border: OutlineInputBorder(), isDense: true),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextFormField(
                  controller: _newAadhaarCtrl,
                  decoration: const InputDecoration(labelText: 'Aadhaar Number (Optional)', border: OutlineInputBorder(), isDense: true),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _propertyAddressCtrl,
            maxLines: 2,
            decoration: const InputDecoration(labelText: 'Complete Property / Installation Address *', border: OutlineInputBorder(), isDense: true),
            validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
          ),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: const Color(0xFF0F3B7A)),
              onPressed: _goToNextStep,
              icon: const Icon(Icons.arrow_forward, size: 16),
              label: const Text('Next: Step 2 - Application Meta ➔'),
            ),
          ),
        ],
      ),
    );
  }

  // TAB 2: APPLICATION META
  Widget _buildApplicationMetaTab(bool isMobile) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _applicationNoCtrl,
                  decoration: const InputDecoration(labelText: 'Application Number *', border: OutlineInputBorder(), isDense: true),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                  icon: const Icon(Icons.calendar_today, size: 16),
                  label: Text('Date: ${_dateFormat.format(_applicationDate)}'),
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _applicationDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2035),
                    );
                    if (picked != null) setState(() => _applicationDate = picked);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _subDivisionOffice,
                  decoration: const InputDecoration(labelText: 'MSEDCL Sub-Division Office *', border: OutlineInputBorder(), isDense: true),
                  items: _MsedclChangeOfNameScreenState.subDivisions
                      .where((s) => s != 'All')
                      .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                      .toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => _subDivisionOffice = val);
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextFormField(
                  controller: _villageCtrl,
                  decoration: const InputDecoration(labelText: 'Village / Location', border: OutlineInputBorder(), isDense: true),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            value: _reasonForChange,
            decoration: const InputDecoration(labelText: 'Reason for Change of Name *', border: OutlineInputBorder(), isDense: true),
            items: MsedclReasonForChange.all.map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
            onChanged: (val) {
              if (val != null) setState(() => _reasonForChange = val);
            },
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _status,
                  decoration: const InputDecoration(labelText: 'Current Workflow Status', border: OutlineInputBorder(), isDense: true),
                  items: MsedclApplicationStatus.all.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => _status = val);
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextFormField(
                  controller: _assignedEmployeeCtrl,
                  decoration: const InputDecoration(labelText: 'Assigned Employee / Staff', border: OutlineInputBorder(), isDense: true),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: _remarksCtrl,
            maxLines: 2,
            decoration: const InputDecoration(labelText: 'Remarks / Case Notes', border: OutlineInputBorder(), isDense: true),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              OutlinedButton.icon(
                onPressed: _goToPreviousStep,
                icon: const Icon(Icons.arrow_back, size: 16),
                label: const Text('⬅ Back to Step 1'),
              ),
              FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: const Color(0xFF0F3B7A)),
                onPressed: _goToNextStep,
                icon: const Icon(Icons.arrow_forward, size: 16),
                label: const Text('Next: Step 3 - Stamp Paper ➔'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // TAB 3: STAMP PAPER / AFFIDAVIT CONFIGURATION
  Widget _buildStampPaperTab(bool isMobile) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFFEFCE8),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFFDE047)),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline, color: Color(0xFF854D0E), size: 18),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Stamp Paper value is admin configurable (not hardcoded). You can print directly onto physical non-judicial e-stamp paper by setting top margin (e.g. 80mm).',
                    style: TextStyle(fontSize: 12, color: Color(0xFF854D0E)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<double>(
                  value: _stampValue,
                  decoration: const InputDecoration(labelText: 'Stamp Paper Value (₹) *', border: OutlineInputBorder(), isDense: true),
                  items: const [
                    DropdownMenuItem(value: 100.0, child: Text('₹ 100 (Standard Non-Judicial)')),
                    DropdownMenuItem(value: 200.0, child: Text('₹ 200 Stamp Paper')),
                    DropdownMenuItem(value: 500.0, child: Text('₹ 500 Stamp Paper')),
                    DropdownMenuItem(value: 50.0, child: Text('₹ 50 Stamp Paper')),
                  ],
                  onChanged: (val) {
                    if (val != null) setState(() => _stampValue = val);
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _stampLanguage,
                  decoration: const InputDecoration(labelText: 'Language *', border: OutlineInputBorder(), isDense: true),
                  items: const [
                    DropdownMenuItem(value: 'Marathi', child: Text('मराठी (Marathi - Official)')),
                    DropdownMenuItem(value: 'English', child: Text('English')),
                  ],
                  onChanged: (val) {
                    if (val != null) setState(() => _stampLanguage = val);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  initialValue: _stampTopMarginMm.toStringAsFixed(0),
                  decoration: const InputDecoration(
                    labelText: 'Top Margin for Physical Stamp (mm)',
                    suffixText: 'mm',
                    helperText: '80mm to print below physical e-stamp header; 0 for plain A4',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  keyboardType: TextInputType.number,
                  onChanged: (v) {
                    final d = double.tryParse(v);
                    if (d != null) _stampTopMarginMm = d;
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextFormField(
                  controller: _affidavitPlaceCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Place of Affidavit',
                    helperText: 'e.g. Dhule, Nardana, Shindkheda',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text('Custom Affidavit Content (Optional - Leave blank to use standard official legal draft):', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
          const SizedBox(height: 6),
          TextFormField(
            controller: _affidavitCustomTextCtrl,
            maxLines: 4,
            decoration: const InputDecoration(
              hintText: 'Enter custom legal clauses or declaration points if required by specific MSEDCL office...',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              OutlinedButton.icon(
                onPressed: _goToPreviousStep,
                icon: const Icon(Icons.arrow_back, size: 16),
                label: const Text('⬅ Back to Step 2'),
              ),
              FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: const Color(0xFF0F3B7A)),
                onPressed: _goToNextStep,
                icon: const Icon(Icons.arrow_forward, size: 16),
                label: const Text('Next: Step 4 - Form X Deposit ➔'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // TAB 4: FORM X (SECURITY DEPOSIT)
  Widget _buildFormXTab(bool isMobile) {
    final isTransfer = _formXOption == 'transfer';

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: RadioListTile<String>(
                  title: const Text('Option A: Transfer Deposit', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  subtitle: const Text('Old consumer consents to transfer SD to new consumer', style: TextStyle(fontSize: 11)),
                  value: 'transfer',
                  groupValue: _formXOption,
                  onChanged: (v) => setState(() => _formXOption = v!),
                ),
              ),
              Expanded(
                child: RadioListTile<String>(
                  title: const Text('Option B: Refund Deposit', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  subtitle: const Text('Old consumer requests refund to their bank account', style: TextStyle(fontSize: 11)),
                  value: 'refund',
                  groupValue: _formXOption,
                  onChanged: (v) => setState(() => _formXOption = v!),
                ),
              ),
            ],
          ),
          const Divider(),
          if (isTransfer) ...[
            CheckboxListTile(
              title: const Text('Old Consumer (Transferor) Consent Given', style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(
                'Consent statement will be printed in Form X allowing ${_newFullNameCtrl.text.isNotEmpty ? _newFullNameCtrl.text : "New Consumer"} to retain existing SD.',
              ),
              value: _oldConsumerConsent,
              onChanged: (v) => setState(() => _oldConsumerConsent = v ?? true),
            ),
          ] else ...[
            const Text('Bank Account Details for Refund of Security Deposit (ECS / NEFT):', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F3B7A))),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _refundAccountHolderCtrl,
                    decoration: const InputDecoration(labelText: 'Account Holder Name', border: OutlineInputBorder(), isDense: true),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    controller: _refundBankNameCtrl,
                    decoration: const InputDecoration(labelText: 'Bank Name', border: OutlineInputBorder(), isDense: true),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _refundAccountNoCtrl,
                    decoration: const InputDecoration(labelText: 'Bank Account Number', border: OutlineInputBorder(), isDense: true),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    controller: _refundIfscCtrl,
                    decoration: const InputDecoration(labelText: 'IFSC Code', border: OutlineInputBorder(), isDense: true),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    controller: _refundBranchCtrl,
                    decoration: const InputDecoration(labelText: 'Branch', border: OutlineInputBorder(), isDense: true),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _originalReceiptNoCtrl,
                    decoration: const InputDecoration(labelText: 'Original SD Receipt No.', border: OutlineInputBorder(), isDense: true),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _receiptStatus,
                    decoration: const InputDecoration(labelText: 'Receipt Status', border: OutlineInputBorder(), isDense: true),
                    items: const [
                      DropdownMenuItem(value: 'Available', child: Text('Receipt Available (Enclosed)')),
                      DropdownMenuItem(value: 'Lost', child: Text('Receipt Lost (Indemnity Bond Required)')),
                    ],
                    onChanged: (v) {
                      if (v != null) setState(() => _receiptStatus = v);
                    },
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            OutlinedButton.icon(
              onPressed: _goToPreviousStep,
              icon: const Icon(Icons.arrow_back, size: 16),
              label: const Text('⬅ Back to Step 3'),
            ),
            FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: const Color(0xFF0F3B7A)),
              onPressed: _goToNextStep,
              icon: const Icon(Icons.arrow_forward, size: 16),
              label: const Text('Next: Step 5 - Documents Checklist ➔'),
            ),
          ],
        ),
      ],
    ),
  );
}

  // TAB 5: ANNEXURE A (DOCUMENTS CHECKLIST)
  Widget _buildDocumentsChecklistTab(bool isMobile) {
    return Column(
      children: [
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 6),
            itemCount: _documents.length,
            separatorBuilder: (_, index) => const Divider(height: 1),
            itemBuilder: (ctx, i) {
              final doc = _documents[i];
              return ListTile(
                dense: true,
                title: Text(doc.docType, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                subtitle: doc.fileName != null ? Text('File: ${doc.fileName}', style: TextStyle(color: Colors.blue.shade800, fontSize: 11)) : null,
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Status selector
                    DropdownButton<String>(
                      value: doc.status,
                      underline: const SizedBox(),
                      items: const [
                        DropdownMenuItem(value: 'Received', child: Text('Received ✓', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold))),
                        DropdownMenuItem(value: 'Pending', child: Text('Pending ⏳', style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold))),
                        DropdownMenuItem(value: 'Not Applicable', child: Text('N/A -', style: TextStyle(color: Colors.grey))),
                      ],
                      onChanged: (v) {
                        if (v != null) {
                          setState(() {
                            _documents[i] = doc.copyWith(status: v);
                          });
                        }
                      },
                    ),
                    const SizedBox(width: 6),
                    // Attachment button
                    IconButton(
                      icon: Icon(doc.fileName != null ? Icons.check_circle : Icons.upload_file_outlined,
                          size: 18, color: doc.fileName != null ? Colors.green : Colors.blueGrey),
                      tooltip: 'Attach Document',
                      onPressed: () async {
                        final result = await FilePicker.platform.pickFiles(
                          type: FileType.custom,
                          allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
                          withData: true,
                        );
                        if (result != null && result.files.isNotEmpty) {
                          final f = result.files.first;
                          final base64 = f.bytes != null ? base64Encode(f.bytes!) : null;
                          setState(() {
                            _documents[i] = doc.copyWith(
                              fileName: f.name,
                              fileBytesBase64: base64,
                              status: 'Received',
                              uploadedAt: DateTime.now(),
                            );
                          });
                        }
                      },
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: Colors.grey.shade200)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              OutlinedButton.icon(
                onPressed: _goToPreviousStep,
                icon: const Icon(Icons.arrow_back, size: 16),
                label: const Text('⬅ Back to Step 4'),
              ),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF047857),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
                onPressed: _isSaving ? null : _submit,
                icon: _isSaving
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.check_circle_outline, size: 18),
                label: Text(widget.existing != null ? 'Submit & Save Changes' : 'Submit Application (अर्ज सबमिट करा)'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// =============================================================================
// DOCUMENT GENERATOR DIALOG (8 Direct Actions)
// =============================================================================

class _MsedclDocumentGeneratorDialog extends StatefulWidget {
  final MsedclChangeOfNameApplication application;

  const _MsedclDocumentGeneratorDialog({required this.application});

  @override
  State<_MsedclDocumentGeneratorDialog> createState() => _MsedclDocumentGeneratorDialogState();
}

class _MsedclDocumentGeneratorDialogState extends State<_MsedclDocumentGeneratorDialog> {
  bool _isGenerating = false;
  String _activeDocName = 'Complete Master Application';
  Uint8List? _previewBytes;

  @override
  void initState() {
    super.initState();
    _loadCompletePdfPreview();
  }

  Future<void> _loadCompletePdfPreview() async {
    setState(() => _isGenerating = true);
    try {
      final bytes = await MsedclPdfService.generateCompleteApplicationPdf(widget.application);
      if (mounted) {
        setState(() {
          _previewBytes = bytes;
          _activeDocName = 'Complete Application PDF';
          _isGenerating = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  Future<void> _previewDoc(String title, Future<Uint8List> Function() generator) async {
    setState(() => _isGenerating = true);
    try {
      final bytes = await generator();
      if (mounted) {
        setState(() {
          _activeDocName = title;
          _previewBytes = bytes;
          _isGenerating = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  Future<void> _downloadDoc(String fileName, Future<Uint8List> Function() generator) async {
    try {
      final bytes = await generator();
      final path = await saveFileUniversal(
        bytes: bytes,
        fileName: fileName,
        dialogTitle: 'Download $fileName',
      );
      if (mounted && path != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Downloaded "$fileName" successfully!'), backgroundColor: const Color(0xFF047857)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to download: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = widget.application;
    final isMobile = Responsive.isMobile(context);

    return AlertDialog(
      titlePadding: const EdgeInsets.fromLTRB(20, 16, 16, 8),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      actionsPadding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      title: Row(
        children: [
          const Icon(Icons.picture_as_pdf_rounded, color: Color(0xFF0F3B7A), size: 24),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Document Generator — ${app.applicationNo}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                Text('Consumer: ${app.consumerNo} • ${app.computedNewFullName}', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
              ],
            ),
          ),
          IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
        ],
      ),
      content: SizedBox(
        width: isMobile ? double.maxFinite : 920,
        height: 600,
        child: Column(
          children: [
            // Generator action buttons bar (Buttons 1 to 5)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _DocActionButton(
                    icon: Icons.description_outlined,
                    label: '1. Form U PDF',
                    isSelected: _activeDocName.contains('Form U'),
                    onPreview: () => _previewDoc('MSEDCL Form U', () => MsedclPdfService.generateUFormPdf(app)),
                    onDownload: () => _downloadDoc('MSEDCL_Form_U_${app.consumerNo}.pdf', () => MsedclPdfService.generateUFormPdf(app)),
                  ),
                  const SizedBox(width: 6),
                  _DocActionButton(
                    icon: Icons.gavel_rounded,
                    label: '2. Stamp Affidavit',
                    isSelected: _activeDocName.contains('Affidavit'),
                    onPreview: () => _previewDoc('Stamp Paper Affidavit', () => MsedclPdfService.generateAffidavitPdf(app)),
                    onDownload: () => _downloadDoc('MSEDCL_Affidavit_${app.consumerNo}.pdf', () => MsedclPdfService.generateAffidavitPdf(app)),
                  ),
                  const SizedBox(width: 6),
                  _DocActionButton(
                    icon: Icons.security_outlined,
                    label: '3. Form X PDF',
                    isSelected: _activeDocName.contains('Form X'),
                    onPreview: () => _previewDoc('MSEDCL Form X', () => MsedclPdfService.generateFormXPdf(app)),
                    onDownload: () => _downloadDoc('MSEDCL_Form_X_${app.consumerNo}.pdf', () => MsedclPdfService.generateFormXPdf(app)),
                  ),
                  const SizedBox(width: 6),
                  _DocActionButton(
                    icon: Icons.checklist_rtl_rounded,
                    label: '4. Checklist PDF',
                    isSelected: _activeDocName.contains('Checklist'),
                    onPreview: () => _previewDoc('Document Checklist', () => MsedclPdfService.generateChecklistPdf(app)),
                    onDownload: () => _downloadDoc('MSEDCL_Checklist_${app.consumerNo}.pdf', () => MsedclPdfService.generateChecklistPdf(app)),
                  ),
                  const SizedBox(width: 6),
                  _DocActionButton(
                    icon: Icons.layers_rounded,
                    label: '5. Complete App PDF',
                    isSelected: _activeDocName.contains('Complete'),
                    isHighlight: true,
                    onPreview: () => _previewDoc('Complete Application PDF', () => MsedclPdfService.generateCompleteApplicationPdf(app)),
                    onDownload: () => _downloadDoc('MSEDCL_Complete_Application_${app.consumerNo}.pdf', () => MsedclPdfService.generateCompleteApplicationPdf(app)),
                  ),
                ],
              ),
            ),
            const Divider(),

            // Live PDF Viewer Area
            Expanded(
              child: _isGenerating
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 12),
                          Text('Generating document PDF...'),
                        ],
                      ),
                    )
                  : _previewBytes != null
                      ? PdfPreview(
                          build: (format) => _previewBytes!,
                          canChangeOrientation: false,
                          canChangePageFormat: false,
                          canDebug: false,
                          allowPrinting: true,
                          allowSharing: true,
                          actions: [
                            PdfPreviewAction(
                              icon: const Icon(Icons.download),
                              onPressed: (ctx, build, format) async {
                                final cleanName = _activeDocName.replaceAll(' ', '_');
                                await saveFileUniversal(
                                  bytes: _previewBytes!,
                                  fileName: '${cleanName}_${app.consumerNo}.pdf',
                                );
                              },
                            ),
                          ],
                        )
                      : const Center(child: Text('Click on any document button above to generate and preview.')),
            ),
          ],
        ),
      ),
      actions: [
        FilledButton.icon(
          icon: const Icon(Icons.print_rounded, size: 18),
          label: const Text('Print Current Doc'),
          style: FilledButton.styleFrom(backgroundColor: const Color(0xFF0F3B7A)),
          onPressed: _previewBytes != null ? () => Printing.layoutPdf(onLayout: (format) async => _previewBytes!) : null,
        ),
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
      ],
    );
  }
}

class _DocActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final bool isHighlight;
  final VoidCallback onPreview;
  final VoidCallback onDownload;

  const _DocActionButton({
    required this.icon,
    required this.label,
    this.isSelected = false,
    this.isHighlight = false,
    required this.onPreview,
    required this.onDownload,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: isHighlight
            ? (isSelected ? const Color(0xFF0F3B7A) : const Color(0xFF0F3B7A).withOpacity(0.12))
            : (isSelected ? Colors.blue.shade100 : Colors.grey.shade100),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isHighlight ? const Color(0xFF0F3B7A) : (isSelected ? Colors.blue : Colors.grey.shade300),
          width: isSelected ? 1.5 : 1.0,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            onTap: onPreview,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Row(
                children: [
                  Icon(icon, size: 15, color: isHighlight && isSelected ? Colors.white : const Color(0xFF0F3B7A)),
                  const SizedBox(width: 4),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: isHighlight && isSelected ? Colors.white : const Color(0xFF0F3B7A),
                    ),
                  ),
                ],
              ),
            ),
          ),
          IconButton(
            icon: Icon(Icons.download, size: 15, color: isHighlight && isSelected ? Colors.white : Colors.blueGrey),
            tooltip: 'Download $label',
            padding: const EdgeInsets.all(4),
            constraints: const BoxConstraints(),
            onPressed: onDownload,
          ),
          const SizedBox(width: 4),
        ],
      ),
    );
  }
}

// =============================================================================
// STATUS TIMELINE & AUDIT HISTORY DIALOG
// =============================================================================

class _MsedclStatusHistoryDialog extends StatefulWidget {
  final MsedclChangeOfNameApplication application;
  final Future<void> Function(String newStatus, String remarks) onStatusUpdated;

  const _MsedclStatusHistoryDialog({
    required this.application,
    required this.onStatusUpdated,
  });

  @override
  State<_MsedclStatusHistoryDialog> createState() => _MsedclStatusHistoryDialogState();
}

class _MsedclStatusHistoryDialogState extends State<_MsedclStatusHistoryDialog> {
  final DateFormat _timeFormat = DateFormat('dd/MM/yyyy hh:mm a');
  final _remarksCtrl = TextEditingController();
  late String _selectedStatus;
  bool _isAdvancing = false;

  @override
  void initState() {
    super.initState();
    _selectedStatus = widget.application.status;
  }

  @override
  void dispose() {
    _remarksCtrl.dispose();
    super.dispose();
  }

  Future<void> _update() async {
    setState(() => _isAdvancing = true);
    try {
      await widget.onStatusUpdated(_selectedStatus, _remarksCtrl.text.trim());
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) setState(() => _isAdvancing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = widget.application;
    final history = app.statusHistory;

    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.timeline_rounded, color: Color(0xFF4F46E5), size: 22),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Status Timeline — ${app.applicationNo}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                Text('Current Status: ${app.status}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 500,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Status advancement box
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.indigo.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.indigo.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Advance Application Status:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    value: _selectedStatus,
                    isDense: true,
                    decoration: const InputDecoration(border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
                    items: MsedclApplicationStatus.all.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                    onChanged: (v) {
                      if (v != null) setState(() => _selectedStatus = v);
                    },
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _remarksCtrl,
                    decoration: const InputDecoration(
                      hintText: 'Remarks / Next Steps...',
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(backgroundColor: const Color(0xFF4F46E5)),
                      onPressed: _isAdvancing ? null : _update,
                      icon: const Icon(Icons.check, size: 14),
                      label: const Text('Update Status'),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            const Text('Status Transition History:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(height: 6),
            Flexible(
              child: history.isEmpty
                  ? const Text('No history recorded yet.', style: TextStyle(color: Colors.grey))
                  : ListView.separated(
                      shrinkWrap: true,
                      itemCount: history.length,
                      separatorBuilder: (_, index) => const Divider(height: 1),
                      itemBuilder: (ctx, i) {
                        final h = history[i];
                        return ListTile(
                          dense: true,
                          leading: const Icon(Icons.check_circle_outline, color: Color(0xFF047857), size: 18),
                          title: Text(h.status, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                          subtitle: Text(
                            '${h.remarks.isNotEmpty ? "${h.remarks} • " : ""}By ${h.updatedBy}',
                            style: const TextStyle(fontSize: 11),
                          ),
                          trailing: Text(_timeFormat.format(h.timestamp), style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
      ],
    );
  }
}

// ==============================================================================
// VIEW APPLICATION DETAILS DIALOG (CRUD - READ / VIEW)
// ==============================================================================

class _ViewMsedclApplicationDialog extends StatelessWidget {
  final MsedclChangeOfNameApplication application;
  final VoidCallback onEdit;
  final VoidCallback onStatus;
  final VoidCallback onPdf;
  final VoidCallback onDelete;

  const _ViewMsedclApplicationDialog({
    required this.application,
    required this.onEdit,
    required this.onStatus,
    required this.onPdf,
    required this.onDelete,
  });

  Color _getStatusColor(String status) {
    switch (status) {
      case MsedclApplicationStatus.newEntry:
        return Colors.blue;
      case MsedclApplicationStatus.docsPending:
        return Colors.orange;
      case MsedclApplicationStatus.docsCompleted:
        return Colors.teal;
      case MsedclApplicationStatus.submitted:
        return Colors.indigo;
      case MsedclApplicationStatus.msedclProcessing:
        return Colors.purple;
      case MsedclApplicationStatus.objectionRaised:
        return Colors.deepOrange;
      case MsedclApplicationStatus.approved:
      case MsedclApplicationStatus.nameChanged:
        return const Color(0xFF047857);
      case MsedclApplicationStatus.rejected:
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd/MM/yyyy');
    final timeFormat = DateFormat('dd/MM/yyyy hh:mm a');
    final statusColor = _getStatusColor(application.status);
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 750;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 960,
          maxHeight: MediaQuery.of(context).size.height * 0.92,
        ),
        child: Column(
          children: [
            // TOP HEADER
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: const BoxDecoration(
                color: Color(0xFF0F3B7A),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.description_outlined, color: Colors.white, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              application.applicationNo,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                'Consumer: ${application.consumerNo}',
                                style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w500),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'MSEDCL Change of Name Application Details • Date: ${dateFormat.format(application.applicationDate)}',
                          style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircleAvatar(radius: 4, backgroundColor: statusColor),
                        const SizedBox(width: 6),
                        Text(
                          application.status,
                          style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // SCROLLABLE CONTENT BODY
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. COMPARISON: OLD CONSUMER VS NEW CONSUMER
                    _buildConsumerComparisonCard(isMobile),
                    const SizedBox(height: 16),

                    // 2. APPLICATION & OFFICE DETAILS
                    _buildOfficeDetailsCard(dateFormat),
                    const SizedBox(height: 16),

                    // 3. STAMP PAPER AFFIDAVIT DETAILS
                    _buildStampPaperCard(),
                    const SizedBox(height: 16),

                    // 4. FORM X SECURITY DEPOSIT DETAILS
                    _buildFormXCard(),
                    const SizedBox(height: 16),

                    // 5. ANNEXURE A DOCUMENT CHECKLIST
                    _buildDocumentChecklistCard(),
                    const SizedBox(height: 16),

                    // 6. STATUS HISTORY & AUDIT TRAIL
                    _buildStatusHistoryCard(timeFormat),
                  ],
                ),
              ),
            ),

            // BOTTOM ACTION BAR
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                border: Border(top: BorderSide(color: Colors.grey.shade200)),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton.icon(
                    style: TextButton.styleFrom(foregroundColor: Colors.red),
                    icon: const Icon(Icons.delete_outline, size: 16),
                    label: const Text('Delete'),
                    onPressed: onDelete,
                  ),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        icon: const Icon(Icons.edit_outlined, size: 16),
                        label: const Text('Edit Application'),
                        onPressed: onEdit,
                      ),
                      FilledButton.icon(
                        style: FilledButton.styleFrom(backgroundColor: const Color(0xFF4F46E5)),
                        icon: const Icon(Icons.timeline_rounded, size: 16),
                        label: const Text('Advance Status'),
                        onPressed: onStatus,
                      ),
                      FilledButton.icon(
                        style: FilledButton.styleFrom(backgroundColor: const Color(0xFF0F3B7A)),
                        icon: const Icon(Icons.picture_as_pdf_rounded, size: 16),
                        label: const Text('Generate PDFs'),
                        onPressed: onPdf,
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Close'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 1. Consumer Comparison Card (Old vs New)
  Widget _buildConsumerComparisonCard(bool isMobile) {
    final oldConsumerWidget = Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB), // Warm amber background
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFFDE68A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(color: Colors.amber.shade200, shape: BoxShape.circle),
                child: const Icon(Icons.person_outline, size: 16, color: Color(0xFF92400E)),
              ),
              const SizedBox(width: 8),
              const Text(
                'Old Consumer (माजी ग्राहक / विक्रेता)',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF92400E)),
              ),
            ],
          ),
          const Divider(height: 18),
          _detailItem('Full Name (पूर्ण नाव):', application.computedOldFullName, isBold: true),
          if (application.oldFatherOrHusbandName.isNotEmpty)
            _detailItem('Father / Husband:', application.oldFatherOrHusbandName),
          _detailItem('Consumer No (ग्राहक क्र.):', application.consumerNo),
          if (application.oldMeterNo.isNotEmpty)
            _detailItem('Meter No (मीटर क्र.):', application.oldMeterNo),
          if (application.oldMobileNo.isNotEmpty)
            _detailItem('Mobile No (मोबाईल क्र.):', application.oldMobileNo),
        ],
      ),
    );

    final newConsumerWidget = Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF), // Cool blue background
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFBFDBFE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(color: Colors.blue.shade200, shape: BoxShape.circle),
                child: const Icon(Icons.person, size: 16, color: Color(0xFF1E3A8A)),
              ),
              const SizedBox(width: 8),
              const Text(
                'New Consumer (नवीन ग्राहक / खरेदीदार)',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1E3A8A)),
              ),
            ],
          ),
          const Divider(height: 18),
          _detailItem('Full Name (पूर्ण नाव):', application.computedNewFullName, isBold: true),
          if (application.newFatherOrHusbandName.isNotEmpty)
            _detailItem('Father / Husband:', application.newFatherOrHusbandName),
          _detailItem('Age (वय):', '${application.newAge} वर्षे (Years)'),
          _detailItem('Mobile No (मोबाईल क्र.):', application.newMobileNo, isBold: true),
          if (application.newPhoneNo.isNotEmpty)
            _detailItem('Phone No:', application.newPhoneNo),
          if (application.newEmail.isNotEmpty)
            _detailItem('Email ID:', application.newEmail),
          if (application.newAadhaarNo.isNotEmpty)
            _detailItem('Aadhaar No:', application.newAadhaarNo),
          _detailItem('Property Address (पत्ता):', application.propertyAddress),
        ],
      ),
    );

    return isMobile
        ? Column(
            children: [
              oldConsumerWidget,
              const SizedBox(height: 12),
              newConsumerWidget,
            ],
          )
        : Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: oldConsumerWidget),
              const SizedBox(width: 14),
              Expanded(child: newConsumerWidget),
            ],
          );
  }

  // 2. Office & Application Meta Card
  Widget _buildOfficeDetailsCard(DateFormat dateFormat) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.business_outlined, size: 18, color: Color(0xFF0F3B7A)),
                SizedBox(width: 8),
                Text('Application & MSEDCL Office Details (कार्यालयीन तपशील)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              ],
            ),
            const Divider(height: 18),
            Wrap(
              spacing: 24,
              runSpacing: 10,
              children: [
                _detailColumn('Sub-Division Office:', application.subDivisionOffice),
                _detailColumn('Circle Office:', application.circleOffice),
                if (application.village.isNotEmpty)
                  _detailColumn('Village / Location:', application.village),
                _detailColumn('Reason for Transfer:', application.reasonForChange),
                _detailColumn('Assigned Staff:', application.assignedEmployee),
                _detailColumn('Application Date:', dateFormat.format(application.applicationDate)),
                if (application.remarks.isNotEmpty)
                  _detailColumn('Remarks:', application.remarks),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // 3. Stamp Paper & Affidavit Details Card
  Widget _buildStampPaperCard() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.gavel_rounded, size: 18, color: Color(0xFFD97706)),
                SizedBox(width: 8),
                Text('Stamp Paper Affidavit & Undertaking (स्टॅम्प पेपर प्रतिज्ञापत्र)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              ],
            ),
            const Divider(height: 18),
            Wrap(
              spacing: 24,
              runSpacing: 10,
              children: [
                _detailColumn('Configurable Stamp Value:', '₹ ${application.stampPaperValue.toStringAsFixed(0)}'),
                _detailColumn('State:', application.stampPaperState),
                _detailColumn('Language:', application.stampPaperLanguage),
                _detailColumn('Top Margin for Physical Stamp:', '${application.stampTopMarginMm.toStringAsFixed(0)} mm'),
                _detailColumn('Place of Execution:', application.affidavitPlace),
              ],
            ),
            if (application.affidavitCustomText != null && application.affidavitCustomText!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Text(
                  application.affidavitCustomText!,
                  style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic),
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // 4. Form X Security Deposit Card
  Widget _buildFormXCard() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.account_balance_outlined, size: 18, color: Color(0xFF047857)),
                const SizedBox(width: 8),
                const Text('Form X - Security Deposit (सुरक्षा ठेव हस्तांतरण / परतावा)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: application.isFormXTransfer ? Colors.blue.shade50 : Colors.teal.shade50,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: application.isFormXTransfer ? Colors.blue.shade300 : Colors.teal.shade300),
                  ),
                  child: Text(
                    application.isFormXTransfer ? 'Option A: Transfer of Security Deposit' : 'Option B: Refund of Security Deposit',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: application.isFormXTransfer ? Colors.blue.shade900 : Colors.teal.shade900),
                  ),
                ),
              ],
            ),
            const Divider(height: 18),
            if (application.isFormXTransfer) ...[
              _detailItem('Old Consumer Consent:', application.oldConsumerConsent ? 'Consent Granted (सहमत)' : 'Consent Pending (प्रलंबित)', isBold: true),
              _detailItem('Transferee Name:', application.computedNewFullName),
            ] else ...[
              Wrap(
                spacing: 24,
                runSpacing: 10,
                children: [
                  _detailColumn('A/C Holder Name:', application.refundAccountHolderName),
                  _detailColumn('Bank Name:', application.refundBankName),
                  _detailColumn('Branch:', application.refundBranch),
                  _detailColumn('Account Number:', application.refundAccountNumber),
                  _detailColumn('IFSC Code:', application.refundIfscCode),
                  _detailColumn('Original Receipt No:', application.originalReceiptNo),
                  _detailColumn('Receipt Status:', application.receiptStatus),
                  if (application.indemnityBondDetails.isNotEmpty)
                    _detailColumn('Indemnity Bond:', application.indemnityBondDetails),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  // 5. Annexure A Supporting Documents Checklist Card
  Widget _buildDocumentChecklistCard() {
    final docs = application.documents;
    final receivedCount = application.receivedDocCount;
    final applicableCount = application.applicableDocCount;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.checklist_rtl_rounded, size: 18, color: Color(0xFF0F3B7A)),
                const SizedBox(width: 8),
                const Text('Annexure A - Document Checklist (कागदपत्रे तपासणी यादी)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: receivedCount == applicableCount ? Colors.green.shade50 : Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: receivedCount == applicableCount ? Colors.green.shade400 : Colors.amber.shade400),
                  ),
                  child: Text(
                    '$receivedCount / $applicableCount Documents Received',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: receivedCount == applicableCount ? Colors.green.shade900 : Colors.amber.shade900,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 18),
            if (docs.isEmpty)
              const Text('No documents initialized for this application.', style: TextStyle(color: Colors.grey))
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: docs.length,
                separatorBuilder: (_, index) => const Divider(height: 1),
                itemBuilder: (ctx, i) {
                  final d = docs[i];
                  Color badgeColor = Colors.grey;
                  Color badgeBg = Colors.grey.shade100;
                  if (d.isReceived) {
                    badgeColor = const Color(0xFF047857);
                    badgeBg = Colors.green.shade50;
                  } else if (d.isPending) {
                    badgeColor = Colors.orange.shade800;
                    badgeBg = Colors.orange.shade50;
                  }

                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      children: [
                        Icon(
                          d.isReceived
                              ? Icons.check_circle_rounded
                              : (d.isPending ? Icons.pending_actions_rounded : Icons.remove_circle_outline),
                          size: 16,
                          color: badgeColor,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(d.docType, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                              if (d.fileName != null && d.fileName!.isNotEmpty)
                                Text('File: ${d.fileName}', style: TextStyle(fontSize: 11, color: Colors.blue.shade700)),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: badgeBg,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: badgeColor),
                          ),
                          child: Text(
                            d.status,
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: badgeColor),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  // 6. Status History & Audit Trail Card
  Widget _buildStatusHistoryCard(DateFormat timeFormat) {
    final history = application.statusHistory;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.history_rounded, size: 18, color: Color(0xFF4F46E5)),
                SizedBox(width: 8),
                Text('Workflow & Status Audit History (कार्यप्रवाह इतिहास)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              ],
            ),
            const Divider(height: 18),
            if (history.isEmpty)
              const Text('No status transitions recorded yet.', style: TextStyle(color: Colors.grey, fontSize: 12))
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: history.length,
                separatorBuilder: (_, index) => const Divider(height: 1),
                itemBuilder: (ctx, i) {
                  final h = history[i];
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    leading: const Icon(Icons.check_circle_outline, color: Color(0xFF047857), size: 18),
                    title: Text(h.status, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    subtitle: Text(
                      '${h.remarks.isNotEmpty ? "${h.remarks} • " : ""}Updated by ${h.updatedBy}',
                      style: const TextStyle(fontSize: 11),
                    ),
                    trailing: Text(timeFormat.format(h.timestamp), style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  // Helper widgets for key-value display
  Widget _detailItem(String label, String value, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(label, style: const TextStyle(fontSize: 11.5, color: Colors.black54)),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailColumn(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.black54)),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black87)),
      ],
    );
  }
}
