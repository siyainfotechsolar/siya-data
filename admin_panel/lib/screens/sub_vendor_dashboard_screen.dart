import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:siya_shared/siya_shared.dart';
import '../services/sub_vendor_service.dart';
import '../services/sub_vendor_pdf_service.dart';
import '../services/supabase_service.dart';
import '../widgets/sub_vendor_dialogs.dart';
import 'login_screen.dart';

final _currency = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 2);
final _dateFormat = DateFormat('dd-MM-yyyy');

/// Sub-Vendor Dashboard — dedicated responsive portal for Solar Installation Sub-Vendors.
/// Shows strictly their own assigned sites, dynamic material costs, vendor charges, and settlements.
class SubVendorDashboardScreen extends StatefulWidget {
  final SubVendor? preloadedVendor;

  const SubVendorDashboardScreen({super.key, this.preloadedVendor});

  @override
  State<SubVendorDashboardScreen> createState() => _SubVendorDashboardScreenState();
}

class _SubVendorDashboardScreenState extends State<SubVendorDashboardScreen>
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
      // 1. Resolve current vendor profile
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

      // 2. Load assignments, materials, payouts
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
          SnackBar(content: Text('Error loading vendor dashboard: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _handleLogout() async {
    await SupabaseService.signOut();
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const AdminLoginScreen()),
        (route) => false,
      );
    }
  }

  List<VendorSiteAssignment> get _filteredAssignments {
    return _assignments.where((a) {
      final matchesQuery = _searchQuery.isEmpty ||
          (a.customerName?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false) ||
          (a.consumerNo?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false) ||
          (a.customerAddress?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false);

      final matchesStatus = _statusFilter == 'All' || a.status.toLowerCase() == _statusFilter.toLowerCase();
      return matchesQuery && matchesStatus;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D2B6F),
        foregroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.solar_power, size: 20, color: Color(0xFFF59E0B)),
                const SizedBox(width: 8),
                Text(_vendor?.name ?? 'Sub-Vendor Dashboard', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                if (_vendor?.vendorCode.isNotEmpty == true) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(_vendor!.vendorCode, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
                ],
              ],
            ),
            const Text(
              'SIYA INFOTECH & SOLAR ENERGY — PARTNER PORTAL',
              style: TextStyle(fontSize: 9.5, color: Color(0xFFBAE6FD), letterSpacing: 0.5),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Data',
            onPressed: _loadDashboardData,
          ),
          if (_summary != null)
            IconButton(
              icon: const Icon(Icons.picture_as_pdf),
              tooltip: 'Download Master Statement',
              onPressed: () => SubVendorPdfService.printOrShareVendorOverallStatement(_summary!, vendor: _vendor),
            ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sign Out',
            onPressed: _handleLogout,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFFF59E0B),
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(icon: Icon(Icons.assignment, size: 18), text: 'Assigned Sites'),
            Tab(icon: Icon(Icons.inventory_2, size: 18), text: 'Material Issued'),
            Tab(icon: Icon(Icons.payments, size: 18), text: 'Payouts & Balance'),
            Tab(icon: Icon(Icons.account_balance, size: 18), text: 'Profile & Bank'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadDashboardData,
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildSitesTab(),
                  _buildMaterialsTab(),
                  _buildPayoutsTab(),
                  _buildProfileTab(),
                ],
              ),
            ),
    );
  }

  // ============================================================================
  // TAB 1: ASSIGNED SITES
  // ============================================================================

  Widget _buildSitesTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // KPI Metric Cards Row
          if (_summary != null) _buildKpiGrid(),

          const SizedBox(height: 16),

          // Search and Filters Bar
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: BorderSide(color: Colors.grey.shade300),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      decoration: const InputDecoration(
                        hintText: 'Search by Customer Name, CA No, Village...',
                        prefixIcon: Icon(Icons.search),
                        border: InputBorder.none,
                        isDense: true,
                      ),
                      onChanged: (val) => setState(() => _searchQuery = val),
                    ),
                  ),
                  const SizedBox(width: 8),
                  DropdownButton<String>(
                    value: _statusFilter,
                    underline: const SizedBox(),
                    items: const [
                      DropdownMenuItem(value: 'All', child: Text('All Statuses')),
                      DropdownMenuItem(value: 'Assigned', child: Text('Assigned')),
                      DropdownMenuItem(value: 'In Progress', child: Text('In Progress')),
                      DropdownMenuItem(value: 'Completed', child: Text('Completed')),
                      DropdownMenuItem(value: 'Settled', child: Text('Settled')),
                    ],
                    onChanged: (val) => setState(() => _statusFilter = val ?? 'All'),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Sites List
          if (_filteredAssignments.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(40.0),
                child: Column(
                  children: [
                    Icon(Icons.solar_power_outlined, size: 48, color: Colors.grey.shade400),
                    const SizedBox(height: 12),
                    Text(
                      _assignments.isEmpty
                          ? 'No sites assigned to your account yet.'
                          : 'No sites match your filter criteria.',
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                    ),
                  ],
                ),
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _filteredAssignments.length,
              itemBuilder: (context, index) {
                final assignment = _filteredAssignments[index];
                return _buildSiteCard(assignment);
              },
            ),
        ],
      ),
    );
  }

  Widget _buildKpiGrid() {
    final s = _summary!;
    return LayoutBuilder(builder: (context, constraints) {
      final isWide = constraints.maxWidth > 800;
      return Column(
        children: [
          Row(
            children: [
              _kpiCard('Assigned Sites', '${s.totalAssignedSites}', '${s.completedSites} Completed', Icons.home_work, const Color(0xFF0D2B6F)),
              const SizedBox(width: 8),
              _kpiCard('Total Capacity', '${s.totalCapacityKw} kW', 'Installed', Icons.bolt, const Color(0xFFF59E0B)),
              if (isWide) ...[
                const SizedBox(width: 8),
                _kpiCard('Net Material Cost', _currency.format(s.totalMaterialCost), 'Issues (-) Returns', Icons.inventory, Colors.blueGrey),
                const SizedBox(width: 8),
                _kpiCard('Vendor Charges', _currency.format(s.totalVendorCharges), '₹1,000/kW basis', Icons.handshake, const Color(0xFF047857)),
              ],
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              if (!isWide) ...[
                _kpiCard('Net Material Cost', _currency.format(s.totalMaterialCost), 'Issues (-) Returns', Icons.inventory, Colors.blueGrey),
                const SizedBox(width: 8),
                _kpiCard('Vendor Charges', _currency.format(s.totalVendorCharges), '₹1,000/kW basis', Icons.handshake, const Color(0xFF047857)),
              ] else ...[
                _kpiCard('Disbursed Payouts', _currency.format(s.totalPaidAmount), 'Paid to Vendor', Icons.check_circle, const Color(0xFF047857)),
                const SizedBox(width: 8),
                _kpiCard('Outstanding Balance', _currency.format(s.outstandingSettlement), 'Remaining Due', Icons.account_balance_wallet, const Color(0xFF0D2B6F), isHighlight: true),
              ],
            ],
          ),
          if (!isWide) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                _kpiCard('Disbursed Payouts', _currency.format(s.totalPaidAmount), 'Paid to Vendor', Icons.check_circle, const Color(0xFF047857)),
                const SizedBox(width: 8),
                _kpiCard('Outstanding Balance', _currency.format(s.outstandingSettlement), 'Remaining Due', Icons.account_balance_wallet, const Color(0xFF0D2B6F), isHighlight: true),
              ],
            ),
          ],
        ],
      );
    });
  }

  Widget _kpiCard(String title, String value, String subtitle, IconData icon, Color color, {bool isHighlight = false}) {
    return Expanded(
      child: Card(
        elevation: 0,
        color: isHighlight ? const Color(0xFFE0F2FE) : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: isHighlight ? const Color(0xFF0D2B6F) : Colors.grey.shade300),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: color.withOpacity(0.12),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                    const SizedBox(height: 2),
                    Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: color)),
                    Text(subtitle, style: TextStyle(fontSize: 9.5, color: Colors.grey.shade500)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSiteCard(VendorSiteAssignment assignment) {
    Color statusColor = Colors.orange;
    if (assignment.status.toLowerCase() == 'completed') statusColor = Colors.blue;
    if (assignment.status.toLowerCase() == 'settled') statusColor = Colors.green;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      const CircleAvatar(
                        radius: 14,
                        backgroundColor: Color(0xFFE0F2FE),
                        child: Icon(Icons.solar_power, size: 16, color: Color(0xFF0D2B6F)),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          assignment.customerName ?? 'Site Customer',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: statusColor.withOpacity(0.4)),
                  ),
                  child: Text(
                    assignment.status,
                    style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 11),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 16,
              runSpacing: 4,
              children: [
                _chipInfo(Icons.tag, 'CA / Consumer No: ${assignment.consumerNo ?? "-"}'),
                _chipInfo(Icons.bolt, 'Capacity: ${assignment.siteCapacityKw} kW'),
                _chipInfo(Icons.calendar_today, 'Assigned: ${_dateFormat.format(assignment.assignedDate)}'),
                if (assignment.customerAddress != null)
                  _chipInfo(Icons.location_on, assignment.customerAddress!),
              ],
            ),
            const Divider(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Vendor Installation Charges:', style: TextStyle(fontSize: 11, color: Colors.grey)),
                    Text(
                      _currency.format(assignment.vendorCharges),
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0D2B6F)),
                    ),
                  ],
                ),
                Row(
                  children: [
                    OutlinedButton.icon(
                      icon: const Icon(Icons.visibility, size: 15),
                      label: const Text('Materials & Details'),
                      style: OutlinedButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        foregroundColor: const Color(0xFF0D2B6F),
                      ),
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (_) => VendorSiteDetailDialog(assignment: assignment),
                        );
                      },
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.picture_as_pdf, size: 15),
                      label: const Text('PDF Statement'),
                      style: ElevatedButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        backgroundColor: const Color(0xFF0D2B6F),
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () async {
                        final d = await SubVendorService.getSiteFinancialDetail(assignment);
                        SubVendorPdfService.printOrShareSiteStatement(d, vendor: _vendor);
                      },
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _chipInfo(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: Colors.grey.shade600),
        const SizedBox(width: 4),
        Text(text, style: TextStyle(fontSize: 11.5, color: Colors.grey.shade700)),
      ],
    );
  }

  // ============================================================================
  // TAB 2: MATERIAL ISSUES & RETURNS
  // ============================================================================

  Widget _buildMaterialsTab() {
    if (_materials.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(40.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.inventory_2_outlined, size: 48, color: Colors.grey.shade400),
              const SizedBox(height: 12),
              const Text('No materials issued to your sites yet.', style: TextStyle(fontSize: 14, color: Colors.grey)),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16.0),
      itemCount: _materials.length,
      itemBuilder: (context, index) {
        final m = _materials[index];
        final isRet = m.isReturn;
        return Card(
          elevation: 0,
          margin: const EdgeInsets.only(bottom: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(color: Colors.grey.shade300),
          ),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: isRet ? Colors.red.shade100 : Colors.green.shade100,
              child: Icon(isRet ? Icons.arrow_downward : Icons.arrow_upward, color: isRet ? Colors.red : Colors.green, size: 18),
            ),
            title: Text(m.itemName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            subtitle: Text(
              '${m.quantity} ${m.unit} @ ${_currency.format(m.unitRate)} | GST: ${m.gstRate.toStringAsFixed(0)}% (Taxable: ${_currency.format(m.taxableAmount)}) | ${_dateFormat.format(m.transactionDate)}',
              style: const TextStyle(fontSize: 11),
            ),
            trailing: Text(
              '${isRet ? "-" : ""}${_currency.format(m.totalAmount)}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isRet ? Colors.red.shade700 : const Color(0xFF0D2B6F),
                fontSize: 13,
              ),
            ),
          ),
        );
      },
    );
  }

  // ============================================================================
  // TAB 3: PAYOUTS & DISBURSEMENTS HISTORY
  // ============================================================================

  Widget _buildPayoutsTab() {
    if (_payouts.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(40.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.payments_outlined, size: 48, color: Colors.grey.shade400),
              const SizedBox(height: 12),
              const Text('No payment disbursements recorded yet.', style: TextStyle(fontSize: 14, color: Colors.grey)),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16.0),
      itemCount: _payouts.length,
      itemBuilder: (context, index) {
        final p = _payouts[index];
        return Card(
          elevation: 0,
          margin: const EdgeInsets.only(bottom: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(color: Colors.grey.shade300),
          ),
          child: ListTile(
            leading: const CircleAvatar(
              backgroundColor: Color(0xFFDCFCE7),
              child: Icon(Icons.check, color: Color(0xFF16A34A), size: 18),
            ),
            title: Text(_currency.format(p.amount), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF047857))),
            subtitle: Text(
              '${p.paymentMode} | Date: ${_dateFormat.format(p.payoutDate)} ${p.referenceNumber != null ? "| UTR: " + p.referenceNumber! : ""}',
              style: const TextStyle(fontSize: 11.5),
            ),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Text(p.status, style: TextStyle(color: Colors.green.shade800, fontWeight: FontWeight.bold, fontSize: 11)),
            ),
          ),
        );
      },
    );
  }

  // ============================================================================
  // TAB 4: PROFILE & BANK DETAILS
  // ============================================================================

  Widget _buildProfileTab() {
    final v = _vendor;
    if (v == null) return const SizedBox();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: BorderSide(color: Colors.grey.shade300),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const CircleAvatar(
                        radius: 24,
                        backgroundColor: Color(0xFF0D2B6F),
                        foregroundColor: Colors.white,
                        child: Icon(Icons.business, size: 26),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(v.name, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                            Text('Vendor Code: ${v.vendorCode} | Status: ${v.status}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  const Text('Contact Information', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.blueGrey)),
                  const SizedBox(height: 8),
                  _profileField('Contact Person:', v.contactPerson ?? '-'),
                  _profileField('Mobile (Username):', v.mobile),
                  _profileField('Email Address:', v.email),
                  _profileField('Address:', v.address ?? '-'),
                  const Divider(height: 24),
                  const Text('Banking & Tax Information', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.blueGrey)),
                  const SizedBox(height: 8),
                  _profileField('Bank Name:', v.bankName ?? '-'),
                  _profileField('Account Number:', v.accountNumber ?? '-'),
                  _profileField('IFSC Code:', v.ifscCode ?? '-'),
                  _profileField('UPI ID:', v.upiId ?? '-'),
                  _profileField('PAN Number:', v.panNumber ?? '-'),
                  _profileField('GST Number:', v.gstNumber ?? '-'),
                  _profileField('Contract Rate:', '${_currency.format(v.defaultRatePerKw)}/kW'),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _profileField(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 140, child: Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey))),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
        ],
      ),
    );
  }
}

