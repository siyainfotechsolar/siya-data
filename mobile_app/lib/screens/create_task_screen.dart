import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:open_filex/open_filex.dart';
import '../models/shared_document.dart';
import '../models/extracted_document_data.dart';
import '../models/customer_task.dart';
import '../models/consumer_record.dart';
import '../services/pdf_processing_service.dart';
import '../services/task_service.dart';
import '../services/supabase_service.dart';
import '../widgets/suggested_customer_card.dart';
import '../widgets/customer_search_dialog.dart';
import '../widgets/duplicate_document_dialog.dart';
import '../utils/back_navigation_helper.dart';
import 'home_screen.dart';
import 'task_detail_screen.dart';

class CreateTaskScreen extends StatefulWidget {
  final SharedDocument document;
  final ConsumerRecord? preselectedCustomer;

  const CreateTaskScreen({
    super.key,
    required this.document,
    this.preselectedCustomer,
  });

  @override
  State<CreateTaskScreen> createState() => _CreateTaskScreenState();
}

class _CreateTaskScreenState extends State<CreateTaskScreen> {
  bool _isProcessing = true;
  bool _isSubmitting = false;
  ExtractedDocumentData? _extractedData;
  CustomerMatchResult? _suggestedMatch;
  ConsumerRecord? _selectedCustomer;
  String? _initialTitle;
  String? _initialRemarks;

  late final TextEditingController _titleController;
  late final TextEditingController _remarksController;
  late final TextEditingController _assignedStaffController;

  List<Map<String, String>> _staffMembers = [];
  bool _isLoadingStaff = true;
  String? _selectedStaffName;
  bool _isCustomStaff = false;

  String _selectedDocType = TaskDocumentType.other;
  String _selectedPriority = TaskPriority.normal;
  DateTime _selectedDueDate = DateTime.now().add(const Duration(days: 2));

  @override
  void initState() {
    super.initState();
    _selectedCustomer = widget.preselectedCustomer;
    _titleController = TextEditingController(
      text: 'Doc Update: ${widget.document.fileNameWithoutExtension}',
    );
    _remarksController = TextEditingController();

    final user = SupabaseService.currentUser;
    final staffName = user?.email?.split('@').first ?? 'Staff';
    _assignedStaffController = TextEditingController(text: staffName);
    _selectedStaffName = staffName;

    _loadStaffList();
    _processDocumentAndMatch();
  }

