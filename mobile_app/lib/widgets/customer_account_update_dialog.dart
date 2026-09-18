import 'package:flutter/material.dart';
import '../models/consumer_record.dart';
import '../models/extracted_document_data.dart';
import '../services/task_service.dart';

class CustomerAccountUpdateDialog extends StatefulWidget {
  final ConsumerRecord customer;
  final ExtractedDocumentData extractedData;

  const CustomerAccountUpdateDialog({
    super.key,
    required this.customer,
    required this.extractedData,
  });

  @override
  State<CustomerAccountUpdateDialog> createState() =>
      _CustomerAccountUpdateDialogState();
}

class _FieldComparison {
  final String fieldKey;
  final String label;
  final String existingValue;
  final String documentValue;
  final dynamic dbValue;
  bool isSelected;

  _FieldComparison({
    required this.fieldKey,
    required this.label,
    required this.existingValue,
    required this.documentValue,
    required this.dbValue,
    this.isSelected = true,
  });

  bool get hasDifference =>
      existingValue.trim().toLowerCase() != documentValue.trim().toLowerCase();
}

class _CustomerAccountUpdateDialogState
    extends State<CustomerAccountUpdateDialog> {
  final List<_FieldComparison> _comparisons = [];
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _buildComparisons();
  }

  void _buildComparisons() {
    final c = widget.customer;
    final d = widget.extractedData;

    // 1. Bill Amount
    if (d.billAmount != null && d.billAmount! > 0) {
      final existingAmt = c.totalAmount;
      _comparisons.add(_FieldComparison(
        fieldKey: 'total_amount',
        label: 'Bill Amount',
        existingValue: '₹${existingAmt.toStringAsFixed(0)}',
        documentValue: '₹${d.billAmount!.toStringAsFixed(0)}',
        dbValue: d.billAmount,
        isSelected: existingAmt != d.billAmount,
      ));
    }

    // 2. Consumer Number
    if (d.consumerNo != null && d.consumerNo!.trim().isNotEmpty) {
      _comparisons.add(_FieldComparison(
        fieldKey: 'consumer_no',
        label: 'Consumer Number',
        existingValue: c.consumerNo,
        documentValue: d.consumerNo!.trim(),
        dbValue: d.consumerNo!.trim(),
        isSelected: c.consumerNo.trim() != d.consumerNo!.trim(),
      ));
    }

    // 3. Customer Name
    if (d.customerName != null && d.customerName!.trim().isNotEmpty) {
      _comparisons.add(_FieldComparison(
        fieldKey: 'name',
        label: 'Customer Name',
        existingValue: c.name,
        documentValue: d.customerName!.trim(),
        dbValue: d.customerName!.trim(),
        isSelected: false, // Default false to avoid accidental overwrite of curated names
      ));
    }

    // 4. Mobile Number
    if (d.mobileNumber != null && d.mobileNumber!.trim().isNotEmpty) {
      _comparisons.add(_FieldComparison(
        fieldKey: 'mobile',
        label: 'Mobile Number',
        existingValue: c.mobile ?? '-',
        documentValue: d.mobileNumber!.trim(),
        dbValue: d.mobileNumber!.trim(),
        isSelected: (c.mobile ?? '').trim() != d.mobileNumber!.trim(),
      ));
    }

    // 5. Application ID
    if (d.applicationId != null && d.applicationId!.trim().isNotEmpty) {
      _comparisons.add(_FieldComparison(
        fieldKey: 'application_id',
        label: 'Application ID',
        existingValue: c.applicationId ?? '-',
        documentValue: d.applicationId!.trim(),
        dbValue: d.applicationId!.trim(),
        isSelected: (c.applicationId ?? '').trim() != d.applicationId!.trim(),
      ));
    }

    // 6. Address / Village
    if (d.village != null && d.village!.trim().isNotEmpty) {
      _comparisons.add(_FieldComparison(
        fieldKey: 'address',
        label: 'Address / Village',
        existingValue: c.address ?? '-',
        documentValue: d.village!.trim(),
        dbValue: d.village!.trim(),
        isSelected: false,
      ));
    }
  }

  Future<void> _handleConfirmUpdate() async {
    final selectedDiffs = _comparisons.where((item) => item.isSelected).toList();
    if (selectedDiffs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one field to update')),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final Map<String, dynamic> updatePayload = {};
      final List<String> changeSummary = [];

      for (final diff in selectedDiffs) {
        updatePayload[diff.fieldKey] = diff.dbValue;
        changeSummary.add('${diff.label}: ${diff.existingValue} → ${diff.documentValue}');
      }

      await TaskService.updateCustomerData(
        customerId: widget.customer.id ?? '',
        consumerNo: widget.customer.consumerNo,
        customerName: widget.customer.name,
        changedFields: updatePayload,
        reason: changeSummary.join(' | '),
      );

      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update customer: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.95,
        constraints: const BoxConstraints(maxHeight: 650),
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Icon(Icons.sync_alt_rounded, color: Color(0xFF059669)),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Update Customer Account',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(false),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Select which fields to update on customer record from the document:',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
            ),
            const SizedBox(height: 12),
            if (_comparisons.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Text(
                    'No new or differing values found in this document.',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              )
            else
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: _comparisons.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 8),
                  itemBuilder: (ctx, idx) {
                    final item = _comparisons[idx];
                    return Container(
                      decoration: BoxDecoration(
                        color: item.isSelected
                            ? const Color(0xFFF0FDF4)
                            : Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: item.isSelected
                              ? const Color(0xFF059669)
                              : Colors.grey.shade300,
                        ),
                      ),
                      child: CheckboxListTile(
                        value: item.isSelected,
                        activeColor: const Color(0xFF059669),
                        onChanged: (val) {
                          setState(() => item.isSelected = val ?? false);
                        },
                        title: Text(
                          item.label,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 4.0),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Existing Value:',
                                        style: TextStyle(
                                            fontSize: 10, color: Colors.grey)),
                                    Text(
                                      item.existingValue,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: item.hasDifference
                                            ? Colors.red.shade700
                                            : Colors.grey.shade800,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(Icons.arrow_forward,
                                  size: 14, color: Colors.grey),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Document Value:',
                                        style: TextStyle(
                                            fontSize: 10, color: Colors.grey)),
                                    Text(
                                      item.documentValue,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF059669),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 10),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF059669),
                    foregroundColor: Colors.white,
                  ),
                  onPressed: _isSaving ? null : _handleConfirmUpdate,
                  icon: _isSaving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.check, size: 18),
                  label: const Text('Update Customer'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
