import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../models/consumer_record.dart';
import '../services/record_service.dart';
import '../services/app_database.dart';
import '../widgets/sync_status_indicator.dart';
import 'record_detail_screen.dart';

class SearchRecordsScreen extends StatefulWidget {
  final String? initialFilter;
  final List<ConsumerRecord>? initialRecords;

  const SearchRecordsScreen({
    super.key,
    this.initialFilter,
    this.initialRecords,
  });

  @override
  State<SearchRecordsScreen> createState() => _SearchRecordsScreenState();
}

class _SearchRecordsScreenState extends State<SearchRecordsScreen> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounceTimer;

  bool _isLoading = false;
  List<ConsumerRecord> _results = [];
  bool _hasSearched = false;
  String _selectedSmartFilter = 'All';

  final List<String> _smartFilters = [
    'All',
    'Pending Payment',
    'Stalled (>10d)',
    'Loan Attention',
    'On Hold',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.initialRecords != null && widget.initialRecords!.isNotEmpty) {
      _results = List.from(widget.initialRecords!);
      _hasSearched = true;
      _selectedSmartFilter = widget.initialFilter ?? 'All';
    } else if (widget.initialFilter != null && widget.initialFilter != 'All') {
      _selectedSmartFilter = widget.initialFilter!;
      _applySmartFilter(_selectedSmartFilter);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _debounceTimer?.cancel();
    if (query.trim().isEmpty && _selectedSmartFilter == 'All') {
      setState(() {
        _results = [];
        _hasSearched = false;
        _isLoading = false;
      });
      return;
    }

    _debounceTimer = Timer(const Duration(milliseconds: 350), () {
      if (_selectedSmartFilter != 'All') {
        _applySmartFilter(_selectedSmartFilter);
      } else {
        _performSearch(query.trim());
      }
    });
  }

  Future<void> _performSearch(String query) async {
    setState(() {
      _isLoading = true;
      _hasSearched = true;
    });

    try {
      final res = await MobileRecordService.fetchRecords(
        page: 1,
        pageSize: 50,
        searchQuery: query,
      );

      if (mounted) {
        setState(() {
          _results = res.items;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _applySmartFilter(String filter) async {
    setState(() {
      _selectedSmartFilter = filter;
      _isLoading = true;
      _hasSearched = true;
    });

    try {
      final all = await AppDatabase.getAllConsumerRecords();
      List<ConsumerRecord> matched = [];

      final now = DateTime.now();
      if (filter == 'Pending Payment') {
        matched = all.where((r) => !r.isDeleted && r.pendingAmount > 0).toList();
        matched.sort((a, b) => b.pendingAmount.compareTo(a.pendingAmount));
      } else if (filter == 'Stalled (>10d)') {
        matched = all.where((r) {
          if (r.isDeleted || r.isCompletedState) return false;
          final rDate = r.updatedAt ?? r.createdAt ?? now;
          final days = now.difference(rDate).inDays;
          return days >= 10 || r.isHold;
        }).toList();
      } else if (filter == 'Loan Attention') {
        matched = all.where((r) {
          if (r.isDeleted || r.isCompletedState) return false;
          final sub = r.loanSubStage.trim().toLowerCase();
          return r.overallStage == 'Loan' ||
              sub.contains('rejected') ||
              sub.contains('correction') ||
              sub.contains('bank');
        }).toList();
      } else if (filter == 'On Hold') {
        matched = all.where((r) => !r.isDeleted && r.isHold).toList();
      } else {
        matched = all.where((r) => !r.isDeleted).toList();
      }

      if (_searchController.text.trim().isNotEmpty) {
        final q = _searchController.text.trim().toLowerCase();
        matched = matched.where((r) =>
            r.name.toLowerCase().contains(q) ||
            r.consumerNo.toLowerCase().contains(q) ||
            (r.mobile?.contains(q) ?? false) ||
            (r.village?.toLowerCase().contains(q) ?? false)).toList();
      }

      if (mounted) {
        setState(() {
          _results = matched;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  bool get _isSearchActive => _searchController.text.isNotEmpty || _hasSearched;

  void _clearSearch() {
    setState(() {
      _searchController.clear();
      _results = [];
      _hasSearched = false;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final canPop = Navigator.of(context).canPop();

    return PopScope(
      canPop: !_isSearchActive,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _clearSearch();
      },
      child: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              // Search Input Card
              Padding(
                padding: const EdgeInsets.fromLTRB(14.0, 10.0, 14.0, 8.0),
                child: Row(
                  children: [
                    if (canPop) ...[
                      IconButton(
                        icon: const Icon(Icons.arrow_back),
                        tooltip: 'Back',
                        onPressed: () {
                          if (_isSearchActive && widget.initialRecords == null) {
                            _clearSearch();
                          } else {
                            Navigator.of(context).pop();
                          }
                        },
                      ),
                      const SizedBox(width: 4),
                    ],
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        autofocus: widget.initialRecords == null && widget.initialFilter == null,
                        onChanged: _onSearchChanged,
                        decoration: InputDecoration(
                          hintText: 'Search Consumer No, Name, Mobile, Village...',
                          hintStyle: const TextStyle(fontSize: 13),
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: _searchController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear),
                                  onPressed: () {
                                    _searchController.clear();
                                    _onSearchChanged('');
                                  },
                                )
                              : null,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          filled: true,
                          fillColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const SyncStatusIndicator(compact: true),
                  ],
                ),
              ),

          // Smart Intelligence Filters
          SizedBox(
            height: 38,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              scrollDirection: Axis.horizontal,
              itemCount: _smartFilters.length,
              separatorBuilder: (context, index) => const SizedBox(width: 8),
              itemBuilder: (ctx, i) {
                final filter = _smartFilters[i];
                final isSelected = _selectedSmartFilter == filter;
                return ChoiceChip(
                  label: Text(
                    filter == 'Pending Payment'
                        ? '💰 $filter'
                        : filter == 'Stalled (>10d)'
                            ? '⏳ $filter'
                            : filter == 'Loan Attention'
                                ? '🏦 $filter'
                                : filter == 'On Hold'
                                    ? '⏸️ $filter'
                                    : filter,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                      color: isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurface,
                    ),
                  ),
                  selected: isSelected,
                  selectedColor: theme.colorScheme.primaryContainer,
                  backgroundColor: theme.colorScheme.surfaceContainerLow,
                  side: BorderSide(
                    color: isSelected
                        ? theme.colorScheme.primary
                        : theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
                  ),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  onSelected: (selected) {
                    if (selected) {
                      _applySmartFilter(filter);
                    }
                  },
                );
              },
            ),
          ),
          const SizedBox(height: 6),

          // Search Results
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : !_hasSearched
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
                              ),
                              child: Icon(Icons.search_rounded, size: 48, color: theme.colorScheme.primary),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Type to find solar consumer records',
                              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Quick lookup by Consumer Number, Name, or Mobile',
                              style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 13),
                            ),
                          ],
                        ),
                      )
                    : _results.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: theme.colorScheme.errorContainer.withValues(alpha: 0.3),
                                  ),
                                  child: Icon(Icons.search_off_rounded, size: 48, color: theme.colorScheme.error),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'No matching consumers found',
                                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Verify the Consumer No or Name spelling.',
                                  style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 13),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            itemCount: _results.length,
                            itemBuilder: (context, index) {
                              final record = _results[index];
                              final statusColor = _getStatusColor(record.status);
                              return Card(
                                margin: const EdgeInsets.only(bottom: 10),
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  side: BorderSide(
                                    color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
                                  ),
                                ),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(12),
                                  onTap: () async {
                                    final updated = await Navigator.of(context).push<bool>(
                                      MaterialPageRoute(
                                        builder: (_) => RecordDetailScreen(initialRecord: record),
                                      ),
                                    );
                                    if (updated == true) {
                                      _performSearch(_searchController.text.trim());
                                    }
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.all(14.0),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        // Header Row: Consumer No & Overall Stage Badge
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            InkWell(
                                              onTap: () {
                                                Clipboard.setData(ClipboardData(text: record.consumerNo));
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  SnackBar(
                                                    content: Text('Consumer No. ${record.consumerNo} copied to clipboard'),
                                                    duration: const Duration(seconds: 2),
                                                  ),
                                                );
                                              },
                                              borderRadius: BorderRadius.circular(6),
                                              child: Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                                decoration: BoxDecoration(
                                                  color: theme.colorScheme.surfaceContainerHighest,
                                                  borderRadius: BorderRadius.circular(6),
                                                ),
                                                child: Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    Text(
                                                      'No: ${record.consumerNo}',
                                                      style: TextStyle(
                                                        fontWeight: FontWeight.bold,
                                                        fontSize: 12,
                                                        color: theme.colorScheme.onSurfaceVariant,
                                                      ),
                                                    ),
                                                    const SizedBox(width: 4),
                                                    Icon(
                                                      Icons.copy_rounded,
                                                      size: 13,
                                                      color: theme.colorScheme.onSurfaceVariant,
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                              decoration: BoxDecoration(
                                                color: statusColor.withValues(alpha: 0.12),
                                                borderRadius: BorderRadius.circular(20),
                                                border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                                              ),
                                              child: Text(
                                                record.overallStage,
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 11,
                                                  color: statusColor,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),

                                        // Full Consumer Name
                                        Text(
                                          record.name,
                                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                                        ),
                                        const SizedBox(height: 6),

                                        // Mobile & Address Details Row
                                        Row(
                                          children: [
                                            Icon(Icons.phone_android, size: 14, color: Colors.grey.shade600),
                                            const SizedBox(width: 4),
                                            Text(
                                              record.mobile ?? 'No Mobile',
                                              style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                                            ),
                                            if (record.address != null && record.address!.isNotEmpty) ...[
                                              const SizedBox(width: 12),
                                              Icon(Icons.location_on_outlined, size: 14, color: Colors.grey.shade600),
                                              const SizedBox(width: 4),
                                              Expanded(
                                                child: Text(
                                                  record.address!,
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),

                                        // Smart Status Badges
                                        Builder(
                                          builder: (context) {
                                            final recDate = record.updatedAt ?? record.createdAt ?? DateTime.now();
                                            final idleDays = DateTime.now().difference(recDate).inDays;
                                            if (record.pendingAmount <= 0 && !record.isHold && idleDays < 10) {
                                              return const SizedBox.shrink();
                                            }
                                            return Padding(
                                              padding: const EdgeInsets.only(top: 8.0),
                                              child: Wrap(
                                                spacing: 6,
                                                runSpacing: 4,
                                                children: [
                                                  if (record.pendingAmount > 0)
                                                    Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                      decoration: BoxDecoration(
                                                        color: const Color(0xFFDC2626).withValues(alpha: 0.1),
                                                        borderRadius: BorderRadius.circular(6),
                                                        border: Border.all(
                                                          color: const Color(0xFFDC2626).withValues(alpha: 0.3),
                                                        ),
                                                      ),
                                                      child: Text(
                                                        'Pending: ₹${NumberFormat('#,##,###').format(record.pendingAmount)}',
                                                        style: const TextStyle(
                                                          fontSize: 11,
                                                          fontWeight: FontWeight.bold,
                                                          color: Color(0xFFDC2626),
                                                        ),
                                                      ),
                                                    ),
                                                  if (record.isHold)
                                                    Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                      decoration: BoxDecoration(
                                                        color: const Color(0xFFF59E0B).withValues(alpha: 0.1),
                                                        borderRadius: BorderRadius.circular(6),
                                                        border: Border.all(
                                                          color: const Color(0xFFF59E0B).withValues(alpha: 0.3),
                                                        ),
                                                      ),
                                                      child: const Text(
                                                        '⏸️ On Hold',
                                                        style: TextStyle(
                                                          fontSize: 11,
                                                          fontWeight: FontWeight.bold,
                                                          color: Color(0xFFB45309),
                                                        ),
                                                      ),
                                                    ),
                                                  if (!record.isCompletedState && idleDays >= 10)
                                                    Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                      decoration: BoxDecoration(
                                                        color: Colors.grey.withValues(alpha: 0.15),
                                                        borderRadius: BorderRadius.circular(6),
                                                      ),
                                                      child: Text(
                                                        '⏳ ${idleDays}d idle',
                                                        style: TextStyle(
                                                          fontSize: 11,
                                                          fontWeight: FontWeight.w600,
                                                          color: Colors.grey.shade800,
                                                        ),
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
                                ),
                              );
                            },
                          ),
          ),
        ],
      ),
    ),
    ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Approved':
      case 'Completed':
        return Colors.green.shade800;
      case 'In Progress':
        return Colors.blue.shade800;
      case 'Rejected':
        return Colors.red.shade800;
      case 'Pending':
      default:
        return Colors.orange.shade800;
    }
  }
}
