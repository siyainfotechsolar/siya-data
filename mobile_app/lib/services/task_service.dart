import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/customer_task.dart';
import '../models/consumer_record.dart';
import 'supabase_service.dart';
import 'activity_log_service.dart';
import 'offline_task_sync_service.dart';

class CustomerMatchResult {
  final ConsumerRecord customer;
  final int confidenceScore; // 0 - 100
  final String confidenceLabel; // 'High Confidence', 'Medium Confidence'
  final String matchReason; // 'Exact Consumer No Match', 'Exact Mobile Match', etc.

  const CustomerMatchResult({
    required this.customer,
    required this.confidenceScore,
    required this.confidenceLabel,
    required this.matchReason,
  });

  bool get isHighConfidence => confidenceScore >= 85;
}

class TaskService {
  static SupabaseClient get _client => SupabaseService.client;

  /// Find suggested customer based on extracted document identifiers
  static Future<CustomerMatchResult?> findSuggestedCustomer({
    String? consumerNo,
    String? mobile,
    String? applicationId,
    String? name,
  }) async {
    try {
      // 1. Try exact consumer number match (Highest Confidence)
      if (consumerNo != null && consumerNo.trim().isNotEmpty) {
        final cleanCons = consumerNo.trim().replaceAll(RegExp(r'[^0-9]'), '');
        final data = await _client
            .from('consumer_records')
            .select()
            .or('consumer_no.eq.$cleanCons,consumer_no.ilike.%$cleanCons%')
            .maybeSingle();
        if (data != null) {
          final customer = ConsumerRecord.fromJson(data);
          return CustomerMatchResult(
            customer: customer,
            confidenceScore: 100,
            confidenceLabel: 'High Confidence',
            matchReason: 'Exact Consumer Number Match ($cleanCons)',
          );
        }
      }

      // 2. Try exact application ID match
      if (applicationId != null && applicationId.trim().isNotEmpty) {
        final cleanAppId = applicationId.trim();
        final data = await _client
            .from('consumer_records')
            .select()
            .eq('application_id', cleanAppId)
            .maybeSingle();
        if (data != null) {
          final customer = ConsumerRecord.fromJson(data);
          return CustomerMatchResult(
            customer: customer,
            confidenceScore: 95,
            confidenceLabel: 'High Confidence',
            matchReason: 'Exact Application ID Match ($cleanAppId)',
          );
        }
      }

      // 3. Try exact mobile number match
      if (mobile != null && mobile.trim().length >= 10) {
        final cleanMobile = mobile.trim().replaceAll(RegExp(r'[^0-9]'), '');
        final last10 = cleanMobile.length >= 10
            ? cleanMobile.substring(cleanMobile.length - 10)
            : cleanMobile;
        final data = await _client
            .from('consumer_records')
            .select()
            .or('mobile.eq.$last10,mobile.ilike.%$last10%')
            .maybeSingle();
        if (data != null) {
          final customer = ConsumerRecord.fromJson(data);
          return CustomerMatchResult(
            customer: customer,
            confidenceScore: 90,
            confidenceLabel: 'High Confidence',
            matchReason: 'Exact Mobile Match ($last10)',
          );
        }
      }

      // 4. Try fuzzy name match
      if (name != null && name.trim().length >= 4) {
        final cleanName = name.trim();
        final list = await _client
            .from('consumer_records')
            .select()
            .ilike('name', '%$cleanName%')
            .limit(1);
        if (list.isNotEmpty) {
          final customer = ConsumerRecord.fromJson(list.first);
          return CustomerMatchResult(
            customer: customer,
            confidenceScore: 65,
            confidenceLabel: 'Medium Confidence',
            matchReason: 'Name Similarity ($cleanName)',
          );
        }
      }
    } catch (e) {
      debugPrint('Error finding suggested customer: $e');
    }
    return null;
  }

