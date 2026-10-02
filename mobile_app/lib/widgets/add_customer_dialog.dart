import 'package:flutter/material.dart';
import '../models/consumer_record.dart';
import '../services/record_service.dart';

class AddCustomerDialog extends StatefulWidget {
  final String initialSiteType;

  const AddCustomerDialog({super.key, this.initialSiteType = 'Subsidy'});

  static Future<ConsumerRecord?> show(BuildContext context, {String initialSiteType = 'Subsidy'}) {
    return showModalBottomSheet<ConsumerRecord>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => AddCustomerDialog(initialSiteType: initialSiteType),
    );
  }

  @override
  State<AddCustomerDialog> createState() => _AddCustomerDialogState();
}

class _AddCustomerDialogState extends State<AddCustomerDialog> {
  final _formKey = GlobalKey<FormState>();
  late String _siteType;

  final _nameCtrl = TextEditingController();
  final _mobileCtrl = TextEditingController();
  final _consumerNoCtrl = TextEditingController();
  final _villageCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _capacityCtrl = TextEditingController(text: '3 kW');
  final _costCtrl = TextEditingController(text: '180000');
  final _loanCtrl = TextEditingController(text: '162000');
  final _contributionCtrl = TextEditingController(text: '18000');
  final _remarksCtrl = TextEditingController();

  String _systemType = 'On-Grid';
  bool _isSaving = false;

  final List<String> _systemTypeOptions = [
    'On-Grid',
    'Off-Grid',
    'Hybrid',
    'Solar Pump',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    _siteType = widget.initialSiteType;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _mobileCtrl.dispose();
    _consumerNoCtrl.dispose();
    _villageCtrl.dispose();
    _addressCtrl.dispose();
    _capacityCtrl.dispose();
    _costCtrl.dispose();
    _loanCtrl.dispose();
    _contributionCtrl.dispose();
    _remarksCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final combinedAddress = [
        _addressCtrl.text.trim(),
        _villageCtrl.text.trim(),
      ].where((s) => s.isNotEmpty).join(', ');

      final costVal = double.tryParse(_costCtrl.text.trim()) ?? 0.0;
      final loanVal = double.tryParse(_loanCtrl.text.trim()) ?? 0.0;

      final created = await MobileRecordService.createCustomerRecord(
        name: _nameCtrl.text.trim(),
        consumerNo: _consumerNoCtrl.text.trim(),
        mobile: _mobileCtrl.text.trim().isEmpty ? null : _mobileCtrl.text.trim(),
        address: combinedAddress.isEmpty ? null : combinedAddress,
        siteType: _siteType,
        systemCapacity: _capacityCtrl.text.trim().isEmpty ? null : _capacityCtrl.text.trim(),
        systemType: _systemType,
        remarks: _remarksCtrl.text.trim().isEmpty ? null : _remarksCtrl.text.trim(),
        totalAmount: costVal > 0 ? costVal : null,
        loanSanctionedAmount: loanVal > 0 ? loanVal : null,
      );

      if (mounted) {
        setState(() => _isSaving = false);
        if (created != null) {
          Navigator.pop(context, created);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to create customer record'), backgroundColor: Colors.red),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
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
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade400,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Add Consumer',
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
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
                          setState(() {
                            _nameCtrl.clear();
                            _mobileCtrl.clear();
                            _consumerNoCtrl.clear();
                            _villageCtrl.clear();
                            _addressCtrl.clear();
                            _capacityCtrl.text = '3 kW';
                            _costCtrl.clear();
                            _loanCtrl.clear();
                            _contributionCtrl.clear();
                            _remarksCtrl.clear();
                            _systemType = 'On-Grid';
                          });
                        },
                      ),
                      const SizedBox(width: 4),
                      IconButton(
                        icon: const Icon(Icons.close),
                        visualDensity: VisualDensity.compact,
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // SITE TYPE SELECTOR
              const Text(
                'SITE TYPE',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.8, color: Colors.grey),
              ),
              const SizedBox(height: 6),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(
                    value: 'Subsidy',
                    label: Text('Subsidy'),
                    icon: Icon(Icons.verified_outlined, size: 16),
                  ),
                  ButtonSegment(
                    value: 'Non-Subsidy',
                    label: Text('Non-Subsidy'),
                    icon: Icon(Icons.bolt_outlined, size: 16),
                  ),
                ],
                selected: {_siteType},
                onSelectionChanged: (set) => setState(() => _siteType = set.first),
                style: ButtonStyle(
                  visualDensity: VisualDensity.comfortable,
                  shape: WidgetStateProperty.all(RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                ),
              ),
              const SizedBox(height: 16),

              // Customer Name
              TextFormField(
                controller: _nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Customer Name *',
                  hintText: 'Full legal name',
                  prefixIcon: Icon(Icons.person_outline),
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                textCapitalization: TextCapitalization.words,
                validator: (val) => (val == null || val.trim().isEmpty) ? 'Please enter customer name' : null,
              ),
              const SizedBox(height: 12),

