import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/customer_payment.dart';
import '../models/consumer_record.dart';
import '../services/payment_service.dart';
import 'customer_search_dialog.dart';

class AddPaymentDialog extends StatefulWidget {
  final ConsumerRecord? preselectedCustomer;
  final PaymentTransaction? existingPayment;
  final double? initialAmount;
  final String? initialPaymentType;
  final VoidCallback? onPaymentRecorded;

  const AddPaymentDialog({
    super.key,
    this.preselectedCustomer,
    this.existingPayment,
    this.initialAmount,
    this.initialPaymentType,
    this.onPaymentRecorded,
  });

  static Future<bool?> show(
    BuildContext context, {
    ConsumerRecord? preselectedCustomer,
    PaymentTransaction? existingPayment,
    double? initialAmount,
    String? initialPaymentType,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => AddPaymentDialog(
        preselectedCustomer: preselectedCustomer,
        existingPayment: existingPayment,
        initialAmount: initialAmount,
        initialPaymentType: initialPaymentType,
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

  late String _paymentMode;
  late String _paymentType;
  late DateTime _paymentDate;
  bool _isSaving = false;

  bool get isEditing => widget.existingPayment != null;

  @override
  void initState() {
    super.initState();
    final ep = widget.existingPayment;
    _selectedCustomer = widget.preselectedCustomer;

    if (ep != null) {
      _amountCtrl = TextEditingController(
        text: ep.amount > 0 ? ep.amount.toStringAsFixed(0) : '',
      );
      _remarksCtrl = TextEditingController(text: ep.remarks ?? '');
      _paymentMode = ep.paymentMode.isNotEmpty ? ep.paymentMode : PaymentMode.cash;
      _paymentType = ep.paymentType.isNotEmpty ? ep.paymentType : PaymentType.firstPayment;
      _paymentDate = ep.paymentDate;
    } else {
      _amountCtrl = TextEditingController(
        text: (widget.initialAmount != null && widget.initialAmount! > 0)
            ? widget.initialAmount!.toStringAsFixed(0)
            : '',
      );
      _remarksCtrl = TextEditingController();
      _paymentMode = PaymentMode.cash;

      // Smart default payment type based on customer status
      if (widget.initialPaymentType != null) {
        _paymentType = widget.initialPaymentType!;
      } else if (_selectedCustomer?.isLoanCustomer == true) {
        if (_selectedCustomer!.firstPaymentPending > 0) {
          _paymentType = PaymentType.firstPayment;
        } else if (_selectedCustomer!.secondPaymentPending > 0) {
          _paymentType = PaymentType.secondPayment;
        } else {
          _paymentType = PaymentType.firstPayment;
        }
      } else {
        _paymentType = PaymentType.firstPayment;
      }
      _paymentDate = DateTime.now();
    }
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
        if (_selectedCustomer!.isLoanCustomer) {
          if (_selectedCustomer!.firstPaymentPending > 0) {
            _paymentType = PaymentType.firstPayment;
            if (_amountCtrl.text.isEmpty) {
              _amountCtrl.text = _selectedCustomer!.firstPaymentPending.toStringAsFixed(0);
            }
          } else if (_selectedCustomer!.secondPaymentPending > 0) {
            _paymentType = PaymentType.secondPayment;
            if (_amountCtrl.text.isEmpty) {
              _amountCtrl.text = _selectedCustomer!.secondPaymentPending.toStringAsFixed(0);
            }
          }
        }
      });
    }
  }

