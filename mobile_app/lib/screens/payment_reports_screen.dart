import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import '../models/customer_payment.dart';
import '../models/consumer_record.dart';
import '../services/app_database.dart';

class PaymentReportsScreen extends StatefulWidget {
  const PaymentReportsScreen({super.key});

  @override
  State<PaymentReportsScreen> createState() => _PaymentReportsScreenState();
}

class _PaymentReportsScreenState extends State<PaymentReportsScreen> {
  bool _isLoading = true;
  List<PaymentTransaction> _allPayments = [];
  List<ConsumerRecord> _allCustomers = [];

  String _selectedReport = 'Mode-wise'; // 'Mode-wise', 'Village-wise', 'Staff-wise', 'Pending-wise'

  @override
  void initState() {
    super.initState();
    _loadReportData();
  }

  Future<void> _loadReportData() async {
    setState(() => _isLoading = true);
    try {
      final payments = await AppDatabase.getAllPayments();
      final customers = await AppDatabase.getAllConsumerRecords();

      if (mounted) {
        setState(() {
          _allPayments = payments;
          _allCustomers = customers;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading reports: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _exportCsv() async {
    final buffer = StringBuffer();
    buffer.writeln('Receipt_ID,Consumer_No,Amount,Date,Mode,Type,Status,Sync_Status,Verification');

    for (final tx in _allPayments) {
      buffer.writeln(
        '${tx.id ?? tx.clientTxId},${tx.consumerNo},${tx.amount},${DateFormat('yyyy-MM-dd').format(tx.paymentDate)},${tx.paymentMode},${tx.paymentType},${tx.status},${tx.syncStatus},${tx.verificationStatus}',
      );
    }

    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/Payment_Report_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.csv');
    await file.writeAsString(buffer.toString());

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Report exported: ${file.path.split(Platform.pathSeparator).last}'),
          action: SnackBarAction(
            label: 'Open',
            onPressed: () => OpenFilex.open(file.path),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Payment Reports & Analytics', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.download_rounded),
            tooltip: 'Export CSV',
            onPressed: _exportCsv,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Report Type Selector
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'Mode-wise', label: Text('Mode')),
                    ButtonSegment(value: 'Village-wise', label: Text('Village')),
                    ButtonSegment(value: 'Staff-wise', label: Text('Staff')),
                    ButtonSegment(value: 'Pending-wise', label: Text('Pending')),
                  ],
                  selected: {_selectedReport},
                  onSelectionChanged: (newVal) => setState(() => _selectedReport = newVal.first),
                ),
                const SizedBox(height: 16),

                // Report Summary Body
                if (_selectedReport == 'Mode-wise') _buildModeReport(theme, isDark),
                if (_selectedReport == 'Village-wise') _buildVillageReport(theme, isDark),
                if (_selectedReport == 'Staff-wise') _buildStaffReport(theme, isDark),
                if (_selectedReport == 'Pending-wise') _buildPendingReport(theme, isDark),
              ],
            ),
    );
  }

  Widget _buildModeReport(ThemeData theme, bool isDark) {
    final Map<String, double> totals = {};
    final Map<String, int> counts = {};

    for (final tx in _allPayments) {
      totals[tx.paymentMode] = (totals[tx.paymentMode] ?? 0.0) + tx.amount;
      counts[tx.paymentMode] = (counts[tx.paymentMode] ?? 0) + 1;
    }

    if (totals.isEmpty) return const Center(child: Text('No transactions to report.'));

    return Column(
      children: totals.entries.map((e) {
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.1),
              child: Icon(PaymentMode.getModeIcon(e.key), color: theme.colorScheme.primary),
            ),
            title: Text(e.key, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text('${counts[e.key]} transaction(s)'),
            trailing: Text(
              '₹${NumberFormat('#,##,###').format(e.value)}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF059669)),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildVillageReport(ThemeData theme, bool isDark) {
    final Map<String, double> villagePending = {};
    final Map<String, int> villageCustomers = {};

    for (final c in _allCustomers) {
      final v = c.village ?? c.address ?? 'Unspecified';
      villagePending[v] = (villagePending[v] ?? 0.0) + c.pendingAmount;
      villageCustomers[v] = (villageCustomers[v] ?? 0) + 1;
    }

    return Column(
      children: villagePending.entries.map((e) {
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ListTile(
            leading: const CircleAvatar(
              child: Icon(Icons.location_city_rounded, size: 20),
            ),
            title: Text(e.key, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text('${villageCustomers[e.key]} customer(s)'),
            trailing: Text(
              '₹${NumberFormat('#,##,###').format(e.value)}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFFDC2626)),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildStaffReport(ThemeData theme, bool isDark) {
    final Map<String, double> staffCollected = {};
    final Map<String, int> staffTxCount = {};

    for (final tx in _allPayments) {
      final staff = tx.receivedBy ?? tx.createdByName ?? 'General';
      staffCollected[staff] = (staffCollected[staff] ?? 0.0) + tx.amount;
      staffTxCount[staff] = (staffTxCount[staff] ?? 0) + 1;
    }

    return Column(
      children: staffCollected.entries.map((e) {
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ListTile(
            leading: const CircleAvatar(
              child: Icon(Icons.badge_rounded, size: 20),
            ),
            title: Text(e.key, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text('${staffTxCount[e.key]} collected payment(s)'),
            trailing: Text(
              '₹${NumberFormat('#,##,###').format(e.value)}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF059669)),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildPendingReport(ThemeData theme, bool isDark) {
    final pendingCusts = _allCustomers
        .where((c) => c.pendingAmount > 0 && c.customerWorkState != 'COMPLETED')
        .toList()
      ..sort((a, b) => b.pendingAmount.compareTo(a.pendingAmount));

    return Column(
      children: pendingCusts.map((c) {
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ListTile(
            title: Text(c.name, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text('${c.consumerNo} • Stage: ${c.installationStatus}'),
            trailing: Text(
              '₹${NumberFormat('#,##,###').format(c.pendingAmount)}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFFDC2626)),
            ),
          ),
        );
      }).toList(),
    );
  }
}
