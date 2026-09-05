import 'package:flutter/material.dart';

/// Dialog to prompt mobile app users for a mandatory reason when marking a customer as
/// "No Action Required" (Hold).
class NoActionReasonDialog extends StatefulWidget {
  final String customerName;

  const NoActionReasonDialog({
    super.key,
    required this.customerName,
  });

  static Future<Map<String, String>?> show(
    BuildContext context, {
    required String customerName,
  }) {
    return showDialog<Map<String, String>>(
      context: context,
      barrierDismissible: false,
      builder: (_) => NoActionReasonDialog(customerName: customerName),
    );
  }

  @override
  State<NoActionReasonDialog> createState() => _NoActionReasonDialogState();
}

class _NoActionReasonDialogState extends State<NoActionReasonDialog> {
  static const List<String> predefinedReasons = [
    'Waiting for customer response',
    'Customer requested hold',
    'Waiting for bank response',
    'Pending internal decision',
    'Temporary hold',
    'Other',
  ];

  String _selectedReason = predefinedReasons.first;
  final TextEditingController _detailsController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _detailsController.dispose();
    super.dispose();
  }

  void _submit() {
    if (_selectedReason == 'Other') {
      if (_detailsController.text.trim().isEmpty) {
        _formKey.currentState?.validate();
        return;
      }
    }

    Navigator.of(context).pop({
      'reason': _selectedReason,
      'details': _detailsController.text.trim(),
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isOther = _selectedReason == 'Other';

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
      contentPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
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
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Mark as No Action',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                Text(
                  widget.customerName,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.normal,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
      content: Form(
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
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Icon(Icons.info_outline, color: Color(0xFFB45309), size: 16),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'This customer will be paused from active lists. Not marked as Completed. You can reopen anytime.',
                        style: TextStyle(color: Color(0xFF92400E), fontSize: 11),
                      ),
                    ),
                  ],
                ),
              ),
              const Text(
                'Select Reason *',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
              ),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                value: _selectedReason,
                isExpanded: true,
                decoration: InputDecoration(
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                ),
                items: predefinedReasons.map((r) {
                  return DropdownMenuItem<String>(
                    value: r,
                    child: Text(r, style: const TextStyle(fontSize: 13)),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      _selectedReason = val;
                    });
                  }
                },
              ),
              const SizedBox(height: 14),
              Text(
                isOther ? 'Explanation / Notes *' : 'Additional Notes (Optional)',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                  color: isOther ? const Color(0xFFB45309) : null,
                ),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _detailsController,
                maxLines: 2,
                decoration: InputDecoration(
                  hintText: isOther
                      ? 'Please enter detailed reason...'
                      : 'Add remarks for team (optional)...',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  contentPadding: const EdgeInsets.all(10),
                ),
                validator: (val) {
                  if (isOther && (val == null || val.trim().isEmpty)) {
                    return 'Please specify the reason';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFFD97706),
            foregroundColor: Colors.white,
          ),
          onPressed: _submit,
          child: const Text('Confirm'),
        ),
      ],
    );
  }
}
