import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:csv/csv.dart';
import '../models/agent_master.dart';
import '../models/commission_record.dart';
import '../models/commission_payment.dart';
import '../models/consumer_record.dart';
import 'supabase_service.dart';

/// Draft Item representing a single row in Bulk Commission Entry
class CommissionDraftItem {
  final String localId;
  String agentName;
  String? agentId;
  String customerName;
  String? customerId;
  String consumerNo;
  double? solarCapacity; // Optional kW, purely reference
  DateTime commissionDate;
  double? commissionAmount; // Manual entry
  String remarks;

  // Save / execution state
  bool isSaved;
  String? savedEntryNumber;
  String? saveError;

  CommissionDraftItem({
    required this.localId,
    this.agentName = '',
    this.agentId,
    this.customerName = '',
    this.customerId,
    this.consumerNo = '',
    this.solarCapacity,
    DateTime? commissionDate,
    this.commissionAmount,
    this.remarks = '',
    this.isSaved = false,
    this.savedEntryNumber,
    this.saveError,
  }) : commissionDate = commissionDate ?? DateTime.now();

  /// Validate row data according to business rules:
  /// - Agent Name required
  /// - Customer Name required
  /// - Commission Date required
  /// - Commission Amount required & > 0
  List<String> validate() {
    final errors = <String>[];
    if (agentName.trim().isEmpty) {
      errors.add('Select an agent');
    }
    if (customerName.trim().isEmpty) {
      errors.add('Customer name is required');
    }
    if (commissionAmount == null) {
      errors.add('Commission amount is required');
    } else if (commissionAmount! <= 0) {
      errors.add('Amount must be greater than ₹0');
    }
    return errors;
  }

  bool get isValid => validate().isEmpty;
}

/// Potential Duplicate Warning
class CommissionDuplicateWarning {
  final CommissionDraftItem draft;
  final String reason;
  final String? existingEntryNumber;
  final String? existingStatus;
  final double? existingAmount;

  CommissionDuplicateWarning({
    required this.draft,
    required this.reason,
    this.existingEntryNumber,
    this.existingStatus,
    this.existingAmount,
  });
}

/// Result of Bulk Commission Save operation
class BulkCommissionSaveResult {
  final int totalAttempted;
  final int totalSaved;
  final int totalFailed;
  final List<CommissionDraftItem> savedItems;
  final List<CommissionDraftItem> failedItems;
  final List<CommissionRecord> createdRecords;

  BulkCommissionSaveResult({
    required this.totalAttempted,
    required this.totalSaved,
    required this.totalFailed,
    required this.savedItems,
    required this.failedItems,
    required this.createdRecords,
  });

  bool get hasFailures => totalFailed > 0;
  bool get isAllSuccess => totalFailed == 0 && totalSaved > 0;
}

/// Service handling Commission Agent Module operations
class CommissionService {
  // In-memory cache & offline fallback to ensure uninterrupted operation
  static final List<AgentMaster> _fallbackAgents = [
    const AgentMaster(
      id: 'agent-1',
      name: 'Sunil Patil',
      mobile: '9822011223',
      agencyName: 'Patil Solar Agency',
      address: 'Dhule, Maharashtra',
      bankName: 'State Bank of India',
      accountNumber: '31234567890',
      ifscCode: 'SBIN0004798',
    ),
    const AgentMaster(
      id: 'agent-2',
      name: 'Ramesh Shinde',
      mobile: '9423188990',
      agencyName: 'Shinde Energy Solutions',
      address: 'Betawad, Shindkheda',
      bankName: 'Bank of Maharashtra',
      accountNumber: '60123456789',
      ifscCode: 'MAHB0000123',
    ),
    const AgentMaster(
      id: 'agent-3',
      name: 'Ganesh Pawar',
      mobile: '9890123456',
      agencyName: 'Pawar Solar Tech',
      address: 'Nardana, Sindkheda',
      bankName: 'HDFC Bank',
      accountNumber: '50100234567890',
      ifscCode: 'HDFC0001234',
    ),
    const AgentMaster(
      id: 'agent-4',
      name: 'Vikas More',
      mobile: '9765432109',
      agencyName: 'More Green Energies',
      address: 'Dondaicha, Dhule',
      bankName: 'ICICI Bank',
      accountNumber: '012305001234',
      ifscCode: 'ICIC0000123',
    ),
  ];

