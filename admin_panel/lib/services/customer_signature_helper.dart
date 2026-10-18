import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Helper that generates authentic cursive handwritten customer signatures
/// in realistic blue pen ink from the customer's name, and processes uploaded
/// signatures by automatically removing dirty/grey paper backgrounds.
class CustomerSignatureHelper {
  static pw.Font? _cachedSignatureFont;
  static final Map<String, Uint8List> _customSignatures = {};

  static String _normalizeKey(String key) => key.trim().toUpperCase();

  /// Saves an uploaded customer signature image in memory for the given customer identifier (consumerNo or customerId),
  /// automatically removing background shadows/grey paper and converting to a clean transparent/white background.
  static void setCustomerSignature(String consumerOrCustomerId, Uint8List rawBytes) {
    if (consumerOrCustomerId.trim().isNotEmpty) {
      final processedBytes = removeSignatureBackground(rawBytes);
      final key = _normalizeKey(consumerOrCustomerId);
      _customSignatures[key] = processedBytes;

      // Persist locally in SharedPreferences and in Supabase in background
      _persistCustomerSignatureAsync(consumerOrCustomerId.trim(), processedBytes);
    }
  }

  static Future<void> _persistCustomerSignatureAsync(String consumerNo, Uint8List bytes) async {
    final b64 = base64Encode(bytes);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('customer_signature_${_normalizeKey(consumerNo)}', b64);
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
          .eq('document_type', 'Customer Signature')
          .limit(1);

      final docData = {
        'customer_id': customerId,
        'consumer_no': consumerNo,
        'document_type': 'Customer Signature',
        'document_name': 'Customer_Signature_$consumerNo.png',
        'file_url': 'data:image/png;base64,$b64',
        'source': 'Signature Upload Helper',
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
      debugPrint('Notice saving customer signature to Supabase: $e');
    }
  }

  /// Automatically removes grey, yellow, and shadowy paper backgrounds from
  /// an uploaded signature image, producing a crisp, clean signature with
  /// transparent/pure white background and smooth anti-aliased ink edges.
  static Uint8List removeSignatureBackground(Uint8List rawBytes) {
    try {
      final image = img.decodeImage(rawBytes);
      if (image == null) return rawBytes;

      // Ensure RGBA format with 4 channels
      final rgbaImage = image.hasAlpha ? image : image.convert(numChannels: 4);

      // 1. Analyze brightness distribution to dynamically adapt to lighting
      final lumSamples = <int>[];
      for (int y = 0; y < rgbaImage.height; y += 2) {
        for (int x = 0; x < rgbaImage.width; x += 2) {
          final p = rgbaImage.getPixel(x, y);
          final r = p.r.toInt();
          final g = p.g.toInt();
          final b = p.b.toInt();
          final lum = (0.299 * r + 0.587 * g + 0.114 * b).round().clamp(0, 255);
          lumSamples.add(lum);
        }
      }

      if (lumSamples.isEmpty) return rawBytes;

      lumSamples.sort();
      // Estimate background brightness from 90th percentile
      final p90Index = (lumSamples.length * 0.90).floor().clamp(0, lumSamples.length - 1);
      final bgLum = lumSamples[p90Index];
      // Estimate ink brightness from 10th percentile
      final p10Index = (lumSamples.length * 0.10).floor().clamp(0, lumSamples.length - 1);
      final inkLum = lumSamples[p10Index];

      // Dynamic thresholds
      final highThreshold = (bgLum - (bgLum - inkLum) * 0.28).clamp(160, 245).toDouble();
      final lowThreshold = (inkLum + (bgLum - inkLum) * 0.22).clamp(40, 150).toDouble();

      int minX = rgbaImage.width;
      int maxX = 0;
      int minY = rgbaImage.height;
      int maxY = 0;
      bool hasInk = false;

      for (int y = 0; y < rgbaImage.height; y++) {
        for (int x = 0; x < rgbaImage.width; x++) {
          final p = rgbaImage.getPixel(x, y);
          final r = p.r.toInt();
          final g = p.g.toInt();
          final b = p.b.toInt();
          final lum = 0.299 * r + 0.587 * g + 0.114 * b;

          if (lum >= highThreshold) {
            // Pure background -> make completely transparent
            rgbaImage.setPixelRgba(x, y, 255, 255, 255, 0);
          } else if (lum <= lowThreshold) {
            // Full ink -> sharpen ink contrast slightly (deepen blue/black ink)
            final newR = (r * 0.85).round().clamp(0, 255);
            final newG = (g * 0.85).round().clamp(0, 255);
            final newB = (b * 0.85).round().clamp(0, 255);
            rgbaImage.setPixelRgba(x, y, newR, newG, newB, 255);
            if (x < minX) minX = x;
            if (x > maxX) maxX = x;
            if (y < minY) minY = y;
            if (y > maxY) maxY = y;
            hasInk = true;
          } else {
            // Anti-aliased transition edge
            final factor = (1.0 - (lum - lowThreshold) / (highThreshold - lowThreshold)).clamp(0.0, 1.0);
            final alpha = (factor * 255).round().clamp(0, 255);
            rgbaImage.setPixelRgba(x, y, r, g, b, alpha);
            if (alpha > 40) {
              if (x < minX) minX = x;
              if (x > maxX) maxX = x;
              if (y < minY) minY = y;
              if (y > maxY) maxY = y;
              hasInk = true;
            }
          }
        }
      }

      // Crop to ink content with an 8px border margin if ink was detected
      img.Image finalImage = rgbaImage;
      if (hasInk && maxX > minX && maxY > minY) {
        final cropX = (minX - 8).clamp(0, rgbaImage.width - 1);
        final cropY = (minY - 8).clamp(0, rgbaImage.height - 1);
        final cropW = (maxX - minX + 16).clamp(1, rgbaImage.width - cropX);
        final cropH = (maxY - minY + 16).clamp(1, rgbaImage.height - cropY);
        finalImage = img.copyCrop(rgbaImage, x: cropX, y: cropY, width: cropW, height: cropH);
      }

      return Uint8List.fromList(img.encodePng(finalImage));
    } catch (e) {
      debugPrint('Error removing signature background: $e');
      return rawBytes;
    }
  }

