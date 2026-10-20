import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import '../models/document_enhancer_models.dart';

/// Genuine, high-quality pure-Dart image processing engine
/// Optimized for documents and photographs captured via WhatsApp / mobile cameras.
class DocumentImageProcessor {
  /// Analyzes an image and returns initial metadata (dimensions, thumbnail, quality check)
  static Map<String, dynamic> analyzeImage(Uint8List bytes) {
    final image = img.decodeImage(bytes);
    if (image == null) {
      throw Exception('Unable to decode image. Unsupported format or corrupted file.');
    }

    final width = image.width;
    final height = image.height;

    // Generate fast thumbnail (max 300px)
    final thumb = _generateThumbnail(image, maxDimension: 300);
    final thumbBytes = Uint8List.fromList(img.encodeJpg(thumb, quality: 80));

    // Blur / Quality warning check
    String? warning;
    if (width * height < 400000) {
      warning = 'Low resolution image (${width}x$height). Printed text may appear soft.';
    } else {
      final blurScore = computeBlurScore(image);
      if (blurScore < 50.0) {
        warning = 'Document photograph appears out of focus or blurry. Check preview carefully.';
      }
    }

    return {
      'width': width,
      'height': height,
      'thumbnail': thumbBytes,
      'warning': warning,
    };
  }

  /// Generates a thumbnail for quick gallery rendering
  static img.Image _generateThumbnail(img.Image src, {int maxDimension = 300}) {
    if (src.width <= maxDimension && src.height <= maxDimension) {
      return src;
    }
    if (src.width > src.height) {
      final h = (src.height * maxDimension / src.width).round();
      return img.copyResize(src, width: maxDimension, height: h);
    } else {
      final w = (src.width * maxDimension / src.height).round();
      return img.copyResize(src, width: w, height: maxDimension);
    }
  }

  /// Computes variance of Laplacian on luminance to assess blurriness
  static double computeBlurScore(img.Image src) {
    // Sample a central 300x300 patch for performance
    final sampleSize = math.min(src.width, math.min(src.height, 300));
    final startX = (src.width - sampleSize) ~/ 2;
    final startY = (src.height - sampleSize) ~/ 2;

    double sum = 0.0;
    double sumSq = 0.0;
    int count = 0;

    // Laplacian kernel: [0, 1, 0], [1, -4, 1], [0, 1, 0]
    for (int y = startY + 1; y < startY + sampleSize - 1; y += 2) {
      for (int x = startX + 1; x < startX + sampleSize - 1; x += 2) {
        final c = src.getPixel(x, y).luminance;
        final t = src.getPixel(x, y - 1).luminance;
        final b = src.getPixel(x, y + 1).luminance;
        final l = src.getPixel(x - 1, y).luminance;
        final r = src.getPixel(x + 1, y).luminance;

        final lap = t + b + l + r - (4 * c);
        sum += lap;
        sumSq += lap * lap;
        count++;
      }
    }

    if (count == 0) return 100.0;
    final mean = sum / count;
    final variance = (sumSq / count) - (mean * mean);
    return variance;
  }

  /// Automatically detects document boundary corners (Deskew / Perspective detection)
  static List<Point2D> detectDocumentCorners(Uint8List bytes) {
    final src = img.decodeImage(bytes);
    if (src == null) {
      return const [
        Point2D(0.05, 0.05),
        Point2D(0.95, 0.05),
        Point2D(0.95, 0.95),
        Point2D(0.05, 0.95),
      ];
    }

    // Downsample for fast edge gradient scanning
    const targetW = 200;
    final targetH = (src.height * targetW / src.width).round();
    final small = img.copyResize(src, width: targetW, height: targetH);
    final gray = img.grayscale(small);

    // Look for paper edge transitions from outside borders inwards
    int tlX = 5, tlY = 5;
    int trX = targetW - 6, trY = 5;
    int brX = targetW - 6, brY = targetH - 6;
    int blX = 5, blY = targetH - 6;

    // Scan top-left
    outerTL:
    for (int d = 2; d < targetW ~/ 4; d++) {
      for (int x = d; x < d + 3; x++) {
        final lum = gray.getPixel(x, d).luminance;
        if (lum > 110) {
          tlX = x;
          tlY = d;
          break outerTL;
        }
      }
    }

    // Scan top-right
    outerTR:
    for (int d = 2; d < targetW ~/ 4; d++) {
      for (int x = targetW - 1 - d; x > targetW - 4 - d; x--) {
        final lum = gray.getPixel(x, d).luminance;
        if (lum > 110) {
          trX = x;
          trY = d;
          break outerTR;
        }
      }
    }

    // Scan bottom-right
    outerBR:
    for (int d = 2; d < targetW ~/ 4; d++) {
      for (int x = targetW - 1 - d; x > targetW - 4 - d; x--) {
        final lum = gray.getPixel(x, targetH - 1 - d).luminance;
        if (lum > 110) {
          brX = x;
          brY = targetH - 1 - d;
          break outerBR;
        }
      }
    }

    // Scan bottom-left
    outerBL:
    for (int d = 2; d < targetW ~/ 4; d++) {
      for (int x = d; x < d + 3; x++) {
        final lum = gray.getPixel(x, targetH - 1 - d).luminance;
        if (lum > 110) {
          blX = x;
          blY = targetH - 1 - d;
          break outerBL;
        }
      }
    }

    return [
      Point2D(tlX / targetW, tlY / targetH),
      Point2D(trX / targetW, trY / targetH),
      Point2D(brX / targetW, brY / targetH),
      Point2D(blX / targetW, blY / targetH),
    ];
  }

