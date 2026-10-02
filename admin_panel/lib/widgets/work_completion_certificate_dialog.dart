import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import '../models/consumer_record.dart';
import '../models/work_completion_report_data.dart';
import '../services/work_completion_certificate_service.dart';

class WorkCompletionCertificateDialog extends StatefulWidget {
  final ConsumerRecord customer;
  final int initialTab;

  const WorkCompletionCertificateDialog({
    super.key,
    required this.customer,
    this.initialTab = 0,
  });

  static Future<void> show(BuildContext context, ConsumerRecord customer, {int initialTab = 0}) {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => WorkCompletionCertificateDialog(customer: customer, initialTab: initialTab),
    );
  }

  @override
  State<WorkCompletionCertificateDialog> createState() => _WorkCompletionCertificateDialogState();
}

class _WorkCompletionCertificateDialogState extends State<WorkCompletionCertificateDialog> {
  bool _isDownloading = false;
  int _selectedTab = 0; // 0: Bank WCR, 1: MSEDCL WCR, 2: Annexure-1, 3: DCR, 4: Net-Metering Agreement
  int _renderKey = 0;
  bool _includeStampAndSignature = true;
  bool _includeCustomerSignature = true;

  late WorkCompletionReportData _reportData;

  @override
  void initState() {
    super.initState();
    _selectedTab = widget.initialTab.clamp(0, 4);
    _reportData = WorkCompletionReportData.fromCustomer(widget.customer);
  }

