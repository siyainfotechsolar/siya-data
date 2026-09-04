import 'dart:async';
import 'package:flutter/material.dart';
import '../models/consumer_record.dart';
import '../services/record_service.dart';
import '../services/realtime_service.dart';
import '../services/supabase_service.dart';
import 'login_screen.dart';
import 'record_detail_screen.dart';

class ConsumerRecordsScreen extends StatefulWidget {
  const ConsumerRecordsScreen({super.key});

  @override
  State<ConsumerRecordsScreen> createState() => _ConsumerRecordsScreenState();
}

class _ConsumerRecordsScreenState extends State<ConsumerRecordsScreen> {
  final ScrollController _scrollController = ScrollController();

  bool _isLoading = false;
  bool _isLoadingMore = false;
  List<ConsumerRecord> _records = [];
  int _currentPage = 1;
  final int _pageSize = 20;
  int _totalCount = 0;
  String _selectedStatus = 'All';

  final List<String> _statusOptions = [
    'All',
    'Pending',
    'Approved',
    'In Progress',
    'Completed',
    'Rejected',
  ];

  StreamSubscription<MobileRecordChangeEvent>? _realtimeSub;

  @override
  void initState() {
    super.initState();
    _loadRecords();
    _scrollController.addListener(_onScroll);
    _initRealtime();
  }

  void _initRealtime() {
    MobileRealtimeService.initialize();
    _realtimeSub = MobileRealtimeService.recordEvents.listen((event) {
      if (!mounted) return;

      if (event.type == MobileRealtimeChangeType.update && event.record != null) {
        final updatedRecord = event.record!;
        final index = _records.indexWhere((r) => r.id == updatedRecord.id);

        if (index != -1) {
          if (updatedRecord.deleted || updatedRecord.isMerged) {
            setState(() {
              _records.removeAt(index);
              _totalCount = (_totalCount > 0) ? _totalCount - 1 : 0;
            });
          } else {
            setState(() {
              _records[index] = updatedRecord;
            });
          }
        } else if (!updatedRecord.deleted && !updatedRecord.isMerged && _currentPage == 1) {
          _loadRecords();
        }
      } else if (event.type == MobileRealtimeChangeType.insert && !event.record!.deleted && !event.record!.isMerged) {
        if (_currentPage == 1) {
          _loadRecords();
        } else {
          setState(() => _totalCount += 1);
        }
      } else if (event.type == MobileRealtimeChangeType.delete) {
        setState(() {
          _records.removeWhere((r) => r.id == event.recordId);
          _totalCount = (_totalCount > 0) ? _totalCount - 1 : 0;
        });
      }
    });
  }

