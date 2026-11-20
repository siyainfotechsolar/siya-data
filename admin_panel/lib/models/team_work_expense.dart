import '../utils/consumer_no_utils.dart';

/// Represents an individual person-wise site work expense entry
/// for Structure, Wiring, or Civil team tasks.
class TeamWorkExpense {
  final String id;
  final String? consumerId;
  final String consumerNo;
  final String customerName;
  final String siteLocation;
  final String solarCapacity;
  final DateTime workDate;
  final String workCategory; // 'Structure', 'Wiring', 'Civil'
  final String? teamMemberId;
  final String teamMemberName;
  final double individualExpense;
  final String remarks;
  final String? createdBy;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const TeamWorkExpense({
    required this.id,
    this.consumerId,
    required this.consumerNo,
    required this.customerName,
    this.siteLocation = '',
    this.solarCapacity = '',
    required this.workDate,
    required this.workCategory,
    this.teamMemberId,
    required this.teamMemberName,
    required this.individualExpense,
    this.remarks = '',
    this.createdBy,
    this.createdAt,
    this.updatedAt,
  });

  bool get isStructure => workCategory.toLowerCase() == 'structure';
  bool get isWiring => workCategory.toLowerCase() == 'wiring';
  bool get isCivil => workCategory.toLowerCase() == 'civil';

  String get normalizedConsumerNo => ConsumerNoNormalizer.normalize(consumerNo);

  factory TeamWorkExpense.fromJson(Map<String, dynamic> json) {
    DateTime parsedDate;
    if (json['work_date'] != null) {
      parsedDate = DateTime.tryParse(json['work_date'].toString()) ?? DateTime.now();
    } else {
      parsedDate = DateTime.now();
    }

    return TeamWorkExpense(
      id: json['id']?.toString() ?? '',
      consumerId: json['consumer_id']?.toString(),
      consumerNo: json['consumer_no']?.toString() ?? '',
      customerName: json['customer_name']?.toString() ?? '',
      siteLocation: json['site_location']?.toString() ?? '',
      solarCapacity: json['solar_capacity']?.toString() ?? '',
      workDate: parsedDate,
      workCategory: json['work_category']?.toString() ?? 'Structure',
      teamMemberId: json['team_member_id']?.toString(),
      teamMemberName: json['team_member_name']?.toString() ?? '',
      individualExpense: (json['individual_expense'] as num?)?.toDouble() ?? 0.0,
      remarks: json['remarks']?.toString() ?? '',
      createdBy: json['created_by']?.toString(),
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'].toString()) : null,
      updatedAt: json['updated_at'] != null ? DateTime.tryParse(json['updated_at'].toString()) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      if (consumerId != null) 'consumer_id': consumerId,
      'consumer_no': consumerNo,
      'customer_name': customerName,
      'site_location': siteLocation,
      'solar_capacity': solarCapacity,
      'work_date': "${workDate.year.toString().padLeft(4, '0')}-${workDate.month.toString().padLeft(2, '0')}-${workDate.day.toString().padLeft(2, '0')}",
      'work_category': workCategory,
      if (teamMemberId != null) 'team_member_id': teamMemberId,
      'team_member_name': teamMemberName,
      'individual_expense': individualExpense,
      'remarks': remarks,
      if (createdBy != null) 'created_by': createdBy,
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
      if (updatedAt != null) 'updated_at': updatedAt!.toIso8601String(),
    };
  }

