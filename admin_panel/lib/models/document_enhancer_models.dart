import 'dart:typed_data';

/// Point representation for perspective quad corners (normalized 0.0 to 1.0)
class Point2D {
  final double x;
  final double y;

  const Point2D(this.x, this.y);

  Map<String, dynamic> toJson() => {'x': x, 'y': y};
  factory Point2D.fromJson(Map<String, dynamic> json) =>
      Point2D((json['x'] as num).toDouble(), (json['y'] as num).toDouble());

  Point2D copyWith({double? x, double? y}) =>
      Point2D(x ?? this.x, y ?? this.y);

  @override
  String toString() => 'Point2D(${x.toStringAsFixed(3)}, ${y.toStringAsFixed(3)})';
}

/// Result of automated document boundary detection
class DocumentCropBounds {
  final double cropLeft; // 0.0 to 0.45
  final double cropTop; // 0.0 to 0.45
  final double cropRight; // 0.0 to 0.45
  final double cropBottom; // 0.0 to 0.45
  final List<Point2D> corners; // 4 corners: TL, TR, BR, BL
  final double confidence; // 0.0 to 1.0
  final double skewAngle; // Detected tilt/skew angle in degrees (-45.0 to 45.0)

  const DocumentCropBounds({
    this.cropLeft = 0.0,
    this.cropTop = 0.0,
    this.cropRight = 0.0,
    this.cropBottom = 0.0,
    this.corners = const [
      Point2D(0.0, 0.0),
      Point2D(1.0, 0.0),
      Point2D(1.0, 1.0),
      Point2D(0.0, 1.0),
    ],
    this.confidence = 1.0,
    this.skewAngle = 0.0,
  });

  bool get hasCrop => cropLeft > 0 || cropTop > 0 || cropRight > 0 || cropBottom > 0;
  bool get isTilted => skewAngle.abs() >= 0.75;
}

/// Enhancement presets / strength levels
enum EnhancementStrength {
  low,
  medium,
  high,
}

/// Image enhancement settings applied to an individual document or image
class DocumentEnhanceSettings {
  final bool autoLevels;
  final double brightness; // -1.0 to 1.0, 0.0 is normal
  final double contrast; // 0.5 to 2.5, 1.0 is normal
  final bool denoise;
  final bool sharpen;
  final bool grayscale;
  final bool blackAndWhite; // Document scanner adaptive thresholding
  final bool backgroundCleanup; // Illumination flattening / shadow removal
  final EnhancementStrength strength;
  final int rotationAngle; // 0, 90, 180, 270
  final double fineRotationAngle; // -45.0 to +45.0 degrees for straightening tilted/crooked documents
  final double cropLeft; // 0.0 to 0.45
  final double cropTop; // 0.0 to 0.45
  final double cropRight; // 0.0 to 0.45
  final double cropBottom; // 0.0 to 0.45
  final List<Point2D>? perspectiveCorners; // 4 corners: TL, TR, BR, BL

  const DocumentEnhanceSettings({
    this.autoLevels = false,
    this.brightness = 0.0,
    this.contrast = 1.0,
    this.denoise = false,
    this.sharpen = false,
    this.grayscale = false,
    this.blackAndWhite = false,
    this.backgroundCleanup = false,
    this.strength = EnhancementStrength.medium,
    this.rotationAngle = 0,
    this.fineRotationAngle = 0.0,
    this.cropLeft = 0.0,
    this.cropTop = 0.0,
    this.cropRight = 0.0,
    this.cropBottom = 0.0,
    this.perspectiveCorners,
  });

  bool get hasAnyEnhancement =>
      autoLevels ||
      brightness != 0.0 ||
      contrast != 1.0 ||
      denoise ||
      sharpen ||
      grayscale ||
      blackAndWhite ||
      backgroundCleanup ||
      rotationAngle != 0 ||
      fineRotationAngle != 0.0 ||
      cropLeft > 0 ||
      cropTop > 0 ||
      cropRight > 0 ||
      cropBottom > 0 ||
      (perspectiveCorners != null && perspectiveCorners!.isNotEmpty);

