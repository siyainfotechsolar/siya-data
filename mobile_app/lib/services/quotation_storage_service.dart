import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/solar_quotation.dart';
import '../models/customer_margin_receipt.dart';

class QuotationStorageService {
  static const String _storageKeyPrefix = 'customer_quotations_';
  static const String _marginStorageKeyPrefix = 'customer_margin_receipts_';
  static const String _allQuotationsKey = 'all_solar_quotations_ids';

  /// Save quotation both locally and in Supabase
  static Future<void> saveQuotation(SolarQuotation quotation) async {
    // 1. Save locally in SharedPreferences for offline resilience and instant access
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = '$_storageKeyPrefix${quotation.consumerNo.trim()}';
      final existingJson = prefs.getStringList(key) ?? [];

      // Avoid duplicates with same quotationNo or ID
      final updatedList = existingJson.where((str) {
        try {
          final map = jsonDecode(str) as Map<String, dynamic>;
          return map['quotation_no'] != quotation.quotationNo && map['id'] != quotation.id;
        } catch (_) {
          return true;
        }
      }).toList();

      updatedList.insert(0, jsonEncode(quotation.toJson()));
      await prefs.setStringList(key, updatedList);

      // Track all quotation IDs
      final allIds = prefs.getStringList(_allQuotationsKey) ?? [];
      if (!allIds.contains(quotation.id)) {
        allIds.insert(0, quotation.id);
        await prefs.setStringList(_allQuotationsKey, allIds);
      }
    } catch (e) {
      debugPrint('Error saving quotation locally: $e');
    }

