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

  group('Intelligent Payment Calculations & Milestones', () {
    test('Calculates balance and paid percentage correctly', () {
      const summary = CustomerPaymentSummary(
        totalAmount: 190000.0,
        paidAmount: 120000.0,
        pendingAmount: 70000.0,
        paymentStatus: PaymentStatus.partiallyPaid,
      );

      expect(summary.isPartiallyPaid, isTrue);
      expect(summary.isPaid, isFalse);
      expect(summary.paidPercentage, closeTo(63.15, 0.1));
    });

    test('Installation milestone rule triggers follow-up when shortfall exists', () {
      // Customer has contract of 100,000, paid 40,000 (40%), current stage: Panel (requires 60%)
      final customer = ConsumerRecord(
        id: 'cust_test_1',
        consumerNo: '096590001608',
        name: 'Ganesh Shinde',
        totalAmount: 100000.0,
        paidAmount: 40000.0,
        pendingAmount: 60000.0,
        installationStatus: 'Panel Installation',
      );

      final milestone = PaymentService.evaluateMilestone(customer);

      expect(milestone.isMilestoneSatisfied, isFalse);
      expect(milestone.shortfallAmount, equals(20000.0)); // 60,000 required - 40,000 paid = 20,000 shortfall
      expect(milestone.actionRecommendation, contains('FOLLOW-UP REQUIRED'));
    });

    test('Installation milestone rule approves when target percentage is met', () {
      // Customer has contract of 100,000, paid 70,000 (70%), current stage: Panel (requires 60%)
      final customer = ConsumerRecord(
        id: 'cust_test_2',
        consumerNo: '096590001609',
        name: 'Ramesh Patil',
        totalAmount: 100000.0,
        paidAmount: 70000.0,
        pendingAmount: 30000.0,
        installationStatus: 'Panel Installation',
      );

      final milestone = PaymentService.evaluateMilestone(customer);

      expect(milestone.isMilestoneSatisfied, isTrue);
      expect(milestone.shortfallAmount, equals(0.0));
      expect(milestone.actionRecommendation, contains('PAYMENT CLEAR'));
    });
  });

  group('Offline SQLite Payment Database & Dashboard Summary', () {
    late Database db;

    setUp(() async {
      db = await databaseFactoryFfi.openDatabase(
        inMemoryDatabasePath,
        options: OpenDatabaseOptions(
          version: 1,
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
                site_type TEXT DEFAULT 'Subsidy',
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
          },
        ),
      );
      AppDatabase.setTestDatabase(db);
    });

    tearDown(() async {
      await db.close();
    });

    test('Upserts payment, searches offline, and computes dashboard summary', () async {
      final now = DateTime.now();

      // 1. Insert test customer record into cached_consumer_records
      final cust = ConsumerRecord(
        id: 'cust_abc',
        consumerNo: '096590001610',
        name: 'Vijay Deshmukh',
        totalAmount: 200000.0,
        paidAmount: 50000.0,
        pendingAmount: 150000.0,
        customerWorkState: 'ACTIVE',
      );
      await AppDatabase.upsertConsumerRecord(cust);

      // 2. Insert offline payment transaction
      final tx = PaymentTransaction(
        id: 'ptx_test_101',
        clientTxId: 'ptx_test_101',
        idempotencyKey: 'idem_test_101',
        customerId: 'cust_abc',
        consumerNo: '096590001610',
        amount: 25000.0,
        paymentDate: now,
        paymentMode: PaymentMode.upi,
        referenceNumber: 'UPI789123456',
        syncStatus: 'Pending Sync',
        verificationStatus: PaymentVerificationStatus.pending,
      );
      await AppDatabase.upsertPayment(tx, syncStatus: 'Pending Sync');

      // 3. Search payments offline
      final searchResults = await AppDatabase.searchPaymentsOffline('UPI789');
      expect(searchResults.length, equals(1));
      expect(searchResults.first.amount, equals(25000.0));
      expect(searchResults.first.referenceNumber, equals('UPI789123456'));

      // 4. Test offline dashboard aggregate computation
      final summary = await AppDatabase.getPaymentDashboardSummary();
      expect(summary.todayCollection, equals(25000.0));
      expect(summary.todayPaymentsCount, equals(1));
      expect(summary.pendingSyncCount, equals(1));
      expect(summary.totalContractAmount, equals(200000.0));
      expect(summary.unverifiedPaymentsCount, equals(1));

      // 5. Test idempotency: upserting same payment replaces without duplicating
      await AppDatabase.upsertPayment(tx, syncStatus: 'Synced');
      final all = await AppDatabase.getAllPayments();
      expect(all.length, equals(1));
    });

    test('Updates payment verification status in local cache', () async {
      final now = DateTime.now();
      final tx = PaymentTransaction(
        id: 'ptx_ver_1',
        clientTxId: 'ptx_ver_1',
        idempotencyKey: 'idem_ver_1',
        customerId: 'cust_xyz',
        consumerNo: '096590001611',
        amount: 30000.0,
        paymentDate: now,
        paymentMode: PaymentMode.bankTransfer,
        referenceNumber: 'NEFT998877',
        syncStatus: 'Synced',
      );
      await AppDatabase.upsertPayment(tx, syncStatus: 'Synced');

      // Verify payment
      await AppDatabase.updatePaymentVerification(
        'ptx_ver_1',
        PaymentVerificationStatus.verified,
        remarks: 'Confirmed in bank statement',
        staffName: 'Admin Rahul',
      );

      final payments = await AppDatabase.getCustomerPayments('cust_xyz');
      expect(payments.first.verificationStatus, equals(PaymentVerificationStatus.verified));
      expect(payments.first.verificationRemarks, equals('Confirmed in bank statement'));
      expect(payments.first.verifiedByName, equals('Admin Rahul'));
    });
  });
}
