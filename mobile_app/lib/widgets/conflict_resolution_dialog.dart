import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/app_database.dart';
import '../services/sync_engine.dart';
import '../services/activity_log_service.dart';

class ConflictResolutionDialog extends StatefulWidget {
  final SyncConflict conflict;
  final VoidCallback onResolved;

  const ConflictResolutionDialog({
    super.key,
    required this.conflict,
    required this.onResolved,
  });

  @override
  State<ConflictResolutionDialog> createState() => _ConflictResolutionDialogState();
}

class _ConflictResolutionDialogState extends State<ConflictResolutionDialog> {
  bool _isResolving = false;

  String _formatDate(DateTime dt) => DateFormat('dd MMM yyyy, hh:mm a').format(dt);

  Future<void> _handleKeepServer() async {
    setState(() => _isResolving = true);
    await AppDatabase.resolveConflict(widget.conflict.conflictId);
    await ActivityLogService.logActivity(
      recordId: widget.conflict.entityId,
      consumerNo: widget.conflict.consumerNo ?? '-',
      customerName: widget.conflict.customerName ?? 'Customer',
      module: 'Sync Center',
      action: 'CONFLICT_RESOLVED_KEEP_SERVER',
      remarks: 'Kept server version during conflict resolution',
    );
    if (mounted) {
      widget.onResolved();
      Navigator.pop(context);
    }
  }

  Future<void> _handleKeepLocal() async {
    setState(() => _isResolving = true);
    // Mark operation as PENDING so SyncEngine will push local value again
    await AppDatabase.updateOperationStatus(
      operationId: widget.conflict.operationId,
      syncStatus: 'PENDING',
    );
    await AppDatabase.resolveConflict(widget.conflict.conflictId);
    await ActivityLogService.logActivity(
      recordId: widget.conflict.entityId,
      consumerNo: widget.conflict.consumerNo ?? '-',
      customerName: widget.conflict.customerName ?? 'Customer',
      module: 'Sync Center',
      action: 'CONFLICT_RESOLVED_KEEP_LOCAL',
      remarks: 'Enforced local version during conflict resolution',
    );
    await SyncEngine.syncNow();
    if (mounted) {
      widget.onResolved();
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final local = widget.conflict.localPayload;
    final server = widget.conflict.serverPayload;

    // Identify conflicting keys
    final conflictKeys = <String>[];
    for (final k in local.keys) {
      if (k == 'updated_at' || k == 'updated_by') continue;
      if (server[k]?.toString() != local[k]?.toString()) {
        conflictKeys.add(k);
      }
    }

    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: Colors.orange),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'Conflict Detected',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Different updates were made on this device and on the server for Entity ID: ${widget.conflict.entityId}',
                style: const TextStyle(fontSize: 13, color: Colors.black87),
              ),
              const SizedBox(height: 12),
              Text(
                'Detected At: ${_formatDate(widget.conflict.detectedAt)}',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
              ),
              const Divider(height: 20),
              const Text(
                'Conflicting Fields:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const SizedBox(height: 8),
              ...conflictKeys.map((k) {
                final localVal = local[k]?.toString() ?? '<None>';
                final serverVal = server[k]?.toString() ?? '<None>';
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(k, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Local Value:', style: TextStyle(fontSize: 10, color: Colors.blue)),
                                Text(localVal, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Server Value:', style: TextStyle(fontSize: 10, color: Colors.purple)),
                                Text(serverVal, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
      ),
      actions: [
        if (_isResolving)
          const Center(child: CircularProgressIndicator())
        else ...[
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Later'),
          ),
          OutlinedButton(
            onPressed: _handleKeepServer,
            child: const Text('Keep Server'),
          ),
          FilledButton(
            onPressed: _handleKeepLocal,
            child: const Text('Keep Local'),
          ),
        ],
      ],
    );
  }
}
