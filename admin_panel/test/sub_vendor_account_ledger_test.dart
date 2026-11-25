import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:siya_shared/siya_shared.dart';
import 'package:admin_panel/services/sub_vendor_account_ledger_service.dart';
import 'package:admin_panel/services/sub_vendor_material_outward_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    SubVendorMaterialOutwardService.resetInMemoryDataForTesting();
    SubVendorAccountLedgerService.resetInMemoryDataForTesting();
  });

  group('SUB VENDOR ACCOUNT DASHBOARD & CREDIT/DEBIT LEDGER - 10 SCENARIO TEST SUITE', () {
    // -------------------------------------------------------------------------
    // Scenario 1: Material Outward automatically posts CREDIT to Sub Vendor Ledger
    // -------------------------------------------------------------------------
    test('Scenario 1: Material Outward automatically posts CREDIT (receivable increases)', () async {
      final materials = await SubVendorMaterialOutwardService.fetchMaterialMaster();
      final panelMat = materials.firstWhere((m) => m.category == 'PANEL'); // defaultRate: 11,500

      // Issue 10 panels = 10 * 11,500 = ₹1,15,000
      final outward = await SubVendorMaterialOutwardService.recordOutward(
        vendorId: 'vnd-001',
        vendorName: 'Shree Balaji Solar Works',
        outwardDate: DateTime(2026, 11, 25),
        remarks: 'Panel Dispatch 10 units',
        items: [
          SubVendorMaterialOutwardItem(
            id: '',
            outwardId: '',
            materialId: panelMat.id,
            materialName: panelMat.itemName,
            unit: panelMat.unit,
            quantity: 10.0,
            unitRate: panelMat.defaultRate,
            totalPrice: 10.0 * panelMat.defaultRate,
          ),
        ],
      );

      expect(outward.totalValue, equals(115000.0));

      final ledger = await SubVendorAccountLedgerService.fetchLedger(vendorId: 'vnd-001');
      expect(ledger.length, equals(1));

      final entry = ledger.first;
      expect(entry.transactionType, equals('MATERIAL_OUTWARD'));
      expect(entry.category, equals('MATERIAL'));
      expect(entry.creditAmount, equals(115000.0));
      expect(entry.debitAmount, equals(0.0));
      expect(entry.runningBalance, equals(115000.0)); // Positive = Receivable
      expect(entry.referenceNumber, equals(outward.outwardNumber));
    });

    // -------------------------------------------------------------------------
    // Scenario 2: Material Payment Received posts DEBIT and reduces receivable
    // -------------------------------------------------------------------------
    test('Scenario 2: Material Payment Received posts DEBIT and reduces receivable', () async {
      // 1. Initial Outward Credit: ₹1,50,000
      await SubVendorAccountLedgerService.syncOutwardToLedger(
        SubVendorMaterialOutward(
          id: 'out-101',
          outwardNumber: 'OUT-20261125-1001',
          vendorId: 'vnd-001',
          vendorName: 'Shree Balaji Solar Works',
          outwardDate: DateTime(2026, 11, 20),
          totalItems: 1,
          totalQuantity: 10,
          totalValue: 150000.0,
          status: 'Active',
          items: const [],
        ),
      );

      // 2. Sub Vendor pays ₹1,00,000 via NEFT
      final payment = await SubVendorAccountLedgerService.recordTransaction(
        vendorId: 'vnd-001',
        vendorName: 'Shree Balaji Solar Works',
        transactionDate: DateTime(2026, 11, 25),
        transactionType: 'MATERIAL_PAYMENT',
        amount: 100000.0,
        referenceNumber: 'UTR-HDFC-9823412',
        paymentMode: 'Bank Transfer (NEFT)',
        particulars: 'Part Payment for Solar Panels received from Sub Vendor',
      );

      expect(payment.creditAmount, equals(0.0));
      expect(payment.debitAmount, equals(100000.0));
      expect(payment.category, equals('MATERIAL'));

      // Check running balance: 1,50,000 Cr - 1,00,000 Dr = 50,000 Cr (Receivable)
      final ledger = await SubVendorAccountLedgerService.fetchLedger(vendorId: 'vnd-001');
      expect(ledger.length, equals(2));

      final latest = ledger.first; // sorted newest first
      expect(latest.runningBalance, equals(50000.0));
    });

    // -------------------------------------------------------------------------
    // Scenario 3: Advance Given posts DEBIT and increases advance balance payable
    // -------------------------------------------------------------------------
    test('Scenario 3: Advance Given posts DEBIT and increases advance balance', () async {
      final advance = await SubVendorAccountLedgerService.recordTransaction(
        vendorId: 'vnd-002',
        vendorName: 'Omkar Solar EPC',
        transactionDate: DateTime(2026, 11, 22),
        transactionType: 'ADVANCE_GIVEN',
        amount: 30000.0,
        referenceNumber: 'ADV-VND-002-1',
        paymentMode: 'UPI',
        particulars: 'Site Mobilization Advance Given',
      );

      expect(advance.category, equals('ADVANCE'));
      expect(advance.debitAmount, equals(30000.0));
      expect(advance.creditAmount, equals(0.0));

      final metrics = await SubVendorAccountLedgerService.fetchDashboardMetrics();
      expect(metrics.totalAdvanceGiven, equals(30000.0));
      expect(metrics.netAdvanceBalance, equals(30000.0));
    });

    // -------------------------------------------------------------------------
    // Scenario 4: Advance Refund Received posts CREDIT and reduces advance balance
    // -------------------------------------------------------------------------
    test('Scenario 4: Advance Refund Received posts CREDIT and reduces advance balance', () async {
      // 1. Advance given ₹40,000
      await SubVendorAccountLedgerService.recordTransaction(
        vendorId: 'vnd-002',
        vendorName: 'Omkar Solar EPC',
        transactionDate: DateTime(2026, 11, 20),
        transactionType: 'ADVANCE_GIVEN',
        amount: 40000.0,
        referenceNumber: 'ADV-VND-002-2',
        paymentMode: 'Cheque',
        particulars: 'Security Deposit Given',
      );

      // 2. Refund received ₹15,000
      final refund = await SubVendorAccountLedgerService.recordTransaction(
        vendorId: 'vnd-002',
        vendorName: 'Omkar Solar EPC',
        transactionDate: DateTime(2026, 11, 25),
        transactionType: 'ADVANCE_REFUND',
        amount: 15000.0,
        referenceNumber: 'REF-VND-002-1',
        paymentMode: 'Bank Transfer',
        particulars: 'Security Deposit Refund Received',
      );

      expect(refund.category, equals('ADVANCE'));
      expect(refund.creditAmount, equals(15000.0));
      expect(refund.debitAmount, equals(0.0));

      final metrics = await SubVendorAccountLedgerService.fetchDashboardMetrics();
      expect(metrics.totalAdvanceGiven, equals(40000.0));
      expect(metrics.totalAdvanceRefund, equals(15000.0));
      expect(metrics.netAdvanceBalance, equals(25000.0)); // 40,000 - 15,000 = 25,000
    });

    // -------------------------------------------------------------------------
    // Scenario 5: Running Balance calculation across multiple sequential transactions
    // -------------------------------------------------------------------------
    test('Scenario 5: Running Balance calculates accurately across sequential transactions', () async {
      // T1: Outward ₹2,00,000 (Cr) -> Balance = +2,00,000
      await SubVendorAccountLedgerService.recordTransaction(
        vendorId: 'vnd-001',
        vendorName: 'Shree Balaji Solar Works',
        transactionDate: DateTime(2026, 11, 10),
        transactionType: 'MATERIAL_OUTWARD',
        amount: 200000.0,
        referenceNumber: 'OUT-20261110-001',
        particulars: 'Material Outward 1',
      );

      // T2: Payment ₹80,000 (Dr) -> Balance = +1,20,000
      await SubVendorAccountLedgerService.recordTransaction(
        vendorId: 'vnd-001',
        vendorName: 'Shree Balaji Solar Works',
        transactionDate: DateTime(2026, 11, 12),
        transactionType: 'MATERIAL_PAYMENT',
        amount: 80000.0,
        referenceNumber: 'PAY-001',
        particulars: 'Payment 1',
      );

      // T3: Advance Given ₹20,000 (Dr) -> Balance = +1,00,000
      await SubVendorAccountLedgerService.recordTransaction(
        vendorId: 'vnd-001',
        vendorName: 'Shree Balaji Solar Works',
        transactionDate: DateTime(2026, 11, 15),
        transactionType: 'ADVANCE_GIVEN',
        amount: 20000.0,
        referenceNumber: 'ADV-001',
        particulars: 'Advance Given',
      );

      // T4: Advance Refund ₹10,000 (Cr) -> Balance = +1,10,000
      await SubVendorAccountLedgerService.recordTransaction(
        vendorId: 'vnd-001',
        vendorName: 'Shree Balaji Solar Works',
        transactionDate: DateTime(2026, 11, 18),
        transactionType: 'ADVANCE_REFUND',
        amount: 10000.0,
        referenceNumber: 'REF-001',
        particulars: 'Advance Refund',
      );

      // T5: Material Outward ₹50,000 (Cr) -> Balance = +1,60,000
      await SubVendorAccountLedgerService.recordTransaction(
        vendorId: 'vnd-001',
        vendorName: 'Shree Balaji Solar Works',
        transactionDate: DateTime(2026, 11, 20),
        transactionType: 'MATERIAL_OUTWARD',
        amount: 50000.0,
        referenceNumber: 'OUT-20261120-002',
        particulars: 'Material Outward 2',
      );

      final ledger = await SubVendorAccountLedgerService.fetchLedger(vendorId: 'vnd-001');
      expect(ledger.length, equals(5));

      // Latest entry (T5) running balance should be exactly 1,60,000
      expect(ledger.first.runningBalance, equals(160000.0));

      // Total Credit = 2,00,000 + 10,000 + 50,000 = 2,60,000
      // Total Debit = 80,000 + 20,000 = 1,00,000
      // Net Balance = 2,60,000 - 1,00,000 = 1,60,000
      final metrics = await SubVendorAccountLedgerService.fetchDashboardMetrics();
      expect(metrics.totalCredit, equals(260000.0));
      expect(metrics.totalDebit, equals(100000.0));
      expect(metrics.netBalance, equals(160000.0));
    });

    // -------------------------------------------------------------------------
    // Scenario 6: Separate Material Receivable vs Advance Payable classification
    // -------------------------------------------------------------------------
    test('Scenario 6: Maintains separate Material Receivable and Advance Payable balances', () async {
      // Material Outward ₹2,50,000 (Cr)
      await SubVendorAccountLedgerService.recordTransaction(
        vendorId: 'vnd-001',
        vendorName: 'Vendor A',
        transactionDate: DateTime(2026, 11, 1),
        transactionType: 'MATERIAL_OUTWARD',
        amount: 250000.0,
        referenceNumber: 'OUT-01',
        particulars: 'Material Outward',
      );

      // Material Payment ₹1,80,000 (Dr)
      await SubVendorAccountLedgerService.recordTransaction(
        vendorId: 'vnd-001',
        vendorName: 'Vendor A',
        transactionDate: DateTime(2026, 11, 5),
        transactionType: 'MATERIAL_PAYMENT',
        amount: 180000.0,
        referenceNumber: 'PAY-01',
        particulars: 'Material Payment',
      );

      // Advance Given ₹30,000 (Dr)
      await SubVendorAccountLedgerService.recordTransaction(
        vendorId: 'vnd-001',
        vendorName: 'Vendor A',
        transactionDate: DateTime(2026, 11, 10),
        transactionType: 'ADVANCE_GIVEN',
        amount: 30000.0,
        referenceNumber: 'ADV-01',
        particulars: 'Advance Given',
      );

      // Advance Refund ₹10,000 (Cr)
      await SubVendorAccountLedgerService.recordTransaction(
        vendorId: 'vnd-001',
        vendorName: 'Vendor A',
        transactionDate: DateTime(2026, 11, 12),
        transactionType: 'ADVANCE_REFUND',
        amount: 10000.0,
        referenceNumber: 'REF-01',
        particulars: 'Advance Refund',
      );

      final metrics = await SubVendorAccountLedgerService.fetchDashboardMetrics();

      // Material balances
      expect(metrics.totalMaterialOutward, equals(250000.0));
      expect(metrics.totalMaterialPayment, equals(180000.0));
      expect(metrics.netMaterialReceivable, equals(70000.0)); // 2,50,000 - 1,80,000 = 70,000

      // Advance balances
      expect(metrics.totalAdvanceGiven, equals(30000.0));
      expect(metrics.totalAdvanceRefund, equals(10000.0));
      expect(metrics.netAdvanceBalance, equals(20000.0)); // 30,000 - 10,000 = 20,000

      // Total Credit = 2,50,000 + 10,000 = 2,60,000
      // Total Debit = 1,80,000 + 30,000 = 2,10,000
      // Net Balance = 2,60,000 - 2,10,000 = 50,000
      expect(metrics.totalCredit, equals(260000.0));
      expect(metrics.totalDebit, equals(210000.0));
      expect(metrics.netBalance, equals(50000.0));
    });

    // -------------------------------------------------------------------------
    // Scenario 7: Outward Cancellation removes Credit effect from ledger
    // -------------------------------------------------------------------------
    test('Scenario 7: Outward cancellation marks ledger entry as Cancelled and reverses effect', () async {
      final materials = await SubVendorMaterialOutwardService.fetchMaterialMaster();
      final panelMat = materials.firstWhere((m) => m.category == 'PANEL');

      // 1. Record Outward
      final outward = await SubVendorMaterialOutwardService.recordOutward(
        vendorId: 'vnd-001',
        vendorName: 'Shree Balaji Solar Works',
        outwardDate: DateTime(2026, 11, 20),
        remarks: 'Temporary test outward',
        items: [
          SubVendorMaterialOutwardItem(
            id: '',
            outwardId: '',
            materialId: panelMat.id,
            materialName: panelMat.itemName,
            unit: panelMat.unit,
            quantity: 5.0,
            unitRate: 10000.0,
            totalPrice: 50000.0,
          ),
        ],
      );

      // Verify ledger has active 50,000 Cr
      var ledger = await SubVendorAccountLedgerService.fetchLedger(vendorId: 'vnd-001');
      expect(ledger.first.creditAmount, equals(50000.0));
      expect(ledger.first.status, equals('Active'));

      // 2. Cancel the Outward
      await SubVendorMaterialOutwardService.cancelOutward(
        outward.id,
        reason: 'Client order cancelled',
      );

      // Verify ledger entry is marked Cancelled and running balance is 0
      ledger = await SubVendorAccountLedgerService.fetchLedger(vendorId: 'vnd-001', statusFilter: 'All');
      final cancelledEntry = ledger.firstWhere((e) => e.referenceNumber == outward.outwardNumber);
      expect(cancelledEntry.status, equals('Cancelled'));

      final metrics = await SubVendorAccountLedgerService.fetchDashboardMetrics();
      expect(metrics.totalMaterialOutward, equals(0.0));
      expect(metrics.totalCredit, equals(0.0));
      expect(metrics.netBalance, equals(0.0));
    });

    // -------------------------------------------------------------------------
    // Scenario 8: Dashboard Metrics match exact figures from prompt specification
    // -------------------------------------------------------------------------
    test('Scenario 8: Dashboard metrics match prompt example (Total Cr: 2.5L, Dr: 1.8L, Net: 70k)', () async {
      // Credit: Material Outward ₹2,50,000
      await SubVendorAccountLedgerService.recordTransaction(
        vendorId: 'vnd-001',
        vendorName: 'Vendor Test',
        transactionDate: DateTime(2026, 11, 1),
        transactionType: 'MATERIAL_OUTWARD',
        amount: 250000.0,
        referenceNumber: 'OUT-SAMPLE-1',
        particulars: 'Prompt sample outward',
      );

      // Debit: Material Payment ₹1,80,000
      await SubVendorAccountLedgerService.recordTransaction(
        vendorId: 'vnd-001',
        vendorName: 'Vendor Test',
        transactionDate: DateTime(2026, 11, 15),
        transactionType: 'MATERIAL_PAYMENT',
        amount: 180000.0,
        referenceNumber: 'PAY-SAMPLE-1',
        particulars: 'Prompt sample payment',
      );

      final metrics = await SubVendorAccountLedgerService.fetchDashboardMetrics();

      expect(metrics.totalCredit, equals(250000.0));
      expect(metrics.totalDebit, equals(180000.0));
      expect(metrics.netBalance, equals(70000.0));
      expect(metrics.netMaterialReceivable, equals(70000.0));
      expect(metrics.isReceivable, isTrue);
      expect(metrics.isPayable, isFalse);
    });

    // -------------------------------------------------------------------------
    // Scenario 9: Sub-Vendor-wise balance summary produces correct breakdown
    // -------------------------------------------------------------------------
    test('Scenario 9: Sub-Vendor-wise balance summary produces correct breakdown', () async {
      // Vendor 1: Net receivable ₹60,000
      await SubVendorAccountLedgerService.recordTransaction(
        vendorId: 'vnd-001',
        vendorName: 'Vendor 1',
        transactionDate: DateTime(2026, 11, 1),
        transactionType: 'MATERIAL_OUTWARD',
        amount: 100000.0,
        referenceNumber: 'OUT-V1',
        particulars: 'V1 Outward',
      );
      await SubVendorAccountLedgerService.recordTransaction(
        vendorId: 'vnd-001',
        vendorName: 'Vendor 1',
        transactionDate: DateTime(2026, 11, 5),
        transactionType: 'MATERIAL_PAYMENT',
        amount: 40000.0,
        referenceNumber: 'PAY-V1',
        particulars: 'V1 Payment',
      );

      // Vendor 2: Net advance payable ₹20,000 (Dr > Cr)
      await SubVendorAccountLedgerService.recordTransaction(
        vendorId: 'vnd-002',
        vendorName: 'Vendor 2',
        transactionDate: DateTime(2026, 11, 10),
        transactionType: 'ADVANCE_GIVEN',
        amount: 20000.0,
        referenceNumber: 'ADV-V2',
        particulars: 'V2 Advance',
      );

      final summaries = await SubVendorAccountLedgerService.fetchSubVendorBalances();
      expect(summaries.length, equals(2));

      final v1 = summaries.firstWhere((s) => s.vendorId == 'vnd-001');
      expect(v1.totalCredit, equals(100000.0));
      expect(v1.totalDebit, equals(40000.0));
      expect(v1.netBalance, equals(60000.0)); // Receivable
      expect(v1.isReceivable, isTrue);

      final v2 = summaries.firstWhere((s) => s.vendorId == 'vnd-002');
      expect(v2.totalCredit, equals(0.0));
      expect(v2.totalDebit, equals(20000.0));
      expect(v2.netBalance, equals(-20000.0)); // Payable
      expect(v2.isPayable, isTrue);
    });

    // -------------------------------------------------------------------------
    // Scenario 10: Filtering ledger entries by date, category, and search query
    // -------------------------------------------------------------------------
    test('Scenario 10: Filtering ledger entries by date, category, type, and search query', () async {
      await SubVendorAccountLedgerService.recordTransaction(
        vendorId: 'vnd-001',
        vendorName: 'Vendor A',
        transactionDate: DateTime(2026, 11, 5),
        transactionType: 'MATERIAL_OUTWARD',
        amount: 50000.0,
        referenceNumber: 'OUT-SEARCH-ALPHA',
        particulars: 'Inverter Dispatch',
      );
      await SubVendorAccountLedgerService.recordTransaction(
        vendorId: 'vnd-001',
        vendorName: 'Vendor A',
        transactionDate: DateTime(2026, 11, 15),
        transactionType: 'MATERIAL_PAYMENT',
        amount: 30000.0,
        referenceNumber: 'PAY-SEARCH-BETA',
        particulars: 'Bank Transfer UTR-888',
      );
      await SubVendorAccountLedgerService.recordTransaction(
        vendorId: 'vnd-001',
        vendorName: 'Vendor A',
        transactionDate: DateTime(2026, 11, 20),
        transactionType: 'ADVANCE_GIVEN',
        amount: 10000.0,
        referenceNumber: 'ADV-SEARCH-GAMMA',
        particulars: 'Advance Cash',
      );

      final all = await SubVendorAccountLedgerService.fetchLedger(vendorId: 'vnd-001');
      expect(all.length, equals(3));

      // Category Filter: ADVANCE
      final advanceOnly = SubVendorAccountLedgerService.filterLedgerEntries(
        all,
        categoryFilter: 'ADVANCE',
      );
      expect(advanceOnly.length, equals(1));
      expect(advanceOnly.first.referenceNumber, equals('ADV-SEARCH-GAMMA'));

      // Date Range Filter: 11 Nov to 25 Nov
      final dateFiltered = SubVendorAccountLedgerService.filterLedgerEntries(
        all,
        fromDate: DateTime(2026, 11, 10),
        toDate: DateTime(2026, 11, 25),
      );
      expect(dateFiltered.length, equals(2));

      // Search Query Filter
      final searched = SubVendorAccountLedgerService.filterLedgerEntries(
        all,
        searchQuery: 'UTR-888',
      );
      expect(searched.length, equals(1));
      expect(searched.first.referenceNumber, equals('PAY-SEARCH-BETA'));
    });
  });
}
