import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:siya_shared/siya_shared.dart';
import '../services/sub_vendor_service.dart';
import '../services/sub_vendor_pdf_service.dart';
import '../widgets/sub_vendor_dialogs.dart';

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

  bool _isLoading = true;
  String? _selectedVendorFilter;
  String _assignmentStatusFilter = 'All';
  String _vendorSearchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadAllData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAllData() async {
    setState(() => _isLoading = true);
    try {
      final vendors = await SubVendorService.fetchAllVendors();
      final assignments = await SubVendorService.fetchAssignments();
      final payouts = vendors.isNotEmpty ? await SubVendorService.fetchVendorPayouts(vendors.first.id) : <VendorPayout>[];

      List<VendorMaterialTransaction> materials = [];
      if (vendors.isNotEmpty) {
        materials = await SubVendorService.fetchVendorMaterials(vendors.first.id);
      }

      if (mounted) {
        setState(() {
          _vendors = vendors;
          _assignments = assignments;
          _allMaterials = materials;
          _allPayouts = payouts;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load sub-vendor data: $e'), backgroundColor: Colors.red),
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
                ? const Center(child: Text('No sub-vendors found.'))
                : ListView.builder(
                    itemCount: _filteredVendors.length,
                    itemBuilder: (context, index) {
                      final v = _filteredVendors[index];
                      final isBlocked = v.isBlocked;
                      return Card(
                        elevation: 0,
                        margin: const EdgeInsets.only(bottom: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: BorderSide(color: isBlocked ? Colors.red.shade200 : Colors.grey.shade300),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          leading: CircleAvatar(
                            backgroundColor: isBlocked ? Colors.red.shade100 : const Color(0xFFE0F2FE),
                            child: Icon(
                              isBlocked ? Icons.block : Icons.business,
                              color: isBlocked ? Colors.red : const Color(0xFF0D2B6F),
                            ),
                          ),
                          title: Row(
                            children: [
                              Text(v.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.blueGrey.shade50,
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: Colors.blueGrey.shade200),
                                ),
                                child: Text(v.vendorCode, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 4.0),
                            child: Wrap(
                              spacing: 16,
                              children: [
                                Text('Mobile: ${v.mobile}'),
                                Text('Rate: ${_currency.format(v.defaultRatePerKw)}/kW'),
                                if (v.contactPerson != null) Text('Contact: ${v.contactPerson}'),
                                if (v.bankName != null) Text('Bank: ${v.bankName} (${v.accountNumber ?? ""})'),
                              ],
                            ),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Payout Button
                              IconButton(
                                icon: const Icon(Icons.payment, color: Color(0xFF047857)),
                                tooltip: 'Record Payout',
                                onPressed: () async {
                                  final recorded = await showDialog<bool>(
                                    context: context,
                                    builder: (_) => RecordVendorPayoutDialog(
                                      vendor: v,
                                      assignments: _assignments.where((a) => a.vendorId == v.id).toList(),
                                    ),
                                  );
                                  if (recorded == true) _loadAllData();
                                },
                              ),
                              // Edit Button
                              IconButton(
                                icon: const Icon(Icons.edit, color: Colors.blue),
                                tooltip: 'Edit Vendor Details',
                                onPressed: () async {
                                  final updated = await showDialog<bool>(
                                    context: context,
                                    builder: (_) => AddEditSubVendorDialog(vendor: v),
                                  );
                                  if (updated == true) _loadAllData();
                                },
                              ),
                              // Reset Password Button
                              IconButton(
                                icon: const Icon(Icons.lock_reset, color: Colors.orange),
                                tooltip: 'Reset Password',
                                onPressed: () {
                                  showDialog(
                                    context: context,
                                    builder: (_) => ResetVendorPasswordDialog(vendor: v),
                                  );
                                },
                              ),
                              // Block / Activate Switch
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
                              const Divider(height: 16),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
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
                                      const SizedBox(width: 8),
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
          padding: const EdgeInsets.all(12),
          color: Colors.blue.shade50,
          child: const Row(
            children: [
              Icon(Icons.info_outline, color: Colors.blue, size: 20),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Dynamic Material Tracking: Material costs update live when items are issued or returned. Solar Panels & Inverters are 5% GST; BOS is 18% GST.',
                  style: TextStyle(fontSize: 12),
                ),
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
  // TAB 4: FINANCIAL SUMMARIES MATRIX
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
                const Divider(height: 16),
                Row(
                  children: [
                    _sumBox('Sites', '${summary.totalAssignedSites} (${summary.completedSites} Done)'),
                    _sumBox('Capacity', '${summary.totalCapacityKw} kW'),
                    _sumBox('Net Material Cost', _currency.format(summary.totalMaterialCost)),
                    _sumBox('Vendor Charges', _currency.format(summary.totalVendorCharges)),
                    _sumBox('Total Paid', _currency.format(summary.totalPaidAmount)),
                    _sumBox('Outstanding Due', _currency.format(summary.outstandingSettlement), isHighlight: true),
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
}

