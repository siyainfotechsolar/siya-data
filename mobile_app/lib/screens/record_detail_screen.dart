import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/consumer_record.dart';
import '../services/record_service.dart';
import '../services/workflow_engine.dart';

class RecordDetailScreen extends StatefulWidget {
  final ConsumerRecord record;

  RecordDetailScreen({
    super.key,
    ConsumerRecord? record,
    ConsumerRecord? initialRecord,
  }) : record = (record ?? initialRecord)!;

  @override
  State<RecordDetailScreen> createState() => _RecordDetailScreenState();
}

class _RecordDetailScreenState extends State<RecordDetailScreen> {
  late ConsumerRecord _record;
  bool _hasChanged = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _record = widget.record;
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
      try {
        final updated = await MobileRecordService.markCustomerAsComplete(_record.id!);
        if (mounted) {
          setState(() {
            _record = updated;
            _hasChanged = true;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Customer marked as complete! Removed from Priority List.'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to mark complete: $e'), backgroundColor: Colors.red),
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
      try {
        final updated = await MobileRecordService.reopenCustomer(_record.id!);
        if (mounted) {
          setState(() {
            _record = updated;
            _hasChanged = true;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Customer reopened and returned to active workflow!'),
              backgroundColor: Colors.blue,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to reopen customer: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  String _safeValue(String value, List<String> allowed) {
    if (allowed.contains(value)) return value;
    return allowed.first;
  }

  void _showMarkLoanRejectedSheet() {
    final reasonCtrl = TextEditingController();
    final remarksCtrl = TextEditingController();
    final correctionCtrl = TextEditingController();
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
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Mark Loan Rejected',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFFDC2626)),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.of(ctx).pop(),
                        ),
                      ],
                    ),
                    const Divider(height: 20),
                    TextField(
                      controller: reasonCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Rejection Reason *',
                        hintText: 'e.g. Bank document issue, Low CIBIL score',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: remarksCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Bank Remarks',
                        hintText: 'Additional comments from bank manager',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: correctionCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Correction Required *',
                        hintText: 'e.g. Upload corrected IT Return document',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 20),
                    FilledButton(
                      style: FilledButton.styleFrom(backgroundColor: const Color(0xFFDC2626)),
                      onPressed: isSaving
                          ? null
                          : () async {
                              if (reasonCtrl.text.trim().isEmpty || correctionCtrl.text.trim().isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Reason and Correction Required are mandatory'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                                return;
                              }
                              setSheetState(() => isSaving = true);
                              try {
                                final updated = await MobileRecordService.markLoanRejected(
                                  recordId: _record.id!,
                                  rejectionReason: reasonCtrl.text.trim(),
                                  bankRemarks: remarksCtrl.text.trim().isEmpty ? null : remarksCtrl.text.trim(),
                                  correctionRequired: correctionCtrl.text.trim(),
                                );
                                if (mounted) {
                                  setState(() {
                                    _record = updated;
                                    _hasChanged = true;
                                  });
                                  Navigator.of(ctx).pop();
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Loan marked as Rejected. Stage set to Correction Required.'),
                                      backgroundColor: Colors.orange,
                                    ),
                                  );
                                }
                              } catch (e) {
                                setSheetState(() => isSaving = false);
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                                  );
                                }
                              }
                            },
                      child: isSaving
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Text('Confirm Loan Rejection', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _handleReapplyLoan() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Re-Apply Loan?'),
        content: Text('This will increment re-apply count to ${_record.loanReapplyCount + 1} and reset Loan Sub-Stage to "Loan Applied". History will be preserved.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Re-Apply Loan')),
        ],
      ),
    );

    if (confirmed == true && _record.id != null && mounted) {
      try {
        final updated = await MobileRecordService.reapplyLoan(currentRecord: _record);
        if (mounted) {
          setState(() {
            _record = updated;
            _hasChanged = true;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Loan Re-Applied! Attempt #${updated.loanReapplyCount} created.'),
              backgroundColor: Colors.blue,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to re-apply: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  void _showWorkflowUpdateSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        String selectedAppStatus = _record.applicationStatus;
        String selectedAgreeStatus = _record.agreementStatus;
        String selectedLoanReq = _record.loanRequired;
        String selectedLoanStatus = _record.loanStatus;
        String selectedInstallStatus = _record.installationStatus;
        String selectedRtsStatus = _record.rtsStatus;
        String selectedSubsidyStatus = _record.subsidyStatus;
        final remarksController = TextEditingController(text: _record.remarks ?? '');
        bool isSaving = false;

        return StatefulBuilder(
          builder: (context, setSheetState) {
            final stageStates = WorkflowEngine.getStageStates(_record);

            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Update Workflow Stages',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.of(ctx).pop(),
                        ),
                      ],
                    ),
                    const Divider(height: 20),

                    // Stage 1: Application
                    _buildSheetDropdown(
                      label: '1. Application Status',
                      value: selectedAppStatus,
                      items: const ['Submitted', 'Under Verification', 'Approved', 'Rejected'],
                      onChanged: (val) => setSheetState(() => selectedAppStatus = val!),
                      enabled: stageStates[WorkflowStage.application]!.isUnlocked,
                      lockReason: stageStates[WorkflowStage.application]!.lockReason,
                    ),

                    const SizedBox(height: 12),

                    // Stage 2: Agreement
                    _buildSheetDropdown(
                      label: '2. Agreement Status',
                      value: selectedAgreeStatus,
                      items: const ['Pending', 'Uploaded', 'Verified', 'Rejected'],
                      onChanged: (val) => setSheetState(() => selectedAgreeStatus = val!),
                      enabled: stageStates[WorkflowStage.agreement]!.isUnlocked,
                      lockReason: stageStates[WorkflowStage.agreement]!.lockReason,
                    ),

                    const SizedBox(height: 12),

                    // Stage 3: Loan Required & Status
                    Row(
                      children: [
                        Expanded(
                          child: _buildSheetDropdown(
                            label: '3. Loan Required?',
                            value: selectedLoanReq,
                            items: const ['No', 'Yes'],
                            onChanged: (val) {
                              setSheetState(() {
                                selectedLoanReq = val!;
                                if (val == 'Yes' && selectedLoanStatus == 'Not Required') {
                                  selectedLoanStatus = 'Pending';
                                } else if (val == 'No') {
                                  selectedLoanStatus = 'Not Required';
                                }
                              });
                            },
                            enabled: stageStates[WorkflowStage.loan]!.isUnlocked,
                            lockReason: stageStates[WorkflowStage.loan]!.lockReason,
                          ),
                        ),
                        if (selectedLoanReq == 'Yes') ...[
                          const SizedBox(width: 10),
                          Expanded(
                            child: _buildSheetDropdown(
                              label: 'Loan Sub-Stage',
                              value: _safeValue(selectedLoanStatus, const [
                                'Loan Applied',
                                'Loan File Ready',
                                'File at Bank',
                                'Loan Rejected',
                                'Correction Required',
                                'Re-Apply Loan',
                                'Loan Approved',
                                '1st Installment',
                                '2nd Installment',
                              ]),
                              items: const [
                                'Loan Applied',
                                'Loan File Ready',
                                'File at Bank',
                                'Loan Rejected',
                                'Correction Required',
                                'Re-Apply Loan',
                                'Loan Approved',
                                '1st Installment',
                                '2nd Installment',
                              ],
                              onChanged: (val) {
                                if (val == 'Loan Rejected') {
                                  Navigator.of(ctx).pop();
                                  _showMarkLoanRejectedSheet();
                                } else {
                                  setSheetState(() => selectedLoanStatus = val!);
                                }
                              },
                              enabled: stageStates[WorkflowStage.loan]!.isUnlocked,
                              lockReason: stageStates[WorkflowStage.loan]!.lockReason,
                            ),
                          ),
                        ],
                      ],
                    ),

                    const SizedBox(height: 12),

                    // Stage 4: Installation
                    _buildSheetDropdown(
                      label: '4. Installation Status',
                      value: selectedInstallStatus,
                      items: const [
                        'Not Started',
                        'Scheduled',
                        'Installation Pending',
                        'Structure Pending',
                        'Panel Pending',
                        'Wiring Pending',
                        'Installation Completed',
                      ],
                      onChanged: (val) => setSheetState(() => selectedInstallStatus = val!),
                      enabled: stageStates[WorkflowStage.installation]!.isUnlocked,
                      lockReason: stageStates[WorkflowStage.installation]!.lockReason,
                    ),

                    const SizedBox(height: 12),

                    // Stage 5: RTS
                    _buildSheetDropdown(
                      label: '5. RTS / Net Meter Status',
                      value: selectedRtsStatus,
                      items: const [
                        'Not Started',
                        'Application Pending',
                        'Applied',
                        'Meter Pending',
                        'Inspection Pending',
                        'Completed',
                        'Rejected',
                      ],
                      onChanged: (val) => setSheetState(() => selectedRtsStatus = val!),
                      enabled: stageStates[WorkflowStage.rts]!.isUnlocked,
                      lockReason: stageStates[WorkflowStage.rts]!.lockReason,
                    ),

                    const SizedBox(height: 12),

                    // Stage 6: Subsidy
                    _buildSheetDropdown(
                      label: '6. Government Subsidy Status',
                      value: selectedSubsidyStatus,
                      items: const [
                        'Not Applied',
                        'Applied',
                        'Under Process',
                        'Pending',
                        'Approved',
                        'Received',
                        'Rejected',
                      ],
                      onChanged: (val) => setSheetState(() => selectedSubsidyStatus = val!),
                      enabled: stageStates[WorkflowStage.subsidy]!.isUnlocked,
                      lockReason: stageStates[WorkflowStage.subsidy]!.lockReason,
                    ),

                    const SizedBox(height: 14),

                    TextField(
                      controller: remarksController,
                      decoration: const InputDecoration(
                        labelText: 'Remarks / Notes',
                        hintText: 'Add field updates or visit remarks',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      maxLines: 2,
                    ),

                    const SizedBox(height: 20),

                    FilledButton(
                      onPressed: isSaving
                          ? null
                          : () async {
                              if (_record.id == null) return;

                              final errors = WorkflowEngine.validateStageProgression(
                                _record,
                                newAgreementStatus: selectedAgreeStatus,
                                newLoanStatus: selectedLoanStatus,
                                newInstallationStatus: selectedInstallStatus,
                                newRtsStatus: selectedRtsStatus,
                                newSubsidyStatus: selectedSubsidyStatus,
                                newLoanRequired: selectedLoanReq,
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

                              setSheetState(() => isSaving = true);

                              try {
                                final updated = await MobileRecordService.updateWorkflowStage(
                                  record: _record,
                                  applicationStatus: selectedAppStatus,
                                  agreementStatus: selectedAgreeStatus,
                                  loanRequired: selectedLoanReq,
                                  loanStatus: selectedLoanStatus,
                                  installationStatus: selectedInstallStatus,
                                  rtsStatus: selectedRtsStatus,
                                  subsidyStatus: selectedSubsidyStatus,
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
                                      content: Text('Customer workflow updated successfully!'),
                                      backgroundColor: Colors.green,
                                    ),
                                  );
                                }
                              } catch (e) {
                                setSheetState(() => isSaving = false);
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Failed to update: $e'),
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
                          : const Text('Save Workflow Update', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSheetDropdown({
    required String label,
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
    bool enabled = true,
    String lockReason = '',
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: enabled ? Colors.black87 : Colors.grey.shade600,
              ),
            ),
            if (!enabled && lockReason.isNotEmpty)
              Text(
                lockReason,
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey.shade700),
              ),
          ],
        ),
        const SizedBox(height: 4),
        DropdownButtonFormField<String>(
          value: items.contains(value) ? value : items.first,
          decoration: InputDecoration(
            border: const OutlineInputBorder(),
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            filled: !enabled,
            fillColor: !enabled ? Colors.grey.shade100 : Colors.white,
          ),
          items: items.map((i) => DropdownMenuItem(value: i, child: Text(i, style: const TextStyle(fontSize: 13)))).toList(),
          onChanged: enabled ? onChanged : null,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {},
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
                        radius: 30,
                        backgroundColor: theme.colorScheme.primaryContainer,
                        child: Icon(Icons.solar_power_rounded, size: 34, color: theme.colorScheme.primary),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        _record.name,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 6),
                      InkWell(
                        onTap: () {
                          Clipboard.setData(ClipboardData(text: _record.consumerNo));
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Consumer No. ${_record.consumerNo} copied to clipboard'),
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        },
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Consumer No: ${_record.consumerNo}',
                                style: TextStyle(fontWeight: FontWeight.bold, color: theme.colorScheme.onSurfaceVariant),
                              ),
                              const SizedBox(width: 6),
                              Icon(
                                Icons.copy_rounded,
                                size: 14,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      // Overall Stage Badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xFF2563EB)),
                        ),
                        child: Text(
                          'Stage: ${_record.overallStage}',
                          style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E40AF), fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Vertical Workflow Stepper Card
              Card(
                elevation: 1,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Workflow Progress', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                          Text('${_record.applicationDays} days elapsed', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                        ],
                      ),
                      const Divider(height: 20),

                      _buildTimelineItem(
                        step: '1. Application',
                        status: _record.applicationStatus,
                        isDone: true,
                      ),
                      _buildTimelineItem(
                        step: '2. Agreement',
                        status: _record.agreementStatus,
                        isDone: _record.agreementStatus.toLowerCase() == 'verified',
                      ),
                      _buildTimelineItem(
                        step: '3. Loan (${_record.loanRequired == 'Yes' ? 'Bank' : 'Self/Cash'})',
                        status: _record.loanRequired == 'Yes' ? _record.loanStatus : 'Not Required',
                        isDone: _record.isLoanSatisfied,
                      ),
                      _buildTimelineItem(
                        step: '4. Installation',
                        status: _record.installationStatus,
                        isDone: _record.installationStatus.toLowerCase() == 'installation completed',
                      ),
                      _buildTimelineItem(
                        step: '5. RTS / Net Meter',
                        status: _record.rtsStatus,
                        isDone: _record.rtsStatus.toLowerCase() == 'completed',
                      ),
                      _buildTimelineItem(
                        step: '6. Subsidy',
                        status: _record.subsidyStatus,
                        isDone: _record.isFullyCompleted,
                        isLast: true,
                      ),
                    ],
                  ),
                ),
              ),

              if (_record.loanRequired.toLowerCase() == 'yes') ...[
                const SizedBox(height: 16),
                Card(
                  elevation: 1,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Loan Workflow & History', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                            Chip(
                              label: Text('Re-Apply Count: ${_record.loanReapplyCount}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                              backgroundColor: Colors.blue.shade50,
                              side: BorderSide(color: Colors.blue.shade200),
                              padding: EdgeInsets.zero,
                              visualDensity: VisualDensity.compact,
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text('Sub-Stage: ${_record.loanSubStage}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF1E40AF))),
                        const Divider(height: 20),

                        // Rejection Details if present
                        if (_record.rejectionReason != null && _record.rejectionReason!.isNotEmpty) ...[
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEF2F2),
                              borderRadius: BorderRadius.circular(10),
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
                                if (_record.correctionRequired != null) Text('Correction: ${_record.correctionRequired}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF991B1B))),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),
                        ],

                        // Action Buttons
                        Row(
                          children: [
                            Expanded(
                              child: FilledButton.icon(
                                onPressed: _isSaving ? null : _handleReapplyLoan,
                                style: FilledButton.styleFrom(
                                  backgroundColor: const Color(0xFF2563EB),
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                ),
                                icon: const Icon(Icons.replay_rounded, size: 18),
                                label: const Text('RE-APPLY LOAN', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: _isSaving ? null : _showMarkLoanRejectedSheet,
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: const Color(0xFFDC2626),
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                ),
                                icon: const Icon(Icons.gavel_rounded, size: 18),
                                label: const Text('Mark Rejected', style: TextStyle(fontSize: 13)),
                              ),
                            ),
                          ],
                        ),

                        // Attempt History
                        if (_record.loanAttempts.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          const Text('Loan Attempt History:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          const SizedBox(height: 8),
                          ..._record.loanAttempts.map((attempt) {
                            final num = attempt['attempt_number'] ?? 1;
                            final date = attempt['reapply_date'] != null ? attempt['reapply_date'].toString().split('T')[0] : '—';
                            final prevReason = attempt['previous_rejection_reason'] ?? 'Initial Application';
                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade50,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.grey.shade300),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text('Attempt #$num', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                      Text('Re-Applied: $date', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                                    ],
                                  ),
                                  if (prevReason.isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Text('Prior Issue: $prevReason', style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
                                  ],
                                ],
                              ),
                            );
                          }),
                        ],
                      ],
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 16),

              // Contact & Details Card
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

                      // Application Date
                      _buildInfoRow(
                        icon: Icons.calendar_month_outlined,
                        label: 'Application Date',
                        value: _record.applicationDate != null
                            ? '${_record.applicationDate!.day.toString().padLeft(2, '0')}/${_record.applicationDate!.month.toString().padLeft(2, '0')}/${_record.applicationDate!.year}'
                            : 'Not Set',
                      ),

                      // Submit Date
                      _buildInfoRow(
                        icon: Icons.edit_calendar_outlined,
                        label: 'Submit Date',
                        value: _record.submitDate != null
                            ? '${_record.submitDate!.day.toString().padLeft(2, '0')}/${_record.submitDate!.month.toString().padLeft(2, '0')}/${_record.submitDate!.year}'
                            : 'Not Set',
                      ),

                      // Action Center Info
                      _buildInfoRow(
                        icon: Icons.bolt_outlined,
                        label: 'Current Work Stage',
                        value: _record.overallStage,
                      ),
                      _buildInfoRow(
                        icon: Icons.info_outline,
                        label: 'Current Status',
                        value: _record.currentStatus,
                      ),
                      _buildInfoRow(
                        icon: Icons.check_circle_outline,
                        label: 'Action Required',
                        value: _record.actionRequired,
                      ),
                      _buildInfoRow(
                        icon: Icons.arrow_forward_outlined,
                        label: 'Next Action',
                        value: _record.nextAction,
                      ),
                      _buildInfoRow(
                        icon: Icons.timer_outlined,
                        label: 'Days in Stage',
                        value: '${_record.daysInCurrentStage} Days',
                      ),
                      _buildInfoRow(
                        icon: Icons.calendar_today_outlined,
                        label: 'Application Days',
                        value: '${_record.applicationDays} Days elapsed',
                      ),
                      if (_record.assignedStaff != null || _record.installerTeam != null)
                        _buildInfoRow(
                          icon: Icons.person_outline,
                          label: 'Assigned Staff',
                          value: _record.assignedStaff ?? _record.installerTeam!,
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
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Action Buttons
              FilledButton.icon(
                onPressed: _showWorkflowUpdateSheet,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.timeline_rounded, size: 22),
                label: const Text('Update Workflow Stage', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 12),
              if (_record.customerWorkState.toUpperCase() == 'COMPLETED')
                OutlinedButton.icon(
                  onPressed: _handleReopen,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.refresh, size: 20),
                  label: const Text('Reopen Customer', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                )
              else
                FilledButton.icon(
                  onPressed: _handleMarkAsComplete,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF059669),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.check_circle_outline, size: 20),
                  label: const Text('Mark as Complete', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTimelineItem({
    required String step,
    required String status,
    required bool isDone,
    bool isLast = false,
  }) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Icon(
                isDone ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
                size: 20,
                color: isDone ? Colors.green : Colors.grey.shade400,
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    color: isDone ? Colors.green.shade200 : Colors.grey.shade300,
                    margin: const EdgeInsets.symmetric(vertical: 2),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 12.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(step, style: TextStyle(fontWeight: isDone ? FontWeight.bold : FontWeight.w500, fontSize: 13)),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: isDone ? Colors.green.withValues(alpha: 0.1) : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      status,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: isDone ? Colors.green.shade800 : Colors.grey.shade700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
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
}
