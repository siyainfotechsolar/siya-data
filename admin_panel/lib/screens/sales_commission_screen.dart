import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../models/sales_commission.dart';
import '../models/consumer_record.dart';
import '../models/user_profile.dart';
import '../services/sales_commission_service.dart';
import '../services/sales_commission_excel_service.dart';
import '../utils/responsive.dart';

class SalesCommissionScreen extends StatefulWidget {
  const SalesCommissionScreen({super.key});

  @override
  State<SalesCommissionScreen> createState() => _SalesCommissionScreenState();
}

class _SalesCommissionScreenState extends State<SalesCommissionScreen> {
  final NumberFormat _currency = NumberFormat.currency(locale: 'en_IN', symbol: '₹ ', decimalDigits: 0);
  final DateFormat _dateFormat = DateFormat('dd/MM/yyyy');

  List<SalesCommission> _allCommissions = [];
  List<ConsumerRecord> _availableConsumers = [];
  List<UserProfile> _availableStaff = [];
  bool _isLoading = false;
  bool _isExporting = false;
  String? _errorMessage;

  // Filter controllers & states
  final TextEditingController _searchCtrl = TextEditingController();
  final TextEditingController _consumerNoSearchCtrl = TextEditingController();
  final TextEditingController _salesPersonSearchCtrl = TextEditingController();
  String _selectedSourceFilter = 'All'; // 'All', 'Sales Person', 'Direct Customer'
  String _selectedStatusFilter = 'All'; // 'All', 'Pending', 'Completed', 'Not Applicable'
  String? _selectedSalesPersonFilter; // Specific sales person filter or null
  DateTime? _filterStartDate;
  DateTime? _filterEndDate;

  // UI state for showing/hiding Sales Person Summary breakdown
  bool _showSalesPersonSummaryCard = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _consumerNoSearchCtrl.dispose();
    _salesPersonSearchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final results = await Future.wait([
        SalesCommissionService.fetchCommissions(),
        SalesCommissionService.fetchAvailableCustomers(),
        SalesCommissionService.fetchAvailableStaff(),
      ]);

