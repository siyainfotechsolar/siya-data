import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:open_filex/open_filex.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import '../models/office_task.dart';
import '../models/consumer_record.dart';
import '../models/shared_document.dart';
import '../services/office_task_service.dart';
import '../services/supabase_service.dart';
import '../widgets/customer_search_dialog.dart';
import 'task_details_screen.dart';
import 'home_screen.dart';

class CreateTaskScreen extends StatefulWidget {
  final SharedDocument? document;
  final File? initialFile;
  final String? initialFileName;
  final ConsumerRecord? preselectedCustomer;

  const CreateTaskScreen({
    super.key,
    this.document,
    this.initialFile,
    this.initialFileName,
    this.preselectedCustomer,
  });

  @override
  State<CreateTaskScreen> createState() => _CreateTaskScreenState();
}

class _CreateTaskScreenState extends State<CreateTaskScreen> {
  final _formKey = GlobalKey<FormState>();

  ConsumerRecord? _selectedCustomer;
  late final TextEditingController _titleController;
  late final TextEditingController _descController;

  String _taskType = OfficeTaskType.pmSuryaGhar;
  String _priority = OfficeTaskPriority.normal;
  DateTime _dueDate = DateTime.now().add(const Duration(days: 1));

  List<Map<String, String>> _staffList = [];
  String? _selectedStaffId;
  String? _selectedStaffName;
  bool _isLoadingStaff = true;
  bool _isSaving = false;

  File? _attachedFile;
  String? _attachedFileName;
  int? _attachedFileSize;
  bool _isFromWhatsApp = false;

  @override
  void initState() {
    super.initState();
    _selectedCustomer = widget.preselectedCustomer;

    // Handle incoming WhatsApp shared document or file
    if (widget.document != null) {
      _attachedFile = File(widget.document!.filePath);
      _attachedFileName = widget.document!.fileName;
      _attachedFileSize = widget.document!.fileSize;
      _isFromWhatsApp = true;
      if (widget.document!.isPdf) {
        _taskType = OfficeTaskType.pmSuryaGhar;
      } else {
        _taskType = OfficeTaskType.documentCollection;
      }
      _titleController = TextEditingController(
        text: 'Doc: ${widget.document!.fileNameWithoutExtension}',
      );
    } else if (widget.initialFile != null) {
      _attachedFile = widget.initialFile;
      _attachedFileName = widget.initialFileName ??
          widget.initialFile!.path.split(Platform.pathSeparator).last;
      _titleController = TextEditingController(
        text: 'Task - $_attachedFileName',
      );
    } else {
      _titleController = TextEditingController(
        text: '$_taskType Task',
      );
    }

    _descController = TextEditingController();
    _loadStaff();
  }

