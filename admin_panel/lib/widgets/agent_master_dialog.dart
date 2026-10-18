import 'package:flutter/material.dart';
import '../models/agent_master.dart';
import '../services/commission_service.dart';

/// Modal dialog to manage Agent Master records (Full CRUD: Create, Read, Update, Delete)
class AgentMasterDialog extends StatefulWidget {
  final VoidCallback? onAgentListChanged;
  final AgentMaster? initialEditAgent;

  const AgentMasterDialog({
    super.key,
    this.onAgentListChanged,
    this.initialEditAgent,
  });

  static Future<void> show(
    BuildContext context, {
    VoidCallback? onAgentListChanged,
    AgentMaster? initialEditAgent,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AgentMasterDialog(
        onAgentListChanged: onAgentListChanged,
        initialEditAgent: initialEditAgent,
      ),
    );
  }

  @override
  State<AgentMasterDialog> createState() => _AgentMasterDialogState();
}

class _AgentMasterDialogState extends State<AgentMasterDialog> with SingleTickerProviderStateMixin {
  List<AgentMaster> _allAgents = [];
  List<AgentMaster> _filteredAgents = [];
  bool _isLoading = true;
  bool _isSaving = false;

  // Search & Filter
  final TextEditingController _searchController = TextEditingController();
  String _statusFilter = 'All'; // 'All', 'Active', 'Inactive'

  // Edit Mode state
  AgentMaster? _editingAgent;

  // Form Controllers
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _mobileController = TextEditingController();
  final _emailController = TextEditingController();
  final _agencyController = TextEditingController();
  final _addressController = TextEditingController();
  final _panController = TextEditingController();
  final _bankController = TextEditingController();
  final _accountController = TextEditingController();
  final _ifscController = TextEditingController();
  final _upiController = TextEditingController();
  bool _isActiveFormValue = true;

  TabController? _mobileTabController;

  @override
  void initState() {
    super.initState();
    _mobileTabController = TabController(length: 2, vsync: this);
    _loadAgents();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _nameController.dispose();
    _mobileController.dispose();
    _emailController.dispose();
    _agencyController.dispose();
    _addressController.dispose();
    _panController.dispose();
    _bankController.dispose();
    _accountController.dispose();
    _ifscController.dispose();
    _upiController.dispose();
    _mobileTabController?.dispose();
    super.dispose();
  }

  Future<void> _loadAgents() async {
    setState(() => _isLoading = true);
    final list = await CommissionService.fetchAgents();
    if (mounted) {
      setState(() {
        _allAgents = list;
        _isLoading = false;
        _applyFilters();
      });

      if (widget.initialEditAgent != null && _editingAgent == null) {
        _startEditing(widget.initialEditAgent!);
      }
    }
  }

  void _applyFilters() {
    List<AgentMaster> list = List.from(_allAgents);

    // Status Filter
    if (_statusFilter == 'Active') {
      list = list.where((a) => a.isActive).toList();
    } else if (_statusFilter == 'Inactive') {
      list = list.where((a) => !a.isActive).toList();
    }

    // Search Query
    final query = _searchController.text.trim().toLowerCase();
    if (query.isNotEmpty) {
      list = list.where((a) {
        return a.name.toLowerCase().contains(query) ||
            (a.mobile != null && a.mobile!.toLowerCase().contains(query)) ||
            (a.agencyName != null && a.agencyName!.toLowerCase().contains(query)) ||
            (a.address != null && a.address!.toLowerCase().contains(query)) ||
            (a.bankName != null && a.bankName!.toLowerCase().contains(query)) ||
            (a.panNumber != null && a.panNumber!.toLowerCase().contains(query));
      }).toList();
    }

    setState(() => _filteredAgents = list);
  }

  // ---------------------------------------------------------------------------
  // Form Operations: Populate / Clear / Save / Update / Delete
  // ---------------------------------------------------------------------------