      if (mounted) {
        setState(() {
          _allCommissions = results[0] as List<SalesCommission>;
          _availableConsumers = results[1] as List<ConsumerRecord>;
          _availableStaff = results[2] as List<UserProfile>;
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

  /// Filtered commissions matching all active search and filter parameters
  List<SalesCommission> get _filteredCommissions {
    final nameQuery = _searchCtrl.text.trim().toLowerCase();
    final noQuery = _consumerNoSearchCtrl.text.trim().toLowerCase();
    final spQuery = _salesPersonSearchCtrl.text.trim().toLowerCase();

    return _allCommissions.where((comm) {
      // 1. Customer Name search
      if (nameQuery.isNotEmpty && !comm.customerName.toLowerCase().contains(nameQuery)) {
        return false;
      }

      // 2. Consumer Number search
      if (noQuery.isNotEmpty && !comm.consumerNo.toLowerCase().contains(noQuery)) {
        return false;
      }

      // 3. Sales Person Name search
      if (spQuery.isNotEmpty) {
        final spName = (comm.salesPersonName ?? '').toLowerCase();
        if (!spName.contains(spQuery)) return false;
      }

      // 4. Customer Source filter
      if (_selectedSourceFilter != 'All' && comm.customerSource != _selectedSourceFilter) {
        return false;
      }

      // 5. Commission Status filter
      if (_selectedStatusFilter != 'All' && comm.commissionStatus != _selectedStatusFilter) {
        return false;
      }

      // 6. Specific Sales Person filter
      if (_selectedSalesPersonFilter != null) {
        if (comm.salesPersonName?.trim().toLowerCase() != _selectedSalesPersonFilter!.trim().toLowerCase()) {
          return false;
        }
      }

      // 7. Date range filter
      if (_filterStartDate != null) {
        final start = DateTime(_filterStartDate!.year, _filterStartDate!.month, _filterStartDate!.day);
        if (comm.commissionDate.isBefore(start)) return false;
      }
      if (_filterEndDate != null) {
        final end = DateTime(_filterEndDate!.year, _filterEndDate!.month, _filterEndDate!.day, 23, 59, 59);
        if (comm.commissionDate.isAfter(end)) return false;
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
      parts.add('Customer: "${_searchCtrl.text.trim()}"');
    }
    if (_consumerNoSearchCtrl.text.trim().isNotEmpty) {
      parts.add('Consumer No: "${_consumerNoSearchCtrl.text.trim()}"');
    }
    if (_salesPersonSearchCtrl.text.trim().isNotEmpty) {
      parts.add('Sales Person: "${_salesPersonSearchCtrl.text.trim()}"');
    }
    if (_selectedSourceFilter != 'All') {
      parts.add('Source: $_selectedSourceFilter');
    }
    if (_selectedStatusFilter != 'All') {
      parts.add('Status: $_selectedStatusFilter');
    }
    if (_selectedSalesPersonFilter != null) {
      parts.add('Sales Person: $_selectedSalesPersonFilter');
    }
    return parts.isEmpty ? 'All Records (No Filters)' : parts.join(' | ');
  }

  void _resetFilters() {
    setState(() {
      _searchCtrl.clear();
      _consumerNoSearchCtrl.clear();
      _salesPersonSearchCtrl.clear();
      _selectedSourceFilter = 'All';
      _selectedStatusFilter = 'All';
      _selectedSalesPersonFilter = null;
      _filterStartDate = null;
      _filterEndDate = null;
    });
  }

  Future<void> _handleExportExcel() async {
    final toExport = _filteredCommissions;
    if (toExport.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No commission records found to export.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isExporting = true);
    try {
      final success = await SalesCommissionExcelService.exportAndSave(
        commissions: toExport,
        filterSummary: _filterSummary,
      );

      if (mounted && success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Excel Report exported successfully! (${toExport.length} records, 5 sheets)'),
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

  void _openAddEditDialog({SalesCommission? existing, ConsumerRecord? initialConsumer}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _AddEditCommissionDialog(
        existing: existing,
        initialConsumer: initialConsumer,
        availableConsumers: _availableConsumers,
        availableStaff: _availableStaff,
        allCommissions: _allCommissions,
        onSaved: () {
          _loadData();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                existing == null
                    ? 'Sales commission record added successfully!'
                    : 'Sales commission record updated successfully!',
              ),
              backgroundColor: Colors.green,
            ),
          );
        },
      ),
    );
  }

  void _openViewDialog(SalesCommission commission) {
    showDialog(
      context: context,
      builder: (ctx) => _ViewCommissionDialog(commission: commission),
    );
  }

  Future<void> _handleDelete(SalesCommission commission) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.delete_outline, color: Colors.red),
            SizedBox(width: 8),
            Text('Confirm Delete'),
          ],
        ),
        content: Text(
          'Are you sure you want to delete the commission record for "${commission.customerName}" '
          '(Consumer No: ${commission.consumerNo})?\n\nThis will remove the commission tracking for this customer.',
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

    if (confirm != true) return;

    try {
      await SalesCommissionService.deleteCommission(commission.id);
      await _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Commission record deleted successfully.'),
            backgroundColor: Colors.orange,
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isMobile = Responsive.isMobile(context);
    final displayed = _filteredCommissions;
    final summary = CommissionDashboardSummary.fromCommissions(displayed);
    final salesPersonSummaries = CommissionDashboardSummary.buildSalesPersonSummaries(_allCommissions);

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
                          Icon(Icons.price_check_rounded, size: 28, color: theme.colorScheme.primary),
                          const SizedBox(width: 10),
                          Text(
                            isMobile ? 'Sales Commission' : 'Sales Person Commission Management',
                            style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(width: 12),
                          Chip(
                            backgroundColor: Colors.blue.shade50,
                            side: BorderSide(color: Colors.blue.shade200),
                            label: Text(
                              '${displayed.length} Customers',
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
                          'Track customer-wise and sales-person-wise commissions based on solar installation capacity (kW), direct customers, and pending commissions.',
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
                        isMobile ? 'Excel' : 'Export to Excel (5 Sheets)',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ),
                    // Add Commission Button
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: theme.colorScheme.primary,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                      onPressed: () => _openAddEditDialog(),
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: Text(
                        isMobile ? 'Add' : 'Add Commission',
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
            const SizedBox(height: 12),

            // SECTION 8: SALES PERSON-WISE SUMMARY (Toggleable Strip)
            if (salesPersonSummaries.isNotEmpty) ...[
              _buildSalesPersonSummarySection(theme, salesPersonSummaries, isMobile),
              const SizedBox(height: 12),
            ],

            // SECTION 9: SEARCH & FILTERS TOOLBAR
            _buildFiltersToolbar(theme, isMobile),
            const SizedBox(height: 12),

            // SECTION 6: MAIN SCREEN – COMPLETE CUSTOMER LIST
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
                                  Icon(Icons.person_search_outlined, size: 56, color: Colors.grey.shade400),
                                  const SizedBox(height: 12),
                                  const Text(
                                    'No customer commission records found',
                                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    _allCommissions.isEmpty
                                        ? 'Click "+ Add Commission" to create the first record.'
                                        : 'No records match the current filter criteria.',
                                    style: TextStyle(color: Colors.grey.shade600),
                                  ),
                                  if (_allCommissions.isNotEmpty) ...[
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
                              ? _buildMobileCommissionList(theme, displayed)
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
  Widget _buildDashboardMetricsBar(ThemeData theme, CommissionDashboardSummary summary, bool isMobile) {
    final cards = [
      _MetricCard(
        title: 'Total Customers',
        value: '${summary.totalCustomers}',
        subtitle: 'All Master Sites',
        icon: Icons.people_alt_outlined,
        color: Colors.blue.shade800,
        bgColor: Colors.blue.shade50,
      ),
      _MetricCard(
        title: 'Sales Person Customers',
        value: '${summary.salesPersonCustomers}',
        subtitle: 'Referred Customers',
        icon: Icons.badge_outlined,
        color: Colors.indigo.shade800,
        bgColor: Colors.indigo.shade50,
        onTap: () => setState(() => _selectedSourceFilter = 'Sales Person'),
      ),
      _MetricCard(
        title: 'Direct Customers',
        value: '${summary.directCustomers}',
        subtitle: 'No Commission Required',
        icon: Icons.domain_outlined,
        color: Colors.teal.shade800,
        bgColor: Colors.teal.shade50,
        onTap: () => setState(() => _selectedSourceFilter = 'Direct Customer'),
      ),
      _MetricCard(
        title: 'Total Installed Capacity',
        value: '${summary.totalInstalledCapacityKw.toStringAsFixed(1)} kW',
        subtitle: 'All Customer Sites',
        icon: Icons.solar_power_outlined,
        color: Colors.orange.shade800,
        bgColor: Colors.orange.shade50,
      ),
      _MetricCard(
        title: 'Pending Commission Sites',
        value: '${summary.pendingCommissionCustomers}',
        subtitle: 'Awaiting Finalization',
        icon: Icons.hourglass_top_rounded,
        color: Colors.amber.shade900,
        bgColor: Colors.amber.shade50,
        onTap: () => setState(() => _selectedStatusFilter = 'Pending'),
      ),
      _MetricCard(
        title: 'Completed Commission Sites',
        value: '${summary.completedCommissionCustomers}',
        subtitle: 'Finalized Commission Records',
        icon: Icons.check_circle_outline,
        color: Colors.green.shade800,
        bgColor: Colors.green.shade50,
        onTap: () => setState(() => _selectedStatusFilter = 'Completed'),
      ),
      _MetricCard(
        title: 'Not Applicable Sites',
        value: '${summary.notApplicableCustomers}',
        subtitle: 'Direct Customers',
        icon: Icons.block_outlined,
        color: Colors.blueGrey.shade700,
        bgColor: Colors.blueGrey.shade50,
        onTap: () => setState(() => _selectedStatusFilter = 'Not Applicable'),
      ),
      _MetricCard(
        title: 'Total Pending Commission',
        value: _currency.format(summary.totalPendingCommissionAmount),
        subtitle: 'Pending Payout (Direct Excluded)',
        icon: Icons.pending_actions_rounded,
        color: const Color(0xFFB45309), // Amber dark
        bgColor: const Color(0xFFFEF3C7),
      ),
      _MetricCard(
        title: 'Total Commission Amount',
        value: _currency.format(summary.totalCommissionAmount),
        subtitle: 'All Sales Person Records',
        icon: Icons.account_balance_wallet_rounded,
        color: const Color(0xFF064E3B),
        bgColor: const Color(0xFFD1FAE5),
        isPrimary: true,
      ),
    ];

    return SizedBox(
      height: 110,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: cards.length,
        separatorBuilder: (context, index) => const SizedBox(width: 10),
        itemBuilder: (context, i) => SizedBox(width: isMobile ? 185 : 210, child: cards[i]),
      ),
    );
  }

  // =========================================================================
  // SECTION 8: SALES PERSON-WISE SUMMARY STRIP
  // =========================================================================
  Widget _buildSalesPersonSummarySection(ThemeData theme, List<SalesPersonSummary> summaries, bool isMobile) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: Colors.indigo.shade200),
      ),
      color: Colors.indigo.shade50.withValues(alpha: 0.5),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.leaderboard_rounded, size: 18, color: Colors.indigo.shade900),
                const SizedBox(width: 8),
                Text(
                  'Sales Person-Wise Summary (${summaries.length} Sales Persons)',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.indigo.shade900),
                ),
                const Spacer(),
                if (_selectedSalesPersonFilter != null) ...[
                  Chip(
                    avatar: const Icon(Icons.filter_alt, size: 14, color: Colors.white),
                    label: Text('Filtered: $_selectedSalesPersonFilter', style: const TextStyle(fontSize: 11, color: Colors.white)),
                    backgroundColor: Colors.indigo.shade800,
                    onDeleted: () => setState(() => _selectedSalesPersonFilter = null),
                    deleteIconColor: Colors.white70,
                    visualDensity: VisualDensity.compact,
                  ),
                  const SizedBox(width: 8),
                ],
                IconButton(
                  icon: Icon(_showSalesPersonSummaryCard ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down, size: 18),
                  tooltip: _showSalesPersonSummaryCard ? 'Hide Summary' : 'Show Summary',
                  onPressed: () => setState(() => _showSalesPersonSummaryCard = !_showSalesPersonSummaryCard),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            if (_showSalesPersonSummaryCard) ...[
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: summaries.map((sp) {
                    final isSelected = _selectedSalesPersonFilter?.toLowerCase() == sp.salesPersonName.toLowerCase();
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: InkWell(
                        onTap: () {
                          setState(() {
                            if (isSelected) {
                              _selectedSalesPersonFilter = null;
                            } else {
                              _selectedSalesPersonFilter = sp.salesPersonName;
                            }
                          });
                        },
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: isSelected ? Colors.indigo.shade800 : Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isSelected ? Colors.indigo.shade900 : Colors.indigo.shade200,
                              width: isSelected ? 1.5 : 1.0,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                sp.salesPersonName,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  color: isSelected ? Colors.white : Colors.indigo.shade900,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${sp.totalCustomers} Sites • ${sp.totalCapacityKw.toStringAsFixed(1)} kW',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isSelected ? Colors.white70 : Colors.grey.shade700,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  Text(
                                    'Total: ${_currency.format(sp.totalCommission)}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: isSelected ? Colors.amber.shade200 : const Color(0xFF064E3B),
                                    ),
                                  ),
                                  if (sp.pendingCommission > 0) ...[
                                    const SizedBox(width: 6),
                                    Text(
                                      '(Pending: ${_currency.format(sp.pendingCommission)})',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                        color: isSelected ? Colors.orange.shade200 : Colors.amber.shade900,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // =========================================================================
  // SECTION 9: SEARCH AND FILTERS TOOLBAR
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
                      labelText: 'Search Customer Name',
                      prefixIcon: const Icon(Icons.search, size: 18),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      isDense: true,
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 8),

                // 2. Consumer Number Search
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: _consumerNoSearchCtrl,
                    decoration: InputDecoration(
                      labelText: 'Consumer Number',
                      prefixIcon: const Icon(Icons.tag, size: 18),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      isDense: true,
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 8),

                // 3. Sales Person Name Search
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: _salesPersonSearchCtrl,
                    decoration: InputDecoration(
                      labelText: 'Sales Person Name',
                      prefixIcon: const Icon(Icons.person_search_outlined, size: 18),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      isDense: true,
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            Row(
              children: [
                // 4. Customer Source Filter
                Expanded(
                  flex: 2,
                  child: DropdownButtonFormField<String>(
                    // ignore: deprecated_member_use
                    value: _selectedSourceFilter,
                    decoration: InputDecoration(
                      labelText: 'Customer Source',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      isDense: true,
                    ),
                    items: const [
                      DropdownMenuItem(value: 'All', child: Text('All Sources')),
                      DropdownMenuItem(value: 'Sales Person', child: Text('Sales Person')),
                      DropdownMenuItem(value: 'Direct Customer', child: Text('Direct Customer')),
                    ],
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedSourceFilter = val);
                    },
                  ),
                ),
                const SizedBox(width: 8),

                // 5. Commission Status Filter
                Expanded(
                  flex: 2,
                  child: DropdownButtonFormField<String>(
                    // ignore: deprecated_member_use
                    value: _selectedStatusFilter,
                    decoration: InputDecoration(
                      labelText: 'Commission Status',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      isDense: true,
                    ),
                    items: const [
                      DropdownMenuItem(value: 'All', child: Text('All Statuses')),
                      DropdownMenuItem(value: 'Pending', child: Text('Pending Commission')),
                      DropdownMenuItem(value: 'Completed', child: Text('Completed')),
                      DropdownMenuItem(value: 'Not Applicable', child: Text('Not Applicable')),
                    ],
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedStatusFilter = val);
                    },
                  ),
                ),
                const SizedBox(width: 8),

                // 6. Date Range Picker
                Expanded(
                  flex: 3,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: const Icon(Icons.date_range_outlined, size: 16),
                    label: Text(
                      _filterStartDate == null
                          ? 'Date: All Dates'
                          : '${_dateFormat.format(_filterStartDate!)} - ${_dateFormat.format(_filterEndDate!)}',
                      style: const TextStyle(fontSize: 12),
                      overflow: TextOverflow.ellipsis,
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
                ),
                const SizedBox(width: 8),

                // 7. Reset Filters Button
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: const Icon(Icons.clear_all_rounded, size: 16),
                  label: const Text('Reset', style: TextStyle(fontSize: 12)),
                  onPressed: _resetFilters,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // =========================================================================
  // SECTION 6: DESKTOP DATA TABLE (ALL CUSTOMERS TOGETHER)
  // =========================================================================
  Widget _buildDesktopDataTable(ThemeData theme, List<SalesCommission> commissions, CommissionDashboardSummary summary) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        children: [
          // Table header banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.blueGrey.shade50,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
              border: Border(bottom: BorderSide(color: Colors.blueGrey.shade200)),
            ),
            child: Row(
              children: [
                const Icon(Icons.table_chart_outlined, size: 18, color: Colors.blueGrey),
                const SizedBox(width: 8),
                Text(
                  'Customer Commission List (${commissions.length} Records)',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const Spacer(),
                Text(
                  'Sales Person: ${summary.salesPersonCustomers} | Direct: ${summary.directCustomers} | Pending: ${summary.pendingCommissionCustomers}',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade700, fontWeight: FontWeight.w500),
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
                  headingRowColor: WidgetStateProperty.all(const Color(0xFF1E3A8A)),
                  headingTextStyle: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 12),
                  columns: const [
                    DataColumn(label: Text('Sr. No.')),
                    DataColumn(label: Text('Customer Name')),
                    DataColumn(label: Text('Consumer No.')),
                    DataColumn(label: Text('Customer Source')),
                    DataColumn(label: Text('Sales Person')),
                    DataColumn(label: Text('Capacity (kW)')),
                    DataColumn(label: Text('Rate / kW (₹)')),
                    DataColumn(label: Text('Total Commission (₹)')),
                    DataColumn(label: Text('Status')),
                    DataColumn(label: Text('Date')),
                    DataColumn(label: Text('Remarks')),
                    DataColumn(label: Text('Actions')),
                  ],
                  rows: [
                    ...List.generate(commissions.length, (idx) {
                      final c = commissions[idx];
                      final isEven = (idx % 2 == 0);
                      final rowColor = isEven ? Colors.white : const Color(0xFFF8FAFC);

                      return DataRow(
                        color: WidgetStateProperty.all(rowColor),
                        cells: [
                          DataCell(Text('${idx + 1}')),
                          DataCell(Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                c.isDirectCustomer ? Icons.domain_outlined : Icons.person_outline,
                                size: 16,
                                color: c.isDirectCustomer ? Colors.teal : Colors.blue,
                              ),
                              const SizedBox(width: 6),
                              ConstrainedBox(
                                constraints: const BoxConstraints(maxWidth: 160),
                                child: Text(
                                  c.customerName,
                                  style: const TextStyle(fontWeight: FontWeight.w600),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          )),
                          DataCell(Text(c.consumerNo, style: const TextStyle(fontWeight: FontWeight.w500))),
                          DataCell(_buildSourceBadge(c.customerSource)),
                          DataCell(Text(c.isDirectCustomer ? '—' : (c.salesPersonName ?? '—'))),
                          DataCell(Text('${c.capacityKw.toStringAsFixed(1)} kW')),
                          DataCell(Text(c.isDirectCustomer ? '₹ 0' : _currency.format(c.commissionRatePerKw))),
                          DataCell(Text(
                            c.isDirectCustomer ? '₹ 0' : _currency.format(c.totalCommission),
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: c.isDirectCustomer ? Colors.grey : const Color(0xFF064E3B),
                            ),
                          )),
                          DataCell(_buildStatusBadge(c.commissionStatus)),
                          DataCell(Text(c.formattedDate, style: const TextStyle(fontSize: 11))),
                          DataCell(ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 130),
                            child: Text(
                              c.remarks ?? '—',
                              style: const TextStyle(fontSize: 11, color: Colors.grey),
                              overflow: TextOverflow.ellipsis,
                            ),
                          )),
                          DataCell(Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.visibility_outlined, size: 18, color: Colors.blue),
                                tooltip: 'View Details',
                                onPressed: () => _openViewDialog(c),
                              ),
                              IconButton(
                                icon: const Icon(Icons.edit_outlined, size: 18, color: Colors.indigo),
                                tooltip: 'Edit Record',
                                onPressed: () => _openAddEditDialog(existing: c),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                                tooltip: 'Delete',
                                onPressed: () => _handleDelete(c),
                              ),
                            ],
                          )),
                        ],
                      );
                    }),

                    // Grand Total Row
                    DataRow(
                      color: WidgetStateProperty.all(const Color(0xFFD1FAE5)),
                      cells: [
                        const DataCell(Text('')),
                        const DataCell(Text('GRAND TOTAL', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF064E3B)))),
                        DataCell(Text('${commissions.length} Sites', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF064E3B)))),
                        const DataCell(Text('')),
                        const DataCell(Text('')),
                        DataCell(Text('${summary.totalInstalledCapacityKw.toStringAsFixed(1)} kW', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF064E3B)))),
                        const DataCell(Text('')),
                        DataCell(
                          Text(
                            _currency.format(summary.totalCommissionAmount),
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF064E3B)),
                          ),
                        ),
                        DataCell(Text('Pending: ${_currency.format(summary.totalPendingCommissionAmount)}', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.amber.shade900))),
                        const DataCell(Text('')),
                        const DataCell(Text('')),
                        const DataCell(Text('')),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // MOBILE CARD LIST
  // =========================================================================
  Widget _buildMobileCommissionList(ThemeData theme, List<SalesCommission> commissions) {
    return ListView.separated(
      itemCount: commissions.length,
      separatorBuilder: (context, index) => const SizedBox(height: 8),
      itemBuilder: (context, idx) {
        final c = commissions[idx];
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
                        c.customerName,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    _buildStatusBadge(c.commissionStatus),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Consumer No: ${c.consumerNo} • ${c.solarCapacity} (${c.capacityKw} kW)',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    _buildSourceBadge(c.customerSource),
                    const SizedBox(width: 8),
                    if (!c.isDirectCustomer)
                      Text(
                        'Sales: ${c.salesPersonName ?? "—"}',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                      ),
                  ],
                ),
                const Divider(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      c.isDirectCustomer ? 'Direct: ₹0' : 'Rate: ${_currency.format(c.commissionRatePerKw)}/kW',
                      style: const TextStyle(fontSize: 12),
                    ),
                    Text(
                      'Commission: ${_currency.format(c.totalCommission)}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: c.isDirectCustomer ? Colors.grey : const Color(0xFF064E3B),
                      ),
                    ),
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
                      onPressed: () => _openViewDialog(c),
                    ),
                    const SizedBox(width: 6),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.edit_outlined, size: 14),
                      label: const Text('Edit', style: TextStyle(fontSize: 11)),
                      style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact),
                      onPressed: () => _openAddEditDialog(existing: c),
                    ),
                    const SizedBox(width: 6),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, size: 16, color: Colors.red),
                      onPressed: () => _handleDelete(c),
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

  Widget _buildSourceBadge(String source) {
    final isDirect = source == 'Direct Customer';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isDirect ? Colors.teal.shade50 : Colors.indigo.shade50,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: isDirect ? Colors.teal.shade300 : Colors.indigo.shade300),
      ),
      child: Text(
        source,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: isDirect ? Colors.teal.shade900 : Colors.indigo.shade900,
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color bg;
    Color border;
    Color text;
    IconData icon;

    switch (status) {
      case 'Pending':
        bg = Colors.amber.shade50;
        border = Colors.amber.shade400;
        text = Colors.amber.shade900;
        icon = Icons.hourglass_top_rounded;
        break;
      case 'Completed':
        bg = Colors.green.shade50;
        border = Colors.green.shade400;
        text = Colors.green.shade800;
        icon = Icons.check_circle_outline;
        break;
      case 'Not Applicable':
      default:
        bg = Colors.grey.shade100;
        border = Colors.grey.shade400;
        text = Colors.grey.shade800;
        icon = Icons.block_outlined;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: text),
          const SizedBox(width: 4),
          Text(status, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: text)),
        ],
      ),
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
  final VoidCallback? onTap;

  const _MetricCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.bgColor,
    this.isPrimary = false,
    this.onTap,
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
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
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
                  if (onTap != null)
                    Icon(Icons.arrow_forward_ios_rounded, size: 10, color: color.withValues(alpha: 0.6)),
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
      ),
    );
  }
}

