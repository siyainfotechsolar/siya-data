import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';

import '../models/consumer_record.dart';
import '../models/consumer_vendor_agreement.dart';
import '../services/agreement_storage_service.dart';
import '../services/consumer_vendor_agreement_pdf_service.dart';

/// Simple, focused PDF Generator for Consumer-Vendor Agreement (Annexure 2)
/// Directly auto-fills from Customer Profile, allows editing payment milestones,
/// and generates the official A4 Agreement PDF.
class ConsumerVendorAgreementDialog extends StatefulWidget {
  final ConsumerRecord customer;
  final ConsumerVendorAgreement? initialAgreement;

  const ConsumerVendorAgreementDialog({
    super.key,
    required this.customer,
    this.initialAgreement,
  });

  static Future<void> show(
    BuildContext context, {
    required ConsumerRecord customer,
    ConsumerVendorAgreement? initialAgreement,
  }) {
    return showDialog<void>(
      context: context,
      builder: (ctx) => ConsumerVendorAgreementDialog(
        customer: customer,
        initialAgreement: initialAgreement,
      ),
    );
  }

  @override
  State<ConsumerVendorAgreementDialog> createState() => _ConsumerVendorAgreementDialogState();
}

class _ConsumerVendorAgreementDialogState extends State<ConsumerVendorAgreementDialog> {
  bool _isGenerating = false;
  File? _generatedFile;
  String? _statusMessage;

  // Auto-filled Fields
  late String _customerName;
  late String _consumerNo;
  late String _customerMobile;
  late String _customerAddress;
  late String _villageCity;
  late String _district;
  late String _agreementNo;
  late DateTime _executionDate;
  late String _systemCapacity;
  late double _totalProjectCost;
  late double _cfaSubsidyAmount;
  late double _netCustomerPayable;

  late List<PaymentMilestone> _paymentMilestones;

  List<ConsumerVendorAgreement> _previousAgreements = [];
  final currencyFmt = NumberFormat.currency(locale: 'en_IN', symbol: 'Rs. ', decimalDigits: 0);

  @override
  void initState() {
    super.initState();
    _initAutoFillFields();
    _loadHistory();
  }

  void _initAutoFillFields() {
    final cust = widget.customer;
    final init = widget.initialAgreement;

    _customerName = init?.customerName ?? cust.name.trim();
    _consumerNo = init?.consumerNo ?? cust.consumerNo.trim();
    _customerMobile = init?.customerMobile ?? cust.mobile?.trim() ?? '';

    final fullAddr = init?.customerAddress ?? (cust.address?.trim().isNotEmpty == true
        ? cust.address!.trim()
        : (cust.village?.trim().isNotEmpty == true ? cust.village!.trim() : 'Betawad, Tal. Shindkheda'));
    _customerAddress = fullAddr;
    _villageCity = init?.villageCity ?? (cust.village?.trim().isNotEmpty == true ? cust.village!.trim() : 'Betawad');
    _district = init?.district ?? 'Dhule';

    _executionDate = init?.executionDate ?? DateTime.now();
    final suffix = _consumerNo.length > 4 ? _consumerNo.substring(_consumerNo.length - 4) : _consumerNo;
    _agreementNo = init?.agreementNo ?? 'SIYA-AGR-${_executionDate.year}-$suffix';

    String cap = init?.systemCapacity ?? cust.systemCapacity?.trim() ?? '';
    if (cap.isEmpty && cust.remarks != null && cust.remarks!.trim().isNotEmpty) {
      final match = RegExp(r'(\d+(?:\.\d+)?\s*(?:kw|kW|KW|Kw))').firstMatch(cust.remarks!);
      if (match != null) cap = match.group(1)!;
    }
    _systemCapacity = cap.isNotEmpty ? cap : '3 kW';

    _totalProjectCost = init?.totalProjectCost ?? (cust.totalAmount > 0 ? cust.totalAmount : 0.0);
    _cfaSubsidyAmount = init?.cfaSubsidyAmount ?? 78000.0;
    _netCustomerPayable = init?.netCustomerPayable ?? (_totalProjectCost > 0 ? (_totalProjectCost - _cfaSubsidyAmount).clamp(0.0, double.infinity) : 0.0);

    if (init != null && init.paymentMilestones.isNotEmpty) {
      _paymentMilestones = List.from(init.paymentMilestones);
    } else {
      _paymentMilestones = ConsumerVendorAgreement.defaultMilestones(_totalProjectCost);
    }
  }

  bool _includeStampAndSignature = false;

  Future<void> _loadHistory() async {
    final history = await AgreementStorageService.getAgreementsForCustomer(_consumerNo);
    if (mounted) {
      setState(() => _previousAgreements = history);
    }
  }

