import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:siya_shared/siya_shared.dart';
import 'package:admin_panel/services/sub_vendor_account_ledger_pdf_service.dart';
import 'package:admin_panel/services/sub_vendor_account_ledger_service.dart';
import 'package:admin_panel/services/sub_vendor_material_outward_pdf_service.dart';
import 'package:admin_panel/services/sub_vendor_material_outward_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    SubVendorMaterialOutwardService.resetInMemoryDataForTesting();
    SubVendorAccountLedgerService.resetInMemoryDataForTesting();
  });

  group('SUB VENDOR COMPLETE E2E CALCULATION AUDIT - 14 SCENARIO TEST SUITE', () {
    const v1Id = 'vnd-audit-001';
    const v1Name = 'Dhanshree Solar Energy';
    const v1Code = 'SIYA-VND-001';

    const v2Id = 'vnd-audit-002';
    const v2Name = 'Surya Shakti Contractors';
    const v2Code = 'SIYA-VND-002';

    // -------------------------------------------------------------------------
    // Scenario 1: One Material Outward Entry (decimal qty & rate, non-stock deduction)
    // -------------------------------------------------------------------------
    test('Scenario 1: Single material outward entry calculates exact base, GST, grand total & posts Debit without deducting inventory', () async {
      final master = await SubVendorMaterialOutwardService.fetchMaterialMaster();
      final panel = master.firstWhere((m) => m.category == 'PANEL');
      final stockBefore = panel.availableStock;

      // 2.5 units * 1234.55 = 3086.375 -> 3086.38 base; 5% GST = 154.319 -> 154.32; final = 3240.70
      final outward = await SubVendorMaterialOutwardService.recordOutward(
        vendorId: v1Id,
        vendorName: v1Name,
        outwardDate: DateTime(2026, 11, 10),
        remarks: 'Scenario 1 dispatch',
        items: [
          SubVendorMaterialOutwardItem(
            id: '',
            outwardId: '',
            materialId: panel.id,
            materialName: panel.itemName,
            unit: 'NOS',
            quantity: 2.5,
            unitRate: 1234.55,
            gstPercentage: 5.0,
          ),
        ],
      );

      expect(outward.subtotal, equals(3086.38));
      expect(outward.totalGst, equals(154.32));
      expect(outward.totalValue, equals(3240.70));

      // Stock untouched
      final masterAfter = await SubVendorMaterialOutwardService.fetchMaterialMaster();
      expect(masterAfter.firstWhere((m) => m.id == panel.id).availableStock, equals(stockBefore));

      // Ledger synchronized with exact DEBIT under Standard Passbook convention
      final ledger = await SubVendorAccountLedgerService.fetchLedger(vendorId: v1Id);
      expect(ledger.length, equals(1));
      expect(ledger.first.transactionType, equals('MATERIAL_OUTWARD'));
      expect(ledger.first.creditAmount, equals(0.0));
      expect(ledger.first.debitAmount, equals(3240.70));
      expect(ledger.first.runningBalance, equals(-3240.70)); // Dr recoverable
    });

    // -------------------------------------------------------------------------
    // Scenario 2: Multiple Materials with different GST rates (5%, 18%, 0%)
    // -------------------------------------------------------------------------
    test('Scenario 2: Multi-GST outward rows (5%, 18%, 0%) & Site ITC classification preserve 0% and isItcEligible', () async {
      final outward = await SubVendorMaterialOutwardService.recordOutward(
        vendorId: v1Id,
        vendorName: v1Name,
        outwardDate: DateTime(2026, 11, 12),
        items: const [
          SubVendorMaterialOutwardItem(
            id: '',
            outwardId: '',
            materialName: 'Solar Panel 585W',
            unit: 'NOS',
            quantity: 6,
            unitRate: 15000.0,
            gstPercentage: 5.0,
          ),
          SubVendorMaterialOutwardItem(
            id: '',
            outwardId: '',
            materialName: 'ACDB/DCDB + LA Kit',
            unit: 'SET',
            quantity: 2,
            unitRate: 2500.0,
            gstPercentage: 18.0,
          ),
          SubVendorMaterialOutwardItem(
            id: '',
            outwardId: '',
            materialName: 'Chemical Earthing Kit',
            unit: 'SET',
            quantity: 2,
            unitRate: 100.0,
            gstPercentage: 0.0,
          ),
        ],
      );

      // Row 1: 90,000 + 4,500 = 94,500
      // Row 2:  5,000 +   900 =  5,900
      // Row 3:    200 +     0 =    200
      expect(outward.subtotal, equals(95200.0));
      expect(outward.totalGst, equals(5400.0));
      expect(outward.totalValue, equals(100600.0));
      expect(outward.items[2].gstPercentage, equals(0.0));
      expect(outward.items[2].gstAmount, equals(0.0));

      // Verify site material classifier respects 0% and isItcEligible: false
      final siteMats = [
        VendorMaterialTransaction.create(
          assignmentId: 'a-1',
          vendorId: v1Id,
          customerId: 'c-1',
          transactionType: 'ISSUE',
          itemName: '5% Panels',
          itemCategory: 'SOLAR_PANEL',
          quantity: 6,
          unitRate: 15000.0,
          isItcEligible: true,
        ),
        VendorMaterialTransaction.create(
          assignmentId: 'a-1',
          vendorId: v1Id,
          customerId: 'c-1',
          transactionType: 'ISSUE',
          itemName: 'Exempt Consumable',
          itemCategory: 'OTHER',
          gstRate: 0.0,
          quantity: 1,
          unitRate: 500.0,
          isItcEligible: false,
        ),
        VendorMaterialTransaction.create(
          assignmentId: 'a-1',
          vendorId: v1Id,
          customerId: 'c-1',
          transactionType: 'ISSUE',
          itemName: 'Unregistered 18% BOS',
          itemCategory: 'BOS',
          gstRate: 18.0,
          quantity: 1,
          unitRate: 1000.0,
          isItcEligible: false,
        ),
      ];

      final breakdown = SubVendorFinancialEngine.classifySiteMaterialsGst(siteMats);
      expect(breakdown.material5Total, equals(94500.0));
      expect(breakdown.material18Total, equals(1180.0));
      expect(breakdown.otherAndZeroTotal, equals(500.0));
      expect(breakdown.totalEligibleInputGst, equals(4500.0)); // Only ITC-eligible 5% GST counts
      expect(breakdown.totalIneligibleInputGst, equals(180.0));
      expect(breakdown.totalMaterialCost, equals(96180.0));
    });

    // -------------------------------------------------------------------------
    // Scenario 3: Multiple Outward Entries on Different Dates & Indian FY/Timezone boundary
    // -------------------------------------------------------------------------
    test('Scenario 3: Multiple outward dates reconcile Daily, Monthly & Indian FY (Apr-Mar) including UTC boundaries', () async {
      // FY 2025-26: March 31, 2026 (late UTC evening local calendar equivalence test)
      await SubVendorMaterialOutwardService.recordOutward(
        vendorId: v1Id,
        vendorName: v1Name,
        outwardDate: DateTime(2026, 3, 31),
        items: const [
          SubVendorMaterialOutwardItem(
            id: '', outwardId: '', materialName: 'Panel', unit: 'NOS', quantity: 2, unitRate: 10000.0, gstPercentage: 5.0,
          ),
        ],
      );
      // FY 2026-27: April 1, 2026 & April 15, 2026
      await SubVendorMaterialOutwardService.recordOutward(
        vendorId: v1Id,
        vendorName: v1Name,
        outwardDate: DateTime(2026, 4, 1),
        items: const [
          SubVendorMaterialOutwardItem(
            id: '', outwardId: '', materialName: 'Inverter', unit: 'NOS', quantity: 1, unitRate: 20000.0, gstPercentage: 5.0,
          ),
        ],
      );
      await SubVendorMaterialOutwardService.recordOutward(
        vendorId: v1Id,
        vendorName: v1Name,
        outwardDate: DateTime(2026, 4, 15),
        items: const [
          SubVendorMaterialOutwardItem(
            id: '', outwardId: '', materialName: 'Structure', unit: 'SET', quantity: 1, unitRate: 10000.0, gstPercentage: 18.0,
          ),
        ],
      );

      final allRaw = await SubVendorMaterialOutwardService.fetchOutwards();
      final all = SubVendorMaterialOutwardService.filterOutwards(allRaw, vendorId: v1Id);
      final filteredApr = SubVendorMaterialOutwardService.filterOutwards(
        allRaw,
        vendorId: v1Id,
        fromDate: DateTime(2026, 4, 1),
        toDate: DateTime(2026, 4, 15),
      );
      expect(filteredApr.length, equals(2));

      final fyPeriods = SubVendorMaterialOutwardService.generatePeriodSummary(all, grouping: 'FINANCIAL_YEAR');
      expect(fyPeriods.length, equals(2));
      expect(fyPeriods.firstWhere((p) => p.periodKey == 'FY 2026-27').grandTotal, equals(21000.0 + 11800.0));
      expect(fyPeriods.firstWhere((p) => p.periodKey == 'FY 2025-26').grandTotal, equals(21000.0));

      final monthly = SubVendorMaterialOutwardService.generatePeriodSummary(all, grouping: 'MONTHLY');
      expect(monthly.firstWhere((p) => p.periodKey == '2026-04').grandTotal, equals(32800.0));
      expect(monthly.firstWhere((p) => p.periodKey == '2026-03').grandTotal, equals(21000.0));
    });

    // -------------------------------------------------------------------------
    // Scenarios 4 & 5: Partial & Full Material Payment Received
    // -------------------------------------------------------------------------
    test('Scenarios 4 & 5: Partial and Full Material Payment Received update Material Receivable & Passbook cleanly', () async {
      await SubVendorMaterialOutwardService.recordOutward(
        vendorId: v1Id,
        vendorName: v1Name,
        outwardDate: DateTime(2026, 11, 1),
        items: const [
          SubVendorMaterialOutwardItem(
            id: '', outwardId: '', materialName: 'Panels', unit: 'NOS', quantity: 10, unitRate: 10000.0, gstPercentage: 5.0,
          ),
        ],
      ); // Debit: ₹1,05,000

      // Scenario 4: Partial Material Payment = ₹40,000 Credit
      await SubVendorAccountLedgerService.recordTransaction(
        vendorId: v1Id,
        vendorName: v1Name,
        transactionDate: DateTime(2026, 11, 5),
        transactionType: 'MATERIAL_PAYMENT',
        amount: 40000.0,
        referenceNumber: 'UTR-PART-001',
        particulars: 'Partial payment via NEFT',
      );

      var metrics = await SubVendorAccountLedgerService.calculateDashboardMetrics();
      expect(metrics.totalMaterialOutwardValue, equals(105000.0));
      expect(metrics.totalMaterialPaymentsReceived, equals(40000.0));
      expect(metrics.netMaterialReceivable, equals(65000.0)); // 105,000 - 40,000 receivable
      expect(metrics.netBalance, equals(-65000.0)); // Passbook Dr balance

      // Scenario 5: Remaining Full Material Payment = ₹65,000 Credit
      await SubVendorAccountLedgerService.recordTransaction(
        vendorId: v1Id,
        vendorName: v1Name,
        transactionDate: DateTime(2026, 11, 10),
        transactionType: 'MATERIAL_PAYMENT',
        amount: 65000.0,
        referenceNumber: 'UTR-FULL-002',
        particulars: 'Remaining full payment',
      );

      metrics = await SubVendorAccountLedgerService.calculateDashboardMetrics();
      expect(metrics.totalMaterialOutwardValue, equals(105000.0));
      expect(metrics.totalMaterialPaymentsReceived, equals(105000.0));
      expect(metrics.netMaterialReceivable, equals(0.0));
      expect(metrics.netBalance, equals(0.0));
    });

    // -------------------------------------------------------------------------
    // Scenarios 6, 7 & 8: Advance Given, Partial Advance Refund, Full Advance Refund
    // -------------------------------------------------------------------------
    test('Scenarios 6, 7 & 8: Advance Given, Partial Refund & Full Refund stay strictly separate from Material Receivable', () async {
      // Scenario 6: Advance Given = ₹50,000 (Debit)
      await SubVendorAccountLedgerService.recordTransaction(
        vendorId: v1Id,
        vendorName: v1Name,
        transactionDate: DateTime(2026, 11, 2),
        transactionType: 'ADVANCE_GIVEN',
        amount: 50000.0,
        referenceNumber: 'ADV-PAY-001',
        particulars: 'Site mobilization advance',
      );

      var metrics = await SubVendorAccountLedgerService.calculateDashboardMetrics();
      expect(metrics.totalAdvanceGiven, equals(50000.0));
      expect(metrics.totalAdvanceRefundReceived, equals(0.0));
      expect(metrics.netAdvanceBalance, equals(50000.0));
      expect(metrics.netMaterialReceivable, equals(0.0)); // Isolated!

      // Scenario 7: Partial Advance Refund = ₹20,000 (Credit)
      await SubVendorAccountLedgerService.recordTransaction(
        vendorId: v1Id,
        vendorName: v1Name,
        transactionDate: DateTime(2026, 11, 6),
        transactionType: 'ADVANCE_REFUND',
        amount: 20000.0,
        referenceNumber: 'ADV-REF-001',
        particulars: 'Partial security refund',
      );

      metrics = await SubVendorAccountLedgerService.calculateDashboardMetrics();
      expect(metrics.totalAdvanceGiven, equals(50000.0));
      expect(metrics.totalAdvanceRefundReceived, equals(20000.0));
      expect(metrics.netAdvanceBalance, equals(30000.0));
      expect(metrics.netBalance, equals(-30000.0));

      // Scenario 8: Full remaining Advance Refund = ₹30,000 (Credit)
      await SubVendorAccountLedgerService.recordTransaction(
        vendorId: v1Id,
        vendorName: v1Name,
        transactionDate: DateTime(2026, 11, 10),
        transactionType: 'ADVANCE_REFUND',
        amount: 30000.0,
        referenceNumber: 'ADV-REF-002',
        particulars: 'Final advance closure refund',
      );

      metrics = await SubVendorAccountLedgerService.calculateDashboardMetrics();
      expect(metrics.totalAdvanceGiven, equals(50000.0));
      expect(metrics.totalAdvanceRefundReceived, equals(50000.0));
      expect(metrics.netAdvanceBalance, equals(0.0));
      expect(metrics.netBalance, equals(0.0));
    });

    // -------------------------------------------------------------------------
    // Scenario 9: Edit an Outward Transaction (updates original & syncs ledger without duplicates)
    // -------------------------------------------------------------------------
    test('Scenario 9: Editing an outward transaction updates original record, reports & mirrored ledger entry atomically', () async {
      final created = await SubVendorMaterialOutwardService.recordOutward(
        vendorId: v1Id,
        vendorName: v1Name,
        outwardDate: DateTime(2026, 11, 10),
        items: const [
          SubVendorMaterialOutwardItem(
            id: '', outwardId: '', materialName: 'Wire', unit: 'METER', quantity: 100, unitRate: 40.0, gstPercentage: 18.0,
          ),
        ],
      ); // 4000 + 720 = 4720 Debit

      // Add a subsequent credit so we verify running balance recalculation chronologically
      await SubVendorAccountLedgerService.recordTransaction(
        vendorId: v1Id,
        vendorName: v1Name,
        transactionDate: DateTime(2026, 11, 12),
        transactionType: 'MATERIAL_PAYMENT',
        amount: 5000.0,
        referenceNumber: 'UTR-EDIT-CHECK',
        particulars: 'Payment after dispatch',
      );

      // Edit outward quantity from 100 to 150 -> base 6000 + 18% GST 1080 = 7080
      final updated = await SubVendorMaterialOutwardService.updateOutward(
        outwardId: created.id,
        vendorId: v1Id,
        vendorName: v1Name,
        outwardDate: DateTime(2026, 11, 10),
        remarks: 'Updated qty to 150',
        items: const [
          SubVendorMaterialOutwardItem(
            id: '', outwardId: '', materialName: 'Wire', unit: 'METER', quantity: 150, unitRate: 40.0, gstPercentage: 18.0,
          ),
        ],
      );

      expect(updated.totalValue, equals(7080.0));
      final activeLedger = await SubVendorAccountLedgerService.fetchLedger(vendorId: v1Id, statusFilter: 'Active');
      expect(activeLedger.length, equals(2)); // Still 2 entries (no duplicate row!)
      expect(activeLedger.firstWhere((e) => e.transactionType == 'MATERIAL_OUTWARD').debitAmount, equals(7080.0));

      final metrics = await SubVendorAccountLedgerService.calculateDashboardMetrics();
      expect(metrics.totalMaterialOutwardValue, equals(7080.0));
      expect(metrics.totalMaterialPaymentsReceived, equals(5000.0));
      expect(metrics.netMaterialReceivable, equals(2080.0));
      expect(metrics.netBalance, equals(-2080.0));
    });

    // -------------------------------------------------------------------------
    // Scenario 10: Cancel a Payment & Reject Duplicate UTR
    // -------------------------------------------------------------------------
    test('Scenario 10: Cancelling a payment reverses its balance impact while preserving audit log; duplicate UTR is blocked', () async {
      await SubVendorMaterialOutwardService.recordOutward(
        vendorId: v1Id,
        vendorName: v1Name,
        outwardDate: DateTime(2026, 11, 1),
        items: const [
          SubVendorMaterialOutwardItem(
            id: '', outwardId: '', materialName: 'Panels', unit: 'NOS', quantity: 10, unitRate: 10000.0, gstPercentage: 0.0,
          ),
        ],
      ); // Debit: ₹1,00,000

      final pay = await SubVendorAccountLedgerService.recordTransaction(
        vendorId: v1Id,
        vendorName: v1Name,
        transactionDate: DateTime(2026, 11, 3),
        transactionType: 'MATERIAL_PAYMENT',
        amount: 35000.0,
        referenceNumber: 'UTR-UNIQ-999',
        particulars: 'Bank Payment',
      );

      // Duplicate UTR must be rejected on active transaction
      expect(
        () => SubVendorAccountLedgerService.recordTransaction(
          vendorId: v1Id,
          vendorName: v1Name,
          transactionDate: DateTime(2026, 11, 4),
          transactionType: 'MATERIAL_PAYMENT',
          amount: 35000.0,
          referenceNumber: 'utr-uniq-999', // Case-insensitive check
          particulars: 'Accidental double entry',
        ),
        throwsA(isA<Exception>()),
      );

      // Cancel payment -> reverts net balance back to -1,00,000 Dr
      await SubVendorAccountLedgerService.cancelTransaction(pay.id, reason: 'Cheque bounced');

      final metrics = await SubVendorAccountLedgerService.calculateDashboardMetrics();
      expect(metrics.totalMaterialPaymentsReceived, equals(0.0));
      expect(metrics.netMaterialReceivable, equals(100000.0));
      expect(metrics.netBalance, equals(-100000.0));

      // Audit history preserved under status='All'
      final allHistory = await SubVendorAccountLedgerService.fetchLedger(vendorId: v1Id, statusFilter: 'All');
      expect(allHistory.any((e) => e.id == pay.id && e.isCancelled), isTrue);
    });

    // -------------------------------------------------------------------------
    // Scenario 11: Multiple Sub Vendors (sum of individuals == Dashboard total)
    // -------------------------------------------------------------------------
    test('Scenario 11: Individual Sub Vendor balances strictly sum to overall Dashboard totals across vendors', () async {
      final vendors = [
        const SubVendor(id: v1Id, vendorCode: v1Code, name: v1Name, mobile: '9999999991', email: 'v1@test.com'),
        const SubVendor(id: v2Id, vendorCode: v2Code, name: v2Name, mobile: '9999999992', email: 'v2@test.com'),
      ];

      // Vendor 1: Outward 1,05,000 + Payment 1,50,000 + Advance 10,000 => Net +35,000 Cr
      await SubVendorMaterialOutwardService.recordOutward(
        vendorId: v1Id,
        vendorName: v1Name,
        outwardDate: DateTime(2026, 11, 1),
        items: const [
          SubVendorMaterialOutwardItem(id: '', outwardId: '', materialName: 'Kit', unit: 'NOS', quantity: 1, unitRate: 100000.0, gstPercentage: 5.0),
        ],
      );
      await SubVendorAccountLedgerService.recordTransaction(
        vendorId: v1Id, vendorName: v1Name, transactionDate: DateTime(2026, 11, 2),
        transactionType: 'MATERIAL_PAYMENT', amount: 150000.0, referenceNumber: 'V1-PAY', particulars: 'Loan credit',
      );
      await SubVendorAccountLedgerService.recordTransaction(
        vendorId: v1Id, vendorName: v1Name, transactionDate: DateTime(2026, 11, 3),
        transactionType: 'ADVANCE_GIVEN', amount: 10000.0, referenceNumber: 'V1-ADV', particulars: 'Advance',
      );

      // Vendor 2: Outward 59,000 + Payment 20,000 + Advance 5,000 - Refund 2,000 => Net -42,000 Dr
      await SubVendorMaterialOutwardService.recordOutward(
        vendorId: v2Id,
        vendorName: v2Name,
        outwardDate: DateTime(2026, 11, 1),
        items: const [
          SubVendorMaterialOutwardItem(id: '', outwardId: '', materialName: 'BOS', unit: 'SET', quantity: 1, unitRate: 50000.0, gstPercentage: 18.0),
        ],
      );
      await SubVendorAccountLedgerService.recordTransaction(
        vendorId: v2Id, vendorName: v2Name, transactionDate: DateTime(2026, 11, 2),
        transactionType: 'MATERIAL_PAYMENT', amount: 20000.0, referenceNumber: 'V2-PAY', particulars: 'Cash',
      );
      await SubVendorAccountLedgerService.recordTransaction(
        vendorId: v2Id, vendorName: v2Name, transactionDate: DateTime(2026, 11, 3),
        transactionType: 'ADVANCE_GIVEN', amount: 5000.0, referenceNumber: 'V2-ADV', particulars: 'Adv given',
      );
      await SubVendorAccountLedgerService.recordTransaction(
        vendorId: v2Id, vendorName: v2Name, transactionDate: DateTime(2026, 11, 4),
        transactionType: 'ADVANCE_REFUND', amount: 2000.0, referenceNumber: 'V2-REF', particulars: 'Adv refund',
      );

      final overall = await SubVendorAccountLedgerService.calculateDashboardMetrics(preloadedVendors: vendors);
      final sumCredit = SubVendorFinancialEngine.sumPaise(overall.vendorBalances, (v) => v.totalCredit);
      final sumDebit = SubVendorFinancialEngine.sumPaise(overall.vendorBalances, (v) => v.totalDebit);
      final sumNet = SubVendorFinancialEngine.sumPaise(overall.vendorBalances, (v) => v.netBalance);
      final sumMatRec = SubVendorFinancialEngine.sumPaise(overall.vendorBalances, (v) => v.materialReceivable);
      final sumAdvBal = SubVendorFinancialEngine.sumPaise(overall.vendorBalances, (v) => v.advanceBalance);

      expect(overall.totalCredit, equals(sumCredit));
      expect(overall.totalDebit, equals(sumDebit));
      expect(overall.netBalance, equals(sumNet)); // 35,000 + (-42,000) = -7,000.00
      expect(overall.netMaterialReceivable, equals(sumMatRec));
      expect(overall.netAdvanceBalance, equals(sumAdvBal));
    });

    // -------------------------------------------------------------------------
    // Scenario 12: Filtered Date Reports + Opening + Credit - Debit == Closing
    // -------------------------------------------------------------------------
    test('Scenario 12: Filtered ledger preserves exact Opening Balance and report totals reconcile across Daily/Monthly/FY views', () async {
      await SubVendorMaterialOutwardService.recordOutward(
        vendorId: v1Id, vendorName: v1Name, outwardDate: DateTime(2026, 10, 20),
        items: const [
          SubVendorMaterialOutwardItem(id: '', outwardId: '', materialName: 'Panels', unit: 'NOS', quantity: 5, unitRate: 10000.0, gstPercentage: 5.0),
        ],
      ); // Oct: -52,500 Dr
      await SubVendorAccountLedgerService.recordTransaction(
        vendorId: v1Id, vendorName: v1Name, transactionDate: DateTime(2026, 11, 5),
        transactionType: 'MATERIAL_PAYMENT', amount: 60000.0, referenceNumber: 'NOV-PAY-1', particulars: 'Nov Receipt',
      ); // Nov: +60,000 Cr
      await SubVendorMaterialOutwardService.recordOutward(
        vendorId: v1Id, vendorName: v1Name, outwardDate: DateTime(2026, 11, 12),
        items: const [
          SubVendorMaterialOutwardItem(id: '', outwardId: '', materialName: 'Earthing', unit: 'SET', quantity: 2, unitRate: 1000.0, gstPercentage: 18.0),
        ],
      ); // Nov: -2,360 Dr

      final fromNov = DateTime(2026, 11, 1);
      final toNov = DateTime(2026, 11, 30);
      final openingBal = SubVendorAccountLedgerService.calculateOpeningBalance(vendorId: v1Id, fromDate: fromNov);
      final novMetrics = await SubVendorAccountLedgerService.calculateDashboardMetrics(fromDate: fromNov, toDate: toNov);

      expect(openingBal, equals(-52500.0));
      expect(novMetrics.totalCredit, equals(60000.0));
      expect(novMetrics.totalDebit, equals(2360.0));
      expect(SubVendorFinancialEngine.round2(openingBal + novMetrics.totalCredit - novMetrics.totalDebit), equals(5140.0));

      // Outward Reports cross-check (Date-wise vs Vendor-wise vs Material-wise vs Monthly)
      final allRawOutwards = await SubVendorMaterialOutwardService.fetchOutwards();
      final allOutwards = SubVendorMaterialOutwardService.filterOutwards(allRawOutwards, vendorId: v1Id);
      final dateRows = SubVendorMaterialOutwardService.generateDateWiseReportRows(allOutwards);
      final vendorRows = SubVendorMaterialOutwardService.generateSubVendorWiseSummary(allOutwards);
      final matRows = SubVendorMaterialOutwardService.generateMaterialWiseSummary(allOutwards);
      final monthRows = SubVendorMaterialOutwardService.generatePeriodSummary(allOutwards, grouping: 'MONTHLY');

      final dateTotal = SubVendorFinancialEngine.sumPaise(dateRows, (r) => (r['total_price'] as num).toDouble());
      final vendorTotal = SubVendorFinancialEngine.sumPaise(vendorRows, (r) => (r['total_value'] as num).toDouble());
      final matTotal = SubVendorFinancialEngine.sumPaise(matRows, (r) => (r['total_value'] as num).toDouble());
      final periodTotal = SubVendorFinancialEngine.sumPaise(monthRows, (p) => p.grandTotal);

      expect(dateTotal, equals(54860.0));
      expect(vendorTotal, equals(54860.0));
      expect(matTotal, equals(54860.0));
      expect(periodTotal, equals(54860.0));
    });

    // -------------------------------------------------------------------------
    // Scenario 13: Cross-Screen Unified Agreement (Summary == Settlement == LedgerBuilder)
    // -------------------------------------------------------------------------
    test('Scenario 13: SiteFinancialDetail, VendorFinancialSummary, SubVendorSettlement & SubVendorLedgerBuilder produce identical balances', () async {
      // Quoted ₹1,80,000 site: Customer cash ₹15,000 residual + Bank Loan ₹1,65,000 itemized in vendor_customer_payments
      final assignment = VendorSiteAssignment(
        id: 'asgn-reconcile-1',
        vendorId: v1Id,
        vendorName: v1Name,
        customerId: 'cust-reconcile-1',
        customerName: 'Ramesh Patil',
        consumerNo: 'CA-100200',
        assignedDate: DateTime(2026, 11, 1),
        siteCapacityKw: 3.0,
        ratePerKw: 1000.0,
        vendorCharges: 3000.0,
        otherExpenses: 500.0,
        customerTotalAmount: 180000.0,
        customerPaidAmount: 180000.0,
        totalCustomerSiteAmount: 180000.0,
        totalCustomerReceived: 180000.0,
        totalCashReceived: 15000.0,
        totalLoanCredited: 165000.0,
      );

      final customerPayments = [
        VendorCustomerPayment(
          id: 'cp-loan-1',
          assignmentId: assignment.id,
          vendorId: v1Id,
          customerId: assignment.customerId,
          paymentType: 'BANK_LOAN',
          paymentStage: 'LOAN_CREDIT',
          amount: 165000.0,
          paymentDate: DateTime(2026, 11, 5),
          referenceNumber: 'SBI-LOAN-001',
          bankName: 'SBI',
          customerName: 'Ramesh Patil',
          status: 'Approved',
        ),
      ];

      final materials = [
        VendorMaterialTransaction.create(
          assignmentId: assignment.id,
          vendorId: v1Id,
          customerId: assignment.customerId,
          transactionType: 'ISSUE',
          itemName: '550W Panels',
          itemCategory: 'SOLAR_PANEL',
          quantity: 6,
          unitRate: 12000.0,
        ), // 72,000 + 3,600 (5%) = 75,600
      ];

      final payouts = [
        VendorPayout(
          id: 'vp-paid-1',
          vendorId: v1Id,
          assignmentId: assignment.id,
          payoutDate: DateTime(2026, 11, 10),
          amount: 25000.0,
          referenceNumber: 'NEFT-25K',
          status: 'Paid',
        ),
        VendorPayout(
          id: 'vp-rejected-ignored',
          vendorId: v1Id,
          assignmentId: assignment.id,
          payoutDate: DateTime(2026, 11, 11),
          amount: 99999.0,
          referenceNumber: 'REJ-99K',
          status: 'Rejected', // MUST BE IGNORED EVERYWHERE
        ),
      ];

      final gstRecoveries = [
        VendorGstRecovery(
          id: 'gst-rec-1',
          assignmentId: assignment.id,
          vendorId: v1Id,
          taxableValue: 10000.0,
          gstRate: 18.0,
          gstAmount: 1800.0,
          totalRecovery: 11800.0,
          recoveryDate: DateTime(2026, 11, 12),
          recoveryStatus: 'Approved',
        ),
      ];

      final siteDetail = SiteFinancialDetail.compute(
        assignment: assignment,
        materials: materials,
        payouts: payouts,
        customerPayments: customerPayments,
        gstRecoveries: gstRecoveries,
      );

      final vendorSummary = VendorFinancialSummary.compute(
        vendorId: v1Id,
        vendorCode: v1Code,
        vendorName: v1Name,
        assignments: [assignment],
        allMaterials: materials,
        allPayouts: payouts,
        customerPayments: customerPayments,
        gstRecoveries: gstRecoveries,
      );

      final settlement = SubVendorSettlement.compute(
        assignment: assignment,
        materials: materials,
        previousPayouts: payouts,
        customerPayments: customerPayments,
        gstRecoveries: gstRecoveries,
      );

      final chronologicalLedger = SubVendorLedgerBuilder.buildLedger(
        vendorId: v1Id,
        vendorName: v1Name,
        vendorCode: v1Code,
        assignments: [assignment],
        materials: materials,
        payouts: payouts,
        customerPayments: customerPayments,
        gstRecoveries: gstRecoveries,
      );

      // Verify residual ₹15,000 cash wasn't dropped alongside SBI ₹1,65,000 loan
      expect(siteDetail.effectiveCollection, equals(180000.0));
      expect(vendorSummary.effectiveTotalCollection, equals(180000.0));
      expect(settlement.totalActualCollected, equals(180000.0));

      // Verify Rejected ₹99,999 payout is excluded across ALL 4 engines
      expect(siteDetail.totalPaidToVendor, equals(25000.0));
      expect(vendorSummary.totalPaidAmount, equals(25000.0));
      expect(settlement.previousPayoutsPaid, equals(25000.0));

      // Verify exact agreement across all 4 screens/engines down to the paise
      expect(vendorSummary.netSettlementPayable, equals(siteDetail.netSubVendorBalance));
      expect(settlement.finalPayoutPayable, equals(siteDetail.netSubVendorBalance));
      expect(chronologicalLedger.closingBalance, equals(siteDetail.netSubVendorBalance));
    });

    // -------------------------------------------------------------------------
    // Scenario 14: PDF Generation Reconciles with Ledger & Outward Summaries
    // -------------------------------------------------------------------------
    test('Scenario 14: PDF statement & dispatch slip generation succeed offline with consistent totals', () async {
      const vendor = SubVendor(
        id: v1Id,
        vendorCode: v1Code,
        name: v1Name,
        mobile: '9876543210',
        email: 'dhanshree@siya.com',
      );

      final outward = await SubVendorMaterialOutwardService.recordOutward(
        vendorId: v1Id,
        vendorName: v1Name,
        outwardDate: DateTime(2026, 11, 20),
        remarks: 'PDF reconciliation slip',
        items: const [
          SubVendorMaterialOutwardItem(
            id: 'i1', outwardId: 'o1', materialName: '550W Solar Panel', unit: 'NOS', quantity: 4, unitRate: 11500.0, gstPercentage: 5.0,
          ),
        ],
      );

      await SubVendorAccountLedgerService.recordTransaction(
        vendorId: v1Id,
        vendorName: v1Name,
        transactionDate: DateTime(2026, 11, 25),
        transactionType: 'MATERIAL_PAYMENT',
        amount: 20000.0,
        referenceNumber: 'UTR-PDF-1',
        particulars: 'Bank Payment for PDF',
      );

      final fromDate = DateTime(2026, 11, 22);
      final openBal = SubVendorAccountLedgerService.calculateOpeningBalance(vendorId: v1Id, fromDate: fromDate);
      final filteredEntries = await SubVendorAccountLedgerService.fetchLedgerEntries(vendorId: v1Id, fromDate: fromDate);
      final metrics = await SubVendorAccountLedgerService.calculateDashboardMetrics(fromDate: fromDate);

      expect(openBal, equals(-48300.0)); // 4 * 11500 * 1.05 = 48,300 Dr
      expect(metrics.totalCredit, equals(20000.0));
      expect(metrics.netBalance, equals(-28300.0)); // -48,300 + 20,000

      final slipBytes = await SubVendorMaterialOutwardPdfService.generateOutwardSlipPdfBytes(outward);
      expect(slipBytes.length, greaterThan(1000));

      final periods = SubVendorMaterialOutwardService.generatePeriodSummary([outward], grouping: 'MONTHLY');
      final periodPdfBytes = await SubVendorMaterialOutwardPdfService.generatePeriodReportPdfBytes(periods, grouping: 'MONTHLY');
      expect(periodPdfBytes.length, greaterThan(1000));

      final stmtPdfBytes = await SubVendorAccountLedgerPdfService.generateAccountStatementPdfBytes(
        vendor: vendor,
        entries: filteredEntries,
        openingBalance: openBal,
        totalCredit: metrics.totalCredit,
        totalDebit: metrics.totalDebit,
        closingBalance: metrics.netBalance,
        fromDate: fromDate,
      );
      expect(stmtPdfBytes.length, greaterThan(1000));
    });
  });
}
