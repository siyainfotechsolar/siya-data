import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:mobile_app/models/customer_payment.dart';
import 'package:mobile_app/models/consumer_record.dart';
import 'package:mobile_app/services/app_database.dart';
import 'package:mobile_app/services/payment_service.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('Additional Payments Support & Strict Separation Tests', () {
    test('1. Exact User Prompt Accounting: Additional does NOT reduce Contract Pending', () {
      // Contract Amount = ₹1,90,000
      const contractAmount = 190000.0;

      // Contract Payments: ₹50,000 (UPI) + ₹70,000 (Cash) = ₹1,20,000
      final tx1 = PaymentTransaction(
        id: 'tx_c1',
        customerId: 'cust_001',
        consumerNo: '096590002001',
        amount: 50000.0,
        paymentDate: DateTime(2026, 9, 15),
        paymentType: PaymentType.contract,
        paymentMode: PaymentMode.upi,
        remarks: 'Contract Advance',
      );

      final tx2 = PaymentTransaction(
        id: 'tx_c2',
        customerId: 'cust_001',
        consumerNo: '096590002001',
        amount: 70000.0,
        paymentDate: DateTime(2026, 9, 18),
        paymentType: PaymentType.contract,
        paymentMode: PaymentMode.cash,
        remarks: 'Contract Stage 2',
      );

      // Additional Payments: Extra Work ₹10,000 + Transport ₹5,000 = ₹15,000
      final tx3 = PaymentTransaction(
        id: 'tx_a1',
        customerId: 'cust_001',
        consumerNo: '096590002001',
        amount: 10000.0,
        paymentDate: DateTime(2026, 9, 19),
        paymentType: PaymentType.additional,
        additionalCategory: AdditionalPaymentCategory.extraWork,
        paymentMode: PaymentMode.upi,
        remarks: 'Extra civil foundation work',
      );

      final tx4 = PaymentTransaction(
        id: 'tx_a2',
        customerId: 'cust_001',
        consumerNo: '096590002001',
        amount: 5000.0,
        paymentDate: DateTime(2026, 9, 19),
        paymentType: PaymentType.additional,
        additionalCategory: AdditionalPaymentCategory.transport,
        paymentMode: PaymentMode.cash,
        remarks: 'Special transport charges',
      );

      final summary = CustomerPaymentSummary.calculate(
        totalAmount: contractAmount,
        transactions: [tx1, tx2, tx3, tx4],
      );

      // Strict assertions matching the user prompt:
      // Contract Amount = ₹1,90,000
      // Contract Paid = ₹1,20,000
      // Contract Pending = ₹70,000
      // Additional Total = ₹15,000
      // Total Received = ₹1,35,000
      // Contract Pending strictly remains ₹70,000!
      expect(summary.contractAmount, equals(190000.0));
      expect(summary.contractPaid, equals(120000.0));
      expect(summary.contractPending, equals(70000.0));
      expect(summary.additionalPaid, equals(15000.0));
      expect(summary.totalReceived, equals(135000.0));
      expect(summary.isPartiallyPaid, isTrue);
      expect(summary.isPaid, isFalse);
    });

    test('2. CustomerPaymentRow handles backwards compatibility & totalReceived', () {
      final row = CustomerPaymentRow(
        customerId: 'cust_001',
        customerName: 'Suresh Patil',
        consumerNo: '096590002001',
        totalAmount: 190000.0,
        paidAmount: 120000.0,
        pendingAmount: 70000.0,
        additionalPaid: 15000.0,
        paymentStatus: 'Partially Paid',
      );

      expect(row.totalAmount, equals(190000.0));
      expect(row.paidAmount, equals(120000.0));
      expect(row.pendingAmount, equals(70000.0));
      expect(row.additionalPaid, equals(15000.0));
      expect(row.totalReceived, equals(135000.0));
    });

    test('3. Additional categories mapping and icons', () {
      expect(AdditionalPaymentCategory.allCategories, contains(AdditionalPaymentCategory.extraMaterial));
      expect(AdditionalPaymentCategory.allCategories, contains(AdditionalPaymentCategory.extraWork));
      expect(AdditionalPaymentCategory.allCategories, contains(AdditionalPaymentCategory.additionalInstallation));
      expect(AdditionalPaymentCategory.allCategories, contains(AdditionalPaymentCategory.transport));
      expect(AdditionalPaymentCategory.allCategories, contains(AdditionalPaymentCategory.serviceCharge));
      expect(AdditionalPaymentCategory.allCategories, contains(AdditionalPaymentCategory.other));

      expect(AdditionalPaymentCategory.displayName(AdditionalPaymentCategory.extraMaterial), equals('Extra Material'));
      expect(AdditionalPaymentCategory.displayName(AdditionalPaymentCategory.transport), equals('Transport'));
      expect(AdditionalPaymentCategory.displayName(AdditionalPaymentCategory.serviceCharge), equals('Service Charge'));
    });
  });

  group('Offline SQLite Additional Payments & Dashboard Aggregations', () {
    late Database db;

    setUp(() async {
      db = await databaseFactoryFfi.openDatabase(
        inMemoryDatabasePath,
        options: OpenDatabaseOptions(
          version: 3,
          onCreate: (db, version) async {
            await db.execute('''
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

            await db.execute('''
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

            await db.execute('''
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

            await db.execute('''
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
          },
        ),
      );
      AppDatabase.setTestDatabase(db);
    });

    tearDown(() async {
      await db.close();
    });

    test('Upserts Contract and Additional payments, filters, and computes collections', () async {
      final now = DateTime.now();

      // 1. Insert customer record (Contract: 1,90,000, Paid: 1,20,000, Pending: 70,000)
      final cust = ConsumerRecord(
        id: 'cust_offline_1',
        consumerNo: '096590002002',
        name: 'Sunil Jagtap',
        totalAmount: 190000.0,
        paidAmount: 120000.0,
        pendingAmount: 70000.0,
        customerWorkState: 'ACTIVE',
      );
      await AppDatabase.upsertConsumerRecord(cust);

      // 2. Insert Contract Payment ₹1,20,000
      final txContract = PaymentTransaction(
        id: 'ptx_c_101',
        clientTxId: 'ptx_c_101',
        idempotencyKey: 'idem_c_101',
        customerId: 'cust_offline_1',
        consumerNo: '096590002002',
        amount: 120000.0,
        paymentDate: now,
        paymentType: PaymentType.contract,
        paymentMode: PaymentMode.bankTransfer,
        referenceNumber: 'NEFT123456',
        syncStatus: 'Synced',
      );
      await AppDatabase.upsertPayment(txContract, syncStatus: 'Synced');

      // 3. Insert Additional Payment 1: Extra Work ₹10,000
      final txExtraWork = PaymentTransaction(
        id: 'ptx_a_102',
        clientTxId: 'ptx_a_102',
        idempotencyKey: 'idem_a_102',
        customerId: 'cust_offline_1',
        consumerNo: '096590002002',
        amount: 10000.0,
        paymentDate: now,
        paymentType: PaymentType.additional,
        additionalCategory: AdditionalPaymentCategory.extraWork,
        paymentMode: PaymentMode.upi,
        referenceNumber: 'UPI998877',
        syncStatus: 'Synced',
      );
      await AppDatabase.upsertPayment(txExtraWork, syncStatus: 'Synced');

      // 4. Insert Additional Payment 2: Transport ₹5,000
      final txTransport = PaymentTransaction(
        id: 'ptx_a_103',
        clientTxId: 'ptx_a_103',
        idempotencyKey: 'idem_a_103',
        customerId: 'cust_offline_1',
        consumerNo: '096590002002',
        amount: 5000.0,
        paymentDate: now,
        paymentType: PaymentType.additional,
        additionalCategory: AdditionalPaymentCategory.transport,
        paymentMode: PaymentMode.cash,
        syncStatus: 'Pending Sync',
      );
      await AppDatabase.upsertPayment(txTransport, syncStatus: 'Pending Sync');

      // 5. Test Filters:
      // All payments
      final all = await AppDatabase.getAllPayments();
      expect(all.length, equals(3));

      // Filter by Type = CONTRACT
      final contractPayments = await AppDatabase.getAllPayments(typeFilter: 'CONTRACT');
      expect(contractPayments.length, equals(1));
      expect(contractPayments.first.amount, equals(120000.0));

      // Filter by Type = ADDITIONAL
      final additionalPayments = await AppDatabase.getAllPayments(typeFilter: 'ADDITIONAL');
      expect(additionalPayments.length, equals(2));

      // Filter by Category = EXTRA_WORK
      final extraWorkPayments = await AppDatabase.getAllPayments(categoryFilter: AdditionalPaymentCategory.extraWork);
      expect(extraWorkPayments.length, equals(1));
      expect(extraWorkPayments.first.amount, equals(10000.0));

      // 6. Test Dashboard Summary Calculation:
      final summary = await AppDatabase.getPaymentDashboardSummary();
      expect(summary.contractCollection, equals(120000.0));
      expect(summary.additionalCollection, equals(15000.0));
      expect(summary.totalReceivedAmount, equals(135000.0));
      expect(summary.totalPendingAmount, equals(70000.0));
      expect(summary.todayCollection, equals(135000.0));
      expect(summary.pendingSyncCount, equals(1)); // txTransport is Pending Sync
    });
  });
}
