import 'dart:convert';

/// Domain Models for SIYA SOLAR SITE COST CALCULATOR
///
/// Features:
/// - Solar Panels (Wattage x Qty x Rate/Watt, with 5% GST)
/// - Inverter (Fixed Cost x Qty, with 5% / 12% GST)
/// - GI Pipe (Size-wise, Weight x Qty x Rate/KG, with 18% GST)
/// - Other Structure Material (Configurable units, with 18% GST)
/// - Electrical BOS Material (Fixed, Meter, Nos, Set, with 18% GST)
/// - Other Custom Materials (Configurable GST)
/// - Labour Cost (Exactly 3 categories: Wiring, Structure, Civil)
/// - Other Expenses (Transportation, Loading/Unloading, Other)
/// - GST Toggle & Breakdown: Taxable Base Cost, Total GST, and Final Total

// -----------------------------------------------------------------------------
// 1. Solar Panel Cost Item
// -----------------------------------------------------------------------------
class SolarPanelCostItem {
  final String id;
  final String brand;
  final String model;
  final double wattage; // e.g. 550.0
  final int quantity; // e.g. 6
  final double ratePerWatt; // e.g. 18.0
  final double gstRate; // e.g. 5.0%

  const SolarPanelCostItem({
    required this.id,
    this.brand = '',
    this.model = '',
    required this.wattage,
    required this.quantity,
    required this.ratePerWatt,
    this.gstRate = 5.0,
  });

  double get totalWattage => wattage * quantity;
  double get taxableAmount => totalWattage * ratePerWatt;
  double get gstAmount => taxableAmount * (gstRate / 100.0);
  double get totalAmount => taxableAmount + gstAmount;

  Map<String, dynamic> toJson() => {
        'id': id,
        'brand': brand,
        'model': model,
        'wattage': wattage,
        'quantity': quantity,
        'ratePerWatt': ratePerWatt,
        'gstRate': gstRate,
        'totalWattage': totalWattage,
        'taxableAmount': taxableAmount,
        'gstAmount': gstAmount,
        'totalAmount': totalAmount,
      };

  factory SolarPanelCostItem.fromJson(Map<String, dynamic> json) {
    final wattage = (json['wattage'] as num?)?.toDouble() ?? 0.0;
    final quantity = (json['quantity'] as num?)?.toInt() ?? 0;
    final ratePerWatt = (json['ratePerWatt'] as num?)?.toDouble() ?? 0.0;
    final gstRate = (json['gstRate'] as num?)?.toDouble() ?? 5.0;

    return SolarPanelCostItem(
      id: json['id']?.toString() ?? '',
      brand: json['brand']?.toString() ?? '',
      model: json['model']?.toString() ?? '',
      wattage: wattage,
      quantity: quantity,
      ratePerWatt: ratePerWatt,
      gstRate: gstRate,
    );
  }

  SolarPanelCostItem copyWith({
    String? id,
    String? brand,
    String? model,
    double? wattage,
    int? quantity,
    double? ratePerWatt,
    double? gstRate,
  }) {
    return SolarPanelCostItem(
      id: id ?? this.id,
      brand: brand ?? this.brand,
      model: model ?? this.model,
      wattage: wattage ?? this.wattage,
      quantity: quantity ?? this.quantity,
      ratePerWatt: ratePerWatt ?? this.ratePerWatt,
      gstRate: gstRate ?? this.gstRate,
    );
  }
}

// -----------------------------------------------------------------------------
// 2. Solar Inverter Cost Item (FIXED RATE ONLY)
// -----------------------------------------------------------------------------
class SolarInverterCostItem {
  final String id;
  final String brand;
  final String model;
  final String capacity; // e.g. "3 kW", "5 kW"
  final int quantity;
  final double fixedRate; // Fixed rate per inverter
  final double gstRate; // e.g. 5.0% or 12.0%

  const SolarInverterCostItem({
    required this.id,
    this.brand = '',
    this.model = '',
    this.capacity = '',
    required this.quantity,
    required this.fixedRate,
    this.gstRate = 5.0,
  });

  double get taxableAmount => quantity * fixedRate;
  double get gstAmount => taxableAmount * (gstRate / 100.0);
  double get totalAmount => taxableAmount + gstAmount;

  Map<String, dynamic> toJson() => {
        'id': id,
        'brand': brand,
        'model': model,
        'capacity': capacity,
        'quantity': quantity,
        'fixedRate': fixedRate,
        'gstRate': gstRate,
        'taxableAmount': taxableAmount,
        'gstAmount': gstAmount,
        'totalAmount': totalAmount,
      };

  factory SolarInverterCostItem.fromJson(Map<String, dynamic> json) {
    return SolarInverterCostItem(
      id: json['id']?.toString() ?? '',
      brand: json['brand']?.toString() ?? '',
      model: json['model']?.toString() ?? '',
      capacity: json['capacity']?.toString() ?? '',
      quantity: (json['quantity'] as num?)?.toInt() ?? 0,
      fixedRate: (json['fixedRate'] as num?)?.toDouble() ?? 0.0,
      gstRate: (json['gstRate'] as num?)?.toDouble() ?? 5.0,
    );
  }

