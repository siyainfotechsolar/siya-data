import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/office_task.dart';
import '../models/consumer_record.dart';
import '../services/office_task_service.dart';
import '../services/record_service.dart';
import '../services/supabase_service.dart';
import '../widgets/create_office_task_bottom_sheet.dart';
import 'record_detail_screen.dart';

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
  String _selectedTypeFilter = 'ALL';
  String? _currentStaffName;

  @override
  void initState() {
    super.initState();
    _filterOnlyMine = widget.showOnlyMine;
    _tabController = TabController(length: 4, vsync: this);
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

  List<OfficeTask> _filterTasks(List<OfficeTask> tasks) {
    var result = tasks;

    // Type filter
    if (_selectedTypeFilter != 'ALL') {
      result =
          result.where((t) => t.taskType == _selectedTypeFilter).toList();
    }

    // Search query
    final query = _searchController.text.trim().toLowerCase();
    if (query.isNotEmpty) {
      result = result.where((t) {
        return t.title.toLowerCase().contains(query) ||
            t.customerName.toLowerCase().contains(query) ||
            t.consumerNo.toLowerCase().contains(query) ||
            (t.village?.toLowerCase().contains(query) ?? false) ||
            t.assignedToName.toLowerCase().contains(query);
      }).toList();
    }

    return result;
  }

  // 4 Categories for tabs
  List<OfficeTask> get _todayTasks {
    final now = DateTime.now();
    return _filterTasks(_allTasks.where((t) {
      if (t.isCompleted) return false;
      if (t.dueDate == null) return false;
      return t.dueDate!.year == now.year &&
          t.dueDate!.month == now.month &&
          t.dueDate!.day == now.day;
    }).toList());
  }

  List<OfficeTask> get _pendingTasks {
    return _filterTasks(_allTasks.where((t) {
      return t.status == OfficeTaskStatus.pending ||
          t.status == OfficeTaskStatus.inProgress ||
          t.status == OfficeTaskStatus.hold;
    }).toList());
  }

  List<OfficeTask> get _overdueTasks {
    return _filterTasks(_allTasks.where((t) => t.isOverdue).toList());
  }

  List<OfficeTask> get _completedTasks {
    return _filterTasks(_allTasks.where((t) => t.isCompleted).toList());
  }

  // Action Handlers
  Future<void> _handleStartTask(OfficeTask task) async {
    try {
      final updated = await MobileOfficeTaskService.updateTaskStatus(
        task: task,
        newStatus: OfficeTaskStatus.inProgress,
        staffName: _currentStaffName ?? task.assignedToName,
        remarks: 'Started work on task',
      );
      _updateTaskInState(updated);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Task started! Status changed to In Progress.'),
            backgroundColor: Color(0xFF2563EB),
          ),
        );
      }
    } catch (e) {
      _showError('Failed to start task: $e');
    }
  }

  Future<void> _handleHoldTask(OfficeTask task) async {
    final reasonCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.pause_circle_outline, color: Color(0xFFD97706)),
            SizedBox(width: 8),
            Text('Put Task On Hold'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Put task "${task.title}" on Hold?'),
            const SizedBox(height: 12),
            TextField(
              controller: reasonCtrl,
              decoration: const InputDecoration(
                labelText: 'Hold Reason *',
                hintText: 'e.g. Customer not reachable, requested call tomorrow',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              maxLines: 2,
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFD97706),
            ),
            onPressed: () {
              if (reasonCtrl.text.trim().isEmpty) return;
              Navigator.pop(ctx, true);
            },
            child: const Text('Put On Hold'),
          ),
        ],
      ),
    );

    if (confirmed == true && reasonCtrl.text.trim().isNotEmpty) {
      try {
        final updated = await MobileOfficeTaskService.updateTaskStatus(
          task: task,
          newStatus: OfficeTaskStatus.hold,
          holdReason: reasonCtrl.text.trim(),
          staffName: _currentStaffName ?? task.assignedToName,
          remarks: 'Task put on hold: ${reasonCtrl.text.trim()}',
        );
        _updateTaskInState(updated);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Task put on Hold.'),
              backgroundColor: Color(0xFFD97706),
            ),
          );
        }
      } catch (e) {
        _showError('Failed to update task: $e');
      }
    }
  }

  Future<void> _handleCompleteTask(OfficeTask task) async {
    final noteCtrl = TextEditingController();
    File? attachedFile;
    final picker = ImagePicker();

    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          final media = MediaQuery.of(ctx);
          return Container(
            padding: EdgeInsets.only(
              bottom: media.viewInsets.bottom,
            ),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: SafeArea(
              top: false,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.check_circle_outline,
                                color: Color(0xFF059669), size: 24),
                            SizedBox(width: 8),
                            Text(
                              'Complete Task',
                              style: TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(ctx, false),
                        ),
                      ],
                    ),
                    const Divider(),
                    const SizedBox(height: 8),
                    Text(
                      'Customer: ${task.customerName}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'Task: ${task.title}',
                      style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                    ),
                    const SizedBox(height: 16),

                    // Completion Note
                    const Text(
                      'COMPLETION NOTE (पूर्तता नोंद) *',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: noteCtrl,
                      decoration: const InputDecoration(
                        hintText:
                            'e.g. Spoke to customer, verified meter copy, customer agreed to loan process.',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 14),

                    // Optional Document / Photo
                    const Text(
                      'OPTIONAL DOCUMENT / PHOTO',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 6),
                    if (attachedFile != null)
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0FDF4),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFF86EFAC)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.attach_file_rounded,
                                color: Color(0xFF059669)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                attachedFile!.path.split(Platform.pathSeparator).last,
                                style: const TextStyle(
                                    fontSize: 12, fontWeight: FontWeight.bold),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close,
                                  size: 18, color: Colors.red),
                              onPressed: () =>
                                  setModalState(() => attachedFile = null),
                            ),
                          ],
                        ),
                      )
                    else
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              icon: const Icon(Icons.camera_alt_outlined, size: 16),
                              label: const Text('Camera', style: TextStyle(fontSize: 12)),
                              onPressed: () async {
                                final photo = await picker.pickImage(
                                    source: ImageSource.camera,
                                    imageQuality: 80);
                                if (photo != null) {
                                  setModalState(
                                      () => attachedFile = File(photo.path));
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              icon: const Icon(Icons.photo_library_outlined,
                                  size: 16),
                              label: const Text('Gallery', style: TextStyle(fontSize: 12)),
                              onPressed: () async {
                                final img = await picker.pickImage(
                                    source: ImageSource.gallery,
                                    imageQuality: 80);
                                if (img != null) {
                                  setModalState(
                                      () => attachedFile = File(img.path));
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              icon: const Icon(Icons.picture_as_pdf_outlined,
                                  size: 16),
                              label: const Text('PDF / Doc', style: TextStyle(fontSize: 12)),
                              onPressed: () async {
                                final res = await FilePicker.platform.pickFiles(
                                  type: FileType.custom,
                                  allowedExtensions: ['pdf', 'doc', 'docx', 'jpg', 'png'],
                                );
                                if (res != null && res.files.single.path != null) {
                                  setModalState(
                                      () => attachedFile = File(res.files.single.path!));
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                    const SizedBox(height: 20),

                    // Submit
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF059669),
                        ),
                        icon: const Icon(Icons.check_circle_rounded),
                        label: const Text(
                          'MARK AS COMPLETED',
                          style: TextStyle(
                              fontSize: 14, fontWeight: FontWeight.bold),
                        ),
                        onPressed: () {
                          if (noteCtrl.text.trim().isEmpty) {
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              const SnackBar(
                                content: Text('Please enter a completion note.'),
                                backgroundColor: Colors.orange,
                              ),
                            );
                            return;
                          }
                          Navigator.pop(ctx, true);
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );

    if (confirmed == true && noteCtrl.text.trim().isNotEmpty) {
      try {
        String? attachmentUrl;
        if (attachedFile != null && SupabaseService.client.auth.currentSession != null) {
          try {
            final fileName =
                'office_task_${task.id}_${DateTime.now().millisecondsSinceEpoch}.jpg';
            final path = 'office_tasks/$fileName';
            await SupabaseService.client.storage
                .from('customer-documents')
                .upload(path, attachedFile!);
            attachmentUrl = SupabaseService.client.storage
                .from('customer-documents')
                .getPublicUrl(path);
          } catch (_) {}
        }

        final updated = await MobileOfficeTaskService.updateTaskStatus(
          task: task,
          newStatus: OfficeTaskStatus.completed,
          completionNote: noteCtrl.text.trim(),
          attachmentUrl: attachmentUrl,
          staffName: _currentStaffName ?? task.assignedToName,
          remarks: 'Completed: ${noteCtrl.text.trim()}',
        );
        _updateTaskInState(updated);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Task successfully marked as Completed!'),
              backgroundColor: Color(0xFF059669),
            ),
          );
        }
      } catch (e) {
        _showError('Failed to complete task: $e');
      }
    }
  }

  Future<void> _handleAddNote(OfficeTask task) async {
    final noteCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.edit_note_rounded, color: Color(0xFF2563EB)),
            SizedBox(width: 8),
            Text('Add Note / Remark'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Customer: ${task.customerName}'),
            Text('Task: ${task.title}',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
            const SizedBox(height: 12),
            TextField(
              controller: noteCtrl,
              decoration: const InputDecoration(
                labelText: 'Note / Remark *',
                hintText: 'e.g. Customer requested call after 4 PM',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              maxLines: 3,
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF2563EB),
            ),
            onPressed: () {
              if (noteCtrl.text.trim().isEmpty) return;
              Navigator.pop(ctx, true);
            },
            child: const Text('Save Note'),
          ),
        ],
      ),
    );

    if (confirmed == true && noteCtrl.text.trim().isNotEmpty) {
      try {
        final existing = task.description ?? '';
        final appended = existing.isEmpty
            ? noteCtrl.text.trim()
            : '$existing\n[${DateFormat("dd MMM, hh:mm a").format(DateTime.now())}]: ${noteCtrl.text.trim()}';

        final updated = await MobileOfficeTaskService.updateTaskStatus(
          task: task.copyWith(description: appended),
          newStatus: task.status,
          remarks: 'Note added: ${noteCtrl.text.trim()}',
          staffName: _currentStaffName ?? task.assignedToName,
        );
        _updateTaskInState(updated);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Note added to task!'),
              backgroundColor: Color(0xFF2563EB),
            ),
          );
        }
      } catch (e) {
        _showError('Failed to add note: $e');
      }
    }
  }

  Future<void> _openCustomerProfile(OfficeTask task) async {
    if (task.customerId == null || task.customerId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No linked customer ID found for this task.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Try fetching customer record
    final customer = await MobileRecordService.getRecordById(task.customerId!);
    if (customer != null && mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => RecordDetailScreen(record: customer),
        ),
      );
    } else if (mounted) {
      // Create minimal ConsumerRecord placeholder for profile viewer
      final placeholder = ConsumerRecord(
        id: task.customerId,
        name: task.customerName,
        consumerNo: task.consumerNo,
        address: task.village,
        status: 'Active',
      );
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => RecordDetailScreen(record: placeholder),
        ),
      );
    }
  }

  void _updateTaskInState(OfficeTask updated) {
    setState(() {
      final index = _allTasks.indexWhere((t) => t.id == updated.id);
      if (index >= 0) {
        _allTasks[index] = updated;
      }
    });
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final todayList = _todayTasks;
    final pendingList = _pendingTasks;
    final overdueList = _overdueTasks;
    final completedList = _completedTasks;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Office Tasks (कार्यालयीन कामे)',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_task_rounded),
            tooltip: 'Assign New Task',
            onPressed: () async {
              final created =
                  await CreateOfficeTaskBottomSheet.show(context);
              if (created != null && mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content:
                        Text('Task assigned to ${created.assignedToName}!'),
                    backgroundColor: const Color(0xFF059669),
                  ),
                );
                _loadTasks();
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _loadTasks,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(108),
          child: Column(
            children: [
              // Search & Mine Toggle Row
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
                            hintText: 'Search customer, village, task...',
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

                    // "Only Mine" filter chip
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
                      onSelected: (val) {
                        setState(() => _filterOnlyMine = val);
                        _loadTasks();
                      },
                    ),
                  ],
                ),
              ),

              // 4 Tabs
              TabBar(
                controller: _tabController,
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                labelColor: theme.colorScheme.primary,
                unselectedLabelColor: Colors.grey.shade600,
                indicatorWeight: 3,
                tabs: [
                  Tab(text: "Today's (${todayList.length})"),
                  Tab(text: 'Pending (${pendingList.length})'),
                  Tab(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('Overdue (${overdueList.length})'),
                        if (overdueList.isNotEmpty) ...[
                          const SizedBox(width: 4),
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Tab(text: 'Completed (${completedList.length})'),
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
                _buildTaskList(todayList, "No tasks due today!"),
                _buildTaskList(pendingList, "No pending tasks."),
                _buildTaskList(overdueList, "No overdue tasks! Good job."),
                _buildTaskList(completedList, "No completed tasks yet."),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF059669),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('New Task',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        onPressed: () async {
          final created = await CreateOfficeTaskBottomSheet.show(context);
          if (created != null && mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content:
                    Text('Task assigned to ${created.assignedToName}!'),
                backgroundColor: const Color(0xFF059669),
              ),
            );
            _loadTasks();
          }
        },
      ),
    );
  }

  Widget _buildTaskList(List<OfficeTask> tasks, String emptyMessage) {
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
                    emptyMessage,
                    style: TextStyle(
                        fontSize: 15,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w500),
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
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final task = tasks[index];
          return _buildTaskCard(task);
        },
      ),
    );
  }

  Widget _buildTaskCard(OfficeTask task) {
    // Priority color
    Color priorityColor = Colors.grey;
    if (task.priority == OfficeTaskPriority.urgent) {
      priorityColor = const Color(0xFFDC2626);
    } else if (task.priority == OfficeTaskPriority.high) {
      priorityColor = const Color(0xFFD97706);
    } else if (task.priority == OfficeTaskPriority.normal) {
      priorityColor = const Color(0xFF2563EB);
    }

    // Status styling
    Color statusBg = const Color(0xFFFEF3C7);
    Color statusFg = const Color(0xFF92400E);
    if (task.status == OfficeTaskStatus.inProgress) {
      statusBg = const Color(0xFFDBEAFE);
      statusFg = const Color(0xFF1E40AF);
    } else if (task.status == OfficeTaskStatus.completed) {
      statusBg = const Color(0xFFD1FAE5);
      statusFg = const Color(0xFF065F46);
    } else if (task.status == OfficeTaskStatus.hold) {
      statusBg = const Color(0xFFF3E8FF);
      statusFg = const Color(0xFF6B21A8);
    }

    return Card(
      elevation: 1.5,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: task.isOverdue
              ? Colors.red.shade300
              : Colors.grey.shade200,
          width: task.isOverdue ? 1.5 : 1.0,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Priority & Status Badges
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: priorityColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.flag_rounded,
                              size: 13, color: priorityColor),
                          const SizedBox(width: 4),
                          Text(
                            task.priority.toUpperCase(),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: priorityColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        task.taskType,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF334155),
                        ),
                      ),
                    ),
                  ],
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: statusBg,
                    borderRadius: BorderRadius.circular(12),
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
            const SizedBox(height: 10),

            // Task Title
            Text(
              task.title,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (task.description != null &&
                task.description!.trim().isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                task.description!.trim(),
                style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 10),

            // Customer Details Row
            InkWell(
              onTap: () => _openCustomerProfile(task),
              child: Row(
                children: [
                  const Icon(Icons.person_pin_rounded,
                      size: 20, color: Color(0xFF2563EB)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                task.customerName,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1E40AF),
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Icon(Icons.open_in_new_rounded,
                                size: 13, color: Color(0xFF2563EB)),
                          ],
                        ),
                        Text(
                          '${task.consumerNo} • ${task.village ?? "No Village"}',
                          style: TextStyle(
                              fontSize: 11, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),

            // Meta Row: Assigned Staff & Due Date
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.badge_outlined,
                        size: 14, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text(
                      'Staff: ${task.assignedToName}',
                      style: const TextStyle(
                          fontSize: 11, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Icon(
                      Icons.event_outlined,
                      size: 14,
                      color: task.isOverdue
                          ? Colors.red
                          : Colors.grey.shade700,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      task.dueDate != null
                          ? 'Due: ${DateFormat("dd MMM").format(task.dueDate!)}'
                          : 'No Due Date',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: task.isOverdue
                            ? Colors.red
                            : Colors.grey.shade800,
                      ),
                    ),
                  ],
                ),
              ],
            ),

            // Hold reason / completion note banners if any
            if (task.status == OfficeTaskStatus.hold &&
                task.holdReason != null) ...[
              const SizedBox(height: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline,
                        size: 14, color: Color(0xFF92400E)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Hold Reason: ${task.holdReason}',
                        style: const TextStyle(
                            fontSize: 11, color: Color(0xFF92400E)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (task.isCompleted && task.completionNote != null) ...[
              const SizedBox(height: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle_outline,
                        size: 14, color: Color(0xFF065F46)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Completed Note: ${task.completionNote}',
                        style: const TextStyle(
                            fontSize: 11, color: Color(0xFF065F46)),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Attached File banner
            if (task.attachmentUrl != null && task.attachmentUrl!.isNotEmpty) ...[
              const SizedBox(height: 8),
              InkWell(
                onTap: () async {
                  final uri = Uri.parse(task.attachmentUrl!);
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  } else {
                    _showError('Could not open attached file');
                  }
                },
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFBFDBFE)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.attach_file_rounded, size: 18, color: Color(0xFF1D4ED8)),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Attached File / Document (दस्तऐवज पहा)',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1D4ED8),
                          ),
                        ),
                      ),
                      const Icon(Icons.open_in_new_rounded, size: 14, color: Color(0xFF1D4ED8)),
                    ],
                  ),
                ),
              ),
            ],

            const SizedBox(height: 12),

            // Action Buttons Row: [Start] [Complete] [Hold] [Add Note] [Customer Profile]
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                if (!task.isCompleted &&
                    task.status != OfficeTaskStatus.inProgress)
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    icon: const Icon(Icons.play_arrow_rounded, size: 16),
                    label:
                        const Text('Start', style: TextStyle(fontSize: 12)),
                    onPressed: () => _handleStartTask(task),
                  ),
                if (!task.isCompleted)
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF059669),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    icon: const Icon(Icons.check_rounded, size: 16),
                    label: const Text('Complete',
                        style: TextStyle(fontSize: 12)),
                    onPressed: () => _handleCompleteTask(task),
                  ),
                if (!task.isCompleted &&
                    task.status != OfficeTaskStatus.hold)
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFD97706),
                      side: const BorderSide(color: Color(0xFFD97706)),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 8),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    icon: const Icon(Icons.pause_rounded, size: 16),
                    label: const Text('Hold', style: TextStyle(fontSize: 12)),
                    onPressed: () => _handleHoldTask(task),
                  ),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF475569),
                    side: const BorderSide(color: Color(0xFF94A3B8)),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 8),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  icon: const Icon(Icons.edit_note_rounded, size: 16),
                  label: const Text('Add Note',
                      style: TextStyle(fontSize: 12)),
                  onPressed: () => _handleAddNote(task),
                ),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF2563EB),
                    side: const BorderSide(color: Color(0xFF93C5FD)),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 8),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  icon: const Icon(Icons.person_search_outlined, size: 16),
                  label: const Text('Customer Profile',
                      style: TextStyle(fontSize: 12)),
                  onPressed: () => _openCustomerProfile(task),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
