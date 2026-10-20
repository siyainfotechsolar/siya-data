import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import '../models/document_enhancer_models.dart';
import '../services/document_image_processor.dart';

enum CropAspectRatio {
  freeform,
  a4Document,
  idCard,
  square,
}

class DocPerspectiveCropDialog extends StatefulWidget {
  final Uint8List imageBytes;
  final DocumentEnhanceSettings initialSettings;

  const DocPerspectiveCropDialog({
    super.key,
    required this.imageBytes,
    required this.initialSettings,
  });

  @override
  State<DocPerspectiveCropDialog> createState() => _DocPerspectiveCropDialogState();
}

class _DocPerspectiveCropDialogState extends State<DocPerspectiveCropDialog> {
  late Uint8List _renderedImageBytes;
  int _imageWidth = 1000;
  int _imageHeight = 1000;

  // Normalized crop bounds (0.0 to 0.45)
  double _cropLeft = 0.0;
  double _cropTop = 0.0;
  double _cropRight = 0.0;
  double _cropBottom = 0.0;

  // 4 perspective corners (normalized 0.0 to 1.0)
  List<Point2D>? _corners;
  bool _usePerspective = false;
  bool _isAutoDetecting = false;
  CropAspectRatio _selectedRatio = CropAspectRatio.freeform;

  @override
  void initState() {
    super.initState();
    _cropLeft = widget.initialSettings.cropLeft.clamp(0.0, 0.45);
    _cropTop = widget.initialSettings.cropTop.clamp(0.0, 0.45);
    _cropRight = widget.initialSettings.cropRight.clamp(0.0, 0.45);
    _cropBottom = widget.initialSettings.cropBottom.clamp(0.0, 0.45);

    _corners = widget.initialSettings.perspectiveCorners != null
        ? List.from(widget.initialSettings.perspectiveCorners!)
        : null;
    _usePerspective = _corners != null && _corners!.length == 4;

    // Prepare upright image if rotation is present
    _prepareImage();
  }

  void _prepareImage() {
    img.Image? decoded = img.decodeImage(widget.imageBytes);
    if (decoded == null) {
      _renderedImageBytes = widget.imageBytes;
      return;
    }

    if (widget.initialSettings.rotationAngle != 0) {
      decoded = img.copyRotate(decoded, angle: widget.initialSettings.rotationAngle);
      _renderedImageBytes = Uint8List.fromList(img.encodeJpg(decoded, quality: 90));
    } else {
      _renderedImageBytes = widget.imageBytes;
    }

    _imageWidth = decoded.width;
    _imageHeight = decoded.height;
  }

