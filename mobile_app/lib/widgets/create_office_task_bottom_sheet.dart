import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import '../models/office_task.dart';
import '../models/consumer_record.dart';
import '../services/office_task_service.dart';
import 'customer_search_dialog.dart';

class CreateOfficeTaskBottomSheet extends StatefulWidget {
  final ConsumerRecord? preselectedCustomer;

  const CreateOfficeTaskBottomSheet({
    super.key,
    this.preselectedCustomer,
  });

  static Future<OfficeTask?> show(
    BuildContext context, {
    ConsumerRecord? preselectedCustomer,
  }) {
    return showModalBottomSheet<OfficeTask>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => CreateOfficeTaskBottomSheet(
        preselectedCustomer: preselectedCustomer,
      ),
    );
  }

  @override
  State<CreateOfficeTaskBottomSheet> createState() =>
      _CreateOfficeTaskBottomSheetState();
}

class _CreateOfficeTaskBottomSheetState
    extends State<CreateOfficeTaskBottomSheet> {
  final _formKey = GlobalKey<FormState>();

  ConsumerRecord? _selectedCustomer;
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descController = TextEditingController();

  String _taskType = OfficeTaskType.customerCall;
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

  @override
  void initState() {
    super.initState();
    _selectedCustomer = widget.preselectedCustomer;
    _updateDefaultTitle();
    _loadStaff();
  }

  void _updateDefaultTitle() {
    if (_selectedCustomer != null) {
      _titleController.text = '$_taskType - ${_selectedCustomer!.name}';
    } else {
      _titleController.text = '$_taskType Task';
    }
  }

  Future<void> _loadStaff() async {
    final list = await MobileOfficeTaskService.fetchActiveOfficeStaff();
    if (mounted) {
      setState(() {
        _staffList = list;
        _isLoadingStaff = false;
        if (list.isNotEmpty) {
          _selectedStaffId = list.first['id'];
          _selectedStaffName = list.first['name'];
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
    });
  }

  Future<void> _handleSave() async {
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
      String? attachmentUrl;
      if (_attachedFile != null) {
        attachmentUrl = await MobileOfficeTaskService.uploadTaskFile(_attachedFile!);
      }

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
        Navigator.pop(context, task);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to assign task: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);

    return Container(
      padding: EdgeInsets.only(
        bottom: media.viewInsets.bottom,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.assignment_ind_rounded,
                            color: Color(0xFF2563EB), size: 24),
                        SizedBox(width: 8),
                        Text(
                          'Assign Office Task',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const Divider(),
                const SizedBox(height: 8),

                // 1. Customer Selection
                const Text(
                  'CUSTOMER (ग्राहक) *',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 6),
                InkWell(
                  onTap: _pickCustomer,
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: _selectedCustomer == null
                            ? Colors.blue.shade300
                            : const Color(0xFF059669),
                        width: 1.2,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _selectedCustomer == null
                              ? Icons.person_search_rounded
                              : Icons.check_circle_rounded,
                          color: _selectedCustomer == null
                              ? const Color(0xFF2563EB)
                              : const Color(0xFF059669),
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _selectedCustomer == null
                              ? const Text(
                                  'Tap to search & select Customer...',
                                  style: TextStyle(
                                      color: Color(0xFF2563EB),
                                      fontWeight: FontWeight.w600),
                                )
                              : Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _selectedCustomer!.name,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14),
                                    ),
                                    Text(
                                      '${_selectedCustomer!.consumerNo} • ${_selectedCustomer!.village ?? "N/A"}',
                                      style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey.shade700),
                                    ),
                                  ],
                                ),
                        ),
                        const Icon(Icons.arrow_drop_down, color: Colors.grey),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // 2. Task Type
                const Text(
                  'TASK TYPE (कामाचा प्रकार) *',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  value: _taskType,
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10)),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                  ),
                  items: OfficeTaskType.allTypes.map((type) {
                    return DropdownMenuItem(
                      value: type,
                      child: Text(type, style: const TextStyle(fontSize: 13)),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        _taskType = val;
                        _updateDefaultTitle();
                      });
                    }
                  },
                ),
                const SizedBox(height: 14),

                // 3. Assign To (Active Office Staff)
                const Text(
                  'ASSIGN TO OFFICE STAFF (कोणाला काम द्यायचे?) *',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 6),
                if (_isLoadingStaff)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: LinearProgressIndicator(),
                  )
                else if (_staffList.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.amber.shade300),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.warning_amber_rounded,
                            color: Colors.amber, size: 20),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'No active office staff found in database.',
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  DropdownButtonFormField<String>(
                    value: _selectedStaffId,
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10)),
                      filled: true,
                      fillColor: Colors.grey.shade50,
                      prefixIcon: const Icon(Icons.badge_outlined,
                          color: Color(0xFF2563EB), size: 20),
                    ),
                    items: _staffList.map((staff) {
                      return DropdownMenuItem(
                        value: staff['id'],
                        child: Row(
                          children: [
                            Text(
                              staff['name'] ?? 'Staff',
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 1),
                              decoration: BoxDecoration(
                                color: const Color(0xFFDBEAFE),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                staff['role'] ?? 'office',
                                style: const TextStyle(
                                    fontSize: 10,
                                    color: Color(0xFF1E40AF),
                                    fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        final found = _staffList.firstWhere(
                            (s) => s['id'] == val,
                            orElse: () => {});
                        setState(() {
                          _selectedStaffId = val;
                          _selectedStaffName = found['name'] ?? '';
                        });
                      }
                    },
                  ),
                const SizedBox(height: 14),

                // 4. Priority & Due Date Row
                Row(
                  children: [
                    // Priority
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'PRIORITY *',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey,
                            ),
                          ),
                          const SizedBox(height: 6),
                          DropdownButtonFormField<String>(
                            value: _priority,
                            decoration: InputDecoration(
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 10),
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10)),
                              filled: true,
                              fillColor: Colors.grey.shade50,
                            ),
                            items: OfficeTaskPriority.allPriorities.map((p) {
                              Color c = Colors.grey;
                              if (p == OfficeTaskPriority.urgent) {
                                c = Colors.red;
                              } else if (p == OfficeTaskPriority.high) {
                                c = Colors.orange;
                              } else if (p == OfficeTaskPriority.normal) {
                                c = Colors.blue;
                              }
                              return DropdownMenuItem(
                                value: p,
                                child: Row(
                                  children: [
                                    Container(
                                      width: 8,
                                      height: 8,
                                      decoration: BoxDecoration(
                                          color: c, shape: BoxShape.circle),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(p,
                                        style: const TextStyle(fontSize: 12)),
                                  ],
                                ),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) setState(() => _priority = val);
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Due Date
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'DUE DATE *',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey,
                            ),
                          ),
                          const SizedBox(height: 6),
                          InkWell(
                            onTap: _pickDueDate,
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 12),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade50,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: Colors.grey.shade400),
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    DateFormat('dd MMM yyyy').format(_dueDate),
                                    style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold),
                                  ),
                                  const Icon(Icons.calendar_today,
                                      size: 16, color: Color(0xFF2563EB)),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // 5. Title
                const Text(
                  'TASK TITLE (कामाचे शीर्षक) *',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _titleController,
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Title required' : null,
                  decoration: InputDecoration(
                    hintText: 'e.g. Agreement Signature Follow-up',
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 14),

                // 6. Description / Details
                const Text(
                  'INSTRUCTIONS / DETAILS (तपशील)',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _descController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText:
                        'e.g. Call customer, verify meter reading and collection of signature.',
                    contentPadding: const EdgeInsets.all(12),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 14),

                // 7. File Attachment Section
                const Text(
                  'ATTACH FILE / DOCUMENT (दस्तऐवज संलग्न करा)',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 8),
                if (_attachedFile == null)
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          onPressed: () => _pickImage(ImageSource.camera),
                          icon: const Icon(Icons.camera_alt_outlined, size: 16),
                          label: const Text('Camera', style: TextStyle(fontSize: 12)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          onPressed: () => _pickImage(ImageSource.gallery),
                          icon: const Icon(Icons.photo_library_outlined, size: 16),
                          label: const Text('Gallery', style: TextStyle(fontSize: 12)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          onPressed: _pickDocument,
                          icon: const Icon(Icons.picture_as_pdf_outlined, size: 16),
                          label: const Text('PDF / Doc', style: TextStyle(fontSize: 12)),
                        ),
                      ),
                    ],
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFBFDBFE)),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          (_attachedFileName ?? '').toLowerCase().endsWith('.pdf')
                              ? Icons.picture_as_pdf_rounded
                              : Icons.image_rounded,
                          color: const Color(0xFF2563EB),
                          size: 24,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _attachedFileName ?? 'Attached File',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1E40AF),
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                '${((_attachedFileSize ?? 0) / 1024).toStringAsFixed(1)} KB',
                                style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, color: Colors.red, size: 20),
                          tooltip: 'Remove',
                          onPressed: _removeAttachment,
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 20),

                // Submit Button
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF059669),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: _isSaving ? null : _handleSave,
                    icon: _isSaving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2),
                          )
                        : const Icon(Icons.send_rounded, size: 20),
                    label: Text(
                      _isSaving ? 'Assigning Task...' : 'ASSIGN TASK TO STAFF',
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
