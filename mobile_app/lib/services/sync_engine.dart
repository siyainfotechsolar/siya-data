import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app_database.dart';
import 'connectivity_service.dart';
import 'supabase_service.dart';
import '../models/consumer_record.dart';
import '../models/lead_record.dart';

class SyncResult {
  final bool success;
  final int pushedCount;
  final int pulledCount;
  final int conflictCount;
  final String? errorMessage;

  const SyncResult({
    required this.success,
    this.pushedCount = 0,
    this.pulledCount = 0,
    this.conflictCount = 0,
    this.errorMessage,
  });
}

/// Deterministic 2-Way Synchronization Engine
class SyncEngine {
  static SupabaseClient get _client => SupabaseService.client;
  static bool _isSyncing = false;

  static bool get isSyncing => _isSyncing;

  /// Initialize sync engine and connect to connectivity change hooks
  static void initialize() {
    ConnectivityService.onReconnected = () {
      debugPrint('[SyncEngine] Automatic background sync triggered on network reconnection.');
      syncNow();
    };
  }

  /// Trigger full synchronization (Push pending local ops -> Pull remote deltas)
  static Future<SyncResult> syncNow() async {
    if (_isSyncing) {
      debugPrint('[SyncEngine] Sync already in progress, skipping duplicate call.');
      return const SyncResult(success: true);
    }

    final isConnected = await ConnectivityService.checkConnectivity();
    if (!isConnected) {
      debugPrint('[SyncEngine] Cannot sync: Device is currently offline.');
      return const SyncResult(
        success: false,
        errorMessage: 'Cannot synchronize while offline.',
      );
    }

    _isSyncing = true;
    ConnectivityService.setSyncing(true);

    int pushed = 0;
    int pulled = 0;
    int conflicts = 0;
    String? error;

    try {
      // 1. PUSH PHASE: Process pending local mutations in deterministic FIFO order
      final pendingOps = await AppDatabase.getPendingOperations();
      for (final op in pendingOps) {
        try {
          await AppDatabase.updateOperationStatus(
            operationId: op.operationId,
            syncStatus: 'SYNCING',
          );

          final opResult = await _processOperation(op);
          if (opResult == 'SUCCESS') {
            await AppDatabase.deleteOperation(op.operationId);
            pushed++;
          } else if (opResult == 'CONFLICT') {
            await AppDatabase.updateOperationStatus(
              operationId: op.operationId,
              syncStatus: 'CONFLICT',
            );
            conflicts++;
          }
        } catch (e) {
          final newRetryCount = op.retryCount + 1;
          debugPrint('[SyncEngine] Error processing operation ${op.operationId} (attempt $newRetryCount): $e');

          if (newRetryCount >= 10) {
            // Dead-letter: operation has exceeded max retries. Mark ABANDONED
            // so it never blocks the sync queue again.
            await AppDatabase.updateOperationStatus(
              operationId: op.operationId,
              syncStatus: 'ABANDONED',
              retryCount: newRetryCount,
              errorMessage: 'Max retries exceeded. Last error: ${e.toString()}',
            );
            debugPrint('[SyncEngine] Operation ${op.operationId} ABANDONED after $newRetryCount attempts.');
          } else {
            await AppDatabase.updateOperationStatus(
              operationId: op.operationId,
              syncStatus: 'FAILED',
              retryCount: newRetryCount,
              errorMessage: e.toString(),
            );
          }
        }

      }

      // 2. PUSH OFFLINE ACTIVITY LOGS
      await _syncPendingActivityLogs();

      // 3. PULL PHASE: Download remote delta changes scoped to staff permissions
      pulled = await _pullRemoteChanges();

      // 4. Update sync timestamps
      final nowIso = DateTime.now().toUtc().toIso8601String();
      await AppDatabase.setMetadata('last_successful_sync', nowIso);
      await AppDatabase.setMetadata('last_pull_timestamp', nowIso);

      ConnectivityService.setSyncing(false);
      debugPrint('[SyncEngine] Sync completed successfully! Pushed: $pushed, Pulled: $pulled, Conflicts: $conflicts');
      return SyncResult(
        success: true,
        pushedCount: pushed,
        pulledCount: pulled,
        conflictCount: conflicts,
      );
    } catch (e) {
      debugPrint('[SyncEngine] Fatal sync failure: $e');
      ConnectivityService.setSyncError();
      error = e.toString();
      return SyncResult(
        success: false,
        pushedCount: pushed,
        pulledCount: pulled,
        conflictCount: conflicts,
        errorMessage: error,
      );
    } finally {
      _isSyncing = false;
    }
  }

  /// Process individual offline operation idempotently
  static Future<String> _processOperation(OfflineOperation op) async {
    switch (op.entityType) {
      case 'consumer_record':
        return await _processConsumerRecordOp(op);
      case 'task':
        return await _processTaskOp(op);
      case 'payment':
        return await _processPaymentOp(op);
      case 'payment_verification':
        return await _processPaymentVerificationOp(op);
      case 'lead':
        return await _processLeadOp(op);
      case 'misc_action':
        return await _processMiscOp(op);
      case 'issue':
        return await _processIssueOp(op);
      case 'customer_followup':
        return await _processFollowupOp(op);
      default:
        return 'SUCCESS';
    }
  }

