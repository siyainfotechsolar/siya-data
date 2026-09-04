import 'package:flutter/material.dart';
import '../models/consumer_record.dart';
import '../models/duplicate_group.dart';
import '../models/merge_conflict.dart';
import '../services/duplicate_finder_service.dart';
import '../services/workflow_engine.dart';

class SmartMergeDialog extends StatefulWidget {
  final DuplicateGroup group;
  final VoidCallback onMergeCompleted;

  const SmartMergeDialog({
    super.key,
    required this.group,
    required this.onMergeCompleted,
  });

  @override
  State<SmartMergeDialog> createState() => _SmartMergeDialogState();
}

class _SmartMergeDialogState extends State<SmartMergeDialog> {
  int _currentStep = 0; // 0: Master Selection, 1: Field Comparison & Conflict Resolution, 2: Final Review
  bool _isExecutingMerge = false;

  late ConsumerRecord _masterRecord;
  late List<ConsumerRecord> _duplicateRecords;

  // Field conflict maps key -> MergeConflictField
  final Map<String, MergeConflictField> _conflictFields = {};

  @override
  void initState() {
    super.initState();
    // Default master is the first record (oldest or primary)
    _masterRecord = widget.group.records.first;
    _updateDuplicatesList();
    _buildConflictFields();
  }

  void _updateDuplicatesList() {
    _duplicateRecords = widget.group.records.where((r) => r.id != _masterRecord.id).toList();
    if (_duplicateRecords.isEmpty && widget.group.records.length > 1) {
      _duplicateRecords = [widget.group.records.last];
    }
  }

  void _buildConflictFields() {
    _conflictFields.clear();
    final primaryDup = _duplicateRecords.first;

    void addField(String key, String label, String? masterVal, String? dupVal) {
      _conflictFields[key] = MergeConflictField.compare(
        fieldKey: key,
        fieldLabel: label,
        masterVal: masterVal,
        duplicateVal: dupVal,
      );
    }

    addField('consumer_no', 'Consumer No', _masterRecord.consumerNo, primaryDup.consumerNo);
    addField('name', 'Customer Name', _masterRecord.name, primaryDup.name);
    addField('mobile', 'Mobile Number', _masterRecord.mobile, primaryDup.mobile);
    addField('address', 'Address', _masterRecord.address, primaryDup.address);
    addField('application_id', 'Application ID', _masterRecord.applicationId, primaryDup.applicationId);
    addField('status', 'Overall Status', _masterRecord.status, primaryDup.status);
    addField('remarks', 'Remarks', _masterRecord.remarks, primaryDup.remarks);

    // Workflow Stages
    addField('application_status', 'Application Status', _masterRecord.applicationStatus, primaryDup.applicationStatus);
    addField('agreement_status', 'Agreement Status', _masterRecord.agreementStatus, primaryDup.agreementStatus);
    addField('loan_required', 'Loan Required', _masterRecord.loanRequired, primaryDup.loanRequired);
    addField('loan_status', 'Loan Status', _masterRecord.loanStatus, primaryDup.loanStatus);
    addField('installation_status', 'Installation Status', _masterRecord.installationStatus, primaryDup.installationStatus);
    addField('installer_team', 'Assigned Installer Team', _masterRecord.installerTeam, primaryDup.installerTeam);
    addField('rts_status', 'RTS / Net Meter Status', _masterRecord.rtsStatus, primaryDup.rtsStatus);
    addField('rts_application_id', 'RTS Application ID', _masterRecord.rtsApplicationId, primaryDup.rtsApplicationId);
    addField('subsidy_status', 'Subsidy Status', _masterRecord.subsidyStatus, primaryDup.subsidyStatus);

    // Dates
    addField(
      'submit_date',
      'Submit Date (Recalculates Priority)',
      _masterRecord.submitDate?.toLocal().toString().split(' ')[0],
      primaryDup.submitDate?.toLocal().toString().split(' ')[0],
    );
  }

  Map<String, dynamic> _buildMergedPayload() {
    final payload = <String, dynamic>{};

    _conflictFields.forEach((key, conflict) {
      final val = conflict.resolvedValue.trim();
      if (key == 'submit_date') {
        if (val.isNotEmpty) {
          final parsedDate = DateTime.tryParse(val);
          if (parsedDate != null) {
            payload[key] = parsedDate.toUtc().toIso8601String();
          }
        }
      } else if (key == 'agreement_required') {
        payload[key] = val.toLowerCase() == 'true';
      } else {
        if (val.isNotEmpty) {
          payload[key] = val;
        }
      }
    });

    // Recalculate status using WorkflowEngine on prospective record
    final prospective = ConsumerRecord.fromJson({..._masterRecord.toJson(), ...payload});
    payload['status'] = WorkflowEngine.getCurrentWorkStage(prospective);

    return payload;
  }

