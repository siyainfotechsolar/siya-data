import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../models/site_team_expense.dart';
import '../models/consumer_record.dart';
import '../services/site_team_expense_service.dart';
import '../services/team_expense_excel_service.dart';
import '../utils/responsive.dart';

class TeamExpenseCalculatorScreen extends StatefulWidget {
  const TeamExpenseCalculatorScreen({super.key});

  @override
  State<TeamExpenseCalculatorScreen> createState() => _TeamExpenseCalculatorScreenState();
}

class _TeamExpenseCalculatorScreenState extends State<TeamExpenseCalculatorScreen> {
  final NumberFormat _currency = NumberFormat.currency(locale: 'en_IN', symbol: '₹ ', decimalDigits: 0);
  final DateFormat _dateFormat = DateFormat('dd/MM/yyyy');

  List<SiteTeamExpense> _allExpenses = [];
  List<ConsumerRecord> _availableConsumers = [];
  bool _isLoading = false;
  bool _isExporting = false;
  String? _errorMessage;

  // Filter controllers & states
  final TextEditingController _searchCtrl = TextEditingController();
  final TextEditingController _consumerNoSearchCtrl = TextEditingController();
  DateTime? _filterStartDate;
  DateTime? _filterEndDate;
  String _selectedTeamFilter = 'All'; // 'All', 'Wiring Team', 'Civil Team', 'Structure Team'

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _consumerNoSearchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final results = await Future.wait([
        SiteTeamExpenseService.fetchExpenses(),
        SiteTeamExpenseService.fetchAvailableCustomers(),
      ]);

      if (mounted) {
        setState(() {
          _allExpenses = results[0] as List<SiteTeamExpense>;
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

  /// Filtered expenses based on Date, Customer Name, Consumer No, and Team filter
  List<SiteTeamExpense> get _filteredExpenses {
    final nameQuery = _searchCtrl.text.trim().toLowerCase();
    final noQuery = _consumerNoSearchCtrl.text.trim().toLowerCase();

    return _allExpenses.where((exp) {
      // 1. Date-wise filter
      if (_filterStartDate != null) {
        final start = DateTime(_filterStartDate!.year, _filterStartDate!.month, _filterStartDate!.day);
        if (exp.expenseDate.isBefore(start)) return false;
      }
      if (_filterEndDate != null) {
        final end = DateTime(_filterEndDate!.year, _filterEndDate!.month, _filterEndDate!.day, 23, 59, 59);
        if (exp.expenseDate.isAfter(end)) return false;
      }

      // 2. Customer Name search
      if (nameQuery.isNotEmpty && !exp.customerName.toLowerCase().contains(nameQuery)) {
        return false;
      }

      // 3. Consumer Number search
      if (noQuery.isNotEmpty && !exp.consumerNo.toLowerCase().contains(noQuery)) {
        return false;
      }

      // 4. Team-wise filter
      if (_selectedTeamFilter == 'Wiring Team' && exp.wiringExpense <= 0) {
        return false;
      }
      if (_selectedTeamFilter == 'Civil Team' && exp.civilExpense <= 0) {
        return false;
      }
      if (_selectedTeamFilter == 'Structure Team' && exp.structureExpense <= 0) {
        return false;
      }

      return true;
    }).toList();
  }

  /// Summary of currently applied filters for the Excel report banner
  String get _filterSummary {
    final parts = <String>[];
    if (_filterStartDate != null || _filterEndDate != null) {
      final s = _filterStartDate != null ? _dateFormat.format(_filterStartDate!) : 'Any';
      final e = _filterEndDate != null ? _dateFormat.format(_filterEndDate!) : 'Any';
      parts.add('Date: $s to $e');
    }
    if (_searchCtrl.text.trim().isNotEmpty) {
      parts.add('Name: "${_searchCtrl.text.trim()}"');
    }
    if (_consumerNoSearchCtrl.text.trim().isNotEmpty) {
      parts.add('Consumer No: "${_consumerNoSearchCtrl.text.trim()}"');
    }
    if (_selectedTeamFilter != 'All') {
      parts.add('Team: $_selectedTeamFilter');
    }
    return parts.isEmpty ? 'All Records (No Filters)' : parts.join(' | ');
  }

  Future<void> _handleExportExcel() async {
    final toExport = _filteredExpenses;
    if (toExport.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No site expense records found matching current filters to export.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isExporting = true);
    try {
      final success = await TeamExpenseExcelService.exportAndSave(
        expenses: toExport,
        filterSummary: _filterSummary,
      );

      if (mounted && success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Excel Report exported successfully! (${toExport.length} sites, 3 sheets)'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to export Excel report: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  void _openAddEditDialog([SiteTeamExpense? existing]) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _AddEditTeamExpenseDialog(
        existing: existing,
        availableConsumers: _availableConsumers,
        allExpenses: _allExpenses,
        onSaved: () {
          _loadData();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                existing == null
                    ? 'Site Team Expense recorded successfully!'
                    : 'Site Team Expense updated successfully!',
              ),
              backgroundColor: Colors.green,
            ),
          );
        },
      ),
    );
  }

