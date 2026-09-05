import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/lead_record.dart';
import '../services/lead_service.dart';

class MobileLeadFormScreen extends StatefulWidget {
  final LeadRecord? lead;

  const MobileLeadFormScreen({super.key, this.lead});

  @override
  State<MobileLeadFormScreen> createState() => _MobileLeadFormScreenState();
}

class _MobileLeadFormScreenState extends State<MobileLeadFormScreen> {
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
      final res = await MobileLeadService.createLead(data);
      ok = res != null;
    } else {
      ok = await MobileLeadService.updateStatus(widget.lead!.id, _leadStatus, nextFollowupDate: _nextFollowupDate);
    }

    if (mounted) {
      setState(() => _isSaving = false);
      if (ok) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.lead == null ? 'Lead created successfully!' : 'Lead updated!'),
            backgroundColor: Colors.green.shade700,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to save lead'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.lead != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? 'Edit Lead' : 'New Lead'),
        actions: [
          IconButton(
            icon: _isSaving
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.check),
            onPressed: _isSaving ? null : _save,
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Contact Details Card
            _buildCard(
              title: 'Customer Contact',
              icon: Icons.person_outline,
              children: [
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Customer Name *',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter customer name' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _mobileController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Mobile Number *',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  validator: (v) => (v == null || v.trim().length < 10) ? 'Enter 10-digit mobile' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _whatsappController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'WhatsApp Number',
                    hintText: 'Leave empty if same as mobile',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _villageController,
                        decoration: const InputDecoration(
                          labelText: 'Village / City',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
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
                  ],
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _districtController,
                  decoration: const InputDecoration(
                    labelText: 'District',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Requirements Card
            _buildCard(
              title: 'Lead Requirement',
              icon: Icons.solar_power_outlined,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: _leadSource,
                  decoration: const InputDecoration(
                    labelText: 'Lead Source',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: _sources.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                  onChanged: (v) => setState(() => _leadSource = v!),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _interestedIn,
                  decoration: const InputDecoration(
                    labelText: 'Interested In',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: _products.map((p) => DropdownMenuItem(value: p, child: Text(p))).toList(),
                  onChanged: (v) => setState(() => _interestedIn = v!),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _systemSizeController,
                  decoration: const InputDecoration(
                    labelText: 'Approx System Size (e.g. 3 kW)',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _billController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Monthly Bill (₹)',
                          prefixText: '₹ ',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextFormField(
                        controller: _budgetController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Budget (₹)',
                          prefixText: '₹ ',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _consumerNoController,
                  decoration: const InputDecoration(
                    labelText: 'Electricity Consumer No (Optional)',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Status & Follow-up
            _buildCard(
              title: 'Status & Follow-up',
              icon: Icons.calendar_today_outlined,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: _leadStatus,
                  decoration: const InputDecoration(
                    labelText: 'Lead Status',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: _statuses.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                  onChanged: (v) => setState(() => _leadStatus = v!),
                ),
                const SizedBox(height: 12),
                InkWell(
                  onTap: _pickDate,
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Next Follow-up Date',
                      prefixIcon: Icon(Icons.calendar_today),
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    child: Text(
                      _nextFollowupDate != null
                          ? DateFormat('dd/MM/yyyy').format(_nextFollowupDate!)
                          : 'Select Date',
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _assignedStaffController,
                  decoration: const InputDecoration(
                    labelText: 'Assigned Staff',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _remarksController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Notes & Remarks',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            FilledButton.icon(
              onPressed: _isSaving ? null : _save,
              icon: const Icon(Icons.check),
              label: Text(isEdit ? 'Update Lead' : 'Save New Lead'),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCard({required String title, required IconData icon, required List<Widget> children}) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  title.toUpperCase(),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 0.5),
                ),
              ],
            ),
            const Divider(height: 20),
            ...children,
          ],
        ),
      ),
    );
  }
}
