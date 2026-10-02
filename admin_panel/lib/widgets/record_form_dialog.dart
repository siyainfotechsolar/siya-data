import 'package:flutter/material.dart';
import '../models/consumer_record.dart';
import '../services/record_service.dart';

class RecordFormDialog extends StatefulWidget {
  final ConsumerRecord? initialRecord;
  final Function(ConsumerRecord)? onRecordSaved;

  const RecordFormDialog({super.key, this.initialRecord, this.onRecordSaved});

  @override
  State<RecordFormDialog> createState() => _RecordFormDialogState();
}

class _RecordFormDialogState extends State<RecordFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _consumerNoController;
  late TextEditingController _nameController;
  late TextEditingController _mobileController;
  late TextEditingController _addressController;
  late TextEditingController _applicationIdController;
  late TextEditingController _capacityController;
  late TextEditingController _systemTypeController;
  late TextEditingController _costController;
  late TextEditingController _loanController;
  late TextEditingController _contributionController;
  late TextEditingController _remarksController;
  late String _siteType;
  late String _loanRequired;
  late String _status;
  bool _isLoading = false;
  String? _errorMessage;

  final List<String> _statusOptions = [
    'Pending',
    'Approved',
    'In Progress',
    'Completed',
    'Rejected',
  ];

  @override
  void initState() {
    super.initState();
    final r = widget.initialRecord;
    _consumerNoController = TextEditingController(text: r?.consumerNo ?? '');
    _nameController = TextEditingController(text: r?.name ?? '');
    _mobileController = TextEditingController(text: r?.mobile ?? '');
    _addressController = TextEditingController(text: r?.address ?? '');
    _applicationIdController = TextEditingController(text: r?.applicationId ?? '');
    _capacityController = TextEditingController(text: r?.systemCapacity ?? '');
    _systemTypeController = TextEditingController(text: r?.systemType ?? '');
    final totalCost = r != null && r.totalAmount > 0 ? r.totalAmount : 0.0;
    _loanRequired = r?.loanRequired ?? 'No';
    final isLoan = _loanRequired.toLowerCase() == 'yes';
    final loanAmt = isLoan
        ? (r != null && r.loanSanctionedAmount > 0 ? r.loanSanctionedAmount : (totalCost > 0 ? (totalCost * 0.9).roundToDouble() : 0.0))
        : 0.0;
    final contrib = (totalCost - loanAmt).clamp(0.0, double.infinity);
    _costController = TextEditingController(text: totalCost > 0 ? totalCost.toStringAsFixed(0) : '');
    _loanController = TextEditingController(text: isLoan && loanAmt > 0 ? loanAmt.toStringAsFixed(0) : (isLoan ? '' : '0'));
    _contributionController = TextEditingController(text: contrib > 0 ? contrib.toStringAsFixed(0) : '');
    _remarksController = TextEditingController(text: r?.remarks ?? '');
    _siteType = r?.siteType ?? 'Subsidy';
    _status = r?.status ?? 'Pending';
  }

  @override
  void dispose() {
    _consumerNoController.dispose();
    _nameController.dispose();
    _mobileController.dispose();
    _addressController.dispose();
    _applicationIdController.dispose();
    _capacityController.dispose();
    _systemTypeController.dispose();
    _costController.dispose();
    _loanController.dispose();
    _contributionController.dispose();
    _remarksController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final isLoan = _loanRequired.toLowerCase() == 'yes';
      final totalCost = double.tryParse(_costController.text.trim()) ?? 0.0;
      final loanAmt = isLoan ? (double.tryParse(_loanController.text.trim()) ?? 0.0) : 0.0;

      final record = widget.initialRecord != null
          ? widget.initialRecord!.copyWith(
              consumerNo: _consumerNoController.text.trim(),
              name: _nameController.text.trim(),
              mobile: _mobileController.text.trim().isEmpty ? null : _mobileController.text.trim(),
              address: _addressController.text.trim().isEmpty ? null : _addressController.text.trim(),
              applicationId: _applicationIdController.text.trim().isEmpty ? null : _applicationIdController.text.trim(),
              siteType: _siteType,
              systemCapacity: _capacityController.text.trim().isEmpty ? null : _capacityController.text.trim(),
              systemType: _systemTypeController.text.trim().isEmpty ? null : _systemTypeController.text.trim(),
              status: _status,
              remarks: _remarksController.text.trim().isEmpty ? null : _remarksController.text.trim(),
              totalAmount: totalCost,
              loanRequired: _loanRequired,
              loanStatus: isLoan
                  ? (widget.initialRecord?.loanStatus == 'Not Required' ? 'Pending' : (widget.initialRecord?.loanStatus ?? 'Pending'))
                  : 'Not Required',
              loanSanctionedAmount: loanAmt,
            )
          : ConsumerRecord(
              consumerNo: _consumerNoController.text.trim(),
              name: _nameController.text.trim(),
              mobile: _mobileController.text.trim().isEmpty ? null : _mobileController.text.trim(),
              address: _addressController.text.trim().isEmpty ? null : _addressController.text.trim(),
              applicationId: _applicationIdController.text.trim().isEmpty ? null : _applicationIdController.text.trim(),
              siteType: _siteType,
              systemCapacity: _capacityController.text.trim().isEmpty ? null : _capacityController.text.trim(),
              systemType: _systemTypeController.text.trim().isEmpty ? null : _systemTypeController.text.trim(),
              status: _status,
              remarks: _remarksController.text.trim().isEmpty ? null : _remarksController.text.trim(),
              totalAmount: totalCost,
              loanRequired: _loanRequired,
              loanStatus: isLoan ? 'Pending' : 'Not Required',
              loanSanctionedAmount: loanAmt,
            );

      if (widget.initialRecord == null) {
        await RecordService.createRecord(record);
      } else {
        await RecordService.updateRecord(record);
      }

      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      setState(() {
        final err = e.toString();
        if (err.contains('duplicate key') || err.contains('consumer_records_consumer_no_key')) {
          _errorMessage = 'A record with Consumer No "${_consumerNoController.text.trim()}" already exists!';
        } else {
          _errorMessage = err.replaceAll('Exception: ', '');
        }
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isEdit = widget.initialRecord != null;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 580),
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    isEdit ? 'Edit Consumer' : 'Add New Consumer',
                    style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(false),
                  ),
                ],
              ),
              const Divider(height: 24),
              if (_errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline, color: theme.colorScheme.error, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: TextStyle(
                            color: theme.colorScheme.onErrorContainer,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      // Site Type & Funding / Customer Type Selection
                      Wrap(
                        spacing: 20,
                        runSpacing: 12,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text('Site: ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                              const SizedBox(width: 8),
                              SegmentedButton<String>(
                                segments: const [
                                  ButtonSegment(
                                    value: 'Subsidy',
                                    label: Text('Subsidy', style: TextStyle(fontSize: 12)),
                                    icon: Icon(Icons.verified_outlined, size: 14),
                                  ),
                                  ButtonSegment(
                                    value: 'Non-Subsidy',
                                    label: Text('Non-Subsidy', style: TextStyle(fontSize: 12)),
                                    icon: Icon(Icons.business_outlined, size: 14),
                                  ),
                                ],
                                selected: {_siteType},
                                onSelectionChanged: (val) {
                                  setState(() => _siteType = val.first);
                                },
                              ),
                            ],
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text('Customer Type: ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                              const SizedBox(width: 8),
                              SegmentedButton<String>(
                                segments: const [
                                  ButtonSegment(
                                    value: 'No',
                                    label: Text('💵 Cash Customer', style: TextStyle(fontSize: 12)),
                                    icon: Icon(Icons.payments_outlined, size: 14),
                                  ),
                                  ButtonSegment(
                                    value: 'Yes',
                                    label: Text('🏦 Bank Loan', style: TextStyle(fontSize: 12)),
                                    icon: Icon(Icons.account_balance_outlined, size: 14),
                                  ),
                                ],
                                selected: {_loanRequired},
                                onSelectionChanged: (val) {
                                  setState(() {
                                    _loanRequired = val.first;
                                    final cost = double.tryParse(_costController.text.trim()) ?? 0.0;
                                    if (_loanRequired == 'No') {
                                      _loanController.text = '0';
                                      _contributionController.text = cost > 0 ? cost.toStringAsFixed(0) : '';
                                    } else {
                                      if (cost > 0) {
                                        final loan = (cost * 0.9).roundToDouble();
                                        final contrib = (cost - loan).roundToDouble();
                                        _loanController.text = loan.toStringAsFixed(0);
                                        _contributionController.text = contrib.toStringAsFixed(0);
                                      }
                                    }
                                  });
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _consumerNoController,
                              decoration: const InputDecoration(
                                labelText: 'Consumer No *',
                                prefixIcon: Icon(Icons.tag),
                                border: OutlineInputBorder(),
                              ),
                              validator: (v) =>
                                  (v == null || v.trim().isEmpty) ? 'Required' : null,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: TextFormField(
                              controller: _applicationIdController,
                              decoration: const InputDecoration(
                                labelText: 'Application ID',
                                prefixIcon: Icon(Icons.numbers),
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                          labelText: 'Consumer Name *',
                          prefixIcon: Icon(Icons.person),
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) =>
                            (v == null || v.trim().isEmpty) ? 'Required' : null,
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _mobileController,
                              keyboardType: TextInputType.phone,
                              decoration: const InputDecoration(
                                labelText: 'Mobile Number',
                                prefixIcon: Icon(Icons.phone),
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: _status,
                              decoration: const InputDecoration(
                                labelText: 'Status',
                                prefixIcon: Icon(Icons.flag),
                                border: OutlineInputBorder(),
                              ),
                              items: _statusOptions
                                  .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                                  .toList(),
                              onChanged: (val) {
                                if (val != null) {
                                  setState(() => _status = val);
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _capacityController,
                              decoration: const InputDecoration(
                                labelText: 'System Capacity (e.g. 3 kW)',
                                prefixIcon: Icon(Icons.solar_power_outlined),
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: TextFormField(
                              controller: _systemTypeController,
                              decoration: const InputDecoration(
                                labelText: 'System Type (e.g. On-Grid)',
                                prefixIcon: Icon(Icons.settings_input_component_outlined),
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // ==========================================
                      // FINANCIAL & PAYMENT DETAILS (CASH / BANK LOAN)
                      // ==========================================
                      Builder(builder: (context) {
                        final isLoan = _loanRequired.toLowerCase() == 'yes';

                        return Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isLoan ? const Color(0xFFF8FAFC) : const Color(0xFFF0FDF4),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isLoan ? const Color(0xFFCBD5E1) : const Color(0xFF86EFAC),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        isLoan ? Icons.account_balance_rounded : Icons.payments_rounded,
                                        size: 16,
                                        color: isLoan ? const Color(0xFF0F2D69) : const Color(0xFF15803D),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        isLoan
                                            ? 'Bank Loan Financials (90% Loan + 10% Contribution)'
                                            : 'Cash Customer Financials (100% Direct Payment)',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                          color: isLoan ? const Color(0xFF0F2D69) : const Color(0xFF15803D),
                                        ),
                                      ),
                                    ],
                                  ),
                                  TextButton.icon(
                                    style: TextButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      minimumSize: Size.zero,
                                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    ),
                                    icon: const Icon(Icons.restart_alt_rounded, size: 14, color: Color(0xFFD97706)),
                                    label: const Text('Reset', style: TextStyle(fontSize: 11, color: Color(0xFFD97706), fontWeight: FontWeight.bold)),
                                    onPressed: () {
                                      setState(() {
                                        _costController.clear();
                                        _loanController.text = isLoan ? '' : '0';
                                        _contributionController.clear();
                                      });
                                    },
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),

                              // Quick Presets: 3kW=1.8L, 3.5kW=2.0L, 4kW=2.4L, 5kW=3.0L
                              Wrap(
                                spacing: 6,
                                runSpacing: 4,
                                children: [
                                  {'cap': '3 kW', 'cost': 180000, 'loan': 162000, 'contrib': 18000},
                                  {'cap': '3.5 kW', 'cost': 200000, 'loan': 180000, 'contrib': 20000},
                                  {'cap': '4 kW', 'cost': 240000, 'loan': 216000, 'contrib': 24000},
                                  {'cap': '5 kW', 'cost': 300000, 'loan': 270000, 'contrib': 30000},
                                ].map((preset) {
                                  final pCap = preset['cap'] as String;
                                  final pCost = preset['cost'] as int;
                                  final pLoan = preset['loan'] as int;
                                  final pContrib = preset['contrib'] as int;
                                  final isSelected = _capacityController.text.trim() == pCap && _costController.text.trim() == pCost.toString();

                                  return ChoiceChip(
                                    label: Text(
                                      isLoan
                                          ? '$pCap: ₹${(pCost / 100000).toStringAsFixed(pCost % 100000 == 0 ? 0 : 1)}L (Loan)'
                                          : '$pCap: ₹${(pCost / 100000).toStringAsFixed(pCost % 100000 == 0 ? 0 : 1)}L (Cash)',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                        color: isSelected ? (isLoan ? Colors.amber.shade900 : Colors.green.shade900) : null,
                                      ),
                                    ),
                                    selected: isSelected,
                                    selectedColor: isLoan ? const Color(0xFFFEF3C7) : const Color(0xFFDCFCE7),
                                    visualDensity: VisualDensity.compact,
                                    onSelected: (_) {
                                      setState(() {
                                        _capacityController.text = pCap;
                                        _costController.text = pCost.toString();
                                        if (isLoan) {
                                          _loanController.text = pLoan.toString();
                                          _contributionController.text = pContrib.toString();
                                        } else {
                                          _loanController.text = '0';
                                          _contributionController.text = pCost.toString();
                                        }
                                      });
                                    },
                                  );
                                }).toList(),
                              ),
                              const SizedBox(height: 10),

                              // Inputs
                              Row(
                                children: [
                                  Expanded(
                                    child: TextFormField(
                                      controller: _costController,
                                      keyboardType: TextInputType.number,
                                      decoration: const InputDecoration(
                                        labelText: 'Project Cost (Rs.) *',
                                        hintText: 'e.g. 180000',
                                        prefixIcon: Icon(Icons.solar_power, size: 18),
                                        border: OutlineInputBorder(),
                                        isDense: true,
                                      ),
                                      onChanged: (val) {
                                        final cost = double.tryParse(val.trim()) ?? 0.0;
                                        if (isLoan) {
                                          if (cost > 0) {
                                            final loan = (cost * 0.9).roundToDouble();
                                            final contrib = (cost - loan).roundToDouble();
                                            _loanController.text = loan.toStringAsFixed(0);
                                            _contributionController.text = contrib.toStringAsFixed(0);
                                          }
                                        } else {
                                          _loanController.text = '0';
                                          _contributionController.text = cost > 0 ? cost.toStringAsFixed(0) : '';
                                        }
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: TextFormField(
                                      controller: _loanController,
                                      readOnly: !isLoan,
                                      keyboardType: TextInputType.number,
                                      decoration: InputDecoration(
                                        labelText: isLoan ? 'Bank Loan (90%)' : 'Bank Loan (No Loan)',
                                        hintText: isLoan ? 'e.g. 162000' : '₹0',
                                        prefixIcon: Icon(
                                          isLoan ? Icons.account_balance : Icons.block,
                                          size: 18,
                                          color: isLoan ? null : Colors.grey,
                                        ),
                                        border: const OutlineInputBorder(),
                                        filled: !isLoan,
                                        fillColor: isLoan ? null : Colors.grey.shade100,
                                        isDense: true,
                                      ),
                                      onChanged: isLoan
                                          ? (val) {
                                              final loan = double.tryParse(val.trim()) ?? 0.0;
                                              if (loan > 0) {
                                                final cost = (loan / 0.9).roundToDouble();
                                                final contrib = (cost - loan).clamp(0.0, double.infinity);
                                                _costController.text = cost.toStringAsFixed(0);
                                                _contributionController.text = contrib.toStringAsFixed(0);
                                              }
                                            }
                                          : null,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: TextFormField(
                                      controller: _contributionController,
                                      keyboardType: TextInputType.number,
                                      decoration: InputDecoration(
                                        labelText: isLoan ? 'Contribution (10%)' : 'Customer Cash (100%)',
                                        hintText: isLoan ? 'e.g. 18000' : 'e.g. 180000',
                                        prefixIcon: const Icon(Icons.payments_outlined, size: 18),
                                        border: const OutlineInputBorder(),
                                        isDense: true,
                                      ),
                                      onChanged: (val) {
                                        final contrib = double.tryParse(val.trim()) ?? 0.0;
                                        final cost = double.tryParse(_costController.text.trim()) ?? 0.0;
                                        if (isLoan && cost > 0 && contrib >= 0) {
                                          _loanController.text = (cost - contrib).clamp(0.0, double.infinity).toStringAsFixed(0);
                                        } else if (!isLoan && contrib > 0) {
                                          _costController.text = contrib.toStringAsFixed(0);
                                          _loanController.text = '0';
                                        }
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      }),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _addressController,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          labelText: 'Address / Location',
                          prefixIcon: Icon(Icons.location_on_outlined),
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _remarksController,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          labelText: 'Remarks / Notes',
                          prefixIcon: Icon(Icons.note_alt_outlined),
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 12),
                  FilledButton(
                    onPressed: _isLoading ? null : _handleSave,
                    child: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : Text(isEdit ? 'Save Changes' : 'Create Record'),
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