  void _openViewDialog(SiteTeamExpense expense) {
    showDialog(
      context: context,
      builder: (ctx) => _ViewTeamExpenseDialog(expense: expense),
    );
  }

  Future<void> _handleDelete(SiteTeamExpense expense) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.delete_outline, color: Colors.red),
            SizedBox(width: 8),
            Text('Delete Team Expense Record'),
          ],
        ),
        content: Text(
          'Are you sure you want to delete the team expense entry for "${expense.customerName}" '
          '(${expense.consumerNo}) totaling ${_currency.format(expense.totalSiteExpense)}?\n\n'
          'This action cannot be undone.',
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
      try {
        await SiteTeamExpenseService.deleteExpense(expense.id);
        _loadData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Team expense record deleted successfully.'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to delete: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  void _resetFilters() {
    setState(() {
      _searchCtrl.clear();
      _consumerNoSearchCtrl.clear();
      _filterStartDate = null;
      _filterEndDate = null;
      _selectedTeamFilter = 'All';
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isMobile = Responsive.isMobile(context);
    final displayed = _filteredExpenses;
    final summary = TeamExpenseSummary.fromExpenses(displayed);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: Padding(
        padding: EdgeInsets.all(isMobile ? 12.0 : 20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Module Header & Action Bar
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.group_work_rounded, size: 28, color: theme.colorScheme.primary),
                          const SizedBox(width: 10),
                          Text(
                            isMobile ? 'Team Expense' : 'Site-Wise Team Expense Calculator',
                            style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(width: 12),
                          Chip(
                            backgroundColor: Colors.blue.shade50,
                            side: BorderSide(color: Colors.blue.shade200),
                            label: Text(
                              '${summary.totalSites} Sites',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue.shade900,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (!isMobile) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Track wiring, civil, and structure team site expenses with automatic customer-wise totals and professional 3-sheet Excel reports.',
                          style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 13),
                        ),
                      ],
                    ],
                  ),
                ),
                Wrap(
                  spacing: 10,
                  children: [
                    // Export to Excel Button
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF107C41), // Official Excel Green
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                      onPressed: _isExporting ? null : _handleExportExcel,
                      icon: _isExporting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.table_view_rounded, size: 18),
                      label: Text(
                        isMobile ? 'Excel' : 'Export to Excel (3 Sheets)',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ),
                    // Add Expense Button
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: theme.colorScheme.primary,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                      onPressed: () => _openAddEditDialog(),
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: Text(
                        isMobile ? 'Add' : 'Add Team Expense',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
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
            const SizedBox(height: 16),

            // SECTION 7: DASHBOARD METRICS CARDS
            _buildDashboardMetricsBar(theme, summary, isMobile),
            const SizedBox(height: 16),

            // SECTION 6: FILTERS & SEARCH TOOLBAR
            _buildFiltersToolbar(theme, isMobile),
            const SizedBox(height: 14),

            // DATA TABLE / LIST
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
                      : displayed.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.inventory_2_outlined, size: 56, color: Colors.grey.shade400),
                                  const SizedBox(height: 12),
                                  const Text(
                                    'No team expense records found',
                                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    _allExpenses.isEmpty
                                        ? 'Click "+ Add Team Expense" to record the first site entry.'
                                        : 'No records match the current filter criteria.',
                                    style: TextStyle(color: Colors.grey.shade600),
                                  ),
                                  if (_allExpenses.isNotEmpty) ...[
                                    const SizedBox(height: 12),
                                    OutlinedButton(
                                      onPressed: _resetFilters,
                                      child: const Text('Reset All Filters'),
                                    ),
                                  ],
                                ],
                              ),
                            )
                          : isMobile
                              ? _buildMobileExpenseList(theme, displayed)
                              : _buildDesktopDataTable(theme, displayed, summary),
            ),
          ],
        ),
      ),
    );
  }

  // =========================================================================
  // SECTION 7: DASHBOARD METRICS CARDS
  // =========================================================================
  Widget _buildDashboardMetricsBar(ThemeData theme, TeamExpenseSummary summary, bool isMobile) {
    final cards = [
      _MetricCard(
        title: 'Total Customers / Sites',
        value: '${summary.totalSites}',
        subtitle: 'Recorded Sites',
        icon: Icons.location_on_outlined,
        color: Colors.blue.shade700,
        bgColor: Colors.blue.shade50,
      ),
      _MetricCard(
        title: 'Wiring Team Expense',
        value: _currency.format(summary.totalWiringExpense),
        subtitle: '${summary.wiringSitesCount} Sites with Wiring',
        icon: Icons.electric_bolt_outlined,
        color: Colors.amber.shade800,
        bgColor: Colors.amber.shade50,
      ),
      _MetricCard(
        title: 'Civil Team Expense',
        value: _currency.format(summary.totalCivilExpense),
        subtitle: '${summary.civilSitesCount} Sites with Civil',
        icon: Icons.foundation_outlined,
        color: Colors.teal.shade800,
        bgColor: Colors.teal.shade50,
      ),
      _MetricCard(
        title: 'Structure Team Expense',
        value: _currency.format(summary.totalStructureExpense),
        subtitle: '${summary.structureSitesCount} Sites with Structure',
        icon: Icons.architecture_outlined,
        color: Colors.purple.shade800,
        bgColor: Colors.purple.shade50,
      ),
      _MetricCard(
        title: 'Grand Total Team Expense',
        value: _currency.format(summary.grandTotalExpense),
        subtitle: 'Wiring + Civil + Structure',
        icon: Icons.account_balance_wallet_rounded,
        color: const Color(0xFF064E3B),
        bgColor: const Color(0xFFD1FAE5),
        isPrimary: true,
      ),
    ];

    if (isMobile) {
      return SizedBox(
        height: 110,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: cards.length,
          separatorBuilder: (context, index) => const SizedBox(width: 10),
          itemBuilder: (context, i) => SizedBox(width: 200, child: cards[i]),
        ),
      );
    }

    return Row(
      children: cards.map((c) => Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: c))).toList(),
    );
  }

  // =========================================================================
  // SECTION 6: FILTERS TOOLBAR
  // =========================================================================
  Widget _buildFiltersToolbar(ThemeData theme, bool isMobile) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                // 1. Customer Name Search
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: _searchCtrl,
                    decoration: InputDecoration(
                      hintText: 'Search by Customer Name...',
                      prefixIcon: const Icon(Icons.person_search_outlined, size: 18),
                      suffixIcon: _searchCtrl.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 16),
                              onPressed: () {
                                _searchCtrl.clear();
                                setState(() {});
                              },
                            )
                          : null,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      isDense: true,
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 10),

                // 2. Consumer Number Search
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: _consumerNoSearchCtrl,
                    decoration: InputDecoration(
                      hintText: 'Search Consumer No...',
                      prefixIcon: const Icon(Icons.numbers_outlined, size: 18),
                      suffixIcon: _consumerNoSearchCtrl.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 16),
                              onPressed: () {
                                _consumerNoSearchCtrl.clear();
                                setState(() {});
                              },
                            )
                          : null,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      isDense: true,
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 10),

                // 3. Team-wise Filter
                Expanded(
                  flex: 2,
                  child: DropdownButtonFormField<String>(
                    // ignore: deprecated_member_use
                    value: _selectedTeamFilter,
                    decoration: InputDecoration(
                      labelText: 'Team Filter',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      isDense: true,
                    ),
                    items: const [
                      DropdownMenuItem(value: 'All', child: Text('All Teams')),
                      DropdownMenuItem(value: 'Wiring Team', child: Text('Wiring Team')),
                      DropdownMenuItem(value: 'Civil Team', child: Text('Civil Team')),
                      DropdownMenuItem(value: 'Structure Team', child: Text('Structure Team')),
                    ],
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedTeamFilter = val);
                    },
                  ),
                ),
                const SizedBox(width: 10),

                // 4. Date Filter Button
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    side: BorderSide(
                      color: (_filterStartDate != null || _filterEndDate != null)
                          ? theme.colorScheme.primary
                          : theme.colorScheme.outlineVariant,
                    ),
                  ),
                  onPressed: _showDateRangePicker,
                  icon: const Icon(Icons.calendar_month_outlined, size: 18),
                  label: Text(
                    (_filterStartDate != null || _filterEndDate != null)
                        ? '${_filterStartDate != null ? _dateFormat.format(_filterStartDate!) : ""} – ${_filterEndDate != null ? _dateFormat.format(_filterEndDate!) : ""}'
                        : 'Date Filter',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),

                if (_searchCtrl.text.isNotEmpty ||
                    _consumerNoSearchCtrl.text.isNotEmpty ||
                    _filterStartDate != null ||
                    _filterEndDate != null ||
                    _selectedTeamFilter != 'All') ...[
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.filter_alt_off_outlined, color: Colors.red),
                    tooltip: 'Reset Filters',
                    onPressed: _resetFilters,
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showDateRangePicker() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      initialDateRange: (_filterStartDate != null && _filterEndDate != null)
          ? DateTimeRange(start: _filterStartDate!, end: _filterEndDate!)
          : null,
    );

    if (picked != null) {
      setState(() {
        _filterStartDate = picked.start;
        _filterEndDate = picked.end;
      });
    }
  }

  // =========================================================================
  // DESKTOP DATA TABLE
  // =========================================================================
  Widget _buildDesktopDataTable(ThemeData theme, List<SiteTeamExpense> expenses, TeamExpenseSummary summary) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SingleChildScrollView(
          child: DataTable(
            headingRowColor: WidgetStateProperty.all(
              theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
            ),
            columns: const [
              DataColumn(label: Text('Sr.', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Customer Name', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Consumer No', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Site Location', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Capacity', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(numeric: true, label: Text('Wiring Team (₹)', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(numeric: true, label: Text('Civil Team (₹)', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(numeric: true, label: Text('Structure Team (₹)', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(numeric: true, label: Text('Total Site Expense (₹)', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF064E3B)))),
              DataColumn(label: Text('Date', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Remarks', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold))),
            ],
            rows: [
              ...expenses.asMap().entries.map((entry) {
                final idx = entry.key;
                final e = entry.value;

                return DataRow(
                  cells: [
                    DataCell(Text('${idx + 1}', style: const TextStyle(fontSize: 12))),
                    DataCell(
                      Text(
                        e.customerName,
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                      ),
                    ),
                    DataCell(Text(e.consumerNo, style: const TextStyle(fontSize: 12))),
                    DataCell(Text(e.siteLocation.isNotEmpty ? e.siteLocation : '—', style: const TextStyle(fontSize: 12))),
                    DataCell(Text(e.solarCapacity.isNotEmpty ? e.solarCapacity : '—', style: const TextStyle(fontSize: 12))),
                    DataCell(
                      Text(
                        _currency.format(e.wiringExpense),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: _selectedTeamFilter == 'Wiring Team' ? Colors.blue.shade900 : null,
                        ),
                      ),
                    ),
                    DataCell(
                      Text(
                        _currency.format(e.civilExpense),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: _selectedTeamFilter == 'Civil Team' ? Colors.teal.shade900 : null,
                        ),
                      ),
                    ),
                    DataCell(
                      Text(
                        _currency.format(e.structureExpense),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: _selectedTeamFilter == 'Structure Team' ? Colors.purple.shade900 : null,
                        ),
                      ),
                    ),
                    DataCell(
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFD1FAE5),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          _currency.format(e.totalSiteExpense),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            color: Color(0xFF064E3B),
                          ),
                        ),
                      ),
                    ),
                    DataCell(Text(e.formattedDate, style: const TextStyle(fontSize: 12))),
                    DataCell(
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 150),
                        child: Text(
                          e.remarks ?? '—',
                          style: const TextStyle(fontSize: 11, color: Colors.grey),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    DataCell(
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.visibility_outlined, size: 18, color: Colors.blue),
                            tooltip: 'View Details',
                            onPressed: () => _openViewDialog(e),
                          ),
                          IconButton(
                            icon: const Icon(Icons.edit_outlined, size: 18, color: Colors.indigo),
                            tooltip: 'Edit Expense',
                            onPressed: () => _openAddEditDialog(e),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                            tooltip: 'Delete',
                            onPressed: () => _handleDelete(e),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              }),

              // Grand Total Row
              DataRow(
                color: WidgetStateProperty.all(const Color(0xFFD1FAE5)),
                cells: [
                  const DataCell(Text('')),
                  const DataCell(Text('GRAND TOTAL', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF064E3B)))),
                  DataCell(Text('${summary.totalSites} Sites', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF064E3B)))),
                  const DataCell(Text('')),
                  const DataCell(Text('')),
                  DataCell(Text(_currency.format(summary.totalWiringExpense), style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF064E3B)))),
                  DataCell(Text(_currency.format(summary.totalCivilExpense), style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF064E3B)))),
                  DataCell(Text(_currency.format(summary.totalStructureExpense), style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF064E3B)))),
                  DataCell(
                    Text(
                      _currency.format(summary.grandTotalExpense),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF064E3B)),
                    ),
                  ),
                  const DataCell(Text('')),
                  const DataCell(Text('')),
                  const DataCell(Text('')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // =========================================================================
  // MOBILE CARD LIST
  // =========================================================================
  Widget _buildMobileExpenseList(ThemeData theme, List<SiteTeamExpense> expenses) {
    return ListView.separated(
      itemCount: expenses.length,
      separatorBuilder: (context, index) => const SizedBox(height: 8),
      itemBuilder: (context, idx) {
        final e = expenses[idx];
        return Card(
          elevation: 1,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
                        e.customerName,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFD1FAE5),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        _currency.format(e.totalSiteExpense),
                        style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF064E3B)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Consumer No: ${e.consumerNo} • ${e.solarCapacity} • ${e.formattedDate}',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
                if (e.siteLocation.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text('Location: ${e.siteLocation}', style: TextStyle(fontSize: 11, color: Colors.grey.shade700)),
                ],
                const Divider(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Wiring: ${_currency.format(e.wiringExpense)}', style: const TextStyle(fontSize: 12)),
                    Text('Civil: ${_currency.format(e.civilExpense)}', style: const TextStyle(fontSize: 12)),
                    Text('Structure: ${_currency.format(e.structureExpense)}', style: const TextStyle(fontSize: 12)),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton.icon(
                      icon: const Icon(Icons.visibility_outlined, size: 14),
                      label: const Text('View', style: TextStyle(fontSize: 11)),
                      style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact),
                      onPressed: () => _openViewDialog(e),
                    ),
                    const SizedBox(width: 6),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.edit_outlined, size: 14),
                      label: const Text('Edit', style: TextStyle(fontSize: 11)),
                      style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact),
                      onPressed: () => _openAddEditDialog(e),
                    ),
                    const SizedBox(width: 6),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, size: 16, color: Colors.red),
                      onPressed: () => _handleDelete(e),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// =============================================================================
