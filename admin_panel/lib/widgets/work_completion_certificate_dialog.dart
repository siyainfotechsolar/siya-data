import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
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

  late String _customerName;
  late String _consumerNo;
  late String _address;
  late String _capacity;
  late DateTime _completionDate;
  int _renderKey = 0;

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

  Future<void> _openEditDetailsDialog() async {
    final nameCtrl = TextEditingController(text: _customerName);
    final consumerCtrl = TextEditingController(text: _consumerNo);
    final addressCtrl = TextEditingController(text: _address);
    final capacityCtrl = TextEditingController(text: _capacity);
    DateTime selectedDate = _completionDate;

    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Row(
                children: [
                  Icon(Icons.edit_note_rounded, color: Color(0xFF0F2D69)),
                  SizedBox(width: 8),
                  Text('Edit WCR Certificate Details'),
                ],
              ),
              content: SizedBox(
                width: 520,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Customize the details displayed on the A4 Work Completion Certificate. These changes are applied directly to the exported/printed certificate.',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      const SizedBox(height: 16),

                      // 1. Customer Name
                      TextField(
                        controller: nameCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Customer Name *',
                          prefixIcon: Icon(Icons.person_outline_rounded, size: 18),
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // 2. Consumer Number
                      TextField(
                        controller: consumerCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Consumer Number *',
                          prefixIcon: Icon(Icons.numbers_rounded, size: 18),
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // 3. Project Address
                      TextField(
                        controller: addressCtrl,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          labelText: 'Project Address *',
                          prefixIcon: Icon(Icons.location_on_outlined, size: 18),
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // 4. Solar Capacity
                      TextField(
                        controller: capacityCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Solar System Capacity *',
                          prefixIcon: Icon(Icons.solar_power_outlined, size: 18),
                          border: OutlineInputBorder(),
                          hintText: 'e.g. 3.0 kW Rooftop Solar PV',
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
                              setDialogState(() {
                                capacityCtrl.text = '$val Rooftop Solar PV';
                              });
                            },
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 14),

                      // 5. Installation Date
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
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
                                  setDialogState(() => selectedDate = picked);
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton.icon(
                  style: FilledButton.styleFrom(backgroundColor: const Color(0xFF0F2D69)),
                  onPressed: () {
                    setState(() {
                      _customerName = nameCtrl.text.trim();
                      _consumerNo = consumerCtrl.text.trim();
                      _address = addressCtrl.text.trim();
                      _capacity = capacityCtrl.text.trim();
                      _completionDate = selectedDate;
                      _renderKey++; // Triggers PdfPreview reload with new data
                    });
                    Navigator.of(ctx).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('WCR Certificate details updated!'),
                        backgroundColor: Color(0xFF059669),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                  icon: const Icon(Icons.check_rounded, size: 16),
                  label: const Text('Apply Changes'),
                ),
              ],
            );
          },
        );
      },
    );
  }

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
        width: isCompact ? size.width * 0.95 : 880,
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
                          '$_customerName • $_consumerNo',
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
                    // Edit Details Button
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF0F2D69),
                        side: const BorderSide(color: Color(0xFF0F2D69)),
                        padding: EdgeInsets.symmetric(horizontal: isCompact ? 8 : 12, vertical: 8),
                      ),
                      onPressed: _openEditDetailsDialog,
                      icon: const Icon(Icons.edit_note_rounded, size: 16),
                      label: Text(isCompact ? 'Edit' : 'Edit Details'),
                    ),
                    const SizedBox(width: 8),

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
                              await WorkCompletionCertificateService.downloadCertificatePdf(
                                context,
                                widget.customer,
                                customCustomerName: _customerName,
                                customConsumerNo: _consumerNo,
                                customAddress: _address,
                                customCapacity: _capacity,
                                customCompletionDate: _completionDate,
                              );
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
            const SizedBox(height: 10),

            // Active Certificate Details summary banner
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFCBD5E1), width: 0.8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded, size: 16, color: Color(0xFF0F2D69)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Capacity: $_capacity  •  Date: ${DateFormat('dd-MM-yyyy').format(_completionDate)}  •  Address: ${_address.isNotEmpty ? _address : "Default"}',
                      style: const TextStyle(fontSize: 11, color: Color(0xFF334155), fontWeight: FontWeight.w500),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _openEditDetailsDialog,
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    icon: const Icon(Icons.edit, size: 12, color: Color(0xFF0F2D69)),
                    label: const Text('Change', style: TextStyle(fontSize: 11, color: Color(0xFF0F2D69), fontWeight: FontWeight.bold)),
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
                    key: ValueKey('wcr_preview_$_renderKey'),
                    build: (PdfPageFormat format) async {
                      return WorkCompletionCertificateService.generateCertificatePdfBytes(
                        widget.customer,
                        customCustomerName: _customerName,
                        customConsumerNo: _consumerNo,
                        customAddress: _address,
                        customCapacity: _capacity,
                        customCompletionDate: _completionDate,
                      );
                    },
                    canChangeOrientation: false,
                    canChangePageFormat: false,
                    allowPrinting: true,
                    allowSharing: true,
                    initialPageFormat: PdfPageFormat.a4,
                    pdfFileName: 'Work_Completion_Certificate_$_consumerNo.pdf',
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
