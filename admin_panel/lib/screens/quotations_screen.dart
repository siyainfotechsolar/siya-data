import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/consumer_record.dart';
import '../models/solar_quotation.dart';
import '../models/invoice.dart';
import '../services/bank_loan_quotation_service.dart';
import '../services/invoice_storage_service.dart';
import '../services/quotation_storage_service.dart';
import '../services/record_service.dart';
import '../widgets/bank_loan_quotation_dialog.dart';
import '../widgets/invoice_details_dialog.dart';

/// Quotation Management Screen — Maintains all solar quotations across customers.
/// Features:
/// - Full list with status badges, filters, and real-time search.
/// - Create quotation from existing customer profile.
/// - View, edit (preserves quotation number & asks confirmation if issued).
/// - Preview, download PDF, print, and share via WhatsApp.
/// - Manual Generate Invoice with duplicate protection.
class QuotationsScreen extends StatefulWidget {
  const QuotationsScreen({super.key});

  @override
  State<QuotationsScreen> createState() => _QuotationsScreenState();
}

class _QuotationsScreenState extends State<QuotationsScreen> {
  List<SolarQuotation> _allQuotations = [];
  List<SolarQuotation> _filteredQuotations = [];
  bool _isLoading = true;
  String _searchQuery = '';
  String _selectedFilter = 'All';
  final _searchController = TextEditingController();
  final _inrFormat = NumberFormat.currency(locale: 'en_IN', symbol: '₹ ', decimalDigits: 0);
  final _dateFormat = DateFormat('dd/MM/yyyy');

  static const List<String> _filters = [
    'All',
    'Issued',
    'Draft',
    'Approved',
    'Invoiced',
    'Cancelled',
  ];

