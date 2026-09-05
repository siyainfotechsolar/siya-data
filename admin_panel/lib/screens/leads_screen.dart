import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/lead_record.dart';
import '../services/lead_service.dart';
import '../widgets/lead_form_dialog.dart';
import '../widgets/lead_details_dialog.dart';

class LeadsScreen extends StatefulWidget {
  final String? initialScope;
  final String? initialStatus;

  const LeadsScreen({
    super.key,
    this.initialScope,
    this.initialStatus,
  });

  @override
  State<LeadsScreen> createState() => _LeadsScreenState();
}

class _LeadsScreenState extends State<LeadsScreen> {
  List<LeadRecord> _leads = [];
  LeadMetrics _metrics = const LeadMetrics();
  bool _isLoading = false;

  final TextEditingController _searchController = TextEditingController();
  String _selectedScope = 'all'; // 'all', 'overdue', 'today', 'upcoming'
  String _selectedStatus = 'All';

  final List<String> _statusOptions = [
    'All',
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
    if (widget.initialScope != null) _selectedScope = widget.initialScope!;
    if (widget.initialStatus != null) _selectedStatus = widget.initialStatus!;
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final metricsFuture = LeadService.fetchLeadMetrics();
    final leadsFuture = LeadService.fetchLeads(
      scopeFilter: _selectedScope,
      statusFilter: _selectedStatus == 'All' ? null : _selectedStatus,
      searchQuery: _searchController.text.trim().isEmpty ? null : _searchController.text.trim(),
    );

    final results = await Future.wait([metricsFuture, leadsFuture]);

    if (mounted) {
      setState(() {
        _metrics = results[0] as LeadMetrics;
        _leads = results[1] as List<LeadRecord>;
        _isLoading = false;
      });
    }
  }

  void _openLeadDetails(LeadRecord lead) {
    showDialog(
      context: context,
      builder: (_) => LeadDetailsDialog(
        lead: lead,
        onRefresh: _loadData,
      ),
    );
  }

