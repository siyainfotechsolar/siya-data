import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/record_diff.dart';
import '../services/import_parser_service.dart';
import '../services/record_service.dart';
import '../services/duplicate_detection_service.dart';
import 'diff_review_view.dart';

enum ImportStep {
  upload,
  mapping,
  preview,
  diffReview,
  importing,
  completed,
}

class ImportDialog extends StatefulWidget {
  final VoidCallback onImportSuccess;

  const ImportDialog({super.key, required this.onImportSuccess});

  @override
  State<ImportDialog> createState() => _ImportDialogState();
}

class _ImportDialogState extends State<ImportDialog> {
  ImportStep _currentStep = ImportStep.upload;
  bool _isLoading = false;
  String? _errorMessage;

  // File data
  String? _fileName;
  RawImportData? _rawData;

  // Mapping & Validation
  ImportColumnMapping _mapping = ImportColumnMapping();
  ImportValidationReport? _validationReport;
  bool _showOnlyInvalid = false;

  // Duplicate & Diff Analysis (Phase 5)
  DuplicateAnalysisResult? _duplicateAnalysis;
  ConflictStrategy _selectedStrategy = ConflictStrategy.updateNonEmptyOnly;

  // Progress
  int _currentProgress = 0;
  int _totalToImport = 0;
  Map<String, int>? _importSummary;