  @override
  void initState() {
    super.initState();
    _loadQuotations();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadQuotations() async {
    setState(() => _isLoading = true);
    try {
      final list = await QuotationStorageService.getAllQuotations();
      if (mounted) {
        setState(() {
          _allQuotations = list;
          _applyFilters();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading quotations: $e')),
        );
      }
    }
  }

  void _applyFilters() {
    List<SolarQuotation> list = List.from(_allQuotations);

    // Status filter
    if (_selectedFilter != 'All') {
      list = list.where((q) {
        final st = q.status.trim().toLowerCase();
        return st == _selectedFilter.toLowerCase();
      }).toList();
    }

    // Search query
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase().trim();
      list = list.where((item) {
        return item.quotationNo.toLowerCase().contains(q) ||
            item.customerName.toLowerCase().contains(q) ||
            item.consumerNo.toLowerCase().contains(q) ||
            item.mobileNo.toLowerCase().contains(q) ||
            item.systemCapacity.toLowerCase().contains(q);
      }).toList();
    }

    _filteredQuotations = list;
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

  // ── Action Handlers ────────────────────────────────────────────────────────

  Future<ConsumerRecord?> _resolveCustomer(SolarQuotation q) async {
    // 1. Try by customerId
    if (q.customerId != null && q.customerId!.isNotEmpty) {
      final rec = await RecordService.fetchRecordById(q.customerId!);
      if (rec != null) return rec;
    }
    // 2. Try by consumerNo
    if (q.consumerNo.isNotEmpty) {
      final res = await RecordService.fetchRecords(searchQuery: q.consumerNo.trim(), pageSize: 1);
      if (res.items.isNotEmpty) return res.items.first;
    }
    // 3. Fallback dummy record to view
    return ConsumerRecord(
      id: q.customerId,
      name: q.customerName,
      consumerNo: q.consumerNo,
      mobile: q.mobileNo,
      address: q.address.isNotEmpty ? q.address : q.villageCity,
      systemCapacity: q.systemCapacity,
      totalAmount: q.grandTotal,
    );
  }

  Future<void> _viewQuotation(SolarQuotation quotation) async {
    final customer = await _resolveCustomer(quotation);
    if (!mounted) return;
    if (customer == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Customer record not found for this quotation.')),
      );
      return;
    }

    await BankLoanQuotationDialog.show(
      context,
      customer,
      initialQuotation: quotation,
      initialTab: 0,
    );
    _loadQuotations();
  }

  Future<void> _editQuotation(SolarQuotation quotation) async {
    // Confirmation if quotation is already issued
    if (quotation.status.toLowerCase() == 'issued' || quotation.status.toLowerCase() == 'approved') {
      final proceed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          icon: const Icon(Icons.warning_amber_rounded, color: Color(0xFFD97706), size: 36),
          title: const Text('Modify Issued Quotation?'),
          content: Text(
            'Quotation "${quotation.quotationNo}" has already been issued to ${quotation.customerName}.\n\n'
            'Modifying will update the existing record while preserving the Quotation Number. Do you want to proceed?',
            style: const TextStyle(fontSize: 13),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: const Color(0xFFD97706)),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Proceed to Edit'),
            ),
          ],
        ),
      );

      if (proceed != true || !mounted) return;
    }

    final customer = await _resolveCustomer(quotation);
    if (!mounted) return;
    if (customer == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Customer record not found for this quotation.')),
      );
      return;
    }

    await BankLoanQuotationDialog.show(
      context,
      customer,
      initialQuotation: quotation,
      initialTab: 0,
    );
    _loadQuotations();
  }

  Future<void> _downloadOrPrintPdf(SolarQuotation quotation) async {
    try {
      final pdfBytes = await BankLoanQuotationService.generateQuotationPdfBytes(
        quotation,
        includeStampAndSignature: true,
      );
      await Printing.layoutPdf(
        onLayout: (_) => pdfBytes,
        name: quotation.pdfFileName,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error generating PDF: $e')),
        );
      }
    }
  }

  Future<void> _shareQuotation(SolarQuotation quotation) async {
    final mob = quotation.mobileNo.replaceAll(RegExp(r'\D'), '');
    final cleanMob = mob.length == 10 ? '91$mob' : mob;

    final text = 'Namaskar ${quotation.customerName},\n\n'
        'Here are the details of your Solar Quotation from Siya Infotech & Digital Solutions:\n'
        '• Quotation No: ${quotation.quotationNo}\n'
        '• Solar Capacity: ${quotation.systemCapacity}\n'
        '• Total Project Cost: ${_inrFormat.format(quotation.grandTotal)}\n'
        '• Proposed Bank Loan: ${_inrFormat.format(quotation.bankLoanAmount)}\n'
        '• Customer Margin: ${_inrFormat.format(quotation.customerContribution)}\n\n'
        'For queries or assistance, please reach out to us.\n'
        'Siya Infotech and Digital Solutions, Betawad.';

    final encoded = Uri.encodeComponent(text);
    final waUrl = cleanMob.isNotEmpty
        ? 'https://wa.me/$cleanMob?text=$encoded'
        : 'https://wa.me/?text=$encoded';

    try {
      await launchUrl(Uri.parse(waUrl), mode: LaunchMode.externalApplication);
    } catch (_) {
      // Fallback: share PDF bytes
      try {
        final pdfBytes = await BankLoanQuotationService.generateQuotationPdfBytes(
          quotation,
          includeStampAndSignature: true,
        );
        await Printing.sharePdf(bytes: pdfBytes, filename: quotation.pdfFileName);
      } catch (err) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not share: $err')),
          );
        }
      }
    }
  }

  Future<void> _handleGenerateInvoice(SolarQuotation quotation) async {
    // 1. Duplicate check
    final existingInvoice = await InvoiceStorageService.getInvoiceForQuotation(quotation.id);
    if (existingInvoice != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Invoice ${existingInvoice.invoiceNumber} already exists for this quotation!'),
          backgroundColor: const Color(0xFFB45309),
          action: SnackBarAction(
            label: 'View Invoice',
            textColor: Colors.white,
            onPressed: () => InvoiceDetailsDialog.show(context, existingInvoice),
          ),
        ),
      );
      return;
    }

    // 2. User confirmation
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        icon: const Icon(Icons.receipt_long_rounded, color: Color(0xFF047857), size: 32),
        title: const Text('Generate Invoice'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Generate official tax invoice from this quotation?',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Customer: ${quotation.customerName}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  Text('Quotation: ${quotation.quotationNo}', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                  Text('Capacity: ${quotation.systemCapacity}', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                  Text('Grand Total: ${_inrFormat.format(quotation.grandTotal)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF047857))),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFF047857)),
            onPressed: () => Navigator.pop(ctx, true),
            icon: const Icon(Icons.receipt_long_rounded, size: 16),
            label: const Text('Generate Invoice'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    // 3. Generate invoice number & create invoice
    try {
      final invoiceNumber = await InvoiceStorageService.generateInvoiceNumber();
      final invoice = Invoice.fromQuotation(
        quotation: quotation,
        invoiceNumber: invoiceNumber,
      );

      await InvoiceStorageService.saveInvoice(invoice);

      // Update quotation status to Invoiced
      await QuotationStorageService.updateQuotationStatus(quotation.id, quotation.consumerNo, 'Invoiced');
      _loadQuotations();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Invoice $invoiceNumber generated successfully!'),
            backgroundColor: const Color(0xFF047857),
            action: SnackBarAction(
              label: 'View',
              textColor: Colors.white,
              onPressed: () => InvoiceDetailsDialog.show(context, invoice),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to generate invoice: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _updateStatus(SolarQuotation quotation, String newStatus) async {
    try {
      await QuotationStorageService.updateQuotationStatus(quotation.id, quotation.consumerNo, newStatus);
      _loadQuotations();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Quotation status updated to "$newStatus"'),
            backgroundColor: const Color(0xFF047857),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating status: $e')),
        );
      }
    }
  }

  Future<void> _deleteQuotation(SolarQuotation quotation) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        icon: const Icon(Icons.delete_outline_rounded, color: Colors.red, size: 36),
        title: const Text('Delete Quotation?'),
        content: Text(
          'Are you sure you want to delete quotation "${quotation.quotationNo}" for ${quotation.customerName}?\nThis action cannot be undone.',
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
      await QuotationStorageService.deleteQuotation(quotation.id, quotation.consumerNo);
      _loadQuotations();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Quotation deleted successfully.')),
        );
      }
    }
  }

  Future<void> _openCreateQuotationPicker() async {
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
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.person_search_rounded, color: Color(0xFF1D4ED8), size: 22),
                ),
                const SizedBox(width: 10),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Select Customer for Quotation', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    Text('Search by Customer Name, Consumer No., or Mobile', style: TextStyle(fontSize: 11, color: Colors.grey)),
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
                      hintText: 'Type Customer Name, Consumer No., or Mobile...',
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
                        child: Text('No customers found matching search.', style: TextStyle(color: Colors.grey)),
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
                              'Consumer No: ${c.consumerNo} • ${c.village ?? c.address ?? ''} • ${c.systemCapacity ?? '3 kW'}',
                              style: const TextStyle(fontSize: 12),
                            ),
                            trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey),
                            onTap: () {
                              Navigator.pop(ctx);
                              BankLoanQuotationDialog.show(context, c);
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

    _loadQuotations();
  }

  // ── Color & Badge Helpers ──────────────────────────────────────────────────

  Color _getStatusBgColor(String status) {
    switch (status.toLowerCase()) {
      case 'issued':
        return const Color(0xFFEFF6FF); // Blue
      case 'approved':
        return const Color(0xFFECFDF5); // Emerald
      case 'invoiced':
        return const Color(0xFFFAF5FF); // Purple
      case 'draft':
        return const Color(0xFFFFFBEB); // Amber
      case 'cancelled':
        return const Color(0xFFFEF2F2); // Red
      default:
        return const Color(0xFFF1F5F9); // Slate
    }
  }

  Color _getStatusTextColor(String status) {
    switch (status.toLowerCase()) {
      case 'issued':
        return const Color(0xFF1D4ED8);
      case 'approved':
        return const Color(0xFF047857);
      case 'invoiced':
        return const Color(0xFF7E22CE);
      case 'draft':
        return const Color(0xFFB45309);
      case 'cancelled':
        return const Color(0xFFDC2626);
      default:
        return const Color(0xFF475569);
    }
  }

  // ── Build UI ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Column(
      children: [
        // ── Top Header Bar ──────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFBFDBFE)),
                ),
                child: const Icon(Icons.request_quote_rounded, color: Color(0xFF1D4ED8), size: 22),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text(
                        'Quotation Management',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1D4ED8).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${_filteredQuotations.length} / ${_allQuotations.length}',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF1D4ED8)),
                        ),
                      ),
                    ],
                  ),
                  const Text(
                    'Maintain, preview, edit, download and convert solar quotations to invoices',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
              const Spacer(),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF1D4ED8),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: _openCreateQuotationPicker,
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Create Quotation', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              ),
              const SizedBox(width: 8),
              IconButton.outlined(
                icon: const Icon(Icons.refresh_rounded, size: 20),
                tooltip: 'Refresh Quotations',
                onPressed: _loadQuotations,
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
              hintText: 'Search by Quotation No., Customer Name, Consumer No., Mobile...',
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
                  selectedColor: const Color(0xFF1D4ED8),
                  showCheckmark: false,
                  visualDensity: VisualDensity.compact,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                );
              },
            ),
          ),
        ),

        const Divider(height: 1),

        // ── Main Quotation Table / List ─────────────────────────────────────
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _filteredQuotations.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.request_quote_outlined, size: 48, color: cs.onSurfaceVariant.withValues(alpha: 0.4)),
                          const SizedBox(height: 12),
                          Text(
                            _searchQuery.isNotEmpty || _selectedFilter != 'All'
                                ? 'No quotations match current filters'
                                : 'No quotations created yet',
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: cs.onSurfaceVariant),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Click "+ Create Quotation" above to generate a new quotation.',
                            style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant.withValues(alpha: 0.7)),
                          ),
                          const SizedBox(height: 16),
                          FilledButton.icon(
                            onPressed: _openCreateQuotationPicker,
                            icon: const Icon(Icons.add, size: 16),
                            label: const Text('Create Quotation'),
                          ),
                        ],
                      ),
                    )
                  : LayoutBuilder(
                      builder: (ctx, constraints) {
                        // Desktop Table vs Mobile Cards
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
              0: FlexColumnWidth(2.2), // Quotation No
              1: FlexColumnWidth(2.6), // Customer Name
              2: FlexColumnWidth(1.8), // Consumer No
              3: FlexColumnWidth(1.4), // Date
              4: FlexColumnWidth(1.3), // Capacity
              5: FlexColumnWidth(1.6), // Amount
              6: FlexColumnWidth(1.4), // Status
              7: FlexColumnWidth(2.5), // Actions
            },
            defaultVerticalAlignment: TableCellVerticalAlignment.middle,
            children: [
              // Header Row
              TableRow(
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                ),
                children: const [
                  Padding(padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10), child: Text('Quotation No.', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5))),
                  Padding(padding: EdgeInsets.symmetric(horizontal: 8, vertical: 10), child: Text('Customer Name', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5))),
                  Padding(padding: EdgeInsets.symmetric(horizontal: 8, vertical: 10), child: Text('Consumer No.', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5))),
                  Padding(padding: EdgeInsets.symmetric(horizontal: 8, vertical: 10), child: Text('Date', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5))),
                  Padding(padding: EdgeInsets.symmetric(horizontal: 8, vertical: 10), child: Text('Capacity', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5))),
                  Padding(padding: EdgeInsets.symmetric(horizontal: 8, vertical: 10), child: Text('Total Amount', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5))),
                  Padding(padding: EdgeInsets.symmetric(horizontal: 8, vertical: 10), child: Text('Status', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5))),
                  Padding(padding: EdgeInsets.symmetric(horizontal: 8, vertical: 10), child: Text('Actions', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5))),
                ],
              ),
              // Data Rows
              ..._filteredQuotations.map((q) {
                return TableRow(
                  decoration: BoxDecoration(
                    border: Border(bottom: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.3))),
                  ),
                  children: [
                    // Quotation No
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      child: Row(
                        children: [
                          SelectableText(
                            q.quotationNo,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF1D4ED8)),
                          ),
                          IconButton(
                            icon: const Icon(Icons.copy_rounded, size: 14, color: Colors.grey),
                            tooltip: 'Copy Quotation No',
                            onPressed: () {
                              Clipboard.setData(ClipboardData(text: q.quotationNo));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Quotation number copied!'), duration: Duration(seconds: 1)),
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
                          Text(q.customerName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5)),
                          if (q.mobileNo.isNotEmpty)
                            Text(q.mobileNo, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                        ],
                      ),
                    ),
                    // Consumer No
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                      child: SelectableText(q.consumerNo, style: const TextStyle(fontSize: 12)),
                    ),
                    // Date
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                      child: Text(_dateFormat.format(q.quotationDate), style: const TextStyle(fontSize: 12)),
                    ),
                    // Capacity
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          q.systemCapacity,
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
                        ),
                      ),
                    ),
                    // Total Amount
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                      child: Text(
                        _inrFormat.format(q.grandTotal),
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF047857)),
                      ),
                    ),
                    // Status Badge with Dropdown
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                      child: PopupMenuButton<String>(
                        tooltip: 'Change Status',
                        onSelected: (val) => _updateStatus(q, val),
                        itemBuilder: (ctx) => ['Draft', 'Issued', 'Approved', 'Invoiced', 'Cancelled']
                            .map((st) => PopupMenuItem(value: st, child: Text(st)))
                            .toList(),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: _getStatusBgColor(q.status),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: _getStatusTextColor(q.status).withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                q.status,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: _getStatusTextColor(q.status),
                                ),
                              ),
                              const SizedBox(width: 4),
                              Icon(Icons.arrow_drop_down, size: 14, color: _getStatusTextColor(q.status)),
                            ],
                          ),
                        ),
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
                            tooltip: 'Preview Quotation',
                            onPressed: () => _viewQuotation(q),
                          ),
                          IconButton(
                            icon: const Icon(Icons.edit_outlined, size: 18, color: Color(0xFF1D4ED8)),
                            tooltip: 'Edit Quotation',
                            onPressed: () => _editQuotation(q),
                          ),
                          IconButton(
                            icon: const Icon(Icons.picture_as_pdf_outlined, size: 18, color: Color(0xFF047857)),
                            tooltip: 'Download / Print PDF',
                            onPressed: () => _downloadOrPrintPdf(q),
                          ),
                          IconButton(
                            icon: const Icon(Icons.share_outlined, size: 18, color: Color(0xFF0284C7)),
                            tooltip: 'Share via WhatsApp',
                            onPressed: () => _shareQuotation(q),
                          ),
                          PopupMenuButton<String>(
                            icon: const Icon(Icons.more_vert, size: 18),
                            tooltip: 'More Actions',
                            onSelected: (val) {
                              if (val == 'invoice') {
                                _handleGenerateInvoice(q);
                              } else if (val == 'delete') {
                                _deleteQuotation(q);
                              }
                            },
                            itemBuilder: (ctx) => [
                              const PopupMenuItem(
                                value: 'invoice',
                                child: Row(
                                  children: [
                                    Icon(Icons.receipt_long_rounded, size: 18, color: Color(0xFF047857)),
                                    SizedBox(width: 8),
                                    Text('Generate Invoice'),
                                  ],
                                ),
                              ),
                              const PopupMenuItem(
                                value: 'delete',
                                child: Row(
                                  children: [
                                    Icon(Icons.delete_outline, size: 18, color: Colors.red),
                                    SizedBox(width: 8),
                                    Text('Delete Quotation', style: TextStyle(color: Colors.red)),
                                  ],
                                ),
                              ),
                            ],
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
      itemCount: _filteredQuotations.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (ctx, idx) {
        final q = _filteredQuotations[idx];
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
                      q.quotationNo,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1D4ED8)),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: _getStatusBgColor(q.status),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        q.status,
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _getStatusTextColor(q.status)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(q.customerName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                Text('Consumer No: ${q.consumerNo} • ${q.systemCapacity}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Date: ${_dateFormat.format(q.quotationDate)}', style: const TextStyle(fontSize: 12)),
                    Text(
                      _inrFormat.format(q.grandTotal),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF047857)),
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
                      onPressed: () => _viewQuotation(q),
                      icon: const Icon(Icons.visibility_outlined, size: 16),
                      label: const Text('View', style: TextStyle(fontSize: 12)),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      ),
                      onPressed: () => _editQuotation(q),
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
                      onPressed: () => _downloadOrPrintPdf(q),
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
