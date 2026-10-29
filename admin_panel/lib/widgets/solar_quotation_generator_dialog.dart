import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'package:siya_shared/siya_shared.dart';

import '../services/customer_signature_helper.dart';
import '../services/margin_money_receipt_service.dart';
import '../services/quotation_storage_service.dart';
import '../services/record_service.dart';
import '../services/solar_quotation_service.dart';

/// Professional Bilingual Solar Quotation Generator Dialog
/// Features:
/// 1. Language Selection: Marathi + English Mix (Default), English, Marathi
/// 2. Quotation Type: Residential / Commercial
/// 3. Option A (New Customer with optional Save to Master) & Option B (Existing Customer)
/// 4. Solar System Configuration (Capacity, Type, Package, Panels, Inverter, Structure)
/// 5. Item-wise Editable Pricing
/// 6. Pricing & Statutory 70:30 GST Breakdown Card
/// 7. On-Grid Solar System Working Schematic (Vector visual preview & PDF toggle)
/// 8. January–December 12-Month Generation Table & Interactive Bar Chart
/// 9. PM Surya Ghar Subsidy Calculator (Residential)
/// 10. Solar Savings, ROI & Payback Analysis
/// 11. Payment Modes: Cash / Bank Loan / Part Payment with Reducing-Balance EMI Formula
/// 12. Live A4 PDF Preview & WhatsApp Sharing with Bilingual Template
class SolarQuotationGeneratorDialog extends StatefulWidget {
  final ConsumerRecord? customer;
  final SolarQuotation? initialQuotation;
  final int initialTab; // 0 = Quotation Generator, 1 = Margin Money Receipt

  const SolarQuotationGeneratorDialog({
    super.key,
    this.customer,
    this.initialQuotation,
    this.initialTab = 0,
  });

  static Future<void> show(
    BuildContext context, {
    ConsumerRecord? customer,
    SolarQuotation? initialQuotation,
    int initialTab = 0,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: SizedBox(
          width: 1300,
          height: 900,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: SolarQuotationGeneratorDialog(
              customer: customer,
              initialQuotation: initialQuotation,
              initialTab: initialTab,
            ),
          ),
        ),
      ),
    );
  }

  @override
  State<SolarQuotationGeneratorDialog> createState() => _SolarQuotationGeneratorDialogState();
}