  void _openCreateLeadDialog() {
    showDialog(
      context: context,
      builder: (_) => LeadFormDialog(
        onSaved: _loadData,
      ),
    );
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: Column(
        children: [
          // Screen Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            color: Colors.white,
            child: Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.leaderboard_rounded, color: theme.colorScheme.primary, size: 28),
                        const SizedBox(width: 10),
                        const Text(
                          'Lead Management',
                          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Potential solar inquiries and pre-conversion lead pipelines',
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                    ),
                  ],
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  tooltip: 'Refresh Leads',
                  onPressed: _loadData,
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  icon: const Icon(Icons.add),
                  label: const Text('New Lead'),
                  onPressed: _openCreateLeadDialog,
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Metrics Summary Cards
          _buildMetricsBar(),

          // Filter & Search Toolbar
          _buildToolbar(),

          // Main Data Content
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _leads.isEmpty
                    ? _buildEmptyState()
                    : _buildLeadsTable(),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricsBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      color: Colors.white,
      child: Row(
        children: [
          _metricCard('Total Leads', '${_metrics.total}', Icons.groups_outlined, Colors.blueGrey, () {
            setState(() {
              _selectedScope = 'all';
              _selectedStatus = 'All';
            });
            _loadData();
          }),
          const SizedBox(width: 10),
          _metricCard('New Leads', '${_metrics.newLeads}', Icons.fiber_new_outlined, Colors.blue, () {
            setState(() {
              _selectedScope = 'all';
              _selectedStatus = 'New';
            });
            _loadData();
          }),
          const SizedBox(width: 10),
          _metricCard(
            'Today\'s Follow-ups',
            '${_metrics.todayFollowups}',
            Icons.notifications_active_outlined,
            Colors.amber.shade800,
            () {
              setState(() {
                _selectedScope = 'today';
                _selectedStatus = 'All';
              });
              _loadData();
            },
            isAlert: _metrics.todayFollowups > 0,
          ),
          const SizedBox(width: 10),
          _metricCard(
            'Overdue Follow-ups',
            '${_metrics.overdueFollowups}',
            Icons.warning_amber_rounded,
            Colors.red.shade700,
            () {
              setState(() {
                _selectedScope = 'overdue';
                _selectedStatus = 'All';
              });
              _loadData();
            },
            isAlert: _metrics.overdueFollowups > 0,
          ),
          const SizedBox(width: 10),
          _metricCard('Converted', '${_metrics.converted}', Icons.check_circle_outline, Colors.green.shade700, () {
            setState(() {
              _selectedScope = 'all';
              _selectedStatus = 'Converted';
            });
            _loadData();
          }),
          const SizedBox(width: 10),
          _metricCard('Hold / Lost', '${_metrics.noActionRequired + _metrics.lost}', Icons.pause_circle_outline, Colors.orange.shade800, () {
            setState(() {
              _selectedScope = 'all';
              _selectedStatus = 'No Action Required';
            });
            _loadData();
          }),
        ],
      ),
    );
  }

  Widget _metricCard(String label, String value, IconData icon, Color color, VoidCallback onTap, {bool isAlert = false}) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: isAlert ? color.withValues(alpha: 0.08) : Colors.grey.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: isAlert ? color.withValues(alpha: 0.4) : Colors.grey.shade200),
          ),
          child: Row(
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    value,
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: color),
                  ),
                  Text(
                    label,
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 11),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildToolbar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
      color: Colors.white,
      child: Row(
        children: [
          // Scope segmented tabs
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'all', label: Text('All')),
              ButtonSegment(value: 'today', label: Text('Today')),
              ButtonSegment(value: 'overdue', label: Text('Overdue')),
              ButtonSegment(value: 'upcoming', label: Text('Upcoming')),
            ],
            selected: {_selectedScope},
            onSelectionChanged: (set) {
              setState(() => _selectedScope = set.first);
              _loadData();
            },
            style: const ButtonStyle(visualDensity: VisualDensity.compact),
          ),
          const SizedBox(width: 16),

          // Stage dropdown
          SizedBox(
            width: 180,
            child: DropdownButtonFormField<String>(
              initialValue: _selectedStatus,
              decoration: const InputDecoration(
                isDense: true,
                labelText: 'Lead Stage',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              items: _statusOptions.map((s) => DropdownMenuItem(value: s, child: Text(s, style: const TextStyle(fontSize: 13)))).toList(),
              onChanged: (v) {
                setState(() => _selectedStatus = v!);
                _loadData();
              },
            ),
          ),
          const SizedBox(width: 16),

          // Search Field
          Expanded(
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search customer name, mobile, consumer no, village...',
                prefixIcon: const Icon(Icons.search, size: 20),
                isDense: true,
                border: const OutlineInputBorder(),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 16),
                        onPressed: () {
                          _searchController.clear();
                          _loadData();
                        },
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
              onSubmitted: (_) => _loadData(),
            ),
          ),
          const SizedBox(width: 8),
          FilledButton.tonal(
            onPressed: _loadData,
            child: const Text('Search'),
          ),
        ],
      ),
    );
  }

  Widget _buildLeadsTable() {
    return Container(
      margin: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: SingleChildScrollView(
          child: DataTable(
            showCheckboxColumn: false,
            headingRowColor: WidgetStateProperty.all(Colors.grey.shade100),
            dataRowMinHeight: 52,
            dataRowMaxHeight: 64,
            columns: const [
              DataColumn(label: Text('CUSTOMER & MOBILE', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
              DataColumn(label: Text('LOCATION', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
              DataColumn(label: Text('INQUIRY / PRODUCT', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
              DataColumn(label: Text('STAGE / STATUS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
              DataColumn(label: Text('NEXT FOLLOW-UP', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
              DataColumn(label: Text('SMART NEXT ACTION', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
              DataColumn(label: Text('ASSIGNED', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
              DataColumn(label: Text('ACTIONS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
            ],
            rows: _leads.map((l) {
              return DataRow(
                onSelectChanged: (_) => _openLeadDetails(l),
                cells: [
                  // Customer & Mobile
                  DataCell(
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          l.customerName,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        Text(
                          l.mobileNo,
                          style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  // Location
                  DataCell(
                    Text(
                      l.village != null && l.village!.isNotEmpty
                          ? '${l.village}${l.taluka != null ? ", " + l.taluka! : ""}'
                          : '—',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                  // Inquiry / Product
                  DataCell(
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '${l.interestedIn} • ${l.approxSystemSize ?? ""}',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                        ),
                        Text(
                          'Source: ${l.leadSource}',
                          style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                        ),
                      ],
                    ),
                  ),
                  // Stage / Status Badge
                  DataCell(_buildStatusBadge(l.leadStatus)),
                  // Next Follow-up
                  DataCell(_buildFollowupCell(l)),
                  // Smart Next Action
                  DataCell(
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        l.smartNextAction,
                        style: TextStyle(color: Colors.blue.shade900, fontSize: 11, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                  // Assigned Staff
                  DataCell(
                    Text(
                      l.assignedStaffName ?? 'Unassigned',
                      style: TextStyle(
                        fontSize: 12,
                        color: l.assignedStaffName != null ? Colors.black87 : Colors.grey.shade400,
                      ),
                    ),
                  ),
                  // Actions
                  DataCell(
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.phone, size: 18),
                          tooltip: 'Call',
                          onPressed: () => _handleCall(l.mobileNo),
                        ),
                        IconButton(
                          icon: const Icon(Icons.chat, size: 18, color: Colors.green),
                          tooltip: 'WhatsApp',
                          onPressed: () => _handleWhatsApp(l.whatsappNo ?? l.mobileNo),
                        ),
                        IconButton(
                          icon: const Icon(Icons.open_in_new, size: 18),
                          tooltip: 'Open Details & Convert',
                          onPressed: () => _openLeadDetails(l),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildFollowupCell(LeadRecord l) {
    if (l.isTerminalState) {
      return Text('—', style: TextStyle(color: Colors.grey.shade400));
    }
    if (l.nextFollowupDate == null) {
      return Text('Not set', style: TextStyle(color: Colors.grey.shade500, fontSize: 12));
    }

    final dateStr = DateFormat('dd/MM/yyyy').format(l.nextFollowupDate!);

    if (l.isOverdue) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(dateStr, style: TextStyle(color: Colors.red.shade800, fontWeight: FontWeight.bold, fontSize: 12)),
          Text(
            'Overdue ${l.overdueDays}d',
            style: TextStyle(color: Colors.red.shade700, fontSize: 10, fontWeight: FontWeight.bold),
          ),
        ],
      );
    } else if (l.isTodayFollowup) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(dateStr, style: TextStyle(color: Colors.amber.shade900, fontWeight: FontWeight.bold, fontSize: 12)),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            decoration: BoxDecoration(color: Colors.amber.shade800, borderRadius: BorderRadius.circular(2)),
            child: const Text('TODAY', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
          ),
        ],
      );
    }

    return Text(dateStr, style: const TextStyle(fontSize: 12));
  }

  Widget _buildStatusBadge(String status) {
    Color bg;
    Color fg;
    switch (status) {
      case 'New':
        bg = Colors.blue.shade50;
        fg = Colors.blue.shade800;
        break;
      case 'Contacted':
      case 'Interested':
        bg = Colors.cyan.shade50;
        fg = Colors.cyan.shade800;
        break;
      case 'Site Survey':
      case 'Quotation':
        bg = Colors.purple.shade50;
        fg = Colors.purple.shade800;
        break;
      case 'Follow-up':
        bg = Colors.amber.shade50;
        fg = Colors.amber.shade900;
        break;
      case 'Converted':
        bg = Colors.green.shade50;
        fg = Colors.green.shade800;
        break;
      case 'Lost':
        bg = Colors.red.shade50;
        fg = Colors.red.shade800;
        break;
      case 'No Action Required':
        bg = Colors.orange.shade50;
        fg = Colors.orange.shade900;
        break;
      default:
        bg = Colors.grey.shade100;
        fg = Colors.grey.shade800;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
      child: Text(
        status,
        style: TextStyle(color: fg, fontWeight: FontWeight.bold, fontSize: 11),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.leaderboard_outlined, size: 54, color: Colors.grey.shade400),
          const SizedBox(height: 12),
          const Text(
            'No leads found matching current filter',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            'Create a new lead or adjust your filter/search criteria',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            icon: const Icon(Icons.add),
            label: const Text('Add New Lead'),
            onPressed: _openCreateLeadDialog,
          ),
        ],
      ),
    );
  }
}
