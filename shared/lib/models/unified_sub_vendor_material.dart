import 'sub_vendor_account_ledger.dart';
import 'sub_vendor_material_outward.dart';
import 'vendor_material_transaction.dart';

/// Unified material transaction item combining:
/// 1. Site-wise Material Issues & Returns (`vendor_material_transactions`)
/// 2. Warehouse Material Outward Dispatches (`sub_vendor_material_outwards` + items)
/// 3. Unlinked manual `MATERIAL_OUTWARD` ledger entries (`sub_vendor_account_ledger`)
class UnifiedSubVendorMaterialEntry {
  final String id;
  final String vendorId;
  final String vendorName;
  final String? assignmentId;
  final String? customerId;
  final String? customerName;
  final DateTime transactionDate;
  final String sourceType; // 'SITE_ISSUE', 'SITE_RETURN', 'MATERIAL_OUTWARD', 'LEDGER_OUTWARD'
  final String itemName;
  final String itemCategory;
  final double quantity;
  final String unit;
  final double unitRate;
  final double gstRate;
  final double taxableAmount;
  final double gstAmount;
  final double totalAmount;
  final String? referenceNo;
  final String? remarks;
  final VendorMaterialTransaction? originalSiteMaterial;
  final SubVendorMaterialOutward? originalOutward;
  final SubVendorAccountLedgerEntry? originalLedgerEntry;

  const UnifiedSubVendorMaterialEntry({
    required this.id,
    required this.vendorId,
    required this.vendorName,
    this.assignmentId,
    this.customerId,
    this.customerName,
    required this.transactionDate,
    required this.sourceType,
    required this.itemName,
    required this.itemCategory,
    required this.quantity,
    required this.unit,
    required this.unitRate,
    required this.gstRate,
    required this.taxableAmount,
    required this.gstAmount,
    required this.totalAmount,
    this.referenceNo,
    this.remarks,
    this.originalSiteMaterial,
    this.originalOutward,
    this.originalLedgerEntry,
  });

  bool get isReturn => sourceType == 'SITE_RETURN';
  bool get isOutward => sourceType == 'MATERIAL_OUTWARD' || sourceType == 'LEDGER_OUTWARD';
  bool get isSiteMaterial => sourceType == 'SITE_ISSUE' || sourceType == 'SITE_RETURN';

  double get signedTaxable => isReturn ? -taxableAmount : taxableAmount;
  double get signedGst => isReturn ? -gstAmount : gstAmount;
  double get signedTotal => isReturn ? -totalAmount : totalAmount;

  String get sourceLabel {
    switch (sourceType) {
      case 'SITE_ISSUE':
        return 'Site Material Issue';
      case 'SITE_RETURN':
        return 'Site Material Return';
      case 'MATERIAL_OUTWARD':
        return 'Material Outward';
      case 'LEDGER_OUTWARD':
        return 'Manual Outward Entry';
      default:
        return sourceType;
    }
  }
}

class UnifiedSubVendorMaterialResult {
  final List<UnifiedSubVendorMaterialEntry> entries;
  final double siteIssueTotal;
  final double siteReturnTotal;
  final double outwardTotal;
  final double material5Total;
  final double material5Gst;
  final double material18Total;
  final double material18Gst;
  final double otherAndZeroGstTotal;
  final double otherAndZeroGstTax;
  final double siteGstTotal;
  final double outwardGstTotal;
  final int siteEntryCount;
  final int outwardDispatchCount;

  const UnifiedSubVendorMaterialResult({
    required this.entries,
    required this.siteIssueTotal,
    required this.siteReturnTotal,
    required this.outwardTotal,
    this.material5Total = 0.0,
    this.material5Gst = 0.0,
    this.material18Total = 0.0,
    this.material18Gst = 0.0,
    this.otherAndZeroGstTotal = 0.0,
    this.otherAndZeroGstTax = 0.0,
    this.siteGstTotal = 0.0,
    this.outwardGstTotal = 0.0,
    required this.siteEntryCount,
    required this.outwardDispatchCount,
  });

  double get netSiteMaterialTotal =>
      double.parse((siteIssueTotal - siteReturnTotal).toStringAsFixed(2));

  double get combinedMaterialTotal =>
      double.parse((netSiteMaterialTotal + outwardTotal).toStringAsFixed(2));

  double get totalInputGst =>
      double.parse((siteGstTotal + outwardGstTotal).toStringAsFixed(2));
}

