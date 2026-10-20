import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:printing/printing.dart';
import '../models/document_enhancer_models.dart';
import '../services/document_image_processor.dart';
import '../services/document_a4_pdf_service.dart';
import '../widgets/doc_comparison_dialog.dart';
import '../widgets/doc_perspective_crop_dialog.dart';
import '../widgets/save_doc_to_customer_dialog.dart';
import '../utils/responsive.dart';

class DocumentEnhancerScreen extends StatefulWidget {
  const DocumentEnhancerScreen({super.key});

  @override
  State<DocumentEnhancerScreen> createState() => _DocumentEnhancerScreenState();
}

class _DocumentEnhancerScreenState extends State<DocumentEnhancerScreen> with SingleTickerProviderStateMixin {
  final List<DocumentToolItem> _items = [];
  int _activeItemIndex = 0;

  // Settings
  A4PageSettings _a4Settings = const A4PageSettings();

  // PDF Preview State
  Uint8List? _generatedPdfBytes;
  bool _isGeneratingPdf = false;
  bool _isProcessingImage = false;
  String? _statusMessage;
  String? _errorMessage;

  // Mobile Tabs
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  DocumentToolItem? get _activeItem {
    if (_items.isEmpty) return null;
    if (_activeItemIndex >= 0 && _activeItemIndex < _items.length) {
      return _items[_activeItemIndex];
    }
    return _items.first;
  }

  // ── Document Upload Handling ──────────────────────────────────────────────────

  Future<void> _pickFiles() async {
    setState(() {
      _errorMessage = null;
      _statusMessage = 'Selecting files...';
    });

    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png', 'webp'],
        withData: true,
      );

      if (result == null || result.files.isEmpty) {
        setState(() => _statusMessage = null);
        return;
      }

      int addedCount = 0;
      for (final file in result.files) {
        final bytes = file.bytes;
        if (bytes == null || bytes.isEmpty) continue;

        final ext = (file.extension ?? '').toLowerCase();
        final isPdf = ext == 'pdf';

        if (isPdf) {
          // Extract PDF pages
          setState(() => _statusMessage = 'Extracting pages from ${file.name}...');
          try {
            final pdfPages = await DocumentA4PdfService.extractPagesFromPdf(
              fileId: 'pdf_${DateTime.now().millisecondsSinceEpoch}',
              fileName: file.name,
              pdfBytes: bytes,
            );
            _items.addAll(pdfPages);
            addedCount += pdfPages.length;
          } catch (e) {
            _showSnack('PDF extraction error: $e', isError: true);
          }
        } else {
          // Process Image
          setState(() => _statusMessage = 'Analyzing ${file.name}...');
          try {
            final meta = DocumentImageProcessor.analyzeImage(bytes);
            final item = DocumentToolItem(
              id: 'img_${DateTime.now().millisecondsSinceEpoch}_${_items.length}',
              name: file.name,
              fileSize: bytes.length,
              mimeType: 'image/$ext',
              originalBytes: bytes,
              thumbnailBytes: meta['thumbnail'],
              width: meta['width'] ?? 0,
              height: meta['height'] ?? 0,
              qualityWarning: meta['warning'],
            );
            _items.add(item);
            addedCount++;
          } catch (e) {
            _showSnack('Failed to load image ${file.name}: $e', isError: true);
          }
        }
      }

      setState(() {
        _statusMessage = null;
        if (_items.isNotEmpty && _activeItemIndex >= _items.length) {
          _activeItemIndex = 0;
        }
      });

