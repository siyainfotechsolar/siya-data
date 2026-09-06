import 'package:flutter/material.dart';

/// Result object for Follow-up Done action
class FollowupDoneResult {
  final String followupResult;
  final String? remarks;
  final DateTime? nextFollowupDate;

  const FollowupDoneResult({
    required this.followupResult,
    this.remarks,
    this.nextFollowupDate,
  });
}

/// Dialog displayed when staff clicks [Follow-up Done]
class FollowupDoneDialog extends StatefulWidget {
  final String customerName;

  const FollowupDoneDialog({super.key, required this.customerName});

  static Future<FollowupDoneResult?> show(
    BuildContext context, {
    required String customerName,
  }) {
    return showDialog<FollowupDoneResult>(
      context: context,
      barrierDismissible: false,
      builder: (_) => FollowupDoneDialog(customerName: customerName),
    );
  }

  @override
  State<FollowupDoneDialog> createState() => _FollowupDoneDialogState();
}

class _FollowupDoneDialogState extends State<FollowupDoneDialog> {
  static const List<String> predefinedResults = [
    'Call Completed - Customer Interested',
    'Call Completed - Documents Promised',
    'Customer Requested Call Back',
    'Customer Not Reachable / No Answer',
    'Bank Follow-up Completed',
    'Issue Resolved',
    'Other',
  ];

  String _selectedResult = predefinedResults.first;
  final TextEditingController _otherResultController = TextEditingController();
  final TextEditingController _remarksController = TextEditingController();
  DateTime? _nextFollowupDate;
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _otherResultController.dispose();
    _remarksController.dispose();
    super.dispose();
  }

  void _submit() {
    if (_selectedResult == 'Other') {
      if (_otherResultController.text.trim().isEmpty) {
        _formKey.currentState?.validate();
        return;
      }
    }

    final effectiveResult = _selectedResult == 'Other'
        ? _otherResultController.text.trim()
        : _selectedResult;

    Navigator.of(context).pop(
      FollowupDoneResult(
        followupResult: effectiveResult,
        remarks: _remarksController.text.trim().isNotEmpty
            ? _remarksController.text.trim()
            : null,
        nextFollowupDate: _nextFollowupDate,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isOther = _selectedResult == 'Other';

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
              color: Color(0xFFDCFCE7),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_circle_outline_rounded,
              color: Color(0xFF059669),
              size: 24,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Record Follow-up Outcome',
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
                // Follow-up Result
                const Text(
                  'Follow-up Result *',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                ),
                const SizedBox(height: 4),
                DropdownButtonFormField<String>(
                  value: _selectedResult,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  ),
                  items: predefinedResults.map((result) {
                    return DropdownMenuItem<String>(
                      value: result,
                      child: Text(result, style: const TextStyle(fontSize: 12)),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() => _selectedResult = val);
                    }
                  },
                ),
                if (isOther) ...[
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _otherResultController,
                    decoration: const InputDecoration(
                      labelText: 'Specify Result *',
                      hintText: 'Enter outcome details...',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    ),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) {
                        return 'Please provide result outcome';
                      }
                      return null;
                    },
                  ),
                ],
                const SizedBox(height: 12),

                // Remarks
                const Text(
                  'Remarks (Call summary / Next steps)',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                ),
                const SizedBox(height: 4),
                TextFormField(
                  controller: _remarksController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    hintText: 'Notes from customer conversation...',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.all(10),
                  ),
                ),
                const SizedBox(height: 12),

                // Optional Next Follow-up Date
                const Text(
                  'Next Follow-up Date (Optional)',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                ),
                const SizedBox(height: 4),
                InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _nextFollowupDate ?? DateTime.now().add(const Duration(days: 3)),
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (picked != null) {
                      setState(() => _nextFollowupDate = picked);
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
                            const Icon(Icons.calendar_month, size: 16, color: Color(0xFF059669)),
                            const SizedBox(width: 6),
                            Text(
                              _nextFollowupDate != null
                                  ? _nextFollowupDate!.toLocal().toString().split(' ')[0]
                                  : 'Select next date if needed...',
                              style: TextStyle(
                                fontSize: 12,
                                color: _nextFollowupDate != null ? Colors.black87 : Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                        if (_nextFollowupDate != null)
                          GestureDetector(
                            onTap: () => setState(() => _nextFollowupDate = null),
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
            backgroundColor: const Color(0xFF059669),
          ),
          onPressed: _submit,
          icon: const Icon(Icons.check_circle_outline, size: 16),
          label: const Text('Save Outcome'),
        ),
      ],
    );
  }
}
