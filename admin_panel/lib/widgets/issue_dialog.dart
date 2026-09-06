import 'package:flutter/material.dart';
import '../models/consumer_record.dart';
import '../models/customer_issue.dart';
import '../services/record_service.dart';

class IssueDialog extends StatefulWidget {
  final ConsumerRecord? customerRecord;
  final CustomerIssue? existingIssue;

  const IssueDialog({
    super.key,
    this.customerRecord,
    this.existingIssue,
  });

  static Future<bool?> show(
    BuildContext context, {
    ConsumerRecord? customerRecord,
    CustomerIssue? existingIssue,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => IssueDialog(
        customerRecord: customerRecord,
        existingIssue: existingIssue,
      ),
    );
  }

  @override
  State<IssueDialog> createState() => _IssueDialogState();
}

class _IssueDialogState extends State<IssueDialog> {
  final _formKey = GlobalKey<FormState>();

  // Customer search & selection
  ConsumerRecord? _selectedCustomer;
  final TextEditingController _customerSearchCtrl = TextEditingController();
  List<ConsumerRecord> _customerSearchResults = [];
  bool _isSearchingCustomer = false;

  late String _selectedType;
  late TextEditingController _titleCtrl;
  late TextEditingController _descriptionCtrl;
  late TextEditingController _staffCtrl;
  late TextEditingController _remarksCtrl;
  late String _selectedPriority;
  late String _selectedStatus;
  DateTime? _selectedDueDate;

  bool _isSaving = false;
  String? _duplicateWarning;
  CustomerIssue? _existingActiveIssue;

  @override
  void initState() {
    super.initState();
    _selectedCustomer = widget.customerRecord;
    final issue = widget.existingIssue;

    _selectedType = issue?.issueType ?? IssueType.customerComplaint;
    _titleCtrl = TextEditingController(text: issue?.title ?? '');
    _descriptionCtrl = TextEditingController(text: issue?.description ?? '');
    _staffCtrl = TextEditingController(text: issue?.assignedStaff ?? '');
    _remarksCtrl = TextEditingController(text: issue?.remarks ?? '');
    _selectedPriority = issue?.priority ?? IssuePriority.normal;
    _selectedStatus = issue?.status ?? IssueStatus.newIssue;
    _selectedDueDate = issue?.dueDate;

    if (_selectedCustomer != null) {
      _customerSearchCtrl.text = '${_selectedCustomer!.name} (${_selectedCustomer!.consumerNo})';
      _checkDuplicate();
    }
  }

  @override
  void dispose() {
    _customerSearchCtrl.dispose();
    _titleCtrl.dispose();
    _descriptionCtrl.dispose();
    _staffCtrl.dispose();
    _remarksCtrl.dispose();
    super.dispose();
  }

