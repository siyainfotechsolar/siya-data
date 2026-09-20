import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import '../models/consumer_record.dart';
import '../services/work_completion_certificate_service.dart';

class WorkCompletionCertificateDialog extends StatefulWidget {
  final ConsumerRecord customer;

  const WorkCompletionCertificateDialog({
    super.key,
    required this.customer,
  });

  static Future<void> show(BuildContext context, ConsumerRecord customer) {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => WorkCompletionCertificateDialog(customer: customer),
    );
  }

  @override
  State<WorkCompletionCertificateDialog> createState() => _WorkCompletionCertificateDialogState();
}

class _WorkCompletionCertificateDialogState extends State<WorkCompletionCertificateDialog> {
  bool _isDownloading = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = MediaQuery.of(context).size;
    final isCompact = size.width < 768;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: EdgeInsets.symmetric(
        horizontal: isCompact ? 12 : 32,
        vertical: isCompact ? 16 : 24,
      ),
      child: Container(
        width: isCompact ? size.width * 0.95 : 860,
        height: size.height * 0.9,
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ==========================================
            // HEADER & ACTION BUTTONS
            // ==========================================
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F2D69).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.verified_outlined,
                        color: Color(0xFF0F2D69),
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Work Completion Certificate',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF0F2D69),
                          ),
                        ),
                        Text(
                          '${widget.customer.name} • ${widget.customer.consumerNo}',
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // WhatsApp notification
                    FilledButton.tonalIcon(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF25D366).withValues(alpha: 0.15),
                        foregroundColor: const Color(0xFF128C7E),
                        padding: EdgeInsets.symmetric(horizontal: isCompact ? 10 : 14, vertical: 8),
                      ),
                      onPressed: () => WorkCompletionCertificateService.sendOnWhatsApp(context, widget.customer),
                      icon: const Icon(Icons.chat_bubble_outline_rounded, size: 16),
                      label: Text(isCompact ? 'WhatsApp' : 'Send WhatsApp'),
                    ),
                    const SizedBox(width: 8),

                    // Download PDF
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF059669),
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(horizontal: isCompact ? 10 : 14, vertical: 8),
                      ),
                      onPressed: _isDownloading
                          ? null
                          : () async {
                              setState(() => _isDownloading = true);
                              await WorkCompletionCertificateService.downloadCertificatePdf(context, widget.customer);
                              if (mounted) setState(() => _isDownloading = false);
                            },
                      icon: _isDownloading
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.download_rounded, size: 16),
                      label: Text(isCompact ? 'Download' : 'Download PDF'),
                    ),
                    const SizedBox(width: 8),

                    // Close button
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      tooltip: 'Close',
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 12),

            // Info notification badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFCBD5E1), width: 0.8),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline_rounded, size: 16, color: Color(0xFF0F2D69)),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Official single-page A4 certificate configured for Bank Loan verification and Financial Institution compliance.',
                      style: TextStyle(fontSize: 12, color: Color(0xFF334155)),
                    ),
                  ),
                ],
              ),
            ),

            // ==========================================
            // LIVE INTERACTIVE PDF PREVIEW
            // ==========================================
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: PdfPreview(
                    build: (PdfPageFormat format) async {
                      return WorkCompletionCertificateService.generateCertificatePdfBytes(widget.customer);
                    },
                    canChangeOrientation: false,
                    canChangePageFormat: false,
                    allowPrinting: true,
                    allowSharing: true,
                    initialPageFormat: PdfPageFormat.a4,
                    pdfFileName: 'Work_Completion_Certificate_${widget.customer.consumerNo}.pdf',
                    loadingWidget: const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(strokeWidth: 3, color: Color(0xFF0F2D69)),
                          SizedBox(height: 12),
                          Text('Generating Work Completion Certificate...', style: TextStyle(fontSize: 13, color: Color(0xFF0F2D69))),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
