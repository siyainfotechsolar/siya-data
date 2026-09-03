import 'package:flutter/material.dart';
import '../models/consumer_record.dart';
import '../services/record_service.dart';

class RecordDetailsDialog extends StatefulWidget {
  final ConsumerRecord record;
  final VoidCallback? onRecordUpdated;

  const RecordDetailsDialog({super.key, required this.record, this.onRecordUpdated});

  @override
  State<RecordDetailsDialog> createState() => _RecordDetailsDialogState();
}

class _RecordDetailsDialogState extends State<RecordDetailsDialog> {
  late ConsumerRecord _record;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _record = widget.record;
  }

  String _safeValue(String currentValue, List<String> allowedItems) {
    for (final item in allowedItems) {
      if (item.trim().toLowerCase() == currentValue.trim().toLowerCase()) {
        return item;
      }
    }
    return allowedItems.first;
  }

  String _formatDate(DateTime? dt) {
    if (dt == null) return 'Not Set';
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
  }

  Future<void> _pickDate({required bool isSubmitDate}) async {
    final initial = isSubmitDate ? (_record.submitDate ?? DateTime.now()) : (_record.applicationDate ?? DateTime.now());
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      if (isSubmitDate) {
        await _updateWorkflowField(submitDate: picked);
      } else {
        await _updateWorkflowField(applicationDate: picked);
      }
    }
  }

  Future<void> _updateWorkflowField({
    String? applicationStatus,
    DateTime? applicationDate,
    DateTime? submitDate,
    String? agreementStatus,
    String? loanRequired,
    String? loanStatus,
    String? installationStatus,
    String? installerTeam,
    String? rtsStatus,
    String? rtsApplicationId,
    String? subsidyStatus,
  }) async {
    // 1. Dependency Guard Validation
    final prospective = _record.copyWith(
      applicationStatus: applicationStatus,
      applicationDate: applicationDate,
      submitDate: submitDate,
      agreementStatus: agreementStatus,
      loanRequired: loanRequired,
      loanStatus: loanStatus,
      installationStatus: installationStatus,
      installerTeam: installerTeam,
      rtsStatus: rtsStatus,
      rtsApplicationId: rtsApplicationId,
      subsidyStatus: subsidyStatus,
    );

    // Guard 1: Loan required but not approved blocks installation completion
    if (installationStatus != null &&
        installationStatus.toLowerCase() == 'installation completed' &&
        !prospective.isLoanSatisfied) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot mark Installation Completed! Loan is required and must be Approved first.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Guard 2: RTS Completed requires Installation Completed
    if (rtsStatus != null &&
        rtsStatus.toLowerCase() == 'completed' &&
        _record.installationStatus.toLowerCase() != 'installation completed') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot mark RTS Completed! Installation must be completed first.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Guard 3: Subsidy Approved/Received requires RTS Completed
    if (subsidyStatus != null &&
        (subsidyStatus.toLowerCase() == 'approved' || subsidyStatus.toLowerCase() == 'received') &&
        _record.rtsStatus.toLowerCase() != 'completed') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot mark Subsidy Approved/Received! RTS must be Completed first.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final updated = await RecordService.updateRecord(prospective);
      if (mounted) {
        setState(() {
          _record = updated;
          _isSaving = false;
        });
        widget.onRecordUpdated?.call();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Customer workflow updated successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 720, maxHeight: 850),
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 22,
                      backgroundColor: theme.colorScheme.primaryContainer,
                      child: Icon(Icons.solar_power_rounded, color: theme.colorScheme.primary, size: 26),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _record.name,
                          style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'Consumer No: ${_record.consumerNo} • Stage: ${_record.overallStage}',
                          style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 13),
                        ),
                      ],
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const Divider(height: 24),

            // Scrollable Workflow Lifecycle Sections
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Visual Workflow Timeline Tracker
                    _buildVisualTimeline(),
                    const SizedBox(height: 20),

                    // Stage 1: Application
                    _buildStageCard(
                      title: '1. Application',
                      icon: Icons.assignment_outlined,
                      color: Colors.indigo,
                      content: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildDetailRow('Application ID', _record.applicationId ?? '—'),
                          _buildDetailRow('Mobile Number', _record.mobile ?? '—'),
                          _buildDetailRow('Address', _record.address ?? '—'),
                          
                          // Application Date row with pick button
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4.0),
                            child: Row(
                              children: [
                                const SizedBox(
                                  width: 140,
                                  child: Text('Application Date:', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey)),
                                ),
                                Text(_formatDate(_record.applicationDate), style: const TextStyle(fontWeight: FontWeight.w500)),
                                const SizedBox(width: 8),
                                InkWell(
                                  onTap: _isSaving ? null : () => _pickDate(isSubmitDate: false),
                                  child: const Padding(
                                    padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                    child: Icon(Icons.calendar_month_outlined, size: 18, color: Colors.indigo),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Submit Date row with pick button
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4.0),
                            child: Row(
                              children: [
                                const SizedBox(
                                  width: 140,
                                  child: Text('Submit Date:', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey)),
                                ),
                                Text(_formatDate(_record.submitDate), style: const TextStyle(fontWeight: FontWeight.w500)),
                                const SizedBox(width: 8),
                                InkWell(
                                  onTap: _isSaving ? null : () => _pickDate(isSubmitDate: true),
                                  child: const Padding(
                                    padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                    child: Icon(Icons.edit_calendar_outlined, size: 18, color: Colors.indigo),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Application Days & Priority Badge
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4.0),
                            child: Row(
                              children: [
                                const SizedBox(
                                  width: 140,
                                  child: Text('Application Days:', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey)),
                                ),
                                Text('${_record.applicationDays} days elapsed ', style: const TextStyle(fontWeight: FontWeight.bold)),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: _record.priorityLevel.color.withAlpha(40),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: _record.priorityLevel.color),
                                  ),
                                  child: Text(
                                    _record.priority,
                                    style: TextStyle(
                                      color: _record.priorityLevel.color,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 11,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const SizedBox(
                                width: 140,
                                child: Text('Application Status: ', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey)),
                              ),
                              DropdownButton<String>(
                                value: _safeValue(_record.applicationStatus, const ['Submitted', 'Pending', 'Under Verification', 'Approved', 'Rejected']),
                                isDense: true,
                                items: const [
                                  DropdownMenuItem(value: 'Submitted', child: Text('Submitted')),
                                  DropdownMenuItem(value: 'Pending', child: Text('Pending')),
                                  DropdownMenuItem(value: 'Under Verification', child: Text('Under Verification')),
                                  DropdownMenuItem(value: 'Approved', child: Text('Approved')),
                                  DropdownMenuItem(value: 'Rejected', child: Text('Rejected')),
                                ],
                                onChanged: _isSaving ? null : (val) => _updateWorkflowField(applicationStatus: val),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 14),

                    // Stage 2: Agreement
                    _buildStageCard(
                      title: '2. Agreement',
                      icon: Icons.history_edu_rounded,
                      color: const Color(0xFF2563EB),
                      content: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildDetailRow('Agreement Required', _record.agreementRequired ? 'Yes' : 'No'),
                          Row(
                            children: [
                              const Text('Agreement Status: ', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey)),
                              const SizedBox(width: 8),
                              DropdownButton<String>(
                                value: _safeValue(_record.agreementStatus, const ['Pending', 'Uploaded', 'Verified', 'Rejected']),
                                isDense: true,
                                items: const [
                                  DropdownMenuItem(value: 'Pending', child: Text('Pending')),
                                  DropdownMenuItem(value: 'Uploaded', child: Text('Uploaded')),
                                  DropdownMenuItem(value: 'Verified', child: Text('Verified')),
                                  DropdownMenuItem(value: 'Rejected', child: Text('Rejected')),
                                ],
                                onChanged: _isSaving ? null : (val) => _updateWorkflowField(agreementStatus: val),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 14),

                    // Stage 3: Loan Decision
                    _buildStageCard(
                      title: '3. Loan Decision & Status',
                      icon: Icons.account_balance_rounded,
                      color: const Color(0xFFD97706),
                      content: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Text('Loan Required? ', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey)),
                              const SizedBox(width: 8),
                              DropdownButton<String>(
                                value: _safeValue(_record.loanRequired, const ['No', 'Yes']),
                                isDense: true,
                                items: const [
                                  DropdownMenuItem(value: 'No', child: Text('No (Direct Cash/Self)')),
                                  DropdownMenuItem(value: 'Yes', child: Text('Yes (Bank Loan)')),
                                ],
                                onChanged: _isSaving ? null : (val) {
                                  final newLoanStatus = val == 'Yes' ? 'Pending' : 'Not Required';
                                  _updateWorkflowField(loanRequired: val, loanStatus: newLoanStatus);
                                },
                              ),
                            ],
                          ),
                          if (_record.loanRequired.toLowerCase() == 'yes') ...[
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                const Text('Loan Status: ', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey)),
                                const SizedBox(width: 8),
                                DropdownButton<String>(
                                  value: _safeValue(_record.loanStatus, const ['Not Required', 'Pending', 'Applied', 'Under Process', 'Approved', 'Rejected']),
                                  isDense: true,
                                  items: const [
                                    DropdownMenuItem(value: 'Not Required', child: Text('Not Required')),
                                    DropdownMenuItem(value: 'Pending', child: Text('Pending')),
                                    DropdownMenuItem(value: 'Applied', child: Text('Applied')),
                                    DropdownMenuItem(value: 'Under Process', child: Text('Under Process')),
                                    DropdownMenuItem(value: 'Approved', child: Text('Approved')),
                                    DropdownMenuItem(value: 'Rejected', child: Text('Rejected')),
                                  ],
                                  onChanged: _isSaving ? null : (val) => _updateWorkflowField(loanStatus: val),
                                ),
                              ],
                            ),
                            if (_record.loanStatus != 'Approved')
                              Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Text(
                                  '⚠️ Note: Installation completion is blocked until Loan is Approved.',
                                  style: TextStyle(fontSize: 12, color: Colors.amber.shade900, fontWeight: FontWeight.bold),
                                ),
                              ),
                          ],
                        ],
                      ),
                    ),

                    const SizedBox(height: 14),

                    // Stage 4: Installation
                    _buildStageCard(
                      title: '4. Installation Stage',
                      icon: Icons.build_circle_rounded,
                      color: const Color(0xFF0F766E),
                      content: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Text('Installation Status: ', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey)),
                              const SizedBox(width: 8),
                              DropdownButton<String>(
                                value: _safeValue(_record.installationStatus, const ['Not Started', 'Scheduled', 'Installation Pending', 'Structure Pending', 'Panel Pending', 'Wiring Pending', 'Installation Completed']),
                                isDense: true,
                                items: const [
                                  DropdownMenuItem(value: 'Not Started', child: Text('Not Started')),
                                  DropdownMenuItem(value: 'Scheduled', child: Text('Scheduled')),
                                  DropdownMenuItem(value: 'Installation Pending', child: Text('Installation Pending')),
                                  DropdownMenuItem(value: 'Structure Pending', child: Text('Structure Pending')),
                                  DropdownMenuItem(value: 'Panel Pending', child: Text('Panel Pending')),
                                  DropdownMenuItem(value: 'Wiring Pending', child: Text('Wiring Pending')),
                                  DropdownMenuItem(value: 'Installation Completed', child: Text('Installation Completed')),
                                ],
                                onChanged: _isSaving ? null : (val) => _updateWorkflowField(installationStatus: val),
                              ),
                            ],
                          ),
                          if (_record.installerTeam != null && _record.installerTeam!.isNotEmpty)
                            _buildDetailRow('Assigned Team', _record.installerTeam!),
                        ],
                      ),
                    ),

                    const SizedBox(height: 14),

                    // Stage 5: RTS / Net Meter
                    _buildStageCard(
                      title: '5. RTS / Net Metering',
                      icon: Icons.electric_meter_rounded,
                      color: const Color(0xFF7C3AED),
                      content: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Text('RTS Status: ', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey)),
                              const SizedBox(width: 8),
                              DropdownButton<String>(
                                value: _safeValue(_record.rtsStatus, const ['Not Started', 'Application Pending', 'Applied', 'Meter Pending', 'Inspection Pending', 'Completed', 'Rejected']),
                                isDense: true,
                                items: const [
                                  DropdownMenuItem(value: 'Not Started', child: Text('Not Started')),
                                  DropdownMenuItem(value: 'Application Pending', child: Text('Application Pending')),
                                  DropdownMenuItem(value: 'Applied', child: Text('Applied')),
                                  DropdownMenuItem(value: 'Meter Pending', child: Text('Meter Pending')),
                                  DropdownMenuItem(value: 'Inspection Pending', child: Text('Inspection Pending')),
                                  DropdownMenuItem(value: 'Completed', child: Text('Completed')),
                                  DropdownMenuItem(value: 'Rejected', child: Text('Rejected')),
                                ],
                                onChanged: _isSaving ? null : (val) => _updateWorkflowField(rtsStatus: val),
                              ),
                            ],
                          ),
                          if (_record.rtsApplicationId != null && _record.rtsApplicationId!.isNotEmpty)
                            _buildDetailRow('RTS App ID', _record.rtsApplicationId!),
                        ],
                      ),
                    ),

                    const SizedBox(height: 14),

                    // Stage 6: Subsidy
                    _buildStageCard(
                      title: '6. Government Subsidy',
                      icon: Icons.currency_rupee_rounded,
                      color: const Color(0xFF059669),
                      content: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Text('Subsidy Status: ', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey)),
                              const SizedBox(width: 8),
                              DropdownButton<String>(
                                value: _safeValue(_record.subsidyStatus, const ['Not Applied', 'Applied', 'Under Process', 'Pending', 'Approved', 'Received', 'Rejected']),
                                isDense: true,
                                items: const [
                                  DropdownMenuItem(value: 'Not Applied', child: Text('Not Applied')),
                                  DropdownMenuItem(value: 'Applied', child: Text('Applied')),
                                  DropdownMenuItem(value: 'Under Process', child: Text('Under Process')),
                                  DropdownMenuItem(value: 'Pending', child: Text('Pending')),
                                  DropdownMenuItem(value: 'Approved', child: Text('Approved')),
                                  DropdownMenuItem(value: 'Received', child: Text('Received')),
                                  DropdownMenuItem(value: 'Rejected', child: Text('Rejected')),
                                ],
                                onChanged: _isSaving ? null : (val) => _updateWorkflowField(subsidyStatus: val),
                              ),
                            ],
                          ),
                          if (_record.isFullyCompleted)
                            const Padding(
                              padding: EdgeInsets.only(top: 8),
                              child: Text(
                                '🎉 Customer solar journey is 100% Completed!',
                                style: TextStyle(color: Color(0xFF059669), fontWeight: FontWeight.bold),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Done'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVisualTimeline() {
    final stages = [
      {'label': 'App', 'done': true},
      {'label': 'Agreement', 'done': _record.agreementStatus.toLowerCase() == 'verified'},
      {'label': 'Loan', 'done': _record.isLoanSatisfied},
      {'label': 'Install', 'done': _record.installationStatus.toLowerCase() == 'installation completed'},
      {'label': 'RTS', 'done': _record.rtsStatus.toLowerCase() == 'completed'},
      {'label': 'Subsidy', 'done': _record.subsidyStatus.toLowerCase() == 'received'},
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: stages.map((s) {
          final isDone = s['done'] as bool;
          return Row(
            children: [
              Icon(
                isDone ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
                size: 16,
                color: isDone ? const Color(0xFF059669) : Colors.grey.shade400,
              ),
              const SizedBox(width: 4),
              Text(
                s['label'] as String,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isDone ? FontWeight.bold : FontWeight.normal,
                  color: isDone ? const Color(0xFF0F766E) : Colors.grey.shade600,
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildStageCard({
    required String title,
    required IconData icon,
    required Color color,
    required Widget content,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 8),
              Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color)),
            ],
          ),
          const Divider(height: 16),
          content,
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          SizedBox(
            width: 140,
            child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.grey, fontSize: 13)),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
          ),
        ],
      ),
    );
  }
}
