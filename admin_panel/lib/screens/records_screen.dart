import 'dart:async';
import 'package:flutter/material.dart';
import '../models/consumer_record.dart';
import '../services/record_service.dart';
import '../widgets/record_form_dialog.dart';
import '../widgets/record_details_dialog.dart';

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

  final List<String> _statusFilters = [
    'All',
    'Pending',
    'Approved',
    'In Progress',
    'Completed',
    'Rejected',
  ];

  @override
  void initState() {
    super.initState();
    _loadRecords();
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
      setState(() => _currentPage = 1);
      _loadRecords();
    });
  }

  Future<void> _loadRecords() async {
    setState(() => _isLoading = true);

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
      });
    }
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

  Future<void> _openDeleteDialog(ConsumerRecord record) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Record'),
        content: Text('Are you sure you want to delete "${record.name}" (Consumer No: ${record.consumerNo})? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && record.id != null) {
      try {
        await RecordService.deleteRecord(record.id!);
        _loadRecords();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Record deleted successfully')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to delete: $e')),
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final totalPages = (_totalCount / _pageSize).ceil();

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
              FilledButton.icon(
                onPressed: _openAddRecordDialog,
                icon: const Icon(Icons.add),
                label: const Text('Add Record'),
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
                    onPressed: _loadRecords,
                  ),
                ],
              ),
            ),
          ),
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
                              columns: const [
                                DataColumn(label: Text('Consumer No', style: TextStyle(fontWeight: FontWeight.bold))),
                                DataColumn(label: Text('Name', style: TextStyle(fontWeight: FontWeight.bold))),
                                DataColumn(label: Text('Mobile', style: TextStyle(fontWeight: FontWeight.bold))),
                                DataColumn(label: Text('App ID', style: TextStyle(fontWeight: FontWeight.bold))),
                                DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.bold))),
                                DataColumn(label: Text('Last Updated', style: TextStyle(fontWeight: FontWeight.bold))),
                                DataColumn(label: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold))),
                              ],
                              rows: _records.map((r) {
                                return DataRow(
                                  cells: [
                                    DataCell(
                                      Text(
                                        r.consumerNo,
                                        style: const TextStyle(fontWeight: FontWeight.w600),
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
                                          IconButton(
                                            icon: const Icon(Icons.delete_outline, size: 20, color: Colors.red),
                                            tooltip: 'Delete Record',
                                            onPressed: () => _openDeleteDialog(r),
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
                            setState(() => _currentPage--);
                            _loadRecords();
                          }
                        : null,
                  ),
                  Text('Page $_currentPage of ${totalPages == 0 ? 1 : totalPages}'),
                  IconButton(
                    icon: const Icon(Icons.chevron_right),
                    onPressed: _currentPage < totalPages
                        ? () {
                            setState(() => _currentPage++);
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
