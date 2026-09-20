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
    final customer = widget.customer;

    final actualDate = customer.installationDate ?? customer.rtsCompletionDate ?? customer.rtsDate;
    final dateDisplay = actualDate != null ? DateFormat('dd-MM-yyyy').format(actualDate) : 'Not Specified';

    String capacityDisplay = 'Not Specified';
    if (customer.remarks != null && customer.remarks!.trim().isNotEmpty) {
      final match = RegExp(r'(\d+(?:\.\d+)?\s*(?:kw|kW|KW|Kw))').firstMatch(customer.remarks!);
      if (match != null) capacityDisplay = match.group(1)!;
    }

    final addressDisplay = (customer.address != null && customer.address!.trim().isNotEmpty)
        ? customer.address!.trim()
        : ((customer.village != null && customer.village!.trim().isNotEmpty) ? customer.village!.trim() : 'Not Specified');

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
                  _buildDetailRow('Customer Name', customer.name, isBold: true),
                  const Divider(height: 14),
                  _buildDetailRow('Consumer No.', customer.consumerNo),
                  const Divider(height: 14),
                  _buildDetailRow('Project Address', addressDisplay),
                  const Divider(height: 14),
                  _buildDetailRow('Solar Capacity', capacityDisplay),
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
        Row(
          children: [
            // Preview Button
            Expanded(
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                icon: const Icon(Icons.visibility_outlined, size: 16),
                label: const Text('Preview', style: TextStyle(fontSize: 12)),
                onPressed: _isGenerating ? null : _handlePreview,
              ),
            ),
            const SizedBox(width: 8),

            // Share Button
            Expanded(
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF059669),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                icon: const Icon(Icons.share_rounded, size: 16),
                label: const Text('Share', style: TextStyle(fontSize: 12)),
                onPressed: _isGenerating ? null : _handleShare,
              ),
            ),
            const SizedBox(width: 8),

            // Download Button
            Expanded(
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF1D4ED8),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                icon: const Icon(Icons.download_rounded, size: 16),
                label: const Text('Download', style: TextStyle(fontSize: 12)),
                onPressed: _isGenerating ? null : _handleDownload,
              ),
            ),
          ],
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
            style: TextStyle(
              fontSize: 11.5,
              color: Colors.grey.shade600,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}
