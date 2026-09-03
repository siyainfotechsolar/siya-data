import 'dart:async';
import 'package:flutter/material.dart';
import '../models/consumer_record.dart';
import '../services/record_service.dart';

class RecycleBinScreen extends StatefulWidget {
  const RecycleBinScreen({super.key});

  @override
  State<RecycleBinScreen> createState() => _RecycleBinScreenState();
}

class _RecycleBinScreenState extends State<RecycleBinScreen> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounceTimer;

  bool _isLoading = false;
  List<ConsumerRecord> _deletedRecords = [];
  int _totalCount = 0;
  int _currentPage = 1;
  final int _pageSize = 15;

  final Set<String> _selectedRecordIds = {};
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _loadDeletedRecords();
  }

  @override
  void dispose() {
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
      _loadDeletedRecords();
    });
  }

  Future<void> _loadDeletedRecords() async {
    setState(() => _isLoading = true);

    try {
      final result = await RecordService.fetchDeletedRecords(
        page: _currentPage,
        pageSize: _pageSize,
        searchQuery: _searchController.text,
      );

      if (mounted) {
        setState(() {
          _deletedRecords = result.items;
          _totalCount = result.totalCount;
          _isLoading = false;
          final currentIds = _deletedRecords.map((r) => r.id).whereType<String>().toSet();
          _selectedRecordIds.removeWhere((id) => !currentIds.contains(id));
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load deleted records: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _toggleSelectAll(bool? checked) {
    setState(() {
      if (checked == true) {
        for (final r in _deletedRecords) {
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

  Future<void> _handleRestoreSelected() async {
    if (_selectedRecordIds.isEmpty) return;

    final count = _selectedRecordIds.length;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.restore_from_trash, color: Colors.green, size: 28),
            const SizedBox(width: 10),
            const Text('Restore Records?'),
          ],
        ),
        content: Text(
          'Restore $count selected records? They will immediately reappear in the active Consumer Records table.',
          style: const TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.green.shade700),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('Restore ($count)'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => _isProcessing = true);

      try {
        final restored = await RecordService.restoreRecords(_selectedRecordIds.toList());

        if (mounted) {
          setState(() {
            _selectedRecordIds.clear();
            _isProcessing = false;
          });

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('$restored records restored successfully'),
              backgroundColor: Colors.green.shade800,
            ),
          );

          _loadDeletedRecords();
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isProcessing = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to restore: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _handlePermanentDeleteSelected() async {
    if (_selectedRecordIds.isEmpty) return;

    final count = _selectedRecordIds.length;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 28),
            const SizedBox(width: 10),
            const Text('Permanently Delete?'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'DANGER: You are about to permanently delete $count record(s).',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.red),
            ),
            const SizedBox(height: 8),
            const Text(
              'This will completely remove the records from the database. This action CANNOT be undone.',
              style: TextStyle(fontSize: 13),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade900),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('Permanently Delete ($count)'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => _isProcessing = true);

      try {
        final deleted = await RecordService.permanentDeleteRecords(_selectedRecordIds.toList());

        if (mounted) {
          setState(() {
            _selectedRecordIds.clear();
            _isProcessing = false;
          });

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('$deleted records permanently purged'),
              backgroundColor: Colors.grey.shade900,
            ),
          );

          _loadDeletedRecords();
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isProcessing = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to permanently delete: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final totalPages = (_totalCount / _pageSize).ceil();

    final allCurrentPageSelected = _deletedRecords.isNotEmpty &&
        _deletedRecords.every((r) => r.id != null && _selectedRecordIds.contains(r.id));
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
                  Row(
                    children: [
                      Icon(Icons.recycling_rounded, color: Colors.orange.shade800, size: 28),
                      const SizedBox(width: 10),
                      Text(
                        'Recycle Bin / Deleted Records',
                        style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Review soft-deleted records. Restore them back to active list or permanently purge them.',
                    style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
              IconButton.outlined(
                icon: const Icon(Icons.refresh),
                tooltip: 'Refresh Recycle Bin',
                onPressed: () {
                  _selectedRecordIds.clear();
                  _loadDeletedRecords();
                },
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Search Bar
          Card(
            elevation: 1,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: TextField(
                controller: _searchController,
                onChanged: _onSearchChanged,
                decoration: InputDecoration(
                  hintText: 'Search deleted records by Consumer No, Name, Mobile, or App ID...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                            _loadDeletedRecords();
                          },
                        )
                      : null,
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ),
          ),

          // Actions Bar when records are selected
          if (hasSomeSelected) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF7ED),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFFED7AA)),
              ),
              child: Row(
                children: [
                  Icon(Icons.check_box, color: Colors.orange.shade800, size: 20),
                  const SizedBox(width: 10),
                  Text(
                    '${_selectedRecordIds.length} deleted record(s) selected',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: Colors.orange.shade900,
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => setState(() => _selectedRecordIds.clear()),
                    child: const Text('Deselect All'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.green.shade700,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    ),
                    icon: _isProcessing
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.restore, size: 18),
                    label: Text('Restore Selected (${_selectedRecordIds.length})'),
                    onPressed: _isProcessing ? null : _handleRestoreSelected,
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.red.shade900,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    ),
                    icon: const Icon(Icons.delete_forever, size: 18),
                    label: Text('Permanently Delete (${_selectedRecordIds.length})'),
                    onPressed: _isProcessing ? null : _handlePermanentDeleteSelected,
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 16),

          // Deleted Records Table
          Expanded(
            child: Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              clipBehavior: Clip.antiAlias,
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _deletedRecords.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.delete_sweep_outlined, size: 64, color: Colors.grey.shade400),
                              const SizedBox(height: 16),
                              const Text(
                                'Recycle Bin is Empty',
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 8),
                              const Text('No records have been soft-deleted.'),
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
                                const DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.bold))),
                                const DataColumn(label: Text('Deleted Date', style: TextStyle(fontWeight: FontWeight.bold))),
                                const DataColumn(label: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold))),
                              ],
                              rows: _deletedRecords.map((r) {
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
                                    DataCell(
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.red.shade50,
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          'Deleted',
                                          style: TextStyle(
                                            color: Colors.red.shade800,
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ),
                                    DataCell(
                                      Text(
                                        r.deletedAt != null
                                            ? r.deletedAt!.toLocal().toString().split('.')[0]
                                            : '—',
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                    ),
                                    DataCell(
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          IconButton(
                                            icon: const Icon(Icons.restore, color: Colors.green),
                                            tooltip: 'Restore Record',
                                            onPressed: () async {
                                              if (r.id == null) return;
                                              await RecordService.restoreRecords([r.id!]);
                                              _loadDeletedRecords();
                                              if (context.mounted) {
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  const SnackBar(
                                                    content: Text('Record restored successfully'),
                                                    backgroundColor: Colors.green,
                                                  ),
                                                );
                                              }
                                            },
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.delete_forever, color: Colors.red),
                                            tooltip: 'Permanently Delete',
                                            onPressed: () async {
                                              if (r.id == null) return;
                                              _selectedRecordIds.add(r.id!);
                                              _handlePermanentDeleteSelected();
                                            },
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
                'Showing ${(_currentPage - 1) * _pageSize + (_deletedRecords.isEmpty ? 0 : 1)} - ${(_currentPage - 1) * _pageSize + _deletedRecords.length} of $_totalCount deleted records',
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
                            _loadDeletedRecords();
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
                            _loadDeletedRecords();
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
}
