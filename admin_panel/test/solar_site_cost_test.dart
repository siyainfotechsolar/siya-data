import 'package:flutter_test/flutter_test.dart';
import 'package:siya_shared/siya_shared.dart';
import 'package:admin_panel/services/solar_site_cost_pdf_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SIYA SOLAR SITE COST CALCULATOR - Unit & Verification Tests', () {
    test('1. Solar Panel calculation: 550W x 6 @ ₹18/W = ₹59,400', () {
      const panel = SolarPanelCostItem(
        id: 'p1',
        brand: 'Waaree',
        model: 'Mono PERC',
        wattage: 550.0,
        quantity: 6,
        ratePerWatt: 18.0,
        gstRate: 5.0,
      );

      expect(panel.totalWattage, 3300.0);
      expect(panel.taxableAmount, 59400.0);
      expect(panel.gstAmount, 2970.0); // 59,400 * 5% = 2,970
      expect(panel.totalAmount, 62370.0);
    });

    test('2. Inverter Cost (Fixed Rate Only): 1 x ₹25,000 = ₹25,000 + 5% GST', () {
      const inverter = SolarInverterCostItem(
        id: 'inv1',
        brand: 'Growatt',
        model: 'MIC 3300TL-X',
        capacity: '3.3 kW',
        quantity: 1,
        fixedRate: 25000.0,
        gstRate: 5.0,
      );

      expect(inverter.taxableAmount, 25000.0);
      expect(inverter.gstAmount, 1250.0); // 25,000 * 5% = 1,250
      expect(inverter.totalAmount, 26250.0);
    });

    test('3. GI Pipe Size-wise Calculation: 40x40, 80x40, 40x20 matching ₹14,120 + 18% GST', () {
      const pipe1 = SolarGiPipeCostItem(
        id: 'pipe1',
        pipeSize: '40x40 mm',
        thicknessMm: 1.6,
        lengthFeet: 20.0,
        numberOfPipes: 10,
        weightPerPipeKg: 8.0,
        ratePerKg: 85.0,
        gstRate: 18.0,
      );
      expect(pipe1.totalWeightKg, 80.0);
      expect(pipe1.taxableAmount, 6800.0); // 80 * 85 = 6,800
      expect(pipe1.gstAmount, 1224.0); // 6,800 * 18% = 1,224

      const pipe2 = SolarGiPipeCostItem(
        id: 'pipe2',
        pipeSize: '80x40 mm',
        thicknessMm: 2.0,
        lengthFeet: 20.0,
        numberOfPipes: 5,
        weightPerPipeKg: 12.0,
        ratePerKg: 90.0,
        gstRate: 18.0,
      );
      expect(pipe2.totalWeightKg, 60.0);
      expect(pipe2.taxableAmount, 5400.0); // 60 * 90 = 5,400
      expect(pipe2.gstAmount, 972.0); // 5,400 * 18% = 972

      const pipe3 = SolarGiPipeCostItem(
        id: 'pipe3',
        pipeSize: '40x20 mm',
        thicknessMm: 1.6,
        lengthFeet: 20.0,
        numberOfPipes: 4,
        weightPerPipeKg: 6.0,
        ratePerKg: 80.0,
        gstRate: 18.0,
      );
      expect(pipe3.totalWeightKg, 24.0);
      expect(pipe3.taxableAmount, 1920.0); // 24 * 80 = 1,920
      expect(pipe3.gstAmount, closeTo(345.60, 0.01)); // 1,920 * 18% = 345.60

      final totalGiTaxable = pipe1.taxableAmount + pipe2.taxableAmount + pipe3.taxableAmount;
      expect(totalGiTaxable, 14120.0);

      final totalGiGst = pipe1.gstAmount + pipe2.gstAmount + pipe3.gstAmount;
      expect(totalGiGst, closeTo(2541.60, 0.01));
    });

    test('4. Electrical BOS Material: ACDB, DCDB, DC Cable, AC Cable, Earthing, MC4 = ₹12,400 + 18% GST', () {
      final bosItems = const [
        SolarBosCostItem(id: '1', itemName: 'ACDB', unit: 'FIXED', quantity: 1, rate: 2500.0, gstRate: 18.0),
        SolarBosCostItem(id: '2', itemName: 'DCDB', unit: 'FIXED', quantity: 1, rate: 2200.0, gstRate: 18.0),
        SolarBosCostItem(id: '3', itemName: 'DC Cable', unit: 'FIXED', quantity: 1, rate: 1750.0, gstRate: 18.0),
        SolarBosCostItem(id: '4', itemName: 'AC Cable', unit: 'FIXED', quantity: 1, rate: 1950.0, gstRate: 18.0),
        SolarBosCostItem(id: '5', itemName: 'Earthing Kit', unit: 'FIXED', quantity: 1, rate: 3500.0, gstRate: 18.0),
        SolarBosCostItem(id: '6', itemName: 'MC4 Connector', unit: 'FIXED', quantity: 1, rate: 500.0, gstRate: 18.0),
      ];

      final totalBosTaxable = bosItems.fold(0.0, (sum, i) => sum + i.taxableAmount);
      expect(totalBosTaxable, 12400.0);

      final totalBosGst = bosItems.fold(0.0, (sum, i) => sum + i.gstAmount);
      expect(totalBosGst, 2232.0); // 12,400 * 18% = 2,232
    });

    test('5. Labour Cost (Only Three Categories): Wiring, Structure, Civil = ₹18,500', () {
      const labour = SolarLabourCost(
        wiringLabour: LabourCategoryDetail(description: 'Wiring Labour', fixedAmount: 6000.0),
        structureLabour: LabourCategoryDetail(description: 'Structure Labour', fixedAmount: 7000.0),
        civilLabour: LabourCategoryDetail(description: 'Civil Labour', fixedAmount: 5500.0),
      );

      expect(labour.totalWiring, 6000.0);
      expect(labour.totalStructure, 7000.0);
      expect(labour.totalCivil, 5500.0);
      expect(labour.totalLabour, 18500.0);
    });

    test('6. Other Expenses: Transport ₹3,000 + Loading ₹500 + Other ₹1,000 = ₹4,500', () {
      const expenses = SolarOtherExpenses(
        transportation: 3000.0,
        loadingUnloading: 500.0,
        otherExpenses: 1000.0,
      );

      expect(expenses.totalExpenses, 4500.0);
    });

    test('7. FINAL SITE COST VERIFICATION (Section 11 Sample Net Base): MUST EQUAL EXACTLY ₹1,33,920', () {
      final sample = SolarSiteCostCalculation.createSampleTestCalculation(withGst: false);

      expect(sample.totalPanelTaxable, 59400.0);
      expect(sample.totalInverterTaxable, 25000.0);
      expect(sample.totalGiPipeTaxable, 14120.0);
      expect(sample.totalStructureTaxable, 0.0);
      expect(sample.totalBosTaxable, 12400.0);
      expect(sample.totalOtherMaterialTaxable, 0.0);
      expect(sample.totalLabourCost, 18500.0);
      expect(sample.totalOtherExpensesCost, 4500.0);

      // 59,400 + 25,000 + 14,120 + 12,400 + 18,500 + 4,500 = 1,33,920
      expect(sample.finalSiteCostWithoutGst, 133920.0);
      expect(sample.finalSiteCost, 133920.0);

      // Cost per kW for 3.3 kW: 133920 / 3.3 = 40581.818...
      expect(sample.costPerKw, closeTo(40581.82, 0.01));
    });

    test('8. GST CALCULATION VERIFICATION: 5% Panels/Inverters + 18% GI/BOS = ₹8,993.60 GST & ₹1,42,913.60 Total', () {
      final sample = SolarSiteCostCalculation.createSampleTestCalculation(withGst: true);

      // 1. Panels GST: 59,400 * 5% = 2,970
      expect(sample.totalPanelGst, 2970.0);

      // 2. Inverter GST: 25,000 * 5% = 1,250
      expect(sample.totalInverterGst, 1250.0);

      // 3. GI Pipe GST: 14,120 * 18% = 2,541.60
      expect(sample.totalGiPipeGst, 2541.60);

      // 4. BOS GST: 12,400 * 18% = 2,232.00
      expect(sample.totalBosGst, 2232.0);

      // Total GST = 2,970 + 1,250 + 2,541.60 + 2,232 = 8,993.60
      expect(sample.totalGstAmount, 8993.60);

      // Final Total with GST: 1,33,920 (Base) + 8,993.60 (GST) = 1,42,913.60
      expect(sample.finalSiteCostWithGst, 142913.60);
      expect(sample.finalSiteCost, 142913.60);

      // Cost Per kW with GST: 142913.60 / 3.3 = 43,307.15
      expect(sample.costPerKw, closeTo(43307.15, 0.01));
    });

    test('9. Other Structure Material supports configurable units (KG, WATT, NOS, METER, FIXED)', () {
      const itemKg = SolarStructureCostItem(id: '1', itemName: 'Purlin', unit: 'KG', quantity: 50, rate: 85, gstRate: 18);
      expect(itemKg.taxableAmount, 4250.0);
      expect(itemKg.gstAmount, 765.0);
      expect(itemKg.totalAmount, 5015.0);

      const itemMeter = SolarStructureCostItem(id: '2', itemName: 'Rail', unit: 'METER', quantity: 20, rate: 180, gstRate: 18);
      expect(itemMeter.taxableAmount, 3600.0);
      expect(itemMeter.gstAmount, 648.0);
      expect(itemMeter.totalAmount, 4248.0);
    });

    test('10. JSON Serialization & Deserialization round-trip integrity with GST', () {
      final sample = SolarSiteCostCalculation.createSampleTestCalculation(withGst: true);
      final json = sample.toJson();
      final reconstructed = SolarSiteCostCalculation.fromJson(json);

      expect(reconstructed.siteName, sample.siteName);
      expect(reconstructed.systemCapacityKw, sample.systemCapacityKw);
      expect(reconstructed.isGstApplicable, true);
      expect(reconstructed.finalSiteCost, sample.finalSiteCost);
      expect(reconstructed.totalTaxableCost, sample.totalTaxableCost);
      expect(reconstructed.totalGstAmount, sample.totalGstAmount);
      expect(reconstructed.totalPanelGst, sample.totalPanelGst);
      expect(reconstructed.totalGiPipeGst, sample.totalGiPipeGst);
    });

    test('11. PDF Generator produces valid non-empty PDF bytes with GST tables', () async {
      final sample = SolarSiteCostCalculation.createSampleTestCalculation(withGst: true);
      final pdfBytes = await SolarSiteCostPdfService.generateSiteCostPdfBytes(sample);

      expect(pdfBytes, isNotNull);
      expect(pdfBytes.length, greaterThan(1000));
    });
  });
}