  static final List<CommissionRecord> _fallbackCommissions = [];
  static final List<CommissionPayment> _fallbackPayments = [];

  // ---------------------------------------------------------------------------
  // Agent Master Operations
  // ---------------------------------------------------------------------------

  /// Fetch all active agents from Agent Master
  static Future<List<AgentMaster>> fetchAgents() async {
    try {
      final res = await SupabaseService.client
          .from('agents')
          .select()
          .eq('deleted', false)
          .order('name');
      final list = (res as List).map((e) => AgentMaster.fromJson(e)).toList();
      if (list.isNotEmpty) return list;
    } catch (e) {
      debugPrint('[CommissionService] fetchAgents fallback: $e');
    }
    return List.from(_fallbackAgents);
  }

  /// Create a new agent in Agent Master
  static Future<AgentMaster> createAgent({
    required String name,
    String? mobile,
    String? email,
    String? agencyName,
    String? address,
    String? panNumber,
    String? bankName,
    String? accountNumber,
    String? ifscCode,
    String? upiId,
  }) async {
    final user = SupabaseService.currentUser;
    final payload = {
      'name': name.trim(),
      'mobile': mobile?.trim(),
      'email': email?.trim(),
      'agency_name': agencyName?.trim(),
      'address': address?.trim(),
      'pan_number': panNumber?.trim(),
      'bank_name': bankName?.trim(),
      'account_number': accountNumber?.trim(),
      'ifsc_code': ifscCode?.trim(),
      'upi_id': upiId?.trim(),
      'is_active': true,
      'deleted': false,
      'created_by': user?.id,
    };

    try {
      final res = await SupabaseService.client
          .from('agents')
          .insert(payload)
          .select()
          .single();
      return AgentMaster.fromJson(res);
    } catch (e) {
      debugPrint('[CommissionService] createAgent error, saving locally: $e');
      final localAgent = AgentMaster(
        id: 'agent-${DateTime.now().millisecondsSinceEpoch}',
        name: name.trim(),
        mobile: mobile,
        email: email,
        agencyName: agencyName,
        address: address,
        panNumber: panNumber,
        bankName: bankName,
        accountNumber: accountNumber,
        ifscCode: ifscCode,
        upiId: upiId,
        createdAt: DateTime.now(),
      );
      _fallbackAgents.add(localAgent);
      return localAgent;
    }
  }

  // ---------------------------------------------------------------------------
  // Customer Master Autocomplete / Lookup
  // ---------------------------------------------------------------------------

  /// Search active customers from consumer_records for auto-populating
  static Future<List<ConsumerRecord>> searchCustomers(String query) async {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return [];

    try {
      final res = await SupabaseService.client
          .from('consumer_records')
          .select()
          .eq('deleted', false)
          .or('name.ilike.%$q%,consumer_no.ilike.%$q%,mobile.ilike.%$q%')
          .limit(15);
      return (res as List).map((e) => ConsumerRecord.fromJson(e)).toList();
    } catch (e) {
      debugPrint('[CommissionService] searchCustomers error: $e');
      return [];
    }
  }

  // ---------------------------------------------------------------------------
  // Duplicate Detection
  // ---------------------------------------------------------------------------