  /// Retrieves an uploaded customer signature image for the given customer identifier
  static Uint8List? getCustomerSignature(String consumerOrCustomerId) {
    if (consumerOrCustomerId.trim().isEmpty) return null;
    return _customSignatures[_normalizeKey(consumerOrCustomerId)];
  }

  /// Checks if an uploaded customer signature image is available for this customer
  static bool hasCustomerSignature(String consumerOrCustomerId) {
    if (consumerOrCustomerId.trim().isEmpty) return false;
    return _customSignatures.containsKey(_normalizeKey(consumerOrCustomerId));
  }

  /// Ensures customer signature is loaded from memory, SharedPreferences, or Supabase
  static Future<bool> ensureCustomerSignatureLoaded(String consumerOrCustomerId) async {
    if (consumerOrCustomerId.trim().isEmpty) return false;
    final key = _normalizeKey(consumerOrCustomerId);
    if (_customSignatures.containsKey(key)) return true;

    // 1. Try local SharedPreferences
    try {
      final prefs = await SharedPreferences.getInstance();
      final localB64 = prefs.getString('customer_signature_$key');
      if (localB64 != null && localB64.isNotEmpty) {
        final decoded = base64Decode(localB64);
        _customSignatures[key] = decoded;
        return true;
      }
    } catch (_) {}

    // 2. Try Supabase customer_documents
    try {
      final client = Supabase.instance.client;
      final clean = consumerOrCustomerId.trim();
      final res = await client
          .from('customer_documents')
          .select('extracted_data')
          .eq('consumer_no', clean)
          .eq('document_type', 'Customer Signature')
          .limit(1);

      if (res.isNotEmpty) {
        final extracted = res.first['extracted_data'] as Map<String, dynamic>?;
        final b64 = extracted?['base64']?.toString();
        if (b64 != null && b64.isNotEmpty) {
          final decoded = base64Decode(b64);
          _customSignatures[key] = decoded;
          try {
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString('customer_signature_$key', b64);
          } catch (_) {}
          return true;
        }
      }
    } catch (_) {}

    return false;
  }

  /// Clears an uploaded customer signature
  static void clearCustomerSignature(String consumerOrCustomerId) {
    if (consumerOrCustomerId.trim().isNotEmpty) {
      final key = _normalizeKey(consumerOrCustomerId);
      _customSignatures.remove(key);

      // Remove from SharedPreferences & Supabase in background
      SharedPreferences.getInstance().then((prefs) {
        prefs.remove('customer_signature_$key');
      }).catchError((_) {});

      try {
        Supabase.instance.client
            .from('customer_documents')
            .delete()
            .eq('consumer_no', consumerOrCustomerId.trim())
            .eq('document_type', 'Customer Signature')
            .catchError((_) {});
      } catch (_) {}
    }
  }

