import 'package:flutter/material.dart';

/// Result object for Mark Follow-up action
class FollowupDialogResult {
  final DateTime followupDate;
  final String followupReason;
  final String? remarks;

  const FollowupDialogResult({
    required this.followupDate,
    required this.followupReason,
    this.remarks,
  });
}

/// Dialog for [📞 Mark Follow-up] Quick Action
class FollowupDialog extends StatefulWidget {
  final String customerName;
  final DateTime? initialDate;
  final String? initialReason;

  const FollowupDialog({
    super.key,
    required this.customerName,
    this.initialDate,
    this.initialReason,
  });

  static Future<FollowupDialogResult?> show(
    BuildContext context, {
    required String customerName,
    DateTime? initialDate,
    String? initialReason,
  }) {
    return showDialog<FollowupDialogResult>(
      context: context,
      barrierDismissible: false,
      builder: (_) => FollowupDialog(
        customerName: customerName,
        initialDate: initialDate,
        initialReason: initialReason,
      ),
    );
  }

  @override
  State<FollowupDialog> createState() => _FollowupDialogState();
}

class _FollowupDialogState extends State<FollowupDialog> {
  static const List<String> predefinedReasons = [
    'Customer Call',
    'Bank Follow-up',
    'Document Follow-up',
    'Installation Follow-up',
    'Other',
  ];

  late DateTime _followupDate;
  late String _selectedReason;
  final TextEditingController _otherReasonController = TextEditingController();
  final TextEditingController _remarksController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _followupDate = widget.initialDate ?? DateTime.now();
    _selectedReason = (widget.initialReason != null && predefinedReasons.contains(widget.initialReason))
        ? widget.initialReason!
        : predefinedReasons.first;
  }

  @override
  void dispose() {
    _otherReasonController.dispose();
    _remarksController.dispose();
    super.dispose();
  }

  void _submit() {
    if (_selectedReason == 'Other') {
      if (_otherReasonController.text.trim().isEmpty) {
        _formKey.currentState?.validate();
        return;
      }
    }

    final effectiveReason = _selectedReason == 'Other'
        ? _otherReasonController.text.trim()
        : _selectedReason;

    Navigator.of(context).pop(
      FollowupDialogResult(
        followupDate: _followupDate,
        followupReason: effectiveReason,
        remarks: _remarksController.text.trim().isNotEmpty
            ? _remarksController.text.trim()
            : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isOther = _selectedReason == 'Other';

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
      contentPadding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
      actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
              color: Color(0xFFEFF6FF),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.phone_in_talk_rounded,
              color: Color(0xFF2563EB),
              size: 26,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Schedule Follow-up',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Text(
                  widget.customerName,
                  style: TextStyle(
                    fontSize: 13,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 480,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Follow-up Date Field
                const Text(
                  'Follow-up Date *',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
                const SizedBox(height: 6),
                InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _followupDate,
                      firstDate: DateTime.now().subtract(const Duration(days: 365)),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (picked != null) {
                      setState(() => _followupDate = picked);
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade400),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.calendar_today, size: 18, color: Color(0xFF2563EB)),
                            const SizedBox(width: 8),
                            Text(
                              _followupDate.toLocal().toString().split(' ')[0],
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        Text(
                          _getRelativeDateLabel(_followupDate),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: _getRelativeDateColor(_followupDate),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // Follow-up Reason Field
                const Text(
                  'Follow-up Reason *',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  value: _selectedReason,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                  items: predefinedReasons.map((reason) {
                    return DropdownMenuItem<String>(
                      value: reason,
                      child: Text(reason, style: const TextStyle(fontSize: 13)),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() => _selectedReason = val);
                    }
                  },
                ),
                if (isOther) ...[
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _otherReasonController,
                    decoration: const InputDecoration(
                      labelText: 'Specify Reason *',
                      hintText: 'Enter reason for follow-up...',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) {
                        return 'Please provide a follow-up reason';
                      }
                      return null;
                    },
                  ),
                ],
                const SizedBox(height: 14),

                // Remarks Field
                const Text(
                  'Remarks',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _remarksController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    hintText: 'What needs to be discussed or checked with the customer/bank...',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.all(12),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(null),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF2563EB),
          ),
          onPressed: _submit,
          icon: const Icon(Icons.check, size: 18),
          label: const Text('Save Follow-up'),
        ),
      ],
    );
  }

  String _getRelativeDateLabel(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(date.year, date.month, date.day);
    final diff = target.difference(today).inDays;

    if (diff == 0) return 'Today';
    if (diff == 1) return 'Tomorrow';
    if (diff < 0) return '${diff.abs()} days overdue';
    return 'in $diff days';
  }

  Color _getRelativeDateColor(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(date.year, date.month, date.day);
    final diff = target.difference(today).inDays;

    if (diff == 0) return const Color(0xFF059669); // Green
    if (diff < 0) return const Color(0xFFDC2626); // Red
    return const Color(0xFF2563EB); // Blue
  }
}
