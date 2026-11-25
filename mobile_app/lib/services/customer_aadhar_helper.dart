import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Helper that caches, processes, and persists uploaded consumer Aadhar Card Xerox
/// for Work Completion Reports (WCR) and official MSEDCL submissions.
class CustomerAadharHelper {
  static final Map<String, Uint8List> _customAadhars = {};

  static String _normalizeKey(String key) => key.trim().toUpperCase();

  /// Saves an uploaded Aadhar Card image in memory and persists to local storage and Supabase in background
  static void setCustomerAadhar(String consumerOrCustomerId, Uint8List rawBytes) {
    if (consumerOrCustomerId.trim().isNotEmpty) {
      final processedBytes = compressAadharCardImage(rawBytes);
      final key = _normalizeKey(consumerOrCustomerId);
      _customAadhars[key] = processedBytes;

      // Persist locally in SharedPreferences and in Supabase in background
      _persistCustomerAadharAsync(consumerOrCustomerId.trim(), processedBytes);
    }
  }

  /// Retrieves cached Aadhar card bytes from memory
  static Uint8List? getCustomerAadhar(String consumerOrCustomerId) {
    return _customAadhars[_normalizeKey(consumerOrCustomerId)];
  }

  /// Checks if Aadhar card is loaded in memory
  static bool hasCustomerAadhar(String consumerOrCustomerId) {
    final key = _normalizeKey(consumerOrCustomerId);
    return _customAadhars.containsKey(key) && _customAadhars[key]!.isNotEmpty;
  }

  /// Clears Aadhar card for consumer from memory and storage
  static void clearCustomerAadhar(String consumerOrCustomerId) {
    final key = _normalizeKey(consumerOrCustomerId);
    _customAadhars.remove(key);
    _clearAadharStorageAsync(consumerOrCustomerId.trim());
  }

  static Future<void> _clearAadharStorageAsync(String consumerNo) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('customer_aadhar_${_normalizeKey(consumerNo)}');
    } catch (_) {}
  }

  /// Asynchronously loads Aadhar Card image from memory, SharedPreferences, or Supabase customer_documents
  static Future<Uint8List?> loadCustomerAadharAsync(String consumerNo) async {
    final key = _normalizeKey(consumerNo);
    if (_customAadhars.containsKey(key) && _customAadhars[key]!.isNotEmpty) {
      return _customAadhars[key];
    }

    // 1. Try SharedPreferences
    try {
      final prefs = await SharedPreferences.getInstance();
      final localB64 = prefs.getString('customer_aadhar_$key');
      if (localB64 != null && localB64.isNotEmpty) {
        final bytes = base64Decode(localB64);
        _customAadhars[key] = bytes;
        return bytes;
      }
    } catch (_) {}

    // 2. Try Supabase customer_documents
    try {
      final client = Supabase.instance.client;
      final res = await client
          .from('customer_documents')
          .select('extracted_data, file_url, document_type, document_name')
          .eq('consumer_no', consumerNo)
          .or('document_type.ilike.%aadhar%,document_name.ilike.%aadhar%')
          .order('created_at', ascending: false)
          .limit(1);

      if (res.isNotEmpty) {
        final row = res.first;
        final extracted = row['extracted_data'] as Map<String, dynamic>?;
        if (extracted != null && extracted['base64'] != null) {
          final b64 = extracted['base64'].toString();
          if (b64.isNotEmpty) {
            final bytes = base64Decode(b64);
            _customAadhars[key] = bytes;
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString('customer_aadhar_$key', b64);
            return bytes;
          }
        }
      }
    } catch (e) {
      debugPrint('Notice loading customer Aadhar from Supabase: $e');
    }

    return null;
  }

  static Future<void> _persistCustomerAadharAsync(String consumerNo, Uint8List bytes) async {
    final b64 = base64Encode(bytes);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('customer_aadhar_${_normalizeKey(consumerNo)}', b64);
    } catch (_) {}

    try {
      final client = Supabase.instance.client;
      final userId = client.auth.currentUser?.id;

      // Resolve customerId if possible
      String? customerId;
      try {
        final res = await client
            .from('consumer_records')
            .select('id')
            .eq('consumer_no', consumerNo)
            .limit(1);
        if (res.isNotEmpty) {
          customerId = res.first['id']?.toString();
        }
      } catch (_) {}

      final existing = await client
          .from('customer_documents')
          .select('id')
          .eq('consumer_no', consumerNo)
          .eq('document_type', 'Aadhar Card Xerox')
          .limit(1);

      final docData = {
        'customer_id': customerId,
        'consumer_no': consumerNo,
        'document_type': 'Aadhar Card Xerox',
        'document_name': 'Aadhar_Card_$consumerNo.jpg',
        'file_url': 'data:image/jpeg;base64,$b64',
        'source': 'WCR Aadhar Upload Helper',
        'extracted_data': {
          'base64': b64,
          'consumer_no': consumerNo,
          'customer_id': customerId,
        },
        'uploaded_by': userId,
        'created_at': DateTime.now().toUtc().toIso8601String(),
      };

      if (existing.isNotEmpty) {
        await client.from('customer_documents').update(docData).eq('id', existing.first['id']);
      } else {
        await client.from('customer_documents').insert(docData);
      }
    } catch (e) {
      debugPrint('Notice saving customer Aadhar to Supabase: $e');
    }
  }

  /// Compresses and scales Aadhar card image to fit cleanly on A4 page
  /// while keeping high clarity for text and photos
  static Uint8List compressAadharCardImage(Uint8List rawBytes, {int maxDimension = 1200, int quality = 85}) {
    try {
      final image = img.decodeImage(rawBytes);
      if (image == null) return rawBytes;

      img.Image processed = image;
      if (processed.width > maxDimension || processed.height > maxDimension) {
        if (processed.width >= processed.height) {
          processed = img.copyResize(processed, width: maxDimension);
        } else {
          processed = img.copyResize(processed, height: maxDimension);
        }
      }

      final encoded = img.encodeJpg(processed, quality: quality);
      return Uint8List.fromList(encoded);
    } catch (_) {
      return rawBytes;
    }
  }
}