    // 2. Sync to Supabase in background
    try {
      final client = Supabase.instance.client;
      final userId = client.auth.currentUser?.id;

      // Insert into customer_quotations
      await client.from('customer_quotations').upsert({
        'id': quotation.id,
        'customer_id': quotation.customerId,
        'consumer_no': quotation.consumerNo.trim(),
        'quotation_no': quotation.quotationNo.trim(),
        'customer_name': quotation.customerName.trim(),
        'address': quotation.address,
        'village_city': quotation.villageCity,
        'district': quotation.district,
        'mobile_no': quotation.mobileNo,
        'system_capacity': quotation.systemCapacity,
        'system_type': quotation.systemType,
        'total_system_cost': quotation.totalSystemCost,
        'gst_amount': quotation.gstAmount,
        'grand_total': quotation.grandTotal,
        'amount_in_words': quotation.amountInWords,
        'bank_loan_amount': quotation.bankLoanAmount,
        'customer_contribution': quotation.customerContribution,
        'bank_name': quotation.bankName,
        'branch': quotation.branch,
        'account_no': quotation.accountNo,
        'ifsc_code': quotation.ifscCode,
        'account_type': quotation.accountType,
        'upi_id': quotation.upiId,
        'signatory_name': quotation.signatoryName,
        'signatory_designation': quotation.signatoryDesignation,
        'file_name': quotation.pdfFileName,
        'file_url': quotation.fileUrl,
        'metadata': {
          'items': quotation.items,
        },
        'created_by': userId,
        'created_at': quotation.createdAt.toUtc().toIso8601String(),
      });

      // Also record in customer_documents for seamless cross-visibility
      if (quotation.customerId != null && quotation.customerId!.isNotEmpty) {
        try {
          await client.from('customer_documents').insert({
            'customer_id': quotation.customerId,
            'consumer_no': quotation.consumerNo.trim(),
            'document_type': 'Bank Loan Quotation',
            'document_name': quotation.pdfFileName,
            'file_url': quotation.fileUrl ?? quotation.pdfFilePath ?? '',
            'source': 'Quotation Generator',
            'extracted_data': {
              'quotation_no': quotation.quotationNo,
              'grand_total': quotation.grandTotal,
              'system_capacity': quotation.systemCapacity,
              'bank_loan_amount': quotation.bankLoanAmount,
            },
            'uploaded_by': userId,
            'created_at': quotation.createdAt.toUtc().toIso8601String(),
          });
        } catch (_) {}
      }
    } catch (e) {
      debugPrint('Supabase quotation sync error (offline or skipped): $e');
    }
  }

  /// Retrieve all previously generated quotations for a specific customer
  static Future<List<SolarQuotation>> getQuotationsForCustomer(String consumerNo) async {
    final Map<String, SolarQuotation> quotationMap = {};

    // 1. Fetch from Local SharedPreferences
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = '$_storageKeyPrefix${consumerNo.trim()}';
      final localList = prefs.getStringList(key) ?? [];
      for (final jsonStr in localList) {
        try {
          final map = jsonDecode(jsonStr) as Map<String, dynamic>;
          final quotation = SolarQuotation.fromJson(map);
          quotationMap[quotation.quotationNo] = quotation;
        } catch (_) {}
      }
    } catch (e) {
      debugPrint('Error reading local quotations: $e');
    }

    // 2. Fetch from Supabase (if online)
    try {
      final client = Supabase.instance.client;
      final res = await client
          .from('customer_quotations')
          .select()
          .eq('consumer_no', consumerNo.trim())
          .order('created_at', ascending: false);

      for (final row in res) {
          try {
            final quotation = SolarQuotation.fromJson(row);
            // Supabase entries override or complement local
            quotationMap[quotation.quotationNo] = quotation;
          } catch (_) {}
      }
    } catch (e) {
      debugPrint('Supabase quotation fetch skipped: $e');
    }

    final list = quotationMap.values.toList();
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  /// Save customer margin money receipt locally and sync to Supabase
  static Future<void> saveMarginReceipt(CustomerMarginReceipt receipt) async {
    // 1. Local storage
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = '$_marginStorageKeyPrefix${receipt.consumerNo.trim()}';
      final existingJson = prefs.getStringList(key) ?? [];

      final updatedList = existingJson.where((str) {
        try {
          final map = jsonDecode(str) as Map<String, dynamic>;
          return map['receipt_no'] != receipt.receiptNo && map['id'] != receipt.id;
        } catch (_) {
          return true;
        }
      }).toList();

      updatedList.insert(0, jsonEncode(receipt.toJson()));
      await prefs.setStringList(key, updatedList);
    } catch (e) {
      debugPrint('Error saving margin receipt locally in mobile app: $e');
    }

    // 2. Supabase sync
    try {
      final client = Supabase.instance.client;
      final userId = client.auth.currentUser?.id;

      if (receipt.customerId != null && receipt.customerId!.isNotEmpty) {
        await client.from('customer_documents').insert({
          'customer_id': receipt.customerId,
          'consumer_no': receipt.consumerNo.trim(),
          'document_type': 'Customer Margin Money Receipt',
          'document_name': receipt.pdfFileName,
          'file_url': receipt.fileUrl ?? receipt.pdfFilePath ?? '',
          'source': 'Margin Receipt Generator',
          'extracted_data': {
            'receipt_no': receipt.receiptNo,
            'margin_amount': receipt.marginAmount,
            'system_capacity': receipt.systemCapacity,
            'total_system_cost': receipt.totalSystemCost,
            'bank_loan_amount': receipt.bankLoanAmount,
            'payment_mode': receipt.paymentMode,
            'transaction_ref': receipt.transactionRef,
          },
          'uploaded_by': userId,
          'created_at': receipt.createdAt.toUtc().toIso8601String(),
        });
      }
    } catch (e) {
      debugPrint('Supabase margin receipt sync error in mobile app (offline or skipped): $e');
    }
  }

  /// Retrieve all previously saved margin receipts for a customer
  static Future<List<CustomerMarginReceipt>> getMarginReceiptsForCustomer(String consumerNo) async {
    final Map<String, CustomerMarginReceipt> receiptMap = {};

    try {
      final prefs = await SharedPreferences.getInstance();
      final key = '$_marginStorageKeyPrefix${consumerNo.trim()}';
      final localList = prefs.getStringList(key) ?? [];
      for (final jsonStr in localList) {
        try {
          final map = jsonDecode(jsonStr) as Map<String, dynamic>;
          final receipt = CustomerMarginReceipt.fromJson(map);
          receiptMap[receipt.receiptNo] = receipt;
        } catch (_) {}
      }
    } catch (e) {
      debugPrint('Error reading local margin receipts in mobile app: $e');
    }

    final list = receiptMap.values.toList();
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }
}
