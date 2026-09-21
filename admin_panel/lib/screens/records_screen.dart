import 'dart:async';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import '../models/consumer_record.dart';
import '../services/record_service.dart';
import '../services/realtime_service.dart';
import '../widgets/record_form_dialog.dart';
import '../widgets/record_details_dialog.dart';
import '../widgets/import_dialog.dart';
import '../widgets/export_excel_button.dart';
import '../widgets/global_whatsapp_button.dart';
import '../widgets/work_completion_certificate_dialog.dart';
import '../services/excel_export_service.dart';
import '../services/export_definitions.dart';
import '../utils/responsive.dart';

class RecordsScreen extends StatefulWidget {
  final String? initialWorkflowQueue;
  final String? initialSiteType;

  const RecordsScreen({super.key, this.initialWorkflowQueue, this.initialSiteType});

  @override
  State<RecordsScreen> createState() => _RecordsScreenState();
}

class _RecordsScreenState extends State<RecordsScreen> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _verticalScrollController = ScrollController();
  final ScrollController _horizontalScrollController = ScrollController();
  Timer? _debounceTimer;

  bool _isLoading = false;
  List<ConsumerRecord> _records = [];
  int _totalCount = 0;
  int _currentPage = 1;
  final int _pageSize = 15;
  String _selectedStatus = 'All';
  String _selectedSiteType = 'All';
  String _selectedWorkflowQueue = 'All';
  String _workQueueScope = 'Active'; // 'Active', 'Completed', 'Old Applications', 'All'
  String _sortBy = 'updated_at';
  bool _sortAscending = false;

  // Multi-delete selection state
  final Set<String> _selectedRecordIds = {};
  bool _canDelete = true;
  bool _isDeleting = false;

  final List<String> _statusFilters = [
    'All',
    'Pending',
    'Approved',
    'In Progress',
    'Completed',
    'Rejected',
  ];

  StreamSubscription<ConsumerRecordChangeEvent>? _realtimeSub;

  @override
  void initState() {
    super.initState();
    if (widget.initialWorkflowQueue != null) {
      _selectedWorkflowQueue = widget.initialWorkflowQueue!;
      if (_selectedWorkflowQueue == 'Completed') {
        _workQueueScope = 'Completed';
      }
    }
    if (widget.initialSiteType != null) {
      _selectedSiteType = widget.initialSiteType!;
    }
    _checkDeletePermission();
    _loadRecords();
    _initRealtimeSync();
  }

  void _initRealtimeSync() {
    RealtimeSyncService.initialize();
    _realtimeSub = RealtimeSyncService.recordEvents.listen((event) {
      if (!mounted) return;

      if (event.type == RealtimeChangeType.update && event.record != null) {
        final updatedRecord = event.record!;
        final index = _records.indexWhere((r) => r.id == updatedRecord.id);

        if (index != -1) {
          // If record is now soft-deleted or completed (when scope is Active), evict
          if (updatedRecord.deleted || (_workQueueScope == 'Active' && updatedRecord.subsidyStatus.toLowerCase() == 'received')) {
            setState(() {
              _records.removeAt(index);
              _totalCount = (_totalCount > 0) ? _totalCount - 1 : 0;
            });
          } else {
            // Update in-place
            setState(() {
              _records[index] = updatedRecord;
            });
          }
        } else {
          // Re-fetch on new inserts
          _loadRecords();
        }

        // Show brief status snackbar
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Record #${updatedRecord.consumerNo} updated (${updatedRecord.status})'),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else if (event.type == RealtimeChangeType.insert && !event.record!.deleted) {
        // If on first page, refresh to show new insert
        if (_currentPage == 1) {
          _loadRecords();
        } else {
          setState(() => _totalCount += 1);
        }
      } else if (event.type == RealtimeChangeType.delete) {
        setState(() {
          _records.removeWhere((r) => r.id == event.recordId);
          _totalCount = (_totalCount > 0) ? _totalCount - 1 : 0;
        });
      }
    });
  }

  Future<void> _checkDeletePermission() async {
    final canDel = await RecordService.canCurrentUserDelete();
    if (mounted) {
      setState(() => _canDelete = canDel);
    }
  }

  @override
  void dispose() {
    _realtimeSub?.cancel();
    _searchController.dispose();
    _verticalScrollController.dispose();
    _horizontalScrollController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 350), () {
      setState(() {
        _currentPage = 1;
        _selectedRecordIds.clear();
      });
      _loadRecords();
    });
  }

  Future<void> _loadRecords() async {
    setState(() => _isLoading = true);

    try {
      final result = await RecordService.fetchRecords(
        page: _currentPage,
        pageSize: _pageSize,
        searchQuery: _searchController.text,
        statusFilter: _selectedStatus,
        siteTypeFilter: _selectedSiteType,
        workflowQueueFilter: _selectedWorkflowQueue,
        workQueueScope: _workQueueScope,
        sortBy: _sortBy,
        ascending: _sortAscending,
      );

      if (mounted) {
        setState(() {
          _records = result.items;
          _totalCount = result.totalCount;
          _isLoading = false;
          // Clean up selected IDs that may no longer be present
          final currentIds = _records.map((r) => r.id).whereType<String>().toSet();
          _selectedRecordIds.removeWhere((id) => !currentIds.contains(id));
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load records: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _toggleSelectAll(bool? checked) {
    setState(() {
      if (checked == true) {
        for (final r in _records) {
          if (r.id != null) {
            _selectedRecordIds.add(r.id!);
          }
        }
      } else {
        _selectedRecordIds.clear();
      }
    });
  }

  void _toggleRecordSelection(String id, bool? checked) {
    setState(() {
      if (checked == true) {
        _selectedRecordIds.add(id);
      } else {
        _selectedRecordIds.remove(id);
      }
    });
  }

  Future<void> _openAddRecordDialog() async {
    final created = await showDialog<bool>(
      context: context,
      builder: (_) => const RecordFormDialog(),
    );
    if (created == true) {
      _loadRecords();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Record created successfully')),
        );
      }
    }
  }

  Future<void> _openEditRecordDialog(ConsumerRecord record) async {
    final updated = await showDialog<bool>(
      context: context,
      builder: (_) => RecordFormDialog(initialRecord: record),
    );
    if (updated == true) {
      _loadRecords();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Record updated successfully')),
        );
      }
    }
  }

  Future<void> _openSingleDeleteDialog(ConsumerRecord record) async {
    if (record.id == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.delete_outline, color: Colors.red),
            const SizedBox(width: 8),
            const Text('Move to Recycle Bin?'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to delete "${record.name}" (Consumer No: ${record.consumerNo})?',
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 18, color: Colors.amber.shade800),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'This record will be moved to the Recycle Bin. An Administrator can restore it later.',
                      style: TextStyle(fontSize: 12, color: Colors.amber.shade900),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete Record'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await RecordService.deleteRecord(record.id!, consumerNo: record.consumerNo);
        _selectedRecordIds.remove(record.id);
        _loadRecords();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Record moved to Recycle Bin'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to delete: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _handleBulkDelete() async {
    if (_selectedRecordIds.isEmpty) return;

    final count = _selectedRecordIds.length;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 28),
            const SizedBox(width: 10),
            const Text('Delete Selected Records?'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'You are about to delete $count selected records.',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'These records will be removed from the active list and moved to the Recycle Bin.',
              style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.recycling_rounded, size: 20, color: Colors.blue.shade800),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Safety feature: Soft-delete is active. An Admin can view and restore these records from the Recycle Bin at any time.',
                      style: TextStyle(fontSize: 12, color: Colors.blue.shade900),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            icon: const Icon(Icons.delete_forever, size: 18),
            label: Text('Delete $count Records'),
            onPressed: () => Navigator.of(ctx).pop(true),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => _isDeleting = true);

      try {
        final idsToDelete = _selectedRecordIds.toList();
        final deletedCount = await RecordService.softDeleteMultipleRecords(idsToDelete);

        if (mounted) {
          setState(() {
            _selectedRecordIds.clear();
            _isDeleting = false;
          });

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('$deletedCount records successfully moved to Recycle Bin'),
              backgroundColor: Colors.green.shade800,
            ),
          );

          _loadRecords();
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isDeleting = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to delete records: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  void _openDetailsDialog(ConsumerRecord record) {
    showDialog(
      context: context,
      builder: (_) => RecordDetailsDialog(record: record),
    );
  }

  Future<List<ConsumerRecord>> _fetchFilteredRecordsForExport() async {
    final result = await RecordService.fetchRecords(
      page: 1,
      pageSize: 10000,
      searchQuery: _searchController.text.trim().isEmpty ? null : _searchController.text.trim(),
      statusFilter: _selectedStatus == 'All' ? null : _selectedStatus,
      siteTypeFilter: _selectedSiteType == 'All' ? null : _selectedSiteType,
      workflowQueueFilter: _selectedWorkflowQueue == 'All' ? null : _selectedWorkflowQueue,
      workQueueScope: _workQueueScope,
      sortBy: _sortBy,
      ascending: _sortAscending,
    );
    return result.items;
  }

  static final List<ExcelColumnDef<ConsumerRecord>> _consumerExcelColumns = [
    ExcelColumnDef(header: 'Consumer No', valueExtractor: (r) => r.consumerNo),
    ExcelColumnDef(header: 'Customer Name', valueExtractor: (r) => r.name),
    ExcelColumnDef(header: 'Site Type', valueExtractor: (r) => r.siteType),
    ExcelColumnDef(header: 'Mobile No', valueExtractor: (r) => r.mobile ?? '—'),
    ExcelColumnDef(header: 'Application ID', valueExtractor: (r) => r.applicationId ?? '—'),
    ExcelColumnDef(header: 'System Capacity', valueExtractor: (r) => r.systemCapacity ?? '—'),
    ExcelColumnDef(header: 'System Type', valueExtractor: (r) => r.systemType ?? '—'),
    ExcelColumnDef(header: 'Overall Stage', valueExtractor: (r) => r.overallStage),
    ExcelColumnDef(header: 'Application Status', valueExtractor: (r) => r.status),
    ExcelColumnDef(header: 'Agreement Status', valueExtractor: (r) => r.agreementStatus),
    ExcelColumnDef(header: 'Loan Required', valueExtractor: (r) => r.loanRequired),
    ExcelColumnDef(header: 'Loan Status', valueExtractor: (r) => r.loanStatus),
    ExcelColumnDef(header: 'Installation Status', valueExtractor: (r) => r.installationStatus),
    ExcelColumnDef(header: 'RTS Status', valueExtractor: (r) => r.rtsStatus),
    ExcelColumnDef(header: 'Subsidy Status', valueExtractor: (r) => r.isNonSubsidy ? 'N/A (Non-Subsidy)' : r.subsidyStatus),
    ExcelColumnDef(header: 'Work State', valueExtractor: (r) => r.customerWorkState),
    ExcelColumnDef(header: 'Application Date', valueExtractor: (r) => r.applicationDate),
    ExcelColumnDef(header: 'Submit Date', valueExtractor: (r) => r.submitDate),
    ExcelColumnDef(header: 'Days in Stage', valueExtractor: (r) => r.daysInCurrentStage),
    ExcelColumnDef(header: 'Priority', valueExtractor: (r) => r.priorityCategory),
    ExcelColumnDef(header: 'Assigned Staff', valueExtractor: (r) => r.createdBy ?? '—'),
    ExcelColumnDef(header: 'Village / Address', valueExtractor: (r) => r.address ?? '—'),
    ExcelColumnDef(header: 'Remarks', valueExtractor: (r) => r.remarks ?? '—'),
  ];

  void _openImportDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => ImportDialog(
        onImportSuccess: () {
          _loadRecords();
        },
      ),
    );
  }

  void _showMobileFilterBottomSheet(BuildContext context) {
    final theme = Theme.of(context);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: theme.colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Filter Customer Records', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                      ],
                    ),
                    const Divider(),
                    const SizedBox(height: 10),
                    const Text('SCOPE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.8)),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      value: _workQueueScope,
                      decoration: const InputDecoration(isDense: true, border: OutlineInputBorder()),
                      items: const [
                        DropdownMenuItem(value: 'Active', child: Text('⚡ Active Customers')),
                        DropdownMenuItem(value: 'No Action Required', child: Text('⏸️ Hold / No Action')),
                        DropdownMenuItem(value: 'Completed', child: Text('✅ Completed Customers')),
                        DropdownMenuItem(value: 'Old Applications', child: Text('⏳ Old Applications (≥60 Days)')),
                        DropdownMenuItem(value: 'All', child: Text('🌐 All Customers')),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setState(() {
                            _workQueueScope = val;
                            _currentPage = 1;
                            _selectedRecordIds.clear();
                          });
                          setSheetState(() {});
                          _loadRecords();
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    const Text('QUEUE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.8)),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      value: _selectedWorkflowQueue,
                      decoration: const InputDecoration(isDense: true, border: OutlineInputBorder()),
                      items: const [
                        DropdownMenuItem(value: 'All', child: Text('All Queues')),
                        DropdownMenuItem(value: 'Agreement Pending', child: Text('⚡ Agreement Pending')),
                        DropdownMenuItem(value: 'Loan Pending', child: Text('💰 Loan Pending')),
                        DropdownMenuItem(value: 'Installation Pending', child: Text('🔧 Installation Pending')),
                        DropdownMenuItem(value: 'RTS Pending', child: Text('⚡ RTS Pending')),
                        DropdownMenuItem(value: 'Subsidy Pending', child: Text('🏛️ Subsidy Pending')),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setState(() {
                            _selectedWorkflowQueue = val;
                            _currentPage = 1;
                            _selectedRecordIds.clear();
                          });
                          setSheetState(() {});
                          _loadRecords();
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    const Text('SITE TYPE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.8)),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      value: _selectedSiteType,
                      decoration: const InputDecoration(isDense: true, border: OutlineInputBorder()),
                      items: const [
                        DropdownMenuItem(value: 'All', child: Text('All Sites')),
                        DropdownMenuItem(value: 'Subsidy', child: Text('Subsidy')),
                        DropdownMenuItem(value: 'Non-Subsidy', child: Text('Non-Subsidy')),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setState(() {
                            _selectedSiteType = val;
                            _currentPage = 1;
                            _selectedRecordIds.clear();
                          });
                          setSheetState(() {});
                          _loadRecords();
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    const Text('STATUS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.8)),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      value: _selectedStatus,
                      decoration: const InputDecoration(isDense: true, border: OutlineInputBorder()),
                      items: _statusFilters.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setState(() {
                            _selectedStatus = val;
                            _currentPage = 1;
                            _selectedRecordIds.clear();
                          });
                          setSheetState(() {});
                          _loadRecords();
                        }
                      },
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Apply Filters'),
                      ),
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isMobile = Responsive.isMobile(context);
    final totalPages = (_totalCount / _pageSize).ceil();

    final allCurrentPageSelected = _records.isNotEmpty &&
        _records.every((r) => r.id != null && _selectedRecordIds.contains(r.id));
    final hasSomeSelected = _selectedRecordIds.isNotEmpty;

    return Padding(
      padding: EdgeInsets.all(isMobile ? 12.0 : 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Bar
          if (isMobile)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Consumer Records',
                      style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    FilledButton.icon(
                      onPressed: _openAddRecordDialog,
                      style: FilledButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Add'),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Manage solar consumer profiles & statuses',
                  style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 12),
                ),
              ],
            )
          else
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Consumer Records',
                      style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Manage solar consumer profiles and installation statuses',
                      style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
                Row(
                  children: [
                    ExportExcelButton<ConsumerRecord>(
                      filePrefix: 'Solar_Consumers',
                      sheetName: 'Consumer Records',
                      reportTitle: 'Consumer Master Records',
                      filterSummary: 'Scope: $_workQueueScope, Queue: $_selectedWorkflowQueue, Status: $_selectedStatus${_searchController.text.trim().isNotEmpty ? ', Search: "${_searchController.text.trim()}"' : ''}',
                      columns: ExportDefinitions.consumerRecordColumns,
                      onFetchFullDataset: _fetchFilteredRecordsForExport,
                    ),
                    const SizedBox(width: 12),
                    OutlinedButton.icon(
                      onPressed: _openImportDialog,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                        side: BorderSide(color: theme.colorScheme.primary),
                      ),
                      icon: const Icon(Icons.upload_file_rounded),
                      label: const Text('Import Excel / CSV'),
                    ),
                    const SizedBox(width: 12),
                    FilledButton.icon(
                      onPressed: _openAddRecordDialog,
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                      ),
                      icon: const Icon(Icons.add),
                      label: const Text('Add Record'),
                    ),
                  ],
                ),
              ],
            ),
          const SizedBox(height: 16),

          // Filters & Search Bar
          if (isMobile)
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    onChanged: _onSearchChanged,
                    decoration: InputDecoration(
                      hintText: 'Search consumer name, mobile, no...',
                      prefixIcon: const Icon(Icons.search, size: 20),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              onPressed: () {
                                _searchController.clear();
                                _loadRecords();
                              },
                            )
                          : null,
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filledTonal(
                  icon: const Icon(Icons.tune_rounded),
                  tooltip: 'Filter',
                  onPressed: () => _showMobileFilterBottomSheet(context),
                ),
                IconButton.outlined(
                  icon: const Icon(Icons.refresh, size: 20),
                  tooltip: 'Refresh',
                  onPressed: () {
                    _selectedRecordIds.clear();
                    _loadRecords();
                  },
                ),
              ],
            )
          else
            Card(
              elevation: 1,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextField(
                        controller: _searchController,
                        onChanged: _onSearchChanged,
                        decoration: InputDecoration(
                          hintText: 'Search by Consumer No, Name, Mobile, or App ID...',
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: _searchController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear),
                                  onPressed: () {
                                    _searchController.clear();
                                    _loadRecords();
                                  },
                                )
                              : null,
                          border: const OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('SCOPE', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 0.8, color: theme.colorScheme.onSurfaceVariant)),
                        const SizedBox(height: 2),
                        DropdownButtonHideUnderline(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              border: Border.all(color: theme.colorScheme.primary),
                              borderRadius: BorderRadius.circular(8),
                              color: theme.colorScheme.primaryContainer.withValues(alpha: 0.2),
                            ),
                            child: DropdownButton<String>(
                              value: _workQueueScope,
                              items: const [
                                DropdownMenuItem(value: 'Active', child: Text('⚡ Active Customers', style: TextStyle(fontWeight: FontWeight.bold))),
                                DropdownMenuItem(value: 'No Action Required', child: Text('⏸️ Hold / No Action Required')),
                                DropdownMenuItem(value: 'Completed', child: Text('✅ Completed Customers')),
                                DropdownMenuItem(value: 'Old Applications', child: Text('⏳ Old Applications (≥60 Days)')),
                                DropdownMenuItem(value: 'All', child: Text('🌐 All Customers')),
                              ],
                              onChanged: (val) {
                                if (val != null) {
                                  setState(() {
                                    _workQueueScope = val;
                                    _currentPage = 1;
                                    _selectedRecordIds.clear();
                                  });
                                  _loadRecords();
                                }
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('QUEUE', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 0.8, color: theme.colorScheme.onSurfaceVariant)),
                        const SizedBox(height: 2),
                        DropdownButtonHideUnderline(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              border: Border.all(color: const Color(0xFFD97706)),
                              borderRadius: BorderRadius.circular(8),
                              color: const Color(0xFFFFFBEB),
                            ),
                            child: DropdownButton<String>(
                              value: _selectedWorkflowQueue,
                              items: const [
                                DropdownMenuItem(value: 'All', child: Text('All Queues', style: TextStyle(fontWeight: FontWeight.bold))),
                                DropdownMenuItem(value: 'Agreement Pending', child: Text('⚡ Agreement Pending')),
                                DropdownMenuItem(value: 'Loan Pending', child: Text('💰 Loan Pending')),
                                DropdownMenuItem(value: 'Installation Pending', child: Text('🔧 Installation Pending')),
                                DropdownMenuItem(value: 'RTS Pending', child: Text('⚡ RTS Pending')),
                                DropdownMenuItem(value: 'Subsidy Pending', child: Text('🏛️ Subsidy Pending')),
                              ],
                              onChanged: (val) {
                                if (val != null) {
                                  setState(() {
                                    _selectedWorkflowQueue = val;
                                    _currentPage = 1;
                                    _selectedRecordIds.clear();
                                  });
                                  _loadRecords();
                                }
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('SITE TYPE', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 0.8, color: theme.colorScheme.onSurfaceVariant)),
                        const SizedBox(height: 2),
                        DropdownButtonHideUnderline(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.purple.shade400),
                              borderRadius: BorderRadius.circular(8),
                              color: Colors.purple.shade50.withValues(alpha: 0.3),
                            ),
                            child: DropdownButton<String>(
                              value: _selectedSiteType,
                              items: const [
                                DropdownMenuItem(value: 'All', child: Text('All Sites', style: TextStyle(fontWeight: FontWeight.bold))),
                                DropdownMenuItem(value: 'Subsidy', child: Text('Subsidy')),
                                DropdownMenuItem(value: 'Non-Subsidy', child: Text('Non-Subsidy')),
                              ],
                              onChanged: (val) {
                                if (val != null) {
                                  setState(() {
                                    _selectedSiteType = val;
                                    _currentPage = 1;
                                    _selectedRecordIds.clear();
                                  });
                                  _loadRecords();
                                }
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('STATUS', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 0.8, color: theme.colorScheme.onSurfaceVariant)),
                        const SizedBox(height: 2),
                        DropdownButtonHideUnderline(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey.shade400),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: DropdownButton<String>(
                              value: _selectedStatus,
                              items: _statusFilters
                                  .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                                  .toList(),
                              onChanged: (val) {
                                if (val != null) {
                                  setState(() {
                                    _selectedStatus = val;
                                    _currentPage = 1;
                                    _selectedRecordIds.clear();
                                  });
                                  _loadRecords();
                                }
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 16),
                    IconButton.outlined(
                      icon: const Icon(Icons.refresh),
                      tooltip: 'Refresh Records',
                      onPressed: () {
                        _selectedRecordIds.clear();
                        _loadRecords();
                      },
                    ),
                  ],
                ),
              ),
            ),

          // Multi-Select Action Bar
          if (hasSomeSelected) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFFECACA)),
              ),
              child: Row(
                children: [
                  Icon(Icons.check_box, color: Colors.red.shade700, size: 20),
                  const SizedBox(width: 10),
                  Text(
                    '${_selectedRecordIds.length} selected',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: Colors.red.shade900,
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => setState(() => _selectedRecordIds.clear()),
                    child: const Text('Deselect All'),
                  ),
                  const SizedBox(width: 8),
                  if (_canDelete)
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.red.shade700,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      icon: _isDeleting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.delete_outline, size: 18),
                      label: Text('Delete (${_selectedRecordIds.length})'),
                      onPressed: _isDeleting ? null : _handleBulkDelete,
                    ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 12),

          // Content: Cards on Mobile vs Table on Desktop
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _records.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.inbox_outlined, size: 56, color: Colors.grey.shade400),
                            const SizedBox(height: 12),
                            const Text(
                              'No records found',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 6),
                            const Text('Try adjusting your search query or add a new record.', style: TextStyle(fontSize: 12)),
                          ],
                        ),
                      )
                    : isMobile
                        ? ListView.builder(
                            itemCount: _records.length,
                            itemBuilder: (ctx, index) => _buildMobileCustomerCard(_records[index], theme),
                          )
                        : Card(
                            elevation: 2,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            clipBehavior: Clip.antiAlias,
                            child: ScrollConfiguration(
                              behavior: ScrollConfiguration.of(context).copyWith(
                                dragDevices: {
                                  PointerDeviceKind.touch,
                                  PointerDeviceKind.mouse,
                                  PointerDeviceKind.trackpad,
                                  PointerDeviceKind.stylus,
                                },
                              ),
                              child: Scrollbar(
                                controller: _verticalScrollController,
                                thumbVisibility: true,
                                trackVisibility: true,
                                child: SingleChildScrollView(
                                  controller: _verticalScrollController,
                                  scrollDirection: Axis.vertical,
                                  child: Scrollbar(
                                    controller: _horizontalScrollController,
                                    thumbVisibility: true,
                                    trackVisibility: true,
                                    child: SingleChildScrollView(
                                      controller: _horizontalScrollController,
                                      scrollDirection: Axis.horizontal,
                                      child: DataTable(
                                        headingRowColor: WidgetStateProperty.all(
                                          theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                                        ),
                                        columns: [
                                          DataColumn(
                                            label: Row(
                                              children: [
                                                Checkbox(
                                                  value: allCurrentPageSelected,
                                                  tristate: hasSomeSelected && !allCurrentPageSelected,
                                                  onChanged: _toggleSelectAll,
                                                ),
                                                const Text('Customer Name', style: TextStyle(fontWeight: FontWeight.bold)),
                                              ],
                                            ),
                                          ),
                                          const DataColumn(label: Text('Consumer No', style: TextStyle(fontWeight: FontWeight.bold))),
                                          const DataColumn(label: Text('Application Date', style: TextStyle(fontWeight: FontWeight.bold))),
                                          const DataColumn(label: Text('Application Days', style: TextStyle(fontWeight: FontWeight.bold))),
                                          const DataColumn(label: Text('Work Stage', style: TextStyle(fontWeight: FontWeight.bold))),
                                          const DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.bold))),
                                          const DataColumn(label: Text('Action Required', style: TextStyle(fontWeight: FontWeight.bold))),
                                          const DataColumn(label: Text('Next Action', style: TextStyle(fontWeight: FontWeight.bold))),
                                          const DataColumn(label: Text('Days in Stage', style: TextStyle(fontWeight: FontWeight.bold))),
                                          const DataColumn(label: Text('Priority', style: TextStyle(fontWeight: FontWeight.bold))),
                                          const DataColumn(label: Text('Staff', style: TextStyle(fontWeight: FontWeight.bold))),
                                          const DataColumn(label: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold))),
                                        ],
                                        rows: _records.map((r) {
                                          final isSelected = r.id != null && _selectedRecordIds.contains(r.id);

                                          final appDateStr = r.applicationDate != null
                                              ? r.applicationDate!.toLocal().toString().split(' ')[0]
                                              : '—';

                                          return DataRow(
                                            selected: isSelected,
                                            onSelectChanged: r.id != null
                                                ? (val) => _toggleRecordSelection(r.id!, val)
                                                : null,
                                            cells: [
                                              DataCell(
                                                Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    Checkbox(
                                                      value: isSelected,
                                                      onChanged: r.id != null
                                                          ? (val) => _toggleRecordSelection(r.id!, val)
                                                          : null,
                                                    ),
                                                    InkWell(
                                                      onTap: () => _openDetailsDialog(r),
                                                      child: Text(
                                                        r.name,
                                                        style: const TextStyle(
                                                          fontWeight: FontWeight.w600,
                                                          color: Color(0xFF2563EB),
                                                          decoration: TextDecoration.underline,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              DataCell(
                                                Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    InkWell(
                                                      onTap: () => _openDetailsDialog(r),
                                                      child: Text(
                                                        r.consumerNo,
                                                        style: const TextStyle(fontWeight: FontWeight.w500),
                                                      ),
                                                    ),
                                                    if (r.isNonSubsidy) ...[
                                                      const SizedBox(width: 6),
                                                      Container(
                                                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                                        decoration: BoxDecoration(
                                                          color: Colors.purple.shade50,
                                                          borderRadius: BorderRadius.circular(4),
                                                          border: Border.all(color: Colors.purple.shade200),
                                                        ),
                                                        child: Text(
                                                          'Non-Subsidy',
                                                          style: TextStyle(
                                                            fontSize: 10,
                                                            fontWeight: FontWeight.bold,
                                                            color: Colors.purple.shade700,
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ],
                                                ),
                                              ),
                                              DataCell(Text(appDateStr)),
                                              DataCell(
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                                  decoration: BoxDecoration(
                                                    color: Colors.blue.shade50,
                                                    borderRadius: BorderRadius.circular(4),
                                                  ),
                                                  child: Text(
                                                    '${r.applicationDays} Days',
                                                    style: TextStyle(
                                                      fontWeight: FontWeight.bold,
                                                      color: Colors.blue.shade900,
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              DataCell(_buildWorkflowStageBadge(r)),
                                              DataCell(_buildStatusBadge(r.status)),
                                              DataCell(_buildActionRequiredBadge(r.actionRequired)),
                                              DataCell(
                                                Text(
                                                  r.nextAction,
                                                  style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 12),
                                                ),
                                              ),
                                              DataCell(
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                                  decoration: BoxDecoration(
                                                    color: Colors.amber.shade50,
                                                    borderRadius: BorderRadius.circular(4),
                                                  ),
                                                  child: Text(
                                                    '${r.daysInCurrentStage} Days',
                                                    style: TextStyle(
                                                      fontWeight: FontWeight.bold,
                                                      color: Colors.amber.shade900,
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              DataCell(_buildPriorityCategoryBadge(r.priorityCategory)),
                                              DataCell(Text(r.createdBy ?? 'Unassigned')),
                                              DataCell(
                                                Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    GlobalWhatsAppButton(
                                                      phoneNumber: r.mobile,
                                                      customerName: r.name,
                                                      consumerNo: r.consumerNo,
                                                      currentStage: r.overallStage,
                                                    ),
                                                    IconButton(
                                                      icon: const Icon(Icons.edit, size: 18),
                                                      tooltip: 'Edit Record',
                                                      onPressed: () => _openEditRecordDialog(r),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          );
                                        }).toList(),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
          ),

          // Pagination Bar
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Showing ${(_currentPage - 1) * _pageSize + (_records.isEmpty ? 0 : 1)} - ${(_currentPage - 1) * _pageSize + _records.length} of $_totalCount',
                style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 12),
              ),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left, size: 20),
                    onPressed: _currentPage > 1
                        ? () {
                            setState(() {
                              _currentPage--;
                              _selectedRecordIds.clear();
                            });
                            _loadRecords();
                          }
                        : null,
                  ),
                  Text('$_currentPage / ${totalPages == 0 ? 1 : totalPages}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  IconButton(
                    icon: const Icon(Icons.chevron_right, size: 20),
                    onPressed: _currentPage < totalPages
                        ? () {
                            setState(() {
                              _currentPage++;
                              _selectedRecordIds.clear();
                            });
                            _loadRecords();
                          }
                        : null,
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMobileCustomerCard(ConsumerRecord r, ThemeData theme) {
    final isSelected = r.id != null && _selectedRecordIds.contains(r.id);
    final appDateStr = r.applicationDate != null
        ? r.applicationDate!.toLocal().toString().split(' ')[0]
        : '—';

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isSelected
              ? theme.colorScheme.primary
              : theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
          width: isSelected ? 2 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (r.id != null)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: Checkbox(
                      value: isSelected,
                      visualDensity: VisualDensity.compact,
                      onChanged: (val) => _toggleRecordSelection(r.id!, val),
                    ),
                  ),
                Expanded(
                  child: InkWell(
                    onTap: () => _openDetailsDialog(r),
                    child: Text(
                      r.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: Color(0xFF2563EB),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                _buildStatusBadge(r.status),
              ],
            ),
            const SizedBox(height: 6),

            Row(
              children: [
                Text('No: ${r.consumerNo}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                if (r.isNonSubsidy) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                      color: Colors.purple.shade50,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Colors.purple.shade200),
                    ),
                    child: Text(
                      'Non-Subsidy',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.purple.shade700),
                    ),
                  ),
                ],
                if (r.village != null && r.village!.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text('📍 ${r.village}', style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 12), overflow: TextOverflow.ellipsis),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 8),

            Row(
              children: [
                _buildWorkflowStageBadge(r),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '${r.applicationDays} Days',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade900,
                      fontSize: 10,
                    ),
                  ),
                ),
                const Spacer(),
                GlobalWhatsAppButton(
                  phoneNumber: r.mobile,
                  customerName: r.name,
                  consumerNo: r.consumerNo,
                  currentStage: r.overallStage,
                ),
              ],
            ),
            const SizedBox(height: 8),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'App Date: $appDateStr',
                  style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant),
                ),
                FilledButton.tonalIcon(
                  onPressed: () => _openDetailsDialog(r),
                  style: FilledButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  ),
                  icon: const Icon(Icons.open_in_new_rounded, size: 14),
                  label: const Text('Open Profile', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ],
        ),
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        status,
        style: TextStyle(color: fg, fontWeight: FontWeight.bold, fontSize: 12),
      ),
    );
  }

  Widget _buildWorkflowStageBadge(ConsumerRecord record) {
    if (record.isNoActionRequired) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFFFEF3C7),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: const Color(0xFFF59E0B)),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.pause_circle_filled, size: 14, color: Color(0xFFD97706)),
            SizedBox(width: 4),
            Text(
              'HOLD',
              style: TextStyle(color: Color(0xFF92400E), fontWeight: FontWeight.bold, fontSize: 11),
            ),
          ],
        ),
      );
    }

    final stage = record.overallStage;
    Color bg;
    Color fg;
    IconData icon;

    switch (stage) {
      case 'Completed':
        bg = const Color(0xFFECFDF5);
        fg = const Color(0xFF047857);
        icon = Icons.check_circle_rounded;
        break;
      case 'Subsidy':
        bg = const Color(0xFFF0FDF4);
        fg = const Color(0xFF16A34A);
        icon = Icons.currency_rupee_rounded;
        break;
      case 'RTS':
        bg = const Color(0xFFF5F3FF);
        fg = const Color(0xFF7C3AED);
        icon = Icons.electric_meter_rounded;
        break;
      case 'Installation':
        bg = const Color(0xFFF0FDFA);
        fg = const Color(0xFF0F766E);
        icon = Icons.build_circle_rounded;
        break;
      case 'Loan':
        bg = const Color(0xFFFFFBEB);
        fg = const Color(0xFFD97706);
        icon = Icons.account_balance_rounded;
        break;
      case 'Agreement':
        bg = const Color(0xFFEFF6FF);
        fg = const Color(0xFF2563EB);
        icon = Icons.history_edu_rounded;
        break;
      case 'Application':
      default:
        bg = const Color(0xFFF8FAFC);
        fg = const Color(0xFF475569);
        icon = Icons.assignment_rounded;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: fg.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: fg),
          const SizedBox(width: 4),
          Text(
            stage,
            style: TextStyle(color: fg, fontWeight: FontWeight.bold, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _buildActionRequiredBadge(String action) {
    Color bg;
    Color fg;
    IconData icon;

    switch (action) {
      case 'Agreement':
        bg = const Color(0xFFEFF6FF);
        fg = const Color(0xFF2563EB);
        icon = Icons.history_edu_rounded;
        break;
      case 'Loan':
        bg = const Color(0xFFFFFBEB);
        fg = const Color(0xFFD97706);
        icon = Icons.account_balance_rounded;
        break;
      case 'Installation':
        bg = const Color(0xFFF0FDFA);
        fg = const Color(0xFF0F766E);
        icon = Icons.build_circle_rounded;
        break;
      case 'RTS':
        bg = const Color(0xFFF5F3FF);
        fg = const Color(0xFF7C3AED);
        icon = Icons.electric_meter_rounded;
        break;
      case 'Subsidy':
        bg = const Color(0xFFF0FDF4);
        fg = const Color(0xFF16A34A);
        icon = Icons.currency_rupee_rounded;
        break;
      case 'None':
      default:
        bg = const Color(0xFFF1F5F9);
        fg = const Color(0xFF64748B);
        icon = Icons.check_circle_outline;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: fg.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: fg),
          const SizedBox(width: 4),
          Text(
            action,
            style: TextStyle(color: fg, fontWeight: FontWeight.bold, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _buildPriorityCategoryBadge(String priority) {
    Color bg;
    Color fg;

    switch (priority) {
      case 'Critical Active Work':
        bg = const Color(0xFFFEF2F2);
        fg = const Color(0xFFDC2626);
        break;
      case 'High Active Work':
        bg = const Color(0xFFFFEDD5);
        fg = const Color(0xFFEA580C);
        break;
      case 'Medium Active Work':
        bg = const Color(0xFFFEF3C7);
        fg = const Color(0xFFD97706);
        break;
      case 'Normal Active Work':
        bg = const Color(0xFFDCFCE7);
        fg = const Color(0xFF16A34A);
        break;
      case 'Processing':
        bg = const Color(0xFFF0F9FF);
        fg = const Color(0xFF0284C7);
        break;
      case 'Completed':
      default:
        bg = const Color(0xFFF1F5F9);
        fg = const Color(0xFF64748B);
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        priority,
        style: TextStyle(color: fg, fontWeight: FontWeight.bold, fontSize: 11),
      ),
    );
  }
}
