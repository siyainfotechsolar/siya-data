import 'package:flutter/material.dart';
import '../models/consumer_record.dart';
import '../models/customer_misc_action.dart';
import '../services/record_service.dart';

class MiscActionDialog extends StatefulWidget {
  final ConsumerRecord? customerRecord;
  final CustomerMiscAction? existingAction;
  final VoidCallback? onSaved;

  const MiscActionDialog({
    super.key,
    this.customerRecord,
    this.existingAction,
    this.onSaved,
  });

  static Future<bool?> show(
    BuildContext context, {
    ConsumerRecord? customerRecord,
    CustomerMiscAction? existingAction,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => MiscActionDialog(
        customerRecord: customerRecord,
        existingAction: existingAction,
      ),
    );
  }

  @override
  State<MiscActionDialog> createState() => _MiscActionDialogState();
}

class _MiscActionDialogState extends State<MiscActionDialog> {
  final _formKey = GlobalKey<FormState>();

  ConsumerRecord? _selectedCustomer;
  late TextEditingController _consumerNoCtrl;
  late TextEditingController _customerNameCtrl;
  late TextEditingController _mobileCtrl;
  late TextEditingController _descriptionCtrl;
  late TextEditingController _remarksCtrl;
  late TextEditingController _customReasonCtrl;

  String _selectedReason = CustomerMiscAction.standardReasons.first;
  String _selectedPriority = 'Medium';
  String? _assignedStaff;
  DateTime? _dueDate;
  bool _isCustomReason = false;
  bool _isLoading = false;
  String? _errorMessage;

  List<ConsumerRecord> _customerSuggestions = [];
  bool _isSearchingCustomer = false;

  final List<String> _staffList = [
    'Amol Shinde',
    'Pooja Patil',
    'Rahul Deshmukh',
    'Sachin Kadam',
    'Sunil More',
    'Staff',
  ];

  @override
  void initState() {
    super.initState();
    final action = widget.existingAction;
    final customer = widget.customerRecord;

    _selectedCustomer = customer;
    _consumerNoCtrl = TextEditingController(text: action?.consumerNo ?? customer?.consumerNo ?? '');
    _customerNameCtrl = TextEditingController(text: action?.customerName ?? customer?.name ?? '');
    _mobileCtrl = TextEditingController(text: action?.mobile ?? customer?.mobile ?? '');
    _descriptionCtrl = TextEditingController(text: action?.description ?? '');
    _remarksCtrl = TextEditingController(text: action?.remarks ?? '');
    _customReasonCtrl = TextEditingController();

    if (action != null) {
      if (CustomerMiscAction.standardReasons.contains(action.reason)) {
        _selectedReason = action.reason;
        _isCustomReason = false;
      } else {
        _selectedReason = 'Other Customer Request';
        _customReasonCtrl.text = action.reason;
        _isCustomReason = true;
      }
      _selectedPriority = action.priority;
      _assignedStaff = action.assignedStaffName;
      _dueDate = action.dueDate;
    } else {
      _dueDate = DateTime.now().add(const Duration(days: 2));
    }
  }

  @override
  void dispose() {
    _consumerNoCtrl.dispose();
    _customerNameCtrl.dispose();
    _mobileCtrl.dispose();
    _descriptionCtrl.dispose();
    _remarksCtrl.dispose();
    _customReasonCtrl.dispose();
    super.dispose();
  }

