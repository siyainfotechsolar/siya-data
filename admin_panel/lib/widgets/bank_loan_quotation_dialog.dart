import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import 'package:siya_shared/utils/number_to_words_utils.dart';
import '../models/consumer_record.dart';
import '../models/solar_quotation.dart';
import '../models/customer_margin_receipt.dart';
import '../services/bank_loan_quotation_service.dart';
import '../services/margin_money_receipt_service.dart';
import '../services/quotation_storage_service.dart';

class BankLoanQuotationDialog extends StatefulWidget {
  final ConsumerRecord customer;
  final SolarQuotation? initialQuotation;
  final int initialTab;

  const BankLoanQuotationDialog({
    super.key,
    required this.customer,
    this.initialQuotation,
    this.initialTab = 0,
  });

  static Future<void> show(
    BuildContext context,
    ConsumerRecord customer, {
    SolarQuotation? initialQuotation,
    int initialTab = 0,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => BankLoanQuotationDialog(
        customer: customer,
        initialQuotation: initialQuotation,
        initialTab: initialTab,
      ),
    );
  }

  @override
  State<BankLoanQuotationDialog> createState() => _BankLoanQuotationDialogState();
}

class _BankLoanQuotationDialogState extends State<BankLoanQuotationDialog> {
  late String _customerName;
  late String _consumerNo;
  late String _mobileNo;
  late String _address;
  late String _villageCity;
  late String _district;
  late String _capacity;
  late String _systemType;
  late double _totalCost;
  late double _gstAmount;
  late double _grandTotal;
  late double _bankLoan;
  late double _contribution;
  late String _quotationNo;
  late DateTime _quotationDate;
  late String _bankName;
  late String _branch;
  late String _accountNo;
  late String _ifscCode;
  late String _upiId;

  // Margin Money Receipt State
  late int _selectedTab;
  late String _receiptNo;
  late DateTime _receiptDate;
  late String _paymentMode;
  late String _transactionRef;
  late DateTime _paymentDate;
  late double _marginAmount;
  late String _receiptNotes;

