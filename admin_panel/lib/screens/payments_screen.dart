import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/customer_payment.dart';
import '../services/payment_service.dart';
import '../services/supabase_service.dart';

class PaymentsScreen extends StatefulWidget {
  const PaymentsScreen({super.key});

  @override
  State<PaymentsScreen> createState() => _PaymentsScreenState();
}

class _PaymentsScreenState extends State<PaymentsScreen> {
  bool _isLoading = true;
  bool _isLoadingMetrics = true;
  AdminPaymentMetrics _metrics = AdminPaymentMetrics.empty();
  List<PaymentTransaction> _payments = [];

  // Filter controllers
  final TextEditingController _searchController = TextEditingController();
  String _selectedDateFilter = 'All';
  String _selectedPaymentType = 'All';
  String _selectedPaymentMode = 'All';
  String _selectedVerification = 'All';
  String _selectedSyncStatus = 'All';

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    await Future.wait([
      _loadMetrics(),
      _loadPayments(),
    ]);
  }

  Future<void> _loadMetrics() async {
    setState(() => _isLoadingMetrics = true);
    final m = await AdminPaymentService.fetchDashboardMetrics();
    if (mounted) {
      setState(() {
        _metrics = m;
        _isLoadingMetrics = false;
      });
    }
  }

  Future<void> _loadPayments() async {
    setState(() => _isLoading = true);
    final list = await AdminPaymentService.fetchPayments(
      searchQuery: _searchController.text,
      dateFilter: _selectedDateFilter,
      paymentType: _selectedPaymentType,
      paymentMode: _selectedPaymentMode,
      verificationStatus: _selectedVerification,
      syncStatus: _selectedSyncStatus,
    );
    if (mounted) {
      setState(() {
        _payments = list;
        _isLoading = false;
      });
    }
  }

  void _onSearchChanged(String val) {
    _loadPayments();
  }

  // ===========================================================================
  // ACTION HANDLERS
  // ===========================================================================

  Future<void> _handleVerify(PaymentTransaction tx) async {
    final user = SupabaseService.currentUser;
    final adminId = user?.id ?? 'admin-uuid';
    final adminName = user?.email?.split('@').first ?? 'Admin';

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.check_circle_outline, color: Color(0xFF059669)),
            SizedBox(width: 8),
            Text('Verify Payment'),
          ],
        ),
        content: Text(
          'Confirm verification for ₹${NumberFormat('#,##,###').format(tx.amount)} from ${tx.customerName ?? tx.consumerNo}?\nReference: ${tx.referenceNumber ?? 'N/A'}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFF059669)),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Verify Payment'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final success = await AdminPaymentService.verifyPayment(
        paymentId: tx.id!,
        adminId: adminId,
        adminName: adminName,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success ? 'Payment verified successfully.' : 'Failed to verify payment.'),
            backgroundColor: success ? const Color(0xFF059669) : Colors.red,
          ),
        );
        _loadAll();
      }
    }
  }

  Future<void> _handleReject(PaymentTransaction tx) async {
    final user = SupabaseService.currentUser;
    final adminId = user?.id ?? 'admin-uuid';
    final adminName = user?.email?.split('@').first ?? 'Admin';
    final reasonCtrl = TextEditingController();

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.cancel_outlined, color: Colors.red),
            SizedBox(width: 8),
            Text('Reject Payment'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Enter mandatory rejection reason for payment of ₹${NumberFormat('#,##,###').format(tx.amount)}:'),
            const SizedBox(height: 12),
            TextField(
              controller: reasonCtrl,
              autofocus: true,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'e.g., UTR not matching bank statement / Invalid cheque',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              if (reasonCtrl.text.trim().isEmpty) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(content: Text('Rejection reason is mandatory.')),
                );
                return;
              }
              Navigator.of(ctx).pop(true);
            },
            child: const Text('Confirm Rejection'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final success = await AdminPaymentService.rejectPayment(
        paymentId: tx.id!,
        adminId: adminId,
        adminName: adminName,
        reason: reasonCtrl.text.trim(),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success ? 'Payment rejected.' : 'Failed to reject payment.'),
            backgroundColor: success ? Colors.orange.shade800 : Colors.red,
          ),
        );
        _loadAll();
      }
    }
  }

  Future<void> _handleVoid(PaymentTransaction tx) async {
    final user = SupabaseService.currentUser;
    final adminId = user?.id ?? 'admin-uuid';
    final adminName = user?.email?.split('@').first ?? 'Admin';
    final reasonCtrl = TextEditingController();

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.block_rounded, color: Colors.blueGrey),
            SizedBox(width: 8),
            Text('Void Payment (Non-destructive)'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '⚠️ Financial Record Preservation:\nThis transaction will be marked as Void in the ledger without permanently deleting the audit trail.',
              style: TextStyle(fontSize: 13, color: Colors.blueGrey, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            Text('Enter mandatory reason for voiding ₹${NumberFormat('#,##,###').format(tx.amount)}:'),
            const SizedBox(height: 8),
            TextField(
              controller: reasonCtrl,
              autofocus: true,
              maxLines: 2,
              decoration: const InputDecoration(
                hintText: 'e.g., Duplicate entry made by staff / Bounced cheque',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.blueGrey.shade800),
            onPressed: () {
              if (reasonCtrl.text.trim().isEmpty) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(content: Text('Reason is mandatory to void transaction.')),
                );
                return;
              }
              Navigator.of(ctx).pop(true);
            },
            child: const Text('Mark Void'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final success = await AdminPaymentService.voidPayment(
        paymentId: tx.id!,
        adminId: adminId,
        adminName: adminName,
        reason: reasonCtrl.text.trim(),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success ? 'Payment voided and preserved in ledger.' : 'Failed to void payment.'),
            backgroundColor: Colors.blueGrey,
          ),
        );
        _loadAll();
      }
    }
  }

  Future<void> _handleEdit(PaymentTransaction tx) async {
    final user = SupabaseService.currentUser;
    final adminId = user?.id ?? 'admin-uuid';
    final adminName = user?.email?.split('@').first ?? 'Admin';

    final amtCtrl = TextEditingController(text: tx.amount.toStringAsFixed(2));
    final refCtrl = TextEditingController(text: tx.referenceNumber ?? '');
    final remarksCtrl = TextEditingController(text: tx.remarks ?? '');
    final reasonCtrl = TextEditingController();
    String selectedMode = tx.paymentMode;
    String selectedType = tx.paymentType;

    final updated = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDState) => AlertDialog(
          title: const Text('Edit Authorized Payment Fields'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: amtCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Amount (₹)', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: selectedType,
                  decoration: const InputDecoration(labelText: 'Payment Type', border: OutlineInputBorder()),
                  items: PaymentType.allTypes.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                  onChanged: (v) => setDState(() => selectedType = v!),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: selectedMode,
                  decoration: const InputDecoration(labelText: 'Payment Mode', border: OutlineInputBorder()),
                  items: PaymentMode.allModes.map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
                  onChanged: (v) => setDState(() => selectedMode = v!),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: refCtrl,
                  decoration: const InputDecoration(labelText: 'Reference Number / UTR', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: remarksCtrl,
                  decoration: const InputDecoration(labelText: 'Remarks', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: Colors.amber.shade50, borderRadius: BorderRadius.circular(8)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Mandatory Edit Reason (Audit Trail)*', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                      const SizedBox(height: 4),
                      TextField(
                        controller: reasonCtrl,
                        decoration: const InputDecoration(
                          hintText: 'Explain why this payment is being altered',
                          isDense: true,
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
            FilledButton(
              onPressed: () {
                if (reasonCtrl.text.trim().isEmpty) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(content: Text('Audit reason is required for editing payment records.')),
                  );
                  return;
                }
                Navigator.of(ctx).pop(true);
              },
              child: const Text('Save Changes'),
            ),
          ],
        ),
      ),
    );

    if (updated == true) {
      final newAmt = double.tryParse(amtCtrl.text.trim()) ?? tx.amount;
      final updates = {
        'amount': newAmt,
        'payment_type': selectedType,
        'payment_mode': selectedMode,
        'reference_number': refCtrl.text.trim().isEmpty ? null : refCtrl.text.trim(),
        'remarks': remarksCtrl.text.trim().isEmpty ? null : remarksCtrl.text.trim(),
      };

      final ok = await AdminPaymentService.updatePayment(
        oldPayment: tx,
        updates: updates,
        reason: reasonCtrl.text.trim(),
        adminId: adminId,
        adminName: adminName,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ok ? 'Payment updated with audit record.' : 'Failed to update payment.')),
        );
        _loadAll();
      }
    }
  }

  void _showReceiptDialog(PaymentTransaction tx) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: 520,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF059669).withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.receipt_long_rounded, color: Color(0xFF059669), size: 28),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'SIYA INFOTECH & SOLAR ENERGY',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                        Text(
                          'Official Payment Acknowledgement Receipt',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const Divider(height: 28),

              // Details
              _receiptRow('Receipt Ref #', tx.id ?? 'N/A'),
              _receiptRow('Customer Name', tx.customerName ?? 'N/A'),
              _receiptRow('Consumer Number', tx.consumerNo),
              _receiptRow('Village', tx.village ?? '-'),
              _receiptRow('Payment Date', DateFormat('dd MMM yyyy').format(tx.paymentDate)),
              _receiptRow('Payment Mode', '${tx.paymentMode} (${tx.paymentType})'),
              if (tx.referenceNumber != null && tx.referenceNumber!.isNotEmpty)
                _receiptRow('UTR / Ref No', tx.referenceNumber!),
              _receiptRow('Collected By', tx.createdByName ?? tx.receivedBy ?? 'Staff'),
              _receiptRow('Verification', tx.verificationStatus),
              const Divider(height: 24),

              // Amount Highlight Box
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFA7F3D0)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Amount Received:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF065F46))),
                    Text(
                      '₹${NumberFormat('#,##,###').format(tx.amount)}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: Color(0xFF059669)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Actions
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: const Text('Close'),
                  ),
                  const SizedBox(width: 8),
                  if (tx.mobileNumber != null && tx.mobileNumber!.isNotEmpty)
                    FilledButton.icon(
                      icon: const Icon(Icons.share, size: 16),
                      label: const Text('WhatsApp Receipt'),
                      style: FilledButton.styleFrom(backgroundColor: const Color(0xFF25D366)),
                      onPressed: () {
                        final phone = tx.mobileNumber!.replaceAll(RegExp(r'\D'), '');
                        final msg = Uri.encodeComponent(
                          'Dear ${tx.customerName ?? "Customer"},\nWe have received payment of ₹${NumberFormat("#,##,###").format(tx.amount)} via ${tx.paymentMode} on ${DateFormat("dd-MM-yyyy").format(tx.paymentDate)} for Consumer No: ${tx.consumerNo}.\nReference: ${tx.referenceNumber ?? "N/A"}.\nStatus: ${tx.verificationStatus}.\nThank you,\nSiya Solar Connect',
                        );
                        launchUrl(Uri.parse('https://wa.me/91$phone?text=$msg'), mode: LaunchMode.externalApplication);
                      },
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _receiptRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        ],
      ),
    );
  }

  void _showProofDialog(PaymentTransaction tx) {
    if (tx.attachmentUrl == null || tx.attachmentUrl!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No payment proof image attached for this transaction.')),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 600, maxHeight: 600),
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Payment Proof Document', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  IconButton(onPressed: () => Navigator.of(ctx).pop(), icon: const Icon(Icons.close)),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: Image.network(
                  tx.attachmentUrl!,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const Center(
                    child: Text('Could not load proof image or format is unsupported.'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showCustomerProfile(PaymentTransaction tx) async {
    final data = await AdminPaymentService.fetchCustomerPaymentProfile(tx.customerId);
    if (data == null || !mounted) return;

    final cust = data['customer'] as Map<String, dynamic>;
    final summary = data['summary'] as CustomerPaymentSummary;
    final txList = data['transactions'] as List<PaymentTransaction>;

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: 750,
          constraints: const BoxConstraints(maxHeight: 650),
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(cust['customer_name'] ?? 'Customer', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      Text('Consumer: ${cust['consumer_no']} • Village: ${cust['village'] ?? "-"} • Stage: ${cust['current_stage'] ?? "-"}',
                          style: const TextStyle(fontSize: 12, color: Colors.grey)),
                    ],
                  ),
                  IconButton(onPressed: () => Navigator.of(ctx).pop(), icon: const Icon(Icons.close)),
                ],
              ),
              const Divider(height: 24),

              // KPI Row
              Row(
                children: [
                  _profileKpi('Contract Amount', '₹${NumberFormat('#,##,###').format(summary.totalAmount)}', Colors.blueGrey),
                  _profileKpi('Total Paid', '₹${NumberFormat('#,##,###').format(summary.paidAmount)}', const Color(0xFF059669)),
                  _profileKpi('Online Paid', '₹${NumberFormat('#,##,###').format(summary.onlinePaidAmount)}', Colors.blue.shade700),
                  _profileKpi('Offline Paid', '₹${NumberFormat('#,##,###').format(summary.offlinePaidAmount)}', Colors.orange.shade800),
                  _profileKpi('Pending Balance', '₹${NumberFormat('#,##,###').format(summary.pendingAmount)}', Colors.red.shade700),
                ],
              ),
              const SizedBox(height: 16),

              const Text('Payment History Ledger', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 8),

              Expanded(
                child: ListView.separated(
                  itemCount: txList.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (ctx, i) {
                    final t = txList[i];
                    return ListTile(
                      dense: true,
                      leading: Icon(PaymentMode.getModeIcon(t.paymentMode), color: const Color(0xFF059669)),
                      title: Text('₹${NumberFormat('#,##,###').format(t.amount)} via ${t.paymentMode}'),
                      subtitle: Text('${DateFormat('dd MMM yyyy').format(t.paymentDate)} • Ref: ${t.referenceNumber ?? "N/A"}'),
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: PaymentVerificationStatus.badgeColor(t.verificationStatus).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          t.verificationStatus,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: PaymentVerificationStatus.badgeColor(t.verificationStatus),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _profileKpi(String label, String value, Color color) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color)),
            const SizedBox(height: 4),
            Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color)),
          ],
        ),
      ),
    );
  }

  void _exportCsv() {
    final csv = AdminPaymentService.generatePaymentsCsv(_payments);
    // Open in new tab or trigger download via data URI
    final bytes = Uri.encodeComponent(csv);
    launchUrl(Uri.parse('data:text/csv;charset=utf-8,$bytes'));
  }

  // ===========================================================================
  // BUILD METHOD
  // ===========================================================================

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: Column(
        children: [
          // 1. TOP HEADER & METRICS
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Payments & Financial Management', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 2),
                    Text('Central ledger, verification, and audit trail', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                  ],
                ),
                Row(
                  children: [
                    OutlinedButton.icon(
                      icon: const Icon(Icons.file_download_outlined, size: 18),
                      label: const Text('Export CSV'),
                      onPressed: _payments.isEmpty ? null : _exportCsv,
                    ),
                    const SizedBox(width: 10),
                    IconButton(
                      icon: const Icon(Icons.refresh),
                      tooltip: 'Refresh Ledger',
                      onPressed: _loadAll,
                    ),
                  ],
                ),
              ],
            ),
          ),

          // 2. DASHBOARD KPI METRIC CARDS
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: _isLoadingMetrics
                ? const LinearProgressIndicator()
                : LayoutBuilder(
                    builder: (context, constraints) {
                      return Row(
                        children: [
                          _buildMetricCard('Total Collection', '₹${NumberFormat('#,##,###').format(_metrics.totalCollection)}', const Color(0xFF059669), Icons.account_balance_wallet_rounded),
                          const SizedBox(width: 10),
                          _buildMetricCard("Today's Collection", '₹${NumberFormat('#,##,###').format(_metrics.todayCollection)}', const Color(0xFF0284C7), Icons.today_rounded),
                          const SizedBox(width: 10),
                          _buildMetricCard('This Month', '₹${NumberFormat('#,##,###').format(_metrics.monthCollection)}', const Color(0xFF7C3AED), Icons.calendar_month_rounded),
                          const SizedBox(width: 10),
                          _buildMetricCard('Total Outstanding', '₹${NumberFormat('#,##,###').format(_metrics.totalOutstanding)}', const Color(0xFFDC2626), Icons.pending_actions_rounded),
                          const SizedBox(width: 10),
                          _buildMetricCard('Pending Verification', '${_metrics.pendingVerificationCount}', const Color(0xFFD97706), Icons.verified_user_outlined),
                          const SizedBox(width: 10),
                          _buildMetricCard('Pending Sync', '${_metrics.pendingSyncCount}', const Color(0xFFEA580C), Icons.sync_problem_rounded),
                        ],
                      );
                    },
                  ),
          ),
          const SizedBox(height: 16),

          // 3. SEARCH & FILTERS BAR
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Row(
                children: [
                  // Search Box
                  Expanded(
                    flex: 3,
                    child: TextField(
                      controller: _searchController,
                      onChanged: _onSearchChanged,
                      decoration: const InputDecoration(
                        hintText: 'Search customer, consumer no, mobile, UTR, ID...',
                        prefixIcon: Icon(Icons.search, size: 20),
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Date Filter
                  _buildDropdownFilter(
                    label: 'Date',
                    value: _selectedDateFilter,
                    items: const ['All', 'Today', 'This Week', 'This Month'],
                    onChanged: (v) {
                      setState(() => _selectedDateFilter = v!);
                      _loadPayments();
                    },
                  ),
                  const SizedBox(width: 10),

                  // Payment Type
                  _buildDropdownFilter(
                    label: 'Type',
                    value: _selectedPaymentType,
                    items: const ['All', 'Online', 'Offline'],
                    onChanged: (v) {
                      setState(() => _selectedPaymentType = v!);
                      _loadPayments();
                    },
                  ),
                  const SizedBox(width: 10),

                  // Payment Mode
                  _buildDropdownFilter(
                    label: 'Mode',
                    value: _selectedPaymentMode,
                    items: ['All', ...PaymentMode.allModes],
                    onChanged: (v) {
                      setState(() => _selectedPaymentMode = v!);
                      _loadPayments();
                    },
                  ),
                  const SizedBox(width: 10),

                  // Verification Status
                  _buildDropdownFilter(
                    label: 'Verification',
                    value: _selectedVerification,
                    items: const ['All', 'Pending', 'Verified', 'Rejected', 'Void'],
                    onChanged: (v) {
                      setState(() => _selectedVerification = v!);
                      _loadPayments();
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // 4. DATA TABLE
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _payments.isEmpty
                      ? const Center(child: Text('No payment transactions match the selected criteria.'))
                      : Card(
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(color: Colors.grey.shade300),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: SingleChildScrollView(
                              scrollDirection: Axis.vertical,
                              child: SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: DataTable(
                                  headingRowColor: WidgetStateProperty.all(Colors.grey.shade100),
                                  columnSpacing: 18,
                                  dataRowMaxHeight: 52,
                                  columns: const [
                                    DataColumn(label: Text('Payment ID', style: TextStyle(fontWeight: FontWeight.bold))),
                                    DataColumn(label: Text('Customer', style: TextStyle(fontWeight: FontWeight.bold))),
                                    DataColumn(label: Text('Consumer No', style: TextStyle(fontWeight: FontWeight.bold))),
                                    DataColumn(label: Text('Village', style: TextStyle(fontWeight: FontWeight.bold))),
                                    DataColumn(label: Text('Amount (₹)', style: TextStyle(fontWeight: FontWeight.bold))),
                                    DataColumn(label: Text('Type', style: TextStyle(fontWeight: FontWeight.bold))),
                                    DataColumn(label: Text('Mode', style: TextStyle(fontWeight: FontWeight.bold))),
                                    DataColumn(label: Text('Date', style: TextStyle(fontWeight: FontWeight.bold))),
                                    DataColumn(label: Text('Reference No', style: TextStyle(fontWeight: FontWeight.bold))),
                                    DataColumn(label: Text('Verification', style: TextStyle(fontWeight: FontWeight.bold))),
                                    DataColumn(label: Text('Created By', style: TextStyle(fontWeight: FontWeight.bold))),
                                    DataColumn(label: Text('Sync', style: TextStyle(fontWeight: FontWeight.bold))),
                                    DataColumn(label: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold))),
                                  ],
                                  rows: _payments.map((tx) => _buildDataRow(tx)).toList(),
                                ),
                              ),
                            ),
                          ),
                        ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  DataRow _buildDataRow(PaymentTransaction tx) {
    return DataRow(
      cells: [
        // Payment ID
        DataCell(
          Text(
            tx.id != null && tx.id!.length > 8 ? tx.id!.substring(0, 8) : (tx.id ?? '-'),
            style: const TextStyle(fontSize: 11, fontFamily: 'monospace', fontWeight: FontWeight.bold),
          ),
        ),
        // Customer Name
        DataCell(
          InkWell(
            onTap: () => _showCustomerProfile(tx),
            child: Text(
              tx.customerName ?? 'Unknown',
              style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0284C7)),
            ),
          ),
        ),
        // Consumer No
        DataCell(Text(tx.consumerNo, style: const TextStyle(fontSize: 12))),
        // Village
        DataCell(Text(tx.village ?? '-', style: const TextStyle(fontSize: 12))),
        // Amount
        DataCell(
          Text(
            '₹${NumberFormat('#,##,###').format(tx.amount)}',
            style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF059669)),
          ),
        ),
        // Type
        DataCell(
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: tx.paymentType == 'Online' ? Colors.blue.shade50 : Colors.amber.shade50,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              tx.paymentType,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: tx.paymentType == 'Online' ? Colors.blue.shade800 : Colors.amber.shade900,
              ),
            ),
          ),
        ),
        // Mode
        DataCell(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(PaymentMode.getModeIcon(tx.paymentMode), size: 16, color: Colors.grey.shade700),
              const SizedBox(width: 6),
              Text(tx.paymentMode, style: const TextStyle(fontSize: 12)),
            ],
          ),
        ),
        // Date
        DataCell(Text(DateFormat('dd MMM yyyy').format(tx.paymentDate), style: const TextStyle(fontSize: 12))),
        // Reference No
        DataCell(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(tx.referenceNumber ?? '-', style: const TextStyle(fontSize: 11, fontFamily: 'monospace')),
              if (tx.proofMismatch)
                const Tooltip(
                  message: 'Proof Mismatch Warning',
                  child: Padding(
                    padding: EdgeInsets.only(left: 4),
                    child: Icon(Icons.warning_amber_rounded, size: 14, color: Colors.red),
                  ),
                ),
            ],
          ),
        ),
        // Verification
        DataCell(
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: PaymentVerificationStatus.badgeColor(tx.verificationStatus).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              tx.verificationStatus,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: PaymentVerificationStatus.badgeColor(tx.verificationStatus),
              ),
            ),
          ),
        ),
        // Created By
        DataCell(Text(tx.createdByName ?? tx.createdBy ?? '-', style: const TextStyle(fontSize: 11))),
        // Sync Status
        DataCell(
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: tx.syncStatus == 'Synced' ? Colors.green.shade50 : Colors.orange.shade50,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              tx.syncStatus,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: tx.syncStatus == 'Synced' ? Colors.green.shade800 : Colors.orange.shade900,
              ),
            ),
          ),
        ),
        // Actions
        DataCell(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.receipt_outlined, size: 18),
                tooltip: 'View Receipt',
                onPressed: () => _showReceiptDialog(tx),
              ),
              if (tx.attachmentUrl != null && tx.attachmentUrl!.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.image_outlined, size: 18),
                  tooltip: 'View Proof',
                  onPressed: () => _showProofDialog(tx),
                ),
              if (tx.isPendingVerification) ...[
                IconButton(
                  icon: const Icon(Icons.check_circle_outline, size: 18, color: Color(0xFF059669)),
                  tooltip: 'Verify Payment',
                  onPressed: () => _handleVerify(tx),
                ),
                IconButton(
                  icon: const Icon(Icons.cancel_outlined, size: 18, color: Colors.red),
                  tooltip: 'Reject Payment',
                  onPressed: () => _handleReject(tx),
                ),
              ],
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, size: 18),
                onSelected: (val) {
                  if (val == 'edit') _handleEdit(tx);
                  if (val == 'void') _handleVoid(tx);
                  if (val == 'profile') _showCustomerProfile(tx);
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(value: 'profile', child: Text('Customer Profile')),
                  const PopupMenuItem(value: 'edit', child: Text('Edit Record')),
                  if (!tx.isVoid)
                    const PopupMenuItem(value: 'void', child: Text('Mark Void (Non-destructive)')),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMetricCard(String title, String value, Color color, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: color.withValues(alpha: 0.15), shape: BoxShape.circle),
              child: Icon(icon, size: 20, color: color),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(title, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey.shade700)),
                  const SizedBox(height: 2),
                  Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: color)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDropdownFilter({
    required String label,
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isDense: true,
          items: items.map((i) => DropdownMenuItem(value: i, child: Text(i, style: const TextStyle(fontSize: 12)))).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}