  Future<void> _searchCustomer(String query) async {
    if (query.trim().length < 2) {
      setState(() => _customerSuggestions = []);
      return;
    }
    setState(() => _isSearchingCustomer = true);
    try {
      final res = await RecordService.fetchRecords(
        page: 1,
        pageSize: 5,
        searchQuery: query.trim(),
      );
      if (mounted) {
        setState(() {
          _customerSuggestions = res.items;
          _isSearchingCustomer = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isSearchingCustomer = false);
    }
  }

  void _onCustomerPicked(ConsumerRecord c) {
    setState(() {
      _selectedCustomer = c;
      _consumerNoCtrl.text = c.consumerNo;
      _customerNameCtrl.text = c.name;
      _mobileCtrl.text = c.mobile ?? '';
      _customerSuggestions = [];
    });
  }

  String get _effectiveReason {
    if (_isCustomReason && _customReasonCtrl.text.trim().isNotEmpty) {
      return _customReasonCtrl.text.trim();
    }
    return _selectedReason;
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    final recordId = _selectedCustomer?.id ?? widget.customerRecord?.id ?? widget.existingAction?.recordId;
    if (recordId == null || recordId.isEmpty) {
      setState(() => _errorMessage = 'Please select a valid customer.');
      return;
    }

    final reason = _effectiveReason;

    // Check for duplicate active action if creating a new one
    if (widget.existingAction == null) {
      final existingDup = await RecordService.checkDuplicateMiscAction(
        recordId: recordId,
        reason: reason,
      );

      if (existingDup != null && mounted) {
        final choice = await showDialog<String>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: Color(0xFFD97706)),
                SizedBox(width: 8),
                Text('Active Action Already Exists'),
              ],
            ),
            content: Text(
              'An active MISC action with reason "$reason" already exists for ${_customerNameCtrl.text}.\n\nDo you want to create a duplicate anyway?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, 'cancel'),
                child: const Text('Cancel'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: const Color(0xFFD97706)),
                onPressed: () => Navigator.pop(ctx, 'create_anyway'),
                child: const Text('Create Duplicate Anyway'),
              ),
            ],
          ),
        );

        if (choice != 'create_anyway') return;
      }
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      if (widget.existingAction == null) {
        final newAction = CustomerMiscAction(
          recordId: recordId,
          consumerNo: _consumerNoCtrl.text.trim(),
          customerName: _customerNameCtrl.text.trim(),
          mobile: _mobileCtrl.text.trim().isEmpty ? null : _mobileCtrl.text.trim(),
          reason: reason,
          description: _descriptionCtrl.text.trim().isEmpty ? null : _descriptionCtrl.text.trim(),
          assignedStaffName: _assignedStaff,
          dueDate: _dueDate,
          priority: _selectedPriority,
          status: 'Pending',
          remarks: _remarksCtrl.text.trim().isEmpty ? null : _remarksCtrl.text.trim(),
          createdAt: DateTime.now(),
        );
        await RecordService.createMiscAction(newAction);
      } else {
        final updated = widget.existingAction!.copyWith(
          reason: reason,
          description: _descriptionCtrl.text.trim().isEmpty ? null : _descriptionCtrl.text.trim(),
          assignedStaffName: _assignedStaff,
          dueDate: _dueDate,
          priority: _selectedPriority,
          remarks: _remarksCtrl.text.trim().isEmpty ? null : _remarksCtrl.text.trim(),
        );
        await RecordService.updateMiscAction(updated);
      }

      widget.onSaved?.call();
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.toString().replaceAll('Exception: ', '');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isEditing = widget.existingAction != null;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 580, maxHeight: 720),
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title & Close
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF6366F1).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.assignment_turned_in_rounded, color: Color(0xFF6366F1), size: 22),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        isEditing ? 'Edit MISC Action' : 'Add MISC Action',
                        style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Miscellaneous customer action (outside primary workflow stages).',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
              const Divider(height: 20),

              if (_errorMessage != null)
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Text(_errorMessage!, style: const TextStyle(color: Colors.red, fontSize: 13)),
                ),

              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Customer Picker (if not preselected)
                      if (widget.customerRecord == null && widget.existingAction == null) ...[
                        const Text('Select Customer *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        const SizedBox(height: 6),
                        TextField(
                          decoration: InputDecoration(
                            hintText: 'Search customer name or consumer no...',
                            prefixIcon: const Icon(Icons.search, size: 18),
                            border: const OutlineInputBorder(),
                            isDense: true,
                            suffixIcon: _isSearchingCustomer
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: Padding(
                                      padding: EdgeInsets.all(10),
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    ),
                                  )
                                : null,
                          ),
                          onChanged: _searchCustomer,
                        ),
                        if (_customerSuggestions.isNotEmpty)
                          Container(
                            margin: const EdgeInsets.only(top: 4, bottom: 8),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey.shade300),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Column(
                              children: _customerSuggestions.map((c) {
                                return ListTile(
                                  dense: true,
                                  title: Text(c.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                                  subtitle: Text('No: ${c.consumerNo} • ${c.mobile ?? ''}'),
                                  onTap: () => _onCustomerPicked(c),
                                );
                              }).toList(),
                            ),
                          ),
                        const SizedBox(height: 12),
                      ],

                      // Customer Info (Locked)
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _customerNameCtrl,
                              readOnly: true,
                              decoration: const InputDecoration(
                                labelText: 'Customer Name',
                                border: OutlineInputBorder(),
                                isDense: true,
                                filled: true,
                              ),
                              validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextFormField(
                              controller: _consumerNoCtrl,
                              readOnly: true,
                              decoration: const InputDecoration(
                                labelText: 'Consumer No',
                                border: OutlineInputBorder(),
                                isDense: true,
                                filled: true,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Reason Dropdown
                      const Text('Action / Reason *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String>(
                        value: CustomerMiscAction.standardReasons.contains(_selectedReason)
                            ? _selectedReason
                            : CustomerMiscAction.standardReasons.first,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        items: [
                          ...CustomerMiscAction.standardReasons.map((r) => DropdownMenuItem(
                                value: r,
                                child: Text(r, style: const TextStyle(fontSize: 13)),
                              )),
                          const DropdownMenuItem(
                            value: '__custom__',
                            child: Text('+ Other (Custom Reason)', style: TextStyle(fontSize: 13, fontStyle: FontStyle.italic)),
                          ),
                        ],
                        onChanged: (val) {
                          if (val == '__custom__') {
                            setState(() => _isCustomReason = true);
                          } else if (val != null) {
                            setState(() {
                              _selectedReason = val;
                              _isCustomReason = false;
                            });
                          }
                        },
                      ),
                      if (_isCustomReason) ...[
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _customReasonCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Custom Reason *',
                            hintText: 'Enter specific miscellaneous action reason',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          validator: (v) {
                            if (_isCustomReason && (v == null || v.trim().isEmpty)) {
                              return 'Please specify custom reason';
                            }
                            return null;
                          },
                        ),
                      ],
                      const SizedBox(height: 14),

                      // Priority & Due Date
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Priority', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                const SizedBox(height: 6),
                                DropdownButtonFormField<String>(
                                  value: _selectedPriority,
                                  decoration: const InputDecoration(
                                    border: OutlineInputBorder(),
                                    isDense: true,
                                  ),
                                  items: CustomerMiscAction.standardPriorities.map((p) {
                                    return DropdownMenuItem(
                                      value: p,
                                      child: Text(p, style: const TextStyle(fontSize: 13)),
                                    );
                                  }).toList(),
                                  onChanged: (v) => setState(() => _selectedPriority = v ?? 'Medium'),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Due Date', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                const SizedBox(height: 6),
                                InkWell(
                                  onTap: () async {
                                    final picked = await showDatePicker(
                                      context: context,
                                      initialDate: _dueDate ?? DateTime.now(),
                                      firstDate: DateTime.now().subtract(const Duration(days: 30)),
                                      lastDate: DateTime.now().add(const Duration(days: 365)),
                                    );
                                    if (picked != null) {
                                      setState(() => _dueDate = picked);
                                    }
                                  },
                                  child: InputDecorator(
                                    decoration: const InputDecoration(
                                      border: OutlineInputBorder(),
                                      isDense: true,
                                      suffixIcon: Icon(Icons.calendar_today_outlined, size: 18),
                                    ),
                                    child: Text(
                                      _dueDate != null
                                          ? '${_dueDate!.day.toString().padLeft(2, '0')}/${_dueDate!.month.toString().padLeft(2, '0')}/${_dueDate!.year}'
                                          : 'Pick Due Date',
                                      style: const TextStyle(fontSize: 13),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Assigned Staff
                      const Text('Assigned Staff', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String?>(
                        value: _assignedStaff,
                        decoration: const InputDecoration(
                          hintText: 'Assign to team member (optional)',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        items: [
                          const DropdownMenuItem<String?>(
                            value: null,
                            child: Text('Unassigned', style: TextStyle(fontSize: 13, color: Colors.grey)),
                          ),
                          ..._staffList.map((s) => DropdownMenuItem<String?>(
                                value: s,
                                child: Text(s, style: const TextStyle(fontSize: 13)),
                              )),
                        ],
                        onChanged: (v) => setState(() => _assignedStaff = v),
                      ),
                      const SizedBox(height: 14),

                      // Description
                      const Text('Description', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _descriptionCtrl,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          hintText: 'Details about what needs to be done...',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Remarks
                      const Text('Remarks (Optional)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _remarksCtrl,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          hintText: 'Additional operational notes...',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const Divider(height: 24),

              // Actions
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF4F46E5),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    ),
                    onPressed: _isLoading ? null : _handleSave,
                    child: _isLoading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : Text(isEditing ? 'Save Changes' : 'Create Action'),
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
