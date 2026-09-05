import 'package:flutter/material.dart';
import '../models/consumer_record.dart';
import '../services/record_service.dart';
import '../services/workflow_engine.dart';
import 'no_action_reason_dialog.dart';

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
  bool _isOwnerOverride = false;
  String _overrideReason = '';

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

  Future<void> _showMarkLoanRejectedDialog() async {
    final reasonCtrl = TextEditingController();
    final remarksCtrl = TextEditingController();
    final correctionCtrl = TextEditingController();
    bool isSaving = false;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.gavel_rounded, color: Color(0xFFDC2626)),
              SizedBox(width: 8),
              Text('Mark Loan Rejected'),
            ],
          ),
          content: SizedBox(
            width: 480,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Enter the bank rejection details. The loan stage will be set to "Correction Required".',
                  style: TextStyle(fontSize: 13),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: reasonCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Rejection Reason *',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: remarksCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Bank Remarks (optional)',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: correctionCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Correction Required *',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  maxLines: 2,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isSaving ? null : () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: const Color(0xFFDC2626)),
              onPressed: isSaving
                  ? null
                  : () async {
                      if (reasonCtrl.text.trim().isEmpty || correctionCtrl.text.trim().isEmpty) {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          const SnackBar(content: Text('Rejection Reason and Correction Required are mandatory.')),
                        );
                        return;
                      }
                      setDlgState(() => isSaving = true);
                      try {
                        final updated = await RecordService.markLoanRejected(
                          recordId: _record.id!,
                          rejectionReason: reasonCtrl.text.trim(),
                          bankRemarks: remarksCtrl.text.trim().isEmpty ? null : remarksCtrl.text.trim(),
                          correctionRequired: correctionCtrl.text.trim(),
                        );
                        if (mounted) {
                          setState(() {
                            _record = updated;
                          });
                          widget.onRecordUpdated?.call();
                          // ignore: use_build_context_synchronously
                          Navigator.pop(ctx);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Loan marked as Rejected. Stage set to Correction Required.'),
                                backgroundColor: Colors.orange,
                              ),
                            );
                          }
                        }
                      } catch (e) {
                        setDlgState(() => isSaving = false);
                        if (ctx.mounted) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                          );
                        }
                      }
                    },
              child: isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Confirm Rejection'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleReapplyLoan() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.replay_rounded, color: Color(0xFF2563EB)),
            SizedBox(width: 8),
            Text('Re-Apply Loan'),
          ],
        ),
        content: Text(
          'This will increment the re-apply count to ${_record.loanReapplyCount + 1} and reset the loan stage back to "Loan Applied".\n\nPrevious rejection details will be saved in the history.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirm Re-Apply'),
          ),
        ],
      ),
    );

    if (confirmed == true && _record.id != null && mounted) {
      setState(() => _isSaving = true);
      try {
        final updated = await RecordService.reapplyLoan(currentRecord: _record);
        if (mounted) {
          setState(() {
            _record = updated;
            _isSaving = false;
          });
          widget.onRecordUpdated?.call();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Loan re-application #${updated.loanReapplyCount} submitted. Stage reset to Loan Applied.'),
              backgroundColor: const Color(0xFF2563EB),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isSaving = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to re-apply loan: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
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

  Future<void> _toggleOwnerOverride() async {
    if (_isOwnerOverride) {
      setState(() {
        _isOwnerOverride = false;
        _overrideReason = '';
      });
      return;
    }

    final controller = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.shield_rounded, color: Colors.orange),
            SizedBox(width: 8),
            Text('Owner Workflow Override'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enabling Owner Override allows editing locked future stages out-of-order.',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'Reason for Override *',
                hintText: 'e.g. Manual backdated import correction',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              if (controller.text.trim().isEmpty) return;
              Navigator.pop(ctx, true);
            },
            child: const Text('Confirm Override'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      setState(() {
        _isOwnerOverride = true;
        _overrideReason = controller.text.trim();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Owner Override Active: $_overrideReason')),
      );
    }
  }

  Future<void> _updateWorkflowField({
    String? applicationStatus,
    DateTime? applicationDate,
    DateTime? submitDate,
    String? agreementStatus,
    String? loanRequired,
    String? loanStatus,
    String? loanSubStage,
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
      loanSubStage: loanSubStage,
      installationStatus: installationStatus,
      installerTeam: installerTeam,
      rtsStatus: rtsStatus,
      rtsApplicationId: rtsApplicationId,
      subsidyStatus: subsidyStatus,
    );

    // 1-by-1 Workflow Rule Validation
    if (!_isOwnerOverride) {
      final errors = WorkflowEngine.validateStageProgression(
        _record,
        newAgreementStatus: agreementStatus,
        newLoanStatus: loanStatus,
        newInstallationStatus: installationStatus,
        newRtsStatus: rtsStatus,
        newSubsidyStatus: subsidyStatus,
        newLoanRequired: loanRequired,
      );

      if (errors.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errors.first),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
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

  Future<void> _handleMarkAsComplete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.check_circle_outline, color: Colors.green),
            SizedBox(width: 8),
            Text('Mark as Complete'),
          ],
        ),
        content: const Text('Mark this customer as complete?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFF059669)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Mark as Complete'),
          ),
        ],
      ),
    );

    if (confirmed == true && _record.id != null && mounted) {
      setState(() => _isSaving = true);
      try {
        final updated = await RecordService.markCustomerAsComplete(_record.id!);
        if (mounted) {
          setState(() {
            _record = updated;
            _isSaving = false;
          });
          widget.onRecordUpdated?.call();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Customer marked as complete! Removed from Priority List.'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isSaving = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to mark complete: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  Future<void> _handleMarkAsNoActionRequired() async {
    final result = await NoActionReasonDialog.show(context, customerName: _record.name);
    if (result != null && _record.id != null && mounted) {
      setState(() => _isSaving = true);
      try {
        final updated = await RecordService.markCustomerAsNoActionRequired(
          recordId: _record.id!,
          reason: result['reason'] ?? 'Hold',
          freeTextDetails: result['details'],
        );
        if (mounted) {
          setState(() {
            _record = updated;
            _isSaving = false;
          });
          widget.onRecordUpdated?.call();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Customer marked as No Action Required (Hold)! Removed from active queues.'),
              backgroundColor: Color(0xFFD97706),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isSaving = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to update state: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  Future<void> _handleReopen() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.refresh, color: Colors.blue),
            SizedBox(width: 8),
            Text('Reopen Customer'),
          ],
        ),
        content: const Text('Reopen this customer and return to active priority list?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Reopen'),
          ),
        ],
      ),
    );

    if (confirmed == true && _record.id != null && mounted) {
      setState(() => _isSaving = true);
      try {
        final updated = await RecordService.reopenCustomer(_record.id!);
        if (mounted) {
          setState(() {
            _record = updated;
            _isSaving = false;
          });
          widget.onRecordUpdated?.call();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Customer reopened and returned to active workflow!'),
              backgroundColor: Colors.blue,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isSaving = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to reopen customer: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final stageStates = WorkflowEngine.getStageStates(_record, isOwnerOverride: _isOwnerOverride);

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
                    if (_record.isNoActionRequired)
                      Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF3C7),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFF59E0B)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.pause_circle_filled, color: Color(0xFFD97706), size: 24),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'WORK STATE: NO ACTION REQUIRED (HOLD)',
                                    style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF92400E), fontSize: 13),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Reason: ${_record.noActionReason ?? _record.holdReason ?? "Hold"}' +
                                        (_record.noActionByName != null ? ' • By: ${_record.noActionByName}' : '') +
                                        (_record.noActionDate != null ? ' • Date: ${_formatDate(_record.noActionDate)}' : ''),
                                    style: const TextStyle(color: Color(0xFFB45309), fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    // Visual Workflow Timeline Tracker
                    _buildVisualTimeline(),
                    const SizedBox(height: 20),

                    // Stage 1: Application
                    _buildStageCard(
                      title: '1. Application',
                      icon: Icons.assignment_outlined,
                      color: Colors.indigo,
                      isUnlocked: stageStates[WorkflowStage.application]!.isUnlocked,
                      lockReason: stageStates[WorkflowStage.application]!.lockReason,
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
                      isUnlocked: stageStates[WorkflowStage.agreement]!.isUnlocked,
                      lockReason: stageStates[WorkflowStage.agreement]!.lockReason,
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
                                onChanged: (_isSaving || !stageStates[WorkflowStage.agreement]!.isUnlocked) ? null : (val) => _updateWorkflowField(agreementStatus: val),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 14),

                    // Stage 3: Loan Decision
                    _buildStageCard(
                      title: '3. Loan Decision & Sub-Stages',
                      icon: Icons.account_balance_rounded,
                      color: const Color(0xFFD97706),
                      isUnlocked: stageStates[WorkflowStage.loan]!.isUnlocked,
                      lockReason: stageStates[WorkflowStage.loan]!.lockReason,
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
                                onChanged: (_isSaving || !stageStates[WorkflowStage.loan]!.isUnlocked) ? null : (val) {
                                  final newLoanStatus = val == 'Yes' ? 'Pending' : 'Not Required';
                                  _updateWorkflowField(loanRequired: val, loanStatus: newLoanStatus);
                                },
                              ),
                            ],
                          ),
                          if (_record.loanRequired.toLowerCase() == 'yes') ...[
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                const Text('Loan Sub-Stage: ', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey)),
                                const SizedBox(width: 8),
                                DropdownButton<String>(
                                  value: _safeValue(_record.loanSubStage, const [
                                    'Loan Applied',
                                    'Loan File Ready',
                                    'File at Bank',
                                    'Loan Rejected',
                                    'Correction Required',
                                    'Re-Apply Loan',
                                    'Loan Approved',
                                    '1st Installment',
                                    '2nd Installment',
                                    'Loan Completed',
                                  ]),
                                  isDense: true,
                                  items: const [
                                    DropdownMenuItem(value: 'Loan Applied', child: Text('1. Loan Applied')),
                                    DropdownMenuItem(value: 'Loan File Ready', child: Text('2. Loan File Ready')),
                                    DropdownMenuItem(value: 'File at Bank', child: Text('3. File at Bank')),
                                    DropdownMenuItem(value: 'Loan Rejected', child: Text('🔴 4. Loan Rejected')),
                                    DropdownMenuItem(value: 'Correction Required', child: Text('🟠 5. Correction Required')),
                                    DropdownMenuItem(value: 'Re-Apply Loan', child: Text('🔵 6. Re-Apply Loan')),
                                    DropdownMenuItem(value: 'Loan Approved', child: Text('🟢 7. Loan Approved')),
                                    DropdownMenuItem(value: '1st Installment', child: Text('8. 1st Installment')),
                                    DropdownMenuItem(value: '2nd Installment', child: Text('9. 2nd Installment')),
                                    DropdownMenuItem(value: 'Loan Completed', child: Text('✅ 10. Loan Completed')),
                                  ],
                                  onChanged: (_isSaving || !stageStates[WorkflowStage.loan]!.isUnlocked)
                                      ? null
                                      : (val) {
                                          if (val == 'Loan Rejected') {
                                            _showMarkLoanRejectedDialog();
                                          } else {
                                            _updateWorkflowField(loanSubStage: val, loanStatus: val);
                                          }
                                        },
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            _buildDetailRow('Re-Apply Count', '${_record.loanReapplyCount} Re-Applications'),

                            // Rejection Details Box
                            if (_record.rejectionReason != null && _record.rejectionReason!.isNotEmpty) ...[
                              const SizedBox(height: 10),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFEF2F2),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: const Color(0xFFFCA5A5)),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Row(
                                      children: [
                                        Icon(Icons.warning_amber_rounded, color: Color(0xFFDC2626), size: 18),
                                        SizedBox(width: 6),
                                        Text('Bank Rejection Details', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFDC2626))),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Text('Reason: ${_record.rejectionReason}', style: const TextStyle(fontSize: 13)),
                                    if (_record.bankRemarks != null) Text('Remarks: ${_record.bankRemarks}', style: const TextStyle(fontSize: 13)),
                                    if (_record.correctionRequired != null) Text('Correction: ${_record.correctionRequired}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                                    if (_record.rejectionDate != null) Text('Rejected Date: ${_formatDate(_record.rejectionDate)}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                  ],
                                ),
                              ),
                            ],

                            const SizedBox(height: 12),
                            Row(
                              children: [
                                FilledButton.icon(
                                  onPressed: _isSaving ? null : _handleReapplyLoan,
                                  style: FilledButton.styleFrom(
                                    backgroundColor: const Color(0xFF2563EB),
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                  ),
                                  icon: const Icon(Icons.replay_rounded, size: 18),
                                  label: const Text('RE-APPLY LOAN', style: TextStyle(fontWeight: FontWeight.bold)),
                                ),
                                const SizedBox(width: 12),
                                OutlinedButton.icon(
                                  onPressed: _isSaving ? null : _showMarkLoanRejectedDialog,
                                  style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFFDC2626)),
                                  icon: const Icon(Icons.gavel_rounded, size: 18),
                                  label: const Text('Mark Loan Rejected'),
                                ),
                              ],
                            ),

                            // Loan Attempt History Timeline
                            if (_record.loanAttempts.isNotEmpty) ...[
                              const SizedBox(height: 16),
                              const Text('Loan Attempt History:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                              const SizedBox(height: 8),
                              Column(
                                children: _record.loanAttempts.map((attempt) {
                                  final num = attempt['attempt_number'] ?? 1;
                                  final date = attempt['reapply_date'] != null ? attempt['reapply_date'].toString().split('T')[0] : '—';
                                  final prevReason = attempt['previous_rejection_reason'] ?? 'Initial Application';
                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 6),
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade50,
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: Colors.grey.shade300),
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: Colors.blue.shade100,
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text('Attempt #$num', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.blue)),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Text('Date: $date • Prev Issue: $prevReason', style: const TextStyle(fontSize: 12)),
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                              ),
                            ],

                            if (!_record.isLoanSatisfied)
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Text(
                                  '⚠️ Note: Installation stage remains LOCKED until 2nd Installment is completed.',
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
                      isUnlocked: stageStates[WorkflowStage.installation]!.isUnlocked,
                      lockReason: stageStates[WorkflowStage.installation]!.lockReason,
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
                                onChanged: (_isSaving || !stageStates[WorkflowStage.installation]!.isUnlocked) ? null : (val) => _updateWorkflowField(installationStatus: val),
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
                      isUnlocked: stageStates[WorkflowStage.rts]!.isUnlocked,
                      lockReason: stageStates[WorkflowStage.rts]!.lockReason,
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
                                onChanged: (_isSaving || !stageStates[WorkflowStage.rts]!.isUnlocked) ? null : (val) => _updateWorkflowField(rtsStatus: val),
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
                      isUnlocked: stageStates[WorkflowStage.subsidy]!.isUnlocked,
                      lockReason: stageStates[WorkflowStage.subsidy]!.lockReason,
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
                                onChanged: (_isSaving || !stageStates[WorkflowStage.subsidy]!.isUnlocked) ? null : (val) => _updateWorkflowField(subsidyStatus: val),
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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (_record.customerWorkState.toUpperCase() == 'COMPLETED' || _record.isNoActionRequired)
                  OutlinedButton.icon(
                    onPressed: _isSaving ? null : _handleReopen,
                    icon: const Icon(Icons.refresh, size: 18),
                    label: const Text('Reopen Customer'),
                  )
                else
                  Wrap(
                    spacing: 8,
                    children: [
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFD97706),
                          side: const BorderSide(color: Color(0xFFD97706)),
                        ),
                        onPressed: _isSaving ? null : _handleMarkAsNoActionRequired,
                        icon: const Icon(Icons.pause_circle_outline, size: 18),
                        label: const Text('Mark as No Action Required'),
                      ),
                      FilledButton.icon(
                        style: FilledButton.styleFrom(backgroundColor: const Color(0xFF059669)),
                        onPressed: _isSaving ? null : _handleMarkAsComplete,
                        icon: const Icon(Icons.check_circle_outline, size: 18),
                        label: const Text('Mark as Complete'),
                      ),
                    ],
                  ),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Done'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVisualTimeline() {
    final states = WorkflowEngine.getStageStates(_record, isOwnerOverride: _isOwnerOverride);
    final stageList = [
      states[WorkflowStage.application]!,
      states[WorkflowStage.agreement]!,
      states[WorkflowStage.loan]!,
      states[WorkflowStage.installation]!,
      states[WorkflowStage.rts]!,
      states[WorkflowStage.subsidy]!,
      states[WorkflowStage.completed]!,
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Current Stage: ${WorkflowEngine.getCurrentWorkStage(_record).toUpperCase()}',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
              ),
              InkWell(
                onTap: _toggleOwnerOverride,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: _isOwnerOverride ? Colors.amber.shade100 : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: _isOwnerOverride ? Colors.amber.shade800 : Colors.grey.shade300),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _isOwnerOverride ? Icons.lock_open_rounded : Icons.lock_outline_rounded,
                        size: 13,
                        color: _isOwnerOverride ? Colors.amber.shade900 : Colors.grey.shade700,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _isOwnerOverride ? 'Override ACTIVE' : 'Owner Override',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: _isOwnerOverride ? Colors.amber.shade900 : Colors.grey.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: stageList.map((info) {
                IconData icon;
                Color color;

                switch (info.state) {
                  case StageState.completed:
                    icon = Icons.check_circle_rounded;
                    color = const Color(0xFF059669);
                    break;
                  case StageState.active:
                    icon = Icons.arrow_circle_right_rounded;
                    color = const Color(0xFF2563EB);
                    break;
                  case StageState.skipped:
                    icon = Icons.remove_circle_outline_rounded;
                    color = Colors.grey.shade500;
                    break;
                  case StageState.locked:
                    icon = Icons.lock_clock_rounded;
                    color = Colors.grey.shade400;
                    break;
                }

                return Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: Row(
                    children: [
                      Icon(icon, size: 16, color: color),
                      const SizedBox(width: 4),
                      Text(
                        info.label,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: info.state == StageState.active || info.state == StageState.completed
                              ? FontWeight.bold
                              : FontWeight.normal,
                          color: color,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStageCard({
    required String title,
    required IconData icon,
    required Color color,
    required Widget content,
    bool isUnlocked = true,
    String lockReason = '',
  }) {
    final effectiveColor = isUnlocked ? color : Colors.grey.shade500;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isUnlocked ? Colors.white : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: effectiveColor.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(isUnlocked ? icon : Icons.lock_outline_rounded, size: 18, color: effectiveColor),
              const SizedBox(width: 8),
              Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: effectiveColor)),
              if (!isUnlocked) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    lockReason.isNotEmpty ? lockReason : '🔒 Locked',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey.shade700),
                  ),
                ),
              ],
            ],
          ),
          const Divider(height: 16),
          AbsorbPointer(
            absorbing: !isUnlocked,
            child: Opacity(
              opacity: isUnlocked ? 1.0 : 0.6,
              child: content,
            ),
          ),
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
