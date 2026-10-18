import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/agent_master.dart';
import '../models/commission_record.dart';
import '../models/commission_payment.dart';
import '../services/commission_service.dart';
import '../utils/file_download_utils.dart';
import '../utils/responsive.dart';
import '../widgets/agent_master_dialog.dart';
import 'bulk_commission_entry_screen.dart';

/// Commission Agent Module Screen
///
/// Features:
/// - Button: **Bulk Add Commission**
/// - Filters: Agent-wise, Customer-wise, Date range, Status (Pending Approval, Approved, Partially Paid, Paid, All)
/// - Search: Agent, Customer, Consumer No, Entry Number
/// - Actions: Edit authorized entries, Record Payment, Bulk Approval, Export Report
class CommissionScreen extends StatefulWidget {
  const CommissionScreen({super.key});

  @override
  State<CommissionScreen> createState() => _CommissionScreenState();
}

class _CommissionScreenState extends State<CommissionScreen> {
  List<CommissionRecord> _allCommissions = [];
  List<CommissionRecord> _filteredCommissions = [];
  List<AgentMaster> _agents = [];
  bool _isLoading = true;

  // Filter & Search states
  String _selectedStatus = 'All';
  String? _selectedAgent = 'All';
  final TextEditingController _searchController = TextEditingController();
  DateTimeRange? _selectedDateRange;

  // Multi-selection for bulk approval
  final Set<String> _selectedCommissionIds = {};

  final _currencyFormat = NumberFormat('#,##,##0.00', 'en_IN');
  final _dateFormat = DateFormat('dd MMM yyyy');

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final agentsFuture = CommissionService.fetchAgents();
    final commissionsFuture = CommissionService.fetchCommissions();

