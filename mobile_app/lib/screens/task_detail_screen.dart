import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:open_filex/open_filex.dart';
import '../models/customer_task.dart';
import '../models/consumer_record.dart';
import '../models/extracted_document_data.dart';
import '../services/task_service.dart';
import '../services/record_service.dart';
import '../widgets/customer_account_update_dialog.dart';

class TaskDetailScreen extends StatefulWidget {
  final CustomerTask task;
  final ConsumerRecord customer;
  final ExtractedDocumentData? extractedData;

  const TaskDetailScreen({
    super.key,
    required this.task,
    required this.customer,
    this.extractedData,
  });

  @override
  State<TaskDetailScreen> createState() => _TaskDetailScreenState();
}

class _TaskDetailScreenState extends State<TaskDetailScreen> {
  late CustomerTask _currentTask;
  late ConsumerRecord _currentCustomer;
  late final ExtractedDocumentData _extractedData;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _currentTask = widget.task;
    _currentCustomer = widget.customer;
    _extractedData = widget.extractedData ??
        (widget.task.extractedData != null
            ? ExtractedDocumentData.fromMap(widget.task.extractedData!)
            : const ExtractedDocumentData());
    _refreshCustomerRecord();
  }

  Future<void> _refreshCustomerRecord() async {
    try {
      final fresh =
          await MobileRecordService.getRecordById(_currentCustomer.id ?? '');
      if (fresh != null && mounted) {
        setState(() => _currentCustomer = fresh);
      }
    } catch (_) {}
  }

  Future<void> _handleOpenFile() async {
    final path = _currentTask.localFilePath;
    if (path == null || path.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Document file path not available')),
      );
      return;
    }

    try {
      final res = await OpenFilex.open(path);
      if (res.type != ResultType.done && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open file: ${res.message}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error opening document: $e')),
        );
      }
    }
  }

  Future<void> _handleUpdateCustomer() async {
    final updated = await showDialog<bool>(
      context: context,
      builder: (_) => CustomerAccountUpdateDialog(
        customer: _currentCustomer,
        extractedData: _extractedData,
      ),
    );

    if (updated == true && mounted) {
      await _refreshCustomerRecord();
      // Advance task workflow to Customer Data Update if currently on New/Review
      if (_currentTask.status == TaskStatus.newTask ||
          _currentTask.status == TaskStatus.documentReview) {
        await _updateWorkflowStatus(TaskStatus.customerDataUpdate);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Customer record successfully updated from document!'),
            backgroundColor: Color(0xFF059669),
          ),
        );
      }
    }
  }

  Future<void> _handleCreatePayment() async {
    final candidate = _extractedData.paymentCandidate;
    final double amount = (candidate?['amount'] as num?)?.toDouble() ??
        _extractedData.billAmount ??
        0.0;
    final String date = candidate?['paymentDate'] as String? ??
        DateFormat('yyyy-MM-dd').format(DateTime.now());
    final String mode = candidate?['paymentMode'] as String? ?? 'UPI';
    final String? ref = candidate?['referenceNumber'] as String?;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.payment_rounded, color: Color(0xFF059669)),
            SizedBox(width: 8),
            Text('Create Payment Transaction'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Confirm payment details detected from WhatsApp document:',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Customer: ${_currentCustomer.name}',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  Text('Consumer No: ${_currentCustomer.consumerNo}'),
                  const Divider(height: 12),
                  Text('Amount: ₹${amount.toStringAsFixed(2)}',
                      style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF059669))),
                  Text('Date: $date'),
                  Text('Mode: $mode'),
                  if (ref != null && ref.isNotEmpty) Text('Ref / UTR: $ref'),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF059669),
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Confirm & Create Payment'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      setState(() => _isLoading = true);
      try {
        await TaskService.createPaymentFromDocument(
          customerId: _currentCustomer.id ?? '',
          consumerNo: _currentCustomer.consumerNo,
          amount: amount,
          paymentDate: date,
          paymentMode: mode,
          referenceNumber: ref,
          attachmentUrl:
              _currentTask.documentUrl ?? _currentTask.localFilePath,
        );
        await _refreshCustomerRecord();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Payment transaction created successfully!'),
              backgroundColor: Color(0xFF059669),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to create payment: $e')),
          );
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _updateWorkflowStatus(String newStatus) async {
    setState(() => _isLoading = true);
    try {
      final updated = await TaskService.updateTaskStatus(
        task: _currentTask,
        newStatus: newStatus,
      );
      if (mounted) {
        setState(() => _currentTask = updated);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Status update error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd MMM yyyy, hh:mm a');

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _currentTask.title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              '${_currentTask.documentType} • ${_currentTask.source}',
              style: const TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          if (_currentTask.isPendingSync)
            Container(
              margin: const EdgeInsets.only(right: 12),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.amber.shade700,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.sync_problem, size: 12, color: Colors.white),
                  SizedBox(width: 4),
                  Text('Pending Sync',
                      style: TextStyle(color: Colors.white, fontSize: 10)),
                ],
              ),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. WORKFLOW STEPPER CARD
                  _buildWorkflowStepper(),
                  const SizedBox(height: 16),

                  // 2. ATTACHED ORIGINAL DOCUMENT CARD
                  _buildAttachedDocumentCard(),
                  const SizedBox(height: 16),

                  // 3. LINKED CUSTOMER ACCOUNT CARD
                  _buildCustomerAccountCard(),
                  const SizedBox(height: 16),

                  // 4. PAYMENT CANDIDATE CARD (IF PAYMENT PROOF)
                  if (_extractedData.isPaymentProof) ...[
                    _buildPaymentProofCard(),
                    const SizedBox(height: 16),
                  ],

                  // 5. EXTRACTED DATA SUMMARY
                  _buildExtractedDataCard(),
                  const SizedBox(height: 16),

                  // 6. TASK METADATA
                  _buildMetadataCard(dateFormat),
                  const SizedBox(height: 30),
                ],
              ),
            ),
    );
  }

  Widget _buildWorkflowStepper() {
    final stages = TaskStatus.standardWorkflow;
    final currentIdx = stages.indexOf(_currentTask.status);

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.alt_route_rounded,
                    color: Color(0xFF059669), size: 18),
                const SizedBox(width: 6),
                const Text(
                  'TASK WORKFLOW LIFECYCLE',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: _currentTask.statusColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _currentTask.status.toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: stages.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final stage = entry.value;
                  final isDone = currentIdx >= 0 && idx < currentIdx;
                  final isCurrent = currentIdx == idx;

                  return Row(
                    children: [
                      InkWell(
                        onTap: () => _updateWorkflowStatus(stage),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: isCurrent
                                ? const Color(0xFF059669)
                                : (isDone
                                    ? const Color(0xFFECFDF5)
                                    : Colors.grey.shade100),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isCurrent
                                  ? const Color(0xFF059669)
                                  : (isDone
                                      ? const Color(0xFF10B981)
                                      : Colors.grey.shade300),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                isDone
                                    ? Icons.check_circle
                                    : (isCurrent
                                        ? Icons.radio_button_checked
                                        : Icons.circle_outlined),
                                size: 14,
                                color: isCurrent
                                    ? Colors.white
                                    : (isDone
                                        ? const Color(0xFF059669)
                                        : Colors.grey),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                stage,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: isCurrent
                                      ? FontWeight.bold
                                      : FontWeight.w500,
                                  color: isCurrent
                                      ? Colors.white
                                      : (isDone
                                          ? const Color(0xFF065F46)
                                          : Colors.grey.shade700),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (idx < stages.length - 1)
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 4),
                          child: Icon(Icons.arrow_forward_ios,
                              size: 10, color: Colors.grey),
                        ),
                    ],
                  );
                }).toList(),
              ),
            ),
            const Divider(height: 20),
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: () => _updateWorkflowStatus(TaskStatus.hold),
                  icon: const Icon(Icons.pause_circle_outline, size: 15),
                  label: const Text('Hold', style: TextStyle(fontSize: 12)),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: () => _updateWorkflowStatus(TaskStatus.followup),
                  icon: const Icon(Icons.phone_callback_rounded, size: 15),
                  label: const Text('Follow-up', style: TextStyle(fontSize: 12)),
                ),
                const Spacer(),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF059669),
                  ),
                  onPressed: _currentTask.isComplete
                      ? null
                      : () => _updateWorkflowStatus(TaskStatus.complete),
                  icon: const Icon(Icons.done_all_rounded, size: 16),
                  label: const Text('Complete Task',
                      style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAttachedDocumentCard() {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'ORIGINAL ATTACHED DOCUMENT',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.picture_as_pdf_rounded,
                    color: Colors.red, size: 36),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _currentTask.documentName,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 13),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Type: ${_currentTask.documentType} • Source: ${_currentTask.source}',
                        style: TextStyle(
                            fontSize: 11, color: Colors.grey.shade700),
                      ),
                    ],
                  ),
                ),
                FilledButton.tonalIcon(
                  onPressed: _handleOpenFile,
                  icon: const Icon(Icons.visibility, size: 16),
                  label: const Text('View PDF', style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomerAccountCard() {
    final c = _currentCustomer;

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.account_box_rounded,
                    color: Color(0xFF059669), size: 20),
                const SizedBox(width: 8),
                const Text(
                  'CUSTOMER ACCOUNT DATA',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
                const Spacer(),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF059669),
                    visualDensity: VisualDensity.compact,
                  ),
                  onPressed: _handleUpdateCustomer,
                  icon: const Icon(Icons.edit, size: 14),
                  label: const Text('Update Customer',
                      style: TextStyle(fontSize: 11)),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              c.name,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Text('Consumer No: ${c.consumerNo}',
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 12)),
                if (c.mobile != null) ...[
                  const SizedBox(width: 8),
                  Text('• Mobile: ${c.mobile}',
                      style: const TextStyle(fontSize: 12)),
                ],
              ],
            ),
            if (c.address != null && c.address!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 2.0),
                child: Text('Address: ${c.address}',
                    style:
                        TextStyle(fontSize: 11, color: Colors.grey.shade700)),
              ),
            const SizedBox(height: 6),
            Row(
              children: [
                Text('Current Bill: ₹${c.totalAmount.toStringAsFixed(0)}',
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF059669))),
                const SizedBox(width: 12),
                Text('Paid: ₹${c.paidAmount.toStringAsFixed(0)}',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentProofCard() {
    final candidate = _extractedData.paymentCandidate;
    final double amt = (candidate?['amount'] as num?)?.toDouble() ??
        _extractedData.billAmount ??
        0.0;
    final String mode = candidate?['paymentMode'] as String? ?? 'UPI';
    final String? ref = candidate?['referenceNumber'] as String?;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFF059669), width: 1.5),
      ),
      color: const Color(0xFFECFDF5),
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.verified_rounded,
                    color: Color(0xFF059669), size: 20),
                const SizedBox(width: 8),
                const Text(
                  'PAYMENT PROOF DETECTED',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF065F46),
                    letterSpacing: 0.5,
                  ),
                ),
                const Spacer(),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF059669),
                  ),
                  onPressed: _handleCreatePayment,
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Create Payment',
                      style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Amount: ₹${amt.toStringAsFixed(2)} • Mode: $mode',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: Color(0xFF065F46),
              ),
            ),
            if (ref != null && ref.isNotEmpty)
              Text('UTR / Reference: $ref',
                  style: const TextStyle(fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Widget _buildExtractedDataCard() {
    final d = _extractedData;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'SMART EXTRACTED DATA',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 8),
            if (d.consumerNo != null) Text('Consumer No: ${d.consumerNo}'),
            if (d.customerName != null) Text('Name: ${d.customerName}'),
            if (d.mobileNumber != null) Text('Mobile: ${d.mobileNumber}'),
            if (d.billAmount != null) Text('Bill Amount: ₹${d.billAmount}'),
            if (d.billDate != null) Text('Bill Date: ${d.billDate}'),
            if (d.dueDate != null) Text('Due Date: ${d.dueDate}'),
          ],
        ),
      ),
    );
  }

  Widget _buildMetadataCard(DateFormat dateFormat) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      color: Colors.grey.shade50,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Task ID: ${_currentTask.id}',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade700)),
            Text('Created: ${dateFormat.format(_currentTask.createdAt)}',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade700)),
            Text('Assigned Staff: ${_currentTask.assignedStaff ?? "Unassigned"}',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade700)),
            if (_currentTask.remarks != null &&
                _currentTask.remarks!.isNotEmpty)
              Text('Remarks: ${_currentTask.remarks}',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade700)),
          ],
        ),
      ),
    );
  }
}
