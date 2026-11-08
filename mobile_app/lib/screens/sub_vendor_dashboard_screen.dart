import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:siya_shared/siya_shared.dart';
import '../services/sub_vendor_service.dart';
import '../services/supabase_service.dart';
import 'login_screen.dart';

final _currency = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 2);
final _dateFormat = DateFormat('dd-MM-yyyy');

/// Responsive Android/Mobile Sub-Vendor Portal
/// Exclusively displays and isolates that specific Sub-Vendor's own assigned sites,
/// dynamic material transactions, GST categories (5% vs 18%), and settlements.
class SubVendorMobileDashboardScreen extends StatefulWidget {
  final SubVendor? preloadedVendor;

  const SubVendorMobileDashboardScreen({super.key, this.preloadedVendor});

  @override
  State<SubVendorMobileDashboardScreen> createState() => _SubVendorMobileDashboardScreenState();
}

class _SubVendorMobileDashboardScreenState extends State<SubVendorMobileDashboardScreen>
    with SingleTickerProviderStateMixin {
  SubVendor? _vendor;
  VendorFinancialSummary? _summary;
  List<VendorSiteAssignment> _assignments = [];
  List<VendorMaterialTransaction> _materials = [];
  List<VendorPayout> _payouts = [];

  bool _isLoading = true;
  String _searchQuery = '';
  String _statusFilter = 'All';

  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _vendor = widget.preloadedVendor;
    _loadDashboardData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadDashboardData() async {
    setState(() => _isLoading = true);
    try {
      final v = _vendor ?? await SubVendorService.fetchCurrentVendorProfile();
      if (v == null) {
        if (mounted) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No Sub-Vendor profile linked to this account.')),
          );
        }
        return;
      }

      _vendor = v;
      final assignments = await SubVendorService.fetchAssignments(vendorId: v.id);
      final materials = await SubVendorService.fetchVendorMaterials(v.id);
      final payouts = await SubVendorService.fetchVendorPayouts(v.id);

      final summary = VendorFinancialSummary.compute(
        vendorId: v.id,
        vendorCode: v.vendorCode,
        vendorName: v.name,
        assignments: assignments,
        allMaterials: materials,
        allPayouts: payouts,
      );

      if (mounted) {
        setState(() {
          _assignments = assignments;
          _materials = materials;
          _payouts = payouts;
          _summary = summary;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load dashboard: $e')),
        );
      }
    }
  }

  Future<void> _handleSignOut() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to log out of your Sub-Vendor account?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Log Out')),
        ],
      ),
    );

    if (confirm == true) {
      await SupabaseService.signOut();
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const MobileLoginScreen()),
          (route) => false,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFF0D2B6F), // SIYA Navy
        foregroundColor: Colors.white,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.solar_power_rounded, color: Color(0xFF10B981), size: 22),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _vendor?.name ?? 'Sub-Vendor Portal',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    '${_vendor?.vendorCode ?? "SIYA-VND"} • SIYA Solar Partner',
                    style: TextStyle(color: Colors.white.withOpacity(0.75), fontSize: 11),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh Data',
            onPressed: _loadDashboardData,
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            tooltip: 'Log Out',
            onPressed: _handleSignOut,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: false,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white.withOpacity(0.65),
          indicatorColor: const Color(0xFF10B981),
          indicatorWeight: 3,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          tabs: const [
            Tab(text: 'Sites', icon: Icon(Icons.location_on_outlined, size: 20)),
            Tab(text: 'Materials', icon: Icon(Icons.inventory_2_outlined, size: 20)),
            Tab(text: 'Payouts', icon: Icon(Icons.payments_outlined, size: 20)),
            Tab(text: 'Profile', icon: Icon(Icons.account_balance_outlined, size: 20)),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildSitesTab(cs),
                _buildMaterialsTab(cs),
                _buildPayoutsTab(cs),
                _buildProfileTab(cs),
              ],
            ),
    );
  }

  // ============================================================================
  // TAB 1: ASSIGNED SITES
  // ============================================================================

  Widget _buildSitesTab(ColorScheme cs) {
    final filtered = _assignments.where((a) {
      final q = _searchQuery.toLowerCase();
      final cName = (a.customerName ?? '').toLowerCase();
      final cNo = (a.consumerNo ?? '').toLowerCase();
      final cCity = (a.customerVillageCity ?? '').toLowerCase();
      final matchSearch = cName.contains(q) || cNo.contains(q) || cCity.contains(q);
      final matchStatus = _statusFilter == 'All' || a.status == _statusFilter;
      return matchSearch && matchStatus;
    }).toList();

    return RefreshIndicator(
      onRefresh: _loadDashboardData,
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          _buildMetricsOverview(),
          const SizedBox(height: 12),

          // Search & Filter
          Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Search customer, CA no, village...',
                    hintStyle: const TextStyle(fontSize: 12),
                    prefixIcon: const Icon(Icons.search, size: 18),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                    ),
                  ),
                  onChanged: (val) => setState(() => _searchQuery = val),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFCBD5E1)),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _statusFilter,
                    style: const TextStyle(fontSize: 12, color: Color(0xFF0F172A), fontWeight: FontWeight.bold),
                    items: ['All', 'Assigned', 'In Progress', 'Completed', 'Settled']
                        .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                        .toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _statusFilter = val);
                    },
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Sites List
          if (filtered.isEmpty)
            Container(
              padding: const EdgeInsets.all(32),
              alignment: Alignment.center,
              child: Column(
                children: [
                  Icon(Icons.assignment_outlined, size: 48, color: Colors.grey.shade400),
                  const SizedBox(height: 8),
                  const Text('No assigned sites found', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                ],
              ),
            )
          else
            ...filtered.map((a) {
              final detail = _summary?.siteDetails.firstWhere(
                (d) => d.assignment.id == a.id,
                orElse: () => SiteFinancialDetail(
                  assignment: a,
                  materials: [],
                  payouts: [],
                  material5Taxable: 0,
                  material5Gst: 0,
                  material5Total: 0,
                  material18Taxable: 0,
                  material18Gst: 0,
                  material18Total: 0,
                  totalMaterialTaxable: 0,
                  totalEligibleInputGst: 0,
                  totalMaterialCost: 0,
                  vendorCharges: a.vendorCharges,
                  otherExpenses: a.otherExpenses,
                  totalVendorPayable: a.vendorCharges + a.otherExpenses,
                  totalSiteAmount: a.customerTotalAmount,
                  amountReceivedBySiya: a.customerPaidAmount,
                  totalPaidToVendor: 0,
                  outstandingVendorPayable: a.vendorCharges + a.otherExpenses,
                ),
              );
              return _buildSiteCard(a, detail, cs);
            }),
        ],
      ),
    );
  }

  Widget _buildMetricsOverview() {
    final s = _summary;
    if (s == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Text(
                  'Financial Performance Summary',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${s.totalCapacityKw.toStringAsFixed(1)} kW Total',
                  style: const TextStyle(color: Color(0xFF047857), fontWeight: FontWeight.bold, fontSize: 11),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _metricPill('Sites Assigned', '${s.totalAssignedSites}', const Color(0xFF0D2B6F), Icons.home_work_outlined),
              const SizedBox(width: 8),
              _metricPill('Completed', '${s.completedSites}', const Color(0xFF047857), Icons.task_alt_outlined),
              const SizedBox(width: 8),
              _metricPill('Pending', '${s.pendingSites}', const Color(0xFFD97706), Icons.pending_actions_outlined),
            ],
          ),
          const Divider(height: 20, color: Color(0xFFE2E8F0)),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _metricFinancial('SIYA Charges', _currency.format(s.totalVendorCharges), const Color(0xFF0D2B6F), 'kW × ₹1,000'),
              const SizedBox(width: 4),
              _metricFinancial('Material Cost', _currency.format(s.totalMaterialCost), const Color(0xFFDC2626), 'Net Issued'),
              const SizedBox(width: 4),
              _metricFinancial('Outstanding', _currency.format(s.outstandingSettlement), const Color(0xFF047857), 'Receivable'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _metricPill(String label, String value, Color color, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(height: 2),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: color)),
            ),
            Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10, color: Color(0xFF64748B))),
          ],
        ),
      ),
    );
  }

  Widget _metricFinancial(String label, String value, Color color, String sub) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10, color: Color(0xFF64748B))),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: color)),
          ),
          Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 9, color: Color(0xFF94A3B8))),
        ],
      ),
    );
  }

  Widget _buildSiteCard(VendorSiteAssignment a, SiteFinancialDetail? detail, ColorScheme cs) {
    Color statusColor;
    switch (a.status) {
      case 'Completed':
      case 'Settled':
        statusColor = const Color(0xFF047857);
        break;
      case 'In Progress':
        statusColor = const Color(0xFFD97706);
        break;
      default:
        statusColor = const Color(0xFF0D2B6F);
    }

    final displayName = (a.customerName != null && a.customerName!.isNotEmpty) ? a.customerName! : 'Site Customer';
    final consumerNumber = (a.consumerNo != null && a.consumerNo!.isNotEmpty) ? a.consumerNo! : 'CA Pending';
    final location = (a.customerVillageCity != null && a.customerVillageCity!.isNotEmpty) ? a.customerVillageCity! : 'Site Location';

    return Card(
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => _showSiteDetailsSheet(a, detail),
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
                      displayName,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0F172A)),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      a.status,
                      style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 11),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'CA No: $consumerNumber • $location',
                style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
              ),
              const Divider(height: 16, color: Color(0xFFF1F5F9)),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _infoTile('Capacity', '${a.siteCapacityKw} kW'),
                  _infoTile('Vendor Charges', _currency.format(a.vendorCharges)),
                  _infoTile('Material Cost', _currency.format(detail?.totalMaterialCost ?? 0)),
                  _infoTile('Settlement', _currency.format(detail?.totalVendorPayable ?? a.vendorCharges)),
                ],
              ),
              const SizedBox(height: 8),
              // Customer Payment & Loan Overview Banner (Read-Only)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: a.isBankLoan ? const Color(0xFFF0FDF4) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: a.isBankLoan ? const Color(0xFFBBF7D0) : const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(
                              a.isBankLoan ? Icons.account_balance : Icons.payments_outlined,
                              size: 13,
                              color: a.isBankLoan ? const Color(0xFF047857) : const Color(0xFF0D2B6F),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              a.paymentType,
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.bold,
                                color: a.isBankLoan ? const Color(0xFF047857) : const Color(0xFF0D2B6F),
                              ),
                            ),
                          ],
                        ),
                        Text(
                          'Cust. Received: ${_currency.format(a.effectiveReceivedAmount)} / ${_currency.format(a.effectiveSiteAmount)}',
                          style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    if (a.isBankLoan) ...[
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Loan Status: ${a.loanStatus}',
                            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF047857)),
                          ),
                          Text(
                            'Pending: ${_currency.format(a.loanPendingCredit)}',
                            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFFB45309)),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              if (a.financialApproved) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFECFDF5),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.verified_rounded, size: 14, color: Color(0xFF047857)),
                      SizedBox(width: 4),
                      Text('Financial Settlement Approved by SIYA Admin', style: TextStyle(color: Color(0xFF047857), fontSize: 10, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoTile(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 9, color: Color(0xFF64748B))),
        Text(value, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
      ],
    );
  }

  void _showSiteDetailsSheet(VendorSiteAssignment a, SiteFinancialDetail? detail) {
    final displayName = (a.customerName != null && a.customerName!.isNotEmpty) ? a.customerName! : 'Site Customer';
    final consumerNumber = (a.consumerNo != null && a.consumerNo!.isNotEmpty) ? a.consumerNo! : 'CA Pending';
    final location = (a.customerVillageCity != null && a.customerVillageCity!.isNotEmpty) ? a.customerVillageCity! : 'Site Location';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final siteMats = _materials.where((m) => m.assignmentId == a.id).toList();

        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.85,
          maxChildSize: 0.95,
          minChildSize: 0.5,
          builder: (_, scrollController) {
            return ListView(
              controller: scrollController,
              padding: const EdgeInsets.all(16),
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFCBD5E1),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(displayName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                          Text('CA: $consumerNumber • $location', style: const TextStyle(color: Color(0xFF64748B), fontSize: 12)),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0D2B6F).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text('${a.siteCapacityKw} kW', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0D2B6F))),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Calculation Breakdown Card
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    children: [
                      _breakdownRow('Installed Capacity', '${a.siteCapacityKw} kW'),
                      _breakdownRow('Agreed Rate / kW', '₹${a.ratePerKw.toStringAsFixed(0)} / kW'),
                      _breakdownRow('SIYA Vendor Charges', _currency.format(a.vendorCharges), isBold: true),
                      const Divider(height: 12),
                      _breakdownRow('Dynamic Material Cost', _currency.format(detail?.totalMaterialCost ?? 0), color: const Color(0xFFDC2626)),
                      _breakdownRow('  • 5% Category (Panels & Inverters)', _currency.format(detail?.material5Total ?? 0)),
                      _breakdownRow('  • 18% Category (Solar BOS & Electricals)', _currency.format(detail?.material18Total ?? 0)),
                      if (a.otherExpenses > 0)
                        _breakdownRow('Other Approved Expenses', _currency.format(a.otherExpenses), color: const Color(0xFF047857)),
                      const Divider(height: 14),
                      _breakdownRow('Net Settlement Amount', _currency.format(detail?.totalVendorPayable ?? a.vendorCharges), isBold: true, color: const Color(0xFF0D2B6F)),
                      _breakdownRow('Amount Paid to Vendor', _currency.format(detail?.totalPaidToVendor ?? 0), color: const Color(0xFF047857)),
                      _breakdownRow('Remaining Settlement Balance', _currency.format(detail?.outstandingVendorPayable ?? a.vendorCharges), isBold: true, color: const Color(0xFFD97706)),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // Customer Payment & Loan Tracking Card (Read-Only)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: a.isBankLoan ? const Color(0xFFF0FDF4) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: a.isBankLoan ? const Color(0xFFBBF7D0) : const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('CUSTOMER PAYMENT & LOAN STATUS',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: a.isBankLoan ? const Color(0xFF047857) : const Color(0xFF0D2B6F))),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(4)),
                            child: const Text('Admin Managed (View Only)', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.black54)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      _breakdownRow('Payment Category', a.paymentType),
                      _breakdownRow('Total Site Contract Amount', _currency.format(a.effectiveSiteAmount)),
                      _breakdownRow('Cash Payment Received', _currency.format(a.totalCashReceived)),
                      if (a.isBankLoan) ...[
                        _breakdownRow('Financing Bank', a.loanBankName ?? 'Not specified'),
                        if (a.loanApplicationId != null && a.loanApplicationId!.isNotEmpty)
                          _breakdownRow('Loan Application ID', a.loanApplicationId!),
                        _breakdownRow('Loan Sanctioned Amount', _currency.format(a.loanSanctionedAmount)),
                        _breakdownRow('Bank Loan Credited to SIYA', _currency.format(a.totalLoanCredited), color: const Color(0xFF047857)),
                        _breakdownRow('Pending Loan Credit', _currency.format(a.loanPendingCredit), color: const Color(0xFFD97706)),
                        _breakdownRow('Loan Credit Status', a.loanStatus, isBold: true, color: const Color(0xFF047857)),
                      ],
                      const Divider(height: 10),
                      _breakdownRow('Total Customer Collection', _currency.format(a.effectiveReceivedAmount), isBold: true, color: const Color(0xFF047857)),
                      _breakdownRow('Outstanding Due from Customer', _currency.format(a.effectiveCustomerOutstanding), isBold: true, color: const Color(0xFFDC2626)),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Material Items Issued/Returned Table
                const Text('Material Tracking (Issued & Returned)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 8),
                if (siteMats.isEmpty)
                  const Text('No material transactions recorded yet for this site.', style: TextStyle(color: Colors.grey, fontSize: 12))
                else
                  ...siteMats.map((m) {
                    final isReturn = m.isReturn;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isReturn ? const Color(0xFFFEF2F2) : Colors.white,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: isReturn ? const Color(0xFFFCA5A5) : const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                      decoration: BoxDecoration(
                                        color: isReturn ? Colors.red : Colors.blue.shade700,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        isReturn ? 'RETURN' : 'ISSUE',
                                        style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(m.itemName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                  ],
                                ),
                                Text(
                                  'Qty: ${m.quantity} ${m.unit} @ ₹${m.unitRate.toStringAsFixed(0)} | GST: ${m.gstRate}%',
                                  style: const TextStyle(fontSize: 10, color: Color(0xFF64748B)),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            '${isReturn ? "- " : "+ "}${_currency.format(m.totalAmount)}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              color: isReturn ? Colors.red : const Color(0xFF0F172A),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),

                const SizedBox(height: 16),
                // Action to advance status if not locked
                if (!a.financialApproved && a.status != 'Completed' && a.status != 'Settled') ...[
                  FilledButton.icon(
                    style: FilledButton.styleFrom(backgroundColor: const Color(0xFF047857)),
                    icon: const Icon(Icons.check_circle_outline),
                    label: const Text('Mark Site Work as Completed'),
                    onPressed: () async {
                      Navigator.pop(ctx);
                      await _updateSiteStatus(a.id, 'Completed');
                    },
                  ),
                ],
              ],
            );
          },
        );
      },
    );
  }

  Widget _breakdownRow(String label, String value, {bool isBold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              color: const Color(0xFF475569),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 11,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
              color: color ?? const Color(0xFF0F172A),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _updateSiteStatus(String assignmentId, String status) async {
    try {
      await SubVendorService.updateAssignmentStatus(assignmentId: assignmentId, status: status);
      await _loadDashboardData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Site status successfully updated to $status!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Status update error: $e')),
        );
      }
    }
  }

  // ============================================================================
  // TAB 2: DYNAMIC MATERIAL TRANSACTIONS
  // ============================================================================

  Widget _buildMaterialsTab(ColorScheme cs) {
    if (_materials.isEmpty) {
      return RefreshIndicator(
        onRefresh: _loadDashboardData,
        child: ListView(
          padding: const EdgeInsets.all(32),
          children: const [
            Center(child: Text('No material transactions recorded yet.', style: TextStyle(color: Colors.grey))),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadDashboardData,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _materials.length,
        itemBuilder: (ctx, i) {
          final m = _materials[i];
          final isReturn = m.isReturn;
          final isBos = m.itemCategory == 'BOS';

          return Card(
            elevation: 1,
            margin: const EdgeInsets.only(bottom: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: BorderSide(color: isReturn ? Colors.red.shade200 : const Color(0xFFE2E8F0)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: isReturn ? Colors.red : Colors.blue.shade800,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              isReturn ? 'RETURN' : 'ISSUE',
                              style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(m.itemName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: isBos ? const Color(0xFFFEF3C7) : const Color(0xFFE0F2FE),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '${m.gstRate.toStringAsFixed(0)}% GST (${isBos ? "Solar BOS" : "Panels/Inverters"})',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: isBos ? const Color(0xFF92400E) : const Color(0xFF0369A1),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Transaction Date: ${_dateFormat.format(m.transactionDate)}',
                    style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                  ),
                  if (m.challanNumber != null && m.challanNumber!.isNotEmpty)
                    Text('Challan No: ${m.challanNumber}', style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
                  const Divider(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Qty: ${m.quantity} ${m.unit} @ ₹${m.unitRate.toStringAsFixed(0)}', style: const TextStyle(fontSize: 11)),
                      Text('Taxable: ₹${m.taxableAmount.toStringAsFixed(2)}', style: const TextStyle(fontSize: 10, color: Color(0xFF64748B))),
                      Text('GST: ₹${m.gstAmount.toStringAsFixed(2)}', style: const TextStyle(fontSize: 10, color: Color(0xFF64748B))),
                      Text(
                        '${isReturn ? "- " : "+ "}${_currency.format(m.totalAmount)}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: isReturn ? Colors.red : const Color(0xFF047857),
                        ),
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

  // ============================================================================
  // TAB 3: PAYOUTS & DISBURSEMENTS
  // ============================================================================

  Widget _buildPayoutsTab(ColorScheme cs) {
    final s = _summary;

    return RefreshIndicator(
      onRefresh: _loadDashboardData,
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          // Settlement Math Banner
          if (s != null)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF0D2B6F),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('SETTLEMENT CALCULATION SUMMARY', style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  _whiteRow('+ Total SIYA Vendor Charges', _currency.format(s.totalVendorCharges)),
                  _whiteRow('- Dynamic Material Cost Deductions', _currency.format(s.totalMaterialCost), isRed: true),
                  if (s.totalOtherExpenses > 0)
                    _whiteRow('+ Approved Other Expenses', _currency.format(s.totalOtherExpenses)),
                  const Divider(color: Colors.white24, height: 16),
                  _whiteRow('= Net Settlement Payable', _currency.format(s.totalSettlementAmount), isBold: true),
                  _whiteRow('- Total Paid / Disbursed', _currency.format(s.totalPaidAmount), isBold: true, isGreen: true),
                  const Divider(color: Colors.white24, height: 16),
                  _whiteRow('OUTSTANDING BALANCE', _currency.format(s.outstandingSettlement), isBold: true, fontSize: 14),
                ],
              ),
            ),
          const SizedBox(height: 14),

          const Text('Payout Disbursements History', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 8),

          if (_payouts.isEmpty)
            Container(
              padding: const EdgeInsets.all(24),
              alignment: Alignment.center,
              child: const Text('No payout transactions recorded yet.', style: TextStyle(color: Colors.grey)),
            )
          else
            ..._payouts.map((p) {
              return Card(
                elevation: 1,
                margin: const EdgeInsets.only(bottom: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.check_circle, size: 16, color: Color(0xFF047857)),
                              const SizedBox(width: 6),
                              Text(p.paymentMode, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text('Date: ${_dateFormat.format(p.payoutDate)}', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                          if (p.referenceNumber != null && p.referenceNumber!.isNotEmpty)
                            Text('UTR / Ref: ${p.referenceNumber}', style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(_currency.format(p.amount), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF047857))),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFECFDF5),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(p.status, style: const TextStyle(color: Color(0xFF047857), fontSize: 9, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _whiteRow(String label, String value, {bool isBold = false, bool isRed = false, bool isGreen = false, double fontSize = 11}) {
    Color valColor = Colors.white;
    if (isRed) valColor = const Color(0xFFFCA5A5);
    if (isGreen) valColor = const Color(0xFF6EE7B7);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.white70, fontSize: fontSize, fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
          Text(value, style: TextStyle(color: valColor, fontSize: fontSize, fontWeight: isBold ? FontWeight.bold : FontWeight.w600)),
        ],
      ),
    );
  }

  // ============================================================================
  // TAB 4: VENDOR PROFILE & BANK ACCOUNT
  // ============================================================================

  Widget _buildProfileTab(ColorScheme cs) {
    final v = _vendor;
    if (v == null) return const SizedBox.shrink();

    return RefreshIndicator(
      onRefresh: _loadDashboardData,
      child: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(v.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: v.isActive ? const Color(0xFFECFDF5) : Colors.red.shade50,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        v.status,
                        style: TextStyle(color: v.isActive ? const Color(0xFF047857) : Colors.red, fontWeight: FontWeight.bold, fontSize: 11),
                      ),
                    ),
                  ],
                ),
                Text('Vendor ID: ${v.vendorCode}', style: const TextStyle(color: Color(0xFF64748B), fontSize: 12)),
                const Divider(height: 20),
                _profileDetail('Contact Person', v.contactPerson ?? '—'),
                _profileDetail('Mobile / Login', v.mobile),
                _profileDetail('Email', v.email),
                _profileDetail('Address', v.address ?? 'Betawad / Shindkheda / Dhule'),
                _profileDetail('Default Rate per kW', '₹${v.defaultRatePerKw.toStringAsFixed(0)} / kW'),
                if (v.panNumber != null && v.panNumber!.isNotEmpty) _profileDetail('PAN Number', v.panNumber!),
                if (v.gstNumber != null && v.gstNumber!.isNotEmpty) _profileDetail('GST Number', v.gstNumber!),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Bank Details
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.account_balance, color: Color(0xFF0D2B6F), size: 18),
                    SizedBox(width: 8),
                    Text('Bank Account for Direct Payouts', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  ],
                ),
                const Divider(height: 16),
                _profileDetail('Bank Name', v.bankName ?? 'Not Configured'),
                _profileDetail('Account Number', v.accountNumber ?? 'Not Configured'),
                _profileDetail('IFSC Code', v.ifscCode ?? 'Not Configured'),
                if (v.upiId != null && v.upiId!.isNotEmpty) _profileDetail('UPI ID', v.upiId!),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _profileDetail(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
          Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
        ],
      ),
    );
  }
}