  /// Loads the signature TTF font with multi-source fallback
  static Future<pw.Font> loadSignatureFont() async {
    if (_cachedSignatureFont != null) {
      return _cachedSignatureFont!;
    }

    // 1. Try loading DancingScript from rootBundle
    try {
      final ByteData data = await rootBundle.load('assets/fonts/DancingScript.ttf');
      _cachedSignatureFont = pw.Font.ttf(data);
      return _cachedSignatureFont!;
    } catch (_) {}

    // 2. Direct filesystem read (for desktop, CLI, and unit test environments)
    if (!kIsWeb) {
      final candidates = [
        'assets/fonts/DancingScript.ttf',
        'admin_panel/assets/fonts/DancingScript.ttf',
        'mobile_app/assets/fonts/DancingScript.ttf',
        '../assets/fonts/DancingScript.ttf',
        'build/unit_test_assets/assets/fonts/DancingScript.ttf',
      ];
      for (final p in candidates) {
        try {
          final f = File(p);
          if (f.existsSync()) {
            final bytes = f.readAsBytesSync();
            final byteData = ByteData.sublistView(bytes);
            _cachedSignatureFont = pw.Font.ttf(byteData);
            return _cachedSignatureFont!;
          }
        } catch (_) {}
      }
    }

    // 3. Fallback to italic standard font
    return pw.Font.helveticaOblique();
  }

  /// Formats name for natural signature display (e.g. Ramesh Balasaheb Patil -> Ramesh B. Patil)
  static String formatSignatureName(String rawName) {
    if (rawName.trim().isEmpty) return 'Customer';
    final parts = rawName.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return 'Customer';

    String toTitleCase(String s) {
      if (s.isEmpty) return '';
      return s[0].toUpperCase() + s.substring(1).toLowerCase();
    }

    if (parts.length == 1) {
      return toTitleCase(parts[0]);
    } else if (parts.length == 2) {
      return '${toTitleCase(parts[0])} ${toTitleCase(parts[1])}';
    } else {
      final first = toTitleCase(parts[0]);
      final midInitial = parts[1][0].toUpperCase();
      final last = toTitleCase(parts.last);
      return '$first $midInitial. $last';
    }
  }

  /// Builds a realistic digital signature widget in blue ink with pen flourish
  static pw.Widget buildSignature({
    required String customerName,
    required pw.Font font,
    double fontSize = 16.0,
    bool includeUnderline = true,
    PdfColor color = const PdfColor.fromInt(0xFF0F3B7A), // Classic royal blue ink
  }) {
    final displayName = formatSignatureName(customerName);

    return pw.Column(
      mainAxisSize: pw.MainAxisSize.min,
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pw.Transform.rotate(
          angle: -0.045, // Subtle -2.6 degree natural signature tilt
          child: pw.Text(
            displayName,
            style: pw.TextStyle(
              font: font,
              fontSize: fontSize,
              fontWeight: pw.FontWeight.bold,
              color: color,
            ),
          ),
        ),
        if (includeUnderline) ...[
          pw.SizedBox(height: 1),
          pw.CustomPaint(
            size: const PdfPoint(95, 3),
            painter: (PdfGraphics canvas, PdfPoint size) {
              canvas.setColor(color);
              canvas.setLineWidth(1.0);
              canvas.moveTo(2, 2.5);
              canvas.curveTo(25, 0.5, 65, 3.0, size.x - 6, 1.5);
              canvas.strokePath();
              canvas.drawEllipse(size.x - 3, 1.5, 1.1, 1.1);
              canvas.fillPath();
            },
          ),
        ],
      ],
    );
  }

  /// High-level signature widget: Renders uploaded signature image if present,
  /// otherwise renders authentic cursive handwritten signature from name.
  static pw.Widget buildSignatureWidget({
    required String customerName,
    String? consumerNo,
    Uint8List? customSignatureBytes,
    pw.Font? font,
    bool includeSignature = false,
    double height = 48.0,
    double fontSize = 16.0,
    bool includeUnderline = true,
    PdfColor color = const PdfColor.fromInt(0xFF0F3B7A),
  }) {
    if (!includeSignature) {
      return pw.SizedBox(height: height);
    }

    final effectiveBytes = customSignatureBytes ??
        (consumerNo != null ? getCustomerSignature(consumerNo) : null);

    if (effectiveBytes != null && effectiveBytes.isNotEmpty) {
      try {
        final memImage = pw.MemoryImage(effectiveBytes);
        return pw.Container(
          height: height,
          alignment: pw.Alignment.bottomCenter,
          child: pw.Image(
            memImage,
            height: height,
            fit: pw.BoxFit.contain,
          ),
        );
      } catch (e) {
        debugPrint('Error rendering uploaded customer signature: $e');
      }
    }

    if (font != null) {
      return pw.Container(
        height: height,
        alignment: pw.Alignment.bottomCenter,
        child: buildSignature(
          customerName: customerName,
          font: font,
          fontSize: fontSize,
          includeUnderline: includeUnderline,
          color: color,
        ),
      );
    }

    return pw.SizedBox(height: height);
  }
}
