import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// Helper that generates authentic cursive handwritten customer signatures
/// in realistic blue pen ink from the customer's name.
class CustomerSignatureHelper {
  static pw.Font? _cachedSignatureFont;
  static final Map<String, Uint8List> _customSignatures = {};

  static String _normalizeKey(String key) => key.trim().toUpperCase();

  /// Saves an uploaded customer signature image in memory for the given customer identifier (consumerNo or customerId)
  static void setCustomerSignature(String consumerOrCustomerId, Uint8List bytes) {
    if (consumerOrCustomerId.trim().isNotEmpty) {
      _customSignatures[_normalizeKey(consumerOrCustomerId)] = bytes;
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

  /// Clears an uploaded customer signature
  static void clearCustomerSignature(String consumerOrCustomerId) {
    if (consumerOrCustomerId.trim().isNotEmpty) {
      _customSignatures.remove(_normalizeKey(consumerOrCustomerId));
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
    bool includeSignature = true,
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