  static Future<String> _processConsumerRecordOp(OfflineOperation op) async {
    final recordId = op.entityId;
    final payload = Map<String, dynamic>.from(op.payload);

    // Fetch current server state to detect conflicts
    final remoteRecord = await _client
        .from('consumer_records')
        .select()
        .eq('id', recordId)
        .maybeSingle();

    if (remoteRecord != null) {
      final remoteUpdatedAtStr = remoteRecord['updated_at']?.toString();
      final remoteUpdatedAt = remoteUpdatedAtStr != null ? DateTime.tryParse(remoteUpdatedAtStr) : null;

      // Conflict condition: server updated after operation was queued and data differs
      if (remoteUpdatedAt != null && remoteUpdatedAt.isAfter(op.createdAt)) {
        bool hasConflict = false;
        for (final key in payload.keys) {
          if (key == 'updated_at' || key == 'updated_by') continue;
          if (remoteRecord[key]?.toString() != payload[key]?.toString()) {
            hasConflict = true;
            break;
          }
        }

        if (hasConflict) {
          await AppDatabase.recordConflict(
            SyncConflict(
              conflictId: 'conf_${op.operationId}',
              operationId: op.operationId,
              entityType: 'consumer_record',
              entityId: recordId,
              localPayload: payload,
              serverPayload: remoteRecord,
              detectedAt: DateTime.now(),
            ),
          );
          return 'CONFLICT';
        }
      }
    }

    // Apply idempotent update to Supabase
    final updatedResponse = await _client
        .from('consumer_records')
        .update(payload)
        .eq('id', recordId)
        .select()
        .single();

    // Reconcile local SQLite record
    final confirmed = ConsumerRecord.fromJson(updatedResponse);
    await AppDatabase.upsertConsumerRecord(confirmed, syncStatus: 'SYNCED');

    // Post audit log with client_operation_id for duplicate protection
    try {
      final user = SupabaseService.currentUser;
      await _client.from('audit_logs').insert({
        'record_id': recordId,
        'consumer_no': confirmed.consumerNo,
        'action': op.action,
        'changed_by': user?.id,
        'client_operation_id': op.operationId,
        'source': 'Mobile App (Offline-Sync)',
        'created_at': op.createdAt.toIso8601String(),
      });
    } catch (_) {}

    return 'SUCCESS';
  }

  static Future<String> _processTaskOp(OfflineOperation op) async {
    final payload = Map<String, dynamic>.from(op.payload);
    String? localFilePath = payload['local_file_path']?.toString();
    String? remoteDocUrl = payload['document_url']?.toString();

    // If document is local and not yet uploaded, upload to Supabase Storage
    if (localFilePath != null && localFilePath.isNotEmpty && (remoteDocUrl == null || remoteDocUrl.isEmpty)) {
      final file = File(localFilePath);
      if (await file.exists()) {
        final fileName = '${DateTime.now().millisecondsSinceEpoch}_${file.uri.pathSegments.last}';
        final storagePath = 'tasks/$fileName';
        await _client.storage.from('customer-documents').upload(storagePath, file);
        remoteDocUrl = _client.storage.from('customer-documents').getPublicUrl(storagePath);
        payload['document_url'] = remoteDocUrl;
      }
    }

    payload['sync_status'] = 'Synced';
    payload['client_operation_id'] = op.operationId;

    try {
      await _client.from('customer_tasks').upsert(payload);
    } catch (_) {
      // Fallback to customer_issues if customer_tasks is not in schema cache
      await _client.from('customer_issues').upsert({
        'id': payload['id'],
        'customer_id': payload['customer_id'],
        'consumer_no': payload['consumer_no'] ?? '',
        'customer_name': payload['customer_name'] ?? '',
        'title': payload['title'] ?? 'Customer Document Update',
        'issue_type': 'Customer Document',
        'priority': payload['priority'] ?? 'Normal',
        'status': payload['status'] == 'Complete' ? 'Resolved' : 'Open',
        'description': '${payload['document_name']} (${payload['source']})',
        'attachment_url': remoteDocUrl,
      });
    }

    return 'SUCCESS';
  }

  static Future<String> _processPaymentOp(OfflineOperation op) async {
    final payload = Map<String, dynamic>.from(op.payload);
    payload['client_tx_id'] = payload['client_tx_id'] ?? op.operationId;
    payload['idempotency_key'] = payload['idempotency_key'] ?? 'tx_${op.operationId}';

    // If payment has a local attachment and no remote url, upload to customer-documents bucket
    final localPath = payload['local_attachment_path'] as String?;
    String? attachmentUrl = payload['attachment_url'] as String?;
    if (localPath != null && localPath.isNotEmpty && (attachmentUrl == null || attachmentUrl.isEmpty)) {
      final file = File(localPath);
      if (await file.exists()) {
        try {
          final fileName = 'proof_${DateTime.now().millisecondsSinceEpoch}_${file.uri.pathSegments.last}';
          final storagePath = 'payments/$fileName';
          await _client.storage.from('customer-documents').upload(storagePath, file);
          attachmentUrl = _client.storage.from('customer-documents').getPublicUrl(storagePath);
          payload['attachment_url'] = attachmentUrl;
        } catch (_) {}
      }
    }

    payload['sync_status'] = 'Synced';

    await _client.from('customer_payment_transactions').upsert(
      payload,
      onConflict: 'client_tx_id',
    );

    return 'SUCCESS';
  }

