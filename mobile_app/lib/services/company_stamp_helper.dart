import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart' as sf;
import 'package:pdf/pdf.dart' as pw_pdf;
import 'package:pdf/widgets.dart' as pw;

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

  /// Robustly loads Rs. 100 Stamp Paper image bytes with multi-stage fallback
  static Future<Uint8List?> loadStampPaperBytes({Uint8List? customBytes}) async {
    if (customBytes != null && customBytes.isNotEmpty) {
      return customBytes;
    }

    // 1. Try primary rootBundle
    try {
      final ByteData data = await rootBundle.load('assets/images/stamp_paper_100.jpg');
      final bytes = data.buffer.asUint8List();
      if (bytes.isNotEmpty) return bytes;
    } catch (_) {}

    // 2. Try direct filesystem read (for desktop, tests, command line)
    if (!kIsWeb) {
      final candidates = [
        'assets/images/stamp_paper_100.jpg',
        'mobile_app/assets/images/stamp_paper_100.jpg',
        '../assets/images/stamp_paper_100.jpg',
        'admin_panel/assets/images/stamp_paper_100.jpg',
        'build/unit_test_assets/assets/images/stamp_paper_100.jpg',
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
    required sf.PdfGraphics graphics,
    required Rect bounds,
    sf.PdfBitmap? bitmap,
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

    final sf.PdfColor stampBlue = sf.PdfColor(15, 45, 105); // #0F2D69
    final sf.PdfPen outerPen = sf.PdfPen(stampBlue, width: 1.5);
    final sf.PdfPen innerPen = sf.PdfPen(stampBlue, width: 0.8);
    final sf.PdfBrush stampBrush = sf.PdfSolidBrush(stampBlue);

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
    final sf.PdfFont topFont = sf.PdfStandardFont(sf.PdfFontFamily.helvetica, 5.2, style: sf.PdfFontStyle.bold);
    final sf.PdfFont midFont = sf.PdfStandardFont(sf.PdfFontFamily.helvetica, 4.8, style: sf.PdfFontStyle.bold);
    final sf.PdfFont botFont = sf.PdfStandardFont(sf.PdfFontFamily.helvetica, 4.5, style: sf.PdfFontStyle.bold);

    graphics.drawString(
      'SIYA INFOTECH &',
      topFont,
      brush: stampBrush,
      bounds: Rect.fromLTWH(cx - radius + 4, cy - 17, (radius - 4) * 2, 8),
      format: sf.PdfStringFormat(alignment: sf.PdfTextAlignment.center),
    );
    graphics.drawString(
      'DIGITAL SOLUTIONS',
      topFont,
      brush: stampBrush,
      bounds: Rect.fromLTWH(cx - radius + 4, cy - 10, (radius - 4) * 2, 8),
      format: sf.PdfStringFormat(alignment: sf.PdfTextAlignment.center),
    );
    graphics.drawString(
      '★ BETAWAD ★',
      midFont,
      brush: stampBrush,
      bounds: Rect.fromLTWH(cx - radius + 4, cy - 2, (radius - 4) * 2, 7),
      format: sf.PdfStringFormat(alignment: sf.PdfTextAlignment.center),
    );
    graphics.drawString(
      'AUTH. SIGNATORY',
      botFont,
      brush: stampBrush,
      bounds: Rect.fromLTWH(cx - radius + 4, cy + 8, (radius - 4) * 2, 7),
      format: sf.PdfStringFormat(alignment: sf.PdfTextAlignment.center),
    );

    // Right-aligned Signature Overlay
    final double sigX = bounds.left + bounds.width * 0.45;
    final double sigY = bounds.top + bounds.height * 0.25;
    final double sigW = bounds.width * 0.55;

    final sf.PdfFont sigFont = sf.PdfStandardFont(sf.PdfFontFamily.helvetica, 12.0, style: sf.PdfFontStyle.bold);
    graphics.drawString(
      'Siya Infotech',
      sigFont,
      brush: stampBrush,
      bounds: Rect.fromLTWH(sigX, sigY, sigW, 18),
      format: sf.PdfStringFormat(alignment: sf.PdfTextAlignment.center),
    );

    final sf.PdfFont subSigFont = sf.PdfStandardFont(sf.PdfFontFamily.helvetica, 6.5, style: sf.PdfFontStyle.bold);
    graphics.drawString(
      'Authorized Signatory',
      subSigFont,
      brush: stampBrush,
      bounds: Rect.fromLTWH(sigX, sigY + 18, sigW, 10),
      format: sf.PdfStringFormat(alignment: sf.PdfTextAlignment.center),
    );
  }

  /// Builds the official stamp and signature pw.Widget.
  /// If image is loaded, displays the image.
  /// If image is null but include is true, displays the crisp vector official badge.
  static pw.Widget buildStampAndSignatureWidget({
    pw.MemoryImage? image,
    bool include = false,
    double height = 72,
    double width = 160,
  }) {
    if (!include) {
      return pw.SizedBox(height: height, width: width);
    }

    if (image != null) {
      return pw.Container(
        height: height,
        width: width,
        alignment: pw.Alignment.center,
        child: pw.Image(image, fit: pw.BoxFit.contain),
      );
    }

    // Official Vector Stamp & Signature Fallback (Deep Blue / Indigo Ink)
    const pw_pdf.PdfColor stampBlue = pw_pdf.PdfColor(15 / 255, 45 / 255, 105 / 255); // #0F2D69

    return pw.Container(
      height: height,
      width: width,
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.center,
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          // Circular Seal
          pw.Container(
            width: 58,
            height: 58,
            decoration: pw.BoxDecoration(
              shape: pw.BoxShape.circle,
              border: pw.Border.all(color: stampBlue, width: 1.5),
            ),
            padding: const pw.EdgeInsets.all(2.5),
            child: pw.Container(
              decoration: pw.BoxDecoration(
                shape: pw.BoxShape.circle,
                border: pw.Border.all(color: stampBlue, width: 0.8),
              ),
              padding: const pw.EdgeInsets.symmetric(horizontal: 2),
              child: pw.Column(
                mainAxisAlignment: pw.MainAxisAlignment.center,
                children: [
                  pw.Text(
                    'SIYA INFOTECH',
                    style: pw.TextStyle(color: stampBlue, fontSize: 4.8, fontWeight: pw.FontWeight.bold),
                    textAlign: pw.TextAlign.center,
                  ),
                  pw.Text(
                    '& DIGITAL',
                    style: pw.TextStyle(color: stampBlue, fontSize: 4.4, fontWeight: pw.FontWeight.bold),
                    textAlign: pw.TextAlign.center,
                  ),
                  pw.SizedBox(height: 1),
                  pw.Text(
                    '★ BETAWAD ★',
                    style: pw.TextStyle(color: stampBlue, fontSize: 4.0, fontWeight: pw.FontWeight.bold),
                    textAlign: pw.TextAlign.center,
                  ),
                  pw.SizedBox(height: 1),
                  pw.Text(
                    'AUTH. SIGNATORY',
                    style: pw.TextStyle(color: stampBlue, fontSize: 3.8, fontWeight: pw.FontWeight.bold),
                    textAlign: pw.TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
          pw.SizedBox(width: 8),

          // Signature text
          pw.Column(
            mainAxisAlignment: pw.MainAxisAlignment.center,
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.Text(
                'Siya Infotech',
                style: pw.TextStyle(
                  color: stampBlue,
                  fontSize: 12,
                  fontWeight: pw.FontWeight.bold,
                  fontStyle: pw.FontStyle.italic,
                ),
              ),
              pw.SizedBox(height: 2),
              pw.Text(
                'Authorized Signatory',
                style: pw.TextStyle(
                  color: stampBlue,
                  fontSize: 6.5,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

typedef AdminCompanyStampHelper = CompanyStampHelper;
