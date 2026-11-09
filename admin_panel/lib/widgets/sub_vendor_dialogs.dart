import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
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

// ==============================================================================
// 7. CONFIGURE SITE CUSTOMER PAYMENT & LOAN DIALOG
// ==============================================================================

class ConfigureSitePaymentDialog extends StatefulWidget {
  final VendorSiteAssignment assignment;
  const ConfigureSitePaymentDialog({super.key, required this.assignment});

  @override
  State<ConfigureSitePaymentDialog> createState() => _ConfigureSitePaymentDialogState();
}

class _ConfigureSitePaymentDialogState extends State<ConfigureSitePaymentDialog> {
  final _formKey = GlobalKey<FormState>();
  late String _paymentType;
  late final TextEditingController _siteAmountCtrl;
  late final TextEditingController _bankNameCtrl;
  late final TextEditingController _loanAppIdCtrl;
  late final TextEditingController _loanAppliedCtrl;
  late final TextEditingController _loanSanctionedCtrl;
  bool _isLoading = false;

  final List<String> _bankSuggestions = [
    'State Bank of India',
    'Bank of Maharashtra',
    'Bank of Baroda',
    'Punjab National Bank',
    'Union Bank of India',
    'Canara Bank',
    'HDFC Bank',
    'ICICI Bank',
    'Axis Bank',
    'Kotak Mahindra Bank',
    'Other / Rural Bank',
  ];

  @override
  void initState() {
    super.initState();
    final a = widget.assignment;
    _paymentType = a.paymentType;
    _siteAmountCtrl = TextEditingController(
      text: (a.totalCustomerSiteAmount > 0 ? a.totalCustomerSiteAmount : a.customerTotalAmount).toStringAsFixed(2),
    );
    _bankNameCtrl = TextEditingController(text: a.loanBankName ?? '');
    _loanAppIdCtrl = TextEditingController(text: a.loanApplicationId ?? '');
    _loanAppliedCtrl = TextEditingController(
      text: a.loanAppliedAmount > 0 ? a.loanAppliedAmount.toStringAsFixed(2) : '',
    );
    _loanSanctionedCtrl = TextEditingController(
      text: a.loanSanctionedAmount > 0 ? a.loanSanctionedAmount.toStringAsFixed(2) : '',
    );
  }

  @override
  void dispose() {
    _siteAmountCtrl.dispose();
    _bankNameCtrl.dispose();
    _loanAppIdCtrl.dispose();
    _loanAppliedCtrl.dispose();
    _loanSanctionedCtrl.dispose();
    super.dispose();
  }

  bool get _isLoan =>
      _paymentType == 'Bank Loan Customer' || _paymentType == 'Part Cash + Part Loan';

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final siteAmt = double.tryParse(_siteAmountCtrl.text.trim()) ?? 0.0;
      final applied = double.tryParse(_loanAppliedCtrl.text.trim()) ?? 0.0;
      final sanctioned = double.tryParse(_loanSanctionedCtrl.text.trim()) ?? 0.0;

      await SubVendorService.updateSitePaymentConfig(
        assignmentId: widget.assignment.id,
        paymentType: _paymentType,
        totalCustomerSiteAmount: siteAmt,
        loanBankName: _isLoan ? _bankNameCtrl.text.trim() : null,
        loanApplicationId: _isLoan ? _loanAppIdCtrl.text.trim() : null,
        loanAppliedAmount: _isLoan ? applied : 0.0,
        loanSanctionedAmount: _isLoan ? sanctioned : 0.0,
      );

