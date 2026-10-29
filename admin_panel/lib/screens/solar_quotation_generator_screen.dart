import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'package:siya_shared/siya_shared.dart';

import '../services/quotation_storage_service.dart';
import '../services/record_service.dart';
import '../services/solar_quotation_service.dart';
import '../widgets/solar_quotation_generator_dialog.dart';

/// Standalone Solar Quotation Generator Screen
/// Completely independent from the Bank Loan Quotation system.
/// Features:
/// 1. Option A (New Customer direct quotation without saving to master)
/// 2. Option B (Select from Customer Master)
/// 3. Bilingual (Marathi + English Mix default), English, Marathi
/// 4. PM Surya Ghar Subsidy & 12-Month Generation Forecast
/// 5. Live A4 PDF Preview, Direct Download, Print & WhatsApp Sharing
class SolarQuotationGeneratorScreen extends StatefulWidget {
  const SolarQuotationGeneratorScreen({super.key});

  @override
  State<SolarQuotationGeneratorScreen> createState() => _SolarQuotationGeneratorScreenState();
}

class _SolarQuotationGeneratorScreenState extends State<SolarQuotationGeneratorScreen> {
  List<SolarQuotation> _allQuotations = [];
  List<SolarQuotation> _filteredQuotations = [];
  bool _isLoading = true;
  String _searchQuery = '';
  String _typeFilter = 'All'; // All, Residential, Commercial
  String _statusFilter = 'All'; // All, Draft, Issued, Approved, Invoiced

