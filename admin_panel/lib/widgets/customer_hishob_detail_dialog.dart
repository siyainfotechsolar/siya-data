import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/customer_hishob.dart';
import '../models/customer_payment.dart';
import '../models/invoice.dart';
import '../services/customer_hishob_service.dart';
import 'hishob_add_payment_dialog.dart';
import 'invoice_details_dialog.dart';

class CustomerHishobDetailDialog extends StatefulWidget {
  final CustomerHishobEntry entry;
  final VoidCallback onDataChanged;

  const CustomerHishobDetailDialog({
    super.key,
    required this.entry,
    required this.onDataChanged,
  });

  static Future<void> show(
    BuildContext context, {
    required CustomerHishobEntry entry,
    required VoidCallback onDataChanged,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => CustomerHishobDetailDialog(
        entry: entry,
        onDataChanged: onDataChanged,
      ),
    );
  }

  @override
  State<CustomerHishobDetailDialog> createState() => _CustomerHishobDetailDialogState();
}

class _CustomerHishobDetailDialogState extends State<CustomerHishobDetailDialog> {
  final _inr = NumberFormat('#,##,##0', 'en_IN');
  late CustomerHishobEntry _entry;
  bool _isLoading = false;

  String _selectedInvoiceStatusFilter = 'All'; // 'All', 'Paid', 'Partially Paid', 'Unpaid'
  DateTimeRange? _selectedDateRange;

  @override
  void initState() {
    super.initState();
    _entry = widget.entry;
  }

