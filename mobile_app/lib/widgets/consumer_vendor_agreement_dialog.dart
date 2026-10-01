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

    _totalProjectCost = init?.totalProjectCost ?? (cust.totalAmount != null && cust.totalAmount! > 0 ? cust.totalAmount! : 160000.0);
    _cfaSubsidyAmount = init?.cfaSubsidyAmount ?? 78000.0;
    _netCustomerPayable = init?.netCustomerPayable ?? (_totalProjectCost - _cfaSubsidyAmount);

    if (init != null && init.paymentMilestones.isNotEmpty) {
      _paymentMilestones = List.from(init.paymentMilestones);
    } else {
      _paymentMilestones = ConsumerVendorAgreement.defaultMilestones(_totalProjectCost);
    }
  }

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
      vendorMobile: '7588003220',
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

  /// Primary Action: [ GENERATE AGREEMENT PDF ]
  Future<void> _handleGeneratePdf() async {
    setState(() {
      _isGenerating = true;
      _statusMessage = 'Generating official Agreement PDF...';
    });

    try {
      final agreement = _buildAgreement();
      final file = await ConsumerVendorAgreementPdfService.generateAgreementPdf(
        agreement: agreement,
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

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Agreement PDF Generated: ${file.uri.pathSegments.last}'),
            backgroundColor: const Color(0xFF0F2D69),
            duration: const Duration(seconds: 4),
            action: SnackBarAction(
              label: 'PREVIEW',
              textColor: Colors.white,
              onPressed: () => ConsumerVendorAgreementPdfService.previewAgreement(file),
            ),
          ),
        );
      }
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
    }
  }

  Future<void> _handlePreviewPdf() async {
    if (_generatedFile == null || !await _generatedFile!.exists()) {
      await _handleGeneratePdf();
    }
    if (_generatedFile != null && mounted) {
      await ConsumerVendorAgreementPdfService.previewAgreement(_generatedFile!);
    }
  }

  Future<void> _handleSharePdf() async {
    if (_generatedFile == null || !await _generatedFile!.exists()) {
      await _handleGeneratePdf();
    }
    if (_generatedFile != null && mounted) {
      final agreement = _buildAgreement();
      await ConsumerVendorAgreementPdfService.shareAgreement(_generatedFile!, agreement);
    }
  }

  Future<void> _handleDownloadPdf() async {
    if (_generatedFile == null || !await _generatedFile!.exists()) {
      await _handleGeneratePdf();
    }
    if (_generatedFile != null && mounted) {
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
        final savedFile = await _generatedFile!.copy(targetPath);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Downloaded: ${savedFile.uri.pathSegments.last}'),
              backgroundColor: const Color(0xFF047857),
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
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520, maxHeight: 720),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F2D69).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.picture_as_pdf_outlined, color: Color(0xFF0F2D69), size: 22),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Consumer-Vendor Agreement',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F2D69)),
                        ),
                        Text(
                          'PM Surya Ghar: Muft Bijli Yojana • Official Annexure 2',
                          style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const Divider(height: 18),

              // Body
              Expanded(
                child: ListView(
                  children: [
                    // Auto-fill Details Card
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('AUTO-FILLED CUSTOMER DATA', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
                              Text('Date: ${DateFormat('dd-MM-yyyy').format(_executionDate)}', style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF0F2D69))),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(_customerName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A))),
                          const SizedBox(height: 2),
                          Text('Consumer No: $_consumerNo  •  Mobile: ${_customerMobile.isNotEmpty ? _customerMobile : "N/A"}', style: const TextStyle(fontSize: 11, color: Color(0xFF334155))),
                          Text('Address: $_customerAddress', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                          const Divider(height: 14),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _buildMetricItem('Capacity', _systemCapacity),
                              _buildMetricItem('Project Cost', currencyFmt.format(_totalProjectCost)),
                              _buildMetricItem('Govt Subsidy', currencyFmt.format(_cfaSubsidyAmount)),
                              _buildMetricItem('Net Payable', currencyFmt.format(_netCustomerPayable)),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Payment Milestones Overview & Edit
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFCBD5E1)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('PAYMENT TABLE (Clause 19)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5, color: Color(0xFF0F2D69))),
                              TextButton(
                                style: TextButton.styleFrom(padding: EdgeInsets.zero, visualDensity: VisualDensity.compact),
                                onPressed: _openEditPaymentTableModal,
                                child: const Text('Edit Milestones', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          ..._paymentMilestones.map((m) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 2.0),
                              child: Row(
                                children: [
                                  Text('${m.sr}. ${m.stage} (${m.percentage.toStringAsFixed(0)}%):', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                                  const Spacer(),
                                  Text(currencyFmt.format(m.amount), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Primary Button: [ GENERATE AGREEMENT PDF ]
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF0F2D69),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: _isGenerating ? null : _handleGeneratePdf,
                      icon: _isGenerating
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.picture_as_pdf, size: 20),
                      label: Text(
                        _isGenerating ? (_statusMessage ?? 'Generating...') : 'GENERATE AGREEMENT PDF',
                        style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                      ),
                    ),

                    // Actions after generation
                    if (_generatedFile != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFECFDF5),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFA7F3D0)),
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.check_circle, color: Color(0xFF047857), size: 18),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    'PDF Ready: ${_generatedFile!.uri.pathSegments.last}',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF065F46)),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 10), visualDensity: VisualDensity.compact),
                                    onPressed: _handlePreviewPdf,
                                    icon: const Icon(Icons.preview_rounded, size: 16),
                                    label: const Text('Preview PDF', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: OutlinedButton.icon(
                                    style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 10), visualDensity: VisualDensity.compact),
                                    onPressed: _handleSharePdf,
                                    icon: const Icon(Icons.share_outlined, size: 16),
                                    label: const Text('Share PDF', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: FilledButton.tonal(
                                    style: FilledButton.styleFrom(
                                      backgroundColor: const Color(0xFF047857),
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(vertical: 10),
                                      visualDensity: VisualDensity.compact,
                                    ),
                                    onPressed: _handleDownloadPdf,
                                    child: const Text('Download', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],

                    // History Section
                    if (_previousAgreements.isNotEmpty) ...[
                      const Divider(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Previous Agreements (${_previousAgreements.length})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5, color: Color(0xFF0F2D69))),
                          const Text('Annexure 2 A4 PDF', style: TextStyle(fontSize: 10, color: Colors.grey)),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ..._previousAgreements.take(3).map((agr) {
                        return Container(
                          margin: const EdgeInsets.only(bottom: 6),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.picture_as_pdf_outlined, color: Color(0xFFDC2626), size: 16),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  '${agr.agreementNo} • ${agr.systemCapacity}',
                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                                ),
                              ),
                              TextButton(
                                style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), minimumSize: Size.zero),
                                onPressed: () async {
                                  if (agr.pdfFilePath != null && File(agr.pdfFilePath!).existsSync()) {
                                    ConsumerVendorAgreementPdfService.previewAgreement(File(agr.pdfFilePath!));
                                  } else {
                                    final file = await ConsumerVendorAgreementPdfService.generateAgreementPdf(agreement: agr);
                                    ConsumerVendorAgreementPdfService.previewAgreement(file);
                                  }
                                },
                                child: const Text('View', style: TextStyle(fontSize: 11)),
                              ),
                              const SizedBox(width: 4),
                              IconButton(
                                icon: const Icon(Icons.share_outlined, size: 16, color: Color(0xFF0F2D69)),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                tooltip: 'Share',
                                onPressed: () async {
                                  final file = (agr.pdfFilePath != null && File(agr.pdfFilePath!).existsSync())
                                      ? File(agr.pdfFilePath!)
                                      : await ConsumerVendorAgreementPdfService.generateAgreementPdf(agreement: agr);
                                  ConsumerVendorAgreementPdfService.shareAgreement(file, agr);
                                },
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetricItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 10, color: Color(0xFF64748B))),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF0F2D69))),
      ],
    );
  }
}
