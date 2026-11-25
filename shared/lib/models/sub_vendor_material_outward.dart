import 'dart:convert';

/// Represents an item in the Material Master with available inventory stock.
class MaterialMasterItem {
  final String id;
  final String itemName;
  final String unit;
  final String category;
  final String? specification;
  final double defaultRate;
  final double availableStock;
  final bool isActive;
  final int displayOrder;

  const MaterialMasterItem({
    required this.id,
    required this.itemName,
    this.unit = 'NOS',
    this.category = 'OTHER',
    this.specification,
    this.defaultRate = 0.0,
    this.availableStock = 500.0,
    this.isActive = true,
    this.displayOrder = 0,
  });

  factory MaterialMasterItem.fromJson(Map<String, dynamic> json) {
    return MaterialMasterItem(
      id: json['id']?.toString() ?? '',
      itemName: json['item_name']?.toString() ?? '',
      unit: (json['unit']?.toString() ?? 'NOS').toUpperCase(),
      category: json['category']?.toString() ?? 'OTHER',
      specification: json['specification']?.toString(),
      defaultRate: (json['default_rate'] as num?)?.toDouble() ?? 0.0,
      availableStock: (json['available_stock'] as num?)?.toDouble() ?? 500.0,
      isActive: json['is_active'] as bool? ?? true,
      displayOrder: (json['display_order'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'item_name': itemName,
        'unit': unit,
        'category': category,
        if (specification != null) 'specification': specification,
        'default_rate': defaultRate,
        'available_stock': availableStock,
        'is_active': isActive,
        'display_order': displayOrder,
      };

  MaterialMasterItem copyWith({
    String? id,
    String? itemName,
    String? unit,
    String? category,
    String? specification,
    double? defaultRate,
    double? availableStock,
    bool? isActive,
    int? displayOrder,
  }) {
    return MaterialMasterItem(
      id: id ?? this.id,
      itemName: itemName ?? this.itemName,
      unit: unit ?? this.unit,
      category: category ?? this.category,
      specification: specification ?? this.specification,
      defaultRate: defaultRate ?? this.defaultRate,
      availableStock: availableStock ?? this.availableStock,
      isActive: isActive ?? this.isActive,
      displayOrder: displayOrder ?? this.displayOrder,
    );
  }
}

/// Represents an individual material line item issued in a Material Outward transaction.
class SubVendorMaterialOutwardItem {
  final String id;
  final String outwardId;
  final String? materialId;
  final String materialName;
  final String unit;
  final double quantity;
  final double unitRate;
  final double baseAmount;
  final double gstPercentage;
  final double gstAmount;
  final double totalPrice;
  final DateTime? createdAt;

  const SubVendorMaterialOutwardItem({
    required this.id,
    required this.outwardId,
    this.materialId,
    required this.materialName,
    this.unit = 'NOS',
    required this.quantity,
    this.unitRate = 0.0,
    this.baseAmount = 0.0,
    this.gstPercentage = 0.0,
    this.gstAmount = 0.0,
    this.totalPrice = 0.0,
    this.createdAt,
  });

  factory SubVendorMaterialOutwardItem.fromJson(Map<String, dynamic> json) {
    final qty = (json['quantity'] as num?)?.toDouble() ?? 0.0;
    final rate = (json['unit_rate'] as num?)?.toDouble() ?? 0.0;
    final base = (json['base_amount'] as num?)?.toDouble() ?? (qty * rate);
    final gstPct = (json['gst_percentage'] as num?)?.toDouble() ?? 0.0;
    final gstAmt = (json['gst_amount'] as num?)?.toDouble() ?? (base * gstPct / 100.0);
    final price = (json['total_price'] as num?)?.toDouble() ?? (base + gstAmt);

    return SubVendorMaterialOutwardItem(
      id: json['id']?.toString() ?? '',
      outwardId: json['outward_id']?.toString() ?? '',
      materialId: json['material_id']?.toString(),
      materialName: json['material_name']?.toString() ?? '',
      unit: (json['unit']?.toString() ?? 'NOS').toUpperCase(),
      quantity: qty,
      unitRate: rate,
      baseAmount: base,
      gstPercentage: gstPct,
      gstAmount: gstAmt,
      totalPrice: price,
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'].toString()) : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'outward_id': outwardId,
        if (materialId != null) 'material_id': materialId,
        'material_name': materialName,
        'unit': unit,
        'quantity': quantity,
        'unit_rate': unitRate,
        'base_amount': baseAmount,
        'gst_percentage': gstPercentage,
        'gst_amount': gstAmount,
        'total_price': totalPrice,
        if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
      };

  SubVendorMaterialOutwardItem copyWith({
    String? id,
    String? outwardId,
    String? materialId,
    String? materialName,
    String? unit,
    double? quantity,
    double? unitRate,
    double? baseAmount,
    double? gstPercentage,
    double? gstAmount,
    double? totalPrice,
    DateTime? createdAt,
  }) {
    return SubVendorMaterialOutwardItem(
      id: id ?? this.id,
      outwardId: outwardId ?? this.outwardId,
      materialId: materialId ?? this.materialId,
      materialName: materialName ?? this.materialName,
      unit: unit ?? this.unit,
      quantity: quantity ?? this.quantity,
      unitRate: unitRate ?? this.unitRate,
      baseAmount: baseAmount ?? this.baseAmount,
      gstPercentage: gstPercentage ?? this.gstPercentage,
      gstAmount: gstAmount ?? this.gstAmount,
      totalPrice: totalPrice ?? this.totalPrice,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

/// Represents a Material Outward transaction header issued to a Sub-Vendor.
class SubVendorMaterialOutward {
  final String id;
  final String outwardNumber; // e.g. OUT-20261125-0001
  final String vendorId;
  final String vendorName;
  final DateTime outwardDate;
  final int totalItems;
  final double totalQuantity;
  final double subtotal;
  final double totalGst;
  final double totalValue;
  final String? remarks;
  final String status; // 'Active', 'Cancelled'
  final DateTime? cancelledAt;
  final String? cancelledBy;
  final String? cancellationReason;
  final List<SubVendorMaterialOutwardItem> items;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? createdBy;

  const SubVendorMaterialOutward({
    required this.id,
    required this.outwardNumber,
    required this.vendorId,
    required this.vendorName,
    required this.outwardDate,
    this.totalItems = 0,
    this.totalQuantity = 0.0,
    this.subtotal = 0.0,
    this.totalGst = 0.0,
    this.totalValue = 0.0,
    this.remarks,
    this.status = 'Active',
    this.cancelledAt,
    this.cancelledBy,
    this.cancellationReason,
    this.items = const [],
    this.createdAt,
    this.updatedAt,
    this.createdBy,
  });

  bool get isActive => status.toUpperCase() == 'ACTIVE';
  bool get isCancelled => status.toUpperCase() == 'CANCELLED';

  factory SubVendorMaterialOutward.fromJson(Map<String, dynamic> json) {
    List<SubVendorMaterialOutwardItem> parsedItems = [];
    if (json['items'] is List) {
      parsedItems = (json['items'] as List)
          .map((i) => SubVendorMaterialOutwardItem.fromJson(i as Map<String, dynamic>))
          .toList();
    } else if (json['sub_vendor_material_outward_items'] is List) {
      parsedItems = (json['sub_vendor_material_outward_items'] as List)
          .map((i) => SubVendorMaterialOutwardItem.fromJson(i as Map<String, dynamic>))
          .toList();
    }

    final totalItems = (json['total_items'] as num?)?.toInt() ?? parsedItems.length;
    final double totalQuantity = (json['total_quantity'] as num?)?.toDouble() ??
        parsedItems.fold<double>(0.0, (double sum, i) => sum + i.quantity);
    final double subtotal = (json['subtotal'] as num?)?.toDouble() ??
        parsedItems.fold<double>(0.0, (double sum, i) => sum + i.baseAmount);
    final double totalGst = (json['total_gst'] as num?)?.toDouble() ??
        parsedItems.fold<double>(0.0, (double sum, i) => sum + i.gstAmount);
    final double totalValue = (json['total_value'] as num?)?.toDouble() ??
        parsedItems.fold<double>(0.0, (double sum, i) => sum + i.totalPrice);

    return SubVendorMaterialOutward(
      id: json['id']?.toString() ?? '',
      outwardNumber: json['outward_number']?.toString() ?? '',
      vendorId: json['vendor_id']?.toString() ?? '',
      vendorName: json['vendor_name']?.toString() ?? '',
      outwardDate: json['outward_date'] != null
          ? DateTime.tryParse(json['outward_date'].toString()) ?? DateTime.now()
          : DateTime.now(),
      totalItems: totalItems,
      totalQuantity: totalQuantity,
      subtotal: subtotal,
      totalGst: totalGst,
      totalValue: totalValue,
      remarks: json['remarks']?.toString(),
      status: json['status']?.toString() ?? 'Active',
      cancelledAt: json['cancelled_at'] != null ? DateTime.tryParse(json['cancelled_at'].toString()) : null,
      cancelledBy: json['cancelled_by']?.toString(),
      cancellationReason: json['cancellation_reason']?.toString(),
      items: parsedItems,
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'].toString()) : null,
      updatedAt: json['updated_at'] != null ? DateTime.tryParse(json['updated_at'].toString()) : null,
      createdBy: json['created_by']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'outward_number': outwardNumber,
        'vendor_id': vendorId,
        'vendor_name': vendorName,
        'outward_date': outwardDate.toIso8601String().split('T').first,
        'total_items': totalItems,
        'total_quantity': totalQuantity,
        'subtotal': subtotal,
        'total_gst': totalGst,
        'total_value': totalValue,
        if (remarks != null) 'remarks': remarks,
        'status': status,
        if (cancelledAt != null) 'cancelled_at': cancelledAt!.toIso8601String(),
        if (cancelledBy != null) 'cancelled_by': cancelledBy,
        if (cancellationReason != null) 'cancellation_reason': cancellationReason,
        'items': items.map((i) => i.toJson()).toList(),
        if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
        if (updatedAt != null) 'updated_at': updatedAt!.toIso8601String(),
        if (createdBy != null) 'created_by': createdBy,
      };

  SubVendorMaterialOutward copyWith({
    String? id,
    String? outwardNumber,
    String? vendorId,
    String? vendorName,
    DateTime? outwardDate,
    int? totalItems,
    double? totalQuantity,
    double? subtotal,
    double? totalGst,
    double? totalValue,
    String? remarks,
    String? status,
    DateTime? cancelledAt,
    String? cancelledBy,
    String? cancellationReason,
    List<SubVendorMaterialOutwardItem>? items,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? createdBy,
  }) {
    final effectiveItems = items ?? this.items;
    final effTotalItems = totalItems ?? effectiveItems.length;
    final double effTotalQty = totalQuantity ?? effectiveItems.fold<double>(0.0, (double sum, i) => sum + i.quantity);
    final double effSubtotal = subtotal ?? effectiveItems.fold<double>(0.0, (double sum, i) => sum + i.baseAmount);
    final double effTotalGst = totalGst ?? effectiveItems.fold<double>(0.0, (double sum, i) => sum + i.gstAmount);
    final double effTotalVal = totalValue ?? effectiveItems.fold<double>(0.0, (double sum, i) => sum + i.totalPrice);

    return SubVendorMaterialOutward(
      id: id ?? this.id,
      outwardNumber: outwardNumber ?? this.outwardNumber,
      vendorId: vendorId ?? this.vendorId,
      vendorName: vendorName ?? this.vendorName,
      outwardDate: outwardDate ?? this.outwardDate,
      totalItems: effTotalItems,
      totalQuantity: effTotalQty,
      subtotal: effSubtotal,
      totalGst: effTotalGst,
      totalValue: effTotalVal,
      remarks: remarks ?? this.remarks,
      status: status ?? this.status,
      cancelledAt: cancelledAt ?? this.cancelledAt,
      cancelledBy: cancelledBy ?? this.cancelledBy,
      cancellationReason: cancellationReason ?? this.cancellationReason,
      items: effectiveItems,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      createdBy: createdBy ?? this.createdBy,
    );
  }
}

/// Represents an audit log entry for Sub-Vendor Material Outward transactions.
class SubVendorMaterialOutwardAudit {
  final String id;
  final String outwardId;
  final String outwardNumber;
  final String action; // 'CREATE', 'UPDATE', 'CANCEL'
  final String description;
  final Map<String, dynamic> details;
  final String? performedBy;
  final DateTime createdAt;

  const SubVendorMaterialOutwardAudit({
    required this.id,
    required this.outwardId,
    required this.outwardNumber,
    required this.action,
    required this.description,
    this.details = const {},
    this.performedBy,
    required this.createdAt,
  });

  factory SubVendorMaterialOutwardAudit.fromJson(Map<String, dynamic> json) {
    Map<String, dynamic> detailsMap = {};
    if (json['details'] is Map) {
      detailsMap = Map<String, dynamic>.from(json['details'] as Map);
    } else if (json['details'] is String) {
      try {
        detailsMap = jsonDecode(json['details'] as String) as Map<String, dynamic>;
      } catch (_) {}
    }

    return SubVendorMaterialOutwardAudit(
      id: json['id']?.toString() ?? '',
      outwardId: json['outward_id']?.toString() ?? '',
      outwardNumber: json['outward_number']?.toString() ?? '',
      action: json['action']?.toString() ?? 'CREATE',
      description: json['description']?.toString() ?? '',
      details: detailsMap,
      performedBy: json['performed_by']?.toString(),
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'outward_id': outwardId,
        'outward_number': outwardNumber,
        'action': action,
        'description': description,
        'details': details,
        if (performedBy != null) 'performed_by': performedBy,
        'created_at': createdAt.toIso8601String(),
      };
}
