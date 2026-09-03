import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/consumer_record.dart';
import '../services/record_service.dart';

class RecordDetailScreen extends StatefulWidget {
  final ConsumerRecord initialRecord;

  const RecordDetailScreen({super.key, required this.initialRecord});

  @override
  State<RecordDetailScreen> createState() => _RecordDetailScreenState();
}

class _RecordDetailScreenState extends State<RecordDetailScreen> {
  late ConsumerRecord _record;
  bool _hasChanged = false;

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
    _record = widget.initialRecord;
  }

  void _showUpdateStatusSheet() {
    String selectedStatus = _record.status;
    final remarksController = TextEditingController(text: _record.remarks ?? '');
    bool isSaving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Update Installation Status',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.of(ctx).pop(),
                      ),
                    ],
                  ),
                  const Divider(),
                  const SizedBox(height: 10),

                  // Status Radio Options
                  ..._statusOptions.map((status) {
                    return RadioListTile<String>(
                      title: Text(status, style: const TextStyle(fontWeight: FontWeight.w500)),
                      value: status,
                      groupValue: selectedStatus,
                      activeColor: Theme.of(context).colorScheme.primary,
                      onChanged: (val) {
                        if (val != null) {
                          setSheetState(() => selectedStatus = val);
                        }
                      },
                    );
                  }),

                  const SizedBox(height: 10),

                  // Remarks Input
                  TextField(
                    controller: remarksController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Field Notes / Site Remarks',
                      hintText: 'e.g., Solar panels mounted, inverter pending grid connection...',
                      border: OutlineInputBorder(),
                    ),
                  ),

                  const SizedBox(height: 20),

                  FilledButton(
                    onPressed: isSaving
                        ? null
                        : () async {
                            if (_record.id == null) return;

                            setSheetState(() => isSaving = true);

                            try {
                              final updated = await MobileRecordService.updateRecordStatus(
                                id: _record.id!,
                                consumerNo: _record.consumerNo,
                                oldStatus: _record.status,
                                newStatus: selectedStatus,
                                remarks: remarksController.text,
                              );

                              if (mounted) {
                                setState(() {
                                  _record = updated;
                                  _hasChanged = true;
                                });
                                Navigator.of(ctx).pop();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Installation status updated successfully!'),
                                    backgroundColor: Colors.green,
                                  ),
                                );
                              }
                            } catch (e) {
                              setSheetState(() => isSaving = false);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Failed to update status: $e'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            }
                          },
                    style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                    child: isSaving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Text('Save Status Update', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {
        // Return hasChanged to parent list
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Consumer Details'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.of(context).pop(_hasChanged),
          ),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header Card
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(18.0),
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 32,
                        backgroundColor: theme.colorScheme.primaryContainer,
                        child: Icon(Icons.person, size: 36, color: theme.colorScheme.primary),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _record.name,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Consumer No: ${_record.consumerNo}',
                          style: TextStyle(fontWeight: FontWeight.bold, color: theme.colorScheme.onSurfaceVariant),
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildStatusBadge(_record.status),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Details Information Card
              Card(
                elevation: 1,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Contact & Location', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                      const Divider(height: 20),

                      // Mobile
                      _buildInfoRow(
                        icon: Icons.phone,
                        label: 'Mobile Number',
                        value: _record.mobile ?? 'Not provided',
                        trailing: _record.mobile != null && _record.mobile!.trim().isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.call, color: Colors.green),
                                tooltip: 'Call Consumer',
                                onPressed: () async {
                                  final rawPhone = _record.mobile!.replaceAll(RegExp(r'[^\d+]'), '');
                                  final Uri phoneUri = Uri.parse('tel:$rawPhone');
                                  try {
                                    if (await canLaunchUrl(phoneUri)) {
                                      await launchUrl(phoneUri, mode: LaunchMode.externalApplication);
                                    } else {
                                      await launchUrl(phoneUri);
                                    }
                                  } catch (e) {
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('Could not open phone dialer: $e'),
                                          backgroundColor: Colors.red,
                                        ),
                                      );
                                    }
                                  }
                                },
                              )
                            : null,
                      ),

                      // Application ID
                      _buildInfoRow(
                        icon: Icons.assignment_ind_outlined,
                        label: 'Application ID',
                        value: _record.applicationId ?? 'Not registered',
                      ),

                      // Address
                      _buildInfoRow(
                        icon: Icons.location_on_outlined,
                        label: 'Premise Address',
                        value: _record.address ?? 'No address recorded',
                      ),

                      // Remarks
                      _buildInfoRow(
                        icon: Icons.notes,
                        label: 'Field Remarks',
                        value: _record.remarks ?? 'No notes available',
                      ),

                      // Updated At
                      if (_record.updatedAt != null)
                        _buildInfoRow(
                          icon: Icons.update,
                          label: 'Last Synchronized',
                          value: _record.updatedAt!.toLocal().toString().split('.')[0],
                        ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Action Button
              FilledButton.icon(
                onPressed: _showUpdateStatusSheet,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.edit_note, size: 22),
                label: const Text('Update Installation Status', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
    Widget? trailing,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Colors.grey.shade600),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                const SizedBox(height: 2),
                Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
          if (trailing != null) trailing,
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color bg;
    Color fg;

    switch (status) {
      case 'Approved':
      case 'Completed':
        bg = Colors.green.withValues(alpha: 0.15);
        fg = Colors.green.shade800;
        break;
      case 'In Progress':
        bg = Colors.blue.withValues(alpha: 0.15);
        fg = Colors.blue.shade800;
        break;
      case 'Rejected':
        bg = Colors.red.withValues(alpha: 0.15);
        fg = Colors.red.shade800;
        break;
      case 'Pending':
      default:
        bg = Colors.orange.withValues(alpha: 0.15);
        fg = Colors.orange.shade800;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        status,
        style: TextStyle(color: fg, fontWeight: FontWeight.bold, fontSize: 13),
      ),
    );
  }
}
