import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/consumer_record.dart';
import '../models/customer_margin_receipt.dart';
import '../services/margin_money_receipt_service.dart';
import '../services/quotation_storage_service.dart';
import '../services/record_service.dart';
import '../widgets/bank_loan_quotation_dialog.dart';

/// Margin Receipts Screen — Strictly for Loan Documentation.
/// IMPORTANT: Margin Receipts are for bank loan/finance processing only.
/// They do NOT affect actual payments, cash balance, customer ledger, or pending amounts.
class MarginReceiptsScreen extends StatefulWidget {
  const MarginReceiptsScreen({super.key});

  @override
  State<MarginReceiptsScreen> createState() => _MarginReceiptsScreenState();
}

class _MarginReceiptsScreenState extends State<MarginReceiptsScreen> {
  List<CustomerMarginReceipt> _allReceipts = [];
  List<CustomerMarginReceipt> _filteredReceipts = [];
  bool _isLoading = true;
  String _searchQuery = '';
  String _selectedFilter = 'All';
  final _searchController = TextEditingController();
  final _inrFormat = NumberFormat.currency(locale: 'en_IN', symbol: '₹ ', decimalDigits: 0);
  final _dateFormat = DateFormat('dd/MM/yyyy');

  static const List<String> _filters = [
    'All',
    'Cash',
    'Online / UPI',
    'Bank Transfer',
    'Cheque / DD',
  ];

  @override
  void initState() {
    super.initState();
    _loadReceipts();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadReceipts() async {
    setState(() => _isLoading = true);
    try {
      final list = await QuotationStorageService.getAllMarginReceipts();
      if (mounted) {
        setState(() {
          _allReceipts = list;
          _applyFilters();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading margin receipts: $e')),
        );
      }
    }
  }

  void _applyFilters() {
    List<CustomerMarginReceipt> list = List.from(_allReceipts);

    // Filter by payment mode
    if (_selectedFilter != 'All') {
      list = list.where((r) {
        return r.paymentMode.toLowerCase().contains(_selectedFilter.toLowerCase());
      }).toList();
    }

    // Search query
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase().trim();
      list = list.where((item) {
        return item.receiptNo.toLowerCase().contains(q) ||
            item.customerName.toLowerCase().contains(q) ||
            item.consumerNo.toLowerCase().contains(q) ||
            item.financeCompanyName.toLowerCase().contains(q) ||
            item.bankName.toLowerCase().contains(q) ||
            item.loanApplicationNo.toLowerCase().contains(q) ||
            item.quotationNo.toLowerCase().contains(q);
      }).toList();
    }

    _filteredReceipts = list;
  }

  void _onSearchChanged(String query) {
    setState(() {
      _searchQuery = query;
      _applyFilters();
    });
  }

  void _onFilterChanged(String filter) {
    setState(() {
      _selectedFilter = filter;
      _applyFilters();
    });
  }

  // ── Actions ────────────────────────────────────────────────────────────────

  Future<ConsumerRecord?> _resolveCustomer(CustomerMarginReceipt r) async {
    if (r.customerId != null && r.customerId!.isNotEmpty) {
      final rec = await RecordService.fetchRecordById(r.customerId!);
      if (rec != null) return rec;
    }
    if (r.consumerNo.isNotEmpty) {
      final res = await RecordService.fetchRecords(searchQuery: r.consumerNo.trim(), pageSize: 1);
      if (res.items.isNotEmpty) return res.items.first;
    }
    return ConsumerRecord(
      id: r.customerId,
      name: r.customerName,
      consumerNo: r.consumerNo,
      mobile: r.mobileNo,
      address: r.address.isNotEmpty ? r.address : r.villageCity,
      systemCapacity: r.systemCapacity,
      totalAmount: r.totalSystemCost,
    );
  }

  Future<void> _viewReceipt(CustomerMarginReceipt receipt) async {
    final customer = await _resolveCustomer(receipt);
    if (!mounted) return;
    if (customer == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Customer record not found for this receipt.')),
      );
      return;
    }

    await BankLoanQuotationDialog.show(
      context,
      customer,
      initialTab: 1,
    );
    _loadReceipts();
  }