  /// Search customers by name, consumer number, mobile, application ID, village
  static Future<List<ConsumerRecord>> searchCustomers(String query) async {
    if (query.trim().isEmpty) return [];
    try {
      final q = query.trim();
      final res = await _client
          .from('consumer_records')
          .select()
          .or('name.ilike.%$q%,consumer_no.ilike.%$q%,mobile.ilike.%$q%,application_id.ilike.%$q%,address.ilike.%$q%')
          .limit(20);
      return res.map((map) => ConsumerRecord.fromJson(map)).toList();
    } catch (e) {
      debugPrint('Error searching customers: $e');
      return [];
    }
  }

  /// Check if file hash or (customerId + docType) already exists
  static Future<CustomerTask?> checkDuplicate({
    String? fileHash,
    required String customerId,
    required String documentType,
  }) async {
    try {
      // Check offline queue first
      final pendingList = await OfflineTaskSyncService.getPendingTasks();
      for (final pt in pendingList) {
        if (fileHash != null &&
            fileHash.isNotEmpty &&
            pt.fileHash == fileHash) {
          return pt;
        }
        if (pt.customerId == customerId && pt.documentType == documentType) {
          return pt;
        }
      }

      // Check remote customer_tasks table
      if (fileHash != null && fileHash.isNotEmpty) {
        final data = await _client
            .from('customer_tasks')
            .select()
            .eq('file_hash', fileHash)
            .maybeSingle();
        if (data != null) {
          return CustomerTask.fromMap(data);
        }
      }

      // Check customer id + document type recent duplicates
      final list = await _client
          .from('customer_tasks')
          .select()
          .eq('customer_id', customerId)
          .eq('document_type', documentType)
          .order('created_at', ascending: false)
          .limit(1);
      if (list.isNotEmpty) {
        return CustomerTask.fromMap(list.first);
      }
    } catch (e) {
      debugPrint('Duplicate check warning: $e');
    }
    return null;
  }

  /// Upload document to Supabase Storage bucket 'customer-documents'
  static Future<String?> uploadDocumentFile({
    required String localFilePath,
    required String fileName,
    required String customerId,
  }) async {
    try {
      final file = File(localFilePath);
      if (!await file.exists()) return null;

      final storagePath =
          '$customerId/${DateTime.now().millisecondsSinceEpoch}_$fileName';

      await _client.storage
          .from('customer-documents')
          .upload(storagePath, file, fileOptions: FileOptions(upsert: true));

      final publicUrl = _client.storage
          .from('customer-documents')
          .getPublicUrl(storagePath);

      return publicUrl;
    } catch (e) {
      debugPrint('Storage upload error: $e');
      return null;
    }
  }

