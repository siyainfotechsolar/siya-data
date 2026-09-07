import 'package:flutter/material.dart';
import '../models/staff_workload_model.dart';
import '../models/user_profile.dart';
import '../services/user_management_service.dart';

class StaffWorkloadDialog extends StatefulWidget {
  final List<UserProfile> users;

  const StaffWorkloadDialog({super.key, required this.users});

  @override
  State<StaffWorkloadDialog> createState() => _StaffWorkloadDialogState();
}

class _StaffWorkloadDialogState extends State<StaffWorkloadDialog> {
  bool _isLoading = true;
  List<StaffWorkload> _workloads = [];
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadWorkloads();
  }

  Future<void> _loadWorkloads() async {
    setState(() => _isLoading = true);
    final results = await UserManagementService.fetchWorkloadMetrics(widget.users);
    if (mounted) {
      setState(() {
        _workloads = results;
        _isLoading = false;
      });
    }
  }

  List<StaffWorkload> get _filteredList {
    if (_searchQuery.trim().isEmpty) return _workloads;
    final q = _searchQuery.toLowerCase();
    return _workloads.where((w) {
      return w.staffName.toLowerCase().contains(q) ||
          w.email.toLowerCase().contains(q) ||
          w.role.toLowerCase().contains(q) ||
          (w.department ?? '').toLowerCase().contains(q);
    }).toList();
  }

  Color _getWorkloadBadgeColor(String level) {
    switch (level) {
      case 'Overloaded':
        return Colors.red.shade700;
      case 'High':
        return Colors.orange.shade800;
      case 'Moderate':
        return Colors.blue.shade700;
      case 'Light':
      default:
        return Colors.green.shade700;
    }
  }

  Color _getWorkloadBgColor(String level) {
    switch (level) {
      case 'Overloaded':
        return Colors.red.shade50;
      case 'High':
        return Colors.orange.shade50;
      case 'Moderate':
        return Colors.blue.shade50;
      case 'Light':
      default:
        return Colors.green.shade50;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 960,
        height: 700,
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // Header
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: theme.colorScheme.primaryContainer,
                  radius: 22,
                  child: Icon(Icons.analytics_rounded, color: theme.colorScheme.onPrimaryContainer),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Intelligent Staff Workload Engine',
                        style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Live tracking of pending tasks, follow-ups, and open customer issues across all team members.',
                        style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: _loadWorkloads,
                  icon: const Icon(Icons.refresh),
                  tooltip: 'Refresh metrics',
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Top Search & Summary Stats
            Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Search staff by name, email, department...',
                      prefixIcon: const Icon(Icons.search, size: 20),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    ),
                    onChanged: (val) => setState(() => _searchQuery = val),
                  ),
                ),
                const SizedBox(width: 16),
                Chip(
                  avatar: const Icon(Icons.people, size: 16),
                  label: Text('Staff Tracked: '),
                ),
                const SizedBox(width: 8),
                Chip(
                  backgroundColor: Colors.orange.shade50,
                  avatar: Icon(Icons.warning_amber_rounded, size: 16, color: Colors.orange.shade800),
                  label: Text(
                    'High / Overloaded: ',
                    style: TextStyle(color: Colors.orange.shade900, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Content Table
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _filteredList.isEmpty
                      ? const Center(child: Text('No staff workload data available.'))
                      : Card(
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(color: theme.colorScheme.outlineVariant),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: SingleChildScrollView(
                              child: DataTable(
                                headingRowColor: WidgetStateProperty.all(theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3)),
                                columns: const [
                                  DataColumn(label: Text('Staff Member', style: TextStyle(fontWeight: FontWeight.bold))),
                                  DataColumn(label: Text('Role / Dept', style: TextStyle(fontWeight: FontWeight.bold))),
                                  DataColumn(label: Text('Workload Status', style: TextStyle(fontWeight: FontWeight.bold))),
                                  DataColumn(label: Text('Assigned Customers', style: TextStyle(fontWeight: FontWeight.bold))),
                                  DataColumn(label: Text('Pending Actions', style: TextStyle(fontWeight: FontWeight.bold))),
                                  DataColumn(label: Text('Follow-ups Today / Overdue', style: TextStyle(fontWeight: FontWeight.bold))),
                                  DataColumn(label: Text('Open Issues', style: TextStyle(fontWeight: FontWeight.bold))),
                                  DataColumn(label: Text('Installations', style: TextStyle(fontWeight: FontWeight.bold))),
                                  DataColumn(label: Text('Completed', style: TextStyle(fontWeight: FontWeight.bold))),
                                ],
                                rows: _filteredList.map((w) {
                                  final badgeColor = _getWorkloadBadgeColor(w.workloadLevel);
                                  final bgColor = _getWorkloadBgColor(w.workloadLevel);

                                  return DataRow(
                                    cells: [
                                      DataCell(
                                        Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(w.staffName, style: const TextStyle(fontWeight: FontWeight.bold)),
                                            Text(w.email, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                                          ],
                                        ),
                                      ),
                                      DataCell(
                                        Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(w.role, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                                            if (w.department != null && w.department!.isNotEmpty)
                                              Text(w.department!, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                                          ],
                                        ),
                                      ),
                                      DataCell(
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: bgColor,
                                            borderRadius: BorderRadius.circular(6),
                                            border: Border.all(color: badgeColor.withValues(alpha: 0.3)),
                                          ),
                                          child: Text(
                                            ' ()',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                              color: badgeColor,
                                            ),
                                          ),
                                        ),
                                      ),
                                      DataCell(
                                        Center(
                                          child: Text(
                                            '',
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                          ),
                                        ),
                                      ),
                                      DataCell(
                                        Center(
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: w.pendingActionsCount > 0 ? Colors.orange.shade50 : Colors.grey.shade100,
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              '',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                color: w.pendingActionsCount > 0 ? Colors.orange.shade900 : Colors.black87,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                      DataCell(
                                        Row(
                                          children: [
                                            if (w.todayFollowupsCount > 0)
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: Colors.blue.shade50,
                                                  borderRadius: BorderRadius.circular(4),
                                                ),
                                                child: Text(
                                                  ' Today',
                                                  style: TextStyle(fontSize: 11, color: Colors.blue.shade900, fontWeight: FontWeight.bold),
                                                ),
                                              ),
                                            if (w.todayFollowupsCount > 0 && w.overdueFollowupsCount > 0)
                                              const SizedBox(width: 4),
                                            if (w.overdueFollowupsCount > 0)
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: Colors.red.shade50,
                                                  borderRadius: BorderRadius.circular(4),
                                                ),
                                                child: Text(
                                                  ' Overdue',
                                                  style: TextStyle(fontSize: 11, color: Colors.red.shade900, fontWeight: FontWeight.bold),
                                                ),
                                              ),
                                            if (w.todayFollowupsCount == 0 && w.overdueFollowupsCount == 0)
                                              const Text('-', style: TextStyle(color: Colors.grey)),
                                          ],
                                        ),
                                      ),
                                      DataCell(
                                        Center(
                                          child: Text(
                                            w.openIssuesCount > 0 ? '' : '-',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: w.openIssuesCount > 0 ? Colors.red.shade700 : Colors.black54,
                                            ),
                                          ),
                                        ),
                                      ),
                                      DataCell(
                                        Center(
                                          child: Text(
                                            w.installationTasksCount > 0 ? '' : '-',
                                            style: const TextStyle(fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                      ),
                                      DataCell(
                                        Center(
                                          child: Text(
                                            '',
                                            style: TextStyle(color: Colors.green.shade800, fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                      ),
                                    ],
                                  );
                                }).toList(),
                              ),
                            ),
                          ),
                        ),
            ),
            const SizedBox(height: 16),

            // Footer info note
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 18, color: Colors.blue.shade700),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Workload scores are calculated dynamically from active customer assignments, actionable queue tasks, and unassigned/assigned open customer tickets. Inactive staff do not receive new workload assignments.',
                      style: TextStyle(fontSize: 11, color: Colors.black87),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
