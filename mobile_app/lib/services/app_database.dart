import 'dart:convert';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import '../models/consumer_record.dart';
import '../models/customer_task.dart';
import '../models/customer_payment.dart';
import '../models/lead_record.dart';
import '../models/customer_misc_action.dart';
import '../models/customer_issue.dart';
import '../models/activity_log.dart';

/// Representation of an operation queued for server synchronization
class OfflineOperation {
  final String operationId;
  final String entityType; // 'consumer_record', 'task', 'payment', 'lead', 'misc_action', 'issue', 'document'
  final String entityId;
  final String action; // 'UPDATE_NAME', 'UPDATE_WORKFLOW', 'MARK_COMPLETE', 'MARK_HOLD', 'CREATE_TASK', 'ADD_PAYMENT', etc.
  final Map<String, dynamic> payload;
  final String? userId;
  final String? deviceId;
  final DateTime createdAt;
  final String syncStatus; // 'PENDING', 'SYNCING', 'FAILED', 'CONFLICT', 'SYNCED'
  final int retryCount;
  final String? errorMessage;

  const OfflineOperation({
    required this.operationId,
    required this.entityType,
    required this.entityId,
    required this.action,
    required this.payload,
    this.userId,
    this.deviceId,
    required this.createdAt,
    this.syncStatus = 'PENDING',
    this.retryCount = 0,
    this.errorMessage,
  });

  Map<String, dynamic> toMap() {
    return {
      'operation_id': operationId,
      'entity_type': entityType,
      'entity_id': entityId,
      'action': action,
      'payload': jsonEncode(payload),
      'user_id': userId,
      'device_id': deviceId,
      'created_at': createdAt.toIso8601String(),
      'sync_status': syncStatus,
      'retry_count': retryCount,
      'error_message': errorMessage,
    };
  }

  factory OfflineOperation.fromMap(Map<String, dynamic> map) {
    Map<String, dynamic> parsedPayload = {};
    try {
      final pRaw = map['payload'];
      if (pRaw is String) {
        parsedPayload = jsonDecode(pRaw) as Map<String, dynamic>;
      } else if (pRaw is Map) {
        parsedPayload = Map<String, dynamic>.from(pRaw);
      }
    } catch (_) {}

    return OfflineOperation(
      operationId: map['operation_id']?.toString() ?? '',
      entityType: map['entity_type']?.toString() ?? '',
      entityId: map['entity_id']?.toString() ?? '',
      action: map['action']?.toString() ?? '',
      payload: parsedPayload,
      userId: map['user_id']?.toString(),
      deviceId: map['device_id']?.toString(),
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      syncStatus: map['sync_status']?.toString() ?? 'PENDING',
      retryCount: (map['retry_count'] is num) ? (map['retry_count'] as num).toInt() : 0,
      errorMessage: map['error_message']?.toString(),
    );
  }

