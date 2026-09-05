import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/lead_record.dart';
import '../services/lead_service.dart';
import 'lead_form_dialog.dart';

class LeadDetailsDialog extends StatefulWidget {
  final LeadRecord lead;
  final VoidCallback onRefresh;

  const LeadDetailsDialog({
    super.key,
    required this.lead,
    required this.onRefresh,
  });

  @override
  State<LeadDetailsDialog> createState() => _LeadDetailsDialogState();
}

class _LeadDetailsDialogState extends State<LeadDetailsDialog> with SingleTickerProviderStateMixin {
  late LeadRecord _lead;
  late TabController _tabController;
  List<LeadFollowup> _followups = [];
  List<LeadAuditLog> _auditLogs = [];
  bool _isLoadingHistory = false;

  // Add follow-up form state
  final _followupNotesController = TextEditingController();
  String _followupType = 'Call';
  String? _followupResult = 'Follow-up Required';
  DateTime? _newNextFollowupDate;
  String? _advanceStatus;
  bool _isSavingFollowup = false;

  final List<String> _followupTypes = ['Call', 'WhatsApp', 'Meeting', 'Site Visit', 'Email', 'Other'];
  final List<String> _followupResults = [
    'Follow-up Required',
    'Interested',
    'Site Survey Scheduled',
    'Quotation Requested',
    'Not Reachable',
    'Hold',
    'Lost',
  ];

  @override
  void initState() {
    super.initState();
    _lead = widget.lead;
    _tabController = TabController(length: 3, vsync: this);
    _newNextFollowupDate = DateTime.now().add(const Duration(days: 2));
    _advanceStatus = _lead.leadStatus;
    _loadHistory();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _followupNotesController.dispose();
    super.dispose();
  }

  Future<void> _loadHistory() async {
    setState(() => _isLoadingHistory = true);
    final f = await LeadService.fetchFollowups(_lead.id);
    final a = await LeadService.fetchAuditLogs(_lead.id);
    if (mounted) {
      setState(() {
        _followups = f;
        _auditLogs = a;
        _isLoadingHistory = false;
      });
    }
  }

  Future<void> _handleAddFollowup() async {
    final notes = _followupNotesController.text.trim();
    if (notes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter follow-up notes')),
      );
      return;
    }

    setState(() => _isSavingFollowup = true);
    final ok = await LeadService.addFollowup(
      leadId: _lead.id,
      followupType: _followupType,
      notes: notes,
      result: _followupResult,
      nextFollowupDate: _newNextFollowupDate,
      updatedStatus: _advanceStatus != _lead.leadStatus ? _advanceStatus : null,
    );

