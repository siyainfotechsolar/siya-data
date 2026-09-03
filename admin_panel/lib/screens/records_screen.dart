import 'dart:async';
import 'package:flutter/material.dart';
import '../models/consumer_record.dart';
import '../services/record_service.dart';
import '../services/realtime_service.dart';
import '../widgets/record_form_dialog.dart';
import '../widgets/record_details_dialog.dart';
import '../widgets/import_dialog.dart';

class RecordsScreen extends StatefulWidget {
  const RecordsScreen({super.key});

  @override
  State<RecordsScreen> createState() => _RecordsScreenState();
}

class _RecordsScreenState extends State<RecordsScreen> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounceTimer;

  bool _isLoading = false;
  List<ConsumerRecord> _records = [];
  int _totalCount = 0;
  int _currentPage = 1;
  final int _pageSize = 15;
  String _selectedStatus = 'All';
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
          // If record is now soft-deleted, remove from active list
          if (updatedRecord.deleted) {
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
        } else if (!updatedRecord.deleted && _currentPage == 1) {
          // New/restored record might belong on current view
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final totalPages = (_totalCount / _pageSize).ceil();

    final allCurrentPageSelected = _records.isNotEmpty &&
        _records.every((r) => r.id != null && _selectedRecordIds.contains(r.id));
    final hasSomeSelected = _selectedRecordIds.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Bar
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
          const SizedBox(height: 20),

          // Filters & Search Bar
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
                  DropdownButtonHideUnderline(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade400),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: DropdownButton<String>(
                        value: _selectedStatus,
                        items: _statusFilters
                            .map((s) => DropdownMenuItem(value: s, child: Text('Status: $s')))
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

          // Multi-Select Action Bar (Shows when records are selected)
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
                    '${_selectedRecordIds.length} record(s) selected',
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
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      ),
                      icon: _isDeleting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.delete_outline, size: 18),
                      label: Text('Delete Selected (${_selectedRecordIds.length})'),
                      onPressed: _isDeleting ? null : _handleBulkDelete,
                    )
                  else
                    Tooltip(
                      message: 'Only Administrators or Staff with delete permission can delete records',
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.grey.shade400,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        ),
                        icon: const Icon(Icons.lock_outline, size: 18),
                        label: const Text('Delete (No Permission)'),
                        onPressed: null,
                      ),
                    ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 16),

          // Records Table
          Expanded(
            child: Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              clipBehavior: Clip.antiAlias,
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _records.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.inbox_outlined, size: 64, color: Colors.grey.shade400),
                              const SizedBox(height: 16),
                              const Text(
                                'No records found',
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 8),
                              const Text('Try adjusting your search query or add a new record.'),
                            ],
                          ),
                        )
                      : SingleChildScrollView(
                          scrollDirection: Axis.vertical,
                          child: SingleChildScrollView(
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
                                      const Text('Consumer No', style: TextStyle(fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                ),
                                const DataColumn(label: Text('Name', style: TextStyle(fontWeight: FontWeight.bold))),
                                const DataColumn(label: Text('Mobile', style: TextStyle(fontWeight: FontWeight.bold))),
                                const DataColumn(label: Text('App ID', style: TextStyle(fontWeight: FontWeight.bold))),
                                const DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.bold))),
                                const DataColumn(label: Text('Last Updated', style: TextStyle(fontWeight: FontWeight.bold))),
                                const DataColumn(label: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold))),
                              ],
                              rows: _records.map((r) {
                                final isSelected = r.id != null && _selectedRecordIds.contains(r.id);

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
                                          Text(
                                            r.consumerNo,
                                            style: const TextStyle(fontWeight: FontWeight.w600),
                                          ),
                                        ],
                                      ),
                                    ),
                                    DataCell(Text(r.name)),
                                    DataCell(Text(r.mobile ?? '—')),
                                    DataCell(Text(r.applicationId ?? '—')),
                                    DataCell(_buildStatusBadge(r.status)),
                                    DataCell(
                                      Text(
                                        r.updatedAt != null
                                            ? r.updatedAt!.toLocal().toString().split(' ')[0]
                                            : '—',
                                      ),
                                    ),
                                    DataCell(
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          IconButton(
                                            icon: const Icon(Icons.visibility_outlined, size: 20),
                                            tooltip: 'View Details',
                                            onPressed: () => _openDetailsDialog(r),
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.edit_outlined, size: 20),
                                            tooltip: 'Edit Record',
                                            onPressed: () => _openEditRecordDialog(r),
                                          ),
                                          if (_canDelete)
                                            IconButton(
                                              icon: const Icon(Icons.delete_outline, size: 20, color: Colors.red),
                                              tooltip: 'Delete Record',
                                              onPressed: () => _openSingleDeleteDialog(r),
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

          // Pagination Bar
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Showing ${(_currentPage - 1) * _pageSize + (_records.isEmpty ? 0 : 1)} - ${(_currentPage - 1) * _pageSize + _records.length} of $_totalCount records',
                style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
              ),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left),
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
                  Text('Page $_currentPage of ${totalPages == 0 ? 1 : totalPages}'),
                  IconButton(
                    icon: const Icon(Icons.chevron_right),
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
}
