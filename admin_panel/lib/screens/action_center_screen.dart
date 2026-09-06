import 'dart:async';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import '../models/consumer_record.dart';
import '../models/customer_misc_action.dart';
import '../models/customer_issue.dart';
import '../services/record_service.dart';
import '../services/realtime_service.dart';
import '../services/workflow_engine.dart';
import '../widgets/record_details_dialog.dart';
import '../widgets/record_form_dialog.dart';
import '../widgets/no_action_reason_dialog.dart';
import '../widgets/hold_reason_dialog.dart';
import '../widgets/followup_dialog.dart';
import '../widgets/followup_done_dialog.dart';
import '../widgets/misc_action_dialog.dart';
import '../widgets/issue_dialog.dart';
import '../widgets/payment_dialog.dart';
import 'package:url_launcher/url_launcher.dart';

class ActionCenterScreen extends StatefulWidget {
  final String? initialStageFilter;

  const ActionCenterScreen({super.key, this.initialStageFilter});

  @override
  State<ActionCenterScreen> createState() => _ActionCenterScreenState();
}

class _ActionCenterScreenState extends State<ActionCenterScreen> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _verticalScrollController = ScrollController();
  final ScrollController _horizontalScrollController = ScrollController();
  Timer? _debounceTimer;

  bool _isLoading = false;
  List<ConsumerRecord> _records = [];
  List<CustomerMiscAction> _miscActions = [];
  List<CustomerIssue> _issues = [];
  int _totalCount = 0;
  int _currentPage = 1;
  final int _pageSize = 15;

  Map<String, int> _queueCounts = {};
  String _selectedStageFilter = 'ALL';
  String _selectedStaffFilter = 'All';

  StreamSubscription<ConsumerRecordChangeEvent>? _realtimeSub;

  @override
  void initState() {
    super.initState();
    if (widget.initialStageFilter != null && widget.initialStageFilter!.isNotEmpty) {
      _selectedStageFilter = widget.initialStageFilter!;
    }
    _loadActionCenterRecords();
    _initRealtimeSync();
  }

  void _initRealtimeSync() {
    RealtimeSyncService.initialize();
    _realtimeSub = RealtimeSyncService.recordEvents.listen((_) {
      if (mounted) {
        _loadActionCenterRecords();
      }
    });
  }

  @override
  void dispose() {
    _realtimeSub?.cancel();
    _searchController.dispose();
    _verticalScrollController.dispose();
    _horizontalScrollController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 350), () {
      if (mounted) {
        setState(() => _currentPage = 1);
        _loadActionCenterRecords();
      }
    });
  }

  Future<void> _loadActionCenterRecords() async {
    setState(() => _isLoading = true);

    try {
      final countsFuture = RecordService.fetchActionCenterQueueCounts();

      if (_selectedStageFilter == 'MISC') {
        final miscFuture = RecordService.fetchMiscActions(
          page: _currentPage,
          pageSize: _pageSize,
          statusFilter: 'Active',
          assignedStaffFilter: _selectedStaffFilter,
          searchQuery: _searchController.text,
        );

        final results = await Future.wait([countsFuture, miscFuture]);
        final queueCounts = results[0] as Map<String, int>;
        final miscResult = results[1] as PaginatedResult<CustomerMiscAction>;

        if (mounted) {
          setState(() {
            _queueCounts = queueCounts;
            _miscActions = miscResult.items;
            _totalCount = miscResult.totalCount;
            _isLoading = false;
          });
        }
      } else if (_selectedStageFilter == 'General Issue') {
        final issueFuture = RecordService.fetchIssues(
          page: _currentPage,
          pageSize: _pageSize,
          statusFilter: 'Active',
          assignedStaffFilter: _selectedStaffFilter,
          searchQuery: _searchController.text,
        );

        final results = await Future.wait([countsFuture, issueFuture]);
        final queueCounts = results[0] as Map<String, int>;
        final issueResult = results[1] as PaginatedResult<CustomerIssue>;

        if (mounted) {
          setState(() {
            _queueCounts = queueCounts;
            _issues = issueResult.items;
            _totalCount = issueResult.totalCount;
            _isLoading = false;
          });
        }
      } else if (_selectedStageFilter == 'Payment Pending') {
        final paymentFuture = RecordService.fetchPaymentPendingRecords(
          page: _currentPage,
          pageSize: _pageSize,
          assignedStaffFilter: _selectedStaffFilter,
          searchQuery: _searchController.text,
        );

        final results = await Future.wait([countsFuture, paymentFuture]);
        final queueCounts = results[0] as Map<String, int>;
        final paymentResult = results[1] as PaginatedResult<ConsumerRecord>;

        if (mounted) {
          setState(() {
            _queueCounts = queueCounts;
            _records = paymentResult.items;
            _totalCount = paymentResult.totalCount;
            _isLoading = false;
          });
        }
      } else {
        final recordsFuture = RecordService.fetchActionCenterRecords(
          page: _currentPage,
          pageSize: _pageSize,
          stageFilter: _selectedStageFilter,
          assignedStaffFilter: _selectedStaffFilter,
          searchQuery: _searchController.text,
        );

        final results = await Future.wait([countsFuture, recordsFuture]);
        final queueCounts = results[0] as Map<String, int>;
        final recordResult = results[1] as PaginatedResult<ConsumerRecord>;

        if (mounted) {
          setState(() {
            _queueCounts = queueCounts;
            _records = recordResult.items;
            _totalCount = recordResult.totalCount;
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load Action Center: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _openAddMiscDialog([ConsumerRecord? customer]) async {
    final saved = await MiscActionDialog.show(
      context,
      customerRecord: customer,
    );
    if (saved == true) {
      _loadActionCenterRecords();
    }
  }

  Future<void> _openEditMiscDialog(CustomerMiscAction action) async {
    final saved = await MiscActionDialog.show(
      context,
      existingAction: action,
    );
    if (saved == true) {
      _loadActionCenterRecords();
    }
  }

  Future<void> _confirmCompleteMiscAction(CustomerMiscAction action) async {
    final remarksCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.check_circle_outline, color: Color(0xFF059669)),
            SizedBox(width: 8),
            Text('Complete MISC Action'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Mark action "${action.reason}" for ${action.customerName} as Complete?'),
            const SizedBox(height: 12),
            TextField(
              controller: remarksCtrl,
              decoration: const InputDecoration(
                labelText: 'Completion Remarks (Optional)',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFF059669)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Complete Action'),
          ),
        ],
      ),
    );

    if (confirmed == true && action.id != null && mounted) {
      try {
        await RecordService.completeMiscAction(
          id: action.id!,
          remarks: remarksCtrl.text.trim().isEmpty ? null : remarksCtrl.text.trim(),
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('MISC action "${action.reason}" completed.'), backgroundColor: const Color(0xFF059669)),
          );
          _loadActionCenterRecords();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to complete action: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  Future<void> _confirmHoldMiscAction(CustomerMiscAction action) async {
    final reasonCtrl = TextEditingController();
    final remarksCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.pause_circle_outline, color: Color(0xFFD97706)),
            SizedBox(width: 8),
            Text('Hold MISC Action'),
          ],
        ),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Put action "${action.reason}" for ${action.customerName} on Hold:'),
              const SizedBox(height: 12),
              TextFormField(
                controller: reasonCtrl,
                decoration: const InputDecoration(
                  labelText: 'Hold Reason *',
                  hintText: 'e.g. Waiting for customer response',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Hold Reason is required' : null,
              ),
              const SizedBox(height: 10),
              TextField(
                controller: remarksCtrl,
                decoration: const InputDecoration(
                  labelText: 'Remarks (Optional)',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                maxLines: 2,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFD97706)),
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(ctx, true);
              }
            },
            child: const Text('Put on Hold'),
          ),
        ],
      ),
    );

    if (confirmed == true && action.id != null && mounted) {
      try {
        await RecordService.holdMiscAction(
          id: action.id!,
          holdReason: reasonCtrl.text.trim(),
          remarks: remarksCtrl.text.trim().isEmpty ? null : remarksCtrl.text.trim(),
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('MISC action "${action.reason}" placed on hold.'), backgroundColor: const Color(0xFFD97706)),
          );
          _loadActionCenterRecords();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to hold action: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  Future<void> _confirmFollowupMiscAction(CustomerMiscAction action) async {
    final result = await FollowupDialog.show(
      context,
      customerName: action.customerName,
      initialReason: 'MISC: ${action.reason}',
    );
    if (result != null && mounted) {
      try {
        await RecordService.markCustomerFollowup(
          recordId: action.recordId,
          followupDate: result.followupDate,
          followupReason: result.followupReason,
          remarks: result.remarks,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Follow-up scheduled for ${action.customerName} on ${result.followupDate.toLocal().toString().split(' ')[0]}.'),
              backgroundColor: const Color(0xFF2563EB),
            ),
          );
          _loadActionCenterRecords();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to schedule follow-up: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  // ================= GENERAL ISSUE HELPERS =================

  Future<void> _openReportIssueDialog([ConsumerRecord? customer]) async {
    final saved = await IssueDialog.show(context, customerRecord: customer);
    if (saved == true) {
      _loadActionCenterRecords();
    }
  }

  Future<void> _openEditIssueDialog(CustomerIssue issue) async {
    final saved = await IssueDialog.show(context, existingIssue: issue);
    if (saved == true) {
      _loadActionCenterRecords();
    }
  }

  Future<void> _confirmAssignIssue(CustomerIssue issue) async {
    final staffCtrl = TextEditingController(text: issue.assignedStaff ?? '');
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.person_add_rounded, color: Color(0xFF2563EB)),
            SizedBox(width: 8),
            Text('Assign Staff to Issue'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Issue: ${issue.title} (${issue.issueType})'),
            const SizedBox(height: 12),
            TextField(
              controller: staffCtrl,
              decoration: const InputDecoration(
                labelText: 'Assign Staff Name *',
                hintText: 'e.g. Rahul Sharma / Technical Team',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFF2563EB)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Assign'),
          ),
        ],
      ),
    );

    if (confirmed == true && staffCtrl.text.trim().isNotEmpty && issue.id != null && mounted) {
      try {
        await RecordService.assignIssue(
          issueId: issue.id!,
          assignedStaff: staffCtrl.text.trim(),
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Issue assigned to ${staffCtrl.text.trim()}.'), backgroundColor: const Color(0xFF2563EB)),
          );
          _loadActionCenterRecords();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to assign issue: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  Future<void> _confirmHoldIssue(CustomerIssue issue) async {
    final remarksCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.pause_circle_outline, color: Color(0xFFD97706)),
            SizedBox(width: 8),
            Text('Put Issue On Hold'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Put issue "${issue.title}" on Hold?'),
            const SizedBox(height: 12),
            TextField(
              controller: remarksCtrl,
              decoration: const InputDecoration(
                labelText: 'Hold Reason / Remarks *',
                hintText: 'e.g. Waiting for spare part delivery from vendor',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFD97706)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Put On Hold'),
          ),
        ],
      ),
    );

    if (confirmed == true && issue.id != null && mounted) {
      try {
        await RecordService.holdIssue(
          issueId: issue.id!,
          remarks: remarksCtrl.text.trim().isEmpty ? null : remarksCtrl.text.trim(),
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Issue placed on Hold.'), backgroundColor: Color(0xFFD97706)),
          );
          _loadActionCenterRecords();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to hold issue: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  Future<void> _confirmResolveIssue(CustomerIssue issue) async {
    final remarksCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.check_circle_outline, color: Color(0xFF059669)),
            SizedBox(width: 8),
            Text('Resolve Issue'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Mark issue "${issue.title}" as Resolved?'),
            const SizedBox(height: 12),
            TextField(
              controller: remarksCtrl,
              decoration: const InputDecoration(
                labelText: 'Resolution Remarks',
                hintText: 'e.g. Inverter firmware updated, working normally',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFF059669)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Mark Resolved'),
          ),
        ],
      ),
    );

    if (confirmed == true && issue.id != null && mounted) {
      try {
        await RecordService.resolveIssue(
          issueId: issue.id!,
          remarks: remarksCtrl.text.trim().isEmpty ? null : remarksCtrl.text.trim(),
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Issue marked as Resolved.'), backgroundColor: Color(0xFF059669)),
          );
          _loadActionCenterRecords();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to resolve issue: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  Future<void> _confirmCloseIssue(CustomerIssue issue) async {
    final remarksCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.task_alt_rounded, color: Colors.grey),
            SizedBox(width: 8),
            Text('Close Issue'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Close issue "${issue.title}" permanently?'),
            const SizedBox(height: 12),
            TextField(
              controller: remarksCtrl,
              decoration: const InputDecoration(
                labelText: 'Closing Remarks',
                hintText: 'e.g. Customer satisfied with fix',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.grey.shade800),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Close Issue'),
          ),
        ],
      ),
    );

    if (confirmed == true && issue.id != null && mounted) {
      try {
        await RecordService.closeIssue(
          issueId: issue.id!,
          remarks: remarksCtrl.text.trim().isEmpty ? null : remarksCtrl.text.trim(),
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Issue closed.'), backgroundColor: Colors.grey),
          );
          _loadActionCenterRecords();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to close issue: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  Future<void> _confirmReopenIssue(CustomerIssue issue) async {
    final remarksCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.replay_rounded, color: Color(0xFF2563EB)),
            SizedBox(width: 8),
            Text('Reopen Issue'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Reopen issue "${issue.title}" for customer ${issue.customerName}?'),
            const SizedBox(height: 12),
            TextField(
              controller: remarksCtrl,
              decoration: const InputDecoration(
                labelText: 'Reason for Reopening *',
                hintText: 'e.g. Problem reoccurred after 2 days',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFF2563EB)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Reopen Issue'),
          ),
        ],
      ),
    );

    if (confirmed == true && issue.id != null && mounted) {
      try {
        await RecordService.reopenIssue(
          issueId: issue.id!,
          remarks: remarksCtrl.text.trim().isEmpty ? null : remarksCtrl.text.trim(),
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Issue reopened successfully.'), backgroundColor: Color(0xFF2563EB)),
          );
          _loadActionCenterRecords();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to reopen issue: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  Future<void> _confirmFollowupIssue(CustomerIssue issue) async {
    final result = await FollowupDialog.show(
      context,
      customerName: issue.customerName,
      initialReason: 'Issue: ${issue.issueType} - ${issue.title}',
    );
    if (result != null && mounted) {
      try {
        await RecordService.markCustomerFollowup(
          recordId: issue.customerId,
          followupDate: result.followupDate,
          followupReason: result.followupReason,
          remarks: result.remarks,
          relatedType: 'Issue',
          relatedId: issue.id,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Follow-up scheduled for ${issue.customerName} on ${result.followupDate.toLocal().toString().split(' ')[0]}.'),
              backgroundColor: const Color(0xFF2563EB),
            ),
          );
          _loadActionCenterRecords();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to schedule follow-up: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  // ================= PAYMENT HELPERS =================

  Future<void> _openAddPaymentDialog(ConsumerRecord customer) async {
    final saved = await PaymentDialog.show(context, customerRecord: customer);
    if (saved == true) {
      _loadActionCenterRecords();
    }
  }

  Future<void> _confirmFollowupPayment(ConsumerRecord record) async {
    if (record.id == null) return;
    final result = await FollowupDialog.show(
      context,
      customerName: record.name,
      initialReason: 'Payment Pending: ₹${record.pendingAmount.toStringAsFixed(0)}',
    );
    if (result != null && mounted) {
      try {
        await RecordService.markCustomerFollowup(
          recordId: record.id!,
          followupDate: result.followupDate,
          followupReason: result.followupReason,
          remarks: result.remarks,
          relatedType: 'Payment',
          relatedId: record.id,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Payment follow-up scheduled for ${record.name} on ${result.followupDate.toLocal().toString().split(' ')[0]}.'),
              backgroundColor: const Color(0xFF2563EB),
            ),
          );
          _loadActionCenterRecords();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to schedule follow-up: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }


  void _openDetailsDialog(ConsumerRecord record) {
    showDialog(
      context: context,
      builder: (_) => RecordDetailsDialog(
        record: record,
        onRecordUpdated: _loadActionCenterRecords,
      ),
    );
  }

  void _openEditDialog(ConsumerRecord record) {
    showDialog(
      context: context,
      builder: (_) => RecordFormDialog(
        initialRecord: record,
        onRecordSaved: (_) => _loadActionCenterRecords(),
      ),
    );
  }

  Future<void> _confirmMarkAsComplete(ConsumerRecord record) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.check_circle_outline, color: Colors.green),
            SizedBox(width: 8),
            Text('Mark as Complete'),
          ],
        ),
        content: Text('Mark customer ${record.name} as complete? They will be moved immediately to Completed.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFF059669)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Mark as Complete'),
          ),
        ],
      ),
    );

    if (confirmed == true && record.id != null && mounted) {
      try {
        await RecordService.markCustomerAsComplete(record.id!);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Customer ${record.name} marked as complete and moved to Completed.'),
              backgroundColor: Colors.green,
            ),
          );
          _loadActionCenterRecords();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to mark complete: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  Future<void> _confirmMarkAsHold(ConsumerRecord record) async {
    final result = await HoldReasonDialog.show(context, customerName: record.name);
    if (result != null && record.id != null && mounted) {
      try {
        await RecordService.markCustomerAsHold(
          recordId: record.id!,
          reason: result.reason,
          remarks: result.remarks,
          expectedFollowupDate: result.expectedFollowupDate,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Customer ${record.name} marked as On Hold (${result.reason}).'),
              backgroundColor: const Color(0xFFD97706),
            ),
          );
          _loadActionCenterRecords();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to update hold state: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  Future<void> _openFollowupDialog(ConsumerRecord record) async {
    if (record.id == null) return;

    // Check whether the customer already has an active Pending Follow-up
    final existing = await RecordService.getActiveFollowupForRecord(record.id!);
    if (existing != null && mounted) {
      final existingDateStr = existing['followup_date']?.toString() ?? 'N/A';
      final existingReason = existing['followup_reason']?.toString() ?? 'Follow-up';
      final existingRemarks = existing['remarks']?.toString();

      final chosenAction = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: const Row(
            children: [
              Icon(Icons.info_outline, color: Color(0xFF2563EB)),
              SizedBox(width: 8),
              Text('Active Follow-up Exists'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'An active pending follow-up is already scheduled for ${record.name}:',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFBFDBFE)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('📅 Date: $existingDateStr', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E40AF))),
                    const SizedBox(height: 4),
                    Text('📌 Reason: $existingReason', style: const TextStyle(fontWeight: FontWeight.w500)),
                    if (existingRemarks != null && existingRemarks.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text('💬 Remarks: $existingRemarks', style: TextStyle(color: Colors.grey.shade700, fontSize: 13)),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'What would you like to do?',
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, 'CANCEL'),
              child: const Text('Cancel'),
            ),
            OutlinedButton(
              onPressed: () => Navigator.pop(ctx, 'UPDATE_EXISTING'),
              child: const Text('Update Existing'),
            ),
            OutlinedButton(
              onPressed: () => Navigator.pop(ctx, 'CREATE_ANOTHER'),
              child: const Text('Create Another'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, 'OPEN_EXISTING'),
              child: const Text('Open Existing (Default)'),
            ),
          ],
        ),
      );

      if (chosenAction == null || chosenAction == 'CANCEL' || !mounted) return;

      if (chosenAction == 'OPEN_EXISTING') {
        _openDetailsDialog(record);
        return;
      }

      if (chosenAction == 'UPDATE_EXISTING') {
        DateTime? initialDate;
        try {
          if (existing['followup_date'] != null) {
            initialDate = DateTime.parse(existing['followup_date'].toString());
          }
        } catch (_) {}

        final result = await FollowupDialog.show(
          context,
          customerName: record.name,
          initialDate: initialDate ?? record.followupDate,
          initialReason: existingReason,
        );

        if (result != null && mounted) {
          try {
            await RecordService.updateCustomerFollowup(
              followupId: existing['id'].toString(),
              recordId: record.id!,
              followupDate: result.followupDate,
              followupReason: result.followupReason,
              remarks: result.remarks,
            );
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Follow-up updated for ${record.name}.'),
                  backgroundColor: const Color(0xFF059669),
                ),
              );
              _loadActionCenterRecords();
            }
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Failed to update follow-up: $e'), backgroundColor: Colors.red),
              );
            }
          }
        }
        return;
      }
      // If CREATE_ANOTHER, proceed below
    }

    final result = await FollowupDialog.show(
      context,
      customerName: record.name,
      initialDate: record.followupDate,
      initialReason: record.followupReason,
    );
    if (result != null && record.id != null && mounted) {
      try {
        await RecordService.markCustomerFollowup(
          recordId: record.id!,
          followupDate: result.followupDate,
          followupReason: result.followupReason,
          remarks: result.remarks,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Follow-up scheduled for ${record.name} on ${result.followupDate.toLocal().toString().split(' ')[0]}.'),
              backgroundColor: const Color(0xFF2563EB),
            ),
          );
          _loadActionCenterRecords();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to schedule follow-up: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  Future<void> _openFollowupDoneDialog(ConsumerRecord record) async {
    final result = await FollowupDoneDialog.show(
      context,
      customerName: record.name,
    );
    if (result != null && record.id != null && mounted) {
      try {
        await RecordService.completeCustomerFollowup(
          recordId: record.id!,
          followupResult: result.followupResult,
          remarks: result.remarks,
          nextFollowupDate: result.nextFollowupDate,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Follow-up outcome recorded for ${record.name}.'),
              backgroundColor: const Color(0xFF059669),
            ),
          );
          _loadActionCenterRecords();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to record follow-up: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  Future<void> _makePhoneCall(String? mobile) async {
    if (mobile == null || mobile.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No phone number available for this customer.'), backgroundColor: Colors.orange),
      );
      return;
    }
    final uri = Uri.parse('tel:${mobile.trim()}');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not launch dialer for $mobile'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _confirmReopen(ConsumerRecord record) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.replay_rounded, color: Colors.blue),
            SizedBox(width: 8),
            Text('Reopen Customer'),
          ],
        ),
        content: Text('Reopen customer ${record.name}? Workflow Engine will recalculate current stage and return customer to Action Center.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFF2563EB)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Reopen Customer'),
          ),
        ],
      ),
    );

    if (confirmed == true && record.id != null && mounted) {
      try {
        await RecordService.reopenCustomer(record.id!);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Customer ${record.name} reopened successfully.'),
              backgroundColor: Colors.blue,
            ),
          );
          _loadActionCenterRecords();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to reopen customer: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final totalPages = (_totalCount / _pageSize).ceil();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Title
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.bolt_rounded, color: theme.colorScheme.primary, size: 30),
                      const SizedBox(width: 8),
                      Text(
                        'ACTION CENTER',
                        style: theme.textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Intelligent operational queue — WHO NEEDS ACTION NOW?',
                    style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 13),
                  ),
                ],
              ),
              IconButton.outlined(
                icon: const Icon(Icons.refresh),
                tooltip: 'Refresh Action Center',
                onPressed: _loadActionCenterRecords,
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Stage Summary Filter Cards
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _buildStageFilterCard(
                title: 'Agreement Pending',
                stageCode: 'Agreement Pending',
                color: const Color(0xFF2563EB),
                icon: Icons.history_edu_rounded,
              ),
              _buildStageFilterCard(
                title: 'Loan Pending',
                stageCode: 'Loan Pending',
                color: const Color(0xFFD97706),
                icon: Icons.account_balance_rounded,
              ),
              _buildStageFilterCard(
                title: 'Installation Pending',
                stageCode: 'Installation Pending',
                color: const Color(0xFF0F766E),
                icon: Icons.build_circle_outlined,
              ),
              _buildStageFilterCard(
                title: 'RTS Pending',
                stageCode: 'RTS Pending',
                color: const Color(0xFF7C3AED),
                icon: Icons.electric_meter_rounded,
              ),
              _buildStageFilterCard(
                title: 'Subsidy Processing',
                stageCode: 'Subsidy Processing',
                color: const Color(0xFF059669),
                icon: Icons.currency_rupee_rounded,
              ),
              _buildStageFilterCard(
                title: "Today's Follow-up",
                stageCode: "Today's Follow-up",
                color: const Color(0xFF0284C7),
                icon: Icons.phone_in_talk_rounded,
              ),
              _buildStageFilterCard(
                title: "Overdue Follow-up",
                stageCode: "Overdue Follow-up",
                color: const Color(0xFFDC2626),
                icon: Icons.phone_missed_rounded,
              ),
              _buildStageFilterCard(
                title: "Upcoming Follow-up",
                stageCode: "Upcoming Follow-up",
                color: const Color(0xFF4F46E5),
                icon: Icons.phone_callback_rounded,
              ),
              _buildStageFilterCard(
                title: 'On Hold',
                stageCode: 'Hold',
                color: const Color(0xFFD97706),
                icon: Icons.pause_circle_filled_rounded,
              ),
              _buildStageFilterCard(
                title: 'Completed',
                stageCode: 'Completed',
                color: Colors.grey.shade700,
                icon: Icons.check_circle_rounded,
              ),
              _buildStageFilterCard(
                title: 'MISC',
                stageCode: 'MISC',
                color: const Color(0xFF6366F1),
                icon: Icons.assignment_turned_in_rounded,
              ),
              _buildStageFilterCard(
                title: 'General Issue',
                stageCode: 'General Issue',
                color: const Color(0xFFDC2626),
                icon: Icons.report_problem_rounded,
              ),
              _buildStageFilterCard(
                title: 'Payment Pending',
                stageCode: 'Payment Pending',
                color: const Color(0xFFD97706),
                icon: Icons.payments_rounded,
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Search & Filter Bar
          Card(
            elevation: 1,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: TextField(
                      controller: _searchController,
                      onChanged: _onSearchChanged,
                      decoration: InputDecoration(
                        hintText: 'Search Action Center by Customer Name, Consumer No, App ID, Mobile...',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () {
                                  _searchController.clear();
                                  _loadActionCenterRecords();
                                },
                              )
                            : null,
                        border: const OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Stage Dropdown Filter
                  DropdownButtonHideUnderline(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade400),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: DropdownButton<String>(
                        value: _selectedStageFilter,
                        items: const [
                          DropdownMenuItem(value: 'ALL', child: Text('Work Stage: All Active Stages')),
                          DropdownMenuItem(value: 'Agreement Pending', child: Text('Agreement Pending')),
                          DropdownMenuItem(value: 'Loan Pending', child: Text('Loan Pending')),
                          DropdownMenuItem(value: 'Installation Pending', child: Text('Installation Pending')),
                          DropdownMenuItem(value: 'RTS Pending', child: Text('RTS Pending')),
                          DropdownMenuItem(value: 'Subsidy Processing', child: Text('Subsidy Processing')),
                          DropdownMenuItem(value: "Today's Follow-up", child: Text("📞 Today's Follow-up")),
                          DropdownMenuItem(value: "Overdue Follow-up", child: Text("⚠️ Overdue Follow-up")),
                          DropdownMenuItem(value: "Upcoming Follow-up", child: Text("📅 Upcoming Follow-up")),
                          DropdownMenuItem(value: 'Hold', child: Text('⏸ On Hold')),
                          DropdownMenuItem(value: 'Completed', child: Text('✓ Completed')),
                          DropdownMenuItem(value: 'MISC', child: Text('⚡ MISC Actions')),
                          DropdownMenuItem(value: 'General Issue', child: Text('⚠️ General Issue')),
                          DropdownMenuItem(value: 'Payment Pending', child: Text('💰 Payment Pending')),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            setState(() {
                              _selectedStageFilter = val;
                              _currentPage = 1;
                            });
                            _loadActionCenterRecords();
                          }
                        },
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Assigned Staff Filter
                  DropdownButtonHideUnderline(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade400),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: DropdownButton<String>(
                        value: _selectedStaffFilter,
                        items: const [
                          DropdownMenuItem(value: 'All', child: Text('Staff: All Staff')),
                          DropdownMenuItem(value: 'Rushikesh', child: Text('Rushikesh')),
                          DropdownMenuItem(value: 'Rihan', child: Text('Rihan')),
                          DropdownMenuItem(value: 'Vishal', child: Text('Vishal')),
                          DropdownMenuItem(value: 'Samadhan', child: Text('Samadhan')),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            setState(() {
                              _selectedStaffFilter = val;
                              _currentPage = 1;
                            });
                            _loadActionCenterRecords();
                          }
                        },
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF4F46E5),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                    icon: const Icon(Icons.add_task_rounded, size: 18),
                    label: const Text('+ Add MISC'),
                    onPressed: () => _openAddMiscDialog(),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFDC2626),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                    icon: const Icon(Icons.report_problem_rounded, size: 18),
                    label: const Text('+ Report Issue'),
                    onPressed: () => _openReportIssueDialog(),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Action Center Customer Table Card
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Column(
              children: [
                _isLoading
                    ? const Padding(
                        padding: EdgeInsets.all(40.0),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    : _selectedStageFilter == 'MISC'
                        ? _miscActions.isEmpty
                            ? Padding(
                                padding: const EdgeInsets.all(40.0),
                                child: Center(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.assignment_turned_in_outlined, size: 48, color: Colors.grey),
                                      const SizedBox(height: 12),
                                      Text(
                                        'No active miscellaneous customer actions found.',
                                        style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                                      ),
                                      const SizedBox(height: 12),
                                      FilledButton.icon(
                                        onPressed: () => _openAddMiscDialog(),
                                        icon: const Icon(Icons.add, size: 16),
                                        label: const Text('Create First MISC Action'),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                            : _buildMiscDataTable(theme)
                        : _selectedStageFilter == 'General Issue'
                            ? _issues.isEmpty
                                ? Padding(
                                    padding: const EdgeInsets.all(40.0),
                                    child: Center(
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.report_problem_outlined, size: 48, color: Colors.redAccent),
                                          const SizedBox(height: 12),
                                          Text(
                                            'No active general customer issues requiring staff action.',
                                            style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                                          ),
                                          const SizedBox(height: 12),
                                          FilledButton.icon(
                                            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFDC2626)),
                                            onPressed: () => _openReportIssueDialog(),
                                            icon: const Icon(Icons.add, size: 16),
                                            label: const Text('Report New Issue'),
                                          ),
                                        ],
                                      ),
                                    ),
                                  )
                                : _buildIssueDataTable(theme)
                        : _selectedStageFilter == 'Payment Pending'
                            ? _records.isEmpty
                                ? Padding(
                                    padding: const EdgeInsets.all(40.0),
                                    child: Center(
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.payments_outlined, size: 48, color: Colors.amber),
                                          const SizedBox(height: 12),
                                          Text(
                                            'No customers with pending payments found.',
                                            style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                                          ),
                                        ],
                                      ),
                                    ),
                                  )
                                : _buildPaymentDataTable(theme)
                        : _records.isEmpty
                            ? Padding(
                                padding: const EdgeInsets.all(40.0),
                                child: Center(
                                  child: Text(
                                    'No customers requiring action for selected stage/filter.',
                                    style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                                  ),
                                ),
                              )
                            : ScrollConfiguration(
                            behavior: ScrollConfiguration.of(context).copyWith(
                              dragDevices: {
                                PointerDeviceKind.touch,
                                PointerDeviceKind.mouse,
                                PointerDeviceKind.trackpad,
                                PointerDeviceKind.stylus,
                              },
                            ),
                            child: Scrollbar(
                              controller: _verticalScrollController,
                              thumbVisibility: true,
                              trackVisibility: true,
                              child: SingleChildScrollView(
                                controller: _verticalScrollController,
                                scrollDirection: Axis.vertical,
                                child: Scrollbar(
                                  controller: _horizontalScrollController,
                                  thumbVisibility: true,
                                  trackVisibility: true,
                                  child: SingleChildScrollView(
                                    controller: _horizontalScrollController,
                                    scrollDirection: Axis.horizontal,
                                    child: DataTable(
                                      columnSpacing: 16,
                                      horizontalMargin: 12,
                                      headingRowColor: WidgetStateProperty.all(
                                        theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                                      ),
                                      columns: const [
                                        DataColumn(label: Text('Customer Name', style: TextStyle(fontWeight: FontWeight.bold))),
                                        DataColumn(label: Text('Consumer No', style: TextStyle(fontWeight: FontWeight.bold))),
                                        DataColumn(label: Text('Current Work Stage', style: TextStyle(fontWeight: FontWeight.bold))),
                                        DataColumn(label: Text('Current Sub-Stage', style: TextStyle(fontWeight: FontWeight.bold))),
                                        DataColumn(label: Text('Current Status', style: TextStyle(fontWeight: FontWeight.bold))),
                                        DataColumn(label: Text('Follow-up', style: TextStyle(fontWeight: FontWeight.bold))),
                                        DataColumn(label: Text('Next Action', style: TextStyle(fontWeight: FontWeight.bold))),
                                        DataColumn(label: Text('Days in Stage', style: TextStyle(fontWeight: FontWeight.bold))),
                                        DataColumn(label: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold))),
                                      ],
                                      rows: _records.map((r) {
                                        final isCompleted = r.isCompletedState;
                                        final isHold = r.isHold;

                                        return DataRow(
                                          cells: [
                                            // Customer Name
                                            DataCell(
                                              InkWell(
                                                onTap: () => _openDetailsDialog(r),
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  mainAxisAlignment: MainAxisAlignment.center,
                                                  children: [
                                                    Text(
                                                      r.name,
                                                      style: const TextStyle(fontWeight: FontWeight.w600),
                                                    ),
                                                    if (r.mobile != null && r.mobile!.isNotEmpty)
                                                      Text(
                                                        r.mobile!,
                                                        style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                                                      ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                            // Consumer No
                                            DataCell(
                                              InkWell(
                                                onTap: () => _openDetailsDialog(r),
                                                child: Text(
                                                  r.consumerNo,
                                                  style: const TextStyle(
                                                    color: Color(0xFF2563EB),
                                                    decoration: TextDecoration.underline,
                                                  ),
                                                ),
                                              ),
                                            ),
                                            // Current Work Stage
                                            DataCell(_buildStageBadge(r.overallStage, isHold: isHold, holdReason: r.holdReason ?? r.noActionReason)),
                                            // Current Sub-Stage
                                            DataCell(
                                              Text(
                                                r.currentSubStage,
                                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                                              ),
                                            ),
                                            // Current Status
                                            DataCell(
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: Colors.grey.shade100,
                                                  borderRadius: BorderRadius.circular(4),
                                                  border: Border.all(color: Colors.grey.shade300),
                                                ),
                                                child: Text(
                                                  isHold ? 'On Hold' : (isCompleted ? 'Completed' : r.currentStatus),
                                                  style: const TextStyle(fontSize: 12),
                                                ),
                                              ),
                                            ),
                                            // Follow-up
                                            DataCell(_buildFollowupBadge(r)),
                                            // Next Action
                                            DataCell(_buildNextActionBadge(r)),
                                            // Days in Current Stage
                                            DataCell(
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: isHold
                                                      ? Colors.grey.shade100
                                                      : (r.daysInCurrentStage >= 15
                                                          ? const Color(0xFFFEF2F2)
                                                          : (r.daysInCurrentStage >= 8 ? const Color(0xFFFFFBEB) : const Color(0xFFF0FDF4))),
                                                  borderRadius: BorderRadius.circular(4),
                                                ),
                                                child: Text(
                                                  '${r.daysInCurrentStage} Days',
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 12,
                                                    color: isHold
                                                        ? Colors.grey.shade700
                                                        : (r.daysInCurrentStage >= 15
                                                            ? const Color(0xFFDC2626)
                                                            : (r.daysInCurrentStage >= 8 ? const Color(0xFFD97706) : const Color(0xFF16A34A))),
                                                  ),
                                                ),
                                              ),
                                            ),
                                            // Actions
                                            DataCell(
                                              Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  // 1. [Open]
                                                  IconButton.filledTonal(
                                                    icon: const Icon(Icons.visibility_outlined, size: 14),
                                                    tooltip: 'Open Customer Details',
                                                    style: IconButton.styleFrom(
                                                      visualDensity: VisualDensity.compact,
                                                      padding: const EdgeInsets.all(4),
                                                    ),
                                                    onPressed: () => _openDetailsDialog(r),
                                                  ),
                                                  const SizedBox(width: 4),
                                                  // 2. [Call]
                                                  if (r.mobile != null && r.mobile!.isNotEmpty) ...[
                                                    IconButton.filledTonal(
                                                      icon: const Icon(Icons.phone, size: 14, color: Color(0xFF0284C7)),
                                                      tooltip: 'Call Customer: ${r.mobile}',
                                                      style: IconButton.styleFrom(
                                                        backgroundColor: const Color(0xFFE0F2FE),
                                                        visualDensity: VisualDensity.compact,
                                                        padding: const EdgeInsets.all(4),
                                                      ),
                                                      onPressed: () => _makePhoneCall(r.mobile),
                                                    ),
                                                    const SizedBox(width: 4),
                                                  ],
                                                  // 3. [Mark Complete]
                                                  if (!isCompleted && !isHold) ...[
                                                    FilledButton.tonalIcon(
                                                      icon: const Icon(Icons.check_circle_outline, size: 14, color: Color(0xFF059669)),
                                                      label: const Text('Complete', style: TextStyle(fontSize: 12, color: Color(0xFF065F46), fontWeight: FontWeight.bold)),
                                                      style: FilledButton.styleFrom(
                                                        backgroundColor: const Color(0xFFECFDF5),
                                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                        visualDensity: VisualDensity.compact,
                                                      ),
                                                      onPressed: () => _confirmMarkAsComplete(r),
                                                    ),
                                                    const SizedBox(width: 4),
                                                    // 4. [Mark Hold]
                                                    FilledButton.tonalIcon(
                                                      icon: const Icon(Icons.pause_circle_outline, size: 14, color: Color(0xFFD97706)),
                                                      label: const Text('Hold', style: TextStyle(fontSize: 12, color: Color(0xFF92400E), fontWeight: FontWeight.bold)),
                                                      style: FilledButton.styleFrom(
                                                        backgroundColor: const Color(0xFFFFFBEB),
                                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                        visualDensity: VisualDensity.compact,
                                                      ),
                                                      onPressed: () => _confirmMarkAsHold(r),
                                                    ),
                                                    const SizedBox(width: 4),
                                                    // 5. [Follow-up]
                                                    FilledButton.tonalIcon(
                                                      icon: const Icon(Icons.phone_in_talk_rounded, size: 14, color: Color(0xFF2563EB)),
                                                      label: const Text('Follow-up', style: TextStyle(fontSize: 12, color: Color(0xFF1E40AF), fontWeight: FontWeight.bold)),
                                                      style: FilledButton.styleFrom(
                                                        backgroundColor: const Color(0xFFEFF6FF),
                                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                        visualDensity: VisualDensity.compact,
                                                      ),
                                                      onPressed: () => _openFollowupDialog(r),
                                                    ),
                                                  ],
                                                  if (isHold) ...[
                                                    FilledButton.icon(
                                                      icon: const Icon(Icons.replay_rounded, size: 14),
                                                      label: const Text('Reopen', style: TextStyle(fontSize: 12)),
                                                      style: FilledButton.styleFrom(
                                                        backgroundColor: const Color(0xFF2563EB),
                                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                                        visualDensity: VisualDensity.compact,
                                                      ),
                                                      onPressed: () => _confirmReopen(r),
                                                    ),
                                                    const SizedBox(width: 4),
                                                    FilledButton.tonalIcon(
                                                      icon: const Icon(Icons.phone_in_talk_rounded, size: 14, color: Color(0xFF2563EB)),
                                                      label: const Text('Follow-up', style: TextStyle(fontSize: 12, color: Color(0xFF1E40AF), fontWeight: FontWeight.bold)),
                                                      style: FilledButton.styleFrom(
                                                        backgroundColor: const Color(0xFFEFF6FF),
                                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                        visualDensity: VisualDensity.compact,
                                                      ),
                                                      onPressed: () => _openFollowupDialog(r),
                                                    ),
                                                  ],
                                                  if (r.hasActiveFollowup) ...[
                                                    const SizedBox(width: 4),
                                                    FilledButton.tonalIcon(
                                                      icon: const Icon(Icons.done_all_rounded, size: 14, color: Color(0xFF059669)),
                                                      label: const Text('Follow-up Done', style: TextStyle(fontSize: 11, color: Color(0xFF065F46), fontWeight: FontWeight.bold)),
                                                      style: FilledButton.styleFrom(
                                                        backgroundColor: const Color(0xFFD1FAE5),
                                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                                        visualDensity: VisualDensity.compact,
                                                      ),
                                                      onPressed: () => _openFollowupDoneDialog(r),
                                                    ),
                                                  ],
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
                            ),
                          ),

                // Pagination Footer
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Showing ${(_currentPage - 1) * _pageSize + (_records.isEmpty ? 0 : 1)} - ${(_currentPage - 1) * _pageSize + _records.length} of $_totalCount customers',
                        style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                      ),
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.chevron_left),
                            onPressed: _currentPage > 1
                                ? () {
                                    setState(() => _currentPage--);
                                    _loadActionCenterRecords();
                                  }
                                : null,
                          ),
                          Text('Page $_currentPage of ${totalPages == 0 ? 1 : totalPages}'),
                          IconButton(
                            icon: const Icon(Icons.chevron_right),
                            onPressed: _currentPage < totalPages
                                ? () {
                                    setState(() => _currentPage++);
                                    _loadActionCenterRecords();
                                  }
                                : null,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStageFilterCard({
    required String title,
    required String stageCode,
    required Color color,
    required IconData icon,
  }) {
    final count = _queueCounts[stageCode] ?? 0;
    final isSelected = _selectedStageFilter.toUpperCase() == stageCode.toUpperCase();

    return InkWell(
      onTap: () {
        setState(() {
          _selectedStageFilter = isSelected ? 'ALL' : stageCode;
          _currentPage = 1;
        });
        _loadActionCenterRecords();
      },
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 175,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.1) : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? color : Colors.grey.shade300,
            width: isSelected ? 2.5 : 1.0,
          ),
          boxShadow: isSelected
              ? [BoxShadow(color: color.withValues(alpha: 0.15), blurRadius: 6, offset: const Offset(0, 2))]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '$count',
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                    fontSize: 22,
                  ),
                ),
                Text(
                  isSelected ? 'Selected ✓' : 'Filter Section ➔',
                  style: TextStyle(
                    color: isSelected ? color : Colors.grey.shade600,
                    fontSize: 11,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStageBadge(String stage, {bool isHold = false, String? holdReason}) {
    if (isHold) {
      return Tooltip(
        message: holdReason != null ? 'Hold Reason: $holdReason' : 'On Hold (Action Center)',
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: const Color(0xFFFEF3C7),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: const Color(0xFFF59E0B)),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.pause_circle_filled, color: Color(0xFFD97706), size: 14),
              SizedBox(width: 4),
              Text(
                'HOLD',
                style: TextStyle(color: Color(0xFF92400E), fontWeight: FontWeight.bold, fontSize: 11),
              ),
            ],
          ),
        ),
      );
    }

    Color bg;
    Color fg;

    switch (stage) {
      case 'Agreement':
        bg = const Color(0xFFEFF6FF);
        fg = const Color(0xFF2563EB);
        break;
      case 'Loan':
        bg = const Color(0xFFFFFBEB);
        fg = const Color(0xFFD97706);
        break;
      case 'Installation':
        bg = const Color(0xFFCCFBF1);
        fg = const Color(0xFF0F766E);
        break;
      case 'RTS':
        bg = const Color(0xFFF3E8FF);
        fg = const Color(0xFF7C3AED);
        break;
      case 'Subsidy':
        bg = const Color(0xFFECFDF5);
        fg = const Color(0xFF059669);
        break;
      case 'Completed':
      default:
        bg = const Color(0xFFF3F4F6);
        fg = const Color(0xFF4B5563);
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: fg.withValues(alpha: 0.3)),
      ),
      child: Text(
        stage,
        style: TextStyle(color: fg, fontWeight: FontWeight.bold, fontSize: 12),
      ),
    );
  }

  Widget _buildFollowupBadge(ConsumerRecord r) {
    if (!r.hasActiveFollowup || r.followupDate == null) {
      return Text('—', style: TextStyle(color: Colors.grey.shade400, fontWeight: FontWeight.bold));
    }

    final dateStr = r.followupDate!.toLocal().toString().split(' ')[0];
    final reason = r.followupReason ?? 'Follow-up';

    if (r.isFollowupOverdue) {
      return Tooltip(
        message: '🔴 Overdue Follow-up ($reason): $dateStr\nRemarks: ${r.followupRemarks ?? 'None'}',
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: const Color(0xFFFEE2E2),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: const Color(0xFFDC2626)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('🔴', style: TextStyle(fontSize: 10)),
              const SizedBox(width: 4),
              Text(
                'Overdue: $dateStr',
                style: const TextStyle(color: Color(0xFF991B1B), fontWeight: FontWeight.bold, fontSize: 11),
              ),
            ],
          ),
        ),
      );
    } else if (r.isFollowupToday) {
      return Tooltip(
        message: "📞 Today's Follow-up ($reason)\nRemarks: ${r.followupRemarks ?? 'None'}",
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: const Color(0xFFE0F2FE),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: const Color(0xFF0284C7)),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('📞', style: TextStyle(fontSize: 10)),
              SizedBox(width: 4),
              Text(
                'Today',
                style: TextStyle(color: Color(0xFF0369A1), fontWeight: FontWeight.bold, fontSize: 11),
              ),
            ],
          ),
        ),
      );
    } else {
      return Tooltip(
        message: '🟡 Upcoming Follow-up ($reason): $dateStr\nRemarks: ${r.followupRemarks ?? 'None'}',
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: const Color(0xFFFEF3C7),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: const Color(0xFFF59E0B)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('🟡', style: TextStyle(fontSize: 10)),
              const SizedBox(width: 4),
              Text(
                'Upcoming: $dateStr',
                style: const TextStyle(color: Color(0xFF92400E), fontWeight: FontWeight.bold, fontSize: 11),
              ),
            ],
          ),
        ),
      );
    }
  }

  Widget _buildNextActionBadge(ConsumerRecord r) {
    final nextAction = WorkflowEngine.getNextAction(r);
    if (nextAction == 'None' || nextAction == 'No operational action') {
      return Text(
        nextAction == 'No operational action' ? '✓ Disbursed' : '—',
        style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
      );
    }

    Color badgeBg = const Color(0xFFEFF6FF);
    Color badgeFg = const Color(0xFF1D4ED8);
    IconData actionIcon = Icons.arrow_forward_rounded;

    if (nextAction.contains('Bank')) {
      badgeBg = const Color(0xFFFFFBEB);
      badgeFg = const Color(0xFFB45309);
      actionIcon = Icons.account_balance_outlined;
    } else if (nextAction.contains('Agreement')) {
      badgeBg = const Color(0xFFEFF6FF);
      badgeFg = const Color(0xFF1D4ED8);
      actionIcon = Icons.edit_document;
    } else if (nextAction.contains('Installation')) {
      badgeBg = const Color(0xFFF0FDF4);
      badgeFg = const Color(0xFF15803D);
      actionIcon = Icons.build_circle_outlined;
    } else if (nextAction.contains('RTS')) {
      badgeBg = const Color(0xFFFAF5FF);
      badgeFg = const Color(0xFF7E22CE);
      actionIcon = Icons.electric_meter_outlined;
    } else if (nextAction.contains('Wait') || nextAction.contains('Monitor')) {
      badgeBg = const Color(0xFFF1F5F9);
      badgeFg = const Color(0xFF475569);
      actionIcon = Icons.hourglass_empty_rounded;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: badgeBg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: badgeFg.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(actionIcon, size: 12, color: badgeFg),
          const SizedBox(width: 4),
          Text(
            nextAction,
            style: TextStyle(color: badgeFg, fontWeight: FontWeight.bold, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _buildMiscDataTable(ThemeData theme) {
    return ScrollConfiguration(
      behavior: ScrollConfiguration.of(context).copyWith(
        dragDevices: {
          PointerDeviceKind.touch,
          PointerDeviceKind.mouse,
          PointerDeviceKind.trackpad,
          PointerDeviceKind.stylus,
        },
      ),
      child: Scrollbar(
        controller: _verticalScrollController,
        thumbVisibility: true,
        trackVisibility: true,
        child: SingleChildScrollView(
          controller: _verticalScrollController,
          scrollDirection: Axis.vertical,
          child: Scrollbar(
            controller: _horizontalScrollController,
            thumbVisibility: true,
            trackVisibility: true,
            child: SingleChildScrollView(
              controller: _horizontalScrollController,
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columnSpacing: 16,
                horizontalMargin: 12,
                headingRowColor: WidgetStateProperty.all(
                  theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                ),
                columns: const [
                  DataColumn(label: Text('Customer Name', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Consumer No', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Mobile', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('MISC Reason', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Assigned Staff', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Due Date', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold))),
                ],
                rows: _miscActions.map((action) {
                  return DataRow(
                    cells: [
                      // Customer Name
                      DataCell(
                        InkWell(
                          onTap: () => _openEditMiscDialog(action),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(action.customerName, style: const TextStyle(fontWeight: FontWeight.w600)),
                              if (action.description != null && action.description!.isNotEmpty)
                                SizedBox(
                                  width: 140,
                                  child: Text(
                                    action.description!,
                                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                      // Consumer No
                      DataCell(Text(action.consumerNo, style: const TextStyle(fontWeight: FontWeight.w500))),
                      // Mobile
                      DataCell(
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(action.mobile ?? '—', style: TextStyle(color: action.mobile != null ? Colors.black87 : Colors.grey)),
                            if (action.mobile != null && action.mobile!.isNotEmpty) ...[
                              const SizedBox(width: 4),
                              IconButton(
                                icon: const Icon(Icons.phone, size: 14, color: Color(0xFF059669)),
                                tooltip: 'Call ${action.customerName}',
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                onPressed: () => _makePhoneCall(action.mobile),
                              ),
                            ],
                          ],
                        ),
                      ),
                      // MISC Reason + Priority
                      DataCell(
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEEF2FF),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: const Color(0xFF6366F1).withValues(alpha: 0.3)),
                              ),
                              child: Text(
                                action.reason,
                                style: const TextStyle(color: Color(0xFF4338CA), fontWeight: FontWeight.w600, fontSize: 12),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: action.priorityColor.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: action.priorityColor.withValues(alpha: 0.4)),
                              ),
                              child: Text(
                                action.priority.toUpperCase(),
                                style: TextStyle(color: action.priorityColor, fontWeight: FontWeight.bold, fontSize: 10),
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Assigned Staff
                      DataCell(Text(action.assignedStaffName ?? 'Unassigned', style: TextStyle(color: action.assignedStaffName != null ? Colors.black87 : Colors.grey))),
                      // Due Date
                      DataCell(_buildMiscDueDateBadge(action)),
                      // Status
                      DataCell(
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: action.statusColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: action.statusColor.withValues(alpha: 0.3)),
                          ),
                          child: Text(
                            action.status,
                            style: TextStyle(color: action.statusColor, fontWeight: FontWeight.bold, fontSize: 11),
                          ),
                        ),
                      ),
                      // Actions: [Open] [Call] [Complete] [Hold] [Follow-up]
                      DataCell(
                        Wrap(
                          spacing: 4,
                          runSpacing: 2,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            // [Open]
                            OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                minimumSize: const Size(0, 28),
                                visualDensity: VisualDensity.compact,
                                side: BorderSide(color: theme.colorScheme.primary),
                              ),
                              onPressed: () => _openEditMiscDialog(action),
                              child: const Text('Open', style: TextStyle(fontSize: 11)),
                            ),
                            // [Call]
                            if (action.mobile != null && action.mobile!.isNotEmpty)
                              IconButton(
                                icon: const Icon(Icons.phone_in_talk, size: 16, color: Color(0xFF059669)),
                                tooltip: 'Call Customer (${action.mobile})',
                                padding: const EdgeInsets.all(4),
                                constraints: const BoxConstraints(),
                                onPressed: () => _makePhoneCall(action.mobile),
                              ),
                            // [✓ Complete]
                            if (!action.isCompleted)
                              FilledButton(
                                style: FilledButton.styleFrom(
                                  backgroundColor: const Color(0xFF059669),
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  minimumSize: const Size(0, 28),
                                  visualDensity: VisualDensity.compact,
                                ),
                                onPressed: () => _confirmCompleteMiscAction(action),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.check, size: 12),
                                    SizedBox(width: 2),
                                    Text('Complete', style: TextStyle(fontSize: 11)),
                                  ],
                                ),
                              ),
                            // [⏸ Hold]
                            if (action.isActive)
                              OutlinedButton(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: const Color(0xFFD97706),
                                  side: const BorderSide(color: Color(0xFFD97706)),
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  minimumSize: const Size(0, 28),
                                  visualDensity: VisualDensity.compact,
                                ),
                                onPressed: () => _confirmHoldMiscAction(action),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.pause, size: 12),
                                    SizedBox(width: 2),
                                    Text('Hold', style: TextStyle(fontSize: 11)),
                                  ],
                                ),
                              ),
                            // [📞 Follow-up]
                            OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFF2563EB),
                                side: const BorderSide(color: Color(0xFF2563EB)),
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                minimumSize: const Size(0, 28),
                                visualDensity: VisualDensity.compact,
                              ),
                              onPressed: () => _confirmFollowupMiscAction(action),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.phone, size: 12),
                                  SizedBox(width: 2),
                                  Text('Follow-up', style: TextStyle(fontSize: 11)),
                                ],
                              ),
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
      ),
    );
  }

  Widget _buildMiscDueDateBadge(CustomerMiscAction action) {
    if (action.dueDate == null) {
      return Text('Not Set', style: TextStyle(fontSize: 11, color: Colors.grey.shade500));
    }
    final dateStr = '${action.dueDate!.day.toString().padLeft(2, '0')}/${action.dueDate!.month.toString().padLeft(2, '0')}/${action.dueDate!.year}';

    if (action.isOverdue) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: const Color(0xFFFEE2E2),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: const Color(0xFFEF4444)),
        ),
        child: Text('🔴 Overdue: $dateStr', style: const TextStyle(color: Color(0xFF991B1B), fontSize: 11, fontWeight: FontWeight.bold)),
      );
    }
    if (action.isDueToday) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: const Color(0xFFFEF3C7),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: const Color(0xFFF59E0B)),
        ),
        child: Text('⚠️ Due Today', style: const TextStyle(color: Color(0xFF92400E), fontSize: 11, fontWeight: FontWeight.bold)),
      );
    }

    return Text(dateStr, style: const TextStyle(fontSize: 12));
  }

  // ================= GENERAL ISSUE DATA TABLE =================

  Widget _buildIssueDataTable(ThemeData theme) {
    return ScrollConfiguration(
      behavior: ScrollConfiguration.of(context).copyWith(
        dragDevices: {
          PointerDeviceKind.touch,
          PointerDeviceKind.mouse,
          PointerDeviceKind.trackpad,
          PointerDeviceKind.stylus,
        },
      ),
      child: Scrollbar(
        controller: _verticalScrollController,
        thumbVisibility: true,
        trackVisibility: true,
        child: SingleChildScrollView(
          controller: _verticalScrollController,
          scrollDirection: Axis.vertical,
          child: Scrollbar(
            controller: _horizontalScrollController,
            thumbVisibility: true,
            trackVisibility: true,
            child: SingleChildScrollView(
              controller: _horizontalScrollController,
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columnSpacing: 16,
                horizontalMargin: 12,
                headingRowColor: WidgetStateProperty.all(
                  theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                ),
                columns: const [
                  DataColumn(label: Text('Customer Name', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Consumer No', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Issue Type & Priority', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Title / Description', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Assigned Staff', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Due Date / Alert', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold))),
                ],
                rows: _issues.map((issue) {
                  return DataRow(
                    cells: [
                      // Customer Name
                      DataCell(
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  issue.customerName,
                                  style: const TextStyle(fontWeight: FontWeight.w600),
                                ),
                                if (issue.mobile != null && issue.mobile!.isNotEmpty)
                                  Text(
                                    issue.mobile!,
                                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                                  ),
                              ],
                            ),
                            if (issue.mobile != null && issue.mobile!.isNotEmpty) ...[
                              const SizedBox(width: 4),
                              IconButton(
                                icon: const Icon(Icons.phone, size: 14, color: Color(0xFF059669)),
                                tooltip: 'Call ${issue.customerName}',
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                onPressed: () => _makePhoneCall(issue.mobile),
                              ),
                            ],
                          ],
                        ),
                      ),
                      // Consumer No
                      DataCell(
                        InkWell(
                          onTap: () async {
                            final rec = await RecordService.fetchRecordById(issue.customerId);
                            if (rec != null && mounted) _openDetailsDialog(rec);
                          },
                          child: Text(
                            issue.consumerNo,
                            style: const TextStyle(
                              color: Color(0xFF2563EB),
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                      ),
                      // Issue Type & Priority
                      DataCell(
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: issue.typeColor.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: issue.typeColor.withValues(alpha: 0.4)),
                              ),
                              child: Text(
                                issue.issueType,
                                style: TextStyle(color: issue.typeColor, fontWeight: FontWeight.w600, fontSize: 12),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: issue.priorityColor.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: issue.priorityColor.withValues(alpha: 0.4)),
                              ),
                              child: Text(
                                issue.priority.toUpperCase(),
                                style: TextStyle(color: issue.priorityColor, fontWeight: FontWeight.bold, fontSize: 10),
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Title & Description
                      DataCell(
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 240),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                issue.title,
                                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (issue.description != null && issue.description!.isNotEmpty)
                                Text(
                                  issue.description!,
                                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                            ],
                          ),
                        ),
                      ),
                      // Assigned Staff
                      DataCell(
                        InkWell(
                          onTap: () => _confirmAssignIssue(issue),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.person, size: 14, color: issue.assignedStaff != null ? const Color(0xFF2563EB) : Colors.grey),
                              const SizedBox(width: 4),
                              Text(
                                issue.assignedStaff ?? 'Unassigned (Tap)',
                                style: TextStyle(
                                  color: issue.assignedStaff != null ? Colors.black87 : Colors.grey.shade600,
                                  fontSize: 12,
                                  fontWeight: issue.assignedStaff != null ? FontWeight.w500 : FontWeight.normal,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      // Due Date / Alert (Stuck Detection)
                      DataCell(_buildIssueDueDateBadge(issue)),
                      // Status
                      DataCell(
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: issue.statusColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: issue.statusColor.withValues(alpha: 0.4)),
                          ),
                          child: Text(
                            issue.status,
                            style: TextStyle(color: issue.statusColor, fontWeight: FontWeight.bold, fontSize: 11),
                          ),
                        ),
                      ),
                      // Actions: [Open] [Assign] [Hold] [Resolve] [Close] [Follow-up]
                      DataCell(
                        Wrap(
                          spacing: 4,
                          runSpacing: 2,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            // [Open]
                            OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                minimumSize: const Size(0, 28),
                                visualDensity: VisualDensity.compact,
                                side: BorderSide(color: theme.colorScheme.primary),
                              ),
                              onPressed: () => _openEditIssueDialog(issue),
                              child: const Text('Open', style: TextStyle(fontSize: 11)),
                            ),
                            // [Assign]
                            OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                minimumSize: const Size(0, 28),
                                visualDensity: VisualDensity.compact,
                                side: const BorderSide(color: Color(0xFF2563EB)),
                                foregroundColor: const Color(0xFF2563EB),
                              ),
                              onPressed: () => _confirmAssignIssue(issue),
                              child: const Text('Assign', style: TextStyle(fontSize: 11)),
                            ),
                            // [Hold]
                            if (issue.status != 'Hold' && issue.status != 'Resolved' && issue.status != 'Closed')
                              OutlinedButton(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: const Color(0xFFD97706),
                                  side: const BorderSide(color: Color(0xFFD97706)),
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  minimumSize: const Size(0, 28),
                                  visualDensity: VisualDensity.compact,
                                ),
                                onPressed: () => _confirmHoldIssue(issue),
                                child: const Text('Hold', style: TextStyle(fontSize: 11)),
                              ),
                            // [Resolve]
                            if (issue.status != 'Resolved' && issue.status != 'Closed')
                              FilledButton(
                                style: FilledButton.styleFrom(
                                  backgroundColor: const Color(0xFF059669),
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  minimumSize: const Size(0, 28),
                                  visualDensity: VisualDensity.compact,
                                ),
                                onPressed: () => _confirmResolveIssue(issue),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.check, size: 12),
                                    SizedBox(width: 2),
                                    Text('Resolve', style: TextStyle(fontSize: 11)),
                                  ],
                                ),
                              ),
                            // [Close]
                            if (issue.status == 'Resolved')
                              FilledButton(
                                style: FilledButton.styleFrom(
                                  backgroundColor: Colors.grey.shade800,
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  minimumSize: const Size(0, 28),
                                  visualDensity: VisualDensity.compact,
                                ),
                                onPressed: () => _confirmCloseIssue(issue),
                                child: const Text('Close', style: TextStyle(fontSize: 11)),
                              ),
                            // [Reopen]
                            if (issue.status == 'Resolved' || issue.status == 'Closed' || issue.status == 'Cancelled')
                              OutlinedButton(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: const Color(0xFF2563EB),
                                  side: const BorderSide(color: Color(0xFF2563EB)),
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  minimumSize: const Size(0, 28),
                                  visualDensity: VisualDensity.compact,
                                ),
                                onPressed: () => _confirmReopenIssue(issue),
                                child: const Text('Reopen', style: TextStyle(fontSize: 11)),
                              ),
                            // [Follow-up]
                            OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFF2563EB),
                                side: const BorderSide(color: Color(0xFF2563EB)),
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                minimumSize: const Size(0, 28),
                                visualDensity: VisualDensity.compact,
                              ),
                              onPressed: () => _confirmFollowupIssue(issue),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.phone, size: 12),
                                  SizedBox(width: 2),
                                  Text('Follow-up', style: TextStyle(fontSize: 11)),
                                ],
                              ),
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
      ),
    );
  }

  Widget _buildIssueDueDateBadge(CustomerIssue issue) {
    if (issue.isStuck) {
      return Tooltip(
        message: 'Stuck Issue: In progress or assigned for over 7 days.',
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: const Color(0xFFFEF2F2),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: const Color(0xFFEF4444)),
          ),
          child: const Text('⚠️ Stuck Issue', style: TextStyle(color: Color(0xFFDC2626), fontSize: 11, fontWeight: FontWeight.bold)),
        ),
      );
    }
    if (issue.dueDate == null) {
      return Text('Not Set', style: TextStyle(fontSize: 11, color: Colors.grey.shade500));
    }
    final dateStr = '${issue.dueDate!.day.toString().padLeft(2, '0')}/${issue.dueDate!.month.toString().padLeft(2, '0')}/${issue.dueDate!.year}';

    if (issue.isOverdue) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: const Color(0xFFFEE2E2),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: const Color(0xFFEF4444)),
        ),
        child: Text('🔴 Overdue: $dateStr', style: const TextStyle(color: Color(0xFF991B1B), fontSize: 11, fontWeight: FontWeight.bold)),
      );
    }
    if (issue.isDueToday) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: const Color(0xFFFEF3C7),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: const Color(0xFFF59E0B)),
        ),
        child: const Text('⚠️ Due Today', style: TextStyle(color: Color(0xFF92400E), fontSize: 11, fontWeight: FontWeight.bold)),
      );
    }

    return Text(dateStr, style: const TextStyle(fontSize: 12));
  }

  // ================= PAYMENT DATA TABLE =================

  Widget _buildPaymentDataTable(ThemeData theme) {
    return ScrollConfiguration(
      behavior: ScrollConfiguration.of(context).copyWith(
        dragDevices: {
          PointerDeviceKind.touch,
          PointerDeviceKind.mouse,
          PointerDeviceKind.trackpad,
          PointerDeviceKind.stylus,
        },
      ),
      child: Scrollbar(
        controller: _verticalScrollController,
        thumbVisibility: true,
        trackVisibility: true,
        child: SingleChildScrollView(
          controller: _verticalScrollController,
          scrollDirection: Axis.vertical,
          child: Scrollbar(
            controller: _horizontalScrollController,
            thumbVisibility: true,
            trackVisibility: true,
            child: SingleChildScrollView(
              controller: _horizontalScrollController,
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columnSpacing: 16,
                horizontalMargin: 12,
                headingRowColor: WidgetStateProperty.all(
                  theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                ),
                columns: const [
                  DataColumn(label: Text('Customer Name', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Consumer No', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Current Stage', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Total Amount', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Paid Amount', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Pending Amount', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Due Date', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Payment Status', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold))),
                ],
                rows: _records.map((r) {
                  return DataRow(
                    cells: [
                      // Customer Name
                      DataCell(
                        InkWell(
                          onTap: () => _openDetailsDialog(r),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                r.name,
                                style: const TextStyle(fontWeight: FontWeight.w600),
                              ),
                              if (r.mobile != null && r.mobile!.isNotEmpty)
                                Text(
                                  r.mobile!,
                                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                                ),
                            ],
                          ),
                        ),
                      ),
                      // Consumer No
                      DataCell(
                        InkWell(
                          onTap: () => _openDetailsDialog(r),
                          child: Text(
                            r.consumerNo,
                            style: const TextStyle(
                              color: Color(0xFF2563EB),
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                      ),
                      // Current Stage
                      DataCell(_buildStageBadge(r.overallStage, isHold: r.isHold, holdReason: r.holdReason ?? r.noActionReason)),
                      // Total Amount
                      DataCell(
                        Text(
                          '₹${r.totalAmount.toStringAsFixed(0)}',
                          style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
                        ),
                      ),
                      // Paid Amount
                      DataCell(
                        Text(
                          '₹${r.paidAmount.toStringAsFixed(0)}',
                          style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF059669), fontSize: 13),
                        ),
                      ),
                      // Pending Amount
                      DataCell(
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: r.pendingAmount > 0 ? const Color(0xFFFEF2F2) : const Color(0xFFF0FDF4),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: r.pendingAmount > 0 ? const Color(0xFFEF4444) : const Color(0xFF22C55E)),
                          ),
                          child: Text(
                            '₹${r.pendingAmount.toStringAsFixed(0)}',
                            style: TextStyle(
                              color: r.pendingAmount > 0 ? const Color(0xFFDC2626) : const Color(0xFF16A34A),
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                      // Due Date
                      DataCell(_buildPaymentDueDateBadge(r)),
                      // Payment Status
                      DataCell(
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: r.paymentStatus == 'Paid'
                                ? const Color(0xFFECFDF5)
                                : (r.paymentStatus == 'Partially Paid' ? const Color(0xFFFFFBEB) : const Color(0xFFFEF2F2)),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: r.paymentStatus == 'Paid'
                                  ? const Color(0xFF059669)
                                  : (r.paymentStatus == 'Partially Paid' ? const Color(0xFFD97706) : const Color(0xFFDC2626)),
                            ),
                          ),
                          child: Text(
                            r.paymentStatus,
                            style: TextStyle(
                              color: r.paymentStatus == 'Paid'
                                  ? const Color(0xFF059669)
                                  : (r.paymentStatus == 'Partially Paid' ? const Color(0xFFB45309) : const Color(0xFFDC2626)),
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ),
                      // Actions: [Open] [+ Add Payment] [📞 Follow-up] [Call]
                      DataCell(
                        Wrap(
                          spacing: 4,
                          runSpacing: 2,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                minimumSize: const Size(0, 28),
                                visualDensity: VisualDensity.compact,
                                side: BorderSide(color: theme.colorScheme.primary),
                              ),
                              onPressed: () => _openDetailsDialog(r),
                              child: const Text('Open', style: TextStyle(fontSize: 11)),
                            ),
                            FilledButton.icon(
                              style: FilledButton.styleFrom(
                                backgroundColor: const Color(0xFF059669),
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                minimumSize: const Size(0, 28),
                                visualDensity: VisualDensity.compact,
                              ),
                              icon: const Icon(Icons.add, size: 12),
                              label: const Text('Add Payment', style: TextStyle(fontSize: 11)),
                              onPressed: () => _openAddPaymentDialog(r),
                            ),
                            OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFF2563EB),
                                side: const BorderSide(color: Color(0xFF2563EB)),
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                minimumSize: const Size(0, 28),
                                visualDensity: VisualDensity.compact,
                              ),
                              onPressed: () => _confirmFollowupPayment(r),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.phone, size: 12),
                                  SizedBox(width: 2),
                                  Text('Follow-up', style: TextStyle(fontSize: 11)),
                                ],
                              ),
                            ),
                            if (r.mobile != null && r.mobile!.isNotEmpty)
                              IconButton(
                                icon: const Icon(Icons.phone_in_talk, size: 16, color: Color(0xFF059669)),
                                tooltip: 'Call ${r.name}',
                                padding: const EdgeInsets.all(4),
                                constraints: const BoxConstraints(),
                                onPressed: () => _makePhoneCall(r.mobile),
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
      ),
    );
  }

  Widget _buildPaymentDueDateBadge(ConsumerRecord r) {
    if (r.paymentDueDate == null) {
      return Text('—', style: TextStyle(fontSize: 12, color: Colors.grey.shade400));
    }
    final dateStr = '${r.paymentDueDate!.day.toString().padLeft(2, '0')}/${r.paymentDueDate!.month.toString().padLeft(2, '0')}/${r.paymentDueDate!.year}';
    if (r.isPaymentOverdue) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: const Color(0xFFFEE2E2),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: const Color(0xFFEF4444)),
        ),
        child: Text('🔴 Overdue: $dateStr', style: const TextStyle(color: Color(0xFF991B1B), fontSize: 11, fontWeight: FontWeight.bold)),
      );
    }
    return Text(dateStr, style: const TextStyle(fontSize: 12));
  }
}

/// Backward compatibility alias for PriorityListScreen
typedef PriorityListScreen = ActionCenterScreen;