      if (mounted) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Customer payment and loan configuration updated successfully!'),
            backgroundColor: Color(0xFF047857),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update config: $e'), backgroundColor: Colors.red.shade700),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.assignment;
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 580, maxHeight: 720),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Configure Payment & Loan Tracking',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0D2B6F))),
                          Text('${a.customerName ?? "Customer"} (CA: ${a.consumerNo ?? "-"}) | ${a.siteCapacityKw} kW',
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                        ],
                      ),
                      IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.of(context).pop()),
                    ],
                  ),
                  const Divider(),
                  const SizedBox(height: 8),

                  // Payment Type Selector
                  const Text('Customer Payment Type', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    value: _paymentType,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'Cash Customer',
                        child: Text('Cash Customer (100% Self-Funded)'),
                      ),
                      DropdownMenuItem(
                        value: 'Bank Loan Customer',
                        child: Text('Bank Loan Customer (100% Bank Financed)'),
                      ),
                      DropdownMenuItem(
                        value: 'Part Cash + Part Loan',
                        child: Text('Part Cash + Part Loan (Hybrid Split)'),
                      ),
                    ],
                    onChanged: (val) {
                      if (val != null) setState(() => _paymentType = val);
                    },
                  ),

                  const SizedBox(height: 14),

                  // Total Customer Site Amount
                  const Text('Total Customer Site Amount (₹)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _siteAmountCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      prefixText: '₹ ',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      hintText: 'e.g. 200000.00',
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Enter total site amount';
                      if ((double.tryParse(v) ?? -1) < 0) return 'Enter valid amount';
                      return null;
                    },
                  ),

                  if (_isLoan) ...[
                    const SizedBox(height: 18),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0FDF4),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFF86EFAC)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: const [
                              Icon(Icons.account_balance, size: 18, color: Color(0xFF047857)),
                              SizedBox(width: 6),
                              Text('Bank Loan Lifecycle & Sanction Details',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF047857))),
                            ],
                          ),
                          const SizedBox(height: 10),

                          // Bank Name
                          const Text('Financing Bank Name', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                          const SizedBox(height: 4),
                          Autocomplete<String>(
                            initialValue: TextEditingValue(text: _bankNameCtrl.text),
                            optionsBuilder: (textEditingValue) {
                              if (textEditingValue.text.isEmpty) return _bankSuggestions;
                              return _bankSuggestions.where(
                                (b) => b.toLowerCase().contains(textEditingValue.text.toLowerCase()),
                              );
                            },
                            onSelected: (selection) => _bankNameCtrl.text = selection,
                            fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                              return TextField(
                                controller: controller,
                                focusNode: focusNode,
                                decoration: const InputDecoration(
                                  hintText: 'e.g. State Bank of India',
                                  border: OutlineInputBorder(),
                                  filled: true,
                                  fillColor: Colors.white,
                                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                ),
                                onChanged: (val) => _bankNameCtrl.text = val,
                              );
                            },
                          ),

                          const SizedBox(height: 10),

                          // Loan Application ID
                          const Text('Loan Application / Sanction Number', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                          const SizedBox(height: 4),
                          TextFormField(
                            controller: _loanAppIdCtrl,
                            decoration: const InputDecoration(
                              hintText: 'e.g. SBI-SOLAR-2026-9812',
                              border: OutlineInputBorder(),
                              filled: true,
                              fillColor: Colors.white,
                              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            ),
                          ),

                          const SizedBox(height: 10),

                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Loan Applied Amount (₹)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                                    const SizedBox(height: 4),
                                    TextFormField(
                                      controller: _loanAppliedCtrl,
                                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                      decoration: const InputDecoration(
                                        prefixText: '₹ ',
                                        border: OutlineInputBorder(),
                                        filled: true,
                                        fillColor: Colors.white,
                                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Loan Sanctioned Amount (₹)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                                    const SizedBox(height: 4),
                                    TextFormField(
                                      controller: _loanSanctionedCtrl,
                                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                      decoration: const InputDecoration(
                                        prefixText: '₹ ',
                                        border: OutlineInputBorder(),
                                        filled: true,
                                        fillColor: Colors.white,
                                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 16),

                  // Realtime summary card
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Current Cash Received:', style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
                            Text(_currency.format(a.totalCashReceived), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Current Loan Credited:', style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
                            Text(_currency.format(a.totalLoanCredited), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF047857))),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Total Customer Received:', style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
                            Text(_currency.format(a.effectiveReceivedAmount), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF0D2B6F))),
                          ],
                        ),
                        const Divider(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Outstanding Customer Due:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                            Text(_currency.format(a.effectiveCustomerOutstanding), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.deepOrange)),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Save Button
                  SizedBox(
                    width: double.infinity,
                    height: 44,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0D2B6F),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: _isLoading ? null : _handleSave,
                      child: _isLoading
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Text('Save Payment & Loan Configuration', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
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
// 8. RECORD CUSTOMER PAYMENT / BANK LOAN CREDIT DIALOG (ADMIN ONLY)
// ==============================================================================

class RecordCustomerPaymentDialog extends StatefulWidget {
  final VendorSiteAssignment assignment;
  final String? initialCategory; // 'CASH' or 'BANK_LOAN'

  const RecordCustomerPaymentDialog({
    super.key,
    required this.assignment,
    this.initialCategory,
  });

  @override
  State<RecordCustomerPaymentDialog> createState() => _RecordCustomerPaymentDialogState();
}

class _RecordCustomerPaymentDialogState extends State<RecordCustomerPaymentDialog> {
  final _formKey = GlobalKey<FormState>();
  late String _category; // 'CASH' or 'BANK_LOAN'
  String _paymentStage = 'PARTIAL'; // 'ADVANCE', 'PARTIAL', 'FINAL', 'LOAN_CREDIT'
  DateTime _paymentDate = DateTime.now();
  String _paymentMode = 'Bank Transfer';

  late final TextEditingController _amountCtrl;
  late final TextEditingController _refCtrl;
  late final TextEditingController _bankNameCtrl;
  late final TextEditingController _loanAppIdCtrl;
  late final TextEditingController _attachmentCtrl;
  late final TextEditingController _remarksCtrl;

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final a = widget.assignment;
    _category = widget.initialCategory ?? (a.isBankLoan ? 'BANK_LOAN' : 'CASH');
    if (_category == 'BANK_LOAN') {
      _paymentStage = 'LOAN_CREDIT';
    }

    _amountCtrl = TextEditingController();
    _refCtrl = TextEditingController();
    _bankNameCtrl = TextEditingController(text: a.loanBankName ?? 'State Bank of India');
    _loanAppIdCtrl = TextEditingController(text: a.loanApplicationId ?? '');
    _attachmentCtrl = TextEditingController();
    _remarksCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _refCtrl.dispose();
    _bankNameCtrl.dispose();
    _loanAppIdCtrl.dispose();
    _attachmentCtrl.dispose();
    _remarksCtrl.dispose();
    super.dispose();
  }

  bool get _isLoan => _category == 'BANK_LOAN';

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final amt = double.parse(_amountCtrl.text.trim());
      final a = widget.assignment;

      final payment = VendorCustomerPayment.create(
        assignmentId: a.id,
        vendorId: a.vendorId,
        customerId: a.customerId,
        paymentType: _category,
        paymentStage: _paymentStage,
        amount: amt,
        paymentDate: _paymentDate,
        paymentMode: _isLoan ? 'Bank Credit / Direct NEFT' : _paymentMode,
        referenceNumber: _refCtrl.text.trim().isNotEmpty ? _refCtrl.text.trim() : null,
        bankName: _isLoan ? _bankNameCtrl.text.trim() : null,
        loanApplicationId: _isLoan ? _loanAppIdCtrl.text.trim() : null,
        attachmentUrl: _attachmentCtrl.text.trim().isNotEmpty ? _attachmentCtrl.text.trim() : null,
        remarks: _remarksCtrl.text.trim().isNotEmpty ? _remarksCtrl.text.trim() : null,
        status: 'Approved',
      );

      await SubVendorService.recordCustomerPayment(payment);

      if (mounted) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _isLoan
                  ? 'Bank Loan Credit Installment of ${_currency.format(amt)} recorded successfully!'
                  : 'Cash payment of ${_currency.format(amt)} recorded successfully!',
            ),
            backgroundColor: const Color(0xFF047857),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to record payment: $e'), backgroundColor: Colors.red.shade700),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.assignment;
    final pendingCredit = a.loanPendingCredit;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 580, maxHeight: 720),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _isLoan ? 'Record Bank Loan Credit Installment' : 'Record Customer Cash Payment',
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0D2B6F)),
                          ),
                          Text('${a.customerName ?? "Customer"} (CA: ${a.consumerNo ?? "-"}) | Sub-Vendor: ${a.vendorName ?? "Vendor"}',
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                        ],
                      ),
                      IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.of(context).pop()),
                    ],
                  ),
                  const Divider(),
                  const SizedBox(height: 8),

                  // Category Toggle: Cash Payment vs Bank Loan Credit
                  Row(
                    children: [
                      Expanded(
                        child: ChoiceChip(
                          label: const Center(child: Text('Cash Payment (Self-Funded)', style: TextStyle(fontWeight: FontWeight.bold))),
                          selected: _category == 'CASH',
                          selectedColor: const Color(0xFF0D2B6F),
                          labelStyle: TextStyle(color: _category == 'CASH' ? Colors.white : Colors.black87),
                          onSelected: (sel) {
                            if (sel) {
                              setState(() {
                                _category = 'CASH';
                                _paymentStage = 'PARTIAL';
                              });
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ChoiceChip(
                          label: const Center(child: Text('Bank Loan Credit (Disbursal)', style: TextStyle(fontWeight: FontWeight.bold))),
                          selected: _category == 'BANK_LOAN',
                          selectedColor: const Color(0xFF047857),
                          labelStyle: TextStyle(color: _category == 'BANK_LOAN' ? Colors.white : Colors.black87),
                          onSelected: (sel) {
                            if (sel) {
                              setState(() {
                                _category = 'BANK_LOAN';
                                _paymentStage = 'LOAN_CREDIT';
                              });
                            }
                          },
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 14),

                  if (_isLoan) ...[
                    // Loan Context Banner
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFECFDF5),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFA7F3D0)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Loan Sanctioned: ${_currency.format(a.loanSanctionedAmount)}',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF047857))),
                              Text('Already Credited: ${_currency.format(a.totalLoanCredited)}',
                                  style: TextStyle(fontSize: 11, color: Colors.grey.shade700)),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFF047857),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'Pending Credit: ${_currency.format(pendingCredit)}',
                              style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  // Payment Stage & Date Row
                  Row(
                    children: [
                      if (!_isLoan)
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Payment Stage', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                              const SizedBox(height: 4),
                              DropdownButtonFormField<String>(
                                value: _paymentStage,
                                decoration: const InputDecoration(border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
                                items: const [
                                  DropdownMenuItem(value: 'ADVANCE', child: Text('Advance')),
                                  DropdownMenuItem(value: 'PARTIAL', child: Text('Partial')),
                                  DropdownMenuItem(value: 'FINAL', child: Text('Final')),
                                ],
                                onChanged: (v) => setState(() => _paymentStage = v ?? 'PARTIAL'),
                              ),
                            ],
                          ),
                        ),
                      if (!_isLoan) const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(_isLoan ? 'Bank Credit Date' : 'Payment Date', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                            const SizedBox(height: 4),
                            InkWell(
                              onTap: () async {
                                final d = await showDatePicker(
                                  context: context,
                                  initialDate: _paymentDate,
                                  firstDate: DateTime(2023),
                                  lastDate: DateTime(2030),
                                );
                                if (d != null) setState(() => _paymentDate = d);
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey.shade400),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(_dateFormat.format(_paymentDate)),
                                    const Icon(Icons.calendar_today, size: 16),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // Amount
                  Text(_isLoan ? 'Credit Amount Received (₹)' : 'Payment Amount (₹)', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  const SizedBox(height: 4),
                  TextFormField(
                    controller: _amountCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      prefixText: '₹ ',
                      border: const OutlineInputBorder(),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      hintText: _isLoan ? 'e.g. 50000.00 (Installment amount credited to SIYA)' : 'e.g. 50000.00',
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Enter amount';
                      final parsed = double.tryParse(v);
                      if (parsed == null || parsed <= 0) return 'Enter positive amount';
                      return null;
                    },
                  ),

                  const SizedBox(height: 12),

                  // Mode & Reference (UTR)
                  Row(
                    children: [
                      if (!_isLoan)
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Payment Mode', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                              const SizedBox(height: 4),
                              DropdownButtonFormField<String>(
                                value: _paymentMode,
                                decoration: const InputDecoration(border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
                                items: const ['Bank Transfer', 'UPI', 'Cash', 'Cheque', 'NEFT/RTGS']
                                    .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                                    .toList(),
                                onChanged: (v) => setState(() => _paymentMode = v ?? 'Bank Transfer'),
                              ),
                            ],
                          ),
                        ),
                      if (!_isLoan) const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _isLoan ? 'Bank UTR / Transaction ID *' : 'Transaction Ref / UTR / Cheque No',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                            ),
                            const SizedBox(height: 4),
                            TextFormField(
                              controller: _refCtrl,
                              decoration: InputDecoration(
                                hintText: _isLoan ? 'e.g. SBIN202611089912' : 'Reference number',
                                border: const OutlineInputBorder(),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              ),
                              validator: (v) {
                                if (_isLoan && (v == null || v.trim().isEmpty)) {
                                  return 'UTR / Txn ID is required for bank loan credit';
                                }
                                return null;
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  if (_isLoan) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Disbursing Bank Name', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                              const SizedBox(height: 4),
                              TextFormField(
                                controller: _bankNameCtrl,
                                decoration: const InputDecoration(
                                  hintText: 'e.g. State Bank of India',
                                  border: OutlineInputBorder(),
                                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Loan Application ID', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                              const SizedBox(height: 4),
                              TextFormField(
                                controller: _loanAppIdCtrl,
                                decoration: const InputDecoration(
                                  hintText: 'e.g. SBI-APP-99881',
                                  border: OutlineInputBorder(),
                                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text('Bank Credit Proof Attachment URL', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    const SizedBox(height: 4),
                    TextFormField(
                      controller: _attachmentCtrl,
                      decoration: const InputDecoration(
                        hintText: 'https://... or bank statement file path',
                        prefixIcon: Icon(Icons.link, size: 18),
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                    ),
                  ],

                  const SizedBox(height: 12),
                  const Text('Remarks / Notes', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  const SizedBox(height: 4),
                  TextFormField(
                    controller: _remarksCtrl,
                    decoration: InputDecoration(
                      hintText: _isLoan ? 'e.g. 1st installment disbursement from SBI' : 'e.g. Advance paid via UPI',
                      border: const OutlineInputBorder(),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Submit
                  SizedBox(
                    width: double.infinity,
                    height: 44,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _isLoan ? const Color(0xFF047857) : const Color(0xFF0D2B6F),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: _isLoading ? null : _handleSave,
                      child: _isLoading
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : Text(
                              _isLoan ? 'Confirm & Record Bank Loan Credit' : 'Confirm & Record Cash Payment',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                    ),
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
// 9. SITE PAYMENT & BANK LOAN LEDGER DIALOG
// ==============================================================================

class SitePaymentLedgerDialog extends StatefulWidget {
  final VendorSiteAssignment assignment;
  const SitePaymentLedgerDialog({super.key, required this.assignment});

  @override
  State<SitePaymentLedgerDialog> createState() => _SitePaymentLedgerDialogState();
}

class _SitePaymentLedgerDialogState extends State<SitePaymentLedgerDialog> {
  late VendorSiteAssignment _assignment;
  List<VendorCustomerPayment> _payments = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _assignment = widget.assignment;
    _loadLedger();
  }

  Future<void> _loadLedger() async {
    setState(() => _isLoading = true);
    try {
      final payments = await SubVendorService.fetchCustomerPayments(assignmentId: _assignment.id);
      // Re-fetch assignment to ensure refreshed totals
      final assignments = await SubVendorService.fetchAssignments(vendorId: _assignment.vendorId);
      final refreshed = assignments.firstWhere((a) => a.id == _assignment.id, orElse: () => _assignment);

      if (mounted) {
        setState(() {
          _payments = payments;
          _assignment = refreshed;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleDeletePayment(String paymentId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Payment Record?'),
        content: const Text('Are you sure you want to delete this payment record? The site balances will be automatically recalculated.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await SubVendorService.deleteCustomerPayment(paymentId);
      await _loadLedger();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Payment deleted successfully.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete payment: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final a = _assignment;
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 880, maxHeight: 780),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text('Customer Payment Ledger: ${a.customerName ?? "Customer"}',
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0D2B6F))),
                          const SizedBox(width: 8),
                          _paymentTypeChip(a.paymentType),
                          if (a.isBankLoan) ...[
                            const SizedBox(width: 6),
                            _loanStatusChip(a.loanStatus),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text('CA No: ${a.consumerNo ?? "-"} | Sub-Vendor: ${a.vendorCode ?? "VND"} - ${a.vendorName ?? "Vendor"} | Capacity: ${a.siteCapacityKw} kW',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                    ],
                  ),
                  Row(
                    children: [
                      OutlinedButton.icon(
                        icon: const Icon(Icons.settings, size: 16),
                        label: const Text('Config'),
                        onPressed: () async {
                          final res = await showDialog<bool>(
                            context: context,
                            builder: (_) => ConfigureSitePaymentDialog(assignment: a),
                          );
                          if (res == true) _loadLedger();
                        },
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.add, size: 16),
                        label: const Text('+ Payment / Credit'),
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF047857), foregroundColor: Colors.white),
                        onPressed: () async {
                          final res = await showDialog<bool>(
                            context: context,
                            builder: (_) => RecordCustomerPaymentDialog(assignment: a),
                          );
                          if (res == true) _loadLedger();
                        },
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.picture_as_pdf, size: 16),
                        label: const Text('PDF Ledger'),
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0D2B6F), foregroundColor: Colors.white),
                        onPressed: _payments.isEmpty
                            ? null
                            : () => SubVendorPdfService.printOrShareSitePaymentLedger(assignment: a, payments: _payments),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.calculate, size: 16),
                        label: const Text('Settlement Calculator'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF047857),
                          foregroundColor: Colors.white,
                        ),
                        onPressed: () async {
                          await showDialog(
                            context: context,
                            builder: (_) => SubVendorFinalSettlementCalculatorDialog(assignment: a),
                          );
                          _loadLedger();
                        },
                      ),
                      const SizedBox(width: 8),
                      IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.of(context).pop()),
                    ],
                  ),
                ],
              ),
              const Divider(),
              const SizedBox(height: 6),

              // KPI Row
              Row(
                children: [
                  _kpiCard('Site Amount', _currency.format(a.effectiveSiteAmount), const Color(0xFF0D2B6F)),
                  _kpiCard('Cash Received', _currency.format(a.totalCashReceived), Colors.blueGrey),
                  _kpiCard(
                    'Loan Credited',
                    _currency.format(a.totalLoanCredited),
                    const Color(0xFF047857),
                    sub: a.isBankLoan ? 'Sanctioned: ${_currency.format(a.loanSanctionedAmount)}' : null,
                  ),
                  _kpiCard(
                    'Balance Due',
                    _currency.format(a.effectiveCustomerOutstanding),
                    Colors.deepOrange,
                    sub: a.isBankLoan && a.loanPendingCredit > 0 ? 'Pending Loan: ${_currency.format(a.loanPendingCredit)}' : null,
                  ),
                ],
              ),

              const SizedBox(height: 12),
              const Text('TRANSACTION LEDGER & BANK DISBURSEMENT ENTRIES',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0D2B6F))),
              const SizedBox(height: 6),

              // Payments Table
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _payments.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.receipt_long_outlined, size: 48, color: Colors.grey.shade400),
                                const SizedBox(height: 8),
                                const Text('No payments or bank loan credits recorded yet.'),
                                const SizedBox(height: 6),
                                ElevatedButton(
                                  onPressed: () async {
                                    final res = await showDialog<bool>(
                                      context: context,
                                      builder: (_) => RecordCustomerPaymentDialog(assignment: a),
                                    );
                                    if (res == true) _loadLedger();
                                  },
                                  child: const Text('Record First Payment'),
                                ),
                              ],
                            ),
                          )
                        : Container(
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey.shade300),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: ListView.separated(
                              itemCount: _payments.length,
                              separatorBuilder: (_, __) => const Divider(height: 1),
                              itemBuilder: (context, i) {
                                final p = _payments[i];
                                final isLoan = p.isLoan;
                                return ListTile(
                                  dense: true,
                                  leading: CircleAvatar(
                                    radius: 14,
                                    backgroundColor: isLoan ? const Color(0xFFD1FAE5) : const Color(0xFFE0E7FF),
                                    child: Icon(
                                      isLoan ? Icons.account_balance : Icons.payments,
                                      size: 16,
                                      color: isLoan ? const Color(0xFF047857) : const Color(0xFF4338CA),
                                    ),
                                  ),
                                  title: Row(
                                    children: [
                                      Text(
                                        isLoan ? 'BANK LOAN CREDIT' : 'CASH PAYMENT (${p.paymentStage})',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                          color: isLoan ? const Color(0xFF047857) : const Color(0xFF0D2B6F),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(_dateFormat.format(p.paymentDate), style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                                    ],
                                  ),
                                  subtitle: Text(
                                    [
                                      if (p.referenceNumber != null && p.referenceNumber!.isNotEmpty) 'UTR: ${p.referenceNumber}',
                                      if (p.bankName != null && p.bankName!.isNotEmpty) 'Bank: ${p.bankName}',
                                      if (p.loanApplicationId != null && p.loanApplicationId!.isNotEmpty) 'App ID: ${p.loanApplicationId}',
                                      if (p.remarks != null && p.remarks!.isNotEmpty) 'Notes: ${p.remarks}',
                                    ].join(' | '),
                                    style: const TextStyle(fontSize: 11),
                                  ),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        _currency.format(p.amount),
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                          color: isLoan ? const Color(0xFF047857) : Colors.black87,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      IconButton(
                                        icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                                        tooltip: 'Delete Payment',
                                        onPressed: () => _handleDeletePayment(p.id),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _kpiCard(String title, String value, Color color, {String? sub}) {
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
              const SizedBox(height: 3),
              Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: color)),
              if (sub != null) ...[
                const SizedBox(height: 2),
                Text(sub, style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _paymentTypeChip(String type) {
    Color bg = const Color(0xFFE2E8F0);
    Color fg = const Color(0xFF334155);
    if (type.contains('Bank Loan')) {
      bg = const Color(0xFFDCFCE7);
      fg = const Color(0xFF166534);
    } else if (type.contains('Part')) {
      bg = const Color(0xFFFEF3C7);
      fg = const Color(0xFF92400E);
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(4)),
      child: Text(type, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: fg)),
    );
  }

  Widget _loanStatusChip(String status) {
    Color bg = const Color(0xFFE0E7FF);
    Color fg = const Color(0xFF4338CA);
    if (status == 'Fully Credited') {
      bg = const Color(0xFFDCFCE7);
      fg = const Color(0xFF166534);
    } else if (status == 'Partially Credited') {
      bg = const Color(0xFFFEF3C7);
      fg = const Color(0xFF92400E);
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(4)),
      child: Text(status, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: fg)),
    );
  }
}

// ==============================================================================
// 10. SUB-VENDOR FINAL SETTLEMENT & PAYOUT CALCULATOR DIALOG
// ==============================================================================

class SubVendorFinalSettlementCalculatorDialog extends StatefulWidget {
  final VendorSiteAssignment assignment;
  final SubVendor? vendor;

  const SubVendorFinalSettlementCalculatorDialog({
    super.key,
    required this.assignment,
    this.vendor,
  });

  @override
  State<SubVendorFinalSettlementCalculatorDialog> createState() =>
      _SubVendorFinalSettlementCalculatorDialogState();
}

class _SubVendorFinalSettlementCalculatorDialogState
    extends State<SubVendorFinalSettlementCalculatorDialog> {
  late VendorSiteAssignment _assignment;
  List<VendorMaterialTransaction> _materials = [];
  List<VendorPayout> _previousPayouts = [];
  List<VendorCustomerPayment> _customerPayments = [];

  SubVendorSettlementMode _mode = SubVendorSettlementMode.netBalance;
  double _expectedLoanPercent = 90.0;
  bool _isMarginReceiptOnly = true; // 10% Margin Money is only a bank receipt; excluded from calculation
  bool _use7030GstRule = true; // Default to Statutory 70:30 Split (70% @ 5% + 30% @ 18%)
  double _outputGstRate = 13.8;

  late final TextEditingController _fixedFeeCtrl;
  late final TextEditingController _profitShareCtrl;
  late final TextEditingController _adjustmentsCtrl;
  late final TextEditingController _adjustmentRemarksCtrl;
  late final TextEditingController _notesCtrl;

  SubVendorSettlement? _settlement;
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _assignment = widget.assignment;
    _fixedFeeCtrl = TextEditingController(text: _assignment.vendorCharges.toStringAsFixed(0));
    _profitShareCtrl = TextEditingController(text: '70');
    _adjustmentsCtrl = TextEditingController(text: '0');
    _adjustmentRemarksCtrl = TextEditingController();
    _notesCtrl = TextEditingController();

    _loadDataAndCalculate();
  }

  @override
  void dispose() {
    _fixedFeeCtrl.dispose();
    _profitShareCtrl.dispose();
    _adjustmentsCtrl.dispose();
    _adjustmentRemarksCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadDataAndCalculate() async {
    setState(() => _isLoading = true);
    try {
      final materials = await SubVendorService.fetchSiteMaterials(_assignment.id);
      final allPayouts = await SubVendorService.fetchVendorPayouts(_assignment.vendorId);
      final payments = await SubVendorService.fetchCustomerPayments(assignmentId: _assignment.id);
      final saved = await SubVendorService.fetchSavedSettlement(_assignment.id);

      final sitePayouts = allPayouts.where((p) => p.assignmentId == _assignment.id || p.assignmentId == null).toList();

      if (saved != null) {
        _mode = saved.settlementMode;
        _expectedLoanPercent = saved.expectedLoanPercent;
        _use7030GstRule = saved.use7030GstRule;
        _isMarginReceiptOnly = saved.isMarginReceiptOnly;
        _outputGstRate = saved.outputGstRate;
        _fixedFeeCtrl.text = saved.fixedAgreedFee.toStringAsFixed(0);
        _profitShareCtrl.text = saved.vendorProfitSharePercent.toStringAsFixed(0);
        _adjustmentsCtrl.text = saved.approvedAdjustments.toStringAsFixed(0);
        _adjustmentRemarksCtrl.text = saved.adjustmentRemarks ?? '';
        _notesCtrl.text = saved.notes ?? '';
      }

      _materials = materials;
      _previousPayouts = sitePayouts;
      _customerPayments = payments;

      _recalculate();

      if (mounted) {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _recalculate() {
    final fixedFee = double.tryParse(_fixedFeeCtrl.text.trim()) ?? 0.0;
    final profitShare = double.tryParse(_profitShareCtrl.text.trim()) ?? 70.0;
    final adj = double.tryParse(_adjustmentsCtrl.text.trim()) ?? 0.0;

    _settlement = SubVendorSettlement.compute(
      assignment: _assignment,
      materials: _materials,
      previousPayouts: _previousPayouts,
      customerPayments: _customerPayments,
      settlementMode: _mode,
      expectedLoanPercent: _expectedLoanPercent,
      isMarginReceiptOnly: _isMarginReceiptOnly,
      use7030GstRule: _use7030GstRule,
      outputGstRate: _outputGstRate,
      fixedAgreedFee: fixedFee,
      vendorProfitSharePercent: profitShare,
      approvedAdjustments: adj,
      adjustmentRemarks: _adjustmentRemarksCtrl.text.trim().isNotEmpty
          ? _adjustmentRemarksCtrl.text.trim()
          : null,
      notes: _notesCtrl.text.trim().isNotEmpty ? _notesCtrl.text.trim() : null,
    );
  }

  Future<void> _handleSaveOrApprove({bool approve = false}) async {
    if (_settlement == null) return;
    setState(() => _isSaving = true);
    try {
      final saved = await SubVendorService.saveOrApproveSettlement(
        _settlement!,
        approve: approve,
      );

      if (mounted) {
        setState(() {
          _settlement = saved;
          _isSaving = false;
        });
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              approve
                  ? 'Sub-Vendor final settlement successfully APPROVED!'
                  : 'Settlement calculation draft saved.',
            ),
            backgroundColor: approve ? const Color(0xFF047857) : const Color(0xFF0D2B6F),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save settlement: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _handleDisbursePayout() async {
    if (_settlement == null) return;
    final amt = _settlement!.amountPayableToVendor;
    if (amt <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No positive payout amount payable to disburse.')),
      );
      return;
    }

    final modeCtrl = TextEditingController(text: 'Bank Transfer');
    final refCtrl = TextEditingController();
    final remarksCtrl = TextEditingController(text: 'Final Site Settlement Payout');

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Disburse Settlement Payout'),
          content: SizedBox(
            width: 440,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Vendor: ${_assignment.vendorName ?? "Sub-Vendor"} (${_assignment.vendorCode ?? "VND"})',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text('Site: ${_assignment.customerName} (CA: ${_assignment.consumerNo ?? "-"})'),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: const Color(0xFFECFDF5), borderRadius: BorderRadius.circular(8)),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Disbursement Amount:', style: TextStyle(fontWeight: FontWeight.bold)),
                      Text(_currency.format(amt),
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF047857))),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: refCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Bank UTR / Transaction ID *',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: remarksCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Remarks',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF047857), foregroundColor: Colors.white),
              onPressed: () {
                if (refCtrl.text.trim().isEmpty) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(content: Text('Please enter bank UTR / Txn ID.')),
                  );
                  return;
                }
                Navigator.of(ctx).pop(true);
              },
              child: const Text('Confirm Disbursal'),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;

    try {
      final payout = VendorPayout(
        id: '',
        vendorId: _assignment.vendorId,
        assignmentId: _assignment.id,
        payoutDate: DateTime.now(),
        amount: amt,
        paymentMode: modeCtrl.text.trim(),
        referenceNumber: refCtrl.text.trim(),
        remarks: remarksCtrl.text.trim(),
        status: 'Paid',
      );

      await SubVendorService.recordVendorPayout(payout);
      // Auto-approve settlement
      await _handleSaveOrApprove(approve: true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to record payout: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final a = _assignment;
    final s = _settlement;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 960, maxHeight: 840),
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: _isLoading || s == null
              ? const Center(child: CircularProgressIndicator())
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.calculate_rounded, color: Color(0xFF0D2B6F), size: 24),
                                const SizedBox(width: 8),
                                const Text(
                                  'Sub-Vendor Final Settlement & Payout Calculator',
                                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0D2B6F)),
                                ),
                                const SizedBox(width: 10),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: s.isApproved ? const Color(0xFFDCFCE7) : const Color(0xFFFEF3C7),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(
                                      color: s.isApproved ? const Color(0xFF86EFAC) : const Color(0xFFFDE68A),
                                    ),
                                  ),
                                  child: Text(
                                    s.isApproved ? 'APPROVED SETTLEMENT' : 'CALCULATION DRAFT',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: s.isApproved ? const Color(0xFF166534) : const Color(0xFF92400E),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Site: ${a.customerName} (CA: ${a.consumerNo ?? "-"}) | Sub-Vendor: ${a.vendorName} (${a.vendorCode}) | ${a.siteCapacityKw} kW',
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            ElevatedButton.icon(
                              icon: const Icon(Icons.picture_as_pdf, size: 16),
                              label: const Text('Export Statement PDF'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF0D2B6F),
                                foregroundColor: Colors.white,
                              ),
                              onPressed: () => SubVendorPdfService.printOrShareFinalSettlementStatement(s),
                            ),
                            const SizedBox(width: 8),
                            IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.of(context).pop()),
                          ],
                        ),
                      ],
                    ),
                    const Divider(height: 16),

                    // Scrollable content
                    Expanded(
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // 1. SETTLEMENT MODE SELECTOR (OPTIONS A, B, C)
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: const Color(0xFFCBD5E1)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'निवडा: Sub-Vendor चा हिस्सा ठरवण्याची पद्धत (Settlement Method):',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0D2B6F)),
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: _modeOptionRadio(
                                          mode: SubVendorSettlementMode.netBalance,
                                          title: 'पर्याय A (शिफारस)',
                                          subtitle: 'उरलेली रक्कम पूर्ण Sub-Vendor ची (Net Balance)',
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: _modeOptionRadio(
                                          mode: SubVendorSettlementMode.fixedFee,
                                          title: 'पर्याय B',
                                          subtitle: 'आधी ठरवलेली रक्कम (Fixed Agreed Amount)',
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: _modeOptionRadio(
                                          mode: SubVendorSettlementMode.profitShare,
                                          title: 'पर्याय C',
                                          subtitle: 'उरलेल्या नफ्यातील % (Profit Sharing)',
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (_mode == SubVendorSettlementMode.fixedFee) ...[
                                    const SizedBox(height: 10),
                                    Row(
                                      children: [
                                        const Text('Agreed Fixed Installation Fee: ₹ ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                        SizedBox(
                                          width: 150,
                                          height: 36,
                                          child: TextField(
                                            controller: _fixedFeeCtrl,
                                            keyboardType: TextInputType.number,
                                            decoration: const InputDecoration(border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 10)),
                                            onChanged: (_) => setState(_recalculate),
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Text('Default: ${a.siteCapacityKw} kW × ₹${a.ratePerKw.toStringAsFixed(0)} = ₹${(a.siteCapacityKw * a.ratePerKw).toStringAsFixed(0)}',
                                            style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                                      ],
                                    ),
                                  ] else if (_mode == SubVendorSettlementMode.profitShare) ...[
                                    const SizedBox(height: 10),
                                    Row(
                                      children: [
                                        const Text('Sub-Vendor Profit Share %: ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                        SizedBox(
                                          width: 90,
                                          height: 36,
                                          child: TextField(
                                            controller: _profitShareCtrl,
                                            keyboardType: TextInputType.number,
                                            decoration: const InputDecoration(suffixText: '%', border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 10)),
                                            onChanged: (_) => setState(_recalculate),
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Text('SIYA retains remainder ${(100 - (double.tryParse(_profitShareCtrl.text) ?? 70)).toStringAsFixed(0)}% of net profit',
                                            style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                                      ],
                                    ),
                                  ],
                                  const SizedBox(height: 10),
                                  // GST Calculation Mode Selector
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: const Color(0xFFE2E8F0)),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.receipt_long, size: 16, color: Color(0xFF0D2B6F)),
                                        const SizedBox(width: 8),
                                        const Text(
                                          'GST नियम:',
                                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0D2B6F)),
                                        ),
                                        const SizedBox(width: 10),
                                        ChoiceChip(
                                          label: const Text('Statutory 70:30 Split (70% @ 5% + 30% @ 18%)', style: TextStyle(fontSize: 11)),
                                          selected: _use7030GstRule,
                                          selectedColor: const Color(0xFFDBEAFE),
                                          onSelected: (val) {
                                            if (val) {
                                              setState(() {
                                                _use7030GstRule = true;
                                                _recalculate();
                                              });
                                            }
                                          },
                                        ),
                                        const SizedBox(width: 8),
                                        ChoiceChip(
                                          label: const Text('Flat 13.8% Composite Rate', style: TextStyle(fontSize: 11)),
                                          selected: !_use7030GstRule,
                                          selectedColor: const Color(0xFFFEF3C7),
                                          onSelected: (val) {
                                            if (val) {
                                              setState(() {
                                                _use7030GstRule = false;
                                                _recalculate();
                                              });
                                            }
                                          },
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  // 10% Margin Money Compliance Policy Switch
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: _isMarginReceiptOnly ? const Color(0xFFF0FDF4) : const Color(0xFFFFFBEB),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                        color: _isMarginReceiptOnly ? const Color(0xFF86EFAC) : const Color(0xFFFDE68A),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          _isMarginReceiptOnly ? Icons.check_circle_rounded : Icons.info_outline,
                                          size: 16,
                                          color: _isMarginReceiptOnly ? const Color(0xFF166534) : const Color(0xFFB45309),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            _isMarginReceiptOnly
                                                ? '10% Margin Money ही फक्त बँक पावती आहे (हिशोबात ग्राहकाकडून येणे बाकी धरू नये)'
                                                : '10% Margin ग्राहकाकडून प्रत्यक्ष रोख येणे बाकी म्हणून धरावे',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                              color: _isMarginReceiptOnly ? const Color(0xFF166534) : const Color(0xFF92400E),
                                            ),
                                          ),
                                        ),
                                        Switch(
                                          value: _isMarginReceiptOnly,
                                          activeColor: const Color(0xFF047857),
                                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                          onChanged: (val) {
                                            setState(() {
                                              _isMarginReceiptOnly = val;
                                              _recalculate();
                                            });
                                          },
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 14),

                            // 2. PROMINENT FINAL AMOUNT BANNER
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                              decoration: BoxDecoration(
                                color: s.isRecoverable ? const Color(0xFFDC2626) : const Color(0xFF047857),
                                borderRadius: BorderRadius.circular(10),
                                boxShadow: [
                                  BoxShadow(
                                    color: (s.isRecoverable ? Colors.red : Colors.green).withOpacity(0.2),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        s.isRecoverable
                                            ? 'AMOUNT RECOVERABLE FROM SUB-VENDOR'
                                            : 'FINAL PAYOUT PAYABLE TO SUB-VENDOR',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Calculated strictly from actual realized collection (₹${_currency.format(s.totalActualCollected)})',
                                        style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 12),
                                      ),
                                    ],
                                  ),
                                  Text(
                                    _currency.format(s.isRecoverable ? s.amountRecoverableFromVendor : s.amountPayableToVendor),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 26,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // Future Retained / Receivable alert or Settled Notification
                            if (s.pendingCustomerReceivable > 0) ...[
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFEF3C7),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: const Color(0xFFF59E0B)),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        const Icon(Icons.info_outline, size: 16, color: Color(0xFF92400E)),
                                        const SizedBox(width: 8),
                                        Text(
                                          'Pending Customer/Loan Balance: ${_currency.format(s.pendingCustomerReceivable)} (10% Difference: ${_currency.format(s.pendingCustomerContribution)} | Loan: ${_currency.format(s.pendingLoanDisbursement)})',
                                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF92400E)),
                                        ),
                                      ],
                                    ),
                                    Text(
                                      'Potential Full Payout: ${_currency.format(s.potentialFuturePayoutUponFullCollection)}',
                                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFB45309)),
                                    ),
                                  ],
                                ),
                              ),
                            ] else if (s.isMarginReceiptOnly) ...[
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFECFDF5),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: const Color(0xFFA7F3D0)),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.verified, size: 16, color: Color(0xFF047857)),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'बँक कर्ज पूर्ण जमा (₹${_currency.format(s.actualLoanCredited)}) | 10% Margin Money ही केवळ बँकेसाठी Margin Receipt आहे — हिशोब पूर्ण सेटल झाला आहे (Pending: ₹0.00).',
                                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF065F46)),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],

                            const SizedBox(height: 14),

                            // 3. STEP-BY-STEP CALCULATION AUDIT GRID
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Left Column: Collections & GST
                                Expanded(
                                  child: Column(
                                    children: [
                                      _auditCard(
                                        title: '1. Actual Collections Credited to SIYA',
                                        icon: Icons.savings,
                                        iconColor: const Color(0xFF047857),
                                        items: [
                                          _auditItem('Total Site Quotation (100%)', _currency.format(s.totalQuotation), isBold: true),
                                          _auditItem('Actual Bank Loan Credited', _currency.format(s.actualLoanCredited), color: const Color(0xFF047857)),
                                          if (s.isMarginReceiptOnly)
                                            _auditItem('10% Margin Receipt (Bank Paper Only)', '₹0.00 (Exempt)', color: Colors.grey.shade600)
                                          else
                                            _auditItem('Actual Customer Advance/Cash', _currency.format(s.actualCustomerContribution)),
                                          _auditDivider(),
                                          _auditItem('Total Actual Realized Collection', _currency.format(s.totalActualCollected), isBold: true, color: const Color(0xFF0D2B6F)),
                                          _auditItem('Pending Receivable', _currency.format(s.pendingCustomerReceivable), color: s.pendingCustomerReceivable > 0 ? Colors.deepOrange : const Color(0xFF047857)),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      _auditCard(
                                        title: '2. Statutory GST (Zero Double Deduction)',
                                        icon: Icons.receipt_long,
                                        iconColor: Colors.blueGrey,
                                        items: [
                                          if (s.use7030GstRule) ...[
                                            _auditItem('Output GST (70:30 on Quotation ${_currency.format(s.totalQuotation)})', _currency.format(s.outputGstLiability), isBold: true),
                                            _auditItem('  • Goods Portion (70% @ 5% GST)', _currency.format(s.goodsGst5)),
                                            _auditItem('  • Services Portion (30% @ 18% GST)', _currency.format(s.servicesGst18)),
                                          ] else ...[
                                            _auditItem('Output GST (${s.outputGstRate.toStringAsFixed(1)}% on Quotation)', _currency.format(s.outputGstLiability)),
                                          ],
                                          _auditItem('Eligible Material Input GST Credit', _currency.format(s.eligibleInputGstCredit), color: const Color(0xFF047857)),
                                          _auditDivider(),
                                          _auditItem('Net GST Payable to Govt', _currency.format(s.netGstLiability), isBold: true),
                                          _auditNote(s.use7030GstRule
                                              ? 'Statutory 70:30 Rule: Output GST is calculated on full quotation (${_currency.format(s.totalQuotation)}) [70% Goods @ 5% + 30% Services @ 18%]. Net GST = Output GST minus Eligible Input GST.'
                                              : 'Note: Material cost already includes GST. Net GST is deducted so tax is never subtracted twice.'),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),

                                const SizedBox(width: 14),

                                // Right Column: Deductions & Payout Entitlement
                                Expanded(
                                  child: Column(
                                    children: [
                                      _auditCard(
                                        title: '3. Dynamic Material & SIYA Deductions',
                                        icon: Icons.inventory_2,
                                        iconColor: const Color(0xFF0D2B6F),
                                        items: [
                                          _auditItem('Actual Dynamic Material Cost', _currency.format(s.materialCost), isBold: true, color: const Color(0xFFDC2626)),
                                          _auditItem('SIYA Vendor Charges (${a.siteCapacityKw} kW × ₹1k)', _currency.format(s.siyaVendorCharges), isBold: true),
                                          _auditItem('Other Approved Expenses', _currency.format(s.otherApprovedExpenses)),
                                          _auditItem('Net GST Liability', _currency.format(s.netGstLiability)),
                                          _auditDivider(),
                                          _auditItem('Total Deductions from Collection', _currency.format(s.totalDeductions), isBold: true, color: const Color(0xFFDC2626)),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      _auditCard(
                                        title: '4. Sub-Vendor Payout Entitlement',
                                        icon: Icons.payments,
                                        iconColor: const Color(0xFF047857),
                                        items: [
                                          _auditItem('Gross Sub-Vendor Entitlement', _currency.format(s.subVendorGrossEntitlement), isBold: true, color: const Color(0xFF047857)),
                                          _auditItem('Advances / Payouts Already Paid', '- ${_currency.format(s.previousPayoutsPaid)}', color: Colors.red.shade700),
                                          if (s.approvedAdjustments.abs() > 0.01)
                                            _auditItem('Approved Adjustments', _currency.format(s.approvedAdjustments)),
                                          _auditDivider(),
                                          _auditItem(
                                            s.isRecoverable ? 'Amount Recoverable from Vendor' : 'Net Final Amount Payable Now',
                                            _currency.format(s.isRecoverable ? s.amountRecoverableFromVendor : s.amountPayableToVendor),
                                            isBold: true,
                                            color: s.isRecoverable ? Colors.red : const Color(0xFF047857),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 14),

                            // 4. Adjustments & Notes Accordion
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: _adjustmentsCtrl,
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                                    decoration: const InputDecoration(
                                      labelText: 'Approved Adjustment Amount (₹ +/-)',
                                      hintText: 'e.g. -500 for damage penalty or +1000 for bonus',
                                      border: OutlineInputBorder(),
                                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                    ),
                                    onChanged: (_) => setState(_recalculate),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  flex: 2,
                                  child: TextField(
                                    controller: _adjustmentRemarksCtrl,
                                    decoration: const InputDecoration(
                                      labelText: 'Adjustment Reason / Audit Remarks',
                                      hintText: 'e.g. Structure modification cost adjustment',
                                      border: OutlineInputBorder(),
                                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                    ),
                                    onChanged: (_) => setState(_recalculate),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),

                    const Divider(height: 16),

                    // Actions Row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Last updated: ${_dateFormat.format(DateTime.now())} | Admin approval locks settlement.',
                          style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                        ),
                        Row(
                          children: [
                            OutlinedButton(
                              onPressed: _isSaving ? null : () => _handleSaveOrApprove(approve: false),
                              child: const Text('Save Draft Calculation'),
                            ),
                            const SizedBox(width: 10),
                            ElevatedButton.icon(
                              icon: const Icon(Icons.check_circle_outline, size: 16),
                              label: const Text('Approve Final Settlement'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF0D2B6F),
                                foregroundColor: Colors.white,
                              ),
                              onPressed: _isSaving ? null : () => _handleSaveOrApprove(approve: true),
                            ),
                            if (!s.isRecoverable && s.amountPayableToVendor > 0) ...[
                              const SizedBox(width: 10),
                              ElevatedButton.icon(
                                icon: const Icon(Icons.send_rounded, size: 16),
                                label: const Text('Disburse Payout'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF047857),
                                  foregroundColor: Colors.white,
                                ),
                                onPressed: _isSaving ? null : _handleDisbursePayout,
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _modeOptionRadio({
    required SubVendorSettlementMode mode,
    required String title,
    required String subtitle,
  }) {
    final isSelected = _mode == mode;
    return InkWell(
      onTap: () {
        setState(() {
          _mode = mode;
          _recalculate();
        });
      },
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFEFF6FF) : Colors.white,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isSelected ? const Color(0xFF1D4ED8) : Colors.grey.shade300,
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
                  size: 16,
                  color: isSelected ? const Color(0xFF1D4ED8) : Colors.grey,
                ),
                const SizedBox(width: 6),
                Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: isSelected ? const Color(0xFF1D4ED8) : Colors.black87)),
              ],
            ),
            const SizedBox(height: 3),
            Text(subtitle, style: TextStyle(fontSize: 10, color: Colors.grey.shade700)),
          ],
        ),
      ),
    );
  }

  Widget _auditCard({
    required String title,
    required IconData icon,
    required Color iconColor,
    required List<Widget> items,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: iconColor),
              const SizedBox(width: 6),
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF0D2B6F))),
            ],
          ),
          const SizedBox(height: 8),
          ...items,
        ],
      ),
    );
  }

  Widget _auditItem(String label, String value, {bool isBold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 11, fontWeight: isBold ? FontWeight.bold : FontWeight.normal, color: Colors.grey.shade800)),
          Text(value, style: TextStyle(fontSize: 12, fontWeight: isBold ? FontWeight.bold : FontWeight.w600, color: color ?? Colors.black87)),
        ],
      ),
    );
  }

  Widget _auditDivider() {
    return const Divider(height: 10);
  }

  Widget _auditNote(String note) {
    return Padding(
      padding: const EdgeInsets.only(top: 4.0),
      child: Text(note, style: TextStyle(fontSize: 9.5, fontStyle: FontStyle.italic, color: Colors.grey.shade600)),
    );
  }
}

