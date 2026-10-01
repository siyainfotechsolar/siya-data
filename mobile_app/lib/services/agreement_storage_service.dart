import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/consumer_vendor_agreement.dart';

class AgreementStorageService {
  static const String _storageKeyPrefix = 'customer_agreements_';
  static const String _allAgreementsKey = 'all_consumer_agreements_ids';

  /// Save agreement locally in SharedPreferences for offline resilience and fast access
  static Future<void> saveAgreement(ConsumerVendorAgreement agreement) async {
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
  }

  /// Retrieve all saved agreements for a specific consumer number
  static Future<List<ConsumerVendorAgreement>> getAgreementsForCustomer(String consumerNo) async {
    if (consumerNo.trim().isEmpty) return [];

    try {
      final prefs = await SharedPreferences.getInstance();
      final key = '$_storageKeyPrefix${consumerNo.trim()}';
      final list = prefs.getStringList(key) ?? [];

      return list
          .map((str) {
            try {
              return ConsumerVendorAgreement.fromJson(jsonDecode(str) as Map<String, dynamic>);
            } catch (e) {
              debugPrint('Error parsing agreement JSON: $e');
              return null;
            }
          })
          .whereType<ConsumerVendorAgreement>()
          .toList();
    } catch (e) {
      debugPrint('Error fetching agreements from storage: $e');
      return [];
    }
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
          return map['id'] != agreementId;
        } catch (_) {
          return true;
        }
      }).toList();

      await prefs.setStringList(key, updatedList);
    } catch (e) {
      debugPrint('Error deleting agreement: $e');
    }
  }
}
