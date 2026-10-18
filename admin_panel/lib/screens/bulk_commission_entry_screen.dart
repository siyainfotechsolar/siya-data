import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import 'package:csv/csv.dart';
import '../models/agent_master.dart';
import '../models/commission_record.dart';
import '../models/consumer_record.dart';
import '../services/commission_service.dart';
import '../widgets/agent_master_dialog.dart';
import '../widgets/single_commission_entry_dialog.dart';
import '../utils/file_download_utils.dart';
import '../utils/responsive.dart';

/// Screen / Full Dialog for Bulk Manual Commission Entry
class BulkCommissionEntryScreen extends StatefulWidget {
  final VoidCallback? onEntriesSaved;

  const BulkCommissionEntryScreen({super.key, this.onEntriesSaved});

  static Future<void> show(BuildContext context, {VoidCallback? onEntriesSaved}) {
    return Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => BulkCommissionEntryScreen(onEntriesSaved: onEntriesSaved),
      ),
    );
  }

  @override
  State<BulkCommissionEntryScreen> createState() => _BulkCommissionEntryScreenState();
}

class _BulkCommissionEntryScreenState extends State<BulkCommissionEntryScreen> {
  final List<CommissionDraftItem> _rows = [];
  List<AgentMaster> _agents = [];
  bool _isLoadingAgents = true;
  bool _isSaving = false;
  bool _showValidationErrors = false;
  final _currencyFormat = NumberFormat('#,##,##0.00', 'en_IN');
  final _dateFormat = DateFormat('dd/MM/yyyy');

  // Customer search suggestions cache
  final Map<String, List<ConsumerRecord>> _customerSearchCache = {};

  @override
  void initState() {
    super.initState();
    _loadAgents();
    // Start with 3 empty initial rows
    _addRow();
    _addRow();
    _addRow();
  }

  Future<void> _loadAgents() async {
    setState(() => _isLoadingAgents = true);
    final list = await CommissionService.fetchAgents();
    if (mounted) {
      setState(() {
        _agents = list;
        _isLoadingAgents = false;
      });
    }
  }

  void _addRow([AgentMaster? defaultAgent]) {
    setState(() {
      _rows.add(CommissionDraftItem(
        localId: 'row-${DateTime.now().microsecondsSinceEpoch}-${_rows.length + 1}',
        agentName: defaultAgent?.name ?? (_agents.isNotEmpty ? _agents.first.name : ''),
        agentId: defaultAgent?.id ?? (_agents.isNotEmpty ? _agents.first.id : null),
        commissionDate: DateTime.now(),
      ));
    });
  }

  void _addMultipleRows(int count) {
    for (int i = 0; i < count; i++) {
      _addRow();
    }
  }

  void _removeRow(int index) {
    if (index >= 0 && index < _rows.length) {
      setState(() {
        _rows.removeAt(index);
        if (_rows.isEmpty) {
          _addRow();
        }
      });
    }
  }

  void _confirmClearForm() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear Form? (फॉर्म साफ करा?)'),
        content: const Text('Are you sure you want to discard all entered rows? Any unsaved entries will be lost.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Navigator.pop(ctx);
              setState(() {
                _rows.clear();
                _addRow();
                _addRow();
                _showValidationErrors = false;
              });
            },
            child: const Text('Clear All'),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Summary Metrics Computation
  // ---------------------------------------------------------------------------

  int get _totalEntries => _rows.where((r) => r.customerName.trim().isNotEmpty || (r.commissionAmount ?? 0) > 0).length;

  double get _totalCommissionAmount {
    double sum = 0.0;
    for (final r in _rows) {
      if (r.commissionAmount != null && r.commissionAmount! > 0) {
        sum += r.commissionAmount!;
      }
    }
    return sum;
  }

  int get _numberOfAgents {
    final set = <String>{};
    for (final r in _rows) {
      if (r.agentName.trim().isNotEmpty) set.add(r.agentName.trim().toLowerCase());
    }
    return set.length;
  }

