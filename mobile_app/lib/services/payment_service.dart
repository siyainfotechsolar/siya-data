import 'dart:io';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/customer_payment.dart';
import '../models/consumer_record.dart';
import '../models/shared_document.dart';
import 'supabase_service.dart';
import 'app_database.dart';
import 'connectivity_service.dart';
import 'sync_engine.dart';
import 'activity_log_service.dart';
import 'pdf_processing_service.dart';

class MilestoneEvaluationResult {
  final bool isMilestoneSatisfied;
  final String stageName;
  final double requiredPercentage;
  final double currentPaidPercentage;
  final double targetAmount;
  final double shortfallAmount;
  final String actionRecommendation;
  final Color badgeColor;

  const MilestoneEvaluationResult({
    required this.isMilestoneSatisfied,
    required this.stageName,
    required this.requiredPercentage,
    required this.currentPaidPercentage,
    required this.targetAmount,
    required this.shortfallAmount,
    required this.actionRecommendation,
    required this.badgeColor,
  });
}

class ProofAnalysisResult {
  final double? extractedAmount;
  final DateTime? extractedDate;
  final String? extractedRefNo;
  final String? detectedMode;
  final bool hasMismatch;
  final String? mismatchReason;

  const ProofAnalysisResult({
    this.extractedAmount,
    this.extractedDate,
    this.extractedRefNo,
    this.detectedMode,
    required this.hasMismatch,
    this.mismatchReason,
  });
}

class PaymentService {
  static SupabaseClient get _client => SupabaseService.client;

  /// Fetch dashboard metrics (offline-first: fast local SQLite read, then background remote sync if online)
  static Future<PaymentDashboardSummary> fetchDashboardSummary() async {
    // 1. Instant local read
    final localSummary = await AppDatabase.getPaymentDashboardSummary();

    // 2. If online, fetch confirmed server aggregates in background to ensure sync
    if (ConnectivityService.isOnline) {
      _syncRemotePaymentData().catchError((e) {
        debugPrint('Payment remote sync background error: $e');
      });
    }

    return localSummary;
  }

  /// Sync remote payments into local cache
  static Future<void> _syncRemotePaymentData() async {
    try {
      final res = await _client
          .from('customer_payment_transactions')
          .select()
          .order('payment_date', ascending: false)
          .limit(200);

      final remoteList = (res as List)
          .map((m) => PaymentTransaction.fromJson(m as Map<String, dynamic>))
          .toList();

      if (remoteList.isNotEmpty) {
        await AppDatabase.batchUpsertPayments(remoteList, syncStatus: 'Synced');
      }
    } catch (_) {}
  }

  /// Recalculate customer's financial balance strictly adhering to simple accounting:
  /// - 1st Payment Pending = 1st Payment Amount - 1st Payment Received
  /// - 2nd Payment Pending = 2nd Payment Amount - 2nd Payment Received
  /// - Additional Payment = Sum of Additional Payments
  /// - Total Received = 1st Received + 2nd Received + Additional Received
  /// - Total Pending = Total Payment - 1st Received - 2nd Received
  /// - Additional Payment must NOT reduce 1st/2nd Payment pending amount!
  static Future<ConsumerRecord?> recalculateCustomerBalances(String customerId) async {
    final customer = await AppDatabase.getConsumerRecordById(customerId);
    if (customer == null) return null;

    final txs = await AppDatabase.getCustomerPayments(customerId);
    final validTxs = txs.where((t) => t.isValid && !t.isRejected && !t.isVoid).toList();

    double firstReceived = 0.0;
    double secondReceived = 0.0;
    double additionalReceived = 0.0;
    double generalReceived = 0.0;

    for (final t in validTxs) {
      if (t.isAdditional) {
        additionalReceived += t.amount;
      } else if (t.isFirstPayment) {
        firstReceived += t.amount;
      } else if (t.isSecondPayment) {
        secondReceived += t.amount;
      } else {
        generalReceived += t.amount;
      }
    }

    final isLoan = customer.isLoanCustomer;
    final total = customer.totalAmount;
    final double paid;
    final double pending;

    if (isLoan) {
      // Loan Customer:
      paid = firstReceived + secondReceived + generalReceived;
      pending = (total - firstReceived - secondReceived - generalReceived).clamp(0.0, double.infinity);
    } else {
      // Normal Customer:
      // Paid = Sum of payments
      // Pending = Total Payment - Paid
      paid = firstReceived + secondReceived + generalReceived;
      pending = (total - paid).clamp(0.0, double.infinity);
    }

    String status = customer.paymentStatus;
    if (total > 0 && paid >= total) {
      status = PaymentStatus.paid;
    } else if (paid > 0) {
      status = PaymentStatus.partiallyPaid;
    } else {
      status = PaymentStatus.pending;
    }

    final updated = customer.copyWith(
      paidAmount: paid,
      pendingAmount: pending,
      firstPaymentReceived: firstReceived,
      secondPaymentReceived: secondReceived,
      additionalPaidAmount: additionalReceived,
      paymentStatus: status,
      updatedAt: DateTime.now(),
    );

    await AppDatabase.upsertConsumerRecord(updated, syncStatus: 'Pending Sync');
    return updated;
  }

