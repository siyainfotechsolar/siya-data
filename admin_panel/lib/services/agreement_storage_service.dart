import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/consumer_vendor_agreement.dart';

class AgreementStorageService {
  static const String _storageKeyPrefix = 'customer_agreements_';
  static const String _allAgreementsKey = 'all_consumer_agreements_ids';

  /// Save agreement both locally in SharedPreferences and synchronized to Supabase
  static Future<void> saveAgreement(ConsumerVendorAgreement agreement) async {
    // 1. Save locally in SharedPreferences for offline resilience and fast instant access
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = '$_storageKeyPrefix${agreement.consumerNo.trim()}';
      final existingJson = prefs.getStringList(key) ?? [];

      // Avoid duplicates with same agreementNo or ID
      final updatedList = existingJson.where((str) {
        try {
          final map = jsonDecode(str) as Map<String, dynamic>;
          return map['agreement_no'] != agreement.agreementNo && map['id'] != agreement.id;
        } catch (_) {
          return true;
        }
      }).toList();

      updatedList.insert(0, jsonEncode(agreement.toJson()));
      await prefs.setStringList(key, updatedList);

      // Track all agreement IDs
      final allIds = prefs.getStringList(_allAgreementsKey) ?? [];
      if (!allIds.contains(agreement.id)) {
        allIds.insert(0, agreement.id);
        await prefs.setStringList(_allAgreementsKey, allIds);
      }
    } catch (e) {
      debugPrint('Error saving agreement locally: $e');
    }

