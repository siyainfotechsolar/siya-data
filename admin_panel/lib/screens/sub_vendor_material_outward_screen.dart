import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'package:siya_shared/siya_shared.dart';
import '../services/sub_vendor_material_outward_pdf_service.dart';
import '../services/sub_vendor_material_outward_service.dart';

final _dateFormat = DateFormat('dd-MM-yyyy');

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
  int _selectedReportType = 0; // 0: Date-wise, 1: Sub Vendor-wise, 2: Material-wise
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

  void _addMaterialRow([MaterialMasterItem? initialMat, double initialQty = 1.0]) {
    final mat = initialMat ?? (_materials.isNotEmpty ? _materials.first : null);
    setState(() {
      _entryRows.add(_OutwardRowState(
        selectedMaterial: mat,
        quantityCtrl: TextEditingController(text: initialQty > 0 ? initialQty.toString() : '1'),
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

  double get _currentTotalQty {
    double total = 0.0;
    for (final r in _entryRows) {
      final q = double.tryParse(r.quantityCtrl.text.trim()) ?? 0.0;
      total += q;
    }
    return total;
  }

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
                'Issue materials date-wise with real-time stock deduction, history & reports',
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
                    final idx = entry.key;
                    final row = entry.value;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // Row Index Badge
                          CircleAvatar(
                            radius: 14,
                            backgroundColor: navyColor.withOpacity(0.1),
                            child: Text('${idx + 1}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: navyColor)),
                          ),
                          const SizedBox(width: 12),

                          // Material Dropdown
                          Expanded(
                            flex: 5,
                            child: DropdownButtonFormField<MaterialMasterItem>(
                              value: row.selectedMaterial,
                              isExpanded: true,
                              decoration: const InputDecoration(
                                labelText: 'Select Material',
                                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                border: OutlineInputBorder(),
                              ),
                              items: _materials.map((m) {
                                return DropdownMenuItem(
                                  value: m,
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          m.itemName,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: m.availableStock > 0 ? Colors.green.shade50 : Colors.red.shade50,
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          'Stock: ${m.availableStock.toStringAsFixed(1)} ${m.unit}',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: m.availableStock > 0 ? Colors.green.shade800 : Colors.red.shade800,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                              onChanged: (val) {
                                if (val != null) {
                                  setState(() => row.selectedMaterial = val);
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 12),

                          // Unit Auto-fetch Box
                          Container(
                            width: 85,
                            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: const Color(0xFFCBD5E1)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                const Text('UNIT', style: TextStyle(fontSize: 9, color: Color(0xFF64748B), fontWeight: FontWeight.bold)),
                                const SizedBox(height: 2),
                                Text(
                                  row.selectedMaterial?.unit ?? 'NOS',
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: navyColor),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),

                          // Quantity Text Field
                          Expanded(
                            flex: 2,
                            child: TextField(
                              controller: row.quantityCtrl,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: const InputDecoration(
                                labelText: 'Quantity',
                                hintText: '0.0',
                                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                border: OutlineInputBorder(),
                              ),
                              onChanged: (_) => setState(() {}),
                            ),
                          ),
                          const SizedBox(width: 8),

                          // Remove Button
                          IconButton(
                            icon: const Icon(Icons.delete_outline, color: redColor, size: 20),
                            tooltip: 'Remove Row',
                            onPressed: () => _removeMaterialRow(idx),
                          ),
                        ],
                      ),
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
            child: Row(
              children: [
                // KPI: Total Rows
                _buildSummaryKpi('Total Materials', '${_entryRows.length} Items', Icons.layers_outlined, navyColor),
                const SizedBox(width: 24),
                // KPI: Total Quantity
                _buildSummaryKpi('Total Quantity', _currentTotalQty.toStringAsFixed(1), Icons.numbers, amberColor),
                const SizedBox(width: 24),
                // Selected Vendor
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
                // Bulk Save Button
                ElevatedButton.icon(
                  onPressed: _isSavingEntry ? null : _handleSaveOutwardEntry,
                  icon: _isSavingEntry
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.check_circle_outline, size: 18),
                  label: Text(_isSavingEntry ? 'Saving & Deducting...' : 'Save Material Outward'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: navyColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
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
      final q = double.tryParse(r.quantityCtrl.text.trim()) ?? 0.0;
      if (q <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Row ${i + 1}: Quantity must be greater than zero.'), backgroundColor: redColor),
        );
        return;
      }

      items.add(SubVendorMaterialOutwardItem(
        id: '',
        outwardId: '',
        materialId: r.selectedMaterial!.id,
        materialName: r.selectedMaterial!.itemName,
        unit: r.selectedMaterial!.unit,
        quantity: q,
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

      // Refresh master stock and outwards
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
                  child: Text('Material Outward ${created.outwardNumber} successfully recorded & stock deducted!'),
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
                                    tooltip: 'Cancel Outward & Restore Stock',
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
                    : _buildMaterialWiseReportView(activeOutwards),
          ),
        ),
      ],
    );
  }

  // Report A View: Date-wise List
  Widget _buildDateWiseReportView(List<SubVendorMaterialOutward> outwards) {
    final rows = SubVendorMaterialOutwardService.generateDateWiseReportRows(outwards);
    final totalQty = rows.fold(0.0, (sum, r) => sum + (r['quantity'] as double));

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
                Text('Total Issued Items: ${rows.length} | Net Quantity: ${totalQty.toStringAsFixed(1)}', style: const TextStyle(fontWeight: FontWeight.bold, color: greenColor)),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: rows.isEmpty
                ? const Center(child: Text('No active outward records for the selected period.'))
                : SingleChildScrollView(
                    child: DataTable(
                      headingRowColor: WidgetStateProperty.all(const Color(0xFFF1F5F9)),
                      columns: const [
                        DataColumn(label: Text('Outward No', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Date', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Sub Vendor', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Material Name', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Unit', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Quantity', style: TextStyle(fontWeight: FontWeight.bold))),
                      ],
                      rows: rows.map((r) {
                        return DataRow(
                          cells: [
                            DataCell(Text(r['outward_number'].toString(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                            DataCell(Text(_dateFormat.format(r['outward_date'] as DateTime), style: const TextStyle(fontSize: 12))),
                            DataCell(Text(r['vendor_name'].toString(), style: const TextStyle(fontSize: 12))),
                            DataCell(Text(r['material_name'].toString(), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
                            DataCell(Text(r['unit'].toString(), style: const TextStyle(fontSize: 12))),
                            DataCell(Text((r['quantity'] as double).toStringAsFixed(1), style: const TextStyle(fontWeight: FontWeight.bold, color: amberColor))),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  // Report B View: Sub Vendor-wise Summary
  Widget _buildSubVendorWiseReportView(List<SubVendorMaterialOutward> outwards) {
    final summaries = SubVendorMaterialOutwardService.generateSubVendorWiseSummary(outwards);

    return ListView.builder(
      itemCount: summaries.length,
      itemBuilder: (context, i) {
        final v = summaries[i];
        final matSummary = v['materials_summary'] as Map<String, double>;

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
                      'Outward Transactions: ${v['total_outwards']} | Total Qty: ${(v['total_quantity'] as double).toStringAsFixed(1)}',
                      style: const TextStyle(fontWeight: FontWeight.bold, color: greenColor, fontSize: 13),
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
                    return Chip(
                      backgroundColor: const Color(0xFFF1F5F9),
                      label: Text('${m.key}: ${m.value.toStringAsFixed(1)}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
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

  // Report C View: Material-wise Summary
  Widget _buildMaterialWiseReportView(List<SubVendorMaterialOutward> outwards) {
    final summaries = SubVendorMaterialOutwardService.generateMaterialWiseSummary(outwards);

    return ListView.builder(
      itemCount: summaries.length,
      itemBuilder: (context, i) {
        final m = summaries[i];
        final vBreakdown = m['vendor_breakdown'] as Map<String, double>;

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
                      'Total Issued: ${(m['total_quantity'] as double).toStringAsFixed(1)} ${m['unit']}',
                      style: const TextStyle(fontWeight: FontWeight.bold, color: amberColor, fontSize: 13),
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
                    return Chip(
                      avatar: const Icon(Icons.person, size: 14, color: navyColor),
                      backgroundColor: navyColor.withOpacity(0.06),
                      label: Text('${v.key}: ${v.value.toStringAsFixed(1)} ${m['unit']}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
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

  // Handle Export CSV
  Future<void> _handleExportReportCsv(List<SubVendorMaterialOutward> outwards) async {
    try {
      if (_selectedReportType == 0) {
        await SubVendorMaterialOutwardPdfService.exportDateWiseReportCsv(outwards);
      } else if (_selectedReportType == 1) {
        final summaries = SubVendorMaterialOutwardService.generateSubVendorWiseSummary(outwards);
        await SubVendorMaterialOutwardPdfService.exportSubVendorWiseReportCsv(summaries);
      } else {
        final summaries = SubVendorMaterialOutwardService.generateMaterialWiseSummary(outwards);
        await SubVendorMaterialOutwardPdfService.exportMaterialWiseReportCsv(summaries);
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
      } else {
        final summaries = SubVendorMaterialOutwardService.generateMaterialWiseSummary(outwards);
        bytes = await SubVendorMaterialOutwardPdfService.generateMaterialWiseReportPdfBytes(summaries);
        docName = 'Material_Wise_Distribution_Report.pdf';
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
            width: 600,
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
                    children: [
                      const TableRow(
                        decoration: BoxDecoration(color: Color(0xFFF1F5F9)),
                        children: [
                          Padding(padding: EdgeInsets.all(6), child: Text('#', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                          Padding(padding: EdgeInsets.all(6), child: Text('Material Name', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                          Padding(padding: EdgeInsets.all(6), child: Text('Unit', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                          Padding(padding: EdgeInsets.all(6), child: Text('Quantity', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                        ],
                      ),
                      ...outward.items.asMap().entries.map((entry) {
                        final idx = entry.key + 1;
                        final item = entry.value;
                        return TableRow(
                          children: [
                            Padding(padding: const EdgeInsets.all(6), child: Text('$idx', style: const TextStyle(fontSize: 12))),
                            Padding(padding: const EdgeInsets.all(6), child: Text(item.materialName, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
                            Padding(padding: const EdgeInsets.all(6), child: Text(item.unit, style: const TextStyle(fontSize: 12))),
                            Padding(padding: const EdgeInsets.all(6), child: Text(item.quantity.toStringAsFixed(1), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                          ],
                        );
                      }),
                    ],
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
                'Cancelling entry "${outward.outwardNumber}" will automatically restore all ${outward.totalQuantity} items back to Main Inventory.',
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
                      SnackBar(content: Text('Outward ${outward.outwardNumber} cancelled and stock restored!'), backgroundColor: greenColor),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Cancel failed: $e'), backgroundColor: redColor));
                  }
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: redColor, foregroundColor: Colors.white),
              child: const Text('Yes, Cancel & Restore Stock'),
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
        orElse: () => MaterialMasterItem(id: i.materialId ?? '', itemName: i.materialName, unit: i.unit),
      );
      return _OutwardRowState(
        selectedMaterial: matchedMat,
        quantityCtrl: TextEditingController(text: i.quantity.toString()),
      );
    }).toList();

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              title: Row(
                children: [
                  const Icon(Icons.edit, color: amberColor),
                  const SizedBox(width: 8),
                  Text('Edit Outward: ${outward.outwardNumber}'),
                ],
              ),
              content: SizedBox(
                width: 700,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Note: Editing this entry will automatically reverse previous stock deduction and apply new quantities.',
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
                                editRows.add(_OutwardRowState(
                                  selectedMaterial: _materials.isNotEmpty ? _materials.first : null,
                                  quantityCtrl: TextEditingController(text: '1'),
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
                        final idx = entry.key;
                        final r = entry.value;
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(6), border: Border.all(color: const Color(0xFFE2E8F0))),
                          child: Row(
                            children: [
                              Text('${idx + 1}.', style: const TextStyle(fontWeight: FontWeight.bold)),
                              const SizedBox(width: 8),
                              Expanded(
                                flex: 4,
                                child: DropdownButtonFormField<MaterialMasterItem>(
                                  value: r.selectedMaterial,
                                  isExpanded: true,
                                  decoration: const InputDecoration(border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8)),
                                  items: _materials.map((m) => DropdownMenuItem(value: m, child: Text(m.itemName, overflow: TextOverflow.ellipsis))).toList(),
                                  onChanged: (val) {
                                    if (val != null) setDialogState(() => r.selectedMaterial = val);
                                  },
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                flex: 2,
                                child: TextField(
                                  controller: r.quantityCtrl,
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  decoration: const InputDecoration(labelText: 'Qty', border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8)),
                                ),
                              ),
                              const SizedBox(width: 6),
                              IconButton(
                                icon: const Icon(Icons.delete, color: redColor, size: 18),
                                onPressed: () {
                                  if (editRows.length <= 1) return;
                                  setDialogState(() => editRows.removeAt(idx));
                                },
                              ),
                            ],
                          ),
                        );
                      }),
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
                      final q = double.tryParse(r.quantityCtrl.text.trim()) ?? 0.0;
                      if (q <= 0) continue;
                      updatedItems.add(SubVendorMaterialOutwardItem(
                        id: '',
                        outwardId: outward.id,
                        materialId: r.selectedMaterial!.id,
                        materialName: r.selectedMaterial!.itemName,
                        unit: r.selectedMaterial!.unit,
                        quantity: q,
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
                  child: const Text('Save Changes & Re-Apply Stock'),
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
  final TextEditingController quantityCtrl;

  _OutwardRowState({
    required this.selectedMaterial,
    required this.quantityCtrl,
  });

  void dispose() {
    quantityCtrl.dispose();
  }
}