  int get _numberOfCustomers {
    final set = <String>{};
    for (final r in _rows) {
      if (r.customerName.trim().isNotEmpty) set.add(r.customerName.trim().toLowerCase());
    }
    return set.length;
  }

  // ---------------------------------------------------------------------------
  // Save & Preview Flow
  // ---------------------------------------------------------------------------

  Future<void> _handlePreviewBeforeSave() async {
    setState(() => _showValidationErrors = true);

    final activeRows = _rows.where((r) => !r.isSaved).toList();
    if (activeRows.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No entries to save.')),
      );
      return;
    }

    final invalidRows = activeRows.where((r) => !r.isValid).toList();
    final validRows = activeRows.where((r) => r.isValid).toList();

    if (validRows.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('All ${invalidRows.length} rows contain validation errors. Please fix highlighted fields.'),
          backgroundColor: Colors.red.shade700,
        ),
      );
      return;
    }

    // Check duplicate warnings
    final warnings = await CommissionService.checkBatchDuplicates(validRows);

    if (!mounted) return;

    _showPreviewConfirmationDialog(validRows: validRows, invalidCount: invalidRows.length, warnings: warnings);
  }

  void _showPreviewConfirmationDialog({
    required List<CommissionDraftItem> validRows,
    required int invalidCount,
    required List<CommissionDuplicateWarning> warnings,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            final validTotal = validRows.fold<double>(0.0, (sum, r) => sum + (r.commissionAmount ?? 0.0));
            return Dialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              child: Container(
                width: 780,
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF57C00).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.fact_check_outlined, color: Color(0xFFF57C00), size: 24),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'Preview Before Save (जतन करण्यापूर्वी पूर्वावलोकन)',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                        ),
                        IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(dialogCtx)),
                      ],
                    ),
                    const Divider(height: 24),

                    // Summary Banner
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.blue.shade200),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildMiniStat('Valid Entries', '${validRows.length}', Icons.check_circle, Colors.green),
                          _buildMiniStat('Total Commission', '₹${_currencyFormat.format(validTotal)}', Icons.currency_rupee, const Color(0xFFF57C00)),
                          _buildMiniStat('Unique Agents', '${validRows.map((r) => r.agentName).toSet().length}', Icons.people, Colors.blue),
                          if (invalidCount > 0)
                            _buildMiniStat('Skipped Errors', '$invalidCount', Icons.warning_amber, Colors.red),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Duplicate Warning Alert if any
                    if (warnings.isNotEmpty) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.amber.shade50,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.amber.shade400),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.warning_rounded, color: Colors.amber.shade900, size: 20),
                                const SizedBox(width: 8),
                                Text(
                                  'Possible Duplicate Entries Warning (${warnings.length})',
                                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.amber.shade900),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'The following entries match existing commission records for the same agent, customer, and period. Please review:',
                              style: TextStyle(fontSize: 12),
                            ),
                            const SizedBox(height: 6),
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxHeight: 90),
                              child: ListView.builder(
                                shrinkWrap: true,
                                itemCount: warnings.length,
                                itemBuilder: (_, idx) {
                                  final w = warnings[idx];
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 2),
                                    child: Text(
                                      '• ${w.draft.agentName} ↔ ${w.draft.customerName}: ${w.reason}',
                                      style: TextStyle(fontSize: 12, color: Colors.brown.shade800),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],

                    // Entries List Preview
                    const Text('Entries to be created:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    const SizedBox(height: 8),
                    Flexible(
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: ListView.separated(
                          shrinkWrap: true,
                          itemCount: validRows.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (c, i) {
                            final row = validRows[i];
                            return ListTile(
                              dense: true,
                              leading: CircleAvatar(
                                radius: 14,
                                backgroundColor: Colors.orange.shade100,
                                child: Text('${i + 1}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.orange)),
                              ),
                              title: Text('${row.agentName}  ➔  ${row.customerName}', style: const TextStyle(fontWeight: FontWeight.w600)),
                              subtitle: Text(
                                'Consumer: ${row.consumerNo.isNotEmpty ? row.consumerNo : "N/A"} • Date: ${_dateFormat.format(row.commissionDate)}${row.solarCapacity != null ? " • Capacity: ${row.solarCapacity} kW" : ""}',
                                style: const TextStyle(fontSize: 11),
                              ),
                              trailing: Text(
                                '₹${_currencyFormat.format(row.commissionAmount ?? 0)}',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF16A34A)),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Actions
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        OutlinedButton(
                          onPressed: () => Navigator.pop(dialogCtx),
                          child: const Text('Back to Edit'),
                        ),
                        const SizedBox(width: 12),
                        FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFFF57C00),
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          ),
                          icon: const Icon(Icons.check),
                          label: Text('Save ${validRows.length} Valid Entries'),
                          onPressed: () {
                            Navigator.pop(dialogCtx);
                            _executeSaveAll(validRows);
                          },
                        ),
                      ],
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

  Widget _buildMiniStat(String label, String value, IconData icon, Color color) {
    return Row(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: color)),
            Text(label, style: const TextStyle(fontSize: 10, color: Colors.black54)),
          ],
        ),
      ],
    );
  }

  Future<void> _executeSaveAll(List<CommissionDraftItem> validRows) async {
    setState(() => _isSaving = true);

    try {
      final result = await CommissionService.saveBulkCommissionEntries(
        drafts: _rows,
      );

      setState(() {});

      if (mounted) {
        if (result.isAllSuccess) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Successfully saved all ${result.totalSaved} commission entries! (Initial status: Pending Approval)'),
              backgroundColor: const Color(0xFF16A34A),
            ),
          );
          widget.onEntriesSaved?.call();
          Navigator.of(context).pop();
        } else if (result.hasFailures) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Saved ${result.totalSaved} entries. ${result.totalFailed} rows had errors and remain for review.'),
              backgroundColor: Colors.orange.shade800,
              duration: const Duration(seconds: 5),
            ),
          );
          widget.onEntriesSaved?.call();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Save failed: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // ---------------------------------------------------------------------------
  // Optional Bulk Import (Excel/CSV)
  // ---------------------------------------------------------------------------

  Future<void> _handleDownloadTemplate() async {
    final csvContent = CommissionService.generateImportTemplateCsv();
    final ok = await FileDownloadUtils.downloadCsv(
      fileName: 'siya_bulk_commission_template.csv',
      csvContent: csvContent,
    );
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to trigger download automatically.')),
      );
    }
  }

  Future<void> _handleImportCsv() async {
    try {
      final res = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
        withData: true,
      );

      if (res == null || res.files.isEmpty) return;
      final fileBytes = res.files.first.bytes;
      if (fileBytes == null) return;

      final csvString = utf8.decode(fileBytes);
      final rawRows = const CsvToListConverter().convert(csvString);

      if (rawRows.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('The selected CSV file is empty.')),
          );
        }
        return;
      }

      final parsedDrafts = CommissionService.parseImportRows(rawRows, _agents);

      if (parsedDrafts.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No valid commission rows found in CSV.')),
          );
        }
        return;
      }

      setState(() {
        // If current rows are only initial empty rows, replace them
        if (_rows.length <= 3 && _rows.every((r) => r.customerName.isEmpty && (r.commissionAmount == null))) {
          _rows.clear();
        }
        _rows.addAll(parsedDrafts);
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Imported ${parsedDrafts.length} rows from CSV. Please review amounts before saving.'),
            backgroundColor: Colors.blue.shade700,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error importing file: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Build Main Screen
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDesktop = MediaQuery.of(context).size.width >= 900;

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.post_add_rounded, color: Color(0xFFF57C00)),
            SizedBox(width: 10),
            Text('Bulk Commission Entry (कमिशन बल्क नोंदणी)', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.download, size: 18),
            label: const Text('Sample Template'),
            onPressed: _handleDownloadTemplate,
          ),
          TextButton.icon(
            icon: const Icon(Icons.upload_file, size: 18),
            label: const Text('Import CSV'),
            onPressed: _handleImportCsv,
          ),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              visualDensity: VisualDensity.compact,
            ),
            icon: const Icon(Icons.add_circle_outline, size: 16),
            label: const Text('One by One Entry', style: TextStyle(fontSize: 12)),
            onPressed: () {
              Navigator.pop(context);
              SingleCommissionEntryDialog.show(context, onEntrySaved: widget.onEntriesSaved);
            },
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.person_add_alt_1),
            tooltip: 'Agent Master',
            onPressed: () => AgentMasterDialog.show(context, onAgentListChanged: _loadAgents),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // 1. Live Summary Dashboard Banner
          _buildSummaryBanner(theme),

          // 2. Information notice
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: const Color(0xFFFFF7ED),
            child: Row(
              children: [
                const Icon(Icons.info_outline, size: 18, color: Color(0xFFEA580C)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Manual Entry Mode: Enter the exact commission amount for each row manually. Commission is never calculated automatically by kW or formulas.',
                    style: TextStyle(fontSize: 12, color: Colors.orange.shade900, fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
          ),

          // 3. Editable Table
          Expanded(
            child: _isLoadingAgents
                ? const Center(child: CircularProgressIndicator())
                : isDesktop
                    ? _buildDesktopTable(theme)
                    : _buildMobileCardsList(theme),
          ),

          // 4. Bottom Controls Bar
          _buildBottomControlsBar(theme),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Summary Banner
  // ---------------------------------------------------------------------------

  Widget _buildSummaryBanner(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
        border: Border(bottom: BorderSide(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5))),
      ),
      child: LayoutBuilder(builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 650;
        final items = [
          _buildStatCard('Total Rows', '$_totalEntries', Icons.table_rows_outlined, Colors.indigo),
          _buildStatCard('Total Commission', '₹${_currencyFormat.format(_totalCommissionAmount)}', Icons.currency_rupee, const Color(0xFFF57C00)),
          _buildStatCard('Unique Agents', '$_numberOfAgents', Icons.badge_outlined, Colors.teal),
          _buildStatCard('Unique Customers', '$_numberOfCustomers', Icons.people_alt_outlined, Colors.blue),
        ];

        if (isNarrow) {
          return Wrap(
            spacing: 12,
            runSpacing: 8,
            children: items.map((w) => SizedBox(width: (constraints.maxWidth - 20) / 2, child: w)).toList(),
          );
        }

        return Row(
          children: items.map((w) => Expanded(child: w)).toList(),
        );
      }),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 4, offset: const Offset(0, 2)),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  value,
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: color),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(label, style: const TextStyle(fontSize: 11, color: Colors.black54)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Desktop Editable Table
  // ---------------------------------------------------------------------------

  Widget _buildDesktopTable(ThemeData theme) {
    return Scrollbar(
      thumbVisibility: true,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Table Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.8),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
              ),
              child: const Row(
                children: [
                  SizedBox(width: 40, child: Text('#', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                  Expanded(flex: 3, child: Text('Agent Name *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                  SizedBox(width: 8),
                  Expanded(flex: 4, child: Text('Customer Name *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                  SizedBox(width: 8),
                  Expanded(flex: 3, child: Text('Consumer No', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                  SizedBox(width: 8),
                  Expanded(flex: 2, child: Text('Capacity (kW)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                  SizedBox(width: 8),
                  Expanded(flex: 2, child: Text('Date *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                  SizedBox(width: 8),
                  Expanded(flex: 3, child: Text('Commission (₹) *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFFF57C00)))),
                  SizedBox(width: 8),
                  Expanded(flex: 3, child: Text('Remarks', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                  SizedBox(width: 48, child: Text('Action', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                ],
              ),
            ),

            // Table Rows
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _rows.length,
              itemBuilder: (context, index) {
                final row = _rows[index];
                final isInvalid = _showValidationErrors && !row.isValid && !row.isSaved;

                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: row.isSaved
                        ? Colors.green.shade50.withValues(alpha: 0.5)
                        : (isInvalid ? Colors.red.shade50.withValues(alpha: 0.5) : (index.isEven ? Colors.white : Colors.grey.shade50)),
                    border: Border(
                      bottom: BorderSide(color: isInvalid ? Colors.red.shade300 : Colors.grey.shade200),
                      left: BorderSide(color: isInvalid ? Colors.red : (row.isSaved ? Colors.green : Colors.transparent), width: 3),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // # Index / Saved indicator
                      SizedBox(
                        width: 40,
                        child: row.isSaved
                            ? const Icon(Icons.check_circle, color: Colors.green, size: 20)
                            : Text('${index + 1}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                      ),

                      // 1. Agent Dropdown
                      Expanded(
                        flex: 3,
                        child: DropdownButtonFormField<String>(
                          initialValue: row.agentName.isNotEmpty ? row.agentName : null,
                          isDense: true,
                          isExpanded: true,
                          decoration: InputDecoration(
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            errorText: isInvalid && row.agentName.isEmpty ? 'Select agent' : null,
                          ),
                          hint: const Text('Select Agent', style: TextStyle(fontSize: 12)),
                          items: _agents.map((a) {
                            return DropdownMenuItem<String>(
                              value: a.name,
                              child: Text(a.name, style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis),
                            );
                          }).toList(),
                          onChanged: row.isSaved
                              ? null
                              : (val) {
                                  if (val != null) {
                                    setState(() {
                                      row.agentName = val;
                                      final matched = _agents.firstWhere((a) => a.name == val, orElse: () => const AgentMaster(id: '', name: ''));
                                      row.agentId = matched.id.isNotEmpty ? matched.id : null;
                                    });
                                  }
                                },
                        ),
                      ),
                      const SizedBox(width: 8),

                      // 2. Customer Name with Autocomplete (Database Lookup)
                      Expanded(
                        flex: 4,
                        child: Autocomplete<ConsumerRecord>(
                          initialValue: TextEditingValue(text: row.customerName),
                          optionsBuilder: (textEditingValue) async {
                            final q = textEditingValue.text.trim();
                            if (q.length < 2) return const Iterable<ConsumerRecord>.empty();
                            if (_customerSearchCache.containsKey(q)) return _customerSearchCache[q]!;
                            final results = await CommissionService.searchCustomers(q);
                            _customerSearchCache[q] = results;
                            return results;
                          },
                          displayStringForOption: (c) => c.name,
                          optionsViewBuilder: (context, onSelected, options) {
                            return Align(
                              alignment: Alignment.topLeft,
                              child: Material(
                                elevation: 4.0,
                                borderRadius: BorderRadius.circular(8),
                                color: Theme.of(context).colorScheme.surface,
                                child: ConstrainedBox(
                                  constraints: const BoxConstraints(maxHeight: 260, maxWidth: 380),
                                  child: ListView.separated(
                                    padding: EdgeInsets.zero,
                                    shrinkWrap: true,
                                    itemCount: options.length,
                                    separatorBuilder: (_, __) => const Divider(height: 1),
                                    itemBuilder: (context, index) {
                                      final customer = options.elementAt(index);
                                      final capacity = customer.systemCapacity != null ? '${customer.systemCapacity}' : '';
                                      final consumerNo = customer.consumerNo.isNotEmpty ? customer.consumerNo : 'No Consumer #';
                                      final mobile = customer.mobile != null && customer.mobile!.isNotEmpty ? ' • ${customer.mobile}' : '';
                                      return ListTile(
                                        dense: true,
                                        leading: const CircleAvatar(
                                          radius: 14,
                                          backgroundColor: Color(0xFFFFF3E0),
                                          child: Icon(Icons.person, size: 16, color: Color(0xFFF57C00)),
                                        ),
                                        title: Text(
                                          customer.name,
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        subtitle: Text(
                                          '$consumerNo$mobile${capacity.isNotEmpty ? ' • $capacity' : ''}',
                                          style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        onTap: () => onSelected(customer),
                                      );
                                    },
                                  ),
                                ),
                              ),
                            );
                          },
                          onSelected: (customer) {
                            setState(() {
                              row.customerName = customer.name;
                              row.customerId = customer.id;
                              if (customer.consumerNo.isNotEmpty) row.consumerNo = customer.consumerNo;
                              if (customer.systemCapacity != null) {
                                final cleanCapacity = customer.systemCapacity!.replaceAll(RegExp(r'[^0-9.]'), '');
                                row.solarCapacity = double.tryParse(cleanCapacity);
                              }
                            });
                          },
                          fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                            return TextFormField(
                              controller: controller,
                              focusNode: focusNode,
                              readOnly: row.isSaved,
                              style: const TextStyle(fontSize: 12),
                              decoration: InputDecoration(
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                hintText: 'Customer name (search)',
                                errorText: isInvalid && row.customerName.isEmpty ? 'Required' : null,
                                suffixIcon: const Icon(Icons.search, size: 16, color: Colors.black45),
                              ),
                              onChanged: (v) => row.customerName = v,
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 8),

                      // 3. Consumer Number
                      Expanded(
                        flex: 3,
                        child: TextFormField(
                          key: ValueKey('${row.localId}_consumer_${row.customerId ?? "raw"}_${row.consumerNo}'),
                          initialValue: row.consumerNo,
                          readOnly: row.isSaved,
                          style: const TextStyle(fontSize: 12),
                          decoration: const InputDecoration(
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            hintText: 'Consumer No.',
                          ),
                          onChanged: (v) => row.consumerNo = v.trim(),
                        ),
                      ),
                      const SizedBox(width: 8),

                      // 4. Solar Capacity (kW) - Reference Only
                      Expanded(
                        flex: 2,
                        child: TextFormField(
                          key: ValueKey('${row.localId}_capacity_${row.customerId ?? "raw"}_${row.solarCapacity}'),
                          initialValue: row.solarCapacity != null ? row.solarCapacity.toString() : '',
                          readOnly: row.isSaved,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          style: const TextStyle(fontSize: 12),
                          decoration: const InputDecoration(
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            hintText: 'e.g. 3.0',
                            suffixText: 'kW',
                            suffixStyle: TextStyle(fontSize: 10, color: Colors.black54),
                          ),
                          onChanged: (v) => row.solarCapacity = double.tryParse(v),
                        ),
                      ),
                      const SizedBox(width: 8),

                      // 5. Commission Date
                      Expanded(
                        flex: 2,
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          onPressed: row.isSaved
                              ? null
                              : () async {
                                  final picked = await showDatePicker(
                                    context: context,
                                    initialDate: row.commissionDate,
                                    firstDate: DateTime(2020),
                                    lastDate: DateTime(2035),
                                  );
                                  if (picked != null) {
                                    setState(() => row.commissionDate = picked);
                                  }
                                },
                          child: Text(
                            DateFormat('dd/MM/yy').format(row.commissionDate),
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),

                      // 6. Commission Amount (₹) - Manual Entry
                      Expanded(
                        flex: 3,
                        child: TextFormField(
                          initialValue: row.commissionAmount != null ? row.commissionAmount.toString() : '',
                          readOnly: row.isSaved,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFFF57C00)),
                          decoration: InputDecoration(
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            prefixText: '₹ ',
                            prefixStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                            hintText: '0.00',
                            errorText: isInvalid && (row.commissionAmount == null || row.commissionAmount! <= 0)
                                ? 'Amount > 0'
                                : null,
                          ),
                          onChanged: (v) {
                            setState(() {
                              row.commissionAmount = double.tryParse(v.replaceAll(',', '').trim());
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: 8),

                      // 7. Remarks
                      Expanded(
                        flex: 3,
                        child: TextFormField(
                          initialValue: row.remarks,
                          readOnly: row.isSaved,
                          style: const TextStyle(fontSize: 12),
                          decoration: const InputDecoration(
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            hintText: 'Optional remarks',
                          ),
                          onChanged: (v) => row.remarks = v,
                        ),
                      ),

                      // 8. Remove Row
                      SizedBox(
                        width: 48,
                        child: row.isSaved
                            ? Tooltip(
                                message: 'Saved: ${row.savedEntryNumber}',
                                child: const Icon(Icons.lock, size: 18, color: Colors.green),
                              )
                            : IconButton(
                                icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                                tooltip: 'Remove row',
                                onPressed: () => _removeRow(index),
                              ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Mobile Cards List
  // ---------------------------------------------------------------------------

  Widget _buildMobileCardsList(ThemeData theme) {
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _rows.length,
      itemBuilder: (context, index) {
        final row = _rows[index];
        final isInvalid = _showValidationErrors && !row.isValid && !row.isSaved;

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: isInvalid ? Colors.red : (row.isSaved ? Colors.green : Colors.grey.shade300),
              width: isInvalid || row.isSaved ? 2 : 1,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 12,
                          backgroundColor: row.isSaved ? Colors.green : const Color(0xFFF57C00),
                          child: Text('${index + 1}', style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold)),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          row.isSaved ? 'Saved: ${row.savedEntryNumber}' : 'Row #${index + 1}',
                          style: TextStyle(fontWeight: FontWeight.bold, color: row.isSaved ? Colors.green : null),
                        ),
                      ],
                    ),
                    if (!row.isSaved)
                      IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                        onPressed: () => _removeRow(index),
                      ),
                  ],
                ),
                const SizedBox(height: 10),

                // Agent Selection
                DropdownButtonFormField<String>(
                  initialValue: row.agentName.isNotEmpty ? row.agentName : null,
                  decoration: const InputDecoration(labelText: 'Select Agent *', isDense: true),
                  items: _agents.map((a) => DropdownMenuItem(value: a.name, child: Text(a.name))).toList(),
                  onChanged: row.isSaved
                      ? null
                      : (v) {
                          if (v != null) {
                            setState(() {
                              row.agentName = v;
                              final m = _agents.firstWhere((a) => a.name == v, orElse: () => const AgentMaster(id: '', name: ''));
                              row.agentId = m.id.isNotEmpty ? m.id : null;
                            });
                          }
                        },
                ),
                const SizedBox(height: 10),

                // Customer Name with Autocomplete (Database Lookup)
                Autocomplete<ConsumerRecord>(
                  initialValue: TextEditingValue(text: row.customerName),
                  optionsBuilder: (textEditingValue) async {
                    final q = textEditingValue.text.trim();
                    if (q.length < 2) return const Iterable<ConsumerRecord>.empty();
                    if (_customerSearchCache.containsKey(q)) return _customerSearchCache[q]!;
                    final results = await CommissionService.searchCustomers(q);
                    _customerSearchCache[q] = results;
                    return results;
                  },
                  displayStringForOption: (c) => c.name,
                  optionsViewBuilder: (context, onSelected, options) {
                    return Align(
                      alignment: Alignment.topLeft,
                      child: Material(
                        elevation: 4.0,
                        borderRadius: BorderRadius.circular(8),
                        color: Theme.of(context).colorScheme.surface,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxHeight: 240, maxWidth: 320),
                          child: ListView.separated(
                            padding: EdgeInsets.zero,
                            shrinkWrap: true,
                            itemCount: options.length,
                            separatorBuilder: (_, __) => const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final customer = options.elementAt(index);
                              final capacity = customer.systemCapacity != null ? '${customer.systemCapacity}' : '';
                              final consumerNo = customer.consumerNo.isNotEmpty ? customer.consumerNo : 'No Consumer #';
                              final mobile = customer.mobile != null && customer.mobile!.isNotEmpty ? ' • ${customer.mobile}' : '';
                              return ListTile(
                                dense: true,
                                title: Text(customer.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                subtitle: Text('$consumerNo$mobile${capacity.isNotEmpty ? ' • $capacity' : ''}', style: TextStyle(fontSize: 11, color: Colors.grey.shade700)),
                                onTap: () => onSelected(customer),
                              );
                            },
                          ),
                        ),
                      ),
                    );
                  },
                  onSelected: (customer) {
                    setState(() {
                      row.customerName = customer.name;
                      row.customerId = customer.id;
                      if (customer.consumerNo.isNotEmpty) row.consumerNo = customer.consumerNo;
                      if (customer.systemCapacity != null) {
                        final cleanCapacity = customer.systemCapacity!.replaceAll(RegExp(r'[^0-9.]'), '');
                        row.solarCapacity = double.tryParse(cleanCapacity);
                      }
                    });
                  },
                  fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                    return TextFormField(
                      controller: controller,
                      focusNode: focusNode,
                      readOnly: row.isSaved,
                      decoration: InputDecoration(
                        labelText: 'Customer Name *',
                        hintText: 'Search customer name/no...',
                        isDense: true,
                        errorText: isInvalid && row.customerName.isEmpty ? 'Required' : null,
                        suffixIcon: const Icon(Icons.search, size: 18),
                      ),
                      onChanged: (v) => row.customerName = v,
                    );
                  },
                ),
                const SizedBox(height: 10),

                // Consumer Number & Solar Capacity
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: TextFormField(
                        key: ValueKey('${row.localId}_m_consumer_${row.customerId ?? "raw"}_${row.consumerNo}'),
                        initialValue: row.consumerNo,
                        readOnly: row.isSaved,
                        decoration: const InputDecoration(labelText: 'Consumer No', isDense: true),
                        onChanged: (v) => row.consumerNo = v.trim(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 2,
                      child: TextFormField(
                        key: ValueKey('${row.localId}_m_capacity_${row.customerId ?? "raw"}_${row.solarCapacity}'),
                        initialValue: row.solarCapacity != null ? row.solarCapacity.toString() : '',
                        readOnly: row.isSaved,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(labelText: 'Capacity (kW)', isDense: true),
                        onChanged: (v) => row.solarCapacity = double.tryParse(v),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Date & Manual Commission Amount
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.calendar_month, size: 16),
                        label: Text(_dateFormat.format(row.commissionDate)),
                        onPressed: row.isSaved
                            ? null
                            : () async {
                                final p = await showDatePicker(
                                  context: context,
                                  initialDate: row.commissionDate,
                                  firstDate: DateTime(2020),
                                  lastDate: DateTime(2035),
                                );
                                if (p != null) setState(() => row.commissionDate = p);
                              },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextFormField(
                        initialValue: row.commissionAmount != null ? row.commissionAmount.toString() : '',
                        readOnly: row.isSaved,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFF57C00)),
                        decoration: const InputDecoration(
                          labelText: 'Commission Amount *',
                          prefixText: '₹ ',
                          isDense: true,
                        ),
                        onChanged: (v) {
                          setState(() {
                            row.commissionAmount = double.tryParse(v.replaceAll(',', '').trim());
                          });
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Remarks
                TextFormField(
                  initialValue: row.remarks,
                  readOnly: row.isSaved,
                  decoration: const InputDecoration(labelText: 'Remarks', isDense: true),
                  onChanged: (v) => row.remarks = v,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Bottom Controls Bar
  // ---------------------------------------------------------------------------

  Widget _buildBottomControlsBar(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(top: BorderSide(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5))),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4, offset: const Offset(0, -2)),
        ],
      ),
      child: SafeArea(
        child: Wrap(
          spacing: 10,
          runSpacing: 10,
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            // Left row modification buttons
            Wrap(
              spacing: 8,
              children: [
                OutlinedButton.icon(
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add Row'),
                  onPressed: () => _addRow(),
                ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.playlist_add, size: 18),
                  label: const Text('+5 Rows'),
                  onPressed: () => _addMultipleRows(5),
                ),
                TextButton.icon(
                  icon: const Icon(Icons.delete_sweep, size: 18, color: Colors.red),
                  label: const Text('Clear Form', style: TextStyle(color: Colors.red)),
                  onPressed: _confirmClearForm,
                ),
              ],
            ),

            // Right action buttons
            Wrap(
              spacing: 10,
              children: [
                OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton.tonalIcon(
                  icon: const Icon(Icons.visibility_outlined, size: 18),
                  label: const Text('Preview Before Save'),
                  onPressed: _isSaving ? null : _handlePreviewBeforeSave,
                ),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFF57C00),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  ),
                  icon: _isSaving
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.save_outlined, size: 18),
                  label: Text(_isSaving ? 'Saving All...' : 'Save All (${_totalEntries})'),
                  onPressed: _isSaving ? null : _handlePreviewBeforeSave,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
