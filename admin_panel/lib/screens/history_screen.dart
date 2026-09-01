import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/import_log.dart';
import '../services/audit_service.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Tab 1: Import Logs State
  bool _isLoadingImports = false;
  List<ImportLog> _importLogs = [];
  int _importTotalCount = 0;
  int _importPage = 1;
  final int _importPageSize = 12;

  // Tab 2: Audit Logs State
  bool _isLoadingAudits = false;
  List<AuditLogEntry> _auditLogs = [];
  int _auditTotalCount = 0;
  int _auditPage = 1;
  final int _auditPageSize = 15;
  final TextEditingController _auditSearchController = TextEditingController();
  String _selectedAuditAction = 'All';
  Timer? _auditDebounce;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        if (_tabController.index == 0) {
          _loadImportLogs();
        } else {
          _loadAuditLogs();
        }
      }
    });

    _loadImportLogs();
    _loadAuditLogs();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _auditSearchController.dispose();
    _auditDebounce?.cancel();
    super.dispose();
  }

  Future<void> _loadImportLogs() async {
    setState(() => _isLoadingImports = true);
    final result = await AuditService.fetchImportLogs(
      page: _importPage,
      pageSize: _importPageSize,
    );
    if (mounted) {
      setState(() {
        _importLogs = result.items;
        _importTotalCount = result.totalCount;
        _isLoadingImports = false;
      });
    }
  }

  Future<void> _loadAuditLogs() async {
    setState(() => _isLoadingAudits = true);
    final result = await AuditService.fetchAuditLogs(
      page: _auditPage,
      pageSize: _auditPageSize,
      searchQuery: _auditSearchController.text,
      actionFilter: _selectedAuditAction,
    );
    if (mounted) {
      setState(() {
        _auditLogs = result.items;
        _auditTotalCount = result.totalCount;
        _isLoadingAudits = false;
      });
    }
  }

  void _onAuditSearchChanged(String query) {
    _auditDebounce?.cancel();
    _auditDebounce = Timer(const Duration(milliseconds: 350), () {
      setState(() => _auditPage = 1);
      _loadAuditLogs();
    });
  }

  void _showBatchDetails(ImportLog log) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFD97706).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.description_outlined, color: Color(0xFFD97706)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(log.fileName, style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold)),
                  Text('Imported on ${log.createdAt.toLocal().toString().split('.')[0]}', style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B))),
                ],
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 480,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Divider(),
              const SizedBox(height: 12),
              _buildDetailRow('Total Records Processed', log.totalRows.toString()),
              _buildDetailRow('New Records Inserted', log.insertedCount.toString(), color: const Color(0xFF059669)),
              _buildDetailRow('Existing Records Updated', log.updatedCount.toString(), color: const Color(0xFFD97706)),
              _buildDetailRow('Records Skipped', log.skippedCount.toString(), color: const Color(0xFF64748B)),
              if (log.failedCount > 0)
                _buildDetailRow('Failed Records', log.failedCount.toString(), color: Colors.red),
              _buildDetailRow('File Size', log.formattedFileSize),
              _buildDetailRow('Conflict Strategy', log.strategyLabel),
              _buildDetailRow('Uploaded By', log.creatorEmail ?? 'System Admin'),
              const SizedBox(height: 12),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF64748B))),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: color ?? const Color(0xFF1E293B),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Import History & Audit Trail',
                    style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Track historical Excel / CSV ingestion runs and inspect field-level changes',
                    style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
              IconButton.outlined(
                icon: const Icon(Icons.refresh),
                tooltip: 'Refresh',
                onPressed: () {
                  if (_tabController.index == 0) {
                    _loadImportLogs();
                  } else {
                    _loadAuditLogs();
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Tabs
          TabBar(
            controller: _tabController,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            labelColor: theme.colorScheme.primary,
            unselectedLabelColor: const Color(0xFF64748B),
            indicatorColor: theme.colorScheme.primary,
            tabs: const [
              Tab(
                icon: Icon(Icons.history_rounded, size: 18),
                child: Text('Import Batches'),
              ),
              Tab(
                icon: Icon(Icons.checklist_rounded, size: 18),
                child: Text('Field-Level Audit Trail'),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Tab Views
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildImportLogsTab(),
                _buildAuditLogsTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- Tab 1: Import Logs ---
  Widget _buildImportLogsTab() {
    if (_isLoadingImports) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_importLogs.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history_toggle_off_rounded, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              'No Import Runs Recorded Yet',
              style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: const Color(0xFF1E293B)),
            ),
            const SizedBox(height: 8),
            Text(
              'When you upload Excel or CSV spreadsheets, execution summaries will appear here.',
              style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF64748B)),
            ),
          ],
        ),
      );
    }

    final totalPages = (_importTotalCount / _importPageSize).ceil();

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.vertical,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
                  headingTextStyle: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 12, color: const Color(0xFF475569)),
                  dataRowMinHeight: 52,
                  dataRowMaxHeight: 60,
                  columns: const [
                    DataColumn(label: Text('File Name')),
                    DataColumn(label: Text('Date & Time')),
                    DataColumn(label: Text('Total Rows')),
                    DataColumn(label: Text('Breakdown')),
                    DataColumn(label: Text('Strategy')),
                    DataColumn(label: Text('User')),
                    DataColumn(label: Text('Actions')),
                  ],
                  rows: _importLogs.map((log) {
                    return DataRow(
                      cells: [
                        DataCell(
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.insert_drive_file_outlined, size: 18, color: Color(0xFFD97706)),
                              const SizedBox(width: 8),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(log.fileName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                  Text(log.formattedFileSize, style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
                                ],
                              ),
                            ],
                          ),
                        ),
                        DataCell(Text(log.createdAt.toLocal().toString().split('.')[0])),
                        DataCell(Text(log.totalRows.toString(), style: const TextStyle(fontWeight: FontWeight.bold))),
                        DataCell(
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _buildCountChip('+${log.insertedCount} new', const Color(0xFF059669), const Color(0xFFD1FAE5)),
                              const SizedBox(width: 6),
                              if (log.updatedCount > 0) ...[
                                _buildCountChip('${log.updatedCount} updated', const Color(0xFFD97706), const Color(0xFFFEF3C7)),
                                const SizedBox(width: 6),
                              ],
                              if (log.skippedCount > 0) ...[
                                _buildCountChip('${log.skippedCount} skipped', const Color(0xFF64748B), const Color(0xFFF1F5F9)),
                              ],
                            ],
                          ),
                        ),
                        DataCell(Text(log.strategyLabel, style: const TextStyle(fontSize: 12))),
                        DataCell(Text(log.creatorEmail ?? 'Admin', style: const TextStyle(fontSize: 12))),
                        DataCell(
                          IconButton(
                            icon: const Icon(Icons.info_outline, size: 20, color: Color(0xFF2563EB)),
                            tooltip: 'View Details',
                            onPressed: () => _showBatchDetails(log),
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
          // Pagination
          _buildPaginationBar(_importPage, totalPages, _importTotalCount, (newPage) {
            setState(() => _importPage = newPage);
            _loadImportLogs();
          }),
        ],
      ),
    );
  }

  Widget _buildCountChip(String label, Color textColor, Color bgColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: textColor),
      ),
    );
  }

  // --- Tab 2: Audit Logs ---
  Widget _buildAuditLogsTab() {
    final totalPages = (_auditTotalCount / _auditPageSize).ceil();

    return Column(
      children: [
        // Filter Bar
        Card(
          elevation: 1,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: _auditSearchController,
                    onChanged: _onAuditSearchChanged,
                    decoration: InputDecoration(
                      hintText: 'Search audit logs by Consumer No, Field, or Value...',
                      prefixIcon: const Icon(Icons.search, size: 20),
                      suffixIcon: _auditSearchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              onPressed: () {
                                _auditSearchController.clear();
                                _loadAuditLogs();
                              },
                            )
                          : null,
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                DropdownButton<String>(
                  value: _selectedAuditAction,
                  items: const [
                    DropdownMenuItem(value: 'All', child: Text('All Actions')),
                    DropdownMenuItem(value: 'UPDATE', child: Text('UPDATE')),
                    DropdownMenuItem(value: 'INSERT', child: Text('INSERT')),
                    DropdownMenuItem(value: 'DELETE', child: Text('DELETE')),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        _selectedAuditAction = val;
                        _auditPage = 1;
                      });
                      _loadAuditLogs();
                    }
                  },
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Table
        Expanded(
          child: Card(
            elevation: 1,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: _isLoadingAudits
                ? const Center(child: CircularProgressIndicator())
                : _auditLogs.isEmpty
                    ? Center(
                        child: Text(
                          'No audit logs match your search criteria.',
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                      )
                    : Column(
                        children: [
                          Expanded(
                            child: SingleChildScrollView(
                              scrollDirection: Axis.vertical,
                              child: SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: DataTable(
                                  headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
                                  headingTextStyle: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 12, color: const Color(0xFF475569)),
                                  dataRowMinHeight: 48,
                                  dataRowMaxHeight: 56,
                                  columns: const [
                                    DataColumn(label: Text('Timestamp')),
                                    DataColumn(label: Text('Consumer No')),
                                    DataColumn(label: Text('Field Name')),
                                    DataColumn(label: Text('Old Value ➔ New Value')),
                                    DataColumn(label: Text('User')),
                                    DataColumn(label: Text('Source')),
                                  ],
                                  rows: _auditLogs.map((entry) {
                                    return DataRow(
                                      cells: [
                                        DataCell(Text(entry.createdAt.toLocal().toString().split('.')[0])),
                                        DataCell(Text(entry.consumerNo, style: const TextStyle(fontWeight: FontWeight.bold))),
                                        DataCell(Text(entry.fieldName ?? '—', style: const TextStyle(fontWeight: FontWeight.w500))),
                                        DataCell(
                                          Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: Colors.red.shade50,
                                                  borderRadius: BorderRadius.circular(4),
                                                ),
                                                child: Text(
                                                  entry.oldValue ?? '(empty)',
                                                  style: TextStyle(fontSize: 12, color: Colors.red.shade800),
                                                ),
                                              ),
                                              const Padding(
                                                padding: EdgeInsets.symmetric(horizontal: 6),
                                                child: Icon(Icons.arrow_forward_rounded, size: 14, color: Color(0xFF94A3B8)),
                                              ),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFFD1FAE5),
                                                  borderRadius: BorderRadius.circular(4),
                                                ),
                                                child: Text(
                                                  entry.newValue ?? '(empty)',
                                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF065F46)),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        DataCell(Text(entry.changerEmail ?? 'Admin', style: const TextStyle(fontSize: 12))),
                                        DataCell(
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFF1F5F9),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Text(entry.source, style: const TextStyle(fontSize: 11, color: Color(0xFF475569))),
                                          ),
                                        ),
                                      ],
                                    );
                                  }).toList(),
                                ),
                              ),
                            ),
                          ),
                          _buildPaginationBar(_auditPage, totalPages, _auditTotalCount, (newPage) {
                            setState(() => _auditPage = newPage);
                            _loadAuditLogs();
                          }),
                        ],
                      ),
          ),
        ),
      ],
    );
  }

  Widget _buildPaginationBar(int currentPage, int totalPages, int totalCount, ValueChanged<int> onPageChange) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Total: $totalCount items',
            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
          ),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: currentPage > 1 ? () => onPageChange(currentPage - 1) : null,
              ),
              Text(
                'Page $currentPage of ${totalPages < 1 ? 1 : totalPages}',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: currentPage < totalPages ? () => onPageChange(currentPage + 1) : null,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