  Future<void> _handleExecuteMerge() async {
    setState(() => _isExecutingMerge = true);

    try {
      final mergedPayload = _buildMergedPayload();
      final duplicateIds = _duplicateRecords.map((r) => r.id ?? '').where((id) => id.isNotEmpty).toList();

      final conflictsSummary = <String, dynamic>{};
      _conflictFields.forEach((key, conflict) {
        if (conflict.state == MergeFieldState.conflict) {
          conflictsSummary[key] = {
            'label': conflict.fieldLabel,
            'master': conflict.masterValue,
            'duplicate': conflict.duplicateValue,
            'resolved': conflict.resolvedValue,
            'strategy': conflict.strategy.name,
          };
        }
      });

      final success = await DuplicateFinderService.executeSmartMerge(
        masterId: _masterRecord.id ?? '',
        duplicateIds: duplicateIds,
        mergedPayload: mergedPayload,
        conflictsSummary: conflictsSummary,
      );

      if (mounted) {
        setState(() => _isExecutingMerge = false);
        if (success) {
          Navigator.of(context).pop();
          widget.onMergeCompleted();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Smart Merge Successful! Combined into Master Record #${_masterRecord.consumerNo}'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to execute Smart Merge. Transaction rolled back.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isExecutingMerge = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Merge Error: $e'), backgroundColor: Colors.red),
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
        width: 860,
        height: 700,
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            // Header
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: theme.colorScheme.primaryContainer,
                  child: Icon(Icons.merge_type_rounded, color: theme.colorScheme.primary),
                ),
                const SizedBox(width: 14),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Smart Merge Wizard',
                      style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'Safe deduplication for Consumer No: ${widget.group.normalizedConsumerNo}',
                      style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 13),
                    ),
                  ],
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Stepper Tabs Header
            Row(
              children: [
                _buildStepHeader(0, '1. Select Master Record'),
                const Expanded(child: Divider(indent: 8, endIndent: 8)),
                _buildStepHeader(1, '2. Compare & Resolve Conflicts'),
                const Expanded(child: Divider(indent: 8, endIndent: 8)),
                _buildStepHeader(2, '3. Review & Confirm'),
              ],
            ),
            const SizedBox(height: 20),

