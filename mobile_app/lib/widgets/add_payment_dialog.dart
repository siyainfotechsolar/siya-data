import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/customer_payment.dart';
import '../models/consumer_record.dart';
import '../services/payment_service.dart';
import 'customer_search_dialog.dart';

class AddPaymentDialog extends StatefulWidget {
  final ConsumerRecord? preselectedCustomer;
  final double? initialAmount;
  final VoidCallback? onPaymentRecorded;

  const AddPaymentDialog({
    super.key,
    this.preselectedCustomer,
    this.initialAmount,
    this.onPaymentRecorded,
  });

  static Future<bool?> show(
    BuildContext context, {
    ConsumerRecord? preselectedCustomer,
    double? initialAmount,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => AddPaymentDialog(
        preselectedCustomer: preselectedCustomer,
        initialAmount: initialAmount,
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
  late TextEditingController _remarksCtrl;

  String _paymentMode = PaymentMode.cash;
  String _paymentType = PaymentType.contract;
  DateTime _paymentDate = DateTime.now();
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _selectedCustomer = widget.preselectedCustomer;
    _amountCtrl = TextEditingController(
      text: (widget.initialAmount != null && widget.initialAmount! > 0)
          ? widget.initialAmount!.toStringAsFixed(0)
          : '',
    );
    _remarksCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _remarksCtrl.dispose();
    super.dispose();
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
    }
  }

  Future<void> _submitPayment() async {
    if (_selectedCustomer == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a customer')),
      );
      return;
    }

    if (!_formKey.currentState!.validate()) return;

    final amount = double.tryParse(_amountCtrl.text.trim());
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid amount > 0')),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      await PaymentService.recordPayment(
        customerId: _selectedCustomer!.id!,
        consumerNo: _selectedCustomer!.consumerNo,
        amount: amount,
        paymentDate: _paymentDate,
        paymentMode: _paymentMode,
        paymentType: _paymentType,
        remarks: _remarksCtrl.text.trim().isEmpty ? null : _remarksCtrl.text.trim(),
      );

      if (mounted) {
        widget.onPaymentRecorded?.call();
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Payment of ₹${NumberFormat('#,##,###').format(amount)} recorded successfully!'),
            backgroundColor: const Color(0xFF059669),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving payment: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF059669).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.payments_rounded, color: Color(0xFF059669), size: 22),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Add Payment',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Customer Selection
              if (_selectedCustomer == null)
                InkWell(
                  onTap: _pickCustomer,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      border: Border.all(color: theme.colorScheme.primary),
                      borderRadius: BorderRadius.circular(12),
                      color: theme.colorScheme.primary.withValues(alpha: 0.05),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.person_search_rounded, color: theme.colorScheme.primary),
                        const SizedBox(width: 8),
                        Text(
                          'Select Customer *',
                          style: TextStyle(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF334155) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _selectedCustomer!.name,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                            Text(
                              _selectedCustomer!.consumerNo,
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            'Pending: ₹${NumberFormat('#,##,###').format(_selectedCustomer!.pendingAmount)}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: _selectedCustomer!.pendingAmount > 0
                                  ? const Color(0xFFDC2626)
                                  : const Color(0xFF059669),
                            ),
                          ),
                          Text(
                            'Total: ₹${NumberFormat('#,##,###').format(_selectedCustomer!.totalAmount)}',
                            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 16),

              // Payment Type (Contract vs Additional)
              Row(
                children: [
                  Expanded(
                    child: ChoiceChip(
                      label: const Center(child: Text('Contract')),
                      selected: _paymentType == PaymentType.contract,
                      selectedColor: const Color(0xFF059669).withValues(alpha: 0.2),
                      onSelected: (val) {
                        if (val) setState(() => _paymentType = PaymentType.contract);
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ChoiceChip(
                      label: const Center(child: Text('Additional')),
                      selected: _paymentType == PaymentType.additional,
                      selectedColor: const Color(0xFF8B5CF6).withValues(alpha: 0.2),
                      onSelected: (val) {
                        if (val) setState(() => _paymentType = PaymentType.additional);
                      },
                    ),
                  ),
                ],
              ),
              if (_paymentType == PaymentType.additional) ...[
                const SizedBox(height: 4),
                Text(
                  'ℹ️ Additional payment does not reduce Contract Pending.',
                  style: TextStyle(fontSize: 11, color: Colors.purple.shade600),
                ),
              ],
              // Quick Amount Suggestions
              if (_selectedCustomer != null && _selectedCustomer!.pendingAmount > 0) ...[
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    ActionChip(
                      avatar: const Icon(Icons.bolt_rounded, size: 14, color: Color(0xFF059669)),
                      label: Text(
                        'Full: ₹${NumberFormat('#,##,###').format(_selectedCustomer!.pendingAmount)}',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                      ),
                      onPressed: () {
                        setState(() {
                          _amountCtrl.text = _selectedCustomer!.pendingAmount.toStringAsFixed(0);
                        });
                      },
                    ),
                    if (_selectedCustomer!.pendingAmount >= 1000)
                      ActionChip(
                        avatar: const Icon(Icons.pie_chart_outline_rounded, size: 14, color: Color(0xFF2563EB)),
                        label: Text(
                          '50%: ₹${NumberFormat('#,##,###').format((_selectedCustomer!.pendingAmount / 2).round())}',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                        ),
                        onPressed: () {
                          setState(() {
                            _amountCtrl.text = (_selectedCustomer!.pendingAmount / 2).round().toString();
                          });
                        },
                      ),
                  ],
                ),
                const SizedBox(height: 8),
              ],

              // 1. Amount
              TextFormField(
                controller: _amountCtrl,
                keyboardType: TextInputType.number,
                autofocus: true,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                decoration: InputDecoration(
                  labelText: 'Amount (₹) *',
                  prefixText: '₹ ',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  filled: true,
                  fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) return 'Enter amount';
                  final n = double.tryParse(val.trim());
                  if (n == null || n <= 0) return 'Must be greater than 0';
                  return null;
                },
              ),
              const SizedBox(height: 14),

              // 2. Date
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
                  decoration: InputDecoration(
                    labelText: 'Date *',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    prefixIcon: const Icon(Icons.calendar_today, size: 18),
                    filled: true,
                    fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                  ),
                  child: Text(
                    DateFormat('dd MMM yyyy').format(_paymentDate),
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // 3. Payment Mode (Cash, UPI, Bank Transfer, Cheque, Other)
              DropdownButtonFormField<String>(
                value: _paymentMode,
                decoration: InputDecoration(
                  labelText: 'Payment Mode *',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  filled: true,
                  fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                ),
                items: const [
                  DropdownMenuItem(value: 'Cash', child: Text('Cash')),
                  DropdownMenuItem(value: 'UPI', child: Text('UPI')),
                  DropdownMenuItem(value: 'Bank Transfer', child: Text('Bank Transfer')),
                  DropdownMenuItem(value: 'Cheque', child: Text('Cheque')),
                  DropdownMenuItem(value: 'Other', child: Text('Other')),
                ],
                onChanged: (val) {
                  if (val != null) setState(() => _paymentMode = val);
                },
              ),
              const SizedBox(height: 14),

              // 4. Remarks
              TextFormField(
                controller: _remarksCtrl,
                decoration: InputDecoration(
                  labelText: 'Remarks',
                  hintText: 'e.g. 1st installment / cash collected on site',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  filled: true,
                  fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 20),

              // Submit Button
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  icon: _isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.check_circle_outline, size: 20),
                  label: const Text(
                    'Record Payment',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF059669),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: _isSaving ? null : _submitPayment,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