  /// Record a payment transaction (100% Offline-First)
  static Future<PaymentTransaction> recordPayment({
    required String customerId,
    required String consumerNo,
    required double amount,
    required DateTime paymentDate,
    required String paymentMode,
    String paymentType = PaymentType.firstPayment,
    String? additionalCategory,
    String? referenceNumber,
    String? receivedBy,
    String? remarks,
    String? localAttachmentPath,
    double? extractedAmount,
    DateTime? extractedDate,
    String? extractedRefNo,
    bool proofMismatch = false,
    bool overrideAmountLimit = false,
  }) async {
    final user = SupabaseService.currentUser;
    final userName = user?.userMetadata?['name'] as String? ?? user?.email?.split('@')[0] ?? 'Staff';
    final now = DateTime.now();
    final clientTxId = 'ptx_${now.microsecondsSinceEpoch}';
    final idempotencyKey = 'idem_${customerId}_${paymentDate.toIso8601String().split('T')[0]}_${amount.toStringAsFixed(2)}_${paymentMode.trim()}_$clientTxId';

    final isAdditional = PaymentType.isAdditionalType(paymentType);

    final tx = PaymentTransaction(
      id: clientTxId,
      clientTxId: clientTxId,
      idempotencyKey: idempotencyKey,
      customerId: customerId,
      consumerNo: consumerNo,
      amount: amount,
      paymentDate: paymentDate,
      paymentType: paymentType,
      additionalCategory: isAdditional ? (additionalCategory ?? AdditionalPaymentCategory.other) : null,
      paymentMode: paymentMode,
      referenceNumber: referenceNumber?.trim(),
      receivedBy: receivedBy ?? userName,
      remarks: remarks?.trim(),
      localAttachmentPath: localAttachmentPath,
      status: TransactionStatus.valid,
      syncStatus: ConnectivityService.isOnline ? 'Synced' : 'Pending Sync',
      verificationStatus: PaymentVerificationStatus.pending,
      extractedAmount: extractedAmount,
      extractedDate: extractedDate,
      extractedRefNo: extractedRefNo,
      proofMismatch: proofMismatch,
      createdBy: user?.id,
      createdByName: userName,
      createdAt: now,
    );

    // 1. Save payment locally in SQLite
    await AppDatabase.upsertPayment(tx, syncStatus: tx.syncStatus);

    // 2. Recalculate customer's balance using standard accounting rules
    final customer = await recalculateCustomerBalances(customerId);

    // 3. Enqueue offline operation for deterministic sync
    await AppDatabase.enqueueOperation(
      OfflineOperation(
        operationId: clientTxId,
        entityType: 'payment',
        entityId: clientTxId,
        action: 'ADD_PAYMENT',
        payload: tx.toJson(),
        userId: user?.id,
        createdAt: now,
      ),
    );

    // 4. Log financial audit trail
    await AppDatabase.logOfflineActivity(
      recordId: customerId,
      consumerNo: consumerNo,
      customerName: customer?.name ?? consumerNo,
      staffName: userName,
      action: 'PAYMENT_RECORDED',
      remarks:
          '₹${amount.toStringAsFixed(0)} via $paymentMode [${PaymentType.displayName(paymentType)}] (${tx.syncStatus})',
    );

    // 5. Trigger sync if online
    if (ConnectivityService.isOnline) {
      SyncEngine.syncNow().catchError((_) => const SyncResult(success: false));
    }

    return tx;
  }

