import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/consumer_record.dart';
import '../services/work_completion_certificate_service.dart';

class WorkCompletionCertificateDialog extends StatefulWidget {
  final ConsumerRecord customer;

  const WorkCompletionCertificateDialog({
    super.key,
    required this.customer,
  });

  static Future<void> show(
    BuildContext context, {
    required ConsumerRecord customer,
  }) {
    return showDialog<void>(
      context: context,
      builder: (ctx) => WorkCompletionCertificateDialog(customer: customer),
    );
  }

  @override
  State<WorkCompletionCertificateDialog> createState() => _WorkCompletionCertificateDialogState();
}

class _WorkCompletionCertificateDialogState extends State<WorkCompletionCertificateDialog> {
  bool _isGenerating = false;
  File? _cachedFile;
  String? _statusMessage;

  late String _customerName;
  late String _consumerNo;
  late String _address;
  late String _capacity;
  late DateTime _completionDate;

  @override
  void initState() {
    super.initState();
    _customerName = widget.customer.name;
    _consumerNo = widget.customer.consumerNo;

    if (widget.customer.address != null && widget.customer.address!.trim().isNotEmpty) {
      _address = widget.customer.address!.trim();
    } else if (widget.customer.village != null && widget.customer.village!.trim().isNotEmpty) {
      _address = widget.customer.village!.trim();
    } else {
      _address = '';
    }

    String cap = '';
    if (widget.customer.remarks != null && widget.customer.remarks!.trim().isNotEmpty) {
      final match = RegExp(r'(\d+(?:\.\d+)?\s*(?:kw|kW|KW|Kw))').firstMatch(widget.customer.remarks!);
      if (match != null) cap = match.group(1)!;
    }
    _capacity = cap.isNotEmpty ? cap : '3.0 kW Rooftop Solar PV';

    _completionDate = widget.customer.installationDate ??
        widget.customer.rtsCompletionDate ??
        widget.customer.submitDate ??
        DateTime.now();
  }