  DocumentEnhanceSettings copyWith({
    bool? autoLevels,
    double? brightness,
    double? contrast,
    bool? denoise,
    bool? sharpen,
    bool? grayscale,
    bool? blackAndWhite,
    bool? backgroundCleanup,
    EnhancementStrength? strength,
    int? rotationAngle,
    double? fineRotationAngle,
    double? cropLeft,
    double? cropTop,
    double? cropRight,
    double? cropBottom,
    List<Point2D>? perspectiveCorners,
  }) {
    return DocumentEnhanceSettings(
      autoLevels: autoLevels ?? this.autoLevels,
      brightness: brightness ?? this.brightness,
      contrast: contrast ?? this.contrast,
      denoise: denoise ?? this.denoise,
      sharpen: sharpen ?? this.sharpen,
      grayscale: grayscale ?? this.grayscale,
      blackAndWhite: blackAndWhite ?? this.blackAndWhite,
      backgroundCleanup: backgroundCleanup ?? this.backgroundCleanup,
      strength: strength ?? this.strength,
      rotationAngle: rotationAngle ?? this.rotationAngle,
      fineRotationAngle: fineRotationAngle ?? this.fineRotationAngle,
      cropLeft: cropLeft ?? this.cropLeft,
      cropTop: cropTop ?? this.cropTop,
      cropRight: cropRight ?? this.cropRight,
      cropBottom: cropBottom ?? this.cropBottom,
      perspectiveCorners: perspectiveCorners ?? this.perspectiveCorners,
    );
  }

  static DocumentEnhanceSettings presetLow() => const DocumentEnhanceSettings(
        autoLevels: true,
        sharpen: true,
        backgroundCleanup: true,
        strength: EnhancementStrength.low,
      );

  static DocumentEnhanceSettings presetMedium() => const DocumentEnhanceSettings(
        autoLevels: true,
        sharpen: true,
        denoise: true,
        backgroundCleanup: true,
        strength: EnhancementStrength.medium,
      );

  static DocumentEnhanceSettings presetHigh() => const DocumentEnhanceSettings(
        autoLevels: true,
        sharpen: true,
        denoise: true,
        backgroundCleanup: true,
        blackAndWhite: true,
        strength: EnhancementStrength.high,
      );
}

/// A4 Page Formatting Settings
enum A4Orientation { auto, portrait, landscape }
enum A4Layout { onePerPage, twoPerPage, fourPerPage }
enum A4FitMode { fit, fill, actual }
enum A4MarginPreset { none, small, normal, custom }
enum A4ColorMode { color, grayscale, blackAndWhite }
enum A4Alignment { center, top }

class A4PageSettings {
  final A4Orientation orientation;
  final A4Layout layout;
  final A4FitMode fitMode;
  final A4MarginPreset marginPreset;
  final double customMarginMm;
  final A4Alignment alignment;
  final A4ColorMode colorMode;

  const A4PageSettings({
    this.orientation = A4Orientation.auto,
    this.layout = A4Layout.onePerPage,
    this.fitMode = A4FitMode.fit,
    this.marginPreset = A4MarginPreset.small,
    this.customMarginMm = 5.0,
    this.alignment = A4Alignment.center,
    this.colorMode = A4ColorMode.color,
  });

  double get marginPoints {
    switch (marginPreset) {
      case A4MarginPreset.none:
        return 0.0;
      case A4MarginPreset.small:
        return 14.17; // 5 mm in points (72 / 25.4 * 5)
      case A4MarginPreset.normal:
        return 28.35; // 10 mm in points (72 / 25.4 * 10)
      case A4MarginPreset.custom:
        return (customMarginMm * 72.0) / 25.4;
    }
  }

  A4PageSettings copyWith({
    A4Orientation? orientation,
    A4Layout? layout,
    A4FitMode? fitMode,
    A4MarginPreset? marginPreset,
    double? customMarginMm,
    A4Alignment? alignment,
    A4ColorMode? colorMode,
  }) {
    return A4PageSettings(
      orientation: orientation ?? this.orientation,
      layout: layout ?? this.layout,
      fitMode: fitMode ?? this.fitMode,
      marginPreset: marginPreset ?? this.marginPreset,
      customMarginMm: customMarginMm ?? this.customMarginMm,
      alignment: alignment ?? this.alignment,
      colorMode: colorMode ?? this.colorMode,
    );
  }
}

/// Active Mode of the Document Clear & A4 Print Tool
enum DocumentMode {
  general,
  aadhaarFrontBack,
}

/// Sizing scale for Aadhaar Card on A4 Sheet
enum AadhaarCardScale {
  actualIdSize, // 85.6 mm × 54 mm (~242 × 153 pt) — Real pocket card size
  mediumScale, // ~115 mm width (~326 pt) — Recommended balanced readability
  largeScale, // ~140 mm width (~397 pt) — Large clear print
  fitWidth, // Full width within margins (~90% printable width)
}

/// Vertical spacing between Front and Back Aadhaar cards
enum AadhaarSpacing {
  compact, // 10 mm
  normal, // 20 mm
  spacious, // 35 mm
}

/// Dedicated A4 Layout Settings for Aadhaar Card Front & Back Mode
class AadhaarPageSettings {
  final AadhaarCardScale scale;
  final AadhaarSpacing spacing;
  final double customSpacingMm;
  final A4MarginPreset marginPreset;
  final bool showCutLine;
  final bool showHeader;
  final A4ColorMode colorMode;

