import 'package:flutter/material.dart';
import '../models/consumer_record.dart';
import '../models/customer_payment.dart';
import '../services/record_service.dart';

class PaymentDialog extends StatefulWidget {
  final ConsumerRecord customerRecord;
  final PaymentTransaction? existingPayment;

  const PaymentDialog({
    super.key,
    required this.customerRecord,
    this.existingPayment,
  });

  static Future<bool?> show(
    BuildContext context, {
    required ConsumerRecord customerRecord,
    PaymentTransaction? existingPayment,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => PaymentDialog(
        customerRecord: customerRecord,
        existingPayment: existingPayment,
      ),
    );
  }

  @override
  State<PaymentDialog> createState() => _PaymentDialogState();
}

class _PaymentDialogState extends State<PaymentDialog> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _amountCtrl;
  late TextEditingController _remarksCtrl;

  late String _selectedMode;
  late String _paymentType;
  late DateTime _paymentDate;

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final ep = widget.existingPayment;
    _amountCtrl = TextEditingController(
      text: ep != null ? ep.amount.toStringAsFixed(0) : '',
    );
    _remarksCtrl = TextEditingController(text: ep?.remarks ?? '');
    _selectedMode = ep != null && PaymentMode.allModes.contains(ep.paymentMode)
        ? ep.paymentMode
        : PaymentMode.cash;
    _paymentType = ep?.isAdditional == true ? PaymentType.additional : PaymentType.contract;
    _paymentDate = ep?.paymentDate ?? DateTime.now();
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _remarksCtrl.dispose();
    super.dispose();
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

    setState(() => _isSaving = true);
    try {
      final ep = widget.existingPayment;
      if (ep != null && ep.id != null) {
        // Edit existing payment
        final updatedTx = ep.copyWith(
          amount: amount,
          paymentDate: _paymentDate,
          paymentMode: _selectedMode,
          paymentType: _paymentType,
          remarks: _remarksCtrl.text.trim().isEmpty ? null : _remarksCtrl.text.trim(),
        );
        await RecordService.updatePaymentTransaction(updatedTx);
      } else {
        // Add new payment
        final tx = PaymentTransaction(
          customerId: widget.customerRecord.id!,
          consumerNo: widget.customerRecord.consumerNo,
          amount: amount,
          paymentDate: _paymentDate,
          paymentMode: _selectedMode,
          paymentType: _paymentType,
          remarks: _remarksCtrl.text.trim().isEmpty ? null : _remarksCtrl.text.trim(),
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        await RecordService.addPaymentTransaction(tx);
      }

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              ep != null
                  ? 'Payment updated successfully!'
                  : 'Payment of ₹${amount.toStringAsFixed(0)} added successfully!',
            ),
            backgroundColor: const Color(0xFF059669),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save payment: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final rec = widget.customerRecord;
    final isEdit = widget.existingPayment != null;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: const Color(0xFFECFDF5),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.payments_rounded, color: Color(0xFF059669), size: 22),
          ),
          const SizedBox(width: 10),
          Text(
            isEdit ? 'Edit Payment' : '+ Add Payment',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
        ],
      ),
      content: SizedBox(
        width: 440,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Customer Summary Banner
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              rec.name,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              rec.consumerNo,
                              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            'Pending: ₹${rec.pendingAmount.toStringAsFixed(0)}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: rec.pendingAmount > 0 ? const Color(0xFFDC2626) : const Color(0xFF059669),
                            ),
                          ),
                          Text(
                            'Total: ₹${rec.totalAmount.toStringAsFixed(0)}',
                            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Payment Type Toggle (Contract vs Additional)
                Row(
                  children: [
                    Expanded(
                      child: ChoiceChip(
                        label: const Center(child: Text('Contract Payment')),
                        selected: _paymentType == PaymentType.contract,
                        selectedColor: const Color(0xFFD1FAE5),
                        onSelected: (val) {
                          if (val) setState(() => _paymentType = PaymentType.contract);
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ChoiceChip(
                        label: const Center(child: Text('Additional Payment')),
                        selected: _paymentType == PaymentType.additional,
                        selectedColor: const Color(0xFFEDE9FE),
                        onSelected: (val) {
                          if (val) setState(() => _paymentType = PaymentType.additional);
                        },
                      ),
                    ),
                  ],
                ),
                if (_paymentType == PaymentType.additional) ...[
                  const SizedBox(height: 6),
                  Text(
                    'ℹ️ Additional payment does not reduce Contract Pending.',
                    style: TextStyle(fontSize: 11, color: Colors.purple.shade700),
                  ),
                ],
                const SizedBox(height: 14),

                // Amount
                TextFormField(
                  controller: _amountCtrl,
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: 'Amount (₹) *',
                    border: OutlineInputBorder(),
                    isDense: true,
                    prefixText: '₹ ',
                  ),
                  keyboardType: TextInputType.number,
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) return 'Amount is required';
                    final n = double.tryParse(val.trim());
                    if (n == null || n <= 0) return 'Enter a valid amount > 0';
                    return null;
                  },
                ),
                const SizedBox(height: 14),

                // Date Picker
                InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _paymentDate,
                      firstDate: DateTime.now().subtract(const Duration(days: 365)),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (picked != null) setState(() => _paymentDate = picked);
                  },
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Date *',
                      border: OutlineInputBorder(),
                      isDense: true,
                      prefixIcon: Icon(Icons.calendar_today, size: 16),
                    ),
                    child: Text(
                      '${_paymentDate.day.toString().padLeft(2, '0')}/${_paymentDate.month.toString().padLeft(2, '0')}/${_paymentDate.year}',
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // Payment Mode Dropdown
                DropdownButtonFormField<String>(
                  value: _selectedMode,
                  decoration: const InputDecoration(
                    labelText: 'Payment Mode *',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: PaymentMode.allModes.map((m) {
                    return DropdownMenuItem(
                      value: m,
                      child: Row(
                        children: [
                          Icon(PaymentMode.getModeIcon(m), size: 16, color: Colors.grey.shade700),
                          const SizedBox(width: 8),
                          Text(m, style: const TextStyle(fontSize: 13)),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedMode = val);
                  },
                ),
                const SizedBox(height: 14),

                // Remarks
                TextFormField(
                  controller: _remarksCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Remarks',
                    hintText: 'e.g. 1st installment / cash received at site',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  maxLines: 2,
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
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF059669),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          ),
          onPressed: _isSaving ? null : _save,
          icon: _isSaving
              ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.check, size: 16),
          label: Text(isEdit ? 'Save Changes' : '+ Add Payment'),
        ),
      ],
    );
  }
}
