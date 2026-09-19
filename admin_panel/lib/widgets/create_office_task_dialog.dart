import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/office_task.dart';
import '../models/consumer_record.dart';
import '../services/record_service.dart';
import '../services/office_task_service.dart';

class CreateOfficeTaskDialog extends StatefulWidget {
  final ConsumerRecord? preselectedCustomer;

  const CreateOfficeTaskDialog({
    super.key,
    this.preselectedCustomer,
  });

  static Future<OfficeTask?> show(
    BuildContext context, {
    ConsumerRecord? preselectedCustomer,
  }) {
    return showDialog<OfficeTask>(
      context: context,
      barrierDismissible: false,
      builder: (_) => CreateOfficeTaskDialog(preselectedCustomer: preselectedCustomer),
    );
  }

  @override
  State<CreateOfficeTaskDialog> createState() => _CreateOfficeTaskDialogState();
}

class _CreateOfficeTaskDialogState extends State<CreateOfficeTaskDialog> {
  final _formKey = GlobalKey<FormState>();
  ConsumerRecord? _selectedCustomer;

  final TextEditingController _customerSearchController = TextEditingController();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();

  String _selectedTaskType = OfficeTaskType.customerCall;
  String _selectedPriority = OfficeTaskPriority.normal;
  DateTime _selectedDueDate = DateTime.now().add(const Duration(days: 1));

  List<Map<String, String>> _activeOfficeStaff = [];
  String? _selectedStaffId;
  String? _selectedStaffName;
  bool _isLoadingStaff = true;
  bool _isSubmitting = false;

  List<ConsumerRecord> _customerSearchResults = [];
  bool _isSearchingCustomer = false;

  @override
  void initState() {
    super.initState();
    _selectedCustomer = widget.preselectedCustomer;
    if (_selectedCustomer != null) {
      _customerSearchController.text =
          '${_selectedCustomer!.name} (${_selectedCustomer!.consumerNo})';
      _titleController.text = '$_selectedTaskType - ${_selectedCustomer!.name}';
    } else {
      _titleController.text = '$_selectedTaskType Task';
    }
    _loadStaff();
  }

