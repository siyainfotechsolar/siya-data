import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import '../models/customer_payment.dart';
import '../models/consumer_record.dart';
import '../services/payment_service.dart';
import '../services/payment_receipt_service.dart';
import '../utils/back_navigation_helper.dart';
import 'customer_search_dialog.dart';

class AddPaymentDialog extends StatefulWidget {
  final ConsumerRecord? preselectedCustomer;
  final VoidCallback? onPaymentRecorded;

  const AddPaymentDialog({
    super.key,
    this.preselectedCustomer,
    this.onPaymentRecorded,
  });

  static Future<bool?> show(
    BuildContext context, {
    ConsumerRecord? preselectedCustomer,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => AddPaymentDialog(
        preselectedCustomer: preselectedCustomer,
      ),
    );
  }

  @override
  State<AddPaymentDialog> createState() => _AddPaymentDialogState();
}

class _AddPaymentDialogState extends State<AddPaymentDialog> {
  final _formKey = GlobalKey<FormState>();

  ConsumerRecord? _selectedCustomer;
  late TextEditingController _amountCtrl;
  late TextEditingController _refCtrl;
  late TextEditingController _remarksCtrl;
  late TextEditingController _receivedByCtrl;

  String _paymentMode = PaymentMode.upi;
  String _paymentType = PaymentType.contract;
  String _additionalCategory = AdditionalPaymentCategory.extraMaterial;
  DateTime _paymentDate = DateTime.now();

  File? _attachedFile;
  ProofAnalysisResult? _proofAnalysis;
  bool _isAnalyzingProof = false;
  bool _isSaving = false;
  bool _overrideOverpayment = false;
  String? _overpaymentWarning;

  @override
  void initState() {
    super.initState();
    _selectedCustomer = widget.preselectedCustomer;
    _amountCtrl = TextEditingController();
    _refCtrl = TextEditingController();
    _remarksCtrl = TextEditingController();
    _receivedByCtrl = TextEditingController();

    _amountCtrl.addListener(_onAmountChanged);
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _refCtrl.dispose();
    _remarksCtrl.dispose();
    _receivedByCtrl.dispose();
    super.dispose();
  }

  void _onAmountChanged() {
    if (_selectedCustomer == null) return;
    if (_paymentType == PaymentType.additional) {
      if (_overpaymentWarning != null) {
        setState(() => _overpaymentWarning = null);
      }
      return;
    }
    final entered = double.tryParse(_amountCtrl.text.trim()) ?? 0.0;
    final total = _selectedCustomer!.totalAmount;
    final pending = _selectedCustomer!.pendingAmount;

    if (total > 0 && entered > pending) {
      final excess = entered - pending;
      setState(() {
        _overpaymentWarning =
            '⚠️ Entered amount exceeds pending contract balance by ₹${excess.toStringAsFixed(0)} (Pending: ₹${pending.toStringAsFixed(0)}).';
      });
    } else {
      if (_overpaymentWarning != null) {
        setState(() => _overpaymentWarning = null);
      }
    }
  }

  Future<void> _pickCustomer() async {
    final result = await showDialog<ConsumerRecord>(
      context: context,
      builder: (ctx) => const CustomerSearchDialog(),
    );
    if (result != null) {
      setState(() {
        _selectedCustomer = result;
      });
      _onAmountChanged();
    }
  }