              // Mobile Number
              TextFormField(
                controller: _mobileCtrl,
                decoration: const InputDecoration(
                  labelText: 'Mobile Number *',
                  hintText: '10-digit mobile number',
                  prefixIcon: Icon(Icons.phone_outlined),
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                keyboardType: TextInputType.phone,
                validator: (val) {
                  if (val == null || val.trim().isEmpty) return 'Please enter mobile number';
                  final clean = val.replaceAll(RegExp(r'\D'), '');
                  if (clean.length < 10) return 'Please enter a valid 10-digit number';
                  return null;
                },
              ),
              const SizedBox(height: 12),

              // Consumer Number
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _consumerNoCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Consumer No. *',
                        hintText: 'e.g. 012345678901',
                        prefixIcon: Icon(Icons.tag_rounded),
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      validator: (val) => (val == null || val.trim().isEmpty) ? 'Consumer No. is required' : null,
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () {
                      _consumerNoCtrl.text = 'CUS-${DateTime.now().millisecondsSinceEpoch.toString().substring(6)}';
                    },
                    child: const Text('Auto', style: TextStyle(fontSize: 12)),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Village & Address
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _villageCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Village / Town',
                        hintText: 'e.g. Shirpur',
                        prefixIcon: Icon(Icons.location_city_outlined),
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextFormField(
                      controller: _capacityCtrl,
                      decoration: const InputDecoration(
                        labelText: 'System Capacity',
                        hintText: 'e.g. 3 kW',
                        prefixIcon: Icon(Icons.solar_power_outlined),
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // System Type Dropdown
              DropdownButtonFormField<String>(
                value: _systemType,
                decoration: const InputDecoration(
                  labelText: 'System Type',
                  prefixIcon: Icon(Icons.settings_input_component_outlined),
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                items: _systemTypeOptions
                    .map((opt) => DropdownMenuItem(value: opt, child: Text(opt)))
                    .toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _systemType = val);
                },
              ),
              const SizedBox(height: 12),

              // ==========================================
              // FINANCIAL & LOAN DETAILS (मॅन्युअल / ऑटो)
              // ==========================================
              Container(
                margin: const EdgeInsets.symmetric(vertical: 4),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.currency_rupee_rounded, size: 16, color: Color(0xFF0F2D69)),
                            SizedBox(width: 4),
                            Text(
                              'Financial & Loan (Manual / Auto)',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F2D69)),
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
                              _costCtrl.clear();
                              _loanCtrl.clear();
                              _contributionCtrl.clear();
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
                        final isSelected = _capacityCtrl.text.trim() == pCap && _costCtrl.text.trim() == pCost.toString();

                        return ChoiceChip(
                          label: Text(
                            '$pCap: ₹${(pCost / 100000).toStringAsFixed(pCost % 100000 == 0 ? 0 : 1)}L',
                            style: TextStyle(fontSize: 11, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal),
                          ),
                          selected: isSelected,
                          selectedColor: const Color(0xFFFEF3C7),
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          onSelected: (_) {
                            setState(() {
                              _capacityCtrl.text = pCap;
                              _costCtrl.text = pCost.toString();
                              _loanCtrl.text = pLoan.toString();
                              _contributionCtrl.text = pContrib.toString();
                            });
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 10),

                    // Manual Inputs: Project Cost & Loan Amount
                    Row(
                      children: [
                        Expanded(
                          flex: 5,
                          child: TextFormField(
                            controller: _costCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Project Cost (Rs.)',
                              hintText: 'e.g. 180000',
                              prefixIcon: Icon(Icons.solar_power, size: 18),
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                            onChanged: (val) {
                              final cost = double.tryParse(val.trim()) ?? 0.0;
                              if (cost > 0) {
                                final loan = (cost * 0.9).roundToDouble();
                                final contrib = (cost - loan).roundToDouble();
                                _loanCtrl.text = loan.toStringAsFixed(0);
                                _contributionCtrl.text = contrib.toStringAsFixed(0);
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 5,
                          child: TextFormField(
                            controller: _loanCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Bank Loan (90%)',
                              hintText: 'e.g. 162000',
                              prefixIcon: Icon(Icons.account_balance, size: 18),
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                            onChanged: (val) {
                              final loan = double.tryParse(val.trim()) ?? 0.0;
                              if (loan > 0) {
                                final cost = (loan / 0.9).roundToDouble();
                                final contrib = (cost - loan).clamp(0.0, double.infinity);
                                _costCtrl.text = cost.toStringAsFixed(0);
                                _contributionCtrl.text = contrib.toStringAsFixed(0);
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Customer Contribution (10%)
                    TextFormField(
                      controller: _contributionCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Customer Margin / Contribution (10%)',
                        hintText: 'e.g. 18000',
                        prefixIcon: Icon(Icons.payments_outlined, size: 18),
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      onChanged: (val) {
                        final contrib = double.tryParse(val.trim()) ?? 0.0;
                        final cost = double.tryParse(_costCtrl.text.trim()) ?? 0.0;
                        if (cost > 0 && contrib >= 0) {
                          _loanCtrl.text = (cost - contrib).clamp(0.0, double.infinity).toStringAsFixed(0);
                        }
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Full Address
              TextFormField(
                controller: _addressCtrl,
                decoration: const InputDecoration(
                  labelText: 'Premise Address',
                  hintText: 'House/Street/Plot details',
                  prefixIcon: Icon(Icons.home_outlined),
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 12),

              // Field Remarks
              TextFormField(
                controller: _remarksCtrl,
                decoration: const InputDecoration(
                  labelText: 'Remarks (Optional)',
                  hintText: 'Initial visit or customer notes',
                  prefixIcon: Icon(Icons.notes_outlined),
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 20),

              // Submit Button
              FilledButton.icon(
                onPressed: _isSaving ? null : _handleSave,
                style: FilledButton.styleFrom(
                  backgroundColor: _siteType == 'Non-Subsidy' ? const Color(0xFF7C3AED) : const Color(0xFF059669),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: _isSaving
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.check_circle_outline, size: 20),
                label: Text(
                  _isSaving ? 'Creating...' : 'Create $_siteType Customer',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
