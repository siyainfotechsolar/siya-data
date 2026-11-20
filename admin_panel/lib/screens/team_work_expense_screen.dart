import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../models/team_member.dart';
import '../models/team_work_expense.dart';
import '../models/consumer_record.dart';
import '../services/team_work_service.dart';
import '../services/team_work_excel_service.dart';
import '../utils/consumer_no_utils.dart';
import '../utils/responsive.dart';

enum TeamWorkViewTab { allSites, pending, customers, entries, persons, categories }

class TeamWorkExpenseScreen extends StatefulWidget {
  const TeamWorkExpenseScreen({super.key});

  @override
  State<TeamWorkExpenseScreen> createState() => _TeamWorkExpenseScreenState();
}

class _TeamWorkExpenseScreenState extends State<TeamWorkExpenseScreen> {
  final NumberFormat _currency = NumberFormat.currency(locale: 'en_IN', symbol: '₹ ', decimalDigits: 0);
  final DateFormat _dateFormat = DateFormat('dd/MM/yyyy');

  List<TeamWorkExpense> _allExpenses = [];
  List<TeamMember> _teamMembers = [];
  List<ConsumerRecord> _availableConsumers = [];

  bool _isLoading = true;
  bool _isExporting = false;
  String? _errorMessage;

  TeamWorkViewTab _currentTab = TeamWorkViewTab.allSites;