class _SolarQuotationGeneratorDialogState extends State<SolarQuotationGeneratorDialog> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Language & Quotation Type
  String _language = 'en'; // 100% Corporate English Proposal
  String _quotationType = 'Residential'; // 'Residential' or 'Commercial'

  // Customer Details
  String? _customerId;
  bool _isSavedCustomer = false;
  final _customerNameCtrl = TextEditingController();
  final _consumerNoCtrl = TextEditingController();
  final _mobileNoCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _villageCityCtrl = TextEditingController();
  final _districtCtrl = TextEditingController(text: 'Dhule');
  final _emailCtrl = TextEditingController();

  // Quotation Metadata
  late String _quotationNo;
  final _quotationNoCtrl = TextEditingController();
  late DateTime _quotationDate;
  String _status = 'Issued';
  final _connectionTypeCtrl = TextEditingController(text: 'LT Residential 1-Phase (230V)');

  // Solar System Configuration
  String _capacity = '3 kW';
  String _systemType = 'On-Grid Solar System';
  final _packageNameCtrl = TextEditingController(text: 'PM Surya Ghar Standard Package');
  final _panelBrandCtrl = TextEditingController(text: 'Waaree / Adani / Goldi (DCR TopCon)');
  final _panelWattageCtrl = TextEditingController(text: '540 Wp / 550 Wp');
  final _panelCountCtrl = TextEditingController(text: '6');
  final _inverterBrandCtrl = TextEditingController(text: 'Sungrow / Growatt / Solis');
  final _inverterCapacityCtrl = TextEditingController(text: '3.3 kW Grid-Tie');
  final _mountingStructureCtrl = TextEditingController(text: 'Hot Dip GI Elevated Rooftop Structure');

  // Pricing & GST
  double _totalCost = 200000.0;
  double _discount = 0.0;
  double _gstAmount = 0.0;
  double _grandTotal = 200000.0;
  final _grandTotalCtrl = TextEditingController(text: '200000');
  final _discountCtrl = TextEditingController(text: '0');

  // Material-wise Line Items
  List<Map<String, String>> _items = [];

  // Subsidy & Pricing Option
  double _subsidyAmount = 78000.0;
  final _subsidyAmountCtrl = TextEditingController(text: '78000');
  bool _includeSubsidyInPricing = true;
  double _payableAfterSubsidy = 122000.0;

  // Payment Mode & Bank Loan EMI
  String _paymentMode = 'Bank Loan'; // 'Cash', 'Bank Loan', 'Part Payment + Bank Loan'
  final _loanBankNameCtrl = TextEditingController(text: 'STATE BANK OF INDIA');
  double _downPayment = 12200.0;
  double _bankLoan = 109800.0;
  final _loanAmountCtrl = TextEditingController(text: '109800');
  final _downPaymentCtrl = TextEditingController(text: '12200');
  double _annualInterestRate = 7.5;
  final _interestRateCtrl = TextEditingController(text: '7.5');
  int _loanTenureMonths = 60;
  double _monthlyEmi = 2201.0;
  double _processingFees = 0.0;

  // Company Bank Account (for RTGS / NEFT / Disbursement)
  final _companyAccountNameCtrl = TextEditingController(text: 'SIYA INFOTECH & SOLAR ENERGY');
  final _companyBankNameCtrl = TextEditingController(text: 'STATE BANK OF INDIA');
  final _branchCtrl = TextEditingController(text: 'Betawad');
  final _accountNoCtrl = TextEditingController(text: '40662252403');
  final _ifscCodeCtrl = TextEditingController(text: 'SBIN0004798');
  final _upiIdCtrl = TextEditingController(text: 'siyainfodigital@sbi');

  // Commercial Terms, Warranties & Site Notes
  final _termsCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  // Signatory & Authorization
  final _signatoryNameCtrl = TextEditingController(text: 'Manoj Kshirsagar');
  final _signatoryDesignationCtrl = TextEditingController(text: 'Proprietor / Authorized Signatory');

  // Solar Generation, ROI & Payback
  double _electricityTariff = 8.0;
  final _tariffCtrl = TextEditingController(text: '8.0');
  double _annualMaintenance = 1500.0;
  final _maintenanceCtrl = TextEditingController(text: '1500');
  double _annualGenerationUnits = 4365.0;
  final _annualGenerationUnitsCtrl = TextEditingController(text: '4365');
  double _annualSavings = 34920.0;
  double _paybackYears = 3.6;

  // Diagram & PDF toggles
  bool _includeDiagram = true;
  bool _includeGenerationTable = true;
  bool _includeRoi = true;
  bool _includeStampAndSignature = true;
  bool _includeCustomerSignature = false;
  Uint8List? _customCustomerSignatureBytes;

  // Margin Money Receipt Tab State
  late String _receiptNo;
  final _receiptNoCtrl = TextEditingController();
  late DateTime _receiptDate;
  String _receiptPaymentMode = 'Cash';
  final _receiptTransactionRefCtrl = TextEditingController(text: 'Paid in Cash');
  DateTime _receiptPaymentDate = DateTime.now();
  double _receiptMarginAmount = 20000.0;
  final _receiptMarginAmountCtrl = TextEditingController(text: '20000');
  final _receiptNotesCtrl = TextEditingController(text: 'Received 10% Customer Margin Contribution in Cash towards PM Surya Ghar Bank Solar Loan installation.');

  // Formatters
  final _inrFormat = NumberFormat.currency(locale: 'en_IN', symbol: '₹ ', decimalDigits: 0);
  final _dateFormat = DateFormat('dd/MM/yyyy');
  int _renderKey = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this, initialIndex: widget.initialTab);
    _initValues();
    _checkCustomerSignature();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _customerNameCtrl.dispose();
    _consumerNoCtrl.dispose();
    _mobileNoCtrl.dispose();
    _addressCtrl.dispose();
    _villageCityCtrl.dispose();
    _districtCtrl.dispose();
    _emailCtrl.dispose();
    _quotationNoCtrl.dispose();
    _connectionTypeCtrl.dispose();
    _packageNameCtrl.dispose();
    _panelBrandCtrl.dispose();
    _panelWattageCtrl.dispose();
    _panelCountCtrl.dispose();
    _inverterBrandCtrl.dispose();
    _inverterCapacityCtrl.dispose();
    _mountingStructureCtrl.dispose();
    _grandTotalCtrl.dispose();
    _discountCtrl.dispose();
    _subsidyAmountCtrl.dispose();
    _loanBankNameCtrl.dispose();
    _companyAccountNameCtrl.dispose();
    _companyBankNameCtrl.dispose();
    _branchCtrl.dispose();
    _accountNoCtrl.dispose();
    _ifscCodeCtrl.dispose();
    _upiIdCtrl.dispose();
    _termsCtrl.dispose();
    _notesCtrl.dispose();
    _signatoryNameCtrl.dispose();
    _signatoryDesignationCtrl.dispose();
    _loanAmountCtrl.dispose();
    _downPaymentCtrl.dispose();
    _interestRateCtrl.dispose();
    _tariffCtrl.dispose();
    _maintenanceCtrl.dispose();
    _annualGenerationUnitsCtrl.dispose();
    _receiptNoCtrl.dispose();
    _receiptTransactionRefCtrl.dispose();
    _receiptMarginAmountCtrl.dispose();
    _receiptNotesCtrl.dispose();
    super.dispose();
  }

  void _initValues() {
    final q = widget.initialQuotation;
    final c = widget.customer;

    _customerId = q?.customerId ?? c?.id;
    _isSavedCustomer = _customerId != null && _customerId!.isNotEmpty;

    _customerNameCtrl.text = q?.customerName ?? c?.name.trim() ?? '';
    _consumerNoCtrl.text = q?.consumerNo ?? c?.consumerNo.trim() ?? '';
    _mobileNoCtrl.text = q?.mobileNo ?? c?.mobile?.trim() ?? '';
    final addr = q?.address ?? (c?.address?.trim() ?? '');
    _addressCtrl.text = addr.isNotEmpty ? addr : 'Betawad';
    _villageCityCtrl.text = q?.villageCity ?? (c?.village ?? (addr.isNotEmpty ? addr : 'Betawad'));
    _districtCtrl.text = q?.district ?? 'Dhule';
    _emailCtrl.text = q?.email ?? '';

    _quotationDate = q?.quotationDate ?? DateTime.now();
    final suffix = _consumerNoCtrl.text.length > 4
        ? _consumerNoCtrl.text.substring(_consumerNoCtrl.text.length - 4)
        : (_consumerNoCtrl.text.isNotEmpty ? _consumerNoCtrl.text : '${DateTime.now().millisecondsSinceEpoch % 10000}'.padLeft(4, '0'));
    _quotationNo = q?.quotationNo ?? 'SIYA-Q-${_quotationDate.year}-$suffix';
    _quotationNoCtrl.text = _quotationNo;
    _status = q?.status ?? 'Issued';
    _connectionTypeCtrl.text = q?.connectionType ?? 'LT Residential 1-Phase (230V)';

    if (q != null) {
      _language = q.language;
      _quotationType = q.quotationType;
      _capacity = q.systemCapacity;
      _systemType = q.systemType;
      _totalCost = q.totalSystemCost;
      _discount = q.discount;
      _grandTotal = q.grandTotal;
      _grandTotalCtrl.text = _grandTotal.toStringAsFixed(0);
      _discountCtrl.text = _discount.toStringAsFixed(0);
      _subsidyAmount = q.subsidyAmount;
      _subsidyAmountCtrl.text = _subsidyAmount.toStringAsFixed(0);
      _includeSubsidyInPricing = q.includeSubsidyInPricing;
      _payableAfterSubsidy = q.payableAfterSubsidy;
      _paymentMode = q.paymentMode;
      _loanBankNameCtrl.text = q.bankName.isNotEmpty ? q.bankName : 'STATE BANK OF INDIA';
      _bankLoan = q.bankLoanAmount;
      _loanAmountCtrl.text = _bankLoan.toStringAsFixed(0);
      _downPayment = q.downPayment;
      _downPaymentCtrl.text = _downPayment.toStringAsFixed(0);
      _annualInterestRate = q.annualInterestRate;
      _interestRateCtrl.text = _annualInterestRate.toStringAsFixed(1);
      _loanTenureMonths = q.loanTenureMonths;
      _monthlyEmi = q.monthlyEmi;
      _electricityTariff = q.electricityTariff;
      _tariffCtrl.text = _electricityTariff.toStringAsFixed(1);
      _annualGenerationUnits = q.annualGenerationUnits;
      _annualGenerationUnitsCtrl.text = _annualGenerationUnits.toStringAsFixed(0);
      _annualSavings = q.annualSavings;
      _paybackYears = q.paybackYears;
      _packageNameCtrl.text = q.solarPackageName;
      _panelBrandCtrl.text = q.panelBrand;
      _panelWattageCtrl.text = q.panelWattage;
      _panelCountCtrl.text = q.panelCount.toString();
      _inverterBrandCtrl.text = q.inverterBrand;
      _inverterCapacityCtrl.text = q.inverterCapacity;
      _mountingStructureCtrl.text = q.mountingStructure;
      
      _companyBankNameCtrl.text = q.bankName.isNotEmpty ? q.bankName : CompanyMaster.current.bankName;
      _companyAccountNameCtrl.text = CompanyMaster.current.companyName;
      _branchCtrl.text = q.branch.isNotEmpty ? q.branch : CompanyMaster.current.branch;
      _accountNoCtrl.text = q.accountNo.isNotEmpty ? q.accountNo : CompanyMaster.current.accountNo;
      _ifscCodeCtrl.text = q.ifscCode.isNotEmpty ? q.ifscCode : CompanyMaster.current.ifscCode;
      _upiIdCtrl.text = q.upiId.isNotEmpty ? q.upiId : CompanyMaster.current.upiId;

      _termsCtrl.text = q.termsAndConditions.isNotEmpty
          ? q.termsAndConditions.join('\n')
          : SolarQuotation.defaultImportantNotes.join('\n');
      _notesCtrl.text = q.notes ?? '';
      _signatoryNameCtrl.text = q.signatoryName.isNotEmpty ? q.signatoryName : CompanyMaster.current.signatoryName;
      _signatoryDesignationCtrl.text = q.signatoryDesignation.isNotEmpty ? q.signatoryDesignation : CompanyMaster.current.signatoryDesignation;

      _includeDiagram = q.includeDiagram;
      _includeGenerationTable = q.includeGenerationTable;
      _includeRoi = q.includeRoi;
      _items = List.from(q.items);
    } else {
      // New quotation defaults
      if (c != null && c.systemCapacity != null && c.systemCapacity!.trim().isNotEmpty) {
        _capacity = c.systemCapacity!.trim();
      }
      _items = SolarQuotation.defaultItems(_capacity);
      _termsCtrl.text = SolarQuotation.defaultImportantNotes.join('\n');
      _recalculateAll(recalculateSubsidyFromFormula: true, recalculateGenFromFormula: true);
    }

    // Margin Receipt initialization
    _receiptDate = _quotationDate;
    _receiptNo = 'SIYA-MMR-${_receiptDate.year}-$suffix';
    _receiptNoCtrl.text = _receiptNo;
    _receiptPaymentDate = _receiptDate;
    _receiptMarginAmount = _downPayment > 0 ? _downPayment : 12200.0;
    _receiptMarginAmountCtrl.text = _receiptMarginAmount.toStringAsFixed(0);
    _receiptTransactionRefCtrl.text = 'Paid in Cash';
    _receiptNotesCtrl.text = 'Received 10% Customer Margin Contribution in Cash towards PM Surya Ghar Bank Solar Loan installation.';
  }

  Future<void> _checkCustomerSignature() async {
    final consNo = _consumerNoCtrl.text.trim();
    if (consNo.isNotEmpty) {
      final hasSig = await CustomerSignatureHelper.ensureCustomerSignatureLoaded(consNo);
      if (hasSig && mounted) {
        setState(() => _includeCustomerSignature = true);
      }
    }
  }

  void _recalculateAll({
    bool recalculateSubsidyFromFormula = false,
    bool recalculateGenFromFormula = false,
  }) {
    final capKw = SolarQuotationCalculations.parseCapacity(_capacity);

    // Subsidy calculation
    if (recalculateSubsidyFromFormula || _subsidyAmountCtrl.text.trim().isEmpty) {
      _subsidyAmount = SolarQuotationCalculations.calculatePmSuryaGharSubsidy(
        capacityKw: capKw,
        quotationType: _quotationType,
      );
      _subsidyAmountCtrl.text = _subsidyAmount.toStringAsFixed(0);
    } else {
      _subsidyAmount = double.tryParse(_subsidyAmountCtrl.text.trim()) ??
          SolarQuotationCalculations.calculatePmSuryaGharSubsidy(
            capacityKw: capKw,
            quotationType: _quotationType,
          );
    }

    // Grand total
    final enteredGrand = double.tryParse(_grandTotalCtrl.text.trim()) ?? 200000.0;
    _discount = double.tryParse(_discountCtrl.text.trim()) ?? 0.0;
    _grandTotal = (enteredGrand - _discount).clamp(0.0, double.infinity);
    _totalCost = _grandTotal;

    // Payable after subsidy
    _payableAfterSubsidy = (_grandTotal - (_includeSubsidyInPricing && _quotationType != 'Commercial' ? _subsidyAmount : 0.0))
        .clamp(0.0, double.infinity);

    final double netFinancingBase = (_quotationType != 'Commercial' && _subsidyAmount > 0)
        ? _payableAfterSubsidy
        : _grandTotal;

    // Loan & EMI (Calculated on Net Amount After Subsidy)
    if (_paymentMode.toLowerCase().contains('loan')) {
      if (_paymentMode == 'Part Payment + Bank Loan') {
        _downPayment = double.tryParse(_downPaymentCtrl.text.trim()) ?? (netFinancingBase * 0.10).roundToDouble();
        _bankLoan = (netFinancingBase - _downPayment).clamp(0.0, double.infinity);
        _loanAmountCtrl.text = _bankLoan.toStringAsFixed(0);
      } else {
        final enteredLoan = double.tryParse(_loanAmountCtrl.text.trim());
        // Default loan is 90% of Net Amount After Subsidy
        if (enteredLoan == null || enteredLoan == 0.0 || enteredLoan > netFinancingBase) {
          _bankLoan = (netFinancingBase * 0.90).roundToDouble();
          _loanAmountCtrl.text = _bankLoan.toStringAsFixed(0);
        } else {
          _bankLoan = enteredLoan;
        }
        _downPayment = (netFinancingBase - _bankLoan).clamp(0.0, double.infinity);
        _downPaymentCtrl.text = _downPayment.toStringAsFixed(0);
      }
      _annualInterestRate = double.tryParse(_interestRateCtrl.text.trim()) ?? 7.5;
      _monthlyEmi = SolarQuotationCalculations.calculateMonthlyEmi(
        principal: _bankLoan,
        annualInterestRate: _annualInterestRate,
        tenureMonths: _loanTenureMonths,
      );
    } else {
      _bankLoan = 0.0;
      _downPayment = _grandTotal;
      _monthlyEmi = 0.0;
    }

    // Solar generation & ROI
    _electricityTariff = double.tryParse(_tariffCtrl.text.trim()) ?? 8.0;
    _annualMaintenance = double.tryParse(_maintenanceCtrl.text.trim()) ?? 1500.0;
    
    if (recalculateGenFromFormula || _annualGenerationUnitsCtrl.text.trim().isEmpty) {
      _annualGenerationUnits = SolarQuotationCalculations.calculateAnnualGenerationUnits(capKw);
      _annualGenerationUnitsCtrl.text = _annualGenerationUnits.toStringAsFixed(0);
    } else {
      _annualGenerationUnits = double.tryParse(_annualGenerationUnitsCtrl.text.trim()) ??
          SolarQuotationCalculations.calculateAnnualGenerationUnits(capKw);
    }

    _annualSavings = (_annualGenerationUnits * _electricityTariff).roundToDouble();

    final roiData = SolarQuotationCalculations.calculateRoiAndPayback(
      totalSystemCost: _grandTotal,
      eligibleSubsidy: _subsidyAmount,
      deductSubsidyFromNetInvestment: _includeSubsidyInPricing && _quotationType != 'Commercial',
      annualGenerationUnits: _annualGenerationUnits,
      electricityTariff: _electricityTariff,
      annualMaintenanceCost: _annualMaintenance,
    );
    _paybackYears = (roiData['paybackYears'] as num).toDouble();

    // Update margin receipt default amount if down payment changed
    if (_downPayment > 0) {
      _receiptMarginAmount = _downPayment;
      _receiptMarginAmountCtrl.text = _receiptMarginAmount.toStringAsFixed(0);
    }

    // Panel count suggestion
    final wattage = double.tryParse(RegExp(r'\d+').firstMatch(_panelWattageCtrl.text)?.group(0) ?? '540') ?? 540.0;
    _panelCountCtrl.text = ((capKw * 1000) / wattage).ceil().toString();

    _renderKey++;
  }

  SolarQuotation _buildQuotationObject() {
    final capKw = SolarQuotationCalculations.parseCapacity(_capacity);
    final count = int.tryParse(_panelCountCtrl.text.trim()) ?? ((capKw * 1000) / 540).ceil();
    final effectiveQuotationNo = _quotationNoCtrl.text.trim().isNotEmpty ? _quotationNoCtrl.text.trim() : _quotationNo;

    final parsedTerms = _termsCtrl.text
        .split('\n')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    return SolarQuotation.create(
      id: widget.initialQuotation?.id,
      customerId: _customerId,
      consumerNo: _consumerNoCtrl.text.trim(),
      customerName: _customerNameCtrl.text.trim().isNotEmpty ? _customerNameCtrl.text.trim() : 'Valued Customer',
      address: _addressCtrl.text.trim(),
      villageCity: _villageCityCtrl.text.trim(),
      district: _districtCtrl.text.trim(),
      mobileNo: _mobileNoCtrl.text.trim(),
      quotationNo: effectiveQuotationNo,
      quotationDate: _quotationDate,
      systemCapacity: _capacity,
      systemType: _systemType,
      totalSystemCost: _totalCost,
      gstAmount: _gstAmount,
      grandTotal: _grandTotal,
      bankLoanAmount: _bankLoan,
      customerContribution: _downPayment,
      bankName: _companyBankNameCtrl.text.trim(),
      branch: _branchCtrl.text.trim(),
      accountNo: _accountNoCtrl.text.trim(),
      ifscCode: _ifscCodeCtrl.text.trim(),
      upiId: _upiIdCtrl.text.trim(),
      signatoryName: _signatoryNameCtrl.text.trim(),
      signatoryDesignation: _signatoryDesignationCtrl.text.trim(),
      items: _items,
      status: _status,
      quotationType: _quotationType,
      language: _language,
      subsidyAmount: _subsidyAmount,
      payableAfterSubsidy: _payableAfterSubsidy,
      includeSubsidyInPricing: _includeSubsidyInPricing,
      paymentMode: _paymentMode,
      downPayment: _downPayment,
      loanTenureMonths: _loanTenureMonths,
      annualInterestRate: _annualInterestRate,
      monthlyEmi: _monthlyEmi,
      processingFees: _processingFees,
      electricityTariff: _electricityTariff,
      annualGenerationUnits: _annualGenerationUnits,
      annualSavings: _annualSavings,
      paybackYears: _paybackYears,
      solarPackageName: _packageNameCtrl.text.trim(),
      panelBrand: _panelBrandCtrl.text.trim(),
      panelWattage: _panelWattageCtrl.text.trim(),
      panelCount: count,
      inverterBrand: _inverterBrandCtrl.text.trim(),
      inverterCapacity: _inverterCapacityCtrl.text.trim(),
      mountingStructure: _mountingStructureCtrl.text.trim(),
      includeDiagram: _includeDiagram,
      includeGenerationTable: _includeGenerationTable,
      includeRoi: _includeRoi,
      termsAndConditions: parsedTerms.isNotEmpty ? parsedTerms : SolarQuotation.defaultImportantNotes,
      notes: _notesCtrl.text.trim().isNotEmpty ? _notesCtrl.text.trim() : null,
      email: _emailCtrl.text.trim().isNotEmpty ? _emailCtrl.text.trim() : null,
      connectionType: _connectionTypeCtrl.text.trim().isNotEmpty ? _connectionTypeCtrl.text.trim() : 'LT Residential 1-Phase (230V)',
      discount: _discount,
    );
  }

  Future<void> _handleSaveQuotation() async {
    try {
      final quotation = _buildQuotationObject();
      await QuotationStorageService.saveQuotation(quotation);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Quotation ${quotation.quotationNo} saved successfully!'),
            backgroundColor: const Color(0xFF047857),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save quotation: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _handleSaveCustomerToMaster() async {
    final name = _customerNameCtrl.text.trim();
    final mobile = _mobileNoCtrl.text.trim();
    if (name.isEmpty || mobile.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Customer Name and Mobile Number are required to save to Customer Master.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Save Customer to Customer Master?'),
        content: Text(
          'Add "$name" ($mobile) as a permanent customer record in the Customer Master?\n\n'
          'This will link this quotation and future documents directly to the customer profile.',
          style: const TextStyle(fontSize: 13),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFF047857)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Save Customer'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      final newRecord = ConsumerRecord(
        name: name,
        mobile: mobile,
        address: _addressCtrl.text.trim().isNotEmpty
            ? _addressCtrl.text.trim()
            : '${_villageCityCtrl.text.trim()}, ${_districtCtrl.text.trim()}',
        consumerNo: _consumerNoCtrl.text.trim().isNotEmpty
            ? _consumerNoCtrl.text.trim()
            : 'CN-${DateTime.now().millisecondsSinceEpoch % 1000000}',
        systemCapacity: _capacity,
        totalAmount: _grandTotal,
        loanSanctionedAmount: _bankLoan,
      );

      final created = await RecordService.createRecord(newRecord);
      setState(() {
        _customerId = created.id;
        _isSavedCustomer = true;
      });

      // Save quotation with newly generated customer ID
      await _handleSaveQuotation();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Customer "$name" added to Customer Master!'),
            backgroundColor: const Color(0xFF047857),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error creating customer record: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _openSearchMasterCustomer() async {
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
                    Text('Select Customer from Master', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    Text('Search by Customer Name, Consumer No., or Mobile', style: TextStyle(fontSize: 11, color: Colors.grey)),
                  ],
                ),
              ],
            ),
            content: SizedBox(
              width: 500,
              height: 380,
              child: Column(
                children: [
                  TextField(
                    controller: searchCtrl,
                    autofocus: true,
                    onChanged: doSearch,
                    decoration: InputDecoration(
                      hintText: 'Type Name, Consumer No., or Mobile...',
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
                        child: Text('Type to search Customer Master...', style: TextStyle(color: Colors.grey, fontSize: 12)),
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
                            subtitle: Text('Consumer No: ${c.consumerNo} • ${c.village ?? c.address ?? ''} • ${c.systemCapacity ?? '3 kW'}', style: const TextStyle(fontSize: 12)),
                            trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey),
                            onTap: () {
                              Navigator.pop(ctx);
                              setState(() {
                                _customerId = c.id;
                                _isSavedCustomer = true;
                                _customerNameCtrl.text = c.name.trim();
                                _consumerNoCtrl.text = c.consumerNo.trim();
                                _mobileNoCtrl.text = c.mobile?.trim() ?? '';
                                final addr = c.address?.trim() ?? '';
                                _addressCtrl.text = addr.isNotEmpty ? addr : 'Betawad';
                                _villageCityCtrl.text = addr.isNotEmpty ? addr : 'Betawad';
                                _districtCtrl.text = 'Dhule';
                                if (c.systemCapacity != null && c.systemCapacity!.trim().isNotEmpty) {
                                  _capacity = c.systemCapacity!.trim();
                                  _items = SolarQuotation.defaultItems(_capacity);
                                }
                                _recalculateAll();
                                _checkCustomerSignature();
                              });
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

  Future<void> _handleWhatsAppShare() async {
    final quotation = _buildQuotationObject();
    await _handleSaveQuotation();

    // Trigger PDF download first so user can attach
    if (mounted) {
      try {
        final pdfBytes = await SolarQuotationService.generateQuotationPdfBytes(
          quotation,
          includeStampAndSignature: _includeStampAndSignature,
          includeCustomerSignature: _includeCustomerSignature,
          customCustomerSignatureBytes: _customCustomerSignatureBytes,
        );
        await Printing.sharePdf(bytes: pdfBytes, filename: quotation.pdfFileName);
      } catch (_) {}
    }

    // Open WhatsApp
    await SolarQuotationService.shareViaWhatsApp(quotation);
  }

  @override
  Widget build(BuildContext context) {
    final t = SolarQuotationTranslations(_language);
    final isDesktop = MediaQuery.of(context).size.width >= 960;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D2B6F),
        foregroundColor: Colors.white,
        title: Row(
          children: [
            const Icon(Icons.solar_power_rounded, color: Color(0xFFF59E0B), size: 24),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t.quotationTitle,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                Text(
                  'SIYA INFOTECH & SOLAR ENERGY • Quotation: $_quotationNo',
                  style: const TextStyle(fontSize: 11, color: Color(0xFF93C5FD)),
                ),
              ],
            ),
          ],
        ),
        actions: [
          // Save Customer button if not yet in master
          if (!_isSavedCustomer) ...[
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF047857),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              onPressed: _handleSaveCustomerToMaster,
              icon: const Icon(Icons.person_add_rounded, size: 16),
              label: const Text('Save Customer to Master', style: TextStyle(fontSize: 12)),
            ),
            const SizedBox(width: 8),
          ],
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            onPressed: _handleSaveQuotation,
            icon: const Icon(Icons.save_rounded, size: 16),
            label: const Text('Save Quotation', style: TextStyle(fontSize: 12)),
          ),
          const SizedBox(width: 8),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF25D366),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            onPressed: _handleWhatsAppShare,
            icon: const Icon(Icons.share_rounded, size: 16),
            label: const Text('WhatsApp Share', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 12),
          IconButton(
            icon: const Icon(Icons.close_rounded),
            tooltip: 'Close',
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: const Color(0xFF93C5FD),
          indicatorColor: const Color(0xFFF59E0B),
          indicatorWeight: 3,
          tabs: const [
            Tab(icon: Icon(Icons.receipt_long_rounded, size: 18), text: 'Solar Project Proposal Generator'),
            Tab(icon: Icon(Icons.description_outlined, size: 18), text: 'Customer Margin Money Receipt (10%)'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Tab 0: Solar Quotation Generator (Split Pane: Form + Live PDF Preview)
          isDesktop
              ? Row(
                  children: [
                    // Left: Form configuration (12 Sections)
                    Expanded(
                      flex: 5,
                      child: Container(
                        decoration: const BoxDecoration(
                          border: Border(right: BorderSide(color: Color(0xFFE2E8F0))),
                        ),
                        child: _buildFormView(t),
                      ),
                    ),
                    // Right: Live A4 PDF Preview
                    Expanded(
                      flex: 5,
                      child: _buildPdfPreviewPane(),
                    ),
                  ],
                )
              : _buildMobileTabs(t),

          // Tab 1: Customer Margin Money Receipt
          _buildMarginReceiptTab(),
        ],
      ),
    );
  }

  // ── MOBILE TAB VIEW ────────────────────────────────────────────────────────
  Widget _buildMobileTabs(SolarQuotationTranslations t) {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          const TabBar(
            labelColor: Color(0xFF0D2B6F),
            tabs: [
              Tab(text: 'Proposal Form Details'),
              Tab(text: 'Proposal PDF Preview & Share'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                _buildFormView(t),
                _buildPdfPreviewPane(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // SECTION 1 TO 12: FORM VIEW
  // ===========================================================================
  Widget _buildFormView(SolarQuotationTranslations t) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── SECTION 1: QUOTATION DETAILS, CATEGORY & STATUS ───────────────
          _buildCard(
            title: '1. Quotation Details, Project Category & Status',
            icon: Icons.category_rounded,
            iconColor: const Color(0xFF1D4ED8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      flex: 5,
                      child: TextField(
                        controller: _quotationNoCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Quotation No. *',
                          helperText: 'Auto-generated or custom editable',
                          isDense: true,
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (_) => setState(() => _renderKey++),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 4,
                      child: InkWell(
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: _quotationDate,
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2035),
                          );
                          if (picked != null) {
                            setState(() {
                              _quotationDate = picked;
                              _renderKey++;
                            });
                          }
                        },
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'Quotation Date *',
                            isDense: true,
                            border: OutlineInputBorder(),
                            suffixIcon: Icon(Icons.calendar_today_rounded, size: 18),
                          ),
                          child: Text(_dateFormat.format(_quotationDate), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 3,
                      child: DropdownButtonFormField<String>(
                        value: _status,
                        decoration: const InputDecoration(
                          labelText: 'Status',
                          isDense: true,
                          border: OutlineInputBorder(),
                        ),
                        items: ['Issued', 'Draft', 'Approved', 'Invoiced', 'Cancelled']
                            .map((st) => DropdownMenuItem(value: st, child: Text(st)))
                            .toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() {
                              _status = val;
                              _renderKey++;
                            });
                          }
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      flex: 6,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Project Category:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                          const SizedBox(height: 4),
                          SegmentedButton<String>(
                            segments: const [
                              ButtonSegment(value: 'Residential', label: Text('Residential (PM Surya Ghar)')),
                              ButtonSegment(value: 'Commercial', label: Text('Commercial & Industrial')),
                            ],
                            selected: {_quotationType},
                            onSelectionChanged: (val) {
                              setState(() {
                                _quotationType = val.first;
                                _recalculateAll();
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 6,
                      child: TextField(
                        controller: _connectionTypeCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Grid Connection Type',
                          hintText: 'e.g. LT Residential 1-Phase (230V)',
                          isDense: true,
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (_) => setState(() => _renderKey++),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // ── SECTION 2: CUSTOMER INFORMATION ───────────────────────────────
          _buildCard(
            title: '2. Customer Profile & Site Details',
            icon: Icons.person_outline_rounded,
            iconColor: const Color(0xFF047857),
            trailing: _isSavedCustomer
                ? Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: const Color(0xFFECFDF5), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFA7F3D0))),
                    child: const Text('Master Customer Linked', style: TextStyle(color: Color(0xFF047857), fontSize: 11, fontWeight: FontWeight.bold)),
                  )
                : Wrap(
                    spacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      TextButton.icon(
                        onPressed: _openSearchMasterCustomer,
                        icon: const Icon(Icons.person_search_rounded, size: 15, color: Color(0xFF1D4ED8)),
                        label: const Text('Pick from Master', style: TextStyle(fontSize: 12, color: Color(0xFF1D4ED8), fontWeight: FontWeight.bold)),
                      ),
                      TextButton.icon(
                        onPressed: _handleSaveCustomerToMaster,
                        icon: const Icon(Icons.person_add_alt_1, size: 15, color: Color(0xFF047857)),
                        label: const Text('Save to Master', style: TextStyle(fontSize: 12, color: Color(0xFF047857), fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      flex: 6,
                      child: TextField(
                        controller: _customerNameCtrl,
                        decoration: InputDecoration(
                          labelText: '${t.customerName} *',
                          isDense: true,
                          border: const OutlineInputBorder(),
                        ),
                        onChanged: (_) => setState(() => _renderKey++),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 5,
                      child: TextField(
                        controller: _mobileNoCtrl,
                        keyboardType: TextInputType.phone,
                        decoration: InputDecoration(
                          labelText: '${t.mobileNo} *',
                          isDense: true,
                          border: const OutlineInputBorder(),
                        ),
                        onChanged: (_) => setState(() => _renderKey++),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      flex: 6,
                      child: TextField(
                        controller: _consumerNoCtrl,
                        decoration: InputDecoration(
                          labelText: '${t.consumerNo} (MSEDCL)',
                          hintText: 'e.g. 096590001608',
                          isDense: true,
                          border: const OutlineInputBorder(),
                        ),
                        onChanged: (_) => setState(() => _renderKey++),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 5,
                      child: TextField(
                        controller: _emailCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Email Address (Optional)',
                          isDense: true,
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (_) => setState(() => _renderKey++),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      flex: 6,
                      child: TextField(
                        controller: _addressCtrl,
                        decoration: InputDecoration(
                          labelText: t.address,
                          isDense: true,
                          border: const OutlineInputBorder(),
                        ),
                        onChanged: (_) => setState(() => _renderKey++),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 3,
                      child: TextField(
                        controller: _villageCityCtrl,
                        decoration: InputDecoration(
                          labelText: t.villageCity,
                          isDense: true,
                          border: const OutlineInputBorder(),
                        ),
                        onChanged: (_) => setState(() => _renderKey++),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 3,
                      child: TextField(
                        controller: _districtCtrl,
                        decoration: InputDecoration(
                          labelText: t.district,
                          isDense: true,
                          border: const OutlineInputBorder(),
                        ),
                        onChanged: (_) => setState(() => _renderKey++),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // ── SECTION 3: SOLAR SYSTEM CONFIGURATION ─────────────────────────
          _buildCard(
            title: '3. Solar System Technical Specifications',
            icon: Icons.bolt_rounded,
            iconColor: const Color(0xFFF59E0B),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      flex: 4,
                      child: DropdownButtonFormField<String>(
                        value: ['1 kW', '2 kW', '3 kW', '3.5 kW', '4 kW', '5 kW', '6 kW', '8 kW', '10 kW'].contains(_capacity) ? _capacity : '3 kW',
                        decoration: InputDecoration(
                          labelText: '${t.systemCapacity} *',
                          isDense: true,
                          border: const OutlineInputBorder(),
                        ),
                        items: ['1 kW', '2 kW', '3 kW', '3.5 kW', '4 kW', '5 kW', '6 kW', '8 kW', '10 kW']
                            .map((cap) => DropdownMenuItem(value: cap, child: Text(cap, style: const TextStyle(fontWeight: FontWeight.bold))))
                            .toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() {
                              _capacity = val;
                              _items = SolarQuotation.defaultItems(_capacity);
                              _recalculateAll(recalculateSubsidyFromFormula: true, recalculateGenFromFormula: true);
                            });
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 4,
                      child: DropdownButtonFormField<String>(
                        value: _systemType,
                        decoration: InputDecoration(
                          labelText: '${t.systemType} *',
                          isDense: true,
                          border: const OutlineInputBorder(),
                        ),
                        items: ['On-Grid Solar System', 'Off-Grid Solar System', 'Hybrid Solar System']
                            .map((st) => DropdownMenuItem(value: st, child: Text(st)))
                            .toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() {
                              _systemType = val;
                              _includeDiagram = val.toLowerCase().contains('on-grid');
                              _recalculateAll();
                            });
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 4,
                      child: TextField(
                        controller: _packageNameCtrl,
                        decoration: InputDecoration(
                          labelText: t.solarPackage,
                          isDense: true,
                          border: const OutlineInputBorder(),
                        ),
                        onChanged: (_) => setState(() => _renderKey++),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      flex: 4,
                      child: TextField(
                        controller: _panelBrandCtrl,
                        decoration: InputDecoration(
                          labelText: t.panelBrand,
                          isDense: true,
                          border: const OutlineInputBorder(),
                        ),
                        onChanged: (_) => setState(() => _renderKey++),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 4,
                      child: TextField(
                        controller: _panelWattageCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Panel Wattage (Wp)',
                          isDense: true,
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (_) => _recalculateAll(),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 4,
                      child: TextField(
                        controller: _panelCountCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Number of Panels',
                          isDense: true,
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (_) => setState(() => _renderKey++),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      flex: 6,
                      child: TextField(
                        controller: _inverterBrandCtrl,
                        decoration: InputDecoration(
                          labelText: t.inverterBrand,
                          isDense: true,
                          border: const OutlineInputBorder(),
                        ),
                        onChanged: (_) => setState(() => _renderKey++),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 6,
                      child: TextField(
                        controller: _inverterCapacityCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Inverter Rating / Capacity',
                          isDense: true,
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (_) => setState(() => _renderKey++),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _mountingStructureCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Mounting Structure Specifications',
                    hintText: 'e.g. Hot Dip GI Elevated Rooftop Structure',
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (_) => setState(() => _renderKey++),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // ── SECTION 4: ITEM-WISE PRICING & BOQ ────────────────────────────
          _buildCard(
            title: '4. Bill of Materials (BOQ) & Scope of Supply',
            icon: Icons.format_list_numbered_rounded,
            iconColor: const Color(0xFF7C3AED),
            trailing: Wrap(
              spacing: 6,
              children: [
                TextButton.icon(
                  onPressed: _resetToDefaultBoq,
                  icon: const Icon(Icons.restart_alt_rounded, size: 16, color: Color(0xFF64748B)),
                  label: const Text('Reset Standard BOQ', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                ),
                TextButton.icon(
                  onPressed: _openAddCustomItemDialog,
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Add Item', style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
            child: Column(
              children: [
                ..._items.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final item = entry.value;
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    margin: const EdgeInsets.only(bottom: 6),
                    decoration: BoxDecoration(
                      color: idx % 2 == 1 ? const Color(0xFFF8FAFC) : Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 28,
                          child: Text('${idx + 1}.', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                        ),
                        Expanded(
                          flex: 3,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(item['item'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                              Text(item['spec'] ?? '', style: const TextStyle(color: Color(0xFF64748B), fontSize: 11)),
                            ],
                          ),
                        ),
                        SizedBox(
                          width: 90,
                          child: Text(item['qty'] ?? '', textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                        ),
                        IconButton(
                          icon: const Icon(Icons.edit_outlined, size: 18, color: Color(0xFF0284C7)),
                          tooltip: 'Edit Component',
                          onPressed: () => _openEditItemDialog(idx),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                          tooltip: 'Remove',
                          onPressed: () {
                            setState(() {
                              _items.removeAt(idx);
                              _renderKey++;
                            });
                          },
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // ── SECTION 5: PRICING & STATUTORY 70:30 GST ──────────────────────
          _buildCard(
            title: '5. Commercial Proposal Pricing & Statutory 70:30 GST',
            icon: Icons.currency_rupee_rounded,
            iconColor: const Color(0xFF0D2B6F),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      flex: 6,
                      child: TextField(
                        controller: _grandTotalCtrl,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: '${t.grandTotal} *',
                          helperText: 'Entered amount is Total GST Inclusive',
                          prefixIcon: const Icon(Icons.currency_rupee_rounded),
                          border: const OutlineInputBorder(),
                        ),
                        onChanged: (_) => setState(() => _recalculateAll()),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 6,
                      child: TextField(
                        controller: _discountCtrl,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: t.discount,
                          prefixIcon: const Icon(Icons.discount_outlined),
                          border: const OutlineInputBorder(),
                        ),
                        onChanged: (_) => setState(() => _recalculateAll()),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                // Statutory 70:30 Split Card
                _buildGstSummaryCard(_grandTotal),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEFCE8),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFFEF08A)),
                  ),
                  child: Text(
                    '${t.amountInWords}: ${NumberToWordsUtils.convertToBilingualRupees(_grandTotal, language: _language)}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5, color: Color(0xFF854D0E)),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // ── SECTION 6: ON-GRID SCHEMATIC PREVIEW & TOGGLE ─────────────────
          if (_systemType.toLowerCase().contains('on-grid')) ...[
            _buildCard(
              title: '6. On-Grid Solar System Working Schematic',
              icon: Icons.schema_rounded,
              iconColor: const Color(0xFF0284C7),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Checkbox(
                    value: _includeDiagram,
                    onChanged: (val) => setState(() => _includeDiagram = val ?? true),
                  ),
                  const Text('Include in PDF', style: TextStyle(fontSize: 12)),
                ],
              ),
              child: _buildOnGridVisualSchematic(t),
            ),
            const SizedBox(height: 12),
          ],

          // ── SECTION 7: 12-MONTH GENERATION & INTERACTIVE CHART ────────────
          _buildCard(
            title: '7. 12-Month Generation Schedule (Jan–Dec)',
            icon: Icons.calendar_month_rounded,
            iconColor: const Color(0xFF047857),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Checkbox(
                  value: _includeGenerationTable,
                  onChanged: (val) => setState(() => _includeGenerationTable = val ?? true),
                ),
                const Text('Include in PDF', style: TextStyle(fontSize: 12)),
              ],
            ),
            child: _buildGenerationUiSection(t),
          ),

          const SizedBox(height: 12),

          // ── SECTION 8: SOLAR SAVINGS, ROI & PAYBACK ANALYSIS ──────────────
          _buildCard(
            title: '8. Financial ROI, Bill Savings & Payback Analysis',
            icon: Icons.trending_up_rounded,
            iconColor: const Color(0xFF10B981),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Checkbox(
                  value: _includeRoi,
                  onChanged: (val) => setState(() => _includeRoi = val ?? true),
                ),
                const Text('Include in PDF', style: TextStyle(fontSize: 12)),
              ],
            ),
            child: _buildRoiUiSection(t),
          ),

          const SizedBox(height: 12),

          // ── SECTION 9: PM SURYA GHAR SUBSIDY CALCULATOR ───────────────────
          _buildCard(
            title: '9. PM Surya Ghar Central Government Subsidy',
            icon: Icons.account_balance_rounded,
            iconColor: const Color(0xFF047857),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_quotationType == 'Commercial') ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFCBD5E1)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.info_outline, color: Color(0xFF475569)),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Commercial Connection: PM Surya Ghar Residential Central Subsidy is not applicable to commercial/industrial electricity meters.',
                            style: TextStyle(fontSize: 12, color: Color(0xFF334155)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else ...[
                  Row(
                    children: [
                      Expanded(
                        flex: 6,
                        child: TextField(
                          controller: _subsidyAmountCtrl,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: 'Central Government Subsidy (₹) *',
                            helperText: 'Editable — Automatically updates Loan & Margin',
                            isDense: true,
                            border: const OutlineInputBorder(),
                            suffixIcon: IconButton(
                              icon: const Icon(Icons.auto_fix_high_rounded, color: Color(0xFF047857), size: 20),
                              tooltip: 'Recalculate Standard PM Surya Ghar Subsidy for $_capacity',
                              onPressed: () {
                                setState(() {
                                  _recalculateAll(recalculateSubsidyFromFormula: true);
                                });
                              },
                            ),
                          ),
                          onChanged: (_) {
                            setState(() {
                              _recalculateAll();
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 6,
                        child: _buildSummaryBox('Net Payable After Subsidy', _inrFormat.format(_payableAfterSubsidy), const Color(0xFF0D2B6F)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _buildSummaryBox('System Capacity', _capacity, const Color(0xFF1D4ED8)),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildSummaryBox('Eligible Subsidy', _inrFormat.format(_subsidyAmount), const Color(0xFF047857)),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildSummaryBox('Customer Contribution', _inrFormat.format(_downPayment), const Color(0xFFD97706)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    t.subsidyDisclaimer,
                    style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontStyle: FontStyle.italic),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 12),

          // ── SECTION 10: PAYMENT MODE & EMI SCHEDULE ───────────────────────
          _buildCard(
            title: '10. Payment Milestones & Bank Loan EMI Options',
            icon: Icons.payments_rounded,
            iconColor: const Color(0xFF0D2B6F),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'Cash', label: Text('Cash / Self-Funded')),
                    ButtonSegment(value: 'Bank Loan', label: Text('Bank Loan (Full)')),
                    ButtonSegment(value: 'Part Payment + Bank Loan', label: Text('Part Payment + Loan')),
                  ],
                  selected: {_paymentMode},
                  onSelectionChanged: (val) {
                    setState(() {
                      _paymentMode = val.first;
                      _recalculateAll();
                    });
                  },
                ),
                const SizedBox(height: 12),
                if (_paymentMode.toLowerCase().contains('loan')) ...[
                  Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                    decoration: BoxDecoration(
                      color: const Color(0xFFECFDF5),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFFA7F3D0)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline_rounded, size: 16, color: Color(0xFF047857)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Bank Loan is calculated on Net Amount After Subsidy: ${_inrFormat.format((_quotationType != 'Commercial' && _subsidyAmount > 0) ? _payableAfterSubsidy : _grandTotal)} (Turnkey ${_inrFormat.format(_grandTotal)} - Subsidy ${_inrFormat.format(_subsidyAmount)}). 10% Margin = ₹${(((_quotationType != 'Commercial' && _subsidyAmount > 0) ? _payableAfterSubsidy : _grandTotal) * 0.10).round()}.',
                            style: const TextStyle(fontSize: 11.5, color: Color(0xFF065F46), fontWeight: FontWeight.w600),
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
                          controller: _loanBankNameCtrl,
                          decoration: const InputDecoration(labelText: 'Financing Bank Name', isDense: true, border: OutlineInputBorder()),
                          onChanged: (_) => setState(() => _renderKey++),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 6,
                        child: TextField(
                          controller: _loanAmountCtrl,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: 'Proposed Loan Amount (₹) *',
                            helperText: 'Calculated on Net Cost after ₹${_subsidyAmount.round()} subsidy',
                            helperStyle: const TextStyle(fontSize: 10, color: Color(0xFF047857), fontWeight: FontWeight.bold),
                            isDense: true,
                            border: const OutlineInputBorder(),
                          ),
                          onChanged: (_) => setState(() => _recalculateAll()),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        flex: 4,
                        child: TextField(
                          controller: _downPaymentCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Down Payment (₹)',
                            helperText: '10% Margin on Net',
                            helperStyle: TextStyle(fontSize: 10, color: Color(0xFF64748B)),
                            isDense: true,
                            border: OutlineInputBorder(),
                          ),
                          onChanged: (_) => setState(() => _recalculateAll()),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 4,
                        child: TextField(
                          controller: _interestRateCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'Interest Rate (% p.a.)', isDense: true, border: OutlineInputBorder()),
                          onChanged: (_) => setState(() => _recalculateAll()),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 4,
                        child: DropdownButtonFormField<int>(
                          value: _loanTenureMonths,
                          decoration: const InputDecoration(labelText: 'Tenure (Months)', isDense: true, border: OutlineInputBorder()),
                          items: [12, 24, 36, 48, 60, 84, 120]
                              .map((m) => DropdownMenuItem(value: m, child: Text('$m Months (${(m / 12).toStringAsFixed(1)} Yrs)')))
                              .toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setState(() {
                                _loanTenureMonths = val;
                                _recalculateAll();
                              });
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFBFDBFE)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Monthly EMI: ${_inrFormat.format(_monthlyEmi)} / month', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF1D4ED8))),
                        Text('Total Repayment: ${_inrFormat.format(_monthlyEmi * _loanTenureMonths)}', style: const TextStyle(fontSize: 12, color: Color(0xFF1E293B))),
                        Text('Total Interest: ${_inrFormat.format((_monthlyEmi * _loanTenureMonths) - _bankLoan)}', style: const TextStyle(fontSize: 12, color: Color(0xFF047857))),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF1D4ED8),
                        side: const BorderSide(color: Color(0xFF1D4ED8)),
                        padding: const EdgeInsets.symmetric(vertical: 9),
                      ),
                      icon: const Icon(Icons.calculate_rounded, size: 18),
                      label: const Text('Download Bank Loan EMI Calculation Sheet (PDF)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                      onPressed: () {
                        final quotation = _buildQuotationObject();
                        SolarQuotationService.downloadBankLoanEmiSheetPdf(
                          context,
                          quotation,
                          includeStampAndSignature: _includeStampAndSignature,
                        );
                      },
                    ),
                  ),
                ] else ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Total Payable: ${_inrFormat.format(_grandTotal)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        const Text('Self-funded direct payment (no EMI)', style: TextStyle(color: Color(0xFF64748B), fontSize: 12)),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 12),

          // ── SECTION 11: COMPANY BANK ACCOUNT (FOR DISBURSEMENT) ───────────
          _buildCard(
            title: '11. Vendor Company Bank Details (For RTGS, NEFT & Loan Disbursement)',
            icon: Icons.account_balance_wallet_rounded,
            iconColor: const Color(0xFF0284C7),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      flex: 6,
                      child: TextField(
                        controller: _companyAccountNameCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Account Beneficiary Name',
                          isDense: true,
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (_) => setState(() => _renderKey++),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 6,
                      child: TextField(
                        controller: _companyBankNameCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Bank Name',
                          isDense: true,
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (_) => setState(() => _renderKey++),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      flex: 6,
                      child: TextField(
                        controller: _branchCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Branch Name',
                          isDense: true,
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (_) => setState(() => _renderKey++),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 6,
                      child: TextField(
                        controller: _accountNoCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Account Number',
                          isDense: true,
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (_) => setState(() => _renderKey++),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      flex: 6,
                      child: TextField(
                        controller: _ifscCodeCtrl,
                        decoration: const InputDecoration(
                          labelText: 'IFSC Code',
                          isDense: true,
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (_) => setState(() => _renderKey++),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 6,
                      child: TextField(
                        controller: _upiIdCtrl,
                        decoration: const InputDecoration(
                          labelText: 'UPI ID / VPA',
                          isDense: true,
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (_) => setState(() => _renderKey++),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // ── SECTION 12: TERMS, CONDITIONS & SITE NOTES ────────────────────
          _buildCard(
            title: '12. Commercial Terms, Warranties & Project Notes',
            icon: Icons.gavel_rounded,
            iconColor: const Color(0xFF7C3AED),
            child: Column(
              children: [
                TextField(
                  controller: _termsCtrl,
                  maxLines: 5,
                  decoration: const InputDecoration(
                    labelText: 'Commercial Terms & Conditions (One per line)',
                    helperText: 'Displayed in official quotation proposal and client acceptance page',
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (_) => setState(() => _renderKey++),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _notesCtrl,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Special Site Remarks / Project Notes (Optional)',
                    helperText: 'Printed on proposal overview and client remarks',
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (_) => setState(() => _renderKey++),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // ── SECTION 13: AUTHORIZATION & SIGNATURES ────────────────────────
          _buildCard(
            title: '13. Authorization, Official Seal & Customer Acceptance',
            icon: Icons.verified_user_rounded,
            iconColor: const Color(0xFF047857),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      flex: 6,
                      child: TextField(
                        controller: _signatoryNameCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Authorized Signatory Name',
                          isDense: true,
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (_) => setState(() => _renderKey++),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 6,
                      child: TextField(
                        controller: _signatoryDesignationCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Signatory Designation',
                          isDense: true,
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (_) => setState(() => _renderKey++),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: CheckboxListTile(
                        title: const Text('Company Stamp & Signature', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                        subtitle: const Text('Official Vendor Seal on Proposal', style: TextStyle(fontSize: 11)),
                        value: _includeStampAndSignature,
                        onChanged: (val) => setState(() => _includeStampAndSignature = val ?? true),
                      ),
                    ),
                    Expanded(
                      child: CheckboxListTile(
                        title: const Text('Customer Signature', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                        subtitle: const Text('Customer Acceptance Sign-off', style: TextStyle(fontSize: 11)),
                        value: _includeCustomerSignature,
                        onChanged: (val) => setState(() => _includeCustomerSignature = val ?? true),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // ===========================================================================
  // SECTION 12: LIVE A4 PDF PREVIEW PANE
  // ===========================================================================
  Widget _buildPdfPreviewPane() {
    final quotation = _buildQuotationObject();

    return Container(
      color: const Color(0xFF525659),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            color: const Color(0xFF323639),
            child: Row(
              children: [
                const Icon(Icons.picture_as_pdf_rounded, color: Colors.redAccent, size: 20),
                const SizedBox(width: 8),
                const Text('Live A4 Quotation PDF Preview', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.refresh_rounded, color: Colors.white),
                  tooltip: 'Refresh Preview',
                  onPressed: () => setState(() => _renderKey++),
                ),
                IconButton(
                  icon: const Icon(Icons.calculate_rounded, color: Colors.amberAccent),
                  tooltip: 'Download Bank Loan EMI Calculation Sheet',
                  onPressed: () => SolarQuotationService.downloadBankLoanEmiSheetPdf(
                    context,
                    quotation,
                    includeStampAndSignature: _includeStampAndSignature,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.download_rounded, color: Colors.white),
                  tooltip: 'Download PDF',
                  onPressed: () => SolarQuotationService.downloadQuotationPdf(
                    context,
                    quotation,
                    includeStampAndSignature: _includeStampAndSignature,
                    includeCustomerSignature: _includeCustomerSignature,
                    customCustomerSignatureBytes: _customCustomerSignatureBytes,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.print_rounded, color: Colors.white),
                  tooltip: 'Print A4',
                  onPressed: () => SolarQuotationService.printQuotationPdf(
                    quotation,
                    includeStampAndSignature: _includeStampAndSignature,
                    includeCustomerSignature: _includeCustomerSignature,
                    customCustomerSignatureBytes: _customCustomerSignatureBytes,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: PdfPreview(
              key: ValueKey('preview-$_renderKey-$_language-$_quotationType'),
              build: (format) => SolarQuotationService.generateQuotationPdfBytes(
                quotation,
                includeStampAndSignature: _includeStampAndSignature,
                includeCustomerSignature: _includeCustomerSignature,
                customCustomerSignatureBytes: _customCustomerSignatureBytes,
              ),
              canChangeOrientation: false,
              canChangePageFormat: false,
              canDebug: false,
              allowPrinting: true,
              allowSharing: true,
              previewPageMargin: const EdgeInsets.all(12),
            ),
          ),
        ],
      ),
    );
  }

  // ── ON-GRID VISUAL SCHEMATIC WIDGET (UI) ──────────────────────────────────
  Widget _buildOnGridVisualSchematic(SolarQuotationTranslations t) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFCBD5E1)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildUiSchematicNode('☀️ Rooftop Panels', 'Solar PV Modules', 'Waaree / Adani TopCon', const Color(0xFFE0F2FE), const Color(0xFF0284C7)),
              const Icon(Icons.arrow_forward_rounded, color: Color(0xFFEA580C)),
              _buildUiSchematicNode('⚡ DCDB Box', 'DC Protection', 'Surge Protection & Fuse', const Color(0xFFFEF3C7), const Color(0xFFD97706)),
              const Icon(Icons.arrow_forward_rounded, color: Color(0xFFEA580C)),
              _buildUiSchematicNode('🔄 Grid Inverter', 'Grid-Tied MPPT', 'High Efficiency IP65', const Color(0xFFD1FAE5), const Color(0xFF047857)),
              const Icon(Icons.arrow_forward_rounded, color: Color(0xFF047857)),
              _buildUiSchematicNode('⚡ ACDB Box', 'AC Protection', 'MCB & AC SPD', const Color(0xFFEDE9FE), const Color(0xFF7C3AED)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildUiSchematicNode('🏠 Building Load', 'Self-Consumption', 'Lights, Fan, AC, Machine', const Color(0xFFF1F5F9), const Color(0xFF475569)),
              const Icon(Icons.swap_horiz_rounded, color: Color(0xFF0D2B6F)),
              _buildUiSchematicNode('⇄ Net Meter', 'Bi-Directional Meter', 'Import / Export Billing', const Color(0xFFFEF08A), const Color(0xFFCA8A04)),
              const Icon(Icons.swap_horiz_rounded, color: Color(0xFF0D2B6F)),
              _buildUiSchematicNode('🏛️ MSEDCL Grid', 'Distribution Utility', 'Continuous Grid Sync', const Color(0xFFE0E7FF), const Color(0xFF0D2B6F)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildUiSchematicNode(String title, String sub, String detail, Color bg, Color border) {
    return Container(
      width: 120,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: border, width: 1.2),
      ),
      child: Column(
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11), textAlign: TextAlign.center),
          Text(sub, style: const TextStyle(fontSize: 10, color: Color(0xFF64748B)), textAlign: TextAlign.center),
          const SizedBox(height: 2),
          Text(detail, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w600), textAlign: TextAlign.center),
        ],
      ),
    );
  }

  // ── GENERATION UI SECTION (TABLE + INTERACTIVE BAR CHART) ─────────────────
  Widget _buildGenerationUiSection(SolarQuotationTranslations t) {
    final capKw = SolarQuotationCalculations.parseCapacity(_capacity);
    final rows = SolarQuotationCalculations.calculate12MonthGeneration(
      capacityKw: capKw,
      electricityTariff: _electricityTariff,
      targetAnnualUnits: _annualGenerationUnits > 0 ? _annualGenerationUnits : null,
    );

    double maxUnits = 1.0;
    for (final r in rows) {
      if (r.units > maxUnits) maxUnits = r.units;
    }

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              flex: 6,
              child: TextField(
                controller: _annualGenerationUnitsCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Annual Generation (kWh / Units) *',
                  helperText: 'Editable — Scaled proportionally across 12 months',
                  isDense: true,
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.auto_fix_high_rounded, color: Color(0xFF047857), size: 20),
                    tooltip: 'Recalculate from capacity formula (1460 units/kW)',
                    onPressed: () {
                      setState(() {
                        _recalculateAll(recalculateGenFromFormula: true);
                      });
                    },
                  ),
                ),
                onChanged: (_) {
                  setState(() {
                    _recalculateAll();
                  });
                },
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 6,
              child: _buildSummaryBox('Annual Electricity Savings', _inrFormat.format(_annualSavings), const Color(0xFF0D2B6F)),
            ),
          ],
        ),
        const SizedBox(height: 10),
        // Summary Cards
        Row(
          children: [
            Expanded(child: _buildSummaryBox('Annual Generation', '${_annualGenerationUnits.toStringAsFixed(0)} kWh', const Color(0xFF047857))),
            const SizedBox(width: 8),
            Expanded(child: _buildSummaryBox('Monthly Average', '${(_annualGenerationUnits / 12).toStringAsFixed(0)} Units', const Color(0xFF1D4ED8))),
            const SizedBox(width: 8),
            Expanded(child: _buildSummaryBox('Daily Average', '${(_annualGenerationUnits / 365).toStringAsFixed(1)} Units', const Color(0xFFD97706))),
          ],
        ),
        const SizedBox(height: 14),

        // Interactive Bar Chart
        Container(
          height: 130,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: rows.map((r) {
              final pct = r.units / maxUnits;
              final height = (pct * 80).clamp(12.0, 80.0);
              return Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(r.units.toStringAsFixed(0), style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 3),
                  Container(
                    width: 22,
                    height: height,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF10B981), Color(0xFF047857)],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(r.monthEn.substring(0, 3), style: const TextStyle(fontSize: 10, color: Color(0xFF64748B))),
                ],
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  // ── ROI UI SECTION ────────────────────────────────────────────────────────
  Widget _buildRoiUiSection(SolarQuotationTranslations t) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              flex: 4,
              child: TextField(
                controller: _tariffCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Tariff Rate (₹/kWh)', isDense: true, border: OutlineInputBorder()),
                onChanged: (_) => setState(() => _recalculateAll()),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 4,
              child: TextField(
                controller: _maintenanceCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Annual Maintenance (₹)', isDense: true, border: OutlineInputBorder()),
                onChanged: (_) => setState(() => _recalculateAll()),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 4,
              child: _buildSummaryBox('Payback Period', '$_paybackYears Yrs', const Color(0xFFD97706)),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          t.roiDisclaimer,
          style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontStyle: FontStyle.italic),
        ),
      ],
    );
  }

  // ── GST SUMMARY CARD ──────────────────────────────────────────────────────
  Widget _buildGstSummaryCard(double grandTotal) {
    final gst = SolarQuotationGstBreakdown.calculate(grandTotal);
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFCBD5E1)),
      ),
      child: Column(
        children: [
          _gstRow('Total Amount (GST Inclusive)', _inrFormat.format(gst.totalAmount), isBold: true),
          const Divider(height: 8),
          _gstRow('70% Goods Portion @ 5% GST', _inrFormat.format(gst.portion70)),
          _gstRow('GST Included @ 5%', _inrFormat.format(gst.gst5)),
          _gstRow('30% Services Portion @ 18% GST', _inrFormat.format(gst.portion30)),
          _gstRow('GST Included @ 18%', _inrFormat.format(gst.gst18)),
          const Divider(height: 8),
          _gstRow('Total Taxable Value', _inrFormat.format(gst.totalTaxableValue), isBold: true, color: const Color(0xFF0D2B6F)),
          _gstRow('Total GST Included', _inrFormat.format(gst.totalGstIncluded), isBold: true, color: const Color(0xFF047857)),
        ],
      ),
    );
  }

  Widget _gstRow(String label, String value, {bool isBold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 11, fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
          Text(value, style: TextStyle(fontSize: 11.5, fontWeight: isBold ? FontWeight.bold : FontWeight.w600, color: color)),
        ],
      ),
    );
  }

  Widget _buildSummaryBox(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
          const SizedBox(height: 2),
          Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: color)),
        ],
      ),
    );
  }

  Widget _buildCard({
    required String title,
    required IconData icon,
    required Color iconColor,
    required Widget child,
    Widget? trailing,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(color: Color(0x06000000), blurRadius: 4, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
            child: Row(
              children: [
                Icon(icon, color: iconColor, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                ),
                if (trailing != null) trailing,
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(padding: const EdgeInsets.all(14), child: child),
        ],
      ),
    );
  }

  // ── RESET TO DEFAULT BOQ ──────────────────────────────────────────────────
  void _resetToDefaultBoq() {
    setState(() {
      _items = SolarQuotation.defaultItems(_capacity);
      _renderKey++;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('BOQ components reset to standard specification for $_capacity.'),
        backgroundColor: const Color(0xFF047857),
      ),
    );
  }

  // ── ADD / EDIT LINE ITEMS ──────────────────────────────────────────────────
  void _openAddCustomItemDialog() {
    final itemCtrl = TextEditingController();
    final specCtrl = TextEditingController();
    final qtyCtrl = TextEditingController(text: '1 Set');

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Component to Quotation'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: itemCtrl, decoration: const InputDecoration(labelText: 'Item / Component Name')),
            const SizedBox(height: 10),
            TextField(controller: specCtrl, decoration: const InputDecoration(labelText: 'Technical Specification')),
            const SizedBox(height: 10),
            TextField(controller: qtyCtrl, decoration: const InputDecoration(labelText: 'Quantity')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              if (itemCtrl.text.trim().isNotEmpty) {
                setState(() {
                  _items.add({
                    'sr': '${_items.length + 1}',
                    'item': itemCtrl.text.trim(),
                    'spec': specCtrl.text.trim(),
                    'qty': qtyCtrl.text.trim(),
                  });
                  _renderKey++;
                });
                Navigator.pop(ctx);
              }
            },
            child: const Text('Add Item'),
          ),
        ],
      ),
    );
  }

  void _openEditItemDialog(int index) {
    final cur = _items[index];
    final itemCtrl = TextEditingController(text: cur['item']);
    final specCtrl = TextEditingController(text: cur['spec']);
    final qtyCtrl = TextEditingController(text: cur['qty']);

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Edit Component #${index + 1}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: itemCtrl, decoration: const InputDecoration(labelText: 'Item / Component Name')),
            const SizedBox(height: 10),
            TextField(controller: specCtrl, decoration: const InputDecoration(labelText: 'Technical Specification')),
            const SizedBox(height: 10),
            TextField(controller: qtyCtrl, decoration: const InputDecoration(labelText: 'Quantity')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              setState(() {
                _items[index] = {
                  'sr': cur['sr'] ?? '${index + 1}',
                  'item': itemCtrl.text.trim(),
                  'spec': specCtrl.text.trim(),
                  'qty': qtyCtrl.text.trim(),
                };
                _renderKey++;
              });
              Navigator.pop(ctx);
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  // ── TAB 1: MARGIN MONEY RECEIPT TAB (FULLY EDITABLE) ──────────────────────
  Widget _buildMarginReceiptTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Center(
        child: Container(
          width: 750,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: const [BoxShadow(color: Color(0x0A000000), blurRadius: 8, offset: Offset(0, 4))],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: const Color(0xFFECFDF5), borderRadius: BorderRadius.circular(10)),
                    child: const Icon(Icons.receipt_long_rounded, color: Color(0xFF047857), size: 28),
                  ),
                  const SizedBox(width: 12),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Customer Margin Money Receipt (10%)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0D2B6F))),
                      Text('Official PM Surya Ghar Bank Loan Margin Receipt Generator', style: TextStyle(fontSize: 11, color: Colors.grey)),
                    ],
                  ),
                ],
              ),
              const Divider(height: 24),
              Row(
                children: [
                  Expanded(
                    flex: 6,
                    child: TextField(
                      controller: _receiptNoCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Receipt No. *',
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 6,
                    child: InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _receiptDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2035),
                        );
                        if (picked != null) {
                          setState(() => _receiptDate = picked);
                        }
                      },
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Receipt Date *',
                          isDense: true,
                          border: OutlineInputBorder(),
                          suffixIcon: Icon(Icons.calendar_today_rounded, size: 18),
                        ),
                        child: Text(_dateFormat.format(_receiptDate), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
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
                    Text('Received with thanks from: ${_customerNameCtrl.text.isNotEmpty ? _customerNameCtrl.text : "Valued Customer"}', style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text('Consumer No: ${_consumerNoCtrl.text} • Mobile: ${_mobileNoCtrl.text} • Address: ${_addressCtrl.text}', style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B))),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    flex: 6,
                    child: TextField(
                      controller: _receiptMarginAmountCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Customer Margin Amount Received (₹) *',
                        helperText: 'Default: 10% Down Payment from Quotation',
                        prefixIcon: Icon(Icons.currency_rupee_rounded),
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (val) {
                        setState(() {
                          _receiptMarginAmount = double.tryParse(val.trim()) ?? 0.0;
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 6,
                    child: DropdownButtonFormField<String>(
                      value: _receiptPaymentMode,
                      decoration: const InputDecoration(
                        labelText: 'Payment Mode *',
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                      items: ['Cash', 'Cheque', 'Online / NEFT / RTGS', 'UPI', 'Demand Draft']
                          .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                          .toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setState(() => _receiptPaymentMode = val);
                        }
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEFCE8),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFFEF08A)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, size: 16, color: Color(0xFF854D0E)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Amount in Words: ${NumberToWordsUtils.convertToBilingualRupees(_receiptMarginAmount, language: _language)}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5, color: Color(0xFF854D0E)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    flex: 7,
                    child: TextField(
                      controller: _receiptTransactionRefCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Transaction Ref / Cheque No. / UTR',
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 5,
                    child: InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _receiptPaymentDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2035),
                        );
                        if (picked != null) {
                          setState(() => _receiptPaymentDate = picked);
                        }
                      },
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Payment Date',
                          isDense: true,
                          border: OutlineInputBorder(),
                          suffixIcon: Icon(Icons.calendar_today_rounded, size: 18),
                        ),
                        child: Text(_dateFormat.format(_receiptPaymentDate), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _receiptNotesCtrl,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Receipt Purpose & Notes',
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF047857),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    ),
                    onPressed: () async {
                      final effectiveMargin = double.tryParse(_receiptMarginAmountCtrl.text.trim()) ?? _receiptMarginAmount;
                      final effectiveReceiptNo = _receiptNoCtrl.text.trim().isNotEmpty ? _receiptNoCtrl.text.trim() : _receiptNo;
                      final effectiveNotes = _receiptNotesCtrl.text.trim();
                      final effectiveRef = _receiptTransactionRefCtrl.text.trim();

                      final receipt = CustomerMarginReceipt.create(
                        customerId: _customerId,
                        consumerNo: _consumerNoCtrl.text.trim(),
                        customerName: _customerNameCtrl.text.trim(),
                        address: _addressCtrl.text.trim(),
                        villageCity: _villageCityCtrl.text.trim(),
                        district: _districtCtrl.text.trim(),
                        mobileNo: _mobileNoCtrl.text.trim(),
                        receiptNo: effectiveReceiptNo,
                        receiptDate: _receiptDate,
                        quotationNo: _quotationNoCtrl.text.trim().isNotEmpty ? _quotationNoCtrl.text.trim() : _quotationNo,
                        quotationDate: _quotationDate,
                        systemCapacity: _capacity,
                        systemType: _systemType,
                        totalSystemCost: _grandTotal,
                        bankLoanAmount: _bankLoan,
                        marginAmount: effectiveMargin,
                        paymentMode: _receiptPaymentMode,
                        transactionRef: effectiveRef.isNotEmpty ? effectiveRef : 'Paid in Cash',
                        paymentDate: _receiptPaymentDate,
                        notes: effectiveNotes.isNotEmpty ? effectiveNotes : null,
                      );
                      await QuotationStorageService.saveMarginReceipt(receipt);
                      if (mounted) {
                        final pdfBytes = await MarginMoneyReceiptService.generateReceiptPdfBytes(receipt, includeStampAndSignature: true);
                        await Printing.layoutPdf(onLayout: (_) => pdfBytes, name: receipt.pdfFileName);
                      }
                    },
                    icon: const Icon(Icons.print_rounded, size: 18),
                    label: const Text('Save & Print Margin Receipt', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
