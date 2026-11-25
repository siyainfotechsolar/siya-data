import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'package:siya_shared/siya_shared.dart';
import '../services/sub_vendor_account_ledger_pdf_service.dart';
import '../services/sub_vendor_account_ledger_service.dart';
import '../services/sub_vendor_material_outward_service.dart';

final _currency = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 2);
final _dateFormat = DateFormat('dd-MM-yyyy');

/// Sub-Vendor Account Dashboard & Credit / Debit Ledger Screen.
/// Provides real-time visibility into:
/// - Total Credit (Receivable from Sub-Vendors)
/// - Total Debit (Payable / Payments Received / Advance Balance)
/// - Net Outstanding Balance (Sub-Vendor-wise and Overall)
/// - Chronological running-balance ledger with Excel and PDF Print exports.
class SubVendorAccountDashboardScreen extends StatefulWidget {
  final String? preselectedVendorId;

  const SubVendorAccountDashboardScreen({super.key, this.preselectedVendorId});

  @override
  State<SubVendorAccountDashboardScreen> createState() => _SubVendorAccountDashboardScreenState();
}

class _SubVendorAccountDashboardScreenState extends State<SubVendorAccountDashboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Data
  List<SubVendor> _vendors = [];
  SubVendorDashboardMetrics _metrics = SubVendorDashboardMetrics.empty();
  List<SubVendorAccountLedgerEntry> _ledgerEntries = [];

  bool _isLoading = true;
  String? _errorMessage;

  // Ledger Filter State
  String _selectedVendorId = 'All';
  DateTime? _filterFromDate;
  DateTime? _filterToDate;
  String _filterType = 'All';
  String _filterCategory = 'All';
  String _filterStatus = 'Active';
  final TextEditingController _searchCtrl = TextEditingController();

  // Branding Colors
  static const Color navyColor = Color(0xFF0D2B6F);
  static const Color greenColor = Color(0xFF059669);
  static const Color amberColor = Color(0xFFD97706);
  static const Color redColor = Color(0xFFDC2626);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    if (widget.preselectedVendorId != null) {
      _selectedVendorId = widget.preselectedVendorId!;
    }
    _loadAllData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadAllData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final vendors = await SubVendorMaterialOutwardService.fetchActiveSubVendors();
      final metrics = await SubVendorAccountLedgerService.calculateDashboardMetrics(
        preloadedVendors: vendors,
        fromDate: _filterFromDate,
        toDate: _filterToDate,
      );

      final entries = await SubVendorAccountLedgerService.fetchLedgerEntries(
        vendorId: _selectedVendorId,
        fromDate: _filterFromDate,
        toDate: _filterToDate,
        typeFilter: _filterType,
        categoryFilter: _filterCategory,
        statusFilter: _filterStatus,
        searchQuery: _searchCtrl.text,
      );

      if (mounted) {
        setState(() {
          _vendors = vendors;
          _metrics = metrics;
          _ledgerEntries = entries;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Column(
        children: [
          _buildTopBar(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: navyColor))
                : _errorMessage != null
                    ? _buildErrorView()
                    : TabBarView(
                        controller: _tabController,
                        children: [
                          _buildDashboardTab(),
                          _buildLedgerTab(),
                        ],
                      ),
          ),
        ],
      ),
    );
  }

  // ============================================================================
  // TOP BAR WITH NAVIGATION PILLS & ACTIONS
  // ============================================================================
  Widget _buildTopBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0), width: 1.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: navyColor.withOpacity(0.08), borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.account_balance_wallet_rounded, color: navyColor, size: 24),
          ),
          const SizedBox(width: 14),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Sub Vendor Account Dashboard & Ledger',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: navyColor),
              ),
              Text(
                'Real-time Credit / Debit balances, Material Receivables & Advance tracking',
                style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
              ),
            ],
          ),
          const Spacer(),
          // Quick Action: Record Payment
          ElevatedButton.icon(
            onPressed: _showRecordTransactionDialog,
            icon: const Icon(Icons.add_card_rounded, size: 16),
            label: const Text('Record Payment'),
            style: ElevatedButton.styleFrom(backgroundColor: greenColor, foregroundColor: Colors.white),
          ),
          const SizedBox(width: 12),
          // Tab Switcher
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(10)),
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              indicator: BoxDecoration(
                color: navyColor,
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(color: navyColor.withOpacity(0.2), blurRadius: 4, offset: const Offset(0, 2)),
                ],
              ),
              labelColor: Colors.white,
              unselectedLabelColor: const Color(0xFF475569),
              labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              tabs: const [
                Tab(icon: Icon(Icons.dashboard_rounded, size: 16), text: 'Account Dashboard'),
                Tab(icon: Icon(Icons.receipt_long_rounded, size: 16), text: 'Credit / Debit Ledger'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Card(
        margin: const EdgeInsets.all(24),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: redColor, size: 48),
              const SizedBox(height: 12),
              Text('Error loading ledger: $_errorMessage'),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _loadAllData,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
                style: ElevatedButton.styleFrom(backgroundColor: navyColor, foregroundColor: Colors.white),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================================
  // TAB 1: SUB VENDOR ACCOUNT DASHBOARD
  // ============================================================================
  Widget _buildDashboardTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: Primary Account Dashboard Cards (Matching User Spec Exactly)
          Row(
            children: [
              // Total Credit (Sub Vendor कडून येणे)
              Expanded(
                child: _buildBigMetricCard(
                  title: 'Total Credit',
                  subtitle: 'Sub Vendor कडून येणे (Receivable)',
                  amount: _currency.format(_metrics.totalCredit),
                  icon: Icons.trending_up_rounded,
                  color: greenColor,
                  bgColor: const Color(0xFFECFDF5),
                  borderColor: const Color(0xFFA7F3D0),
                ),
              ),
              const SizedBox(width: 16),
              // Total Debit (Sub Vendor ला देणे / जमा झालेले)
              Expanded(
                child: _buildBigMetricCard(
                  title: 'Total Debit',
                  subtitle: 'Sub Vendor ला देणे / मिळालेले',
                  amount: _currency.format(_metrics.totalDebit),
                  icon: Icons.trending_down_rounded,
                  color: amberColor,
                  bgColor: const Color(0xFFFFFBEB),
                  borderColor: const Color(0xFFFDE68A),
                ),
              ),
              const SizedBox(width: 16),
              // Net Outstanding Balance
              Expanded(
                child: _buildBigMetricCard(
                  title: 'Net Balance',
                  subtitle: _metrics.netBalance >= 0 ? 'आपल्याला Sub Vendor कडून येणे' : 'आपल्याला Sub Vendor ला देणे',
                  amount: '${_currency.format(_metrics.netBalance.abs())} ${_metrics.netBalance >= 0 ? "Cr" : "Dr"}',
                  icon: Icons.account_balance_wallet_rounded,
                  color: _metrics.netBalance >= 0 ? greenColor : redColor,
                  bgColor: _metrics.netBalance >= 0 ? const Color(0xFFECFDF5) : const Color(0xFFFEF2F2),
                  borderColor: _metrics.netBalance >= 0 ? const Color(0xFFA7F3D0) : const Color(0xFFFECACA),
                ),
              ),
            ],
          ),

          const SizedBox(height: 18),

          // Row 2: Secondary Category Breakdowns (Material vs Advance)
          Row(
            children: [
              // Material Account Summary Card
              Expanded(
                child: Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: const BorderSide(color: Color(0xFFE2E8F0))),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.inventory_2_outlined, color: navyColor, size: 18),
                            SizedBox(width: 8),
                            Text('A. Material Account Summary', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: navyColor)),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _buildSummarySubRow('Material Outward Value (Credit):', _currency.format(_metrics.totalMaterialOutwardValue), greenColor),
                        const SizedBox(height: 6),
                        _buildSummarySubRow('Material Payments Received (Debit):', _currency.format(_metrics.totalMaterialPaymentsReceived), amberColor),
                        const Divider(height: 16),
                        _buildSummarySubRow('Net Material Receivable:', _currency.format(_metrics.netMaterialReceivable), navyColor, isBold: true),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              // Advance Account Summary Card
              Expanded(
                child: Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: const BorderSide(color: Color(0xFFE2E8F0))),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.payments_outlined, color: amberColor, size: 18),
                            SizedBox(width: 8),
                            Text('B. Advance & Deposit Summary', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: amberColor)),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _buildSummarySubRow('Total Advance Given (Debit):', _currency.format(_metrics.totalAdvanceGiven), amberColor),
                        const SizedBox(height: 6),
                        _buildSummarySubRow('Advance Refunds Received (Credit):', _currency.format(_metrics.totalAdvanceRefundReceived), greenColor),
                        const Divider(height: 16),
                        _buildSummarySubRow('Net Advance Balance:', _currency.format(_metrics.netAdvanceBalance), navyColor, isBold: true),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Sub Vendor-wise Outstanding Balance Table
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Sub Vendor-wise Account Balances', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: navyColor)),
              OutlinedButton.icon(
                icon: const Icon(Icons.table_view, size: 16, color: greenColor),
                label: const Text('Export Summary (CSV)', style: TextStyle(color: greenColor)),
                style: OutlinedButton.styleFrom(side: const BorderSide(color: greenColor)),
                onPressed: () => SubVendorAccountLedgerPdfService.exportDashboardSummaryCsv(_metrics),
              ),
            ],
          ),
          const SizedBox(height: 12),

          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: const BorderSide(color: Color(0xFFE2E8F0))),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(const Color(0xFFF1F5F9)),
                columns: const [
                  DataColumn(label: Text('Code', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Sub Vendor Name', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Total Credit (येणे)', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Total Debit (देणे)', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Net Balance', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Material Receivable', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Advance Balance', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold))),
                ],
                rows: _metrics.vendorBalances.map((v) {
                  return DataRow(
                    cells: [
                      DataCell(Text(v.vendorCode, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                      DataCell(Text(v.vendorName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
                      DataCell(Text(_currency.format(v.totalCredit), style: const TextStyle(color: greenColor, fontWeight: FontWeight.bold))),
                      DataCell(Text(_currency.format(v.totalDebit), style: const TextStyle(color: amberColor, fontWeight: FontWeight.bold))),
                      DataCell(
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: v.netBalance >= 0 ? const Color(0xFFECFDF5) : const Color(0xFFFEF2F2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '${_currency.format(v.netBalance.abs())} ${v.netBalance >= 0 ? "Cr (येणे)" : "Dr (देणे)"}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              color: v.netBalance >= 0 ? greenColor : redColor,
                            ),
                          ),
                        ),
                      ),
                      DataCell(Text(_currency.format(v.materialReceivable), style: const TextStyle(fontSize: 12))),
                      DataCell(Text(_currency.format(v.advanceBalance), style: const TextStyle(fontSize: 12))),
                      DataCell(
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // View Ledger button
                            TextButton.icon(
                              onPressed: () {
                                setState(() => _selectedVendorId = v.vendorId);
                                _tabController.animateTo(1);
                                _loadAllData();
                              },
                              icon: const Icon(Icons.receipt_long, size: 14, color: navyColor),
                              label: const Text('View Ledger', style: TextStyle(fontSize: 12, color: navyColor)),
                            ),
                            // Print Statement button
                            IconButton(
                              icon: const Icon(Icons.print_outlined, size: 18, color: greenColor),
                              tooltip: 'Print Statement PDF',
                              onPressed: () => _printVendorStatement(v.vendorId),
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
        ],
      ),
    );
  }

  Widget _buildBigMetricCard({
    required String title,
    required String subtitle,
    required String amount,
    required IconData icon,
    required Color color,
    required Color bgColor,
    required Color borderColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor, width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color)),
              Icon(icon, color: color, size: 22),
            ],
          ),
          const SizedBox(height: 10),
          Text(amount, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 4),
          Text(subtitle, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
        ],
      ),
    );
  }

  Widget _buildSummarySubRow(String label, String value, Color color, {bool isBold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontSize: 12, color: isBold ? navyColor : const Color(0xFF475569), fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
        Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }

  // ============================================================================
  // TAB 2: CREDIT / DEBIT LEDGER
  // ============================================================================
  Widget _buildLedgerTab() {
    return Column(
      children: [
        // Filter Bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          color: Colors.white,
          child: Row(
            children: [
              // Vendor Dropdown
              Expanded(
                flex: 3,
                child: DropdownButtonFormField<String>(
                  value: _selectedVendorId,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Select Sub-Vendor',
                    contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    const DropdownMenuItem(value: 'All', child: Text('All Sub-Vendors')),
                    ..._vendors.map((v) => DropdownMenuItem(value: v.id, child: Text('${v.name} (${v.vendorCode})'))),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      setState(() => _selectedVendorId = val);
                      _loadAllData();
                    }
                  },
                ),
              ),
              const SizedBox(width: 10),
              // Category Filter
              DropdownButton<String>(
                value: _filterCategory,
                items: const [
                  DropdownMenuItem(value: 'All', child: Text('All Categories')),
                  DropdownMenuItem(value: 'MATERIAL', child: Text('Material Only')),
                  DropdownMenuItem(value: 'ADVANCE', child: Text('Advance Only')),
                ],
                onChanged: (val) {
                  if (val != null) {
                    setState(() => _filterCategory = val);
                    _loadAllData();
                  }
                },
              ),
              const SizedBox(width: 10),
              // Search Ref / Notes
              Expanded(
                flex: 2,
                child: TextField(
                  controller: _searchCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Search Ref / Note',
                    prefixIcon: Icon(Icons.search, size: 16),
                    contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (_) => _loadAllData(),
                ),
              ),
              const SizedBox(width: 10),
              // Export CSV
              OutlinedButton.icon(
                icon: const Icon(Icons.download, size: 16, color: greenColor),
                label: const Text('Export CSV', style: TextStyle(color: greenColor)),
                style: OutlinedButton.styleFrom(side: const BorderSide(color: greenColor)),
                onPressed: _handleExportLedgerCsv,
              ),
              const SizedBox(width: 8),
              // Print Statement PDF
              ElevatedButton.icon(
                icon: const Icon(Icons.print, size: 16),
                label: const Text('Print Statement'),
                style: ElevatedButton.styleFrom(backgroundColor: navyColor, foregroundColor: Colors.white),
                onPressed: () {
                  if (_selectedVendorId == 'All') {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Please select a specific Sub-Vendor to print statement.'), backgroundColor: Colors.orange),
                    );
                    return;
                  }
                  _printVendorStatement(_selectedVendorId);
                },
              ),
            ],
          ),
        ),

        // Ledger List
        Expanded(
          child: _ledgerEntries.isEmpty
              ? const Center(child: Text('No ledger entries recorded yet.'))
              : ListView.builder(
                  padding: const EdgeInsets.all(20),
                  itemCount: _ledgerEntries.length,
                  itemBuilder: (context, i) {
                    final e = _ledgerEntries[i];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: BorderSide(color: e.isCancelled ? Colors.red.shade200 : const Color(0xFFE2E8F0)),
                      ),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: e.isCredit ? Colors.green.shade50 : Colors.amber.shade50,
                          child: Icon(
                            e.isCredit ? Icons.arrow_downward : Icons.arrow_upward,
                            color: e.isCredit ? greenColor : amberColor,
                          ),
                        ),
                        title: Row(
                          children: [
                            Text(e.particulars, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: e.isCredit ? greenColor.withOpacity(0.1) : amberColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                e.typeLabel,
                                style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: e.isCredit ? greenColor : amberColor),
                              ),
                            ),
                          ],
                        ),
                        subtitle: Text(
                          'Date: ${_dateFormat.format(e.transactionDate)} | Ref: ${e.referenceNumber} | Mode: ${e.paymentMode} | Vendor: ${e.vendorName}',
                          style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  e.creditAmount > 0 ? '+ ${_currency.format(e.creditAmount)} (Cr)' : '- ${_currency.format(e.debitAmount)} (Dr)',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: e.creditAmount > 0 ? greenColor : amberColor,
                                  ),
                                ),
                                Text(
                                  'Running Bal: ${_currency.format(e.runningBalance.abs())} ${e.runningBalance >= 0 ? "Cr" : "Dr"}',
                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: navyColor),
                                ),
                              ],
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, color: redColor, size: 20),
                              tooltip: 'Remove Entry',
                              onPressed: () => _confirmRemoveEntry(e),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  void _confirmRemoveEntry(SubVendorAccountLedgerEntry entry) {
    final amt = entry.creditAmount > 0 ? entry.creditAmount : entry.debitAmount;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.delete_outline, color: redColor),
            SizedBox(width: 8),
            Text('Remove Ledger Entry?'),
          ],
        ),
        content: Text(
          'Are you sure you want to remove "${entry.particulars}" (${_currency.format(amt)}) dated ${_dateFormat.format(entry.transactionDate)}?\n\nRunning balances will be recalculated automatically.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: redColor, foregroundColor: Colors.white),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await SubVendorAccountLedgerService.deleteTransaction(entry.id);
                await _loadAllData();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Entry removed & balances recalculated!'), backgroundColor: greenColor),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Remove failed: $e'), backgroundColor: redColor),
                  );
                }
              }
            },
            child: const Text('Yes, Remove'),
          ),
        ],
      ),
    );
  }

  // ============================================================================
  // DIALOG: RECORD MANUAL PAYMENT / ADVANCE / REFUND
  // ============================================================================
  void _showRecordTransactionDialog() {
    SubVendor? selectedVendor = _vendors.isNotEmpty ? _vendors.first : null;
    String selectedType = 'MATERIAL_PAYMENT';
    DateTime selectedDate = DateTime.now();
    final amountCtrl = TextEditingController();
    final refCtrl = TextEditingController();
    final particularsCtrl = TextEditingController(text: 'Payments Received');
    final remarksCtrl = TextEditingController();
    String selectedMode = 'Bank Transfer';

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              title: const Row(
                children: [
                  Icon(Icons.add_card_rounded, color: navyColor),
                  SizedBox(width: 8),
                  Text('Record Payment'),
                ],
              ),
              content: SizedBox(
                width: 550,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Sub Vendor
                      DropdownButtonFormField<SubVendor>(
                        value: selectedVendor,
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: 'Sub Vendor *', border: OutlineInputBorder()),
                        items: _vendors.map((v) => DropdownMenuItem(value: v, child: Text('${v.name} (${v.vendorCode})'))).toList(),
                        onChanged: (val) => setDialogState(() => selectedVendor = val),
                      ),
                      const SizedBox(height: 12),

                      // Transaction Type (Simple: Payments Received & Payout)
                      DropdownButtonFormField<String>(
                        value: selectedType,
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: 'Payment Type *', border: OutlineInputBorder()),
                        items: const [
                          DropdownMenuItem(
                            value: 'MATERIAL_PAYMENT',
                            child: Text('🟢 Payments Received (पैसे मिळाले)'),
                          ),
                          DropdownMenuItem(
                            value: 'ADVANCE_GIVEN',
                            child: Text('🟠 Payout (पैसे दिले)'),
                          ),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            setDialogState(() {
                              selectedType = val;
                              if (val == 'MATERIAL_PAYMENT') {
                                particularsCtrl.text = 'Payments Received';
                              } else {
                                particularsCtrl.text = 'Payout to Sub-Vendor';
                              }
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 12),

                      // Amount & Date
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: amountCtrl,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: const InputDecoration(
                                labelText: 'Amount (₹) *',
                                prefixText: '₹ ',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: InkWell(
                              onTap: () async {
                                final p = await showDatePicker(
                                  context: ctx,
                                  initialDate: selectedDate,
                                  firstDate: DateTime(2024),
                                  lastDate: DateTime(2030),
                                );
                                if (p != null) setDialogState(() => selectedDate = p);
                              },
                              child: InputDecorator(
                                decoration: const InputDecoration(labelText: 'Date', border: OutlineInputBorder()),
                                child: Text(_dateFormat.format(selectedDate)),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Payment Mode & Ref
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: selectedMode,
                              decoration: const InputDecoration(labelText: 'Mode', border: OutlineInputBorder()),
                              items: const [
                                DropdownMenuItem(value: 'Bank Transfer', child: Text('Bank Transfer')),
                                DropdownMenuItem(value: 'NEFT/RTGS', child: Text('NEFT/RTGS')),
                                DropdownMenuItem(value: 'UPI', child: Text('UPI')),
                                DropdownMenuItem(value: 'Cheque', child: Text('Cheque')),
                                DropdownMenuItem(value: 'Cash', child: Text('Cash')),
                              ],
                              onChanged: (val) {
                                if (val != null) setDialogState(() => selectedMode = val);
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: refCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Ref / UTR / Cheque No *',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      TextField(
                        controller: particularsCtrl,
                        decoration: const InputDecoration(labelText: 'Particulars / Description', border: OutlineInputBorder()),
                      ),
                      const SizedBox(height: 12),

                      TextField(
                        controller: remarksCtrl,
                        decoration: const InputDecoration(labelText: 'Remarks (Optional)', border: OutlineInputBorder()),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                ElevatedButton(
                  onPressed: () async {
                    if (selectedVendor == null) return;
                    final amt = double.tryParse(amountCtrl.text.trim()) ?? 0.0;
                    if (amt <= 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please enter a valid amount greater than zero.'), backgroundColor: redColor),
                      );
                      return;
                    }
                    if (refCtrl.text.trim().isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please enter a reference number.'), backgroundColor: redColor),
                      );
                      return;
                    }

                    Navigator.pop(ctx);
                    try {
                      await SubVendorAccountLedgerService.recordTransaction(
                        vendorId: selectedVendor!.id,
                        vendorName: selectedVendor!.name,
                        transactionDate: selectedDate,
                        transactionType: selectedType,
                        amount: amt,
                        referenceNumber: refCtrl.text.trim(),
                        paymentMode: selectedMode,
                        particulars: particularsCtrl.text.trim(),
                        remarks: remarksCtrl.text.trim().isNotEmpty ? remarksCtrl.text.trim() : null,
                      );

                      await _loadAllData();
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Transaction recorded & ledger updated!'), backgroundColor: greenColor),
                        );
                      }
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e'), backgroundColor: redColor));
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: navyColor, foregroundColor: Colors.white),
                  child: const Text('Record & Update Ledger'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // Print Statement Helper
  Future<void> _printVendorStatement(String vendorId) async {
    try {
      final vendor = _vendors.firstWhere((v) => v.id == vendorId);
      final entries = await SubVendorAccountLedgerService.fetchLedgerEntries(vendorId: vendorId, statusFilter: 'Active');

      double totalCredit = 0.0;
      double totalDebit = 0.0;
      for (final e in entries) {
        totalCredit += e.creditAmount;
        totalDebit += e.debitAmount;
      }

      final bytes = await SubVendorAccountLedgerPdfService.generateAccountStatementPdfBytes(
        vendor: vendor,
        entries: entries,
        totalCredit: totalCredit,
        totalDebit: totalDebit,
        closingBalance: totalCredit - totalDebit,
        fromDate: _filterFromDate,
        toDate: _filterToDate,
      );

      await Printing.layoutPdf(onLayout: (_) => bytes, name: 'Statement_${vendor.vendorCode}.pdf');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Print failed: $e'), backgroundColor: redColor));
      }
    }
  }

  // Export CSV Helper
  Future<void> _handleExportLedgerCsv() async {
    try {
      if (_selectedVendorId == 'All') {
        await SubVendorAccountLedgerPdfService.exportDashboardSummaryCsv(_metrics);
      } else {
        final vendor = _vendors.firstWhere((v) => v.id == _selectedVendorId);
        final entries = _ledgerEntries.where((e) => e.vendorId == _selectedVendorId).toList();
        double totalCredit = 0.0;
        double totalDebit = 0.0;
        for (final e in entries) {
          if (e.isActive) {
            totalCredit += e.creditAmount;
            totalDebit += e.debitAmount;
          }
        }
        await SubVendorAccountLedgerPdfService.exportVendorLedgerCsv(
          vendor: vendor,
          entries: entries,
          totalCredit: totalCredit,
          totalDebit: totalDebit,
          closingBalance: totalCredit - totalDebit,
        );
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ledger exported to CSV successfully!'), backgroundColor: greenColor),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Export failed: $e'), backgroundColor: redColor));
      }
    }
  }
}
