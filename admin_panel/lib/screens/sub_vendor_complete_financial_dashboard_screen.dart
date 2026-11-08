import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:siya_shared/siya_shared.dart';
import '../services/sub_vendor_service.dart';
import '../services/sub_vendor_pdf_service.dart';
import '../widgets/sub_vendor_dialogs.dart';

final _currency = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 2);
final _dateFormat = DateFormat('dd-MM-yyyy');

/// SubVendorCompleteFinancialDashboardScreen
///
/// Comprehensive click-to-open financial dashboard for a Sub-Vendor.
/// Aggregates live data across all assigned sites:
///   1. Complete Vendor Overview (Live math aggregation, KPI cards, Final Settlement banner)
///   2. Loan Account (All sites, sanction, 90% expected, bank credits, UTR, 10% diff)
///   3. Material Account (Item-by-item issued/returned, dynamic 5% & 18% cost, net cost)
///   4. GST Account (Taxable billing, Output GST, Eligible ITC, Net GST payable)
///   5. SIYA Vendor Charges (₹1,000/kW calculation & approval audit)
///   6. Payment & Final Settlement (Option A net contract settlement, previous advances, disbursals)
///   7. Site-wise Drill Down (Clicking any site opens its quotation, loan, material, and settlement)
///
/// Security: Admin has full access; Sub-Vendor has View-Only access to own records.
class SubVendorCompleteFinancialDashboardScreen extends StatefulWidget {
  final SubVendor vendor;
  final bool isAdmin;

  const SubVendorCompleteFinancialDashboardScreen({
    super.key,
    required this.vendor,
    this.isAdmin = true,
  });

  @override
  State<SubVendorCompleteFinancialDashboardScreen> createState() =>
      _SubVendorCompleteFinancialDashboardScreenState();
}