    if (mounted) {
      setState(() => _isSavingFollowup = false);
      if (ok) {
        _followupNotesController.clear();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Follow-up logged successfully!'), backgroundColor: Colors.green),
        );
        // Refresh lead info
        final refreshed = await LeadService.fetchLeads(searchQuery: _lead.mobileNo);
        if (refreshed.isNotEmpty) {
          setState(() => _lead = refreshed.first);
        }
        _loadHistory();
        widget.onRefresh();
      }
    }
  }

  Future<void> _handleCall(String mobile) async {
    final uri = Uri.parse('tel:$mobile');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _handleWhatsApp(String mobile) async {
    final clean = mobile.replaceAll(RegExp(r'\D'), '');
    final phone = clean.startsWith('91') ? clean : '91$clean';
    final uri = Uri.parse('https://wa.me/$phone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  // Conversion with safety duplicate check
  Future<void> _startConversionFlow() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(child: CircularProgressIndicator()),
    );

    final duplicates = await LeadService.checkExistingCustomer(
      mobileNo: _lead.mobileNo,
      consumerNo: _lead.consumerNo,
    );

    if (!mounted) return;
    Navigator.pop(context); // dismiss loading

    if (duplicates.isNotEmpty) {
      _showDuplicateWarningDialog(duplicates);
    } else {
      _showConfirmConversionDialog();
    }
  }

  void _showDuplicateWarningDialog(List<Map<String, dynamic>> duplicates) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange.shade800),
            const SizedBox(width: 8),
            const Text('Possible Existing Customer'),
          ],
        ),
        content: SizedBox(
          width: 500,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Existing customer records found with matching Mobile or Consumer No. Please review before converting:',
                style: TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 12),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: duplicates.length,
                  itemBuilder: (c, i) {
                    final d = duplicates[i];
                    return Card(
                      elevation: 0,
                      color: Colors.amber.shade50,
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        dense: true,
                        leading: const Icon(Icons.person, color: Colors.amber),
                        title: Text(
                          d['name'] ?? 'Unknown',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          'Mobile: ${d['mobile']} | Consumer: ${d['consumer_no']} | Status: ${d['status']}',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Do you still want to proceed and create a NEW customer application?',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel Conversion'),
          ),
          FilledButton.tonal(
            onPressed: () {
              Navigator.pop(ctx);
              _showConfirmConversionDialog();
            },
            child: const Text('Continue & Create Application'),
          ),
        ],
      ),
    );
  }

  void _showConfirmConversionDialog() {
    final remarksCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.transform_rounded, color: Colors.green),
            SizedBox(width: 8),
            Text('Convert Lead to Customer'),
          ],
        ),
        content: SizedBox(
          width: 480,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'This will create an active Customer Application in "Agreement Pending" stage for ${_lead.customerName}.',
                style: const TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 12),
              Card(
                color: Colors.grey.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      _rowInfo('Customer', _lead.customerName),
                      _rowInfo('Mobile', _lead.mobileNo),
                      _rowInfo('System Size', _lead.approxSystemSize ?? 'Not specified'),
                      _rowInfo('Address', _lead.fullAddress),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: remarksCtrl,
                decoration: const InputDecoration(
                  labelText: 'Conversion Remarks (Optional)',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(ctx);
              _executeConversion(remarksCtrl.text.trim());
            },
            child: const Text('Confirm Conversion'),
          ),
        ],
      ),
    );
  }

  Future<void> _executeConversion(String remarks) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    final res = await LeadService.convertLeadToCustomer(
      lead: _lead,
      remarks: remarks.isEmpty ? null : remarks,
    );

    if (!mounted) return;
    Navigator.pop(context); // dismiss spinner

    if (res != null) {
      widget.onRefresh();
      Navigator.pop(context); // close details dialog
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lead converted! Customer record created: ${res['consumer_no']}'),
          backgroundColor: Colors.green.shade700,
          duration: const Duration(seconds: 4),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to convert lead. Check permissions.'), backgroundColor: Colors.red),
      );
    }
  }

  // Mark as Lost Dialog
  void _showMarkLostDialog() {
    String selectedReason = 'Not Interested';
    final notesCtrl = TextEditingController();
    final reasons = ['Not Interested', 'Price Issue', 'Competitor', 'No Response', 'Not Eligible', 'Other'];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (c, setDState) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.cancel_outlined, color: Colors.red),
              SizedBox(width: 8),
              Text('Mark Lead as Lost'),
            ],
          ),
          content: SizedBox(
            width: 440,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Record reason for closing this lead. It will be removed from active follow-ups but kept in reports.',
                  style: TextStyle(fontSize: 13),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: selectedReason,
                  decoration: const InputDecoration(
                    labelText: 'Lost Reason *',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: reasons.map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
                  onChanged: (v) => setDState(() => selectedReason = v!),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: notesCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Additional Notes',
                    hintText: 'e.g. Went with competitor Tata Power / Budget mismatch',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
              onPressed: () async {
                Navigator.pop(ctx);
                final ok = await LeadService.markLeadLost(
                  _lead.id,
                  reason: selectedReason,
                  notes: notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim(),
                );
                if (ok && mounted) {
                  widget.onRefresh();
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Lead marked as Lost')),
                  );
                }
              },
              child: const Text('Confirm Lost'),
            ),
          ],
        ),
      ),
    );
  }

  // Mark as No Action Required (Hold)
  void _showNoActionDialog() {
    String selectedReason = 'Customer on Hold';
    final notesCtrl = TextEditingController();
    final reasons = [
      'Customer on Hold',
      'Not Ready for Installation',
      'Awaiting Budget / Loan Approval',
      'Construction / Roof Pending',
      'Other',
    ];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (c, setDState) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.pause_circle_outline, color: Colors.orange),
              SizedBox(width: 8),
              Text('Hold / No Action Required'),
            ],
          ),
          content: SizedBox(
            width: 440,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Put this lead on temporary hold. It will be removed from daily follow-ups but can be reopened anytime.',
                  style: TextStyle(fontSize: 13),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: selectedReason,
                  decoration: const InputDecoration(
                    labelText: 'Hold Reason *',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: reasons.map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
                  onChanged: (v) => setDState(() => selectedReason = v!),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: notesCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Remarks',
                    hintText: 'e.g. Call back after 2 months',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.orange.shade800),
              onPressed: () async {
                Navigator.pop(ctx);
                final ok = await LeadService.markLeadNoAction(
                  _lead.id,
                  reason: selectedReason,
                  notes: notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim(),
                );
                if (ok && mounted) {
                  widget.onRefresh();
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Lead placed on Hold')),
                  );
                }
              },
              child: const Text('Confirm Hold'),
            ),
          ],
        ),
      ),
    );
  }

  // Reopen Lead
  void _showReopenDialog() {
    DateTime reopenDate = DateTime.now().add(const Duration(days: 1));
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (c, setDState) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.replay_rounded, color: Colors.blue),
              SizedBox(width: 8),
              Text('Reopen Lead'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('This will reactivate the lead into the "Follow-up" queue.'),
              const SizedBox(height: 16),
              InkWell(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: reopenDate,
                    firstDate: DateTime.now(),
                    lastDate: DateTime(2030),
                  );
                  if (picked != null) setDState(() => reopenDate = picked);
                },
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Next Follow-up Date',
                    prefixIcon: Icon(Icons.calendar_today_outlined),
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  child: Text(DateFormat('dd/MM/yyyy').format(reopenDate)),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(
              onPressed: () async {
                Navigator.pop(ctx);
                final ok = await LeadService.reopenLead(_lead.id, nextFollowupDate: reopenDate);
                if (ok && mounted) {
                  widget.onRefresh();
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Lead reopened successfully!')),
                  );
                }
              },
              child: const Text('Reopen'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Container(
        width: 860,
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.92),
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 20, 12),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: theme.colorScheme.primaryContainer,
                    child: Icon(Icons.leaderboard_outlined, color: theme.colorScheme.primary),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              _lead.customerName,
                              style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(width: 10),
                            _buildStatusBadge(_lead.leadStatus),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Source: ${_lead.leadSource} • Product: ${_lead.interestedIn} • Mobile: ${_lead.mobileNo}',
                          style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit_outlined),
                    tooltip: 'Edit Lead',
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (_) => LeadFormDialog(
                          lead: _lead,
                          onSaved: () async {
                            final res = await LeadService.fetchLeads(searchQuery: _lead.mobileNo);
                            if (res.isNotEmpty) setState(() => _lead = res.first);
                            widget.onRefresh();
                          },
                        ),
                      );
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // Smart Action Banner
            _buildSmartActionBanner(),

            // Tab Bar
            TabBar(
              controller: _tabController,
              tabs: [
                const Tab(icon: Icon(Icons.info_outline, size: 18), text: 'Overview'),
                Tab(
                  icon: const Icon(Icons.history_toggle_off, size: 18),
                  text: 'Follow-ups (${_followups.length})',
                ),
                Tab(
                  icon: const Icon(Icons.receipt_long_outlined, size: 18),
                  text: 'Audit Trail (${_auditLogs.length})',
                ),
              ],
            ),

            // Tab Body
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildOverviewTab(),
                  _buildFollowupsTab(),
                  _buildAuditTab(),
                ],
              ),
            ),

            const Divider(height: 1),
            // Bottom Action Bar
            _buildBottomActionBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildSmartActionBanner() {
    Color bannerBg;
    Color iconColor;
    IconData actionIcon;

    if (_lead.isOverdue) {
      bannerBg = Colors.red.shade50;
      iconColor = Colors.red.shade800;
      actionIcon = Icons.error_outline;
    } else if (_lead.isTodayFollowup) {
      bannerBg = Colors.amber.shade50;
      iconColor = Colors.amber.shade900;
      actionIcon = Icons.notifications_active_outlined;
    } else if (_lead.isConverted) {
      bannerBg = Colors.green.shade50;
      iconColor = Colors.green.shade800;
      actionIcon = Icons.check_circle_outline;
    } else if (_lead.isLost) {
      bannerBg = Colors.grey.shade100;
      iconColor = Colors.grey.shade700;
      actionIcon = Icons.cancel_outlined;
    } else {
      bannerBg = Colors.blue.shade50;
      iconColor = Colors.blue.shade800;
      actionIcon = Icons.bolt;
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bannerBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: iconColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(actionIcon, color: iconColor, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'NEXT ACTION: ${_lead.smartNextAction.toUpperCase()}',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: iconColor),
                    ),
                    const SizedBox(width: 8),
                    if (_lead.isOverdue)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.red.shade700,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'OVERDUE BY ${_lead.overdueDays} DAYS',
                          style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      )
                    else if (_lead.isTodayFollowup)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.amber.shade800,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'TODAY\'S WORK',
                          style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  _lead.nextFollowupDate != null
                      ? 'Scheduled: ${DateFormat('EEEE, dd MMMM yyyy').format(_lead.nextFollowupDate!)} • Assigned: ${_lead.assignedStaffName ?? "Unassigned"}'
                      : 'No follow-up date scheduled • Assigned: ${_lead.assignedStaffName ?? "Unassigned"}',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade800),
                ),
              ],
            ),
          ),
          // Call & WhatsApp quick shortcuts
          IconButton.filledTonal(
            icon: const Icon(Icons.phone, size: 18),
            tooltip: 'Call Customer',
            onPressed: () => _handleCall(_lead.mobileNo),
          ),
          const SizedBox(width: 6),
          IconButton.filledTonal(
            icon: const Icon(Icons.chat, size: 18, color: Colors.green),
            tooltip: 'Chat on WhatsApp',
            onPressed: () => _handleWhatsApp(_lead.whatsappNo ?? _lead.mobileNo),
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Contact & Location Card
              Expanded(
                child: Card(
                  elevation: 0,
                  color: Colors.grey.shade50,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: BorderSide(color: Colors.grey.shade200),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('CONTACT & LOCATION', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                        const Divider(height: 16),
                        _rowInfo('Customer Name', _lead.customerName),
                        _rowInfo('Mobile No', _lead.mobileNo),
                        _rowInfo('WhatsApp No', _lead.whatsappNo ?? 'Same as mobile'),
                        _rowInfo('Village / City', _lead.village ?? '—'),
                        _rowInfo('Taluka', _lead.taluka ?? '—'),
                        _rowInfo('District', _lead.district ?? '—'),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),

              // Requirements & Financials Card
              Expanded(
                child: Card(
                  elevation: 0,
                  color: Colors.grey.shade50,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: BorderSide(color: Colors.grey.shade200),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('REQUIREMENT & ESTIMATES', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                        const Divider(height: 16),
                        _rowInfo('Lead Source', _lead.leadSource),
                        _rowInfo('Interested In', _lead.interestedIn),
                        _rowInfo('System Size', _lead.approxSystemSize ?? '—'),
                        _rowInfo(
                          'Monthly Electricity Bill',
                          _lead.monthlyElectricityBill != null ? '₹ ${_lead.monthlyElectricityBill!.toStringAsFixed(0)}' : '—',
                        ),
                        _rowInfo(
                          'Estimated Budget',
                          _lead.estimatedBudget != null ? '₹ ${_lead.estimatedBudget!.toStringAsFixed(0)}' : '—',
                        ),
                        _rowInfo('Consumer No', _lead.consumerNo ?? '—'),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Remarks Card
          if (_lead.remarks != null && _lead.remarks!.isNotEmpty)
            Card(
              elevation: 0,
              color: Colors.grey.shade50,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: BorderSide(color: Colors.grey.shade200),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('REMARKS & SPECIAL NOTES', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    const SizedBox(height: 8),
                    Text(_lead.remarks!, style: const TextStyle(fontSize: 13)),
                  ],
                ),
              ),
            ),

          // Lost Details Banner if Lost
          if (_lead.isLost)
            Container(
              margin: const EdgeInsets.only(top: 12),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Row(
                children: [
                  const Icon(Icons.cancel, color: Colors.red),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Lost Reason: ${_lead.lostReason ?? "Unspecified"}. Notes: ${_lead.lostNotes ?? "None"}',
                      style: TextStyle(color: Colors.red.shade900, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),

          // No Action Details Banner if Hold
          if (_lead.isNoActionRequired)
            Container(
              margin: const EdgeInsets.only(top: 12),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Row(
                children: [
                  const Icon(Icons.pause_circle_filled, color: Colors.orange),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Hold Reason: ${_lead.noActionReason ?? "Customer on hold"}. Remarks: ${_lead.noActionNotes ?? "None"}',
                      style: TextStyle(color: Colors.orange.shade900, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),

          // Converted Banner if Converted
          if (_lead.isConverted)
            Container(
              margin: const EdgeInsets.only(top: 12),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.green),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Converted to Customer Application on ${_lead.convertedAt != null ? DateFormat('dd/MM/yyyy').format(_lead.convertedAt!) : "recent"}. Linked Customer ID: ${_lead.customerId ?? "—"}',
                      style: TextStyle(color: Colors.green.shade900, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFollowupsTab() {
    final statuses = ['New', 'Contacted', 'Interested', 'Site Survey', 'Quotation', 'Follow-up'];

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left: Add Follow-up Form
          SizedBox(
            width: 320,
            child: Card(
              elevation: 0,
              color: Colors.grey.shade50,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: BorderSide(color: Colors.grey.shade200),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('LOG NEW FOLLOW-UP', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: _followupType,
                      decoration: const InputDecoration(
                        labelText: 'Contact Mode',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      items: _followupTypes.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                      onChanged: (v) => setState(() => _followupType = v!),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      initialValue: _followupResult,
                      decoration: const InputDecoration(
                        labelText: 'Follow-up Result',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      items: _followupResults.map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
                      onChanged: (v) => setState(() => _followupResult = v!),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      initialValue: statuses.contains(_advanceStatus) ? _advanceStatus : 'Follow-up',
                      decoration: const InputDecoration(
                        labelText: 'Update Stage / Status',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      items: statuses.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                      onChanged: (v) => setState(() => _advanceStatus = v!),
                    ),
                    const SizedBox(height: 10),
                    InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _newNextFollowupDate ?? DateTime.now().add(const Duration(days: 2)),
                          firstDate: DateTime.now(),
                          lastDate: DateTime(2030),
                        );
                        if (picked != null) setState(() => _newNextFollowupDate = picked);
                      },
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Next Follow-up Date',
                          prefixIcon: Icon(Icons.calendar_today, size: 16),
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        child: Text(
                          _newNextFollowupDate != null
                              ? DateFormat('dd/MM/yyyy').format(_newNextFollowupDate!)
                              : 'Select Date',
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _followupNotesController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Discussion Notes *',
                        hintText: 'Customer agreed to 5 kW rooftop quote...',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        icon: _isSavingFollowup
                            ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.add, size: 18),
                        label: const Text('Record Follow-up'),
                        onPressed: _isSavingFollowup ? null : _handleAddFollowup,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),

          // Right: Follow-up Timeline List
          Expanded(
            child: _isLoadingHistory
                ? const Center(child: CircularProgressIndicator())
                : _followups.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.speaker_notes_off_outlined, size: 48, color: Colors.grey.shade400),
                            const SizedBox(height: 8),
                            Text('No follow-up notes logged yet', style: TextStyle(color: Colors.grey.shade600)),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: _followups.length,
                        itemBuilder: (ctx, idx) {
                          final f = _followups[idx];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 10),
                            elevation: 0,
                            color: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                              side: BorderSide(color: Colors.grey.shade200),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: Colors.blue.shade50,
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          f.followupType.toUpperCase(),
                                          style: TextStyle(
                                            color: Colors.blue.shade800,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 11,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      if (f.result != null)
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: Colors.teal.shade50,
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            f.result!,
                                            style: TextStyle(
                                              color: Colors.teal.shade800,
                                              fontSize: 11,
                                            ),
                                          ),
                                        ),
                                      const Spacer(),
                                      Text(
                                        DateFormat('dd MMM yyyy, hh:mm a').format(f.followupDate),
                                        style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(f.notes, style: const TextStyle(fontSize: 13)),
                                  if (f.nextFollowupDate != null) ...[
                                    const SizedBox(height: 6),
                                    Text(
                                      'Next follow-up scheduled for: ${DateFormat('dd/MM/yyyy').format(f.nextFollowupDate!)}',
                                      style: TextStyle(fontSize: 11, color: Colors.blue.shade700),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildAuditTab() {
    return _isLoadingHistory
        ? const Center(child: CircularProgressIndicator())
        : _auditLogs.isEmpty
            ? Center(
                child: Text('No audit history recorded', style: TextStyle(color: Colors.grey.shade500)),
              )
            : ListView.separated(
                padding: const EdgeInsets.all(20),
                itemCount: _auditLogs.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (ctx, idx) {
                  final a = _auditLogs[idx];
                  return ListTile(
                    dense: true,
                    leading: CircleAvatar(
                      radius: 14,
                      backgroundColor: Colors.grey.shade200,
                      child: Icon(Icons.history, size: 14, color: Colors.grey.shade700),
                    ),
                    title: Text('${a.action}: ${a.newValue ?? a.reason ?? ""}', style: const TextStyle(fontSize: 13)),
                    subtitle: Text(
                      'By ${a.changedByName ?? "Admin"} via ${a.source} on ${DateFormat('dd MMM yyyy, hh:mm a').format(a.createdAt)}',
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                    ),
                  );
                },
              );
  }

  Widget _buildBottomActionBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      color: Colors.grey.shade50,
      child: Row(
        children: [
          // Reopen button if terminal
          if (_lead.isTerminalState && !_lead.isConverted)
            OutlinedButton.icon(
              icon: const Icon(Icons.replay_rounded, size: 18),
              label: const Text('Reopen Lead'),
              onPressed: _showReopenDialog,
            )
          else ...[
            // Mark Lost
            OutlinedButton.icon(
              icon: const Icon(Icons.close_rounded, size: 18, color: Colors.red),
              label: const Text('Mark Lost', style: TextStyle(color: Colors.red)),
              onPressed: _lead.isConverted ? null : _showMarkLostDialog,
            ),
            const SizedBox(width: 8),
            // Hold / No Action
            OutlinedButton.icon(
              icon: const Icon(Icons.pause_circle_outline, size: 18, color: Colors.orange),
              label: const Text('No Action Required', style: TextStyle(color: Colors.orange)),
              onPressed: _lead.isConverted ? null : _showNoActionDialog,
            ),
          ],

          const Spacer(),

          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          const SizedBox(width: 12),

          // Convert to Customer
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: Colors.green.shade700),
            icon: const Icon(Icons.transform_rounded),
            label: Text(_lead.isConverted ? 'Already Converted' : 'Convert to Customer'),
            onPressed: _lead.isConverted ? null : _startConversionFlow,
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color bg;
    Color fg;
    switch (status) {
      case 'New':
        bg = Colors.blue.shade100;
        fg = Colors.blue.shade900;
        break;
      case 'Contacted':
      case 'Interested':
        bg = Colors.cyan.shade100;
        fg = Colors.cyan.shade900;
        break;
      case 'Site Survey':
      case 'Quotation':
        bg = Colors.purple.shade100;
        fg = Colors.purple.shade900;
        break;
      case 'Follow-up':
        bg = Colors.amber.shade100;
        fg = Colors.amber.shade900;
        break;
      case 'Converted':
        bg = Colors.green.shade100;
        fg = Colors.green.shade900;
        break;
      case 'Lost':
        bg = Colors.red.shade100;
        fg = Colors.red.shade900;
        break;
      case 'No Action Required':
        bg = Colors.orange.shade100;
        fg = Colors.orange.shade900;
        break;
      default:
        bg = Colors.grey.shade200;
        fg = Colors.grey.shade800;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
      child: Text(
        status,
        style: TextStyle(color: fg, fontWeight: FontWeight.bold, fontSize: 12),
      ),
    );
  }

  Widget _rowInfo(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
