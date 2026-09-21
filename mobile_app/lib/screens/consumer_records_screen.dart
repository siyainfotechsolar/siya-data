import 'dart:async';
import 'package:flutter/material.dart';
import '../models/consumer_record.dart';
import '../services/record_service.dart';
import '../services/realtime_service.dart';
import '../services/supabase_service.dart';
import 'login_screen.dart';
import 'record_detail_screen.dart';
import '../widgets/add_customer_dialog.dart';

class ConsumerRecordsScreen extends StatefulWidget {
  final String? initialSiteType;
  final String? initialStatusFilter;
  const ConsumerRecordsScreen({super.key, this.initialSiteType, this.initialStatusFilter});

  @override
  State<ConsumerRecordsScreen> createState() => _ConsumerRecordsScreenState();
}

class _ConsumerRecordsScreenState extends State<ConsumerRecordsScreen> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounceTimer;
  String _searchQuery = '';

  bool _isLoading = false;
  bool _isLoadingMore = false;
  List<ConsumerRecord> _records = [];
  int _currentPage = 1;
  final int _pageSize = 20;
  int _totalCount = 0;
  late String _selectedStatus;
  late String _selectedSiteType;

  StreamSubscription<MobileRecordChangeEvent>? _realtimeSub;

  @override
  void initState() {
    super.initState();
    // Default view: Subsidy customers by default
    _selectedSiteType = widget.initialSiteType ?? 'Subsidy';
    _selectedStatus = widget.initialStatusFilter ?? 'All';
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
    _debounceTimer?.cancel();
    _searchController.dispose();
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
        siteTypeFilter: _selectedSiteType,
        searchQuery: _searchQuery.isNotEmpty ? _searchQuery : null,
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
            content: Text('Failed to load customers: $e'),
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
        siteTypeFilter: _selectedSiteType,
        searchQuery: _searchQuery.isNotEmpty ? _searchQuery : null,
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

  Future<void> _openRecordDetail(ConsumerRecord record) async {
    final updated = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => RecordDetailScreen(initialRecord: record),
      ),
    );
    if (updated == true && mounted) {
      _loadRecords();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: Navigator.canPop(context)
          ? AppBar(
              title: const Text('Customers'),
            )
          : null,
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'fab_add_customer',
        onPressed: () async {
          final created = await AddCustomerDialog.show(context);
          if (created != null && mounted) {
            _loadRecords();
          }
        },
        icon: const Icon(Icons.person_add_rounded),
        label: const Text('Add Customer'),
      ),
      body: Column(
        children: [
          // ── Search Bar ──────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search customer, village, mobile, consumer no...',
                hintStyle: TextStyle(color: Colors.grey.shade500, fontSize: 14),
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 20),
                        onPressed: () {
                          _searchController.clear();
                          _debounceTimer?.cancel();
                          setState(() => _searchQuery = '');
                          _loadRecords();
                        },
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                filled: true,
                fillColor: theme.colorScheme.surfaceContainerLowest,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: theme.colorScheme.primary, width: 2),
                ),
              ),
              onChanged: (val) {
                _debounceTimer?.cancel();
                _debounceTimer = Timer(const Duration(milliseconds: 300), () {
                  setState(() => _searchQuery = val.trim());
                  _loadRecords();
                });
              },
            ),
          ),

          // ── Switch Button & Customer Count ──────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '$_totalCount customers',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                if (_selectedSiteType == 'Subsidy')
                  OutlinedButton.icon(
                    onPressed: () {
                      setState(() {
                        _selectedSiteType = 'Non-Subsidy';
                        _currentPage = 1;
                      });
                      _loadRecords();
                    },
                    icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                    label: const Text(
                      'Non-Subsidy Sites',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    style: OutlinedButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  )
                else
                  FilledButton.icon(
                    onPressed: () {
                      setState(() {
                        _selectedSiteType = 'Subsidy';
                        _currentPage = 1;
                      });
                      _loadRecords();
                    },
                    icon: const Icon(Icons.arrow_back_rounded, size: 16),
                    label: const Text(
                      'Back to Subsidy',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    style: FilledButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      backgroundColor: theme.colorScheme.primary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
              ],
            ),
          ),
          const Divider(height: 12),

          // ── Customer List ──────────────────────────────────────
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
                                'Unable to Load Customers',
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
                                        : 'No customers found',
                                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    !SupabaseService.isAuthenticated
                                        ? 'Please sign in with your Staff email and password.'
                                        : (_searchQuery.isNotEmpty
                                            ? 'No customers match your search.'
                                            : 'No customers available.'),
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
                              padding: EdgeInsets.only(
                                left: 14,
                                right: 14,
                                bottom: MediaQuery.of(context).padding.bottom + 90,
                              ),
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
    final villageText = (record.village != null && record.village!.trim().isNotEmpty)
        ? record.village!.trim()
        : ((record.address != null && record.address!.trim().isNotEmpty)
            ? record.address!.trim()
            : '—');
    final mobileText = (record.mobile != null && record.mobile!.trim().isNotEmpty)
        ? record.mobile!.trim()
        : '—';
    final capacityText = (record.systemCapacity != null && record.systemCapacity!.trim().isNotEmpty)
        ? record.systemCapacity!.trim()
        : '—';

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0.8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _openRecordDetail(record),
        child: Padding(
          padding: const EdgeInsets.all(14.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Row 1: Customer Name and Status
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      record.name.isNotEmpty ? record.name : 'Unknown Customer',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _buildStatusBadge(record.status),
                ],
              ),
              const SizedBox(height: 10),

              // Row 2: Village
              Row(
                children: [
                  Icon(Icons.location_on_outlined, size: 15, color: Colors.grey.shade600),
                  const SizedBox(width: 6),
                  const Text(
                    'Village: ',
                    style: TextStyle(fontSize: 13, color: Colors.grey, fontWeight: FontWeight.w500),
                  ),
                  Expanded(
                    child: Text(
                      villageText,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),

              // Row 3: Mobile & Consumer No.
              Row(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Icon(Icons.phone_outlined, size: 15, color: Colors.grey.shade600),
                        const SizedBox(width: 6),
                        const Text(
                          'Mobile: ',
                          style: TextStyle(fontSize: 13, color: Colors.grey, fontWeight: FontWeight.w500),
                        ),
                        Flexible(
                          child: Text(
                            mobileText,
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Row(
                      children: [
                        Icon(Icons.tag_rounded, size: 15, color: Colors.grey.shade600),
                        const SizedBox(width: 4),
                        const Text(
                          'Consumer No: ',
                          style: TextStyle(fontSize: 13, color: Colors.grey, fontWeight: FontWeight.w500),
                        ),
                        Expanded(
                          child: Text(
                            record.consumerNo.isNotEmpty ? record.consumerNo : '—',
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Row 4: System Capacity & [ Open ]
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.bolt_rounded, size: 15, color: Colors.grey.shade600),
                      const SizedBox(width: 6),
                      const Text(
                        'System Capacity: ',
                        style: TextStyle(fontSize: 13, color: Colors.grey, fontWeight: FontWeight.w500),
                      ),
                      Text(
                        capacityText,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  FilledButton.tonalIcon(
                    onPressed: () => _openRecordDetail(record),
                    icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                    label: const Text('Open'),
                    style: FilledButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