  /// Create a new Task with document attachment and activity log
  static Future<CustomerTask> createTask(CustomerTask task) async {
    String? remoteUrl = task.documentUrl;

    // 1. Try uploading file to storage if online and has local file
    if (task.localFilePath != null && remoteUrl == null) {
      try {
        remoteUrl = await uploadDocumentFile(
          localFilePath: task.localFilePath!,
          fileName: task.documentName,
          customerId: task.customerId,
        );
      } catch (_) {}
    }

    final taskToSave = task.copyWith(
      documentUrl: remoteUrl,
    );

    // 2. Try saving to Supabase
    try {
      final payload = taskToSave.toMap();
      payload.remove('id'); // let Supabase gen_random_uuid() or provide taskToSave.id
      payload['id'] = taskToSave.id;

      try {
        final res = await _client
            .from('customer_tasks')
            .insert(payload)
            .select()
            .single();

        final createdTask = CustomerTask.fromMap(res);

        // Also record in customer_documents
        try {
          await _client.from('customer_documents').insert({
            'customer_id': createdTask.customerId,
            'consumer_no': createdTask.consumerNo,
            'document_type': createdTask.documentType,
            'document_name': createdTask.documentName,
            'file_url': createdTask.documentUrl ?? createdTask.localFilePath ?? '',
            'file_hash': createdTask.fileHash,
            'file_size': createdTask.fileSize,
            'source': createdTask.source,
            'task_id': createdTask.id,
            'extracted_data': createdTask.extractedData,
            'uploaded_by': createdTask.createdBy,
            'uploaded_by_name': createdTask.createdByName,
            'created_at': DateTime.now().toUtc().toIso8601String(),
          });
        } catch (_) {}

        // Log Activity in activity_logs
        await ActivityLogService.logActivity(
          recordId: createdTask.customerId,
          consumerNo: createdTask.consumerNo,
          customerName: createdTask.customerName,
          module: 'Task',
          action: 'WhatsApp PDF → Task Created',
          newValue: '${createdTask.documentType} (${createdTask.documentName})',
          remarks: 'Task ID: ${createdTask.id} | Source: ${createdTask.source}',
          source: createdTask.source,
          metadata: {
            'taskId': createdTask.id,
            'documentType': createdTask.documentType,
            'priority': createdTask.priority,
            'fileHash': createdTask.fileHash,
          },
        );

        return createdTask;
      } catch (err) {
        debugPrint('customer_tasks insert failed, falling back: $err');
        // If customer_tasks table is not migrated in Supabase yet, fallback to customer_issues
        try {
          await _client.from('customer_issues').insert({
            'customer_id': taskToSave.customerId,
            'customer_name': taskToSave.customerName,
            'consumer_no': taskToSave.consumerNo,
            'mobile_number': taskToSave.mobileNumber,
            'issue_type': 'Customer Document Update',
            'title': taskToSave.title,
            'description': 'WhatsApp Shared Doc: ${taskToSave.documentName}',
            'priority': taskToSave.priority,
            'status': 'New',
            'assigned_staff': taskToSave.assignedStaff,
            'due_date': taskToSave.dueDate?.toIso8601String().split('T').first,
            'remarks': 'Document Type: ${taskToSave.documentType} | File: ${taskToSave.documentUrl ?? taskToSave.localFilePath}',
            'created_by': taskToSave.createdBy,
            'created_by_name': taskToSave.createdByName,
          });
        } catch (_) {}
      }

      return taskToSave;
    } catch (offlineError) {
      // OFFLINE FALLBACK: Save locally to persistent queue
      debugPrint('Offline mode: saving task locally. $offlineError');
      final offlineTask = taskToSave.copyWith(
        syncStatus: 'Pending Sync',
      );
      await OfflineTaskSyncService.enqueueTask(offlineTask);
      return offlineTask;
    }
  }

  /// Sync all pending offline tasks to Supabase
  static Future<int> syncPendingOfflineTasks() async {
    final pending = await OfflineTaskSyncService.getPendingTasks();
    if (pending.isEmpty) return 0;

    int syncedCount = 0;
    for (final task in pending) {
      try {
        final synced = await createTask(task.copyWith(syncStatus: 'Synced'));
        if (synced.syncStatus == 'Synced') {
          await OfflineTaskSyncService.dequeueTask(task.id);
          syncedCount++;
        }
      } catch (e) {
        debugPrint('Failed to sync offline task ${task.id}: $e');
      }
    }
    return syncedCount;
  }

  /// Fetch all tasks (combines offline pending tasks with remote tasks)
  static Future<List<CustomerTask>> fetchTasks({
    String? statusFilter,
    String? sourceFilter,
    String? customerId,
  }) async {
    final List<CustomerTask> results = [];

    // 1. Add offline pending tasks
    final offlineTasks = await OfflineTaskSyncService.getPendingTasks();
    for (final t in offlineTasks) {
      if (statusFilter != null && statusFilter != 'ALL' && t.status != statusFilter) continue;
      if (sourceFilter != null && sourceFilter != 'ALL' && t.source != sourceFilter) continue;
      if (customerId != null && t.customerId != customerId) continue;
      results.add(t);
    }

    // 2. Fetch remote tasks
    try {
      var query = _client.from('customer_tasks').select();
      if (statusFilter != null && statusFilter != 'ALL') {
        query = query.eq('status', statusFilter);
      }
      if (sourceFilter != null && sourceFilter != 'ALL') {
        query = query.eq('source', sourceFilter);
      }
      if (customerId != null) {
        query = query.eq('customer_id', customerId);
      }
      final list = await query.order('created_at', ascending: false).limit(50);
      for (final item in list) {
        results.add(CustomerTask.fromMap(item));
      }
    } catch (e) {
      debugPrint('Error fetching customer_tasks: $e');
    }

    return results;
  }

