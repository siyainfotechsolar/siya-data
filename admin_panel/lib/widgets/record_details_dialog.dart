import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/consumer_record.dart';
import '../models/customer_issue.dart';
import '../models/customer_payment.dart';
import '../services/record_service.dart';
import '../services/workflow_engine.dart';
import 'hold_reason_dialog.dart';
import 'followup_dialog.dart';
import 'followup_done_dialog.dart';
import 'misc_action_dialog.dart';
import 'issue_dialog.dart';
import 'payment_dialog.dart';
import 'global_whatsapp_button.dart';

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

  List<PaymentTransaction> _transactions = [];
  List<CustomerIssue> _issues = [];
  bool _isLoadingPayments = false;
  bool _isLoadingIssues = false;

  @override
  void initState() {
    super.initState();
    _record = widget.record;
    _loadPayments();
    _loadIssues();
  }

  Future<void> _loadPayments() async {
    if (_record.id == null) return;
    setState(() => _isLoadingPayments = true);
    try {
      final txs = await RecordService.fetchPaymentTransactions(_record.id!);
      if (mounted) {
        setState(() {
          _transactions = txs;
          _isLoadingPayments = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingPayments = false);
    }
  }

  Future<void> _loadIssues() async {
    if (_record.id == null) return;
    setState(() => _isLoadingIssues = true);
    try {
      final issues = await RecordService.fetchCustomerIssues(_record.id!);
      if (mounted) {
        setState(() {
          _issues = issues;
          _isLoadingIssues = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingIssues = false);
    }
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

  Future<void> _handleMarkAsHold() async {
    final result = await HoldReasonDialog.show(context, customerName: _record.name);
    if (result != null && _record.id != null && mounted) {
      setState(() => _isSaving = true);
      try {
        final updated = await RecordService.markCustomerAsHold(
          recordId: _record.id!,
          reason: result.reason,
          remarks: result.remarks,
          expectedFollowupDate: result.expectedFollowupDate,
        );
        if (mounted) {
          setState(() {
            _record = updated;
            _isSaving = false;
          });
          widget.onRecordUpdated?.call();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Customer marked as On Hold (${result.reason})!'),
              backgroundColor: const Color(0xFFD97706),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isSaving = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to update hold state: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  Future<void> _handleMarkFollowup() async {
    final result = await FollowupDialog.show(
      context,
      customerName: _record.name,
      initialDate: _record.followupDate,
      initialReason: _record.followupReason,
    );
    if (result != null && _record.id != null && mounted) {
      setState(() => _isSaving = true);
      try {
        final updated = await RecordService.markCustomerFollowup(
          recordId: _record.id!,
          followupDate: result.followupDate,
          followupReason: result.followupReason,
          remarks: result.remarks,
        );
        if (mounted) {
          setState(() {
            _record = updated;
            _isSaving = false;
          });
          widget.onRecordUpdated?.call();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Follow-up scheduled for ${_record.name} on ${result.followupDate.toLocal().toString().split(' ')[0]}.'),
              backgroundColor: const Color(0xFF2563EB),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isSaving = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to schedule follow-up: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  Future<void> _handleFollowupDone() async {
    final result = await FollowupDoneDialog.show(
      context,
      customerName: _record.name,
    );
    if (result != null && _record.id != null && mounted) {
      setState(() => _isSaving = true);
      try {
        final updated = await RecordService.completeCustomerFollowup(
          recordId: _record.id!,
          followupResult: result.followupResult,
          remarks: result.remarks,
          nextFollowupDate: result.nextFollowupDate,
        );
        if (mounted) {
          setState(() {
            _record = updated;
            _isSaving = false;
          });
          widget.onRecordUpdated?.call();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Follow-up outcome recorded successfully!'),
              backgroundColor: Color(0xFF059669),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isSaving = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to record follow-up: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  Future<void> _makePhoneCall(String? mobile) async {
    if (mobile == null || mobile.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No phone number available for this customer.'), backgroundColor: Colors.orange),
      );
      return;
    }
    final uri = Uri.parse('tel:${mobile.trim()}');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not launch dialer for $mobile'), backgroundColor: Colors.red),
        );
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

  Future<void> _showEditNameDialog() async {
    final nameCtrl = TextEditingController(text: _record.name);
    final formKey = GlobalKey<FormState>();

    final updatedName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.edit_note_rounded, color: Colors.blue),
            SizedBox(width: 8),
            Text('Edit Customer Name'),
          ],
        ),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Consumer No: ${_record.consumerNo}',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: nameCtrl,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Customer Name *',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Customer Name cannot be empty';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(ctx, nameCtrl.text.trim());
              }
            },
            child: const Text('Save Name'),
          ),
        ],
      ),
    );

    if (updatedName != null && updatedName != _record.name && _record.id != null && mounted) {
      setState(() => _isSaving = true);
      try {
        final updated = await RecordService.updateCustomerName(
          recordId: _record.id!,
          newName: updatedName,
        );
        if (mounted) {
          setState(() {
            _record = updated;
            _isSaving = false;
          });
          widget.onRecordUpdated?.call();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Customer Name updated to "$updatedName" successfully!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isSaving = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to update name: $e'), backgroundColor: Colors.red),
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
                        Row(
                          children: [
                            Text(
                              _record.name,
                              style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(width: 6),
                            IconButton(
                              icon: const Icon(Icons.edit_outlined, size: 18),
                              tooltip: 'Edit Customer Name',
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              onPressed: _showEditNameDialog,
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            Text(
                              'Consumer No: ${_record.consumerNo} • Stage: ${_record.overallStage}',
                              style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 13),
                            ),
                            if (_record.consumerNo.isNotEmpty) ...[
                              const SizedBox(width: 4),
                              InkWell(
                                onTap: () => _copyToClipboard(_record.consumerNo, 'Consumer No'),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                  child: Icon(Icons.copy_rounded, size: 14, color: theme.colorScheme.primary),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    GlobalWhatsAppButton.outlined(
                      phoneNumber: _record.mobile,
                      customerName: _record.name,
                      consumerNo: _record.consumerNo,
                      currentStage: _record.overallStage,
                      label: 'WhatsApp',
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
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
                    if (_record.hasActiveFollowup && _record.followupDate != null)
                      Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: _record.isFollowupOverdue
                              ? const Color(0xFFFEE2E2)
                              : (_record.isFollowupToday ? const Color(0xFFE0F2FE) : const Color(0xFFEEF2FF)),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: _record.isFollowupOverdue
                                ? const Color(0xFFDC2626)
                                : (_record.isFollowupToday ? const Color(0xFF0284C7) : const Color(0xFF6366F1)),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              _record.isFollowupOverdue
                                  ? Icons.warning_amber_rounded
                                  : (_record.isFollowupToday ? Icons.phone_in_talk_rounded : Icons.calendar_today_rounded),
                              color: _record.isFollowupOverdue
                                  ? const Color(0xFFDC2626)
                                  : (_record.isFollowupToday ? const Color(0xFF0284C7) : const Color(0xFF4F46E5)),
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'SCHEDULED FOLLOW-UP: ' +
                                        (_record.isFollowupOverdue ? 'OVERDUE' : (_record.isFollowupToday ? 'TODAY' : 'UPCOMING')),
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                      color: _record.isFollowupOverdue
                                          ? const Color(0xFF991B1B)
                                          : (_record.isFollowupToday ? const Color(0xFF0369A1) : const Color(0xFF3730A3)),
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Date: ${_record.followupDate!.toLocal().toString().split(' ')[0]} • Reason: ${_record.followupReason ?? 'General'}' +
                                        (_record.followupRemarks != null && _record.followupRemarks!.isNotEmpty
                                            ? ' • Remarks: ${_record.followupRemarks}'
                                            : ''),
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: _record.isFollowupOverdue
                                          ? const Color(0xFFB91C1C)
                                          : (_record.isFollowupToday ? const Color(0xFF0284C7) : const Color(0xFF4338CA)),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton.filledTonal(
                              icon: const Icon(Icons.phone, size: 16, color: Color(0xFF0284C7)),
                              tooltip: 'Call Customer: ${_record.mobile ?? 'No phone'}',
                              onPressed: () => _makePhoneCall(_record.mobile),
                            ),
                            const SizedBox(width: 6),
                            FilledButton.tonalIcon(
                              icon: const Icon(Icons.done_all_rounded, size: 14, color: Color(0xFF059669)),
                              label: const Text('Follow-up Done', style: TextStyle(fontSize: 12, color: Color(0xFF065F46), fontWeight: FontWeight.bold)),
                              style: FilledButton.styleFrom(backgroundColor: const Color(0xFFD1FAE5)),
                              onPressed: _isSaving ? null : _handleFollowupDone,
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

                    const SizedBox(height: 14),
                    // Module 7: Payment & Balance Tracking
                    _buildPaymentCard(),

                    const SizedBox(height: 14),
                    // Module 6: General Issues & Complaints
                    _buildIssuesCard(),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_record.isHold) ...[
                          FilledButton.icon(
                            style: FilledButton.styleFrom(backgroundColor: const Color(0xFF2563EB)),
                            onPressed: _isSaving ? null : _handleReopen,
                            icon: const Icon(Icons.refresh, size: 18),
                            label: const Text('Reopen Customer'),
                          ),
                          const SizedBox(width: 8),
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF2563EB),
                              side: const BorderSide(color: Color(0xFF2563EB)),
                            ),
                            onPressed: _isSaving ? null : _handleMarkFollowup,
                            icon: const Icon(Icons.phone_in_talk_rounded, size: 18),
                            label: const Text('Mark Follow-up'),
                          ),
                          const SizedBox(width: 8),
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF6366F1),
                              side: const BorderSide(color: Color(0xFF6366F1)),
                            ),
                            onPressed: _isSaving
                                ? null
                                : () async {
                                    final res = await MiscActionDialog.show(context, customerRecord: _record);
                                    if (res == true) {
                                      widget.onRecordUpdated?.call();
                                    }
                                  },
                            icon: const Icon(Icons.add_task_rounded, size: 18),
                            label: const Text('Add MISC'),
                          ),
                        ] else if (_record.isCompletedState) ...[
                          OutlinedButton.icon(
                            onPressed: _isSaving ? null : _handleReopen,
                            icon: const Icon(Icons.refresh, size: 18),
                            label: const Text('Reopen Customer'),
                          ),
                          const SizedBox(width: 8),
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF6366F1),
                              side: const BorderSide(color: Color(0xFF6366F1)),
                            ),
                            onPressed: _isSaving
                                ? null
                                : () async {
                                    final res = await MiscActionDialog.show(context, customerRecord: _record);
                                    if (res == true) {
                                      widget.onRecordUpdated?.call();
                                    }
                                  },
                            icon: const Icon(Icons.add_task_rounded, size: 18),
                            label: const Text('Add MISC'),
                          ),
                        ] else ...[
                          // 1. [✓ Mark Complete]
                          FilledButton.icon(
                            style: FilledButton.styleFrom(backgroundColor: const Color(0xFF059669)),
                            onPressed: _isSaving ? null : _handleMarkAsComplete,
                            icon: const Icon(Icons.check_circle_outline, size: 18),
                            label: const Text('Mark Complete'),
                          ),
                          const SizedBox(width: 8),
                          // 2. [⏸ Mark Hold]
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFFD97706),
                              side: const BorderSide(color: Color(0xFFD97706)),
                            ),
                            onPressed: _isSaving ? null : _handleMarkAsHold,
                            icon: const Icon(Icons.pause_circle_outline, size: 18),
                            label: const Text('Mark Hold'),
                          ),
                          const SizedBox(width: 8),
                          // 3. [📞 Mark Follow-up]
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF2563EB),
                              side: const BorderSide(color: Color(0xFF2563EB)),
                            ),
                            onPressed: _isSaving ? null : _handleMarkFollowup,
                            icon: const Icon(Icons.phone_in_talk_rounded, size: 18),
                            label: const Text('Mark Follow-up'),
                          ),
                          const SizedBox(width: 8),
                          // 4. [More Actions ⋮]
                          PopupMenuButton<String>(
                            tooltip: 'More Actions',
                            onSelected: (val) async {
                              if (val == 'misc') {
                                final res = await MiscActionDialog.show(context, customerRecord: _record);
                                if (res == true) widget.onRecordUpdated?.call();
                              } else if (val == 'payment') {
                                final res = await PaymentDialog.show(context, customerRecord: _record);
                                if (res == true) {
                                  _loadPayments();
                                  final updated = await RecordService.fetchRecordById(_record.id!);
                                  if (updated != null && mounted) setState(() => _record = updated);
                                  widget.onRecordUpdated?.call();
                                }
                              } else if (val == 'issue') {
                                final res = await IssueDialog.show(context, customerRecord: _record);
                                if (res == true) _loadIssues();
                              } else if (val == 'whatsapp') {
                                GlobalWhatsAppButton.openChat(
                                  context,
                                  phoneNumber: _record.mobile,
                                  customerName: _record.name,
                                  consumerNo: _record.consumerNo,
                                  currentStage: _record.overallStage,
                                );
                              } else if (val == 'call' && _record.mobile != null) {
                                _makePhoneCall(_record.mobile);
                              } else if (val == 'followup_done') {
                                _handleFollowupDone();
                              }
                            },
                            itemBuilder: (ctx) => [
                              const PopupMenuItem(
                                value: 'whatsapp',
                                child: Row(
                                  children: [
                                    Icon(Icons.chat_rounded, size: 18, color: Color(0xFF25D366)),
                                    SizedBox(width: 10),
                                    Text('WhatsApp Message'),
                                  ],
                                ),
                              ),
                              const PopupMenuItem(
                                value: 'misc',
                                child: Row(
                                  children: [
                                    Icon(Icons.add_task_rounded, size: 18, color: Color(0xFF6366F1)),
                                    SizedBox(width: 10),
                                    Text('Add MISC Action'),
                                  ],
                                ),
                              ),
                              const PopupMenuItem(
                                value: 'payment',
                                child: Row(
                                  children: [
                                    Icon(Icons.payments_outlined, size: 18, color: Color(0xFF059669)),
                                    SizedBox(width: 10),
                                    Text('Record Payment'),
                                  ],
                                ),
                              ),
                              const PopupMenuItem(
                                value: 'issue',
                                child: Row(
                                  children: [
                                    Icon(Icons.report_problem_outlined, size: 18, color: Color(0xFFDC2626)),
                                    SizedBox(width: 10),
                                    Text('Report Issue / Complaint'),
                                  ],
                                ),
                              ),
                              if (_record.hasActiveFollowup) ...[
                                const PopupMenuDivider(),
                                if (_record.mobile != null && _record.mobile!.isNotEmpty)
                                  PopupMenuItem(
                                    value: 'call',
                                    child: Row(
                                      children: [
                                        const Icon(Icons.phone, size: 18, color: Color(0xFF0284C7)),
                                        const SizedBox(width: 10),
                                        Text('Call: ${_record.mobile}'),
                                      ],
                                    ),
                                  ),
                                const PopupMenuItem(
                                  value: 'followup_done',
                                  child: Row(
                                    children: [
                                      Icon(Icons.done_all_rounded, size: 18, color: Color(0xFF059669)),
                                      SizedBox(width: 10),
                                      Text('Mark Follow-up Done'),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: Colors.grey.shade400),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'More',
                                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black87),
                                  ),
                                  SizedBox(width: 2),
                                  Icon(Icons.more_vert, size: 18, color: Colors.black87),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
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

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label copied to clipboard!'),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {bool copyable = false}) {
    final isCopyable = copyable ||
        label.toLowerCase().contains('mobile') ||
        label.toLowerCase().contains('id') ||
        label.toLowerCase().contains('consumer');
    final canCopy = isCopyable && value.isNotEmpty && value != '—';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          SizedBox(
            width: 140,
            child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.grey, fontSize: 13)),
          ),
          Expanded(
            child: SelectableText(
              value,
              style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
            ),
          ),
          if (canCopy)
            InkWell(
              onTap: () => _copyToClipboard(value, label),
              borderRadius: BorderRadius.circular(4),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                child: Icon(Icons.copy_rounded, size: 15, color: Colors.blue.shade700),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPaymentCard() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: Colors.green.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Icon(Icons.payments_rounded, color: Color(0xFF059669), size: 20),
                    ),
                    const SizedBox(width: 8),
                    const Text('Payment & Balance Tracking', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                  ],
                ),
                FilledButton.icon(
                  style: FilledButton.styleFrom(backgroundColor: const Color(0xFF059669)),
                  onPressed: () async {
                    final res = await PaymentDialog.show(context, customerRecord: _record);
                    if (res == true) {
                      _loadPayments();
                      final updated = await RecordService.fetchRecordById(_record.id!);
                      if (updated != null && mounted) setState(() => _record = updated);
                      widget.onRecordUpdated?.call();
                    }
                  },
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Record Payment', style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.green.shade50.withOpacity(0.5),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.shade100),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Total Amount', style: TextStyle(fontSize: 11, color: Colors.black54)),
                      Text('₹${_record.totalAmount.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Paid Amount', style: TextStyle(fontSize: 11, color: Colors.black54)),
                      Text('₹${_record.paidAmount.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF059669))),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Pending Balance', style: TextStyle(fontSize: 11, color: Colors.black54)),
                      Text(
                        '₹${_record.pendingAmount.toStringAsFixed(0)}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: _record.pendingAmount > 0 ? const Color(0xFFDC2626) : const Color(0xFF059669),
                        ),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Payment Status', style: TextStyle(fontSize: 11, color: Colors.black54)),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: PaymentStatus.statusColor(_record.paymentStatus).withOpacity(0.12),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: PaymentStatus.statusColor(_record.paymentStatus).withOpacity(0.3)),
                        ),
                        child: Text(
                          _record.paymentStatus,
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: PaymentStatus.statusColor(_record.paymentStatus)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (_isLoadingPayments)
              const Padding(
                padding: EdgeInsets.all(12),
                child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))),
              )
            else if (_transactions.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Center(child: Text('No payment transactions recorded yet.', style: TextStyle(fontSize: 12, color: Colors.grey))),
              )
            else ...[
              const SizedBox(height: 12),
              const Text('Transaction History:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Table(
                  border: TableBorder.all(color: Colors.grey.shade200),
                  columnWidths: const {
                    0: FlexColumnWidth(2),
                    1: FlexColumnWidth(2),
                    2: FlexColumnWidth(2),
                    3: FlexColumnWidth(3),
                    4: FlexColumnWidth(2),
                    5: FlexColumnWidth(2),
                  },
                  children: [
                    TableRow(
                      decoration: BoxDecoration(color: Colors.grey.shade100),
                      children: const [
                        Padding(padding: EdgeInsets.all(6), child: Text('Date', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                        Padding(padding: EdgeInsets.all(6), child: Text('Amount', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                        Padding(padding: EdgeInsets.all(6), child: Text('Mode', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                        Padding(padding: EdgeInsets.all(6), child: Text('Ref / UTR', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                        Padding(padding: EdgeInsets.all(6), child: Text('Status', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                        Padding(padding: EdgeInsets.all(6), child: Text('Action', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                      ],
                    ),
                    ..._transactions.map((tx) {
                      return TableRow(
                        children: [
                          Padding(padding: const EdgeInsets.all(6), child: Text(tx.paymentDate.toIso8601String().split('T')[0], style: const TextStyle(fontSize: 11))),
                          Padding(padding: const EdgeInsets.all(6), child: Text('₹${tx.amount.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                          Padding(padding: const EdgeInsets.all(6), child: Text(tx.paymentMode, style: const TextStyle(fontSize: 11))),
                          Padding(padding: const EdgeInsets.all(6), child: Text(tx.referenceNumber ?? '—', style: const TextStyle(fontSize: 11))),
                          Padding(
                            padding: const EdgeInsets.all(6),
                            child: Text(
                              tx.status,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: tx.isValid ? const Color(0xFF059669) : const Color(0xFFDC2626),
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(4),
                            child: tx.isValid
                                ? InkWell(
                                    onTap: () => _confirmReversePayment(tx),
                                    child: const Text('Reverse', style: TextStyle(fontSize: 11, color: Color(0xFFDC2626), decoration: TextDecoration.underline)),
                                  )
                                : const Text('—', style: TextStyle(fontSize: 11)),
                          ),
                        ],
                      );
                    }),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildIssuesCard() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: Colors.red.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Icon(Icons.report_problem_rounded, color: Color(0xFFDC2626), size: 20),
                    ),
                    const SizedBox(width: 8),
                    const Text('General Issues & Customer Complaints', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                  ],
                ),
                FilledButton.icon(
                  style: FilledButton.styleFrom(backgroundColor: const Color(0xFFDC2626)),
                  onPressed: () async {
                    final res = await IssueDialog.show(context, customerRecord: _record);
                    if (res == true) {
                      _loadIssues();
                    }
                  },
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Report Issue', style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (_isLoadingIssues)
              const Padding(
                padding: EdgeInsets.all(12),
                child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))),
              )
            else if (_issues.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Center(child: Text('No issues reported for this customer.', style: TextStyle(fontSize: 12, color: Colors.grey))),
              )
            else
              Column(
                children: _issues.map((issue) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: issue.isActive ? const Color(0xFFFEF2F2) : Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: issue.isActive ? const Color(0xFFFECACA) : Colors.grey.shade300),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(issue.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: issue.priorityColor.withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(issue.priority, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: issue.priorityColor)),
                                  ),
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: issue.statusColor.withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(issue.status, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: issue.statusColor)),
                                  ),
                                  if (issue.isStuck) ...[
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                      decoration: BoxDecoration(
                                        color: Colors.red.shade100,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: const Text('⚠️ Stuck', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.red)),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${issue.issueType}${issue.assignedStaff != null ? " • Assigned: ${issue.assignedStaff}" : ""}${issue.dueDate != null ? " • Due: ${issue.dueDate!.toIso8601String().split('T')[0]}" : ""}',
                                style: const TextStyle(fontSize: 11, color: Colors.black54),
                              ),
                              if (issue.description != null && issue.description!.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(issue.description!, style: const TextStyle(fontSize: 11, color: Colors.black87)),
                                ),
                            ],
                          ),
                        ),
                        Row(
                          children: [
                            if (issue.isActive) ...[
                              TextButton(
                                onPressed: () => _handleResolveIssue(issue),
                                child: const Text('Resolve', style: TextStyle(fontSize: 11, color: Color(0xFF059669))),
                              ),
                            ],
                            IconButton(
                              icon: const Icon(Icons.edit_outlined, size: 16),
                              tooltip: 'Edit Issue',
                              onPressed: () async {
                                final res = await IssueDialog.show(context, existingIssue: issue);
                                if (res == true) _loadIssues();
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmReversePayment(PaymentTransaction tx) async {
    final reasonCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reverse Payment Transaction'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Are you sure you want to reverse payment of ₹${tx.amount.toStringAsFixed(0)}?'),
            const SizedBox(height: 12),
            TextField(
              controller: reasonCtrl,
              decoration: const InputDecoration(
                labelText: 'Reversal Reason *',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFDC2626)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirm Reverse'),
          ),
        ],
      ),
    );

    if (confirmed == true && tx.id != null && mounted) {
      if (reasonCtrl.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Reversal reason is required')),
        );
        return;
      }
      try {
        await RecordService.reversePaymentTransaction(
          transactionId: tx.id!,
          reason: reasonCtrl.text.trim(),
        );
        _loadPayments();
        final updated = await RecordService.fetchRecordById(_record.id!);
        if (updated != null && mounted) setState(() => _record = updated);
        widget.onRecordUpdated?.call();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
        }
      }
    }
  }

  Future<void> _handleResolveIssue(CustomerIssue issue) async {
    final remarksCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Resolve Issue'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Mark "${issue.title}" as Resolved?'),
            const SizedBox(height: 12),
            TextField(
              controller: remarksCtrl,
              decoration: const InputDecoration(
                labelText: 'Resolution Remarks *',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFF059669)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Resolve'),
          ),
        ],
      ),
    );

    if (confirmed == true && issue.id != null && mounted) {
      if (remarksCtrl.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Resolution remarks are required')),
        );
        return;
      }
      try {
        await RecordService.resolveIssue(
          issueId: issue.id!,
          resolutionRemarks: remarksCtrl.text.trim(),
        );
        _loadIssues();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
        }
      }
    }
  }
}
