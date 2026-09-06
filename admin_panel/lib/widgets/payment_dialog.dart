import 'package:flutter/material.dart';
import '../models/consumer_record.dart';
import '../models/customer_payment.dart';
import '../services/record_service.dart';

class PaymentDialog extends StatefulWidget {
  final ConsumerRecord customerRecord;

  const PaymentDialog({
    super.key,
    required this.customerRecord,
  });

  static Future<bool?> show(
    BuildContext context, {
    required ConsumerRecord customerRecord,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => PaymentDialog(customerRecord: customerRecord),
    );
  }

  @override
  State<PaymentDialog> createState() => _PaymentDialogState();
}

class _PaymentDialogState extends State<PaymentDialog> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _totalAmountCtrl;
  late TextEditingController _amountCtrl;
  late TextEditingController _referenceCtrl;
  late TextEditingController _receivedByCtrl;
  late TextEditingController _remarksCtrl;

  late String _selectedMode;
  DateTime _paymentDate = DateTime.now();
  DateTime? _dueDate;

  bool _isSaving = false;
  String? _overpaymentWarning;
  String? _duplicateWarning;

  @override
  void initState() {
    super.initState();
    final rec = widget.customerRecord;
    _totalAmountCtrl = TextEditingController(
      text: rec.totalAmount > 0 ? rec.totalAmount.toStringAsFixed(0) : '',
    );
    _amountCtrl = TextEditingController();
    _referenceCtrl = TextEditingController();
    _receivedByCtrl = TextEditingController(text: rec.assignedStaff ?? '');
    _remarksCtrl = TextEditingController();
    _selectedMode = PaymentMode.upi;
    _dueDate = rec.paymentDueDate;

    _amountCtrl.addListener(_validateOverpayment);
  }

  @override
  void dispose() {
    _totalAmountCtrl.dispose();
    _amountCtrl.dispose();
    _referenceCtrl.dispose();
    _receivedByCtrl.dispose();
    _remarksCtrl.dispose();
    super.dispose();
  }

  void _validateOverpayment() {
    final entered = double.tryParse(_amountCtrl.text.trim()) ?? 0.0;
    final total = double.tryParse(_totalAmountCtrl.text.trim()) ?? widget.customerRecord.totalAmount;
    final alreadyPaid = widget.customerRecord.paidAmount;

    if (total > 0 && (alreadyPaid + entered) > total) {
      final excess = (alreadyPaid + entered) - total;
      setState(() {
        _overpaymentWarning = '⚠️ Overpayment Notice: Entered ₹${entered.toStringAsFixed(0)} exceeds pending balance by ₹${excess.toStringAsFixed(0)} (Total: ₹${total.toStringAsFixed(0)}, Already Paid: ₹${alreadyPaid.toStringAsFixed(0)}).';
      });
    } else {
      if (_overpaymentWarning != null) {
        setState(() => _overpaymentWarning = null);
      }
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final amount = double.tryParse(_amountCtrl.text.trim());
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid payment amount greater than 0')),
      );
      return;
    }

    final totalAmount = double.tryParse(_totalAmountCtrl.text.trim()) ?? widget.customerRecord.totalAmount;

    // Check duplicate
    final dup = await RecordService.checkDuplicatePayment(
      customerId: widget.customerRecord.id!,
      amount: amount,
      paymentDate: _paymentDate,
      referenceNumber: _referenceCtrl.text.trim().isEmpty ? null : _referenceCtrl.text.trim(),
    );

    if (dup != null && _duplicateWarning == null) {
      setState(() {
        _duplicateWarning = '⚠️ A transaction of ₹$amount on ${_paymentDate.toIso8601String().split('T')[0]} already exists. Click "Confirm & Save" again if you are certain.';
      });
      return;
    }

    // Overpayment confirmation if applicable
    if (_overpaymentWarning != null) {
      final proceed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Confirm Overpayment'),
          content: Text(_overpaymentWarning!),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.amber.shade800),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Proceed Anyway'),
            ),
          ],
        ),
      );
      if (proceed != true) return;
    }

    setState(() => _isSaving = true);
    try {
      final tx = PaymentTransaction(
        customerId: widget.customerRecord.id!,
        consumerNo: widget.customerRecord.consumerNo,
        amount: amount,
        paymentDate: _paymentDate,
        paymentMode: _selectedMode,
        referenceNumber: _referenceCtrl.text.trim().isEmpty ? null : _referenceCtrl.text.trim(),
        receivedBy: _receivedByCtrl.text.trim().isEmpty ? null : _receivedByCtrl.text.trim(),
        remarks: _remarksCtrl.text.trim().isEmpty ? null : _remarksCtrl.text.trim(),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await RecordService.addPaymentTransaction(
        tx,
        customerTotalAmount: totalAmount > 0 ? totalAmount : null,
        paymentDueDate: _dueDate,
      );

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Payment of ₹${amount.toStringAsFixed(0)} recorded successfully!'),
            backgroundColor: const Color(0xFF059669),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to record payment: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final rec = widget.customerRecord;

    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.payments_rounded, color: Color(0xFF059669)),
          SizedBox(width: 8),
          Text('Record Customer Payment'),
        ],
      ),
      content: SizedBox(
        width: 520,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Customer & Balance summary card
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0FDF4),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFBBF7D0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${rec.name} (${rec.consumerNo})',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF166534)),
                      ),
                      const Divider(height: 14),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Total Amount', style: TextStyle(fontSize: 11, color: Color(0xFF15803D))),
                              Text('₹${rec.totalAmount.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Paid so far', style: TextStyle(fontSize: 11, color: Color(0xFF15803D))),
                              Text('₹${rec.paidAmount.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF059669))),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Pending Balance', style: TextStyle(fontSize: 11, color: Color(0xFF15803D))),
                              Text(
                                '₹${rec.pendingAmount.toStringAsFixed(0)}',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: rec.pendingAmount > 0 ? const Color(0xFFDC2626) : const Color(0xFF059669),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Overpayment warning
                if (_overpaymentWarning != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF3C7),
                      border: Border.all(color: const Color(0xFFF59E0B)),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(_overpaymentWarning!, style: const TextStyle(color: Color(0xFF92400E), fontSize: 12)),
                  ),

                // Duplicate warning
                if (_duplicateWarning != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEE2E2),
                      border: Border.all(color: const Color(0xFFDC2626)),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(_duplicateWarning!, style: const TextStyle(color: Color(0xFF991B1B), fontSize: 12)),
                  ),

                // Total Contract Amount (editable if previously 0 or correcting)
                TextFormField(
                  controller: _totalAmountCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Total Contract / System Amount (₹)',
                    border: OutlineInputBorder(),
                    isDense: true,
                    prefixText: '₹ ',
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 12),

                // Payment Amount & Date
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: TextFormField(
                        controller: _amountCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Payment Received (₹) *',
                          border: OutlineInputBorder(),
                          isDense: true,
                          prefixText: '₹ ',
                        ),
                        keyboardType: TextInputType.number,
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) return 'Amount required';
                          final n = double.tryParse(val.trim());
                          if (n == null || n <= 0) return 'Must be > 0';
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: InkWell(
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: _paymentDate,
                            firstDate: DateTime.now().subtract(const Duration(days: 365)),
                            lastDate: DateTime.now().add(const Duration(days: 30)),
                          );
                          if (picked != null) setState(() => _paymentDate = picked);
                        },
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'Payment Date *',
                            border: OutlineInputBorder(),
                            isDense: true,
                            prefixIcon: Icon(Icons.calendar_today, size: 16),
                          ),
                          child: Text(
                            '${_paymentDate.year}-${_paymentDate.month.toString().padLeft(2, '0')}-${_paymentDate.day.toString().padLeft(2, '0')}',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Payment Mode & Reference Number
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: DropdownButtonFormField<String>(
                        value: _selectedMode,
                        decoration: const InputDecoration(
                          labelText: 'Payment Mode *',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        items: PaymentMode.allModes.map((m) => DropdownMenuItem(value: m, child: Text(m, style: const TextStyle(fontSize: 13)))).toList(),
                        onChanged: (val) {
                          if (val != null) setState(() => _selectedMode = val);
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 3,
                      child: TextFormField(
                        controller: _referenceCtrl,
                        decoration: const InputDecoration(
                          labelText: 'UTR / Ref / Cheque No.',
                          hintText: 'e.g. UTR12345678',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Received By & Due Date
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _receivedByCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Received By (Staff)',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: InkWell(
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: _dueDate ?? DateTime.now().add(const Duration(days: 7)),
                            firstDate: DateTime.now().subtract(const Duration(days: 30)),
                            lastDate: DateTime.now().add(const Duration(days: 365)),
                          );
                          if (picked != null) setState(() => _dueDate = picked);
                        },
                        child: InputDecorator(
                          decoration: InputDecoration(
                            labelText: 'Next Due Date (optional)',
                            border: const OutlineInputBorder(),
                            isDense: true,
                            suffixIcon: _dueDate != null
                                ? IconButton(
                                    icon: const Icon(Icons.clear, size: 16),
                                    onPressed: () => setState(() => _dueDate = null),
                                  )
                                : null,
                          ),
                          child: Text(
                            _dueDate != null
                                ? '${_dueDate!.year}-${_dueDate!.month.toString().padLeft(2, '0')}-${_dueDate!.day.toString().padLeft(2, '0')}'
                                : 'None',
                            style: TextStyle(
                              fontSize: 12,
                              color: _dueDate != null ? Colors.black87 : Colors.grey.shade600,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Remarks
                TextFormField(
                  controller: _remarksCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Payment Remarks (optional)',
                    hintText: 'e.g. 1st installment after structure installation',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  maxLines: 1,
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          style: FilledButton.styleFrom(backgroundColor: const Color(0xFF059669)),
          onPressed: _isSaving ? null : _save,
          icon: _isSaving
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.check, size: 16),
          label: Text(_duplicateWarning != null ? 'Confirm & Save' : 'Record Payment'),
        ),
      ],
    );
  }
}