    final results = await Future.wait([agentsFuture, commissionsFuture]);
    if (mounted) {
      setState(() {
        _agents = results[0] as List<AgentMaster>;
        _allCommissions = results[1] as List<CommissionRecord>;
        _selectedCommissionIds.clear();
        _applyFilters();
        _isLoading = false;
      });
    }
  }

  void _applyFilters() {
    List<CommissionRecord> list = List.from(_allCommissions);

    // Status filter
    if (_selectedStatus != 'All') {
      list = list.where((c) => c.status == _selectedStatus).toList();
    }

    // Agent filter
    if (_selectedAgent != null && _selectedAgent != 'All') {
      list = list.where((c) => c.agentName == _selectedAgent).toList();
    }

    // Date range filter
    if (_selectedDateRange != null) {
      list = list.where((c) {
        return !c.commissionDate.isBefore(_selectedDateRange!.start) &&
            !c.commissionDate.isAfter(_selectedDateRange!.end.add(const Duration(days: 1)));
      }).toList();
    }

    // Search query
    final query = _searchController.text.trim().toLowerCase();
    if (query.isNotEmpty) {
      list = list.where((c) {
        return c.agentName.toLowerCase().contains(query) ||
            c.customerName.toLowerCase().contains(query) ||
            (c.consumerNo != null && c.consumerNo!.toLowerCase().contains(query)) ||
            c.entryNumber.toLowerCase().contains(query);
      }).toList();
    }

    setState(() => _filteredCommissions = list);
  }

  // ---------------------------------------------------------------------------
  // Metric Calculations
  // ---------------------------------------------------------------------------

  double get _totalCommission => _allCommissions.fold(0.0, (sum, c) => sum + c.commissionAmount);
  double get _totalApproved => _allCommissions.where((c) => c.isApproved).fold(0.0, (sum, c) => sum + c.effectiveApprovedAmount);
  double get _totalPaid => _allCommissions.fold(0.0, (sum, c) => sum + c.paidAmount);
  double get _totalPendingPayout => _allCommissions.where((c) => c.isApproved).fold(0.0, (sum, c) => sum + c.pendingAmount);

  int get _pendingApprovalCount => _allCommissions.where((c) => c.isPendingApproval).length;

  // ---------------------------------------------------------------------------
  // Approval Actions
  // ---------------------------------------------------------------------------

  Future<void> _handleApproveIndividual(CommissionRecord comm) async {
    final amountController = TextEditingController(text: comm.commissionAmount.toString());
    final notesController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Approve Commission (${comm.entryNumber})'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Agent: ${comm.agentName}', style: const TextStyle(fontWeight: FontWeight.bold)),
            Text('Customer: ${comm.customerName}'),
            const SizedBox(height: 12),
            TextField(
              controller: amountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Approved Commission Amount (₹)',
                prefixText: '₹ ',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: notesController,
              decoration: const InputDecoration(
                labelText: 'Approval Notes (Optional)',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFF16A34A)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Approve'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final appAmount = double.tryParse(amountController.text.trim()) ?? comm.commissionAmount;
      final ok = await CommissionService.approveCommission(
        commissionId: comm.id,
        approvedAmount: appAmount,
        notes: notesController.text.trim().isNotEmpty ? notesController.text.trim() : null,
      );
      if (ok) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Commission entry approved successfully!'), backgroundColor: Color(0xFF16A34A)),
          );
        }
        _loadData();
      }
    }
  }

  Future<void> _handleBulkApproval() async {
    if (_selectedCommissionIds.isEmpty) return;

    final count = _selectedCommissionIds.length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Bulk Approve ($count Entries)'),
        content: Text('Are you sure you want to approve all $count selected commission records?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFF16A34A)),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Approve $count Entries'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final approvedCount = await CommissionService.bulkApproveCommissions(
        commissionIds: _selectedCommissionIds.toList(),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Successfully approved $approvedCount commission entries!'), backgroundColor: const Color(0xFF16A34A)),
        );
      }
      _loadData();
    }
  }

  // ---------------------------------------------------------------------------
  // Record Payment Flow
  // ---------------------------------------------------------------------------

  void _openRecordPaymentDialog(CommissionRecord comm) {
    if (!comm.isApproved) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Only approved commission entries can receive payments.')),
      );
      return;
    }

    final pending = comm.pendingAmount;
    if (pending <= 0.01) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This commission record is already fully paid!')),
      );
      return;
    }

    final amountController = TextEditingController(text: pending.toStringAsFixed(2));
    final refController = TextEditingController();
    final bankController = TextEditingController();
    final notesController = TextEditingController();
    String selectedMode = 'Bank Transfer';
    bool isSubmitting = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: [
                  const Icon(Icons.payments_outlined, color: Color(0xFF16A34A)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text('Record Payment (${comm.entryNumber})', style: const TextStyle(fontSize: 17)),
                  ),
                ],
              ),
              content: SizedBox(
                width: 480,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Balance info box
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.blue.shade200),
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Agent Name:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                                Text(comm.agentName, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Customer:', style: TextStyle(fontSize: 12)),
                                Text(comm.customerName, style: const TextStyle(fontSize: 12)),
                              ],
                            ),
                            const Divider(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Approved Commission:', style: TextStyle(fontSize: 12)),
                                Text('₹${_currencyFormat.format(comm.effectiveApprovedAmount)}', style: const TextStyle(fontSize: 12)),
                              ],
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Already Paid:', style: TextStyle(fontSize: 12)),
                                Text('₹${_currencyFormat.format(comm.paidAmount)}', style: const TextStyle(fontSize: 12, color: Colors.green)),
                              ],
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Pending Balance:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                                Text(
                                  '₹${_currencyFormat.format(pending)}',
                                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFFEA580C)),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Notice: margin money not commission
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.amber.shade50,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'Note: Margin receipts and loan documents are customer finance records and are NOT treated as commission payments.',
                          style: TextStyle(fontSize: 11, color: Colors.brown.shade800),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Payment amount
                      TextFormField(
                        controller: amountController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(
                          labelText: 'Payment Amount (₹) *',
                          prefixText: '₹ ',
                          helperText: 'Max allowable: ₹${_currencyFormat.format(pending)}',
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Payment mode
                      DropdownButtonFormField<String>(
                        value: selectedMode,
                        decoration: const InputDecoration(labelText: 'Payment Mode *'),
                        items: const [
                          DropdownMenuItem(value: 'Bank Transfer', child: Text('Bank Transfer (NEFT/RTGS/IMPS)')),
                          DropdownMenuItem(value: 'UPI', child: Text('UPI / Google Pay / PhonePe')),
                          DropdownMenuItem(value: 'Cash', child: Text('Cash')),
                          DropdownMenuItem(value: 'Cheque', child: Text('Cheque')),
                        ],
                        onChanged: (val) {
                          if (val != null) setDialogState(() => selectedMode = val);
                        },
                      ),
                      const SizedBox(height: 12),

                      // Reference Number
                      TextFormField(
                        controller: refController,
                        decoration: const InputDecoration(
                          labelText: 'Reference / UTR / Cheque No.',
                          hintText: 'e.g. UTR123456789',
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Bank Name
                      TextFormField(
                        controller: bankController,
                        decoration: const InputDecoration(
                          labelText: 'Bank Name',
                          hintText: 'e.g. State Bank of India',
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Notes
                      TextFormField(
                        controller: notesController,
                        decoration: const InputDecoration(labelText: 'Notes / Remarks'),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSubmitting ? null : () => Navigator.pop(dialogCtx),
                  child: const Text('Cancel'),
                ),
                FilledButton.icon(
                  style: FilledButton.styleFrom(backgroundColor: const Color(0xFF16A34A)),
                  icon: isSubmitting
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.check),
                  label: Text(isSubmitting ? 'Recording...' : 'Record Payment'),
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          final amt = double.tryParse(amountController.text.trim());
                          if (amt == null || amt <= 0) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Please enter a valid amount greater than ₹0.')),
                            );
                            return;
                          }
                          if (amt > pending + 0.01) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Amount cannot exceed pending balance of ₹${_currencyFormat.format(pending)}')),
                            );
                            return;
                          }

                          setDialogState(() => isSubmitting = true);
                          try {
                            await CommissionService.recordCommissionPayment(
                              commission: comm,
                              paymentAmount: amt,
                              paymentMode: selectedMode,
                              referenceNumber: refController.text.trim().isNotEmpty ? refController.text.trim() : null,
                              bankName: bankController.text.trim().isNotEmpty ? bankController.text.trim() : null,
                              notes: notesController.text.trim().isNotEmpty ? notesController.text.trim() : null,
                            );

                            if (mounted) {
                              Navigator.pop(dialogCtx);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Commission payment recorded successfully!'), backgroundColor: Color(0xFF16A34A)),
                              );
                              _loadData();
                            }
                          } catch (e) {
                            setDialogState(() => isSubmitting = false);
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Payment failed: $e'), backgroundColor: Colors.red),
                              );
                            }
                          }
                        },
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Edit Commission Record (Updates existing, never creates duplicate)
  // ---------------------------------------------------------------------------

  void _openEditDialog(CommissionRecord comm) {
    String agentName = comm.agentName;
    String customerName = comm.customerName;
    String consumerNo = comm.consumerNo ?? '';
    double? capacity = comm.solarCapacity;
    DateTime date = comm.commissionDate;
    double amount = comm.commissionAmount;
    String remarks = comm.remarks ?? '';

    final customerCtrl = TextEditingController(text: customerName);
    final consumerCtrl = TextEditingController(text: consumerNo);
    final capacityCtrl = TextEditingController(text: capacity != null ? capacity.toString() : '');
    final amountCtrl = TextEditingController(text: amount.toString());
    final remarksCtrl = TextEditingController(text: remarks);

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(builder: (c, setLocalState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Text('Edit Commission (${comm.entryNumber})'),
            content: SizedBox(
              width: 480,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      value: agentName,
                      decoration: const InputDecoration(labelText: 'Agent Name *'),
                      items: _agents.map((a) => DropdownMenuItem(value: a.name, child: Text(a.name))).toList(),
                      onChanged: (v) {
                        if (v != null) setLocalState(() => agentName = v);
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(controller: customerCtrl, decoration: const InputDecoration(labelText: 'Customer Name *')),
                    const SizedBox(height: 12),
                    TextField(controller: consumerCtrl, decoration: const InputDecoration(labelText: 'Consumer Number')),
                    const SizedBox(height: 12),
                    TextField(controller: capacityCtrl, decoration: const InputDecoration(labelText: 'Solar Capacity (kW)')),
                    const SizedBox(height: 12),
                    TextField(controller: amountCtrl, decoration: const InputDecoration(labelText: 'Commission Amount (₹) *', prefixText: '₹ ')),
                    const SizedBox(height: 12),
                    TextField(controller: remarksCtrl, decoration: const InputDecoration(labelText: 'Remarks')),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              FilledButton(
                onPressed: () async {
                  final newAmt = double.tryParse(amountCtrl.text.trim()) ?? amount;
                  final updated = comm.copyWith(
                    agentName: agentName,
                    customerName: customerCtrl.text.trim(),
                    consumerNo: consumerCtrl.text.trim().isNotEmpty ? consumerCtrl.text.trim() : null,
                    solarCapacity: double.tryParse(capacityCtrl.text.trim()),
                    commissionAmount: newAmt,
                    remarks: remarksCtrl.text.trim(),
                  );

                  final ok = await CommissionService.updateCommissionRecord(updated);
                  if (ok && mounted) {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Commission entry updated successfully!')),
                    );
                    _loadData();
                  }
                },
                child: const Text('Save Changes'),
              ),
            ],
          );
        });
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Export Report
  // ---------------------------------------------------------------------------

  Future<void> _handleExportReport() async {
    if (_filteredCommissions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No records to export.')),
      );
      return;
    }

    final csvContent = CommissionService.exportCommissionsToCsv(_filteredCommissions);
    final fileName = 'siya_commission_report_${DateFormat("yyyyMMdd_HHmm").format(DateTime.now())}.csv';

    final ok = await FileDownloadUtils.downloadCsv(fileName: fileName, csvContent: csvContent);
    if (ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Report exported: $fileName'), backgroundColor: const Color(0xFF16A34A)),
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Payment History Dialog
  // ---------------------------------------------------------------------------

  Future<void> _showPaymentHistory(CommissionRecord comm) async {
    final payments = await CommissionService.fetchPaymentsForCommission(comm.id);

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Payment History (${comm.entryNumber})'),
        content: SizedBox(
          width: 500,
          child: payments.isEmpty
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: Text('No actual payments recorded for this commission entry yet.')),
                )
              : ListView.separated(
                  shrinkWrap: true,
                  itemCount: payments.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final p = payments[i];
                    return ListTile(
                      leading: const Icon(Icons.check_circle, color: Colors.green),
                      title: Text('₹${_currencyFormat.format(p.amount)} via ${p.paymentMode}', style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text('Date: ${_dateFormat.format(p.paymentDate)}${p.referenceNumber != null ? " • Ref: ${p.referenceNumber}" : ""}${p.bankName != null ? " • Bank: ${p.bankName}" : ""}'),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Build Main Screen UI
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDesktop = MediaQuery.of(context).size.width >= 900;

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: Column(
        children: [
          // 1. Module Top Bar
          _buildTopBar(theme, isDesktop),

          // 2. Metrics Summary Cards
          _buildMetricsSection(theme),

          // 3. Search & Filter Bar
          _buildFilterBar(theme, isDesktop),

          // 4. Commission Records List (Desktop Table or Mobile Cards)
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredCommissions.isEmpty
                    ? _buildEmptyState()
                    : isDesktop
                        ? _buildDesktopDataTable(theme)
                        : _buildMobileList(theme),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Top Action Bar
  // ---------------------------------------------------------------------------

  Widget _buildTopBar(ThemeData theme, bool isDesktop) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(bottom: BorderSide(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5))),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Commission Agent Module (एजंट कमिशन विभाग)',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Text(
                  'Manage agent records, manual bulk entries, approvals, and payout tracking',
                  style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          Wrap(
            spacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              OutlinedButton.icon(
                icon: const Icon(Icons.people_outline, size: 18),
                label: const Text('Agent Master'),
                onPressed: () => AgentMasterDialog.show(context, onAgentListChanged: _loadData),
              ),
              OutlinedButton.icon(
                icon: const Icon(Icons.file_download_outlined, size: 18),
                label: const Text('Export Report'),
                onPressed: _handleExportReport,
              ),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFF57C00),
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                ),
                icon: const Icon(Icons.post_add_rounded, size: 18),
                label: const Text('Bulk Add Commission', style: TextStyle(fontWeight: FontWeight.bold)),
                onPressed: () => BulkCommissionEntryScreen.show(context, onEntriesSaved: _loadData),
              ),
              IconButton(
                icon: const Icon(Icons.refresh),
                tooltip: 'Refresh',
                onPressed: _loadData,
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Metrics Section
  // ---------------------------------------------------------------------------

  Widget _buildMetricsSection(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        border: Border(bottom: BorderSide(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4))),
      ),
      child: LayoutBuilder(builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 750;
        final items = [
          _buildMetricCard('Total Commission', '₹${_currencyFormat.format(_totalCommission)}', Icons.monetization_on_outlined, const Color(0xFFF57C00)),
          _buildMetricCard('Pending Approval', '$_pendingApprovalCount records', Icons.hourglass_top_rounded, Colors.amber.shade900),
          _buildMetricCard('Approved Payouts', '₹${_currencyFormat.format(_totalApproved)}', Icons.verified_outlined, const Color(0xFF0284C7)),
          _buildMetricCard('Total Paid Out', '₹${_currencyFormat.format(_totalPaid)}', Icons.check_circle_outline, const Color(0xFF16A34A)),
          _buildMetricCard('Pending Payout', '₹${_currencyFormat.format(_totalPendingPayout)}', Icons.pending_actions_outlined, Colors.deepOrange),
        ];

        if (isNarrow) {
          return Wrap(
            spacing: 8,
            runSpacing: 8,
            children: items.map((w) => SizedBox(width: (constraints.maxWidth - 20) / 2, child: w)).toList(),
          );
        }

        return Row(
          children: items.map((w) => Expanded(child: w)).toList(),
        );
      }),
    );
  }

  Widget _buildMetricCard(String label, String value, IconData icon, Color color) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  value,
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: color),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(label, style: const TextStyle(fontSize: 10, color: Colors.black54)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Filter Bar
  // ---------------------------------------------------------------------------

  Widget _buildFilterBar(ThemeData theme, bool isDesktop) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(bottom: BorderSide(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4))),
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Search input
              Expanded(
                flex: 3,
                child: SizedBox(
                  height: 38,
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.search, size: 20),
                      hintText: 'Search by agent, customer, consumer no, or entry number...',
                      hintStyle: const TextStyle(fontSize: 12),
                      contentPadding: EdgeInsets.zero,
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 16),
                              onPressed: () {
                                _searchController.clear();
                                _applyFilters();
                              },
                            )
                          : null,
                    ),
                    onChanged: (_) => _applyFilters(),
                  ),
                ),
              ),
              const SizedBox(width: 10),

              // Agent Dropdown Filter
              SizedBox(
                width: 180,
                height: 38,
                child: DropdownButtonFormField<String>(
                  value: _selectedAgent,
                  decoration: const InputDecoration(
                    contentPadding: EdgeInsets.symmetric(horizontal: 10),
                    isDense: true,
                  ),
                  items: [
                    const DropdownMenuItem(value: 'All', child: Text('All Agents', style: TextStyle(fontSize: 12))),
                    ..._agents.map((a) => DropdownMenuItem(value: a.name, child: Text(a.name, style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis))),
                  ],
                  onChanged: (v) {
                    setState(() {
                      _selectedAgent = v;
                      _applyFilters();
                    });
                  },
                ),
              ),
              const SizedBox(width: 10),

              // Date Range Filter Button
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                icon: const Icon(Icons.calendar_today, size: 16),
                label: Text(
                  _selectedDateRange == null
                      ? 'Date Filter'
                      : '${DateFormat("dd/MM").format(_selectedDateRange!.start)} - ${DateFormat("dd/MM").format(_selectedDateRange!.end)}',
                  style: const TextStyle(fontSize: 12),
                ),
                onPressed: () async {
                  final picked = await showDateRangePicker(
                    context: context,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2035),
                    initialDateRange: _selectedDateRange,
                  );
                  if (picked != null) {
                    setState(() {
                      _selectedDateRange = picked;
                      _applyFilters();
                    });
                  } else if (_selectedDateRange != null) {
                    setState(() {
                      _selectedDateRange = null;
                      _applyFilters();
                    });
                  }
                },
              ),

              if (_selectedCommissionIds.isNotEmpty) ...[
                const SizedBox(width: 10),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF16A34A),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  icon: const Icon(Icons.check_circle_outline, size: 16),
                  label: Text('Bulk Approve (${_selectedCommissionIds.length})', style: const TextStyle(fontSize: 12)),
                  onPressed: _handleBulkApproval,
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),

          // Status Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: CommissionStatus.allStatuses.map((st) {
                final isSelected = _selectedStatus == st;
                final count = st == 'All'
                    ? _allCommissions.length
                    : _allCommissions.where((c) => c.status == st).length;

                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    selected: isSelected,
                    label: Text('$st ($count)'),
                    labelStyle: TextStyle(
                      fontSize: 11,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      color: isSelected ? Colors.white : Colors.black87,
                    ),
                    selectedColor: const Color(0xFFF57C00),
                    checkmarkColor: Colors.white,
                    onSelected: (_) {
                      setState(() {
                        _selectedStatus = st;
                        _applyFilters();
                      });
                    },
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Desktop Data Table
  // ---------------------------------------------------------------------------

  Widget _buildDesktopDataTable(ThemeData theme) {
    return Scrollbar(
      thumbVisibility: true,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: DataTable(
            horizontalMargin: 12,
            columnSpacing: 16,
            headingRowHeight: 44,
            dataRowMinHeight: 52,
            dataRowMaxHeight: 56,
            headingRowColor: WidgetStateProperty.all(theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.6)),
            columns: const [
              DataColumn(label: Text('# Entry No', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
              DataColumn(label: Text('Agent Name', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
              DataColumn(label: Text('Customer & Consumer No', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
              DataColumn(label: Text('Date', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
              DataColumn(label: Text('Commission (₹)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
              DataColumn(label: Text('Approved (₹)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
              DataColumn(label: Text('Paid (₹)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
              DataColumn(label: Text('Pending (₹)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFFEA580C)))),
              DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
              DataColumn(label: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
            ],
            rows: _filteredCommissions.map((comm) {
              final isPendingApproval = comm.isPendingApproval;
              final isSelected = _selectedCommissionIds.contains(comm.id);

              return DataRow(
                selected: isSelected,
                onSelectChanged: isPendingApproval
                    ? (sel) {
                        setState(() {
                          if (sel == true) {
                            _selectedCommissionIds.add(comm.id);
                          } else {
                            _selectedCommissionIds.remove(comm.id);
                          }
                        });
                      }
                    : null,
                cells: [
                  // 1. Entry No
                  DataCell(
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(comm.entryNumber, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                        if (comm.solarCapacity != null)
                          Text('${comm.solarCapacity} kW', style: const TextStyle(fontSize: 10, color: Colors.black54)),
                      ],
                    ),
                  ),

                  // 2. Agent Name
                  DataCell(Text(comm.agentName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12))),

                  // 3. Customer & Consumer No
                  DataCell(
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(comm.customerName, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                        Text(comm.consumerNo ?? 'No Consumer No', style: const TextStyle(fontSize: 10, color: Colors.black54)),
                      ],
                    ),
                  ),

                  // 4. Commission Date
                  DataCell(Text(DateFormat('dd/MM/yyyy').format(comm.commissionDate), style: const TextStyle(fontSize: 12))),

                  // 5. Commission Amount (₹)
                  DataCell(Text('₹${_currencyFormat.format(comm.commissionAmount)}', style: const TextStyle(fontSize: 12))),

                  // 6. Approved (₹)
                  DataCell(
                    Text(
                      comm.approvedAmount != null ? '₹${_currencyFormat.format(comm.approvedAmount!)}' : '-',
                      style: const TextStyle(fontSize: 12, color: Color(0xFF0284C7)),
                    ),
                  ),

                  // 7. Paid (₹)
                  DataCell(
                    InkWell(
                      onTap: comm.paidAmount > 0 ? () => _showPaymentHistory(comm) : null,
                      child: Text(
                        '₹${_currencyFormat.format(comm.paidAmount)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: comm.paidAmount > 0 ? Colors.green.shade800 : Colors.black54,
                          decoration: comm.paidAmount > 0 ? TextDecoration.underline : TextDecoration.none,
                        ),
                      ),
                    ),
                  ),

                  // 8. Pending Amount (₹)
                  DataCell(
                    Text(
                      '₹${_currencyFormat.format(comm.pendingAmount)}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: comm.pendingAmount > 0 ? const Color(0xFFEA580C) : Colors.grey,
                      ),
                    ),
                  ),

                  // 9. Status Badge
                  DataCell(
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: CommissionStatus.getStatusColor(comm.status).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: CommissionStatus.getStatusColor(comm.status).withValues(alpha: 0.3)),
                      ),
                      child: Text(
                        comm.status,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: CommissionStatus.getStatusColor(comm.status),
                        ),
                      ),
                    ),
                  ),

                  // 10. Actions
                  DataCell(
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (comm.isPendingApproval)
                          IconButton(
                            icon: const Icon(Icons.check_circle_outline, color: Color(0xFF16A34A), size: 20),
                            tooltip: 'Approve Commission',
                            onPressed: () => _handleApproveIndividual(comm),
                          ),
                        if (comm.isApproved && comm.pendingAmount > 0.01)
                          IconButton(
                            icon: const Icon(Icons.payments_outlined, color: Color(0xFF0284C7), size: 20),
                            tooltip: 'Record Payment',
                            onPressed: () => _openRecordPaymentDialog(comm),
                          ),
                        IconButton(
                          icon: const Icon(Icons.edit_outlined, size: 18),
                          tooltip: 'Edit Entry',
                          onPressed: () => _openEditDialog(comm),
                        ),
                        if (comm.paidAmount > 0)
                          IconButton(
                            icon: const Icon(Icons.history, size: 18),
                            tooltip: 'Payment History',
                            onPressed: () => _showPaymentHistory(comm),
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

  // ---------------------------------------------------------------------------
  // Mobile Card List
  // ---------------------------------------------------------------------------

  Widget _buildMobileList(ThemeData theme) {
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _filteredCommissions.length,
      itemBuilder: (context, index) {
        final comm = _filteredCommissions[index];
        final statusColor = CommissionStatus.getStatusColor(comm.status);

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: statusColor.withValues(alpha: 0.4), width: 1.5),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(comm.entryNumber, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        comm.status,
                        style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 10),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text('Agent: ${comm.agentName}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                Text('Customer: ${comm.customerName} (${comm.consumerNo ?? "N/A"})', style: const TextStyle(fontSize: 12)),
                const Divider(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Commission Amount', style: TextStyle(fontSize: 10, color: Colors.black54)),
                        Text('₹${_currencyFormat.format(comm.commissionAmount)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Paid Out', style: TextStyle(fontSize: 10, color: Colors.black54)),
                        Text('₹${_currencyFormat.format(comm.paidAmount)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.green)),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Text('Pending Balance', style: TextStyle(fontSize: 10, color: Colors.black54)),
                        Text(
                          '₹${_currencyFormat.format(comm.pendingAmount)}',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFFEA580C)),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (comm.isPendingApproval)
                      FilledButton.tonal(
                        onPressed: () => _handleApproveIndividual(comm),
                        child: const Text('Approve'),
                      ),
                    const SizedBox(width: 8),
                    if (comm.isApproved && comm.pendingAmount > 0.01)
                      FilledButton(
                        style: FilledButton.styleFrom(backgroundColor: const Color(0xFF16A34A)),
                        onPressed: () => _openRecordPaymentDialog(comm),
                        child: const Text('Record Payment'),
                      ),
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, size: 20),
                      onPressed: () => _openEditDialog(comm),
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

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.monetization_on_outlined, size: 56, color: Colors.grey.shade400),
          const SizedBox(height: 14),
          const Text(
            'No commission entries found matching your filters.',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),
          const SizedBox(height: 6),
          const Text('Click "Bulk Add Commission" to add entries for agents and customers.'),
          const SizedBox(height: 16),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFF57C00)),
            icon: const Icon(Icons.post_add_rounded),
            label: const Text('Bulk Add Commission'),
            onPressed: () => BulkCommissionEntryScreen.show(context, onEntriesSaved: _loadData),
          ),
        ],
      ),
    );
  }
}
