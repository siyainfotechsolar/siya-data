import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/office_task.dart';
import '../models/consumer_record.dart';
import '../services/office_task_service.dart';
import '../services/record_service.dart';
import '../services/supabase_service.dart';
import 'record_detail_screen.dart';

class TaskDetailsScreen extends StatefulWidget {
  final OfficeTask task;
  final String? currentStaffName;

  const TaskDetailsScreen({
    super.key,
    required this.task,
    this.currentStaffName,
  });

  @override
  State<TaskDetailsScreen> createState() => _TaskDetailsScreenState();
}

class _TaskDetailsScreenState extends State<TaskDetailsScreen> {
  late OfficeTask _task;
  bool _isProcessing = false;
  String? _staffName;

  @override
  void initState() {
    super.initState();
    _task = widget.task;
    _staffName = widget.currentStaffName;
    _resolveStaffName();
  }

  Future<void> _resolveStaffName() async {
    if (_staffName != null && _staffName!.trim().isNotEmpty) return;
    final user = SupabaseService.currentUser;
    if (user != null) {
      try {
        final profile = await SupabaseService.client
            .from('profiles')
            .select('full_name')
            .eq('id', user.id)
            .maybeSingle();
        final name = profile?['full_name'] as String?;
        if (mounted) {
          setState(() {
            _staffName = (name != null && name.trim().isNotEmpty)
                ? name.trim()
                : (user.email?.split('@').first ?? 'Staff');
          });
        }
      } catch (_) {
        if (mounted) {
          setState(() {
            _staffName = user.email?.split('@').first ?? 'Staff';
          });
        }
      }
    }
  }

  String get _effectiveStaffName =>
      _staffName ?? _task.assignedToName;

