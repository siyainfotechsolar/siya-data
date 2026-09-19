import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
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

class _PaymentDashboardScreenState extends State<PaymentDashboardScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchCtrl = TextEditingController();

  PaymentDashboardSummary _summary = PaymentDashboardSummary.empty();
  List<PaymentTransaction> _transactions = [];
  List<ConsumerRecord> _pendingCustomers = [];
  List<ConsumerRecord> _followupCustomers = [];

  bool _isLoading = true;
  String _selectedModeFilter = 'All';
  String _selectedTypeFilter = 'All';
  String _selectedCategoryFilter = 'All';
  String _selectedVerificationFilter = 'All';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
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
      final txs = await AppDatabase.getAllPayments(
        modeFilter: _selectedModeFilter,
        typeFilter: _selectedTypeFilter == 'All'
            ? null
            : (_selectedTypeFilter == 'Contract' ? 'CONTRACT' : 'ADDITIONAL'),
        categoryFilter: _selectedCategoryFilter == 'All' ? null : _selectedCategoryFilter,
        verificationFilter: _selectedVerificationFilter,
      );

      // Fetch pending customers from local SQLite
      final allRecords = await AppDatabase.getAllConsumerRecords();
      final pendingCusts = allRecords
          .where((r) => r.pendingAmount > 0 && r.customerWorkState != 'COMPLETED')
          .toList()
        ..sort((a, b) => b.pendingAmount.compareTo(a.pendingAmount));

      // Fetch follow-up customers
      final fuCusts = allRecords
          .where((r) => r.hasActiveFollowup == true)
          .toList()
        ..sort((a, b) => (a.followupDate ?? DateTime.now()).compareTo(b.followupDate ?? DateTime.now()));

      if (mounted) {
        setState(() {
          _summary = summary;
          _transactions = txs;
          _pendingCustomers = pendingCusts;
          _followupCustomers = fuCusts;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading payment dashboard: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _onSearchChanged(String query) async {
    if (query.trim().isEmpty) {
      _loadDashboardData();
      return;
    }

    final results = await AppDatabase.searchPaymentsOffline(
      query,
      modeFilter: _selectedModeFilter,
      verificationFilter: _selectedVerificationFilter,
    );

    if (mounted) {
      setState(() {
        _transactions = results;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isSearchActive = _searchCtrl.text.isNotEmpty;

    return PopScope(
      canPop: !isSearchActive,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        setState(() {
          _searchCtrl.clear();
        });
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            tooltip: 'Back',
            onPressed: () {
              if (_searchCtrl.text.isNotEmpty) {
                setState(() {
                  _searchCtrl.clear();
                });
              } else {
                Navigator.of(context).pop();
              }
            },
          ),
          title: const Text('Payment Hub', style: TextStyle(fontWeight: FontWeight.bold)),
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
            icon: const Icon(Icons.refresh),
            onPressed: _loadDashboardData,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: theme.colorScheme.primary,
          unselectedLabelColor: Colors.grey,
          indicatorColor: theme.colorScheme.primary,
          tabs: [
            Tab(
              icon: const Icon(Icons.history_rounded, size: 20),
              text: 'Transactions (${_transactions.length})',
            ),
            Tab(
              icon: const Icon(Icons.hourglass_top_rounded, size: 20),
              text: 'Pending (${_pendingCustomers.length})',
            ),
            Tab(
              icon: const Icon(Icons.event_note_rounded, size: 20),
              text: 'Follow-ups (${_followupCustomers.length})',
            ),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadDashboardData,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // 1. TOP METRICS CAROUSEL / SUMMARY CARDS
                  _buildSummaryCards(theme, isDark),
                  const SizedBox(height: 14),

                  // 2. QUICK ACTION MODULE BUTTONS
                  _buildQuickActionButtons(theme, isDark),
                  const SizedBox(height: 16),

                  // 3. OFFLINE SYNC ALERT BANNER
                  if (_summary.pendingSyncCount > 0) ...[
                    _buildPendingSyncBanner(theme),
                    const SizedBox(height: 16),
                  ],

                  // 4. SEARCH & MODE FILTER BAR
                  _buildSearchAndFilters(theme, isDark),
                  const SizedBox(height: 16),

                  // 4. TABBED CONTENT
                  SizedBox(
                    height: 520,
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        _buildTransactionsTab(theme, isDark),
                        _buildPendingTab(theme, isDark),
                        _buildFollowupsTab(theme, isDark),
                      ],
                    ),
                  ),
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add_rounded),
        label: const Text('Record Payment', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: Colors.white,
        onPressed: () async {
          final res = await AddPaymentDialog.show(context);
          if (res == true) {
            _loadDashboardData();
          }
        },
      ),
      ),
    );
  }

  Widget _buildQuickActionButtons(ThemeData theme, bool isDark) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          // 1. [+ Add Payment]
          FilledButton.icon(
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('+ Add Payment', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF059669),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () async {
              final res = await AddPaymentDialog.show(context);
              if (res == true) {
                _loadDashboardData();
              }
            },
          ),
          const SizedBox(width: 8),

          // 2. [Payment History]
          OutlinedButton.icon(
            icon: const Icon(Icons.history_rounded, size: 18),
            label: const Text('Payment History', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              _tabController.animateTo(0);
            },
          ),
          const SizedBox(width: 8),

          // 3. [Customer Payments]
          OutlinedButton.icon(
            icon: const Icon(Icons.people_outline_rounded, size: 18),
            label: const Text('Customer Payments', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              _tabController.animateTo(1);
            },
          ),
          const SizedBox(width: 8),

          // 4. [Payment Follow-up]
          OutlinedButton.icon(
            icon: const Icon(Icons.phone_callback_rounded, size: 18),
            label: const Text('Payment Follow-up', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              _tabController.animateTo(2);
            },
          ),
          const SizedBox(width: 8),

          // 5. [Payment Receipts]
          OutlinedButton.icon(
            icon: const Icon(Icons.receipt_long_rounded, size: 18, color: Color(0xFF059669)),
            label: const Text('Payment Receipts', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF059669))),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Color(0xFFA7F3D0)),
              backgroundColor: const Color(0xFFECFDF5),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              _tabController.animateTo(0);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Showing all payments. Tap receipt or WhatsApp icon on any entry to view or share.'),
                  duration: Duration(seconds: 3),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCards(ThemeData theme, bool isDark) {
    return Column(
      children: [
        // Primary Financial Summary Row (Contract Collection, Additional Collection, Total Collection)
        Row(
          children: [
            Expanded(
              child: _statCard(
                title: "Contract",
                value: '₹${NumberFormat('#,##,###').format(_summary.contractCollection > 0 ? _summary.contractCollection : _summary.totalPaidAmount)}',
                subtitle: 'Contract Collection',
                color: const Color(0xFF0284C7), // Blue
                icon: Icons.receipt_long_rounded,
                isDark: isDark,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _statCard(
                title: "Additional",
                value: '₹${NumberFormat('#,##,###').format(_summary.additionalCollection)}',
                subtitle: 'Extra Material/Work',
                color: const Color(0xFF7C3AED), // Purple
                icon: Icons.add_circle_outline_rounded,
                isDark: isDark,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _statCard(
                title: "Total Received",
                value: '₹${NumberFormat('#,##,###').format(_summary.totalReceivedAmount)}',
                subtitle: 'Total Collection',
                color: const Color(0xFF059669), // Green
                icon: Icons.check_circle_outline_rounded,
                isDark: isDark,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // Balance & Run-rate Row (Contract Pending, Today, Month)
        Row(
          children: [
            Expanded(
              child: _miniStatCard(
                title: "Contract Pending",
                value: '₹${NumberFormat('#,##,###').format(_summary.totalPendingAmount)}',
                color: const Color(0xFFDC2626),
                isDark: isDark,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _miniStatCard(
                title: "Today's Collection",
                value: '₹${NumberFormat('#,##,###').format(_summary.todayCollection)} (${_summary.todayPaymentsCount})',
                color: const Color(0xFF059669),
                isDark: isDark,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _miniStatCard(
                title: 'This Month',
                value: '₹${NumberFormat('#,##,###').format(_summary.monthCollection)}',
                color: const Color(0xFFD97706),
                isDark: isDark,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _statCard({
    required String title,
    required String value,
    required String subtitle,
    required Color color,
    required IconData icon,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w600)),
              Icon(icon, size: 20, color: color),
            ],
          ),
          const SizedBox(height: 8),
          Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 4),
          Text(subtitle, style: const TextStyle(fontSize: 11, color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _miniStatCard({
    required String title,
    required String value,
    required Color color,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 10, color: Colors.grey), overflow: TextOverflow.ellipsis),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color), overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }

  Widget _buildPendingSyncBanner(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFEA580C).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFEA580C)),
      ),
      child: Row(
        children: [
          const Icon(Icons.cloud_off_rounded, color: Color(0xFFEA580C), size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${_summary.pendingSyncCount} Offline Payment(s) Pending Sync',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFFEA580C)),
                ),
                const Text(
                  'Stored safely in local database. Will push to cloud automatically.',
                  style: TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilters(ThemeData theme, bool isDark) {
    return Column(
      children: [
        TextField(
          controller: _searchCtrl,
          onChanged: _onSearchChanged,
          decoration: InputDecoration(
            hintText: 'Search by consumer no, name, UTR, ref...',
            prefixIcon: const Icon(Icons.search_rounded),
            suffixIcon: _searchCtrl.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear, size: 18),
                    onPressed: () {
                      _searchCtrl.clear();
                      _onSearchChanged('');
                    },
                  )
                : null,
            filled: true,
            fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
          ),
        ),
        const SizedBox(height: 8),
        // Type Filters (Contract vs Additional)
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _filterChip('All Types', _selectedTypeFilter == 'All' ? 'All Types' : _selectedTypeFilter, (val) {
                setState(() {
                  _selectedTypeFilter = 'All';
                  _selectedCategoryFilter = 'All';
                });
                _loadDashboardData();
              }),
              _filterChip('Contract', _selectedTypeFilter, (val) {
                setState(() {
                  _selectedTypeFilter = val;
                  _selectedCategoryFilter = 'All';
                });
                _loadDashboardData();
              }),
              _filterChip('Additional', _selectedTypeFilter, (val) {
                setState(() => _selectedTypeFilter = val);
                _loadDashboardData();
              }),
              if (_selectedTypeFilter == 'Additional') ...[
                ...AdditionalPaymentCategory.allCategories.map((c) {
                  return _filterChip(
                    AdditionalPaymentCategory.displayName(c),
                    _selectedCategoryFilter == c ? AdditionalPaymentCategory.displayName(c) : '',
                    (val) {
                      setState(() => _selectedCategoryFilter = _selectedCategoryFilter == c ? 'All' : c);
                      _loadDashboardData();
                    },
                  );
                }),
              ],
            ],
          ),
        ),
        const SizedBox(height: 6),
        // Mode Filters
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _filterChip('All Modes', _selectedModeFilter == 'All' ? 'All Modes' : _selectedModeFilter, (val) {
                setState(() => _selectedModeFilter = 'All');
                _loadDashboardData();
              }),
              ...PaymentMode.allModes.map((m) {
                return _filterChip(m, _selectedModeFilter, (val) {
                  setState(() => _selectedModeFilter = val);
                  _loadDashboardData();
                });
              }),
            ],
          ),
        ),
        const SizedBox(height: 6),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _filterChip('All Status', _selectedVerificationFilter == 'All' ? 'All Status' : _selectedVerificationFilter, (val) {
                setState(() => _selectedVerificationFilter = 'All');
                _loadDashboardData();
              }),
              ...PaymentVerificationStatus.allStatuses.map((s) {
                return _filterChip(s, _selectedVerificationFilter, (val) {
                  setState(() => _selectedVerificationFilter = val);
                  _loadDashboardData();
                });
              }),
            ],
          ),
        ),
      ],
    );
  }

  Widget _filterChip(String label, String currentVal, ValueChanged<String> onSelected) {
    final isSelected = label == currentVal;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: FilterChip(
        label: Text(label, style: TextStyle(fontSize: 11, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
        selected: isSelected,
        onSelected: (_) => onSelected(label),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
      ),
    );
  }

  Widget _buildTransactionsTab(ThemeData theme, bool isDark) {
    if (_transactions.isEmpty) {
      return const Center(child: Text('No payment transactions found.'));
    }

    return ListView.builder(
      itemCount: _transactions.length,
      itemBuilder: (ctx, idx) {
        final tx = _transactions[idx];
        final isDraft = tx.isPendingSync;

        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: isDraft
                  ? const Color(0xFFEA580C).withValues(alpha: 0.15)
                  : const Color(0xFF059669).withValues(alpha: 0.15),
              child: Icon(
                PaymentMode.getModeIcon(tx.paymentMode),
                color: isDraft ? const Color(0xFFEA580C) : const Color(0xFF059669),
                size: 20,
              ),
            ),
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    '₹${NumberFormat('#,##,###').format(tx.amount)}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: isDraft
                        ? const Color(0xFFEA580C).withValues(alpha: 0.1)
                        : const Color(0xFF059669).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    isDraft ? 'PENDING SYNC' : 'SYNCED',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: isDraft ? const Color(0xFFEA580C) : const Color(0xFF059669),
                    ),
                  ),
                ),
              ],
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                // Payment Type & Category Badge
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: tx.isAdditional
                            ? const Color(0xFF7C3AED).withValues(alpha: 0.12)
                            : const Color(0xFF0284C7).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (tx.isAdditional) ...[
                            Icon(
                              AdditionalPaymentCategory.getCategoryIcon(tx.additionalCategory ?? ''),
                              size: 11,
                              color: const Color(0xFF7C3AED),
                            ),
                            const SizedBox(width: 4),
                          ],
                          Text(
                            tx.isAdditional
                                ? 'Additional: ${AdditionalPaymentCategory.displayName(tx.additionalCategory ?? "")}'
                                : 'Contract Payment',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: tx.isAdditional ? const Color(0xFF7C3AED) : const Color(0xFF0284C7),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${DateFormat("dd/MM/yyyy").format(tx.paymentDate)} — ₹${NumberFormat("#,##,###").format(tx.amount)} — ${tx.paymentMode}',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
                Text(
                  '${tx.consumerNo}${tx.remarks != null && tx.remarks!.isNotEmpty ? " • ${tx.remarks}" : ""}${tx.referenceNumber != null && tx.referenceNumber!.isNotEmpty ? " • Ref: ${tx.referenceNumber}" : ""}',
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.share_rounded, size: 18, color: Color(0xFF25D366)),
                  tooltip: 'WhatsApp Receipt',
                  onPressed: () async {
                    final customer = await AppDatabase.getConsumerRecordById(tx.customerId);
                    if (customer != null && context.mounted) {
                      await PaymentReceiptService.shareViaWhatsApp(
                        tx: tx,
                        customer: customer,
                      );
                    }
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.receipt_long_rounded, size: 20, color: Color(0xFF059669)),
                  tooltip: 'View PDF',
                  onPressed: () async {
                    final customer = await AppDatabase.getConsumerRecordById(tx.customerId);
                    if (customer != null && context.mounted) {
                      final file = await PaymentReceiptService.generateReceiptPdf(
                        tx: tx,
                        customer: customer,
                      );
                      await PaymentReceiptService.openReceipt(file);
                    }
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPendingTab(ThemeData theme, bool isDark) {
    if (_pendingCustomers.isEmpty) {
      return const Center(child: Text('All customers are fully paid!'));
    }

    return ListView.builder(
      itemCount: _pendingCustomers.length,
      itemBuilder: (ctx, idx) {
        final cust = _pendingCustomers[idx];
        final milestone = PaymentService.evaluateMilestone(cust);

        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(cust.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                          Text('${cust.consumerNo} • ${cust.village ?? cust.address ?? "-"}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '₹${NumberFormat('#,##,###').format(cust.pendingAmount)}',
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFFDC2626)),
                        ),
                        const Text('Pending Balance', style: TextStyle(fontSize: 10, color: Colors.grey)),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // Milestone Action Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: milestone.badgeColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: milestone.badgeColor.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.bolt_rounded, size: 14, color: milestone.badgeColor),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          'Stage: ${cust.installationStatus} — ${milestone.actionRecommendation}',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: milestone.badgeColor),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton.icon(
                      icon: const Icon(Icons.phone_in_talk_rounded, size: 14),
                      label: const Text('Follow-up', style: TextStyle(fontSize: 12)),
                      onPressed: () => _openScheduleFollowupDialog(cust),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.add, size: 14),
                      label: const Text('Pay', style: TextStyle(fontSize: 12)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.colorScheme.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      ),
                      onPressed: () async {
                        final res = await AddPaymentDialog.show(context, preselectedCustomer: cust);
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
    );
  }

  Widget _buildFollowupsTab(ThemeData theme, bool isDark) {
    if (_followupCustomers.isEmpty) {
      return const Center(child: Text('No active payment follow-ups.'));
    }

    return ListView.builder(
      itemCount: _followupCustomers.length,
      itemBuilder: (ctx, idx) {
        final cust = _followupCustomers[idx];
        final dateStr = cust.followupDate != null
            ? DateFormat('dd MMM yyyy').format(cust.followupDate!)
            : 'Scheduled';

        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ListTile(
            leading: const CircleAvatar(
              backgroundColor: Color(0xFFF59E0B),
              child: Icon(Icons.notifications_active_rounded, color: Colors.white, size: 18),
            ),
            title: Text(cust.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            subtitle: Text(
              'Date: $dateStr\nPending: ₹${NumberFormat('#,##,###').format(cust.pendingAmount)} • ${cust.followupRemarks ?? cust.followupReason ?? ""}',
              style: const TextStyle(fontSize: 12),
            ),
            trailing: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: Colors.white,
              ),
              child: const Text('Collect', style: TextStyle(fontSize: 12)),
              onPressed: () async {
                final res = await AddPaymentDialog.show(context, preselectedCustomer: cust);
                if (res == true) _loadDashboardData();
              },
            ),
          ),
        );
      },
    );
  }

  void _openScheduleFollowupDialog(ConsumerRecord customer) {
    DateTime selectedDate = DateTime.now().add(const Duration(days: 2));
    final noteCtrl = TextEditingController(text: 'Customer requested callback for payment');

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('Schedule Follow-up: ${customer.name}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Follow-up Date'),
                subtitle: Text(DateFormat('dd MMMM yyyy').format(selectedDate)),
                trailing: const Icon(Icons.calendar_today_rounded),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: ctx,
                    initialDate: selectedDate,
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 90)),
                  );
                  if (picked != null) {
                    setDlgState(() => selectedDate = picked);
                  }
                },
              ),
              TextField(
                controller: noteCtrl,
                decoration: const InputDecoration(labelText: 'Follow-up Note'),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              child: const Text('Schedule'),
              onPressed: () async {
                await PaymentService.schedulePaymentFollowup(
                  customerId: customer.id!,
                  followupDate: selectedDate,
                  remarks: noteCtrl.text.trim(),
                );
                if (ctx.mounted) Navigator.pop(ctx);
                _loadDashboardData();
              },
            ),
          ],
        ),
      ),
    );
  }
}