  List<SolarQuotation> _previousQuotations = [];
  bool _isLoadingHistory = true;
  int _renderKey = 0;
  final currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: 'Rs. ', decimalDigits: 0);

  @override
  void initState() {
    super.initState();
    _initFields();
    _loadHistory();
  }

  void _initFields([SolarQuotation? init]) {
    final cust = widget.customer;
    final q = init ?? widget.initialQuotation;

    _customerName = q?.customerName ?? cust.name.trim();
    _consumerNo = q?.consumerNo ?? cust.consumerNo.trim();
    _mobileNo = q?.mobileNo ?? cust.mobile?.trim() ?? '';

    final addr = q?.address ?? (cust.address?.trim() ?? cust.village?.trim() ?? '');
    _address = addr.isNotEmpty ? addr : 'Betawad';
    _villageCity = q?.villageCity ?? (cust.village?.trim().isNotEmpty == true
        ? cust.village!.trim()
        : (_address.split(',').firstOrNull?.trim() ?? 'Betawad'));
    _district = q?.district ?? (_address.toLowerCase().contains('dhule') ? 'Dhule' : 'Dhule');

    _quotationDate = q?.quotationDate ?? DateTime.now();
    final suffix = _consumerNo.length > 4 ? _consumerNo.substring(_consumerNo.length - 4) : _consumerNo;
    _quotationNo = q?.quotationNo ?? 'SIYA-Q-${_quotationDate.year}-$suffix';

    String cap = q?.systemCapacity ?? cust.systemCapacity?.trim() ?? '';
    if (cap.isEmpty && cust.remarks != null && cust.remarks!.trim().isNotEmpty) {
      final match = RegExp(r'(\d+(?:\.\d+)?\s*(?:kw|kW|KW|Kw))').firstMatch(cust.remarks!);
      if (match != null) cap = match.group(1)!;
    }
    _capacity = cap.isNotEmpty ? cap : '3 kW';
    _systemType = q?.systemType ?? 'On-Grid Solar System';

    if (q != null) {
      _totalCost = q.totalSystemCost;
      _gstAmount = q.gstAmount;
      _grandTotal = q.grandTotal;
      _bankLoan = q.bankLoanAmount;
      _contribution = q.customerContribution;
      _bankName = q.bankName;
      _branch = q.branch;
      _accountNo = q.accountNo;
      _ifscCode = q.ifscCode;
      _upiId = q.upiId;
    } else {
      _totalCost = cust.totalAmount > 0 ? cust.totalAmount : 0.0;
      _gstAmount = 0.0;
      _grandTotal = _totalCost + _gstAmount;
      _bankLoan = cust.loanSanctionedAmount > 0
          ? cust.loanSanctionedAmount
          : (_grandTotal > 0 ? (_grandTotal * 0.9).roundToDouble() : 0.0);
      _contribution = (_grandTotal - _bankLoan).clamp(0.0, double.infinity);
      _bankName = 'STATE BANK OF INDIA';
      _branch = 'Betawad';
      _accountNo = '40662252403';
      _ifscCode = 'SBIN0004798';
      _upiId = 'siyainfodigital@sbi';
    }

    _selectedTab = widget.initialTab;
    _receiptDate = _quotationDate;
    _receiptNo = 'SIYA-MMR-${_receiptDate.year}-$suffix';
    _paymentMode = 'Cash';
    _transactionRef = 'Paid in Cash';
    _paymentDate = _receiptDate;
    _marginAmount = _contribution;
    _receiptNotes = 'Received 10% Customer Margin Contribution in Cash towards PM Surya Ghar Bank Solar Loan installation.';
  }

  Future<void> _loadHistory() async {
    try {
      final list = await QuotationStorageService.getQuotationsForCustomer(_consumerNo);
      if (mounted) {
        setState(() {
          _previousQuotations = list;
          _isLoadingHistory = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingHistory = false);
    }
  }

  SolarQuotation _buildQuotation() {
    return SolarQuotation.create(
      customerId: widget.customer.id,
      consumerNo: _consumerNo,
      customerName: _customerName,
      address: _address,
      villageCity: _villageCity,
      district: _district,
      mobileNo: _mobileNo,
      quotationNo: _quotationNo,
      quotationDate: _quotationDate,
      systemCapacity: _capacity,
      systemType: _systemType,
      totalSystemCost: _totalCost,
      gstAmount: _gstAmount,
      grandTotal: _grandTotal,
      bankLoanAmount: _bankLoan,
      customerContribution: _contribution,
      bankName: _bankName,
      branch: _branch,
      accountNo: _accountNo,
      ifscCode: _ifscCode,
      upiId: _upiId,
    );
  }

  Future<void> _saveCurrentQuotation() async {
    final quotation = _buildQuotation();
    await QuotationStorageService.saveQuotation(quotation);
    _loadHistory();
  }

  CustomerMarginReceipt _buildMarginReceipt() {
    return CustomerMarginReceipt.create(
      customerId: widget.customer.id,
      consumerNo: _consumerNo,
      customerName: _customerName,
      address: _address,
      villageCity: _villageCity,
      district: _district,
      mobileNo: _mobileNo,
      receiptNo: _receiptNo,
      receiptDate: _receiptDate,
      quotationNo: _quotationNo,
      quotationDate: _quotationDate,
      systemCapacity: _capacity,
      systemType: _systemType,
      totalSystemCost: _grandTotal,
      bankLoanAmount: _bankLoan,
      marginAmount: _marginAmount > 0 ? _marginAmount : _contribution,
      paymentMode: _paymentMode,
      transactionRef: _transactionRef,
      paymentDate: _paymentDate,
      bankName: _bankName,
      branch: _branch,
      accountNo: _accountNo,
      ifscCode: _ifscCode,
      upiId: _upiId,
      notes: _receiptNotes,
    );
  }

  Future<void> _saveCurrentMarginReceipt() async {
    final receipt = _buildMarginReceipt();
    await QuotationStorageService.saveMarginReceipt(receipt);
  }

  Future<void> _openEditReceiptDialog() async {
    final receiptNoCtrl = TextEditingController(text: _receiptNo);
    final txnRefCtrl = TextEditingController(text: _transactionRef);
    final amountCtrl = TextEditingController(text: _marginAmount.toStringAsFixed(0));
    final notesCtrl = TextEditingController(text: _receiptNotes);
    String selectedMode = _paymentMode;
    DateTime selectedDate = _receiptDate;

    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDlgState) {
            final curAmt = double.tryParse(amountCtrl.text.trim()) ?? _marginAmount;
            final words = NumberToWordsUtils.convertToIndianRupees(curAmt);

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
                    child: const Icon(Icons.receipt_long_rounded, color: Color(0xFF047857), size: 22),
                  ),
                  const SizedBox(width: 10),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Edit Margin Money Receipt', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F2D69))),
                      Text('Payment Mode, Transaction Ref & Margin Amount', style: TextStyle(fontSize: 11, color: Colors.grey)),
                    ],
                  ),
                ],
              ),
              content: SizedBox(
                width: 480,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            flex: 6,
                            child: TextField(
                              controller: receiptNoCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Receipt No. *',
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
                                if (picked != null) {
                                  setDlgState(() => selectedDate = picked);
                                }
                              },
                              child: InputDecorator(
                                decoration: const InputDecoration(
                                  labelText: 'Receipt Date',
                                  isDense: true,
                                  border: OutlineInputBorder(),
                                  prefixIcon: Icon(Icons.calendar_today_rounded, size: 16),
                                ),
                                child: Text(DateFormat('dd-MM-yyyy').format(selectedDate), style: const TextStyle(fontSize: 13)),
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
                          labelText: 'Customer Margin Amount Received (Rs.) *',
                          helperText: 'Default: 10% of Total System Cost',
                          isDense: true,
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.currency_rupee_rounded, size: 18),
                        ),
                        onChanged: (_) => setDlgState(() {}),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEFCE8),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFFFEF08A)),
                        ),
                        child: Text(
                          'Words: $words',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF854D0E)),
                        ),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: selectedMode,
                        decoration: const InputDecoration(
                          labelText: 'Payment Mode *',
                          isDense: true,
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.payment_rounded, size: 18),
                        ),
                        items: ['Cash', 'Online / UPI', 'Cheque / DD', 'NEFT / RTGS', 'Bank Transfer']
                            .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                            .toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setDlgState(() {
                              selectedMode = val;
                              if (val == 'Cash' && txnRefCtrl.text.trim().isEmpty) {
                                txnRefCtrl.text = 'Paid in Cash';
                              }
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: txnRefCtrl,
                        decoration: InputDecoration(
                          labelText: selectedMode == 'Cash' ? 'Remarks / Receipt Memo' : 'Transaction Ref / UTR / Cheque No. *',
                          hintText: selectedMode == 'Cash' ? 'Paid in Cash' : 'e.g. UPI/6284910294 / Chq 40291',
                          isDense: true,
                          border: const OutlineInputBorder(),
                          prefixIcon: const Icon(Icons.receipt_long, size: 18),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: notesCtrl,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          labelText: 'Receipt Purpose / Remarks',
                          isDense: true,
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF047857),
                    foregroundColor: Colors.white,
                  ),
                  icon: const Icon(Icons.check_circle_outline, size: 16),
                  label: const Text('Save & Update Receipt'),
                  onPressed: () {
                    final newAmt = double.tryParse(amountCtrl.text.trim()) ?? _marginAmount;
                    setState(() {
                      _receiptNo = receiptNoCtrl.text.trim().isNotEmpty ? receiptNoCtrl.text.trim() : _receiptNo;
                      _paymentMode = selectedMode;
                      _transactionRef = txnRefCtrl.text.trim().isNotEmpty ? txnRefCtrl.text.trim() : _transactionRef;
                      _receiptDate = selectedDate;
                      _paymentDate = selectedDate;
                      _marginAmount = newAmt;
                      _receiptNotes = notesCtrl.text.trim();
                      _renderKey++;
                    });
                    Navigator.of(ctx).pop();
                    _saveCurrentMarginReceipt();
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  static String _autoSuggestCapacity(double grandTotal) {
    if (grandTotal >= 550000) return '10 kW';
    if (grandTotal >= 340000) return '6 kW';
    if (grandTotal >= 280000) return '5 kW';
    if (grandTotal >= 220000) return '4 kW';
    if (grandTotal >= 190000) return '3.5 kW';
    if (grandTotal >= 150000) return '3 kW';
    if (grandTotal >= 100000) return '2 kW';
    if (grandTotal >= 50000) return '1 kW';
    return '3 kW';
  }

  Future<void> _openEditAmountDialog() async {
    final capCtrl = TextEditingController(text: _capacity);
    final costCtrl = TextEditingController(text: _totalCost > 0 ? _totalCost.toStringAsFixed(0) : '');
    final gstCtrl = TextEditingController(text: _gstAmount > 0 ? _gstAmount.toStringAsFixed(0) : '0');
    final grandTotalCtrl = TextEditingController(text: _grandTotal > 0 ? _grandTotal.toStringAsFixed(0) : '');
    final loanCtrl = TextEditingController(text: _bankLoan > 0 ? _bankLoan.toStringAsFixed(0) : '');
    final contribCtrl = TextEditingController(text: _contribution > 0 ? _contribution.toStringAsFixed(0) : '');
    DateTime selectedDate = _quotationDate;
    bool isReverseCalcMode = false;

    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDlgState) {
            final c = double.tryParse(costCtrl.text.trim()) ?? 0.0;
            final g = double.tryParse(gstCtrl.text.trim()) ?? 0.0;
            final currentGrand = double.tryParse(grandTotalCtrl.text.trim()) ?? (c + g);
            final currentLoan = double.tryParse(loanCtrl.text.trim()) ?? (currentGrand * 0.9);
            final currentContrib = double.tryParse(contribCtrl.text.trim()) ?? (currentGrand - currentLoan).clamp(0.0, double.infinity);
            final isLoanExceeded = currentLoan > currentGrand;
            final isContribExceeded = currentContrib > currentGrand;
            final hasValidationError = isLoanExceeded || isContribExceeded || currentGrand <= 0;
            final loanPct = currentGrand > 0 ? (currentLoan / currentGrand * 100) : 90.0;
            final contribPct = currentGrand > 0 ? (currentContrib / currentGrand * 100) : 10.0;
            final words = NumberToWordsUtils.convertToIndianRupees(currentGrand);

            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.currency_rupee_rounded, color: Color(0xFFB45309), size: 22),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Edit Quotation Amount', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F2D69))),
                        Text('System Capacity, Total Cost & Loan Calculations', style: TextStyle(fontSize: 11, color: Colors.grey)),
                      ],
                    ),
                  ),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.restart_alt_rounded, size: 16, color: Color(0xFFD97706)),
                    label: const Text('Reset / Clear', style: TextStyle(fontSize: 12, color: Color(0xFFD97706), fontWeight: FontWeight.bold)),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      side: const BorderSide(color: Color(0xFFFCD34D)),
                      backgroundColor: const Color(0xFFFFFBEB),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () {
                      setDlgState(() {
                        capCtrl.clear();
                        costCtrl.clear();
                        gstCtrl.text = '0';
                        grandTotalCtrl.clear();
                        loanCtrl.clear();
                        contribCtrl.clear();
                        isReverseCalcMode = true;
                      });
                    },
                  ),
                ],
              ),
              content: SizedBox(
                width: 520,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Quick System Capacity & Cost Presets
                      const Text('Quick Select System Capacity & Cost:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF0F2D69))),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          {'cap': '3 kW', 'cost': 180000},
                          {'cap': '3.5 kW', 'cost': 200000},
                          {'cap': '4 kW', 'cost': 240000},
                          {'cap': '5 kW', 'cost': 300000},
                          {'cap': '6 kW', 'cost': 360000},
                          {'cap': '10 kW', 'cost': 600000},
                        ].map((preset) {
                          final pCap = preset['cap'] as String;
                          final pCost = preset['cost'] as int;
                          final isSelected = capCtrl.text.trim() == pCap;

                          return ChoiceChip(
                            label: Text('$pCap — ${currencyFormat.format(pCost)}', style: TextStyle(fontSize: 11, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                            selected: isSelected,
                            selectedColor: const Color(0xFFFEF3C7),
                            onSelected: (_) {
                              setDlgState(() {
                                isReverseCalcMode = false;
                                capCtrl.text = pCap;
                                costCtrl.text = pCost.toString();
                                gstCtrl.text = '0';
                                grandTotalCtrl.text = pCost.toString();
                                final pLoan = (pCost * 0.9).roundToDouble();
                                final pContrib = (pCost - pLoan).roundToDouble();
                                loanCtrl.text = pLoan.toStringAsFixed(0);
                                contribCtrl.text = pContrib.toStringAsFixed(0);
                              });
                            },
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 16),

                      // Manual System Capacity & Quotation Date Row
                      Row(
                        children: [
                          Expanded(
                            flex: 6,
                            child: TextField(
                              controller: capCtrl,
                              decoration: const InputDecoration(
                                labelText: 'System Capacity (e.g. 3 kW, 5 kW) *',
                                isDense: true,
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.bolt_rounded, size: 20, color: Color(0xFFF59E0B)),
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
                                if (picked != null) {
                                  setDlgState(() => selectedDate = picked);
                                }
                              },
                              child: InputDecorator(
                                decoration: const InputDecoration(
                                  labelText: 'Quotation Date *',
                                  isDense: true,
                                  border: OutlineInputBorder(),
                                  prefixIcon: Icon(Icons.calendar_today_rounded, size: 16, color: Color(0xFF0F2D69)),
                                ),
                                child: Text(
                                  DateFormat('dd-MM-yyyy').format(selectedDate),
                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Total Cost & GST Row
                      Row(
                        children: [
                          Expanded(
                            flex: 6,
                            child: TextField(
                              controller: costCtrl,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Total System Cost (Rs.) *',
                                isDense: true,
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.currency_rupee, size: 18),
                              ),
                              onChanged: (val) => setDlgState(() {
                                isReverseCalcMode = false;
                                final cost = double.tryParse(val.trim()) ?? 0.0;
                                final gst = double.tryParse(gstCtrl.text.trim()) ?? 0.0;
                                final tot = cost + gst;
                                grandTotalCtrl.text = tot.toStringAsFixed(0);
                                final loan = (tot * 0.9).roundToDouble();
                                final contrib = (tot - loan).clamp(0.0, double.infinity);
                                loanCtrl.text = loan.toStringAsFixed(0);
                                contribCtrl.text = contrib.toStringAsFixed(0);
                              }),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            flex: 4,
                            child: TextField(
                              controller: gstCtrl,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'GST (Rs.)',
                                isDense: true,
                                border: OutlineInputBorder(),
                                hintText: '0 (Exempt)',
                              ),
                              onChanged: (val) => setDlgState(() {
                                final cost = double.tryParse(costCtrl.text.trim()) ?? 0.0;
                                final gst = double.tryParse(val.trim()) ?? 0.0;
                                final tot = cost + gst;
                                grandTotalCtrl.text = tot.toStringAsFixed(0);
                                final loan = (tot * 0.9).roundToDouble();
                                final contrib = (tot - loan).clamp(0.0, double.infinity);
                                loanCtrl.text = loan.toStringAsFixed(0);
                                contribCtrl.text = contrib.toStringAsFixed(0);
                              }),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Grand Total Field
                      TextField(
                        controller: grandTotalCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Grand Total (Rs.) *',
                          isDense: true,
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.account_balance_wallet_outlined, size: 18),
                        ),
                        onChanged: (val) => setDlgState(() {
                          isReverseCalcMode = false;
                          final gt = double.tryParse(val.trim()) ?? 0.0;
                          final gst = double.tryParse(gstCtrl.text.trim()) ?? 0.0;
                          costCtrl.text = (gt - gst).clamp(0.0, double.infinity).toStringAsFixed(0);
                          final loan = (gt * 0.9).roundToDouble();
                          final contrib = (gt - loan).clamp(0.0, double.infinity);
                          loanCtrl.text = loan.toStringAsFixed(0);
                          contribCtrl.text = contrib.toStringAsFixed(0);
                        }),
                      ),
                      const SizedBox(height: 12),

                      // Bank Loan Amount & Customer Contribution (Two-Way Auto Calculation)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: TextField(
                              controller: loanCtrl,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                labelText: 'Bank Loan (${loanPct.toStringAsFixed(0)}%) *',
                                helperText: isLoanExceeded ? null : 'Auto-calculates customer contribution',
                                errorText: isLoanExceeded ? 'Exceeds Grand Total' : null,
                                isDense: true,
                                border: const OutlineInputBorder(),
                                prefixIcon: Icon(
                                  Icons.account_balance,
                                  size: 18,
                                  color: isLoanExceeded ? Colors.red : const Color(0xFF0F2D69),
                                ),
                              ),
                              onChanged: (val) => setDlgState(() {
                                final loan = double.tryParse(val.trim()) ?? 0.0;
                                final gt = double.tryParse(grandTotalCtrl.text.trim()) ?? 0.0;
                                final gst = double.tryParse(gstCtrl.text.trim()) ?? 0.0;

                                if (loan <= 0) {
                                  if (isReverseCalcMode || gt == 0) {
                                    grandTotalCtrl.clear();
                                    costCtrl.clear();
                                    contribCtrl.clear();
                                    capCtrl.clear();
                                  } else {
                                    contribCtrl.text = gt.toStringAsFixed(0);
                                  }
                                  return;
                                }

                                // Reverse calculate if in reverse mode, or if grand total is empty/zero, or if entered loan exceeds current grand total
                                if (isReverseCalcMode || gt == 0 || loan > gt) {
                                  final autoGrand = (loan / 0.9).roundToDouble();
                                  final autoContrib = (autoGrand - loan).clamp(0.0, double.infinity);
                                  final autoCost = (autoGrand - gst).clamp(0.0, double.infinity);

                                  grandTotalCtrl.text = autoGrand > 0 ? autoGrand.toStringAsFixed(0) : '';
                                  costCtrl.text = autoCost > 0 ? autoCost.toStringAsFixed(0) : '';
                                  contribCtrl.text = autoContrib > 0 ? autoContrib.toStringAsFixed(0) : '';
                                  capCtrl.text = _autoSuggestCapacity(autoGrand);
                                } else {
                                  final contrib = (gt - loan).clamp(0.0, double.infinity);
                                  contribCtrl.text = contrib.toStringAsFixed(0);
                                }
                              }),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextField(
                              controller: contribCtrl,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                labelText: 'Customer Contri (${contribPct.toStringAsFixed(0)}%) *',
                                helperText: isContribExceeded ? null : 'Auto: Grand Total - Loan',
                                errorText: isContribExceeded ? 'Exceeds Grand Total' : null,
                                isDense: true,
                                border: const OutlineInputBorder(),
                                prefixIcon: Icon(
                                  Icons.person_outline,
                                  size: 18,
                                  color: isContribExceeded ? Colors.red : const Color(0xFF047857),
                                ),
                              ),
                              onChanged: (val) => setDlgState(() {
                                final contrib = double.tryParse(val.trim()) ?? 0.0;
                                final gt = double.tryParse(grandTotalCtrl.text.trim()) ?? 0.0;
                                final gst = double.tryParse(gstCtrl.text.trim()) ?? 0.0;

                                if (contrib <= 0) {
                                  if (isReverseCalcMode || gt == 0) {
                                    grandTotalCtrl.clear();
                                    costCtrl.clear();
                                    loanCtrl.clear();
                                    capCtrl.clear();
                                  } else {
                                    loanCtrl.text = gt.toStringAsFixed(0);
                                  }
                                  return;
                                }

                                if (isReverseCalcMode || gt == 0 || contrib > gt) {
                                  final autoGrand = (contrib / 0.1).roundToDouble();
                                  final autoLoan = (autoGrand - contrib).clamp(0.0, double.infinity);
                                  final autoCost = (autoGrand - gst).clamp(0.0, double.infinity);

                                  grandTotalCtrl.text = autoGrand > 0 ? autoGrand.toStringAsFixed(0) : '';
                                  costCtrl.text = autoCost > 0 ? autoCost.toStringAsFixed(0) : '';
                                  loanCtrl.text = autoLoan > 0 ? autoLoan.toStringAsFixed(0) : '';
                                  capCtrl.text = _autoSuggestCapacity(autoGrand);
                                } else {
                                  final loan = (gt - contrib).clamp(0.0, double.infinity);
                                  loanCtrl.text = loan.toStringAsFixed(0);
                                }
                              }),
                            ),
                          ),
                        ],
                      ),

                      // Validation Warning & Auto-Fix Actions Card
                      if (isLoanExceeded) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF2F2),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFFECACA)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.error_outline, color: Color(0xFFDC2626), size: 18),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Bank Loan (${currencyFormat.format(currentLoan)}) cannot exceed Grand Total (${currencyFormat.format(currentGrand)})!',
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5, color: Color(0xFFB91C1C)),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Wrap(
                                spacing: 8,
                                runSpacing: 4,
                                children: [
                                  ActionChip(
                                    avatar: const Icon(Icons.auto_fix_high, size: 14, color: Color(0xFF1D4ED8)),
                                    label: Text('Auto-calc 90% Loan (Total: ${currencyFormat.format((currentLoan / 0.9).roundToDouble())})', style: const TextStyle(fontSize: 11, color: Color(0xFF1D4ED8))),
                                    backgroundColor: const Color(0xFFEFF6FF),
                                    onPressed: () {
                                      setDlgState(() {
                                        final autoGrand = (currentLoan / 0.9).roundToDouble();
                                        final gst = double.tryParse(gstCtrl.text.trim()) ?? 0.0;
                                        grandTotalCtrl.text = autoGrand.toStringAsFixed(0);
                                        costCtrl.text = (autoGrand - gst).clamp(0.0, double.infinity).toStringAsFixed(0);
                                        contribCtrl.text = (autoGrand - currentLoan).clamp(0.0, double.infinity).toStringAsFixed(0);
                                        capCtrl.text = _autoSuggestCapacity(autoGrand);
                                      });
                                    },
                                  ),
                                  ActionChip(
                                    avatar: const Icon(Icons.refresh, size: 14, color: Color(0xFF047857)),
                                    label: Text('Cap Loan to 90% (${currencyFormat.format(currentGrand * 0.9)})', style: const TextStyle(fontSize: 11, color: Color(0xFF047857))),
                                    backgroundColor: const Color(0xFFECFDF5),
                                    onPressed: () {
                                      setDlgState(() {
                                        final cappedLoan = (currentGrand * 0.9).roundToDouble();
                                        loanCtrl.text = cappedLoan.toStringAsFixed(0);
                                        contribCtrl.text = (currentGrand - cappedLoan).toStringAsFixed(0);
                                      });
                                    },
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 14),

                      // Live Calculation Breakdown Card
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFBFDBFE)),
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.account_balance, size: 16, color: Color(0xFF0F2D69)),
                                    const SizedBox(width: 6),
                                    Text('Bank Loan (${loanPct.toStringAsFixed(1)}%):', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF0F2D69))),
                                  ],
                                ),
                                Text(
                                  currencyFormat.format(currentLoan),
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: isLoanExceeded ? Colors.red : const Color(0xFF0F2D69),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.person_outline, size: 16, color: Color(0xFF047857)),
                                    const SizedBox(width: 6),
                                    Text('Customer Contribution (${contribPct.toStringAsFixed(1)}%):', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF047857))),
                                  ],
                                ),
                                Text(
                                  currencyFormat.format(currentContrib),
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF047857)),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Grand Total in Words Preview
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFECFDF5),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFA7F3D0)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Grand Total for Bank:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF065F46))),
                                Text(currencyFormat.format(currentGrand), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF047857))),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text('Words: $words', style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Color(0xFF065F46))),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                OutlinedButton.icon(
                  icon: const Icon(Icons.restart_alt_rounded, size: 16, color: Color(0xFFD97706)),
                  label: const Text('Reset / Clear', style: TextStyle(color: Color(0xFFD97706), fontWeight: FontWeight.bold)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFFFCD34D)),
                    backgroundColor: const Color(0xFFFFFBEB),
                  ),
                  onPressed: () {
                    setDlgState(() {
                      capCtrl.clear();
                      costCtrl.clear();
                      gstCtrl.text = '0';
                      grandTotalCtrl.clear();
                      loanCtrl.clear();
                      contribCtrl.clear();
                      isReverseCalcMode = true;
                    });
                  },
                ),
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: hasValidationError ? Colors.grey.shade400 : const Color(0xFF0D2B6F),
                    foregroundColor: Colors.white,
                  ),
                  icon: const Icon(Icons.check_circle_outline, size: 16),
                  label: const Text('Save & Update Quotation'),
                  onPressed: hasValidationError
                      ? null
                      : () {
                    final c = double.tryParse(costCtrl.text.trim()) ?? _totalCost;
                    final g = double.tryParse(gstCtrl.text.trim()) ?? 0.0;
                    final tot = double.tryParse(grandTotalCtrl.text.trim()) ?? (c + g);
                    final l = double.tryParse(loanCtrl.text.trim()) ?? (tot * 0.9);
                    final contrib = double.tryParse(contribCtrl.text.trim()) ?? (tot - l).clamp(0.0, double.infinity);

                    setState(() {
                      _capacity = capCtrl.text.trim().isNotEmpty ? capCtrl.text.trim() : _capacity;
                      _totalCost = c;
                      _gstAmount = g;
                      _grandTotal = tot;
                      _bankLoan = l;
                      _contribution = contrib;
                      _marginAmount = contrib;
                      _quotationDate = selectedDate;
                      _renderKey++;
                    });
                    Navigator.of(ctx).pop();
                    _saveCurrentQuotation();
                    _saveCurrentMarginReceipt();
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _openEditDetailsDialog() async {
    final nameCtrl = TextEditingController(text: _customerName);
    final consumerCtrl = TextEditingController(text: _consumerNo);
    final mobileCtrl = TextEditingController(text: _mobileNo);
    final villageCtrl = TextEditingController(text: _villageCity);
    final addressCtrl = TextEditingController(text: _address);
    final districtCtrl = TextEditingController(text: _district);
    final quoteNoCtrl = TextEditingController(text: _quotationNo);
    final capCtrl = TextEditingController(text: _capacity);

    final costCtrl = TextEditingController(text: _totalCost > 0 ? _totalCost.toStringAsFixed(0) : '');
    final gstCtrl = TextEditingController(text: _gstAmount > 0 ? _gstAmount.toStringAsFixed(0) : '0');
    final grandTotalCtrl = TextEditingController(text: _grandTotal > 0 ? _grandTotal.toStringAsFixed(0) : '');
    final loanCtrl = TextEditingController(text: _bankLoan > 0 ? _bankLoan.toStringAsFixed(0) : '');
    final contribCtrl = TextEditingController(text: _contribution > 0 ? _contribution.toStringAsFixed(0) : '');

    DateTime selectedDate = _quotationDate;

    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDlgState) {
            final currentCost = double.tryParse(costCtrl.text.trim()) ?? 0.0;
            final currentGst = double.tryParse(gstCtrl.text.trim()) ?? 0.0;
            final currentGrand = double.tryParse(grandTotalCtrl.text.trim()) ?? (currentCost + currentGst);
            final currentLoan = double.tryParse(loanCtrl.text.trim()) ?? (currentGrand * 0.9);
            final currentContrib = double.tryParse(contribCtrl.text.trim()) ?? (currentGrand - currentLoan).clamp(0.0, double.infinity);
            final loanPct = currentGrand > 0 ? (currentLoan / currentGrand * 100) : 90.0;
            final contribPct = currentGrand > 0 ? (currentContrib / currentGrand * 100) : 10.0;
            final words = NumberToWordsUtils.convertToIndianRupees(currentGrand);

            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Row(
                children: [
                  Icon(Icons.edit_note, color: Color(0xFF0F2D69), size: 22),
                  SizedBox(width: 8),
                  Text('Customize Bank Loan Quotation', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F2D69))),
                ],
              ),
              content: SizedBox(
                width: 520,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Section 1: Customer Details (Auto-fetched)
                      const Text('1. Customer Information (Auto-fetched)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF0F2D69))),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(child: TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Customer Name *', isDense: true, border: OutlineInputBorder()))),
                          const SizedBox(width: 10),
                          Expanded(child: TextField(controller: consumerCtrl, decoration: const InputDecoration(labelText: 'Consumer No. *', isDense: true, border: OutlineInputBorder()))),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(child: TextField(controller: addressCtrl, decoration: const InputDecoration(labelText: 'Address *', isDense: true, border: OutlineInputBorder()))),
                          const SizedBox(width: 10),
                          Expanded(child: TextField(controller: villageCtrl, decoration: const InputDecoration(labelText: 'Village / City *', isDense: true, border: OutlineInputBorder()))),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(child: TextField(controller: districtCtrl, decoration: const InputDecoration(labelText: 'District *', isDense: true, border: OutlineInputBorder()))),
                          const SizedBox(width: 10),
                          Expanded(child: TextField(controller: mobileCtrl, decoration: const InputDecoration(labelText: 'Mobile No. *', isDense: true, border: OutlineInputBorder()))),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Section 2: System Specifications
                      const Text('2. System & Quotation Info', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF0F2D69))),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            flex: 4,
                            child: TextField(
                              controller: quoteNoCtrl,
                              decoration: const InputDecoration(labelText: 'Quotation No. *', isDense: true, border: OutlineInputBorder()),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            flex: 4,
                            child: TextField(
                              controller: capCtrl,
                              decoration: const InputDecoration(labelText: 'System Capacity *', isDense: true, border: OutlineInputBorder()),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            flex: 4,
                            child: InkWell(
                              onTap: () async {
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate: selectedDate,
                                  firstDate: DateTime(2020),
                                  lastDate: DateTime(2035),
                                );
                                if (picked != null) {
                                  setDlgState(() => selectedDate = picked);
                                }
                              },
                              child: InputDecorator(
                                decoration: const InputDecoration(
                                  labelText: 'Quotation Date *',
                                  isDense: true,
                                  border: OutlineInputBorder(),
                                  prefixIcon: Icon(Icons.calendar_today_rounded, size: 15, color: Color(0xFF0F2D69)),
                                ),
                                child: Text(
                                  DateFormat('dd-MM-yyyy').format(selectedDate),
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        children: ['3 kW', '3.5 kW', '4 kW', '5 kW', '6 kW', '10 kW'].map((val) {
                          return ActionChip(
                            label: Text(val, style: const TextStyle(fontSize: 11)),
                            onPressed: () {
                              setDlgState(() {
                                capCtrl.text = val;
                                if (val == '3 kW') costCtrl.text = '180000';
                                if (val == '3.5 kW') costCtrl.text = '200000';
                                if (val == '4 kW') costCtrl.text = '240000';
                                if (val == '5 kW') costCtrl.text = '300000';
                                if (val == '6 kW') costCtrl.text = '360000';
                                if (val == '10 kW') costCtrl.text = '600000';
                                final newCost = double.tryParse(costCtrl.text) ?? 180000.0;
                                final newGst = double.tryParse(gstCtrl.text) ?? 0.0;
                                final tot = newCost + newGst;
                                grandTotalCtrl.text = tot.toStringAsFixed(0);
                                final pLoan = (tot * 0.9).roundToDouble();
                                final pContrib = (tot - pLoan).clamp(0.0, double.infinity);
                                loanCtrl.text = pLoan.toStringAsFixed(0);
                                contribCtrl.text = pContrib.toStringAsFixed(0);
                              });
                            },
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 16),

                      // Section 3: Financial Details
                      const Text('3. Financial Details (Auto-calculated)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF0F2D69))),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: costCtrl,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(labelText: 'Total System Cost (Rs.) *', isDense: true, border: OutlineInputBorder()),
                              onChanged: (val) => setDlgState(() {
                                final c = double.tryParse(val.trim()) ?? 0.0;
                                final g = double.tryParse(gstCtrl.text.trim()) ?? 0.0;
                                final tot = c + g;
                                grandTotalCtrl.text = tot.toStringAsFixed(0);
                                final loan = (tot * 0.9).roundToDouble();
                                final contrib = (tot - loan).clamp(0.0, double.infinity);
                                loanCtrl.text = loan.toStringAsFixed(0);
                                contribCtrl.text = contrib.toStringAsFixed(0);
                              }),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextField(
                              controller: gstCtrl,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(labelText: 'GST (Rs.)', isDense: true, border: OutlineInputBorder()),
                              onChanged: (val) => setDlgState(() {
                                final g = double.tryParse(val.trim()) ?? 0.0;
                                final c = double.tryParse(costCtrl.text.trim()) ?? 0.0;
                                final tot = c + g;
                                grandTotalCtrl.text = tot.toStringAsFixed(0);
                                final loan = (tot * 0.9).roundToDouble();
                                final contrib = (tot - loan).clamp(0.0, double.infinity);
                                loanCtrl.text = loan.toStringAsFixed(0);
                                contribCtrl.text = contrib.toStringAsFixed(0);
                              }),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: grandTotalCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Grand Total (Rs.) *', isDense: true, border: OutlineInputBorder()),
                        onChanged: (val) => setDlgState(() {
                          final gt = double.tryParse(val.trim()) ?? 0.0;
                          final g = double.tryParse(gstCtrl.text.trim()) ?? 0.0;
                          costCtrl.text = (gt - g).clamp(0.0, double.infinity).toStringAsFixed(0);
                          final loan = (gt * 0.9).roundToDouble();
                          final contrib = (gt - loan).clamp(0.0, double.infinity);
                          loanCtrl.text = loan.toStringAsFixed(0);
                          contribCtrl.text = contrib.toStringAsFixed(0);
                        }),
                      ),
                      const SizedBox(height: 10),
                      // Bank Loan Amount & Customer Contribution (Two-way auto-calculate)
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: loanCtrl,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                labelText: 'Bank Loan (${loanPct.toStringAsFixed(0)}%) *',
                                helperText: 'Auto-calculates customer contribution',
                                isDense: true,
                                border: const OutlineInputBorder(),
                                prefixIcon: const Icon(Icons.account_balance, size: 18, color: Color(0xFF0F2D69)),
                              ),
                              onChanged: (val) => setDlgState(() {
                                final gt = double.tryParse(grandTotalCtrl.text.trim()) ?? 0.0;
                                final loan = double.tryParse(val.trim()) ?? 0.0;
                                final contrib = (gt - loan).clamp(0.0, double.infinity);
                                contribCtrl.text = contrib.toStringAsFixed(0);
                              }),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextField(
                              controller: contribCtrl,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                labelText: 'Customer Contri (${contribPct.toStringAsFixed(0)}%) *',
                                helperText: 'Auto: Grand Total - Loan',
                                isDense: true,
                                border: const OutlineInputBorder(),
                                prefixIcon: const Icon(Icons.person_outline, size: 18, color: Color(0xFF047857)),
                              ),
                              onChanged: (val) => setDlgState(() {
                                final gt = double.tryParse(grandTotalCtrl.text.trim()) ?? 0.0;
                                final contrib = double.tryParse(val.trim()) ?? 0.0;
                                final loan = (gt - contrib).clamp(0.0, double.infinity);
                                loanCtrl.text = loan.toStringAsFixed(0);
                              }),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      // Live Breakdown Card
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFBFDBFE)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Loan: ${currencyFormat.format(currentLoan)} (${loanPct.toStringAsFixed(0)}%)',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF0F2D69)),
                            ),
                            Text(
                              'Customer Contri: ${currencyFormat.format(currentContrib)} (${contribPct.toStringAsFixed(0)}%)',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF047857)),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Grand Total & Words preview
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFECFDF5),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFA7F3D0)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Grand Total:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF047857))),
                                Text(currencyFormat.format(currentGrand), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF047857))),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text('Words: $words', style: const TextStyle(fontSize: 10.5, fontStyle: FontStyle.italic, color: Color(0xFF065F46))),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
                FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: const Color(0xFF0F2D69)),
                  onPressed: () {
                    final c = double.tryParse(costCtrl.text.trim()) ?? _totalCost;
                    final g = double.tryParse(gstCtrl.text.trim()) ?? 0.0;
                    final tot = double.tryParse(grandTotalCtrl.text.trim()) ?? (c + g);
                    final l = double.tryParse(loanCtrl.text.trim()) ?? (tot * 0.9);
                    final contrib = double.tryParse(contribCtrl.text.trim()) ?? (tot - l).clamp(0.0, double.infinity);

                    setState(() {
                      _customerName = nameCtrl.text.trim();
                      _consumerNo = consumerCtrl.text.trim();
                      _mobileNo = mobileCtrl.text.trim();
                      _villageCity = villageCtrl.text.trim();
                      _address = addressCtrl.text.trim();
                      _district = districtCtrl.text.trim();
                      _quotationNo = quoteNoCtrl.text.trim();
                      _capacity = capCtrl.text.trim();
                      _totalCost = c;
                      _gstAmount = g;
                      _grandTotal = tot;
                      _bankLoan = l;
                      _contribution = contrib;
                      _marginAmount = contrib;
                      _quotationDate = selectedDate;
                      _renderKey++;
                    });
                    Navigator.of(ctx).pop();
                    _saveCurrentQuotation();
                    _saveCurrentMarginReceipt();
                  },
                  child: const Text('Apply Changes'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final quotation = _buildQuotation();
    final marginReceipt = _buildMarginReceipt();

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Container(
        width: (MediaQuery.of(context).size.width * 0.94).clamp(960.0, 1280.0),
        height: (MediaQuery.of(context).size.height * 0.94).clamp(650.0, 940.0),
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Row 1: Header Top Bar (Title + Customer Name + Subtitle + Close Button)
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: _selectedTab == 0 ? const Color(0xFFEFF6FF) : const Color(0xFFECFDF5),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: _selectedTab == 0 ? const Color(0xFFBFDBFE) : const Color(0xFFA7F3D0),
                    ),
                  ),
                  child: Icon(
                    _selectedTab == 0 ? Icons.request_quote_rounded : Icons.receipt_long_rounded,
                    color: _selectedTab == 0 ? const Color(0xFF0F2D69) : const Color(0xFF047857),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Text(
                            _selectedTab == 0 ? 'Solar System Quotation' : 'Margin Money Receipt (10%)',
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0F2D69),
                              letterSpacing: -0.2,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Text('—', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: const Color(0xFFCBD5E1)),
                              ),
                              child: Text(
                                _customerName,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF1E293B),
                                ),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _selectedTab == 0
                            ? 'For Bank Loan / Finance Purpose • Consumer No: $_consumerNo • Quotation No: $_quotationNo • Date: ${DateFormat('dd MMM yyyy').format(_quotationDate)}'
                            : '10% Customer Margin Contribution for Bank Loan • Receipt No: $_receiptNo • Mode: $_paymentMode • Date: ${DateFormat('dd MMM yyyy').format(_receiptDate)}',
                        style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 22),
                  tooltip: 'Close',
                  style: IconButton.styleFrom(
                    backgroundColor: const Color(0xFFF1F5F9),
                    foregroundColor: const Color(0xFF475569),
                    hoverColor: const Color(0xFFE2E8F0),
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Row 2: Document Switcher Tabs (Left) + Actions Toolbar (Right)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Left: Document Switcher Pills
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFCBD5E1)),
                  ),
                  padding: const EdgeInsets.all(3),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      InkWell(
                        onTap: () => setState(() {
                          _selectedTab = 0;
                          _renderKey++;
                        }),
                        borderRadius: BorderRadius.circular(6),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: _selectedTab == 0 ? const Color(0xFF0D2B6F) : Colors.transparent,
                            borderRadius: BorderRadius.circular(6),
                            boxShadow: _selectedTab == 0
                                ? [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 4, offset: const Offset(0, 2))]
                                : null,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.description_rounded,
                                size: 14,
                                color: _selectedTab == 0 ? Colors.white : const Color(0xFF475569),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '1. Solar Quotation',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: _selectedTab == 0 ? Colors.white : const Color(0xFF475569),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      InkWell(
                        onTap: () => setState(() {
                          _selectedTab = 1;
                          _renderKey++;
                        }),
                        borderRadius: BorderRadius.circular(6),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: _selectedTab == 1 ? const Color(0xFF047857) : Colors.transparent,
                            borderRadius: BorderRadius.circular(6),
                            boxShadow: _selectedTab == 1
                                ? [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 4, offset: const Offset(0, 2))]
                                : null,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.receipt_long_rounded,
                                size: 14,
                                color: _selectedTab == 1 ? Colors.white : const Color(0xFF475569),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '2. Margin Money Receipt (10%)',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: _selectedTab == 1 ? Colors.white : const Color(0xFF475569),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Right: Action Buttons Toolbar
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (_selectedTab == 0) ...[
                      // Edit Amount
                      FilledButton.tonalIcon(
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFFFEF3C7),
                          foregroundColor: const Color(0xFF92400E),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                          visualDensity: VisualDensity.compact,
                        ),
                        onPressed: _openEditAmountDialog,
                        icon: const Icon(Icons.currency_rupee_rounded, size: 14),
                        label: const Text('Edit Amount', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5)),
                      ),
                      // All Specs
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                          visualDensity: VisualDensity.compact,
                          side: const BorderSide(color: Color(0xFFCBD5E1)),
                        ),
                        onPressed: _openEditDetailsDialog,
                        icon: const Icon(Icons.edit_note, size: 15),
                        label: const Text('All Specs', style: TextStyle(fontSize: 11.5)),
                      ),
                      // Share WhatsApp
                      FilledButton.tonalIcon(
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF25D366).withValues(alpha: 0.15),
                          foregroundColor: const Color(0xFF128C7E),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                          visualDensity: VisualDensity.compact,
                        ),
                        onPressed: () => BankLoanQuotationService.shareViaWhatsApp(quotation),
                        icon: const Icon(Icons.share_rounded, size: 14),
                        label: const Text('Share', style: TextStyle(fontSize: 11.5)),
                      ),
                      // Download PDF
                      FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF0D2B6F),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                          visualDensity: VisualDensity.compact,
                        ),
                        onPressed: () async {
                          await _saveCurrentQuotation();
                          if (context.mounted) {
                            await BankLoanQuotationService.downloadQuotationPdf(context, quotation);
                          }
                        },
                        icon: const Icon(Icons.download_rounded, size: 14),
                        label: const Text('Download PDF', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                      ),
                    ] else ...[
                      // Edit Receipt Details
                      FilledButton.tonalIcon(
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFFECFDF5),
                          foregroundColor: const Color(0xFF047857),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                          visualDensity: VisualDensity.compact,
                        ),
                        onPressed: _openEditReceiptDialog,
                        icon: const Icon(Icons.edit_calendar_rounded, size: 14),
                        label: const Text('Edit Receipt Details', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5)),
                      ),
                      // Edit Amount
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                          visualDensity: VisualDensity.compact,
                          side: const BorderSide(color: Color(0xFFCBD5E1)),
                        ),
                        onPressed: _openEditAmountDialog,
                        icon: const Icon(Icons.currency_rupee_rounded, size: 14),
                        label: const Text('Edit Amount', style: TextStyle(fontSize: 11.5)),
                      ),
                      // Share Receipt
                      FilledButton.tonalIcon(
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF25D366).withValues(alpha: 0.15),
                          foregroundColor: const Color(0xFF128C7E),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                          visualDensity: VisualDensity.compact,
                        ),
                        onPressed: () => MarginMoneyReceiptService.shareViaWhatsApp(receipt: marginReceipt),
                        icon: const Icon(Icons.share_rounded, size: 14),
                        label: const Text('Share Receipt', style: TextStyle(fontSize: 11.5)),
                      ),
                      // Download Receipt
                      FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF047857),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                          visualDensity: VisualDensity.compact,
                        ),
                        onPressed: () async {
                          await _saveCurrentMarginReceipt();
                          if (context.mounted) {
                            await MarginMoneyReceiptService.downloadPdf(marginReceipt);
                          }
                        },
                        icon: const Icon(Icons.download_rounded, size: 14),
                        label: const Text('Download Receipt', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                      ),
                    ],

                    // Universal Print Button
                    IconButton(
                      tooltip: 'Print ${_selectedTab == 0 ? "Quotation" : "Margin Receipt"}',
                      style: IconButton.styleFrom(
                        backgroundColor: const Color(0xFFF1F5F9),
                        foregroundColor: const Color(0xFF334155),
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.all(7),
                      ),
                      onPressed: () async {
                        if (_selectedTab == 1) {
                          await Printing.layoutPdf(
                            onLayout: (format) async => MarginMoneyReceiptService.generateReceiptPdfBytes(marginReceipt),
                            name: marginReceipt.pdfFileName,
                          );
                        } else {
                          await Printing.layoutPdf(
                            onLayout: (format) async => BankLoanQuotationService.generateQuotationPdfBytes(quotation),
                            name: quotation.pdfFileName,
                          );
                        }
                      },
                      icon: const Icon(Icons.print_rounded, size: 16),
                    ),

                    // Download Both (Complete Bank Set)
                    FilledButton.tonalIcon(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFEFF6FF),
                        foregroundColor: const Color(0xFF1D4ED8),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                        visualDensity: VisualDensity.compact,
                      ),
                      onPressed: () async {
                        await _saveCurrentQuotation();
                        await _saveCurrentMarginReceipt();
                        if (!context.mounted) return;
                        await BankLoanQuotationService.downloadQuotationPdf(context, quotation);
                        if (!context.mounted) return;
                        await MarginMoneyReceiptService.downloadPdf(marginReceipt);
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Both Bank Documents (Quotation + Margin Receipt) downloaded!'),
                            backgroundColor: Color(0xFF1D4ED8),
                          ),
                        );
                      },
                      icon: const Icon(Icons.collections_bookmark_rounded, size: 14),
                      label: const Text('Bank Set (Both)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5)),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Financial Summary Card (Key Metrics Grid + Dedicated Amount in Words)
            if (_selectedTab == 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFBBF7D0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        _buildSummaryMetric(
                          label: 'SYSTEM CAPACITY',
                          value: '$_capacity On-Grid',
                          color: const Color(0xFF065F46),
                          icon: Icons.solar_power_rounded,
                        ),
                        _buildMetricDivider(),
                        _buildSummaryMetric(
                          label: 'GRAND TOTAL',
                          value: currencyFormat.format(_grandTotal),
                          color: const Color(0xFF047857),
                          isLarge: true,
                        ),
                        _buildMetricDivider(),
                        _buildSummaryMetric(
                          label: 'BANK LOAN (${_grandTotal > 0 ? (_bankLoan / _grandTotal * 100).toStringAsFixed(0) : '90'}%)',
                          value: currencyFormat.format(_bankLoan),
                          color: const Color(0xFF0F2D69),
                        ),
                        _buildMetricDivider(),
                        _buildSummaryMetric(
                          label: 'MARGIN MONEY (${_grandTotal > 0 ? (_contribution / _grandTotal * 100).toStringAsFixed(0) : '10'}%)',
                          value: currencyFormat.format(_contribution),
                          color: const Color(0xFF92400E),
                        ),
                        const Spacer(),
                        InkWell(
                          onTap: _openEditAmountDialog,
                          borderRadius: BorderRadius.circular(6),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFF047857),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.edit_rounded, size: 11, color: Colors.white),
                                SizedBox(width: 4),
                                Text('Edit Amounts', style: TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.8),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        children: [
                          const Text(
                            'Amount in Words: ',
                            style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF065F46)),
                          ),
                          Expanded(
                            child: Text(
                              NumberToWordsUtils.convertToIndianRupees(_grandTotal),
                              style: const TextStyle(
                                fontStyle: FontStyle.italic,
                                color: Color(0xFF047857),
                                fontSize: 10.5,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              )
            else
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEFCE8),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFFEF08A)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        _buildSummaryMetric(
                          label: 'RECEIPT NO',
                          value: _receiptNo,
                          color: const Color(0xFF92400E),
                          icon: Icons.receipt_rounded,
                        ),
                        _buildMetricDivider(),
                        _buildSummaryMetric(
                          label: 'MARGIN RECEIVED (10%)',
                          value: currencyFormat.format(_marginAmount),
                          color: const Color(0xFFB45309),
                          isLarge: true,
                        ),
                        _buildMetricDivider(),
                        _buildSummaryMetric(
                          label: 'PAYMENT MODE',
                          value: _paymentMode,
                          color: const Color(0xFF0F2D69),
                        ),
                        _buildMetricDivider(),
                        _buildSummaryMetric(
                          label: 'TRANSACTION REF',
                          value: _transactionRef,
                          color: const Color(0xFF334155),
                        ),
                        const Spacer(),
                        InkWell(
                          onTap: _openEditReceiptDialog,
                          borderRadius: BorderRadius.circular(6),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFB45309),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.edit_rounded, size: 11, color: Colors.white),
                                SizedBox(width: 4),
                                Text('Edit Receipt', style: TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.8),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        children: [
                          const Text(
                            'Amount in Words: ',
                            style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF92400E)),
                          ),
                          Expanded(
                            child: Text(
                              NumberToWordsUtils.convertToIndianRupees(_marginAmount),
                              style: const TextStyle(
                                fontStyle: FontStyle.italic,
                                color: Color(0xFF92400E),
                                fontSize: 10.5,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 12),

            // Body: Live Interactive Preview + Quotation History
            Expanded(
              child: Row(
                children: [
                  // Live Preview (70% width)
                  Expanded(
                    flex: 7,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: PdfPreview(
                          key: ValueKey('preview_${_selectedTab}_$_renderKey'),
                          build: (PdfPageFormat format) async {
                            if (_selectedTab == 1) {
                              return MarginMoneyReceiptService.generateReceiptPdfBytes(marginReceipt);
                            }
                            return BankLoanQuotationService.generateQuotationPdfBytes(quotation);
                          },
                          useActions: false,
                          canChangeOrientation: false,
                          canChangePageFormat: false,
                          allowPrinting: false,
                          allowSharing: false,
                          initialPageFormat: PdfPageFormat.a4,
                          pdfFileName: _selectedTab == 1 ? marginReceipt.pdfFileName : quotation.pdfFileName,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(width: 12),

                  // Quotation History Sidebar (30% width)
                  Expanded(
                    flex: 3,
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Row(
                                children: [
                                  Icon(Icons.history_rounded, size: 16, color: Color(0xFF0F2D69)),
                                  SizedBox(width: 6),
                                  Text(
                                    'Quotation History',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F2D69)),
                                  ),
                                ],
                              ),
                              IconButton(
                                icon: const Icon(Icons.refresh, size: 16),
                                tooltip: 'Refresh History',
                                onPressed: _loadHistory,
                              ),
                            ],
                          ),
                          const Divider(height: 16),

                          if (_isLoadingHistory)
                            const Expanded(child: Center(child: CircularProgressIndicator(strokeWidth: 2)))
                          else if (_previousQuotations.isEmpty)
                            Expanded(
                              child: Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.description_outlined, size: 36, color: Colors.grey.shade400),
                                    const SizedBox(height: 8),
                                    const Text('No previous quotations', style: TextStyle(fontSize: 12, color: Colors.grey)),
                                    const SizedBox(height: 4),
                                    const Text('Click Generate to save this quotation', style: TextStyle(fontSize: 10.5, color: Colors.grey)),
                                  ],
                                ),
                              ),
                            )
                          else
                            Expanded(
                              child: ListView.separated(
                                itemCount: _previousQuotations.length,
                                separatorBuilder: (_, __) => const SizedBox(height: 8),
                                itemBuilder: (ctx, i) {
                                  final q = _previousQuotations[i];
                                  final isCurrent = q.quotationNo == _quotationNo;

                                  return Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: isCurrent ? const Color(0xFFEFF6FF) : Colors.white,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: isCurrent ? const Color(0xFF3B82F6) : const Color(0xFFE2E8F0),
                                        width: isCurrent ? 1.5 : 1.0,
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              q.quotationNo,
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 12,
                                                color: isCurrent ? const Color(0xFF1D4ED8) : const Color(0xFF0F172A),
                                              ),
                                            ),
                                            Text(
                                              DateFormat('dd MMM yyyy').format(q.quotationDate),
                                              style: const TextStyle(fontSize: 10, color: Colors.grey),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '${q.systemCapacity} • ${currencyFormat.format(q.grandTotal)}',
                                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF047857)),
                                        ),
                                        const SizedBox(height: 8),
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.end,
                                          children: [
                                            // 1. View
                                            InkWell(
                                              onTap: () {
                                                setState(() {
                                                  _initFields(q);
                                                  _renderKey++;
                                                });
                                              },
                                              borderRadius: BorderRadius.circular(4),
                                              child: const Padding(
                                                padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                child: Row(
                                                  children: [
                                                    Icon(Icons.visibility_outlined, size: 14, color: Color(0xFF0F2D69)),
                                                    SizedBox(width: 3),
                                                    Text('View', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF0F2D69))),
                                                  ],
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                            // 2. Edit
                                            InkWell(
                                              onTap: () {
                                                setState(() {
                                                  _initFields(q);
                                                  _renderKey++;
                                                });
                                                _openEditDetailsDialog();
                                              },
                                              borderRadius: BorderRadius.circular(4),
                                              child: const Padding(
                                                padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                child: Row(
                                                  children: [
                                                    Icon(Icons.edit_outlined, size: 14, color: Color(0xFFD97706)),
                                                    SizedBox(width: 3),
                                                    Text('Edit', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFFD97706))),
                                                  ],
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                            // 3. Regenerate
                                            InkWell(
                                              onTap: () async {
                                                await QuotationStorageService.saveQuotation(q);
                                                setState(() {
                                                  _initFields(q);
                                                  _renderKey++;
                                                });
                                                _loadHistory();
                                                if (context.mounted) {
                                                  ScaffoldMessenger.of(context).showSnackBar(
                                                    SnackBar(
                                                      content: Text('Quotation ${q.quotationNo} regenerated!'),
                                                      backgroundColor: const Color(0xFF047857),
                                                    ),
                                                  );
                                                }
                                              },
                                              borderRadius: BorderRadius.circular(4),
                                              child: const Padding(
                                                padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                child: Row(
                                                  children: [
                                                    Icon(Icons.refresh_rounded, size: 14, color: Color(0xFF2563EB)),
                                                    SizedBox(width: 3),
                                                    Text('Regenerate', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF2563EB))),
                                                  ],
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                            // 4. Share
                                            InkWell(
                                              onTap: () => BankLoanQuotationService.shareViaWhatsApp(q),
                                              borderRadius: BorderRadius.circular(4),
                                              child: const Padding(
                                                padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                child: Row(
                                                  children: [
                                                    Icon(Icons.share_outlined, size: 14, color: Color(0xFF059669)),
                                                    SizedBox(width: 3),
                                                    Text('Share', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF059669))),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryMetric({
    required String label,
    required String value,
    required Color color,
    IconData? icon,
    bool isLarge = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
              color: color.withValues(alpha: 0.8),
            ),
          ),
          const SizedBox(height: 1),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: isLarge ? 14 : 12, color: color),
                const SizedBox(width: 3),
              ],
              Text(
                value,
                style: TextStyle(
                  fontSize: isLarge ? 13 : 11.5,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricDivider() {
    return Container(
      height: 22,
      width: 1,
      margin: const EdgeInsets.symmetric(horizontal: 6),
      color: Colors.black12,
    );
  }
}