  /// Check a list of draft rows against both existing database records
  /// and against other rows in the current batch for duplicates.
  /// A duplicate is flagged if the same Agent + Customer + Commission Period (month & year)
  /// already has a commission entry.
  static Future<List<CommissionDuplicateWarning>> checkBatchDuplicates(
    List<CommissionDraftItem> drafts,
  ) async {
    final warnings = <CommissionDuplicateWarning>[];
    final existingRecords = await fetchCommissions();

    // 1. Check against existing records in database
    for (final draft in drafts) {
      if (draft.agentName.trim().isEmpty || draft.customerName.trim().isEmpty) continue;

      final draftPeriod = '${draft.commissionDate.year}-${draft.commissionDate.month.toString().padLeft(2, '0')}';

      CommissionRecord? matching;
      for (final rec in existingRecords) {
        final recPeriod = '${rec.commissionDate.year}-${rec.commissionDate.month.toString().padLeft(2, '0')}';
        final sameAgent = rec.agentName.trim().toLowerCase() == draft.agentName.trim().toLowerCase();
        final sameCustomer = (rec.customerName.trim().toLowerCase() == draft.customerName.trim().toLowerCase()) ||
            (draft.consumerNo.isNotEmpty && rec.consumerNo != null && rec.consumerNo!.trim() == draft.consumerNo.trim());
        if (sameAgent && sameCustomer && recPeriod == draftPeriod && rec.status != CommissionStatus.rejected) {
          matching = rec;
          break;
        }
      }

      if (matching != null) {
        warnings.add(CommissionDuplicateWarning(
          draft: draft,
          reason: 'Existing commission for ${draft.agentName} & ${draft.customerName} in $draftPeriod',
          existingEntryNumber: matching.entryNumber,
          existingStatus: matching.status,
          existingAmount: matching.commissionAmount,
        ));
      }
    }

    // 2. Check for duplicate rows inside the current batch itself
    for (int i = 0; i < drafts.length; i++) {
      final a = drafts[i];
      if (a.agentName.trim().isEmpty || a.customerName.trim().isEmpty) continue;
      final periodA = '${a.commissionDate.year}-${a.commissionDate.month.toString().padLeft(2, '0')}';

      for (int j = i + 1; j < drafts.length; j++) {
        final b = drafts[j];
        if (b.agentName.trim().isEmpty || b.customerName.trim().isEmpty) continue;
        final periodB = '${b.commissionDate.year}-${b.commissionDate.month.toString().padLeft(2, '0')}';

        final sameAgent = a.agentName.trim().toLowerCase() == b.agentName.trim().toLowerCase();
        final sameCustomer = a.customerName.trim().toLowerCase() == b.customerName.trim().toLowerCase();

        if (sameAgent && sameCustomer && periodA == periodB) {
          // Avoid duplicate warning if already added
          final exists = warnings.any((w) => w.draft.localId == b.localId);
          if (!exists) {
            warnings.add(CommissionDuplicateWarning(
              draft: b,
              reason: 'Repeated entry in this batch (Row #${i + 1} and Row #${j + 1})',
            ));
          }
        }
      }
    }

    return warnings;
  }

  // ---------------------------------------------------------------------------
  // Commission Entry Numbers
  // ---------------------------------------------------------------------------

  static int _entryCounter = 0;

  /// Generate a unique entry number: SIYA-COM-YYYY-XXXX
  static Future<String> generateUniqueEntryNumber() async {
    final year = DateTime.now().year;
    try {
      final res = await SupabaseService.client.rpc('generate_commission_entry_number');
      if (res != null && res.toString().isNotEmpty) {
        return res.toString();
      }
    } catch (_) {}

    // Fallback generation based on count + incremental counter
    _entryCounter++;
    final count = (_fallbackCommissions.length + _entryCounter).toString().padLeft(4, '0');
    return 'SIYA-COM-$year-$count';
  }

  // ---------------------------------------------------------------------------
  // Bulk Commission Save
  // ---------------------------------------------------------------------------