  /// Update an existing payment transaction (Edit Payment)
  static Future<PaymentTransaction> updatePaymentTransaction({
    required PaymentTransaction updatedTx,
  }) async {
    final now = DateTime.now();
    final isOnline = ConnectivityService.isOnline;

    final tx = updatedTx.copyWith(
      updatedAt: now,
      syncStatus: isOnline ? 'Synced' : 'Pending Sync',
    );

    // 1. Update in local SQLite
    await AppDatabase.upsertPayment(tx, syncStatus: tx.syncStatus);

    // 2. Recalculate customer balances immediately
    await recalculateCustomerBalances(tx.customerId);

    // 3. Queue offline sync
    final user = SupabaseService.currentUser;
    await AppDatabase.enqueueOperation(
      OfflineOperation(
        operationId: 'upd_${tx.clientTxId ?? tx.id ?? now.microsecondsSinceEpoch}',
        entityType: 'payment',
        entityId: tx.clientTxId ?? tx.id ?? '',
        action: 'ADD_PAYMENT',
        payload: tx.toJson(),
        userId: user?.id,
        createdAt: now,
      ),
    );

    // 4. If online, sync directly
    if (isOnline) {
      try {
        if (tx.id != null) {
          await _client
              .from('customer_payment_transactions')
              .update(tx.toJson())
              .eq('id', tx.id!);
        }
      } catch (_) {}
      SyncEngine.syncNow().catchError((_) => const SyncResult(success: false));
    }

    return tx;
  }

  /// Analyze attached payment proof (PDF or image) to extract transaction information
  static Future<ProofAnalysisResult> analyzeProof({
    required File file,
    required double enteredAmount,
    required String enteredRefNo,
    required DateTime enteredDate,
  }) async {
    try {
      final len = await file.length();
      final sharedDoc = SharedDocument(
        filePath: file.path,
        fileName: file.path.split(Platform.pathSeparator).last,
        mimeType: file.path.endsWith('.pdf') ? 'application/pdf' : 'image/jpeg',
        fileSize: len,
        fileHash: '${len}_${file.lastModifiedSync().millisecondsSinceEpoch}',
        receivedAt: DateTime.now(),
      );

      final extracted = await PdfProcessingService.processDocument(sharedDoc);

      double? extractedAmt = extracted.billAmount;
      DateTime? extractedDt;
      if (extracted.billDate != null) {
        extractedDt = DateTime.tryParse(extracted.billDate!);
      }
      String? extractedRef = extracted.documentNumber;

      bool mismatch = false;
      final reasons = <String>[];

      // Check amount mismatch
      if (extractedAmt != null && (extractedAmt - enteredAmount).abs() > 1.0) {
        mismatch = true;
        reasons.add('Amount: Extracted ₹${extractedAmt.toStringAsFixed(0)} vs Entered ₹${enteredAmount.toStringAsFixed(0)}');
      }

      // Check reference number mismatch
      if (extractedRef != null &&
          enteredRefNo.trim().isNotEmpty &&
          !enteredRefNo.toLowerCase().contains(extractedRef.toLowerCase()) &&
          !extractedRef.toLowerCase().contains(enteredRefNo.toLowerCase())) {
        mismatch = true;
        reasons.add('Ref No: Extracted "$extractedRef" vs Entered "$enteredRefNo"');
      }

      return ProofAnalysisResult(
        extractedAmount: extractedAmt,
        extractedDate: extractedDt,
        extractedRefNo: extractedRef,
        hasMismatch: mismatch,
        mismatchReason: reasons.isEmpty ? null : reasons.join(' | '),
      );
    } catch (e) {
      debugPrint('Proof analysis error: $e');
      return const ProofAnalysisResult(hasMismatch: false);
    }
  }

