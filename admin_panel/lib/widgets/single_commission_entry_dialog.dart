import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/agent_master.dart';
import '../models/commission_record.dart';
import '../models/consumer_record.dart';
import '../services/commission_service.dart';
import '../screens/bulk_commission_entry_screen.dart';
import 'agent_master_dialog.dart';

/// Calculation Mode for Single Commission Entry
enum CommissionCalcMode {
  fixedAmount('Fixed Amount', 'थेट रक्कम'),
  perKw('Rate per kW', 'प्रति किलोवॅट दर');

  final String label;
  final String marathiLabel;
  const CommissionCalcMode(this.label, this.marathiLabel);
}

/// Dialog / Screen for entering commission records one-by-one (एका वेळी एक नोंद)
///
/// Features:
/// - Quick Agent Selection + inline "+ New Agent" creation
/// - Customer live autocomplete from database (consumer_records) with auto-fill
///   for Customer Name, Consumer Number, and Solar Capacity (kW)
/// - Calculation Modes: Fixed Lump Sum or Rate per kW with auto-computation
/// - Live Duplicate Detection warning if agent + customer + month exists
/// - "Save & Add Another" button: immediately saves to DB, keeps agent & date,
///   clears customer fields, and refocuses for rapid sequential entries
/// - "Save & Close" button: saves and dismisses
/// - "Switch to Bulk Entry" shortcut
class SingleCommissionEntryDialog extends StatefulWidget {
  final VoidCallback? onEntrySaved;
  final AgentMaster? initialAgent;

  const SingleCommissionEntryDialog({
    super.key,
    this.onEntrySaved,
    this.initialAgent,
  });

  static Future<void> show(
    BuildContext context, {
    VoidCallback? onEntrySaved,
    AgentMaster? initialAgent,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => SingleCommissionEntryDialog(
        onEntrySaved: onEntrySaved,
        initialAgent: initialAgent,
      ),
    );
  }

  @override
  State<SingleCommissionEntryDialog> createState() => _SingleCommissionEntryDialogState();
}

class _SingleCommissionEntryDialogState extends State<SingleCommissionEntryDialog> {
  final _formKey = GlobalKey<FormState>();

  // Data states
  List<AgentMaster> _agents = [];
  AgentMaster? _selectedAgent;
  DateTime _commissionDate = DateTime.now();
  String? _selectedCustomerId;
  CommissionDuplicateWarning? _duplicateWarning;

  // Controllers
  final TextEditingController _customerNameController = TextEditingController();
  final TextEditingController _consumerNoController = TextEditingController();
  final TextEditingController _capacityController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _ratePerKwController = TextEditingController(text: '1500');
  final TextEditingController _remarksController = TextEditingController();

  final FocusNode _customerFocusNode = FocusNode();

  // Mode and Status
  CommissionCalcMode _calcMode = CommissionCalcMode.fixedAmount;
  String _status = CommissionStatus.pendingApproval;

  // State flags
  bool _isLoadingAgents = true;
  bool _isSaving = false;
  int _sessionSavedCount = 0;

  // Search cache
  final Map<String, List<ConsumerRecord>> _customerSearchCache = {};

  final _currencyFormat = NumberFormat('#,##,##0.00', 'en_IN');
  final _dateFormat = DateFormat('dd MMM yyyy');

  @override
  void initState() {
    super.initState();
    _loadAgents();
  }

