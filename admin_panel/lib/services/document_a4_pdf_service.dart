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
}
