import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/app_database.dart';
import '../services/connectivity_service.dart';
import '../services/sync_engine.dart';
import '../widgets/conflict_resolution_dialog.dart';

class SyncCenterScreen extends StatefulWidget {
  const SyncCenterScreen({super.key});

  @override
  State<SyncCenterScreen> createState() => _SyncCenterScreenState();
}

class _SyncCenterScreenState extends State<SyncCenterScreen> {
  bool _isLoading = true;
  String? _lastSyncTime;
  int _pendingChanges = 0;
  int _pendingPayments = 0;
  int _pendingTasks = 0;
  int _failedOps = 0;
  int _conflictsCount = 0;
  List<OfflineOperation> _operations = [];
  List<SyncConflict> _conflicts = [];

  @override
  void initState() {
    super.initState();
    _loadSyncData();
  }

  Future<void> _loadSyncData() async {
    setState(() => _isLoading = true);

    final lastSync = await AppDatabase.getMetadata('last_successful_sync');
    final pendingChanges = await AppDatabase.getPendingOperationsCount();
    final pendingPayments = await AppDatabase.getPendingPaymentsCount();
    final pendingTasks = await AppDatabase.getPendingTasksCount();
    final failedOps = await AppDatabase.getFailedOperationsCount();
    final conflictsCount = await AppDatabase.getActiveConflictsCount();
    final ops = await AppDatabase.getPendingOperations(limit: 50);
    final conflicts = await AppDatabase.getActiveConflicts();

    if (mounted) {
      setState(() {
        _lastSyncTime = lastSync;
        _pendingChanges = pendingChanges;
        _pendingPayments = pendingPayments;
        _pendingTasks = pendingTasks;
        _failedOps = failedOps;
        _conflictsCount = conflictsCount;
        _operations = ops;
        _conflicts = conflicts;
        _isLoading = false;
      });
    }
  }

  String _formatDateTime(String? iso) {
    if (iso == null || iso.isEmpty) return 'Never';
    final dt = DateTime.tryParse(iso);
    if (dt == null) return iso;
    return DateFormat('dd MMM yyyy, hh:mm a').format(dt.toLocal());
  }

