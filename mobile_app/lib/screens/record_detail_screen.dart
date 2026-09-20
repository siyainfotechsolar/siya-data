import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import '../models/consumer_record.dart';
import '../models/customer_payment.dart';
import '../models/office_task.dart';
import '../services/record_service.dart';
import '../services/workflow_engine.dart';
import '../services/payment_service.dart';
import '../services/app_database.dart';
import '../services/app_intelligence_service.dart';
import '../services/office_task_service.dart';
import '../widgets/no_action_reason_dialog.dart';
import '../widgets/customer_timeline_widget.dart';
import '../widgets/add_payment_dialog.dart';
import '../widgets/create_office_task_bottom_sheet.dart';
import '../utils/back_navigation_helper.dart';
import 'task_details_screen.dart';

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
  List<OfficeTask> _customerTasks = [];
  bool _isLoadingCustomerTasks = true;

  @override
  void initState() {
    super.initState();
    _record = widget.record;
    _loadCustomerTasks();
  }

  Future<void> _loadCustomerTasks() async {
    if (!mounted) return;
    setState(() => _isLoadingCustomerTasks = true);
    try {
      final tasks = await MobileOfficeTaskService.fetchCustomerTasks(
        customerId: _record.id,
        consumerNo: _record.consumerNo,
      );
      if (mounted) {
        setState(() {
          _customerTasks = tasks;
          _isLoadingCustomerTasks = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading customer tasks: $e');
      if (mounted) {
        setState(() => _isLoadingCustomerTasks = false);
      }
    }
  }

  Future<void> _showEditConsumerNameDialog() async {
    final nameCtrl = TextEditingController(text: _record.name);
    final formKey = GlobalKey<FormState>();

    final updatedName = await showDialog<String>(
      context: context,
      builder: (ctx) {
        Future<void> handleCancel() async {
          if (nameCtrl.text.trim() != _record.name) {
            final discard = await BackNavigationHelper.showDiscardDialog(
              ctx,
              title: 'Discard Name Change?',
              message: 'Unsaved name change will be lost.',
            );
            if (!discard) return;
          }
          Navigator.pop(ctx);
        }

        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, result) async {
            if (didPop) return;
            await handleCancel();
          },
          child: AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                Icon(Icons.edit_note_rounded, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                const Text('Edit Consumer Name', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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
              const SizedBox(height: 14),
              TextFormField(
                controller: nameCtrl,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  labelText: 'Consumer Name *',
                  hintText: 'Enter full consumer name',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  isDense: true,
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Consumer Name cannot be empty';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: handleCancel,
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF059669),
            ),
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
      },
    );

    if (updatedName != null && updatedName != _record.name && _record.id != null && mounted) {
      setState(() => _isSaving = true);
      try {
        final updated = await MobileRecordService.updateCustomerName(
          recordId: _record.id!,
          newName: updatedName,
        );
        if (mounted) {
          setState(() {
            _record = updated;
            _hasChanged = true;
            _isSaving = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Consumer name updated to "$updatedName" successfully!'),
              backgroundColor: const Color(0xFF059669),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isSaving = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to update consumer name: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
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

  Future<void> _handleMarkAsNoAction() async {
    final result = await NoActionReasonDialog.show(
      context,
      customerName: _record.name,
    );

    if (result != null && _record.id != null && mounted) {
      try {
        final updated = await MobileRecordService.markCustomerAsNoActionRequired(
          recordId: _record.id!,
          reason: result['reason'] ?? 'Hold',
          freeTextDetails: result['details'],
        );
        if (mounted) {
          setState(() {
            _record = updated;
            _hasChanged = true;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Customer marked as Hold / No Action Required.'),
              backgroundColor: Color(0xFFD97706),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to mark as Hold: $e'), backgroundColor: Colors.red),
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

        bool hasChanges() {
          if (selectedAppStatus != _record.applicationStatus) return true;
          if (selectedAgreeStatus != _record.agreementStatus) return true;
          if (selectedLoanReq != _record.loanRequired) return true;
          if (selectedLoanStatus != _record.loanStatus) return true;
          if (selectedInstallStatus != _record.installationStatus) return true;
          if (selectedRtsStatus != _record.rtsStatus) return true;
          if (selectedSubsidyStatus != _record.subsidyStatus) return true;
          if (remarksController.text.trim() != (_record.remarks ?? '').trim()) return true;
          return false;
        }

        Future<void> handleCancel() async {
          if (isSaving) return;
          if (hasChanges()) {
            final discard = await BackNavigationHelper.showDiscardDialog(
              ctx,
              title: 'Discard Changes?',
              message: 'Unsaved workflow updates will be lost.',
            );
            if (!discard) return;
          }
          Navigator.of(ctx).pop();
        }

        return StatefulBuilder(
          builder: (context, setSheetState) {
            final stageStates = WorkflowEngine.getStageStates(_record);

            return PopScope(
              canPop: false,
              onPopInvokedWithResult: (didPop, result) async {
                if (didPop) return;
                await handleCancel();
              },
              child: Padding(
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
                            onPressed: handleCancel,
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
                                'Loan Completed',
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
                                'Loan Completed',
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
                        'Pending',
                        'DCR Created',
                        'PM Surya Ghar Updated',
                        'Install Ack',
                        'Done',
                        'Not Applied',
                        'Applied',
                        'Under Process',
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

  Widget _buildSmartInsightBanner(BuildContext context, ThemeData theme, bool isDark) {
    final intel = AppIntelligenceService.evaluateCustomer(_record);
    final isWarning = intel.riskLevel == 'high';
    final isMedium = intel.riskLevel == 'medium';
    final badgeColor = isWarning
        ? const Color(0xFFDC2626)
        : (isMedium ? const Color(0xFFD97706) : const Color(0xFF2563EB));
    final bgColor = isDark
        ? (isWarning ? const Color(0xFF450A0A) : const Color(0xFF1E293B))
        : (isWarning ? const Color(0xFFFEF2F2) : const Color(0xFFEFF6FF));

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: badgeColor.withValues(alpha: 0.3), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  isWarning ? Icons.warning_amber_rounded : Icons.auto_awesome_rounded,
                  size: 18,
                  color: badgeColor,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'NEXT BEST ACTION: ${intel.nextBestAction.toUpperCase()}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                    color: badgeColor,
                  ),
                ),
              ),
              if (intel.daysInCurrentStage > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: (intel.daysInCurrentStage >= 10 ? const Color(0xFFEF4444) : Colors.grey)
                        .withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${intel.daysInCurrentStage}d in stage',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: intel.daysInCurrentStage >= 10 ? const Color(0xFFDC2626) : Colors.grey.shade700,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            intel.context,
            style: TextStyle(
              fontSize: 13,
              color: isDark ? Colors.white70 : const Color(0xFF334155),
              height: 1.3,
            ),
          ),
          if (intel.suggestedPaymentAmount != null && intel.suggestedPaymentAmount! > 0) ...[
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.tonalIcon(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF059669).withValues(alpha: 0.15),
                  foregroundColor: const Color(0xFF059669),
                  visualDensity: VisualDensity.compact,
                ),
                icon: const Icon(Icons.bolt_rounded, size: 16),
                label: Text(
                  'Quick Record ₹${NumberFormat('#,##,###').format(intel.suggestedPaymentAmount)}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                ),
                onPressed: () async {
                  final res = await AddPaymentDialog.show(
                    context,
                    preselectedCustomer: _record,
                    initialAmount: intel.suggestedPaymentAmount,
                  );
                  if (res == true && mounted) {
                    final updated = await AppDatabase.getConsumerRecordById(_record.id!);
                    if (updated != null) {
                      setState(() {
                        _record = updated;
                        _hasChanged = true;
                      });
                    }
                  }
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        Navigator.of(context).pop(_hasChanged);
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
              // Hold / No Action Banner
              if (_record.isNoActionRequired)
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFF59E0B)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.pause_circle_filled, color: Color(0xFFD97706), size: 24),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'WORK STATE: HOLD / NO ACTION REQUIRED',
                              style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF92400E), fontSize: 13),
                            ),
                            if (_record.noActionReason != null && _record.noActionReason!.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(
                                'Reason: ${_record.noActionReason}',
                                style: const TextStyle(color: Color(0xFF78350F), fontSize: 12),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

              // Smart Next Best Action Radar Banner
              _buildSmartInsightBanner(context, theme, isDark),

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
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Flexible(
                            child: Text(
                              _record.name,
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                            ),
                          ),
                          const SizedBox(width: 6),
                          IconButton(
                            icon: const Icon(Icons.edit_outlined, size: 20),
                            tooltip: 'Edit Consumer Name',
                            visualDensity: VisualDensity.compact,
                            onPressed: _isSaving ? null : _showEditConsumerNameDialog,
                          ),
                        ],
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

              // Customer Payment Profile & Milestone Intelligence Card
              _buildCustomerPaymentProfileCard(theme, isDark),

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

              const SizedBox(height: 16),

              // Activity History (Who Worked Log Timeline)
              Card(
                elevation: 1,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: CustomerTimelineWidget(
                    recordId: _record.id,
                    consumerNo: _record.consumerNo,
                    customerName: _record.name,
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Customer Tasks (Standard Office Tasks)
              _buildCustomerTasksCard(theme),

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
              if (_record.isCompletedState || _record.isNoActionRequired)
                OutlinedButton.icon(
                  onPressed: _handleReopen,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.refresh, size: 20),
                  label: const Text('Reopen Customer', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                )
              else ...[
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _handleMarkAsNoAction,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFD97706),
                          side: const BorderSide(color: Color(0xFFD97706)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: const Icon(Icons.pause_circle_outline, size: 20),
                        label: const Text('Mark as Hold', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _handleMarkAsComplete,
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF059669),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: const Icon(Icons.check_circle_outline, size: 20),
                        label: const Text('Mark Complete', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ],
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

  Widget _buildCustomerPaymentProfileCard(ThemeData theme, bool isDark) {
    final total = _record.totalAmount;
    final paid = _record.paidAmount;
    final pending = _record.pendingAmount;
    final hasAdditional = _record.additionalPaidAmount > 0;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.account_balance_wallet_rounded, color: Color(0xFF059669), size: 22),
                    const SizedBox(width: 8),
                    Text(
                      'PAYMENT',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
                TextButton.icon(
                  icon: const Icon(Icons.edit_outlined, size: 14),
                  label: const Text('Edit Total', style: TextStyle(fontSize: 12)),
                  onPressed: _showEditTotalPaymentDialog,
                ),
              ],
            ),
            const Divider(height: 16),

            // Metrics: Total Payment, Paid, Pending, Additional
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _paymentMetricCol(
                  'Total Payment',
                  '₹${NumberFormat('#,##,###').format(total)}',
                  Colors.grey.shade800,
                  onTap: _showEditTotalPaymentDialog,
                ),
                _paymentMetricCol(
                  'Paid',
                  '₹${NumberFormat('#,##,###').format(paid)}',
                  const Color(0xFF059669),
                ),
                _paymentMetricCol(
                  'Pending',
                  '₹${NumberFormat('#,##,###').format(pending)}',
                  pending > 0 ? const Color(0xFFDC2626) : const Color(0xFF059669),
                ),
                if (hasAdditional)
                  _paymentMetricCol(
                    'Additional',
                    '₹${NumberFormat('#,##,###').format(_record.additionalPaidAmount)}',
                    const Color(0xFF7C3AED),
                  ),
              ],
            ),
            const SizedBox(height: 16),

            // Action Buttons: [ + Add Payment ] and [ Payment History ]
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('+ Add Payment', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF059669),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: () async {
                      final res = await AddPaymentDialog.show(context, preselectedCustomer: _record);
                      if (res == true && mounted) {
                        final updated = await AppDatabase.getConsumerRecordById(_record.id!);
                        if (updated != null) {
                          setState(() {
                            _record = updated;
                            _hasChanged = true;
                          });
                        }
                      }
                    },
                  ),
                ),
                const SizedBox(width: 10),
                OutlinedButton.icon(
                  icon: const Icon(Icons.history_rounded, size: 18),
                  label: const Text('Payment History', style: TextStyle(fontSize: 13)),
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                  onPressed: _showPaymentHistorySheet,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showEditTotalPaymentDialog() async {
    final totalCtrl = TextEditingController(
      text: _record.totalAmount > 0 ? _record.totalAmount.toStringAsFixed(0) : '',
    );

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Total Payment'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Customer: ${_record.name} (${_record.consumerNo})'),
            const SizedBox(height: 12),
            TextField(
              controller: totalCtrl,
              keyboardType: TextInputType.number,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Total Payment (₹) *',
                prefixText: '₹ ',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFF059669)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final newTotal = double.tryParse(totalCtrl.text.trim()) ?? 0.0;
      final updated = await PaymentService.updateTotalPayment(
        customerId: _record.id!,
        newTotalAmount: newTotal,
      );
      if (updated != null && mounted) {
        setState(() {
          _record = updated;
          _hasChanged = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Total Payment updated successfully!'),
            backgroundColor: Color(0xFF059669),
          ),
        );
      }
    }
  }

  Widget _paymentMetricCol(String title, String val, Color color, {VoidCallback? onTap}) {
    final col = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title, style: const TextStyle(fontSize: 11, color: Colors.grey)),
            if (onTap != null) ...[
              const SizedBox(width: 2),
              const Icon(Icons.edit_outlined, size: 10, color: Colors.grey),
            ],
          ],
        ),
        const SizedBox(height: 2),
        Text(val, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: color)),
      ],
    );

    if (onTap != null) {
      return InkWell(onTap: onTap, child: col);
    }
    return col;
  }

  void _showPaymentHistorySheet() async {
    if (_record.id == null) return;
    final payments = await AppDatabase.getCustomerPayments(_record.id!);

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Payment History (${payments.length})',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
            const Divider(),
            if (payments.isEmpty)
              const Expanded(
                child: Center(child: Text('No recorded payments for this customer yet.')),
              )
            else
              Expanded(
                child: ListView.builder(
                  itemCount: payments.length,
                  itemBuilder: (context, idx) {
                    final tx = payments[idx];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: const Color(0xFF059669).withValues(alpha: 0.12),
                          child: Icon(PaymentMode.getModeIcon(tx.paymentMode), size: 18, color: const Color(0xFF059669)),
                        ),
                        title: Row(
                          children: [
                            Text(
                              '₹${NumberFormat('#,##,###').format(tx.amount)}',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                            ),
                            if (tx.isAdditional) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEDE9FE),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  'Additional',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF7C3AED),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 2),
                            Text(
                              '${DateFormat('dd MMM yyyy').format(tx.paymentDate)} • ${tx.paymentMode}',
                              style: const TextStyle(fontSize: 12),
                            ),
                            if (tx.remarks != null && tx.remarks!.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Text(
                                  tx.remarks!,
                                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomerTasksCard(ThemeData theme) {
    return Card(
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
                Row(
                  children: [
                    const Icon(Icons.assignment_outlined, size: 20, color: Color(0xFF0284C7)),
                    const SizedBox(width: 8),
                    Text(
                      'Tasks',
                      style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0284C7).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${_customerTasks.length}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0284C7),
                        ),
                      ),
                    ),
                  ],
                ),
                TextButton.icon(
                  onPressed: () async {
                    final created = await CreateOfficeTaskBottomSheet.show(
                      context,
                      preselectedCustomer: _record,
                    );
                    if (created != null) {
                      _loadCustomerTasks();
                    }
                  },
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Add Task', style: TextStyle(fontSize: 13)),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ],
            ),
            const Divider(height: 18),
            if (_isLoadingCustomerTasks)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2.5),
                  ),
                ),
              )
            else if (_customerTasks.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12.0),
                child: Center(
                  child: Column(
                    children: [
                      Icon(Icons.task_alt_outlined, size: 36, color: Colors.grey.shade400),
                      const SizedBox(height: 6),
                      Text(
                        'No tasks for this customer',
                        style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _customerTasks.length,
                separatorBuilder: (context, index) => const Divider(height: 12),
                itemBuilder: (context, index) {
                  final task = _customerTasks[index];
                  final isDone = task.isCompleted;

                  Color statusColor;
                  switch (task.status.toUpperCase()) {
                    case 'COMPLETED':
                      statusColor = const Color(0xFF059669);
                      break;
                    case 'IN PROGRESS':
                      statusColor = const Color(0xFF0284C7);
                      break;
                    case 'ON HOLD':
                      statusColor = const Color(0xFFD97706);
                      break;
                    default:
                      statusColor = const Color(0xFF6B7280);
                  }

                  return InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => TaskDetailsScreen(task: task),
                        ),
                      );
                      _loadCustomerTasks();
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 4.0),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            isDone ? Icons.check_circle : Icons.radio_button_unchecked,
                            size: 18,
                            color: isDone ? const Color(0xFF059669) : Colors.grey.shade400,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        task.title,
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13,
                                          decoration: isDone ? TextDecoration.lineThrough : null,
                                          color: isDone ? Colors.grey.shade600 : null,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    if (task.hasAttachment) ...[
                                      const SizedBox(width: 4),
                                      const Icon(Icons.attach_file, size: 14, color: Color(0xFF0284C7)),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 3),
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                      decoration: BoxDecoration(
                                        color: statusColor.withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        task.status,
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: statusColor,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'Assigned: ${task.assignedToName}',
                                        style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    if (task.dueDate != null) ...[
                                      Text(
                                        DateFormat('dd MMM').format(task.dueDate!),
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: task.isOverdue ? Colors.red.shade600 : Colors.grey.shade600,
                                          fontWeight: task.isOverdue ? FontWeight.bold : FontWeight.normal,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(Icons.chevron_right, size: 16, color: Colors.grey.shade400),
                        ],
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}