  Future<void> _openEditDetailsDialog() async {
    // Basic Details
    final nameCtrl = TextEditingController(text: _reportData.customerName);
    final consumerCtrl = TextEditingController(text: _reportData.consumerNo);
    final addressCtrl = TextEditingController(text: _reportData.customerAddress);
    final mobileCtrl = TextEditingController(text: _reportData.customerMobile);
    final categoryCtrl = TextEditingController(text: _reportData.category);
    final sanctionCtrl = TextEditingController(text: _reportData.sanctionNo);
    final aadharCtrl = TextEditingController(text: _reportData.consumerAadhar);
    final capKwCtrl = TextEditingController(text: _reportData.installedCapacityKw.toStringAsFixed(1));

    // Module Specs
    final modMakeCtrl = TextEditingController(text: _reportData.moduleMake);
    final modAlmmCtrl = TextEditingController(text: _reportData.moduleAlmmModel);
    final modWattCtrl = TextEditingController(text: _reportData.moduleWattage.toString());
    final modCountCtrl = TextEditingController(text: _reportData.moduleCount.toString());
    final modWarrantyCtrl = TextEditingController(text: _reportData.moduleWarranty);
    final modSerialCtrl = TextEditingController(text: _reportData.moduleSerialNos);
    final cellMfrCtrl = TextEditingController(text: _reportData.cellManufacturer);
    final cellGstCtrl = TextEditingController(text: _reportData.cellGstInvoiceNo);

    // Inverter Specs
    final invMakeCtrl = TextEditingController(text: _reportData.inverterMake);
    final invModelCtrl = TextEditingController(text: _reportData.inverterModel);
    final invRatingCtrl = TextEditingController(text: _reportData.inverterRating);
    final invCapCtrl = TextEditingController(text: _reportData.inverterCapacityKw.toStringAsFixed(1));
    final invTypeCtrl = TextEditingController(text: _reportData.inverterControllerType);
    final invYearCtrl = TextEditingController(text: _reportData.inverterMfgYear.toString());

    // Earthing & Safety
    final earthDetailsCtrl = TextEditingController(text: _reportData.earthResistanceDetails);
    final earthCertCtrl = TextEditingController(text: _reportData.earthResistanceCertified);
    final laCtrl = TextEditingController(text: _reportData.lightningArrester);

    DateTime compDate = _reportData.completionDate;

    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Row(
                children: [
                  Icon(Icons.edit_document, color: Color(0xFF0F2D69)),
                  SizedBox(width: 8),
                  Text('Edit WCR & Commissioning Dossier Specifications'),
                ],
              ),
              content: SizedBox(
                width: 650,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'All values are pre-filled automatically from the customer profile. Customize equipment specs below and click Apply.',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      const SizedBox(height: 16),

                      // SECTION 1: Consumer & Sanction Details
                      const Text('1. Consumer & Site Information', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F2D69))),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(child: TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Customer Name *', isDense: true, border: OutlineInputBorder()))),
                          const SizedBox(width: 10),
                          Expanded(child: TextField(controller: consumerCtrl, decoration: const InputDecoration(labelText: 'Consumer No *', isDense: true, border: OutlineInputBorder()))),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(child: TextField(controller: addressCtrl, decoration: const InputDecoration(labelText: 'Site Address *', isDense: true, border: OutlineInputBorder()))),
                          const SizedBox(width: 10),
                          Expanded(child: TextField(controller: mobileCtrl, decoration: const InputDecoration(labelText: 'Mobile Number', isDense: true, border: OutlineInputBorder()))),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(child: TextField(controller: sanctionCtrl, decoration: const InputDecoration(labelText: 'Sanction / Appln No *', isDense: true, border: OutlineInputBorder()))),
                          const SizedBox(width: 10),
                          Expanded(child: TextField(controller: capKwCtrl, decoration: const InputDecoration(labelText: 'System Capacity (KW) *', isDense: true, border: OutlineInputBorder()))),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(child: TextField(controller: aadharCtrl, decoration: const InputDecoration(labelText: 'Consumer Aadhar No', isDense: true, border: OutlineInputBorder()))),
                          const SizedBox(width: 10),
                          Expanded(child: TextField(controller: categoryCtrl, decoration: const InputDecoration(labelText: 'Category', isDense: true, border: OutlineInputBorder()))),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // SECTION 2: Solar Modules Specifications
                      const Text('2. Solar PV Modules Specifications', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F2D69))),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(child: TextField(controller: modMakeCtrl, decoration: const InputDecoration(labelText: 'Module Make *', isDense: true, border: OutlineInputBorder()))),
                          const SizedBox(width: 10),
                          Expanded(child: TextField(controller: modAlmmCtrl, decoration: const InputDecoration(labelText: 'ALMM Model No *', isDense: true, border: OutlineInputBorder()))),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(child: TextField(controller: modWattCtrl, decoration: const InputDecoration(labelText: 'Wattage (Wp) *', isDense: true, border: OutlineInputBorder()))),
                          const SizedBox(width: 10),
                          Expanded(child: TextField(controller: modCountCtrl, decoration: const InputDecoration(labelText: 'Module Count (Nos) *', isDense: true, border: OutlineInputBorder()))),
                        ],
                      ),
                      const SizedBox(height: 10),
                      TextField(controller: modWarrantyCtrl, decoration: const InputDecoration(labelText: 'Warranty Details *', isDense: true, border: OutlineInputBorder())),
                      const SizedBox(height: 10),
                      TextField(controller: modSerialCtrl, decoration: const InputDecoration(labelText: 'Module Serial Numbers', isDense: true, border: OutlineInputBorder())),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(child: TextField(controller: cellMfrCtrl, decoration: const InputDecoration(labelText: 'Cell Manufacturer (DCR)', isDense: true, border: OutlineInputBorder()))),
                          const SizedBox(width: 10),
                          Expanded(child: TextField(controller: cellGstCtrl, decoration: const InputDecoration(labelText: 'Cell GST Invoice No', isDense: true, border: OutlineInputBorder()))),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // SECTION 3: PCU / Inverter Specifications
                      const Text('3. Inverter / PCU Specifications', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F2D69))),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(child: TextField(controller: invMakeCtrl, decoration: const InputDecoration(labelText: 'Inverter Make *', isDense: true, border: OutlineInputBorder()))),
                          const SizedBox(width: 10),
                          Expanded(child: TextField(controller: invModelCtrl, decoration: const InputDecoration(labelText: 'Model Number *', isDense: true, border: OutlineInputBorder()))),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(child: TextField(controller: invRatingCtrl, decoration: const InputDecoration(labelText: 'Inverter Rating *', isDense: true, border: OutlineInputBorder()))),
                          const SizedBox(width: 10),
                          Expanded(child: TextField(controller: invCapCtrl, decoration: const InputDecoration(labelText: 'Inverter Capacity (KW) *', isDense: true, border: OutlineInputBorder()))),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(child: TextField(controller: invTypeCtrl, decoration: const InputDecoration(labelText: 'MPPT / Controller Type', isDense: true, border: OutlineInputBorder()))),
                          const SizedBox(width: 10),
                          Expanded(child: TextField(controller: invYearCtrl, decoration: const InputDecoration(labelText: 'Year of Manufacturing', isDense: true, border: OutlineInputBorder()))),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // SECTION 4: Earthing & Protection
                      const Text('4. Earthing & Safety Protections', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F2D69))),
                      const SizedBox(height: 8),
                      TextField(controller: earthDetailsCtrl, decoration: const InputDecoration(labelText: 'Earthing Resistance Details *', isDense: true, border: OutlineInputBorder())),
                      const SizedBox(height: 10),
                      TextField(controller: earthCertCtrl, decoration: const InputDecoration(labelText: 'Resistance Inspection Certification *', isDense: true, border: OutlineInputBorder())),
                      const SizedBox(height: 10),
                      TextField(controller: laCtrl, decoration: const InputDecoration(labelText: 'Lightening Arrester Specs *', isDense: true, border: OutlineInputBorder())),
                      const SizedBox(height: 16),

                      // Date picker
                      Row(
                        children: [
                          const Icon(Icons.calendar_month, color: Color(0xFF0F2D69), size: 20),
                          const SizedBox(width: 8),
                          Text('Installation / Completion Date: ${DateFormat('dd MMM yyyy').format(compDate)}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                          const Spacer(),
                          TextButton(
                            onPressed: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: compDate,
                                firstDate: DateTime(2020),
                                lastDate: DateTime(2035),
                              );
                              if (picked != null) {
                                setDialogState(() => compDate = picked);
                              }
                            },
                            child: const Text('Change Date'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
                FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: const Color(0xFF0F2D69)),
                  onPressed: () {
                    final cap = double.tryParse(capKwCtrl.text.trim()) ?? _reportData.installedCapacityKw;
                    final mCount = int.tryParse(modCountCtrl.text.trim()) ?? _reportData.moduleCount;
                    final mWatt = int.tryParse(modWattCtrl.text.trim()) ?? _reportData.moduleWattage;
                    final totalKwp = double.parse((mCount * mWatt / 1000.0).toStringAsFixed(2));

                    setState(() {
                      _reportData = _reportData.copyWith(
                        customerName: nameCtrl.text.trim(),
                        consumerNo: consumerCtrl.text.trim(),
                        customerAddress: addressCtrl.text.trim(),
                        customerMobile: mobileCtrl.text.trim(),
                        category: categoryCtrl.text.trim(),
                        sanctionNo: sanctionCtrl.text.trim(),
                        consumerAadhar: aadharCtrl.text.trim(),
                        sanctionedCapacityKw: cap,
                        installedCapacityKw: cap,
                        moduleMake: modMakeCtrl.text.trim(),
                        moduleAlmmModel: modAlmmCtrl.text.trim(),
                        moduleWattage: mWatt,
                        moduleCount: mCount,
                        moduleTotalCapacityKwp: totalKwp,
                        moduleWarranty: modWarrantyCtrl.text.trim(),
                        moduleSerialNos: modSerialCtrl.text.trim(),
                        cellManufacturer: cellMfrCtrl.text.trim(),
                        cellGstInvoiceNo: cellGstCtrl.text.trim(),
                        inverterMake: invMakeCtrl.text.trim(),
                        inverterModel: invModelCtrl.text.trim(),
                        inverterRating: invRatingCtrl.text.trim(),
                        inverterCapacityKw: double.tryParse(invCapCtrl.text.trim()) ?? _reportData.inverterCapacityKw,
                        inverterControllerType: invTypeCtrl.text.trim(),
                        inverterMfgYear: int.tryParse(invYearCtrl.text.trim()) ?? _reportData.inverterMfgYear,
                        earthResistanceDetails: earthDetailsCtrl.text.trim(),
                        earthResistanceCertified: earthCertCtrl.text.trim(),
                        lightningArrester: laCtrl.text.trim(),
                        completionDate: compDate,
                      );
                      _renderKey++;
                    });
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
    final screenSize = MediaQuery.of(context).size;
    final isCompact = screenSize.width < 900;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: EdgeInsets.symmetric(
        horizontal: isCompact ? 12 : 24,
        vertical: isCompact ? 12 : 20,
      ),
      child: Container(
        width: (screenSize.width * 0.94).clamp(750.0, 1200.0),
        height: (screenSize.height * 0.94).clamp(650.0, 960.0),
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Row 1: Dialog Header (Icon + Title & Customer Name + Subtitle + Close Button)
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F2D69).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.verified_outlined, color: Color(0xFF0F2D69), size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              'Work Completion & Commissioning Dossier',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0F2D69),
                                letterSpacing: -0.2,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Text('—', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: const Color(0xFFCBD5E1)),
                              ),
                              child: Text(
                                _reportData.customerName,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF1E293B),
                                ),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Consumer No: ${_reportData.consumerNo} • Capacity: ${_reportData.installedCapacityKw.toStringAsFixed(1)} kW (${_reportData.moduleTotalCapacityKwp.toStringAsFixed(2)} kWp) • Sanction: ${_reportData.sanctionNo}',
                        style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 22),
                  tooltip: 'Close',
                  style: IconButton.styleFrom(
                    backgroundColor: const Color(0xFFF1F5F9),
                    foregroundColor: const Color(0xFF475569),
                    hoverColor: const Color(0xFFE2E8F0),
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Row 2: Document Switcher Tabs (Left) + Actions Toolbar (Right)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                // Tabs Switcher Pills
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFCBD5E1)),
                  ),
                  padding: const EdgeInsets.all(3),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildTabButton(0, '1. Bank WCR (1P)', Icons.account_balance_rounded),
                      const SizedBox(width: 4),
                      _buildTabButton(1, '2. MSEDCL WCR (2P)', Icons.assignment_turned_in_rounded),
                      const SizedBox(width: 4),
                      _buildTabButton(2, '3. Annexure-I (2P)', Icons.description_rounded),
                      const SizedBox(width: 4),
                      _buildTabButton(3, '4. DCR Undertaking (1P)', Icons.verified_user_rounded),
                      const SizedBox(width: 4),
                      _buildTabButton(4, '5. Net-Metering (5P)', Icons.handshake_outlined),
                    ],
                  ),
                ),

                // Right Actions Toolbar
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF0F2D69),
                        side: const BorderSide(color: Color(0xFF0F2D69)),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      onPressed: _openEditDetailsDialog,
                      icon: const Icon(Icons.tune_rounded, size: 16),
                      label: const Text('Edit Specs / Details'),
                                        if (_includeStampAndSignature)
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFDC2626),
                          side: const BorderSide(color: Color(0xFFFCA5A5)),
                          backgroundColor: const Color(0xFFFEF2F2),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        ),
                        onPressed: () {
                          setState(() {
                            _includeStampAndSignature = false;
                            _renderKey++;
                          });
                        },
                        icon: const Icon(Icons.remove_circle_outline_rounded, size: 15, color: Color(0xFFDC2626)),
                        label: const Text('Remove Stamp & Sig', style: TextStyle(fontWeight: FontWeight.w600)),
                      )
                    else
                      FilledButton.tonalIcon(
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFFECFDF5),
                          foregroundColor: const Color(0xFF047857),
                          side: const BorderSide(color: Color(0xFFA7F3D0)),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        ),
                        onPressed: () {
                          setState(() {
                            _includeStampAndSignature = true;
                            _renderKey++;
                          });
                        },
                        icon: const Icon(Icons.verified_rounded, size: 15, color: Color(0xFF047857)),
                        label: const Text('Include Stamp & Sig', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),

                    if (_includeCustomerSignature)
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF0F3B7A),
                          side: const BorderSide(color: Color(0xFF93C5FD)),
                          backgroundColor: const Color(0xFFEFF6FF),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        ),
                        onPressed: () {
                          setState(() {
                            _includeCustomerSignature = false;
                            _renderKey++;
                          });
                        },
                        icon: const Icon(Icons.draw_outlined, size: 15, color: Color(0xFF0F3B7A)),
                        label: const Text('Customer Sig: ON', style: TextStyle(fontWeight: FontWeight.bold)),
                      )
                    else
                      FilledButton.tonalIcon(
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFFF1F5F9),
                          foregroundColor: const Color(0xFF64748B),
                          side: const BorderSide(color: Color(0xFFCBD5E1)),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        ),
                        onPressed: () {
                          setState(() {
                            _includeCustomerSignature = true;
                            _renderKey++;
                          });
                        },
                        icon: const Icon(Icons.draw_outlined, size: 15, color: Color(0xFF64748B)),
                        label: const Text('Customer Sig: OFF', style: TextStyle(fontWeight: FontWeight.w600)),
                      ),

                    FilledButton.tonalIcon(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF25D366).withValues(alpha: 0.15),
                        foregroundColor: const Color(0xFF128C7E),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      onPressed: () => WorkCompletionCertificateService.sendOnWhatsApp(context, widget.customer, reportData: _reportData),
                      icon: const Icon(Icons.chat_bubble_outline_rounded, size: 16),
                      label: const Text('Send WhatsApp'),
                    ),

                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF059669),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      ),
                      onPressed: _isDownloading
                          ? null
                          : () async {
                              setState(() => _isDownloading = true);
                              await WorkCompletionCertificateService.downloadCertificatePdf(
                                context,
                                widget.customer,
                                reportData: _reportData,
                                includeStampAndSignature: _includeStampAndSignature,
                                includeCustomerSignature: _includeCustomerSignature,
                                documentType: _selectedTab,
                              );
                              if (mounted) setState(() => _isDownloading = false);
                            },
                      icon: _isDownloading
                          ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.download_rounded, size: 16),
                      label: const Text('Download PDF', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Summary Pill
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: const Color(0xFFECFDF5),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFA7F3D0)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Modules: ${_reportData.moduleCount}x ${_reportData.moduleMake} (${_reportData.moduleWattage}Wp)', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF065F46), fontSize: 11.5)),
                  Text('Inverter: ${_reportData.inverterMake} ${_reportData.inverterModel} (${_reportData.inverterCapacityKw.toStringAsFixed(1)} kW)', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF047857), fontSize: 11.5)),
                  Text('Earthing: ${_reportData.earthResistanceDetails}', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F2D69), fontSize: 11.5)),
                  Text('Date: ${DateFormat('dd MMM yyyy').format(_reportData.completionDate)}', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF334155), fontSize: 11.5)),
                ],
              ),
            ),
            const SizedBox(height: 10),

            // Live Interactive PDF Preview
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
                    key: ValueKey('wcr_preview_${_selectedTab}_${_renderKey}_${_includeStampAndSignature}_$_includeCustomerSignature'),
                    build: (PdfPageFormat format) async {
                      switch (_selectedTab) {
                        case 0:
                          return WorkCompletionCertificateService.generateBankWcrPdfBytes(
                            _reportData,
                            includeStampAndSignature: _includeStampAndSignature,
                            includeCustomerSignature: _includeCustomerSignature,
                          );
                        case 1:
                          return WorkCompletionCertificateService.generateWcrPdfBytes(
                            _reportData,
                            includeStampAndSignature: _includeStampAndSignature,
                            includeCustomerSignature: _includeCustomerSignature,
                          );
                        case 2:
                          return WorkCompletionCertificateService.generateAnnexure1PdfBytes(_reportData, includeStampAndSignature: _includeStampAndSignature);
                        case 3:
                          return WorkCompletionCertificateService.generateDcrPdfBytes(_reportData, includeStampAndSignature: _includeStampAndSignature);
                        case 4:
                        default:
                          return WorkCompletionCertificateService.generateAnnexure3PdfBytes(
                            _reportData,
                            includeStampAndSignature: _includeStampAndSignature,
                            includeCustomerSignature: _includeCustomerSignature,
                          );
                      }
                    },
                    canChangeOrientation: false,
                    canChangePageFormat: false,
                    allowPrinting: true,
                    allowSharing: true,
                    initialPageFormat: PdfPageFormat.a4,
                    pdfFileName: _selectedTab == 0
                        ? 'Bank_WCR_${_reportData.consumerNo}.pdf'
                        : (_selectedTab == 1
                            ? 'MSEDCL_WCR_${_reportData.consumerNo}.pdf'
                            : (_selectedTab == 2
                                ? 'Annexure_1_${_reportData.consumerNo}.pdf'
                                : (_selectedTab == 3
                                    ? 'DCR_Undertaking_${_reportData.consumerNo}.pdf'
                                    : 'Net_Metering_Agreement_${_reportData.consumerNo}.pdf'))),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabButton(int index, String title, IconData icon) {
    final isSelected = _selectedTab == index;
    return InkWell(
      onTap: () => setState(() {
        _selectedTab = index;
        _renderKey++;
      }),
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF0D2B6F) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          boxShadow: isSelected
              ? [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 4, offset: const Offset(0, 2))]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: isSelected ? Colors.white : const Color(0xFF475569)),
            const SizedBox(width: 6),
            Text(
              title,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.bold,
                color: isSelected ? Colors.white : const Color(0xFF475569),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