class _SubVendorCompleteFinancialDashboardScreenState
    extends State<SubVendorCompleteFinancialDashboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  bool _isLoading = true;
  String? _errorMessage;

  VendorFinancialSummary? _summary;
  List<VendorSiteAssignment> _assignments = [];
  List<VendorMaterialTransaction> _materials = [];
  List<VendorPayout> _payouts = [];
  List<VendorCustomerPayment> _customerPayments = [];

  // Search & filter
  String _siteSearch = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 7, vsync: this);
    _loadAllVendorData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAllVendorData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final vendorId = widget.vendor.id;

      final results = await Future.wait([
        SubVendorService.getVendorFinancialSummary(vendorId),
        SubVendorService.fetchAssignments(vendorId: vendorId),
        SubVendorService.fetchVendorMaterials(vendorId),
        SubVendorService.fetchVendorPayouts(vendorId),
        SubVendorService.fetchCustomerPayments(vendorId: vendorId),
      ]);

      if (mounted) {
        setState(() {
          _summary = results[0] as VendorFinancialSummary;
          _assignments = results[1] as List<VendorSiteAssignment>;
          _materials = results[2] as List<VendorMaterialTransaction>;
          _payouts = results[3] as List<VendorPayout>;
          _customerPayments = results[4] as List<VendorCustomerPayment>;
          _isLoading = false;
        });
      }
    } catch (e, stack) {
      debugPrint('Error loading complete vendor dashboard: $e\n$stack');
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  // ============================================================================
  // CSV EXPORT HELPERS
  // ============================================================================

  Future<void> _exportCsv({
    required String fileName,
    required List<List<dynamic>> rows,
  }) async {
    try {
      final csvString = const ListToCsvConverter().convert(rows);
      final bytes = utf8.encode(csvString);
      await FilePicker.platform.saveFile(
        dialogTitle: 'Export $fileName',
        fileName: '$fileName.csv',
        bytes: Uint8List.fromList(bytes),
        allowedExtensions: ['csv'],
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Exported $fileName.csv successfully!'),
            backgroundColor: const Color(0xFF047857),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to export CSV: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _exportLoanReportCsv() {
    final rows = <List<dynamic>>[
      [
        'Consumer No',
        'Customer Name',
        'Capacity kW',
        'Payment Type',
        'Quotation Amount',
        'Expected 90% Loan',
        '10% Quotation Diff',
        'Disbursing Bank',
        'Loan App ID',
        'Sanction Amount',
        'Total Loan Credited',
        'Pending Loan Credit',
        'Total Cash Received',
        'Customer Outstanding',
        'Loan Status',
      ],
      for (final a in _assignments)
        [
          a.consumerNo ?? 'N/A',
          a.customerName ?? 'N/A',
          a.siteCapacityKw,
          a.paymentType,
          a.effectiveSiteAmount,
          a.effectiveSiteAmount * 0.90,
          a.effectiveSiteAmount * 0.10,
          a.loanBankName ?? 'N/A',
          a.loanApplicationId ?? 'N/A',
          a.loanSanctionedAmount,
          a.totalLoanCredited,
          a.loanPendingCredit,
          a.totalCashReceived,
          a.customerOutstanding,
          a.loanStatus,
        ],
    ];
    _exportCsv(
      fileName: 'loan_report_${widget.vendor.vendorCode}_${DateTime.now().millisecondsSinceEpoch}',
      rows: rows,
    );
  }

  void _exportMaterialReportCsv() {
    final rows = <List<dynamic>>[
      [
        'Date',
        'Item Name',
        'Category',
        'Remarks / Serial',
        'Customer / Site',
        'Consumer No',
        'Tx Type',
        'Quantity',
        'Unit',
        'Purchase Rate',
        'GST Rate %',
        'Taxable Amount',
        'GST Amount',
        'Net Total Cost',
      ],
      for (final m in _materials) ...[
        () {
          final assignment = _assignments.firstWhere(
            (a) => a.id == m.assignmentId,
            orElse: () => _assignments.isNotEmpty ? _assignments.first : _assignments.first,
          );
          return [
            _dateFormat.format(m.transactionDate),
            m.itemName,
            m.itemCategory,
            m.remarks ?? m.serialNumbers ?? '',
            assignment.customerName ?? 'Site',
            assignment.consumerNo ?? '',
            m.isReturn ? 'RETURN' : 'ISSUE',
            m.isReturn ? -m.quantity : m.quantity,
            m.unit,
            m.unitRate,
            m.gstRate,
            (m.isReturn ? -1 : 1) * m.taxableAmount,
            (m.isReturn ? -1 : 1) * m.gstAmount,
            (m.isReturn ? -1 : 1) * m.totalAmount,
          ];
        }(),
      ],
    ];
    _exportCsv(
      fileName: 'material_report_${widget.vendor.vendorCode}_${DateTime.now().millisecondsSinceEpoch}',
      rows: rows,
    );
  }

  void _exportGstSummaryCsv() {
    final rows = <List<dynamic>>[
      [
        'Consumer No',
        'Customer Name',
        'Capacity kW',
        'Site Quotation (Gross)',
        'Taxable Value (~86.2% / Composite)',
        'Output GST Liability (~13.8%)',
        'Issued Material Cost',
        'Eligible Input GST Credit',
        'Net GST Payable',
      ],
      for (final a in _assignments) ...[
        () {
          final siteMats = _materials.where((m) => m.assignmentId == a.id).toList();
          double inputGst = 0.0;
          double matCost = 0.0;
          for (final m in siteMats) {
            final s = m.isReturn ? -1.0 : 1.0;
            inputGst += s * m.gstAmount;
            matCost += s * m.totalAmount;
          }
          final gross = a.effectiveSiteAmount;
          final taxable = gross / 1.138;
          final outputGst = gross - taxable;
          final netGst = (outputGst - inputGst).clamp(0.0, double.infinity);

          return [
            a.consumerNo ?? 'N/A',
            a.customerName ?? 'N/A',
            a.siteCapacityKw,
            gross,
            taxable,
            outputGst,
            matCost,
            inputGst,
            netGst,
          ];
        }(),
      ],
    ];
    _exportCsv(
      fileName: 'gst_summary_${widget.vendor.vendorCode}_${DateTime.now().millisecondsSinceEpoch}',
      rows: rows,
    );
  }

  // ============================================================================
  // UI BUILD
  // ============================================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D2B6F),
        foregroundColor: Colors.white,
        titleSpacing: 0,
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: const Color(0xFFE0F2FE),
              child: Text(
                widget.vendor.name.isNotEmpty ? widget.vendor.name[0].toUpperCase() : 'V',
                style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0D2B6F), fontSize: 16),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          widget.vendor.name,
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E3A8A),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: const Color(0xFF60A5FA)),
                        ),
                        child: Text(
                          widget.vendor.vendorCode,
                          style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: widget.vendor.isBlocked ? Colors.red.shade900 : Colors.green.shade800,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          widget.vendor.status,
                          style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  Text(
                    'Mobile: ${widget.vendor.mobile}  •  SIYA Platform Rate: ${_currency.format(widget.vendor.defaultRatePerKw)}/kW  •  Bank: ${widget.vendor.bankName ?? "N/A"}',
                    style: const TextStyle(fontSize: 11, color: Color(0xFFBAE6FD)),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh All',
            onPressed: _loadAllVendorData,
          ),
          if (_summary != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
              child: ElevatedButton.icon(
                icon: const Icon(Icons.picture_as_pdf, size: 16),
                label: const Text('Export Ledger PDF'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF59E0B),
                  foregroundColor: Colors.black87,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
                onPressed: () async {
                  await SubVendorPdfService.printOrShareVendorOverallStatement(
                    _summary!,
                    vendor: widget.vendor,
                  );
                },
              ),
            ),
          if (widget.isAdmin)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
              child: ElevatedButton.icon(
                icon: const Icon(Icons.calculate, size: 16),
                label: const Text('Settlement Calculator'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF047857),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
                onPressed: _openSettlementCalculator,
              ),
            ),
          const SizedBox(width: 8),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          indicatorColor: const Color(0xFFF59E0B),
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: const Color(0xFF93C5FD),
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          tabs: const [
            Tab(icon: Icon(Icons.dashboard_outlined, size: 18), text: 'Overview'),
            Tab(icon: Icon(Icons.account_balance_outlined, size: 18), text: 'Loan Account'),
            Tab(icon: Icon(Icons.inventory_2_outlined, size: 18), text: 'Material Account'),
            Tab(icon: Icon(Icons.receipt_long_outlined, size: 18), text: 'GST Account'),
            Tab(icon: Icon(Icons.bolt_outlined, size: 18), text: 'SIYA Charges'),
            Tab(icon: Icon(Icons.payments_outlined, size: 18), text: 'Payment & Settlement'),
            Tab(icon: Icon(Icons.layers_outlined, size: 18), text: 'Site Drill Down'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? _buildErrorView()
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildOverviewTab(),
                    _buildLoanAccountTab(),
                    _buildMaterialAccountTab(),
                    _buildGstAccountTab(),
                    _buildVendorChargesTab(),
                    _buildPaymentSettlementTab(),
                    _buildSiteDrillDownTab(),
                  ],
                ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 12),
            const Text(
              'Failed to Load Financial Dashboard',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
            ),
            const SizedBox(height: 8),
            Text(_errorMessage!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
              onPressed: _loadAllVendorData,
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================================
  // TAB 1: COMPLETE VENDOR OVERVIEW
  // ============================================================================

  Widget _buildOverviewTab() {
    final s = _summary;
    if (s == null) return const Center(child: Text('No data'));

    final totalQuotation = s.totalSiteAmount;
    final expectedLoan90 = totalQuotation * 0.90;
    final loan10Diff = totalQuotation * 0.10;
    final loanSanctioned = s.totalLoanSanctioned;
    final loanCredited = s.totalLoanCredited;
    final loanPending = s.totalLoanPendingCredit;
    final cashReceived = s.totalCashReceived;
    final actualCollection = s.totalCustomerCollection;
    final totalMaterialCost = s.totalMaterialCost;

    // GST aggregation
    final taxableBilling = totalQuotation / 1.138;
    final outputGst = totalQuotation - taxableBilling;
    final eligibleItc = s.totalEligibleInputGst;
    final netGstPayable = (outputGst - eligibleItc).clamp(0.0, double.infinity);

    final vendorCharges = s.totalVendorCharges;
    final otherExpenses = s.totalOtherExpenses;
    final previousPayments = s.totalPaidAmount;

    // Option A Final Net Balance:
    // Realized Collection - Material Cost - SIYA Charges - Net GST - Other Expenses - Previous Advances
    final effectiveCollection = actualCollection > 0 ? actualCollection : totalQuotation;
    final netSubVendorEntitlement = effectiveCollection - totalMaterialCost - vendorCharges - otherExpenses - netGstPayable;
    final finalBalance = netSubVendorEntitlement - previousPayments;

    final isPayable = finalBalance >= 0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // HERO BANNER: FINAL SETTLEMENT AMOUNT
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isPayable
                    ? [const Color(0xFF065F46), const Color(0xFF047857)]
                    : [const Color(0xFF991B1B), const Color(0xFFDC2626)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: (isPayable ? const Color(0xFF047857) : Colors.red).withOpacity(0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          isPayable ? Icons.verified : Icons.warning_amber_rounded,
                          color: Colors.white,
                          size: 24,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          isPayable
                              ? 'FINAL AMOUNT PAYABLE TO SUB-VENDOR'
                              : 'AMOUNT RECOVERABLE FROM SUB-VENDOR',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        'OPTION A NET BALANCE',
                        style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  _currency.format(finalBalance.abs()),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  isPayable
                    ? 'Net balance payable by SIYA to ${widget.vendor.name} after material costs, SIYA platform charges (₹1,000/kW), GST liability, and previous advances.'
                    : 'Advance payments, material costs, and deductions exceed realized collections. Recoverable from ${widget.vendor.name}.',
                  style: const TextStyle(color: Color(0xFFE2E8F0), fontSize: 13),
                ),
                const Divider(color: Colors.white24, height: 24),
                // Compact formula audit
                Wrap(
                  spacing: 16,
                  runSpacing: 8,
                  children: [
                    _buildBannerFormulaChip('Realized Collection', _currency.format(effectiveCollection), Colors.white),
                    _buildBannerFormulaChip('Material Cost', '- ${_currency.format(totalMaterialCost)}', const Color(0xFFFECACA)),
                    _buildBannerFormulaChip('SIYA Charges (₹1,000/kW)', '- ${_currency.format(vendorCharges)}', const Color(0xFFFED7AA)),
                    _buildBannerFormulaChip('Net GST', '- ${_currency.format(netGstPayable)}', const Color(0xFFFDE68A)),
                    _buildBannerFormulaChip('Other Expenses', '- ${_currency.format(otherExpenses)}', const Color(0xFFE9D5FF)),
                    _buildBannerFormulaChip('Previous Advances', '- ${_currency.format(previousPayments)}', const Color(0xFFBFDBFE)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // SECTION TITLE
          const Text(
            'AGGREGATED FINANCIAL OVERVIEW',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A), letterSpacing: 0.5),
          ),
          const SizedBox(height: 10),

          // 14 KEY METRIC CARDS
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _buildMetricCard('Total Quotation (100%)', _currency.format(totalQuotation), Icons.receipt, const Color(0xFF1E3A8A)),
              _buildMetricCard('Expected Loan (90%)', _currency.format(expectedLoan90), Icons.account_balance, const Color(0xFF2563EB)),
              _buildMetricCard('10% Difference', _currency.format(loan10Diff), Icons.pie_chart, const Color(0xFF0284C7)),
              _buildMetricCard('Loan Sanctioned', _currency.format(loanSanctioned), Icons.check_circle_outline, const Color(0xFF059669)),
              _buildMetricCard('Actual Loan Credited', _currency.format(loanCredited), Icons.account_balance_wallet, const Color(0xFF047857)),
              _buildMetricCard('Loan Pending Credit', _currency.format(loanPending), Icons.hourglass_top, const Color(0xFFD97706)),
              _buildMetricCard('Customer Contribution (Cash)', _currency.format(cashReceived), Icons.payments_outlined, const Color(0xFF0D9488)),
              _buildMetricCard('Total Actual Collection', _currency.format(actualCollection), Icons.price_check, const Color(0xFF15803D)),
              _buildMetricCard('Total Material Cost', _currency.format(totalMaterialCost), Icons.inventory_2, const Color(0xFFDC2626)),
              _buildMetricCard('Output GST Liability', _currency.format(outputGst), Icons.receipt_long, const Color(0xFF7C3AED)),
              _buildMetricCard('Eligible Input GST Credit', _currency.format(eligibleItc), Icons.assignment_return, const Color(0xFF9333EA)),
              _buildMetricCard('Net GST Payable', _currency.format(netGstPayable), Icons.account_tree, const Color(0xFF4C1D95)),
              _buildMetricCard('SIYA Charges (₹1,000/kW)', _currency.format(vendorCharges), Icons.bolt, const Color(0xFFEA580C)),
              _buildMetricCard('Other Approved Expenses', _currency.format(otherExpenses), Icons.receipt, const Color(0xFF475569)),
              _buildMetricCard('Previous Payments / Advances', _currency.format(previousPayments), Icons.history, const Color(0xFF334155)),
            ],
          ),
          const SizedBox(height: 24),

          // QUICK ACTION BUTTONS
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            elevation: 0,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text('Full Sub-Vendor Financial Audit Statement', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        SizedBox(height: 4),
                        Text('Includes complete site-by-site table, material costs, bank loans, and statutory deductions.', style: TextStyle(color: Colors.grey, fontSize: 12)),
                      ],
                    ),
                  ),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.picture_as_pdf, size: 16),
                    label: const Text('Download Ledger PDF'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0D2B6F),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    onPressed: () => SubVendorPdfService.printOrShareVendorOverallStatement(s, vendor: widget.vendor),
                  ),
                  if (widget.isAdmin) ...[
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.payment, size: 16),
                      label: const Text('Record Payout'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF047857),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                      onPressed: _openRecordPayoutDialog,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBannerFormulaChip(String label, String value, Color valueColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: const TextStyle(fontSize: 10, color: Colors.white70)),
          const SizedBox(height: 2),
          Text(value, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: valueColor)),
        ],
      ),
    );
  }

  Widget _buildMetricCard(String title, String value, IconData icon, Color color) {
    return Container(
      width: 220,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade100,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: color.withOpacity(0.12),
                child: Icon(icon, size: 14, color: color),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  // ============================================================================
  // TAB 2: LOAN ACCOUNT
  // ============================================================================

  Widget _buildLoanAccountTab() {
    final s = _summary;
    final totalSanc = s?.totalLoanSanctioned ?? 0.0;
    final totalCred = s?.totalLoanCredited ?? 0.0;
    final totalPend = s?.totalLoanPendingCredit ?? 0.0;
    final totalQuotation = s?.totalSiteAmount ?? 0.0;
    final expected90 = totalQuotation * 0.90;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // KPI SUMMARY
          Row(
            children: [
              Expanded(child: _buildMetricCard('Expected 90% Loan', _currency.format(expected90), Icons.pie_chart, const Color(0xFF2563EB))),
              const SizedBox(width: 12),
              Expanded(child: _buildMetricCard('Loan Sanctioned', _currency.format(totalSanc), Icons.check_circle_outline, const Color(0xFF059669))),
              const SizedBox(width: 12),
              Expanded(child: _buildMetricCard('Actual Bank Credited', _currency.format(totalCred), Icons.account_balance_wallet, const Color(0xFF047857))),
              const SizedBox(width: 12),
              Expanded(child: _buildMetricCard('Pending Loan Credit', _currency.format(totalPend), Icons.hourglass_top, const Color(0xFFD97706))),
            ],
          ),
          const SizedBox(height: 16),

          // ACTIONS BAR
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'SITE-WISE BANK LOAN & CREDIT LEDGER',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
              ),
              Row(
                children: [
                  OutlinedButton.icon(
                    icon: const Icon(Icons.download, size: 16),
                    label: const Text('Export Loan CSV'),
                    onPressed: _exportLoanReportCsv,
                  ),
                  if (widget.isAdmin) ...[
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.add_circle, size: 16),
                      label: const Text('Record Bank Credit'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF047857),
                        foregroundColor: Colors.white,
                      ),
                      onPressed: _openRecordPaymentDialog,
                    ),
                  ],
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),

          // DATA TABLE
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: BorderSide(color: Colors.grey.shade300),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowColor: MaterialStateProperty.all(const Color(0xFFF1F5F9)),
                dataRowMinHeight: 48,
                dataRowMaxHeight: 56,
                columns: const [
                  DataColumn(label: Text('Customer / Site', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Payment Type', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Bank & App ID', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Sanction (₹)', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Expected 90% (₹)', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Credited (₹)', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Pending (₹)', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('10% Diff Status', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Loan Status', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold))),
                ],
                rows: _assignments.map((a) {
                  final expected = a.effectiveSiteAmount * 0.90;
                  final diff10 = a.effectiveSiteAmount * 0.10;
                  final diffRecv = a.totalCashReceived >= diff10;

                  return DataRow(
                    cells: [
                      DataCell(
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(a.customerName ?? 'Site', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            Text('CA: ${a.consumerNo ?? "N/A"}  •  ${a.siteCapacityKw} kW', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                          ],
                        ),
                      ),
                      DataCell(
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: a.isBankLoan ? Colors.indigo.shade50 : Colors.teal.shade50,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            a.paymentType,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: a.isBankLoan ? Colors.indigo.shade800 : Colors.teal.shade800,
                            ),
                          ),
                        ),
                      ),
                      DataCell(
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(a.loanBankName ?? 'State Bank of India', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                            Text(a.loanApplicationId ?? 'Not Assigned', style: const TextStyle(fontSize: 10, color: Colors.grey)),
                          ],
                        ),
                      ),
                      DataCell(Text(_currency.format(a.loanSanctionedAmount), style: const TextStyle(fontSize: 12))),
                      DataCell(Text(_currency.format(expected), style: const TextStyle(fontSize: 12, color: Color(0xFF2563EB), fontWeight: FontWeight.w600))),
                      DataCell(Text(_currency.format(a.totalLoanCredited), style: const TextStyle(fontSize: 12, color: Color(0xFF047857), fontWeight: FontWeight.bold))),
                      DataCell(
                        Text(
                          _currency.format(a.loanPendingCredit),
                          style: TextStyle(
                            fontSize: 12,
                            color: a.loanPendingCredit > 0 ? const Color(0xFFD97706) : Colors.grey,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      DataCell(
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: diffRecv ? Colors.green.shade50 : Colors.amber.shade50,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            diffRecv ? '10% Paid' : '10% Pending (${_currency.format(diff10 - a.totalCashReceived)})',
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: diffRecv ? Colors.green.shade800 : Colors.amber.shade900),
                          ),
                        ),
                      ),
                      DataCell(
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: a.loanStatus == 'Fully Credited' ? Colors.green.shade50 : Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            a.loanStatus,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: a.loanStatus == 'Fully Credited' ? Colors.green.shade800 : Colors.blue.shade800,
                            ),
                          ),
                        ),
                      ),
                      DataCell(
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.remove_red_eye, size: 18, color: Color(0xFF0D2B6F)),
                              tooltip: 'Site Loan Drill-Down',
                              onPressed: () => _openSiteDrillDownDialog(a),
                            ),
                            if (widget.isAdmin)
                              IconButton(
                                icon: const Icon(Icons.add_card, size: 18, color: Color(0xFF047857)),
                                tooltip: 'Add Bank Credit Installment',
                                onPressed: () async {
                                  final recorded = await showDialog<bool>(
                                    context: context,
                                    builder: (_) => RecordCustomerPaymentDialog(
                                      assignment: a,
                                      initialCategory: 'BANK_LOAN',
                                    ),
                                  );
                                  if (recorded == true) _loadAllVendorData();
                                },
                              ),
                          ],
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================================
  // TAB 3: MATERIAL ACCOUNT
  // ============================================================================

  Widget _buildMaterialAccountTab() {
    final s = _summary;
    final m5Total = s?.material5Total ?? 0.0;
    final m18Total = s?.material18Total ?? 0.0;
    final totalMaterialCost = s?.totalMaterialCost ?? 0.0;
    final totalInputGst = s?.totalEligibleInputGst ?? 0.0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // SUMMARY CARDS
          Row(
            children: [
              Expanded(child: _buildMetricCard('5% Solar Modules & Inverters', _currency.format(m5Total), Icons.solar_power, const Color(0xFF0284C7))),
              const SizedBox(width: 12),
              Expanded(child: _buildMetricCard('18% Solar BOS & Structures', _currency.format(m18Total), Icons.construction, const Color(0xFF7C3AED))),
              const SizedBox(width: 12),
              Expanded(child: _buildMetricCard('Eligible Input GST Credit', _currency.format(totalInputGst), Icons.receipt_long, const Color(0xFF059669))),
              const SizedBox(width: 12),
              Expanded(child: _buildMetricCard('Net Material Deducted', _currency.format(totalMaterialCost), Icons.inventory_2, const Color(0xFFDC2626))),
            ],
          ),
          const SizedBox(height: 16),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'ITEMIZED MATERIAL DISPATCH & RETURN REGISTER',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
              ),
              Row(
                children: [
                  OutlinedButton.icon(
                    icon: const Icon(Icons.download, size: 16),
                    label: const Text('Export Material CSV'),
                    onPressed: _exportMaterialReportCsv,
                  ),
                  if (widget.isAdmin) ...[
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('Issue Material'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0D2B6F),
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () async {
                        if (_assignments.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Please assign a site first before issuing material.')),
                          );
                          return;
                        }
                        final recorded = await showDialog<bool>(
                          context: context,
                          builder: (_) => IssueReturnMaterialDialog(
                            assignment: _assignments.first,
                            transactionType: 'ISSUE',
                          ),
                        );
                        if (recorded == true) _loadAllVendorData();
                      },
                    ),
                  ],
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),

          if (_materials.isEmpty)
            Card(
              elevation: 0,
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Center(
                  child: Column(
                    children: const [
                      Icon(Icons.inventory_2_outlined, size: 48, color: Colors.grey),
                      SizedBox(height: 8),
                      const Text('No Material Transactions Recorded Yet', style: TextStyle(fontWeight: FontWeight.bold)),
                      const Text('Materials issued from warehouse will appear here item-by-item.', style: TextStyle(color: Colors.grey, fontSize: 12)),
                    ],
                  ),
                ),
              ),
            )
          else
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: BorderSide(color: Colors.grey.shade300),
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  headingRowColor: MaterialStateProperty.all(const Color(0xFFF1F5F9)),
                  dataRowMinHeight: 46,
                  dataRowMaxHeight: 52,
                  columns: const [
                    DataColumn(label: Text('Date', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('Item Name', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('Category', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('Remarks / Serial', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('Site / Customer', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('Type', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('Qty', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('Rate (₹)', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('GST %', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('Taxable (₹)', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('GST (₹)', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('Net Total (₹)', style: TextStyle(fontWeight: FontWeight.bold))),
                  ],
                  rows: _materials.map((m) {
                    final sign = m.isReturn ? -1.0 : 1.0;
                    final assignment = _assignments.firstWhere(
                      (a) => a.id == m.assignmentId,
                      orElse: () => _assignments.isNotEmpty ? _assignments.first : _assignments.first,
                    );

                    return DataRow(
                      cells: [
                        DataCell(Text(_dateFormat.format(m.transactionDate), style: const TextStyle(fontSize: 12))),
                        DataCell(Text(m.itemName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                        DataCell(Text(m.itemCategory, style: const TextStyle(fontSize: 11, color: Colors.grey))),
                        DataCell(Text(m.remarks ?? m.serialNumbers ?? '-', style: const TextStyle(fontSize: 11))),
                        DataCell(Text(assignment.customerName ?? 'Site', style: const TextStyle(fontSize: 12))),
                        DataCell(
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: m.isReturn ? Colors.orange.shade50 : Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              m.isReturn ? 'RETURN' : 'ISSUE',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: m.isReturn ? Colors.orange.shade800 : Colors.blue.shade800,
                              ),
                            ),
                          ),
                        ),
                        DataCell(Text('${m.isReturn ? "-" : ""}${m.quantity} ${m.unit}', style: const TextStyle(fontSize: 12))),
                        DataCell(Text(_currency.format(m.unitRate), style: const TextStyle(fontSize: 12))),
                        DataCell(Text('${m.gstRate}%', style: const TextStyle(fontSize: 12))),
                        DataCell(Text(_currency.format(sign * m.taxableAmount), style: const TextStyle(fontSize: 12))),
                        DataCell(Text(_currency.format(sign * m.gstAmount), style: const TextStyle(fontSize: 12, color: Color(0xFF047857)))),
                        DataCell(
                          Text(
                            _currency.format(sign * m.totalAmount),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: m.isReturn ? Colors.orange.shade800 : Colors.red.shade800,
                            ),
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ============================================================================
  // TAB 4: GST ACCOUNT
  // ============================================================================

  Widget _buildGstAccountTab() {
    final s = _summary;
    final totalQuotation = s?.totalSiteAmount ?? 0.0;
    final taxableBilling = totalQuotation / 1.138;
    final outputGst = totalQuotation - taxableBilling;
    final eligibleItc = s?.totalEligibleInputGst ?? 0.0;
    final netGstPayable = (outputGst - eligibleItc).clamp(0.0, double.infinity);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // STATUTORY NOTICE BANNER
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFBFDBFE)),
            ),
            child: Row(
              children: const [
                Icon(Icons.info_outline, color: Color(0xFF1D4ED8)),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Statutory GST Treatment: Composite Solar Supply is calculated on customer quotation billing. Eligible Input Tax Credit (ITC) from purchased Solar Panels (5%) and BOS (18%) is adjusted against Output GST to determine Net GST Payable. No double deduction is applied.',
                    style: TextStyle(fontSize: 12.5, color: Color(0xFF1E3A8A)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // SUMMARY CARDS
          Row(
            children: [
              Expanded(child: _buildMetricCard('Taxable Site Revenue', _currency.format(taxableBilling), Icons.receipt, const Color(0xFF1E3A8A))),
              const SizedBox(width: 12),
              Expanded(child: _buildMetricCard('Output GST Liability', _currency.format(outputGst), Icons.receipt_long, const Color(0xFF7C3AED))),
              const SizedBox(width: 12),
              Expanded(child: _buildMetricCard('Eligible Material ITC', _currency.format(eligibleItc), Icons.assignment_turned_in, const Color(0xFF047857))),
              const SizedBox(width: 12),
              Expanded(child: _buildMetricCard('Net GST Payable to Govt', _currency.format(netGstPayable), Icons.account_balance, const Color(0xFF4C1D95))),
            ],
          ),
          const SizedBox(height: 16),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'SITE-WISE GST BREAKDOWN & AUDIT TABLE',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
              ),
              OutlinedButton.icon(
                icon: const Icon(Icons.download, size: 16),
                label: const Text('Export GST CSV'),
                onPressed: _exportGstSummaryCsv,
              ),
            ],
          ),
          const SizedBox(height: 12),

          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: BorderSide(color: Colors.grey.shade300),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowColor: MaterialStateProperty.all(const Color(0xFFF1F5F9)),
                dataRowMinHeight: 46,
                dataRowMaxHeight: 52,
                columns: const [
                  DataColumn(label: Text('Customer / Site', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Capacity (kW)', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Gross Billing (₹)', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Taxable Value (₹)', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Output GST (₹)', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Material Cost (₹)', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Input ITC (₹)', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Net GST Payable (₹)', style: TextStyle(fontWeight: FontWeight.bold))),
                ],
                rows: _assignments.map((a) {
                  final gross = a.effectiveSiteAmount;
                  final taxable = gross / 1.138;
                  final outGst = gross - taxable;

                  final siteMats = _materials.where((m) => m.assignmentId == a.id).toList();
                  double inGst = 0.0;
                  double matCost = 0.0;
                  for (final m in siteMats) {
                    final s = m.isReturn ? -1.0 : 1.0;
                    inGst += s * m.gstAmount;
                    matCost += s * m.totalAmount;
                  }
                  final netGst = (outGst - inGst).clamp(0.0, double.infinity);

                  return DataRow(
                    cells: [
                      DataCell(
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(a.customerName ?? 'Site', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            Text('CA: ${a.consumerNo ?? "N/A"}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                          ],
                        ),
                      ),
                      DataCell(Text('${a.siteCapacityKw} kW', style: const TextStyle(fontSize: 12))),
                      DataCell(Text(_currency.format(gross), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                      DataCell(Text(_currency.format(taxable), style: const TextStyle(fontSize: 12))),
                      DataCell(Text(_currency.format(outGst), style: const TextStyle(fontSize: 12, color: Color(0xFF7C3AED)))),
                      DataCell(Text(_currency.format(matCost), style: const TextStyle(fontSize: 12, color: Colors.red))),
                      DataCell(Text(_currency.format(inGst), style: const TextStyle(fontSize: 12, color: Color(0xFF047857), fontWeight: FontWeight.w600))),
                      DataCell(
                        Text(
                          _currency.format(netGst),
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF4C1D95)),
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================================
  // TAB 5: SIYA VENDOR CHARGES
  // ============================================================================

  Widget _buildVendorChargesTab() {
    final s = _summary;
    final totalKw = s?.totalCapacityKw ?? 0.0;
    final totalCharges = s?.totalVendorCharges ?? 0.0;
    final totalExpenses = s?.totalOtherExpenses ?? 0.0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFBEB),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFFDE68A)),
            ),
            child: Row(
              children: const [
                Icon(Icons.bolt, color: Color(0xFFD97706)),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'SIYA Platform Management Fee: Standard ₹1,000 per installed kW. Calculated directly from approved site capacity.',
                    style: TextStyle(fontSize: 12.5, color: Color(0xFF92400E)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          Row(
            children: [
              Expanded(child: _buildMetricCard('Total Assigned kW', '${totalKw.toStringAsFixed(1)} kW', Icons.speed, const Color(0xFF1E3A8A))),
              const SizedBox(width: 12),
              Expanded(child: _buildMetricCard('Platform Rate', '${_currency.format(widget.vendor.defaultRatePerKw)}/kW', Icons.currency_rupee, const Color(0xFFD97706))),
              const SizedBox(width: 12),
              Expanded(child: _buildMetricCard('SIYA Vendor Charges', _currency.format(totalCharges), Icons.bolt, const Color(0xFFEA580C))),
              const SizedBox(width: 12),
              Expanded(child: _buildMetricCard('Other Approved Expenses', _currency.format(totalExpenses), Icons.receipt, const Color(0xFF475569))),
            ],
          ),
          const SizedBox(height: 16),

          const Text(
            'SITE-BY-SITE CHARGES AUDIT REGISTER',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
          ),
          const SizedBox(height: 12),

          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: BorderSide(color: Colors.grey.shade300),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowColor: MaterialStateProperty.all(const Color(0xFFF1F5F9)),
                dataRowMinHeight: 46,
                dataRowMaxHeight: 52,
                columns: const [
                  DataColumn(label: Text('Customer / Site', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Installed kW', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Rate / kW (₹)', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('SIYA Fee (₹)', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Other Expenses (₹)', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Total Deductible (₹)', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.bold))),
                ],
                rows: _assignments.map((a) {
                  final charges = a.siteCapacityKw * a.ratePerKw;
                  final expenses = a.otherExpenses;
                  final totalDeduct = charges + expenses;

                  return DataRow(
                    cells: [
                      DataCell(
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(a.customerName ?? 'Site', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            Text('CA: ${a.consumerNo ?? "N/A"}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                          ],
                        ),
                      ),
                      DataCell(Text('${a.siteCapacityKw} kW', style: const TextStyle(fontSize: 12))),
                      DataCell(Text(_currency.format(a.ratePerKw), style: const TextStyle(fontSize: 12))),
                      DataCell(Text(_currency.format(charges), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFFEA580C)))),
                      DataCell(Text(_currency.format(expenses), style: const TextStyle(fontSize: 12))),
                      DataCell(Text(_currency.format(totalDeduct), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                      DataCell(
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: a.financialApproved ? Colors.green.shade50 : Colors.amber.shade50,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            a.financialApproved ? 'Approved' : 'Pending Approval',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: a.financialApproved ? Colors.green.shade800 : Colors.amber.shade900,
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================================
  // TAB 6: PAYMENT & FINAL SETTLEMENT
  // ============================================================================

  Widget _buildPaymentSettlementTab() {
    final s = _summary;
    if (s == null) return const Center(child: Text('No data'));

    final totalCollection = s.totalCustomerCollection > 0 ? s.totalCustomerCollection : s.totalSiteAmount;
    final totalMaterialCost = s.totalMaterialCost;
    final taxableBilling = s.totalSiteAmount / 1.138;
    final outputGst = s.totalSiteAmount - taxableBilling;
    final netGst = (outputGst - s.totalEligibleInputGst).clamp(0.0, double.infinity);
    final vendorCharges = s.totalVendorCharges;
    final otherExpenses = s.totalOtherExpenses;
    final previousPayments = s.totalPaidAmount;

    final netEntitlement = totalCollection - totalMaterialCost - vendorCharges - otherExpenses - netGst;
    final finalAmount = netEntitlement - previousPayments;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // CONTRACTUAL DEDUCTIONS AUDIT CARD
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            elevation: 0,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'OPTION A: FINAL CONTRACTUAL SETTLEMENT BREAKDOWN',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0FDF4),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xFF86EFAC)),
                        ),
                        child: const Text('Contract Standard Formula', style: TextStyle(fontSize: 11, color: Color(0xFF166534), fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  _buildSettlementRow('Total Realized Collections (Loan Credited + Cash)', _currency.format(totalCollection), isPositive: true),
                  _buildSettlementRow('Less: Total Material Issued (Net of Returns)', '- ${_currency.format(totalMaterialCost)}', isPositive: false),
                  _buildSettlementRow('Less: SIYA Vendor Charges (₹1,000/kW)', '- ${_currency.format(vendorCharges)}', isPositive: false),
                  _buildSettlementRow('Less: Net Statutory GST Liability', '- ${_currency.format(netGst)}', isPositive: false),
                  _buildSettlementRow('Less: Other Approved Site Expenses', '- ${_currency.format(otherExpenses)}', isPositive: false),
                  const Divider(height: 20),
                  _buildSettlementRow('Sub-Vendor Net Entitlement', _currency.format(netEntitlement), isBold: true),
                  _buildSettlementRow('Less: Previous Advances & Disbursals Paid', '- ${_currency.format(previousPayments)}', isPositive: false),
                  const Divider(height: 24, thickness: 1.5),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        finalAmount >= 0 ? 'FINAL AMOUNT PAYABLE TO SUB-VENDOR' : 'AMOUNT RECOVERABLE FROM SUB-VENDOR',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          color: finalAmount >= 0 ? const Color(0xFF047857) : Colors.red.shade800,
                        ),
                      ),
                      Text(
                        _currency.format(finalAmount.abs()),
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: finalAmount >= 0 ? const Color(0xFF047857) : Colors.red.shade800,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // PREVIOUS PAYOUTS / ADVANCES TABLE
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'DISBURSED ADVANCES & SETTLEMENT PAYOUTS',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
              ),
              if (widget.isAdmin)
                ElevatedButton.icon(
                  icon: const Icon(Icons.payment, size: 16),
                  label: const Text('Record Payout'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF047857),
                    foregroundColor: Colors.white,
                  ),
                  onPressed: _openRecordPayoutDialog,
                ),
            ],
          ),
          const SizedBox(height: 12),

          if (_payouts.isEmpty)
            Card(
              elevation: 0,
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Center(
                  child: Column(
                    children: const [
                      Icon(Icons.payments_outlined, size: 36, color: Colors.grey),
                      SizedBox(height: 6),
                      Text('No payouts recorded yet.', style: TextStyle(color: Colors.grey)),
                    ],
                  ),
                ),
              ),
            )
          else
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: BorderSide(color: Colors.grey.shade300),
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  headingRowColor: MaterialStateProperty.all(const Color(0xFFF1F5F9)),
                  columns: const [
                    DataColumn(label: Text('Date', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('Site / Assignment', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('Amount (₹)', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('Payment Mode', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('Reference / UTR', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('Notes', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.bold))),
                  ],
                  rows: _payouts.map((p) {
                    return DataRow(
                      cells: [
                        DataCell(Text(_dateFormat.format(p.payoutDate))),
                        DataCell(Text(p.customerName ?? 'General Vendor Advance')),
                        DataCell(Text(_currency.format(p.amount), style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF047857)))),
                        DataCell(Text(p.paymentMode)),
                        DataCell(Text(p.referenceNumber ?? '-')),
                        DataCell(Text(p.remarks ?? '-')),
                        DataCell(
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.green.shade50,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(p.status, style: TextStyle(color: Colors.green.shade800, fontSize: 11, fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSettlementRow(String label, String value, {bool isPositive = true, bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 13, fontWeight: isBold ? FontWeight.bold : FontWeight.normal, color: const Color(0xFF334155))),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
              color: isPositive ? const Color(0xFF047857) : Colors.red.shade700,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================================
  // TAB 7: SITE-WISE DRILL DOWN
  // ============================================================================

  Widget _buildSiteDrillDownTab() {
    final filtered = _assignments.where((a) {
      final q = _siteSearch.toLowerCase();
      return q.isEmpty ||
          (a.customerName?.toLowerCase().contains(q) ?? false) ||
          (a.consumerNo?.toLowerCase().contains(q) ?? false);
    }).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // SEARCH BAR
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: BorderSide(color: Colors.grey.shade300),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12.0),
              child: TextField(
                decoration: const InputDecoration(
                  hintText: 'Search site by Customer Name or Consumer No...',
                  prefixIcon: Icon(Icons.search),
                  border: InputBorder.none,
                ),
                onChanged: (val) => setState(() => _siteSearch = val),
              ),
            ),
          ),
          const SizedBox(height: 16),

          if (filtered.isEmpty)
            Card(
              elevation: 0,
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Center(
                  child: Column(
                    children: const [
                      Icon(Icons.layers_clear, size: 48, color: Colors.grey),
                      SizedBox(height: 8),
                      Text('No assigned sites match your search.', style: TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: filtered.length,
              itemBuilder: (context, index) {
                final a = filtered[index];
                final detail = _summary?.siteDetails.firstWhere(
                  (d) => d.assignment.id == a.id,
                  orElse: () => SiteFinancialDetail.compute(
                    assignment: a,
                    materials: _materials.where((m) => m.assignmentId == a.id).toList(),
                    payouts: _payouts.where((p) => p.assignmentId == a.id).toList(),
                  ),
                );

                return Card(
                  elevation: 0,
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: BorderSide(color: Colors.grey.shade300),
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () => _openSiteDrillDownDialog(a),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const CircleAvatar(
                                radius: 18,
                                backgroundColor: Color(0xFFE0F2FE),
                                child: Icon(Icons.solar_power, color: Color(0xFF0D2B6F), size: 18),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      a.customerName ?? 'Customer Site',
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                    ),
                                    Text(
                                      'Consumer No: ${a.consumerNo ?? "N/A"}  •  ${a.siteCapacityKw} kW System  •  Status: ${a.status}',
                                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: a.loanStatus == 'Fully Credited' ? Colors.green.shade50 : Colors.blue.shade50,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  a.paymentType,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: a.loanStatus == 'Fully Credited' ? Colors.green.shade800 : Colors.blue.shade800,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 20),
                          Wrap(
                            spacing: 20,
                            runSpacing: 8,
                            children: [
                              _buildMiniStat('Quotation', _currency.format(a.effectiveSiteAmount)),
                              _buildMiniStat('Loan Credited', _currency.format(a.totalLoanCredited), color: const Color(0xFF047857)),
                              _buildMiniStat('Cash Received', _currency.format(a.totalCashReceived), color: const Color(0xFF0D9488)),
                              _buildMiniStat('Material Deducted', _currency.format(detail?.totalMaterialCost ?? 0.0), color: Colors.red),
                              _buildMiniStat('SIYA Platform Fee', _currency.format(detail?.vendorCharges ?? 0.0), color: const Color(0xFFEA580C)),
                              _buildMiniStat('Net Sub-Vendor Due', _currency.format(detail?.netSubVendorBalance ?? 0.0), color: const Color(0xFF1E3A8A), isBold: true),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              TextButton.icon(
                                icon: const Icon(Icons.picture_as_pdf, size: 16),
                                label: const Text('Site Statement PDF'),
                                onPressed: () {
                                  if (detail != null) {
                                    SubVendorPdfService.printOrShareSiteStatement(detail, vendor: widget.vendor);
                                  }
                                },
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton.icon(
                                icon: const Icon(Icons.open_in_new, size: 16),
                                label: const Text('Open Complete Audit & Drill-Down'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF0D2B6F),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                ),
                                onPressed: () => _openSiteDrillDownDialog(a),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildMiniStat(String label, String value, {Color color = const Color(0xFF0F172A), bool isBold = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }

  // ============================================================================
  // DIALOG LAUNCHERS
  // ============================================================================

  void _openSettlementCalculator() {
    if (_assignments.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No site assignments found to calculate settlement.')),
      );
      return;
    }
    if (_assignments.length == 1) {
      showDialog(
        context: context,
        builder: (_) => SubVendorFinalSettlementCalculatorDialog(
          assignment: _assignments.first,
          vendor: widget.vendor,
        ),
      ).then((_) => _loadAllVendorData());
      return;
    }
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.calculate, color: Color(0xFF0D2B6F)),
            SizedBox(width: 8),
            Text('Select Site for Settlement Calculation'),
          ],
        ),
        content: SizedBox(
          width: 480,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: _assignments.length,
            itemBuilder: (context, index) {
              final a = _assignments[index];
              return ListTile(
                leading: const Icon(Icons.solar_power, color: Color(0xFF0D2B6F)),
                title: Text(a.customerName ?? 'Customer Site', style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text('CA: ${a.consumerNo ?? "N/A"} • ${a.siteCapacityKw} kW • ${_currency.format(a.effectiveSiteAmount)}'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                onTap: () {
                  Navigator.of(ctx).pop();
                  showDialog(
                    context: context,
                    builder: (_) => SubVendorFinalSettlementCalculatorDialog(
                      assignment: a,
                      vendor: widget.vendor,
                    ),
                  ).then((_) => _loadAllVendorData());
                },
              );
            },
          ),
        ),
      ),
    );
  }

  void _openRecordPayoutDialog() async {
    final recorded = await showDialog<bool>(
      context: context,
      builder: (_) => RecordVendorPayoutDialog(
        vendor: widget.vendor,
        assignments: _assignments,
      ),
    );
    if (recorded == true) _loadAllVendorData();
  }

  void _openRecordPaymentDialog() async {
    if (_assignments.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please assign a site first before recording customer payment / loan credit.')),
      );
      return;
    }
    final recorded = await showDialog<bool>(
      context: context,
      builder: (_) => RecordCustomerPaymentDialog(
        assignment: _assignments.first,
        initialCategory: 'BANK_LOAN',
      ),
    );
    if (recorded == true) _loadAllVendorData();
  }

  void _openSiteDrillDownDialog(VendorSiteAssignment assignment) {
    showDialog(
      context: context,
      builder: (_) => _SiteComprehensiveDrillDownModal(
        assignment: assignment,
        vendor: widget.vendor,
        materials: _materials.where((m) => m.assignmentId == assignment.id).toList(),
        customerPayments: _customerPayments.where((cp) => cp.assignmentId == assignment.id).toList(),
        payouts: _payouts.where((p) => p.assignmentId == assignment.id).toList(),
        isAdmin: widget.isAdmin,
        onRefreshNeeded: _loadAllVendorData,
      ),
    );
  }
}

// ============================================================================
// SITE COMPREHENSIVE DRILL-DOWN MODAL
// ============================================================================

class _SiteComprehensiveDrillDownModal extends StatelessWidget {
  final VendorSiteAssignment assignment;
  final SubVendor vendor;
  final List<VendorMaterialTransaction> materials;
  final List<VendorCustomerPayment> customerPayments;
  final List<VendorPayout> payouts;
  final bool isAdmin;
  final VoidCallback onRefreshNeeded;

  const _SiteComprehensiveDrillDownModal({
    required this.assignment,
    required this.vendor,
    required this.materials,
    required this.customerPayments,
    required this.payouts,
    required this.isAdmin,
    required this.onRefreshNeeded,
  });

  @override
  Widget build(BuildContext context) {
    final a = assignment;
    final detail = SiteFinancialDetail.compute(
      assignment: a,
      materials: materials,
      payouts: payouts,
    );

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 850, maxHeight: 850),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // HEADER
              Row(
                children: [
                  const CircleAvatar(
                    radius: 20,
                    backgroundColor: Color(0xFF0D2B6F),
                    child: Icon(Icons.solar_power, color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          a.customerName ?? 'Customer Site Audit',
                          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'CA: ${a.consumerNo ?? "N/A"}  •  ${a.siteCapacityKw} kW  •  Sub-Vendor: ${vendor.name} (${vendor.vendorCode})',
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.picture_as_pdf, size: 16),
                    label: const Text('Download PDF'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0D2B6F),
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () => SubVendorPdfService.printOrShareSiteStatement(detail, vendor: vendor),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const Divider(height: 24),

              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 1. COMMERCIAL & PAYMENT PROFILE
                      const Text('1. COMMERCIAL & PAYMENT PROFILE', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Row(
                          children: [
                            Expanded(child: _buildModalField('Quotation (100%)', _currency.format(a.effectiveSiteAmount))),
                            Expanded(child: _buildModalField('Payment Type', a.paymentType)),
                            Expanded(child: _buildModalField('Disbursing Bank', a.loanBankName ?? 'N/A')),
                            Expanded(child: _buildModalField('Loan App ID', a.loanApplicationId ?? 'N/A')),
                            Expanded(child: _buildModalField('Loan Sanctioned', _currency.format(a.loanSanctionedAmount))),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // 2. REALIZED COLLECTIONS (CASH & LOAN CREDITS)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('2. REALIZED CUSTOMER & LOAN COLLECTIONS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          if (isAdmin)
                            TextButton.icon(
                              icon: const Icon(Icons.add, size: 16),
                              label: const Text('Record Installment'),
                              onPressed: () async {
                                final recorded = await showDialog<bool>(
                                  context: context,
                                  builder: (_) => RecordCustomerPaymentDialog(
                                    assignment: a,
                                    initialCategory: a.isBankLoan ? 'BANK_LOAN' : 'CASH',
                                  ),
                                );
                                if (recorded == true) {
                                  Navigator.of(context).pop();
                                  onRefreshNeeded();
                                }
                              },
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (customerPayments.isEmpty)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(6)),
                          child: const Text('No cash or loan credits recorded yet.', style: TextStyle(color: Colors.grey, fontSize: 12)),
                        )
                      else
                        Table(
                          border: TableBorder.all(color: Colors.grey.shade300),
                          children: [
                            TableRow(
                              decoration: const BoxDecoration(color: Color(0xFFF1F5F9)),
                              children: const [
                                Padding(padding: EdgeInsets.all(6), child: Text('Date', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                                Padding(padding: EdgeInsets.all(6), child: Text('Type', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                                Padding(padding: EdgeInsets.all(6), child: Text('Amount', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                                Padding(padding: EdgeInsets.all(6), child: Text('Mode', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                                Padding(padding: EdgeInsets.all(6), child: Text('UTR / Reference', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                                Padding(padding: EdgeInsets.all(6), child: Text('Bank', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                              ],
                            ),
                            for (final cp in customerPayments)
                              TableRow(
                                children: [
                                  Padding(padding: const EdgeInsets.all(6), child: Text(_dateFormat.format(cp.paymentDate), style: const TextStyle(fontSize: 11))),
                                  Padding(padding: const EdgeInsets.all(6), child: Text(cp.paymentType, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
                                  Padding(padding: const EdgeInsets.all(6), child: Text(_currency.format(cp.amount), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF047857)))),
                                  Padding(padding: const EdgeInsets.all(6), child: Text(cp.paymentMode, style: const TextStyle(fontSize: 11))),
                                  Padding(padding: const EdgeInsets.all(6), child: Text(cp.referenceNumber ?? '-', style: const TextStyle(fontSize: 11))),
                                  Padding(padding: const EdgeInsets.all(6), child: Text(cp.bankName ?? '-', style: const TextStyle(fontSize: 11))),
                                ],
                              ),
                          ],
                        ),
                      const SizedBox(height: 16),

                      // 3. MATERIALS ISSUED TO THIS SITE
                      const Text('3. MATERIALS ISSUED TO THIS SITE', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      const SizedBox(height: 8),
                      if (materials.isEmpty)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(6)),
                          child: const Text('No materials issued for this site.', style: TextStyle(color: Colors.grey, fontSize: 12)),
                        )
                      else
                        Table(
                          border: TableBorder.all(color: Colors.grey.shade300),
                          children: [
                            TableRow(
                              decoration: const BoxDecoration(color: Color(0xFFF1F5F9)),
                              children: const [
                                Padding(padding: EdgeInsets.all(6), child: Text('Item', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                                Padding(padding: EdgeInsets.all(6), child: Text('Category', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                                Padding(padding: EdgeInsets.all(6), child: Text('Qty', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                                Padding(padding: EdgeInsets.all(6), child: Text('Rate', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                                Padding(padding: EdgeInsets.all(6), child: Text('GST %', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                                Padding(padding: EdgeInsets.all(6), child: Text('Total Cost', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                              ],
                            ),
                            for (final m in materials)
                              TableRow(
                                children: [
                                  Padding(padding: const EdgeInsets.all(6), child: Text(m.itemName, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
                                  Padding(padding: const EdgeInsets.all(6), child: Text(m.itemCategory, style: const TextStyle(fontSize: 11))),
                                  Padding(padding: const EdgeInsets.all(6), child: Text('${m.isReturn ? "-" : ""}${m.quantity} ${m.unit}', style: const TextStyle(fontSize: 11))),
                                  Padding(padding: const EdgeInsets.all(6), child: Text(_currency.format(m.unitRate), style: const TextStyle(fontSize: 11))),
                                  Padding(padding: const EdgeInsets.all(6), child: Text('${m.gstRate}%', style: const TextStyle(fontSize: 11))),
                                  Padding(padding: const EdgeInsets.all(6), child: Text(_currency.format((m.isReturn ? -1 : 1) * m.totalAmount), style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: m.isReturn ? Colors.orange : Colors.red))),
                                ],
                              ),
                          ],
                        ),
                      const SizedBox(height: 16),

                      // 4. SITE FINAL SETTLEMENT SUMMARY
                      const Text('4. SITE CONTRACTUAL SETTLEMENT LEDGER', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFECFDF5),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFA7F3D0)),
                        ),
                        child: Column(
                          children: [
                            _buildMiniSummaryRow('Effective Realized Collection', _currency.format(detail.effectiveCollection), isPositive: true),
                            _buildMiniSummaryRow('Less: Material Cost Deducted', '- ${_currency.format(detail.totalMaterialCost)}', isPositive: false),
                            _buildMiniSummaryRow('Less: SIYA Vendor Charges (₹1,000/kW)', '- ${_currency.format(detail.vendorCharges)}', isPositive: false),
                            _buildMiniSummaryRow('Less: Other Site Expenses', '- ${_currency.format(detail.otherExpenses)}', isPositive: false),
                            _buildMiniSummaryRow('Less: Paid to Sub-Vendor', '- ${_currency.format(detail.totalPaidToVendor)}', isPositive: false),
                            const Divider(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Net Site Balance Payable / Due:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF065F46))),
                                Text(
                                  _currency.format(detail.netSubVendorBalance),
                                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Color(0xFF047857)),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModalField(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildMiniSummaryRow(String label, String value, {bool isPositive = true}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF334155))),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: isPositive ? const Color(0xFF047857) : Colors.red.shade700,
            ),
          ),
        ],
      ),
    );
  }
}