// =============================================================================
// ADD / EDIT COMMISSION DIALOG
// =============================================================================
class _AddEditCommissionDialog extends StatefulWidget {
  final SalesCommission? existing;
  final ConsumerRecord? initialConsumer;
  final List<ConsumerRecord> availableConsumers;
  final List<UserProfile> availableStaff;
  final List<SalesCommission> allCommissions;
  final VoidCallback onSaved;

  const _AddEditCommissionDialog({
    this.existing,
    this.initialConsumer,
    required this.availableConsumers,
    required this.availableStaff,
    required this.allCommissions,
    required this.onSaved,
  });

  @override
  State<_AddEditCommissionDialog> createState() => _AddEditCommissionDialogState();
}

class _AddEditCommissionDialogState extends State<_AddEditCommissionDialog> {
  final _formKey = GlobalKey<FormState>();
  final NumberFormat _currency = NumberFormat.currency(locale: 'en_IN', symbol: '₹ ', decimalDigits: 0);

  ConsumerRecord? _selectedConsumer;
  late TextEditingController _nameCtrl;
  late TextEditingController _consumerNoCtrl;
  late TextEditingController _locationCtrl;
  late TextEditingController _capacityCtrl;
  late TextEditingController _capacityKwCtrl;
  late TextEditingController _rateCtrl;
  late TextEditingController _remarksCtrl;