  void _startEditing(AgentMaster agent) {
    setState(() {
      _editingAgent = agent;
      _nameController.text = agent.name;
      _mobileController.text = agent.mobile ?? '';
      _emailController.text = agent.email ?? '';
      _agencyController.text = agent.agencyName ?? '';
      _addressController.text = agent.address ?? '';
      _panController.text = agent.panNumber ?? '';
      _bankController.text = agent.bankName ?? '';
      _accountController.text = agent.accountNumber ?? '';
      _ifscController.text = agent.ifscCode ?? '';
      _upiController.text = agent.upiId ?? '';
      _isActiveFormValue = agent.isActive;
    });

    // On mobile, switch to tab index 1 (Form)
    if (_mobileTabController != null && _mobileTabController!.index != 1) {
      _mobileTabController!.animateTo(1);
    }
  }

  void _cancelEditing() {
    setState(() {
      _editingAgent = null;
      _clearForm();
    });
  }

  void _clearForm() {
    _nameController.clear();
    _mobileController.clear();
    _emailController.clear();
    _agencyController.clear();
    _addressController.clear();
    _panController.clear();
    _bankController.clear();
    _accountController.clear();
    _ifscController.clear();
    _upiController.clear();
    _isActiveFormValue = true;
  }

  Future<void> _handleSubmitForm() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    try {
      if (_editingAgent == null) {
        // CREATE NEW AGENT
        await CommissionService.createAgent(
          name: _nameController.text.trim(),
          mobile: _mobileController.text.trim().isNotEmpty ? _mobileController.text.trim() : null,
          email: _emailController.text.trim().isNotEmpty ? _emailController.text.trim() : null,
          agencyName: _agencyController.text.trim().isNotEmpty ? _agencyController.text.trim() : null,
          address: _addressController.text.trim().isNotEmpty ? _addressController.text.trim() : null,
          panNumber: _panController.text.trim().isNotEmpty ? _panController.text.trim() : null,
          bankName: _bankController.text.trim().isNotEmpty ? _bankController.text.trim() : null,
          accountNumber: _accountController.text.trim().isNotEmpty ? _accountController.text.trim() : null,
          ifscCode: _ifscController.text.trim().isNotEmpty ? _ifscController.text.trim() : null,
          upiId: _upiController.text.trim().isNotEmpty ? _upiController.text.trim() : null,
          isActive: _isActiveFormValue,
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Agent registered successfully in Agent Master!'),
              backgroundColor: Color(0xFF16A34A),
            ),
          );
        }
      } else {
        // UPDATE EXISTING AGENT
        final updated = _editingAgent!.copyWith(
          name: _nameController.text.trim(),
          mobile: _mobileController.text.trim().isNotEmpty ? _mobileController.text.trim() : null,
          email: _emailController.text.trim().isNotEmpty ? _emailController.text.trim() : null,
          agencyName: _agencyController.text.trim().isNotEmpty ? _agencyController.text.trim() : null,
          address: _addressController.text.trim().isNotEmpty ? _addressController.text.trim() : null,
          panNumber: _panController.text.trim().isNotEmpty ? _panController.text.trim() : null,
          bankName: _bankController.text.trim().isNotEmpty ? _bankController.text.trim() : null,
          accountNumber: _accountController.text.trim().isNotEmpty ? _accountController.text.trim() : null,
          ifscCode: _ifscController.text.trim().isNotEmpty ? _ifscController.text.trim() : null,
          upiId: _upiController.text.trim().isNotEmpty ? _upiController.text.trim() : null,
          isActive: _isActiveFormValue,
        );

        await CommissionService.updateAgent(updated);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Agent "${updated.name}" updated successfully!'),
              backgroundColor: const Color(0xFF0284C7),
            ),
          );
        }
      }

      _cancelEditing();
      await _loadAgents();
      widget.onAgentListChanged?.call();

      // On mobile, switch back to list view
      if (_mobileTabController != null && _mobileTabController!.index != 0) {
        _mobileTabController!.animateTo(0);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save agent: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _handleDeleteAgent(AgentMaster agent) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 24),
            const SizedBox(width: 8),
            Text('Delete Agent (${agent.name})?'),
          ],
        ),
        content: Text(
          'Are you sure you want to delete agent "${agent.name}"?\n\n'
          'Existing commission records and payment history linked to this agent will remain safe in the system.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete Agent (हटवा)'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => _isLoading = true);
      await CommissionService.deleteAgent(agent.id);

      if (_editingAgent?.id == agent.id) {
        _cancelEditing();
      }

      await _loadAgents();
      widget.onAgentListChanged?.call();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Agent "${agent.name}" deleted from master.')),
        );
      }
    }
  }

  Future<void> _handleToggleActive(AgentMaster agent, bool newValue) async {
    await CommissionService.toggleAgentActiveStatus(agent.id, newValue);
    await _loadAgents();
    widget.onAgentListChanged?.call();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Agent "${agent.name}" marked as ${newValue ? "Active" : "Inactive"}.'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  // ---------------------------------------------------------------------------
  // UI Builder
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDesktop = MediaQuery.of(context).size.width >= 900;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: Container(
        width: isDesktop ? 960 : double.infinity,
        height: 680,
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Header
            _buildHeader(theme),

            const Divider(height: 20),

            // 2. Body: Split or Tabbed Layout
            Expanded(
              child: isDesktop ? _buildDesktopLayout() : _buildMobileLayout(),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Header
  // ---------------------------------------------------------------------------

  Widget _buildHeader(ThemeData theme) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFFF57C00).withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.people_outline, color: Color(0xFFF57C00), size: 24),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Text(
                    'Agent Master (एजंट मास्टर व्यवस्थापन)',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(width: 8),
                  Chip(
                    label: Text('CRUD Enabled', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF15803D))),
                    backgroundColor: Color(0xFFDCFCE7),
                    padding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
              Text(
                'Add, edit, deactivate, or delete verified agents and bank details for payouts',
                style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
        IconButton(
          icon: const Icon(Icons.close),
          tooltip: 'Close',
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Desktop Layout (Split View: Form on Left, List on Right)
  // ---------------------------------------------------------------------------

  Widget _buildDesktopLayout() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left Column: Agent Create/Edit Form
        Expanded(
          flex: 5,
          child: SingleChildScrollView(
            padding: const EdgeInsets.only(right: 12),
            child: _buildAgentForm(),
          ),
        ),

        const VerticalDivider(width: 24),

        // Right Column: Agent List & Search
        Expanded(
          flex: 6,
          child: _buildAgentListSection(),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Mobile Layout (Tabbed View: List & Form Tabs)
  // ---------------------------------------------------------------------------

  Widget _buildMobileLayout() {
    return Column(
      children: [
        TabBar(
          controller: _mobileTabController,
          labelColor: const Color(0xFFF57C00),
          indicatorColor: const Color(0xFFF57C00),
          tabs: [
            Tab(text: 'Agents List (${_allAgents.length})', icon: const Icon(Icons.list)),
            Tab(
              text: _editingAgent != null ? 'Edit Agent' : '+ Add Agent',
              icon: Icon(_editingAgent != null ? Icons.edit : Icons.person_add),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Expanded(
          child: TabBarView(
            controller: _mobileTabController,
            children: [
              _buildAgentListSection(),
              SingleChildScrollView(child: _buildAgentForm()),
            ],
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Agent Form (Create / Edit Modes)
  // ---------------------------------------------------------------------------

  Widget _buildAgentForm() {
    final isEditing = _editingAgent != null;

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Form Mode Banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isEditing ? Colors.blue.shade50 : const Color(0xFFFFF7ED),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: isEditing ? Colors.blue.shade300 : const Color(0xFFFED7AA)),
            ),
            child: Row(
              children: [
                Icon(
                  isEditing ? Icons.edit_note : Icons.person_add_alt_1,
                  color: isEditing ? const Color(0xFF0284C7) : const Color(0xFFF57C00),
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isEditing ? 'Editing Agent: ${_editingAgent!.name}' : 'Add New Commission Agent',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: isEditing ? const Color(0xFF0369A1) : const Color(0xFFC2410C),
                    ),
                  ),
                ),
                if (isEditing)
                  TextButton.icon(
                    style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                    icon: const Icon(Icons.cancel, size: 16),
                    label: const Text('Cancel Edit', style: TextStyle(fontSize: 12)),
                    onPressed: _cancelEditing,
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Agent Name
          TextFormField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Agent Full Name (एजंटचे नाव) *',
              hintText: 'e.g. Sunil Patil',
              prefixIcon: Icon(Icons.person),
              isDense: true,
            ),
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Please enter agent name' : null,
          ),
          const SizedBox(height: 10),

          // Mobile & Email
          Row(
            children: [
              Expanded(
                flex: 5,
                child: TextFormField(
                  controller: _mobileController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Mobile Number *',
                    hintText: '9822011223',
                    prefixIcon: Icon(Icons.phone),
                    isDense: true,
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter mobile' : null,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 6,
                child: TextFormField(
                  controller: _agencyController,
                  decoration: const InputDecoration(
                    labelText: 'Agency / Enterprise',
                    hintText: 'e.g. Patil Solar',
                    prefixIcon: Icon(Icons.business),
                    isDense: true,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Email & Address
          Row(
            children: [
              Expanded(
                flex: 5,
                child: TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Email Address',
                    hintText: 'agent@gmail.com',
                    prefixIcon: Icon(Icons.email_outlined),
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 6,
                child: TextFormField(
                  controller: _addressController,
                  decoration: const InputDecoration(
                    labelText: 'Address / Taluka / City',
                    hintText: 'e.g. Dhule, Maharashtra',
                    prefixIcon: Icon(Icons.location_on_outlined),
                    isDense: true,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // PAN & UPI
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _panController,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(
                    labelText: 'PAN Number',
                    hintText: 'ABCDE1234F',
                    prefixIcon: Icon(Icons.credit_card),
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextFormField(
                  controller: _upiController,
                  decoration: const InputDecoration(
                    labelText: 'UPI ID for Payouts',
                    hintText: 'agent@oksbi',
                    prefixIcon: Icon(Icons.qr_code),
                    isDense: true,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Bank Details Box
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Bank Account Details (कमिशन जमा करण्याचे बँक तपशील)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 11)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      flex: 5,
                      child: TextFormField(
                        controller: _bankController,
                        decoration: const InputDecoration(
                          labelText: 'Bank Name',
                          hintText: 'State Bank of India',
                          prefixIcon: Icon(Icons.account_balance),
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 6,
                      child: TextFormField(
                        controller: _accountController,
                        decoration: const InputDecoration(
                          labelText: 'Account Number',
                          hintText: '31234567890',
                          prefixIcon: Icon(Icons.numbers),
                          isDense: true,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _ifscController,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(
                    labelText: 'IFSC Code',
                    hintText: 'SBIN0004798',
                    prefixIcon: Icon(Icons.pin),
                    isDense: true,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Active Status Switch
          SwitchListTile(
            title: const Text('Active Status (सक्रिय एजंट)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
            subtitle: Text(
              _isActiveFormValue
                  ? 'Active: Agent will appear in commission entry dropdowns'
                  : 'Inactive: Agent is hidden from new entry dropdowns',
              style: const TextStyle(fontSize: 11),
            ),
            value: _isActiveFormValue,
            activeColor: const Color(0xFF16A34A),
            dense: true,
            contentPadding: EdgeInsets.zero,
            onChanged: (val) => setState(() => _isActiveFormValue = val),
          ),
          const SizedBox(height: 14),

          // Save / Update Action Buttons
          Row(
            children: [
              if (isEditing)
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isSaving ? null : _cancelEditing,
                    child: const Text('Cancel'),
                  ),
                ),
              if (isEditing) const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: isEditing ? const Color(0xFF0284C7) : const Color(0xFFF57C00),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: _isSaving
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Icon(isEditing ? Icons.check : Icons.save),
                  label: Text(
                    _isSaving
                        ? (isEditing ? 'Updating...' : 'Saving...')
                        : (isEditing ? 'Update Agent (बदल जतन करा)' : 'Save Agent (एजंट जतन करा)'),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  onPressed: _isSaving ? null : _handleSubmitForm,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Agent List & Search Section
  // ---------------------------------------------------------------------------

  Widget _buildAgentListSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Search & Filter Header
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 38,
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search agent, mobile, agency, city...',
                    hintStyle: const TextStyle(fontSize: 12),
                    prefixIcon: const Icon(Icons.search, size: 18),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 16),
                            onPressed: () {
                              _searchController.clear();
                              _applyFilters();
                            },
                          )
                        : null,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                  onChanged: (_) => _applyFilters(),
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.refresh, size: 20),
              tooltip: 'Refresh Agents',
              onPressed: _loadAgents,
            ),
          ],
        ),
        const SizedBox(height: 8),

        // Status Filter Chips
        Row(
          children: [
            _buildStatusFilterChip('All', _allAgents.length),
            const SizedBox(width: 6),
            _buildStatusFilterChip('Active', _allAgents.where((a) => a.isActive).length),
            const SizedBox(width: 6),
            _buildStatusFilterChip('Inactive', _allAgents.where((a) => !a.isActive).length),
          ],
        ),
        const SizedBox(height: 10),

        // List View
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _filteredAgents.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.person_off_outlined, size: 44, color: Colors.grey.shade400),
                          const SizedBox(height: 10),
                          Text(
                            _searchController.text.isNotEmpty
                                ? 'No agents match "${_searchController.text}"'
                                : 'No agents found.',
                            style: const TextStyle(color: Colors.black54),
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      itemCount: _filteredAgents.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final a = _filteredAgents[index];
                        final isSelectedForEdit = _editingAgent?.id == a.id;

                        return Container(
                          decoration: BoxDecoration(
                            color: isSelectedForEdit
                                ? Colors.blue.shade50
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            leading: CircleAvatar(
                              backgroundColor: a.isActive
                                  ? const Color(0xFFF57C00).withValues(alpha: 0.15)
                                  : Colors.grey.shade200,
                              child: Text(
                                a.name.isNotEmpty ? a.name[0].toUpperCase() : 'A',
                                style: TextStyle(
                                  color: a.isActive ? const Color(0xFFF57C00) : Colors.grey.shade600,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            title: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    a.name,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                  ),
                                ),
                                Chip(
                                  label: Text(a.isActive ? 'Active' : 'Inactive'),
                                  labelStyle: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                    color: a.isActive ? Colors.green.shade800 : Colors.grey.shade600,
                                  ),
                                  backgroundColor: a.isActive ? Colors.green.shade50 : Colors.grey.shade100,
                                  padding: EdgeInsets.zero,
                                  visualDensity: VisualDensity.compact,
                                ),
                              ],
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 2),
                                Text(
                                  '${a.agencyName != null && a.agencyName!.isNotEmpty ? a.agencyName! : "Independent"} • Mobile: ${a.mobile ?? "N/A"}${a.address != null ? " • ${a.address}" : ""}',
                                  style: const TextStyle(fontSize: 11),
                                ),
                                if (a.bankName != null || a.accountNumber != null || a.upiId != null) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    '${a.bankName != null ? a.bankName! : ""}${a.accountNumber != null ? " (A/c: ${a.accountNumber})" : ""}${a.ifscCode != null ? " IFSC: ${a.ifscCode}" : ""}${a.upiId != null ? " • UPI: ${a.upiId}" : ""}',
                                    style: TextStyle(fontSize: 10, color: Colors.blueGrey.shade700),
                                  ),
                                ],
                              ],
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Edit Agent Button
                                IconButton(
                                  icon: const Icon(Icons.edit_outlined, size: 18, color: Color(0xFF0284C7)),
                                  tooltip: 'Edit Agent (संपादित करा)',
                                  onPressed: () => _startEditing(a),
                                ),
                                // Delete Agent Button
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                                  tooltip: 'Delete Agent (हटवा)',
                                  onPressed: () => _handleDeleteAgent(a),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }

  Widget _buildStatusFilterChip(String status, int count) {
    final isSelected = _statusFilter == status;
    return FilterChip(
      selected: isSelected,
      label: Text('$status ($count)', style: const TextStyle(fontSize: 11)),
      selectedColor: const Color(0xFFF57C00),
      labelStyle: TextStyle(
        fontSize: 11,
        color: isSelected ? Colors.white : Colors.black87,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      checkmarkColor: Colors.white,
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      onSelected: (_) {
        setState(() {
          _statusFilter = status;
          _applyFilters();
        });
      },
    );
  }
}
