import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/customer_payment.dart';
import '../models/consumer_record.dart';
import '../services/payment_service.dart';
import '../services/record_service.dart';
import '../services/supabase_service.dart';

class PaymentsScreen extends StatefulWidget {
  const PaymentsScreen({super.key});

  @override
  State<PaymentsScreen> createState() => _PaymentsScreenState();
}

class _PaymentsScreenState extends State<PaymentsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  bool _isLoadingMetrics = true;
  bool _isLoadingCustomers = true;
  bool _isLoadingLedger = true;
  bool _isExporting = false;

  AdminPaymentMetrics _metrics = AdminPaymentMetrics.empty();
  List<CustomerPaymentRow> _customerRows = [];
  List<PaymentTransaction> _ledgerTransactions = [];

  final TextEditingController _searchController = TextEditingController();
  String _selectedStatusFilter = 'All'; // 'All', 'Pending', 'Partially Paid', 'Paid'
  String _selectedModeFilter = 'All';
  String _selectedTypeFilter = 'All'; // 'All', 'CONTRACT', 'ADDITIONAL'
  String _selectedCategoryFilter = 'All'; // 'All', 'EXTRA_MATERIAL', etc.

  StreamSubscription? _realtimeSub;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadAll();
    _initRealtime();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _realtimeSub?.cancel();
    super.dispose();
  }

  void _initRealtime() {
    try {
      final channel = SupabaseService.client.channel('public:payments_realtime');
      channel
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'customer_payment_transactions',
            callback: (_) {
              if (mounted) {
                _loadAll(silent: true);
              }
            },
          )
          .subscribe();
    } catch (_) {}
  }

  Future<void> _loadAll({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _isLoadingMetrics = true;
        _isLoadingCustomers = true;
        _isLoadingLedger = true;
      });
    }

    await Future.wait([
      _loadMetrics(),
      _loadCustomerSummaries(),
      _loadLedgerTransactions(),
    ]);
  }

  Future<void> _loadMetrics() async {
    final m = await AdminPaymentService.fetchDashboardMetrics();
    if (mounted) {
      setState(() {
        _metrics = m;
        _isLoadingMetrics = false;
      });
    }
  }

  Future<void> _loadCustomerSummaries() async {
    final rows = await AdminPaymentService.fetchCustomerPaymentSummaries(
      searchQuery: _searchController.text,
      statusFilter: _selectedStatusFilter,
    );
    if (mounted) {
      setState(() {
        _customerRows = rows;
        _isLoadingCustomers = false;
      });
    }
  }

  Future<void> _loadLedgerTransactions() async {
    final txs = await AdminPaymentService.fetchPayments(
      searchQuery: _searchController.text,
      paymentMode: _selectedModeFilter,
      paymentType: _selectedTypeFilter,
      additionalCategory: _selectedCategoryFilter,
    );
    if (mounted) {
      setState(() {
        _ledgerTransactions = txs;
        _isLoadingLedger = false;
      });
    }
  }

  void _onSearchChanged(String val) {
    _loadCustomerSummaries();
    _loadLedgerTransactions();
  }

  Future<void> _handleExportExcel() async {
    if (_customerRows.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No payment records to export.')),
      );
      return;
    }

    setState(() => _isExporting = true);
    try {
      final success = await AdminPaymentService.exportCustomerPaymentsToExcel(_customerRows);
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Excel payment ledger exported successfully!'),
            backgroundColor: Color(0xFF059669),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  void _openAddPaymentDialog([CustomerPaymentRow? customer]) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _AdminAddPaymentDialog(
        preselectedCustomer: customer,
        onSaved: () {
          _loadAll();
        },
      ),
    );
  }

  void _openEditPaymentDialog(PaymentTransaction tx) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _AdminEditPaymentDialog(
        transaction: tx,
        onSaved: () {
          _loadAll();
        },
      ),
    );
  }

  void _openAdditionalReportDialog() {
    showDialog(
      context: context,
      builder: (ctx) => const _AdditionalPaymentReportDialog(),
    );
  }

  void _openCustomerHistoryDialog(CustomerPaymentRow customer) {
    showDialog(
      context: context,
      builder: (ctx) => _CustomerHistoryDialog(
        customer: customer,
        onAddPayment: () => _openAddPaymentDialog(customer),
        onEditPayment: (tx) => _openEditPaymentDialog(tx),
        onPaymentChanged: () => _loadAll(),
      ),
    );
  }

  void _openEditTotalPaymentDialog(CustomerPaymentRow row) async {
    final totalCtrl = TextEditingController(
      text: row.totalAmount > 0 ? row.totalAmount.toStringAsFixed(0) : '',
    );
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Total Payment'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Customer: ${row.customerName} (${row.consumerNo})'),
            const SizedBox(height: 12),
            TextField(
              controller: totalCtrl,
              autofocus: true,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Total Payment (₹) *',
                prefixText: '₹ ',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFF059669)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final newTotal = double.tryParse(totalCtrl.text.trim()) ?? 0.0;
      try {
        await RecordService.updateCustomerPaymentProfile(
          customerId: row.customerId,
          totalAmount: newTotal,
        );
        _loadAll();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error updating Total Payment: $e')));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. TOP HEADER & ACTION BUTTONS
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Payments',
                      style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Contract payments, additional payments, customer balances & Excel export',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                  ],
                ),
                Row(
                  children: [
                    ElevatedButton.icon(
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: const Text('+ Add Payment', style: TextStyle(fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF059669),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () => _openAddPaymentDialog(),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.analytics_outlined, size: 18),
                      label: const Text('Additional Report', style: TextStyle(fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6366F1),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: _openAdditionalReportDialog,
                    ),
                    const SizedBox(width: 10),
                    OutlinedButton.icon(
                      icon: _isExporting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.file_download_outlined, size: 18),
                      label: const Text('Export Excel'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: _isExporting ? null : _handleExportExcel,
                    ),
                    const SizedBox(width: 10),
                    IconButton(
                      icon: const Icon(Icons.refresh),
                      tooltip: 'Refresh',
                      onPressed: () => _loadAll(),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // 2. DASHBOARD KPI CARDS (Contract Collection, Additional Collection, Total Collection, Contract Pending)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: _isLoadingMetrics
                ? const LinearProgressIndicator()
                : Row(
                    children: [
                      Expanded(
                        child: _buildMetricCard(
                          title: 'Contract Collection',
                          amount: _metrics.contractCollection,
                          subtitle: 'Original contract payments',
                          color: const Color(0xFF0284C7), // Sky Blue
                          icon: Icons.description_rounded,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: _buildMetricCard(
                          title: 'Additional Collection',
                          amount: _metrics.additionalCollection,
                          subtitle: 'Extra material, work, etc.',
                          color: const Color(0xFF8B5CF6), // Purple
                          icon: Icons.playlist_add_check_circle_rounded,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: _buildMetricCard(
                          title: 'Total Collection',
                          amount: _metrics.totalCollection,
                          subtitle: '${_metrics.totalTransactionsCount} total payments',
                          color: const Color(0xFF059669), // Emerald
                          icon: Icons.account_balance_wallet_rounded,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: _buildMetricCard(
                          title: 'Contract Pending',
                          amount: _metrics.totalOutstanding,
                          subtitle: 'Outstanding contract balance',
                          color: const Color(0xFFDC2626), // Red
                          icon: Icons.pending_actions_rounded,
                        ),
                      ),
                    ],
                  ),
          ),
          const SizedBox(height: 16),

          // 3. SEARCH & TABS BAR WITH COMPREHENSIVE FILTERS
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: _searchController,
                    onChanged: _onSearchChanged,
                    decoration: InputDecoration(
                      hintText: 'Search customer name, consumer no, mobile, village...',
                      prefixIcon: const Icon(Icons.search, size: 20),
                      isDense: true,
                      filled: true,
                      fillColor: theme.cardColor,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
                const SizedBox(width: 10),

                // Filters depending on active tab
                if (_tabController.index == 0) ...[
                  // Customer Summary Tab Filters
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      color: theme.cardColor,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedStatusFilter,
                        items: const [
                          DropdownMenuItem(value: 'All', child: Text('Status: All')),
                          DropdownMenuItem(value: 'Pending', child: Text('Pending Only')),
                          DropdownMenuItem(value: 'Partially Paid', child: Text('Partially Paid')),
                          DropdownMenuItem(value: 'Paid', child: Text('Fully Paid')),
                        ],
                        onChanged: (v) {
                          setState(() => _selectedStatusFilter = v!);
                          _loadCustomerSummaries();
                        },
                      ),
                    ),
                  ),
                ] else ...[
                  // Payment History Tab Filters: Type, Category, Mode
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      color: theme.cardColor,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedTypeFilter,
                        items: const [
                          DropdownMenuItem(value: 'All', child: Text('Type: All')),
                          DropdownMenuItem(value: PaymentType.contract, child: Text('Contract')),
                          DropdownMenuItem(value: PaymentType.additional, child: Text('Additional')),
                        ],
                        onChanged: (v) {
                          setState(() => _selectedTypeFilter = v!);
                          _loadLedgerTransactions();
                        },
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      color: theme.cardColor,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedCategoryFilter,
                        items: [
                          const DropdownMenuItem(value: 'All', child: Text('Category: All')),
                          ...AdditionalPaymentCategory.allCategories.map((c) => DropdownMenuItem(
                                value: c,
                                child: Text(AdditionalPaymentCategory.displayName(c)),
                              )),
                        ],
                        onChanged: (v) {
                          setState(() => _selectedCategoryFilter = v!);
                          _loadLedgerTransactions();
                        },
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      color: theme.cardColor,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedModeFilter,
                        items: const [
                          DropdownMenuItem(value: 'All', child: Text('Mode: All')),
                          DropdownMenuItem(value: 'Cash', child: Text('Cash')),
                          DropdownMenuItem(value: 'UPI', child: Text('UPI')),
                          DropdownMenuItem(value: 'Bank Transfer', child: Text('Bank Transfer')),
                          DropdownMenuItem(value: 'Cheque', child: Text('Cheque')),
                          DropdownMenuItem(value: 'Other', child: Text('Other')),
                        ],
                        onChanged: (v) {
                          setState(() => _selectedModeFilter = v!);
                          _loadLedgerTransactions();
                        },
                      ),
                    ),
                  ),
                ],
                const SizedBox(width: 14),
                SizedBox(
                  width: 320,
                  child: TabBar(
                    controller: _tabController,
                    labelColor: theme.colorScheme.primary,
                    indicatorColor: theme.colorScheme.primary,
                    onTap: (_) => setState(() {}),
                    tabs: [
                      Tab(text: 'Customer Summary (${_customerRows.length})'),
                      Tab(text: 'Payment History (${_ledgerTransactions.length})'),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // 4. MAIN CONTENT TABS
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildCustomerTable(theme),
                  _buildLedgerTable(theme),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildMetricCard({
    required String title,
    required double amount,
    required String subtitle,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: color.withValues(alpha: 0.15),
            radius: 24,
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey.shade700),
                ),
                const SizedBox(height: 4),
                Text(
                  '₹${NumberFormat('#,##,###').format(amount)}',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomerTable(ThemeData theme) {
    if (_isLoadingCustomers) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_customerRows.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.person_search_rounded, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            const Text('No customer payment records found.', style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    final currency = NumberFormat('#,##,###');

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: SingleChildScrollView(
          child: DataTable(
            headingRowColor: WidgetStateProperty.all(theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5)),
            columns: const [
              DataColumn(label: Text('Customer', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Consumer No', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Contract Amt', style: TextStyle(fontWeight: FontWeight.bold)), numeric: true),
              DataColumn(label: Text('Contract Paid', style: TextStyle(fontWeight: FontWeight.bold)), numeric: true),
              DataColumn(label: Text('Contract Pending', style: TextStyle(fontWeight: FontWeight.bold)), numeric: true),
              DataColumn(label: Text('Additional Paid', style: TextStyle(fontWeight: FontWeight.bold)), numeric: true),
              DataColumn(label: Text('Total Received', style: TextStyle(fontWeight: FontWeight.bold)), numeric: true),
              DataColumn(label: Text('Last Payment', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Payment Date', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold))),
            ],
            rows: _customerRows.map((row) {
              final isPending = row.pendingAmount > 0;

              return DataRow(
                cells: [
                  DataCell(
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(row.customerName, style: const TextStyle(fontWeight: FontWeight.bold)),
                        if (row.village.isNotEmpty)
                          Text(row.village, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                      ],
                    ),
                  ),
                  DataCell(
                    Text(
                      row.consumerNo,
                      style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.w600),
                    ),
                  ),
                  DataCell(
                    InkWell(
                      onTap: () => _openEditTotalPaymentDialog(row),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('₹${currency.format(row.totalAmount)}', style: const TextStyle(fontWeight: FontWeight.w600)),
                          const SizedBox(width: 4),
                          Icon(Icons.edit_outlined, size: 12, color: Colors.grey.shade600),
                        ],
                      ),
                    ),
                  ),
                  DataCell(
                    Text(
                      '₹${currency.format(row.paidAmount)}',
                      style: const TextStyle(color: Color(0xFF059669), fontWeight: FontWeight.bold),
                    ),
                  ),
                  DataCell(
                    Text(
                      '₹${currency.format(row.pendingAmount)}',
                      style: TextStyle(
                        color: isPending ? const Color(0xFFDC2626) : Colors.grey,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  DataCell(
                    Text(
                      row.additionalPaid > 0 ? '₹${currency.format(row.additionalPaid)}' : '—',
                      style: const TextStyle(color: Color(0xFF8B5CF6), fontWeight: FontWeight.bold),
                    ),
                  ),
                  DataCell(
                    Text(
                      '₹${currency.format(row.totalReceived)}',
                      style: const TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold),
                    ),
                  ),
                  DataCell(
                    row.lastPaymentAmount != null
                        ? Text(
                            '₹${currency.format(row.lastPaymentAmount)} (${row.lastPaymentMode ?? "—"})${row.lastPaymentType == PaymentType.additional ? " [${row.lastAdditionalCategory != null ? AdditionalPaymentCategory.displayName(row.lastAdditionalCategory!) : 'Extra'}]" : ""}')
                        : const Text('—', style: TextStyle(color: Colors.grey)),
                  ),
                  DataCell(
                    row.lastPaymentDate != null
                        ? Text(DateFormat('dd/MM/yyyy').format(row.lastPaymentDate!))
                        : const Text('—', style: TextStyle(color: Colors.grey)),
                  ),
                  DataCell(
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit_note_rounded, color: Colors.indigo, size: 20),
                          tooltip: 'Edit Total Payment',
                          onPressed: () => _openEditTotalPaymentDialog(row),
                        ),
                        IconButton(
                          icon: const Icon(Icons.add_circle_outline, color: Color(0xFF059669), size: 20),
                          tooltip: 'Add Payment',
                          onPressed: () => _openAddPaymentDialog(row),
                        ),
                        IconButton(
                          icon: const Icon(Icons.history_rounded, color: Color(0xFF0284C7), size: 20),
                          tooltip: 'Payment History',
                          onPressed: () => _openCustomerHistoryDialog(row),
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

  Widget _buildLedgerTable(ThemeData theme) {
    if (_isLoadingLedger) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_ledgerTransactions.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.receipt_long_outlined, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            const Text('No payment transactions found.', style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    final currency = NumberFormat('#,##,###');

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: SingleChildScrollView(
          child: DataTable(
            headingRowColor: WidgetStateProperty.all(theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5)),
            columns: const [
              DataColumn(label: Text('Date', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Customer', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Consumer No', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Type', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Category', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Amount', style: TextStyle(fontWeight: FontWeight.bold)), numeric: true),
              DataColumn(label: Text('Mode', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Reference No', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Remarks', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Recorded By', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold))),
            ],
            rows: _ledgerTransactions.map((tx) {
              return DataRow(
                cells: [
                  DataCell(Text(DateFormat('dd/MM/yyyy').format(tx.paymentDate))),
                  DataCell(Text(tx.customerName ?? '—', style: const TextStyle(fontWeight: FontWeight.bold))),
                  DataCell(Text(tx.consumerNo, style: const TextStyle(fontFamily: 'monospace'))),
                  DataCell(
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: tx.isAdditional
                            ? const Color(0xFF8B5CF6).withValues(alpha: 0.1)
                            : const Color(0xFF0284C7).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        tx.typeDisplayName,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: tx.isAdditional ? const Color(0xFF7C3AED) : const Color(0xFF0284C7),
                        ),
                      ),
                    ),
                  ),
                  DataCell(
                    tx.isAdditional
                        ? Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                AdditionalPaymentCategory.getCategoryIcon(tx.additionalCategory ?? ''),
                                size: 14,
                                color: const Color(0xFF6366F1),
                              ),
                              const SizedBox(width: 4),
                              Text(tx.categoryDisplayName, style: const TextStyle(fontWeight: FontWeight.w600)),
                            ],
                          )
                        : const Text('—', style: TextStyle(color: Colors.grey)),
                  ),
                  DataCell(
                    Text(
                      '₹${currency.format(tx.amount)}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: tx.isAdditional ? const Color(0xFF7C3AED) : const Color(0xFF059669),
                      ),
                    ),
                  ),
                  DataCell(
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(PaymentMode.getModeIcon(tx.paymentMode), size: 16, color: Colors.grey.shade700),
                        const SizedBox(width: 6),
                        Text(tx.paymentMode),
                      ],
                    ),
                  ),
                  DataCell(Text(tx.referenceNumber?.isNotEmpty == true ? tx.referenceNumber! : '—')),
                  DataCell(Text(tx.remarks?.isNotEmpty == true ? tx.remarks! : '—')),
                  DataCell(Text(tx.createdByName ?? tx.receivedBy ?? 'Staff')),
                  DataCell(
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, size: 18, color: Color(0xFF0284C7)),
                      tooltip: 'Edit Payment',
                      onPressed: () => _openEditPaymentDialog(tx),
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
}

/// Admin Add Payment Dialog with Typeahead / Customer Selection, Type & Category, and Auto-calculation
class _AdminAddPaymentDialog extends StatefulWidget {
  final CustomerPaymentRow? preselectedCustomer;
  final VoidCallback onSaved;

  const _AdminAddPaymentDialog({
    this.preselectedCustomer,
    required this.onSaved,
  });

  @override
  State<_AdminAddPaymentDialog> createState() => _AdminAddPaymentDialogState();
}

class _AdminAddPaymentDialogState extends State<_AdminAddPaymentDialog> {
  final _formKey = GlobalKey<FormState>();

  String? _selectedCustomerId;
  String? _selectedCustomerName;
  String? _selectedConsumerNo;
  double _contractAmount = 0.0;
  double _contractPaid = 0.0;
  double _contractPending = 0.0;
  double _additionalPaid = 0.0;
  double _totalReceived = 0.0;

  String _paymentType = PaymentType.contract;
  String _additionalCategory = AdditionalPaymentCategory.extraMaterial;

  final TextEditingController _amountCtrl = TextEditingController();
  final TextEditingController _refCtrl = TextEditingController();
  final TextEditingController _remarksCtrl = TextEditingController();
  final TextEditingController _searchCtrl = TextEditingController();

  DateTime _paymentDate = DateTime.now();
  String _paymentMode = 'UPI';
  bool _isSaving = false;
  bool _isSearching = false;
  List<ConsumerRecord> _matchingCustomers = [];

  @override
  void initState() {
    super.initState();
    if (widget.preselectedCustomer != null) {
      _selectedCustomerId = widget.preselectedCustomer!.customerId;
      _selectedCustomerName = widget.preselectedCustomer!.customerName;
      _selectedConsumerNo = widget.preselectedCustomer!.consumerNo;
      _contractAmount = widget.preselectedCustomer!.totalAmount;
      _contractPaid = widget.preselectedCustomer!.paidAmount;
      _contractPending = widget.preselectedCustomer!.pendingAmount;
      _additionalPaid = widget.preselectedCustomer!.additionalPaid;
      _totalReceived = widget.preselectedCustomer!.totalReceived;
    }
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _refCtrl.dispose();
    _remarksCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _searchCustomers(String q) async {
    if (q.trim().isEmpty) {
      setState(() => _matchingCustomers = []);
      return;
    }
    setState(() => _isSearching = true);
    try {
      final res = await SupabaseService.client
          .from('consumer_records')
          .select('id, customer_name, consumer_no, total_amount, paid_amount, pending_amount, additional_paid_amount, total_received_amount, village')
          .eq('deleted', false)
          .or('customer_name.ilike.%$q%,consumer_no.ilike.%$q%,mobile_number.ilike.%$q%')
          .limit(10);

      final list = (res as List).map((m) => ConsumerRecord.fromJson(m as Map<String, dynamic>)).toList();
      if (mounted) {
        setState(() {
          _matchingCustomers = list;
          _isSearching = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  void _selectCustomer(ConsumerRecord c) {
    setState(() {
      _selectedCustomerId = c.id;
      _selectedCustomerName = c.name;
      _selectedConsumerNo = c.consumerNo;
      _contractAmount = c.totalAmount;
      _contractPaid = c.paidAmount;
      _contractPending = c.pendingAmount;
      _matchingCustomers = [];
      _searchCtrl.clear();
    });
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCustomerId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a customer first.')),
      );
      return;
    }

    final amt = double.tryParse(_amountCtrl.text.trim()) ?? 0.0;
    if (amt <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid amount greater than 0.')),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      await AdminPaymentService.recordPayment(
        customerId: _selectedCustomerId!,
        consumerNo: _selectedConsumerNo!,
        amount: amt,
        paymentDate: _paymentDate,
        paymentMode: _paymentMode,
        paymentType: _paymentType,
        additionalCategory: _paymentType == PaymentType.additional ? _additionalCategory : null,
        referenceNumber: _refCtrl.text.trim(),
        remarks: _remarksCtrl.text.trim(),
      );

      widget.onSaved();
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Payment saved and customer balance updated!'),
            backgroundColor: Color(0xFF059669),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving payment: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat('#,##,###');

    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.add_circle, color: Color(0xFF059669)),
          const SizedBox(width: 8),
          const Text('Record Payment'),
        ],
      ),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Customer Selection / Auto Display
                if (_selectedCustomerId == null) ...[
                  const Text('Select Customer', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _searchCtrl,
                    onChanged: _searchCustomers,
                    decoration: InputDecoration(
                      hintText: 'Type customer name or consumer number...',
                      prefixIcon: const Icon(Icons.search, size: 20),
                      suffixIcon: _isSearching
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: Padding(
                                padding: EdgeInsets.all(12),
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                            )
                          : null,
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  if (_matchingCustomers.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Container(
                      constraints: const BoxConstraints(maxHeight: 180),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: _matchingCustomers.length,
                        itemBuilder: (ctx, idx) {
                          final c = _matchingCustomers[idx];
                          return ListTile(
                            dense: true,
                            title: Text(c.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text('${c.consumerNo}${c.address != null ? " • ${c.address}" : ""}'),
                            trailing: Text('Pending: ₹${currency.format(c.pendingAmount)}'),
                            onTap: () => _selectCustomer(c),
                          );
                        },
                      ),
                    ),
                  ],
                ] else ...[
                  // Selected Customer Summary Box
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0FDF4),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFBBF7D0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _selectedCustomerName ?? '',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                            ),
                            TextButton(
                              onPressed: () => setState(() => _selectedCustomerId = null),
                              child: const Text('Change Customer', style: TextStyle(fontSize: 12)),
                            ),
                          ],
                        ),
                        Text(
                          'Consumer No: $_selectedConsumerNo',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade700, fontFamily: 'monospace'),
                        ),
                        const Divider(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Contract Amount', style: TextStyle(fontSize: 11, color: Colors.grey)),
                                  Text(
                                    '₹${currency.format(_contractAmount)}',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                  ),
                                ],
                              ),
                            ),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Contract Paid', style: TextStyle(fontSize: 11, color: Colors.grey)),
                                  Text(
                                    '₹${currency.format(_contractPaid)}',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF059669)),
                                  ),
                                ],
                              ),
                            ),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Contract Pending', style: TextStyle(fontSize: 11, color: Colors.grey)),
                                  Text(
                                    '₹${currency.format(_contractPending)}',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFFDC2626)),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        if (_additionalPaid > 0) ...[
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'Additional Paid: ₹${currency.format(_additionalPaid)}',
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF7C3AED)),
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  'Total Received: ₹${currency.format(_totalReceived)}',
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 16),

                // 2. PAYMENT TYPE SELECTION
                const Text('Payment Type*', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 6),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(
                      value: PaymentType.contract,
                      label: Text('Contract Payment'),
                      icon: Icon(Icons.assignment_outlined, size: 16),
                    ),
                    ButtonSegment(
                      value: PaymentType.additional,
                      label: Text('Additional Payment'),
                      icon: Icon(Icons.add_shopping_cart_rounded, size: 16),
                    ),
                  ],
                  selected: {_paymentType},
                  onSelectionChanged: (newSelection) {
                    setState(() => _paymentType = newSelection.first);
                  },
                ),
                const SizedBox(height: 14),

                // 3. IF ADDITIONAL PAYMENT: CATEGORY DROPDOWN
                if (_paymentType == PaymentType.additional) ...[
                  DropdownButtonFormField<String>(
                    value: _additionalCategory,
                    decoration: const InputDecoration(
                      labelText: 'Additional Payment For*',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: AdditionalPaymentCategory.allCategories.map((cat) {
                      return DropdownMenuItem(
                        value: cat,
                        child: Row(
                          children: [
                            Icon(AdditionalPaymentCategory.getCategoryIcon(cat), size: 18, color: const Color(0xFF7C3AED)),
                            const SizedBox(width: 8),
                            Text(AdditionalPaymentCategory.displayName(cat)),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: (v) => setState(() => _additionalCategory = v!),
                  ),
                  const SizedBox(height: 14),
                ],

                // 4. Payment Amount & Date
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: TextFormField(
                        controller: _amountCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(
                          labelText: 'Payment Amount (₹)*',
                          prefixText: '₹ ',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) return 'Enter amount';
                          final n = double.tryParse(val.trim());
                          if (n == null || n <= 0) return 'Invalid amount';
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: InkWell(
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: _paymentDate,
                            firstDate: DateTime(2020),
                            lastDate: DateTime.now().add(const Duration(days: 1)),
                          );
                          if (picked != null) {
                            setState(() => _paymentDate = picked);
                          }
                        },
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'Payment Date*',
                            border: OutlineInputBorder(),
                            isDense: true,
                            suffixIcon: Icon(Icons.calendar_today, size: 16),
                          ),
                          child: Text(DateFormat('dd/MM/yyyy').format(_paymentDate)),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // 5. Payment Mode & Reference
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: DropdownButtonFormField<String>(
                        value: _paymentMode,
                        decoration: const InputDecoration(
                          labelText: 'Payment Mode*',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        items: const [
                          DropdownMenuItem(value: 'Cash', child: Text('Cash')),
                          DropdownMenuItem(value: 'UPI', child: Text('UPI')),
                          DropdownMenuItem(value: 'Bank Transfer', child: Text('Bank Transfer')),
                          DropdownMenuItem(value: 'Cheque', child: Text('Cheque')),
                          DropdownMenuItem(value: 'Other', child: Text('Other')),
                        ],
                        onChanged: (v) => setState(() => _paymentMode = v!),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 3,
                      child: TextFormField(
                        controller: _refCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Reference Number / UTR',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // 6. Description / Remarks
                TextFormField(
                  controller: _remarksCtrl,
                  decoration: InputDecoration(
                    labelText: _paymentType == PaymentType.additional
                        ? 'Description / Remarks (e.g. 50m extra cable)'
                        : 'Description / Remarks (Optional)',
                    border: const OutlineInputBorder(),
                    isDense: true,
                  ),
                  maxLines: 2,
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: const Color(0xFF059669)),
          onPressed: _isSaving ? null : _handleSave,
          child: _isSaving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Text('Save Payment'),
        ),
      ],
    );
  }
}

/// Admin Edit Payment Dialog with automatic balance recalculation
class _AdminEditPaymentDialog extends StatefulWidget {
  final PaymentTransaction transaction;
  final VoidCallback onSaved;

  const _AdminEditPaymentDialog({
    required this.transaction,
    required this.onSaved,
  });

  @override
  State<_AdminEditPaymentDialog> createState() => _AdminEditPaymentDialogState();
}

class _AdminEditPaymentDialogState extends State<_AdminEditPaymentDialog> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _amountCtrl;
  late TextEditingController _refCtrl;
  late TextEditingController _remarksCtrl;
  late DateTime _paymentDate;
  late String _paymentMode;
  late String _paymentType;
  late String _additionalCategory;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _amountCtrl = TextEditingController(text: widget.transaction.amount.toStringAsFixed(0));
    _refCtrl = TextEditingController(text: widget.transaction.referenceNumber ?? '');
    _remarksCtrl = TextEditingController(text: widget.transaction.remarks ?? '');
    _paymentDate = widget.transaction.paymentDate;
    _paymentMode = ['Cash', 'UPI', 'Bank Transfer', 'Cheque', 'Other'].contains(widget.transaction.paymentMode)
        ? widget.transaction.paymentMode
        : 'Other';
    _paymentType = widget.transaction.paymentType.toUpperCase() == 'ADDITIONAL'
        ? PaymentType.additional
        : PaymentType.contract;
    _additionalCategory = widget.transaction.additionalCategory ?? AdditionalPaymentCategory.extraMaterial;
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _refCtrl.dispose();
    _remarksCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleUpdate() async {
    if (!_formKey.currentState!.validate()) return;

    final amt = double.tryParse(_amountCtrl.text.trim()) ?? 0.0;
    if (amt <= 0) return;

    setState(() => _isSaving = true);
    try {
      await AdminPaymentService.updatePaymentSimple(
        paymentId: widget.transaction.id!,
        customerId: widget.transaction.customerId,
        amount: amt,
        paymentDate: _paymentDate,
        paymentMode: _paymentMode,
        paymentType: _paymentType,
        additionalCategory: _paymentType == PaymentType.additional ? _additionalCategory : null,
        referenceNumber: _refCtrl.text.trim(),
        remarks: _remarksCtrl.text.trim(),
      );

      widget.onSaved();
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Payment updated and balances recalculated!'),
            backgroundColor: Color(0xFF059669),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating payment: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.edit, color: Color(0xFF0284C7)),
          SizedBox(width: 8),
          Text('Edit Payment'),
        ],
      ),
      content: SizedBox(
        width: 480,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Customer: ${widget.transaction.customerName ?? widget.transaction.consumerNo}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              Text(
                'Consumer No: ${widget.transaction.consumerNo}',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontFamily: 'monospace'),
              ),
              const SizedBox(height: 14),

              // Payment Type
              const Text('Payment Type*', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              const SizedBox(height: 6),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: PaymentType.contract, label: Text('Contract')),
                  ButtonSegment(value: PaymentType.additional, label: Text('Additional')),
                ],
                selected: {_paymentType},
                onSelectionChanged: (set) => setState(() => _paymentType = set.first),
              ),
              if (_paymentType == PaymentType.additional) ...[
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _additionalCategory,
                  decoration: const InputDecoration(
                    labelText: 'Additional Category*',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: AdditionalPaymentCategory.allCategories.map((c) {
                    return DropdownMenuItem(
                      value: c,
                      child: Text(AdditionalPaymentCategory.displayName(c)),
                    );
                  }).toList(),
                  onChanged: (v) => setState(() => _additionalCategory = v!),
                ),
              ],
              const SizedBox(height: 14),

              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: TextFormField(
                      controller: _amountCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Payment Amount (₹)*',
                        prefixText: '₹ ',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) return 'Enter amount';
                        final n = double.tryParse(val.trim());
                        if (n == null || n <= 0) return 'Invalid amount';
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _paymentDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now().add(const Duration(days: 1)),
                        );
                        if (picked != null) {
                          setState(() => _paymentDate = picked);
                        }
                      },
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Payment Date*',
                          border: OutlineInputBorder(),
                          isDense: true,
                          suffixIcon: Icon(Icons.calendar_today, size: 16),
                        ),
                        child: Text(DateFormat('dd/MM/yyyy').format(_paymentDate)),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: DropdownButtonFormField<String>(
                      value: _paymentMode,
                      decoration: const InputDecoration(
                        labelText: 'Payment Mode*',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      items: const [
                        DropdownMenuItem(value: 'Cash', child: Text('Cash')),
                        DropdownMenuItem(value: 'UPI', child: Text('UPI')),
                        DropdownMenuItem(value: 'Bank Transfer', child: Text('Bank Transfer')),
                        DropdownMenuItem(value: 'Cheque', child: Text('Cheque')),
                        DropdownMenuItem(value: 'Other', child: Text('Other')),
                      ],
                      onChanged: (v) => setState(() => _paymentMode = v!),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 3,
                    child: TextFormField(
                      controller: _refCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Reference Number / UTR',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _remarksCtrl,
                decoration: const InputDecoration(
                  labelText: 'Remarks',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                maxLines: 2,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _isSaving ? null : _handleUpdate,
          child: _isSaving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Text('Update Payment'),
        ),
      ],
    );
  }
}