  Future<void> _editReceipt(CustomerMarginReceipt receipt) async {
    final receiptNoCtrl = TextEditingController(text: receipt.receiptNo);
    final txnRefCtrl = TextEditingController(text: receipt.transactionRef);
    final amountCtrl = TextEditingController(text: receipt.marginAmount.toStringAsFixed(0));
    final bankCtrl = TextEditingController(text: receipt.financeCompanyName.isNotEmpty ? receipt.financeCompanyName : receipt.bankName);
    final loanAppCtrl = TextEditingController(text: receipt.loanApplicationNo);
    final notesCtrl = TextEditingController(text: receipt.notes);
    String selectedMode = receipt.paymentMode;
    DateTime selectedDate = receipt.receiptDate;

    final updated = await showDialog<CustomerMarginReceipt?>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDlgState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFECFDF5),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.edit_document, color: Color(0xFF047857), size: 22),
                  ),
                  const SizedBox(width: 10),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Edit Margin Receipt (Loan Doc)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      Text('Preserves Receipt No. & ID • For Bank Loan Processing Only', style: TextStyle(fontSize: 11, color: Colors.grey)),
                    ],
                  ),
                ],
              ),
              content: SizedBox(
                width: 500,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Notice banner
                      Container(
                        padding: const EdgeInsets.all(10),
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF3C7),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFFDE68A)),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.info_outline, size: 16, color: Color(0xFFB45309)),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'This receipt is strictly for loan processing and does not affect the payment ledger.',
                                style: TextStyle(fontSize: 11, color: Color(0xFF92400E)),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Row(
                        children: [
                          Expanded(
                            flex: 6,
                            child: TextField(
                              controller: receiptNoCtrl,
                              readOnly: true, // Preserve receipt number
                              decoration: const InputDecoration(
                                labelText: 'Receipt No. (Preserved)',
                                isDense: true,
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.tag_rounded, size: 18),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            flex: 5,
                            child: InkWell(
                              onTap: () async {
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate: selectedDate,
                                  firstDate: DateTime(2020),
                                  lastDate: DateTime(2035),
                                );
                                if (picked != null) setDlgState(() => selectedDate = picked);
                              },
                              child: InputDecorator(
                                decoration: const InputDecoration(
                                  labelText: 'Document Date',
                                  isDense: true,
                                  border: OutlineInputBorder(),
                                  prefixIcon: Icon(Icons.calendar_today_rounded, size: 16),
                                ),
                                child: Text(_dateFormat.format(selectedDate), style: const TextStyle(fontSize: 13)),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: amountCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Margin Amount (₹) *',
                          helperText: 'Loan documentation margin contribution',
                          isDense: true,
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.currency_rupee_rounded, size: 18),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: bankCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Bank / Finance Company *',
                                isDense: true,
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.account_balance_rounded, size: 18),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextField(
                              controller: loanAppCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Loan App No. / Ref',
                                isDense: true,
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.badge_rounded, size: 18),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            flex: 5,
                            child: DropdownButtonFormField<String>(
                              value: selectedMode,
                              decoration: const InputDecoration(
                                labelText: 'Payment Mode *',
                                isDense: true,
                                border: OutlineInputBorder(),
                              ),
                              items: ['Cash', 'Online / UPI', 'Cheque / DD', 'NEFT / RTGS', 'Bank Transfer']
                                  .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                                  .toList(),
                              onChanged: (v) {
                                if (v != null) setDlgState(() => selectedMode = v);
                              },
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            flex: 6,
                            child: TextField(
                              controller: txnRefCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Transaction Ref / Cheque No.',
                                isDense: true,
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: notesCtrl,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          labelText: 'Remarks / Notes',
                          isDense: true,
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                FilledButton.icon(
                  style: FilledButton.styleFrom(backgroundColor: const Color(0xFF047857)),
                  icon: const Icon(Icons.save_rounded, size: 16),
                  label: const Text('Save Changes'),
                  onPressed: () {
                    final newAmt = double.tryParse(amountCtrl.text.trim()) ?? receipt.marginAmount;
                    final edited = receipt.copyWith(
                      receiptDate: selectedDate,
                      marginAmount: newAmt,
                      paymentMode: selectedMode,
                      transactionRef: txnRefCtrl.text.trim(),
                      financeCompanyName: bankCtrl.text.trim(),
                      bankName: bankCtrl.text.trim(),
                      loanApplicationNo: loanAppCtrl.text.trim(),
                      notes: notesCtrl.text.trim(),
                      updatedAt: DateTime.now(),
                    );
                    Navigator.pop(ctx, edited);
                  },
                ),
              ],
            );
          },
        );
      },
    );

    if (updated != null) {
      await QuotationStorageService.saveMarginReceipt(updated);
      _loadReceipts();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Margin receipt updated successfully! Record preserved.'),
            backgroundColor: Color(0xFF047857),
          ),
        );
      }
    }
  }

  Future<void> _downloadOrPrintPdf(CustomerMarginReceipt receipt) async {
    try {
      final pdfBytes = await MarginMoneyReceiptService.generateReceiptPdfBytes(
        receipt,
        includeStampAndSignature: true,
      );
      await Printing.layoutPdf(
        onLayout: (_) => pdfBytes,
        name: receipt.pdfFileName,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error generating PDF: $e')),
        );
      }
    }
  }

  Future<void> _shareReceipt(CustomerMarginReceipt receipt) async {
    final mob = receipt.mobileNo.replaceAll(RegExp(r'\D'), '');
    final cleanMob = mob.length == 10 ? '91$mob' : mob;

    final text = 'Namaskar ${receipt.customerName},\n\n'
        'Here are the details of your Margin Contribution Declaration for Bank Solar Loan:\n'
        '• Receipt No: ${receipt.receiptNo}\n'
        '• Date: ${_dateFormat.format(receipt.receiptDate)}\n'
        '• Customer Margin: ${_inrFormat.format(receipt.marginAmount)}\n'
        '• Bank/Finance Co: ${receipt.financeCompanyName.isNotEmpty ? receipt.financeCompanyName : receipt.bankName}\n'
        '• Loan App No: ${receipt.loanApplicationNo.isNotEmpty ? receipt.loanApplicationNo : 'Under Processing'}\n\n'
        'Note: Issued solely for bank loan and finance processing.\n'
        'Siya Infotech and Digital Solutions, Betawad.';

    final encoded = Uri.encodeComponent(text);
    final waUrl = cleanMob.isNotEmpty
        ? 'https://wa.me/$cleanMob?text=$encoded'
        : 'https://wa.me/?text=$encoded';

    try {
      await launchUrl(Uri.parse(waUrl), mode: LaunchMode.externalApplication);
    } catch (_) {
      try {
        final pdfBytes = await MarginMoneyReceiptService.generateReceiptPdfBytes(
          receipt,
          includeStampAndSignature: true,
        );
        await Printing.sharePdf(bytes: pdfBytes, filename: receipt.pdfFileName);
      } catch (err) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not share: $err')),
          );
        }
      }
    }
  }

  Future<void> _deleteReceipt(CustomerMarginReceipt receipt) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        icon: const Icon(Icons.delete_outline_rounded, color: Colors.red, size: 36),
        title: const Text('Delete Margin Receipt?'),
        content: Text(
          'Delete margin receipt "${receipt.receiptNo}" for ${receipt.customerName}?\nThis will not affect any accounting balances.',
          style: const TextStyle(fontSize: 13),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await QuotationStorageService.deleteMarginReceipt(receipt.receiptNo, receipt.consumerNo);
      _loadReceipts();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Margin receipt deleted.')),
        );
      }
    }
  }

  Future<void> _openCreateReceiptPicker() async {
    final searchCtrl = TextEditingController();
    List<ConsumerRecord> searchResults = [];
    bool isSearching = false;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) {
          Future<void> doSearch(String query) async {
            if (query.trim().isEmpty) {
              setDlgState(() => searchResults = []);
              return;
            }
            setDlgState(() => isSearching = true);
            try {
              final res = await RecordService.fetchRecords(searchQuery: query.trim(), pageSize: 15);
              setDlgState(() {
                searchResults = res.items;
                isSearching = false;
              });
            } catch (_) {
              setDlgState(() => isSearching = false);
            }
          }

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFECFDF5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.description_rounded, color: Color(0xFF047857), size: 22),
                ),
                const SizedBox(width: 10),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Create Margin Receipt', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    Text('Select customer to generate loan margin document', style: TextStyle(fontSize: 11, color: Colors.grey)),
                  ],
                ),
              ],
            ),
            content: SizedBox(
              width: 520,
              height: 400,
              child: Column(
                children: [
                  TextField(
                    controller: searchCtrl,
                    autofocus: true,
                    onChanged: doSearch,
                    decoration: InputDecoration(
                      hintText: 'Search Customer Name, Consumer No., or Mobile...',
                      prefixIcon: const Icon(Icons.search_rounded),
                      isDense: true,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (isSearching)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (searchResults.isEmpty && searchCtrl.text.isNotEmpty)
                    const Expanded(
                      child: Center(
                        child: Text('No customers found.', style: TextStyle(color: Colors.grey)),
                      ),
                    )
                  else if (searchResults.isEmpty)
                    const Expanded(
                      child: Center(
                        child: Text('Search above to select an existing customer from Customer Master.', style: TextStyle(color: Colors.grey, fontSize: 12)),
                      ),
                    )
                  else
                    Expanded(
                      child: ListView.separated(
                        itemCount: searchResults.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (ctx, idx) {
                          final c = searchResults[idx];
                          return ListTile(
                            title: Text(c.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                            subtitle: Text(
                              'Consumer No: ${c.consumerNo} • ${c.village ?? c.address ?? ''}',
                              style: const TextStyle(fontSize: 12),
                            ),
                            trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey),
                            onTap: () {
                              Navigator.pop(ctx);
                              BankLoanQuotationDialog.show(context, c, initialTab: 1);
                            },
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
            ],
          );
        },
      ),
    );

    _loadReceipts();
  }

  // ── Build UI ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Column(
      children: [
        // ── Mandatory Separation Banner ─────────────────────────────────────
        Container(
          width: double.infinity,
          color: const Color(0xFFFEF3C7),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: const Row(
            children: [
              Icon(Icons.shield_outlined, size: 18, color: Color(0xFFB45309)),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Accounting Separation Rule: Margin Receipts are strictly for bank loan/finance processing and do NOT affect actual payments, cash balance, customer ledger, or pending amounts.',
                  style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF92400E)),
                ),
              ),
            ],
          ),
        ),

        // ── Top Header Bar ──────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFA7F3D0)),
                ),
                child: const Icon(Icons.description_rounded, color: Color(0xFF047857), size: 22),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text(
                        'Margin Receipt Management',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF047857).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${_filteredReceipts.length} / ${_allReceipts.length}',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF047857)),
                        ),
                      ),
                    ],
                  ),
                  const Text(
                    'Bank Loan & Finance Documentation (10% Margin Contribution)',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
              const Spacer(),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF047857),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: _openCreateReceiptPicker,
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Create Margin Receipt', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              ),
              const SizedBox(width: 8),
              IconButton.outlined(
                icon: const Icon(Icons.refresh_rounded, size: 20),
                tooltip: 'Refresh Receipts',
                onPressed: _loadReceipts,
              ),
            ],
          ),
        ),

        // ── Search Bar ──────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
          child: TextField(
            controller: _searchController,
            onChanged: _onSearchChanged,
            decoration: InputDecoration(
              hintText: 'Search by Receipt No., Customer, Consumer No., Bank, Loan App No...',
              hintStyle: TextStyle(fontSize: 13, color: cs.onSurfaceVariant.withValues(alpha: 0.6)),
              prefixIcon: const Icon(Icons.search_rounded, size: 20),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () {
                        _searchController.clear();
                        _onSearchChanged('');
                      },
                    )
                  : null,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),

        // ── Filter Chips ────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: SizedBox(
            height: 36,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _filters.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (ctx, idx) {
                final f = _filters[idx];
                final isSelected = _selectedFilter == f;
                return ChoiceChip(
                  label: Text(f),
                  selected: isSelected,
                  onSelected: (_) => _onFilterChanged(f),
                  labelStyle: TextStyle(
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    color: isSelected ? cs.onPrimary : cs.onSurface,
                  ),
                  selectedColor: const Color(0xFF047857),
                  showCheckmark: false,
                  visualDensity: VisualDensity.compact,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                );
              },
            ),
          ),
        ),

        const Divider(height: 1),

        // ── Main Receipts Table / List ───────────────────────────────────────
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _filteredReceipts.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.description_outlined, size: 48, color: cs.onSurfaceVariant.withValues(alpha: 0.4)),
                          const SizedBox(height: 12),
                          Text(
                            _searchQuery.isNotEmpty || _selectedFilter != 'All'
                                ? 'No margin receipts match current filters'
                                : 'No margin receipts created yet',
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: cs.onSurfaceVariant),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Click "+ Create Margin Receipt" to generate loan contribution document.',
                            style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant.withValues(alpha: 0.7)),
                          ),
                          const SizedBox(height: 16),
                          FilledButton.icon(
                            style: FilledButton.styleFrom(backgroundColor: const Color(0xFF047857)),
                            onPressed: _openCreateReceiptPicker,
                            icon: const Icon(Icons.add, size: 16),
                            label: const Text('Create Margin Receipt'),
                          ),
                        ],
                      ),
                    )
                  : LayoutBuilder(
                      builder: (ctx, constraints) {
                        if (constraints.maxWidth > 850) {
                          return _buildDesktopTable(cs);
                        } else {
                          return _buildMobileList(cs);
                        }
                      },
                    ),
        ),
      ],
    );
  }

  Widget _buildDesktopTable(ColorScheme cs) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Container(
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.5)),
          ),
          child: Table(
            columnWidths: const {
              0: FlexColumnWidth(2.0), // Receipt No
              1: FlexColumnWidth(2.5), // Customer Name
              2: FlexColumnWidth(1.6), // Consumer No
              3: FlexColumnWidth(1.3), // Date
              4: FlexColumnWidth(1.6), // Margin Amount
              5: FlexColumnWidth(2.0), // Bank/Finance Company
              6: FlexColumnWidth(1.8), // Loan App No
              7: FlexColumnWidth(2.2), // Actions
            },
            defaultVerticalAlignment: TableCellVerticalAlignment.middle,
            children: [
              // Header
              TableRow(
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                ),
                children: const [
                  Padding(padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10), child: Text('Receipt No.', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5))),
                  Padding(padding: EdgeInsets.symmetric(horizontal: 8, vertical: 10), child: Text('Customer Name', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5))),
                  Padding(padding: EdgeInsets.symmetric(horizontal: 8, vertical: 10), child: Text('Consumer No.', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5))),
                  Padding(padding: EdgeInsets.symmetric(horizontal: 8, vertical: 10), child: Text('Date', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5))),
                  Padding(padding: EdgeInsets.symmetric(horizontal: 8, vertical: 10), child: Text('Margin Amount', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5))),
                  Padding(padding: EdgeInsets.symmetric(horizontal: 8, vertical: 10), child: Text('Bank / Finance Co.', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5))),
                  Padding(padding: EdgeInsets.symmetric(horizontal: 8, vertical: 10), child: Text('Loan App No.', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5))),
                  Padding(padding: EdgeInsets.symmetric(horizontal: 8, vertical: 10), child: Text('Actions', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5))),
                ],
              ),
              // Data Rows
              ..._filteredReceipts.map((r) {
                return TableRow(
                  decoration: BoxDecoration(
                    border: Border(bottom: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.3))),
                  ),
                  children: [
                    // Receipt No
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      child: Row(
                        children: [
                          SelectableText(
                            r.receiptNo,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF047857)),
                          ),
                          IconButton(
                            icon: const Icon(Icons.copy_rounded, size: 14, color: Colors.grey),
                            tooltip: 'Copy Receipt No',
                            onPressed: () {
                              Clipboard.setData(ClipboardData(text: r.receiptNo));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Receipt number copied!'), duration: Duration(seconds: 1)),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                    // Customer Name
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(r.customerName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5)),
                          if (r.mobileNo.isNotEmpty)
                            Text(r.mobileNo, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                        ],
                      ),
                    ),
                    // Consumer No
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                      child: SelectableText(r.consumerNo, style: const TextStyle(fontSize: 12)),
                    ),
                    // Date
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                      child: Text(_dateFormat.format(r.receiptDate), style: const TextStyle(fontSize: 12)),
                    ),
                    // Margin Amount
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _inrFormat.format(r.marginAmount),
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFFB45309)),
                          ),
                          Text(
                            r.paymentMode,
                            style: const TextStyle(fontSize: 10.5, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                    // Bank / Finance Co.
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                      child: Text(
                        r.financeCompanyName.isNotEmpty ? r.financeCompanyName : r.bankName,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                      ),
                    ),
                    // Loan App No.
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                      child: Text(
                        r.loanApplicationNo.isNotEmpty ? r.loanApplicationNo : '—',
                        style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                      ),
                    ),
                    // Actions
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.visibility_outlined, size: 18),
                            tooltip: 'Preview Receipt',
                            onPressed: () => _viewReceipt(r),
                          ),
                          IconButton(
                            icon: const Icon(Icons.edit_outlined, size: 18, color: Color(0xFF1D4ED8)),
                            tooltip: 'Edit Receipt',
                            onPressed: () => _editReceipt(r),
                          ),
                          IconButton(
                            icon: const Icon(Icons.picture_as_pdf_outlined, size: 18, color: Color(0xFF047857)),
                            tooltip: 'Download / Print PDF',
                            onPressed: () => _downloadOrPrintPdf(r),
                          ),
                          IconButton(
                            icon: const Icon(Icons.share_outlined, size: 18, color: Color(0xFF0284C7)),
                            tooltip: 'Share via WhatsApp',
                            onPressed: () => _shareReceipt(r),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                            tooltip: 'Delete Receipt',
                            onPressed: () => _deleteReceipt(r),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMobileList(ColorScheme cs) {
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: _filteredReceipts.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (ctx, idx) {
        final r = _filteredReceipts[idx];
        return Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.5)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    SelectableText(
                      r.receiptNo,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF047857)),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF3C7),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'Loan Doc Only',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFFB45309)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(r.customerName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                Text('Consumer No: ${r.consumerNo}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                if (r.financeCompanyName.isNotEmpty)
                  Text('Bank: ${r.financeCompanyName}', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Date: ${_dateFormat.format(r.receiptDate)}', style: const TextStyle(fontSize: 12)),
                    Text(
                      _inrFormat.format(r.marginAmount),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFFB45309)),
                    ),
                  ],
                ),
                const Divider(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      ),
                      onPressed: () => _viewReceipt(r),
                      icon: const Icon(Icons.visibility_outlined, size: 16),
                      label: const Text('View', style: TextStyle(fontSize: 12)),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      ),
                      onPressed: () => _editReceipt(r),
                      icon: const Icon(Icons.edit_outlined, size: 16),
                      label: const Text('Edit', style: TextStyle(fontSize: 12)),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF047857),
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      ),
                      onPressed: () => _downloadOrPrintPdf(r),
                      icon: const Icon(Icons.picture_as_pdf, size: 16),
                      label: const Text('PDF', style: TextStyle(fontSize: 12)),
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
}
