import 'package:intl/intl.dart';

/// Represents a customer-wise and sales-person-wise commission record in SIYA INFOTECH & SOLAR ENERGY.
class SalesCommission {
  final String id;
  final String consumerId;
  final String consumerNo;
  final String customerName;
  final String siteLocation;
  final String solarCapacity;
  final double capacityKw;

  /// Customer Source: 'Sales Person' or 'Direct Customer'
  final String customerSource;

  /// Sales Person details (null or '-' for Direct Customer)
  final String? salesPersonId;
  final String? salesPersonName;

  /// Commission Rate per kW (₹)
  final double commissionRatePerKw;

  /// Total Commission (₹): Solar Capacity (kW) × Commission Rate per kW (₹0 for Direct Customers)
  final double totalCommission;

  /// Commission Status: 'Pending', 'Completed', 'Not Applicable'
  final String commissionStatus;

  final DateTime commissionDate;
  final String? remarks;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? createdBy;

  const SalesCommission({
    required this.id,
    required this.consumerId,
    required this.consumerNo,
    required this.customerName,
    required this.siteLocation,
    required this.solarCapacity,
    required this.capacityKw,
    required this.customerSource,
    this.salesPersonId,
    this.salesPersonName,
    required this.commissionRatePerKw,
    required this.totalCommission,
    required this.commissionStatus,
    required this.commissionDate,
    this.remarks,
    this.createdAt,
    this.updatedAt,
    this.createdBy,
  });

  bool get isDirectCustomer => customerSource == 'Direct Customer';
  bool get isSalesPersonCustomer => customerSource == 'Sales Person';

  bool get isPending => commissionStatus == 'Pending';
  bool get isCompleted => commissionStatus == 'Completed';
  bool get isNotApplicable => commissionStatus == 'Not Applicable' || isDirectCustomer;

  /// Effective calculated commission amount based on rules:
  /// Direct Customers must ALWAYS have zero commission!
  double get calculatedCommission {
    if (isDirectCustomer) return 0.0;
    return (capacityKw * commissionRatePerKw);
  }

  String get formattedDate => DateFormat('dd/MM/yyyy').format(commissionDate);

  factory SalesCommission.fromJson(Map<String, dynamic> json) {
    DateTime parsedDate;
    if (json['commission_date'] != null) {
      parsedDate = DateTime.tryParse(json['commission_date'].toString()) ?? DateTime.now();
    } else {
      parsedDate = DateTime.now();
    }

    final rawSource = json['customer_source']?.toString().trim();
    final source = (rawSource == 'Direct Customer' || rawSource == 'Direct')
        ? 'Direct Customer'
        : 'Sales Person';

    final capKw = (json['capacity_kw'] as num?)?.toDouble() ??
        _extractKw(json['solar_capacity']?.toString() ?? '');

    final rate = source == 'Direct Customer'
        ? 0.0
        : ((json['commission_rate_per_kw'] as num?)?.toDouble() ?? 0.0);

    final total = source == 'Direct Customer'
        ? 0.0
        : ((json['total_commission'] as num?)?.toDouble() ?? (capKw * rate));

    final rawStatus = json['commission_status']?.toString().trim() ?? '';
    final status = source == 'Direct Customer'
        ? 'Not Applicable'
        : (rawStatus.isNotEmpty ? rawStatus : 'Pending');

    return SalesCommission(
      id: json['id']?.toString() ?? '',
      consumerId: json['consumer_id']?.toString() ?? '',
      consumerNo: json['consumer_no']?.toString() ?? '',
      customerName: json['customer_name']?.toString() ?? '',
      siteLocation: json['site_location']?.toString() ?? '',
      solarCapacity: json['solar_capacity']?.toString() ?? '${capKw.toStringAsFixed(1)} kW',
      capacityKw: capKw,
      customerSource: source,
      salesPersonId: json['sales_person_id']?.toString(),
      salesPersonName: source == 'Direct Customer' ? null : json['sales_person_name']?.toString(),
      commissionRatePerKw: rate,
      totalCommission: total,
      commissionStatus: status,
      commissionDate: parsedDate,
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
      'capacity_kw': capacityKw,
      'customer_source': customerSource,
      'sales_person_id': isDirectCustomer ? null : salesPersonId,
      'sales_person_name': isDirectCustomer ? null : salesPersonName,
      'commission_rate_per_kw': isDirectCustomer ? 0.0 : commissionRatePerKw,
      'total_commission': isDirectCustomer ? 0.0 : totalCommission,
      'commission_status': isDirectCustomer ? 'Not Applicable' : commissionStatus,
      'commission_date': DateFormat('yyyy-MM-dd').format(commissionDate),
      'remarks': remarks,
      if (createdBy != null) 'created_by': createdBy,
    };
  }