/// Dialog for Admin to record and approve contractual GST Recovery from Sub-Vendor
class RecordVendorGstRecoveryDialog extends StatefulWidget {
  final SubVendor vendor;
  final List<VendorSiteAssignment> assignments;

  const RecordVendorGstRecoveryDialog({
    super.key,
    required this.vendor,
    required this.assignments,
  });

  @override
  State<RecordVendorGstRecoveryDialog> createState() => _RecordVendorGstRecoveryDialogState();
}

class _RecordVendorGstRecoveryDialogState extends State<RecordVendorGstRecoveryDialog> {
  final _formKey = GlobalKey<FormState>();
  final _taxableCtrl = TextEditingController();
  final _invoiceNoCtrl = TextEditingController();
  final _remarksCtrl = TextEditingController();

  VendorSiteAssignment? _selectedAssignment;
  double _gstRate = 18.0;
  String _recoveryStatus = 'Approved';
  DateTime _recoveryDate = DateTime.now();
  DateTime? _paymentDate;
  bool _isLoading = false;

  double get _calculatedGst {
    final t = double.tryParse(_taxableCtrl.text.trim()) ?? 0.0;
    return double.parse((t * (_gstRate / 100.0)).toStringAsFixed(2));
  }

  double get _calculatedTotal {
    final t = double.tryParse(_taxableCtrl.text.trim()) ?? 0.0;
    return double.parse((t + _calculatedGst).toStringAsFixed(2));
  }

