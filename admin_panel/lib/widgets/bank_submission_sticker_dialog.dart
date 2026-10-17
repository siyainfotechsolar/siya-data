import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import '../models/consumer_record.dart';
import '../services/record_service.dart';
import '../services/bank_submission_sticker_service.dart';
import '../utils/responsive.dart';

class BankSubmissionStickerDialog extends StatefulWidget {
  final List<ConsumerRecord>? preselectedCustomers;
  final List<ConsumerRecord>? allCustomers;

  const BankSubmissionStickerDialog({
    super.key,
    this.preselectedCustomers,
    this.allCustomers,
  });

  static Future<void> show(
    BuildContext context, {
    List<ConsumerRecord>? preselectedCustomers,
    List<ConsumerRecord>? allCustomers,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => BankSubmissionStickerDialog(
        preselectedCustomers: preselectedCustomers,
        allCustomers: allCustomers,
      ),
    );
  }

  @override
  State<BankSubmissionStickerDialog> createState() => _BankSubmissionStickerDialogState();
}

class _BankSubmissionStickerDialogState extends State<BankSubmissionStickerDialog>
    with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  List<ConsumerRecord> _allList = [];
  final Set<String> _selectedIds = {};
  bool _isLoading = false;
  bool _onlyBankLoan = false;
  int _renderKey = 0;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    if (widget.preselectedCustomers != null) {
      for (final c in widget.preselectedCustomers!) {
        if (c.id != null) _selectedIds.add(c.id!);
      }
    }

    if (widget.allCustomers != null && widget.allCustomers!.isNotEmpty) {
      _allList = List.from(widget.allCustomers!);
      // Ensure preselected customers are also in _allList
      if (widget.preselectedCustomers != null) {
        for (final c in widget.preselectedCustomers!) {
          if (!_allList.any((e) => e.id == c.id)) {
            _allList.insert(0, c);
          }
        }
      }
      // If the passed list was just a single page, fetch all customers in background for complete search
      if (_allList.length < 300) {
        _loadCustomers(inBackground: true);
      }
    } else {
      _loadCustomers();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadCustomers({bool inBackground = false}) async {
    if (!inBackground) setState(() => _isLoading = true);
    try {
      final res = await RecordService.fetchRecords(
        page: 1,
        pageSize: 5000,
        workQueueScope: 'All',
        sortBy: 'name',
        ascending: true,
      );
      if (mounted) {
        setState(() {
          final existingIds = _allList.map((e) => e.id).toSet();
          for (final c in res.items) {
            if (!existingIds.contains(c.id)) {
              _allList.add(c);
            }
          }
          if (!inBackground) _allList = res.items;
          // Also merge preselected if not found
          if (widget.preselectedCustomers != null) {
            for (final c in widget.preselectedCustomers!) {
              if (!_allList.any((e) => e.id == c.id)) {
                _allList.insert(0, c);
              }
            }
          }
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted && !inBackground) setState(() => _isLoading = false);
    }
  }

  List<ConsumerRecord> get _filteredList {
    final query = _searchController.text.trim().toLowerCase();
    return _allList.where((c) {
      if (_onlyBankLoan && !c.isLoanCustomer) {
        return false;
      }
      if (query.isEmpty) return true;
      final name = c.name.toLowerCase();
      final no = c.consumerNo.toLowerCase();
      final mob = (c.mobile ?? '').toLowerCase();
      final appId = (c.applicationId ?? '').toLowerCase();
      final addr = (c.address ?? '').toLowerCase();
      return name.contains(query) ||
          no.contains(query) ||
          mob.contains(query) ||
          appId.contains(query) ||
          addr.contains(query);
    }).toList();
  }

  List<ConsumerRecord> get _selectedCustomers {
    // Preserve selection order based on user selection or filtered list
    final map = {for (final c in _allList) if (c.id != null) c.id!: c};
    return _selectedIds.map((id) => map[id]).whereType<ConsumerRecord>().toList();
  }

  void _selectAllFiltered() {
    setState(() {
      for (final c in _filteredList) {
        if (c.id != null) _selectedIds.add(c.id!);
      }
      _renderKey++;
    });
  }

  void _clearSelection() {
    setState(() {
      _selectedIds.clear();
      _renderKey++;
    });
  }

  void _toggleCustomer(String id, bool? selected) {
    setState(() {
      if (selected == true) {
        _selectedIds.add(id);
      } else {
        _selectedIds.remove(id);
      }
      _renderKey++;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = Responsive.isMobile(context);
    final theme = Theme.of(context);
    final selectedCount = _selectedIds.length;
    final pageCount = (selectedCount / 4).ceil();

    return Dialog(
      insetPadding: EdgeInsets.symmetric(
        horizontal: isMobile ? 8 : 24,
        vertical: isMobile ? 12 : 20,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: Container(
        width: isMobile ? double.infinity : 1280,
        height: isMobile ? double.infinity : 860,
        color: const Color(0xFFF8FAFC),
        child: Column(
          children: [
            // ── Dialog Header ──
            _buildDialogHeader(context, theme, selectedCount, pageCount, isMobile),

            // ── Body ──
            Expanded(
              child: isMobile
                  ? Column(
                      children: [
                        TabBar(
                          controller: _tabController,
                          labelColor: const Color(0xFF0F172A),
                          unselectedLabelColor: Colors.grey,
                          indicatorColor: const Color(0xFF0F172A),
                          tabs: [
                            Tab(text: 'Select Customers ($selectedCount)'),
                            Tab(text: 'Preview ($pageCount Pages)'),
                          ],
                        ),
                        Expanded(
                          child: TabBarView(
                            controller: _tabController,
                            children: [
                              _buildSelectionPanel(theme, isMobile),
                              _buildPreviewPanel(selectedCount, pageCount),
                            ],
                          ),
                        ),
                      ],
                    )
                  : Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Left Selection Sidebar (38% width)
                        SizedBox(
                          width: 440,
                          child: _buildSelectionPanel(theme, isMobile),
                        ),
                        const VerticalDivider(width: 1, thickness: 1, color: Color(0xFFE2E8F0)),
                        // Right PDF Preview (62% width)
                        Expanded(
                          child: _buildPreviewPanel(selectedCount, pageCount),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDialogHeader(
    BuildContext context,
    ThemeData theme,
    int selectedCount,
    int pageCount,
    bool isMobile,
  ) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 12 : 20,
        vertical: isMobile ? 10 : 14,
      ),
      decoration: const BoxDecoration(
        color: Color(0xFF0F172A), // Midnight Dark
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.print_rounded, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    const Text(
                      'Bank File Sticker Printing',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade400,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'A4 • 4 STICKERS / PAGE (A6)',
                        style: TextStyle(
                          color: Color(0xFF0F172A),
                          fontSize: 9.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  'SIYA INFOTECH & SOLAR ENERGY • SOLAR LOAN DOCUMENT FILE (PURE B&W)',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.75),
                    fontSize: 10.5,
                  ),
                ),
              ],
            ),
          ),
          if (!isMobile && selectedCount > 0) ...[
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFF0F172A),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              ),
              icon: const Icon(Icons.download_rounded, size: 16),
              label: const Text('Download PDF', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              onPressed: () => BankSubmissionStickerService.downloadPdf(_selectedCustomers),
            ),
            const SizedBox(width: 8),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF059669),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
              icon: const Icon(Icons.print, size: 16),
              label: const Text('Print Now', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              onPressed: () => BankSubmissionStickerService.printStickers(_selectedCustomers),
            ),
            const SizedBox(width: 12),
          ],
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white, size: 22),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectionPanel(ThemeData theme, bool isMobile) {
    final filtered = _filteredList;
    final selectedCount = _selectedIds.length;
    final totalFiltered = filtered.length;

    return Container(
      color: Colors.white,
      child: Column(
        children: [
          // Search & Filter Controls
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: 'Search customer, consumer no, mobile...',
                    hintStyle: const TextStyle(fontSize: 13),
                    prefixIcon: const Icon(Icons.search, size: 18),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 16),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {});
                            },
                          )
                        : null,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    filled: true,
                    fillColor: const Color(0xFFF1F5F9),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    FilterChip(
                      selected: _onlyBankLoan,
                      label: const Text('🏦 Bank Loan Only', style: TextStyle(fontSize: 11)),
                      visualDensity: VisualDensity.compact,
                      onSelected: (val) => setState(() => _onlyBankLoan = val),
                    ),
                    const Spacer(),
                    TextButton(
                      style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                      onPressed: _selectAllFiltered,
                      child: const Text('Select All', style: TextStyle(fontSize: 12)),
                    ),
                    const SizedBox(width: 4),
                    TextButton(
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        foregroundColor: Colors.red.shade700,
                      ),
                      onPressed: selectedCount > 0 ? _clearSelection : null,
                      child: const Text('Clear', style: TextStyle(fontSize: 12)),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Count Summary Banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            color: const Color(0xFFF8FAFC),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '$selectedCount selected of ${_allList.length}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                  ),
                ),
                Text(
                  'Showing $totalFiltered matching',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
          const Divider(height: 1, thickness: 1, color: Color(0xFFE2E8F0)),

          // Customer List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : filtered.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.search_off_rounded, size: 40, color: Colors.grey.shade400),
                            const SizedBox(height: 8),
                            const Text(
                              'No matching customers found',
                              style: TextStyle(fontSize: 13, color: Colors.grey),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        itemCount: filtered.length,
                        separatorBuilder: (ctx, idx) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
                        itemBuilder: (ctx, index) {
                          final c = filtered[index];
                          final id = c.id;
                          final isSelected = id != null && _selectedIds.contains(id);

                          return InkWell(
                            onTap: id != null ? () => _toggleCustomer(id, !isSelected) : null,
                            child: Container(
                              color: isSelected ? const Color(0xFFF0FDF4) : Colors.transparent,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              child: Row(
                                children: [
                                  Checkbox(
                                    value: isSelected,
                                    visualDensity: VisualDensity.compact,
                                    onChanged: id != null ? (val) => _toggleCustomer(id, val) : null,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                c.name,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 13,
                                                  color: Color(0xFF0F172A),
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            if (c.isLoanCustomer)
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFFFEF3C7),
                                                  borderRadius: BorderRadius.circular(4),
                                                  border: Border.all(color: const Color(0xFFFCD34D)),
                                                ),
                                                child: const Text(
                                                  'LOAN',
                                                  style: TextStyle(
                                                    fontSize: 9,
                                                    fontWeight: FontWeight.bold,
                                                    color: Color(0xFF92400E),
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                        const SizedBox(height: 2),
                                        Row(
                                          children: [
                                            Text(
                                              'No: ${c.consumerNo}',
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                                color: Colors.blueGrey.shade700,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            if (c.mobile != null && c.mobile!.isNotEmpty)
                                              Text(
                                                '• ${c.mobile}',
                                                style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                                              ),
                                            const Spacer(),
                                            Text(
                                              c.systemCapacity ?? '${c.capacityKw.toStringAsFixed(1)} kW',
                                              style: const TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                                color: Color(0xFF047857),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
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

  Widget _buildPreviewPanel(int selectedCount, int pageCount) {
    final isMobile = Responsive.isMobile(context);
    if (selectedCount == 0) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.label_outline_rounded, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 14),
            const Text(
              'No Customers Selected',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
            ),
            const SizedBox(height: 6),
            const Text(
              'Select one or more customers from the list to preview\nand print 2 bank file stickers per A4 page.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    final isOdd = selectedCount % 2 != 0;

    return Column(
      children: [
        // Page & Layout Info Banner
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          color: const Color(0xFFF1F5F9),
          child: Row(
            children: [
              const Icon(Icons.info_outline, size: 18, color: Color(0xFF334155)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '$selectedCount customer stickers → $pageCount A4 Landscape sheet(s) (4 A6 Landscape stickers per page).'
                  '${isOdd ? ' Remaining spaces remain blank for cutting.' : ' Full sheets.'}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF334155),
                  ),
                ),
              ),
              if (isMobile) ...[
                IconButton(
                  tooltip: 'Download PDF',
                  icon: const Icon(Icons.download_rounded, size: 20, color: Color(0xFF0F172A)),
                  onPressed: () => BankSubmissionStickerService.downloadPdf(_selectedCustomers),
                ),
                IconButton(
                  tooltip: 'Print',
                  icon: const Icon(Icons.print_rounded, size: 20, color: Color(0xFF059669)),
                  onPressed: () => BankSubmissionStickerService.printStickers(_selectedCustomers),
                ),
              ] else ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: const Color(0xFFCBD5E1)),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'A4 Landscape • 4 Stickers / Sheet (A6)',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ],
          ),
        ),

        // Live PDF Preview
        Expanded(
          child: PdfPreview(
            key: ValueKey('stickers_preview_${selectedCount}_$_renderKey'),
            build: (format) => BankSubmissionStickerService.generateStickersPdfBytes(_selectedCustomers),
            canChangeOrientation: false,
            canChangePageFormat: false,
            canDebug: false,
            allowPrinting: true,
            allowSharing: true,
            initialPageFormat: PdfPageFormat.a4.landscape,
            pdfFileName: 'Bank_Submission_Stickers_${selectedCount}Cust.pdf',
          ),
        ),
      ],
    );
  }
}