  /// Check installation stage payment milestone
  static MilestoneEvaluationResult evaluateMilestone(ConsumerRecord record) {
    final stage = record.installationStatus;
    final total = record.totalAmount;
    final paid = record.paidAmount;
    final currentPercentage = total > 0 ? (paid / total) : 0.0;

    final rule = InstallationPaymentStageRule.getRuleForStage(stage);
    if (rule == null || total <= 0) {
      // No strict rule found for this stage
      return MilestoneEvaluationResult(
        isMilestoneSatisfied: true,
        stageName: stage,
        requiredPercentage: 0.0,
        currentPaidPercentage: currentPercentage,
        targetAmount: 0.0,
        shortfallAmount: 0.0,
        actionRecommendation: 'PAYMENT CLEAR',
        badgeColor: const Color(0xFF059669),
      );
    }

    final targetAmount = total * rule.requiredPercentage;
    final shortfall = targetAmount - paid;

    if (shortfall <= 0) {
      return MilestoneEvaluationResult(
        isMilestoneSatisfied: true,
        stageName: rule.stageName,
        requiredPercentage: rule.requiredPercentage,
        currentPaidPercentage: currentPercentage,
        targetAmount: targetAmount,
        shortfallAmount: 0.0,
        actionRecommendation: 'PAYMENT CLEAR FOR ${rule.nextStageName.toUpperCase()}',
        badgeColor: const Color(0xFF059669),
      );
    } else {
      return MilestoneEvaluationResult(
        isMilestoneSatisfied: false,
        stageName: rule.stageName,
        requiredPercentage: rule.requiredPercentage,
        currentPaidPercentage: currentPercentage,
        targetAmount: targetAmount,
        shortfallAmount: shortfall,
        actionRecommendation: 'FOLLOW-UP REQUIRED: ₹${shortfall.toStringAsFixed(0)} needed before ${rule.nextStageName}',
        badgeColor: const Color(0xFFDC2626),
      );
    }
  }

  /// Verify a payment transaction (Admin / Staff Verification)
  static Future<void> verifyPayment({
    required String paymentId,
    required String verificationStatus,
    String? remarks,
  }) async {
    final user = SupabaseService.currentUser;
    final staffName = user?.userMetadata?['name'] as String? ?? user?.email?.split('@')[0] ?? 'Staff';

    // 1. Update SQLite locally
    await AppDatabase.updatePaymentVerification(
      paymentId,
      verificationStatus,
      remarks: remarks,
      staffName: staffName,
    );

    // 2. Queue sync operation
    await AppDatabase.enqueueOperation(
      OfflineOperation(
        operationId: 'ver_${DateTime.now().microsecondsSinceEpoch}',
        entityType: 'payment_verification',
        entityId: paymentId,
        action: 'VERIFY_PAYMENT',
        payload: {
          'payment_id': paymentId,
          'verification_status': verificationStatus,
          'verification_remarks': remarks,
          'verified_by': user?.id,
          'verified_by_name': staffName,
          'verified_at': DateTime.now().toUtc().toIso8601String(),
        },
        userId: user?.id,
        createdAt: DateTime.now(),
      ),
    );

    // 3. Log audit
    await ActivityLogService.logActivity(
      consumerNo: paymentId,
      customerName: 'Payment Verification',
      module: 'Payment',
      action: 'PAYMENT_VERIFIED',
      remarks: 'Payment $paymentId marked $verificationStatus ($remarks)',
    );

    // 4. Background push
    if (ConnectivityService.isOnline) {
      SyncEngine.syncNow().catchError((_) => const SyncResult(success: false));
    }
  }