  OfflineOperation copyWith({
    String? syncStatus,
    int? retryCount,
    String? errorMessage,
  }) {
    return OfflineOperation(
      operationId: operationId,
      entityType: entityType,
      entityId: entityId,
      action: action,
      payload: payload,
      userId: userId,
      deviceId: deviceId,
      createdAt: createdAt,
      syncStatus: syncStatus ?? this.syncStatus,
      retryCount: retryCount ?? this.retryCount,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

/// Conflict record when local and remote data diverge
class SyncConflict {
  final String conflictId;
  final String operationId;
  final String entityType;
  final String entityId;
  final Map<String, dynamic> localPayload;
  final Map<String, dynamic> serverPayload;
  final DateTime detectedAt;
  final bool resolved;

  const SyncConflict({
    required this.conflictId,
    required this.operationId,
    required this.entityType,
    required this.entityId,
    required this.localPayload,
    required this.serverPayload,
    required this.detectedAt,
    this.resolved = false,
  });

  String? get consumerNo =>
      localPayload['consumer_no']?.toString() ??
      serverPayload['consumer_no']?.toString();

  String? get customerName =>
      localPayload['name']?.toString() ??
      localPayload['customer_name']?.toString() ??
      serverPayload['name']?.toString() ??
      serverPayload['customer_name']?.toString();

  Map<String, dynamic> toMap() {
    return {
      'conflict_id': conflictId,
      'operation_id': operationId,
      'entity_type': entityType,
      'entity_id': entityId,
      'local_payload': jsonEncode(localPayload),
      'server_payload': jsonEncode(serverPayload),
      'detected_at': detectedAt.toIso8601String(),
      'resolved': resolved ? 1 : 0,
    };
  }

  factory SyncConflict.fromMap(Map<String, dynamic> map) {
    Map<String, dynamic> local = {};
    Map<String, dynamic> server = {};
    try {
      if (map['local_payload'] is String) {
        local = jsonDecode(map['local_payload'] as String) as Map<String, dynamic>;
      }
      if (map['server_payload'] is String) {
        server = jsonDecode(map['server_payload'] as String) as Map<String, dynamic>;
      }
    } catch (_) {}

    return SyncConflict(
      conflictId: map['conflict_id']?.toString() ?? '',
      operationId: map['operation_id']?.toString() ?? '',
      entityType: map['entity_type']?.toString() ?? '',
      entityId: map['entity_id']?.toString() ?? '',
      localPayload: local,
      serverPayload: server,
      detectedAt: map['detected_at'] != null
          ? DateTime.tryParse(map['detected_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      resolved: map['resolved'] == 1 || map['resolved'] == true,
    );
  }
}

/// Main Persistent Local Database Service (SQLite)
class AppDatabase {
  static const String _dbName = 'siya_solar_local.db';
  static const int _dbVersion = 1;

  static Database? _database;
  static Database? _testDatabase;

  /// Allow injecting a mock or FFI database for unit testing
  static void setTestDatabase(Database? db) {
    _testDatabase = db;
    _database = db;
  }

  /// Get current open database instance
  static Future<Database> get database async {
    if (_testDatabase != null) return _testDatabase!;
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  static Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, _dbName);

    return await openDatabase(
      path,
      version: _dbVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  static Future<void> _onCreate(Database db, int version) async {
    final batch = db.batch();

    // 1. Cached Consumer Records Table
    batch.execute('''
      CREATE TABLE cached_consumer_records (
        id TEXT PRIMARY KEY,
        consumer_no TEXT,
        name TEXT,
        mobile TEXT,
        application_id TEXT,
        village TEXT,
        status TEXT,
        customer_work_state TEXT,
        priority TEXT,
        assigned_staff_id TEXT,
        assigned_staff_name TEXT,
        raw_json TEXT NOT NULL,
        sync_status TEXT NOT NULL DEFAULT 'SYNCED',
        last_modified_at TEXT
      )
    ''');
    batch.execute('CREATE INDEX idx_cached_cr_consumer_no ON cached_consumer_records(consumer_no)');
    batch.execute('CREATE INDEX idx_cached_cr_name ON cached_consumer_records(name)');
    batch.execute('CREATE INDEX idx_cached_cr_mobile ON cached_consumer_records(mobile)');
    batch.execute('CREATE INDEX idx_cached_cr_app_id ON cached_consumer_records(application_id)');
    batch.execute('CREATE INDEX idx_cached_cr_village ON cached_consumer_records(village)');
    batch.execute('CREATE INDEX idx_cached_cr_state ON cached_consumer_records(customer_work_state)');
    batch.execute('CREATE INDEX idx_cached_cr_staff ON cached_consumer_records(assigned_staff_id)');

    // 2. Cached Leads Table
    batch.execute('''
      CREATE TABLE cached_leads (
        id TEXT PRIMARY KEY,
        customer_name TEXT,
        mobile_no TEXT,
        village TEXT,
        lead_status TEXT,
        assigned_staff_id TEXT,
        next_followup_date TEXT,
        raw_json TEXT NOT NULL,
        sync_status TEXT NOT NULL DEFAULT 'SYNCED'
      )
    ''');
    batch.execute('CREATE INDEX idx_cached_leads_name ON cached_leads(customer_name)');
    batch.execute('CREATE INDEX idx_cached_leads_mobile ON cached_leads(mobile_no)');
    batch.execute('CREATE INDEX idx_cached_leads_village ON cached_leads(village)');
    batch.execute('CREATE INDEX idx_cached_leads_status ON cached_leads(lead_status)');

    // 3. Cached Customer Tasks Table
    batch.execute('''
      CREATE TABLE cached_customer_tasks (
        id TEXT PRIMARY KEY,
        customer_id TEXT,
        consumer_no TEXT,
        customer_name TEXT,
        status TEXT,
        document_type TEXT,
        document_name TEXT,
        local_file_path TEXT,
        document_url TEXT,
        raw_json TEXT NOT NULL,
        sync_status TEXT NOT NULL DEFAULT 'Synced'
      )
    ''');
    batch.execute('CREATE INDEX idx_cached_tasks_cid ON cached_customer_tasks(customer_id)');
    batch.execute('CREATE INDEX idx_cached_tasks_status ON cached_customer_tasks(status)');
    batch.execute('CREATE INDEX idx_cached_tasks_sync ON cached_customer_tasks(sync_status)');

    // 4. Cached Payments Table
    batch.execute('''
      CREATE TABLE cached_payments (
        id TEXT PRIMARY KEY,
        client_tx_id TEXT UNIQUE,
        idempotency_key TEXT UNIQUE,
        customer_id TEXT,
        consumer_no TEXT,
        customer_name TEXT,
        amount REAL,
        payment_date TEXT,
        payment_type TEXT NOT NULL DEFAULT 'Offline',
        payment_mode TEXT,
        reference_number TEXT,
        verification_status TEXT NOT NULL DEFAULT 'Pending',
        proof_mismatch INTEGER NOT NULL DEFAULT 0,
        extracted_amount REAL,
        extracted_ref_no TEXT,
        attachment_url TEXT,
        local_attachment_path TEXT,
        raw_json TEXT NOT NULL,
        sync_status TEXT NOT NULL DEFAULT 'Synced'
      )
    ''');
    batch.execute('CREATE INDEX idx_cached_payments_cid ON cached_payments(customer_id)');
    batch.execute('CREATE INDEX idx_cached_payments_sync ON cached_payments(sync_status)');
    batch.execute('CREATE INDEX idx_cached_payments_date ON cached_payments(payment_date DESC)');
    batch.execute('CREATE INDEX idx_cached_payments_verify ON cached_payments(verification_status)');

    // 5. Cached Misc Actions Table
    batch.execute('''
      CREATE TABLE cached_misc_actions (
        id TEXT PRIMARY KEY,
        record_id TEXT,
        consumer_no TEXT,
        customer_name TEXT,
        action_type TEXT,
        status TEXT,
        raw_json TEXT NOT NULL,
        sync_status TEXT NOT NULL DEFAULT 'SYNCED'
      )
    ''');

    // 6. Cached Customer Issues Table
    batch.execute('''
      CREATE TABLE cached_customer_issues (
        id TEXT PRIMARY KEY,
        customer_id TEXT,
        consumer_no TEXT,
        customer_name TEXT,
        issue_type TEXT,
        status TEXT,
        priority TEXT,
        raw_json TEXT NOT NULL,
        sync_status TEXT NOT NULL DEFAULT 'SYNCED'
      )
    ''');

    // 7. Cached Activity Logs Table
    batch.execute('''
      CREATE TABLE cached_activity_logs (
        id TEXT PRIMARY KEY,
        record_id TEXT,
        consumer_no TEXT,
        staff_name TEXT,
        action TEXT,
        created_at TEXT,
        raw_json TEXT NOT NULL,
        sync_status TEXT NOT NULL DEFAULT 'Pending'
      )
    ''');
    batch.execute('CREATE INDEX idx_cached_logs_date ON cached_activity_logs(created_at DESC)');

    // 8. Offline Operations Queue Table
    batch.execute('''
      CREATE TABLE offline_operations_queue (
        operation_id TEXT PRIMARY KEY,
        entity_type TEXT NOT NULL,
        entity_id TEXT NOT NULL,
        action TEXT NOT NULL,
        payload TEXT NOT NULL,
        user_id TEXT,
        device_id TEXT,
        created_at TEXT NOT NULL,
        sync_status TEXT NOT NULL DEFAULT 'PENDING',
        retry_count INTEGER NOT NULL DEFAULT 0,
        error_message TEXT
      )
    ''');
    batch.execute('CREATE INDEX idx_op_queue_created ON offline_operations_queue(created_at ASC)');
    batch.execute('CREATE INDEX idx_op_queue_status ON offline_operations_queue(sync_status)');

    // 9. Sync Conflicts Table
    batch.execute('''
      CREATE TABLE sync_conflicts (
        conflict_id TEXT PRIMARY KEY,
        operation_id TEXT NOT NULL,
        entity_type TEXT NOT NULL,
        entity_id TEXT NOT NULL,
        local_payload TEXT NOT NULL,
        server_payload TEXT NOT NULL,
        detected_at TEXT NOT NULL,
        resolved INTEGER NOT NULL DEFAULT 0
      )
    ''');

    // 10. Sync Metadata Table
    batch.execute('''
      CREATE TABLE sync_metadata (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');

    await batch.commit(noResult: true);
  }

  static Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // Migration logic for future upgrades
  }

  // ===========================================================================
  // METADATA HELPERS
  // ===========================================================================

  static Future<String?> getMetadata(String key) async {
    final db = await database;
    final res = await db.query(
      'sync_metadata',
      where: 'key = ?',
      whereArgs: [key],
      limit: 1,
    );
    if (res.isEmpty) return null;
    return res.first['value']?.toString();
  }

  static Future<void> setMetadata(String key, String value) async {
    final db = await database;
    await db.insert(
      'sync_metadata',
      {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // ===========================================================================
  // OFFLINE OPERATIONS QUEUE
  // ===========================================================================

  static Future<void> enqueueOperation(OfflineOperation op) async {
    final db = await database;
    await db.insert(
      'offline_operations_queue',
      op.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  static Future<List<OfflineOperation>> getPendingOperations({int limit = 100}) async {
    final db = await database;
    final res = await db.query(
      'offline_operations_queue',
      where: "sync_status IN ('PENDING', 'FAILED')",
      orderBy: 'created_at ASC',
      limit: limit,
    );
    return res.map((m) => OfflineOperation.fromMap(m)).toList();
  }

  static Future<void> updateOperationStatus({
    required String operationId,
    required String syncStatus,
    int? retryCount,
    String? errorMessage,
  }) async {
    final db = await database;
    final values = <String, dynamic>{
      'sync_status': syncStatus,
      if (retryCount != null) 'retry_count': retryCount,
      if (errorMessage != null) 'error_message': errorMessage,
    };
    await db.update(
      'offline_operations_queue',
      values,
      where: 'operation_id = ?',
      whereArgs: [operationId],
    );
  }

  static Future<void> deleteOperation(String operationId) async {
    final db = await database;
    await db.delete(
      'offline_operations_queue',
      where: 'operation_id = ?',
      whereArgs: [operationId],
    );
  }

  static Future<int> getPendingOperationsCount() async {
    final db = await database;
    final res = await db.rawQuery(
      "SELECT COUNT(*) as count FROM offline_operations_queue WHERE sync_status IN ('PENDING', 'FAILED', 'SYNCING')",
    );
    return Sqflite.firstIntValue(res) ?? 0;
  }

  static Future<int> getFailedOperationsCount() async {
    final db = await database;
    final res = await db.rawQuery(
      "SELECT COUNT(*) as count FROM offline_operations_queue WHERE sync_status = 'FAILED'",
    );
    return Sqflite.firstIntValue(res) ?? 0;
  }

  // ===========================================================================
  // SYNC CONFLICTS
  // ===========================================================================

  static Future<void> recordConflict(SyncConflict conflict) async {
    final db = await database;
    await db.insert(
      'sync_conflicts',
      conflict.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  static Future<List<SyncConflict>> getActiveConflicts() async {
    final db = await database;
    final res = await db.query(
      'sync_conflicts',
      where: 'resolved = 0',
      orderBy: 'detected_at DESC',
    );
    return res.map((m) => SyncConflict.fromMap(m)).toList();
  }

  static Future<void> resolveConflict(String conflictId) async {
    final db = await database;
    await db.update(
      'sync_conflicts',
      {'resolved': 1},
      where: 'conflict_id = ?',
      whereArgs: [conflictId],
    );
  }

  static Future<int> getActiveConflictsCount() async {
    final db = await database;
    final res = await db.rawQuery(
      'SELECT COUNT(*) as count FROM sync_conflicts WHERE resolved = 0',
    );
    return Sqflite.firstIntValue(res) ?? 0;
  }

  // ===========================================================================
  // CONSUMER RECORDS (LOCAL CACHE)
  // ===========================================================================

  static Future<void> upsertConsumerRecord(ConsumerRecord record, {String syncStatus = 'SYNCED'}) async {
    final db = await database;
    final rawJson = jsonEncode(record.toJson());
    await db.insert(
      'cached_consumer_records',
      {
        'id': record.id ?? '',
        'consumer_no': record.consumerNo,
        'name': record.name,
        'mobile': record.mobile,
        'application_id': record.applicationId,
        'village': record.village,
        'status': record.status,
        'customer_work_state': record.customerWorkState,
        'priority': record.priority,
        'assigned_staff_id': record.assignedStaffId,
        'assigned_staff_name': record.assignedStaffName,
        'raw_json': rawJson,
        'sync_status': syncStatus,
        'last_modified_at': DateTime.now().toUtc().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  static Future<void> batchUpsertConsumerRecords(List<ConsumerRecord> records, {String syncStatus = 'SYNCED'}) async {
    final db = await database;
    final batch = db.batch();
    final nowIso = DateTime.now().toUtc().toIso8601String();

    for (final record in records) {
      if (record.id == null || record.id!.isEmpty) continue;
      batch.insert(
        'cached_consumer_records',
        {
          'id': record.id!,
          'consumer_no': record.consumerNo,
          'name': record.name,
          'mobile': record.mobile,
          'application_id': record.applicationId,
          'village': record.village,
          'status': record.status,
          'customer_work_state': record.customerWorkState,
          'priority': record.priority,
          'assigned_staff_id': record.assignedStaffId,
          'assigned_staff_name': record.assignedStaffName,
          'raw_json': jsonEncode(record.toJson()),
          'sync_status': syncStatus,
          'last_modified_at': nowIso,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    await batch.commit(noResult: true);
  }

  static Future<ConsumerRecord?> getConsumerRecordById(String id) async {
    final db = await database;
    final res = await db.query(
      'cached_consumer_records',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (res.isEmpty) return null;
    return ConsumerRecord.fromJson(
      jsonDecode(res.first['raw_json'] as String) as Map<String, dynamic>,
    );
  }

  /// Fast local partial search across multiple indexed fields
  static Future<List<ConsumerRecord>> searchConsumerRecords({
    String? query,
    String? statusFilter,
    String? workStateFilter,
    int page = 1,
    int pageSize = 25,
  }) async {
    final db = await database;
    final whereClauses = <String>[];
    final whereArgs = <dynamic>[];

    if (statusFilter != null && statusFilter.isNotEmpty && statusFilter != 'All') {
      whereClauses.add('status = ?');
      whereArgs.add(statusFilter);
    }

    if (workStateFilter != null && workStateFilter.isNotEmpty && workStateFilter != 'All') {
      whereClauses.add('customer_work_state = ?');
      whereArgs.add(workStateFilter);
    }

    if (query != null && query.trim().isNotEmpty) {
      final term = '%${query.trim()}%';
      whereClauses.add(
        '(consumer_no LIKE ? OR name LIKE ? OR mobile LIKE ? OR application_id LIKE ? OR village LIKE ?)',
      );
      whereArgs.addAll([term, term, term, term, term]);
    }

    final whereString = whereClauses.isEmpty ? null : whereClauses.join(' AND ');
    final offset = (page - 1) * pageSize;

    final res = await db.query(
      'cached_consumer_records',
      where: whereString,
      whereArgs: whereArgs,
      orderBy: 'last_modified_at DESC',
      limit: pageSize,
      offset: offset,
    );

    return res.map((row) {
      return ConsumerRecord.fromJson(
        jsonDecode(row['raw_json'] as String) as Map<String, dynamic>,
      );
    }).toList();
  }

  static Future<int> countConsumerRecords({
    String? query,
    String? statusFilter,
    String? workStateFilter,
  }) async {
    final db = await database;
    final whereClauses = <String>[];
    final whereArgs = <dynamic>[];

    if (statusFilter != null && statusFilter.isNotEmpty && statusFilter != 'All') {
      whereClauses.add('status = ?');
      whereArgs.add(statusFilter);
    }

    if (workStateFilter != null && workStateFilter.isNotEmpty && workStateFilter != 'All') {
      whereClauses.add('customer_work_state = ?');
      whereArgs.add(workStateFilter);
    }

    if (query != null && query.trim().isNotEmpty) {
      final term = '%${query.trim()}%';
      whereClauses.add(
        '(consumer_no LIKE ? OR name LIKE ? OR mobile LIKE ? OR application_id LIKE ? OR village LIKE ?)',
      );
      whereArgs.addAll([term, term, term, term, term]);
    }

    final whereString = whereClauses.isEmpty ? null : whereClauses.join(' AND ');
    final res = await db.query(
      'cached_consumer_records',
      columns: ['COUNT(*) as count'],
      where: whereString,
      whereArgs: whereArgs,
    );
    return Sqflite.firstIntValue(res) ?? 0;
  }

  /// Get all cached consumer records
  static Future<List<ConsumerRecord>> getAllConsumerRecords() async {
    final db = await database;
    final res = await db.query('cached_consumer_records', orderBy: 'last_modified_at DESC');
    return res.map((row) {
      return ConsumerRecord.fromJson(
        jsonDecode(row['raw_json'] as String) as Map<String, dynamic>,
      );
    }).toList();
  }

  /// Dashboard summary aggregated directly from offline database
  static Future<Map<String, int>> getDashboardSummary() async {
    final db = await database;

    final totalRes = await db.rawQuery('SELECT COUNT(*) as c FROM cached_consumer_records');
    final total = Sqflite.firstIntValue(totalRes) ?? 0;

    final activeRes = await db.rawQuery(
      "SELECT COUNT(*) as c FROM cached_consumer_records WHERE customer_work_state = 'ACTIVE'",
    );
    final active = Sqflite.firstIntValue(activeRes) ?? 0;

    final completeRes = await db.rawQuery(
      "SELECT COUNT(*) as c FROM cached_consumer_records WHERE customer_work_state = 'COMPLETED'",
    );
    final completed = Sqflite.firstIntValue(completeRes) ?? 0;

    final holdRes = await db.rawQuery(
      "SELECT COUNT(*) as c FROM cached_consumer_records WHERE customer_work_state = 'ON_HOLD'",
    );
    final onHold = Sqflite.firstIntValue(holdRes) ?? 0;

    final leadsRes = await db.rawQuery(
      "SELECT COUNT(*) as c FROM cached_leads WHERE lead_status NOT IN ('Converted', 'Lost', 'No Action Required')",
    );
    final activeLeads = Sqflite.firstIntValue(leadsRes) ?? 0;

    final tasksRes = await db.rawQuery(
      "SELECT COUNT(*) as c FROM cached_customer_tasks WHERE status NOT IN ('Complete')",
    );
    final pendingTasks = Sqflite.firstIntValue(tasksRes) ?? 0;

    return {
      'total': total,
      'active': active,
      'completed': completed,
      'on_hold': onHold,
      'active_leads': activeLeads,
      'pending_tasks': pendingTasks,
    };
  }

  // ===========================================================================
  // PAYMENTS (LOCAL CACHE & INTELLIGENCE)
  // ===========================================================================

  static Future<void> upsertPayment(PaymentTransaction tx, {String syncStatus = 'Synced'}) async {
    final db = await database;
    final paymentId = tx.id ?? tx.clientTxId ?? DateTime.now().microsecondsSinceEpoch.toString();

    // Try to resolve customer name from cached consumer records if available
    String customerName = '';
    try {
      final cr = await getConsumerRecordById(tx.customerId);
      if (cr != null) customerName = cr.name;
    } catch (_) {}

    await db.insert(
      'cached_payments',
      {
        'id': paymentId,
        'client_tx_id': tx.clientTxId,
        'idempotency_key': tx.idempotencyKey,
        'customer_id': tx.customerId,
        'consumer_no': tx.consumerNo,
        'customer_name': customerName,
        'amount': tx.amount,
        'payment_date': tx.paymentDate.toIso8601String().split('T')[0],
        'payment_type': tx.paymentType,
        'payment_mode': tx.paymentMode,
        'reference_number': tx.referenceNumber,
        'verification_status': tx.verificationStatus,
        'proof_mismatch': tx.proofMismatch ? 1 : 0,
        'extracted_amount': tx.extractedAmount,
        'extracted_ref_no': tx.extractedRefNo,
        'attachment_url': tx.attachmentUrl,
        'local_attachment_path': tx.localAttachmentPath,
        'raw_json': jsonEncode(tx.toJson()),
        'sync_status': syncStatus,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  static Future<void> batchUpsertPayments(List<PaymentTransaction> list, {String syncStatus = 'Synced'}) async {
    final db = await database;
    final batch = db.batch();
    for (final tx in list) {
      final paymentId = tx.id ?? tx.clientTxId ?? DateTime.now().microsecondsSinceEpoch.toString();
      batch.insert(
        'cached_payments',
        {
          'id': paymentId,
          'client_tx_id': tx.clientTxId,
          'idempotency_key': tx.idempotencyKey,
          'customer_id': tx.customerId,
          'consumer_no': tx.consumerNo,
          'amount': tx.amount,
          'payment_date': tx.paymentDate.toIso8601String().split('T')[0],
          'payment_type': tx.paymentType,
          'payment_mode': tx.paymentMode,
          'reference_number': tx.referenceNumber,
          'verification_status': tx.verificationStatus,
          'proof_mismatch': tx.proofMismatch ? 1 : 0,
          'extracted_amount': tx.extractedAmount,
          'extracted_ref_no': tx.extractedRefNo,
          'attachment_url': tx.attachmentUrl,
          'local_attachment_path': tx.localAttachmentPath,
          'raw_json': jsonEncode(tx.toJson()),
          'sync_status': syncStatus,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  static Future<List<PaymentTransaction>> getCustomerPayments(String customerId) async {
    final db = await database;
    final res = await db.query(
      'cached_payments',
      where: 'customer_id = ?',
      whereArgs: [customerId],
      orderBy: 'payment_date DESC',
    );
    return res.map((m) {
      return PaymentTransaction.fromJson(
        jsonDecode(m['raw_json'] as String) as Map<String, dynamic>,
      );
    }).toList();
  }

  static Future<List<PaymentTransaction>> getAllPayments({
    String? modeFilter,
    String? verificationFilter,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final db = await database;
    final whereClauses = <String>[];
    final whereArgs = <dynamic>[];

    if (modeFilter != null && modeFilter != 'All') {
      whereClauses.add('payment_mode = ?');
      whereArgs.add(modeFilter);
    }

    if (verificationFilter != null && verificationFilter != 'All') {
      whereClauses.add('verification_status = ?');
      whereArgs.add(verificationFilter);
    }

    if (startDate != null) {
      whereClauses.add('payment_date >= ?');
      whereArgs.add(startDate.toIso8601String().split('T')[0]);
    }

    if (endDate != null) {
      whereClauses.add('payment_date <= ?');
      whereArgs.add(endDate.toIso8601String().split('T')[0]);
    }

    final whereString = whereClauses.isEmpty ? null : whereClauses.join(' AND ');
    final res = await db.query(
      'cached_payments',
      where: whereString,
      whereArgs: whereArgs,
      orderBy: 'payment_date DESC',
    );

    return res.map((m) {
      return PaymentTransaction.fromJson(
        jsonDecode(m['raw_json'] as String) as Map<String, dynamic>,
      );
    }).toList();
  }

  static Future<int> getPendingPaymentsCount() async {
    final db = await database;
    final res = await db.rawQuery(
      "SELECT COUNT(*) as count FROM cached_payments WHERE sync_status = 'Pending Sync'",
    );
    return Sqflite.firstIntValue(res) ?? 0;
  }

  /// Calculates fast aggregate figures for the Payment Dashboard completely offline
  static Future<PaymentDashboardSummary> getPaymentDashboardSummary() async {
    final db = await database;
    final now = DateTime.now();
    final todayStr = now.toIso8601String().split('T')[0];
    final monthPrefix = '${now.year}-${now.month.toString().padLeft(2, '0')}';

    // 1. Today's collection
    final todayRes = await db.rawQuery(
      "SELECT SUM(amount) as s, COUNT(*) as c FROM cached_payments WHERE payment_date = ?",
      [todayStr],
    );
    final todayCollection = (todayRes.first['s'] as num?)?.toDouble() ?? 0.0;
    final todayPaymentsCount = (todayRes.first['c'] as num?)?.toInt() ?? 0;

    // 2. This Month's collection
    final monthRes = await db.rawQuery(
      "SELECT SUM(amount) as s FROM cached_payments WHERE payment_date LIKE ?",
      ['$monthPrefix%'],
    );
    final monthCollection = (monthRes.first['s'] as num?)?.toDouble() ?? 0.0;

    // 3. Totals from cached consumer records
    final totalsRes = await db.rawQuery('''
      SELECT 
        SUM(json_extract(raw_json, '\$.total_amount')) as total_contract,
        SUM(json_extract(raw_json, '\$.paid_amount')) as total_paid,
        SUM(json_extract(raw_json, '\$.pending_amount')) as total_pending,
        COUNT(CASE WHEN json_extract(raw_json, '\$.pending_amount') > 0 THEN 1 END) as pending_customers
      FROM cached_consumer_records
      WHERE customer_work_state != 'COMPLETED'
    ''');
    final totalContract = (totalsRes.first['total_contract'] as num?)?.toDouble() ?? 0.0;
    final totalPaid = (totalsRes.first['total_paid'] as num?)?.toDouble() ?? 0.0;
    final totalPending = (totalsRes.first['total_pending'] as num?)?.toDouble() ?? 0.0;
    final pendingCount = (totalsRes.first['pending_customers'] as num?)?.toInt() ?? 0;

    // 4. Pending Sync count
    final pendingSync = await getPendingPaymentsCount();

    // 5. Active follow-ups count
    final fuRes = await db.rawQuery('''
      SELECT COUNT(*) as c FROM cached_consumer_records 
      WHERE json_extract(raw_json, '\$.has_active_followup') = 1
         OR json_extract(raw_json, '\$.has_active_followup') = 'true'
    ''');
    final activeFollowups = Sqflite.firstIntValue(fuRes) ?? 0;

    // 6. Unverified payments count
    final unverifiedRes = await db.rawQuery(
      "SELECT COUNT(*) as c FROM cached_payments WHERE verification_status = 'Pending'",
    );
    final unverifiedCount = Sqflite.firstIntValue(unverifiedRes) ?? 0;

    return PaymentDashboardSummary(
      todayCollection: todayCollection,
      monthCollection: monthCollection,
      totalContractAmount: totalContract,
      totalPaidAmount: totalPaid,
      totalPendingAmount: totalPending,
      todayPaymentsCount: todayPaymentsCount,
      pendingPaymentsCount: pendingCount,
      pendingSyncCount: pendingSync,
      activeFollowupsCount: activeFollowups,
      unverifiedPaymentsCount: unverifiedCount,
    );
  }

  /// Fast multi-field payment search completely offline
  static Future<List<PaymentTransaction>> searchPaymentsOffline(
    String query, {
    String? modeFilter,
    String? verificationFilter,
  }) async {
    final db = await database;
    final term = '%${query.trim()}%';
    final whereClauses = <String>[
      '(consumer_no LIKE ? OR customer_name LIKE ? OR reference_number LIKE ? OR id LIKE ? OR client_tx_id LIKE ?)'
    ];
    final whereArgs = <dynamic>[term, term, term, term, term];

    if (modeFilter != null && modeFilter != 'All') {
      whereClauses.add('payment_mode = ?');
      whereArgs.add(modeFilter);
    }

    if (verificationFilter != null && verificationFilter != 'All') {
      whereClauses.add('verification_status = ?');
      whereArgs.add(verificationFilter);
    }

    final res = await db.query(
      'cached_payments',
      where: whereClauses.join(' AND '),
      whereArgs: whereArgs,
      orderBy: 'payment_date DESC',
      limit: 100,
    );

    return res.map((m) {
      return PaymentTransaction.fromJson(
        jsonDecode(m['raw_json'] as String) as Map<String, dynamic>,
      );
    }).toList();
  }

  /// Update payment verification status locally
  static Future<void> updatePaymentVerification(
    String paymentId,
    String verificationStatus, {
    String? remarks,
    String? staffName,
  }) async {
    final db = await database;
    final res = await db.query(
      'cached_payments',
      where: 'id = ? OR client_tx_id = ?',
      whereArgs: [paymentId, paymentId],
      limit: 1,
    );

    if (res.isNotEmpty) {
      final current = PaymentTransaction.fromJson(
        jsonDecode(res.first['raw_json'] as String) as Map<String, dynamic>,
      );
      final updated = current.copyWith(
        verificationStatus: verificationStatus,
        verificationRemarks: remarks,
        verifiedByName: staffName,
        verifiedAt: DateTime.now(),
      );
      await db.update(
        'cached_payments',
        {
          'verification_status': verificationStatus,
          'raw_json': jsonEncode(updated.toJson()),
        },
        where: 'id = ? OR client_tx_id = ?',
        whereArgs: [paymentId, paymentId],
      );
    }
  }

  // ===========================================================================
  // TASKS (LOCAL CACHE)
  // ===========================================================================

  static Future<void> upsertCustomerTask(CustomerTask task) async {
    final db = await database;
    await db.insert(
      'cached_customer_tasks',
      {
        'id': task.id,
        'customer_id': task.customerId,
        'consumer_no': task.consumerNo,
        'customer_name': task.customerName,
        'status': task.status,
        'document_type': task.documentType,
        'document_name': task.documentName,
        'local_file_path': task.localFilePath,
        'document_url': task.documentUrl,
        'raw_json': jsonEncode(task.toMap()),
        'sync_status': task.syncStatus,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  static Future<List<CustomerTask>> getCustomerTasks({String? statusFilter}) async {
    final db = await database;
    final res = await db.query(
      'cached_customer_tasks',
      where: (statusFilter != null && statusFilter != 'All') ? 'status = ?' : null,
      whereArgs: (statusFilter != null && statusFilter != 'All') ? [statusFilter] : null,
      orderBy: 'id DESC',
    );
    return res.map((m) {
      return CustomerTask.fromMap(
        jsonDecode(m['raw_json'] as String) as Map<String, dynamic>,
      );
    }).toList();
  }

  static Future<int> getPendingTasksCount() async {
    final db = await database;
    final res = await db.rawQuery(
      "SELECT COUNT(*) as count FROM cached_customer_tasks WHERE sync_status = 'Pending Sync'",
    );
    return Sqflite.firstIntValue(res) ?? 0;
  }

  // ===========================================================================
  // LEADS (LOCAL CACHE)
  // ===========================================================================

  static Future<void> upsertLead(LeadRecord lead, {String syncStatus = 'SYNCED'}) async {
    final db = await database;
    await db.insert(
      'cached_leads',
      {
        'id': lead.id,
        'customer_name': lead.customerName,
        'mobile_no': lead.mobileNo,
        'village': lead.village,
        'lead_status': lead.leadStatus,
        'assigned_staff_id': lead.assignedStaffId,
        'next_followup_date': lead.nextFollowupDate?.toIso8601String(),
        'raw_json': jsonEncode(lead.toJson()),
        'sync_status': syncStatus,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  static Future<List<LeadRecord>> getLeads({
    String? statusFilter,
    String? searchQuery,
  }) async {
    final db = await database;
    final whereClauses = <String>[];
    final whereArgs = <dynamic>[];

    if (statusFilter != null && statusFilter != 'All') {
      whereClauses.add('lead_status = ?');
      whereArgs.add(statusFilter);
    }

    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      final term = '%${searchQuery.trim()}%';
      whereClauses.add('(customer_name LIKE ? OR mobile_no LIKE ? OR village LIKE ?)');
      whereArgs.addAll([term, term, term]);
    }

    final whereString = whereClauses.isEmpty ? null : whereClauses.join(' AND ');
    final res = await db.query(
      'cached_leads',
      where: whereString,
      whereArgs: whereArgs,
      orderBy: 'next_followup_date ASC',
    );

    return res.map((m) {
      return LeadRecord.fromJson(
        jsonDecode(m['raw_json'] as String) as Map<String, dynamic>,
      );
    }).toList();
  }

  // ===========================================================================
  // MISC ACTIONS (LOCAL CACHE)
  // ===========================================================================

  static Future<void> upsertMiscAction(CustomerMiscAction action, {String syncStatus = 'SYNCED'}) async {
    final db = await database;
    await db.insert(
      'cached_misc_actions',
      {
        'id': action.id ?? DateTime.now().microsecondsSinceEpoch.toString(),
        'record_id': action.recordId,
        'consumer_no': action.consumerNo,
        'customer_name': action.customerName,
        'action_type': action.reason,
        'status': action.status,
        'raw_json': jsonEncode(action.toJson()),
        'sync_status': syncStatus,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  static Future<List<CustomerMiscAction>> getMiscActions({String? statusFilter, String? recordId}) async {
    final db = await database;
    final whereClauses = <String>[];
    final whereArgs = <dynamic>[];

    if (recordId != null && recordId.isNotEmpty) {
      whereClauses.add('record_id = ?');
      whereArgs.add(recordId);
    }
    if (statusFilter != null && statusFilter != 'All' && statusFilter.isNotEmpty) {
      if (statusFilter == 'Active') {
        whereClauses.add("status IN ('Pending', 'In Progress')");
      } else {
        whereClauses.add('status = ?');
        whereArgs.add(statusFilter);
      }
    }

    final whereStr = whereClauses.isEmpty ? null : whereClauses.join(' AND ');
    final res = await db.query(
      'cached_misc_actions',
      where: whereStr,
      whereArgs: whereArgs,
      orderBy: 'id DESC',
    );
    return res.map((m) {
      return CustomerMiscAction.fromJson(
        jsonDecode(m['raw_json'] as String) as Map<String, dynamic>,
      );
    }).toList();
  }

  // ===========================================================================
  // CUSTOMER ISSUES (LOCAL CACHE)
  // ===========================================================================

  static Future<void> upsertCustomerIssue(CustomerIssue issue, {String syncStatus = 'SYNCED'}) async {
    final db = await database;
    await db.insert(
      'cached_customer_issues',
      {
        'id': issue.id ?? DateTime.now().microsecondsSinceEpoch.toString(),
        'customer_id': issue.customerId,
        'consumer_no': issue.consumerNo,
        'customer_name': issue.customerName,
        'issue_type': issue.issueType,
        'status': issue.status,
        'priority': issue.priority,
        'raw_json': jsonEncode(issue.toJson()),
        'sync_status': syncStatus,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  static Future<List<CustomerIssue>> getCustomerIssues({String? statusFilter, String? customerId}) async {
    final db = await database;
    final whereClauses = <String>[];
    final whereArgs = <dynamic>[];

    if (customerId != null && customerId.isNotEmpty) {
      whereClauses.add('customer_id = ?');
      whereArgs.add(customerId);
    }
    if (statusFilter != null && statusFilter != 'All' && statusFilter.isNotEmpty) {
      if (statusFilter == 'Active') {
        whereClauses.add("status IN ('New', 'Assigned', 'In Progress', 'Hold')");
      } else {
        whereClauses.add('status = ?');
        whereArgs.add(statusFilter);
      }
    }

    final whereStr = whereClauses.isEmpty ? null : whereClauses.join(' AND ');
    final res = await db.query(
      'cached_customer_issues',
      where: whereStr,
      whereArgs: whereArgs,
      orderBy: 'id DESC',
    );
    return res.map((m) {
      return CustomerIssue.fromJson(
        jsonDecode(m['raw_json'] as String) as Map<String, dynamic>,
      );
    }).toList();
  }

  // ===========================================================================
  // ACTIVITY LOGS (LOCAL CACHE)
  // ===========================================================================

  static Future<void> logOfflineActivity({
    String? id,
    String? recordId,
    required String consumerNo,
    String customerName = 'Customer',
    String village = '-',
    String module = 'General',
    required String action,
    String? oldValue,
    String? newValue,
    String? nextAction,
    String? remarks,
    String? staffId,
    String staffName = 'Mobile Staff',
    String staffRole = 'staff',
    String source = 'Mobile App (Offline)',
    Map<String, dynamic>? metadata,
    String syncStatus = 'Pending',
  }) async {
    final logId = id ?? DateTime.now().microsecondsSinceEpoch.toString();
    final log = ActivityLog(
      id: logId,
      recordId: recordId,
      consumerNo: consumerNo,
      customerName: customerName,
      village: village,
      module: module,
      action: action,
      oldValue: oldValue,
      newValue: newValue,
      nextAction: nextAction,
      remarks: remarks,
      staffId: staffId,
      staffName: staffName,
      staffRole: staffRole,
      source: source,
      metadata: metadata,
      createdAt: DateTime.now(),
    );

    final db = await database;
    await db.insert(
      'cached_activity_logs',
      {
        'id': logId,
        'record_id': recordId,
        'consumer_no': consumerNo,
        'staff_name': staffName,
        'action': action,
        'created_at': DateTime.now().toIso8601String(),
        'raw_json': jsonEncode(log.toJson()),
        'sync_status': syncStatus,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  static Future<List<ActivityLog>> getPendingActivityLogs() async {
    final db = await database;
    final res = await db.query(
      'cached_activity_logs',
      where: "sync_status = 'Pending'",
      orderBy: 'created_at ASC',
    );
    return res.map((m) {
      return ActivityLog.fromJson(
        jsonDecode(m['raw_json'] as String) as Map<String, dynamic>,
      );
    }).toList();
  }

  static Future<void> markActivityLogSynced(String id) async {
    final db = await database;
    await db.update(
      'cached_activity_logs',
      {'sync_status': 'Confirmed'},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ===========================================================================
  // CLEANUP & PURGE
  // ===========================================================================

  static Future<void> clearAllData() async {
    final db = await database;
    await db.delete('cached_consumer_records');
    await db.delete('cached_leads');
    await db.delete('cached_customer_tasks');
    await db.delete('cached_payments');
    await db.delete('cached_misc_actions');
    await db.delete('cached_customer_issues');
    await db.delete('cached_activity_logs');
    await db.delete('offline_operations_queue');
    await db.delete('sync_conflicts');
    await db.delete('sync_metadata');
  }
}