  String _customerSource = 'Sales Person'; // 'Sales Person' or 'Direct Customer'
  String? _selectedSalesPersonName;
  String? _selectedSalesPersonId;
  String _commissionStatus = 'Pending'; // 'Pending', 'Completed', 'Not Applicable'
  late DateTime _commissionDate;

  bool _isSaving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    final initC = widget.initialConsumer;

    _commissionDate = e?.commissionDate ?? DateTime.now();

    if (initC != null && e == null) {
      _selectedConsumer = initC;
      _nameCtrl = TextEditingController(text: initC.name);
      _consumerNoCtrl = TextEditingController(text: initC.consumerNo);
      _locationCtrl = TextEditingController(text: initC.address ?? initC.village ?? '');
      _capacityCtrl = TextEditingController(
        text: initC.systemCapacity?.isNotEmpty == true
            ? initC.systemCapacity!
            : '${initC.capacityKw > 0 ? initC.capacityKw : 3.0} kW',
      );
      _capacityKwCtrl = TextEditingController(
        text: (initC.capacityKw > 0 ? initC.capacityKw : 3.0).toStringAsFixed(1),
      );
      final hasStaff = initC.assignedStaff != null && initC.assignedStaff!.trim().isNotEmpty;
      _customerSource = hasStaff ? 'Sales Person' : 'Direct Customer';
      _selectedSalesPersonName = hasStaff ? initC.assignedStaff : null;
      _rateCtrl = TextEditingController(text: hasStaff ? '500' : '0');
      _commissionStatus = hasStaff ? 'Pending' : 'Not Applicable';
    } else {
      _nameCtrl = TextEditingController(text: e?.customerName ?? '');
      _consumerNoCtrl = TextEditingController(text: e?.consumerNo ?? '');
      _locationCtrl = TextEditingController(text: e?.siteLocation ?? '');
      _capacityCtrl = TextEditingController(text: e?.solarCapacity ?? '');
      _capacityKwCtrl = TextEditingController(text: (e?.capacityKw ?? 3.0).toStringAsFixed(1));
      _customerSource = e?.customerSource ?? 'Sales Person';
      _selectedSalesPersonName = e?.salesPersonName;
      _selectedSalesPersonId = e?.salesPersonId;
      _rateCtrl = TextEditingController(
        text: e != null ? (e.isDirectCustomer ? '0' : e.commissionRatePerKw.toStringAsFixed(0)) : '500',
      );
      _commissionStatus = e?.commissionStatus ?? (_customerSource == 'Direct Customer' ? 'Not Applicable' : 'Pending');
    }

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
    _capacityKwCtrl.dispose();
    _rateCtrl.dispose();
    _remarksCtrl.dispose();
    super.dispose();
  }

  double get _kw => double.tryParse(_capacityKwCtrl.text.trim()) ?? 3.0;
  double get _rate => _customerSource == 'Direct Customer' ? 0.0 : (double.tryParse(_rateCtrl.text.trim()) ?? 0.0);
  double get _totalCommission => _customerSource == 'Direct Customer' ? 0.0 : (_kw * _rate);

  void _onCustomerSelected(ConsumerRecord? customer) {
    if (customer == null) return;
    setState(() {
      _selectedConsumer = customer;
      _nameCtrl.text = customer.name;
      _consumerNoCtrl.text = customer.consumerNo;
      _locationCtrl.text = customer.address ?? customer.village ?? '';
      final cap = customer.systemCapacity?.isNotEmpty == true
          ? customer.systemCapacity!
          : '${customer.capacityKw > 0 ? customer.capacityKw : 3.0} kW';
      _capacityCtrl.text = cap;
      _capacityKwCtrl.text = (customer.capacityKw > 0 ? customer.capacityKw : 3.0).toStringAsFixed(1);

      if (customer.assignedStaff != null && customer.assignedStaff!.trim().isNotEmpty) {
        _customerSource = 'Sales Person';
        _selectedSalesPersonName = customer.assignedStaff;
        _rateCtrl.text = '500';
        _commissionStatus = 'Pending';
      }
    });
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    if (_consumerNoCtrl.text.trim().isEmpty) {
      setState(() => _errorMessage = 'Consumer Number is required. Please select a customer.');
      return;
    }

    final targetNo = _consumerNoCtrl.text.trim();
    final existingWithSameNo = widget.allCommissions.where(
      (c) => c.consumerNo.trim() == targetNo &&
          c.id != (widget.existing?.id ?? '') &&
          !c.id.startsWith('init-'),
    );

    if (existingWithSameNo.isNotEmpty) {
      setState(() {
        _errorMessage = 'A commission record already exists for Consumer No: $targetNo. Please edit the existing entry.';
      });
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      final isDirect = _customerSource == 'Direct Customer';
      final commissionToSave = SalesCommission(
        id: widget.existing?.id ?? '',
        consumerId: _selectedConsumer?.id ?? widget.existing?.consumerId ?? '',
        consumerNo: _consumerNoCtrl.text.trim(),
        customerName: _nameCtrl.text.trim(),
        siteLocation: _locationCtrl.text.trim(),
        solarCapacity: _capacityCtrl.text.trim().isNotEmpty ? _capacityCtrl.text.trim() : '${_kw.toStringAsFixed(1)} kW',
        capacityKw: _kw,
        customerSource: _customerSource,
        salesPersonId: isDirect ? null : _selectedSalesPersonId,
        salesPersonName: isDirect ? null : _selectedSalesPersonName,
        commissionRatePerKw: isDirect ? 0.0 : _rate,
        totalCommission: isDirect ? 0.0 : _totalCommission,
        commissionStatus: isDirect ? 'Not Applicable' : _commissionStatus,
        commissionDate: _commissionDate,
        remarks: _remarksCtrl.text.trim().isNotEmpty ? _remarksCtrl.text.trim() : null,
      );

      await SalesCommissionService.saveCommission(commissionToSave);

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
    final isDirect = _customerSource == 'Direct Customer';

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
                      child: Icon(Icons.price_check_rounded, color: theme.colorScheme.primary),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isNew ? 'Add Customer Commission' : 'Edit Customer Commission',
                            style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const Text(
                            'Configure sales person commission rate per kW or mark as direct customer.',
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
                          child: Text(_errorMessage!, style: const TextStyle(color: Colors.red, fontSize: 13)),
                        ),
                      ],
                    ),
                  ),

                // 1. SELECT CUSTOMER (CUSTOMER MASTER)
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
                        decoration: InputDecoration(
                          hintText: 'Search customer name or consumer number...',
                          prefixIcon: const Icon(Icons.person_search_outlined),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 14),
                ],

                // 2. CUSTOMER DETAILS (Auto-Populated & Editable)
                const Text('CUSTOMER & SITE DETAILS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: TextFormField(
                        controller: _nameCtrl,
                        decoration: const InputDecoration(labelText: 'Customer Name *', border: OutlineInputBorder()),
                        validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: TextFormField(
                        controller: _consumerNoCtrl,
                        decoration: const InputDecoration(labelText: 'Consumer No. *', border: OutlineInputBorder()),
                        validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
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
                        decoration: const InputDecoration(labelText: 'Site Location / Village', border: OutlineInputBorder()),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: TextFormField(
                        controller: _capacityKwCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(labelText: 'Capacity (kW) *', suffixText: 'kW', border: OutlineInputBorder()),
                        validator: (v) {
                          final n = double.tryParse(v ?? '');
                          if (n == null || n <= 0) return 'Invalid kW';
                          return null;
                        },
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // 3. CUSTOMER SOURCE (Sales Person vs Direct Customer)
                const Text('CUSTOMER SOURCE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
                const SizedBox(height: 6),
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: RadioListTile<String>(
                          title: const Text('Sales Person', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                          subtitle: const Text('Commission is applicable', style: TextStyle(fontSize: 11)),
                          value: 'Sales Person',
                          groupValue: _customerSource,
                          onChanged: (val) {
                            if (val != null) {
                              setState(() {
                                _customerSource = val;
                                _commissionStatus = 'Pending';
                                if (_rateCtrl.text == '0') _rateCtrl.text = '500';
                              });
                            }
                          },
                        ),
                      ),
                      Expanded(
                        child: RadioListTile<String>(
                          title: const Text('Direct Customer', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                          subtitle: const Text('₹0 Commission (Not Applicable)', style: TextStyle(fontSize: 11)),
                          value: 'Direct Customer',
                          groupValue: _customerSource,
                          onChanged: (val) {
                            if (val != null) {
                              setState(() {
                                _customerSource = val;
                                _commissionStatus = 'Not Applicable';
                                _rateCtrl.text = '0';
                                _selectedSalesPersonName = null;
                              });
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // 4. SALES PERSON SELECTION & COMMISSION RATE
                if (!isDirect) ...[
                  const Text('SALES PERSON & COMMISSION RATE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
                  const SizedBox(height: 8),

                  Row(
                    children: [
                      // Sales Person Dropdown / Input
                      Expanded(
                        flex: 3,
                        child: DropdownButtonFormField<String>(
                          // ignore: deprecated_member_use
                          value: widget.availableStaff.any((s) => (s.fullName?.trim() ?? '') == _selectedSalesPersonName && _selectedSalesPersonName != null && _selectedSalesPersonName!.isNotEmpty)
                              ? _selectedSalesPersonName
                              : null,
                          decoration: const InputDecoration(
                            labelText: 'Select Sales Person *',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.badge_outlined),
                          ),
                          items: widget.availableStaff
                              .where((s) => (s.fullName != null && s.fullName!.trim().isNotEmpty))
                              .map((staff) {
                            final name = staff.fullName!.trim();
                            return DropdownMenuItem<String>(
                              value: name,
                              child: Text(name),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              final staff = widget.availableStaff.firstWhere((s) => (s.fullName?.trim() ?? '') == val);
                              setState(() {
                                _selectedSalesPersonName = staff.fullName?.trim();
                                _selectedSalesPersonId = staff.id;
                              });
                            }
                          },
                          validator: (v) {
                            if (!isDirect && (_selectedSalesPersonName == null || _selectedSalesPersonName!.isEmpty)) {
                              return 'Please select a Sales Person';
                            }
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 10),

                      // Commission Rate per kW
                      Expanded(
                        flex: 2,
                        child: TextFormField(
                          controller: _rateCtrl,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          decoration: const InputDecoration(
                            labelText: 'Rate / kW (₹) *',
                            prefixText: '₹ ',
                            border: OutlineInputBorder(),
                          ),
                          validator: (v) {
                            if (!isDirect && (v == null || v.trim().isEmpty)) return 'Required';
                            return null;
                          },
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Status: Pending vs Completed
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          // ignore: deprecated_member_use
                          value: _commissionStatus == 'Not Applicable' ? 'Pending' : _commissionStatus,
                          decoration: const InputDecoration(
                            labelText: 'Commission Status',
                            border: OutlineInputBorder(),
                            helperText: 'Completed is record status only (No payment).',
                          ),
                          items: const [
                            DropdownMenuItem(value: 'Pending', child: Text('Pending (Action Required)')),
                            DropdownMenuItem(value: 'Completed', child: Text('Completed (Finalized Record)')),
                          ],
                          onChanged: (val) {
                            if (val != null) setState(() => _commissionStatus = val);
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: InkWell(
                          onTap: () async {
                            final d = await showDatePicker(
                              context: context,
                              initialDate: _commissionDate,
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2035),
                            );
                            if (d != null) setState(() => _commissionDate = d);
                          },
                          child: InputDecorator(
                            decoration: const InputDecoration(
                              labelText: 'Commission Date',
                              border: OutlineInputBorder(),
                              suffixIcon: Icon(Icons.calendar_today, size: 18),
                            ),
                            child: Text(DateFormat('dd/MM/yyyy').format(_commissionDate)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ] else ...[
                  // Direct customer info box
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.teal.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.teal.shade300),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.teal.shade900),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Direct Customer: Commission Rate is ₹0.00 and Status is automatically marked as "Not Applicable". This record is tracked in reports but excluded from pending commission amounts.',
                            style: TextStyle(fontSize: 12, color: Colors.teal.shade900),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 14),

                // 5. LIVE CALCULATION TOTAL BANNER
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: isDirect ? Colors.grey.shade100 : const Color(0xFFD1FAE5),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isDirect ? Colors.grey.shade300 : const Color(0xFF10B981),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isDirect ? 'DIRECT CUSTOMER COMMISSION' : 'TOTAL COMMISSION AMOUNT',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: isDirect ? Colors.grey.shade700 : const Color(0xFF064E3B),
                            ),
                          ),
                          Text(
                            isDirect
                                ? 'Solar Capacity: ${_kw.toStringAsFixed(1)} kW × ₹0.00/kW'
                                : 'Solar Capacity: ${_kw.toStringAsFixed(1)} kW × ${_currency.format(_rate)}/kW',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDirect ? Colors.grey.shade600 : Colors.black87,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        _currency.format(_totalCommission),
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: isDirect ? Colors.grey.shade700 : const Color(0xFF064E3B),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // Remarks
                TextFormField(
                  controller: _remarksCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Remarks / Notes (Optional)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 20),

                // Actions
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                    const SizedBox(width: 10),
                    FilledButton.icon(
                      onPressed: _isSaving ? null : _handleSave,
                      icon: _isSaving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.check_circle_outline, size: 18),
                      label: Text(_isSaving ? 'Saving...' : 'Save Commission Record'),
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
// VIEW COMMISSION RECORD DIALOG
// =============================================================================
class _ViewCommissionDialog extends StatelessWidget {
  final SalesCommission commission;
  final NumberFormat _currency = NumberFormat.currency(locale: 'en_IN', symbol: '₹ ', decimalDigits: 0);

  _ViewCommissionDialog({required this.commission});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDirect = commission.isDirectCustomer;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 520),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: isDirect ? Colors.teal.shade50 : Colors.indigo.shade50,
                  child: Icon(
                    isDirect ? Icons.domain_outlined : Icons.badge_outlined,
                    color: isDirect ? Colors.teal.shade800 : Colors.indigo.shade800,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(commission.customerName, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                      Text('Consumer No: ${commission.consumerNo}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                    ],
                  ),
                ),
                IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
              ],
            ),
            const Divider(height: 24),

            _infoRow('Customer Source', commission.customerSource),
            _infoRow('Sales Person', isDirect ? '— Direct Customer' : (commission.salesPersonName ?? '—')),
            _infoRow('Site Location', commission.siteLocation.isNotEmpty ? commission.siteLocation : '—'),
            _infoRow('Solar Capacity', '${commission.capacityKw.toStringAsFixed(1)} kW (${commission.solarCapacity})'),
            _infoRow('Commission Rate', isDirect ? '₹ 0.00 / kW' : '${_currency.format(commission.commissionRatePerKw)} / kW'),
            _infoRow('Commission Status', commission.commissionStatus),
            _infoRow('Commission Date', commission.formattedDate),
            if (commission.remarks != null && commission.remarks!.isNotEmpty)
              _infoRow('Remarks', commission.remarks!),

            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDirect ? Colors.grey.shade100 : const Color(0xFFD1FAE5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('TOTAL COMMISSION', style: TextStyle(fontWeight: FontWeight.bold)),
                  Text(
                    _currency.format(commission.totalCommission),
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isDirect ? Colors.black87 : const Color(0xFF064E3B),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 13, color: Colors.grey)),
          Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
