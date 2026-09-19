import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/office_task.dart';
import '../services/office_task_service.dart';
import '../widgets/create_office_task_dialog.dart';
import '../widgets/office_staff_work_log_dialog.dart';

class OfficeTasksScreen extends StatefulWidget {
  const OfficeTasksScreen({super.key});

  @override
  State<OfficeTasksScreen> createState() => _OfficeTasksScreenState();
}

class _OfficeTasksScreenState extends State<OfficeTasksScreen> {
  List<OfficeTask> _tasks = [];
  List<Map<String, String>> _staffMembers = [];
  bool _isLoading = true;

  String _selectedStatus = 'ALL';
  String _selectedTaskType = 'ALL';
  String _selectedStaff = 'ALL';
  String _selectedVillage = 'ALL';
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final results = await Future.wait([
      OfficeTaskService.fetchTasks(
        status: _selectedStatus,
        taskType: _selectedTaskType,
        staffName: _selectedStaff,
        village: _selectedVillage,
        searchQuery: _searchQuery,
      ),
      OfficeTaskService.fetchActiveOfficeStaff(),
    ]);

    if (mounted) {
      setState(() {
        _tasks = results[0] as List<OfficeTask>;
        _staffMembers = results[1] as List<Map<String, String>>;
        _isLoading = false;
      });
    }
  }

  List<String> get _distinctVillages {
    final villages = _tasks
        .map((t) => t.village)
        .where((v) => v != null && v.trim().isNotEmpty)
        .map((v) => v!.trim())
        .toSet()
        .toList();
    villages.sort();
    return ['ALL', ...villages];
  }

  int get _totalCount => _tasks.length;
  int get _pendingCount => _tasks.where((t) => t.isPending || t.isInProgress).length;
  int get _todayCount => _tasks.where((t) => t.isDueToday).length;
  int get _overdueCount => _tasks.where((t) => t.isOverdue).length;
  int get _completedCount => _tasks.where((t) => t.isCompleted).length;

  Future<void> _openCreateTaskDialog() async {
    final created = await showDialog<OfficeTask>(
      context: context,
      builder: (_) => const CreateOfficeTaskDialog(),
    );

    if (created != null && mounted) {
      _loadData();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Task "${created.title}" assigned to ${created.assignedToName}!'),
          backgroundColor: const Color(0xFF059669),
        ),
      );
    }
  }

  Future<void> _showReassignDialog(OfficeTask task) async {
    String? chosenStaffId;
    String? chosenStaffName;
    final reasonController = TextEditingController();

    if (_staffMembers.isNotEmpty) {
      final defaultStaff = _staffMembers.firstWhere(
        (s) => s['name'] != task.assignedToName,
        orElse: () => _staffMembers.first,
      );
      chosenStaffId = defaultStaff['id'];
      chosenStaffName = defaultStaff['name'];
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              const Icon(Icons.swap_horiz_rounded, color: Color(0xFF2563EB), size: 24),
              const SizedBox(width: 8),
              Text('Reassign Task: ${task.title}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Currently Assigned To: ${task.assignedToName}', style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                value: chosenStaffId,
                decoration: const InputDecoration(
                  labelText: 'Reassign To (Active Office Staff) *',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person_pin_rounded),
                ),
                items: _staffMembers.map((s) {
                  return DropdownMenuItem<String>(
                    value: s['id'],
                    child: Text('${s['name']} (${(s['role'] ?? 'staff').replaceAll('_', ' ')})'),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) {
                    final s = _staffMembers.firstWhere((m) => m['id'] == val);
                    setDialogState(() {
                      chosenStaffId = val;
                      chosenStaffName = s['name'];
                    });
                  }
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: reasonController,
                decoration: const InputDecoration(
                  labelText: 'Reassignment Reason / Note',
                  hintText: 'e.g. Staff on leave, balancing workload',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Confirm Reassign'),
            ),
          ],
        ),
      ),
    );

    if (confirmed == true && chosenStaffName != null) {
      try {
        await OfficeTaskService.reassignTask(
          task: task,
          newStaffId: chosenStaffId ?? '',
          newStaffName: chosenStaffName!,
          reason: reasonController.text.trim(),
        );
        _loadData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Task reassigned to $chosenStaffName!'),
              backgroundColor: const Color(0xFF059669),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Reassign error: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  Future<void> _showStatusUpdateDialog(OfficeTask task) async {
    String selectedStatus = task.status;
    final noteController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('Update Task Status: ${task.title}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DropdownButtonFormField<String>(
                value: selectedStatus,
                decoration: const InputDecoration(
                  labelText: 'Status',
                  border: OutlineInputBorder(),
                ),
                items: OfficeTaskStatus.all.map((s) {
                  return DropdownMenuItem(value: s, child: Text(s));
                }).toList(),
                onChanged: (val) {
                  if (val != null) setDialogState(() => selectedStatus = val);
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: noteController,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: selectedStatus == OfficeTaskStatus.completed
                      ? 'Completion Note'
                      : (selectedStatus == OfficeTaskStatus.hold ? 'Hold Reason' : 'Remarks / Note'),
                  border: const OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Update'),
            ),
          ],
        ),
      ),
    );

    if (confirmed == true) {
      try {
        await OfficeTaskService.updateTaskStatus(
          task: task,
          newStatus: selectedStatus,
          remarks: noteController.text.trim(),
          completionNote: selectedStatus == OfficeTaskStatus.completed ? noteController.text.trim() : null,
          holdReason: selectedStatus == OfficeTaskStatus.hold ? noteController.text.trim() : null,
          staffName: task.assignedToName,
          staffId: task.assignedToId,
        );
        _loadData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Task status updated to $selectedStatus!'),
              backgroundColor: const Color(0xFF059669),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Update error: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  void _showTaskWorkLog(OfficeTask task) {
    showDialog(
      context: context,
      builder: (_) => OfficeStaffWorkLogDialog(taskId: task.id, taskTitle: task.title),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd MMM yyyy');

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.assignment_ind_rounded, color: Color(0xFF2563EB)),
            SizedBox(width: 10),
            Text(
              'Office Staff Task Management',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _loadData,
          ),
          const SizedBox(width: 8),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF059669),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            onPressed: _openCreateTaskDialog,
            icon: const Icon(Icons.add, size: 18),
            label: const Text('+ Create Task', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: Column(
        children: [
          // 1. KPI Metric Summary Cards
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                _buildKpiCard('Total Tasks', '$_totalCount', const Color(0xFF2563EB), Icons.assignment_rounded),
                const SizedBox(width: 12),
                _buildKpiCard('Pending', '$_pendingCount', const Color(0xFFD97706), Icons.pending_actions_rounded),
                const SizedBox(width: 12),
                _buildKpiCard('Due Today', '$_todayCount', const Color(0xFF4F46E5), Icons.today_rounded),
                const SizedBox(width: 12),
                _buildKpiCard('Overdue', '$_overdueCount', const Color(0xFFDC2626), Icons.warning_rounded),
                const SizedBox(width: 12),
                _buildKpiCard('Completed', '$_completedCount', const Color(0xFF059669), Icons.task_alt_rounded),
              ],
            ),
          ),

          // 2. Filters & Search Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Card(
              elevation: 0,
              color: Colors.grey.shade50,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: BorderSide(color: Colors.grey.shade200),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Row(
                  children: [
                    // Search box
                    Expanded(
                      flex: 3,
                      child: TextField(
                        controller: _searchController,
                        onChanged: (v) {
                          _searchQuery = v;
                          _loadData();
                        },
                        decoration: InputDecoration(
                          hintText: 'Search customer, consumer no, task, staff...',
                          prefixIcon: const Icon(Icons.search, size: 18),
                          suffixIcon: _searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, size: 16),
                                  onPressed: () {
                                    _searchController.clear();
                                    _searchQuery = '';
                                    _loadData();
                                  },
                                )
                              : null,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),

                    // Staff Filter
                    DropdownButton<String>(
                      value: _selectedStaff,
                      hint: const Text('Staff'),
                      items: [
                        const DropdownMenuItem(value: 'ALL', child: Text('All Staff')),
                        ..._staffMembers.map((s) => DropdownMenuItem(value: s['name'], child: Text(s['name'] ?? ''))),
                      ],
                      onChanged: (v) {
                        if (v != null) {
                          setState(() => _selectedStaff = v);
                          _loadData();
                        }
                      },
                    ),
                    const SizedBox(width: 10),

                    // Task Type Filter
                    DropdownButton<String>(
                      value: _selectedTaskType,
                      hint: const Text('Task Type'),
                      items: [
                        const DropdownMenuItem(value: 'ALL', child: Text('All Task Types')),
                        ...OfficeTaskType.all.map((t) => DropdownMenuItem(value: t, child: Text(t))),
                      ],
                      onChanged: (v) {
                        if (v != null) {
                          setState(() => _selectedTaskType = v);
                          _loadData();
                        }
                      },
                    ),
                    const SizedBox(width: 10),

                    // Status Filter
                    DropdownButton<String>(
                      value: _selectedStatus,
                      hint: const Text('Status'),
                      items: [
                        const DropdownMenuItem(value: 'ALL', child: Text('All Statuses')),
                        ...OfficeTaskStatus.all.map((s) => DropdownMenuItem(value: s, child: Text(s))),
                      ],
                      onChanged: (v) {
                        if (v != null) {
                          setState(() => _selectedStatus = v);
                          _loadData();
                        }
                      },
                    ),
                    const SizedBox(width: 10),

                    // Village Filter
                    DropdownButton<String>(
                      value: _selectedVillage,
                      hint: const Text('Village'),
                      items: _distinctVillages.map((vg) => DropdownMenuItem(value: vg, child: Text(vg == 'ALL' ? 'All Villages' : vg))).toList(),
                      onChanged: (v) {
                        if (v != null) {
                          setState(() => _selectedVillage = v);
                          _loadData();
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),

          // 3. Tasks Table
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _tasks.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.assignment_turned_in_outlined, size: 48, color: Colors.grey.shade400),
                            const SizedBox(height: 12),
                            const Text(
                              'No Office Staff Tasks Found',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Click "+ Create Task" to assign work to active office staff.',
                              style: TextStyle(color: Colors.grey, fontSize: 13),
                            ),
                          ],
                        ),
                      )
                    : SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: Card(
                          elevation: 1,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          child: DataTable(
                            headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
                            columns: const [
                              DataColumn(label: Text('Task', style: TextStyle(fontWeight: FontWeight.bold))),
                              DataColumn(label: Text('Customer', style: TextStyle(fontWeight: FontWeight.bold))),
                              DataColumn(label: Text('Assigned Staff', style: TextStyle(fontWeight: FontWeight.bold))),
                              DataColumn(label: Text('Due Date', style: TextStyle(fontWeight: FontWeight.bold))),
                              DataColumn(label: Text('Priority', style: TextStyle(fontWeight: FontWeight.bold))),
                              DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.bold))),
                              DataColumn(label: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold))),
                            ],
                            rows: _tasks.map((t) {
                              return DataRow(
                                cells: [
                                  // Task Column
                                  DataCell(
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(OfficeTaskType.getIcon(t.taskType), size: 18, color: const Color(0xFF2563EB)),
                                        const SizedBox(width: 8),
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Text(t.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                            Text(t.taskType, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),

                                  // Customer Column
                                  DataCell(
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Text(t.customerName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                                        Text('${t.consumerNo}${t.village != null ? " • ${t.village}" : ""}', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                                      ],
                                    ),
                                  ),

                                  // Assigned Staff Column
                                  DataCell(
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.person_outline, size: 16, color: Color(0xFF059669)),
                                        const SizedBox(width: 6),
                                        Text(t.assignedToName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                      ],
                                    ),
                                  ),

                                  // Due Date Column
                                  DataCell(
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        if (t.isOverdue)
                                          const Icon(Icons.error_outline, color: Colors.red, size: 16)
                                        else if (t.isDueToday)
                                          const Icon(Icons.alarm, color: Colors.orange, size: 16),
                                        if (t.isOverdue || t.isDueToday) const SizedBox(width: 4),
                                        Text(
                                          t.dueDate != null ? dateFormat.format(t.dueDate!) : 'No date',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: (t.isOverdue || t.isDueToday) ? FontWeight.bold : FontWeight.normal,
                                            color: t.isOverdue ? Colors.red : (t.isDueToday ? Colors.orange.shade800 : Colors.black87),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                  // Priority Column
                                  DataCell(
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: t.priorityColor.withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(color: t.priorityColor.withValues(alpha: 0.4)),
                                      ),
                                      child: Text(
                                        t.priority,
                                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: t.priorityColor),
                                      ),
                                    ),
                                  ),

                                  // Status Column
                                  DataCell(
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: t.statusColor.withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(color: t.statusColor.withValues(alpha: 0.4)),
                                      ),
                                      child: Text(
                                        t.status.toUpperCase(),
                                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: t.statusColor),
                                      ),
                                    ),
                                  ),

                                  // Actions Column
                                  DataCell(
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.swap_horiz_rounded, size: 20),
                                          tooltip: 'Reassign Staff',
                                          color: const Color(0xFF2563EB),
                                          onPressed: () => _showReassignDialog(t),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.edit_note_rounded, size: 20),
                                          tooltip: 'Update Status',
                                          color: const Color(0xFF059669),
                                          onPressed: () => _showStatusUpdateDialog(t),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.history_rounded, size: 20),
                                          tooltip: 'View Work Log',
                                          color: const Color(0xFF7E22CE),
                                          onPressed: () => _showTaskWorkLog(t),
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
          ),
        ],
      ),
    );
  }

  Widget _buildKpiCard(String label, String value, Color color, IconData icon) {
    return Expanded(
      child: Card(
        elevation: 0,
        color: color.withValues(alpha: 0.08),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(color: color.withValues(alpha: 0.2)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Icon(icon, color: color, size: 26),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade700, fontWeight: FontWeight.w600)),
                  Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