      if (addedCount > 0) {
        _showSnack('Successfully loaded $addedCount document item(s).');
        _triggerPdfRegeneration();
      }
    } catch (e) {
      setState(() {
        _statusMessage = null;
        _errorMessage = 'Error picking files: $e';
      });
    }
  }

  void _removeItem(int index) {
    if (index >= 0 && index < _items.length) {
      setState(() {
        _items.removeAt(index);
        if (_activeItemIndex >= _items.length) {
          _activeItemIndex = _items.isEmpty ? 0 : _items.length - 1;
        }
      });
      _triggerPdfRegeneration();
    }
  }

  void _clearAllFiles() {
    if (_items.isEmpty) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear All Files?'),
        content: const Text('This will remove all uploaded and processed documents from temporary memory.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () {
              Navigator.of(ctx).pop();
              setState(() {
                _items.clear();
                _activeItemIndex = 0;
                _generatedPdfBytes = null;
              });
              _showSnack('All files cleared.');
            },
            child: const Text('Clear All'),
          ),
        ],
      ),
    );
  }

  void _moveItem(int index, int delta) {
    final target = index + delta;
    if (target < 0 || target >= _items.length) return;
    setState(() {
      final item = _items.removeAt(index);
      _items.insert(target, item);
      _activeItemIndex = target;
    });
    _triggerPdfRegeneration();
  }

  // ── Document Enhancement Handling ─────────────────────────────────────────────

  Future<void> _applyEnhancementToItem({
    required int index,
    required DocumentEnhanceSettings settings,
    bool autoRegenPdf = true,
  }) async {
    if (index < 0 || index >= _items.length) return;
    final item = _items[index];

    setState(() {
      item.status = DocumentProcessingStatus.processing;
      _isProcessingImage = true;
    });

    try {
      final enhanced = await DocumentImageProcessor.enhanceDocument(
        originalBytes: item.originalBytes,
        settings: settings,
      );

      final meta = DocumentImageProcessor.analyzeImage(enhanced);

      setState(() {
        item.settings = settings;
        item.processedBytes = enhanced;
        item.thumbnailBytes = meta['thumbnail'];
        item.width = meta['width'] ?? item.width;
        item.height = meta['height'] ?? item.height;
        item.status = DocumentProcessingStatus.done;
        _isProcessingImage = false;
      });

      if (autoRegenPdf) {
        _triggerPdfRegeneration();
      }
    } catch (e) {
      setState(() {
        item.status = DocumentProcessingStatus.error;
        item.errorMessage = e.toString();
        _isProcessingImage = false;
      });
      _showSnack('Enhancement failed: $e', isError: true);
    }
  }

  Future<void> _applyToAllSelected(DocumentEnhanceSettings settings) async {
    final selectedIndices = <int>[];
    for (int i = 0; i < _items.length; i++) {
      if (_items[i].isSelected) selectedIndices.add(i);
    }

    if (selectedIndices.isEmpty) {
      _showSnack('No documents selected.', isError: true);
      return;
    }

    setState(() {
      _isProcessingImage = true;
      _statusMessage = 'Enhancing ${selectedIndices.length} document(s)...';
    });

    for (final idx in selectedIndices) {
      await _applyEnhancementToItem(index: idx, settings: settings, autoRegenPdf: false);
    }

    setState(() {
      _isProcessingImage = false;
      _statusMessage = null;
    });

    _showSnack('Applied enhancement to ${selectedIndices.length} document(s).');
    _triggerPdfRegeneration();
  }

  void _resetActiveItem() {
    final item = _activeItem;
    if (item == null) return;
    setState(() {
      item.settings = const DocumentEnhanceSettings();
      item.processedBytes = null;
      item.status = DocumentProcessingStatus.idle;
    });
    _showSnack('Reset "${item.name}" to original.');
    _triggerPdfRegeneration();
  }

  void _rotateActiveItem(int deltaAngle) {
    final item = _activeItem;
    if (item == null) return;
    final newAngle = (item.settings.rotationAngle + deltaAngle) % 360;
    final updated = item.settings.copyWith(rotationAngle: newAngle);
    _applyEnhancementToItem(index: _activeItemIndex, settings: updated);
  }

  // ── PDF Generation ────────────────────────────────────────────────────────────

  Future<void> _triggerPdfRegeneration() async {
    final selected = _items.where((it) => it.isSelected).toList();
    if (selected.isEmpty) {
      setState(() => _generatedPdfBytes = null);
      return;
    }

    setState(() => _isGeneratingPdf = true);

    try {
      final pdfBytes = await DocumentA4PdfService.generateA4Pdf(
        items: _items,
        settings: _a4Settings,
      );

      if (mounted) {
        setState(() {
          _generatedPdfBytes = pdfBytes;
          _isGeneratingPdf = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isGeneratingPdf = false;
          _errorMessage = 'PDF Generation error: $e';
        });
      }
    }
  }

  // ── Action Buttons ────────────────────────────────────────────────────────────

  Future<void> _handleDirectPrint() async {
    if (_generatedPdfBytes == null) {
      await _triggerPdfRegeneration();
    }
    if (_generatedPdfBytes == null) return;

    await Printing.layoutPdf(
      onLayout: (format) async => _generatedPdfBytes!,
      name: 'Siya_Document_A4_${DateTime.now().millisecondsSinceEpoch}.pdf',
    );
  }

  Future<void> _handleDownloadPdf() async {
    if (_generatedPdfBytes == null) {
      await _triggerPdfRegeneration();
    }
    if (_generatedPdfBytes == null) return;

    final fileName = 'Siya_Document_A4_${DateTime.now().millisecondsSinceEpoch}.pdf';
    await Printing.sharePdf(bytes: _generatedPdfBytes!, filename: fileName);
  }

  void _openSaveToCustomerDialog() {
    if (_generatedPdfBytes == null) {
      _showSnack('Generate an A4 document first.', isError: true);
      return;
    }

    showDialog(
      context: context,
      builder: (_) => SaveDocToCustomerDialog(
        pdfBytes: _generatedPdfBytes!,
        defaultDocName: _activeItem?.name.replaceAll(RegExp(r'\.[a-zA-Z0-9]+$'), '') ?? 'Enhanced_Document',
      ),
    ).then((saved) {
      if (saved == true && mounted) {
        _showSnack('Document attached to customer record successfully!');
      }
    });
  }

  void _openComparisonDialog() {
    final item = _activeItem;
    if (item == null) return;

    showDialog(
      context: context,
      builder: (_) => DocComparisonDialog(
        originalBytes: item.originalBytes,
        enhancedBytes: item.displayBytes,
        title: item.name,
      ),
    );
  }

  Future<void> _openPerspectiveCropDialog() async {
    final item = _activeItem;
    if (item == null) return;

    final result = await showDialog<DocumentEnhanceSettings>(
      context: context,
      builder: (_) => DocPerspectiveCropDialog(
        imageBytes: item.originalBytes,
        initialSettings: item.settings,
      ),
    );

    if (result != null) {
      _applyEnhancementToItem(index: _activeItemIndex, settings: result);
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? Colors.red.shade700 : const Color(0xFF0F2D69),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // ── Build Method ──────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDesktop = Responsive.isDesktop(context);

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Document Clear, Enhance & A4 Print',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            Text(
              'Tools → Process WhatsApp photos, sharpen text, remove shadows & print ISO A4 PDFs',
              style: TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          if (_items.isNotEmpty) ...[
            TextButton.icon(
              icon: const Icon(Icons.clear_all, size: 18),
              label: const Text('Clear All'),
              onPressed: _clearAllFiles,
            ),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              icon: const Icon(Icons.print_outlined, size: 18),
              label: const Text('Print A4'),
              style: ElevatedButton.styleFrom(
                backgroundColor: cs.primary,
                foregroundColor: Colors.white,
              ),
              onPressed: _generatedPdfBytes == null ? null : _handleDirectPrint,
            ),
            const SizedBox(width: 12),
          ],
        ],
        bottom: isDesktop
            ? null
            : TabBar(
                controller: _tabController,
                tabs: const [
                  Tab(icon: Icon(Icons.upload_file), text: 'Upload'),
                  Tab(icon: Icon(Icons.auto_fix_high), text: 'Enhance & A4'),
                  Tab(icon: Icon(Icons.picture_as_pdf), text: 'Preview & Print'),
                ],
              ),
      ),
      body: isDesktop ? _buildDesktopLayout(cs) : _buildMobileLayout(cs),
    );
  }

  // ── Desktop Layout ────────────────────────────────────────────────────────────

  Widget _buildDesktopLayout(ColorScheme cs) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left Column: Uploads + Enhancer + A4 Settings (Scrollable)
        SizedBox(
          width: 500,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildSectionAUpload(cs),
                const SizedBox(height: 16),
                if (_items.isNotEmpty) ...[
                  _buildSectionBClarityEnhancement(cs),
                  const SizedBox(height: 16),
                  _buildSectionCA4Settings(cs),
                  const SizedBox(height: 16),
                  _buildPrinterTipBanner(cs),
                ],
              ],
            ),
          ),
        ),
        const VerticalDivider(width: 1, thickness: 1),
        // Right Column: PDF Preview & Action Controls
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: _buildSectionEPreviewAndExport(cs),
          ),
        ),
      ],
    );
  }

  // ── Mobile Layout ─────────────────────────────────────────────────────────────

  Widget _buildMobileLayout(ColorScheme cs) {
    return TabBarView(
      controller: _tabController,
      children: [
        // Tab 1: Upload
        SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              _buildSectionAUpload(cs),
              const SizedBox(height: 16),
              if (_items.isNotEmpty) _buildPrinterTipBanner(cs),
            ],
          ),
        ),
        // Tab 2: Enhance & A4
        SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: _items.isEmpty
              ? _buildEmptyUploadPrompt(cs)
              : Column(
                  children: [
                    _buildSectionBClarityEnhancement(cs),
                    const SizedBox(height: 16),
                    _buildSectionCA4Settings(cs),
                  ],
                ),
        ),
        // Tab 3: Preview & Print
        Padding(
          padding: const EdgeInsets.all(16),
          child: _items.isEmpty ? _buildEmptyUploadPrompt(cs) : _buildSectionEPreviewAndExport(cs),
        ),
      ],
    );
  }

  // ── Section A: Upload Documents ───────────────────────────────────────────────

  Widget _buildSectionAUpload(ColorScheme cs) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.6)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_errorMessage != null) ...[
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(_errorMessage!, style: const TextStyle(fontSize: 12, color: Colors.red)),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 14),
                      visualDensity: VisualDensity.compact,
                      onPressed: () => setState(() => _errorMessage = null),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: cs.primaryContainer,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(Icons.file_upload_outlined, color: cs.primary, size: 20),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Section A: Upload Documents',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ),
                if (_items.isNotEmpty)
                  Text(
                    '${_items.length} items',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: cs.primary),
                  ),
              ],
            ),
            const SizedBox(height: 12),

            // Drop zone area
            InkWell(
              onTap: _pickFiles,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                decoration: BoxDecoration(
                  color: cs.primaryContainer.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: cs.primary.withValues(alpha: 0.5),
                    style: BorderStyle.solid,
                    width: 1.5,
                  ),
                ),
                child: Column(
                  children: [
                    Icon(Icons.cloud_upload_rounded, color: cs.primary, size: 40),
                    const SizedBox(height: 10),
                    const Text(
                      'Drag & drop WhatsApp photos or PDF files here',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Supports JPG, PNG, WEBP, and multi-page PDF documents',
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.folder_open, size: 16),
                      label: const Text('Browse Files / Photos'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: cs.primary,
                        foregroundColor: Colors.white,
                        visualDensity: VisualDensity.compact,
                      ),
                      onPressed: _pickFiles,
                    ),
                  ],
                ),
              ),
            ),

            if (_statusMessage != null) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _statusMessage!,
                      style: TextStyle(fontSize: 12, color: cs.primary, fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ],

            if (_items.isNotEmpty) ...[
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Document Queue:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                  Row(
                    children: [
                      TextButton(
                        style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                        onPressed: () {
                          setState(() {
                            for (final it in _items) {
                              it.isSelected = true;
                            }
                          });
                          _triggerPdfRegeneration();
                        },
                        child: const Text('Select All', style: TextStyle(fontSize: 11)),
                      ),
                      TextButton(
                        style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                        onPressed: () {
                          setState(() {
                            for (final it in _items) {
                              it.isSelected = false;
                            }
                          });
                          _triggerPdfRegeneration();
                        },
                        child: const Text('Deselect All', style: TextStyle(fontSize: 11)),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _buildDocumentList(cs),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDocumentList(ColorScheme cs) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _items.length,
      separatorBuilder: (_, _) => const SizedBox(height: 6),
      itemBuilder: (ctx, i) {
        final item = _items[i];
        final isActive = i == _activeItemIndex;

        return Material(
          color: isActive ? cs.primaryContainer.withValues(alpha: 0.3) : cs.surfaceContainerHighest.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(8),
          child: InkWell(
            onTap: () => setState(() => _activeItemIndex = i),
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isActive ? cs.primary : Colors.grey.shade300,
                  width: isActive ? 1.5 : 1.0,
                ),
              ),
              child: Row(
                children: [
                  Checkbox(
                    value: item.isSelected,
                    visualDensity: VisualDensity.compact,
                    onChanged: (val) {
                      setState(() => item.isSelected = val ?? true);
                      _triggerPdfRegeneration();
                    },
                  ),
                  // Thumbnail preview
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: SizedBox(
                      width: 44,
                      height: 52,
                      child: item.thumbnailBytes != null
                          ? Image.memory(item.thumbnailBytes!, fit: BoxFit.cover)
                          : Container(
                              color: Colors.grey.shade200,
                              child: const Icon(Icons.image, size: 20, color: Colors.grey),
                            ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.name,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: isActive ? FontWeight.bold : FontWeight.w600,
                            color: isActive ? cs.primary : null,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Text(
                              '${item.fileSizeFormatted} • ${item.width}x${item.height}',
                              style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                            ),
                            if (item.settings.hasAnyEnhancement) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                decoration: BoxDecoration(
                                  color: Colors.green.shade100,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  'Enhanced',
                                  style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.green.shade800),
                                ),
                              ),
                            ],
                          ],
                        ),
                        if (item.qualityWarning != null) ...[
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Icon(Icons.warning_amber_rounded, size: 12, color: Colors.amber.shade800),
                              const SizedBox(width: 3),
                              Expanded(
                                child: Text(
                                  item.qualityWarning!,
                                  style: TextStyle(fontSize: 9.5, color: Colors.amber.shade900),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  // Controls: Move up/down, rotate, delete
                  IconButton(
                    icon: const Icon(Icons.arrow_upward, size: 16),
                    tooltip: 'Move Up',
                    visualDensity: VisualDensity.compact,
                    onPressed: i > 0 ? () => _moveItem(i, -1) : null,
                  ),
                  IconButton(
                    icon: const Icon(Icons.arrow_downward, size: 16),
                    tooltip: 'Move Down',
                    visualDensity: VisualDensity.compact,
                    onPressed: i < _items.length - 1 ? () => _moveItem(i, 1) : null,
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 16, color: Colors.red),
                    tooltip: 'Remove',
                    visualDensity: VisualDensity.compact,
                    onPressed: () => _removeItem(i),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ── Section B: Document Clarity Enhancement ───────────────────────────────────

  Widget _buildSectionBClarityEnhancement(ColorScheme cs) {
    final item = _activeItem;
    if (item == null) return const SizedBox.shrink();

    final s = item.settings;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.6)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: cs.primaryContainer,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(Icons.auto_fix_high, color: cs.primary, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Section B: Clarity Enhancement',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      Text(
                        'Editing: ${item.name}',
                        style: TextStyle(fontSize: 11, color: cs.primary, fontWeight: FontWeight.w600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                if (_isProcessingImage)
                  const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
              ],
            ),
            const SizedBox(height: 12),

            // Presets
            const Text('Clarity Presets:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                ActionChip(
                  avatar: const Icon(Icons.history, size: 14),
                  label: const Text('Original', style: TextStyle(fontSize: 11)),
                  onPressed: _resetActiveItem,
                ),
                ActionChip(
                  avatar: const Icon(Icons.bolt, size: 14, color: Colors.blue),
                  label: const Text('Quick Fix (Low)', style: TextStyle(fontSize: 11)),
                  onPressed: () => _applyEnhancementToItem(
                    index: _activeItemIndex,
                    settings: DocumentEnhanceSettings.presetLow(),
                  ),
                ),
                ActionChip(
                  avatar: const Icon(Icons.check_circle_outline, size: 14, color: Colors.teal),
                  label: const Text('Balanced (Medium)', style: TextStyle(fontSize: 11)),
                  onPressed: () => _applyEnhancementToItem(
                    index: _activeItemIndex,
                    settings: DocumentEnhanceSettings.presetMedium(),
                  ),
                ),
                ActionChip(
                  avatar: const Icon(Icons.document_scanner, size: 14, color: Colors.deepOrange),
                  label: const Text('Crisp Document (High)', style: TextStyle(fontSize: 11)),
                  onPressed: () => _applyEnhancementToItem(
                    index: _activeItemIndex,
                    settings: DocumentEnhanceSettings.presetHigh(),
                  ),
                ),
              ],
            ),
            const Divider(height: 20),

            // Toggles: Background Cleanup & B&W Mode
            SwitchListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: const Text('Background Cleanup & Shadow Removal', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              subtitle: const Text('Flattens camera phone lighting and removes dark corner shadows', style: TextStyle(fontSize: 10.5)),
              value: s.backgroundCleanup,
              onChanged: (val) {
                _applyEnhancementToItem(
                  index: _activeItemIndex,
                  settings: s.copyWith(backgroundCleanup: val),
                );
              },
            ),
            SwitchListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: const Text('Crisp B&W Document Mode (Adaptive Threshold)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              subtitle: const Text('Converts paper to clean white and text/stamps to crisp black ink', style: TextStyle(fontSize: 10.5)),
              value: s.blackAndWhite,
              onChanged: (val) {
                _applyEnhancementToItem(
                  index: _activeItemIndex,
                  settings: s.copyWith(blackAndWhite: val),
                );
              },
            ),
            SwitchListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: const Text('Auto Contrast & Levels', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              subtitle: const Text('Dynamically stretches faded text and whitens paper', style: TextStyle(fontSize: 10.5)),
              value: s.autoLevels,
              onChanged: (val) {
                _applyEnhancementToItem(
                  index: _activeItemIndex,
                  settings: s.copyWith(autoLevels: val),
                );
              },
            ),
            SwitchListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: const Text('Sharpen Text & Borders', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              subtitle: const Text('Brings back crisp pen strokes and character edges', style: TextStyle(fontSize: 10.5)),
              value: s.sharpen,
              onChanged: (val) {
                _applyEnhancementToItem(
                  index: _activeItemIndex,
                  settings: s.copyWith(sharpen: val),
                );
              },
            ),
            SwitchListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: const Text('Denoise Image', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              subtitle: const Text('Reduces camera grain and JPEG compression artifacts', style: TextStyle(fontSize: 10.5)),
              value: s.denoise,
              onChanged: (val) {
                _applyEnhancementToItem(
                  index: _activeItemIndex,
                  settings: s.copyWith(denoise: val),
                );
              },
            ),
            SwitchListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: const Text('Grayscale Conversion', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              subtitle: const Text('Eliminates background color casts', style: TextStyle(fontSize: 10.5)),
              value: s.grayscale,
              onChanged: (val) {
                _applyEnhancementToItem(
                  index: _activeItemIndex,
                  settings: s.copyWith(grayscale: val),
                );
              },
            ),

            const Divider(height: 16),
            // Brightness & Contrast manual sliders
            Row(
              children: [
                SizedBox(
                  width: 90,
                  child: Text(
                    'Brightness (${(s.brightness * 100).round() > 0 ? '+${(s.brightness * 100).round()}' : '${(s.brightness * 100).round()}'})',
                    style: const TextStyle(fontSize: 11),
                  ),
                ),
                Expanded(
                  child: Slider(
                    value: s.brightness,
                    min: -0.5,
                    max: 0.5,
                    divisions: 20,
                    onChanged: (v) {
                      _applyEnhancementToItem(
                        index: _activeItemIndex,
                        settings: s.copyWith(brightness: v),
                      );
                    },
                  ),
                ),
              ],
            ),
            Row(
              children: [
                SizedBox(
                  width: 90,
                  child: Text(
                    'Contrast (${s.contrast.toStringAsFixed(1)}x)',
                    style: const TextStyle(fontSize: 11),
                  ),
                ),
                Expanded(
                  child: Slider(
                    value: s.contrast,
                    min: 0.5,
                    max: 2.0,
                    divisions: 15,
                    onChanged: (v) {
                      _applyEnhancementToItem(
                        index: _activeItemIndex,
                        settings: s.copyWith(contrast: v),
                      );
                    },
                  ),
                ),
              ],
            ),

            const Divider(height: 16),
            // Transformation & Crop buttons
            const Text('Crop & Rotate (कापा आणि फिरवा):', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ElevatedButton.icon(
                  icon: const Icon(Icons.crop, size: 16),
                  label: const Text('Crop Document (कापा)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: cs.primary,
                    foregroundColor: Colors.white,
                    visualDensity: VisualDensity.compact,
                  ),
                  onPressed: _openPerspectiveCropDialog,
                ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.crop_square, size: 16),
                  label: const Text('Trim 5%', style: TextStyle(fontSize: 11)),
                  onPressed: () {
                    _applyEnhancementToItem(
                      index: _activeItemIndex,
                      settings: s.copyWith(cropLeft: 0.05, cropTop: 0.05, cropRight: 0.05, cropBottom: 0.05),
                    );
                  },
                ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.crop_square, size: 16),
                  label: const Text('Trim 10%', style: TextStyle(fontSize: 11)),
                  onPressed: () {
                    _applyEnhancementToItem(
                      index: _activeItemIndex,
                      settings: s.copyWith(cropLeft: 0.10, cropTop: 0.10, cropRight: 0.10, cropBottom: 0.10),
                    );
                  },
                ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.rotate_left, size: 16),
                  label: const Text('Rotate 90° L', style: TextStyle(fontSize: 11)),
                  onPressed: () => _rotateActiveItem(-90),
                ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.rotate_right, size: 16),
                  label: const Text('Rotate 90° R', style: TextStyle(fontSize: 11)),
                  onPressed: () => _rotateActiveItem(90),
                ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.compare_arrows, size: 16),
                  label: const Text('Before / After', style: TextStyle(fontSize: 11)),
                  onPressed: _openComparisonDialog,
                ),
              ],
            ),

            const SizedBox(height: 12),
            ElevatedButton.icon(
              icon: const Icon(Icons.copy_all, size: 16),
              label: const Text('Apply Current Settings to All Selected Files'),
              style: ElevatedButton.styleFrom(
                backgroundColor: cs.secondaryContainer,
                foregroundColor: cs.onSecondaryContainer,
                visualDensity: VisualDensity.compact,
              ),
              onPressed: () => _applyToAllSelected(s),
            ),
          ],
        ),
      ),
    );
  }

  // ── Section C: A4 Settings ────────────────────────────────────────────────────

  Widget _buildSectionCA4Settings(ColorScheme cs) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.6)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: cs.primaryContainer,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(Icons.settings_outlined, color: cs.primary, size: 20),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Section C: A4 Page Formatting Settings',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Orientation
            const Text('Orientation:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
            const SizedBox(height: 6),
            SegmentedButton<A4Orientation>(
              segments: const [
                ButtonSegment(value: A4Orientation.auto, label: Text('Auto Detect', style: TextStyle(fontSize: 11))),
                ButtonSegment(value: A4Orientation.portrait, label: Text('Portrait (210×297)', style: TextStyle(fontSize: 11))),
                ButtonSegment(value: A4Orientation.landscape, label: Text('Landscape (297×210)', style: TextStyle(fontSize: 11))),
              ],
              selected: {_a4Settings.orientation},
              onSelectionChanged: (set) {
                setState(() => _a4Settings = _a4Settings.copyWith(orientation: set.first));
                _triggerPdfRegeneration();
              },
            ),
            const SizedBox(height: 12),

            // Layout
            const Text('Multi-Photo Layout:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
            const SizedBox(height: 6),
            SegmentedButton<A4Layout>(
              segments: const [
                ButtonSegment(value: A4Layout.onePerPage, label: Text('1 Photo / Page', style: TextStyle(fontSize: 11))),
                ButtonSegment(value: A4Layout.twoPerPage, label: Text('2 Photos / Page', style: TextStyle(fontSize: 11))),
                ButtonSegment(value: A4Layout.fourPerPage, label: Text('4 Photos / Page', style: TextStyle(fontSize: 11))),
              ],
              selected: {_a4Settings.layout},
              onSelectionChanged: (set) {
                setState(() => _a4Settings = _a4Settings.copyWith(layout: set.first));
                _triggerPdfRegeneration();
              },
            ),
            const SizedBox(height: 12),

            // Margins
            const Text('Margins:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
            const SizedBox(height: 6),
            SegmentedButton<A4MarginPreset>(
              segments: const [
                ButtonSegment(value: A4MarginPreset.none, label: Text('None (0mm)', style: TextStyle(fontSize: 11))),
                ButtonSegment(value: A4MarginPreset.small, label: Text('Small (5mm)', style: TextStyle(fontSize: 11))),
                ButtonSegment(value: A4MarginPreset.normal, label: Text('Normal (10mm)', style: TextStyle(fontSize: 11))),
              ],
              selected: {_a4Settings.marginPreset},
              onSelectionChanged: (set) {
                setState(() => _a4Settings = _a4Settings.copyWith(marginPreset: set.first));
                _triggerPdfRegeneration();
              },
            ),
            const SizedBox(height: 12),

            // Fit Mode
            const Text('Fit Mode:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
            const SizedBox(height: 6),
            SegmentedButton<A4FitMode>(
              segments: const [
                ButtonSegment(value: A4FitMode.fit, label: Text('Fit (Preserve Ratio)', style: TextStyle(fontSize: 11))),
                ButtonSegment(value: A4FitMode.fill, label: Text('Fill Page', style: TextStyle(fontSize: 11))),
                ButtonSegment(value: A4FitMode.actual, label: Text('Actual Size', style: TextStyle(fontSize: 11))),
              ],
              selected: {_a4Settings.fitMode},
              onSelectionChanged: (set) {
                setState(() => _a4Settings = _a4Settings.copyWith(fitMode: set.first));
                _triggerPdfRegeneration();
              },
            ),
          ],
        ),
      ),
    );
  }

  // ── Section E: Preview & Export ───────────────────────────────────────────────

  Widget _buildSectionEPreviewAndExport(ColorScheme cs) {
    final selectedCount = _items.where((it) => it.isSelected).length;

    // Estimate output pages based on layout
    final int estimatedPages;
    if (_a4Settings.layout == A4Layout.twoPerPage) {
      estimatedPages = (selectedCount / 2).ceil();
    } else if (_a4Settings.layout == A4Layout.fourPerPage) {
      estimatedPages = (selectedCount / 4).ceil();
    } else {
      estimatedPages = selectedCount;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Action Bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            alignment: WrapAlignment.spaceBetween,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.picture_as_pdf, color: cs.primary, size: 22),
                  const SizedBox(width: 8),
                  Text(
                    'Final A4 Output Preview ($selectedCount items • ~$estimatedPages A4 page${estimatedPages == 1 ? '' : 's'})',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    icon: const Icon(Icons.refresh, size: 20),
                    tooltip: 'Refresh Preview',
                    visualDensity: VisualDensity.compact,
                    onPressed: _triggerPdfRegeneration,
                  ),
                ],
              ),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  OutlinedButton.icon(
                    icon: const Icon(Icons.folder_shared_outlined, size: 16),
                    label: const Text('Save to Customer'),
                    style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact),
                    onPressed: _generatedPdfBytes == null ? null : _openSaveToCustomerDialog,
                  ),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.download, size: 16),
                    label: const Text('Download PDF'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: cs.primary,
                      foregroundColor: Colors.white,
                      visualDensity: VisualDensity.compact,
                    ),
                    onPressed: _generatedPdfBytes == null ? null : _handleDownloadPdf,
                  ),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.print, size: 16),
                    label: const Text('Print Document'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0F2D69),
                      foregroundColor: Colors.white,
                      visualDensity: VisualDensity.compact,
                    ),
                    onPressed: _generatedPdfBytes == null ? null : _handleDirectPrint,
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Live PDF Preview Container
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: _buildPdfPreviewWidget(cs),
          ),
        ),
      ],
    );
  }

  Widget _buildPdfPreviewWidget(ColorScheme cs) {
    if (_isGeneratingPdf) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: cs.primary),
            const SizedBox(height: 16),
            const Text('Rendering A4 PDF pages with enhanced clarity...', style: TextStyle(fontSize: 13)),
          ],
        ),
      );
    }

    if (_generatedPdfBytes == null || _items.where((it) => it.isSelected).isEmpty) {
      return Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.picture_as_pdf_outlined, size: 56, color: Colors.grey.shade400),
              const SizedBox(height: 12),
              Text(
                'No documents selected for A4 conversion.',
                style: TextStyle(fontSize: 14, color: Colors.grey.shade600, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              Text(
                'Upload photos or documents on the left and select items to preview.',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
              ),
            ],
          ),
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: PdfPreview(
        build: (_) async => _generatedPdfBytes!,
        canChangeOrientation: false,
        canChangePageFormat: false,
        canDebug: false,
        allowSharing: true,
        allowPrinting: true,
        pdfFileName: 'Siya_Document_A4_${DateTime.now().millisecondsSinceEpoch}.pdf',
      ),
    );
  }

  Widget _buildPrinterTipBanner(ColorScheme cs) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.amber.shade300),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.print_outlined, color: Colors.amber.shade900, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Physical Printer Guidance:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.amber.shade900),
                ),
                const SizedBox(height: 2),
                Text(
                  'In your browser or system print dialog, make sure Paper Size is set to "A4" (210×297 mm) and Margins are set to "Default" or "None" for accurate physical page scaling.',
                  style: TextStyle(fontSize: 11, color: Colors.brown.shade800),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyUploadPrompt(ColorScheme cs) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.upload_file, size: 50, color: cs.primary),
            const SizedBox(height: 16),
            const Text(
              'No Documents Uploaded',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            const Text(
              'Go to the Upload tab to add WhatsApp photos or PDFs first.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => _tabController.animateTo(0),
              child: const Text('Go to Upload'),
            ),
          ],
        ),
      ),
    );
  }
}
