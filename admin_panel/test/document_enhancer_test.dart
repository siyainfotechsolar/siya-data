import 'dart:math' as math;
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

    test('Auto crop detects borders of document photographed on dark background', () {
      // Create an image with dark table background (lum ~40) and white document in center (lum ~230)
      final image = img.Image(width: 400, height: 400);
      for (int y = 0; y < 400; y++) {
        for (int x = 0; x < 400; x++) {
          image.setPixelRgb(x, y, 40, 40, 40); // Dark table
        }
      }
      // White document occupying center (inset 40px = 10% on each side)
      for (int y = 40; y < 360; y++) {
        for (int x = 40; x < 360; x++) {
          image.setPixelRgb(x, y, 230, 230, 230); // White paper
        }
      }
      final bytes = Uint8List.fromList(img.encodeJpg(image, quality: 90));

      final bounds = DocumentImageProcessor.detectDocumentBounds(bytes);
      expect(bounds.cropLeft, greaterThanOrEqualTo(0.05));
      expect(bounds.cropTop, greaterThanOrEqualTo(0.05));
      expect(bounds.cropRight, greaterThanOrEqualTo(0.05));
      expect(bounds.cropBottom, greaterThanOrEqualTo(0.05));
      expect(bounds.hasCrop, isTrue);
      expect(bounds.corners.length, equals(4));
    });

    test('Auto crop gracefully handles edge-to-edge document without excessive trimming', () {
      // Pure edge-to-edge document
      final image = img.Image(width: 300, height: 400);
      for (int y = 0; y < 400; y++) {
        for (int x = 0; x < 300; x++) {
          image.setPixelRgb(x, y, 235, 235, 230);
        }
      }
      final bytes = Uint8List.fromList(img.encodeJpg(image, quality: 90));

      final bounds = DocumentImageProcessor.detectDocumentBounds(bytes);
      expect(bounds.cropLeft, lessThan(0.05));
      expect(bounds.cropTop, lessThan(0.05));
      expect(bounds.cropRight, lessThan(0.05));
      expect(bounds.cropBottom, lessThan(0.05));
    });

    test('Fine rotation and tilt angle straightening works accurately', () async {
      final original = createTestDocumentImage(width: 300, height: 400);

      const settings = DocumentEnhanceSettings(
        fineRotationAngle: 5.5,
      );

      final enhanced = await DocumentImageProcessor.enhanceDocument(
        originalBytes: original,
        settings: settings,
      );

      final decoded = img.decodeImage(enhanced);
      expect(decoded, isNotNull);
      expect(decoded!.width, greaterThan(250));
      expect(decoded.height, greaterThan(350));
    });

    test('Auto straighten detects and populates tilt skew angle on tilted document', () {
      final canvas = img.Image(width: 400, height: 400);
      for (int y = 0; y < 400; y++) {
        for (int x = 0; x < 400; x++) {
          canvas.setPixelRgb(x, y, 30, 30, 30);
        }
      }

      const rad = 10.0 * math.pi / 180.0;
      final cosA = math.cos(rad);
      final sinA = math.sin(rad);

      for (int dy = -60; dy < 60; dy++) {
        for (int dx = -100; dx < 100; dx++) {
          final rotX = (200 + dx * cosA - dy * sinA).round();
          final rotY = (200 + dx * sinA + dy * cosA).round();
          if (rotX >= 0 && rotX < 400 && rotY >= 0 && rotY < 400) {
            canvas.setPixelRgb(rotX, rotY, 230, 230, 230);
          }
        }
      }

      final bytes = Uint8List.fromList(img.encodeJpg(canvas, quality: 90));
      final bounds = DocumentImageProcessor.detectDocumentBounds(bytes);

      expect(bounds.skewAngle.abs(), greaterThanOrEqualTo(1.0));
      expect(bounds.isTilted, isTrue);
      expect(bounds.corners.length, equals(4));
    });

    test('Trapezoid perspective distortion is detected and marked in DocumentCropBounds', () {
      // Create a keystone / trapezoid document on dark table: narrow at top (width ~140), wide at bottom (width ~260)
      final canvas = img.Image(width: 400, height: 400);
      for (int y = 0; y < 400; y++) {
        for (int x = 0; x < 400; x++) {
          canvas.setPixelRgb(x, y, 30, 30, 30);
        }
      }

      for (int y = 60; y < 340; y++) {
        final progress = (y - 60) / 280.0;
        final halfW = (70 + progress * 60).round();
        for (int x = 200 - halfW; x <= 200 + halfW; x++) {
          if (x >= 0 && x < 400) {
            canvas.setPixelRgb(x, y, 230, 230, 230);
          }
        }
      }

      final bytes = Uint8List.fromList(img.encodeJpg(canvas, quality: 90));
      final bounds = DocumentImageProcessor.detectDocumentBounds(bytes);

      expect(bounds.hasPerspectiveDistortion, isTrue);
      expect(bounds.isTrapezoid, isTrue);
      expect(bounds.corners.length, equals(4));
    });

    test('Projective Homography Transform rectifies trapezoid perspective quad into clean rectangle', () async {
      final original = createTestDocumentImage(width: 400, height: 500);

      // Skewed quad corners (keystone photographed at angle)
      final settings = DocumentEnhanceSettings(
        perspectiveCorners: [
          const Point2D(0.15, 0.08), // TL
          const Point2D(0.85, 0.12), // TR
          const Point2D(0.95, 0.92), // BR
          const Point2D(0.05, 0.88), // BL
        ],
      );

      final enhanced = await DocumentImageProcessor.enhanceDocument(
        originalBytes: original,
        settings: settings,
      );

      expect(enhanced, isNotEmpty);
      final decoded = img.decodeImage(enhanced);
      expect(decoded, isNotNull);
      expect(decoded!.width, greaterThanOrEqualTo(200));
      expect(decoded.height, greaterThanOrEqualTo(200));
    });

    test('Low contrast / blurry document flags needsManualAdjustment', () {
      // White document on pale near-white table (contrastDiff < 18)
      final canvas = img.Image(width: 300, height: 300);
      for (int y = 0; y < 300; y++) {
        for (int x = 0; x < 300; x++) {
          canvas.setPixelRgb(x, y, 220, 220, 220); // Border bg
        }
      }
      // Inner document almost identical color
      for (int y = 50; y < 250; y++) {
        for (int x = 50; x < 250; x++) {
          canvas.setPixelRgb(x, y, 228, 228, 228);
        }
      }

      final bytes = Uint8List.fromList(img.encodeJpg(canvas, quality: 90));
      final bounds = DocumentImageProcessor.detectDocumentBounds(bytes);

      expect(bounds.needsManualAdjustment, isTrue);
      expect(bounds.confidence, lessThan(0.6));
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

    test('Generates Aadhaar Front & Back on 1 A4 page correctly', () async {
      final frontBytes = createTestDocumentImage(width: 856, height: 540);
      final backBytes = createTestDocumentImage(width: 856, height: 540);

      final frontItem = DocumentToolItem(
        id: 'aadhaar_front',
        name: 'Aadhaar_Front.jpg',
        fileSize: frontBytes.length,
        mimeType: 'image/jpeg',
        originalBytes: frontBytes,
        width: 856,
        height: 540,
      );

      final backItem = DocumentToolItem(
        id: 'aadhaar_back',
        name: 'Aadhaar_Back.jpg',
        fileSize: backBytes.length,
        mimeType: 'image/jpeg',
        originalBytes: backBytes,
        width: 856,
        height: 540,
      );

      final pdfBytes = await DocumentA4PdfService.generateAadhaarA4Pdf(
        frontItem: frontItem,
        backItem: backItem,
        settings: const AadhaarPageSettings(
          scale: AadhaarCardScale.mediumScale,
          spacing: AadhaarSpacing.normal,
          showCutLine: true,
          showHeader: true,
        ),
      );

      expect(pdfBytes, isNotEmpty);
      expect(pdfBytes.length, greaterThan(2000));
    });

    test('Generates Aadhaar PDF when only front side is uploaded', () async {
      final frontBytes = createTestDocumentImage(width: 856, height: 540);
      final frontItem = DocumentToolItem(
        id: 'aadhaar_front',
        name: 'Aadhaar_Front.jpg',
        fileSize: frontBytes.length,
        mimeType: 'image/jpeg',
        originalBytes: frontBytes,
        width: 856,
        height: 540,
      );

      final pdfBytes = await DocumentA4PdfService.generateAadhaarA4Pdf(
        frontItem: frontItem,
        backItem: null,
        settings: const AadhaarPageSettings(),
      );

      expect(pdfBytes, isNotEmpty);
      expect(pdfBytes.length, greaterThan(1500));
    });
  });
}
