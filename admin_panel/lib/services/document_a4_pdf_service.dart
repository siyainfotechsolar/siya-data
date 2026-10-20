import 'package:flutter/foundation.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/document_enhancer_models.dart';
import 'document_image_processor.dart';

/// Professional A4 Page Conversion and Merging Engine
class DocumentA4PdfService {
  /// Rasterizes an uploaded PDF into individual page images
  static Future<List<DocumentToolItem>> extractPagesFromPdf({
    required String fileId,
    required String fileName,
    required Uint8List pdfBytes,
  }) async {
    final List<DocumentToolItem> items = [];

    try {
      int pageIndex = 1;
      await for (final rasterPage in Printing.raster(pdfBytes, dpi: 150)) {
        final pngBytes = await rasterPage.toPng();
        final meta = DocumentImageProcessor.analyzeImage(pngBytes);

        items.add(DocumentToolItem(
          id: '${fileId}_page_$pageIndex',
          name: '$fileName (Page $pageIndex)',
          fileSize: pngBytes.length,
          mimeType: 'image/png',
          originalBytes: pngBytes,
          processedBytes: null,
          thumbnailBytes: meta['thumbnail'],
          width: meta['width'] ?? 0,
          height: meta['height'] ?? 0,
          isPdf: true,
          pdfPageNumber: pageIndex,
          totalPdfPages: 1, // Will be updated after stream
          qualityWarning: meta['warning'],
        ));

        pageIndex++;
      }

      // Update total pages
      final total = pageIndex - 1;
      return items.map((it) => it.copyWith(totalPdfPages: total)).toList();
    } catch (e) {
      debugPrint('Error rasterizing PDF: $e');
      throw Exception('Failed to parse PDF document. It may be password-protected or corrupted: $e');
    }
  }

  /// Builds a complete printable A4 PDF from a list of document items and settings
  static Future<Uint8List> generateA4Pdf({
    required List<DocumentToolItem> items,
    required A4PageSettings settings,
    String? title,
  }) async {
    final selectedItems = items.where((it) => it.isSelected).toList();
    if (selectedItems.isEmpty) {
      throw Exception('No documents or images selected to generate PDF.');
    }

    final doc = pw.Document(
      title: title ?? 'Siya Documents',
      author: 'Siya Solar Connect',
      creator: 'Siya Data Management Software',
    );

    final double marginPt = settings.marginPoints;

    switch (settings.layout) {
      case A4Layout.onePerPage:
        await _buildOnePerPageLayout(doc, selectedItems, settings, marginPt);
        break;
      case A4Layout.twoPerPage:
        await _buildTwoPerPageLayout(doc, selectedItems, settings, marginPt);
        break;
      case A4Layout.fourPerPage:
        await _buildFourPerPageLayout(doc, selectedItems, settings, marginPt);
        break;
    }

    return await doc.save();
  }

  /// 1 photo / document per A4 page layout
  static Future<void> _buildOnePerPageLayout(
    pw.Document doc,
    List<DocumentToolItem> items,
    A4PageSettings settings,
    double marginPt,
  ) async {
    for (final item in items) {
      final imageBytes = item.displayBytes;
      final pwImage = pw.MemoryImage(imageBytes);

      // Determine page format
      final bool isLandscape;
      if (settings.orientation == A4Orientation.auto) {
        isLandscape = item.width > (item.height * 1.05);
      } else {
        isLandscape = settings.orientation == A4Orientation.landscape;
      }

      final pageFormat = isLandscape ? PdfPageFormat.a4.landscape : PdfPageFormat.a4;

      final pw.BoxFit boxFit = switch (settings.fitMode) {
        A4FitMode.fit => pw.BoxFit.contain,
        A4FitMode.fill => pw.BoxFit.cover,
        A4FitMode.actual => pw.BoxFit.scaleDown,
      };

      final pw.Alignment pwAlign = switch (settings.alignment) {
        A4Alignment.center => pw.Alignment.center,
        A4Alignment.top => pw.Alignment.topCenter,
      };

      doc.addPage(
        pw.Page(
          pageFormat: pageFormat,
          margin: pw.EdgeInsets.all(marginPt),
          build: (pw.Context context) {
            return pw.Container(
              alignment: pwAlign,
              width: double.infinity,
              height: double.infinity,
              child: pw.Image(
                pwImage,
                fit: boxFit,
                alignment: pwAlign,
              ),
            );
          },
        ),
      );
    }
  }