  /// Main enhancement pipeline
  static Future<Uint8List> enhanceDocument({
    required Uint8List originalBytes,
    required DocumentEnhanceSettings settings,
  }) async {
    // Run CPU-intensive image processing without blocking
    return compute(_runProcessingPipeline, {
      'bytes': originalBytes,
      'settings': settings,
    });
  }

  /// Internal processing pipeline
  static Uint8List _runProcessingPipeline(Map<String, dynamic> params) {
    final Uint8List bytes = params['bytes'];
    final DocumentEnhanceSettings settings = params['settings'];

    img.Image? current = img.decodeImage(bytes);
    if (current == null) {
      throw Exception('Failed to decode image data.');
    }

    // 1. Rotation (0, 90, 180, 270)
    if (settings.rotationAngle != 0) {
      current = img.copyRotate(current, angle: settings.rotationAngle);
    }

    // 2. Perspective Transform / Deskew (if corners specified)
    if (settings.perspectiveCorners != null && settings.perspectiveCorners!.length == 4) {
      current = _applyPerspectiveWarp(current, settings.perspectiveCorners!);
    }

    // 3. Crop margins (if non-zero)
    if (settings.cropLeft > 0 || settings.cropTop > 0 || settings.cropRight > 0 || settings.cropBottom > 0) {
      final cropX = (current.width * settings.cropLeft).round().clamp(0, current.width - 10);
      final cropY = (current.height * settings.cropTop).round().clamp(0, current.height - 10);
      final cropW = (current.width * (1.0 - settings.cropLeft - settings.cropRight)).round().clamp(10, current.width - cropX);
      final cropH = (current.height * (1.0 - settings.cropTop - settings.cropBottom)).round().clamp(10, current.height - cropY);
      current = img.copyCrop(current, x: cropX, y: cropY, width: cropW, height: cropH);
    }

    // 4. Background Illumination Cleanup (Removes camera shadows & uneven gradients)
    if (settings.backgroundCleanup) {
      current = _flattenBackgroundIllumination(current, settings.strength);
    }

    // 5. Auto Levels / Histogram Stretch
    if (settings.autoLevels) {
      current = _applyAutoLevels(current);
    }

    // 6. Manual Brightness & Contrast adjustment
    if (settings.brightness != 0.0 || settings.contrast != 1.0) {
      current = img.adjustColor(current, brightness: 1.0 + settings.brightness, contrast: settings.contrast);
    }

    // 7. Denoise (soft median/box filter)
    if (settings.denoise) {
      current = _applyDenoise(current);
    }

    // 8. Sharpen (unsharp mask to bring out text strokes & edges)
    if (settings.sharpen) {
      current = _applySharpen(current, settings.strength);
    }

    // 9. Black & White Document Scanner Mode (Adaptive Thresholding) or Grayscale
    if (settings.blackAndWhite) {
      current = _applyAdaptiveDocumentThreshold(current, settings.strength);
    } else if (settings.grayscale) {
      current = img.grayscale(current);
    }

    // Encode to high-quality JPEG
    return Uint8List.fromList(img.encodeJpg(current, quality: 92));
  }