    // 2. Sync to Supabase in background
    try {
      final client = Supabase.instance.client;
      final userId = client.auth.currentUser?.id;

      // Resolve customerId if missing
      String? customerId = agreement.customerId;
      if (customerId == null || customerId.isEmpty) {
        try {
          final custRes = await client
              .from('consumer_records')
              .select('id')
              .eq('consumer_no', agreement.consumerNo.trim())
              .limit(1);
          if (custRes.isNotEmpty) {
            customerId = custRes.first['id']?.toString();
          }
        } catch (_) {}
      }

      // Upsert into public.customer_agreements
      try {
        await client.from('customer_agreements').upsert({
          'id': agreement.id,
          'agreement_no': agreement.agreementNo.trim(),
          'customer_id': customerId,
          'consumer_no': agreement.consumerNo.trim(),
          'customer_name': agreement.customerName.trim(),
          'customer_address': agreement.customerAddress.trim(),
          'village_city': agreement.villageCity,
          'district': agreement.district,
          'customer_mobile': agreement.customerMobile,
          'execution_date': agreement.executionDate.toIso8601String().split('T')[0],
          'system_capacity': agreement.systemCapacity,
          'system_type': agreement.systemType,
          'scheme_name': agreement.schemeName,
          'total_project_cost': agreement.totalProjectCost,
          'cfa_subsidy_amount': agreement.cfaSubsidyAmount,
          'net_customer_payable': agreement.netCustomerPayable,
          'vendor_name': agreement.vendorName,
          'vendor_address': agreement.vendorAddress,
          'vendor_phone': agreement.vendorPhone,
          'vendor_email': agreement.vendorEmail,
          'vendor_gstin': agreement.vendorGstin,
          'payment_milestones': agreement.paymentMilestones.map((m) => m.toJson()).toList(),
          'pdf_file_name': agreement.pdfFileName,
          'file_url': agreement.fileUrl ?? agreement.pdfFilePath,
          'created_by': userId,
          'created_at': agreement.createdAt.toUtc().toIso8601String(),
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        });
      } catch (e) {
        debugPrint('Supabase customer_agreements sync notice: $e');
      }

      // Also maintain record in customer_documents for cross-module document repository
      if (customerId != null && customerId.isNotEmpty) {
        try {
          final existingDocs = await client
              .from('customer_documents')
              .select('id')
              .eq('customer_id', customerId)
              .eq('document_type', 'Consumer Vendor Agreement')
              .filter('extracted_data->>agreement_no', 'eq', agreement.agreementNo.trim())
              .limit(1);

          final docData = {
            'customer_id': customerId,
            'consumer_no': agreement.consumerNo.trim(),
            'document_type': 'Consumer Vendor Agreement',
            'document_name': agreement.pdfFileName,
            'file_url': agreement.fileUrl ?? agreement.pdfFilePath ?? '',
            'source': 'Agreement Generator',
            'extracted_data': {
              'id': agreement.id,
              'agreement_no': agreement.agreementNo,
              'customer_name': agreement.customerName,
              'customer_address': agreement.customerAddress,
              'customer_mobile': agreement.customerMobile,
              'execution_date': agreement.executionDate.toIso8601String(),
              'system_capacity': agreement.systemCapacity,
              'system_type': agreement.systemType,
              'total_project_cost': agreement.totalProjectCost,
              'cfa_subsidy_amount': agreement.cfaSubsidyAmount,
              'net_customer_payable': agreement.netCustomerPayable,
              'vendor_name': agreement.vendorName,
            },
            'uploaded_by': userId,
            'created_at': agreement.createdAt.toUtc().toIso8601String(),
          };

          if (existingDocs.isNotEmpty) {
            await client.from('customer_documents').update(docData).eq('id', existingDocs.first['id']);
          } else {
            await client.from('customer_documents').insert(docData);
          }
        } catch (_) {}

        // Propagate customer updates to consumer_records so ALL modules stay in sync
        try {
          final updatePayload = <String, dynamic>{
            'agreement_status': 'Signed',
            'agreement_date': agreement.executionDate.toIso8601String(),
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          };
          if (agreement.customerName.trim().isNotEmpty) {
            updatePayload['name'] = agreement.customerName.trim();
          }
          if (agreement.customerMobile.trim().isNotEmpty) {
            updatePayload['mobile'] = agreement.customerMobile.trim();
          }
          if (agreement.customerAddress.trim().isNotEmpty) {
            updatePayload['address'] = agreement.customerAddress.trim();
          }
          if (agreement.systemCapacity.trim().isNotEmpty) {
            updatePayload['system_capacity'] = agreement.systemCapacity.trim();
          }
          if (agreement.totalProjectCost > 0) {
            updatePayload['total_amount'] = agreement.totalProjectCost;
          }

          await client
              .from('consumer_records')
              .update(updatePayload)
              .eq('id', customerId);
        } catch (e) {
          debugPrint('Notice updating consumer_records from agreement: $e');
        }
      }
    } catch (e) {
      debugPrint('Supabase agreement remote sync skipped: $e');
    }
  }

  /// Retrieve all saved agreements for a specific consumer number
  static Future<List<ConsumerVendorAgreement>> getAgreementsForCustomer(String consumerNo) async {
    if (consumerNo.trim().isEmpty) return [];
    final Map<String, ConsumerVendorAgreement> agreementMap = {};

    // 1. Check local SharedPreferences
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = '$_storageKeyPrefix${consumerNo.trim()}';
      final list = prefs.getStringList(key) ?? [];

      for (final str in list) {
        try {
          final agr = ConsumerVendorAgreement.fromJson(jsonDecode(str) as Map<String, dynamic>);
          agreementMap[agr.agreementNo] = agr;
        } catch (_) {}
      }
    } catch (e) {
      debugPrint('Error fetching agreements from storage: $e');
    }

    // 2. Fetch from Supabase customer_agreements table (cross-user source of truth)
    try {
      final client = Supabase.instance.client;
      final res = await client
          .from('customer_agreements')
          .select()
          .eq('consumer_no', consumerNo.trim())
          .order('created_at', ascending: false);

      for (final row in res) {
        try {
          final agr = ConsumerVendorAgreement.fromJson(row);
          agreementMap[agr.agreementNo] = agr;
        } catch (_) {}
      }
    } catch (e) {
      debugPrint('Supabase customer_agreements fetch skipped: $e');
    }

    // 3. Fallback: check customer_documents table for agreements
    if (agreementMap.isEmpty) {
      try {
        final client = Supabase.instance.client;
        final res = await client
            .from('customer_documents')
            .select()
            .eq('consumer_no', consumerNo.trim())
            .eq('document_type', 'Consumer Vendor Agreement')
            .order('created_at', ascending: false);

        for (final row in res) {
          try {
            final extracted = row['extracted_data'] as Map<String, dynamic>?;
            if (extracted != null) {
              final agr = ConsumerVendorAgreement.fromJson(extracted);
              agreementMap[agr.agreementNo] = agr;
            }
          } catch (_) {}
        }
      } catch (_) {}
    }

    final list = agreementMap.values.toList();
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  /// Retrieve all agreements across all customers for Agreement List views
  static Future<List<ConsumerVendorAgreement>> getAllAgreements() async {
    final Map<String, ConsumerVendorAgreement> agreementMap = {};

    // 1. Supabase first (authoritative cloud records)
    try {
      final client = Supabase.instance.client;
      final res = await client
          .from('customer_agreements')
          .select()
          .order('created_at', ascending: false)
          .limit(1000);

      for (final row in res) {
        try {
          final agr = ConsumerVendorAgreement.fromJson(row);
          agreementMap[agr.agreementNo] = agr;
        } catch (_) {}
      }
    } catch (e) {
      debugPrint('Supabase getAllAgreements fetch skipped: $e');
    }

    // 2. Merge local SharedPreferences
    try {
      final prefs = await SharedPreferences.getInstance();
      final allKeys = prefs.getKeys();
      for (final key in allKeys) {
        if (key.startsWith(_storageKeyPrefix)) {
          final localList = prefs.getStringList(key) ?? [];
          for (final jsonStr in localList) {
            try {
              final map = jsonDecode(jsonStr) as Map<String, dynamic>;
              final agr = ConsumerVendorAgreement.fromJson(map);
              if (!agreementMap.containsKey(agr.agreementNo)) {
                agreementMap[agr.agreementNo] = agr;
              }
            } catch (_) {}
          }
        }
      }
    } catch (_) {}

    final list = agreementMap.values.toList();
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  /// Delete an agreement
  static Future<void> deleteAgreement(String consumerNo, String agreementId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = '$_storageKeyPrefix${consumerNo.trim()}';
      final existingJson = prefs.getStringList(key) ?? [];

      final updatedList = existingJson.where((str) {
        try {
          final map = jsonDecode(str) as Map<String, dynamic>;
          return map['id'] != agreementId && map['agreement_no'] != agreementId;
        } catch (_) {
          return true;
        }
      }).toList();

      await prefs.setStringList(key, updatedList);
    } catch (e) {
      debugPrint('Error deleting agreement locally: $e');
    }

    try {
      final client = Supabase.instance.client;
      await client.from('customer_agreements').delete().or('id.eq.$agreementId,agreement_no.eq.$agreementId');
    } catch (e) {
      debugPrint('Error deleting agreement from Supabase: $e');
    }
  }
}