  void _autoDetectCorners() {
    setState(() => _isAutoDetecting = true);
    try {
      final bounds = DocumentImageProcessor.detectDocumentBounds(_renderedImageBytes);
      setState(() {
        if (bounds.isTilted || _usePerspective) {
          _usePerspective = true;
          _corners = bounds.corners;
        } else {
          _cropLeft = bounds.cropLeft;
          _cropTop = bounds.cropTop;
          _cropRight = bounds.cropRight;
          _cropBottom = bounds.cropBottom;
        }
        _isAutoDetecting = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(bounds.isTilted
                ? 'वाकडे डॉक्युमेंट ओळखले! (${bounds.skewAngle.abs().toStringAsFixed(1)}° Deskew corners set) Click "Apply Crop" to straighten.'
                : (bounds.hasCrop
                    ? 'Document boundaries auto-detected! (L:${(bounds.cropLeft * 100).round()}% T:${(bounds.cropTop * 100).round()}% R:${(bounds.cropRight * 100).round()}% B:${(bounds.cropBottom * 100).round()}%)'
                    : 'Document already fills the entire image.')),
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (_) {
      setState(() => _isAutoDetecting = false);
    }
  }

  void _setPresetMargins(double margin) {
    setState(() {
      _cropLeft = margin;
      _cropTop = margin;
      _cropRight = margin;
      _cropBottom = margin;
      _corners = null;
      _usePerspective = false;
    });
  }

  void _applyAspectRatio(CropAspectRatio ratio) {
    setState(() {
      _selectedRatio = ratio;
      if (ratio == CropAspectRatio.freeform) return;

      double targetAR = 1.0;
      if (ratio == CropAspectRatio.a4Document) {
        targetAR = 1.0 / 1.414; // Portrait A4
      } else if (ratio == CropAspectRatio.idCard) {
        targetAR = 4.0 / 3.0; // ID card
      } else if (ratio == CropAspectRatio.square) {
        targetAR = 1.0;
      }

      final imageAR = _imageWidth / _imageHeight;
      if (imageAR > targetAR) {
        // Image is wider than target: trim left/right
        final neededW = targetAR / imageAR;
        final totalTrim = (1.0 - neededW).clamp(0.0, 0.8);
        _cropLeft = totalTrim / 2;
        _cropRight = totalTrim / 2;
        _cropTop = 0.02;
        _cropBottom = 0.02;
      } else {
        // Image is taller than target: trim top/bottom
        final neededH = imageAR / targetAR;
        final totalTrim = (1.0 - neededH).clamp(0.0, 0.8);
        _cropTop = totalTrim / 2;
        _cropBottom = totalTrim / 2;
        _cropLeft = 0.02;
        _cropRight = 0.02;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDesktop = MediaQuery.of(context).size.width >= 900;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1050, maxHeight: 820),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: cs.primaryContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.crop, color: cs.primary, size: 22),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Crop Document & Straighten (कापा / Crop)',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        Text(
                          'Drag handles directly on the image to crop unwanted borders, desk, or background',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const Divider(height: 20),

              // Main Work Area
              Expanded(
                child: isDesktop
                    ? Row(
                        children: [
                          Expanded(flex: 7, child: _buildInteractiveCropViewer(cs)),
                          const SizedBox(width: 16),
                          SizedBox(width: 310, child: _buildControlsSidebar(cs)),
                        ],
                      )
                    : Column(
                        children: [
                          Expanded(child: _buildInteractiveCropViewer(cs)),
                          const SizedBox(height: 12),
                          SizedBox(height: 220, child: SingleChildScrollView(child: _buildControlsSidebar(cs))),
                        ],
                      ),
              ),

              const Divider(height: 20),
              // Footer
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 12,
                runSpacing: 8,
                children: [
                  TextButton.icon(
                    icon: const Icon(Icons.refresh, size: 16),
                    label: const Text('Reset to Full Image'),
                    onPressed: () => _setPresetMargins(0.0),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.check, size: 18),
                        label: const Text('Apply Crop'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: cs.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        ),
                        onPressed: () {
                          final updated = widget.initialSettings.copyWith(
                            cropLeft: _cropLeft,
                            cropTop: _cropTop,
                            cropRight: _cropRight,
                            cropBottom: _cropBottom,
                            perspectiveCorners: _usePerspective ? _corners : null,
                          );
                          Navigator.of(context).pop(updated);
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Interactive Crop Canvas ───────────────────────────────────────────────────

  Widget _buildInteractiveCropViewer(ColorScheme cs) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade800),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final containerW = constraints.maxWidth;
            final containerH = constraints.maxHeight;

            // Compute exact image rendered rectangle with BoxFit.contain
            final double imageAR = _imageWidth / _imageHeight;
            final double containerAR = containerW / containerH;

            double renderW, renderH, offsetX, offsetY;
            if (containerAR > imageAR) {
              renderH = containerH;
              renderW = containerH * imageAR;
              offsetX = (containerW - renderW) / 2;
              offsetY = 0;
            } else {
              renderW = containerW;
              renderH = containerW / imageAR;
              offsetX = 0;
              offsetY = (containerH - renderH) / 2;
            }

            final renderRect = Rect.fromLTWH(offsetX, offsetY, renderW, renderH);

            // Screen crop rect
            final cropRect = Rect.fromLTRB(
              renderRect.left + _cropLeft * renderRect.width,
              renderRect.top + _cropTop * renderRect.height,
              renderRect.right - _cropRight * renderRect.width,
              renderRect.bottom - _cropBottom * renderRect.height,
            );

            return Stack(
              children: [
                // 1. Image
                Positioned.fromRect(
                  rect: renderRect,
                  child: Image.memory(
                    _renderedImageBytes,
                    fit: BoxFit.fill,
                  ),
                ),

                // 2. Translucent Scrim & Crop Box Painter
                Positioned.fill(
                  child: IgnorePointer(
                    child: CustomPaint(
                      painter: _InteractiveCropPainter(
                        renderRect: renderRect,
                        cropRect: cropRect,
                        corners: _usePerspective ? _corners : null,
                        primaryColor: cs.primary,
                        showGrid: true,
                      ),
                    ),
                  ),
                ),

                // 3. Center Box Drag to Move
                if (!_usePerspective)
                  Positioned.fromRect(
                    rect: cropRect,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onPanUpdate: (details) {
                        final dx = details.delta.dx / renderRect.width;
                        final dy = details.delta.dy / renderRect.height;

                        setState(() {
                          final currentW = 1.0 - _cropLeft - _cropRight;
                          final currentH = 1.0 - _cropTop - _cropBottom;

                          final newLeft = (_cropLeft + dx).clamp(0.0, 1.0 - currentW);
                          final newTop = (_cropTop + dy).clamp(0.0, 1.0 - currentH);

                          _cropLeft = newLeft;
                          _cropRight = 1.0 - newLeft - currentW;
                          _cropTop = newTop;
                          _cropBottom = 1.0 - newTop - currentH;
                        });
                      },
                    ),
                  ),

                // 4. Edge Midpoint Handles
                if (!_usePerspective) ...[
                  // Top Edge
                  _buildEdgeHandle(
                    top: cropRect.top - 12,
                    left: cropRect.left + (cropRect.width / 2) - 24,
                    width: 48,
                    height: 24,
                    isHorizontal: true,
                    onPan: (dy) {
                      setState(() {
                        _cropTop = (_cropTop + (dy / renderRect.height)).clamp(0.0, 1.0 - _cropBottom - 0.05);
                      });
                    },
                  ),
                  // Bottom Edge
                  _buildEdgeHandle(
                    top: cropRect.bottom - 12,
                    left: cropRect.left + (cropRect.width / 2) - 24,
                    width: 48,
                    height: 24,
                    isHorizontal: true,
                    onPan: (dy) {
                      setState(() {
                        _cropBottom = (_cropBottom - (dy / renderRect.height)).clamp(0.0, 1.0 - _cropTop - 0.05);
                      });
                    },
                  ),
                  // Left Edge
                  _buildEdgeHandle(
                    top: cropRect.top + (cropRect.height / 2) - 24,
                    left: cropRect.left - 12,
                    width: 24,
                    height: 48,
                    isHorizontal: false,
                    onPan: (dx) {
                      setState(() {
                        _cropLeft = (_cropLeft + (dx / renderRect.width)).clamp(0.0, 1.0 - _cropRight - 0.05);
                      });
                    },
                  ),
                  // Right Edge
                  _buildEdgeHandle(
                    top: cropRect.top + (cropRect.height / 2) - 24,
                    left: cropRect.right - 12,
                    width: 24,
                    height: 48,
                    isHorizontal: false,
                    onPan: (dx) {
                      setState(() {
                        _cropRight = (_cropRight - (dx / renderRect.width)).clamp(0.0, 1.0 - _cropLeft - 0.05);
                      });
                    },
                  ),
                ],

                // 5. Four Corner Handles
                if (!_usePerspective) ...[
                  // Top-Left
                  _buildCornerHandle(
                    x: cropRect.left,
                    y: cropRect.top,
                    cs: cs,
                    onPan: (dx, dy) {
                      setState(() {
                        _cropLeft = (_cropLeft + (dx / renderRect.width)).clamp(0.0, 1.0 - _cropRight - 0.05);
                        _cropTop = (_cropTop + (dy / renderRect.height)).clamp(0.0, 1.0 - _cropBottom - 0.05);
                      });
                    },
                  ),
                  // Top-Right
                  _buildCornerHandle(
                    x: cropRect.right,
                    y: cropRect.top,
                    cs: cs,
                    onPan: (dx, dy) {
                      setState(() {
                        _cropRight = (_cropRight - (dx / renderRect.width)).clamp(0.0, 1.0 - _cropLeft - 0.05);
                        _cropTop = (_cropTop + (dy / renderRect.height)).clamp(0.0, 1.0 - _cropBottom - 0.05);
                      });
                    },
                  ),
                  // Bottom-Left
                  _buildCornerHandle(
                    x: cropRect.left,
                    y: cropRect.bottom,
                    cs: cs,
                    onPan: (dx, dy) {
                      setState(() {
                        _cropLeft = (_cropLeft + (dx / renderRect.width)).clamp(0.0, 1.0 - _cropRight - 0.05);
                        _cropBottom = (_cropBottom - (dy / renderRect.height)).clamp(0.0, 1.0 - _cropTop - 0.05);
                      });
                    },
                  ),
                  // Bottom-Right
                  _buildCornerHandle(
                    x: cropRect.right,
                    y: cropRect.bottom,
                    cs: cs,
                    onPan: (dx, dy) {
                      setState(() {
                        _cropRight = (_cropRight - (dx / renderRect.width)).clamp(0.0, 1.0 - _cropLeft - 0.05);
                        _cropBottom = (_cropBottom - (dy / renderRect.height)).clamp(0.0, 1.0 - _cropTop - 0.05);
                      });
                    },
                  ),
                ],

                // 6. Perspective Corner Handles (if perspective mode active)
                if (_usePerspective && _corners != null && _corners!.length == 4) ...[
                  for (int i = 0; i < 4; i++)
                    _buildPerspectiveCornerHandle(
                      index: i,
                      corner: _corners![i],
                      renderRect: renderRect,
                      cs: cs,
                    ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildCornerHandle({
    required double x,
    required double y,
    required ColorScheme cs,
    required void Function(double dx, double dy) onPan,
  }) {
    return Positioned(
      left: x - 18,
      top: y - 18,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanUpdate: (details) => onPan(details.delta.dx, details.delta.dy),
        child: Container(
          width: 36,
          height: 36,
          alignment: Alignment.center,
          child: Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: cs.primary, width: 3.5),
              boxShadow: const [
                BoxShadow(color: Colors.black45, blurRadius: 4, offset: Offset(0, 2)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEdgeHandle({
    required double left,
    required double top,
    required double width,
    required double height,
    required bool isHorizontal,
    required void Function(double delta) onPan,
  }) {
    return Positioned(
      left: left,
      top: top,
      width: width,
      height: height,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanUpdate: (details) => onPan(isHorizontal ? details.delta.dy : details.delta.dx),
        child: Center(
          child: Container(
            width: isHorizontal ? 36 : 10,
            height: isHorizontal ? 10 : 36,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(5),
              border: Border.all(color: Colors.black87, width: 1.5),
              boxShadow: const [
                BoxShadow(color: Colors.black38, blurRadius: 3),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPerspectiveCornerHandle({
    required int index,
    required Point2D corner,
    required Rect renderRect,
    required ColorScheme cs,
  }) {
    final x = renderRect.left + corner.x * renderRect.width;
    final y = renderRect.top + corner.y * renderRect.height;

    return Positioned(
      left: x - 18,
      top: y - 18,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanUpdate: (details) {
          final newX = (corner.x + (details.delta.dx / renderRect.width)).clamp(0.0, 1.0);
          final newY = (corner.y + (details.delta.dy / renderRect.height)).clamp(0.0, 1.0);
          setState(() {
            _corners![index] = Point2D(newX, newY);
          });
        },
        child: Container(
          width: 36,
          height: 36,
          alignment: Alignment.center,
          child: Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: Colors.greenAccent,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.black, width: 2.5),
              boxShadow: const [
                BoxShadow(color: Colors.black54, blurRadius: 4),
              ],
            ),
            child: Center(
              child: Text(
                '${index + 1}',
                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Controls Sidebar ─────────────────────────────────────────────────────────

  Widget _buildControlsSidebar(ColorScheme cs) {
    final croppedW = (_imageWidth * (1.0 - _cropLeft - _cropRight)).round();
    final croppedH = (_imageHeight * (1.0 - _cropTop - _cropBottom)).round();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Live Size Info Badge
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: cs.primaryContainer.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    children: [
                      const Text('Cropped Size:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                      Text('${croppedW}x$croppedH px', style: TextStyle(fontWeight: FontWeight.bold, color: cs.primary, fontSize: 12)),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Original: ${_imageWidth}x$_imageHeight px (${((1.0 - (croppedW * croppedH / (_imageWidth * _imageHeight))) * 100).round()}% trimmed)',
                    style: TextStyle(fontSize: 10.5, color: Colors.grey.shade700),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 14),

          // 1-Click Quick Margins
          const Text('Quick Border Trim:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              OutlinedButton(
                style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact),
                onPressed: () => _setPresetMargins(0.0),
                child: const Text('Full (0%)', style: TextStyle(fontSize: 11)),
              ),
              OutlinedButton(
                style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact),
                onPressed: () => _setPresetMargins(0.05),
                child: const Text('Trim 5%', style: TextStyle(fontSize: 11)),
              ),
              OutlinedButton(
                style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact),
                onPressed: () => _setPresetMargins(0.10),
                child: const Text('Trim 10%', style: TextStyle(fontSize: 11)),
              ),
              ElevatedButton.icon(
                icon: _isAutoDetecting
                    ? const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.auto_awesome, size: 14),
                label: Text(_isAutoDetecting ? 'Detecting...' : 'Auto Crop (स्मार्ट क्रॉप)', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: cs.primary,
                  foregroundColor: Colors.white,
                  visualDensity: VisualDensity.compact,
                ),
                onPressed: _isAutoDetecting ? null : _autoDetectCorners,
              ),
            ],
          ),

          const Divider(height: 24),
          // Aspect Ratio Presets
          const Text('Aspect Ratio:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              ChoiceChip(
                label: const Text('Freeform', style: TextStyle(fontSize: 11)),
                selected: _selectedRatio == CropAspectRatio.freeform,
                onSelected: (_) => _applyAspectRatio(CropAspectRatio.freeform),
              ),
              ChoiceChip(
                label: const Text('A4 (1:1.41)', style: TextStyle(fontSize: 11)),
                selected: _selectedRatio == CropAspectRatio.a4Document,
                onSelected: (_) => _applyAspectRatio(CropAspectRatio.a4Document),
              ),
              ChoiceChip(
                label: const Text('ID Card (4:3)', style: TextStyle(fontSize: 11)),
                selected: _selectedRatio == CropAspectRatio.idCard,
                onSelected: (_) => _applyAspectRatio(CropAspectRatio.idCard),
              ),
              ChoiceChip(
                label: const Text('1:1 Square', style: TextStyle(fontSize: 11)),
                selected: _selectedRatio == CropAspectRatio.square,
                onSelected: (_) => _applyAspectRatio(CropAspectRatio.square),
              ),
            ],
          ),

          const Divider(height: 24),
          // Perspective Deskew Switch
          SwitchListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: const Text('Perspective Deskew', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
            subtitle: const Text('Free 4-corner warp for tilted documents', style: TextStyle(fontSize: 10.5)),
            value: _usePerspective,
            onChanged: (val) {
              setState(() {
                _usePerspective = val;
                if (val && _corners == null) {
                  _corners = [
                    Point2D(_cropLeft, _cropTop),
                    Point2D(1.0 - _cropRight, _cropTop),
                    Point2D(1.0 - _cropRight, 1.0 - _cropBottom),
                    Point2D(_cropLeft, 1.0 - _cropBottom),
                  ];
                }
              });
            },
          ),
          const SizedBox(height: 8),
          Text(
            '💡 Tip: Drag corner or edge handles to crop out surrounding background. Click "Apply Crop" to save.',
            style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontStyle: FontStyle.italic),
          ),
        ],
      ),
    ),
  );
}
}

// ── Custom Painter for Scrim, Grid & Crop Border ────────────────────────────────

class _InteractiveCropPainter extends CustomPainter {
  final Rect renderRect;
  final Rect cropRect;
  final List<Point2D>? corners;
  final Color primaryColor;
  final bool showGrid;

  _InteractiveCropPainter({
    required this.renderRect,
    required this.cropRect,
    required this.corners,
    required this.primaryColor,
    required this.showGrid,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (corners != null && corners!.length == 4) {
      // Perspective mode polygon
      _paintPerspectivePolygon(canvas, size);
      return;
    }

    // 1. Dark Scrim outside cropRect
    final scrimPaint = Paint()..color = Colors.black.withValues(alpha: 0.65);

    // Top rect
    canvas.drawRect(Rect.fromLTRB(renderRect.left, renderRect.top, renderRect.right, cropRect.top), scrimPaint);
    // Bottom rect
    canvas.drawRect(Rect.fromLTRB(renderRect.left, cropRect.bottom, renderRect.right, renderRect.bottom), scrimPaint);
    // Left rect
    canvas.drawRect(Rect.fromLTRB(renderRect.left, cropRect.top, cropRect.left, cropRect.bottom), scrimPaint);
    // Right rect
    canvas.drawRect(Rect.fromLTRB(cropRect.right, cropRect.top, renderRect.right, cropRect.bottom), scrimPaint);

    // 2. Crop Box Outer Border
    final borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawRect(cropRect, borderPaint);

    // Primary accent line
    final accentPaint = Paint()
      ..color = primaryColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawRect(cropRect, accentPaint);

    // 3. Rule of Thirds Grid Lines
    if (showGrid && cropRect.width > 60 && cropRect.height > 60) {
      final gridPaint = Paint()
        ..color = Colors.white.withValues(alpha: 0.35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8;

      final oneThirdW = cropRect.width / 3.0;
      final oneThirdH = cropRect.height / 3.0;

      // Vertical grid lines
      canvas.drawLine(
        Offset(cropRect.left + oneThirdW, cropRect.top),
        Offset(cropRect.left + oneThirdW, cropRect.bottom),
        gridPaint,
      );
      canvas.drawLine(
        Offset(cropRect.left + 2 * oneThirdW, cropRect.top),
        Offset(cropRect.left + 2 * oneThirdW, cropRect.bottom),
        gridPaint,
      );

      // Horizontal grid lines
      canvas.drawLine(
        Offset(cropRect.left, cropRect.top + oneThirdH),
        Offset(cropRect.right, cropRect.top + oneThirdH),
        gridPaint,
      );
      canvas.drawLine(
        Offset(cropRect.left, cropRect.top + 2 * oneThirdH),
        Offset(cropRect.right, cropRect.top + 2 * oneThirdH),
        gridPaint,
      );
    }
  }

  void _paintPerspectivePolygon(Canvas canvas, Size size) {
    final pts = corners!.map((c) => Offset(
      renderRect.left + c.x * renderRect.width,
      renderRect.top + c.y * renderRect.height,
    )).toList();

    final path = Path()
      ..moveTo(pts[0].dx, pts[0].dy)
      ..lineTo(pts[1].dx, pts[1].dy)
      ..lineTo(pts[2].dx, pts[2].dy)
      ..lineTo(pts[3].dx, pts[3].dy)
      ..close();

    // Semi-transparent overlay outside polygon
    final scrimPath = Path.combine(
      PathOperation.difference,
      Path()..addRect(renderRect),
      path,
    );
    canvas.drawPath(scrimPath, Paint()..color = Colors.black.withValues(alpha: 0.65));

    // Green guideline stroke
    final linePaint = Paint()
      ..color = Colors.greenAccent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;
    canvas.drawPath(path, linePaint);
  }

  @override
  bool shouldRepaint(covariant _InteractiveCropPainter oldDelegate) => true;
}