  Future<void> _searchCustomers(String query) async {
    if (query.trim().isEmpty) {
      setState(() => _customerSearchResults = []);
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
          _customerSearchResults = res.items;
          _isSearchingCustomer = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isSearchingCustomer = false);
    }
  }

  Future<void> _checkDuplicate() async {
    if (_selectedCustomer?.id == null || widget.existingIssue != null) return;
    try {
      final dup = await RecordService.checkDuplicateIssue(
        customerId: _selectedCustomer!.id!,
        issueType: _selectedType,
      );
      if (mounted) {
        setState(() {
          _existingActiveIssue = dup;
          if (dup != null) {
            _duplicateWarning = '⚠️ Similar active issue "${dup.title}" already exists for this customer (Status: ${dup.status}).';
          } else {
            _duplicateWarning = null;
          }
        });
      }
    } catch (_) {}
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCustomer == null && widget.existingIssue == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a customer')),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      if (widget.existingIssue != null) {
        final updated = widget.existingIssue!.copyWith(
          issueType: _selectedType,
          title: _titleCtrl.text.trim(),
          description: _descriptionCtrl.text.trim().isEmpty ? null : _descriptionCtrl.text.trim(),
          priority: _selectedPriority,
          status: _selectedStatus,
          assignedStaff: _staffCtrl.text.trim().isEmpty ? null : _staffCtrl.text.trim(),
          dueDate: _selectedDueDate,
          remarks: _remarksCtrl.text.trim().isEmpty ? null : _remarksCtrl.text.trim(),
        );
        await RecordService.updateIssue(updated);
      } else {
        final newIssue = CustomerIssue(
          customerId: _selectedCustomer!.id!,
          customerName: _selectedCustomer!.name,
          consumerNo: _selectedCustomer!.consumerNo,
          mobileNumber: _selectedCustomer!.mobile,
          issueType: _selectedType,
          title: _titleCtrl.text.trim(),
          description: _descriptionCtrl.text.trim().isEmpty ? null : _descriptionCtrl.text.trim(),
          priority: _selectedPriority,
          status: _selectedStatus,
          assignedStaff: _staffCtrl.text.trim().isEmpty ? null : _staffCtrl.text.trim(),
          dueDate: _selectedDueDate,
          remarks: _remarksCtrl.text.trim().isEmpty ? null : _remarksCtrl.text.trim(),
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        await RecordService.createIssue(newIssue);
      }

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.existingIssue != null ? 'Issue updated successfully' : 'Issue created successfully'),
            backgroundColor: const Color(0xFF059669),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save issue: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.existingIssue != null;

    return AlertDialog(
      title: Row(
        children: [
          Icon(
            isEditing ? Icons.edit_note_rounded : Icons.report_problem_rounded,
            color: const Color(0xFFDC2626),
          ),
          const SizedBox(width: 8),
          Text(isEditing ? 'Edit General Issue' : 'Report General Issue'),
        ],
      ),
      content: SizedBox(
        width: 600,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Customer selector
                if (!isEditing && widget.customerRecord == null) ...[
                  const Text('Select Customer *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _customerSearchCtrl,
                    decoration: InputDecoration(
                      hintText: 'Search customer name or consumer no...',
                      prefixIcon: const Icon(Icons.search, size: 20),
                      suffixIcon: _isSearchingCustomer
                          ? const SizedBox(width: 20, height: 20, child: Padding(padding: EdgeInsets.all(8), child: CircularProgressIndicator(strokeWidth: 2)))
                          : null,
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                    onChanged: _searchCustomers,
                  ),
                  if (_customerSearchResults.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(top: 4),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      constraints: const BoxConstraints(maxHeight: 150),
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: _customerSearchResults.length,
                        itemBuilder: (ctx, i) {
                          final c = _customerSearchResults[i];
                          return ListTile(
                            dense: true,
                            title: Text(c.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text('${c.consumerNo} • ${c.mobile ?? "No phone"}'),
                            onTap: () {
                              setState(() {
                                _selectedCustomer = c;
                                _customerSearchCtrl.text = '${c.name} (${c.consumerNo})';
                                _customerSearchResults = [];
                              });
                              _checkDuplicate();
                            },
                          );
                        },
                      ),
                    ),
                  const SizedBox(height: 14),
                ] else ...[
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.person, color: Color(0xFF2563EB), size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Customer: ${_selectedCustomer?.name ?? widget.existingIssue?.customerName} (${_selectedCustomer?.consumerNo ?? widget.existingIssue?.consumerNo})',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                ],

                // Duplicate warning if any
                if (_duplicateWarning != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 14),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF3C7),
                      border: Border.all(color: const Color(0xFFF59E0B)),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _duplicateWarning!,
                          style: const TextStyle(color: Color(0xFF92400E), fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'You can continue to create another issue or update the existing active issue.',
                          style: TextStyle(color: Color(0xFF78350F), fontSize: 11),
                        ),
                      ],
                    ),
                  ),

                // Issue Type & Priority Row
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: DropdownButtonFormField<String>(
                        value: _selectedType,
                        decoration: const InputDecoration(
                          labelText: 'Issue Type *',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        items: IssueType.allTypes.map((t) => DropdownMenuItem(value: t, child: Text(t, style: const TextStyle(fontSize: 13)))).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() => _selectedType = val);
                            _checkDuplicate();
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 1,
                      child: DropdownButtonFormField<String>(
                        value: _selectedPriority,
                        decoration: const InputDecoration(
                          labelText: 'Priority *',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        items: IssuePriority.allPriorities.map((p) => DropdownMenuItem(value: p, child: Text(p, style: const TextStyle(fontSize: 13)))).toList(),
                        onChanged: (val) {
                          if (val != null) setState(() => _selectedPriority = val);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Title
                TextFormField(
                  controller: _titleCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Issue Title / Summary *',
                    hintText: 'e.g. Inverter not turning on / Incomplete net meter application',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  validator: (val) => val == null || val.trim().isEmpty ? 'Title is required' : null,
                ),
                const SizedBox(height: 14),

                // Description
                TextFormField(
                  controller: _descriptionCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Detailed Problem Description (optional)',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 14),

                // Assigned Staff & Due Date
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _staffCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Assigned Staff (optional)',
                          hintText: 'e.g. Rahul Sharma',
                          border: OutlineInputBorder(),
                          isDense: true,
                          prefixIcon: Icon(Icons.badge_outlined, size: 18),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: InkWell(
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: _selectedDueDate ?? DateTime.now().add(const Duration(days: 3)),
                            firstDate: DateTime.now().subtract(const Duration(days: 30)),
                            lastDate: DateTime.now().add(const Duration(days: 365)),
                          );
                          if (picked != null) {
                            setState(() => _selectedDueDate = picked);
                          }
                        },
                        child: InputDecorator(
                          decoration: InputDecoration(
                            labelText: 'Due Date (optional)',
                            border: const OutlineInputBorder(),
                            isDense: true,
                            prefixIcon: const Icon(Icons.calendar_today, size: 18),
                            suffixIcon: _selectedDueDate != null
                                ? IconButton(
                                    icon: const Icon(Icons.clear, size: 16),
                                    onPressed: () => setState(() => _selectedDueDate = null),
                                  )
                                : null,
                          ),
                          child: Text(
                            _selectedDueDate != null
                                ? '${_selectedDueDate!.year}-${_selectedDueDate!.month.toString().padLeft(2, '0')}-${_selectedDueDate!.day.toString().padLeft(2, '0')}'
                                : 'Select Due Date',
                            style: TextStyle(
                              fontSize: 13,
                              color: _selectedDueDate != null ? Colors.black87 : Colors.grey.shade600,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Status if editing
                if (isEditing) ...[
                  DropdownButtonFormField<String>(
                    value: _selectedStatus,
                    decoration: const InputDecoration(
                      labelText: 'Status *',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: IssueStatus.allStatuses.map((s) => DropdownMenuItem(value: s, child: Text(s, style: const TextStyle(fontSize: 13)))).toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedStatus = val);
                    },
                  ),
                  const SizedBox(height: 14),
                ],

                // Remarks
                TextFormField(
                  controller: _remarksCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Staff Remarks (optional)',
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
          style: FilledButton.styleFrom(backgroundColor: const Color(0xFFDC2626)),
          onPressed: _isSaving ? null : _save,
          icon: _isSaving
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.save, size: 16),
          label: Text(isEditing ? 'Update Issue' : 'Create Issue'),
        ),
      ],
    );
  }
}