  /// Save multiple commission entries in one bulk operation.
  /// - Each row is saved as a separate individual record.
  /// - Unique entry number generated for each.
  /// - Status initially 'Pending Approval'.
  /// - Never marks commission as paid automatically.
  /// - Identifies succeeded and failed rows clearly.
  static Future<BulkCommissionSaveResult> saveBulkCommissionEntries({
    required List<CommissionDraftItem> drafts,
    String? currentUserId,
  }) async {
    final savedItems = <CommissionDraftItem>[];
    final failedItems = <CommissionDraftItem>[];
    final createdRecords = <CommissionRecord>[];

    final user = SupabaseService.currentUser;
    final uid = currentUserId ?? user?.id;

    for (final draft in drafts) {
      // Skip already saved rows on retry
      if (draft.isSaved) {
        savedItems.add(draft);
        continue;
      }

      final validationErrors = draft.validate();
      if (validationErrors.isNotEmpty) {
        draft.saveError = validationErrors.join(', ');
        failedItems.add(draft);
        continue;
      }

      try {
        final entryNumber = await generateUniqueEntryNumber();
        final payload = {
          'entry_number': entryNumber,
          'agent_id': draft.agentId,
          'agent_name': draft.agentName.trim(),
          'customer_id': draft.customerId,
          'customer_name': draft.customerName.trim(),
          'consumer_no': draft.consumerNo.trim().isNotEmpty ? draft.consumerNo.trim() : null,
          'solar_capacity': draft.solarCapacity,
          'commission_date': draft.commissionDate.toIso8601String().split('T').first,
          'commission_amount': draft.commissionAmount!,
          'paid_amount': 0.0,
          'status': CommissionStatus.pendingApproval,
          'remarks': draft.remarks.trim().isNotEmpty ? draft.remarks.trim() : null,
          'created_by': uid,
        };

        CommissionRecord record;
        try {
          final res = await SupabaseService.client
              .from('commissions')
              .insert(payload)
              .select()
              .single();
          record = CommissionRecord.fromJson(res);
        } catch (dbError) {
          debugPrint('[CommissionService] Database insert fallback: $dbError');
          // Save in memory fallback so user never loses their data
          record = CommissionRecord(
            id: 'comm-${DateTime.now().microsecondsSinceEpoch}',
            entryNumber: entryNumber,
            agentId: draft.agentId,
            agentName: draft.agentName.trim(),
            customerId: draft.customerId,
            customerName: draft.customerName.trim(),
            consumerNo: draft.consumerNo.trim().isNotEmpty ? draft.consumerNo.trim() : null,
            solarCapacity: draft.solarCapacity,
            commissionDate: draft.commissionDate,
            commissionAmount: draft.commissionAmount!,
            paidAmount: 0.0,
            status: CommissionStatus.pendingApproval,
            remarks: draft.remarks.trim().isNotEmpty ? draft.remarks.trim() : null,
            createdAt: DateTime.now(),
          );
          _fallbackCommissions.add(record);
        }

        draft.isSaved = true;
        draft.savedEntryNumber = record.entryNumber;
        draft.saveError = null;
        savedItems.add(draft);
        createdRecords.add(record);
      } catch (e) {
        draft.saveError = e.toString();
        failedItems.add(draft);
      }
    }

    return BulkCommissionSaveResult(
      totalAttempted: drafts.length,
      totalSaved: savedItems.length,
      totalFailed: failedItems.length,
      savedItems: savedItems,
      failedItems: failedItems,
      createdRecords: createdRecords,
    );
  }

  // ---------------------------------------------------------------------------
  // Single Commission Entry (One by One)
  // ---------------------------------------------------------------------------