  /// 2 photos per A4 page layout (e.g. Aadhaar Card front & back on 1 sheet!)
  static Future<void> _buildTwoPerPageLayout(
    pw.Document doc,
    List<DocumentToolItem> items,
    A4PageSettings settings,
    double marginPt,
  ) async {
    final bool isLandscape = settings.orientation == A4Orientation.landscape;
    final pageFormat = isLandscape ? PdfPageFormat.a4.landscape : PdfPageFormat.a4;

    for (int i = 0; i < items.length; i += 2) {
      final item1 = items[i];
      final item2 = (i + 1 < items.length) ? items[i + 1] : null;

      final img1 = pw.MemoryImage(item1.displayBytes);
      final img2 = item2 != null ? pw.MemoryImage(item2.displayBytes) : null;

      doc.addPage(
        pw.Page(
          pageFormat: pageFormat,
          margin: pw.EdgeInsets.all(marginPt),
          build: (pw.Context context) {
            if (isLandscape) {
              // Side by side in landscape
              return pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  pw.Expanded(
                    child: pw.Container(
                      padding: const pw.EdgeInsets.all(8),
                      alignment: pw.Alignment.center,
                      child: pw.Image(img1, fit: pw.BoxFit.contain),
                    ),
                  ),
                  if (img2 != null) ...[
                    pw.VerticalDivider(width: 16, thickness: 0.5, color: PdfColors.grey300),
                    pw.Expanded(
                      child: pw.Container(
                        padding: const pw.EdgeInsets.all(8),
                        alignment: pw.Alignment.center,
                        child: pw.Image(img2, fit: pw.BoxFit.contain),
                      ),
                    ),
                  ] else
                    pw.Spacer(),
                ],
              );
            } else {
              // Stacked vertically in portrait (Standard for 2 ID cards / receipts)
              return pw.Column(
                mainAxisAlignment: pw.MainAxisAlignment.spaceEvenly,
                children: [
                  pw.Expanded(
                    child: pw.Container(
                      padding: const pw.EdgeInsets.all(12),
                      alignment: pw.Alignment.center,
                      child: pw.Image(img1, fit: pw.BoxFit.contain),
                    ),
                  ),
                  if (img2 != null) ...[
                    pw.Divider(height: 20, thickness: 0.5, color: PdfColors.grey300),
                    pw.Expanded(
                      child: pw.Container(
                        padding: const pw.EdgeInsets.all(12),
                        alignment: pw.Alignment.center,
                        child: pw.Image(img2, fit: pw.BoxFit.contain),
                      ),
                    ),
                  ] else
                    pw.Spacer(),
                ],
              );
            }
          },
        ),
      );
    }
  }

  /// 4 photos per A4 page layout (2x2 grid)
  static Future<void> _buildFourPerPageLayout(
    pw.Document doc,
    List<DocumentToolItem> items,
    A4PageSettings settings,
    double marginPt,
  ) async {
    final bool isLandscape = settings.orientation == A4Orientation.landscape;
    final pageFormat = isLandscape ? PdfPageFormat.a4.landscape : PdfPageFormat.a4;

    for (int i = 0; i < items.length; i += 4) {
      final chunk = items.sublist(i, (i + 4 < items.length) ? i + 4 : items.length);

      final imgList = chunk.map((it) => pw.MemoryImage(it.displayBytes)).toList();

      doc.addPage(
        pw.Page(
          pageFormat: pageFormat,
          margin: pw.EdgeInsets.all(marginPt),
          build: (pw.Context context) {
            return pw.Column(
              children: [
                // Top Row
                pw.Expanded(
                  child: pw.Row(
                    children: [
                      pw.Expanded(
                        child: pw.Container(
                          padding: const pw.EdgeInsets.all(6),
                          alignment: pw.Alignment.center,
                          child: pw.Image(imgList[0], fit: pw.BoxFit.contain),
                        ),
                      ),
                      if (imgList.length > 1)
                        pw.Expanded(
                          child: pw.Container(
                            padding: const pw.EdgeInsets.all(6),
                            alignment: pw.Alignment.center,
                            child: pw.Image(imgList[1], fit: pw.BoxFit.contain),
                          ),
                        )
                      else
                        pw.Spacer(),
                    ],
                  ),
                ),
                pw.Divider(height: 12, thickness: 0.5, color: PdfColors.grey300),
                // Bottom Row
                pw.Expanded(
                  child: pw.Row(
                    children: [
                      if (imgList.length > 2)
                        pw.Expanded(
                          child: pw.Container(
                            padding: const pw.EdgeInsets.all(6),
                            alignment: pw.Alignment.center,
                            child: pw.Image(imgList[2], fit: pw.BoxFit.contain),
                          ),
                        )
                      else
                        pw.Spacer(),
                      if (imgList.length > 3)
                        pw.Expanded(
                          child: pw.Container(
                            padding: const pw.EdgeInsets.all(6),
                            alignment: pw.Alignment.center,
                            child: pw.Image(imgList[3], fit: pw.BoxFit.contain),
                          ),
                        )
                      else
                        pw.Spacer(),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      );
    }
  }

  /// Generates dedicated ISO A4 PDF for Aadhaar Card Front & Back on a single page
  static Future<Uint8List> generateAadhaarA4Pdf({
    DocumentToolItem? frontItem,
    DocumentToolItem? backItem,
    required AadhaarPageSettings settings,
    String? title,
  }) async {
    if (frontItem == null && backItem == null) {
      throw Exception('Please upload at least the Front or Back of the Aadhaar Card.');
    }

    final doc = pw.Document(
      title: title ?? 'Aadhaar Card Front & Back',
      author: 'Siya Solar Connect',
      creator: 'Siya Data Management Software',
    );

    final double marginPt = settings.marginPoints;
    final pageFormat = PdfPageFormat.a4; // 595.28 x 841.89 points
    final double printableWidth = pageFormat.width - (marginPt * 2);
    final double printableHeight = pageFormat.height - (marginPt * 2);

    // Target card width based on scale
    double targetCardWidth;
    switch (settings.scale) {
      case AadhaarCardScale.actualIdSize:
        targetCardWidth = 242.6; // 85.6 mm (standard pocket ID card width)
        break;
      case AadhaarCardScale.mediumScale:
        targetCardWidth = 330.0; // ~116 mm - optimal readable print
        break;
      case AadhaarCardScale.largeScale:
        targetCardWidth = 400.0; // ~141 mm - large clear print
        break;
      case AadhaarCardScale.fitWidth:
        targetCardWidth = printableWidth * 0.90;
        break;
    }

    if (targetCardWidth > printableWidth) {
      targetCardWidth = printableWidth;
    }

    // Calculate heights preserving aspect ratio
    double frontHeight = 0;
    if (frontItem != null) {
      final double ar = frontItem.width > 0 && frontItem.height > 0
          ? (frontItem.width / frontItem.height)
          : (85.6 / 54.0);
      frontHeight = targetCardWidth / ar;
    }

    double backHeight = 0;
    if (backItem != null) {
      final double ar = backItem.width > 0 && backItem.height > 0
          ? (backItem.width / backItem.height)
          : (85.6 / 54.0);
      backHeight = targetCardWidth / ar;
    }

    final double spacing = settings.spacingPoints;
    final double headerHeight = settings.showHeader ? 30.0 : 0.0;
    final double totalHeight = frontHeight + backHeight + spacing + headerHeight;

    if (totalHeight > printableHeight && totalHeight > 0) {
      final double scaleFactor = (printableHeight - headerHeight - spacing) / (frontHeight + backHeight);
      targetCardWidth *= scaleFactor;
      frontHeight *= scaleFactor;
      backHeight *= scaleFactor;
    }

    final pwImageFront = frontItem != null ? pw.MemoryImage(frontItem.displayBytes) : null;
    final pwImageBack = backItem != null ? pw.MemoryImage(backItem.displayBytes) : null;

    doc.addPage(
      pw.Page(
        pageFormat: pageFormat,
        margin: pw.EdgeInsets.all(marginPt),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            mainAxisAlignment: pw.MainAxisAlignment.center,
            children: [
              if (settings.showHeader) ...[
                pw.Text(
                  'GOVERNMENT OF INDIA / UIDAI - AADHAAR CARD',
                  style: pw.TextStyle(
                    fontSize: 10,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.blueGrey800,
                  ),
                ),
                pw.SizedBox(height: 12),
              ],

              // 1. Front Card Container (Upper Section)
              if (pwImageFront != null)
                pw.Container(
                  width: targetCardWidth,
                  height: frontHeight,
                  decoration: pw.BoxDecoration(
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                    border: pw.Border.all(color: PdfColors.grey400, width: 0.5),
                  ),
                  child: pw.ClipRRect(
                    horizontalRadius: 6,
                    verticalRadius: 6,
                    child: pw.Image(pwImageFront, fit: pw.BoxFit.contain),
                  ),
                )
              else
                pw.Container(
                  width: targetCardWidth,
                  height: targetCardWidth / (85.6 / 54.0),
                  decoration: pw.BoxDecoration(
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                    border: pw.Border.all(color: PdfColors.grey300, width: 1, style: pw.BorderStyle.dashed),
                  ),
                  alignment: pw.Alignment.center,
                  child: pw.Text(
                    'Front Side Pending Upload',
                    style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey500),
                  ),
                ),

              // 2. Spacing / Cut Line
              pw.SizedBox(height: spacing / 2),
              if (settings.showCutLine)
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.center,
                  children: [
                    pw.Text(
                      '- - - - - - - - - - - - - - - - - - - - - - - [ CUT HERE ] - - - - - - - - - - - - - - - - - - - - - - -',
                      style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey500),
                    ),
                  ],
                )
              else
                pw.SizedBox(height: 1),
              pw.SizedBox(height: spacing / 2),

              // 3. Back Card Container (Lower Section)
              if (pwImageBack != null)
                pw.Container(
                  width: targetCardWidth,
                  height: backHeight,
                  decoration: pw.BoxDecoration(
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                    border: pw.Border.all(color: PdfColors.grey400, width: 0.5),
                  ),
                  child: pw.ClipRRect(
                    horizontalRadius: 6,
                    verticalRadius: 6,
                    child: pw.Image(pwImageBack, fit: pw.BoxFit.contain),
                  ),
                )
              else
                pw.Container(
                  width: targetCardWidth,
                  height: targetCardWidth / (85.6 / 54.0),
                  decoration: pw.BoxDecoration(
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                    border: pw.Border.all(color: PdfColors.grey300, width: 1, style: pw.BorderStyle.dashed),
                  ),
                  alignment: pw.Alignment.center,
                  child: pw.Text(
                    'Back Side Pending Upload',
                    style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey500),
                  ),
                ),
            ],
          );
        },
      ),
    );

    return await doc.save();
  }
}
