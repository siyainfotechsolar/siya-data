import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

class CompanyStampHelper {
  /// Robustly loads stamp and signature bytes with multi-stage fallback
  static Future<Uint8List?> loadStampAndSignatureBytes({Uint8List? customBytes}) async {
    if (customBytes != null && customBytes.isNotEmpty) {
      return customBytes;
    }

    // 1. Try primary rootBundle pair
    try {
      final ByteData data = await rootBundle.load('assets/images/company_stamp_signature_pair.png');
      final bytes = data.buffer.asUint8List();
      if (bytes.isNotEmpty) return bytes;
    } catch (_) {}

    // 2. Try standalone stamp from rootBundle
    try {
      final ByteData data = await rootBundle.load('assets/images/company_stamp.png');
      final bytes = data.buffer.asUint8List();
      if (bytes.isNotEmpty) return bytes;
    } catch (_) {}

    // 3. Try direct filesystem read (for desktop, tests, command line)
    if (!kIsWeb) {
      final candidates = [
        'assets/images/company_stamp_signature_pair.png',
        'mobile_app/assets/images/company_stamp_signature_pair.png',
        '../assets/images/company_stamp_signature_pair.png',
        'admin_panel/assets/images/company_stamp_signature_pair.png',
        'build/unit_test_assets/assets/images/company_stamp_signature_pair.png',
        'assets/images/company_stamp.png',
        'mobile_app/assets/images/company_stamp.png',
      ];
      for (final p in candidates) {
        try {
          final f = File(p);
          if (f.existsSync()) {
            final bytes = f.readAsBytesSync();
            if (bytes.isNotEmpty) return bytes;
          }
        } catch (_) {}
      }
    }

    return null;
  }

  /// Draws official stamp and signature onto Syncfusion PdfGraphics
  /// If bitmap is available, renders the bitmap image.
  /// If bitmap is null but inclusion is requested, renders a crisp official vector seal.
  static void drawStampAndSignature({
    required PdfGraphics graphics,
    required Rect bounds,
    PdfBitmap? bitmap,
    bool include = false,
  }) {
    if (!include) return;

    if (bitmap != null) {
      graphics.drawImage(bitmap, bounds);
      return;
    }

    // Official Vector Stamp & Signature Fallback
    final double cx = bounds.left + bounds.width * 0.35;
    final double cy = bounds.top + bounds.height * 0.5;
    const double radius = 27.0;

    final PdfColor stampBlue = PdfColor(15, 45, 105); // #0F2D69
    final PdfPen outerPen = PdfPen(stampBlue, width: 1.5);
    final PdfPen innerPen = PdfPen(stampBlue, width: 0.8);
    final PdfBrush stampBrush = PdfSolidBrush(stampBlue);

    // Outer and Inner Stamp Box with Rounded Aesthetic
    graphics.drawRectangle(
      pen: outerPen,
      bounds: Rect.fromLTWH(cx - radius, cy - radius, radius * 2, radius * 2),
    );
    graphics.drawRectangle(
      pen: innerPen,
      bounds: Rect.fromLTWH(cx - radius + 3, cy - radius + 3, (radius - 3) * 2, (radius - 3) * 2),
    );

    // Stamp text inside seal
    final PdfFont topFont = PdfStandardFont(PdfFontFamily.helvetica, 5.2, style: PdfFontStyle.bold);
    final PdfFont midFont = PdfStandardFont(PdfFontFamily.helvetica, 4.8, style: PdfFontStyle.bold);
    final PdfFont botFont = PdfStandardFont(PdfFontFamily.helvetica, 4.5, style: PdfFontStyle.bold);

    graphics.drawString(
      'SIYA INFOTECH &',
      topFont,
      brush: stampBrush,
      bounds: Rect.fromLTWH(cx - radius + 4, cy - 17, (radius - 4) * 2, 8),
      format: PdfStringFormat(alignment: PdfTextAlignment.center),
    );
    graphics.drawString(
      'DIGITAL SOLUTIONS',
      topFont,
      brush: stampBrush,
      bounds: Rect.fromLTWH(cx - radius + 4, cy - 10, (radius - 4) * 2, 8),
      format: PdfStringFormat(alignment: PdfTextAlignment.center),
    );
    graphics.drawString(
      '★ BETAWAD ★',
      midFont,
      brush: stampBrush,
      bounds: Rect.fromLTWH(cx - radius + 4, cy - 2, (radius - 4) * 2, 7),
      format: PdfStringFormat(alignment: PdfTextAlignment.center),
    );
    graphics.drawString(
      'AUTH. SIGNATORY',
      botFont,
      brush: stampBrush,
      bounds: Rect.fromLTWH(cx - radius + 4, cy + 8, (radius - 4) * 2, 7),
      format: PdfStringFormat(alignment: PdfTextAlignment.center),
    );

    // Right-aligned Signature Overlay
    final double sigX = bounds.left + bounds.width * 0.45;
    final double sigY = bounds.top + bounds.height * 0.25;
    final double sigW = bounds.width * 0.55;

    final PdfFont sigFont = PdfStandardFont(PdfFontFamily.helvetica, 12.0, style: PdfFontStyle.bold);
    graphics.drawString(
      'Siya Infotech',
      sigFont,
      brush: stampBrush,
      bounds: Rect.fromLTWH(sigX, sigY, sigW, 18),
      format: PdfStringFormat(alignment: PdfTextAlignment.center),
    );

    final PdfFont subSigFont = PdfStandardFont(PdfFontFamily.helvetica, 6.5, style: PdfFontStyle.bold);
    graphics.drawString(
      'Authorized Signatory',
      subSigFont,
      brush: stampBrush,
      bounds: Rect.fromLTWH(sigX, sigY + 18, sigW, 10),
      format: PdfStringFormat(alignment: PdfTextAlignment.center),
    );
  }
}
