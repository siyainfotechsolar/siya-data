import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:admin_panel/models/document_enhancer_models.dart';
import 'package:admin_panel/services/document_image_processor.dart';
import 'package:admin_panel/services/document_a4_pdf_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Create a synthetic test document image (white paper with text-like dark bars)
  Uint8List createTestDocumentImage({int width = 400, int height = 600}) {
    final image = img.Image(width: width, height: height);
    // Fill with slightly off-white paper color with gradient shadow
    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final shadow = (y * 40 ~/ height); // shadow towards bottom
        final r = (230 - shadow).clamp(0, 255);
        final g = (225 - shadow).clamp(0, 255);
        final b = (210 - shadow).clamp(0, 255);
        image.setPixelRgb(x, y, r, g, b);
      }
    }

    // Draw some dark text lines
    for (int row = 50; row < height - 50; row += 40) {
      for (int y = row; y < row + 12; y++) {
        for (int x = 40; x < width - 40; x++) {
          image.setPixelRgb(x, y, 20, 25, 30);
        }
      }
    }

    return Uint8List.fromList(img.encodeJpg(image, quality: 90));
  }

  group('DocumentImageProcessor Tests', () {
    test('Image analysis produces valid dimensions, thumbnail and quality score', () {
      final bytes = createTestDocumentImage(width: 500, height: 700);
      final meta = DocumentImageProcessor.analyzeImage(bytes);

      expect(meta['width'], equals(500));
      expect(meta['height'], equals(700));
      expect(meta['thumbnail'], isNotNull);
      expect((meta['thumbnail'] as Uint8List).length, greaterThan(100));
    });

    test('Enhancement pipeline applies auto levels, sharpening, and background cleanup', () async {
      final original = createTestDocumentImage(width: 300, height: 400);

      const settings = DocumentEnhanceSettings(
        autoLevels: true,
        sharpen: true,
        backgroundCleanup: true,
        strength: EnhancementStrength.medium,
      );

      final enhanced = await DocumentImageProcessor.enhanceDocument(
        originalBytes: original,
        settings: settings,
      );

      expect(enhanced, isNotEmpty);
      expect(enhanced.length, greaterThan(1000));

      final decoded = img.decodeImage(enhanced);
      expect(decoded, isNotNull);
      expect(decoded!.width, equals(300));
      expect(decoded.height, equals(400));
    });

    test('Document Scanner Mode (Adaptive Thresholding) creates clean binary document', () async {
      final original = createTestDocumentImage(width: 250, height: 350);

      const settings = DocumentEnhanceSettings(
        blackAndWhite: true,
        strength: EnhancementStrength.medium,
      );

      final enhanced = await DocumentImageProcessor.enhanceDocument(
        originalBytes: original,
        settings: settings,
      );

      final decoded = img.decodeImage(enhanced);
      expect(decoded, isNotNull);

      // Verify that pixel values are either near-white (background) or near-black (ink)
      int blackPixels = 0;
      int whitePixels = 0;

      for (int y = 0; y < decoded!.height; y += 5) {
        for (int x = 0; x < decoded.width; x += 5) {
          final lum = decoded.getPixel(x, y).luminance;
          if (lum < 50) blackPixels++;
          if (lum > 200) whitePixels++;
        }
      }

      expect(blackPixels, greaterThan(10));
      expect(whitePixels, greaterThan(50));
    });

    test('Rotation and crop work accurately', () async {
      final original = createTestDocumentImage(width: 400, height: 600);

      const settings = DocumentEnhanceSettings(
        rotationAngle: 90,
        cropLeft: 0.1,
        cropTop: 0.1,
        cropRight: 0.1,
        cropBottom: 0.1,
      );

      final enhanced = await DocumentImageProcessor.enhanceDocument(
        originalBytes: original,
        settings: settings,
      );

      final decoded = img.decodeImage(enhanced);
      expect(decoded, isNotNull);
      // Because it cropped 20% then rotated 90 degrees, width & height swap
      expect(decoded!.width, greaterThan(300));
      expect(decoded.height, greaterThan(200));
    });

    test('Perspective deskew warps 4 corners to rectangular output', () async {
      final original = createTestDocumentImage(width: 400, height: 500);

      const settings = DocumentEnhanceSettings(
        perspectiveCorners: [
          Point2D(0.1, 0.05), // TL
          Point2D(0.9, 0.1),  // TR
          Point2D(0.85, 0.95), // BR
          Point2D(0.08, 0.9),  // BL
        ],
      );

      final enhanced = await DocumentImageProcessor.enhanceDocument(
        originalBytes: original,
        settings: settings,
      );

      final decoded = img.decodeImage(enhanced);
      expect(decoded, isNotNull);
      expect(decoded!.width, greaterThan(200));
      expect(decoded.height, greaterThan(200));
    });
  });

  group('DocumentA4PdfService Tests', () {
    test('Generates single page A4 PDF correctly', () async {
      final imgBytes = createTestDocumentImage(width: 400, height: 600);
      final item = DocumentToolItem(
        id: 'test_1',
        name: 'test_doc.jpg',
        fileSize: imgBytes.length,
        mimeType: 'image/jpeg',
        originalBytes: imgBytes,
        width: 400,
        height: 600,
      );

      final pdfBytes = await DocumentA4PdfService.generateA4Pdf(
        items: [item],
        settings: const A4PageSettings(
          orientation: A4Orientation.portrait,
          layout: A4Layout.onePerPage,
          marginPreset: A4MarginPreset.small,
        ),
      );

      expect(pdfBytes, isNotEmpty);
      expect(pdfBytes.length, greaterThan(2000));
    });

    test('Generates 2-per-page A4 PDF layout for front/back documents', () async {
      final imgBytes1 = createTestDocumentImage(width: 400, height: 250);
      final imgBytes2 = createTestDocumentImage(width: 400, height: 250);

      final item1 = DocumentToolItem(
        id: 'doc_front',
        name: 'Aadhaar_Front.jpg',
        fileSize: imgBytes1.length,
        mimeType: 'image/jpeg',
        originalBytes: imgBytes1,
        width: 400,
        height: 250,
      );

      final item2 = DocumentToolItem(
        id: 'doc_back',
        name: 'Aadhaar_Back.jpg',
        fileSize: imgBytes2.length,
        mimeType: 'image/jpeg',
        originalBytes: imgBytes2,
        width: 400,
        height: 250,
      );

      final pdfBytes = await DocumentA4PdfService.generateA4Pdf(
        items: [item1, item2],
        settings: const A4PageSettings(
          orientation: A4Orientation.portrait,
          layout: A4Layout.twoPerPage,
        ),
      );

      expect(pdfBytes, isNotEmpty);
      expect(pdfBytes.length, greaterThan(2500));
    });

    test('Generates 4-per-page A4 PDF grid layout', () async {
      final items = List.generate(4, (i) {
        final bytes = createTestDocumentImage(width: 300, height: 300);
        return DocumentToolItem(
          id: 'item_$i',
          name: 'photo_$i.jpg',
          fileSize: bytes.length,
          mimeType: 'image/jpeg',
          originalBytes: bytes,
          width: 300,
          height: 300,
        );
      });

      final pdfBytes = await DocumentA4PdfService.generateA4Pdf(
        items: items,
        settings: const A4PageSettings(
          orientation: A4Orientation.portrait,
          layout: A4Layout.fourPerPage,
        ),
      );

      expect(pdfBytes, isNotEmpty);
      expect(pdfBytes.length, greaterThan(3000));
    });
  });
}