  SolarInverterCostItem copyWith({
    String? id,
    String? brand,
    String? model,
    String? capacity,
    int? quantity,
    double? fixedRate,
    double? gstRate,
  }) {
    return SolarInverterCostItem(
      id: id ?? this.id,
      brand: brand ?? this.brand,
      model: model ?? this.model,
      capacity: capacity ?? this.capacity,
      quantity: quantity ?? this.quantity,
      fixedRate: fixedRate ?? this.fixedRate,
      gstRate: gstRate ?? this.gstRate,
    );
  }
}

// -----------------------------------------------------------------------------
// 3. GI Pipe Cost Item (SIZE-WISE CALCULATION)
// -----------------------------------------------------------------------------
class SolarGiPipeCostItem {
  final String id;
  final String pipeSize; // e.g. "40x40 mm", "80x40 mm", "40x20 mm", "50x50 mm", "Custom Size"
  final double thicknessMm; // e.g. 1.6, 2.0
  final double lengthFeet; // Default standard 20 Feet
  final int numberOfPipes; // Nos
  final double weightPerPipeKg; // KG according to supplier spec
  final double ratePerKg; // ₹/KG
  final double gstRate; // e.g. 18.0%

  const SolarGiPipeCostItem({
    required this.id,
    required this.pipeSize,
    this.thicknessMm = 1.6,
    this.lengthFeet = 20.0,
    required this.numberOfPipes,
    required this.weightPerPipeKg,
    required this.ratePerKg,
    this.gstRate = 18.0,
  });

  double get totalLengthFeet => numberOfPipes * lengthFeet;
  double get totalWeightKg => numberOfPipes * weightPerPipeKg;
  double get taxableAmount => totalWeightKg * ratePerKg;
  double get gstAmount => taxableAmount * (gstRate / 100.0);
  double get totalAmount => taxableAmount + gstAmount;

  Map<String, dynamic> toJson() => {
        'id': id,
        'pipeSize': pipeSize,
        'thicknessMm': thicknessMm,
        'lengthFeet': lengthFeet,
        'numberOfPipes': numberOfPipes,
        'weightPerPipeKg': weightPerPipeKg,
        'ratePerKg': ratePerKg,
        'gstRate': gstRate,
        'totalLengthFeet': totalLengthFeet,
        'totalWeightKg': totalWeightKg,
        'taxableAmount': taxableAmount,
        'gstAmount': gstAmount,
        'totalAmount': totalAmount,
      };

  factory SolarGiPipeCostItem.fromJson(Map<String, dynamic> json) {
    return SolarGiPipeCostItem(
      id: json['id']?.toString() ?? '',
      pipeSize: json['pipeSize']?.toString() ?? '40x40 mm',
      thicknessMm: (json['thicknessMm'] as num?)?.toDouble() ?? 1.6,
      lengthFeet: (json['lengthFeet'] as num?)?.toDouble() ?? 20.0,
      numberOfPipes: (json['numberOfPipes'] as num?)?.toInt() ?? 0,
      weightPerPipeKg: (json['weightPerPipeKg'] as num?)?.toDouble() ?? 0.0,
      ratePerKg: (json['ratePerKg'] as num?)?.toDouble() ?? 0.0,
      gstRate: (json['gstRate'] as num?)?.toDouble() ?? 18.0,
    );
  }

  SolarGiPipeCostItem copyWith({
    String? id,
    String? pipeSize,
    double? thicknessMm,
    double? lengthFeet,
    int? numberOfPipes,
    double? weightPerPipeKg,
    double? ratePerKg,
    double? gstRate,
  }) {
    return SolarGiPipeCostItem(
      id: id ?? this.id,
      pipeSize: pipeSize ?? this.pipeSize,
      thicknessMm: thicknessMm ?? this.thicknessMm,
      lengthFeet: lengthFeet ?? this.lengthFeet,
      numberOfPipes: numberOfPipes ?? this.numberOfPipes,
      weightPerPipeKg: weightPerPipeKg ?? this.weightPerPipeKg,
      ratePerKg: ratePerKg ?? this.ratePerKg,
      gstRate: gstRate ?? this.gstRate,
    );
  }
}

// -----------------------------------------------------------------------------
// 4. Other Structure Material Item
// -----------------------------------------------------------------------------
class SolarStructureCostItem {
  final String id;
  final String itemName;
  final String specification;
  final String unit; // 'KG', 'WATT', 'NOS', 'METER', 'FIXED'
  final double quantity;
  final double rate;
  final double gstRate; // e.g. 18.0%

  const SolarStructureCostItem({
    required this.id,
    required this.itemName,
    this.specification = '',
    this.unit = 'NOS',
    required this.quantity,
    required this.rate,
    this.gstRate = 18.0,
  });

  double get taxableAmount {
    if (unit.toUpperCase() == 'FIXED') {
      return quantity > 0 ? quantity * rate : rate;
    }
    return quantity * rate;
  }

  double get gstAmount => taxableAmount * (gstRate / 100.0);
  double get totalAmount => taxableAmount + gstAmount;

  Map<String, dynamic> toJson() => {
        'id': id,
        'itemName': itemName,
        'specification': specification,
        'unit': unit,
        'quantity': quantity,
        'rate': rate,
        'gstRate': gstRate,
        'taxableAmount': taxableAmount,
        'gstAmount': gstAmount,
        'totalAmount': totalAmount,
      };

