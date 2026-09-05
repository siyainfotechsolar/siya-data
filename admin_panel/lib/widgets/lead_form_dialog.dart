import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/lead_record.dart';
import '../services/lead_service.dart';

class LeadFormDialog extends StatefulWidget {
  final LeadRecord? lead; // If null, create mode; otherwise edit mode
  final VoidCallback onSaved;

  const LeadFormDialog({super.key, this.lead, required this.onSaved});

  @override
  State<LeadFormDialog> createState() => _LeadFormDialogState();
}

class _LeadFormDialogState extends State<LeadFormDialog> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameController;
  late final TextEditingController _mobileController;
  late final TextEditingController _whatsappController;
  late final TextEditingController _villageController;
  late final TextEditingController _talukaController;
  late final TextEditingController _districtController;
  late final TextEditingController _systemSizeController;
  late final TextEditingController _billController;
  late final TextEditingController _budgetController;
  late final TextEditingController _consumerNoController;
  late final TextEditingController _assignedStaffController;
  late final TextEditingController _remarksController;

  late String _leadSource;
  late String _interestedIn;
  late String _leadStatus;
  DateTime? _nextFollowupDate;
  bool _isSaving = false;

  final List<String> _sources = [
    'Call',
    'Reference',
    'Walk-in',
    'WhatsApp',
    'Facebook',
    'Website',
    'Other',
  ];

  final List<String> _products = [
    'On-Grid',
    'Off-Grid',
    'Hybrid',
    'Solar Pump',
    'Other',
  ];

  final List<String> _statuses = [
    'New',
    'Contacted',
    'Interested',
    'Site Survey',
    'Quotation',
    'Follow-up',
    'Converted',
    'Lost',
    'No Action Required',
  ];

  @override
  void initState() {
    super.initState();
    final l = widget.lead;
    _nameController = TextEditingController(text: l?.customerName ?? '');
    _mobileController = TextEditingController(text: l?.mobileNo ?? '');
    _whatsappController = TextEditingController(text: l?.whatsappNo ?? '');
    _villageController = TextEditingController(text: l?.village ?? '');
    _talukaController = TextEditingController(text: l?.taluka ?? '');
    _districtController = TextEditingController(text: l?.district ?? '');
    _systemSizeController = TextEditingController(text: l?.approxSystemSize ?? '3 kW');
    _billController = TextEditingController(
        text: l?.monthlyElectricityBill != null ? l!.monthlyElectricityBill!.toStringAsFixed(0) : '');
    _budgetController = TextEditingController(
        text: l?.estimatedBudget != null ? l!.estimatedBudget!.toStringAsFixed(0) : '');
    _consumerNoController = TextEditingController(text: l?.consumerNo ?? '');
    _assignedStaffController = TextEditingController(text: l?.assignedStaffName ?? '');
    _remarksController = TextEditingController(text: l?.remarks ?? '');

    _leadSource = (l != null && _sources.contains(l.leadSource)) ? l.leadSource : 'Call';
    _interestedIn = (l != null && _products.contains(l.interestedIn)) ? l.interestedIn : 'On-Grid';
    _leadStatus = (l != null && _statuses.contains(l.leadStatus)) ? l.leadStatus : 'New';
    _nextFollowupDate = l?.nextFollowupDate ?? DateTime.now().add(const Duration(days: 1));
  }

  @override
  void dispose() {
    _nameController.dispose();
    _mobileController.dispose();
    _whatsappController.dispose();
    _villageController.dispose();
    _talukaController.dispose();
    _districtController.dispose();
    _systemSizeController.dispose();
    _billController.dispose();
    _budgetController.dispose();
    _consumerNoController.dispose();
    _assignedStaffController.dispose();
    _remarksController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _nextFollowupDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() => _nextFollowupDate = picked);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    final data = {
      'customer_name': _nameController.text.trim(),
      'mobile_no': _mobileController.text.trim(),
      'whatsapp_no': _whatsappController.text.trim().isEmpty ? null : _whatsappController.text.trim(),
      'village': _villageController.text.trim().isEmpty ? null : _villageController.text.trim(),
      'taluka': _talukaController.text.trim().isEmpty ? null : _talukaController.text.trim(),
      'district': _districtController.text.trim().isEmpty ? null : _districtController.text.trim(),
      'lead_source': _leadSource,
      'interested_in': _interestedIn,
      'approx_system_size': _systemSizeController.text.trim().isEmpty ? null : _systemSizeController.text.trim(),
      'monthly_electricity_bill': double.tryParse(_billController.text.trim()),
      'estimated_budget': double.tryParse(_budgetController.text.trim()),
      'consumer_no': _consumerNoController.text.trim().isEmpty ? null : _consumerNoController.text.trim(),
      'lead_status': _leadStatus,
      'next_followup_date': _nextFollowupDate?.toIso8601String().split('T')[0],
      'assigned_staff_name': _assignedStaffController.text.trim().isEmpty ? null : _assignedStaffController.text.trim(),
      'remarks': _remarksController.text.trim().isEmpty ? null : _remarksController.text.trim(),
    };

    bool ok;
    if (widget.lead == null) {
      final res = await LeadService.createLead(data);
      ok = res != null;
    } else {
      ok = await LeadService.updateLead(widget.lead!.id, data);
    }

    if (mounted) {
      setState(() => _isSaving = false);
      if (ok) {
        widget.onSaved();
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.lead == null ? 'Lead created successfully!' : 'Lead updated successfully!'),
            backgroundColor: Colors.green.shade700,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to save lead. Please check network/inputs.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isEdit = widget.lead != null;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Container(
        width: 720,
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.88),
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: theme.colorScheme.primaryContainer,
                    child: Icon(
                      isEdit ? Icons.edit_note_rounded : Icons.person_add_alt_1_rounded,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isEdit ? 'Edit Lead: ${widget.lead!.customerName}' : 'Create New Lead',
                          style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'Potential customer inquiry before entering application workflow',
                          style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const Divider(height: 24),

              // Form fields scrollable
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Customer Details Section
                      _buildSectionTitle('Customer Contact Information'),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: TextFormField(
                              controller: _nameController,
                              decoration: const InputDecoration(
                                labelText: 'Customer Name *',
                                prefixIcon: Icon(Icons.person_outline),
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                              validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter customer name' : null,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 2,
                            child: TextFormField(
                              controller: _mobileController,
                              keyboardType: TextInputType.phone,
                              decoration: const InputDecoration(
                                labelText: 'Mobile No *',
                                prefixIcon: Icon(Icons.phone_outlined),
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                              validator: (v) => (v == null || v.trim().length < 10) ? 'Enter 10-digit mobile' : null,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 2,
                            child: TextFormField(
                              controller: _whatsappController,
                              keyboardType: TextInputType.phone,
                              decoration: const InputDecoration(
                                labelText: 'WhatsApp No',
                                prefixIcon: Icon(Icons.chat_bubble_outline),
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Location Details
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _villageController,
                              decoration: const InputDecoration(
                                labelText: 'Village / City',
                                prefixIcon: Icon(Icons.location_on_outlined),
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: _talukaController,
                              decoration: const InputDecoration(
                                labelText: 'Taluka',
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: _districtController,
                              decoration: const InputDecoration(
                                labelText: 'District',
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // System & Inquiry Section
                      _buildSectionTitle('Lead Requirement & Estimates'),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              initialValue: _leadSource,
                              decoration: const InputDecoration(
                                labelText: 'Lead Source',
                                prefixIcon: Icon(Icons.campaign_outlined),
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                              items: _sources.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                              onChanged: (v) => setState(() => _leadSource = v!),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              initialValue: _interestedIn,
                              decoration: const InputDecoration(
                                labelText: 'Interested In',
                                prefixIcon: Icon(Icons.solar_power_outlined),
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                              items: _products.map((p) => DropdownMenuItem(value: p, child: Text(p))).toList(),
                              onChanged: (v) => setState(() => _interestedIn = v!),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: _systemSizeController,
                              decoration: const InputDecoration(
                                labelText: 'Approx System Size',
                                hintText: 'e.g. 3 kW',
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _billController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Monthly Electric Bill (₹)',
                                prefixText: '₹ ',
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: _budgetController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Estimated Budget (₹)',
                                prefixText: '₹ ',
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: _consumerNoController,
                              decoration: const InputDecoration(
                                labelText: 'Consumer No (Optional)',
                                hintText: 'MSEDCL 12 digits',
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Status, Staff & Follow-up
                      _buildSectionTitle('Follow-up & Assignment'),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              initialValue: _leadStatus,
                              decoration: const InputDecoration(
                                labelText: 'Lead Status',
                                prefixIcon: Icon(Icons.flag_outlined),
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                              items: _statuses.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                              onChanged: (v) => setState(() => _leadStatus = v!),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: InkWell(
                              onTap: _pickDate,
                              borderRadius: BorderRadius.circular(4),
                              child: InputDecorator(
                                decoration: const InputDecoration(
                                  labelText: 'Next Follow-up Date',
                                  prefixIcon: Icon(Icons.calendar_today_outlined),
                                  border: OutlineInputBorder(),
                                  isDense: true,
                                ),
                                child: Text(
                                  _nextFollowupDate != null
                                      ? DateFormat('dd/MM/yyyy').format(_nextFollowupDate!)
                                      : 'Select Date',
                                  style: const TextStyle(fontSize: 14),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: _assignedStaffController,
                              decoration: const InputDecoration(
                                labelText: 'Assigned Staff',
                                prefixIcon: Icon(Icons.assignment_ind_outlined),
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _remarksController,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          labelText: 'Notes & Remarks',
                          hintText: 'Customer expectations, site requirements, or discussion notes...',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const Divider(height: 24),
              // Footer actions
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _isSaving ? null : () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 12),
                  FilledButton.icon(
                    icon: _isSaving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.check),
                    label: Text(isEdit ? 'Update Lead' : 'Save New Lead'),
                    onPressed: _isSaving ? null : _save,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title.toUpperCase(),
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.bold,
        color: Colors.grey.shade700,
        letterSpacing: 0.8,
      ),
    );
  }
}