// METRIC CARD WIDGET
// =============================================================================
class _MetricCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color color;
  final Color bgColor;
  final bool isPrimary;

  const _MetricCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.bgColor,
    this.isPrimary = false,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: isPrimary ? color.withValues(alpha: 0.5) : Colors.grey.shade300),
      ),
      color: bgColor,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              children: [
                Icon(icon, size: 16, color: color),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isPrimary ? color : Colors.black87,
              ),
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
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
// ADD / EDIT TEAM EXPENSE DIALOG
// =============================================================================
class _AddEditTeamExpenseDialog extends StatefulWidget {
  final SiteTeamExpense? existing;
  final List<ConsumerRecord> availableConsumers;
  final List<SiteTeamExpense> allExpenses;
  final VoidCallback onSaved;

  const _AddEditTeamExpenseDialog({
    this.existing,
    required this.availableConsumers,
    required this.allExpenses,
    required this.onSaved,
  });

  @override
  State<_AddEditTeamExpenseDialog> createState() => _AddEditTeamExpenseDialogState();
}

class _AddEditTeamExpenseDialogState extends State<_AddEditTeamExpenseDialog> {
  final _formKey = GlobalKey<FormState>();
  final NumberFormat _currency = NumberFormat.currency(locale: 'en_IN', symbol: '₹ ', decimalDigits: 0);