  /// Auto Levels / Contrast stretching based on 1st & 99th luminance percentiles
  static img.Image _applyAutoLevels(img.Image src) {
    final hist = List<int>.filled(256, 0);
    int total = 0;

    for (final pixel in src) {
      final lum = pixel.luminance.round().clamp(0, 255);
      hist[lum]++;
      total++;
    }

    if (total == 0) return src;

    // Find 1st and 99th percentile
    final lowTarget = (total * 0.015).round();
    final highTarget = (total * 0.985).round();

    int cumulative = 0;
    int minL = 0;
    int maxL = 255;

    for (int i = 0; i < 256; i++) {
      cumulative += hist[i];
      if (cumulative >= lowTarget && minL == 0) {
        minL = i;
      }
      if (cumulative >= highTarget) {
        maxL = i;
        break;
      }
    }

    if (maxL <= minL) return src;

    final range = maxL - minL;
    final lookup = List<int>.filled(256, 0);
    for (int i = 0; i < 256; i++) {
      lookup[i] = (((i - minL) / range) * 255.0).round().clamp(0, 255);
    }

    final out = img.Image.from(src);
    for (int y = 0; y < out.height; y++) {
      for (int x = 0; x < out.width; x++) {
        final p = out.getPixel(x, y);
        final r = lookup[p.r.round().clamp(0, 255)];
        final g = lookup[p.g.round().clamp(0, 255)];
        final b = lookup[p.b.round().clamp(0, 255)];
        out.setPixelRgb(x, y, r, g, b);
      }
    }

    return out;
  }

  /// Removes camera phone shadows and uneven yellow lighting by estimating background surface
  static img.Image _flattenBackgroundIllumination(img.Image src, EnhancementStrength strength) {
    final w = src.width;
    final h = src.height;

    // Downsample to estimate illumination map (blocks of ~24px)
    final blockW = math.max(16, w ~/ 24);
    final blockH = math.max(16, h ~/ 24);

    final bgSmall = img.copyResize(src, width: blockW, height: blockH);
    // Gaussian blur the illumination estimate to make transition perfectly smooth
    final bgBlurred = img.gaussianBlur(bgSmall, radius: 4);
    final bgFull = img.copyResize(bgBlurred, width: w, height: h);

    final out = img.Image.from(src);

    // Target paper brightness constant
    final double targetPaper = strength == EnhancementStrength.high ? 245.0 : 235.0;

    for (int y = 0; y < h; y++) {
      for (int x = 0; x < w; x++) {
        final p = out.getPixel(x, y);
        final bg = bgFull.getPixel(x, y);

        final bgLum = math.max(15.0, bg.luminance.toDouble());

        final r = ((p.r / bgLum) * targetPaper).round().clamp(0, 255);
        final g = ((p.g / bgLum) * targetPaper).round().clamp(0, 255);
        final b = ((p.b / bgLum) * targetPaper).round().clamp(0, 255);

        out.setPixelRgb(x, y, r, g, b);
      }
    }

    return out;
  }

  /// Document Scanner Mode: High performance adaptive thresholding (Sauvola/Bradley-Roth)
  /// Converts uneven, shadow-cast photos into crisp black text on pure white paper
  /// Preserves signatures, stamps, and handwritten annotations accurately
  static img.Image _applyAdaptiveDocumentThreshold(img.Image src, EnhancementStrength strength) {
    final w = src.width;
    final h = src.height;

    // Convert to grayscale first
    final gray = img.grayscale(src);

    // Build 2D Integral Image for fast O(1) local mean computation
    final integral = List<int>.filled((w + 1) * (h + 1), 0);

    for (int y = 0; y < h; y++) {
      int rowSum = 0;
      final int rowOffset = (y + 1) * (w + 1);
      final int prevRowOffset = y * (w + 1);

      for (int x = 0; x < w; x++) {
        final lum = gray.getPixel(x, y).r.toInt();
        rowSum += lum;
        integral[rowOffset + (x + 1)] = integral[prevRowOffset + (x + 1)] + rowSum;
      }
    }

    // Adaptive window radius based on document dimensions (~w / 28)
    final radius = math.max(12, w ~/ 28);

    // Sensitivity factor T
    final double t = switch (strength) {
      EnhancementStrength.low => 0.08,
      EnhancementStrength.medium => 0.13,
      EnhancementStrength.high => 0.18,
    };

    final out = img.Image(width: w, height: h);

    for (int y = 0; y < h; y++) {
      final y1 = math.max(0, y - radius);
      final y2 = math.min(h - 1, y + radius);

      for (int x = 0; x < w; x++) {
        final x1 = math.max(0, x - radius);
        final x2 = math.min(w - 1, x + radius);

        final count = (x2 - x1 + 1) * (y2 - y1 + 1);

        // Sum from integral image: D - B - C + A
        final sum = integral[(y2 + 1) * (w + 1) + (x2 + 1)] -
            integral[y1 * (w + 1) + (x2 + 1)] -
            integral[(y2 + 1) * (w + 1) + x1] +
            integral[y1 * (w + 1) + x1];

        final mean = sum / count;
        final pixelLum = gray.getPixel(x, y).r.toDouble();

        // Thresholding rule: pixel is black if darker than (mean * (1 - t))
        if (pixelLum <= mean * (1.0 - t)) {
          out.setPixelRgb(x, y, 0, 0, 0); // Text / ink
        } else {
          out.setPixelRgb(x, y, 255, 255, 255); // Paper background
        }
      }
    }

    return out;
  }