  @override
  void initState() {
    super.initState();
    if (widget.assignments.isNotEmpty) {
      _selectedAssignment = widget.assignments.first;
    }
  }

  @override
  void dispose() {
    _taxableCtrl.dispose();
    _invoiceNoCtrl.dispose();
    _remarksCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedAssignment == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an assigned customer site')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final taxable = double.parse(_taxableCtrl.text.trim());
      final recovery = VendorGstRecovery.calculate(
        assignmentId: _selectedAssignment!.id,
        vendorId: widget.vendor.id,
        taxableValue: taxable,
        gstRate: _gstRate,
        invoiceNumber: _invoiceNoCtrl.text.trim().isNotEmpty ? _invoiceNoCtrl.text.trim() : null,
        recoveryStatus: _recoveryStatus,
        recoveryDate: _recoveryDate,
        paymentDate: _paymentDate,
        remarks: _remarksCtrl.text.trim().isNotEmpty ? _remarksCtrl.text.trim() : null,
        customerName: _selectedAssignment!.customerName,
        consumerNo: _selectedAssignment!.consumerNo,
        vendorName: widget.vendor.name,
        vendorCode: widget.vendor.vendorCode,
      );

      await SubVendorService.recordVendorGstRecovery(recovery);

      if (mounted) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Contractual GST Recovery of ${_currency.format(_calculatedTotal)} recorded successfully!',
            ),
            backgroundColor: const Color(0xFF047857),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to record GST recovery: $e'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 580, maxHeight: 720),
        child: Padding(
          padding: const EdgeInsets.all(22),
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
                      Row(
                        children: const [
                          Icon(Icons.receipt_long, color: Color(0xFF7C3AED)),
                          SizedBox(width: 8),
                          Text(
                            'Record Contractual GST Recovery',
                            style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                  const Divider(),
                  const SizedBox(height: 8),

                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3E8FF),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFDDD6FE)),
                    ),
                    child: const Text(
                      'Admin Control Note: Commercial recovery from the Sub-Vendor must be based on a mutually agreed contractual charge or supply, supported by an official invoice.',
                      style: TextStyle(fontSize: 12, color: Color(0xFF5B21B6)),
                    ),
                  ),
                  const SizedBox(height: 14),

                  DropdownButtonFormField<VendorSiteAssignment>(
                    value: _selectedAssignment,
                    decoration: const InputDecoration(
                      labelText: 'Select Customer Site *',
                      border: OutlineInputBorder(),
                    ),
                    items: widget.assignments.map((a) {
                      return DropdownMenuItem(
                        value: a,
                        child: Text('${a.customerName ?? 'Site'} (${a.consumerNo ?? 'No CA'}) - ${a.siteCapacityKw} kW'),
                      );
                    }).toList(),
                    onChanged: (val) => setState(() => _selectedAssignment = val),
                    validator: (val) => val == null ? 'Site is required' : null,
                  ),
                  const SizedBox(height: 12),

                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: TextFormField(
                          controller: _taxableCtrl,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(
                            labelText: 'Taxable Recovery Value (₹) *',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.currency_rupee),
                          ),
                          onChanged: (_) => setState(() {}),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) return 'Enter taxable amount';
                            final n = double.tryParse(v.trim());
                            if (n == null || n <= 0) return 'Must be greater than 0';
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<double>(
                          value: _gstRate,
                          decoration: const InputDecoration(
                            labelText: 'GST Rate *',
                            border: OutlineInputBorder(),
                          ),
                          items: const [
                            DropdownMenuItem(value: 18.0, child: Text('18% GST')),
                            DropdownMenuItem(value: 5.0, child: Text('5% GST')),
                            DropdownMenuItem(value: 12.0, child: Text('12% GST')),
                            DropdownMenuItem(value: 28.0, child: Text('28% GST')),
                          ],
                          onChanged: (v) => setState(() => _gstRate = v ?? 18.0),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        Column(
                          children: [
                            const Text('GST Amount', style: TextStyle(fontSize: 11, color: Colors.grey)),
                            const SizedBox(height: 4),
                            Text(
                              _currency.format(_calculatedGst),
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF7C3AED)),
                            ),
                          ],
                        ),
                        Container(height: 30, width: 1, color: Colors.grey.shade300),
                        Column(
                          children: [
                            const Text('Total Recovery Due', style: TextStyle(fontSize: 11, color: Colors.grey)),
                            const SizedBox(height: 4),
                            Text(
                              _currency.format(_calculatedTotal),
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF0F172A)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _invoiceNoCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Recovery Invoice / Debit Note No',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.receipt),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _recoveryStatus,
                          decoration: const InputDecoration(
                            labelText: 'Status *',
                            border: OutlineInputBorder(),
                          ),
                          items: const [
                            DropdownMenuItem(value: 'Approved', child: Text('Approved')),
                            DropdownMenuItem(value: 'Pending', child: Text('Pending Approval')),
                            DropdownMenuItem(value: 'Collected', child: Text('Collected / Deducted')),
                          ],
                          onChanged: (v) => setState(() => _recoveryStatus = v ?? 'Approved'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  TextFormField(
                    controller: _remarksCtrl,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Contractual Basis / Remarks',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.notes),
                    ),
                  ),
                  const SizedBox(height: 20),

                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF7C3AED),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      icon: _isLoading
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Icon(Icons.check_circle_outline),
                      label: Text(_isLoading ? 'Saving Entry...' : 'Confirm & Save GST Recovery'),
                      onPressed: _isLoading ? null : _submit,
                    ),
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
// 15. SUB-VENDOR FULL CHRONOLOGICAL ACCOUNT LEDGER DIALOG
// ==============================================================================

