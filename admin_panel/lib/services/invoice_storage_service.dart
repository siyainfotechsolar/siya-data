import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/invoice.dart';

/// Invoice storage and retrieval service.
/// Invoices are ONLY created when user explicitly clicks [Generate Invoice].
class InvoiceStorageService {
  static const String _storageKeyPrefix = 'customer_invoices_';
  static const String _allInvoicesKey = 'all_invoices_ids';
  static const String _invoiceCounterKey = 'invoice_counter';
  static const String _quotationInvoiceMapKey = 'quotation_invoice_map';

  // ── Invoice Number Generation ──────────────────────────────────────────────

  /// Generate next unique invoice number: INV-YYYY-NNNN
  /// Only called when user explicitly confirms [Generate Invoice].
  static Future<String> generateInvoiceNumber() async {
    final prefs = await SharedPreferences.getInstance();
    final year = DateTime.now().year;
    final yearKey = '${_invoiceCounterKey}_$year';

    int counter = prefs.getInt(yearKey) ?? 0;
    counter++;
    await prefs.setInt(yearKey, counter);

    // Also try to get the max from Supabase for consistency
    try {
      final client = Supabase.instance.client;
      final res = await client
          .from('customer_invoices')
          .select('invoice_number')
          .like('invoice_number', 'INV-$year-%')
          .order('created_at', ascending: false)
          .limit(1);

      if (res.isNotEmpty) {
        final lastNo = res[0]['invoice_number']?.toString() ?? '';
        final parts = lastNo.split('-');
        if (parts.length == 3) {
          final dbCounter = int.tryParse(parts[2]) ?? 0;
          if (dbCounter >= counter) {
            counter = dbCounter + 1;
            await prefs.setInt(yearKey, counter);
          }
        }
      }
    } catch (_) {
      // Offline — use local counter
    }

    final paddedCounter = counter.toString().padLeft(4, '0');
    return 'INV-$year-$paddedCounter';
  }

  // ── Duplicate Protection ───────────────────────────────────────────────────

  /// Check if a quotation already has an invoice generated
  static Future<Invoice?> getInvoiceForQuotation(String quotationId) async {
    // 1. Check local
    try {
      final prefs = await SharedPreferences.getInstance();
      final mapJson = prefs.getString(_quotationInvoiceMapKey);
      if (mapJson != null) {
        final map = jsonDecode(mapJson) as Map<String, dynamic>;
        if (map.containsKey(quotationId)) {
          final invoiceId = map[quotationId].toString();
          final invoice = await getInvoiceById(invoiceId);
          if (invoice != null) return invoice;
        }
      }
    } catch (_) {}

    // 2. Check Supabase
    try {
      final client = Supabase.instance.client;
      final res = await client
          .from('customer_invoices')
          .select()
          .eq('ref_quotation_id', quotationId)
          .limit(1);

      if (res.isNotEmpty) {
        return Invoice.fromJson(res[0]);
      }
    } catch (_) {}

    return null;
  }

  // ── Save ────────────────────────────────────────────────────────────────────

  /// Save invoice locally and sync to Supabase
  static Future<void> saveInvoice(Invoice invoice) async {
    // 1. Save locally
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = '$_storageKeyPrefix${invoice.consumerNo.trim()}';
      final existingJson = prefs.getStringList(key) ?? [];

      // Avoid duplicates
      final updatedList = existingJson.where((str) {
        try {
          final map = jsonDecode(str) as Map<String, dynamic>;
          return map['invoice_number'] != invoice.invoiceNumber && map['id'] != invoice.id;
        } catch (_) {
          return true;
        }
      }).toList();

      updatedList.insert(0, jsonEncode(invoice.toJson()));
      await prefs.setStringList(key, updatedList);

      // Track all invoice IDs
      final allIds = prefs.getStringList(_allInvoicesKey) ?? [];
      if (!allIds.contains(invoice.id)) {
        allIds.insert(0, invoice.id);
        await prefs.setStringList(_allInvoicesKey, allIds);
      }

      // Map quotation → invoice for duplicate protection
      if (invoice.refQuotationId != null && invoice.refQuotationId!.isNotEmpty) {
        final mapJson = prefs.getString(_quotationInvoiceMapKey);
        final map = mapJson != null
            ? Map<String, dynamic>.from(jsonDecode(mapJson) as Map)
            : <String, dynamic>{};
        map[invoice.refQuotationId!] = invoice.id;
        await prefs.setString(_quotationInvoiceMapKey, jsonEncode(map));
      }
    } catch (e) {
      debugPrint('Error saving invoice locally: $e');
    }