  Future<void> _loadStaffList() async {
    try {
      final res = await SupabaseService.client
          .from('profiles')
          .select('id, full_name, email, role, status')
          .order('full_name', ascending: true);

      final List<Map<String, String>> list = [];
      for (final item in res) {
        final status = (item['status'] as String? ?? 'Active').toLowerCase();
        if (status == 'inactive' || status == 'suspended') continue;

        final fullName = (item['full_name'] as String?)?.trim();
        final email = (item['email'] as String?)?.trim() ?? '';
        final role = (item['role'] as String?)?.trim() ?? 'staff';
        final displayName = (fullName != null && fullName.isNotEmpty)
            ? fullName
            : (email.isNotEmpty ? email.split('@').first : 'Staff');

        list.add({
          'name': displayName,
          'email': email,
          'role': role,
        });
      }

      if (mounted) {
        setState(() {
          _staffMembers = list;
          _isLoadingStaff = false;

          final currentEmail = SupabaseService.currentUser?.email?.toLowerCase();
          final currentMatch = list.firstWhere(
            (s) => s['email']?.toLowerCase() == currentEmail,
            orElse: () => list.isNotEmpty
                ? list.first
                : {'name': 'Staff', 'email': '', 'role': 'staff'},
          );

          _selectedStaffName = currentMatch['name'];
          _assignedStaffController.text = _selectedStaffName ?? 'Staff';
        });
      }
    } catch (e) {
      debugPrint('Error loading staff list: $e');
      if (mounted) {
        setState(() {
          _isLoadingStaff = false;
          final fallbackName = SupabaseService.currentUser?.email?.split('@').first ?? 'Staff';
          if (_staffMembers.isEmpty) {
            _staffMembers = [
              {'name': fallbackName, 'email': '', 'role': 'staff'}
            ];
          }
          _selectedStaffName ??= fallbackName;
          _assignedStaffController.text = _selectedStaffName!;
        });
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _remarksController.dispose();
    _assignedStaffController.dispose();
    super.dispose();
  }

  Future<void> _processDocumentAndMatch() async {
    setState(() => _isProcessing = true);

    final extracted =
        await PdfProcessingService.processDocument(widget.document);

    CustomerMatchResult? match;
    if (_selectedCustomer == null && extracted.hasCustomerIdentifiers) {
      match = await TaskService.findSuggestedCustomer(
        consumerNo: extracted.consumerNo,
        mobile: extracted.mobileNumber,
        applicationId: extracted.applicationId,
        name: extracted.customerName,
      );
    }

    if (mounted) {
      setState(() {
        _extractedData = extracted;
        _suggestedMatch = match;
        _selectedDocType = extracted.detectedDocType;
        _titleController.text =
            '${extracted.detectedDocType}: ${widget.document.fileNameWithoutExtension}';

        // Auto-select if 100% exact match
        if (match != null && match.confidenceScore == 100) {
          _selectedCustomer = match.customer;
        }

        // Pre-fill remarks with extracted highlights
        final List<String> highlights = [];
        if (extracted.billAmount != null) {
          highlights.add('Bill Amount: ₹${extracted.billAmount}');
        }
        if (extracted.billDate != null) {
          highlights.add('Bill Date: ${extracted.billDate}');
        }
        if (extracted.consumerNo != null) {
          highlights.add('Consumer No: ${extracted.consumerNo}');
        }
        if (highlights.isNotEmpty && _remarksController.text.isEmpty) {
          _remarksController.text = highlights.join(' | ');
        }

        _initialTitle = _titleController.text;
        _initialRemarks = _remarksController.text;
        _isProcessing = false;
      });
    }
  }

  Future<void> _openCustomerSearch() async {
    final result = await showDialog<ConsumerRecord>(
      context: context,
      builder: (_) => CustomerSearchDialog(
        initialQuery: _extractedData?.consumerNo ??
            _extractedData?.customerName ??
            _extractedData?.mobileNumber,
      ),
    );
    if (result != null && mounted) {
      setState(() {
        _selectedCustomer = result;
        _suggestedMatch = null;
      });
    }
  }

  Future<void> _handleOpenFile() async {
    try {
      final result = await OpenFilex.open(widget.document.filePath);
      if (result.type != ResultType.done && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open file: ${result.message}')),
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

  Future<void> _handleCreateTask() async {
    if (_selectedCustomer == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select or confirm a customer first!'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a task title')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    // 1. Duplicate Check
    final duplicate = await TaskService.checkDuplicate(
      fileHash: widget.document.fileHash,
      customerId: _selectedCustomer!.id ?? '',
      documentType: _selectedDocType,
    );

    if (duplicate != null && mounted) {
      final proceed = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (_) => DuplicateDocumentDialog(existingTask: duplicate),
      );

      if (proceed != true) {
        if (mounted) setState(() => _isSubmitting = false);
        return;
      }
    }

    // 2. Build Task Model
    final user = SupabaseService.currentUser;
    final staffName = _assignedStaffController.text.trim().isNotEmpty
        ? _assignedStaffController.text.trim()
        : (user?.email?.split('@').first ?? 'Staff');

    final taskId = 'task_${DateTime.now().millisecondsSinceEpoch}';

    final task = CustomerTask(
      id: taskId,
      customerId: _selectedCustomer!.id ?? '',
      customerName: _selectedCustomer!.name,
      consumerNo: _selectedCustomer!.consumerNo,
      mobileNumber: _selectedCustomer!.mobile,
      taskType: 'Customer Document Update',
      title: _titleController.text.trim(),
      documentType: _selectedDocType,
      documentName: widget.document.fileName,
      localFilePath: widget.document.filePath,
      fileHash: widget.document.fileHash,
      fileSize: widget.document.fileSize,
      source: widget.document.source,
      status: TaskStatus.newTask,
      priority: _selectedPriority,
      assignedStaff: staffName,
      dueDate: _selectedDueDate,
      remarks: _remarksController.text.trim(),
      extractedData: _extractedData?.toMap(),
      createdBy: user?.id,
      createdByName: staffName,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    // 3. Save Task
    try {
      final created = await TaskService.createTask(task);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              created.isPendingSync
                  ? 'Task saved locally (Offline - Pending Sync)'
                  : 'Task created successfully with document attached!',
            ),
            backgroundColor: const Color(0xFF059669),
          ),
        );

        // Replace with Task Detail Screen
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => TaskDetailScreen(
              task: created,
              customer: _selectedCustomer!,
              extractedData: _extractedData,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to create task: $e')),
        );
      }
    }
  }

  bool _hasUnsavedChanges() {
    if (_initialTitle != null && _titleController.text.trim() != _initialTitle!.trim()) {
      return true;
    }
    if (_remarksController.text.trim() != (_initialRemarks ?? '').trim()) {
      return true;
    }
    if (_selectedCustomer != null &&
        _selectedCustomer != widget.preselectedCustomer &&
        _selectedCustomer != _suggestedMatch?.customer) {
      return true;
    }
    return false;
  }

  Future<bool> _handleWillPop() async {
    if (_isProcessing || _isSubmitting) {
      final confirm = await BackNavigationHelper.showProcessingDialog(
        context,
        title: 'Operation in Progress',
        message: 'Task processing or creation is in progress. Leaving now may interrupt it. Are you sure you want to leave?',
      );
      return confirm;
    }

    if (_hasUnsavedChanges()) {
      final discard = await BackNavigationHelper.showDiscardDialog(
        context,
        title: 'Discard Task?',
        message: 'Unsaved task details will be lost.',
      );
      return discard;
    }

    return true;
  }

  void _safePop() {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const MobileHomeScreen()),
      );
    }
  }

  Future<void> _handleBackPress() async {
    final canLeave = await _handleWillPop();
    if (canLeave && mounted) {
      _safePop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        await _handleBackPress();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            tooltip: 'Back',
            onPressed: _handleBackPress,
          ),
          title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'CREATE TASK',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            Text(
              'WhatsApp Direct Document Intake',
              style: TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 12),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF25D366), // WhatsApp Brand Green
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.share, size: 12, color: Colors.white),
                SizedBox(width: 4),
                Text(
                  'WhatsApp Share',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: _isProcessing
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Color(0xFF059669)),
                  SizedBox(height: 16),
                  Text(
                    'Smart Reading & Analyzing Document...',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Extracting Consumer No, Name, Amount & Matching Customer',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. ATTACHED DOCUMENT CARD
                  _buildDocumentCard(),
                  const SizedBox(height: 14),

                  // 2. SMART EXTRACTED INFORMATION CARD
                  if (_extractedData != null) _buildExtractedInfoCard(),
                  const SizedBox(height: 14),

                  // 3. CUSTOMER SELECTION & MATCH
                  _buildCustomerSection(),
                  const SizedBox(height: 16),

                  // 4. TASK DETAILS FORM
                  _buildTaskForm(theme),
                  const SizedBox(height: 24),

                  // 5. CREATE TASK BUTTON
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF059669),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: _isSubmitting ? null : _handleCreateTask,
                      icon: _isSubmitting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Icon(Icons.add_task_rounded, size: 22),
                      label: Text(
                        _isSubmitting ? 'Creating Task...' : 'Create Task',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),
                ],
              ),
            ),
      ),
    );
  }

  Widget _buildDocumentCard() {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: widget.document.isPdf
                    ? Colors.red.shade50
                    : Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                widget.document.isPdf
                    ? Icons.picture_as_pdf
                    : Icons.image_rounded,
                color: widget.document.isPdf ? Colors.red : Colors.blue,
                size: 26,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.document.fileName,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Text(
                        widget.document.formattedSize,
                        style: TextStyle(
                            fontSize: 11, color: Colors.grey.shade700),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '• ${widget.document.source}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF059669),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                visualDensity: VisualDensity.compact,
              ),
              onPressed: _handleOpenFile,
              icon: const Icon(Icons.visibility_outlined, size: 15),
              label: const Text('Open', style: TextStyle(fontSize: 12)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExtractedInfoCard() {
    final d = _extractedData!;
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFFBFDBFE)),
      ),
      color: const Color(0xFFF8FAFC),
      child: ExpansionTile(
        initiallyExpanded: true,
        leading: const Icon(Icons.auto_awesome, color: Color(0xFF2563EB), size: 20),
        title: const Text(
          'DOCUMENT INFORMATION',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
            color: Color(0xFF1E3A8A),
          ),
        ),
        subtitle: Text(
          'Detected: ${d.detectedDocType}',
          style: TextStyle(fontSize: 11, color: Colors.blue.shade900),
        ),
        children: [
          Padding(
            padding:
                const EdgeInsets.only(left: 16, right: 16, bottom: 12, top: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildInfoRow('Customer Name', d.customerName, d.confidenceMap['customerName']),
                _buildInfoRow('Consumer Number', d.consumerNo, d.confidenceMap['consumerNo']),
                _buildInfoRow('Mobile Number', d.mobileNumber, d.confidenceMap['mobileNumber']),
                _buildInfoRow('Application ID', d.applicationId, d.confidenceMap['applicationId']),
                _buildInfoRow('Village / Area', d.village, d.confidenceMap['village']),
                _buildInfoRow('Bill Date', d.billDate, d.confidenceMap['billDate']),
                _buildInfoRow('Due Date', d.dueDate, d.confidenceMap['dueDate']),
                if (d.billAmount != null)
                  _buildInfoRow('Bill Amount', '₹${d.billAmount}', d.confidenceMap['billAmount']),
                if (d.isPaymentProof && d.paymentCandidate != null)
                  _buildInfoRow('Payment Ref / UTR', d.paymentCandidate!['referenceNumber']?.toString(), 'High'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String? value, String? confidence) {
    if (value == null || value.trim().isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3.0),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1F2937),
              ),
            ),
          ),
          if (confidence != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: confidence == 'High'
                    ? const Color(0xFFDCFCE7)
                    : const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                confidence,
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  color: confidence == 'High'
                      ? const Color(0xFF166534)
                      : const Color(0xFF92400E),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCustomerSection() {
    if (_suggestedMatch != null && _selectedCustomer == null) {
      return SuggestedCustomerCard(
        match: _suggestedMatch!,
        onConfirm: () {
          setState(() {
            _selectedCustomer = _suggestedMatch!.customer;
            _suggestedMatch = null;
          });
        },
        onChange: _openCustomerSearch,
      );
    }

    if (_selectedCustomer != null) {
      return Card(
        elevation: 1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Color(0xFF059669), width: 1.2),
        ),
        color: const Color(0xFFF0FDF4),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            children: [
              const CircleAvatar(
                backgroundColor: Color(0xFF059669),
                radius: 18,
                child: Icon(Icons.person, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'LINKED CUSTOMER',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF065F46),
                        letterSpacing: 0.5,
                      ),
                    ),
                    Text(
                      _selectedCustomer!.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      'Cons No: ${_selectedCustomer!.consumerNo}${_selectedCustomer!.mobile != null ? ' • ${_selectedCustomer!.mobile}' : ''}',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: _openCustomerSearch,
                child: const Text('Change'),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.amber.shade400),
      ),
      color: Colors.amber.shade50,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          children: [
            Icon(Icons.person_search, color: Colors.amber.shade900),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'No Customer Linked',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  Text(
                    'Select customer to associate with this task',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                  ),
                ],
              ),
            ),
            FilledButton.tonal(
              onPressed: _openCustomerSearch,
              child: const Text('Select'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTaskForm(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'TASK DETAILS',
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 10),

        // Title
        TextField(
          controller: _titleController,
          decoration: const InputDecoration(
            labelText: 'Task Title *',
            border: OutlineInputBorder(),
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          ),
        ),
        const SizedBox(height: 12),

        // Document Type Dropdown
        DropdownButtonFormField<String>(
          value: _selectedDocType,
          decoration: const InputDecoration(
            labelText: 'Document Type *',
            border: OutlineInputBorder(),
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          ),
          items: TaskDocumentType.all.map((type) {
            return DropdownMenuItem(value: type, child: Text(type));
          }).toList(),
          onChanged: (val) {
            if (val != null) setState(() => _selectedDocType = val);
          },
        ),
        const SizedBox(height: 12),

        // Priority & Due Date Row
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                value: _selectedPriority,
                decoration: const InputDecoration(
                  labelText: 'Priority',
                  border: OutlineInputBorder(),
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                ),
                items: TaskPriority.all.map((p) {
                  return DropdownMenuItem(value: p, child: Text(p));
                }).toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _selectedPriority = val);
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: InkWell(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _selectedDueDate,
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (picked != null) {
                    setState(() => _selectedDueDate = picked);
                  }
                },
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Due Date',
                    border: OutlineInputBorder(),
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(DateFormat('dd-MM-yyyy').format(_selectedDueDate)),
                      const Icon(Icons.calendar_today, size: 16),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Assigned Staff Selection
        if (_isLoadingStaff) ...[
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8.0),
            child: Row(
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF059669)),
                ),
                SizedBox(width: 10),
                Text('Loading staff members...', style: TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
          ),
        ] else ...[
          DropdownButtonFormField<String>(
            value: _isCustomStaff
                ? '__custom__'
                : (_staffMembers.any((s) => s['name'] == _selectedStaffName)
                    ? _selectedStaffName
                    : (_staffMembers.isNotEmpty ? _staffMembers.first['name'] : null)),
            decoration: InputDecoration(
              labelText: 'Assign Staff * (जबाबदार कर्मचारी)',
              prefixIcon: const Icon(Icons.assignment_ind_rounded, color: Color(0xFF059669)),
              border: const OutlineInputBorder(),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              suffixIcon: _isCustomStaff
                  ? IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      tooltip: 'Select from staff list',
                      onPressed: () {
                        setState(() {
                          _isCustomStaff = false;
                          _selectedStaffName = _staffMembers.isNotEmpty ? _staffMembers.first['name'] : 'Staff';
                          _assignedStaffController.text = _selectedStaffName!;
                        });
                      },
                    )
                  : null,
            ),
            items: [
              ..._staffMembers.map((staff) {
                final name = staff['name'] ?? 'Staff';
                final role = staff['role'] ?? 'staff';
                return DropdownMenuItem<String>(
                  value: name,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.person_outline, size: 16, color: Color(0xFF059669)),
                      const SizedBox(width: 8),
                      Text(
                        name,
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Text(
                          role.replaceAll('_', ' '),
                          style: TextStyle(fontSize: 10, color: Colors.grey.shade700),
                        ),
                      ),
                    ],
                  ),
                );
              }),
              const DropdownMenuItem<String>(
                value: '__custom__',
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.person_add_alt_1_outlined, size: 16, color: Colors.blue),
                    SizedBox(width: 8),
                    Text(
                      '+ Enter Other Staff Name...',
                      style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
            onChanged: (val) {
              if (val == '__custom__') {
                setState(() {
                  _isCustomStaff = true;
                  _assignedStaffController.clear();
                });
              } else if (val != null) {
                setState(() {
                  _isCustomStaff = false;
                  _selectedStaffName = val;
                  _assignedStaffController.text = val;
                });
              }
            },
          ),
          if (_isCustomStaff) ...[
            const SizedBox(height: 10),
            TextField(
              controller: _assignedStaffController,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Enter Custom Staff Name *',
                hintText: 'e.g. Ramesh Patil',
                prefixIcon: Icon(Icons.person_add_outlined),
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              ),
              onChanged: (val) {
                _selectedStaffName = val.trim();
              },
            ),
          ],
        ],
        const SizedBox(height: 12),

        // Remarks
        TextField(
          controller: _remarksController,
          maxLines: 2,
          decoration: const InputDecoration(
            labelText: 'Remarks / Extracted Highlights',
            border: OutlineInputBorder(),
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          ),
        ),
      ],
    );
  }
}