  SalesCommission copyWith({
    String? id,
    String? consumerId,
    String? consumerNo,
    String? customerName,
    String? siteLocation,
    String? solarCapacity,
    double? capacityKw,
    String? customerSource,
    String? salesPersonId,
    String? salesPersonName,
    double? commissionRatePerKw,
    double? totalCommission,
    String? commissionStatus,
    DateTime? commissionDate,
    String? remarks,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? createdBy,
  }) {
    final effectiveSource = customerSource ?? this.customerSource;
    final isDirect = effectiveSource == 'Direct Customer';
    final effectiveRate = isDirect ? 0.0 : (commissionRatePerKw ?? this.commissionRatePerKw);
    final effectiveKw = capacityKw ?? this.capacityKw;
    final effectiveTotal = isDirect ? 0.0 : (totalCommission ?? (effectiveKw * effectiveRate));
    final effectiveStatus = isDirect ? 'Not Applicable' : (commissionStatus ?? this.commissionStatus);

    return SalesCommission(
      id: id ?? this.id,
      consumerId: consumerId ?? this.consumerId,
      consumerNo: consumerNo ?? this.consumerNo,
      customerName: customerName ?? this.customerName,
      siteLocation: siteLocation ?? this.siteLocation,
      solarCapacity: solarCapacity ?? this.solarCapacity,
      capacityKw: effectiveKw,
      customerSource: effectiveSource,
      salesPersonId: isDirect ? null : (salesPersonId ?? this.salesPersonId),
      salesPersonName: isDirect ? null : (salesPersonName ?? this.salesPersonName),
      commissionRatePerKw: effectiveRate,
      totalCommission: effectiveTotal,
      commissionStatus: effectiveStatus,
      commissionDate: commissionDate ?? this.commissionDate,
      remarks: remarks ?? this.remarks,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      createdBy: createdBy ?? this.createdBy,
    );
  }

  static double _extractKw(String text) {
    if (text.isEmpty) return 3.0;
    final match = RegExp(r'(\d+(?:\.\d+)?)').firstMatch(text);
    if (match != null) {
      return double.tryParse(match.group(1)!) ?? 3.0;
    }
    return 3.0;
  }
}

/// Aggregated summary row for a specific Sales Person
class SalesPersonSummary {
  final String salesPersonName;
  final int totalCustomers;
  final double totalCapacityKw;
  final double totalCommission;
  final double pendingCommission;
  final double completedCommission;

  const SalesPersonSummary({
    required this.salesPersonName,
    required this.totalCustomers,
    required this.totalCapacityKw,
    required this.totalCommission,
    required this.pendingCommission,
    required this.completedCommission,
  });
}

/// Aggregated dashboard metrics for the Commission Module
class CommissionDashboardSummary {
  final int totalCustomers;
  final int salesPersonCustomers;
  final int directCustomers;
  final double totalInstalledCapacityKw;
  final int pendingCommissionCustomers;
  final int completedCommissionCustomers;
  final int notApplicableCustomers;

  /// Sum of commission amounts with Pending status (Direct Customers excluded)
  final double totalPendingCommissionAmount;

  /// Sum of commission amounts with Completed status
  final double totalCompletedCommissionAmount;

  /// Sum of all applicable Sales Person commission records
  final double totalCommissionAmount;

  const CommissionDashboardSummary({
    required this.totalCustomers,
    required this.salesPersonCustomers,
    required this.directCustomers,
    required this.totalInstalledCapacityKw,
    required this.pendingCommissionCustomers,
    required this.completedCommissionCustomers,
    required this.notApplicableCustomers,
    required this.totalPendingCommissionAmount,
    required this.totalCompletedCommissionAmount,
    required this.totalCommissionAmount,
  });

  factory CommissionDashboardSummary.fromCommissions(List<SalesCommission> list) {
    int salesPersonCount = 0;
    int directCount = 0;
    double capacitySum = 0.0;
    int pendingCount = 0;
    int completedCount = 0;
    int notApplicableCount = 0;
    double pendingAmount = 0.0;
    double completedAmount = 0.0;
    double totalCommission = 0.0;

    for (final c in list) {
      capacitySum += c.capacityKw;

      if (c.isDirectCustomer) {
        directCount++;
        notApplicableCount++;
        // Direct customers must ALWAYS be excluded from pending and completed commission totals
      } else {
        salesPersonCount++;
        totalCommission += c.totalCommission;

        if (c.isPending) {
          pendingCount++;
          pendingAmount += c.totalCommission;
        } else if (c.isCompleted) {
          completedCount++;
          completedAmount += c.totalCommission;
        } else {
          notApplicableCount++;
        }
      }
    }

    return CommissionDashboardSummary(
      totalCustomers: list.length,
      salesPersonCustomers: salesPersonCount,
      directCustomers: directCount,
      totalInstalledCapacityKw: capacitySum,
      pendingCommissionCustomers: pendingCount,
      completedCommissionCustomers: completedCount,
      notApplicableCustomers: notApplicableCount,
      totalPendingCommissionAmount: pendingAmount,
      totalCompletedCommissionAmount: completedAmount,
      totalCommissionAmount: totalCommission,
    );
  }

  /// Groups commissions by Sales Person (excluding Direct Customers)
  static List<SalesPersonSummary> buildSalesPersonSummaries(List<SalesCommission> list) {
    final Map<String, List<SalesCommission>> grouped = {};

    for (final c in list) {
      if (c.isDirectCustomer) continue;
      final name = (c.salesPersonName?.trim().isNotEmpty == true)
          ? c.salesPersonName!.trim()
          : 'Unassigned Sales Person';
      grouped.putIfAbsent(name, () => []).add(c);
    }

    final summaries = <SalesPersonSummary>[];
    for (final entry in grouped.entries) {
      final name = entry.key;
      final items = entry.value;

      double kw = 0.0;
      double total = 0.0;
      double pending = 0.0;
      double completed = 0.0;

      for (final item in items) {
        kw += item.capacityKw;
        total += item.totalCommission;
        if (item.isPending) pending += item.totalCommission;
        if (item.isCompleted) completed += item.totalCommission;
      }

      summaries.add(SalesPersonSummary(
        salesPersonName: name,
        totalCustomers: items.length,
        totalCapacityKw: kw,
        totalCommission: total,
        pendingCommission: pending,
        completedCommission: completed,
      ));
    }

    summaries.sort((a, b) => b.totalCommission.compareTo(a.totalCommission));
    return summaries;
  }
}
