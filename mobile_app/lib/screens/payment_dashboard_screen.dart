import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/customer_payment.dart';
import '../models/consumer_record.dart';
import '../services/payment_service.dart';
import '../services/payment_receipt_service.dart';
import '../services/app_database.dart';
import '../widgets/add_payment_dialog.dart';
import '../widgets/sync_status_indicator.dart';
import 'payment_reports_screen.dart';

class PaymentDashboardScreen extends StatefulWidget {
  const PaymentDashboardScreen({super.key});

  @override
  State<PaymentDashboardScreen> createState() => _PaymentDashboardScreenState();
}

class _PaymentDashboardScreenState extends State<PaymentDashboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchCtrl = TextEditingController();

  PaymentDashboardSummary _summary = PaymentDashboardSummary.empty();
  List<PaymentTransaction> _allTransactions = [];
  List<PaymentTransaction> _filteredTransactions = [];
  List<ConsumerRecord> _allPendingCustomers = [];
  List<ConsumerRecord> _filteredPendingCustomers = [];

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadDashboardData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadDashboardData() async {
    setState(() => _isLoading = true);

    try {
      final summary = await PaymentService.fetchDashboardSummary();
      final txs = await AppDatabase.getAllPayments();

      // Fetch pending customers from local SQLite
      final allRecords = await AppDatabase.getAllConsumerRecords();
      final pendingCusts = allRecords
          .where((r) => r.pendingAmount > 0 && r.customerWorkState != 'COMPLETED')
          .toList()
        ..sort((a, b) => b.pendingAmount.compareTo(a.pendingAmount));

      if (mounted) {
        setState(() {
          _summary = summary;
          _allTransactions = txs;
          _allPendingCustomers = pendingCusts;
          _isLoading = false;
        });
        _applySearch(_searchCtrl.text);
      }
    } catch (e) {
      debugPrint('Error loading payment dashboard: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _applySearch(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) {
      setState(() {
        _filteredTransactions = _allTransactions;
        _filteredPendingCustomers = _allPendingCustomers;
      });
      return;
    }

    setState(() {
      _filteredTransactions = _allTransactions.where((tx) {
        return tx.consumerNo.toLowerCase().contains(q) ||
            tx.paymentMode.toLowerCase().contains(q) ||
            (tx.remarks?.toLowerCase().contains(q) ?? false) ||
            (tx.referenceNumber?.toLowerCase().contains(q) ?? false) ||
            tx.amount.toString().contains(q);
      }).toList();

      _filteredPendingCustomers = _allPendingCustomers.where((c) {
        return c.name.toLowerCase().contains(q) ||
            c.consumerNo.toLowerCase().contains(q) ||
            (c.village?.toLowerCase().contains(q) ?? false) ||
            (c.mobile?.contains(q) ?? false) ||
            c.pendingAmount.toString().contains(q);
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Payments', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          const SyncStatusIndicator(),
          IconButton(
            icon: const Icon(Icons.bar_chart_rounded),
            tooltip: 'Payment Reports',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PaymentReportsScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
            onPressed: _loadDashboardData,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: theme.colorScheme.primary,
          unselectedLabelColor: Colors.grey,
          indicatorColor: theme.colorScheme.primary,
          indicatorWeight: 3,
          tabs: [
            Tab(
              icon: const Icon(Icons.check_circle_outline_rounded, size: 18),
              text: 'Received (${_filteredTransactions.length})',
            ),
            Tab(
              icon: const Icon(Icons.hourglass_top_rounded, size: 18),
              text: 'Pending Dues (${_filteredPendingCustomers.length})',
            ),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Top Metrics & Search (Clean & Simple)
                _buildTopSection(theme, isDark),

                // Tab Views with native natural scrolling
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildReceivedTab(theme, isDark),
                      _buildPendingTab(theme, isDark),
                    ],
                  ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add_rounded),
        label: const Text('Record Payment', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF059669),
        foregroundColor: Colors.white,
        onPressed: () async {
          final res = await AddPaymentDialog.show(context);
          if (res == true) {
            _loadDashboardData();
          }
        },
      ),
    );
  }

  Widget _buildTopSection(ThemeData theme, bool isDark) {
    final receivedAmount = _summary.totalReceivedAmount > 0
        ? _summary.totalReceivedAmount
        : _summary.totalPaidAmount;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        border: Border(
          bottom: BorderSide(
            color: isDark ? Colors.white12 : Colors.black.withValues(alpha: 0.06),
          ),
        ),
      ),
      child: Column(
        children: [
          // Clean 2-metric summary row
          Row(
            children: [
              // 1. Total Received
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF059669).withValues(alpha: isDark ? 0.2 : 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFF059669).withValues(alpha: 0.25),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.check_circle_rounded, size: 14, color: Color(0xFF059669)),
                          const SizedBox(width: 5),
                          Text(
                            'TOTAL RECEIVED',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                              color: isDark ? const Color(0xFF34D399) : const Color(0xFF065F46),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '₹${NumberFormat('#,##,###').format(receivedAmount)}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF059669),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),

              // 2. Pending Dues
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDC2626).withValues(alpha: isDark ? 0.2 : 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFFDC2626).withValues(alpha: 0.25),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.hourglass_bottom_rounded, size: 14, color: Color(0xFFDC2626)),
                          const SizedBox(width: 5),
                          Text(
                            'PENDING DUES',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                              color: isDark ? const Color(0xFFF87171) : const Color(0xFF991B1B),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '₹${NumberFormat('#,##,###').format(_summary.totalPendingAmount)}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFFDC2626),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Simple clean search input
          TextField(
            controller: _searchCtrl,
            onChanged: _applySearch,
            decoration: InputDecoration(
              hintText: 'Search consumer no, name, mode, amount...',
              hintStyle: const TextStyle(fontSize: 13),
              prefixIcon: const Icon(Icons.search_rounded, size: 20),
              suffixIcon: _searchCtrl.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () {
                        _searchCtrl.clear();
                        _applySearch('');
                      },
                    )
                  : null,
              filled: true,
              fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                ),
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReceivedTab(ThemeData theme, bool isDark) {
    if (_filteredTransactions.isEmpty) {
      return RefreshIndicator(
        onRefresh: _loadDashboardData,
        child: ListView(
          children: [
            const SizedBox(height: 60),
            Center(
              child: Column(
                children: [
                  Icon(Icons.payments_outlined, size: 48, color: Colors.grey.shade400),
                  const SizedBox(height: 10),
                  Text(
                    _searchCtrl.text.isNotEmpty
                        ? 'No payments match "${_searchCtrl.text}"'
                        : 'No payment transactions recorded yet.',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadDashboardData,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
        itemCount: _filteredTransactions.length,
        itemBuilder: (ctx, idx) {
          final tx = _filteredTransactions[idx];
          final isDraft = tx.isPendingSync;

          return Card(
            margin: const EdgeInsets.only(bottom: 10),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(
                color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Mode Icon Badge
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: isDraft
                        ? const Color(0xFFEA580C).withValues(alpha: 0.12)
                        : const Color(0xFF059669).withValues(alpha: 0.12),
                    child: Icon(
                      PaymentMode.getModeIcon(tx.paymentMode),
                      color: isDraft ? const Color(0xFFEA580C) : const Color(0xFF059669),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Middle Information
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                tx.consumerNo,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Text(
                              '+ ₹${NumberFormat('#,##,###').format(tx.amount)}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 15,
                                color: Color(0xFF059669),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                tx.paymentMode,
                                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              DateFormat('dd MMM yyyy').format(tx.paymentDate),
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                            ),
                            if (tx.isAdditional) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF7C3AED).withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  'Additional',
                                  style: TextStyle(
                                    fontSize: 9,
                                    color: Color(0xFF7C3AED),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        if (tx.remarks != null && tx.remarks!.trim().isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            tx.remarks!,
                            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),

                  // Actions: WhatsApp & PDF Receipt
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.share_rounded, size: 20, color: Color(0xFF25D366)),
                        tooltip: 'WhatsApp Receipt',
                        onPressed: () async {
                          final customer = await AppDatabase.getConsumerRecordById(tx.customerId);
                          if (!mounted) return;
                          if (customer != null) {
                            await PaymentReceiptService.shareViaWhatsApp(
                              tx: tx,
                              customer: customer,
                            );
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Customer details not found')),
                            );
                          }
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.receipt_long_rounded, size: 20, color: Color(0xFF0284C7)),
                        tooltip: 'PDF Receipt',
                        onPressed: () async {
                          final customer = await AppDatabase.getConsumerRecordById(tx.customerId);
                          if (!mounted) return;
                          if (customer != null) {
                            final file = await PaymentReceiptService.generateReceiptPdf(
                              tx: tx,
                              customer: customer,
                            );
                            await PaymentReceiptService.openReceipt(file);
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Customer details not found')),
                            );
                          }
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPendingTab(ThemeData theme, bool isDark) {
    if (_filteredPendingCustomers.isEmpty) {
      return RefreshIndicator(
        onRefresh: _loadDashboardData,
        child: ListView(
          children: [
            const SizedBox(height: 60),
            Center(
              child: Column(
                children: [
                  const Icon(Icons.verified_rounded, size: 48, color: Color(0xFF059669)),
                  const SizedBox(height: 10),
                  Text(
                    _searchCtrl.text.isNotEmpty
                        ? 'No pending customers match "${_searchCtrl.text}"'
                        : 'Great news! All customers are fully paid.',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadDashboardData,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
        itemCount: _filteredPendingCustomers.length,
        itemBuilder: (ctx, idx) {
          final cust = _filteredPendingCustomers[idx];

          return Card(
            margin: const EdgeInsets.only(bottom: 10),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(
                color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              cust.name,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${cust.consumerNo} • ${cust.village ?? cust.address ?? "-"}',
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '₹${NumberFormat('#,##,###').format(cust.pendingAmount)}',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFFDC2626),
                            ),
                          ),
                          Text(
                            'Pending Dues',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey.shade600,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (cust.mobile != null && cust.mobile!.trim().isNotEmpty) ...[
                        OutlinedButton.icon(
                          icon: const Icon(Icons.call, size: 14, color: Color(0xFF059669)),
                          label: const Text('Call', style: TextStyle(fontSize: 12)),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          onPressed: () async {
                            final phone = cust.mobile!.replaceAll(RegExp(r'[^\d+]'), '');
                            final uri = Uri.parse('tel:$phone');
                            if (await canLaunchUrl(uri)) {
                              await launchUrl(uri);
                            }
                          },
                        ),
                        const SizedBox(width: 8),
                      ],
                      FilledButton.icon(
                        icon: const Icon(Icons.add, size: 15),
                        label: const Text(
                          'Collect Payment',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF059669),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        onPressed: () async {
                          final res = await AddPaymentDialog.show(
                            context,
                            preselectedCustomer: cust,
                            initialAmount: cust.pendingAmount > 0 ? cust.pendingAmount : null,
                          );
                          if (res == true) _loadDashboardData();
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