  Future<void> _refreshCustomerData() async {
    setState(() => _isLoading = true);
    try {
      final res = await CustomerHishobService.fetchHishobData(
        searchQuery: _entry.consumerNo,
      );
      if (mounted) {
        final updated = res.entries.firstWhere(
          (e) => e.consumerNo.toUpperCase() == _entry.consumerNo.toUpperCase(),
          orElse: () => _entry,
        );
        setState(() {
          _entry = updated;
          _isLoading = false;
        });
        widget.onDataChanged();
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _openAddPayment({Invoice? targetInvoice, PaymentTransaction? paymentToEdit}) {
    HishobAddPaymentDialog.show(
      context,
      customerEntry: _entry,
      preselectedInvoice: targetInvoice,
      existingPaymentToEdit: paymentToEdit,
      onSaved: _refreshCustomerData,
    );
  }

  Future<void> _confirmDeletePayment(PaymentTransaction payment) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 28),
            const SizedBox(width: 10),
            Text('Delete Payment Record?', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        content: Text(
          'Are you sure you want to delete this payment of ₹${_inr.format(payment.amount)} '
          'recorded on ${DateFormat('dd/MM/yyyy').format(payment.paymentDate)}?\n\n'
          'The customer pending balance will be automatically recalculated.',
          style: GoogleFonts.inter(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: GoogleFonts.inter(color: Colors.grey.shade700)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Delete & Recalculate'),
          ),
        ],
      ),
    );

    if (confirmed == true && payment.id != null) {
      setState(() => _isLoading = true);
      try {
        await CustomerHishobService.deletePayment(payment.id!);
        await _refreshCustomerData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Payment deleted and balances recalculated successfully.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error deleting payment: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  List<InvoiceBalance> get _filteredInvoiceBalances {
    var list = _entry.invoiceBalances;

    // Status filter
    if (_selectedInvoiceStatusFilter != 'All') {
      list = list.where((b) => b.paymentStatus == _selectedInvoiceStatusFilter).toList();
    }

    // Date range filter
    if (_selectedDateRange != null) {
      final start = DateTime(_selectedDateRange!.start.year, _selectedDateRange!.start.month, _selectedDateRange!.start.day);
      final end = DateTime(_selectedDateRange!.end.year, _selectedDateRange!.end.month, _selectedDateRange!.end.day, 23, 59, 59);
      list = list.where((b) => b.invoiceDate.isAfter(start.subtract(const Duration(seconds: 1))) &&
          b.invoiceDate.isBefore(end.add(const Duration(seconds: 1)))).toList();
    }

    return list;
  }

  List<PaymentTransaction> get _filteredPayments {
    var list = _entry.payments.where((p) => p.isValid).toList();

    // Date range filter
    if (_selectedDateRange != null) {
      final start = DateTime(_selectedDateRange!.start.year, _selectedDateRange!.start.month, _selectedDateRange!.start.day);
      final end = DateTime(_selectedDateRange!.end.year, _selectedDateRange!.end.month, _selectedDateRange!.end.day, 23, 59, 59);
      list = list.where((p) => p.paymentDate.isAfter(start.subtract(const Duration(seconds: 1))) &&
          p.paymentDate.isBefore(end.add(const Duration(seconds: 1)))).toList();
    }

    return list;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDesktop = MediaQuery.of(context).size.width >= 768;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 960,
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        child: Column(
          children: [
            // Header Bar
            _buildHeader(theme),

            // Customer Summary Strip
            _buildSummaryStrip(theme, isDesktop),

            // Filter Bar
            _buildFilterBar(),

            const Divider(height: 1),

            // Content Area (Invoices + Payments)
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Invoices Section
                          _buildInvoicesSection(),

                          const SizedBox(height: 28),

                          // Payments History Section
                          _buildPaymentsSection(),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFE0F2FE),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.menu_book_rounded, color: Color(0xFF0284C7), size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Customer Hishob Ledger',
                  style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
                ),
                Text(
                  '${_entry.customerName}  •  Consumer No: ${_entry.consumerNo}',
                  style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF64748B), fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
          ElevatedButton.icon(
            onPressed: () => _openAddPayment(),
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Add Payment'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF059669),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.close_rounded),
            onPressed: () => Navigator.pop(context),
            tooltip: 'Close',
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryStrip(ThemeData theme, bool isDesktop) {
    Color statusBg;
    Color statusColor;
    switch (_entry.paymentStatus) {
      case 'Paid':
        statusBg = const Color(0xFFD1FAE5);
        statusColor = const Color(0xFF065F46);
        break;
      case 'Partially Paid':
        statusBg = const Color(0xFFE0F2FE);
        statusColor = const Color(0xFF0369A1);
        break;
      case 'Unpaid':
      default:
        statusBg = const Color(0xFFFEE2E2);
        statusColor = const Color(0xFF991B1B);
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      color: Colors.white,
      child: Wrap(
        spacing: 24,
        runSpacing: 12,
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          // Total Invoiced
          _buildSummaryItem('Total Invoices', '₹${_inr.format(_entry.totalAmount)}', const Color(0xFF1E293B)),
          // Total Paid
          _buildSummaryItem('Total Paid', '₹${_inr.format(_entry.totalPaid)}', const Color(0xFF059669)),
          // Total Pending
          _buildSummaryItem(
            'Total Pending',
            '₹${_inr.format(_entry.totalPending)}',
            _entry.totalPending > 0 ? const Color(0xFFDC2626) : const Color(0xFF059669),
          ),
          // Status Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: statusBg,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              _entry.paymentStatus,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: statusColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value, Color valueColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B), fontWeight: FontWeight.w500)),
        const SizedBox(height: 2),
        Text(value, style: GoogleFonts.inter(fontSize: 17, fontWeight: FontWeight.bold, color: valueColor)),
      ],
    );
  }

  Widget _buildFilterBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      color: const Color(0xFFF8FAFC),
      child: Row(
        children: [
          Text('Invoice Filter:', style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B), fontWeight: FontWeight.w600)),
          const SizedBox(width: 10),
          DropdownButton<String>(
            value: _selectedInvoiceStatusFilter,
            underline: const SizedBox(),
            style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF334155)),
            items: const [
              DropdownMenuItem(value: 'All', child: Text('All Statuses')),
              DropdownMenuItem(value: 'Paid', child: Text('Paid Invoices')),
              DropdownMenuItem(value: 'Partially Paid', child: Text('Partially Paid')),
              DropdownMenuItem(value: 'Unpaid', child: Text('Unpaid Invoices')),
            ],
            onChanged: (val) {
              if (val != null) setState(() => _selectedInvoiceStatusFilter = val);
            },
          ),
          const Spacer(),
          // Date Range Filter Button
          TextButton.icon(
            onPressed: () async {
              final picked = await showDateRangePicker(
                context: context,
                firstDate: DateTime(2020),
                lastDate: DateTime.now().add(const Duration(days: 30)),
                initialDateRange: _selectedDateRange,
              );
              if (picked != null) {
                setState(() => _selectedDateRange = picked);
              }
            },
            icon: const Icon(Icons.date_range_rounded, size: 16),
            label: Text(
              _selectedDateRange != null
                  ? '${DateFormat('dd/MM').format(_selectedDateRange!.start)} - ${DateFormat('dd/MM/yy').format(_selectedDateRange!.end)}'
                  : 'Date Range',
              style: GoogleFonts.inter(fontSize: 12),
            ),
          ),
          if (_selectedDateRange != null)
            IconButton(
              icon: const Icon(Icons.clear_rounded, size: 16),
              tooltip: 'Clear Date Filter',
              onPressed: () => setState(() => _selectedDateRange = null),
            ),
        ],
      ),
    );
  }

  Widget _buildInvoicesSection() {
    final list = _filteredInvoiceBalances;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Icon(Icons.receipt_long_rounded, size: 20, color: Color(0xFF0F766E)),
                const SizedBox(width: 8),
                Text('Invoices & Balances (${list.length})', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold)),
              ],
            ),
            Text('Saved invoices only', style: GoogleFonts.inter(fontSize: 11, color: Colors.grey.shade500)),
          ],
        ),
        const SizedBox(height: 12),
        if (list.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              children: [
                Icon(Icons.receipt_outlined, size: 36, color: Colors.grey.shade400),
                const SizedBox(height: 8),
                Text(
                  'No saved invoices found for this customer.',
                  style: GoogleFonts.inter(fontSize: 13, color: Colors.grey.shade600),
                ),
              ],
            ),
          )
        else
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade200),
              borderRadius: BorderRadius.circular(10),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  headingRowColor: WidgetStateProperty.all(const Color(0xFFF1F5F9)),
                  headingTextStyle: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 12, color: const Color(0xFF475569)),
                  dataRowMinHeight: 48,
                  dataRowMaxHeight: 56,
                  columns: const [
                    DataColumn(label: Text('Invoice No')),
                    DataColumn(label: Text('Invoice Date')),
                    DataColumn(label: Text('Grand Total (₹)')),
                    DataColumn(label: Text('Paid (₹)')),
                    DataColumn(label: Text('Pending (₹)')),
                    DataColumn(label: Text('Status')),
                    DataColumn(label: Text('Action')),
                  ],
                  rows: list.map((b) {
                    final inv = b.invoice;
                    Color statusBg;
                    Color statusText;
                    switch (b.paymentStatus) {
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
                        DataCell(
                          InkWell(
                            onTap: () => InvoiceDetailsDialog.show(context, inv),
                            child: Text(
                              inv.invoiceNumber,
                              style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F766E)),
                            ),
                          ),
                        ),
                        DataCell(Text(DateFormat('dd/MM/yyyy').format(inv.invoiceDate))),
                        DataCell(Text('₹${_inr.format(inv.grandTotal)}', style: const TextStyle(fontWeight: FontWeight.w600))),
                        DataCell(Text('₹${_inr.format(b.totalPaid)}', style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF059669)))),
                        DataCell(
                          Text(
                            '₹${_inr.format(b.pendingAmount)}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: b.pendingAmount > 0 ? const Color(0xFFDC2626) : const Color(0xFF059669),
                            ),
                          ),
                        ),
                        DataCell(
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(color: statusBg, borderRadius: BorderRadius.circular(4)),
                            child: Text(
                              b.paymentStatus,
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: statusText),
                            ),
                          ),
                        ),
                        DataCell(
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (b.pendingAmount > 0)
                                TextButton(
                                  onPressed: () => _openAddPayment(targetInvoice: inv),
                                  style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    foregroundColor: const Color(0xFF059669),
                                  ),
                                  child: const Text('Pay', style: TextStyle(fontWeight: FontWeight.bold)),
                                ),
                              IconButton(
                                icon: const Icon(Icons.remove_red_eye_outlined, size: 18),
                                tooltip: 'View Invoice PDF',
                                onPressed: () => InvoiceDetailsDialog.show(context, inv),
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
          ),
      ],
    );
  }

  Widget _buildPaymentsSection() {
    final payments = _filteredPayments;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Icon(Icons.history_rounded, size: 20, color: Color(0xFF0284C7)),
                const SizedBox(width: 8),
                Text('Payment History (${payments.length})', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold)),
              ],
            ),
            Text('Actual payments only (Margin Receipts excluded)', style: GoogleFonts.inter(fontSize: 11, color: Colors.grey.shade500)),
          ],
        ),
        const SizedBox(height: 12),
        if (payments.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              children: [
                Icon(Icons.payment_outlined, size: 36, color: Colors.grey.shade400),
                const SizedBox(height: 8),
                Text(
                  'No payment transactions recorded yet.',
                  style: GoogleFonts.inter(fontSize: 13, color: Colors.grey.shade600),
                ),
              ],
            ),
          )
        else
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade200),
              borderRadius: BorderRadius.circular(10),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  headingRowColor: WidgetStateProperty.all(const Color(0xFFF1F5F9)),
                  headingTextStyle: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 12, color: const Color(0xFF475569)),
                  dataRowMinHeight: 48,
                  dataRowMaxHeight: 56,
                  columns: const [
                    DataColumn(label: Text('Date')),
                    DataColumn(label: Text('Amount (₹)')),
                    DataColumn(label: Text('Payment Mode')),
                    DataColumn(label: Text('Ref / UTR')),
                    DataColumn(label: Text('Invoice Link')),
                    DataColumn(label: Text('Remarks')),
                    DataColumn(label: Text('Actions')),
                  ],
                  rows: payments.map((p) {
                    return DataRow(
                      cells: [
                        DataCell(Text(DateFormat('dd/MM/yyyy').format(p.paymentDate))),
                        DataCell(Text('₹${_inr.format(p.amount)}', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF059669)))),
                        DataCell(
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(PaymentMode.getIcon(p.paymentMode), size: 16, color: Colors.grey.shade700),
                              const SizedBox(width: 6),
                              Text(p.paymentMode),
                            ],
                          ),
                        ),
                        DataCell(Text(p.referenceNumber?.isNotEmpty == true ? p.referenceNumber! : '—')),
                        DataCell(
                          p.invoiceNumber?.isNotEmpty == true
                              ? Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFECFDF5),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    p.invoiceNumber!,
                                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF059669)),
                                  ),
                                )
                              : const Text('General', style: TextStyle(color: Colors.grey, fontSize: 12)),
                        ),
                        DataCell(Text(p.remarks?.isNotEmpty == true ? p.remarks! : '—')),
                        DataCell(
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit_outlined, size: 18, color: Color(0xFF0284C7)),
                                tooltip: 'Edit Payment',
                                onPressed: () => _openAddPayment(paymentToEdit: p),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                                tooltip: 'Delete Payment',
                                onPressed: () => _confirmDeletePayment(p),
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
          ),
      ],
    );
  }
}
