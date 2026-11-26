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

  group('SUB VENDOR ACCOUNT DASHBOARD & PASSBOOK LEDGER (OPTION A) - 11 SCENARIO TEST SUITE', () {
    // -------------------------------------------------------------------------
    // Scenario 1: Material Outward automatically posts DEBIT (Passbook - Dr)
    // -------------------------------------------------------------------------
    test('Scenario 1: Material Outward automatically posts DEBIT (Passbook - Dr / recoverable increases)', () async {
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
      expect(entry.creditAmount, equals(0.0));
      expect(entry.debitAmount, equals(115000.0));
      expect(entry.runningBalance, equals(-115000.0)); // Negative = Dr Recoverable
      expect(entry.referenceNumber, equals(outward.outwardNumber));
    });

    // -------------------------------------------------------------------------
    // Scenario 2: Material Payment Received posts CREDIT (Passbook + Cr)
    // -------------------------------------------------------------------------
    test('Scenario 2: Material Payment Received posts CREDIT and offsets Debit outward', () async {
      // 1. Initial Outward Debit: ₹1,50,000
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

      // 2. Sub Vendor pays ₹1,00,000 via NEFT (Credit + Cr)
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

      expect(payment.creditAmount, equals(100000.0));
      expect(payment.debitAmount, equals(0.0));
      expect(payment.category, equals('MATERIAL'));

      // Check running balance: +1,00,000 Cr - 1,50,000 Dr = -50,000 Dr (Recoverable)
      final ledger = await SubVendorAccountLedgerService.fetchLedger(vendorId: 'vnd-001');
      expect(ledger.length, equals(2));

      final latest = ledger.first; // sorted newest first
      expect(latest.runningBalance, equals(-50000.0));
    });

    // -------------------------------------------------------------------------
    // Scenario 3: Advance Given posts DEBIT (Passbook - Dr)
    // -------------------------------------------------------------------------
    test('Scenario 3: Advance Given posts DEBIT and increases advance paid out', () async {
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
      expect(metrics.netBalance, equals(-30000.0));
      expect(metrics.isReceivable, isTrue);
    });

    // -------------------------------------------------------------------------
    // Scenario 4: Advance Refund Received posts CREDIT (Passbook + Cr)
    // -------------------------------------------------------------------------
    test('Scenario 4: Advance Refund Received posts CREDIT and reduces advance balance', () async {
      // 1. Advance given ₹40,000 (Dr)
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

      // 2. Refund received ₹15,000 (Cr)
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
      expect(metrics.netBalance, equals(-25000.0));
    });

    // -------------------------------------------------------------------------
    // Scenario 5: Running Balance calculation across multiple sequential transactions
    // -------------------------------------------------------------------------
    test('Scenario 5: Running Balance calculates accurately across sequential transactions', () async {
      // T1: Outward ₹2,00,000 (Dr) -> Balance = -2,00,000
      await SubVendorAccountLedgerService.recordTransaction(
        vendorId: 'vnd-001',
        vendorName: 'Shree Balaji Solar Works',
        transactionDate: DateTime(2026, 11, 10),
        transactionType: 'MATERIAL_OUTWARD',
        amount: 200000.0,
        referenceNumber: 'OUT-20261110-001',
        particulars: 'Material Outward 1',
      );

      // T2: Payment ₹80,000 (Cr) -> Balance = -1,20,000
      await SubVendorAccountLedgerService.recordTransaction(
        vendorId: 'vnd-001',
        vendorName: 'Shree Balaji Solar Works',
        transactionDate: DateTime(2026, 11, 12),
        transactionType: 'MATERIAL_PAYMENT',
        amount: 80000.0,
        referenceNumber: 'PAY-001',
        particulars: 'Payment 1',
      );

      // T3: Advance Given ₹20,000 (Dr) -> Balance = -1,40,000
      await SubVendorAccountLedgerService.recordTransaction(
        vendorId: 'vnd-001',
        vendorName: 'Shree Balaji Solar Works',
        transactionDate: DateTime(2026, 11, 15),
        transactionType: 'ADVANCE_GIVEN',
        amount: 20000.0,
        referenceNumber: 'ADV-001',
        particulars: 'Advance Given',
      );

      // T4: Advance Refund ₹10,000 (Cr) -> Balance = -1,30,000
      await SubVendorAccountLedgerService.recordTransaction(
        vendorId: 'vnd-001',
        vendorName: 'Shree Balaji Solar Works',
        transactionDate: DateTime(2026, 11, 18),
        transactionType: 'ADVANCE_REFUND',
        amount: 10000.0,
        referenceNumber: 'REF-001',
        particulars: 'Advance Refund',
      );

      // T5: Material Outward ₹50,000 (Dr) -> Balance = -1,80,000
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

      // Latest entry (T5) running balance should be exactly -1,80,000
      expect(ledger.first.runningBalance, equals(-180000.0));

      // Total Credit = 80,000 + 10,000 = 90,000
      // Total Debit = 2,00,000 + 20,000 + 50,000 = 2,70,000
      // Net Balance = 90,000 - 2,70,000 = -1,80,000
      final metrics = await SubVendorAccountLedgerService.fetchDashboardMetrics();
      expect(metrics.totalCredit, equals(90000.0));
      expect(metrics.totalDebit, equals(270000.0));
      expect(metrics.netBalance, equals(-180000.0));
    });

    // -------------------------------------------------------------------------
    // Scenario 6: Separate Material vs Advance classification under Passbook
    // -------------------------------------------------------------------------
    test('Scenario 6: Maintains separate Material and Advance category totals consistently', () async {
      // Material Outward ₹2,50,000 (Dr)
      await SubVendorAccountLedgerService.recordTransaction(
        vendorId: 'vnd-001',
        vendorName: 'Vendor A',
        transactionDate: DateTime(2026, 11, 1),
        transactionType: 'MATERIAL_OUTWARD',
        amount: 250000.0,
        referenceNumber: 'OUT-01',
        particulars: 'Material Outward',
      );

      // Material Payment ₹1,80,000 (Cr)
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

      // Total Credit = 1,80,000 + 10,000 = 1,90,000
      // Total Debit = 2,50,000 + 30,000 = 2,80,000
      // Net Balance = 1,90,000 - 2,80,000 = -90,000 (Dr = 70k material + 20k advance recoverable)
      expect(metrics.totalCredit, equals(190000.0));
      expect(metrics.totalDebit, equals(280000.0));
      expect(metrics.netBalance, equals(-90000.0));
    });

    // -------------------------------------------------------------------------
    // Scenario 7: Outward Cancellation removes Debit effect from ledger
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

      // Verify ledger has active 50,000 Dr
      var ledger = await SubVendorAccountLedgerService.fetchLedger(vendorId: 'vnd-001');
      expect(ledger.first.debitAmount, equals(50000.0));
      expect(ledger.first.creditAmount, equals(0.0));
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
      expect(metrics.totalDebit, equals(0.0));
      expect(metrics.netBalance, equals(0.0));
    });

    // -------------------------------------------------------------------------
    // Scenario 8: Live Dhanshree-style Passbook Metrics (Cr 3.4L, Dr 2,05,559.74 -> +1,34,440.26 Cr Payable)
    // -------------------------------------------------------------------------
    test('Scenario 8: Dashboard metrics match Passbook convention (Cr 3.4L, Dr 2,05,559.74 -> +1,34,440.26 Cr Payable)', () async {
      // Credit: Loans & Vendor Payments ₹3,40,000
      await SubVendorAccountLedgerService.recordTransaction(
        vendorId: 'vnd-001',
        vendorName: 'Dhanshree solar',
        transactionDate: DateTime(2026, 11, 20),
        transactionType: 'MATERIAL_PAYMENT',
        amount: 340000.0,
        referenceNumber: 'LOAN-PAY-1',
        particulars: 'Bank Loan & Direct Payments Received',
      );

      // Debit: Material Outwards ₹2,05,559.74
      await SubVendorAccountLedgerService.recordTransaction(
        vendorId: 'vnd-001',
        vendorName: 'Dhanshree solar',
        transactionDate: DateTime(2026, 11, 22),
        transactionType: 'MATERIAL_OUTWARD',
        amount: 205559.74,
        referenceNumber: 'OUT-20261126-0001',
        particulars: 'Material Outward Dispatch',
      );

      final metrics = await SubVendorAccountLedgerService.fetchDashboardMetrics();

      expect(metrics.totalCredit, equals(340000.0));
      expect(metrics.totalDebit, closeTo(205559.74, 0.01));
      expect(metrics.netBalance, closeTo(134440.26, 0.01));
      expect(metrics.netMaterialReceivable, closeTo(-134440.26, 0.01));
      expect(metrics.isPayable, isTrue);
      expect(metrics.isReceivable, isFalse);
    });

    // -------------------------------------------------------------------------
    // Scenario 9: Sub-Vendor-wise balance summary produces correct Payable vs Receivable flags
    // -------------------------------------------------------------------------
    test('Scenario 9: Sub-Vendor-wise balance summary classifies Payable (Cr) and Receivable (Dr)', () async {
      // Vendor 1: Credits ₹1,00,000 > Debits ₹40,000 -> +₹60,000 Cr Payable
      await SubVendorAccountLedgerService.recordTransaction(
        vendorId: 'vnd-001',
        vendorName: 'Vendor 1',
        transactionDate: DateTime(2026, 11, 1),
        transactionType: 'MATERIAL_PAYMENT',
        amount: 100000.0,
        referenceNumber: 'PAY-V1',
        particulars: 'V1 Receipts',
      );
      await SubVendorAccountLedgerService.recordTransaction(
        vendorId: 'vnd-001',
        vendorName: 'Vendor 1',
        transactionDate: DateTime(2026, 11, 5),
        transactionType: 'MATERIAL_OUTWARD',
        amount: 40000.0,
        referenceNumber: 'OUT-V1',
        particulars: 'V1 Outward',
      );

      // Vendor 2: Advance paid out ₹20,000 Dr -> -₹20,000 Dr Receivable
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
      expect(v1.netBalance, equals(60000.0));
      expect(v1.isPayable, isTrue);
      expect(v1.isReceivable, isFalse);

      final v2 = summaries.firstWhere((s) => s.vendorId == 'vnd-002');
      expect(v2.totalCredit, equals(0.0));
      expect(v2.totalDebit, equals(20000.0));
      expect(v2.netBalance, equals(-20000.0));
      expect(v2.isReceivable, isTrue);
      expect(v2.isPayable, isFalse);
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

    test('Scenario 11: Central merger includes Outwards, Site Materials, CRM/Loan Collections & Payouts with zero duplicates', () {
      const vendorId = 'vnd-central-1';
      const vendorName = 'Dhanshree solar';

      final manualEntries = [
        SubVendorAccountLedgerEntry(
          id: 'man-9319',
          vendorId: vendorId,
          vendorName: vendorName,
          transactionDate: DateTime(2026, 11, 24),
          transactionType: 'MATERIAL_PAYMENT',
          category: 'MATERIAL',
          creditAmount: 50000.0,
          debitAmount: 0.0,
          referenceNumber: '9319',
          paymentMode: 'Bank Transfer',
          particulars: 'Payments Received',
        ),
        SubVendorAccountLedgerEntry(
          id: 'man-3793',
          vendorId: vendorId,
          vendorName: vendorName,
          transactionDate: DateTime(2026, 11, 25),
          transactionType: 'MATERIAL_PAYMENT',
          category: 'MATERIAL',
          creditAmount: 50000.0,
          debitAmount: 0.0,
          referenceNumber: '3793',
          paymentMode: 'Bank Transfer',
          particulars: 'Payments Received',
        ),
      ];

      final rawOutwards = [
        {
          'id': 'out-uuid-1',
          'vendor_id': vendorId,
          'vendor_name': vendorName,
          'outward_date': '2026-11-22',
          'outward_number': 'OUT-20261126-0001',
          'total_items': 1,
          'total_quantity': 618.0,
          'total_value': 63809.74,
          'status': 'Active',
        },
      ];

      final siteMaterials = [
        VendorMaterialTransaction(
          id: 'vmt-uuid-1',
          assignmentId: 'asg-1',
          vendorId: vendorId,
          customerId: 'cust-1',
          transactionType: 'ISSUE',
          itemName: '550W Solar Panels',
          itemCategory: 'SOLAR_PANEL',
          quantity: 10,
          unitRate: 21924.0,
          taxableAmount: 219240.0,
          gstRate: 5.0,
          gstAmount: 10962.0,
          totalAmount: 230202.0,
          transactionDate: DateTime(2026, 11, 15),
        ),
      ];

      final assignments = [
        VendorSiteAssignment(
          id: 'asg-1',
          vendorId: vendorId,
          customerId: 'cust-1',
          customerName: 'Pandurang Kshirsagar',
          consumerNo: 'CONS-001',
          assignedDate: DateTime(2026, 11, 10),
          siteCapacityKw: 6.0,
          paymentType: 'Part Cash + Part Loan',
          totalCustomerSiteAmount: 611111.0,
          totalLoanCredited: 240000.0,
          totalCashReceived: 371111.0,
          totalCustomerReceived: 611111.0,
        ),
      ];

      final customerPayments = [
        VendorCustomerPayment(
          id: 'cp-uuid-loan',
          assignmentId: 'asg-1',
          vendorId: vendorId,
          customerId: 'cust-1',
          customerName: 'Pandurang Kshirsagar',
          paymentType: 'BANK_LOAN',
          paymentStage: 'LOAN_CREDIT',
          amount: 240000.0,
          paymentDate: DateTime(2026, 11, 20),
          paymentMode: 'Bank Transfer',
          referenceNumber: 'LOAN-UTR-240K',
          bankName: 'SBI',
          status: 'Approved',
        ),
      ];

      // Include one CRM payment matching cp-uuid-loan (must be deduplicated) and one separate cash CRM payment
      final crmPayments = [
        {
          'id': 'cpt-dup',
          'customer_id': 'cust-1',
          'amount': 240000.0,
          'payment_date': '2026-11-20',
          'payment_mode': 'Bank Transfer',
          'payment_type': '2nd Payment',
          'reference_number': 'LOAN-UTR-240K',
          'status': 'Valid',
          'deleted': false,
          'verification_status': 'Verified',
        },
        {
          'id': 'cpt-cash-1',
          'customer_id': 'cust-1',
          'amount': 371111.0,
          'payment_date': '2026-11-18',
          'payment_mode': 'Cash',
          'payment_type': '1st Payment',
          'reference_number': 'CASH-1',
          'status': 'Valid',
          'deleted': false,
          'verification_status': 'Verified',
        },
      ];

      final payouts = [
        VendorPayout(
          id: 'vp-uuid-1',
          vendorId: vendorId,
          vendorName: vendorName,
          payoutDate: DateTime(2026, 11, 21),
          amount: 10000.0,
          paymentMode: 'Bank Transfer',
          referenceNumber: 'PAYOUT-10K',
          status: 'Paid',
        ),
      ];

      // First merge (simulating fallback or partial 000049 view):
      final merged = SubVendorAccountLedgerService.mergeSupplementalLedgerEntries(
        baseEntries: manualEntries,
        vendorNameMap: {vendorId: vendorName},
        rawOutwards: rawOutwards,
        siteMaterials: siteMaterials,
        customerPayments: customerPayments,
        assignments: assignments,
        crmPaymentsRaw: crmPayments,
        payouts: payouts,
      );

      // Should contain:
      // 2 manual payments (50k + 50k)
      // + 1 outward (63,809.74)
      // + 1 site material (2,30,202)
      // + 1 bank loan cp (2,40,000)
      // + 1 CRM cash payment cpt-cash-1 (3,71,111) -- cpt-dup skipped & a_coll residual is 0!
      // + 1 vendor payout vp-uuid-1 (10,000)
      // = 7 entries
      expect(merged.length, equals(7));
      expect(merged.any((e) => e.id == 'mo_out-uuid-1'), isTrue);
      expect(merged.any((e) => e.id == 'vmt_vmt-uuid-1'), isTrue);
      expect(merged.any((e) => e.id == 'cp_cp-uuid-loan'), isTrue);
      expect(merged.any((e) => e.id.startsWith('cpt_cpt-cash-1_')), isTrue);
      expect(merged.any((e) => e.id.startsWith('cpt_cpt-dup_')), isFalse);
      expect(merged.any((e) => e.id == 'a_coll_asg-1'), isFalse);

      // Re-running merge on already unified rows must yield exact same 7 entries (0 duplicates)
      final secondPass = SubVendorAccountLedgerService.mergeSupplementalLedgerEntries(
        baseEntries: merged,
        vendorNameMap: {vendorId: vendorName},
        rawOutwards: rawOutwards,
        siteMaterials: siteMaterials,
        customerPayments: customerPayments,
        assignments: assignments,
        crmPaymentsRaw: crmPayments,
        payouts: payouts,
      );
      expect(secondPass.length, equals(7));

      final double totCr = merged.fold(0.0, (s, e) => s + e.creditAmount);
      final double totDr = merged.fold(0.0, (s, e) => s + e.debitAmount);
      // Passbook Option A:
      // Credits (+ Cr): 1,00,000 manual + 2,40,000 bank loan + 3,71,111 CRM cash = 7,11,111.00
      // Debits  (- Dr): 63,809.74 outward + 2,30,202.00 site material + 10,000 payout = 3,04,011.74
      expect(totCr, closeTo(711111.0, 0.01));
      expect(totDr, closeTo(304011.74, 0.01));

      // Verify clear semantic typeLabel badges
      expect(merged.firstWhere((e) => e.id == 'mo_out-uuid-1').typeLabel, equals('Material Outward'));
      expect(merged.firstWhere((e) => e.id == 'vmt_vmt-uuid-1').typeLabel, equals('Site Material Given'));
      expect(merged.firstWhere((e) => e.id == 'cp_cp-uuid-loan').typeLabel, equals('Bank Loan Credited'));
      expect(merged.firstWhere((e) => e.id.startsWith('cpt_cpt-cash-1_')).typeLabel, equals('Customer Payment'));
      expect(merged.firstWhere((e) => e.id == 'vp_vp-uuid-1').typeLabel, equals('Vendor Payout'));
      expect(merged.firstWhere((e) => e.id == 'man-9319').typeLabel, equals('Payment Received'));
    });
  });
}