  ConsumerVendorAgreement _buildAgreement() {
    return ConsumerVendorAgreement(
      id: widget.initialAgreement?.id ?? 'agr_${DateTime.now().millisecondsSinceEpoch}',
      customerId: widget.customer.id,
      consumerNo: _consumerNo,
      customerName: _customerName,
      customerAddress: _customerAddress,
      villageCity: _villageCity,
      district: _district,
      customerMobile: _customerMobile,
      vendorFirmName: 'SIYA INFOTECH & DIGITAL SOLUTIONS',
      vendorGstin: '27CVTPK6358P1ZD',
      vendorAddress: '21, Mudavad Road, Betawad, Tal. Shindkheda, Dist. Dhule - 425403',
      vendorMobile: '7972143798',
      vendorEmail: 'siyainfodigital@gmail.com',
      systemCapacity: _systemCapacity,
      systemType: 'Grid-Connected Rooftop Solar PV',
      totalProjectCost: _totalProjectCost,
      cfaSubsidyAmount: _cfaSubsidyAmount,
      netCustomerPayable: _netCustomerPayable,
      executionDate: _executionDate,
      agreementNo: _agreementNo,
      discomName: 'MSEDCL',
      paymentMilestones: _paymentMilestones,
      pdfFilePath: _generatedFile?.path,
      createdAt: widget.initialAgreement?.createdAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  Future<File?> _ensurePdfGenerated() async {
    if (_generatedFile != null && await _generatedFile!.exists()) {
      return _generatedFile;
    }
    setState(() {
      _isGenerating = true;
      _statusMessage = 'Generating official Agreement PDF...';
    });

    try {
      final agreement = _buildAgreement();
      final file = await ConsumerVendorAgreementPdfService.generateAgreementPdf(
        agreement: agreement,
        includeStampAndSignature: _includeStampAndSignature,
      );

      final updatedAgreement = agreement.copyWith(pdfFilePath: file.path);
      await AgreementStorageService.saveAgreement(updatedAgreement);

      if (mounted) {
        setState(() {
          _generatedFile = file;
          _isGenerating = false;
          _statusMessage = null;
        });
        _loadHistory();
      }
      return file;
    } catch (e) {
      debugPrint('Error generating agreement PDF: $e');
      if (mounted) {
        setState(() {
          _isGenerating = false;
          _statusMessage = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to generate PDF: $e'), backgroundColor: Colors.red),
        );
      }
      return null;
    }
  }

  Future<void> _handlePreviewPdf() async {
    final file = await _ensurePdfGenerated();
    if (file != null && mounted) {
      await ConsumerVendorAgreementPdfService.previewAgreement(file);
    }
  }

  Future<void> _handleSharePdf() async {
    final file = await _ensurePdfGenerated();
    if (file != null && mounted) {
      final agreement = _buildAgreement();
      await ConsumerVendorAgreementPdfService.shareAgreement(file, agreement);
    }
  }

  Future<void> _handleDownloadPdf() async {
    final file = await _ensurePdfGenerated();
    if (file != null && mounted) {
      setState(() {
        _isGenerating = true;
        _statusMessage = 'Saving to device storage...';
      });

      try {
        final agreement = _buildAgreement();
        Directory? downloadDir;
        try {
          downloadDir = Directory('/storage/emulated/0/Download');
          if (!await downloadDir.exists()) {
            downloadDir = await getApplicationDocumentsDirectory();
          }
        } catch (_) {
          downloadDir = await getApplicationDocumentsDirectory();
        }

        final targetPath = '${downloadDir.path}/${agreement.pdfFileName}';
        final savedFile = await file.copy(targetPath);

        if (mounted) {
          setState(() => _isGenerating = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Saved: ${savedFile.uri.pathSegments.last}'),
              backgroundColor: const Color(0xFF047857),
              duration: const Duration(seconds: 4),
              action: SnackBarAction(
                label: 'OPEN',
                textColor: Colors.white,
                onPressed: () => ConsumerVendorAgreementPdfService.previewAgreement(savedFile),
              ),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isGenerating = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Download failed: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  /// Edit Milestone Payment Terms Dialog
  Future<void> _openEditPaymentTableModal() async {
    final costCtrl = TextEditingController(text: _totalProjectCost.toStringAsFixed(0));
    final subsidyCtrl = TextEditingController(text: _cfaSubsidyAmount.toStringAsFixed(0));
    final capCtrl = TextEditingController(text: _systemCapacity);
    DateTime tempExecutionDate = _executionDate;
    List<PaymentMilestone> tempMilestones = _paymentMilestones.map((m) => m.copyWith()).toList();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final currentCost = double.tryParse(costCtrl.text.trim()) ?? 0.0;
            final currentSubsidy = double.tryParse(subsidyCtrl.text.trim()) ?? 0.0;
            final netPayable = currentCost - currentSubsidy;

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom + 16,
                left: 16,
                right: 16,
                top: 16,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Payment Table (Clause 19)',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F2D69)),
                        ),
                        TextButton.icon(
                          icon: const Icon(Icons.refresh, size: 16),
                          label: const Text('Reset 20-60-20'),
                          onPressed: () {
                            setSheetState(() {
                              tempMilestones = ConsumerVendorAgreement.defaultMilestones(currentCost);
                            });
                          },
                        ),
                      ],
                    ),
                    const Divider(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: capCtrl,
                            decoration: const InputDecoration(labelText: 'Capacity (e.g. 3 kW)', isDense: true, border: OutlineInputBorder()),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: costCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(labelText: 'Total Cost (Rs.)', isDense: true, border: OutlineInputBorder()),
                            onChanged: (_) => setSheetState(() {}),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: subsidyCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(labelText: 'Govt. Subsidy (Rs.)', isDense: true, border: OutlineInputBorder()),
                            onChanged: (_) => setSheetState(() {}),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Net Customer Payable: ${currencyFmt.format(netPayable)}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF0F2D69)),
                    ),
                    const SizedBox(height: 12),
                    InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: tempExecutionDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2035),
                        );
                        if (picked != null) {
                          setSheetState(() => tempExecutionDate = picked);
                        }
                      },
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Agreement Date *',
                          border: OutlineInputBorder(),
                          isDense: true,
                          prefixIcon: Icon(Icons.calendar_today_rounded, size: 16, color: Color(0xFF0F2D69)),
                        ),
                        child: Text(
                          DateFormat('dd MMMM yyyy').format(tempExecutionDate),
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    ...tempMilestones.asMap().entries.map((entry) {
                      final idx = entry.key;
                      final m = entry.value;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                          borderRadius: BorderRadius.circular(8),
                          color: const Color(0xFFF8FAFC),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text('${m.sr}. ${m.stage}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                const Spacer(),
                                Text('${m.percentage.toStringAsFixed(0)}% • ${currencyFmt.format(m.amount)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF0F2D69))),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                SizedBox(
                                  width: 65,
                                  child: TextFormField(
                                    initialValue: m.percentage.toStringAsFixed(0),
                                    keyboardType: TextInputType.number,
                                    decoration: const InputDecoration(labelText: 'Share %', isDense: true, border: OutlineInputBorder()),
                                    onChanged: (val) {
                                      final pct = double.tryParse(val.trim()) ?? 0.0;
                                      final amt = (currentCost * pct) / 100.0;
                                      setSheetState(() {
                                        tempMilestones[idx] = m.copyWith(percentage: pct, amount: amt);
                                      });
                                    },
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: TextFormField(
                                    initialValue: m.description,
                                    decoration: const InputDecoration(labelText: 'Payment Due Condition', isDense: true, border: OutlineInputBorder()),
                                    onChanged: (val) {
                                      tempMilestones[idx] = m.copyWith(description: val.trim());
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    }),
                    const SizedBox(height: 14),
                    FilledButton(
                      style: FilledButton.styleFrom(backgroundColor: const Color(0xFF0F2D69), padding: const EdgeInsets.symmetric(vertical: 12)),
                      onPressed: () {
                        final c = double.tryParse(costCtrl.text.trim()) ?? _totalProjectCost;
                        final s = double.tryParse(subsidyCtrl.text.trim()) ?? _cfaSubsidyAmount;
                        final updated = tempMilestones.map((m) {
                          return m.copyWith(amount: (c * m.percentage) / 100.0);
                        }).toList();

                        setState(() {
                          _systemCapacity = capCtrl.text.trim();
                          _totalProjectCost = c;
                          _cfaSubsidyAmount = s;
                          _netCustomerPayable = c - s;
                          _paymentMilestones = updated;
                          _executionDate = tempExecutionDate;
                          _generatedFile = null; // Re-generate needed
                        });

                        Navigator.of(context).pop();
                      },
                      child: const Text('Save Payment Table Changes', style: TextStyle(fontWeight: FontWeight.bold)),
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

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
            child: const Icon(Icons.handshake_outlined, color: Color(0xFF0F2D69), size: 24),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Consumer-Vendor Agreement',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                ),
                Text(
                  'PM Surya Ghar: Muft Bijli Yojana • Annexure 2',
                  style: TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ],
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 500,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header with Edit Payment Table Button
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Agreement Specifications',
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
                      'Edit Milestones',
                      style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF0F2D69)),
                    ),
                    onPressed: _openEditPaymentTableModal,
                  ),
                ],
              ),
              const SizedBox(height: 6),

              // Summary Box (matching WCR layout)
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
                    const Divider(height: 12),
                    _buildDetailRow('Consumer No.', _consumerNo),
                    const Divider(height: 12),
                    _buildDetailRow('Agreement No.', _agreementNo),
                    const Divider(height: 12),
                    _buildDetailRow('Project Address', _customerAddress),
                    const Divider(height: 12),
                    _buildDetailRow('Solar Capacity', _systemCapacity),
                    const Divider(height: 12),
                    _buildDetailRow('Total Project Cost', currencyFmt.format(_totalProjectCost)),
                    const Divider(height: 12),
                    _buildDetailRow('Govt Subsidy (CFA)', currencyFmt.format(_cfaSubsidyAmount)),
                    const Divider(height: 12),
                    _buildDetailRow('Net Payable', currencyFmt.format(_netCustomerPayable), isBold: true),
                  ],
                ),
              ),
              const SizedBox(height: 10),

              // Payment Milestones Mini Card
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Payment Milestones (Clause 19)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF0F2D69))),
                        Text('${_paymentMilestones.length} Stages', style: const TextStyle(fontSize: 10, color: Color(0xFF64748B))),
                      ],
                    ),
                    const SizedBox(height: 4),
                    ..._paymentMilestones.map((m) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 1.5),
                      child: Row(
                        children: [
                          Text('${m.sr}. ${m.stage} (${m.percentage.toStringAsFixed(0)}%):', style: const TextStyle(fontSize: 10.5, color: Color(0xFF334155))),
                          const Spacer(),
                          Text(currencyFmt.format(m.amount), style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    )),
                  ],
                ),
              ),
              const SizedBox(height: 10),

              // Option: [ Remove Stamp & Signature ] / [ Include Stamp & Signature ]
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    if (_includeStampAndSignature)
                      InkWell(
                        onTap: () {
                          setState(() {
                            _includeStampAndSignature = false;
                            _generatedFile = null;
                          });
                        },
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF2F2),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFFCA5A5)),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.remove_circle_outline_rounded, size: 14, color: Color(0xFFDC2626)),
                              SizedBox(width: 6),
                              Text(
                                'Remove Stamp & Signature',
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFFDC2626)),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      InkWell(
                        onTap: () {
                          setState(() {
                            _includeStampAndSignature = true;
                            _generatedFile = null;
                          });
                        },
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: const Color(0xFFECFDF5),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFA7F3D0)),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.verified_rounded, size: 14, color: Color(0xFF047857)),
                              SizedBox(width: 6),
                              Text(
                                'Include Stamp & Signature',
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF047857)),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              // Format Info Pill (identical to WCR)
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
                        'A4 Agreement • Official PM Surya Ghar Model Draft',
                        style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF047857)),
                      ),
                    ),
                  ],
                ),
              ),

              if (_isGenerating) ...[
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      _statusMessage ?? 'Processing Agreement...',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ],

              // Previous Agreements (Collapsible/compact if available)
              if (_previousAgreements.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text('Saved Customer Agreements (${_previousAgreements.length})', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0F2D69))),
                const SizedBox(height: 4),
                ..._previousAgreements.take(2).map((agr) => Container(
                  margin: const EdgeInsets.only(bottom: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.picture_as_pdf_outlined, color: Color(0xFFDC2626), size: 14),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          '${agr.agreementNo} • ${agr.systemCapacity}',
                          style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600),
                        ),
                      ),
                      TextButton(
                        style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0), minimumSize: Size.zero),
                        onPressed: () async {
                          if (agr.pdfFilePath != null && File(agr.pdfFilePath!).existsSync()) {
                            ConsumerVendorAgreementPdfService.previewAgreement(File(agr.pdfFilePath!));
                          } else {
                            final file = await ConsumerVendorAgreementPdfService.generateAgreementPdf(agreement: agr);
                            ConsumerVendorAgreementPdfService.previewAgreement(file);
                          }
                        },
                        child: const Text('View', style: TextStyle(fontSize: 10.5)),
                      ),
                    ],
                  ),
                )),
              ],
            ],
          ),
        ),
      ),
      actions: [
        // Preview Button (Identical to WCR)
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFF0F2D69),
            side: const BorderSide(color: Color(0xFF0F2D69), width: 1.2),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
          onPressed: _isGenerating ? null : _handlePreviewPdf,
          icon: const Icon(Icons.visibility_rounded, size: 17),
          label: const Text('Preview'),
        ),

        // Share Button (Identical to WCR)
        FilledButton.tonalIcon(
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF25D366).withValues(alpha: 0.15),
            foregroundColor: const Color(0xFF128C7E),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
          onPressed: _isGenerating ? null : _handleSharePdf,
          icon: const Icon(Icons.share_rounded, size: 17),
          label: const Text('Share'),
        ),

        // Download Button (Identical to WCR)
        FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF059669),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          ),
          onPressed: _isGenerating ? null : _handleDownloadPdf,
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