  Future<void> _loadStaff() async {
    final list = await MobileOfficeTaskService.fetchActiveOfficeStaff();
    final user = SupabaseService.currentUser;
    String? currentName;
    if (user != null) {
      try {
        final profile = await SupabaseService.client
            .from('profiles')
            .select('full_name')
            .eq('id', user.id)
            .maybeSingle();
        final name = profile?['full_name'] as String?;
        currentName = (name != null && name.trim().isNotEmpty)
            ? name.trim()
            : user.email?.split('@').first;
      } catch (_) {
        currentName = user.email?.split('@').first;
      }
    }

    if (mounted) {
      setState(() {
        _staffList = list;
        _isLoadingStaff = false;

        // Default to logged-in staff member if found in list
        if (list.isNotEmpty) {
          final match = list.firstWhere(
            (s) =>
                s['id'] == user?.id ||
                (currentName != null &&
                    s['name']?.toLowerCase() == currentName.toLowerCase()),
            orElse: () => list.first,
          );
          _selectedStaffId = match['id'];
          _selectedStaffName = match['name'];
        }
      });
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  void _updateDefaultTitle() {
    if (_selectedCustomer != null) {
      if (_isFromWhatsApp && _attachedFileName != null) {
        _titleController.text = '$_taskType - ${_selectedCustomer!.name}';
      } else {
        _titleController.text = '$_taskType - ${_selectedCustomer!.name}';
      }
    }
  }

  Future<void> _pickCustomer() async {
    final result = await showDialog<ConsumerRecord>(
      context: context,
      builder: (_) => const CustomerSearchDialog(),
    );

    if (result != null && mounted) {
      setState(() {
        _selectedCustomer = result;
        _updateDefaultTitle();
      });
    }
  }

  Future<void> _pickDueDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() => _dueDate = picked);
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(source: source, imageQuality: 85);
      if (picked != null) {
        final file = File(picked.path);
        final size = await file.length();
        setState(() {
          _attachedFile = file;
          _attachedFileName = picked.name;
          _attachedFileSize = size;
          _isFromWhatsApp = false;
        });
      }
    } catch (e) {
      debugPrint('Error picking image: $e');
    }
  }

  Future<void> _pickDocument() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx', 'jpg', 'jpeg', 'png', 'xlsx'],
      );
      if (result != null && result.files.single.path != null) {
        final file = File(result.files.single.path!);
        final size = await file.length();
        setState(() {
          _attachedFile = file;
          _attachedFileName = result.files.single.name;
          _attachedFileSize = size;
          _isFromWhatsApp = false;
        });
      }
    } catch (e) {
      debugPrint('Error picking document: $e');
    }
  }

  void _removeAttachment() {
    setState(() {
      _attachedFile = null;
      _attachedFileName = null;
      _attachedFileSize = null;
      _isFromWhatsApp = false;
    });
  }

  Future<void> _openAttachedFile() async {
    if (_attachedFile != null && await _attachedFile!.exists()) {
      try {
        await OpenFilex.open(_attachedFile!.path);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not open file: $e')),
          );
        }
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Action: Create Task (Unified OfficeTask)
  // ---------------------------------------------------------------------------
  Future<void> _handleCreateTask() async {
    if (_selectedCustomer == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a customer first.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (_selectedStaffName == null || _selectedStaffName!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select an active office staff member.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      // 1. Upload attachment if present
      String? attachmentUrl;
      if (_attachedFile != null && await _attachedFile!.exists()) {
        attachmentUrl =
            await MobileOfficeTaskService.uploadTaskFile(_attachedFile!);
      }

      // 2. Create task in unified tasks table
      final task = await MobileOfficeTaskService.createTask(
        customerId: _selectedCustomer!.id,
        customerName: _selectedCustomer!.name,
        consumerNo: _selectedCustomer!.consumerNo,
        village: _selectedCustomer!.village,
        title: _titleController.text.trim(),
        taskType: _taskType,
        description: _descController.text.trim(),
        priority: _priority,
        dueDate: _dueDate,
        assignedToId: _selectedStaffId,
        assignedToName: _selectedStaffName!,
        attachmentUrl: attachmentUrl,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Task assigned to ${task.assignedToName}!'),
            backgroundColor: const Color(0xFF059669),
          ),
        );

        // Replace route with TaskDetailsScreen so staff can immediately view details
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => TaskDetailsScreen(task: task),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to create task: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Create Task',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _safePop,
        ),
        actions: [
          if (_isFromWhatsApp)
            Container(
              margin: const EdgeInsets.only(right: 14),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF25D366), // WhatsApp Green
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.share_rounded, size: 13, color: Colors.white),
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
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Customer Selection Card
              _buildCustomerSelectionCard(),
              const SizedBox(height: 16),

              // 2. Attachment Card (WhatsApp shared doc or uploaded file)
              _buildAttachmentSection(),
              const SizedBox(height: 16),

              // 3. Task Details Card
              _buildTaskDetailsCard(),
              const SizedBox(height: 24),

              // 4. Create Task Submit Button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF059669),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: _isSaving
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
                    _isSaving ? 'Creating Task...' : 'Create Task',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  onPressed: _isSaving ? null : _handleCreateTask,
                ),
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Customer Selection Card
  // ---------------------------------------------------------------------------
  Widget _buildCustomerSelectionCard() {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.person_outline,
                        size: 20, color: Color(0xFF2563EB)),
                    SizedBox(width: 8),
                    Text(
                      'Customer *',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                  ],
                ),
                TextButton.icon(
                  onPressed: _pickCustomer,
                  icon: Icon(
                    _selectedCustomer == null
                        ? Icons.person_add_alt_1_rounded
                        : Icons.swap_horiz_rounded,
                    size: 16,
                  ),
                  label: Text(
                    _selectedCustomer == null ? 'Select Customer' : 'Change',
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
              ],
            ),
            const Divider(height: 16),
            if (_selectedCustomer != null) ...[
              Text(
                _selectedCustomer!.name,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      _selectedCustomer!.consumerNo,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2563EB),
                      ),
                    ),
                  ),
                  if (_selectedCustomer!.village != null &&
                      _selectedCustomer!.village!.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _selectedCustomer!.village!,
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey.shade600),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ],
              ),
            ] else
              InkWell(
                onTap: _pickCustomer,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade300, style: BorderStyle.solid),
                  ),
                  child: Column(
                    children: [
                      Icon(Icons.person_search_rounded,
                          size: 32, color: Colors.grey.shade400),
                      const SizedBox(height: 6),
                      Text(
                        'Tap to search & link customer',
                        style: TextStyle(
                            fontSize: 13, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Attachment Section
  // ---------------------------------------------------------------------------
  Widget _buildAttachmentSection() {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.attach_file_rounded,
                        size: 20, color: Color(0xFF475569)),
                    const SizedBox(width: 8),
                    const Text(
                      'Attachment',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    if (_isFromWhatsApp) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFDCFCE7),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'WhatsApp',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF166534),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                if (_attachedFile != null)
                  IconButton(
                    icon: const Icon(Icons.close, size: 18, color: Colors.red),
                    tooltip: 'Remove Attachment',
                    visualDensity: VisualDensity.compact,
                    onPressed: _removeAttachment,
                  ),
              ],
            ),
            const Divider(height: 16),

            if (_attachedFile != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: (_attachedFileName?.toLowerCase().endsWith('.pdf') ?? false)
                            ? Colors.red.shade50
                            : Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        (_attachedFileName?.toLowerCase().endsWith('.pdf') ?? false)
                            ? Icons.picture_as_pdf
                            : Icons.image_rounded,
                        color: (_attachedFileName?.toLowerCase().endsWith('.pdf') ?? false)
                            ? Colors.red
                            : Colors.blue,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _attachedFileName ?? 'Attached Document',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _attachedFileSize != null
                                ? '${(_attachedFileSize! / 1024).toStringAsFixed(1)} KB'
                                : 'Ready to attach',
                            style: TextStyle(
                                fontSize: 11, color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    ),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        visualDensity: VisualDensity.compact,
                      ),
                      icon: const Icon(Icons.visibility_outlined, size: 14),
                      label: const Text('View', style: TextStyle(fontSize: 12)),
                      onPressed: _openAttachedFile,
                    ),
                  ],
                ),
              ),
            ] else ...[
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.camera_alt_outlined, size: 16),
                      label: const Text('Camera',
                          style: TextStyle(fontSize: 12)),
                      onPressed: () => _pickImage(ImageSource.camera),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.photo_library_outlined, size: 16),
                      label: const Text('Gallery',
                          style: TextStyle(fontSize: 12)),
                      onPressed: () => _pickImage(ImageSource.gallery),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.picture_as_pdf_outlined, size: 16),
                      label: const Text('PDF / Doc',
                          style: TextStyle(fontSize: 12)),
                      onPressed: _pickDocument,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Task Details Card
  // ---------------------------------------------------------------------------
  Widget _buildTaskDetailsCard() {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.assignment_outlined,
                    size: 20, color: Color(0xFF475569)),
                SizedBox(width: 8),
                Text(
                  'Task Information',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E293B),
                  ),
                ),
              ],
            ),
            const Divider(height: 20),

            // Task Title
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Task Title *',
                hintText: 'e.g. Agreement Verification, Collect Loan Docs',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Title is required' : null,
            ),
            const SizedBox(height: 14),

            // Task Type Dropdown
            DropdownButtonFormField<String>(
              initialValue: _taskType,
              decoration: const InputDecoration(
                labelText: 'Task Type *',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              items: OfficeTaskType.all
                  .map(
                    (t) => DropdownMenuItem(
                      value: t,
                      child: Row(
                        children: [
                          Icon(OfficeTaskType.getIcon(t),
                              size: 16, color: const Color(0xFF2563EB)),
                          const SizedBox(width: 8),
                          Text(t, style: const TextStyle(fontSize: 13)),
                        ],
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (v) {
                if (v != null) {
                  setState(() {
                    _taskType = v;
                    _updateDefaultTitle();
                  });
                }
              },
            ),
            const SizedBox(height: 14),

            // Assigned Staff Dropdown
            _isLoadingStaff
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(8.0),
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : DropdownButtonFormField<String>(
                    initialValue: _selectedStaffName,
                    decoration: const InputDecoration(
                      labelText: 'Assign To Staff *',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: _staffList
                        .map(
                          (s) => DropdownMenuItem(
                            value: s['name'],
                            child: Row(
                              children: [
                                const Icon(Icons.badge_outlined,
                                    size: 16, color: Color(0xFF475569)),
                                const SizedBox(width: 8),
                                Text(
                                  s['name'] ?? 'Staff',
                                  style: const TextStyle(fontSize: 13),
                                ),
                              ],
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (v) {
                      if (v != null) {
                        final found = _staffList.firstWhere(
                          (s) => s['name'] == v,
                          orElse: () => {'id': '', 'name': v},
                        );
                        setState(() {
                          _selectedStaffName = v;
                          _selectedStaffId = found['id'];
                        });
                      }
                    },
                    validator: (v) =>
                        v == null || v.isEmpty ? 'Staff is required' : null,
                  ),
            const SizedBox(height: 14),

            // Due Date Picker & Priority Row
            Row(
              children: [
                // Due Date
                Expanded(
                  child: InkWell(
                    onTap: _pickDueDate,
                    borderRadius: BorderRadius.circular(8),
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Due Date *',
                        border: OutlineInputBorder(),
                        isDense: true,
                        suffixIcon:
                            Icon(Icons.calendar_today_outlined, size: 18),
                      ),
                      child: Text(
                        DateFormat('dd MMM yyyy').format(_dueDate),
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // Priority Dropdown
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _priority,
                    decoration: const InputDecoration(
                      labelText: 'Priority *',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: OfficeTaskPriority.all
                        .map(
                          (p) => DropdownMenuItem(
                            value: p,
                            child: Text(
                              p,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: OfficeTaskPriority.getColor(p),
                              ),
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (v) {
                      if (v != null) setState(() => _priority = v);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Description / Instructions
            TextFormField(
              controller: _descController,
              decoration: const InputDecoration(
                labelText: 'Description / Instructions (optional)',
                hintText: 'e.g. Verify meter copy, collect signed subsidy form',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
              maxLines: 3,
            ),
          ],
        ),
      ),
    );
  }
}