class UnifiedSubVendorMaterialBuilder {
  static UnifiedSubVendorMaterialResult build({
    List<VendorMaterialTransaction> siteMaterials = const [],
    List<SubVendorMaterialOutward> materialOutwards = const [],
    List<SubVendorAccountLedgerEntry> accountLedgerEntries = const [],
    Map<String, String> vendorNameById = const {},
    Map<String, String> customerNameByAssignmentId = const {},
    String? vendorIdFilter,
  }) {
    final List<UnifiedSubVendorMaterialEntry> items = [];
    final Set<String> knownSiteIds = {};
    final Set<String> knownOutwardIds = {};
    final Set<String> knownOutwardVendorKeys = {};

    double siteIssueTotal = 0.0;
    double siteReturnTotal = 0.0;
    double outwardTotal = 0.0;
    int siteEntryCount = 0;
    int outwardDispatchCount = 0;

    // 1. Site-wise Material Issues & Returns
    for (final m in siteMaterials) {
      if (vendorIdFilter != null && m.vendorId != vendorIdFilter) continue;
      if (m.id.isNotEmpty) knownSiteIds.add(m.id);

      final isRet = m.isReturn;
      if (isRet) {
        siteReturnTotal += m.totalAmount;
      } else {
        siteIssueTotal += m.totalAmount;
      }
      siteEntryCount++;

      items.add(
        UnifiedSubVendorMaterialEntry(
          id: 'vmt_${m.id}',
          vendorId: m.vendorId,
          vendorName: vendorNameById[m.vendorId] ?? 'Sub-Vendor',
          assignmentId: m.assignmentId,
          customerId: m.customerId,
          customerName: customerNameByAssignmentId[m.assignmentId],
          transactionDate: m.transactionDate,
          sourceType: isRet ? 'SITE_RETURN' : 'SITE_ISSUE',
          itemName: m.itemName,
          itemCategory: m.itemCategory,
          quantity: m.quantity,
          unit: m.unit,
          unitRate: m.unitRate,
          gstRate: m.gstRate,
          taxableAmount: m.taxableAmount,
          gstAmount: m.gstAmount,
          totalAmount: m.totalAmount,
          referenceNo: m.invoiceNumber ?? m.challanNumber,
          remarks: m.remarks ?? m.serialNumbers,
          originalSiteMaterial: m,
        ),
      );
    }

    // 2. Warehouse Material Outwards (Active only) with item-level expansion
    for (final o in materialOutwards) {
      if (vendorIdFilter != null && o.vendorId != vendorIdFilter) continue;
      if (!o.isActive) continue;
      if (o.id.isNotEmpty) knownOutwardIds.add(o.id);
      final normalizedOutNo = o.outwardNumber.trim().toUpperCase();
      if (normalizedOutNo.isNotEmpty) {
        knownOutwardVendorKeys.add('${o.vendorId}::$normalizedOutNo');
      }

      outwardDispatchCount++;
      outwardTotal += o.totalValue;

      if (o.items.isNotEmpty) {
        for (var idx = 0; idx < o.items.length; idx++) {
          final item = o.items[idx];
          items.add(
            UnifiedSubVendorMaterialEntry(
              id: 'mo_${o.id}_${item.id.isNotEmpty ? item.id : idx}',
              vendorId: o.vendorId,
              vendorName: vendorNameById[o.vendorId] ?? o.vendorName,
              transactionDate: o.outwardDate,
              sourceType: 'MATERIAL_OUTWARD',
              itemName: item.materialName,
              itemCategory: 'OUTWARD',
              quantity: item.quantity,
              unit: item.unit,
              unitRate: item.unitRate,
              gstRate: item.gstPercentage,
              taxableAmount: item.baseAmount,
              gstAmount: item.gstAmount,
              totalAmount: item.totalPrice,
              referenceNo: o.outwardNumber,
              remarks: o.remarks,
              originalOutward: o,
            ),
          );
        }
      } else {
        items.add(
          UnifiedSubVendorMaterialEntry(
            id: 'mo_${o.id}',
            vendorId: o.vendorId,
            vendorName: vendorNameById[o.vendorId] ?? o.vendorName,
            transactionDate: o.outwardDate,
            sourceType: 'MATERIAL_OUTWARD',
            itemName: 'Material Outward (${o.totalItems > 0 ? o.totalItems : 1} items)',
            itemCategory: 'OUTWARD',
            quantity: o.totalQuantity,
            unit: 'QTY',
            unitRate: o.totalQuantity > 0
                ? double.parse(((o.subtotal > 0 ? o.subtotal : o.totalValue) / o.totalQuantity).toStringAsFixed(2))
                : o.totalValue,
            gstRate: 0.0,
            taxableAmount: o.subtotal > 0 ? o.subtotal : o.totalValue,
            gstAmount: o.totalGst,
            totalAmount: o.totalValue,
            referenceNo: o.outwardNumber,
            remarks: o.remarks,
            originalOutward: o,
          ),
        );
      }
    }

    // 3. Unlinked manual MATERIAL_OUTWARD entries in sub_vendor_account_ledger
    for (final le in accountLedgerEntries) {
      if (!le.isActive) continue;
      if (vendorIdFilter != null && le.vendorId != vendorIdFilter) continue;
      if (le.transactionType.toUpperCase() != 'MATERIAL_OUTWARD') continue;
      if (le.id.startsWith('mo_') || le.id.startsWith('vmt_')) continue;

      final refId = le.referenceId;
      if (refId != null && (knownOutwardIds.contains(refId) || knownSiteIds.contains(refId))) {
        continue;
      }
      final refKey = '${le.vendorId}::${le.referenceNumber.trim().toUpperCase()}';
      if (le.referenceNumber.trim().isNotEmpty && knownOutwardVendorKeys.contains(refKey)) {
        continue;
      }

      final amt = le.debitAmount > 0 ? le.debitAmount : le.creditAmount;
      if (amt <= 0) continue;

      outwardDispatchCount++;
      outwardTotal += amt;

      items.add(
        UnifiedSubVendorMaterialEntry(
          id: 'led_${le.id}',
          vendorId: le.vendorId,
          vendorName: vendorNameById[le.vendorId] ?? le.vendorName,
          transactionDate: le.transactionDate,
          sourceType: 'LEDGER_OUTWARD',
          itemName: le.particulars,
          itemCategory: 'OUTWARD',
          quantity: 1.0,
          unit: 'LOT',
          unitRate: amt,
          gstRate: 0.0,
          taxableAmount: amt,
          gstAmount: 0.0,
          totalAmount: amt,
          referenceNo: le.referenceNumber,
          remarks: le.remarks,
          originalLedgerEntry: le,
        ),
      );
    }

    // Sort newest first
    items.sort((a, b) {
      final dCmp = b.transactionDate.compareTo(a.transactionDate);
      if (dCmp != 0) return dCmp;
      return a.id.compareTo(b.id);
    });

    double material5Total = 0.0;
    double material5Gst = 0.0;
    double material18Total = 0.0;
    double material18Gst = 0.0;
    double otherAndZeroGstTotal = 0.0;
    double otherAndZeroGstTax = 0.0;
    double siteGstTotal = 0.0;
    double outwardGstTotal = 0.0;

    for (final entry in items) {
      final signedTot = entry.signedTotal;
      final signedGst = entry.signedGst;
      final rate = entry.gstRate;

      if (entry.isSiteMaterial) {
        siteGstTotal += signedGst;
      } else {
        outwardGstTotal += signedGst;
      }

      if ((rate - 5.0).abs() < 0.01) {
        material5Total += signedTot;
        material5Gst += signedGst;
      } else if ((rate - 18.0).abs() < 0.01) {
        material18Total += signedTot;
        material18Gst += signedGst;
      } else {
        otherAndZeroGstTotal += signedTot;
        otherAndZeroGstTax += signedGst;
      }
    }

    return UnifiedSubVendorMaterialResult(
      entries: items,
      siteIssueTotal: double.parse(siteIssueTotal.toStringAsFixed(2)),
      siteReturnTotal: double.parse(siteReturnTotal.toStringAsFixed(2)),
      outwardTotal: double.parse(outwardTotal.toStringAsFixed(2)),
      material5Total: double.parse(material5Total.toStringAsFixed(2)),
      material5Gst: double.parse(material5Gst.toStringAsFixed(2)),
      material18Total: double.parse(material18Total.toStringAsFixed(2)),
      material18Gst: double.parse(material18Gst.toStringAsFixed(2)),
      otherAndZeroGstTotal: double.parse(otherAndZeroGstTotal.toStringAsFixed(2)),
      otherAndZeroGstTax: double.parse(otherAndZeroGstTax.toStringAsFixed(2)),
      siteGstTotal: double.parse(siteGstTotal.toStringAsFixed(2)),
      outwardGstTotal: double.parse(outwardGstTotal.toStringAsFixed(2)),
      siteEntryCount: siteEntryCount,
      outwardDispatchCount: outwardDispatchCount,
    );
  }
}
