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
      _totalCost = cust.totalAmount > 0 ? cust.totalAmount : 160000.0;
      _gstAmount = 0.0;
      _grandTotal = _totalCost + _gstAmount;
      _bankLoan = cust.loanSanctionedAmount > 0
          ? cust.loanSanctionedAmount
          : (_grandTotal * 0.9).roundToDouble();
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

  Future<void> _openEditAmountDialog() async {
    final capCtrl = TextEditingController(text: _capacity);
    final costCtrl = TextEditingController(text: _totalCost.toStringAsFixed(0));
    final gstCtrl = TextEditingController(text: _gstAmount.toStringAsFixed(0));
    final grandTotalCtrl = TextEditingController(text: _grandTotal.toStringAsFixed(0));
    final loanCtrl = TextEditingController(text: _bankLoan.toStringAsFixed(0));

    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDlgState) {
            final c = double.tryParse(costCtrl.text.trim()) ?? 0.0;
            final g = double.tryParse(gstCtrl.text.trim()) ?? 0.0;
            final currentGrand = double.tryParse(grandTotalCtrl.text.trim()) ?? (c + g);
            final currentLoan = double.tryParse(loanCtrl.text.trim()) ?? (currentGrand * 0.9);
            final currentContrib = (currentGrand - currentLoan).clamp(0.0, double.infinity);
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
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Edit Quotation Amount', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F2D69))),
                      Text('System Capacity, Total Cost & Loan Calculations', style: TextStyle(fontSize: 11, color: Colors.grey)),
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
                      // Quick System Capacity & Cost Presets
                      const Text('Quick Select System Capacity & Cost:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF0F2D69))),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          {'cap': '3 kW', 'cost': 160000},
                          {'cap': '3.3 kW', 'cost': 180000},
                          {'cap': '4 kW', 'cost': 210000},
                          {'cap': '5 kW', 'cost': 260000},
                          {'cap': '6 kW', 'cost': 310000},
                          {'cap': '10 kW', 'cost': 520000},
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
                                capCtrl.text = pCap;
                                costCtrl.text = pCost.toString();
                                gstCtrl.text = '0';
                                grandTotalCtrl.text = pCost.toString();
                                loanCtrl.text = (pCost * 0.9).round().toString();
                              });
                            },
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 16),

                      // Manual System Capacity
                      TextField(
                        controller: capCtrl,
                        decoration: const InputDecoration(
                          labelText: 'System Capacity (e.g. 3 kW, 5 kW) *',
                          isDense: true,
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.bolt_rounded, size: 20, color: Color(0xFFF59E0B)),
                        ),
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
                                final cost = double.tryParse(val.trim()) ?? 0.0;
                                final gst = double.tryParse(gstCtrl.text.trim()) ?? 0.0;
                                final tot = cost + gst;
                                grandTotalCtrl.text = tot.toStringAsFixed(0);
                                loanCtrl.text = (tot * 0.9).round().toString();
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
                                loanCtrl.text = (tot * 0.9).round().toString();
                              }),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Grand Total & Bank Loan (90%)
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: grandTotalCtrl,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Grand Total (Rs.) *',
                                isDense: true,
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.account_balance_wallet_outlined, size: 18),
                              ),
                              onChanged: (val) => setDlgState(() {
                                final gt = double.tryParse(val.trim()) ?? 0.0;
                                final gst = double.tryParse(gstCtrl.text.trim()) ?? 0.0;
                                costCtrl.text = (gt - gst).clamp(0.0, double.infinity).toStringAsFixed(0);
                                loanCtrl.text = (gt * 0.9).round().toString();
                              }),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextField(
                              controller: loanCtrl,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Bank Loan (90%) *',
                                isDense: true,
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.account_balance, size: 18),
                              ),
                              onChanged: (_) => setDlgState(() {}),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Customer Contribution Breakdown (10%)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEFCE8),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFFEF08A)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.person_outline, size: 18, color: Color(0xFF854D0E)),
                                SizedBox(width: 6),
                                Text('Customer Contribution (10%):', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF854D0E))),
                              ],
                            ),
                            Text(
                              currencyFormat.format(currentContrib),
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF854D0E)),
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
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF0D2B6F),
                    foregroundColor: Colors.white,
                  ),
                  icon: const Icon(Icons.check_circle_outline, size: 16),
                  label: const Text('Save & Update Quotation'),
                  onPressed: () {
                    final c = double.tryParse(costCtrl.text.trim()) ?? _totalCost;
                    final g = double.tryParse(gstCtrl.text.trim()) ?? 0.0;
                    final tot = double.tryParse(grandTotalCtrl.text.trim()) ?? (c + g);
                    final l = double.tryParse(loanCtrl.text.trim()) ?? (tot * 0.9);
                    final contrib = (tot - l).clamp(0.0, double.infinity);

                    setState(() {
                      _capacity = capCtrl.text.trim().isNotEmpty ? capCtrl.text.trim() : _capacity;
                      _totalCost = c;
                      _gstAmount = g;
                      _grandTotal = tot;
                      _bankLoan = l;
                      _contribution = contrib;
                      _renderKey++;
                    });
                    Navigator.of(ctx).pop();
                    _saveCurrentQuotation();
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

    final costCtrl = TextEditingController(text: _totalCost.toStringAsFixed(0));
    final gstCtrl = TextEditingController(text: _gstAmount.toStringAsFixed(0));
    final grandTotalCtrl = TextEditingController(text: _grandTotal.toStringAsFixed(0));
    final loanCtrl = TextEditingController(text: _bankLoan.toStringAsFixed(0));

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
            final currentContrib = (currentGrand - currentLoan).clamp(0.0, double.infinity);
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
                          Expanded(child: TextField(controller: quoteNoCtrl, decoration: const InputDecoration(labelText: 'Quotation No. *', isDense: true, border: OutlineInputBorder()))),
                          const SizedBox(width: 10),
                          Expanded(child: TextField(controller: capCtrl, decoration: const InputDecoration(labelText: 'System Capacity *', isDense: true, border: OutlineInputBorder()))),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        children: ['3 kW', '3.3 kW', '4 kW', '5 kW', '6 kW', '10 kW'].map((val) {
                          return ActionChip(
                            label: Text(val, style: const TextStyle(fontSize: 11)),
                            onPressed: () {
                              setDlgState(() {
                                capCtrl.text = val;
                                if (val == '3 kW') costCtrl.text = '160000';
                                if (val == '4 kW') costCtrl.text = '210000';
                                if (val == '5 kW') costCtrl.text = '260000';
                                if (val == '6 kW') costCtrl.text = '310000';
                                if (val == '10 kW') costCtrl.text = '520000';
                                final newCost = double.tryParse(costCtrl.text) ?? 160000.0;
                                final newGst = double.tryParse(gstCtrl.text) ?? 0.0;
                                final tot = newCost + newGst;
                                grandTotalCtrl.text = tot.toStringAsFixed(0);
                                loanCtrl.text = (tot * 0.9).round().toString();
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
                                loanCtrl.text = (tot * 0.9).round().toString();
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
                                loanCtrl.text = (tot * 0.9).round().toString();
                              }),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: grandTotalCtrl,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(labelText: 'Grand Total (Rs.) *', isDense: true, border: OutlineInputBorder()),
                              onChanged: (val) => setDlgState(() {
                                final gt = double.tryParse(val.trim()) ?? 0.0;
                                final g = double.tryParse(gstCtrl.text.trim()) ?? 0.0;
                                costCtrl.text = (gt - g).clamp(0.0, double.infinity).toStringAsFixed(0);
                                loanCtrl.text = (gt * 0.9).round().toString();
                              }),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextField(
                              controller: loanCtrl,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(labelText: 'Bank Loan Amount (Rs.) *', isDense: true, border: OutlineInputBorder()),
                              onChanged: (_) => setDlgState(() {}),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFFCBD5E1)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Customer Contribution:', style: TextStyle(fontSize: 11, color: Colors.grey)),
                            Text(
                              currencyFormat.format(currentContrib),
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F2D69)),
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
                    final contrib = (tot - l).clamp(0.0, double.infinity);

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
                      _quotationDate = selectedDate;
                      _renderKey++;
                    });
                    Navigator.of(ctx).pop();
                    _saveCurrentQuotation();
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
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Container(
        width: 1060,
        height: MediaQuery.of(context).size.height * 0.92,
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header Bar
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _selectedTab == 0 ? const Color(0xFFEFF6FF) : const Color(0xFFECFDF5),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _selectedTab == 0 ? const Color(0xFFBFDBFE) : const Color(0xFFA7F3D0)),
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
                    children: [
                      Row(
                        children: [
                          Text(
                            _selectedTab == 0 ? 'Solar System Quotation — $_customerName' : 'Margin Money Receipt (10%) — $_customerName',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F2D69)),
                          ),
                          const SizedBox(width: 12),
                          // Document Switcher (Quotation vs Margin Receipt)
                          Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFFCBD5E1)),
                            ),
                            padding: const EdgeInsets.all(2),
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
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                    decoration: BoxDecoration(
                                      color: _selectedTab == 0 ? const Color(0xFF0D2B6F) : Colors.transparent,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(Icons.description_outlined, size: 14, color: _selectedTab == 0 ? Colors.white : const Color(0xFF475569)),
                                        const SizedBox(width: 5),
                                        Text('1. Solar Quotation', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: _selectedTab == 0 ? Colors.white : const Color(0xFF475569))),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 2),
                                InkWell(
                                  onTap: () => setState(() {
                                    _selectedTab = 1;
                                    _renderKey++;
                                  }),
                                  borderRadius: BorderRadius.circular(6),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                    decoration: BoxDecoration(
                                      color: _selectedTab == 1 ? const Color(0xFF047857) : Colors.transparent,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(Icons.receipt_long_rounded, size: 14, color: _selectedTab == 1 ? Colors.white : const Color(0xFF475569)),
                                        const SizedBox(width: 5),
                                        Text('2. Margin Money Receipt (10%)', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: _selectedTab == 1 ? Colors.white : const Color(0xFF475569))),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _selectedTab == 0
                            ? 'For Bank Loan / Finance Purpose • Consumer No: $_consumerNo • Quotation No: $_quotationNo'
                            : '10% Customer Margin Contribution for Bank Loan • Receipt No: $_receiptNo • Mode: $_paymentMode',
                        style: const TextStyle(fontSize: 11.5, color: Colors.grey),
                      ),
                    ],
                  ),
                ),

                // Top Action Buttons
                if (_selectedTab == 0) ...[
                  // 1. Edit Amount
                  FilledButton.tonalIcon(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFFEF3C7),
                      foregroundColor: const Color(0xFF92400E),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    ),
                    onPressed: _openEditAmountDialog,
                    icon: const Icon(Icons.currency_rupee_rounded, size: 15),
                    label: const Text('Edit Amount', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                  const SizedBox(width: 6),
                  // 2. All Specs
                  OutlinedButton.icon(
                    onPressed: _openEditDetailsDialog,
                    icon: const Icon(Icons.edit_note, size: 15),
                    label: const Text('All Specs', style: TextStyle(fontSize: 12)),
                  ),
                  const SizedBox(width: 6),
                  // 3. Share Quotation
                  FilledButton.tonalIcon(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF25D366).withValues(alpha: 0.15),
                      foregroundColor: const Color(0xFF128C7E),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    ),
                    onPressed: () => BankLoanQuotationService.shareViaWhatsApp(quotation),
                    icon: const Icon(Icons.share_rounded, size: 15),
                    label: const Text('Share', style: TextStyle(fontSize: 12)),
                  ),
                  const SizedBox(width: 6),
                  // 4. Download Quotation
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF0D2B6F),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    ),
                    onPressed: () async {
                      await _saveCurrentQuotation();
                      if (context.mounted) {
                        await BankLoanQuotationService.downloadQuotationPdf(context, quotation);
                      }
                    },
                    icon: const Icon(Icons.download_rounded, size: 15),
                    label: const Text('Download PDF', style: TextStyle(fontSize: 12)),
                  ),
                ] else ...[
                  // Margin Receipt Actions
                  // 1. Edit Receipt
                  FilledButton.tonalIcon(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFECFDF5),
                      foregroundColor: const Color(0xFF047857),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    ),
                    onPressed: _openEditReceiptDialog,
                    icon: const Icon(Icons.edit_calendar_rounded, size: 15),
                    label: const Text('Edit Receipt Details', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                  const SizedBox(width: 6),
                  // 2. Edit Amount
                  OutlinedButton.icon(
                    onPressed: _openEditAmountDialog,
                    icon: const Icon(Icons.currency_rupee_rounded, size: 15),
                    label: const Text('Edit Amount', style: TextStyle(fontSize: 12)),
                  ),
                  const SizedBox(width: 6),
                  // 3. Share Margin Receipt
                  FilledButton.tonalIcon(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF25D366).withValues(alpha: 0.15),
                      foregroundColor: const Color(0xFF128C7E),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    ),
                    onPressed: () => MarginMoneyReceiptService.shareViaWhatsApp(receipt: marginReceipt),
                    icon: const Icon(Icons.share_rounded, size: 15),
                    label: const Text('Share Receipt', style: TextStyle(fontSize: 12)),
                  ),
                  const SizedBox(width: 6),
                  // 4. Download Margin Receipt
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF047857),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    ),
                    onPressed: () async {
                      await _saveCurrentMarginReceipt();
                      if (context.mounted) {
                        await MarginMoneyReceiptService.downloadPdf(marginReceipt);
                      }
                    },
                    icon: const Icon(Icons.download_rounded, size: 15),
                    label: const Text('Download Receipt', style: TextStyle(fontSize: 12)),
                  ),
                ],

                const SizedBox(width: 6),
                // Universal Action: Download Both (Complete Bank Set)
                FilledButton.tonalIcon(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFEFF6FF),
                    foregroundColor: const Color(0xFF1D4ED8),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  ),
                  onPressed: () async {
                    await _saveCurrentQuotation();
                    await _saveCurrentMarginReceipt();
                    if (context.mounted) {
                      await BankLoanQuotationService.downloadQuotationPdf(context, quotation);
                      await MarginMoneyReceiptService.downloadPdf(marginReceipt);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Both Bank Documents (Quotation + Margin Receipt) downloaded!'),
                          backgroundColor: Color(0xFF1D4ED8),
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.collections_bookmark_rounded, size: 15),
                  label: const Text('Bank Set (Both)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                ),
                const SizedBox(width: 6),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Summary Pill (Interactive depending on Tab)
            if (_selectedTab == 0)
              InkWell(
                onTap: _openEditAmountDialog,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFECFDF5),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFA7F3D0)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('System: $_capacity On-Grid', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF065F46), fontSize: 12)),
                      Text('Grand Total: ${currencyFormat.format(_grandTotal)}', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF047857), fontSize: 13)),
                      Text('Bank Loan: ${currencyFormat.format(_bankLoan)} (90%)', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F2D69), fontSize: 12)),
                      Text('Contribution: ${currencyFormat.format(_contribution)} (10%)', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF334155), fontSize: 12)),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(NumberToWordsUtils.convertToIndianRupees(_grandTotal), style: const TextStyle(fontStyle: FontStyle.italic, color: Color(0xFF047857), fontSize: 11)),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF047857),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.edit, size: 10, color: Colors.white),
                                SizedBox(width: 3),
                                Text('Edit Amount', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              )
            else
              InkWell(
                onTap: _openEditReceiptDialog,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEFCE8),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFFEF08A)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Receipt: $_receiptNo', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF92400E), fontSize: 12)),
                      Text('Margin Received (10%): ${currencyFormat.format(_marginAmount)}', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFB45309), fontSize: 13)),
                      Text('Mode: $_paymentMode', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F2D69), fontSize: 12)),
                      Text('Ref: $_transactionRef', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF334155), fontSize: 12)),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(NumberToWordsUtils.convertToIndianRupees(_marginAmount), style: const TextStyle(fontStyle: FontStyle.italic, color: Color(0xFF92400E), fontSize: 11)),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFB45309),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.edit, size: 10, color: Colors.white),
                                SizedBox(width: 3),
                                Text('Edit Receipt', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
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
                          canChangeOrientation: false,
                          canChangePageFormat: false,
                          allowPrinting: true,
                          allowSharing: true,
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
}
