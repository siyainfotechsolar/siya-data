import 'dart:typed_data';
import 'package:flutter/material.dart';

class DocComparisonDialog extends StatefulWidget {
  final Uint8List originalBytes;
  final Uint8List enhancedBytes;
  final String title;

  const DocComparisonDialog({
    super.key,
    required this.originalBytes,
    required this.enhancedBytes,
    required this.title,
  });

  @override
  State<DocComparisonDialog> createState() => _DocComparisonDialogState();
}

class _DocComparisonDialogState extends State<DocComparisonDialog> {
  int _viewMode = 0; // 0: Side-by-side, 1: Split toggle / slider, 2: Enhanced Only

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDesktop = MediaQuery.of(context).size.width >= 900;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1050, maxHeight: 850),
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
                    child: Icon(Icons.compare_arrows_rounded, color: cs.primary, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Before & After Clarity Comparison: ${widget.title}',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const Text(
                          'Inspect text sharpness, shadow removal, and contrast before accepting',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                  SegmentedButton<int>(
                    segments: const [
                      ButtonSegment(value: 0, label: Text('Side by Side'), icon: Icon(Icons.view_column_outlined, size: 16)),
                      ButtonSegment(value: 1, label: Text('Original'), icon: Icon(Icons.history, size: 16)),
                      ButtonSegment(value: 2, label: Text('Enhanced'), icon: Icon(Icons.auto_fix_high, size: 16)),
                    ],
                    selected: {_viewMode},
                    onSelectionChanged: (set) => setState(() => _viewMode = set.first),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const Divider(height: 20),

              // Content View
              Expanded(
                child: _buildComparisonContent(isDesktop, cs),
              ),

              const Divider(height: 20),
              // Footer
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 12,
                runSpacing: 8,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.verified_outlined, size: 16, color: Colors.green.shade700),
                      const SizedBox(width: 6),
                      Text(
                        'Original file is strictly preserved. Hand-drawn signatures & stamps intact.',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                      ),
                    ],
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: cs.primary,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Close Comparison'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildComparisonContent(bool isDesktop, ColorScheme cs) {
    if (_viewMode == 1) {
      // Original Only
      return Column(
        children: [
          _buildBadge('ORIGINAL UPLOADED FILE (BEFORE)', Colors.grey.shade700, Colors.grey.shade200),
          const SizedBox(height: 8),
          Expanded(
            child: InteractiveViewer(
              child: Image.memory(widget.originalBytes, fit: BoxFit.contain),
            ),
          ),
        ],
      );
    }

    if (_viewMode == 2) {
      // Enhanced Only
      return Column(
        children: [
          _buildBadge('ENHANCED DOCUMENT OUTPUT (AFTER)', cs.primary, cs.primaryContainer),
          const SizedBox(height: 8),
          Expanded(
            child: InteractiveViewer(
              child: Image.memory(widget.enhancedBytes, fit: BoxFit.contain),
            ),
          ),
        ],
      );
    }

    // Side by side
    if (!isDesktop) {
      return Column(
        children: [
          Expanded(
            child: Column(
              children: [
                _buildBadge('ORIGINAL', Colors.grey.shade700, Colors.grey.shade200),
                const SizedBox(height: 4),
                Expanded(child: Image.memory(widget.originalBytes, fit: BoxFit.contain)),
              ],
            ),
          ),
          const Divider(height: 12),
          Expanded(
            child: Column(
              children: [
                _buildBadge('ENHANCED', cs.primary, cs.primaryContainer),
                const SizedBox(height: 4),
                Expanded(child: Image.memory(widget.enhancedBytes, fit: BoxFit.contain)),
              ],
            ),
          ),
        ],
      );
    }

    return Row(
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Column(
              children: [
                _buildBadge('ORIGINAL UPLOADED PHOTO', Colors.grey.shade700, Colors.grey.shade200),
                const SizedBox(height: 10),
                Expanded(
                  child: InteractiveViewer(
                    child: Image.memory(widget.originalBytes, fit: BoxFit.contain),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: cs.primaryContainer.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: cs.primary.withValues(alpha: 0.3)),
            ),
            child: Column(
              children: [
                _buildBadge('CLARITY ENHANCED (CLEAN BACKGROUND & SHARP TEXT)', cs.primary, cs.primaryContainer),
                const SizedBox(height: 10),
                Expanded(
                  child: InteractiveViewer(
                    child: Image.memory(widget.enhancedBytes, fit: BoxFit.contain),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBadge(String label, Color textColor, Color bgColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: textColor),
      ),
    );
  }
}