  factory SolarStructureCostItem.fromJson(Map<String, dynamic> json) {
    return SolarStructureCostItem(
      id: json['id']?.toString() ?? '',
      itemName: json['itemName']?.toString() ?? '',
      specification: json['specification']?.toString() ?? '',
      unit: json['unit']?.toString() ?? 'NOS',
      quantity: (json['quantity'] as num?)?.toDouble() ?? 0.0,
      rate: (json['rate'] as num?)?.toDouble() ?? 0.0,
      gstRate: (json['gstRate'] as num?)?.toDouble() ?? 18.0,
    );
  }

  SolarStructureCostItem copyWith({
    String? id,
    String? itemName,
    String? specification,
    String? unit,
    double? quantity,
    double? rate,
    double? gstRate,
  }) {
    return SolarStructureCostItem(
      id: id ?? this.id,
      itemName: itemName ?? this.itemName,
      specification: specification ?? this.specification,
      unit: unit ?? this.unit,
      quantity: quantity ?? this.quantity,
      rate: rate ?? this.rate,
      gstRate: gstRate ?? this.gstRate,
    );
  }
}

// -----------------------------------------------------------------------------
// 5. Electrical BOS Material Item
// -----------------------------------------------------------------------------
class SolarBosCostItem {
  final String id;
  final String itemName;
  final String specification;
  final String unit; // 'FIXED', 'METER', 'NOS', 'SET'
  final double quantity;
  final double rate;
  final double gstRate; // e.g. 18.0%

  const SolarBosCostItem({
    required this.id,
    required this.itemName,
    this.specification = '',
    this.unit = 'FIXED',
    required this.quantity,
    required this.rate,
    this.gstRate = 18.0,
  });

  double get taxableAmount {
    if (unit.toUpperCase() == 'FIXED') {
      return quantity > 0 ? quantity * rate : rate;
    }
    return quantity * rate;
  }

  double get gstAmount => taxableAmount * (gstRate / 100.0);
  double get totalAmount => taxableAmount + gstAmount;

  Map<String, dynamic> toJson() => {
        'id': id,
        'itemName': itemName,
        'specification': specification,
        'unit': unit,
        'quantity': quantity,
        'rate': rate,
        'gstRate': gstRate,
        'taxableAmount': taxableAmount,
        'gstAmount': gstAmount,
        'totalAmount': totalAmount,
      };

  factory SolarBosCostItem.fromJson(Map<String, dynamic> json) {
    return SolarBosCostItem(
      id: json['id']?.toString() ?? '',
      itemName: json['itemName']?.toString() ?? '',
      specification: json['specification']?.toString() ?? '',
      unit: json['unit']?.toString() ?? 'FIXED',
      quantity: (json['quantity'] as num?)?.toDouble() ?? 0.0,
      rate: (json['rate'] as num?)?.toDouble() ?? 0.0,
      gstRate: (json['gstRate'] as num?)?.toDouble() ?? 18.0,
    );
  }

  SolarBosCostItem copyWith({
    String? id,
    String? itemName,
    String? specification,
    String? unit,
    double? quantity,
    double? rate,
    double? gstRate,
  }) {
    return SolarBosCostItem(
      id: id ?? this.id,
      itemName: itemName ?? this.itemName,
      specification: specification ?? this.specification,
      unit: unit ?? this.unit,
      quantity: quantity ?? this.quantity,
      rate: rate ?? this.rate,
      gstRate: gstRate ?? this.gstRate,
    );
  }
}

// -----------------------------------------------------------------------------
// 6. Other Custom Material Item
// -----------------------------------------------------------------------------
class SolarOtherMaterialItem {
  final String id;
  final String materialName;
  final String specification;
  final String unit;
  final double quantity;
  final double rate;
  final double gstRate; // e.g. 18.0%

  const SolarOtherMaterialItem({
    required this.id,
    required this.materialName,
    this.specification = '',
    this.unit = 'NOS',
    required this.quantity,
    required this.rate,
    this.gstRate = 18.0,
  });

  double get taxableAmount => quantity * rate;
  double get gstAmount => taxableAmount * (gstRate / 100.0);
  double get totalAmount => taxableAmount + gstAmount;

  Map<String, dynamic> toJson() => {
        'id': id,
        'materialName': materialName,
        'specification': specification,
        'unit': unit,
        'quantity': quantity,
        'rate': rate,
        'gstRate': gstRate,
        'taxableAmount': taxableAmount,
        'gstAmount': gstAmount,
        'totalAmount': totalAmount,
      };

  factory SolarOtherMaterialItem.fromJson(Map<String, dynamic> json) {
    return SolarOtherMaterialItem(
      id: json['id']?.toString() ?? '',
      materialName: json['materialName']?.toString() ?? '',
      specification: json['specification']?.toString() ?? '',
      unit: json['unit']?.toString() ?? 'NOS',
      quantity: (json['quantity'] as num?)?.toDouble() ?? 0.0,
      rate: (json['rate'] as num?)?.toDouble() ?? 0.0,
      gstRate: (json['gstRate'] as num?)?.toDouble() ?? 18.0,
    );
  }