  static Future<String> _processPaymentVerificationOp(OfflineOperation op) async {
    final payload = Map<String, dynamic>.from(op.payload);
    final paymentId = payload['payment_id']?.toString() ?? op.entityId;

    await _client.from('customer_payment_transactions').update({
      'verification_status': payload['verification_status'],
      'verification_remarks': payload['verification_remarks'],
      'verified_by': payload['verified_by'],
      'verified_by_name': payload['verified_by_name'],
      'verified_at': payload['verified_at'] ?? DateTime.now().toUtc().toIso8601String(),
    }).or('id.eq.$paymentId,client_tx_id.eq.$paymentId');

    return 'SUCCESS';
  }

  static Future<String> _processLeadOp(OfflineOperation op) async {
    final payload = Map<String, dynamic>.from(op.payload);
    await _client.from('leads').upsert(payload);
    return 'SUCCESS';
  }

  static Future<String> _processMiscOp(OfflineOperation op) async {
    final payload = Map<String, dynamic>.from(op.payload);
    if (op.action == 'CREATE_MISC') {
      await _client.from('customer_misc_actions').upsert(payload);
    } else {
      await _client.from('customer_misc_actions').update(payload).eq('id', op.entityId);
    }
    return 'SUCCESS';
  }

  static Future<String> _processIssueOp(OfflineOperation op) async {
    final payload = Map<String, dynamic>.from(op.payload);
    if (op.action == 'CREATE_ISSUE') {
      await _client.from('customer_issues').upsert(payload);
    } else {
      await _client.from('customer_issues').update(payload).eq('id', op.entityId);
    }
    return 'SUCCESS';
  }

  static Future<String> _processFollowupOp(OfflineOperation op) async {
    final payload = Map<String, dynamic>.from(op.payload);
    if (op.action == 'MARK_FOLLOWUP') {
      await _client.from('customer_followups').insert(payload);
    } else if (op.action == 'COMPLETE_FOLLOWUP') {
      await _client
          .from('customer_followups')
          .update(payload)
          .eq('record_id', op.entityId)
          .eq('status', 'PENDING');
    }
    return 'SUCCESS';
  }

  static Future<void> _syncPendingActivityLogs() async {
    final pendingLogs = await AppDatabase.getPendingActivityLogs();
    for (final log in pendingLogs) {
      try {
        await _client.from('activity_logs').insert(log.toJson());
        await AppDatabase.markActivityLogSynced(log.id);
      } catch (_) {}
    }
  }

  /// Pull delta changes from server since last sync
  static Future<int> _pullRemoteChanges() async {
    final lastSyncStr = await AppDatabase.getMetadata('last_pull_timestamp');
    final user = SupabaseService.currentUser;

    dynamic query = _client
        .from('consumer_records')
        .select()
        .eq('deleted', false)
        .eq('is_merged', false);

    if (lastSyncStr != null && lastSyncStr.isNotEmpty) {
      query = query.gt('updated_at', lastSyncStr);
    } else {
      // First sync: pull latest active records
      query = query.order('updated_at', ascending: false).limit(500);
    }

    // Role-based scope
    final role = user?.userMetadata?['role']?.toString().toLowerCase();
    if (role == 'staff' && user != null) {
      query = query.or('assigned_staff_id.eq.${user.id},assigned_staff_id.is.null');
    }

    final List<dynamic> recordsData = await query;
    final List<ConsumerRecord> records = recordsData
        .map((json) => ConsumerRecord.fromJson(json as Map<String, dynamic>))
        .toList();

    if (records.isNotEmpty) {
      await AppDatabase.batchUpsertConsumerRecords(records, syncStatus: 'SYNCED');
    }

    // Also pull latest leads
    try {
      dynamic leadQuery = _client.from('leads').select().eq('deleted', false);
      if (lastSyncStr != null && lastSyncStr.isNotEmpty) {
        leadQuery = leadQuery.gt('updated_at', lastSyncStr);
      } else {
        leadQuery = leadQuery.order('updated_at', ascending: false).limit(200);
      }
      final List<dynamic> leadsData = await leadQuery;
      for (final l in leadsData) {
        final lead = LeadRecord.fromJson(l as Map<String, dynamic>);
        await AppDatabase.upsertLead(lead, syncStatus: 'SYNCED');
      }
    } catch (_) {}

    return records.length;
  }

  /// Retry failed operations specifically
  static Future<SyncResult> retryFailed() async {
    final db = await AppDatabase.database;
    await db.update(
      'offline_operations_queue',
      {'sync_status': 'PENDING'},
      where: "sync_status = 'FAILED'",
    );
    return await syncNow();
  }
}