  // ---------------------------------------------------------------------------
  // Action: Mark Complete
  // ---------------------------------------------------------------------------
  Future<void> _handleMarkComplete() async {
    final noteController = TextEditingController();

    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, _) {
          final bottomInset = MediaQuery.of(ctx).viewInsets.bottom;
          return Container(
            padding: EdgeInsets.only(bottom: bottomInset),
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
                    // Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.check_circle_rounded,
                                color: Color(0xFF059669), size: 26),
                            SizedBox(width: 8),
                            Text(
                              'Complete Task',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                          ],
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(ctx, false),
                        ),
                      ],
                    ),
                    const Divider(height: 20),

                    Text(
                      'Customer: ${_task.customerName}',
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Task: ${_task.title}',
                      style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                    ),
                    const SizedBox(height: 16),

                    // Completion Note (Optional)
                    const Text(
                      'Completion Note (optional)',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF334155),
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: noteController,
                      decoration: InputDecoration(
                        hintText: 'e.g. Documents verified, customer payment confirmed',
                        hintStyle: TextStyle(fontSize: 13, color: Colors.grey.shade400),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        contentPadding: const EdgeInsets.all(12),
                      ),
                      maxLines: 3,
                      autofocus: true,
                    ),
                    const SizedBox(height: 20),

                    // Confirm Button
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF059669),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        icon: const Icon(Icons.check_rounded, color: Colors.white),
                        label: const Text(
                          'Confirm Complete',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        onPressed: () => Navigator.pop(ctx, true),
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

    if (confirmed == true) {
      setState(() => _isProcessing = true);
      try {
        final noteText = noteController.text.trim();
        final updated = await MobileOfficeTaskService.updateTaskStatus(
          task: _task,
          newStatus: OfficeTaskStatus.completed,
          completionNote: noteText.isNotEmpty ? noteText : null,
          staffName: _effectiveStaffName,
          remarks: noteText.isNotEmpty ? 'Completed: $noteText' : 'Task marked as completed',
        );

        if (mounted) {
          setState(() {
            _task = updated;
            _isProcessing = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Task marked as Completed! Moved to Completed tab.'),
              backgroundColor: Color(0xFF059669),
            ),
          );
          // Auto-pop and return updated task so MyTasksScreen immediately reflects the move
          Navigator.pop(context, updated);
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isProcessing = false);
          _showError('Failed to complete task: $e');
        }
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Action: Put on Hold
  // ---------------------------------------------------------------------------
  Future<void> _handleHoldTask() async {
    final reasonController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.pause_circle_outline, color: Color(0xFFD97706)),
            SizedBox(width: 8),
            Text('Hold Task'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Put task "${_task.title}" on Hold?'),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: 'Hold Reason *',
                hintText: 'e.g. Customer requested call next week',
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
              if (reasonController.text.trim().isEmpty) return;
              Navigator.pop(ctx, true);
            },
            child: const Text('Confirm Hold'),
          ),
        ],
      ),
    );

    if (confirmed == true && reasonController.text.trim().isNotEmpty) {
      setState(() => _isProcessing = true);
      try {
        final reason = reasonController.text.trim();
        final updated = await MobileOfficeTaskService.updateTaskStatus(
          task: _task,
          newStatus: OfficeTaskStatus.hold,
          holdReason: reason,
          staffName: _effectiveStaffName,
          remarks: 'Task put on hold: $reason',
        );

        if (mounted) {
          setState(() {
            _task = updated;
            _isProcessing = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Task put on Hold.'),
              backgroundColor: Color(0xFFD97706),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isProcessing = false);
          _showError('Failed to put task on hold: $e');
        }
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Action: Add Note
  // ---------------------------------------------------------------------------
  Future<void> _handleAddNote() async {
    final noteController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.note_add_outlined, color: Color(0xFF2563EB)),
            SizedBox(width: 8),
            Text('Add Note'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Customer: ${_task.customerName}'),
            const SizedBox(height: 12),
            TextField(
              controller: noteController,
              decoration: const InputDecoration(
                labelText: 'Note / Remark *',
                hintText: 'e.g. Customer wants meter inspection on Monday',
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
              if (noteController.text.trim().isEmpty) return;
              Navigator.pop(ctx, true);
            },
            child: const Text('Save Note'),
          ),
        ],
      ),
    );

    if (confirmed == true && noteController.text.trim().isNotEmpty) {
      setState(() => _isProcessing = true);
      try {
        final newNote = noteController.text.trim();
        final timeStr = DateFormat("dd MMM, hh:mm a").format(DateTime.now());
        final existing = _task.description ?? '';
        final appended = existing.isEmpty
            ? '[$timeStr - $_effectiveStaffName]: $newNote'
            : '$existing\n[$timeStr - $_effectiveStaffName]: $newNote';

        final updated = await MobileOfficeTaskService.updateTaskStatus(
          task: _task.copyWith(description: appended),
          newStatus: _task.status,
          remarks: 'Note added: $newNote',
          staffName: _effectiveStaffName,
        );

        if (mounted) {
          setState(() {
            _task = updated;
            _isProcessing = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Note added to task!'),
              backgroundColor: Color(0xFF2563EB),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isProcessing = false);
          _showError('Failed to add note: $e');
        }
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Action: View Customer Profile
  // ---------------------------------------------------------------------------
  Future<void> _viewCustomer() async {
    if (_task.customerId == null || _task.customerId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No linked customer found for this task.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      final customer = await MobileRecordService.getRecordById(_task.customerId!);
      if (customer != null && mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => RecordDetailScreen(record: customer),
          ),
        );
        return;
      }
    } catch (_) {}

    if (mounted) {
      final fallback = ConsumerRecord(
        id: _task.customerId,
        name: _task.customerName,
        consumerNo: _task.consumerNo,
        address: _task.village,
        status: 'Active',
      );
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => RecordDetailScreen(record: fallback),
        ),
      );
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  // ---------------------------------------------------------------------------
  // UI Build
  // ---------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final isCompleted = _task.isCompleted;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        Navigator.pop(context, _task);
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            'Task Details',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.pop(context, _task),
          ),
        ),
        body: _isProcessing
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header card with Title, Priority and Status
                    _buildHeaderCard(),
                    const SizedBox(height: 14),

                    // Customer Information card with [View Customer] button
                    _buildCustomerCard(),
                    const SizedBox(height: 14),

                    // Completed Banner (if completed)
                    if (isCompleted) ...[
                      _buildCompletedBanner(),
                      const SizedBox(height: 14),
                    ],

                    // Hold Reason Banner (if on hold)
                    if (_task.status == OfficeTaskStatus.hold &&
                        _task.holdReason != null &&
                        _task.holdReason!.isNotEmpty) ...[
                      _buildHoldBanner(),
                      const SizedBox(height: 14),
                    ],

                    // Task Information & Metadata
                    _buildTaskInfoCard(),
                    const SizedBox(height: 14),

                    // Description / Notes / Remarks
                    _buildNotesCard(),
                    const SizedBox(height: 14),

                    // Attachment (if any)
                    if (_task.attachmentUrl != null &&
                        _task.attachmentUrl!.isNotEmpty) ...[
                      _buildAttachmentCard(),
                      const SizedBox(height: 14),
                    ],

                    const SizedBox(height: 80),
                  ],
                ),
              ),

        // Bottom Action Bar
        bottomNavigationBar: _buildBottomActionBar(),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Header Card
  // ---------------------------------------------------------------------------
  Widget _buildHeaderCard() {
    Color priorityColor = Colors.grey;
    if (_task.priority == OfficeTaskPriority.urgent) {
      priorityColor = const Color(0xFFDC2626);
    } else if (_task.priority == OfficeTaskPriority.high) {
      priorityColor = const Color(0xFFEA580C);
    } else if (_task.priority == OfficeTaskPriority.normal) {
      priorityColor = const Color(0xFF2563EB);
    }

    Color statusBg = const Color(0xFFFEF3C7);
    Color statusFg = const Color(0xFF92400E);
    if (_task.status == OfficeTaskStatus.inProgress) {
      statusBg = const Color(0xFFDBEAFE);
      statusFg = const Color(0xFF1E40AF);
    } else if (_task.status == OfficeTaskStatus.completed) {
      statusBg = const Color(0xFFD1FAE5);
      statusFg = const Color(0xFF065F46);
    } else if (_task.status == OfficeTaskStatus.hold) {
      statusBg = const Color(0xFFF3E8FF);
      statusFg = const Color(0xFF6B21A8);
    }

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Badges row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Priority Badge
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: priorityColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.flag_rounded, size: 14, color: priorityColor),
                      const SizedBox(width: 4),
                      Text(
                        'Priority: ${_task.priority}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: priorityColor,
                        ),
                      ),
                    ],
                  ),
                ),

                // Status Badge
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusBg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _task.status,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: statusFg,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Task Title
            Text(
              _task.title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F172A),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Customer Card
  // ---------------------------------------------------------------------------
  Widget _buildCustomerCard() {
    final hasCustomerLink =
        _task.customerId != null && _task.customerId!.isNotEmpty;

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.person_rounded, size: 20, color: Color(0xFF2563EB)),
                SizedBox(width: 8),
                Text(
                  'Customer Details',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E293B),
                  ),
                ),
              ],
            ),
            const Divider(height: 20),

            _buildDetailRow('Customer Name', _task.customerName, isBold: true),
            const SizedBox(height: 8),
            _buildDetailRow('Consumer Number', _task.consumerNo),
            if (_task.village != null && _task.village!.trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              _buildDetailRow('Village / Address', _task.village!.trim()),
            ],

            if (hasCustomerLink) ...[
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF2563EB),
                    side: const BorderSide(color: Color(0xFF93C5FD)),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  icon: const Icon(Icons.open_in_new_rounded, size: 18),
                  label: const Text(
                    'View Customer',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                  onPressed: _viewCustomer,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Completed Details Banner
  // ---------------------------------------------------------------------------
  Widget _buildCompletedBanner() {
    final completedDateStr = _task.completedAt != null
        ? DateFormat('dd MMM yyyy, hh:mm a').format(_task.completedAt!)
        : 'Completed';
    final completedByStr = _task.effectiveCompletedByName;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF86EFAC)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.check_circle_rounded,
                  color: Color(0xFF059669), size: 22),
              SizedBox(width: 8),
              Text(
                'Task Completed',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF065F46),
                ),
              ),
            ],
          ),
          const Divider(color: Color(0xFFBBF7D0), height: 20),

          _buildDetailRow('Completed Date', completedDateStr),
          const SizedBox(height: 8),
          _buildDetailRow('Completed By', completedByStr),
          if (_task.completionNote != null &&
              _task.completionNote!.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            _buildDetailRow('Completion Note', _task.completionNote!.trim()),
          ],
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Hold Reason Banner
  // ---------------------------------------------------------------------------
  Widget _buildHoldBanner() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFDE68A)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, color: Color(0xFFD97706), size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Task on Hold',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF92400E),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _task.holdReason!,
                  style:
                      const TextStyle(fontSize: 13, color: Color(0xFF78350F)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Task Info Card
  // ---------------------------------------------------------------------------
  Widget _buildTaskInfoCard() {
    final createdDateStr =
        DateFormat('dd MMM yyyy, hh:mm a').format(_task.createdAt);

    String dueDateStr = 'No Due Date';
    bool isOverdue = false;
    if (_task.dueDate != null) {
      if (_task.isDueToday) {
        dueDateStr = 'Today';
      } else {
        dueDateStr = DateFormat('dd MMM yyyy').format(_task.dueDate!);
      }
      isOverdue = _task.isOverdue;
    }

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.assignment_outlined,
                    size: 20, color: Color(0xFF475569)),
                SizedBox(width: 8),
                Text(
                  'Task Information',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E293B),
                  ),
                ),
              ],
            ),
            const Divider(height: 20),

            _buildDetailRow('Task Type', _task.taskType),
            const SizedBox(height: 8),
            _buildDetailRow('Assigned Staff', _task.assignedToName),
            const SizedBox(height: 8),
            _buildDetailRow('Created Date', createdDateStr),
            const SizedBox(height: 8),
            _buildDetailRow(
              'Due Date',
              dueDateStr,
              valueColor: isOverdue ? Colors.red : null,
              isBold: isOverdue,
            ),
            const SizedBox(height: 8),
            _buildDetailRow('Priority', _task.priority),
            const SizedBox(height: 8),
            _buildDetailRow('Current Status', _task.status),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Notes / Remarks Card
  // ---------------------------------------------------------------------------
  Widget _buildNotesCard() {
    final hasDesc =
        _task.description != null && _task.description!.trim().isNotEmpty;

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.notes_rounded, size: 20, color: Color(0xFF475569)),
                SizedBox(width: 8),
                Text(
                  'Remarks / Description',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E293B),
                  ),
                ),
              ],
            ),
            const Divider(height: 20),
            Text(
              hasDesc ? _task.description!.trim() : 'No remarks or notes yet.',
              style: TextStyle(
                fontSize: 13,
                color: hasDesc ? const Color(0xFF334155) : Colors.grey.shade500,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Attachment Card
  // ---------------------------------------------------------------------------
  Widget _buildAttachmentCard() {
    final url = _task.attachmentUrl!;
    final isPdf = url.toLowerCase().contains('.pdf');
    final isImage = url.toLowerCase().contains('.jpg') ||
        url.toLowerCase().contains('.jpeg') ||
        url.toLowerCase().contains('.png') ||
        url.toLowerCase().contains('.webp');

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isPdf
                      ? Icons.picture_as_pdf_rounded
                      : (isImage ? Icons.image_rounded : Icons.attach_file_rounded),
                  size: 20,
                  color: isPdf ? Colors.red : const Color(0xFF2563EB),
                ),
                const SizedBox(width: 8),
                const Text(
                  'Attachment (जोडलेला दस्तऐवज)',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E293B),
                  ),
                ),
              ],
            ),
            const Divider(height: 20),
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: isPdf ? Colors.red.shade50 : const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    isPdf
                        ? Icons.picture_as_pdf
                        : (isImage ? Icons.image_rounded : Icons.insert_drive_file_outlined),
                    color: isPdf ? Colors.red : const Color(0xFF2563EB),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isPdf ? 'PDF Document' : (isImage ? 'Image Document' : 'Document File'),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                      Text(
                        url.split('/').last.split('?').first,
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                icon: const Icon(Icons.visibility_rounded, size: 18, color: Colors.white),
                label: const Text(
                  'View PDF/Image',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                onPressed: () async {
                  final uri = Uri.parse(_task.attachmentUrl!);
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  } else {
                    _showError('Could not open document.');
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Bottom Action Bar (Pending Task Actions vs Completed)
  // ---------------------------------------------------------------------------
  Widget _buildBottomActionBar() {
    final isCompleted = _task.isCompleted;

    if (isCompleted) {
      // Completed state: show Add Note button only
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, -3),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            width: double.infinity,
            height: 46,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF2563EB),
                side: const BorderSide(color: Color(0xFF93C5FD)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              icon: const Icon(Icons.edit_note_rounded, size: 20),
              label: const Text(
                'Add Note',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
              onPressed: _handleAddNote,
            ),
          ),
        ),
      );
    }

    // Pending state: [ Mark Complete ] [ Hold ] [ Add Note ]
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Prominent Mark Complete Button
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF059669),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                icon: const Icon(Icons.check_circle_rounded, color: Colors.white),
                label: const Text(
                  'Mark Complete',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                onPressed: _handleMarkComplete,
              ),
            ),
            const SizedBox(height: 10),

            // Secondary row: [ Hold ] and [ Add Note ]
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFD97706),
                      side: const BorderSide(color: Color(0xFFD97706)),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    icon: const Icon(Icons.pause_rounded, size: 18),
                    label: const Text(
                      'Hold',
                      style: TextStyle(
                          fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                    onPressed: _handleHoldTask,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF2563EB),
                      side: const BorderSide(color: Color(0xFF93C5FD)),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    icon: const Icon(Icons.edit_note_rounded, size: 18),
                    label: const Text(
                      'Add Note',
                      style: TextStyle(
                          fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                    onPressed: _handleAddNote,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value,
      {bool isBold = false, Color? valueColor}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 130,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
              color: valueColor ?? const Color(0xFF0F172A),
            ),
          ),
        ),
      ],
    );
  }
}
