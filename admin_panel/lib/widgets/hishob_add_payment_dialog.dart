import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/customer_hishob.dart';
import '../models/customer_payment.dart';
import '../models/invoice.dart';
import '../services/customer_hishob_service.dart';

class HishobAddPaymentDialog extends StatefulWidget {
  final CustomerHishobEntry customerEntry;
  final Invoice? preselectedInvoice;
  final PaymentTransaction? existingPaymentToEdit;
  final VoidCallback onSaved;

  const HishobAddPaymentDialog({
    super.key,
    required this.customerEntry,
    this.preselectedInvoice,
    this.existingPaymentToEdit,
    required this.onSaved,
  });

  static Future<bool?> show(
    BuildContext context, {
    required CustomerHishobEntry customerEntry,
    Invoice? preselectedInvoice,
    PaymentTransaction? existingPaymentToEdit,
    required VoidCallback onSaved,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => HishobAddPaymentDialog(
        customerEntry: customerEntry,
        preselectedInvoice: preselectedInvoice,
        existingPaymentToEdit: existingPaymentToEdit,
        onSaved: onSaved,
      ),
    );
  }

  @override
  State<HishobAddPaymentDialog> createState() => _HishobAddPaymentDialogState();
}

class _HishobAddPaymentDialogState extends State<HishobAddPaymentDialog> {
  final _formKey = GlobalKey<FormState>();
  final _inr = NumberFormat('#,##,##0', 'en_IN');

  late TextEditingController _amountCtrl;
  late TextEditingController _refCtrl;
  late TextEditingController _remarksCtrl;

  late DateTime _paymentDate;
  late String _selectedMode;
  String? _selectedInvoiceNumber;
  bool _isSaving = false;

  final List<String> _modes = [
    PaymentMode.cash,
    PaymentMode.upi,
    PaymentMode.bankTransfer,
    PaymentMode.cheque,
    PaymentMode.other,
  ];

  @override
  void initState() {
    super.initState();
    final edit = widget.existingPaymentToEdit;

    if (edit != null) {
      _amountCtrl = TextEditingController(text: edit.amount.toStringAsFixed(0));
      _refCtrl = TextEditingController(text: edit.referenceNumber ?? '');
      _remarksCtrl = TextEditingController(text: edit.remarks ?? '');
      _paymentDate = edit.paymentDate;
      _selectedMode = _modes.contains(edit.paymentMode) ? edit.paymentMode : PaymentMode.cash;
      _selectedInvoiceNumber = edit.invoiceNumber;
    } else {
      // Pre-fill pending amount of preselected invoice or customer total pending
      double defaultAmount = 0.0;
      if (widget.preselectedInvoice != null) {
        final inv = widget.preselectedInvoice!;
        _selectedInvoiceNumber = inv.invoiceNumber;
        final bal = widget.customerEntry.invoiceBalances.firstWhere(
          (b) => b.invoiceNumber == inv.invoiceNumber,
          orElse: () => InvoiceBalance(
            invoice: inv,
            totalPaid: 0,
            pendingAmount: inv.grandTotal,
            paymentStatus: 'Unpaid',
            allocatedPayments: [],
          ),
        );
        defaultAmount = bal.pendingAmount;
      } else if (widget.customerEntry.invoices.isNotEmpty) {
        // If customer has only 1 invoice, select it by default
        if (widget.customerEntry.invoices.length == 1) {
          _selectedInvoiceNumber = widget.customerEntry.invoices.first.invoiceNumber;
        }
        defaultAmount = widget.customerEntry.totalPending;
      }

      _amountCtrl = TextEditingController(
        text: defaultAmount > 0 ? defaultAmount.toStringAsFixed(0) : '',
      );
      _refCtrl = TextEditingController();
      _remarksCtrl = TextEditingController();
      _paymentDate = DateTime.now();
      _selectedMode = PaymentMode.cash;
    }
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _refCtrl.dispose();
    _remarksCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    final amount = double.tryParse(_amountCtrl.text.replaceAll(',', '').trim());
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid payment amount greater than 0')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      if (widget.existingPaymentToEdit != null) {
        // Update existing payment
        await CustomerHishobService.updatePayment(
          payment: widget.existingPaymentToEdit!,
          newAmount: amount,
          newDate: _paymentDate,
          newMode: _selectedMode,
          newInvoiceNumber: _selectedInvoiceNumber,
          newRef: _refCtrl.text.trim(),
          newRemarks: _remarksCtrl.text.trim(),
        );
      } else {
        // Record new payment with duplicate validation
        await CustomerHishobService.recordPayment(
          customerId: widget.customerEntry.customerId,
          consumerNo: widget.customerEntry.consumerNo,
          customerName: widget.customerEntry.customerName,
          amount: amount,
          paymentDate: _paymentDate,
          paymentMode: _selectedMode,
          invoiceNumber: _selectedInvoiceNumber,
          referenceNumber: _refCtrl.text.trim(),
          remarks: _remarksCtrl.text.trim(),
        );
      }