class SubVendorFullLedgerDialog extends StatefulWidget {
  final SubVendor vendor;
  final String? initialAssignmentId;

  const SubVendorFullLedgerDialog({
    super.key,
    required this.vendor,
    this.initialAssignmentId,
  });

  @override
  State<SubVendorFullLedgerDialog> createState() => _SubVendorFullLedgerDialogState();
}

class _SubVendorFullLedgerDialogState extends State<SubVendorFullLedgerDialog> {
  bool _isLoading = true;
  List<VendorSiteAssignment> _assignments = [];
  List<VendorMaterialTransaction> _materials = [];
  List<VendorPayout> _payouts = [];
  List<VendorCustomerPayment> _customerPayments = [];
  List<VendorGstRecovery> _gstRecoveries = [];
  String? _selectedAssignmentId;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _selectedAssignmentId = widget.initialAssignmentId;
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final vid = widget.vendor.id;
      final results = await Future.wait([
        SubVendorService.fetchAssignments(vendorId: vid),
        SubVendorService.fetchVendorMaterials(vid),
        SubVendorService.fetchVendorPayouts(vid),
        SubVendorService.fetchCustomerPayments(vendorId: vid),
        SubVendorService.fetchVendorGstRecoveries(vid),
      ]);
      if (mounted) {
        setState(() {
          _assignments = results[0] as List<VendorSiteAssignment>;
          _materials = results[1] as List<VendorMaterialTransaction>;
          _payouts = results[2] as List<VendorPayout>;
          _customerPayments = results[3] as List<VendorCustomerPayment>;
          _gstRecoveries = results[4] as List<VendorGstRecovery>;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _shareViaWhatsApp(SubVendorLedgerSummary ledger) async {
    final cleanMob = (widget.vendor.mobile ?? '').replaceAll(RegExp(r'[^0-9]'), '');
    final msg = '''*SIYA INFOTECH & SOLAR ENERGY*
*Sub-Vendor Account Ledger Statement*
----------------------------------------
*Vendor:* ${widget.vendor.name} (${widget.vendor.vendorCode})
*Date:* ${_dateFormat.format(DateTime.now())}
*Entries:* ${ledger.entries.length} Transactions
----------------------------------------
*Account Summary:*
• Total Credits (जमा): ${_currency.format(ledger.totalCredit)}
• Total Debits (नावे): - ${_currency.format(ledger.totalDebit)}
----------------------------------------
*FINAL NET BALANCE:* *${_currency.format(ledger.closingBalance.abs())}* ${ledger.isPayable ? "(Payable to Vendor)" : "(Recoverable)"}
----------------------------------------
_Statement generated by Siya Data Management Software._''';

    final uri = Uri.parse(cleanMob.isNotEmpty
        ? 'https://wa.me/$cleanMob?text=${Uri.encodeComponent(msg)}'
        : 'https://wa.me/?text=${Uri.encodeComponent(msg)}');

    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        await Clipboard.setData(ClipboardData(text: msg));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Ledger summary copied to clipboard!')),
          );
        }
      }
    } catch (_) {
      await Clipboard.setData(ClipboardData(text: msg));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ledger summary copied to clipboard!')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Dialog(
        child: Padding(
          padding: EdgeInsets.all(32.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Building Sub-Vendor Chronological Ledger...'),
            ],
          ),
        ),
      );
    }

    final ledger = SubVendorLedgerBuilder.buildLedger(
      vendorId: widget.vendor.id,
      vendorName: widget.vendor.name,
      vendorCode: widget.vendor.vendorCode,
      assignments: _assignments,
      materials: _materials,
      payouts: _payouts,
      customerPayments: _customerPayments,
      gstRecoveries: _gstRecoveries,
      filterAssignmentId: _selectedAssignmentId,
    );

    final entries = _searchQuery.trim().isEmpty
        ? ledger.entries
        : ledger.entries.where((e) {
            final q = _searchQuery.trim().toLowerCase();
            return e.particulars.toLowerCase().contains(q) ||
                e.voucherType.toLowerCase().contains(q) ||
                (e.referenceNo?.toLowerCase().contains(q) ?? false) ||
                (e.consumerNo?.toLowerCase().contains(q) ?? false);
          }).toList();

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Container(
        width: 1100,
        height: 750,
        padding: const EdgeInsets.all(20),
        child: Column(
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
                        color: const Color(0xFF0D2B6F).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.menu_book, color: Color(0xFF0D2B6F), size: 24),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${widget.vendor.name} (${widget.vendor.vendorCode}) — Account Ledger (खातावही)',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0D2B6F)),
                        ),
                        Text(
                          'Chronological Debits & Credits Reconciled Statement | Bank A/C: ${widget.vendor.bankName ?? "-"} (${widget.vendor.accountNumber ?? "-"})',
                          style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ],
                ),
                Row(
                  children: [
                    ElevatedButton.icon(
                      icon: const Icon(Icons.picture_as_pdf, size: 14),
                      label: const Text('Export PDF'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0D2B6F),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      onPressed: () => SubVendorPdfService.printOrShareSubVendorFullLedger(
                        summary: ledger,
                        vendor: widget.vendor,
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.chat, size: 14),
                      label: const Text('WhatsApp Share'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF16A34A),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      onPressed: () => _shareViaWhatsApp(ledger),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ],
            ),
            const Divider(height: 20),

            // Summary Banner
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: ledger.isPayable ? const Color(0xFFECFDF5) : const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: ledger.isPayable ? const Color(0xFFA7F3D0) : const Color(0xFFFECACA),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        ledger.isPayable ? Icons.verified : Icons.warning_amber,
                        color: ledger.isPayable ? const Color(0xFF047857) : Colors.red,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        ledger.isPayable
                            ? 'Total Credits (जमा): ${_currency.format(ledger.totalCredit)}  |  Total Debits (नावे): - ${_currency.format(ledger.totalDebit)}'
                            : 'Debits exceed credits by ${_currency.format(ledger.closingBalance.abs())}',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.bold,
                          color: ledger.isPayable ? const Color(0xFF065F46) : Colors.red.shade900,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    'Net Outstanding Balance: ${_currency.format(ledger.closingBalance)}',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      color: ledger.isPayable ? const Color(0xFF047857) : Colors.red.shade800,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Filter Bar
            Row(
              children: [
                Expanded(
                  child: Container(
                    height: 38,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String?>(
                        value: _selectedAssignmentId,
                        isExpanded: true,
                        hint: const Text('All Assigned Sites (सर्व साइट्स)', style: TextStyle(fontSize: 12)),
                        items: [
                          const DropdownMenuItem<String?>(
                            value: null,
                            child: Text('All Sites (Consolidated)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          ),
                          ..._assignments.map((a) => DropdownMenuItem<String?>(
                                value: a.id,
                                child: Text(
                                  '${a.customerName ?? "Site"} (${a.consumerNo ?? "CA"})',
                                  style: const TextStyle(fontSize: 12),
                                ),
                              )),
                        ],
                        onChanged: (val) => setState(() => _selectedAssignmentId = val),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    height: 38,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: TextField(
                      decoration: const InputDecoration(
                        hintText: 'Search particulars / voucher...',
                        hintStyle: TextStyle(fontSize: 11),
                        prefixIcon: Icon(Icons.search, size: 16),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(vertical: 9),
                      ),
                      style: const TextStyle(fontSize: 12),
                      onChanged: (val) => setState(() => _searchQuery = val),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Table
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: entries.isEmpty
                    ? const Center(child: Text('No transactions recorded.', style: TextStyle(color: Colors.grey)))
                    : SingleChildScrollView(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: DataTable(
                            headingRowColor: MaterialStateProperty.all(const Color(0xFFF1F5F9)),
                            dataRowMinHeight: 36,
                            dataRowMaxHeight: 48,
                            horizontalMargin: 12,
                            columnSpacing: 16,
                            columns: const [
                              DataColumn(label: Text('#', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                              DataColumn(label: Text('Date', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                              DataColumn(label: Text('Voucher Type', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                              DataColumn(label: Text('Particulars / Site Reference', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                              DataColumn(label: Text('Ref / UTR', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                              DataColumn(label: Text('Debit (नावे)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFFDC2626)))),
                              DataColumn(label: Text('Credit (जमा)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF047857)))),
                              DataColumn(label: Text('Balance (शिल्लक)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF0D2B6F)))),
                            ],
                            rows: [
                              for (int i = 0; i < entries.length; i++)
                                DataRow(
                                  color: MaterialStateProperty.all(i % 2 == 1 ? const Color(0xFFF8FAFC) : Colors.white),
                                  cells: [
                                    DataCell(Text('${i + 1}', style: const TextStyle(fontSize: 10.5))),
                                    DataCell(Text(_dateFormat.format(entries[i].date), style: const TextStyle(fontSize: 10.5))),
                                    DataCell(
                                      Text(
                                        entries[i].voucherType,
                                        style: TextStyle(
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.bold,
                                          color: entries[i].isCredit ? const Color(0xFF047857) : const Color(0xFF0D2B6F),
                                        ),
                                      ),
                                    ),
                                    DataCell(
                                      SizedBox(
                                        width: 320,
                                        child: Text(
                                          entries[i].particulars,
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: entries[i].isCredit ? FontWeight.bold : FontWeight.normal,
                                          ),
                                        ),
                                      ),
                                    ),
                                    DataCell(Text(entries[i].referenceNo ?? '-', style: const TextStyle(fontSize: 10.5))),
                                    DataCell(
                                      Text(
                                        entries[i].debit > 0 ? _currency.format(entries[i].debit) : '-',
                                        style: const TextStyle(fontSize: 11, color: Color(0xFFDC2626), fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                    DataCell(
                                      Text(
                                        entries[i].credit > 0 ? _currency.format(entries[i].credit) : '-',
                                        style: const TextStyle(fontSize: 11, color: Color(0xFF047857), fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                    DataCell(
                                      Text(
                                        _currency.format(entries[i].runningBalance),
                                        style: TextStyle(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w900,
                                          color: entries[i].runningBalance >= 0 ? const Color(0xFF047857) : Colors.red.shade800,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              // Total Row
                              DataRow(
                                color: MaterialStateProperty.all(const Color(0xFFEFF6FF)),
                                cells: [
                                  const DataCell(Text('')),
                                  const DataCell(Text('')),
                                  const DataCell(Text('')),
                                  const DataCell(Text('TOTALS & CLOSING NET BALANCE', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5, color: Color(0xFF0D2B6F)))),
                                  const DataCell(Text('')),
                                  DataCell(Text(_currency.format(ledger.totalDebit), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5, color: Color(0xFFDC2626)))),
                                  DataCell(Text(_currency.format(ledger.totalCredit), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5, color: Color(0xFF047857)))),
                                  DataCell(
                                    Text(
                                      _currency.format(ledger.closingBalance),
                                      style: TextStyle(
                                        fontWeight: FontWeight.w900,
                                        fontSize: 12.5,
                                        color: ledger.closingBalance >= 0 ? const Color(0xFF047857) : Colors.red.shade800,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