    // 2. Sync to Supabase
    try {
      final client = Supabase.instance.client;
      final userId = client.auth.currentUser?.id;

      await client.from('customer_invoices').upsert({
        'id': invoice.id,
        'invoice_number': invoice.invoiceNumber,
        'ref_invoice_no': invoice.refInvoiceNo,
        'ref_quotation_id': invoice.refQuotationId,
        'customer_id': invoice.customerId,
        'consumer_no': invoice.consumerNo.trim(),
        'customer_name': invoice.customerName.trim(),
        'address': invoice.address,
        'village_city': invoice.villageCity,
        'district': invoice.district,
        'mobile_no': invoice.mobileNo,
        'invoice_date': invoice.invoiceDate.toIso8601String().split('T')[0],
        'system_capacity': invoice.systemCapacity,
        'system_type': invoice.systemType,
        'items': invoice.items,
        'taxable_amount': invoice.taxableAmount,
        'gst_5': invoice.gst5,
        'gst_18': invoice.gst18,
        'total_gst': invoice.totalGst,
        'grand_total': invoice.grandTotal,
        'amount_in_words': invoice.amountInWords,
        'total_paid': invoice.totalPaid,
        'total_pending': invoice.totalPending,
        'payment_status': invoice.paymentStatus,
        'pdf_file_name': invoice.pdfFileName,
        'file_url': invoice.fileUrl,
        'include_stamp_and_signature': invoice.includeStampAndSignature,
        'created_by': userId ?? invoice.createdBy,
        'created_at': invoice.createdAt.toUtc().toIso8601String(),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      });

      // Record in customer_documents for cross-visibility
      if (invoice.customerId != null && invoice.customerId!.isNotEmpty) {
        try {
          await client.from('customer_documents').insert({
            'customer_id': invoice.customerId,
            'consumer_no': invoice.consumerNo.trim(),
            'document_type': 'Invoice',
            'document_name': invoice.pdfFileName ?? 'Invoice.pdf',
            'file_url': invoice.fileUrl ?? '',
            'source': 'Invoice Generator',
            'extracted_data': {
              'invoice_number': invoice.invoiceNumber,
              'ref_invoice_no': invoice.refInvoiceNo,
              'grand_total': invoice.grandTotal,
              'system_capacity': invoice.systemCapacity,
              'payment_status': invoice.paymentStatus,
            },
            'uploaded_by': userId,
            'created_at': invoice.createdAt.toUtc().toIso8601String(),
          });
        } catch (_) {}
      }
    } catch (e) {
      debugPrint('Supabase invoice sync error (offline or skipped): $e');
    }
  }

  /// Update an existing invoice
  static Future<void> updateInvoice(Invoice invoice) async {
    final updated = invoice.copyWith(updatedAt: DateTime.now());
    await saveInvoice(updated);
  }

  // ── Fetch ───────────────────────────────────────────────────────────────────

  /// Get all invoices for a specific customer
  static Future<List<Invoice>> getInvoicesForCustomer(String consumerNo) async {
    final Map<String, Invoice> invoiceMap = {};

    // 1. Local
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = '$_storageKeyPrefix${consumerNo.trim()}';
      final localList = prefs.getStringList(key) ?? [];
      for (final jsonStr in localList) {
        try {
          final map = jsonDecode(jsonStr) as Map<String, dynamic>;
          final invoice = Invoice.fromJson(map);
          invoiceMap[invoice.invoiceNumber] = invoice;
        } catch (_) {}
      }
    } catch (e) {
      debugPrint('Error reading local invoices: $e');
    }

    // 2. Supabase
    try {
      final client = Supabase.instance.client;
      final res = await client
          .from('customer_invoices')
          .select()
          .eq('consumer_no', consumerNo.trim())
          .order('created_at', ascending: false);

      for (final row in res) {
        try {
          final invoice = Invoice.fromJson(row);
          invoiceMap[invoice.invoiceNumber] = invoice;
        } catch (_) {}
      }
    } catch (e) {
      debugPrint('Supabase invoice fetch skipped: $e');
    }

    final list = invoiceMap.values.toList();
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  /// Get all invoices (for the Invoices tab)
  static Future<List<Invoice>> getAllInvoices() async {
    final Map<String, Invoice> invoiceMap = {};

    // 1. Try Supabase first (authoritative)
    try {
      final client = Supabase.instance.client;
      final res = await client
          .from('customer_invoices')
          .select()
          .order('created_at', ascending: false)
          .limit(500);

      for (final row in res) {
        try {
          final invoice = Invoice.fromJson(row);
          invoiceMap[invoice.invoiceNumber] = invoice;
        } catch (_) {}
      }
    } catch (e) {
      debugPrint('Supabase all invoices fetch skipped: $e');
    }

    // 2. Supplement with local data
    try {
      final prefs = await SharedPreferences.getInstance();
      final allIds = prefs.getStringList(_allInvoicesKey) ?? [];

      // Collect all consumer_no keys
      final keys = prefs.getKeys().where((k) => k.startsWith(_storageKeyPrefix));
      for (final key in keys) {
        final localList = prefs.getStringList(key) ?? [];
        for (final jsonStr in localList) {
          try {
            final map = jsonDecode(jsonStr) as Map<String, dynamic>;
            final invoice = Invoice.fromJson(map);
            if (!invoiceMap.containsKey(invoice.invoiceNumber)) {
              invoiceMap[invoice.invoiceNumber] = invoice;
            }
          } catch (_) {}
        }
      }
    } catch (e) {
      debugPrint('Error reading local invoices for all: $e');
    }

    final list = invoiceMap.values.toList();
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  /// Get a single invoice by ID
  static Future<Invoice?> getInvoiceById(String invoiceId) async {
    // 1. Supabase
    try {
      final client = Supabase.instance.client;
      final res = await client
          .from('customer_invoices')
          .select()
          .eq('id', invoiceId)
          .limit(1);

      if (res.isNotEmpty) {
        return Invoice.fromJson(res[0]);
      }
    } catch (_) {}

    // 2. Local search
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys().where((k) => k.startsWith(_storageKeyPrefix));
      for (final key in keys) {
        final localList = prefs.getStringList(key) ?? [];
        for (final jsonStr in localList) {
          try {
            final map = jsonDecode(jsonStr) as Map<String, dynamic>;
            if (map['id'] == invoiceId) {
              return Invoice.fromJson(map);
            }
          } catch (_) {}
        }
      }
    } catch (_) {}

    return null;
  }
}
