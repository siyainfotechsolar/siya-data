import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'package:siya_shared/siya_shared.dart';
import '../services/sub_vendor_material_outward_pdf_service.dart';
import '../services/sub_vendor_material_outward_service.dart';
import '../widgets/searchable_material_picker_dialog.dart';

final _dateFormat = DateFormat('dd-MM-yyyy');
final _currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 2);
const List<String> _unitOptions = ['NOS', 'PCS', 'KG', 'MTR', 'SET', 'BOX'];
const List<double> _gstOptions = [0.0, 5.0, 12.0, 18.0, 28.0];

/// Sub-Vendor Material Outward Tracking Screen — Complete Module containing:
/// 1. Material Outward Entry (Bulk Entry with dynamic rows & stock deduction)
/// 2. Date-wise Outward History (Search, Filter, View, Edit, Cancel & Restores)
/// 3. Outward Reports (Date-wise, Sub Vendor-wise, Material-wise + Excel & Print)
class SubVendorMaterialOutwardScreen extends StatefulWidget {
  final int initialSubTabIndex;
  const SubVendorMaterialOutwardScreen({super.key, this.initialSubTabIndex = 0});

  @override
  State<SubVendorMaterialOutwardScreen> createState() => _SubVendorMaterialOutwardScreenState();
}

