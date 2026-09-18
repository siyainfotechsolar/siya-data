import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/customer_task.dart';
import '../services/supabase_service.dart';
import '../services/activity_log_service.dart';

class WhatsAppTasksScreen extends StatefulWidget {
  const WhatsAppTasksScreen({super.key});

  @override
  State<WhatsAppTasksScreen> createState() => _WhatsAppTasksScreenState();
}

class _WhatsAppTasksScreenState extends State<WhatsAppTasksScreen> {
  List<CustomerTask> _tasks = [];
  bool _isLoading = true;
  String _statusFilter = 'ALL';
  String _sourceFilter = 'WhatsApp Share';
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchTasks();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchTasks() async {
    setState(() => _isLoading = true);
    try {
      var query = SupabaseService.client.from('customer_tasks').select();

      if (_statusFilter != 'ALL') {
        query = query.eq('status', _statusFilter);
      }
      if (_sourceFilter != 'ALL') {
        query = query.eq('source', _sourceFilter);
      }

      final list = await query.order('created_at', ascending: false).limit(100);
      final fetched = list.map((item) => CustomerTask.fromMap(item)).toList();

      if (mounted) {
        setState(() {
          _tasks = fetched;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching tasks in admin panel: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  List<CustomerTask> get _filteredTasks {
    if (_searchQuery.trim().isEmpty) return _tasks;
    final q = _searchQuery.toLowerCase().trim();
    return _tasks.where((t) {
      return t.title.toLowerCase().contains(q) ||
          t.customerName.toLowerCase().contains(q) ||
          t.consumerNo.toLowerCase().contains(q) ||
          t.documentName.toLowerCase().contains(q) ||
          (t.assignedStaff?.toLowerCase().contains(q) ?? false);
    }).toList();
  }

  Future<void> _openDocumentUrl(String? url) async {
    if (url == null || url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Document URL not available or document is local')),
      );
      return;
    }
    final uri = Uri.parse(url);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        await launchUrl(uri);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open document: $e')),
        );
      }
    }
  }

  void _showTaskDetailDialog(CustomerTask task) {
    final dateFormat = DateFormat('dd MMM yyyy, hh:mm a');
    final extracted = task.extractedData ?? {};

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFF25D366).withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.share, color: Color(0xFF25D366), size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    task.title,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    '${task.documentType} • Source: ${task.source}',
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.of(ctx).pop(),
            ),
          ],
        ),
        content: SizedBox(
          width: 600,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Status & Priority Banner
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: task.statusColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: task.statusColor),
                      ),
                      child: Text(
                        task.status.toUpperCase(),
                        style: TextStyle(
                          color: task.statusColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Priority: ${task.priority}',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      'Created: ${dateFormat.format(task.createdAt)}',
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // 2. Customer Information Card
                Card(
                  elevation: 0,
                  color: Colors.grey.shade50,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: BorderSide(color: Colors.grey.shade200),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'CUSTOMER INFORMATION',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          task.customerName,
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Text('Consumer No: ${task.consumerNo}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                            if (task.mobileNumber != null) ...[
                              const SizedBox(width: 12),
                              Text('Mobile: ${task.mobileNumber}', style: const TextStyle(fontSize: 12)),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // 3. Document Attachment Card
                Card(
                  elevation: 0,
                  color: const Color(0xFFF0FDF4),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: const BorderSide(color: Color(0xFFA7F3D0)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Row(
                      children: [
                        const Icon(Icons.picture_as_pdf_rounded, color: Colors.red, size: 32),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                task.documentName,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                              Text(
                                'File Size: ${(task.fileSize / 1024).toStringAsFixed(1)} KB',
                                style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                              ),
                            ],
                          ),
                        ),
                        FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF059669),
                            visualDensity: VisualDensity.compact,
                          ),
                          onPressed: () => _openDocumentUrl(task.documentUrl),
                          icon: const Icon(Icons.open_in_new, size: 14),
                          label: const Text('Open PDF'),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // 4. Extracted Document Information
                if (extracted.isNotEmpty) ...[
                  const Text(
                    'SMART EXTRACTED DATA',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (extracted['consumerNo'] != null)
                          Text('• Extracted Consumer No: ${extracted['consumerNo']}'),
                        if (extracted['customerName'] != null)
                          Text('• Extracted Customer Name: ${extracted['customerName']}'),
                        if (extracted['billAmount'] != null)
                          Text('• Bill Amount: ₹${extracted['billAmount']}'),
                        if (extracted['billDate'] != null)
                          Text('• Bill Date: ${extracted['billDate']}'),
                        if (extracted['paymentCandidate'] != null)
                          Text('• Payment Proof: Ref: ${extracted['paymentCandidate']['referenceNumber']} | Amount: ₹${extracted['paymentCandidate']['amount']}'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                // 5. Assigned Staff & Remarks
                Row(
                  children: [
                    Text('Assigned To: ${task.assignedStaff ?? "Unassigned"}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                    const Spacer(),
                    if (task.dueDate != null)
                      Text('Due Date: ${DateFormat('dd-MM-yyyy').format(task.dueDate!)}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                ),
                if (task.remarks != null && task.remarks!.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text('Remarks: ${task.remarks}', style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Close'),
          ),
          PopupMenuButton<String>(
            tooltip: 'Change Status',
            onSelected: (newStatus) async {
              Navigator.of(ctx).pop();
              try {
                await SupabaseService.client
                    .from('customer_tasks')
                    .update({'status': newStatus})
                    .eq('id', task.id);
                _fetchTasks();
              } catch (e) {
                debugPrint('Status update error: $e');
              }
            },
            itemBuilder: (_) => TaskStatus.all.map((s) {
              return PopupMenuItem(value: s, child: Text(s));
            }).toList(),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF059669),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Update Status', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                  SizedBox(width: 4),
                  Icon(Icons.arrow_drop_down, color: Colors.white, size: 16),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateFormat = DateFormat('dd MMM yyyy, hh:mm a');
    final tasks = _filteredTasks;

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.share_rounded, color: Color(0xFF25D366)),
            SizedBox(width: 8),
            Text(
              'WhatsApp Document Tasks',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _fetchTasks,
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter & Search Controls
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: _searchController,
                    onChanged: (val) => setState(() => _searchQuery = val),
                    decoration: InputDecoration(
                      hintText: 'Search by Customer, Consumer No, Document...',
                      prefixIcon: const Icon(Icons.search, size: 20),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 16),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _searchQuery = '');
                              },
                            )
                          : null,
                      filled: true,
                      fillColor: Colors.grey.shade100,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Source Filter
                DropdownButton<String>(
                  value: _sourceFilter,
                  items: const [
                    DropdownMenuItem(value: 'ALL', child: Text('All Sources')),
                    DropdownMenuItem(value: 'WhatsApp Share', child: Text('WhatsApp Share Only')),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      setState(() => _sourceFilter = val);
                      _fetchTasks();
                    }
                  },
                ),
                const SizedBox(width: 12),
                // Status Filter
                DropdownButton<String>(
                  value: _statusFilter,
                  items: [
                    const DropdownMenuItem(value: 'ALL', child: Text('All Statuses')),
                    ...TaskStatus.all.map((s) => DropdownMenuItem(value: s, child: Text(s))),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      setState(() => _statusFilter = val);
                      _fetchTasks();
                    }
                  },
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Data Table View
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : tasks.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.inbox_outlined, size: 64, color: Colors.grey.shade300),
                            const SizedBox(height: 12),
                            Text(
                              'No WhatsApp Document Tasks Found',
                              style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                      )
                    : SingleChildScrollView(
                        scrollDirection: Axis.vertical,
                        child: SizedBox(
                          width: double.infinity,
                          child: DataTable(
                            headingRowColor: WidgetStateProperty.all(Colors.grey.shade100),
                            columns: const [
                              DataColumn(label: Text('Task & Document')),
                              DataColumn(label: Text('Customer')),
                              DataColumn(label: Text('Assigned Staff')),
                              DataColumn(label: Text('Status')),
                              DataColumn(label: Text('Created Date')),
                              DataColumn(label: Text('Source')),
                              DataColumn(label: Text('Actions')),
                            ],
                            rows: tasks.map((t) {
                              return DataRow(
                                cells: [
                                  DataCell(
                                    InkWell(
                                      onTap: () => _showTaskDetailDialog(t),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Text(
                                            t.title,
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                          ),
                                          Text(
                                            '${t.documentType} • ${t.documentName}',
                                            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Text(t.customerName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                                        Text('Cons: ${t.consumerNo}', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                                      ],
                                    ),
                                  ),
                                  DataCell(Text(t.assignedStaff ?? '-')),
                                  DataCell(
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: t.statusColor.withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(color: t.statusColor),
                                      ),
                                      child: Text(
                                        t.status,
                                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: t.statusColor),
                                      ),
                                    ),
                                  ),
                                  DataCell(Text(dateFormat.format(t.createdAt), style: const TextStyle(fontSize: 12))),
                                  DataCell(
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF25D366),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.share, size: 10, color: Colors.white),
                                          SizedBox(width: 4),
                                          Text('WhatsApp Share', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                                        ],
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.visibility_outlined, size: 18),
                                          tooltip: 'View Details',
                                          onPressed: () => _showTaskDetailDialog(t),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.picture_as_pdf_outlined, size: 18, color: Colors.red),
                                          tooltip: 'Open PDF',
                                          onPressed: () => _openDocumentUrl(t.documentUrl),
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
          ),
        ],
      ),
    );
  }
}