            // Step Body
            Expanded(
              child: _buildCurrentStepBody(theme),
            ),

            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 16),

            // Dialog Footer Navigation Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (_currentStep > 0)
                  OutlinedButton.icon(
                    icon: const Icon(Icons.arrow_back),
                    label: const Text('Back'),
                    onPressed: _isExecutingMerge ? null : () => setState(() => _currentStep--),
                  )
                else
                  const SizedBox.shrink(),
                Row(
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 12),
                    if (_currentStep < 2)
                      FilledButton.icon(
                        icon: const Icon(Icons.arrow_forward),
                        label: const Text('Next Step'),
                        onPressed: () {
                          if (_currentStep == 0) {
                            _updateDuplicatesList();
                            _buildConflictFields();
                          }
                          setState(() => _currentStep++);
                        },
                      )
                    else
                      FilledButton.icon(
                        icon: _isExecutingMerge
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.check_circle_rounded),
                        label: Text(_isExecutingMerge ? 'Merging Records...' : 'CONFIRM MERGE'),
                        style: FilledButton.styleFrom(backgroundColor: const Color(0xFF16A34A)),
                        onPressed: _isExecutingMerge ? null : _handleExecuteMerge,
                      ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepHeader(int stepIndex, String title) {
    final isActive = _currentStep == stepIndex;
    final isDone = _currentStep > stepIndex;

    return Row(
      children: [
        CircleAvatar(
          radius: 13,
          backgroundColor: isDone
              ? Colors.green
              : (isActive ? Theme.of(context).colorScheme.primary : Colors.grey.shade300),
          child: isDone
              ? const Icon(Icons.check, size: 14, color: Colors.white)
              : Text(
                  '${stepIndex + 1}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: isActive ? Colors.white : Colors.grey.shade700,
                  ),
                ),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontWeight: isActive || isDone ? FontWeight.bold : FontWeight.normal,
            color: isActive ? Theme.of(context).colorScheme.primary : Colors.grey.shade700,
            fontSize: 13,
          ),
        ),
      ],
    );
  }

  Widget _buildCurrentStepBody(ThemeData theme) {
    switch (_currentStep) {
      case 0:
        return _buildStep1MasterSelection(theme);
      case 1:
        return _buildStep2ConflictResolution(theme);
      case 2:
        return _buildStep3FinalReview(theme);
      default:
        return _buildStep1MasterSelection(theme);
    }
  }

  // --- Step 1: Master Record Selection ---
  Widget _buildStep1MasterSelection(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.blue.shade200),
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline, color: Colors.blue.shade800, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Select the Master Record. Its Primary Key ID will be preserved as the active customer entry. Other duplicate records will be safely merged and marked as merged.',
                  style: TextStyle(fontSize: 12, color: Colors.blue.shade900),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Available Duplicate Records (${widget.group.recordCount}):',
          style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        Expanded(
          child: ListView.builder(
            itemCount: widget.group.records.length,
            itemBuilder: (ctx, i) {
              final rec = widget.group.records[i];
              final isMaster = _masterRecord.id == rec.id || (rec.id == null && i == 0);

              return Card(
                elevation: isMaster ? 3 : 1,
                margin: const EdgeInsets.only(bottom: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: BorderSide(
                    color: isMaster ? theme.colorScheme.primary : Colors.grey.shade300,
                    width: isMaster ? 2.0 : 1.0,
                  ),
                ),
                child: InkWell(
                  onTap: () {
                    setState(() {
                      _masterRecord = rec;
                      _updateDuplicatesList();
                    });
                  },
                  borderRadius: BorderRadius.circular(10),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      children: [
                        Radio<String?>(
                          value: rec.id ?? '$i',
                          groupValue: _masterRecord.id ?? '0',
                          onChanged: (_) {
                            setState(() {
                              _masterRecord = rec;
                              _updateDuplicatesList();
                            });
                          },
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    rec.name,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                  ),
                                  const SizedBox(width: 10),
                                  if (isMaster)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: theme.colorScheme.primary,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: const Text(
                                        'MASTER RECORD',
                                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10),
                                      ),
                                    )
                                  else
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.grey.shade200,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: const Text(
                                        'DUPLICATE',
                                        style: TextStyle(color: Colors.black87, fontSize: 10),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Consumer No: ${rec.consumerNo} • Mobile: ${rec.mobile ?? "—"} • Status: ${rec.status}',
                                style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Overall Stage: ${rec.overallStage} • Priority: ${rec.priority} (${rec.applicationDays} Days)',
                                style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // --- Step 2: Side-by-Side Comparison & Conflict Resolution ---
  Widget _buildStep2ConflictResolution(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.amber.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.amber.shade300),
          ),
          child: Row(
            children: [
              Icon(Icons.rule_folder_outlined, color: Colors.amber.shade900, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Resolve field conflicts below. Empty values are automatically copied. For conflicting values, select whether to Keep Master, Use Duplicate, or Enter Custom value.',
                  style: TextStyle(fontSize: 12, color: Colors.amber.shade900),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        Expanded(
          child: SingleChildScrollView(
            child: Table(
              columnWidths: const {
                0: FlexColumnWidth(1.8),
                1: FlexColumnWidth(2.2),
                2: FlexColumnWidth(2.2),
                3: FlexColumnWidth(2.8),
              },
              border: TableBorder.all(color: Colors.grey.shade300, width: 1),
              children: [
                TableRow(
                  decoration: BoxDecoration(color: Colors.grey.shade100),
                  children: const [
                    Padding(padding: EdgeInsets.all(10), child: Text('Field Name', style: TextStyle(fontWeight: FontWeight.bold))),
                    Padding(padding: EdgeInsets.all(10), child: Text('Master Record', style: TextStyle(fontWeight: FontWeight.bold))),
                    Padding(padding: EdgeInsets.all(10), child: Text('Duplicate Record', style: TextStyle(fontWeight: FontWeight.bold))),
                    Padding(padding: EdgeInsets.all(10), child: Text('Resolution Strategy', style: TextStyle(fontWeight: FontWeight.bold))),
                  ],
                ),
                ..._conflictFields.entries.map((entry) {
                  final key = entry.key;
                  final conflict = entry.value;
                  return _buildConflictTableRow(key, conflict);
                }),
              ],
            ),
          ),
        ),
      ],
    );
  }

  TableRow _buildConflictTableRow(String key, MergeConflictField conflict) {
    final isConflict = conflict.state == MergeFieldState.conflict;
    final isMatch = conflict.state == MergeFieldState.match;

    Color bg = Colors.white;
    if (isConflict) bg = const Color(0xFFFFFBEB);
    if (isMatch) bg = const Color(0xFFF0FDF4);

    return TableRow(
      decoration: BoxDecoration(color: bg),
      children: [
        // Column 1: Field Label & State Badge
        Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(conflict.fieldLabel, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              const SizedBox(height: 4),
              if (isMatch)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: Colors.green.shade100, borderRadius: BorderRadius.circular(4)),
                  child: const Text('MATCH', style: TextStyle(fontSize: 10, color: Colors.green, fontWeight: FontWeight.bold)),
                )
              else if (isConflict)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: Colors.amber.shade200, borderRadius: BorderRadius.circular(4)),
                  child: const Text('CONFLICT', style: TextStyle(fontSize: 10, color: Colors.amber, fontWeight: FontWeight.bold)),
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: Colors.blue.shade100, borderRadius: BorderRadius.circular(4)),
                  child: const Text('AUTO-COPY', style: TextStyle(fontSize: 10, color: Colors.blue, fontWeight: FontWeight.bold)),
                ),
            ],
          ),
        ),

        // Column 2: Master Value
        Padding(
          padding: const EdgeInsets.all(10),
          child: Text(
            conflict.masterValue.isEmpty ? '— (Empty)' : conflict.masterValue,
            style: TextStyle(
              fontSize: 13,
              color: conflict.masterValue.isEmpty ? Colors.grey : Colors.black87,
              fontWeight: conflict.strategy == MergeStrategy.keepMaster ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),

        // Column 3: Duplicate Value
        Padding(
          padding: const EdgeInsets.all(10),
          child: Text(
            conflict.duplicateValue.isEmpty ? '— (Empty)' : conflict.duplicateValue,
            style: TextStyle(
              fontSize: 13,
              color: conflict.duplicateValue.isEmpty ? Colors.grey : Colors.black87,
              fontWeight: conflict.strategy == MergeStrategy.useDuplicate ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),

        // Column 4: Selection Radio Controls
        Padding(
          padding: const EdgeInsets.all(6),
          child: isMatch
              ? const Padding(
                  padding: EdgeInsets.all(4.0),
                  child: Text('Identical (Keep Value)', style: TextStyle(color: Colors.green, fontSize: 12, fontWeight: FontWeight.bold)),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    RadioListTile<MergeStrategy>(
                      title: Text('Keep Master (${conflict.masterValue.isEmpty ? "Empty" : conflict.masterValue})', style: const TextStyle(fontSize: 11)),
                      value: MergeStrategy.keepMaster,
                      groupValue: conflict.strategy,
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      onChanged: (val) {
                        if (val != null) setState(() => conflict.strategy = val);
                      },
                    ),
                    RadioListTile<MergeStrategy>(
                      title: Text('Use Duplicate (${conflict.duplicateValue.isEmpty ? "Empty" : conflict.duplicateValue})', style: const TextStyle(fontSize: 11)),
                      value: MergeStrategy.useDuplicate,
                      groupValue: conflict.strategy,
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      onChanged: (val) {
                        if (val != null) setState(() => conflict.strategy = val);
                      },
                    ),
                  ],
                ),
        ),
      ],
    );
  }

  // --- Step 3: Final Safety Review & Confirmation ---
  Widget _buildStep3FinalReview(ThemeData theme) {
    final mergedPayload = _buildMergedPayload();
    final conflictCount = _conflictFields.values.where((c) => c.state == MergeFieldState.conflict).length;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF0FDF4),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFF86EFAC)),
            ),
            child: Row(
              children: [
                const Icon(Icons.shield_outlined, color: Color(0xFF16A34A), size: 28),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Merge Confirmation Review',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF166534)),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Review final resolved attributes. Data will be combined into Master Record #${_masterRecord.consumerNo}. Duplicate records will be safely marked as merged.',
                        style: const TextStyle(fontSize: 12, color: Color(0xFF15803D)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Master Card Summary
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Final Master Record Attributes:', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                  const Divider(height: 16),
                  Wrap(
                    spacing: 20,
                    runSpacing: 10,
                    children: [
                      _buildReviewBadge('Consumer No', mergedPayload['consumer_no'] ?? _masterRecord.consumerNo),
                      _buildReviewBadge('Customer Name', mergedPayload['name'] ?? _masterRecord.name),
                      _buildReviewBadge('Mobile', mergedPayload['mobile'] ?? _masterRecord.mobile ?? '—'),
                      _buildReviewBadge('Overall Stage', _masterRecord.overallStage),
                      _buildReviewBadge('Submit Date', mergedPayload['submit_date'] != null ? mergedPayload['submit_date'].toString().split('T')[0] : '—'),
                      _buildReviewBadge('Conflicts Resolved', '$conflictCount Field Conflicts'),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Duplicate Records to be Merged Card
          Card(
            elevation: 1,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Records to be marked as MERGED (${_duplicateRecords.length}):',
                    style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  ..._duplicateRecords.map((dup) {
                    return ListTile(
                      leading: const Icon(Icons.history_rounded, color: Colors.orange),
                      title: Text('${dup.name} (Consumer No: ${dup.consumerNo})'),
                      subtitle: Text('ID: ${dup.id ?? "—"} • Status: ${dup.status}'),
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(color: Colors.orange.shade100, borderRadius: BorderRadius.circular(4)),
                        child: const Text('WILL BE MARKED MERGED', style: TextStyle(fontSize: 10, color: Colors.orange, fontWeight: FontWeight.bold)),
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewBadge(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
      ],
    );
  }
}