  /// Sharpen filter using unsharp masking to enhance document clarity
  static img.Image _applySharpen(img.Image src, EnhancementStrength strength) {
    final double amount = switch (strength) {
      EnhancementStrength.low => 0.35,
      EnhancementStrength.medium => 0.60,
      EnhancementStrength.high => 0.90,
    };

    // Soft blurred version
    final blurred = img.gaussianBlur(src, radius: 1);
    final out = img.Image.from(src);

    for (int y = 0; y < src.height; y++) {
      for (int x = 0; x < src.width; x++) {
        final orig = src.getPixel(x, y);
        final blur = blurred.getPixel(x, y);

        final r = (orig.r + (orig.r - blur.r) * amount).round().clamp(0, 255);
        final g = (orig.g + (orig.g - blur.g) * amount).round().clamp(0, 255);
        final b = (orig.b + (orig.b - blur.b) * amount).round().clamp(0, 255);

        out.setPixelRgb(x, y, r, g, b);
      }
    }

    return out;
  }

  /// Denoising filter to remove camera noise
  static img.Image _applyDenoise(img.Image src) {
    return img.gaussianBlur(src, radius: 1);
  }

  /// Perspective Warp: Maps 4 quadrilateral corner points to a rectified rectangle
  static img.Image _applyPerspectiveWarp(img.Image src, List<Point2D> corners) {
    final p0 = corners[0]; // TL
    final p1 = corners[1]; // TR
    final p2 = corners[2]; // BR
    final p3 = corners[3]; // BL

    final x0 = p0.x * src.width;
    final y0 = p0.y * src.height;
    final x1 = p1.x * src.width;
    final y1 = p1.y * src.height;
    final x2 = p2.x * src.width;
    final y2 = p2.y * src.height;
    final x3 = p3.x * src.width;
    final y3 = p3.y * src.height;

    // Estimate output rectangle dimensions
    final topWidth = math.sqrt(math.pow(x1 - x0, 2) + math.pow(y1 - y0, 2));
    final bottomWidth = math.sqrt(math.pow(x2 - x3, 2) + math.pow(y2 - y3, 2));
    final leftHeight = math.sqrt(math.pow(x3 - x0, 2) + math.pow(y3 - y0, 2));
    final rightHeight = math.sqrt(math.pow(x2 - x1, 2) + math.pow(y2 - y1, 2));

    final outW = math.max(100, math.max(topWidth, bottomWidth).round());
    final outH = math.max(100, math.max(leftHeight, rightHeight).round());

    final out = img.Image(width: outW, height: outH);

    // Bilinear interpolation warp
    for (int y = 0; y < outH; y++) {
      final v = y / outH;
      for (int x = 0; x < outW; x++) {
        final u = x / outW;

        // Bilinear interpolation between the 4 corners:
        // P(u,v) = (1-u)(1-v)*P0 + u(1-v)*P1 + u*v*P2 + (1-u)*v*P3
        final srcX = ((1.0 - u) * (1.0 - v) * x0 +
                u * (1.0 - v) * x1 +
                u * v * x2 +
                (1.0 - u) * v * x3)
            .round()
            .clamp(0, src.width - 1);

        final srcY = ((1.0 - u) * (1.0 - v) * y0 +
                u * (1.0 - v) * y1 +
                u * v * y2 +
                (1.0 - u) * v * y3)
            .round()
            .clamp(0, src.height - 1);

        final p = src.getPixel(srcX, srcY);
        out.setPixelRgb(x, y, p.r.toInt(), p.g.toInt(), p.b.toInt());
      }
    }

    return out;
  }
}