  /// Update task workflow status: New -> Review -> Data Update -> Verification -> Complete
  static Future<CustomerTask> updateTaskStatus({
    required CustomerTask task,
    required String newStatus,
    String? holdReason,
    String? resolutionRemarks,
    String? remarks,
  }) async {
    final user = SupabaseService.currentUser;
    final now = DateTime.now();

    final updated = task.copyWith(
      status: newStatus,
      holdReason: holdReason ?? task.holdReason,
      resolutionRemarks: resolutionRemarks ?? task.resolutionRemarks,
      remarks: remarks ?? task.remarks,
      updatedAt: now,
      completedAt: newStatus == TaskStatus.complete ? now : null,
      completedBy: newStatus == TaskStatus.complete ? user?.id : null,
    );

    try {
      await _client.from('customer_tasks').update({
        'status': newStatus,
        'hold_reason': updated.holdReason,
        'resolution_remarks': updated.resolutionRemarks,
        'remarks': updated.remarks,
        'updated_at': now.toUtc().toIso8601String(),
        'completed_at': updated.completedAt?.toUtc().toIso8601String(),
        'completed_by': updated.completedBy,
      }).eq('id', task.id);

      await ActivityLogService.logActivity(
        recordId: task.customerId,
        consumerNo: task.consumerNo,
        customerName: task.customerName,
        module: 'Task',
        action: 'Task Status → $newStatus',
        oldValue: task.status,
        newValue: newStatus,
        remarks: resolutionRemarks ?? holdReason ?? remarks,
        source: task.source,
      );
    } catch (e) {
      debugPrint('Error updating task status remotely: $e');
      if (task.isPendingSync) {
        await OfflineTaskSyncService.enqueueTask(updated);
      }
    }

    return updated;
  }

  /// Update Customer Account Data from document review
  static Future<void> updateCustomerData({
    required String customerId,
    required String consumerNo,
    required String customerName,
    required Map<String, dynamic> changedFields,
    required String reason,
  }) async {
    try {
      changedFields['updated_at'] = DateTime.now().toUtc().toIso8601String();
      await _client
          .from('consumer_records')
          .update(changedFields)
          .eq('id', customerId);

      await ActivityLogService.logActivity(
        recordId: customerId,
        consumerNo: consumerNo,
        customerName: customerName,
        module: 'Customer',
        action: 'Customer Updated from Document Review',
        newValue: changedFields.keys.join(', '),
        remarks: reason,
        source: 'WhatsApp Share',
      );
    } catch (e) {
      debugPrint('Error updating customer data: $e');
      rethrow;
    }
  }

  /// Create a payment transaction from detected payment proof
  static Future<void> createPaymentFromDocument({
    required String customerId,
    required String consumerNo,
    required double amount,
    required String paymentDate,
    required String paymentMode,
    String? referenceNumber,
    String? remarks,
    String? attachmentUrl,
  }) async {
    try {
      final user = SupabaseService.currentUser;
      await _client.from('customer_payment_transactions').insert({
        'customer_id': customerId,
        'consumer_no': consumerNo,
        'amount': amount,
        'payment_date': paymentDate,
        'payment_mode': paymentMode,
        'reference_number': referenceNumber,
        'remarks': remarks ?? 'Created from WhatsApp Payment Proof',
        'attachment_url': attachmentUrl,
        'status': 'Valid',
        'received_by': user?.email?.split('@').first ?? 'Staff',
      });

      await ActivityLogService.logActivity(
        recordId: customerId,
        consumerNo: consumerNo,
        customerName: 'Customer',
        module: 'Payment',
        action: 'Payment Created from WhatsApp Document',
        newValue: '₹$amount ($paymentMode - Ref: $referenceNumber)',
        source: 'WhatsApp Share',
      );
    } catch (e) {
      debugPrint('Error creating payment from document: $e');
      rethrow;
    }
  }
}