  @override
  void dispose() {
    _customerNameController.dispose();
    _consumerNoController.dispose();
    _capacityController.dispose();
    _amountController.dispose();
    _ratePerKwController.dispose();
    _remarksController.dispose();
    _customerFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadAgents() async {
    setState(() => _isLoadingAgents = true);
    final agents = await CommissionService.fetchAgents();
    if (mounted) {
      setState(() {
        _agents = agents;
        if (_selectedAgent == null) {
          if (widget.initialAgent != null) {
            _selectedAgent = _agents.firstWhere(
              (a) => a.id == widget.initialAgent!.id,
              orElse: () => _agents.isNotEmpty ? _agents.first : widget.initialAgent!,
            );
          } else if (_agents.isNotEmpty) {
            _selectedAgent = _agents.first;
          }
        }
        _isLoadingAgents = false;
      });
      _checkDuplicate();
    }
  }

  // ---------------------------------------------------------------------------
  // Calculations
  // ---------------------------------------------------------------------------

  void _recalculateFromKwRate() {
    if (_calcMode != CommissionCalcMode.perKw) return;
    final capacity = double.tryParse(_capacityController.text.trim()) ?? 0.0;
    final rate = double.tryParse(_ratePerKwController.text.trim()) ?? 0.0;
    if (capacity > 0 && rate > 0) {
      final total = capacity * rate;
      _amountController.text = total.toStringAsFixed(2);
    }
  }

  // ---------------------------------------------------------------------------
  // Duplicate Check
  // ---------------------------------------------------------------------------

  Future<void> _checkDuplicate() async {
    final agentName = _selectedAgent?.name ?? '';
    final customerName = _customerNameController.text.trim();
    if (agentName.isEmpty || customerName.isEmpty) {
      if (_duplicateWarning != null) {
        setState(() => _duplicateWarning = null);
      }
      return;
    }

    final warning = await CommissionService.checkSingleDuplicate(
      agentName: agentName,
      customerName: customerName,
      consumerNo: _consumerNoController.text.trim(),
      commissionDate: _commissionDate,
    );

    if (mounted) {
      setState(() => _duplicateWarning = warning);
    }
  }

  // ---------------------------------------------------------------------------
  // Save Methods
  // ---------------------------------------------------------------------------

  Future<bool> _saveCurrentEntry() async {
    if (!_formKey.currentState!.validate()) {
      return false;
    }

    if (_selectedAgent == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an agent.'), backgroundColor: Colors.red),
      );
      return false;
    }

    final amount = double.tryParse(_amountController.text.trim());
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid commission amount greater than ₹0.'), backgroundColor: Colors.red),
      );
      return false;
    }

    setState(() => _isSaving = true);

    try {
      final capacity = double.tryParse(_capacityController.text.trim());
      final record = await CommissionService.saveSingleCommissionEntry(
        agentName: _selectedAgent!.name,
        agentId: _selectedAgent!.id,
        customerName: _customerNameController.text.trim(),
        customerId: _selectedCustomerId,
        consumerNo: _consumerNoController.text.trim().isNotEmpty ? _consumerNoController.text.trim() : null,
        solarCapacity: capacity,
        commissionDate: _commissionDate,
        commissionAmount: amount,
        approvedAmount: _status == CommissionStatus.approved ? amount : null,
        status: _status,
        remarks: _remarksController.text.trim().isNotEmpty ? _remarksController.text.trim() : null,
      );

      widget.onEntrySaved?.call();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('Commission entry ${record.entryNumber} saved for ${_selectedAgent!.name} (₹${_currencyFormat.format(amount)})!'),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF16A34A),
            duration: const Duration(seconds: 3),
          ),
        );
      }

      setState(() {
        _sessionSavedCount++;
        _isSaving = false;
      });

      return true;
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save entry: $e'), backgroundColor: Colors.red),
        );
      }
      return false;
    }
  }

  void _resetCustomerFieldsForNextEntry() {
    setState(() {
      _customerNameController.clear();
      _consumerNoController.clear();
      _capacityController.clear();
      _amountController.clear();
      _remarksController.clear();
      _selectedCustomerId = null;
      _duplicateWarning = null;
    });

    // Refocus on customer search input for quick typing
    Future.microtask(() {
      if (mounted) {
        _customerFocusNode.requestFocus();
      }
    });
  }

  Future<void> _handleSaveAndAddAnother() async {
    final success = await _saveCurrentEntry();
    if (success) {
      _resetCustomerFieldsForNextEntry();
    }
  }

  Future<void> _handleSaveAndClose() async {
    final success = await _saveCurrentEntry();
    if (success && mounted) {
      Navigator.of(context).pop();
    }
  }

  // ---------------------------------------------------------------------------
  // Date Picker
  // ---------------------------------------------------------------------------

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _commissionDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null && mounted) {
      setState(() => _commissionDate = picked);
      _checkDuplicate();
    }
  }

  // ---------------------------------------------------------------------------
  // UI Builder
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDesktop = MediaQuery.of(context).size.width >= 750;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: isDesktop ? 680 : double.infinity,
          maxHeight: MediaQuery.of(context).size.height * 0.92,
        ),
        child: Column(
          children: [
            // 1. Header
            _buildHeader(theme),

            const Divider(height: 1),

            // 2. Scrollable Form Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Session status badge if user added items this session
                      if (_sessionSavedCount > 0)
                        Container(
                          margin: const EdgeInsets.only(bottom: 14),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFDCFCE7),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFF86EFAC)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.check_circle_outline, color: Color(0xFF16A34A), size: 18),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  '$_sessionSavedCount commission ${(_sessionSavedCount == 1 ? "entry" : "entries")} saved in this session. Ready for next entry!',
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF15803D)),
                                ),
                              ),
                            ],
                          ),
                        ),

                      // Section 1: Agent & Date
                      _buildAgentAndDateSection(theme),

                      const SizedBox(height: 16),

                      // Section 2: Customer Details with Autocomplete
                      _buildCustomerSection(theme),

                      const SizedBox(height: 16),

                      // Duplicate Alert Banner
                      if (_duplicateWarning != null)
                        _buildDuplicateWarningBanner(theme),

                      // Section 3: Commission Calculation & Amount
                      _buildAmountAndCalculationSection(theme),

                      const SizedBox(height: 16),

                      // Section 4: Status & Remarks
                      _buildStatusAndRemarksSection(theme),
                    ],
                  ),
                ),
              ),
            ),

            const Divider(height: 1),

            // 3. Bottom Action Bar
            _buildBottomActionBar(theme),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Header
  // ---------------------------------------------------------------------------

  Widget _buildHeader(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFF57C00).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.person_add_alt_1, color: Color(0xFFF57C00), size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Text(
                      'New Commission Entry',
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(width: 8),
                    Text(
                      '(एका वेळी एक नोंद)',
                      style: TextStyle(fontSize: 13, color: Colors.black54, fontWeight: FontWeight.normal),
                    ),
                  ],
                ),
                Text(
                  'Record agent commission one-by-one with customer lookup & instant calculation',
                  style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              visualDensity: VisualDensity.compact,
            ),
            icon: const Icon(Icons.table_chart_outlined, size: 15),
            label: const Text('Bulk Entry', style: TextStyle(fontSize: 12)),
            onPressed: () {
              Navigator.of(context).pop();
              BulkCommissionEntryScreen.show(context, onEntriesSaved: widget.onEntrySaved);
            },
          ),
          const SizedBox(width: 6),
          IconButton(
            icon: const Icon(Icons.close, size: 20),
            tooltip: 'Close',
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Section 1: Agent & Date
  // ---------------------------------------------------------------------------

  Widget _buildAgentAndDateSection(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.badge_outlined, size: 16, color: Color(0xFFF57C00)),
              const SizedBox(width: 6),
              const Text('Agent & Commission Date', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const Spacer(),
              TextButton.icon(
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  visualDensity: VisualDensity.compact,
                ),
                icon: const Icon(Icons.add, size: 15),
                label: const Text('+ New Agent', style: TextStyle(fontSize: 12)),
                onPressed: () async {
                  await AgentMasterDialog.show(context, onAgentListChanged: _loadAgents);
                  _loadAgents();
                },
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Agent Dropdown
              Expanded(
                flex: 6,
                child: _isLoadingAgents
                    ? const SizedBox(
                        height: 48,
                        child: Center(child: LinearProgressIndicator()),
                      )
                    : DropdownButtonFormField<AgentMaster>(
                        value: _selectedAgent,
                        decoration: const InputDecoration(
                          labelText: 'Select Agent (एजंट निवडा) *',
                          prefixIcon: Icon(Icons.person_outline, size: 18),
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                        ),
                        items: _agents.map((agent) {
                          return DropdownMenuItem<AgentMaster>(
                            value: agent,
                            child: Text(
                              '${agent.name}${agent.agencyName != null && agent.agencyName!.isNotEmpty ? ' (${agent.agencyName})' : ''}',
                              style: const TextStyle(fontSize: 13),
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        }).toList(),
                        validator: (val) => val == null ? 'Please select an agent' : null,
                        onChanged: (val) {
                          setState(() => _selectedAgent = val);
                          _checkDuplicate();
                        },
                      ),
              ),
              const SizedBox(width: 12),

              // Commission Date
              Expanded(
                flex: 4,
                child: InkWell(
                  onTap: _pickDate,
                  borderRadius: BorderRadius.circular(8),
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Date (तारीख) *',
                      prefixIcon: Icon(Icons.calendar_today_outlined, size: 17),
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                    ),
                    child: Text(
                      _dateFormat.format(_commissionDate),
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Section 2: Customer Details
  // ---------------------------------------------------------------------------

  Widget _buildCustomerSection(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.person_search_outlined, size: 16, color: Color(0xFF0284C7)),
              SizedBox(width: 6),
              Text('Customer Information (ग्राहक माहिती)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              Spacer(),
              Text('Search or enter manually', style: TextStyle(fontSize: 11, color: Colors.black45)),
            ],
          ),
          const SizedBox(height: 12),

          // Customer Autocomplete Search
          Autocomplete<ConsumerRecord>(
            optionsBuilder: (textEditingValue) async {
              final query = textEditingValue.text.trim();
              if (query.length < 2) return const Iterable<ConsumerRecord>.empty();
              if (_customerSearchCache.containsKey(query)) {
                return _customerSearchCache[query]!;
              }
              final results = await CommissionService.searchCustomers(query);
              _customerSearchCache[query] = results;
              return results;
            },
            displayStringForOption: (c) => c.name,
            optionsViewBuilder: (context, onSelected, options) {
              return Align(
                alignment: Alignment.topLeft,
                child: Material(
                  elevation: 6.0,
                  borderRadius: BorderRadius.circular(10),
                  color: Colors.white,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 250, maxWidth: 450),
                    child: ListView.separated(
                      padding: EdgeInsets.zero,
                      shrinkWrap: true,
                      itemCount: options.length,
                      separatorBuilder: (context, index) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final customer = options.elementAt(index);
                        final capacity = customer.systemCapacity != null ? '${customer.systemCapacity}' : '';
                        final consumerNo = customer.consumerNo.isNotEmpty ? customer.consumerNo : 'No Consumer #';
                        final mobile = customer.mobile != null && customer.mobile!.isNotEmpty ? ' • ${customer.mobile}' : '';
                        return ListTile(
                          dense: true,
                          leading: const CircleAvatar(
                            radius: 14,
                            backgroundColor: Color(0xFFE0F2FE),
                            child: Icon(Icons.solar_power, size: 16, color: Color(0xFF0284C7)),
                          ),
                          title: Text(customer.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          subtitle: Text(
                            '$consumerNo$mobile${capacity.isNotEmpty ? ' • $capacity' : ''}',
                            style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                          ),
                          onTap: () => onSelected(customer),
                        );
                      },
                    ),
                  ),
                ),
              );
            },
            onSelected: (customer) {
              setState(() {
                _customerNameController.text = customer.name;
                _selectedCustomerId = customer.id;
                if (customer.consumerNo.isNotEmpty) {
                  _consumerNoController.text = customer.consumerNo;
                }
                if (customer.systemCapacity != null) {
                  final cleanCapacity = customer.systemCapacity!.replaceAll(RegExp(r'[^0-9.]'), '');
                  _capacityController.text = cleanCapacity;
                }
              });
              _recalculateFromKwRate();
              _checkDuplicate();
            },
            fieldViewBuilder: (context, textController, focusNode, onFieldSubmitted) {
              // Keep external controller synced
              textController.addListener(() {
                if (_customerNameController.text != textController.text) {
                  _customerNameController.text = textController.text;
                }
              });
              _customerNameController.addListener(() {
                if (textController.text != _customerNameController.text) {
                  textController.text = _customerNameController.text;
                }
              });

              return TextFormField(
                controller: textController,
                focusNode: focusNode,
                decoration: const InputDecoration(
                  labelText: 'Customer Name (ग्राहकाचे नाव) *',
                  hintText: 'Type customer name, consumer no or mobile to search...',
                  prefixIcon: Icon(Icons.search, size: 18),
                  isDense: true,
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Customer name is required';
                  }
                  return null;
                },
                onChanged: (_) => _checkDuplicate(),
              );
            },
          ),
          const SizedBox(height: 12),

          Row(
            children: [
              // Consumer Number
              Expanded(
                flex: 6,
                child: TextFormField(
                  controller: _consumerNoController,
                  decoration: const InputDecoration(
                    labelText: 'Consumer Number (ग्राहक क्रमांक)',
                    hintText: 'e.g. 012345678901',
                    prefixIcon: Icon(Icons.numbers, size: 18),
                    isDense: true,
                  ),
                  onChanged: (_) => _checkDuplicate(),
                ),
              ),
              const SizedBox(width: 12),

              // Solar Capacity (kW)
              Expanded(
                flex: 4,
                child: TextFormField(
                  controller: _capacityController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Solar Capacity (kW)',
                    hintText: 'e.g. 3.0',
                    prefixIcon: Icon(Icons.bolt, size: 18),
                    suffixText: 'kW',
                    isDense: true,
                  ),
                  onChanged: (_) => _recalculateFromKwRate(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Duplicate Alert Banner
  // ---------------------------------------------------------------------------

  Widget _buildDuplicateWarningBanner(ThemeData theme) {
    final w = _duplicateWarning!;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.amber.shade400),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.warning_amber_rounded, color: Colors.amber.shade900, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Possible Duplicate Commission Entry!',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.amber.shade900),
                ),
                const SizedBox(height: 2),
                Text(
                  w.reason,
                  style: const TextStyle(fontSize: 12, color: Colors.black87),
                ),
                if (w.existingEntryNumber != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Existing Entry: ${w.existingEntryNumber} • Status: ${w.existingStatus ?? ""} • ₹${w.existingAmount != null ? _currencyFormat.format(w.existingAmount!) : ""}',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.amber.shade900),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Section 3: Commission Calculation & Amount
  // ---------------------------------------------------------------------------

  Widget _buildAmountAndCalculationSection(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFDE68A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.currency_rupee, size: 17, color: Color(0xFFD97706)),
              const SizedBox(width: 6),
              const Text('Commission Calculation (कमिशन रक्कम)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const Spacer(),

              // Calculation Mode Toggle
              SegmentedButton<CommissionCalcMode>(
                segments: const [
                  ButtonSegment(
                    value: CommissionCalcMode.fixedAmount,
                    label: Text('Fixed ₹', style: TextStyle(fontSize: 11)),
                  ),
                  ButtonSegment(
                    value: CommissionCalcMode.perKw,
                    label: Text('₹/kW', style: TextStyle(fontSize: 11)),
                  ),
                ],
                selected: {_calcMode},
                onSelectionChanged: (set) {
                  setState(() {
                    _calcMode = set.first;
                    if (_calcMode == CommissionCalcMode.perKw) {
                      _recalculateFromKwRate();
                    }
                  });
                },
                style: const ButtonStyle(
                  visualDensity: VisualDensity.compact,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Rate per kW assistant if mode is active
          if (_calcMode == CommissionCalcMode.perKw) ...[
            Row(
              children: [
                Expanded(
                  flex: 5,
                  child: TextFormField(
                    controller: _ratePerKwController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Rate per kW (₹/kW)',
                      prefixText: '₹ ',
                      isDense: true,
                    ),
                    onChanged: (_) => _recalculateFromKwRate(),
                  ),
                ),
                const SizedBox(width: 8),
                const Text('×', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black45)),
                const SizedBox(width: 8),
                Expanded(
                  flex: 5,
                  child: InputDecorator(
                    decoration: const InputDecoration(labelText: 'Capacity', suffixText: 'kW', isDense: true),
                    child: Text(
                      _capacityController.text.trim().isNotEmpty ? '${_capacityController.text.trim()} kW' : '0.0 kW',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
          ],

          // Final Commission Amount Input
          TextFormField(
            controller: _amountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF15803D)),
            decoration: InputDecoration(
              labelText: 'Commission Amount (₹) *',
              hintText: 'Enter commission amount (उदा. 5000)',
              prefixIcon: const Icon(Icons.payments_outlined, color: Color(0xFF15803D)),
              prefixText: '₹ ',
              helperText: _calcMode == CommissionCalcMode.perKw ? 'Auto-calculated from rate × kW, editable if negotiated' : 'Enter agreed commission for this client',
              isDense: true,
            ),
            validator: (val) {
              if (val == null || val.trim().isEmpty) {
                return 'Commission amount is required';
              }
              final amt = double.tryParse(val.trim());
              if (amt == null || amt <= 0) {
                return 'Amount must be greater than ₹0';
              }
              return null;
            },
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Section 4: Status & Remarks
  // ---------------------------------------------------------------------------

  Widget _buildStatusAndRemarksSection(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            // Status Dropdown
            Expanded(
              flex: 5,
              child: DropdownButtonFormField<String>(
                value: _status,
                decoration: const InputDecoration(
                  labelText: 'Initial Status (स्थिती)',
                  isDense: true,
                  prefixIcon: Icon(Icons.rule_outlined, size: 18),
                ),
                items: const [
                  DropdownMenuItem(
                    value: CommissionStatus.pendingApproval,
                    child: Text('Pending Approval (पेंडिंग)', style: TextStyle(fontSize: 12)),
                  ),
                  DropdownMenuItem(
                    value: CommissionStatus.approved,
                    child: Text('Direct Approved (मंजूर)', style: TextStyle(fontSize: 12, color: Color(0xFF0284C7), fontWeight: FontWeight.bold)),
                  ),
                ],
                onChanged: (val) {
                  if (val != null) setState(() => _status = val);
                },
              ),
            ),
            const SizedBox(width: 12),

            // Remarks / Notes
            Expanded(
              flex: 6,
              child: TextFormField(
                controller: _remarksController,
                decoration: const InputDecoration(
                  labelText: 'Remarks / Notes (नोंद)',
                  hintText: 'e.g. Referral, milestone 1',
                  isDense: true,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Bottom Action Bar (Save & Add Another / Save & Close)
  // ---------------------------------------------------------------------------

  Widget _buildBottomActionBar(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
      ),
      child: Row(
        children: [
          // Close button
          OutlinedButton(
            onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
            child: Text(_sessionSavedCount > 0 ? 'Done ($_sessionSavedCount saved)' : 'Cancel'),
          ),

          const Spacer(),

          // Save & Add Another Button (The key "one by one" sequential entry flow)
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              side: const BorderSide(color: Color(0xFFF57C00), width: 1.5),
              foregroundColor: const Color(0xFFEA580C),
            ),
            icon: _isSaving
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.queue, size: 18),
            label: const Text(
              'Save & Add Another (जतन करून पुढील नोंद)',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            onPressed: _isSaving ? null : _handleSaveAndAddAnother,
          ),
          const SizedBox(width: 10),

          // Save & Close Button
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF16A34A),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            ),
            icon: _isSaving
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.check, size: 18),
            label: const Text('Save & Close', style: TextStyle(fontWeight: FontWeight.bold)),
            onPressed: _isSaving ? null : _handleSaveAndClose,
          ),
        ],
      ),
    );
  }
}
