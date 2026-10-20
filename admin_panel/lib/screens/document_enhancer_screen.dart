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
  DocumentMode _documentMode = DocumentMode.general;

  // General Document Items
  final List<DocumentToolItem> _items = [];
  int _activeItemIndex = 0;

  // Dedicated Aadhaar Front & Back Items
  DocumentToolItem? _aadhaarFrontItem;
  DocumentToolItem? _aadhaarBackItem;
  AadhaarPageSettings _aadhaarSettings = const AadhaarPageSettings();
  int _aadhaarActiveSlot = 0; // 0 = Front, 1 = Back

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

  bool get _hasAnyDocuments =>
      _documentMode == DocumentMode.general
          ? _items.isNotEmpty
          : (_aadhaarFrontItem != null || _aadhaarBackItem != null);

  DocumentToolItem? get _activeAadhaarItem =>
      _aadhaarActiveSlot == 0 ? _aadhaarFrontItem : _aadhaarBackItem;

  DocumentToolItem? get _activeItem {
    if (_documentMode == DocumentMode.aadhaarFrontBack) {
      return _activeAadhaarItem;
    }
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
          setState(() => _statusMessage = 'Analyzing & detecting orientation for ${file.name}...');
          try {
            final meta = DocumentImageProcessor.analyzeImage(bytes);
            final bounds = DocumentImageProcessor.detectDocumentBounds(bytes, isIdCard: false);
            final bool shouldAutoStraighten = bounds.isTilted || bounds.hasPerspectiveDistortion;

            DocumentEnhanceSettings initSettings = const DocumentEnhanceSettings();
            if (shouldAutoStraighten) {
              initSettings = initSettings.copyWith(
                perspectiveCorners: bounds.corners,
                cropLeft: bounds.cropLeft,
                cropTop: bounds.cropTop,
                cropRight: bounds.cropRight,
                cropBottom: bounds.cropBottom,
              );
            }

            String? warning = meta['warning'];
            if (bounds.needsManualAdjustment) {
              const warnManual = 'कागदपत्राचे कोपरे अस्पष्ट आहेत, कृपया "Adjust Corners" द्वारे तपासा.';
              warning = warning != null ? '$warning\n$warnManual' : warnManual;
            }

            final item = DocumentToolItem(
              id: 'img_${DateTime.now().millisecondsSinceEpoch}_${_items.length}',
              name: file.name,
              fileSize: bytes.length,
              mimeType: 'image/$ext',
              originalBytes: bytes,
              thumbnailBytes: meta['thumbnail'],
              width: meta['width'] ?? 0,
              height: meta['height'] ?? 0,
              qualityWarning: warning,
              settings: initSettings,
            );

            // Automatically straighten if tilted or perspective skewed
            if (shouldAutoStraighten) {
              try {
                final rectified = await DocumentImageProcessor.enhanceDocument(
                  originalBytes: bytes,
                  settings: initSettings,
                );
                final rectifiedMeta = DocumentImageProcessor.analyzeImage(rectified);
                item.processedBytes = rectified;
                item.thumbnailBytes = rectifiedMeta['thumbnail'];
                item.width = rectifiedMeta['width'] ?? item.width;
                item.height = rectifiedMeta['height'] ?? item.height;
                item.status = DocumentProcessingStatus.done;
              } catch (_) {}
            }

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
    if (!_hasAnyDocuments) return;
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
                if (_documentMode == DocumentMode.aadhaarFrontBack) {
                  _aadhaarFrontItem = null;
                  _aadhaarBackItem = null;
                  _aadhaarActiveSlot = 0;
                } else {
                  _items.clear();
                  _activeItemIndex = 0;
                }
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

  Future<void> _pickAadhaarSlot(int slot) async {
    setState(() {
      _errorMessage = null;
      _statusMessage = 'Selecting Aadhaar ${slot == 0 ? "Front" : "Back"} file...';
    });

    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: false,
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png', 'webp'],
        withData: true,
      );

      if (result == null || result.files.isEmpty) {
        setState(() => _statusMessage = null);
        return;
      }

      final file = result.files.first;
      final bytes = file.bytes;
      if (bytes == null || bytes.isEmpty) return;

      final ext = (file.extension ?? '').toLowerCase();
      final isPdf = ext == 'pdf';

      Uint8List imageBytes;
      int width = 0;
      int height = 0;
      Uint8List? thumb;
      String? warning;

      if (isPdf) {
        setState(() => _statusMessage = 'Extracting page from PDF...');
        final pdfPages = await DocumentA4PdfService.extractPagesFromPdf(
          fileId: 'aadhaar_${slot == 0 ? "front" : "back"}_${DateTime.now().millisecondsSinceEpoch}',
          fileName: file.name,
          pdfBytes: bytes,
        );
        if (pdfPages.isEmpty) throw Exception('No readable pages found in PDF');

        // Smart multi-page check: If 2-page PDF is uploaded in Front slot and Back is empty, place both!
        if (slot == 0 && pdfPages.length >= 2 && _aadhaarBackItem == null) {
          final frontPage = pdfPages[0];
          final backPage = pdfPages[1];
          setState(() {
            _aadhaarFrontItem = frontPage;
            _aadhaarBackItem = backPage;
            _aadhaarActiveSlot = 0;
            _statusMessage = null;
          });
          _showSnack('Loaded Page 1 as Front and Page 2 as Back side!');
          _triggerPdfRegeneration();
          return;
        }

        final page = pdfPages.first;
        imageBytes = page.originalBytes;
        width = page.width;
        height = page.height;
        thumb = page.thumbnailBytes;
        warning = page.qualityWarning;
      } else {
        imageBytes = bytes;
        final meta = DocumentImageProcessor.analyzeImage(bytes);
        width = meta['width'] ?? 0;
        height = meta['height'] ?? 0;
        thumb = meta['thumbnail'];
        warning = meta['warning'];
      }

      final bounds = DocumentImageProcessor.detectDocumentBounds(imageBytes, isIdCard: true);
      final bool shouldAutoStraighten = bounds.isTilted || bounds.hasPerspectiveDistortion;

      DocumentEnhanceSettings initSettings = const DocumentEnhanceSettings();
      if (shouldAutoStraighten) {
        initSettings = initSettings.copyWith(
          perspectiveCorners: bounds.corners,
          cropLeft: bounds.cropLeft,
          cropTop: bounds.cropTop,
          cropRight: bounds.cropRight,
          cropBottom: bounds.cropBottom,
        );
      }

      if (bounds.needsManualAdjustment) {
        const warnManual = 'कागदपत्राचे कोपरे अस्पष्ट आहेत, कृपया "Adjust Corners" द्वारे तपासा.';
        warning = warning != null ? '$warning\n$warnManual' : warnManual;
      }

      final item = DocumentToolItem(
        id: 'aadhaar_${slot == 0 ? "front" : "back"}_${DateTime.now().millisecondsSinceEpoch}',
        name: '${slot == 0 ? "Aadhaar Front" : "Aadhaar Back"} (${file.name})',
        fileSize: imageBytes.length,
        mimeType: isPdf ? 'image/png' : 'image/$ext',
        originalBytes: imageBytes,
        thumbnailBytes: thumb,
        width: width,
        height: height,
        qualityWarning: warning,
        settings: initSettings,
      );

      if (shouldAutoStraighten) {
        try {
          final rectified = await DocumentImageProcessor.enhanceDocument(
            originalBytes: imageBytes,
            settings: initSettings,
          );
          final rectifiedMeta = DocumentImageProcessor.analyzeImage(rectified);
          item.processedBytes = rectified;
          item.thumbnailBytes = rectifiedMeta['thumbnail'];
          item.width = rectifiedMeta['width'] ?? item.width;
          item.height = rectifiedMeta['height'] ?? item.height;
          item.status = DocumentProcessingStatus.done;
        } catch (_) {}
      }

      setState(() {
        if (slot == 0) {
          _aadhaarFrontItem = item;
          _aadhaarActiveSlot = 0;
        } else {
          _aadhaarBackItem = item;
          _aadhaarActiveSlot = 1;
        }
        _statusMessage = null;
      });

      _showSnack('${slot == 0 ? "Front" : "Back"} side uploaded successfully!');
      _triggerPdfRegeneration();
    } catch (e) {
      setState(() {
        _statusMessage = null;
        _errorMessage = 'Error loading Aadhaar file: $e';
      });
    }
  }

  void _removeAadhaarSlot(int slot) {
    setState(() {
      if (slot == 0) {
        _aadhaarFrontItem = null;
      } else {
        _aadhaarBackItem = null;
      }
    });
    _showSnack('${slot == 0 ? "Front" : "Back"} side removed.');
    _triggerPdfRegeneration();
  }

  void _resetAadhaarSlotToOriginal(int slot) {
    final item = slot == 0 ? _aadhaarFrontItem : _aadhaarBackItem;
    if (item == null) return;
    setState(() {
      item.settings = const DocumentEnhanceSettings();
      item.processedBytes = null;
      final meta = DocumentImageProcessor.analyzeImage(item.originalBytes);
      item.thumbnailBytes = meta['thumbnail'];
      item.width = meta['width'] ?? item.width;
      item.height = meta['height'] ?? item.height;
      item.status = DocumentProcessingStatus.idle;
    });
    _showSnack('${slot == 0 ? "Front" : "Back"} reset to original.');
    _triggerPdfRegeneration();
  }

  Future<void> _applyEnhancementToAadhaarSlot({
    required int slot,
    required DocumentEnhanceSettings settings,
    bool autoRegenPdf = true,
  }) async {
    final item = slot == 0 ? _aadhaarFrontItem : _aadhaarBackItem;
    if (item == null) return;

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

  Future<void> _applyAadhaarSettingsToBoth(DocumentEnhanceSettings settings) async {
    if (_aadhaarFrontItem != null) {
      await _applyEnhancementToAadhaarSlot(slot: 0, settings: settings, autoRegenPdf: false);
    }
    if (_aadhaarBackItem != null) {
      await _applyEnhancementToAadhaarSlot(slot: 1, settings: settings, autoRegenPdf: false);
    }
    _showSnack('Applied enhancement settings to both Front & Back.');
    _triggerPdfRegeneration();
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
    if (_documentMode == DocumentMode.aadhaarFrontBack) {
      _resetAadhaarSlotToOriginal(_aadhaarActiveSlot);
      return;
    }
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
    if (_documentMode == DocumentMode.aadhaarFrontBack) {
      final item = _activeAadhaarItem;
      if (item == null) return;
      final newAngle = (item.settings.rotationAngle + deltaAngle) % 360;
      final updated = item.settings.copyWith(rotationAngle: newAngle >= 0 ? newAngle : newAngle + 360);
      _applyEnhancementToAadhaarSlot(slot: _aadhaarActiveSlot, settings: updated);
      return;
    }
    final item = _activeItem;
    if (item == null) return;
    final newAngle = (item.settings.rotationAngle + deltaAngle) % 360;
    final updated = item.settings.copyWith(rotationAngle: newAngle >= 0 ? newAngle : newAngle + 360);
    _applyEnhancementToItem(index: _activeItemIndex, settings: updated);
  }

  // ── Auto Crop Handlers ────────────────────────────────────────────────────────

  Future<void> _autoCropItem({required int index, bool autoRegenPdf = true}) async {
    if (index < 0 || index >= _items.length) return;
    final item = _items[index];

    setState(() {
      _isProcessingImage = true;
      _statusMessage = 'Auto-detecting document boundaries for ${item.name}...';
    });

    try {
      final bounds = DocumentImageProcessor.detectDocumentBounds(item.originalBytes, isIdCard: false);
      final newSettings = item.settings.copyWith(
        cropLeft: bounds.cropLeft,
        cropTop: bounds.cropTop,
        cropRight: bounds.cropRight,
        cropBottom: bounds.cropBottom,
        perspectiveCorners: bounds.corners,
      );

      await _applyEnhancementToItem(index: index, settings: newSettings, autoRegenPdf: autoRegenPdf);

      _showSnack(
        bounds.hasCrop
            ? 'Auto-cropped "${item.name}" (L:${(bounds.cropLeft * 100).round()}% T:${(bounds.cropTop * 100).round()}% R:${(bounds.cropRight * 100).round()}% B:${(bounds.cropBottom * 100).round()}%)'
            : '"${item.name}" already fills the full frame.',
      );
    } catch (e) {
      _showSnack('Auto crop error: $e', isError: true);
    } finally {
      if (mounted) {
        setState(() {
          _isProcessingImage = false;
          _statusMessage = null;
        });
      }
    }
  }

  Future<void> _autoCropAadhaarSlot(int slot) async {
    final item = slot == 0 ? _aadhaarFrontItem : _aadhaarBackItem;
    if (item == null) return;

    setState(() {
      _isProcessingImage = true;
      _statusMessage = 'Auto-detecting Aadhaar ${slot == 0 ? "Front" : "Back"} boundaries...';
    });

    try {
      final bounds = DocumentImageProcessor.detectDocumentBounds(item.originalBytes, isIdCard: true);
      final newSettings = item.settings.copyWith(
        cropLeft: bounds.cropLeft,
        cropTop: bounds.cropTop,
        cropRight: bounds.cropRight,
        cropBottom: bounds.cropBottom,
        perspectiveCorners: bounds.corners,
      );

      await _applyEnhancementToAadhaarSlot(slot: slot, settings: newSettings, autoRegenPdf: true);

      _showSnack(
        bounds.hasCrop
            ? 'Auto-cropped Aadhaar ${slot == 0 ? "Front" : "Back"} card (L:${(bounds.cropLeft * 100).round()}% T:${(bounds.cropTop * 100).round()}% R:${(bounds.cropRight * 100).round()}% B:${(bounds.cropBottom * 100).round()}%)'
            : 'Aadhaar ${slot == 0 ? "Front" : "Back"} already fills the full frame.',
      );
    } catch (e) {
      _showSnack('Auto crop error: $e', isError: true);
    } finally {
      if (mounted) {
        setState(() {
          _isProcessingImage = false;
          _statusMessage = null;
        });
      }
    }
  }

  Future<void> _autoCropBothAadhaar() async {
    if (_aadhaarFrontItem == null && _aadhaarBackItem == null) return;

    setState(() {
      _isProcessingImage = true;
      _statusMessage = 'Auto-cropping both Aadhaar Front & Back cards...';
    });

    try {
      if (_aadhaarFrontItem != null) {
        final bFront = DocumentImageProcessor.detectDocumentBounds(_aadhaarFrontItem!.originalBytes, isIdCard: true);
        final sFront = _aadhaarFrontItem!.settings.copyWith(
          cropLeft: bFront.cropLeft,
          cropTop: bFront.cropTop,
          cropRight: bFront.cropRight,
          cropBottom: bFront.cropBottom,
          perspectiveCorners: bFront.corners,
        );
        await _applyEnhancementToAadhaarSlot(slot: 0, settings: sFront, autoRegenPdf: false);
      }

      if (_aadhaarBackItem != null) {
        final bBack = DocumentImageProcessor.detectDocumentBounds(_aadhaarBackItem!.originalBytes, isIdCard: true);
        final sBack = _aadhaarBackItem!.settings.copyWith(
          cropLeft: bBack.cropLeft,
          cropTop: bBack.cropTop,
          cropRight: bBack.cropRight,
          cropBottom: bBack.cropBottom,
          perspectiveCorners: bBack.corners,
        );
        await _applyEnhancementToAadhaarSlot(slot: 1, settings: sBack, autoRegenPdf: false);
      }

      _showSnack('Auto-cropped both Aadhaar Front & Back cards successfully!');
      _triggerPdfRegeneration();
    } catch (e) {
      _showSnack('Auto crop error: $e', isError: true);
    } finally {
      if (mounted) {
        setState(() {
          _isProcessingImage = false;
          _statusMessage = null;
        });
      }
    }
  }

  Future<void> _autoCropActiveItem() async {
    if (_documentMode == DocumentMode.aadhaarFrontBack) {
      await _autoCropAadhaarSlot(_aadhaarActiveSlot);
    } else {
      await _autoCropItem(index: _activeItemIndex);
    }
  }

  Future<void> _autoCropAllSelected() async {
    if (_documentMode == DocumentMode.aadhaarFrontBack) {
      await _autoCropBothAadhaar();
      return;
    }

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
      _statusMessage = 'Auto-cropping ${selectedIndices.length} document(s)...';
    });

    try {
      for (final idx in selectedIndices) {
        final item = _items[idx];
        final bounds = DocumentImageProcessor.detectDocumentBounds(item.originalBytes, isIdCard: false);
        final newSettings = item.settings.copyWith(
          cropLeft: bounds.cropLeft,
          cropTop: bounds.cropTop,
          cropRight: bounds.cropRight,
          cropBottom: bounds.cropBottom,
          perspectiveCorners: bounds.corners,
        );
        await _applyEnhancementToItem(index: idx, settings: newSettings, autoRegenPdf: false);
      }

      _showSnack('Auto-cropped all ${selectedIndices.length} document(s) successfully!');
      _triggerPdfRegeneration();
    } catch (e) {
      _showSnack('Auto crop error: $e', isError: true);
    } finally {
      if (mounted) {
        setState(() {
          _isProcessingImage = false;
          _statusMessage = null;
        });
      }
    }
  }

  // ── Auto Straighten & Deskew Handlers (वाकडे डॉक्युमेंट सरळ करणे) ──────────────────────────

  Future<void> _autoStraightenItem({required int index, bool autoRegenPdf = true}) async {
    if (index < 0 || index >= _items.length) return;
    final item = _items[index];

    setState(() {
      _isProcessingImage = true;
      _statusMessage = 'Auto-detecting slant & straightening "${item.name}"...';
    });

    try {
      final bounds = DocumentImageProcessor.detectDocumentBounds(item.originalBytes, isIdCard: false);
      final DocumentEnhanceSettings newSettings;
      if (bounds.isTilted) {
        newSettings = item.settings.copyWith(
          perspectiveCorners: bounds.corners,
          fineRotationAngle: 0.0,
          cropLeft: bounds.cropLeft,
          cropTop: bounds.cropTop,
          cropRight: bounds.cropRight,
          cropBottom: bounds.cropBottom,
        );
      } else {
        newSettings = item.settings.copyWith(
          cropLeft: bounds.cropLeft,
          cropTop: bounds.cropTop,
          cropRight: bounds.cropRight,
          cropBottom: bounds.cropBottom,
          perspectiveCorners: bounds.corners,
        );
      }

      await _applyEnhancementToItem(index: index, settings: newSettings, autoRegenPdf: autoRegenPdf);

      _showSnack(
        bounds.isTilted
            ? 'वाकडे डॉक्युमेंट सरळ केले! (${bounds.skewAngle.abs().toStringAsFixed(1)}° Deskew)'
            : 'डॉक्युमेंट आधीच सरळ आहे. (Document is already level)',
      );
    } catch (e) {
      _showSnack('Straighten error: $e', isError: true);
    } finally {
      if (mounted) {
        setState(() {
          _isProcessingImage = false;
          _statusMessage = null;
        });
      }
    }
  }

  Future<void> _autoStraightenAadhaarSlot(int slot) async {
    final item = slot == 0 ? _aadhaarFrontItem : _aadhaarBackItem;
    if (item == null) return;

    setState(() {
      _isProcessingImage = true;
      _statusMessage = 'Straightening Aadhaar ${slot == 0 ? "Front" : "Back"} card...';
    });

    try {
      final bounds = DocumentImageProcessor.detectDocumentBounds(item.originalBytes, isIdCard: true);
      final DocumentEnhanceSettings newSettings;
      if (bounds.isTilted) {
        newSettings = item.settings.copyWith(
          perspectiveCorners: bounds.corners,
          fineRotationAngle: 0.0,
          cropLeft: bounds.cropLeft,
          cropTop: bounds.cropTop,
          cropRight: bounds.cropRight,
          cropBottom: bounds.cropBottom,
        );
      } else {
        newSettings = item.settings.copyWith(
          cropLeft: bounds.cropLeft,
          cropTop: bounds.cropTop,
          cropRight: bounds.cropRight,
          cropBottom: bounds.cropBottom,
          perspectiveCorners: bounds.corners,
        );
      }

      await _applyEnhancementToAadhaarSlot(slot: slot, settings: newSettings, autoRegenPdf: true);

      _showSnack(
        bounds.isTilted
            ? 'वाकडे आधार कार्ड सरळ केले! (${bounds.skewAngle.abs().toStringAsFixed(1)}° Deskew)'
            : 'आधार कार्ड आधीच सरळ आहे.',
      );
    } catch (e) {
      _showSnack('Straighten error: $e', isError: true);
    } finally {
      if (mounted) {
        setState(() {
          _isProcessingImage = false;
          _statusMessage = null;
        });
      }
    }
  }

  Future<void> _autoStraightenBothAadhaar() async {
    if (_aadhaarFrontItem == null && _aadhaarBackItem == null) return;

    setState(() {
      _isProcessingImage = true;
      _statusMessage = 'Auto-straightening both Aadhaar Front & Back cards...';
    });

    try {
      if (_aadhaarFrontItem != null) {
        final bFront = DocumentImageProcessor.detectDocumentBounds(_aadhaarFrontItem!.originalBytes, isIdCard: true);
        final sFront = _aadhaarFrontItem!.settings.copyWith(
          perspectiveCorners: bFront.isTilted ? bFront.corners : _aadhaarFrontItem!.settings.perspectiveCorners,
          fineRotationAngle: bFront.isTilted ? 0.0 : _aadhaarFrontItem!.settings.fineRotationAngle,
          cropLeft: bFront.cropLeft,
          cropTop: bFront.cropTop,
          cropRight: bFront.cropRight,
          cropBottom: bFront.cropBottom,
        );
        await _applyEnhancementToAadhaarSlot(slot: 0, settings: sFront, autoRegenPdf: false);
      }

      if (_aadhaarBackItem != null) {
        final bBack = DocumentImageProcessor.detectDocumentBounds(_aadhaarBackItem!.originalBytes, isIdCard: true);
        final sBack = _aadhaarBackItem!.settings.copyWith(
          perspectiveCorners: bBack.isTilted ? bBack.corners : _aadhaarBackItem!.settings.perspectiveCorners,
          fineRotationAngle: bBack.isTilted ? 0.0 : _aadhaarBackItem!.settings.fineRotationAngle,
          cropLeft: bBack.cropLeft,
          cropTop: bBack.cropTop,
          cropRight: bBack.cropRight,
          cropBottom: bBack.cropBottom,
        );
        await _applyEnhancementToAadhaarSlot(slot: 1, settings: sBack, autoRegenPdf: false);
      }

      _showSnack('दोन्ही आधार कार्ड्स सरळ व क्रॉप केले! (Straightened both cards)');
      _triggerPdfRegeneration();
    } catch (e) {
      _showSnack('Straighten error: $e', isError: true);
    } finally {
      if (mounted) {
        setState(() {
          _isProcessingImage = false;
          _statusMessage = null;
        });
      }
    }
  }

  Future<void> _autoStraightenActiveItem() async {
    if (_documentMode == DocumentMode.aadhaarFrontBack) {
      await _autoStraightenAadhaarSlot(_aadhaarActiveSlot);
    } else {
      await _autoStraightenItem(index: _activeItemIndex);
    }
  }

  void _adjustFineRotation(double delta) {
    final item = _activeItem;
    if (item == null) return;
    final currentAngle = item.settings.fineRotationAngle;
    final newAngle = (currentAngle + delta).clamp(-45.0, 45.0);
    final updated = item.settings.copyWith(fineRotationAngle: double.parse(newAngle.toStringAsFixed(1)));
    if (_documentMode == DocumentMode.aadhaarFrontBack) {
      _applyEnhancementToAadhaarSlot(slot: _aadhaarActiveSlot, settings: updated);
    } else {
      _applyEnhancementToItem(index: _activeItemIndex, settings: updated);
    }
  }

  void _setFineRotation(double angle) {
    final item = _activeItem;
    if (item == null) return;
    final clamped = angle.clamp(-45.0, 45.0);
    final updated = item.settings.copyWith(fineRotationAngle: double.parse(clamped.toStringAsFixed(1)));
    if (_documentMode == DocumentMode.aadhaarFrontBack) {
      _applyEnhancementToAadhaarSlot(slot: _aadhaarActiveSlot, settings: updated);
    } else {
      _applyEnhancementToItem(index: _activeItemIndex, settings: updated);
    }
  }

  // ── PDF Generation ────────────────────────────────────────────────────────────

  Future<void> _triggerPdfRegeneration() async {
    if (_documentMode == DocumentMode.aadhaarFrontBack) {
      if (_aadhaarFrontItem == null && _aadhaarBackItem == null) {
        setState(() {
          _generatedPdfBytes = null;
          _isGeneratingPdf = false;
        });
        return;
      }

      setState(() => _isGeneratingPdf = true);

      try {
        final pdfBytes = await DocumentA4PdfService.generateAadhaarA4Pdf(
          frontItem: _aadhaarFrontItem,
          backItem: _aadhaarBackItem,
          settings: _aadhaarSettings,
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
            _errorMessage = 'Aadhaar PDF Generation error: $e';
          });
        }
      }
      return;
    }

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
        defaultDocName: _documentMode == DocumentMode.aadhaarFrontBack
            ? 'Aadhaar_Card_Front_Back'
            : (_activeItem?.name.replaceAll(RegExp(r'\.[a-zA-Z0-9]+$'), '') ?? 'Enhanced_Document'),
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

  Future<void> _autoPerspectiveCorrectionActiveItem() async {
    final item = _activeItem;
    if (item == null) return;

    setState(() {
      _isProcessingImage = true;
      _statusMessage = 'Detecting 4 corners & perspective transformation for ${item.name}...';
    });

    try {
      final isId = _documentMode == DocumentMode.aadhaarFrontBack;
      final bounds = DocumentImageProcessor.detectDocumentBounds(item.originalBytes, isIdCard: isId);

      if (bounds.needsManualAdjustment) {
        _showSnack('कागदपत्राचे कोपरे अस्पष्ट आहेत, कृपया "Adjust Corners" द्वारे सेट करा.');
        await _openPerspectiveCropDialog(forcePerspectiveMode: true);
        return;
      }

      final newSettings = item.settings.copyWith(
        perspectiveCorners: bounds.corners,
        cropLeft: bounds.cropLeft,
        cropTop: bounds.cropTop,
        cropRight: bounds.cropRight,
        cropBottom: bounds.cropBottom,
        fineRotationAngle: 0.0,
      );

      if (_documentMode == DocumentMode.aadhaarFrontBack) {
        await _applyEnhancementToAadhaarSlot(slot: _aadhaarActiveSlot, settings: newSettings, autoRegenPdf: true);
      } else {
        await _applyEnhancementToItem(index: _activeItemIndex, settings: newSettings, autoRegenPdf: true);
      }

      _showSnack(
        bounds.hasPerspectiveDistortion
            ? 'कोनातून काढलेला फोटो सरळ केला! (Perspective Corrected & Rectified)'
            : (bounds.isTilted
                ? 'वाकडे डॉक्युमेंट सरळ केले! (${bounds.skewAngle.abs().toStringAsFixed(1)}° Deskew)'
                : 'डॉक्युमेंट आधीच सरळ आहे. (Perspective already level)'),
      );
    } catch (e) {
      _showSnack('Perspective correction error: $e', isError: true);
    } finally {
      if (mounted) {
        setState(() {
          _isProcessingImage = false;
          _statusMessage = null;
        });
      }
    }
  }

  Future<void> _openPerspectiveCropDialog({bool forcePerspectiveMode = false}) async {
    final item = _activeItem;
    if (item == null) return;

    DocumentEnhanceSettings initial = item.settings;
    if (forcePerspectiveMode && (initial.perspectiveCorners == null || initial.perspectiveCorners!.isEmpty)) {
      final isId = _documentMode == DocumentMode.aadhaarFrontBack;
      final bounds = DocumentImageProcessor.detectDocumentBounds(item.originalBytes, isIdCard: isId);
      initial = initial.copyWith(perspectiveCorners: bounds.corners);
    }

    final result = await showDialog<DocumentEnhanceSettings>(
      context: context,
      builder: (_) => DocPerspectiveCropDialog(
        imageBytes: item.originalBytes,
        initialSettings: initial,
        startInPerspectiveMode: forcePerspectiveMode,
      ),
    );

    if (result != null) {
      if (_documentMode == DocumentMode.aadhaarFrontBack) {
        _applyEnhancementToAadhaarSlot(slot: _aadhaarActiveSlot, settings: result);
      } else {
        _applyEnhancementToItem(index: _activeItemIndex, settings: result);
      }
    }
  }

  Future<void> _openAdjustCornersDialog() => _openPerspectiveCropDialog(forcePerspectiveMode: true);

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
          if (_hasAnyDocuments) ...[
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
                if (_hasAnyDocuments) ...[
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
              if (_hasAnyDocuments) _buildPrinterTipBanner(cs),
            ],
          ),
        ),
        // Tab 2: Enhance & A4
        SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: !_hasAnyDocuments
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
          child: !_hasAnyDocuments ? _buildEmptyUploadPrompt(cs) : _buildSectionEPreviewAndExport(cs),
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
            // 1. Document Mode Selector (General vs Aadhaar Front & Back)
            _buildDocumentModeSelector(cs),

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

            if (_documentMode == DocumentMode.aadhaarFrontBack) ...[
              _buildAadhaarUploadPanels(cs),
            ] else ...[
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
          ],
        ),
      ),
    );
  }

  Widget _buildDocumentModeSelector(ColorScheme cs) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: () {
                if (_documentMode != DocumentMode.general) {
                  setState(() => _documentMode = DocumentMode.general);
                  _triggerPdfRegeneration();
                }
              },
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 8),
                decoration: BoxDecoration(
                  color: _documentMode == DocumentMode.general ? cs.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: _documentMode == DocumentMode.general
                      ? [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 4, offset: const Offset(0, 1))]
                      : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.description_outlined,
                      size: 16,
                      color: _documentMode == DocumentMode.general ? Colors.white : cs.onSurface,
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        'General Document',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: _documentMode == DocumentMode.general ? Colors.white : cs.onSurface,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: InkWell(
              onTap: () {
                if (_documentMode != DocumentMode.aadhaarFrontBack) {
                  setState(() => _documentMode = DocumentMode.aadhaarFrontBack);
                  _triggerPdfRegeneration();
                }
              },
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 8),
                decoration: BoxDecoration(
                  color: _documentMode == DocumentMode.aadhaarFrontBack ? cs.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: _documentMode == DocumentMode.aadhaarFrontBack
                      ? [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 4, offset: const Offset(0, 1))]
                      : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.badge_outlined,
                      size: 16,
                      color: _documentMode == DocumentMode.aadhaarFrontBack ? Colors.white : cs.onSurface,
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        'Aadhaar Card — Front & Back',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: _documentMode == DocumentMode.aadhaarFrontBack ? Colors.white : cs.onSurface,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAadhaarUploadPanels(ColorScheme cs) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.blue.shade200),
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline, color: Colors.blue.shade800, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Upload Aadhaar Front & Back separately. Both will automatically be centered on 1 A4 page with optimal card dimensions.',
                  style: TextStyle(fontSize: 11, color: Colors.blue.shade900),
                ),
              ),
            ],
          ),
        ),
        if (_aadhaarFrontItem != null || _aadhaarBackItem != null) ...[
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ElevatedButton.icon(
                icon: const Icon(Icons.auto_awesome, size: 16),
                label: const Text('Auto Crop Both Cards', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F2D69),
                  foregroundColor: Colors.white,
                  visualDensity: VisualDensity.compact,
                ),
                onPressed: _autoCropBothAadhaar,
              ),
              ElevatedButton.icon(
                icon: const Icon(Icons.straighten, size: 16),
                label: const Text('Auto Straighten Both (दोन्ही सरळ करा)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal.shade700,
                  foregroundColor: Colors.white,
                  visualDensity: VisualDensity.compact,
                ),
                onPressed: _autoStraightenBothAadhaar,
              ),
            ],
          ),
        ],
        const SizedBox(height: 12),
        _buildAadhaarCardSlot(cs, 0),
        const SizedBox(height: 12),
        _buildAadhaarCardSlot(cs, 1),
      ],
    );
  }

  Widget _buildAadhaarCardSlot(ColorScheme cs, int slot) {
    final isFront = slot == 0;
    final item = isFront ? _aadhaarFrontItem : _aadhaarBackItem;
    final isSelected = _aadhaarActiveSlot == slot;

    return Container(
      decoration: BoxDecoration(
        color: isSelected
            ? cs.primaryContainer.withValues(alpha: 0.25)
            : cs.surfaceContainerHighest.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSelected ? cs.primary : Colors.grey.shade300,
          width: isSelected ? 2.0 : 1.0,
        ),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Row
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: isFront ? Colors.teal.shade50 : Colors.indigo.shade50,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(
                  isFront ? Icons.badge : Icons.qr_code_2,
                  size: 18,
                  color: isFront ? Colors.teal.shade700 : Colors.indigo.shade700,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isFront
                          ? 'Aadhaar Front Side (समोरील बाजू)'
                          : 'Aadhaar Back Side (मागील बाजू)',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    Text(
                      isFront
                          ? 'Photo, Name, Aadhaar Number, DOB, Gender'
                          : 'Address, Father/Husband Name, QR Code',
                      style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
              if (item != null)
                TextButton(
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    foregroundColor: isSelected ? cs.primary : Colors.grey.shade700,
                  ),
                  onPressed: () => setState(() => _aadhaarActiveSlot = slot),
                  child: Text(
                    isSelected ? '● Editing' : 'Select to Edit',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),

          // Slot Body
          if (item == null)
            InkWell(
              onTap: () => _pickAadhaarSlot(slot),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300, style: BorderStyle.solid),
                ),
                child: Column(
                  children: [
                    Icon(Icons.add_photo_alternate_outlined, size: 32, color: cs.primary),
                    const SizedBox(height: 6),
                    Text(
                      'Click to Upload ${isFront ? "Front" : "Back"} Side',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: cs.primary),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Supports JPG, PNG, WEBP, or PDF',
                      style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                    ),
                  ],
                ),
              ),
            )
          else ...[
            // Thumbnail & Info Row
            InkWell(
              onTap: () => setState(() => _aadhaarActiveSlot = slot),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: Container(
                        width: 72,
                        height: 52,
                        color: Colors.grey.shade100,
                        child: item.displayBytes.isNotEmpty
                            ? Image.memory(item.displayBytes, fit: BoxFit.cover)
                            : const Icon(Icons.image, size: 24, color: Colors.grey),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.name,
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${item.fileSizeFormatted} • ${item.width}x${item.height} px',
                            style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                          ),
                          if (item.qualityWarning != null) ...[
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.amber.shade50,
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: Colors.amber.shade300),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.warning_amber_rounded, size: 12, color: Colors.amber.shade900),
                                  const SizedBox(width: 4),
                                  Text(
                                    item.qualityWarning!,
                                    style: TextStyle(fontSize: 9.5, color: Colors.amber.shade900, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),

            // Quick Toolbar for slot
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                ElevatedButton.icon(
                  icon: const Icon(Icons.auto_awesome, size: 14),
                  label: const Text('Auto Crop', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    backgroundColor: const Color(0xFF0F2D69),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  ),
                  onPressed: () => _autoCropAadhaarSlot(slot),
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.straighten, size: 14),
                  label: const Text('Straighten (सरळ करा)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    backgroundColor: Colors.teal.shade700,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  ),
                  onPressed: () => _autoStraightenAadhaarSlot(slot),
                ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.crop, size: 14),
                  label: const Text('Crop (कापा)', style: TextStyle(fontSize: 11)),
                  style: OutlinedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  ),
                  onPressed: () {
                    setState(() => _aadhaarActiveSlot = slot);
                    _openPerspectiveCropDialog();
                  },
                ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.crop_free, size: 14, color: Colors.deepPurple),
                  label: const Text('Adjust Corners (कोपरे जुळवा)', style: TextStyle(fontSize: 11)),
                  style: OutlinedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  ),
                  onPressed: () {
                    setState(() => _aadhaarActiveSlot = slot);
                    _openAdjustCornersDialog();
                  },
                ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.rotate_right, size: 14),
                  label: const Text('Rotate 90°', style: TextStyle(fontSize: 11)),
                  style: OutlinedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  ),
                  onPressed: () {
                    setState(() => _aadhaarActiveSlot = slot);
                    _rotateActiveItem(90);
                  },
                ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.bolt, size: 14, color: Colors.blue),
                  label: const Text('Magic Enhance', style: TextStyle(fontSize: 11)),
                  style: OutlinedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  ),
                  onPressed: () => _applyEnhancementToAadhaarSlot(
                    slot: slot,
                    settings: DocumentEnhanceSettings.presetMedium(),
                  ),
                ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.compare_arrows, size: 14),
                  label: const Text('Compare', style: TextStyle(fontSize: 11)),
                  style: OutlinedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  ),
                  onPressed: () {
                    setState(() => _aadhaarActiveSlot = slot);
                    _openComparisonDialog();
                  },
                ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.refresh, size: 14),
                  label: const Text('Replace', style: TextStyle(fontSize: 11)),
                  style: OutlinedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  ),
                  onPressed: () => _pickAadhaarSlot(slot),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 16, color: Colors.red),
                  tooltip: 'Remove',
                  visualDensity: VisualDensity.compact,
                  onPressed: () => _removeAadhaarSlot(slot),
                ),
              ],
            ),
          ],
        ],
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
                            if (item.settings.cropLeft > 0 || item.settings.cropTop > 0 || item.settings.cropRight > 0 || item.settings.cropBottom > 0) ...[
                              const SizedBox(width: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                decoration: BoxDecoration(
                                  color: Colors.blue.shade100,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  'Cropped',
                                  style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.blue.shade900),
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
                  // Controls: Auto crop, move up/down, delete
                  IconButton(
                    icon: const Icon(Icons.auto_awesome, size: 16, color: Color(0xFF0F2D69)),
                    tooltip: 'Auto Crop Document (ऑटो क्रॉप)',
                    visualDensity: VisualDensity.compact,
                    onPressed: () => _autoCropItem(index: i),
                  ),
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

    void apply(DocumentEnhanceSettings newSettings) {
      if (_documentMode == DocumentMode.aadhaarFrontBack) {
        _applyEnhancementToAadhaarSlot(slot: _aadhaarActiveSlot, settings: newSettings);
      } else {
        _applyEnhancementToItem(index: _activeItemIndex, settings: newSettings);
      }
    }

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

            if (item.qualityWarning != null) ...[
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.amber.shade300),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Icon(Icons.warning_amber_rounded, color: Colors.amber.shade900, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        item.qualityWarning!,
                        style: TextStyle(fontSize: 11, color: Colors.brown.shade900, fontWeight: FontWeight.w600),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.crop_free, size: 13),
                      label: const Text('Adjust Corners', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        backgroundColor: Colors.amber.shade800,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      ),
                      onPressed: _openAdjustCornersDialog,
                    ),
                  ],
                ),
              ),
            ],

            // Aadhaar Active Slot Selector Switch
            if (_documentMode == DocumentMode.aadhaarFrontBack) ...[
              Row(
                children: [
                  Expanded(
                    child: ChoiceChip(
                      avatar: const Icon(Icons.badge, size: 14),
                      label: Text('Front Side ${_aadhaarFrontItem != null ? "✓" : "(Empty)"}'),
                      selected: _aadhaarActiveSlot == 0,
                      onSelected: (_) => setState(() => _aadhaarActiveSlot = 0),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ChoiceChip(
                      avatar: const Icon(Icons.qr_code_2, size: 14),
                      label: Text('Back Side ${_aadhaarBackItem != null ? "✓" : "(Empty)"}'),
                      selected: _aadhaarActiveSlot == 1,
                      onSelected: (_) => setState(() => _aadhaarActiveSlot = 1),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],

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
                  onPressed: () => apply(DocumentEnhanceSettings.presetLow()),
                ),
                ActionChip(
                  avatar: const Icon(Icons.check_circle_outline, size: 14, color: Colors.teal),
                  label: const Text('Balanced (Medium)', style: TextStyle(fontSize: 11)),
                  onPressed: () => apply(DocumentEnhanceSettings.presetMedium()),
                ),
                ActionChip(
                  avatar: const Icon(Icons.document_scanner, size: 14, color: Colors.deepOrange),
                  label: const Text('Crisp Document (High)', style: TextStyle(fontSize: 11)),
                  onPressed: () => apply(DocumentEnhanceSettings.presetHigh()),
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
              onChanged: (val) => apply(s.copyWith(backgroundCleanup: val)),
            ),
            SwitchListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: const Text('Crisp B&W Document Mode (Adaptive Threshold)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              subtitle: const Text('Converts paper to clean white and text/stamps to crisp black ink', style: TextStyle(fontSize: 10.5)),
              value: s.blackAndWhite,
              onChanged: (val) => apply(s.copyWith(blackAndWhite: val)),
            ),
            SwitchListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: const Text('Auto Contrast & Levels', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              subtitle: const Text('Dynamically stretches faded text and whitens paper', style: TextStyle(fontSize: 10.5)),
              value: s.autoLevels,
              onChanged: (val) => apply(s.copyWith(autoLevels: val)),
            ),
            SwitchListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: const Text('Sharpen Text & Borders', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              subtitle: const Text('Brings back crisp pen strokes and character edges', style: TextStyle(fontSize: 10.5)),
              value: s.sharpen,
              onChanged: (val) => apply(s.copyWith(sharpen: val)),
            ),
            SwitchListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: const Text('Denoise Image', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              subtitle: const Text('Reduces camera grain and JPEG compression artifacts', style: TextStyle(fontSize: 10.5)),
              value: s.denoise,
              onChanged: (val) => apply(s.copyWith(denoise: val)),
            ),
            SwitchListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: const Text('Grayscale Conversion', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              subtitle: const Text('Eliminates background color casts', style: TextStyle(fontSize: 10.5)),
              value: s.grayscale,
              onChanged: (val) => apply(s.copyWith(grayscale: val)),
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
                    onChanged: (v) => apply(s.copyWith(brightness: v)),
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
                    onChanged: (v) => apply(s.copyWith(contrast: v)),
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
                  icon: const Icon(Icons.straighten, size: 16),
                  label: const Text('Auto Straighten (सरळ करा)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal.shade700,
                    foregroundColor: Colors.white,
                    visualDensity: VisualDensity.compact,
                  ),
                  onPressed: _autoStraightenActiveItem,
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.transform, size: 16),
                  label: const Text('Auto Perspective (कोनातून सरळ करा)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0F2D69),
                    foregroundColor: Colors.white,
                    visualDensity: VisualDensity.compact,
                  ),
                  onPressed: _autoPerspectiveCorrectionActiveItem,
                ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.crop_free, size: 16, color: Colors.deepPurple),
                  label: const Text('Adjust Corners (कोपरे जुळवा)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  style: OutlinedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    foregroundColor: Colors.deepPurple,
                  ),
                  onPressed: _openAdjustCornersDialog,
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.auto_awesome, size: 16),
                  label: const Text('Auto Crop (ऑटो क्रॉप)', style: TextStyle(fontSize: 12)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueGrey.shade700,
                    foregroundColor: Colors.white,
                    visualDensity: VisualDensity.compact,
                  ),
                  onPressed: _autoCropActiveItem,
                ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.auto_awesome_motion, size: 16, color: Color(0xFF0F2D69)),
                  label: Text(
                    _documentMode == DocumentMode.aadhaarFrontBack
                        ? 'Auto Crop Both (Front & Back)'
                        : 'Auto Crop All Files',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                  onPressed: _autoCropAllSelected,
                ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.crop, size: 16),
                  label: const Text('Manual Crop (कापा)', style: TextStyle(fontSize: 12)),
                  style: OutlinedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                  ),
                  onPressed: _openPerspectiveCropDialog,
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
                  label: const Text('Before / After (तुलना)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  onPressed: _openComparisonDialog,
                ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.history, size: 16, color: Colors.red),
                  label: const Text('Reset (मूळ प्रत)', style: TextStyle(fontSize: 11, color: Colors.red)),
                  onPressed: _resetActiveItem,
                ),
              ],
            ),

            const SizedBox(height: 12),
            // Dedicated Tilt Straightening Panel (वाकडे कागद सरळ करणे)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: cs.primaryContainer.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: cs.primary.withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.straighten, size: 16, color: cs.primary),
                          const SizedBox(width: 6),
                          const Text(
                            'वाकडे डॉक्युमेंट सरळ करा (Straighten Tilt):',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: s.fineRotationAngle != 0.0 ? cs.primary : Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '${s.fineRotationAngle > 0 ? "+${s.fineRotationAngle.toStringAsFixed(1)}" : s.fineRotationAngle.toStringAsFixed(1)}°',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: s.fineRotationAngle != 0.0 ? Colors.white : Colors.black87,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Text('-30°', style: TextStyle(fontSize: 10, color: Colors.grey)),
                      Expanded(
                        child: Slider(
                          value: s.fineRotationAngle,
                          min: -30.0,
                          max: 30.0,
                          divisions: 60,
                          onChanged: (v) => _setFineRotation(v),
                        ),
                      ),
                      const Text('+30°', style: TextStyle(fontSize: 10, color: Colors.grey)),
                    ],
                  ),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      OutlinedButton(
                        style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact, padding: const EdgeInsets.symmetric(horizontal: 8)),
                        onPressed: () => _adjustFineRotation(-5.0),
                        child: const Text('-5°', style: TextStyle(fontSize: 11)),
                      ),
                      OutlinedButton(
                        style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact, padding: const EdgeInsets.symmetric(horizontal: 8)),
                        onPressed: () => _adjustFineRotation(-1.0),
                        child: const Text('-1°', style: TextStyle(fontSize: 11)),
                      ),
                      OutlinedButton(
                        style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact, padding: const EdgeInsets.symmetric(horizontal: 8)),
                        onPressed: () => _setFineRotation(0.0),
                        child: const Text('0° Reset', style: TextStyle(fontSize: 11)),
                      ),
                      OutlinedButton(
                        style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact, padding: const EdgeInsets.symmetric(horizontal: 8)),
                        onPressed: () => _adjustFineRotation(1.0),
                        child: const Text('+1°', style: TextStyle(fontSize: 11)),
                      ),
                      OutlinedButton(
                        style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact, padding: const EdgeInsets.symmetric(horizontal: 8)),
                        onPressed: () => _adjustFineRotation(5.0),
                        child: const Text('+5°', style: TextStyle(fontSize: 11)),
                      ),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.straighten, size: 14),
                        label: const Text('Auto Straighten (ऑटो सरळ करा)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: cs.primary,
                          foregroundColor: Colors.white,
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                        ),
                        onPressed: _autoStraightenActiveItem,
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),
            ElevatedButton.icon(
              icon: const Icon(Icons.copy_all, size: 16),
              label: Text(_documentMode == DocumentMode.aadhaarFrontBack
                  ? 'Apply Current Settings to Both Front & Back'
                  : 'Apply Current Settings to All Selected Files'),
              style: ElevatedButton.styleFrom(
                backgroundColor: cs.secondaryContainer,
                foregroundColor: cs.onSecondaryContainer,
                visualDensity: VisualDensity.compact,
              ),
              onPressed: () {
                if (_documentMode == DocumentMode.aadhaarFrontBack) {
                  _applyAadhaarSettingsToBoth(s);
                } else {
                  _applyToAllSelected(s);
                }
              },
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
                Expanded(
                  child: Text(
                    _documentMode == DocumentMode.aadhaarFrontBack
                        ? 'Section C: Aadhaar A4 Layout & Card Sizing'
                        : 'Section C: A4 Page Formatting Settings',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            if (_documentMode == DocumentMode.aadhaarFrontBack)
              _buildAadhaarA4Settings(cs)
            else ...[
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
          ],
        ),
      ),
    );
  }

  Widget _buildAadhaarA4Settings(ColorScheme cs) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Card Scale / Size
        const Text('Aadhaar Card Print Size:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
        const SizedBox(height: 6),
        SegmentedButton<AadhaarCardScale>(
          segments: const [
            ButtonSegment(
              value: AadhaarCardScale.actualIdSize,
              label: Text('Pocket ID (85x54mm)', style: TextStyle(fontSize: 10.5)),
            ),
            ButtonSegment(
              value: AadhaarCardScale.mediumScale,
              label: Text('Medium (~115mm)', style: TextStyle(fontSize: 10.5)),
            ),
            ButtonSegment(
              value: AadhaarCardScale.largeScale,
              label: Text('Large (~140mm)', style: TextStyle(fontSize: 10.5)),
            ),
            ButtonSegment(
              value: AadhaarCardScale.fitWidth,
              label: Text('Full Width', style: TextStyle(fontSize: 10.5)),
            ),
          ],
          selected: {_aadhaarSettings.scale},
          onSelectionChanged: (set) {
            setState(() => _aadhaarSettings = _aadhaarSettings.copyWith(scale: set.first));
            _triggerPdfRegeneration();
          },
        ),
        const SizedBox(height: 12),

        // Spacing Between Front and Back
        const Text('Vertical Spacing Between Cards:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
        const SizedBox(height: 6),
        SegmentedButton<AadhaarSpacing>(
          segments: const [
            ButtonSegment(value: AadhaarSpacing.compact, label: Text('Compact (10mm)', style: TextStyle(fontSize: 11))),
            ButtonSegment(value: AadhaarSpacing.normal, label: Text('Normal (20mm)', style: TextStyle(fontSize: 11))),
            ButtonSegment(value: AadhaarSpacing.spacious, label: Text('Spacious (35mm)', style: TextStyle(fontSize: 11))),
          ],
          selected: {_aadhaarSettings.spacing},
          onSelectionChanged: (set) {
            setState(() => _aadhaarSettings = _aadhaarSettings.copyWith(spacing: set.first));
            _triggerPdfRegeneration();
          },
        ),
        const SizedBox(height: 12),

        // Margins
        const Text('A4 Page Margins:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
        const SizedBox(height: 6),
        SegmentedButton<A4MarginPreset>(
          segments: const [
            ButtonSegment(value: A4MarginPreset.none, label: Text('None (0mm)', style: TextStyle(fontSize: 11))),
            ButtonSegment(value: A4MarginPreset.small, label: Text('Small (5mm)', style: TextStyle(fontSize: 11))),
            ButtonSegment(value: A4MarginPreset.normal, label: Text('Normal (10mm)', style: TextStyle(fontSize: 11))),
          ],
          selected: {_aadhaarSettings.marginPreset},
          onSelectionChanged: (set) {
            setState(() => _aadhaarSettings = _aadhaarSettings.copyWith(marginPreset: set.first));
            _triggerPdfRegeneration();
          },
        ),
        const SizedBox(height: 12),

        // Dotted Cut Line Switch
        SwitchListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          title: const Text('Dotted Cut Guide (✂️ Cut Here)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          subtitle: const Text('Draws a clean dashed guide between front and back cards for easy scissor cutting', style: TextStyle(fontSize: 10.5)),
          value: _aadhaarSettings.showCutLine,
          onChanged: (val) {
            setState(() => _aadhaarSettings = _aadhaarSettings.copyWith(showCutLine: val));
            _triggerPdfRegeneration();
          },
        ),

        // Header Title Switch
        SwitchListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          title: const Text('Header Title (UIDAI — AADHAAR CARD)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          subtitle: const Text('Include official header title at the top of the A4 page', style: TextStyle(fontSize: 10.5)),
          value: _aadhaarSettings.showHeader,
          onChanged: (val) {
            setState(() => _aadhaarSettings = _aadhaarSettings.copyWith(showHeader: val));
            _triggerPdfRegeneration();
          },
        ),

        const SizedBox(height: 8),
        OutlinedButton.icon(
          icon: const Icon(Icons.refresh, size: 16),
          label: const Text('Reset Layout to Default', style: TextStyle(fontSize: 11)),
          onPressed: () {
            setState(() => _aadhaarSettings = const AadhaarPageSettings());
            _triggerPdfRegeneration();
          },
        ),
      ],
    );
  }

  // ── Section E: Preview & Export ───────────────────────────────────────────────

  Widget _buildSectionEPreviewAndExport(ColorScheme cs) {
    final isAadhaar = _documentMode == DocumentMode.aadhaarFrontBack;
    final selectedCount = isAadhaar
        ? [if (_aadhaarFrontItem != null) 1, if (_aadhaarBackItem != null) 1].length
        : _items.where((it) => it.isSelected).length;

    // Estimate output pages based on layout
    final int estimatedPages;
    if (isAadhaar) {
      estimatedPages = 1;
    } else if (_a4Settings.layout == A4Layout.twoPerPage) {
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
                  Icon(
                    isAadhaar ? Icons.badge : Icons.picture_as_pdf,
                    color: cs.primary,
                    size: 22,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isAadhaar
                        ? 'Aadhaar A4 Output Preview (Front & Back on 1 Page)'
                        : 'Final A4 Output Preview ($selectedCount items • ~$estimatedPages A4 page${estimatedPages == 1 ? '' : 's'})',
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

    final bool hasContent = _documentMode == DocumentMode.aadhaarFrontBack
        ? (_aadhaarFrontItem != null || _aadhaarBackItem != null)
        : _items.where((it) => it.isSelected).isNotEmpty;

    if (_generatedPdfBytes == null || !hasContent) {
      return Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _documentMode == DocumentMode.aadhaarFrontBack
                    ? Icons.badge_outlined
                    : Icons.picture_as_pdf_outlined,
                size: 56,
                color: Colors.grey.shade400,
              ),
              const SizedBox(height: 12),
              Text(
                _documentMode == DocumentMode.aadhaarFrontBack
                    ? 'No Aadhaar sides uploaded for A4 conversion.'
                    : 'No documents selected for A4 conversion.',
                style: TextStyle(fontSize: 14, color: Colors.grey.shade600, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              Text(
                _documentMode == DocumentMode.aadhaarFrontBack
                    ? 'Upload Front and/or Back side on the left to generate the A4 sheet.'
                    : 'Upload photos or documents on the left and select items to preview.',
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
        pdfFileName: _documentMode == DocumentMode.aadhaarFrontBack
            ? 'Aadhaar_Card_Front_Back_${DateTime.now().millisecondsSinceEpoch}.pdf'
            : 'Siya_Document_A4_${DateTime.now().millisecondsSinceEpoch}.pdf',
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
