import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/customer_hishob.dart';
import '../services/customer_hishob_service.dart';
import '../services/supabase_service.dart';
import '../widgets/customer_hishob_detail_dialog.dart';
import '../widgets/hishob_add_payment_dialog.dart';

class CustomerHishobScreen extends StatefulWidget {
  const CustomerHishobScreen({super.key});

  @override
  State<CustomerHishobScreen> createState() => _CustomerHishobScreenState();
}

class _CustomerHishobScreenState extends State<CustomerHishobScreen> {
  final _inr = NumberFormat('#,##,##0', 'en_IN');
  final TextEditingController _searchController = TextEditingController();

  List<CustomerHishobEntry> _entries = [];
  CustomerHishobMetrics _metrics = CustomerHishobMetrics.empty();
  bool _isLoading = true;

  String _selectedStatusFilter = 'All'; // 'All', 'Pending', 'Partially Paid', 'Paid'
  DateTimeRange? _selectedDateRange;

  StreamSubscription? _realtimeSub;

  @override
  void initState() {
    super.initState();
    _loadData();
    _initRealtime();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _realtimeSub?.cancel();
    super.dispose();
  }

  void _initRealtime() {
    try {
      final channel = SupabaseService.client.channel('public:hishob_realtime');
      channel
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'customer_payment_transactions',
            callback: (_) {
              if (mounted) _loadData(silent: true);
            },
          )
          .subscribe();
    } catch (_) {}
  }

  Future<void> _loadData({bool silent = false}) async {
    if (!silent) {
      setState(() => _isLoading = true);
    }

    try {
      final result = await CustomerHishobService.fetchHishobData(
        searchQuery: _searchController.text.trim(),
        statusFilter: _selectedStatusFilter,
        dateRange: _selectedDateRange,
      );

      if (mounted) {
        setState(() {
          _entries = result.entries;
          _metrics = result.metrics;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading Hishob data: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _onSearchChanged(String val) {
    _loadData(silent: true);
  }

  void _onStatusFilterSelected(String filter) {
    setState(() => _selectedStatusFilter = filter);
    _loadData();
  }

  void _viewHishob(CustomerHishobEntry entry) {
    CustomerHishobDetailDialog.show(
      context,
      entry: entry,
      onDataChanged: () => _loadData(silent: true),
    );
  }

  void _openAddPayment(CustomerHishobEntry entry) {
    HishobAddPaymentDialog.show(
      context,
      customerEntry: entry,
      onSaved: () => _loadData(silent: true),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 900;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: RefreshIndicator(
        onRefresh: () => _loadData(),
        child: CustomScrollView(
          slivers: [
            // Top App Bar / Title
            SliverToBoxAdapter(
              child: Container(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
                color: Colors.white,
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFECFDF5),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.account_balance_wallet_rounded, color: Color(0xFF059669), size: 26),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Customer Hishob',
                            style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
                          ),
                          Text(
                            'Customer-wise receivables, invoice balances and actual payment history',
                            style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF64748B)),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.refresh_rounded),
                      tooltip: 'Refresh',
                      onPressed: () => _loadData(),
                    ),
                  ],
                ),
              ),
            ),

            // 1. Hishob Dashboard KPI Metrics Cards
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
                child: _buildKpiCards(isDesktop),
              ),
            ),

            // 2. Search & Filter Bar
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
                child: _buildSearchBar(context, isDesktop),
              ),
            ),

            // 3. Customer-wise Hishob List
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
              sliver: _isLoading
                  ? const SliverToBoxAdapter(
                      child: Center(
                        child: Padding(
                          padding: EdgeInsets.all(40),
                          child: CircularProgressIndicator(),
                        ),
                      ),
                    )
                  : _entries.isEmpty
                      ? SliverToBoxAdapter(child: _buildEmptyState())
                      : SliverToBoxAdapter(child: _buildCustomerTable(isDesktop)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKpiCards(bool isDesktop) {
    final cards = [
      _KpiCard(
        title: 'Total Customer Amount',
        value: '₹${_inr.format(_metrics.totalCustomerAmount)}',
        subtitle: 'From saved invoices',
        icon: Icons.receipt_long_rounded,
        color: const Color(0xFF1E293B),
        bgGradient: const [Color(0xFFF8FAFC), Color(0xFFF1F5F9)],
      ),
      _KpiCard(
        title: 'Total Paid Amount',
        value: '₹${_inr.format(_metrics.totalPaidAmount)}',
        subtitle: 'Actual recorded payments',
        icon: Icons.check_circle_outline_rounded,
        color: const Color(0xFF059669),
        bgGradient: const [Color(0xFFECFDF5), Color(0xFFD1FAE5)],
      ),
      _KpiCard(
        title: 'Total Pending Amount',
        value: '₹${_inr.format(_metrics.totalPendingAmount)}',
        subtitle: 'Outstanding receivables',
        icon: Icons.hourglass_top_rounded,
        color: _metrics.totalPendingAmount > 0 ? const Color(0xFFDC2626) : const Color(0xFF059669),
        bgGradient: _metrics.totalPendingAmount > 0
            ? const [Color(0xFFFEF2F2), Color(0xFFFEE2E2)]
            : const [Color(0xFFECFDF5), Color(0xFFD1FAE5)],
      ),
      _KpiCard(
        title: 'Pending Customers',
        value: '${_metrics.pendingCustomersCount}',
        subtitle: 'With balance due',
        icon: Icons.people_outline_rounded,
        color: const Color(0xFFD97706),
        bgGradient: const [Color(0xFFFFFBEB), Color(0xFFFEF3C7)],
      ),
      _KpiCard(
        title: 'Fully Paid Customers',
        value: '${_metrics.fullyPaidCustomersCount}',
        subtitle: 'All invoices cleared',
        icon: Icons.verified_user_outlined,
        color: const Color(0xFF0284C7),
        bgGradient: const [Color(0xFFF0F9FF), Color(0xFFE0F2FE)],
      ),
    ];

    if (isDesktop) {
      return Row(
        children: cards.map((c) => Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: c))).toList(),
      );
    } else {
      return LayoutBuilder(builder: (context, constraints) {
        final cardWidth = (constraints.maxWidth - 8) / 2;
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: cards.map((c) => SizedBox(width: cardWidth, child: c)).toList(),
        );
      });
    }
  }

  Widget _buildSearchBar(BuildContext context, bool isDesktop) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Search Input (Name, Consumer No, Invoice No)
              Expanded(
                child: TextField(
                  controller: _searchController,
                  onChanged: _onSearchChanged,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search_rounded, size: 20),
                    hintText: 'Search by Customer Name, Consumer No, or Invoice No...',
                    hintStyle: GoogleFonts.inter(fontSize: 13, color: Colors.grey.shade500),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              _loadData(silent: true);
                            },
                          )
                        : null,
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Date Range Picker
              OutlinedButton.icon(
                onPressed: () async {
                  final picked = await showDateRangePicker(
                    context: context,
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now().add(const Duration(days: 30)),
                    initialDateRange: _selectedDateRange,
                  );
                  if (picked != null) {
                    setState(() => _selectedDateRange = picked);
                    _loadData();
                  }
                },
                icon: const Icon(Icons.date_range_rounded, size: 18),
                label: Text(
                  _selectedDateRange != null
                      ? '${DateFormat('dd/MM').format(_selectedDateRange!.start)} - ${DateFormat('dd/MM/yy').format(_selectedDateRange!.end)}'
                      : 'Date Filter',
                  style: GoogleFonts.inter(fontSize: 13),
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
              if (_selectedDateRange != null) ...[
                const SizedBox(width: 4),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 18),
                  tooltip: 'Clear Date Filter',
                  onPressed: () {
                    setState(() => _selectedDateRange = null);
                    _loadData();
                  },
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),

          // Status Filter Chips
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildFilterChip('All', 'All (${_metrics.totalCustomers})'),
              _buildFilterChip('Pending', 'Pending (${_metrics.pendingCustomersCount})'),
              _buildFilterChip('Partially Paid', 'Partially Paid'),
              _buildFilterChip('Paid', 'Fully Paid (${_metrics.fullyPaidCustomersCount})'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String value, String label) {
    final isSelected = _selectedStatusFilter == value;
    return ChoiceChip(
      label: Text(label),
      labelStyle: GoogleFonts.inter(
        fontSize: 12,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
        color: isSelected ? Colors.white : const Color(0xFF475569),
      ),
      selected: isSelected,
      selectedColor: const Color(0xFF0F766E),
      backgroundColor: const Color(0xFFF1F5F9),
      showCheckmark: false,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide.none),
      onSelected: (_) => _onStatusFilterSelected(value),
    );
  }

  Widget _buildCustomerTable(bool isDesktop) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
            headingTextStyle: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13, color: const Color(0xFF475569)),
            dataRowMinHeight: 52,
            dataRowMaxHeight: 64,
            columns: const [
              DataColumn(label: Text('Customer Name')),
              DataColumn(label: Text('Consumer Number')),
              DataColumn(label: Text('Total Amount (₹)')),
              DataColumn(label: Text('Total Paid (₹)')),
              DataColumn(label: Text('Total Pending (₹)')),
              DataColumn(label: Text('Payment Status')),
              DataColumn(label: Text('Action')),
            ],
            rows: _entries.map((e) {
              Color statusBg;
              Color statusText;
              switch (e.paymentStatus) {
                case 'Paid':
                  statusBg = const Color(0xFFD1FAE5);
                  statusText = const Color(0xFF065F46);
                  break;
                case 'Partially Paid':
                  statusBg = const Color(0xFFE0F2FE);
                  statusText = const Color(0xFF0369A1);
                  break;
                case 'Unpaid':
                default:
                  statusBg = const Color(0xFFFEE2E2);
                  statusText = const Color(0xFF991B1B);
                  break;
              }

              return DataRow(
                cells: [
                  // Customer Name
                  DataCell(
                    InkWell(
                      onTap: () => _viewHishob(e),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            e.customerName,
                            style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: const Color(0xFF0F766E)),
                          ),
                          if (e.mobile != null && e.mobile!.isNotEmpty)
                            Text(
                              e.mobile!,
                              style: GoogleFonts.inter(fontSize: 11, color: Colors.grey.shade600),
                            ),
                        ],
                      ),
                    ),
                  ),

                  // Consumer Number
                  DataCell(
                    Text(
                      e.consumerNo,
                      style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: const Color(0xFF334155)),
                    ),
                  ),

                  // Total Amount
                  DataCell(
                    Text(
                      '₹${_inr.format(e.totalAmount)}',
                      style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                    ),
                  ),

                  // Total Paid
                  DataCell(
                    Text(
                      '₹${_inr.format(e.totalPaid)}',
                      style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: const Color(0xFF059669)),
                    ),
                  ),

                  // Total Pending
                  DataCell(
                    Text(
                      '₹${_inr.format(e.totalPending)}',
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.bold,
                        color: e.totalPending > 0 ? const Color(0xFFDC2626) : const Color(0xFF059669),
                      ),
                    ),
                  ),

                  // Payment Status
                  DataCell(
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusBg,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        e.paymentStatus,
                        style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: statusText),
                      ),
                    ),
                  ),

                  // Action
                  DataCell(
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        OutlinedButton.icon(
                          onPressed: () => _viewHishob(e),
                          icon: const Icon(Icons.menu_book_rounded, size: 16),
                          label: const Text('View Hishob'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF0F766E),
                            side: const BorderSide(color: Color(0xFF0F766E)),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                          ),
                        ),
                        const SizedBox(width: 6),
                        IconButton(
                          icon: const Icon(Icons.add_circle_outline_rounded, color: Color(0xFF059669), size: 20),
                          tooltip: 'Add Payment',
                          onPressed: () => _openAddPayment(e),
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

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(48),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Icon(Icons.search_off_rounded, size: 56, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(
            'No matching customer hishob records found',
            style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: const Color(0xFF334155)),
          ),
          const SizedBox(height: 6),
          Text(
            'Try adjusting your search query, status filter, or date range.',
            style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF64748B)),
          ),
        ],
      ),
    );
  }
}

class _KpiCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color color;
  final List<Color> bgGradient;

  const _KpiCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.bgGradient,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: bgGradient, begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF475569)),
              ),
              Icon(icon, size: 20, color: color),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.bold, color: color),
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B)),
          ),
        ],
      ),
    );
  }
}