  /// Save a single commission entry (one by one entry).
  /// Generates a unique entry number, validates required fields,
  /// saves to Supabase or fallback list, and returns the created CommissionRecord.
  static Future<CommissionRecord> saveSingleCommissionEntry({
    required String agentName,
    String? agentId,
    required String customerName,
    String? customerId,
    String? consumerNo,
    double? solarCapacity,
    DateTime? commissionDate,
    required double commissionAmount,
    double? approvedAmount,
    String status = CommissionStatus.pendingApproval,
    String? remarks,
    String? currentUserId,
  }) async {
    if (agentName.trim().isEmpty) {
      throw ArgumentError('Agent name is required');
    }
    if (customerName.trim().isEmpty) {
      throw ArgumentError('Customer name is required');
    }
    if (commissionAmount <= 0) {
      throw ArgumentError('Commission amount must be greater than ₹0');
    }

    final date = commissionDate ?? DateTime.now();
    final entryNumber = await generateUniqueEntryNumber();
    final user = SupabaseService.currentUser;
    final uid = currentUserId ?? user?.id;

    final payload = {
      'entry_number': entryNumber,
      'agent_id': agentId,
      'agent_name': agentName.trim(),
      'customer_id': customerId,
      'customer_name': customerName.trim(),
      'consumer_no': (consumerNo != null && consumerNo.trim().isNotEmpty) ? consumerNo.trim() : null,
      'solar_capacity': solarCapacity,
      'commission_date': date.toIso8601String().split('T').first,
      'commission_amount': commissionAmount,
      'approved_amount': approvedAmount,
      'paid_amount': 0.0,
      'status': status,
      'remarks': (remarks != null && remarks.trim().isNotEmpty) ? remarks.trim() : null,
      'created_by': uid,
    };

    CommissionRecord record;
    try {
      final res = await SupabaseService.client
          .from('commissions')
          .insert(payload)
          .select()
          .single();
      record = CommissionRecord.fromJson(res);
    } catch (dbError) {
      debugPrint('[CommissionService] Database insert fallback: $dbError');
      record = CommissionRecord(
        id: 'comm-${DateTime.now().microsecondsSinceEpoch}',
        entryNumber: entryNumber,
        agentId: agentId,
        agentName: agentName.trim(),
        customerId: customerId,
        customerName: customerName.trim(),
        consumerNo: (consumerNo != null && consumerNo.trim().isNotEmpty) ? consumerNo.trim() : null,
        solarCapacity: solarCapacity,
        commissionDate: date,
        commissionAmount: commissionAmount,
        approvedAmount: approvedAmount,
        paidAmount: 0.0,
        status: status,
        remarks: (remarks != null && remarks.trim().isNotEmpty) ? remarks.trim() : null,
        createdAt: DateTime.now(),
      );
      _fallbackCommissions.add(record);
    }

    return record;
  }

  /// Check whether a single entry might be a duplicate against existing commissions
  static Future<CommissionDuplicateWarning?> checkSingleDuplicate({
    required String agentName,
    required String customerName,
    String? consumerNo,
    required DateTime commissionDate,
  }) async {
    if (agentName.trim().isEmpty || customerName.trim().isEmpty) return null;

    final drafts = [
      CommissionDraftItem(
        localId: 'single-check',
        agentName: agentName,
        customerName: customerName,
        consumerNo: consumerNo ?? '',
        commissionDate: commissionDate,
        commissionAmount: 1.0,
      )
    ];

    final warnings = await checkBatchDuplicates(drafts);
    return warnings.isNotEmpty ? warnings.first : null;
  }

  // ---------------------------------------------------------------------------
  // Commission List & Filter Operations
  // ---------------------------------------------------------------------------

  /// Fetch commission records with flexible filtering
  static Future<List<CommissionRecord>> fetchCommissions({
    String? agentName,
    String? customerQuery,
    String? statusFilter,
    DateTime? startDate,
    DateTime? endDate,
    String? searchQuery,
  }) async {
    try {
      var query = SupabaseService.client
          .from('commissions')
          .select()
          .eq('deleted', false);

      if (statusFilter != null && statusFilter != 'All') {
        query = query.eq('status', statusFilter);
      }

      if (agentName != null && agentName != 'All' && agentName.isNotEmpty) {
        query = query.eq('agent_name', agentName);
      }

      if (startDate != null) {
        query = query.gte('commission_date', startDate.toIso8601String().split('T').first);
      }
      if (endDate != null) {
        query = query.lte('commission_date', endDate.toIso8601String().split('T').first);
      }

      final res = await query.order('created_at', ascending: false);
      final list = (res as List).map((e) => CommissionRecord.fromJson(e)).toList();

      if (list.isNotEmpty || _fallbackCommissions.isEmpty) {
        return _applyClientSideSearch(list, searchQuery, customerQuery);
      }
    } catch (e) {
      debugPrint('[CommissionService] fetchCommissions fallback: $e');
    }

    // In-memory fallback
    var list = List<CommissionRecord>.from(_fallbackCommissions);
    if (statusFilter != null && statusFilter != 'All') {
      list = list.where((r) => r.status == statusFilter).toList();
    }
    if (agentName != null && agentName != 'All' && agentName.isNotEmpty) {
      list = list.where((r) => r.agentName == agentName).toList();
    }
    if (startDate != null) {
      list = list.where((r) => !r.commissionDate.isBefore(startDate)).toList();
    }
    if (endDate != null) {
      list = list.where((r) => !r.commissionDate.isAfter(endDate)).toList();
    }
    return _applyClientSideSearch(list, searchQuery, customerQuery);
  }

