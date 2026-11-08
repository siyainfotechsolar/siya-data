import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:siya_shared/siya_shared.dart';
import '../services/sub_vendor_service.dart';
import '../services/sub_vendor_pdf_service.dart';
import '../services/record_service.dart';

final _currency = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 2);
final _dateFormat = DateFormat('dd-MM-yyyy');

// ==============================================================================
// 1. ADD / EDIT SUB-VENDOR DIALOG (ADMIN)
// ==============================================================================

class AddEditSubVendorDialog extends StatefulWidget {
  final SubVendor? vendor;
  const AddEditSubVendorDialog({super.key, this.vendor});

  @override
  State<AddEditSubVendorDialog> createState() => _AddEditSubVendorDialogState();
}

class _AddEditSubVendorDialogState extends State<AddEditSubVendorDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _codeCtrl;
  late final TextEditingController _nameCtrl;
  late final TextEditingController _contactCtrl;
  late final TextEditingController _mobileCtrl;
  late final TextEditingController _emailCtrl;
  late final TextEditingController _passwordCtrl;
  late final TextEditingController _rateCtrl;
  late final TextEditingController _addressCtrl;
  late final TextEditingController _panCtrl;
  late final TextEditingController _gstCtrl;
  late final TextEditingController _bankNameCtrl;
  late final TextEditingController _accountNoCtrl;
  late final TextEditingController _ifscCtrl;
  late final TextEditingController _upiCtrl;
  late final TextEditingController _notesCtrl;

  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    final v = widget.vendor;
    _codeCtrl = TextEditingController(text: v?.vendorCode ?? '');
    _nameCtrl = TextEditingController(text: v?.name ?? '');
    _contactCtrl = TextEditingController(text: v?.contactPerson ?? '');
    _mobileCtrl = TextEditingController(text: v?.mobile ?? '');
    _emailCtrl = TextEditingController(text: v?.email ?? '');
    _passwordCtrl = TextEditingController(text: v == null ? 'Siya@2026' : '');
    _rateCtrl = TextEditingController(text: v != null ? v.defaultRatePerKw.toStringAsFixed(0) : '1000');
    _addressCtrl = TextEditingController(text: v?.address ?? '');
    _panCtrl = TextEditingController(text: v?.panNumber ?? '');
    _gstCtrl = TextEditingController(text: v?.gstNumber ?? '');
    _bankNameCtrl = TextEditingController(text: v?.bankName ?? '');
    _accountNoCtrl = TextEditingController(text: v?.accountNumber ?? '');
    _ifscCtrl = TextEditingController(text: v?.ifscCode ?? '');
    _upiCtrl = TextEditingController(text: v?.upiId ?? '');
    _notesCtrl = TextEditingController(text: v?.notes ?? '');
  }

  @override
  void dispose() {
    _codeCtrl.dispose();
    _nameCtrl.dispose();
    _contactCtrl.dispose();
    _mobileCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _rateCtrl.dispose();
    _addressCtrl.dispose();
    _panCtrl.dispose();
    _gstCtrl.dispose();
    _bankNameCtrl.dispose();
    _accountNoCtrl.dispose();
    _ifscCtrl.dispose();
    _upiCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      if (widget.vendor == null) {
        // Create new vendor
        await SubVendorService.createVendor(
          vendorCode: _codeCtrl.text.trim().isEmpty ? 'SIYA-VND' : _codeCtrl.text.trim(),
          name: _nameCtrl.text.trim(),
          mobile: _mobileCtrl.text.trim(),
          password: _passwordCtrl.text.trim(),
          contactPerson: _contactCtrl.text.trim(),
          email: _emailCtrl.text.trim(),
          address: _addressCtrl.text.trim(),
          panNumber: _panCtrl.text.trim(),
          gstNumber: _gstCtrl.text.trim(),
          bankName: _bankNameCtrl.text.trim(),
          accountNumber: _accountNoCtrl.text.trim(),
          ifscCode: _ifscCtrl.text.trim(),
          upiId: _upiCtrl.text.trim(),
          defaultRatePerKw: double.tryParse(_rateCtrl.text.trim()) ?? 1000.0,
          notes: _notesCtrl.text.trim(),
        );
      } else {
        // Update existing vendor
        final updated = widget.vendor!.copyWith(
          vendorCode: _codeCtrl.text.trim(),
          name: _nameCtrl.text.trim(),
          contactPerson: _contactCtrl.text.trim(),
          mobile: _mobileCtrl.text.trim(),
          email: _emailCtrl.text.trim(),
          address: _addressCtrl.text.trim(),
          panNumber: _panCtrl.text.trim(),
          gstNumber: _gstCtrl.text.trim(),
          bankName: _bankNameCtrl.text.trim(),
          accountNumber: _accountNoCtrl.text.trim(),
          ifscCode: _ifscCtrl.text.trim(),
          upiId: _upiCtrl.text.trim(),
          defaultRatePerKw: double.tryParse(_rateCtrl.text.trim()) ?? 1000.0,
          notes: _notesCtrl.text.trim(),
        );
        await SubVendorService.updateVendor(updated);
      }

      if (mounted) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.vendor == null
                ? 'Sub-Vendor account created successfully!'
                : 'Sub-Vendor updated successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isNew = widget.vendor == null;
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        isNew ? 'Create Sub-Vendor Account' : 'Edit Sub-Vendor Details',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                  const Divider(),
                  const SizedBox(height: 12),
                  const Text('1. BASIC & LOGIN CREDENTIALS',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.blueGrey)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _nameCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Vendor Name / Agency Name *',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.business),
                          ),
                          validator: (v) => v?.trim().isEmpty == true ? 'Required' : null,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _codeCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Vendor Code (e.g. SIYA-VND-101)',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.tag),
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
                          controller: _mobileCtrl,
                          keyboardType: TextInputType.phone,
                          decoration: const InputDecoration(
                            labelText: 'Mobile Number (Login Username) *',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.phone),
                          ),
                          validator: (v) => (v == null || v.trim().length < 10) ? 'Enter 10-digit mobile' : null,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _contactCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Contact Person Name',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.person),
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
                          controller: _emailCtrl,
                          keyboardType: TextInputType.emailAddress,
                          decoration: const InputDecoration(
                            labelText: 'Email Address (Optional)',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.email),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      if (isNew)
                        Expanded(
                          child: TextFormField(
                            controller: _passwordCtrl,
                            obscureText: _obscurePassword,
                            decoration: InputDecoration(
                              labelText: 'Initial Password *',
                              border: const OutlineInputBorder(),
                              prefixIcon: const Icon(Icons.lock),
                              suffixIcon: IconButton(
                                icon: Icon(_obscurePassword ? Icons.visibility : Icons.visibility_off),
                                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                              ),
                            ),
                            validator: (v) => (v == null || v.trim().length < 6) ? 'Min 6 characters' : null,
                          ),
                        )
                      else
                        Expanded(
                          child: TextFormField(
                            controller: _rateCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Default Rate (₹/kW) *',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.currency_rupee),
                            ),
                          ),
                        ),
                    ],
                  ),
                  if (isNew) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _rateCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Default SIYA Vendor Charge (₹/kW) *',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.currency_rupee),
                              helperText: 'Default rate is ₹1,000/kW',
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _panCtrl,
                            decoration: const InputDecoration(
                              labelText: 'PAN Number',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 16),
                  const Text('2. BANKING & STATUTORY DETAILS',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.blueGrey)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _bankNameCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Bank Name',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _accountNoCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Account Number',
                            border: OutlineInputBorder(),
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
                          controller: _ifscCtrl,
                          decoration: const InputDecoration(
                            labelText: 'IFSC Code',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _upiCtrl,
                          decoration: const InputDecoration(
                            labelText: 'UPI ID (Optional)',
                            border: OutlineInputBorder(),
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
                          controller: _gstCtrl,
                          decoration: const InputDecoration(
                            labelText: 'GST Number (Optional)',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _addressCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Workshop / Office Address',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _notesCtrl,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Notes / Remarks',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        onPressed: _isLoading ? null : _handleSave,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0D2B6F),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : Text(isNew ? 'Create Sub-Vendor' : 'Save Changes'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ==============================================================================
// 2. ASSIGN SITE TO VENDOR DIALOG (ADMIN)
// ==============================================================================

class AssignSiteDialog extends StatefulWidget {
  final List<SubVendor> vendors;
  final String? preselectedVendorId;

  const AssignSiteDialog({
    super.key,
    required this.vendors,
    this.preselectedVendorId,
  });

  @override
  State<AssignSiteDialog> createState() => _AssignSiteDialogState();
}

class _AssignSiteDialogState extends State<AssignSiteDialog> {
  final _formKey = GlobalKey<FormState>();
  String? _selectedVendorId;
  ConsumerRecord? _selectedCustomer;
  late final TextEditingController _capacityCtrl;
  late final TextEditingController _rateCtrl;
  late final TextEditingController _expensesCtrl;
  late final TextEditingController _expenseRemarksCtrl;
  late final TextEditingController _notesCtrl;

  List<ConsumerRecord> _customers = [];
  bool _loadingCustomers = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _selectedVendorId = widget.preselectedVendorId ?? (widget.vendors.isNotEmpty ? widget.vendors.first.id : null);
    _capacityCtrl = TextEditingController(text: '3.0');
    _rateCtrl = TextEditingController(text: '1000');
    _expensesCtrl = TextEditingController(text: '0');
    _expenseRemarksCtrl = TextEditingController();
    _notesCtrl = TextEditingController();

    _loadCustomers();
  }

  @override
  void dispose() {
    _capacityCtrl.dispose();
    _rateCtrl.dispose();
    _expensesCtrl.dispose();
    _expenseRemarksCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadCustomers() async {
    try {
      final result = await RecordService.fetchRecords(pageSize: 1000);
      if (mounted) {
        setState(() {
          _customers = result.items.where((c) => !c.deleted).toList();
          _loadingCustomers = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingCustomers = false);
    }
  }

  Future<void> _handleAssign() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedVendorId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a Sub-Vendor')));
      return;
    }
    if (_selectedCustomer == null || _selectedCustomer!.id == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a Customer site')));
      return;
    }

    setState(() => _isSaving = true);
    try {
      await SubVendorService.assignSiteToVendor(
        vendorId: _selectedVendorId!,
        customerId: _selectedCustomer!.id!,
        siteCapacityKw: double.tryParse(_capacityCtrl.text.trim()) ?? 3.0,
        ratePerKw: double.tryParse(_rateCtrl.text.trim()) ?? 1000.0,
        otherExpenses: double.tryParse(_expensesCtrl.text.trim()) ?? 0.0,
        expenseRemarks: _expenseRemarksCtrl.text.trim().isEmpty ? null : _expenseRemarksCtrl.text.trim(),
        notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      );

      if (mounted) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Site assigned to Sub-Vendor successfully!'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to assign site: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Assign Site to Sub-Vendor',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.of(context).pop()),
                    ],
                  ),
                  const Divider(),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: _selectedVendorId,
                    decoration: const InputDecoration(
                      labelText: 'Select Sub-Vendor *',
                      border: OutlineInputBorder(),
                    ),
                    items: widget.vendors.map((v) {
                      return DropdownMenuItem(
                        value: v.id,
                        child: Text('${v.name} (${v.vendorCode}) - ${v.mobile}'),
                      );
                    }).toList(),
                    onChanged: (val) {
                      setState(() {
                        _selectedVendorId = val;
                        final v = widget.vendors.firstWhere((element) => element.id == val);
                        _rateCtrl.text = v.defaultRatePerKw.toStringAsFixed(0);
                      });
                    },
                    validator: (v) => v == null ? 'Required' : null,
                  ),
                  const SizedBox(height: 12),
                  if (_loadingCustomers)
                    const LinearProgressIndicator()
                  else
                    Autocomplete<ConsumerRecord>(
                      displayStringForOption: (c) => '${c.name} (CA: ${c.consumerNo}) - ${c.address ?? ""}',
                      optionsBuilder: (textEditingValue) {
                        if (textEditingValue.text.isEmpty) return const Iterable<ConsumerRecord>.empty();
                        final q = textEditingValue.text.toLowerCase();
                        return _customers.where((c) =>
                            c.name.toLowerCase().contains(q) ||
                            c.consumerNo.toLowerCase().contains(q) ||
                            (c.address?.toLowerCase().contains(q) ?? false));
                      },
                      onSelected: (selection) {
                        setState(() {
                          _selectedCustomer = selection;
                          if (selection.capacityKw > 0) {
                            _capacityCtrl.text = selection.capacityKw.toStringAsFixed(1);
                          }
                        });
                      },
                      fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                        return TextFormField(
                          controller: controller,
                          focusNode: focusNode,
                          decoration: const InputDecoration(
                            labelText: 'Search Customer / Site (Name, CA No, Village) *',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.search),
                          ),
                          validator: (v) => _selectedCustomer == null ? 'Select a customer' : null,
                        );
                      },
                    ),
                  if (_selectedCustomer != null) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.blue.shade200),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline, color: Colors.blue, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Selected: ${_selectedCustomer!.name} | CA: ${_selectedCustomer!.consumerNo} | Total: ${_currency.format(_selectedCustomer!.totalAmount)}',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _capacityCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Installed Capacity (kW) *',
                            border: OutlineInputBorder(),
                            suffixText: 'kW',
                          ),
                          validator: (v) => (double.tryParse(v ?? '') ?? 0) <= 0 ? 'Enter valid kW' : null,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _rateCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Vendor Charge Rate (₹/kW) *',
                            border: OutlineInputBorder(),
                            prefixText: '₹ ',
                            helperText: 'Default: ₹1,000/kW',
                          ),
                          validator: (v) => (double.tryParse(v ?? '') ?? 0) < 0 ? 'Invalid rate' : null,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _expensesCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Other Approved Expenses (₹)',
                            border: OutlineInputBorder(),
                            prefixText: '₹ ',
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _expenseRemarksCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Expense Remarks',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _notesCtrl,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Assignment Notes / Scope',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(onPressed: _isSaving ? null : () => Navigator.of(context).pop(), child: const Text('Cancel')),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        onPressed: _isSaving ? null : _handleAssign,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0D2B6F),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        ),
                        child: _isSaving
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Text('Assign Site'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ==============================================================================
// 3. ISSUE / RETURN MATERIAL DIALOG (ADMIN)
// ==============================================================================

class IssueReturnMaterialDialog extends StatefulWidget {
  final VendorSiteAssignment assignment;
  final String transactionType; // 'ISSUE' or 'RETURN'

  const IssueReturnMaterialDialog({
    super.key,
    required this.assignment,
    this.transactionType = 'ISSUE',
  });

  @override
  State<IssueReturnMaterialDialog> createState() => _IssueReturnMaterialDialogState();
}

class _IssueReturnMaterialDialogState extends State<IssueReturnMaterialDialog> {
  final _formKey = GlobalKey<FormState>();
  late String _txType;
  String _itemCategory = 'SOLAR_PANEL';
  late final TextEditingController _itemCtrl;
  late final TextEditingController _qtyCtrl;
  late final TextEditingController _unitCtrl;
  late final TextEditingController _rateCtrl;
  late final TextEditingController _gstRateCtrl;
  late final TextEditingController _challanCtrl;
  late final TextEditingController _serialCtrl;
  late final TextEditingController _remarksCtrl;

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _txType = widget.transactionType;
    _itemCtrl = TextEditingController(text: 'Solar PV Modules (550Wp DCR TopCon)');
    _qtyCtrl = TextEditingController(text: '6');
    _unitCtrl = TextEditingController(text: 'Nos');
    _rateCtrl = TextEditingController(text: '12000');
    _gstRateCtrl = TextEditingController(text: '5');
    _challanCtrl = TextEditingController();
    _serialCtrl = TextEditingController();
    _remarksCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _itemCtrl.dispose();
    _qtyCtrl.dispose();
    _unitCtrl.dispose();
    _rateCtrl.dispose();
    _gstRateCtrl.dispose();
    _challanCtrl.dispose();
    _serialCtrl.dispose();
    _remarksCtrl.dispose();
    super.dispose();
  }

  static const List<Map<String, String>> _bosPresets = [
    {
      'label': 'GI Structure',
      'name': 'GI Solar Mounting Structure (Elevated / Tin Shed)',
      'unit': 'Sets',
      'defaultQty': '1',
      'defaultRate': '18000',
    },
    {
      'label': 'DC Cable',
      'name': 'Solar DC Cable 4 sq.mm / 6 sq.mm (Polycab / Havells)',
      'unit': 'Mtrs',
      'defaultQty': '50',
      'defaultRate': '45',
    },
    {
      'label': 'AC Cable',
      'name': 'Solar AC Cable 4 sq.mm / 6 sq.mm (3/4 Core Cu/Al)',
      'unit': 'Mtrs',
      'defaultQty': '20',
      'defaultRate': '75',
    },
    {
      'label': 'ACDB / DCDB Box',
      'name': 'ACDB & DCDB Distribution Box with MCB & SPD',
      'unit': 'Sets',
      'defaultQty': '1',
      'defaultRate': '3500',
    },
    {
      'label': 'Earthing Kit',
      'name': 'Chemical Earthing Electrodes & Gel Pit (3 Pits Kit)',
      'unit': 'Sets',
      'defaultQty': '3',
      'defaultRate': '1800',
    },
    {
      'label': 'Lightning Arrester',
      'name': 'Early Streamer Lightning Arrester (LA) with GI Strip',
      'unit': 'Sets',
      'defaultQty': '1',
      'defaultRate': '3200',
    },
    {
      'label': 'MC4 & Pipes',
      'name': 'MC4 Connectors & UV Conduit Protection Pipes',
      'unit': 'Sets',
      'defaultQty': '1',
      'defaultRate': '1200',
    },
    {
      'label': 'Nut-Bolts & Clamps',
      'name': 'Fasteners, SS304 Nut-Bolts & End/Mid Clamps',
      'unit': 'Sets',
      'defaultQty': '1',
      'defaultRate': '2000',
    },
  ];

  static const List<Map<String, String>> _panelPresets = [
    {
      'label': '550Wp DCR Mono',
      'name': 'Solar PV Modules (550Wp DCR Mono TopCon)',
      'unit': 'Nos',
      'defaultQty': '6',
      'defaultRate': '12000',
    },
    {
      'label': '540Wp Bifacial',
      'name': 'Solar PV Modules (540Wp DCR Bifacial Dual-Glass)',
      'unit': 'Nos',
      'defaultQty': '6',
      'defaultRate': '11800',
    },
    {
      'label': '575Wp / 580Wp DCR',
      'name': 'Solar PV Modules (575Wp / 580Wp High Efficiency DCR)',
      'unit': 'Nos',
      'defaultQty': '6',
      'defaultRate': '12500',
    },
  ];

  static const List<Map<String, String>> _inverterPresets = [
    {
      'label': '3.3kW Single Phase',
      'name': 'Grid-Tied Solar Inverter (3.3kW Single Phase with WiFi)',
      'unit': 'Nos',
      'defaultQty': '1',
      'defaultRate': '25000',
    },
    {
      'label': '5kW Single Phase',
      'name': 'Grid-Tied Solar Inverter (5kW Single Phase with WiFi)',
      'unit': 'Nos',
      'defaultQty': '1',
      'defaultRate': '34000',
    },
    {
      'label': '6kW / 8kW 3-Phase',
      'name': 'Grid-Tied Solar Inverter (6kW / 8kW Three Phase)',
      'unit': 'Nos',
      'defaultQty': '1',
      'defaultRate': '48000',
    },
    {
      'label': '10kW Three Phase',
      'name': 'Grid-Tied Solar Inverter (10kW Three Phase)',
      'unit': 'Nos',
      'defaultQty': '1',
      'defaultRate': '55000',
    },
  ];

  void _applyPreset(Map<String, String> preset) {
    setState(() {
      _itemCtrl.text = preset['name'] ?? '';
      _unitCtrl.text = preset['unit'] ?? 'Nos';
      _qtyCtrl.text = preset['defaultQty'] ?? '1';
      _rateCtrl.text = preset['defaultRate'] ?? '0';
    });
  }

  void _onCategoryChanged(String cat) {
    setState(() {
      _itemCategory = cat;
      if (cat == 'SOLAR_PANEL') {
        _applyPreset(_panelPresets.first);
        _gstRateCtrl.text = '5';
      } else if (cat == 'INVERTER') {
        _applyPreset(_inverterPresets.first);
        _gstRateCtrl.text = '5';
      } else if (cat == 'BOS') {
        _applyPreset(_bosPresets.first);
        _gstRateCtrl.text = '18';
      } else {
        _itemCtrl.text = 'Net Meter / Testing Kit';
        _gstRateCtrl.text = '18';
        _unitCtrl.text = 'Nos';
        _qtyCtrl.text = '1';
        _rateCtrl.text = '3500';
      }
    });
  }

  Widget _buildPresetChips() {
    List<Map<String, String>> presets = [];
    String title = '';
    if (_itemCategory == 'BOS') {
      presets = _bosPresets;
      title = 'BOS साहित्य निवडा (Select Individual BOS Item — 18% GST):';
    } else if (_itemCategory == 'SOLAR_PANEL') {
      presets = _panelPresets;
      title = 'सोलर पॅनेल मॉडेल निवडा (Select Module — 5% GST):';
    } else if (_itemCategory == 'INVERTER') {
      presets = _inverterPresets;
      title = 'सोलर इनव्हर्टर मॉडेल निवडा (Select Inverter — 5% GST):';
    }

    if (presets.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF0D2B6F)),
            ),
            if (_itemCategory == 'BOS')
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: const Color(0xFFFEF3C7), borderRadius: BorderRadius.circular(4)),
                child: const Text('वेगवेगळे आयटम्स (18% GST)', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF92400E))),
              ),
          ],
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: presets.map((p) {
            final isSelected = _itemCtrl.text.trim() == p['name'];
            return ActionChip(
              avatar: Icon(Icons.check_circle_outline, size: 14, color: isSelected ? Colors.white : const Color(0xFF0D2B6F)),
              backgroundColor: isSelected ? const Color(0xFF0D2B6F) : const Color(0xFFF1F5F9),
              side: BorderSide(color: isSelected ? const Color(0xFF0D2B6F) : const Color(0xFFCBD5E1)),
              label: Text(
                p['label']!,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected ? Colors.white : const Color(0xFF1E293B),
                ),
              ),
              onPressed: () => _applyPreset(p),
            );
          }).toList(),
        ),
        const SizedBox(height: 10),
      ],
    );
  }

  double get _computedTaxable {
    final qty = double.tryParse(_qtyCtrl.text.trim()) ?? 0;
    final rate = double.tryParse(_rateCtrl.text.trim()) ?? 0;
    return qty * rate;
  }

  double get _computedGst {
    final gst = double.tryParse(_gstRateCtrl.text.trim()) ?? 5;
    return _computedTaxable * (gst / 100);
  }

  double get _computedTotal => _computedTaxable + _computedGst;

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    try {
      final tx = VendorMaterialTransaction.create(
        assignmentId: widget.assignment.id,
        vendorId: widget.assignment.vendorId,
        customerId: widget.assignment.customerId,
        transactionType: _txType,
        itemName: _itemCtrl.text.trim(),
        itemCategory: _itemCategory,
        gstRate: double.tryParse(_gstRateCtrl.text.trim()) ?? 5.0,
        quantity: double.tryParse(_qtyCtrl.text.trim()) ?? 1.0,
        unit: _unitCtrl.text.trim(),
        unitRate: double.tryParse(_rateCtrl.text.trim()) ?? 0.0,
        challanNumber: _challanCtrl.text.trim().isEmpty ? null : _challanCtrl.text.trim(),
        serialNumbers: _serialCtrl.text.trim().isEmpty ? null : _serialCtrl.text.trim(),
        remarks: _remarksCtrl.text.trim().isEmpty ? null : _remarksCtrl.text.trim(),
      );

      await SubVendorService.recordMaterialTransaction(tx);

      if (mounted) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${_txType == "ISSUE" ? "Material Issued" : "Material Return"} recorded successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to record transaction: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isReturn = _txType == 'RETURN';
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        isReturn ? 'Record Material Return' : 'Issue Material to Site',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: isReturn ? Colors.red.shade800 : const Color(0xFF0D2B6F),
                        ),
                      ),
                      IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.of(context).pop()),
                    ],
                  ),
                  const Divider(),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Text(
                      'Site: ${widget.assignment.customerName} (CA: ${widget.assignment.consumerNo}) | Capacity: ${widget.assignment.siteCapacityKw} kW',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Transaction Type Toggle
                  Row(
                    children: [
                      const Text('Transaction Type: ', style: TextStyle(fontWeight: FontWeight.bold)),
                      ChoiceChip(
                        label: const Text('Material Issue (+)'),
                        selected: _txType == 'ISSUE',
                        selectedColor: Colors.blue.shade100,
                        onSelected: (val) {
                          if (val) setState(() => _txType = 'ISSUE');
                        },
                      ),
                      const SizedBox(width: 8),
                      ChoiceChip(
                        label: const Text('Material Return (-)'),
                        selected: _txType == 'RETURN',
                        selectedColor: Colors.red.shade100,
                        onSelected: (val) {
                          if (val) setState(() => _txType = 'RETURN');
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Category Selection
                  DropdownButtonFormField<String>(
                    value: _itemCategory,
                    decoration: const InputDecoration(
                      labelText: 'Material Category *',
                      border: OutlineInputBorder(),
                      helperText: 'Panels & Inverters = 5% GST; BOS & Other = 18% GST',
                    ),
                    items: const [
                      DropdownMenuItem(value: 'SOLAR_PANEL', child: Text('Solar Panels (5% GST Category)')),
                      DropdownMenuItem(value: 'INVERTER', child: Text('Solar Inverters (5% GST Category)')),
                      DropdownMenuItem(value: 'BOS', child: Text('Solar BOS / Mounting Structure / Cables (18% GST)')),
                      DropdownMenuItem(value: 'OTHER', child: Text('Other / Net Meter / Accessories (18% GST)')),
                    ],
                    onChanged: (val) {
                      if (val != null) _onCategoryChanged(val);
                    },
                  ),
                  const SizedBox(height: 10),
                  _buildPresetChips(),
                  TextFormField(
                    controller: _itemCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Item Name & Technical Description *',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) => v?.trim().isEmpty == true ? 'Required' : null,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _qtyCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Quantity *',
                            border: OutlineInputBorder(),
                          ),
                          onChanged: (_) => setState(() {}),
                          validator: (v) => (double.tryParse(v ?? '') ?? 0) <= 0 ? 'Enter valid qty' : null,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _unitCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Unit (Nos, Sets, Mtrs)',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _rateCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Purchase Rate (excl. GST) *',
                            border: OutlineInputBorder(),
                            prefixText: '₹ ',
                          ),
                          onChanged: (_) => setState(() {}),
                          validator: (v) => (double.tryParse(v ?? '') ?? 0) <= 0 ? 'Enter unit rate' : null,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _gstRateCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'GST Rate (%) *',
                            border: OutlineInputBorder(),
                            suffixText: '%',
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _challanCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Challan / Invoice No.',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _serialCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Serial Numbers / Barcode Details',
                      border: OutlineInputBorder(),
                      helperText: 'Optional barcode/serial numbers for warranty tracking',
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Real-time calculation preview
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isReturn ? Colors.red.shade50 : Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: isReturn ? Colors.red.shade200 : Colors.blue.shade200),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Taxable Purchase Value:'),
                            Text(
                              '${isReturn ? "-" : ""}${_currency.format(_computedTaxable)}',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Input GST (${_gstRateCtrl.text}%):'),
                            Text(
                              '${isReturn ? "-" : ""}${_currency.format(_computedGst)}',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        const Divider(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Net Total ${isReturn ? "Return" : "Issue"} Amount:',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            Text(
                              '${isReturn ? "-" : ""}${_currency.format(_computedTotal)}',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                                color: isReturn ? Colors.red.shade800 : const Color(0xFF0D2B6F),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _remarksCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Remarks / Notes',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(onPressed: _isSaving ? null : () => Navigator.of(context).pop(), child: const Text('Cancel')),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        onPressed: _isSaving ? null : _handleSave,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isReturn ? Colors.red.shade800 : const Color(0xFF0D2B6F),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        ),
                        child: _isSaving
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : Text(isReturn ? 'Record Return' : 'Record Issue'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ==============================================================================
// 4. RECORD VENDOR PAYOUT DIALOG (ADMIN)
// ==============================================================================

class RecordVendorPayoutDialog extends StatefulWidget {
  final SubVendor vendor;
  final List<VendorSiteAssignment> assignments;

  const RecordVendorPayoutDialog({
    super.key,
    required this.vendor,
    required this.assignments,
  });

  @override
  State<RecordVendorPayoutDialog> createState() => _RecordVendorPayoutDialogState();
}

class _RecordVendorPayoutDialogState extends State<RecordVendorPayoutDialog> {
  final _formKey = GlobalKey<FormState>();
  String? _selectedAssignmentId;
  late final TextEditingController _amountCtrl;
  String _paymentMode = 'Bank Transfer';
  late final TextEditingController _refCtrl;
  late final TextEditingController _bankCtrl;
  late final TextEditingController _remarksCtrl;
  DateTime _payoutDate = DateTime.now();

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _amountCtrl = TextEditingController();
    _refCtrl = TextEditingController();
    _bankCtrl = TextEditingController(text: widget.vendor.bankName ?? '');
    _remarksCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _refCtrl.dispose();
    _bankCtrl.dispose();
    _remarksCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    try {
      final payout = VendorPayout(
        id: '',
        vendorId: widget.vendor.id,
        assignmentId: _selectedAssignmentId,
        payoutDate: _payoutDate,
        amount: double.tryParse(_amountCtrl.text.trim()) ?? 0.0,
        paymentMode: _paymentMode,
        referenceNumber: _refCtrl.text.trim().isEmpty ? null : _refCtrl.text.trim(),
        bankName: _bankCtrl.text.trim().isEmpty ? null : _bankCtrl.text.trim(),
        remarks: _remarksCtrl.text.trim().isEmpty ? null : _remarksCtrl.text.trim(),
      );

      await SubVendorService.recordVendorPayout(payout);

      if (mounted) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Vendor payout recorded successfully!'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to record payout: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 540),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Record Sub-Vendor Payout (${widget.vendor.name})',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.of(context).pop()),
                    ],
                  ),
                  const Divider(),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String?>(
                    value: _selectedAssignmentId,
                    decoration: const InputDecoration(
                      labelText: 'Link to Specific Site (Optional)',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('General Account / All Sites')),
                      ...widget.assignments.map((a) {
                        return DropdownMenuItem(
                          value: a.id,
                          child: Text('${a.customerName} (CA: ${a.consumerNo}) - ${a.siteCapacityKw}kW'),
                        );
                      }),
                    ],
                    onChanged: (val) => setState(() => _selectedAssignmentId = val),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _amountCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Disbursement Amount (₹) *',
                            border: OutlineInputBorder(),
                            prefixText: '₹ ',
                          ),
                          validator: (v) => (double.tryParse(v ?? '') ?? 0) <= 0 ? 'Enter valid amount' : null,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _paymentMode,
                          decoration: const InputDecoration(labelText: 'Payment Mode', border: OutlineInputBorder()),
                          items: const [
                            DropdownMenuItem(value: 'Bank Transfer', child: Text('Bank Transfer (NEFT/RTGS)')),
                            DropdownMenuItem(value: 'UPI', child: Text('UPI / QR')),
                            DropdownMenuItem(value: 'Cheque', child: Text('Cheque')),
                            DropdownMenuItem(value: 'Cash', child: Text('Cash')),
                          ],
                          onChanged: (val) => setState(() => _paymentMode = val ?? 'Bank Transfer'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _refCtrl,
                          decoration: const InputDecoration(
                            labelText: 'UTR / Transaction Reference No.',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _bankCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Paid from / to Bank',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _remarksCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Remarks / Notes',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(onPressed: _isSaving ? null : () => Navigator.of(context).pop(), child: const Text('Cancel')),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        onPressed: _isSaving ? null : _handleSave,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF047857),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        ),
                        child: _isSaving
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Text('Record Payout'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ==============================================================================
// 5. RESET VENDOR PASSWORD DIALOG (ADMIN)
// ==============================================================================

class ResetVendorPasswordDialog extends StatefulWidget {
  final SubVendor vendor;
  const ResetVendorPasswordDialog({super.key, required this.vendor});

  @override
  State<ResetVendorPasswordDialog> createState() => _ResetVendorPasswordDialogState();
}

class _ResetVendorPasswordDialogState extends State<ResetVendorPasswordDialog> {
  final _formKey = GlobalKey<FormState>();
  final _passwordCtrl = TextEditingController(text: 'Siya@2026');
  bool _isLoading = false;
  bool _obscure = true;

  @override
  void dispose() {
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleReset() async {
    if (!_formKey.currentState!.validate()) return;
    if (widget.vendor.authUserId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This vendor does not have an active login account linked.')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      await SubVendorService.resetVendorPassword(
        authUserId: widget.vendor.authUserId!,
        newPassword: _passwordCtrl.text.trim(),
      );

      if (mounted) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Password reset successfully!'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to reset password: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Reset Password for ${widget.vendor.name}'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Mobile / Login Username: ${widget.vendor.mobile}'),
            const SizedBox(height: 12),
            TextFormField(
              controller: _passwordCtrl,
              obscureText: _obscure,
              decoration: InputDecoration(
                labelText: 'New Password *',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
              validator: (v) => (v == null || v.trim().length < 6) ? 'Min 6 characters' : null,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: _isLoading ? null : () => Navigator.of(context).pop(), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: _isLoading ? null : _handleReset,
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0D2B6F), foregroundColor: Colors.white),
          child: _isLoading
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Text('Reset Password'),
        ),
      ],
    );
  }
}

// ==============================================================================
// 6. SITE DETAILS & FINANCIAL BREAKDOWN DIALOG (FOR SUB-VENDOR & ADMIN)
// ==============================================================================

class VendorSiteDetailDialog extends StatefulWidget {
  final VendorSiteAssignment assignment;
  final bool isAdmin;

  const VendorSiteDetailDialog({
    super.key,
    required this.assignment,
    this.isAdmin = false,
  });

  @override
  State<VendorSiteDetailDialog> createState() => _VendorSiteDetailDialogState();
}

class _VendorSiteDetailDialogState extends State<VendorSiteDetailDialog> {
  SiteFinancialDetail? _detail;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDetail();
  }

  Future<void> _loadDetail() async {
    try {
      final d = await SubVendorService.getSiteFinancialDetail(widget.assignment);
      if (mounted) setState(() { _detail = d; _isLoading = false; });
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.assignment;
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 820),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Site Details: ${a.customerName}',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      Text('CA No: ${a.consumerNo ?? "-"} | Capacity: ${a.siteCapacityKw} kW | Status: ${a.status}',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                    ],
                  ),
                  Row(
                    children: [
                      ElevatedButton.icon(
                        icon: const Icon(Icons.picture_as_pdf, size: 16),
                        label: const Text('Export PDF Statement'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0D2B6F),
                          foregroundColor: Colors.white,
                        ),
                        onPressed: _detail == null ? null : () => SubVendorPdfService.printOrShareSiteStatement(_detail!),
                      ),
                      const SizedBox(width: 8),
                      IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.of(context).pop()),
                    ],
                  ),
                ],
              ),
              const Divider(),
              if (_isLoading)
                const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator()))
              else if (_detail == null)
                const Padding(padding: EdgeInsets.all(40), child: Center(child: Text('Failed to load calculations')))
              else ...[
                // Top KPI Summary row
                Row(
                  children: [
                    _metricCard('Material Cost (Net)', _currency.format(_detail!.totalMaterialCost), Colors.blueGrey),
                    _metricCard('Vendor Charges (₹1k/kW)', _currency.format(_detail!.vendorCharges), const Color(0xFF0D2B6F)),
                    _metricCard('Payouts Disbursed', _currency.format(_detail!.totalPaidToVendor), const Color(0xFF047857)),
                    _metricCard('Net Outstanding', _currency.format(_detail!.outstandingVendorPayable), Colors.deepOrange),
                  ],
                ),
                const SizedBox(height: 16),
                const Text('ACTUAL MATERIAL ISSUED & RETURNED', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 6),
                Flexible(
                  child: Container(
                    decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(6)),
                    child: _detail!.materials.isEmpty
                        ? const Padding(padding: EdgeInsets.all(16), child: Center(child: Text('No material transactions recorded.')))
                        : ListView.separated(
                            shrinkWrap: true,
                            itemCount: _detail!.materials.length,
                            separatorBuilder: (_, __) => const Divider(height: 1),
                            itemBuilder: (context, i) {
                              final m = _detail!.materials[i];
                              final isRet = m.isReturn;
                              return ListTile(
                                dense: true,
                                leading: CircleAvatar(
                                  radius: 12,
                                  backgroundColor: isRet ? Colors.red.shade100 : Colors.green.shade100,
                                  child: Icon(isRet ? Icons.arrow_downward : Icons.arrow_upward, size: 14, color: isRet ? Colors.red : Colors.green),
                                ),
                                title: Text(m.itemName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                subtitle: Text(
                                  '${m.quantity} ${m.unit} @ ${_currency.format(m.unitRate)} | GST: ${m.gstRate.toStringAsFixed(0)}% (Taxable: ${_currency.format(m.taxableAmount)})',
                                  style: const TextStyle(fontSize: 11),
                                ),
                                trailing: Text(
                                  '${isRet ? "-" : ""}${_currency.format(m.totalAmount)}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: isRet ? Colors.red : Colors.black87,
                                    fontSize: 13,
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ),
                const SizedBox(height: 12),
                // GST Breakdown Box
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(6)),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('5% GST (Panels/Inverters): ${_currency.format(_detail!.material5Total)}', style: const TextStyle(fontSize: 12)),
                      Text('18% GST (BOS/Cables): ${_currency.format(_detail!.material18Total)}', style: const TextStyle(fontSize: 12)),
                      Text('Eligible Input GST: ${_currency.format(_detail!.totalEligibleInputGst)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _metricCard(String title, String val, Color color) {
    return Expanded(
      child: Card(
        color: color.withOpacity(0.08),
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: BorderSide(color: color.withOpacity(0.2))),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: TextStyle(fontSize: 11, color: Colors.grey.shade700)),
              const SizedBox(height: 4),
              Text(val, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color)),
            ],
          ),
        ),
      ),
    );
  }
}