  Future<void> _pickFile() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls', 'csv'],
        withData: true,
      );

      if (result == null || result.files.isEmpty || result.files.first.bytes == null) {
        setState(() => _isLoading = false);
        return;
      }

      final file = result.files.first;
      final bytes = file.bytes!;
      final name = file.name;

      final parsed = await ImportParserService.parseFile(name, bytes);

      if (parsed.headers.isEmpty || parsed.rows.isEmpty) {
        throw Exception('The selected file contains no readable rows.');
      }

      final detectedMapping = ImportParserService.autoDetectColumns(parsed.headers);
      final validation = ImportParserService.validateData(parsed, detectedMapping);

      setState(() {
        _fileName = name;
        _rawData = parsed;
        _mapping = detectedMapping;
        _validationReport = validation;
        // Always open Step 2: Mapping screen so user has full manual control,
        // while offering an optional "Skip Mapping" button for quick bypass.
        _currentStep = ImportStep.mapping;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  void _revalidate() {
    if (_rawData != null) {
      final updatedValidation = ImportParserService.validateData(_rawData!, _mapping);
      setState(() {
        _validationReport = updatedValidation;
      });
    }
  }

  Future<void> _runDuplicateAnalysis() async {
    if (_validationReport == null || _validationReport!.validRowsCount == 0) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final validRecords = _validationReport!.rows
          .where((r) => r.isValid)
          .map((r) => r.toConsumerRecord())
          .toList();

      final analysis = await DuplicateDetectionService.analyzeDuplicates(
        validRecords,
        allowedFieldKeys: _mapping.mappedFieldKeys,
        ignoreBlankValues: _mapping.ignoreBlankValues,
      );

      setState(() {
        _duplicateAnalysis = analysis;
        _currentStep = ImportStep.diffReview;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Duplicate analysis failed: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _executeImport() async {
    if (_duplicateAnalysis == null) return;

    final newRecords = _duplicateAnalysis!.newRecords;
    final conflictRecords = _duplicateAnalysis!.conflictRecords;

    setState(() {
      _currentStep = ImportStep.importing;
      _currentProgress = 0;
      _totalToImport = newRecords.length + conflictRecords.length;
    });

    try {
      final summary = await RecordService.executeSmartImport(
        newRecords: newRecords,
        conflictRecords: conflictRecords,
        strategy: _selectedStrategy,
        allowedFieldKeys: _mapping.mappedFieldKeys,
        ignoreBlankValues: _mapping.ignoreBlankValues,
        fileName: _fileName,
        fileSizeBytes: _rawData?.fileSizeBytes,
        onProgress: (current, total) {
          if (mounted) {
            setState(() {
              _currentProgress = current;
              _totalToImport = total;
            });
          }
        },
      );

      if (mounted) {
        setState(() {
          _importSummary = summary;
          _currentStep = ImportStep.completed;
        });
        widget.onImportSuccess();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Import failed: $e';
          _currentStep = ImportStep.diffReview;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Container(
        width: 1000,
        height: 720,
        padding: const EdgeInsets.all(28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFD97706).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.upload_file_rounded, color: Color(0xFFD97706), size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Import Solar Consumer Data',
                        style: GoogleFonts.outfit(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF1E293B),
                        ),
                      ),
                      Text(
                        'Upload Excel (.xlsx, .xls) or CSV files with smart duplicate & field diff detection',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
                if (_currentStep != ImportStep.importing)
                  IconButton(
                    icon: const Icon(Icons.close, color: Color(0xFF64748B)),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
              ],
            ),
            const SizedBox(height: 18),

            // Step Indicator Bar
            _buildStepIndicator(),
            const SizedBox(height: 20),

            // Error Banner
            if (_errorMessage != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, color: Colors.red.shade700, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: GoogleFonts.inter(fontSize: 13, color: Colors.red.shade900),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Step Content
            Expanded(
              child: _buildCurrentStepContent(),
            ),

            const SizedBox(height: 16),

            // Bottom Actions Bar
            _buildBottomActionBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildStepIndicator() {
    final steps = [
      {'step': ImportStep.upload, 'title': '1. Upload'},
      {'step': ImportStep.mapping, 'title': '2. Column Mapping'},
      {'step': ImportStep.preview, 'title': '3. Validation'},
      {'step': ImportStep.diffReview, 'title': '4. Diff & Duplicates'},
      {'step': ImportStep.completed, 'title': '5. Complete'},
    ];

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: steps.map((s) {
          final stepEnum = s['step'] as ImportStep;
          final title = s['title'] as String;
          final isPassed = _isStepPassed(stepEnum);
          final isCurrent = _currentStep == stepEnum ||
              (_currentStep == ImportStep.importing && stepEnum == ImportStep.diffReview);

          Color textColor = const Color(0xFF94A3B8);
          FontWeight fontWeight = FontWeight.normal;

          if (isCurrent) {
            textColor = const Color(0xFFD97706);
            fontWeight = FontWeight.bold;
          } else if (isPassed) {
            textColor = const Color(0xFF0F766E);
            fontWeight = FontWeight.w600;
          }

          return Row(
            children: [
              Icon(
                isPassed
                    ? Icons.check_circle
                    : (isCurrent ? Icons.radio_button_checked : Icons.radio_button_unchecked),
                size: 16,
                color: textColor,
              ),
              const SizedBox(width: 6),
              Text(
                title,
                style: GoogleFonts.inter(fontSize: 12, fontWeight: fontWeight, color: textColor),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  bool _isStepPassed(ImportStep step) {
    if (_currentStep == ImportStep.completed) return true;
    if (_currentStep == ImportStep.importing) return step != ImportStep.completed;
    if (_currentStep == ImportStep.diffReview) {
      return step == ImportStep.upload || step == ImportStep.mapping || step == ImportStep.preview;
    }
    if (_currentStep == ImportStep.preview) return step == ImportStep.upload || step == ImportStep.mapping;
    if (_currentStep == ImportStep.mapping) return step == ImportStep.upload;
    return false;
  }

  Widget _buildCurrentStepContent() {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(color: Color(0xFFD97706)),
            const SizedBox(height: 16),
            Text(
              _currentStep == ImportStep.preview
                  ? 'Comparing records against database & computing field diffs...'
                  : 'Parsing file contents & detecting column headers...',
              style: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF64748B)),
            ),
          ],
        ),
      );
    }

    switch (_currentStep) {
      case ImportStep.upload:
        return _buildUploadView();
      case ImportStep.mapping:
        return _buildMappingView();
      case ImportStep.preview:
        return _buildPreviewView();
      case ImportStep.diffReview:
        return _duplicateAnalysis != null
            ? DiffReviewView(
                analysis: _duplicateAnalysis!,
                selectedStrategy: _selectedStrategy,
                onStrategyChanged: (strategy) => setState(() => _selectedStrategy = strategy),
                onDataChanged: () => setState(() {}),
              )
            : const SizedBox.shrink();
      case ImportStep.importing:
        return _buildImportingView();
      case ImportStep.completed:
        return _buildCompletedView();
    }
  }

  // --- Step 1: Upload View ---
  Widget _buildUploadView() {
    return Center(
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(36),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFCBD5E1), width: 1.5),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFFD97706).withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.cloud_upload_outlined, size: 54, color: Color(0xFFD97706)),
            ),
            const SizedBox(height: 20),
            Text(
              'Select or Drop Excel or CSV File',
              style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: const Color(0xFF1E293B)),
            ),
            const SizedBox(height: 8),
            Text(
              'Supports Microsoft Excel (.xlsx, .xls) and Comma-Separated Values (.csv)',
              style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF64748B)),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _pickFile,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD97706),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                elevation: 0,
              ),
              icon: const Icon(Icons.folder_open_rounded, size: 20),
              label: Text('Browse File', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600)),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildFormatBadge('.XLSX'),
                const SizedBox(width: 8),
                _buildFormatBadge('.XLS'),
                const SizedBox(width: 8),
                _buildFormatBadge('.CSV'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFormatBadge(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFE2E8F0),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF475569)),
      ),
    );
  }

  // --- Step 2: Mapping View ---
  Widget _buildMappingView() {
    if (_rawData == null) return const SizedBox.shrink();

    final headers = _rawData!.headers;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFEFF6FF),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFBFDBFE)),
          ),
          child: Row(
            children: [
              const Icon(Icons.info_outline, color: Color(0xFF2563EB), size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Selected File: ${_fileName ?? 'Dataset'} (${_rawData?.totalRows ?? 0} rows). Columns were auto-detected. You can skip directly or verify below.',
                  style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF1E40AF)),
                ),
              ),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                onPressed: _mapping.isValid
                    ? () {
                        _revalidate();
                        setState(() => _currentStep = ImportStep.preview);
                      }
                    : null,
                style: OutlinedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF2563EB),
                  side: const BorderSide(color: Color(0xFF93C5FD)),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                ),
                icon: const Icon(Icons.fast_forward_rounded, size: 16),
                label: const Text('Skip Mapping ➔'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),

        // Policy Notice Banner & Blank Values Setting
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            children: [
              const Icon(Icons.security, size: 18, color: Color(0xFF0F766E)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Only selected UPDATE columns will modify existing records. SKIPPED columns will remain 100% unchanged in the database.',
                  style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500, color: const Color(0xFF334155)),
                ),
              ),
              const SizedBox(width: 12),
              InkWell(
                onTap: () {
                  setState(() {
                    _mapping.ignoreBlankValues = !_mapping.ignoreBlankValues;
                  });
                },
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Checkbox(
                      value: _mapping.ignoreBlankValues,
                      onChanged: (val) {
                        setState(() {
                          _mapping.ignoreBlankValues = val ?? true;
                        });
                      },
                      activeColor: const Color(0xFF0F766E),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    Text(
                      'Ignore blank values (Keep existing data)',
                      style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF1E293B)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        Expanded(
          child: ListView(
            children: [
              _buildMappingRow('Consumer No *', 'Unique identifier (CA No, K No, Connection ID)', _mapping.consumerNoIndex, headers, (idx) {
                setState(() => _mapping.consumerNoIndex = idx);
                _revalidate();
              }, isRequired: true, isUniqueKey: true),
              _buildMappingRow('Consumer Name *', 'Full name of applicant or beneficiary', _mapping.nameIndex, headers, (idx) {
                setState(() => _mapping.nameIndex = idx);
                _revalidate();
              }, isRequired: true),
              _buildMappingRow('Mobile Number', 'Contact phone or cell number', _mapping.mobileIndex, headers, (idx) {
                setState(() => _mapping.mobileIndex = idx);
                _revalidate();
              }),
              _buildMappingRow('Full Address', 'Village, taluka, district, or premise location', _mapping.addressIndex, headers, (idx) {
                setState(() => _mapping.addressIndex = idx);
                _revalidate();
              }),
              _buildMappingRow('Application ID', 'Portal registration / acknowledgment number', _mapping.applicationIdIndex, headers, (idx) {
                setState(() => _mapping.applicationIdIndex = idx);
                _revalidate();
              }),
              _buildMappingRow('Installation Status', 'Pending, Approved, In Progress, Installed, Rejected', _mapping.statusIndex, headers, (idx) {
                setState(() => _mapping.statusIndex = idx);
                _revalidate();
              }),
              _buildMappingRow('Remarks / Notes', 'Vendor notes or solar capacity remarks', _mapping.remarksIndex, headers, (idx) {
                setState(() => _mapping.remarksIndex = idx);
                _revalidate();
              }),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMappingRow(
    String label,
    String description,
    int? currentIndex,
    List<String> headers,
    ValueChanged<int?> onChanged, {
    bool isRequired = false,
    bool isUniqueKey = false,
  }) {
    final bool isMapped = currentIndex != null && currentIndex >= 0 && currentIndex < headers.length;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: (isRequired && currentIndex == null) ? Colors.red.shade300 : const Color(0xFFE2E8F0),
        ),
      ),
      child: Row(
        children: [
          // Database Field Info
          Expanded(
            flex: 4,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      label,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF1E293B),
                      ),
                    ),
                    if (isRequired) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'Required',
                          style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.red.shade700),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),

          // Action Status Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: isUniqueKey
                  ? const Color(0xFFEFF6FF)
                  : (isMapped ? const Color(0xFFECFDF5) : const Color(0xFFF1F5F9)),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: isUniqueKey
                    ? const Color(0xFFBFDBFE)
                    : (isMapped ? const Color(0xFFA7F3D0) : const Color(0xFFCBD5E1)),
              ),
            ),
            child: Text(
              isUniqueKey ? 'UNIQUE KEY' : (isMapped ? 'UPDATE' : 'SKIP'),
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: isUniqueKey
                    ? const Color(0xFF1D4ED8)
                    : (isMapped ? const Color(0xFF047857) : const Color(0xFF64748B)),
              ),
            ),
          ),
          const SizedBox(width: 16),

          // Dropdown Selector
          Expanded(
            flex: 4,
            child: DropdownButtonFormField<int?>(
              initialValue: isMapped ? currentIndex : null,
              decoration: InputDecoration(
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                hintText: '-- Skip Column --',
                hintStyle: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF94A3B8)),
              ),
              items: [
                const DropdownMenuItem<int?>(
                  value: null,
                  child: Text('-- Skip / Do not import --', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13)),
                ),
                ...headers.asMap().entries.map((entry) {
                  return DropdownMenuItem<int?>(
                    value: entry.key,
                    child: Text(
                      'Col ${entry.key + 1}: ${entry.value}',
                      style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500),
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }),
              ],
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }

  // --- Step 3: Validation & Preview View ---
  Widget _buildPreviewView() {
    if (_validationReport == null) return const SizedBox.shrink();

    final report = _validationReport!;
    final rowsToShow = _showOnlyInvalid
        ? report.rows.where((r) => !r.isValid).toList()
        : report.rows;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Stats Badges Bar
        Row(
          children: [
            _buildStatBadge('Total Rows', report.totalRows.toString(), const Color(0xFF64748B), Colors.grey.shade100),
            const SizedBox(width: 10),
            _buildStatBadge('Valid Rows', report.validRowsCount.toString(), const Color(0xFF0F766E), const Color(0xFFCCFBF1)),
            const SizedBox(width: 10),
            _buildStatBadge('Invalid Rows', report.invalidRowsCount.toString(), Colors.red.shade700, Colors.red.shade50),
            const SizedBox(width: 10),
            _buildStatBadge('In-File Duplicates', report.duplicateCount.toString(), const Color(0xFFD97706), const Color(0xFFFEF3C7)),
            const Spacer(),
            FilterChip(
              label: Text('Show Invalid Only (${report.invalidRowsCount})'),
              selected: _showOnlyInvalid,
              onSelected: (val) => setState(() => _showOnlyInvalid = val),
              selectedColor: Colors.red.shade100,
              checkmarkColor: Colors.red.shade700,
            ),
          ],
        ),
        const SizedBox(height: 14),

        // Preview Table
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SingleChildScrollView(
                scrollDirection: Axis.vertical,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
                    headingTextStyle: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 12, color: const Color(0xFF475569)),
                    dataRowMinHeight: 44,
                    dataRowMaxHeight: 52,
                    columns: const [
                      DataColumn(label: Text('Row')),
                      DataColumn(label: Text('Validation Status')),
                      DataColumn(label: Text('Consumer No')),
                      DataColumn(label: Text('Consumer Name')),
                      DataColumn(label: Text('Mobile')),
                      DataColumn(label: Text('Address')),
                      DataColumn(label: Text('Status')),
                      DataColumn(label: Text('Errors')),
                    ],
                    rows: rowsToShow.take(50).map((row) {
                      return DataRow(
                        color: WidgetStateProperty.resolveWith<Color?>((states) {
                          if (!row.isValid) return Colors.red.shade50.withValues(alpha: 0.5);
                          return null;
                        }),
                        cells: [
                          DataCell(Text(row.rowNumber.toString())),
                          DataCell(
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: row.isValid ? const Color(0xFFD1FAE5) : Colors.red.shade100,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                row.isValid ? 'Valid' : 'Error',
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: row.isValid ? const Color(0xFF065F46) : Colors.red.shade800,
                                ),
                              ),
                            ),
                          ),
                          DataCell(Text(row.consumerNo.isEmpty ? '—' : row.consumerNo, style: const TextStyle(fontWeight: FontWeight.w600))),
                          DataCell(Text(row.name.isEmpty ? '—' : row.name)),
                          DataCell(Text(row.mobile ?? '—')),
                          DataCell(Text(row.address ?? '—', overflow: TextOverflow.ellipsis)),
                          DataCell(Text(row.status)),
                          DataCell(
                            row.errors.isEmpty
                                ? const Text('None', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12))
                                : Text(
                                    row.errors.join(', '),
                                    style: TextStyle(color: Colors.red.shade700, fontSize: 12, fontWeight: FontWeight.w500),
                                  ),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatBadge(String title, String count, Color textColor, Color bgColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$title: ', style: GoogleFonts.inter(fontSize: 12, color: textColor.withValues(alpha: 0.8))),
          Text(count, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: textColor)),
        ],
      ),
    );
  }

  // --- Step 4: Importing in Progress View ---
  Widget _buildImportingView() {
    final double percent = _totalToImport == 0 ? 0 : (_currentProgress / _totalToImport).clamp(0.0, 1.0);

    return Center(
      child: Container(
        width: 500,
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: Color(0xFFD97706), strokeWidth: 3),
            const SizedBox(height: 24),
            Text(
              'Importing Records...',
              style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: const Color(0xFF1E293B)),
            ),
            const SizedBox(height: 8),
            Text(
              'Writing verified consumer records and updating existing entries in database',
              style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF64748B)),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: percent,
                minHeight: 10,
                backgroundColor: const Color(0xFFE2E8F0),
                valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFD97706)),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '$_currentProgress / $_totalToImport records (${(percent * 100).toInt()}%)',
              style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF1E293B)),
            ),
          ],
        ),
      ),
    );
  }

  // --- Step 5: Completed View ---
  Widget _buildCompletedView() {
    final total = _importSummary?['total'] ?? 0;
    final inserted = _importSummary?['inserted'] ?? 0;
    final updated = _importSummary?['updated'] ?? 0;
    final skipped = _importSummary?['skipped'] ?? 0;
    final errors = _importSummary?['errors'] ?? 0;

    return Center(
      child: Container(
        width: 540,
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle_outline_rounded, size: 54, color: Color(0xFF059669)),
            ),
            const SizedBox(height: 20),
            Text(
              'Import Completed Successfully!',
              style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold, color: const Color(0xFF1E293B)),
            ),
            const SizedBox(height: 8),
            Text(
              'Your dataset has been synchronized with the database and field changes were logged.',
              style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF64748B)),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              alignment: WrapAlignment.center,
              children: [
                _buildSummaryBox('Total Processed', total.toString(), const Color(0xFF1E293B)),
                _buildSummaryBox('New Inserted', inserted.toString(), const Color(0xFF059669)),
                if (updated > 0) _buildSummaryBox('Updated', updated.toString(), const Color(0xFFD97706)),
                if (skipped > 0) _buildSummaryBox('Skipped', skipped.toString(), const Color(0xFF64748B)),
                if (errors > 0) _buildSummaryBox('Failed', errors.toString(), Colors.red.shade700),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryBox(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFCBD5E1)),
      ),
      child: Column(
        children: [
          Text(value, style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
          Text(label, style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B))),
        ],
      ),
    );
  }

  // --- Bottom Navigation Bar ---
  Widget _buildBottomActionBar() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Back Buttons
        if (_currentStep == ImportStep.mapping)
          TextButton.icon(
            onPressed: () => setState(() => _currentStep = ImportStep.upload),
            icon: const Icon(Icons.arrow_back, size: 16),
            label: const Text('Choose Different File'),
          )
        else if (_currentStep == ImportStep.preview)
          TextButton.icon(
            onPressed: () => setState(() => _currentStep = ImportStep.mapping),
            icon: const Icon(Icons.arrow_back, size: 16),
            label: const Text('Back to Mapping'),
          )
        else if (_currentStep == ImportStep.diffReview)
          TextButton.icon(
            onPressed: () => setState(() => _currentStep = ImportStep.preview),
            icon: const Icon(Icons.arrow_back, size: 16),
            label: const Text('Back to Preview'),
          )
        else
          const SizedBox.shrink(),

        // Forward / Action Buttons
        if (_currentStep == ImportStep.upload)
          const SizedBox.shrink()
        else if (_currentStep == ImportStep.mapping)
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: _mapping.isValid
                    ? () {
                        _revalidate();
                        setState(() => _currentStep = ImportStep.preview);
                      }
                    : null,
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF2563EB),
                  side: const BorderSide(color: Color(0xFF93C5FD)),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                icon: const Icon(Icons.fast_forward_rounded, size: 18),
                label: const Text('Skip Mapping ➔'),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: _mapping.isValid
                    ? () {
                        _revalidate();
                        setState(() => _currentStep = ImportStep.preview);
                      }
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD97706),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                icon: const Icon(Icons.arrow_forward, size: 18),
                label: Text('Proceed to Validation (${_rawData?.totalRows ?? 0} rows)', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
              ),
            ],
          )
        else if (_currentStep == ImportStep.preview)
          ElevatedButton.icon(
            onPressed: (_validationReport != null && _validationReport!.validRowsCount > 0)
                ? _runDuplicateAnalysis
                : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0F766E),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            icon: const Icon(Icons.compare_arrows_rounded, size: 18),
            label: Text(
              'Check Duplicates & Diffs (${_validationReport?.validRowsCount ?? 0} Valid)',
              style: GoogleFonts.inter(fontWeight: FontWeight.bold),
            ),
          )
        else if (_currentStep == ImportStep.diffReview)
          ElevatedButton.icon(
            onPressed: _executeImport,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0F766E),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            icon: const Icon(Icons.cloud_upload_rounded, size: 18),
            label: Text(
              'Execute Smart Import (${_duplicateAnalysis?.totalIncoming ?? 0} Records)',
              style: GoogleFonts.inter(fontWeight: FontWeight.bold),
            ),
          )
        else if (_currentStep == ImportStep.completed)
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD97706),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Text('Close & Refresh Records', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
          ),
      ],
    );
  }
}
