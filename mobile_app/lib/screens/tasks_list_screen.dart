import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/customer_task.dart';
import '../services/task_service.dart';
import '../services/offline_task_sync_service.dart';
import '../services/record_service.dart';
import 'task_detail_screen.dart';

class TasksListScreen extends StatefulWidget {
  final String? initialSourceFilter;

  const TasksListScreen({super.key, this.initialSourceFilter});

  @override
  State<TasksListScreen> createState() => _TasksListScreenState();
}

class _TasksListScreenState extends State<TasksListScreen> {
  List<CustomerTask> _tasks = [];
  bool _isLoading = true;
  String _selectedStatus = 'ALL';
  late String _selectedSource;
  int _pendingSyncCount = 0;

  @override
  void initState() {
    super.initState();
    _selectedSource = widget.initialSourceFilter ?? 'ALL';
    _loadTasks();
  }

  Future<void> _loadTasks() async {
    setState(() => _isLoading = true);
    final tasks = await TaskService.fetchTasks(
      statusFilter: _selectedStatus == 'ALL' ? null : _selectedStatus,
      sourceFilter: _selectedSource == 'ALL' ? null : _selectedSource,
    );
    final pendingCount = OfflineTaskSyncService.pendingCount;

    if (mounted) {
      setState(() {
        _tasks = tasks;
        _pendingSyncCount = pendingCount;
        _isLoading = false;
      });
    }
  }

  Future<void> _handleManualSync() async {
    setState(() => _isLoading = true);
    final count = await TaskService.syncPendingOfflineTasks();
    await _loadTasks();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(count > 0
              ? 'Synced $count tasks successfully!'
              : 'All tasks already up to date.'),
          backgroundColor: const Color(0xFF059669),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd MMM, hh:mm a');

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Document Tasks',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          if (_pendingSyncCount > 0)
            IconButton(
              icon: Badge(
                label: Text('$_pendingSyncCount'),
                child: const Icon(Icons.sync_rounded),
              ),
              tooltip: 'Sync Offline Tasks',
              onPressed: _handleManualSync,
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadTasks,
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                FilterChip(
                  label: const Text('All Tasks'),
                  selected: _selectedSource == 'ALL' && _selectedStatus == 'ALL',
                  onSelected: (_) {
                    setState(() {
                      _selectedSource = 'ALL';
                      _selectedStatus = 'ALL';
                    });
                    _loadTasks();
                  },
                ),
                const SizedBox(width: 8),
                FilterChip(
                  avatar: const Icon(Icons.share, size: 14, color: Colors.green),
                  label: const Text('WhatsApp Shares'),
                  selected: _selectedSource == 'WhatsApp Share',
                  onSelected: (val) {
                    setState(() {
                      _selectedSource = val ? 'WhatsApp Share' : 'ALL';
                    });
                    _loadTasks();
                  },
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: const Text('New'),
                  selected: _selectedStatus == TaskStatus.newTask,
                  onSelected: (val) {
                    setState(() {
                      _selectedStatus = val ? TaskStatus.newTask : 'ALL';
                    });
                    _loadTasks();
                  },
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: const Text('Review'),
                  selected: _selectedStatus == TaskStatus.documentReview,
                  onSelected: (val) {
                    setState(() {
                      _selectedStatus = val ? TaskStatus.documentReview : 'ALL';
                    });
                    _loadTasks();
                  },
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: const Text('Completed'),
                  selected: _selectedStatus == TaskStatus.complete,
                  onSelected: (val) {
                    setState(() {
                      _selectedStatus = val ? TaskStatus.complete : 'ALL';
                    });
                    _loadTasks();
                  },
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Task List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _tasks.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.assignment_outlined,
                                size: 54, color: Colors.grey.shade400),
                            const SizedBox(height: 12),
                            Text(
                              'No document tasks found',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey.shade700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Share a PDF from WhatsApp to create one instantly!',
                              style: TextStyle(
                                  fontSize: 12, color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(12),
                        itemCount: _tasks.length,
                        separatorBuilder: (context, index) => const SizedBox(height: 8),
                        itemBuilder: (ctx, idx) {
                          final t = _tasks[idx];
                          return Card(
                            elevation: 1,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: () async {
                                final customer =
                                    await MobileRecordService.getRecordById(
                                        t.customerId);
                                if (customer != null && context.mounted) {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => TaskDetailScreen(
                                        task: t,
                                        customer: customer,
                                      ),
                                    ),
                                  ).then((_) => _loadTasks());
                                }
                              },
                              child: Padding(
                                padding: const EdgeInsets.all(12.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: t.statusColor.withValues(alpha: 0.15),
                                            borderRadius:
                                                BorderRadius.circular(6),
                                            border: Border.all(
                                                color: t.statusColor, width: 1),
                                          ),
                                          child: Text(
                                            t.status.toUpperCase(),
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                              color: t.statusColor,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        if (t.isWhatsAppShare)
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF25D366),
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                            ),
                                            child: const Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(Icons.share,
                                                    size: 10,
                                                    color: Colors.white),
                                                SizedBox(width: 3),
                                                Text(
                                                  'WhatsApp',
                                                  style: TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 9,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        const Spacer(),
                                        Text(
                                          dateFormat.format(t.createdAt),
                                          style: TextStyle(
                                              fontSize: 11,
                                              color: Colors.grey.shade600),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      t.title,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        const Icon(Icons.person,
                                            size: 14, color: Colors.grey),
                                        const SizedBox(width: 4),
                                        Text(
                                          '${t.customerName} (${t.consumerNo})',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey.shade800,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        const Icon(Icons.description_outlined,
                                            size: 14, color: Colors.grey),
                                        const SizedBox(width: 4),
                                        Expanded(
                                          child: Text(
                                            '${t.documentType} • ${t.documentName}',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: Colors.grey.shade700,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        if (t.isPendingSync)
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 6, vertical: 1),
                                            decoration: BoxDecoration(
                                              color: Colors.amber.shade100,
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              'Pending Sync',
                                              style: TextStyle(
                                                fontSize: 10,
                                                color: Colors.amber.shade900,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ],
                                ),
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
}