  Future<void> _submitPayment() async {
    if (_selectedCustomer == null && widget.existingPayment == null) {
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
      if (isEditing) {
        final ep = widget.existingPayment!;
        final updatedTx = ep.copyWith(
          amount: amount,
          paymentDate: _paymentDate,
          paymentMode: _paymentMode,
          paymentType: _paymentType,
          remarks: _remarksCtrl.text.trim().isEmpty ? null : _remarksCtrl.text.trim(),
        );
        await PaymentService.updatePaymentTransaction(updatedTx: updatedTx);

        if (mounted) {
          widget.onPaymentRecorded?.call();
          Navigator.pop(context, true);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Payment updated successfully!'),
              backgroundColor: Color(0xFF059669),
            ),
          );
        }
      } else {
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

    final isLoan = _selectedCustomer?.isLoanCustomer ?? false;
    final paymentTypes = [
      PaymentType.firstPayment,
      PaymentType.secondPayment,
      PaymentType.additional,
    ];

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
                          color: const Color(0xFF059669).withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          isEditing ? Icons.edit_note_rounded : Icons.add_card_rounded,
                          color: const Color(0xFF059669),
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        isEditing ? 'Edit Payment' : 'Add Payment',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
              if (!isEditing && _selectedCustomer == null)
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
              else if (_selectedCustomer != null)
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
                              '${_selectedCustomer!.consumerNo}${isLoan ? ' • Loan Customer' : ''}',
                              style: TextStyle(
                                fontSize: 12,
                                color: isLoan ? const Color(0xFF2563EB) : Colors.grey.shade600,
                                fontWeight: isLoan ? FontWeight.bold : FontWeight.normal,
                              ),
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

              // Payment Type (1st Payment, 2nd Payment, Additional Payment)
              const Text(
                'Payment Type',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey),
              ),
              const SizedBox(height: 6),
              Row(
                children: paymentTypes.map((type) {
                  final isSelected = _paymentType == type;
                  final isAdd = type == PaymentType.additional;
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: ChoiceChip(
                        label: Center(
                          child: Text(
                            type == PaymentType.additional ? 'Additional' : type,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                              color: isSelected
                                  ? (isAdd ? Colors.purple.shade900 : const Color(0xFF065F46))
                                  : null,
                            ),
                          ),
                        ),
                        selected: isSelected,
                        selectedColor: isAdd
                            ? Colors.purple.shade100
                            : const Color(0xFFD1FAE5),
                        onSelected: (val) {
                          if (val) setState(() => _paymentType = type);
                        },
                      ),
                    ),
                  );
                }).toList(),
              ),
              if (_paymentType == PaymentType.additional) ...[
                const SizedBox(height: 6),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.purple.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.purple.shade200),
                  ),
                  child: Text(
                    'ℹ️ Additional payment does not reduce 1st/2nd Payment pending amount.',
                    style: TextStyle(fontSize: 11, color: Colors.purple.shade800),
                  ),
                ),
              ],
              const SizedBox(height: 12),

              // Quick Amount Suggestions (Strictly no percentage!)
              if (_selectedCustomer != null) ...[
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    if (isLoan && _selectedCustomer!.firstPaymentPending > 0)
                      ActionChip(
                        avatar: const Icon(Icons.payment, size: 14, color: Color(0xFF2563EB)),
                        label: Text(
                          '1st Due: ₹${NumberFormat('#,##,###').format(_selectedCustomer!.firstPaymentPending)}',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                        ),
                        onPressed: () {
                          setState(() {
                            _paymentType = PaymentType.firstPayment;
                            _amountCtrl.text = _selectedCustomer!.firstPaymentPending.toStringAsFixed(0);
                          });
                        },
                      ),
                    if (isLoan && _selectedCustomer!.secondPaymentPending > 0)
                      ActionChip(
                        avatar: const Icon(Icons.payment, size: 14, color: Color(0xFFD97706)),
                        label: Text(
                          '2nd Due: ₹${NumberFormat('#,##,###').format(_selectedCustomer!.secondPaymentPending)}',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                        ),
                        onPressed: () {
                          setState(() {
                            _paymentType = PaymentType.secondPayment;
                            _amountCtrl.text = _selectedCustomer!.secondPaymentPending.toStringAsFixed(0);
                          });
                        },
                      ),
                    if (_selectedCustomer!.pendingAmount > 0)
                      ActionChip(
                        avatar: const Icon(Icons.done_all_rounded, size: 14, color: Color(0xFF059669)),
                        label: Text(
                          'Full Pending: ₹${NumberFormat('#,##,###').format(_selectedCustomer!.pendingAmount)}',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                        ),
                        onPressed: () {
                          setState(() {
                            _amountCtrl.text = _selectedCustomer!.pendingAmount.toStringAsFixed(0);
                          });
                        },
                      ),
                  ],
                ),
                const SizedBox(height: 10),
              ],

              // 1. Amount
              TextFormField(
                controller: _amountCtrl,
                keyboardType: TextInputType.number,
                autofocus: !isEditing,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                decoration: InputDecoration(
                  labelText: 'Payment Amount (₹) *',
                  prefixText: '₹ ',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  filled: true,
                  fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) return 'Enter payment amount';
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
                    labelText: 'Payment Date *',
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
                value: PaymentMode.allModes.contains(_paymentMode) ? _paymentMode : 'Cash',
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
                  hintText: 'Enter notes or transaction details',
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
                      : Icon(isEditing ? Icons.check_circle_rounded : Icons.add_task_rounded, size: 20),
                  label: Text(
                    isEditing ? 'Update Payment' : 'Record Payment',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
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