  ConsumerRecord? _selectedConsumer;
  late TextEditingController _nameCtrl;
  late TextEditingController _consumerNoCtrl;
  late TextEditingController _locationCtrl;
  late TextEditingController _capacityCtrl;
  late TextEditingController _wiringCtrl;
  late TextEditingController _civilCtrl;
  late TextEditingController _structureCtrl;
  late TextEditingController _remarksCtrl;

  late DateTime _expenseDate;
  bool _isSaving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _expenseDate = e?.expenseDate ?? DateTime.now();

    _nameCtrl = TextEditingController(text: e?.customerName ?? '');
    _consumerNoCtrl = TextEditingController(text: e?.consumerNo ?? '');
    _locationCtrl = TextEditingController(text: e?.siteLocation ?? '');
    _capacityCtrl = TextEditingController(text: e?.solarCapacity ?? '');
    _wiringCtrl = TextEditingController(text: e != null && e.wiringExpense > 0 ? e.wiringExpense.toStringAsFixed(0) : '');
    _civilCtrl = TextEditingController(text: e != null && e.civilExpense > 0 ? e.civilExpense.toStringAsFixed(0) : '');
    _structureCtrl = TextEditingController(text: e != null && e.structureExpense > 0 ? e.structureExpense.toStringAsFixed(0) : '');
    _remarksCtrl = TextEditingController(text: e?.remarks ?? '');

