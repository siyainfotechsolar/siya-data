import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/consumer_record.dart';
import '../models/solar_quotation.dart';
import '../models/customer_margin_receipt.dart';
import '../services/bank_loan_quotation_service.dart';
import '../services/margin_money_receipt_service.dart';
import '../services/quotation_storage_service.dart';
import '../utils/number_to_words_utils.dart';

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
    BuildContext context, {
    required ConsumerRecord customer,
    SolarQuotation? initialQuotation,
    int initialTab = 0,
  }) {
    return showDialog<void>(
      context: context,
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
  bool _isGenerating = false;
  File? _cachedFile;
  File? _cachedReceiptFile;
  String? _statusMessage;
  int _selectedTab = 0;

  // Quotation Properties
  late String _customerName;
  late String _consumerNo;
  late String _mobileNo;
  late String _address;
  late String _villageCity;
  late String _district;
  late String _quotationNo;
  late DateTime _quotationDate;
  late String _systemCapacity;
  late String _systemType;
  late double _totalSystemCost;
  late double _gstAmount;
  late double _grandTotal;
  late double _bankLoanAmount;
  late double _customerContribution;
  late String _bankName;
  late String _branch;
  late String _accountNo;
  late String _ifscCode;
  late String _accountType;
  late String _upiId;

  // Margin Money Receipt Properties
  late String _receiptNo;
  late DateTime _receiptDate;
  late String _paymentMode;
  late String _transactionRef;
  late DateTime _paymentDate;
  late double _marginAmount;
  late String _receiptNotes;

  List<SolarQuotation> _previousQuotations = [];
  bool _isLoadingHistory = true;

  final currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: 'Rs. ', decimalDigits: 2);

  @override
  void initState() {
    super.initState();
    _initQuotationFields();
    _loadHistory();
  }

  void _initQuotationFields() {
    final cust = widget.customer;
    final init = widget.initialQuotation;

    _customerName = init?.customerName ?? cust.name.trim();
    _consumerNo = init?.consumerNo ?? cust.consumerNo.trim();
    _mobileNo = init?.mobileNo ?? cust.mobile?.trim() ?? '';

    // Smart address resolution
    final fullAddr = init?.address ?? (cust.address?.trim().isNotEmpty == true
        ? cust.address!.trim()
        : (cust.village?.trim().isNotEmpty == true ? cust.village!.trim() : 'Betawad'));
    _address = fullAddr;

    // Smart village/district extraction
    _villageCity = init?.villageCity ?? _extractVillage(fullAddr, cust.village);
    _district = init?.district ?? _extractDistrict(fullAddr);

    // Date & No
    _quotationDate = init?.quotationDate ?? DateTime.now();
    final suffix = _consumerNo.length > 4 ? _consumerNo.substring(_consumerNo.length - 4) : _consumerNo;
    _quotationNo = init?.quotationNo ?? 'SIYA-Q-${_quotationDate.year}-$suffix';

    // System capacity
    String cap = init?.systemCapacity ?? '';
    if (cap.isEmpty && cust.systemCapacity != null && cust.systemCapacity!.trim().isNotEmpty) {
      cap = cust.systemCapacity!.trim();
    } else if (cap.isEmpty && cust.remarks != null && cust.remarks!.trim().isNotEmpty) {
      final match = RegExp(r'(\d+(?:\.\d+)?\s*(?:kw|kW|KW|Kw))').firstMatch(cust.remarks!);
      if (match != null) cap = match.group(1)!;
    }
    _systemCapacity = cap.isNotEmpty ? cap : '3 kW';
    _systemType = init?.systemType ?? 'On-Grid Solar System';

    // Financials
    if (init != null) {
      _totalSystemCost = init.totalSystemCost;
      _gstAmount = init.gstAmount;
      _grandTotal = init.grandTotal;
      _bankLoanAmount = init.bankLoanAmount;
      _customerContribution = init.customerContribution;
    } else {
      final baseCost = cust.totalAmount > 0 ? cust.totalAmount : 0.0;
      _totalSystemCost = baseCost;
      _gstAmount = 0.0;
      _grandTotal = _totalSystemCost + _gstAmount;

      if (cust.loanSanctionedAmount > 0) {
        _bankLoanAmount = cust.loanSanctionedAmount;
      } else {
        _bankLoanAmount = _grandTotal > 0 ? (_grandTotal * 0.9).roundToDouble() : 0.0; // 90% Bank Loan
      }
      _customerContribution = (_grandTotal - _bankLoanAmount).clamp(0.0, double.infinity); // 10% Contribution
    }

    _selectedTab = widget.initialTab;
    _receiptDate = _quotationDate;
    _receiptNo = 'SIYA-MMR-${_receiptDate.year}-$suffix';
    _paymentMode = 'Cash';
    _transactionRef = 'Paid in Cash';
    _paymentDate = _receiptDate;
    _marginAmount = _customerContribution;
    _receiptNotes = 'Received 10% Customer Margin Contribution in Cash towards PM Surya Ghar Bank Solar Loan installation.';

    // Bank Details
    _bankName = init?.bankName ?? 'STATE BANK OF INDIA';
    _branch = init?.branch ?? 'Betawad';
    _accountNo = init?.accountNo ?? '40662252403';
    _ifscCode = init?.ifscCode ?? 'SBIN0004798';
    _accountType = init?.accountType ?? 'Current Account';
    _upiId = init?.upiId ?? 'siyainfodigital@sbi';
  }

  String _extractVillage(String addr, String? village) {
    if (village != null && village.trim().isNotEmpty) return village.trim();
    if (addr.isEmpty) return 'Betawad';
    final parts = addr.split(RegExp(r'[,/-]'));
    if (parts.isNotEmpty) return parts.first.trim();
    return 'Betawad';
  }

  String _extractDistrict(String addr) {
    final lower = addr.toLowerCase();
    if (lower.contains('dhule')) return 'Dhule';
    if (lower.contains('jalgaon')) return 'Jalgaon';
    if (lower.contains('nashik')) return 'Nashik';
    if (lower.contains('nandurbar')) return 'Nandurbar';
    return 'Dhule';
  }

  Future<void> _loadHistory() async {
    try {
      final list = await QuotationStorageService.getQuotationsForCustomer(widget.customer.consumerNo);
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

  SolarQuotation _buildCurrentQuotation() {
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
      systemCapacity: _systemCapacity,
      systemType: _systemType,
      totalSystemCost: _totalSystemCost,
      gstAmount: _gstAmount,
      grandTotal: _grandTotal,
      bankLoanAmount: _bankLoanAmount,
      customerContribution: _customerContribution,
      bankName: _bankName,
      branch: _branch,
      accountNo: _accountNo,
      ifscCode: _ifscCode,
      accountType: _accountType,
      upiId: _upiId,
      pdfFilePath: _cachedFile?.path,
    );
  }

  Future<File?> _ensurePdfGenerated() async {
    if (_cachedFile != null && await _cachedFile!.exists()) {
      return _cachedFile;
    }

    setState(() {
      _isGenerating = true;
      _statusMessage = 'Generating A4 Solar Quotation...';
    });

    try {
      final quotation = _buildCurrentQuotation();
      final file = await BankLoanQuotationService.generateQuotationPdf(
        quotation: quotation,
      );

      final updatedQuotation = quotation.copyWith(pdfFilePath: file.path);
      await QuotationStorageService.saveQuotation(updatedQuotation);

      if (mounted) {
        setState(() {
          _cachedFile = file;
          _isGenerating = false;
          _statusMessage = null;
        });
        _loadHistory();
      }
      return file;
    } catch (e) {
      debugPrint('Error generating quotation: $e');
      if (mounted) {
        setState(() {
          _isGenerating = false;
          _statusMessage = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to generate quotation: $e'),
            backgroundColor: const Color(0xFFDC2626),
          ),
        );
      }
      return null;
    }
  }

  Future<void> _handlePreview() async {
    final file = await _ensurePdfGenerated();
    if (file != null && mounted) {
      await BankLoanQuotationService.previewQuotation(file);
    }
  }

  Future<void> _handleShare() async {
    final file = await _ensurePdfGenerated();
    if (file != null && mounted) {
      final quotation = _buildCurrentQuotation();
      await BankLoanQuotationService.shareQuotation(file, quotation);
    }
  }

  Future<void> _handleDownload() async {
    final file = await _ensurePdfGenerated();
    if (file != null && mounted) {
      setState(() {
        _isGenerating = true;
        _statusMessage = 'Saving to device Downloads...';
      });

      try {
        final quotation = _buildCurrentQuotation();
        final downloaded = await BankLoanQuotationService.downloadQuotation(file, quotation);
        if (mounted) {
          setState(() => _isGenerating = false);
          final fileName = downloaded.uri.pathSegments.last;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Saved: $fileName'),
              backgroundColor: const Color(0xFF059669),
              duration: const Duration(seconds: 4),
              action: SnackBarAction(
                label: 'OPEN',
                textColor: Colors.white,
                onPressed: () => BankLoanQuotationService.previewQuotation(downloaded),
              ),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isGenerating = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error downloading quotation: $e'),
              backgroundColor: const Color(0xFFDC2626),
            ),
          );
        }
      }
    }
  }

  CustomerMarginReceipt _buildCurrentReceipt() {
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
      systemCapacity: _systemCapacity,
      systemType: _systemType,
      totalSystemCost: _grandTotal,
      bankLoanAmount: _bankLoanAmount,
      marginAmount: _marginAmount > 0 ? _marginAmount : _customerContribution,
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

  Future<File?> _ensureReceiptPdfGenerated() async {
    if (_cachedReceiptFile != null && await _cachedReceiptFile!.exists()) {
      return _cachedReceiptFile;
    }

    setState(() {
      _isGenerating = true;
      _statusMessage = 'Generating Margin Money Receipt PDF...';
    });

    try {
      final receipt = _buildCurrentReceipt();
      final file = await MarginMoneyReceiptService.generateReceiptPdf(receipt: receipt);
      final updatedReceipt = receipt.copyWith(pdfFilePath: file.path);
      await QuotationStorageService.saveMarginReceipt(updatedReceipt);

      if (mounted) {
        setState(() {
          _cachedReceiptFile = file;
          _isGenerating = false;
          _statusMessage = null;
        });
      }
      return file;
    } catch (e) {
      debugPrint('Error generating margin receipt: $e');
      if (mounted) {
        setState(() {
          _isGenerating = false;
          _statusMessage = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to generate margin receipt: $e'),
            backgroundColor: const Color(0xFFDC2626),
          ),
        );
      }
      return null;
    }
  }

  Future<void> _handleReceiptPreview() async {
    final file = await _ensureReceiptPdfGenerated();
    if (file != null && mounted) {
      await MarginMoneyReceiptService.previewReceipt(file);
    }
  }

  Future<void> _handleReceiptShare() async {
    final file = await _ensureReceiptPdfGenerated();
    if (file != null && mounted) {
      final receipt = _buildCurrentReceipt();
      await MarginMoneyReceiptService.shareReceipt(file, receipt);
    }
  }

  Future<void> _handleReceiptDownload() async {
    final file = await _ensureReceiptPdfGenerated();
    if (file != null && mounted) {
      setState(() {
        _isGenerating = true;
        _statusMessage = 'Saving Margin Receipt to Downloads...';
      });

      try {
        final receipt = _buildCurrentReceipt();
        final downloaded = await MarginMoneyReceiptService.downloadReceipt(file, receipt);
        if (mounted) {
          setState(() => _isGenerating = false);
          final fileName = downloaded.uri.pathSegments.last;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Saved: $fileName'),
              backgroundColor: const Color(0xFF047857),
              duration: const Duration(seconds: 4),
              action: SnackBarAction(
                label: 'OPEN',
                textColor: Colors.white,
                onPressed: () => MarginMoneyReceiptService.previewReceipt(downloaded),
              ),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isGenerating = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error downloading receipt: $e'),
              backgroundColor: const Color(0xFFDC2626),
            ),
          );
        }
      }
    }
  }

  Future<void> _handleDownloadBoth() async {
    final qFile = await _ensurePdfGenerated();
    final rFile = await _ensureReceiptPdfGenerated();
    if (qFile != null && rFile != null && mounted) {
      setState(() {
        _isGenerating = true;
        _statusMessage = 'Saving Bank Package (Both PDFs)...';
      });
      try {
        final q = _buildCurrentQuotation();
        final r = _buildCurrentReceipt();
        await BankLoanQuotationService.downloadQuotation(qFile, q);
        await MarginMoneyReceiptService.downloadReceipt(rFile, r);
        if (mounted) {
          setState(() => _isGenerating = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Both Bank Documents (Quotation + Margin Receipt) saved to Downloads!'),
              backgroundColor: Color(0xFF1D4ED8),
              duration: Duration(seconds: 4),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isGenerating = false);
        }
      }
    }
  }

  Future<void> _openEditReceiptModal() async {
    final receiptNoCtrl = TextEditingController(text: _receiptNo);
    final txnRefCtrl = TextEditingController(text: _transactionRef);
    final amountCtrl = TextEditingController(text: _marginAmount.toStringAsFixed(0));
    final notesCtrl = TextEditingController(text: _receiptNotes);
    String selectedMode = _paymentMode;
    DateTime selectedDate = _receiptDate;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final curAmt = double.tryParse(amountCtrl.text.trim()) ?? _marginAmount;
            final words = NumberToWordsUtils.convertToIndianRupees(curAmt);

            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.receipt_long_rounded, color: Color(0xFF047857), size: 24),
                            SizedBox(width: 8),
                            Text(
                              'Edit Margin Receipt Details',
                              style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.bold, color: Color(0xFF0F2D69)),
                            ),
                          ],
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.of(ctx).pop(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Update payment mode, transaction reference and receipt date.',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(height: 16),

                    Row(
                      children: [
                        Expanded(
                          flex: 6,
                          child: TextField(
                            controller: receiptNoCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Receipt No. *',
                              border: OutlineInputBorder(),
                              isDense: true,
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
                                setSheetState(() => selectedDate = picked);
                              }
                            },
                            child: InputDecorator(
                              decoration: const InputDecoration(
                                labelText: 'Date',
                                border: OutlineInputBorder(),
                                isDense: true,
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
                        labelText: 'Margin Amount Received (Rs.) *',
                        border: OutlineInputBorder(),
                        isDense: true,
                        prefixIcon: Icon(Icons.currency_rupee_rounded, size: 18),
                      ),
                      onChanged: (_) => setSheetState(() {}),
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
                        border: OutlineInputBorder(),
                        isDense: true,
                        prefixIcon: Icon(Icons.payment_rounded, size: 18),
                      ),
                      items: ['Cash', 'Online / UPI', 'Cheque / DD', 'NEFT / RTGS', 'Bank Transfer']
                          .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                          .toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setSheetState(() {
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
                        labelText: selectedMode == 'Cash' ? 'Remarks / Cash Receipt' : 'Transaction Ref / UTR / Cheque No. *',
                        hintText: selectedMode == 'Cash' ? 'Paid in Cash' : 'e.g. UPI/6284910294 / Chq 40291',
                        border: const OutlineInputBorder(),
                        isDense: true,
                        prefixIcon: const Icon(Icons.receipt_long, size: 18),
                      ),
                    ),
                    const SizedBox(height: 12),

                    TextField(
                      controller: notesCtrl,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Receipt Purpose / Remarks',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 18),

                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF047857),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      icon: const Icon(Icons.check_circle_outline, size: 18),
                      label: const Text('Save & Update Receipt', style: TextStyle(fontWeight: FontWeight.bold)),
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
                          _cachedReceiptFile = null;
                        });
                        Navigator.of(ctx).pop();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Margin Receipt details updated!'),
                            backgroundColor: Color(0xFF047857),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
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

  Future<void> _openEditAmountModal() async {
    final capacityCtrl = TextEditingController(text: _systemCapacity);
    final costCtrl = TextEditingController(text: _totalSystemCost > 0 ? _totalSystemCost.toStringAsFixed(0) : '');
    final gstCtrl = TextEditingController(text: _gstAmount > 0 ? _gstAmount.toStringAsFixed(0) : '0');
    final grandTotalCtrl = TextEditingController(text: _grandTotal > 0 ? _grandTotal.toStringAsFixed(0) : '');
    final loanCtrl = TextEditingController(text: _bankLoanAmount > 0 ? _bankLoanAmount.toStringAsFixed(0) : '');
    final contribCtrl = TextEditingController(text: _customerContribution > 0 ? _customerContribution.toStringAsFixed(0) : '');
    DateTime selectedDate = _quotationDate;
    bool isReverseCalcMode = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final currentCost = double.tryParse(costCtrl.text.trim()) ?? 0.0;
            final currentGst = double.tryParse(gstCtrl.text.trim()) ?? 0.0;
            final currentGrand = double.tryParse(grandTotalCtrl.text.trim()) ?? (currentCost + currentGst);
            final currentLoan = double.tryParse(loanCtrl.text.trim()) ?? (currentGrand * 0.9);
            final currentContrib = double.tryParse(contribCtrl.text.trim()) ?? (currentGrand - currentLoan).clamp(0.0, double.infinity);
            final isLoanExceeded = currentLoan > currentGrand;
            final isContribExceeded = currentContrib > currentGrand;
            final hasValidationError = isLoanExceeded || isContribExceeded || currentGrand <= 0;
            final loanPct = currentGrand > 0 ? (currentLoan / currentGrand * 100) : 90.0;
            final contribPct = currentGrand > 0 ? (currentContrib / currentGrand * 100) : 10.0;
            final words = NumberToWordsUtils.convertToIndianRupees(currentGrand);

            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.currency_rupee_rounded, color: Color(0xFF0F2D69), size: 24),
                            SizedBox(width: 8),
                            Text(
                              'Edit Quotation Amount',
                              style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.bold, color: Color(0xFF0F2D69)),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            OutlinedButton.icon(
                              icon: const Icon(Icons.restart_alt_rounded, size: 15, color: Color(0xFFD97706)),
                              label: const Text('Reset', style: TextStyle(fontSize: 11.5, color: Color(0xFFD97706), fontWeight: FontWeight.bold)),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                side: const BorderSide(color: Color(0xFFFCD34D)),
                                backgroundColor: const Color(0xFFFFFBEB),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                              ),
                              onPressed: () {
                                setSheetState(() {
                                  capacityCtrl.clear();
                                  costCtrl.clear();
                                  gstCtrl.text = '0';
                                  grandTotalCtrl.clear();
                                  loanCtrl.clear();
                                  contribCtrl.clear();
                                  isReverseCalcMode = true;
                                });
                              },
                            ),
                            const SizedBox(width: 4),
                            IconButton(
                              icon: const Icon(Icons.close),
                              onPressed: () => Navigator.of(ctx).pop(),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Update system capacity, total cost & bank finance calculations.',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(height: 16),

                    // Quick Select Chips
                    const Text('Quick Select System Capacity & Cost:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F2D69))),
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
                        final isSelected = capacityCtrl.text.trim() == pCap;

                        return ChoiceChip(
                          label: Text('$pCap — ${currencyFormat.format(pCost)}', style: TextStyle(fontSize: 11.5, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                          selected: isSelected,
                          selectedColor: const Color(0xFFFEF3C7),
                          onSelected: (_) {
                            setSheetState(() {
                              isReverseCalcMode = false;
                              capacityCtrl.text = pCap;
                              costCtrl.text = pCost.toString();
                              gstCtrl.text = '0';
                              grandTotalCtrl.text = pCost.toString();
                              final loan = (pCost * 0.9).roundToDouble();
                              final contrib = (pCost - loan).clamp(0.0, double.infinity);
                              loanCtrl.text = loan.toStringAsFixed(0);
                              contribCtrl.text = contrib.toStringAsFixed(0);
                            });
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),

                    // Manual Capacity & Quotation Date
                    Row(
                      children: [
                        Expanded(
                          flex: 6,
                          child: TextField(
                            controller: capacityCtrl,
                            decoration: const InputDecoration(
                              labelText: 'System Capacity *',
                              border: OutlineInputBorder(),
                              isDense: true,
                              prefixIcon: Icon(Icons.bolt, color: Color(0xFFF59E0B)),
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
                                setSheetState(() => selectedDate = picked);
                              }
                            },
                            child: InputDecorator(
                              decoration: const InputDecoration(
                                labelText: 'Date *',
                                border: OutlineInputBorder(),
                                isDense: true,
                                prefixIcon: Icon(Icons.calendar_today_rounded, size: 16),
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

                    // Total Cost & GST
                    Row(
                      children: [
                        Expanded(
                          flex: 6,
                          child: TextField(
                            controller: costCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Total System Cost (Rs.) *',
                              border: OutlineInputBorder(),
                              isDense: true,
                              prefixIcon: Icon(Icons.currency_rupee, size: 18),
                            ),
                            onChanged: (val) => setSheetState(() {
                              isReverseCalcMode = false;
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
                          flex: 4,
                          child: TextField(
                            controller: gstCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'GST (Rs.)',
                              border: OutlineInputBorder(),
                              isDense: true,
                              hintText: '0',
                            ),
                            onChanged: (val) => setSheetState(() {
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
                    const SizedBox(height: 12),

                    // Grand Total
                    TextField(
                      controller: grandTotalCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Grand Total (Rs.) *',
                        border: OutlineInputBorder(),
                        isDense: true,
                        prefixIcon: Icon(Icons.account_balance_wallet_outlined, size: 18),
                      ),
                      onChanged: (val) => setSheetState(() {
                        isReverseCalcMode = false;
                        final gt = double.tryParse(val.trim()) ?? 0.0;
                        final g = double.tryParse(gstCtrl.text.trim()) ?? 0.0;
                        costCtrl.text = (gt - g).clamp(0.0, double.infinity).toStringAsFixed(0);
                        final loan = (gt * 0.9).roundToDouble();
                        final contrib = (gt - loan).clamp(0.0, double.infinity);
                        loanCtrl.text = loan.toStringAsFixed(0);
                        contribCtrl.text = contrib.toStringAsFixed(0);
                      }),
                    ),
                    const SizedBox(height: 12),

                    // Bank Loan & Customer Contribution (Two-Way Auto Calculation)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: TextField(
                            controller: loanCtrl,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: 'Bank Loan (${loanPct.toStringAsFixed(0)}%) *',
                              helperText: isLoanExceeded ? null : 'Auto-calculates contribution',
                              errorText: isLoanExceeded ? 'Exceeds Grand Total' : null,
                              helperStyle: const TextStyle(fontSize: 10),
                              border: const OutlineInputBorder(),
                              isDense: true,
                              prefixIcon: Icon(
                                Icons.account_balance,
                                size: 18,
                                color: isLoanExceeded ? Colors.red : const Color(0xFF0F2D69),
                              ),
                            ),
                            onChanged: (val) => setSheetState(() {
                              final loan = double.tryParse(val.trim()) ?? 0.0;
                              final gt = double.tryParse(grandTotalCtrl.text.trim()) ?? 0.0;
                              final gst = double.tryParse(gstCtrl.text.trim()) ?? 0.0;

                              if (loan <= 0) {
                                if (isReverseCalcMode || gt == 0) {
                                  grandTotalCtrl.clear();
                                  costCtrl.clear();
                                  contribCtrl.clear();
                                  capacityCtrl.clear();
                                } else {
                                  contribCtrl.text = gt.toStringAsFixed(0);
                                }
                                return;
                              }

                              // Reverse calculate if reset was pressed, grand total is empty/0, or loan entered exceeds grand total
                              if (isReverseCalcMode || gt == 0 || loan > gt) {
                                final autoGrand = (loan / 0.9).roundToDouble();
                                final autoContrib = (autoGrand - loan).clamp(0.0, double.infinity);
                                final autoCost = (autoGrand - gst).clamp(0.0, double.infinity);

                                grandTotalCtrl.text = autoGrand > 0 ? autoGrand.toStringAsFixed(0) : '';
                                costCtrl.text = autoCost > 0 ? autoCost.toStringAsFixed(0) : '';
                                contribCtrl.text = autoContrib > 0 ? autoContrib.toStringAsFixed(0) : '';
                                capacityCtrl.text = _autoSuggestCapacity(autoGrand);
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
                              helperText: isContribExceeded ? null : 'Auto: Total - Loan',
                              errorText: isContribExceeded ? 'Exceeds Grand Total' : null,
                              helperStyle: const TextStyle(fontSize: 10),
                              border: const OutlineInputBorder(),
                              isDense: true,
                              prefixIcon: Icon(
                                Icons.person_outline,
                                size: 18,
                                color: isContribExceeded ? Colors.red : const Color(0xFF047857),
                              ),
                            ),
                            onChanged: (val) => setSheetState(() {
                              final contrib = double.tryParse(val.trim()) ?? 0.0;
                              final gt = double.tryParse(grandTotalCtrl.text.trim()) ?? 0.0;
                              final gst = double.tryParse(gstCtrl.text.trim()) ?? 0.0;

                              if (contrib <= 0) {
                                if (isReverseCalcMode || gt == 0) {
                                  grandTotalCtrl.clear();
                                  costCtrl.clear();
                                  loanCtrl.clear();
                                  capacityCtrl.clear();
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
                                capacityCtrl.text = _autoSuggestCapacity(autoGrand);
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
                                    setSheetState(() {
                                      final autoGrand = (currentLoan / 0.9).roundToDouble();
                                      final gst = double.tryParse(gstCtrl.text.trim()) ?? 0.0;
                                      grandTotalCtrl.text = autoGrand.toStringAsFixed(0);
                                      costCtrl.text = (autoGrand - gst).clamp(0.0, double.infinity).toStringAsFixed(0);
                                      contribCtrl.text = (autoGrand - currentLoan).clamp(0.0, double.infinity).toStringAsFixed(0);
                                      capacityCtrl.text = _autoSuggestCapacity(autoGrand);
                                    });
                                  },
                                ),
                                ActionChip(
                                  avatar: const Icon(Icons.refresh, size: 14, color: Color(0xFF047857)),
                                  label: Text('Cap Loan to 90% (${currencyFormat.format(currentGrand * 0.9)})', style: const TextStyle(fontSize: 11, color: Color(0xFF047857))),
                                  backgroundColor: const Color(0xFFECFDF5),
                                  onPressed: () {
                                    setSheetState(() {
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
                    const SizedBox(height: 12),

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
                                  Text(
                                    'Bank Loan (${loanPct.toStringAsFixed(1)}%):',
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF0F2D69)),
                                  ),
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
                                  Text(
                                    'Customer Contribution (${contribPct.toStringAsFixed(1)}%):',
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF047857)),
                                  ),
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

                    // Words Preview
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
                              const Text('Grand Total for Bank:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF047857))),
                              Text(currencyFormat.format(currentGrand), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF047857))),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text('Words: $words', style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Color(0xFF065F46))),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Action Buttons Row: Reset / Clear + Save & Update
                    Row(
                      children: [
                        Expanded(
                          flex: 4,
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              side: const BorderSide(color: Color(0xFFFCD34D)),
                              backgroundColor: const Color(0xFFFFFBEB),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            icon: const Icon(Icons.restart_alt_rounded, size: 18, color: Color(0xFFD97706)),
                            label: const Text(
                              'Reset',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFFD97706)),
                            ),
                            onPressed: () {
                              setSheetState(() {
                                capacityCtrl.clear();
                                costCtrl.clear();
                                gstCtrl.text = '0';
                                grandTotalCtrl.clear();
                                loanCtrl.clear();
                                contribCtrl.clear();
                                isReverseCalcMode = true;
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 6,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: hasValidationError ? Colors.grey.shade400 : const Color(0xFF0D2B6F),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            onPressed: hasValidationError
                                ? null
                                : () {
                              final c = double.tryParse(costCtrl.text.trim()) ?? _totalSystemCost;
                              final g = double.tryParse(gstCtrl.text.trim()) ?? 0.0;
                              final tot = double.tryParse(grandTotalCtrl.text.trim()) ?? (c + g);
                              final l = double.tryParse(loanCtrl.text.trim()) ?? (tot * 0.9);
                              final contrib = double.tryParse(contribCtrl.text.trim()) ?? (tot - l).clamp(0.0, double.infinity);

                              setState(() {
                                _systemCapacity = capacityCtrl.text.trim().isNotEmpty ? capacityCtrl.text.trim() : _systemCapacity;
                                _totalSystemCost = c;
                                _gstAmount = g;
                                _grandTotal = tot;
                                _bankLoanAmount = l;
                                _customerContribution = contrib;
                                _marginAmount = contrib;
                                _quotationDate = selectedDate;
                                _cachedFile = null;
                                _cachedReceiptFile = null;
                              });
                              Navigator.of(ctx).pop();
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Quotation amount updated! Ready to generate PDF.'),
                                  backgroundColor: Color(0xFF059669),
                                  duration: Duration(seconds: 2),
                                ),
                              );
                            },
                            icon: const Icon(Icons.check_circle_outline, size: 18),
                            label: const Text('Save & Update', style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _openEditDetailsModal() async {
    final nameCtrl = TextEditingController(text: _customerName);
    final consumerCtrl = TextEditingController(text: _consumerNo);
    final mobileCtrl = TextEditingController(text: _mobileNo);
    final addrCtrl = TextEditingController(text: _address);
    final villageCtrl = TextEditingController(text: _villageCity);
    final districtCtrl = TextEditingController(text: _district);
    final quoteNoCtrl = TextEditingController(text: _quotationNo);

    final capacityCtrl = TextEditingController(text: _systemCapacity);
    final costCtrl = TextEditingController(text: _totalSystemCost > 0 ? _totalSystemCost.toStringAsFixed(0) : '');
    final gstCtrl = TextEditingController(text: _gstAmount > 0 ? _gstAmount.toStringAsFixed(0) : '0');
    final grandTotalCtrl = TextEditingController(text: _grandTotal > 0 ? _grandTotal.toStringAsFixed(0) : '');
    final loanCtrl = TextEditingController(text: _bankLoanAmount > 0 ? _bankLoanAmount.toStringAsFixed(0) : '');
    final contribCtrl = TextEditingController(text: _customerContribution > 0 ? _customerContribution.toStringAsFixed(0) : '');
    final bankNameCtrl = TextEditingController(text: _bankName);
    final branchCtrl = TextEditingController(text: _branch);
    final accountCtrl = TextEditingController(text: _accountNo);
    final ifscCtrl = TextEditingController(text: _ifscCode);
    final upiCtrl = TextEditingController(text: _upiId);

    DateTime selectedDate = _quotationDate;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final currentCost = double.tryParse(costCtrl.text.trim()) ?? 0.0;
            final currentGst = double.tryParse(gstCtrl.text.trim()) ?? 0.0;
            final currentGrand = double.tryParse(grandTotalCtrl.text.trim()) ?? (currentCost + currentGst);
            final currentLoan = double.tryParse(loanCtrl.text.trim()) ?? (currentGrand * 0.9);
            final currentContrib = double.tryParse(contribCtrl.text.trim()) ?? (currentGrand - currentLoan).clamp(0.0, double.infinity);
            final loanPct = currentGrand > 0 ? (currentLoan / currentGrand * 100) : 90.0;
            final contribPct = currentGrand > 0 ? (currentContrib / currentGrand * 100) : 10.0;
            final words = NumberToWordsUtils.convertToIndianRupees(currentGrand);

            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.edit_note_rounded, color: Color(0xFF0F2D69), size: 24),
                            SizedBox(width: 8),
                            Text(
                              'Edit Quotation Specifications',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F2D69)),
                            ),
                          ],
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.of(ctx).pop(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Customize financial and technical details for bank loan submission.',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(height: 16),

                    // Section 1: System Capacity & Quotation No.
                    const Text('1. System & Quotation Info', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F2D69))),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: quoteNoCtrl,
                            decoration: const InputDecoration(labelText: 'Quotation No. *', border: OutlineInputBorder(), isDense: true),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: capacityCtrl,
                            decoration: const InputDecoration(labelText: 'System Capacity *', border: OutlineInputBorder(), isDense: true),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: ['3 kW', '3.5 kW', '4 kW', '5 kW', '6 kW', '10 kW'].map((cap) {
                        return ActionChip(
                          label: Text(cap, style: const TextStyle(fontSize: 11)),
                          padding: EdgeInsets.zero,
                          onPressed: () {
                            setSheetState(() {
                              capacityCtrl.text = cap;
                              if (cap == '3 kW') costCtrl.text = '180000';
                              if (cap == '3.5 kW') costCtrl.text = '200000';
                              if (cap == '4 kW') costCtrl.text = '240000';
                              if (cap == '5 kW') costCtrl.text = '300000';
                              if (cap == '6 kW') costCtrl.text = '360000';
                              if (cap == '10 kW') costCtrl.text = '600000';
                              final newTot = (double.tryParse(costCtrl.text) ?? 180000.0) + (double.tryParse(gstCtrl.text) ?? 0.0);
                              final loan = (newTot * 0.9).roundToDouble();
                              final contrib = (newTot - loan).clamp(0.0, double.infinity);
                              grandTotalCtrl.text = newTot.toStringAsFixed(0);
                              loanCtrl.text = loan.toStringAsFixed(0);
                              contribCtrl.text = contrib.toStringAsFixed(0);
                            });
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),

                    // Section 2: Financial Details
                    const Text('2. Financial Details', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F2D69))),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: costCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(labelText: 'Total System Cost (Rs.) *', border: OutlineInputBorder(), isDense: true),
                            onChanged: (val) => setSheetState(() {
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
                            decoration: const InputDecoration(labelText: 'GST Amount (Rs.)', border: OutlineInputBorder(), isDense: true),
                            onChanged: (val) => setSheetState(() {
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
                      decoration: const InputDecoration(labelText: 'Grand Total (Rs.) *', border: OutlineInputBorder(), isDense: true),
                      onChanged: (val) => setSheetState(() {
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

                    // Bank Loan & Customer Contribution (Two-Way Auto Calculation)
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: loanCtrl,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: 'Bank Loan (${loanPct.toStringAsFixed(0)}%) *',
                              helperText: 'Auto-calculates contribution',
                              helperStyle: const TextStyle(fontSize: 10),
                              border: const OutlineInputBorder(),
                              isDense: true,
                            ),
                            onChanged: (val) => setSheetState(() {
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
                              helperText: 'Auto: Total - Loan',
                              helperStyle: const TextStyle(fontSize: 10),
                              border: const OutlineInputBorder(),
                              isDense: true,
                            ),
                            onChanged: (val) => setSheetState(() {
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

                    // Live Calculation Breakdown Card
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFFBFDBFE)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Loan (${loanPct.toStringAsFixed(0)}%): ${currencyFormat.format(currentLoan)}',
                              style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF0F2D69))),
                          Text('Contri (${contribPct.toStringAsFixed(0)}%): ${currencyFormat.format(currentContrib)}',
                              style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF047857))),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Highlighted Grand Total & Words preview
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
                              const Text('Grand Total (Auto-calculated):', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF047857))),
                              Text(currencyFormat.format(currentGrand), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF047857))),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text('Words: $words', style: const TextStyle(fontSize: 10.5, fontStyle: FontStyle.italic, color: Color(0xFF065F46))),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Section 3: Customer Details (Pre-filled from Profile)
                    const Text('3. Customer Details (Auto-fetched)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F2D69))),
                    const SizedBox(height: 8),
                    TextField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(labelText: 'Customer Name *', border: OutlineInputBorder(), isDense: true),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: consumerCtrl,
                            decoration: const InputDecoration(labelText: 'Consumer No. *', border: OutlineInputBorder(), isDense: true),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: mobileCtrl,
                            decoration: const InputDecoration(labelText: 'Mobile No. *', border: OutlineInputBorder(), isDense: true),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: villageCtrl,
                            decoration: const InputDecoration(labelText: 'Village *', border: OutlineInputBorder(), isDense: true),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: addrCtrl,
                            decoration: const InputDecoration(labelText: 'Address *', border: OutlineInputBorder(), isDense: true),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Section 4: Bank Account Details
                    const Text('4. Company Bank Account for Disbursement', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F2D69))),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: bankNameCtrl,
                            decoration: const InputDecoration(labelText: 'Bank Name', border: OutlineInputBorder(), isDense: true),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: branchCtrl,
                            decoration: const InputDecoration(labelText: 'Branch', border: OutlineInputBorder(), isDense: true),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: accountCtrl,
                            decoration: const InputDecoration(labelText: 'Account No.', border: OutlineInputBorder(), isDense: true),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: ifscCtrl,
                            decoration: const InputDecoration(labelText: 'IFSC Code', border: OutlineInputBorder(), isDense: true),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: upiCtrl,
                      decoration: const InputDecoration(labelText: 'UPI ID', border: OutlineInputBorder(), isDense: true),
                    ),
                    const SizedBox(height: 14),

                    // Quotation Date Picker
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                        alignment: Alignment.centerLeft,
                      ),
                      icon: const Icon(Icons.calendar_today_rounded, size: 18, color: Color(0xFF0F2D69)),
                      label: Text(
                        'Quotation Date: ${DateFormat('dd MMMM yyyy').format(selectedDate)}',
                        style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.black87),
                      ),
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: selectedDate,
                          firstDate: DateTime(2024),
                          lastDate: DateTime.now().add(const Duration(days: 365)),
                        );
                        if (picked != null) {
                          setSheetState(() => selectedDate = picked);
                        }
                      },
                    ),
                    const SizedBox(height: 20),

                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF0F2D69),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: () {
                        final parsedCost = double.tryParse(costCtrl.text.trim()) ?? _totalSystemCost;
                        final parsedGst = double.tryParse(gstCtrl.text.trim()) ?? 0.0;
                        final parsedTotal = double.tryParse(grandTotalCtrl.text.trim()) ?? (parsedCost + parsedGst);
                        final parsedLoan = double.tryParse(loanCtrl.text.trim()) ?? (parsedTotal * 0.9);
                        final parsedContrib = double.tryParse(contribCtrl.text.trim()) ?? (parsedTotal - parsedLoan).clamp(0.0, double.infinity);

                        setState(() {
                          _customerName = nameCtrl.text.trim();
                          _consumerNo = consumerCtrl.text.trim();
                          _mobileNo = mobileCtrl.text.trim();
                          _address = addrCtrl.text.trim();
                          _villageCity = villageCtrl.text.trim();
                          _district = districtCtrl.text.trim();
                          _quotationNo = quoteNoCtrl.text.trim();
                          _systemCapacity = capacityCtrl.text.trim();
                          _totalSystemCost = parsedCost;
                          _gstAmount = parsedGst;
                          _grandTotal = parsedTotal;
                          _bankLoanAmount = parsedLoan;
                          _customerContribution = parsedContrib;
                          _marginAmount = parsedContrib;
                          _bankName = bankNameCtrl.text.trim();
                          _branch = branchCtrl.text.trim();
                          _accountNo = accountCtrl.text.trim();
                          _ifscCode = ifscCtrl.text.trim();
                          _upiId = upiCtrl.text.trim();
                          _quotationDate = selectedDate;
                          _cachedFile = null; // Invalidate cache to regenerate
                          _cachedReceiptFile = null;
                        });
                        Navigator.of(ctx).pop();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Quotation specifications updated! Ready to generate PDF.'),
                            backgroundColor: Color(0xFF059669),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      },
                      icon: const Icon(Icons.check_circle_outline, size: 18),
                      label: const Text('Apply Changes & Refresh', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final dateDisplay = DateFormat('dd-MM-yyyy').format(_quotationDate);
    final addressDisplay = _address.isNotEmpty ? _address : 'Not Specified';

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      contentPadding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
      actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
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
                  size: 22,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _selectedTab == 0 ? 'Bank Loan Solar Quotation' : 'Customer Margin Money Receipt (${_grandTotal > 0 ? (_customerContribution / _grandTotal * 100).toStringAsFixed(0) : 10}%)',
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      _selectedTab == 0
                          ? 'Official WCR Letterhead • Bank Ready'
                          : 'Margin Payment Proof for Bank Solar Loan',
                      style: const TextStyle(fontSize: 10.5, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Document Switcher Pill
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFCBD5E1)),
            ),
            padding: const EdgeInsets.all(3),
            child: Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => setState(() => _selectedTab = 0),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      decoration: BoxDecoration(
                        color: _selectedTab == 0 ? const Color(0xFF0D2B6F) : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      alignment: Alignment.center,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.description_outlined,
                            size: 13,
                            color: _selectedTab == 0 ? Colors.white : const Color(0xFF475569),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '1. Solar Quotation',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: _selectedTab == 0 ? Colors.white : const Color(0xFF475569),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: InkWell(
                    onTap: () => setState(() => _selectedTab = 1),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      decoration: BoxDecoration(
                        color: _selectedTab == 1 ? const Color(0xFF047857) : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      alignment: Alignment.center,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.receipt_long_rounded,
                            size: 13,
                            color: _selectedTab == 1 ? Colors.white : const Color(0xFF475569),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '2. Margin Receipt (10%)',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: _selectedTab == 1 ? Colors.white : const Color(0xFF475569),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      content: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 500,
          maxHeight: MediaQuery.of(context).size.height * 0.58,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_selectedTab == 0) ...[
                // --- QUOTATION TAB CONTENT ---
                // Specifications Header with Edit Amount and All Details Buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Quotation Specifications',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F2D69)),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFEF3C7),
                            foregroundColor: const Color(0xFF92400E),
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            elevation: 0,
                            side: const BorderSide(color: Color(0xFFFDE68A)),
                          ),
                          icon: const Icon(Icons.currency_rupee_rounded, size: 13, color: Color(0xFF92400E)),
                          label: const Text(
                            'Edit Amount',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                          onPressed: _openEditAmountModal,
                        ),
                        const SizedBox(width: 6),
                        TextButton.icon(
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          icon: const Icon(Icons.edit_note_rounded, size: 15, color: Color(0xFF0F2D69)),
                          label: const Text(
                            'All Details',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0F2D69)),
                          ),
                          onPressed: _openEditDetailsModal,
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 6),

                // Details Summary Box
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.grey.shade900 : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: isDark ? Colors.grey.shade800 : const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    children: [
                      _buildDetailRow('Customer Name', _customerName, isBold: true),
                      const Divider(height: 10),
                      _buildDetailRow('Consumer No.', _consumerNo),
                      const Divider(height: 10),
                      _buildDetailRow('Mobile No.', _mobileNo.isNotEmpty ? _mobileNo : 'N/A'),
                      const Divider(height: 10),
                      _buildDetailRow('Address & Village', '$addressDisplay, $_villageCity'),
                      const Divider(height: 10),
                      _buildDetailRow('Proposed System', '$_systemCapacity On-Grid Solar System', isBold: true),
                      const Divider(height: 10),
                      _buildDetailRow('Quotation No.', _quotationNo),
                      const Divider(height: 10),
                      _buildDetailRow('Date of Issue', dateDisplay),
                    ],
                  ),
                ),
                const SizedBox(height: 10),

                // Financial Highlight Card (Clickable to edit amount directly)
                InkWell(
                  onTap: _openEditAmountModal,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFECFDF5),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFA7F3D0), width: 1.2),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                const Text(
                                  'GRAND TOTAL COST',
                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF065F46)),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF047857),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.edit, size: 10, color: Colors.white),
                                      SizedBox(width: 2),
                                      Text('Edit', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              currencyFormat.format(_grandTotal),
                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF047857)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          NumberToWordsUtils.convertToIndianRupees(_grandTotal),
                          style: const TextStyle(fontSize: 10.5, fontStyle: FontStyle.italic, color: Color(0xFF065F46)),
                        ),
                        const Divider(height: 12, color: Color(0xFFA7F3D0)),
                        Builder(
                          builder: (context) {
                            final loanPct = _grandTotal > 0 ? (_bankLoanAmount / _grandTotal * 100) : 90.0;
                            final contribPct = _grandTotal > 0 ? (_customerContribution / _grandTotal * 100) : 10.0;
                            return Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Bank Loan (${loanPct.toStringAsFixed(0)}%): ${currencyFormat.format(_bankLoanAmount)}',
                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF0F2D69)),
                                ),
                                Text(
                                  'Contribution (${contribPct.toStringAsFixed(0)}%): ${currencyFormat.format(_customerContribution)}',
                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                                ),
                              ],
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                // WCR Format Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFBFDBFE)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.verified_outlined, size: 15, color: Color(0xFF1D4ED8)),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Master WCR Letterhead • A4 Single-Page • Bank Submission Ready',
                          style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: Color(0xFF1D4ED8)),
                        ),
                      ),
                    ],
                  ),
                ),

                // Previously Generated Quotations Section
                if (!_isLoadingHistory && _previousQuotations.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  const Divider(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Previously Generated (${_previousQuotations.length})',
                        style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF0F2D69)),
                      ),
                      const Text('Saved in Profile', style: TextStyle(fontSize: 10, color: Colors.grey)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Container(
                    constraints: const BoxConstraints(maxHeight: 120),
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: _previousQuotations.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 6),
                      itemBuilder: (ctx, i) {
                        final q = _previousQuotations[i];
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.picture_as_pdf_outlined, color: Color(0xFFDC2626), size: 18),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      q.quotationNo,
                                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                                    ),
                                    Text(
                                      '${q.systemCapacity} • ${currencyFormat.format(q.grandTotal)} • ${DateFormat('dd MMM yyyy').format(q.quotationDate)}',
                                      style: const TextStyle(fontSize: 10, color: Colors.grey),
                                    ),
                                  ],
                                ),
                              ),
                              // View
                              IconButton(
                                icon: const Icon(Icons.visibility_outlined, size: 16, color: Color(0xFF0F2D69)),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                tooltip: 'View',
                                onPressed: () async {
                                  if (q.pdfFilePath != null && File(q.pdfFilePath!).existsSync()) {
                                    BankLoanQuotationService.previewQuotation(File(q.pdfFilePath!));
                                  } else {
                                    final file = await BankLoanQuotationService.generateQuotationPdf(quotation: q);
                                    BankLoanQuotationService.previewQuotation(file);
                                  }
                                },
                              ),
                              const SizedBox(width: 6),
                              // Edit
                              IconButton(
                                icon: const Icon(Icons.edit_outlined, size: 16, color: Color(0xFFD97706)),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                tooltip: 'Edit',
                                onPressed: () {
                                  setState(() {
                                    _customerName = q.customerName;
                                    _consumerNo = q.consumerNo;
                                    _mobileNo = q.mobileNo;
                                    _address = q.address;
                                    _villageCity = q.villageCity;
                                    _district = q.district;
                                    _quotationNo = q.quotationNo;
                                    _quotationDate = q.quotationDate;
                                    _systemCapacity = q.systemCapacity;
                                    _systemType = q.systemType;
                                    _totalSystemCost = q.totalSystemCost;
                                    _gstAmount = q.gstAmount;
                                    _grandTotal = q.grandTotal;
                                    _bankLoanAmount = q.bankLoanAmount;
                                    _customerContribution = q.customerContribution;
                                    _bankName = q.bankName;
                                    _branch = q.branch;
                                    _accountNo = q.accountNo;
                                    _ifscCode = q.ifscCode;
                                    _upiId = q.upiId;
                                    _cachedFile = q.pdfFilePath != null ? File(q.pdfFilePath!) : null;
                                  });
                                  _openEditDetailsModal();
                                },
                              ),
                              const SizedBox(width: 6),
                              // Share
                              IconButton(
                                icon: const Icon(Icons.share_outlined, size: 16, color: Color(0xFF059669)),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                tooltip: 'Share',
                                onPressed: () async {
                                  final file = (q.pdfFilePath != null && File(q.pdfFilePath!).existsSync())
                                      ? File(q.pdfFilePath!)
                                      : await BankLoanQuotationService.generateQuotationPdf(quotation: q);
                                  BankLoanQuotationService.shareQuotation(file, q);
                                },
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ] else ...[
                // --- MARGIN MONEY RECEIPT TAB CONTENT ---
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Receipt Specifications',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF047857)),
                    ),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFD1FAE5),
                        foregroundColor: const Color(0xFF065F46),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        elevation: 0,
                        side: const BorderSide(color: Color(0xFFA7F3D0)),
                      ),
                      icon: const Icon(Icons.edit_note_rounded, size: 16, color: Color(0xFF065F46)),
                      label: const Text(
                        'Edit Receipt Details',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                      onPressed: _openEditReceiptModal,
                    ),
                  ],
                ),
                const SizedBox(height: 6),

                // Receipt Summary Box
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.grey.shade900 : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: isDark ? Colors.grey.shade800 : const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    children: [
                      _buildDetailRow('Customer Name', _customerName, isBold: true),
                      const Divider(height: 10),
                      _buildDetailRow('Consumer No.', _consumerNo),
                      const Divider(height: 10),
                      _buildDetailRow('Solar Capacity', '$_systemCapacity On-Grid'),
                      const Divider(height: 10),
                      _buildDetailRow('Total Project Cost', currencyFormat.format(_grandTotal)),
                      const Divider(height: 10),
                      _buildDetailRow('Proposed Bank Loan', '${currencyFormat.format(_bankLoanAmount)} (${_grandTotal > 0 ? (_bankLoanAmount / _grandTotal * 100).toStringAsFixed(0) : 90}%)'),
                      const Divider(height: 10),
                      _buildDetailRow('Receipt No.', _receiptNo),
                      const Divider(height: 10),
                      _buildDetailRow('Receipt Date', DateFormat('dd-MM-yyyy').format(_receiptDate)),
                      const Divider(height: 10),
                      _buildDetailRow('Payment Mode', _paymentMode, isBold: true),
                      const Divider(height: 10),
                      _buildDetailRow('Txn Ref / UTR', _transactionRef),
                    ],
                  ),
                ),
                const SizedBox(height: 10),

                // Margin Money Financial Highlight Card
                InkWell(
                  onTap: _openEditReceiptModal,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFECFDF5),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFA7F3D0), width: 1.2),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Text(
                                  '${_grandTotal > 0 ? (_marginAmount / _grandTotal * 100).toStringAsFixed(0) : 10}% MARGIN RECEIVED',
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF065F46)),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF047857),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.edit, size: 10, color: Colors.white),
                                      SizedBox(width: 2),
                                      Text('Edit', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              currencyFormat.format(_marginAmount),
                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF047857)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          NumberToWordsUtils.convertToIndianRupees(_marginAmount),
                          style: const TextStyle(fontSize: 10.5, fontStyle: FontStyle.italic, color: Color(0xFF065F46)),
                        ),
                        const Divider(height: 12, color: Color(0xFFA7F3D0)),
                        Text(
                          'Payment via $_paymentMode • Ref: $_transactionRef',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF065F46)),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                // Bank Undertaking Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEFCE8),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFFEF08A)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.account_balance_outlined, size: 16, color: Color(0xFF854D0E)),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Confirmed 10% Margin Money received. Requesting Bank to disburse remaining 90% directly to SBI Betawad A/c 40662252403.',
                          style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w500, color: Color(0xFF854D0E)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 10),
              // Universal Bank Set Action Banner
              InkWell(
                onTap: _isGenerating ? null : _handleDownloadBoth,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFBFDBFE)),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.collections_bookmark_rounded, size: 15, color: Color(0xFF1D4ED8)),
                      SizedBox(width: 6),
                      Text(
                        'Download Complete Bank Set (Quotation + 10% Receipt)',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF1D4ED8)),
                      ),
                    ],
                  ),
                ),
              ),

              if (_isGenerating) ...[
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      _statusMessage ?? 'Processing...',
                      style: const TextStyle(fontSize: 11.5, color: Colors.grey),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        if (_selectedTab == 0) ...[
          // Quotation Actions (Identical to WCR)
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF0F2D69),
              side: const BorderSide(color: Color(0xFF0F2D69), width: 1.2),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
            onPressed: _isGenerating ? null : _handlePreview,
            icon: const Icon(Icons.visibility_rounded, size: 17),
            label: const Text('Preview'),
          ),
          FilledButton.tonalIcon(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF25D366).withValues(alpha: 0.15),
              foregroundColor: const Color(0xFF128C7E),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
            onPressed: _isGenerating ? null : _handleShare,
            icon: const Icon(Icons.share_rounded, size: 17),
            label: const Text('Share'),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF0F2D69),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            ),
            onPressed: _isGenerating ? null : _handleDownload,
            icon: const Icon(Icons.download_rounded, size: 17),
            label: const Text('Download'),
          ),
        ] else ...[
          // Receipt Actions (Identical to WCR)
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF047857),
              side: const BorderSide(color: Color(0xFF047857), width: 1.2),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
            onPressed: _isGenerating ? null : _handleReceiptPreview,
            icon: const Icon(Icons.visibility_rounded, size: 17),
            label: const Text('Preview'),
          ),
          FilledButton.tonalIcon(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF25D366).withValues(alpha: 0.15),
              foregroundColor: const Color(0xFF128C7E),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
            onPressed: _isGenerating ? null : _handleReceiptShare,
            icon: const Icon(Icons.share_rounded, size: 17),
            label: const Text('Share'),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF047857),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            ),
            onPressed: _isGenerating ? null : _handleReceiptDownload,
            icon: const Icon(Icons.download_rounded, size: 17),
            label: const Text('Download'),
          ),
        ],
      ],
    );
  }

  Widget _buildDetailRow(String label, String value, {bool isBold = false}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 105,
          child: Text(
            label,
            style: const TextStyle(fontSize: 11, color: Colors.grey),
          ),
        ),
        const Text(': ', style: TextStyle(fontSize: 11, color: Colors.grey)),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
              color: isBold ? const Color(0xFF0F2D69) : null,
            ),
          ),
        ),
      ],
    );
  }
}
