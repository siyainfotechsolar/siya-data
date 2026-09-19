import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/office_task.dart';
import '../services/office_task_service.dart';

class OfficeStaffWorkLogDialog extends StatefulWidget {
  final String? taskId;
  final String? taskTitle;

  const OfficeStaffWorkLogDialog({
    super.key,
    this.taskId,
    this.taskTitle,
  });

  @override
  State<OfficeStaffWorkLogDialog> createState() => _OfficeStaffWorkLogDialogState();
}

class _OfficeStaffWorkLogDialogState extends State<OfficeStaffWorkLogDialog> {
  List<TaskAssignment> _assignments = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadLogs();
  }

  Future<void> _loadLogs() async {
    final logs = await OfficeTaskService.fetchWorkLog(taskId: widget.taskId);
    if (mounted) {
      setState(() {
        _assignments = logs;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd MMM yyyy, hh:mm a');

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFF3E8FF),
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFD8B4FE)),
            ),
            child: const Icon(Icons.history_edu_rounded, color: Color(0xFF7E22CE), size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Office Staff Work Log',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                Text(
                  widget.taskTitle != null
                      ? 'Audit history for: ${widget.taskTitle}'
                      : 'Who worked on which customer/task timeline',
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 650,
        height: 420,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _assignments.isEmpty
                ? const Center(
                    child: Text(
                      'No assignment logs recorded yet.',
                      style: TextStyle(color: Colors.grey),
                    ),
                  )
                : ListView.separated(
                    itemCount: _assignments.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (ctx, i) {
                      final item = _assignments[i];
                      return ListTile(
                        leading: CircleAvatar(
                          radius: 18,
                          backgroundColor: const Color(0xFF7E22CE).withValues(alpha: 0.12),
                          child: const Icon(Icons.person, color: Color(0xFF7E22CE), size: 18),
                        ),
                        title: Row(
                          children: [
                            Text(
                              item.staffName,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: item.status == 'Completed'
                                    ? const Color(0xFFECFDF5)
                                    : (item.status == 'Reassigned'
                                        ? const Color(0xFFFFFBEB)
                                        : const Color(0xFFEFF6FF)),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                  color: item.status == 'Completed'
                                      ? const Color(0xFFA7F3D0)
                                      : (item.status == 'Reassigned'
                                          ? const Color(0xFFFDE68A)
                                          : const Color(0xFFBFDBFE)),
                                ),
                              ),
                              child: Text(
                                item.status.toUpperCase(),
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: item.status == 'Completed'
                                      ? const Color(0xFF065F46)
                                      : (item.status == 'Reassigned'
                                          ? const Color(0xFF92400E)
                                          : const Color(0xFF1E40AF)),
                                ),
                              ),
                            ),
                            const Spacer(),
                            Text(
                              dateFormat.format(item.assignedAt),
                              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (item.remarks != null && item.remarks!.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                'Remarks: ${item.remarks}',
                                style: TextStyle(fontSize: 12, color: Colors.grey.shade800),
                              ),
                            ],
                            if (item.startedAt != null || item.completedAt != null) ...[
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  if (item.startedAt != null)
                                    Text(
                                      'Started: ${dateFormat.format(item.startedAt!)}  ',
                                      style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                                    ),
                                  if (item.completedAt != null)
                                    Text(
                                      'Completed: ${dateFormat.format(item.completedAt!)}',
                                      style: const TextStyle(fontSize: 10, color: Color(0xFF059669), fontWeight: FontWeight.bold),
                                    ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      );
                    },
                  ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }
}