    if (e != null && widget.availableConsumers.isNotEmpty) {
      _selectedConsumer = widget.availableConsumers.cast<ConsumerRecord?>().firstWhere(
            (c) => c?.consumerNo == e.consumerNo,
            orElse: () => null,
          );
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _consumerNoCtrl.dispose();
    _locationCtrl.dispose();
    _capacityCtrl.dispose();
    _wiringCtrl.dispose();
    _civilCtrl.dispose();
    _structureCtrl.dispose();
    _remarksCtrl.dispose();
    super.dispose();
  }

  double get _wiring => double.tryParse(_wiringCtrl.text.trim()) ?? 0.0;
  double get _civil => double.tryParse(_civilCtrl.text.trim()) ?? 0.0;
  double get _structure => double.tryParse(_structureCtrl.text.trim()) ?? 0.0;
  double get _total => _wiring + _civil + _structure;

  void _onCustomerSelected(ConsumerRecord? customer) {
    if (customer == null) return;
    setState(() {
      _selectedConsumer = customer;
      _nameCtrl.text = customer.name;
      _consumerNoCtrl.text = customer.consumerNo;
      _locationCtrl.text = customer.address ?? customer.village ?? '';
      _capacityCtrl.text = customer.systemCapacity?.isNotEmpty == true
          ? customer.systemCapacity!
          : (customer.capacityKw > 0 ? '${customer.capacityKw} kW' : '3 kW');
    });
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    if (_consumerNoCtrl.text.trim().isEmpty) {
      setState(() => _errorMessage = 'Consumer Number is required. Please select a customer.');
      return;
    }

    // Check duplicate record
    final targetNo = _consumerNoCtrl.text.trim();
    final existingWithSameNo = widget.allExpenses.where(
      (e) => e.consumerNo.trim() == targetNo && e.id != (widget.existing?.id ?? ''),
    );
    if (existingWithSameNo.isNotEmpty) {
      setState(() {
        _errorMessage = 'Duplicate Site: An expense entry already exists for Consumer No: $targetNo. '
            'Please edit the existing entry instead.';
      });
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      final item = SiteTeamExpense(
        id: widget.existing?.id ?? '',
        consumerId: _selectedConsumer?.id ?? widget.existing?.consumerId ?? '',
        consumerNo: targetNo,
        customerName: _nameCtrl.text.trim(),
        siteLocation: _locationCtrl.text.trim(),
        solarCapacity: _capacityCtrl.text.trim(),
        expenseDate: _expenseDate,
        wiringExpense: _wiring,
        civilExpense: _civil,
        structureExpense: _structure,
        remarks: _remarksCtrl.text.trim().isNotEmpty ? _remarksCtrl.text.trim() : null,
      );

      await SiteTeamExpenseService.saveExpense(item);
      if (mounted) {
        widget.onSaved();
        Navigator.pop(context);
      }
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
    final theme = Theme.of(context);
    final isNew = widget.existing == null;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 620),
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: theme.colorScheme.primaryContainer,
                      child: Icon(Icons.group_work_rounded, color: theme.colorScheme.primary),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isNew ? 'Add Site Team Expense' : 'Edit Site Team Expense',
                            style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const Text(
                            'Enter manual expenses for Wiring, Civil, and Structure teams.',
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                    IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
                  ],
                ),
                const SizedBox(height: 16),

