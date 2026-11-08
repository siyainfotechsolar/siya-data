import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:printing/printing.dart';
import 'package:siya_shared/siya_shared.dart';

import '../services/solar_site_cost_service.dart';
import '../services/solar_site_cost_pdf_service.dart';

/// SIYA SOLAR SITE COST CALCULATOR SCREEN
///
/// Material-wise Solar Site Cost & GST Estimation:
/// - Solar Panels (Wattage x Qty x Rate/Watt + 5% GST)
/// - Inverter (Fixed Cost x Qty + 5% / 12% GST)
/// - GI Pipe (Size-wise, Weight x Qty x Rate/KG + 18% GST)
/// - Other Structure Material (Configurable units + 18% GST)
/// - Electrical BOS Material (Fixed, Meter, Nos, Set + 18% GST)
/// - Other Custom Materials (Configurable GST)
/// - Labour Cost (Exactly 3 categories: Wiring, Structure, Civil)
/// - Other Expenses (Transportation, Loading/Unloading, Other)
/// - Full GST & Taxable breakdown with Net/Gross toggle
class SolarSiteCostCalculatorScreen extends StatefulWidget {
  const SolarSiteCostCalculatorScreen({super.key});

  @override
  State<SolarSiteCostCalculatorScreen> createState() =>
      _SolarSiteCostCalculatorScreenState();
}

