import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import '../models/consumer_record.dart';
import '../models/customer_task.dart';
import '../models/customer_payment.dart';
import '../models/lead_record.dart';
import '../models/customer_misc_action.dart';
import '../models/customer_issue.dart';
import '../models/activity_log.dart';
import '../models/office_task.dart';

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

  /// Version history:
  ///   v1 — Initial schema (10 tables: records, leads, tasks, payments,
  ///          misc_actions, issues, activity_logs, op_queue, conflicts, metadata)
  ///   v2 — Added: retry_count safety guard (data only, no schema change needed)
  ///          whatsapp_docs cleanup tracking metadata key
  ///   v3 — Added: additional_category column to cached_payments for Additional Payments support
  ///   v4 — Added: cached_office_tasks and cached_task_assignments for Office Staff Tasks support
  ///   v5 — Added: completed_by and completed_by_name to cached_office_tasks
  ///   v6 — Added: loan_sanctioned_amount to consumer_records (raw_json field, no ALTER needed)
  ///   v7 — Added: site_type column and index to cached_consumer_records and cached_leads
  static const int _dbVersion = 7;

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
        site_type TEXT DEFAULT 'Subsidy',
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
    batch.execute('CREATE INDEX idx_cached_cr_site_type ON cached_consumer_records(site_type)');

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
        site_type TEXT DEFAULT 'Subsidy',
        raw_json TEXT NOT NULL,
        sync_status TEXT NOT NULL DEFAULT 'SYNCED'
      )
    ''');
    batch.execute('CREATE INDEX idx_cached_leads_name ON cached_leads(customer_name)');
    batch.execute('CREATE INDEX idx_cached_leads_mobile ON cached_leads(mobile_no)');
    batch.execute('CREATE INDEX idx_cached_leads_village ON cached_leads(village)');
    batch.execute('CREATE INDEX idx_cached_leads_status ON cached_leads(lead_status)');
    batch.execute('CREATE INDEX idx_cached_leads_site_type ON cached_leads(site_type)');

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
        payment_type TEXT NOT NULL DEFAULT 'CONTRACT',
        additional_category TEXT,
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

    // 11. Cached Office Tasks Table
    batch.execute('''
      CREATE TABLE cached_office_tasks (
        id TEXT PRIMARY KEY,
        customer_id TEXT,
        customer_name TEXT NOT NULL,
        consumer_no TEXT NOT NULL,
        village TEXT,
        title TEXT NOT NULL,
        task_type TEXT NOT NULL,
        description TEXT,
        priority TEXT NOT NULL,
        status TEXT NOT NULL,
        due_date TEXT,
        assigned_to_id TEXT,
        assigned_to_name TEXT NOT NULL,
        created_by TEXT,
        created_by_name TEXT,
        started_at TEXT,
        completed_at TEXT,
        completed_by TEXT,
        completed_by_name TEXT,
        completion_note TEXT,
        hold_reason TEXT,
        attachment_url TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
    batch.execute('CREATE INDEX idx_cached_office_tasks_status ON cached_office_tasks(status)');
    batch.execute('CREATE INDEX idx_cached_office_tasks_assigned_to ON cached_office_tasks(assigned_to_name)');
    batch.execute('CREATE INDEX idx_cached_office_tasks_due_date ON cached_office_tasks(due_date)');

    // 12. Cached Task Assignments Table
    batch.execute('''
      CREATE TABLE cached_task_assignments (
        id TEXT PRIMARY KEY,
        task_id TEXT NOT NULL,
        staff_id TEXT,
        staff_name TEXT NOT NULL,
        assigned_by TEXT,
        assigned_by_name TEXT,
        assigned_at TEXT NOT NULL,
        status TEXT NOT NULL,
        started_at TEXT,
        completed_at TEXT,
        remarks TEXT,
        created_at TEXT NOT NULL
      )
    ''');
    batch.execute('CREATE INDEX idx_cached_assign_task ON cached_task_assignments(task_id)');

    await batch.commit(noResult: true);
  }

  static Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    debugPrint('[AppDatabase] Upgrading SQLite from v$oldVersion to v$newVersion');
    final batch = db.batch();

    // -------------------------------------------------------------------------
    // v1 → v2: No new columns required yet.
    // Use CREATE TABLE IF NOT EXISTS guards to handle any users who may have
    // a partially-initialised db (edge-case recovery).
    // -------------------------------------------------------------------------
    if (oldVersion < 2) {
      // Ensure all core tables exist (safe no-op on fresh installs)
      batch.execute('''
        CREATE TABLE IF NOT EXISTS cached_consumer_records (
          id TEXT PRIMARY KEY, consumer_no TEXT, name TEXT, mobile TEXT,
          application_id TEXT, village TEXT, status TEXT, customer_work_state TEXT,
          priority TEXT, assigned_staff_id TEXT, assigned_staff_name TEXT,
          raw_json TEXT NOT NULL, sync_status TEXT NOT NULL DEFAULT 'SYNCED',
          last_modified_at TEXT
        )
      ''');
      batch.execute('''
        CREATE TABLE IF NOT EXISTS cached_leads (
          id TEXT PRIMARY KEY, customer_name TEXT, mobile_no TEXT, village TEXT,
          lead_status TEXT, assigned_staff_id TEXT, next_followup_date TEXT,
          raw_json TEXT NOT NULL, sync_status TEXT NOT NULL DEFAULT 'SYNCED'
        )
      ''');
      batch.execute('''
        CREATE TABLE IF NOT EXISTS cached_customer_tasks (
          id TEXT PRIMARY KEY, customer_id TEXT, consumer_no TEXT,
          customer_name TEXT, status TEXT, document_type TEXT, document_name TEXT,
          local_file_path TEXT, document_url TEXT,
          raw_json TEXT NOT NULL, sync_status TEXT NOT NULL DEFAULT 'Synced'
        )
      ''');
      batch.execute('''
        CREATE TABLE IF NOT EXISTS cached_payments (
          id TEXT PRIMARY KEY, client_tx_id TEXT UNIQUE, idempotency_key TEXT UNIQUE,
          customer_id TEXT, consumer_no TEXT, customer_name TEXT, amount REAL,
          payment_date TEXT, payment_type TEXT NOT NULL DEFAULT 'Offline',
          payment_mode TEXT, reference_number TEXT,
          verification_status TEXT NOT NULL DEFAULT 'Pending',
          proof_mismatch INTEGER NOT NULL DEFAULT 0,
          extracted_amount REAL, extracted_ref_no TEXT,
          attachment_url TEXT, local_attachment_path TEXT,
          raw_json TEXT NOT NULL, sync_status TEXT NOT NULL DEFAULT 'Synced'
        )
      ''');
      batch.execute('''
        CREATE TABLE IF NOT EXISTS cached_misc_actions (
          id TEXT PRIMARY KEY, record_id TEXT, consumer_no TEXT,
          customer_name TEXT, action_type TEXT, status TEXT,
          raw_json TEXT NOT NULL, sync_status TEXT NOT NULL DEFAULT 'SYNCED'
        )
      ''');
      batch.execute('''
        CREATE TABLE IF NOT EXISTS cached_customer_issues (
          id TEXT PRIMARY KEY, customer_id TEXT, consumer_no TEXT,
          customer_name TEXT, issue_type TEXT, status TEXT, priority TEXT,
          raw_json TEXT NOT NULL, sync_status TEXT NOT NULL DEFAULT 'SYNCED'
        )
      ''');
      batch.execute('''
        CREATE TABLE IF NOT EXISTS cached_activity_logs (
          id TEXT PRIMARY KEY, record_id TEXT, consumer_no TEXT, staff_name TEXT,
          action TEXT, created_at TEXT, raw_json TEXT NOT NULL,
          sync_status TEXT NOT NULL DEFAULT 'Pending'
        )
      ''');
      batch.execute('''
        CREATE TABLE IF NOT EXISTS offline_operations_queue (
          operation_id TEXT PRIMARY KEY, entity_type TEXT NOT NULL,
          entity_id TEXT NOT NULL, action TEXT NOT NULL, payload TEXT NOT NULL,
          user_id TEXT, device_id TEXT, created_at TEXT NOT NULL,
          sync_status TEXT NOT NULL DEFAULT 'PENDING',
          retry_count INTEGER NOT NULL DEFAULT 0, error_message TEXT
        )
      ''');
      batch.execute('''
        CREATE TABLE IF NOT EXISTS sync_conflicts (
          conflict_id TEXT PRIMARY KEY, operation_id TEXT NOT NULL,
          entity_type TEXT NOT NULL, entity_id TEXT NOT NULL,
          local_payload TEXT NOT NULL, server_payload TEXT NOT NULL,
          detected_at TEXT NOT NULL, resolved INTEGER NOT NULL DEFAULT 0
        )
      ''');
      batch.execute('''
        CREATE TABLE IF NOT EXISTS sync_metadata (
          key TEXT PRIMARY KEY, value TEXT NOT NULL
        )
      ''');

      // Dead-letter any FAILED operations that piled up before the retry cap
      // existed — mark them ABANDONED so they do not loop forever.
      batch.execute('''
        UPDATE offline_operations_queue
        SET sync_status = 'ABANDONED', error_message = 'Abandoned during v1→v2 upgrade (exceeded retry safety limit)'
        WHERE sync_status = 'FAILED' AND retry_count >= 10
      ''');
    }

    // -------------------------------------------------------------------------
    // v2 → v3: Add additional_category column to cached_payments
    // -------------------------------------------------------------------------
    if (oldVersion < 3) {
      try {
        batch.execute('ALTER TABLE cached_payments ADD COLUMN additional_category TEXT');
      } catch (_) {}
    }

    // -------------------------------------------------------------------------
    // v3 → v4: Add cached_office_tasks and cached_task_assignments
    // -------------------------------------------------------------------------
    if (oldVersion < 4) {
      batch.execute('''
        CREATE TABLE IF NOT EXISTS cached_office_tasks (
          id TEXT PRIMARY KEY,
          customer_id TEXT,
          customer_name TEXT NOT NULL,
          consumer_no TEXT NOT NULL,
          village TEXT,
          title TEXT NOT NULL,
          task_type TEXT NOT NULL,
          description TEXT,
          priority TEXT NOT NULL,
          status TEXT NOT NULL,
          due_date TEXT,
          assigned_to_id TEXT,
          assigned_to_name TEXT NOT NULL,
          created_by TEXT,
          created_by_name TEXT,
          started_at TEXT,
          completed_at TEXT,
          completion_note TEXT,
          hold_reason TEXT,
          attachment_url TEXT,
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL
        )
      ''');
      batch.execute('CREATE INDEX IF NOT EXISTS idx_cached_office_tasks_status ON cached_office_tasks(status)');
      batch.execute('CREATE INDEX IF NOT EXISTS idx_cached_office_tasks_assigned_to ON cached_office_tasks(assigned_to_name)');
      batch.execute('CREATE INDEX IF NOT EXISTS idx_cached_office_tasks_due_date ON cached_office_tasks(due_date)');

      batch.execute('''
        CREATE TABLE IF NOT EXISTS cached_task_assignments (
          id TEXT PRIMARY KEY,
          task_id TEXT NOT NULL,
          staff_id TEXT,
          staff_name TEXT NOT NULL,
          assigned_by TEXT,
          assigned_by_name TEXT,
          assigned_at TEXT NOT NULL,
          status TEXT NOT NULL,
          started_at TEXT,
          completed_at TEXT,
          remarks TEXT,
          created_at TEXT NOT NULL
        )
      ''');
      batch.execute('CREATE INDEX IF NOT EXISTS idx_cached_assign_task ON cached_task_assignments(task_id)');
    }

    // -------------------------------------------------------------------------
    // v4 -> v5: Add completed_by and completed_by_name to cached_office_tasks
    // -------------------------------------------------------------------------
    if (oldVersion < 5) {
      try {
        batch.execute('ALTER TABLE cached_office_tasks ADD COLUMN completed_by TEXT');
      } catch (_) {}
      try {
        batch.execute('ALTER TABLE cached_office_tasks ADD COLUMN completed_by_name TEXT');
      } catch (_) {}
    }

    // -------------------------------------------------------------------------
    // v5 → v6: loan_sanctioned_amount added to ConsumerRecord model.
    // Data is stored in raw_json, no ALTER TABLE needed.
    // Just mark a metadata note for debugging purposes.
    // -------------------------------------------------------------------------
    if (oldVersion < 6) {
      try {
        batch.execute(
          "INSERT OR REPLACE INTO sync_metadata (key, value) VALUES ('schema_v6_note', 'loan_sanctioned_amount added to model raw_json')",
        );
      } catch (_) {}
    }

    // -------------------------------------------------------------------------
    // v6 → v7: site_type added to cached_consumer_records and cached_leads.
    // -------------------------------------------------------------------------
    if (oldVersion < 7) {
      try {
        batch.execute("ALTER TABLE cached_consumer_records ADD COLUMN site_type TEXT DEFAULT 'Subsidy'");
      } catch (_) {}
      try {
        batch.execute('CREATE INDEX IF NOT EXISTS idx_cached_cr_site_type ON cached_consumer_records(site_type)');
      } catch (_) {}
      try {
        batch.execute("ALTER TABLE cached_leads ADD COLUMN site_type TEXT DEFAULT 'Subsidy'");
      } catch (_) {}
      try {
        batch.execute('CREATE INDEX IF NOT EXISTS idx_cached_leads_site_type ON cached_leads(site_type)');
      } catch (_) {}
    }

    await batch.commit(noResult: true);
    debugPrint('[AppDatabase] Upgrade complete (v$oldVersion → v$newVersion)');
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
      // Cap retries at 10 to prevent permanently-failing ops from looping forever.
      // Operations exceeding the cap are marked ABANDONED by the sync engine.
      where: "sync_status IN ('PENDING', 'FAILED') AND retry_count < 10",
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
        'site_type': record.siteType,
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
          'site_type': record.siteType,
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
    String? siteTypeFilter,
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

    if (siteTypeFilter != null && siteTypeFilter.isNotEmpty && siteTypeFilter != 'All') {
      whereClauses.add('site_type = ?');
      whereArgs.add(siteTypeFilter);
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
    String? siteTypeFilter,
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

    if (siteTypeFilter != null && siteTypeFilter.isNotEmpty && siteTypeFilter != 'All') {
      whereClauses.add('site_type = ?');
      whereArgs.add(siteTypeFilter);
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
  static Future<List<ConsumerRecord>> getAllConsumerRecords({String? siteTypeFilter}) async {
    final db = await database;
    final String? where = (siteTypeFilter != null && siteTypeFilter.isNotEmpty && siteTypeFilter != 'All')
        ? 'site_type = ?'
        : null;
    final List<dynamic>? whereArgs = (where != null) ? [siteTypeFilter] : null;
    final res = await db.query('cached_consumer_records', where: where, whereArgs: whereArgs, orderBy: 'last_modified_at DESC');
    return res.map((row) {
      return ConsumerRecord.fromJson(
        jsonDecode(row['raw_json'] as String) as Map<String, dynamic>,
      );
    }).toList();
  }

  /// Dashboard summary aggregated directly from offline database
  static Future<Map<String, dynamic>> getDashboardSummary({String siteType = 'Non-Subsidy'}) async {
    final db = await database;
    final isSubsidy = siteType.toLowerCase() == 'subsidy';
    final siteTypeWhere = isSubsidy
        ? "(site_type = 'Subsidy' OR site_type IS NULL OR site_type = '')"
        : "site_type = 'Non-Subsidy'";

    final customerRes = await db.rawQuery(
      "SELECT COUNT(*) as c FROM cached_consumer_records WHERE $siteTypeWhere",
    );
    final customerCount = Sqflite.firstIntValue(customerRes) ?? 0;

    // Completed Sites
    final completeWhere = isSubsidy
        ? "$siteTypeWhere AND (customer_work_state = 'COMPLETED' OR status = 'Completed' OR json_extract(raw_json, '\$.subsidy_status') = 'Received')"
        : "$siteTypeWhere AND (customer_work_state = 'COMPLETED' OR status = 'Completed' OR json_extract(raw_json, '\$.installation_status') = 'Installation Completed')";

    final completeRes = await db.rawQuery('''
      SELECT COUNT(*) as c FROM cached_consumer_records WHERE $completeWhere
    ''');
    final completedSites = Sqflite.firstIntValue(completeRes) ?? 0;

    final activeRes = await db.rawQuery('''
      SELECT COUNT(*) as c FROM cached_consumer_records 
      WHERE $siteTypeWhere AND customer_work_state != 'COMPLETED'
    ''');
    final active = Sqflite.firstIntValue(activeRes) ?? 0;

    // Payment Aggregates
    final paymentsRes = await db.rawQuery('''
      SELECT 
        SUM(COALESCE(json_extract(raw_json, '\$.total_amount'), 0)) as total_payment,
        SUM(COALESCE(json_extract(raw_json, '\$.paid_amount'), 0)) as paid_payment,
        SUM(COALESCE(json_extract(raw_json, '\$.pending_amount'), 0)) as pending_payment,
        COUNT(CASE WHEN COALESCE(json_extract(raw_json, '\$.pending_amount'), 0) > 0 THEN 1 END) as pending_customers
      FROM cached_consumer_records
      WHERE $siteTypeWhere
    ''');
    final totalPayment = (paymentsRes.first['total_payment'] as num?)?.toDouble() ?? 0.0;
    final paidPayment = (paymentsRes.first['paid_payment'] as num?)?.toDouble() ?? 0.0;
    final pendingPayment = (paymentsRes.first['pending_payment'] as num?)?.toDouble() ?? 0.0;
    final pendingPaymentCount = (paymentsRes.first['pending_customers'] as num?)?.toInt() ?? 0;

    // Tasks linked to customers of this site type
    final tasksRes = await db.rawQuery('''
      SELECT 
        COUNT(CASE WHEN status NOT IN ('Completed', 'Complete') THEN 1 END) as pending_tasks,
        COUNT(CASE WHEN status IN ('Completed', 'Complete') THEN 1 END) as completed_tasks
      FROM cached_office_tasks
      WHERE consumer_no IN (SELECT consumer_no FROM cached_consumer_records WHERE $siteTypeWhere)
         OR customer_id IN (SELECT id FROM cached_consumer_records WHERE $siteTypeWhere)
    ''');
    final pendingTasks = (tasksRes.first['pending_tasks'] as num?)?.toInt() ?? 0;
    final completedTasks = (tasksRes.first['completed_tasks'] as num?)?.toInt() ?? 0;

    return {
      'total': customerCount,
      'site_type': siteType,
      'active': active,
      'completed_sites': completedSites,
      'total_payment': totalPayment,
      'paid_payment': paidPayment,
      'pending_payment': pendingPayment,
      'pending_payment_count': pendingPaymentCount,
      'pending_tasks': pendingTasks,
      'completed_tasks': completedTasks,
    };
  }

  /// Get set of consumer numbers and IDs for a given site type
  static Future<Set<String>> getConsumerNosForSiteType([String siteType = 'Non-Subsidy']) async {
    final db = await database;
    final isSubsidy = siteType.toLowerCase() == 'subsidy';
    final siteTypeWhere = isSubsidy
        ? "(site_type = 'Subsidy' OR site_type IS NULL OR site_type = '')"
        : "site_type = 'Non-Subsidy'";
    final res = await db.rawQuery(
      "SELECT consumer_no, id FROM cached_consumer_records WHERE $siteTypeWhere",
    );
    final set = <String>{};
    for (final r in res) {
      final cNo = r['consumer_no']?.toString();
      final id = r['id']?.toString();
      if (cNo != null && cNo.isNotEmpty) set.add(cNo);
      if (id != null && id.isNotEmpty) set.add(id);
    }
    return set;
  }

  /// Backward-compatible alias
  static Future<Set<String>> getNonSubsidyConsumerNos() => getConsumerNosForSiteType('Non-Subsidy');

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
        'additional_category': tx.additionalCategory,
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
          'additional_category': tx.additionalCategory,
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
    String? typeFilter,
    String? categoryFilter,
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

    if (typeFilter != null && typeFilter != 'All') {
      if (typeFilter.toUpperCase() == 'CONTRACT') {
        whereClauses.add("(payment_type != 'ADDITIONAL' AND payment_type != 'Additional Payment')");
      } else if (typeFilter.toUpperCase() == 'ADDITIONAL' || typeFilter == PaymentType.additional) {
        whereClauses.add("(payment_type = 'ADDITIONAL' OR payment_type = 'Additional Payment')");
      } else {
        whereClauses.add('payment_type = ?');
        whereArgs.add(typeFilter);
      }
    }

    if (categoryFilter != null && categoryFilter != 'All') {
      whereClauses.add('additional_category = ?');
      whereArgs.add(categoryFilter);
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

    // 7. Contract & Additional Collections
    final contractRes = await db.rawQuery(
      "SELECT SUM(amount) as s FROM cached_payments WHERE payment_type != 'ADDITIONAL' AND payment_type != 'Additional Payment'",
    );
    final contractCollection = (contractRes.first['s'] as num?)?.toDouble() ?? 0.0;

    final addRes = await db.rawQuery(
      "SELECT SUM(amount) as s FROM cached_payments WHERE payment_type = 'ADDITIONAL' OR payment_type = 'Additional Payment'",
    );
    final additionalCollection = (addRes.first['s'] as num?)?.toDouble() ?? 0.0;

    return PaymentDashboardSummary(
      todayCollection: todayCollection,
      monthCollection: monthCollection,
      totalContractAmount: totalContract,
      totalPaidAmount: totalPaid,
      totalPendingAmount: totalPending,
      contractCollection: contractCollection,
      additionalCollection: additionalCollection,
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
        'site_type': lead.siteType,
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
  // OFFICE TASKS PERSISTENCE (OFFICE STAFF MY TASKS)
  // ===========================================================================

  static Future<void> upsertOfficeTasks(List<OfficeTask> tasks) async {
    final db = await database;
    final batch = db.batch();
    for (final t in tasks) {
      batch.insert(
        'cached_office_tasks',
        t.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  static Future<void> upsertOfficeTask(OfficeTask task) async {
    final db = await database;
    await db.insert(
      'cached_office_tasks',
      task.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  static Future<List<OfficeTask>> getCachedOfficeTasks({
    String? staffName,
    String? staffId,
    String? status,
    bool onlyPending = false,
    bool onlyCompleted = false,
  }) async {
    final db = await database;
    List<String> whereClauses = [];
    List<dynamic> whereArgs = [];

    if (staffId != null && staffId.isNotEmpty && staffName != null && staffName.isNotEmpty && staffName != 'ALL') {
      whereClauses.add('(assigned_to_id = ? OR assigned_to_name = ?)');
      whereArgs.add(staffId);
      whereArgs.add(staffName);
    } else if (staffId != null && staffId.isNotEmpty) {
      whereClauses.add('assigned_to_id = ?');
      whereArgs.add(staffId);
    } else if (staffName != null && staffName.isNotEmpty && staffName != 'ALL') {
      whereClauses.add('assigned_to_name = ?');
      whereArgs.add(staffName);
    }

    if (onlyPending) {
      whereClauses.add("status IN ('Pending', 'In Progress', 'Hold')");
    } else if (onlyCompleted) {
      whereClauses.add("status = 'Completed'");
    } else if (status != null && status.isNotEmpty && status != 'ALL') {
      whereClauses.add('status = ?');
      whereArgs.add(status);
    }

    final where = whereClauses.isNotEmpty ? whereClauses.join(' AND ') : null;

    final res = await db.query(
      'cached_office_tasks',
      where: where,
      whereArgs: whereArgs.isNotEmpty ? whereArgs : null,
      orderBy: 'created_at DESC',
    );

    return res.map((m) => OfficeTask.fromMap(m)).toList();
  }

  static Future<void> deleteCachedOfficeTask(String id) async {
    final db = await database;
    await db.delete(
      'cached_office_tasks',
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
    await db.delete('cached_office_tasks');
    await db.delete('cached_task_assignments');
    await db.delete('offline_operations_queue');
    await db.delete('sync_conflicts');
    await db.delete('sync_metadata');
  }
}
