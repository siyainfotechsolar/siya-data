import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/lead_record.dart';
import '../services/lead_service.dart';
import 'lead_form_screen.dart';

class MobileLeadDetailScreen extends StatefulWidget {
  final LeadRecord lead;

  const MobileLeadDetailScreen({super.key, required this.lead});

  @override
  State<MobileLeadDetailScreen> createState() => _MobileLeadDetailScreenState();
}

class _MobileLeadDetailScreenState extends State<MobileLeadDetailScreen> {
  late LeadRecord _lead;
  List<LeadFollowup> _followups = [];
  bool _isLoadingFollowups = false;

  @override
  void initState() {
    super.initState();
    _lead = widget.lead;
    _loadFollowups();
  }

  Future<void> _loadFollowups() async {
    setState(() => _isLoadingFollowups = true);
    final list = await MobileLeadService.fetchFollowups(_lead.id);
    if (mounted) {
      setState(() {
        _followups = list;
        _isLoadingFollowups = false;
      });
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

  void _showAddFollowupDialog() {
    String fType = 'Call';
    String? fResult = 'Follow-up Required';
    DateTime? nextDate = DateTime.now().add(const Duration(days: 2));
    String? newStatus = _lead.leadStatus;
    final notesCtrl = TextEditingController();
    bool isSaving = false;

    final statuses = ['New', 'Contacted', 'Interested', 'Site Survey', 'Quotation', 'Follow-up'];
    final types = ['Call', 'WhatsApp', 'Meeting', 'Site Visit', 'Email', 'Other'];
    final results = [
      'Follow-up Required',
      'Interested',
      'Site Survey Scheduled',
      'Quotation Requested',
      'Not Reachable',
      'Hold',
      'Lost',
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (c, setSheetState) => Padding(
          padding: EdgeInsets.only(
            top: 20,
            left: 20,
            right: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Log Follow-up', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: fType,
                      decoration: const InputDecoration(labelText: 'Contact Mode', border: OutlineInputBorder(), isDense: true),
                      items: types.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                      onChanged: (v) => setSheetState(() => fType = v!),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: fResult,
                      decoration: const InputDecoration(labelText: 'Result', border: OutlineInputBorder(), isDense: true),
                      items: results.map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
                      onChanged: (v) => setSheetState(() => fResult = v!),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: statuses.contains(newStatus) ? newStatus : 'Follow-up',
                      decoration: const InputDecoration(labelText: 'Update Status', border: OutlineInputBorder(), isDense: true),
                      items: statuses.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                      onChanged: (v) => setSheetState(() => newStatus = v!),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: nextDate ?? DateTime.now().add(const Duration(days: 2)),
                          firstDate: DateTime.now(),
                          lastDate: DateTime(2030),
                        );
                        if (picked != null) setSheetState(() => nextDate = picked);
                      },
                      child: InputDecorator(
                        decoration: const InputDecoration(labelText: 'Next Date', border: OutlineInputBorder(), isDense: true),
                        child: Text(nextDate != null ? DateFormat('dd/MM/yyyy').format(nextDate!) : 'Select'),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              TextField(
                controller: notesCtrl,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Discussion Notes *',
                  hintText: 'Customer requested quotation for 3 kW...',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: isSaving
                      ? null
                      : () async {
                          final notes = notesCtrl.text.trim();
                          if (notes.isEmpty) return;

                          setSheetState(() => isSaving = true);
                          final ok = await MobileLeadService.addFollowup(
                            leadId: _lead.id,
                            followupType: fType,
                            notes: notes,
                            result: fResult,
                            nextFollowupDate: nextDate,
                            updatedStatus: newStatus != _lead.leadStatus ? newStatus : null,
                          );

                          if (mounted && ok) {
                            Navigator.pop(ctx);
                            final refreshed = await MobileLeadService.fetchLeads(searchQuery: _lead.mobileNo);
                            if (refreshed.isNotEmpty) setState(() => _lead = refreshed.first);
                            _loadFollowups();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Follow-up recorded!'), backgroundColor: Colors.green),
                            );
                          }
                        },
                  child: const Text('Save Follow-up'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Conversion with safety duplicate check
  Future<void> _startConversionFlow() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    final duplicates = await MobileLeadService.checkExistingCustomer(
      mobileNo: _lead.mobileNo,
      consumerNo: _lead.consumerNo,
    );

    if (!mounted) return;
    Navigator.pop(context); // Dismiss loading

    if (duplicates.isNotEmpty) {
      _showDuplicateWarning(duplicates);
    } else {
      _showConfirmConversion();
    }
  }

  void _showDuplicateWarning(List<Map<String, dynamic>> duplicates) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Existing Customer Alert'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'A customer with matching mobile/consumer no already exists:',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 8),
            ...duplicates.map(
              (d) => Text(
                '• ${d['name']} (${d['consumer_no']}) - ${d['status']}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
              ),
            ),
            const SizedBox(height: 12),
            const Text('Still create a new customer record?'),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton.tonal(
            onPressed: () {
              Navigator.pop(ctx);
              _showConfirmConversion();
            },
            child: const Text('Continue'),
          ),
        ],
      ),
    );
  }

  void _showConfirmConversion() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Convert to Customer?'),
        content: Text('Convert ${_lead.customerName} into an active Customer Application in Agreement Pending queue?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final res = await MobileLeadService.convertLeadToCustomer(lead: _lead);
              if (mounted && res != null) {
                Navigator.pop(context, true);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Lead converted! Customer created: ${res['consumer_no']}'),
                    backgroundColor: Colors.green.shade700,
                  ),
                );
              }
            },
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }

  void _showMarkLostDialog() {
    String reason = 'Not Interested';
    final reasons = ['Not Interested', 'Price Issue', 'Competitor', 'No Response', 'Not Eligible', 'Other'];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (c, setDState) => AlertDialog(
          title: const Text('Mark Lead as Lost'),
          content: DropdownButtonFormField<String>(
            initialValue: reason,
            decoration: const InputDecoration(labelText: 'Reason', border: OutlineInputBorder()),
            items: reasons.map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
            onChanged: (v) => setDState(() => reason = v!),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () async {
                Navigator.pop(ctx);
                final ok = await MobileLeadService.markLeadLost(_lead.id, reason: reason);
                if (mounted && ok) {
                  Navigator.pop(context, true);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Lead marked as Lost')));
                }
              },
              child: const Text('Mark Lost'),
            ),
          ],
        ),
      ),
    );
  }

  void _showHoldDialog() {
    String reason = 'Customer on Hold';
    final reasons = ['Customer on Hold', 'Not Ready', 'Awaiting Loan', 'Roof Pending', 'Other'];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (c, setDState) => AlertDialog(
          title: const Text('Hold / No Action Required'),
          content: DropdownButtonFormField<String>(
            initialValue: reason,
            decoration: const InputDecoration(labelText: 'Hold Reason', border: OutlineInputBorder()),
            items: reasons.map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
            onChanged: (v) => setDState(() => reason = v!),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.orange.shade800),
              onPressed: () async {
                Navigator.pop(ctx);
                final ok = await MobileLeadService.markLeadNoAction(_lead.id, reason: reason);
                if (mounted && ok) {
                  Navigator.pop(context, true);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Lead placed on Hold')));
                }
              },
              child: const Text('Hold Lead'),
            ),
          ],
        ),
      ),
    );
  }

  void _showReopenDialog() {
    DateTime reopenDate = DateTime.now().add(const Duration(days: 1));
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reopen Lead'),
        content: const Text('Reactivate lead into Follow-up queue?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final ok = await MobileLeadService.reopenLead(_lead.id, nextFollowupDate: reopenDate);
              if (mounted && ok) {
                Navigator.pop(context, true);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Lead Reopened!')));
              }
            },
            child: const Text('Reopen'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_lead.customerName),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            tooltip: 'Edit Lead',
            onPressed: () async {
              final updated = await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => MobileLeadFormScreen(lead: _lead)),
              );
              if (updated == true) {
                final list = await MobileLeadService.fetchLeads(searchQuery: _lead.mobileNo);
                if (list.isNotEmpty) setState(() => _lead = list.first);
              }
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Smart Action Card
          _buildSmartActionCard(),
          const SizedBox(height: 16),

          // Contact Actions Row
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  icon: const Icon(Icons.phone),
                  label: const Text('Call'),
                  onPressed: () => _handleCall(_lead.mobileNo),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.tonalIcon(
                  style: FilledButton.styleFrom(foregroundColor: Colors.green.shade800),
                  icon: const Icon(Icons.chat, color: Colors.green),
                  label: const Text('WhatsApp'),
                  onPressed: () => _handleWhatsApp(_lead.whatsappNo ?? _lead.mobileNo),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Lead Details Card
          Card(
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
                  const Text('INQUIRY DETAILS', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                  const Divider(height: 16),
                  _row('Product', _lead.interestedIn),
                  _row('System Size', _lead.approxSystemSize ?? '—'),
                  _row('Source', _lead.leadSource),
                  _row('Address', _lead.fullAddress),
                  if (_lead.monthlyElectricityBill != null)
                    _row('Monthly Bill', '₹ ${_lead.monthlyElectricityBill!.toStringAsFixed(0)}'),
                  if (_lead.estimatedBudget != null)
                    _row('Budget', '₹ ${_lead.estimatedBudget!.toStringAsFixed(0)}'),
                  if (_lead.consumerNo != null && _lead.consumerNo!.isNotEmpty)
                    _row('Consumer No', _lead.consumerNo!),
                  if (_lead.remarks != null && _lead.remarks!.isNotEmpty)
                    _row('Remarks', _lead.remarks!),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Follow-up Section
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'FOLLOW-UP HISTORY (${_followups.length})',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              FilledButton.tonalIcon(
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Add Note'),
                onPressed: _showAddFollowupDialog,
              ),
            ],
          ),
          const SizedBox(height: 8),

          if (_isLoadingFollowups)
            const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator()))
          else if (_followups.isEmpty)
            Card(
              elevation: 0,
              color: Colors.grey.shade50,
              child: const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: Text('No follow-up notes yet')),
              ),
            )
          else
            ..._followups.map(
              (f) => Card(
                elevation: 0,
                margin: const EdgeInsets.only(bottom: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: BorderSide(color: Colors.grey.shade200),
                ),
                child: ListTile(
                  dense: true,
                  title: Text(f.notes, style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(
                    '${f.followupType} • ${DateFormat('dd MMM, hh:mm a').format(f.followupDate)} ${f.result != null ? "• " + f.result! : ""}',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 11),
                  ),
                ),
              ),
            ),

          const SizedBox(height: 24),

          // Action Buttons
          if (_lead.isTerminalState && !_lead.isConverted)
            FilledButton.icon(
              icon: const Icon(Icons.replay),
              label: const Text('Reopen Lead'),
              onPressed: _showReopenDialog,
            )
          else if (!_lead.isConverted) ...[
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: Colors.green.shade700,
                minimumSize: const Size.fromHeight(48),
              ),
              icon: const Icon(Icons.transform_rounded),
              label: const Text('Convert to Customer Application'),
              onPressed: _startConversionFlow,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                    onPressed: _showMarkLostDialog,
                    child: const Text('Mark Lost'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(foregroundColor: Colors.orange.shade800),
                    onPressed: _showHoldDialog,
                    child: const Text('Hold / No Action'),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSmartActionCard() {
    Color bg = Colors.blue.shade50;
    Color fg = Colors.blue.shade900;
    if (_lead.isOverdue) {
      bg = Colors.red.shade50;
      fg = Colors.red.shade800;
    } else if (_lead.isTodayFollowup) {
      bg = Colors.amber.shade50;
      fg = Colors.amber.shade900;
    }

    return Card(
      elevation: 0,
      color: bg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: fg.withValues(alpha: 0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _lead.leadStatus.toUpperCase(),
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: fg),
                ),
                if (_lead.isOverdue)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: Colors.red.shade700, borderRadius: BorderRadius.circular(4)),
                    child: Text('OVERDUE ${_lead.overdueDays}d', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                  )
                else if (_lead.isTodayFollowup)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: Colors.amber.shade800, borderRadius: BorderRadius.circular(4)),
                    child: const Text('TODAY', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'NEXT ACTION: ${_lead.smartNextAction}',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: fg),
            ),
            const SizedBox(height: 2),
            Text(
              _lead.nextFollowupDate != null
                  ? 'Follow-up: ${DateFormat('EEEE, dd MMM yyyy').format(_lead.nextFollowupDate!)}'
                  : 'No scheduled follow-up',
              style: TextStyle(fontSize: 12, color: fg.withValues(alpha: 0.8)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(label, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          ),
        ],
      ),
    );
  }
}
