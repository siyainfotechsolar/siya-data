import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/office_task.dart';
import '../services/office_task_service.dart';
import '../services/supabase_service.dart';
import '../widgets/create_office_task_bottom_sheet.dart';
import 'task_details_screen.dart';

class MyTasksScreen extends StatefulWidget {
  final bool showOnlyMine;

  const MyTasksScreen({
    super.key,
    this.showOnlyMine = true,
  });

  @override
  State<MyTasksScreen> createState() => _MyTasksScreenState();
}

class _MyTasksScreenState extends State<MyTasksScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();

  bool _isLoading = true;
  List<OfficeTask> _allTasks = [];
  bool _filterOnlyMine = true;
  String? _currentStaffName;

  @override
  void initState() {
    super.initState();
    _filterOnlyMine = widget.showOnlyMine;
    // Strictly 2 tabs: [ PENDING ] and [ COMPLETED ]
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {});
      }
    });
    _loadCurrentUserAndTasks();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentUserAndTasks() async {
    final user = SupabaseService.currentUser;
    if (user != null) {
      try {
        final profile = await SupabaseService.client
            .from('profiles')
            .select('full_name')
            .eq('id', user.id)
            .maybeSingle();
        final name = profile?['full_name'] as String?;
        _currentStaffName = (name != null && name.trim().isNotEmpty)
            ? name.trim()
            : (user.email?.split('@').first ?? 'Staff');
      } catch (_) {
        _currentStaffName = user.email?.split('@').first ?? 'Staff';
      }
    }
    await _loadTasks();
  }

  Future<void> _loadTasks() async {
    setState(() => _isLoading = true);
    try {
      List<OfficeTask> list;
      if (_filterOnlyMine) {
        list = await MobileOfficeTaskService.fetchMyTasks();
      } else {
        list = await MobileOfficeTaskService.fetchTasks();
      }

      if (mounted) {
        setState(() {
          _allTasks = list;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // Filter tasks by search query
  List<OfficeTask> _applySearch(List<OfficeTask> tasks) {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return tasks;

    return tasks.where((t) {
      return t.title.toLowerCase().contains(query) ||
          t.customerName.toLowerCase().contains(query) ||
          t.consumerNo.toLowerCase().contains(query) ||
          (t.village?.toLowerCase().contains(query) ?? false) ||
          t.assignedToName.toLowerCase().contains(query);
    }).toList();
  }

  // 1. Pending tasks (active tasks: Pending, In Progress, Hold)
  List<OfficeTask> get _pendingTasks {
    return _applySearch(_allTasks.where((t) => !t.isCompleted).toList());
  }

  // 2. Completed tasks
  List<OfficeTask> get _completedTasks {
    return _applySearch(_allTasks.where((t) => t.isCompleted).toList());
  }

  // Navigate to dedicated Task Details Screen
  Future<void> _openTaskDetails(OfficeTask task) async {
    final updated = await Navigator.push<OfficeTask>(
      context,
      MaterialPageRoute(
        builder: (_) => TaskDetailsScreen(
          task: task,
          currentStaffName: _currentStaffName,
        ),
      ),
    );

    if (updated != null && mounted) {
      setState(() {
        final index = _allTasks.indexWhere((t) => t.id == updated.id);
        if (index >= 0) {
          _allTasks[index] = updated;
        } else {
          _allTasks.insert(0, updated);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pendingList = _pendingTasks;
    final completedList = _completedTasks;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'My Tasks',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _loadTasks,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(102),
          child: Column(
            children: [
              // Search & Staff Filter Row
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                child: Row(
                  children: [
                    // Search bar
                    Expanded(
                      child: Container(
                        height: 38,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: TextField(
                          controller: _searchController,
                          style: const TextStyle(fontSize: 13),
                          decoration: InputDecoration(
                            hintText: 'Search customer, task, village...',
                            hintStyle: TextStyle(
                                fontSize: 12, color: Colors.grey.shade500),
                            prefixIcon: const Icon(Icons.search, size: 18),
                            suffixIcon: _searchController.text.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear, size: 16),
                                    onPressed: () {
                                      _searchController.clear();
                                      setState(() {});
                                    },
                                  )
                                : null,
                            border: InputBorder.none,
                            contentPadding:
                                const EdgeInsets.symmetric(vertical: 9),
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // "My Tasks" toggle filter
                    FilterChip(
                      selected: _filterOnlyMine,
                      label: Text(
                        _filterOnlyMine ? 'My Tasks' : 'All Staff',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: _filterOnlyMine
                              ? const Color(0xFF1E40AF)
                              : Colors.grey.shade700,
                        ),
                      ),
                      avatar: Icon(
                        _filterOnlyMine
                            ? Icons.person
                            : Icons.group_outlined,
                        size: 14,
                        color: _filterOnlyMine
                            ? const Color(0xFF1E40AF)
                            : Colors.grey.shade700,
                      ),
                      backgroundColor: Colors.white,
                      selectedColor: const Color(0xFFDBEAFE),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: BorderSide(
                          color: _filterOnlyMine
                              ? const Color(0xFF3B82F6)
                              : Colors.grey.shade300,
                        ),
                      ),
                      onSelected: (val) {
                        setState(() => _filterOnlyMine = val);
                        _loadTasks();
                      },
                    ),
                  ],
                ),
              ),

              // Strictly Two Tabs: [ PENDING ] and [ COMPLETED ]
              TabBar(
                controller: _tabController,
                labelColor: theme.colorScheme.primary,
                unselectedLabelColor: Colors.grey.shade600,
                indicatorWeight: 3,
                indicatorSize: TabBarIndicatorSize.tab,
                tabs: [
                  Tab(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          'PENDING',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        if (pendingList.isNotEmpty) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFDC2626),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '${pendingList.length}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Tab(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          'COMPLETED',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        if (completedList.isNotEmpty) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF059669),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '${completedList.length}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),

      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                // 1. Pending Tab View
                _buildPendingList(pendingList),

                // 2. Completed Tab View
                _buildCompletedList(completedList),
              ],
            ),

      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF059669),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text(
          'New Task',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        onPressed: () async {
          final messenger = ScaffoldMessenger.of(context);
          final created = await CreateOfficeTaskBottomSheet.show(context);
          if (!mounted) return;
          if (created != null) {
            messenger.showSnackBar(
              SnackBar(
                content: Text('Task assigned to ${created.assignedToName}!'),
                backgroundColor: const Color(0xFF059669),
              ),
            );
            _loadTasks();
          }
        },
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Pending Tasks List
  // ---------------------------------------------------------------------------
  Widget _buildPendingList(List<OfficeTask> tasks) {
    if (tasks.isEmpty) {
      return RefreshIndicator(
        onRefresh: _loadTasks,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(height: MediaQuery.of(context).size.height * 0.25),
            Center(
              child: Column(
                children: [
                  Icon(Icons.task_alt_rounded,
                      size: 56, color: Colors.grey.shade400),
                  const SizedBox(height: 12),
                  Text(
                    'No pending tasks!',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey.shade700,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'All active tasks have been completed.',
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadTasks,
      child: ListView.separated(
        padding: const EdgeInsets.only(
            left: 14, right: 14, top: 14, bottom: 84),
        itemCount: tasks.length,
        separatorBuilder: (context, index) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final task = tasks[index];
          return _buildPendingTaskCard(task);
        },
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Pending Task Card
  // ---------------------------------------------------------------------------
  Widget _buildPendingTaskCard(OfficeTask task) {
    // Priority color
    Color priorityColor = Colors.grey;
    if (task.priority == OfficeTaskPriority.urgent) {
      priorityColor = const Color(0xFFDC2626);
    } else if (task.priority == OfficeTaskPriority.high) {
      priorityColor = const Color(0xFFEA580C);
    } else if (task.priority == OfficeTaskPriority.normal) {
      priorityColor = const Color(0xFF2563EB);
    }

    // Status styling
    Color statusBg = const Color(0xFFFEF3C7);
    Color statusFg = const Color(0xFF92400E);
    if (task.status == OfficeTaskStatus.inProgress) {
      statusBg = const Color(0xFFDBEAFE);
      statusFg = const Color(0xFF1E40AF);
    } else if (task.status == OfficeTaskStatus.hold) {
      statusBg = const Color(0xFFF3E8FF);
      statusFg = const Color(0xFF6B21A8);
    }

    String dueDateText = 'Due: None';
    if (task.dueDate != null) {
      if (task.isDueToday) {
        dueDateText = 'Due: Today';
      } else {
        dueDateText = 'Due: ${DateFormat("dd MMM").format(task.dueDate!)}';
      }
    }

    return Card(
      elevation: 1.5,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: task.isOverdue ? Colors.red.shade300 : Colors.grey.shade200,
          width: task.isOverdue ? 1.5 : 1.0,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _openTaskDetails(task),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Customer Name + Arrow
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      task.customerName,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E3A8A),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: Colors.grey, size: 20),
                ],
              ),
              const SizedBox(height: 4),

              // Task Title
              Text(
                task.title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1F2937),
                ),
              ),
              const SizedBox(height: 10),

              const Divider(height: 1),
              const SizedBox(height: 10),

              // Due Date, Priority, Status Row
              Row(
                children: [
                  // Due Date
                  Expanded(
                    child: Row(
                      children: [
                        Icon(
                          Icons.event_outlined,
                          size: 14,
                          color: task.isOverdue ? Colors.red : Colors.grey.shade600,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          dueDateText,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: task.isOverdue
                                ? Colors.red
                                : Colors.grey.shade800,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Priority
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                    decoration: BoxDecoration(
                      color: priorityColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'Priority: ${task.priority}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: priorityColor,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Status
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                    decoration: BoxDecoration(
                      color: statusBg,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      task.status,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: statusFg,
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
  }

  // ---------------------------------------------------------------------------
  // Completed Tasks List
  // ---------------------------------------------------------------------------
  Widget _buildCompletedList(List<OfficeTask> tasks) {
    if (tasks.isEmpty) {
      return RefreshIndicator(
        onRefresh: _loadTasks,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(height: MediaQuery.of(context).size.height * 0.25),
            Center(
              child: Column(
                children: [
                  Icon(Icons.assignment_turned_in_outlined,
                      size: 56, color: Colors.grey.shade400),
                  const SizedBox(height: 12),
                  Text(
                    'No completed tasks yet.',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey.shade700,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Tasks you mark complete will appear here.',
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadTasks,
      child: ListView.separated(
        padding: const EdgeInsets.only(
            left: 14, right: 14, top: 14, bottom: 84),
        itemCount: tasks.length,
        separatorBuilder: (context, index) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final task = tasks[index];
          return _buildCompletedTaskCard(task);
        },
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Completed Task Card
  // ---------------------------------------------------------------------------
  Widget _buildCompletedTaskCard(OfficeTask task) {
    final completedDateStr = task.completedAt != null
        ? DateFormat("dd MMM, hh:mm a").format(task.completedAt!)
        : 'Completed';

    return Card(
      elevation: 1.5,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _openTaskDetails(task),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Customer Name + Completed indicator
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      task.customerName,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF065F46),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const Row(
                    children: [
                      Icon(Icons.check_circle_rounded,
                          color: Color(0xFF059669), size: 16),
                      SizedBox(width: 4),
                      Icon(Icons.chevron_right, color: Colors.grey, size: 20),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 4),

              // Task Title
              Text(
                task.title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1F2937),
                ),
              ),
              const SizedBox(height: 10),

              const Divider(height: 1),
              const SizedBox(height: 10),

              // Completed Date & Completed By Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Completed Date
                  Row(
                    children: [
                      const Icon(Icons.event_available_outlined,
                          size: 14, color: Color(0xFF059669)),
                      const SizedBox(width: 4),
                      Text(
                        'Completed: $completedDateStr',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF374151),
                        ),
                      ),
                    ],
                  ),

                  // Completed By
                  Row(
                    children: [
                      const Icon(Icons.person_outline,
                          size: 14, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text(
                        'By: ${task.effectiveCompletedByName}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E40AF),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