  TeamWorkExpense copyWith({
    String? id,
    String? consumerId,
    String? consumerNo,
    String? customerName,
    String? siteLocation,
    String? solarCapacity,
    DateTime? workDate,
    String? workCategory,
    String? teamMemberId,
    String? teamMemberName,
    double? individualExpense,
    String? remarks,
    String? createdBy,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return TeamWorkExpense(
      id: id ?? this.id,
      consumerId: consumerId ?? this.consumerId,
      consumerNo: consumerNo ?? this.consumerNo,
      customerName: customerName ?? this.customerName,
      siteLocation: siteLocation ?? this.siteLocation,
      solarCapacity: solarCapacity ?? this.solarCapacity,
      workDate: workDate ?? this.workDate,
      workCategory: workCategory ?? this.workCategory,
      teamMemberId: teamMemberId ?? this.teamMemberId,
      teamMemberName: teamMemberName ?? this.teamMemberName,
      individualExpense: individualExpense ?? this.individualExpense,
      remarks: remarks ?? this.remarks,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

/// Person-wise Expense Summary aggregator
class PersonExpenseSummary {
  final String teamMemberName;
  final double structureExpense;
  final double wiringExpense;
  final double civilExpense;
  final double totalExpense;
  final int totalSites;
  final Set<String> siteConsumerNos;

  const PersonExpenseSummary({
    required this.teamMemberName,
    required this.structureExpense,
    required this.wiringExpense,
    required this.civilExpense,
    required this.totalExpense,
    required this.totalSites,
    required this.siteConsumerNos,
  });

  factory PersonExpenseSummary.fromExpenses(String personName, List<TeamWorkExpense> expenses) {
    double struct = 0.0;
    double wire = 0.0;
    double civ = 0.0;
    final sites = <String>{};

    for (final e in expenses) {
      final cat = e.workCategory.trim().toLowerCase();
      if (cat == 'structure') {
        struct += e.individualExpense;
      } else if (cat == 'wiring') {
        wire += e.individualExpense;
      } else if (cat == 'civil') {
        civ += e.individualExpense;
      }
      final normSite = ConsumerNoNormalizer.normalize(e.consumerNo);
      if (normSite.isNotEmpty) {
        sites.add(normSite);
      }
    }

    return PersonExpenseSummary(
      teamMemberName: personName,
      structureExpense: struct,
      wiringExpense: wire,
      civilExpense: civ,
      totalExpense: struct + wire + civ,
      totalSites: sites.length,
      siteConsumerNos: sites,
    );
  }
}

/// Customer-wise Expense Summary aggregator
class CustomerExpenseSummary {
  final String customerName;
  final String consumerNo;
  final String siteLocation;
  final String solarCapacity;
  final double structureExpense;
  final double wiringExpense;
  final double civilExpense;
  final double totalSiteExpense;
  final int entriesCount;
  final List<TeamWorkExpense> entries;

  const CustomerExpenseSummary({
    required this.customerName,
    required this.consumerNo,
    required this.siteLocation,
    required this.solarCapacity,
    required this.structureExpense,
    required this.wiringExpense,
    required this.civilExpense,
    required this.totalSiteExpense,
    required this.entriesCount,
    required this.entries,
  });

  factory CustomerExpenseSummary.fromEntries(
    String consumerNo,
    String customerName,
    String siteLocation,
    String solarCapacity,
    List<TeamWorkExpense> entries,
  ) {
    double struct = 0.0;
    double wire = 0.0;
    double civ = 0.0;

    for (final e in entries) {
      final cat = e.workCategory.trim().toLowerCase();
      if (cat == 'structure') {
        struct += e.individualExpense;
      } else if (cat == 'wiring') {
        wire += e.individualExpense;
      } else if (cat == 'civil') {
        civ += e.individualExpense;
      }
    }

    return CustomerExpenseSummary(
      customerName: customerName,
      consumerNo: consumerNo,
      siteLocation: siteLocation,
      solarCapacity: solarCapacity,
      structureExpense: struct,
      wiringExpense: wire,
      civilExpense: civ,
      totalSiteExpense: struct + wire + civ,
      entriesCount: entries.length,
      entries: entries,
    );
  }
}

/// Category-wise Expense Summary aggregator
class CategoryExpenseSummary {
  final String workCategory; // 'Structure', 'Wiring', 'Civil'
  final int totalWorkers;
  final int totalSites;
  final double totalExpense;

  const CategoryExpenseSummary({
    required this.workCategory,
    required this.totalWorkers,
    required this.totalSites,
    required this.totalExpense,
  });
}

/// Dashboard metrics aggregator
class TeamWorkDashboardSummary {
  final int totalSites;
  final int totalTeamMembers;
  final double totalStructureExpense;
  final double totalWiringExpense;
  final double totalCivilExpense;
  final double grandTotalExpense;

  const TeamWorkDashboardSummary({
    required this.totalSites,
    required this.totalTeamMembers,
    required this.totalStructureExpense,
    required this.totalWiringExpense,
    required this.totalCivilExpense,
    required this.grandTotalExpense,
  });

  factory TeamWorkDashboardSummary.calculate(
    List<TeamWorkExpense> expenses, {
    int? customTeamMemberCount,
  }) {
    final sites = <String>{};
    final workers = <String>{};
    double struct = 0.0;
    double wire = 0.0;
    double civ = 0.0;

    for (final e in expenses) {
      final normSite = ConsumerNoNormalizer.normalize(e.consumerNo);
      if (normSite.isNotEmpty) sites.add(normSite);

      final w = e.teamMemberName.trim().toLowerCase();
      if (w.isNotEmpty) workers.add(w);

      final cat = e.workCategory.trim().toLowerCase();
      if (cat == 'structure') {
        struct += e.individualExpense;
      } else if (cat == 'wiring') {
        wire += e.individualExpense;
      } else if (cat == 'civil') {
        civ += e.individualExpense;
      }
    }

    final workerCount = customTeamMemberCount != null && customTeamMemberCount > 0
        ? customTeamMemberCount
        : workers.length;

    return TeamWorkDashboardSummary(
      totalSites: sites.length,
      totalTeamMembers: workerCount,
      totalStructureExpense: struct,
      totalWiringExpense: wire,
      totalCivilExpense: civ,
      grandTotalExpense: struct + wire + civ,
    );
  }
}