  final _searchController = TextEditingController();
  final _currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: '₹ ', decimalDigits: 0);
  final _dateFormat = DateFormat('dd/MM/yyyy');

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
          SnackBar(content: Text('Error loading solar quotations: $e')),
        );
      }
    }
  }

  void _applyFilters() {
    List<SolarQuotation> list = List.from(_allQuotations);

    // Type filter
    if (_typeFilter != 'All') {
      list = list.where((q) => q.quotationType.toLowerCase() == _typeFilter.toLowerCase()).toList();
    }

    // Status filter
    if (_statusFilter != 'All') {
      list = list.where((q) => q.status.toLowerCase() == _statusFilter.toLowerCase()).toList();
    }

    // Search query
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase().trim();
      list = list.where((item) {
        return item.quotationNo.toLowerCase().contains(q) ||
            item.customerName.toLowerCase().contains(q) ||
            item.consumerNo.toLowerCase().contains(q) ||
            item.mobileNo.toLowerCase().contains(q) ||
            item.systemCapacity.toLowerCase().contains(q) ||
            item.villageCity.toLowerCase().contains(q);
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

  // ── Open Generator Handlers ────────────────────────────────────────────────

  /// Option A: New Customer (Direct entry without requiring master save)
  void _openForNewCustomer() {
    SolarQuotationGeneratorDialog.show(
      context,
      customer: null,
      initialQuotation: null,
    ).then((_) => _loadQuotations());
  }

  /// Option B: Select existing customer from Customer Master
  Future<void> _openSelectMasterCustomer() async {
    final searchCtrl = TextEditingController();
    List<ConsumerRecord> results = [];
    bool isSearching = false;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) {
          Future<void> doSearch(String query) async {
            if (query.trim().isEmpty) {
              setDlgState(() => results = []);
              return;
            }
            setDlgState(() => isSearching = true);
            try {
              final res = await RecordService.fetchRecords(searchQuery: query.trim(), pageSize: 15);
              setDlgState(() {
                results = res.items;
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
                  child: const Icon(Icons.person_search_rounded, color: Color(0xFF047857), size: 22),
                ),
                const SizedBox(width: 10),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Select Customer from Master', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    Text('Choose an existing customer to populate proposal details', style: TextStyle(fontSize: 11, color: Colors.grey)),
                  ],
                ),
              ],
            ),
            content: SizedBox(
              width: 540,
              height: 420,
              child: Column(
                children: [
                  TextField(
                    controller: searchCtrl,
                    autofocus: true,
                    onChanged: doSearch,
                    decoration: InputDecoration(
                      hintText: 'Search by Customer Name, Consumer No., or Mobile...',
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
                  else if (results.isEmpty && searchCtrl.text.isNotEmpty)
                    const Expanded(
                      child: Center(
                        child: Text('No customers found matching search.', style: TextStyle(color: Colors.grey)),
                      ),
                    )
                  else if (results.isEmpty)
                    const Expanded(
                      child: Center(
                        child: Text(
                          'Type customer name, consumer number, or mobile to search.',
                          style: TextStyle(color: Colors.grey, fontSize: 12),
                        ),
                      ),
                    )
                  else
                    Expanded(
                      child: ListView.separated(
                        itemCount: results.length,
                        separatorBuilder: (_, index) => const Divider(height: 1),
                        itemBuilder: (ctx, idx) {
                          final c = results[idx];
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: const Color(0xFFD1FAE5),
                              foregroundColor: const Color(0xFF047857),
                              child: Text(c.name.isNotEmpty ? c.name[0].toUpperCase() : 'C'),
                            ),
                            title: Text(c.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                            subtitle: Text(
                              'Consumer No: ${c.consumerNo} • ${c.village ?? c.address ?? ''} • ${c.systemCapacity ?? '3 kW'}',
                              style: const TextStyle(fontSize: 12),
                            ),
                            trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey),
                            onTap: () {
                              Navigator.pop(ctx);
                              SolarQuotationGeneratorDialog.show(
                                context,
                                customer: c,
                              ).then((_) => _loadQuotations());
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
  }

  void _openForQuotation(SolarQuotation quotation) {
    SolarQuotationGeneratorDialog.show(
      context,
      initialQuotation: quotation,
    ).then((_) => _loadQuotations());
  }

  // ── Quick Actions Handlers ─────────────────────────────────────────────────

  Future<void> _handlePreviewOrPrint(SolarQuotation quotation) async {
    try {
      final pdfBytes = await SolarQuotationService.generateQuotationPdfBytes(
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

  Future<void> _handleShareWhatsApp(SolarQuotation quotation) async {
    try {
      await SolarQuotationService.shareViaWhatsApp(quotation);
    } catch (err) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open WhatsApp: $err')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Column(
        children: [
          _buildHeaderBanner(),
          _buildMetricsStrip(),
          _buildFilterBar(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredQuotations.isEmpty
                    ? _buildEmptyState()
                    : _buildQuotationsList(),
          ),
        ],
      ),
    );
  }

  // ── UI Components ──────────────────────────────────────────────────────────

  Widget _buildHeaderBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0D2B6F), Color(0xFF047857)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0x1A000000),
            blurRadius: 8,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.solar_power_rounded, color: Colors.white, size: 30),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Solar Customer Proposal Generator',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                SizedBox(height: 3),
                Text(
                  'Professional Sales Proposal • PM Surya Ghar Subsidy • 12-Month Generation Schedule • On-Grid Schematic • WhatsApp Sharing',
                  style: TextStyle(fontSize: 12, color: Color(0xFFE2E8F0)),
                ),
              ],
            ),
          ),
          // Action Buttons
          Wrap(
            spacing: 10,
            children: [
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white70),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.search_rounded, size: 18),
                label: const Text('Select from Master'),
                onPressed: _openSelectMasterCustomer,
              ),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFF59E0B),
                  foregroundColor: const Color(0xFF0F172A),
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  elevation: 2,
                ),
                icon: const Icon(Icons.add_rounded, size: 20, fontWeight: FontWeight.bold),
                label: const Text(
                  '+ New Customer Proposal',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                onPressed: _openForNewCustomer,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricsStrip() {
    final totalCount = _allQuotations.length;
    final residentialCount = _allQuotations.where((q) => q.quotationType == 'Residential').length;
    final commercialCount = _allQuotations.where((q) => q.quotationType == 'Commercial').length;
    final totalAmount = _allQuotations.fold<double>(0.0, (sum, q) => sum + q.grandTotal);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Row(
        children: [
          _buildMetricPill('Total Quotations', totalCount.toString(), Icons.request_quote_outlined, const Color(0xFF0D2B6F)),
          const SizedBox(width: 14),
          _buildMetricPill('Residential', residentialCount.toString(), Icons.home_rounded, const Color(0xFF047857)),
          const SizedBox(width: 14),
          _buildMetricPill('Commercial', commercialCount.toString(), Icons.business_rounded, const Color(0xFFB45309)),
          const SizedBox(width: 14),
          _buildMetricPill('Total Quoted Value', _currencyFormat.format(totalAmount), Icons.currency_rupee_rounded, const Color(0xFF4338CA)),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, size: 20),
            tooltip: 'Refresh Quotations',
            onPressed: _loadQuotations,
          ),
        ],
      ),
    );
  }

  Widget _buildMetricPill(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text('$label: ', style: TextStyle(fontSize: 11.5, color: Colors.grey.shade700)),
          Text(value, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }

  Widget _buildFilterBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
      color: Colors.white,
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                hintText: 'Search by Customer Name, Consumer No., Mobile, Village...',
                prefixIcon: const Icon(Icons.search_rounded, size: 20),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 16),
                        onPressed: () {
                          _searchController.clear();
                          _onSearchChanged('');
                        },
                      )
                    : null,
                isDense: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),
          ),
          const SizedBox(width: 14),
          // Type filter dropdown
          DropdownButton<String>(
            value: _typeFilter,
            underline: const SizedBox.shrink(),
            items: const [
              DropdownMenuItem(value: 'All', child: Text('All Types')),
              DropdownMenuItem(value: 'Residential', child: Text('Residential')),
              DropdownMenuItem(value: 'Commercial', child: Text('Commercial')),
            ],
            onChanged: (val) {
              if (val != null) {
                setState(() {
                  _typeFilter = val;
                  _applyFilters();
                });
              }
            },
          ),
          const SizedBox(width: 14),
          // Status filter dropdown
          DropdownButton<String>(
            value: _statusFilter,
            underline: const SizedBox.shrink(),
            items: const [
              DropdownMenuItem(value: 'All', child: Text('All Statuses')),
              DropdownMenuItem(value: 'Draft', child: Text('Draft')),
              DropdownMenuItem(value: 'Issued', child: Text('Issued')),
              DropdownMenuItem(value: 'Approved', child: Text('Approved')),
              DropdownMenuItem(value: 'Invoiced', child: Text('Invoiced')),
            ],
            onChanged: (val) {
              if (val != null) {
                setState(() {
                  _statusFilter = val;
                  _applyFilters();
                });
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFFECFDF5),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.solar_power_rounded, size: 54, color: Color(0xFF047857)),
            ),
            const SizedBox(height: 16),
            const Text(
              'No Solar Quotations Found',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
            ),
            const SizedBox(height: 6),
            const Text(
              'Create professional bilingual quotations with PM Surya Ghar subsidy,\n12-month generation forecast, On-Grid schematic, and WhatsApp sharing.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                OutlinedButton.icon(
                  onPressed: _openSelectMasterCustomer,
                  icon: const Icon(Icons.person_search_rounded, size: 18),
                  label: const Text('Option B: Select from Master'),
                ),
                const SizedBox(width: 12),
                FilledButton.icon(
                  style: FilledButton.styleFrom(backgroundColor: const Color(0xFF047857)),
                  onPressed: _openForNewCustomer,
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('Option A: New Customer Quotation'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuotationsList() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      itemCount: _filteredQuotations.length,
      itemBuilder: (ctx, idx) {
        final q = _filteredQuotations[idx];
        final isCommercial = q.quotationType == 'Commercial';

        return Card(
          elevation: 1,
          margin: const EdgeInsets.only(bottom: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: Color(0xFFE2E8F0)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                // Leading avatar
                CircleAvatar(
                  radius: 22,
                  backgroundColor: isCommercial ? const Color(0xFFFEF3C7) : const Color(0xFFEFF6FF),
                  child: Icon(
                    isCommercial ? Icons.business_rounded : Icons.home_rounded,
                    color: isCommercial ? const Color(0xFFB45309) : const Color(0xFF1D4ED8),
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                // Customer & System details
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            q.customerName,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5, color: Color(0xFF0F172A)),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: isCommercial ? const Color(0xFFFEF3C7) : const Color(0xFFD1FAE5),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              q.quotationType,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: isCommercial ? const Color(0xFFB45309) : const Color(0xFF047857),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Quotation: ${q.quotationNo} • Date: ${_dateFormat.format(q.quotationDate)} • Mobile: ${q.mobileNo}',
                        style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                      ),
                      if (q.villageCity.isNotEmpty || q.district.isNotEmpty)
                        Text(
                          'Location: ${q.villageCity}${q.district.isNotEmpty ? ', ${q.district}' : ''}',
                          style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                        ),
                    ],
                  ),
                ),
                // System Capacity & Financials
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEFF6FF),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              q.systemCapacity,
                              style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF1D4ED8)),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _currencyFormat.format(q.grandTotal),
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF047857)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      if (q.subsidyAmount > 0)
                        Text(
                          'Subsidy: ${_currencyFormat.format(q.subsidyAmount)} • Net: ${_currencyFormat.format(q.payableAfterSubsidy)}',
                          style: const TextStyle(fontSize: 11.5, color: Color(0xFF059669), fontWeight: FontWeight.w500),
                        )
                      else
                        Text(
                          'Payment: ${q.paymentMode}${q.monthlyEmi > 0 ? ' (EMI: ${_currencyFormat.format(q.monthlyEmi)})' : ''}',
                          style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                        ),
                    ],
                  ),
                ),
                // Action Buttons
                Wrap(
                  spacing: 6,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit_note_rounded, color: Color(0xFF0D2B6F)),
                      tooltip: 'Edit / Open in Generator',
                      onPressed: () => _openForQuotation(q),
                    ),
                    IconButton(
                      icon: const Icon(Icons.picture_as_pdf_rounded, color: Color(0xFF047857)),
                      tooltip: 'Preview & Download PDF',
                      onPressed: () => _handlePreviewOrPrint(q),
                    ),
                    IconButton(
                      icon: const Icon(Icons.share_rounded, color: Color(0xFF25D366)),
                      tooltip: 'Share on WhatsApp',
                      onPressed: () => _handleShareWhatsApp(q),
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
