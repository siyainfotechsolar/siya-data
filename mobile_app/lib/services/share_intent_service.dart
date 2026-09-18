import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../models/shared_document.dart';

class ShareIntentService {
  static const MethodChannel _channel =
      MethodChannel('com.siyainfotech.mobile_app/share_intent');

  static final StreamController<SharedDocument> _documentStreamController =
      StreamController<SharedDocument>.broadcast();

  static Stream<SharedDocument> get documentStream =>
      _documentStreamController.stream;

  static SharedDocument? _pendingDocument;

  static SharedDocument? get pendingDocument => _pendingDocument;

  static bool _isInitialized = false;

  /// Global callback handler for navigation when document arrives
  static void Function(SharedDocument doc)? onDirectNavigate;

  static Future<void> initialize() async {
    if (_isInitialized) return;
    _isInitialized = true;

    // Listen to native method calls from Kotlin MainActivity (onNewIntent)
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onFilesShared') {
        final List<dynamic>? files = call.arguments as List<dynamic>?;
        if (files != null && files.isNotEmpty) {
          for (final item in files) {
            if (item is Map) {
              final doc =
                  SharedDocument.fromMap(Map<String, dynamic>.from(item));
              _handleIncomingDocument(doc);
            }
          }
        }
      }
    });

    // Check cold-start intent
    await checkInitialSharedFiles();
  }

  static Future<SharedDocument?> checkInitialSharedFiles() async {
    try {
      final List<dynamic>? rawList =
          await _channel.invokeMethod<List<dynamic>>('getInitialSharedFiles');
      if (rawList != null && rawList.isNotEmpty) {
        final firstItem = rawList.first;
        if (firstItem is Map) {
          final doc =
              SharedDocument.fromMap(Map<String, dynamic>.from(firstItem));
          _pendingDocument = doc;
          _handleIncomingDocument(doc);
          return doc;
        }
      }
    } catch (e) {
      debugPrint('ShareIntentService getInitialSharedFiles error: $e');
    }
    return null;
  }

  static void _handleIncomingDocument(SharedDocument doc) {
    _pendingDocument = doc;
    _documentStreamController.add(doc);

    if (onDirectNavigate != null) {
      try {
        onDirectNavigate!(doc);
      } catch (e) {
        debugPrint('Direct navigate callback error: $e');
      }
    }
  }

  static SharedDocument? consumePendingDocument() {
    final doc = _pendingDocument;
    _pendingDocument = null;
    return doc;
  }

  static Future<void> clearNativeFiles() async {
    try {
      await _channel.invokeMethod('clearSharedFiles');
    } catch (_) {}
  }
}
