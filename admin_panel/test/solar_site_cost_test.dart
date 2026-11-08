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
      );

      expect(panel.totalWattage, 3300.0);
      expect(panel.totalAmount, 59400.0);
    });

    test('2. Inverter Cost (Fixed Rate Only): 1 x ₹25,000 = ₹25,000', () {
      const inverter = SolarInverterCostItem(
        id: 'inv1',
        brand: 'Growatt',
        model: 'MIC 3300TL-X',
        capacity: '3.3 kW',
        quantity: 1,
        fixedRate: 25000.0,
      );

      expect(inverter.totalAmount, 25000.0);
    });

    test('3. GI Pipe Size-wise Calculation: 40x40, 80x40, 40x20 matching ₹14,120', () {
      const pipe1 = SolarGiPipeCostItem(
        id: 'pipe1',
        pipeSize: '40x40 mm',
        thicknessMm: 1.6,
        lengthFeet: 20.0,
        numberOfPipes: 10,
        weightPerPipeKg: 8.0,
        ratePerKg: 85.0,
      );
      expect(pipe1.totalWeightKg, 80.0);
      expect(pipe1.totalAmount, 6800.0); // 80 * 85 = 6,800

      const pipe2 = SolarGiPipeCostItem(
        id: 'pipe2',
        pipeSize: '80x40 mm',
        thicknessMm: 2.0,
        lengthFeet: 20.0,
        numberOfPipes: 5,
        weightPerPipeKg: 12.0,
        ratePerKg: 90.0,
      );
      expect(pipe2.totalWeightKg, 60.0);
      expect(pipe2.totalAmount, 5400.0); // 60 * 90 = 5,400

      const pipe3 = SolarGiPipeCostItem(
        id: 'pipe3',
        pipeSize: '40x20 mm',
        thicknessMm: 1.6,
        lengthFeet: 20.0,
        numberOfPipes: 4,
        weightPerPipeKg: 6.0,
        ratePerKg: 80.0,
      );
      expect(pipe3.totalWeightKg, 24.0);
      expect(pipe3.totalAmount, 1920.0); // 24 * 80 = 1,920

      final totalGiCost = pipe1.totalAmount + pipe2.totalAmount + pipe3.totalAmount;
      expect(totalGiCost, 14120.0);
    });

    test('4. Electrical BOS Material: ACDB, DCDB, DC Cable, AC Cable, Earthing, MC4 = ₹12,400', () {
      final bosItems = const [
        SolarBosCostItem(id: '1', itemName: 'ACDB', unit: 'FIXED', quantity: 1, rate: 2500.0),
        SolarBosCostItem(id: '2', itemName: 'DCDB', unit: 'FIXED', quantity: 1, rate: 2200.0),
        SolarBosCostItem(id: '3', itemName: 'DC Cable', unit: 'FIXED', quantity: 1, rate: 1750.0),
        SolarBosCostItem(id: '4', itemName: 'AC Cable', unit: 'FIXED', quantity: 1, rate: 1950.0),
        SolarBosCostItem(id: '5', itemName: 'Earthing Kit', unit: 'FIXED', quantity: 1, rate: 3500.0),
        SolarBosCostItem(id: '6', itemName: 'MC4 Connector', unit: 'FIXED', quantity: 1, rate: 500.0),
      ];

      final totalBos = bosItems.fold(0.0, (sum, i) => sum + i.totalAmount);
      expect(totalBos, 12400.0);
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

    test('7. FINAL SITE COST VERIFICATION (Section 11 Sample): MUST EQUAL EXACTLY ₹1,33,920', () {
      final sample = SolarSiteCostCalculation.createSampleTestCalculation();

      expect(sample.totalPanelCost, 59400.0);
      expect(sample.totalInverterCost, 25000.0);
      expect(sample.totalGiPipeCost, 14120.0);
      expect(sample.totalStructureCost, 0.0);
      expect(sample.totalBosCost, 12400.0);
      expect(sample.totalOtherMaterialCost, 0.0);
      expect(sample.totalLabourCost, 18500.0);
      expect(sample.totalOtherExpensesCost, 4500.0);

      // 59,400 + 25,000 + 14,120 + 12,400 + 18,500 + 4,500 = 1,33,920
      expect(sample.finalSiteCost, 133920.0);

      // Cost per kW for 3.3 kW: 133920 / 3.3 = 40581.818...
      expect(sample.costPerKw, closeTo(40581.82, 0.01));
    });

    test('8. Other Structure Material supports configurable units (KG, WATT, NOS, METER, FIXED)', () {
      const itemKg = SolarStructureCostItem(id: '1', itemName: 'Purlin', unit: 'KG', quantity: 50, rate: 85);
      expect(itemKg.totalAmount, 4250.0);

      const itemMeter = SolarStructureCostItem(id: '2', itemName: 'Rail', unit: 'METER', quantity: 20, rate: 180);
      expect(itemMeter.totalAmount, 3600.0);

      const itemFixed = SolarStructureCostItem(id: '3', itemName: 'Base Plate Set', unit: 'FIXED', quantity: 1, rate: 1500);
      expect(itemFixed.totalAmount, 1500.0);
    });

    test('9. JSON Serialization & Deserialization round-trip integrity', () {
      final sample = SolarSiteCostCalculation.createSampleTestCalculation();
      final json = sample.toJson();
      final reconstructed = SolarSiteCostCalculation.fromJson(json);

      expect(reconstructed.siteName, sample.siteName);
      expect(reconstructed.systemCapacityKw, sample.systemCapacityKw);
      expect(reconstructed.finalSiteCost, sample.finalSiteCost);
      expect(reconstructed.totalPanelCost, sample.totalPanelCost);
      expect(reconstructed.totalInverterCost, sample.totalInverterCost);
      expect(reconstructed.totalGiPipeCost, sample.totalGiPipeCost);
      expect(reconstructed.totalBosCost, sample.totalBosCost);
      expect(reconstructed.totalLabourCost, sample.totalLabourCost);
      expect(reconstructed.totalOtherExpensesCost, sample.totalOtherExpensesCost);
    });

    test('10. PDF Generator produces valid non-empty PDF bytes', () async {
      final sample = SolarSiteCostCalculation.createSampleTestCalculation();
      final pdfBytes = await SolarSiteCostPdfService.generateSiteCostPdfBytes(sample);

      expect(pdfBytes, isNotNull);
      expect(pdfBytes.length, greaterThan(1000));
    });
  });
}

