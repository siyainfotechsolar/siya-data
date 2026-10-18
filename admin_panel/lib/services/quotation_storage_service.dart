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
  static const String _allMarginReceiptsKey = 'all_margin_receipts_ids';

  // ── QUOTATION STORAGE & RETRIEVAL ──────────────────────────────────────────

  /// Save or update quotation both locally and in Supabase.
  /// If an existing quotation with the same ID or quotationNo exists, it updates the record.
  static Future<void> saveQuotation(SolarQuotation quotation) async {
    // 1. Save locally in SharedPreferences
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = '$_storageKeyPrefix${quotation.consumerNo.trim()}';
      final existingJson = prefs.getStringList(key) ?? [];

      // Avoid duplicates: remove any record with matching id or quotationNo
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

      // Track quotation in all-IDs set
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

      // Upsert into customer_quotations
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
          'status': quotation.status,
        },
        'created_by': userId,
        'created_at': quotation.createdAt.toUtc().toIso8601String(),
      });

      // Resolve customerId if missing
      String? customerId = quotation.customerId;
      if (customerId == null || customerId.isEmpty) {
        try {
          final custRes = await client
              .from('consumer_records')
              .select('id')
              .eq('consumer_no', quotation.consumerNo.trim())
              .limit(1);
          if (custRes.isNotEmpty) {
            customerId = custRes.first['id']?.toString();
          }
        } catch (_) {}
      }

      // Maintain in customer_documents for cross-visibility without duplicating
      if (customerId != null && customerId.isNotEmpty) {
        try {
          // Check if document entry exists
          final existingDocs = await client
              .from('customer_documents')
              .select('id')
              .eq('customer_id', customerId)
              .eq('document_type', 'Bank Loan Quotation')
              .filter('extracted_data->>quotation_no', 'eq', quotation.quotationNo.trim())
              .limit(1);

          final docData = {
            'customer_id': customerId,
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
              'status': quotation.status,
            },
            'uploaded_by': userId,
            'created_at': quotation.createdAt.toUtc().toIso8601String(),
          };

          if (existingDocs.isNotEmpty) {
            await client.from('customer_documents').update(docData).eq('id', existingDocs.first['id']);
          } else {
            await client.from('customer_documents').insert(docData);
          }
        } catch (_) {}

        // Propagate updates to consumer_records so all modules remain in sync
        try {
          final updateMap = <String, dynamic>{
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          };
          if (quotation.grandTotal > 0) {
            updateMap['total_amount'] = quotation.grandTotal;
          }
          if (quotation.bankLoanAmount > 0) {
            updateMap['loan_sanctioned_amount'] = quotation.bankLoanAmount;
          }
          if (quotation.customerName.trim().isNotEmpty) {
            updateMap['name'] = quotation.customerName.trim();
          }
          if (quotation.mobileNo.trim().isNotEmpty) {
            updateMap['mobile'] = quotation.mobileNo.trim();
          }
          if (quotation.address.trim().isNotEmpty) {
            updateMap['address'] = quotation.address.trim();
          }
          if (quotation.systemCapacity.trim().isNotEmpty) {
            updateMap['system_capacity'] = quotation.systemCapacity.trim();
          }
          await client.from('consumer_records').update(updateMap).eq('id', customerId);
        } catch (_) {}
      }
    } catch (e) {
      debugPrint('Supabase quotation sync error: $e');
    }
  }

  /// Update quotation status (e.g. Draft -> Issued -> Approved -> Invoiced -> Cancelled)
  static Future<void> updateQuotationStatus(String id, String consumerNo, String newStatus) async {
    // 1. Update in Local Storage
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = '$_storageKeyPrefix${consumerNo.trim()}';
      final existingJson = prefs.getStringList(key) ?? [];
      final updatedList = <String>[];

      for (final str in existingJson) {
        try {
          final map = jsonDecode(str) as Map<String, dynamic>;
          if (map['id'] == id || map['quotation_no'] == id) {
            map['status'] = newStatus;
            updatedList.add(jsonEncode(map));
          } else {
            updatedList.add(str);
          }
        } catch (_) {
          updatedList.add(str);
        }
      }
      await prefs.setStringList(key, updatedList);
    } catch (e) {
      debugPrint('Error updating local quotation status: $e');
    }

    // 2. Update in Supabase
    try {
      final client = Supabase.instance.client;
      final existing = await client.from('customer_quotations').select('metadata').eq('id', id).limit(1);
      Map<String, dynamic> meta = {};
      if (existing.isNotEmpty && existing.first['metadata'] is Map) {
        meta = Map<String, dynamic>.from(existing.first['metadata'] as Map);
      }
      meta['status'] = newStatus;
      await client.from('customer_quotations').update({'metadata': meta}).eq('id', id);
    } catch (e) {
      debugPrint('Error updating supabase quotation status: $e');
    }
  }

  /// Retrieve all quotations for a specific customer
  static Future<List<SolarQuotation>> getQuotationsForCustomer(String consumerNo) async {
    final Map<String, SolarQuotation> quotationMap = {};

    // 1. Local
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
      debugPrint('Error reading local customer quotations: $e');
    }

    // 2. Supabase
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
          quotationMap[quotation.quotationNo] = quotation;
        } catch (_) {}
      }
    } catch (e) {
      debugPrint('Supabase customer quotation fetch skipped: $e');
    }

    final list = quotationMap.values.toList();
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  /// Retrieve ALL quotations across all customers for the Quotation List Screen
  static Future<List<SolarQuotation>> getAllQuotations() async {
    final Map<String, SolarQuotation> quotationMap = {};

    // 1. Supabase first (authoritative cloud records)
    try {
      final client = Supabase.instance.client;
      final res = await client
          .from('customer_quotations')
          .select()
          .order('created_at', ascending: false)
          .limit(1000);

      for (final row in res) {
        try {
          final quotation = SolarQuotation.fromJson(row);
          quotationMap[quotation.quotationNo] = quotation;
        } catch (_) {}
      }
    } catch (e) {
      debugPrint('Supabase getAllQuotations fetch skipped: $e');
    }

    // 2. Scan SharedPreferences to merge offline or locally saved records
    try {
      final prefs = await SharedPreferences.getInstance();
      final allKeys = prefs.getKeys();
      for (final key in allKeys) {
        if (key.startsWith(_storageKeyPrefix)) {
          final localList = prefs.getStringList(key) ?? [];
          for (final jsonStr in localList) {
            try {
              final map = jsonDecode(jsonStr) as Map<String, dynamic>;
              final quotation = SolarQuotation.fromJson(map);
              if (!quotationMap.containsKey(quotation.quotationNo)) {
                quotationMap[quotation.quotationNo] = quotation;
              }
            } catch (_) {}
          }
        }
      }
    } catch (e) {
      debugPrint('Local getAllQuotations scan error: $e');
    }

    final list = quotationMap.values.toList();
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  /// Delete a quotation from local and Supabase
  static Future<void> deleteQuotation(String id, String consumerNo) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = '$_storageKeyPrefix${consumerNo.trim()}';
      final existingJson = prefs.getStringList(key) ?? [];
      final updatedList = existingJson.where((str) {
        try {
          final map = jsonDecode(str) as Map<String, dynamic>;
          return map['id'] != id && map['quotation_no'] != id;
        } catch (_) {
          return true;
        }
      }).toList();
      await prefs.setStringList(key, updatedList);
    } catch (e) {
      debugPrint('Error deleting local quotation: $e');
    }

    try {
      final client = Supabase.instance.client;
      await client.from('customer_quotations').delete().eq('id', id);
    } catch (e) {
      debugPrint('Error deleting supabase quotation: $e');
    }
  }

  // ── MARGIN RECEIPT STORAGE & RETRIEVAL (LOAN DOCUMENTATION ONLY) ────────────

  /// Save or update a margin receipt.
  /// IMPORTANT: Margin Receipts are strictly for loan documentation and NEVER affect
  /// actual payment calculations, customer pending balances, cash balance, or ledger.
  static Future<void> saveMarginReceipt(CustomerMarginReceipt receipt) async {
    // 1. Local storage in SharedPreferences
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = '$_marginStorageKeyPrefix${receipt.consumerNo.trim()}';
      final existingJson = prefs.getStringList(key) ?? [];

      // Avoid duplicates with same receiptNo or id
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

      // Track all margin receipts
      final allIds = prefs.getStringList(_allMarginReceiptsKey) ?? [];
      if (!allIds.contains(receipt.id)) {
        allIds.insert(0, receipt.id);
        await prefs.setStringList(_allMarginReceiptsKey, allIds);
      }
    } catch (e) {
      debugPrint('Error saving margin receipt locally: $e');
    }

    // 2. Supabase sync into customer_documents (strictly tagged as Loan Documentation)
    try {
      final client = Supabase.instance.client;
      final userId = client.auth.currentUser?.id;

      // Resolve customerId if missing
      String? customerId = receipt.customerId;
      if (customerId == null || customerId.isEmpty) {
        try {
          final custRes = await client
              .from('consumer_records')
              .select('id')
              .eq('consumer_no', receipt.consumerNo.trim())
              .limit(1);
          if (custRes.isNotEmpty) {
            customerId = custRes.first['id']?.toString();
          }
        } catch (_) {}
      }

      if (customerId != null && customerId.isNotEmpty) {
        final existingDocs = await client
            .from('customer_documents')
            .select('id')
            .eq('customer_id', customerId)
            .eq('document_type', 'Customer Margin Money Receipt')
            .filter('extracted_data->>receipt_no', 'eq', receipt.receiptNo.trim())
            .limit(1);

        final docData = {
          'customer_id': customerId,
          'consumer_no': receipt.consumerNo.trim(),
          'document_type': 'Customer Margin Money Receipt',
          'document_name': receipt.pdfFileName,
          'file_url': receipt.fileUrl ?? receipt.pdfFilePath ?? '',
          'source': 'Margin Receipt Generator',
          'extracted_data': {
            'id': receipt.id,
            'receipt_no': receipt.receiptNo,
            'customer_name': receipt.customerName,
            'address': receipt.address,
            'village_city': receipt.villageCity,
            'district': receipt.district,
            'mobile_no': receipt.mobileNo,
            'receipt_date': receipt.receiptDate.toIso8601String(),
            'quotation_no': receipt.quotationNo,
            'quotation_date': receipt.quotationDate.toIso8601String(),
            'margin_amount': receipt.marginAmount,
            'margin_amount_in_words': receipt.marginAmountInWords,
            'system_capacity': receipt.systemCapacity,
            'system_type': receipt.systemType,
            'total_system_cost': receipt.totalSystemCost,
            'bank_loan_amount': receipt.bankLoanAmount,
            'bank_name': receipt.bankName,
            'finance_company_name': receipt.financeCompanyName,
            'loan_application_no': receipt.loanApplicationNo,
            'branch': receipt.branch,
            'account_no': receipt.accountNo,
            'ifsc_code': receipt.ifscCode,
            'payment_mode': receipt.paymentMode,
            'transaction_ref': receipt.transactionRef,
            'payment_date': receipt.paymentDate.toIso8601String(),
            'signatory_name': receipt.signatoryName,
            'signatory_designation': receipt.signatoryDesignation,
            'notes': receipt.notes,
            'updated_at': receipt.updatedAt?.toIso8601String(),
            'updated_by': receipt.updatedBy ?? userId,
            'is_loan_doc_only': true,
          },
          'uploaded_by': userId,
          'created_at': receipt.createdAt.toUtc().toIso8601String(),
        };

        if (existingDocs.isNotEmpty) {
          await client.from('customer_documents').update(docData).eq('id', existingDocs.first['id']);
        } else {
          await client.from('customer_documents').insert(docData);
        }

        // Propagate updates to consumer_records so financial numbers stay in sync
        try {
          final updateMap = <String, dynamic>{
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          };
          if (receipt.bankLoanAmount > 0) {
            updateMap['loan_sanctioned_amount'] = receipt.bankLoanAmount;
          }
          if (receipt.totalSystemCost > 0) {
            updateMap['total_amount'] = receipt.totalSystemCost;
          }
          if (receipt.customerName.trim().isNotEmpty) {
            updateMap['name'] = receipt.customerName.trim();
          }
          if (receipt.mobileNo.trim().isNotEmpty) {
            updateMap['mobile'] = receipt.mobileNo.trim();
          }
          if (receipt.address.trim().isNotEmpty) {
            updateMap['address'] = receipt.address.trim();
          }
          if (receipt.systemCapacity.trim().isNotEmpty) {
            updateMap['system_capacity'] = receipt.systemCapacity.trim();
          }
          await client.from('consumer_records').update(updateMap).eq('id', customerId);
        } catch (_) {}
      }
    } catch (e) {
      debugPrint('Supabase margin receipt sync error: $e');
    }
  }

  /// Retrieve all margin receipts for a specific customer
  static Future<List<CustomerMarginReceipt>> getMarginReceiptsForCustomer(String consumerNo) async {
    final Map<String, CustomerMarginReceipt> receiptMap = {};

    // 1. Local
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
      debugPrint('Error reading local margin receipts: $e');
    }

    // 2. Supabase
    try {
      final client = Supabase.instance.client;
      final res = await client
          .from('customer_documents')
          .select()
          .eq('consumer_no', consumerNo.trim())
          .eq('document_type', 'Customer Margin Money Receipt')
          .order('created_at', ascending: false);

      for (final row in res) {
        try {
          final extracted = row['extracted_data'] as Map<String, dynamic>?;
          if (extracted != null) {
            final receipt = CustomerMarginReceipt.fromJson(extracted);
            receiptMap[receipt.receiptNo] = receipt;
          }
        } catch (_) {}
      }
    } catch (e) {
      debugPrint('Supabase margin receipts fetch skipped: $e');
    }

    final list = receiptMap.values.toList();
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  /// Retrieve ALL margin receipts across all customers for Margin Receipt List screen
  static Future<List<CustomerMarginReceipt>> getAllMarginReceipts() async {
    final Map<String, CustomerMarginReceipt> receiptMap = {};

    // 1. Supabase first
    try {
      final client = Supabase.instance.client;
      final res = await client
          .from('customer_documents')
          .select()
          .eq('document_type', 'Customer Margin Money Receipt')
          .order('created_at', ascending: false)
          .limit(1000);

      for (final row in res) {
        try {
          final extracted = row['extracted_data'] as Map<String, dynamic>?;
          if (extracted != null) {
            final receipt = CustomerMarginReceipt.fromJson(extracted);
            receiptMap[receipt.receiptNo] = receipt;
          }
        } catch (_) {}
      }
    } catch (e) {
      debugPrint('Supabase getAllMarginReceipts fetch skipped: $e');
    }

    // 2. Scan SharedPreferences
    try {
      final prefs = await SharedPreferences.getInstance();
      final allKeys = prefs.getKeys();
      for (final key in allKeys) {
        if (key.startsWith(_marginStorageKeyPrefix)) {
          final localList = prefs.getStringList(key) ?? [];
          for (final jsonStr in localList) {
            try {
              final map = jsonDecode(jsonStr) as Map<String, dynamic>;
              final receipt = CustomerMarginReceipt.fromJson(map);
              if (!receiptMap.containsKey(receipt.receiptNo)) {
                receiptMap[receipt.receiptNo] = receipt;
              }
            } catch (_) {}
          }
        }
      }
    } catch (e) {
      debugPrint('Local getAllMarginReceipts scan error: $e');
    }

    final list = receiptMap.values.toList();
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  /// Delete a margin receipt from local and Supabase
  static Future<void> deleteMarginReceipt(String id, String consumerNo) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = '$_marginStorageKeyPrefix${consumerNo.trim()}';
      final existingJson = prefs.getStringList(key) ?? [];
      final updatedList = existingJson.where((str) {
        try {
          final map = jsonDecode(str) as Map<String, dynamic>;
          return map['id'] != id && map['receipt_no'] != id;
        } catch (_) {
          return true;
        }
      }).toList();
      await prefs.setStringList(key, updatedList);
    } catch (e) {
      debugPrint('Error deleting local margin receipt: $e');
    }

    try {
      final client = Supabase.instance.client;
      await client
          .from('customer_documents')
          .delete()
          .eq('document_type', 'Customer Margin Money Receipt')
          .filter('extracted_data->>receipt_no', 'eq', id);
    } catch (e) {
      debugPrint('Error deleting supabase margin receipt: $e');
    }
  }
}