  SolarOtherMaterialItem copyWith({
    String? id,
    String? materialName,
    String? specification,
    String? unit,
    double? quantity,
    double? rate,
    double? gstRate,
  }) {
    return SolarOtherMaterialItem(
      id: id ?? this.id,
      materialName: materialName ?? this.materialName,
      specification: specification ?? this.specification,
      unit: unit ?? this.unit,
      quantity: quantity ?? this.quantity,
      rate: rate ?? this.rate,
      gstRate: gstRate ?? this.gstRate,
    );
  }
}

// -----------------------------------------------------------------------------
// 7. Labour Cost (EXACTLY THREE CATEGORIES)
// -----------------------------------------------------------------------------
class LabourCategoryDetail {
  final String description;
  final double? quantity;
  final double? rate;
  final double fixedAmount;

  const LabourCategoryDetail({
    this.description = '',
    this.quantity,
    this.rate,
    this.fixedAmount = 0.0,
  });

  double get amount {
    if (quantity != null && rate != null && quantity! > 0 && rate! > 0) {
      return quantity! * rate!;
    }
    return fixedAmount;
  }

  Map<String, dynamic> toJson() => {
        'description': description,
        'quantity': quantity,
        'rate': rate,
        'fixedAmount': fixedAmount,
        'amount': amount,
      };

  factory LabourCategoryDetail.fromJson(Map<String, dynamic> json) {
    return LabourCategoryDetail(
      description: json['description']?.toString() ?? '',
      quantity: (json['quantity'] as num?)?.toDouble(),
      rate: (json['rate'] as num?)?.toDouble(),
      fixedAmount: (json['fixedAmount'] as num?)?.toDouble() ?? (json['amount'] as num?)?.toDouble() ?? 0.0,
    );
  }

  LabourCategoryDetail copyWith({
    String? description,
    double? quantity,
    double? rate,
    double? fixedAmount,
  }) {
    return LabourCategoryDetail(
      description: description ?? this.description,
      quantity: quantity ?? this.quantity,
      rate: rate ?? this.rate,
      fixedAmount: fixedAmount ?? this.fixedAmount,
    );
  }
}

class SolarLabourCost {
  final LabourCategoryDetail wiringLabour;
  final LabourCategoryDetail structureLabour;
  final LabourCategoryDetail civilLabour;

  const SolarLabourCost({
    this.wiringLabour = const LabourCategoryDetail(),
    this.structureLabour = const LabourCategoryDetail(),
    this.civilLabour = const LabourCategoryDetail(),
  });

  double get totalWiring => wiringLabour.amount;
  double get totalStructure => structureLabour.amount;
  double get totalCivil => civilLabour.amount;
  double get totalLabour => totalWiring + totalStructure + totalCivil;

  Map<String, dynamic> toJson() => {
        'wiringLabour': wiringLabour.toJson(),
        'structureLabour': structureLabour.toJson(),
        'civilLabour': civilLabour.toJson(),
        'totalWiring': totalWiring,
        'totalStructure': totalStructure,
        'totalCivil': totalCivil,
        'totalLabour': totalLabour,
      };

  factory SolarLabourCost.fromJson(Map<String, dynamic> json) {
    return SolarLabourCost(
      wiringLabour: json['wiringLabour'] is Map<String, dynamic>
          ? LabourCategoryDetail.fromJson(json['wiringLabour'] as Map<String, dynamic>)
          : LabourCategoryDetail(fixedAmount: (json['totalWiring'] as num?)?.toDouble() ?? 0.0),
      structureLabour: json['structureLabour'] is Map<String, dynamic>
          ? LabourCategoryDetail.fromJson(json['structureLabour'] as Map<String, dynamic>)
          : LabourCategoryDetail(fixedAmount: (json['totalStructure'] as num?)?.toDouble() ?? 0.0),
      civilLabour: json['civilLabour'] is Map<String, dynamic>
          ? LabourCategoryDetail.fromJson(json['civilLabour'] as Map<String, dynamic>)
          : LabourCategoryDetail(fixedAmount: (json['totalCivil'] as num?)?.toDouble() ?? 0.0),
    );
  }

  SolarLabourCost copyWith({
    LabourCategoryDetail? wiringLabour,
    LabourCategoryDetail? structureLabour,
    LabourCategoryDetail? civilLabour,
  }) {
    return SolarLabourCost(
      wiringLabour: wiringLabour ?? this.wiringLabour,
      structureLabour: structureLabour ?? this.structureLabour,
      civilLabour: civilLabour ?? this.civilLabour,
    );
  }
}

// -----------------------------------------------------------------------------
// 8. Other Expenses Item
// -----------------------------------------------------------------------------
class SolarCustomExpenseItem {
  final String id;
  final String description;
  final double amount;

