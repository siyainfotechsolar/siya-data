import 'package:intl/intl.dart';

/// Represents a site-wise team expense entry in SIYA INFOTECH & SOLAR ENERGY software
class SiteTeamExpense {
  final String id;
  final String consumerId;
  final String consumerNo;
  final String customerName;
  final String siteLocation;
  final String solarCapacity;
  final DateTime expenseDate;
  final double wiringExpense;
  final double civilExpense;
  final double structureExpense;
  final String? remarks;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? createdBy;

  const SiteTeamExpense({
    required this.id,
    required this.consumerId,
    required this.consumerNo,
    required this.customerName,
    required this.siteLocation,
    required this.solarCapacity,
    required this.expenseDate,
    required this.wiringExpense,
    required this.civilExpense,
    required this.structureExpense,
    this.remarks,
    this.createdAt,
    this.updatedAt,
    this.createdBy,
  });

  /// Automatic Customer-wise Calculation:
  /// Total Site Expense = Wiring Expense + Civil Expense + Structure Expense
  double get totalSiteExpense => wiringExpense + civilExpense + structureExpense;

  bool get hasWiringExpense => wiringExpense > 0;
  bool get hasCivilExpense => civilExpense > 0;
  bool get hasStructureExpense => structureExpense > 0;

  String get formattedDate => DateFormat('dd/MM/yyyy').format(expenseDate);

  factory SiteTeamExpense.fromJson(Map<String, dynamic> json) {
    DateTime parsedDate;
    if (json['expense_date'] != null) {
      parsedDate = DateTime.tryParse(json['expense_date'].toString()) ?? DateTime.now();
    } else {
      parsedDate = DateTime.now();
    }

    return SiteTeamExpense(
      id: json['id']?.toString() ?? '',
      consumerId: json['consumer_id']?.toString() ?? '',
      consumerNo: json['consumer_no']?.toString() ?? '',
      customerName: json['customer_name']?.toString() ?? '',
      siteLocation: json['site_location']?.toString() ?? '',
      solarCapacity: json['solar_capacity']?.toString() ?? '',
      expenseDate: parsedDate,
      wiringExpense: (json['wiring_expense'] as num?)?.toDouble() ?? 0.0,
      civilExpense: (json['civil_expense'] as num?)?.toDouble() ?? 0.0,
      structureExpense: (json['structure_expense'] as num?)?.toDouble() ?? 0.0,
      remarks: json['remarks'] as String?,
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'].toString()) : null,
      updatedAt: json['updated_at'] != null ? DateTime.tryParse(json['updated_at'].toString()) : null,
      createdBy: json['created_by'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id.isNotEmpty) 'id': id,
      'consumer_id': consumerId,
      'consumer_no': consumerNo,
      'customer_name': customerName,
      'site_location': siteLocation,
      'solar_capacity': solarCapacity,
      'expense_date': DateFormat('yyyy-MM-dd').format(expenseDate),
      'wiring_expense': wiringExpense,
      'civil_expense': civilExpense,
      'structure_expense': structureExpense,
      'remarks': remarks,
      if (createdBy != null) 'created_by': createdBy,
    };
  }

  SiteTeamExpense copyWith({
    String? id,
    String? consumerId,
    String? consumerNo,
    String? customerName,
    String? siteLocation,
    String? solarCapacity,
    DateTime? expenseDate,
    double? wiringExpense,
    double? civilExpense,
    double? structureExpense,
    String? remarks,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? createdBy,
  }) {
    return SiteTeamExpense(
      id: id ?? this.id,
      consumerId: consumerId ?? this.consumerId,
      consumerNo: consumerNo ?? this.consumerNo,
      customerName: customerName ?? this.customerName,
      siteLocation: siteLocation ?? this.siteLocation,
      solarCapacity: solarCapacity ?? this.solarCapacity,
      expenseDate: expenseDate ?? this.expenseDate,
      wiringExpense: wiringExpense ?? this.wiringExpense,
      civilExpense: civilExpense ?? this.civilExpense,
      structureExpense: structureExpense ?? this.structureExpense,
      remarks: remarks ?? this.remarks,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      createdBy: createdBy ?? this.createdBy,
    );
  }
}

/// Aggregated dashboard & report totals for team expenses
class TeamExpenseSummary {
  final int totalSites;
  final double totalWiringExpense;
  final double totalCivilExpense;
  final double totalStructureExpense;
  final double grandTotalExpense;
  final int wiringSitesCount;
  final int civilSitesCount;
  final int structureSitesCount;

  const TeamExpenseSummary({
    required this.totalSites,
    required this.totalWiringExpense,
    required this.totalCivilExpense,
    required this.totalStructureExpense,
    required this.grandTotalExpense,
    required this.wiringSitesCount,
    required this.civilSitesCount,
    required this.structureSitesCount,
  });

  factory TeamExpenseSummary.fromExpenses(List<SiteTeamExpense> expenses) {
    double wiringSum = 0;
    double civilSum = 0;
    double structureSum = 0;
    int wiringSites = 0;
    int civilSites = 0;
    int structureSites = 0;

    for (final exp in expenses) {
      wiringSum += exp.wiringExpense;
      civilSum += exp.civilExpense;
      structureSum += exp.structureExpense;

      if (exp.wiringExpense > 0) wiringSites++;
      if (exp.civilExpense > 0) civilSites++;
      if (exp.structureExpense > 0) structureSites++;
    }

    final grandTotal = wiringSum + civilSum + structureSum;

    return TeamExpenseSummary(
      totalSites: expenses.length,
      totalWiringExpense: wiringSum,
      totalCivilExpense: civilSum,
      totalStructureExpense: structureSum,
      grandTotalExpense: grandTotal,
      wiringSitesCount: wiringSites,
      civilSitesCount: civilSites,
      structureSitesCount: structureSites,
    );
  }
}
