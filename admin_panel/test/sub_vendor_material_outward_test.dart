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

  group('SUB VENDOR MATERIAL OUTWARD TRACKING - 10 SCENARIO TEST SUITE', () {
    // -------------------------------------------------------------------------
    // Scenario 1: Create one outward entry with multiple materials
    // -------------------------------------------------------------------------
    test('Scenario 1: Create one outward entry with multiple materials', () async {
      final materials = await SubVendorMaterialOutwardService.fetchMaterialMaster();
      expect(materials.length, greaterThanOrEqualTo(2));

      final panelMat = materials.firstWhere((m) => m.category == 'PANEL');
      final inverterMat = materials.firstWhere((m) => m.category == 'INVERTER');

      final initialPanelStock = panelMat.availableStock;
      final initialInverterStock = inverterMat.availableStock;

      final outward = await SubVendorMaterialOutwardService.recordOutward(
        vendorId: 'vnd-001',
        vendorName: 'Shree Balaji Solar Works',
        outwardDate: DateTime(2026, 11, 25),
        remarks: 'Site Installation 3kW at Jatoda',
        items: [
          SubVendorMaterialOutwardItem(
            id: '',
            outwardId: '',
            materialId: panelMat.id,
            materialName: panelMat.itemName,
            unit: 'NOS',
            quantity: 6.0,
            unitRate: 10000.0,
            gstPercentage: 18.0,
          ),
          SubVendorMaterialOutwardItem(
            id: '',
            outwardId: '',
            materialId: inverterMat.id,
            materialName: inverterMat.itemName,
            unit: 'NOS',
            quantity: 1.0,
            unitRate: 25000.0,
            gstPercentage: 0.0,
          ),
        ],
      );

      expect(outward.id, isNotEmpty);
      expect(outward.outwardNumber, startsWith('OUT-20261125-'));
      expect(outward.totalItems, equals(2));
      expect(outward.totalQuantity, equals(7.0));
      // Row 1: 6 * 10000 = 60000 + 18% GST (10800) = 70800
      // Row 2: 1 * 25000 = 25000 + 0% GST (0) = 25000
      expect(outward.subtotal, equals(85000.0));
      expect(outward.totalGst, equals(10800.0));
      expect(outward.totalValue, equals(95800.0));
      expect(outward.status, equals('Active'));
      expect(outward.isActive, isTrue);

      // Verify Main Inventory stock was NOT deducted
      final updatedMaterials = await SubVendorMaterialOutwardService.fetchMaterialMaster();
      final updatedPanel = updatedMaterials.firstWhere((m) => m.id == panelMat.id);
      final updatedInverter = updatedMaterials.firstWhere((m) => m.id == inverterMat.id);

      expect(updatedPanel.availableStock, equals(initialPanelStock));
      expect(updatedInverter.availableStock, equals(initialInverterStock));
    });

    // -------------------------------------------------------------------------
    // Scenario 2: Create multiple entries on different dates for same vendor
    // -------------------------------------------------------------------------
    test('Scenario 2: Create multiple outward entries for the same Sub Vendor on different dates', () async {
      final materials = await SubVendorMaterialOutwardService.fetchMaterialMaster();
      final cableMat = materials.firstWhere((m) => m.itemName.contains('Cable'));

      final e1 = await SubVendorMaterialOutwardService.recordOutward(
        vendorId: 'vnd-001',
        vendorName: 'Shree Balaji Solar Works',
        outwardDate: DateTime(2026, 11, 20),
        remarks: 'Phase 1 Wiring',
        items: [
          SubVendorMaterialOutwardItem(
            id: '',
            outwardId: '',
            materialId: cableMat.id,
            materialName: cableMat.itemName,
            unit: cableMat.unit,
            quantity: 50.0,
          ),
        ],
      );

      final e2 = await SubVendorMaterialOutwardService.recordOutward(
        vendorId: 'vnd-001',
        vendorName: 'Shree Balaji Solar Works',
        outwardDate: DateTime(2026, 11, 25),
        remarks: 'Phase 2 Wiring',
        items: [
          SubVendorMaterialOutwardItem(
            id: '',
            outwardId: '',
            materialId: cableMat.id,
            materialName: cableMat.itemName,
            unit: cableMat.unit,
            quantity: 30.0,
          ),
        ],
      );

      expect(e1.outwardNumber, isNot(equals(e2.outwardNumber)));
      expect(e1.outwardDate, equals(DateTime(2026, 11, 20)));
      expect(e2.outwardDate, equals(DateTime(2026, 11, 25)));

      final all = await SubVendorMaterialOutwardService.fetchOutwards();
      final vendorEntries = all.where((o) => o.vendorId == 'vnd-001').toList();
      expect(vendorEntries.length, equals(2));
    });

    // -------------------------------------------------------------------------
    // Scenario 3: Check date-wise history and filtering
    // -------------------------------------------------------------------------
    test('Scenario 3: Check date-wise history and multi-parameter filtering', () async {
      final materials = await SubVendorMaterialOutwardService.fetchMaterialMaster();
      final mat1 = materials[0];
      final mat2 = materials[1];

      await SubVendorMaterialOutwardService.recordOutward(
        vendorId: 'vnd-001',
        vendorName: 'Shree Balaji Solar Works',
        outwardDate: DateTime(2026, 11, 10),
        items: [
          SubVendorMaterialOutwardItem(id: '', outwardId: '', materialId: mat1.id, materialName: mat1.itemName, unit: mat1.unit, quantity: 10),
        ],
      );

      await SubVendorMaterialOutwardService.recordOutward(
        vendorId: 'vnd-002',
        vendorName: 'Khandesh Solar EPC',
        outwardDate: DateTime(2026, 11, 25),
        items: [
          SubVendorMaterialOutwardItem(id: '', outwardId: '', materialId: mat2.id, materialName: mat2.itemName, unit: mat2.unit, quantity: 5),
        ],
      );

      final all = await SubVendorMaterialOutwardService.fetchOutwards();
      expect(all.length, equals(2));

      // Filter by Date Range (Nov 20 to Nov 30) -> Should only find 2nd entry
      final dateFiltered = SubVendorMaterialOutwardService.filterOutwards(
        all,
        fromDate: DateTime(2026, 11, 20),
        toDate: DateTime(2026, 11, 30),
      );
      expect(dateFiltered.length, equals(1));
      expect(dateFiltered.first.vendorId, equals('vnd-002'));

      // Filter by Vendor ID -> Should only find vnd-001
      final vendorFiltered = SubVendorMaterialOutwardService.filterOutwards(
        all,
        vendorId: 'vnd-001',
      );
      expect(vendorFiltered.length, equals(1));
      expect(vendorFiltered.first.vendorName, equals('Shree Balaji Solar Works'));
    });

    // -------------------------------------------------------------------------
    // Scenario 4: Check Sub Vendor-wise report calculations
    // -------------------------------------------------------------------------
    test('Scenario 4: Check Sub Vendor-wise report summary and breakdown', () async {
      final materials = await SubVendorMaterialOutwardService.fetchMaterialMaster();
      final panel = materials.firstWhere((m) => m.category == 'PANEL');
      final inverter = materials.firstWhere((m) => m.category == 'INVERTER');

      // Entry 1 for Vendor A
      await SubVendorMaterialOutwardService.recordOutward(
        vendorId: 'vnd-001',
        vendorName: 'Vendor A',
        outwardDate: DateTime(2026, 11, 20),
        items: [
          SubVendorMaterialOutwardItem(id: '', outwardId: '', materialId: panel.id, materialName: panel.itemName, unit: panel.unit, quantity: 6),
        ],
      );

      // Entry 2 for Vendor A
      await SubVendorMaterialOutwardService.recordOutward(
        vendorId: 'vnd-001',
        vendorName: 'Vendor A',
        outwardDate: DateTime(2026, 11, 22),
        items: [
          SubVendorMaterialOutwardItem(id: '', outwardId: '', materialId: inverter.id, materialName: inverter.itemName, unit: inverter.unit, quantity: 2),
        ],
      );

      // Entry 3 for Vendor B
      await SubVendorMaterialOutwardService.recordOutward(
        vendorId: 'vnd-002',
        vendorName: 'Vendor B',
        outwardDate: DateTime(2026, 11, 24),
        items: [
          SubVendorMaterialOutwardItem(id: '', outwardId: '', materialId: panel.id, materialName: panel.itemName, unit: panel.unit, quantity: 12),
        ],
      );

      final all = await SubVendorMaterialOutwardService.fetchOutwards();
      final report = SubVendorMaterialOutwardService.generateSubVendorWiseSummary(all);

      expect(report.length, equals(2));

      final vendorAReport = report.firstWhere((r) => r['vendor_id'] == 'vnd-001');
      expect(vendorAReport['total_outwards'], equals(2));
      expect(vendorAReport['total_quantity'], equals(8.0)); // 6 panels + 2 inverters
      final vendorAMatMap = vendorAReport['materials_summary'] as Map<String, double>;
      expect(vendorAMatMap[panel.itemName], equals(6.0));
      expect(vendorAMatMap[inverter.itemName], equals(2.0));

      final vendorBReport = report.firstWhere((r) => r['vendor_id'] == 'vnd-002');
      expect(vendorBReport['total_outwards'], equals(1));
      expect(vendorBReport['total_quantity'], equals(12.0));
    });

    // -------------------------------------------------------------------------
    // Scenario 5: Check Material-wise report calculations
    // -------------------------------------------------------------------------
    test('Scenario 5: Check Material-wise report summary and Sub-Vendor breakdown', () async {
      final materials = await SubVendorMaterialOutwardService.fetchMaterialMaster();
      final panel = materials.firstWhere((m) => m.category == 'PANEL');

      await SubVendorMaterialOutwardService.recordOutward(
        vendorId: 'vnd-001',
        vendorName: 'Vendor A',
        outwardDate: DateTime(2026, 11, 20),
        items: [
          SubVendorMaterialOutwardItem(id: '', outwardId: '', materialId: panel.id, materialName: panel.itemName, unit: panel.unit, quantity: 6),
        ],
      );

      await SubVendorMaterialOutwardService.recordOutward(
        vendorId: 'vnd-002',
        vendorName: 'Vendor B',
        outwardDate: DateTime(2026, 11, 21),
        items: [
          SubVendorMaterialOutwardItem(id: '', outwardId: '', materialId: panel.id, materialName: panel.itemName, unit: panel.unit, quantity: 18),
        ],
      );

      final all = await SubVendorMaterialOutwardService.fetchOutwards();
      final report = SubVendorMaterialOutwardService.generateMaterialWiseSummary(all);

      final panelSummary = report.firstWhere((r) => r['material_name'] == panel.itemName);
      expect(panelSummary['total_quantity'], equals(24.0)); // 6 + 18
      expect(panelSummary['total_outwards'], equals(2));

      final vBreakdown = panelSummary['vendor_breakdown'] as Map<String, double>;
      expect(vBreakdown['Vendor A'], equals(6.0));
      expect(vBreakdown['Vendor B'], equals(18.0));
    });

    // -------------------------------------------------------------------------
    // Scenario 6: Verify NO Main Inventory deduction & custom material addition
    // -------------------------------------------------------------------------
    test('Scenario 6: Verify NO Main Inventory stock deduction and support adding custom material', () async {
      final materials = await SubVendorMaterialOutwardService.fetchMaterialMaster();
      final structureMat = materials.firstWhere((m) => m.itemName.contains('Structure'));
      final availableStock = structureMat.availableStock;

      // 1. Add custom material to master
      final customMat = await SubVendorMaterialOutwardService.addMaterialToMaster(
        itemName: 'MC4 Connector Pair (Custom)',
        unit: 'PCS',
        defaultRate: 120.0,
      );
      expect(customMat.itemName, equals('MC4 Connector Pair (Custom)'));

      // 2. Record outward with large quantity - must NOT fail or deduct Main Inventory
      final outward = await SubVendorMaterialOutwardService.recordOutward(
        vendorId: 'vnd-001',
        vendorName: 'Shree Balaji',
        outwardDate: DateTime(2026, 11, 25),
        items: [
          SubVendorMaterialOutwardItem(
            id: '',
            outwardId: '',
            materialId: structureMat.id,
            materialName: structureMat.itemName,
            unit: 'SET',
            quantity: 10.0,
            unitRate: 14000.0,
            gstPercentage: 18.0,
          ),
          SubVendorMaterialOutwardItem(
            id: '',
            outwardId: '',
            materialId: customMat.id,
            materialName: customMat.itemName,
            unit: 'PCS',
            quantity: 50.0,
            unitRate: 120.0,
            gstPercentage: 5.0,
          ),
        ],
      );

      // Structure: 10 * 14000 = 140000 + 18% (25200) = 165200
      // Custom MC4: 50 * 120 = 6000 + 5% (300) = 6300
      expect(outward.subtotal, equals(146000.0));
      expect(outward.totalGst, equals(25500.0));
      expect(outward.totalValue, equals(171500.0));

      final updatedMats = await SubVendorMaterialOutwardService.fetchMaterialMaster();
      final updatedStruct = updatedMats.firstWhere((m) => m.id == structureMat.id);
      expect(updatedStruct.availableStock, equals(availableStock));
    });

    // -------------------------------------------------------------------------
    // Scenario 7: Edit an existing outward entry and verify pricing & no stock change
    // -------------------------------------------------------------------------
    test('Scenario 7: Edit outward entry updates Rate/GST totals without modifying stock', () async {
      final materials = await SubVendorMaterialOutwardService.fetchMaterialMaster();
      final panel = materials.firstWhere((m) => m.category == 'PANEL');
      final baselineStock = panel.availableStock;

      final created = await SubVendorMaterialOutwardService.recordOutward(
        vendorId: 'vnd-001',
        vendorName: 'Vendor A',
        outwardDate: DateTime(2026, 11, 25),
        items: [
          SubVendorMaterialOutwardItem(
            id: '',
            outwardId: '',
            materialId: panel.id,
            materialName: panel.itemName,
            unit: 'NOS',
            quantity: 10.0,
            unitRate: 10000.0,
            gstPercentage: 0.0,
          ),
        ],
      );
      expect(created.totalValue, equals(100000.0));

      // Edit entry to 15 panels with 12% GST
      final updated = await SubVendorMaterialOutwardService.updateOutward(
        outwardId: created.id,
        vendorId: 'vnd-001',
        vendorName: 'Vendor A',
        outwardDate: DateTime(2026, 11, 25),
        remarks: 'Updated to 15 panels @ 12% GST',
        items: [
          SubVendorMaterialOutwardItem(
            id: '',
            outwardId: created.id,
            materialId: panel.id,
            materialName: panel.itemName,
            unit: 'NOS',
            quantity: 15.0,
            unitRate: 10000.0,
            gstPercentage: 12.0,
          ),
        ],
      );

      expect(updated.subtotal, equals(150000.0));
      expect(updated.totalGst, equals(18000.0));
      expect(updated.totalValue, equals(168000.0));

      final matsAfterEdit = await SubVendorMaterialOutwardService.fetchMaterialMaster();
      expect(matsAfterEdit.firstWhere((m) => m.id == panel.id).availableStock, equals(baselineStock));
    });

    // -------------------------------------------------------------------------
    // Scenario 8: Cancel outward entry and verify exclusion from active reports
    // -------------------------------------------------------------------------
    test('Scenario 8: Cancel outward entry excludes from active reports without modifying stock', () async {
      final materials = await SubVendorMaterialOutwardService.fetchMaterialMaster();
      final panel = materials.firstWhere((m) => m.category == 'PANEL');
      final baselineStock = panel.availableStock;

      final outward = await SubVendorMaterialOutwardService.recordOutward(
        vendorId: 'vnd-001',
        vendorName: 'Vendor A',
        outwardDate: DateTime(2026, 11, 25),
        items: [
          SubVendorMaterialOutwardItem(
            id: '',
            outwardId: '',
            materialId: panel.id,
            materialName: panel.itemName,
            unit: 'NOS',
            quantity: 20.0,
            unitRate: 11000.0,
            gstPercentage: 5.0,
          ),
        ],
      );

      // Cancel the outward
      final cancelled = await SubVendorMaterialOutwardService.cancelOutward(
        outward.id,
        reason: 'Client site cancelled installation',
      );

      expect(cancelled.status, equals('Cancelled'));
      expect(cancelled.isCancelled, isTrue);
      expect(cancelled.isActive, isFalse);
      expect(cancelled.cancellationReason, equals('Client site cancelled installation'));

      // Stock remains unchanged
      final matsAfterCancel = await SubVendorMaterialOutwardService.fetchMaterialMaster();
      expect(matsAfterCancel.firstWhere((m) => m.id == panel.id).availableStock, equals(baselineStock));

      // Rule 7 Verification: Cancelled entries must not count in active outward reports
      final allOutwards = await SubVendorMaterialOutwardService.fetchOutwards();
      final activeSummary = SubVendorMaterialOutwardService.generateMaterialWiseSummary(allOutwards);
      expect(activeSummary.where((s) => s['material_name'] == panel.itemName), isEmpty);
    });

    // -------------------------------------------------------------------------
    // Scenario 9: Verify no duplicate ledger or stock side-effects on fetch
    // -------------------------------------------------------------------------
    test('Scenario 9: Fetching and filtering leaves stock unchanged and prevents double cancel', () async {
      final materials = await SubVendorMaterialOutwardService.fetchMaterialMaster();
      final panel = materials.firstWhere((m) => m.category == 'PANEL');
      final baselineStock = panel.availableStock;

      final created = await SubVendorMaterialOutwardService.recordOutward(
        vendorId: 'vnd-001',
        vendorName: 'Vendor A',
        outwardDate: DateTime(2026, 11, 25),
        items: [
          SubVendorMaterialOutwardItem(
            id: '',
            outwardId: '',
            materialId: panel.id,
            materialName: panel.itemName,
            unit: 'NOS',
            quantity: 5.0,
            unitRate: 10000.0,
            gstPercentage: 18.0,
          ),
        ],
      );

      // Perform multiple fetches and reports
      await SubVendorMaterialOutwardService.fetchOutwards();
      await SubVendorMaterialOutwardService.fetchOutwards();
      final all = await SubVendorMaterialOutwardService.fetchOutwards();
      SubVendorMaterialOutwardService.generateDateWiseReportRows(all);
      SubVendorMaterialOutwardService.generateSubVendorWiseSummary(all);
      SubVendorMaterialOutwardService.generateMaterialWiseSummary(all);

      final finalMats = await SubVendorMaterialOutwardService.fetchMaterialMaster();
      expect(finalMats.firstWhere((m) => m.id == panel.id).availableStock, equals(baselineStock));

      // Cannot cancel twice
      expect(() => SubVendorMaterialOutwardService.cancelOutward(created.id), returnsNormally);
      expect(() => SubVendorMaterialOutwardService.cancelOutward(created.id), throwsA(isA<StateError>()));
    });

    // -------------------------------------------------------------------------
    // Scenario 10: Verify old data, existing vendor master, and other modules
    // -------------------------------------------------------------------------
    test('Scenario 10: Verify old data and existing Sub-Vendor master functionality works correctly', () async {
      final vendors = await SubVendorMaterialOutwardService.fetchActiveSubVendors();
      expect(vendors, isNotEmpty);
      expect(vendors.first.name, isNotEmpty);
      expect(vendors.first.vendorCode, isNotEmpty);

      // Validation: Prevent empty entry
      expect(
        () => SubVendorMaterialOutwardService.recordOutward(
          vendorId: vendors.first.id,
          vendorName: vendors.first.name,
          outwardDate: DateTime.now(),
          items: [],
        ),
        throwsA(isA<ArgumentError>()),
      );

      // Validation: Quantity > 0
      expect(
        () => SubVendorMaterialOutwardService.recordOutward(
          vendorId: vendors.first.id,
          vendorName: vendors.first.name,
          outwardDate: DateTime.now(),
          items: [
            const SubVendorMaterialOutwardItem(id: '', outwardId: '', materialName: 'Panel', unit: 'NOS', quantity: 0),
          ],
        ),
        throwsA(isA<ArgumentError>()),
      );
    });
  });
}
