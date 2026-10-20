import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../models/document_enhancer_models.dart';
import '../services/document_image_processor.dart';

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
  late double _cropLeft;
  late double _cropTop;
  late double _cropRight;
  late double _cropBottom;
  List<Point2D>? _corners;
  bool _usePerspective = false;
  bool _isAutoDetecting = false;

  @override
  void initState() {
    super.initState();
    _cropLeft = widget.initialSettings.cropLeft;
    _cropTop = widget.initialSettings.cropTop;
    _cropRight = widget.initialSettings.cropRight;
    _cropBottom = widget.initialSettings.cropBottom;
    _corners = widget.initialSettings.perspectiveCorners != null
        ? List.from(widget.initialSettings.perspectiveCorners!)
        : null;
    _usePerspective = _corners != null && _corners!.length == 4;
  }

  void _autoDetectCorners() {
    setState(() => _isAutoDetecting = true);
    try {
      final detected = DocumentImageProcessor.detectDocumentCorners(widget.imageBytes);
      setState(() {
        _corners = detected;
        _usePerspective = true;
        _isAutoDetecting = false;
      });
    } catch (_) {
      setState(() => _isAutoDetecting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDesktop = MediaQuery.of(context).size.width >= 900;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 950, maxHeight: 750),
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
                    child: Icon(Icons.crop_rotate_outlined, color: cs.primary, size: 22),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Crop Borders & Perspective Deskew',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        Text(
                          'Remove unwanted desk/bedsheet backgrounds and straighten tilted camera angles',
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

              // Body
              Expanded(
                child: isDesktop
                    ? Row(
                        children: [
                          Expanded(flex: 3, child: _buildPreviewArea(cs)),
                          const SizedBox(width: 16),
                          Expanded(flex: 2, child: _buildControlsArea(cs)),
                        ],
                      )
                    : SingleChildScrollView(
                        child: Column(
                          children: [
                            SizedBox(height: 300, child: _buildPreviewArea(cs)),
                            const SizedBox(height: 16),
                            _buildControlsArea(cs),
                          ],
                        ),
                      ),
              ),

              const Divider(height: 20),
              // Footer
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton.icon(
                    icon: const Icon(Icons.refresh, size: 16),
                    label: const Text('Reset Crop & Corners'),
                    onPressed: () {
                      setState(() {
                        _cropLeft = 0.0;
                        _cropTop = 0.0;
                        _cropRight = 0.0;
                        _cropBottom = 0.0;
                        _corners = null;
                        _usePerspective = false;
                      });
                    },
                  ),
                  Row(
                    children: [
                      OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.check, size: 18),
                        label: const Text('Apply Changes'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: cs.primary,
                          foregroundColor: Colors.white,
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

  Widget _buildPreviewArea(ColorScheme cs) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black87,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Underlying image
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.memory(
              widget.imageBytes,
              fit: BoxFit.contain,
            ),
          ),
          // Crop border overlay
          if (_cropLeft > 0 || _cropTop > 0 || _cropRight > 0 || _cropBottom > 0)
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: _CropOverlayPainter(
                    left: _cropLeft,
                    top: _cropTop,
                    right: _cropRight,
                    bottom: _cropBottom,
                    overlayColor: Colors.black54,
                    borderColor: cs.primary,
                  ),
                ),
              ),
            ),
          if (_usePerspective && _corners != null && _corners!.length == 4)
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: _PerspectiveQuadPainter(
                    corners: _corners!,
                    lineColor: Colors.greenAccent,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildControlsArea(ColorScheme cs) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Border Crop Margins (%):',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          ),
          const SizedBox(height: 6),
          _buildSliderRow('Left Margin', _cropLeft, (v) => setState(() => _cropLeft = v)),
          _buildSliderRow('Right Margin', _cropRight, (v) => setState(() => _cropRight = v)),
          _buildSliderRow('Top Margin', _cropTop, (v) => setState(() => _cropTop = v)),
          _buildSliderRow('Bottom Margin', _cropBottom, (v) => setState(() => _cropBottom = v)),
          const Divider(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Perspective Deskew:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              Switch(
                value: _usePerspective,
                onChanged: (val) {
                  setState(() {
                    _usePerspective = val;
                    if (val && _corners == null) {
                      _corners = const [
                        Point2D(0.04, 0.04),
                        Point2D(0.96, 0.04),
                        Point2D(0.96, 0.96),
                        Point2D(0.04, 0.96),
                      ];
                    }
                  });
                },
              ),
            ],
          ),
          if (_usePerspective) ...[
            const SizedBox(height: 8),
            ElevatedButton.icon(
              icon: _isAutoDetecting
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.auto_fix_high, size: 16),
              label: Text(_isAutoDetecting ? 'Detecting Borders...' : 'Auto-Detect Document Edges'),
              style: ElevatedButton.styleFrom(
                backgroundColor: cs.primary,
                foregroundColor: Colors.white,
                visualDensity: VisualDensity.compact,
              ),
              onPressed: _isAutoDetecting ? null : _autoDetectCorners,
            ),
            const SizedBox(height: 8),
            Text(
              '4-corner boundary mapping rectifies angle distortion from camera phone photos.',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSliderRow(String label, double val, ValueChanged<double> onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 90,
            child: Text(
              '$label (${(val * 100).round()}%)',
              style: const TextStyle(fontSize: 11),
            ),
          ),
          Expanded(
            child: Slider(
              value: val,
              min: 0.0,
              max: 0.35,
              divisions: 35,
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }
}

class _CropOverlayPainter extends CustomPainter {
  final double left;
  final double top;
  final double right;
  final double bottom;
  final Color overlayColor;
  final Color borderColor;

  _CropOverlayPainter({
    required this.left,
    required this.top,
    required this.right,
    required this.bottom,
    required this.overlayColor,
    required this.borderColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTRB(
      size.width * left,
      size.height * top,
      size.width * (1.0 - right),
      size.height * (1.0 - bottom),
    );

    // Draw darkened borders outside crop rect
    final overlayPaint = Paint()..color = overlayColor;
    canvas.drawRect(Rect.fromLTRB(0, 0, size.width, rect.top), overlayPaint);
    canvas.drawRect(Rect.fromLTRB(0, rect.bottom, size.width, size.height), overlayPaint);
    canvas.drawRect(Rect.fromLTRB(0, rect.top, rect.left, rect.bottom), overlayPaint);
    canvas.drawRect(Rect.fromLTRB(rect.right, rect.top, size.width, rect.bottom), overlayPaint);

    // Draw border
    final borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawRect(rect, borderPaint);
  }

  @override
  bool shouldRepaint(covariant _CropOverlayPainter oldDelegate) =>
      left != oldDelegate.left ||
      top != oldDelegate.top ||
      right != oldDelegate.right ||
      bottom != oldDelegate.bottom;
}

class _PerspectiveQuadPainter extends CustomPainter {
  final List<Point2D> corners;
  final Color lineColor;

  _PerspectiveQuadPainter({required this.corners, required this.lineColor});

  @override
  void paint(Canvas canvas, Size size) {
    if (corners.length != 4) return;

    final path = Path()
      ..moveTo(corners[0].x * size.width, corners[0].y * size.height)
      ..lineTo(corners[1].x * size.width, corners[1].y * size.height)
      ..lineTo(corners[2].x * size.width, corners[2].y * size.height)
      ..lineTo(corners[3].x * size.width, corners[3].y * size.height)
      ..close();

    final paint = Paint()
      ..color = lineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;

    canvas.drawPath(path, paint);

    // Corner dots
    final dotPaint = Paint()..color = Colors.white;
    for (final c in corners) {
      canvas.drawCircle(Offset(c.x * size.width, c.y * size.height), 5, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _PerspectiveQuadPainter oldDelegate) => true;
}
