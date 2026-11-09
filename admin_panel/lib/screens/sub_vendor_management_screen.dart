import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:csv/csv.dart';
import 'package:siya_shared/siya_shared.dart';
import '../services/sub_vendor_service.dart';
import '../services/sub_vendor_pdf_service.dart';
import '../widgets/sub_vendor_dialogs.dart';
import 'sub_vendor_complete_financial_dashboard_screen.dart';

final _currency = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 2);
final _dateFormat = DateFormat('dd-MM-yyyy');

/// Sub-Vendor Management Screen — Master Admin control panel for all Sub-Vendor accounts,
/// site assignments, dynamic material issue/return, payouts, and final settlement approvals.
class SubVendorManagementScreen extends StatefulWidget {
  const SubVendorManagementScreen({super.key});

  @override
  State<SubVendorManagementScreen> createState() => _SubVendorManagementScreenState();
}

class _SubVendorManagementScreenState extends State<SubVendorManagementScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  List<SubVendor> _vendors = [];
  List<VendorSiteAssignment> _assignments = [];
  List<VendorMaterialTransaction> _allMaterials = [];
  List<VendorPayout> _allPayouts = [];
  List<VendorCustomerPayment> _allCustomerPayments = [];

  bool _isLoading = true;
  String? _errorMessage;
  String? _selectedVendorFilter;
  String _assignmentStatusFilter = 'All';
  String _vendorSearchQuery = '';
  String _customerPaymentCategoryFilter = 'All';
  String _customerPaymentSearchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _loadAllData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAllData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final vendors = await SubVendorService.fetchAllVendors();
      final assignments = await SubVendorService.fetchAssignments();
      final payouts = vendors.isNotEmpty ? await SubVendorService.fetchVendorPayouts(vendors.first.id) : <VendorPayout>[];

      List<VendorMaterialTransaction> materials = [];
      if (vendors.isNotEmpty) {
        materials = await SubVendorService.fetchVendorMaterials(vendors.first.id);
      }

      List<VendorCustomerPayment> customerPayments = [];
      try {
        customerPayments = await SubVendorService.fetchCustomerPayments();
      } catch (e) {
        debugPrint('Customer payments fetch: $e');
      }

      if (mounted) {
        setState(() {
          _vendors = vendors;
          _assignments = assignments;
          _allMaterials = materials;
          _allPayouts = payouts;
          _allCustomerPayments = customerPayments;
          _errorMessage = null;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        final errText = e.toString();
        setState(() {
          _errorMessage = errText;
          _isLoading = false;
        });
        final isTableMissing = errText.contains('sub_vendors') || errText.contains('PGRST205');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isTableMissing
                  ? 'Supabase Database setup required: Tables not found in schema cache. Please execute 20261108000036_sub_vendor_management_module.sql in Supabase SQL Editor.'
                  : 'Failed to load sub-vendor data: $e',
            ),
            backgroundColor: Colors.red.shade700,
            duration: const Duration(seconds: 10),
            action: isTableMissing
                ? SnackBarAction(
                    label: 'Setup Guide',
                    textColor: Colors.yellowAccent,
                    onPressed: _showMigrationSqlHelpDialog,
                  )
                : null,
          ),
        );
      }
    }
  }

  List<SubVendor> get _filteredVendors {
    return _vendors.where((v) {
      final q = _vendorSearchQuery.toLowerCase();
      return q.isEmpty ||
          v.name.toLowerCase().contains(q) ||
          v.vendorCode.toLowerCase().contains(q) ||
          v.mobile.contains(q);
    }).toList();
  }

  List<VendorSiteAssignment> get _filteredAssignments {
    return _assignments.where((a) {
      final matchesVendor = _selectedVendorFilter == null || a.vendorId == _selectedVendorFilter;
      final matchesStatus = _assignmentStatusFilter == 'All' || a.status.toLowerCase() == _assignmentStatusFilter.toLowerCase();
      return matchesVendor && matchesStatus;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D2B6F),
        foregroundColor: Colors.white,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Sub-Vendor & Financial Management', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            Text(
              'SIYA INFOTECH & SOLAR ENERGY — SUB-VENDOR OPERATIONS',
              style: TextStyle(fontSize: 9.5, color: Color(0xFFBAE6FD), letterSpacing: 0.5),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh All',
            onPressed: _loadAllData,
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            icon: const Icon(Icons.person_add, size: 16),
            label: const Text('Add Sub-Vendor'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF59E0B),
              foregroundColor: Colors.black87,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            ),
            onPressed: () async {
              final created = await showDialog<bool>(
                context: context,
                builder: (_) => const AddEditSubVendorDialog(),
              );
              if (created == true) _loadAllData();
            },
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            icon: const Icon(Icons.add_task, size: 16),
            label: const Text('Assign Site'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF047857),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            ),
            onPressed: () async {
              final assigned = await showDialog<bool>(
                context: context,
                builder: (_) => AssignSiteDialog(vendors: _vendors),
              );
              if (assigned == true) _loadAllData();
            },
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            icon: const Icon(Icons.calculate, size: 16),
            label: const Text('Settlement Calculator'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2563EB),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            ),
            onPressed: _openQuickSettlementCalculatorDialog,
          ),
          const SizedBox(width: 16),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFFF59E0B),
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(icon: Icon(Icons.people, size: 18), text: 'Vendor Accounts'),
            Tab(icon: Icon(Icons.assignment, size: 18), text: 'Site Assignments'),
            Tab(icon: Icon(Icons.inventory, size: 18), text: 'Material Tracking'),
            Tab(icon: Icon(Icons.account_balance, size: 18), text: 'Customer Payments & Loans'),
            Tab(icon: Icon(Icons.assessment, size: 18), text: 'Financial Summaries'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildVendorsListTab(),
                _buildAssignmentsTab(),
                _buildMaterialTrackingTab(),
                _buildCustomerPaymentsTab(),
                _buildFinancialSummariesTab(),
              ],
            ),
    );
  }

  // ============================================================================
  // TAB 1: VENDOR ACCOUNTS
  // ============================================================================

  Widget _buildVendorsListTab() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          if (_errorMessage != null) _buildSetupRequiredBanner(),
          // Search Bar
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: BorderSide(color: Colors.grey.shade300),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12.0),
              child: TextField(
                decoration: const InputDecoration(
                  hintText: 'Search vendors by Name, Vendor Code, or Mobile Number...',
                  prefixIcon: Icon(Icons.search),
                  border: InputBorder.none,
                ),
                onChanged: (val) => setState(() => _vendorSearchQuery = val),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: _filteredVendors.isEmpty
                ? Center(
                    child: Builder(
                      builder: (context) {
                        final isMissingTables = _errorMessage != null &&
                            (_errorMessage!.contains('PGRST205') || _errorMessage!.contains('sub_vendors'));
                        if (isMissingTables) {
                          return Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.warning_amber_rounded, size: 48, color: Color(0xFFDC2626)),
                              const SizedBox(height: 12),
                              const Text(
                                'Sub-Vendor Tables Not Initialized in Supabase',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFFDC2626)),
                              ),
                              const SizedBox(height: 6),
                              const Text(
                                'Table "public.sub_vendors" is missing from the database schema cache.\nPlease run the migration in Supabase SQL editor to create the tables.',
                                textAlign: TextAlign.center,
                                style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton.icon(
                                icon: const Icon(Icons.code),
                                label: const Text('View Supabase Setup Instructions'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF0D2B6F),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                ),
                                onPressed: _showMigrationSqlHelpDialog,
                              ),
                            ],
                          );
                        }

                        if (_errorMessage != null) {
                          return Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.error_outline, size: 48, color: Color(0xFFDC2626)),
                              const SizedBox(height: 12),
                              const Text(
                                'Failed to Load Sub-Vendor Data',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFFDC2626)),
                              ),
                              const SizedBox(height: 6),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 32.0),
                                child: Text(
                                  _errorMessage!,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                                ),
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton.icon(
                                icon: const Icon(Icons.refresh),
                                label: const Text('Retry'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF0D2B6F),
                                  foregroundColor: Colors.white,
                                ),
                                onPressed: _loadAllData,
                              ),
                            ],
                          );
                        }

                        return Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.people_outline, size: 52, color: Colors.grey.shade400),
                            const SizedBox(height: 12),
                            const Text(
                              'No Sub-Vendors Added Yet',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'Register your first solar contractor to assign sites and track materials.',
                              style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              icon: const Icon(Icons.person_add, size: 16),
                              label: const Text('Add Sub-Vendor'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFF59E0B),
                                foregroundColor: Colors.black87,
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              ),
                              onPressed: () async {
                                final created = await showDialog<bool>(
                                  context: context,
                                  builder: (_) => const AddEditSubVendorDialog(),
                                );
                                if (created == true) _loadAllData();
                              },
                            ),
                          ],
                        );
                      },
                    ),
                  )
                : ListView.builder(
                    itemCount: _filteredVendors.length,
                    itemBuilder: (context, index) {
                      final v = _filteredVendors[index];
                      final isBlocked = v.isBlocked;

                      // Live aggregated metrics for this vendor across all sites
                      final vendorAssignments = _assignments.where((a) => a.vendorId == v.id).toList();
                      final totalSites = vendorAssignments.length;
                      final totalKw = vendorAssignments.fold<double>(0.0, (sum, a) => sum + a.siteCapacityKw);
                      final totalQuotation = vendorAssignments.fold<double>(0.0, (sum, a) => sum + a.effectiveSiteAmount);
                      final totalReceivable = vendorAssignments.fold<double>(0.0, (sum, a) => sum + a.effectiveReceivedAmount);
                      final totalLoanCredited = vendorAssignments.fold<double>(0.0, (sum, a) => sum + a.totalLoanCredited);
                      final totalPending = vendorAssignments.fold<double>(0.0, (sum, a) => sum + a.effectiveCustomerOutstanding);

                      return Card(
                        elevation: 0,
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side: BorderSide(color: isBlocked ? Colors.red.shade200 : Colors.grey.shade300),
                        ),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(10),
                          onTap: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => SubVendorCompleteFinancialDashboardScreen(
                                  vendor: v,
                                  isAdmin: true,
                                ),
                              ),
                            );
                            _loadAllData();
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Top Header Row: Vendor Info & Administrative Controls
                                Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 20,
                                      backgroundColor: isBlocked ? Colors.red.shade100 : const Color(0xFFE0F2FE),
                                      child: Icon(
                                        isBlocked ? Icons.block : Icons.business,
                                        color: isBlocked ? Colors.red : const Color(0xFF0D2B6F),
                                        size: 20,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Flexible(
                                                child: Text(
                                                  v.name,
                                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: Colors.blueGrey.shade50,
                                                  borderRadius: BorderRadius.circular(4),
                                                  border: Border.all(color: Colors.blueGrey.shade200),
                                                ),
                                                child: Text(
                                                  'ID: ${v.vendorCode}',
                                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                                                ),
                                              ),
                                              const SizedBox(width: 6),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: isBlocked ? Colors.red.shade50 : Colors.green.shade50,
                                                  borderRadius: BorderRadius.circular(4),
                                                  border: Border.all(color: isBlocked ? Colors.red.shade200 : Colors.green.shade200),
                                                ),
                                                child: Text(
                                                  v.status,
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.bold,
                                                    color: isBlocked ? Colors.red.shade800 : Colors.green.shade800,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          Wrap(
                                            spacing: 12,
                                            children: [
                                              Text('📱 ${v.mobile}', style: const TextStyle(fontSize: 12, color: Color(0xFF475569))),
                                              Text('⚡ Rate: ${_currency.format(v.defaultRatePerKw)}/kW', style: const TextStyle(fontSize: 12, color: Color(0xFF475569))),
                                              if (v.bankName != null)
                                                Text('🏦 ${v.bankName}', style: const TextStyle(fontSize: 12, color: Color(0xFF475569))),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    // Quick Admin Action Icons
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.payment, color: Color(0xFF047857), size: 20),
                                          tooltip: 'Record Payout',
                                          onPressed: () async {
                                            final recorded = await showDialog<bool>(
                                              context: context,
                                              builder: (_) => RecordVendorPayoutDialog(
                                                vendor: v,
                                                assignments: vendorAssignments,
                                              ),
                                            );
                                            if (recorded == true) _loadAllData();
                                          },
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.edit, color: Colors.blue, size: 20),
                                          tooltip: 'Edit Vendor Details',
                                          onPressed: () async {
                                            final updated = await showDialog<bool>(
                                              context: context,
                                              builder: (_) => AddEditSubVendorDialog(vendor: v),
                                            );
                                            if (updated == true) _loadAllData();
                                          },
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.lock_reset, color: Colors.orange, size: 20),
                                          tooltip: 'Reset Password',
                                          onPressed: () {
                                            showDialog(
                                              context: context,
                                              builder: (_) => ResetVendorPasswordDialog(vendor: v),
                                            );
                                          },
                                        ),
                                        Switch(
                                          value: !isBlocked,
                                          activeColor: const Color(0xFF047857),
                                          onChanged: (val) async {
                                            final newStatus = val ? 'Active' : 'Blocked';
                                            await SubVendorService.toggleVendorStatus(v.id, newStatus);
                                            _loadAllData();
                                          },
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                const Divider(height: 20),

                                // 6 Aggregated Metrics Row (Live Aggregation)
                                Wrap(
                                  spacing: 16,
                                  runSpacing: 8,
                                  children: [
                                    _buildVendorCardKpi('Total Sites', '$totalSites Sites', Icons.layers, const Color(0xFF0D2B6F)),
                                    _buildVendorCardKpi('Installed Capacity', '${totalKw.toStringAsFixed(1)} kW', Icons.solar_power, const Color(0xFF0284C7)),
                                    _buildVendorCardKpi('Total Quotation', _currency.format(totalQuotation), Icons.receipt, const Color(0xFF1E3A8A)),
                                    _buildVendorCardKpi('Total Receivable', _currency.format(totalReceivable), Icons.payments, const Color(0xFF0D9488)),
                                    _buildVendorCardKpi('Loan Credited', _currency.format(totalLoanCredited), Icons.account_balance, const Color(0xFF047857)),
                                    _buildVendorCardKpi(
                                      'Pending Amount',
                                      _currency.format(totalPending),
                                      Icons.hourglass_bottom,
                                      totalPending > 0 ? const Color(0xFFD97706) : Colors.grey,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),

                                // Click to Open Complete Dashboard Banner Button
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    ElevatedButton.icon(
                                      icon: const Icon(Icons.dashboard, size: 16),
                                      label: const Text('Open Complete Financial Dashboard →'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFF0D2B6F),
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                        textStyle: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
                                      ),
                                      onPressed: () async {
                                        await Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => SubVendorCompleteFinancialDashboardScreen(
                                              vendor: v,
                                              isAdmin: true,
                                            ),
                                          ),
                                        );
                                        _loadAllData();
                                      },
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildVendorCardKpi(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label, style: const TextStyle(fontSize: 10, color: Color(0xFF64748B), fontWeight: FontWeight.w500)),
              Text(value, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color)),
            ],
          ),
        ],
      ),
    );
  }

  // ============================================================================
  // TAB 2: SITE ASSIGNMENTS
  // ============================================================================

  Widget _buildAssignmentsTab() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          // Filter Row
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String?>(
                  value: _selectedVendorFilter,
                  decoration: const InputDecoration(
                    labelText: 'Filter by Sub-Vendor',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('All Sub-Vendors')),
                    ..._vendors.map((v) => DropdownMenuItem(value: v.id, child: Text('${v.name} (${v.vendorCode})'))),
                  ],
                  onChanged: (val) => setState(() => _selectedVendorFilter = val),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _assignmentStatusFilter,
                  decoration: const InputDecoration(
                    labelText: 'Filter by Status',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: const [
                    DropdownMenuItem(value: 'All', child: Text('All Statuses')),
                    DropdownMenuItem(value: 'Assigned', child: Text('Assigned')),
                    DropdownMenuItem(value: 'In Progress', child: Text('In Progress')),
                    DropdownMenuItem(value: 'Completed', child: Text('Completed')),
                    DropdownMenuItem(value: 'Settled', child: Text('Settled')),
                  ],
                  onChanged: (val) => setState(() => _assignmentStatusFilter = val ?? 'All'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: _filteredAssignments.isEmpty
                ? const Center(child: Text('No site assignments found.'))
                : ListView.builder(
                    itemCount: _filteredAssignments.length,
                    itemBuilder: (context, index) {
                      final a = _filteredAssignments[index];
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
                                  Row(
                                    children: [
                                      Text(
                                        a.customerName ?? 'Customer',
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.blue.shade50,
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text('CA: ${a.consumerNo ?? "-"}', style: const TextStyle(fontSize: 11)),
                                      ),
                                    ],
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: Colors.green.shade50,
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(color: Colors.green.shade200),
                                    ),
                                    child: Text(
                                      'Vendor: ${a.vendorName ?? "Sub-Vendor"} (${a.vendorCode ?? ""})',
                                      style: TextStyle(color: Colors.green.shade900, fontWeight: FontWeight.bold, fontSize: 11),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 16,
                                children: [
                                  Text('Capacity: ${a.siteCapacityKw} kW'),
                                  Text('Vendor Rate: ${_currency.format(a.ratePerKw)}/kW'),
                                  Text('Vendor Charges: ${_currency.format(a.vendorCharges)}'),
                                  Text('Status: ${a.status}'),
                                  Text('Assigned: ${_dateFormat.format(a.assignedDate)}'),
                                ],
                              ),
                              const SizedBox(height: 8),
                              // Customer Payment & Loan Lifecycle Overview Banner
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                decoration: BoxDecoration(
                                  color: a.isBankLoan ? const Color(0xFFF0FDF4) : const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: a.isBankLoan ? const Color(0xFFBBF7D0) : const Color(0xFFE2E8F0),
                                  ),
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
                                              size: 15,
                                              color: a.isBankLoan ? const Color(0xFF047857) : const Color(0xFF0D2B6F),
                                            ),
                                            const SizedBox(width: 6),
                                            Text(
                                              a.paymentType,
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 12,
                                                color: a.isBankLoan ? const Color(0xFF047857) : const Color(0xFF0D2B6F),
                                              ),
                                            ),
                                            if (a.isBankLoan) ...[
                                              const SizedBox(width: 8),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: a.loanStatus == 'Fully Credited' ? const Color(0xFFDCFCE7) : const Color(0xFFFEF3C7),
                                                  borderRadius: BorderRadius.circular(4),
                                                ),
                                                child: Text(
                                                  'Loan: ${a.loanStatus}',
                                                  style: TextStyle(
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.bold,
                                                    color: a.loanStatus == 'Fully Credited' ? const Color(0xFF166534) : const Color(0xFF92400E),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                        Row(
                                          children: [
                                            Text(
                                              'Site Total: ${_currency.format(a.effectiveSiteAmount)}',
                                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                            ),
                                            const SizedBox(width: 12),
                                            Text(
                                              'Received: ${_currency.format(a.effectiveReceivedAmount)}',
                                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF047857)),
                                            ),
                                            const SizedBox(width: 12),
                                            Text(
                                              'Due: ${_currency.format(a.effectiveCustomerOutstanding)}',
                                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.deepOrange),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                    if (a.isBankLoan && (a.loanSanctionedAmount > 0 || a.totalLoanCredited > 0)) ...[
                                      const SizedBox(height: 6),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            'Bank: ${a.loanBankName ?? "Not specified"} ${a.loanApplicationId != null && a.loanApplicationId!.isNotEmpty ? "(${a.loanApplicationId})" : ""}',
                                            style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                                          ),
                                          Text(
                                            'Sanctioned: ${_currency.format(a.loanSanctionedAmount)} | Credited: ${_currency.format(a.totalLoanCredited)} | Pending: ${_currency.format(a.loanPendingCredit)}',
                                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF047857)),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              const Divider(height: 16),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Wrap(
                                    spacing: 6,
                                    runSpacing: 6,
                                    children: [
                                      // Customer Payment / Bank Credit Button
                                      ElevatedButton.icon(
                                        icon: const Icon(Icons.add_card, size: 14),
                                        label: const Text('+ Payment / Credit'),
                                        style: ElevatedButton.styleFrom(
                                          visualDensity: VisualDensity.compact,
                                          backgroundColor: const Color(0xFF047857),
                                          foregroundColor: Colors.white,
                                        ),
                                        onPressed: () async {
                                          final ok = await showDialog<bool>(
                                            context: context,
                                            builder: (_) => RecordCustomerPaymentDialog(assignment: a),
                                          );
                                          if (ok == true) _loadAllData();
                                        },
                                      ),
                                      // Customer Payment Ledger Dialog Button
                                      OutlinedButton.icon(
                                        icon: const Icon(Icons.receipt, size: 14),
                                        label: const Text('Ledger'),
                                        style: OutlinedButton.styleFrom(
                                          visualDensity: VisualDensity.compact,
                                          foregroundColor: const Color(0xFF0D2B6F),
                                        ),
                                        onPressed: () async {
                                          await showDialog(
                                            context: context,
                                            builder: (_) => SitePaymentLedgerDialog(assignment: a),
                                          );
                                          _loadAllData();
                                        },
                                      ),
                                      // Configure Payment & Loan Settings Button
                                      OutlinedButton.icon(
                                        icon: const Icon(Icons.settings, size: 14),
                                        label: const Text('Config'),
                                        style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact),
                                        onPressed: () async {
                                          final ok = await showDialog<bool>(
                                            context: context,
                                            builder: (_) => ConfigureSitePaymentDialog(assignment: a),
                                          );
                                          if (ok == true) _loadAllData();
                                        },
                                      ),
                                      // Final Settlement Calculator Dialog Button
                                      ElevatedButton.icon(
                                        icon: const Icon(Icons.calculate, size: 14),
                                        label: const Text('Settlement Calculator'),
                                        style: ElevatedButton.styleFrom(
                                          visualDensity: VisualDensity.compact,
                                          backgroundColor: const Color(0xFF0D2B6F),
                                          foregroundColor: Colors.white,
                                        ),
                                        onPressed: () async {
                                          final ok = await showDialog<bool>(
                                            context: context,
                                            builder: (_) => SubVendorFinalSettlementCalculatorDialog(assignment: a),
                                          );
                                          if (ok == true) _loadAllData();
                                        },
                                      ),
                                      // Issue Material Button
                                      ElevatedButton.icon(
                                        icon: const Icon(Icons.arrow_upward, size: 14),
                                        label: const Text('Issue Material'),
                                        style: ElevatedButton.styleFrom(
                                          visualDensity: VisualDensity.compact,
                                          backgroundColor: const Color(0xFF0D2B6F),
                                          foregroundColor: Colors.white,
                                        ),
                                        onPressed: () async {
                                          final ok = await showDialog<bool>(
                                            context: context,
                                            builder: (_) => IssueReturnMaterialDialog(assignment: a, transactionType: 'ISSUE'),
                                          );
                                          if (ok == true) _loadAllData();
                                        },
                                      ),
                                      // Return Material Button
                                      OutlinedButton.icon(
                                        icon: const Icon(Icons.arrow_downward, size: 14),
                                        label: const Text('Material Return'),
                                        style: OutlinedButton.styleFrom(
                                          visualDensity: VisualDensity.compact,
                                          foregroundColor: Colors.red.shade800,
                                        ),
                                        onPressed: () async {
                                          final ok = await showDialog<bool>(
                                            context: context,
                                            builder: (_) => IssueReturnMaterialDialog(assignment: a, transactionType: 'RETURN'),
                                          );
                                          if (ok == true) _loadAllData();
                                        },
                                      ),
                                    ],
                                  ),
                                  Row(
                                    children: [
                                      // Details Dialog
                                      OutlinedButton.icon(
                                        icon: const Icon(Icons.receipt_long, size: 14),
                                        label: const Text('Site Financials'),
                                        style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact),
                                        onPressed: () {
                                          showDialog(
                                            context: context,
                                            builder: (_) => VendorSiteDetailDialog(assignment: a, isAdmin: true),
                                          );
                                        },
                                      ),
                                      const SizedBox(width: 8),
                                      // Statement PDF
                                      IconButton(
                                        icon: const Icon(Icons.picture_as_pdf, color: Color(0xFF0D2B6F)),
                                        tooltip: 'Generate PDF Statement',
                                        onPressed: () async {
                                          final d = await SubVendorService.getSiteFinancialDetail(a);
                                          SubVendorPdfService.printOrShareSiteStatement(d);
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
                    },
                  ),
          ),
        ],
      ),
    );
  }

  // ============================================================================
  // TAB 3: MATERIAL TRACKING
  // ============================================================================

  Widget _buildMaterialTrackingTab() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          color: Colors.blue.shade50,
          child: Row(
            children: [
              const Icon(Icons.info_outline, color: Color(0xFF0D2B6F), size: 20),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Dynamic Material Tracking: Material costs update live when items are issued or returned. Solar Panels & Inverters: 5% GST | BOS: 18% GST.',
                  style: TextStyle(fontSize: 12, color: Color(0xFF1E3A8A)),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Issue Material to Site'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0D2B6F),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                ),
                onPressed: _openQuickIssueDialog,
              ),
            ],
          ),
        ),
        Expanded(
          child: _allMaterials.isEmpty
              ? const Center(child: Text('No material transactions recorded yet.'))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _allMaterials.length,
                  itemBuilder: (context, i) {
                    final m = _allMaterials[i];
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
                          child: Icon(isRet ? Icons.arrow_downward : Icons.arrow_upward, color: isRet ? Colors.red : Colors.green),
                        ),
                        title: Text(m.itemName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        subtitle: Text(
                          '${m.quantity} ${m.unit} @ ${_currency.format(m.unitRate)} | GST ${m.gstRate.toStringAsFixed(0)}% (Taxable: ${_currency.format(m.taxableAmount)}) | Date: ${_dateFormat.format(m.transactionDate)}',
                          style: const TextStyle(fontSize: 11.5),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '${isRet ? "-" : ""}${_currency.format(m.totalAmount)}',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: isRet ? Colors.red.shade700 : const Color(0xFF0D2B6F),
                                fontSize: 14,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                              onPressed: () async {
                                final confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (_) => AlertDialog(
                                    title: const Text('Delete Material Entry?'),
                                    content: const Text('This will dynamically adjust the site material cost.'),
                                    actions: [
                                      TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
                                      ElevatedButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Delete')),
                                    ],
                                  ),
                                );
                                if (confirm == true) {
                                  await SubVendorService.deleteMaterialTransaction(m.id);
                                  _loadAllData();
                                }
                              },
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

  // ============================================================================
  // TAB 4: CUSTOMER PAYMENTS & BANK LOAN DISBURSEMENT TRACKING
  // ============================================================================

  Widget _buildCustomerPaymentsTab() {
    double totalCollection = 0.0;
    double totalCash = 0.0;
    double totalLoanCredited = 0.0;
    double totalLoanSanctioned = 0.0;
    double totalLoanPending = 0.0;
    double totalOutstanding = 0.0;

    for (final a in _assignments) {
      totalCash += a.totalCashReceived;
      totalLoanCredited += a.totalLoanCredited;
      totalLoanSanctioned += a.loanSanctionedAmount;
      totalLoanPending += a.loanPendingCredit;
      totalCollection += a.effectiveReceivedAmount;
      totalOutstanding += a.effectiveCustomerOutstanding;
    }

    final filtered = _allCustomerPayments.where((p) {
      final matchesVendor = _selectedVendorFilter == null || p.vendorId == _selectedVendorFilter;
      final matchesCat = _customerPaymentCategoryFilter == 'All' || p.paymentType == _customerPaymentCategoryFilter;
      final q = _customerPaymentSearchQuery.toLowerCase();
      final matchesSearch = q.isEmpty ||
          (p.customerName ?? '').toLowerCase().contains(q) ||
          (p.consumerNo ?? '').toLowerCase().contains(q) ||
          (p.referenceNumber ?? '').toLowerCase().contains(q) ||
          (p.bankName ?? '').toLowerCase().contains(q) ||
          (p.vendorName ?? '').toLowerCase().contains(q);
      return matchesVendor && matchesCat && matchesSearch;
    }).toList();

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 4 KPI Summary Cards
          Row(
            children: [
              _metricSummaryCard('Total Collection', _currency.format(totalCollection), const Color(0xFF0D2B6F), icon: Icons.savings),
              _metricSummaryCard('Cash Received', _currency.format(totalCash), Colors.blueGrey, icon: Icons.payments),
              _metricSummaryCard(
                'Bank Loan Credited',
                _currency.format(totalLoanCredited),
                const Color(0xFF047857),
                icon: Icons.account_balance,
                subtitle: 'Sanctioned: ${_currency.format(totalLoanSanctioned)} | Pending: ${_currency.format(totalLoanPending)}',
              ),
              _metricSummaryCard('Customer Outstanding', _currency.format(totalOutstanding), Colors.deepOrange, icon: Icons.pending_actions),
            ],
          ),
          const SizedBox(height: 14),

          // Search, Filter & Quick Action Row
          Row(
            children: [
              Expanded(
                flex: 3,
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Search by Customer, CA No, Bank, or UTR / Txn ID...',
                    prefixIcon: const Icon(Icons.search),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onChanged: (val) => setState(() => _customerPaymentSearchQuery = val),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: DropdownButtonFormField<String?>(
                  value: _selectedVendorFilter,
                  decoration: InputDecoration(
                    labelText: 'Sub-Vendor',
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('All Sub-Vendors')),
                    ..._vendors.map((v) => DropdownMenuItem(value: v.id, child: Text('${v.name} (${v.vendorCode})'))),
                  ],
                  onChanged: (v) => setState(() => _selectedVendorFilter = v),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: DropdownButtonFormField<String>(
                  value: _customerPaymentCategoryFilter,
                  decoration: InputDecoration(
                    labelText: 'Category',
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'All', child: Text('All Categories')),
                    DropdownMenuItem(value: 'CASH', child: Text('Cash Only')),
                    DropdownMenuItem(value: 'BANK_LOAN', child: Text('Bank Loan Credit Only')),
                  ],
                  onChanged: (v) => setState(() => _customerPaymentCategoryFilter = v ?? 'All'),
                ),
              ),
              const SizedBox(width: 10),
              ElevatedButton.icon(
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Record Payment / Credit'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF047857),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: _openQuickRecordPaymentDialog,
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                icon: const Icon(Icons.file_download, size: 16),
                label: const Text('Export CSV'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () => _exportPaymentsCsv(filtered),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                icon: const Icon(Icons.calculate, size: 16),
                label: const Text('Settlement Calculator'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: _openQuickSettlementCalculatorDialog,
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Table / List of Payments
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.account_balance_wallet_outlined, size: 48, color: Colors.grey.shade400),
                        const SizedBox(height: 8),
                        const Text('No customer payments or bank loan credits found.'),
                        const SizedBox(height: 6),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.add),
                          label: const Text('Record Payment / Loan Credit'),
                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0D2B6F), foregroundColor: Colors.white),
                          onPressed: _openQuickRecordPaymentDialog,
                        ),
                      ],
                    ),
                  )
                : Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: ListView.separated(
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, idx) {
                        final p = filtered[idx];
                        final isLoan = p.isLoan;
                        return ListTile(
                          leading: CircleAvatar(
                            radius: 16,
                            backgroundColor: isLoan ? const Color(0xFFD1FAE5) : const Color(0xFFE0E7FF),
                            child: Icon(
                              isLoan ? Icons.account_balance : Icons.payments,
                              size: 18,
                              color: isLoan ? const Color(0xFF047857) : const Color(0xFF4338CA),
                            ),
                          ),
                          title: Row(
                            children: [
                              Text(p.customerName ?? 'Customer', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text('CA: ${p.consumerNo ?? "-"}', style: const TextStyle(fontSize: 11)),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: isLoan ? const Color(0xFFDCFCE7) : const Color(0xFFEEF2FF),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  isLoan ? 'BANK LOAN' : 'CASH (${p.paymentStage})',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: isLoan ? const Color(0xFF166534) : const Color(0xFF3730A3),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 4.0),
                            child: Wrap(
                              spacing: 14,
                              children: [
                                Text('Date: ${_dateFormat.format(p.paymentDate)}'),
                                Text('Vendor: ${p.vendorCode ?? "VND"} - ${p.vendorName ?? "Sub-Vendor"}'),
                                if (p.referenceNumber != null && p.referenceNumber!.isNotEmpty)
                                  Text('UTR / Txn: ${p.referenceNumber}', style: const TextStyle(fontWeight: FontWeight.bold)),
                                if (p.bankName != null && p.bankName!.isNotEmpty)
                                  Text('Bank: ${p.bankName}'),
                                if (p.remarks != null && p.remarks!.isNotEmpty)
                                  Text('Remarks: ${p.remarks}'),
                              ],
                            ),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _currency.format(p.amount),
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: isLoan ? const Color(0xFF047857) : const Color(0xFF0D2B6F),
                                ),
                              ),
                              const SizedBox(width: 12),
                              // Ledger button
                              IconButton(
                                icon: const Icon(Icons.receipt_long, color: Color(0xFF0D2B6F)),
                                tooltip: 'View Customer Ledger',
                                onPressed: () {
                                  final match = _assignments.firstWhere(
                                    (a) => a.id == p.assignmentId,
                                    orElse: () => _assignments.first,
                                  );
                                  showDialog(
                                    context: context,
                                    builder: (_) => SitePaymentLedgerDialog(assignment: match),
                                  ).then((_) => _loadAllData());
                                },
                              ),
                              // Settlement Calculator button
                              IconButton(
                                icon: const Icon(Icons.calculate, color: Color(0xFF2563EB)),
                                tooltip: 'Sub-Vendor Settlement Calculator',
                                onPressed: () {
                                  final match = _assignments.firstWhere(
                                    (a) => a.id == p.assignmentId,
                                    orElse: () => _assignments.first,
                                  );
                                  showDialog(
                                    context: context,
                                    builder: (_) => SubVendorFinalSettlementCalculatorDialog(assignment: match),
                                  ).then((_) => _loadAllData());
                                },
                              ),
                              // Delete button
                              IconButton(
                                icon: const Icon(Icons.delete_outline, color: Colors.red),
                                tooltip: 'Delete Payment Record',
                                onPressed: () => _handleDeleteCustomerPayment(p.id),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _openQuickRecordPaymentDialog() async {
    if (_assignments.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please assign at least one site first.')),
      );
      return;
    }

    VendorSiteAssignment? selected = _assignments.first;
    final pickedAssignment = await showDialog<VendorSiteAssignment>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDlgState) {
            return AlertDialog(
              title: const Text('Select Site for Payment Entry'),
              content: SizedBox(
                width: 480,
                child: DropdownButtonFormField<VendorSiteAssignment>(
                  value: selected,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Customer Site',
                    border: OutlineInputBorder(),
                  ),
                  items: _assignments.map((a) {
                    return DropdownMenuItem(
                      value: a,
                      child: Text('${a.customerName ?? "Customer"} (CA: ${a.consumerNo ?? "-"}) - ${a.vendorName ?? "Vendor"}'),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) setDlgState(() => selected = val);
                  },
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF047857), foregroundColor: Colors.white),
                  onPressed: () => Navigator.of(ctx).pop(selected),
                  child: const Text('Continue'),
                ),
              ],
            );
          },
        );
      },
    );

    if (pickedAssignment == null) return;

    final recorded = await showDialog<bool>(
      context: context,
      builder: (_) => RecordCustomerPaymentDialog(assignment: pickedAssignment),
    );
    if (recorded == true) _loadAllData();
  }

  Future<void> _handleDeleteCustomerPayment(String paymentId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Payment Record?'),
        content: const Text('Are you sure you want to delete this payment record? Recalculation will happen automatically.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await SubVendorService.deleteCustomerPayment(paymentId);
      _loadAllData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Payment record deleted successfully.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete payment: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _openQuickSettlementCalculatorDialog() {
    if (_assignments.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No site assignments found to calculate settlement.')),
      );
      return;
    }

    if (_assignments.length == 1) {
      showDialog(
        context: context,
        builder: (_) => SubVendorFinalSettlementCalculatorDialog(assignment: _assignments.first),
      ).then((_) => _loadAllData());
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.calculate, color: Color(0xFF0D2B6F)),
            SizedBox(width: 8),
            Text('Select Site for Settlement Calculation'),
          ],
        ),
        content: SizedBox(
          width: 520,
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: _assignments.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, i) {
              final a = _assignments[i];
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: const Color(0xFFE0F2FE),
                  child: Text('${a.siteCapacityKw.toStringAsFixed(0)}k',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0D2B6F))),
                ),
                title: Text(a.customerName ?? 'Customer', style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text('Vendor: ${a.vendorName ?? "Sub-Vendor"} (${a.vendorCode ?? "VND"}) | CA: ${a.consumerNo ?? "-"}'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                onTap: () {
                  Navigator.of(ctx).pop();
                  showDialog(
                    context: context,
                    builder: (_) => SubVendorFinalSettlementCalculatorDialog(assignment: a),
                  ).then((_) => _loadAllData());
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
        ],
      ),
    );
  }

  Future<void> _exportPaymentsCsv(List<VendorCustomerPayment> payments) async {
    try {
      final rows = <List<dynamic>>[];
      rows.add([
        'Payment ID',
        'Date',
        'Customer Name',
        'Consumer No',
        'Sub-Vendor Code',
        'Sub-Vendor Name',
        'Category',
        'Stage',
        'Amount (INR)',
        'Mode',
        'UTR / Txn ID',
        'Bank Name',
        'Loan App ID',
        'Status',
        'Remarks',
      ]);
      for (final p in payments) {
        rows.add([
          p.id,
          _dateFormat.format(p.paymentDate),
          p.customerName ?? '',
          p.consumerNo ?? '',
          p.vendorCode ?? '',
          p.vendorName ?? '',
          p.paymentType,
          p.paymentStage,
          p.amount,
          p.paymentMode,
          p.referenceNumber ?? '',
          p.bankName ?? '',
          p.loanApplicationId ?? '',
          p.status,
          p.remarks ?? '',
        ]);
      }
      final csvString = const ListToCsvConverter().convert(rows);
      final bytes = utf8.encode(csvString);
      final fileName = 'siya_customer_payments_${DateTime.now().millisecondsSinceEpoch}.csv';

      final result = await FilePicker.platform.saveFile(
        dialogTitle: 'Export Payments as CSV',
        fileName: fileName,
        bytes: Uint8List.fromList(bytes),
        type: FileType.custom,
        allowedExtensions: ['csv'],
      );

      if (result != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Exported CSV successfully: $fileName'), backgroundColor: const Color(0xFF047857)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to export CSV: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Widget _metricSummaryCard(String title, String value, Color color, {IconData? icon, String? subtitle}) {
    return Expanded(
      child: Card(
        color: color.withOpacity(0.07),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: color.withOpacity(0.2)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(title, style: TextStyle(fontSize: 12, color: Colors.grey.shade700, fontWeight: FontWeight.w600)),
                  if (icon != null) Icon(icon, size: 18, color: color),
                ],
              ),
              const SizedBox(height: 4),
              Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
              if (subtitle != null) ...[
                const SizedBox(height: 4),
                Text(subtitle, style: TextStyle(fontSize: 10.5, color: Colors.grey.shade600)),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================================
  // TAB 5: FINANCIAL SUMMARIES MATRIX
  // ============================================================================

  Widget _buildFinancialSummariesTab() {
    if (_vendors.isEmpty) return const Center(child: Text('No vendors registered yet.'));

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _vendors.length,
      itemBuilder: (context, index) {
        final v = _vendors[index];
        final vendorAssignments = _assignments.where((a) => a.vendorId == v.id).toList();
        final vendorMaterials = _allMaterials.where((m) => m.vendorId == v.id).toList();
        final vendorPayouts = _allPayouts.where((p) => p.vendorId == v.id).toList();

        final summary = VendorFinancialSummary.compute(
          vendorId: v.id,
          vendorCode: v.vendorCode,
          vendorName: v.name,
          assignments: vendorAssignments,
          allMaterials: vendorMaterials,
          allPayouts: vendorPayouts,
        );

        return Card(
          elevation: 0,
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(color: Colors.grey.shade300),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const CircleAvatar(
                          radius: 16,
                          backgroundColor: Color(0xFF0D2B6F),
                          child: Icon(Icons.business, size: 18, color: Colors.white),
                        ),
                        const SizedBox(width: 10),
                        Text(v.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        const SizedBox(width: 8),
                        Text('(${v.vendorCode})', style: const TextStyle(color: Colors.grey)),
                      ],
                    ),
                    Row(
                      children: [
                        ElevatedButton.icon(
                          icon: const Icon(Icons.calculate, size: 14),
                          label: const Text('Settlement Calculator'),
                          style: ElevatedButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                            backgroundColor: const Color(0xFF2563EB),
                            foregroundColor: Colors.white,
                          ),
                          onPressed: () {
                            if (vendorAssignments.isNotEmpty) {
                              showDialog(
                                context: context,
                                builder: (_) => SubVendorFinalSettlementCalculatorDialog(assignment: vendorAssignments.first),
                              ).then((_) => _loadAllData());
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('No sites assigned to this sub-vendor yet.')),
                              );
                            }
                          },
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.picture_as_pdf, size: 14),
                          label: const Text('Export Statement'),
                          style: ElevatedButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                            backgroundColor: const Color(0xFF0D2B6F),
                            foregroundColor: Colors.white,
                          ),
                          onPressed: () => SubVendorPdfService.printOrShareVendorOverallStatement(summary, vendor: v),
                        ),
                      ],
                    ),
                  ],
                ),
                const Divider(height: 16),
                Row(
                  children: [
                    _sumBox('Sites', '${summary.totalAssignedSites} (${summary.completedSites} Done)'),
                    _sumBox('Capacity', '${summary.totalCapacityKw} kW'),
                    _sumBox('Collection', _currency.format(summary.effectiveTotalCollection)),
                    _sumBox('Material Cost', '- ${_currency.format(summary.totalMaterialCost)}'),
                    _sumBox('SIYA Fee', '- ${_currency.format(summary.totalVendorCharges)}'),
                    _sumBox('Net GST', '- ${_currency.format(summary.totalNetGstLiability)}'),
                    _sumBox('Net Due', _currency.format(summary.netSettlementPayable), isHighlight: true),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _sumBox(String label, String value, {bool isHighlight = false}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        margin: const EdgeInsets.only(right: 6),
        decoration: BoxDecoration(
          color: isHighlight ? const Color(0xFFE0F2FE) : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: isHighlight ? const Color(0xFF0D2B6F) : Colors.grey.shade300),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 10.5, color: Colors.grey)),
            const SizedBox(height: 2),
            Text(
              value,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.bold,
                color: isHighlight ? const Color(0xFF0D2B6F) : Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSetupRequiredBanner() {
    final isMissingTables = _errorMessage != null &&
        (_errorMessage!.contains('PGRST205') || _errorMessage!.contains('sub_vendors'));
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFFCA5A5)),
      ),
      child: Row(
        children: [
          Icon(isMissingTables ? Icons.warning_amber_rounded : Icons.error_outline,
              color: const Color(0xFFDC2626), size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isMissingTables
                      ? 'Database Setup Required (Migration Pending)'
                      : 'Error Loading Sub-Vendor Data',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF991B1B)),
                ),
                const SizedBox(height: 2),
                Text(
                  isMissingTables
                      ? 'The sub_vendors tables have not been created in Supabase yet. Please apply migration 20261108000036_sub_vendor_management_module.sql in Supabase SQL Editor.'
                      : (_errorMessage ?? ''),
                  style: const TextStyle(fontSize: 12, color: Color(0xFF7F1D1D)),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (isMissingTables)
            ElevatedButton.icon(
              onPressed: _showMigrationSqlHelpDialog,
              icon: const Icon(Icons.terminal, size: 15),
              label: const Text('Setup Guide'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFDC2626),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
            )
          else
            ElevatedButton.icon(
              onPressed: _loadAllData,
              icon: const Icon(Icons.refresh, size: 15),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0D2B6F),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
            ),
        ],
      ),
    );
  }

  void _showMigrationSqlHelpDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.terminal, color: Color(0xFF0D2B6F)),
            SizedBox(width: 8),
            Text('Supabase Database Setup Required'),
          ],
        ),
        content: SizedBox(
          width: 620,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'To activate the Sub-Vendor and Customer Payment/Bank Loan modules, apply the database migrations in your Supabase project (Project: unueboqvasadiuvgcvvh):',
                style: const TextStyle(fontSize: 13, color: Color(0xFF334155)),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const SelectableText(
                  '1. Open Supabase Dashboard SQL Editor:\n'
                  '   https://supabase.com/dashboard/project/unueboqvasadiuvgcvvh/sql/new\n\n'
                  '2. Core Sub-Vendor Module Migration:\n'
                  '   supabase/migrations/20261108000036_sub_vendor_management_module.sql\n\n'
                  '3. Customer Payments & Bank Loan Tracking Migration:\n'
                  '   supabase/migrations/20261108000037_sub_vendor_customer_payments.sql\n\n'
                  '4. Final Settlement & Payout Calculator Migration:\n'
                  '   supabase/migrations/20261108000038_sub_vendor_settlement_calculator.sql\n\n'
                  '5. Paste the SQL contents into the Supabase SQL Editor and click "RUN".\n\n'
                  '6. After successful run, return here and click "Refresh All".',
                  style: TextStyle(color: Color(0xFF38BDF8), fontFamily: 'monospace', fontSize: 12, height: 1.4),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
          FilledButton.icon(
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text('Refresh All Data'),
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFF0D2B6F)),
            onPressed: () {
              Navigator.pop(ctx);
              _loadAllData();
            },
          ),
        ],
      ),
    );
  }

  void _openQuickIssueDialog() async {
    if (_assignments.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please assign at least one site to a sub-vendor before issuing materials.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    VendorSiteAssignment? selected = _assignments.first;
    final confirmed = await showDialog<VendorSiteAssignment>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.inventory, color: Color(0xFF0D2B6F)),
              SizedBox(width: 8),
              Text('Select Site to Issue Material'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Select the customer site assigned to a sub-vendor:', style: TextStyle(fontSize: 13)),
              const SizedBox(height: 12),
              DropdownButtonFormField<VendorSiteAssignment>(
                value: selected,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Assigned Site', border: OutlineInputBorder()),
                items: _assignments.map((a) {
                  return DropdownMenuItem(
                    value: a,
                    child: Text(
                      '${a.customerName ?? "Customer"} (${a.siteCapacityKw} kW) - ${a.vendorName ?? "Vendor"}',
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13),
                    ),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) setDialogState(() => selected = val);
                },
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, selected),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0D2B6F), foregroundColor: Colors.white),
              child: const Text('Continue to Issue'),
            ),
          ],
        ),
      ),
    );

    if (confirmed != null && mounted) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (_) => IssueReturnMaterialDialog(assignment: confirmed, transactionType: 'ISSUE'),
      );
      if (ok == true) _loadAllData();
    }
  }
}