/// Dialog displaying customer profile payment summary and individual transaction history
class _CustomerHistoryDialog extends StatefulWidget {
  final CustomerPaymentRow customer;
  final VoidCallback onAddPayment;
  final Function(PaymentTransaction tx) onEditPayment;
  final VoidCallback onPaymentChanged;

  const _CustomerHistoryDialog({
    required this.customer,
    required this.onAddPayment,
    required this.onEditPayment,
    required this.onPaymentChanged,
  });

  @override
  State<_CustomerHistoryDialog> createState() => _CustomerHistoryDialogState();
}

class _CustomerHistoryDialogState extends State<_CustomerHistoryDialog> {
  bool _isLoading = true;
  List<PaymentTransaction> _transactions = [];

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() => _isLoading = true);
    final data = await AdminPaymentService.fetchCustomerPaymentProfile(widget.customer.customerId);
    if (mounted) {
      setState(() {
        _transactions = (data?['transactions'] as List<PaymentTransaction>?) ?? [];
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat('#,##,###');

    return AlertDialog(
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              const Icon(Icons.account_balance_wallet, color: Color(0xFF059669)),
              const SizedBox(width: 8),
              Text('${widget.customer.customerName} — Payment History'),
            ],
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.add, size: 16),
            label: const Text('+ Add Payment', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF059669),
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.of(context).pop();
              widget.onAddPayment();
            },
          ),
        ],
      ),
      content: SizedBox(
        width: 700,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Balance Summary
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Contract Amount', style: TextStyle(fontSize: 11, color: Colors.grey)),
                            Text('₹${currency.format(widget.customer.totalAmount)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Contract Paid', style: TextStyle(fontSize: 11, color: Colors.grey)),
                            Text('₹${currency.format(widget.customer.paidAmount)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF059669))),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Contract Pending', style: TextStyle(fontSize: 11, color: Colors.grey)),
                            Text('₹${currency.format(widget.customer.pendingAmount)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFFDC2626))),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Additional Paid: ₹${currency.format(widget.customer.additionalPaid)}',
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF7C3AED)),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          'Total Received: ₹${currency.format(widget.customer.totalReceived)}',
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text('Payment Transactions', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 8),

            // Transactions list
            _isLoading
                ? const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()))
                : _transactions.isEmpty
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: Text('No payment transactions recorded for this customer yet.', style: TextStyle(color: Colors.grey)),
                        ),
                      )
                    : Container(
                        constraints: const BoxConstraints(maxHeight: 280),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade200),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: ListView.separated(
                          shrinkWrap: true,
                          itemCount: _transactions.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (ctx, idx) {
                            final tx = _transactions[idx];
                            return ListTile(
                              dense: true,
                              leading: CircleAvatar(
                                radius: 16,
                                backgroundColor: tx.isAdditional
                                    ? const Color(0xFF8B5CF6).withValues(alpha: 0.15)
                                    : const Color(0xFF059669).withValues(alpha: 0.1),
                                child: Icon(
                                  tx.isAdditional
                                      ? AdditionalPaymentCategory.getCategoryIcon(tx.additionalCategory ?? '')
                                      : PaymentMode.getModeIcon(tx.paymentMode),
                                  size: 16,
                                  color: tx.isAdditional ? const Color(0xFF7C3AED) : const Color(0xFF059669),
                                ),
                              ),
                              title: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Text('₹${currency.format(tx.amount)} • ${tx.paymentMode}', style: const TextStyle(fontWeight: FontWeight.bold)),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: tx.isAdditional
                                              ? const Color(0xFF8B5CF6).withValues(alpha: 0.1)
                                              : const Color(0xFF0284C7).withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          tx.isAdditional ? tx.categoryDisplayName : 'Contract',
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: tx.isAdditional ? const Color(0xFF7C3AED) : const Color(0xFF0284C7),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  Text(DateFormat('dd/MM/yyyy').format(tx.paymentDate), style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                ],
                              ),
                              subtitle: Text(
                                '${tx.referenceNumber?.isNotEmpty == true ? "Ref: ${tx.referenceNumber} • " : ""}${tx.remarks?.isNotEmpty == true ? tx.remarks : "No remarks"}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              trailing: IconButton(
                                icon: const Icon(Icons.edit_outlined, size: 16),
                                tooltip: 'Edit',
                                onPressed: () {
                                  Navigator.of(context).pop();
                                  widget.onEditPayment(tx);
                                },
                              ),
                            );
                          },
                        ),
                      ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }
}