  const SolarCustomExpenseItem({
    required this.id,
    required this.description,
    required this.amount,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'description': description,
        'amount': amount,
      };

  factory SolarCustomExpenseItem.fromJson(Map<String, dynamic> json) {
    return SolarCustomExpenseItem(
      id: json['id']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class SolarOtherExpenses {
  final double transportation;
  final double loadingUnloading;
  final double otherExpenses;
  final List<SolarCustomExpenseItem> customExpenses;

  const SolarOtherExpenses({
    this.transportation = 0.0,
    this.loadingUnloading = 0.0,
    this.otherExpenses = 0.0,
    this.customExpenses = const [],
  });

  double get customExpensesTotal =>
      customExpenses.fold(0.0, (sum, item) => sum + item.amount);

  double get totalExpenses =>
      transportation + loadingUnloading + otherExpenses + customExpensesTotal;

  Map<String, dynamic> toJson() => {
        'transportation': transportation,
        'loadingUnloading': loadingUnloading,
        'otherExpenses': otherExpenses,
        'customExpenses': customExpenses.map((e) => e.toJson()).toList(),
        'totalExpenses': totalExpenses,
      };

  factory SolarOtherExpenses.fromJson(Map<String, dynamic> json) {
    return SolarOtherExpenses(
      transportation: (json['transportation'] as num?)?.toDouble() ?? 0.0,
      loadingUnloading: (json['loadingUnloading'] as num?)?.toDouble() ?? 0.0,
      otherExpenses: (json['otherExpenses'] as num?)?.toDouble() ?? (json['other_expenses'] as num?)?.toDouble() ?? 0.0,
      customExpenses: (json['customExpenses'] as List<dynamic>?)
              ?.map((e) => SolarCustomExpenseItem.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
    );
  }

  SolarOtherExpenses copyWith({
    double? transportation,
    double? loadingUnloading,
    double? otherExpenses,
    List<SolarCustomExpenseItem>? customExpenses,
  }) {
    return SolarOtherExpenses(
      transportation: transportation ?? this.transportation,
      loadingUnloading: loadingUnloading ?? this.loadingUnloading,
      otherExpenses: otherExpenses ?? this.otherExpenses,
      customExpenses: customExpenses ?? this.customExpenses,
    );
  }
}

// -----------------------------------------------------------------------------
// 9. Master Solar Site Cost Calculation Record
// -----------------------------------------------------------------------------
class SolarSiteCostCalculation {
  final String? id;
  final String calculationNumber; // e.g. "SCC-2026-0001"
  final String siteName;
  final String customerName;
  final double systemCapacityKw; // e.g. 3.3
  final DateTime calculationDate;
  final String notes;
  final bool isGstApplicable; // Toggle for including GST in final site cost

  final List<SolarPanelCostItem> panels;
  final List<SolarInverterCostItem> inverters;
  final List<SolarGiPipeCostItem> giPipes;
  final List<SolarStructureCostItem> structureItems;
  final List<SolarBosCostItem> bosItems;
  final List<SolarOtherMaterialItem> otherMaterials;
  final SolarLabourCost labour;
  final SolarOtherExpenses otherExpenses;

  final String? createdBy;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const SolarSiteCostCalculation({
    this.id,
    this.calculationNumber = '',
    required this.siteName,
    this.customerName = '',
    this.systemCapacityKw = 0.0,
    required this.calculationDate,
    this.notes = '',
    this.isGstApplicable = false, // default false so base cost matches Section 11 sample
    this.panels = const [],
    this.inverters = const [],
    this.giPipes = const [],
    this.structureItems = const [],
    this.bosItems = const [],
    this.otherMaterials = const [],
    this.labour = const SolarLabourCost(),
    this.otherExpenses = const SolarOtherExpenses(),
    this.createdBy,
    this.createdAt,
    this.updatedAt,
  });

  // ---------------------------------------------------------------------------
  // Category Taxable Subtotals
  // ---------------------------------------------------------------------------
  double get totalPanelTaxable =>
      panels.fold(0.0, (sum, p) => sum + p.taxableAmount);

  double get totalInverterTaxable =>
      inverters.fold(0.0, (sum, inv) => sum + inv.taxableAmount);

  double get totalGiPipeTaxable =>
      giPipes.fold(0.0, (sum, pipe) => sum + pipe.taxableAmount);

  double get totalStructureTaxable =>
      structureItems.fold(0.0, (sum, item) => sum + item.taxableAmount);

  double get totalBosTaxable =>
      bosItems.fold(0.0, (sum, item) => sum + item.taxableAmount);

  double get totalOtherMaterialTaxable =>
      otherMaterials.fold(0.0, (sum, item) => sum + item.taxableAmount);

  // ---------------------------------------------------------------------------
  // Category GST Subtotals
  // ---------------------------------------------------------------------------
  double get totalPanelGst =>
      panels.fold(0.0, (sum, p) => sum + p.gstAmount);

  double get totalInverterGst =>
      inverters.fold(0.0, (sum, inv) => sum + inv.gstAmount);

  double get totalGiPipeGst =>
      giPipes.fold(0.0, (sum, pipe) => sum + pipe.gstAmount);

  double get totalStructureGst =>
      structureItems.fold(0.0, (sum, item) => sum + item.gstAmount);

  double get totalBosGst =>
      bosItems.fold(0.0, (sum, item) => sum + item.gstAmount);

  double get totalOtherMaterialGst =>
      otherMaterials.fold(0.0, (sum, item) => sum + item.gstAmount);

  double get totalGstAmount =>
      totalPanelGst +
      totalInverterGst +
      totalGiPipeGst +
      totalStructureGst +
      totalBosGst +
      totalOtherMaterialGst;

  // ---------------------------------------------------------------------------
  // Category Effective Subtotals (Respects isGstApplicable)
  // ---------------------------------------------------------------------------
  double get totalPanelCost => isGstApplicable
      ? panels.fold(0.0, (sum, p) => sum + p.totalAmount)
      : totalPanelTaxable;

  double get totalInverterCost => isGstApplicable
      ? inverters.fold(0.0, (sum, inv) => sum + inv.totalAmount)
      : totalInverterTaxable;

  double get totalGiPipeCost => isGstApplicable
      ? giPipes.fold(0.0, (sum, pipe) => sum + pipe.totalAmount)
      : totalGiPipeTaxable;

  double get totalStructureCost => isGstApplicable
      ? structureItems.fold(0.0, (sum, item) => sum + item.totalAmount)
      : totalStructureTaxable;

  double get totalBosCost => isGstApplicable
      ? bosItems.fold(0.0, (sum, item) => sum + item.totalAmount)
      : totalBosTaxable;

  double get totalOtherMaterialCost => isGstApplicable
      ? otherMaterials.fold(0.0, (sum, item) => sum + item.totalAmount)
      : totalOtherMaterialTaxable;

  double get totalWiringLabour => labour.totalWiring;
  double get totalStructureLabour => labour.totalStructure;
  double get totalCivilLabour => labour.totalCivil;
  double get totalLabourCost => labour.totalLabour;

  double get totalOtherExpensesCost => otherExpenses.totalExpenses;

  /// Total Taxable / Base Material + Labour + Expenses Cost (Without GST)
  double get totalTaxableCost =>
      totalPanelTaxable +
      totalInverterTaxable +
      totalGiPipeTaxable +
      totalStructureTaxable +
      totalBosTaxable +
      totalOtherMaterialTaxable;

  /// Pure Net Cost without GST (Base Material + Labour + Expenses)
  double get finalSiteCostWithoutGst =>
      totalTaxableCost + totalLabourCost + totalOtherExpensesCost;

  /// Total Cost with GST (Base Material + GST + Labour + Expenses)
  double get finalSiteCostWithGst =>
      totalTaxableCost + totalGstAmount + totalLabourCost + totalOtherExpensesCost;

  /// Effective Final Site Cost (Dependent on isGstApplicable toggle)
  double get finalSiteCost =>
      isGstApplicable ? finalSiteCostWithGst : finalSiteCostWithoutGst;

  /// Cost Per kW = Final Site Cost ÷ System Capacity
  double get costPerKw {
    if (systemCapacityKw > 0) {
      return finalSiteCost / systemCapacityKw;
    }
    final totalWatts = panels.fold(0.0, (sum, p) => sum + p.totalWattage);
    if (totalWatts > 0) {
      final kw = totalWatts / 1000.0;
      return finalSiteCost / kw;
    }
    return 0.0;
  }

  /// Total system wattage calculated from panels
  double get totalSystemWattage =>
      panels.fold(0.0, (sum, p) => sum + p.totalWattage);

  Map<String, dynamic> toJson() => {
        if (id != null) 'id': id,
        'calculation_number': calculationNumber,
        'site_name': siteName,
        'customer_name': customerName,
        'system_capacity_kw': systemCapacityKw,
        'calculation_date': calculationDate.toIso8601String().split('T').first,
        'notes': notes,
        'is_gst_applicable': isGstApplicable,
        'total_panel_cost': totalPanelCost,
        'total_inverter_cost': totalInverterCost,
        'total_gi_pipe_cost': totalGiPipeCost,
        'total_structure_cost': totalStructureCost,
        'total_bos_cost': totalBosCost,
        'total_other_material_cost': totalOtherMaterialCost,
        'total_taxable_cost': totalTaxableCost,
        'total_gst_amount': totalGstAmount,
        'wiring_labour_cost': totalWiringLabour,
        'structure_labour_cost': totalStructureLabour,
        'civil_labour_cost': totalCivilLabour,
        'total_labour_cost': totalLabourCost,
        'transportation_cost': otherExpenses.transportation,
        'loading_unloading_cost': otherExpenses.loadingUnloading,
        'other_expenses_cost': otherExpenses.otherExpenses + otherExpenses.customExpensesTotal,
        'total_other_expenses': totalOtherExpensesCost,
        'final_site_cost': finalSiteCost,
        'final_site_cost_with_gst': finalSiteCostWithGst,
        'final_site_cost_without_gst': finalSiteCostWithoutGst,
        'cost_per_kw': costPerKw,
        'items_payload': {
          'isGstApplicable': isGstApplicable,
          'panels': panels.map((e) => e.toJson()).toList(),
          'inverters': inverters.map((e) => e.toJson()).toList(),
          'giPipes': giPipes.map((e) => e.toJson()).toList(),
          'structureItems': structureItems.map((e) => e.toJson()).toList(),
          'bosItems': bosItems.map((e) => e.toJson()).toList(),
          'otherMaterials': otherMaterials.map((e) => e.toJson()).toList(),
          'labour': labour.toJson(),
          'otherExpenses': otherExpenses.toJson(),
        },
        if (createdBy != null) 'created_by': createdBy,
        if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
        if (updatedAt != null) 'updated_at': updatedAt!.toIso8601String(),
      };

  factory SolarSiteCostCalculation.fromJson(Map<String, dynamic> json) {
    Map<String, dynamic> payload = {};
    if (json['items_payload'] is Map<String, dynamic>) {
      payload = json['items_payload'] as Map<String, dynamic>;
    } else if (json['items_payload'] is String) {
      try {
        payload = jsonDecode(json['items_payload'] as String) as Map<String, dynamic>;
      } catch (_) {}
    }

    final isGstApplicable = json['is_gst_applicable'] == true || payload['isGstApplicable'] == true;

    final panelList = (payload['panels'] as List<dynamic>?)
            ?.map((e) => SolarPanelCostItem.fromJson(e as Map<String, dynamic>))
            .toList() ??
        const [];

    final inverterList = (payload['inverters'] as List<dynamic>?)
            ?.map((e) => SolarInverterCostItem.fromJson(e as Map<String, dynamic>))
            .toList() ??
        const [];

    final pipeList = (payload['giPipes'] as List<dynamic>?)
            ?.map((e) => SolarGiPipeCostItem.fromJson(e as Map<String, dynamic>))
            .toList() ??
        const [];

    final structureList = (payload['structureItems'] as List<dynamic>?)
            ?.map((e) => SolarStructureCostItem.fromJson(e as Map<String, dynamic>))
            .toList() ??
        const [];

    final bosList = (payload['bosItems'] as List<dynamic>?)
            ?.map((e) => SolarBosCostItem.fromJson(e as Map<String, dynamic>))
            .toList() ??
        const [];

    final otherMatList = (payload['otherMaterials'] as List<dynamic>?)
            ?.map((e) => SolarOtherMaterialItem.fromJson(e as Map<String, dynamic>))
            .toList() ??
        const [];

    final labourObj = payload['labour'] is Map<String, dynamic>
        ? SolarLabourCost.fromJson(payload['labour'] as Map<String, dynamic>)
        : SolarLabourCost(
            wiringLabour: LabourCategoryDetail(fixedAmount: (json['wiring_labour_cost'] as num?)?.toDouble() ?? 0.0),
            structureLabour: LabourCategoryDetail(fixedAmount: (json['structure_labour_cost'] as num?)?.toDouble() ?? 0.0),
            civilLabour: LabourCategoryDetail(fixedAmount: (json['civil_labour_cost'] as num?)?.toDouble() ?? 0.0),
          );

    final expensesObj = payload['otherExpenses'] is Map<String, dynamic>
        ? SolarOtherExpenses.fromJson(payload['otherExpenses'] as Map<String, dynamic>)
        : SolarOtherExpenses(
            transportation: (json['transportation_cost'] as num?)?.toDouble() ?? 0.0,
            loadingUnloading: (json['loading_unloading_cost'] as num?)?.toDouble() ?? 0.0,
            otherExpenses: (json['other_expenses_cost'] as num?)?.toDouble() ?? 0.0,
          );

    DateTime parsedDate;
    try {
      parsedDate = DateTime.parse(json['calculation_date']?.toString() ?? DateTime.now().toIso8601String());
    } catch (_) {
      parsedDate = DateTime.now();
    }

    return SolarSiteCostCalculation(
      id: json['id']?.toString(),
      calculationNumber: json['calculation_number']?.toString() ?? '',
      siteName: json['site_name']?.toString() ?? 'Solar Site',
      customerName: json['customer_name']?.toString() ?? '',
      systemCapacityKw: (json['system_capacity_kw'] as num?)?.toDouble() ?? 0.0,
      calculationDate: parsedDate,
      notes: json['notes']?.toString() ?? '',
      isGstApplicable: isGstApplicable,
      panels: panelList,
      inverters: inverterList,
      giPipes: pipeList,
      structureItems: structureList,
      bosItems: bosList,
      otherMaterials: otherMatList,
      labour: labourObj,
      otherExpenses: expensesObj,
      createdBy: json['created_by']?.toString(),
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'].toString()) : null,
      updatedAt: json['updated_at'] != null ? DateTime.tryParse(json['updated_at'].toString()) : null,
    );
  }

  SolarSiteCostCalculation copyWith({
    String? id,
    String? calculationNumber,
    String? siteName,
    String? customerName,
    double? systemCapacityKw,
    DateTime? calculationDate,
    String? notes,
    bool? isGstApplicable,
    List<SolarPanelCostItem>? panels,
    List<SolarInverterCostItem>? inverters,
    List<SolarGiPipeCostItem>? giPipes,
    List<SolarStructureCostItem>? structureItems,
    List<SolarBosCostItem>? bosItems,
    List<SolarOtherMaterialItem>? otherMaterials,
    SolarLabourCost? labour,
    SolarOtherExpenses? otherExpenses,
    String? createdBy,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return SolarSiteCostCalculation(
      id: id ?? this.id,
      calculationNumber: calculationNumber ?? this.calculationNumber,
      siteName: siteName ?? this.siteName,
      customerName: customerName ?? this.customerName,
      systemCapacityKw: systemCapacityKw ?? this.systemCapacityKw,
      calculationDate: calculationDate ?? this.calculationDate,
      notes: notes ?? this.notes,
      isGstApplicable: isGstApplicable ?? this.isGstApplicable,
      panels: panels ?? this.panels,
      inverters: inverters ?? this.inverters,
      giPipes: giPipes ?? this.giPipes,
      structureItems: structureItems ?? this.structureItems,
      bosItems: bosItems ?? this.bosItems,
      otherMaterials: otherMaterials ?? this.otherMaterials,
      labour: labour ?? this.labour,
      otherExpenses: otherExpenses ?? this.otherExpenses,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Exact Sample Test Calculation from Section 11 of the requirement:
  /// Base Taxable Material + Labour + Expenses = ₹1,33,920.
  /// When GST is applied:
  /// - Panels (5% GST): ₹59,400 + ₹2,970 = ₹62,370
  /// - Inverters (5% GST): ₹25,000 + ₹1,250 = ₹26,250
  /// - GI Pipes (18% GST): ₹14,120 + ₹2,541.60 = ₹16,661.60
  /// - BOS (18% GST): ₹12,400 + ₹2,232 = ₹14,632
  /// Total GST = ₹8,993.60
  /// Total with GST = ₹1,42,913.60
  static SolarSiteCostCalculation createSampleTestCalculation({bool withGst = false}) {
    return SolarSiteCostCalculation(
      calculationNumber: 'SCC-TEST-SAMPLE',
      siteName: 'Sample Solar Site Test',
      customerName: 'Test Customer',
      systemCapacityKw: 3.3, // 550W * 6 = 3.3 kW
      calculationDate: DateTime.now(),
      notes: 'Sample test calculation verifying exact ₹1,33,920 site cost formula and statutory GST',
      isGstApplicable: withGst,
      panels: const [
        SolarPanelCostItem(
          id: 'p1',
          brand: 'Waaree',
          model: 'Mono PERC',
          wattage: 550.0,
          quantity: 6,
          ratePerWatt: 18.0,
          gstRate: 5.0,
        ),
      ],
      inverters: const [
        SolarInverterCostItem(
          id: 'inv1',
          brand: 'Growatt',
          model: 'MIC 3300TL-X',
          capacity: '3.3 kW',
          quantity: 1,
          fixedRate: 25000.0,
          gstRate: 5.0,
        ),
      ],
      giPipes: const [
        SolarGiPipeCostItem(
          id: 'pipe1',
          pipeSize: '40x40 mm',
          thicknessMm: 1.6,
          lengthFeet: 20.0,
          numberOfPipes: 10,
          weightPerPipeKg: 8.0,
          ratePerKg: 85.0,
          gstRate: 18.0,
        ),
        SolarGiPipeCostItem(
          id: 'pipe2',
          pipeSize: '80x40 mm',
          thicknessMm: 2.0,
          lengthFeet: 20.0,
          numberOfPipes: 5,
          weightPerPipeKg: 12.0,
          ratePerKg: 90.0,
          gstRate: 18.0,
        ),
        SolarGiPipeCostItem(
          id: 'pipe3',
          pipeSize: '40x20 mm',
          thicknessMm: 1.6,
          lengthFeet: 20.0,
          numberOfPipes: 4,
          weightPerPipeKg: 6.0,
          ratePerKg: 80.0,
          gstRate: 18.0,
        ),
      ],
      structureItems: const [],
      bosItems: const [
        SolarBosCostItem(
          id: 'bos1',
          itemName: 'ACDB',
          unit: 'FIXED',
          quantity: 1,
          rate: 2500.0,
          gstRate: 18.0,
        ),
        SolarBosCostItem(
          id: 'bos2',
          itemName: 'DCDB',
          unit: 'FIXED',
          quantity: 1,
          rate: 2200.0,
          gstRate: 18.0,
        ),
        SolarBosCostItem(
          id: 'bos3',
          itemName: 'DC Cable',
          unit: 'FIXED',
          quantity: 1,
          rate: 1750.0,
          gstRate: 18.0,
        ),
        SolarBosCostItem(
          id: 'bos4',
          itemName: 'AC Cable',
          unit: 'FIXED',
          quantity: 1,
          rate: 1950.0,
          gstRate: 18.0,
        ),
        SolarBosCostItem(
          id: 'bos5',
          itemName: 'Earthing Kit',
          unit: 'FIXED',
          quantity: 1,
          rate: 3500.0,
          gstRate: 18.0,
        ),
        SolarBosCostItem(
          id: 'bos6',
          itemName: 'MC4 Connector',
          unit: 'FIXED',
          quantity: 1,
          rate: 500.0,
          gstRate: 18.0,
        ),
      ],
      otherMaterials: const [],
      labour: const SolarLabourCost(
        wiringLabour: LabourCategoryDetail(description: 'Wiring Labour', fixedAmount: 6000.0),
        structureLabour: LabourCategoryDetail(description: 'Structure Labour', fixedAmount: 7000.0),
        civilLabour: LabourCategoryDetail(description: 'Civil Labour', fixedAmount: 5500.0),
      ),
      otherExpenses: const SolarOtherExpenses(
        transportation: 3000.0,
        loadingUnloading: 500.0,
        otherExpenses: 1000.0,
      ),
    );
  }
}