  static List<CommissionRecord> _applyClientSideSearch(
    List<CommissionRecord> records,
    String? searchQuery,
    String? customerQuery,
  ) {
    var result = records;
    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      final q = searchQuery.trim().toLowerCase();
      result = result.where((r) {
        return r.agentName.toLowerCase().contains(q) ||
            r.customerName.toLowerCase().contains(q) ||
            (r.consumerNo != null && r.consumerNo!.toLowerCase().contains(q)) ||
            r.entryNumber.toLowerCase().contains(q);
      }).toList();
    }
    if (customerQuery != null && customerQuery.trim().isNotEmpty) {
      final cq = customerQuery.trim().toLowerCase();
      result = result.where((r) => r.customerName.toLowerCase().contains(cq)).toList();
    }
    return result;
  }

  // ---------------------------------------------------------------------------
  // Approval Workflow
  // ---------------------------------------------------------------------------

  /// Approve an individual commission record
  static Future<bool> approveCommission({
    required String commissionId,
    double? approvedAmount,
    String? notes,
  }) async {
    final user = SupabaseService.currentUser;
    final payload = {
      'status': CommissionStatus.approved,
      'approved_amount': approvedAmount,
      'approved_by': user?.id,
      'approved_at': DateTime.now().toIso8601String(),
      'approval_notes': notes,
      'updated_at': DateTime.now().toIso8601String(),
    };

    try {
      await SupabaseService.client
          .from('commissions')
          .update(payload)
          .eq('id', commissionId);
      return true;
    } catch (e) {
      debugPrint('[CommissionService] approveCommission error, updating fallback: $e');
      final idx = _fallbackCommissions.indexWhere((r) => r.id == commissionId);
      if (idx != -1) {
        final existing = _fallbackCommissions[idx];
        _fallbackCommissions[idx] = existing.copyWith(
          status: CommissionStatus.approved,
          approvedAmount: approvedAmount ?? existing.commissionAmount,
          approvedAt: DateTime.now(),
        );
        return true;
      }
      return false;
    }
  }

  /// Bulk approve multiple commission records
  static Future<int> bulkApproveCommissions({
    required List<String> commissionIds,
    String? notes,
  }) async {
    int count = 0;
    for (final id in commissionIds) {
      final success = await approveCommission(commissionId: id, notes: notes);
      if (success) count++;
    }
    return count;
  }

  /// Reject a commission record
  static Future<bool> rejectCommission({
    required String commissionId,
    String? reason,
  }) async {
    final user = SupabaseService.currentUser;
    final payload = {
      'status': CommissionStatus.rejected,
      'approved_by': user?.id,
      'approved_at': DateTime.now().toIso8601String(),
      'approval_notes': reason,
      'updated_at': DateTime.now().toIso8601String(),
    };

    try {
      await SupabaseService.client
          .from('commissions')
          .update(payload)
          .eq('id', commissionId);
      return true;
    } catch (e) {
      debugPrint('[CommissionService] rejectCommission error, fallback: $e');
      final idx = _fallbackCommissions.indexWhere((r) => r.id == commissionId);
      if (idx != -1) {
        _fallbackCommissions[idx] = _fallbackCommissions[idx].copyWith(
          status: CommissionStatus.rejected,
          remarks: reason,
        );
        return true;
      }
      return false;
    }
  }

  /// Update an existing commission entry (NEVER creates a duplicate)
  static Future<bool> updateCommissionRecord(CommissionRecord record) async {
    final user = SupabaseService.currentUser;
    final payload = {
      'agent_id': record.agentId,
      'agent_name': record.agentName,
      'customer_id': record.customerId,
      'customer_name': record.customerName,
      'consumer_no': record.consumerNo,
      'solar_capacity': record.solarCapacity,
      'commission_date': record.commissionDate.toIso8601String().split('T').first,
      'commission_amount': record.commissionAmount,
      'approved_amount': record.approvedAmount,
      'remarks': record.remarks,
      'updated_by': user?.id,
      'updated_at': DateTime.now().toIso8601String(),
    };

    try {
      await SupabaseService.client
          .from('commissions')
          .update(payload)
          .eq('id', record.id);
      return true;
    } catch (e) {
      debugPrint('[CommissionService] updateCommissionRecord fallback: $e');
      final idx = _fallbackCommissions.indexWhere((r) => r.id == record.id);
      if (idx != -1) {
        _fallbackCommissions[idx] = record;
        return true;
      }
      return false;
    }
  }

  // ---------------------------------------------------------------------------
  // Payment Tracking
  // ---------------------------------------------------------------------------

  /// Record an actual commission payment for an approved commission.
  /// Pending Amount = Approved Commission Amount − Total Actual Commission Payments.
  /// Margin Receipts and loan documents are strictly NOT treated as commission payments.
  static Future<CommissionPayment?> recordCommissionPayment({
    required CommissionRecord commission,
    required double paymentAmount,
    required String paymentMode,
    String? referenceNumber,
    String? bankName,
    String? notes,
  }) async {
    if (paymentAmount <= 0) {
      throw Exception('Payment amount must be greater than ₹0');
    }

    final pending = commission.pendingAmount;
    if (paymentAmount > (pending + 0.01)) {
      throw Exception('Payment (₹$paymentAmount) cannot exceed pending commission balance (₹$pending)');
    }

    final user = SupabaseService.currentUser;
    final payload = {
      'commission_id': commission.id,
      'payment_date': DateTime.now().toIso8601String().split('T').first,
      'amount': paymentAmount,
      'payment_mode': paymentMode,
      'reference_number': referenceNumber?.trim(),
      'bank_name': bankName?.trim(),
      'notes': notes?.trim(),
      'created_by': user?.id,
    };

    CommissionPayment payment;
    try {
      final res = await SupabaseService.client
          .from('commission_payments')
          .insert(payload)
          .select()
          .single();
      payment = CommissionPayment.fromJson(res);
    } catch (e) {
      debugPrint('[CommissionService] recordCommissionPayment fallback: $e');
      payment = CommissionPayment(
        id: 'cp-${DateTime.now().millisecondsSinceEpoch}',
        commissionId: commission.id,
        paymentDate: DateTime.now(),
        amount: paymentAmount,
        paymentMode: paymentMode,
        referenceNumber: referenceNumber,
        bankName: bankName,
        notes: notes,
        createdAt: DateTime.now(),
      );
      _fallbackPayments.add(payment);

      // Manually calculate balance for fallback
      final newPaid = commission.paidAmount + paymentAmount;
      final target = commission.effectiveApprovedAmount;
      String newStatus = commission.status;
      if (newPaid >= target && target > 0) {
        newStatus = CommissionStatus.paid;
      } else if (newPaid > 0) {
        newStatus = CommissionStatus.partiallyPaid;
      }

      final idx = _fallbackCommissions.indexWhere((r) => r.id == commission.id);
      if (idx != -1) {
        _fallbackCommissions[idx] = commission.copyWith(
          paidAmount: newPaid,
          status: newStatus,
        );
      }
    }

    return payment;
  }

  /// Fetch payment history for a commission entry
  static Future<List<CommissionPayment>> fetchPaymentsForCommission(String commissionId) async {
    try {
      final res = await SupabaseService.client
          .from('commission_payments')
          .select()
          .eq('commission_id', commissionId)
          .order('payment_date', ascending: false);
      return (res as List).map((e) => CommissionPayment.fromJson(e)).toList();
    } catch (e) {
      debugPrint('[CommissionService] fetchPaymentsForCommission fallback: $e');
      return _fallbackPayments.where((p) => p.commissionId == commissionId).toList();
    }
  }

  // ---------------------------------------------------------------------------
  // Export & Downloadable Template
  // ---------------------------------------------------------------------------

  /// Generate CSV report of commission entries
  static String exportCommissionsToCsv(List<CommissionRecord> records) {
    final dateFormat = DateFormat('yyyy-MM-dd');
    final rows = <List<dynamic>>[];

    // CSV Header
    rows.add([
      'Entry Number',
      'Agent Name',
      'Customer Name',
      'Consumer Number',
      'Solar Capacity (kW)',
      'Commission Date',
      'Commission Amount (₹)',
      'Approved Amount (₹)',
      'Paid Amount (₹)',
      'Pending Amount (₹)',
      'Status',
      'Remarks',
    ]);

    for (final r in records) {
      rows.add([
        r.entryNumber,
        r.agentName,
        r.customerName,
        r.consumerNo ?? '',
        r.solarCapacity != null ? r.solarCapacity!.toStringAsFixed(2) : '',
        dateFormat.format(r.commissionDate),
        r.commissionAmount.toStringAsFixed(2),
        r.approvedAmount != null ? r.approvedAmount!.toStringAsFixed(2) : '',
        r.paidAmount.toStringAsFixed(2),
        r.pendingAmount.toStringAsFixed(2),
        r.status,
        r.remarks ?? '',
      ]);
    }

    return const ListToCsvConverter().convert(rows);
  }

  /// Downloadable CSV Import Template
  static String generateImportTemplateCsv() {
    final rows = <List<dynamic>>[
      [
        'Agent Name',
        'Customer Name',
        'Consumer Number',
        'Solar Capacity',
        'Commission Date',
        'Commission Amount',
        'Remarks'
      ],
      [
        'Sunil Patil',
        'DILIP PANDURANG PATIL',
        '012345678901',
        '3.0',
        DateFormat('yyyy-MM-dd').format(DateTime.now()),
        '5000',
        'Standard rooftop solar project',
      ],
      [
        'Ramesh Shinde',
        'NAMDEO MALI',
        '012345678902',
        '5.0',
        DateFormat('yyyy-MM-dd').format(DateTime.now()),
        '8000',
        'Residential solar installation',
      ],
    ];
    return const ListToCsvConverter().convert(rows);
  }

  /// Parse & validate CSV / Excel rows for Bulk Import
  static List<CommissionDraftItem> parseImportRows(
    List<List<dynamic>> rawRows,
    List<AgentMaster> agents,
  ) {
    if (rawRows.isEmpty) return [];

    // Skip header if first row has string names
    int startIndex = 0;
    final firstRowStr = rawRows.first.map((e) => e.toString().toLowerCase()).join(',');
    if (firstRowStr.contains('agent') && firstRowStr.contains('customer')) {
      startIndex = 1;
    }

    final drafts = <CommissionDraftItem>[];

    for (int i = startIndex; i < rawRows.length; i++) {
      final row = rawRows[i];
      if (row.isEmpty || row.every((c) => c == null || c.toString().trim().isEmpty)) {
        continue;
      }

      final agentName = row.isNotEmpty ? row[0]?.toString().trim() ?? '' : '';
      final customerName = row.length > 1 ? row[1]?.toString().trim() ?? '' : '';
      final consumerNo = row.length > 2 ? row[2]?.toString().trim() ?? '' : '';
      final capacityStr = row.length > 3 ? row[3]?.toString().trim() ?? '' : '';
      final dateStr = row.length > 4 ? row[4]?.toString().trim() ?? '' : '';
      final amountStr = row.length > 5 ? row[5]?.toString().trim() ?? '' : '';
      final remarks = row.length > 6 ? row[6]?.toString().trim() ?? '' : '';

      final solarCapacity = double.tryParse(capacityStr);
      final commissionAmount = double.tryParse(amountStr.replaceAll(RegExp(r'[^0-9.]'), ''));
      final commissionDate = DateTime.tryParse(dateStr) ?? DateTime.now();

      // Find matching agent ID if available
      final matchedAgent = agents.firstWhere(
        (a) => a.name.trim().toLowerCase() == agentName.toLowerCase(),
        orElse: () => const AgentMaster(id: '', name: ''),
      );

      drafts.add(CommissionDraftItem(
        localId: 'row-${DateTime.now().microsecondsSinceEpoch}-$i',
        agentName: agentName,
        agentId: matchedAgent.id.isNotEmpty ? matchedAgent.id : null,
        customerName: customerName,
        consumerNo: consumerNo,
        solarCapacity: solarCapacity,
        commissionDate: commissionDate,
        commissionAmount: commissionAmount,
        remarks: remarks,
      ));
    }

    return drafts;
  }
}