class _SolarSiteCostCalculatorScreenState
    extends State<SolarSiteCostCalculatorScreen> {
  final _currency = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 2);
  final _dateFormat = DateFormat('dd-MM-yyyy');

  bool _isLoading = false;
  String? _savedCalculationId;
  String _calculationNumber = '';
  bool _isGstApplicable = true; // Enabled by default to show GST

  // Header controllers
  final _siteNameCtrl = TextEditingController(text: 'New Solar Site');
  final _customerNameCtrl = TextEditingController();
  final _capacityCtrl = TextEditingController(text: '3.3');
  final _notesCtrl = TextEditingController();
  DateTime _calculationDate = DateTime.now();

  // Item lists
  List<SolarPanelCostItem> _panels = [];
  List<SolarInverterCostItem> _inverters = [];
  List<SolarGiPipeCostItem> _giPipes = [];
  List<SolarStructureCostItem> _structureItems = [];
  List<SolarBosCostItem> _bosItems = [];
  List<SolarOtherMaterialItem> _otherMaterials = [];

  // Labour controllers (Exactly 3 categories)
  final _wiringLabourCtrl = TextEditingController(text: '0');
  final _structureLabourCtrl = TextEditingController(text: '0');
  final _civilLabourCtrl = TextEditingController(text: '0');

  // Other Expenses controllers
  final _transportCtrl = TextEditingController(text: '0');
  final _loadingCtrl = TextEditingController(text: '0');
  final _otherExpCtrl = TextEditingController(text: '0');
  List<SolarCustomExpenseItem> _customExpenses = [];

  @override
  void initState() {
    super.initState();
    _loadMasterAndInitialData();
  }

  @override
  void dispose() {
    _siteNameCtrl.dispose();
    _customerNameCtrl.dispose();
    _capacityCtrl.dispose();
    _notesCtrl.dispose();
    _wiringLabourCtrl.dispose();
    _structureLabourCtrl.dispose();
    _civilLabourCtrl.dispose();
    _transportCtrl.dispose();
    _loadingCtrl.dispose();
    _otherExpCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadMasterAndInitialData() async {
    setState(() => _isLoading = true);
    try {
      await SolarSiteCostService.fetchMaterialMaster();
      _startNewBlankCalculation();
    } catch (_) {
      _startNewBlankCalculation();
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _startNewBlankCalculation() {
    setState(() {
      _savedCalculationId = null;
      _calculationNumber = '';
      _isGstApplicable = true;
      _siteNameCtrl.text = 'New Solar Site';
      _customerNameCtrl.text = '';
      _capacityCtrl.text = '3.3';
      _notesCtrl.text = '';
      _calculationDate = DateTime.now();

      _panels = [
        const SolarPanelCostItem(
          id: 'p_init_1',
          brand: 'Waaree',
          model: 'Mono PERC',
          wattage: 550.0,
          quantity: 6,
          ratePerWatt: 18.0,
          gstRate: 5.0,
        ),
      ];

      _inverters = [
        const SolarInverterCostItem(
          id: 'inv_init_1',
          brand: 'Growatt',
          model: 'MIC 3300TL-X',
          capacity: '3.3 kW',
          quantity: 1,
          fixedRate: 25000.0,
          gstRate: 5.0,
        ),
      ];

      _giPipes = [
        const SolarGiPipeCostItem(
          id: 'pipe_init_1',
          pipeSize: '40x40 mm',
          thicknessMm: 1.6,
          lengthFeet: 20.0,
          numberOfPipes: 10,
          weightPerPipeKg: 8.0,
          ratePerKg: 85.0,
          gstRate: 18.0,
        ),
        const SolarGiPipeCostItem(
          id: 'pipe_init_2',
          pipeSize: '80x40 mm',
          thicknessMm: 2.0,
          lengthFeet: 20.0,
          numberOfPipes: 5,
          weightPerPipeKg: 12.0,
          ratePerKg: 90.0,
          gstRate: 18.0,
        ),
        const SolarGiPipeCostItem(
          id: 'pipe_init_3',
          pipeSize: '40x20 mm',
          thicknessMm: 1.6,
          lengthFeet: 20.0,
          numberOfPipes: 4,
          weightPerPipeKg: 6.0,
          ratePerKg: 80.0,
          gstRate: 18.0,
        ),
      ];

      _structureItems = [];

      _bosItems = [
        const SolarBosCostItem(id: 'bos_1', itemName: 'ACDB', unit: 'FIXED', quantity: 1, rate: 2500.0, gstRate: 18.0),
        const SolarBosCostItem(id: 'bos_2', itemName: 'DCDB', unit: 'FIXED', quantity: 1, rate: 2200.0, gstRate: 18.0),
        const SolarBosCostItem(id: 'bos_3', itemName: 'DC Cable', unit: 'FIXED', quantity: 1, rate: 1750.0, gstRate: 18.0),
        const SolarBosCostItem(id: 'bos_4', itemName: 'AC Cable', unit: 'FIXED', quantity: 1, rate: 1950.0, gstRate: 18.0),
        const SolarBosCostItem(id: 'bos_5', itemName: 'Earthing Kit', unit: 'FIXED', quantity: 1, rate: 3500.0, gstRate: 18.0),
        const SolarBosCostItem(id: 'bos_6', itemName: 'MC4 Connector', unit: 'FIXED', quantity: 1, rate: 500.0, gstRate: 18.0),
      ];

      _otherMaterials = [];

      _wiringLabourCtrl.text = '6000';
      _structureLabourCtrl.text = '7000';
      _civilLabourCtrl.text = '5500';

      _transportCtrl.text = '3000';
      _loadingCtrl.text = '500';
      _otherExpCtrl.text = '1000';
      _customExpenses = [];
    });
  }

  /// Loads the exact sample test calculation from Section 11 of the requirement:
  /// Base Taxable: ₹1,33,920. When GST is toggled ON: ₹1,42,913.60
  void _loadSampleTestCalculation({bool withGst = false}) {
    final sample = SolarSiteCostCalculation.createSampleTestCalculation(withGst: withGst);
    _populateFromCalculation(sample);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(withGst
            ? 'Loaded Sample with GST: Base Taxable = ₹1,33,920 | GST = ₹8,993.60 | Total = ₹1,42,913.60'
            : 'Loaded Sample (Net Cost): Expected Base Total = ₹1,33,920 (Toggle GST to see taxes)'),
        backgroundColor: const Color(0xFF047857),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _populateFromCalculation(SolarSiteCostCalculation calc) {
    setState(() {
      _savedCalculationId = calc.id;
      _calculationNumber = calc.calculationNumber;
      _isGstApplicable = calc.isGstApplicable;
      _siteNameCtrl.text = calc.siteName;
      _customerNameCtrl.text = calc.customerName;
      _capacityCtrl.text = calc.systemCapacityKw > 0 ? calc.systemCapacityKw.toStringAsFixed(2) : '3.3';
      _notesCtrl.text = calc.notes;
      _calculationDate = calc.calculationDate;

      _panels = List.from(calc.panels);
      _inverters = List.from(calc.inverters);
      _giPipes = List.from(calc.giPipes);
      _structureItems = List.from(calc.structureItems);
      _bosItems = List.from(calc.bosItems);
      _otherMaterials = List.from(calc.otherMaterials);

      _wiringLabourCtrl.text = calc.labour.totalWiring.toStringAsFixed(0);
      _structureLabourCtrl.text = calc.labour.totalStructure.toStringAsFixed(0);
      _civilLabourCtrl.text = calc.labour.totalCivil.toStringAsFixed(0);

      _transportCtrl.text = calc.otherExpenses.transportation.toStringAsFixed(0);
      _loadingCtrl.text = calc.otherExpenses.loadingUnloading.toStringAsFixed(0);
      _otherExpCtrl.text = calc.otherExpenses.otherExpenses.toStringAsFixed(0);
      _customExpenses = List.from(calc.otherExpenses.customExpenses);
    });
  }

  // ---------------------------------------------------------------------------
  // Build Current Calculation Object
  // ---------------------------------------------------------------------------
  SolarSiteCostCalculation _buildCurrentCalculation() {
    final capacity = double.tryParse(_capacityCtrl.text.trim()) ?? 0.0;
    final wiringLabour = double.tryParse(_wiringLabourCtrl.text.trim()) ?? 0.0;
    final structureLabour = double.tryParse(_structureLabourCtrl.text.trim()) ?? 0.0;
    final civilLabour = double.tryParse(_civilLabourCtrl.text.trim()) ?? 0.0;

    final transport = double.tryParse(_transportCtrl.text.trim()) ?? 0.0;
    final loading = double.tryParse(_loadingCtrl.text.trim()) ?? 0.0;
    final otherExp = double.tryParse(_otherExpCtrl.text.trim()) ?? 0.0;

    return SolarSiteCostCalculation(
      id: _savedCalculationId,
      calculationNumber: _calculationNumber,
      siteName: _siteNameCtrl.text.trim().isNotEmpty ? _siteNameCtrl.text.trim() : 'Solar Site',
      customerName: _customerNameCtrl.text.trim(),
      systemCapacityKw: capacity,
      calculationDate: _calculationDate,
      notes: _notesCtrl.text.trim(),
      isGstApplicable: _isGstApplicable,
      panels: _panels,
      inverters: _inverters,
      giPipes: _giPipes,
      structureItems: _structureItems,
      bosItems: _bosItems,
      otherMaterials: _otherMaterials,
      labour: SolarLabourCost(
        wiringLabour: LabourCategoryDetail(description: 'Wiring Labour', fixedAmount: wiringLabour),
        structureLabour: LabourCategoryDetail(description: 'Structure Labour', fixedAmount: structureLabour),
        civilLabour: LabourCategoryDetail(description: 'Civil Labour', fixedAmount: civilLabour),
      ),
      otherExpenses: SolarOtherExpenses(
        transportation: transport,
        loadingUnloading: loading,
        otherExpenses: otherExp,
        customExpenses: _customExpenses,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Save & Actions
  // ---------------------------------------------------------------------------
  Future<void> _saveCalculation() async {
    final calc = _buildCurrentCalculation();
    setState(() => _isLoading = true);
    try {
      final saved = await SolarSiteCostService.saveCalculation(calc);
      setState(() {
        _savedCalculationId = saved.id;
        _calculationNumber = saved.calculationNumber;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Site Calculation saved successfully! (${saved.calculationNumber})'),
            backgroundColor: const Color(0xFF047857),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving calculation: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _exportPdf() async {
    final calc = _buildCurrentCalculation();
    try {
      final bytes = await SolarSiteCostPdfService.generateSiteCostPdfBytes(calc);
      final filename = 'Site_Cost_${calc.siteName.replaceAll(' ', '_')}_${_dateFormat.format(calc.calculationDate)}.pdf';
      await Printing.layoutPdf(
        name: filename,
        onLayout: (format) async => bytes,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to generate PDF: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _exportCsv() async {
    final calc = _buildCurrentCalculation();
    final rows = <List<dynamic>>[
      ['SIYA INFOTECH & SOLAR ENERGY - SOLAR SITE COST & GST ESTIMATE'],
      ['Calculation Number', calc.calculationNumber],
      ['Site Name', calc.siteName],
      ['Customer Name', calc.customerName],
      ['System Capacity', '${calc.systemCapacityKw} kW'],
      ['Calculation Date', _dateFormat.format(calc.calculationDate)],
      ['GST Mode', calc.isGstApplicable ? 'GST Inclusive' : 'Net Base Cost'],
      [],
      ['1. SOLAR PANELS'],
      ['Brand', 'Model', 'Wattage (W)', 'Quantity', 'Total Watts', 'Rate/Watt (₹)', 'Taxable (₹)', 'GST %', 'GST Amount (₹)', 'Total Amount (₹)'],
      ...calc.panels.map((p) => [p.brand, p.model, p.wattage, p.quantity, p.totalWattage, p.ratePerWatt, p.taxableAmount, '${p.gstRate}%', p.gstAmount, p.totalAmount]),
      ['Total Solar Panel Cost', '', '', '', '', '', calc.totalPanelTaxable, '', calc.totalPanelGst, calc.totalPanelCost],
      [],
      ['2. INVERTERS (FIXED COST)'],
      ['Brand', 'Model', 'Capacity', 'Quantity', 'Fixed Rate (₹)', 'Taxable (₹)', 'GST %', 'GST Amount (₹)', 'Total Amount (₹)'],
      ...calc.inverters.map((i) => [i.brand, i.model, i.capacity, i.quantity, i.fixedRate, i.taxableAmount, '${i.gstRate}%', i.gstAmount, i.totalAmount]),
      ['Total Inverter Cost', '', '', '', '', calc.totalInverterTaxable, '', calc.totalInverterGst, calc.totalInverterCost],
      [],
      ['3. GI PIPES (SIZE-WISE CALCULATION)'],
      ['Pipe Size', 'Thickness (mm)', 'Length (Ft)', 'Pipes (Nos)', 'Weight/Pipe (KG)', 'Total Weight (KG)', 'Rate/KG (₹)', 'Taxable (₹)', 'GST %', 'GST Amount (₹)', 'Total Amount (₹)'],
      ...calc.giPipes.map((pipe) => [pipe.pipeSize, pipe.thicknessMm, pipe.lengthFeet, pipe.numberOfPipes, pipe.weightPerPipeKg, pipe.totalWeightKg, pipe.ratePerKg, pipe.taxableAmount, '${pipe.gstRate}%', pipe.gstAmount, pipe.totalAmount]),
      ['Total GI Pipe Cost', '', '', '', '', '', '', calc.totalGiPipeTaxable, '', calc.totalGiPipeGst, calc.totalGiPipeCost],
      [],
      ['4. OTHER STRUCTURE MATERIAL'],
      ['Item Name', 'Specification', 'Unit', 'Quantity', 'Rate (₹)', 'Taxable (₹)', 'GST %', 'GST Amount (₹)', 'Total Amount (₹)'],
      ...calc.structureItems.map((s) => [s.itemName, s.specification, s.unit, s.quantity, s.rate, s.taxableAmount, '${s.gstRate}%', s.gstAmount, s.totalAmount]),
      ['Total Other Structure Cost', '', '', '', '', calc.totalStructureTaxable, '', calc.totalStructureGst, calc.totalStructureCost],
      [],
      ['5. ELECTRICAL BOS MATERIAL'],
      ['Item Name', 'Specification', 'Unit', 'Quantity', 'Rate (₹)', 'Taxable (₹)', 'GST %', 'GST Amount (₹)', 'Total Amount (₹)'],
      ...calc.bosItems.map((b) => [b.itemName, b.specification, b.unit, b.quantity, b.rate, b.taxableAmount, '${b.gstRate}%', b.gstAmount, b.totalAmount]),
      ['Total Electrical BOS Cost', '', '', '', '', calc.totalBosTaxable, '', calc.totalBosGst, calc.totalBosCost],
      [],
      ['6. OTHER CUSTOM MATERIALS'],
      ['Material Name', 'Specification', 'Unit', 'Quantity', 'Rate (₹)', 'Taxable (₹)', 'GST %', 'GST Amount (₹)', 'Total Amount (₹)'],
      ...calc.otherMaterials.map((m) => [m.materialName, m.specification, m.unit, m.quantity, m.rate, m.taxableAmount, '${m.gstRate}%', m.gstAmount, m.totalAmount]),
      ['Total Other Materials Cost', '', '', '', '', calc.totalOtherMaterialTaxable, '', calc.totalOtherMaterialGst, calc.totalOtherMaterialCost],
      [],
      ['7. LABOUR COST (THREE CATEGORIES)'],
      ['Labour Category', 'Description', 'Amount (₹)'],
      ['Wiring Labour', calc.labour.wiringLabour.description, calc.totalWiringLabour],
      ['Structure Labour', calc.labour.structureLabour.description, calc.totalStructureLabour],
      ['Civil Labour', calc.labour.civilLabour.description, calc.totalCivilLabour],
      ['Total Labour Cost', '', calc.totalLabourCost],
      [],
      ['8. OTHER EXPENSES'],
      ['Expense Description', 'Amount (₹)'],
      ['Transportation Charges', calc.otherExpenses.transportation],
      ['Loading / Unloading', calc.otherExpenses.loadingUnloading],
      ['Other Expenses', calc.otherExpenses.otherExpenses],
      ...calc.otherExpenses.customExpenses.map((e) => [e.description, e.amount]),
      ['Total Other Expenses', calc.totalOtherExpensesCost],
      [],
      ['FINAL SUMMARY'],
      ['Category', 'Taxable (₹)', 'GST (₹)', 'Subtotal (₹)'],
      ['Solar Panels (5% GST)', calc.totalPanelTaxable, calc.totalPanelGst, calc.totalPanelCost],
      ['Inverter (5% GST)', calc.totalInverterTaxable, calc.totalInverterGst, calc.totalInverterCost],
      ['GI Pipe Structure (18% GST)', calc.totalGiPipeTaxable, calc.totalGiPipeGst, calc.totalGiPipeCost],
      ['Other Structure Material (18% GST)', calc.totalStructureTaxable, calc.totalStructureGst, calc.totalStructureCost],
      ['Electrical BOS Material (18% GST)', calc.totalBosTaxable, calc.totalBosGst, calc.totalBosCost],
      ['Other Custom Materials', calc.totalOtherMaterialTaxable, calc.totalOtherMaterialGst, calc.totalOtherMaterialCost],
      ['Total Labour Charges', calc.totalLabourCost, 0.0, calc.totalLabourCost],
      ['Total Other Expenses', calc.totalOtherExpensesCost, 0.0, calc.totalOtherExpensesCost],
      ['SUBTOTAL TAXABLE COST', calc.totalTaxableCost, '', ''],
      ['TOTAL MATERIAL GST (5% & 18%)', '', calc.totalGstAmount, ''],
      ['FINAL TOTAL SITE COST', '', '', calc.finalSiteCost],
      ['Cost Per kW Installed', '', '', calc.costPerKw],
    ];

    try {
      final csvString = const ListToCsvConverter().convert(rows);
      final bytes = utf8.encode(csvString);
      final filename = 'Site_Cost_GST_${calc.siteName.replaceAll(' ', '_')}_${_dateFormat.format(calc.calculationDate)}.csv';

      await FilePicker.platform.saveFile(
        dialogTitle: 'Export Site Cost & GST CSV',
        fileName: filename,
        bytes: Uint8List.fromList(bytes),
        allowedExtensions: ['csv'],
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Exported $filename successfully!'),
            backgroundColor: const Color(0xFF047857),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to export CSV: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showSavedCalculationsDialog() async {
    setState(() => _isLoading = true);
    final list = await SolarSiteCostService.fetchCalculations();
    setState(() => _isLoading = false);

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.folder_shared_outlined, color: Color(0xFF0D2B6F)),
              SizedBox(width: 8),
              Text('Saved Site Cost Calculations', style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          content: SizedBox(
            width: 650,
            height: 450,
            child: list.isEmpty
                ? const Center(child: Text('No saved calculations found.'))
                : ListView.separated(
                    itemCount: list.length,
                    separatorBuilder: (_, index) => const Divider(height: 1),
                    itemBuilder: (context, idx) {
                      final item = list[idx];
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: const Color(0xFFEFF6FF),
                          child: Text(
                            '${idx + 1}',
                            style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0D2B6F)),
                          ),
                        ),
                        title: Text(
                          item.siteName,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          '${item.calculationNumber} • ${item.customerName.isNotEmpty ? item.customerName : 'No Customer'} • ${item.systemCapacityKw} kW • ${_dateFormat.format(item.calculationDate)}',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _currency.format(item.finalSiteCost),
                              style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF047857), fontSize: 14),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              icon: const Icon(Icons.open_in_new, color: Color(0xFF0D2B6F), size: 20),
                              tooltip: 'Open',
                              onPressed: () {
                                Navigator.pop(ctx);
                                _populateFromCalculation(item);
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.copy, color: Colors.blueGrey, size: 20),
                              tooltip: 'Duplicate',
                              onPressed: () async {
                                Navigator.pop(ctx);
                                final dup = await SolarSiteCostService.duplicateCalculation(item);
                                _populateFromCalculation(dup);
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                              tooltip: 'Delete',
                              onPressed: () async {
                                final confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (c) => AlertDialog(
                                    title: const Text('Confirm Delete'),
                                    content: Text('Are you sure you want to delete ${item.siteName}?'),
                                    actions: [
                                      TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
                                      ElevatedButton(
                                        style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                                        onPressed: () => Navigator.pop(c, true),
                                        child: const Text('Delete', style: TextStyle(color: Colors.white)),
                                      ),
                                    ],
                                  ),
                                );
                                if (confirm == true) {
                                  await SolarSiteCostService.deleteCalculation(item.id ?? '');
                                  if (mounted && ctx.mounted) {
                                    Navigator.pop(ctx);
                                    _showSavedCalculationsDialog();
                                  }
                                }
                              },
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Build Main UI
  // ---------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final calc = _buildCurrentCalculation();
    final isBaseSampleMatch = (calc.finalSiteCostWithoutGst - 133920.0).abs() < 0.01;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : CustomScrollView(
              slivers: [
                _buildSliverAppBar(calc),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  sliver: SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Site Basic Details Card & GST Toggle
                        _buildSiteInfoCard(calc, isBaseSampleMatch),
                        const SizedBox(height: 16),

                        // Main Content (2-Column on Wide Desktop, 1-Column on Mobile)
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final isWide = constraints.maxWidth >= 1050;
                            if (isWide) {
                              return Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Left side: Detailed Material & Labour inputs (width 65%)
                                  Expanded(
                                    flex: 65,
                                    child: Column(
                                      children: [
                                        _buildPanelSection(),
                                        const SizedBox(height: 16),
                                        _buildInverterSection(),
                                        const SizedBox(height: 16),
                                        _buildGiPipeSection(),
                                        const SizedBox(height: 16),
                                        _buildStructureSection(),
                                        const SizedBox(height: 16),
                                        _buildBosSection(),
                                        const SizedBox(height: 16),
                                        _buildOtherMaterialsSection(),
                                        const SizedBox(height: 16),
                                        _buildLabourSection(),
                                        const SizedBox(height: 16),
                                        _buildExpensesSection(),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 20),
                                  // Right side: Sticky Live Cost Summary Box (width 35%)
                                  Expanded(
                                    flex: 35,
                                    child: _buildLiveCostSummaryCard(calc, isBaseSampleMatch),
                                  ),
                                ],
                              );
                            } else {
                              return Column(
                                children: [
                                  _buildLiveCostSummaryCard(calc, isBaseSampleMatch),
                                  const SizedBox(height: 16),
                                  _buildPanelSection(),
                                  const SizedBox(height: 16),
                                  _buildInverterSection(),
                                  const SizedBox(height: 16),
                                  _buildGiPipeSection(),
                                  const SizedBox(height: 16),
                                  _buildStructureSection(),
                                  const SizedBox(height: 16),
                                  _buildBosSection(),
                                  const SizedBox(height: 16),
                                  _buildOtherMaterialsSection(),
                                  const SizedBox(height: 16),
                                  _buildLabourSection(),
                                  const SizedBox(height: 16),
                                  _buildExpensesSection(),
                                  const SizedBox(height: 16),
                                  _buildLiveCostSummaryCard(calc, isBaseSampleMatch),
                                ],
                              );
                            }
                          },
                        ),
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  // ---------------------------------------------------------------------------
  // AppBar & Header
  // ---------------------------------------------------------------------------
  Widget _buildSliverAppBar(SolarSiteCostCalculation calc) {
    return SliverAppBar(
      pinned: true,
      elevation: 0,
      backgroundColor: const Color(0xFF0D2B6F), // Deep Blue branding
      foregroundColor: Colors.white,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'SIYA SOLAR SITE COST & GST CALCULATOR',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 0.5),
          ),
          Text(
            'Panel (5%), Inverter (5%), GI Pipe (18%), BOS (18%) & Labour Costing',
            style: TextStyle(fontSize: 11, color: Colors.amber.shade200),
          ),
        ],
      ),
      actions: [
        // One-Click Sample Test button
        TextButton.icon(
          style: TextButton.styleFrom(
            backgroundColor: const Color(0xFFD97706), // Golden Yellow
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          icon: const Icon(Icons.verified, size: 16),
          label: const Text('Sample Test (₹1,33,920)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          onPressed: () => _loadSampleTestCalculation(withGst: false),
        ),
        const SizedBox(width: 8),
        IconButton(
          tooltip: 'New Blank Calculation',
          icon: const Icon(Icons.add_circle_outline),
          onPressed: _startNewBlankCalculation,
        ),
        IconButton(
          tooltip: 'Saved Calculations',
          icon: const Icon(Icons.folder_open),
          onPressed: _showSavedCalculationsDialog,
        ),
        IconButton(
          tooltip: 'Export CSV',
          icon: const Icon(Icons.table_view_outlined),
          onPressed: _exportCsv,
        ),
        IconButton(
          tooltip: 'Export PDF Statement',
          icon: const Icon(Icons.picture_as_pdf_outlined),
          onPressed: _exportPdf,
        ),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF047857), // Emerald Green
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          icon: const Icon(Icons.save, size: 16),
          label: const Text('Save Calculation', style: TextStyle(fontWeight: FontWeight.bold)),
          onPressed: _saveCalculation,
        ),
        const SizedBox(width: 12),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Top Site Basic Info Card & GST Toggle
  // ---------------------------------------------------------------------------
  Widget _buildSiteInfoCard(SolarSiteCostCalculation calc, bool isBaseSampleMatch) {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.solar_power, color: Color(0xFF0D2B6F), size: 22),
                const SizedBox(width: 8),
                const Text(
                  'Site & Capacity Details',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF0D2B6F)),
                ),
                const Spacer(),

                // GST Mode Toggle
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _isGstApplicable ? const Color(0xFFEFF6FF) : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _isGstApplicable ? const Color(0xFF3B82F6) : Colors.grey.shade300),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _isGstApplicable ? Icons.receipt_long : Icons.money_off,
                        size: 16,
                        color: _isGstApplicable ? const Color(0xFF0D2B6F) : Colors.grey.shade700,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _isGstApplicable ? 'GST Mode: INCLUSIVE (5% & 18%)' : 'GST Mode: NET BASE (Without GST)',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: _isGstApplicable ? const Color(0xFF0D2B6F) : Colors.grey.shade800,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Switch(
                        value: _isGstApplicable,
                        activeColor: const Color(0xFF0D2B6F),
                        onChanged: (val) => setState(() => _isGstApplicable = val),
                      ),
                    ],
                  ),
                ),

                if (isBaseSampleMatch) ...[
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFDCFCE7),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.green.shade400),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.check_circle, size: 14, color: Color(0xFF047857)),
                        SizedBox(width: 4),
                        Text(
                          'Base Net Verified: ₹1,33,920',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF047857)),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 16,
              runSpacing: 12,
              children: [
                SizedBox(
                  width: 240,
                  child: TextField(
                    controller: _siteNameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Site Name *',
                      isDense: true,
                      prefixIcon: Icon(Icons.location_on_outlined, size: 18),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                SizedBox(
                  width: 220,
                  child: TextField(
                    controller: _customerNameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Customer Name',
                      isDense: true,
                      prefixIcon: Icon(Icons.person_outline, size: 18),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                SizedBox(
                  width: 170,
                  child: TextField(
                    controller: _capacityCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'System Capacity (kW) *',
                      isDense: true,
                      suffixText: 'kW',
                      prefixIcon: Icon(Icons.bolt, size: 18),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                SizedBox(
                  width: 180,
                  child: InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _calculationDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2035),
                      );
                      if (picked != null) {
                        setState(() => _calculationDate = picked);
                      }
                    },
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Calculation Date',
                        isDense: true,
                        prefixIcon: Icon(Icons.calendar_today, size: 18),
                      ),
                      child: Text(_dateFormat.format(_calculationDate), style: const TextStyle(fontSize: 13)),
                    ),
                  ),
                ),
                SizedBox(
                  width: 260,
                  child: TextField(
                    controller: _notesCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Site Notes / Remarks',
                      isDense: true,
                      prefixIcon: Icon(Icons.notes, size: 18),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // SECTION 1: Solar Panel Cost (+ 5% GST)
  // ---------------------------------------------------------------------------
  Widget _buildPanelSection() {
    final taxable = _panels.fold(0.0, (sum, p) => sum + p.taxableAmount);
    final gst = _panels.fold(0.0, (sum, p) => sum + p.gstAmount);
    final total = _isGstApplicable ? (taxable + gst) : taxable;
    final totalWatts = _panels.fold(0.0, (sum, p) => sum + p.totalWattage);

    return _buildSectionCard(
      title: '1. Solar Panel Cost (Wattage × Rate/Watt + 5% GST)',
      badge: '${totalWatts.toStringAsFixed(0)} W • Taxable: ${_currency.format(taxable)} • GST: ${_currency.format(gst)} • Total: ${_currency.format(total)}',
      badgeColor: const Color(0xFF0D2B6F),
      onAdd: () {
        setState(() {
          _panels.add(SolarPanelCostItem(
            id: 'p_${DateTime.now().millisecondsSinceEpoch}',
            brand: 'Waaree',
            model: 'Mono PERC',
            wattage: 550.0,
            quantity: 6,
            ratePerWatt: 18.0,
            gstRate: 5.0,
          ));
        });
      },
      addLabel: '+ Add Panel',
      child: Column(
        children: _panels.asMap().entries.map((entry) {
          final idx = entry.key;
          final item = entry.value;
          return _buildPanelRow(idx, item);
        }).toList(),
      ),
    );
  }

  Widget _buildPanelRow(int index, SolarPanelCostItem item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: TextFormField(
              initialValue: item.brand,
              decoration: const InputDecoration(labelText: 'Brand', isDense: true),
              onChanged: (val) => _panels[index] = item.copyWith(brand: val),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: TextFormField(
              initialValue: item.model,
              decoration: const InputDecoration(labelText: 'Model', isDense: true),
              onChanged: (val) => _panels[index] = item.copyWith(model: val),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: TextFormField(
              initialValue: item.wattage.toStringAsFixed(0),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Watts', suffixText: 'W', isDense: true),
              onChanged: (val) {
                final d = double.tryParse(val) ?? 0.0;
                setState(() => _panels[index] = item.copyWith(wattage: d));
              },
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 1,
            child: TextFormField(
              initialValue: item.quantity.toString(),
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Qty', isDense: true),
              onChanged: (val) {
                final i = int.tryParse(val) ?? 0;
                setState(() => _panels[index] = item.copyWith(quantity: i));
              },
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: TextFormField(
              initialValue: item.ratePerWatt.toStringAsFixed(2),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Rate/W', prefixText: '₹', isDense: true),
              onChanged: (val) {
                final d = double.tryParse(val) ?? 0.0;
                setState(() => _panels[index] = item.copyWith(ratePerWatt: d));
              },
            ),
          ),
          const SizedBox(width: 8),
          // GST Rate Dropdown (0%, 5%, 12%)
          SizedBox(
            width: 80,
            child: DropdownButtonFormField<double>(
              initialValue: item.gstRate,
              decoration: const InputDecoration(labelText: 'GST %', isDense: true),
              items: const [
                DropdownMenuItem(value: 0.0, child: Text('0%')),
                DropdownMenuItem(value: 5.0, child: Text('5%')),
                DropdownMenuItem(value: 12.0, child: Text('12%')),
              ],
              onChanged: (val) {
                if (val != null) setState(() => _panels[index] = item.copyWith(gstRate: val));
              },
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('Taxable: ${_currency.format(item.taxableAmount)}', style: TextStyle(fontSize: 11, color: Colors.grey.shade700)),
              if (item.gstRate > 0)
                Text('+ GST (${item.gstRate.toStringAsFixed(0)}%): ${_currency.format(item.gstAmount)}', style: TextStyle(fontSize: 10, color: Colors.blue.shade700)),
              Text(_currency.format(_isGstApplicable ? item.totalAmount : item.taxableAmount), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0D2B6F))),
            ],
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.remove_circle_outline, color: Colors.redAccent, size: 20),
            onPressed: () => setState(() => _panels.removeAt(index)),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // SECTION 2: Inverter Cost (+ 5% / 12% GST)
  // ---------------------------------------------------------------------------
  Widget _buildInverterSection() {
    final taxable = _inverters.fold(0.0, (sum, inv) => sum + inv.taxableAmount);
    final gst = _inverters.fold(0.0, (sum, inv) => sum + inv.gstAmount);
    final total = _isGstApplicable ? (taxable + gst) : taxable;

    return _buildSectionCard(
      title: '2. Inverter Cost (Fixed Rate + 5% / 12% GST)',
      badge: 'Taxable: ${_currency.format(taxable)} • GST: ${_currency.format(gst)} • Total: ${_currency.format(total)}',
      badgeColor: const Color(0xFF0D2B6F),
      onAdd: () {
        setState(() {
          _inverters.add(SolarInverterCostItem(
            id: 'inv_${DateTime.now().millisecondsSinceEpoch}',
            brand: 'Growatt',
            model: 'MIC 3300TL-X',
            capacity: '3.3 kW',
            quantity: 1,
            fixedRate: 25000.0,
            gstRate: 5.0,
          ));
        });
      },
      addLabel: '+ Add Inverter',
      child: Column(
        children: _inverters.asMap().entries.map((entry) {
          final idx = entry.key;
          final item = entry.value;
          return _buildInverterRow(idx, item);
        }).toList(),
      ),
    );
  }

  Widget _buildInverterRow(int index, SolarInverterCostItem item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: TextFormField(
              initialValue: item.brand,
              decoration: const InputDecoration(labelText: 'Brand', isDense: true),
              onChanged: (val) => _inverters[index] = item.copyWith(brand: val),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: TextFormField(
              initialValue: item.model,
              decoration: const InputDecoration(labelText: 'Model', isDense: true),
              onChanged: (val) => _inverters[index] = item.copyWith(model: val),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: TextFormField(
              initialValue: item.capacity,
              decoration: const InputDecoration(labelText: 'Capacity', isDense: true),
              onChanged: (val) => _inverters[index] = item.copyWith(capacity: val),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 1,
            child: TextFormField(
              initialValue: item.quantity.toString(),
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Qty', isDense: true),
              onChanged: (val) {
                final i = int.tryParse(val) ?? 0;
                setState(() => _inverters[index] = item.copyWith(quantity: i));
              },
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: TextFormField(
              initialValue: item.fixedRate.toStringAsFixed(0),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Fixed Rate', prefixText: '₹', isDense: true),
              onChanged: (val) {
                final d = double.tryParse(val) ?? 0.0;
                setState(() => _inverters[index] = item.copyWith(fixedRate: d));
              },
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 80,
            child: DropdownButtonFormField<double>(
              initialValue: item.gstRate,
              decoration: const InputDecoration(labelText: 'GST %', isDense: true),
              items: const [
                DropdownMenuItem(value: 0.0, child: Text('0%')),
                DropdownMenuItem(value: 5.0, child: Text('5%')),
                DropdownMenuItem(value: 12.0, child: Text('12%')),
                DropdownMenuItem(value: 18.0, child: Text('18%')),
              ],
              onChanged: (val) {
                if (val != null) setState(() => _inverters[index] = item.copyWith(gstRate: val));
              },
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('Taxable: ${_currency.format(item.taxableAmount)}', style: TextStyle(fontSize: 11, color: Colors.grey.shade700)),
              if (item.gstRate > 0)
                Text('+ GST (${item.gstRate.toStringAsFixed(0)}%): ${_currency.format(item.gstAmount)}', style: TextStyle(fontSize: 10, color: Colors.blue.shade700)),
              Text(_currency.format(_isGstApplicable ? item.totalAmount : item.taxableAmount), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0D2B6F))),
            ],
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.remove_circle_outline, color: Colors.redAccent, size: 20),
            onPressed: () => setState(() => _inverters.removeAt(index)),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // SECTION 3: GI Pipe (Size-wise & Rate Per KG + 18% GST)
  // ---------------------------------------------------------------------------
  Widget _buildGiPipeSection() {
    final taxable = _giPipes.fold(0.0, (sum, pipe) => sum + pipe.taxableAmount);
    final gst = _giPipes.fold(0.0, (sum, pipe) => sum + pipe.gstAmount);
    final total = _isGstApplicable ? (taxable + gst) : taxable;
    final totalWeight = _giPipes.fold(0.0, (sum, pipe) => sum + pipe.totalWeightKg);

    return _buildSectionCard(
      title: '3. GI Pipe Structure (Size-wise & Rate Per KG + 18% GST)',
      badge: '${totalWeight.toStringAsFixed(1)} KG • Taxable: ${_currency.format(taxable)} • GST: ${_currency.format(gst)} • Total: ${_currency.format(total)}',
      badgeColor: const Color(0xFF0D2B6F),
      onAdd: () {
        setState(() {
          _giPipes.add(SolarGiPipeCostItem(
            id: 'pipe_${DateTime.now().millisecondsSinceEpoch}',
            pipeSize: '40x40 mm',
            thicknessMm: 1.6,
            lengthFeet: 20.0,
            numberOfPipes: 10,
            weightPerPipeKg: 8.0,
            ratePerKg: 85.0,
            gstRate: 18.0,
          ));
        });
      },
      addLabel: '+ Add GI Pipe',
      child: Column(
        children: _giPipes.asMap().entries.map((entry) {
          final idx = entry.key;
          final item = entry.value;
          return _buildGiPipeRow(idx, item);
        }).toList(),
      ),
    );
  }

  Widget _buildGiPipeRow(int index, SolarGiPipeCostItem item) {
    const pipePresets = [
      '40x40 mm',
      '80x40 mm',
      '40x20 mm',
      '50x50 mm',
      'Custom Size',
    ];

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          // Pipe Size Preset
          SizedBox(
            width: 130,
            child: DropdownButtonFormField<String>(
              initialValue: pipePresets.contains(item.pipeSize) ? item.pipeSize : 'Custom Size',
              decoration: const InputDecoration(labelText: 'Pipe Size', isDense: true),
              items: pipePresets.map((s) => DropdownMenuItem(value: s, child: Text(s, style: const TextStyle(fontSize: 12)))).toList(),
              onChanged: (val) {
                if (val == null) return;
                double defaultWeight = item.weightPerPipeKg;
                double defaultRate = item.ratePerKg;
                double defaultThk = item.thicknessMm;
                if (val == '40x40 mm') {
                  defaultWeight = 8.0;
                  defaultRate = 85.0;
                  defaultThk = 1.6;
                } else if (val == '80x40 mm') {
                  defaultWeight = 12.0;
                  defaultRate = 90.0;
                  defaultThk = 2.0;
                } else if (val == '40x20 mm') {
                  defaultWeight = 6.0;
                  defaultRate = 80.0;
                  defaultThk = 1.6;
                } else if (val == '50x50 mm') {
                  defaultWeight = 10.0;
                  defaultRate = 88.0;
                  defaultThk = 2.0;
                }
                setState(() {
                  _giPipes[index] = item.copyWith(
                    pipeSize: val,
                    weightPerPipeKg: defaultWeight,
                    ratePerKg: defaultRate,
                    thicknessMm: defaultThk,
                  );
                });
              },
            ),
          ),
          if (item.pipeSize == 'Custom Size')
            SizedBox(
              width: 120,
              child: TextFormField(
                initialValue: item.pipeSize == 'Custom Size' ? '' : item.pipeSize,
                decoration: const InputDecoration(labelText: 'Custom Name', isDense: true),
                onChanged: (val) => _giPipes[index] = item.copyWith(pipeSize: val),
              ),
            ),
          SizedBox(
            width: 90,
            child: TextFormField(
              initialValue: item.thicknessMm.toStringAsFixed(1),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Thk (mm)', isDense: true),
              onChanged: (val) {
                final d = double.tryParse(val) ?? 1.6;
                setState(() => _giPipes[index] = item.copyWith(thicknessMm: d));
              },
            ),
          ),
          SizedBox(
            width: 80,
            child: TextFormField(
              initialValue: item.numberOfPipes.toString(),
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Pipes', isDense: true),
              onChanged: (val) {
                final i = int.tryParse(val) ?? 0;
                setState(() => _giPipes[index] = item.copyWith(numberOfPipes: i));
              },
            ),
          ),
          SizedBox(
            width: 100,
            child: TextFormField(
              initialValue: item.weightPerPipeKg.toStringAsFixed(1),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Wt/Pipe(KG)', isDense: true),
              onChanged: (val) {
                final d = double.tryParse(val) ?? 0.0;
                setState(() => _giPipes[index] = item.copyWith(weightPerPipeKg: d));
              },
            ),
          ),
          SizedBox(
            width: 100,
            child: TextFormField(
              initialValue: item.ratePerKg.toStringAsFixed(2),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Rate/KG', prefixText: '₹', isDense: true),
              onChanged: (val) {
                final d = double.tryParse(val) ?? 0.0;
                setState(() => _giPipes[index] = item.copyWith(ratePerKg: d));
              },
            ),
          ),
          SizedBox(
            width: 80,
            child: DropdownButtonFormField<double>(
              initialValue: item.gstRate,
              decoration: const InputDecoration(labelText: 'GST %', isDense: true),
              items: const [
                DropdownMenuItem(value: 0.0, child: Text('0%')),
                DropdownMenuItem(value: 18.0, child: Text('18%')),
              ],
              onChanged: (val) {
                if (val != null) setState(() => _giPipes[index] = item.copyWith(gstRate: val));
              },
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('Taxable: ${_currency.format(item.taxableAmount)}', style: TextStyle(fontSize: 11, color: Colors.grey.shade700)),
              if (item.gstRate > 0)
                Text('+ 18% GST: ${_currency.format(item.gstAmount)}', style: TextStyle(fontSize: 10, color: Colors.blue.shade700)),
              Text(_currency.format(_isGstApplicable ? item.totalAmount : item.taxableAmount), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0D2B6F))),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.remove_circle_outline, color: Colors.redAccent, size: 20),
            onPressed: () => setState(() => _giPipes.removeAt(index)),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // SECTION 4: Other Structure Material (+ 18% GST)
  // ---------------------------------------------------------------------------
  Widget _buildStructureSection() {
    final taxable = _structureItems.fold(0.0, (sum, item) => sum + item.taxableAmount);
    final gst = _structureItems.fold(0.0, (sum, item) => sum + item.gstAmount);
    final total = _isGstApplicable ? (taxable + gst) : taxable;

    return _buildSectionCard(
      title: '4. Other Structure Material (+ 18% GST)',
      badge: 'Taxable: ${_currency.format(taxable)} • GST: ${_currency.format(gst)} • Total: ${_currency.format(total)}',
      badgeColor: const Color(0xFF0D2B6F),
      onAdd: () {
        setState(() {
          _structureItems.add(SolarStructureCostItem(
            id: 'str_${DateTime.now().millisecondsSinceEpoch}',
            itemName: 'Mid Clamp',
            specification: 'Aluminum Mid Clamp with SS Bolt',
            unit: 'NOS',
            quantity: 10,
            rate: 25.0,
            gstRate: 18.0,
          ));
        });
      },
      addLabel: '+ Add Structure Item',
      child: _structureItems.isEmpty
          ? const Padding(
              padding: EdgeInsets.all(12),
              child: Text('No additional structure materials added. Click "+ Add Structure Item" if needed.', style: TextStyle(fontSize: 12, color: Colors.grey)),
            )
          : Column(
              children: _structureItems.asMap().entries.map((entry) {
                final idx = entry.key;
                final item = entry.value;
                return _buildStructureRow(idx, item);
              }).toList(),
            ),
    );
  }

  Widget _buildStructureRow(int index, SolarStructureCostItem item) {
    const units = ['NOS', 'KG', 'WATT', 'METER', 'FIXED'];
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: TextFormField(
              initialValue: item.itemName,
              decoration: const InputDecoration(labelText: 'Item Name', isDense: true),
              onChanged: (val) => _structureItems[index] = item.copyWith(itemName: val),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: TextFormField(
              initialValue: item.specification,
              decoration: const InputDecoration(labelText: 'Specification', isDense: true),
              onChanged: (val) => _structureItems[index] = item.copyWith(specification: val),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 90,
            child: DropdownButtonFormField<String>(
              initialValue: units.contains(item.unit.toUpperCase()) ? item.unit.toUpperCase() : 'NOS',
              decoration: const InputDecoration(labelText: 'Unit', isDense: true),
              items: units.map((u) => DropdownMenuItem(value: u, child: Text(u, style: const TextStyle(fontSize: 12)))).toList(),
              onChanged: (val) {
                if (val != null) setState(() => _structureItems[index] = item.copyWith(unit: val));
              },
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 80,
            child: TextFormField(
              initialValue: item.quantity.toStringAsFixed(0),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Qty', isDense: true),
              onChanged: (val) {
                final d = double.tryParse(val) ?? 0.0;
                setState(() => _structureItems[index] = item.copyWith(quantity: d));
              },
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 100,
            child: TextFormField(
              initialValue: item.rate.toStringAsFixed(2),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Rate (₹)', prefixText: '₹', isDense: true),
              onChanged: (val) {
                final d = double.tryParse(val) ?? 0.0;
                setState(() => _structureItems[index] = item.copyWith(rate: d));
              },
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 80,
            child: DropdownButtonFormField<double>(
              initialValue: item.gstRate,
              decoration: const InputDecoration(labelText: 'GST %', isDense: true),
              items: const [
                DropdownMenuItem(value: 0.0, child: Text('0%')),
                DropdownMenuItem(value: 18.0, child: Text('18%')),
              ],
              onChanged: (val) {
                if (val != null) setState(() => _structureItems[index] = item.copyWith(gstRate: val));
              },
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('Taxable: ${_currency.format(item.taxableAmount)}', style: TextStyle(fontSize: 11, color: Colors.grey.shade700)),
              if (item.gstRate > 0)
                Text('+ GST: ${_currency.format(item.gstAmount)}', style: TextStyle(fontSize: 10, color: Colors.blue.shade700)),
              Text(_currency.format(_isGstApplicable ? item.totalAmount : item.taxableAmount), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0D2B6F))),
            ],
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.remove_circle_outline, color: Colors.redAccent, size: 20),
            onPressed: () => setState(() => _structureItems.removeAt(index)),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // SECTION 5: Electrical BOS Material (+ 18% GST)
  // ---------------------------------------------------------------------------
  Widget _buildBosSection() {
    final taxable = _bosItems.fold(0.0, (sum, item) => sum + item.taxableAmount);
    final gst = _bosItems.fold(0.0, (sum, item) => sum + item.gstAmount);
    final total = _isGstApplicable ? (taxable + gst) : taxable;

    return _buildSectionCard(
      title: '5. Electrical BOS Material (+ 18% GST)',
      badge: 'Taxable: ${_currency.format(taxable)} • GST: ${_currency.format(gst)} • Total: ${_currency.format(total)}',
      badgeColor: const Color(0xFF0D2B6F),
      onAdd: () {
        setState(() {
          _bosItems.add(SolarBosCostItem(
            id: 'bos_${DateTime.now().millisecondsSinceEpoch}',
            itemName: 'Cable Tray',
            unit: 'METER',
            quantity: 10,
            rate: 120.0,
            gstRate: 18.0,
          ));
        });
      },
      addLabel: '+ Add BOS Item',
      child: Column(
        children: _bosItems.asMap().entries.map((entry) {
          final idx = entry.key;
          final item = entry.value;
          return _buildBosRow(idx, item);
        }).toList(),
      ),
    );
  }

  Widget _buildBosRow(int index, SolarBosCostItem item) {
    const units = ['FIXED', 'METER', 'NOS', 'SET'];
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: TextFormField(
              initialValue: item.itemName,
              decoration: const InputDecoration(labelText: 'BOS Item', isDense: true),
              onChanged: (val) => _bosItems[index] = item.copyWith(itemName: val),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 90,
            child: DropdownButtonFormField<String>(
              initialValue: units.contains(item.unit.toUpperCase()) ? item.unit.toUpperCase() : 'FIXED',
              decoration: const InputDecoration(labelText: 'Unit', isDense: true),
              items: units.map((u) => DropdownMenuItem(value: u, child: Text(u, style: const TextStyle(fontSize: 12)))).toList(),
              onChanged: (val) {
                if (val != null) setState(() => _bosItems[index] = item.copyWith(unit: val));
              },
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 70,
            child: TextFormField(
              initialValue: item.quantity.toStringAsFixed(0),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Qty', isDense: true),
              onChanged: (val) {
                final d = double.tryParse(val) ?? 1.0;
                setState(() => _bosItems[index] = item.copyWith(quantity: d));
              },
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 100,
            child: TextFormField(
              initialValue: item.rate.toStringAsFixed(0),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Rate (₹)', prefixText: '₹', isDense: true),
              onChanged: (val) {
                final d = double.tryParse(val) ?? 0.0;
                setState(() => _bosItems[index] = item.copyWith(rate: d));
              },
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 80,
            child: DropdownButtonFormField<double>(
              initialValue: item.gstRate,
              decoration: const InputDecoration(labelText: 'GST %', isDense: true),
              items: const [
                DropdownMenuItem(value: 0.0, child: Text('0%')),
                DropdownMenuItem(value: 18.0, child: Text('18%')),
              ],
              onChanged: (val) {
                if (val != null) setState(() => _bosItems[index] = item.copyWith(gstRate: val));
              },
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('Taxable: ${_currency.format(item.taxableAmount)}', style: TextStyle(fontSize: 11, color: Colors.grey.shade700)),
              if (item.gstRate > 0)
                Text('+ GST: ${_currency.format(item.gstAmount)}', style: TextStyle(fontSize: 10, color: Colors.blue.shade700)),
              Text(_currency.format(_isGstApplicable ? item.totalAmount : item.taxableAmount), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0D2B6F))),
            ],
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.remove_circle_outline, color: Colors.redAccent, size: 20),
            onPressed: () => setState(() => _bosItems.removeAt(index)),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // SECTION 6: Other Materials
  // ---------------------------------------------------------------------------
  Widget _buildOtherMaterialsSection() {
    final taxable = _otherMaterials.fold(0.0, (sum, item) => sum + item.taxableAmount);
    final gst = _otherMaterials.fold(0.0, (sum, item) => sum + item.gstAmount);
    final total = _isGstApplicable ? (taxable + gst) : taxable;

    return _buildSectionCard(
      title: '6. Other Materials (Custom Rows)',
      badge: 'Taxable: ${_currency.format(taxable)} • GST: ${_currency.format(gst)} • Total: ${_currency.format(total)}',
      badgeColor: const Color(0xFF0D2B6F),
      onAdd: () {
        setState(() {
          _otherMaterials.add(SolarOtherMaterialItem(
            id: 'oth_${DateTime.now().millisecondsSinceEpoch}',
            materialName: 'Custom Item',
            specification: 'Site Specific',
            unit: 'NOS',
            quantity: 1,
            rate: 500.0,
            gstRate: 18.0,
          ));
        });
      },
      addLabel: '+ Add Other Material',
      child: _otherMaterials.isEmpty
          ? const Padding(
              padding: EdgeInsets.all(12),
              child: Text('No extra materials added. Click "+ Add Other Material" for custom site items.', style: TextStyle(fontSize: 12, color: Colors.grey)),
            )
          : Column(
              children: _otherMaterials.asMap().entries.map((entry) {
                final idx = entry.key;
                final item = entry.value;
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: TextFormField(
                          initialValue: item.materialName,
                          decoration: const InputDecoration(labelText: 'Material Name', isDense: true),
                          onChanged: (val) => _otherMaterials[idx] = item.copyWith(materialName: val),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 2,
                        child: TextFormField(
                          initialValue: item.specification,
                          decoration: const InputDecoration(labelText: 'Specification', isDense: true),
                          onChanged: (val) => _otherMaterials[idx] = item.copyWith(specification: val),
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 70,
                        child: TextFormField(
                          initialValue: item.unit,
                          decoration: const InputDecoration(labelText: 'Unit', isDense: true),
                          onChanged: (val) => _otherMaterials[idx] = item.copyWith(unit: val),
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 70,
                        child: TextFormField(
                          initialValue: item.quantity.toStringAsFixed(0),
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(labelText: 'Qty', isDense: true),
                          onChanged: (val) {
                            final d = double.tryParse(val) ?? 0.0;
                            setState(() => _otherMaterials[idx] = item.copyWith(quantity: d));
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 90,
                        child: TextFormField(
                          initialValue: item.rate.toStringAsFixed(0),
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(labelText: 'Rate (₹)', prefixText: '₹', isDense: true),
                          onChanged: (val) {
                            final d = double.tryParse(val) ?? 0.0;
                            setState(() => _otherMaterials[idx] = item.copyWith(rate: d));
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 80,
                        child: DropdownButtonFormField<double>(
                          initialValue: item.gstRate,
                          decoration: const InputDecoration(labelText: 'GST %', isDense: true),
                          items: const [
                            DropdownMenuItem(value: 0.0, child: Text('0%')),
                            DropdownMenuItem(value: 5.0, child: Text('5%')),
                            DropdownMenuItem(value: 12.0, child: Text('12%')),
                            DropdownMenuItem(value: 18.0, child: Text('18%')),
                            DropdownMenuItem(value: 28.0, child: Text('28%')),
                          ],
                          onChanged: (val) {
                            if (val != null) setState(() => _otherMaterials[idx] = item.copyWith(gstRate: val));
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('Taxable: ${_currency.format(item.taxableAmount)}', style: TextStyle(fontSize: 11, color: Colors.grey.shade700)),
                          if (item.gstRate > 0)
                            Text('+ GST: ${_currency.format(item.gstAmount)}', style: TextStyle(fontSize: 10, color: Colors.blue.shade700)),
                          Text(_currency.format(_isGstApplicable ? item.totalAmount : item.taxableAmount), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0D2B6F))),
                        ],
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.remove_circle_outline, color: Colors.redAccent, size: 20),
                        onPressed: () => setState(() => _otherMaterials.removeAt(idx)),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
    );
  }

  // ---------------------------------------------------------------------------
  // SECTION 7: Labour Cost (EXACTLY THREE CATEGORIES)
  // ---------------------------------------------------------------------------
  Widget _buildLabourSection() {
    final w = double.tryParse(_wiringLabourCtrl.text.trim()) ?? 0.0;
    final s = double.tryParse(_structureLabourCtrl.text.trim()) ?? 0.0;
    final c = double.tryParse(_civilLabourCtrl.text.trim()) ?? 0.0;
    final totalLabour = w + s + c;

    return _buildSectionCard(
      title: '7. Labour Cost (Only Three Categories)',
      badge: 'Total Labour: ${_currency.format(totalLabour)}',
      badgeColor: const Color(0xFF0D2B6F),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              children: [
                _buildLabourRow('A. Wiring Labour', 'AC, DC & Inverter Cable Wiring', _wiringLabourCtrl),
                const Divider(height: 16),
                _buildLabourRow('B. Structure Labour', 'Module Mounting Structure Erection', _structureLabourCtrl),
                const Divider(height: 16),
                _buildLabourRow('C. Civil Labour', 'Civil Foundation & Concrete Grouting', _civilLabourCtrl),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLabourRow(String title, String subtitle, TextEditingController ctrl) {
    return Row(
      children: [
        Expanded(
          flex: 4,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0D2B6F))),
              Text(subtitle, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
            ],
          ),
        ),
        SizedBox(
          width: 160,
          child: TextField(
            controller: ctrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Fixed Amount (₹)',
              prefixText: '₹',
              isDense: true,
            ),
            onChanged: (_) => setState(() {}),
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // SECTION 8: Other Expenses
  // ---------------------------------------------------------------------------
  Widget _buildExpensesSection() {
    final t = double.tryParse(_transportCtrl.text.trim()) ?? 0.0;
    final l = double.tryParse(_loadingCtrl.text.trim()) ?? 0.0;
    final o = double.tryParse(_otherExpCtrl.text.trim()) ?? 0.0;
    final customTotal = _customExpenses.fold(0.0, (sum, e) => sum + e.amount);
    final totalExp = t + l + o + customTotal;

    return _buildSectionCard(
      title: '8. Other Expenses (Transportation & Site Overhead)',
      badge: 'Total Expenses: ${_currency.format(totalExp)}',
      badgeColor: const Color(0xFF0D2B6F),
      onAdd: () {
        setState(() {
          _customExpenses.add(SolarCustomExpenseItem(
            id: 'exp_${DateTime.now().millisecondsSinceEpoch}',
            description: 'Site Contingency',
            amount: 500.0,
          ));
        });
      },
      addLabel: '+ Add Expense',
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              children: [
                _buildExpenseRow('Transportation Charges', 'Freight to site', _transportCtrl),
                const Divider(height: 16),
                _buildExpenseRow('Loading / Unloading', 'Site material handling', _loadingCtrl),
                const Divider(height: 16),
                _buildExpenseRow('Other General Expenses', 'Miscellaneous site expenses', _otherExpCtrl),
              ],
            ),
          ),
          if (_customExpenses.isNotEmpty) ...[
            const SizedBox(height: 8),
            ..._customExpenses.asMap().entries.map((entry) {
              final idx = entry.key;
              final item = entry.value;
              return Container(
                margin: const EdgeInsets.only(top: 6),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Row(
                  children: [
                    Expanded(
                      flex: 4,
                      child: TextFormField(
                        initialValue: item.description,
                        decoration: const InputDecoration(labelText: 'Custom Expense Description', isDense: true),
                        onChanged: (val) => _customExpenses[idx] = SolarCustomExpenseItem(id: item.id, description: val, amount: item.amount),
                      ),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 140,
                      child: TextFormField(
                        initialValue: item.amount.toStringAsFixed(0),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(labelText: 'Amount (₹)', prefixText: '₹', isDense: true),
                        onChanged: (val) {
                          final d = double.tryParse(val) ?? 0.0;
                          setState(() => _customExpenses[idx] = SolarCustomExpenseItem(id: item.id, description: item.description, amount: d));
                        },
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.remove_circle_outline, color: Colors.redAccent, size: 20),
                      onPressed: () => setState(() => _customExpenses.removeAt(idx)),
                    ),
                  ],
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  Widget _buildExpenseRow(String title, String subtitle, TextEditingController ctrl) {
    return Row(
      children: [
        Expanded(
          flex: 4,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0D2B6F))),
              Text(subtitle, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
            ],
          ),
        ),
        SizedBox(
          width: 160,
          child: TextField(
            controller: ctrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Amount (₹)',
              prefixText: '₹',
              isDense: true,
            ),
            onChanged: (_) => setState(() {}),
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // FINAL LIVE COST & GST SUMMARY CARD (PROMINENT UI)
  // ---------------------------------------------------------------------------
  Widget _buildLiveCostSummaryCard(SolarSiteCostCalculation calc, bool isBaseSampleMatch) {
    return Card(
      elevation: 2,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFF0D2B6F), width: 1.2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.calculate, color: Color(0xFF0D2B6F), size: 24),
                const SizedBox(width: 8),
                const Text(
                  'FINAL COST & GST SUMMARY',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0D2B6F), letterSpacing: 0.5),
                ),
                const Spacer(),
                if (isBaseSampleMatch)
                  const Tooltip(
                    message: 'Net material base cost matches Section 11 specifications!',
                    child: Icon(Icons.verified, color: Color(0xFF047857), size: 20),
                  ),
              ],
            ),
            const Divider(height: 20),

            _summaryLine('1. Solar Panels (Taxable):', calc.totalPanelTaxable),
            if (calc.totalPanelGst > 0)
              _summaryLine('   + 5% Panel GST:', calc.totalPanelGst, isIndented: true, isGst: true),
            
            _summaryLine('2. Inverter (Fixed Taxable):', calc.totalInverterTaxable),
            if (calc.totalInverterGst > 0)
              _summaryLine('   + Inverter GST:', calc.totalInverterGst, isIndented: true, isGst: true),

            _summaryLine('3. GI Pipe Structure (Taxable):', calc.totalGiPipeTaxable),
            if (calc.totalGiPipeGst > 0)
              _summaryLine('   + 18% GI Pipe GST:', calc.totalGiPipeGst, isIndented: true, isGst: true),

            if (calc.totalStructureTaxable > 0) ...[
              _summaryLine('4. Other Structure (Taxable):', calc.totalStructureTaxable),
              if (calc.totalStructureGst > 0)
                _summaryLine('   + 18% Structure GST:', calc.totalStructureGst, isIndented: true, isGst: true),
            ],

            _summaryLine('5. Electrical BOS (Taxable):', calc.totalBosTaxable),
            if (calc.totalBosGst > 0)
              _summaryLine('   + 18% BOS GST:', calc.totalBosGst, isIndented: true, isGst: true),

            if (calc.totalOtherMaterialTaxable > 0) ...[
              _summaryLine('6. Other Materials (Taxable):', calc.totalOtherMaterialTaxable),
              if (calc.totalOtherMaterialGst > 0)
                _summaryLine('   + Custom GST:', calc.totalOtherMaterialGst, isIndented: true, isGst: true),
            ],

            const Divider(height: 14),
            _summaryLine('Subtotal Taxable Material Cost:', calc.totalTaxableCost, isBold: true),
            _summaryLine('Total Material GST (5% & 18%):', calc.totalGstAmount, isBold: true, isGst: true),
            _summaryLine('7. Total Labour Cost (Wiring+Structure+Civil):', calc.totalLabourCost),
            _summaryLine('8. Total Other Expenses (Transport/Handling):', calc.totalOtherExpensesCost),

            const SizedBox(height: 12),

            // Prominent FINAL SITE COST Highlight Box
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF0D2B6F), // Deep Blue branding
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(color: const Color(0xFF0D2B6F).withValues(alpha: 0.2), blurRadius: 6, offset: const Offset(0, 3)),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _isGstApplicable ? 'FINAL SITE COST (WITH GST):' : 'FINAL SITE COST (NET BASE):',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 0.5),
                      ),
                      Text(
                        _currency.format(calc.finalSiteCost),
                        style: const TextStyle(
                          color: Color(0xFFFBBF24), // Golden Yellow branding
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                        ),
                      ),
                    ],
                  ),
                  const Divider(color: Colors.white24, height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _isGstApplicable
                            ? 'Net Base (w/o GST): ${_currency.format(calc.finalSiteCostWithoutGst)}'
                            : 'Gross (with GST): ${_currency.format(calc.finalSiteCostWithGst)}',
                        style: const TextStyle(color: Colors.white70, fontSize: 11),
                      ),
                      if (calc.systemCapacityKw > 0)
                        Text(
                          '${_currency.format(calc.costPerKw)} / kW',
                          style: const TextStyle(color: Color(0xFF86EFAC), fontWeight: FontWeight.bold, fontSize: 12.5),
                        ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),

            // Quick action buttons inside summary card
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.picture_as_pdf, size: 16),
                    label: const Text('PDF'),
                    onPressed: _exportPdf,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.table_view, size: 16),
                    label: const Text('CSV'),
                    onPressed: _exportCsv,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF047857),
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.save, size: 16),
                    label: const Text('Save'),
                    onPressed: _saveCalculation,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _summaryLine(String title, double amount, {bool isBold = false, bool isIndented = false, bool isGst = false}) {
    return Padding(
      padding: EdgeInsets.only(top: 2, bottom: 2, left: isIndented ? 12 : 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: isBold ? 12.5 : 12,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              color: isGst ? Colors.blue.shade800 : (isBold ? const Color(0xFF0D2B6F) : Colors.grey.shade800),
            ),
          ),
          Text(
            _currency.format(amount),
            style: TextStyle(
              fontSize: isBold ? 13 : 12,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
              color: isGst ? Colors.blue.shade800 : (isBold ? const Color(0xFF0D2B6F) : Colors.black87),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Reusable Section Card Wrapper
  // ---------------------------------------------------------------------------
  Widget _buildSectionCard({
    required String title,
    required String badge,
    required Color badgeColor,
    required Widget child,
    VoidCallback? onAdd,
    String? addLabel,
  }) {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0D2B6F)),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Text(
                    badge,
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: badgeColor),
                  ),
                ),
                if (onAdd != null && addLabel != null) ...[
                  const SizedBox(width: 8),
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      visualDensity: VisualDensity.compact,
                    ),
                    icon: const Icon(Icons.add, size: 16),
                    label: Text(addLabel, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    onPressed: onAdd,
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}