  @override
  void dispose() {
    _customerSearchController.dispose();
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _loadStaff() async {
    final staff = await OfficeTaskService.fetchActiveOfficeStaff();
    if (mounted) {
      setState(() {
        _activeOfficeStaff = staff;
        _isLoadingStaff = false;
        if (staff.isNotEmpty) {
          _selectedStaffId = staff.first['id'];
          _selectedStaffName = staff.first['name'];
        }
      });
    }
  }

  Future<void> _searchCustomers(String query) async {
    if (query.trim().length < 2) {
      setState(() => _customerSearchResults = []);
      return;
    }

    setState(() => _isSearchingCustomer = true);
    try {
      final res = await RecordService.fetchRecords(
        page: 1,
        pageSize: 8,
        searchQuery: query.trim(),
        workQueueScope: 'All',
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

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedCustomer == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please search and select a Customer.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (_selectedStaffName == null || _selectedStaffName!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select an active Office Staff member.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final task = await OfficeTaskService.createTask(
        customerId: _selectedCustomer!.id,
        customerName: _selectedCustomer!.name,
        consumerNo: _selectedCustomer!.consumerNo,
        village: _selectedCustomer!.address,
        title: _titleController.text.trim(),
        taskType: _selectedTaskType,
        description: _descriptionController.text.trim(),
        priority: _selectedPriority,
        dueDate: _selectedDueDate,
        assignedToId: _selectedStaffId,
        assignedToName: _selectedStaffName!,
      );

      if (mounted) {
        Navigator.of(context).pop(task);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to create task: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFBFDBFE)),
            ),
            child: const Icon(Icons.add_task_rounded, color: Color(0xFF2563EB), size: 22),
          ),
          const SizedBox(width: 12),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Assign Office Staff Task',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
              ),
              Text(
                'Create and assign customer task to active office staff',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ],
      ),
      content: SizedBox(
        width: 580,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // 1. Customer Search & Select
                const Text(
                  '1. CUSTOMER LINK *',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF1E40AF)),
                ),
                const SizedBox(height: 6),
                if (_selectedCustomer != null)
                  Card(
                    color: const Color(0xFFF0FDF4),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: const BorderSide(color: Color(0xFF86EFAC)),
                    ),
                    elevation: 0,
                    child: ListTile(
                      dense: true,
                      leading: const CircleAvatar(
                        radius: 16,
                        backgroundColor: Color(0xFF059669),
                        child: Icon(Icons.person, color: Colors.white, size: 18),
                      ),
                      title: Text(
                        _selectedCustomer!.name,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      subtitle: Text(
                        'Cons: ${_selectedCustomer!.consumerNo}${_selectedCustomer!.address != null ? " • ${_selectedCustomer!.address}" : ""}',
                        style: const TextStyle(fontSize: 12),
                      ),
                      trailing: TextButton(
                        onPressed: () {
                          setState(() {
                            _selectedCustomer = null;
                            _customerSearchController.clear();
                          });
                        },
                        child: const Text('Change'),
                      ),
                    ),
                  )
                else ...[
                  TextField(
                    controller: _customerSearchController,
                    onChanged: _searchCustomers,
                    decoration: InputDecoration(
                      hintText: 'Search customer name, consumer no, or mobile...',
                      prefixIcon: const Icon(Icons.search, size: 20),
                      suffixIcon: _isSearchingCustomer
                          ? const Padding(
                              padding: EdgeInsets.all(12),
                              child: SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                            )
                          : null,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                  ),
                  if (_customerSearchResults.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(top: 4),
                      constraints: const BoxConstraints(maxHeight: 180),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade300),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8),
                        ],
                      ),
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: _customerSearchResults.length,
                        itemBuilder: (ctx, i) {
                          final c = _customerSearchResults[i];
                          return ListTile(
                            dense: true,
                            title: Text(c.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                            subtitle: Text('${c.consumerNo} • ${c.address ?? ""}'),
                            trailing: const Icon(Icons.check, size: 16, color: Color(0xFF059669)),
                            onTap: () {
                              setState(() {
                                _selectedCustomer = c;
                                _customerSearchResults = [];
                                _titleController.text = '$_selectedTaskType - ${c.name}';
                              });
                            },
                          );
                        },
                      ),
                    ),
                ],
                const SizedBox(height: 16),

                // 2. Task Type & Priority Row
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: DropdownButtonFormField<String>(
                        value: _selectedTaskType,
                        decoration: InputDecoration(
                          labelText: 'Task Type *',
                          prefixIcon: Icon(OfficeTaskType.getIcon(_selectedTaskType), size: 20),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                        items: OfficeTaskType.all.map((t) {
                          return DropdownMenuItem(
                            value: t,
                            child: Text(t, style: const TextStyle(fontSize: 13)),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() {
                              _selectedTaskType = val;
                              if (_selectedCustomer != null) {
                                _titleController.text = '$val - ${_selectedCustomer!.name}';
                              } else {
                                _titleController.text = '$val Task';
                              }
                            });
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: DropdownButtonFormField<String>(
                        value: _selectedPriority,
                        decoration: InputDecoration(
                          labelText: 'Priority',
                          prefixIcon: Icon(Icons.flag_rounded, color: OfficeTaskPriority.getColor(_selectedPriority), size: 20),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                        items: OfficeTaskPriority.all.map((p) {
                          return DropdownMenuItem(
                            value: p,
                            child: Text(
                              p,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: OfficeTaskPriority.getColor(p),
                              ),
                            ),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) setState(() => _selectedPriority = val);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // 3. Task Title
                TextFormField(
                  controller: _titleController,
                  decoration: InputDecoration(
                    labelText: 'Task Title *',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Please enter a title' : null,
                ),
                const SizedBox(height: 14),

                // 4. Due Date & Assign To Office Staff Row
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: InkWell(
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: _selectedDueDate,
                            firstDate: DateTime.now().subtract(const Duration(days: 1)),
                            lastDate: DateTime.now().add(const Duration(days: 365)),
                          );
                          if (picked != null) {
                            setState(() => _selectedDueDate = picked);
                          }
                        },
                        child: InputDecorator(
                          decoration: InputDecoration(
                            labelText: 'Due Date *',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(DateFormat('dd-MM-yyyy').format(_selectedDueDate), style: const TextStyle(fontSize: 13)),
                              const Icon(Icons.calendar_today, size: 16),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 3,
                      child: _isLoadingStaff
                          ? const Center(child: CircularProgressIndicator())
                          : DropdownButtonFormField<String>(
                              value: _selectedStaffId,
                              decoration: InputDecoration(
                                labelText: 'Assign To (Office Staff) *',
                                prefixIcon: const Icon(Icons.assignment_ind_rounded, color: Color(0xFF2563EB), size: 20),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              ),
                              items: _activeOfficeStaff.map((s) {
                                return DropdownMenuItem<String>(
                                  value: s['id'],
                                  child: Row(
                                    children: [
                                      Text(s['name'] ?? 'Staff', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.blue.shade50,
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          (s['role'] ?? 'staff').replaceAll('_', ' '),
                                          style: TextStyle(fontSize: 10, color: Colors.blue.shade800),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                              onChanged: (val) {
                                if (val != null) {
                                  final staff = _activeOfficeStaff.firstWhere((s) => s['id'] == val);
                                  setState(() {
                                    _selectedStaffId = val;
                                    _selectedStaffName = staff['name'];
                                  });
                                }
                              },
                              validator: (v) => v == null ? 'Please select staff' : null,
                            ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // 5. Description / Instructions
                TextFormField(
                  controller: _descriptionController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: 'Task Instructions / Details',
                    hintText: 'e.g. Call customer, request electricity bill copy and confirm loan disbursement status.',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    contentPadding: const EdgeInsets.all(12),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF059669),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          ),
          onPressed: _isSubmitting ? null : _handleSave,
          icon: _isSubmitting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                )
              : const Icon(Icons.check_circle_rounded, size: 18),
          label: Text(_isSubmitting ? 'Assigning...' : 'Assign Task'),
        ),
      ],
    );
  }
}
