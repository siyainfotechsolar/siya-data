import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';

import '../models/invoice.dart';
import '../services/invoice_pdf_service.dart';

/// Full-screen dialog for Invoice Preview, Edit, PDF, Share, Download
class InvoiceDetailsDialog extends StatefulWidget {
  final Invoice invoice;
  final VoidCallback? onUpdated;

  const InvoiceDetailsDialog({
    super.key,
    required this.invoice,
    this.onUpdated,
  });

  /// Open as full-screen dialog
  static Future<void> show(BuildContext context, Invoice invoice, {VoidCallback? onUpdated}) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => InvoiceDetailsDialog(invoice: invoice, onUpdated: onUpdated),
    );
  }

  @override
  State<InvoiceDetailsDialog> createState() => _InvoiceDetailsDialogState();
}

class _InvoiceDetailsDialogState extends State<InvoiceDetailsDialog> {
  late Invoice _invoice;
  bool _includeStampAndSignature = false;
  int _selectedTab = 0; // 0 = Details, 1 = PDF Preview
  UniqueKey _renderKey = UniqueKey();
  bool _isGenerating = false;
  final _inr = NumberFormat('#,##,##0.00', 'en_IN');

  @override
  void initState() {
    super.initState();
    _invoice = widget.invoice;
    _includeStampAndSignature = _invoice.includeStampAndSignature;
  }

  void _refreshPreview() {
    setState(() => _renderKey = UniqueKey());
  }

  Future<Uint8List> _generatePdfBytes() async {
    return InvoicePdfService.generateInvoicePdfBytes(
      _invoice,
      includeStampAndSignature: _includeStampAndSignature,
    );
  }

