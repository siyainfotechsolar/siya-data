import 'package:flutter/material.dart';
import '../models/consumer_record.dart';
import '../services/record_service.dart';

class RecordFormDialog extends StatefulWidget {
  final ConsumerRecord? initialRecord;
  final Function(ConsumerRecord)? onRecordSaved;

  const RecordFormDialog({super.key, this.initialRecord, this.onRecordSaved});

  @override
  State<RecordFormDialog> createState() => _RecordFormDialogState();
}

class _RecordFormDialogState extends State<RecordFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _consumerNoController;
  late TextEditingController _nameController;
  late TextEditingController _mobileController;
  late TextEditingController _addressController;
  late TextEditingController _applicationIdController;
  late TextEditingController _remarksController;
  late String _status;
  bool _isLoading = false;
  String? _errorMessage;

  final List<String> _statusOptions = [
    'Pending',
    'Approved',
    'In Progress',
    'Completed',
    'Rejected',
  ];

  @override
  void initState() {
    super.initState();
    final r = widget.initialRecord;
    _consumerNoController = TextEditingController(text: r?.consumerNo ?? '');
    _nameController = TextEditingController(text: r?.name ?? '');
    _mobileController = TextEditingController(text: r?.mobile ?? '');
    _addressController = TextEditingController(text: r?.address ?? '');
    _applicationIdController = TextEditingController(text: r?.applicationId ?? '');
    _remarksController = TextEditingController(text: r?.remarks ?? '');
    _status = r?.status ?? 'Pending';
  }

  @override
  void dispose() {
    _consumerNoController.dispose();
    _nameController.dispose();
    _mobileController.dispose();
    _addressController.dispose();
    _applicationIdController.dispose();
    _remarksController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final record = ConsumerRecord(
        id: widget.initialRecord?.id,
        consumerNo: _consumerNoController.text.trim(),
        name: _nameController.text.trim(),
        mobile: _mobileController.text.trim().isEmpty ? null : _mobileController.text.trim(),
        address: _addressController.text.trim().isEmpty ? null : _addressController.text.trim(),
        applicationId: _applicationIdController.text.trim().isEmpty ? null : _applicationIdController.text.trim(),
        status: _status,
        remarks: _remarksController.text.trim().isEmpty ? null : _remarksController.text.trim(),
      );

      if (widget.initialRecord == null) {
        await RecordService.createRecord(record);
      } else {
        await RecordService.updateRecord(record);
      }

      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      setState(() {
        final err = e.toString();
        if (err.contains('duplicate key') || err.contains('consumer_records_consumer_no_key')) {
          _errorMessage = 'A record with Consumer No "${_consumerNoController.text.trim()}" already exists!';
        } else {
          _errorMessage = err.replaceAll('Exception: ', '');
        }
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isEdit = widget.initialRecord != null;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 580),
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    isEdit ? 'Edit Consumer Record' : 'Add New Consumer Record',
                    style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(false),
                  ),
                ],
              ),
              const Divider(height: 24),
              if (_errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline, color: theme.colorScheme.error, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: TextStyle(
                            color: theme.colorScheme.onErrorContainer,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _consumerNoController,
                              decoration: const InputDecoration(
                                labelText: 'Consumer No *',
                                prefixIcon: Icon(Icons.tag),
                                border: OutlineInputBorder(),
                              ),
                              validator: (v) =>
                                  (v == null || v.trim().isEmpty) ? 'Required' : null,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: TextFormField(
                              controller: _applicationIdController,
                              decoration: const InputDecoration(
                                labelText: 'Application ID',
                                prefixIcon: Icon(Icons.numbers),
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                          labelText: 'Consumer Name *',
                          prefixIcon: Icon(Icons.person),
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) =>
                            (v == null || v.trim().isEmpty) ? 'Required' : null,
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _mobileController,
                              keyboardType: TextInputType.phone,
                              decoration: const InputDecoration(
                                labelText: 'Mobile Number',
                                prefixIcon: Icon(Icons.phone),
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: _status,
                              decoration: const InputDecoration(
                                labelText: 'Status',
                                prefixIcon: Icon(Icons.flag),
                                border: OutlineInputBorder(),
                              ),
                              items: _statusOptions
                                  .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                                  .toList(),
                              onChanged: (val) {
                                if (val != null) {
                                  setState(() => _status = val);
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _addressController,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          labelText: 'Address / Location',
                          prefixIcon: Icon(Icons.location_on_outlined),
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _remarksController,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          labelText: 'Remarks / Notes',
                          prefixIcon: Icon(Icons.note_alt_outlined),
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 12),
                  FilledButton(
                    onPressed: _isLoading ? null : _handleSave,
                    child: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : Text(isEdit ? 'Save Changes' : 'Create Record'),
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
