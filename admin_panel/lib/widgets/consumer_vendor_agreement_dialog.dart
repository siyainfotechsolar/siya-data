import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import '../models/consumer_record.dart';
import '../models/consumer_vendor_agreement.dart';
import '../services/agreement_storage_service.dart';
import '../services/consumer_vendor_agreement_service.dart';

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
      barrierDismissible: true,
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

  int _renderKey = 0;
  final currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: 'Rs. ', decimalDigits: 0);

  @override
  void initState() {
    super.initState();
    _initFields();
  }

  void _initFields() {
    final cust = widget.customer;
    final init = widget.initialAgreement;

    _customerName = init?.customerName ?? cust.name.trim();
    _consumerNo = init?.consumerNo ?? cust.consumerNo.trim();
    _customerMobile = init?.customerMobile ?? cust.mobile?.trim() ?? '';

    final addr = init?.customerAddress ?? (cust.address?.trim().isNotEmpty == true
        ? cust.address!.trim()
        : (cust.village?.trim().isNotEmpty == true ? cust.village!.trim() : 'Betawad'));
    _customerAddress = addr;
    _villageCity = init?.villageCity ?? (cust.village?.trim().isNotEmpty == true ? cust.village!.trim() : (_customerAddress.split(',').firstOrNull?.trim() ?? 'Betawad'));
    _district = init?.district ?? (_customerAddress.toLowerCase().contains('dhule') ? 'Dhule' : 'Dhule');

    _executionDate = init?.executionDate ?? DateTime.now();
    final suffix = _consumerNo.length > 4 ? _consumerNo.substring(_consumerNo.length - 4) : _consumerNo;
    _agreementNo = init?.agreementNo ?? 'SIYA-AGR-${_executionDate.year}-$suffix';

    String cap = init?.systemCapacity ?? cust.systemCapacity?.trim() ?? '';
    if (cap.isEmpty && cust.remarks != null && cust.remarks!.trim().isNotEmpty) {
      final match = RegExp(r'(\d+(?:\.\d+)?\s*(?:kw|kW|KW|Kw))').firstMatch(cust.remarks!);
      if (match != null) cap = match.group(1)!;
    }
    _systemCapacity = cap.isNotEmpty ? cap : '3 kW';

    _totalProjectCost = init?.totalProjectCost ?? (cust.totalAmount > 0 ? cust.totalAmount : 160000.0);
    _cfaSubsidyAmount = init?.cfaSubsidyAmount ?? 78000.0;
    _netCustomerPayable = init?.netCustomerPayable ?? (_totalProjectCost - _cfaSubsidyAmount);

    if (init != null && init.paymentMilestones.isNotEmpty) {
      _paymentMilestones = List.from(init.paymentMilestones);
    } else {
      _paymentMilestones = ConsumerVendorAgreement.defaultMilestones(_totalProjectCost);
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
      createdAt: widget.initialAgreement?.createdAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  Future<void> _openEditDetailsDialog() async {
    final nameCtrl = TextEditingController(text: _customerName);
    final consumerCtrl = TextEditingController(text: _consumerNo);
    final mobileCtrl = TextEditingController(text: _customerMobile);
    final villageCtrl = TextEditingController(text: _villageCity);
    final addressCtrl = TextEditingController(text: _customerAddress);
    final capCtrl = TextEditingController(text: _systemCapacity);
    final costCtrl = TextEditingController(text: _totalProjectCost.toStringAsFixed(0));
    final subsidyCtrl = TextEditingController(text: _cfaSubsidyAmount.toStringAsFixed(0));
    final agrNoCtrl = TextEditingController(text: _agreementNo);

    DateTime tempExecutionDate = _executionDate;
    List<PaymentMilestone> tempMilestones = _paymentMilestones.map((m) => m.copyWith()).toList();

    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDlgState) {
            final currentCost = double.tryParse(costCtrl.text.trim()) ?? 0.0;
            final currentSubsidy = double.tryParse(subsidyCtrl.text.trim()) ?? 0.0;
            final netPayable = currentCost - currentSubsidy;

            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Row(
                children: [
                  Icon(Icons.edit_document, color: Color(0xFF0F2D69), size: 22),
                  SizedBox(width: 8),
                  Text('Edit Agreement Terms & Milestones', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F2D69))),
                ],
              ),
              content: SizedBox(
                width: 580,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Customer Info
                      const Text('1. Customer Information', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F2D69))),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(child: TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Customer Name *', isDense: true, border: OutlineInputBorder()))),
                          const SizedBox(width: 10),
                          Expanded(child: TextField(controller: consumerCtrl, decoration: const InputDecoration(labelText: 'Consumer No. *', isDense: true, border: OutlineInputBorder()))),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(child: TextField(controller: mobileCtrl, decoration: const InputDecoration(labelText: 'Mobile No.', isDense: true, border: OutlineInputBorder()), keyboardType: TextInputType.phone)),
                          const SizedBox(width: 10),
                          Expanded(child: TextField(controller: villageCtrl, decoration: const InputDecoration(labelText: 'Village / City *', isDense: true, border: OutlineInputBorder()))),
                        ],
                      ),
                      const SizedBox(height: 10),
                      TextField(controller: addressCtrl, decoration: const InputDecoration(labelText: 'Full Address *', isDense: true, border: OutlineInputBorder())),

                      const SizedBox(height: 16),
                      // System Specs & Agreement Meta
                      const Text('2. System Specs & Agreement Details', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F2D69))),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(child: TextField(controller: capCtrl, decoration: const InputDecoration(labelText: 'System Capacity *', isDense: true, border: OutlineInputBorder()))),
                          const SizedBox(width: 10),
                          Expanded(child: TextField(controller: agrNoCtrl, decoration: const InputDecoration(labelText: 'Agreement No. *', isDense: true, border: OutlineInputBorder()))),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        children: ['3 kW', '3.5 kW', '4 kW', '5 kW', '6 kW', '10 kW'].map((val) {
                          return ActionChip(
                            label: Text(val, style: const TextStyle(fontSize: 11)),
                            onPressed: () {
                              setDlgState(() {
                                capCtrl.text = val;
                                if (val == '3 kW') {
                                  costCtrl.text = '180000';
                                  subsidyCtrl.text = '78000';
                                } else if (val == '3.5 kW') {
                                  costCtrl.text = '200000';
                                  subsidyCtrl.text = '78000';
                                } else if (val == '4 kW') {
                                  costCtrl.text = '240000';
                                  subsidyCtrl.text = '78000';
                                } else if (val == '5 kW') {
                                  costCtrl.text = '300000';
                                  subsidyCtrl.text = '78000';
                                } else if (val == '6 kW') {
                                  costCtrl.text = '360000';
                                  subsidyCtrl.text = '78000';
                                } else if (val == '10 kW') {
                                  costCtrl.text = '600000';
                                  subsidyCtrl.text = '78000';
                                }
                                final c = double.tryParse(costCtrl.text) ?? 180000.0;
                                tempMilestones = ConsumerVendorAgreement.defaultMilestones(c);
                              });
                            },
                          );
                        }).toList(),
                      ),

                      const SizedBox(height: 16),
                      // Financial Breakdown
                      const Text('3. Financial Breakdown', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F2D69))),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: costCtrl,
                              decoration: const InputDecoration(labelText: 'Total Cost (Rs.) *', isDense: true, border: OutlineInputBorder()),
                              keyboardType: TextInputType.number,
                              onChanged: (_) => setDlgState(() {}),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextField(
                              controller: subsidyCtrl,
                              decoration: const InputDecoration(labelText: 'Govt Subsidy (Rs.) *', isDense: true, border: OutlineInputBorder()),
                              keyboardType: TextInputType.number,
                              onChanged: (_) => setDlgState(() {}),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFBFDBFE)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Net Customer Payable:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                            Text(currencyFormat.format(netPayable), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F2D69))),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),
                      // Clause 19 Payment Milestones
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('4. Clause 19 Payment Milestones', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F2D69))),
                          TextButton.icon(
                            style: TextButton.styleFrom(padding: EdgeInsets.zero, visualDensity: VisualDensity.compact),
                            icon: const Icon(Icons.refresh, size: 16),
                            label: const Text('Reset 20-60-20', style: TextStyle(fontSize: 11)),
                            onPressed: () {
                              setDlgState(() {
                                tempMilestones = ConsumerVendorAgreement.defaultMilestones(currentCost);
                              });
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
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
                                  CircleAvatar(
                                    radius: 10,
                                    backgroundColor: const Color(0xFF0F2D69),
                                    child: Text('${idx + 1}', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(m.stage, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                  ),
                                  Text(
                                    '${m.percentage.toStringAsFixed(0)}% • ${currencyFormat.format(m.amount)}',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF0F2D69)),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  SizedBox(
                                    width: 70,
                                    child: TextFormField(
                                      initialValue: m.percentage.toStringAsFixed(0),
                                      keyboardType: TextInputType.number,
                                      decoration: const InputDecoration(labelText: 'Share %', isDense: true, border: OutlineInputBorder()),
                                      onChanged: (val) {
                                        final pct = double.tryParse(val.trim()) ?? 0.0;
                                        final amt = (currentCost * pct) / 100.0;
                                        setDlgState(() {
                                          tempMilestones[idx] = m.copyWith(percentage: pct, amount: amt);
                                        });
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: TextFormField(
                                      initialValue: m.description,
                                      decoration: const InputDecoration(labelText: 'Due Condition / Description', isDense: true, border: OutlineInputBorder()),
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
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
                FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: const Color(0xFF0F2D69)),
                  onPressed: () {
                    final c = double.tryParse(costCtrl.text.trim()) ?? _totalProjectCost;
                    final s = double.tryParse(subsidyCtrl.text.trim()) ?? _cfaSubsidyAmount;

                    final updatedMilestones = tempMilestones.map((m) {
                      final recalculatedAmt = (c * m.percentage) / 100.0;
                      return m.copyWith(amount: recalculatedAmt);
                    }).toList();

                    setState(() {
                      _customerName = nameCtrl.text.trim();
                      _consumerNo = consumerCtrl.text.trim();
                      _customerMobile = mobileCtrl.text.trim();
                      _villageCity = villageCtrl.text.trim();
                      _customerAddress = addressCtrl.text.trim();
                      _systemCapacity = capCtrl.text.trim();
                      _agreementNo = agrNoCtrl.text.trim();
                      _executionDate = tempExecutionDate;
                      _totalProjectCost = c;
                      _cfaSubsidyAmount = s;
                      _netCustomerPayable = c - s;
                      _paymentMilestones = updatedMilestones;
                      _renderKey++;
                    });

                    // Save locally to link to profile
                    final agr = _buildAgreement();
                    AgreementStorageService.saveAgreement(agr);

                    Navigator.of(ctx).pop();
                  },
                  child: const Text('Apply Changes & Re-generate'),
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
    final agreement = _buildAgreement();

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Container(
        width: 900,
        height: 750,
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header Bar
            Row(
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
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Consumer-Vendor Agreement (Annexure 2) — $_customerName',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F2D69)),
                      ),
                      Text(
                        'PM Surya Ghar: Muft Bijli Yojana • Official Annexure 2 Agreement • Consumer No: $_consumerNo',
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF0F2D69),
                    side: const BorderSide(color: Color(0xFF0F2D69)),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  onPressed: _openEditDetailsDialog,
                  icon: const Icon(Icons.edit_document, size: 16),
                  label: const Text('Edit Payment Table'),
                ),
                const SizedBox(width: 8),
                FilledButton.tonalIcon(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF25D366).withValues(alpha: 0.15),
                    foregroundColor: const Color(0xFF128C7E),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  onPressed: () => ConsumerVendorAgreementService.shareViaWhatsApp(agreement),
                  icon: const Icon(Icons.chat_bubble_outline_rounded, size: 16),
                  label: const Text('Send WhatsApp'),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF059669),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  ),
                  onPressed: () => ConsumerVendorAgreementService.downloadAgreementPdf(context, agreement),
                  icon: const Icon(Icons.download_rounded, size: 16),
                  label: const Text('Download PDF', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  tooltip: 'Close',
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Summary Pill
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFECFDF5),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFA7F3D0)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('System: $_systemCapacity Solar RTS', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF065F46), fontSize: 12)),
                  Text('Total Cost: ${currencyFormat.format(_totalProjectCost)}', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF047857), fontSize: 13)),
                  Text('Govt Subsidy: ${currencyFormat.format(_cfaSubsidyAmount)}', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F2D69), fontSize: 12)),
                  Text('Net Payable: ${currencyFormat.format(_netCustomerPayable)}', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF334155), fontSize: 12)),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Live Interactive Agreement Preview
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
                    key: ValueKey('agreement_preview_$_renderKey'),
                    build: (PdfPageFormat format) async {
                      // Save to local storage on render to link to profile
                      await AgreementStorageService.saveAgreement(agreement);
                      return ConsumerVendorAgreementService.generateAgreementPdfBytes(agreement);
                    },
                    canChangeOrientation: false,
                    canChangePageFormat: false,
                    allowPrinting: true,
                    allowSharing: true,
                    initialPageFormat: PdfPageFormat.a4,
                    pdfFileName: agreement.pdfFileName,
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