  const AadhaarPageSettings({
    this.scale = AadhaarCardScale.mediumScale,
    this.spacing = AadhaarSpacing.normal,
    this.customSpacingMm = 20.0,
    this.marginPreset = A4MarginPreset.small,
    this.showCutLine = true,
    this.showHeader = false,
    this.colorMode = A4ColorMode.color,
  });

  double get spacingPoints {
    switch (spacing) {
      case AadhaarSpacing.compact:
        return 28.35; // 10 mm
      case AadhaarSpacing.normal:
        return 56.70; // 20 mm
      case AadhaarSpacing.spacious:
        return 99.21; // 35 mm
    }
  }

  double get marginPoints {
    switch (marginPreset) {
      case A4MarginPreset.none:
        return 0.0;
      case A4MarginPreset.small:
        return 14.17; // 5 mm
      case A4MarginPreset.normal:
        return 28.35; // 10 mm
      case A4MarginPreset.custom:
        return 42.52; // 15 mm
    }
  }

  AadhaarPageSettings copyWith({
    AadhaarCardScale? scale,
    AadhaarSpacing? spacing,
    double? customSpacingMm,
    A4MarginPreset? marginPreset,
    bool? showCutLine,
    bool? showHeader,
    A4ColorMode? colorMode,
  }) {
    return AadhaarPageSettings(
      scale: scale ?? this.scale,
      spacing: spacing ?? this.spacing,
      customSpacingMm: customSpacingMm ?? this.customSpacingMm,
      marginPreset: marginPreset ?? this.marginPreset,
      showCutLine: showCutLine ?? this.showCutLine,
      showHeader: showHeader ?? this.showHeader,
      colorMode: colorMode ?? this.colorMode,
    );
  }
}

/// Status of an uploaded document item
enum DocumentProcessingStatus { idle, processing, done, error }

/// Represents an uploaded document file or extracted page
class DocumentToolItem {
  final String id;
  final String name;
  final int fileSize;
  final String mimeType;
  final Uint8List originalBytes; // PRESERVED UNTOUCHED
  Uint8List? processedBytes; // Generated enhanced bytes
  Uint8List? thumbnailBytes; // Fast thumbnail for gallery list
  int width;
  int height;
  final bool isPdf;
  final int pdfPageNumber; // 1-based page index if extracted from PDF
  final int totalPdfPages;
  bool isSelected;
  DocumentEnhanceSettings settings;
  DocumentProcessingStatus status;
  String? errorMessage;
  String? qualityWarning;

  DocumentToolItem({
    required this.id,
    required this.name,
    required this.fileSize,
    required this.mimeType,
    required this.originalBytes,
    this.processedBytes,
    this.thumbnailBytes,
    this.width = 0,
    this.height = 0,
    this.isPdf = false,
    this.pdfPageNumber = 1,
    this.totalPdfPages = 1,
    this.isSelected = true,
    DocumentEnhanceSettings? settings,
    this.status = DocumentProcessingStatus.idle,
    this.errorMessage,
    this.qualityWarning,
  }) : settings = settings ?? const DocumentEnhanceSettings();

  bool get isLandscape => width > height;

  /// Returns current effective bytes (processed if available, else original)
  Uint8List get displayBytes => processedBytes ?? originalBytes;

  String get fileSizeFormatted {
    if (fileSize < 1024) return '$fileSize B';
    if (fileSize < 1024 * 1024) return '${(fileSize / 1024).toStringAsFixed(1)} KB';
    return '${(fileSize / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  DocumentToolItem copyWith({
    String? id,
    String? name,
    int? fileSize,
    String? mimeType,
    Uint8List? originalBytes,
    Uint8List? processedBytes,
    Uint8List? thumbnailBytes,
    int? width,
    int? height,
    bool? isPdf,
    int? pdfPageNumber,
    int? totalPdfPages,
    bool? isSelected,
    DocumentEnhanceSettings? settings,
    DocumentProcessingStatus? status,
    String? errorMessage,
    String? qualityWarning,
  }) {
    return DocumentToolItem(
      id: id ?? this.id,
      name: name ?? this.name,
      fileSize: fileSize ?? this.fileSize,
      mimeType: mimeType ?? this.mimeType,
      originalBytes: originalBytes ?? this.originalBytes,
      processedBytes: processedBytes ?? this.processedBytes,
      thumbnailBytes: thumbnailBytes ?? this.thumbnailBytes,
      width: width ?? this.width,
      height: height ?? this.height,
      isPdf: isPdf ?? this.isPdf,
      pdfPageNumber: pdfPageNumber ?? this.pdfPageNumber,
      totalPdfPages: totalPdfPages ?? this.totalPdfPages,
      isSelected: isSelected ?? this.isSelected,
      settings: settings ?? this.settings,
      status: status ?? this.status,
      errorMessage: errorMessage ?? this.errorMessage,
      qualityWarning: qualityWarning ?? this.qualityWarning,
    );
  }
}