  /// Schedule a payment follow-up
  static Future<void> schedulePaymentFollowup({
    required String customerId,
    required DateTime followupDate,
    required String remarks,
  }) async {
    final customer = await AppDatabase.getConsumerRecordById(customerId);
    final consumerNo = customer?.consumerNo ?? '';

    // Update customer record with active follow-up
    if (customer != null) {
      final updated = customer.copyWith(
        hasActiveFollowup: true,
        followupDate: followupDate,
        followupReason: 'Payment Collection Follow-up',
        followupRemarks: remarks,
        updatedAt: DateTime.now(),
      );
      await AppDatabase.upsertConsumerRecord(updated, syncStatus: 'Pending Sync');
    }

    final user = SupabaseService.currentUser;
    final staffName = user?.email?.split('@')[0] ?? 'Staff';

    await AppDatabase.enqueueOperation(
      OfflineOperation(
        operationId: 'pfu_${DateTime.now().microsecondsSinceEpoch}',
        entityType: 'customer_followup',
        entityId: customerId,
        action: 'MARK_FOLLOWUP',
        payload: {
          'record_id': customerId,
          'consumer_no': consumerNo,
          'followup_date': followupDate.toIso8601String().split('T')[0],
          'followup_reason': 'Payment Collection Follow-up',
          'remarks': remarks,
          'related_type': 'Payment',
          'created_by': user?.id,
          'created_by_name': staffName,
        },
        userId: user?.id,
        createdAt: DateTime.now(),
      ),
    );

    await AppDatabase.logOfflineActivity(
      recordId: customerId,
      consumerNo: consumerNo,
      customerName: customer?.name ?? consumerNo,
      staffName: staffName,
      action: 'PAYMENT_FOLLOWUP_SCHEDULED',
      remarks: 'Payment follow-up on ${followupDate.toIso8601String().split('T')[0]}: $remarks',
    );

    if (ConnectivityService.isOnline) {
      SyncEngine.syncNow().catchError((_) => const SyncResult(success: false));
    }
  }

  /// Update customer's Payment Settings (Total Payment, 1st Payment Amount, 2nd Payment Amount)
  static Future<ConsumerRecord?> updatePaymentSettings({
    required String customerId,
    required double newTotalAmount,
    double? firstPaymentAmount,
    double? secondPaymentAmount,
  }) async {
    final customer = await AppDatabase.getConsumerRecordById(customerId);
    if (customer == null) return null;

    final updated = customer.copyWith(
      totalAmount: newTotalAmount,
      firstPaymentAmount: firstPaymentAmount ?? customer.firstPaymentAmount,
      secondPaymentAmount: secondPaymentAmount ?? customer.secondPaymentAmount,
      updatedAt: DateTime.now(),
    );

    // Save locally
    await AppDatabase.upsertConsumerRecord(updated, syncStatus: 'Pending Sync');

    // Recalculate balances
    final recalculated = await recalculateCustomerBalances(customerId);

    // Queue offline sync
    final user = SupabaseService.currentUser;
    await AppDatabase.enqueueOperation(
      OfflineOperation(
        operationId: 'settings_${DateTime.now().microsecondsSinceEpoch}',
        entityType: 'consumer_record',
        entityId: customerId,
        action: 'UPDATE_RECORD',
        payload: {
          'id': customerId,
          'total_amount': newTotalAmount,
          'contract_amount': newTotalAmount,
          'first_payment_amount': recalculated?.firstPaymentAmount ?? newTotalAmount,
          'second_payment_amount': recalculated?.secondPaymentAmount ?? 0.0,
          'pending_amount': recalculated?.pendingAmount ?? 0.0,
          'paid_amount': recalculated?.paidAmount ?? 0.0,
          'payment_status': recalculated?.paymentStatus ?? 'Pending',
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        },
        userId: user?.id,
        createdAt: DateTime.now(),
      ),
    );

    // Sync if online
    if (ConnectivityService.isOnline) {
      SyncEngine.syncNow().catchError((_) => const SyncResult(success: false));
    }

    return recalculated ?? updated;
  }

  /// Update customer's Total Payment (contract amount) - backward compatibility
  static Future<ConsumerRecord?> updateTotalPayment({
    required String customerId,
    required double newTotalAmount,
  }) async {
    return updatePaymentSettings(
      customerId: customerId,
      newTotalAmount: newTotalAmount,
    );
  }
}