  Future<void> _printInvoice() async {
    setState(() => _isGenerating = true);
    try {
      final bytes = await _generatePdfBytes();
      await Printing.layoutPdf(onLayout: (_) => bytes);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Print error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  Future<void> _downloadInvoice() async {
    setState(() => _isGenerating = true);
    try {
      final bytes = await _generatePdfBytes();
      await Printing.sharePdf(
        bytes: bytes,
        filename: _invoice.pdfFileName ?? 'Invoice.pdf',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Download error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  Future<void> _shareWhatsApp() async {
    await InvoicePdfService.shareOnWhatsApp(_invoice);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    return Dialog(
      insetPadding: EdgeInsets.symmetric(
        horizontal: isMobile ? 8 : 40,
        vertical: isMobile ? 8 : 24,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: SizedBox(
          width: isMobile ? double.infinity : 900,
          height: MediaQuery.of(context).size.height * (isMobile ? 0.95 : 0.9),
          child: Scaffold(
            backgroundColor: theme.scaffoldBackgroundColor,
            appBar: AppBar(
              elevation: 0,
              scrolledUnderElevation: 1,
              leading: IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).pop(),
              ),
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _invoice.invoiceNumber,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                  ),
                  Text(
                    'Ref: ${_invoice.refInvoiceNo}',
                    style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
                  ),
                ],
              ),
              actions: [
                if (_isGenerating)
                  const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                  )
                else ...[
                  IconButton(
                    icon: const Icon(Icons.print_rounded, size: 20),
                    tooltip: 'Print',
                    onPressed: _printInvoice,
                  ),
                  IconButton(
                    icon: const Icon(Icons.download_rounded, size: 20),
                    tooltip: 'Download',
                    onPressed: _downloadInvoice,
                  ),
                  IconButton(
                    icon: Icon(Icons.share_rounded, size: 20, color: Colors.green.shade700),
                    tooltip: 'WhatsApp',
                    onPressed: _shareWhatsApp,
                  ),
                ],
              ],
            ),
            body: Column(
              children: [
                // ── Tab Switcher ─────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: _buildTabButton(
                          label: 'Details',
                          icon: Icons.info_outline_rounded,
                          isActive: _selectedTab == 0,
                          onTap: () => setState(() => _selectedTab = 0),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildTabButton(
                          label: 'PDF Preview',
                          icon: Icons.picture_as_pdf_rounded,
                          isActive: _selectedTab == 1,
                          onTap: () => setState(() => _selectedTab = 1),
                        ),
                      ),
                    ],
                  ),
                ),

                // ── Controls Row ─────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    alignment: WrapAlignment.center,
                    children: [
                      FilterChip(
                        label: Text(
                          _includeStampAndSignature ? 'Remove Stamp & Signature' : 'Add Stamp & Signature',
                          style: const TextStyle(fontSize: 11),
                        ),
                        selected: _includeStampAndSignature,
                        onSelected: (v) {
                          setState(() {
                            _includeStampAndSignature = v;
                            _refreshPreview();
                          });
                        },
                        avatar: Icon(
                          _includeStampAndSignature ? Icons.verified_rounded : Icons.remove_circle_outline,
                          size: 16,
                        ),
                        selectedColor: cs.primaryContainer,
                      ),
                      // Payment Status Chip
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: _statusColor(_invoice.paymentStatus).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: _statusColor(_invoice.paymentStatus).withValues(alpha: 0.4)),
                        ),
                        child: Text(
                          _invoice.paymentStatus,
                          style: TextStyle(
                            color: _statusColor(_invoice.paymentStatus),
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const Divider(height: 1),

                // ── Body ────────────────────────────────────────────────
                Expanded(
                  child: _selectedTab == 0 ? _buildDetailsView(theme) : _buildPdfPreview(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTabButton({
    required String label,
    required IconData icon,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: isActive ? cs.primaryContainer : cs.surfaceContainerHighest.withValues(alpha: 0.5),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          alignment: Alignment.center,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: isActive ? cs.primary : cs.onSurfaceVariant),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                  color: isActive ? cs.primary : cs.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'Paid':
        return const Color(0xFF059669);
      case 'Partially Paid':
        return const Color(0xFF0284C7);
      default:
        return const Color(0xFFD97706);
    }
  }

  // ── Details View ────────────────────────────────────────────────────────────

  Widget _buildDetailsView(ThemeData theme) {
    final cs = theme.colorScheme;
    final gst = _invoice.gstBreakdown;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Invoice Info
          _buildDetailCard(
            title: 'Invoice Information',
            icon: Icons.receipt_long_rounded,
            children: [
              _detailRow('Invoice No.', _invoice.invoiceNumber, isBold: true),
              _detailRow('Ref. Invoice No.', _invoice.refInvoiceNo),
              _detailRow('Invoice Date', _invoice.formattedDate),
              _detailRow('System', '${_invoice.systemCapacity} - ${_invoice.systemType}'),
            ],
          ),
          const SizedBox(height: 12),

          // Customer Details
          _buildDetailCard(
            title: 'Customer Details',
            icon: Icons.person_rounded,
            children: [
              _detailRow('Name', _invoice.customerName, isBold: true),
              _detailRow('Consumer No.', _invoice.consumerNo),
              _detailRow('Mobile', _invoice.mobileNo),
              _detailRow('Address', _invoice.address),
              _detailRow('Village / City', _invoice.villageCity),
              _detailRow('District', _invoice.district),
            ],
          ),
          const SizedBox(height: 12),

          // Items
          _buildDetailCard(
            title: 'Invoice Items',
            icon: Icons.list_alt_rounded,
            children: [
              ..._invoice.items.asMap().entries.map((e) {
                final item = e.value;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    children: [
                      SizedBox(width: 24, child: Text('${e.key + 1}.', style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12))),
                      Expanded(
                        child: Text(
                          '${item['item'] ?? item['description'] ?? ''} — ${item['spec'] ?? item['specification'] ?? ''}',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                      SizedBox(width: 60, child: Text(item['qty'] ?? '', style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant), textAlign: TextAlign.right)),
                    ],
                  ),
                );
              }),
            ],
          ),
          const SizedBox(height: 12),

          // Financial
          _buildDetailCard(
            title: 'Financial Summary (GST Inclusive)',
            icon: Icons.account_balance_wallet_rounded,
            children: [
              _detailRow('Taxable Amount', '₹ ${_inr.format(gst.totalTaxableValue)}'),
              _detailRow('GST @ 5% (70% Portion)', '₹ ${_inr.format(gst.gst5)}'),
              _detailRow('GST @ 18% (30% Portion)', '₹ ${_inr.format(gst.gst18)}'),
              _detailRow('Total GST Included', '₹ ${_inr.format(gst.totalGstIncluded)}'),
              const Divider(height: 12),
              _detailRow('GRAND TOTAL', '₹ ${_inr.format(_invoice.grandTotal)}', isBold: true),
              _detailRow('Amount in Words', _invoice.amountInWords),
            ],
          ),
          const SizedBox(height: 12),

          // Payment
          _buildDetailCard(
            title: 'Payment Details',
            icon: Icons.payments_rounded,
            children: [
              _detailRow('Total Invoice Amount', '₹ ${_inr.format(_invoice.grandTotal)}'),
              _detailRow('Total Paid', '₹ ${_inr.format(_invoice.totalPaid)}'),
              _detailRow('Total Pending', '₹ ${_inr.format(_invoice.totalPending)}'),
              _detailRow('Payment Status', _invoice.paymentStatus, isBold: true),
            ],
          ),
          const SizedBox(height: 12),

          // Helpline
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: cs.primaryContainer.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: cs.primary.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                Icon(Icons.phone, size: 18, color: cs.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Helpline: 7972143798  |  Owner: Manoj Kshirsagar',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: cs.onSurface),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildDetailCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.5)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 4, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
            child: Row(
              children: [
                Icon(icon, size: 16, color: cs.primary),
                const SizedBox(width: 6),
                Text(title, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: cs.primary)),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value, {bool isBold = false}) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant, fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: Text(
              value.isNotEmpty ? value : '—',
              style: TextStyle(fontSize: 12, fontWeight: isBold ? FontWeight.w700 : FontWeight.w400),
            ),
          ),
        ],
      ),
    );
  }

  // ── PDF Preview ─────────────────────────────────────────────────────────────

  Widget _buildPdfPreview() {
    return PdfPreview(
      key: _renderKey,
      build: (_) => _generatePdfBytes(),
      canChangeOrientation: false,
      canChangePageFormat: false,
      canDebug: false,
      allowSharing: true,
      allowPrinting: true,
      pdfFileName: _invoice.pdfFileName ?? 'Invoice.pdf',
    );
  }
}