  Future<void> _attachImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(source: source, imageQuality: 85);
      if (picked != null) {
        final file = File(picked.path);
        setState(() {
          _attachedFile = file;
          _isAnalyzingProof = true;
        });
        await _runProofAnalysis(file);
      }
    } catch (e) {
      debugPrint('Error picking image: $e');
    } finally {
      if (mounted) setState(() => _isAnalyzingProof = false);
    }
  }

  Future<void> _attachPdf() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
      );
      if (result != null && result.files.single.path != null) {
        final file = File(result.files.single.path!);
        setState(() {
          _attachedFile = file;
          _isAnalyzingProof = true;
        });
        await _runProofAnalysis(file);
      }
    } catch (e) {
      debugPrint('Error picking document: $e');
    } finally {
      if (mounted) setState(() => _isAnalyzingProof = false);
    }
  }

  Future<void> _runProofAnalysis(File file) async {
    final enteredAmt = double.tryParse(_amountCtrl.text.trim()) ?? 0.0;
    final analysis = await PaymentService.analyzeProof(
      file: file,
      enteredAmount: enteredAmt,
      enteredRefNo: _refCtrl.text.trim(),
      enteredDate: _paymentDate,
    );

    if (mounted) {
      setState(() {
        _proofAnalysis = analysis;
        // Auto-fill amount or reference if fields are empty
        if (_amountCtrl.text.isEmpty && analysis.extractedAmount != null) {
          _amountCtrl.text = analysis.extractedAmount!.toStringAsFixed(0);
        }
        if (_refCtrl.text.isEmpty && analysis.extractedRefNo != null) {
          _refCtrl.text = analysis.extractedRefNo!;
        }
      });
    }
  }

  Future<void> _submitPayment() async {
    if (_selectedCustomer == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a customer first')),
      );
      return;
    }

    if (!_formKey.currentState!.validate()) return;

    final amount = double.tryParse(_amountCtrl.text.trim());
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid amount greater than 0')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final tx = await PaymentService.recordPayment(
        customerId: _selectedCustomer!.id!,
        consumerNo: _selectedCustomer!.consumerNo,
        amount: amount,
        paymentDate: _paymentDate,
        paymentMode: _paymentMode,
        paymentType: _paymentType,
        additionalCategory: _paymentType == PaymentType.additional ? _additionalCategory : null,
        referenceNumber: _refCtrl.text.trim().isNotEmpty ? _refCtrl.text.trim() : null,
        receivedBy: _receivedByCtrl.text.trim().isNotEmpty ? _receivedByCtrl.text.trim() : null,
        remarks: _remarksCtrl.text.trim().isNotEmpty ? _remarksCtrl.text.trim() : null,
        localAttachmentPath: _attachedFile?.path,
        extractedAmount: _proofAnalysis?.extractedAmount,
        extractedDate: _proofAnalysis?.extractedDate,
        extractedRefNo: _proofAnalysis?.extractedRefNo,
        proofMismatch: _proofAnalysis?.hasMismatch ?? false,
        overrideAmountLimit: _overrideOverpayment,
      );

      widget.onPaymentRecorded?.call();

      if (mounted) {
        Navigator.pop(context, true);
        _showSuccessDialog(tx);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to record payment: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showSuccessDialog(PaymentTransaction tx) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Color(0xFF059669), size: 28),
            const SizedBox(width: 8),
            const Text('Payment Recorded!'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Payment Type: ${PaymentType.displayName(tx.paymentType)}'),
            if (tx.isAdditional && tx.additionalCategory != null)
              Text('Category: ${AdditionalPaymentCategory.displayName(tx.additionalCategory!)}'),
            Text('Amount: ₹${NumberFormat('#,##,###').format(tx.amount)}'),
            Text('Status: ${tx.syncStatus}'),
            Text('Mode: ${tx.paymentMode}'),
            const SizedBox(height: 12),
            const Text(
              'Payment has been saved locally and will synchronize automatically.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.share, size: 16),
            label: const Text('WhatsApp'),
            onPressed: () {
              Navigator.pop(ctx);
              if (_selectedCustomer != null) {
                PaymentReceiptService.shareViaWhatsApp(tx: tx, customer: _selectedCustomer!);
              }
            },
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.receipt_long, size: 16),
            label: const Text('View Receipt'),
            onPressed: () async {
              Navigator.pop(ctx);
              if (_selectedCustomer != null) {
                final file = await PaymentReceiptService.generateReceiptPdf(
                  tx: tx,
                  customer: _selectedCustomer!,
                );
                await PaymentReceiptService.openReceipt(file);
              }
            },
          ),
        ],
      ),
    );
  }

  bool _hasUnsavedChanges() {
    if (_amountCtrl.text.trim().isNotEmpty) return true;
    if (_refCtrl.text.trim().isNotEmpty) return true;
    if (_remarksCtrl.text.trim().isNotEmpty) return true;
    if (_attachedFile != null) return true;
    if (_selectedCustomer != null && _selectedCustomer != widget.preselectedCustomer) return true;
    return false;
  }

  Future<bool> _handleWillPop() async {
    if (_isSaving || _isAnalyzingProof) {
      return await BackNavigationHelper.showProcessingDialog(
        context,
        title: 'Payment in Progress',
        message: 'Payment verification or saving is currently in progress. Do you want to cancel?',
      );
    }
    if (_hasUnsavedChanges()) {
      return await BackNavigationHelper.showDiscardDialog(
        context,
        title: 'Discard Payment?',
        message: 'Entered payment details will be lost.',
      );
    }
    return true;
  }

  Future<void> _handleClose() async {
    final canClose = await _handleWillPop();
    if (canClose && mounted) {
      Navigator.of(context).pop(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final customer = _selectedCustomer;
    final total = customer?.totalAmount ?? 0.0;
    final paid = customer?.paidAmount ?? 0.0;
    final pending = customer?.pendingAmount ?? 0.0;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        await _handleClose();
      },
      child: Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        top: 20,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Modal Handle & Header
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Record Payment',
                    style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: _handleClose,
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // 1. Customer Selection Card
              InkWell(
                onTap: _pickCustomer,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.1),
                        child: Icon(Icons.person_rounded, color: theme.colorScheme.primary),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: customer == null
                            ? const Text(
                                'Select Customer *',
                                style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey),
                              )
                            : Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    customer.name,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                  ),
                                  Text(
                                    '${customer.consumerNo} • ${customer.village ?? customer.address ?? "-"}',
                                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                                  ),
                                ],
                              ),
                      ),
                      const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey),
                    ],
                  ),
                ),
              ),

              // Smart Financial Calculation Breakdown
              if (customer != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _calcColumn('Contract', '₹${NumberFormat('#,##,###').format(total)}', Colors.grey),
                      _calcColumn('Paid', '₹${NumberFormat('#,##,###').format(paid)}', const Color(0xFF059669)),
                      _calcColumn('Pending', '₹${NumberFormat('#,##,###').format(pending)}', const Color(0xFFDC2626)),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 16),

              // 2. Payment Type Selection (Contract vs Additional)
              const SizedBox(height: 16),
              const Text(
                'Payment Type *',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(
                      value: PaymentType.contract,
                      label: Text('Contract Payment', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                      icon: Icon(Icons.receipt_long_rounded, size: 16),
                    ),
                    ButtonSegment(
                      value: PaymentType.additional,
                      label: Text('Additional Payment', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                      icon: Icon(Icons.add_circle_outline_rounded, size: 16),
                    ),
                  ],
                  selected: {_paymentType},
                  onSelectionChanged: (Set<String> newSelection) {
                    setState(() {
                      _paymentType = newSelection.first;
                    });
                    _onAmountChanged();
                  },
                ),
              ),

              // 2.1 If Additional Payment: Show Category Selection
              if (_paymentType == PaymentType.additional) ...[
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  initialValue: _additionalCategory,
                  decoration: InputDecoration(
                    labelText: 'Additional Payment For *',
                    prefixIcon: Icon(AdditionalPaymentCategory.getCategoryIcon(_additionalCategory)),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    helperText: 'Extra work, material, transport, etc. (Separate from Contract)',
                  ),
                  items: AdditionalPaymentCategory.allCategories.map((cat) {
                    return DropdownMenuItem(
                      value: cat,
                      child: Row(
                        children: [
                          Icon(AdditionalPaymentCategory.getCategoryIcon(cat), size: 18),
                          const SizedBox(width: 8),
                          Text(AdditionalPaymentCategory.displayName(cat)),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => _additionalCategory = val);
                  },
                ),
              ],

              const SizedBox(height: 16),

              // 3. Amount & Payment Date
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: TextFormField(
                      controller: _amountCtrl,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Payment Amount (₹) *',
                        prefixIcon: const Icon(Icons.currency_rupee_rounded),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) return 'Required';
                        final num = double.tryParse(val.trim());
                        if (num == null || num <= 0) return 'Invalid amount';
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _paymentDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now(),
                        );
                        if (picked != null) {
                          setState(() => _paymentDate = picked);
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 15),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.calendar_today_rounded, size: 16),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                DateFormat('dd/MM/yy').format(_paymentDate),
                                style: const TextStyle(fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              // Overpayment Notice & Override Checkbox (Contract Payments only)
              if (_overpaymentWarning != null && _paymentType == PaymentType.contract) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.amber),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_overpaymentWarning!, style: const TextStyle(fontSize: 12, color: Colors.amber)),
                      Row(
                        children: [
                          Checkbox(
                            value: _overrideOverpayment,
                            onChanged: (val) => setState(() => _overrideOverpayment = val ?? false),
                          ),
                          const Expanded(
                            child: Text(
                              'Authorized Overpayment Override',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 16),

              // 4. Payment Mode
              DropdownButtonFormField<String>(
                initialValue: _paymentMode,
                decoration: InputDecoration(
                  labelText: 'Payment Mode',
                  prefixIcon: Icon(PaymentMode.getModeIcon(_paymentMode)),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                items: PaymentMode.allModes.map((mode) {
                  return DropdownMenuItem(
                    value: mode,
                    child: Text(mode),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _paymentMode = val);
                },
              ),

              const SizedBox(height: 16),

              // 4. Reference Number / UTR
              TextFormField(
                controller: _refCtrl,
                decoration: InputDecoration(
                  labelText: 'UTR / Cheque / Reference No',
                  prefixIcon: const Icon(Icons.tag_rounded),
                  hintText: 'e.g. UPI Ref, Bank Transaction ID',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),

              const SizedBox(height: 16),

              // 5. Payment Proof Attachment & OCR Scanning
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Payment Proof Attachment',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        if (_isAnalyzingProof)
                          const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (_attachedFile != null)
                      Row(
                        children: [
                          const Icon(Icons.attach_file, size: 18, color: Color(0xFF059669)),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              _attachedFile!.path.split(Platform.pathSeparator).last,
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, size: 18, color: Colors.red),
                            onPressed: () => setState(() {
                              _attachedFile = null;
                              _proofAnalysis = null;
                            }),
                          ),
                        ],
                      )
                    else
                      Row(
                        children: [
                          OutlinedButton.icon(
                            icon: const Icon(Icons.camera_alt_rounded, size: 16),
                            label: const Text('Camera'),
                            onPressed: () => _attachImage(ImageSource.camera),
                          ),
                          const SizedBox(width: 8),
                          OutlinedButton.icon(
                            icon: const Icon(Icons.photo_library_rounded, size: 16),
                            label: const Text('Gallery'),
                            onPressed: () => _attachImage(ImageSource.gallery),
                          ),
                          const SizedBox(width: 8),
                          OutlinedButton.icon(
                            icon: const Icon(Icons.picture_as_pdf_rounded, size: 16),
                            label: const Text('PDF'),
                            onPressed: _attachPdf,
                          ),
                        ],
                      ),

                    // Proof Mismatch Warning Badge
                    if (_proofAnalysis != null && _proofAnalysis!.hasMismatch) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.red),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '⚠ PAYMENT PROOF MISMATCH: ${_proofAnalysis!.mismatchReason}',
                                style: const TextStyle(fontSize: 11, color: Colors.red, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // 6. Remarks
              TextFormField(
                controller: _remarksCtrl,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: 'Remarks / Notes',
                  prefixIcon: const Icon(Icons.note_alt_outlined),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),

              const SizedBox(height: 24),

              // Submit Button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  icon: _isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Icon(Icons.save_rounded),
                  label: Text(
                    _isSaving ? 'Saving...' : 'Save Payment',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _isSaving ? null : _submitPayment,
                ),
              ),
            ],
          ),
        ),
      ),
      ),
    );
  }

  Widget _calcColumn(String label, String value, Color color) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
        const SizedBox(height: 2),
        Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }
}