  @override
  void dispose() {
    _realtimeSub?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200 &&
        !_isLoading &&
        !_isLoadingMore &&
        _records.length < _totalCount) {
      _loadMoreRecords();
    }
  }

  String? _errorMessage;

  Future<void> _loadRecords() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _currentPage = 1;
    });

    try {
      final res = await MobileRecordService.fetchRecords(
        page: 1,
        pageSize: _pageSize,
        statusFilter: _selectedStatus,
      );

      if (mounted) {
        setState(() {
          _records = res.items;
          _totalCount = res.totalCount;
          _isLoading = false;
          _errorMessage = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.toString();
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load records: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  Future<void> _loadMoreRecords() async {
    setState(() => _isLoadingMore = true);

    try {
      final nextPage = _currentPage + 1;
      final res = await MobileRecordService.fetchRecords(
        page: nextPage,
        pageSize: _pageSize,
        statusFilter: _selectedStatus,
      );

      if (mounted) {
        setState(() {
          _currentPage = nextPage;
          _records.addAll(res.items);
          _totalCount = res.totalCount;
          _isLoadingMore = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoadingMore = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: Column(
        children: [
          // Filter Chips Bar
          Container(
            height: 52,
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _statusOptions.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final status = _statusOptions[index];
                final isSelected = _selectedStatus == status;

                return FilterChip(
                  label: Text(status),
                  selected: isSelected,
                  selectedColor: theme.colorScheme.primaryContainer,
                  labelStyle: TextStyle(
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    color: isSelected ? theme.colorScheme.onPrimaryContainer : null,
                    fontSize: 13,
                  ),
                  onSelected: (val) {
                    if (val) {
                      setState(() => _selectedStatus = status);
                      _loadRecords();
                    }
                  },
                );
              },
            ),
          ),
          const Divider(height: 1),

          // Records Count Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Showing ${_records.length} of $_totalCount records',
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
                if (_selectedStatus != 'All')
                  InkWell(
                    onTap: () {
                      setState(() => _selectedStatus = 'All');
                      _loadRecords();
                    },
                    child: Text(
                      'Clear Filter',
                      style: TextStyle(fontSize: 12, color: theme.colorScheme.primary, fontWeight: FontWeight.bold),
                    ),
                  ),
              ],
            ),
          ),

          // Consumer List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _errorMessage != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.error_outline, size: 56, color: Colors.red),
                              const SizedBox(height: 12),
                              const Text(
                                'Unable to Load Records',
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _errorMessage!,
                                textAlign: TextAlign.center,
                                style: const TextStyle(fontSize: 12, color: Colors.grey),
                              ),
                              const SizedBox(height: 16),
                              FilledButton.icon(
                                onPressed: _loadRecords,
                                icon: const Icon(Icons.refresh),
                                label: const Text('Try Again'),
                              ),
                            ],
                          ),
                        ),
                      )
                    : _records.isEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24.0),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    !SupabaseService.isAuthenticated
                                        ? Icons.lock_outline
                                        : Icons.inbox_outlined,
                                    size: 60,
                                    color: Colors.grey.shade400,
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    !SupabaseService.isAuthenticated
                                        ? 'Staff Login Required'
                                        : 'No records found',
                                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    !SupabaseService.isAuthenticated
                                        ? 'You used Dev Demo mode (guest). To view live consumer records, please sign in with your Staff email and password.'
                                        : 'Try selecting a different status filter.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 13),
                                  ),
                                  if (!SupabaseService.isAuthenticated) ...[
                                    const SizedBox(height: 18),
                                    FilledButton.icon(
                                      onPressed: () {
                                        Navigator.of(context).pushReplacement(
                                          MaterialPageRoute(builder: (_) => const MobileLoginScreen()),
                                        );
                                      },
                                      icon: const Icon(Icons.login),
                                      label: const Text('Go to Staff Sign In'),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          )
                        : RefreshIndicator(
                        onRefresh: _loadRecords,
                        child: ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.only(left: 14, right: 14, bottom: 24),
                          itemCount: _records.length + (_isLoadingMore ? 1 : 0),
                          itemBuilder: (context, index) {
                            if (index == _records.length) {
                              return const Padding(
                                padding: EdgeInsets.all(16.0),
                                child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                              );
                            }

                            final record = _records[index];
                            return _buildRecordCard(record);
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecordCard(ConsumerRecord record) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () async {
          final updated = await Navigator.of(context).push<bool>(
            MaterialPageRoute(
              builder: (_) => RecordDetailScreen(initialRecord: record),
            ),
          );
          if (updated == true) {
            _loadRecords();
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(14.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Consumer No & Status Badge
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'No: ${record.consumerNo}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  _buildStatusBadge(record.status),
                ],
              ),
              const SizedBox(height: 8),

              // Consumer Name
              Text(
                record.name,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),

              // Mobile & Application ID
              Row(
                children: [
                  if (record.mobile != null && record.mobile!.isNotEmpty) ...[
                    Icon(Icons.phone_outlined, size: 14, color: theme.colorScheme.primary),
                    const SizedBox(width: 4),
                    Text(
                      record.mobile!,
                      style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurfaceVariant),
                    ),
                    const SizedBox(width: 16),
                  ],
                  if (record.applicationId != null && record.applicationId!.isNotEmpty) ...[
                    const Icon(Icons.numbers_outlined, size: 14, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text(
                      'App: ${record.applicationId}',
                      style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
                    ),
                  ],
                ],
              ),

              // Address Preview
              if (record.address != null && record.address!.isNotEmpty) ...[
                const SizedBox(height: 6),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.location_on_outlined, size: 14, color: Colors.grey),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        record.address!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                      ),
                    ),
                  ],
                ),
              ],

              const Divider(height: 16),

              // Workflow & Action Info Row
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  // Work Stage
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFFBFDBFE)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.task_alt, size: 12, color: Color(0xFF1D4ED8)),
                        const SizedBox(width: 4),
                        Text(
                          'STAGE: ${record.overallStage}',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1D4ED8),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Action Required
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFFBEB),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFFFDE68A)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.flash_on, size: 12, color: Color(0xFFB45309)),
                        const SizedBox(width: 4),
                        Text(
                          'ACTION: ${record.actionRequired}',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFB45309),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Application Age
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Text(
                      'AGE: ${record.applicationAgeDays}d (${record.applicationDays}d active)',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade800,
                      ),
                    ),
                  ),

                  // Priority Category
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: record.priorityCategory == 'Critical Active Work'
                          ? const Color(0xFFFEF2F2)
                          : record.priorityCategory == 'High Active Work'
                              ? const Color(0xFFFFEDD5)
                              : record.priorityCategory == 'Completed'
                                  ? const Color(0xFFECFDF5)
                                  : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      record.priorityCategory,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: record.priorityCategory == 'Critical Active Work'
                            ? const Color(0xFFDC2626)
                            : record.priorityCategory == 'High Active Work'
                                ? const Color(0xFFEA580C)
                                : record.priorityCategory == 'Completed'
                                    ? const Color(0xFF047857)
                                    : const Color(0xFF475569),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        status,
        style: TextStyle(color: fg, fontWeight: FontWeight.bold, fontSize: 11),
      ),
    );
  }
}
