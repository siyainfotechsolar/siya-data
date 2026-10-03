import 'dart:async';
import 'package:flutter/material.dart';
import '../models/import_log.dart';
import '../services/audit_service.dart';
import '../utils/responsive.dart';

/// Standalone Audit Screen — directly accessible from the main navigation.
/// Shows the Security Audit Trail (field-level change logs) with search,
/// filter, and pagination.
class AuditScreen extends StatefulWidget {
  const AuditScreen({super.key});

  @override
  State<AuditScreen> createState() => _AuditScreenState();
}

class _AuditScreenState extends State<AuditScreen> {
  bool _isLoading = false;
  List<AuditLogEntry> _auditLogs = [];
  int _totalCount = 0;
  int _page = 1;
  final int _pageSize = 20;
  final TextEditingController _searchController = TextEditingController();
  String _selectedAction = 'All';
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _loadAuditLogs();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _loadAuditLogs() async {
    setState(() => _isLoading = true);
    final result = await AuditService.fetchAuditLogs(
      page: _page,
      pageSize: _pageSize,
      searchQuery: _searchController.text,
      actionFilter: _selectedAction,
    );
    if (mounted) {
      setState(() {
        _auditLogs = result.items;
        _totalCount = result.totalCount;
        _isLoading = false;
      });
    }
  }

  void _onSearchChanged(String query) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      setState(() => _page = 1);
      _loadAuditLogs();
    });
  }

  int get _totalPages => (_totalCount / _pageSize).ceil().clamp(1, 999999);

  Color _actionColor(String action) {
    switch (action.toUpperCase()) {
      case 'INSERT':
        return const Color(0xFF10B981);
      case 'UPDATE':
        return const Color(0xFF3B82F6);
      case 'DELETE':
        return const Color(0xFFEF4444);
      case 'IMPORT':
        return const Color(0xFF8B5CF6);
      case 'RESTORE':
        return const Color(0xFF06B6D4);
      case 'EXPORT':
        return const Color(0xFFF59E0B);
      default:
        return const Color(0xFF6B7280);
    }
  }

  IconData _actionIcon(String action) {
    switch (action.toUpperCase()) {
      case 'INSERT':
        return Icons.add_circle_outline;
      case 'UPDATE':
        return Icons.edit_outlined;
      case 'DELETE':
        return Icons.delete_outline;
      case 'IMPORT':
        return Icons.upload_file_outlined;
      case 'RESTORE':
        return Icons.restore;
      case 'EXPORT':
        return Icons.download_outlined;
      default:
        return Icons.info_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isMobile = Responsive.isMobile(context);

    return Padding(
      padding: EdgeInsets.all(isMobile ? 12 : 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          if (isMobile)
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Security Audit Trail',
                        style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$_totalCount total records',
                        style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                IconButton.outlined(
                  icon: const Icon(Icons.refresh, size: 20),
                  tooltip: 'Refresh',
                  onPressed: _loadAuditLogs,
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
                      'Security Audit Trail',
                      style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Immutable field-level change history • $_totalCount total records',
                      style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
                IconButton.outlined(
                  icon: const Icon(Icons.refresh),
                  tooltip: 'Refresh',
                  onPressed: _loadAuditLogs,
                ),
              ],
            ),
          const SizedBox(height: 16),

          // Filter bar
          Wrap(
            spacing: 12,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: isMobile ? double.infinity : 360,
                child: TextField(
                  controller: _searchController,
                  onChanged: _onSearchChanged,
                  decoration: InputDecoration(
                    hintText: 'Search by Consumer No, field, or value...',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    isDense: true,
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.close, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _page = 1);
                              _loadAuditLogs();
                            },
                          )
                        : null,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5)),
                ),
                child: DropdownButton<String>(
                  value: _selectedAction,
                  underline: const SizedBox(),
                  isDense: true,
                  icon: const Icon(Icons.keyboard_arrow_down, size: 18),
                  items: const ['All', 'INSERT', 'UPDATE', 'DELETE', 'IMPORT', 'RESTORE', 'EXPORT'].map((a) {
                    return DropdownMenuItem(
                      value: a,
                      child: Text('Action: $a', style: const TextStyle(fontSize: 13)),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        _selectedAction = val;
                        _page = 1;
                      });
                      _loadAuditLogs();
                    }
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Audit log list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _auditLogs.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.shield_outlined, size: 48, color: Colors.grey.shade400),
                            const SizedBox(height: 12),
                            Text(
                              'No audit logs found',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.grey.shade600),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'All field-level changes will appear here',
                              style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
                            ),
                          ],
                        ),
                      )
                    : Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5)),
                        ),
                        child: ListView.separated(
                          itemCount: _auditLogs.length,
                          separatorBuilder: (_, _) => Divider(height: 1, color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3)),
                          itemBuilder: (context, index) {
                            final log = _auditLogs[index];
                            final color = _actionColor(log.action);
                            return ListTile(
                              leading: Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: color.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(_actionIcon(log.action), size: 18, color: color),
                              ),
                              title: Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      log.consumerNo,
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: color.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      log.action,
                                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color),
                                    ),
                                  ),
                                ],
                              ),
                              subtitle: Text(
                                '${log.fieldName ?? 'Field'}: ${log.oldValue ?? 'None'} → ${log.newValue ?? 'None'}\n'
                                'By ${log.userEmail ?? 'Staff'} • ${_formatDate(log.createdAt)}',
                                style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant),
                              ),
                              isThreeLine: true,
                              dense: isMobile,
                            );
                          },
                        ),
                      ),
          ),

          // Pagination
          if (_totalCount > _pageSize) ...[
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: _page > 1
                      ? () {
                          setState(() => _page--);
                          _loadAuditLogs();
                        }
                      : null,
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Page $_page of $_totalPages',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: _page < _totalPages
                      ? () {
                          setState(() => _page++);
                          _loadAuditLogs();
                        }
                      : null,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  String _formatDate(DateTime dt) {
    final local = dt.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    final year = local.year;
    final hour = local.hour.toString().padLeft(2, '0');
    final min = local.minute.toString().padLeft(2, '0');
    return '$day/$month/$year $hour:$min';
  }
}
