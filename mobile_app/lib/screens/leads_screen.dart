import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/lead_record.dart';
import '../services/lead_service.dart';
import 'lead_detail_screen.dart';
import 'lead_form_screen.dart';

class MobileLeadsScreen extends StatefulWidget {
  final String? initialFilterScope;

  const MobileLeadsScreen({super.key, this.initialFilterScope});

  @override
  State<MobileLeadsScreen> createState() => _MobileLeadsScreenState();
}

class _MobileLeadsScreenState extends State<MobileLeadsScreen> {
  List<LeadRecord> _leads = [];
  MobileLeadMetrics _metrics = const MobileLeadMetrics();
  bool _isLoading = false;

  late String _scope; // 'today', 'overdue', 'my_leads', 'all'
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _scope = widget.initialFilterScope ?? 'all';
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final mFuture = MobileLeadService.fetchLeadMetrics();
    final lFuture = MobileLeadService.fetchLeads(
      filterScope: _scope,
      searchQuery: _searchController.text.trim().isEmpty ? null : _searchController.text.trim(),
    );

    final res = await Future.wait([mFuture, lFuture]);

    if (mounted) {
      setState(() {
        _metrics = res[0] as MobileLeadMetrics;
        _leads = res[1] as List<LeadRecord>;
        _isLoading = false;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Leads & Prospects'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('New Lead'),
        onPressed: () async {
          final created = await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const MobileLeadFormScreen()),
          );
          if (created == true) _loadData();
        },
      ),
      body: Column(
        children: [
          // Search box
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search customer name, mobile, village...',
                prefixIcon: const Icon(Icons.search),
                isDense: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          _loadData();
                        },
                      )
                    : null,
              ),
              onSubmitted: (_) => _loadData(),
            ),
          ),

          // Scope segment filter chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                _buildFilterChip('All Leads', 'all', _metrics.activeLeads),
                const SizedBox(width: 8),
                _buildFilterChip("Today's Work", 'today', _metrics.todayFollowups, isAlert: _metrics.todayFollowups > 0),
                const SizedBox(width: 8),
                _buildFilterChip('Overdue', 'overdue', _metrics.overdueFollowups, isDanger: _metrics.overdueFollowups > 0),
                const SizedBox(width: 8),
                _buildFilterChip('My Leads', 'my_leads', _metrics.myLeads),
              ],
            ),
          ),
          const Divider(height: 16),

          // Lead list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _leads.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.leaderboard_outlined, size: 48, color: Colors.grey.shade400),
                            const SizedBox(height: 8),
                            Text('No leads found in this view', style: TextStyle(color: Colors.grey.shade600)),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 80),
                        itemCount: _leads.length,
                        itemBuilder: (ctx, idx) => _buildLeadCard(_leads[idx]),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value, int count, {bool isAlert = false, bool isDanger = false}) {
    final isSelected = _scope == value;
    Color chipColor = isSelected ? Theme.of(context).colorScheme.primaryContainer : Colors.grey.shade100;
    if (isDanger && count > 0) {
      chipColor = isSelected ? Colors.red.shade100 : Colors.red.shade50;
    } else if (isAlert && count > 0) {
      chipColor = isSelected ? Colors.amber.shade200 : Colors.amber.shade50;
    }

    return FilterChip(
      selected: isSelected,
      label: Text('$label ($count)'),
      backgroundColor: chipColor,
      selectedColor: chipColor,
      onSelected: (_) {
        setState(() => _scope = value);
        _loadData();
      },
    );
  }

  Widget _buildLeadCard(LeadRecord lead) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: lead.isOverdue
              ? Colors.red.shade300
              : lead.isTodayFollowup
                  ? Colors.amber.shade400
                  : Colors.grey.shade200,
          width: (lead.isOverdue || lead.isTodayFollowup) ? 1.5 : 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () async {
          final changed = await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => MobileLeadDetailScreen(lead: lead)),
          );
          if (changed == true) _loadData();
        },
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: Name & Status
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          lead.customerName,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${lead.mobileNo} ${lead.village != null ? "• " + lead.village! : ""}',
                          style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  _buildStatusBadge(lead.leadStatus),
                ],
              ),
              const SizedBox(height: 8),

              // Requirement info
              Row(
                children: [
                  Icon(Icons.solar_power_outlined, size: 16, color: Colors.grey.shade700),
                  const SizedBox(width: 6),
                  Text(
                    '${lead.interestedIn} • ${lead.approxSystemSize ?? "Standard"}',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                  ),
                  const Spacer(),
                  if (lead.nextFollowupDate != null && !lead.isTerminalState)
                    _buildFollowupLabel(lead),
                ],
              ),
              const SizedBox(height: 8),

              // Smart Next Action row
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'Action: ${lead.smartNextAction}',
                  style: TextStyle(color: Colors.blue.shade900, fontWeight: FontWeight.w600, fontSize: 11),
                ),
              ),
              const SizedBox(height: 8),

              // Action shortcuts
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  IconButton.filledTonal(
                    icon: const Icon(Icons.phone, size: 18),
                    tooltip: 'Call',
                    onPressed: () => _handleCall(lead.mobileNo),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filledTonal(
                    icon: const Icon(Icons.chat, size: 18, color: Colors.green),
                    tooltip: 'WhatsApp',
                    onPressed: () => _handleWhatsApp(lead.whatsappNo ?? lead.mobileNo),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.tonal(
                    onPressed: () async {
                      final changed = await Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => MobileLeadDetailScreen(lead: lead)),
                      );
                      if (changed == true) _loadData();
                    },
                    child: const Text('Details'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFollowupLabel(LeadRecord lead) {
    if (lead.isOverdue) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(color: Colors.red.shade700, borderRadius: BorderRadius.circular(4)),
        child: Text(
          'OVERDUE ${lead.overdueDays}d',
          style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
        ),
      );
    } else if (lead.isTodayFollowup) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(color: Colors.amber.shade800, borderRadius: BorderRadius.circular(4)),
        child: const Text(
          'TODAY',
          style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
        ),
      );
    }
    return Text(
      DateFormat('dd/MM').format(lead.nextFollowupDate!),
      style: TextStyle(color: Colors.grey.shade600, fontSize: 11),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color bg = Colors.grey.shade100;
    Color fg = Colors.grey.shade800;

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
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
      child: Text(
        status,
        style: TextStyle(color: fg, fontWeight: FontWeight.bold, fontSize: 11),
      ),
    );
  }
}
