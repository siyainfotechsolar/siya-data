import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class AdminCompanyStampHelper {
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
        'admin_panel/assets/images/company_stamp_signature_pair.png',
        'mobile_app/assets/images/company_stamp_signature_pair.png',
        '../assets/images/company_stamp_signature_pair.png',
        'build/unit_test_assets/assets/images/company_stamp_signature_pair.png',
        'assets/images/company_stamp.png',
        'admin_panel/assets/images/company_stamp.png',
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

  /// Builds the official stamp and signature pw.Widget.
  /// If image is loaded, displays the image.
  /// If image is null but include is true, displays the crisp vector official badge.
  static pw.Widget buildStampAndSignatureWidget({
    pw.MemoryImage? image,
    bool include = true,
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
    const PdfColor stampBlue = PdfColor(15 / 255, 45 / 255, 105 / 255); // #0F2D69

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