/// Dialog showing additional payments category-wise analytics and breakdown
class _AdditionalPaymentReportDialog extends StatefulWidget {
  const _AdditionalPaymentReportDialog();

  @override
  State<_AdditionalPaymentReportDialog> createState() => _AdditionalPaymentReportDialogState();
}

class _AdditionalPaymentReportDialogState extends State<_AdditionalPaymentReportDialog> {
  bool _isLoading = true;
  Map<String, double> _breakdown = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final res = await AdminPaymentService.fetchCategoryPaymentBreakdown();
    if (mounted) {
      setState(() {
        _breakdown = res;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat('#,##,###');
    final totalAdditional = _breakdown.values.fold<double>(0.0, (sum, val) => sum + val);

    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.analytics_rounded, color: Color(0xFF6366F1)),
          SizedBox(width: 8),
          Text('Additional Payment Report'),
        ],
      ),
      content: SizedBox(
        width: 520,
        child: _isLoading
            ? const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()))
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Total summary card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6366F1).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFF6366F1).withValues(alpha: 0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Total Additional Collections',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF4338CA)),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '₹${currency.format(totalAdditional)}',
                          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF4338CA)),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Collections beyond contract quotation (materials, extra work, transport)',
                          style: TextStyle(fontSize: 11, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text('Category-wise Breakdown', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 8),

                  ...AdditionalPaymentCategory.allCategories.map((cat) {
                    final amt = _breakdown[cat] ?? 0.0;
                    final pct = totalAdditional > 0 ? (amt / totalAdditional) : 0.0;
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Icon(AdditionalPaymentCategory.getCategoryIcon(cat), size: 18, color: const Color(0xFF6366F1)),
                          const SizedBox(width: 10),
                          Expanded(
                            flex: 3,
                            child: Text(
                              AdditionalPaymentCategory.displayName(cat),
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: pct,
                                minHeight: 8,
                                backgroundColor: Colors.grey.shade200,
                                valueColor: const AlwaysStoppedAnimation(Color(0xFF6366F1)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          SizedBox(
                            width: 90,
                            child: Text(
                              '₹${currency.format(amt)}',
                              textAlign: TextAlign.right,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }
}
