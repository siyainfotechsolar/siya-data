import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

/// Helper to load Unicode-compatible Devanagari (Marathi) and Latin fonts for PDF generation
class SolarQuotationFontHelper {
  static pw.Font? _cachedRegular;
  static pw.Font? _cachedBold;

  /// Loads Regular Devanagari font (Noto Sans Devanagari)
  static Future<pw.Font> loadRegularFont() async {
    if (_cachedRegular != null) return _cachedRegular!;

    // 1. Try rootBundle
    try {
      final ByteData data = await rootBundle.load('assets/fonts/NotoSansDevanagari-Regular.ttf');
      _cachedRegular = pw.Font.ttf(data);
      return _cachedRegular!;
    } catch (_) {}

    // 2. Try file system candidates for CLI, Desktop and Unit Tests
    if (!kIsWeb) {
      final candidates = [
        'assets/fonts/NotoSansDevanagari-Regular.ttf',
        'admin_panel/assets/fonts/NotoSansDevanagari-Regular.ttf',
        '../admin_panel/assets/fonts/NotoSansDevanagari-Regular.ttf',
        'mobile_app/assets/fonts/NotoSansDevanagari-Regular.ttf',
        'C:/Windows/Fonts/Nirmala.ttf',
        'C:/Windows/Fonts/mangal.ttf',
      ];
      for (final p in candidates) {
        try {
          final f = File(p);
          if (f.existsSync()) {
            final bytes = f.readAsBytesSync();
            _cachedRegular = pw.Font.ttf(ByteData.sublistView(bytes));
            return _cachedRegular!;
          }
        } catch (_) {}
      }
    }

    // 3. Fallback to PdfGoogleFonts
    try {
      _cachedRegular = await PdfGoogleFonts.notoSansDevanagariRegular();
      return _cachedRegular!;
    } catch (_) {}

    return pw.Font.helvetica();
  }

  /// Loads Bold Devanagari font (Noto Sans Devanagari Bold)
  static Future<pw.Font> loadBoldFont() async {
    if (_cachedBold != null) return _cachedBold!;

    // 1. Try rootBundle
    try {
      final ByteData data = await rootBundle.load('assets/fonts/NotoSansDevanagari-Bold.ttf');
      _cachedBold = pw.Font.ttf(data);
      return _cachedBold!;
    } catch (_) {}

    // 2. Try file system candidates
    if (!kIsWeb) {
      final candidates = [
        'assets/fonts/NotoSansDevanagari-Bold.ttf',
        'admin_panel/assets/fonts/NotoSansDevanagari-Bold.ttf',
        '../admin_panel/assets/fonts/NotoSansDevanagari-Bold.ttf',
        'mobile_app/assets/fonts/NotoSansDevanagari-Bold.ttf',
        'C:/Windows/Fonts/NirmalaB.ttf',
        'C:/Windows/Fonts/mangalb.ttf',
      ];
      for (final p in candidates) {
        try {
          final f = File(p);
          if (f.existsSync()) {
            final bytes = f.readAsBytesSync();
            _cachedBold = pw.Font.ttf(ByteData.sublistView(bytes));
            return _cachedBold!;
          }
        } catch (_) {}
      }
    }

    // 3. Fallback to PdfGoogleFonts
    try {
      _cachedBold = await PdfGoogleFonts.notoSansDevanagariBold();
      return _cachedBold!;
    } catch (_) {}

    return pw.Font.helveticaBold();
  }

  /// Creates a unified pw.ThemeData configured with both Latin and Devanagari fonts
  static Future<pw.ThemeData> loadPdfTheme() async {
    final devanagariRegular = await loadRegularFont();
    final devanagariBold = await loadBoldFont();
    final latinRegular = pw.Font.helvetica();
    final latinBold = pw.Font.helveticaBold();

    return pw.ThemeData.withFont(
      base: latinRegular,
      bold: latinBold,
      fontFallback: [devanagariRegular, devanagariBold, latinRegular, latinBold],
    );
  }
}
