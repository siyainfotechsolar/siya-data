import 'package:flutter/material.dart';

/// Result object for Mark Hold action
class HoldDialogResult {
  final String reason;
  final String? remarks;
  final DateTime? expectedFollowupDate;

  const HoldDialogResult({
    required this.reason,
    this.remarks,
    this.expectedFollowupDate,
  });
}

/// Dialog for [⏸ Mark Hold] Quick Action
class HoldReasonDialog extends StatefulWidget {
  final String customerName;

  const HoldReasonDialog({super.key, required this.customerName});

  static Future<HoldDialogResult?> show(
    BuildContext context, {
    required String customerName,
  }) {
    return showDialog<HoldDialogResult>(
      context: context,
      barrierDismissible: false,
      builder: (_) => HoldReasonDialog(customerName: customerName),
    );
  }

  @override
  State<HoldReasonDialog> createState() => _HoldReasonDialogState();
}

class _HoldReasonDialogState extends State<HoldReasonDialog> {
  static const List<String> predefinedReasons = [
    'Waiting for Customer',
    'Waiting for Bank',
    'Waiting for Document',
    'Customer Requested Hold',
    'Other',
  ];

  String _selectedReason = predefinedReasons.first;
  final TextEditingController _otherReasonController = TextEditingController();
  final TextEditingController _remarksController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  DateTime? _expectedFollowupDate;

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
      HoldDialogResult(
        reason: effectiveReason,
        remarks: _remarksController.text.trim().isNotEmpty
            ? _remarksController.text.trim()
            : null,
        expectedFollowupDate: _expectedFollowupDate,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isOther = _selectedReason == 'Other';

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
      contentPadding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
              color: Color(0xFFFEF3C7),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.pause_circle_filled_rounded,
              color: Color(0xFFD97706),
              size: 24,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Mark Customer on Hold',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                Text(
                  widget.customerName,
                  style: TextStyle(
                    fontSize: 12,
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
        width: double.maxFinite,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 10),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFBEB),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFFDE68A)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline, size: 16, color: Color(0xFFD97706)),
                      SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Removed from active queues. Can be reopened anytime.',
                          style: TextStyle(fontSize: 11, color: Color(0xFF92400E)),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),

                // Mandatory Hold Reason
                const Text(
                  'Hold Reason *',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                ),
                const SizedBox(height: 4),
                DropdownButtonFormField<String>(
                  value: _selectedReason,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  ),
                  items: predefinedReasons.map((reason) {
                    return DropdownMenuItem<String>(
                      value: reason,
                      child: Text(reason, style: const TextStyle(fontSize: 12)),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() => _selectedReason = val);
                    }
                  },
                ),
                if (isOther) ...[
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _otherReasonController,
                    decoration: const InputDecoration(
                      labelText: 'Specify Reason *',
                      hintText: 'Enter specific reason...',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    ),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) {
                        return 'Please provide a hold reason';
                      }
                      return null;
                    },
                  ),
                ],
                const SizedBox(height: 12),

                // Optional Hold Remarks
                const Text(
                  'Hold Remarks (Optional)',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                ),
                const SizedBox(height: 4),
                TextFormField(
                  controller: _remarksController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    hintText: 'Notes regarding the hold...',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.all(10),
                  ),
                ),
                const SizedBox(height: 12),

                // Optional Expected Follow-up Date
                const Text(
                  'Expected Follow-up Date (Optional)',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                ),
                const SizedBox(height: 4),
                InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _expectedFollowupDate ?? DateTime.now().add(const Duration(days: 3)),
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (picked != null) {
                      setState(() => _expectedFollowupDate = picked);
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade400),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.calendar_month, size: 16, color: Color(0xFFD97706)),
                            const SizedBox(width: 6),
                            Text(
                              _expectedFollowupDate != null
                                  ? _expectedFollowupDate!.toLocal().toString().split(' ')[0]
                                  : 'Select date...',
                              style: TextStyle(
                                fontSize: 12,
                                color: _expectedFollowupDate != null ? Colors.black87 : Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                        if (_expectedFollowupDate != null)
                          GestureDetector(
                            onTap: () => setState(() => _expectedFollowupDate = null),
                            child: const Icon(Icons.clear, size: 14, color: Colors.grey),
                          ),
                      ],
                    ),
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
            backgroundColor: const Color(0xFFD97706),
          ),
          onPressed: _submit,
          icon: const Icon(Icons.pause_circle_outline, size: 16),
          label: const Text('Mark Hold'),
        ),
      ],
    );
  }
}
