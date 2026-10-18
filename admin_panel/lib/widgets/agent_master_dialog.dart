import 'package:flutter/material.dart';
import '../models/agent_master.dart';
import '../services/commission_service.dart';

/// Modal dialog to manage Agent Master records
class AgentMasterDialog extends StatefulWidget {
  final VoidCallback? onAgentListChanged;

  const AgentMasterDialog({super.key, this.onAgentListChanged});

  static Future<void> show(BuildContext context, {VoidCallback? onAgentListChanged}) {
    return showDialog(
      context: context,
      builder: (_) => AgentMasterDialog(onAgentListChanged: onAgentListChanged),
    );
  }

  @override
  State<AgentMasterDialog> createState() => _AgentMasterDialogState();
}

class _AgentMasterDialogState extends State<AgentMasterDialog> {
  List<AgentMaster> _agents = [];
  bool _isLoading = true;
  bool _isCreating = false;

  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _mobileController = TextEditingController();
  final _agencyController = TextEditingController();
  final _addressController = TextEditingController();
  final _panController = TextEditingController();
  final _bankController = TextEditingController();
  final _accountController = TextEditingController();
  final _ifscController = TextEditingController();
  final _upiController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadAgents();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _mobileController.dispose();
    _agencyController.dispose();
    _addressController.dispose();
    _panController.dispose();
    _bankController.dispose();
    _accountController.dispose();
    _ifscController.dispose();
    _upiController.dispose();
    super.dispose();
  }

  Future<void> _loadAgents() async {
    setState(() => _isLoading = true);
    final list = await CommissionService.fetchAgents();
    if (mounted) {
      setState(() {
        _agents = list;
        _isLoading = false;
      });
    }
  }

  Future<void> _handleCreateAgent() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isCreating = true);
    try {
      await CommissionService.createAgent(
        name: _nameController.text.trim(),
        mobile: _mobileController.text.trim().isNotEmpty ? _mobileController.text.trim() : null,
        agencyName: _agencyController.text.trim().isNotEmpty ? _agencyController.text.trim() : null,
        address: _addressController.text.trim().isNotEmpty ? _addressController.text.trim() : null,
        panNumber: _panController.text.trim().isNotEmpty ? _panController.text.trim() : null,
        bankName: _bankController.text.trim().isNotEmpty ? _bankController.text.trim() : null,
        accountNumber: _accountController.text.trim().isNotEmpty ? _accountController.text.trim() : null,
        ifscCode: _ifscController.text.trim().isNotEmpty ? _ifscController.text.trim() : null,
        upiId: _upiController.text.trim().isNotEmpty ? _upiController.text.trim() : null,
      );

      _clearForm();
      await _loadAgents();
      widget.onAgentListChanged?.call();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Agent registered successfully in Agent Master!'),
            backgroundColor: Color(0xFF16A34A),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save agent: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isCreating = false);
    }
  }

  void _clearForm() {
    _nameController.clear();
    _mobileController.clear();
    _agencyController.clear();
    _addressController.clear();
    _panController.clear();
    _bankController.clear();
    _accountController.clear();
    _ifscController.clear();
    _upiController.clear();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDesktop = MediaQuery.of(context).size.width >= 800;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Container(
        width: isDesktop ? 860 : double.infinity,
        height: 640,
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
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
                      const Text(
                        'Agent Master (एजंट मास्टर)',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Manage verified commission agents and bank details for payouts',
                        style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const Divider(height: 28),

            // Body: Split or Single View
            Expanded(
              child: isDesktop ? _buildDesktopLayout() : _buildMobileLayout(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDesktopLayout() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left: Agent Form
        Expanded(
          flex: 5,
          child: SingleChildScrollView(
            child: _buildAgentForm(),
          ),
        ),
        const VerticalDivider(width: 32),
        // Right: Agent List
        Expanded(
          flex: 6,
          child: _buildAgentList(),
        ),
      ],
    );
  }

  Widget _buildMobileLayout() {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          const TabBar(
            tabs: [
              Tab(text: 'Agents List', icon: Icon(Icons.list)),
              Tab(text: '+ New Agent', icon: Icon(Icons.person_add)),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: TabBarView(
              children: [
                _buildAgentList(),
                SingleChildScrollView(child: _buildAgentForm()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAgentForm() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Add New Agent', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 12),
          TextFormField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Agent Full Name *',
              prefixIcon: Icon(Icons.person),
              isDense: true,
            ),
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Please enter agent name' : null,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _mobileController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Mobile Number *',
                    prefixIcon: Icon(Icons.phone),
                    isDense: true,
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter mobile' : null,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextFormField(
                  controller: _agencyController,
                  decoration: const InputDecoration(
                    labelText: 'Agency Name',
                    prefixIcon: Icon(Icons.business),
                    isDense: true,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _addressController,
            decoration: const InputDecoration(
              labelText: 'Address / Location',
              prefixIcon: Icon(Icons.location_on_outlined),
              isDense: true,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _bankController,
                  decoration: const InputDecoration(
                    labelText: 'Bank Name',
                    prefixIcon: Icon(Icons.account_balance),
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextFormField(
                  controller: _accountController,
                  decoration: const InputDecoration(
                    labelText: 'Account No.',
                    prefixIcon: Icon(Icons.numbers),
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
                  controller: _ifscController,
                  decoration: const InputDecoration(
                    labelText: 'IFSC Code',
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextFormField(
                  controller: _upiController,
                  decoration: const InputDecoration(
                    labelText: 'UPI ID',
                    isDense: true,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 42,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFF57C00),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              icon: _isCreating
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.save),
              label: Text(_isCreating ? 'Saving...' : 'Save Agent'),
              onPressed: _isCreating ? null : _handleCreateAgent,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAgentList() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_agents.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.person_off_outlined, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            const Text('No agents registered in Agent Master yet.'),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Existing Agents (${_agents.length})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            IconButton(
              icon: const Icon(Icons.refresh, size: 20),
              tooltip: 'Refresh Agents',
              onPressed: _loadAgents,
            ),
          ],
        ),
        const SizedBox(height: 8),
        Expanded(
          child: ListView.separated(
            itemCount: _agents.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final a = _agents[index];
              return ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                leading: CircleAvatar(
                  backgroundColor: const Color(0xFFF57C00).withValues(alpha: 0.15),
                  child: Text(
                    a.name.isNotEmpty ? a.name[0].toUpperCase() : 'A',
                    style: const TextStyle(color: Color(0xFFF57C00), fontWeight: FontWeight.bold),
                  ),
                ),
                title: Text(a.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                subtitle: Text(
                  '${a.agencyName ?? "Independent"} • Mobile: ${a.mobile ?? "N/A"}\nBank: ${a.bankName ?? "N/A"} (${a.accountNumber ?? "-"})',
                  style: const TextStyle(fontSize: 11),
                ),
                trailing: Chip(
                  label: Text(a.isActive ? 'Active' : 'Inactive'),
                  labelStyle: TextStyle(
                    fontSize: 10,
                    color: a.isActive ? Colors.green.shade800 : Colors.grey.shade600,
                  ),
                  backgroundColor: a.isActive ? Colors.green.shade50 : Colors.grey.shade100,
                  padding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