                if (_errorMessage != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 14),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline, color: Colors.red, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: const TextStyle(color: Colors.red, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),

                // 1. Customer Selection from Master
                if (isNew) ...[
                  const Text('1. SELECT CUSTOMER (CUSTOMER MASTER)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
                  const SizedBox(height: 6),
                  Autocomplete<ConsumerRecord>(
                    displayStringForOption: (c) => '${c.name} (${c.consumerNo}) - ${c.address ?? ""}',
                    optionsBuilder: (textEditingValue) {
                      if (textEditingValue.text.isEmpty) {
                        return widget.availableConsumers.take(20);
                      }
                      final q = textEditingValue.text.toLowerCase();
                      return widget.availableConsumers.where((c) {
                        return c.name.toLowerCase().contains(q) ||
                            c.consumerNo.toLowerCase().contains(q) ||
                            (c.address?.toLowerCase().contains(q) ?? false);
                      });
                    },
                    onSelected: _onCustomerSelected,
                    fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                      return TextFormField(
                        controller: controller,
                        focusNode: focusNode,
                        decoration: const InputDecoration(
                          labelText: 'Select Customer *',
                          hintText: 'Type customer name or consumer number...',
                          prefixIcon: Icon(Icons.search),
                          border: OutlineInputBorder(),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                ],

                // 2. Display Customer & Site Details
                const Text('SITE DETAILS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: TextFormField(
                        controller: _nameCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Customer Name *',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        validator: (v) => v?.trim().isEmpty == true ? 'Required' : null,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: TextFormField(
                        controller: _consumerNoCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Consumer Number *',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        validator: (v) => v?.trim().isEmpty == true ? 'Required' : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: TextFormField(
                        controller: _locationCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Site Location',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: TextFormField(
                        controller: _capacityCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Solar Capacity',
                          hintText: 'e.g. 3 kW',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Expense Date Picker
                InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _expenseDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2035),
                    );
                    if (picked != null) setState(() => _expenseDate = picked);
                  },
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Expense Date',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.calendar_today_outlined, size: 18),
                      isDense: true,
                    ),
                    child: Text(
                      DateFormat('dd MMMM yyyy').format(_expenseDate),
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // 3. Exactly 3 Manual Expense Fields
                const Text(
                  '2. TEAM EXPENSES (DIRECT AMOUNT ENTRY ONLY)',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey),
                ),
                const SizedBox(height: 10),

                // Field 1: Wiring Team Expense
                TextFormField(
                  controller: _wiringCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))],
                  decoration: const InputDecoration(
                    labelText: '1. Wiring Team Expense (₹)',
                    hintText: '0.00',
                    prefixIcon: Icon(Icons.electric_bolt_outlined, color: Colors.blue),
                    prefixText: '₹ ',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 12),

                // Field 2: Civil Team Expense
                TextFormField(
                  controller: _civilCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))],
                  decoration: const InputDecoration(
                    labelText: '2. Civil Team Expense (₹)',
                    hintText: '0.00',
                    prefixIcon: Icon(Icons.foundation_outlined, color: Colors.teal),
                    prefixText: '₹ ',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 12),

                // Field 3: Structure Team Expense
                TextFormField(
                  controller: _structureCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))],
                  decoration: const InputDecoration(
                    labelText: '3. Structure Team Expense (₹)',
                    hintText: '0.00',
                    prefixIcon: Icon(Icons.architecture_outlined, color: Colors.purple),
                    prefixText: '₹ ',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 16),

                // LIVE TOTAL SITE EXPENSE CALCULATION CARD
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFD1FAE5),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFF059669)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'TOTAL SITE EXPENSE',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF064E3B),
                            ),
                          ),
                          Text(
                            'Wiring + Civil + Structure',
                            style: TextStyle(fontSize: 10, color: Color(0xFF047857)),
                          ),
                        ],
                      ),
                      Text(
                        _currency.format(_total),
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF064E3B),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // Remarks Field
                TextFormField(
                  controller: _remarksCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Remarks / Notes (Optional)',
                    hintText: 'Special team notes, site conditions, etc.',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 24),

                // Action Buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 12),
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: theme.colorScheme.primary,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      ),
                      onPressed: _isSaving ? null : _handleSave,
                      icon: _isSaving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.check_rounded, size: 18),
                      label: Text(
                        isNew ? 'Save Expense' : 'Update Expense',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// VIEW TEAM EXPENSE DIALOG
// =============================================================================
class _ViewTeamExpenseDialog extends StatelessWidget {
  final SiteTeamExpense expense;
  const _ViewTeamExpenseDialog({required this.expense});

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(locale: 'en_IN', symbol: '₹ ', decimalDigits: 2);
    final theme = Theme.of(context);

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Icon(Icons.receipt_long_rounded, color: theme.colorScheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              expense.customerName,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              overflow: TextOverflow.ellipsis,
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
            Text('Consumer No: ${expense.consumerNo}', style: const TextStyle(fontWeight: FontWeight.w600)),
            Text('Location: ${expense.siteLocation.isNotEmpty ? expense.siteLocation : "—"}'),
            Text('Solar Capacity: ${expense.solarCapacity.isNotEmpty ? expense.solarCapacity : "—"}'),
            Text('Expense Date: ${expense.formattedDate}'),
            const Divider(height: 24),
            const Text('TEAM EXPENSE BREAKDOWN', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
            const SizedBox(height: 8),
            _buildDetailRow('1. Wiring Team Expense', currency.format(expense.wiringExpense), Colors.blue.shade900),
            const SizedBox(height: 6),
            _buildDetailRow('2. Civil Team Expense', currency.format(expense.civilExpense), Colors.teal.shade900),
            const SizedBox(height: 6),
            _buildDetailRow('3. Structure Team Expense', currency.format(expense.structureExpense), Colors.purple.shade900),
            const Divider(height: 20),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFD1FAE5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('TOTAL SITE EXPENSE', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF064E3B))),
                  Text(
                    currency.format(expense.totalSiteExpense),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF064E3B)),
                  ),
                ],
              ),
            ),
            if (expense.remarks != null && expense.remarks!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text('Remarks: ${expense.remarks!}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
      ],
    );
  }

  Widget _buildDetailRow(String label, String value, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 13)),
        Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: color)),
      ],
    );
  }
}