  Future<void> _openEditDetailsModal() async {
    final nameCtrl = TextEditingController(text: _customerName);
    final consumerCtrl = TextEditingController(text: _consumerNo);
    final addressCtrl = TextEditingController(text: _address);
    final capacityCtrl = TextEditingController(text: _capacity);
    DateTime selectedDate = _completionDate;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.edit_note_rounded, color: Color(0xFF0F2D69), size: 24),
                            SizedBox(width: 8),
                            Text(
                              'Edit Certificate Details',
                              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF0F2D69)),
                            ),
                          ],
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.of(ctx).pop(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Customize values for this A4 Work Completion Certificate before exporting or sharing.',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(height: 16),

                    // 1. Customer Name
                    TextField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Customer Name *',
                        prefixIcon: Icon(Icons.person_outline_rounded, size: 20),
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // 2. Consumer Number
                    TextField(
                      controller: consumerCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Consumer Number *',
                        prefixIcon: Icon(Icons.numbers_rounded, size: 20),
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // 3. Project Address
                    TextField(
                      controller: addressCtrl,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Project Address *',
                        prefixIcon: Icon(Icons.location_on_outlined, size: 20),
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // 4. Solar Capacity
                    TextField(
                      controller: capacityCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Solar System Capacity *',
                        prefixIcon: Icon(Icons.solar_power_outlined, size: 20),
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: ['3 kW', '3.3 kW', '4 kW', '5 kW', '6 kW', '10 kW'].map((val) {
                        return ActionChip(
                          label: Text('$val Rooftop Solar', style: const TextStyle(fontSize: 11)),
                          padding: EdgeInsets.zero,
                          onPressed: () {
                            setSheetState(() {
                              capacityCtrl.text = '$val Rooftop Solar PV';
                            });
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 14),

                    // 5. Installation Date
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        alignment: Alignment.centerLeft,
                      ),
                      icon: const Icon(Icons.calendar_today_rounded, size: 18, color: Color(0xFF0F2D69)),
                      label: Text(
                        'Installation Date: ${DateFormat('dd MMMM yyyy').format(selectedDate)}',
                        style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.black87),
                      ),
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: selectedDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now().add(const Duration(days: 365)),
                        );
                        if (picked != null) {
                          setSheetState(() => selectedDate = picked);
                        }
                      },
                    ),
                    const SizedBox(height: 20),

                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF0F2D69),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: () {
                        setState(() {
                          _customerName = nameCtrl.text.trim();
                          _consumerNo = consumerCtrl.text.trim();
                          _address = addressCtrl.text.trim();
                          _capacity = capacityCtrl.text.trim();
                          _completionDate = selectedDate;
                          _cachedFile = null; // Invalidate cache to regenerate with edited details
                        });
                        Navigator.of(ctx).pop();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Certificate details updated! Regenerating PDF...'),
                            backgroundColor: Color(0xFF059669),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      },
                      icon: const Icon(Icons.check_circle_outline, size: 18),
                      label: const Text('Apply Changes & Update PDF', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<File?> _ensurePdfGenerated() async {
    if (_cachedFile != null && await _cachedFile!.exists()) {
      return _cachedFile;
    }

    setState(() {
      _isGenerating = true;
      _statusMessage = 'Generating A4 Certificate...';
    });

    try {
      final file = await WorkCompletionCertificateService.generateCertificatePdf(
        customer: widget.customer,
        customCustomerName: _customerName,
        customConsumerNo: _consumerNo,
        customAddress: _address,
        customCapacity: _capacity,
        customCompletionDate: _completionDate,
      );
      if (mounted) {
        setState(() {
          _cachedFile = file;
          _isGenerating = false;
          _statusMessage = null;
        });
      }
      return file;
    } catch (e) {
      debugPrint('Error generating certificate: $e');
      if (mounted) {
        setState(() {
          _isGenerating = false;
          _statusMessage = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to generate PDF: $e'),
            backgroundColor: const Color(0xFFDC2626),
          ),
        );
      }
      return null;
    }
  }

  Future<void> _handlePreview() async {
    final file = await _ensurePdfGenerated();
    if (file != null && mounted) {
      await WorkCompletionCertificateService.previewCertificate(file);
    }
  }

  Future<void> _handleShare() async {
    final file = await _ensurePdfGenerated();
    if (file != null && mounted) {
      await WorkCompletionCertificateService.shareCertificate(file, widget.customer);
    }
  }

  Future<void> _handleDownload() async {
    final file = await _ensurePdfGenerated();
    if (file != null && mounted) {
      setState(() {
        _isGenerating = true;
        _statusMessage = 'Saving to device storage...';
      });

      try {
        final downloaded = await WorkCompletionCertificateService.downloadCertificate(
          file,
          widget.customer,
        );
        if (mounted) {
          setState(() => _isGenerating = false);
          final fileName = downloaded.uri.pathSegments.last;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Saved: $fileName'),
              backgroundColor: const Color(0xFF059669),
              duration: const Duration(seconds: 4),
              action: SnackBarAction(
                label: 'OPEN',
                textColor: Colors.white,
                onPressed: () => WorkCompletionCertificateService.previewCertificate(downloaded),
              ),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isGenerating = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error downloading certificate: $e'),
              backgroundColor: const Color(0xFFDC2626),
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final dateDisplay = DateFormat('dd-MM-yyyy').format(_completionDate);
    final addressDisplay = _address.isNotEmpty ? _address : 'Not Specified';

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      contentPadding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFBFDBFE)),
            ),
            child: const Icon(Icons.workspace_premium_rounded, color: Color(0xFF1D4ED8), size: 24),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Work Completion Certificate',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                ),
                Text(
                  'Bank / Financial Institution Submission A4 PDF',
                  style: TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ],
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Details Header with Edit Button
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Certificate Specifications',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F2D69)),
                ),
                TextButton.icon(
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  icon: const Icon(Icons.edit_note_rounded, size: 16, color: Color(0xFF0F2D69)),
                  label: const Text(
                    'Edit Details',
                    style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF0F2D69)),
                  ),
                  onPressed: _openEditDetailsModal,
                ),
              ],
            ),
            const SizedBox(height: 6),

            // Details Summary Box
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isDark ? Colors.grey.shade900 : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: isDark ? Colors.grey.shade800 : const Color(0xFFE2E8F0)),
              ),
              child: Column(
                children: [
                  _buildDetailRow('Customer Name', _customerName, isBold: true),
                  const Divider(height: 14),
                  _buildDetailRow('Consumer No.', _consumerNo),
                  const Divider(height: 14),
                  _buildDetailRow('Project Address', addressDisplay),
                  const Divider(height: 14),
                  _buildDetailRow('Solar Capacity', _capacity),
                  const Divider(height: 14),
                  _buildDetailRow('Completion Date', dateDisplay),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Format Information Pill
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFECFDF5),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFA7F3D0)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.check_circle_outline, size: 16, color: Color(0xFF059669)),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'A4 Single-Page • Clean Bank-Submission Format',
                      style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF047857)),
                    ),
                  ),
                ],
              ),
            ),

            if (_isGenerating) ...[
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    _statusMessage ?? 'Processing...',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
      actions: [
        // Preview Button
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFF0F2D69),
            side: const BorderSide(color: Color(0xFF0F2D69), width: 1.2),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
          onPressed: _isGenerating ? null : _handlePreview,
          icon: const Icon(Icons.visibility_rounded, size: 17),
          label: const Text('Preview'),
        ),

        // Share Button (WhatsApp, Email, etc.)
        FilledButton.tonalIcon(
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF25D366).withValues(alpha: 0.15),
            foregroundColor: const Color(0xFF128C7E),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
          onPressed: _isGenerating ? null : _handleShare,
          icon: const Icon(Icons.share_rounded, size: 17),
          label: const Text('Share'),
        ),

        // Download Button
        FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF059669),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          ),
          onPressed: _isGenerating ? null : _handleDownload,
          icon: const Icon(Icons.download_rounded, size: 17),
          label: const Text('Download'),
        ),
      ],
    );
  }

  Widget _buildDetailRow(String label, String value, {bool isBold = false}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 110,
          child: Text(
            label,
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ),
        const Text(': ', style: TextStyle(fontSize: 12, color: Colors.grey)),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
              color: isBold ? const Color(0xFF0F2D69) : null,
            ),
          ),
        ),
      ],
    );
  }
}