class _SubVendorMaterialOutwardScreenState extends State<SubVendorMaterialOutwardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Master Data
  List<SubVendor> _vendors = [];
  List<MaterialMasterItem> _materials = [];
  List<SubVendorMaterialOutward> _allOutwards = [];

  bool _isLoading = true;
  String? _errorMessage;

  // Entry Form State
  DateTime _entryDate = DateTime.now();
  SubVendor? _selectedVendor;
  final TextEditingController _remarksCtrl = TextEditingController();
  final List<_OutwardRowState> _entryRows = [];
  bool _isSavingEntry = false;

  // History Filter State
  DateTime? _filterFromDate;
  DateTime? _filterToDate;
  String _filterVendorId = 'All';
  String _filterMaterialName = '';
  final TextEditingController _searchNumberCtrl = TextEditingController();
  String _filterStatus = 'All'; // 'All', 'Active', 'Cancelled'

  // Reports State
  int _selectedReportType = 0; // 0: Date-wise, 1: Sub Vendor-wise, 2: Material-wise, 3: Period Summary
  String _periodGrouping = 'MONTHLY'; // 'DAILY', 'MONTHLY', 'FINANCIAL_YEAR'
  DateTime? _reportFromDate;
  DateTime? _reportToDate;
  String _reportVendorId = 'All';

  // Branding colors
  static const Color navyColor = Color(0xFF0D2B6F);
  static const Color greenColor = Color(0xFF059669);
  static const Color amberColor = Color(0xFFD97706);
  static const Color redColor = Color(0xFFDC2626);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this, initialIndex: widget.initialSubTabIndex);
    _loadInitialData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _remarksCtrl.dispose();
    _searchNumberCtrl.dispose();
    for (final r in _entryRows) {
      r.dispose();
    }
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final vendors = await SubVendorMaterialOutwardService.fetchActiveSubVendors();
      final materials = await SubVendorMaterialOutwardService.fetchMaterialMaster();
      final outwards = await SubVendorMaterialOutwardService.fetchOutwards();

      if (mounted) {
        setState(() {
          _vendors = vendors;
          _materials = materials;
          _allOutwards = outwards;
          _isLoading = false;

          // Initialize with 1 empty row if entry form is empty
          if (_entryRows.isEmpty && materials.isNotEmpty) {
            _addMaterialRow();
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  static String _normalizeUnit(String rawUnit) {
    final u = rawUnit.trim().toUpperCase();
    if (u == 'SETS') return 'SET';
    if (u == 'M' || u == 'METERS' || u == 'METRE') return 'MTR';
    if (_unitOptions.contains(u)) return u;
    return 'NOS';
  }

  void _addMaterialRow([MaterialMasterItem? initialMat, double initialQty = 1.0]) {
    final mat = initialMat ?? (_materials.isNotEmpty ? _materials.first : null);
    setState(() {
      _entryRows.add(_OutwardRowState(
        selectedMaterial: mat,
        selectedUnit: _normalizeUnit(mat?.unit ?? 'NOS'),
        quantityCtrl: TextEditingController(text: initialQty > 0 ? initialQty.toString() : '1'),
        rateCtrl: TextEditingController(
          text: mat != null && mat.defaultRate > 0 ? mat.defaultRate.toStringAsFixed(2) : '0',
        ),
        gstPercentage: 0.0,
      ));
    });
  }

  void _removeMaterialRow(int index) {
    if (_entryRows.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('At least one material row is required.'), backgroundColor: Colors.orange),
      );
      return;
    }
    setState(() {
      final removed = _entryRows.removeAt(index);
      removed.dispose();
    });
  }

  double get _currentTotalQty =>
      SubVendorFinancialEngine.sumPaise(_entryRows, (r) => r.quantity);
  double get _currentSubtotal =>
      SubVendorFinancialEngine.sumPaise(_entryRows, (r) => r.baseAmount);
  double get _currentTotalGst =>
      SubVendorFinancialEngine.sumPaise(_entryRows, (r) => r.gstAmount);
  double get _currentGrandTotal =>
      SubVendorFinancialEngine.sumPaise(_entryRows, (r) => r.finalPrice);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Column(
        children: [
          _buildHeaderBar(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: navyColor))
                : _errorMessage != null
                    ? _buildErrorBanner()
                    : TabBarView(
                        controller: _tabController,
                        children: [
                          _buildOutwardEntryTab(),
                          _buildOutwardHistoryTab(),
                          _buildOutwardReportsTab(),
                        ],
                      ),
          ),
        ],
      ),
    );
  }

  // ============================================================================
  // HEADER BAR WITH NAVIGATION PILLS
  // ============================================================================
  Widget _buildHeaderBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0), width: 1.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: navyColor.withOpacity(0.08), borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.outbox_rounded, color: navyColor, size: 24),
          ),
          const SizedBox(width: 14),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Sub Vendor Material Outward Tracking',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: navyColor),
              ),
              Text(
                'Issue materials date-wise with Rate, GST billing, ledger sync, history & reports',
                style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
              ),
            ],
          ),
          const Spacer(),
          // Segmented Tab Switcher
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(10)),
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              indicator: BoxDecoration(
                color: navyColor,
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(color: navyColor.withOpacity(0.2), blurRadius: 4, offset: const Offset(0, 2)),
                ],
              ),
              labelColor: Colors.white,
              unselectedLabelColor: const Color(0xFF475569),
              labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              tabs: const [
                Tab(icon: Icon(Icons.add_shopping_cart, size: 16), text: 'Outward Entry'),
                Tab(icon: Icon(Icons.history_rounded, size: 16), text: 'Date-wise History'),
                Tab(icon: Icon(Icons.analytics_outlined, size: 16), text: 'Outward Reports'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorBanner() {
    return Center(
      child: Card(
        margin: const EdgeInsets.all(24),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: redColor, size: 48),
              const SizedBox(height: 12),
              Text('Failed to load data: $_errorMessage', textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _loadInitialData,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
                style: ElevatedButton.styleFrom(backgroundColor: navyColor, foregroundColor: Colors.white),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================================
  // TAB 1: MATERIAL OUTWARD ENTRY
  // ============================================================================
  Widget _buildOutwardEntryTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section 1: Header Details Card
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Color(0xFFE2E8F0))),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.inventory_2, color: navyColor, size: 20),
                      SizedBox(width: 8),
                      Text('1. Outward Dispatch Details', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: navyColor)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final isMobile = constraints.maxWidth < 700;
                      return isMobile
                          ? Column(
                              children: [
                                _buildDatePickerField(),
                                const SizedBox(height: 14),
                                _buildVendorSelectorField(),
                              ],
                            )
                          : Row(
                              children: [
                                Expanded(flex: 3, child: _buildDatePickerField()),
                                const SizedBox(width: 16),
                                Expanded(flex: 5, child: _buildVendorSelectorField()),
                              ],
                            );
                    },
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _remarksCtrl,
                    decoration: InputDecoration(
                      labelText: 'Remarks / Dispatch Notes (Optional)',
                      hintText: 'e.g. Issued for Site Shindkheda (Consumer: Raju Chaudhari)',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      prefixIcon: const Icon(Icons.note_alt_outlined, size: 18),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Section 2: Multiple Material Rows Card
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Color(0xFFE2E8F0))),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.format_list_bulleted_rounded, color: greenColor, size: 20),
                          SizedBox(width: 8),
                          Text('2. Material List (Add Multiple Rows)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: navyColor)),
                        ],
                      ),
                      ElevatedButton.icon(
                        onPressed: () => _addMaterialRow(),
                        icon: const Icon(Icons.add, size: 16),
                        label: const Text('Add Material Row'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: greenColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Material Rows List
                  ..._entryRows.asMap().entries.map((entry) {
                    return _buildMaterialRowCard(
                      idx: entry.key,
                      row: entry.value,
                      onChanged: () => setState(() {}),
                      onRemove: () => _removeMaterialRow(entry.key),
                    );
                  }),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Section 3: Live Summary & Bulk Save Action Bar
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4)),
              ],
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isCompact = constraints.maxWidth < 900;
                final kpiWrap = Wrap(
                  spacing: 24,
                  runSpacing: 14,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _buildSummaryKpi('Total Materials', '${_entryRows.length} Items', Icons.layers_outlined, navyColor),
                    _buildSummaryKpi('Total Quantity', _currentTotalQty.toStringAsFixed(2), Icons.numbers, amberColor),
                    _buildSummaryKpi('Subtotal', _currencyFormat.format(_currentSubtotal), Icons.receipt_long_outlined, const Color(0xFF334155)),
                    _buildSummaryKpi('Total GST', _currencyFormat.format(_currentTotalGst), Icons.percent_rounded, const Color(0xFF0284C7)),
                    _buildSummaryKpi('Grand Total', _currencyFormat.format(_currentGrandTotal), Icons.currency_rupee_rounded, greenColor),
                  ],
                );

                final saveBtn = ElevatedButton.icon(
                  onPressed: _isSavingEntry ? null : _handleSaveOutwardEntry,
                  icon: _isSavingEntry
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.check_circle_outline, size: 18),
                  label: Text(_isSavingEntry ? 'Saving Outward...' : 'Save Material Outward'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: navyColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                );

                if (isCompact) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      kpiWrap,
                      const Divider(height: 24),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Target Sub-Vendor', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                                Text(
                                  _selectedVendor?.name ?? 'Please select a Sub-Vendor',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: _selectedVendor != null ? greenColor : redColor,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          saveBtn,
                        ],
                      ),
                    ],
                  );
                }

                return Row(
                  children: [
                    Expanded(child: kpiWrap),
                    const SizedBox(width: 16),
                    saveBtn,
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  /// Responsive Material Row Card (used in both Entry Tab and Edit Dialog).
  Widget _buildMaterialRowCard({
    required int idx,
    required _OutwardRowState row,
    required VoidCallback onChanged,
    required VoidCallback onRemove,
  }) {
    final materialPicker = InkWell(
      onTap: () => _openMaterialSearchDialog(row, onChanged),
      borderRadius: BorderRadius.circular(6),
      child: InputDecorator(
        decoration: const InputDecoration(
          labelText: 'Material Name *',
          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          border: OutlineInputBorder(),
          suffixIcon: Icon(Icons.search, size: 18),
        ),
        child: Text(
          row.selectedMaterial?.itemName ?? 'Search or add material...',
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 13,
            fontWeight: row.selectedMaterial != null ? FontWeight.w600 : FontWeight.normal,
            color: row.selectedMaterial != null ? const Color(0xFF0F172A) : const Color(0xFF94A3B8),
          ),
        ),
      ),
    );

    final qtyField = TextField(
      controller: row.quantityCtrl,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: const InputDecoration(
        labelText: 'Qty *',
        hintText: '0',
        contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        border: OutlineInputBorder(),
      ),
      onChanged: (_) => onChanged(),
    );

    final unitField = DropdownButtonFormField<String>(
      value: _unitOptions.contains(row.selectedUnit) ? row.selectedUnit : 'NOS',
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: 'Unit',
        contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        border: OutlineInputBorder(),
      ),
      items: _unitOptions.map((u) => DropdownMenuItem(value: u, child: Text(u, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)))).toList(),
      onChanged: (val) {
        if (val != null) {
          row.selectedUnit = val;
          onChanged();
        }
      },
    );

    final rateField = TextField(
      controller: row.rateCtrl,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: const InputDecoration(
        labelText: 'Rate (₹)',
        hintText: '0.00',
        contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        border: OutlineInputBorder(),
      ),
      onChanged: (_) => onChanged(),
    );

    final gstField = DropdownButtonFormField<double>(
      value: _gstOptions.contains(row.gstPercentage) ? row.gstPercentage : 0.0,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: 'GST %',
        contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        border: OutlineInputBorder(),
      ),
      items: _gstOptions.map((g) => DropdownMenuItem(
        value: g,
        child: Text('${g.toInt()}%', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
      )).toList(),
      onChanged: (val) {
        if (val != null) {
          row.gstPercentage = val;
          onChanged();
        }
      },
    );

    final priceSummary = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFFCBD5E1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'GST: ${_currencyFormat.format(row.gstAmount)}',
            style: const TextStyle(fontSize: 10, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
          ),
          Text(
            _currencyFormat.format(row.finalPrice),
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: greenColor),
          ),
        ],
      ),
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isDesktop = constraints.maxWidth >= 900;
          if (isDesktop) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor: navyColor.withOpacity(0.1),
                  child: Text('${idx + 1}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: navyColor)),
                ),
                const SizedBox(width: 10),
                Expanded(flex: 4, child: materialPicker),
                const SizedBox(width: 10),
                Expanded(flex: 2, child: qtyField),
                const SizedBox(width: 10),
                SizedBox(width: 92, child: unitField),
                const SizedBox(width: 10),
                Expanded(flex: 2, child: rateField),
                const SizedBox(width: 10),
                SizedBox(width: 88, child: gstField),
                const SizedBox(width: 10),
                SizedBox(width: 130, child: priceSummary),
                const SizedBox(width: 4),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: redColor, size: 20),
                  tooltip: 'Remove Row',
                  onPressed: onRemove,
                ),
              ],
            );
          }

          // Mobile / Tablet stacked layout
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 13,
                    backgroundColor: navyColor.withOpacity(0.1),
                    child: Text('${idx + 1}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: navyColor)),
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: materialPicker),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: redColor, size: 20),
                    tooltip: 'Remove Row',
                    onPressed: onRemove,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(flex: 2, child: qtyField),
                  const SizedBox(width: 8),
                  Expanded(flex: 2, child: unitField),
                  const SizedBox(width: 8),
                  Expanded(flex: 3, child: rateField),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(flex: 2, child: gstField),
                  const SizedBox(width: 10),
                  Expanded(flex: 3, child: priceSummary),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  /// Opens the Central Searchable Material Master Dialog with "+ Add New Material".
  Future<void> _openMaterialSearchDialog(_OutwardRowState row, VoidCallback onChanged) async {
    final picked = await showCentralMaterialPickerDialog(
      context,
      initialMaterials: _materials,
      currentSelection: row.selectedMaterial,
      defaultUnit: row.selectedUnit,
      defaultRate: row.rate,
    );
    if (picked != null && mounted) {
      setState(() {
        row.selectedMaterial = picked;
        row.selectedUnit = _normalizeUnit(picked.unit);
        if (picked.defaultRate > 0) {
          row.rateCtrl.text = picked.defaultRate.toStringAsFixed(2);
        }
      });
      onChanged();
    }
  }

  Widget _buildDatePickerField() {
    return InkWell(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: _entryDate,
          firstDate: DateTime(2024),
          lastDate: DateTime(2030),
        );
        if (picked != null) setState(() => _entryDate = picked);
      },
      borderRadius: BorderRadius.circular(8),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: 'Outward Date',
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          prefixIcon: const Icon(Icons.calendar_today, size: 18),
        ),
        child: Text(_dateFormat.format(_entryDate), style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildVendorSelectorField() {
    return DropdownButtonFormField<SubVendor>(
      value: _selectedVendor,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: 'Select Sub Vendor *',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        prefixIcon: const Icon(Icons.person_pin_outlined, size: 18),
      ),
      items: _vendors.map((v) {
        return DropdownMenuItem(
          value: v,
          child: Text(
            '${v.name} (${v.vendorCode})',
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          ),
        );
      }).toList(),
      onChanged: (val) {
        setState(() => _selectedVendor = val);
      },
    );
  }

  Widget _buildSummaryKpi(String label, String value, IconData icon, Color color) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
            Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: color)),
          ],
        ),
      ],
    );
  }

  Future<void> _handleSaveOutwardEntry() async {
    if (_selectedVendor == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a Sub-Vendor.'), backgroundColor: redColor),
      );
      return;
    }

    if (_entryRows.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one material row.'), backgroundColor: redColor),
      );
      return;
    }

    final List<SubVendorMaterialOutwardItem> items = [];
    for (int i = 0; i < _entryRows.length; i++) {
      final r = _entryRows[i];
      if (r.selectedMaterial == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Row ${i + 1}: Please select a material.'), backgroundColor: redColor),
        );
        return;
      }
      final q = r.quantity;
      if (q <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Row ${i + 1}: Quantity must be greater than zero.'), backgroundColor: redColor),
        );
        return;
      }
      if (r.rate < 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Row ${i + 1}: Rate cannot be negative.'), backgroundColor: redColor),
        );
        return;
      }

      items.add(SubVendorMaterialOutwardItem(
        id: '',
        outwardId: '',
        materialId: r.selectedMaterial!.id,
        materialName: r.selectedMaterial!.itemName,
        unit: r.selectedUnit,
        quantity: q,
        unitRate: r.rate,
        baseAmount: r.baseAmount,
        gstPercentage: r.gstPercentage,
        gstAmount: r.gstAmount,
        totalPrice: r.finalPrice,
      ));
    }

    setState(() => _isSavingEntry = true);

    try {
      final created = await SubVendorMaterialOutwardService.recordOutward(
        vendorId: _selectedVendor!.id,
        vendorName: _selectedVendor!.name,
        outwardDate: _entryDate,
        remarks: _remarksCtrl.text.trim().isNotEmpty ? _remarksCtrl.text.trim() : null,
        items: items,
      );

      // Refresh outwards list
      await _loadInitialData();

      // Reset form
      _remarksCtrl.clear();
      _entryRows.clear();
      _addMaterialRow();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text('Material Outward ${created.outwardNumber} saved (${_currencyFormat.format(created.totalValue)})!'),
                ),
              ],
            ),
            backgroundColor: greenColor,
            behavior: SnackBarBehavior.floating,
          ),
        );

        // Switch to history tab
        _tabController.animateTo(1);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '').replaceAll('StateError: ', '')),
            backgroundColor: redColor,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSavingEntry = false);
    }
  }

  // ============================================================================
  // TAB 2: DATE-WISE OUTWARD HISTORY
  // ============================================================================
  Widget _buildOutwardHistoryTab() {
    final filtered = SubVendorMaterialOutwardService.filterOutwards(
      _allOutwards,
      fromDate: _filterFromDate,
      toDate: _filterToDate,
      vendorId: _filterVendorId,
      materialName: _filterMaterialName,
      outwardNumber: _searchNumberCtrl.text,
      includeCancelled: _filterStatus != 'Active',
    ).where((e) {
      if (_filterStatus == 'Active') return e.isActive;
      if (_filterStatus == 'Cancelled') return e.isCancelled;
      return true;
    }).toList();

    return Column(
      children: [
        // Filter Bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          color: Colors.white,
          child: Column(
            children: [
              Row(
                children: [
                  // From Date
                  InkWell(
                    onTap: () async {
                      final p = await showDatePicker(
                        context: context,
                        initialDate: _filterFromDate ?? DateTime.now().subtract(const Duration(days: 30)),
                        firstDate: DateTime(2024),
                        lastDate: DateTime(2030),
                      );
                      if (p != null) setState(() => _filterFromDate = p);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(border: Border.all(color: const Color(0xFFCBD5E1)), borderRadius: BorderRadius.circular(6)),
                      child: Row(
                        children: [
                          const Icon(Icons.date_range, size: 16, color: navyColor),
                          const SizedBox(width: 6),
                          Text(_filterFromDate != null ? _dateFormat.format(_filterFromDate!) : 'From Date', style: const TextStyle(fontSize: 12)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // To Date
                  InkWell(
                    onTap: () async {
                      final p = await showDatePicker(
                        context: context,
                        initialDate: _filterToDate ?? DateTime.now(),
                        firstDate: DateTime(2024),
                        lastDate: DateTime(2030),
                      );
                      if (p != null) setState(() => _filterToDate = p);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(border: Border.all(color: const Color(0xFFCBD5E1)), borderRadius: BorderRadius.circular(6)),
                      child: Row(
                        children: [
                          const Icon(Icons.date_range, size: 16, color: navyColor),
                          const SizedBox(width: 6),
                          Text(_filterToDate != null ? _dateFormat.format(_filterToDate!) : 'To Date', style: const TextStyle(fontSize: 12)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Vendor Filter
                  Expanded(
                    flex: 2,
                    child: DropdownButtonFormField<String>(
                      value: _filterVendorId,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Filter Vendor',
                        contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        const DropdownMenuItem(value: 'All', child: Text('All Sub-Vendors', style: TextStyle(fontSize: 12))),
                        ..._vendors.map((v) => DropdownMenuItem(value: v.id, child: Text(v.name, style: const TextStyle(fontSize: 12)))),
                      ],
                      onChanged: (val) {
                        if (val != null) setState(() => _filterVendorId = val);
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Outward Number Search
                  Expanded(
                    flex: 2,
                    child: TextField(
                      controller: _searchNumberCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Outward Number',
                        hintText: 'OUT-...',
                        prefixIcon: Icon(Icons.search, size: 16),
                        contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Status Filter
                  DropdownButton<String>(
                    value: _filterStatus,
                    items: const [
                      DropdownMenuItem(value: 'All', child: Text('All Status', style: TextStyle(fontSize: 12))),
                      DropdownMenuItem(value: 'Active', child: Text('Active Only', style: TextStyle(fontSize: 12))),
                      DropdownMenuItem(value: 'Cancelled', child: Text('Cancelled Only', style: TextStyle(fontSize: 12))),
                    ],
                    onChanged: (val) {
                      if (val != null) setState(() => _filterStatus = val);
                    },
                  ),
                  const SizedBox(width: 8),
                  // Clear Filters
                  IconButton(
                    icon: const Icon(Icons.refresh, color: navyColor, size: 20),
                    tooltip: 'Reset Filters',
                    onPressed: () {
                      setState(() {
                        _filterFromDate = null;
                        _filterToDate = null;
                        _filterVendorId = 'All';
                        _filterMaterialName = '';
                        _searchNumberCtrl.clear();
                        _filterStatus = 'All';
                      });
                    },
                  ),
                ],
              ),
            ],
          ),
        ),

        // History Table / List
        Expanded(
          child: filtered.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.inventory_2_outlined, size: 48, color: Colors.grey),
                      SizedBox(height: 12),
                      Text('No outward entries found matching criteria.', style: TextStyle(color: Colors.grey)),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(20),
                  itemCount: filtered.length,
                  itemBuilder: (context, i) {
                    final outward = filtered[i];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: BorderSide(color: outward.isCancelled ? Colors.red.shade200 : const Color(0xFFE2E8F0)),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            // Icon Status
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: outward.isActive ? greenColor.withOpacity(0.1) : redColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                outward.isActive ? Icons.outbox : Icons.cancel_outlined,
                                color: outward.isActive ? greenColor : redColor,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 16),
                            // Details
                            Expanded(
                              flex: 3,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        outward.outwardNumber,
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                          color: outward.isActive ? navyColor : Colors.grey.shade600,
                                          decoration: outward.isCancelled ? TextDecoration.lineThrough : null,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: outward.isActive ? Colors.green.shade50 : Colors.red.shade50,
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          outward.status.toUpperCase(),
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: outward.isActive ? Colors.green.shade800 : Colors.red.shade800,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Sub-Vendor: ${outward.vendorName} | Date: ${_dateFormat.format(outward.outwardDate)}',
                                    style: const TextStyle(fontSize: 12, color: Color(0xFF475569)),
                                  ),
                                  if (outward.remarks != null && outward.remarks!.isNotEmpty)
                                    Text('Notes: ${outward.remarks}', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                                  if (outward.isCancelled && outward.cancellationReason != null)
                                    Text(
                                      'Cancellation Reason: ${outward.cancellationReason}',
                                      style: const TextStyle(fontSize: 11, color: redColor, fontWeight: FontWeight.bold),
                                    ),
                                ],
                              ),
                            ),
                            // Items and Quantity Summary
                            Expanded(
                              flex: 2,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('${outward.totalItems} Materials Included', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                  Text('Total Qty: ${outward.totalQuantity.toStringAsFixed(1)}', style: const TextStyle(fontSize: 12, color: amberColor, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                            // Action Buttons
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // View Details
                                IconButton(
                                  icon: const Icon(Icons.visibility_outlined, color: navyColor, size: 20),
                                  tooltip: 'View Material Details',
                                  onPressed: () => _showOutwardDetailsDialog(outward),
                                ),
                                // Print Slip
                                IconButton(
                                  icon: const Icon(Icons.print_outlined, color: greenColor, size: 20),
                                  tooltip: 'Print Outward Slip',
                                  onPressed: () async {
                                    final bytes = await SubVendorMaterialOutwardPdfService.generateOutwardSlipPdfBytes(outward);
                                    await Printing.layoutPdf(onLayout: (_) => bytes, name: 'Outward_${outward.outwardNumber}.pdf');
                                  },
                                ),
                                // Edit
                                if (outward.isActive)
                                  IconButton(
                                    icon: const Icon(Icons.edit_outlined, color: amberColor, size: 20),
                                    tooltip: 'Edit Outward Entry',
                                    onPressed: () => _showEditOutwardDialog(outward),
                                  ),
                                // Cancel
                                if (outward.isActive)
                                  IconButton(
                                    icon: const Icon(Icons.cancel_outlined, color: redColor, size: 20),
                                    tooltip: 'Cancel Outward Entry',
                                    onPressed: () => _showCancelOutwardDialog(outward),
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
    );
  }

  // ============================================================================
  // TAB 3: OUTWARD REPORTS & EXPORTS
  // ============================================================================
  Widget _buildOutwardReportsTab() {
    final activeOutwards = SubVendorMaterialOutwardService.filterOutwards(
      _allOutwards,
      fromDate: _reportFromDate,
      toDate: _reportToDate,
      vendorId: _reportVendorId,
      includeCancelled: false, // Rule 7: Cancelled entries must not count in active totals
    );

    return Column(
      children: [
        // Report Selector & Filter Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          color: Colors.white,
          child: Row(
            children: [
              // Segmented Report Types
              SegmentedButton<int>(
                segments: const [
                  ButtonSegment(value: 0, label: Text('A. Date-wise Report', style: TextStyle(fontSize: 12))),
                  ButtonSegment(value: 1, label: Text('B. Sub Vendor-wise', style: TextStyle(fontSize: 12))),
                  ButtonSegment(value: 2, label: Text('C. Material-wise', style: TextStyle(fontSize: 12))),
                  ButtonSegment(value: 3, label: Text('D. Daily / Monthly / FY', style: TextStyle(fontSize: 12))),
                ],
                selected: {_selectedReportType},
                onSelectionChanged: (set) {
                  setState(() => _selectedReportType = set.first);
                },
              ),
              const Spacer(),
              // Export to Excel Button
              OutlinedButton.icon(
                icon: const Icon(Icons.table_view_outlined, color: greenColor, size: 18),
                label: const Text('Export Excel (CSV)', style: TextStyle(color: greenColor, fontWeight: FontWeight.bold)),
                style: OutlinedButton.styleFrom(side: const BorderSide(color: greenColor)),
                onPressed: () => _handleExportReportCsv(activeOutwards),
              ),
              const SizedBox(width: 10),
              // Print / PDF Button
              ElevatedButton.icon(
                icon: const Icon(Icons.print, size: 18),
                label: const Text('Print / PDF Report'),
                style: ElevatedButton.styleFrom(backgroundColor: navyColor, foregroundColor: Colors.white),
                onPressed: () => _handlePrintReportPdf(activeOutwards),
              ),
            ],
          ),
        ),

        // Report Content View
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: _selectedReportType == 0
                ? _buildDateWiseReportView(activeOutwards)
                : _selectedReportType == 1
                    ? _buildSubVendorWiseReportView(activeOutwards)
                    : _selectedReportType == 2
                        ? _buildMaterialWiseReportView(activeOutwards)
                        : _buildPeriodSummaryReportView(activeOutwards),
          ),
        ),
      ],
    );
  }

  // Report A View: Date-wise List (with Full Monetary Subtotal, GST, Grand Total)
  Widget _buildDateWiseReportView(List<SubVendorMaterialOutward> outwards) {
    final rows = SubVendorMaterialOutwardService.generateDateWiseReportRows(outwards);
    final totalQty = SubVendorFinancialEngine.sumPaise(rows, (r) => r['quantity'] as double);
    final totalSub = SubVendorFinancialEngine.sumPaise(rows, (r) => r['base_amount'] as double);
    final totalGst = SubVendorFinancialEngine.sumPaise(rows, (r) => r['gst_amount'] as double);
    final totalVal = SubVendorFinancialEngine.sumPaise(rows, (r) => r['total_price'] as double);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: const BorderSide(color: Color(0xFFE2E8F0))),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Date-wise Material Outward Report', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: navyColor)),
                Text(
                  'Items: ${rows.length} | Qty: ${totalQty.toStringAsFixed(2)} | Subtotal: ${_currencyFormat.format(totalSub)} | GST: ${_currencyFormat.format(totalGst)} | Grand Total: ${_currencyFormat.format(totalVal)}',
                  style: const TextStyle(fontWeight: FontWeight.bold, color: greenColor, fontSize: 12.5),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: rows.isEmpty
                ? const Center(child: Text('No active outward records for the selected period.'))
                : SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: SingleChildScrollView(
                      child: DataTable(
                        headingRowColor: WidgetStateProperty.all(const Color(0xFFF1F5F9)),
                        columns: const [
                          DataColumn(label: Text('Outward No', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Date', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Sub Vendor', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Material Name', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Unit', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Qty', style: TextStyle(fontWeight: FontWeight.bold)), numeric: true),
                          DataColumn(label: Text('Rate (₹)', style: TextStyle(fontWeight: FontWeight.bold)), numeric: true),
                          DataColumn(label: Text('Base Amt (₹)', style: TextStyle(fontWeight: FontWeight.bold)), numeric: true),
                          DataColumn(label: Text('GST %', style: TextStyle(fontWeight: FontWeight.bold)), numeric: true),
                          DataColumn(label: Text('GST Amt (₹)', style: TextStyle(fontWeight: FontWeight.bold)), numeric: true),
                          DataColumn(label: Text('Final Total (₹)', style: TextStyle(fontWeight: FontWeight.bold)), numeric: true),
                        ],
                        rows: rows.map((r) {
                          return DataRow(
                            cells: [
                              DataCell(Text(r['outward_number'].toString(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                              DataCell(Text(_dateFormat.format(r['outward_date'] as DateTime), style: const TextStyle(fontSize: 12))),
                              DataCell(Text(r['vendor_name'].toString(), style: const TextStyle(fontSize: 12))),
                              DataCell(Text(r['material_name'].toString(), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
                              DataCell(Text(r['unit'].toString(), style: const TextStyle(fontSize: 12))),
                              DataCell(Text((r['quantity'] as double).toStringAsFixed(2), style: const TextStyle(fontWeight: FontWeight.bold))),
                              DataCell(Text(_currencyFormat.format(r['unit_rate'] as double), style: const TextStyle(fontSize: 12))),
                              DataCell(Text(_currencyFormat.format(r['base_amount'] as double), style: const TextStyle(fontSize: 12))),
                              DataCell(Text('${(r['gst_percentage'] as double).toStringAsFixed(0)}%', style: const TextStyle(fontSize: 12))),
                              DataCell(Text(_currencyFormat.format(r['gst_amount'] as double), style: const TextStyle(fontSize: 12))),
                              DataCell(Text(_currencyFormat.format(r['total_price'] as double), style: const TextStyle(fontWeight: FontWeight.bold, color: greenColor))),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  // Report B View: Sub Vendor-wise Summary (with exact Subtotal, GST & Total Value)
  Widget _buildSubVendorWiseReportView(List<SubVendorMaterialOutward> outwards) {
    final summaries = SubVendorMaterialOutwardService.generateSubVendorWiseSummary(outwards);

    return ListView.builder(
      itemCount: summaries.length,
      itemBuilder: (context, i) {
        final v = summaries[i];
        final matSummary = v['materials_summary'] as Map<String, double>;
        final matValSummary = (v['materials_value_summary'] as Map<String, double>?) ?? const {};

        return Card(
          margin: const EdgeInsets.only(bottom: 14),
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: const BorderSide(color: Color(0xFFE2E8F0))),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(v['vendor_name'].toString(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: navyColor)),
                    Text(
                      'Entries: ${v['total_outwards']} | Qty: ${(v['total_quantity'] as double).toStringAsFixed(2)} | Subtotal: ${_currencyFormat.format((v['total_subtotal'] as num?)?.toDouble() ?? 0)} | GST: ${_currencyFormat.format((v['total_gst'] as num?)?.toDouble() ?? 0)} | Grand Total: ${_currencyFormat.format((v['total_value'] as num?)?.toDouble() ?? 0)}',
                      style: const TextStyle(fontWeight: FontWeight.bold, color: greenColor, fontSize: 12.5),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text('Material-wise Issued Summary:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: matSummary.entries.map((m) {
                    final val = matValSummary[m.key] ?? 0.0;
                    return Chip(
                      backgroundColor: const Color(0xFFF1F5F9),
                      label: Text('${m.key}: ${m.value.toStringAsFixed(2)} (${_currencyFormat.format(val)})', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Report C View: Material-wise Summary (with Taxable, GST & Grand Total ₹)
  Widget _buildMaterialWiseReportView(List<SubVendorMaterialOutward> outwards) {
    final summaries = SubVendorMaterialOutwardService.generateMaterialWiseSummary(outwards);

    return ListView.builder(
      itemCount: summaries.length,
      itemBuilder: (context, i) {
        final m = summaries[i];
        final vBreakdown = m['vendor_breakdown'] as Map<String, double>;
        final vValBreakdown = (m['vendor_value_breakdown'] as Map<String, double>?) ?? const {};

        return Card(
          margin: const EdgeInsets.only(bottom: 14),
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: const BorderSide(color: Color(0xFFE2E8F0))),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(m['material_name'].toString(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: navyColor)),
                    Text(
                      'Qty: ${(m['total_quantity'] as double).toStringAsFixed(2)} ${m['unit']} | Taxable: ${_currencyFormat.format((m['total_taxable'] as num?)?.toDouble() ?? 0)} | GST: ${_currencyFormat.format((m['total_gst'] as num?)?.toDouble() ?? 0)} | Total: ${_currencyFormat.format((m['total_value'] as num?)?.toDouble() ?? 0)}',
                      style: const TextStyle(fontWeight: FontWeight.bold, color: amberColor, fontSize: 12.5),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                const Text('Sub-Vendor Breakdown:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: vBreakdown.entries.map((v) {
                    final val = vValBreakdown[v.key] ?? 0.0;
                    return Chip(
                      avatar: const Icon(Icons.person, size: 14, color: navyColor),
                      backgroundColor: navyColor.withOpacity(0.06),
                      label: Text('${v.key}: ${v.value.toStringAsFixed(2)} ${m['unit']} (${_currencyFormat.format(val)})', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Report D View: Daily / Monthly / Financial Year Reconciliation
  Widget _buildPeriodSummaryReportView(List<SubVendorMaterialOutward> outwards) {
    final periods = SubVendorMaterialOutwardService.generatePeriodSummary(
      outwards,
      grouping: _periodGrouping,
    );
    final totalSub = SubVendorFinancialEngine.sumPaise(periods, (p) => p.subtotal);
    final totalGst = SubVendorFinancialEngine.sumPaise(periods, (p) => p.totalGst);
    final totalGrand = SubVendorFinancialEngine.sumPaise(periods, (p) => p.grandTotal);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: const BorderSide(color: Color(0xFFE2E8F0))),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Text('Period Reconciliation:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: navyColor)),
                    const SizedBox(width: 12),
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(value: 'DAILY', label: Text('Daily', style: TextStyle(fontSize: 11))),
                        ButtonSegment(value: 'MONTHLY', label: Text('Monthly', style: TextStyle(fontSize: 11))),
                        ButtonSegment(value: 'FINANCIAL_YEAR', label: Text('Financial Year', style: TextStyle(fontSize: 11))),
                      ],
                      selected: {_periodGrouping},
                      onSelectionChanged: (s) => setState(() => _periodGrouping = s.first),
                    ),
                  ],
                ),
                Text(
                  'Subtotal: ${_currencyFormat.format(totalSub)} | GST: ${_currencyFormat.format(totalGst)} | Combined Outwards: ${_currencyFormat.format(totalGrand)}',
                  style: const TextStyle(fontWeight: FontWeight.bold, color: greenColor, fontSize: 12.5),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: periods.isEmpty
                ? const Center(child: Text('No active outward entries in selected range.'))
                : SingleChildScrollView(
                    child: DataTable(
                      headingRowColor: WidgetStateProperty.all(const Color(0xFFF1F5F9)),
                      columns: const [
                        DataColumn(label: Text('Period', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Outwards', style: TextStyle(fontWeight: FontWeight.bold)), numeric: true),
                        DataColumn(label: Text('Total Qty', style: TextStyle(fontWeight: FontWeight.bold)), numeric: true),
                        DataColumn(label: Text('Subtotal (₹)', style: TextStyle(fontWeight: FontWeight.bold)), numeric: true),
                        DataColumn(label: Text('Total GST (₹)', style: TextStyle(fontWeight: FontWeight.bold)), numeric: true),
                        DataColumn(label: Text('Grand Total (₹)', style: TextStyle(fontWeight: FontWeight.bold)), numeric: true),
                      ],
                      rows: periods.map((p) {
                        return DataRow(cells: [
                          DataCell(Text(p.periodLabel, style: const TextStyle(fontWeight: FontWeight.bold))),
                          DataCell(Text('${p.entryCount}')),
                          DataCell(Text(p.totalQuantity.toStringAsFixed(2))),
                          DataCell(Text(_currencyFormat.format(p.subtotal))),
                          DataCell(Text(_currencyFormat.format(p.totalGst))),
                          DataCell(Text(_currencyFormat.format(p.grandTotal), style: const TextStyle(fontWeight: FontWeight.bold, color: greenColor))),
                        ]);
                      }).toList(),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  // Handle Export CSV
  Future<void> _handleExportReportCsv(List<SubVendorMaterialOutward> outwards) async {
    try {
      if (_selectedReportType == 0) {
        await SubVendorMaterialOutwardPdfService.exportDateWiseReportCsv(outwards);
      } else if (_selectedReportType == 1) {
        final summaries = SubVendorMaterialOutwardService.generateSubVendorWiseSummary(outwards);
        await SubVendorMaterialOutwardPdfService.exportSubVendorWiseReportCsv(summaries);
      } else if (_selectedReportType == 2) {
        final summaries = SubVendorMaterialOutwardService.generateMaterialWiseSummary(outwards);
        await SubVendorMaterialOutwardPdfService.exportMaterialWiseReportCsv(summaries);
      } else {
        final periods = SubVendorMaterialOutwardService.generatePeriodSummary(outwards, grouping: _periodGrouping);
        await SubVendorMaterialOutwardPdfService.exportPeriodReportCsv(periods, grouping: _periodGrouping);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Report exported to CSV successfully!'), backgroundColor: greenColor),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Export failed: $e'), backgroundColor: redColor));
      }
    }
  }

  // Handle Print PDF
  Future<void> _handlePrintReportPdf(List<SubVendorMaterialOutward> outwards) async {
    try {
      Uint8List bytes;
      String docName;
      if (_selectedReportType == 0) {
        bytes = await SubVendorMaterialOutwardPdfService.generateDateWiseReportPdfBytes(outwards);
        docName = 'Date_Wise_Material_Outward_Report.pdf';
      } else if (_selectedReportType == 1) {
        final summaries = SubVendorMaterialOutwardService.generateSubVendorWiseSummary(outwards);
        bytes = await SubVendorMaterialOutwardPdfService.generateSubVendorWiseReportPdfBytes(summaries);
        docName = 'Sub_Vendor_Wise_Material_Report.pdf';
      } else if (_selectedReportType == 2) {
        final summaries = SubVendorMaterialOutwardService.generateMaterialWiseSummary(outwards);
        bytes = await SubVendorMaterialOutwardPdfService.generateMaterialWiseReportPdfBytes(summaries);
        docName = 'Material_Wise_Distribution_Report.pdf';
      } else {
        final periods = SubVendorMaterialOutwardService.generatePeriodSummary(outwards, grouping: _periodGrouping);
        bytes = await SubVendorMaterialOutwardPdfService.generatePeriodReportPdfBytes(periods, grouping: _periodGrouping);
        docName = 'Period_Material_Outward_Report_$_periodGrouping.pdf';
      }

      await Printing.layoutPdf(onLayout: (_) => bytes, name: docName);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Print failed: $e'), backgroundColor: redColor));
      }
    }
  }

  // ============================================================================
  // DIALOGS: VIEW DETAILS, EDIT, CANCEL
  // ============================================================================

  void _showOutwardDetailsDialog(SubVendorMaterialOutward outward) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.outbox, color: navyColor),
              const SizedBox(width: 8),
              Text('Outward Details: ${outward.outwardNumber}'),
            ],
          ),
          content: SizedBox(
            width: 720,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _dialogInfoRow('Sub-Vendor:', outward.vendorName),
                  _dialogInfoRow('Dispatch Date:', _dateFormat.format(outward.outwardDate)),
                  _dialogInfoRow('Status:', outward.status, color: outward.isActive ? greenColor : redColor),
                  if (outward.remarks != null) _dialogInfoRow('Remarks:', outward.remarks!),
                  const SizedBox(height: 16),
                  const Text('Issued Materials:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: navyColor)),
                  const SizedBox(height: 8),
                  Table(
                    border: TableBorder.all(color: const Color(0xFFE2E8F0)),
                    columnWidths: const {
                      0: FixedColumnWidth(32),
                      1: FlexColumnWidth(3),
                      2: FixedColumnWidth(55),
                      3: FixedColumnWidth(65),
                      4: FixedColumnWidth(85),
                      5: FixedColumnWidth(55),
                      6: FixedColumnWidth(95),
                    },
                    children: [
                      const TableRow(
                        decoration: BoxDecoration(color: Color(0xFFF1F5F9)),
                        children: [
                          Padding(padding: EdgeInsets.all(6), child: Text('#', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                          Padding(padding: EdgeInsets.all(6), child: Text('Material Name', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                          Padding(padding: EdgeInsets.all(6), child: Text('Unit', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                          Padding(padding: EdgeInsets.all(6), child: Text('Qty', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                          Padding(padding: EdgeInsets.all(6), child: Text('Rate', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                          Padding(padding: EdgeInsets.all(6), child: Text('GST %', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                          Padding(padding: EdgeInsets.all(6), child: Text('Final Price', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                        ],
                      ),
                      ...outward.items.asMap().entries.map((entry) {
                        final idx = entry.key + 1;
                        final item = entry.value;
                        return TableRow(
                          children: [
                            Padding(padding: const EdgeInsets.all(6), child: Text('$idx', style: const TextStyle(fontSize: 11))),
                            Padding(padding: const EdgeInsets.all(6), child: Text(item.materialName, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600))),
                            Padding(padding: const EdgeInsets.all(6), child: Text(item.unit, style: const TextStyle(fontSize: 11))),
                            Padding(padding: const EdgeInsets.all(6), child: Text(item.quantity.toStringAsFixed(2), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
                            Padding(padding: const EdgeInsets.all(6), child: Text(_currencyFormat.format(item.unitRate), style: const TextStyle(fontSize: 11))),
                            Padding(padding: const EdgeInsets.all(6), child: Text('${item.gstPercentage.toStringAsFixed(0)}%', style: const TextStyle(fontSize: 11))),
                            Padding(padding: const EdgeInsets.all(6), child: Text(_currencyFormat.format(item.totalPrice), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: greenColor))),
                          ],
                        );
                      }),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFFE2E8F0))),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Subtotal: ${_currencyFormat.format(outward.subtotal)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                        Text('Total GST: ${_currencyFormat.format(outward.totalGst)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF0284C7))),
                        Text('Grand Total: ${_currencyFormat.format(outward.totalValue)}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: greenColor)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
            ElevatedButton.icon(
              onPressed: () async {
                final bytes = await SubVendorMaterialOutwardPdfService.generateOutwardSlipPdfBytes(outward);
                await Printing.layoutPdf(onLayout: (_) => bytes, name: 'Outward_${outward.outwardNumber}.pdf');
              },
              icon: const Icon(Icons.print, size: 16),
              label: const Text('Print Slip'),
              style: ElevatedButton.styleFrom(backgroundColor: navyColor, foregroundColor: Colors.white),
            ),
          ],
        );
      },
    );
  }

  void _showCancelOutwardDialog(SubVendorMaterialOutward outward) {
    final reasonCtrl = TextEditingController(text: 'Cancelled by Admin');
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: redColor),
              SizedBox(width: 8),
              Text('Cancel Outward Entry?'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Cancelling entry "${outward.outwardNumber}" will exclude it from active outward totals and reverse its ledger debit effect.',
                style: const TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: reasonCtrl,
                decoration: const InputDecoration(
                  labelText: 'Cancellation Reason',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('No, Keep Active')),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(ctx);
                try {
                  await SubVendorMaterialOutwardService.cancelOutward(outward.id, reason: reasonCtrl.text.trim());
                  await _loadInitialData();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Outward ${outward.outwardNumber} cancelled!'), backgroundColor: greenColor),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Cancel failed: $e'), backgroundColor: redColor));
                  }
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: redColor, foregroundColor: Colors.white),
              child: const Text('Yes, Cancel Outward'),
            ),
          ],
        );
      },
    );
  }

  void _showEditOutwardDialog(SubVendorMaterialOutward outward) {
    DateTime editDate = outward.outwardDate;
    SubVendor? editVendor = _vendors.firstWhere((v) => v.id == outward.vendorId, orElse: () => _vendors.first);
    final editRemarksCtrl = TextEditingController(text: outward.remarks ?? '');
    final List<_OutwardRowState> editRows = outward.items.map((i) {
      final matchedMat = _materials.firstWhere(
        (m) => m.id == i.materialId || m.itemName.toLowerCase() == i.materialName.toLowerCase(),
        orElse: () => MaterialMasterItem(id: i.materialId ?? '', itemName: i.materialName, unit: i.unit, defaultRate: i.unitRate),
      );
      return _OutwardRowState(
        selectedMaterial: matchedMat,
        selectedUnit: _normalizeUnit(i.unit),
        quantityCtrl: TextEditingController(text: i.quantity.toString()),
        rateCtrl: TextEditingController(text: i.unitRate.toStringAsFixed(2)),
        gstPercentage: _gstOptions.contains(i.gstPercentage) ? i.gstPercentage : 0.0,
      );
    }).toList();

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            final editQty = SubVendorFinancialEngine.sumPaise(editRows, (r) => r.quantity);
            final editSub = SubVendorFinancialEngine.sumPaise(editRows, (r) => r.baseAmount);
            final editGst = SubVendorFinancialEngine.sumPaise(editRows, (r) => r.gstAmount);
            final editGrand = SubVendorFinancialEngine.sumPaise(editRows, (r) => r.finalPrice);

            return AlertDialog(
              title: Row(
                children: [
                  const Icon(Icons.edit, color: amberColor),
                  const SizedBox(width: 8),
                  Text('Edit Outward: ${outward.outwardNumber}'),
                ],
              ),
              content: SizedBox(
                width: 980,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Note: Editing this entry updates the outward record and recalculates the Sub-Vendor ledger.',
                        style: TextStyle(fontSize: 12, color: amberColor, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<SubVendor>(
                              value: editVendor,
                              isExpanded: true,
                              decoration: const InputDecoration(labelText: 'Sub Vendor', border: OutlineInputBorder()),
                              items: _vendors.map((v) => DropdownMenuItem(value: v, child: Text(v.name))).toList(),
                              onChanged: (val) => setDialogState(() => editVendor = val),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: InkWell(
                              onTap: () async {
                                final p = await showDatePicker(
                                  context: ctx,
                                  initialDate: editDate,
                                  firstDate: DateTime(2024),
                                  lastDate: DateTime(2030),
                                );
                                if (p != null) setDialogState(() => editDate = p);
                              },
                              child: InputDecorator(
                                decoration: const InputDecoration(labelText: 'Date', border: OutlineInputBorder()),
                                child: Text(_dateFormat.format(editDate)),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: editRemarksCtrl,
                        decoration: const InputDecoration(labelText: 'Remarks', border: OutlineInputBorder()),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Material Rows:', style: TextStyle(fontWeight: FontWeight.bold)),
                          TextButton.icon(
                            onPressed: () {
                              setDialogState(() {
                                final mat = _materials.isNotEmpty ? _materials.first : null;
                                editRows.add(_OutwardRowState(
                                  selectedMaterial: mat,
                                  selectedUnit: _normalizeUnit(mat?.unit ?? 'NOS'),
                                  quantityCtrl: TextEditingController(text: '1'),
                                  rateCtrl: TextEditingController(text: mat != null && mat.defaultRate > 0 ? mat.defaultRate.toStringAsFixed(2) : '0'),
                                  gstPercentage: 0.0,
                                ));
                              });
                            },
                            icon: const Icon(Icons.add, size: 16),
                            label: const Text('Add Material'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ...editRows.asMap().entries.map((entry) {
                        return _buildMaterialRowCard(
                          idx: entry.key,
                          row: entry.value,
                          onChanged: () => setDialogState(() {}),
                          onRemove: () {
                            if (editRows.length <= 1) return;
                            setDialogState(() {
                              final removed = editRows.removeAt(entry.key);
                              removed.dispose();
                            });
                          },
                        );
                      }),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFFE2E8F0))),
                        child: Wrap(
                          spacing: 20,
                          runSpacing: 8,
                          children: [
                            Text('Total Qty: ${editQty.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                            Text('Subtotal: ${_currencyFormat.format(editSub)}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                            Text('Total GST: ${_currencyFormat.format(editGst)}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: Color(0xFF0284C7))),
                            Text('Grand Total: ${_currencyFormat.format(editGrand)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: greenColor)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                ElevatedButton(
                  onPressed: () async {
                    if (editVendor == null) return;
                    final List<SubVendorMaterialOutwardItem> updatedItems = [];
                    for (final r in editRows) {
                      if (r.selectedMaterial == null) continue;
                      if (r.quantity <= 0) continue;
                      updatedItems.add(SubVendorMaterialOutwardItem(
                        id: '',
                        outwardId: outward.id,
                        materialId: r.selectedMaterial!.id,
                        materialName: r.selectedMaterial!.itemName,
                        unit: r.selectedUnit,
                        quantity: r.quantity,
                        unitRate: r.rate,
                        baseAmount: r.baseAmount,
                        gstPercentage: r.gstPercentage,
                        gstAmount: r.gstAmount,
                        totalPrice: r.finalPrice,
                      ));
                    }

                    if (updatedItems.isEmpty) return;

                    Navigator.pop(ctx);
                    try {
                      await SubVendorMaterialOutwardService.updateOutward(
                        outwardId: outward.id,
                        vendorId: editVendor!.id,
                        vendorName: editVendor!.name,
                        outwardDate: editDate,
                        remarks: editRemarksCtrl.text.trim().isNotEmpty ? editRemarksCtrl.text.trim() : null,
                        items: updatedItems,
                      );
                      await _loadInitialData();
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Outward ${outward.outwardNumber} updated successfully!'), backgroundColor: greenColor),
                        );
                      }
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Update failed: $e'), backgroundColor: redColor));
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: navyColor, foregroundColor: Colors.white),
                  child: const Text('Save Changes'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _dialogInfoRow(String label, String value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(width: 120, child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF64748B)))),
          Expanded(child: Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color ?? const Color(0xFF1E293B)))),
        ],
      ),
    );
  }
}

/// Helper state class for each dynamic row in Material Outward Entry.
class _OutwardRowState {
  MaterialMasterItem? selectedMaterial;
  String selectedUnit;
  final TextEditingController quantityCtrl;
  final TextEditingController rateCtrl;
  double gstPercentage;

  _OutwardRowState({
    required this.selectedMaterial,
    this.selectedUnit = 'NOS',
    required this.quantityCtrl,
    required this.rateCtrl,
    this.gstPercentage = 0.0,
  });

  double get quantity => double.tryParse(quantityCtrl.text.trim()) ?? 0.0;
  double get rate => double.tryParse(rateCtrl.text.trim()) ?? 0.0;
  double get baseAmount => SubVendorFinancialEngine.calculateOutwardRow(
      quantity: quantity, ratePerUnit: rate, gstPercentage: gstPercentage).baseAmount;
  double get gstAmount => SubVendorFinancialEngine.calculateOutwardRow(
      quantity: quantity, ratePerUnit: rate, gstPercentage: gstPercentage).gstAmount;
  double get finalPrice => SubVendorFinancialEngine.calculateOutwardRow(
      quantity: quantity, ratePerUnit: rate, gstPercentage: gstPercentage).finalAmount;

  void dispose() {
    quantityCtrl.dispose();
    rateCtrl.dispose();
  }
}