  Future<void> _triggerSyncNow() async {
    final res = await SyncEngine.syncNow();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            res.success
                ? 'Sync completed! Pushed: ${res.pushedCount}, Pulled: ${res.pulledCount}'
                : 'Sync failed: ${res.errorMessage}',
          ),
          backgroundColor: res.success ? const Color(0xFF059669) : Colors.red,
        ),
      );
      _loadSyncData();
    }
  }

  Future<void> _triggerRetryFailed() async {
    final res = await SyncEngine.retryFailed();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            res.success
                ? 'Retry completed successfully!'
                : 'Retry failed: ${res.errorMessage}',
          ),
          backgroundColor: res.success ? const Color(0xFF059669) : Colors.red,
        ),
      );
      _loadSyncData();
    }
  }

  void _showConflictDialog(SyncConflict conflict) {
    showDialog(
      context: context,
      builder: (_) => ConflictResolutionDialog(
        conflict: conflict,
        onResolved: _loadSyncData,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sync Center', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Status',
            onPressed: _loadSyncData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadSyncData,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // 1. Connection Status Banner
                  ValueListenableBuilder<SyncMode>(
                    valueListenable: ConnectivityService.modeNotifier,
                    builder: (context, mode, _) {
                      Color bannerColor;
                      Color textColor;
                      IconData bannerIcon;
                      String title;
                      String subtitle;

                      switch (mode) {
                        case SyncMode.online:
                          bannerColor = const Color(0xFFDCFCE7);
                          textColor = const Color(0xFF166534);
                          bannerIcon = Icons.cloud_done_rounded;
                          title = 'Connected & Online';
                          subtitle = 'Live connection to server. Changes sync automatically.';
                          break;
                        case SyncMode.offline:
                          bannerColor = const Color(0xFFFEE2E2);
                          textColor = const Color(0xFF991B1B);
                          bannerIcon = Icons.cloud_off_rounded;
                          title = 'Offline — Local Mode';
                          subtitle = 'Operating from persistent local storage. Work safely without internet.';
                          break;
                        case SyncMode.syncing:
                          bannerColor = const Color(0xFFE0F2FE);
                          textColor = const Color(0xFF075985);
                          bannerIcon = Icons.sync_rounded;
                          title = 'Synchronizing...';
                          subtitle = 'Sending local changes and fetching latest remote data.';
                          break;
                        case SyncMode.syncError:
                          bannerColor = const Color(0xFFFEF3C7);
                          textColor = const Color(0xFF92400E);
                          bannerIcon = Icons.warning_amber_rounded;
                          title = 'Synchronization Issue';
                          subtitle = 'Previous sync failed. Local data is safe. Tap Retry.';
                          break;
                      }

                      return Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: bannerColor,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: textColor.withValues(alpha: 0.2)),
                        ),
                        child: Row(
                          children: [
                            Icon(bannerIcon, size: 32, color: textColor),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    title,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                      color: textColor,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    subtitle,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: textColor.withValues(alpha: 0.85),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 16),

                  // 2. Metrics Grid
                  Card(
                    elevation: 1,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.schedule, size: 16, color: Colors.grey),
                              const SizedBox(width: 6),
                              Text(
                                'Last Successful Sync:',
                                style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                              ),
                              const Spacer(),
                              Text(
                                _formatDateTime(_lastSyncTime),
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                              ),
                            ],
                          ),
                          const Divider(height: 24),
                          Row(
                            children: [
                              _buildMetricTile('Pending Changes', '$_pendingChanges', Colors.blue),
                              _buildMetricTile('Pending Payments', '$_pendingPayments', Colors.teal),
                              _buildMetricTile('Pending Tasks', '$_pendingTasks', Colors.orange),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              _buildMetricTile('Failed Syncs', '$_failedOps', Colors.red),
                              _buildMetricTile('Conflicts', '$_conflictsCount', Colors.purple),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // 3. Action Buttons
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: SyncEngine.isSyncing ? null : _triggerSyncNow,
                          icon: const Icon(Icons.sync_rounded),
                          label: const Text('Sync Now'),
                          style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12)),
                        ),
                      ),
                      if (_failedOps > 0) ...[
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: SyncEngine.isSyncing ? null : _triggerRetryFailed,
                            icon: const Icon(Icons.replay_rounded),
                            label: const Text('Retry Failed'),
                            style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12)),
                          ),
                        ),
                      ],
                    ],
                  ),

                  // 4. Conflicts Section (if any)
                  if (_conflicts.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    const Text(
                      'CONCURRENT CONFLICTS',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.purple),
                    ),
                    const SizedBox(height: 8),
                    ..._conflicts.map((conf) {
                      return Card(
                        color: Colors.purple.shade50,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        child: ListTile(
                          leading: const Icon(Icons.warning_amber, color: Colors.purple),
                          title: Text('Conflict: ${conf.entityType} (${conf.entityId})'),
                          subtitle: Text('Detected: ${_formatDateTime(conf.detectedAt.toIso8601String())}'),
                          trailing: FilledButton.tonal(
                            onPressed: () => _showConflictDialog(conf),
                            child: const Text('Resolve'),
                          ),
                        ),
                      );
                    }),
                  ],

                  const SizedBox(height: 20),

                  // 5. Operations Queue Details
                  const Text(
                    'LOCAL OPERATIONS QUEUE',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey),
                  ),
                  const SizedBox(height: 8),
                  if (_operations.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(24),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          Icon(Icons.check_circle_outline, size: 36, color: Colors.green.shade600),
                          const SizedBox(height: 8),
                          const Text(
                            'All local operations are fully synchronized!',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                        ],
                      ),
                    )
                  else
                    ..._operations.map((op) {
                      Color statusColor;
                      switch (op.syncStatus) {
                        case 'SYNCED':
                          statusColor = Colors.green;
                          break;
                        case 'SYNCING':
                          statusColor = Colors.blue;
                          break;
                        case 'FAILED':
                          statusColor = Colors.red;
                          break;
                        case 'CONFLICT':
                          statusColor = Colors.purple;
                          break;
                        default:
                          statusColor = Colors.orange;
                      }

                      return Card(
                        elevation: 1,
                        margin: const EdgeInsets.only(bottom: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        child: ListTile(
                          title: Text(
                            '${op.action} (${op.entityType})',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Entity ID: ${op.entityId}', style: const TextStyle(fontSize: 11)),
                              Text(
                                'Queued: ${_formatDateTime(op.createdAt.toIso8601String())}',
                                style: const TextStyle(fontSize: 10, color: Colors.grey),
                              ),
                              if (op.errorMessage != null)
                                Text(
                                  'Error: ${op.errorMessage}',
                                  style: const TextStyle(fontSize: 10, color: Colors.red),
                                ),
                            ],
                          ),
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: statusColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              op.syncStatus,
                              style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      );
                    }),
                ],
              ),
            ),
    );
  }

  Widget _buildMetricTile(String label, String value, Color color) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: color),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 10, color: Colors.black87),
            ),
          ],
        ),
      ),
    );
  }
}