      if (mounted) {
        widget.onSaved();
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.existingPaymentToEdit != null
                  ? 'Payment updated successfully!'
                  : 'Payment of ₹${_inr.format(amount)} recorded successfully!',
            ),
            backgroundColor: const Color(0xFF059669),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save payment: $e'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existingPaymentToEdit != null;
    final invoices = widget.customerEntry.invoices;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
      contentPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFECFDF5),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.account_balance_wallet_rounded, color: Color(0xFF059669), size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isEdit ? 'Edit Payment' : 'Record Customer Payment',
                  style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Text(
                  '${widget.customerEntry.customerName} (${widget.customerEntry.consumerNo})',
                  style: GoogleFonts.inter(fontSize: 12, color: Colors.grey.shade600),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 480,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Info Banner
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(top: 8, bottom: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0FDF4),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFBBF7D0)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, size: 18, color: Color(0xFF059669)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Total Invoices: ₹${_inr.format(widget.customerEntry.totalAmount)}  |  Total Pending: ₹${_inr.format(widget.customerEntry.totalPending)}',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF166534),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Invoice Linking Dropdown
                Text(
                  'Invoice Number',
                  style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF374151)),
                ),
                const SizedBox(height: 6),
                DropdownButtonFormField<String?>(
                  initialValue: _selectedInvoiceNumber,
                  isExpanded: true,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.receipt_long_rounded, size: 20),
                    hintText: 'Select Invoice or General Payment',
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('General Account Payment (Unlinked)'),
                    ),
                    ...invoices.map((inv) {
                      return DropdownMenuItem<String?>(
                        value: inv.invoiceNumber,
                        child: Text(
                          '${inv.invoiceNumber} (₹${_inr.format(inv.grandTotal)}) — ${inv.paymentStatus}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }),
                  ],
                  onChanged: (val) {
                    setState(() {
                      _selectedInvoiceNumber = val;
                      if (val != null) {
                        final matched = widget.customerEntry.invoiceBalances.firstWhere(
                          (b) => b.invoiceNumber == val,
                          orElse: () => InvoiceBalance(
                            invoice: invoices.firstWhere((i) => i.invoiceNumber == val),
                            totalPaid: 0,
                            pendingAmount: 0,
                            paymentStatus: 'Unpaid',
                            allocatedPayments: [],
                          ),
                        );
                        if (matched.pendingAmount > 0) {
                          _amountCtrl.text = matched.pendingAmount.toStringAsFixed(0);
                        }
                      }
                    });
                  },
                ),
                const SizedBox(height: 14),

                // Amount Field
                Text(
                  'Payment Amount (₹) *',
                  style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF374151)),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _amountCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.currency_rupee, size: 20),
                    hintText: 'e.g. 50000',
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) return 'Amount is required';
                    final n = double.tryParse(val.replaceAll(',', '').trim());
                    if (n == null || n <= 0) return 'Enter a valid amount > 0';
                    return null;
                  },
                ),
                const SizedBox(height: 14),

                // Payment Date & Mode Row
                Row(
                  children: [
                    // Payment Date
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Payment Date *',
                            style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF374151)),
                          ),
                          const SizedBox(height: 6),
                          InkWell(
                            onTap: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: _paymentDate,
                                firstDate: DateTime(2020),
                                lastDate: DateTime.now().add(const Duration(days: 30)),
                              );
                              if (picked != null) {
                                setState(() => _paymentDate = picked);
                              }
                            },
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey.shade400),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.calendar_today_rounded, size: 18, color: Color(0xFF6B7280)),
                                  const SizedBox(width: 8),
                                  Text(
                                    '${_paymentDate.day.toString().padLeft(2, '0')}/${_paymentDate.month.toString().padLeft(2, '0')}/${_paymentDate.year}',
                                    style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Payment Mode
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Payment Mode *',
                            style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF374151)),
                          ),
                          const SizedBox(height: 6),
                          DropdownButtonFormField<String>(
                            initialValue: _selectedMode,
                            decoration: InputDecoration(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            items: _modes.map((m) {
                              return DropdownMenuItem<String>(
                                value: m,
                                child: Row(
                                  children: [
                                    Icon(PaymentMode.getIcon(m), size: 16, color: const Color(0xFF059669)),
                                    const SizedBox(width: 8),
                                    Text(m, style: GoogleFonts.inter(fontSize: 13)),
                                  ],
                                ),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) setState(() => _selectedMode = val);
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Transaction Reference
                Text(
                  'Transaction Reference / UTR / Cheque No',
                  style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF374151)),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _refCtrl,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.tag_rounded, size: 20),
                    hintText: 'e.g. UPI-1234567890 / CHQ-889922',
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                const SizedBox(height: 14),

                // Remarks / Notes
                Text(
                  'Remarks',
                  style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF374151)),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _remarksCtrl,
                  maxLines: 2,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.notes_rounded, size: 20),
                    hintText: 'Optional notes or receipt details...',
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.pop(context, false),
          child: Text('Cancel', style: GoogleFonts.inter(color: Colors.grey.shade700)),
        ),
        ElevatedButton(
          onPressed: _isSaving ? null : _handleSave,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF059669),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          child: _isSaving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                )
              : Text(
                  isEdit ? 'Update Payment' : 'Save Payment',
                  style: GoogleFonts.inter(fontWeight: FontWeight.bold),
                ),
        ),
      ],
    );
  }
}