  // Filter controllers & states
  final TextEditingController _searchCtrl = TextEditingController();
  final TextEditingController _consumerNoSearchCtrl = TextEditingController();
  String _selectedMemberFilter = 'All';
  String _selectedCategoryFilter = 'All'; // 'All', 'Structure', 'Wiring', 'Civil'
  DateTime? _filterStartDate;
  DateTime? _filterEndDate;

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
        TeamWorkService.fetchWorkExpenses(),
        TeamWorkService.fetchTeamMembers(),
        TeamWorkService.fetchAvailableCustomers(),
      ]);

      if (mounted) {
        setState(() {
          _allExpenses = results[0] as List<TeamWorkExpense>;
          _teamMembers = results[1] as List<TeamMember>;
          _availableConsumers = results[2] as List<ConsumerRecord>;
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

  /// Filtered work entries based on search & filters
  List<TeamWorkExpense> get _filteredExpenses {
    final nameQuery = _searchCtrl.text.trim().toLowerCase();
    final noQuery = _consumerNoSearchCtrl.text.trim().toLowerCase();

    return _allExpenses.where((e) {
      // 1. Date range
      if (_filterStartDate != null) {
        final start = DateTime(_filterStartDate!.year, _filterStartDate!.month, _filterStartDate!.day);
        if (e.workDate.isBefore(start)) return false;
      }
      if (_filterEndDate != null) {
        final end = DateTime(_filterEndDate!.year, _filterEndDate!.month, _filterEndDate!.day, 23, 59, 59);
        if (e.workDate.isAfter(end)) return false;
      }

      // 2. Customer Name search
      if (nameQuery.isNotEmpty && !e.customerName.toLowerCase().contains(nameQuery)) {
        return false;
      }

      // 3. Consumer No search
      if (noQuery.isNotEmpty && !e.consumerNo.toLowerCase().contains(noQuery)) {
        return false;
      }

      // 4. Team Member filter
      if (_selectedMemberFilter != 'All' &&
          e.teamMemberName.trim().toLowerCase() != _selectedMemberFilter.trim().toLowerCase()) {
        return false;
      }

      // 5. Work Category filter
      if (_selectedCategoryFilter != 'All' &&
          e.workCategory.trim().toLowerCase() != _selectedCategoryFilter.trim().toLowerCase()) {
        return false;
      }

      return true;
    }).toList();
  }

  /// All unique customer sites from master that do NOT yet have any recorded team work expense
  List<ConsumerRecord> get _allPendingConsumers {
    final recordedConsumerNos = _allExpenses
        .map((e) => ConsumerNoNormalizer.normalize(e.consumerNo))
        .where((s) => s.isNotEmpty)
        .toSet();

    return _availableConsumers.where((c) {
      final norm = ConsumerNoNormalizer.normalize(c.consumerNo);
      return !recordedConsumerNos.contains(norm);
    }).toList();
  }

  /// Pending customer sites filtered by customer name and consumer number searches
  List<ConsumerRecord> get _filteredPendingConsumers {
    final nameTerm = _searchCtrl.text.trim().toLowerCase();
    final noTerm = _consumerNoSearchCtrl.text.trim().toLowerCase();

    return _allPendingConsumers.where((c) {
      if (nameTerm.isNotEmpty && !c.name.toLowerCase().contains(nameTerm)) {
        return false;
      }
      if (noTerm.isNotEmpty && !c.consumerNo.toLowerCase().contains(noTerm)) {
        return false;
      }
      return true;
    }).toList();
  }

  /// All customer sites filtered by customer name and consumer number searches
  List<ConsumerRecord> get _filteredAllConsumers {
    final nameTerm = _searchCtrl.text.trim().toLowerCase();
    final noTerm = _consumerNoSearchCtrl.text.trim().toLowerCase();

    return _availableConsumers.where((c) {
      if (nameTerm.isNotEmpty && !c.name.toLowerCase().contains(nameTerm)) {
        return false;
      }
      if (noTerm.isNotEmpty && !c.consumerNo.toLowerCase().contains(noTerm)) {
        return false;
      }
      return true;
    }).toList();
  }

  void _resetFilters() {
    setState(() {
      _searchCtrl.clear();
      _consumerNoSearchCtrl.clear();
      _selectedMemberFilter = 'All';
      _selectedCategoryFilter = 'All';
      _filterStartDate = null;
      _filterEndDate = null;
    });
  }

  String get _appliedFiltersText {
    final parts = <String>[];
    if (_searchCtrl.text.trim().isNotEmpty) parts.add('Customer: "${_searchCtrl.text.trim()}"');
    if (_consumerNoSearchCtrl.text.trim().isNotEmpty) parts.add('Consumer: "${_consumerNoSearchCtrl.text.trim()}"');
    if (_selectedMemberFilter != 'All') parts.add('Member: $_selectedMemberFilter');
    if (_selectedCategoryFilter != 'All') parts.add('Category: $_selectedCategoryFilter');
    if (_filterStartDate != null && _filterEndDate != null) {
      parts.add('Date: ${_dateFormat.format(_filterStartDate!)} to ${_dateFormat.format(_filterEndDate!)}');
    }
    return parts.isEmpty ? 'All Records (Unfiltered)' : parts.join(', ');
  }

  // ==========================================
  // ACTIONS
  // ==========================================

  Future<void> _exportToExcel() async {
    final toExport = _filteredExpenses;
    if (toExport.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No work entries to export.'), backgroundColor: Colors.orange),
      );
      return;
    }

    setState(() => _isExporting = true);
    try {
      final savedPath = await TeamWorkExcelService.exportAndSave(
        expenses: toExport,
        appliedFilterDescription: _appliedFiltersText,
        customMemberCount: _teamMembers.length,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              savedPath != null
                  ? 'Excel Report exported successfully! (${toExport.length} entries, 4 sheets)'
                  : 'Excel Export cancelled.',
            ),
            backgroundColor: savedPath != null ? Colors.green : Colors.grey,
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

  Future<void> _openAddEditEntryDialog({TeamWorkExpense? existing, ConsumerRecord? preselectedCustomer}) async {
    final result = await showDialog<TeamWorkExpense>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _AddEditWorkEntryDialog(
        existing: existing,
        preselectedCustomer: preselectedCustomer,
        availableCustomers: _availableConsumers,
        teamMembers: _teamMembers,
        onSave: (entry) async {
          final saved = await TeamWorkService.saveWorkExpense(entry);
          return saved;
        },
      ),
    );

    if (result != null && mounted) {
      await _loadData();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            existing == null
                ? 'Work entry for "${result.teamMemberName}" saved successfully.'
                : 'Work entry updated successfully.',
          ),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _deleteEntry(TeamWorkExpense entry) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.delete_outline, color: Colors.red),
            SizedBox(width: 8),
            Text('Delete Work Entry'),
          ],
        ),
        content: Text(
          'Are you sure you want to delete the "${entry.workCategory}" entry for '
          '${entry.teamMemberName} (${_currency.format(entry.individualExpense)}) at ${entry.customerName}?\n\n'
          'Other entries for this site or worker will NOT be affected.',
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
        await TeamWorkService.deleteWorkExpense(entry.id);
        setState(() {
          _allExpenses.removeWhere((e) => e.id == entry.id);
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Work entry deleted successfully.'), backgroundColor: Colors.green),
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

  void _openViewEntryDialog(TeamWorkExpense entry) {
    showDialog(
      context: context,
      builder: (ctx) => _ViewWorkEntryDialog(
        entry: entry,
        onEdit: () => _openAddEditEntryDialog(existing: entry),
      ),
    );
  }

  Future<void> _openTeamMemberMasterDialog() async {
    await showDialog(
      context: context,
      builder: (ctx) => _TeamMemberMasterDialog(
        members: _teamMembers,
        onMembersChanged: () => _loadData(),
      ),
    );
    _loadData();
  }

  void _openCustomerDrillDown(CustomerExpenseSummary customer) {
    showDialog(
      context: context,
      builder: (ctx) => _CustomerWorkDrillDownDialog(
        customerSummary: customer,
        onAddEntry: () {
          Navigator.pop(context);
          final norm = ConsumerNoNormalizer.normalize(customer.consumerNo);
          final match = _availableConsumers.cast<ConsumerRecord?>().firstWhere(
                (c) => c != null && ConsumerNoNormalizer.normalize(c.consumerNo) == norm,
                orElse: () => null,
              );
          _openAddEditEntryDialog(preselectedCustomer: match);
        },
        onEditEntry: (entry) {
          Navigator.pop(context);
          _openAddEditEntryDialog(existing: entry);
        },
        onDeleteEntry: (entry) async {
          Navigator.pop(context);
          await _deleteEntry(entry);
        },
      ),
    );
  }

  // ==========================================
  // BUILD METHOD
  // ==========================================

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isMobile = Responsive.isMobile(context);
    final displayed = _filteredExpenses;
    final summary = TeamWorkDashboardSummary.calculate(displayed, customTeamMemberCount: _teamMembers.length);

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
                          Icon(Icons.engineering_rounded, size: 28, color: theme.colorScheme.primary),
                          Text(
                            isMobile ? 'Team Work' : 'Team Work & Individual Expenses',
                            style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          Chip(
                            backgroundColor: Colors.blue.shade50,
                            side: BorderSide(color: Colors.blue.shade200),
                            label: Text(
                              '${_allExpenses.length} Entries • ${_teamMembers.length} Members',
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
                          'Track individual team worker expenses (Structure, Wiring, Civil) with site drill-down and 4-sheet Excel reports.',
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
                    // Excel Export (Mandatory 4 Sheets)
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF047857), // Emerald
                        foregroundColor: Colors.white,
                      ),
                      onPressed: _isExporting ? null : _exportToExcel,
                      icon: _isExporting
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Icon(Icons.table_view_rounded, size: 18),
                      label: Text(isMobile ? 'Excel' : 'Export to Excel (4 Sheets)'),
                    ),
                    // Manage Team Members Master
                    OutlinedButton.icon(
                      onPressed: _openTeamMemberMasterDialog,
                      icon: const Icon(Icons.people_outline, size: 18),
                      label: Text(isMobile ? 'Members' : 'Team Members (${_teamMembers.length})'),
                    ),
                    // Add Work Entry
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF1E3A8A), // Navy
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () => _openAddEditEntryDialog(),
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: Text(isMobile ? 'Add' : '+ Add Work Entry'),
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

            // DASHBOARD SUMMARY METRICS (6 Cards)
            _buildDashboardMetricsBar(theme, summary, isMobile),
            const SizedBox(height: 12),

            // FILTERS TOOLBAR
            _buildFiltersToolbar(theme, isMobile),
            const SizedBox(height: 10),

            // VIEW TAB SELECTOR
            _buildTabSelector(theme),
            const SizedBox(height: 10),

            // MAIN CONTENT VIEW
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
                      : _buildCurrentTabView(theme, displayed, isMobile),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // DASHBOARD METRIC CARDS
  // ==========================================

  Widget _buildDashboardMetricsBar(ThemeData theme, TeamWorkDashboardSummary summary, bool isMobile) {
    final totalMaster = _availableConsumers.length;
    final customerSummaries = TeamWorkService.buildCustomerSummaries(_allExpenses);
    final recordedCount = customerSummaries.length;
    final pendingCount = _allPendingConsumers.length;

    final cards = [
      _MetricCard(
        title: 'Master Sites',
        value: '$totalMaster Sites',
        subtitle: '$recordedCount Recorded • $pendingCount Pending',
        icon: Icons.business_rounded,
        color: const Color(0xFF2563EB), // Blue
        bgColor: const Color(0xFFEFF6FF),
        isSelected: _currentTab == TeamWorkViewTab.allSites,
        onTap: () {
          setState(() => _currentTab = TeamWorkViewTab.allSites);
        },
      ),
      _MetricCard(
        title: 'Expenses Pending',
        value: '$pendingCount Sites',
        subtitle: 'Click to view pending sites!',
        icon: Icons.pending_actions_rounded,
        color: const Color(0xFFD97706), // Amber
        bgColor: const Color(0xFFFFFBEB),
        isSelected: _currentTab == TeamWorkViewTab.pending,
        onTap: () {
          setState(() => _currentTab = TeamWorkViewTab.pending);
        },
      ),
      _MetricCard(
        title: 'Expenses Recorded',
        value: '$recordedCount Sites',
        subtitle: '${_allExpenses.length} Work Entries',
        icon: Icons.check_circle_outline,
        color: const Color(0xFF047857), // Green
        bgColor: const Color(0xFFECFDF5),
        isSelected: _currentTab == TeamWorkViewTab.customers,
        onTap: () {
          setState(() => _currentTab = TeamWorkViewTab.customers);
        },
      ),
      _MetricCard(
        title: 'Team Members',
        value: '${summary.totalTeamMembers}',
        subtitle: '${_teamMembers.where((m) => m.isActive).length} Active Workers',
        icon: Icons.groups_outlined,
        color: const Color(0xFF4F46E5), // Indigo
        bgColor: const Color(0xFFEEF2FF),
        isSelected: _currentTab == TeamWorkViewTab.persons,
        onTap: () {
          setState(() => _currentTab = TeamWorkViewTab.persons);
        },
      ),
      _MetricCard(
        title: 'Structure Expense',
        value: _currency.format(summary.totalStructureExpense),
        subtitle: 'Structure Team Total',
        icon: Icons.architecture_outlined,
        color: const Color(0xFF7C3AED), // Purple
        bgColor: const Color(0xFFF5F3FF),
        isSelected: _selectedCategoryFilter == 'Structure',
        onTap: () {
          setState(() {
            _selectedCategoryFilter = _selectedCategoryFilter == 'Structure' ? 'All' : 'Structure';
          });
        },
      ),
      _MetricCard(
        title: 'Wiring Expense',
        value: _currency.format(summary.totalWiringExpense),
        subtitle: 'Wiring Team Total',
        icon: Icons.electric_bolt_outlined,
        color: const Color(0xFFB45309), // Amber
        bgColor: const Color(0xFFFFFBEB),
        isSelected: _selectedCategoryFilter == 'Wiring',
        onTap: () {
          setState(() {
            _selectedCategoryFilter = _selectedCategoryFilter == 'Wiring' ? 'All' : 'Wiring';
          });
        },
      ),
      _MetricCard(
        title: 'Civil Expense',
        value: _currency.format(summary.totalCivilExpense),
        subtitle: 'Civil Team Total',
        icon: Icons.foundation_outlined,
        color: const Color(0xFF0D9488), // Teal
        bgColor: const Color(0xFFF0FDFA),
        isSelected: _selectedCategoryFilter == 'Civil',
        onTap: () {
          setState(() {
            _selectedCategoryFilter = _selectedCategoryFilter == 'Civil' ? 'All' : 'Civil';
          });
        },
      ),
      _MetricCard(
        title: 'Grand Total Expense',
        value: _currency.format(summary.grandTotalExpense),
        subtitle: 'Structure + Wiring + Civil',
        icon: Icons.account_balance_wallet_outlined,
        color: const Color(0xFF047857), // Emerald
        bgColor: const Color(0xFFECFDF5),
        isHighlight: true,
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
        final crossCount = constraints.maxWidth > 1200 ? 4 : 2;
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
            // Customer Name Search
            SizedBox(
              width: isMobile ? double.infinity : 210,
              height: 38,
              child: TextField(
                controller: _searchCtrl,
                decoration: InputDecoration(
                  hintText: 'Search Customer...',
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

            // Consumer No Search
            SizedBox(
              width: isMobile ? double.infinity : 170,
              height: 38,
              child: TextField(
                controller: _consumerNoSearchCtrl,
                decoration: InputDecoration(
                  hintText: 'Consumer No...',
                  prefixIcon: const Icon(Icons.tag, size: 18),
                  suffixIcon: _consumerNoSearchCtrl.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 16),
                          onPressed: () {
                            _consumerNoSearchCtrl.clear();
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

            // Team Member Filter
            SizedBox(
              width: isMobile ? double.infinity : 160,
              height: 38,
              child: DropdownButtonFormField<String>(
                initialValue: _selectedMemberFilter,
                decoration: InputDecoration(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  prefixIcon: const Icon(Icons.person_outline, size: 18),
                ),
                items: [
                  const DropdownMenuItem(value: 'All', child: Text('All Members')),
                  ..._teamMembers.map((m) => DropdownMenuItem(value: m.name, child: Text(m.name))),
                ],
                onChanged: (val) {
                  if (val != null) setState(() => _selectedMemberFilter = val);
                },
              ),
            ),

            // Work Category Filter
            SizedBox(
              width: isMobile ? double.infinity : 150,
              height: 38,
              child: DropdownButtonFormField<String>(
                initialValue: _selectedCategoryFilter,
                decoration: InputDecoration(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  prefixIcon: const Icon(Icons.category_outlined, size: 18),
                ),
                items: const [
                  DropdownMenuItem(value: 'All', child: Text('All Categories')),
                  DropdownMenuItem(value: 'Structure', child: Text('Structure')),
                  DropdownMenuItem(value: 'Wiring', child: Text('Wiring')),
                  DropdownMenuItem(value: 'Civil', child: Text('Civil')),
                ],
                onChanged: (val) {
                  if (val != null) setState(() => _selectedCategoryFilter = val);
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
                _consumerNoSearchCtrl.text.isNotEmpty ||
                _selectedMemberFilter != 'All' ||
                _selectedCategoryFilter != 'All' ||
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

  Widget _buildTabSelector(ThemeData theme) {
    final totalMaster = _availableConsumers.length;
    final personSummaries = TeamWorkService.buildPersonSummaries(_allExpenses);
    final customerSummaries = TeamWorkService.buildCustomerSummaries(_allExpenses);
    final pendingCount = _allPendingConsumers.length;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SegmentedButton<TeamWorkViewTab>(
        segments: [
          ButtonSegment(
            value: TeamWorkViewTab.allSites,
            icon: const Icon(Icons.business_rounded, size: 16),
            label: Text('All Customer Sites ($totalMaster)'),
          ),
          ButtonSegment(
            value: TeamWorkViewTab.pending,
            icon: const Icon(Icons.pending_actions_rounded, size: 16),
            label: Text('Pending Sites ($pendingCount)'),
          ),
          ButtonSegment(
            value: TeamWorkViewTab.customers,
            icon: const Icon(Icons.domain_rounded, size: 16),
            label: Text('Recorded Sites (${customerSummaries.length})'),
          ),
          ButtonSegment(
            value: TeamWorkViewTab.entries,
            icon: const Icon(Icons.list_alt_rounded, size: 16),
            label: Text('All Work Entries (${_filteredExpenses.length})'),
          ),
          ButtonSegment(
            value: TeamWorkViewTab.persons,
            icon: const Icon(Icons.person_pin_rounded, size: 16),
            label: Text('Person Summary (${personSummaries.length})'),
          ),
          const ButtonSegment(
            value: TeamWorkViewTab.categories,
            icon: Icon(Icons.pie_chart_outline_rounded, size: 16),
            label: Text('Category Summary (3)'),
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
  // TAB VIEWS
  // ==========================================

  Widget _buildCurrentTabView(ThemeData theme, List<TeamWorkExpense> expenses, bool isMobile) {
    switch (_currentTab) {
      case TeamWorkViewTab.allSites:
        return _buildAllCustomerSitesTab(theme, isMobile);
      case TeamWorkViewTab.entries:
        return _buildWorkEntriesTab(theme, expenses, isMobile);
      case TeamWorkViewTab.pending:
        return _buildPendingSitesTab(theme, isMobile);
      case TeamWorkViewTab.persons:
        return _buildPersonSummaryTab(theme, expenses, isMobile);
      case TeamWorkViewTab.customers:
        return _buildCustomerSummaryTab(theme, expenses, isMobile);
      case TeamWorkViewTab.categories:
        return _buildCategorySummaryTab(theme, expenses);
    }
  }

  // ==========================================
  // ALL CUSTOMER SITES TAB
  // ==========================================

  Widget _buildAllCustomerSitesTab(ThemeData theme, bool isMobile) {
    final list = _filteredAllConsumers;
    final totalMaster = _availableConsumers.length;
    final recordedCount = TeamWorkService.buildCustomerSummaries(_allExpenses).length;
    final pendingCount = _allPendingConsumers.length;

    if (list.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off_rounded, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            const Text('No Customer Sites Found Matching Filter.', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
      );
    }

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: Colors.blue.shade200),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
              border: Border(bottom: BorderSide(color: Colors.blue.shade200)),
            ),
            child: Row(
              children: [
                Icon(Icons.business_rounded, size: 20, color: Colors.blue.shade900),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'All Customer Sites ($totalMaster Sites) — $recordedCount Expenses Recorded, $pendingCount Expenses Pending. Click "Edit Work" or "+ Record Work" on any customer.',
                    style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue.shade900, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(8),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  headingRowColor: WidgetStateProperty.all(Colors.blue.shade100.withValues(alpha: 0.5)),
                  columns: const [
                    DataColumn(label: Text('Sr. No.', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('Customer Name', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('Consumer No.', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('Action / Edit', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('Expense Status', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(numeric: true, label: Text('Total Site Expense (₹)', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('Solar Capacity', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('Site Location', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('Mobile', style: TextStyle(fontWeight: FontWeight.bold))),
                  ],
                  rows: List.generate(list.length, (idx) {
                    final c = list[idx];
                    final norm = ConsumerNoNormalizer.normalize(c.consumerNo);
                    final entries = _allExpenses.where((e) => ConsumerNoNormalizer.normalize(e.consumerNo) == norm).toList();
                    final isRecorded = entries.isNotEmpty;
                    final totalExp = entries.fold<double>(0.0, (sum, e) => sum + e.individualExpense);

                    final loc = c.address ?? c.village ?? '-';
                    final cap = c.systemCapacity?.isNotEmpty == true
                        ? c.systemCapacity!
                        : (c.capacityKw > 0 ? '${c.capacityKw} kW' : '-');

                    return DataRow(
                      cells: [
                        DataCell(Text('${idx + 1}')),
                        DataCell(Row(
                          children: [
                            Icon(isRecorded ? Icons.verified_user_rounded : Icons.person_outline, size: 16, color: isRecorded ? Colors.teal : Colors.blueGrey),
                            const SizedBox(width: 6),
                            Text(c.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                          ],
                        )),
                        DataCell(Text(c.consumerNo, style: const TextStyle(fontWeight: FontWeight.w500))),
                        DataCell(
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (isRecorded) ...[
                                ElevatedButton.icon(
                                  icon: const Icon(Icons.edit_outlined, size: 13, color: Colors.white),
                                  label: const Text('Edit Work', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white)),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF1E3A8A),
                                    visualDensity: VisualDensity.compact,
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  ),
                                  onPressed: () => _openAddEditEntryDialog(existing: entries.first),
                                ),
                                const SizedBox(width: 4),
                                OutlinedButton.icon(
                                  icon: const Icon(Icons.add, size: 13),
                                  label: const Text('+ Worker', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                  style: OutlinedButton.styleFrom(
                                    visualDensity: VisualDensity.compact,
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  ),
                                  onPressed: () => _openAddEditEntryDialog(preselectedCustomer: c),
                                ),
                              ] else ...[
                                ElevatedButton.icon(
                                  icon: const Icon(Icons.add_task_rounded, size: 13, color: Colors.white),
                                  label: const Text('+ Record Work', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white)),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF0D9488),
                                    visualDensity: VisualDensity.compact,
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  ),
                                  onPressed: () => _openAddEditEntryDialog(preselectedCustomer: c),
                                ),
                              ],
                            ],
                          ),
                        ),
                        DataCell(
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: isRecorded ? Colors.green.shade50 : Colors.amber.shade50,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: isRecorded ? Colors.green.shade400 : Colors.amber.shade400),
                            ),
                            child: Text(
                              isRecorded ? 'Recorded (${entries.length} Workers)' : 'Pending Entry',
                              style: TextStyle(
                                color: isRecorded ? Colors.green.shade800 : Colors.amber.shade900,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        DataCell(Text(
                          isRecorded ? _currency.format(totalExp) : '—',
                          style: TextStyle(fontWeight: FontWeight.bold, color: isRecorded ? const Color(0xFF064E3B) : Colors.grey),
                        )),
                        DataCell(Text(cap)),
                        DataCell(Text(loc)),
                        DataCell(Text(c.mobile ?? '-')),
                      ],
                    );
                  }),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // PENDING SITES TAB
  // ==========================================

  Widget _buildPendingSitesTab(ThemeData theme, bool isMobile) {
    final pendingList = _filteredPendingConsumers;
    if (pendingList.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle_outline_rounded, size: 56, color: Colors.green.shade600),
            const SizedBox(height: 12),
            const Text(
              'No Pending Customer Sites!',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green),
            ),
            const SizedBox(height: 6),
            Text(
              _allPendingConsumers.isEmpty
                  ? 'All registered customer sites have team expenses recorded.'
                  : 'No pending sites match the search filter.',
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ],
        ),
      );
    }

    return isMobile
        ? _buildMobilePendingList(theme, pendingList)
        : _buildDesktopPendingTable(theme, pendingList);
  }

  Widget _buildDesktopPendingTable(ThemeData theme, List<ConsumerRecord> pendingList) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.amber.shade50,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
              border: Border(bottom: BorderSide(color: Colors.amber.shade200)),
            ),
            child: Row(
              children: [
                Icon(Icons.warning_amber_rounded, size: 20, color: Colors.amber.shade900),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${pendingList.length} Customer Sites are awaiting team work & expense entry. Click "+ Record / Edit Work" on any site to assign team members.',
                    style: TextStyle(fontWeight: FontWeight.bold, color: Colors.amber.shade900, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(8),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  headingRowColor: WidgetStateProperty.all(Colors.amber.shade100.withValues(alpha: 0.5)),
                  columns: const [
                    DataColumn(label: Text('Sr. No.', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('Customer Name', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('Consumer No.', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('Action / Edit', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('Solar Capacity', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('Site Location', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('Expense Status', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('Mobile', style: TextStyle(fontWeight: FontWeight.bold))),
                  ],
                  rows: List.generate(pendingList.length, (idx) {
                    final c = pendingList[idx];
                    final loc = c.address ?? c.village ?? '-';
                    final cap = c.systemCapacity?.isNotEmpty == true
                        ? c.systemCapacity!
                        : (c.capacityKw > 0 ? '${c.capacityKw} kW' : '-');
                    return DataRow(
                      onSelectChanged: (_) => _openAddEditEntryDialog(preselectedCustomer: c),
                      cells: [
                        DataCell(Text('${idx + 1}')),
                        DataCell(Row(
                          children: [
                            const Icon(Icons.person_outline, size: 16, color: Colors.blueGrey),
                            const SizedBox(width: 6),
                            Text(c.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                          ],
                        )),
                        DataCell(Text(c.consumerNo, style: const TextStyle(fontWeight: FontWeight.w500))),
                        DataCell(
                          ElevatedButton.icon(
                            icon: const Icon(Icons.add_task_rounded, size: 14, color: Colors.white),
                            label: const Text('+ Record / Edit Work', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0D9488),
                              visualDensity: VisualDensity.compact,
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            ),
                            onPressed: () => _openAddEditEntryDialog(preselectedCustomer: c),
                          ),
                        ),
                        DataCell(Text(cap)),
                        DataCell(Text(loc)),
                        DataCell(
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.amber.shade100,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: Colors.amber.shade400),
                            ),
                            child: Text(
                              'Pending Entry',
                              style: TextStyle(color: Colors.amber.shade900, fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                        DataCell(Text(c.mobile ?? '-')),
                      ],
                    );
                  }),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobilePendingList(ThemeData theme, List<ConsumerRecord> pendingList) {
    return ListView.separated(
      itemCount: pendingList.length,
      separatorBuilder: (_, index) => const SizedBox(height: 8),
      itemBuilder: (_, i) {
        final c = pendingList[i];
        final loc = c.address ?? c.village ?? '-';
        final cap = c.systemCapacity?.isNotEmpty == true
            ? c.systemCapacity!
            : (c.capacityKw > 0 ? '${c.capacityKw} kW' : '-');
        return Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: BorderSide(color: Colors.amber.shade200),
          ),
          color: Colors.amber.shade50.withValues(alpha: 0.3),
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
                        c.name,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade100,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'Pending',
                        style: TextStyle(color: Colors.amber.shade900, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text('Consumer No: ${c.consumerNo} • Capacity: $cap', style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
                Text('Location: $loc', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.add_task_rounded, size: 14, color: Colors.white),
                    label: const Text('+ Record / Edit Work', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0D9488),
                      visualDensity: VisualDensity.compact,
                    ),
                    onPressed: () => _openAddEditEntryDialog(preselectedCustomer: c),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // 1. ALL WORK ENTRIES TAB
  Widget _buildWorkEntriesTab(ThemeData theme, List<TeamWorkExpense> expenses, bool isMobile) {
    if (expenses.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inventory_2_outlined, size: 56, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            const Text('No work entries found', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text(
              _allExpenses.isEmpty
                  ? 'Click "+ Add Work Entry" to record team expenses.'
                  : 'No entries match your search/filter criteria.',
              style: TextStyle(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 12),
            if (_allExpenses.isNotEmpty)
              OutlinedButton(onPressed: _resetFilters, child: const Text('Reset All Filters'))
            else
              FilledButton.icon(
                icon: const Icon(Icons.add),
                label: const Text('+ Add First Work Entry'),
                onPressed: () => _openAddEditEntryDialog(),
              ),
          ],
        ),
      );
    }

    if (isMobile) {
      return ListView.separated(
        itemCount: expenses.length,
        separatorBuilder: (_, index) => const SizedBox(height: 8),
        itemBuilder: (_, i) => _buildMobileEntryCard(theme, expenses[i]),
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
            headingRowColor: WidgetStateProperty.all(Colors.blueGrey.shade50),
            columns: const [
              DataColumn(label: Text('Sr. No.', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Work Date', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Customer Name', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Consumer No.', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Team Member', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Work Category', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(numeric: true, label: Text('Individual Expense (₹)', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF064E3B)))),
              DataColumn(label: Text('Remarks', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold))),
            ],
            rows: List.generate(expenses.length, (idx) {
              final e = expenses[idx];
              final catColor = e.isStructure
                  ? Colors.purple.shade800
                  : (e.isWiring ? Colors.amber.shade900 : Colors.teal.shade800);
              final catBg = e.isStructure
                  ? Colors.purple.shade50
                  : (e.isWiring ? Colors.amber.shade50 : Colors.teal.shade50);

              return DataRow(
                onSelectChanged: (_) => _openViewEntryDialog(e),
                cells: [
                  DataCell(Text('${idx + 1}')),
                  DataCell(Text(_dateFormat.format(e.workDate))),
                  DataCell(Text(e.customerName, style: const TextStyle(fontWeight: FontWeight.w600))),
                  DataCell(Text(e.consumerNo)),
                  DataCell(Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircleAvatar(
                        radius: 12,
                        backgroundColor: Colors.blue.shade100,
                        child: Text(
                          e.teamMemberName.isNotEmpty ? e.teamMemberName[0].toUpperCase() : '?',
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.blue.shade900),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(e.teamMemberName, style: const TextStyle(fontWeight: FontWeight.w600)),
                    ],
                  )),
                  DataCell(Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: catBg,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: catColor.withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      e.workCategory,
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: catColor),
                    ),
                  )),
                  DataCell(Text(
                    _currency.format(e.individualExpense),
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF064E3B)),
                  )),
                  DataCell(Text(e.remarks.isNotEmpty ? e.remarks : '—')),
                  DataCell(Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ElevatedButton.icon(
                        icon: const Icon(Icons.edit_outlined, size: 13, color: Colors.white),
                        label: const Text('Edit', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1E3A8A),
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        ),
                        onPressed: () => _openAddEditEntryDialog(existing: e),
                      ),
                      const SizedBox(width: 4),
                      IconButton(
                        icon: const Icon(Icons.visibility_outlined, size: 16, color: Colors.blueGrey),
                        tooltip: 'View Details',
                        onPressed: () => _openViewEntryDialog(e),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, size: 16, color: Colors.red),
                        tooltip: 'Delete Entry',
                        onPressed: () => _deleteEntry(e),
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

  Widget _buildMobileEntryCard(ThemeData theme, TeamWorkExpense e) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: ListTile(
        onTap: () => _openViewEntryDialog(e),
        leading: CircleAvatar(
          backgroundColor: Colors.indigo.shade50,
          child: Text(
            e.teamMemberName.isNotEmpty ? e.teamMemberName[0].toUpperCase() : 'W',
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.indigo.shade900),
          ),
        ),
        title: Row(
          children: [
            Expanded(child: Text(e.customerName, style: const TextStyle(fontWeight: FontWeight.bold))),
            Text(
              _currency.format(e.individualExpense),
              style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF064E3B)),
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 2),
            Text('${e.teamMemberName} • ${e.workCategory} • ${_dateFormat.format(e.workDate)}'),
            Text('No: ${e.consumerNo} ${e.siteLocation.isNotEmpty ? "• ${e.siteLocation}" : ""}'),
          ],
        ),
        trailing: PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert, size: 18),
          onSelected: (val) {
            if (val == 'view') _openViewEntryDialog(e);
            if (val == 'edit') _openAddEditEntryDialog(existing: e);
            if (val == 'delete') _deleteEntry(e);
          },
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'view', child: Text('View Details')),
            PopupMenuItem(value: 'edit', child: Text('Edit')),
            PopupMenuItem(value: 'delete', child: Text('Delete', style: TextStyle(color: Colors.red))),
          ],
        ),
      ),
    );
  }

  // 2. INDIVIDUAL PERSON SUMMARY TAB
  Widget _buildPersonSummaryTab(ThemeData theme, List<TeamWorkExpense> expenses, bool isMobile) {
    final summaries = TeamWorkService.buildPersonSummaries(expenses);

    if (summaries.isEmpty) {
      return const Center(child: Text('No person work records to summarize.'));
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
            headingRowColor: WidgetStateProperty.all(Colors.indigo.shade50),
            columns: const [
              DataColumn(label: Text('Person Name', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(numeric: true, label: Text('Structure (₹)', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(numeric: true, label: Text('Wiring (₹)', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(numeric: true, label: Text('Civil (₹)', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(numeric: true, label: Text('Total Expense (₹)', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF064E3B)))),
              DataColumn(numeric: true, label: Text('Sites', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Action', style: TextStyle(fontWeight: FontWeight.bold))),
            ],
            rows: summaries.map((p) {
              return DataRow(
                cells: [
                  DataCell(Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircleAvatar(
                        radius: 12,
                        backgroundColor: Colors.indigo.shade100,
                        child: Text(
                          p.teamMemberName.isNotEmpty ? p.teamMemberName[0].toUpperCase() : '?',
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.indigo.shade900),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(p.teamMemberName, style: const TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  )),
                  DataCell(Text(_currency.format(p.structureExpense))),
                  DataCell(Text(_currency.format(p.wiringExpense))),
                  DataCell(Text(_currency.format(p.civilExpense))),
                  DataCell(Text(
                    _currency.format(p.totalExpense),
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF064E3B)),
                  )),
                  DataCell(Text('${p.totalSites}')),
                  DataCell(
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      ),
                      icon: const Icon(Icons.filter_alt_outlined, size: 14),
                      label: const Text('View Entries', style: TextStyle(fontSize: 12)),
                      onPressed: () {
                        setState(() {
                          _selectedMemberFilter = p.teamMemberName;
                          _currentTab = TeamWorkViewTab.entries;
                        });
                      },
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  // 3. CUSTOMER-WISE SUMMARY TAB
  Widget _buildCustomerSummaryTab(ThemeData theme, List<TeamWorkExpense> expenses, bool isMobile) {
    final summaries = TeamWorkService.buildCustomerSummaries(expenses);

    if (summaries.isEmpty) {
      return const Center(child: Text('No customer work records to summarize.'));
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
            headingRowColor: WidgetStateProperty.all(Colors.teal.shade50),
            columns: const [
              DataColumn(label: Text('Customer Name', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Consumer No.', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Site Location', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(numeric: true, label: Text('Structure (₹)', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(numeric: true, label: Text('Wiring (₹)', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(numeric: true, label: Text('Civil (₹)', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(numeric: true, label: Text('Total Site Expense (₹)', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF064E3B)))),
              DataColumn(label: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold))),
            ],
            rows: summaries.map((c) {
              return DataRow(
                onSelectChanged: (_) => _openCustomerDrillDown(c),
                cells: [
                  DataCell(Text(c.customerName, style: const TextStyle(fontWeight: FontWeight.bold))),
                  DataCell(Text(c.consumerNo)),
                  DataCell(SizedBox(
                    width: 180,
                    child: Text(c.siteLocation.isNotEmpty ? c.siteLocation : '—', maxLines: 2, overflow: TextOverflow.ellipsis),
                  )),
                  DataCell(Text(_currency.format(c.structureExpense))),
                  DataCell(Text(_currency.format(c.wiringExpense))),
                  DataCell(Text(_currency.format(c.civilExpense))),
                  DataCell(Text(
                    _currency.format(c.totalSiteExpense),
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF064E3B)),
                  )),
                  DataCell(
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1E3A8A),
                            visualDensity: VisualDensity.compact,
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          ),
                          icon: const Icon(Icons.edit_outlined, size: 14, color: Colors.white),
                          label: const Text('Edit Work', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white)),
                          onPressed: () {
                            if (c.entries.isNotEmpty) {
                              _openAddEditEntryDialog(existing: c.entries.first);
                            } else {
                              _openCustomerDrillDown(c);
                            }
                          },
                        ),
                        const SizedBox(width: 6),
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          ),
                          icon: const Icon(Icons.layers_outlined, size: 14),
                          label: Text('${c.entriesCount} Workers', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                          onPressed: () => _openCustomerDrillDown(c),
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
    );
  }

  // 4. CATEGORY-WISE SUMMARY TAB
  Widget _buildCategorySummaryTab(ThemeData theme, List<TeamWorkExpense> expenses) {
    final summaries = TeamWorkService.buildCategorySummaries(expenses);
    final grandTotal = summaries.fold<double>(0.0, (sum, c) => sum + c.totalExpense);
    final allSites = expenses.map((e) => ConsumerNoNormalizer.normalize(e.consumerNo)).where((s) => s.isNotEmpty).toSet();
    final allWorkers = expenses.map((e) => e.teamMemberName.trim().toLowerCase()).where((w) => w.isNotEmpty).toSet();

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'WORK CATEGORY EXPENSE BREAKDOWN',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 0.5),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: SingleChildScrollView(
                child: DataTable(
                  headingRowColor: WidgetStateProperty.all(Colors.blueGrey.shade50),
                  columns: const [
                    DataColumn(label: Text('Work Category', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(numeric: true, label: Text('Total Workers', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(numeric: true, label: Text('Total Sites', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(numeric: true, label: Text('Total Expense (₹)', style: TextStyle(fontWeight: FontWeight.bold))),
                  ],
                  rows: [
                    ...summaries.map((cat) {
                      final color = cat.workCategory == 'Structure'
                          ? Colors.purple.shade800
                          : (cat.workCategory == 'Wiring' ? Colors.amber.shade900 : Colors.teal.shade800);
                      return DataRow(
                        cells: [
                          DataCell(Row(
                            children: [
                              Icon(
                                cat.workCategory == 'Structure'
                                    ? Icons.architecture
                                    : (cat.workCategory == 'Wiring' ? Icons.electric_bolt : Icons.foundation),
                                size: 18,
                                color: color,
                              ),
                              const SizedBox(width: 8),
                              Text(cat.workCategory, style: TextStyle(fontWeight: FontWeight.bold, color: color)),
                            ],
                          )),
                          DataCell(Text('${cat.totalWorkers}')),
                          DataCell(Text('${cat.totalSites}')),
                          DataCell(Text(
                            _currency.format(cat.totalExpense),
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          )),
                        ],
                      );
                    }),
                    // GRAND TOTAL ROW
                    DataRow(
                      color: WidgetStateProperty.all(const Color(0xFFD1FAE5)),
                      cells: [
                        const DataCell(Text('GRAND TOTAL', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF064E3B)))),
                        DataCell(Text('${allWorkers.length}', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF064E3B)))),
                        DataCell(Text('${allSites.length}', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF064E3B)))),
                        DataCell(Text(
                          _currency.format(grandTotal),
                          style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF064E3B)),
                        )),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
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
  final bool isHighlight;
  final bool isSelected;
  final VoidCallback? onTap;

  const _MetricCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.bgColor,
    this.isHighlight = false,
    this.isSelected = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? color : (isHighlight ? color.withValues(alpha: 0.5) : Colors.transparent),
            width: isSelected ? 2 : 1,
          ),
        ),
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
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isHighlight ? color : Colors.black87,
              ),
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

// ==========================================
// ADD / EDIT WORK ENTRY DIALOG
// ==========================================

class _AddEditWorkEntryDialog extends StatefulWidget {
  final TeamWorkExpense? existing;
  final ConsumerRecord? preselectedCustomer;
  final List<ConsumerRecord> availableCustomers;
  final List<TeamMember> teamMembers;
  final Future<TeamWorkExpense> Function(TeamWorkExpense) onSave;

  const _AddEditWorkEntryDialog({
    this.existing,
    this.preselectedCustomer,
    required this.availableCustomers,
    required this.teamMembers,
    required this.onSave,
  });

  @override
  State<_AddEditWorkEntryDialog> createState() => _AddEditWorkEntryDialogState();
}

class _AddEditWorkEntryDialogState extends State<_AddEditWorkEntryDialog> {
  final _formKey = GlobalKey<FormState>();

  ConsumerRecord? _selectedCustomer;
  final TextEditingController _customerSearchCtrl = TextEditingController();
  final TextEditingController _consumerNoCtrl = TextEditingController();
  final TextEditingController _customerNameCtrl = TextEditingController();
  final TextEditingController _siteLocationCtrl = TextEditingController();
  final TextEditingController _solarCapacityCtrl = TextEditingController();
  final TextEditingController _expenseAmountCtrl = TextEditingController();
  final TextEditingController _remarksCtrl = TextEditingController();

  DateTime _workDate = DateTime.now();
  String _workCategory = 'Structure'; // 'Structure', 'Wiring', 'Civil'
  String? _selectedTeamMemberName;
  String? _selectedTeamMemberId;

  bool _isSaving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    if (widget.existing != null) {
      final e = widget.existing!;
      _consumerNoCtrl.text = e.consumerNo;
      _customerNameCtrl.text = e.customerName;
      _siteLocationCtrl.text = e.siteLocation;
      _solarCapacityCtrl.text = e.solarCapacity;
      _workDate = e.workDate;
      _workCategory = e.workCategory;
      _selectedTeamMemberName = e.teamMemberName;
      _selectedTeamMemberId = e.teamMemberId;
      _expenseAmountCtrl.text = e.individualExpense.toStringAsFixed(0);
      _remarksCtrl.text = e.remarks;

      // Match customer
      final norm = ConsumerNoNormalizer.normalize(e.consumerNo);
      _selectedCustomer = widget.availableCustomers.cast<ConsumerRecord?>().firstWhere(
            (c) => c != null && ConsumerNoNormalizer.normalize(c.consumerNo) == norm,
            orElse: () => null,
          );
    } else if (widget.preselectedCustomer != null) {
      _applyCustomer(widget.preselectedCustomer!);
    } else if (widget.teamMembers.isNotEmpty) {
      _selectedTeamMemberName = widget.teamMembers.first.name;
      _selectedTeamMemberId = widget.teamMembers.first.id;
    }
  }

  void _applyCustomer(ConsumerRecord c) {
    setState(() {
      _selectedCustomer = c;
      _consumerNoCtrl.text = c.consumerNo;
      _customerNameCtrl.text = c.name;
      _siteLocationCtrl.text = c.address ?? c.village ?? '';
      _solarCapacityCtrl.text = c.systemCapacity?.isNotEmpty == true
          ? c.systemCapacity!
          : (c.capacityKw > 0 ? '${c.capacityKw} kW' : '3 kW');
    });
  }

  @override
  void dispose() {
    _customerSearchCtrl.dispose();
    _consumerNoCtrl.dispose();
    _customerNameCtrl.dispose();
    _siteLocationCtrl.dispose();
    _solarCapacityCtrl.dispose();
    _expenseAmountCtrl.dispose();
    _remarksCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedTeamMemberName == null || _selectedTeamMemberName!.trim().isEmpty) {
      setState(() => _errorMessage = 'Please select a Team Member.');
      return;
    }

    final amount = double.tryParse(_expenseAmountCtrl.text.replaceAll(',', '').trim()) ?? 0.0;
    if (amount <= 0) {
      setState(() => _errorMessage = 'Please enter a valid expense amount greater than ₹0.');
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      final entry = TeamWorkExpense(
        id: widget.existing?.id ?? '',
        consumerId: _selectedCustomer?.id,
        consumerNo: _consumerNoCtrl.text.trim(),
        customerName: _customerNameCtrl.text.trim(),
        siteLocation: _siteLocationCtrl.text.trim(),
        solarCapacity: _solarCapacityCtrl.text.trim(),
        workDate: _workDate,
        workCategory: _workCategory,
        teamMemberId: _selectedTeamMemberId,
        teamMemberName: _selectedTeamMemberName!.trim(),
        individualExpense: amount,
        remarks: _remarksCtrl.text.trim(),
      );

      final saved = await widget.onSave(entry);
      if (mounted) {
        Navigator.pop(context, saved);
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
    final isEdit = widget.existing != null;
    final activeMembers = widget.teamMembers.where((m) => m.isActive).toList();

    return AlertDialog(
      title: Row(
        children: [
          Icon(isEdit ? Icons.edit_note_rounded : Icons.add_task_rounded, color: const Color(0xFF1E3A8A)),
          const SizedBox(width: 8),
          Text(isEdit ? 'Edit Team Work Entry' : 'Add Individual Work Entry'),
        ],
      ),
      content: SizedBox(
        width: 600,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_errorMessage != null) ...[
                  Container(
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
                        Expanded(child: Text(_errorMessage!, style: const TextStyle(color: Colors.red, fontSize: 12))),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                // 1. CUSTOMER SELECTION
                const Text('1. CUSTOMER / SITE SELECTION', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
                const SizedBox(height: 8),

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
                    if (_customerNameCtrl.text.isNotEmpty && controller.text.isEmpty) {
                      controller.text = '${_customerNameCtrl.text} (${_consumerNoCtrl.text})';
                    }
                    return TextFormField(
                      controller: controller,
                      focusNode: focusNode,
                      decoration: const InputDecoration(
                        labelText: 'Search Customer by Name or Consumer No. *',
                        prefixIcon: Icon(Icons.person_search_outlined),
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) {
                        if (_consumerNoCtrl.text.isEmpty || _customerNameCtrl.text.isEmpty) {
                          return 'Please select a customer';
                        }
                        return null;
                      },
                    );
                  },
                ),
                const SizedBox(height: 10),

                // Customer details preview
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _consumerNoCtrl,
                        readOnly: true,
                        decoration: const InputDecoration(
                          labelText: 'Consumer No.',
                          filled: true,
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextFormField(
                        controller: _solarCapacityCtrl,
                        readOnly: true,
                        decoration: const InputDecoration(
                          labelText: 'Solar Capacity',
                          filled: true,
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _siteLocationCtrl,
                  readOnly: true,
                  decoration: const InputDecoration(
                    labelText: 'Site Location',
                    filled: true,
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 16),

                // 2. WORK CATEGORY
                const Text('2. WORK CATEGORY (Select one for this entry)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
                const SizedBox(height: 6),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'Structure', label: Text('Structure'), icon: Icon(Icons.architecture, size: 16)),
                    ButtonSegment(value: 'Wiring', label: Text('Wiring'), icon: Icon(Icons.electric_bolt, size: 16)),
                    ButtonSegment(value: 'Civil', label: Text('Civil'), icon: Icon(Icons.foundation, size: 16)),
                  ],
                  selected: {_workCategory},
                  onSelectionChanged: (set) => setState(() => _workCategory = set.first),
                ),
                const SizedBox(height: 16),

                // 3. TEAM MEMBER & WORK EXPENSE
                const Text('3. TEAM MEMBER & EXPENSE ENTRY', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
                const SizedBox(height: 8),

                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Team Member dropdown
                    Expanded(
                      flex: 3,
                      child: DropdownButtonFormField<String>(
                        initialValue: activeMembers.any((m) => m.name == _selectedTeamMemberName)
                            ? _selectedTeamMemberName
                            : (activeMembers.isNotEmpty ? activeMembers.first.name : null),
                        decoration: const InputDecoration(
                          labelText: 'Select Team Member *',
                          prefixIcon: Icon(Icons.badge_outlined),
                          border: OutlineInputBorder(),
                        ),
                        items: activeMembers.map((m) {
                          return DropdownMenuItem(value: m.name, child: Text(m.name));
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            final m = activeMembers.firstWhere((element) => element.name == val);
                            setState(() {
                              _selectedTeamMemberName = m.name;
                              _selectedTeamMemberId = m.id;
                            });
                          }
                        },
                        validator: (v) => v == null || v.isEmpty ? 'Please select a team member' : null,
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Individual Expense Amount
                    Expanded(
                      flex: 2,
                      child: TextFormField(
                        controller: _expenseAmountCtrl,
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        decoration: const InputDecoration(
                          labelText: 'Individual Expense *',
                          prefixText: '₹ ',
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'Enter amount';
                          final num = double.tryParse(v.trim());
                          if (num == null || num <= 0) return 'Must be > 0';
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // 4. DATE & REMARKS
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                        ),
                        icon: const Icon(Icons.calendar_today, size: 16),
                        label: Text('Date: ${DateFormat('dd-MM-yyyy').format(_workDate)}'),
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: _workDate,
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2035),
                          );
                          if (picked != null) setState(() => _workDate = picked);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                TextFormField(
                  controller: _remarksCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Remarks (Optional)',
                    border: OutlineInputBorder(),
                    hintText: 'e.g. Structure foundation completed, cable laid...',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF1E3A8A),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          ),
          onPressed: _isSaving ? null : _submit,
          child: _isSaving
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : Text(isEdit ? 'Update Entry' : 'Save Work Entry'),
        ),
      ],
    );
  }
}

// ==========================================
// VIEW WORK ENTRY DIALOG
// ==========================================

class _ViewWorkEntryDialog extends StatelessWidget {
  final TeamWorkExpense entry;
  final VoidCallback onEdit;
  const _ViewWorkEntryDialog({required this.entry, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(locale: 'en_IN', symbol: '₹ ', decimalDigits: 2);
    final dateFormat = DateFormat('dd-MM-yyyy');

    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.info_outline, color: Color(0xFF1E3A8A)),
          const SizedBox(width: 8),
          Expanded(child: Text('${entry.workCategory} Entry: ${entry.teamMemberName}')),
        ],
      ),
      content: SizedBox(
        width: 480,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _row('Customer Name:', entry.customerName),
            _row('Consumer No.:', entry.consumerNo),
            _row('Site Location:', entry.siteLocation.isNotEmpty ? entry.siteLocation : '-'),
            _row('Solar Capacity:', entry.solarCapacity.isNotEmpty ? entry.solarCapacity : '-'),
            const Divider(),
            _row('Work Category:', entry.workCategory, isBold: true),
            _row('Team Member:', entry.teamMemberName, isBold: true),
            _row('Individual Expense:', currency.format(entry.individualExpense), color: const Color(0xFF064E3B)),
            _row('Work Date:', dateFormat.format(entry.workDate)),
            _row('Remarks:', entry.remarks.isNotEmpty ? entry.remarks : '-'),
          ],
        ),
      ),
      actions: [
        OutlinedButton.icon(
          icon: const Icon(Icons.edit_outlined, size: 16),
          label: const Text('Edit Entry'),
          onPressed: () {
            Navigator.pop(context);
            onEdit();
          },
        ),
        FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
      ],
    );
  }

  Widget _row(String label, String value, {bool isBold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 140, child: Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13))),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
                color: color ?? Colors.black87,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ==========================================
// TEAM MEMBER MASTER MANAGEMENT DIALOG
// ==========================================

class _TeamMemberMasterDialog extends StatefulWidget {
  final List<TeamMember> members;
  final VoidCallback onMembersChanged;

  const _TeamMemberMasterDialog({required this.members, required this.onMembersChanged});

  @override
  State<_TeamMemberMasterDialog> createState() => _TeamMemberMasterDialogState();
}

class _TeamMemberMasterDialogState extends State<_TeamMemberMasterDialog> {
  late List<TeamMember> _list;
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _list = List.from(widget.members);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _addOrEditMember({TeamMember? member}) async {
    final nameCtrl = TextEditingController(text: member?.name ?? '');
    final phoneCtrl = TextEditingController(text: member?.phone ?? '');
    final notesCtrl = TextEditingController(text: member?.notes ?? '');

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(member == null ? 'Add Team Member' : 'Edit Team Member'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: 'Member Name *', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: phoneCtrl,
              decoration: const InputDecoration(labelText: 'Phone Number (Optional)', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: notesCtrl,
              decoration: const InputDecoration(labelText: 'Notes (Optional)', border: OutlineInputBorder()),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              if (nameCtrl.text.trim().isNotEmpty) Navigator.pop(ctx, true);
            },
            child: const Text('Save Member'),
          ),
        ],
      ),
    );

    if (saved == true && nameCtrl.text.trim().isNotEmpty) {
      final toSave = TeamMember(
        id: member?.id ?? '',
        name: nameCtrl.text.trim(),
        phone: phoneCtrl.text.trim().isNotEmpty ? phoneCtrl.text.trim() : null,
        notes: notesCtrl.text.trim().isNotEmpty ? notesCtrl.text.trim() : null,
        isActive: member?.isActive ?? true,
      );
      await TeamWorkService.saveTeamMember(toSave);
      final refreshed = await TeamWorkService.fetchTeamMembers();
      setState(() => _list = refreshed);
      widget.onMembersChanged();
    }
  }

  @override
  Widget build(BuildContext context) {
    final query = _searchCtrl.text.trim().toLowerCase();
    final filtered = _list.where((m) => m.name.toLowerCase().contains(query)).toList();

    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.people_alt_outlined, color: Color(0xFF1E3A8A)),
          const SizedBox(width: 8),
          const Text('Team Member Master'),
          const Spacer(),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFF1E3A8A)),
            icon: const Icon(Icons.person_add_rounded, size: 16),
            label: const Text('Add Member'),
            onPressed: () => _addOrEditMember(),
          ),
        ],
      ),
      content: SizedBox(
        width: 520,
        height: 400,
        child: Column(
          children: [
            TextField(
              controller: _searchCtrl,
              decoration: const InputDecoration(
                hintText: 'Search team member...',
                prefixIcon: Icon(Icons.search, size: 18),
                isDense: true,
                border: OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: ListView.separated(
                itemCount: filtered.length,
                separatorBuilder: (_, index) => const Divider(height: 1),
                itemBuilder: (_, i) {
                  final m = filtered[i];
                  return ListTile(
                    dense: true,
                    leading: CircleAvatar(
                      radius: 14,
                      backgroundColor: m.isActive ? Colors.indigo.shade100 : Colors.grey.shade300,
                      child: Text(
                        m.name.isNotEmpty ? m.name[0].toUpperCase() : '?',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: m.isActive ? Colors.indigo.shade900 : Colors.grey.shade700,
                        ),
                      ),
                    ),
                    title: Text(
                      m.name,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        decoration: m.isActive ? null : TextDecoration.lineThrough,
                        color: m.isActive ? null : Colors.grey,
                      ),
                    ),
                    subtitle: Text(m.notes ?? (m.phone ?? 'Active team member')),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit_outlined, size: 18, color: Colors.indigo),
                          tooltip: 'Edit Member',
                          onPressed: () => _addOrEditMember(member: m),
                        ),
                        Switch(
                          value: m.isActive,
                          onChanged: (val) async {
                            await TeamWorkService.toggleTeamMemberActive(m.id, val);
                            setState(() {
                              final idx = _list.indexWhere((element) => element.id == m.id);
                              if (idx >= 0) _list[idx] = _list[idx].copyWith(isActive: val);
                            });
                            widget.onMembersChanged();
                          },
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
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
      ],
    );
  }
}

// ==========================================
// CUSTOMER DRILL DOWN DIALOG
// ==========================================

class _CustomerWorkDrillDownDialog extends StatelessWidget {
  final CustomerExpenseSummary customerSummary;
  final VoidCallback onAddEntry;
  final Function(TeamWorkExpense) onEditEntry;
  final Function(TeamWorkExpense) onDeleteEntry;

  const _CustomerWorkDrillDownDialog({
    required this.customerSummary,
    required this.onAddEntry,
    required this.onEditEntry,
    required this.onDeleteEntry,
  });

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(locale: 'en_IN', symbol: '₹ ', decimalDigits: 0);
    final dateFormat = DateFormat('dd-MM-yyyy');

    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.location_on_rounded, color: Color(0xFF1E3A8A)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(customerSummary.customerName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                Text(
                  'Consumer No: ${customerSummary.consumerNo} • Location: ${customerSummary.siteLocation}',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.add, size: 14, color: Colors.white),
            label: const Text('+ Add Worker', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0D9488),
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            ),
            onPressed: onAddEntry,
          ),
        ],
      ),
      content: SizedBox(
        width: 650,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Totals Banner
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFECFDF5),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFA7F3D0)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _metric('Structure', currency.format(customerSummary.structureExpense), Colors.purple.shade900),
                  _metric('Wiring', currency.format(customerSummary.wiringExpense), Colors.amber.shade900),
                  _metric('Civil', currency.format(customerSummary.civilExpense), Colors.teal.shade900),
                  _metric('Total Site Expense', currency.format(customerSummary.totalSiteExpense), const Color(0xFF064E3B), isBold: true),
                ],
              ),
            ),
            const SizedBox(height: 14),

            const Text('INDIVIDUAL WORKER ENTRIES FOR THIS SITE:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
            const SizedBox(height: 6),

            SizedBox(
              height: 240,
              child: ListView.separated(
                itemCount: customerSummary.entries.length,
                separatorBuilder: (_, index) => const Divider(height: 1),
                itemBuilder: (_, i) {
                  final e = customerSummary.entries[i];
                  return ListTile(
                    dense: true,
                    leading: CircleAvatar(
                      radius: 14,
                      backgroundColor: Colors.blue.shade100,
                      child: Text(
                        e.teamMemberName.isNotEmpty ? e.teamMemberName[0].toUpperCase() : '?',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blue.shade900),
                      ),
                    ),
                    title: Row(
                      children: [
                        Text(e.teamMemberName, style: const TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.blueGrey.shade50,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(e.workCategory, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                        ),
                        const Spacer(),
                        Text(
                          currency.format(e.individualExpense),
                          style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF064E3B)),
                        ),
                      ],
                    ),
                    subtitle: Text('${dateFormat.format(e.workDate)} ${e.remarks.isNotEmpty ? "• ${e.remarks}" : ""}'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ElevatedButton.icon(
                          icon: const Icon(Icons.edit_outlined, size: 13, color: Colors.white),
                          label: const Text('Edit', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1E3A8A),
                            visualDensity: VisualDensity.compact,
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          ),
                          onPressed: () => onEditEntry(e),
                        ),
                        const SizedBox(width: 4),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, size: 16, color: Colors.red),
                          tooltip: 'Delete',
                          onPressed: () => onDeleteEntry(e),
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
      actions: [
        FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
      ],
    );
  }

  Widget _metric(String label, String value, Color color, {bool isBold = false}) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
        const SizedBox(height: 2),
        Text(value, style: TextStyle(fontSize: 13, fontWeight: isBold ? FontWeight.bold : FontWeight.w600, color: color)),
      ],
    );
  }
}
